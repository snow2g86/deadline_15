extends "res://scripts/ui/screen_base.gd"
## 스테이지 선택 — 웹 stage-select.html + js/stage-select.js + css/stage-select.css + story.js(beforeStage · openReplay)
##  에피소드 목록(전체 진행도 · 요일 던전 입구 · 스토리 다시 보기 · 에피소드 카드: 잠김/진행 중/완료, 별, 진행 막대)
##  → 스테이지 목록(EP.x-y · 별 · CLEAR/NEXT/잠김 · 권장 레벨 · 보스 · 상세 정보)
##  스테이지 고르기 → 출전 전 스토리(에피소드 프롤로그 → 스테이지 pre, 본 것은 건너뜀) → 5명이면 바로 전투, 아니면 편성 화면
##  상세 정보 창: 별 조건 · 적 구성 · 환경 · 권장 전략 · (클리어했으면) 연습 모드.  요일 던전 창: 오늘 직업 · 난이도 · 남은 입장.
##  뒤로: 스테이지 목록 → 에피소드 목록 → 로비 (웹 goBack). Router params {daily: true} 면 요일 던전 창을 바로 엶 (요일 던전 전투 뒤)
##  규칙은 scripts/logic/progress_rules.gd · party_rules.gd

const ProgressRules := preload("res://scripts/logic/progress_rules.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const Hazards := preload("res://scripts/logic/hazards.gd")
const StoryBattle := preload("res://scripts/battle/story_battle.gd")
const StoryView := preload("res://scripts/battle/story_view.gd")
const UnitInfo := preload("res://scripts/battle/unit_info.gd")
const Flow := preload("res://scripts/ui/flow.gd")

var view_mode := "episodes"   # episodes | stages
var selected_ep := 0
var subtitle: Label
var scroll: ScrollContainer
var list: VBoxContainer
var story_view: Control
var story: Object   # StoryBattle (대본·화자·본 장면)
var info: Object    # UnitInfo (보스 이름·환경 설명)
var _starting := false
var _launched := false
var _daily_cls := ""
var _story_queue: Array = []
var _story_cur: Dictionary = {}
var _story_done: Callable = Callable()
## 시험용: 마지막 출격 결과 { to, nav } · 재생한 장면 키
var last_launch: Dictionary = {}
var story_log: Array = []
var cards: Dictionary = {}   # "ep:N" / "st:N" → Button


func page_id() -> String:
	return "stage"


func title_text() -> String:
	if view_mode == "stages":
		return "EP.%d %s" % [selected_ep, t("episode.%d.name" % selected_ep)]
	return t("stage.select_episode")


## Router 기록에 남길 상태 (설정 등을 다녀와도 고른 에피소드 유지)
func history_state() -> Dictionary:
	return {"ep": selected_ep} if view_mode == "stages" else {}


func busy() -> bool:
	return story_view != null and bool(story_view.get("active"))


func go_back() -> void:
	if view_mode == "stages":
		view_mode = "episodes"
		selected_ep = 0
		_refresh_chrome()
		_refresh()
	else:
		router.call("go", "lobby")


func _build() -> void:
	info = UnitInfo.new(D, i18n)
	var v := OKit.vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(v)
	subtitle = OKit.label(15, OKit.DIM, 500)
	subtitle.name = "Subtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.custom_minimum_size = Vector2(0, 54)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(subtitle)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	v.add_child(scroll)
	var mw := OKit.MaxWidth.new()
	mw.max_w = 492.0
	mw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(mw)
	list = OKit.vbox(14)
	list.name = "List"
	mw.add_child(list)
	story_view = StoryView.new()
	story_view.call("setup")
	story_view.connect("closed", _on_story_closed)
	add_child(story_view)
	if router != null:
		# 기록에서 돌아왔으면 고른 에피소드 그대로 (history_state), 요일 던전 창은 한 번만 (consume)
		var ep := int(Js.num((router.get("params") as Dictionary).get("ep", 0)))
		if ep > 0:
			selected_ep = ep
			view_mode = "stages"
		if Js.truthy(router.call("consume", "daily")):
			open_daily.call_deferred()


func _refresh() -> void:
	for ch: Node in list.get_children():
		list.remove_child(ch)
		ch.queue_free()
	cards.clear()
	if view_mode == "stages":
		_render_stages()
	else:
		_render_episodes()
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 24)
	list.add_child(pad)
	_focus_first.call_deferred()


func _focus_first() -> void:
	if modal_open() or busy():
		return
	for k: String in cards.keys():
		var b: Button = cards[k]
		if is_instance_valid(b) and not b.disabled and (b.get_meta("next", false) or b.get_meta("current", false)):
			b.grab_focus()
			return


# ═══════════ 에피소드 목록 ═══════════

func _render_episodes() -> void:
	var tp := ProgressRules.total_progress(c)
	subtitle.text = t("stage.total_progress", {"n": tp["n"], "total": tp["total"]})
	# 요일 던전 입구
	var date := local_date()
	var classes := ProgressRules.daily_classes(c, int(date["weekday"]))
	var cls_txt := t("daily.all_classes")
	if classes.size() <= 6:
		var nm: Array = []
		for cl: String in classes:
			nm.append(t("classes." + cl))
		cls_txt = "·".join(nm)
	var de := OKit.styled_button(OKit.box(Color(56 / 255.0, 189 / 255.0, 248 / 255.0, 0.12), Color(56 / 255.0, 189 / 255.0, 248 / 255.0, 0.35), 12, 1, 12, 10),
		OKit.box(Color(56 / 255.0, 189 / 255.0, 248 / 255.0, 0.18), Color("38bdf8"), 12, 1, 12, 10), null, 12)
	de.name = "DailyEntry"
	de.custom_minimum_size = Vector2(0, 60)
	var dh := OKit.hbox(10)
	OKit.set_content(de, dh, Vector4(12, 8, 12, 8))
	dh.add_child(OKit.tex_rect(emoji_tex("💠"), Vector2(26, 26)))
	var dv := OKit.vbox(0)
	dv.alignment = BoxContainer.ALIGNMENT_CENTER
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(dv)
	var dt := OKit.label(14, Color("e0f2fe"), 800)
	dt.text = t("daily.title")
	dv.add_child(dt)
	var ds := OKit.label(11, Color("94a3b8"), 500)
	ds.text = t("daily.today", {"classes": cls_txt})
	ds.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ds.clip_text = true
	dv.add_child(ds)
	var dl := OKit.label(11, Color("7dd3fc"), 700)
	dl.text = t("daily.left", {"n": ProgressRules.daily_left(c, date), "max": D["DAILY"]["perDay"]})
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(dl)
	de.pressed.connect(open_daily)
	list.add_child(de)
	# 스토리 다시 보기 (본 장면이 있을 때만)
	var seen: Variant = store.call("get_json", StoryBattle.SEEN_KEY, {})
	if seen is Dictionary and not (seen as Dictionary).is_empty():
		var rb := OKit.styled_button(OKit.box(Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.08), Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.4), 999, 1, 18, 7),
			OKit.box(Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.18), Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.6), 999, 1, 18, 7), null, 999)
		rb.name = "StoryReplay"
		rb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var rh := OKit.hbox(6)
		rh.alignment = BoxContainer.ALIGNMENT_CENTER
		OKit.set_content(rb, rh, Vector4(18, 7, 18, 7))
		rh.add_child(OKit.tex_rect(emoji_tex("📜"), Vector2(18, 18)))
		var rl := OKit.label(13, Color("fbbf24"), 700)
		rl.text = t("story.replay")
		rh.add_child(rl)
		rb.pressed.connect(open_replay)
		list.add_child(rb)
	for ep: Dictionary in ProgressRules.episodes(c):
		list.add_child(_episode_card(ep))


func _card_box(border: Color, glow: float = 0.0, bg: Color = Color(1, 1, 1, 0.045)) -> StyleBoxFlat:
	var s := OKit.box(bg, border, 14, 2, 26, 22)
	if glow > 0.0:
		s.shadow_color = Color(OKit.GOLD, glow)
		s.shadow_size = 12
	return s


func _episode_card(ep: Dictionary) -> Button:
	var id := int(ep["id"])
	var border := Color(OKit.GOLD, 0.15)
	var glow := 0.0
	if ep["done"]:
		border = Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.4)
	elif ep["current"]:
		border = Color(OKit.GOLD, 0.55)
		glow = 0.12
	if not ep["unlocked"]:
		border = Color(OKit.GOLD, 0.12)
	var b := OKit.styled_button(_card_box(border, glow), _card_box(OKit.GOLD, 0.12), null, 14)
	b.name = "Ep%d" % id
	b.disabled = not ep["unlocked"]
	b.set_meta("current", ep["current"])
	cards["ep:%d" % id] = b
	var v := OKit.vbox(6)
	OKit.set_content(b, v, Vector4(26, 20, 26, 20))
	var h := OKit.hbox(8)
	v.add_child(h)
	var num_l := OKit.label(22, OKit.GOLD if ep["unlocked"] else OKit.DIM2, 900)
	num_l.text = "EP.%d" % id
	h.add_child(num_l)
	h.add_child(OKit.spacer())
	var tag: Control
	if not ep["unlocked"]:
		tag = _tag_with_icon("lock", t("stage.unlock_after", {"ep": id - 1}), Color("cbd5e1"), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.15))
	elif ep["done"]:
		tag = OKit.pill("✓ " + t("stage.ep_done"), 11, Color("4ade80"), Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.12), Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.35))
	else:
		tag = _tag_with_icon("play", t("stage.ep_current"), Color("1a1206"), OKit.GOLD, Color(0, 0, 0, 0))
	tag.name = "Tag"
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tag)
	var st := OKit.label(14, Color("facc15"), 700)
	st.text = "★ %d/%d" % [ep["stars"], ep["max_stars"]]
	h.add_child(st)
	var pr := OKit.label(14, OKit.DIM, 700)
	pr.text = "%d/%d" % [ep["clear_count"], ep["count"]]
	h.add_child(pr)
	var nm := OKit.label(18, OKit.TEXT, 900)
	nm.text = t("episode.%d.name" % id)
	v.add_child(nm)
	var ds := OKit.label(13, OKit.DIM, 500)
	ds.text = t("episode.%d.desc" % id)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ds)
	var bar := Kit.Bar.new()
	bar.custom_minimum_size = Vector2(0, 5)
	bar.radius = 2.0
	bar.track = Color(1, 1, 1, 0.08)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ratio := float(ep["clear_count"]) / maxf(1.0, float(ep["count"]))
	if ep["done"]:
		bar.set_value(ratio, Color("16a34a"), Color("4ade80"))
	else:
		bar.set_value(ratio, OKit.GOLD, Color("d4a017"))
	v.add_child(bar)
	if not ep["unlocked"]:
		b.modulate = Color(0.62, 0.62, 0.66, 0.6)
	b.pressed.connect(func() -> void: open_episode(id))
	return b


## 아이콘 + 글 알약 (잠김 🔒 · 진행 중 ▶)
func _tag_with_icon(kind: String, text: String, fg: Color, bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", OKit.box(bg, border, 999, 1, 8, 2))
	var h := OKit.hbox(4)
	p.add_child(h)
	h.add_child(OKit.vec_icon(kind, 11, fg))
	var l := OKit.label(11, fg, 800)
	l.text = text
	h.add_child(l)
	return p


func open_episode(id: int) -> void:
	selected_ep = id
	view_mode = "stages"
	_refresh_chrome()
	_refresh()
	scroll.scroll_vertical = 0


# ═══════════ 스테이지 목록 ═══════════

func _render_stages() -> void:
	subtitle.text = t("stage.subtitle")
	for sv: Dictionary in ProgressRules.stages_of(c, selected_ep):
		list.add_child(_stage_card(sv))


func _stage_card(sv: Dictionary) -> Button:
	var id := int(sv["id"])
	var st: Dictionary = ProgressRules.find_stage(c, id)
	var border := Color(OKit.GOLD, 0.15)
	var bg := Color(1, 1, 1, 0.045)
	var glow := 0.0
	if sv["cleared"]:
		border = Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.45)
		bg = Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.06)
	if sv["next"]:
		border = OKit.GOLD
		glow = 0.18
	if sv["boss"] and not sv["cleared"]:
		bg = Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.07)
	var b := OKit.styled_button(_card_box(border, glow, bg), _card_box(OKit.GOLD, 0.12, bg), null, 14)
	b.name = "Stage%d" % id
	b.disabled = not sv["unlocked"]
	b.set_meta("next", sv["next"])
	cards["st:%d" % id] = b
	var v := OKit.vbox(8)
	OKit.set_content(b, v, Vector4(26, 20, 26, 20))
	var h := OKit.hbox(8)
	v.add_child(h)
	var nl := OKit.label(22, OKit.GOLD if sv["unlocked"] else OKit.DIM, 900)
	nl.text = "EP.%d-%d" % [selected_ep, sv["idx"]]
	h.add_child(nl)
	h.add_child(OKit.spacer())
	if sv["cleared"]:
		var stars := OKit.hbox(1)
		stars.name = "Stars"
		for f: Variant in sv["flags"]:
			var sl := OKit.label(14, Color("facc15") if Js.truthy(f) else Color(1, 1, 1, 0.18), 900)
			sl.text = "★"
			stars.add_child(sl)
		stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(stars)
	var badge: Control = null
	if sv["cleared"]:
		badge = OKit.pill("✓ CLEAR", 10, Color("4ade80"), Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.12), Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.35), 900)
	elif sv["next"]:
		badge = OKit.pill("NEXT", 10, Color("1a1206"), OKit.GOLD, Color(0, 0, 0, 0), 900)
	elif not sv["unlocked"]:
		badge = OKit.vec_icon("lock", 13, OKit.DIM2)
	if badge != null:
		badge.name = "Badge"
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(badge)
	var rl := OKit.label(11, OKit.DIM, 500)
	rl.text = t("stage.recommended_level", {"level": st.get("recommendedLevel", 1)})
	rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(rl)
	var nm := OKit.label(18, OKit.TEXT, 900)
	nm.text = t("stages.stage_%d_name" % id)
	v.add_child(nm)
	if Js.truthy(st.get("boss")) and Js.truthy(st["boss"].get("name")):
		var bt := PanelContainer.new()
		bt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bt.add_theme_stylebox_override("panel", OKit.box(Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.12), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.3), 6, 1, 8, 2))
		bt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var bh := OKit.hbox(4)
		bt.add_child(bh)
		bh.add_child(OKit.tex_rect(emoji_tex("💀"), Vector2(14, 14)))
		var bl := OKit.label(11, Color("fca5a5"), 800)
		bl.text = info.call("boss_name", st)
		bh.add_child(bl)
		bt.name = "Boss"
		v.add_child(bt)
	var ib := OKit.ghost_button("", 11)
	ib.name = "Info"
	ib.disabled = not sv["unlocked"]
	ib.custom_minimum_size = Vector2(0, 30)
	var ih := OKit.hbox(4)
	ih.alignment = BoxContainer.ALIGNMENT_CENTER
	OKit.set_content(ib, ih, Vector4(8, 4, 8, 4))
	ih.add_child(OKit.vec_icon("info", 13, Color("60a5fa")))
	var il := OKit.label(11, OKit.TEXT, 600)
	il.text = t("stage.info")
	ih.add_child(il)
	ib.pressed.connect(func() -> void: show_stage_info(id))
	v.add_child(ib)
	if not sv["unlocked"]:
		b.modulate = Color(0.6, 0.6, 0.64, 0.5)
	b.pressed.connect(func() -> void: start_stage(id, false))
	return b


# ═══════════ 상세 정보 (showStageInfo) ═══════════

func show_stage_info(id: int) -> void:
	var st: Variant = ProgressRules.find_stage(c, id)
	if st == null:
		return
	var v := OKit.vbox(10)
	v.name = "StageInfo"
	var ht := OKit.hbox(12)
	v.add_child(ht)
	var n1 := OKit.label(24, OKit.GOLD, 900)
	n1.text = ProgressRules.info_label(id)
	ht.add_child(n1)
	ht.add_child(OKit.spacer())
	var rl := OKit.label(12, OKit.DIM, 500)
	rl.text = t("stage.recommended_level_full", {"level": st.get("recommendedLevel", 1)})
	rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ht.add_child(rl)
	var sn := OKit.label(16, OKit.TEXT, 900)
	sn.text = t("stages.stage_%d_name" % id)
	sn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sn)
	var dv := OKit.divider(0.1)
	dv.custom_minimum_size.y = 2
	v.add_child(dv)
	if Js.truthy(st.get("boss")):
		var bp := PanelContainer.new()
		bp.add_theme_stylebox_override("panel", OKit.box(Color(220 / 255.0, 38 / 255.0, 38 / 255.0, 0.1), Color(220 / 255.0, 38 / 255.0, 38 / 255.0, 0.3), 8, 1, 12, 12))
		var bv := OKit.vbox(2)
		bp.add_child(bv)
		var blh := OKit.hbox(4)
		bv.add_child(blh)
		blh.add_child(OKit.tex_rect(emoji_tex("💀"), Vector2(13, 13)))
		var bl := OKit.label(11, Color("ef4444"), 700)
		bl.text = t("stage.boss")
		blh.add_child(bl)
		var bn := OKit.label(15, OKit.TEXT, 900)
		bn.text = info.call("boss_name", st)
		bv.add_child(bn)
		var bch := OKit.hbox(4)
		bv.add_child(bch)
		bch.add_child(cls_icon(str(st["boss"]["cls"]), 18))
		var bc := OKit.label(12, OKit.DIM, 500)
		bc.text = t("classes." + str(st["boss"]["cls"]))
		bch.add_child(bc)
		v.add_child(bp)
	# 별 조건
	v.add_child(_section_title("⭐", t("stars.title")))
	var flags: Array = ProgressRules.stage_star_flags(ProgressRules.stars(c), id)
	var conds := [t("stars.cond_clear"), t("stars.cond_nodeath"), t("stars.cond_turns", {"n": Profile.star_turn_limit(st)})]
	for i in conds.size():
		var on := Js.truthy(flags[i]) if i < flags.size() else false
		var row := OKit.hbox(8)
		var si := OKit.label(13, Color("facc15") if on else Color(1, 1, 1, 0.18), 900)
		si.text = "★"
		row.add_child(si)
		var sl := OKit.label(12, OKit.TEXT if on else OKit.DIM, 500)
		sl.text = conds[i]
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sl)
		row.name = "Star%d" % i
		v.add_child(row)
	# 적 구성
	var eh := OKit.hbox(8)
	v.add_child(eh)
	var et := _section_title("", t("stage.enemy_composition"))
	et.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eh.add_child(et)
	var meta := OKit.label(10, OKit.DIM, 500)
	meta.text = "[%s / %s]" % [t("stage.total_enemies", {"count": st.get("tot", 0)}), t("stage.wave_count", {"count": st.get("spw", 0)})]
	meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eh.add_child(meta)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.name = "Enemies"
	v.add_child(grid)
	for e: Array in ProgressRules.enemy_composition(st):
		var ep := PanelContainer.new()
		ep.add_theme_stylebox_override("panel", OKit.box(Color(1, 1, 1, 0.03), Color(0, 0, 0, 0), 6, 0, 8, 6))
		ep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var eh2 := OKit.hbox(6)
		ep.add_child(eh2)
		eh2.add_child(cls_icon(str(e[0]), 18))
		var en := OKit.label(11, OKit.TEXT, 500)
		en.text = t("classes." + str(e[0]))
		en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		en.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		en.clip_text = true
		eh2.add_child(en)
		var ec := OKit.label(11, OKit.GOLD, 700)
		ec.text = "×%s" % num(e[1])
		eh2.add_child(ec)
		grid.add_child(ep)
	# 환경
	var hz: Variant = Hazards.for_stage(D, st)
	if hz != null:
		var hh := OKit.vbox(4)
		hh.name = "Hazard"
		v.add_child(hh)
		hh.add_child(_section_title(str(hz.get("icon", "")), info.call("hazard_name", hz)))
		var hd := OKit.label(11, OKit.DIM, 500)
		hd.text = icons.call("strip", info.call("hazard_describe", hz, st))
		hd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hh.add_child(hd)
	# 권장 전략
	v.add_child(_section_title("", t("stage.recommended_strategy")))
	for k: String in ProgressRules.tip_keys(st):
		var tr := OKit.hbox(6)
		var ar := OKit.label(11, OKit.GOLD, 700)
		ar.text = "→"
		tr.add_child(ar)
		var tl := OKit.label(11, OKit.DIM, 500)
		tl.text = t(k)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr.add_child(tl)
		v.add_child(tr)
	var btns: Array = []
	if ProgressRules.can_practice(c, id):
		btns.append({"text": "%s (%d%% G)" % [t("stage.practice_mode"), int(roundf(float(D["ECON"]["practiceMul"]) * 100.0))], "name": "Practice",
			"cb": func() -> void: start_stage(id, true)})
	btns.append({"text": t("common.close"), "name": "Close"})
	open_modal(v, {"name": "StageInfoModal", "width": 520.0, "buttons": btns})


func _section_title(emoji: String, text: String) -> Control:
	var h := OKit.hbox(6)
	h.custom_minimum_size = Vector2(0, 30)
	if emoji != "":
		var tx: Texture2D = emoji_tex(emoji)
		if tx != null:
			h.add_child(OKit.tex_rect(tx, Vector2(16, 16)))
	var l := OKit.label(13, OKit.GOLD, 700)
	l.text = text
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


# ═══════════ 출격 (startStage → Story.beforeStage → _launchStage) ═══════════

func start_stage(id: int, practice: bool) -> void:
	var st: Variant = ProgressRules.find_stage(c, id)
	if st == null or _starting:
		return
	_starting = true
	close_all_modals()
	_story_prepare(st)
	var scenes: Array = story.call("intro")
	play_scenes(scenes, true, func() -> void: launch(Js.deep(st), practice))


## _launchStage: 5명이면 바로 전투, 아니면 편성 화면
func launch(stage: Dictionary, practice: bool) -> void:
	if _launched:
		return
	_launched = true   # 출격은 한 번만 (같은 프레임 연타·스토리 뒤 겹침 방지 — 이 화면은 곧 바뀜)
	last_launch = PartyRules.launch_stage(c, stage, practice)
	Flow.follow(router, store, c, last_launch)


func _story_prepare(st: Variant) -> void:
	story = StoryBattle.new(D, i18n, icons)
	story.set("stage", st)
	story.call("load_data", db, str(i18n.get("current_lang")), store.call("get_str", "game_story_dev"))
	story.set("roster", store.call("get_json", "game_roster"))
	var sv: Variant = store.call("get_json", StoryBattle.SEEN_KEY, {})
	story.set("seen", sv if sv is Dictionary else {})
	story.set("store", store)


## 장면 차례로 재생 (mark = 끝까지 보거나 건너뛰면 본 것으로 기록 — 다시 보기는 기록 안 함)
func play_scenes(scenes: Array, mark: bool, done: Callable) -> void:
	_story_queue = []
	for s: Dictionary in scenes:
		var sd := s.duplicate()
		sd["mark"] = mark
		_story_queue.append(sd)
	_story_done = done
	_story_next()


func _story_next() -> void:
	if _story_queue.is_empty():
		_story_cur = {}
		var f := _story_done
		_story_done = Callable()
		if f.is_valid():
			f.call()
		return
	_story_cur = _story_queue.pop_front()
	var lines: Array = story.call("resolve_lines", _story_cur["lines"])
	if lines.is_empty():
		_story_next()
		return
	story_log.append(str(_story_cur.get("key", "")))
	story_view.call("play", lines, {"title": _story_cur.get("title", ""), "battle": false, "skip_text": t("story.skip")})


func _on_story_closed() -> void:
	if _story_cur.is_empty():
		return
	if bool(_story_cur.get("mark", false)):
		story.call("mark_seen", str(_story_cur["key"]))
	_story_next()


# ═══════════ 스토리 다시 보기 (Story.openReplay · seenKeys · titleOf) ═══════════

func _part_title(key: String) -> String:
	var re := RegEx.create_from_string("^s(\\d+)_(\\w+)$")
	var m := re.search(key)
	if m == null:
		return str(story.call("title_of", key))
	var part := m.get_string(2)
	var pt := t("story.part_pre") if part == "pre" else (t("story.part_post") if part == "post" else t("story.part_battle"))
	return "%s · %s" % [story.call("stage_label", int(m.get_string(1))), pt]


func replay_lines(key: String) -> Variant:
	var re := RegEx.create_from_string("^s(\\d+)_battle$")
	var m := re.search(key)
	if m == null:
		return story.call("lines_of", key)
	var out: Array = []
	for k: String in StoryBattle.BATTLE_KINDS:
		var l: Variant = story.call("lines_of", "s%s_%s" % [m.get_string(1), k])
		if l is Array:
			out.append_array(l)
	return out


## 본 장면 → 이야기 순서 (에피소드 프롤로그 < 스테이지 pre < 전투 중 < post < 에필로그), 전투 중 대사는 스테이지마다 한 항목
func replay_keys() -> Array:
	var seen: Variant = store.call("get_json", StoryBattle.SEEN_KEY, {})
	if not (seen is Dictionary):
		return []
	var order := {"pro": 0, "pre": 1, "battle": 2, "post": 7, "epi": 8}
	var keys: Dictionary = {}
	var re_s := RegEx.create_from_string("^s(\\d+)_(\\w+)$")
	for k0: String in (seen as Dictionary).keys():
		if not Js.truthy(seen[k0]):
			continue
		var k := k0
		var bm := re_s.search(k)
		if bm != null and StoryBattle.BATTLE_KINDS.has(bm.get_string(2)):
			k = "s%s_battle" % bm.get_string(1)
		var l: Variant = replay_lines(k)
		if l is Array and not (l as Array).is_empty():
			keys[k] = true
	var re_e := RegEx.create_from_string("^ep(\\d+)_(pro|epi)$")
	var rank := func(k: String) -> Array:
		var m := re_e.search(k)
		if m != null:
			var es: Array = story.call("ep_stages", int(m.get_string(1)))
			if m.get_string(2) == "pro":
				return [(float(es[0]) if not es.is_empty() else 0.0) - 0.5, 0]
			return [(float(es[es.size() - 1]) if not es.is_empty() else 0.0) + 0.5, 0]
		var m2 := re_s.search(k)
		if m2 != null:
			return [float(m2.get_string(1)), int(order.get(m2.get_string(2), 9))]
		return [1e9, 0]
	var arr: Array = keys.keys()
	return Js.stable_sort(arr, func(a: String, b: String) -> float:
		var ra: Array = rank.call(a)
		var rb: Array = rank.call(b)
		return float(ra[0]) - float(rb[0]) if ra[0] != rb[0] else float(ra[1]) - float(rb[1]))


func open_replay() -> void:
	_story_prepare(null)
	var v := OKit.vbox(6)
	v.name = "Replay"
	var keys := replay_keys()
	if keys.is_empty():
		var e := OKit.label(14, OKit.DIM, 500)
		e.text = t("story.replay_empty")
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(e)
	var last_ep := 0
	var re_ep := RegEx.create_from_string("^ep(\\d+)_")
	var re_st := RegEx.create_from_string("^s(\\d+)_")
	for k: String in keys:
		var me := re_ep.search(k)
		var ep: int = int(me.get_string(1)) if me != null else int(story.call("ep_of", int(re_st.search(k).get_string(1))))
		if ep != last_ep:
			last_ep = ep
			var eh := OKit.label(12, Color("f59e0b"), 700)
			var epd: Variant = (story.get("data") as Dictionary).get("episodes", {}).get(str(ep))
			var ept := str(epd.get("title", "")) if typeof(epd) == TYPE_DICTIONARY else ""
			eh.text = "EP.%d %s" % [ep, ept if ept != "" else t("episode.%d.name" % ep)]
			eh.custom_minimum_size = Vector2(0, 30)
			eh.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			v.add_child(eh)
		var b := OKit.styled_button(OKit.box(Color(30 / 255.0, 41 / 255.0, 59 / 255.0, 0.6), Color(148 / 255.0, 163 / 255.0, 184 / 255.0, 0.15), 8, 1, 12, 10),
			OKit.box(Color(30 / 255.0, 41 / 255.0, 59 / 255.0, 0.95), Color("f59e0b"), 8, 1, 12, 10), null, 8)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "▶  " + _part_title(k)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_font_override("font", Kit.bold(700 if k.begins_with("ep") else 400))
		b.add_theme_color_override("font_color", OKit.TEXT)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_focus_color", Color.WHITE)
		b.name = "Replay_" + k
		b.pressed.connect(func() -> void: _replay_play(k))
		v.add_child(b)
	var sb := OKit.box(Color("111827"), Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.4), 12, 1, 16, 14)
	open_modal(v, {"name": "ReplayModal", "title": t("story.replay"), "title_size": 16, "width": 480.0, "box": sb, "close_x": true})


func _replay_play(k: String) -> void:
	close_all_modals()
	var re_s := RegEx.create_from_string("^s(\\d+)_")
	var re_e := RegEx.create_from_string("^ep(\\d+)_(pro|epi)$")
	var st: Variant = null
	var sm := re_s.search(k)
	var em := re_e.search(k)
	if sm != null:
		st = ProgressRules.find_stage(c, int(sm.get_string(1)))
	elif em != null:
		var es: Array = story.call("ep_stages", int(em.get_string(1)))
		if not es.is_empty():
			st = ProgressRules.find_stage(c, int(es[es.size() - 1]))
	story.set("stage", st)
	play_scenes([{"key": k, "lines": replay_lines(k), "title": _part_title(k)}], false, open_replay)


# ═══════════ 요일 던전 (openDaily) ═══════════

func open_daily() -> void:
	close_all_modals()
	var date := local_date()
	var classes := ProgressRules.daily_classes(c, int(date["weekday"]))
	var left := ProgressRules.daily_left(c, date)
	if _daily_cls == "" or not classes.has(_daily_cls):
		_daily_cls = str(classes[0]) if not classes.is_empty() else ""
	var v := OKit.vbox(8)
	v.name = "Daily"
	var help := OKit.label(11, OKit.DIM2, 500)
	help.text = t("daily.help", {"n": D["SOUL"]["fragsPerStone"]})
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(help)
	var lf := OKit.label(12, Color("7dd3fc"), 700)
	lf.text = t("daily.left", {"n": left, "max": D["DAILY"]["perDay"]})
	v.add_child(lf)
	var grid := GridContainer.new()
	grid.name = "Classes"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for cl: String in classes:
		var on := cl == _daily_cls
		var b := OKit.styled_button(OKit.box(Color(56 / 255.0, 189 / 255.0, 248 / 255.0, 0.15) if on else Color(15 / 255.0, 23 / 255.0, 42 / 255.0, 0.55), Color("38bdf8") if on else Color(148 / 255.0, 163 / 255.0, 184 / 255.0, 0.25), 10, 1, 4, 6),
			OKit.box(Color(56 / 255.0, 189 / 255.0, 248 / 255.0, 0.2), Color("38bdf8"), 10, 1, 4, 6), null, 10)
		b.name = "Cls_" + cl
		b.custom_minimum_size = Vector2(98, 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := OKit.vbox(1)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		OKit.set_content(b, cv, Vector4(4, 6, 4, 6))
		var ic := cls_icon(cl, 20)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(ic)
		var nl := OKit.label(11, Color("e2e8f0"), 600)
		nl.text = t("classes." + cl)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(nl)
		var sc: Array = ProgressRules.soul_counts(c, cl)
		var sh := OKit.hbox(2)
		sh.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_child(sh)
		sh.add_child(OKit.tex_rect(emoji_tex("💠"), Vector2(10, 10)))
		var sl := OKit.label(9, Color("94a3b8"), 500)
		sl.text = "%s · %s/%s" % [num(sc[0]), num(sc[1]), num(D["SOUL"]["fragsPerStone"])]
		sh.add_child(sl)
		b.pressed.connect(func() -> void:
			_daily_cls = cl
			open_daily())
		grid.add_child(b)
	var tiers: Array = D["DAILY"]["tiers"]
	for i in tiers.size():
		var T: Dictionary = tiers[i]
		var open := ProgressRules.daily_tier_open(c, i)
		var can := open and left > 0
		var b2 := OKit.styled_button(OKit.box(Color(56 / 255.0, 189 / 255.0, 248 / 255.0, 0.08), Color(56 / 255.0, 189 / 255.0, 248 / 255.0, 0.35), 10, 1, 12, 9),
			OKit.box(Color(56 / 255.0, 189 / 255.0, 248 / 255.0, 0.16), Color("38bdf8"), 10, 1, 12, 9), null, 10)
		b2.name = "Tier_" + str(T["key"])
		b2.disabled = not can
		b2.custom_minimum_size = Vector2(0, 40)
		var th := OKit.hbox(8)
		OKit.set_content(b2, th, Vector4(12, 8, 12, 8))
		var tn := OKit.label(12, Color("e0f2fe"), 800)
		tn.text = t("daily.tier_" + str(T["key"]))
		tn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		th.add_child(tn)
		th.add_child(OKit.spacer())
		var ti := OKit.label(11, Color("94a3b8"), 500)
		ti.text = t("daily.tier_info", {"eq": T["eq"], "n": T["frags"]}) if open else t("daily.tier_lock", {"n": T["unlock"]})
		ti.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		th.add_child(ti)
		if not can:
			b2.modulate = Color(1, 1, 1, 0.45)
		var tier := i
		b2.pressed.connect(func() -> void: daily_start(tier))
		v.add_child(b2)
	open_modal(v, {"name": "DailyModal", "title": "💠 " + t("daily.title"), "width": 520.0,
		"buttons": [{"text": t("common.close"), "secondary": true, "name": "Close"}]})


## 난이도 고르기: 입장 1회 소모(지면 돌려주지 않음) → 요일 던전 스테이지로 출격
func daily_start(tier: int) -> void:
	var date := local_date()
	if _starting or _launched or ProgressRules.daily_left(c, date) <= 0 or _daily_cls == "" or not ProgressRules.daily_tier_open(c, tier):
		return
	_starting = true   # 같은 프레임에 두 번 눌러도 입장은 한 번만 소모
	ProgressRules.daily_consume(c, date)
	close_all_modals()
	launch(ProgressRules.daily_stage(c, _daily_cls, tier), false)
