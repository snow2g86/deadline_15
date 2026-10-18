extends "res://scripts/core/billing/backend_base.gd"
## STOVE PC (Windows 64비트) — 빈 틀 (결제층 B 에서 채움)
##  STOVE PC SDK 는 Windows 64비트 C++ DLL → GDExtension 으로 감싸 Engine.get_singleton("StovePC") 같은 이름으로 부를 예정.
##  채울 것:
##   is_available : SDK 초기화(StovePC_Init) + 로그인 끝 · Windows 64비트에서만
##   query_products: 상점 아이템 조회 (아이템 id = 게임 안 id: gold_500 …) → 원화 가격 글
##   purchase     : 결제 창 → 결과의 TID 를 order_id·receipt 로 (state purchased / cancelled / failed)
##   query_unfinished: 구매 내역 중 game_iap 기록에 없는 것 (STOVE 는 소모 API 가 없음)
##   finish       : 가게 쪽 할 일 없음 — Billing 이 서버 consume 을 먼저 부르고, game_iap 는 STOVE 클라우드 세이브에 함께 올림
##  계정 식별자: STOVE 회원 번호(memberNo) → 서버 account_id

func _init() -> void:
	store_name = "stove"


## 결제 길은 Windows 판에만 (STOVE PC SDK = Windows 64비트 DLL). 맥 판은 결제 카드를 숨김.
##  Windows 에서는 카드가 보이되, SDK 를 붙이기 전에는 꺼짐 (is_available false)
func is_supported() -> bool:
	var pf: Node = get_node_or_null("/root/Platform")
	return (str(pf.call("os_name")) if pf != null else OS.get_name()) == "Windows"
