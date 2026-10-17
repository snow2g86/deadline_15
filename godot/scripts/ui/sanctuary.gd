extends "res://scripts/ui/tabbed_list_screen.gd"
## 성소 — 웹 sanctuary.html + js/sanctuary.js + css/sanctuary.css (4b-2)
##  골드 배지, 탭 4개(부활 · 승급 · 개명 · 마법부여), 탭 설명, 카드 목록
##   부활    : 무료 부활 카드(30분마다 1명 — 고르기 창) + 죽은 클랜원 카드(골드 부활)
##   승급    : 영혼석 보관함(합치기) + 승급할 수 있는 클랜원 카드 → 제물 고르기 창(4점) → 확인 창(예상 능력치 '~') → 결과 알림
##   개명    : 클랜원 카드 → 이름 창 (앞뒤 공백 지움 · 10자 · 비우면 원래 이름)
##   마법부여: 가진 룬·맵별 대응 룬 안내 + 장비 카드(방어·공격 칸마다 룬 단추) → 확인 창 → 룬 1개 + 100G
##  규칙은 scripts/logic/sanctuary_rules.gd. 자원이 오가는 단추는 같은 프레임 연타를 막음 (act_once). 화면은 웹 배치·정보량 그대로.

const Sanc := preload("res://scripts/logic/sanctuary_rules.gd")
const EquipRules := preload("res://scripts/logic/equip_rules.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const LobbyRules := preload("res://scripts/logic/lobby_rules.gd")
const ItemView := preload("res://scripts/ui/item_view.gd")
const TABS := ["resurrect", "promote", "rename", "enchant"]

var _sac_sel: Array = []
var _sac_target: Variant = null
var sac_dialog: Control
var rename_dialog: Control
var rename_input: LineEdit
var _rename_uid: Variant = null


func page_id() -> String:
	return "sanctuary"


func title_text() -> String:
	return t("sanctuary.title")


func tab_keys() -> Array:
	return TABS


func tab_label(k: String) -> String:
	return t("enchant.tab") if k == "enchant" else t("sanctuary.tab_" + k)


func subtitle(k: String) -> String:
	match k:
		"promote":
			return t("sanctuary.promote_subtitle")
		"rename":
			return t("sanctuary.rename_subtitle")
		"enchant":
			return t("enchant.subtitle")
	return t("sanctuary.subtitle")


func _tw() -> Callable:
	return func(k: String, p: Dictionary) -> String: return t(k, p)


## 웹 charName: customName → 이름표 → (Godot) 직업 이름
func sname(ch: Dictionary) -> String:
	var n := char_name(ch)
	return t("classes." + str(ch.get("cls", ""))) if n == "???" else n


func render_tab(k: String) -> void:
	match k:
		"resurrect":
			_render_resurrect()
		"promote":
			_render_promote()
		"rename":
			_render_rename()
		"enchant":
			_render_enchant()


# ═══════════ 부활 ═══════════

func _render_resurrect() -> void:
	var dead := Sanc.dead_list(c)
	if dead.is_empty():
		empty_state("🕊️", t("sanctuary.no_dead_units"))
		return
	var ready := Sanc.ad_remain(c) <= 0.0
	var ad := game_card("AdCard", Color(74 / 255.0, 222 / 255.0, 128 / 255.0, 0.2), Color(74 / 255.0, 222 / 255.0, 128 / 255.0, 0.06))
	var adt := emoji_tex("🎬")
	if adt != null:
		var ir := OKit.tex_rect(adt, Vector2(30, 30))
		ir.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		(ad[3] as HBoxContainer).add_child(ir)
		(ad[3] as HBoxContainer).move_child(ir, 0)
	(ad[1] as VBoxContainer).add_child(line(t("sanctuary.ad_title"), 13, Color("4ade80"), 900))
	(ad[1] as VBoxContainer).add_child(line(t("sanctuary.ad_desc"), 11, OKit.DIM2, 500))
	var bt := t("sanctuary.ad_btn") if ready else t("sanctuary.ad_cooldown", {"minutes": Sanc.ad_minutes(c)})
	(ad[2] as HBoxContainer).add_child(act_btn(bt, GREEN2 if ready else Color("475569"), ready, open_ad_revive, "AdBtn"))
	var gold := Sanc.gold(c)
	for ch: Dictionary in dead:
		var cost := Sanc.revive_cost(c, ch)
		var gc := game_card("Dead_%s" % num(ch["uid"]))
		(gc[3] as HBoxContainer).add_child(portrait(ch, 44))
		(gc[3] as HBoxContainer).move_child((gc[3] as HBoxContainer).get_child(2), 0)
		(gc[1] as VBoxContainer).add_child(name_line(sname(ch), ch.get("lv", 1)))
		(gc[1] as VBoxContainer).add_child(line(stat_text(ch, EquipRules.fixed_str(Js.num(ch["actionRec"]), 2) if Js.truthy(ch.get("actionRec")) else "−"), 11, OKit.DIM, 600))
		(gc[2] as HBoxContainer).add_child(act_btn(t("sanctuary.resurrect_button", {"cost": num(cost)}), PURPLE, gold >= cost, revive.bind(ch["uid"]), "Revive"))


func revive(uid: Variant) -> void:
	if not act_once():
		return
	if Sanc.revive(c, uid):
		after_change()


## 무료 부활: 고르기 창 (웹 showAdReviveModal)
func open_ad_revive() -> void:
	if modal_open() or Sanc.ad_remain(c) > 0.0:
		return
	var v := OKit.vbox(6)
	v.name = "AdPick"
	for ch: Dictionary in Sanc.dead_list(c):
		v.add_child(pick_row("Pick_%s" % num(ch["uid"]), cls_icon(str(ch["cls"]), 22), "%s Lv.%s" % [sname(ch), num(ch.get("lv", 1))], "", "HP " + num(ch.get("hp", 0)), ad_revive.bind(ch["uid"])))
	open_modal(v, {"name": "AdModal", "title": t("sanctuary.ad_select"), "buttons": [{"text": t("common.cancel"), "secondary": true, "name": "Cancel"}]})


func ad_revive(uid: Variant) -> void:
	if not act_once():
		return
	if not Sanc.ad_revive(c, uid):
		return
	close_all_modals()
	after_change()
	var ch: Variant = Profile.get_char(c, uid)
	alert(t("sanctuary.ad_success", {"name": sname(ch) if ch != null else ""}))


# ═══════════ 승급 ═══════════

func _render_promote() -> void:
	_soul_box()
	var list_p := Sanc.promotable(c)
	if list_p.is_empty():
		empty_state("⭐", t("sanctuary.no_promotable"))
		return
	for ch: Dictionary in list_p:
		var st := Sanc.promote_state(c, ch)
		var g := str(st["grade"])
		var gc := game_card("Promote_%s" % num(ch["uid"]), Color(192 / 255.0, 132 / 255.0, 252 / 255.0, 0.25))
		(gc[3] as HBoxContainer).add_child(portrait(ch, 44))
		(gc[3] as HBoxContainer).move_child((gc[3] as HBoxContainer).get_child(2), 0)
		var info: VBoxContainer = gc[1]
		info.add_child(name_line(sname(ch), ch.get("lv", 1), g, grade_color(g)))
		var ar := Js.num(ch.get("actionRec"))
		if ar == 0.0:
			ar = Js.num(D["JAB"][ch["cls"]].get("actionRec"))
		if ar == 0.0:
			ar = 1.0
		info.add_child(line(stat_text(ch, EquipRules.fixed_str(ar, 2)), 11, OKit.DIM, 600))
		info.add_child(line("%s: %s (HP/ATK/DEF/AR)" % [t("stats.potential"), pot_text(ch)], 11, Color("a78bfa"), 600))
		var sk: Array = []
		for s: Dictionary in Sanc.skill_lvs(c, ch):
			sk.append("%s Lv.%s" % [t("skills." + str(s["id"])), num(s["lv"])])
		if not sk.is_empty():
			info.add_child(line(", ".join(sk), 10, Color("c084fc"), 600))
		if float(st["soul_need"]) > 0.0:
			var ok: bool = float(st["soul_have"]) >= float(st["soul_need"])
			var sr := emoji_row("💠 " + t("soul.need", {"have": num(st["soul_have"]), "need": num(st["soul_need"])}), 11, Color("4ade80") if ok else Color("f87171"), 700)
			sr.name = "SoulNeed"
			info.add_child(sr)
		(gc[2] as HBoxContainer).add_child(act_btn(t("sanctuary.promote_btn"), Color("9333ea"), bool(st["can"]), open_sacrifice.bind(ch["uid"]), "PromoteBtn"))


## 영혼석 보관함 (웹 renderSoulBox)
func _soul_box() -> void:
	var p := PanelContainer.new()
	p.name = "SoulBox"
	p.add_theme_stylebox_override("panel", OKit.box(Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.06), Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.25), 10, 1, 14, 12))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := OKit.vbox(8)
	p.add_child(v)
	var hr := emoji_row("💠 " + t("soul.box_title"), 13, Color("93c5fd"), 900)
	v.add_child(hr)
	v.add_child(line(t("soul.box_help", {"n": num(D["SOUL"]["fragsPerStone"])}), 10, OKit.DIM2, 500))
	var owned := Sanc.soul_owned(c)
	if owned.is_empty():
		v.add_child(line(t("soul.box_empty"), 11, OKit.DIM, 500))
	else:
		var g := GridContainer.new()
		g.name = "SoulGrid"
		g.columns = 4
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 8)
		v.add_child(g)
		var per := float(D["SOUL"]["fragsPerStone"])
		for cls: String in owned:
			var cell := PanelContainer.new()
			cell.name = "Soul_" + cls
			cell.add_theme_stylebox_override("panel", OKit.box(Color(0, 0, 0, 0.2), Color(1, 1, 1, 0.08), 8, 1, 8, 6))
			cell.custom_minimum_size = Vector2(100, 0)
			cell.tooltip_text = t("soul.stone_name", {"cls": t("classes." + cls)})
			cell.mouse_filter = Control.MOUSE_FILTER_PASS
			var cv := OKit.vbox(3)
			cell.add_child(cv)
			var ch := OKit.hbox(6)
			ch.add_child(cls_icon(cls, 22))
			var st := OKit.label(15, Color.WHITE, 900)
			st.text = num(Sanc.soul_stones(c, cls))
			st.name = "Stones"
			ch.add_child(st)
			var fr := OKit.label(10, OKit.DIM2, 600)
			fr.text = "%s/%s" % [num(Sanc.soul_frags(c, cls)), num(per)]
			fr.name = "Frags"
			fr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ch.add_child(fr)
			cv.add_child(ch)
			if Sanc.soul_frags(c, cls) >= per:
				var b := OKit.ghost_button(t("soul.combine"), 11, Color("93c5fd"))
				b.name = "Combine"
				b.pressed.connect(combine.bind(cls))
				cv.add_child(b)
			g.add_child(cell)
	list.add_child(p)


func combine(cls: String) -> void:
	if not act_once():
		return
	var n := Sanc.soul_combine(c, cls)
	render()
	if n > 0:
		alert(t("soul.combined", {"cls": t("classes." + cls), "n": n}))


## 제물 고르기 창 (웹 showSacrificeModal — 여러 명 · 4점)
func open_sacrifice(uid: Variant) -> void:
	if modal_open():
		return
	var target: Variant = Profile.get_char(c, uid)
	if target == null:
		return
	_sac_target = uid
	_sac_sel = []
	var tg := Profile.pot_grade(c, target)
	var v := OKit.vbox(8)
	v.name = "Sacrifice"
	var ti := OKit.hbox(8)
	ti.alignment = BoxContainer.ALIGNMENT_CENTER
	ti.add_child(cls_icon(str(target["cls"]), 24))
	var tl := name_line(sname(target), target.get("lv", 1), tg, grade_color(tg))
	tl.fit_content = true
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	ti.add_child(tl)
	v.add_child(ti)
	var bar := Kit.Bar.new()
	bar.name = "PtsBar"
	bar.custom_minimum_size = Vector2(360, 10)
	bar.track = Color(1, 1, 1, 0.08)
	bar.set_value(0.0, Color("7c3aed"), Color("7c3aed"))
	v.add_child(bar)
	var pl := OKit.label(12, OKit.TEXT, 700)
	pl.name = "PtsText"
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pl)
	var sl := OKit.vbox(6)
	sl.name = "SacList"
	v.add_child(sl)
	for ch: Dictionary in Sanc.sacrifices(c, target):
		var g := Profile.pot_grade(c, ch)
		var pts := Sanc.sacrifice_points(c, g, tg)
		var row := pick_row("Sac_%s" % num(ch["uid"]), cls_icon(str(ch["cls"]), 22), "%s Lv.%s %s" % [sname(ch), num(ch.get("lv", 1)), g],
			"HP %s · ATK %s · DEF %s" % [num(ch.get("hp", 0)), num(ch.get("atk", 0)), num(ch.get("def", 0))], "+%dpt" % pts, toggle_sacrifice.bind(ch["uid"]), 380.0)
		row.toggle_mode = false
		sl.add_child(row)
	var msg := OKit.label(11, OKit.DIM2, 600)
	msg.name = "Status"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(360, 0)
	v.add_child(msg)
	sac_dialog = open_modal(v, {"name": "SacModal", "title": t("sanctuary.promote_select_sacrifice"), "width": 480.0,
		"buttons": [{"text": t("common.cancel"), "secondary": true, "name": "Cancel"}, {"text": t("sanctuary.promote_btn"), "name": "Confirm", "cb": confirm_promote}]})
	_update_sac()


func toggle_sacrifice(uid: Variant) -> void:
	var i := Js.index_of(_sac_sel, uid)
	if i >= 0:
		_sac_sel.remove_at(i)
	else:
		_sac_sel.append(uid)
	_update_sac()


func _update_sac() -> void:
	if sac_dialog == null or not is_instance_valid(sac_dialog):
		return
	var target: Variant = Profile.get_char(c, _sac_target)
	if target == null:
		return
	var pts := Sanc.points_of(c, target, _sac_sel)
	var need := Sanc.REQUIRED_POINTS
	var bar: Kit.Bar = sac_dialog.find_child("PtsBar", true, false)
	var col := Color("c084fc") if pts >= need else Color("7c3aed")
	bar.set_value(minf(1.0, Js.round_js(float(pts) / float(need) * 100.0) / 100.0), col, col)
	(sac_dialog.find_child("PtsText", true, false) as Label).text = "%d / %d pt" % [pts, need]
	var st: Label = sac_dialog.find_child("Status", true, false)
	if _sac_sel.is_empty():
		st.text = t("sanctuary.sacrifice_select_more")
	elif pts >= need:
		st.text = ""
	else:
		st.text = "⚠ %d %s" % [need - pts, t("sanctuary.more_points")]
	var cb: Button = sac_dialog.find_child("Confirm", true, false)
	cb.disabled = pts < need
	cb.modulate.a = 1.0 if pts >= need else 0.45
	cb.tooltip_text = t("sanctuary.promote_btn_help")
	var sl: Node = sac_dialog.find_child("SacList", true, false)
	for row: Node in sl.get_children():
		var uid := str(row.name).trim_prefix("Sac_")
		var on := false
		for u: Variant in _sac_sel:
			if num(u) == uid:
				on = true
		(row as Button).add_theme_stylebox_override("normal", OKit.box(Color(168 / 255.0, 85 / 255.0, 247 / 255.0, 0.18) if on else Color(1, 1, 1, 0.04),
			Color("a855f7") if on else Color(1, 1, 1, 0.1), 8, 1, 10, 8))
		var bl: Label = row.find_child("Badge", true, false)
		if bl != null:
			bl.text = ("✓ " if on else "") + bl.text.trim_prefix("✓ ")


## 확인 창 (웹 confirmPromote — 예상치를 위해 잠재력을 한 번 굴림) → 확인 → 승급
func confirm_promote() -> void:
	var uid: Variant = _sac_target
	var sel := _sac_sel.duplicate()
	var target: Variant = Profile.get_char(c, uid)
	if target == null or sel.is_empty():
		return
	var pv := Sanc.promote_preview(c, uid, sel)
	if pv.is_empty():
		return
	var names: Array = []
	for su: Variant in sel:
		var s: Variant = Profile.get_char(c, su)
		names.append(sname(s) if s != null else "???")
	var nm := sname(target)
	var msg := "%s (Lv.%s)\n%s → %s\n" % [nm, num(target.get("lv", 1)), pv["cur"], pv["next"]]
	if float(pv["soul"]) > 0.0:
		msg += "💠 " + t("soul.consume", {"cls": t("classes." + str(target["cls"])), "n": num(pv["soul"])}) + "\n"
	msg += "\nHP %s → ~%s\nATK %s → ~%s\nDEF %s → ~%s" % [num(target["hp"]), num(pv["hp"]), num(target["atk"]), num(pv["atk"]), num(target["def"]), num(pv["def"])]
	if not (pv["skills"] as Array).is_empty():
		var parts: Array = []
		for s2: Dictionary in pv["skills"]:
			parts.append("%s Lv.%s→%s" % [t("skills." + str(s2["id"])), num(s2["cur"]), num(s2["new"])])
		msg += "\n" + t("sanctuary.skill_inherit") + ": " + ", ".join(parts)
		if bool(pv["overflow"]):
			msg += "\n" + t("sanctuary.skill_overflow")
	msg += "\n\n" + t("sanctuary.promote_confirm_multi", {"count": sel.size(), "target": nm, "from": pv["cur"], "to": pv["next"]}) + "\n" + t("sanctuary.promote_warning")
	confirm(msg, func() -> void: do_promote(uid, sel))


func do_promote(uid: Variant, sel: Array) -> void:
	if not act_once():
		return
	var r := Sanc.promote(c, uid, sel)
	after_change()
	if not bool(r["ok"]):
		if str(r.get("reason")) == "no_soul":
			alert(t("soul.not_enough"))
		return
	var ch: Dictionary = r["ch"]
	var nm := sname(ch)
	var msg := "%s\n%s\n\nHP %s / ATK %s / DEF %s" % [nm, t("sanctuary.promote_success", {"name": nm, "grade": r["grade"]}), num(ch["hp"]), num(ch["atk"]), num(ch["def"])]
	var sk: Array = []
	for s: Dictionary in Sanc.skill_lvs(c, ch):
		sk.append("%s Lv.%s" % [t("skills." + str(s["id"])), num(s["lv"])])
	if not sk.is_empty():
		msg += "\n" + ", ".join(sk)
	for b: String in r["books"]:
		msg += "\n" + t("sanctuary.skillbook_gained", {"skill": t("skills." + b)})
	alert(msg)


# ═══════════ 개명 ═══════════

func _render_rename() -> void:
	var al := Sanc.alive(c)
	if al.is_empty():
		empty_state("✏️", t("sanctuary.no_rename_units"))
		return
	for ch: Dictionary in al:
		var gc := game_card("Rename_%s" % num(ch["uid"]))
		(gc[3] as HBoxContainer).add_child(portrait(ch, 44))
		(gc[3] as HBoxContainer).move_child((gc[3] as HBoxContainer).get_child(2), 0)
		(gc[1] as VBoxContainer).add_child(name_line(sname(ch), ch.get("lv", 1)))
		(gc[1] as VBoxContainer).add_child(line(stat_text(ch, EquipRules.fixed_str(Js.num(ch["actionRec"]), 2) if Js.truthy(ch.get("actionRec")) else "−"), 11, OKit.DIM, 600))
		(gc[2] as HBoxContainer).add_child(act_btn(t("sanctuary.rename_button"), BLUE2, true, open_rename.bind(ch["uid"]), "RenameBtn"))


func open_rename(uid: Variant) -> void:
	if modal_open():
		return
	var ch: Variant = Profile.get_char(c, uid)
	if ch == null:
		return
	_rename_uid = uid
	var v := OKit.vbox(10)
	v.name = "Rename"
	var ti := OKit.hbox(8)
	ti.alignment = BoxContainer.ALIGNMENT_CENTER
	ti.add_child(cls_icon(str(ch["cls"]), 24))
	var nl := OKit.label(14, OKit.TEXT, 700)
	nl.text = "%s (Lv.%s)" % [sname(ch), num(ch.get("lv", 1))]
	ti.add_child(nl)
	v.add_child(ti)
	rename_input = LineEdit.new()
	rename_input.name = "NameInput"
	rename_input.placeholder_text = sname(ch)
	rename_input.custom_minimum_size = Vector2(320, 42)
	rename_input.add_theme_font_size_override("font_size", 15)
	rename_input.add_theme_font_override("font", Kit.bold(500))
	rename_input.add_theme_stylebox_override("normal", OKit.box(Color("0b111b"), Color("2c3648"), 8, 1, 12, 8))
	rename_input.add_theme_stylebox_override("focus", OKit.box(Color("0b111b"), OKit.GOLD, 8, 1, 12, 8))
	# 웹 <input maxlength="10"> — UTF-16 단위로 자름 (지휘관 이름과 같은 규칙)
	rename_input.text_changed.connect(func(tx: String) -> void:
		if LobbyRules.utf16_len(tx) > Sanc.NAME_LEN:
			var col := rename_input.caret_column
			rename_input.text = LobbyRules.utf16_slice(tx, Sanc.NAME_LEN)
			rename_input.caret_column = mini(col, rename_input.text.length()))
	rename_input.text_submitted.connect(func(_s: String) -> void: rename_done())
	v.add_child(rename_input)
	rename_dialog = open_modal(v, {"name": "RenameModal", "title": t("sanctuary.rename_title"),
		"buttons": [{"text": t("common.cancel"), "secondary": true, "name": "Cancel"}, {"text": t("common.confirm"), "name": "Confirm", "cb": rename_done}]})
	rename_input.grab_focus.call_deferred()


func rename_done() -> void:
	if not act_once():
		return
	if rename_input == null or not is_instance_valid(rename_input):
		return
	var raw := rename_input.text
	if rename_dialog != null and is_instance_valid(rename_dialog):
		_close_modal_node(rename_dialog, false)
	rename_dialog = null
	var ch: Variant = Sanc.rename(c, _rename_uid, raw)
	if ch == null:
		return
	render()
	alert(t("sanctuary.rename_success", {"name": sname(ch)}))


# ═══════════ 마법부여 ═══════════

func _render_enchant() -> void:
	var EN: Dictionary = D["ENCHANTS"]
	var box := PanelContainer.new()
	box.name = "RuneBox"
	box.add_theme_stylebox_override("panel", OKit.box(Color(167 / 255.0, 139 / 255.0, 250 / 255.0, 0.06), Color(167 / 255.0, 139 / 255.0, 250 / 255.0, 0.25), 10, 1, 14, 12))
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := OKit.vbox(8)
	box.add_child(v)
	v.add_child(emoji_row("🔮 " + t("enchant.runes_title"), 13, Color("c4b5fd"), 900))
	v.add_child(line(t("enchant.runes_help", {"gold": num(D["ENCHANT_FEE"])}), 10, OKit.DIM2, 500))
	for cat: String in ["def", "atk"]:
		var row := HFlowContainer.new()
		row.name = "Runes_" + cat
		row.add_theme_constant_override("h_separation", 10)
		row.add_theme_constant_override("v_separation", 4)
		var cl := OKit.label(11, OKit.GOLD, 800)
		cl.text = t("enchant.cat_" + cat)
		row.add_child(cl)
		for k: String in _kinds(cat):
			var n := Sanc.rune_count(c, k)
			var h := OKit.hbox(3)
			h.name = "Rune_" + k
			h.mouse_filter = Control.MOUSE_FILTER_PASS
			h.tooltip_text = t("enchant.desc_" + k)
			h.add_child(ItemView.icon(icons, "rune_" + k, 18, str(EN[k].get("icon", ""))))
			var nl := OKit.label(11, OKit.TEXT if n > 0 else OKit.DIM, 600)
			nl.text = "%s %d" % [t("enchant." + k), n]
			h.add_child(nl)
			if n == 0:
				h.modulate.a = 0.55
			row.add_child(h)
		v.add_child(row)
	var guide := HFlowContainer.new()
	guide.name = "HazardGuide"
	guide.add_theme_constant_override("h_separation", 12)
	for m: String in (D["HAZARDS"] as Dictionary).keys():
		var hz: Dictionary = D["HAZARDS"][m]
		guide.add_child(emoji_row("%s %s → %s" % [hz["icon"], t("hazard." + str(hz["id"])), EN[hz["enchant"]]["icon"]], 10, OKit.DIM2, 600))
	v.add_child(guide)
	var g2 := VBoxContainer.new()
	g2.name = "AtkGuide"
	for k2: String in _kinds("atk"):
		var h2 := OKit.hbox(4)
		h2.add_child(ItemView.icon(icons, "rune_" + k2, 18, str(EN[k2].get("icon", ""))))
		h2.add_child(line(t("enchant.desc_" + k2), 10, OKit.DIM2, 500))
		g2.add_child(h2)
	v.add_child(g2)
	list.add_child(box)
	var items := Sanc.enchant_items(c)
	if items.is_empty():
		empty_state("🗡️", t("enchant.no_items"))
		return
	var tw := _tw()
	for it: Dictionary in items:
		var gc := game_card("Enc_%s" % str(it.get("eid", "")), Color(192 / 255.0, 132 / 255.0, 252 / 255.0, 0.25))
		var ic := ItemView.equip_icon(icons, D, it, 44)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		(gc[3] as HBoxContainer).add_child(ic)
		(gc[3] as HBoxContainer).move_child(ic, 0)
		var info: VBoxContainer = gc[1]
		var nmtx := EquipRules.gear_name(it, tw) + ((" +" + num(it["enhanceLv"])) if Js.truthy(it.get("enhanceLv")) else "")
		info.add_child(line(nmtx, 14, ItemView.rarity_color(D, it.get("rarity")), 800))
		var owner: Variant = Sanc.owner_of(c, it)
		var cur: Array = []
		for f: String in ["enchant", "enchantAtk"]:
			var k3: Variant = it.get(f)
			if Js.truthy(k3) and EN.has(k3):
				cur.append("%s %s" % [EN[k3]["icon"], t("enchant." + str(k3))])
		var who := ("👤 " + sname(owner)) if owner != null else t("enchant.unequipped")
		info.add_child(emoji_row("%s · %s · %sG" % [who, " · ".join(cur) if not cur.is_empty() else t("enchant.none"), num(D["ENCHANT_FEE"])], 11, OKit.DIM2, 600))
		for cat2: String in ["def", "atk"]:
			var row2 := HFlowContainer.new()
			row2.name = "Opts_" + cat2
			row2.add_theme_constant_override("h_separation", 4)
			row2.add_theme_constant_override("v_separation", 4)
			var cl2 := OKit.label(10, OKit.GOLD, 800)
			cl2.text = t("enchant.cat_" + cat2)
			cl2.custom_minimum_size = Vector2(0, 30)
			cl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row2.add_child(cl2)
			var curk: Variant = it.get(D["ENCHANT_FIELD"][cat2])
			for k4: String in _kinds(cat2):
				var n2 := Sanc.rune_count(c, k4)
				var on := Js.same(curk, k4)
				var b := OKit.styled_button(OKit.box(Color(OKit.GOLD, 0.18) if on else Color(1, 1, 1, 0.05), OKit.GOLD if on else Color(1, 1, 1, 0.1), 6, 1, 3, 3),
					OKit.box(Color(1, 1, 1, 0.12), OKit.GOLD, 6, 1, 3, 3), null, 6)
				b.name = "Opt_" + k4
				b.custom_minimum_size = Vector2(34, 34)
				var ri := ItemView.icon(icons, "rune_" + k4, 26, str(EN[k4].get("icon", "")))
				ri.position = Vector2(4, 4)
				b.add_child(ri)
				b.tooltip_text = "%s (%d) — %s" % [t("enchant." + k4), n2, t("enchant.desc_" + k4)]
				b.disabled = n2 == 0 or on
				if b.disabled and not on:
					b.modulate.a = 0.35
				b.pressed.connect(ask_enchant.bind(str(it.get("eid", "")), k4))
				row2.add_child(b)
			info.add_child(row2)


func _kinds(cat: String) -> Array:
	var out: Array = []
	for k: String in (D["ENCHANTS"] as Dictionary).keys():
		if D["ENCHANTS"][k]["cat"] == cat:
			out.append(k)
	return out


## 룬 단추 → (골드 부족이면 알림) → 확인 창 → Rune.apply
func ask_enchant(eid: String, k: String) -> void:
	if modal_open() or not act_once():
		return
	var fee := float(D["ENCHANT_FEE"])
	if Sanc.gold(c) < fee:
		alert(t("enchant.no_gold", {"gold": num(fee)}))
		return
	var it: Variant = null
	for x: Dictionary in Sanc.enchant_items(c):
		if str(x.get("eid", "")) == eid:
			it = x
	if it == null:
		return
	var EN: Dictionary = D["ENCHANTS"]
	var cur: Variant = it.get(D["ENCHANT_FIELD"][EN[k]["cat"]])
	var msg := t("enchant.confirm", {"item": EquipRules.gear_name(it, _tw()), "e": "%s %s" % [EN[k]["icon"], t("enchant." + k)], "gold": num(fee)})
	if Js.truthy(cur) and EN.has(cur):
		msg += "\n" + t("enchant.overwrite", {"cur": "%s %s" % [EN[cur]["icon"], t("enchant." + str(cur))]})
	confirm(msg, func() -> void: do_enchant(eid, k))


func do_enchant(eid: String, k: String) -> void:
	if not act_once():
		return
	var r: Variant = Sanc.rune_apply(c, eid, k)
	after_change()
	if not (typeof(r) == TYPE_BOOL and r):
		alert(t("enchant.fail_" + str(r), {"gold": num(D["ENCHANT_FEE"])}))
