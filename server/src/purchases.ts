// POST /v1/purchases/verify · POST /v1/purchases/consume · GET /v1/refunds — api.md 3.2 ~ 3.4
//  판단 순서 (형 검사 → 가게 확인 → 먼저 맞는 것): consumed > refunded > pending > claim(가게 소모 · 1번 · 24시간) > valid
//  fake_server.gd 와 같은 요청 → 같은 HTTP 상태 · 같은 JSON (메시지 글까지 맞춤)
import { ApiError, ok } from "./http";
import { sha256Hex } from "./crypto/enc";
import { consumeOrder, getOrder, hasRefund, insertOrder, isPurged, orderKeySha, reclaimOrder, recordRefund, RECLAIM_MAX, RECLAIM_MS, RETENTION_MS, type OrderRow } from "./db";
import { productById, storeProductId } from "./products";
import type { StoreCtx, StoreVerifier, VerifyInput } from "./stores/types";
import { verifyDev } from "./stores/dev";
import { verifyGoogle } from "./stores/google";
import { verifyApple } from "./stores/apple";
import { verifyStove } from "./stores/stove";

export const VERIFIERS: Record<string, StoreVerifier> = { dev: verifyDev, google: verifyGoogle, apple: verifyApple, stove: verifyStove };

/** 길이 상한 — order_id 는 Google purchaseToken 일 수 있어 넉넉히, receipt 는 Apple JWS 를 담을 만큼 */
const MAX_LEN: Record<string, number> = { store: 16, product_id: 64, store_product_id: 128, order_id: 512, receipt: 12288 };

function storesOf(ctx: StoreCtx): string[] {
  return ctx.env.STORES.split(",").map((s) => s.trim()).filter(Boolean);
}

function envOk(ctx: StoreCtx, v: unknown): boolean {
  return typeof v === "string" && v === ctx.env.ENV;
}

function envMismatch(ctx: StoreCtx): ApiError {
  return new ApiError(400, "env_mismatch", `this server is the ${ctx.env.ENV} environment`);
}

export async function verify(iid: string, b: Record<string, unknown>, ctx: StoreCtx): Promise<Response> {
  for (const k of ["store", "product_id", "store_product_id", "order_id", "receipt"]) {
    const v = b[k];
    if (typeof v !== "string" || v === "") throw new ApiError(400, "bad_request", "missing " + k);
    if (v.length > MAX_LEN[k]!) throw new ApiError(400, "bad_request", k + " too long");
  }
  if (!envOk(ctx, b.env)) throw envMismatch(ctx);
  const input: VerifyInput = {
    store: b.store as string,
    productId: b.product_id as string,
    storeProductId: b.store_product_id as string,
    orderId: b.order_id as string,
    receipt: b.receipt as string,
  };
  const verifier = VERIFIERS[input.store];
  if (!verifier || !storesOf(ctx).includes(input.store)) {
    throw new ApiError(400, "bad_store", storesOf(ctx).includes("dev") ? "this server only accepts the fake store" : "this store is not accepted by this server");
  }
  if (input.store === "dev" && ctx.env.ENV !== "dev") throw new ApiError(400, "bad_store", "this server does not accept the fake store");
  const p = productById(input.productId);
  if (!p) throw new ApiError(422, "unknown_product", "unknown product_id");
  if (storeProductId(p, input.store) !== input.storeProductId) throw new ApiError(422, "product_mismatch", "store_product_id does not match product_id");
  // 가게에 영수증 확인 — 계정 값은 확인된 결과의 것만 (본문의 account_id 는 읽지 않음)
  const check = await verifier(input, ctx);
  const out = { order_id: input.orderId, product_id: p.id, gold: p.gold };
  const receiptSha = await sha256Hex(input.receipt);
  const keySha = await orderKeySha(input.store, input.orderId);
  // 0) 보관 기간이 지나 지운 주문 (묘비) — 이미 끝난 주문으로 봄 (다시 지급하지 않음)
  if (await isPurged(ctx.env.DB, keySha)) return ok({ ...out, status: "consumed", first: false });

  for (let attempt = 0; attempt < 3; attempt++) {
    const have = await getOrder(ctx.env.DB, input.store, input.orderId);
    // 1) consumed — 누가 물어도 (환불 기록이 뒤에 붙어도 consume 된 적이 있으면 consumed)
    if (have && (have.status === "consumed" || (have.status === "refunded" && have.consumed_at !== null))) {
      return ok({ ...out, status: "consumed", first: false });
    }
    // 2) refunded — 가게 확인 결과 · 서버 기록 (주인 기록을 만들지 않음)
    if (check.state === "refunded" || have?.status === "refunded" || (await hasRefund(ctx.env.DB, input.store, input.orderId))) {
      // 이미 지급한 주문을 가게가 환불이라고 하면 서버에도 기록 → 주인의 환불 목록에 나옴 (환불 알림·Cron 을 놓쳐도)
      if (have && have.status !== "refunded" && check.state === "refunded") await recordRefund(ctx.env.DB, input.store, input.orderId, ctx.now, "verify");
      throw new ApiError(422, "refunded", "this order was refunded");
    }
    // 3) pending (주인 기록을 만들지 않음)
    if (check.state === "pending") return ok({ ...out, status: "pending" });
    if (have && have.product_id !== p.id) throw new ApiError(422, "product_mismatch", "this order was verified for another product");
    // 4) 다른 설치가 주인 — 재claim 규칙
    if (have && have.install_id !== iid) {
      if (check.storeConsumed) throw new ApiError(403, "already_delivered", "the store says this purchase was already consumed");
      if (have.reclaims >= RECLAIM_MAX) throw new ApiError(403, "reclaim_limit", "this order was already reclaimed once");
      if (ctx.now - have.claimed_at < RECLAIM_MS) throw new ApiError(403, "order_claimed", "order already claimed by another install");
      if (await reclaimOrder(ctx.env.DB, input.store, input.orderId, have.install_id, iid, check.accountId, ctx.now)) {
        console.log(JSON.stringify({ at: "reclaim", store: input.store, order_sha: keySha.slice(0, 16) }));
        return ok({ ...out, status: "valid", first: false, reclaimed: true });
      }
      continue; // 그사이 다른 요청이 바꿈 → 다시 읽고 다시 판단
    }
    // 5) valid
    if (have) return ok({ ...out, status: "valid", first: false });
    // 처음 보는 주문인데 구매가 보관 기간보다 오래됨 → 거절 (기록을 지운 뒤 같은 영수증을 다시 쓰지 못하게)
    if (check.purchasedAt !== undefined && ctx.now - check.purchasedAt > RETENTION_MS) throw new ApiError(422, "invalid_receipt", "receipt is older than the retention period");
    const row: Omit<OrderRow, "reclaims" | "reclaimed_from" | "reclaimed_at" | "consumed_at" | "refunded_at"> = {
      store: input.store,
      order_id: input.orderId,
      product_id: p.id,
      gold: p.gold,
      install_id: iid,
      claimed_at: ctx.now,
      account_id: check.accountId,
      env: ctx.env.ENV,
      status: "verified",
      receipt_sha: receiptSha,
      verified_at: ctx.now,
    };
    if (await insertOrder(ctx.env.DB, row, keySha)) return ok({ ...out, status: "valid", first: true });
    // 같은 주문이 동시에 들어와 다른 요청이 먼저 넣음 · 그사이 환불 기록 · 묘비 → 다시 읽고 판단 (주인은 하나)
    if (await isPurged(ctx.env.DB, keySha)) return ok({ ...out, status: "consumed", first: false });
  }
  throw new ApiError(500, "internal", "order changed too many times, try again");
}

export async function consume(iid: string, b: Record<string, unknown>, ctx: StoreCtx): Promise<Response> {
  if (typeof b.store !== "string" || typeof b.order_id !== "string") throw new ApiError(400, "bad_request", "store and order_id are required");
  if (b.store.length > MAX_LEN.store! || b.order_id.length > MAX_LEN.order_id!) throw new ApiError(400, "bad_request", "store or order_id too long");
  if (!envOk(ctx, b.env)) throw envMismatch(ctx);
  const store = b.store;
  const orderId = b.order_id;
  if (!(await consumeOrder(ctx.env.DB, store, orderId, iid, ctx.now))) {
    const have = await getOrder(ctx.env.DB, store, orderId);
    if (!have) throw new ApiError(404, "unknown_order", "verify first");
    if (have.install_id !== iid) throw new ApiError(403, "order_claimed", "order belongs to another install");
    if (have.status === "refunded") throw new ApiError(409, "refunded", "refunded order cannot be consumed");
    // 이미 consumed (멱등)
  }
  return ok({ status: "consumed", order_id: orderId });
}

function intOr(v: string | null, d: number): number {
  return v !== null && /^[+-]?\d+$/.test(v) ? Number.parseInt(v, 10) : d;
}

export async function refunds(iid: string, q: URLSearchParams, ctx: StoreCtx): Promise<Response> {
  if (q.get("env") !== ctx.env.ENV) throw envMismatch(ctx);
  const cursor = q.get("cursor");
  // 숫자가 아니거나 너무 긴 커서는 처음부터 (가짜 서버와 같음)
  const since = cursor !== null && cursor.length <= 15 ? intOr(cursor, 0) : 0;
  const lq = q.get("limit");
  const limit = Math.min(100, Math.max(1, lq !== null && lq.length <= 15 ? intOr(lq, 100) : 100));
  // 주인(verify 때 서버가 기록한 install_id)이 요청한 설치인 주문만 — 쿼리의 계정 값은 무시
  const rows = await ctx.env.DB.prepare(
    `SELECT r.seq AS seq, r.store AS store, r.order_id AS order_id, o.product_id AS product_id, o.gold AS gold, r.refunded_at AS refunded_at
     FROM refunds r JOIN orders o ON o.store = r.store AND o.order_id = r.order_id
     WHERE o.install_id = ? AND r.seq > ? ORDER BY r.seq LIMIT ?`,
  )
    .bind(iid, since, limit + 1)
    .all<{ seq: number; store: string; order_id: string; product_id: string; gold: number; refunded_at: number }>();
  const list = rows.results;
  const more = list.length > limit;
  const page = list.slice(0, limit);
  let next = since;
  const orders = page.map((r) => {
    next = Math.max(next, r.seq);
    return { store: r.store, order_id: r.order_id, product_id: r.product_id, gold: r.gold, refunded_at: r.refunded_at };
  });
  return ok({ orders, cursor: String(next), more });
}
