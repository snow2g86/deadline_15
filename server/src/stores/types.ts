import type { Deps, Env } from "../env";

/** 게임이 보낸 verify 요청 (형 검사를 마친 것) */
export interface VerifyInput {
  store: string;
  productId: string;
  storeProductId: string;
  orderId: string;
  receipt: string;
}

/** 가게에 물어 얻은 결과 — 계정 값은 이것뿐 (클라이언트가 보낸 account_id 는 쓰지 않음, api.md 2.1) */
export interface StoreCheck {
  state: "purchased" | "pending" | "refunded";
  /** 가게 확인 결과의 계정 값 (기록·분쟁용, 권한 판단에 쓰지 않음) */
  accountId: string;
  /** 가게 쪽에서 이미 소모·확인됨 (Google consumptionState=1 또는 acknowledgementState=1) → 재claim 거절 */
  storeConsumed: boolean;
  /** 가게가 아는 구매 시각 (ms, 모르면 없음) — 보관 기간(5년)보다 오래된 영수증은 거절 */
  purchasedAt?: number;
}

export interface StoreCtx {
  env: Env;
  deps: Deps;
  now: number;
  /** 요청이 로컬 주소(127.0.0.1 · localhost)로 왔는가 — 가짜 가게 조건 */
  local: boolean;
}

/** 영수증이 가짜·불일치면 ApiError(422 invalid_receipt), 가게 장애면 ApiError(503 store_unavailable) 를 던짐 */
export type StoreVerifier = (input: VerifyInput, ctx: StoreCtx) => Promise<StoreCheck>;
