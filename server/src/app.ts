// 요청 하나 → 응답 하나. 순서: 경로 → (도구·웹훅) → 설치 식별자 → 요청 수 제한 → 본문 → 엔드포인트
import type { Deps, Env } from "./env";
import { ApiError, fail, ok, readJsonObject } from "./http";
import { consume, refunds, verify } from "./purchases";
import { appleNotification } from "./webhooks";
import { devClockOffset, devTool } from "./devtools";
import { devStoreEnabled } from "./stores/dev";
import type { StoreCtx } from "./stores/types";

const MAX_BODY = 16 * 1024;          // 게임 요청 (Apple JWS 영수증이 들어가도 충분)
const MAX_WEBHOOK_BODY = 64 * 1024;  // Apple 알림
const MAX_DEV_BODY = 1024 * 1024;    // dev 도구 (장부 통째로)
const IID_RE = /^[0-9a-f]{32}$/;
const LOOPBACK_HOSTS = new Set(["127.0.0.1", "localhost", "[::1]", "::1"]);

function isLoopbackIp(ip: string): boolean {
  return ip === "::1" || /^127\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(ip) || /^::ffff:127\./i.test(ip);
}

/** 로컬 요청인가: 주소가 루프백 이름이고, 실제 연결 주소(CF-Connecting-IP — Cloudflare 가 넣고 클라이언트가 바꿀 수 없음)도 루프백.
 *  wrangler dev 는 127.0.0.1 에만 띄움 (package.json `npm run dev`) */
export function isLocal(req: Request, url: URL): boolean {
  if (!LOOPBACK_HOSTS.has(url.hostname)) return false;
  const ip = req.headers.get("CF-Connecting-IP");
  return ip === null || isLoopbackIp(ip);
}

/** 요청 수 제한 열쇠: IPv4 는 주소 그대로, IPv6 는 /64 (한 가입자가 보통 /64 를 통째로 받음) */
export function ipKey(ip: string): string {
  if (!ip.includes(":")) return "ip:" + ip;
  let addr = ip.split("%")[0]!.toLowerCase();
  if (addr.includes(".")) return "ip:" + addr; // ::ffff:1.2.3.4
  const [head, tail] = addr.includes("::") ? addr.split("::") as [string, string] : [addr, ""];
  const h = head ? head.split(":") : [];
  const t = tail ? tail.split(":") : [];
  const full = [...h, ...Array(Math.max(0, 8 - h.length - t.length)).fill("0"), ...t].map((x) => x.padStart(4, "0"));
  return "ip6:" + full.slice(0, 4).join(":") + "::/64";
}

async function limited(rl: RateLimit | undefined, key: string): Promise<boolean> {
  if (!rl) return false;
  try {
    return !(await rl.limit({ key })).success;
  } catch (e) {
    // 제한기 장애로 결제 확인을 막지 않음 — 대신 기록 (운영 점검: rate_limit_error)
    console.error(JSON.stringify({ at: "rate_limit_error", key: key.startsWith("iid:") ? "iid" : "ip", error: e instanceof Error ? e.message.slice(0, 100) : "error" }));
    return false;
  }
}

function tooMany(): ApiError {
  return new ApiError(429, "rate_limited", "too many requests", { "Retry-After": "60" });
}

/** (dev · 로컬 · 시험 훅) 다음 n 번의 게임 요청을 429 로 — POST /v1/dev/force429 */
async function devForced429(env: Env, local: boolean): Promise<boolean> {
  if (!devStoreEnabled(env, local)) return false;
  const r = await env.DB.prepare("UPDATE dev_meta SET value = CAST(value AS INTEGER) - 1 WHERE name = 'force_429' AND CAST(value AS INTEGER) > 0").run();
  return r.meta.changes === 1;
}

export async function handle(req: Request, env: Env, deps: Deps): Promise<Response> {
  const t0 = Date.now();
  const url = new URL(req.url);
  const path = url.pathname;
  const method = req.method;
  let res: Response;
  try {
    res = await route(req, env, deps, url, path, method);
  } catch (e) {
    if (e instanceof ApiError) {
      res = fail(e.status, e.code, e.message, e.headers);
    } else {
      console.error(JSON.stringify({ at: "unhandled", path, error: e instanceof Error ? e.name + ": " + e.message.slice(0, 200) : "error" }));
      res = fail(500, "internal", "internal error");
    }
  }
  // 기록: 경로 · 상태 · 오류 코드 · 걸린 시간 (영수증 · 비밀값 · 본문은 남기지 않음)
  let code = "";
  if (res.status !== 200) {
    try {
      code = ((await res.clone().json()) as { error?: { code?: string } }).error?.code ?? "";
    } catch {
      code = "";
    }
  }
  console.log(JSON.stringify({ at: "req", m: method, p: path.slice(0, 64), s: res.status, c: code, ms: Date.now() - t0 }));
  return res;
}

async function route(req: Request, env: Env, deps: Deps, url: URL, path: string, method: string): Promise<Response> {
  const local = isLocal(req, url);
  const ip = req.headers.get("CF-Connecting-IP") ?? (local ? "local" : "unknown");
  const ipk = ipKey(ip);
  const clock = deps.clock ?? Date.now;
  const now = async () => clock() + (devStoreEnabled(env, local) ? await devClockOffset(env.DB) : 0);

  if (path === "/v1/health" && method === "GET") {
    if (await limited(env.RL_IP, ipk)) throw tooMany();
    return ok({ time: await now(), env: env.ENV });
  }
  if (path.startsWith("/v1/dev/")) {
    if (!devStoreEnabled(env, local)) throw new ApiError(404, "not_found", "unknown endpoint");
    return devTool(method, path, env.DB, env.ENV, () => readJsonObject(req, MAX_DEV_BODY));
  }
  if (path === "/v1/webhooks/apple" && method === "POST") {
    if (await limited(env.RL_IP, ipk)) throw tooMany();
    const ctx: StoreCtx = { env, deps, now: await now(), local };
    return appleNotification(await readJsonObject(req, MAX_WEBHOOK_BODY), ctx);
  }
  // IP 제한을 먼저 — 설치 식별자가 틀린 요청(401)도 IP 별로 셈
  if ((await limited(env.RL_IP, ipk)) || (await devForced429(env, local))) throw tooMany();
  const iid = req.headers.get("X-D15-Install") ?? "";
  if (!IID_RE.test(iid)) throw new ApiError(401, "no_install_id", "X-D15-Install header missing or malformed");
  const known = (method === "POST" && (path === "/v1/purchases/verify" || path === "/v1/purchases/consume")) || (method === "GET" && path === "/v1/refunds");
  if (!known) throw new ApiError(404, "not_found", "unknown endpoint");
  if (await limited(env.RL_INSTALL, "iid:" + iid)) throw tooMany();
  const ctx: StoreCtx = { env, deps, now: await now(), local };
  if (path === "/v1/refunds") return refunds(iid, url.searchParams, ctx);
  const body = await readJsonObject(req, MAX_BODY);
  return path === "/v1/purchases/verify" ? verify(iid, body, ctx) : consume(iid, body, ctx);
}
