extends "res://scripts/core/billing/backend_base.gd"
## App Store (StoreKit 2) — 빈 틀 (모바일 작업에서 채움)
##  iOS 플러그인(StoreKit 2 를 감싼 GDExtension/플러그인)을 부를 예정. 상품 id 는 xyz.show4you.deadline15.gold_<양> (data/iap.json 의 apple).
##  채울 것:
##   is_available : AppStore.canMakePayments
##   query_products: Product.products(for:) → displayPrice
##   purchase     : product.purchase(options: [.appAccountToken(설치 식별자로 만든 UUID)]) →
##                  .success(verified) → state purchased, order_id = transaction.id, receipt = JWS(jwsRepresentation)
##                  .pending → pending (Ask to Buy) · .userCancelled → cancelled
##   query_unfinished: Transaction.unfinished (+ Transaction.updates 로 들어오는 것)
##   finish       : transaction.finish()

func _init() -> void:
	store_name = "apple"


func is_supported() -> bool:
	return true
