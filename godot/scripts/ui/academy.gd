extends "res://scripts/ui/tabbed_list_screen.gd"
## 아카데미 — 웹 academy.html + js/academy.js + css/academy.css (4b-2)
##  골드 배지, 탭 2개(전직 · 스킬북), 탭 설명, 카드 목록
##   전직  : 노비스 카드 (등급 · 능력치 · 잠재력) → 전직서 고르기 창 → 확인 창(전직 후 예상 스탯) → 결과 알림.
##           전직서가 없으면 단추가 '전직서 구매' → 상점 전직서 탭 (웹 shop.html?tab=scroll)
##   스킬북: 가진 스킬북 카드 → 대상 고르기 창(같은 직업 · 최대 레벨 미만) → 확인 창 → 결과 알림
##  규칙은 scripts/logic/academy_rules.gd. 자원이 오가는 단추는 같은 프레임 연타를 막음 (act_once).

const Acad := preload("res://scripts/logic/academy_rules.gd")
const Sanc := preload("res://scripts/logic/sanctuary_rules.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")
const EquipRules := preload("res://scripts/logic/equip_rules.gd")
const TABS := ["classchange", "skillbook"]


func page_id() -> String:
	return "academy"


func title_text() -> String:
	return t("academy.title")


func tab_keys() -> Array:
	return TABS


func tab_label(k: String) -> String:
	return t("academy.tab_" + k)


func subtitle(k: String) -> String:
	return t("academy.subtitle") if k == "classchange" else t("academy.skillbook_subtitle")


func sname(ch: Variant) -> String:
	if not (ch is Dictionary):
		return "???"
	return char_name(ch)


func render_tab(k: String) -> void:
	if k == "classchange":
		_render_classchange()
	else:
		_render_books()


# ═══════════ 전직 ═══════════

func _render_classchange() -> void:
	var nov := Acad.novices(c)
	if nov.is_empty():
		empty_state("🎓", t("academy.no_novice"))
		return
	var has_scroll := not Acad.usable_scrolls(c).is_empty()
	for ch: Dictionary in nov:
		var g := Profile.pot_grade(c, ch)
		var gc := game_card("Novice_%s" % num(ch["uid"]))
		(gc[3] as HBoxContainer).add_child(portrait(ch, 44))
		(gc[3] as HBoxContainer).move_child((gc[3] as HBoxContainer).get_child(2), 0)
		var info: VBoxContainer = gc[1]
		info.add_child(name_line(sname(ch), ch.get("lv", 1), g, grade_color(g)))
		var p: Variant = ch.get("pot")
		var ar := ("+" + EquipRules.fixed_str(Js.num(p["actionRec"]), 2)) if p is Dictionary and Js.truthy(p.get("actionRec")) else "−"
		info.add_child(line(stat_text(ch, ar), 11, OKit.DIM, 600))
		info.add_child(line("%s: %s (HP/ATK/DEF/AR)" % [t("stats.potential"), pot_text(ch)], 11, Color("a78bfa"), 600))
		var b: Button
		if has_scroll:
			b = act_btn(t("academy.class_change_btn"), Color("9333ea"), true, open_scrolls.bind(ch["uid"]), "ChangeBtn")
		else:
			# 전직서가 없으면 상점 전직서 탭으로 (웹 .game-btn--ghost)
			b = OKit.ghost_button("🛒 " + t("academy.buy_scroll"), 12, Color("c4b5fd"))
			b.name = "BuyScroll"
			set_button_text(b, "🛒 " + t("academy.buy_scroll"), 14)
			b.tooltip_text = t("academy.class_change_btn_noscroll")
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.pressed.connect(func() -> void: router.call("go", "shop", {"tab": "scroll"}))
		(gc[2] as HBoxContainer).add_child(b)


## 전직서 고르기 창 (웹 showScrollSelectModal)
func open_scrolls(uid: Variant) -> void:
	if modal_open():
		return
	var ch: Variant = Profile.get_char(c, uid)
	if ch == null:
		return
	var scrolls := Acad.usable_scrolls(c)
	if scrolls.is_empty():
		var e := OKit.vbox(6)
		e.add_child(_msg_label(t("academy.no_scroll")))
		open_modal(e, {"name": "ScrollModal", "title": t("academy.select_scroll"), "buttons": [{"text": t("common.close"), "secondary": true, "name": "Close"}]})
		return
	var v := OKit.vbox(8)
	v.name = "Scrolls"
	var hd := OKit.hbox(8)
	hd.alignment = BoxContainer.ALIGNMENT_CENTER
	hd.add_child(cls_icon(str(ch["cls"]), 24))
	var hl := OKit.label(14, OKit.TEXT, 800)
	hl.text = "%s (Lv.%s)" % [sname(ch), num(ch.get("lv", 1))]
	hd.add_child(hl)
	v.add_child(hd)
	var w := OKit.label(11, OKit.DIM2, 500)
	w.text = t("class_change.warning_irreversible")
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(w)
	for s: Dictionary in scrolls:
		var cls := str(s["item"]["scrollCls"])
		v.add_child(pick_row("Scroll_%d" % int(s["idx"]), cls_icon(cls, 28), t("shop.scroll_prefix") + " " + t("classes." + cls), t("class_desc." + cls), "",
			confirm_change.bind(uid, cls, int(s["idx"])), 420.0))
	open_modal(v, {"name": "ScrollModal", "title": t("academy.select_scroll"), "width": 500.0, "buttons": [{"text": t("common.cancel"), "secondary": true, "name": "Cancel"}]})


## 확인 창 (웹 confirmClassChange) — 미리보기는 보관한 값(gd_class_preview), Godot 은 그 미리보기 그대로 전직
func confirm_change(uid: Variant, cls: String, idx: int) -> void:
	close_all_modals()
	var ch: Variant = Profile.get_char(c, uid)
	if ch == null:
		return
	var pv := Acad.preview_kept(c, ch, cls)   # 클랜원 + 직업마다 한 번만 굴려 보관 (닫았다 열어도 같은 값)
	if pv.is_empty():
		return
	var g := str(pv["grade"])
	# 등급 + 접미사: 웹은 붙여 써서 영어·스페인어가 'BGrade'·'BGrado' 가 됨 → 한중일 글자가 아니면 띄어 씀
	var suf := t("class_change.grade_suffix")
	var gs := g + ("" if suf == "" or suf.unicode_at(0) >= 0x1100 else " ") + suf
	var msg := "%s (Lv.%s %s)\n%s → %s\n\n%s\nHP %s / ATK %s / DEF %s\nMOV %s / RNG %s\n\n%s\n%s" % [sname(ch), num(ch.get("lv", 1)), gs,
		t("classes." + str(ch["cls"])), t("classes." + cls), t("class_change.stats_preview"), num(pv["hp"]), num(pv["atk"]), num(pv["def"]), num(pv["move"]), num(pv["range"]),
		t("shop.scroll_prefix") + " " + t("classes." + cls), t("class_change.warning_parenthetical")]
	confirm(msg, func() -> void: do_change(uid, pv, idx))


func do_change(uid: Variant, pv: Dictionary, idx: int) -> void:
	if not act_once():
		return
	var r := Acad.change_class(c, uid, pv, idx)
	after_change()
	if not bool(r["ok"]):
		return
	var ch: Dictionary = r["ch"]
	alert("%s\n%s\n\nHP %s / ATK %s / DEF %s\nMOV %s / RNG %s" % [sname(ch), t("class_change.success", {"oldClass": t("classes.novice"), "newClass": t("classes." + str(ch["cls"]))}),
		num(ch["hp"]), num(ch["atk"]), num(ch["def"]), num(ch["move"]), num(ch["range"])])


# ═══════════ 스킬북 ═══════════

func _render_books() -> void:
	var books := Acad.books(c)
	if books.is_empty():
		empty_state("📕", t("academy.no_skillbooks"))
		return
	for b: Dictionary in books:
		var it: Dictionary = b["item"]
		var gc := game_card("Book_%d" % int(b["idx"]), Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.25))
		var ic := cls_icon(str(it["cls"]), 26)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		(gc[3] as HBoxContainer).add_child(ic)
		(gc[3] as HBoxContainer).move_child(ic, 0)
		var info: VBoxContainer = gc[1]
		var nr := OKit.hbox(6)
		var si := OKit.tex_rect(icons.call("skill", str(it["id"]), ""), Vector2(20, 20))
		si.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nr.add_child(si)
		var nl := line(t("skills." + str(it["id"])), 14, OKit.TEXT, 800)
		nl.custom_minimum_size = Vector2(0, 0)
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.size_flags_horizontal = Control.SIZE_FILL
		nr.add_child(nl)
		var cp := OKit.pill(t("classes." + str(it["cls"])), 10, Color("60a5fa"), Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.12))
		cp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nr.add_child(cp)
		info.add_child(nr)
		info.add_child(line("Lv.1 Skill Book", 10, OKit.DIM, 600))
		(gc[2] as HBoxContainer).add_child(act_btn(t("academy.skillbook_use"), BLUE2, bool(b["has_target"]), open_book.bind(int(b["idx"]), it.duplicate()), "UseBtn"))


## 대상 고르기 창 (웹 showSkillBookTargets)
func open_book(idx: int, book: Dictionary) -> void:
	if modal_open():
		return
	var targets := Acad.targets(c, book)
	var sid := str(book["id"])
	var sk := t("skills." + sid)
	if targets.is_empty():
		var e := OKit.vbox(6)
		e.add_child(_msg_label(t("academy.skillbook_no_target")))
		open_modal(e, {"name": "BookModal", "title": t("academy.skillbook_select_target"), "buttons": [{"text": t("common.close"), "secondary": true, "name": "Close"}]})
		return
	var v := OKit.vbox(8)
	v.name = "BookTargets"
	var hd := OKit.hbox(6)
	hd.alignment = BoxContainer.ALIGNMENT_CENTER
	hd.add_child(OKit.tex_rect(icons.call("skill", sid, ""), Vector2(20, 20)))
	var hl := OKit.label(14, OKit.TEXT, 800)
	hl.text = sk + " Lv.1"
	hd.add_child(hl)
	v.add_child(hd)
	for ch: Dictionary in targets:
		var cur := PartyRules.char_skill_lv(c, ch, sid)
		var sub := ("NEW → Lv.1") if cur == 0.0 else "%s Lv.%s → %s" % [sk, num(cur), num(cur + 1.0)]
		v.add_child(pick_row("Target_%s" % num(ch["uid"]), cls_icon(str(ch["cls"]), 22), "%s Lv.%s" % [sname(ch), num(ch.get("lv", 1))], sub,
			"NEW" if cur == 0.0 else "Lv." + num(cur), confirm_book.bind(idx, book, ch["uid"]), 400.0))
	open_modal(v, {"name": "BookModal", "title": t("academy.skillbook_select_target"), "width": 480.0, "buttons": [{"text": t("common.cancel"), "secondary": true, "name": "Cancel"}]})


func confirm_book(idx: int, book: Dictionary, uid: Variant) -> void:
	close_all_modals()
	var ch: Variant = Profile.get_char(c, uid)
	if ch == null:
		return
	var sid := str(book["id"])
	var sk := t("skills." + sid)
	var nm := sname(ch)
	var cur := PartyRules.char_skill_lv(c, ch, sid)
	var msg := nm + "\n\n"
	if cur == 0.0:
		msg += t("academy.skillbook_learn_confirm", {"skill": sk, "name": nm})
	else:
		msg += t("academy.skillbook_confirm", {"skill": sk, "name": nm}) + "\n" + t("academy.skillbook_preview", {"from": num(cur), "to": num(cur + 1.0)})
	confirm(msg, func() -> void: do_book(idx, book, uid))


func do_book(idx: int, book: Dictionary, uid: Variant) -> void:
	if not act_once():
		return
	var r := Acad.use_book(c, idx, uid, book)
	after_change()
	if not bool(r["ok"]):
		return
	var nm := sname(r["ch"])
	var sk := t("skills." + str(r["skill"]))
	if bool(r["new_learn"]):
		alert(t("academy.skillbook_learn_success", {"name": nm, "skill": sk}))
	else:
		alert(t("academy.skillbook_success", {"name": nm, "skill": sk, "lv": num(r["lv"])}))

