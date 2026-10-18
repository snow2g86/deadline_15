// 공통 응답: 성공 200 {"ok": true, ...}, 실패 {"ok": false, "error": {"code", "message"}} (api.md 3)

const BASE_HEADERS: Record<string, string> = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
  "X-Content-Type-Options": "nosniff",
};

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public headers: Record<string, string> = {}) {
    super(message);
  }
}

export function ok(body: Record<string, unknown>): Response {
  return new Response(JSON.stringify({ ok: true, ...body }), { status: 200, headers: BASE_HEADERS });
}

export function fail(status: number, code: string, message: string, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify({ ok: false, error: { code, message } }), { status, headers: { ...BASE_HEADERS, ...extra } });
}

/** 본문을 최대 max 바이트까지만 읽음 (넘으면 400 — 큰 본문을 끝까지 읽지 않음) */
export async function readCapped(req: Request, max: number): Promise<string> {
  const declared = Number(req.headers.get("Content-Length") ?? "0");
  if (Number.isFinite(declared) && declared > max) throw new ApiError(400, "bad_request", "request body too large");
  if (!req.body) return "";
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > max) {
      await reader.cancel();
      throw new ApiError(400, "bad_request", "request body too large");
    }
    chunks.push(value);
  }
  const all = new Uint8Array(total);
  let o = 0;
  for (const c of chunks) {
    all.set(c, o);
    o += c.byteLength;
  }
  try {
    return new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(all);
  } catch {
    throw new ApiError(400, "bad_request", "body is not utf-8");
  }
}

/** JSON 사전 본문 (POST) */
export async function readJsonObject(req: Request, max: number): Promise<Record<string, unknown>> {
  const ct = (req.headers.get("Content-Type") ?? "").toLowerCase();
  if (!ct.startsWith("application/json")) throw new ApiError(400, "bad_request", "Content-Type must be application/json");
  const text = await readCapped(req, max);
  let v: unknown;
  try {
    v = JSON.parse(text);
  } catch {
    throw new ApiError(400, "bad_request", "body is not JSON");
  }
  if (typeof v !== "object" || v === null || Array.isArray(v)) throw new ApiError(400, "bad_request", "body must be a JSON object");
  return v as Record<string, unknown>;
}
