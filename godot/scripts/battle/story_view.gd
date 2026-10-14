extends Control
## 스토리 대사 창 — 웹 js/common/story.js (Story.play·_next·_advance·_skip) + css/story.css
##  전투 대사(battle)는 맵이 비치게 아래만 어둡게·작은 창, 전투 전·후 장면은 어둡게·제목·큰 창
##  양쪽 초상화(말하는 쪽만 밝게·살짝 위로), 이름표(왼쪽/오른쪽·보스는 붉게), 한 글자씩(28ms), 감정(흔들림·색), ▼ 깜빡임, 건너뛰기
##  누르기·Space·Enter·→ = 다음(출력 중이면 즉시 완성), Esc = 건너뛰기. auto(시험) 면 프레임마다 저절로 넘김
##  줄 형식(장면이 풀어서 넘김): {narr, side, key, name, tex, boss, art, ghost, mood, text}

const Kit := preload("res://scripts/battle/ui_kit.gd")
const PortraitShader := preload("res://scripts/battle/shaders/portrait.gdshader")

signal closed
signal line_shown(idx: int)

const TYPE_MS := 28.0

var dim: Control
var glow: TextureRect
var title_lbl: Label
var skip_btn: Button
var scene_box: Control
var pts: Dictionary = {}     # "left"/"right" → {box: Control, img: TextureRect, mat, key}
var box: PanelContainer
var name_tag: PanelContainer
var name_lbl: Label
var text_lbl: Label
var next_lbl: Label
var active := false
var auto := false
## auto 일 때 줄마다 기다릴 초 (0 = 프레임마다 — 시험, >0 = 자동 재생 화면 확인용)
var auto_delay := 0.0
var _auto_t := 0.0
var battle_mode := false
var _lines: Array = []
var _idx := -1
var _full := ""
var _shown := 0
var _typing := false
var _type_t := 0.0
var _t := 0.0
var _shake_t := 9.0
var _closing := false


func setup() -> void:
	name = "Story"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	dim = Control.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.draw.connect(_draw_dim)
	add_child(dim)
	# 웹 .st-dim: radial-gradient(ellipse at 50% 35%, rgba(30,41,80,.55), transparent 70%) — 전투 대사 때는 숨김
	var g := Gradient.new()
	g.set_color(0, Color(30 / 255.0, 41 / 255.0, 80 / 255.0, 0.55))
	g.set_color(1, Color(30 / 255.0, 41 / 255.0, 80 / 255.0, 0.0))
	g.set_offset(1, 0.7)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.35)
	gt.fill_to = Vector2(1.2, 0.35)
	gt.width = 256
	gt.height = 256
	glow = TextureRect.new()
	glow.texture = gt
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	title_lbl = Kit.label(15, Color("fbbf24"), 900)
	title_lbl.position = Vector2(26, 14)
	add_child(title_lbl)
	skip_btn = Kit.button("", Color("f59e0b"), 12)
	skip_btn.name = "Skip"
	skip_btn.add_theme_stylebox_override("normal", Kit.box(Color(15 / 255.0, 23 / 255.0, 42 / 255.0, 0.8), Color(148 / 255.0, 163 / 255.0, 184 / 255.0, 0.35), 999, 1, 14, 6))
	skip_btn.add_theme_stylebox_override("hover", Kit.box(Color(30 / 255.0, 41 / 255.0, 59 / 255.0, 0.9), Color("f59e0b"), 999, 1, 14, 6))
	skip_btn.tooltip_text = "Esc"
	skip_btn.pressed.connect(skip)
	add_child(skip_btn)
	scene_box = Control.new()
	scene_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scene_box)
	for side: String in ["left", "right"]:
		var c := Control.new()
		c.clip_contents = true
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scene_box.add_child(c)
		var img := TextureRect.new()
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		img.flip_h = side == "right"   # 오른쪽 인물은 안쪽(왼쪽)을 보게
		var mat := ShaderMaterial.new()
		mat.shader = PortraitShader
		img.material = mat
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(img)
		c.modulate.a = 0.0
		pts[side] = {"box": c, "img": img, "mat": mat, "key": "", "speaking": false, "enter": 9.0, "show": false}
	box = PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_box.add_child(box)
	var bm := MarginContainer.new()
	bm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bm)
	text_lbl = Kit.label(17, Color("e2e8f0"), 500)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.add_theme_constant_override("line_spacing", 6)
	bm.add_child(text_lbl)
	next_lbl = Kit.label(11, Color("f59e0b"), 700)
	next_lbl.text = "▼"
	scene_box.add_child(next_lbl)
	name_tag = PanelContainer.new()
	name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_box.add_child(name_tag)
	name_lbl = Kit.label(14, Color("1a1206"), 900)
	name_tag.add_child(name_lbl)
	box.draw.connect(func() -> void:
		# 웹 .st-box::before: 금색 위 장식선
		var w := box.size.x
		var pl := PackedVector2Array([Vector2(18, 0), Vector2(w * 0.5, 0), Vector2(w - 18, 0), Vector2(w - 18, 2), Vector2(w * 0.5, 2), Vector2(18, 2)])
		var a := 0.35 if _cur_narr() else 0.7
		box.draw_polygon(pl, PackedColorArray([Color(0.96, 0.62, 0.04, 0), Color(0.96, 0.62, 0.04, a), Color(0.96, 0.62, 0.04, 0), Color(0.96, 0.62, 0.04, 0), Color(0.96, 0.62, 0.04, a), Color(0.96, 0.62, 0.04, 0)])))


func _draw_dim() -> void:
	var s := dim.size
	if battle_mode:
		# 전투 대사: 맵이 비치도록 아래쪽만 (5% → 55% → 85%)
		dim.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.3), Vector2(0, s.y * 0.3)]), PackedColorArray([Color(0.02, 0.03, 0.07, 0.05), Color(0.02, 0.03, 0.07, 0.05), Color(0.02, 0.03, 0.07, 0.05), Color(0.02, 0.03, 0.07, 0.05)]))
		dim.draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.3), Vector2(s.x, s.y * 0.3), Vector2(s.x, s.y * 0.62), Vector2(0, s.y * 0.62)]), PackedColorArray([Color(0.02, 0.03, 0.07, 0.05), Color(0.02, 0.03, 0.07, 0.05), Color(0.02, 0.03, 0.07, 0.55), Color(0.02, 0.03, 0.07, 0.55)]))
		dim.draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.62), Vector2(s.x, s.y * 0.62), Vector2(s.x, s.y), Vector2(0, s.y)]), PackedColorArray([Color(0.02, 0.03, 0.07, 0.55), Color(0.02, 0.03, 0.07, 0.55), Color(0.02, 0.03, 0.07, 0.85), Color(0.02, 0.03, 0.07, 0.85)]))
	else:
		dim.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(0, s.y)]), PackedColorArray([Color(0.02, 0.03, 0.07, 0.88), Color(0.02, 0.03, 0.07, 0.88), Color(0.02, 0.03, 0.07, 0.96), Color(0.02, 0.03, 0.07, 0.96)]))


## lines: 풀어 둔 줄 배열, opts: {title, battle, skip_text}
func play(lines: Array, opts: Dictionary) -> void:
	_lines = lines
	_idx = -1
	battle_mode = bool(opts.get("battle", false))
	title_lbl.text = str(opts.get("title", ""))
	title_lbl.visible = not battle_mode and title_lbl.text != ""
	skip_btn.text = str(opts.get("skip_text", "Skip")) + "  ▶▶"
	for side: String in pts.keys():
		var p: Dictionary = pts[side]
		p["key"] = ""
		p["show"] = false
		p["speaking"] = false
		(p["box"] as Control).modulate.a = 0.0
	active = true
	_closing = false
	visible = true
	modulate.a = 1.0
	_layout()
	dim.queue_redraw()
	glow.visible = not battle_mode
	_next()


func _layout() -> void:
	var vs := get_viewport_rect().size
	var w := minf(640.0 if battle_mode else 820.0, vs.x - 24.0)
	var bottom := 140.0 if battle_mode else 14.0
	var bh := 84.0 if battle_mode else 112.0
	scene_box.position = Vector2((vs.x - w) / 2.0, vs.y - bottom - bh)
	scene_box.size = Vector2(w, bh)
	box.position = Vector2.ZERO
	box.size = Vector2(w, bh)
	box.custom_minimum_size = Vector2(w, bh)
	(box.get_child(0) as MarginContainer).add_theme_constant_override("margin_left", 18 if battle_mode else 22)
	(box.get_child(0) as MarginContainer).add_theme_constant_override("margin_right", 18 if battle_mode else 22)
	(box.get_child(0) as MarginContainer).add_theme_constant_override("margin_top", 22 if battle_mode else 26)
	(box.get_child(0) as MarginContainer).add_theme_constant_override("margin_bottom", 14 if battle_mode else 18)
	text_lbl.custom_minimum_size = Vector2(w - 44.0, 0)
	var pw := 150.0 if battle_mode else 210.0
	var ph := 160.0 if battle_mode else 230.0
	for side: String in pts.keys():
		var c: Control = pts[side]["box"]
		c.size = Vector2(pw, ph)
		c.position = Vector2(0.0 if side == "left" else w - pw, -ph + 26.0)
		var img: TextureRect = pts[side]["img"]
		var iw := pw * 1.65
		var ih := iw * 1087.0 / 962.0
		img.position = Vector2(-0.32 * pw, -0.06 * ph)   # 오른쪽은 flip_h (웹 scaleX(-1) — 같은 자리에서 뒤집기)
		img.size = Vector2(iw, ih)
		var mat: ShaderMaterial = pts[side]["mat"]
		mat.set_shader_parameter("mask_v0", (0.72 * ph + 0.06 * ph) / ih)
		mat.set_shader_parameter("mask_v1", (1.0 * ph + 0.06 * ph) / ih)
	skip_btn.reset_size()
	# 전투 대사는 맵·윗줄이 비치므로 윗줄 아래에 (전투 전·후 장면은 웹처럼 맨 위)
	skip_btn.position = Vector2(vs.x - skip_btn.get_combined_minimum_size().x - 16.0, 70.0 if battle_mode else 12.0)
	next_lbl.position = Vector2(w - 26.0, bh - 22.0)


func _cur() -> Dictionary:
	return _lines[_idx] if _idx >= 0 and _idx < _lines.size() else {}


func _cur_narr() -> bool:
	return bool(_cur().get("narr", false))


func _next() -> void:
	_idx += 1
	if _idx >= _lines.size():
		_close()
		return
	var ln: Dictionary = _lines[_idx]
	var narr: bool = ln.get("narr", false)
	var side := str(ln.get("side", "left"))
	if not narr:
		if ln.get("tex") != null:
			_set_portrait(side, ln)
		for s2: String in pts.keys():
			pts[s2]["speaking"] = s2 == side and ln.get("tex") != null
		name_lbl.text = str(ln.get("name", ""))
		name_tag.visible = name_lbl.text != ""
		var boss: bool = ln.get("boss", false)
		var nsb := Kit.box(Color("dc2626") if boss else Color("f59e0b"), Color(0, 0, 0, 0), 6, 0, 14, 4)
		nsb.shadow_color = Color(0, 0, 0, 0.45)
		nsb.shadow_size = 4
		name_tag.add_theme_stylebox_override("panel", nsb)
		name_lbl.add_theme_color_override("font_color", Color.WHITE if boss else Color("1a1206"))
		name_tag.reset_size()
		var nw := name_tag.get_combined_minimum_size().x
		name_tag.position = Vector2(18.0 if side == "left" else scene_box.size.x - 18.0 - nw, -15.0)
	else:
		for s3: String in pts.keys():
			pts[s3]["speaking"] = false
		name_tag.visible = false
	var mood := str(ln.get("mood", "normal"))
	var bb := Kit.box(Color(10 / 255.0, 14 / 255.0, 26 / 255.0, 0.88) if narr else Color(15 / 255.0, 23 / 255.0, 42 / 255.0, 0.94),
		Color(148 / 255.0, 163 / 255.0, 184 / 255.0, 0.3) if narr else (Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.6) if ln.get("boss", false) else Color(245 / 255.0, 158 / 255.0, 11 / 255.0, 0.45)), 12, 1, 0, 0)
	bb.shadow_color = Color(0, 0, 0, 0.55)
	bb.shadow_size = 14
	box.add_theme_stylebox_override("panel", bb)
	var col := Color("e2e8f0")
	match mood:
		"angry":
			col = Color("fecaca")
		"worried", "sad":
			col = Color("c7d2fe")
		"happy":
			col = Color("fef3c7")
	if narr:
		col = Color("cbd5e1")
	text_lbl.add_theme_color_override("font_color", col)
	var fs := (15 if battle_mode else 17) + (2 if mood == "shout" else 0)
	text_lbl.add_theme_font_size_override("font_size", fs)
	text_lbl.add_theme_font_override("font", Kit.bold(900 if mood == "shout" else 500))
	text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if narr else HORIZONTAL_ALIGNMENT_LEFT
	if mood == "angry" or mood == "shout":
		_shake_t = 0.0
	_full = str(ln.get("text", ""))
	_shown = 0
	_type_t = 0.0
	_typing = true
	text_lbl.text = ""
	text_lbl.visible_characters = -1
	box.queue_redraw()
	line_shown.emit(_idx)


func _set_portrait(side: String, ln: Dictionary) -> void:
	var p: Dictionary = pts[side]
	var img: TextureRect = p["img"]
	var key := str(ln.get("key", "")) + "|" + str(ln.get("tex"))
	if p["key"] != key:
		img.texture = ln["tex"]
		p["key"] = key
		p["enter"] = 0.0
	var mat: ShaderMaterial = p["mat"]
	mat.set_shader_parameter("boss_tint", 1.0 if (ln.get("boss", false) and not ln.get("art", false)) else 0.0)
	mat.set_shader_parameter("ghost", 1.0 if ln.get("ghost", false) else 0.0)
	p["show"] = true


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	if auto and auto_delay <= 0.0:
		# 시험: 한 프레임에 한 단계 (출력 완성 → 다음 줄)
		advance()
		return
	if auto:
		_auto_t += delta
		if not _typing and _auto_t >= auto_delay:
			_auto_t = 0.0
			advance()
	if _typing:
		_type_t += delta * 1000.0
		var n := mini(_full.length(), int(_type_t / TYPE_MS))
		if n != _shown:
			_shown = n
			text_lbl.text = _full.substr(0, n)
		if n >= _full.length():
			_finish_typing()
	next_lbl.visible = not _typing
	next_lbl.modulate.a = 0.25 + 0.75 * (0.5 - 0.5 * cos(_t * TAU))
	next_lbl.position.y = scene_box.size.y - 22.0 + 3.0 * (0.5 - 0.5 * cos(_t * TAU))
	var narr := _cur_narr()
	for side: String in pts.keys():
		var p: Dictionary = pts[side]
		var c: Control = p["box"]
		var want := 0.0
		if p["show"]:
			want = 0.18 if narr else 1.0
		c.modulate.a = move_toward(c.modulate.a, want, delta / 0.25)
		var mat: ShaderMaterial = p["mat"]
		var sp: bool = p["speaking"] and not narr
		mat.set_shader_parameter("bright", 1.0 if sp else (0.3 if narr else 0.38))
		mat.set_shader_parameter("sat", 1.0 if sp else (0.4 if narr else 0.6))
		var base_x := 0.0 if side == "left" else scene_box.size.x - c.size.x
		p["enter"] = float(p["enter"]) + delta
		var ek := clampf(float(p["enter"]) / 0.3, 0.0, 1.0)
		var off := (1.0 - (1.0 - pow(1.0 - ek, 2.0))) * 24.0 * (-1.0 if side == "left" else 1.0)
		c.position = Vector2(base_x + off, -c.size.y + 26.0 - (4.0 if sp else 0.0))
	if _shake_t < 0.35:
		_shake_t += delta
		var k := _shake_t / 0.35
		box.position.x = sin(k * TAU * 2.5) * 6.0 * (1.0 - k)
	else:
		box.position.x = 0.0


func _finish_typing() -> void:
	_typing = false
	_shown = _full.length()
	text_lbl.text = _full


## 누르기·Space·Enter: 출력 중이면 즉시 완성, 아니면 다음 줄
func advance() -> void:
	if not active:
		return
	if _typing:
		_finish_typing()
	else:
		_next()


func skip() -> void:
	if active:
		_close()


func _close() -> void:
	if not active:
		return
	active = false
	_closing = true
	if auto and auto_delay <= 0.0:
		visible = false
		closed.emit()
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		if not active:
			visible = false
		closed.emit())


func _gui_input(ev: InputEvent) -> void:
	if active and ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


## 캡처 단계처럼 먼저 키를 받아 전투 단축키와 겹치지 않게 (웹 keydown capture)
func _input(ev: InputEvent) -> void:
	if not active or not (ev is InputEventKey) or not ev.pressed:
		return
	var k := (ev as InputEventKey).keycode
	if not ev.echo:
		if k == KEY_ESCAPE:
			skip()
		elif k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_RIGHT:
			advance()
	get_viewport().set_input_as_handled()
