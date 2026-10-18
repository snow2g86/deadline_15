extends "res://scripts/core/billing/backend_base.gd"
## Google Play Billing — 빈 틀 (모바일 작업에서 채움)
##  Godot Android 플러그인(GodotGooglePlayBilling, Play Billing Library 7+)을 Engine.get_singleton 으로 부를 예정.
##  채울 것:
##   is_available : startConnection 성공
##   query_products: queryProductDetails(INAPP, [gold_500 …]) → formattedPrice
##   purchase     : launchBillingFlow (obfuscatedAccountId = 설치 식별자의 해시) → onPurchasesUpdated:
##                  PURCHASED → state purchased, order_id = orderId(없으면 purchaseToken), receipt = purchaseToken
##                  PENDING → pending · USER_CANCELED → cancelled · 그 밖 → failed
##   query_unfinished: queryPurchasesAsync(INAPP) — 소모하지 않은 것 (PENDING 이 PURCHASED 로 바뀐 것 포함)
##   finish       : consumeAsync(purchaseToken) (소모형 — 소모가 acknowledge 를 겸함. 3일 안에 안 하면 Google 이 자동 환불)

func _init() -> void:
	store_name = "google"


func is_supported() -> bool:
	return true
