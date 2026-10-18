// Google Play — 서비스 계정 JWT(RS256) → OAuth 2.0 토큰 → Android Publisher API v3
//  확인: purchases.products.get  GET /androidpublisher/v3/applications/{packageName}/purchases/products/{productId}/tokens/{token}
//    purchaseState 0=구매 1=취소 2=대기 · consumptionState 0/1 · acknowledgementState 0/1 · orderId · obfuscatedExternalAccountId · purchaseType(0=시험)
//  환불: purchases.voidedpurchases.list  GET /androidpublisher/v3/applications/{packageName}/purchases/voidedpurchases (Cron)
//  문서: https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/get
//        https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.voidedpurchases/list
//        https://developers.google.com/identity/protocols/oauth2/service-account#httprest
import { ApiError } from "../http";
import { signRs256 } from "../crypto/jwt";
import type { Deps, Env } from "../env";
import type { StoreVerifier } from "./types";

const SCOPE = "https://www.googleapis.com/auth/androidpublisher";
const DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token";
export const PUBLISHER = "https://androidpublisher.googleapis.com/androidpublisher/v3";

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

function account(env: Env): ServiceAccount {
  const raw = env.GOOGLE_SERVICE_ACCOUNT_JSON;
  if (!raw) throw new ApiError(503, "store_unavailable", "Google service account is not configured");
  let sa: Partial<ServiceAccount>;
  try {
    sa = JSON.parse(raw);
  } catch {
    throw new ApiError(503, "store_unavailable", "Google service account is not valid JSON");
  }
  if (typeof sa.client_email !== "string" || typeof sa.private_key !== "string") throw new ApiError(503, "store_unavailable", "Google service account is incomplete");
  return sa as ServiceAccount;
}

// OAuth 토큰은 1시간 유효 — 같은 isolate 안에서 만료 5분 전까지 다시 씀 (요청 사이 공유해도 되는 값: 서버 자신의 토큰)
const tokenCache = new Map<string, { token: string; exp: number }>();

export function clearGoogleTokenCache(): void {
  tokenCache.clear();
}

export async function googleAccessToken(env: Env, deps: Deps, nowMs: number): Promise<string> {
  const sa = account(env);
  const hit = tokenCache.get(sa.client_email);
  if (hit && hit.exp - 300_000 > nowMs) return hit.token;
  const iat = Math.floor(nowMs / 1000);
  const tokenUri = sa.token_uri || DEFAULT_TOKEN_URI;
  let assertion: string;
  try {
    assertion = await signRs256(sa.private_key, {}, { iss: sa.client_email, scope: SCOPE, aud: tokenUri, iat, exp: iat + 3600 });
  } catch {
    throw new ApiError(503, "store_unavailable", "Google service account key could not be used");
  }
  let res: Response;
  try {
    res = await deps.fetch(tokenUri, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }).toString(),
    });
  } catch {
    throw new ApiError(503, "store_unavailable", "Google OAuth is unreachable");
  }
  if (!res.ok) {
    console.warn(JSON.stringify({ at: "google_oauth", status: res.status }));
    throw new ApiError(503, "store_unavailable", "Google OAuth refused the service account");
  }
  const j = (await res.json()) as { access_token?: string; expires_in?: number };
  if (!j.access_token) throw new ApiError(503, "store_unavailable", "Google OAuth returned no token");
  tokenCache.set(sa.client_email, { token: j.access_token, exp: nowMs + (j.expires_in ?? 3600) * 1000 });
  return j.access_token;
}

export async function googleGet(env: Env, deps: Deps, nowMs: number, url: string): Promise<Response> {
  const token = await googleAccessToken(env, deps, nowMs);
  try {
    return await deps.fetch(url, { headers: { Authorization: `Bearer ${token}`, Accept: "application/json" } });
  } catch {
    throw new ApiError(503, "store_unavailable", "Google Play API is unreachable");
  }
}

export interface ProductPurchase {
  purchaseState?: number;
  consumptionState?: number;
  acknowledgementState?: number;
  orderId?: string;
  productId?: string;
  purchaseType?: number;
  obfuscatedExternalAccountId?: string;
  purchaseTimeMillis?: string;
}

export const verifyGoogle: StoreVerifier = async (input, ctx) => {
  const pkg = ctx.env.GOOGLE_PACKAGE_NAME;
  if (!pkg) throw new ApiError(503, "store_unavailable", "Google package name is not configured");
  const url = `${PUBLISHER}/applications/${encodeURIComponent(pkg)}/purchases/products/${encodeURIComponent(input.storeProductId)}/tokens/${encodeURIComponent(input.receipt)}`;
  const res = await googleGet(ctx.env, ctx.deps, ctx.now, url);
  if (res.status === 400 || res.status === 404 || res.status === 410) throw new ApiError(422, "invalid_receipt", "the store does not know this purchase");
  if (!res.ok) {
    console.warn(JSON.stringify({ at: "google_products_get", status: res.status }));
    throw new ApiError(503, "store_unavailable", "Google Play API error");
  }
  let p: ProductPurchase;
  try {
    p = (await res.json()) as ProductPurchase;
  } catch {
    throw new ApiError(503, "store_unavailable", "Google Play API returned bad JSON");
  }
  // 주문 번호: orderId (시험 결제처럼 없으면 purchaseToken) — 요청과 같아야 함
  const oid = p.orderId ? p.orderId : input.receipt;
  if (oid !== input.orderId) throw new ApiError(422, "invalid_receipt", "order_id does not match the purchase");
  if (p.productId !== undefined && p.productId !== input.storeProductId) throw new ApiError(422, "product_mismatch", "store_product_id does not match the purchase");
  if (p.purchaseType === 0 && ctx.env.GOOGLE_ALLOW_TEST_PURCHASES !== "1") throw new ApiError(422, "invalid_receipt", "test purchases are not accepted here");
  const state = p.purchaseState === 1 ? "refunded" : p.purchaseState === 2 ? "pending" : p.purchaseState === 0 ? "purchased" : null;
  if (state === null) throw new ApiError(503, "store_unavailable", "Google Play API returned an unknown purchaseState");
  return {
    state,
    accountId: typeof p.obfuscatedExternalAccountId === "string" ? p.obfuscatedExternalAccountId : "",
    storeConsumed: p.consumptionState === 1 || p.acknowledgementState === 1,
    purchasedAt: Number(p.purchaseTimeMillis) > 0 ? Number(p.purchaseTimeMillis) : undefined,
  };
};

export interface VoidedPurchase {
  purchaseToken?: string;
  orderId?: string;
  voidedTimeMillis?: string;
}

/** Voided Purchases 한 쪽 (type=0: 일회성 상품만). startTime 은 최근 30일까지만 받음 */
export async function listVoided(env: Env, deps: Deps, nowMs: number, startMs: number, endMs: number, pageToken?: string): Promise<{ items: VoidedPurchase[]; next?: string }> {
  const pkg = env.GOOGLE_PACKAGE_NAME;
  if (!pkg) throw new ApiError(503, "store_unavailable", "Google package name is not configured");
  const q = new URLSearchParams({ startTime: String(startMs), endTime: String(endMs), maxResults: "1000", type: "0" });
  if (pageToken) q.set("token", pageToken);
  const res = await googleGet(env, deps, nowMs, `${PUBLISHER}/applications/${encodeURIComponent(pkg)}/purchases/voidedpurchases?${q}`);
  if (!res.ok) {
    console.warn(JSON.stringify({ at: "google_voided", status: res.status }));
    throw new ApiError(503, "store_unavailable", "Google voided purchases API error");
  }
  const j = (await res.json()) as { voidedPurchases?: VoidedPurchase[]; tokenPagination?: { nextPageToken?: string } };
  return { items: j.voidedPurchases ?? [], next: j.tokenPagination?.nextPageToken || undefined };
}
