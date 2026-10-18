// App Store 확인기 — signedTransaction JWS 를 x5c 사슬(시험용 루트를 고정값으로)로 확인 · Server Notifications V2 웹훅 · Get Transaction Info
import { beforeAll, beforeEach, describe, expect, it } from "vitest";
import { call, decodeJwt, IID_A, IID_B, json, mkAppleChain, mkCert, mkEnv, mockFetch, pemPkcs8, resetDb, signJws, T0, type AppleChain, type Clock } from "./helpers";
import { utf8 } from "../src/crypto/enc";
import type { Env } from "../src/env";

const BUNDLE = "xyz.show4you.deadline15";
const SPID = "xyz.show4you.deadline15.gold_1200";
let chain: AppleChain;
let env: Env;
let clock: Clock;

beforeAll(async () => {
  chain = await mkAppleChain();
  env = mkEnv({ ENV: "prod", STORES: "stove,google,apple", DEV_STORE: "0", APPLE_BUNDLE_ID: BUNDLE, APPLE_ENVIRONMENTS: "Production,Sandbox", APPLE_ROOT_SHA256: chain.rootSha });
});
beforeEach(async () => {
  await resetDb(env);
  clock = { t: T0 };
});

const tx = (over: Record<string, unknown> = {}) => ({
  transactionId: "2000000111",
  originalTransactionId: "2000000111",
  bundleId: BUNDLE,
  productId: SPID,
  purchaseDate: T0 - 1000,
  type: "Consumable",
  inAppOwnershipType: "PURCHASED",
  environment: "Production",
  appAccountToken: "6F9619FF-8B86-D011-B42D-00CF4FC964FF",
  signedDate: T0,
  ...over,
});
const body = (receipt: string, over: Record<string, unknown> = {}) => ({ store: "apple", product_id: "gold_1200", store_product_id: SPID, order_id: "2000000111", receipt, env: "prod", ...over });
const verify = (iid: string, b: Record<string, unknown>, e: Env = env, fetch?: any) => call(e, "POST", "/v1/purchases/verify", { iid, body: b, clock, host: "iap.example.com", fetch });

describe("Apple JWS 확인", () => {
  it("서명 · 사슬 · 번들 · 상품 · 주문이 맞으면 valid, 계정 값 = appAccountToken (소문자)", async () => {
    const r = await verify(IID_A, body(await signJws(chain, tx())));
    expect(r.body).toEqual({ ok: true, order_id: "2000000111", product_id: "gold_1200", gold: 1200, status: "valid", first: true });
    const o = await env.DB.prepare("SELECT account_id FROM orders WHERE store='apple'").first<any>();
    expect(o.account_id).toBe("6f9619ff-8b86-d011-b42d-00cf4fc964ff");
  });
  it("revocationDate → 422 refunded", async () => {
    expect((await verify(IID_A, body(await signJws(chain, tx({ revocationDate: T0 }))))).body.error.code).toBe("refunded");
  });
  it("가짜: 다른 키로 서명 · 페이로드 바꿈 · 루트가 Apple 이 아님 · Apple OID 없음 · 사슬 2개 · alg 틀림 → 422 invalid_receipt", async () => {
    const other = await mkAppleChain();
    const good = await signJws(chain, tx());
    const [h, , s] = good.split(".");
    const tampered = `${h}.${btoa(JSON.stringify(tx({ productId: "xyz.show4you.deadline15.gold_6500" }))).replace(/=+$/, "")}.${s}`;
    const noLeafOid = await mkAppleChain({ leafExt: false, root: chain.root });
    const noMidOid = await mkAppleChain({ midExt: false, root: chain.root });
    const leafFromRoot = { ...chain, mid: chain.root }; // 중간 자리에 루트 (OID 없음)
    const rogueLeaf = await mkCert({ cn: "rogue", exts: ["1.2.840.113635.100.6.11.1"] }); // 스스로 서명한 잎
    const cases = [
      await signJws(chain, tx(), (await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign"]) as CryptoKeyPair).privateKey),
      tampered,
      await signJws(other, tx()),
      await signJws(noLeafOid, tx()),
      await signJws(noMidOid, tx()),
      await signJws(leafFromRoot, tx()),
      await signJws({ ...chain, leaf: rogueLeaf }, tx()),
      "a.b.c",
      "not-a-jws",
    ];
    for (const receipt of cases) {
      const r = await verify(IID_A, body(receipt));
      expect(r.status).toBe(422);
      expect(r.body.error).toEqual({ code: "invalid_receipt", message: "receipt signature check failed" });
    }
    // 2개짜리 x5c · ES256 아님
    const parts = good.split(".");
    const hdr = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(parts[0]!.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0))));
    for (const bad of [{ ...hdr, x5c: hdr.x5c.slice(0, 2) }, { ...hdr, alg: "none" }, { ...hdr, alg: "HS256" }]) {
      const h2 = btoa(JSON.stringify(bad)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
      expect((await verify(IID_A, body(`${h2}.${parts[1]}.${parts[2]}`))).body.error.code).toBe("invalid_receipt");
    }
  });
  it("중간 인증서 서명: 루트와 이름은 같고 다른 키로 서명한 중간 → 422 (mid→root 서명 확인)", async () => {
    const fakeRoot = await mkCert({ cn: chain.root.cn, curve: "P-384", ca: true }); // 이름만 같은 가짜 루트
    const mid = await mkCert({ cn: chain.mid.cn, issuer: fakeRoot, curve: "P-384", ca: true, exts: ["1.2.840.113635.100.6.2.1"] });
    const leaf = await mkCert({ cn: chain.leaf.cn, issuer: mid, exts: ["1.2.840.113635.100.6.11.1"] });
    const forged = { root: chain.root, mid, leaf, rootSha: chain.rootSha }; // x5c 의 루트는 고정된 진짜(시험용) 루트
    const r = await verify(IID_A, body(await signJws(forged, tx())));
    expect(r.status).toBe(422);
    expect(r.body.error.code).toBe("invalid_receipt");
  });
  it("잎 인증서 서명: 중간과 이름은 같고 다른 키로 서명한 잎 → 422 (leaf→mid 서명 확인)", async () => {
    const fakeMid = await mkCert({ cn: chain.mid.cn, curve: "P-384", ca: true, exts: ["1.2.840.113635.100.6.2.1"] });
    const leaf = await mkCert({ cn: chain.leaf.cn, issuer: fakeMid, exts: ["1.2.840.113635.100.6.11.1"] });
    const forged = { root: chain.root, mid: chain.mid, leaf, rootSha: chain.rootSha };
    expect((await verify(IID_A, body(await signJws(forged, tx())))).body.error.code).toBe("invalid_receipt");
    // 같은 진짜 중간이 서명한 다른 잎은 통과 (시험 자체가 맞는지)
    const okLeaf = await mkCert({ cn: "another leaf", issuer: chain.mid, exts: ["1.2.840.113635.100.6.11.1"] });
    expect((await verify(IID_A, body(await signJws({ ...chain, leaf: okLeaf }, tx())))).body.status).toBe("valid");
  });
  it("인증서 유효 기간 밖(signedDate) → 422", async () => {
    expect((await verify(IID_A, body(await signJws(chain, tx({ signedDate: T0 + 20 * 365 * 86400000 }))))).body.error.code).toBe("invalid_receipt");
  });
  it("번들 다름 422 · 주문 다름 422 · 상품 다름 product_mismatch · 소모성 아님 422", async () => {
    expect((await verify(IID_A, body(await signJws(chain, tx({ bundleId: "com.other" }))))).body.error.code).toBe("invalid_receipt");
    expect((await verify(IID_A, body(await signJws(chain, tx({ transactionId: "999" }))))).body.error.code).toBe("invalid_receipt");
    expect((await verify(IID_A, body(await signJws(chain, tx({ productId: "xyz.show4you.deadline15.gold_500" }))))).body.error.code).toBe("product_mismatch");
    expect((await verify(IID_A, body(await signJws(chain, tx({ type: "Auto-Renewable Subscription" }))))).body.error.code).toBe("invalid_receipt");
  });
  it("환경: stage(Sandbox 만) 에 Production 영수증 → 400 env_mismatch", async () => {
    const stage = mkEnv({ ...env, ENV: "stage", APPLE_ENVIRONMENTS: "Sandbox" });
    const r = await verify(IID_A, body(await signJws(chain, tx()), { env: "stage" }), stage);
    expect(r.body.error).toEqual({ code: "env_mismatch", message: "Apple environment is not accepted by this server" });
    expect((await verify(IID_A, body(await signJws(chain, tx({ environment: "Sandbox" })), { env: "stage" }), stage)).body.status).toBe("valid");
  });
  it("Apple 은 가게 소모 표시가 없음 → 24시간 뒤 재claim 허용", async () => {
    const r = body(await signJws(chain, tx()));
    await verify(IID_A, r);
    clock.t = T0 + 24 * 3600_000;
    expect((await verify(IID_B, r)).body.reclaimed).toBe(true);
  });
});

describe("App Store Server API (키가 있을 때 Get Transaction Info 로 다시)", () => {
  it("ES256 JWT · 최신 거래의 revocationDate 를 따름", async () => {
    const kp = (await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"])) as CryptoKeyPair;
    const e = mkEnv({ ...env, APPLE_API_KEY_P8: await pemPkcs8(kp.privateKey), APPLE_KEY_ID: "KEY123", APPLE_ISSUER_ID: "issuer-uuid" });
    let revoked = false;
    const f = mockFetch(async (u, init) => {
      expect(u.href).toBe("https://api.storekit.itunes.apple.com/inApps/v1/transactions/2000000111");
      const jwt = decodeJwt(new Headers(init?.headers).get("Authorization")!.replace("Bearer ", ""));
      expect(jwt.header).toEqual({ typ: "JWT", kid: "KEY123", alg: "ES256" });
      expect(jwt.payload).toMatchObject({ iss: "issuer-uuid", aud: "appstoreconnect-v1", bid: BUNDLE });
      expect(await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, kp.publicKey, jwt.sig, utf8(jwt.input))).toBe(true);
      return json(200, { signedTransactionInfo: await signJws(chain, tx(revoked ? { revocationDate: T0 } : {})) });
    });
    const b = body(await signJws(chain, tx()));
    expect((await verify(IID_A, b, e, f)).body.status).toBe("valid");
    revoked = true;
    expect((await verify(IID_A, b, e, f)).body.error.code).toBe("refunded");
    const down = mockFetch(() => json(500, {}));
    expect((await verify(IID_A, b, e, down)).status).toBe(503);
    const gone = mockFetch(() => json(404, {}));
    expect((await verify(IID_A, b, e, gone)).body.error.code).toBe("invalid_receipt");
  });
});

describe("App Store Server Notifications V2 웹훅", () => {
  const notif = async (type: string, t: Record<string, unknown>, over: Record<string, unknown> = {}) =>
    signJws(chain, { notificationType: type, notificationUUID: crypto.randomUUID(), version: "2.0", signedDate: T0 + 10, data: { bundleId: BUNDLE, environment: "Production", signedTransactionInfo: await signJws(chain, t) }, ...over });
  const post = (signedPayload: unknown, e: Env = env) => call(e, "POST", "/v1/webhooks/apple", { iid: null, body: { signedPayload }, clock, host: "iap.example.com" });

  it("REFUND → refunds 기록 → 주인의 환불 목록에 나옴 · 두 번 와도 한 번", async () => {
    await verify(IID_A, body(await signJws(chain, tx())));
    const p = await notif("REFUND", tx({ revocationDate: T0 + 5, revocationReason: 0 }));
    expect((await post(p)).body).toEqual({ ok: true });
    expect((await post(p)).status).toBe(200);
    const list = await call(env, "GET", "/v1/refunds", { iid: IID_A, query: { cursor: "", env: "prod" }, clock, host: "iap.example.com" });
    expect(list.body.orders).toEqual([{ store: "apple", order_id: "2000000111", product_id: "gold_1200", gold: 1200, refunded_at: T0 + 5 }]);
    expect((await verify(IID_B, body(await signJws(chain, tx())))).body.error.code).toBe("refunded");
  });
  it("REVOKE 도 기록 · 다른 알림은 받기만 · 서명 가짜 422 · 번들 다름 422 · 형 틀림 400", async () => {
    expect((await post(await notif("REVOKE", tx({ transactionId: "77" })))).status).toBe(200);
    expect((await env.DB.prepare("SELECT COUNT(*) AS n FROM refunds WHERE order_id='77'").first<any>()).n).toBe(1);
    expect((await post(await notif("CONSUMPTION_REQUEST", tx({ transactionId: "78" })))).status).toBe(200);
    expect((await post(await signJws(chain, { notificationType: "TEST", data: { bundleId: BUNDLE, environment: "Sandbox" } }))).status).toBe(200);
    expect((await env.DB.prepare("SELECT COUNT(*) AS n FROM refunds").first<any>()).n).toBe(1);
    const other = await mkAppleChain();
    expect((await post(await signJws(other, { notificationType: "REFUND" }))).body.error.code).toBe("invalid_receipt");
    expect((await post(await notif("REFUND", tx(), { data: { bundleId: "com.other", environment: "Production" } }))).body.error.code).toBe("invalid_receipt");
    expect((await post(5)).body.error.code).toBe("bad_request");
  });
  it("REFUND_REVERSED → 환불 기록 취소 · 주문 상태 되돌림 (게임이 회수한 골드는 돌려주지 않음)", async () => {
    await verify(IID_A, body(await signJws(chain, tx())));
    await call(env, "POST", "/v1/purchases/consume", { iid: IID_A, body: { store: "apple", order_id: "2000000111", env: "prod" }, clock, host: "iap.example.com" });
    await post(await notif("REFUND", tx({ revocationDate: T0 + 5 })));
    expect((await env.DB.prepare("SELECT status FROM orders").first<any>()).status).toBe("refunded");
    await post(await notif("REFUND_REVERSED", tx()));
    expect((await env.DB.prepare("SELECT status, refunded_at FROM orders").first<any>())).toEqual({ status: "consumed", refunded_at: null });
    expect((await env.DB.prepare("SELECT COUNT(*) AS n FROM refunds").first<any>()).n).toBe(0);
    const list = await call(env, "GET", "/v1/refunds", { iid: IID_A, query: { cursor: "", env: "prod" }, clock, host: "iap.example.com" });
    expect(list.body.orders).toEqual([]);
  });
  it("apple 을 받지 않는 서버(dev)에는 웹훅이 없음", async () => {
    expect((await call(mkEnv(), "POST", "/v1/webhooks/apple", { iid: null, body: { signedPayload: "x" } })).status).toBe(404);
  });
});
