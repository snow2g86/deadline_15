extends Node2D
## 기준점 상자 그리기 (디버그) — 머리 상자(초록=믿음 · 노랑=약함 · 빨강=잃음), 몸통 상자(파랑)
var on := false
var origin := Vector2.ZERO
var z := 1.0
var ha: Dictionary = {}
var ta: Dictionary = {}


func set_info(p_on: bool, p_origin: Vector2, p_z: float, p_ha: Dictionary, p_ta: Dictionary) -> void:
	on = p_on
	origin = p_origin
	z = p_z
	ha = p_ha
	ta = p_ta
	queue_redraw()


func _box(cx: float, cy: float, s: float, rot: float, w: float, h: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var r := deg_to_rad(rot)
	for d: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
		var x := d.x * w * s / 2.0
		var y := d.y * h * s / 2.0
		var xr := x * cos(r) + y * sin(r)
		var yr := -x * sin(r) + y * cos(r)
		pts.append(origin + Vector2(cx + xr, cy + yr) * z)
	draw_polyline(pts, col, 0.6)


func _draw() -> void:
	if not on or ha.is_empty():
		return
	var col := Color(0.2, 1, 0.2)
	match str(ha["vis"]):
		"weak":
			col = Color(1, 0.85, 0)
		"lost":
			col = Color(1, 0.15, 0.15)
	_box(float(ha["x"]), float(ha["y"]), float(ha["s"]), float(ha["r"]), 47, 53, col)
	var tc := Color(0.3, 0.6, 1.0) if str(ta["vis"]) in ["ok", "weak"] else Color(0.8, 0.3, 1.0)
	_box(float(ta["x"]), float(ta["y"]), float(ta["s"]), 0.0, 35, 55, tc)
