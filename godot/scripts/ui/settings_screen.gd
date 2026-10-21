extends "res://scripts/ui/screen_base.gd"
## 설정 — 웹 settings.html (배경음·효과음 켜기/음량, 게임 속도, 언어, 모든 데이터 초기화, 라이선스·Credits)
##  저장 키·동작은 전투 설정 창(hud_settings.gd)과 같음 — 둘 다 scripts/logic/settings_rules.gd:
##   bgmOn · bgmVol · sfxOn · sfxVol (웹과 같은 키), playSpeed(1·2·4) · reduceMotion (Godot 전용), 언어는 고를 때만 I18n.set_language 가 저장.
##  게임 속도: 웹 설정 화면은 늘이기 배율 speed(0.5~2.0) 이지만 Godot 전투는 재생 배율 playSpeed 를 쓰므로 전투 설정 창과 같은 1x·2x·4x 단추 (웹 speed 값은 건드리지 않음)
##  언어: 전투 설정 창과 같은 6개 단추(그 언어 이름·글꼴), 바로 바뀜 (웹은 고른 뒤 페이지 새로고침)
##  초기화: 확인 → Store 전부 지움 → 시작 화면부터 (웹: index.html 로 — 첫 실행처럼 클랜원·지휘관 설정)
##  라이선스·Credits → licenses · credits 화면 (4b-2). 뒤로: 열기 전 화면 (웹은 늘 로비 — 보고서 '갈림길')
##  (5단계 PC — Platform.is_pc() 일 때만) 창이 뒤에 있을 때 소리(그대로·줄이기·끄기 → game_settings.bgAudio, Sound 가 반영),
##   화면: 창 모드 / 전체 화면 · 창 크기(창 모드일 때, 모니터에 들어가는 크기만) → Store gd_display (Display 오토로드)

const SettingsRules := preload("res://scripts/logic/settings_rules.gd")
const Fonts := preload("res://scripts/core/fonts.gd")
const I18nT := preload("res://scripts/core/i18n.gd")

var s: Dictionary = {}
var _box: VBoxContainer
var _disp_box: VBoxContainer
var _resetting := false


func page_id() -> String:
	return ""


func title_text() -> String:
	return t("settings.title")


func has_gear() -> bool:
	return false


func has_bottom_nav() -> bool:
	return false


func go_back() -> void:
	router.call("back")


func _build() -> void:
	s = SettingsRules.load_settings(store)
	var dp := _svc("Display")
	if dp != null and not dp.is_connected("changed", _on_display_changed):
		dp.connect("changed", _on_display_changed)
	var sc := ScrollContainer.new()
	sc.name = "Scroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(sc)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(cc)
	_box = OKit.vbox(12)
	_box.name = "SettingsBox"
	_box.custom_minimum_size = Vector2(400, 0)
	cc.add_child(_box)
	# 스크롤 칸이 화면 높이를 채우게 (가운데 정렬)
	sc.resized.connect(func() -> void: cc.custom_minimum_size = Vector2(0, sc.size.y))


func _refresh() -> void:
	for ch: Node in _box.get_children():
		_box.remove_child(ch)
		ch.queue_free()
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(top)
	_toggle_row("music", t("settings.bgm"), "bgmOn")
	_slider_row(t("settings.volume"), "bgmVol")
	_toggle_row("sound", t("settings.sfx"), "sfxOn")
	_slider_row(t("settings.volume"), "sfxVol")
	if _is_pc():
		_bg_audio_row()
	_box.add_child(OKit.divider(0.06))
	# 게임 속도 (전투 설정 창과 같은 1x·2x·4x)
	var sr := OKit.hbox(8)
	_box.add_child(sr)
	sr.add_child(OKit.vec_icon("speed", 16, OKit.GOLD))
	var sl := OKit.label(14, OKit.TEXT, 700)
	sl.text = t("settings.game_speed")
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sr.add_child(sl)
	for sp: int in SettingsRules.SPEEDS:
		var on := int(s["playSpeed"]) == sp
		var b := OKit.ghost_button("%dx" % sp, 13)
		b.name = "Speed%d" % sp
		b.custom_minimum_size = Vector2(52, 32)
		if on:
			b.add_theme_stylebox_override("normal", OKit.box(Color(OKit.GOLD, 0.25), OKit.GOLD, 6, 1, 10, 6))
		var spv := sp
		b.pressed.connect(func() -> void: set_value("playSpeed", spv, true))
		sr.add_child(b)
	var rm := _toggle_row("eye", t("gd.settings.reduce_motion"), "reduceMotion")
	rm.tooltip_text = t("gd.settings.reduce_motion_tip")
	_box.add_child(OKit.divider(0.06))
	if _is_pc():
		_disp_box = OKit.vbox(10)
		_disp_box.name = "DisplayBox"
		_box.add_child(_disp_box)
		_build_display()
		_box.add_child(OKit.divider(0.06))
	# 언어 (6개 — 그 언어 이름, 그 언어 글꼴)
	var lr := OKit.hbox(8)
	_box.add_child(lr)
	lr.add_child(OKit.vec_icon("globe", 16, OKit.GOLD))
	var ll := OKit.label(14, OKit.TEXT, 700)
	ll.text = t("settings.language")
	lr.add_child(ll)
	var lg := GridContainer.new()
	lg.name = "LangGrid"
	lg.columns = 3
	lg.add_theme_constant_override("h_separation", 6)
	lg.add_theme_constant_override("v_separation", 6)
	_box.add_child(lg)
	var cur := str(i18n.get("current_lang"))
	for code: String in I18nT.LANGS:
		var full := t("settings.language_" + code)
		var cut := full.find(" (")
		var b2 := OKit.ghost_button(full.substr(0, cut) if cut > 0 else full, 13)
		b2.name = "Lang_" + code
		b2.custom_minimum_size = Vector2(0, 34)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.tooltip_text = full
		b2.add_theme_font_override("font", Fonts.for_lang(code, 700))
		if code == cur:
			b2.add_theme_stylebox_override("normal", OKit.box(Color(OKit.GOLD, 0.25), OKit.GOLD, 6, 1, 10, 6))
		b2.pressed.connect(func() -> void: choose_language(code))
		lg.add_child(b2)
	_box.add_child(OKit.divider(0.06))
	# (6b 모바일) 광고 개인정보 설정 — UMP 개인정보 옵션 창
	if _has_ad_privacy():
		var ap := CenterContainer.new()
		ap.name = "AdPrivacyRow"
		ap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_child(ap)
		var apb := OKit.ghost_button(t("gd.settings.ad_privacy"), 13)
		apb.name = "AdPrivacy"
		apb.tooltip_text = t("gd.settings.ad_privacy_tip")
		apb.pressed.connect(open_ad_privacy)
		ap.add_child(apb)
		_box.add_child(OKit.divider(0.06))
	# 모든 데이터 초기화
	var rc := CenterContainer.new()
	rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(rc)
	var rn := OKit.box(Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.08), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.4), 6, 1, 16, 7)
	var rh := OKit.box(Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.18), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.7), 6, 1, 16, 7)
	rn.content_margin_left = 34
	rh.content_margin_left = 34
	var rb := OKit.styled_button(rn, rh, null, 6)
	rb.name = "Reset"
	rb.text = t("settings.reset_all")
	rb.add_theme_font_size_override("font_size", 13)
	rb.add_theme_color_override("font_color", OKit.RED)
	rb.add_theme_color_override("font_hover_color", Color("fca5a5"))
	rb.add_theme_color_override("font_focus_color", Color("fca5a5"))
	var ti := OKit.vec_icon("trash", 14, OKit.RED)
	ti.position = Vector2(12, 9)
	rb.add_child(ti)
	rb.pressed.connect(ask_reset)
	rc.add_child(rb)
	_box.add_child(OKit.divider(0.06))
	var links := OKit.vbox(2)
	_box.add_child(links)
	for lk: Array in [["Licenses", t("settings.licenses"), "licenses"], ["Credits", "Credits", "credits"]]:
		var b3 := OKit.styled_button(StyleBoxEmpty.new(), StyleBoxEmpty.new(), null, 4)
		b3.name = str(lk[0])
		b3.text = str(lk[1])
		b3.add_theme_font_size_override("font_size", 12)
		b3.add_theme_color_override("font_color", OKit.DIM2)
		b3.add_theme_color_override("font_hover_color", OKit.GOLD)
		b3.add_theme_color_override("font_focus_color", OKit.GOLD)
		b3.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var dest := str(lk[2])
		b3.pressed.connect(func() -> void: router.call("go", dest))
		links.add_child(b3)


func _has_ad_privacy() -> bool:
	var pf := _svc("Platform")
	var ad := _svc("Ads")
	return pf != null and bool(pf.call("is_mobile")) and ad != null and bool(ad.call("privacy_entry"))


## '광고 개인정보 설정' — 이 지역에서 필요하면 UMP 창, 아니면 안내만
func open_ad_privacy() -> void:
	var ad := _svc("Ads")
	if ad == null:
		return
	var r := str(await ad.show_privacy_options())
	if r == "not_required":
		alert(t("gd.settings.ad_privacy_none"))


func _toggle_row(icon: String, label: String, key: String) -> Control:
	var r := OKit.hbox(8)
	_box.add_child(r)
	r.add_child(OKit.vec_icon(icon, 16, OKit.GOLD))
	var l := OKit.label(14, OKit.TEXT, 700)
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	var cb := CheckButton.new()
	cb.name = "Toggle_" + key
	cb.focus_mode = Control.FOCUS_ALL
	cb.add_theme_stylebox_override("focus", OKit.focus_box(12))
	cb.button_pressed = bool(s[key])
	cb.toggled.connect(func(on: bool) -> void: set_value(key, on, false))
	r.add_child(cb)
	return r


func _slider_row(label: String, key: String) -> void:
	var r := OKit.hbox(10)
	_box.add_child(r)
	var l := OKit.label(13, OKit.TEXT, 700)
	l.text = label
	l.custom_minimum_size = Vector2(68, 0)
	r.add_child(l)
	var sl := HSlider.new()
	sl.name = "Slider_" + key
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 1
	sl.value = roundf(float(s[key]) * 100.0)
	sl.focus_mode = Control.FOCUS_ALL
	sl.add_theme_stylebox_override("focus", OKit.focus_box(4))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(sl)
	var v := OKit.label(12, OKit.DIM, 600)
	v.text = str(int(sl.value))
	v.custom_minimum_size = Vector2(30, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(v)
	sl.value_changed.connect(func(x: float) -> void:
		v.text = str(int(x))
		set_value(key, x / 100.0, false))


# ── (5단계 PC) 창이 뒤에 있을 때 소리 · 화면 ──

func _is_pc() -> bool:
	var pf := _svc("Platform")
	return pf != null and bool(pf.call("is_pc"))


## 고르기 단추 줄 (게임 속도 단추와 같은 모양): [[값, 글], …]
func _choice_buttons(parent: Control, prefix: String, opts: Array, cur: Variant, pick: Callable, enabled: bool = true) -> void:
	for o: Array in opts:
		var b := OKit.ghost_button(str(o[1]), 13)
		b.name = prefix + str(o[0]).replace("x", "_")
		b.custom_minimum_size = Vector2(52, 32)
		if o[0] == cur:
			b.add_theme_stylebox_override("normal", OKit.box(Color(OKit.GOLD, 0.25), OKit.GOLD, 6, 1, 10, 6))
		b.disabled = not enabled
		if not enabled:
			b.modulate.a = 0.45
		var v: Variant = o[0]
		b.pressed.connect(func() -> void: pick.call(v))
		parent.add_child(b)


func _bg_audio_row() -> void:
	var r := OKit.hbox(8)
	r.name = "BgAudioRow"
	_box.add_child(r)
	r.add_child(OKit.vec_icon("sound", 16, OKit.GOLD))
	var l := OKit.label(14, OKit.TEXT, 700)
	l.text = t("gd.settings.bg_audio")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	r.tooltip_text = t("gd.settings.bg_audio_tip")
	var opts: Array = []
	for m: String in SettingsRules.BG_AUDIO_MODES:
		opts.append([m, t("gd.settings.bg_" + m)])
	_choice_buttons(r, "BgAudio_", opts, SettingsRules.bg_audio(store), func(v: Variant) -> void:
		SettingsRules.set_bg_audio(store, str(v))
		_refresh())


func _build_display() -> void:
	if _disp_box == null:
		return
	for ch: Node in _disp_box.get_children():
		_disp_box.remove_child(ch)
		ch.queue_free()
	var dp := _svc("Display")
	if dp == null:
		return
	var fs := bool(dp.call("is_fullscreen"))
	var mr := OKit.hbox(8)
	mr.name = "ModeRow"
	_disp_box.add_child(mr)
	mr.add_child(OKit.vec_icon("monitor", 16, OKit.GOLD))
	var ml := OKit.label(14, OKit.TEXT, 700)
	ml.text = t("gd.settings.window_mode")
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mr.add_child(ml)
	mr.tooltip_text = t("gd.settings.fullscreen_tip")
	_choice_buttons(mr, "Mode_", [["windowed", t("gd.settings.windowed")], ["fullscreen", t("gd.settings.fullscreen")]], dp.call("mode"),
		func(v: Variant) -> void: dp.call("set_mode", str(v)))
	var sr := OKit.hbox(8)
	sr.name = "SizeRow"
	_disp_box.add_child(sr)
	var sl := OKit.label(13, OKit.TEXT, 700)
	sl.text = t("gd.settings.window_size")
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sr.add_child(sl)
	sr.tooltip_text = t("gd.settings.window_size_tip")
	var cur: Vector2i = dp.call("window_logical_size")
	var cv := OKit.label(12, OKit.DIM, 600)
	cv.name = "CurSize"
	cv.text = "%d×%d" % [cur.x, cur.y]
	sr.add_child(cv)
	var g := GridContainer.new()
	g.name = "SizeGrid"
	g.columns = 3
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	_disp_box.add_child(g)
	var opts: Array = []
	for z: Vector2i in dp.call("available_sizes"):
		opts.append(["%dx%d" % [z.x, z.y], "%d×%d" % [z.x, z.y]])
	var pick := func(v: Variant) -> void:
		var p := str(v).split("x")
		dp.call("set_window_size", Vector2i(int(p[0]), int(p[1])))
		_build_display.call_deferred()
	_choice_buttons(g, "Size_", opts, "%dx%d" % [cur.x, cur.y], pick, not fs)
	for b: Node in g.get_children():
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(b as Control).tooltip_text = t("gd.settings.window_size_tip")


func _on_display_changed() -> void:
	if is_inside_tree() and _disp_box != null:
		_build_display.call_deferred()


## 값 하나 바꾸고 저장 (전투 설정 창과 같은 규칙)
func set_value(key: String, v: Variant, redraw: bool) -> void:
	s[key] = v
	SettingsRules.save_from(store, s)
	if redraw:
		_refresh()


## 언어는 직접 고를 때만 저장 (I18n.set_language → game_settings.language), 바로 바뀜
func choose_language(code: String) -> void:
	i18n.call("set_language", code)


func ask_reset() -> void:
	confirm(t("messages.confirm_reset_all"), reset_all)


## 모든 데이터 초기화 (웹 Store.clear → index.html): 언어 설정도 지워지므로 OS 언어로 다시 고름
func reset_all() -> void:
	if _resetting:
		return
	_resetting = true
	# (결제층 A) 결제 기록(설치 식별자 · 주문 · 환불 커서)과 그 보관함은 지우지 않음 — 지우면 미처리 주문이 다시 지급되거나(중복)
	#  설치 식별자가 바뀌어 서버가 주문을 막음. 화면 문구는 그대로 ('모든 데이터' = 게임 진행)
	var keep: Dictionary = {}
	for k: String in ["game_iap", "game_iap_bak"]:
		var v: Variant = store.call("get_str", k)
		if v != null:
			keep[k] = v
	store.call("clear")
	for k2: String in keep.keys():
		store.call("set_str", k2, keep[k2])
	store.call("flush")
	i18n.call("reload")
	router.set("history", [])
	router.call("go", "boot", {}, false)
