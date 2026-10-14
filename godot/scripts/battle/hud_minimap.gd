extends PanelContainer
## 미니맵 — 웹 #minimap (render.js rMM·rMMvp·mmClick): 타일 윗면 색 마름모 + 보이는 유닛 점(아군 파랑·적 빨강) + 지금 보이는 영역(금빛 사각)
##  누르거나 끌면 pan_to(전장 좌표) — 장면이 카메라를 옮김.
##  두 층: 타일(지형·카메라 방향이 바뀔 때만 다시 그림) + 위 층(유닛 점·보이는 영역 — 카메라가 움직이면 이것만 다시 그림)

const Kit := preload("res://scripts/battle/ui_kit.gd")
const Iso := preload("res://scripts/battle/iso.gd")

signal pan_to(world: Vector2)

const MAX_W := 132.0

var iso: Iso
var TI: Dictionary
var canvas: Control     # 타일 (자주 다시 그리지 않음)
var overlay: Control    # 유닛 점 · 보이는 영역
var _sc := 0.1
## 타일 마름모를 삼각형 배열 하나로 (그리기 호출 한 번 — 다각형마다 삼각분할하지 않음)
var _tri_pts := PackedVector2Array()
var _tri_cols := PackedColorArray()
var _tri_idx := PackedInt32Array()
var _lines := PackedVector2Array()
var _dots: Array = []       # [Vector2, Color]
var view_rect := Rect2()    # 전장 좌표
var _drag := false


func setup(p_iso: Iso, p_TI: Dictionary) -> void:
	iso = p_iso
	TI = p_TI
	name = "Minimap"
	add_theme_stylebox_override("panel", Kit.box(Color(10 / 255.0, 14 / 255.0, 26 / 255.0, 0.85), Color(1, 1, 1, 0.15), 8, 2, 2, 2))
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.clip_contents = true
	canvas.draw.connect(_draw_map)
	add_child(canvas)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.draw.connect(_draw_overlay)
	canvas.add_child(overlay)


## 지형·유닛이 바뀌거나 카메라가 돌면 (units: [{x, y, team}] — 보이는 것만)
func rebuild(units: Array) -> void:
	var ws := iso.world_size()
	_sc = MAX_W / ws.x
	canvas.custom_minimum_size = Vector2(ceilf(ws.x * _sc), ceilf(ws.y * _sc))
	_tri_pts = PackedVector2Array()
	_tri_cols = PackedColorArray()
	_tri_idx = PackedInt32Array()
	_lines = PackedVector2Array()
	for r in iso.rows:
		for c in iso.cols:
			var tp := iso.tile_type(c, r)
			if not TI.has(tp):
				continue
			var v := iso.g2v(c, r)
			var p := Vector2(iso.iso_x(v.x, v.y), iso.iso_y(v.x, v.y, 0)) * _sc
			var tw := Iso.TW * _sc
			var th := Iso.TH * _sc
			var q := [p + Vector2(tw, 0), p + Vector2(tw * 2, th), p + Vector2(tw, th * 2), p + Vector2(0, th)]
			var b := _tri_pts.size()
			var col := Color(str(TI[tp]["tc"]))
			for k in 4:
				_tri_pts.append(q[k])
				_tri_cols.append(col)
				_lines.append(q[k])
				_lines.append(q[(k + 1) % 4])
			_tri_idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	canvas.queue_redraw()
	set_units(units)


func set_units(units: Array) -> void:
	_dots.clear()
	for u: Dictionary in units:
		var v := iso.g2v(int(u["x"]), int(u["y"]))
		_dots.append([Vector2(iso.iso_x(v.x, v.y) + Iso.TW, iso.iso_y(v.x, v.y, 0) + Iso.TH) * _sc, Color("3b82f6") if u["team"] == "ally" else Color("ef4444")])
	overlay.queue_redraw()


func set_view(r: Rect2) -> void:
	if r.is_equal_approx(view_rect):
		return
	view_rect = r
	overlay.queue_redraw()


func _draw_map() -> void:
	if _tri_idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), _tri_idx, _tri_pts, _tri_cols)
	canvas.draw_multiline(_lines, Color(1, 1, 1, 0.08), -1.0)


func _draw_overlay() -> void:
	var rad := maxf(2.0, Iso.TW * _sc * 0.35)
	for d: Array in _dots:
		overlay.draw_circle(d[0], rad, d[1])
	if view_rect.size.x > 0.0:
		var vr := Rect2(view_rect.position * _sc, view_rect.size * _sc).intersection(Rect2(Vector2.ZERO, canvas.size))
		overlay.draw_rect(vr, Color(Kit.GOLD, 0.12))
		overlay.draw_rect(vr, Kit.GOLD, false, 1.5)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
		if ev.pressed:
			_pan((ev as InputEventMouseButton).position)
		accept_event()
	elif ev is InputEventMouseMotion and _drag:
		_pan((ev as InputEventMouseMotion).position)
		accept_event()


func _pan(local: Vector2) -> void:
	var p := local - canvas.position
	pan_to.emit(p / _sc)
