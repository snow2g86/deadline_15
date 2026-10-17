extends "res://scripts/ui/screen_base.gd"
## 파티 편성 — 웹 party-select.html + js/party-select.js(파티 탭 부분) + css/party-select.css
##  골드 배지, 페이지 탭(파티 · 장비 · 소모품 · 강화 — 장비·소모품·강화 탭은 4b-1: scripts/ui/party_gear_tabs.gd, 마지막 탭을 기억 = 웹 ps_active_tab),
##  왼쪽: 인원 'n / 5' + 파티 탭 5개(파티 1~5), 오른쪽: 5칸(클랜원 그림·Lv·직업·스킬·이름·등급·HP/ATK/DEF(+장비)·AR, ✕ 빼기 / 빈 칸 +) + 조합 버프,
##  출격 단추(스테이지를 고르고 왔을 때만 = ps_can_start 'true' 이고 5명일 때).
##  칸 누르기 → 유닛 고르기 창(직업군 필터 · 카드: 그림·등급·Lv·이름·스탯(+장비)(+잠재력)·장비 8칸(등급 색·+강화)·스킬) → 그 칸에 배치(다른 칸에 있으면 옮김)
##  뒤로: 로비 (웹 partyBack — 출격 단추 끔). 규칙은 scripts/logic/party_rules.gd

const PartyRules := preload("res://scripts/logic/party_rules.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const Gear := preload("res://scripts/logic/gear.gd")
const Synergy := preload("res://scripts/logic/synergy.gd")
const UnitInfo := preload("res://scripts/battle/unit_info.gd")
const Flow := preload("res://scripts/ui/flow.gd")
const PartyGearTabs := preload("res://scripts/ui/party_gear_tabs.gd")

const PAGE_TABS := [["party", "nav.party"], ["equip", "nav.equip"], ["item", "party.tab_item"], ["enhance", "nav.enhance"]]
const GRADE_BG := {"S": Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.15), "A": Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.15),
	"B": Color(74 / 255.0, 222 / 255.0, 128 / 255.0, 0.15), "C": Color(156 / 255.0, 163 / 255.0, 175 / 255.0, 0.15)}

var parties: Dictionary
var current_pid: Variant
var c_stage: Variant = null
var practice := false
var gold_lbl: Label
var page_tab_btns: Dictionary = {}
var counter: Label
var counter_box: PanelContainer
var party_tabs_box: VBoxContainer
var slots_box: VBoxContainer
var slots_scroll: ScrollContainer
var start_btn: Button
var info: Object
var _filter := "all"
var _started := false
var _modal_slot := -1
var unit_modal: Control
var _inv_map: Dictionary = {}
var cur_tab := "party"
var sec_party: VBoxContainer
var gear: RefCounted   # party_gear_tabs.gd


func page_id() -> String:
	return "party"


func title_text() -> String:
	return t("party.title")


## 웹 partyBack: 출격 단추 끄고 로비로
func go_back() -> void:
	PartyRules.set_can_start(c, false)
	router.call("go", "lobby")


func _build() -> void:
	info = UnitInfo.new(D, i18n)
	var nav: Variant = PartyRules.load_nav(c)
	if typeof(nav) == TYPE_DICTIONARY:
		c_stage = nav.get("cStage")
		practice = Js.truthy(nav.get("practiceMode"))
	parties = PartyRules.load_parties(c)
	current_pid = parties["activePartyId"]
	PartyRules.drop_dead(c, parties)
	PartyRules.normalize_equipped(c)
	var col := OKit.vbox(0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(col)
	# 골드 (웹 .page-hud)
	var hud := CenterContainer.new()
	hud.custom_minimum_size = Vector2(0, 64)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hud)
	var gb := gold_badge("0 G")
	hud.add_child(gb)
	gold_lbl = gb.find_child("Gold", true, false)
	# 페이지 탭 (웹 .game-tabs 최대 480)
	var tw := OKit.MaxWidth.new()
	tw.max_w = 480.0
	tw.custom_minimum_size = Vector2(0, 62)
	tw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tw)
	var tabs := OKit.hbox(6)
	tabs.name = "PageTabs"
	tw.add_child(tabs)
	for pt: Array in PAGE_TABS:
		var b := OKit.styled_button(OKit.box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.08), 8, 1, 8, 12),
			OKit.box(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.15), 8, 1, 8, 12), null, 8)
		b.name = "PageTab_" + str(pt[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_hover_color", OKit.TEXT)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var key: String = pt[0]
		b.pressed.connect(func() -> void: switch_page_tab(key))
		tabs.add_child(b)
		page_tab_btns[key] = [b, pt[1]]
	col.add_child(OKit.divider(0.06))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	# 본문: 파티 탭 / 장비 · 소모품 · 강화 탭 (하나만 보임)
	sec_party = OKit.vbox(0)
	sec_party.name = "SectionParty"
	sec_party.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sec_party)
	gear = PartyGearTabs.new(self)
	gear.build(col)
	# 파티: 왼쪽(인원·파티 탭) | 오른쪽(칸·조합 버프)
	var lw := OKit.MaxWidth.new()
	lw.max_w = 480.0
	lw.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sec_party.add_child(lw)
	var lay := OKit.hbox(12)
	lay.name = "Layout"
	lw.add_child(lay)
	var left := OKit.vbox(8)
	left.custom_minimum_size = Vector2(114, 0)
	lay.add_child(left)
	counter_box = PanelContainer.new()
	counter_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter_box.custom_minimum_size = Vector2(0, 44)
	left.add_child(counter_box)
	counter = OKit.label(16, OKit.BLUE, 800)
	counter.name = "Counter"
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	counter_box.add_child(counter)
	party_tabs_box = OKit.vbox(6)
	party_tabs_box.name = "PartyTabs"
	left.add_child(party_tabs_box)
	var right := OKit.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lay.add_child(right)
	slots_scroll = ScrollContainer.new()
	slots_scroll.name = "SlotsScroll"
	slots_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slots_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_scroll.follow_focus = true
	right.add_child(slots_scroll)
	slots_box = OKit.vbox(8)
	slots_box.name = "Slots"
	slots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_scroll.add_child(slots_box)
	# 출격 (웹 .ps-start)
	var sw := CenterContainer.new()
	sw.custom_minimum_size = Vector2(0, 76)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sec_party.add_child(sw)
	start_btn = OKit.modal_button("", false, 18)
	start_btn.name = "Start"
	start_btn.custom_minimum_size = Vector2(150, 48)
	start_btn.pressed.connect(confirm_start)
	sw.add_child(start_btn)
	# 저장된 탭으로 엶 (웹 Store ps_active_tab — 출격 단추는 파티 탭에서만)
	var saved: Variant = store.call("get_str", PartyRules.ACTIVE_TAB_KEY)
	for pt2: Array in PAGE_TABS:
		if saved != null and str(saved) == str(pt2[0]):
			cur_tab = str(saved)


func _refresh() -> void:
	refresh_gold()
	for k: String in page_tab_btns.keys():
		(page_tab_btns[k][0] as Button).text = t(page_tab_btns[k][1])
	start_btn.text = t("party.start_battle")
	_show_tab()


func refresh_gold() -> void:
	gold_lbl.text = "%s G" % grouped(Js.num(Profile.load_save(c).get("gold")))


## 페이지 탭 바꾸기 (웹 switchPageTab: Store ps_active_tab 에 기억)
func switch_page_tab(key: String) -> void:
	cur_tab = key
	store.call("set_str", PartyRules.ACTIVE_TAB_KEY, key)
	_show_tab()


func _show_tab() -> void:
	for k: String in page_tab_btns.keys():
		var b: Button = page_tab_btns[k][0]
		var on := k == cur_tab
		b.add_theme_stylebox_override("normal", OKit.box(Color(OKit.GOLD, 0.12) if on else Color(1, 1, 1, 0.04), OKit.GOLD if on else Color(1, 1, 1, 0.08), 8, 1, 8, 12))
		b.add_theme_color_override("font_color", Color.WHITE if on else OKit.DIM)
		b.add_theme_color_override("font_focus_color", Color.WHITE if on else OKit.TEXT)
	sec_party.visible = cur_tab == "party"
	gear.show(cur_tab)
	if cur_tab == "party":
		render_party_tabs()
		render_slots()
	refresh_gold()


func render_party_tabs() -> void:
	for ch: Node in party_tabs_box.get_children():
		party_tabs_box.remove_child(ch)
		ch.queue_free()
	var i := 0
	for p: Dictionary in parties["parties"]:
		i += 1
		var on := Js.same(p["id"], current_pid)
		var nb := OKit.box(Color(OKit.GOLD, 0.14) if on else Color(1, 1, 1, 0.04), Color(OKit.GOLD, 0.6) if on else Color(1, 1, 1, 0.12), 6, 1, 10, 6)
		var b := OKit.styled_button(nb, OKit.box(Color(OKit.GOLD, 0.08), Color(OKit.GOLD, 0.4), 6, 1, 10, 6), null, 6)
		b.name = "Party%d" % i
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 32)
		b.text = t("party.party_n", {"n": i})
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_font_override("font", Kit.bold(700 if on else 600))
		b.add_theme_color_override("font_color", OKit.GOLD if on else Color(1, 1, 1, 0.7))
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.9))
		b.add_theme_color_override("font_focus_color", OKit.GOLD if on else Color(1, 1, 1, 0.9))
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var pid: Variant = p["id"]
		b.pressed.connect(func() -> void: set_active_party(pid))
		party_tabs_box.add_child(b)


func set_active_party(pid: Variant) -> void:
	current_pid = pid
	PartyRules.set_active(c, parties, pid)
	render_party_tabs()
	render_slots()


func _inventory_map() -> Dictionary:
	var m: Dictionary = {}
	for it: Variant in Profile.load_inventory(c):
		if typeof(it) == TYPE_DICTIONARY and it.get("type") == "equip":
			m[it.get("eid")] = it
	return m


func render_slots() -> void:
	for ch: Node in slots_box.get_children():
		slots_box.remove_child(ch)
		ch.queue_free()
	var p: Variant = PartyRules.find_party(parties, current_pid)
	if p == null:
		return
	var by_uid := PartyRules.roster_map(c)
	_inv_map = _inventory_map()
	var slots: Array = p["slots"]
	for idx in slots.size():
		var uid: Variant = slots[idx]
		var ch: Variant = by_uid.get(uid) if uid != null else null
		slots_box.add_child(_slot_card(idx, ch))
	# 조합 버프 (이 파티로 출전하면 전원에게)
	var classes: Array = []
	for u: Variant in slots:
		var cc: Variant = by_uid.get(u) if u != null else null
		classes.append(cc["cls"] if cc != null else null)
	slots_box.add_child(_synergy_box(Synergy.compute(D, classes)))
	var count := PartyRules.count_filled(p)
	var ready := count >= int(D["MIN_P"])
	counter.text = "%d / 5" % count
	counter.add_theme_color_override("font_color", OKit.GREEN if ready else OKit.BLUE)
	counter_box.add_theme_stylebox_override("panel", OKit.box(Color(OKit.GREEN, 0.08) if ready else Color(OKit.BLUE, 0.08), Color(OKit.GREEN, 0.4) if ready else Color(OKit.BLUE, 0.3), 8, 1, 8, 6))
	var can := ready and PartyRules.can_start_flag(c)
	start_btn.disabled = not can
	start_btn.visible = can


func _slot_card(idx: int, ch: Variant) -> Button:
	var b: Button
	if ch == null:
		b = OKit.styled_button(OKit.box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.2), 8, 1, 10, 8), OKit.box(Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.08), Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.4), 8, 1, 10, 8), null, 8)
		b.text = "+"
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
		b.add_theme_color_override("font_hover_color", Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.6))
		b.add_theme_color_override("font_focus_color", Color(1, 1, 1, 0.5))
		b.custom_minimum_size = Vector2(0, 90)
		b.name = "Slot%d" % idx
		b.pressed.connect(func() -> void: open_unit_modal(idx))
		return b
	b = OKit.styled_button(OKit.box(Color(240 / 255.0, 170 / 255.0, 50 / 255.0, 0.09), Color(OKit.GOLD, 0.4), 8, 1, 10, 8), OKit.box(Color(240 / 255.0, 170 / 255.0, 50 / 255.0, 0.14), Color(OKit.GOLD, 0.7), 8, 1, 10, 8), null, 8)
	b.name = "Slot%d" % idx
	b.custom_minimum_size = Vector2(0, 90)
	var v := OKit.vbox(6)
	OKit.set_content(b, v, Vector4(10, 8, 10, 8))
	var h := OKit.hbox(8)
	v.add_child(h)
	var ib := PanelContainer.new()
	ib.add_theme_stylebox_override("panel", OKit.box(Color(0, 0, 0, 0.2), Color(0, 0, 0, 0), 4, 0, 0, 0))
	ib.custom_minimum_size = Vector2(40, 40)
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ib)
	ib.add_child(char_sprite(str(ch["cls"]), str(ch.get("gender", "m")), 36))
	var iv := OKit.vbox(2)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(iv)
	var lr := OKit.hbox(4)
	iv.add_child(lr)
	var lv := OKit.label(11, Color(1, 1, 1, 0.6), 600)
	lv.text = "Lv.%s" % num(ch.get("lv", 1))
	lr.add_child(lv)
	lr.add_child(_cls_label(str(ch["cls"])))
	for sk: Dictionary in PartyRules.learned_skills(c, ch):
		var si := OKit.tex_rect(icons.call("skill", sk["id"], sk["icon"]), Vector2(14, 14))
		si.tooltip_text = "Lv%s" % num(sk["lv"])
		si.mouse_filter = Control.MOUSE_FILTER_PASS
		lr.add_child(si)
	var nr := OKit.hbox(6)
	iv.add_child(nr)
	var nm := OKit.label(12, Color(1, 1, 1, 0.9), 700)
	nm.text = char_name(ch)
	nr.add_child(nm)
	var grade := Profile.pot_grade(c, ch)
	var gl := OKit.label(12, Color(str(D["GRADE_COLORS"].get(grade, "#9ca3af"))), 900)
	gl.text = grade
	nr.add_child(gl)
	var rm := OKit.styled_button(OKit.box(Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.15), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.3), 4, 1, 0, 0),
		OKit.box(Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.3), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.6), 4, 1, 0, 0), null, 4)
	rm.name = "Remove"
	rm.custom_minimum_size = Vector2(22, 22)
	rm.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var rx := OKit.vec_icon("close", 12, Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.85))
	rx.position = Vector2(5, 5)
	rm.add_child(rx)
	rm.tooltip_text = "✕"
	rm.pressed.connect(func() -> void: remove_from_slot(idx))
	h.add_child(rm)
	# 스탯 줄
	var bonus := Gear.calc_equip_bonus(c, ch)
	var sr := OKit.hbox(12)
	v.add_child(sr)
	for st: Array in [["HP", ch.get("hp"), bonus.get("hp", 0)], ["ATK", ch.get("atk"), bonus.get("atk", 0)], ["DEF", ch.get("def"), bonus.get("def", 0)]]:
		sr.add_child(_stat_text(str(st[0]), Js.num(st[1]), Js.num(st[2])))
	var ar := OKit.label(10, Color(1, 1, 1, 0.75), 700)
	ar.text = "AR %s" % _fixed2(_ar(ch))
	sr.add_child(ar)
	b.pressed.connect(func() -> void: open_unit_modal(idx))
	return b


func _stat_text(lbl: String, v: float, bonus: float) -> Control:
	var h := OKit.hbox(1)
	var l := OKit.label(10, Color(1, 1, 1, 0.75), 700)
	l.text = "%s %s" % [lbl, num(v)]
	h.add_child(l)
	if bonus > 0.0:
		var bl := OKit.label(10, Color("4ade80"), 700)
		bl.text = "+" + num(bonus)
		h.add_child(bl)
	return h


func _ar(ch: Dictionary) -> float:
	if Js.truthy(ch.get("actionRec")):
		return Js.num(ch["actionRec"])
	var jab: Dictionary = D["JAB"].get(ch["cls"], {})
	return float(jab["actionRec"]) if Js.truthy(jab.get("actionRec")) else 1.0


## JS toFixed(2) (정확한 10진 반올림)
func _fixed2(v: float) -> String:
	var f := Js.to_fixed_num(v, 2)
	var s := num(f)
	if not s.contains("."):
		s += ".00"
	elif s.length() - s.find(".") == 2:
		s += "0"
	return s


func _cls_label(cls: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", OKit.box(Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.12), Color(0, 0, 0, 0), 3, 0, 5, 1))
	var l := OKit.label(9, Color("60a5fa"), 700)
	l.text = t("classes." + cls)
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _synergy_box(syn: Array) -> Control:
	var p := PanelContainer.new()
	p.name = "Synergy"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", OKit.box(Color(167 / 255.0, 139 / 255.0, 250 / 255.0, 0.06), Color(167 / 255.0, 139 / 255.0, 250 / 255.0, 0.25), 8, 1, 10, 8))
	var v := OKit.vbox(4)
	p.add_child(v)
	var hh := OKit.hbox(6)
	v.add_child(hh)
	hh.add_child(OKit.tex_rect(emoji_tex("✨"), Vector2(13, 13)))
	var hl := OKit.label(12, Color("c4b5fd"), 800)
	hl.text = t("synergy.title")
	hh.add_child(hl)
	var help := OKit.label(10, OKit.DIM2, 500)
	help.text = t("synergy.help")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(help)
	if syn.is_empty():
		var none := OKit.label(11, OKit.DIM, 500)
		none.text = t("synergy.none")
		v.add_child(none)
	for s: Dictionary in syn:
		var row := OKit.hbox(6)
		var ic: Texture2D = emoji_tex(str(s.get("icon", "")))
		if ic != null:
			row.add_child(OKit.tex_rect(ic, Vector2(14, 14)))
		var nm := OKit.label(11, Color("fbbf24") if str(s["id"]).begins_with("mono_") else OKit.TEXT, 800)
		nm.text = icons.call("strip", info.call("synergy_name", s))
		row.add_child(nm)
		var ds := OKit.label(10, OKit.DIM2, 500)
		ds.text = info.call("synergy_describe", s)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(ds)
		v.add_child(row)
	return p


func remove_from_slot(idx: int) -> void:
	PartyRules.remove_from_slot(c, parties, current_pid, idx)
	render_slots()


## 출격 (웹 confirmP): 5명이면 game_nav 쓰고 전투로
func confirm_start() -> void:
	if start_btn.disabled or _started:
		return
	var nav: Variant = PartyRules.confirm_start(c, c_stage, practice)
	if nav == null or c_stage == null:
		return
	_started = true
	Flow.start_battle(router, store, c, nav)


# ═══════════ 유닛 고르기 창 ═══════════

var _unit_grid: GridContainer
var _filter_row: HBoxContainer


func open_unit_modal(idx: int) -> void:
	_modal_slot = idx
	_filter = "all"
	var v := OKit.vbox(10)
	v.name = "UnitSelect"
	_filter_row = OKit.hbox(6)
	_filter_row.name = "Filters"
	v.add_child(_filter_row)
	v.add_child(OKit.divider(0.08))
	_unit_grid = GridContainer.new()
	_unit_grid.name = "Cards"
	_unit_grid.columns = 3
	_unit_grid.add_theme_constant_override("h_separation", 12)
	_unit_grid.add_theme_constant_override("v_separation", 12)
	v.add_child(_unit_grid)
	var sb := OKit.box(Color("0d1322"), Color(1, 1, 1, 0.1), 16, 1, 20, 18)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 24
	unit_modal = open_modal(v, {"name": "UnitModal", "title": t("party.select_unit"), "title_size": 20, "width": 820.0, "box": sb, "close_x": true,
		"on_close": func() -> void: _modal_slot = -1})
	render_filters()
	render_unit_cards()


func render_filters() -> void:
	for ch: Node in _filter_row.get_children():
		_filter_row.remove_child(ch)
		ch.queue_free()
	var keys := ["all"]
	for g: String in PartyRules.groups_present(c):
		keys.append("group_" + g)
	for k: String in keys:
		var on := k == _filter
		var b := OKit.styled_button(OKit.box(Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.18) if on else Color(1, 1, 1, 0.04), Color("60a5fa") if on else Color(1, 1, 1, 0.12), 6, 1, 10, 5),
			OKit.box(Color(1, 1, 1, 0.08), Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.5), 6, 1, 10, 5), null, 6)
		b.name = "Filter_" + k
		set_button_text(b, t("common.all") if k == "all" else t("group." + k.trim_prefix("group_")), 14)
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", Color("bfdbfe") if on else OKit.DIM2)
		b.add_theme_color_override("font_hover_color", OKit.TEXT)
		b.add_theme_color_override("font_focus_color", OKit.TEXT)
		b.pressed.connect(func() -> void:
			_filter = k
			render_filters()
			render_unit_cards())
		_filter_row.add_child(b)


func render_unit_cards() -> void:
	for ch: Node in _unit_grid.get_children():
		_unit_grid.remove_child(ch)
		ch.queue_free()
	var list := PartyRules.unit_list(c, parties, current_pid, _filter)
	var p: Variant = PartyRules.find_party(parties, current_pid)
	var inp: Dictionary = {}
	for u: Variant in p["slots"]:
		if u != null:
			inp[u] = true
	_inv_map = _inventory_map()
	if list.is_empty():
		var e := OKit.label(13, OKit.DIM, 500)
		e.text = t("party.no_available_chars")
		_unit_grid.add_child(e)
	var first: Button = null
	for ch: Dictionary in list:
		var card := _unit_card(ch, inp.has(ch["uid"]))
		var uid: Variant = ch["uid"]
		card.pressed.connect(func() -> void: select_unit(uid))
		_unit_grid.add_child(card)
		if first == null:
			first = card
	if first != null:
		first.grab_focus.call_deferred()
	_fit_modal.call_deferred(unit_modal)


## 클랜원 카드 (유닛 고르기 창 · 장비 탭 같이 씀). slots: EquipRules.card_slots 결과를 주면 장비 탭 모양 (더 좋은 장비 ↑, 강화 단계 없음)
func _unit_card(ch: Dictionary, in_party: bool, slots: Array = []) -> Button:
	var nb := OKit.box(Color(240 / 255.0, 170 / 255.0, 50 / 255.0, 0.1) if in_party else Color(1, 1, 1, 0.025), Color(OKit.GOLD, 0.4) if in_party else Color(1, 1, 1, 0.08), 12, 2, 12, 12)
	var hb := OKit.box(Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.08), Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.4), 12, 2, 12, 12)
	if in_party:
		hb = OKit.box(Color(240 / 255.0, 170 / 255.0, 50 / 255.0, 0.16), Color(OKit.GOLD, 0.6), 12, 2, 12, 12)
	var b := OKit.styled_button(nb, hb, null, 12)
	b.name = "Unit_%s" % num(ch["uid"])
	b.custom_minimum_size = Vector2(242, 0)
	var v := OKit.vbox(8)
	OKit.set_content(b, v, Vector4(12, 12, 12, 12))
	# 머리: 그림(60) + 직업 아이콘 · 등급
	var h := OKit.hbox(8)
	v.add_child(h)
	var ib := PanelContainer.new()
	ib.add_theme_stylebox_override("panel", OKit.box(Color(0, 0, 0, 0.2), Color(0, 0, 0, 0), 10, 0, 0, 0))
	ib.custom_minimum_size = Vector2(60, 60)
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ib)
	var ic := Control.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ib.add_child(ic)
	var spr := char_sprite(str(ch["cls"]), str(ch.get("gender", "m")), 52)
	spr.position = Vector2(4, 0)
	spr.size = Vector2(52, 58)
	ic.add_child(spr)
	var ci := cls_icon(str(ch["cls"]), 22)
	ci.position = Vector2(2, 36)
	ci.size = Vector2(22, 22)
	ic.add_child(ci)
	h.add_child(OKit.spacer())
	var grade := Profile.pot_grade(c, ch)
	var gc := Color(str(D["GRADE_COLORS"].get(grade, "#9ca3af")))
	var gp := PanelContainer.new()
	gp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gp.add_theme_stylebox_override("panel", OKit.box(GRADE_BG.get(grade, Color(1, 1, 1, 0.1)), gc, 4, 1, 6, 1))
	gp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gp.name = "Grade"
	var gl := OKit.label(10, gc, 900)
	gl.text = grade
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gp.add_child(gl)
	h.add_child(gp)
	# Lv · 직업 · 이름
	var lr := OKit.hbox(4)
	v.add_child(lr)
	var lv := OKit.label(12, Color(1, 1, 1, 0.5), 600)
	lv.text = "Lv.%s" % num(ch.get("lv", 1))
	lr.add_child(lv)
	lr.add_child(_cls_label(str(ch["cls"])))
	var nm := OKit.label(14, Color(1, 1, 1, 0.9), 700)
	nm.text = char_name(ch)
	nm.custom_minimum_size = Vector2(218, 0)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	v.add_child(nm)
	# 스탯 (+장비 · (+잠재력))
	var bonus := Gear.calc_equip_bonus(c, ch)
	var pot: Dictionary = ch.get("pot", {}) if typeof(ch.get("pot")) == TYPE_DICTIONARY else {}
	for st: Array in [["HP", "hp"], ["ATK", "atk"], ["DEF", "def"]]:
		var k: String = st[1]
		v.add_child(_stat_row(str(st[0]) + ":", num(ch.get(k, 0)), Js.num(bonus.get(k, 0)), ("(+%s)" % num(pot[k])) if Js.truthy(pot.get(k)) else ""))
	v.add_child(_stat_row("AR:", _fixed2(_ar(ch)), 0.0, ("(+%s)" % _fixed2(float(pot["actionRec"]))) if Js.truthy(pot.get("actionRec")) else ""))
	# 장비 8칸 (웹 .unit-card-equips: 4열, 종류 아이콘 — 비었으면 흐리게, 등급 색, +강화)
	var ep := PanelContainer.new()
	ep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ep.add_theme_stylebox_override("panel", OKit.box(Color(0, 0, 0, 0.2), Color(0, 0, 0, 0), 8, 0, 8, 8))
	ep.name = "Equips"
	v.add_child(ep)
	var eg := GridContainer.new()
	eg.columns = 4
	eg.add_theme_constant_override("h_separation", 4)
	eg.add_theme_constant_override("v_separation", 4)
	ep.add_child(eg)
	var equip: Dictionary = ch.get("equip", {}) if typeof(ch.get("equip")) == TYPE_DICTIONARY else {}
	var marks: Dictionary = {}
	for sm: Dictionary in slots:
		marks[sm["slot"]] = sm
	for slot: String in D["EQUIP_SLOTS"]:
		var eid: Variant = equip.get(slot)
		var item: Variant = _inv_map.get(eid) if eid != null else null
		if marks.has(slot):
			item = marks[slot]["item"]
		var cell := PanelContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.tooltip_text = t("equip.slot." + slot)
		cell.custom_minimum_size = Vector2(46, 46)
		cell.name = "Eq_" + slot
		var rc := Color(1, 1, 1, 0.1)
		var rb := Color(1, 1, 1, 0.04)
		if item != null:
			var rcol := Color(str(D["RARITY"].get(str(item.get("rarity", "common")), {}).get("color", "#9ca3af")))
			rc = Color(rcol, 0.5)
			rb = Color(rcol, 0.1)
		cell.add_theme_stylebox_override("panel", OKit.box(rb, rc, 6, 1, 0, 0))
		var cc := Control.new()
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(cc)
		var et := OKit.tex_rect(emoji_tex(str(D["EQUIP_SLOT_ICONS"].get(slot, ""))), Vector2(18, 18))
		et.position = Vector2(14, 14)
		et.size = Vector2(18, 18)
		if item == null:
			et.modulate = Color(0.55, 0.55, 0.55, 0.38)
		cc.add_child(et)
		if item != null and slots.is_empty():
			var el := OKit.pill("+" + num(Js.num(item.get("enhanceLv"))), 8, OKit.GOLD, Color(0, 0, 0, 0.6))
			el.position = Vector2(20, 1)
			el.set_meta("overflow_ok", true)   # 웹 .unit-card-equip-lv: 칸 오른쪽 위 모서리에 겹친 배지
			cc.add_child(el)
		if marks.has(slot) and marks[slot]["upgrade"]:
			# 웹 .eq-char-slot.upgrade: 초록 바탕 + 오른쪽 위 ↑ (더 높은 등급의 안 낀 장비가 있음)
			cell.add_theme_stylebox_override("panel", OKit.box(Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.15), rc, 6, 1, 0, 0))
			var up := OKit.pill("↑", 8, Color.WHITE, Color("22c55e"))
			up.name = "Upgrade"
			up.position = Vector2(30, -3)
			up.set_meta("overflow_ok", true)
			cell.tooltip_text = t("equip.slot." + slot) + " · " + t("gd.equip.upgrade")
			cc.add_child(up)
		eg.add_child(cell)
	# 스킬
	var sks := PartyRules.learned_skills(c, ch)
	if not sks.is_empty():
		var sr := OKit.hbox(6)
		v.add_child(sr)
		for sk: Dictionary in sks:
			var sc := Control.new()
			sc.custom_minimum_size = Vector2(26, 22)
			sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var si := OKit.tex_rect(icons.call("skill", sk["id"], sk["icon"]), Vector2(20, 20))
			si.size = Vector2(20, 20)
			si.position = Vector2(0, 2)
			sc.add_child(si)
			var sl := OKit.pill(num(sk["lv"]), 8, Color.WHITE, Color("ef4444"))
			sl.position = Vector2(14, -2)
			sl.set_meta("overflow_ok", true)   # 웹 .unit-card-skill-lv: 아이콘 모서리에 겹친 배지
			sc.add_child(sl)
			sr.add_child(sc)
	return b


func _stat_row(lbl: String, val: String, bonus: float, potential: String) -> Control:
	var h := OKit.hbox(4)
	h.custom_minimum_size = Vector2(218, 0)
	var l := OKit.label(11, Color(1, 1, 1, 0.5), 500)
	l.text = lbl
	h.add_child(l)
	h.add_child(OKit.spacer())
	var vl := OKit.label(11, Color(1, 1, 1, 0.9), 700)
	vl.text = val
	h.add_child(vl)
	if bonus > 0.0:
		var bl := OKit.label(11, Color("4ade80"), 600)
		bl.text = "+" + num(bonus)
		h.add_child(bl)
	if potential != "":
		var pl := OKit.label(11, Color(1, 1, 1, 0.4), 500)
		pl.text = potential
		h.add_child(pl)
	return h


## 카드 고르기 → 그 칸에 (다른 칸에 있으면 옮김)
func select_unit(uid: Variant) -> void:
	if _modal_slot < 0 or not modal_open():
		return
	PartyRules.select_unit_for_slot(c, parties, current_pid, _modal_slot, uid)
	_modal_slot = -1
	close_all_modals()
	render_slots()
