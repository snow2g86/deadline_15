extends RefCounted
## 규칙 계산용 저장소 — 웹 Store(localStorage: 키 → JSON 문자열)와 같은 의미를 메모리에서 흉내
##  get_json 은 늘 새 복사본(웹의 JSON.parse), set_json 도 복사해 넣음(웹의 JSON.stringify) → 꺼낸 객체를 고쳐도 저장값은 그대로
##  숫자 키 규칙은 scripts/core/json_norm.gd 와 같음 (uid·lv·x·y·id … 는 int)
##  화면용 Store 오토로드와 분리해 둔 이유: 전투 규칙은 오토로드 없이(시험·시뮬레이션) 돌 수 있어야 하므로.
##  실제 게임에서는 전투 시작 때 Store 의 값을 넣고(load_from), 끝나면 dump() 를 Store 로 되돌려 쓴다.

const Js := preload("res://scripts/logic/js.gd")
const JsonNorm := preload("res://scripts/core/json_norm.gd")

var _mem: Dictionary = {}   # 키 → 값 (JSON 해석된 Variant)


func has(key: String) -> bool:
	return _mem.has(key)


## Store.getJSON — 없으면 null
func get_json(key: String) -> Variant:
	if not _mem.has(key):
		return null
	return Js.deep(_mem[key])


func set_json(key: String, v: Variant) -> void:
	_mem[key] = JsonNorm.normalize_store(key, _json_clean(v))


func remove(key: String) -> void:
	_mem.erase(key)


func keys() -> Array:
	return _mem.keys()


## 사전 하나로 (키 → 값 복사본)
func dump() -> Dictionary:
	var o: Dictionary = {}
	for k: String in _mem.keys():
		o[k] = Js.deep(_mem[k])
	return o


## { 키: 값 } 을 통째로 넣기 (값은 JSON 해석된 것 — 황금 기록의 save, Store 오토로드의 get_json 결과)
func load_from(d: Dictionary) -> void:
	for k: String in d.keys():
		set_json(k, d[k])


## JSON.stringify 처럼: NaN·INF → null, 키는 문자열(숫자 키는 문자열로)
static func _json_clean(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var o: Dictionary = {}
			for k: Variant in d.keys():
				o[str(k) if typeof(k) != TYPE_STRING else k] = _json_clean(d[k])
			return o
		TYPE_ARRAY:
			var a: Array = v
			var o2: Array = []
			for x: Variant in a:
				o2.append(_json_clean(x))
			return o2
		TYPE_FLOAT:
			var f: float = v
			if is_nan(f) or is_inf(f):
				return null
			return f
	return v
