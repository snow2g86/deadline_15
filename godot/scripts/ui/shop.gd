extends "res://scripts/ui/screen_base.gd"
## 상점 — 웹 shop.html + js/shop.js + css/shop.css (4b-1)
##  골드 배지, 탭 6개(용병 · 소모품 · 장비 · 스킬 · 전직서 · 골드), 탭 제목 + 갱신 타이머(소모품·골드 탭은 숨김), 카드 목록(2열)
##   용병: 광고 카드(추후 개발) + 용병 6 (등급·그림·이름·직업·스탯(+잠재력)·모집)
##   소모품: 광고 + 룬 뽑기 + 경험치 물약 3 · 전투 물약 6 · 공성 아이템 3 (사도 사라지지 않음)
##   장비: 광고 + 천장 막대 + 확률표 + 1회 · 10+1회 뽑기 + 강화 재료(강화석 · 보호 주문서) + 전설 교환
##   스킬: 광고 + 영혼석 3 · 스킬북 6,  전직서: 광고 + 전직서 6,  골드: 광고 + 결제 꾸러미 4 (웹도 '추후 오픈 예정')
##  규칙은 scripts/logic/shop_rules.gd (웹과 같은 난수 순서·저장 형식). 사기는 웹과 같이 확인 창(용병·룬·뽑기·재료는 바로).
##  자원이 오가는 단추는 같은 프레임 연타를 막음 (act_once). 다른 화면에서 {tab: "scroll"} 처럼 탭을 정해 들어올 수 있음 (웹 shop.html?tab=)

const ShopRules := preload("res://scripts/logic/shop_rules.gd")
const EquipRules := preload("res://scripts/logic/equip_rules.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const ItemView := preload("res://scripts/ui/item_view.gd")

const LIST_W := 600.0
const HALF_W := 295.0
const TAB_KEYS := ["mercenary", "consumable", "equip", "skill", "scroll", "gold"]
const GREEN := Color("22c55e")
const PURPLE := Color("8b5cf6")

var data: Dictionary = {}
var cur_tab := "mercenary"
var gold_lbl: Label
var tab_btns: Dictionary = {}
var info_title: Label
var timer_lbl: Label
var list: VBoxContainer
var list_scroll: ScrollContainer
var _grid: GridContainer
var _tick := 0.0
var names: Array = []


func page_id() -> String:
	return "shop"


func title_text() -> String:
	return t("shop.title")


## 기록에 남길 상태: 지금 탭 (설정 화면에서 돌아와도 같은 탭)
func history_state() -> Dictionary:
	return {"tab": cur_tab}


func _build() -> void:
	var nm: Variant = i18n.call("t_raw", "character.names") if i18n != null else null
	names = nm if nm is Array else []
	data = ShopRules.load_shop(c, names)
	var q: Variant = router.get("params").get("tab") if router != null else null
	if q != null and TAB_KEYS.has(str(q)):
		cur_tab = str(q)
	var col := OKit.vbox(0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(col)
	var hud := CenterContainer.new()
	hud.custom_minimum_size = Vector2(0, 64)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hud)
	var gb := gold_badge("0 G")
	hud.add_child(gb)
	gold_lbl = gb.find_child("Gold", true, false)
	var tw := OKit.MaxWidth.new()
	tw.max_w = LIST_W
	tw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tw)
	var tg := GridContainer.new()
	tg.name = "Tabs"
	tg.columns = 3
	tg.add_theme_constant_override("h_separation", 6)
	tg.add_theme_constant_override("v_separation", 6)
	tw.add_child(tg)
	for k: String in TAB_KEYS:
		var b := OKit.styled_button(OKit.box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.08), 8, 1, 8, 9), OKit.box(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.15), 8, 1, 8, 9), null, 8)
		b.name = "Tab_" + k
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 13)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(switch_tab.bind(k))
		tg.add_child(b)
		tab_btns[k] = b
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)
	col.add_child(OKit.divider(0.06))
	var iw := OKit.MaxWidth.new()
	iw.max_w = LIST_W
	iw.custom_minimum_size = Vector2(0, 40)
	iw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(iw)
	var ir := OKit.hbox(8)
	ir.name = "InfoRow"
	iw.add_child(ir)
	info_title = OKit.label(15, OKit.TEXT, 800)
	info_title.name = "InfoTitle"
	info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ir.add_child(info_title)
	timer_lbl = OKit.label(12, Color("60a5fa"), 700)
	timer_lbl.name = "Timer"
	timer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ir.add_child(timer_lbl)
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
	for k: String in TAB_KEYS:
		var b: Button = tab_btns[k]
		b.text = t("shop.tab_" + k)
		var on := k == cur_tab
		b.add_theme_stylebox_override("normal", OKit.box(Color(OKit.GOLD, 0.12) if on else Color(1, 1, 1, 0.04), OKit.GOLD if on else Color(1, 1, 1, 0.08), 8, 1, 8, 9))
		b.add_theme_color_override("font_color", Color.WHITE if on else OKit.DIM)
		b.add_theme_color_override("font_focus_color", Color.WHITE if on else OKit.TEXT)
		b.add_theme_color_override("font_hover_color", OKit.TEXT)
	render()


func refresh_gold() -> void:
	gold_lbl.text = "%s G" % grouped(ShopRules.gold(c))


func switch_tab(k: String) -> void:
	cur_tab = k
	_refresh()
	list_scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		_update_timer()


func _update_timer() -> void:
	var tw := func(k: String, p: Dictionary) -> String: return t(k, p)
	timer_lbl.text = ShopRules.timer_text(c, data, cur_tab, tw)
	timer_lbl.visible = timer_lbl.text != ""


# ═══════════ 그리기 ═══════════

func render() -> void:
	for ch: Node in list.get_children():
		list.remove_child(ch)
		ch.queue_free()
	_grid = null
	info_title.text = t("shop.subtitle_" + cur_tab)
	_update_timer()
	var gold := ShopRules.gold(c)
	match cur_tab:
		"equip":
			_render_gacha(gold)
			return
		"gold":
			_full(_ad_card("shop.gold_ad_title", "shop.gold_ad_desc"))
			var gg := GridContainer.new()
			gg.name = "IapGrid"
			gg.columns = 2
			gg.add_theme_constant_override("h_separation", 10)
			gg.add_theme_constant_override("v_separation", 10)
			for pk: Dictionary in ShopRules.GOLD_PACKAGES:
				gg.add_child(_iap_card(pk))
			list.add_child(gg)
			return
	var ad_key := {"mercenary": "shop.ad_merc_desc", "consumable": "shop.ad_item_desc", "skill": "shop.ad_skill_desc", "scroll": "shop.ad_scroll_desc"}
	_full(_ad_card(ad_key[cur_tab]))
	if cur_tab == "consumable":
		_half(_rune_card(gold))
	for idx: int in ShopRules.tab_items(data, cur_tab):
		var it: Dictionary = data["items"][idx]
		var card: Control = null
		match str(it["type"]) if Js.truthy(it.get("type")) else "char":
			"char":
				card = _char_card(idx, it, gold)
			"potion", "battle_potion", "siege":
				card = _consumable_card(idx, it, gold)
			"skillbook":
				card = _skillbook_card(idx, it, gold)
			"soulstone":
				card = _soul_card(idx, it, gold)
			"scroll":
				card = _scroll_card(idx, it, gold)
		if card != null:
			_half(card)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	list.add_child(sp)


func _full(ctl: Control) -> void:
	_grid = null
	list.add_child(ctl)


func _half(ctl: Control) -> void:
	if _grid == null:
		_grid = GridContainer.new()
		_grid.columns = 2
		_grid.add_theme_constant_override("h_separation", 10)
		_grid.add_theme_constant_override("v_separation", 10)
		list.add_child(_grid)
	_grid.add_child(ctl)


func _card(w: float, border: Color = Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.15)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", OKit.box(Color(1, 1, 1, 0.04), border, 12, 2, 12, 12))
	p.custom_minimum_size = Vector2(w, 0)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


func _center_label(text: String, size: int, col: Color, w: int, width: float) -> Label:
	var l := OKit.label(size, col, w)
	l.text = icons.call("strip", text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


## 사기 단추 (웹 .shop-btn: 초록 · potion-btn 보라 · sold 회색) — 못 사면 흐리게 + 막음
func _buy_btn(text: String, ok: bool, sold: bool, col: Color, cb: Callable, nm: String) -> Button:
	var bg := Color("475569") if sold else col
	var b := OKit.styled_button(OKit.box(bg, Color(0, 0, 0, 0), 6, 0, 14, 6), OKit.box(bg.lightened(0.12), Color(0, 0, 0, 0), 6, 0, 14, 6), null, 6)
	b.name = nm
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	for k: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.8))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.disabled = not ok or sold
	if b.disabled and not sold:
		b.modulate.a = 0.35
	b.pressed.connect(cb)
	return b


func _icon_box(ctl: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(ctl)
	return cc


func _ad_card(key: String, key2: String = "") -> Control:
	var p := _card(LIST_W, Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.25))
	p.name = "AdCard"
	var h := OKit.hbox(12)
	p.add_child(h)
	var ad_tex := emoji_tex("🎬")
	if ad_tex != null:
		h.add_child(OKit.tex_rect(ad_tex, Vector2(28, 28)))
	var l := OKit.label(12, OKit.TEXT, 900)
	l.text = t(key) + ((" " + t(key2)) if key2 != "" else "")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(360, 0)
	h.add_child(l)
	var b := OKit.ghost_button(t("common.coming_soon"), 11)
	b.name = "AdBtn"
	b.disabled = true
	b.modulate.a = 0.5
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return p


func _grade_color(g: String) -> Color:
	return Color(str(D["GRADE_COLORS"].get(g, "#9ca3af")))


func _char_card(idx: int, it: Dictionary, gold: float) -> Control:
	var sold := Js.truthy(it.get("sold"))
	var p := _card(HALF_W)
	p.name = "Item%d" % idx
	if sold:
		p.modulate.a = 0.4
	var cls := str(it["cls"])
	var jab: Dictionary = D["JAB"][cls]
	var ga := ShopRules.grade_of(c, cls, it["pot"])
	var v := OKit.vbox(5)
	p.add_child(v)
	var top := OKit.hbox(0)
	top.add_child(OKit.spacer())
	var gl := OKit.label(13, _grade_color(ga[0]), 900)
	gl.text = ga[0]
	top.add_child(gl)
	v.add_child(top)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(60, 64)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spr := char_sprite(cls, str(it.get("gender", "m")), 52)
	spr.position = Vector2(4, 0)
	spr.size = Vector2(52, 58)
	pic.add_child(spr)
	var ci := cls_icon(cls, 20)
	ci.position = Vector2(40, 40)
	ci.size = Vector2(20, 20)
	pic.add_child(ci)
	v.add_child(_icon_box(pic))
	v.add_child(_center_label(str(it.get("name", "")) if it.get("name") != null else "", 15, Color.WHITE, 800, HALF_W - 28))
	v.add_child(_center_label("%s · %s" % [t("classes." + cls), t("class_desc." + cls)], 10, OKit.DIM2, 500, HALF_W - 28))
	var sg := GridContainer.new()
	sg.columns = 2
	sg.add_theme_constant_override("h_separation", 14)
	var pot: Dictionary = it["pot"]
	for row: Array in [["HP : ", jab["base"]["hp"], pot.get("hp")], ["ATK:", jab["base"]["atk"], pot.get("atk")], ["DEF:", jab["base"]["def"], pot.get("def")], ["AR:", jab["actionRec"], pot.get("actionRec")]]:
		var h := OKit.hbox(2)
		var a := OKit.label(11, Color.WHITE, 700)
		a.text = "%s%s" % [row[0], num(row[1])]
		h.add_child(a)
		var b2 := OKit.label(11, OKit.DIM, 600)
		b2.text = "(+%s)" % num(row[2])
		h.add_child(b2)
		sg.add_child(h)
	v.add_child(_icon_box(sg))
	var cost := Js.num(it.get("cost"))
	v.add_child(_icon_box(_buy_btn(t("shop.recruit_complete") if sold else t("shop.recruit", {"gold": num(cost)}), gold >= cost, sold, GREEN, buy_item.bind(idx), "Buy")))
	return p


func _consumable_card(idx: int, it: Dictionary, gold: float) -> Control:
	var ty := str(it["type"])
	var p := _card(HALF_W)
	p.name = "Item%d" % idx
	var v := OKit.vbox(6)
	p.add_child(v)
	var key := str(it.get("potionId", it.get("siegeId", "")))
	var name := ""
	var sub := ""
	match ty:
		"potion":
			name = t(str(it["i18nNameKey"])) if Js.truthy(it.get("i18nNameKey")) else str(it.get("name", ""))
			sub = "%s +%s" % [t("common.exp"), num(it.get("exp"))] if Js.truthy(it.get("exp")) else ""
		"battle_potion":
			name = t("battle_potions." + key)
			sub = t("battle_potions." + key + "_desc")
		"siege":
			name = t("shop." + key)
			sub = t("shop." + key + "_desc")
	v.add_child(_icon_box(ItemView.icon(icons, key, 44, str(it.get("icon", "")))))
	v.add_child(_center_label(name, 14, Color.WHITE, 800, HALF_W - 28))
	if sub != "":
		v.add_child(_center_label(sub, 10, OKit.DIM2, 500, HALF_W - 28))
	var cost := Js.num(it.get("cost"))
	v.add_child(_icon_box(_buy_btn(t("shop.buy", {"gold": num(cost)}), gold >= cost, false, PURPLE, buy_item.bind(idx), "Buy")))
	return p


func _skillbook_card(idx: int, it: Dictionary, gold: float) -> Control:
	var sold := Js.truthy(it.get("sold"))
	var sid := str(it["skillId"])
	var sk: Variant = (D["LEARNABLE_SKILLS"] as Dictionary).get(sid)
	if sk == null:
		return null
	var p := _card(HALF_W)
	p.name = "Item%d" % idx
	if sold:
		p.modulate.a = 0.4
	var v := OKit.vbox(6)
	p.add_child(v)
	v.add_child(_icon_box(OKit.tex_rect(icons.call("skill", sid, str(sk.get("icon", ""))), Vector2(36, 36))))
	var nr := OKit.hbox(6)
	nr.alignment = BoxContainer.ALIGNMENT_CENTER
	var nl := OKit.label(14, Color.WHITE, 800)
	nl.text = t("skills." + sid)
	nr.add_child(nl)
	nr.add_child(_cls_pill(str(it["cls"])))
	v.add_child(nr)
	# 웹은 스킬 데이터의 desc(한국어만)를 보임 — Godot 은 번역 키(skills_desc)가 있으면 그것 (6개 언어)
	var dk := "skills_desc." + sid
	v.add_child(_center_label(t(dk) if has_t(dk) else str(sk.get("desc", "")), 10, OKit.DIM2, 500, HALF_W - 28))
	var cost := Js.num(it.get("cost"))
	v.add_child(_icon_box(_buy_btn(t("shop.buy_complete") if sold else t("shop.buy", {"gold": num(cost)}), gold >= cost, sold, GREEN, buy_item.bind(idx), "Buy")))
	return p


func _cls_pill(cls: String) -> PanelContainer:
	var pp := PanelContainer.new()
	pp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pp.add_theme_stylebox_override("panel", OKit.box(Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.12), Color(0, 0, 0, 0), 3, 0, 5, 1))
	var l := OKit.label(9, Color("60a5fa"), 700)
	l.text = t("classes." + cls)
	pp.add_child(l)
	pp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pp


func _soul_card(idx: int, it: Dictionary, gold: float) -> Control:
	var sold := Js.truthy(it.get("sold"))
	var cls := str(it["cls"])
	var p := _card(HALF_W)
	p.name = "Item%d" % idx
	if sold:
		p.modulate.a = 0.4
	var v := OKit.vbox(6)
	p.add_child(v)
	var ic := OKit.hbox(2)
	ic.add_child(ItemView.icon(icons, "soul_stone", 36, "💠"))
	ic.add_child(cls_icon(cls, 18))
	v.add_child(_icon_box(ic))
	v.add_child(_center_label(t("soul.stone_name", {"cls": t("classes." + cls)}), 14, Color.WHITE, 800, HALF_W - 28))
	var have := 0.0
	var sd: Variant = c.store.get_json(Profile.SOUL_KEY)
	if sd is Dictionary and sd.get("stones") is Dictionary and sd.get("frags") is Dictionary:
		have = Js.num(sd["stones"].get(cls))
	v.add_child(_center_label(t("soul.shop_desc", {"have": num(have)}), 10, OKit.DIM2, 500, HALF_W - 28))
	var cost := Js.num(it.get("cost"))
	v.add_child(_icon_box(_buy_btn(t("shop.buy_complete") if sold else t("shop.buy", {"gold": num(cost)}), gold >= cost, sold, GREEN, buy_item.bind(idx), "Buy")))
	return p


func _scroll_card(idx: int, it: Dictionary, gold: float) -> Control:
	var cls := str(it["scrollCls"])
	if not (D["JAB"] as Dictionary).has(cls):
		return null
	var sold := Js.truthy(it.get("sold"))
	var p := _card(HALF_W, Color(192 / 255.0, 132 / 255.0, 252 / 255.0, 0.2))
	p.name = "Item%d" % idx
	if sold:
		p.modulate.a = 0.4
	var v := OKit.vbox(6)
	p.add_child(v)
	v.add_child(_icon_box(cls_icon(cls, 36)))
	v.add_child(_center_label(_scroll_name(cls), 14, Color.WHITE, 800, HALF_W - 28))
	v.add_child(_center_label(t("class_desc." + cls), 10, OKit.DIM2, 500, HALF_W - 28))
	var cost := Js.num(it.get("cost"))
	v.add_child(_icon_box(_buy_btn(t("shop.buy_complete") if sold else t("shop.buy", {"gold": num(cost)}), gold >= cost, sold, Color("9333ea"), buy_item.bind(idx), "Buy")))
	return p


func _scroll_name(cls: String) -> String:
	return t("shop.scroll_prefix") + " " + t("classes." + cls)


func _rune_card(gold: float) -> Control:
	var p := _card(HALF_W, Color(167 / 255.0, 139 / 255.0, 250 / 255.0, 0.25))
	p.name = "RuneCard"
	var v := OKit.vbox(6)
	p.add_child(v)
	v.add_child(_icon_box(OKit.tex_rect(emoji_tex("🔮"), Vector2(40, 40))))
	v.add_child(_center_label(t("enchant.rune_gacha"), 14, Color.WHITE, 800, HALF_W - 28))
	v.add_child(_center_label(t("enchant.rune_gacha_desc"), 10, OKit.DIM2, 500, HALF_W - 28))
	# 가진 룬 수 (웹은 세로로 흩어져 보임 — 같은 정보를 그림 + 수로 줄 맞춤)
	var rg := GridContainer.new()
	rg.name = "Runes"
	rg.columns = 6
	rg.add_theme_constant_override("h_separation", 6)
	rg.add_theme_constant_override("v_separation", 2)
	for k: String in (D["ENCHANTS"] as Dictionary).keys():
		var h := OKit.hbox(1)
		h.add_child(ItemView.icon(icons, "rune_" + k, 16, str(D["ENCHANTS"][k].get("icon", ""))))
		var l := OKit.label(10, OKit.DIM2, 700)
		l.text = str(ShopRules.rune_count(c, k))
		h.add_child(l)
		h.tooltip_text = t("enchant.rune_name", {"e": t("enchant." + k)})
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		rg.add_child(h)
	v.add_child(_icon_box(rg))
	var cost := float(D["RUNE_GACHA_COST"])
	v.add_child(_icon_box(_buy_btn(t("shop.buy", {"gold": num(cost)}), gold >= cost, false, GREEN, buy_rune, "Buy")))
	return p


func _iap_card(pk: Dictionary) -> Control:
	var p := _card(HALF_W, Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.2))
	p.modulate.a = 0.6
	var v := OKit.vbox(4)
	p.add_child(v)
	var amt := float(pk["gold"])
	var e := "💰" if amt >= 6500.0 else ("🏆" if amt >= 3000.0 else ("💎" if amt >= 1200.0 else "🪙"))
	v.add_child(_icon_box(OKit.tex_rect(emoji_tex(e), Vector2(36, 36))))
	v.add_child(_center_label(t("shop." + str(pk["key"])), 14, OKit.GOLD, 900, HALF_W - 28))
	v.add_child(_center_label(str(pk["price"]), 12, OKit.TEXT, 700, HALF_W - 28))
	v.add_child(_center_label(t("shop.gold_iap_coming"), 10, OKit.DIM, 600, HALF_W - 28))
	return p


# ── 장비 탭 (뽑기) ──

func _render_gacha(gold: float) -> void:
	_full(_ad_card("shop.ad_equip_desc"))
	var pity := Profile.load_pity(c)
	var pmax := int(D["GACHA_PITY_MAX"])
	var pp := _card(LIST_W, Color(OKit.GOLD, 0.2))
	pp.name = "Pity"
	var pv := OKit.vbox(6)
	pp.add_child(pv)
	pv.add_child(_center_label(t("shop.gacha_pity", {"current": pity, "max": pmax}), 11, OKit.GOLD, 700, LIST_W - 28))
	var bar := Kit.Bar.new()
	bar.custom_minimum_size = Vector2(LIST_W - 28, 8)
	bar.track = Color(1, 1, 1, 0.08)
	bar.set_value(Js.round_js(float(pity) / float(pmax) * 100.0) / 100.0, OKit.GOLD, Color("ef4444"))
	pv.add_child(bar)
	_full(pp)
	var rp := _card(LIST_W, Color(1, 1, 1, 0.08))
	rp.name = "Rates"
	var rh := OKit.hbox(10)
	rh.alignment = BoxContainer.ALIGNMENT_CENTER
	rp.add_child(rh)
	for r: Array in ShopRules.gacha_rates(c):
		var l := OKit.label(11, ItemView.rarity_color(D, r[0]), 700)
		l.text = "%s %s%%" % [t("equip.rarity." + str(r[0])), r[1]]
		rh.add_child(l)
	_full(rp)
	_half(_gacha_card("🎲", "shop.gacha_single", "shop.gacha_single_desc", t("shop.gacha_pull_1", {"gold": num(D["GACHA_COST_1"])}), gold >= float(D["GACHA_COST_1"]), GREEN, do_gacha.bind(1), "Gacha1"))
	_half(_gacha_card("🎱", "shop.gacha_multi", "shop.gacha_multi_desc", t("shop.gacha_pull_10", {"gold": num(D["GACHA_COST_10"])}), gold >= float(D["GACHA_COST_10"]), PURPLE, do_gacha.bind(10), "Gacha10"))
	var mp := _card(LIST_W, Color(OKit.GOLD, 0.2))
	mp.name = "Mats"
	mp.add_child(_center_label("🔩 " + t("gear.shop_title") + " — " + t("gear.mats", {"stone": num(EquipRules.mats_get(c, "stone")), "protect": num(EquipRules.mats_get(c, "protect")), "shard": num(EquipRules.mats_get(c, "shard"))}), 11, OKit.GOLD, 700, LIST_W - 28))
	_full(mp)
	for m: Array in [["stone", "🔩", "gear.shop_stone_desc"], ["protect", "📜", "gear.shop_protect_desc"]]:
		var price := float(D["MATS_PRICE"][m[0]])
		var gc := _gacha_card("", "gear." + str(m[0]), str(m[2]), t("shop.buy", {"gold": num(price)}), gold >= price, GREEN, buy_mat.bind(str(m[0])), "Mat_" + str(m[0]))
		var iv: Control = gc.find_child("Icon", true, false)
		if iv != null:
			iv.add_child(ItemView.icon(icons, "mat_" + str(m[0]), 48, str(m[1])))
		_half(gc)
	# 전설 교환
	var ex := _card(LIST_W, Color(OKit.GOLD, 0.3))
	ex.name = "Exchange"
	var ev := OKit.vbox(8)
	ex.add_child(ev)
	var shards := EquipRules.mats_get(c, "shard")
	var need := float(D["LEGEND_SHARD_COST"])
	ev.add_child(_center_label("★ %s — %s (%s/%s)" % [t("gear.exchange_title"), t("gear.exchange_desc", {"n": num(need)}), num(shards), num(need)], 11, OKit.GOLD, 700, LIST_W - 28))
	var lg := GridContainer.new()
	lg.name = "Legends"
	lg.columns = 3
	lg.add_theme_constant_override("h_separation", 6)
	lg.add_theme_constant_override("v_separation", 6)
	ev.add_child(lg)
	var tw := func(k: String, p: Dictionary) -> String: return t(k, p)
	for id: String in (D["LEGENDS"] as Dictionary).keys():
		var b := OKit.styled_button(OKit.box(Color(OKit.GOLD, 0.08), Color(OKit.GOLD, 0.5), 4, 1, 6, 4), OKit.box(Color(OKit.GOLD, 0.18), OKit.GOLD, 4, 1, 6, 4), null, 4)
		b.name = "Legend_" + id
		b.custom_minimum_size = Vector2((LIST_W - 28 - 12) / 3.0, 30)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = t("gear.legend." + id)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override("font_size", 10)
		b.add_theme_color_override("font_color", OKit.GOLD)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_focus_color", Color.WHITE)
		var tex: Texture2D = icons.call("item", "legend_" + id)
		b.icon = tex
		b.add_theme_constant_override("icon_max_width", 18)
		var fxl: Array = []
		var fxd: Dictionary = D["LEGENDS"][id]["fx"]
		for k: String in fxd.keys():
			fxl.append(EquipRules.fmt(c, k, fxd[k], tw))
		b.tooltip_text = " · ".join(fxl)
		if shards < need:
			b.modulate.a = 0.45
		b.pressed.connect(exchange_legend.bind(id))
		lg.add_child(b)
	_full(ex)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	list.add_child(sp)


func _gacha_card(emoji: String, title_key: String, desc_key: String, btn_text: String, ok: bool, col: Color, cb: Callable, nm: String) -> Control:
	var p := _card(HALF_W, Color(167 / 255.0, 139 / 255.0, 250 / 255.0, 0.3) if nm == "Gacha10" else Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.15))
	p.name = nm
	var v := OKit.vbox(6)
	p.add_child(v)
	var ib := CenterContainer.new()
	ib.name = "Icon"
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if emoji != "":
		# 🎲·🎱 은 그림 시트에 없어 같은 시트의 상자 그림으로 (새 그림 없이)
		var et := emoji_tex(emoji)
		if et != null:
			ib.add_child(OKit.tex_rect(et, Vector2(40, 40)))
		else:
			ib.add_child(ItemView.icon(icons, "chest" if nm == "Gacha1" else "e_box", 44))
	v.add_child(ib)
	v.add_child(_center_label(t(title_key), 14, Color.WHITE, 800, HALF_W - 28))
	v.add_child(_center_label(t(desc_key), 10, OKit.DIM2, 500, HALF_W - 28))
	v.add_child(_icon_box(_buy_btn(btn_text, ok, false, col, cb, "Buy")))
	return p


# ═══════════ 사기 ═══════════

func _after_buy() -> void:
	refresh_gold()
	render()


## 카드 단추 (용병은 바로, 나머지는 확인 창 — 웹과 같음)
func buy_item(idx: int) -> void:
	if not act_once():
		return
	var items: Array = data.get("items", [])
	if idx < 0 or idx >= items.size():
		return
	var it: Dictionary = items[idx]
	var ty := str(it["type"]) if Js.truthy(it.get("type")) else "char"
	var cost := Js.num(it.get("cost"))
	if ShopRules.gold(c) < cost or (Js.truthy(it.get("sold")) and ty != "potion" and ty != "battle_potion" and ty != "siege"):
		return
	if ty == "char":
		_do_buy(idx)
		return
	var msg := ""
	match ty:
		"potion":
			msg = t("shop.potion_buy_confirm", {"potion": _potion_name(it), "gold": num(cost)})
		"battle_potion":
			msg = t("shop.battle_potion_buy_confirm", {"name": t("battle_potions." + str(it["potionId"])), "gold": num(cost)})
		"siege":
			msg = t("shop.siege_buy_confirm", {"item": t("shop." + str(it["siegeId"])), "gold": num(cost)})
		"skillbook":
			msg = t("shop.skillbook_buy_confirm", {"skill": t("skills." + str(it["skillId"])), "gold": num(cost)})
		"soulstone":
			msg = t("soul.buy_confirm", {"cls": t("classes." + str(it["cls"])), "gold": num(cost)})
		"scroll":
			msg = t("shop.scroll_buy_confirm", {"scroll": _scroll_name(str(it["scrollCls"])), "gold": num(cost)})
	confirm(msg, func() -> void: _do_buy(idx))


func _potion_name(it: Dictionary) -> String:
	return t(str(it["i18nNameKey"])) if Js.truthy(it.get("i18nNameKey")) else str(it.get("name", ""))


func _do_buy(idx: int) -> void:
	var r := ShopRules.buy(c, data, idx, names)
	_after_buy()
	if not r["ok"]:
		return
	var it: Dictionary = data["items"][idx]
	match str(r["kind"]):
		"potion":
			alert(_potion_name(it) + " " + t("shop.potion_stored"))
		"battle_potion":
			alert(t("shop.battle_potion_stored", {"name": t("battle_potions." + str(it["potionId"]))}))
		"siege":
			alert(t("shop." + str(it["siegeId"])) + " " + t("shop.siege_stored"))
		"skillbook":
			alert(t("academy.skillbook_drop", {"skill": t("skills." + str(it["skillId"]))}))
		"scroll":
			alert(_scroll_name(str(it["scrollCls"])) + " " + t("shop.scroll_stored"))


func buy_rune() -> void:
	if not act_once():
		return
	var k := ShopRules.rune_gacha(c)
	if k == "":
		return
	_after_buy()
	alert(str(D["ENCHANTS"][k].get("icon", "")) + " " + t("enchant.rune_got", {"rune": t("enchant.rune_name", {"e": t("enchant." + k)})}))


func do_gacha(count: int) -> void:
	if not act_once():
		return
	var res := ShopRules.gacha(c, count)
	if res.is_empty():
		return
	_after_buy()
	show_gacha_results(res)


func buy_mat(k: String) -> void:
	if not act_once():
		return
	if not ShopRules.buy_mat(c, k):
		return
	_after_buy()
	alert(("🔩" if k == "stone" else "📜") + " " + t("gear.shop_bought", {"name": t("gear." + k)}))


func exchange_legend(id: String) -> void:
	if not act_once():
		return
	var have := EquipRules.mats_get(c, "shard")
	var need := float(D["LEGEND_SHARD_COST"])
	if have < need:
		alert(t("gear.exchange_need", {"have": num(have), "n": num(need)}))
		return
	var tw := func(k: String, p: Dictionary) -> String: return t(k, p)
	var fxl: Array = []
	var fxd: Dictionary = D["LEGENDS"][id]["fx"]
	for k: String in fxd.keys():
		fxl.append(EquipRules.fmt(c, k, fxd[k], tw))
	confirm(t("gear.exchange_confirm", {"n": num(need), "name": t("gear.legend." + id)}) + "\n\n" + "\n".join(fxl), func() -> void:
		var it: Variant = ShopRules.exchange_legend(c, id)
		if it != null:
			_after_buy()
			alert(t("gear.exchange_done", {"name": EquipRules.gear_name(it, tw)})))


## 뽑기 결과 창 (웹 showGachaResults)
func show_gacha_results(results: Array) -> void:
	var tw := func(k: String, p: Dictionary) -> String: return t(k, p)
	var g := GridContainer.new()
	g.name = "GachaResults"
	g.columns = 4 if results.size() > 1 else 1
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	for it: Dictionary in results:
		var rc := ItemView.rarity_color(D, it.get("rarity"))
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", OKit.box(Color(1, 1, 1, 0.04), rc, 8, 2, 8, 8))
		p.custom_minimum_size = Vector2(170, 0)
		var v := OKit.vbox(3)
		p.add_child(v)
		v.add_child(_center_label(t("equip.rarity." + str(it.get("rarity"))), 10, rc, 900, 150))
		v.add_child(_icon_box(ItemView.equip_icon(icons, D, it, 44)))
		v.add_child(_center_label(EquipRules.gear_name(it, tw), 12, Color.WHITE, 800, 150))
		v.add_child(_center_label(t("equip.slot." + str(it.get("slot"))), 10, OKit.DIM, 600, 150))
		var st: Array = []
		for k: String in (it.get("stats", {}) as Dictionary).keys():
			st.append(t("common." + k) + "+" + num(it["stats"][k]))
		v.add_child(_center_label(" ".join(st), 10, Color("86efac"), 700, 150))
		if Js.truthy(it.get("setId")) and not Js.truthy(it.get("setCls")):
			v.add_child(_center_label(t("equip.set." + str(it["setId"])), 10, OKit.GOLD, 700, 150))
		v.add_child(ItemView.lines_box(EquipRules.lines(c, it, null, tw), 150, 9))
		g.add_child(p)
	open_modal(g, {"name": "GachaModal", "title": t("shop.gacha_results"), "width": 820.0 if results.size() > 1 else 320.0,
		"buttons": [{"text": t("common.confirm"), "name": "Ok"}]})
