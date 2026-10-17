extends Control
## 설정 — 웹 #settings-btn · #settings-panel (render.js toggleSettings·syncSettingsUI·surrender): 배경음·효과음(켜기·음량 — 소리는 5단계,
##  지금은 값만 저장), 게임 속도(1x·2x·4x), 움직임 줄이기, 언어(바로 바뀜), 닫기, 항복(확인 창)
##  값은 Store game_settings 에 웹과 같은 키(bgmOn·bgmVol·sfxOn·sfxVol·language)로, Godot 전용은 playSpeed·reduceMotion
##  읽기·쓰기 규칙은 바깥 설정 화면과 같은 scripts/logic/settings_rules.gd

const Kit := preload("res://scripts/battle/ui_kit.gd")

signal surrender_confirmed
## (4b-1) 저장하고 로비로 — 실제 세이브 전투에서만 단추가 보임 (allow_leave)
signal leave_confirmed
signal speed_chosen(i: int)
signal reduce_motion_changed(on: bool)
signal opened_changed(open: bool)

const Fonts := preload("res://scripts/core/fonts.gd")
const I18nT := preload("res://scripts/core/i18n.gd")

const SettingsRules := preload("res://scripts/logic/settings_rules.gd")
const KEY := SettingsRules.KEY
const LANGS: PackedStringArray = I18nT.LANGS
const SPEEDS := SettingsRules.SPEEDS

var store: Node
var i18n: Node
var btn: Button
var backdrop: Control
var panel: PanelContainer
var confirm: PanelContainer
var confirm_wrap: CenterContainer   # 확인 창은 화면 가운데 고정 (줄바꿈 글자 높이가 정해지기 전 위치 계산 문제 없음)
var _box: VBoxContainer
var s := SettingsRules.defaults()
var allow_leave := false
var _confirm_kind := "surrender"


func setup(p_store: Node, p_i18n: Node) -> void:
	store = p_store
	i18n = p_i18n
	name = "Settings"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	load_settings()
	btn = Button.new()
	btn.name = "SettingsBtn"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(44, 44)
	btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	btn.position = Vector2(12, 0)
	var round_sb := Kit.box(Color(17 / 255.0, 24 / 255.0, 39 / 255.0, 0.85), Color(1, 1, 1, 0.15), 22, 2, 0, 0)
	btn.add_theme_stylebox_override("normal", round_sb)
	btn.add_theme_stylebox_override("hover", Kit.box(Color(30 / 255.0, 41 / 255.0, 59 / 255.0, 0.95), Kit.GOLD, 22, 2, 0, 0))
	btn.add_theme_stylebox_override("pressed", Kit.box(Color(30 / 255.0, 41 / 255.0, 59 / 255.0, 0.95), Kit.GOLD, 22, 2, 0, 0))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := Kit.VecIcon.new()
	ic.kind = "gear"
	ic.color = Kit.DIM
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 10
	ic.offset_top = 10
	ic.offset_right = -10
	ic.offset_bottom = -10
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(ic)
	btn.mouse_entered.connect(func() -> void: ic.color = Kit.GOLD; ic.queue_redraw())
	btn.mouse_exited.connect(func() -> void: ic.color = Kit.DIM; ic.queue_redraw())
	btn.pressed.connect(toggle)
	add_child(btn)
	backdrop = Control.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.visible = false
	backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			close())
	add_child(backdrop)
	panel = PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.add_theme_stylebox_override("panel", Kit.box(Kit.PANEL, Color(1, 1, 1, 0.12), 12, 2, 20, 16))
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_box.custom_minimum_size = Vector2(300, 0)
	panel.add_child(_box)
	confirm = PanelContainer.new()
	confirm.name = "SurrenderConfirm"
	confirm.add_theme_stylebox_override("panel", Kit.box(Kit.PANEL, Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.55), 12, 2, 22, 18))
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_wrap = CenterContainer.new()
	confirm_wrap.name = "ConfirmWrap"
	confirm_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_wrap.visible = false
	confirm_wrap.add_child(confirm)
	add_child(confirm_wrap)


func place(bottom_y: float) -> void:
	btn.position = Vector2(12, bottom_y - 44.0)


func t(k: String, p: Dictionary = {}) -> String:
	return i18n.t(k, p) if i18n != null else k


## 언어 이름 (설정 키 "日本語 (Japanese)" 의 앞부분 — 웹 설정 화면과 같은 키)
func native_name(code: String) -> String:
	var full := t("settings.language_" + code)
	var cut := full.find(" (")
	return full.substr(0, cut) if cut > 0 else full


func load_settings() -> void:
	if store == null:
		return
	SettingsRules.load_into(store, s)


## 웹 saveSett: 다른 페이지가 쓴 값(언어 등)은 그대로 두고 바꾼 값만 덮어씀
func save_settings() -> void:
	SettingsRules.save_from(store, s)


func is_open() -> bool:
	return panel.visible or confirm_wrap.visible


## 확인 창이 떠 있는가 (시험용)
func confirm_open() -> bool:
	return confirm_wrap.visible


func toggle() -> void:
	if panel.visible:
		close()
	else:
		open()


func open() -> void:
	load_settings()
	_build()
	panel.visible = true
	backdrop.visible = true
	_place_panel()
	opened_changed.emit(true)


## 설정 창 자리: 톱니 단추 오른쪽, 아래를 단추에 맞춤 — 글자 높이가 정해진 다음 프레임에 다시 맞추고 화면 안으로
func _place_panel() -> void:
	for i in 2:
		panel.reset_size()
		var vs := get_viewport_rect().size
		var sz := panel.get_combined_minimum_size()
		panel.size = sz
		panel.position = Vector2(clampf(64.0, 8.0, maxf(8.0, vs.x - sz.x - 8.0)), clampf(btn.position.y + 44.0 - sz.y, 8.0, maxf(8.0, vs.y - sz.y - 8.0)))
		if i == 0:
			await get_tree().process_frame
			if not panel.visible:
				return


func close() -> void:
	panel.visible = false
	confirm_wrap.visible = false
	backdrop.visible = false
	opened_changed.emit(false)


func relabel() -> void:
	if panel.visible:
		_build()
		_place_panel()
	if confirm_wrap.visible:
		ask_confirm(_confirm_kind)


func _build() -> void:
	for c: Node in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	_box.add_child(title)
	title.add_child(_icon("gear", 16))
	var tl := Kit.label(15, Kit.GOLD, 700)
	tl.text = t("settings.title")
	title.add_child(tl)
	_box.add_child(_divider())
	_toggle_row("music", t("settings.bgm"), "bgmOn")
	_slider_row(t("settings.volume"), "bgmVol")
	_toggle_row("sound", t("settings.sfx"), "sfxOn")
	_slider_row(t("settings.volume"), "sfxVol")
	_box.add_child(_divider())
	# 게임 속도 (웹은 0.5~2.0 늘이기 배율 — 여기는 연출 재생 배율 1·2·4)
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 6)
	_box.add_child(sr)
	sr.add_child(_icon("speed", 14))
	var sl := Kit.label(13, Kit.TEXT, 700)
	sl.text = t("settings.game_speed")
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sr.add_child(sl)
	for i in SPEEDS.size():
		var b := Kit.button("%dx" % SPEEDS[i], Kit.GOLD, 12, Vector2(44, 28))
		b.name = "Speed%d" % SPEEDS[i]
		if int(s["playSpeed"]) == SPEEDS[i]:
			b.add_theme_stylebox_override("normal", Kit.box(Color(Kit.GOLD, 0.25), Kit.GOLD, 5, 1, 12, 5))
		var idx := i
		b.pressed.connect(func() -> void:
			s["playSpeed"] = SPEEDS[idx]
			save_settings()
			speed_chosen.emit(idx)
			_build())
		sr.add_child(b)
	var rm := _toggle_row("eye", t("gd.settings.reduce_motion"), "reduceMotion")
	rm.tooltip_text = t("gd.settings.reduce_motion_tip")
	# 언어 (바로 바뀜)
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 6)
	_box.add_child(lr)
	lr.add_child(_icon("globe", 14))
	var ll := Kit.label(13, Kit.TEXT, 700)
	ll.text = t("settings.language")
	ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lr.add_child(ll)
	# 6개 언어 — 단추 글자는 그 언어 이름 그대로(한국어·English·…·繁體中文), 글꼴도 그 언어 사슬 (화면 언어와 상관없이 맞는 한자 모양)
	var lg := GridContainer.new()
	lg.name = "LangGrid"
	lg.columns = 3
	lg.add_theme_constant_override("h_separation", 6)
	lg.add_theme_constant_override("v_separation", 6)
	_box.add_child(lg)
	for code: String in LANGS:
		var lb := Kit.button(native_name(code), Kit.GOLD, 12, Vector2(96, 28))
		lb.name = "Lang_" + code
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.tooltip_text = t("settings.language_" + code)
		lb.add_theme_font_override("font", Fonts.for_lang(code, 700))
		if i18n != null and str(i18n.get("current_lang")) == code:
			lb.add_theme_stylebox_override("normal", Kit.box(Color(Kit.GOLD, 0.25), Kit.GOLD, 5, 1, 12, 5))
		lb.pressed.connect(func() -> void:
			if i18n != null:
				i18n.call("set_language", code))
		lg.add_child(lb)
	_box.add_child(_divider())
	var br := HBoxContainer.new()
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	br.add_theme_constant_override("separation", 6)
	_box.add_child(br)
	var cb := Kit.button(t("common.close"), Kit.GOLD, 12)
	cb.name = "Close"
	cb.pressed.connect(close)
	br.add_child(cb)
	var sb := Kit.button(t("battle.surrender"), Kit.RED, 12)
	sb.name = "Surrender"
	sb.add_theme_color_override("font_color", Kit.RED)
	sb.add_theme_stylebox_override("normal", Kit.box(Color(1, 1, 1, 0.06), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.3), 5, 1, 12, 5))
	sb.pressed.connect(ask_surrender)
	br.add_child(sb)
	if allow_leave:
		var lb := Kit.button(t("gd.settings.leave"), Kit.GOLD, 12)
		lb.name = "Leave"
		lb.tooltip_text = t("gd.settings.leave_tip")
		lb.pressed.connect(func() -> void: ask_confirm("leave"))
		br.add_child(lb)


func _icon(kind: String, sz: float) -> Control:
	var ic := Kit.VecIcon.new()
	ic.kind = kind
	ic.custom_minimum_size = Vector2(sz, sz)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func _divider() -> Control:
	var d := ColorRect.new()
	d.color = Color(1, 1, 1, 0.06)
	d.custom_minimum_size = Vector2(0, 1)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


func _toggle_row(icon: String, label: String, key: String) -> Control:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	_box.add_child(r)
	r.add_child(_icon(icon, 14))
	var l := Kit.label(13, Kit.TEXT, 700)
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	var cb := CheckButton.new()
	cb.name = "Toggle_" + key
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(s[key])
	cb.toggled.connect(func(on: bool) -> void:
		s[key] = on
		save_settings()
		if key == "reduceMotion":
			reduce_motion_changed.emit(on))
	r.add_child(cb)
	return r


func _slider_row(label: String, key: String) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	_box.add_child(r)
	var l := Kit.label(13, Kit.TEXT, 700)
	l.text = label
	l.custom_minimum_size = Vector2(60, 0)
	r.add_child(l)
	var sl := HSlider.new()
	sl.name = "Slider_" + key
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 1
	sl.value = roundf(float(s[key]) * 100.0)
	sl.focus_mode = Control.FOCUS_NONE
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(sl)
	var v := Kit.label(12, Kit.DIM, 600)
	v.text = str(int(sl.value))
	v.custom_minimum_size = Vector2(28, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(v)
	sl.value_changed.connect(func(x: float) -> void:
		s[key] = x / 100.0
		v.text = str(int(x))
		save_settings())


## 항복 확인 (웹은 바로 항복 — 실수로 누르지 않게 확인 창을 더함)
func ask_surrender() -> void:
	ask_confirm("surrender")


## 확인 창: surrender(항복) · leave(저장하고 로비로 — 4b-1)
func ask_confirm(kind: String) -> void:
	_confirm_kind = kind
	var leave := kind == "leave"
	panel.visible = false
	backdrop.visible = true
	for c: Node in confirm.get_children():
		confirm.remove_child(c)
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(300, 0)
	confirm.add_child(v)
	var hl := Kit.label(16, Color("fca5a5"), 800)
	hl.text = t("gd.settings.leave") if leave else t("battle.surrender")
	if leave:
		hl.add_theme_color_override("font_color", Kit.GOLD)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hl)
	var ml := Kit.label(13, Kit.TEXT, 500)
	ml.text = t("gd.settings.leave_confirm") if leave else t("gd.settings.surrender_confirm")
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ml)
	var br := HBoxContainer.new()
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	br.add_theme_constant_override("separation", 10)
	v.add_child(br)
	var no := Kit.button(t("common.cancel"), Kit.GOLD, 13, Vector2(110, 34))
	no.name = "No"
	no.pressed.connect(close)
	br.add_child(no)
	var yes := Kit.button(t("gd.settings.leave") if leave else t("battle.surrender"), Kit.GOLD if leave else Kit.RED, 13, Vector2(110, 34))
	yes.name = "Yes"
	if not leave:
		yes.add_theme_color_override("font_color", Color("fca5a5"))
		yes.add_theme_stylebox_override("normal", Kit.box(Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.18), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.6), 5, 1, 12, 5))
	yes.pressed.connect(func() -> void:
		if not confirm_wrap.visible:
			return   # 같은 프레임 두 번 누름 → 한 번만
		close()
		if leave:
			leave_confirmed.emit()
		else:
			surrender_confirmed.emit())
	br.add_child(yes)
	confirm_wrap.visible = true
	confirm.reset_size()
