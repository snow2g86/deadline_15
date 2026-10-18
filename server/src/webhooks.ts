// POST /v1/webhooks/apple — App Store Server Notifications V2 (서명된 signedPayload)
//  App Store Connect → 앱 → App 정보 → App Store 서버 알림 에 이 주소를 넣음 (Production · Sandbox 각각)
//  REFUND · REVOKE → refunds 에 기록 (게임은 /v1/refunds 로 받아 회수).
//  REFUND_REVERSED → 환불 기록을 지우고 주문 상태를 되돌림. 게임이 이미 회수한 골드는 돌려주지 않음 (정책 — api.md 3.4b)
//  CONSUMPTION_REQUEST (Apple 이 환불 심사용 소비 정보를 요청) · 그 밖의 알림 → 받기만 함 (200, 응답하지 않음)
//  서명이 틀리면 422 invalid_receipt (Apple 은 2xx 가 아니면 다시 보냄 — 가짜 요청은 계속 거절됨)
import { ApiError, ok } from "./http";
import { recordRefund, reverseRefund } from "./db";
import { checkTransaction, decodeAppleJws, type AppleTransaction } from "./stores/apple";
import type { StoreCtx } from "./stores/types";

const REFUND_TYPES = new Set(["REFUND", "REVOKE"]);

export async function appleNotification(b: Record<string, unknown>, ctx: StoreCtx): Promise<Response> {
  if (!ctx.env.STORES.split(",").map((s) => s.trim()).includes("apple")) throw new ApiError(404, "not_found", "unknown endpoint");
  if (typeof b.signedPayload !== "string") throw new ApiError(400, "bad_request", "missing signedPayload");
  const n = (await decodeAppleJws(ctx.env, b.signedPayload, ctx.now)) as {
    notificationType?: string;
    notificationUUID?: string;
    data?: { bundleId?: string; environment?: string; signedTransactionInfo?: string };
    signedDate?: number;
  };
  const data = n.data ?? {};
  checkTransaction(ctx.env, { bundleId: data.bundleId, environment: data.environment });
  const type = String(n.notificationType ?? "");
  if (REFUND_TYPES.has(type)) {
    if (typeof data.signedTransactionInfo !== "string") throw new ApiError(400, "bad_request", "missing signedTransactionInfo");
    const t = (await decodeAppleJws(ctx.env, data.signedTransactionInfo, ctx.now)) as AppleTransaction;
    checkTransaction(ctx.env, t);
    if (!t.transactionId) throw new ApiError(400, "bad_request", "missing transactionId");
    const at = typeof t.revocationDate === "number" ? t.revocationDate : typeof n.signedDate === "number" ? n.signedDate : ctx.now;
    await recordRefund(ctx.env.DB, "apple", String(t.transactionId), at, "apple_notif");
  } else if (type === "REFUND_REVERSED") {
    if (typeof data.signedTransactionInfo !== "string") throw new ApiError(400, "bad_request", "missing signedTransactionInfo");
    const t = (await decodeAppleJws(ctx.env, data.signedTransactionInfo, ctx.now)) as AppleTransaction;
    checkTransaction(ctx.env, t);
    if (!t.transactionId) throw new ApiError(400, "bad_request", "missing transactionId");
    await reverseRefund(ctx.env.DB, "apple", String(t.transactionId));
  }
  console.log(JSON.stringify({ at: "apple_notification", type, uuid: n.notificationUUID ?? "" }));
  return ok({});
}
