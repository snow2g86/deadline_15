// 가짜 가게 (dev 환경 · 로컬 주소에서만) — Godot backend_fake.gd 가 만든 '서명된 가짜 영수증'을 fake_server.gd 와 같은 방법으로 확인
//  영수증 = {"oid","spid","acct","sig"}, sig = SHA-256("<FAKE_SIGNER>|<oid>|<spid>|<acct>") (fake_files.gd sig())
//  가게 장부(대기 · 환불 · finish)는 게임의 user://fake_iap/store.json 을 비춘 dev_ledger 표 (PUT /v1/dev/ledger)
import { ApiError } from "../http";
import { safeEqual, sha256Hex } from "../crypto/enc";
import type { Env } from "../env";
import type { StoreVerifier } from "./types";

/** 가짜 가게를 켜도 되는가 — prod 는 무엇을 설정해도 꺼짐 */
export function devStoreEnabled(env: Env, local: boolean): boolean {
  return env.ENV === "dev" && env.DEV_STORE === "1" && local;
}

export function fakeSig(signer: string, oid: string, spid: string, acct: string): Promise<string> {
  return sha256Hex(`${signer}|${oid}|${spid}|${acct}`);
}

interface LedgerRow {
  state: string;
  finished: number;
  refunded: number;
  spid: string;
  at: number;
}

export const verifyDev: StoreVerifier = async (input, ctx) => {
  if (!devStoreEnabled(ctx.env, ctx.local)) throw new ApiError(400, "bad_store", "this server does not accept the fake store");
  const bad = () => new ApiError(422, "invalid_receipt", "receipt signature check failed");
  let r: unknown;
  try {
    r = JSON.parse(input.receipt);
  } catch {
    throw bad();
  }
  if (typeof r !== "object" || r === null || Array.isArray(r)) throw bad();
  const rec = r as Record<string, unknown>;
  // 글이 아닌 값은 받지 않음 (가짜 서버와 같음 — acct 가 없으면 "")
  if (rec.acct !== undefined && typeof rec.acct !== "string") throw bad();
  if (typeof rec.oid !== "string" || typeof rec.spid !== "string" || typeof rec.sig !== "string") throw bad();
  const acct = (rec.acct as string | undefined) ?? "";
  if (rec.oid !== input.orderId || rec.spid !== input.storeProductId) throw bad();
  const want = await fakeSig(ctx.env.DEV_FAKE_SIGNER ?? "dev-fake-store", input.orderId, input.storeProductId, acct);
  if (!safeEqual(rec.sig, want)) throw bad();
  const so = await ctx.env.DB.prepare("SELECT state, finished, refunded, spid, at FROM dev_ledger WHERE order_id = ?").bind(input.orderId).first<LedgerRow>();
  if (!so) throw new ApiError(422, "invalid_receipt", "the store does not know this order");
  if (so.spid !== input.storeProductId) throw new ApiError(422, "invalid_receipt", "the store order is for another product");
  return {
    state: so.refunded ? "refunded" : so.state === "pending" ? "pending" : "purchased",
    accountId: acct,
    storeConsumed: !!so.finished,
    purchasedAt: so.at > 0 ? so.at : undefined,
  };
};
