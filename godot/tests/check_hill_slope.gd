extends SceneTree
## 언덕 경사·바위 절벽 화면 좌표 시험 (화면 쪽 Iso 만 — 규칙 무관)
##   Godot --headless --path godot --script res://tests/check_hill_slope.gd
##  1) 높이 있는 칸(언덕·바위)의 윗면 가운데를 누르면 그 칸이 판정됨 (카메라 4방향 · 앞쪽 칸이 더 높아 가리는 경우는 제외)
##  2) 유닛 발 위치(foot)가 그 칸 모양 안 · 이동 높이(slope_h)가 양 끝에서 정확하고 단조
##  3) 언덕 모양 비트: 외딴 언덕은 네 변 열림, 이웃 언덕은 닫힘 · 칸 모양이 칸 육각형 안
##  4) 바위 화면 높이 배율이 규칙 데이터 z 를 바꾸지 않음

const Iso := preload("res://scripts/battle/iso.gd")
const TerrainTex := preload("res://scripts/battle/terrain_tex.gd")
var _fail := 0
var _n := 0


func _ok(c: bool, msg: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("  FAIL ", msg)


func _initialize() -> void:
	var D: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tiles.json"))
	var TI: Dictionary = D["TI"]
	var cols := 8
	var rows := 9
	var iso := Iso.new(cols, rows, TI)
	var ter: Array = []
	for r in rows:
		var row: Array = []
		for c in cols:
			row.append("plain")
		ter.append(row)
	# 외딴 언덕 (1,1) · 언덕 덩어리 (4..5, 3..4) · 바위 줄 (1..3, 6) · 바위 하나 (6,7)
	ter[1][1] = "hill"
	for r in range(3, 5):
		for c in range(4, 6):
			ter[r][c] = "hill"
	for c in range(1, 4):
		ter[6][c] = "rock"
	ter[7][6] = "rock"
	iso.ter = ter
	_ok(Iso.vis_z("rock", 2.0) > 2.0 and Iso.vis_z("hill", 1.0) == 1.0, "vis_z")
	_ok(float(TI["rock"]["z"]) == 2.0 and float(TI["hill"]["z"]) == 1.0, "데이터 z 변경 없음")
	for dir in 4:
		iso.cam_dir = dir
		for r in rows:
			for c in cols:
				var tp := iso.tile_type(c, r)
				var z := iso.tile_z(c, r)
				var ctr := iso.top_center(c, r)
				var sh := iso.cell_shape(c, r)
				if z > 0.0:
					_ok(Geometry2D.is_point_in_polygon(ctr, sh), "윗면 가운데가 모양 안 dir%d (%d,%d)" % [dir, c, r])
					_ok(Geometry2D.is_point_in_polygon(iso.foot(c, r), sh), "발이 모양 안 dir%d (%d,%d)" % [dir, c, r])
				# 앞쪽 세 칸(화면 기준)이 이 칸보다 높지 않을 때만 정확히 같아야 함
				var v := iso.g2v(c, r)
				var occluded := false
				for d2: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var g := iso.v2g(v.x + d2.x, v.y + d2.y)
					if v.x + d2.x < iso.vdim().x and v.y + d2.y < iso.vdim().y and iso.tile_z(g.x, g.y) > z:
						occluded = true
				if not occluded:
					var hit := iso.iso_hit(ctr)
					_ok(hit == Vector2i(c, r), "iso_hit dir%d (%d,%d) %s → %s" % [dir, c, r, tp, hit])
	iso.cam_dir = 0
	# 언덕 모양 비트
	var f1 := TerrainTex.hill_flags(iso.hill_probe(1, 1))
	_ok((f1 & 15) == 15, "외딴 언덕은 네 변 열림 %d" % f1)
	var f2 := TerrainTex.hill_flags(iso.hill_probe(4, 3))
	_ok((f2 & 15) == (1 | 2), "덩어리 (4,3): 뒤 두 변만 열림 → %d" % f2)
	var sh1 := TerrainTex.hill_shape(Vector2.ZERO, 10.0, f1)
	var hex := Iso.hl_shape(Vector2.ZERO, 10.0)
	var inside := true
	for p: Vector2 in sh1:
		if not Geometry2D.is_point_in_polygon(p, hex) and Geometry2D.offset_polygon(hex, 1.5)[0].has(p) == false:
			if not Geometry2D.is_point_in_polygon(p, Geometry2D.offset_polygon(hex, 1.5)[0]):
				inside = false
	_ok(inside, "경사 모양이 칸 육각형 안")
	# 이동 높이
	for pair: Array in [[0.0, 10.0], [10.0, 0.0], [0.0, 20.0]]:
		for dist in [1.0, 2.0, 3.0]:
			_ok(is_equal_approx(Iso.slope_h(pair[0], pair[1], 0.0, dist), pair[0]), "slope_h 시작")
			_ok(is_equal_approx(Iso.slope_h(pair[0], pair[1], 1.0, dist), pair[1]), "slope_h 끝")
			var prev: float = pair[0]
			var mono := true
			for i in 21:
				var hh := Iso.slope_h(pair[0], pair[1], float(i) / 20.0, dist)
				if (pair[1] > pair[0] and hh < prev - 0.0001) or (pair[1] < pair[0] and hh > prev + 0.0001):
					mono = false
				prev = hh
			_ok(mono, "slope_h 단조 %s" % str(pair))
	print("hill/rock 시험: %d 검사, 실패 %d" % [_n, _fail])
	quit(1 if _fail > 0 else 0)
