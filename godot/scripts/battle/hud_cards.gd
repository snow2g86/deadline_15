extends PanelContainer
## 왼쪽 클랜원 카드 (세로 패널; 예전엔 아래 가로줄) — 웹 #info-panel (render.js rInfoPanel): 초상화 · 이름 · Lv·직업 · HP·자원 막대와 값 · ATK/DEF/RNG · 버프 아이콘
##  지금 차례(ip-cur 금빛 테두리)·선택(ip-sel)·행동 끝(ip-done 흐림). 누르면 unit_clicked (장면이 카메라를 그 유닛으로)
##  카드 노드는 다시 쓰고 바뀐 내용만 고침. 버프 아이콘에 마우스를 올리면 이름·남은 턴 (웹은 아이콘만)

const Kit := preload("res://scripts/battle/ui_kit.gd")
const HudOrder := preload("res://scripts/battle/hud_order.gd")

signal unit_clicked(id: int)
signal unit_hover(id: int)

var icons: Object
var row: VBoxContainer
var _cards: Array = []
var _sig := ""


class Card extends PanelContainer:
	var id := -1
	var por: Kit.Portrait
	var nm: Label
	var cl: Label
	var hp: Kit.Bar
	var hpv: Label
	var hpl: Label
	var nmv: VBoxContainer
	var top_row: HBoxContainer
	var res_row: HBoxContainer
	var resl: Label
	var res: Kit.Bar
	var resv: Label
	var stats: Label
	var buffs: HBoxContainer
	var focused := false
	var down := false
	var moved := false
	var press_at := Vector2.ZERO

	func _draw() -> void:
		if focused:
			draw_rect(Rect2(Vector2(-1, -1), size + Vector2(2, 2)), Color(1, 1, 1, 0.9), false, 2.0)


## 왼쪽 세로 패널 너비 (일반 · 얇은 아이콘형)
const W_NORMAL := 158.0
const W_COMPACT := 56.0

var compact := false
var scroll: ScrollContainer
var col: VBoxContainer
var focus_id := -1   # 순서 바·맵에서 눌러 강조한 유닛 (카드 테두리)


func setup(p_icons: Object) -> void:
	icons = p_icons
	name = "ClanCards"
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var sb := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_PASS
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scroll)
	col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	row = col   # 예전 이름 호환 (카드 부모)


## 자리: 왼쪽 위 (x, y) 에서 너비 w, 아래 끝 bottom_y 까지. 얇은 모드는 아이콘 위주
func place(x: float, y: float, bottom_y: float, p_compact: bool) -> void:
	if p_compact != compact:
		compact = p_compact
		_sig = ""
	var w := W_COMPACT if compact else W_NORMAL
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	offset_left = x
	offset_top = y
	offset_right = x + w
	offset_bottom = maxf(y + 60.0, bottom_y)
	custom_minimum_size = Vector2(w, 0)


func _make() -> Card:
	var c := Card.new()
	c.custom_minimum_size = Vector2(0, Kit.touch_min())   # 터치 44pt
	# PASS: 끌기(스크롤)는 위 ScrollContainer 로 넘어가고, 탭 판정은 아래 gui_input 이 직접 함
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	c.por = Kit.Portrait.new()
	c.por.custom_minimum_size = Vector2(30, 30)
	c.por.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(c.por)
	var nmv := VBoxContainer.new()
	c.nmv = nmv
	c.top_row = top
	nmv.add_theme_constant_override("separation", -2)
	nmv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nmv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(nmv)
	c.nm = Kit.label(13, Kit.TEXT, 700)
	c.nm.clip_text = true
	c.nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nmv.add_child(c.nm)
	c.cl = Kit.label(10, Kit.DIM)
	nmv.add_child(c.cl)
	var hr := _bar_row(v, "HP", Kit.DIM)
	c.hp = hr[1]
	c.hpv = hr[2]
	c.hpl = hr[0]
	var rr := _bar_row(v, "", Kit.DIM)
	c.res_row = rr[3]
	c.resl = rr[0]
	c.res = rr[1]
	c.resv = rr[2]
	c.stats = Kit.label(10, Kit.DIM)
	v.add_child(c.stats)
	c.buffs = HBoxContainer.new()
	c.buffs.add_theme_constant_override("separation", 3)
	v.add_child(c.buffs)
	c.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mbe := ev as InputEventMouseButton
			c.accept_event()   # 누르기·떼기는 여기서 끝냄 (맵으로 새어 '빈 칸 탭' 이 되지 않게). 스크롤은 터치 끌기 사건이 따로 위 ScrollContainer 로 감
			if mbe.pressed:
				c.down = true
				c.moved = false
				c.press_at = mbe.global_position
			else:
				# 문턱(터치는 실제 2mm) 안에서 떼면 탭, 넘었으면 스크롤이었으니 무시
				if c.down and not c.moved and mbe.global_position.distance_to(c.press_at) <= _slop(mbe):
					unit_clicked.emit(c.id)
				c.down = false
		elif ev is InputEventMouseMotion and c.down and (ev as InputEventMouseMotion).global_position.distance_to(c.press_at) > _slop(ev):
			c.moved = true)
	c.mouse_entered.connect(func() -> void: unit_hover.emit(c.id))
	c.mouse_exited.connect(func() -> void: unit_hover.emit(-1))
	col.add_child(c)
	return c


## 끌기 문턱 (논리 px): Mobile 오토로드가 있으면 터치는 실제 2mm, 아니면 6
static func _slop(ev: InputEvent) -> float:
	var ml := Engine.get_main_loop()
	var mob: Node = (ml as SceneTree).root.get_node_or_null("Mobile") if ml is SceneTree else null
	return float(mob.call("slop_for", ev)) if mob != null else 6.0


func _bar_row(parent: Control, lab: String, col: Color) -> Array:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hb)
	var l := Kit.label(9, col, 800)
	l.text = lab
	l.custom_minimum_size = Vector2(18, 0)
	hb.add_child(l)
	var b := Kit.Bar.new()
	b.custom_minimum_size = Vector2(0, 6)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(b)
	var val := Kit.label(10, Kit.TEXT, 700)
	val.custom_minimum_size = Vector2(46, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(val)
	return [l, b, val, hb]


## cards: [{id, name, cls, hp, mhp, res, maxres, res_label, res_color, atk, def, rng, buffs[{icon,label,turns,type}], sel, cur, done, tex, summon}]
func update(cards: Array) -> void:
	var sig := HudOrder.sig_of(cards) + "|c%s|f%d" % [compact, focus_id]
	if sig == _sig:
		return
	_sig = sig
	while _cards.size() < cards.size():
		_cards.append(_make())
	for i in _cards.size():
		var c: Card = _cards[i]
		if i >= cards.size():
			c.visible = false
			continue
		var m: Dictionary = cards[i]
		c.visible = true
		c.id = int(m["id"])
		var sel: bool = m["sel"]
		var cur: bool = m["cur"]
		var sb := Kit.box(Color(13 / 255.0, 17 / 255.0, 23 / 255.0, 0.88), Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.35), 8, 1, 5 if compact else 7, 4)
		if sel:
			sb.border_color = Kit.GOLD
			sb.set_border_width_all(2)
			sb.bg_color = Color(40 / 255.0, 36 / 255.0, 18 / 255.0, 0.92)
		if cur:
			sb.shadow_color = Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.22)
			sb.shadow_size = 7
		c.add_theme_stylebox_override("panel", sb)
		c.modulate.a = 0.55 if (m["done"] and not cur) else 1.0
		c.por.ring = Color("facc15") if sel else Color("3b82f6")
		c.por.set_unit(m["tex"], bool(m["summon"]))
		c.nm.text = str(m["name"])
		c.cl.text = str(m["cls"])
		var hp := float(m["hp"])
		var mhp := maxf(1.0, float(m["mhp"]))
		var low := hp / mhp <= 0.25
		c.hp.set_value(hp / mhp, Color("b91c1c") if low else Color("16a34a"), Color("f87171") if low else Color("4ade80"))
		c.hpv.text = "%s/%s" % [m["hp_text"], m["mhp_text"]]
		var has_res := str(m["res_label"]) != ""
		c.res_row.visible = has_res
		if has_res:
			c.resl.text = str(m["res_label"])
			c.resl.add_theme_color_override("font_color", m["res_color"])
			var mr := maxf(1.0, float(m["maxres"]))
			c.res.set_value(float(m["res"]) / mr, m["res_color"], m["res_color"])
			c.resv.text = "%s/%s" % [m["res_text"], m["maxres_text"]]
		c.stats.text = "ATK %s   DEF %s   RNG %s" % [m["atk"], m["def"], m["rng"]]
		# 얇은 모드: 이름·값 숨김(초상+막대만). 일반: 선택된 카드만 값·능력치를 펼침
		var expanded: bool = sel and not compact
		c.nmv.visible = not compact
		c.hpl.visible = not compact
		c.resl.visible = not compact
		c.hpv.visible = expanded
		c.resv.visible = expanded
		c.stats.visible = expanded
		c.top_row.alignment = BoxContainer.ALIGNMENT_CENTER if compact else BoxContainer.ALIGNMENT_BEGIN
		c.tooltip_text = "%s · %s" % [m["name"], m["cls"]] if compact else ""
		c.focused = c.id == focus_id
		for ch: Node in c.buffs.get_children():
			c.buffs.remove_child(ch)
			ch.queue_free()
		for b: Dictionary in m["buffs"]:
			c.buffs.add_child(buff_icon(icons, b, 16))
		c.buffs.visible = not (m["buffs"] as Array).is_empty() and not compact
		c.queue_redraw()


## 버프 아이콘 하나 (그림 + 남은 턴 작은 숫자, 툴팁 = 이름·남은 턴)
static func buff_icon(p_icons: Object, b: Dictionary, sz: int) -> Control:
	var ir := Kit.IconRect.new()
	ir.custom_minimum_size = Vector2(sz, sz)
	ir.mouse_filter = Control.MOUSE_FILTER_PASS
	var tex: Texture2D = p_icons.call("emoji", str(b["icon"]))
	ir.set_icon(tex)
	var turns := int(b.get("turns", 0))
	ir.tooltip_text = str(b["label"]) + (" · " + str(b.get("turns_text", "")) if turns > 0 else "")
	if tex == null:
		var l := Kit.label(sz - 4, Color("fca5a5") if b.get("type") == "debuff" else Color("86efac"), 800)
		l.text = "•"
		ir.add_child(l)
	if turns > 0:
		var tl := Kit.label(maxi(8, int(sz * 0.55)), Color.WHITE, 900)
		Kit.outline(tl, 3)
		tl.text = str(turns)
		tl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		tl.offset_left = -10
		tl.offset_top = -10
		tl.offset_right = 2
		tl.offset_bottom = 3
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ir.add_child(tl)
	if b.get("type") == "debuff":
		ir.draw.connect(func() -> void: ir.draw_rect(Rect2(Vector2(0, ir.size.y - 2), Vector2(ir.size.x, 2)), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.8)))
	return ir
