extends Control
## 결과 화면 — 웹 render.js showRes (#modal-box.result): VICTORY/DEFEAT 제목, 결과 글, 연습 모드 안내, 별 3개(새 별 강조) + 조건,
##  보상(별 보상·골드·첫 클리어·새 클랜원·스킬북·룬·영혼석·장비 — 그림 아이콘), 전사자, 클랜원마다 경험치(+막대·레벨 업), 단추
##  model 은 장면(battle_scene._result_model)이 엔진 결과(S._expResults·_starResult …)를 읽어 만듦

const Kit := preload("res://scripts/battle/ui_kit.gd")

signal button_pressed(id: String)

var icons: Object
var dim: ColorRect
var box: PanelContainer
var _v: VBoxContainer          # 스크롤되는 내용
var _sc: ScrollContainer
var _btn_row: HBoxContainer    # 단추 줄 (스크롤 밖 — 늘 보임, 웹 #modal-buttons)
var reduce_motion := false
var buttons: Dictionary = {}   # id → Button (시험용)


func setup(p_icons: Object) -> void:
	icons = p_icons
	name = "Result"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	box = PanelContainer.new()
	box.name = "Box"
	add_child(box)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	box.add_child(outer)
	_sc = ScrollContainer.new()
	_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sc.custom_minimum_size = Vector2(400, 0)
	outer.add_child(_sc)
	_v = VBoxContainer.new()
	_v.add_theme_constant_override("separation", 8)
	_v.custom_minimum_size = Vector2(392, 0)
	_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sc.add_child(_v)
	_btn_row = HBoxContainer.new()
	_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_btn_row.add_theme_constant_override("separation", 8)
	outer.add_child(_btn_row)


func show_result(m: Dictionary) -> void:
	var win: bool = m["win"]
	var sb := Kit.box(Color(17 / 255.0, 24 / 255.0, 39 / 255.0, 0.98), Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.7) if win else Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.55), 14, 2, 20, 18)
	sb.shadow_color = Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.22) if win else Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.18)
	sb.shadow_size = 30
	box.add_theme_stylebox_override("panel", sb)
	for c: Node in _v.get_children():
		_v.remove_child(c)
		c.queue_free()
	buttons.clear()
	for c0: Node in _btn_row.get_children():
		_btn_row.remove_child(c0)
		c0.queue_free()
	# 제목 (웹 messages.victory '🏆 VICTORY' — 이모지는 그림으로)
	var trow := HBoxContainer.new()
	trow.alignment = BoxContainer.ALIGNMENT_CENTER
	trow.add_theme_constant_override("separation", 8)
	_v.add_child(trow)
	var tparts: Array = icons.call("split", str(m["title"]))
	var ttxt := ""
	for tp: Variant in tparts:
		if tp is Texture2D:
			var ti := Kit.IconRect.new()
			ti.name = "TitleIcon"
			ti.custom_minimum_size = Vector2(34, 34)
			ti.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ti.set_icon(tp)
			trow.add_child(ti)
		elif typeof(tp) == TYPE_STRING:
			ttxt += tp
	var title := Kit.label(30, Color("f0c040") if win else Color("f87171"), 900)
	title.name = "Title"
	title.text = ttxt.strip_edges()
	Kit.outline(title, 6, Color(0, 0, 0, 0.6))
	trow.add_child(title)
	var msg := Kit.label(12, Kit.DIM, 500)
	msg.text = str(m.get("msg", ""))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_v.add_child(msg)
	var notes: Array = m.get("notes", [])
	if not notes.is_empty():
		var np := PanelContainer.new()
		np.add_theme_stylebox_override("panel", Kit.box(Color(99 / 255.0, 102 / 255.0, 241 / 255.0, 0.1), Color(99 / 255.0, 102 / 255.0, 241 / 255.0, 0.25), 8, 1, 10, 6))
		_v.add_child(np)
		var nl := Kit.label(11, Color("a5b4fc"), 500)
		nl.text = "\n".join(notes)
		np.add_child(nl)
	var st: Variant = m.get("stars")
	if typeof(st) == TYPE_DICTIONARY:
		_v.add_child(_stars(st))
	for rw: Dictionary in m.get("rewards", []):
		_v.add_child(_reward(rw))
	if str(m.get("fallen", "")) != "":
		var fp := PanelContainer.new()
		fp.add_theme_stylebox_override("panel", Kit.box(Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.1), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.25), 8, 1, 10, 6))
		var fh := HBoxContainer.new()
		fh.add_theme_constant_override("separation", 6)
		fp.add_child(fh)
		var sk := Kit.IconRect.new()
		sk.custom_minimum_size = Vector2(16, 16)
		sk.set_icon(icons.call("emoji", "💀"))
		fh.add_child(sk)
		var fl := Kit.label(11, Color("fca5a5"), 600)
		fl.text = str(m["fallen"])
		fh.add_child(fl)
		_v.add_child(fp)
	var rows: Array = m.get("exp", [])
	if not rows.is_empty():
		# 웹 results.battle_detail '📈 처치 …' — 📈 은 그림(e_level_up)
		var hd := Kit.rich(10, Kit.DIM, 700)
		hd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hd.custom_minimum_size = Vector2(390, 0)
		icons.call("fill_rich", hd, str(m.get("detail", "")), 10)
		_v.add_child(hd)
		for i in rows.size():
			var row := _exp_row(rows[i])
			_v.add_child(row)
			_appear(row, 0.15 + i * 0.08)
	var br := _btn_row
	for b: Dictionary in m.get("buttons", []):
		var bt := Kit.button(str(b["text"]), Kit.GOLD, 13, Vector2(120, 38))
		bt.name = "Btn_" + str(b["id"])
		if b.get("primary", false):
			bt.add_theme_color_override("font_color", Color("1a1206"))
			bt.add_theme_color_override("font_hover_color", Color("1a1206"))
			bt.add_theme_stylebox_override("normal", Kit.box(Color("f0c040"), Color("b8860b"), 6, 1, 14, 6))
			bt.add_theme_stylebox_override("hover", Kit.box(Color("fcd34d"), Color("b8860b"), 6, 1, 14, 6))
		var id := str(b["id"])
		bt.pressed.connect(func() -> void: button_pressed.emit(id))
		br.add_child(bt)
		buttons[id] = bt
	visible = true
	box.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(box):
		return
	var vs := get_viewport_rect().size
	var sz := box.get_combined_minimum_size()
	# 내용만 스크롤: 창 높이 = 화면 92% 안에서 (단추 줄·여백을 뺀 만큼)
	var room := vs.y * 0.92 - 36.0 - 12.0 - _btn_row.get_combined_minimum_size().y
	_sc.custom_minimum_size = Vector2(400, clampf(_v.get_combined_minimum_size().y, 80.0, maxf(80.0, room)))
	box.reset_size()
	sz = box.get_combined_minimum_size()
	box.position = (vs - sz) / 2.0
	# 웹 resIn: 살짝 작고 아래에서 튀어 오름
	if not reduce_motion:
		box.pivot_offset = sz / 2.0
		box.scale = Vector2(0.88, 0.88)
		box.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(box, "modulate:a", 1.0, 0.25)


func _appear(c: Control, delay: float) -> void:
	if reduce_motion:
		return
	c.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.35)


## 별 3개 + 조건 (웹 .res-stars)
func _stars(st: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.box(Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.06), Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.22), 10, 1, 12, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var big := HBoxContainer.new()
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	big.add_theme_constant_override("separation", 8)
	v.add_child(big)
	var merged: Array = st["merged"]
	var newly: Array = st["newly"]
	for i in merged.size():
		var on := int(merged[i]) > 0
		var s := Kit.label(30, Color("facc15") if on else Color(1, 1, 1, 0.15), 900)
		s.text = "★"
		s.custom_minimum_size = Vector2(32, 34)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if on:
			Kit.outline(s, 6, Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.35))
		big.add_child(s)
		if not reduce_motion:
			s.pivot_offset = Vector2(16, 17)
			s.scale = Vector2(0.6, 0.6)
			s.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_interval(0.2 + i * 0.15)
			tw.set_parallel(true)
			tw.tween_property(s, "modulate:a", 1.0, 0.2)
			tw.tween_property(s, "scale", Vector2(1.35, 1.35) if newly.has(i) or newly.has(float(i)) else Vector2.ONE, 0.2)
			if newly.has(i) or newly.has(float(i)):
				tw.chain().tween_property(s, "scale", Vector2.ONE, 0.15)
	var conds: Array = st["conds"]
	var flags: Array = st["flags"]
	for i2 in conds.size():
		var ok := int(flags[i2]) > 0
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		v.add_child(r)
		var mk := Kit.label(11, Color("4ade80") if ok else Color("64748b"), 900)
		mk.text = "✓" if ok else "✕"
		mk.custom_minimum_size = Vector2(14, 0)
		r.add_child(mk)
		var lb := Kit.label(11, Color("e5e7eb") if ok else Color("94a3b8"), 500)
		lb.text = str(conds[i2])
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(lb)
		if newly.has(i2) or newly.has(float(i2)):
			var nw := PanelContainer.new()
			nw.add_theme_stylebox_override("panel", Kit.box(Color("facc15"), Color(0, 0, 0, 0), 999, 0, 6, 0))
			var nl := Kit.label(9, Color("1a1206"), 900)
			nl.text = "NEW"
			nw.add_child(nl)
			r.add_child(nw)
	return p


## 보상 한 줄 (웹 .res-reward: [아이콘][이름][값])
func _reward(rw: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.box(Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.09), Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.25), 8, 1, 10, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var ir := Kit.IconRect.new()
	ir.custom_minimum_size = Vector2(26, 26)
	ir.set_icon(rw.get("tex"), rw.get("frame"), rw.get("frame") == null)
	h.add_child(ir)
	var lb := Kit.label(12, Kit.TEXT if not rw.get("legend", false) else Color("fbbf24"), 700)
	lb.text = icons.call("strip", str(rw["label"]))
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(lb)
	if str(rw.get("value", "")) != "":
		var vl := Kit.label(14, Kit.GOLD, 900)
		vl.text = str(rw["value"])
		h.add_child(vl)
	return p


## 클랜원 경험치 (웹 .res-row: 초상화 · 이름 + 다음 레벨까지 막대 · +EXP · LV a → b)
func _exp_row(r: Dictionary) -> Control:
	var p := PanelContainer.new()
	var lvup: bool = r["lvup"]
	p.add_theme_stylebox_override("panel", Kit.box(Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.12) if lvup else Color(1, 1, 1, 0.04),
		Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.5) if lvup else Color(1, 1, 1, 0.06), 8, 1, 8, 5))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var por := Kit.Portrait.new()
	por.custom_minimum_size = Vector2(30, 30)
	por.set_unit(r["tex"], bool(r.get("summon", false)))
	h.add_child(por)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 3)
	h.add_child(mid)
	var nm := Kit.label(12, Kit.TEXT, 700)
	nm.text = str(r["name"])
	mid.add_child(nm)
	var bar := Kit.Bar.new()
	bar.custom_minimum_size = Vector2(0, 4)
	bar.radius = 2
	bar.set_value(float(r["ratio"]), Color("8b5cf6"), Color("c084fc"))
	mid.add_child(bar)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	h.add_child(right)
	var ex := Kit.label(11, Color("c084fc"), 900)
	ex.text = str(r["exp_text"])
	ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(ex)
	var lv := Kit.label(9, Color("facc15") if lvup else Kit.DIM, 700)
	lv.text = str(r["lv_text"])
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(lv)
	return p
