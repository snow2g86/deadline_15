// 설정 확인 — prod 에서 가짜 가게가 꺼져 있는가 · 상품표가 게임과 같은가 · 비밀값이 설정 파일에 없는가
import { describe, expect, it } from "vitest";
import wranglerText from "../wrangler.jsonc?raw";
import iap from "../../godot/data/iap.json";
import { PRODUCTS } from "../src/products";

const cfg = JSON.parse(wranglerText.replace(/^\s*\/\/.*$/gm, "").replace(/,(\s*[}\]])/g, "$1"));

describe("wrangler.jsonc", () => {
  it("prod · stage: DEV_STORE=0, 가게에 dev 없음, ENV 이름", () => {
    for (const e of ["prod", "stage"]) {
      const v = cfg.env[e].vars;
      expect(v.ENV).toBe(e);
      expect(v.DEV_STORE).toBe("0");
      expect(v.STORES.split(",")).not.toContain("dev");
      expect(v.DEV_FAKE_SIGNER).toBeUndefined();
    }
    expect(cfg.env.prod.vars.GOOGLE_ALLOW_TEST_PURCHASES).toBe("0");
  });
  it("dev(맨 위)는 공개 주소 없음 · 크론 없음", () => {
    expect(cfg.vars.ENV).toBe("dev");
    expect(cfg.workers_dev).toBe(false);
  });
  it("모든 환경에 D1 · 요청 수 제한 · (stage·prod) 크론", () => {
    for (const c of [cfg, cfg.env.stage, cfg.env.prod]) {
      expect(c.d1_databases[0].binding).toBe("DB");
      expect(c.ratelimits.map((r: any) => r.name).sort()).toEqual(["RL_INSTALL", "RL_IP"]);
    }
    expect(cfg.env.prod.ratelimits.find((r: any) => r.name === "RL_INSTALL").simple).toEqual({ limit: 60, period: 60 });
    expect(cfg.env.prod.triggers.crons.length).toBe(1);
  });
  it("비밀값 이름이 vars 에 없음", () => {
    for (const c of [cfg, cfg.env.stage, cfg.env.prod]) {
      for (const k of ["GOOGLE_SERVICE_ACCOUNT_JSON", "APPLE_API_KEY_P8", "STOVE_API_KEY", "STOVE_ACCT_KEY"]) expect(c.vars[k]).toBeUndefined();
    }
    expect(wranglerText).not.toMatch(/PRIVATE KEY/);
  });
});

describe("상품표", () => {
  it("서버 = 게임 data/iap.json", () => {
    expect(PRODUCTS.map((p) => [p.id, p.gold, p.google, p.apple, p.stove_item])).toEqual(
      (iap as any).IAP_PRODUCTS.map((p: any) => [p.id, p.gold, p.google, p.apple, p.stove_item]),
    );
    expect(PRODUCTS.length).toBe(4);
  });
  it("게임의 local 서버 주소는 포트 8951 · env dev", () => {
    expect((iap as any).IAP_SERVER.local).toEqual({ url: "http://127.0.0.1:8951", timeout: 10, env: "dev" });
  });
});
