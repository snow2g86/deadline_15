extends CanvasLayer
## 전투 화면 UI (3b) — 웹 battle.html 의 화면 부품을 한 층에:
##   윗줄(hud_top) · 행동 순서(hud_order) · 클랜원 카드(hud_cards) · 미니맵(hud_minimap) · 카메라 방향(#cam-dir) · 설정(hud_settings)
##   · 행동 메뉴(#action-menu) · 안내 줄 · 웨이브 띠(#wave-banner) · 스테이지 소개 · 차례 번쩍임(#turn-flash) · 툴팁·적 팝업(hud_info)
##   · 결과(result_view) · 스토리 대사(story_view) · 로딩(loading_view)
##  규칙은 모름: 장면(battle_scene.gd)이 넘겨 준 모델을 그리고, 누르면 신호만 보냄.

const Kit := preload("res://scripts/battle/ui_kit.gd")
const Icons := preload("res://scripts/battle/icons.gd")
const HudTop := preload("res://scripts/battle/hud_top.gd")
const HudOrder := preload("res://scripts/battle/hud_order.gd")
const HudCards := preload("res://scripts/battle/hud_cards.gd")
const HudMinimap := preload("res://scripts/battle/hud_minimap.gd")
const HudInfo := preload("res://scripts/battle/hud_info.gd")
const HudSettings := preload("res://scripts/battle/hud_settings.gd")
const ResultView := preload("res://scripts/battle/result_view.gd")
const LoadingView := preload("res://scripts/battle/loading_view.gd")
const StoryView := preload("res://scripts/battle/story_view.gd")
const Iso := preload("res://scripts/battle/iso.gd")

signal action_pressed(op: String)
signal skill_pressed(idx: int)
signal item_pressed(kind: String, idx: int)
signal cancel_pressed
signal rotate_pressed(dir: int)
signal threat_pressed
signal speed_pressed
signal back_pressed

const GOLD := Color("f0c040")
## 버튼 강조색 (웹 .ac-move · ac-attack · ac-skill · ac-item · ac-wait · ac-cancel)
const AC := {"move": Color("3b82f6"), "attack": Color("ef4444"), "skill": Color("a855f7"), "item": Color("22c55e"), "wait": Color("9ca3af"), "cancel": Color("64748b")}
const TOP_H := 58.0
const CARDS_H := 130.0

var i18n: Node
var icons: Icons
var root: Control
var top: HudTop
var order: HudOrder
var cards: HudCards
var minimap: HudMinimap
var info: HudInfo
var settings: HudSettings
var result_view: ResultView
var loading: LoadingView
var story: StoryView
var compass: VBoxContainer
var compass_arrow: Label
var compass_label: Label
var menu: PanelContainer
var menu_box: VBoxContainer
var hint: Label
var banner: Control            # 웹 #wave-banner
var banner_lbl: Label
var stage_banner: Control       # 스테이지 소개 (Godot)
var stage_banner_lbl: Label
var stage_banner_sub: Label
var flash: ColorRect
var _flash_mat: ShaderMaterial
var _banner_t := 0.0
var _banner_hold := false
var _stage_t := 9.0
var _flash_t := 9.0
var _flash_dur := 0.6
var _flash_peak := 0.3
var _menu_at := Vector2.ZERO
var _menu_flip := false
var _menu_pop := 9.0
var menu_buttons: Array = []   # 시험·단축키용: {op, button, key, item}
var reduce_motion := false
## 결과 화면 호환 (3a 시험이 result_panel.visible 을 볼 수 있게)
var result_panel: Control:
	get:
		return result_view


func _init() -> void:
	layer = 10


func setup(p_i18n: Node, p_icons: Icons, store: Node) -> void:
	i18n = p_i18n
	icons = p_icons
	var th := Theme.new()
	th.default_font = Kit.font()
	th.default_font_size = 14
	# 툴팁 모양 (웹 title 대신 — 어두운 상자)
	th.set_stylebox("panel", "TooltipPanel", Kit.box(Color(10 / 255.0, 14 / 255.0, 26 / 255.0, 0.96), Color(1, 1, 1, 0.18), 6, 1, 9, 6))
	th.set_color("font_color", "TooltipLabel", Color("e5e7eb"))
	th.set_font_size("font_size", "TooltipLabel", 12)
	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = th
	add_child(root)

	# 차례 번쩍임 (웹 #turn-flash: 화면 가운데 퍼지는 빛 radial-gradient(ellipse, 색, transparent 70%))
	flash = ColorRect.new()
	flash.name = "TurnFlash"
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform vec4 col : source_color = vec4(0.23,0.51,0.96,0.15);\nuniform float amt = 0.0;\nvoid fragment(){ vec2 d = (UV - vec2(0.5)) * 2.0; float r = length(d); COLOR = vec4(col.rgb, col.a * amt * (1.0 - smoothstep(0.0, 0.7 * 1.4142, r))); }"
	_flash_mat.shader = sh
	flash.material = _flash_mat
	flash.visible = false
	root.add_child(flash)

	top = HudTop.new()
	top.setup(icons)
	top.threat_pressed.connect(func() -> void: threat_pressed.emit())
	top.rotate_pressed.connect(func(d: int) -> void: rotate_pressed.emit(d))
	top.speed_pressed.connect(func() -> void: speed_pressed.emit())
	root.add_child(top)

	minimap = HudMinimap.new()
	root.add_child(minimap)
	minimap.position = Vector2(12, TOP_H + 8.0)

	order = HudOrder.new()
	order.setup()
	order.icons = icons
	root.add_child(order)
	order.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	order.offset_left = -190
	order.offset_right = -10
	order.offset_top = TOP_H + 14.0

	cards = HudCards.new()
	cards.setup(icons)
	root.add_child(cards)

	# 카메라 방향 (웹 #cam-dir: ▲ + N)
	compass = VBoxContainer.new()
	compass.name = "CamDir"
	compass.add_theme_constant_override("separation", 0)
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	compass.offset_left = -50
	compass.offset_right = -14
	compass.offset_top = -CARDS_H - 62.0
	compass.offset_bottom = -CARDS_H - 14.0
	root.add_child(compass)
	compass_arrow = Kit.label(24, GOLD, 800)
	compass_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.outline(compass_arrow, 6, Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.18))
	compass.add_child(compass_arrow)
	compass_label = Kit.label(11, Kit.DIM, 700)
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass.add_child(compass_label)

	# 웨이브 띠 (웹 #wave-banner: 붉은 띠 가운데 진하게, 위아래 금빛 선, 세로로 펼쳐짐)
	banner = Control.new()
	banner.name = "WaveBanner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.visible = false
	banner.draw.connect(_draw_banner)
	root.add_child(banner)
	banner_lbl = Kit.label(24, Color("fff3c4"), 900)
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Kit.outline(banner_lbl, 6, Color(0, 0, 0, 0.6))
	banner.add_child(banner_lbl)

	# 스테이지 소개 (Godot: 로딩이 걷히면 잠깐 — 웹은 로딩 화면 제목뿐)
	stage_banner = VBoxContainer.new()
	stage_banner.name = "StageBanner"
	stage_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	stage_banner.offset_left = -400
	stage_banner.offset_right = 400
	stage_banner.offset_top = 150
	stage_banner.visible = false
	(stage_banner as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(stage_banner)
	stage_banner_sub = Kit.label(14, Color("fde68a"), 800)
	stage_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.outline(stage_banner_sub, 6)
	stage_banner.add_child(stage_banner_sub)
	stage_banner_lbl = Kit.label(30, GOLD, 900)
	stage_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.outline(stage_banner_lbl, 8)
	stage_banner.add_child(stage_banner_lbl)

	# 행동 메뉴
	menu = PanelContainer.new()
	menu.name = "ActionMenu"
	var msb := Kit.box(Color(16 / 255.0, 21 / 255.0, 33 / 255.0, 0.97), Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.45), 10, 1, 6, 6)
	msb.shadow_color = Color(0, 0, 0, 0.65)
	msb.shadow_size = 14
	msb.shadow_offset = Vector2(0, 6)
	menu.add_theme_stylebox_override("panel", msb)
	menu.visible = false
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.draw.connect(_draw_menu_tail)
	root.add_child(menu)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 3)
	menu.add_child(menu_box)

	# 안내 줄
	hint = Kit.label(14, Color("fde68a"), 800)
	hint.name = "Hint"
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -CARDS_H - 40.0
	hint.offset_bottom = -CARDS_H - 12.0
	hint.offset_left = -400
	hint.offset_right = 400
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.outline(hint, 6, Color(0, 0, 0, 0.9))
	root.add_child(hint)

	info = HudInfo.new()
	info.setup(icons)
	root.add_child(info)

	settings = HudSettings.new()
	settings.setup(store, i18n)
	root.add_child(settings)

	result_view = ResultView.new()
	result_view.setup(icons)
	root.add_child(result_view)

	story = StoryView.new()
	story.setup()
	root.add_child(story)

	loading = LoadingView.new()
	loading.setup()
	loading.visible = false
	root.add_child(loading)
	relabel()
	root.resized.connect(_on_resized)
	_on_resized()



func _on_resized() -> void:
	var vs := root.size
	if vs.x <= 0.0:
		return
	settings.place(vs.y - CARDS_H - 16.0)
	# 행동 순서: 윗줄 아래부터 카메라 방향 표시 위까지 (현재 줄 50px + 나머지 46px)
	var avail := vs.y - (TOP_H + 14.0) - 18.0 - CARDS_H - 70.0
	order.max_rows = maxi(3, 1 + int(floorf((avail - 54.0) / 46.0)))
	banner.offset_top = vs.y * 0.4 - 32.0
	banner.offset_bottom = vs.y * 0.4 + 32.0


func _t(key: String, p: Dictionary = {}) -> String:
	return i18n.t(key, p) if i18n != null else key


## 언어가 바뀌면 글만 다시 (장면이 모델 갱신도 다시 부름)
func relabel() -> void:
	top.set_tooltips(_t)
	order.set_head(_t("battle.turn_order"))
	settings.relabel()


func _process(delta: float) -> void:
	if banner.visible:
		if not _banner_hold:
			_banner_t -= delta
		var a := clampf(_banner_t / 0.3, 0.0, 1.0) if not _banner_hold else 1.0
		banner.modulate.a = a
		banner.scale.y = lerpf(banner.scale.y, 1.0, minf(1.0, delta * 14.0))
		if _banner_t <= 0.0 and not _banner_hold:
			banner.visible = false
	if stage_banner.visible:
		_stage_t += delta
		var k := _stage_t / 2.2
		stage_banner.modulate.a = clampf(minf(_stage_t / 0.35, (2.2 - _stage_t) / 0.5), 0.0, 1.0)
		stage_banner.position.y = 150.0 - 10.0 * (1.0 - clampf(_stage_t / 0.35, 0.0, 1.0))
		if k >= 1.0:
			stage_banner.visible = false
	if flash.visible:
		_flash_t += delta
		var k2 := _flash_t / _flash_dur
		# 웹 turnFlash: 0 → 30% 최대 → 100% 0
		var amt := k2 / _flash_peak if k2 < _flash_peak else 1.0 - (k2 - _flash_peak) / (1.0 - _flash_peak)
		_flash_mat.set_shader_parameter("amt", clampf(amt, 0.0, 1.0))
		if k2 >= 1.0:
			flash.visible = false
	if menu.visible and _menu_pop < 0.16:
		_menu_pop += delta
		var e := clampf(_menu_pop / 0.16, 0.0, 1.0)
		menu.modulate.a = e
		menu.scale = Vector2.ONE * lerpf(0.96, 1.0, e)


# ── 윗줄 · 카메라 방향 ──

func update_top(m: Dictionary) -> void:
	top.update(m)


func set_cam(arrow: String, label: String) -> void:
	compass_arrow.text = arrow
	compass_label.text = label


func set_speed_label(s: String) -> void:
	top.set_speed(s)


func set_threat(on: bool) -> void:
	top.set_threat(on)


func show_hint(s: String) -> void:
	hint.text = s


# ── 띠·번쩍임 ──

## 웨이브 알림 (웹 showWv — wave_announce_end 에서 hideWv). hold=false 면 secs 뒤 저절로
func show_banner(s: String, secs: float = 1.6, hold: bool = false) -> void:
	banner_lbl.text = icons.strip(s)
	banner.visible = true
	_banner_hold = hold
	_banner_t = secs
	banner.modulate.a = 1.0
	banner.pivot_offset = Vector2(0, banner.size.y / 2.0)
	banner.scale.y = 1.0 if reduce_motion else 0.05
	banner.queue_redraw()


func hide_banner() -> void:
	_banner_hold = false
	_banner_t = minf(_banner_t, 0.3)


func _draw_banner() -> void:
	var w := banner.size.x
	var h := banner.size.y
	var c0 := Color(120 / 255.0, 20 / 255.0, 20 / 255.0, 0.0)
	var c1 := Color(120 / 255.0, 20 / 255.0, 20 / 255.0, 0.85)
	var c2 := Color(160 / 255.0, 30 / 255.0, 30 / 255.0, 0.92)
	var xs := [0.0, 0.2, 0.5, 0.8, 1.0]
	var cs := [c0, c1, c2, c1, c0]
	for i in 4:
		var x0: float = xs[i] * w
		var x1: float = xs[i + 1] * w
		banner.draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, h), Vector2(x0, h)]), PackedColorArray([cs[i], cs[i + 1], cs[i + 1], cs[i]]))
	var gl := Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.5)
	banner.draw_line(Vector2(0, 0), Vector2(w, 0), gl, 1.0)
	banner.draw_line(Vector2(0, h - 1), Vector2(w, h - 1), gl, 1.0)


func show_stage_banner(sub: String, title: String) -> void:
	stage_banner_sub.text = sub
	stage_banner_lbl.text = title
	stage_banner.visible = true
	_stage_t = 0.0
	stage_banner.modulate.a = 0.0


## 차례 번쩍임 (웹 turnFlash: 아군 파랑·적 빨강 .6s) · 스킬 번쩍임 (vfxFlash .4s)
func turn_flash(phase: String) -> void:
	if reduce_motion:
		return
	_flash_mat.set_shader_parameter("col", Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.15) if phase == "player" else Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.15))
	_flash_t = 0.0
	_flash_dur = 0.6
	_flash_peak = 0.3
	flash.visible = true


func big_flash(col: Color, secs: float = 0.4) -> void:
	if reduce_motion:
		return
	_flash_mat.set_shader_parameter("col", col)
	_flash_t = 0.0
	_flash_dur = secs
	_flash_peak = 0.15
	flash.visible = true


# ── 행동 메뉴 (웹 #action-menu · _amBtn: [아이콘][이름 + 보조줄][단축키]) ──

func hide_menu() -> void:
	menu.visible = false
	menu_buttons.clear()


## items: [{op, tex?, frame?, glyph, label, sub, key, ac, enabled, warn, tip, idx?, kind?}] — at: 유닛 화면 위치 (메뉴는 오른쪽, 행동 순서 패널과 겹치면 왼쪽)
func show_menu(head: String, items: Array, at: Vector2) -> void:
	var was := menu.visible
	for c: Node in menu_box.get_children():
		menu_box.remove_child(c)
		c.queue_free()
	menu_buttons.clear()
	if head != "":
		var h := Kit.label(10, GOLD, 900)
		h.text = head
		h.add_theme_constant_override("outline_size", 0)
		var hp := PanelContainer.new()
		var hsb := StyleBoxFlat.new()
		hsb.bg_color = Color(0, 0, 0, 0)
		hsb.border_color = Color(1, 1, 1, 0.08)
		hsb.border_width_bottom = 1
		hsb.content_margin_left = 6
		hsb.content_margin_bottom = 4
		hsb.content_margin_top = 2
		hp.add_theme_stylebox_override("panel", hsb)
		hp.add_child(h)
		menu_box.add_child(hp)
	for it: Dictionary in items:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(184, 38)
		var ac: Color = AC.get(str(it.get("ac", "wait")), AC["wait"])
		var sb := Kit.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6, 1, 5, 3)
		var sbh := Kit.box(Color(1, 1, 1, 0.06), Color(ac, 0.55), 6, 1, 5, 3)
		var sbd := Kit.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6, 1, 5, 3)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		b.add_theme_stylebox_override("disabled", sbd)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.tooltip_text = str(it.get("tip", ""))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 5
		row.offset_right = -8
		row.add_theme_constant_override("separation", 10)
		b.add_child(row)
		var en: bool = it.get("enabled", true)
		# 아이콘 상자 (웹 .am-ic: 강조색 22% 바탕 + 45% 테두리)
		var icb := PanelContainer.new()
		icb.custom_minimum_size = Vector2(28, 28)
		icb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icb.add_theme_stylebox_override("panel", Kit.box(Color(ac, 0.22), Color(ac, 0.45), 6, 1, 0, 0))
		icb.modulate.a = 1.0 if en else 0.4
		row.add_child(icb)
		var tex: Variant = it.get("tex")
		if tex is Texture2D:
			var ir := Kit.IconRect.new()
			ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ir.custom_minimum_size = Vector2(22, 22)
			ir.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			ir.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var fr: Variant = it.get("frame")
			ir.set_icon(tex, fr if fr is Texture2D else null, not bool(it.get("framed", false)))
			icb.add_child(ir)
		else:
			var ic := Kit.label(15, ac.lightened(0.35), 900)
			ic.text = str(it.get("glyph", ""))
			ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icb.add_child(ic)
		var tx := VBoxContainer.new()
		tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tx.alignment = BoxContainer.ALIGNMENT_CENTER
		tx.add_theme_constant_override("separation", -3)
		row.add_child(tx)
		var lb := Kit.label(14, Color("f3f4f6") if en else Color(243 / 255.0, 244 / 255.0, 246 / 255.0, 0.4), 700)
		lb.text = icons.strip(str(it.get("label", "")))
		tx.add_child(lb)
		var sub := str(it.get("sub", ""))
		if sub != "":
			var sl := Kit.label(10, Color("f87171") if it.get("warn", false) else Color("9ca3af"), 500)
			sl.text = icons.strip(sub)
			tx.add_child(sl)
		var key := str(it.get("key", ""))
		if key != "":
			var kp := PanelContainer.new()
			kp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			kp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var ksb := Kit.box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.12), 4, 1, 4, 0)
			ksb.border_width_bottom = 2
			kp.add_theme_stylebox_override("panel", ksb)
			var kl := Kit.label(10, Color("9ca3af"), 700)
			kl.text = key
			kp.add_child(kl)
			row.add_child(kp)
		b.disabled = not en
		var op := str(it["op"])
		if op == "skill_pick":
			var idx := int(it["idx"])
			b.pressed.connect(func() -> void: skill_pressed.emit(idx))
		elif op == "item_pick":
			var k2 := str(it["kind"])
			var i2 := int(it["idx"])
			b.pressed.connect(func() -> void: item_pressed.emit(k2, i2))
		elif op == "cancel":
			b.pressed.connect(func() -> void: cancel_pressed.emit())
		else:
			b.pressed.connect(func() -> void: action_pressed.emit(op))
		if op == "cancel" or op == "undo":
			var sep := ColorRect.new()
			sep.color = Color(1, 1, 1, 0.06)
			sep.custom_minimum_size = Vector2(0, 1)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu_box.add_child(sep)
		menu_box.add_child(b)
		menu_buttons.append({"op": op, "button": b, "key": key.to_lower(), "item": it})
	# 단추 폭: 가장 긴 이름·보조 줄에 맞춤 (스페인어 등 긴 글이 잘리지 않게, 최소 184) — 줄(HBox)의 최소 폭 + 좌우 여백
	var need := 184.0
	for mb: Dictionary in menu_buttons:
		var row0: Control = (mb["button"] as Button).get_child(0)
		need = maxf(need, row0.get_combined_minimum_size().x + 5.0 + 8.0 + 4.0)
	need = minf(need, 360.0)
	for mb2: Dictionary in menu_buttons:
		(mb2["button"] as Button).custom_minimum_size.x = need
	_menu_at = at
	menu.visible = true
	if not was and not reduce_motion:
		_menu_pop = 0.0
		menu.modulate.a = 0.0
	else:
		_menu_pop = 9.0
		menu.modulate.a = 1.0
	menu.scale = Vector2.ONE
	place_menu(at)


## 메뉴 자리: 유닛 오른쪽 → 행동 순서 패널과 겹치면 유닛 왼쪽 (웹 _placeAM), 위아래는 윗줄·카드 사이
func place_menu(at: Vector2) -> void:
	_menu_at = at
	menu.reset_size()
	var sz := menu.get_combined_minimum_size()
	menu.size = sz
	var vs := root.size
	var limit := vs.x - 200.0 - 8.0
	var pos := at + Vector2(38, -22)
	_menu_flip = pos.x + sz.x > limit
	if _menu_flip:
		pos.x = at.x - 38.0 - sz.x
	pos.y = clampf(pos.y, TOP_H + 8.0, vs.y - CARDS_H - sz.y - 8.0)
	pos.x = clampf(pos.x, 8.0, vs.x - sz.x - 8.0)
	menu.position = pos
	menu.pivot_offset = Vector2(sz.x if _menu_flip else 0.0, 22.0)
	menu.queue_redraw()


## 유닛 쪽을 가리키는 꼬리 (웹 #action-menu::before — 45° 돌린 작은 네모)
func _draw_menu_tail() -> void:
	var y := clampf(_menu_at.y - menu.position.y, 14.0, menu.size.y - 14.0)
	var x := menu.size.x if _menu_flip else 0.0
	var d := 6.0
	var pts := PackedVector2Array([Vector2(x, y - d), Vector2(x + (d if _menu_flip else -d), y), Vector2(x, y + d)])
	menu.draw_colored_polygon(pts, Color(20 / 255.0, 26 / 255.0, 40 / 255.0, 0.97))
	menu.draw_polyline(pts, Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.45), 1.0, true)


## 단축키로 메뉴 단추 누르기 (웹 data-key) — 눌렀으면 true
func press_key(k: String) -> bool:
	if not menu.visible:
		return false
	for mb: Dictionary in menu_buttons:
		var b: Button = mb["button"]
		if mb["key"] == k and not b.disabled:
			b.pressed.emit()
			return true
	return false


## 마우스가 HUD 위에 있는가 (그럼 맵 툴팁·클릭을 하지 않음)
func over_hud(p: Vector2) -> bool:
	for c: Control in [top, order, cards, minimap, menu, settings.btn, settings.panel, info.popup]:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	if settings.backdrop.visible or result_view.visible or story.visible or loading.visible:
		return true
	return false


# ── 결과 ──

func show_result(m: Dictionary) -> void:
	hide_menu()
	info.hide_tip()
	info.hide_popup()
	result_view.reduce_motion = reduce_motion
	result_view.show_result(m)
