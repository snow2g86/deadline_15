extends Control
## 정보 창 둘 — ① 칸·유닛 위 마우스 툴팁 (지형 효과·유닛 능력치·버프 남은 턴)  ② 적 정보 팝업 (웹 #enemy-popup: 초상화·이름·Lv·HP·자원·
##  ATK/DEF/RNG·버프 + Godot: 스킬 목록·AI 성향·노리는 대상). 내용은 모델 사전 하나로 만듦 (장면이 정보를 모아 넘김)
##  model: {title, title_color, sub, portrait{tex,summon,ring}|null, bars[{label,label_color,ratio,text,c0,c1}], stats, lines[str],
##          buffs[{icon,label,turns,turns_text,type}], skills[{tex,name,sub}], intent, ai, border}

const Kit := preload("res://scripts/battle/ui_kit.gd")
const HudCards := preload("res://scripts/battle/hud_cards.gd")
const HudOrder := preload("res://scripts/battle/hud_order.gd")

var icons: Object
var tip: PanelContainer
var popup: PanelContainer
var _tip_box: VBoxContainer
var _pop_box: VBoxContainer
var _tip_sig := ""
var _pop_sig := ""
var popup_unit := -1


func setup(p_icons: Object) -> void:
	icons = p_icons
	name = "Info"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip = PanelContainer.new()
	tip.name = "Tooltip"
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.visible = false
	add_child(tip)
	_tip_box = VBoxContainer.new()
	_tip_box.add_theme_constant_override("separation", 3)
	tip.add_child(_tip_box)
	popup = PanelContainer.new()
	popup.name = "EnemyPopup"
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.visible = false
	add_child(popup)
	_pop_box = VBoxContainer.new()
	_pop_box.add_theme_constant_override("separation", 3)
	popup.add_child(_pop_box)


# ── 툴팁 ──

## avoid: 겹치면 안 되는 사각형 (행동 메뉴) — 마우스 오른쪽 아래 → 왼쪽 아래 → 오른쪽 위 → 왼쪽 위 중 겹치지 않는 자리
func show_tip(m: Dictionary, at: Vector2, avoid: Rect2 = Rect2()) -> void:
	var sig := HudOrder.sig_of([m])
	if sig != _tip_sig or not tip.visible:
		_tip_sig = sig
		tip.add_theme_stylebox_override("panel", Kit.box(Color(10 / 255.0, 14 / 255.0, 26 / 255.0, 0.94), m.get("border", Color(1, 1, 1, 0.18)), 7, 1, 9, 6))
		_fill(_tip_box, m, 200.0)
		tip.visible = true
		tip.reset_size()
	var sz := tip.get_combined_minimum_size()
	var vs := get_viewport_rect().size
	var cands := [at + Vector2(18, 16), at + Vector2(-sz.x - 14.0, 16), at + Vector2(18, -sz.y - 12.0), at + Vector2(-sz.x - 14.0, -sz.y - 12.0)]
	if avoid.size.x > 0.0:
		cands.append(Vector2(avoid.position.x - sz.x - 10.0, avoid.position.y))
		cands.append(Vector2(avoid.end.x + 10.0, avoid.position.y))
	var pick: Vector2 = cands[0]
	for c: Vector2 in cands:
		var cc := Vector2(clampf(c.x, 8.0, maxf(8.0, vs.x - sz.x - 8.0)), clampf(c.y, 60.0, maxf(60.0, vs.y - sz.y - 8.0)))
		if avoid.size.x <= 0.0 or not Rect2(cc, sz).intersects(avoid):
			pick = cc
			break
	_place(tip, pick, false)


func hide_tip() -> void:
	tip.visible = false
	_tip_sig = ""


# ── 적 팝업 ──

func show_popup(id: int, m: Dictionary, at: Vector2) -> void:
	popup_unit = id
	var sig := HudOrder.sig_of([m])
	if sig != _pop_sig or not popup.visible:
		_pop_sig = sig
		popup.add_theme_stylebox_override("panel", Kit.box(Color(15 / 255.0, 10 / 255.0, 25 / 255.0, 0.95), m.get("border", Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.4)), 8, 1, 10, 8))
		_fill(_pop_box, m, 230.0)
		popup.visible = true
		popup.reset_size()
		popup.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(popup, "modulate:a", 1.0, 0.15)
	# 유닛 머리 위 (웹: translate(-50%,-100%), 화면 위를 넘으면 아래로)
	var sz := popup.get_combined_minimum_size()
	var pos := at - Vector2(sz.x / 2.0, sz.y + 8.0)
	if pos.y < 66.0:
		pos.y = at.y + 26.0
	_place(popup, pos, false)


func hide_popup() -> void:
	popup.visible = false
	popup_unit = -1
	_pop_sig = ""


func _place(p: Control, pos: Vector2, follow: bool) -> void:
	var vs := get_viewport_rect().size
	var sz := p.get_combined_minimum_size()
	p.size = sz
	if follow and pos.x + sz.x > vs.x - 8.0:
		pos.x -= sz.x + 30.0
	if follow and pos.y + sz.y > vs.y - 8.0:
		pos.y -= sz.y + 26.0
	p.position = Vector2(clampf(pos.x, 8.0, maxf(8.0, vs.x - sz.x - 8.0)), clampf(pos.y, 60.0, maxf(60.0, vs.y - sz.y - 8.0)))


# ── 내용 ──

## 정보 창 안 부품은 마우스를 받지 않음 (지도·메뉴 누르기를 가로채지 않게)
static func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Node in n.get_children():
		_ignore_mouse(c)


func _fill(box: VBoxContainer, m: Dictionary, width: float) -> void:
	_fill_inner(box, m, width)
	_ignore_mouse(box)


func _fill_inner(box: VBoxContainer, m: Dictionary, width: float) -> void:
	for c: Node in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	var pt: Variant = m.get("portrait")
	if typeof(pt) == TYPE_DICTIONARY:
		var por := Kit.Portrait.new()
		por.custom_minimum_size = Vector2(28, 28)
		por.ring = pt.get("ring", Color("ef4444"))
		por.set_unit(pt["tex"], bool(pt.get("summon", false)))
		head.add_child(por)
	var title_icon: Variant = m.get("title_icon")
	if title_icon is Texture2D:
		var ti := Kit.IconRect.new()
		ti.custom_minimum_size = Vector2(16, 16)
		ti.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ti.set_icon(title_icon)
		head.add_child(ti)
	var tex: Variant = m.get("icon")
	if tex is Texture2D:
		var ir := Kit.IconRect.new()
		ir.custom_minimum_size = Vector2(22, 22)
		ir.set_icon(tex)
		head.add_child(ir)
	var tl := Kit.label(13, m.get("title_color", Color.WHITE), 800)
	tl.text = str(m.get("title", ""))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	if str(m.get("sub", "")) != "":
		var sl := Kit.label(10, Kit.DIM, 600)
		sl.text = str(m["sub"])
		head.add_child(sl)
	for b: Dictionary in m.get("bars", []):
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		box.add_child(hb)
		var l := Kit.label(9, b.get("label_color", Kit.DIM), 800)
		l.text = str(b["label"])
		l.custom_minimum_size = Vector2(18, 0)
		hb.add_child(l)
		var bar := Kit.Bar.new()
		bar.custom_minimum_size = Vector2(maxf(80.0, width - 110.0), 5)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.radius = 2
		bar.set_value(float(b["ratio"]), b["c0"], b["c1"])
		hb.add_child(bar)
		var v := Kit.label(10, Kit.TEXT, 700)
		v.text = str(b["text"])
		v.custom_minimum_size = Vector2(46, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hb.add_child(v)
	if str(m.get("stats", "")) != "":
		var st := Kit.label(10, Kit.DIM, 600)
		st.text = str(m["stats"])
		box.add_child(st)
	for ln: String in m.get("lines", []):
		var ll := Kit.label(11, Color("cbd5e1"), 500)
		ll.text = icons.call("strip", ln)
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.custom_minimum_size = Vector2(width, 0)
		box.add_child(ll)
	var bl: Array = m.get("buffs", [])
	if not bl.is_empty():
		box.add_child(_sep())
		for b2: Dictionary in bl:
			var hb2 := HBoxContainer.new()
			hb2.add_theme_constant_override("separation", 5)
			box.add_child(hb2)
			hb2.add_child(HudCards.buff_icon(icons, b2, 16))
			var bn := Kit.label(10, Color("fca5a5") if b2.get("type") == "debuff" else Color("bbf7d0"), 600)
			bn.text = icons.call("strip", str(b2["label"]))
			bn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb2.add_child(bn)
			if int(b2.get("turns", 0)) > 0:
				var tt := Kit.label(10, Kit.DIM, 700)
				tt.text = str(b2.get("turns_text", ""))
				hb2.add_child(tt)
	var sk: Array = m.get("skills", [])
	if not sk.is_empty():
		box.add_child(_sep())
		for s: Dictionary in sk:
			var hb3 := HBoxContainer.new()
			hb3.add_theme_constant_override("separation", 5)
			box.add_child(hb3)
			var ir2 := Kit.IconRect.new()
			ir2.custom_minimum_size = Vector2(18, 18)
			ir2.set_icon(s.get("tex"))
			hb3.add_child(ir2)
			var sn := Kit.label(10, Color("ddd6fe"), 700)
			sn.text = str(s["name"])
			sn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb3.add_child(sn)
			if str(s.get("sub", "")) != "":
				var ss := Kit.label(9, Kit.DIM, 600)
				ss.text = str(s["sub"])
				hb3.add_child(ss)
	for k: String in ["ai", "intent"]:
		if str(m.get(k, "")) != "":
			var il := Kit.label(10, Color("fecaca") if k == "intent" else Color("fdba74"), 700)
			il.text = str(m[k])
			il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			il.custom_minimum_size = Vector2(width, 0)
			box.add_child(il)


func _sep() -> Control:
	var s := ColorRect.new()
	s.color = Color(1, 1, 1, 0.06)
	s.custom_minimum_size = Vector2(0, 1)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s
