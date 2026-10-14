extends Node
## I18n — 번역 (웹 js/common/i18n.js 의 t() 와 같은 규칙)
##
##  t("hazard.safe_zone", {"i": "❄️", "r": 3})
##   - 점(.)으로 나눈 키를 중첩 사전에서 차례로 찾는다 (배열이면 숫자 키를 번호로)
##   - 없으면 키 그대로 돌려준다 (웹과 같음)
##   - {이름} 자리표시자를 params 값으로 바꾼다. params 에 없는 이름은 {이름} 그대로 둔다
##  언어: Store 의 game_settings.language → 없거나 모르는 언어면 ko
##  set_language(lang) 은 game_settings.language 에 저장하고 language_changed 신호를 보낸다.
##
##  웹과 다른 점: 웹은 설정이 없을 때 브라우저 언어(navigator.language)를 보지만, 여기서는 정해진 대로 ko 로 시작한다.

signal language_changed(lang: String)

const SETTINGS_KEY := "game_settings"
const FALLBACK_LANG := "ko"
const SUPPORTED: PackedStringArray = ["ko", "en", "es"]

# 오토로드 이름(Store·DataDB)을 직접 쓰면 --script 시험에서 컴파일이 안 되므로, 스크립트 형식 + /root 경로로 찾는다
const _StoreT := preload("res://scripts/core/store.gd")
const _DataDBT := preload("res://scripts/core/data_db.gd")
const _NumT := preload("res://scripts/core/num.gd")

var current_lang: String = FALLBACK_LANG

var _data: Dictionary = {}
var _placeholder := RegEx.create_from_string("\\{(\\w+)\\}")


func _ready() -> void:
	reload()


## Store 설정을 다시 읽어 언어를 정한다
func reload() -> void:
	_apply(_lang_from_settings())


## 번역 문자열 (없으면 키 그대로). 값이 배열·사전인 키는 문자열이 아니므로 키 그대로 → 그런 키는 t_raw 를 쓸 것
func t(key: String, params: Dictionary = {}) -> String:
	var val: Variant = resolve(key)
	if typeof(val) != TYPE_STRING:
		return key
	return interpolate(String(val), params)


## 웹 t() 와 똑같은 동작: 없으면 키, 문자열이면 자리표시자 치환, 배열·사전(battle.loading_tips, character.names)은 값 그대로
func t_raw(key: String, params: Dictionary = {}) -> Variant:
	var val: Variant = resolve(key)
	if val == null:
		return key
	if typeof(val) == TYPE_STRING:
		return interpolate(String(val), params)
	return val


## 키가 가리키는 값 그대로 (사전·배열일 수도 있음, 없으면 null) — 웹 _resolve
func resolve(key: String) -> Variant:
	return resolve_in(_data, key)


func has_key(key: String) -> bool:
	return typeof(resolve(key)) == TYPE_STRING


## 언어 바꾸기: 저장하고 신호를 보낸다. 모르는 언어면 false
func set_language(lang: String) -> bool:
	if not SUPPORTED.has(lang):
		push_warning("I18n: 지원하지 않는 언어 %s" % lang)
		return false
	var settings: Variant = _store().get_json(SETTINGS_KEY, {})
	var s: Dictionary = settings if settings is Dictionary else {}
	s["language"] = lang
	_store().set_json(SETTINGS_KEY, s)
	_apply(lang)
	return true


# ── 웹 i18n.js 와 같은 순수 함수 (시험·다른 언어 사전에도 쓸 수 있게 static) ──

static func resolve_in(root: Variant, key: String) -> Variant:
	var node: Variant = root
	for part: String in key.split("."):
		if node is Dictionary:
			var d: Dictionary = node
			if not d.has(part):
				return null
			node = d[part]
		elif node is Array and part.is_valid_int():
			var a: Array = node
			var i := part.to_int()
			if i < 0 or i >= a.size():
				return null
			node = a[i]
		else:
			return null
	return node


func interpolate(text: String, params: Dictionary) -> String:
	if params.is_empty():
		return text
	var out := ""
	var last := 0
	for m: RegExMatch in _placeholder.search_all(text):
		var name := m.get_string(1)
		out += text.substr(last, m.get_start() - last)
		out += _param_string(params[name]) if params.has(name) else m.get_string()
		last = m.get_end()
	out += text.substr(last)
	return out


# ── 내부 ──

func _apply(lang: String) -> void:
	var data: Dictionary = _db().lang(lang)
	if data.is_empty() and lang != FALLBACK_LANG:
		push_warning("I18n: %s 언어 팩이 없어 %s 로" % [lang, FALLBACK_LANG])
		lang = FALLBACK_LANG
		data = _db().lang(lang)
	_data = data
	var changed := lang != current_lang
	current_lang = lang
	if changed:
		language_changed.emit(lang)


func _lang_from_settings() -> String:
	var settings: Variant = _store().get_json(SETTINGS_KEY, null)
	if settings is Dictionary:
		var lang := String((settings as Dictionary).get("language", ""))
		if SUPPORTED.has(lang):
			return lang
	return FALLBACK_LANG


## 웹 문자열화와 같게: 정수 값 실수는 소수점 없이 (3.0 → "3"), null 은 "null" (Num.fmt)
static func _param_string(v: Variant) -> String:
	return _NumT.fmt(v)


func _store() -> _StoreT:
	return get_node("/root/Store") as _StoreT


func _db() -> _DataDBT:
	return get_node("/root/DataDB") as _DataDBT
