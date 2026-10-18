extends "res://scripts/core/billing/backend_base.gd"
## 결제 길이 없는 판 (steam — 맨 뒤로 미룸, 출시 빌드의 dev 등). 상점 결제 카드를 숨긴다.

func _init(name_: String = "none") -> void:
	store_name = name_
