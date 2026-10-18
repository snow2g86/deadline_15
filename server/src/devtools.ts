// dev 환경 전용 도구 (가짜 가게를 켠 로컬 서버에서만 — devStoreEnabled)
//  Godot 의 가짜 가게 장부와 시험(check_iap -- --server)이 fake_server.gd 를 다루던 것과 같은 일을 진짜 Worker 에 함
//   PUT  /v1/dev/ledger : 가짜 가게 장부 (user://fake_iap/store.json 모양 그대로) → dev_ledger, 환불된 주문은 refunds (seq = 장부의 refund_seq)
//   GET  /v1/dev/state  : 서버 주문 기록을 fake_server 의 server.json 모양으로 {"orders": {"<store>:<order>": {...}}}
//   PUT  /v1/dev/state  : 같은 모양으로 고쳐 씀 (시험이 '앱이 consume 전에 사라짐' 같은 상태를 만들 때)
//   POST /v1/dev/clock  : {"offset_ms": n} 시험용 시계 밀기 (fake_server.clock_offset_ms)
//   POST /v1/dev/reset  : 모두 지움 (Files.reset)
//   POST /v1/dev/force429 : {"count": n} 다음 n 번의 게임 요청을 429 rate_limited 로 (시험 훅 — fake_server.force_429 와 같음)
//  상태를 바꾸는 도구(POST · PUT)는 JSON 본문과 Content-Type: application/json 이 있어야 함
import { ApiError, ok } from "./http";
import { refundStatements, type OrderRow } from "./db";

export async function devClockOffset(db: D1Database): Promise<number> {
  const r = await db.prepare("SELECT value FROM dev_meta WHERE name = 'clock_offset_ms'").first<{ value: string }>();
  const n = r ? Number(r.value) : 0;
  return Number.isFinite(n) ? n : 0;
}

const num = (v: unknown, d = 0) => (typeof v === "number" && Number.isFinite(v) ? Math.floor(v) : d);
const str = (v: unknown) => (v === undefined || v === null ? "" : String(v));

async function putLedger(db: D1Database, b: Record<string, unknown>): Promise<Response> {
  const orders = b.orders;
  if (typeof orders !== "object" || orders === null || Array.isArray(orders)) throw new ApiError(400, "bad_request", "orders must be an object");
  const st: D1PreparedStatement[] = [db.prepare("DELETE FROM dev_ledger")];
  for (const [oid, ov] of Object.entries(orders as Record<string, unknown>)) {
    if (typeof ov !== "object" || ov === null) continue;
    const o = ov as Record<string, unknown>;
    const refunded = o.refunded === true;
    st.push(
      db
        .prepare("INSERT INTO dev_ledger (order_id, pid, spid, acct, state, finished, refunded, refund_seq, refunded_at, at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
        .bind(oid, str(o.pid), str(o.spid), str(o.acct), str(o.state), o.finished === true ? 1 : 0, refunded ? 1 : 0, refunded ? num(o.refund_seq) : null, refunded ? num(o.refunded_at) : null, num(o.at)),
    );
    if (refunded) {
      // 가짜 가게의 환불 = 진짜 가게의 환불 알림 · Voided Purchases (주인 기록이 있으면 그 상품·골드)
      const [ins, upd] = refundStatements(db, "dev", oid, str(o.pid), 0, num(o.refunded_at), "dev", num(o.refund_seq) || undefined);
      st.push(ins!, upd!);
    }
  }
  st.push(db.prepare("UPDATE refunds SET product_id = (SELECT product_id FROM orders o WHERE o.store = refunds.store AND o.order_id = refunds.order_id), gold = (SELECT gold FROM orders o WHERE o.store = refunds.store AND o.order_id = refunds.order_id) WHERE store = 'dev' AND EXISTS (SELECT 1 FROM orders o WHERE o.store = refunds.store AND o.order_id = refunds.order_id)"));
  await db.batch(st);
  return ok({});
}

function shape(o: OrderRow): Record<string, unknown> {
  const d: Record<string, unknown> = {
    product_id: o.product_id,
    gold: o.gold,
    install_id: o.install_id,
    account_id: o.account_id,
    st: o.status,
    verified_at: o.verified_at,
    claimed_at: o.claimed_at,
    reclaims: o.reclaims,
  };
  if (o.reclaimed_from !== null) d.reclaimed_from = o.reclaimed_from;
  if (o.reclaimed_at !== null) d.reclaimed_at = o.reclaimed_at;
  if (o.consumed_at !== null) d.consumed_at = o.consumed_at;
  if (o.refunded_at !== null) d.refunded_at = o.refunded_at;
  return d;
}

async function getState(db: D1Database): Promise<Response> {
  const rows = await db.prepare("SELECT * FROM orders ORDER BY verified_at").all<OrderRow>();
  const orders: Record<string, unknown> = {};
  for (const o of rows.results) orders[`${o.store}:${o.order_id}`] = shape(o);
  return ok({ orders });
}

async function putState(db: D1Database, env: string, b: Record<string, unknown>): Promise<Response> {
  const orders = b.orders;
  if (typeof orders !== "object" || orders === null || Array.isArray(orders)) throw new ApiError(400, "bad_request", "orders must be an object");
  const keep: [string, string][] = [];
  const st: D1PreparedStatement[] = [];
  for (const [key, ov] of Object.entries(orders as Record<string, unknown>)) {
    const i = key.indexOf(":");
    if (i <= 0 || typeof ov !== "object" || ov === null) continue;
    const store = key.slice(0, i);
    const oid = key.slice(i + 1);
    const o = ov as Record<string, unknown>;
    const status = ["verified", "consumed", "refunded"].includes(str(o.st)) ? str(o.st) : "verified";
    keep.push([store, oid]);
    st.push(
      db
        .prepare(
          `INSERT INTO orders (store, order_id, product_id, gold, install_id, claimed_at, reclaims, reclaimed_from, reclaimed_at, account_id, env, status, receipt_sha, verified_at, consumed_at, refunded_at)
           VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, '', ?13, ?14, ?15)
           ON CONFLICT (store, order_id) DO UPDATE SET product_id = ?3, gold = ?4, install_id = ?5, claimed_at = ?6, reclaims = ?7, reclaimed_from = ?8, reclaimed_at = ?9,
             account_id = ?10, status = ?12, verified_at = ?13, consumed_at = ?14, refunded_at = ?15`,
        )
        .bind(
          store, oid, str(o.product_id), num(o.gold), str(o.install_id), num(o.claimed_at), num(o.reclaims),
          o.reclaimed_from === undefined ? null : str(o.reclaimed_from), o.reclaimed_at === undefined ? null : num(o.reclaimed_at),
          str(o.account_id), env, status, num(o.verified_at), o.consumed_at === undefined ? null : num(o.consumed_at), o.refunded_at === undefined ? null : num(o.refunded_at),
        ),
    );
  }
  const existing = await db.prepare("SELECT store, order_id FROM orders").all<{ store: string; order_id: string }>();
  const ks = new Set(keep.map(([s, o]) => `${s}\u0000${o}`));
  for (const r of existing.results) if (!ks.has(`${r.store}\u0000${r.order_id}`)) st.push(db.prepare("DELETE FROM orders WHERE store = ? AND order_id = ?").bind(r.store, r.order_id));
  if (st.length) await db.batch(st);
  return ok({});
}

async function reset(db: D1Database): Promise<Response> {
  await db.batch([
    db.prepare("DELETE FROM orders"),
    db.prepare("DELETE FROM refunds"),
    db.prepare("DELETE FROM cursors"),
    db.prepare("DELETE FROM dev_ledger"),
    db.prepare("DELETE FROM dev_meta"),
    db.prepare("DELETE FROM purged_orders"),
    db.prepare("DELETE FROM sqlite_sequence WHERE name = 'refunds'"),
  ]);
  return ok({});
}

export async function devTool(method: string, path: string, db: D1Database, env: string, body: () => Promise<Record<string, unknown>>): Promise<Response> {
  switch (`${method} ${path}`) {
    case "PUT /v1/dev/ledger":
      return putLedger(db, await body());
    case "GET /v1/dev/state":
      return getState(db);
    case "PUT /v1/dev/state":
      return putState(db, env, await body());
    case "POST /v1/dev/clock": {
      const b = await body();
      await db.prepare("INSERT INTO dev_meta (name, value) VALUES ('clock_offset_ms', ?) ON CONFLICT (name) DO UPDATE SET value = excluded.value").bind(String(num(b.offset_ms))).run();
      return ok({ offset_ms: num(b.offset_ms) });
    }
    case "POST /v1/dev/reset":
      await body(); // 바꾸는 도구는 모두 JSON 본문 + Content-Type: application/json (웹 페이지의 단순 form 전송으로는 못 부름)
      return reset(db);
    case "POST /v1/dev/force429": {
      const b = await body();
      await db.prepare("INSERT INTO dev_meta (name, value) VALUES ('force_429', ?) ON CONFLICT (name) DO UPDATE SET value = excluded.value").bind(String(num(b.count))).run();
      return ok({ count: num(b.count) });
    }
  }
  throw new ApiError(404, "not_found", "unknown endpoint");
}
