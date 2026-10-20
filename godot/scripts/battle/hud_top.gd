extends PanelContainer
## 윗줄 HUD — 웹 #top-bar (render.js uUI): 차례 표시(점 + 아군/적군 턴) · 스테이지 제목·턴 · 칩(증원 진행 막대·남은 적·돌파·환경·조합 버프·연습)
##  · 오른쪽 단추(위협 범위·카메라 회전·속도). 칩 툴팁은 웹 title 과 같은 글 (Hazard.describe 등)
##  update(model) 은 바뀐 것만 다시 만듦 (매 프레임 부르지 않음)

const Kit := preload("res://scripts/battle/ui_kit.gd")
const Icons := preload("res://scripts/battle/icons.gd")

signal threat_pressed
signal rotate_pressed(dir: int)
signal speed_pressed

var icons: Icons
var ti_box: PanelContainer
var ti_dot: Control
var ti_label: Label
var si_no: Label
var si_name: Label
var si_turn: Label
var chips: HBoxContainer
var threat_btn: Button
var rot_l: Button
var rot_r: Button
var speed_btn: Button
var _sig := ""
var _phase := ""
var _t := 0.0


func setup(p_icons: Icons) -> void:
	icons = p_icons
	name = "TopBar"
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, 58)
	offset_bottom = 58
	# 웹 #top-bar: linear-gradient(180deg,#1a2340,#111827) + 아래 2px #1e293b
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_bottom = 2
	add_theme_stylebox_override("panel", sb)
	draw.connect(func() -> void:
		var w := size.x
		var h := size.y
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color("1a2340"), Color("1a2340"), Color("111827"), Color("111827")]))
		draw_rect(Rect2(0, h - 2, w, 2), Color("1e293b")))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	add_child(row)
	# 왼쪽: 차례 표시 (웹 #turn-indicator)
	var left := HBoxContainer.new()
	left.name = "Left"
	left.custom_minimum_size = Vector2(200, 0)
	row.add_child(left)
	ti_box = PanelContainer.new()
	ti_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(ti_box)
	var tib := HBoxContainer.new()
	tib.add_theme_constant_override("separation", 7)
	ti_box.add_child(tib)
	ti_dot = Control.new()
	ti_dot.custom_minimum_size = Vector2(8, 8)
	ti_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ti_dot.draw.connect(func() -> void: ti_dot.draw_circle(ti_dot.size / 2.0, 3.5, Color(1, 1, 1, 0.35 + 0.65 * (0.5 + 0.5 * cos(_t / 1.4 * TAU)))))
	tib.add_child(ti_dot)
	ti_label = Kit.label(13, Color.WHITE, 900)
	tib.add_child(ti_label)
	# 가운데: 제목 + 칩
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 3)
	row.add_child(mid)
	var title := HBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 6)
	mid.add_child(title)
	si_no = Kit.label(15, Kit.GOLD, 900)
	title.add_child(si_no)
	si_name = Kit.label(13, Color("e5e7eb"), 700)
	title.add_child(si_name)
	var tc := PanelContainer.new()
	tc.add_theme_stylebox_override("panel", Kit.box(Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.15), Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.3), 999, 1, 6, 0))
	tc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(tc)
	si_turn = Kit.label(11, Color("93c5fd"), 800)
	tc.add_child(si_turn)
	chips = HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 4)
	mid.add_child(chips)
	# 오른쪽 단추
	var right := HBoxContainer.new()
	right.name = "Right"
	right.custom_minimum_size = Vector2(200, 0)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 9)
	row.add_child(right)
	threat_btn = Kit.cam_button("warn", "")
	threat_btn.toggle_mode = true
	threat_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	threat_btn.pressed.connect(func() -> void: threat_pressed.emit())
	right.add_child(threat_btn)
	rot_l = Kit.cam_button("rot_l", "")
	rot_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rot_l.pressed.connect(func() -> void: rotate_pressed.emit(-1))
	right.add_child(rot_l)
	rot_r = Kit.cam_button("rot_r", "")
	rot_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rot_r.pressed.connect(func() -> void: rotate_pressed.emit(1))
	right.add_child(rot_r)
	speed_btn = Kit.cam_button("speed", "")
	speed_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sl := Kit.label(10, Kit.GOLD, 900)
	sl.name = "SpeedLabel"
	sl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	sl.offset_left = -22
	sl.offset_top = -15
	sl.offset_right = -3
	sl.offset_bottom = 0
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# (6a) 글자가 커지면(모바일) 단추 아래로 넘치지 않고 위·왼쪽으로 자람 — PC 는 칸 안이라 그대로
	sl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	speed_btn.add_child(sl)
	speed_btn.pressed.connect(func() -> void: speed_pressed.emit())
	right.add_child(speed_btn)


## (6a) 좁은 모바일 논리 화면: 양쪽 칸의 최소 폭(200)을 풀고 간격을 줄임. 칩 줄은 가로 스크롤 안에 넣어(손가락으로 밀어 봄)
##  언어·스테이지에 따라 칩이 많아도 오른쪽 단추가 화면 밖으로 밀리지 않게
func compact() -> void:
	for n: String in ["Left", "Right"]:
		var c := find_child(n, true, false) as Control
		if c != null:
			c.custom_minimum_size.x = 0
			c.add_theme_constant_override("separation", 6)
	var mid := chips.get_parent()
	var sc := ScrollContainer.new()
	sc.name = "ChipsScroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx := chips.get_index()
	mid.remove_child(chips)
	mid.add_child(sc)
	mid.move_child(sc, idx)
	sc.add_child(chips)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fit := func() -> void:
		if is_instance_valid(sc) and is_instance_valid(chips):
			sc.custom_minimum_size.y = chips.get_combined_minimum_size().y
	chips.minimum_size_changed.connect(fit)
	fit.call()


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		ti_dot.queue_redraw()


func set_tooltips(tr: Callable) -> void:
	threat_btn.tooltip_text = tr.call("battle.threat_title")
	rot_l.tooltip_text = tr.call("battle.camera_rotate_left")
	rot_r.tooltip_text = tr.call("battle.camera_rotate_right")
	speed_btn.tooltip_text = tr.call("settings.game_speed")


func set_speed(s: String) -> void:
	(speed_btn.get_node("SpeedLabel") as Label).text = s


func set_threat(on: bool) -> void:
	threat_btn.set_pressed_no_signal(on)
	var ic: Control = threat_btn.get_meta("icon")
	ic.set("color", Color("fca5a5") if on else Kit.GOLD)
	ic.queue_redraw()


## model: {phase, phase_text, no, name, turn_text, wave{done, ratio, text, tip}, foe{text, tip}, breach{text, tip, hit, danger}|null,
##          hazard{icon, name, tip}|null, synergies[{icon, name, tip}], practice(text|"")}
func update(m: Dictionary) -> void:
	var sig := var_to_str(m)
	if sig == _sig:
		return
	_sig = sig
	if m["phase"] != _phase:
		_phase = m["phase"]
		var pl: bool = _phase == "player"
		var sb := Kit.box(Color("2563eb") if pl else Color("dc2626"), Color(0, 0, 0, 0), 999, 0, 11, 5)
		sb.shadow_color = Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.45) if pl else Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.45)
		sb.shadow_size = 8
		ti_box.add_theme_stylebox_override("panel", sb)
	ti_label.text = m["phase_text"]
	si_no.text = m["no"]
	si_name.text = m["name"]
	si_turn.text = m["turn_text"]
	for c: Node in chips.get_children():
		chips.remove_child(c)
		c.queue_free()
	var w: Dictionary = m["wave"]
	var wc := _chip("wave", "⚑", w["text"], w["tip"], Color("cbd5e1"), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.06))
	var bar := Kit.Bar.new()
	bar.custom_minimum_size = Vector2(48, 5)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.track = Color(1, 1, 1, 0.12)
	bar.radius = 2
	var done: bool = w["done"]
	bar.set_value(float(w["ratio"]), Color("22c55e") if done else Color("f97316"), Color("22c55e") if done else Color("f97316"))
	(wc.get_child(0) as HBoxContainer).add_child(bar)
	(wc.get_child(0) as HBoxContainer).move_child(bar, 1)
	var f: Dictionary = m["foe"]
	_chip("foe", "⚔", f["text"], f["tip"], Color("fca5a5"), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.3), Color(1, 1, 1, 0.06))
	var b: Variant = m.get("breach")
	if typeof(b) == TYPE_DICTIONARY:
		var col := Color("cbd5e1")
		var bc := Color(1, 1, 1, 0.1)
		var bg := Color(1, 1, 1, 0.06)
		if b["danger"]:
			col = Color.WHITE
			bc = Kit.RED
			bg = Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.35)
		elif b["hit"]:
			col = Color("fbbf24")
			bc = Color(251 / 255.0, 191 / 255.0, 36 / 255.0, 0.4)
			bg = Color(251 / 255.0, 191 / 255.0, 36 / 255.0, 0.08)
		_chip("breach", "⚠", b["text"], b["tip"], col, bc, bg)
	var h: Variant = m.get("hazard")
	if typeof(h) == TYPE_DICTIONARY:
		_chip("hazard", h["icon"], h["name"], h["tip"], Color("fdba74"), Color(249 / 255.0, 115 / 255.0, 22 / 255.0, 0.45), Color(249 / 255.0, 115 / 255.0, 22 / 255.0, 0.10))
	for sy: Dictionary in m["synergies"]:
		_chip("syn", sy["icon"], sy["name"], sy["tip"], Color("c4b5fd"), Color(167 / 255.0, 139 / 255.0, 250 / 255.0, 0.4), Color(139 / 255.0, 92 / 255.0, 246 / 255.0, 0.10))
	if str(m.get("practice", "")) != "":
		_chip("practice", "", m["practice"], m["practice"], Color("a5b4fc"), Color(99 / 255.0, 102 / 255.0, 241 / 255.0, 0.45), Color(99 / 255.0, 102 / 255.0, 241 / 255.0, 0.12))


## 칩 하나 (웹 .si-chip): [아이콘][값] — 아이콘이 그림 시트에 있으면 그림, 글자 기호면 글자
func _chip(kind: String, icon: String, text: String, tip: String, col: Color, border: Color, bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Chip_" + kind
	p.add_theme_stylebox_override("panel", Kit.box(bg, border, 999, 1, 9, 1))
	p.tooltip_text = tip
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hb)
	if icon != "":
		var tex: Texture2D = icons.emoji(icon)
		if tex != null:
			var ir := Kit.IconRect.new()
			ir.custom_minimum_size = Vector2(15, 15)
			ir.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ir.set_icon(tex)
			hb.add_child(ir)
		else:
			var il := Kit.label(11, Color(col, 0.85), 700)
			il.text = icons.strip(icon)
			hb.add_child(il)
	var l := Kit.label(12, col, 700)
	l.text = icons.strip(text)
	hb.add_child(l)
	chips.add_child(p)
	return p
