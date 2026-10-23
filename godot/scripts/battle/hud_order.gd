extends VBoxContainer
## 오른쪽 행동 순서 패널 — 웹 #ally-nav (render.js rTurnOrder): 순번 · 원형 초상화 · 이름 · HP·행동력 막대 · 다음 행동까지 틱 (✓ 준비, 행동 중)
##  현재 차례는 금빛으로 크게. 클랜원 줄을 누르면 unit_clicked, 마우스를 올리면 unit_hover (맵에서 강조)
##  줄 노드는 다시 쓰고(풀) 바뀐 내용만 고침

const Kit := preload("res://scripts/battle/ui_kit.gd")

signal unit_clicked(id: int)
signal unit_hover(id: int)

var head: Label
var icons: Object   # 보스 표시 💀 그림 (EMOJI_ICON)
var _rows: Array = []   # Row
var _sig := ""
## 화면 높이에 들어가는 줄 수 (웹 max-height: calc(100vh - 240px) — 넘치는 줄은 안 보임)
var max_rows := 99


class Row extends PanelContainer:
	var id := -1
	var team := "ally"
	var cur := false
	var order: Label
	var por: Kit.Portrait
	var nm: Label
	var boss_ic: Kit.IconRect
	var hp: Kit.Bar
	var ap: Kit.Bar
	var eta: Label
	var tc := Color("3b82f6")
	var _t := 0.0

	func _process(d: float) -> void:
		if cur:
			_t += d
			queue_redraw()

	func _draw() -> void:
		# 웹 border-left: 3px solid var(--tc)
		draw_rect(Rect2(0, 1, 3, size.y - 2), tc)
		if cur:
			# 웹 anCurPulse: 금빛 그림자가 숨 쉬듯
			var a := 0.18 + 0.22 * (0.5 - 0.5 * cos(_t / 1.6 * TAU))
			draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), Color(250 / 255.0, 204 / 255.0, 21 / 255.0, a * 0.6), false, 2.0)


func setup() -> void:
	name = "TurnOrder"
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	head = Kit.label(10, Kit.DIM, 900)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(head)


func set_head(s: String) -> void:
	head.text = s


func _make_row() -> Row:
	var r := Row.new()
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.custom_minimum_size = Vector2(180, 42)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)   # 일본어 '行動中' 태그 때문에 이름이 잘리지 않게 이름 칸 폭 +6
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(hb)
	r.order = Kit.label(11, Kit.DIM, 900)
	r.order.custom_minimum_size = Vector2(13, 0)
	r.order.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.order.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(r.order)
	r.por = Kit.Portrait.new()
	r.por.custom_minimum_size = Vector2(32, 32)
	r.por.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.por.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(r.por)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 2)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(body)
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 3)
	nrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(nrow)
	r.boss_ic = Kit.IconRect.new()
	r.boss_ic.custom_minimum_size = Vector2(13, 13)
	r.boss_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.boss_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.boss_ic.visible = false
	nrow.add_child(r.boss_ic)
	r.nm = Kit.label(12, Color("e5e7eb"), 700)
	r.nm.clip_text = true
	r.nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	r.nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nrow.add_child(r.nm)
	r.hp = Kit.Bar.new()
	r.hp.custom_minimum_size = Vector2(0, 4)
	r.hp.radius = 2
	body.add_child(r.hp)
	r.ap = Kit.Bar.new()
	r.ap.custom_minimum_size = Vector2(0, 4)
	r.ap.radius = 2
	body.add_child(r.ap)
	r.eta = Kit.label(11, Kit.DIM, 900)
	r.eta.custom_minimum_size = Vector2(24, 0)
	r.eta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.eta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(r.eta)
	r.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and r.team == "ally":
			unit_clicked.emit(r.id))
	r.mouse_entered.connect(func() -> void: unit_hover.emit(r.id))
	r.mouse_exited.connect(func() -> void: unit_hover.emit(-1))
	add_child(r)
	return r


## rows: [{id, team, boss, cur, name, tip, hp_ratio, ap_ratio, eta, ready, tex, summon}] — 순서대로
func update(all_rows: Array) -> void:
	var rows: Array = all_rows.slice(0, max_rows)
	var sig := sig_of(rows)
	if sig == _sig:
		return
	_sig = sig
	while _rows.size() < rows.size():
		_rows.append(_make_row())
	for i in _rows.size():
		var r: Row = _rows[i]
		if i >= rows.size():
			r.visible = false
			continue
		var m: Dictionary = rows[i]
		r.visible = true
		r.id = int(m["id"])
		r.team = str(m["team"])
		r.cur = bool(m["cur"])
		var tc := Color("facc15") if r.cur else (Color("ef4444") if r.team == "enemy" else Color("3b82f6"))
		r.tc = tc
		var sb := Kit.box(Color(17 / 255.0, 24 / 255.0, 39 / 255.0, 0.92), Color(1, 1, 1, 0.08), 6, 1, 6, 3)
		if r.cur:
			sb.bg_color = Color(60 / 255.0, 52 / 255.0, 20 / 255.0, 0.94)
			sb.border_color = Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.55)
		sb.content_margin_left = 6
		r.add_theme_stylebox_override("panel", sb)
		r.custom_minimum_size = Vector2(180, 50 if r.cur else 42)
		r.por.custom_minimum_size = Vector2(38, 38) if r.cur else Vector2(32, 32)
		r.por.ring = tc
		r.por.set_unit(m["tex"], bool(m["summon"]))
		r.order.text = str(i + 1)
		r.order.add_theme_color_override("font_color", Color("facc15") if r.cur else Kit.DIM)
		# 웹 .an-unit.boss .an-name::before '💀 ' — 그림으로
		r.boss_ic.visible = bool(m["boss"])
		if m["boss"] and icons != null:
			r.boss_ic.set_icon(icons.call("emoji", "💀"))
		r.nm.text = str(m["name"])
		r.nm.add_theme_color_override("font_color", Color("fbbf24") if m["boss"] else (Color("fca5a5") if r.team == "enemy" else Color("e5e7eb")))
		var hr := float(m["hp_ratio"])
		var hc := Color("ef4444") if r.team == "enemy" else (Color("f59e0b") if hr <= 0.3 else Color("22c55e"))
		r.hp.set_value(hr, hc, hc)
		r.ap.set_value(float(m["ap_ratio"]), Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.75), Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.75))
		r.eta.text = str(m["eta"])
		r.eta.add_theme_font_size_override("font_size", 9 if r.cur else 11)
		r.eta.add_theme_color_override("font_color", Color("facc15") if (r.cur or m["ready"]) else Kit.DIM)
		r.tooltip_text = str(m["tip"])
		r.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if r.team == "ally" else Control.CURSOR_ARROW
		r.queue_redraw()


## 바뀜 확인용 글 (텍스처는 객체 번호로 — var_to_str 은 리소스를 통째로 글로 바꿔 느림)
static func sig_of(rows: Array) -> String:
	var parts := PackedStringArray()
	for m: Dictionary in rows:
		for k: Variant in m.keys():
			var v: Variant = m[k]
			parts.append(str(k) + "=" + (str((v as Object).get_instance_id()) if v is Object else str(v)))
		parts.append("|")
	return ";".join(parts)
