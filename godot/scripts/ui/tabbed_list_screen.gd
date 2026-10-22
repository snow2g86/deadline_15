extends "res://scripts/ui/screen_base.gd"
## 탭 + 카드 목록 화면 공통 (4b-2: 성소 · 아카데미) — 웹 .page-hud(골드 배지) · .game-tab-wrap > .game-tabs · .page-info-row · .card-list
##  아래 화면은 tab_keys() · tab_label(k) · subtitle(k) · render_tab(k) 를 채운다. 카드 부품(game_card · empty_state · act_btn)은 여기.
##  다른 화면에서 {tab: "…"} 으로 탭을 정해 들어올 수 있음 (Router 의 한 번만 쓰는 값). 기록에는 지금 탭을 남김 (설정에서 돌아와도 같은 탭)

const LIST_W := 480.0
const PURPLE := Color("a855f7")
const BLUE2 := Color("3b82f6")
const GREEN2 := Color("16a34a")
const EquipGold := preload("res://scripts/logic/equip_rules.gd")

var cur_tab := ""
var gold_lbl: Label
var tab_btns: Dictionary = {}
var info_title: Label
var list: VBoxContainer
var list_scroll: ScrollContainer


func tab_keys() -> Array:
	return []


func tab_label(_k: String) -> String:
	return ""


func subtitle(_k: String) -> String:
	return ""


func render_tab(_k: String) -> void:
	pass


func history_state() -> Dictionary:
	return {"tab": cur_tab}


func _build() -> void:
	var keys := tab_keys()
	cur_tab = keys[0]
	var q: Variant = router.get("params").get("tab") if router != null else null
	if q != null and keys.has(str(q)):
		cur_tab = str(q)
	var col := OKit.vbox(0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(col)
	var hud := CenterContainer.new()
	hud.custom_minimum_size = Vector2(0, 60)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hud)
	var gb := gold_badge("0 G")
	hud.add_child(gb)
	gold_lbl = gb.find_child("Gold", true, false)
	var tw := OKit.MaxWidth.new()
	tw.max_w = LIST_W
	tw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tw)
	var tg := HBoxContainer.new()
	tg.name = "Tabs"
	tg.add_theme_constant_override("separation", 6)
	tw.add_child(tg)
	for k: String in keys:
		var b := OKit.styled_button(OKit.box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.08), 8, 1, 8, 10), OKit.box(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.15), 8, 1, 8, 10), null, 8)
		b.name = "Tab_" + k
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 13)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
		b.pressed.connect(switch_tab.bind(k))
		tg.add_child(b)
		tab_btns[k] = b
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)
	col.add_child(OKit.divider(0.06))
	var iw := OKit.MaxWidth.new()
	iw.max_w = LIST_W
	iw.custom_minimum_size = Vector2(0, 44)
	iw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(iw)
	info_title = OKit.label(16, OKit.TEXT, 900)
	info_title.name = "InfoTitle"
	info_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iw.add_child(info_title)
	list_scroll = ScrollContainer.new()
	list_scroll.name = "ListScroll"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.follow_focus = true
	col.add_child(list_scroll)
	var lw := OKit.MaxWidth.new()
	lw.max_w = LIST_W
	lw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_scroll.add_child(lw)
	list = OKit.vbox(10)
	list.name = "List"
	lw.add_child(list)


func _refresh() -> void:
	refresh_gold()
	for k: String in tab_keys():
		var b: Button = tab_btns[k]
		set_button_text(b, tab_label(k), 16)
		var on := k == cur_tab
		b.add_theme_stylebox_override("normal", OKit.box(Color(OKit.GOLD, 0.12) if on else Color(1, 1, 1, 0.04), OKit.GOLD if on else Color(1, 1, 1, 0.08), 8, 1, 8, 10))
		b.add_theme_color_override("font_color", Color.WHITE if on else OKit.DIM)
		b.add_theme_color_override("font_focus_color", Color.WHITE if on else OKit.TEXT)
		b.add_theme_color_override("font_hover_color", OKit.TEXT)
		b.tooltip_text = tab_label(k)
	render()


func refresh_gold() -> void:
	gold_lbl.text = "%s G" % grouped(EquipGold.load_gold(c))


func switch_tab(k: String) -> void:
	cur_tab = k
	_refresh()
	list_scroll.scroll_vertical = 0


## 지금 탭 다시 그리기 (사거나 바꾼 뒤)
func render() -> void:
	for ch: Node in list.get_children():
		list.remove_child(ch)
		ch.queue_free()
	info_title.text = subtitle(cur_tab)
	render_tab(cur_tab)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	list.add_child(sp)


func after_change() -> void:
	refresh_gold()
	render()


# ── 부품 ──

## 웹 .game-card / .promote-card: 왼쪽 그림 · 가운데 글 줄들 · 오른쪽 단추. 반환: [카드, 글 칸(VBox), 오른쪽 칸(HBox)]
func game_card(nm: String, border: Color = Color(1, 1, 1, 0.1), bg: Color = Color(1, 1, 1, 0.04)) -> Array:
	var p := PanelContainer.new()
	p.name = nm
	p.add_theme_stylebox_override("panel", OKit.box(bg, border, 10, 1, 16, 14))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := OKit.hbox(12)
	p.add_child(h)
	var info := OKit.vbox(3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := OKit.hbox(6)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(info)
	h.add_child(right)
	list.add_child(p)
	return [p, info, right, h]


## 클랜원 초상화 (웹 charPortrait — 소환수는 직업 아이콘)
func portrait(ch: Dictionary, sz: float) -> Control:
	var cls := str(ch.get("cls", ""))
	if cls.begins_with("summon_"):
		return cls_icon(cls, sz)
	var pt := Kit.Portrait.new()
	pt.custom_minimum_size = Vector2(sz, sz)
	pt.ring = Color(1, 1, 1, 0.15)
	pt.ring_w = 1.0
	pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pt.set_unit(icons.call("portrait_tex", cls, str(ch.get("gender", "m"))), false)
	return pt


## 글 줄 (줄바꿈 허용)
func line(text: String, size: int, col: Color, w: int = 600) -> Label:
	var l := OKit.label(size, col, w)
	l.text = icons.call("strip", text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(120, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## 이름 줄: 이름 · Lv.n · (등급) — RichText 한 줄
func name_line(name: String, lv: Variant, grade: String = "", grade_col: Color = Color.WHITE) -> RichTextLabel:
	var rl := RichTextLabel.new()
	rl.name = "NameLine"
	rl.bbcode_enabled = true
	rl.fit_content = true
	rl.scroll_active = false
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rl.custom_minimum_size = Vector2(120, 0)
	rl.add_theme_font_size_override("normal_font_size", 15)
	rl.add_theme_font_size_override("bold_font_size", 15)
	rl.add_theme_font_override("normal_font", Kit.bold(700))
	rl.add_theme_font_override("bold_font", Kit.bold(900))
	rl.add_theme_color_override("default_color", OKit.TEXT)
	var s := name.replace("[", "[lb]") + " [font_size=12][color=#64748b]Lv.%s[/color][/font_size]" % num(lv)
	if grade != "":
		s += " [font_size=13][b][color=#%s]%s[/color][/b][/font_size]" % [grade_col.to_html(false), grade]
	rl.text = s
	return rl


## 웹 .game-btn (보라·파랑·초록 그라디언트 대신 단색) — 못 누르면 흐리게 + 막음
func act_btn(text: String, col: Color, ok: bool, cb: Callable, nm: String = "Act") -> Button:
	var b := OKit.styled_button(OKit.box(col, Color(0, 0, 0, 0), 6, 0, 14, 7), OKit.box(col.lightened(0.12), Color(0, 0, 0, 0), 6, 0, 14, 7), null, 6)
	b.name = nm
	set_button_text(b, text, 14)
	b.add_theme_font_size_override("font_size", 13)
	for k: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.85))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not ok
	if not ok:
		b.modulate.a = 0.35
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## 웹 .empty-state (그림 + 글)
func empty_state(emoji: String, text: String) -> void:
	var v := OKit.vbox(8)
	v.name = "Empty"
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(0, 120)
	var tex := emoji_tex(emoji)
	if tex != null:
		var r := OKit.tex_rect(tex, Vector2(34, 34))
		r.modulate.a = 0.7
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(r)
	var l := OKit.label(14, OKit.DIM2, 600)
	l.text = icons.call("strip", text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(LIST_W - 40.0, 0)
	v.add_child(l)
	list.add_child(v)


## 능력치 줄 (웹 'HP · ATK · DEF · AR')
func stat_text(ch: Dictionary, ar: String) -> String:
	return "HP %s · ATK %s · DEF %s · AR %s" % [num(ch.get("hp", 0)), num(ch.get("atk", 0)), num(ch.get("def", 0)), ar]


## 잠재력 글 (웹 potStr: +hp/+atk/+def/+AR(소수 2자리), 없으면 −)
func pot_text(ch: Dictionary) -> String:
	var p: Variant = ch.get("pot")
	if not (p is Dictionary) or not Js.truthy(p.get("hp")):
		return "−"
	var s := "+%s/+%s/+%s" % [num(p["hp"]), num(p.get("atk", 0)), num(p.get("def", 0))]
	if Js.truthy(p.get("actionRec")):
		s += "/+" + EquipGold.fixed_str(Js.num(p["actionRec"]), 2)
	return s


func grade_color(g: String) -> Color:
	return Color(str((D["GRADE_COLORS"] as Dictionary).get(g, "#9ca3af")))


## 창 안 고르기 목록 단추 (웹 .pt-btn · .sac-btn · .scroll-select-btn · .sb-target-btn)
func pick_row(nm: String, icon: Control, title: String, sub: String, badge: String, cb: Callable, w: float = 400.0) -> Button:
	var b := OKit.styled_button(OKit.box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.1), 8, 1, 10, 8), OKit.box(Color(1, 1, 1, 0.08), OKit.GOLD, 8, 1, 10, 8), null, 8)
	b.name = nm
	b.custom_minimum_size = Vector2(w, 48)
	var h := OKit.hbox(10)
	OKit.set_content(b, h, Vector4(10, 7, 10, 7))
	if icon != null:
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(icon)
	var v := OKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var t1 := OKit.label(14, OKit.TEXT, 700)
	t1.text = icons.call("strip", title)
	t1.name = "Title"
	t1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t1.custom_minimum_size = Vector2(w - 140.0, 0)
	v.add_child(t1)
	if sub != "":
		var t2 := OKit.label(11, OKit.DIM2, 500)
		t2.text = icons.call("strip", sub)
		t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t2.custom_minimum_size = Vector2(w - 140.0, 0)
		v.add_child(t2)
	if badge != "":
		var bl := OKit.label(12, OKit.GOLD, 800)
		bl.text = badge
		bl.name = "Badge"
		bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bl)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b
