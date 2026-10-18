// STOVE (PC) — 결제 확인 API 는 api.md 에서 '확인 필요' (API 이름 · 인증 방식 · 환불 내역).
//  공식 문서(studio-docs.onstove.com → developers-beta.onstove.com 로 옮겨짐)에서 단건 확인 API 의 주소·인증을 확정하지 못해 인터페이스만 둠 → 501.
//  게임은 5xx 를 '다시 시도'로 다루므로, STOVE 결제는 지급되지 않고 가게에 미처리로 남음 (중복 지급 0).
//  확정되면 할 일: TID 로 결제 조회 → 상태·아이템 id(stove_item)·회원 번호 → accountId = stoveAccountId(STOVE_ACCT_KEY, memberNo).
import { ApiError } from "../http";
import { hmacSha256Hex } from "../crypto/enc";
import type { StoreVerifier } from "./types";

/** STOVE 회원 번호는 저장하지 않고 HMAC-SHA256(STOVE_ACCT_KEY, memberNo) 16진수로만 (api.md 2.1) */
export async function stoveAccountId(acctKey: string, memberNo: string | number): Promise<string> {
  if (!acctKey) throw new ApiError(503, "store_unavailable", "STOVE account key is not configured");
  return hmacSha256Hex(acctKey, String(memberNo));
}

export const verifyStove: StoreVerifier = async () => {
  throw new ApiError(501, "not_implemented", "STOVE purchase verification is not implemented yet");
};
