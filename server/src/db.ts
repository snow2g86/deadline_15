import { sha256Hex } from "./crypto/enc";

// D1 접근 — 판단에 쓰는 바꾸기는 모두 한 문장 UPDATE … WHERE (원자적)
export const RECLAIM_MS = 86_400_000; // 24시간 (api.md 3.2)
export const RECLAIM_MAX = 1;         // 주문당 재claim 1번
export const RETENTION_MS = 5 * 365 * 86_400_000; // 주문·환불 기록 보관 5년 (api.md 7)

export interface OrderRow {
  store: string;
  order_id: string;
  product_id: string;
  gold: number;
  install_id: string;
  claimed_at: number;
  reclaims: number;
  reclaimed_from: string | null;
  reclaimed_at: number | null;
  account_id: string;
  env: string;
  status: "verified" | "consumed" | "refunded";
  receipt_sha: string;
  verified_at: number;
  consumed_at: number | null;
  refunded_at: number | null;
}

export function getOrder(db: D1Database, store: string, orderId: string): Promise<OrderRow | null> {
  return db.prepare("SELECT * FROM orders WHERE store = ? AND order_id = ?").bind(store, orderId).first<OrderRow>();
}

export async function hasRefund(db: D1Database, store: string, orderId: string): Promise<boolean> {
  return (await db.prepare("SELECT 1 AS x FROM refunds WHERE store = ? AND order_id = ?").bind(store, orderId).first()) !== null;
}

/** 처음 확인: 주인 기록 INSERT — 이미 있거나, 환불 기록이 있거나, 묘비(보관 기간이 지나 지운 주문)가 있으면 아무것도 안 함.
 *  한 문장이라 verify 와 환불 기록 사이에 끼어들 틈이 없음. 바뀐 줄 수 1 = 이 요청이 첫 주인 */
export async function insertOrder(db: D1Database, o: Omit<OrderRow, "reclaims" | "reclaimed_from" | "reclaimed_at" | "consumed_at" | "refunded_at">, keySha: string): Promise<boolean> {
  const r = await db
    .prepare(
      `INSERT INTO orders (store, order_id, product_id, gold, install_id, claimed_at, account_id, env, status, receipt_sha, verified_at)
       SELECT ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, 'verified', ?9, ?10
       WHERE NOT EXISTS (SELECT 1 FROM refunds WHERE store = ?1 AND order_id = ?2)
         AND NOT EXISTS (SELECT 1 FROM purged_orders WHERE key_sha = ?11)
       ON CONFLICT (store, order_id) DO NOTHING`,
    )
    .bind(o.store, o.order_id, o.product_id, o.gold, o.install_id, o.claimed_at, o.account_id, o.env, o.receipt_sha, o.verified_at, keySha)
    .run();
  return r.meta.changes === 1;
}

/** 묘비 열쇠: SHA-256("<store>\n<order_id>") */
export function orderKeySha(store: string, orderId: string): Promise<string> {
  return sha256Hex(`${store}\n${orderId}`);
}

export async function isPurged(db: D1Database, keySha: string): Promise<boolean> {
  return (await db.prepare("SELECT 1 AS x FROM purged_orders WHERE key_sha = ?").bind(keySha).first()) !== null;
}

/** 환불 취소 (Apple REFUND_REVERSED): 환불 기록을 지우고 주문 상태를 되돌림. 게임이 이미 회수한 골드는 돌려주지 않음 (api.md 3.4b) */
export async function reverseRefund(db: D1Database, store: string, orderId: string): Promise<void> {
  await db.batch([
    db.prepare("DELETE FROM refunds WHERE store = ? AND order_id = ?").bind(store, orderId),
    db.prepare("UPDATE orders SET status = CASE WHEN consumed_at IS NULL THEN 'verified' ELSE 'consumed' END, refunded_at = NULL WHERE store = ? AND order_id = ? AND status = 'refunded'").bind(store, orderId),
  ]);
}

/** 재claim (재설치 복구): 옛 주인이 그대로 · verified · 재claim 0번 · 24시간 지남 — 모두 한 문장에서 */
export async function reclaimOrder(db: D1Database, store: string, orderId: string, oldIid: string, newIid: string, accountId: string, now: number): Promise<boolean> {
  const r = await db
    .prepare(
      `UPDATE orders SET reclaimed_from = install_id, reclaimed_at = ?1, reclaims = reclaims + 1, install_id = ?2, account_id = ?3, claimed_at = ?1
       WHERE store = ?4 AND order_id = ?5 AND install_id = ?6 AND status = 'verified' AND reclaims < ?7 AND claimed_at <= ?1 - ?8`,
    )
    .bind(now, newIid, accountId, store, orderId, oldIid, RECLAIM_MAX, RECLAIM_MS)
    .run();
  return r.meta.changes === 1;
}

/** consume: 주인만 · verified 일 때만 (api.md 3.2 경합) */
export async function consumeOrder(db: D1Database, store: string, orderId: string, iid: string, now: number): Promise<boolean> {
  const r = await db
    .prepare("UPDATE orders SET status = 'consumed', consumed_at = ? WHERE store = ? AND order_id = ? AND status = 'verified' AND install_id = ?")
    .bind(now, store, orderId, iid)
    .run();
  return r.meta.changes === 1;
}

/** 환불 기록 (가게 확인 · 웹훅 · Cron) — refunds 에 INSERT OR IGNORE, orders.status = 'refunded' (이미 consumed 여도 기록, consumed_at 은 남김) */
export function refundStatements(db: D1Database, store: string, orderId: string, productId: string, gold: number, refundedAt: number, source: string, seq?: number): D1PreparedStatement[] {
  const ins =
    seq === undefined
      ? db.prepare("INSERT OR IGNORE INTO refunds (store, order_id, product_id, gold, refunded_at, source) VALUES (?, ?, ?, ?, ?, ?)").bind(store, orderId, productId, gold, refundedAt, source)
      : db.prepare("INSERT OR IGNORE INTO refunds (seq, store, order_id, product_id, gold, refunded_at, source) VALUES (?, ?, ?, ?, ?, ?, ?)").bind(seq, store, orderId, productId, gold, refundedAt, source);
  return [
    ins,
    db.prepare("UPDATE orders SET status = 'refunded', refunded_at = ? WHERE store = ? AND order_id = ? AND status != 'refunded'").bind(refundedAt, store, orderId),
  ];
}

export async function recordRefund(db: D1Database, store: string, orderId: string, refundedAt: number, source: string): Promise<void> {
  const o = await getOrder(db, store, orderId);
  await db.batch(refundStatements(db, store, orderId, o?.product_id ?? "", o?.gold ?? 0, refundedAt, source));
}

export async function getCursor(db: D1Database, name: string): Promise<string | null> {
  const r = await db.prepare("SELECT value FROM cursors WHERE name = ?").bind(name).first<{ value: string }>();
  return r ? r.value : null;
}

export async function setCursor(db: D1Database, name: string, value: string, now: number): Promise<void> {
  await db.prepare("INSERT INTO cursors (name, value, updated_at) VALUES (?, ?, ?) ON CONFLICT (name) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at").bind(name, value, now).run();
}
