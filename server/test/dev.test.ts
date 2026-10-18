// 가짜 가게(dev)로 판단 순서 · 경합 · 재claim 경계 · 환불 목록 · 비정상 입력 · 429 — api.md 3
import { beforeEach, describe, expect, it } from "vitest";
import { call, devVerifyBody, fakeReceipt, IID_A, IID_B, IID_C, mkEnv, putLedger, resetDb, T0, type Clock } from "./helpers";

const env = mkEnv();
let clock: Clock;
const H = 3_600_000;

beforeEach(async () => {
  await resetDb(env);
  clock = { t: T0 };
});

const verify = async (iid: string, body: Record<string, unknown>) => call(env, "POST", "/v1/purchases/verify", { iid, body, clock });
const consume = async (iid: string, oid: string, extra: Record<string, unknown> = {}) => call(env, "POST", "/v1/purchases/consume", { iid, body: { store: "dev", order_id: oid, env: "dev", ...extra }, clock });
const refunds = async (iid: string, q: Record<string, string> = {}) => call(env, "GET", "/v1/refunds", { iid, query: { cursor: "", env: "dev", ...q }, clock });
const order = async (oid: string) => env.DB.prepare("SELECT * FROM orders WHERE store = 'dev' AND order_id = ?").bind(oid).first<any>();

describe("health", () => {
  it("서버 시각과 env (iid 없어도)", async () => {
    const r = await call(env, "GET", "/v1/health", { iid: null, clock });
    expect(r.status).toBe(200);
    expect(r.body).toEqual({ ok: true, time: T0, env: "dev" });
  });
  it("dev 시계 밀기는 health 에도", async () => {
    await call(env, "POST", "/v1/dev/clock", { iid: null, body: { offset_ms: 5000 } });
    expect((await call(env, "GET", "/v1/health", { iid: null, clock })).body.time).toBe(T0 + 5000);
  });
});

describe("verify 판단 순서", () => {
  it("5) 처음 → valid first:true, 다시 → first:false (멱등), 주인 기록", async () => {
    await putLedger(env, { O1: { pid: "gold_1200", spid: "gold_1200", acct: "acct-a" } });
    const b = await devVerifyBody("O1");
    const r1 = await verify(IID_A, b);
    expect(r1.status).toBe(200);
    expect(r1.body).toEqual({ ok: true, order_id: "O1", product_id: "gold_1200", gold: 1200, status: "valid", first: true });
    const r2 = await verify(IID_A, b);
    expect(r2.body).toEqual({ ok: true, order_id: "O1", product_id: "gold_1200", gold: 1200, status: "valid", first: false });
    const o = await order("O1");
    expect(o).toMatchObject({ install_id: IID_A, status: "verified", account_id: "acct-a", claimed_at: T0, reclaims: 0, env: "dev" });
    expect(o.receipt_sha).toMatch(/^[0-9a-f]{64}$/);
    expect(JSON.stringify(o)).not.toContain("sig");
  });

  it("1) consumed 는 누가 물어도 consumed (주인이 아니어도 · 환불 기록이 붙어도)", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    const b = await devVerifyBody("O1", "gold_500", "");
    await verify(IID_A, b);
    expect((await consume(IID_A, "O1")).status).toBe(200);
    for (const iid of [IID_A, IID_B]) {
      const r = await verify(iid, b);
      expect(r.body).toEqual({ ok: true, order_id: "O1", product_id: "gold_500", gold: 500, status: "consumed", first: false });
    }
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500", refunded: true, refund_seq: 1, refunded_at: T0 + 1 } });
    expect((await order("O1")).status).toBe("refunded");
    expect((await verify(IID_B, b)).body.status).toBe("consumed");
  });

  it("2) 가게가 환불 → 422 refunded, 주인 기록을 만들지 않음", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500", refunded: true, refund_seq: 1, refunded_at: T0 } });
    const r = await verify(IID_A, await devVerifyBody("O1", "gold_500", ""));
    expect(r.status).toBe(422);
    expect(r.body).toEqual({ ok: false, error: { code: "refunded", message: "this order was refunded" } });
    expect(await order("O1")).toBeNull();
  });

  it("2) 서버 기록이 refunded → 422 (가게가 다시 purchased 라 해도)", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    const b = await devVerifyBody("O1", "gold_500", "");
    await verify(IID_A, b);
    await env.DB.prepare("INSERT INTO refunds (store, order_id, product_id, gold, refunded_at, source) VALUES ('dev','O1','gold_500',500,1,'manual')").run();
    expect((await verify(IID_A, b)).body.error.code).toBe("refunded");
  });

  it("3) pending → 200 pending (first 없음, 주인 기록 없음) → 승인 뒤 valid", async () => {
    await putLedger(env, { O1: { pid: "gold_3000", spid: "gold_3000", state: "pending" } });
    const b = await devVerifyBody("O1", "gold_3000", "");
    expect((await verify(IID_A, b)).body).toEqual({ ok: true, order_id: "O1", product_id: "gold_3000", gold: 3000, status: "pending" });
    expect(await order("O1")).toBeNull();
    await putLedger(env, { O1: { pid: "gold_3000", spid: "gold_3000", state: "purchased" } });
    expect((await verify(IID_A, b)).body.first).toBe(true);
  });

  it("4) 다른 설치: 24시간 안 → 403 order_claimed", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    const b = await devVerifyBody("O1", "gold_500", "");
    await verify(IID_A, b);
    clock.t = T0 + 23 * H;
    const r = await verify(IID_B, b);
    expect(r.status).toBe(403);
    expect(r.body.error).toEqual({ code: "order_claimed", message: "order already claimed by another install" });
  });

  it("4) 재claim 경계: 24시간 - 1초 거절, 24시간 정각 · + 1초 허용 (주문당 1번) · 로그", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    const b = await devVerifyBody("O1", "gold_500", "");
    await verify(IID_A, b);
    clock.t = T0 + 24 * H - 1000;
    expect((await verify(IID_B, b)).body.error.code).toBe("order_claimed");
    clock.t = T0 + 24 * H;
    const ok = await verify(IID_B, b);
    expect(ok.body).toEqual({ ok: true, order_id: "O1", product_id: "gold_500", gold: 500, status: "valid", first: false, reclaimed: true });
    expect(await order("O1")).toMatchObject({ install_id: IID_B, reclaimed_from: IID_A, reclaimed_at: T0 + 24 * H, reclaims: 1, claimed_at: T0 + 24 * H });
    clock.t = T0 + 100 * H;
    const again = await verify(IID_C, b);
    expect(again.status).toBe(403);
    expect(again.body.error).toEqual({ code: "reclaim_limit", message: "this order was already reclaimed once" });
    // 옛 주인 A 가 돌아와 consume → 403 order_claimed (자기 지급 회수), B 는 성공
    expect((await consume(IID_A, "O1")).body.error.code).toBe("order_claimed");
    expect((await consume(IID_B, "O1")).status).toBe(200);
  });

  it("4) +1초 쪽 경계도 허용", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    const b = await devVerifyBody("O1", "gold_500", "");
    await verify(IID_A, b);
    clock.t = T0 + 24 * H + 1000;
    expect((await verify(IID_B, b)).body.reclaimed).toBe(true);
  });

  it("4) ① 가게에서 이미 소모(finish) → 403 already_delivered (24시간 · 횟수보다 먼저)", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    const b = await devVerifyBody("O1", "gold_500", "");
    await verify(IID_A, b);
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500", finished: true } });
    clock.t = T0 + 1000;
    const r = await verify(IID_B, b);
    expect(r.status).toBe(403);
    expect(r.body.error).toEqual({ code: "already_delivered", message: "the store says this purchase was already consumed" });
    expect((await verify(IID_A, b)).body.status).toBe("valid"); // 주인은 그대로 valid
  });

  it("본문의 account_id 는 믿지 않음 — 계정 값은 확인된 영수증의 acct", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500", acct: "victim" } });
    const b = await devVerifyBody("O1", "gold_500", "victim", { account_id: "attacker" });
    await verify(IID_A, b);
    expect((await order("O1")).account_id).toBe("victim");
    // 공격자가 피해자 영수증 + 피해자 account_id → 403
    const r = await verify(IID_B, { ...b, account_id: "victim" });
    expect(r.body.error.code).toBe("order_claimed");
  });
});

describe("verify 형 검사 · 영수증", () => {
  it("빠진 필드 · 빈 글 · 형이 틀림 → 400 bad_request (필드 이름)", async () => {
    const b = await devVerifyBody("O1");
    for (const k of ["store", "product_id", "store_product_id", "order_id", "receipt"]) {
      for (const bad of [undefined, "", 5, null, ["x"]]) {
        const r = await verify(IID_A, { ...b, [k]: bad });
        expect(r.status).toBe(400);
        expect(r.body).toEqual({ ok: false, error: { code: "bad_request", message: "missing " + k } });
      }
    }
  });
  it("너무 긴 값 → 400", async () => {
    const b = await devVerifyBody("O1");
    expect((await verify(IID_A, { ...b, order_id: "x".repeat(513) })).body.error.code).toBe("bad_request");
  });
  it("env 가 다르거나 없음 → 400 env_mismatch", async () => {
    const b = await devVerifyBody("O1");
    for (const e of ["prod", "stage", "", undefined, 1]) {
      const r = await verify(IID_A, { ...b, env: e });
      expect(r.body.error).toEqual({ code: "env_mismatch", message: "this server is the dev environment" });
    }
  });
  it("dev 서버에 다른 가게 → 400 bad_store", async () => {
    const r = await verify(IID_A, { ...(await devVerifyBody("O1")), store: "google" });
    expect(r.body.error).toEqual({ code: "bad_store", message: "this server only accepts the fake store" });
    expect((await verify(IID_A, { ...(await devVerifyBody("O1")), store: "steam" })).body.error.code).toBe("bad_store");
  });
  it("상품 모름 422 unknown_product · 가게 상품 id 다름 422 product_mismatch", async () => {
    const b = await devVerifyBody("O1");
    expect((await verify(IID_A, { ...b, product_id: "gold_999" })).body.error).toEqual({ code: "unknown_product", message: "unknown product_id" });
    expect((await verify(IID_A, { ...b, store_product_id: "gold_500" })).body.error).toEqual({ code: "product_mismatch", message: "store_product_id does not match product_id" });
  });
  it("가짜·바꾼 영수증 → 422 invalid_receipt", async () => {
    await putLedger(env, { O1: { pid: "gold_1200", spid: "gold_1200", acct: "a" } });
    const good = await devVerifyBody("O1", "gold_1200", "a");
    const sig = JSON.parse(good.receipt as string).sig;
    const cases = [
      "not json",
      "[]",
      JSON.stringify({ oid: "O1", spid: "gold_1200", acct: "b", sig }), // 계정 값 바꿈
      JSON.stringify({ oid: "O2", spid: "gold_1200", acct: "a", sig }), // 다른 주문
      JSON.stringify({ oid: "O1", spid: "gold_1200", acct: "a", sig: "0".repeat(64) }),
      await fakeReceipt("O1", "gold_1200", "a", "wrong-signer"),
    ];
    for (const receipt of cases) {
      const r = await verify(IID_A, { ...good, receipt });
      expect(r.status).toBe(422);
      expect(r.body.error).toEqual({ code: "invalid_receipt", message: "receipt signature check failed" });
    }
    // 서명은 맞는데 가게 장부에 없음
    const r = await verify(IID_A, await devVerifyBody("NOPE", "gold_1200", "a"));
    expect(r.body.error).toEqual({ code: "invalid_receipt", message: "the store does not know this order" });
    expect((await verify(IID_A, good)).body.status).toBe("valid");
  });
});

describe("consume", () => {
  it("주인만 · 멱등 · 404 · 403 · 409", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    const r404 = await consume(IID_A, "O1");
    expect(r404.status).toBe(404);
    expect(r404.body.error).toEqual({ code: "unknown_order", message: "verify first" });
    await verify(IID_A, await devVerifyBody("O1", "gold_500", ""));
    const r403 = await consume(IID_B, "O1", { account_id: "acct-a" });
    expect(r403.status).toBe(403);
    expect(r403.body.error).toEqual({ code: "order_claimed", message: "order belongs to another install" });
    clock.t = T0 + 5;
    const ok = await consume(IID_A, "O1");
    expect(ok.body).toEqual({ ok: true, status: "consumed", order_id: "O1" });
    expect((await order("O1")).consumed_at).toBe(T0 + 5);
    clock.t = T0 + 9;
    expect((await consume(IID_A, "O1")).body).toEqual({ ok: true, status: "consumed", order_id: "O1" });
    expect((await order("O1")).consumed_at).toBe(T0 + 5);
  });
  it("환불된 주문은 409 refunded", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    await verify(IID_A, await devVerifyBody("O1", "gold_500", ""));
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500", refunded: true, refund_seq: 1, refunded_at: T0 } });
    const r = await consume(IID_A, "O1");
    expect(r.status).toBe(409);
    expect(r.body.error).toEqual({ code: "refunded", message: "refunded order cannot be consumed" });
  });
  it("형 검사 · env", async () => {
    expect((await call(env, "POST", "/v1/purchases/consume", { body: { store: "dev", env: "dev" }, clock })).body.error).toEqual({ code: "bad_request", message: "store and order_id are required" });
    expect((await consume(IID_A, "O1", { env: "prod" })).body.error.code).toBe("env_mismatch");
  });
});

describe("경합", () => {
  it("두 설치가 같은 주문을 동시에 처음 verify → 주인은 하나 (valid 1 · 403 1)", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    const b = await devVerifyBody("O1", "gold_500", "");
    const rs = await Promise.all([verify(IID_A, b), verify(IID_B, b), verify(IID_A, b), verify(IID_B, b)]);
    const firsts = rs.filter((r) => r.body.first === true);
    expect(firsts.length).toBe(1);
    const owner = (await order("O1")).install_id;
    for (const [i, r] of rs.entries()) {
      const iid = i % 2 === 0 ? IID_A : IID_B;
      if (iid === owner) expect(r.body.status).toBe("valid");
      else expect(r.body.error.code).toBe("order_claimed");
    }
  });
  it("같은 주문 동시 consume (주인 여럿 번 + 남) → 한 번만 바뀜, 남은 403", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    await verify(IID_A, await devVerifyBody("O1", "gold_500", ""));
    const rs = await Promise.all([consume(IID_A, "O1"), consume(IID_B, "O1"), consume(IID_A, "O1"), consume(IID_B, "O1")]);
    expect(rs.map((r) => r.status)).toEqual([200, 403, 200, 403]);
    expect((await order("O1")).status).toBe("consumed");
  });
  it("동시 verify + consume: consume 뒤에는 누구에게도 valid 를 다시 주지 않음", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    const b = await devVerifyBody("O1", "gold_500", "");
    await verify(IID_A, b);
    const [c, v] = await Promise.all([consume(IID_A, "O1"), verify(IID_A, b)]);
    expect(c.status).toBe(200);
    expect(["valid", "consumed"]).toContain(v.body.status);
    expect((await verify(IID_A, b)).body.status).toBe("consumed");
  });
  it("두 설치의 동시 재claim (24시간 뒤) → 하나만 reclaimed, 다른 하나는 403", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    const b = await devVerifyBody("O1", "gold_500", "");
    await verify(IID_A, b);
    clock.t = T0 + 25 * H;
    const rs = await Promise.all([verify(IID_B, b), verify(IID_C, b)]);
    expect(rs.filter((r) => r.body.reclaimed === true).length).toBe(1);
    const other = rs.find((r) => r.body.reclaimed !== true)!;
    expect(other.status).toBe(403);
    expect(["order_claimed", "reclaim_limit"]).toContain(other.body.error.code);
    expect((await order("O1")).reclaims).toBe(1);
  });
});

describe("환불 목록", () => {
  async function setup() {
    const L: Record<string, any> = {};
    for (let i = 1; i <= 5; i++) L["R" + i] = { pid: "gold_500", spid: "gold_500" };
    await putLedger(env, L);
    for (let i = 1; i <= 5; i++) await verify(i <= 3 ? IID_A : IID_B, await devVerifyBody("R" + i, "gold_500", ""));
    for (let i = 1; i <= 5; i++) L["R" + i] = { ...L["R" + i], refunded: true, refund_seq: i, refunded_at: T0 + i };
    await putLedger(env, L);
  }
  it("주인(iid)의 주문만 · seq 순 · cursor · 쿼리의 account_id 무시", async () => {
    await setup();
    const a = await refunds(IID_A, { account_id: "acct-b" });
    expect(a.body).toEqual({
      ok: true,
      orders: [1, 2, 3].map((i) => ({ store: "dev", order_id: "R" + i, product_id: "gold_500", gold: 500, refunded_at: T0 + i })),
      cursor: "3",
      more: false,
    });
    expect((await refunds(IID_B)).body.orders.map((o: any) => o.order_id)).toEqual(["R4", "R5"]);
    expect((await refunds(IID_A, { cursor: "3" })).body).toEqual({ ok: true, orders: [], cursor: "3", more: false });
    expect((await refunds(IID_C)).body).toEqual({ ok: true, orders: [], cursor: "0", more: false });
  });
  it("limit · more", async () => {
    await setup();
    const p1 = await refunds(IID_A, { limit: "2" });
    expect(p1.body.orders.length).toBe(2);
    expect(p1.body.more).toBe(true);
    expect(p1.body.cursor).toBe("2");
    const p2 = await refunds(IID_A, { limit: "2", cursor: p1.body.cursor });
    expect(p2.body.orders.map((o: any) => o.order_id)).toEqual(["R3"]);
    expect(p2.body.more).toBe(false);
    // 이상한 limit · cursor 는 기본값으로 (가짜 서버와 같음)
    expect((await refunds(IID_A, { limit: "abc", cursor: "x" })).body.orders.length).toBe(3);
    expect((await refunds(IID_A, { limit: "0" })).body.orders.length).toBe(1);
  });
  it("verify 전에 환불된 주문은 목록에 없음 · env 없거나 다름 → env_mismatch", async () => {
    await putLedger(env, { Z: { pid: "gold_500", spid: "gold_500", refunded: true, refund_seq: 1, refunded_at: T0 } });
    expect((await refunds(IID_A)).body.orders).toEqual([]);
    expect((await call(env, "GET", "/v1/refunds", { query: { cursor: "" }, clock })).body.error.code).toBe("env_mismatch");
  });
});

describe("비정상 입력 · 인증 · 경로", () => {
  it("iid 없음·모양 틀림 → 401 no_install_id", async () => {
    for (const iid of [null, "", "A".repeat(32), "a".repeat(31), "a".repeat(33), "g".repeat(32)]) {
      const r = await call(env, "POST", "/v1/purchases/verify", { iid, body: {}, clock });
      expect(r.status).toBe(401);
      expect(r.body).toEqual({ ok: false, error: { code: "no_install_id", message: "X-D15-Install header missing or malformed" } });
    }
  });
  it("모르는 경로 · 메서드 → 404 not_found", async () => {
    for (const [m, p] of [["GET", "/v1/purchases/verify"], ["POST", "/v1/refunds"], ["GET", "/"], ["PUT", "/v1/purchases/consume"], ["GET", "/v2/health"]] as const) {
      const r = await call(env, m, p, { clock });
      expect(r.status).toBe(404);
      expect(r.body.error.code).toBe("not_found");
    }
  });
  it("JSON 아님 · 사전 아님 · Content-Type 틀림 · 너무 큼 → 400 bad_request", async () => {
    expect((await call(env, "POST", "/v1/purchases/verify", { rawBody: "{bad", clock })).body.error.code).toBe("bad_request");
    expect((await call(env, "POST", "/v1/purchases/verify", { rawBody: "[1,2]", clock })).body.error.code).toBe("bad_request");
    expect((await call(env, "POST", "/v1/purchases/verify", { rawBody: "{}", headers: { "Content-Type": "text/plain" }, clock })).body.error.code).toBe("bad_request");
    const big = await call(env, "POST", "/v1/purchases/verify", { body: { receipt: "x".repeat(20000) }, clock });
    expect(big.status).toBe(400);
    expect(big.body.error).toEqual({ code: "bad_request", message: "request body too large" });
  });
  it("CORS 머리 없음 (브라우저에서 부를 수 없음)", async () => {
    const r = await call(env, "GET", "/v1/health", { iid: null, headers: { Origin: "https://evil.example" }, clock });
    expect(r.headers.get("Access-Control-Allow-Origin")).toBeNull();
    const o = await call(env, "OPTIONS", "/v1/purchases/verify", { headers: { Origin: "https://evil.example" }, clock });
    expect(o.status).toBe(404);
    expect(o.headers.get("Access-Control-Allow-Origin")).toBeNull();
  });
});

describe("가짜 가게는 dev · 로컬에서만", () => {
  it("로컬 주소가 아니면 dev 서버라도 가짜 영수증 거절 · dev 도구 404", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    const r = await call(env, "POST", "/v1/purchases/verify", { body: await devVerifyBody("O1", "gold_500", ""), host: "deadline15-iap-dev.example.workers.dev", clock });
    expect(r.body.error.code).toBe("bad_store");
    expect((await call(env, "POST", "/v1/dev/reset", { iid: null, body: {}, host: "deadline15-iap-dev.example.workers.dev" })).status).toBe(404);
  });
  it("prod 설정 (DEV_STORE=1 을 잘못 넣어도) → 가짜 가게 · dev 도구 꺼짐", async () => {
    const prod = mkEnv({ ENV: "prod", STORES: "stove,google,apple,dev", DEV_STORE: "1" });
    const r = await call(prod, "POST", "/v1/purchases/verify", { body: await devVerifyBody("O1", "gold_500", "", { env: "prod" }), clock });
    expect(r.status).toBe(400);
    expect(r.body.error.code).toBe("bad_store");
    expect((await call(prod, "POST", "/v1/dev/reset", { iid: null, body: {} })).status).toBe(404);
    expect((await call(prod, "POST", "/v1/dev/clock", { iid: null, body: { offset_ms: 99 } })).status).toBe(404);
    expect((await call(prod, "GET", "/v1/health", { iid: null, clock })).body).toEqual({ ok: true, time: T0, env: "prod" });
  });
});

describe("요청 수 제한 429", () => {
  function counter(limit: number) {
    const n = new Map<string, number>();
    const keys: string[] = [];
    return {
      keys,
      limit: async ({ key }: { key: string }) => {
        keys.push(key);
        n.set(key, (n.get(key) ?? 0) + 1);
        return { success: n.get(key)! <= limit };
      },
    } as RateLimit & { keys: string[] };
  }
  it("설치 식별자별: 넘으면 429 rate_limited + Retry-After, 다른 설치는 그대로", async () => {
    const RL_INSTALL = counter(3);
    const e = mkEnv({ RL_INSTALL, RL_IP: counter(1000) });
    const q = { query: { cursor: "", env: "dev" }, clock };
    for (let i = 0; i < 3; i++) expect((await call(e, "GET", "/v1/refunds", { iid: IID_A, ...q })).status).toBe(200);
    const r = await call(e, "GET", "/v1/refunds", { iid: IID_A, ...q });
    expect(r.status).toBe(429);
    expect(r.body).toEqual({ ok: false, error: { code: "rate_limited", message: "too many requests" } });
    expect(r.headers.get("Retry-After")).toBe("60");
    expect((await call(e, "GET", "/v1/refunds", { iid: IID_B, ...q })).status).toBe(200);
    expect(RL_INSTALL.keys).toContain("iid:" + IID_A);
  });
  it("IP 별: CF-Connecting-IP 기준 (health · 웹훅 포함)", async () => {
    const RL_IP = counter(2);
    const e = mkEnv({ RL_IP, RL_INSTALL: counter(1000) });
    const h = { "CF-Connecting-IP": "203.0.113.9" };
    expect((await call(e, "GET", "/v1/health", { iid: null, headers: h, clock })).status).toBe(200);
    expect((await call(e, "GET", "/v1/refunds", { iid: IID_A, headers: h, query: { env: "dev" }, clock })).status).toBe(200);
    expect((await call(e, "GET", "/v1/refunds", { iid: IID_B, headers: h, query: { env: "dev" }, clock })).status).toBe(429);
    expect((await call(e, "GET", "/v1/health", { iid: null, headers: { "CF-Connecting-IP": "203.0.113.10" }, clock })).status).toBe(200);
    expect(RL_IP.keys[0]).toBe("ip:203.0.113.9");
  });
  it("제한기가 고장 나도 결제 확인은 막지 않음", async () => {
    const broken = { limit: async () => { throw new Error("down"); } } as unknown as RateLimit;
    const e = mkEnv({ RL_IP: broken, RL_INSTALL: broken });
    expect((await call(e, "GET", "/v1/refunds", { query: { env: "dev" }, clock })).status).toBe(200);
  });
});
