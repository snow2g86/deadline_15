extends CanvasLayer
## 전투 화면 UI (3a 기본판) — 윗줄(턴·차례·카메라·위협·속도), 행동 메뉴(웹 #action-menu), 안내 글, 웨이브 알림, 결과 판
##  규칙은 모름: 장면(battle_scene.gd)이 넘겨 준 목록을 그리고, 누르면 신호만 보냄. HUD·초상화·행동 순서 패널은 3b.

signal action_pressed(op: String)
signal skill_pressed(idx: int)
signal item_pressed(kind: String, idx: int)
signal cancel_pressed
signal rotate_pressed(dir: int)
signal threat_pressed
signal speed_pressed
signal back_pressed

const FONT_PATH := "res://assets/fonts/NotoSansKR-VariableFont_wght.ttf"
const GOLD := Color("f0c040")
const BG := Color(0.04, 0.055, 0.1, 0.92)
## 버튼 강조색 (웹 .ac-move · ac-attack · ac-skill · ac-item · ac-wait · ac-cancel)
const AC := {"move": Color("60a5fa"), "attack": Color("ef4444"), "skill": Color("a78bfa"), "item": Color("34d399"), "wait": Color("94a3b8"), "cancel": Color("f59e0b")}

var i18n: Node
var font: FontFile
var font_bold: FontVariation
var theme_ui: Theme

var top_label: Label
var stage_label: Label
var cam_label: Label
var threat_btn: Button
var speed_btn: Button
var menu: PanelContainer
var menu_box: VBoxContainer
var hint: Label
var banner: Label
var result_panel: PanelContainer
var _banner_t := 0.0
var menu_buttons: Array = []   # 시험·단축키용: {op, button}


func _init() -> void:
	layer = 10


func setup(p_i18n: Node) -> void:
	i18n = p_i18n
	font = load(FONT_PATH)
	font_bold = FontVariation.new()
	font_bold.base_font = font
	font_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	theme_ui = Theme.new()
	theme_ui.default_font = font
	theme_ui.default_font_size = 14
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_ui
	add_child(root)

	# ── 윗줄 ──
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(Color(0.03, 0.045, 0.08, 0.85), Color(1, 1, 1, 0.06), 0))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 40)
	root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	top_label = _label(16, GOLD, true)
	row.add_child(top_label)
	stage_label = _label(13, Color("cbd5e1"))
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stage_label)
	var rl := _small_btn("⟲")
	rl.tooltip_text = _t("battle.camera_rotate_left")
	rl.pressed.connect(func() -> void: rotate_pressed.emit(-1))
	row.add_child(rl)
	cam_label = _label(14, GOLD, true)
	cam_label.custom_minimum_size = Vector2(36, 0)
	cam_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(cam_label)
	var rr := _small_btn("⟳")
	rr.tooltip_text = _t("battle.camera_rotate_right")
	rr.pressed.connect(func() -> void: rotate_pressed.emit(1))
	row.add_child(rr)
	threat_btn = _small_btn("!")
	threat_btn.toggle_mode = true
	threat_btn.tooltip_text = _t("battle.threat_title")
	threat_btn.pressed.connect(func() -> void: threat_pressed.emit())
	row.add_child(threat_btn)
	speed_btn = _small_btn("1x")
	speed_btn.pressed.connect(func() -> void: speed_pressed.emit())
	row.add_child(speed_btn)

	# ── 행동 메뉴 ──
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", _box(BG, Color(GOLD, 0.35), 8))
	menu.visible = false
	root.add_child(menu)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 3)
	menu.add_child(menu_box)

	# ── 안내 글 · 웨이브 알림 ──
	hint = _label(14, Color("fde68a"), true)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -64
	hint.offset_bottom = -36
	hint.offset_left = -400
	hint.offset_right = 400
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_constant_override("outline_size", 6)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	root.add_child(hint)
	banner = _label(28, GOLD, true)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.offset_left = -500
	banner.offset_right = 500
	banner.offset_top = -120
	banner.offset_bottom = -70
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override("outline_size", 8)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	banner.visible = false
	root.add_child(banner)

	result_panel = PanelContainer.new()
	result_panel.add_theme_stylebox_override("panel", _box(Color(0.03, 0.045, 0.08, 0.96), GOLD, 12))
	result_panel.visible = false
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.add_child(result_panel)


func _process(delta: float) -> void:
	if banner.visible:
		_banner_t -= delta
		banner.modulate.a = clampf(_banner_t / 0.4, 0.0, 1.0)
		if _banner_t <= 0.0:
			banner.visible = false


func _t(key: String, p: Dictionary = {}) -> String:
	return i18n.t(key, p) if i18n != null else key


func _label(size: int, col: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", font_bold)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _small_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(34, 28)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_bold)
	return b


# ── 윗줄 ──

func set_turn(turn: int, phase: String, enemies_left: int) -> void:
	var ph := _t("battle.player_phase") if phase == "player" else _t("battle.enemy_phase")
	top_label.text = "%s · %s" % [_t("battle.turn_n", {"n": turn}), ph]
	top_label.add_theme_color_override("font_color", Color("93c5fd") if phase == "player" else Color("fca5a5"))
	stage_label.text = _t("battle.enemy_left", {"n": enemies_left})


func set_stage_name(s: String) -> void:
	stage_label.tooltip_text = s


func set_cam(label: String) -> void:
	cam_label.text = label


func set_speed_label(s: String) -> void:
	speed_btn.text = s


func set_threat(on: bool) -> void:
	threat_btn.set_pressed_no_signal(on)


func show_hint(s: String) -> void:
	hint.text = s


func show_banner(s: String, secs: float = 1.6) -> void:
	banner.text = s
	banner.visible = true
	_banner_t = secs
	banner.modulate.a = 1.0


# ── 행동 메뉴 ──

func hide_menu() -> void:
	menu.visible = false
	menu_buttons.clear()


## items: [{op, icon, label, sub, key, ac, enabled, warn, idx?, kind?}] — at: 유닛 화면 위치 (메뉴는 오른쪽, 넘치면 왼쪽)
func show_menu(head: String, items: Array, at: Vector2) -> void:
	for c: Node in menu_box.get_children():
		menu_box.remove_child(c)
		c.queue_free()
	menu_buttons.clear()
	if head != "":
		var h := _label(12, GOLD, true)
		h.text = head
		menu_box.add_child(h)
	for it: Dictionary in items:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(190, 34)
		var ac: Color = AC.get(str(it.get("ac", "wait")), AC["wait"])
		var sb := _box(Color(0.08, 0.1, 0.16, 0.95), Color(ac, 0.55), 6)
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		var sbh := sb.duplicate() as StyleBoxFlat
		sbh.bg_color = Color(ac, 0.25)
		var sbd := sb.duplicate() as StyleBoxFlat
		sbd.bg_color = Color(0.06, 0.07, 0.1, 0.8)
		sbd.border_color = Color(0.3, 0.3, 0.35, 0.4)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		b.add_theme_stylebox_override("disabled", sbd)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_right = -6
		row.add_theme_constant_override("separation", 6)
		b.add_child(row)
		var ic := _label(15, ac, true)
		ic.text = str(it.get("icon", ""))
		ic.custom_minimum_size = Vector2(20, 0)
		ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(ic)
		var tx := VBoxContainer.new()
		tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tx.alignment = BoxContainer.ALIGNMENT_CENTER
		tx.add_theme_constant_override("separation", -3)
		row.add_child(tx)
		var lb := _label(13, Color.WHITE if it.get("enabled", true) else Color("64748b"), true)
		lb.text = str(it.get("label", ""))
		tx.add_child(lb)
		var sub := str(it.get("sub", ""))
		if sub != "":
			var sl := _label(10, Color("fca5a5") if it.get("warn", false) else Color("94a3b8"))
			sl.text = sub
			tx.add_child(sl)
		var key := str(it.get("key", ""))
		if key != "":
			var kl := _label(10, Color("94a3b8"), true)
			kl.text = key
			kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(kl)
		b.disabled = not it.get("enabled", true)
		var op := str(it["op"])
		if op == "skill_pick":
			var idx := int(it["idx"])
			b.pressed.connect(func() -> void: skill_pressed.emit(idx))
		elif op == "item_pick":
			var k2 := str(it["kind"])
			var i2 := int(it["idx"])
			b.pressed.connect(func() -> void: item_pressed.emit(k2, i2))
		elif op == "cancel":
			b.pressed.connect(func() -> void: cancel_pressed.emit())
		else:
			b.pressed.connect(func() -> void: action_pressed.emit(op))
		menu_box.add_child(b)
		menu_buttons.append({"op": op, "button": b, "key": key.to_lower(), "item": it})
	menu.visible = true
	menu.modulate.a = 0.0   # 크기가 정해진 다음 프레임에 자리 잡고 보임
	menu.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(menu) or not menu.visible:
		return
	menu.reset_size()
	menu.modulate.a = 1.0
	var vs := get_viewport().get_visible_rect().size
	var sz := menu.size
	var pos := at + Vector2(36, -sz.y * 0.5)
	if pos.x + sz.x > vs.x - 8.0:
		pos.x = at.x - 36.0 - sz.x
	pos.y = clampf(pos.y, 48.0, vs.y - sz.y - 8.0)
	pos.x = clampf(pos.x, 8.0, vs.x - sz.x - 8.0)
	menu.position = pos


## 단축키로 메뉴 단추 누르기 (웹 data-key) — 눌렀으면 true
func press_key(k: String) -> bool:
	if not menu.visible:
		return false
	for mb: Dictionary in menu_buttons:
		var b: Button = mb["button"]
		if mb["key"] == k and not b.disabled:
			b.pressed.emit()
			return true
	return false


# ── 결과 ──

func show_result(win: bool, lines: Array) -> void:
	for c: Node in result_panel.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(420, 0)
	result_panel.add_child(box)
	var title := _label(34, GOLD if win else Color("f87171"), true)
	title.text = ("VICTORY" if win else "DEFEAT")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for ln: String in lines:
		var l := _label(14, Color("e2e8f0"))
		l.text = ln
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	var b := Button.new()
	b.text = _t("results.return_to_lobby")
	b.custom_minimum_size = Vector2(200, 40)
	b.add_theme_font_override("font", font_bold)
	b.pressed.connect(func() -> void: back_pressed.emit())
	var cc := CenterContainer.new()
	cc.add_child(b)
	box.add_child(cc)
	result_panel.visible = true
	result_panel.reset_size()
	await get_tree().process_frame
	if is_instance_valid(result_panel):
		result_panel.reset_size()
		var vs := get_viewport().get_visible_rect().size
		result_panel.position = (vs - result_panel.size) / 2.0
