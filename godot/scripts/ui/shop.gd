extends "res://scripts/ui/screen_base.gd"
## 상점 — 웹 shop.html + js/shop.js + css/shop.css (4b-1)
##  골드 배지, 탭 6개(용병 · 소모품 · 장비 · 스킬 · 전직서 · 골드), 탭 제목 + 갱신 타이머(소모품·골드 탭은 숨김), 카드 목록(2열)
##   용병: 광고 카드(추후 개발) + 용병 6 (등급·그림·이름·직업·스탯(+잠재력)·모집)
##   소모품: 광고 + 룬 뽑기 + 경험치 물약 3 · 전투 물약 6 · 공성 아이템 3 (사도 사라지지 않음)
##   장비: 광고 + 천장 막대 + 확률표 + 1회 · 10+1회 뽑기 + 강화 재료(강화석 · 보호 주문서) + 전설 교환
##   스킬: 광고 + 영혼석 3 · 스킬북 6,  전직서: 광고 + 전직서 6,  골드: 광고 + 결제 꾸러미 4 (웹도 '추후 오픈 예정')
##  (5단계) 광고 카드는 Platform.has_ads() 일 때만 — PC 가게판(stove·steam)은 광고가 없어 숨김.
##  (결제층 A) 결제 카드: 상품·가격은 Billing.products() (가게 가격 글, 못 받으면 data 의 fallback_price). 결제 길이 없는 판(steam·출시 빌드 dev)은 숨김,
##   길은 있는데 SDK 가 아직이면(지금의 stove·google·apple 빈 틀) 꺼진 단추. 누르면 구매 확인 창(청약철회·미성년자 안내) → 진행 중 창 → 결과 알림.
##   광고 카드: 탭마다 한 장(웹 배치 그대로) — 보상은 모두 골드, 하루 횟수는 전체 합계 (Ads · ad_rules.gd). '확률 정보' 단추(장비·소모품 탭) → odds_view.gd
##  규칙은 scripts/logic/shop_rules.gd (웹과 같은 난수 순서·저장 형식). 사기는 웹과 같이 확인 창(용병·룬·뽑기·재료는 바로).
##  자원이 오가는 단추는 같은 프레임 연타를 막음 (act_once). 다른 화면에서 {tab: "scroll"} 처럼 탭을 정해 들어올 수 있음 (웹 shop.html?tab=)

const ShopRules := preload("res://scripts/logic/shop_rules.gd")
const EquipRules := preload("res://scripts/logic/equip_rules.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const ItemView := preload("res://scripts/ui/item_view.gd")
const OddsView := preload("res://scripts/ui/odds_view.gd")

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
var odds_btn: Button
var billing: Node
var ads: Node
## 결제 진행 중 창 (Billing.purchase_finished 가 오면 닫음)
var _pay_modal: Control = null
var _paying := ""
## 진행 중 창에 '닫기'가 나오기까지 (초) — 시험은 짧게
var progress_escape_secs := 30.0


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
	odds_btn = OKit.ghost_button("", 11)
	odds_btn.name = "OddsBtn"
	odds_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	odds_btn.pressed.connect(open_odds)
	ir.add_child(odds_btn)
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
	billing = _svc("Billing")
	ads = _svc("Ads")
	if billing != null:
		billing.connect("granted", _on_granted)
		billing.connect("revoked", _on_revoked)
		billing.connect("products_updated", _on_products)
		billing.connect("purchase_finished", _on_purchase_finished)
		# 상점 진입: 미처리 거래 다시 처리 · 환불 조회 · 가게 가격
		billing.call("restore")
		billing.call("refresh_products")
	if ads != null:
		ads.connect("rewarded", _on_ad_rewarded)
		ads.connect("closed", _on_ad_closed)
		ads.connect("failed", _on_ad_failed)


func _exit_tree() -> void:
	super._exit_tree()
	for pair: Array in [[billing, ["granted", _on_granted], ["revoked", _on_revoked], ["products_updated", _on_products], ["purchase_finished", _on_purchase_finished]],
			[ads, ["rewarded", _on_ad_rewarded], ["closed", _on_ad_closed], ["failed", _on_ad_failed]]]:
		var n: Node = pair[0]
		if n == null:
			continue
		for sc: Array in pair.slice(1):
			if n.is_connected(sc[0], sc[1]):
				n.disconnect(sc[0], sc[1])


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
	odds_btn.text = t("gd.odds.btn")
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
	odds_btn.visible = cur_tab == "equip" or cur_tab == "consumable"
	_update_timer()
	var gold := ShopRules.gold(c)
	match cur_tab:
		"equip":
			_render_gacha(gold)
			return
		"gold":
			_full(_ad_card("shop.gold_ad_title", "shop.gold_ad_desc"))
			# 결제 길이 없는 판(steam · 출시 빌드 dev)은 결제 카드를 숨김
			if billing != null and bool(billing.call("is_supported")):
				var gg := GridContainer.new()
				gg.name = "IapGrid"
				gg.columns = 2
				gg.add_theme_constant_override("h_separation", 10)
				gg.add_theme_constant_override("v_separation", 10)
				for pk: Dictionary in billing.call("products"):
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
	if ctl != null:
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


## 광고 카드 (광고가 없는 판이면 null — _full 이 건너뜀). (결제층 A) 보상은 탭과 상관없이 골드 — 하루 횟수는 전체 합계.
##  광고를 띄울 수 있으면(dev 가짜 광고) '광고 보기 (+100G)' + 오늘 남은 횟수, 아직 SDK 가 없으면(google·apple 빈 틀) 예전처럼 꺼진 '추후 개발' 단추
func _ad_card(key: String, key2: String = "") -> Control:
	var pf := get_node_or_null("/root/Platform")
	if pf != null and not bool(pf.call("has_ads")):
		return null
	if ads != null:
		return _gold_ad_card()
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


func _gold_ad_card() -> Control:
	var p := _card(LIST_W, Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.25))
	p.name = "AdCard"
	var h := OKit.hbox(12)
	p.add_child(h)
	var ad_tex := emoji_tex("🎬")
	if ad_tex != null:
		h.add_child(OKit.tex_rect(ad_tex, Vector2(28, 28)))
	var gold := int(float(ads.call("reward_gold")))
	var mx := int(ads.call("daily_max"))
	var left := int(ads.call("left_today"))
	var tv := OKit.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	var l := OKit.label(12, OKit.TEXT, 900)
	l.name = "AdText"
	l.text = t("gd.ads.card", {"gold": gold, "max": mx})
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	tv.add_child(l)
	var avail := bool(ads.call("is_available"))
	if avail:
		var ll := OKit.label(10, Color("60a5fa"), 700)
		ll.name = "AdLeft"
		ll.text = t("gd.ads.left", {"n": left, "max": mx})
		tv.add_child(ll)
	var b: Button
	if not avail:
		b = OKit.ghost_button(t("common.coming_soon"), 11)
		b.disabled = true
		b.modulate.a = 0.5
	elif left <= 0:
		b = OKit.ghost_button(t("gd.ads.none_left"), 11)
		b.disabled = true
		b.modulate.a = 0.5
	else:
		b = _buy_btn(t("gd.ads.btn", {"gold": gold}), true, false, Color("2563eb"), watch_ad, "AdWatch")
	b.name = "AdBtn"
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
	for row: Array in [[t("gd.stat.hp") + " ", jab["base"]["hp"], pot.get("hp")], [t("gd.stat.atk") + " ", jab["base"]["atk"], pot.get("atk")], [t("gd.stat.def") + " ", jab["base"]["def"], pot.get("def")], [t("gd.stat.ar") + " ", jab["actionRec"], pot.get("actionRec")]]:
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
	p.name = "Iap_" + str(pk["id"])
	var v := OKit.vbox(4)
	p.add_child(v)
	var amt := float(pk["gold"])
	# 양마다 다른 기존 그림 (💰·🪙 는 같은 그림이라 가장 작은 꾸러미는 골드 배지의 금화 그림)
	var tex: Texture2D = emoji_tex("💰") if amt >= 6500.0 else (emoji_tex("🏆") if amt >= 3000.0 else (emoji_tex("💎") if amt >= 1200.0 else icons.call("image", "icon/64x64/fc131.png")))
	var ic := OKit.tex_rect(tex, Vector2(36, 36))
	ic.name = "IapIcon"
	v.add_child(_icon_box(ic))
	v.add_child(_center_label(t(str(pk["key"])), 14, OKit.GOLD, 900, HALF_W - 28))
	var pl := _center_label(str(pk["price"]), 12, OKit.TEXT, 700, HALF_W - 28)
	pl.name = "Price"
	v.add_child(pl)
	var avail := billing != null and bool(billing.call("is_available"))
	var bz := billing != null and bool(billing.call("busy"))
	var pend := billing != null and bool(billing.call("purchase_pending", str(pk["id"])))
	var b := _buy_btn(t("gd.iap.processing_short") if pend else t("gd.iap.buy"), avail and not bz and not pend, false, Color("d97706"), buy_iap.bind(str(pk["id"])), "Buy")
	v.add_child(_icon_box(b))
	if not avail:
		var nl := _center_label(t("gd.iap.unavailable_short"), 10, OKit.DIM, 600, HALF_W - 28)
		nl.name = "Unavailable"
		v.add_child(nl)
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
	# 카드 묶음을 창 가운데에 (open_modal 은 내용을 가로로 채우므로 CenterContainer 로 감쌈)
	var gc := CenterContainer.new()
	gc.add_child(g)
	open_modal(gc, {"name": "GachaModal", "title": t("shop.gacha_results"), "width": 820.0 if results.size() > 1 else 320.0,
		"buttons": [{"text": t("common.confirm"), "name": "Ok"}]})


# ═══════════ 결제 (결제층 A) ═══════════

func _iap_product(id: String) -> Dictionary:
	if billing == null:
		return {}
	for p: Dictionary in billing.call("products"):
		if str(p["id"]) == id:
			return p
	return {}


## 결제 카드 '구매' → 구매 확인 창 (상품 · 가격 · 청약철회/미성년자 안내)
func buy_iap(id: String) -> void:
	if not act_once():
		return
	if billing == null or bool(billing.call("busy")) or _paying != "":
		return
	if not bool(billing.call("is_available")):
		alert(t("gd.iap.unavailable"))
		return
	var p := _iap_product(id)
	if p.is_empty():
		return
	var v := OKit.vbox(10)
	v.name = "IapConfirm"
	var nm := _center_label(t(str(p["key"])), 18, OKit.GOLD, 900, 380)
	nm.name = "Product"
	v.add_child(nm)
	var pr := _center_label(str(p["price"]), 16, Color.WHITE, 800, 380)
	pr.name = "Price"
	v.add_child(pr)
	var nb := PanelContainer.new()
	nb.name = "Notice"
	nb.add_theme_stylebox_override("panel", OKit.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08), 8, 1, 12, 10))
	var nv := OKit.vbox(5)
	nb.add_child(nv)
	for k: String in notice_keys(str(i18n.get("current_lang")) if i18n != null else "ko"):
		var l := OKit.label(10, OKit.DIM2, 500)
		l.name = k.get_slice(".", 2)
		l.text = "· " + t(k)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(356, 0)
		nv.add_child(l)
	v.add_child(nb)
	open_modal(v, {"name": "IapConfirmModal", "title": t("gd.iap.confirm_title"), "title_size": 22, "width": 468.0,
		"buttons": [{"text": t("gd.iap.buy"), "cb": func() -> void: _start_iap(id), "name": "Yes"}, {"text": t("common.cancel"), "secondary": true, "name": "No"}]})


## 구매 확인 창의 법정 안내 (재검수 디렉터 결정 — 지역은 게임 언어로 단순하게, 법무 확인 대상: README)
##  ko: 7일 청약철회(사용한 재화 등 제한) · 청약철회·환불은 구매한 스토어 고객센터 · 부가세 포함 · 미성년자
##  그 밖: 환불은 스토어 정책 · 가격·세금은 스토어 표시 기준 · 미성년자
static func notice_keys(lang: String) -> Array:
	if lang == "ko":
		return ["gd.iap.notice_withdraw", "gd.iap.notice_refund_store", "gd.iap.notice_vat", "gd.iap.notice_minor"]
	return ["gd.iap.notice_refund_policy", "gd.iap.notice_price_store", "gd.iap.notice_minor"]


func _start_iap(id: String) -> void:
	if billing == null or _paying != "":
		return
	if not bool(billing.call("buy", id)):
		alert(t("gd.iap.unavailable"))
		return
	_paying = id
	var v := OKit.vbox(12)
	var l := _msg_label(t("gd.iap.processing"))
	l.name = "Processing"
	v.add_child(l)
	var m := open_modal(v, {"name": "IapProgress", "no_esc": true, "close_on_bg": false})
	_pay_modal = m
	render()
	# 가게·서버가 응답하지 않을 때의 탈출구: progress_escape_secs 뒤 안내 + '닫기' (닫아도 구매는 미처리로 남고 restore 가 처리)
	get_tree().create_timer(progress_escape_secs).timeout.connect(func() -> void:
		if not is_instance_valid(m) or m.is_queued_for_deletion() or _pay_modal != m:
			return
		var nl := _msg_label(t("gd.iap.escape_note"))
		nl.name = "EscapeNote"
		nl.add_theme_font_size_override("font_size", 12)
		nl.add_theme_color_override("font_color", OKit.DIM2)
		nl.custom_minimum_size = Vector2(320, 0)
		v.add_child(nl)
		var cb := OKit.modal_button("", true)
		set_button_text(cb, t("common.close"), 18)
		cb.name = "EscapeClose"
		cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cb.pressed.connect(func() -> void:
			_paying = ""   # 결과가 나중에 오면 알림 띠로 (granted_toast)
			_pay_modal = null
			billing.call("release_busy")   # 다른 상품은 살 수 있게 (이 상품 카드는 '처리 중')
			_close_modal_node(m, false)
			render())
		v.add_child(cb)
		_fit_modal(m))


func _on_purchase_finished(id: String, r: Dictionary) -> void:
	if _pay_modal != null and is_instance_valid(_pay_modal):
		_close_modal_node(_pay_modal, false)
	_pay_modal = null
	var mine := _paying == id
	_paying = ""
	refresh_gold()
	render()
	if not mine:
		return
	var p := _iap_product(id)
	var st := str(r.get("status", ""))
	var msg := ""
	match st:
		"granted":
			msg = t("gd.iap.done", {"gold": grouped(float(r.get("gold", 0))), "name": t(str(p.get("key", "")))})
		"dup":
			msg = t("gd.iap.dup")
		"cancelled":
			msg = t("gd.iap.cancelled")
		"pending":
			msg = t("gd.iap.pending")
		"verify_failed":
			msg = t("gd.iap.retry_later")
		"save_failed":
			msg = t("gd.iap.save_failed")
		"deferred":
			msg = t("gd.iap.deferred")
		"invalid":
			msg = t("gd.iap.invalid", {"code": str(r.get("code", ""))})
		_:
			msg = t("gd.iap.failed", {"code": str(r.get("code", st))})
	var a := alert(msg)
	a.set_meta("iap_status", st)


func _on_granted(id: String, gold: float, _oid: String) -> void:
	refresh_gold()
	render()
	# 내 구매 결과는 결과 창이 알림 — 다시 처리(대기 승인·앱 복구, 진행 중인 구매를 restore 가 먼저 처리한 경우 포함)로 들어온 지급은 알림 띠로도
	if _paying != id or (billing != null and bool(billing.call("is_restoring"))):
		toast(t("gd.iap.granted_toast", {"gold": grouped(gold)}), "ok")


func _on_revoked(_id: String, taken: float, _oid: String) -> void:
	refresh_gold()
	render()
	toast(t("gd.iap.revoked_toast", {"gold": grouped(taken)}), "warn")


func _on_products() -> void:
	if cur_tab == "gold" and _paying == "":
		render()


# ── 광고 ──

func watch_ad() -> void:
	if not act_once():
		return
	if ads == null or bool(ads.call("showing")):
		return
	ads.call("show_rewarded", "shop_" + cur_tab)


func _on_ad_rewarded(_pl: String, gold: float) -> void:
	refresh_gold()
	render()
	alert(t("gd.ads.rewarded", {"gold": grouped(gold)}))


func _on_ad_closed(_pl: String) -> void:
	render()
	toast(t("gd.ads.closed"))


func _on_ad_failed(_pl: String, code: String) -> void:
	render()
	toast(t("gd.ads.limit" if code == "limit" else "gd.ads.failed"), "warn")


# ── 확률 정보 ──

func open_odds() -> void:
	if not act_once():
		return
	OddsView.open(self)
