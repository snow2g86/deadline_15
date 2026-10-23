extends RefCounted
## 전투 HUD 공용 부품 — 글꼴·상자 모양·작은 위젯 (웹 css/battle.css 의 색·모양을 옮김)
##  Portrait(원형 얼굴 크롭) · IconRect(아이콘 + 등급 테두리) · Bar(막대) · VecIcon(웹 SVG 단추 그림을 선으로) · Kit.box/label/button

const Fonts := preload("res://scripts/core/fonts.gd")
const Icons := preload("res://scripts/battle/icons.gd")
const GOLD := Color("f0c040")
const GOLD_D := Color("b8860b")
const TEXT := Color("e5e7eb")
const DIM := Color("94a3b8")
const RED := Color("ef4444")
const PANEL := Color(17 / 255.0, 24 / 255.0, 39 / 255.0, 0.96)
const RES_COLOR := {"mana": Color("4488ff"), "energy": Color("f0c040"), "fury": Color("ff6644")}

## 글꼴은 언어별 사슬 (scripts/core/fonts.gd) — 언어가 바뀌면 같은 객체 안의 사슬이 바뀌어 바로 다시 그려짐
## 터치 대상 최소 높이 (논리 px): PC 44, 모바일은 실제 44pt(≈6.9mm) 이상 (Mobile.min_target)
static func touch_min() -> float:
	var ml := Engine.get_main_loop()
	var mob: Node = (ml as SceneTree).root.get_node_or_null("Mobile") if ml is SceneTree else null
	return maxf(44.0, float(mob.call("min_target")) if mob != null else 0.0)


static func font() -> Font:
	return Fonts.weight(Fonts.REGULAR)


## 굵기 (wght 100~900) — 같은 굵기는 한 번만 만듦
static func bold(w: int = 800) -> Font:
	return Fonts.weight(w)


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 6, bw: int = 1, mx: int = 8, my: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = true
	return s


static func label(size: int, col: Color, w: int = 0) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if w > 0:
		l.add_theme_font_override("font", bold(w))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func outline(l: Control, px: int = 4, col: Color = Color(0, 0, 0, 0.85)) -> void:
	l.add_theme_constant_override("outline_size", px)
	l.add_theme_color_override("font_outline_color", col)


static func rich(size: int, col: Color, w: int = 0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = false
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", col)
	if w > 0:
		r.add_theme_font_override("normal_font", bold(w))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## 단추 (보통·마우스·누름·꺼짐 모양) — ac: 강조색
static func button(text: String, ac: Color = GOLD, size: int = 12, min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", bold(700))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("64748b"))
	b.add_theme_stylebox_override("normal", box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.12), 5, 1, 12, 5))
	b.add_theme_stylebox_override("hover", box(Color(1, 1, 1, 0.12), ac, 5, 1, 12, 5))
	b.add_theme_stylebox_override("pressed", box(Color(ac, 0.25), ac, 5, 1, 12, 5))
	b.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.06), 5, 1, 12, 5))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## 웹 .cam-btn (테두리 금빛 · 안에 선 그림)
static func cam_button(icon: String, tip: String, sz: float = 40.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(sz, sz)
	b.tooltip_text = tip
	b.add_theme_stylebox_override("normal", box(Color(10 / 255.0, 14 / 255.0, 26 / 255.0, 0.7), Color(GOLD, 0.25), 8, 1, 0, 0))
	b.add_theme_stylebox_override("hover", box(Color(GOLD, 0.15), GOLD, 8, 1, 0, 0))
	b.add_theme_stylebox_override("pressed", box(Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.22), RED, 8, 1, 0, 0))
	b.add_theme_stylebox_override("hover_pressed", box(Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.3), RED, 8, 1, 0, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := VecIcon.new()
	ic.kind = icon
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 웹 .cam-btn svg 22px / 42px 단추
	var m := roundf(sz * 0.24)
	ic.offset_left = m
	ic.offset_top = m
	ic.offset_right = -m
	ic.offset_bottom = -m
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	b.set_meta("icon", ic)
	return b


# ═══════════ 위젯 ═══════════

## 원형 얼굴 (웹 .an-portrait · .ic-portrait: 캐릭터 그림 얼굴 크롭 + 테두리 색 --tc). 소환수는 도트 그림을 가운데에
class Portrait extends Control:
	var tex: Texture2D
	var region := Rect2()
	var ring := Color("3b82f6")
	var ring_w := 1.5
	var pixel := false   # 소환수 도트 그림
	var tint := Color.WHITE

	func set_unit(t: Texture2D, is_summon: bool) -> void:
		tex = t
		pixel = is_summon
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if is_summon else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if t != null and not is_summon:
			region = Icons.portrait_region(t)
		queue_redraw()

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		var c := size * 0.5
		draw_circle(c, r, Color("1f2937"))
		if tex != null:
			if pixel:
				var s := r * 1.4
				var asp := float(tex.get_height()) / float(tex.get_width())
				draw_texture_rect(tex, Rect2(c.x - s * 0.5, c.y - s * asp * 0.5, s, s * asp), false, tint)
			else:
				var pts := PackedVector2Array()
				var uvs := PackedVector2Array()
				var ts := Vector2(tex.get_width(), tex.get_height())
				for i in 28:
					var a := TAU * i / 28.0
					var d := Vector2(cos(a), sin(a))
					pts.append(c + d * r)
					uvs.append((region.position + region.size * (d * 0.5 + Vector2(0.5, 0.5))) / ts)
				draw_colored_polygon(pts, tint, uvs, tex)
		if ring_w > 0.0:
			draw_arc(c, r - ring_w * 0.5, 0.0, TAU, 32, ring, ring_w, true)


## 아이콘 (아이템 그림 + 등급 테두리 — 웹 itemIcon 의 두 겹: 바깥 테두리, 안쪽 0.78 크기 그림)
class IconRect extends Control:
	var tex: Texture2D
	var frame: Texture2D
	var plain := false   # 테두리·바탕 없이 그림만 (e_* 효과 아이콘, 스킬)
	var modulate_icon := Color.WHITE

	func set_icon(t: Texture2D, f: Texture2D = null, p_plain: bool = true) -> void:
		tex = t
		frame = f
		plain = p_plain
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if not plain:
			if frame != null:
				draw_texture_rect(frame, r, false)
			else:
				draw_rect(r, Color("2a2f3b"))
				draw_rect(r, Color(1, 1, 1, 0.08), false, 1.0)
		if tex != null:
			var k := 1.0 if plain else (0.78 if frame != null else 0.88)
			var s := size * k
			draw_texture_rect(tex, Rect2((size - s) * 0.5, s), false, modulate_icon)


## 막대 (웹 .ic-bar · .an-bar · .ep-btrack): 바탕 + 채움 (그라디언트 두 색)
class Bar extends Control:
	var ratio := 0.0
	var c0 := Color("16a34a")
	var c1 := Color("4ade80")
	var track := Color(1, 1, 1, 0.1)
	var radius := 3.0

	func set_value(r: float, a: Color, b: Color) -> void:
		var nr := clampf(r, 0.0, 1.0)
		if nr == ratio and a == c0 and b == c1:
			return
		ratio = nr
		c0 = a
		c1 = b
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = track
		sb.set_corner_radius_all(int(radius))
		draw_style_box(sb, r)
		if ratio > 0.0:
			var w := maxf(radius * 2.0, size.x * ratio)
			var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, size.y), Vector2(0, size.y)])
			draw_polygon(pts, PackedColorArray([c0, c1, c1, c0]))


## 선 그림 아이콘 (웹 battle.html 의 SVG: 위협 삼각형·회전 화살표·톱니·소리·음표·깃발·속도)
class VecIcon extends Control:
	var kind := ""
	var color := Color("f0c040")
	var stroke := 2.0

	func _draw() -> void:
		var s := minf(size.x, size.y) * 0.5
		var c := size * 0.5
		var k := s / 12.0   # SVG 24×24 기준 → 반 크기 = 12
		var P := func(x: float, y: float) -> Vector2: return c + Vector2(x - 12.0, y - 12.0) * k
		var col := color
		var w := stroke * clampf(k, 0.6, 1.0)
		match kind:
			"warn":
				draw_polyline(PackedVector2Array([P.call(12, 3.5), P.call(22, 20.5), P.call(2, 20.5), P.call(12, 3.5)]), col, w, true)
				draw_line(P.call(12, 9), P.call(12, 13.5), col, w, true)
				draw_circle(P.call(12, 17), w * 0.6, col)
			"rot_l", "rot_r":
				var sg := -1.0 if kind == "rot_l" else 1.0
				var ctr: Vector2 = P.call(12, 12)
				var r := 8.5 * k
				var pts := PackedVector2Array()
				for i in 25:
					var a := deg_to_rad(-60.0 + i * 12.0)
					pts.append(ctr + Vector2(cos(a) * sg, sin(a)) * r)
				draw_polyline(pts, col, w, true)
				var tip := pts[0]
				draw_polyline(PackedVector2Array([tip + Vector2(-6.0 * sg, -1.5) * k, tip, tip + Vector2(-1.0 * sg, -6.0) * k]), col, w, true)
			"gear":
				var ctr2: Vector2 = P.call(12, 12)
				draw_arc(ctr2, 3.0 * k, 0, TAU, 16, col, w, true)
				var pts2 := PackedVector2Array()
				for i in 49:
					var a2 := TAU * i / 48.0
					var rr := (8.6 if (i % 6) < 3 else 6.6) * k
					pts2.append(ctr2 + Vector2(cos(a2), sin(a2)) * rr)
				draw_polyline(pts2, col, w * 0.8, true)
			"speed":
				draw_colored_polygon(PackedVector2Array([P.call(3, 6), P.call(12, 12), P.call(3, 18)]), col)
				draw_colored_polygon(PackedVector2Array([P.call(12, 6), P.call(21, 12), P.call(12, 18)]), col)
			"music":
				draw_polyline(PackedVector2Array([P.call(9, 18), P.call(9, 5), P.call(21, 3), P.call(21, 16)]), col, w, true)
				draw_arc(P.call(6, 18), 3.0 * k, 0, TAU, 14, col, w, true)
				draw_arc(P.call(18, 16), 3.0 * k, 0, TAU, 14, col, w, true)
			"sound":
				draw_polyline(PackedVector2Array([P.call(11, 5), P.call(6, 9), P.call(2, 9), P.call(2, 15), P.call(6, 15), P.call(11, 19), P.call(11, 5)]), col, w, true)
				draw_arc(P.call(12, 12), 4.5 * k, -0.8, 0.8, 8, col, w, true)
				draw_arc(P.call(12, 12), 8.0 * k, -0.85, 0.85, 10, col, w, true)
			"flag":
				draw_polyline(PackedVector2Array([P.call(4, 22), P.call(4, 3), P.call(17, 6), P.call(4, 10)]), col, w, true)
			"globe":
				draw_arc(P.call(12, 12), 9.0 * k, 0, TAU, 24, col, w, true)
				draw_line(P.call(3, 12), P.call(21, 12), col, w, true)
				var e := PackedVector2Array()
				for i in 17:
					var a3 := -PI / 2.0 + PI * i / 16.0
					e.append(c + Vector2(cos(a3) * 4.0, sin(a3) * 9.0) * k)
				draw_polyline(e, col, w, true)
			"eye":
				var e2 := PackedVector2Array()
				for i in 17:
					var a4 := PI * i / 16.0
					e2.append(c + Vector2(-cos(a4) * 10.0, -sin(a4) * 6.0) * k)
				for i in range(1, 16):
					var a5 := PI * i / 16.0
					e2.append(c + Vector2(cos(a5) * 10.0, sin(a5) * 6.0) * k)
				e2.append(e2[0])
				draw_polyline(e2, col, w, true)
				draw_circle(c, 2.6 * k, col)
			# ── 바깥 화면(4a) 웹 SVG: 뒤로(polyline 15 18 9 12 15 6) · 자물쇠(🔒 글자 대신) · 정보(ℹ️) · 닫기(✕) · 휴지통(초기화) · 재생(▶)
			"chev_l":
				draw_polyline(PackedVector2Array([P.call(15, 18), P.call(9, 12), P.call(15, 6)]), col, w * 1.25, true)
			# (4b-2) 접고 펴기 (웹 details summary::after '›' — 펴면 아래로)
			"chev_r":
				draw_polyline(PackedVector2Array([P.call(9, 6), P.call(15, 12), P.call(9, 18)]), col, w * 1.25, true)
			"chev_d":
				draw_polyline(PackedVector2Array([P.call(6, 9), P.call(12, 15), P.call(18, 9)]), col, w * 1.25, true)
			"search":
				draw_arc(P.call(10.5, 10.5), 6.5 * k, 0, TAU, 20, col, w, true)
				draw_line(P.call(15.5, 15.5), P.call(20.5, 20.5), col, w * 1.3, true)
			"lock":
				draw_rect(Rect2(P.call(5, 11), Vector2(14, 10) * k), col, true)
				draw_arc(P.call(12, 11), 4.5 * k, PI, TAU, 12, col, w, true)
				draw_line(P.call(7.5, 11), P.call(7.5, 8), col, w, true)
				draw_line(P.call(16.5, 11), P.call(16.5, 8), col, w, true)
			"info":
				draw_arc(P.call(12, 12), 9.5 * k, 0, TAU, 24, col, w, true)
				draw_line(P.call(12, 11), P.call(12, 17), col, w * 1.2, true)
				draw_circle(P.call(12, 7.5), w * 0.75, col)
			"close":
				draw_line(P.call(6, 6), P.call(18, 18), col, w * 1.1, true)
				draw_line(P.call(18, 6), P.call(6, 18), col, w * 1.1, true)
			"trash":
				draw_polyline(PackedVector2Array([P.call(3, 6), P.call(21, 6)]), col, w, true)
				draw_polyline(PackedVector2Array([P.call(19, 6), P.call(19, 20), P.call(17, 22), P.call(7, 22), P.call(5, 20), P.call(5, 6)]), col, w, true)
				draw_polyline(PackedVector2Array([P.call(8, 6), P.call(8, 4), P.call(10, 2), P.call(14, 2), P.call(16, 4), P.call(16, 6)]), col, w, true)
				draw_line(P.call(10, 11), P.call(10, 17), col, w, true)
				draw_line(P.call(14, 11), P.call(14, 17), col, w, true)
			"play":
				draw_colored_polygon(PackedVector2Array([P.call(6, 4), P.call(20, 12), P.call(6, 20)]), col)
			# (5단계) 화면 설정 — 같은 선 그림 모양의 모니터 (rect 2 3 20 14 · 받침)
			"monitor":
				draw_polyline(PackedVector2Array([P.call(2, 3), P.call(22, 3), P.call(22, 17), P.call(2, 17), P.call(2, 3)]), col, w, true)
				draw_line(P.call(8, 21), P.call(16, 21), col, w, true)
				draw_line(P.call(12, 17), P.call(12, 21), col, w, true)
