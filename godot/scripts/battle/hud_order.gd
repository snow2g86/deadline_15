extends VBoxContainer
## 오른쪽 행동 순서 패널 — 웹 #ally-nav (render.js rTurnOrder): 순번 · 원형 초상화 · 이름 · HP·행동력 막대 · 다음 행동까지 틱 (✓ 준비, 행동 중)
##  현재 차례는 금빛으로 크게. 줄을 누르면(아군·적 모두, 터치 탭 포함) unit_clicked, 마우스를 올리면 unit_hover (맵에서 강조)
##  (도입 1) 팀 테두리(아군 파랑·적 빨강) · 눌러 고른 유닛(focus_id)은 흰 테두리 · 라운드 구분선 · 한도 넘으면 '+N명' (눌러 펼침/접기)
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
## 순서 바에 쓸 수 있는 세로 높이 (장면 UI 가 정함 — 나침반과 안 겹치게). 줄 수 한도는 이 높이와 max_rows 중 작은 쪽
var avail_h := 1.0e9
## 눌러 고른 유닛 (맵·카드와 공유 — 장면이 정함)
var focus_id := -1
## '+N명' 을 눌러 전부 펼침
var expanded := false
var more_fmt := "+{n}"
var less_text := "-"
var round_text := "다음 턴"
var _div: Control
var _more: PanelContainer
var _more_lbl: Label
var _last_rows: Array = []
## 화면에 실제로 그려진 줄 수·넘쳐 숨은 수·넘친 곳에 눌러 고른 유닛이 있는지 (시험·확인용)
var shown_count := 0
var hidden_count := 0
var divider_before := -1


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
	var focus := false
	var _t := 0.0

	func _process(d: float) -> void:
		if cur:
			_t += d
			queue_redraw()

	func _draw() -> void:
		# 웹 border-left: 3px solid var(--tc)
		draw_rect(Rect2(0, 1, 4, size.y - 2), tc)
		if focus:
			draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(1, 1, 1, 0.95), false, 2.0)
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
	_div = Control.new()
	_div.name = "RoundDivider"
	_div.custom_minimum_size = Vector2(180, 14)
	_div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_div.visible = false
	_div.draw.connect(func() -> void:
		var y := _div.size.y * 0.5
		var f := Kit.font()
		var w := f.get_string_size(round_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var cx := _div.size.x * 0.5
		_div.draw_line(Vector2(2, y), Vector2(cx - w * 0.5 - 6, y), Color(1, 1, 1, 0.28), 1.0)
		_div.draw_line(Vector2(cx + w * 0.5 + 6, y), Vector2(_div.size.x - 2, y), Color(1, 1, 1, 0.28), 1.0)
		_div.draw_string(f, Vector2(cx - w * 0.5, y + 4), round_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.6)))
	add_child(_div)
	_more = PanelContainer.new()
	_more.name = "OrderMore"
	_more.custom_minimum_size = Vector2(180, Kit.touch_min())   # 터치 44pt
	_more.mouse_filter = Control.MOUSE_FILTER_STOP
	_more.visible = false
	_more.add_theme_stylebox_override("panel", Kit.box(Color(17 / 255.0, 24 / 255.0, 39 / 255.0, 0.92), Color(1, 1, 1, 0.18), 6, 1, 6, 3))
	_more_lbl = Kit.label(12, Kit.TEXT, 800)
	_more_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_more_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_more_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more.add_child(_more_lbl)
	_more.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			toggle_expanded())
	add_child(_more)


func set_head(s: String) -> void:
	head.text = s


func set_labels(more_f: String, less: String, round_t: String) -> void:
	more_fmt = more_f
	less_text = less
	round_text = round_t
	_sig = ""
	if _div != null:
		_div.queue_redraw()
	if not _last_rows.is_empty():
		update(_last_rows)


## 쓸 수 있는 높이가 바뀌었을 때 (화면 크기·언어) 줄 수를 다시 맞춤
func refit() -> void:
	_sig = ""
	update(_last_rows)


func toggle_expanded() -> void:
	expanded = not expanded
	_sig = ""
	update(_last_rows)


## 눌러 고른 유닛이 바뀜 (맵·카드에서도 불림)
func set_focus(id: int) -> void:
	if focus_id == id:
		return
	focus_id = id
	_sig = ""
	update(_last_rows)




func row_of(id: int) -> Row:
	for r: Row in _rows:
		if r.visible and r.id == id:
			return r
	return null


func _make_row() -> Row:
	var r := Row.new()
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.custom_minimum_size = Vector2(180, Kit.touch_min())
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
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			unit_clicked.emit(r.id))
	r.mouse_entered.connect(func() -> void: unit_hover.emit(r.id))
	r.mouse_exited.connect(func() -> void: unit_hover.emit(-1))
	add_child(r)
	return r


## n 줄이 avail_h 안에 들어가는가: 다 들어가면 n, 아니면 (머리글·구분선·'+N명' 칩 자리를 빼고) 들어가는 줄 수 (최소 1)
func fit_rows(n: int) -> int:
	var tm := Kit.touch_min()
	var cur_h := maxf(50.0, tm)
	var head_h := 18.0    # 머리글 + 간격
	var div_h := 18.0     # 라운드 구분선 + 간격
	var cap_all := 1 + int(floorf((avail_h - head_h - div_h - (cur_h + 4.0)) / (tm + 4.0)))
	if n <= cap_all:
		return n
	return maxi(1, 1 + int(floorf((avail_h - head_h - div_h - (tm + 4.0) - (cur_h + 4.0)) / (tm + 4.0))))


## rows: [{id, team, boss, cur, name, tip, hp_ratio, ap_ratio, eta, ready, tex, summon}] — 순서대로
func update(all_rows: Array) -> void:
	_last_rows = all_rows
	var limit := all_rows.size() if expanded else mini(max_rows, fit_rows(all_rows.size()))
	var rows: Array = all_rows.slice(0, limit)
	var sig := sig_of(rows) + "|n%d|f%d|e%s" % [all_rows.size(), focus_id, expanded]
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
		r.focus = r.id == focus_id
		# 팀 테두리: 아군 파랑·적 빨강 (현재 차례는 금빛 — 아래에서 덮음)
		var sb := Kit.box(Color(17 / 255.0, 24 / 255.0, 39 / 255.0, 0.92), Color(tc.r, tc.g, tc.b, 0.55), 6, 1, 6, 3)
		if r.cur:
			sb.bg_color = Color(60 / 255.0, 52 / 255.0, 20 / 255.0, 0.94)
			sb.border_color = Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.55)
		sb.content_margin_left = 6
		r.add_theme_stylebox_override("panel", sb)
		r.custom_minimum_size = Vector2(180, maxf(50.0, Kit.touch_min()) if r.cur else Kit.touch_min())
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
		r.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		r.queue_redraw()
	# 턴 구분선 (다음 턴 = 이번 턴에 아직 행동 안 한 클랜원이 모두 행동한 뒤 첫 행동부터 — 엔진 턴 정의) · '+N명'
	divider_before = -1
	for i2 in rows.size():
		if bool((rows[i2] as Dictionary).get("round2", false)):
			divider_before = i2
			break
	if divider_before > 0:
		move_child(_div, _rows[divider_before - 1].get_index() + 1)
		_div.visible = true
		_div.queue_redraw()
	else:
		_div.visible = false
	shown_count = rows.size()
	hidden_count = all_rows.size() - rows.size()
	var hide_focus := false
	for k2 in range(rows.size(), all_rows.size()):
		if int((all_rows[k2] as Dictionary)["id"]) == focus_id:
			hide_focus = true
	_more.visible = hidden_count > 0 or (expanded and all_rows.size() > max_rows)
	if _more.visible:
		move_child(_more, get_child_count() - 1)
		_more_lbl.text = less_text if expanded else more_fmt.replace("{n}", str(hidden_count))
		var msb := Kit.box(Color(17 / 255.0, 24 / 255.0, 39 / 255.0, 0.92), Color(1, 1, 1, 0.95 if hide_focus else 0.18), 6, 2 if hide_focus else 1, 6, 3)
		_more.add_theme_stylebox_override("panel", msb)


## 바뀜 확인용 글 (텍스처는 객체 번호로 — var_to_str 은 리소스를 통째로 글로 바꿔 느림)
static func sig_of(rows: Array) -> String:
	var parts := PackedStringArray()
	for m: Dictionary in rows:
		for k: Variant in m.keys():
			var v: Variant = m[k]
			parts.append(str(k) + "=" + (str((v as Object).get_instance_id()) if v is Object else str(v)))
		parts.append("|")
	return ";".join(parts)
