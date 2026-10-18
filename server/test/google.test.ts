// Google Play 확인기 — OAuth(서비스 계정 JWT RS256) · purchases.products.get · Voided Purchases Cron 을 HTTP 흉내로
import { beforeAll, beforeEach, describe, expect, it } from "vitest";
import { call, decodeJwt, IID_A, IID_B, json, mkEnv, mockFetch, pemPkcs8, resetDb, T0, type Clock } from "./helpers";
import { clearGoogleTokenCache } from "../src/stores/google";
import { runCron } from "../src/cron";
import { sha256Hex, utf8 } from "../src/crypto/enc";
import type { Env } from "../src/env";

const PKG = "xyz.show4you.deadline15";
let env: Env;
let pub: CryptoKey;
let clock: Clock;

beforeAll(async () => {
  const kp = (await crypto.subtle.generateKey({ name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign", "verify"])) as CryptoKeyPair;
  pub = kp.publicKey;
  const sa = { type: "service_account", client_email: "iap@test.iam.gserviceaccount.com", private_key: await pemPkcs8(kp.privateKey), token_uri: "https://oauth2.googleapis.com/token" };
  env = mkEnv({ ENV: "prod", STORES: "stove,google,apple", DEV_STORE: "0", GOOGLE_PACKAGE_NAME: PKG, GOOGLE_ALLOW_TEST_PURCHASES: "0", GOOGLE_SERVICE_ACCOUNT_JSON: JSON.stringify(sa) });
});

beforeEach(async () => {
  await resetDb(env);
  clearGoogleTokenCache();
  clock = { t: T0 };
});

interface Purchase {
  purchaseState?: number;
  consumptionState?: number;
  acknowledgementState?: number;
  orderId?: string;
  purchaseType?: number;
  obfuscatedExternalAccountId?: string;
  productId?: string;
}

/** Google 흉내: 토큰 발급(JWT 서명 확인) + 상품 구매 조회 + voided 목록 */
function google(purchases: Record<string, Purchase | number>, voided: { pages?: any[][] } = {}) {
  let tokens = 0;
  const f = mockFetch(async (u, init) => {
    if (u.href === "https://oauth2.googleapis.com/token") {
      const form = new URLSearchParams(String(init?.body));
      expect(form.get("grant_type")).toBe("urn:ietf:params:oauth:grant-type:jwt-bearer");
      const jwt = decodeJwt(form.get("assertion")!);
      expect(jwt.header).toEqual({ typ: "JWT", alg: "RS256" });
      expect(jwt.payload).toMatchObject({ iss: "iap@test.iam.gserviceaccount.com", scope: "https://www.googleapis.com/auth/androidpublisher", aud: "https://oauth2.googleapis.com/token" });
      expect(jwt.payload.exp - jwt.payload.iat).toBe(3600);
      expect(await crypto.subtle.verify({ name: "RSASSA-PKCS1-v1_5" }, pub, jwt.sig, utf8(jwt.input))).toBe(true);
      tokens++;
      return json(200, { access_token: "ya29.test-token", expires_in: 3599, token_type: "Bearer" });
    }
    expect(new Headers(init?.headers).get("Authorization")).toBe("Bearer ya29.test-token");
    const pre = `/androidpublisher/v3/applications/${PKG}/purchases/`;
    expect(u.hostname).toBe("androidpublisher.googleapis.com");
    if (u.pathname.startsWith(pre + "products/")) {
      const [, productId, , token] = u.pathname.slice(pre.length).split("/");
      const p = purchases[decodeURIComponent(token!)];
      if (p === undefined) return json(404, { error: { code: 404 } });
      if (typeof p === "number") return json(p, { error: { code: p } });
      return json(200, { kind: "androidpublisher#productPurchase", productId, purchaseTimeMillis: String(T0), ...p });
    }
    if (u.pathname === pre + "voidedpurchases") {
      const page = Number(u.searchParams.get("token") ?? "0");
      const pages = voided.pages ?? [[]];
      const next = page + 1 < pages.length ? { tokenPagination: { nextPageToken: String(page + 1) } } : {};
      return json(200, { voidedPurchases: pages[page], ...next });
    }
    return json(404, {});
  });
  return Object.assign(f, { tokens: () => tokens });
}

const body = (token: string, oid: string, pid = "gold_1200", over: Record<string, unknown> = {}) => ({ store: "google", product_id: pid, store_product_id: pid, order_id: oid, receipt: token, env: "prod", ...over });
const verify = (iid: string, b: Record<string, unknown>, fetch: any) => call(env, "POST", "/v1/purchases/verify", { iid, body: b, clock, fetch, host: "iap.example.com" });

describe("Google purchases.products.get", () => {
  it("구매됨 → valid · 계정 값은 obfuscatedExternalAccountId · 토큰은 다시 씀", async () => {
    const f = google({ TOK1: { purchaseState: 0, consumptionState: 0, acknowledgementState: 0, orderId: "GPA.1", purchaseType: undefined, obfuscatedExternalAccountId: "acct-a" } });
    const r = await verify(IID_A, body("TOK1", "GPA.1"), f);
    expect(r.body).toEqual({ ok: true, order_id: "GPA.1", product_id: "gold_1200", gold: 1200, status: "valid", first: true });
    const o = await env.DB.prepare("SELECT * FROM orders WHERE store='google' AND order_id='GPA.1'").first<any>();
    expect(o.account_id).toBe("acct-a");
    expect(o.receipt_sha).toBe(await sha256Hex("TOK1"));
    await verify(IID_A, body("TOK1", "GPA.1", "gold_1200", { account_id: "attacker" }), f);
    expect(f.tokens()).toBe(1);
    expect(f.calls[1]!.url).toBe(`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PKG}/purchases/products/gold_1200/tokens/TOK1`);
  });
  it("purchaseState 1 → 422 refunded · 2 → pending", async () => {
    const f = google({ T1: { purchaseState: 1, orderId: "GPA.1" }, T2: { purchaseState: 2, orderId: "GPA.2" } });
    expect((await verify(IID_A, body("T1", "GPA.1"), f)).body.error.code).toBe("refunded");
    expect((await verify(IID_A, body("T2", "GPA.2"), f)).body.status).toBe("pending");
    expect((await env.DB.prepare("SELECT COUNT(*) AS n FROM orders").first<any>()).n).toBe(0);
  });
  it("orderId 가 없으면(시험 결제) order_id = purchaseToken", async () => {
    const e2 = { ...env, GOOGLE_ALLOW_TEST_PURCHASES: "1" };
    const f = google({ TESTTOK: { purchaseState: 0, purchaseType: 0 } });
    const r = await call(e2, "POST", "/v1/purchases/verify", { iid: IID_A, body: body("TESTTOK", "TESTTOK"), clock, fetch: f, host: "x.example" });
    expect(r.body.status).toBe("valid");
    expect((await call(e2, "POST", "/v1/purchases/verify", { iid: IID_A, body: body("TESTTOK", "GPA.X"), clock, fetch: f, host: "x.example" })).body.error.code).toBe("invalid_receipt");
  });
  it("prod 는 라이선스 시험 결제(purchaseType 0) 거절", async () => {
    const f = google({ T: { purchaseState: 0, purchaseType: 0, orderId: "GPA.T" } });
    expect((await verify(IID_A, body("T", "GPA.T"), f)).body.error).toEqual({ code: "invalid_receipt", message: "test purchases are not accepted here" });
  });
  it("주문 번호가 다름 · 모르는 토큰 → 422 invalid_receipt, 상품 다름 → product_mismatch", async () => {
    const f = google({ T: { purchaseState: 0, orderId: "GPA.REAL", productId: "gold_1200" } });
    expect((await verify(IID_A, body("T", "GPA.FAKE"), f)).body.error.code).toBe("invalid_receipt");
    expect((await verify(IID_A, body("NOPE", "GPA.X"), f)).body.error).toEqual({ code: "invalid_receipt", message: "the store does not know this purchase" });
    const g = google({ T: { purchaseState: 0, orderId: "GPA.REAL", productId: "gold_6500" } });
    expect((await verify(IID_A, body("T", "GPA.REAL"), g)).body.error.code).toBe("product_mismatch");
    expect((await verify(IID_A, body("T", "GPA.REAL", "gold_1200", { store_product_id: "xyz.show4you.deadline15.gold_1200" }), g)).body.error.code).toBe("product_mismatch");
  });
  it("Google 장애 · 권한 오류 · 네트워크 → 503 store_unavailable (게임은 다시 시도)", async () => {
    for (const st of [500, 503, 401, 403, 429]) {
      clearGoogleTokenCache();
      const r = await verify(IID_A, body("T", "GPA.1"), google({ T: st }));
      expect(r.status).toBe(503);
      expect(r.body.error.code).toBe("store_unavailable");
    }
    const down = mockFetch(() => {
      throw new TypeError("network");
    });
    expect((await verify(IID_A, body("T", "GPA.1"), down)).body.error.code).toBe("store_unavailable");
    const noKey = { ...env, GOOGLE_SERVICE_ACCOUNT_JSON: undefined };
    expect((await call(noKey, "POST", "/v1/purchases/verify", { body: body("T", "GPA.1"), clock, host: "x.example" })).body.error.code).toBe("store_unavailable");
  });
  it("이미 지급한 주문을 가게가 취소(purchaseState=1)라 하면 환불 기록 → 주인의 환불 목록에", async () => {
    await verify(IID_A, body("T", "GPA.R"), google({ T: { purchaseState: 0, orderId: "GPA.R" } }));
    clock.t = T0 + 50;
    const r = await verify(IID_A, body("T", "GPA.R"), google({ T: { purchaseState: 1, orderId: "GPA.R" } }));
    expect(r.body.error.code).toBe("refunded");
    const list = await call(env, "GET", "/v1/refunds", { iid: IID_A, query: { cursor: "", env: "prod" }, clock, host: "x.example" });
    expect(list.body.orders).toEqual([{ store: "google", order_id: "GPA.R", product_id: "gold_1200", gold: 1200, refunded_at: T0 + 50 }]);
    expect((await env.DB.prepare("SELECT status, source FROM orders JOIN refunds USING (store, order_id)").first<any>())).toEqual({ status: "refunded", source: "verify" });
  });
  it("구매 시각이 보관 기간(5년)보다 오래된 영수증은 거절", async () => {
    const old = String(T0 - 6 * 365 * 86_400_000);
    const r = await verify(IID_A, body("T", "GPA.OLD"), google({ T: { purchaseState: 0, orderId: "GPA.OLD", purchaseTimeMillis: old } as any }));
    expect(r.body.error).toEqual({ code: "invalid_receipt", message: "receipt is older than the retention period" });
  });
  it("재claim ①: consumptionState=1 또는 acknowledgementState=1 → 403 already_delivered", async () => {
    for (const [k, p] of [["C", { consumptionState: 1 }], ["A", { acknowledgementState: 1 }]] as const) {
      const f0 = google({ ["T" + k]: { purchaseState: 0, orderId: "GPA." + k } });
      await verify(IID_A, body("T" + k, "GPA." + k), f0);
      clock.t = T0 + 30 * 3600_000;
      const f1 = google({ ["T" + k]: { purchaseState: 0, orderId: "GPA." + k, ...p } });
      expect((await verify(IID_B, body("T" + k, "GPA." + k), f1)).body.error.code).toBe("already_delivered");
      clock.t = T0;
    }
  });
});

describe("Google Voided Purchases (Cron)", () => {
  it("쪽을 넘기며 수집 → 주문 refunded · 목록에 나옴 · 커서 저장 · 두 번 돌려도 한 번", async () => {
    const f0 = google({ T1: { purchaseState: 0, orderId: "GPA.1" }, T2: { purchaseState: 0 } });
    await verify(IID_A, body("T1", "GPA.1"), f0);
    const e2 = { ...env, GOOGLE_ALLOW_TEST_PURCHASES: "1" };
    await call(e2, "POST", "/v1/purchases/verify", { iid: IID_A, body: body("T2", "T2", "gold_500"), clock, fetch: f0, host: "x.example" });
    await call(env, "POST", "/v1/purchases/consume", { iid: IID_A, body: { store: "google", order_id: "GPA.1", env: "prod" }, clock, host: "x.example" });
    const f = google({}, { pages: [[{ purchaseToken: "T1", orderId: "GPA.1", voidedTimeMillis: String(T0 + 100) }], [{ purchaseToken: "T2", voidedTimeMillis: String(T0 + 200) }, { purchaseToken: "UNKNOWN", orderId: "GPA.9", voidedTimeMillis: String(T0 + 300) }]] });
    clock.t = T0 + 3600_000;
    const rep = await runCron(env, { fetch: f }, clock.t);
    expect(rep.google).toEqual({ pages: 2, seen: 3, recorded: 3, bad: 0 });
    const q = new URL(f.calls.find((c) => c.url.includes("voidedpurchases"))!.url).searchParams;
    expect(q.get("type")).toBe("0");
    expect(Number(q.get("endTime"))).toBe(clock.t);
    expect(Number(q.get("startTime"))).toBeGreaterThan(clock.t - 30 * 86400_000);
    const list = await call(env, "GET", "/v1/refunds", { iid: IID_A, query: { cursor: "", env: "prod" }, clock, host: "x.example" });
    expect(list.body.orders).toEqual([
      { store: "google", order_id: "GPA.1", product_id: "gold_1200", gold: 1200, refunded_at: T0 + 100 },
      { store: "google", order_id: "T2", product_id: "gold_500", gold: 500, refunded_at: T0 + 200 },
    ]);
    expect((await call(env, "GET", "/v1/refunds", { iid: IID_B, query: { cursor: "", env: "prod" }, clock, host: "x.example" })).body.orders).toEqual([]);
    // consume 된 뒤 환불돼도 verify 는 consumed (판단 순서 1), consume 은 409
    expect((await verify(IID_B, body("T1", "GPA.1"), f0)).body.status).toBe("consumed");
    expect((await call(env, "POST", "/v1/purchases/consume", { iid: IID_A, body: { store: "google", order_id: "T2", env: "prod" }, clock, host: "x.example" })).status).toBe(409);
    const cur = await env.DB.prepare("SELECT value FROM cursors WHERE name='google_voided'").first<any>();
    expect(JSON.parse(cur.value)).toEqual({ next: clock.t - 86_400_000 });
    const again = await runCron(env, { fetch: f }, clock.t + 1000);
    expect(again.google.recorded).toBe(3);
    expect((await env.DB.prepare("SELECT COUNT(*) AS n FROM refunds").first<any>()).n).toBe(3);
    const q2 = new URL(f.calls.filter((c) => c.url.includes("voidedpurchases")).at(-1)!.url).searchParams;
    expect(Number(q2.get("startTime"))).toBe(clock.t - 86_400_000); // 24시간 겹쳐 다시 읽음
  });
  it("이상한 항목은 건너뛰고 기록만 · 나머지는 수집", async () => {
    const f = google({}, { pages: [[{ voidedTimeMillis: String(T0) }, { purchaseToken: "OK1", orderId: "GPA.OK1", voidedTimeMillis: String(T0 + 1) }, { orderId: "x".repeat(600) }, null as any, { orderId: "GPA.OK2", voidedTimeMillis: "abc" }, { orderId: "GPA.OK3" }]] });
    const rep = await runCron(env, { fetch: f }, T0 + 3600_000);
    expect(rep.google).toMatchObject({ pages: 1, seen: 6, recorded: 2, bad: 4 });
    const rows = await env.DB.prepare("SELECT order_id FROM refunds ORDER BY order_id").all<any>();
    expect(rows.results.map((r) => r.order_id)).toEqual(["GPA.OK1", "GPA.OK3"]);
  });
  it("20쪽 상한: 커서(같은 기간 · 쪽 토큰)를 저장하고 다음 실행에서 이어서 끝까지", async () => {
    const pages = Array.from({ length: 25 }, (_, i) => [{ orderId: `GPA.P${i}`, voidedTimeMillis: String(T0 + i) }]);
    const f = google({}, { pages });
    const t1 = T0 + 3600_000;
    const r1 = await runCron(env, { fetch: f }, t1);
    expect(r1.google).toMatchObject({ pages: 20, recorded: 20, more: true });
    const c1 = JSON.parse((await env.DB.prepare("SELECT value FROM cursors WHERE name='google_voided'").first<any>()).value);
    expect(c1.token).toBe("20");
    expect(c1.end).toBe(t1);
    const t2 = t1 + 1800_000;
    const r2 = await runCron(env, { fetch: f }, t2);
    expect(r2.google).toMatchObject({ pages: 5, recorded: 5, resumed: true });
    const q = new URL(f.calls.filter((c) => c.url.includes("voidedpurchases"))[20]!.url).searchParams;
    expect(q.get("token")).toBe("20");
    expect(Number(q.get("endTime"))).toBe(t1); // 같은 기간으로 이어 읽음
    expect((await env.DB.prepare("SELECT COUNT(*) AS n FROM refunds").first<any>()).n).toBe(25);
    const c2 = JSON.parse((await env.DB.prepare("SELECT value FROM cursors WHERE name='google_voided'").first<any>()).value);
    expect(c2).toEqual({ next: t1 - 86_400_000 });
  });
  it("오래된 커서(30일 넘게 멈춤)는 API 가 받는 30일 안쪽에서 다시 시작", async () => {
    await env.DB.prepare("INSERT INTO cursors (name, value, updated_at) VALUES ('google_voided', ?, 0)").bind(JSON.stringify({ next: T0 - 90 * 86_400_000 })).run();
    const f = google({}, { pages: [[]] });
    await runCron(env, { fetch: f }, T0);
    const q = new URL(f.calls.find((c) => c.url.includes("voidedpurchases"))!.url).searchParams;
    expect(Number(q.get("startTime"))).toBe(T0 - 29 * 86_400_000);
  });
  it("설정이 없으면 건너뜀 · Google 장애여도 Cron 은 끝남", async () => {
    expect((await runCron({ ...env, GOOGLE_SERVICE_ACCOUNT_JSON: undefined }, { fetch: google({}) }, T0)).google.skipped).toBe("not_configured");
    const bad = mockFetch(() => json(500, {}));
    expect((await runCron(env, { fetch: bad }, T0)).google.skipped).toBe("error");
  });
  it("5년 지난 기록은 정리", async () => {
    await env.DB.prepare("INSERT INTO orders (store, order_id, product_id, gold, install_id, claimed_at, env, status, receipt_sha, verified_at) VALUES ('google','OLD','gold_500',500,?,1,'prod','consumed','',1)").bind(IID_A).run();
    const rep = await runCron({ ...env, GOOGLE_SERVICE_ACCOUNT_JSON: undefined }, { fetch: google({}) }, T0);
    expect(rep.purged).toBe(1);
  });
});
