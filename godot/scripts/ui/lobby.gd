extends "res://scripts/ui/screen_base.gd"
## 로비 — 웹 index.html + js/index.js + js/common/commander.js + css/lobby.css
##  윗줄(제목 DEADLINE 15 · 톱니), 왼쪽 위 지휘관 단추(초상화 + 이름 → 지휘관 설정 다시 열기), 골드 배지,
##  클랜 아지트(횃불 6 · 원탁 · 레벨 높은 클랜원 최대 10명이 원탁 둘레에), 아래 단추(도감 · 출격 · 가이드), 아래 탭.
##  (4b-1) 전투 재개: Godot 저장 전투(gd_battle)면 이어하기, 웹이 만든 game_battle 이면 '이어할 수 없음' 안내 + 포기 (scripts/logic/resume_rules.gd)
##  (4b-2) 이전 판(저장 형식·데이터·게임 버전이 다른) Godot 전투도 '이어할 수 없음' 안내 + 포기. 정상 저장 전투는 단추 오른쪽 위 ✕ → 확인 창 → 포기
##  들어올 때 웹과 같은 순서: 첫 실행이면 클랜원 만들기 → 저장값 점검·복구(알림) → 지휘관 첫 설정 → 성별 보정 → 자동 부활(알림)
##  규칙은 scripts/logic/lobby_rules.gd. 도감·가이드 단추 → compendium · guide 화면 (4b-2)

const LobbyRules := preload("res://scripts/logic/lobby_rules.gd")
const SettingsRules := preload("res://scripts/logic/settings_rules.gd")
const ResumeRules := preload("res://scripts/logic/resume_rules.gd")
const Flow := preload("res://scripts/ui/flow.gd")

var cmd_btn: Button
var cmd_name: Label
var cmd_pt: Kit.Portrait
var gold_lbl: Label
var hideout: Hideout
var popups: BoxContainer
var _popup_labels: Dictionary = {}   # name → [Label, key]
var resume_btn: Button
## "gd" · "old" · "web" · "broken" · "" (ResumeRules.status)
var resume_status := ""
var _resuming := false
var abandon_btn: Button
var _abandoning := false
var cta: Button
var setup_dialog: Control
## 시험·확인용
var last_validate: Dictionary = {}
var revived: Array = []
var created_roster := false


func page_id() -> String:
	return "lobby"


func has_back() -> bool:
	return false


func title_text() -> String:
	return t("common.game_title")


## (6a) 휴대폰: 본문 세로(약 366)에 아지트 아래 단추 줄이 들어가지 않아, 단추 줄(도감·출격·가이드)을 아지트 오른쪽에 세로로 세움 —
##  아지트는 본문 높이 − 골드 배지 · 간격에 맞춤 (가로세로 비율은 PC 560:380 그대로). 단추·순서는 같음
func _fit_mobile() -> void:
	if hideout == null or not is_instance_valid(hideout) or popups == null:
		return
	var pw := popups.get_combined_minimum_size().x
	popups.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	popups.offset_left = -pw - 24.0
	popups.offset_right = -24.0
	popups.offset_top = 0.0
	popups.offset_bottom = 0.0
	var center := body.get_node_or_null("LobbyContent") as Control
	if center != null:
		center.offset_right = -pw - 24.0
	var h := clampf(body.size.y - 6.0 - 44.0 - 20.0, 180.0, 380.0)
	var w := minf(roundf(560.0 * h / 380.0), body.size.x - pw - 72.0)
	hideout.custom_minimum_size = Vector2(w, roundf(w * 380.0 / 560.0))


## (6a) 안드로이드 뒤로 단추 — 로비는 돌아갈 곳이 없으므로 게임 종료 확인 (열린 창이 있으면 screen_base 가 먼저 닫음)
var quit_asked := 0


func root_back() -> void:
	if setup_dialog != null and is_instance_valid(setup_dialog):
		return
	quit_asked += 1
	confirm(t("gd.mobile.quit_confirm"), func() -> void:
		if store != null:
			store.call("flush")
		get_tree().quit())


func _build() -> void:
	created_roster = LobbyRules.ensure_roster(c, names_total())
	last_validate = LobbyRules.validate_and_repair(c, names_total())
	# 지휘관 단추 (웹 .lobby-cmd-btn: 왼쪽 위)
	cmd_btn = OKit.styled_button(OKit.box(Color(15 / 255.0, 21 / 255.0, 32 / 255.0, 0.85), Color("2c3648"), 999, 1, 5, 5),
		OKit.box(Color(20 / 255.0, 28 / 255.0, 42 / 255.0, 0.95), OKit.GOLD, 999, 1, 5, 5), null, 999)
	cmd_btn.name = "CommanderBtn"
	cmd_btn.position = Vector2(16, 14)
	body.add_child(cmd_btn)
	var ch := OKit.hbox(8)
	OKit.set_content(cmd_btn, ch, Vector4(5, 5, 9, 5))
	cmd_pt = Kit.Portrait.new()
	cmd_pt.custom_minimum_size = Vector2(30, 30)
	cmd_pt.ring = Color("1e2a3a")
	cmd_pt.ring_w = 0.0
	cmd_pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(cmd_pt)
	cmd_name = OKit.label(14, OKit.TEXT, 700)
	ch.add_child(cmd_name)
	cmd_btn.pressed.connect(func() -> void: open_commander_setup(false))
	# 가운데: 골드 · 아지트
	var center := OKit.vbox(20)
	center.name = "LobbyContent"
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# (4b-2) 아지트가 아래 단추 줄(출격 등, 위 끝 −124) 위에서 끝나게 — 아래쪽 클랜원 이름표가 출격 단추와 겹치던 것
	center.offset_bottom = -128
	body.add_child(center)
	var gb := gold_badge("0 G")
	gb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(gb)
	gold_lbl = gb.find_child("Gold", true, false)
	hideout = Hideout.new()
	hideout.name = "Hideout"
	hideout.custom_minimum_size = Vector2(560, 380)
	hideout.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hideout.reduce_motion = bool(SettingsRules.load_settings(store).get("reduceMotion", false))
	center.add_child(hideout)
	if is_mobile_ui():
		# (6a) 휴대폰: 본문 높이(약 366)에 아지트를 맞춤 — 골드 배지 아래에서 본문 끝까지, 아래 단추 줄은 아지트 위에 얹힘
		center.offset_bottom = -6
		body.resized.connect(_fit_mobile)
		_fit_mobile.call_deferred()
	# 아래 단추 줄 (웹 .lobby-popups: 아래 20px, 가운데)
	popups = OKit.vbox(10) if is_mobile_ui() else OKit.hbox(12)   # (6a) 휴대폰은 아지트 오른쪽에 세로로 (_fit_mobile)
	popups.name = "Popups"
	popups.alignment = BoxContainer.ALIGNMENT_CENTER
	popups.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	popups.offset_top = -124
	popups.offset_bottom = -46
	popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(popups)
	if is_mobile_ui():
		popups.minimum_size_changed.connect(_fit_mobile)   # (6a QA 재검수) 이어하기 줄이 생기거나 글자가 바뀌어 열이 넓어지면 다시 맞춤
	# 전투 재개 (웹: 저장된 전투가 있으면 맨 앞에 단추)
	resume_status = ResumeRules.status(c)
	if resume_status != "":
		resume_btn = _popup_btn("Resume", "⚔️", "messages.resume_battle")
		resume_btn.pressed.connect(press_resume)
		if resume_status == "gd":
			_add_abandon_btn()
	var comp := _popup_btn("Compendium", "📖", "nav.compendium")
	comp.pressed.connect(func() -> void: router.call("go", "compendium"))
	cta = _cta_btn()
	cta.pressed.connect(func() -> void: router.call("go", "stage_select"))
	popups.add_child(cta)
	var guide := _popup_btn("Guide", "📚", "nav.guide")
	guide.pressed.connect(func() -> void: router.call("go", "guide"))
	# 저장값 점검 결과 알림 (웹: 0.5초 뒤 토스트)
	get_tree().create_timer(0.5).timeout.connect(_toast_validate)
	# 지휘관 첫 설정 → 그 뒤 성별 보정·자동 부활
	if LobbyRules.commander_needs_setup(c):
		open_commander_setup(true)
	LobbyRules.migrate_gender(c)
	revived = LobbyRules.auto_revive(c)
	if not revived.is_empty():
		get_tree().create_timer(1.2).timeout.connect(_alert_revived)
	cta.grab_focus.call_deferred()
	_data_warning()


## 전투 재개: Godot 저장이면 이어하기, 아니면 안내 + 포기 (같은 프레임 연타 → 한 번만)
func press_resume() -> void:
	if _resuming or not act_once():
		return
	resume_status = ResumeRules.status(c)
	if resume_status == "gd":
		var gd: Dictionary = ResumeRules.load_gd(c)
		_resuming = true
		router.call("launch_battle", Flow.resume_cfg(store, gd))
		return
	var msg := t("gd.resume.broken")
	if resume_status == "old":
		msg = t("gd.resume.old_notice")
	elif resume_status == "web":
		var st: Variant = ResumeRules.web_stage(c)
		var nm := ""
		if st is Dictionary:
			nm = str(st.get("name", "")) if st.get("name") != null else ""
			if st.get("id") != null and (typeof(st["id"]) == TYPE_INT or typeof(st["id"]) == TYPE_FLOAT):
				nm = "%s %s" % [t("gd.resume.stage_n", {"n": int(st["id"])}), nm]
		msg = t("gd.resume.web_notice", {"stage": nm.strip_edges()})
	open_modal(_msg_label(msg), {"name": "ResumeNotice", "title": t("messages.resume_battle"),
		"buttons": [{"text": t("gd.resume.abandon"), "cb": abandon_resume, "name": "Abandon"}, {"text": t("common.close"), "secondary": true, "name": "Close"}]})


## 전투 포기 → 저장 전투 지우고 단추 없앰 (이어할 수 없는 전투 · (4b-2) 정상 저장 전투도 확인 창 뒤에) — 한 번만
func abandon_resume() -> void:
	if resume_status == "" or _abandoning or _resuming:
		return
	_abandoning = true
	ResumeRules.abandon(c)
	resume_status = ""
	if resume_btn != null and is_instance_valid(resume_btn):
		resume_btn.queue_free()
		resume_btn = null
	if abandon_btn != null and is_instance_valid(abandon_btn):
		abandon_btn.queue_free()
	abandon_btn = null
	toast(t("gd.resume.abandoned"))
	cta.grab_focus.call_deferred()
	_abandoning = false


## (4b-2) 정상 저장 전투 포기 단추 (전투 재개 단추 오른쪽 위 ✕) → 확인 창
func _add_abandon_btn() -> void:
	# (6a QA) ✕ 는 '전투 재개' 단추 안이 아니라 그 위쪽 바깥(오른쪽 끝에 맞춤)에 둠 — 모바일의 44pt 최소 크기(큰 원)가 단추 글자를 덮던 것.
	#  PC·모바일 모두 단추와 겹치지 않고, ✕ 그림은 원 한가운데
	abandon_btn = OKit.styled_button(OKit.box(Color("1f2937"), Color(OKit.RED, 0.6), 999, 1, 0, 0), OKit.box(Color("7f1d1d"), OKit.RED, 999, 1, 0, 0), null, 999)
	abandon_btn.name = "AbandonBtn"
	abandon_btn.custom_minimum_size = Vector2(22, 22)
	var xi := OKit.vec_icon("close", 10, Color("fca5a5"))
	xi.set_anchors_preset(Control.PRESET_CENTER)
	xi.offset_left = -5
	xi.offset_right = 5
	xi.offset_top = -5
	xi.offset_bottom = 5
	xi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	abandon_btn.add_child(xi)
	abandon_btn.pressed.connect(ask_abandon)
	if is_mobile_ui():
		# (6a QA 재검수) 휴대폰: 이어하기 단추가 본문 맨 위라 위쪽 바깥에 두면 윗줄 밑으로 잘림 → 단추 오른쪽 옆에 같은 줄로 (단추 열이 조금 넓어짐)
		var row := OKit.hbox(6)
		row.name = "ResumeRow"
		var idx := resume_btn.get_index()
		popups.remove_child(resume_btn)
		popups.add_child(row)
		popups.move_child(row, idx)
		row.add_child(resume_btn)
		abandon_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(abandon_btn)
		return
	body.add_child(abandon_btn)
	resume_btn.resized.connect(_place_abandon)
	body.resized.connect(_place_abandon)
	popups.sort_children.connect(_place_abandon)
	_place_abandon.call_deferred()


func _place_abandon() -> void:
	if abandon_btn == null or not is_instance_valid(abandon_btn) or resume_btn == null or not is_instance_valid(resume_btn):
		return
	abandon_btn.reset_size()
	var sz := abandon_btn.get_combined_minimum_size()
	abandon_btn.size = sz
	var r := resume_btn.get_global_rect()
	var o := body.get_global_rect().position
	abandon_btn.position = Vector2(r.end.x - sz.x - o.x, r.position.y - sz.y - 4.0 - o.y)


func ask_abandon() -> void:
	if resume_status != "gd" or _resuming or _abandoning or modal_open() or not act_once():
		return
	var st: Variant = ResumeRules.gd_stage(c)
	var nm := ""
	if st is Dictionary and st.get("id") != null and (typeof(st["id"]) == TYPE_INT or typeof(st["id"]) == TYPE_FLOAT):
		nm = t("gd.resume.stage_n", {"n": int(st["id"])})
	elif st is Dictionary and st.get("daily") is Dictionary:
		nm = t("daily.title") if has_t("daily.title") else ""
	open_modal(_msg_label(t("gd.resume.abandon_confirm", {"stage": nm})), {"name": "AbandonConfirm", "title": t("gd.resume.abandon"),
		"buttons": [{"text": t("gd.resume.abandon"), "cb": abandon_resume, "name": "Abandon"}, {"text": t("common.cancel"), "secondary": true, "name": "Close"}]})


## (2026-10-18) 디버그 빌드: 데이터가 manifest 와 어긋나면(JSON 을 고치고 data_tool --write 를 잊음 등) 위쪽에 빨간 띠 — 개발자만 보는 글이라 번역하지 않음
func _data_warning() -> void:
	var db: Node = get_node_or_null("/root/DataDB")
	if not OS.is_debug_build() or db == null or (db.get("errors") as PackedStringArray).is_empty():
		return
	var errs: PackedStringArray = db.get("errors")
	var p := PanelContainer.new()
	p.name = "DataWarning"
	p.add_theme_stylebox_override("panel", OKit.box(Color(0.6, 0.05, 0.05, 0.92), Color("f87171"), 8, 2, 14, 8))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	p.offset_top = 60
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := OKit.label(13, Color.WHITE, 700)
	l.text = "[DEV] 데이터 오류 %d개%s — godot/data 를 고쳤다면 tools/data_tool.gd -- --write\n%s" % [errs.size(),
		" · 이 실행에서는 전투 이어하기 안 함 (데이터 해시 무효)" if bool(db.get("sha_mismatch")) else "", errs[0].left(160)]
	p.add_child(l)
	body.add_child(p)


## (타이머) 저장값 점검 결과 알림 — 화면이 이미 바뀌었으면 연결이 저절로 끊김 (메서드 연결)
## (6a QA) 알림이 아래 단추 줄(도감·출격·가이드)을 덮지 않게 그 줄 위에 — 모바일은 단추가 오른쪽 세로 열이라 아래쪽 가운데
func toast_y(vs: Vector2, h: float) -> float:
	var bottom := body.get_global_rect().end.y if body != null else vs.y - 64.0
	if is_mobile_ui():
		return bottom - h - 10.0
	return bottom - 124.0 - h - 8.0


func _toast_validate() -> void:
	var rep: bool = last_validate.get("repaired", false)
	toast(("⚠ " + t("messages.data_repaired")) if rep else ("✓ " + t("messages.data_ok")), "warn" if rep else "ok")


func _alert_revived() -> void:
	var names: Array = []
	for r: Dictionary in revived:
		names.append(char_name(r))
	alert(t("messages.auto_revive", {"name": ", ".join(names)}))


func _popup_btn(nm: String, emoji: String, key: String) -> Button:
	var b := OKit.styled_button(OKit.box(Color(OKit.GOLD, 0.08), Color(OKit.GOLD, 0.3), 10, 2, 6, 6),
		OKit.box(Color(OKit.GOLD, 0.16), Color(OKit.GOLD, 0.6), 10, 2, 6, 6), null, 10)
	b.name = nm
	b.custom_minimum_size = Vector2(70, 70)
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	var v := OKit.vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	OKit.set_content(b, v, Vector4(6, 6, 6, 6))
	var ic := OKit.tex_rect(emoji_tex(emoji), Vector2(28, 28))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := OKit.label(11, Color(1, 1, 1, 0.7), 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	_popup_labels[nm] = [l, key]
	b.mouse_entered.connect(func() -> void: l.add_theme_color_override("font_color", OKit.GOLD))
	b.mouse_exited.connect(func() -> void: l.add_theme_color_override("font_color", Color(1, 1, 1, 0.7)))
	popups.add_child(b)
	return b


## 출격 (웹 .lobby-cta: 금빛 그라디언트 120×78, 숨쉬는 빛)
func _cta_btn() -> Button:
	var n := OKit.box(Color("f0c040"), Color("f5d060"), 14, 2, 6, 6)
	n.shadow_color = Color(OKit.GOLD, 0.35)
	n.shadow_size = 14
	var h := OKit.box(Color("ffd85c"), Color("ffe28a"), 14, 2, 6, 6)
	h.shadow_color = Color(OKit.GOLD, 0.5)
	h.shadow_size = 20
	var b := OKit.styled_button(n, h, OKit.box(Color("d8a62a"), Color("f5d060"), 14, 2, 6, 6), 14)
	b.name = "Sortie"
	b.custom_minimum_size = Vector2(120, 78)
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	var v := OKit.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	OKit.set_content(b, v, Vector4(8, 6, 8, 6))
	var ic := OKit.tex_rect(emoji_tex("⚔️"), Vector2(26, 26))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := OKit.label(16, Color("1a1206"), 900)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	_popup_labels["Sortie"] = [l, "nav.sortie"]
	return b


func _refresh() -> void:
	gold_lbl.text = "%s G" % grouped(LobbyRules.gold(c))   # 상점·성소·아카데미와 같은 천 단위 쉼표 (웹 상점·성소 toLocaleString)
	for nm: String in _popup_labels.keys():
		var pl: Array = _popup_labels[nm]
		(pl[0] as Label).text = t(pl[1])
	if resume_btn != null:
		resume_btn.tooltip_text = t("messages.resume_battle")
	if abandon_btn != null and is_instance_valid(abandon_btn):
		abandon_btn.tooltip_text = t("gd.resume.abandon")
	_refresh_commander()
	hideout.set_chars(LobbyRules.hideout_chars(c), self)


func _refresh_commander() -> void:
	var ch: Variant = LobbyRules.commander(c)
	cmd_btn.visible = ch != null
	if ch == null:
		return
	cmd_btn.tooltip_text = t("commander_setup.edit")
	cmd_name.text = LobbyRules.commander_display_name(c, default_commander_name())
	cmd_pt.set_unit(icons.call("portrait_tex", "commander", str(ch.get("gender", "m"))), false)
	cmd_btn.reset_size()


## commander.js defaultName: 언어 팩 commander_setup.default_name → 없으면 COMMANDER_DEFAULT_NAME
func default_commander_name() -> String:
	return t("commander_setup.default_name") if has_t("commander_setup.default_name") else str(D["COMMANDER_DEFAULT_NAME"])


# ═══════════ 지휘관 설정 (commander.js open) ═══════════

var _setup_gender := "m"
var _setup_cards: Dictionary = {}
var setup_input: LineEdit


func open_commander_setup(first: bool) -> void:
	var ch: Variant = LobbyRules.commander(c)
	if ch == null or (setup_dialog != null and is_instance_valid(setup_dialog)):
		return
	_setup_gender = str(ch.get("gender", "m"))
	var v := OKit.vbox(0)
	v.name = "CommanderSetup"
	var title := OKit.label(22, Color("f5c45a"), 800)
	title.text = t("commander_setup.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := OKit.label(13, Color("94a3b8"), 500)
	sub.text = t("commander_setup.sub")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	v.add_child(gap)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	v.add_child(grid)
	_setup_cards.clear()
	for g: String in ["m", "f"]:
		var b := OKit.styled_button(OKit.box(Color("0f1520"), Color("2c3648"), 12, 2, 6, 8), OKit.box(Color("131b29"), Color("f59e0b"), 12, 2, 6, 8), null, 12)
		b.name = "Card_" + g
		b.custom_minimum_size = Vector2(190, 200)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := OKit.vbox(4)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		OKit.set_content(b, cv, Vector4(6, 8, 6, 10))
		var img := OKit.tex_rect(icons.call("image", "character/commander_0%d.png" % (1 if g == "m" else 2)), Vector2(150, 150))
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(img)
		var gl := OKit.label(16, Color("cbd5e1"), 700)
		gl.text = t("commander_setup." + ("male" if g == "m" else "female"))
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(gl)
		b.pressed.connect(func() -> void:
			_setup_gender = g
			_paint_setup_cards())
		grid.add_child(b)
		_setup_cards[g] = [b, gl]
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 16)
	v.add_child(gap2)
	var nr := OKit.hbox(10)
	v.add_child(nr)
	var nl := OKit.label(13, Color("94a3b8"), 500)
	nl.text = t("commander_setup.name")
	nr.add_child(nl)
	setup_input = LineEdit.new()
	setup_input.name = "NameInput"
	# 웹 <input maxlength="10"> 은 UTF-16 단위로 셈 → 글자 수가 아니라 같은 단위로 자름
	setup_input.text_changed.connect(func(tx: String) -> void:
		if LobbyRules.utf16_len(tx) > LobbyRules.NAME_LEN:
			var col := setup_input.caret_column
			setup_input.text = LobbyRules.utf16_slice(tx, LobbyRules.NAME_LEN)
			setup_input.caret_column = mini(col, setup_input.text.length()))
	setup_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_input.custom_minimum_size = Vector2(0, 42)
	setup_input.placeholder_text = t("commander_setup.name_ph")
	setup_input.text = str(ch["customName"]) if Js.truthy(ch.get("setup")) and Js.truthy(ch.get("customName")) else default_commander_name()
	setup_input.add_theme_font_size_override("font_size", 15)
	setup_input.add_theme_font_override("font", Kit.bold(500))
	setup_input.add_theme_stylebox_override("normal", OKit.box(Color("0b111b"), Color("2c3648"), 8, 1, 12, 8))
	setup_input.add_theme_stylebox_override("focus", OKit.box(Color("0b111b"), Color("f59e0b"), 8, 1, 12, 8))
	setup_input.text_submitted.connect(func(_s: String) -> void: commander_setup_done())
	nr.add_child(setup_input)
	var gap3 := Control.new()
	gap3.custom_minimum_size = Vector2(0, 16)
	v.add_child(gap3)
	var ok := OKit.styled_button(OKit.box(Color("e89a22"), Color(0, 0, 0, 0), 10, 0, 12, 12), OKit.box(Color("f5b03a"), Color(0, 0, 0, 0), 10, 0, 12, 12), null, 10)
	ok.name = "Confirm"
	ok.text = t("commander_setup.confirm")
	ok.add_theme_font_size_override("font_size", 16)
	ok.add_theme_font_override("font", Kit.bold(800))
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		ok.add_theme_color_override(k, Color("1b1206"))
	ok.pressed.connect(commander_setup_done)
	v.add_child(ok)
	_paint_setup_cards()
	var sb := OKit.box(Color("141b29"), Color("2c3648"), 16, 1, 20, 22)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 30
	# 웹 commander.js 는 처음이든 다시 열었든 닫는 길이 없음(확인으로만). Godot: 첫 설정은 웹처럼 닫을 수 없고,
	#  로비 단추로 다시 열었을 때만 Esc·바깥 누르기로 닫힘 (바꾸지 않고 나가기 — README '웹판과 다른 점')
	setup_dialog = open_modal(v, {"name": "CommanderDialog", "width": 480.0, "box": sb, "close_on_bg": not first, "no_esc": first})
	if not is_mobile_ui():   # (6a) 휴대폰은 창이 열리자마자 키보드가 화면을 덮지 않게 — 누르면 입력
		setup_input.grab_focus.call_deferred()
	setup_input.select_all.call_deferred()


func _paint_setup_cards() -> void:
	for g: String in _setup_cards.keys():
		var on := g == _setup_gender
		var b: Button = _setup_cards[g][0]
		var nb := OKit.box(Color("0f1520"), Color("f59e0b") if on else Color("2c3648"), 12, 2, 6, 8)
		if on:
			nb.shadow_color = Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.25)
			nb.shadow_size = 12
		b.add_theme_stylebox_override("normal", nb)
		(_setup_cards[g][1] as Label).add_theme_color_override("font_color", Color("f5c45a") if on else Color("cbd5e1"))


func commander_setup_pick(g: String) -> void:
	_setup_gender = g
	_paint_setup_cards()


## 확인 (Enter 도): 이름 다듬기(앞뒤 공백·10자·비면 기본 이름) → 성별·이름·setup 저장
func commander_setup_done() -> void:
	if setup_dialog == null or not is_instance_valid(setup_dialog):
		return
	LobbyRules.commander_apply(c, _setup_gender, setup_input.text, default_commander_name())
	_close_modal_node(setup_dialog, false)
	setup_dialog = null
	_refresh()
	cta.grab_focus.call_deferred()


# ═══════════ 클랜 아지트 (웹 .clan-hideout · renderHideout) ═══════════

class Hideout extends Control:
	const OK2 := preload("res://scripts/ui/outer_kit.gd")
	var reduce_motion := false
	var _t := 0.0
	var _units: Array = []    # [{node, ang, phase, icon}]
	var _start := 0.0
	const TORCHES := [[0.08, 0.5, 0.0], [0.92, 0.5, 0.7], [0.10, 0.14, 0.3], [0.90, 0.14, 0.5], [0.10, 0.88, 0.4], [0.90, 0.88, 0.6]]

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(_place)

	func set_chars(chars: Array, scr: Control) -> void:
		for u: Dictionary in _units:
			(u["node"] as Node).queue_free()
		_units.clear()
		_start = randf() * TAU
		var n := chars.size()
		for i in n:
			var ch: Dictionary = chars[i]
			var wrap := VBoxContainer.new()
			wrap.add_theme_constant_override("separation", 0)
			wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wrap.name = "Unit%d" % i
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(56, 56)
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			wrap.add_child(holder)
			var icon := TextureRect.new()
			icon.texture = scr.get("icons").call("char_tex", str(ch["cls"]), str(ch.get("gender", "m")))
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.size = Vector2(48, 54)
			icon.position = Vector2(4, 0)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(icon)
			var sh := Panel.new()   # 웹 .hu-shadow (28×6 타원 그림자)
			sh.custom_minimum_size = Vector2(28, 6)
			sh.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sh.add_theme_stylebox_override("panel", OK2.box(Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), 3, 0, 0, 0))
			wrap.add_child(sh)
			var nm := PanelContainer.new()
			nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			nm.add_theme_stylebox_override("panel", OK2.box(Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.72), Color(OK2.GOLD, 0.22), 999, 1, 7, 1))
			nm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var rl := RichTextLabel.new()
			rl.bbcode_enabled = true
			rl.fit_content = true
			rl.autowrap_mode = TextServer.AUTOWRAP_OFF
			rl.scroll_active = false
			rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rl.add_theme_font_size_override("normal_font_size", 13)
			rl.add_theme_font_size_override("bold_font_size", 13)
			rl.add_theme_font_override("normal_font", OK2.Kit.bold(700))
			rl.add_theme_font_override("bold_font", OK2.Kit.bold(900))
			rl.add_theme_color_override("default_color", Color("e5e7eb"))
			rl.text = "[b][color=#f0c040]Lv.%s[/color][/b] %s" % [scr.call("num", ch.get("lv", 1)), str(scr.call("char_name", ch)).replace("[", "[lb]")]
			rl.name = "Name"
			nm.add_child(rl)
			wrap.add_child(nm)
			add_child(wrap)
			_units.append({"node": wrap, "ang": _start + float(i) / float(n) * TAU, "phase": randf() * 2.4, "icon": icon})
		_place()

	func _place() -> void:
		for u: Dictionary in _units:
			var w: Control = u["node"]
			var ang: float = u["ang"]
			var cx := size.x * (0.5 + cos(ang) * 0.34)
			var cy := size.y * (0.52 + sin(ang) * 0.33)
			w.reset_size()
			var ms := w.get_combined_minimum_size()
			w.size = ms
			# 아지트 밖으로 나가지 않게 (긴 이름표)
			w.position = (Vector2(cx, cy) - ms * 0.5).clamp(Vector2(2, 2), (size - ms - Vector2(2, 2)).max(Vector2(2, 2)))
			u["cy"] = cy
		# 아래쪽 클랜원일수록 앞에 (웹 z-index 5 + cy%) — z_index 대신 그리는 순서로 (창이 아지트 위에 오도록)
		var order := _units.duplicate()
		order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["cy"]) < float(b["cy"]))
		for i in order.size():
			move_child(order[i]["node"], i)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if reduce_motion:
			return
		for u: Dictionary in _units:
			var ph := (_t + float(u["phase"])) / 2.4 * TAU
			(u["icon"] as Control).position.y = -1.5 + cos(ph) * 1.5 - 1.5

	func _draw() -> void:
		var s := size
		var r := Rect2(Vector2.ZERO, s)
		# 바닥: 위 #12100e → 아래 #2a1f15 (세로), 24px 마다 옅은 세로 줄, 가운데 주황 빛
		var top := Color("12100e")
		var bot := Color("2a1f15")
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(0, s.y)]), PackedColorArray([top, top, bot, bot]))
		var x := 0.0
		while x < s.x:
			draw_line(Vector2(x, 0), Vector2(x, s.y), Color(1, 1, 1, 0.02), 1.0)
			x += 24.0
		var ctr := s * 0.5
		for i in 12:
			var k := 1.0 - float(i) / 12.0
			draw_circle(ctr, maxf(s.x, s.y) * 0.3 * k + 4.0, Color(1.0, 0.63, 0.16, 0.012 * (1.0 + k)))
		# 양옆·위 그늘 (::before)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.15, 0), Vector2(s.x * 0.15, s.y), Vector2(0, s.y)]), PackedColorArray([Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.35)]))
		draw_polygon(PackedVector2Array([Vector2(s.x * 0.85, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x * 0.85, s.y)]), PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0)]))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.4), Vector2(0, s.y * 0.4)]), PackedColorArray([Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		# 횃불 6개 (깜빡임)
		for tc: Array in TORCHES:
			var p := Vector2(s.x * float(tc[0]), s.y * float(tc[1]))
			var f := 0.85 if reduce_motion else 0.8 + 0.2 * sin((_t + float(tc[2])) / 1.5 * PI * 2.0)
			for j in 6:
				draw_circle(p, 10.0 + j * 4.0, Color(1.0, 0.55, 0.16, 0.035 * f))
			draw_set_transform(p, 0.0, Vector2(1.0, 3.0 * (0.9 + 0.2 * f) / 1.0))
			draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.6, 0.13, f))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 원탁 (140px, 갈색 원형 그라디언트 + 테두리)
		var tr := 70.0 if s.x >= 420.0 else 52.0
		draw_circle(ctr + Vector2(0, 8), tr + 6.0, Color(0, 0, 0, 0.35))
		draw_circle(ctr, tr, Color("3d2817"))
		for i in 10:
			var k := float(i) / 10.0
			draw_circle(ctr + Vector2(-tr * 0.4, -tr * 0.4) * k, (tr - 3.0) * (1.0 - k * 0.55), Color("5c4a2f").lerp(Color("8b6f47"), k))
		# 테두리 (웹 border:1px rgba(255,255,255,.08), radius 14)
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = Color(1, 1, 1, 0.08)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(14)
		draw_style_box(sb, r)
