// 바인딩 · 설정값 · 비밀값 (wrangler.jsonc 와 .dev.vars.example 참고)
export interface Env {
  DB: D1Database;
  RL_INSTALL?: RateLimit;
  RL_IP?: RateLimit;
  // 설정 (vars)
  ENV: string;                         // dev | stage | prod — 요청의 env 와 같아야 함
  STORES: string;                      // 받는 가게 (쉼표) — dev 는 "dev", stage·prod 는 "stove,google,apple"
  DEV_STORE?: string;                  // "1" 이면 가짜 가게 (ENV=dev · 로컬 주소에서만)
  DEV_FAKE_SIGNER?: string;            // 가짜 가게 서명 글 (없으면 "dev-fake-store" = 게임 backend_fake.gd FAKE_SIGNER — 비밀 아님)
  GOOGLE_PACKAGE_NAME?: string;
  GOOGLE_ALLOW_TEST_PURCHASES?: string; // "1" 이면 라이선스 시험 결제(purchaseType=0)도 받음
  APPLE_BUNDLE_ID?: string;
  APPLE_ENVIRONMENTS?: string;          // 받는 Apple environment (쉼표) — Production · Sandbox
  APPLE_ROOT_SHA256?: string;           // Apple Root CA - G3 인증서 SHA-256 (16진수)
  // 비밀 (wrangler secret / .dev.vars)
  GOOGLE_SERVICE_ACCOUNT_JSON?: string;
  APPLE_API_KEY_P8?: string;
  APPLE_KEY_ID?: string;
  APPLE_ISSUER_ID?: string;
  STOVE_API_KEY?: string;
  STOVE_ACCT_KEY?: string;
}

// 밖으로 나가는 요청 · 시계 — 시험에서 바꿔 끼움 (Google·Apple HTTP 흉내)
export interface Deps {
  fetch: (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;
  /** 실제 시계 (ms). dev 의 시계 밀기는 여기에 더해짐 */
  clock?: () => number;
}
