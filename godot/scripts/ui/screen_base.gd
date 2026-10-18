extends Control
## 바깥 화면 공통 틀 — 웹 각 페이지의 #top-nav(뒤로·제목·톱니) · #content · #bottom-nav · #modal-overlay · .toast
##  화면 스크립트는 이 파일을 extends 하고 아래 가상 함수를 채운다:
##   page_id()      : 아래 탭에서 켤 탭 ("stage" · "party" · "" …) — 웹 body[data-page]
##   title_text()   : 윗줄 제목
##   has_back() · has_gear() · has_bottom_nav()
##   _build()       : 처음 한 번 (body 아래에 화면 부품)
##   _refresh()     : 글·값 다시 그리기 (언어가 바뀌면 또 부름)
##   go_back()      : 뒤로 단추·Esc·마우스 뒤로 단추 (열린 창이 없을 때) — 웹 '뒤로' 단추와 같은 곳
##  규칙(저장값 읽기·쓰기)은 scripts/logic/*_rules.gd — 여기서는 c (ctx: D · rng · store=진짜 Store) 로 부른다.

const OKit := preload("res://scripts/ui/outer_kit.gd")
const Kit := preload("res://scripts/battle/ui_kit.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")
const StoreCtx := preload("res://scripts/logic/store_ctx.gd")
const Icons := preload("res://scripts/battle/icons.gd")
const Js := preload("res://scripts/logic/js.gd")
const Num := preload("res://scripts/core/num.gd")
const SaveSanitize := preload("res://scripts/logic/save_sanitize.gd")

var store: Node
var db: Node
var i18n: Node
var router: Node
var D: Dictionary
var c: Object   # ctx.gd
var icons: Object
## 들어올 때 다듬은 저장 키 (시험·확인용)
var sanitized: Array = []

var top_nav: PanelContainer
var back_btn: Button
var title_lbl: Label
var gear_btn: Button
var body: Control
var bottom_nav: PanelContainer
var _tabs: Dictionary = {}   # tab → {btn, icon, label}
var layer: Control           # 창·알림 (맨 위)
var _modals: Array = []      # [{root, on_close}]
var _toast: PanelContainer


# ── 가상 함수 ──
func page_id() -> String:
	return ""


func title_text() -> String:
	return t("common.game_title")


func has_back() -> bool:
	return true


func has_gear() -> bool:
	return true


func has_bottom_nav() -> bool:
	return true


func _build() -> void:
	pass


func _refresh() -> void:
	pass


func go_back() -> void:
	if router != null:
		router.call("go", "lobby")


## (4b-1) 자원이 오가는 단추의 같은 프레임 연타 막기: 한 프레임에 한 번만 true (사기·강화·끼우기·판매·분해·수리·물약·뽑기·재개)
var _act_frame := -1


func act_once() -> bool:
	var f := Engine.get_process_frames()
	if f == _act_frame:
		return false
	_act_frame = f
	return true


## 지금 무엇을 재생 중이라 뒤로 가기를 받지 않을 때 (스토리 등)
func busy() -> bool:
	return false


# ── 준비 ──

func _svc(n: String) -> Node:
	return get_node_or_null("/root/" + n)


func _ready() -> void:
	store = _svc("Store")
	db = _svc("DataDB")
	i18n = _svc("I18n")
	router = _svc("Router")
	D = Ctx.globals_from_db(db)
	c = Ctx.new(D, randi() & 0x7fffffff, StoreCtx.new(store))
	c.clock = func() -> float: return Ctx.real_now()
	# 이상한 값이 든 세이브 다듬기 (웹보다 관대하게, 오류 없이 — scripts/logic/save_sanitize.gd)
	sanitized = SaveSanitize.sanitize(c)
	icons = Icons.get_for(D)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_chrome()
	_build()
	_refresh_chrome()
	_refresh()
	if i18n != null:
		i18n.connect("language_changed", _on_language)


func _exit_tree() -> void:
	if i18n != null and i18n.is_connected("language_changed", _on_language):
		i18n.disconnect("language_changed", _on_language)


func _on_language(_lang: String) -> void:
	_refresh_chrome()
	_refresh()


func t(k: String, p: Dictionary = {}) -> String:
	return i18n.call("t", k, p) if i18n != null else k


func has_t(k: String) -> bool:
	return i18n != null and bool(i18n.call("has_key", k))


func num(v: Variant) -> String:
	return Num.fmt(v)


## 웹 Number.toLocaleString() (세 자리마다 쉼표 — 골드 표시)
static func grouped(v: float) -> String:
	var n := int(roundf(v))
	var neg := n < 0
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out


func _build_chrome() -> void:
	var bg := ColorRect.new()
	bg.color = OKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var col := VBoxContainer.new()
	col.name = "Frame"
	col.add_theme_constant_override("separation", 0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	# 윗줄 (#top-nav: 56px, 짙은 남색 그라디언트, 아래 선)
	top_nav = PanelContainer.new()
	top_nav.name = "TopNav"
	top_nav.custom_minimum_size = Vector2(0, OKit.NAV_TOP_H)
	var tsb := OKit.box(Color("131a2b"), Color(1, 1, 1, 0.08), 0, 0, 0, 0)
	tsb.border_width_bottom = 1
	tsb.shadow_color = Color(0, 0, 0, 0.3)
	tsb.shadow_size = 6
	top_nav.add_theme_stylebox_override("panel", tsb)
	col.add_child(top_nav)
	var tn := Control.new()
	tn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_nav.add_child(tn)
	title_lbl = OKit.label(20, OKit.GOLD, 900)
	title_lbl.name = "Title"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_lbl.offset_left = 64
	title_lbl.offset_right = -64
	title_lbl.add_theme_constant_override("outline_size", 0)
	tn.add_child(title_lbl)
	back_btn = _nav_icon_btn("chev_l", OKit.TEXT)
	back_btn.name = "Back"
	back_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	back_btn.offset_left = 16
	back_btn.offset_top = -20
	back_btn.offset_right = 56
	back_btn.offset_bottom = 20
	back_btn.pressed.connect(func() -> void: on_back())
	tn.add_child(back_btn)
	gear_btn = _nav_icon_btn("gear", OKit.DIM)
	gear_btn.name = "Gear"
	gear_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	gear_btn.offset_left = -56
	gear_btn.offset_top = -20
	gear_btn.offset_right = -16
	gear_btn.offset_bottom = 20
	gear_btn.pressed.connect(func() -> void:
		if router != null:
			router.call("go", "settings"))
	tn.add_child(gear_btn)
	# 본문 (#content: radial-gradient(ellipse at 50% 20%, #1e2d4a, #0a0e1a))
	body = Control.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.clip_contents = true
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(body)
	body.add_child(OKit.gradient_rect([Color("1e2d4a"), Color("0a0e1a")], [0.0, 1.0], true, Vector2(0.5, 0.2), Vector2(1.15, 1.05)))
	# 아래 탭 (#bottom-nav: 64px)
	bottom_nav = PanelContainer.new()
	bottom_nav.name = "BottomNav"
	bottom_nav.custom_minimum_size = Vector2(0, OKit.NAV_BOTTOM_H)
	var bsb := OKit.box(OKit.PANEL, Color(OKit.GOLD, 0.1), 0, 0, 0, 0)
	bsb.border_width_top = 1
	bottom_nav.add_theme_stylebox_override("panel", bsb)
	col.add_child(bottom_nav)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	bottom_nav.add_child(row)
	for tab: Dictionary in D.get("NAV_TABS", []):
		var key := str(tab["tab"])
		var b := OKit.styled_button(StyleBoxEmpty.new(), OKit.box(Color(1, 1, 1, 0.03), Color(0, 0, 0, 0), 0, 0, 0, 0), null, 4)
		b.name = "Tab_" + key
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		var v := OKit.vbox(2)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		OKit.set_content(b, v, Vector4(2, 6, 2, 4))
		var ic := OKit.tex_rect(icons.call("image", "icon/nav/%s.png" % key), Vector2(26, 26), true)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var lb := OKit.label(12, OKit.DIM, 700)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lb)
		var bar := ColorRect.new()
		bar.color = OKit.GOLD
		bar.custom_minimum_size = Vector2(16, 2)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bar)
		_tabs[key] = {"btn": b, "icon": ic, "label": lb, "bar": bar, "i18n": str(tab["i18n"]), "fallback": str(tab.get("fallback", key))}
		b.pressed.connect(_on_tab.bind(key))
	# 창·알림 층
	layer = Control.new()
	layer.name = "Layer"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)


func _nav_icon_btn(kind: String, col: Color) -> Button:
	var b := OKit.styled_button(StyleBoxEmpty.new(), OKit.box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 8, 0, 0, 0), null, 8)
	b.custom_minimum_size = Vector2(40, 40)
	var ic := Kit.VecIcon.new()
	ic.kind = kind
	ic.color = col
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 7
	ic.offset_top = 7
	ic.offset_right = -7
	ic.offset_bottom = -7
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	b.mouse_entered.connect(func() -> void: ic.color = OKit.GOLD; ic.queue_redraw())
	b.mouse_exited.connect(func() -> void: ic.color = col; ic.queue_redraw())
	return b


func _refresh_chrome() -> void:
	title_lbl.text = title_text()
	back_btn.visible = has_back()
	gear_btn.visible = has_gear()
	gear_btn.tooltip_text = t("settings.title")
	back_btn.tooltip_text = "Esc"
	bottom_nav.visible = has_bottom_nav()
	var page := page_id()
	for key: String in _tabs.keys():
		var tb: Dictionary = _tabs[key]
		var lbl := t(tb["i18n"])
		(tb["label"] as Label).text = tb["fallback"] if lbl == tb["i18n"] else lbl
		var on := key == page
		(tb["label"] as Label).add_theme_color_override("font_color", OKit.GOLD if on else OKit.DIM)
		(tb["icon"] as Control).modulate = Color(1.0, 0.85, 0.45, 1.0) if on else Color(1, 1, 1, 0.5)
		(tb["bar"] as Control).modulate.a = 1.0 if on else 0.0


## 아래 탭 (웹 nav.js renderBottomNav: 스테이지 · 파티 · 성소 · 아카데미 · 상점)
func _on_tab(key: String) -> void:
	match key:
		"stage":
			router.call("go", "stage_select")
		"party":
			# 웹: 편성 화면으로 갈 때 출격 단추 끔
			c.store.set_str("ps_can_start", "false")
			router.call("go", "party_select")
		"sanctuary", "academy", "shop":
			router.call("go", key)


# ── 뒤로 가기 ──

## 뒤로 단추 · Esc · 마우스 뒤로 단추 (Router 가 부름): 열린 창 먼저 닫고, 없으면 go_back
func on_back() -> void:
	if busy():
		return
	if not _modals.is_empty():
		if not bool(_modals.back().get("no_esc", false)):
			close_modal()
		return
	if has_back():
		go_back()


# ── 창 (웹 #modal-overlay > #modal-box) ──

func modal_open() -> bool:
	return not _modals.is_empty()


## content 를 창에 담아 띄움. opts: {no_esc(Esc·뒤로로 닫지 않음), title, buttons:[{text, cb, secondary, name, keep(누른 뒤 창 유지)}], width, close_on_bg(기본 true), on_close, name, box(StyleBox)}
func open_modal(content: Control, opts: Dictionary = {}) -> Control:
	var ov := Control.new()
	ov.name = str(opts.get("name", "Modal"))
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.add_child(dim)
	if bool(opts.get("close_on_bg", true)):
		# (4b-1) 연 직후 0.3초 안의 바깥 누르기는 무시 — 창을 연 단추를 두 번 누르면(더블클릭·같은 프레임 연타) 두 번째가 바로 창을 닫지 않게
		var opened := Time.get_ticks_msec()
		dim.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				if Time.get_ticks_msec() - opened < 300:
					return
				_close_modal_node(ov, true))
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cc)
	var panel := PanelContainer.new()
	panel.name = "Box"
	var sb: StyleBox = opts.get("box", null)
	if sb == null:
		var f := OKit.box(Color("131a2c"), OKit.GOLD_D, 14, 2, 40, 32)
		f.shadow_color = Color(OKit.GOLD, 0.1)
		f.shadow_size = 24
		sb = f
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	cc.add_child(panel)
	var v := OKit.vbox(14)
	panel.add_child(v)
	var w := float(opts.get("width", 420.0))
	var vs := get_viewport_rect().size
	var max_h := vs.y * 0.85 - 64.0
	if str(opts.get("title", "")) != "":
		var tl := OKit.label(int(opts.get("title_size", 26)), OKit.GOLD, 900)
		tl.name = "ModalTitle"
		tl.text = icons.call("strip", str(opts["title"]))
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if bool(opts.get("close_x", false)):
			# 웹 .unit-modal-header: 제목(왼쪽) + ✕ 단추(오른쪽)
			var hr := OKit.hbox(8)
			hr.name = "Header"
			hr.custom_minimum_size = Vector2(w - 88.0, 0)
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hr.add_child(tl)
			var cx := OKit.styled_button(OKit.box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 8, 0, 0, 0), OKit.box(Color(1, 1, 1, 0.14), Color(0, 0, 0, 0), 8, 0, 0, 0), null, 8)
			cx.name = "CloseX"
			cx.custom_minimum_size = Vector2(32, 32)
			cx.tooltip_text = "Esc"
			var xi := OKit.vec_icon("close", 16, OKit.TEXT)
			xi.position = Vector2(8, 8)
			cx.add_child(xi)
			cx.pressed.connect(close_modal)
			hr.add_child(cx)
			v.add_child(hr)
		else:
			# 제목 속 이모지는 그림으로 (웹 EmojiIcons — 예: 요일 던전 💠)
			var tex: Texture2D = null
			for part: Variant in icons.call("split", str(opts["title"])):
				if part is Texture2D:
					tex = part
					break
			if tex != null:
				tl.text = icons.call("strip", str(opts["title"]))
				tl.autowrap_mode = TextServer.AUTOWRAP_OFF   # 가로 줄 안에서 줄바꿈하면 폭 1 로 세로가 길어짐
				var th := OKit.hbox(8)
				th.name = "TitleRow"
				th.alignment = BoxContainer.ALIGNMENT_CENTER
				th.custom_minimum_size = Vector2(w - 88.0, 0)
				var isz := float(opts.get("title_size", 26)) * 1.15
				var ir := OKit.tex_rect(tex, Vector2(isz, isz))
				ir.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				th.add_child(ir)
				th.add_child(tl)
				v.add_child(th)
			else:
				tl.custom_minimum_size = Vector2(w - 88.0, 0)
				v.add_child(tl)
		max_h -= 50.0
	var sc := ScrollContainer.new()
	sc.name = "Scroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(w - 88.0, 0)
	v.add_child(sc)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	var btns: Array = opts.get("buttons", [])
	var first: Button = null
	if not btns.is_empty():
		var br := OKit.hbox(8)
		br.alignment = BoxContainer.ALIGNMENT_CENTER
		br.name = "Buttons"
		v.add_child(br)
		max_h -= 60.0
		for bd: Dictionary in btns:
			var b := OKit.modal_button("", bool(bd.get("secondary", false)))
			set_button_text(b, str(bd["text"]), 18)
			b.name = str(bd.get("name", "Btn"))
			var cb: Callable = bd.get("cb", Callable())
			var keep := bool(bd.get("keep", false))
			b.pressed.connect(func() -> void:
				# 닫히는 창의 단추는 한 번만 (같은 프레임 연타 — 창은 다음 프레임에 사라짐)
				if ov.get_meta("fired", false):
					return
				if not keep:
					ov.set_meta("fired", true)
					_close_modal_node(ov, false)
				if cb.is_valid():
					cb.call())
			br.add_child(b)
			if first == null:
				first = b
	_modals.append({"root": ov, "on_close": opts.get("on_close", Callable()), "scroll": sc, "content": content, "max_h": max_h, "no_esc": bool(opts.get("no_esc", false))})
	_fit_modal.call_deferred(ov)
	if first != null:
		first.grab_focus.call_deferred()
	return ov


## 내용 높이에 맞춰 스크롤 칸 높이 (최대 화면의 85%)
func _fit_modal(ov: Control) -> void:
	for m: Dictionary in _modals:
		if m["root"] == ov:
			var sc: ScrollContainer = m["scroll"]
			var ch: Control = m["content"]
			if not is_instance_valid(ch):
				return
			sc.custom_minimum_size.y = minf(ch.get_combined_minimum_size().y, maxf(120.0, float(m["max_h"])))


func close_modal() -> void:
	if _modals.is_empty():
		return
	_close_modal_node(_modals.back()["root"], true)


func _close_modal_node(ov: Control, call_close: bool) -> void:
	for i in _modals.size():
		if _modals[i]["root"] == ov:
			var m: Dictionary = _modals[i]
			_modals.remove_at(i)
			ov.queue_free()
			var oc: Callable = m["on_close"]
			if call_close and oc.is_valid():
				oc.call()
			return


func close_all_modals() -> void:
	while not _modals.is_empty():
		var m: Dictionary = _modals.pop_back()
		(m["root"] as Control).queue_free()


## 웹 showAlert (확인 단추 하나)
func alert(msg: String, cb: Callable = Callable()) -> Control:
	return open_modal(_msg_label(msg), {"name": "Alert", "buttons": [{"text": t("common.confirm"), "cb": cb, "name": "Ok"}], "on_close": cb})


## 웹 showConfirm (확인 · 취소)
func confirm(msg: String, yes: Callable, no: Callable = Callable()) -> Control:
	return open_modal(_msg_label(msg), {"name": "Confirm", "title": t("common.confirm"),
		"buttons": [{"text": t("common.confirm"), "cb": yes, "name": "Yes"}, {"text": t("common.cancel"), "cb": no, "secondary": true, "name": "No"}], "on_close": no})


func _msg_label(msg: String) -> Label:
	var l := OKit.label(16, OKit.TEXT, 500)
	l.text = icons.call("strip", msg.replace("<br>", "\n"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# ── 알림 (웹 .toast: 아래 가운데, 3초 뒤 사라짐) ──

func toast(msg: String, kind: String = "") -> void:
	if _toast != null and is_instance_valid(_toast):
		_toast.name = "ToastOld"   # 새 알림이 'Toast' 이름을 갖게 (같은 이름이면 자동 이름으로 바뀜)
		_toast.queue_free()
	var p := PanelContainer.new()
	p.name = "Toast"
	var border := Color(1, 1, 1, 0.15)
	var fg := Color.WHITE
	if kind == "ok":
		border = Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.5)
		fg = Color("86efac")
	elif kind == "warn":
		border = Color(249 / 255.0, 115 / 255.0, 22 / 255.0, 0.6)
		fg = Color("fdba74")
	var sb := OKit.box(Color(17 / 255.0, 24 / 255.0, 39 / 255.0, 0.92), border, 999, 1, 14, 8)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := OKit.label(13, fg, 700)
	l.text = msg
	p.add_child(l)
	layer.add_child(p)
	_toast = p
	p.reset_size()
	var vs := get_viewport_rect().size
	p.position = Vector2((vs.x - p.get_combined_minimum_size().x) * 0.5, vs.y - 84.0 - 40.0)
	var tw := p.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


# ── 공용 표시 ──

## 골드 배지 (웹 .gold-badge: 금화 그림 + 'N G')
func gold_badge(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "GoldBadge"
	var sb := OKit.box(Color(OKit.GOLD, 0.08), Color(OKit.GOLD, 0.25), 20, 1, 22, 6)
	sb.shadow_color = Color(OKit.GOLD, 0.1)
	sb.shadow_size = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := OKit.hbox(6)
	p.add_child(h)
	h.add_child(OKit.tex_rect(icons.call("image", "icon/64x64/fc131.png"), Vector2(20, 20)))
	var l := OKit.label(18, OKit.GOLD, 700)
	l.name = "Gold"
	l.text = text
	h.add_child(l)
	return p


## 직업 아이콘 (웹 clsIcon: image/icon/jab/<직업>.png)
func cls_icon(cls: String, sz: float) -> TextureRect:
	return OKit.tex_rect(icons.call("image", "icon/jab/%s.png" % cls), Vector2(sz, sz))


## 캐릭터 그림 (웹 charSprite: image/character/<직업>_01|02.png)
func char_sprite(cls: String, gender: String, sz: float) -> TextureRect:
	var r := OKit.tex_rect(icons.call("char_tex", cls, gender), Vector2(sz, sz * 1087.0 / 962.0))
	return r


## 이모지 → 그림 (웹 EmojiIcons) — 그림이 없으면 null
func emoji_tex(e: String) -> Texture2D:
	return icons.call("emoji", e)


## 클랜원 이름 (customName → character.names[nameId] → 직업 아이콘 글자)
func char_name(ch: Dictionary) -> String:
	if Js.truthy(ch.get("customName")):
		return str(ch["customName"])
	var names: Variant = i18n.call("t_raw", "character.names") if i18n != null else null
	var nid: Variant = ch.get("nameId")
	if names is Array and (typeof(nid) == TYPE_INT or typeof(nid) == TYPE_FLOAT) and int(nid) >= 0 and int(nid) < (names as Array).size():
		return str(names[int(nid)])
	return "???"


func names_total() -> int:
	var names: Variant = i18n.call("t_raw", "character.names") if i18n != null else null
	return (names as Array).size() if names is Array else 0


## 글 속 이모지를 그림으로 (웹 EmojiIcons) — 글·그림 조각을 가로로. 그림이 없는 이모지는 지움
func emoji_row(text: String, size: int, col: Color, w: int = 0) -> HBoxContainer:
	var h := OKit.hbox(3)
	for p: Variant in icons.call("split", text):
		if typeof(p) == TYPE_STRING:
			var s := str(p).strip_edges()
			if s == "":
				continue
			var l := OKit.label(size, col, w)
			l.text = s
			l.name = "Text"
			h.add_child(l)
		elif p != null:
			var tr := OKit.tex_rect(p, Vector2(roundf(size * 1.2), roundf(size * 1.2)))
			tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(tr)
	return h


## 단추 글자: 이모지는 단추 그림(icon)으로, 글은 이모지를 뺀 것
func set_button_text(b: Button, text: String, icon_px: int = 16) -> void:
	var tex: Texture2D = null
	for p: Variant in icons.call("split", text):
		if p is Texture2D:
			tex = p
			break
	b.icon = tex
	b.add_theme_constant_override("icon_max_width", icon_px)
	b.text = icons.call("strip", text)


## 웹 Date — 기기 현지 날짜 (요일 던전)
static func local_date() -> Dictionary:
	return Time.get_date_dict_from_system()
