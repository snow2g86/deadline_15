extends Control
## 시작 화면 (1단계 기초 확인용)
##  - 게임 제목·메뉴 이름을 I18n 으로 표시
##  - 읽어 들인 데이터 모듈과 전역 개수, DataDB 검증 결과 표시
##  - ko / en / es 버튼으로 언어 바꾸기 (Store 의 game_settings.language 에 저장)
## 화면 코드는 여기만: 데이터·규칙은 DataDB / scripts/logic 쪽에 둔다.

const BG_COLOR := Color("0f1420")
const GOLD := Color("f0c040")
const TEXT_DIM := Color("9aa4b8")

var _title: Label
var _subtitle: Label
var _sample: Label
var _status: Label
var _modules: Label
var _lang_buttons: Dictionary = {}   # 언어 코드 → Button


func _ready() -> void:
	_build()
	I18n.language_changed.connect(func(_lang: String) -> void: _refresh())
	_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(720, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	_title = _label(56, GOLD)
	box.add_child(_title)
	_subtitle = _label(22, Color.WHITE)
	box.add_child(_subtitle)
	_sample = _label(16, TEXT_DIM)
	_sample.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_sample)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for code: String in I18n.SUPPORTED:
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 44)
		b.toggle_mode = true
		b.pressed.connect(I18n.set_language.bind(code))
		row.add_child(b)
		_lang_buttons[code] = b

	_status = _label(16, Color.WHITE)
	box.add_child(_status)
	_modules = _label(14, TEXT_DIM)
	_modules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_modules)


func _refresh() -> void:
	_title.text = I18n.t("common.game_title")
	_subtitle.text = "%s · %s · %s" % [I18n.t("nav.sortie"), I18n.t("nav.party"), I18n.t("nav.settings")]
	var safe: Dictionary = DataDB.global("SAFE_ZONE")
	_sample.text = I18n.t("hazard.safe_zone", {"i": safe.get("icon", ""), "r": safe.get("every", 0)})

	for code: String in _lang_buttons.keys():
		var b: Button = _lang_buttons[code]
		b.text = I18n.t("settings.language_" + code)
		b.set_pressed_no_signal(code == I18n.current_lang)

	if DataDB.is_ok():
		_status.text = "DataDB OK · %s: %s" % [I18n.t("settings.language"), I18n.current_lang]
		_status.add_theme_color_override("font_color", Color("6ee7a0"))
	else:
		_status.text = "DataDB 오류 %d개 — %s" % [DataDB.errors.size(), DataDB.errors[0]]
		_status.add_theme_color_override("font_color", Color("ff6b6b"))

	var parts := PackedStringArray()
	var summary: Dictionary = DataDB.summary()
	for name: String in summary.keys():
		parts.append("%s %d" % [name, summary[name]])
	var stages: Array = DataDB.global("STAGES")
	var episodes: Dictionary = DataDB.story(I18n.current_lang).get("episodes", {})
	_modules.text = "%s\nSTAGES %d · lang %s · story episodes %d" % [
		" · ".join(parts), stages.size(), ",".join(DataDB.lang_codes()), episodes.size()]


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
