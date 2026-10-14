extends Node
## I18n — 번역 (웹 js/common/i18n.js 의 t() 와 같은 규칙)
##
##  t("hazard.safe_zone", {"i": "❄️", "r": 3})
##   - 점(.)으로 나눈 키를 중첩 사전에서 차례로 찾는다 (배열이면 숫자 키를 번호로)
##   - 없으면 키 그대로 돌려준다 (웹과 같음)
##   - {이름} 자리표시자를 params 값으로 바꾼다. params 에 없는 이름은 {이름} 그대로 둔다
##  언어(웹과 같은 규칙): Store 의 game_settings.language 가 LANGS 에 있으면 그것 → 아니면 OS 언어(OS.get_locale, 웹 navigator.language)
##   에서 고름 (detect_lang: ko·es·en·ja, zh-TW·zh-HK·zh-MO·zh-Hant → zh-TW, 그 밖의 zh → zh-CN,
##   그 밖의 언어(fr·de·pt 등)나 빈 값이면 en = DETECT_FALLBACK). 언어 팩 파일이 없으면 ko(FALLBACK_LANG).
##  set_language(lang) 은 game_settings.language 에 저장하고 language_changed 신호를 보낸다.
##  글꼴: 언어를 정할 때마다 Fonts.apply_lang(lang) 을 먼저 불러 한자 글자 모양이 맞는 글꼴 사슬로 바꾼다 (scripts/core/fonts.gd).

signal language_changed(lang: String)

const SETTINGS_KEY := "game_settings"
const FALLBACK_LANG := "ko"   # 언어 팩을 못 읽을 때
## 지원하지 않는 OS 언어(fr·de·pt 등)·빈 값일 때 (웹 _detectLang 과 같음)
const DETECT_FALLBACK := "en"
## 지원 언어 (웹 js/common/i18n.js _I18N_LANGS 와 같은 순서 = 설정 화면 순서)
const LANGS: PackedStringArray = ["ko", "en", "es", "ja", "zh-CN", "zh-TW"]
const SUPPORTED: PackedStringArray = LANGS

# 오토로드 이름(Store·DataDB)을 직접 쓰면 --script 시험에서 컴파일이 안 되므로, 스크립트 형식 + /root 경로로 찾는다
const _StoreT := preload("res://scripts/core/store.gd")
const _DataDBT := preload("res://scripts/core/data_db.gd")
const _NumT := preload("res://scripts/core/num.gd")
const _FontsT := preload("res://scripts/core/fonts.gd")

var current_lang: String = FALLBACK_LANG

var _data: Dictionary = {}
## Godot 전용 추가 키 (res://data/lang_extra/<언어>.json) — 웹 언어 팩에 없는 키만 더함 (웹 키가 늘 우선)
const EXTRA_DIR := "res://data/lang_extra/"
var _extra_cache: Dictionary = {}   # 언어 → 합친 사전
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
	_data = _with_extra(lang, data)
	_FontsT.apply_lang(lang)
	var changed := lang != current_lang
	current_lang = lang
	if changed:
		language_changed.emit(lang)


## 웹 언어 팩 + Godot 전용 키 (lang_extra). 웹 사전은 고치지 않고 사본에 없는 키만 깊게 더함
func _with_extra(lang: String, data: Dictionary) -> Dictionary:
	if _extra_cache.has(lang):
		return _extra_cache[lang]
	var out := data
	var path := EXTRA_DIR + lang + ".json"
	if FileAccess.file_exists(path):
		var ex: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if ex is Dictionary:
			out = data.duplicate(true)
			_merge_missing(out, ex)
		else:
			push_warning("I18n: %s 를 읽지 못했습니다" % path)
	_extra_cache[lang] = out
	return out


static func _merge_missing(dst: Dictionary, src: Dictionary) -> void:
	for k: Variant in src.keys():
		if not dst.has(k):
			dst[k] = src[k]
		elif dst[k] is Dictionary and src[k] is Dictionary:
			_merge_missing(dst[k], src[k])


func _lang_from_settings() -> String:
	var settings: Variant = _store().get_json(SETTINGS_KEY, null)
	if settings is Dictionary:
		var lang := String((settings as Dictionary).get("language", ""))
		if SUPPORTED.has(lang):
			return lang
	return detect_lang(OS.get_locale())


## OS·브라우저 언어 코드 → 지원 언어 (웹 i18n.js _detectLang 과 같음). "ja_JP"·"zh-Hant-TW"·"zh_TW" 처럼 _ 와 - 모두 받음
static func detect_lang(locale: String) -> String:
	var nav := locale.to_lower().replace("_", "-")
	if nav == "ko" or nav.begins_with("ko-"):
		return "ko"
	if nav.begins_with("es"):
		return "es"
	if nav.begins_with("en"):
		return "en"
	if nav.begins_with("ja"):
		return "ja"
	if nav == "zh" or nav.begins_with("zh-"):
		var parts := nav.split("-")
		if parts.has("hans"):
			return "zh-CN"
		if parts.has("hant") or parts.has("tw") or parts.has("hk") or parts.has("mo"):
			return "zh-TW"
		return "zh-CN"
	return DETECT_FALLBACK


## 웹 문자열화와 같게: 정수 값 실수는 소수점 없이 (3.0 → "3"), null 은 "null" (Num.fmt)
static func _param_string(v: Variant) -> String:
	return _NumT.fmt(v)


func _store() -> _StoreT:
	return get_node("/root/Store") as _StoreT


func _db() -> _DataDBT:
	return get_node("/root/DataDB") as _DataDBT
