extends "res://scripts/ui/screen_base.gd"
## 도감·가이드 공통 틀 (4b-2) — 웹 css/codex.css: 머리 그림(.cx-hero: 문장 그림·제목·설명·숫자 칸) · 탭(.cx-tabs, 스크롤하면 위에 붙음) ·
##  본문(.cx-wrap 880px) · 아래 글(.cx-foot). 아래 탭 없음(웹 compendium·guide 페이지에 #bottom-nav 없음), 뒤로 = 이전 화면(웹 history.back()).
##  아래 화면은 emblem() · hero_title() · hero_sub() · hero_stats() · tabs() · tab_text(k) · panel(k) · foot() 를 채운다.
##  내용 블록은 scripts/logic/codex_rules.gd, 그리기는 scripts/ui/codex_view.gd

const CodexRules := preload("res://scripts/logic/codex_rules.gd")
const CodexView := preload("res://scripts/ui/codex_view.gd")
const WRAP_W := 880.0
const PAD := 16.0

var rules: Object
var view: Object
var cur_tab := ""
var page_scroll: ScrollContainer
var page: VBoxContainer
var hero: PanelContainer
var tab_bar: PanelContainer
var sticky_bar: PanelContainer
var panel_box: VBoxContainer
var foot_lbl: Label
var search: LineEdit
var _hero_title: Label
var _hero_sub: Label
var _hero_stats: HBoxContainer
var _emblem: Control


func emblem() -> String:
	return "📖"


func hero_title() -> String:
	return ""


func hero_sub() -> String:
	return ""


func hero_stats() -> Array:
	return []


func tabs() -> Array:
	return []


func tab_text(_k: String) -> String:
	return ""


func panel(_k: String) -> Array:
	return []


func foot() -> String:
	return ""


func has_search() -> bool:
	return false


func has_bottom_nav() -> bool:
	return false


func history_state() -> Dictionary:
	return {"tab": cur_tab}


func go_back() -> void:
	router.call("back")


func _make_rules() -> void:
	rules = CodexRules.new(c, func(k: String, p: Dictionary) -> String: return t(k, p), func(k: String) -> bool: return has_t(k))


func _build() -> void:
	_make_rules()
	view = CodexView.new(self)
	view.width = WRAP_W - PAD * 2.0
	view.on_link = _on_link
	var keys := tabs()
	cur_tab = keys[0]
	var q: Variant = router.get("params").get("tab") if router != null else null
	if q != null and keys.has(str(q)):
		cur_tab = str(q)
	page_scroll = ScrollContainer.new()
	page_scroll.name = "PageScroll"
	page_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.follow_focus = true
	body.add_child(page_scroll)
	page = OKit.vbox(0)
	page.name = "Page"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.add_child(page)
	_build_hero()
	tab_bar = _make_tab_bar("Tabs")
	page.add_child(tab_bar)
	var wrap := OKit.MaxWidth.new()
	wrap.max_w = WRAP_W
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(wrap)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(PAD))
	m.add_theme_constant_override("margin_right", int(PAD))
	m.add_theme_constant_override("margin_bottom", 72)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(m)
	var inner := OKit.vbox(6)
	inner.name = "Wrap"
	m.add_child(inner)
	if has_search():
		var sg := Control.new()
		sg.custom_minimum_size = Vector2(0, 8)
		sg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(sg)
		search = LineEdit.new()
		search.name = "Search"
		search.custom_minimum_size = Vector2(0, 44)
		search.add_theme_font_size_override("font_size", 15)
		search.add_theme_font_override("font", Kit.bold(500))
		var sn := OKit.box(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.08), 12, 1, 38, 10)
		var sf := OKit.box(Color(1, 1, 1, 0.06), Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.28), 12, 1, 38, 10)
		search.add_theme_stylebox_override("normal", sn)
		search.add_theme_stylebox_override("focus", sf)
		search.clear_button_enabled = true
		var mg := OKit.vec_icon("search", 18, OKit.DIM)
		mg.position = Vector2(12, 13)
		search.add_child(mg)
		search.text_changed.connect(func(_s: String) -> void: apply_search())
		inner.add_child(search)
	panel_box = OKit.vbox(0)
	panel_box.name = "Panel"
	inner.add_child(panel_box)
	foot_lbl = OKit.label(12, OKit.DIM, 500)
	foot_lbl.name = "Foot"
	foot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot_lbl.custom_minimum_size = Vector2(0, 50)
	foot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	inner.add_child(foot_lbl)
	# 스크롤하면 위에 붙는 탭 (웹 position: sticky)
	sticky_bar = _make_tab_bar("StickyTabs")
	sticky_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sticky_bar.visible = false
	body.add_child(sticky_bar)
	page_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _update_sticky())


func _build_hero() -> void:
	hero = PanelContainer.new()
	hero.name = "Hero"
	var sb := OKit.box(Color("121a30"), Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.28), 0, 0, 16, 26)
	sb.border_width_bottom = 1
	sb.content_margin_top = 30
	sb.content_margin_bottom = 24
	hero.add_theme_stylebox_override("panel", sb)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.clip_contents = true
	page.add_child(hero)
	var bgc := Control.new()
	bgc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(bgc)
	var g := OKit.gradient_rect([Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.16), Color(0, 0, 0, 0)], [0.0, 0.6], true, Vector2(0.5, 0.0), Vector2(1.1, 0.9))
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bgc.add_child(g)
	var v := OKit.vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(v)
	var ec := CenterContainer.new()
	ec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ec)
	var em := PanelContainer.new()
	em.name = "Emblem"
	var esb := OKit.box(Color("221c0e"), Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.28), 18, 1, 0, 0)
	esb.shadow_color = Color(0, 0, 0, 0.45)
	esb.shadow_size = 14
	em.add_theme_stylebox_override("panel", esb)
	em.custom_minimum_size = Vector2(64, 64)
	em.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ecc := CenterContainer.new()
	ecc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	em.add_child(ecc)
	ecc.add_child(OKit.tex_rect(emoji_tex(emblem()), Vector2(36, 36)))
	ec.add_child(em)
	_emblem = em
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	_hero_title = OKit.label(30, CodexView.GOLD2, 900)
	_hero_title.name = "HeroTitle"
	_hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_hero_title)
	_hero_sub = OKit.label(13, CodexView.TEXT2, 500)
	_hero_sub.name = "HeroSub"
	_hero_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_hero_sub)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 10)
	gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap2)
	_hero_stats = OKit.hbox(8)
	_hero_stats.name = "HeroStats"
	_hero_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_hero_stats)


func _make_tab_bar(nm: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = nm
	var sb := OKit.box(Color(10 / 255.0, 14 / 255.0, 26 / 255.0, 0.95), Color(1, 1, 1, 0.08), 0, 0, 16, 10)
	sb.border_width_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HFlowContainer.new()
	row.name = "Row"
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	p.add_child(row)
	return p


func _fill_tab_bar(p: PanelContainer) -> void:
	var row: Node = p.get_node("Row")
	for ch: Node in row.get_children():
		row.remove_child(ch)
		ch.queue_free()
	for k: String in tabs():
		var b: Button = view.tab_button(tab_text(k), k == cur_tab)
		b.name = "Tab_" + k
		b.pressed.connect(switch_tab.bind(k))
		row.add_child(b)


func _update_sticky() -> void:
	if hero == null:
		return
	sticky_bar.visible = page_scroll.scroll_vertical >= int(hero.size.y)


func _refresh() -> void:
	title_lbl.text = title_text()
	_hero_title.text = icons.call("strip", hero_title())
	_hero_sub.text = icons.call("strip", hero_sub())
	for ch: Node in _hero_stats.get_children():
		ch.queue_free()
	for st: Array in hero_stats():
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", OKit.box(Color(0, 0, 0, 0.28), Color(1, 1, 1, 0.08), 10, 1, 10, 7))
		p.custom_minimum_size = Vector2(80, 0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := OKit.vbox(0)
		p.add_child(v)
		var b := OKit.label(17, OKit.TEXT, 900)
		b.text = str(st[0])
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(b)
		var l := OKit.label(11, CodexView.TEXT2, 600)
		l.text = str(st[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		_hero_stats.add_child(p)
	if search != null:
		search.placeholder_text = search_hint()
	foot_lbl.text = foot()
	_fill_tab_bar(tab_bar)
	_fill_tab_bar(sticky_bar)
	for k: String in _panels.keys():
		drop_panel(k)
	render_panel()


func search_hint() -> String:
	return ""


## 탭마다 한 번 만들어 두고 보이기만 바꿈 (스테이지 100개 등 만들기가 무거움). 언어가 바뀌거나 장비 거르기가 바뀌면 다시 만듦
var _panels: Dictionary = {}


func drop_panel(k: String) -> void:
	if _panels.has(k):
		var n: Node = _panels[k]
		_panels.erase(k)
		if is_instance_valid(n):
			panel_box.remove_child(n)
			n.queue_free()


func render_panel() -> void:
	for k: String in _panels.keys():
		(_panels[k] as Control).visible = k == cur_tab
	if not _panels.has(cur_tab):
		var built: Control = view.build(panel(cur_tab))
		built.name = "Panel_" + cur_tab
		panel_box.add_child(built)
		_panels[cur_tab] = built
	apply_search()


## 지금 보이는 탭의 블록
func current_panel() -> Control:
	return _panels.get(cur_tab)


func switch_tab(k: String) -> void:
	if k == cur_tab:
		page_scroll.scroll_vertical = int(hero.size.y)
		return
	cur_tab = k
	_fill_tab_bar(tab_bar)
	_fill_tab_bar(sticky_bar)
	render_panel()
	# 웹: 탭을 누르면 머리 그림 아래(탭이 위에 붙는 곳)로
	_scroll_to_tabs.call_deferred()
	var b: Node = sticky_bar.get_node("Row").get_node_or_null("Tab_" + k) if sticky_bar.visible else tab_bar.get_node("Row").get_node_or_null("Tab_" + k)
	if b != null:
		(b as Control).grab_focus.call_deferred()


func _scroll_to_tabs() -> void:
	page_scroll.scroll_vertical = int(hero.size.y)


## 검색 (웹 applySearch): q 가 들어 있는 블록만, 맞는 것이 있는 접는 칸은 폄
func apply_search() -> void:
	if search == null:
		return
	var q := search.text.strip_edges().to_lower()
	var cp := current_panel()
	if cp == null:
		return
	var stack: Array = [cp]
	var accs: Array = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_meta("q") and n is Control:
			(n as Control).visible = q == "" or str(n.get_meta("q")).contains(q)
		if n.has_meta("acc"):
			accs.append(n)
		stack.append_array(n.get_children())
	if q != "":
		for a: Control in accs:
			var any := false
			var st2: Array = [a]
			while not st2.is_empty():
				var m: Node = st2.pop_back()
				if m != a and m.has_meta("q") and (m as Control).visible:
					any = true
					break
				st2.append_array(m.get_children())
			view.set_open(a, any)


func _on_link(meta: String) -> void:
	if meta.begins_with("compendium:"):
		var tab := meta.trim_prefix("compendium:")
		router.call("go", "compendium", {"tab": tab} if tab != "" else {})
