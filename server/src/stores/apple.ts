// App Store (StoreKit 2) — 기준: 게임이 보낸 signedTransaction(JWS)을 Apple 인증서 사슬로 확인 (api.md 4: 키 불필요)
//  App Store Server API 키(.p8)가 있으면 Get Transaction Info 로 한 번 더 확인 (환불 여부 최신화)
//  환불: App Store Server Notifications V2 (POST /v1/webhooks/apple) — REFUND · REVOKE
//  문서: https://developer.apple.com/documentation/appstoreserverapi/jwstransactiondecodedpayload
//        https://developer.apple.com/documentation/appstoreserverapi/get-transaction-info
//        https://developer.apple.com/documentation/appstoreservernotifications/responsebodyv2decodedpayload
//        https://developer.apple.com/documentation/appstoreserverapi/generating-json-web-tokens-for-api-requests
import { ApiError } from "../http";
import { JwsError, verifyAppleJws } from "../crypto/jws";
import { signEs256 } from "../crypto/jwt";
import type { Deps, Env } from "../env";
import type { StoreVerifier } from "./types";

export const APPLE_API = { Production: "https://api.storekit.itunes.apple.com", Sandbox: "https://api.storekit-sandbox.itunes.apple.com" } as const;

export interface AppleTransaction {
  transactionId?: string;
  bundleId?: string;
  productId?: string;
  environment?: string;
  appAccountToken?: string;
  revocationDate?: number;
  type?: string;
  signedDate?: number;
  purchaseDate?: number;
}

export function allowedEnvironments(env: Env): string[] {
  return (env.APPLE_ENVIRONMENTS ?? "").split(",").map((s) => s.trim()).filter(Boolean);
}

export async function decodeAppleJws(env: Env, jws: string, now: number): Promise<Record<string, unknown>> {
  if (!env.APPLE_ROOT_SHA256) throw new ApiError(503, "store_unavailable", "Apple root certificate pin is not configured");
  try {
    return await verifyAppleJws(jws, { rootSha256: env.APPLE_ROOT_SHA256, now });
  } catch (e) {
    if (e instanceof JwsError) throw new ApiError(422, "invalid_receipt", "receipt signature check failed");
    throw e;
  }
}

/** 확인된 거래가 이 앱 · 이 환경의 것인가 */
export function checkTransaction(env: Env, t: AppleTransaction): void {
  if (t.bundleId !== env.APPLE_BUNDLE_ID) throw new ApiError(422, "invalid_receipt", "bundleId does not match");
  if (!t.environment || !allowedEnvironments(env).includes(t.environment)) throw new ApiError(400, "env_mismatch", "Apple environment is not accepted by this server");
}

async function apiToken(env: Env, now: number): Promise<string> {
  const iat = Math.floor(now / 1000);
  try {
    return await signEs256(env.APPLE_API_KEY_P8!, { kid: env.APPLE_KEY_ID }, { iss: env.APPLE_ISSUER_ID, iat, exp: iat + 1200, aud: "appstoreconnect-v1", bid: env.APPLE_BUNDLE_ID });
  } catch {
    throw new ApiError(503, "store_unavailable", "Apple API key could not be used");
  }
}

export function appleApiConfigured(env: Env): boolean {
  return !!(env.APPLE_API_KEY_P8 && env.APPLE_KEY_ID && env.APPLE_ISSUER_ID);
}

/** App Store Server API — Get Transaction Info (확인된 JWS 를 돌려줌) */
export async function getTransactionInfo(env: Env, deps: Deps, now: number, environment: string, transactionId: string): Promise<AppleTransaction> {
  const base = environment === "Production" ? APPLE_API.Production : APPLE_API.Sandbox;
  let res: Response;
  try {
    res = await deps.fetch(`${base}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`, { headers: { Authorization: `Bearer ${await apiToken(env, now)}` } });
  } catch (e) {
    if (e instanceof ApiError) throw e;
    throw new ApiError(503, "store_unavailable", "App Store Server API is unreachable");
  }
  if (res.status === 404 || res.status === 400) throw new ApiError(422, "invalid_receipt", "the store does not know this transaction");
  if (!res.ok) {
    console.warn(JSON.stringify({ at: "apple_transaction_info", status: res.status }));
    throw new ApiError(503, "store_unavailable", "App Store Server API error");
  }
  const j = (await res.json()) as { signedTransactionInfo?: string };
  if (!j.signedTransactionInfo) throw new ApiError(503, "store_unavailable", "App Store Server API returned no transaction");
  return (await decodeAppleJws(env, j.signedTransactionInfo, now)) as AppleTransaction;
}

export const verifyApple: StoreVerifier = async (input, ctx) => {
  let t = (await decodeAppleJws(ctx.env, input.receipt, ctx.now)) as AppleTransaction;
  checkTransaction(ctx.env, t);
  if (String(t.transactionId) !== input.orderId) throw new ApiError(422, "invalid_receipt", "order_id does not match the transaction");
  if (t.productId !== input.storeProductId) throw new ApiError(422, "product_mismatch", "store_product_id does not match the transaction");
  if (t.type !== undefined && t.type !== "Consumable") throw new ApiError(422, "invalid_receipt", "not a consumable transaction");
  if (appleApiConfigured(ctx.env)) {
    const fresh = await getTransactionInfo(ctx.env, ctx.deps, ctx.now, t.environment!, input.orderId);
    checkTransaction(ctx.env, fresh);
    if (String(fresh.transactionId) !== input.orderId) throw new ApiError(422, "invalid_receipt", "order_id does not match the transaction");
    t = fresh;
  }
  return {
    state: t.revocationDate ? "refunded" : "purchased",
    accountId: typeof t.appAccountToken === "string" ? t.appAccountToken.toLowerCase() : "",
    // Apple 소모성 상품은 서버에서 볼 수 있는 '소모됨' 표시가 없음 (api.md 3.2 ① — 해당 없음)
    storeConsumed: false,
    purchasedAt: typeof t.purchaseDate === "number" ? t.purchaseDate : undefined,
  };
};
