// 검수 반영 — 묘비 · 오래된 영수증 · 장부 상품 대조 · verify/환불 원자성 · 요청 수 제한(IPv6 /64 · 401 도 IP) · dev 도구 보호
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { call, devVerifyBody, fakeReceipt, IID_A, IID_B, mkEnv, putLedger, resetDb, T0, type Clock } from "./helpers";
import { ipKey } from "../src/app";
import { insertOrder, orderKeySha, RETENTION_MS } from "../src/db";
import { purgeOld } from "../src/cron";

const env = mkEnv();
let clock: Clock;
beforeEach(async () => {
  await resetDb(env);
  clock = { t: T0 };
});
afterEach(() => vi.restoreAllMocks());

const verify = (iid: string, body: Record<string, unknown>) => call(env, "POST", "/v1/purchases/verify", { iid, body, clock });

describe("보관 기간 · 묘비", () => {
  it("5년 지나 지운 주문의 영수증이 다시 오면 consumed (누가 와도) · 묘비는 해시만", async () => {
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500", at: T0 } });
    const b = await devVerifyBody("O1", "gold_500", "");
    await verify(IID_A, b);
    await call(env, "POST", "/v1/purchases/consume", { iid: IID_A, body: { store: "dev", order_id: "O1", env: "dev" }, clock });
    const later = T0 + RETENTION_MS + 86_400_000;
    expect(await purgeOld(env, later)).toBe(1);
    expect(await env.DB.prepare("SELECT * FROM orders").first()).toBeNull();
    const tomb = await env.DB.prepare("SELECT * FROM purged_orders").first<any>();
    expect(tomb.key_sha).toBe(await orderKeySha("dev", "O1"));
    expect(JSON.stringify(tomb)).not.toContain("O1");
    clock.t = later;
    for (const iid of [IID_A, IID_B]) expect((await verify(iid, b)).body).toEqual({ ok: true, order_id: "O1", product_id: "gold_500", gold: 500, status: "consumed", first: false });
    expect(await env.DB.prepare("SELECT * FROM orders").first()).toBeNull();
  });
  it("처음 보는 주문인데 구매 시각이 5년보다 오래됨 → 422 · 이미 기록이 있는 주문은 그대로", async () => {
    await putLedger(env, { OLD: { pid: "gold_500", spid: "gold_500", at: T0 - RETENTION_MS - 1000 }, NEW: { pid: "gold_500", spid: "gold_500", at: T0 } });
    const r = await verify(IID_A, await devVerifyBody("OLD", "gold_500", ""));
    expect(r.status).toBe(422);
    expect(r.body.error).toEqual({ code: "invalid_receipt", message: "receipt is older than the retention period" });
    await verify(IID_A, await devVerifyBody("NEW", "gold_500", ""));
    clock.t = T0 + RETENTION_MS + 5000;
    expect((await verify(IID_A, await devVerifyBody("NEW", "gold_500", ""))).body.status).toBe("valid");
  });
  it("insertOrder 는 환불 기록 · 묘비가 있으면 넣지 않음 (한 문장 — verify 와 환불 사이 경합)", async () => {
    const row = { store: "dev", order_id: "R1", product_id: "gold_500", gold: 500, install_id: IID_A, claimed_at: T0, account_id: "", env: "dev", status: "verified" as const, receipt_sha: "", verified_at: T0 };
    await env.DB.prepare("INSERT INTO refunds (store, order_id, product_id, gold, refunded_at, source) VALUES ('dev','R1','',0,1,'manual')").run();
    expect(await insertOrder(env.DB, row, await orderKeySha("dev", "R1"))).toBe(false);
    await env.DB.prepare("INSERT INTO purged_orders (key_sha, purged_at) VALUES (?, 1)").bind(await orderKeySha("dev", "R2")).run();
    expect(await insertOrder(env.DB, { ...row, order_id: "R2" }, await orderKeySha("dev", "R2"))).toBe(false);
    expect(await insertOrder(env.DB, { ...row, order_id: "R3" }, await orderKeySha("dev", "R3"))).toBe(true);
    expect((await env.DB.prepare("SELECT COUNT(*) AS n FROM orders").first<any>()).n).toBe(1);
  });
});

describe("가짜 가게 장부 대조", () => {
  it("장부의 상품과 영수증 상품이 다르면 422 · acct 가 글이 아니면 422", async () => {
    await putLedger(env, { O1: { pid: "gold_6500", spid: "gold_6500" } });
    const r = await verify(IID_A, await devVerifyBody("O1", "gold_500", ""));
    expect(r.body.error).toEqual({ code: "invalid_receipt", message: "the store order is for another product" });
    await putLedger(env, { O2: { pid: "gold_500", spid: "gold_500" } });
    const b = await devVerifyBody("O2", "gold_500", "");
    const rc = JSON.parse(b.receipt as string);
    for (const acct of [5, null, ["x"], { a: 1 }]) {
      expect((await verify(IID_A, { ...b, receipt: JSON.stringify({ ...rc, acct }) })).body.error.code).toBe("invalid_receipt");
    }
    const noAcct = JSON.stringify({ oid: "O2", spid: "gold_500", sig: rc.sig });
    expect((await verify(IID_A, { ...b, receipt: noAcct })).body.status).toBe("valid"); // acct 없음 = ""
  });
  it("STOVE 는 dev 서버에서도 501 (가짜 서버와 같음)", async () => {
    const r = await verify(IID_A, { store: "stove", product_id: "gold_500", store_product_id: "gold_500", order_id: "T1", receipt: "T1", env: "dev" });
    expect(r.status).toBe(501);
    expect(r.body.error.code).toBe("not_implemented");
  });
});

describe("요청 수 제한 보강", () => {
  function counter(limit: number) {
    const n = new Map<string, number>();
    const keys: string[] = [];
    return { keys, limit: async ({ key }: { key: string }) => { keys.push(key); n.set(key, (n.get(key) ?? 0) + 1); return { success: n.get(key)! <= limit }; } } as RateLimit & { keys: string[] };
  }
  it("ipKey: IPv4 그대로 · IPv6 는 /64", () => {
    expect(ipKey("203.0.113.9")).toBe("ip:203.0.113.9");
    expect(ipKey("2001:db8:1:2:aaaa::1")).toBe("ip6:2001:0db8:0001:0002::/64");
    expect(ipKey("2001:DB8:1:2:ffff:ffff:ffff:ffff")).toBe("ip6:2001:0db8:0001:0002::/64");
    expect(ipKey("2001:db8::1")).toBe("ip6:2001:0db8:0000:0000::/64");
    expect(ipKey("::1")).toBe("ip6:0000:0000:0000:0000::/64");
    expect(ipKey("::ffff:1.2.3.4")).toBe("ip:::ffff:1.2.3.4");
  });
  it("같은 /64 의 다른 주소는 한 묶음, 다른 /64 는 따로", async () => {
    const e = mkEnv({ RL_IP: counter(2), RL_INSTALL: counter(1000) });
    const go = (ip: string) => call(e, "GET", "/v1/health", { iid: null, headers: { "CF-Connecting-IP": ip }, clock, host: "iap.example.com" });
    expect((await go("2001:db8:1:2::a")).status).toBe(200);
    expect((await go("2001:db8:1:2::b")).status).toBe(200);
    expect((await go("2001:db8:1:2:ffff::c")).status).toBe(429);
    expect((await go("2001:db8:1:3::a")).status).toBe(200);
  });
  it("설치 식별자가 틀린 요청(401)도 IP 제한을 먼저 거침", async () => {
    const RL_IP = counter(3);
    const e = mkEnv({ RL_IP, RL_INSTALL: counter(1000) });
    const h = { "CF-Connecting-IP": "198.51.100.7" };
    const st: number[] = [];
    for (let i = 0; i < 5; i++) st.push((await call(e, "POST", "/v1/purchases/verify", { iid: "bad", body: {}, headers: h, clock, host: "iap.example.com" })).status);
    expect(st).toEqual([401, 401, 401, 429, 429]);
  });
  it("제한기가 고장 나면 통과시키되 기록을 남김 (rate_limit_error)", async () => {
    const err = vi.spyOn(console, "error").mockImplementation(() => {});
    const broken = { limit: async () => { throw new Error("down"); } } as unknown as RateLimit;
    const e = mkEnv({ RL_IP: broken, RL_INSTALL: broken });
    expect((await call(e, "GET", "/v1/refunds", { query: { env: "dev" }, clock })).status).toBe(200);
    const logs = err.mock.calls.map((c) => String(c[0])).filter((l) => l.includes("rate_limit_error"));
    expect(logs.length).toBe(2);
    expect(logs[0]).toContain('"key":"ip"');
    expect(logs[1]).toContain('"key":"iid"');
  });
});

describe("dev 도구 보호", () => {
  it("Host 가 127.0.0.1 이어도 실제 연결 주소(CF-Connecting-IP)가 루프백이 아니면 404 · 가짜 가게도 꺼짐", async () => {
    const h = { "CF-Connecting-IP": "203.0.113.50" };
    expect((await call(env, "POST", "/v1/dev/reset", { iid: null, body: {}, headers: h })).status).toBe(404);
    await putLedger(env, { O1: { pid: "gold_500", spid: "gold_500" } });
    expect((await call(env, "POST", "/v1/purchases/verify", { body: await devVerifyBody("O1", "gold_500", ""), headers: h, clock })).body.error.code).toBe("bad_store");
    expect((await call(env, "POST", "/v1/dev/reset", { iid: null, body: {}, headers: { "CF-Connecting-IP": "127.0.0.1" } })).status).toBe(200);
    expect((await call(env, "POST", "/v1/dev/reset", { iid: null, body: {}, headers: { "CF-Connecting-IP": "::1" } })).status).toBe(200);
  });
  it("바꾸는 도구는 JSON 본문 + Content-Type: application/json 이 있어야 함 (form 전송 막기)", async () => {
    for (const [p, ct, raw] of [["/v1/dev/reset", "application/x-www-form-urlencoded", "a=1"], ["/v1/dev/reset", "text/plain", "{}"], ["/v1/dev/clock", "multipart/form-data; boundary=x", "--x--"], ["/v1/dev/reset", "application/json", ""]] as const) {
      const r = await call(env, "POST", p, { iid: null, rawBody: raw, headers: { "Content-Type": ct } });
      expect(r.status).toBe(400);
    }
  });
  it("force429 시험 훅: 다음 n 번만 429", async () => {
    await call(env, "POST", "/v1/dev/force429", { iid: null, body: { count: 2 } });
    const q = { query: { cursor: "", env: "dev" }, clock };
    const st = [];
    for (let i = 0; i < 3; i++) st.push((await call(env, "GET", "/v1/refunds", q)).status);
    expect(st).toEqual([429, 429, 200]);
  });
});

describe("fake 영수증 도우미", () => {
  it("서명 글이 다르면 다른 서명", async () => {
    expect(await fakeReceipt("a", "b", "c")).not.toBe(await fakeReceipt("a", "b", "c", "x"));
  });
});
