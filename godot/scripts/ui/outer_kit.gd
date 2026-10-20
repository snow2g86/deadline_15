extends RefCounted
## 바깥 화면(로비·스테이지·편성·설정) 공용 부품 — 웹 css/common.css 의 색·모양 (#top-nav · #bottom-nav · .gold-badge · #modal-box · .modal-btn · .game-tab · .toast)
##  웹의 PC(1024px 이상) 크기를 씁니다: 창 크기 조절은 project.godot 의 canvas_items·expand 늘이기라 논리 화면은 늘 1280×720 이상.
##  단추는 키보드 포커스를 받습니다 (Tab·화살표로 옮기고 Enter·Space 로 누름 — 포커스는 금빛 테두리).

const Kit := preload("res://scripts/battle/ui_kit.gd")

const BG := Color("0a0e1a")
const PANEL := Color("111827")
const GOLD := Color("f0c040")
const GOLD_D := Color("a08020")
const TEXT := Color("e2e8f0")
const DIM := Color("64748b")
const DIM2 := Color("94a3b8")
const BLUE := Color("3b82f6")
const GREEN := Color("22c55e")
const RED := Color("ef4444")
const NAV_TOP_H := 56.0
const NAV_BOTTOM_H := 64.0


static func label(size: int, col: Color, w: int = 0) -> Label:
	return Kit.label(size, col, w)


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 6, bw: int = 1, mx: int = 8, my: int = 4) -> StyleBoxFlat:
	return Kit.box(bg, border, radius, bw, mx, my)


static func focus_box(radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = Color(GOLD, 0.95)
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.expand_margin_left = 2
	s.expand_margin_right = 2
	s.expand_margin_top = 2
	s.expand_margin_bottom = 2
	return s


## 상자 모양 단추 (normal·hover·pressed·disabled 를 한 번에) — 글자 없는 카드 단추에도 씀
static func styled_button(normal: StyleBox, hover: StyleBox = null, pressed: StyleBox = null, radius: int = 8) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover if hover != null else normal)
	b.add_theme_stylebox_override("pressed", pressed if pressed != null else (hover if hover != null else normal))
	b.add_theme_stylebox_override("hover_pressed", pressed if pressed != null else (hover if hover != null else normal))
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_stylebox_override("focus", focus_box(radius))
	b.add_theme_font_override("font", Kit.bold(700))
	return b


## 웹 .modal-btn (금빛) / .modal-btn.secondary (회색)
static func modal_button(text: String, secondary: bool = false, size: int = 16) -> Button:
	var bg := Color("4b5563") if secondary else Color("e3b42e")
	var hv := Color("566173") if secondary else Color("f3c84a")
	var b := styled_button(box(bg, Color(0, 0, 0, 0), 8, 0, 30, 10), box(hv, Color(0, 0, 0, 0), 8, 0, 30, 10), box(bg.darkened(0.12), Color(0, 0, 0, 0), 8, 0, 30, 10))
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", Kit.bold(800))
	var fg := Color("e2e8f0") if secondary else Color("1a1a2e")
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.4))
	return b


## 작은 테두리 단추 (웹 .sb-info-btn · .es-btn 류)
static func ghost_button(text: String, size: int = 12, accent: Color = GOLD) -> Button:
	var b := styled_button(box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.1), 6, 1, 10, 6), box(Color(1, 1, 1, 0.1), accent, 6, 1, 10, 6), box(Color(accent, 0.18), accent, 6, 1, 10, 6), 6)
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	return b


## 동글한 알약 (상태 배지 · 이름표)
static func pill(text: String, size: int, fg: Color, bg: Color, border: Color = Color(0, 0, 0, 0), w: int = 800) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", box(bg, border, 999, 1, 8, 2))
	var l := label(size, fg, w)
	l.text = text
	l.name = "Text"
	p.add_child(l)
	return p


static func tex_rect(tex: Texture2D, sz: Vector2, nearest: bool = false) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = sz
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if nearest:
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r


static func vec_icon(kind: String, sz: float, col: Color) -> Control:
	var ic := Kit.VecIcon.new()
	ic.kind = kind
	ic.color = col
	ic.custom_minimum_size = Vector2(sz, sz)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


static func hbox(sep: int = 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


static func divider(a: float = 0.08) -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(1, 1, 1, a)
	d.custom_minimum_size = Vector2(0, 1)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


## 가운데 정렬 + 최대 폭 (웹 max-width:Npx; margin:0 auto)
class MaxWidth extends Container:
	var max_w := 460.0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			for ch: Node in get_children():
				if ch is Control and (ch as Control).visible:
					var w := minf(size.x, max_w)
					var h := maxf(size.y, (ch as Control).get_combined_minimum_size().y)
					fit_child_in_rect(ch, Rect2((size.x - w) * 0.5, 0, w, h))

	func _get_minimum_size() -> Vector2:
		var m := Vector2.ZERO
		for ch: Node in get_children():
			if ch is Control and (ch as Control).visible:
				var cm := (ch as Control).get_combined_minimum_size()
				m.x = maxf(m.x, minf(cm.x, max_w))
				m.y = maxf(m.y, cm.y)
		return m


## 그라디언트 바탕 (선형: from→to 방향, 또는 원형) — 웹 linear-gradient / radial-gradient
static func gradient_rect(colors: Array, offsets: Array, radial: bool = false, from: Vector2 = Vector2(0.5, 0), to: Vector2 = Vector2(0.5, 1)) -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL if radial else GradientTexture2D.FILL_LINEAR
	gt.fill_from = from
	gt.fill_to = to
	gt.width = 256
	gt.height = 256
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


## 단추(또는 아무 Control) 안에 내용 하나를 넣고, 내용 크기에 맞춰 단추의 최소 크기를 늘림 (웹 카드처럼 글이 길면 카드가 커짐)
##  pad = (왼, 위, 오른, 아래). 단추에 미리 준 custom_minimum_size 는 최소값으로 남음.
##  Button 은 Container 가 아니라 자식 크기를 모르므로, 자식이 커지면 여기서 단추를 키우고 자식을 단추 안에 맞춤.
static func set_content(b: Control, c: Control, pad: Vector4 = Vector4.ZERO) -> void:
	var base := b.custom_minimum_size
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	b.add_child(c)
	var sync := func() -> void:
		if not is_instance_valid(b) or not is_instance_valid(c):
			return
		var m := c.get_combined_minimum_size()
		var fl := float(b.get_meta("m6a_floor", 0.0))   # (6a) 모바일 터치 최소 (Mobile 이 정함, PC 는 0)
		var want := Vector2(maxf(maxf(base.x, m.x + pad.x + pad.z), fl), maxf(maxf(base.y, m.y + pad.y + pad.w), fl))
		if b.custom_minimum_size != want:
			b.custom_minimum_size = want
		c.position = Vector2(pad.x, pad.y)
		c.size = Vector2(maxf(m.x, b.size.x - pad.x - pad.z), maxf(m.y, b.size.y - pad.y - pad.w))
	c.minimum_size_changed.connect(sync, CONNECT_DEFERRED)
	b.resized.connect(sync, CONNECT_DEFERRED)
	b.ready.connect(sync, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	sync.call()
