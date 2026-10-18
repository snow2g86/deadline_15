// STOVE — 확인 API 미확정: 501 not_implemented (게임은 5xx 를 '다시 시도' → 지급 없음, 미처리로 남음) · 회원 번호 HMAC
import { describe, expect, it } from "vitest";
import { call, mkEnv } from "./helpers";
import { stoveAccountId } from "../src/stores/stove";

describe("STOVE", () => {
  const env = mkEnv({ ENV: "prod", STORES: "stove,google,apple", DEV_STORE: "0" });
  it("verify → 501 not_implemented, 주인 기록 없음", async () => {
    const r = await call(env, "POST", "/v1/purchases/verify", { body: { store: "stove", product_id: "gold_500", store_product_id: "gold_500", order_id: "T123", receipt: "T123", env: "prod" }, host: "iap.example.com" });
    expect(r.status).toBe(501);
    expect(r.body).toEqual({ ok: false, error: { code: "not_implemented", message: "STOVE purchase verification is not implemented yet" } });
    expect((await env.DB.prepare("SELECT COUNT(*) AS n FROM orders").first<any>()).n).toBe(0);
  });
  it("상품 id 는 stove_item 으로 맞춤 (확인 전 형 검사)", async () => {
    const r = await call(env, "POST", "/v1/purchases/verify", { body: { store: "stove", product_id: "gold_500", store_product_id: "xyz", order_id: "T", receipt: "T", env: "prod" }, host: "iap.example.com" });
    expect(r.body.error.code).toBe("product_mismatch");
  });
  it("계정 값 = HMAC-SHA256(STOVE_ACCT_KEY, memberNo) 16진수 (RFC 4231 시험 값 2)", async () => {
    expect(await stoveAccountId("Jefe", "what do ya want for nothing?")).toBe("5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843");
    await expect(stoveAccountId("", "1")).rejects.toThrow();
  });
});
