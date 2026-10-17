extends "res://scripts/logic/save_store.gd"
## 진짜 Store(오토로드, 디스크)를 규칙 저장소(SaveStore) 모양으로 감싼 것 — 바깥 화면(로비·스테이지·편성)의 규칙이 쓴다.
##  규칙 코드(profile.gd · party_rules.gd …)는 c.store.get_json(k) / set_json / remove / keys 만 쓰므로,
##  전투(메모리 SaveStore)와 바깥 화면(진짜 Store)이 같은 규칙 함수를 그대로 함께 쓴다.
##  읽기는 Store.get_json(웹 JSON.parse — 늘 새 사본), 쓰기는 웹 JSON.stringify 처럼 NaN·INF → null.

var node: Node


func _init(store_node: Node) -> void:
	node = store_node


func has(key: String) -> bool:
	return bool(node.call("has", key))


func get_json(key: String) -> Variant:
	return node.call("get_json", key, null)


func set_json(key: String, v: Variant) -> void:
	node.call("set_json", key, _json_clean(v))


func remove(key: String) -> void:
	node.call("remove", key)


func keys() -> Array:
	return Array(node.call("keys"))


func dump() -> Dictionary:
	var o: Dictionary = {}
	for k: String in keys():
		o[k] = get_json(k)
	return o


func load_from(d: Dictionary) -> void:
	for k: String in d.keys():
		set_json(k, d[k])


## 웹 Store.get (문자열 그대로, 없으면 null) — ps_can_start 처럼 JSON 이 아닌 값
func get_str(key: String) -> Variant:
	return node.call("get_str", key)


func set_str(key: String, v: String) -> void:
	node.call("set_str", key, v)
