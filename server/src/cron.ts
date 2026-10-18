// Cron Trigger — 환불 수집 · 오래된 기록 정리 (wrangler.jsonc triggers.crons)
//  Google: Voided Purchases API 를 지난 위치(cursors.google_voided)부터 지금까지 쪽마다 읽어 refunds 에 INSERT OR IGNORE
//  STOVE: 환불 내역 API 확인 필요 — 아직 없음
//  정리: 주문·환불 기록 보관 5년 (api.md 7) 이 지난 것을 지움
import type { Deps, Env } from "./env";
import { getCursor, orderKeySha, recordRefund, setCursor, RETENTION_MS } from "./db";
export { RETENTION_MS };
import { sha256Hex } from "./crypto/enc";
import { listVoided } from "./stores/google";

const DAY = 86_400_000;
const VOIDED_WINDOW = 30 * DAY;   // API 가 돌려주는 기간 (최근 30일 — 그보다 오래된 startTime 은 받지 않음)
export const VOIDED_OVERLAP = DAY; // 다음 실행은 지난 끝보다 24시간 앞에서 (늦게 나타나는 항목 · 시계 차이 — INSERT OR IGNORE 라 겹쳐도 됨)
export const MAX_PAGES = 20;       // 한 번 실행에 읽는 쪽 수 (넘으면 쪽 토큰을 저장해 다음 실행에서 이어서)

export interface CronReport {
  google: { pages: number; seen: number; recorded: number; bad?: number; resumed?: boolean; more?: boolean; skipped?: string };
  purged: number;
}

/** cursors.google_voided 값: {"next": 다음 startTime} 또는 이어 읽는 중 {"start","end","token"} (예전 숫자 글도 next 로 읽음) */
interface VoidedCursor {
  next?: number;
  start?: number;
  end?: number;
  token?: string;
}

function readCursor(v: string | null): VoidedCursor {
  if (v === null) return {};
  if (/^\d+$/.test(v)) return { next: Number(v) };
  try {
    const c = JSON.parse(v) as VoidedCursor;
    return typeof c === "object" && c !== null ? c : {};
  } catch {
    return {};
  }
}

async function recordVoided(env: Env, v: { orderId?: string; purchaseToken?: string; voidedTimeMillis?: string }, now: number): Promise<boolean> {
  const at = Number(v.voidedTimeMillis ?? now);
  let oid = typeof v.orderId === "string" ? v.orderId : "";
  let known = oid ? await env.DB.prepare("SELECT order_id FROM orders WHERE store = 'google' AND order_id = ?").bind(oid).first<{ order_id: string }>() : null;
  if (!known && typeof v.purchaseToken === "string" && v.purchaseToken) {
    // 시험 결제처럼 orderId 가 없던 주문은 purchaseToken 이 order_id (= 영수증) — 해시로 찾음
    known = await env.DB.prepare("SELECT order_id FROM orders WHERE store = 'google' AND receipt_sha = ?").bind(await sha256Hex(v.purchaseToken)).first<{ order_id: string }>();
  }
  if (known) oid = known.order_id;
  if (!oid && typeof v.purchaseToken === "string") oid = v.purchaseToken;
  if (!oid || oid.length > 512 || !Number.isFinite(at)) throw new Error("bad voided item");
  await recordRefund(env.DB, "google", oid, at, "google_voided");
  return true;
}

export async function collectGoogleVoided(env: Env, deps: Deps, now: number, maxPages = MAX_PAGES): Promise<CronReport["google"]> {
  const rep = { pages: 0, seen: 0, recorded: 0, bad: 0 } as CronReport["google"];
  if (!env.STORES.split(",").includes("google")) return { ...rep, skipped: "store_off" };
  if (!env.GOOGLE_SERVICE_ACCOUNT_JSON || !env.GOOGLE_PACKAGE_NAME) return { ...rep, skipped: "not_configured" };
  const cur = readCursor(await getCursor(env.DB, "google_voided"));
  // 새로 시작할 때는 29일 전까지만 (이어 읽기가 하루 안에 끝나면 API 의 30일 한계 안에 남도록)
  const floor = now - VOIDED_WINDOW + DAY;
  const apiFloor = now - VOIDED_WINDOW + 60_000;
  let start: number;
  let end: number;
  let token: string | undefined;
  if (cur.token && typeof cur.start === "number" && typeof cur.end === "number" && cur.start >= apiFloor) {
    // 지난 실행이 쪽 상한에서 멈춤 → 같은 기간 · 같은 쪽 토큰으로 이어서
    start = cur.start;
    end = cur.end;
    token = cur.token;
    rep.resumed = true;
  } else {
    start = Math.max(typeof cur.next === "number" && cur.next > 0 ? cur.next : 0, floor);
    end = now;
  }
  do {
    const page = await listVoided(env, deps, now, start, end, token);
    rep.pages++;
    for (const v of page.items) {
      rep.seen++;
      try {
        await recordVoided(env, v, now);
        rep.recorded++;
      } catch (e) {
        rep.bad!++;
        console.warn(JSON.stringify({ at: "google_voided_item", error: e instanceof Error ? e.message.slice(0, 100) : "error" }));
      }
    }
    token = page.next;
  } while (token && rep.pages < maxPages);
  if (token) {
    // 쪽 상한 — 읽은 데까지 저장하고 다음 실행에서 이어서
    await setCursor(env.DB, "google_voided", JSON.stringify({ start, end, token }), now);
    rep.more = true;
  } else {
    await setCursor(env.DB, "google_voided", JSON.stringify({ next: end - VOIDED_OVERLAP }), now);
  }
  return rep;
}

/** 보관 기간이 지난 주문을 지우고 묘비(purged_orders: (store, order_id) 해시)를 남김 — 같은 영수증이 다시 와도 consumed */
export async function purgeOld(env: Env, now: number, batch = 200): Promise<number> {
  const cut = now - RETENTION_MS;
  let purged = 0;
  for (let round = 0; round < 50; round++) {
    const rows = await env.DB.prepare("SELECT store, order_id FROM orders WHERE verified_at < ? LIMIT ?").bind(cut, batch).all<{ store: string; order_id: string }>();
    if (rows.results.length === 0) break;
    const st: D1PreparedStatement[] = [];
    for (const r of rows.results) {
      st.push(env.DB.prepare("INSERT OR IGNORE INTO purged_orders (key_sha, purged_at) VALUES (?, ?)").bind(await orderKeySha(r.store, r.order_id), now));
      st.push(env.DB.prepare("DELETE FROM refunds WHERE store = ? AND order_id = ?").bind(r.store, r.order_id));
      st.push(env.DB.prepare("DELETE FROM orders WHERE store = ? AND order_id = ?").bind(r.store, r.order_id));
    }
    await env.DB.batch(st); // 묘비와 지우기를 한 번에 (중간에 끊겨도 묘비 없이 지워지는 일이 없음)
    purged += rows.results.length;
  }
  // 주인 기록이 없는 오래된 환불 기록 (verify 전에 환불된 주문)
  await env.DB.prepare("DELETE FROM refunds WHERE refunded_at < ?").bind(cut).run();
  return purged;
}

export async function runCron(env: Env, deps: Deps, now: number): Promise<CronReport> {
  let google: CronReport["google"];
  try {
    google = await collectGoogleVoided(env, deps, now);
  } catch (e) {
    console.error(JSON.stringify({ at: "cron_google", error: e instanceof Error ? e.message : "error" }));
    google = { pages: 0, seen: 0, recorded: 0, skipped: "error" };
  }
  const purged = await purgeOld(env, now);
  const rep = { google, purged };
  console.log(JSON.stringify({ at: "cron", ...rep }));
  return rep;
}
