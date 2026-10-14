extends Control
## 시작 화면 (1단계 기초 확인용)
##  - 게임 제목·메뉴 이름을 I18n 으로 표시
##  - 읽어 들인 데이터 모듈과 전역 개수, DataDB 검증 결과 표시
##  - ko / en / es 버튼으로 언어 바꾸기 (Store 의 game_settings.language 에 저장)
##  - (3a) 전투 시험 실행기: 스테이지·시드·파티(저장된 파티 또는 디버그 세이브)를 골라 전투 장면으로
## 화면 코드는 여기만: 데이터·규칙은 DataDB / scripts/logic 쪽에 둔다.

const BattleScene := preload("res://scripts/battle/battle_scene.gd")
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
## 디버그 세이브로 쓸 수 있는 황금 기록 (tests/golden — 가짜 세이브·파티가 들어 있음)
const DEBUG_SAVES := ["balanced_s05", "legion5_s09", "assassins_s06", "knights_s11", "boss_s10", "abyss_s19", "siege_items_s13", "gear_s15", "swamp_s21", "drill_s35"]

const BG_COLOR := Color("0f1420")
const GOLD := Color("f0c040")
const TEXT_DIM := Color("9aa4b8")

var _title: Label
var _subtitle: Label
var _sample: Label
var _status: Label
var _modules: Label
var _lang_buttons: Dictionary = {}   # 언어 코드 → Button
var _stage_spin: SpinBox
var _seed_spin: SpinBox
var _src_opt: OptionButton
var _replay_chk: CheckBox
var _launch_info: Label


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
	_build_launcher(box)


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


# ═══════════ 전투 시험 실행기 (3a 디버그) ═══════════

func _build_launcher(box: VBoxContainer) -> void:
	var sep := HSeparator.new()
	box.add_child(sep)
	var head := _label(16, GOLD)
	head.text = "전투 시험 (3a 디버그 실행기)"
	box.add_child(head)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(_small("스테이지"))
	_stage_spin = SpinBox.new()
	var stages: Array = DataDB.global("STAGES")
	_stage_spin.min_value = 1
	_stage_spin.max_value = maxi(1, stages.size())
	_stage_spin.value = 5
	row.add_child(_stage_spin)
	row.add_child(_small("시드"))
	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 0
	_seed_spin.max_value = 2147483647
	_seed_spin.value = int(Time.get_unix_time_from_system()) % 100000
	row.add_child(_seed_spin)
	row.add_child(_small("파티"))
	_src_opt = OptionButton.new()
	if _has_store_party():
		_src_opt.add_item("저장된 파티 (Store)")
		_src_opt.set_item_metadata(_src_opt.item_count - 1, "store")
	for g: String in DEBUG_SAVES:
		_src_opt.add_item("디버그 세이브: " + g)
		_src_opt.set_item_metadata(_src_opt.item_count - 1, g)
	row.add_child(_src_opt)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 12)
	box.add_child(row2)
	_replay_chk = CheckBox.new()
	_replay_chk.text = "황금 기록 그대로 자동 재생 (스테이지·시드 무시)"
	row2.add_child(_replay_chk)
	var go := Button.new()
	go.text = "전투 시작"
	go.custom_minimum_size = Vector2(160, 40)
	go.pressed.connect(_launch)
	row2.add_child(go)
	var warn := _label(12, Color("fbbf24"))
	warn.text = "※ '저장된 파티 (Store)' 로 시작하면 전투 결과(골드·경험치·보상)가 실제 세이브에 저장됩니다. 디버그 세이브는 저장하지 않습니다."
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(warn)
	_launch_info = _label(12, TEXT_DIM)
	_launch_info.text = "Q/E 회전 · 휠 확대 · 끌어서 이동 · T 위협 범위 · M/A/S/I/D/O/W/P 행동 · Esc 취소"
	box.add_child(_launch_info)


func _small(t: String) -> Label:
	var l := _label(13, TEXT_DIM)
	l.text = t
	return l


## Store 에 활성 파티가 있는지 (로스터 + 파티 슬롯)
func _has_store_party() -> bool:
	var parties: Variant = Store.get_json("game_parties")
	var roster: Variant = Store.get_json("game_roster")
	if typeof(parties) != TYPE_DICTIONARY or typeof(roster) != TYPE_DICTIONARY:
		return false
	for p: Dictionary in parties.get("parties", []):
		if p.get("id") == parties.get("activePartyId"):
			for sl: Variant in p.get("slots", []):
				if sl != null:
					return true
	return false


func _launch() -> void:
	var src: String = str(_src_opt.get_item_metadata(_src_opt.selected))
	var cfg: Dictionary
	if src == "store":
		var save: Dictionary = {}
		for k: String in ["game_save", "game_roster", "game_parties", "game_inventory"]:
			var v: Variant = Store.get_json(k)
			if v != null:
				save[k] = v
		cfg = {"save": save, "source": "store"}
	elif _replay_chk.button_pressed:
		cfg = BattleScene.golden_cfg(src)
		cfg["autoplay"] = src
	else:
		cfg = BattleScene.golden_cfg(src)
		cfg["inject"] = []
		cfg["maxRounds"] = 0
	if not _replay_chk.button_pressed or src == "store":
		cfg["stage"] = {"id": int(_stage_spin.value)}
		cfg["seed"] = int(_seed_spin.value)
		cfg["practice"] = false
	cfg["speed"] = 1.0
	BattleScene.pending = cfg
	get_tree().change_scene_to_file(BATTLE_SCENE)
