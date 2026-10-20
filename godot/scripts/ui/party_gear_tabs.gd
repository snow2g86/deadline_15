extends RefCounted
## 편성 화면의 장비 · 소모품 · 강화 탭 (4b-1) — 웹 js/party-select.js 의 renderChars·showEquipModal·renderModalBody·renderInventoryInModal ·
##  renderItemTab·showPotionUseModal · renderEnhanceList·showEnhanceConfirmModal·executeEnhance·repairEquipUI·dismantleEquipUI + css/party-select.css·equip.css
##  화면(party_select.gd = scr)의 창·알림·글 도구를 빌려 씀. 규칙은 scripts/logic/equip_rules.gd (웹과 같은 저장 형식·난수 순서)
##  자원이 오가는 단추(끼우기·빼기·판매·분해·수리·강화·물약)는 같은 프레임 연타를 막음 (scr.act_once)
##  '비교 표시' = 웹과 같은 것: 카드 장비 칸의 ↑(같은 부위에 더 높은 등급의 안 낀 장비가 있음), 장비 창 목록의 '장착 중(이 클랜원/다른 클랜원)' 표시

const OKit := preload("res://scripts/ui/outer_kit.gd")
const Kit := preload("res://scripts/battle/ui_kit.gd")
const Js := preload("res://scripts/logic/js.gd")
const Num := preload("res://scripts/core/num.gd")
const EquipRules := preload("res://scripts/logic/equip_rules.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")
const Gear := preload("res://scripts/logic/gear.gd")
const ItemView := preload("res://scripts/ui/item_view.gd")
const OddsView := preload("res://scripts/ui/odds_view.gd")

const MODAL_W := 1060.0
const INV_CARD_W := 300.0

var scr: Control
var c: Object
var D: Dictionary
var sections: Dictionary = {}   # tab → Control
var eq_filter := "all"
var inv_filter := "all"
var sel_uid: Variant = null
var protect := false
## 장비 탭
var eq_filters: HBoxContainer
var eq_grid: GridContainer
## 아이템 탭
var item_list: VBoxContainer
## 강화 탭
var enh_list: VBoxContainer
## 장비 창 · 강화 창 (열려 있을 때)
var equip_modal: Control
var equip_body: VBoxContainer
var enh_modal: Control


func _init(screen: Control) -> void:
	scr = screen
	c = screen.c
	D = screen.D


func t(k: String, p: Dictionary = {}) -> String:
	return scr.t(k, p)


func tw() -> Callable:
	return func(k: String, p: Dictionary) -> String: return scr.t(k, p)


func num(v: Variant) -> String:
	return Num.fmt(v)


func _strip(s: String) -> String:
	return scr.icons.call("strip", s)


func _scroll_section(nm: String, max_w: float, parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = nm
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.follow_focus = true
	sc.visible = false
	parent.add_child(sc)
	var mw := OKit.MaxWidth.new()
	mw.max_w = max_w
	mw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(mw)
	var v := OKit.vbox(8)
	mw.add_child(v)
	return v


func build(parent: Control) -> void:
	# 장비 탭: 직업군 필터 + 클랜원 카드 (웹 .eq-filter-tabs · .eq-chars)
	var ev := _scroll_section("SectionEquip", 780.0, parent)
	sections["equip"] = ev.get_parent().get_parent()
	eq_filters = OKit.hbox(6)
	eq_filters.name = "EqFilters"
	ev.add_child(eq_filters)
	eq_grid = GridContainer.new()
	eq_grid.name = "EqChars"
	eq_grid.columns = 3
	eq_grid.add_theme_constant_override("h_separation", 12)
	eq_grid.add_theme_constant_override("v_separation", 12)
	ev.add_child(eq_grid)
	# 소모품 탭 (웹 .item-list)
	item_list = _scroll_section("SectionItem", 480.0, parent)
	item_list.name = "ItemList"
	sections["item"] = item_list.get_parent().get_parent()
	# 강화 탭 (웹 .enhance-list)
	enh_list = _scroll_section("SectionEnhance", 520.0, parent)
	enh_list.name = "EnhanceList"
	sections["enhance"] = enh_list.get_parent().get_parent()


func show(tab: String) -> void:
	for k: String in sections.keys():
		(sections[k] as Control).visible = k == tab
	match tab:
		"equip":
			render_equip()
		"item":
			render_items()
		"enhance":
			render_enhance()


func _clear(n: Node) -> void:
	for ch: Node in n.get_children():
		n.remove_child(ch)
		ch.queue_free()


func _empty_state(emoji: String, text: String, shop_btn: bool) -> Control:
	var p := PanelContainer.new()
	p.name = "Empty"
	p.add_theme_stylebox_override("panel", OKit.box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.08), 10, 1, 16, 18))
	var v := OKit.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var ic := OKit.tex_rect(scr.emoji_tex(emoji), Vector2(32, 32))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := OKit.label(13, OKit.DIM2, 600)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	v.add_child(l)
	if shop_btn:
		var b := OKit.ghost_button("", 12)
		b.name = "GoShop"
		scr.set_button_text(b, "🛒 " + t("nav.shop"), 16)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void: scr.router.call("go", "shop"))
		v.add_child(b)
	return p


# ═══════════ 장비 탭 ═══════════

func render_equip() -> void:
	_clear(eq_filters)
	var keys := ["all"]
	for g: String in PartyRules.groups_present(c):
		keys.append("group_" + g)
	if not keys.has(eq_filter):
		eq_filter = "all"
	for k: String in keys:
		var on := k == eq_filter
		var b := OKit.styled_button(OKit.box(Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.18) if on else Color(1, 1, 1, 0.04), Color("60a5fa") if on else Color(1, 1, 1, 0.12), 6, 1, 10, 5),
			OKit.box(Color(1, 1, 1, 0.08), Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.5), 6, 1, 10, 5), null, 6)
		b.name = "EqFilter_" + k
		scr.set_button_text(b, t("common.all") if k == "all" else t("group." + k.trim_prefix("group_")), 14)
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", Color("bfdbfe") if on else OKit.DIM2)
		b.add_theme_color_override("font_hover_color", OKit.TEXT)
		b.add_theme_color_override("font_focus_color", OKit.TEXT)
		b.pressed.connect(func() -> void:
			eq_filter = k
			render_equip())
		eq_filters.add_child(b)
	_clear(eq_grid)
	var inv := Profile.load_inventory(c)
	scr._inv_map = scr._inventory_map()
	var list := EquipRules.equip_chars(c, eq_filter)
	if list.is_empty():
		var e := OKit.label(13, OKit.DIM, 500)
		e.text = t("party.no_available_chars")
		eq_grid.add_child(e)
	for ch: Dictionary in list:
		var card: Button = scr._unit_card(ch, EquipRules.in_active_party(c, ch["uid"]), EquipRules.card_slots(c, ch, inv))
		card.name = "EqUnit_%s" % num(ch["uid"])
		var uid: Variant = ch["uid"]
		card.pressed.connect(func() -> void: open_equip_modal(uid))
		eq_grid.add_child(card)


func open_equip_modal(uid: Variant) -> void:
	sel_uid = uid
	inv_filter = "all"
	equip_body = OKit.vbox(10)
	equip_body.name = "EquipBody"
	var sb := OKit.box(Color("0d1322"), Color(1, 1, 1, 0.1), 16, 1, 20, 18)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 24
	equip_modal = scr.open_modal(equip_body, {"name": "EquipModal", "title": "⚔️ " + t("equip.detail_title"), "title_size": 20, "width": MODAL_W, "box": sb, "close_x": true,
		"on_close": func() -> void:
			sel_uid = null
			equip_modal = null})
	render_equip_modal()


## 장비 창 내용 (웹 renderModalBody): 왼쪽 슬롯·스탯·세트·장비 효과 | 오른쪽 인벤토리 (필터 · 카드)
func render_equip_modal() -> void:
	if equip_body == null or not is_instance_valid(equip_body):
		return
	_clear(equip_body)
	var ch: Variant = Profile.get_char(c, sel_uid)
	if ch == null:
		var e := OKit.label(13, OKit.DIM, 500)
		e.text = t("equip.select_char")
		equip_body.add_child(e)
		return
	EquipRules.ensure_equip_slots(c, ch)
	var inv := Profile.load_inventory(c)
	var lay := OKit.hbox(16)
	lay.name = "Layout"
	equip_body.add_child(lay)
	var left := OKit.vbox(10)
	left.name = "Left"
	left.custom_minimum_size = Vector2(330, 0)
	if scr.is_mobile_ui():
		# (6a) 좁은 휴대폰 창: 왼쪽 칸·간격을 조금 줄여 창이 안전 영역 안에 들어가게
		left.custom_minimum_size.x = 300
		lay.add_theme_constant_override("separation", 10)
	lay.add_child(left)
	# 누구 (이름 · 직업)
	var who := OKit.hbox(8)
	who.add_child(scr.cls_icon(str(ch["cls"]), 22))
	var wl := OKit.label(14, Color.WHITE, 800)
	wl.text = "%s · Lv.%s %s" % [scr.char_name(ch), num(ch.get("lv", 1)), t("classes." + str(ch["cls"]))]
	wl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	wl.custom_minimum_size = Vector2(290, 0)
	who.add_child(wl)
	left.add_child(who)
	# 슬롯
	var ss := _section(t("equip.slots_title"))
	left.add_child(ss)
	var sg := GridContainer.new()
	sg.name = "Slots"
	sg.columns = 2
	sg.add_theme_constant_override("h_separation", 6)
	sg.add_theme_constant_override("v_separation", 6)
	ss.get_child(0).add_child(sg)
	for sm: Dictionary in EquipRules.modal_slots(c, ch, inv):
		sg.add_child(_slot_cell(sm))
	# 스탯
	var st := _section(t("equip.stats_title"))
	left.add_child(st)
	var bonus := Gear.calc_equip_bonus(c, ch)
	var stg := GridContainer.new()
	stg.columns = 2
	stg.add_theme_constant_override("h_separation", 18)
	stg.add_theme_constant_override("v_separation", 3)
	st.get_child(0).add_child(stg)
	for k: String in ["hp", "atk", "def", "move", "range"]:
		var row := OKit.hbox(4)
		row.custom_minimum_size = Vector2(135, 0)
		var lb := OKit.label(11, OKit.DIM2, 600)
		lb.text = t("common." + k)
		row.add_child(lb)
		row.add_child(OKit.spacer())
		var vl := OKit.label(12, Color.WHITE, 800)
		vl.text = num(Js.num(ch.get(k)))
		row.add_child(vl)
		if Js.num(bonus.get(k)) > 0.0:
			var bl := OKit.label(11, Color("4ade80"), 700)
			bl.text = "+" + num(bonus[k])
			row.add_child(bl)
		stg.add_child(row)
	# 세트
	var sets := EquipRules.set_counts(c, ch, inv)
	if not sets.is_empty():
		var se := _section("")
		left.add_child(se)
		for pr: Array in sets:
			se.get_child(0).add_child(_set_row(str(pr[0]), int(pr[1])))
	# 장비 효과 합계
	var gk: Array = (bonus.get("gear", {}) as Dictionary).keys()
	if not gk.is_empty():
		var gx := _section("◆ " + t("gear.fx_total"))
		left.add_child(gx)
		for k2: String in gk:
			var gl := OKit.label(10, ItemView.LINE_COLORS["fx"], 700)
			gl.text = EquipRules.fmt(c, k2, bonus["gear"][k2], tw())
			gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			gl.custom_minimum_size = Vector2(300, 0)
			gx.get_child(0).add_child(gl)
	# 오른쪽: 인벤토리
	var right := OKit.vbox(8)
	right.name = "Right"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lay.add_child(right)
	var it_head := OKit.label(13, OKit.GOLD, 800)
	it_head.text = t("equip.inventory")
	right.add_child(it_head)
	var fr := OKit.hbox(6)
	fr.name = "InvFilters"
	right.add_child(fr)
	for f: Array in [["all", "party.filter_all"], ["weapon", "equip.slot.weapon"], ["armor", "equip.filter_armor"], ["accessory", "equip.filter_accessory"]]:
		var on: bool = f[0] == inv_filter
		var fb := OKit.styled_button(OKit.box(Color(OKit.GOLD, 0.14) if on else Color(1, 1, 1, 0.04), Color(OKit.GOLD, 0.6) if on else Color(1, 1, 1, 0.1), 6, 1, 10, 4),
			OKit.box(Color(1, 1, 1, 0.08), Color(OKit.GOLD, 0.4), 6, 1, 10, 4), null, 6)
		fb.name = "InvFilter_" + str(f[0])
		fb.text = t(str(f[1]))
		fb.add_theme_font_size_override("font_size", 11)
		if scr.is_mobile_ui():
			fb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS   # (6a) 좁은 창: 긴 이름(스페인어 등)은 말줄임
			fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.add_theme_color_override("font_color", OKit.GOLD if on else OKit.DIM2)
		fb.add_theme_color_override("font_hover_color", OKit.TEXT)
		fb.add_theme_color_override("font_focus_color", OKit.TEXT)
		var key: String = f[0]
		fb.pressed.connect(func() -> void:
			inv_filter = key
			render_equip_modal())
		fr.add_child(fb)
	var rows := EquipRules.modal_inventory(c, ch, inv_filter, inv)
	if rows.is_empty():
		right.add_child(_empty_state("🗡️", t("equip.no_items"), false))
	var g := GridContainer.new()
	g.name = "InvList"
	g.columns = 2
	if scr.is_mobile_ui() and scr.get_viewport_rect().size.x < 1200.0:
		g.columns = 1   # (6a) 휴대폰 논리 폭(약 1070)에는 카드 두 줄이 안 들어감 — 한 줄로 (스크롤)
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	right.add_child(g)
	for m: Dictionary in rows:
		g.add_child(_inv_card(ch, m))
	_pin_equip_columns.call_deferred(lay, left, right, g)
	scr._fit_modal.call_deferred(equip_modal)


## (6a QA) 장비 창: 왼쪽(장착 칸·능력치·세트·효과)은 고정하고 오른쪽 인벤토리 목록만 스크롤. 창 전체가 아니라 두 칸이 각자 스크롤 안에 있어
##  높이가 모자라면(휴대폰) 왼쪽도 따로 스크롤. 높이 = 왼쪽 내용 높이(창이 허용하는 만큼까지)
func _pin_equip_columns(lay: Control, left: Control, right: Control, grid: Control) -> void:
	if not is_instance_valid(lay) or not is_instance_valid(left) or not is_instance_valid(right) or not is_instance_valid(grid) or equip_modal == null:
		return
	var avail := 400.0
	for m: Dictionary in scr._modals:
		if m["root"] == equip_modal:
			avail = float(m["max_h"])
	var left_h := left.get_combined_minimum_size().y
	var h := clampf(left_h, 220.0, maxf(220.0, avail))
	var ls := ScrollContainer.new()
	ls.name = "LeftScroll"
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ls.custom_minimum_size = Vector2(left.get_combined_minimum_size().x + (10 if left_h > h else 0), h)
	var idx := left.get_index()
	lay.remove_child(left)
	lay.add_child(ls)
	lay.move_child(ls, idx)
	ls.add_child(left)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head_h := 0.0
	for k: Node in right.get_children():
		if k != grid and k is Control and (k as Control).visible:
			head_h += (k as Control).get_combined_minimum_size().y + 8.0
	var gs := ScrollContainer.new()
	gs.name = "InvScroll"
	gs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gs.custom_minimum_size = Vector2(0, maxf(120.0, h - head_h))
	var gi := grid.get_index()
	right.remove_child(grid)
	right.add_child(gs)
	right.move_child(gs, gi)
	gs.add_child(grid)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scr._fit_modal(equip_modal)


func _section(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", OKit.box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.08), 10, 1, 12, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := OKit.vbox(6)
	p.add_child(v)
	if title != "":
		var l := OKit.label(12, OKit.GOLD, 800)
		l.text = title
		v.add_child(l)
	return p


## 왼쪽 칸 하나 (채워져 있으면 눌러서 빼기, 두손 무기면 보조 칸 잠김)
func _slot_cell(sm: Dictionary) -> Control:
	var item: Variant = sm["item"]
	var slot := str(sm["slot"])
	var rc := ItemView.rarity_color(D, item.get("rarity")) if item != null else Color(1, 1, 1, 0.1)
	var b := OKit.styled_button(OKit.box(Color(1, 1, 1, 0.03) if item == null else Color(rc, 0.08), Color(1, 1, 1, 0.1) if item == null else Color(rc, 0.6), 8, 1, 8, 6),
		OKit.box(Color(1, 1, 1, 0.06), OKit.GOLD if item != null else Color(1, 1, 1, 0.15), 8, 1, 8, 6), null, 8)
	b.name = "Slot_" + slot
	b.custom_minimum_size = Vector2(150, 54)
	var v := OKit.vbox(2)
	OKit.set_content(b, v, Vector4(8, 6, 8, 6))
	var sl := OKit.label(10, OKit.DIM, 600)
	sl.text = t("equip.slot." + slot)
	v.add_child(sl)
	if sm["locked"]:
		var lk := OKit.vec_icon("lock", 14, OKit.DIM)
		v.add_child(lk)
		b.tooltip_text = t("equip.slot." + slot)
		b.disabled = true
	elif item != null:
		var h := OKit.hbox(4)
		var rl := OKit.label(10, rc, 900)
		rl.text = EquipRules.rarity_letter(item, tw())
		h.add_child(rl)
		var nl := OKit.label(11, Color.WHITE, 700)
		nl.text = EquipRules.gear_name(item, tw())
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.custom_minimum_size = Vector2(110, 0)
		h.add_child(nl)
		v.add_child(h)
		b.tooltip_text = t("equip.unequip_btn")
		b.pressed.connect(func() -> void: do_unequip(slot))
	else:
		var dl := OKit.label(11, OKit.DIM, 600)
		dl.text = "-"
		v.add_child(dl)
		b.disabled = true
	return b


func _set_row(set_id: String, cnt: int) -> Control:
	var v := OKit.vbox(2)
	var nm := OKit.label(11, OKit.GOLD, 800)
	v.add_child(nm)
	var parts: Array = []   # [글, 켜짐]
	if set_id.begins_with("cls_"):
		var sc := set_id.substr(4)
		nm.text = t("gear.set_progress", {"set": t("gear.set." + sc), "n": cnt})
		var cdef: Dictionary = (D["CLASS_SETS"] as Dictionary).get(sc, {})
		for n: int in [2, 3]:
			var fx: Array = []
			var sd: Dictionary = cdef.get(str(n), {})
			for k: String in sd.keys():
				fx.append(EquipRules.fmt(c, k, sd[k], tw()))
			parts.append(["(%d) %s" % [n, " · ".join(fx)], cnt >= n])
	else:
		nm.text = t("equip.set." + set_id)
		var sdef: Dictionary = (D["EQUIP_SETS"] as Dictionary).get(set_id, {})
		for th: String in sdef.keys():
			var bs: Array = []
			for bk: String in sdef[th].keys():
				bs.append(t("common." + bk) + "+" + num(sdef[th][bk]))
			parts.append(["(%s) %s" % [th, " ".join(bs)], cnt >= int(th)])
	for p: Array in parts:
		var l := OKit.label(10, Color("4ade80") if p[1] else OKit.DIM, 700)
		l.text = p[0]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		v.add_child(l)
	return v


## 인벤토리 카드 (웹 .eq-inv-card): 직업 제한 아이콘 · 등급 · 그림 · 이름 +강화 · 파손 · 능력치 · 세트 · 옵션 줄 · 단추
func _inv_card(ch: Dictionary, m: Dictionary) -> Control:
	var it: Dictionary = m["item"]
	var rc := ItemView.rarity_color(D, it.get("rarity"))
	var border := Color(1, 1, 1, 0.08)
	if m["here"]:
		border = OKit.GOLD
	elif Js.truthy(it.get("legend")):
		border = Color(OKit.GOLD, 0.5)
	var p := PanelContainer.new()
	p.name = "Inv_" + str(it.get("eid"))
	p.add_theme_stylebox_override("panel", OKit.box(Color(OKit.GOLD, 0.06) if m["here"] else Color(1, 1, 1, 0.03), border, 10, 1 if not m["here"] else 2, 10, 10))
	p.custom_minimum_size = Vector2(INV_CARD_W, 0)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	if m["other"] or Js.truthy(it.get("broken")):
		p.modulate.a = 0.75
	var v := OKit.vbox(4)
	p.add_child(v)
	var head := OKit.hbox(3)
	v.add_child(head)
	var cr: Variant = it.get("clsRestrict")
	if cr is Array and not (cr as Array).is_empty() and (cr as Array).size() < (D["CLASS_GROUP_MAP"] as Dictionary).size():
		for cl: Variant in (cr as Array).slice(0, 6):
			head.add_child(scr.cls_icon(str(cl), 18))
	head.add_child(OKit.spacer())
	var rl := OKit.pill(EquipRules.rarity_letter(it, tw()), 10, rc, Color(0, 0, 0, 0.3), rc)
	head.add_child(rl)
	var ib := CenterContainer.new()
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ib.add_child(ItemView.equip_icon(scr.icons, D, it, 40))
	v.add_child(ib)
	var nr := OKit.hbox(4)
	nr.name = "NameRow"
	nr.alignment = BoxContainer.ALIGNMENT_CENTER
	var has_lv := EquipRules.enhance_lv(it) > 0.0
	var nl := OKit.label(13, Color.WHITE, 800)
	nl.name = "Name"
	nl.text = EquipRules.gear_name(it, tw())
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(INV_CARD_W - 24 - (36 if has_lv else 0), 0)
	nr.add_child(nl)
	if has_lv:
		var el := OKit.label(12, OKit.GOLD, 900)
		el.text = "+" + num(it["enhanceLv"])
		nr.add_child(el)
	v.add_child(nr)
	var tags: Array = []
	if m["here"]:
		tags.append([t("equip.equipped"), OKit.GOLD])
	elif m["other"]:
		var who: Variant = Profile.get_char(c, it.get("equipped"))
		tags.append([t("gear.equipped_by", {"name": scr.char_name(who)}) if who != null else t("equip.equipped"), OKit.DIM2])
	if Js.truthy(it.get("broken")):
		tags.append(["💥 " + t("gear.broken"), Color("ef4444")])
	for tg: Array in tags:
		v.add_child(_cl(str(tg[0]), 10, tg[1], 700))
	var st := EquipRules.stats_text(c, it, tw())
	if st != "":
		v.add_child(_cl(st, 11, Color("86efac"), 700))
	var setl := t("gear.set_name", {"set": t("gear.set." + str(it["setCls"]))}) if Js.truthy(it.get("setCls")) else (t("equip.set." + str(it["setId"])) if Js.truthy(it.get("setId")) else "")
	if setl != "":
		v.add_child(_cl(setl, 10, OKit.GOLD, 700))
	v.add_child(ItemView.lines_box(EquipRules.lines(c, it, ch["cls"], tw()), INV_CARD_W - 24, 10))
	var ar := OKit.hbox(6)
	ar.alignment = BoxContainer.ALIGNMENT_CENTER
	ar.name = "Actions"
	v.add_child(ar)
	var eid: Variant = it.get("eid")
	for a: String in m["actions"]:
		var b: Button
		match a:
			"equip":
				b = _act_btn(t("equip.equip_btn"), Color("22c55e"))
				b.pressed.connect(func() -> void: do_equip(eid))
			"unequip":
				b = _act_btn(t("equip.unequip_btn"), Color("64748b"))
				b.pressed.connect(func() -> void: do_unequip(str(it.get("slot"))))
			"sell":
				b = _act_btn(t("equip.sell_btn", {"gold": num(EquipRules.sell_price(c, it))}), Color("b91c1c"))
				b.pressed.connect(func() -> void: ask_sell(eid))
			"dismantle":
				b = _act_btn("", Color("475569"))
				scr.set_button_text(b, "🔩 " + t("gear.dismantle_btn"), 14)
				b.pressed.connect(func() -> void: ask_dismantle(eid))
			"repair":
				b = _act_btn("", Color("2563eb"))
				scr.set_button_text(b, "🔧 " + t("gear.repair_btn", {"gold": num(EquipRules.repair_cost(c, it))}), 14)
				b.pressed.connect(func() -> void: ask_repair(eid))
		b.name = "Act_" + a
		ar.add_child(b)
	return p


func _cl(text: String, size: int, col: Color, w: int) -> Label:
	var l := OKit.label(size, col, w)
	l.text = _strip(text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(INV_CARD_W - 24, 0)
	return l


func _act_btn(text: String, col: Color) -> Button:
	var b := OKit.styled_button(OKit.box(col, Color(0, 0, 0, 0), 6, 0, 10, 5), OKit.box(col.lightened(0.15), Color(0, 0, 0, 0), 6, 0, 10, 5), null, 6)
	b.text = text
	b.add_theme_font_size_override("font_size", 11)
	for k: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	return b


func _after_change() -> void:
	scr.refresh_gold()
	render_equip()
	render_equip_modal()


func do_equip(eid: Variant) -> void:
	if not scr.act_once():
		return
	var ch: Variant = Profile.get_char(c, sel_uid)
	var it: Variant = EquipRules.find_item(Profile.load_inventory(c), eid)
	# 화면에서 끼울 수 있는 것만 (웹 단추 조건과 같음 — 다른 클랜원이 낀 것·직업 제한·파손은 단추가 없음)
	if ch == null or it == null or not EquipRules.can_equip(c, ch, it) or (Js.truthy(it.get("equipped")) and not Js.same(it.get("equipped"), sel_uid)):
		return
	EquipRules.equip_item(c, sel_uid, eid)
	_after_change()


func do_unequip(slot: String) -> void:
	if not scr.act_once():
		return
	EquipRules.unequip_item(c, sel_uid, slot)
	_after_change()


func ask_sell(eid: Variant) -> void:
	if not scr.act_once():
		return
	var it: Variant = EquipRules.find_item(Profile.load_inventory(c), eid)
	if it == null or Js.truthy(it.get("equipped")):
		return
	scr.confirm(t("equip.sell_confirm", {"name": EquipRules.gear_name(it, tw()), "gold": num(EquipRules.sell_price(c, it))}), func() -> void:
		EquipRules.sell_equip(c, eid)
		_after_change())


func ask_dismantle(eid: Variant) -> void:
	if not scr.act_once():
		return
	var it: Variant = EquipRules.find_item(Profile.load_inventory(c), eid)
	if it == null:
		return
	var sh := t("gear.dismantle_shard") if Js.truthy(it.get("legend")) else ""
	scr.confirm(t("gear.dismantle_confirm", {"name": EquipRules.gear_name(it, tw()), "n": num(EquipRules.dismantle_yield(c, it)), "shard": sh}), func() -> void:
		var r := EquipRules.dismantle_item(c, eid)
		if r.has("err"):
			return
		_after_change()
		render_enhance()
		scr.alert(t("gear.dismantle_done", {"n": num(r["stones"]), "shard": t("gear.dismantle_shard") if float(r["shard"]) > 0.0 else ""})))


func ask_repair(eid: Variant) -> void:
	if not scr.act_once():
		return
	var it: Variant = EquipRules.find_item(Profile.load_inventory(c), eid)
	if it == null:
		return
	var nm := EquipRules.gear_name(it, tw())
	scr.confirm(t("gear.repair_confirm", {"name": nm, "gold": num(EquipRules.repair_cost(c, it))}), func() -> void:
		var r := EquipRules.repair_item(c, eid)
		if r.has("err"):
			scr.alert(t("gear.err_gold" if r["err"] == "gold" else "enhance.error_invalid"))
			return
		_after_change()
		render_enhance()
		scr.alert(t("gear.repair_done", {"name": nm})))


# ═══════════ 소모품 탭 ═══════════

func render_items() -> void:
	_clear(item_list)
	var tab := EquipRules.item_tab(c)
	if not tab["has_any"]:
		item_list.add_child(_empty_state("🎒", t("party.no_items"), true))
		return
	if not (tab["potions"] as Array).is_empty():
		item_list.add_child(_sec_title("💊", t("party.sec_exp_potions")))
		for g: Dictionary in tab["potions"]:
			var pid := str(g["potionId"])
			var card := _item_card(ItemView.icon(scr.icons, pid, 36, str(g.get("icon", ""))), t(EquipRules.POTION_INFO[pid]["nameKey"]), "EXP +" + num(g.get("exp")), int(g["count"]))
			card.name = "Potion_" + pid
			var ub := _act_btn(t("party.potion_use"), Color("8b5cf6"))
			ub.name = "Use"
			ub.pressed.connect(func() -> void: open_potion_use(pid))
			card.get_child(0).add_child(ub)
			item_list.add_child(card)
	if not (tab["sieges"] as Array).is_empty():
		item_list.add_child(_sec_title("⚙️", t("party.sec_siege_items")))
		for s: Dictionary in tab["sieges"]:
			var card2 := _item_card(ItemView.icon(scr.icons, str(s["siegeId"]), 36, str(s.get("icon", ""))), t("shop." + str(s["siegeId"])), "", int(s["count"]))
			card2.name = "Siege_" + str(s["siegeId"])
			item_list.add_child(card2)


func _sec_title(emoji: String, text: String) -> Control:
	var h := OKit.hbox(6)
	h.add_child(OKit.tex_rect(scr.emoji_tex(emoji), Vector2(16, 16)))
	var l := OKit.label(13, OKit.GOLD, 800)
	l.text = text
	h.add_child(l)
	return h


func _item_card(icon: Control, name: String, sub: String, count: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", OKit.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08), 10, 1, 12, 8))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := OKit.hbox(10)
	p.add_child(h)
	h.add_child(icon)
	var v := OKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var nl := OKit.label(13, Color.WHITE, 800)
	nl.text = name
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nl)
	if sub != "":
		var sl := OKit.label(11, Color("a78bfa"), 700)
		sl.text = sub
		v.add_child(sl)
	var cl := OKit.label(12, OKit.DIM2, 700)
	cl.name = "Count"
	cl.text = t("party.potion_count", {"count": count})
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cl)
	return p


## 물약 쓸 클랜원 고르기 (웹 showPotionUseModal)
func open_potion_use(pid: String) -> void:
	var pot: Variant = null
	for it: Variant in Profile.load_inventory(c):
		if it is Dictionary and it.get("type") == "potion" and it.get("potionId") == pid:
			pot = it
			break
	if pot == null:
		return
	var targets := EquipRules.potion_targets(c)
	if targets.is_empty():
		scr.alert(t("party.no_available_chars"))
		return
	var pname := t(EquipRules.POTION_INFO[pid]["nameKey"]) if EquipRules.POTION_INFO.has(pid) else pid
	var v := OKit.vbox(6)
	v.name = "PotionTargets"
	var head := OKit.hbox(6)
	head.add_child(ItemView.icon(scr.icons, pid, 22, str(pot.get("icon", ""))))
	var hl := OKit.label(13, OKit.TEXT, 700)
	hl.text = "%s (EXP +%s)" % [pname, num(pot.get("exp"))]
	head.add_child(hl)
	v.add_child(head)
	var first: Button = null
	for ch: Dictionary in targets:
		var b := OKit.styled_button(OKit.box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.1), 8, 1, 10, 6), OKit.box(Color(OKit.GOLD, 0.1), OKit.GOLD, 8, 1, 10, 6), null, 8)
		b.name = "Target_%s" % num(ch["uid"])
		b.custom_minimum_size = Vector2(0, 36)
		var h := OKit.hbox(8)
		OKit.set_content(b, h, Vector4(10, 6, 10, 6))
		h.add_child(scr.cls_icon(str(ch["cls"]), 20))
		var nl := OKit.label(12, Color.WHITE, 700)
		nl.text = "%s Lv.%s" % [scr.char_name(ch), num(ch.get("lv", 1))]
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.custom_minimum_size = Vector2(220, 0)
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(nl)
		var el := OKit.label(11, OKit.DIM2, 600)
		el.text = "%s/%s" % [num(Js.num(ch.get("exp"))), num(Profile.exp_for_level(c, Js.num(ch.get("lv"))))]
		h.add_child(el)
		var uid: Variant = ch["uid"]
		b.pressed.connect(func() -> void: use_potion(pid, uid))
		v.add_child(b)
		if first == null:
			first = b
	scr.open_modal(v, {"name": "PotionModal", "title": "%s - %s" % [t("party.potion_use"), pname], "title_size": 18,
		"buttons": [{"text": t("common.cancel"), "secondary": true, "name": "Cancel"}]})
	if first != null:
		first.grab_focus.call_deferred()


func use_potion(pid: String, uid: Variant) -> void:
	if not scr.act_once() or not scr.modal_open():
		return
	scr.close_modal()
	var r := EquipRules.use_potion(c, pid, uid)
	render_items()
	if not r["ok"]:
		return
	var ch: Variant = Profile.get_char(c, uid)
	var nm: String = scr.char_name(ch) if ch != null else ""
	if int(r["leveled"]) > 0:
		scr.alert("%s\nLv.%s → Lv.%s%s" % [nm, num(r["prevLv"]), num(r["lv"]), (" (%d%s)" % [r["leveled"], t("party.potion_levelup_multi")]) if int(r["leveled"]) > 1 else ""])
	else:
		scr.alert(nm + " " + t("party.potion_use_success", {"exp": num(r["exp"])}))


# ═══════════ 강화 탭 ═══════════

func render_enhance() -> void:
	_clear(enh_list)
	var mats := _cl("🔩 " + t("gear.mats", {"stone": num(EquipRules.mats_get(c, "stone")), "protect": num(EquipRules.mats_get(c, "protect")), "shard": num(EquipRules.mats_get(c, "shard"))}), 13, OKit.GOLD, 800)
	mats.name = "Mats"
	mats.custom_minimum_size = Vector2(380, 0)
	mats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# (결제층 A) 확률 정보 단추 — 강화 성공·파손 확률표 (scripts/ui/odds_view.gd)
	var mrow := OKit.hbox(8)
	mrow.name = "MatsRow"
	mrow.custom_minimum_size = Vector2(500, 0)
	mrow.add_child(mats)
	var ob := OKit.ghost_button(t("gd.odds.btn"), 11)
	ob.name = "OddsBtn"
	ob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ob.pressed.connect(func() -> void:
		if scr.act_once():
			OddsView.open(scr))
	mrow.add_child(ob)
	enh_list.add_child(mrow)
	var hint := _cl(t("gear.enh_list_hint"), 10, OKit.DIM, 500)
	hint.custom_minimum_size = Vector2(500, 0)
	enh_list.add_child(hint)
	var L := EquipRules.enhance_list(c)
	for it: Dictionary in L["ok"]:
		enh_list.add_child(_enh_card(it))
	if (L["ok"] as Array).is_empty() and (L["broken"] as Array).is_empty():
		enh_list.add_child(_empty_state("🔨", t("enhance.no_items"), true))
	if not (L["broken"] as Array).is_empty():
		var bt := _cl("💥 " + t("gear.enh_broken_title"), 13, Color("ef4444"), 800)
		bt.custom_minimum_size = Vector2(500, 0)
		enh_list.add_child(bt)
		var bh := _cl(t("gear.broken_hint"), 10, OKit.DIM, 500)
		bh.custom_minimum_size = Vector2(500, 0)
		enh_list.add_child(bh)
		for it2: Dictionary in L["broken"]:
			enh_list.add_child(_enh_card(it2))


func _enh_card(it: Dictionary) -> Control:
	var broken := Js.truthy(it.get("broken"))
	var lv := EquipRules.enhance_lv(it)
	var mx := lv >= float(D["ENHANCE_MAX_LV"])
	var rc := ItemView.rarity_color(D, it.get("rarity"))
	var b := OKit.styled_button(OKit.box(Color(1, 1, 1, 0.03), Color(OKit.GOLD, 0.4) if Js.truthy(it.get("legend")) else Color(1, 1, 1, 0.08), 10, 1, 10, 8),
		OKit.box(Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.08), Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.4), 10, 1, 10, 8), null, 10)
	b.name = "Enh_" + str(it.get("eid"))
	b.custom_minimum_size = Vector2(0, 56)
	if broken:
		b.modulate.a = 0.8
	var h := OKit.hbox(10)
	OKit.set_content(b, h, Vector4(10, 8, 10, 8))
	h.add_child(ItemView.equip_icon(scr.icons, D, it, 40))
	var v := OKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := OKit.hbox(6)
	v.add_child(top)
	var nl := OKit.label(13, rc, 800)
	nl.text = EquipRules.gear_name(it, tw())
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.custom_minimum_size = Vector2(150, 0)
	top.add_child(nl)
	var ll := OKit.label(11, Color("60a5fa"), 800)
	ll.name = "Level"
	if broken:
		ll.text = _strip("💥 " + t("gear.broken"))
		ll.add_theme_color_override("font_color", Color("ef4444"))
	else:
		ll.text = ("+%s MAX" % num(lv)) if mx else "+%s → +%s" % [num(lv), num(lv + 1.0)]
	top.add_child(ll)
	var bot := OKit.hbox(6)
	v.add_child(bot)
	var wl := OKit.label(10, OKit.DIM2, 600)
	if not broken and Js.truthy(it.get("equipped")):
		var who: Variant = Profile.get_char(c, it["equipped"])
		if who != null:
			wl.text = t("gear.equipped_by", {"name": scr.char_name(who)})
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	wl.custom_minimum_size = Vector2(120, 0)
	bot.add_child(wl)
	if not broken and not mx:
		var rate := EquipRules.calc_enhance_rate(c, it)
		var rl := OKit.label(10, _rate_color(rate), 800)
		rl.name = "RateCost"
		rl.text = "%s%% • %sG •" % [num(Js.round_js(rate * 100.0)), num(EquipRules.calc_enhance_cost(c, it))]
		bot.add_child(rl)
		bot.add_child(OKit.tex_rect(scr.emoji_tex("🔩"), Vector2(12, 12)))
		var stl := OKit.label(10, _rate_color(rate), 800)
		stl.text = num(EquipRules.calc_enhance_stones(c, it))
		bot.add_child(stl)
	var eid: Variant = it.get("eid")
	if broken:
		var rb := _act_btn("", Color("2563eb"))
		rb.name = "Repair"
		scr.set_button_text(rb, "🔧 " + t("gear.repair_btn", {"gold": num(EquipRules.repair_cost(c, it))}), 14)
		rb.pressed.connect(func() -> void: ask_repair(eid))
		h.add_child(rb)
		var db := _act_btn("", Color("475569"))
		db.name = "Dismantle"
		scr.set_button_text(db, "🔩", 14)
		db.tooltip_text = t("gear.dismantle_btn")
		db.pressed.connect(func() -> void: ask_dismantle(eid))
		h.add_child(db)
		b.focus_mode = Control.FOCUS_NONE
	elif not mx:
		var eb := _act_btn(t("enhance.button_enhance"), Color("2563eb"))
		eb.name = "EnhanceBtn"
		eb.focus_mode = Control.FOCUS_NONE
		eb.pressed.connect(func() -> void: open_enhance(eid))
		eb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(eb)
		b.pressed.connect(func() -> void: open_enhance(eid))
	else:
		b.pressed.connect(func() -> void: open_enhance(eid))
	return b


func _rate_color(rate: float) -> Color:
	return Color("4ade80") if rate >= 0.80 else (Color("fbbf24") if rate >= 0.40 else Color("ef4444"))


## 강화 확인 창 (웹 showEnhanceConfirmModal)
func open_enhance(eid: Variant) -> void:
	if scr.modal_open():
		return
	var it: Variant = EquipRules.find_item(Profile.load_inventory(c), eid)
	if it == null or Js.truthy(it.get("broken")):
		return
	var pv := EquipRules.enhance_preview(c, it)
	if pv["max"]:
		scr.alert(t("gear.enh_max"))
		return
	if pv["have_protect"] <= 0.0:
		protect = false
	var lv: float = pv["lv"]
	var rc := ItemView.rarity_color(D, it.get("rarity"))
	var W := 420.0
	var v := OKit.vbox(10)
	v.name = "EnhanceConfirm"
	# 대상
	var s1 := _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08))
	v.add_child(s1)
	var tr := OKit.hbox(6)
	tr.add_child(ItemView.equip_icon(scr.icons, D, it, 24))
	var tl := OKit.label(13, rc, 800)
	tl.text = "%s +%s → +%s" % [EquipRules.gear_name(it, tw()), num(lv), num(lv + 1.0)]
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(W - 60, 0)
	tr.add_child(tl)
	s1.get_child(0).add_child(tr)
	s1.get_child(0).add_child(ItemView.lines_box(EquipRules.lines(c, it, null, tw()), W - 30, 10))
	# 성공
	var s2 := _box(Color(74 / 255.0, 222 / 255.0, 128 / 255.0, 0.1), Color(74 / 255.0, 222 / 255.0, 128 / 255.0, 0.3))
	v.add_child(s2)
	var sv: VBoxContainer = s2.get_child(0)
	sv.add_child(_wl("✨ " + t("enhance.success_reward", {"lv": num(lv + 1.0)}), 12, Color("4ade80"), 800, W))
	var gain: Array = []
	for g: Array in pv["gain"]:
		gain.append("%s %s→%s" % [t("common." + str(g[0])), num(g[1]), num(g[2])])
	if not gain.is_empty():
		sv.add_child(_wl(" · ".join(gain), 13, Color("4ade80"), 800, W))
	if pv["band_pct"] >= 0.0:
		sv.add_child(_wl(t("gear.enh_opt_chance", {"p": num(pv["band_pct"])}), 10, OKit.DIM2, 600, W))
	if int(pv["milestone"]) > 0:
		sv.add_child(_wl("★ " + t("gear.enh_milestone_%d" % int(pv["milestone"])), 10, OKit.GOLD, 700, W))
	var rate_row := OKit.hbox(4)
	var rl := OKit.label(10, OKit.DIM2, 600)
	rl.text = t("gear.enh_rate") + ":"
	rate_row.add_child(rl)
	var rv := OKit.label(13, _rate_color(pv["rate"]), 900)
	rv.name = "Rate"
	rv.text = "%s%%" % num(pv["rp"])
	rate_row.add_child(rv)
	if pv["bonus"] > 0.0:
		var bl := OKit.label(10, Color("fbbf24"), 700)
		bl.text = "(%s)" % t("gear.enh_bonus", {"n": num(pv["bonus"])})
		rate_row.add_child(bl)
	sv.add_child(rate_row)
	# 실패
	var s3 := _box(Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.08), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.3))
	v.add_child(s3)
	var fv: VBoxContainer = s3.get_child(0)
	var fail_txt := t("gear.enh_fail_keep") if pv["fail_keep"] else t("gear.enh_fail_drop", {"lv": num(lv - 1.0)})
	fv.add_child(_wl("⚠️ " + t("gear.enh_on_fail") + ": " + fail_txt, 12, Color("ef4444"), 800, W))
	fv.add_child(_wl("💥 " + t("gear.enh_break"), 10, OKit.DIM2, 600, W))
	var cb := CheckBox.new()
	cb.name = "Protect"
	cb.text = _strip(t("gear.enh_protect_use", {"n": num(pv["have_protect"])}))
	cb.add_theme_font_size_override("font_size", 11)
	cb.button_pressed = protect
	cb.disabled = pv["have_protect"] <= 0.0
	cb.toggled.connect(func(on: bool) -> void: protect = on)
	var ph := OKit.hbox(4)
	ph.add_child(OKit.tex_rect(scr.emoji_tex("📜"), Vector2(16, 16)))
	ph.add_child(cb)
	fv.add_child(ph)
	# 비용
	var s4 := _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08))
	v.add_child(s4)
	var cv: VBoxContainer = s4.get_child(0)
	cv.add_child(_wl("💰 " + t("gear.enh_cost"), 11, OKit.DIM2, 700, W))
	var cost_l := _wl("%s G · 🔩 %s" % [num(pv["cost"]), t("gear.enh_stones", {"need": num(pv["stones"]), "have": num(pv["have_stone"])})], 13, Color.WHITE, 800, W)
	cost_l.name = "Cost"
	cv.add_child(cost_l)
	enh_modal = scr.open_modal(v, {"name": "EnhanceModal", "title": t("enhance.confirm_title"), "title_size": 20, "width": W + 88.0, "close_x": true,
		"on_close": func() -> void: enh_modal = null,
		"buttons": [{"text": t("common.cancel"), "secondary": true, "name": "Cancel"},
			{"text": t("enhance.button_enhance"), "cb": func() -> void: execute_enhance(eid), "name": "Enhance", "keep": true}]})


func _box(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", OKit.box(bg, border, 8, 1, 12, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(OKit.vbox(4))
	return p


func _wl(text: String, size: int, col: Color, w: int, width: float) -> Label:
	var l := OKit.label(size, col, w)
	l.text = _strip(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width - 30, 0)
	return l


## 강화 실행 (웹 executeEnhance): 오류면 알림만 (창 유지), 아니면 창 닫고 결과 알림
func execute_enhance(eid: Variant) -> void:
	if not scr.act_once() or enh_modal == null:
		return
	var before: Variant = EquipRules.find_item(Profile.load_inventory(c), eid)
	var r := EquipRules.enhance_item(c, eid, protect)
	if r.has("err"):
		var em := {"gold": "gear.err_gold", "stone": "gear.err_stone", "max": "gear.enh_max", "broken": "gear.broken_hint"}
		scr.alert(t(str(em.get(r["err"], "enhance.error_invalid"))))
		return
	var item: Variant = EquipRules.find_item(Profile.load_inventory(c), eid)
	if item == null:
		item = before
	var name := EquipRules.gear_name(item, tw())
	if enh_modal != null and is_instance_valid(enh_modal):
		scr._close_modal_node(enh_modal, false)
	enh_modal = null
	scr.refresh_gold()
	render_enhance()
	var msg := ""
	if r.get("ok", false):
		msg = t("gear.enh_success", {"lv": num(r["lv"])}) + "\n" + name
		if r.get("opt") != null:
			msg += "\n\n" + t("gear.enh_opt_gained", {"opt": EquipRules.fmt(c, str(r["opt"]["id"]), r["opt"]["v"], tw())})
	elif r.get("broken", false):
		msg = t("gear.enh_fail") + "\n\n" + t("gear.enh_broken")
	else:
		msg = t("gear.enh_fail") + "\n" + name + "\n\n" + (t("gear.enh_fail_dropped", {"lv": num(r["lv"])}) if r.get("dropped", false) else t("gear.enh_fail_kept", {"lv": num(r["lv"])}))
		if r.get("protected", false):
			msg += "\n" + t("gear.enh_fail_protected")
	scr.alert(msg)
