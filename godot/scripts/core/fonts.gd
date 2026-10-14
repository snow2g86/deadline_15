extends RefCounted
## Fonts — 언어별 글꼴 사슬 (Noto Sans KR · JP · SC · TC, 모두 가변 굵기 wght, OFL — assets/fonts/OFL.txt)
##
##  한·중·일 통합 한자는 같은 코드라도 언어마다 글자 모양이 달라서, 언어마다 맨 앞 글꼴을 바꾸고 나머지를 대체 글꼴로 둔다.
##  (웹 css/common.css 의 :lang() --font-text 와 같은 순서)
##    ko·en·es: KR → JP → SC → TC      ja: JP → KR → SC      zh-CN: SC → TC → KR      zh-TW: TC → SC → KR
##  어느 언어에서든 한글·가나·간체·번체가 모두 사슬 안에 있어, 플레이어가 입력한 이름이 두부(□)로 나오지 않는다.
##
##  사용: Fonts.weight(700) → 그 굵기의 글꼴 (언어가 바뀌어도 같은 객체 — 안의 base_font·fallbacks 만 바꾸고 changed 를 보냄,
##        그래서 add_theme_font_override 로 붙인 글꼴도 바로 다시 그려짐). Fonts.weight(400) 은 기본 글꼴.
##        Fonts.for_lang(lang, w) → 화면 언어와 상관없이 그 언어 사슬 (설정 창 언어 이름 단추 등)
##        Fonts.apply_lang(lang) 은 I18n 이 언어를 정할 때 부름 (language_changed 보다 먼저) + 루트 창 테마 기본 글꼴도 맞춤.
##  메모리: 글꼴 파일은 처음 쓸 때 한 번만 읽고(4개 ≈ 50MB), 굵기마다 파일별 FontVariation(가벼운 객체)만 더 만든다.

const DIR := "res://assets/fonts/"
const FILES := {
	"kr": "NotoSansKR-VariableFont_wght.ttf",
	"jp": "NotoSansJP-VariableFont_wght.ttf",
	"sc": "NotoSansSC-VariableFont_wght.ttf",
	"tc": "NotoSansTC-VariableFont_wght.ttf",
}
const CHAINS := {
	"ko": ["kr", "jp", "sc", "tc"],
	"en": ["kr", "jp", "sc", "tc"],
	"es": ["kr", "jp", "sc", "tc"],
	"ja": ["jp", "kr", "sc"],
	"zh-CN": ["sc", "tc", "kr"],
	"zh-TW": ["tc", "sc", "kr"],
}
const DEFAULT_LANG := "ko"
const REGULAR := 400

static var lang: String = DEFAULT_LANG
static var _files: Dictionary = {}       # "kr" → FontFile
static var _vars: Dictionary = {}        # "kr:700" → FontVariation (파일 하나 + 굵기)
static var _live: Dictionary = {}        # 700 → FontVariation (지금 언어 사슬, 언어가 바뀌어도 같은 객체)
static var _fixed: Dictionary = {}       # "ja:700" → 고정 언어 사슬
static var _theme: Theme


## 지금 언어의 굵기 w 글꼴 (같은 굵기는 같은 객체)
static func weight(w: int = REGULAR) -> Font:
	if not _live.has(w):
		var fv := FontVariation.new()
		_fill(fv, lang, w)
		_live[w] = fv
	return _live[w]


## 화면 언어와 상관없이 lang 의 사슬 (언어 이름 단추처럼 그 언어 글자 모양으로 보여야 할 때)
static func for_lang(p_lang: String, w: int = REGULAR) -> Font:
	var code := p_lang if CHAINS.has(p_lang) else DEFAULT_LANG
	var k := "%s:%d" % [code, w]
	if not _fixed.has(k):
		var fv := FontVariation.new()
		_fill(fv, code, w)
		_fixed[k] = fv
	return _fixed[k]


## 언어 바꾸기 — 이미 만든 모든 굵기 글꼴의 사슬을 바꿔 끼움 (같은 언어면 아무것도 안 함)
static func apply_lang(p_lang: String) -> void:
	var code := p_lang if CHAINS.has(p_lang) else DEFAULT_LANG
	if code == lang and _theme != null:
		return
	lang = code
	for w: int in _live.keys():
		_fill(_live[w], lang, w)
	_apply_root_theme()


## 사슬 순서 (파일 키) — 시험용
static func chain_keys(p_lang: String) -> Array:
	return (CHAINS.get(p_lang, CHAINS[DEFAULT_LANG]) as Array).duplicate()


## 사슬의 파일 글꼴들 (Font.has_char 검사용 — 굵기와 상관없이 글자 유무는 같음)
static func chain_files(p_lang: String) -> Array[FontFile]:
	var out: Array[FontFile] = []
	for key: String in chain_keys(p_lang):
		out.append(_file(key))
	return out


## 사슬 안에 글자가 있는가 (맨 앞 글꼴부터 대체 글꼴까지)
static func chain_has_char(p_lang: String, ch: int) -> bool:
	for f: FontFile in chain_files(p_lang):
		if f.has_char(ch):
			return true
	return false


## 글꼴 파일 크기 합 (바이트, 보고용)
static func files_size() -> int:
	var total := 0
	for key: String in FILES.keys():
		var fa := FileAccess.open(DIR + String(FILES[key]), FileAccess.READ)
		if fa != null:
			total += fa.get_length()
	return total


static func loaded_files() -> PackedStringArray:
	return PackedStringArray(_files.keys())


# ── 내부 ──

static func _file(key: String) -> FontFile:
	if not _files.has(key):
		_files[key] = load(DIR + String(FILES[key]))
	return _files[key]


static func _var(key: String, w: int) -> FontVariation:
	var k := "%s:%d" % [key, w]
	if not _vars.has(k):
		var fv := FontVariation.new()
		fv.base_font = _file(key)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): w}
		_vars[k] = fv
	return _vars[k]


## fv 를 code 언어 사슬로: 맨 앞 파일 + 굵기, 대체 글꼴은 나머지 파일의 같은 굵기 (대체 글자도 굵게)
static func _fill(fv: FontVariation, code: String, w: int) -> void:
	var keys: Array = CHAINS.get(code, CHAINS[DEFAULT_LANG])
	var fbs: Array[Font] = []
	for i in range(1, keys.size()):
		fbs.append(_var(String(keys[i]), w))
	fv.base_font = _file(String(keys[0]))
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): w}
	fv.fallbacks = fbs


## 루트 창 테마 기본 글꼴 = 지금 언어 보통 굵기 (project.godot 의 gui/theme/custom_font(KR) 보다 앞섬 — 테마 없는 화면도 언어 글꼴로)
static func _apply_root_theme() -> void:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return
	var root: Window = (ml as SceneTree).root
	if root == null:
		return
	if _theme == null:
		_theme = root.theme if root.theme != null else Theme.new()
	_theme.default_font = weight(REGULAR)
	if root.theme != _theme:
		root.theme = _theme
