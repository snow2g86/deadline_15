extends Node
## 결제 백엔드 공통 틀 (결제층 A) — Billing 오토로드가 가게마다 하나를 자식으로 둔다.
##  모든 함수는 코루틴일 수 있다 (가게 SDK 는 비동기). Billing 은 늘 `await backend.x()` 로 부른다.
##
##  거래(tx) 사전 — 가게가 무엇이든 같은 모양:
##   { state: "purchased" | "pending" | "cancelled" | "failed",
##     store: "dev"|"stove"|"google"|"apple",  pid: 게임 안 상품 id,  spid: 가게 상품 id,
##     order_id: 가게 주문 번호 (STOVE TID · Google orderId(없으면 purchaseToken) · Apple transactionId),
##     receipt: 서버가 가게에 확인할 원본 (STOVE TID · Google purchaseToken · Apple JWS signedTransaction) — 게임은 해석하지 않음,
##     error: 실패 코드 (failed 일 때) }
##  지급(골드)은 백엔드가 하지 않는다 — Billing 이 서버 확인 → IapRules.grant → Store.flush 뒤에 finish(tx) 를 부른다.

## (6b) 백엔드가 스스로 '처리할 거래가 생겼음'을 알림 — 앱 밖에서 승인된 대기 결제(Ask to Buy · 편의점 결제) · 다른 길로 들어온 구매 · 프로모션 코드.
##  Billing 이 받아서 restore() 를 부름 (구매 창 흐름이 기다리는 거래는 알리지 않음)
signal unfinished_changed

## 가게 이름 (Platform.store() 와 같은 이름) · 결제 길이 없는 판이면 "none"
var store_name := "none"


## 이 판에 결제 길이 있는가 (없으면 상점 결제 카드를 숨김 — steam·백엔드 없음)
func is_supported() -> bool:
	return false


## (6b) 상품 목록 [{id, gold, google, apple, …}] (Billing 이 백엔드를 만든 직후 넘김) — query_unfinished 가 가게 상품 id → 게임 안 상품 id 로 바꿀 때 씀
func set_products(_products: Array) -> void:
	pass


## (6b) 가게 연결을 기다림 (SDK 가 비동기로 연결하는 가게 — Google Play · App Store). 연결되면 true. Billing 이 가격 조회·미처리 확인 앞에서 부름
func prepare() -> bool:
	return is_available()


## 지금 결제할 수 있는가 (SDK 초기화 끝 · 로그인 등). 길은 있는데 안 되면 카드는 보이되 꺼짐
func is_available() -> bool:
	return false


## 가게 가격 [{pid, price(가게가 준 현지 통화 글), currency}] — 못 받으면 [] (화면은 data 의 fallback_price)
func query_products(_products: Array) -> Array:
	return []


## 구매 창을 띄움 → tx (취소·실패도 tx 로)
func purchase(pid: String, _spid: String, _opts: Dictionary) -> Dictionary:
	return {"state": "failed", "store": store_name, "pid": pid, "error": "unavailable"}


## 아직 '처리 끝'을 알리지 않은 거래 (앱 시작·복귀·상점 진입 때 Billing 이 부름) → [tx]
func query_unfinished() -> Array:
	return []


## 지급이 디스크에 남은 뒤에만 부름: Google acknowledge+consume · Apple transaction.finish() · STOVE (소모 API 없음 — 서버 소모 기록 + 클라우드 세이브)
func finish(_tx: Dictionary) -> bool:
	return false
