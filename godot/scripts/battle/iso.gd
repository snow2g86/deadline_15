extends RefCounted
const TerrainTex := preload("res://scripts/battle/terrain_tex.gd")
## 아이소메트릭 좌표 — 웹 js/battle/grid.js (g2v·v2g·isoX·isoY·tSX·tSY·uSX·uSY·depth·isoHit) 와 같은 식
##  격자 (c, r) = (x, y) — 엔진 유닛의 x·y 와 같음. 카메라 방향 cam_dir 0~3 (웹 GameStore.camDir)
##  화면 좌표는 웹 #iso-world 안의 px 와 같음 (TW 48 · TH 24 · ZH 10)

const TW := 48.0
const TH := 24.0
const ZH := 10.0
## 유닛 상수 (battle/constants.js): UW·UH 유닛 상자, UCX·UCY 몸통 중심, UOY 타일 기준 상자 위쪽
const UW := 64.0
const UH := 78.0
const UCX := 32.0
const UCY := 30.0
const UOY := 40.0

var cols: int = 8
var rows: int = 15
var cam_dir: int = 0
## 지형 (엔진 S.ter 와 같은 모양: [행][열] = 종류 문자열) — 높이 계산용 (화면 쪽 사본)
var ter: Array = []:
	set(v):
		ter = v
		_shape_cache.clear()
## 칸 모양 캐시 (카메라 방향·칸 → {sh: 화면 모양, o: 원점}) — 클릭 판정용. 지형이 바뀌면 비움
var _shape_cache: Dictionary = {}
## TI (타일 정보: z 높이 등)
var TI: Dictionary = {}


func _init(p_cols: int = 8, p_rows: int = 15, ti: Dictionary = {}) -> void:
	cols = p_cols
	rows = p_rows
	TI = ti


func g2v(c: int, r: int) -> Vector2i:
	match cam_dir:
		1:
			return Vector2i(rows - 1 - r, c)
		2:
			return Vector2i(cols - 1 - c, rows - 1 - r)
		3:
			return Vector2i(r, cols - 1 - c)
	return Vector2i(c, r)


func v2g(vc: int, vr: int) -> Vector2i:
	match cam_dir:
		1:
			return Vector2i(vr, rows - 1 - vc)
		2:
			return Vector2i(cols - 1 - vc, rows - 1 - vr)
		3:
			return Vector2i(cols - 1 - vr, vc)
	return Vector2i(vc, vr)


## 화면 기준 칸 수 (x = 가로 vc 개수, y = 세로 vr 개수)
func vdim() -> Vector2i:
	return Vector2i(cols, rows) if cam_dir % 2 == 0 else Vector2i(rows, cols)


func iso_x(vc: float, vr: float) -> float:
	return (vc - vr) * TW + float(vdim().y) * TW


func iso_y(vc: float, vr: float, z: float = 0.0) -> float:
	return (vc + vr) * TH - z * ZH


## 타일 그림 왼쪽 위 (웹 tSX·tSY)
func tsx(c: int, r: int) -> float:
	var v := g2v(c, r)
	return iso_x(v.x, v.y)


func tsy(c: int, r: int, z: float = 0.0) -> float:
	var v := g2v(c, r)
	return iso_y(v.x, v.y, z)


func tile_type(c: int, r: int) -> String:
	if r < 0 or r >= ter.size():
		return ""
	var row: Array = ter[r]
	if c < 0 or c >= row.size():
		return ""
	return str(row[c])


## 바위는 절벽 느낌으로 그림만 조금 더 높게 (규칙·데이터의 z 는 그대로 — 화면 높이 배율)
const ROCK_K := 1.3


static func vis_z(tp: String, z: float) -> float:
	return z * ROCK_K if tp == "rock" else z


func tile_z(c: int, r: int) -> float:
	var tp := tile_type(c, r)
	if tp == "" or not TI.has(tp):
		return 0.0
	return vis_z(tp, float(TI[tp]["z"]))


## 타일 윗면 가운데 (높이 반영)
func top_center(c: int, r: int) -> Vector2:
	return Vector2(tsx(c, r) + TW, tsy(c, r, tile_z(c, r)) + TH)


## 유닛 발 위치 (웹: 아이콘 아래 = 타일 윗면 가운데, 발끝은 FIG_FOOT 3px 위)
func foot(c: int, r: int) -> Vector2:
	return top_center(c, r) + Vector2(0, -3)


## 이동 중 발 높이 (px): 높이 h0 칸 → h1 칸, 경로 진행 t (0..1), dist = 경로 길이(칸).
##  높이는 칸 경계(경로 중간 0.5칸 지점)에서 시작해 경사 폭(HILL_A 칸) 동안만 바뀜 — 윗면(고원)은 평평하고 평지는 바닥
static func slope_h(h0: float, h1: float, t: float, dist: float) -> float:
	if is_equal_approx(h0, h1):
		return h1
	var d := maxf(dist, 0.01)
	var a := TerrainTex.HILL_A
	var s0: float
	var s1: float
	if h1 > h0:
		s0 = 1.0 - 0.5 / d
		s1 = 1.0 - (0.5 - a) / d
	else:
		s0 = (0.5 - a) / d
		s1 = 0.5 / d
	var k := clampf((t - s0) / (s1 - s0), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	return lerpf(h0, h1, k)


## 앞뒤 순서 (웹 Grid.depth): 화면 앞쪽 칸일수록 위. layer 0 보물상자 < 1 맵 오브젝트 < 2 유닛
func depth(c: int, r: int, layer: int = 0) -> int:
	var v := g2v(c, r)
	return 100 + (v.x + v.y) * 3 + layer


## 대각선 번호 (vc + vr) — 타일 층 순서
func diag(c: int, r: int) -> int:
	var v := g2v(c, r)
	return v.x + v.y


func diag_count() -> int:
	return cols + rows - 1


## 화면 이웃 칸이 언덕인지 묻는 함수 (경사 모양 계산용) — 화면 기준 (u = vc, v = vr) 이웃 (du, dv)
func hill_probe(c: int, r: int) -> Callable:
	return type_probe(c, r, "hill")


func type_probe(c: int, r: int, tp: String) -> Callable:
	var v0 := g2v(c, r)
	var d := vdim()
	return func(du: int, dv: int) -> bool:
		var vc := v0.x + du
		var vr := v0.y + dv
		if vc < 0 or vr < 0 or vc >= d.x or vr >= d.y:
			return false
		var g := v2g(vc, vr)
		return tile_type(g.x, g.y) == tp


## 칸이 화면에서 덮는 모양 (높이·언덕 경사 반영, 월드 화면 좌표) — 클릭 판정용. 캐시됨
func cell_shape(c: int, r: int) -> PackedVector2Array:
	var key := cam_dir * 1000000 + r * 1000 + c
	if _shape_cache.has(key):
		return _shape_cache[key]
	var out := PackedVector2Array()
	var tp := tile_type(c, r)
	if tp != "" and TI.has(tp):
		var z := tile_z(c, r)
		var o := Vector2(tsx(c, r), tsy(c, r, z))
		if tp == "hill":
			out = TerrainTex.hill_shape(o, z * ZH, TerrainTex.hill_flags(hill_probe(c, r)))
		else:
			out = hl_shape(o, z * ZH)
	_shape_cache[key] = out
	return out


## 화면 좌표 → 칸. 높이 있는 칸(언덕·바위·성벽)은 그려진 윗면·옆면 모양으로 판정하고, 겹치면 앞쪽(그려지는 순서 위) 칸.
##  어느 모양에도 안 들어가면 높이 없는 바닥 평면 기준 (웹 isoHit). 없으면 (-1, -1)
func iso_hit(p: Vector2) -> Vector2i:
	var d := vdim()
	var o_x := float(d.y) * TW
	var fvc := ((p.x - o_x) / TW + p.y / TH) / 2.0
	var fvr := (p.y / TH - (p.x - o_x) / TW) / 2.0
	var best := Vector2i(-1, -1)
	# 높이 있는 칸은 그림이 위로 솟아 있어, 바닥 평면 칸보다 뒤(화면 아래쪽 평면 좌표가 큰 쪽)에 있는 칸도 후보
	var best_k := -1
	for dvc in range(-1, 3):
		for dvr in range(-1, 3):
			var vc := floori(fvc) + dvc
			var vr := floori(fvr) + dvr
			if vc < 0 or vr < 0 or vc >= d.x or vr >= d.y:
				continue
			var g := v2g(vc, vr)
			if tile_z(g.x, g.y) <= 0.0:
				continue   # 높이 없는 칸은 아래 바닥 평면 판정
			var sh := cell_shape(g.x, g.y)
			if not sh.is_empty() and Geometry2D.is_point_in_polygon(p, sh) and vc + vr > best_k:
				best_k = vc + vr
				best = g
	# 높이 없는 칸 (바닥 평면 마름모) — 높이 있는 칸이 같은 점을 가렸다면 그쪽이 앞인 경우만 양보
	var best_d := INF
	var flat := Vector2i(-1, -1)
	var flat_k := -1
	for dvc in range(-1, 2):
		for dvr in range(-1, 2):
			var vc2 := floori(fvc) + dvc
			var vr2 := floori(fvr) + dvr
			if vc2 < 0 or vr2 < 0 or vc2 >= d.x or vr2 >= d.y:
				continue
			var cx := iso_x(vc2, vr2) + TW
			var cy := iso_y(vc2, vr2, 0) + TH
			var dx := absf(p.x - cx) / TW
			var dy := absf(p.y - cy) / TH
			if dx + dy <= 1.0 and dx + dy < best_d:
				best_d = dx + dy
				flat = v2g(vc2, vr2)
				flat_k = vc2 + vr2
	if best.x >= 0:
		# 바닥 칸이 높이 있는 칸보다 앞(대각선 번호가 큼)이면 바닥 칸이 위에 그려짐. 단, 바닥 칸이 높이 있는 칸이면 이미 위에서 처리
		if flat.x >= 0 and tile_z(flat.x, flat.y) <= 0.0 and flat_k > best_k:
			return flat
		return best
	return flat


## 화면 좌표 → 격자 실수 좌표 (카메라 회전 때 화면 가운데 칸을 유지하려고)
func screen_to_grid_f(p: Vector2) -> Vector2:
	var d := vdim()
	var o_x := float(d.y) * TW
	# 칸 가운데 (vc, vr) 의 화면 좌표를 거꾸로 푼 식: fvc = vc + 1, fvr = vr
	var fvc := ((p.x - o_x) / TW + p.y / TH) / 2.0 - 1.0
	var fvr := (p.y / TH - (p.x - o_x) / TW) / 2.0
	# 화면 칸 → 격자 칸 (실수판 v2g)
	match cam_dir:
		1:
			return Vector2(fvr, rows - 1 - fvc)
		2:
			return Vector2(cols - 1 - fvc, rows - 1 - fvr)
		3:
			return Vector2(cols - 1 - fvr, fvc)
	return Vector2(fvc, fvr)


## 격자 실수 좌표 → 화면 (바닥 평면, 칸 가운데)
func grid_f_to_screen(g: Vector2) -> Vector2:
	var vc: float
	var vr: float
	match cam_dir:
		1:
			vc = rows - 1 - g.y
			vr = g.x
		2:
			vc = cols - 1 - g.x
			vr = rows - 1 - g.y
		3:
			vc = g.y
			vr = cols - 1 - g.x
		_:
			vc = g.x
			vr = g.y
	return Vector2(iso_x(vc, vr) + TW, iso_y(vc, vr) + TH)


## 세계 크기 (웹 layWorld: 폭 (c+r)*TW+4, 높이 (c+r)*TH+80)
func world_size() -> Vector2:
	var d := vdim()
	return Vector2((d.x + d.y) * TW + 4.0, (d.x + d.y) * TH + 80.0)


## 격자 방향 → 화면 방향 벡터 (웹 VFX._g2screen: 카메라 회전 반영, 한 칸 = (TW, TH) 마름모 비율)
func g2screen(gdx: float, gdy: float) -> Vector2:
	var vc: float
	var vr: float
	match cam_dir:
		1:
			vc = -gdy
			vr = gdx
		2:
			vc = -gdx
			vr = -gdy
		3:
			vc = gdy
			vr = -gdx
		_:
			vc = gdx
			vr = gdy
	return Vector2((vc - vr) * TW, (vc + vr) * TH)


## 화면 가로 방향 부호 (웹 VFX._g2sx) — 음수면 그림을 좌우로 뒤집음 (원본 그림은 오른쪽을 봄)
func g2sx(gdx: float, gdy: float) -> float:
	match cam_dir:
		0:
			return gdx - gdy
		1:
			return -gdy - gdx
		2:
			return gdy - gdx
	return gdy + gdx


## 발밑 방향 삼각형 (웹 VFX.faceTri): (cx, cy) 기준, 끝 = tip 칸 앞, 밑변 = (tip - len) 칸, 밑변 반폭 half 칸
##  방향 값이 거리(예: (0,-3))여도 네 방향 중 가까운 한 칸 방향으로 줄여 씀
func face_tri(gdx: float, gdy: float, c: Vector2, tip: float, len: float, half: float) -> PackedVector2Array:
	var ax := absf(gdx)
	var ay := absf(gdy)
	var dx := signf(gdx) if ax >= ay else 0.0
	var dy := 0.0 if ax >= ay else signf(gdy)
	var V := g2screen(dx, dy)
	var E := g2screen(-dy, dx)
	return PackedVector2Array([c + V * tip, c + V * (tip - len) + E * half, c + V * (tip - len) - E * half])


## 윗면 마름모 (타일 그림 원점 기준 — 웹 terrain-tex 좌표)
static func diamond(o: Vector2) -> PackedVector2Array:
	return PackedVector2Array([o + Vector2(TW, 0), o + Vector2(TW * 2, TH), o + Vector2(TW, TH * 2), o + Vector2(0, TH)])


## 하이라이트가 덮는 모양 (웹 hl 타일 clip: 높이가 있으면 옆면까지)
static func hl_shape(o: Vector2, h: float) -> PackedVector2Array:
	if h > 0.0:
		return PackedVector2Array([o + Vector2(TW, 1), o + Vector2(TW * 2 - 1, TH), o + Vector2(TW * 2 - 1, TH + h),
			o + Vector2(TW, TH * 2 - 1 + h), o + Vector2(1, TH + h), o + Vector2(1, TH)])
	return PackedVector2Array([o + Vector2(TW, 1), o + Vector2(TW * 2 - 1, TH), o + Vector2(TW, TH * 2 - 1), o + Vector2(1, TH)])
