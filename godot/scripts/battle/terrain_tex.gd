extends RefCounted
## 절차적 지형 그림 — 웹 js/battle/terrain-tex.js 의 _draw 를 CanvasItem 그리기 명령으로 옮김
##  웹은 타일 종류·테마 색·변형마다 캔버스(2배)에 그려 dataURL 로 캐시했지만, 여기서는 같은 명령을 벡터로 바로 그린다
##  (확대해도 선명, 그리기 명령은 Godot 이 노드에 캐시 — 카메라 회전·지형 변화 때만 다시 그림).
##  난수(LCG)·순서를 웹과 같게 해서 풀·자갈·바위 모양이 웹과 같은 자리에 나온다.
##  좌표: 타일 그림 원점(왼쪽 위) 기준 — 윗면 마름모 (TW,0)-(2TW,TH)-(TW,2TH)-(0,TH), 옆면은 아래로 h, 성가퀴는 위로 CAP

const TW := 48.0
const TH := 24.0
const VARIANTS := 3
## 성벽 성가퀴 높이(px) — 윗면보다 이만큼 위로 솟음
const CAP := {"wall": 9.0}
## 언덕 경사: 열린 변에서 윗면(고원)이 안쪽으로 물러나는 정도 (칸 변 길이의 비율) — 경사면이 이만큼의 폭으로 평지까지 내려옴
const HILL_A := 0.2
## 언덕 모양 비트: 1·2·4·8 = 열린 변 (u=0 뒤-왼쪽 · v=0 뒤-오른쪽 · v=1 앞-왼쪽 · u=1 앞-오른쪽, 성가퀴 open 과 같은 번호),
##  16<<i (i=0..7) = 이웃 언덕과 맞닿는 닫힌 변의 끝에서 높이가 어긋나는 곳에 세우는 삼각 옆벽 (GAP_DEFS 순서)
const GAP_BASE := 16


## 웹 _rand: s = s*1664525 + 1013904223 (32비트)
class Lcg:
	var s: int = 1

	func _init(seed: int) -> void:
		s = seed & 0xFFFFFFFF
		if s == 0:
			s = 1

	func next() -> float:
		s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
		return float(s) / 4294967296.0


## 타일 좌표로 변형 번호 고정 (웹 variantOf: ((c*73856093) ^ (r*19349663)) >>> 0) % 3)
static func variant_of(c: int, r: int) -> int:
	var a := _i32(c * 73856093)
	var b := _i32(r * 19349663)
	return ((a ^ b) & 0xFFFFFFFF) % VARIANTS


## JS ToInt32 (곱이 32비트를 넘을 때 웹과 같게)
static func _i32(v: int) -> int:
	var x := v & 0xFFFFFFFF
	return x - 0x100000000 if x >= 0x80000000 else x


# ── 색 (웹 _mix: 채널마다 반올림한 rgb) ──

static func _mix(base: Color, to: Color, k: float) -> Color:
	return Color8(roundi(base.r8 + (to.r8 - base.r8) * k), roundi(base.g8 + (to.g8 - base.g8) * k), roundi(base.b8 + (to.b8 - base.b8) * k))


static func lit(c: Color, k: float) -> Color:
	return _mix(c, Color.WHITE, k)


static func dk(c: Color, k: float) -> Color:
	return _mix(c, Color.BLACK, k)


static func _rgba(r: int, g: int, b: int, a: float) -> Color:
	return Color8(r, g, b, roundi(a * 255.0))


# ── 도형 도우미 ──

static func ellipse_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0, a0: float = 0.0, a1: float = TAU, seg: int = 18) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cs := cos(rot)
	var sn := sin(rot)
	for i in seg + 1:
		var a := a0 + (a1 - a0) * float(i) / float(seg)
		var p := Vector2(cos(a) * rx, sin(a) * ry)
		out.append(c + Vector2(p.x * cs - p.y * sn, p.x * sn + p.y * cs))
	return out


static func _fill_ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	var pts := ellipse_pts(c, rx, ry, rot, 0.0, TAU, 14)
	pts.remove_at(pts.size() - 1)
	ci.draw_colored_polygon(pts, col)


## 2차 베지어를 점으로
static func _quad(p0: Vector2, c: Vector2, p1: Vector2, out: PackedVector2Array, seg: int = 6) -> void:
	for i in range(1, seg + 1):
		var t := float(i) / float(seg)
		out.append(p0.lerp(c, t).lerp(c.lerp(p1, t), t))


## 선형 그라디언트 색 (a→b 축에 투영, 두 정지점)
static func _lin(pts: PackedVector2Array, a: Vector2, b: Vector2, c0: Color, c1: Color) -> PackedColorArray:
	var ab := b - a
	var l2 := ab.length_squared()
	var out := PackedColorArray()
	for p: Vector2 in pts:
		out.append(c0.lerp(c1, clampf((p - a).dot(ab) / l2, 0.0, 1.0)))
	return out


## 원형 그라디언트를 부채꼴 삼각형으로 (가운데 c, 반지름 r0→r1, 색 c0→c1) — 테두리 poly 를 잘게 나눠 근사
static func _radial_fill(ci: CanvasItem, poly: PackedVector2Array, c: Vector2, r0: float, r1: float, c0: Color, c1: Color, sub: int = 6) -> void:
	var rim := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		for k in sub:
			rim.append(a.lerp(b, float(k) / float(sub)))
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([c0.lerp(c1, clampf((0.0 - r0) / (r1 - r0), 0.0, 1.0))])
	for p: Vector2 in rim:
		pts.append(p)
		cols.append(c0.lerp(c1, clampf((p.distance_to(c) - r0) / (r1 - r0), 0.0, 1.0)))
	var idx := PackedInt32Array()
	var n := rim.size()
	for i in n:
		idx.append_array([0, 1 + i, 1 + (i + 1) % n])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


static func _stroke(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, closed: bool = false) -> void:
	if closed and pts.size() > 0:
		var p2 := pts.duplicate()
		p2.append(pts[0])
		ci.draw_polyline(p2, col, w, true)
	else:
		ci.draw_polyline(pts, col, w, true)


# ── 타일 한 장 ──

## tp: 지형 종류, clr: {tc,lc,rc} (Color), v: 변형 번호, h: 옆면 높이(px), open: 성가퀴를 세울 화면 가장자리 비트
## o: 타일 그림 원점 (화면 좌표 — 웹 bgTile 의 left, top + cap)
static func draw_tile(ci: CanvasItem, o: Vector2, tp: String, clr: Dictionary, v: int, h: float, open: int) -> void:
	var tc: Color = clr["tc"]
	var lc: Color = clr["lc"]
	var rc: Color = clr["rc"]
	var W := TW * 2.0
	var seed := (tp.length() * 7919 + v * 104729 + int(h) * 31) ^ ((((7 * 31 + tc.r8) * 31 + tc.g8) * 31) + tc.b8)
	var rnd := Lcg.new(seed)
	var top := PackedVector2Array([o + Vector2(TW, 0.5), o + Vector2(W - 0.5, TH), o + Vector2(TW, TH * 2 - 0.5), o + Vector2(0.5, TH)])

	if tp == "hill":
		_draw_hill(ci, o, clr, v, h, open, rnd)
		return
	if tp == "rock":
		_draw_rock(ci, o, clr, v, h, open, rnd)
		return

	# 다이아몬드 안 무작위 점 (웹 pt)
	var pt := func(m: float) -> Vector2:
		while true:
			var x := rnd.next() * W
			var y := rnd.next() * TH * 2.0
			if absf(x - TW) / TW + absf(y - TH) / TH <= m:
				return o + Vector2(x, y)
		return o

	# ── 옆면 (높이가 있는 타일) ──
	if h > 0.0:
		_side(ci, o, tp, lc, 0.0, true, h, rnd)
		_side(ci, o, tp, rc, 0.1, false, h, rnd)

	# ── 윗면 바탕: 위쪽이 밝은 조명 그라디언트 ──
	ci.draw_polygon(top, _lin(top, o + Vector2(TW * 0.6, 0), o + Vector2(TW * 1.3, TH * 2), lit(tc, 0.10), dk(tc, 0.12)))
	# 미세 노이즈
	for i in 70:
		var p: Vector2 = pt.call(1.0)
		var col: Color
		if rnd.next() < 0.5:
			col = lit(tc, 0.08 + rnd.next() * 0.08)
		else:
			col = dk(tc, 0.08 + rnd.next() * 0.1)
		ci.draw_rect(Rect2(p, Vector2.ONE), col)

	match tp:
		"gate":
			# 나무 판자 (윗면 안으로 자름)
			var pc := dk(tc, 0.35)
			var x := -TH
			while x < W:
				for seg: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([o + Vector2(x, 0), o + Vector2(x + TH * 2, TH * 2)]), top):
					ci.draw_polyline(seg, pc, 0.8, true)
				x += 9.0
		"plain":
			# 풀 무더기
			var blade := lit(tc, 0.22)
			var blade_d := dk(tc, 0.2)
			for i in 9 + v * 2:
				var p: Vector2 = pt.call(0.8)
				for j in 3:
					var a := p + Vector2(j * 1.2, 0)
					var b := p + Vector2(j * 1.2 + (j - 1) * 1.2, -2.5 - rnd.next() * 1.5)
					ci.draw_line(a, b, blade if j == 1 else blade_d, 0.8, true)
			# 작은 꽃·자갈 (변형마다 다르게)
			for i in v + 1:
				var p2: Vector2 = pt.call(0.7)
				var fc: Color = _rgba(250, 230, 140, 0.75) if v == 2 else (_rgba(255, 255, 255, 0.55) if v == 1 else lit(tc, 0.3))
				ci.draw_circle(p2, 0.9, fc, true, -1.0, true)
		"water":
			# 깊이 그라디언트 + 물결
			_radial_fill(ci, top, o + Vector2(TW, TH), 2.0, TW, dk(tc, 0.15), lit(tc, 0.12))
			var wc := _rgba(255, 255, 255, 0.22)
			for i in 4:
				var p5: Vector2 = pt.call(0.7)
				var L := 6.0 + rnd.next() * 6.0
				var line := PackedVector2Array([p5 + Vector2(-L, 0)])
				_quad(p5 + Vector2(-L, 0), p5 + Vector2(-L / 2.0, -1.6), p5, line)
				_quad(p5, p5 + Vector2(L / 2.0, 1.6), p5 + Vector2(L, 0), line)
				ci.draw_polyline(line, wc, 0.8, true)
		"shallow":
			# 여울: 밝은 얕은 물 + 바닥 자갈 + 잔물결
			_radial_fill(ci, top, o + Vector2(TW, TH), 2.0, TW, lit(tc, 0.12), dk(tc, 0.08))
			for i in 7:
				var p6: Vector2 = pt.call(0.75)
				var col2 := _rgba(0, 0, 0, 0.12 + rnd.next() * 0.1)
				var rx := 1.5 + rnd.next() * 2.0
				var ry := 0.8 + rnd.next()
				_fill_ellipse(ci, p6, rx, ry, col2)
			var sc2 := _rgba(255, 255, 255, 0.30)
			for i in 3:
				var p7: Vector2 = pt.call(0.6)
				var L2 := 4.0 + rnd.next() * 4.0
				var line2 := PackedVector2Array([p7 + Vector2(-L2, 0)])
				_quad(p7 + Vector2(-L2, 0), p7 + Vector2(0, -1.4), p7 + Vector2(L2, 0), line2)
				ci.draw_polyline(line2, sc2, 0.7, true)
		"wall":
			# 윗면 석판 줄눈 (마름모를 3등분)
			var jc := dk(tc, 0.35)
			for i in range(1, 3):
				var k2 := float(i) / 3.0
				ci.draw_line(o + Vector2(TW * k2, TH - TH * k2), o + Vector2(TW + TW * k2, TH * 2 - TH * k2), jc, 0.7, true)
				ci.draw_line(o + Vector2(TW * k2, TH + TH * k2), o + Vector2(TW + TW * k2, TH * k2), jc, 0.7, true)

	# ── 가장자리: 위쪽 두 변은 밝게, 아래 두 변은 어둡게 → 격자 구분 ──
	var edge_hi := _rgba(160, 210, 255, 0.18) if (tp == "water" or tp == "shallow") else _rgba(255, 255, 255, 0.10)
	ci.draw_polyline(PackedVector2Array([o + Vector2(0.5, TH), o + Vector2(TW, 0.5), o + Vector2(W - 0.5, TH)]), edge_hi, 1.0, true)
	ci.draw_polyline(PackedVector2Array([o + Vector2(0.5, TH), o + Vector2(TW, TH * 2 - 0.5), o + Vector2(W - 0.5, TH)]), _rgba(0, 0, 0, 0.28), 1.0, true)

	if tp == "wall" and open != 0:
		_merlons(ci, o, tc, lc, rc, open)


## 옆면: 위 밝고 아래 어두운 그라디언트 + 지층(또는 벽돌)
static func _side(ci: CanvasItem, o: Vector2, tp: String, base: Color, shade: float, is_left: bool, h: float, rnd: Lcg) -> void:
	var face: PackedVector2Array
	if is_left:
		face = PackedVector2Array([o + Vector2(0.5, TH), o + Vector2(TW, TH * 2), o + Vector2(TW, TH * 2 + h), o + Vector2(0.5, TH + h)])
	else:
		face = PackedVector2Array([o + Vector2(TW, TH * 2), o + Vector2(TW * 2 - 0.5, TH), o + Vector2(TW * 2 - 0.5, TH + h), o + Vector2(TW, TH * 2 + h)])
	ci.draw_polygon(face, _lin(face, o + Vector2(0, TH), o + Vector2(0, TH * 2 + h), lit(base, 0.06), dk(base, 0.35)))
	var lc := dk(base, 0.3 + shade)
	var seg := func(k: float) -> void:
		if is_left:
			ci.draw_line(o + Vector2(0, TH + k), o + Vector2(TW, TH * 2 + k), lc, 0.6, true)
		else:
			ci.draw_line(o + Vector2(TW, TH * 2 + k), o + Vector2(TW * 2, TH + k), lc, 0.6, true)
	if tp == "wall":
		# 벽돌: 돌마다 명암 + 기울어진 가로 줄눈 + 엇갈린 세로 줄눈
		var row := 0
		var k := 0.0
		while k < h:
			var x := float((row % 2) * 6 - 12)
			while x < TW:
				var x0 := maxf(0.0, x + 3.0)
				var x1 := minf(TW, x + 15.0)
				if x1 > x0:
					var col: Color
					if rnd.next() < 0.5:
						col = _rgba(255, 255, 255, 0.03 + rnd.next() * 0.07)
					else:
						col = _rgba(0, 0, 0, 0.05 + rnd.next() * 0.12)
					var X := func(xx: float) -> float: return xx if is_left else TW + xx
					var Y := func(xx: float, kk: float) -> float: return (TH + xx / 2.0 + kk) if is_left else (TH * 2 - xx / 2.0 + kk)
					ci.draw_colored_polygon(PackedVector2Array([
						o + Vector2(X.call(x0), Y.call(x0, k)), o + Vector2(X.call(x1), Y.call(x1, k)),
						o + Vector2(X.call(x1), Y.call(x1, k + 5)), o + Vector2(X.call(x0), Y.call(x0, k + 5))]), col)
				x += 12.0
			k += 5.0
			row += 1
		var row2 := 0
		var k2 := 5.0
		while k2 < h:
			seg.call(k2)
			var x2 := float((row2 % 2) * 6 + 3)
			while x2 < TW:
				var bx := x2 if is_left else TW + x2
				var by := (TH + x2 / 2.0 + k2) if is_left else (TH * 2 - x2 / 2.0 + k2)
				ci.draw_line(o + Vector2(bx, by - 5), o + Vector2(bx, by), lc, 0.6, true)
				x2 += 12.0
			k2 += 5.0
			row2 += 1
	else:
		for i in 3:
			seg.call(h * (0.3 + i * 0.25) + (rnd.next() - 0.5) * 2.0)


# ── 성가퀴: 윗면 가장자리 중 open 쪽에 돌 톱니 3개씩 (웹 _merlons·_edgeBox·_box) ──

static func _edges() -> Array:
	var W := TW * 2.0
	return [[1, Vector2(0, TH), Vector2(TW, 0)], [2, Vector2(TW, 0), Vector2(W, TH)], [4, Vector2(0, TH), Vector2(TW, TH * 2)], [8, Vector2(TW, TH * 2), Vector2(W, TH)]]


static func _edge_box(p: Vector2, q: Vector2, f: float, L: float, T: float) -> PackedVector2Array:
	var ln := p.distance_to(q)
	var u := (q - p) / ln
	var vv := Vector2(u.x, -u.y)
	var m := (p + q) / 2.0
	if (TW - m.x) * vv.x + (TH - m.y) * vv.y < 0.0:
		vv = -vv
	var c := p + (q - p) * f
	var out := PackedVector2Array()
	for st: Array in [[-1, 0], [1, 0], [1, 1], [-1, 1]]:
		out.append(c + u * L / 2.0 * float(st[0]) + vv * T * float(st[1]))
	return out


static func _merlons(ci: CanvasItem, o: Vector2, tc: Color, lc: Color, rc: Color, open: int) -> void:
	var boxes: Array = []
	for e: Array in _edges():
		if not (open & int(e[0])):
			continue
		var p: Vector2 = e[1]
		var q: Vector2 = e[2]
		for i in 3:
			boxes.append(_edge_box(p, q, (i + 0.5) / 3.0, p.distance_to(q) / 3.0, 5.0))
	var sc := dk(lc, 0.45)
	var t_col := lit(tc, 0.12)
	boxes.sort_custom(func(A: PackedVector2Array, B: PackedVector2Array) -> bool:
		return (A[0].y + A[1].y + A[2].y + A[3].y) < (B[0].y + B[1].y + B[2].y + B[3].y))
	for g: PackedVector2Array in boxes:
		var up := PackedVector2Array()
		for p2: Vector2 in g:
			up.append(p2 + Vector2(0, -9))
		var faces: Array = []
		for ij: Array in [[0, 1], [1, 2], [2, 3], [3, 0]]:
			faces.append({"i": ij[0], "j": ij[1], "y": (g[ij[0]].y + g[ij[1]].y) / 2.0, "dx": g[ij[1]].x - g[ij[0]].x})
		faces.sort_custom(func(A: Dictionary, B: Dictionary) -> bool: return A["y"] < B["y"])
		for f: Dictionary in faces:
			var poly := PackedVector2Array([o + g[f["i"]], o + g[f["j"]], o + up[f["j"]], o + up[f["i"]]])
			ci.draw_colored_polygon(poly, rc if f["dx"] > 0.0 else lc)
			_stroke(ci, poly, sc, 0.6, true)
		var topp := PackedVector2Array()
		for p3: Vector2 in up:
			topp.append(o + p3)
		ci.draw_colored_polygon(topp, t_col)
		_stroke(ci, topp, sc, 0.6, true)


# ═══════════ 언덕 (경사) ═══════════
##  언덕 칸은 이웃이 언덕이 아닌 변마다 윗면(고원)을 HILL_A 만큼 안쪽으로 물리고, 그 사이를 평지 높이까지 내려오는 경사면으로 잇는다.
##  이웃도 언덕인 변은 그대로 이어져(능선) 평평하다. 모서리 둘이 모두 열리면 두 경사면이 모서리 선(hip)에서 만나 둔덕 모서리가 된다.
##  점 (u, v, z): u = 화면 가로 칸 방향(vc), v = 세로 칸 방향(vr) — 0..1, z = 0 평지 · 1 언덕 윗면. 타일 그림 원점 o 는 윗면 기준.

## 닫힌 변 끝의 삼각 옆벽 정의: [조건 변 비트 대신 인덱스 순서] — {pts: 삼각형 (u, v, z) 3점, right: 오른쪽 면(어두운 쪽) 여부}
static func _gap_defs() -> Array:
	var a := HILL_A
	return [
		{"p": [[0, 0, 0], [0, a, 1], [0, 0, 1]], "right": true},
		{"p": [[0, 1, 0], [0, 1.0 - a, 1], [0, 1, 1]], "right": true},
		{"p": [[0, 0, 0], [a, 0, 1], [0, 0, 1]], "right": false},
		{"p": [[1, 0, 0], [1.0 - a, 0, 1], [1, 0, 1]], "right": false},
		{"p": [[1, 0, 0], [1, a, 1], [1, 0, 1]], "right": true},
		{"p": [[1, 1, 0], [1, 1.0 - a, 1], [1, 1, 1]], "right": true},
		{"p": [[0, 1, 0], [a, 1, 1], [0, 1, 1]], "right": false},
		{"p": [[1, 1, 0], [1.0 - a, 1, 1], [1, 1, 1]], "right": false},
	]


## 언덕 모양 비트 (위 설명). is_hill: Callable(du: int, dv: int) -> bool — 화면 기준 칸 (u=vc, v=vr) 이웃이 언덕인가
static func hill_flags(is_hill: Callable) -> int:
	var f := 0
	var ou0 := not bool(is_hill.call(-1, 0))
	var ov0 := not bool(is_hill.call(0, -1))
	var ov1 := not bool(is_hill.call(0, 1))
	var ou1 := not bool(is_hill.call(1, 0))
	if ou0:
		f |= 1
	if ov0:
		f |= 2
	if ov1:
		f |= 4
	if ou1:
		f |= 8
	var g := [
		(not ou0) and ov0 and bool(is_hill.call(-1, -1)),
		(not ou0) and ov1 and bool(is_hill.call(-1, 1)),
		(not ov0) and ou0 and bool(is_hill.call(-1, -1)),
		(not ov0) and ou1 and bool(is_hill.call(1, -1)),
		(not ou1) and (not ov0) and not bool(is_hill.call(1, -1)),
		(not ou1) and (not ov1) and not bool(is_hill.call(1, 1)),
		(not ov1) and (not ou0) and not bool(is_hill.call(-1, 1)),
		(not ov1) and (not ou1) and not bool(is_hill.call(1, 1)),
	]
	for i in 8:
		if g[i]:
			f |= GAP_BASE << i
	return f


## (u, v, z) → 타일 그림 좌표. 가장자리 선이 잘리지 않게 칸 가장자리를 0.5px 안쪽으로 (윗면 마름모의 0.5 안쪽과 같음)
static func _hp(o: Vector2, h: float, u: float, v: float, z: float) -> Vector2:
	var uu := 0.0105 + 0.979 * u
	var vv := 0.0105 + 0.979 * v
	return o + Vector2((uu - vv) * TW + TW, (uu + vv) * TH + (1.0 - z) * h)


## 언덕 칸의 면들 {name, pts (화면 좌표), kind: "top"|"slope"|"gap", right(어두운 쪽 면), g0·g1(경사: 바닥 두 점) t0·t1(꼭대기 두 점)} — 뒤에서 앞 순서
static func hill_faces(o: Vector2, h: float, flags: int) -> Array:
	var a := HILL_A
	var ou0 := (flags & 1) != 0
	var ov0 := (flags & 2) != 0
	var ov1 := (flags & 4) != 0
	var ou1 := (flags & 8) != 0
	var ua := a if ou0 else 0.0
	var ub := 1.0 - a if ou1 else 1.0
	var va := a if ov0 else 0.0
	var vb := 1.0 - a if ov1 else 1.0
	var back: Array = []
	var front: Array = []
	# 경사: 바닥 변 (두 점) → 꼭대기 변 (두 점)
	if ou0:
		back.append(_slope(o, h, [[0, 0], [0, 1]], [[ua, va], [ua, vb]], false))
	if ov0:
		back.append(_slope(o, h, [[0, 0], [1, 0]], [[ua, va], [ub, va]], true))
	if ou1:
		front.append(_slope(o, h, [[1, 0], [1, 1]], [[ub, va], [ub, vb]], true))
	if ov1:
		front.append(_slope(o, h, [[0, 1], [1, 1]], [[ua, vb], [ub, vb]], false))
	var faces: Array = []
	faces.append_array(back)
	var top := {"kind": "top", "pts": PackedVector2Array([_hp(o, h, ua, vb, 1), _hp(o, h, ua, va, 1), _hp(o, h, ub, va, 1), _hp(o, h, ub, vb, 1)])}
	var gaps_back: Array = []
	var gaps_front: Array = []
	var gd := _gap_defs()
	for i in 8:
		if (flags & (GAP_BASE << i)) == 0:
			continue
		var pp: Array = gd[i]["p"]
		var f := {"kind": "gap", "right": gd[i]["right"], "pts": PackedVector2Array([_hp(o, h, pp[0][0], pp[0][1], pp[0][2]), _hp(o, h, pp[1][0], pp[1][1], pp[1][2]), _hp(o, h, pp[2][0], pp[2][1], pp[2][2])])}
		if i < 4:
			gaps_back.append(f)
		else:
			gaps_front.append(f)
	faces.append_array(gaps_back)
	faces.append(top)
	faces.append_array(gaps_front)
	faces.append_array(front)
	return faces


static func _slope(o: Vector2, h: float, g: Array, t: Array, right: bool) -> Dictionary:
	var g0 := _hp(o, h, g[0][0], g[0][1], 0)
	var g1 := _hp(o, h, g[1][0], g[1][1], 0)
	var t0 := _hp(o, h, t[0][0], t[0][1], 1)
	var t1 := _hp(o, h, t[1][0], t[1][1], 1)
	return {"kind": "slope", "right": right, "g0": g0, "g1": g1, "t0": t0, "t1": t1, "pts": PackedVector2Array([g0, g1, t1, t0])}


## 언덕이 화면에서 덮는 모양 (경사 포함) — 하이라이트·클릭 판정용. 타일 그림 원점 기준
static func hill_shape(o: Vector2, h: float, flags: int) -> PackedVector2Array:
	var polys: Array = []
	for f: Dictionary in hill_faces(o, h, flags):
		polys.append(f["pts"])
	var acc: Array = [polys[0]]
	for i in range(1, polys.size()):
		var next: Array = []
		var merged := false
		for q: PackedVector2Array in acc:
			var m := Geometry2D.merge_polygons(q, polys[i])
			if not merged and m.size() == 1:
				next.append(m[0])
				merged = true
			else:
				next.append(q)
		if not merged:
			next.append(polys[i])
		acc = next
	# 가장 큰 바깥 모양 하나 (구멍·조각 무시)
	var best: PackedVector2Array = acc[0]
	var best_a := 0.0
	for q2: PackedVector2Array in acc:
		var ar := absf(_area(q2))
		if ar > best_a:
			best_a = ar
			best = q2
	return best


static func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		s += p[i].x * q.y - q.x * p[i].y
	return s / 2.0


static func _draw_hill(ci: CanvasItem, o: Vector2, clr: Dictionary, v: int, h: float, flags: int, rnd: Lcg) -> void:
	var tc: Color = clr["tc"]
	var lc: Color = clr["lc"]
	var rc: Color = clr["rc"]
	var gc: Color = clr.get("gc", dk(tc, 0.12))
	var faces := hill_faces(o, h, flags)
	var plateau := PackedVector2Array()
	for f: Dictionary in faces:
		match f["kind"]:
			"top":
				plateau = f["pts"]
				_hill_plateau(ci, o, tc, v, flags, plateau, rnd)
			"slope":
				_hill_slope(ci, f, tc, lc, rc, gc, rnd)
			"gap":
				var side: Color = rc if f["right"] else lc
				var pts: PackedVector2Array = f["pts"]
				# 옆면(수직 벽) — 기존 언덕 옆면과 같은 위 밝고 아래 어두운 색
				ci.draw_polygon(pts, PackedColorArray([dk(side, 0.30), lit(side, 0.06), lit(side, 0.06)]))


static func _hill_slope(ci: CanvasItem, f: Dictionary, tc: Color, lc: Color, rc: Color, gc: Color, rnd: Lcg) -> void:
	# 왼쪽 면은 lc(밝은 쪽), 오른쪽 면은 rc(어두운 쪽) — 기존 옆면과 같은 빛 방향.
	# 위(윗면 색) → 아래(평지 색)로 부드럽게: 평지와 이어지게 아래쪽은 평지 색 쪽으로
	var right: bool = f["right"]
	var side: Color = rc if right else lc
	var top_c := _mix(tc, side, 0.14)
	var bot_c := _mix(gc, side, 0.10)
	if right:
		top_c = dk(top_c, 0.10)
		bot_c = dk(bot_c, 0.10)
	var g0: Vector2 = f["g0"]
	var g1: Vector2 = f["g1"]
	var t0: Vector2 = f["t0"]
	var t1: Vector2 = f["t1"]
	ci.draw_polygon(f["pts"], PackedColorArray([bot_c, bot_c, top_c, top_c]))
	# 등고선 두 줄 (경사를 따라 가로로) + 풀 몇 포기
	var lcol := dk(top_c, 0.22)
	lcol.a = 0.55
	lcol.a = 0.35
	ci.draw_line(g0.lerp(t0, 0.55), g1.lerp(t1, 0.55), lcol, 0.6, true)
	var blade := lit(top_c, 0.22)
	blade.a = 0.8
	for i in 5:
		var s1 := rnd.next()
		var s2 := 0.15 + rnd.next() * 0.7
		var base := g0.lerp(g1, s1).lerp(t0.lerp(t1, s1), s2)
		ci.draw_line(base, base + Vector2((rnd.next() - 0.5) * 2.0, -2.2), blade, 0.8, true)


static func _hill_plateau(ci: CanvasItem, o: Vector2, tc: Color, v: int, flags: int, pl: PackedVector2Array, rnd: Lcg) -> void:
	# pl: L, T, R, B 순서 (왼·위·오른·아래 꼭짓점)
	ci.draw_polygon(pl, _lin(pl, o + Vector2(TW * 0.6, 0), o + Vector2(TW * 1.3, TH * 2), lit(tc, 0.10), dk(tc, 0.12)))
	var W := TW * 2.0
	var pt := func(m: float) -> Vector2:
		while true:
			var x := rnd.next() * W
			var y := rnd.next() * TH * 2.0
			if absf(x - TW) / TW + absf(y - TH) / TH <= m:
				return o + Vector2(x, y)
		return o
	for i in 70:
		var p: Vector2 = pt.call(1.0)
		var col: Color
		if rnd.next() < 0.5:
			col = lit(tc, 0.08 + rnd.next() * 0.08)
		else:
			col = dk(tc, 0.08 + rnd.next() * 0.1)
		if Geometry2D.is_point_in_polygon(p + Vector2(0.5, 0.5), pl) and Geometry2D.is_point_in_polygon(p, pl):
			ci.draw_rect(Rect2(p, Vector2.ONE), col)
	# 등고선 (고원 크기에 맞춰) + 자갈
	var ctr := (pl[0] + pl[2]) * 0.5
	var sc := ((pl[2].x - pl[0].x) / W + (pl[3].y - pl[1].y) / (TH * 2.0)) * 0.5
	for i in range(1, 3):
		var k := 0.25 * i + 0.1
		ci.draw_polyline(ellipse_pts(ctr, TW * k * sc, TH * k * sc, 0.0, 3.4, 6.0, 16), lit(tc, 0.22), 0.7, true)
	for i in 4:
		var p3: Vector2 = pt.call(0.75)
		if Geometry2D.is_point_in_polygon(p3, pl):
			_fill_ellipse(ci, p3, 1.6, 1.0, dk(tc, 0.3))
	# 가장자리: 이웃 언덕과 이어지는(닫힌) 변은 격자 선, 열린 변은 마루선(밝게)
	var hi := _rgba(255, 255, 255, 0.10)
	var lo := _rgba(0, 0, 0, 0.28)
	var crest := _rgba(255, 255, 255, 0.13)
	var edges := [[0, 1, 1], [1, 2, 2], [0, 3, 4], [3, 2, 8]]   # L→T(u0) · T→R(v0) · L→B(v1) · B→R(u1)
	for e: Array in edges:
		var open := (flags & int(e[2])) != 0
		var back: bool = int(e[2]) <= 2
		var col: Color
		if back:
			col = crest if open else hi
		else:
			col = _rgba(0, 0, 0, 0.12) if open else lo
		ci.draw_line(pl[int(e[0])], pl[int(e[1])], col, 1.0, true)


# ═══════════ 바위 (절벽) ═══════════
##  이웃이 바위가 아닌 변(open 비트 1·2·4·8 — 언덕과 같은 번호)만 들쭉날쭉한 능선·밝은 마루선을 그리고,
##  바위끼리 맞닿는 변은 매끈하게 이어 하나의 큰 절벽처럼 보이게 한다. 지층선은 칸 높이만의 함수라 이웃 칸과 높이가 맞는다.

const ROCK_STRATA := [0.17, 0.33, 0.48, 0.68, 0.83]
const ROCK_TINT := [0.05, -0.07, 0.02, -0.09, 0.04, -0.06]


## p→q 꺾은선: 안쪽(inward)으로 0~amp px 들쭉날쭉 (닫힌 변은 직선이지만 난수는 똑같이 씀 — 모양이 변 열림과 무관하게 같은 순서)
static func _jag(p: Vector2, q: Vector2, inward: Vector2, rnd: Lcg, amp: float, closed: bool) -> PackedVector2Array:
	var out := PackedVector2Array([p])
	for i in range(1, 6):
		var a := rnd.next()
		var b := rnd.next()
		var d := a * amp * (1.0 if b < 0.65 else 0.35)
		if closed:
			d = 0.0
		out.append(p.lerp(q, float(i) / 6.0) + inward * d)
	out.append(q)
	return out


static func _draw_rock(ci: CanvasItem, o: Vector2, clr: Dictionary, v: int, h: float, open: int, rnd: Lcg) -> void:
	var tc: Color = clr["tc"]
	var lc: Color = clr["lc"]
	var rc: Color = clr["rc"]
	var W := TW * 2.0
	var Lp := o + Vector2(0.5, TH)
	var Tp := o + Vector2(TW, 0.5)
	var Rp := o + Vector2(W - 0.5, TH)
	var Bp := o + Vector2(TW, TH * 2.0 - 0.5)
	var ctr := o + Vector2(TW, TH)
	var amp := 2.2
	var inw := func(p: Vector2, q: Vector2) -> Vector2: return (ctr - (p + q) * 0.5).normalized()
	var e_u0 := _jag(Lp, Tp, inw.call(Lp, Tp), rnd, amp, (open & 1) == 0)
	var e_v0 := _jag(Tp, Rp, inw.call(Tp, Rp), rnd, amp, (open & 2) == 0)
	var e_u1 := _jag(Rp, Bp, inw.call(Rp, Bp), rnd, amp, (open & 8) == 0)
	var e_v1 := _jag(Lp, Bp, inw.call(Lp, Bp), rnd, amp, (open & 4) == 0)
	# ── 불투명 밑판: 칸 윗면 마름모 + 옆면 직사각 영역을 먼저 꽉 채움 → 들쭉날쭉한 능선 틈으로 뒤 칸이 비치지 않음 ──
	var under := dk(tc, 0.22)
	ci.draw_colored_polygon(PackedVector2Array([Lp, Tp, Rp, Rp + Vector2(0, h), Bp + Vector2(0, h), Lp + Vector2(0, h)]), under)
	# ── 옆면: 왼쪽(v1 변) · 오른쪽(u1 변) ──
	for side in 2:
		var is_left := side == 0
		var edge: PackedVector2Array = e_v1 if is_left else e_u1
		var base: Color = lc if is_left else rc
		var face := PackedVector2Array()
		for ep: Vector2 in edge:
			face.append(ep + Vector2(0, -1.5))
		for k in range(edge.size() - 1, -1, -1):
			face.append(edge[k] + Vector2(0, h))
		ci.draw_polygon(face, _lin(face, o + Vector2(0, TH), o + Vector2(0, TH * 2.0 + h), lit(base, 0.12), dk(base, 0.5)))
		# 지층 띠 (칸 높이에만 따라 위치가 정해져 이웃 칸과 이어짐) — 띠마다 밝기가 다름
		var ys: Array = [0.0]
		ys.append_array(ROCK_STRATA)
		ys.append(1.0)
		for i in ys.size() - 1:
			var y0: float = float(ys[i]) * h
			var y1: float = float(ys[i + 1]) * h
			var tint: float = ROCK_TINT[(i + (0 if is_left else 2)) % ROCK_TINT.size()]
			var tcol := Color(1, 1, 1, tint) if tint > 0.0 else Color(0, 0, 0, -tint)
			var q := PackedVector2Array()
			if is_left:
				q = PackedVector2Array([o + Vector2(0.5, TH + y0), o + Vector2(TW, TH * 2.0 + y0), o + Vector2(TW, TH * 2.0 + y1), o + Vector2(0.5, TH + y1)])
			else:
				q = PackedVector2Array([o + Vector2(TW, TH * 2.0 + y0), o + Vector2(W - 0.5, TH + y0), o + Vector2(W - 0.5, TH + y1), o + Vector2(TW, TH * 2.0 + y1)])
			ci.draw_colored_polygon(q, tcol)
		var lcol := dk(base, 0.6)
		lcol.a = 0.75
		var hcol := lit(base, 0.3)
		hcol.a = 0.22
		for i in range(1, ys.size() - 1):
			var k: float = float(ys[i]) * h
			if is_left:
				ci.draw_line(o + Vector2(0.5, TH + k), o + Vector2(TW, TH * 2.0 + k), lcol, 0.8, true)
				ci.draw_line(o + Vector2(0.5, TH + k + 1.0), o + Vector2(TW, TH * 2.0 + k + 1.0), hcol, 0.6, true)
			else:
				ci.draw_line(o + Vector2(TW, TH * 2.0 + k), o + Vector2(W - 0.5, TH + k), lcol, 0.8, true)
				ci.draw_line(o + Vector2(TW, TH * 2.0 + k + 1.0), o + Vector2(W - 0.5, TH + k + 1.0), hcol, 0.6, true)
		# 바위 결: 가는 세로 줄 + 위에서 내려오는 균열 몇 개
		var fy := func(x: float) -> float:
			return (TH + x * 0.5) if is_left else (TH * 2.0 - x * 0.5)
		var ox := 0.0 if is_left else TW
		var vcol := dk(base, 0.5)
		vcol.a = 0.18
		for i in 6:
			var x := 3.0 + rnd.next() * (TW - 6.0)
			var y0: float = fy.call(x)
			ci.draw_line(o + Vector2(ox + x, y0 + rnd.next() * h * 0.3), o + Vector2(ox + x, y0 + h * (0.5 + rnd.next() * 0.5)), vcol, 0.6, true)
		var ccol := dk(base, 0.7)
		ccol.a = 0.85
		for i in 2 + v % 2:
			var x2 := 4.0 + rnd.next() * (TW - 8.0)
			var y2: float = fy.call(x2) + 1.0
			var pts := PackedVector2Array([o + Vector2(ox + x2, y2)])
			var depth := h * (0.35 + rnd.next() * 0.55)
			var yy := 0.0
			while yy < depth:
				x2 += (rnd.next() - 0.5) * 3.5
				yy += 3.0 + rnd.next() * 4.0
				pts.append(o + Vector2(ox + clampf(x2, 1.0, TW - 1.0), y2 + yy))
			ci.draw_polyline(pts, ccol, 0.8, true)
		# 접지: 아래쪽 어두운 띠 + 바위 부스러기
		var base_a := edge[0] + Vector2(0, h)
		var base_b := edge[edge.size() - 1] + Vector2(0, h)
		var sh := PackedVector2Array([base_a + Vector2(0, -5), base_b + Vector2(0, -5), base_b, base_a])
		ci.draw_polygon(sh, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.38), Color(0, 0, 0, 0.38)]))
		for i in 4:
			var x3 := 3.0 + rnd.next() * (TW - 6.0)
			var yb: float = fy.call(x3) + h - 0.5
			_fill_ellipse(ci, o + Vector2(ox + x3, yb), 1.2 + rnd.next() * 1.5, 0.8 + rnd.next() * 0.6, dk(base, 0.15 + rnd.next() * 0.2))
	# 앞쪽 모서리(왼·오른 면이 만나는 선) 어둡게
	ci.draw_line(Bp, Bp + Vector2(0, h), _rgba(0, 0, 0, 0.35), 0.8, true)
	# ── 윗면 ──
	var top := PackedVector2Array()
	for e: PackedVector2Array in [e_v0, e_u1]:
		for i in e.size() - 1:
			top.append(e[i])
	var rv := PackedVector2Array(e_v1)
	rv.reverse()
	for i in rv.size() - 1:
		top.append(rv[i])
	for i in e_u0.size() - 1:   # L → T
		top.append(e_u0[i])
	if Geometry2D.triangulate_polygon(top).is_empty():
		top = PackedVector2Array([Tp, Rp, Bp, Lp])   # 능선이 꼬였을 때의 안전장치 (곧은 마름모)
	ci.draw_polygon(top, _lin(top, o + Vector2(TW * 0.6, 0), o + Vector2(TW * 1.3, TH * 2.0), lit(tc, 0.22), dk(tc, 0.04)))
	var pt := func(m: float) -> Vector2:
		while true:
			var x := rnd.next() * W
			var y := rnd.next() * TH * 2.0
			if absf(x - TW) / TW + absf(y - TH) / TH <= m:
				return o + Vector2(x, y)
		return o
	for i in 50:
		var p: Vector2 = pt.call(0.95)
		var col: Color = lit(tc, 0.06 + rnd.next() * 0.08) if rnd.next() < 0.5 else dk(tc, 0.08 + rnd.next() * 0.1)
		if Geometry2D.is_point_in_polygon(p, top):
			ci.draw_rect(Rect2(p, Vector2.ONE), col)
	# 이끼 조각 · 풀 · 돌 부스러기 · 균열
	var moss := _mix(tc, Color8(90, 130, 60), 0.45)
	for i in 3:
		var p2: Vector2 = pt.call(0.6)
		if Geometry2D.is_point_in_polygon(p2, top):
			var mc := moss
			mc.a = 0.5
			_fill_ellipse(ci, p2, 3.0 + rnd.next() * 3.0, 1.4 + rnd.next() * 1.2, mc, -0.2)
			for j in 2:
				var b := p2 + Vector2((rnd.next() - 0.5) * 5.0, 0)
				ci.draw_line(b, b + Vector2((rnd.next() - 0.5) * 1.5, -2.5), lit(moss, 0.2), 0.8, true)
	for i in 5:
		var p3: Vector2 = pt.call(0.8)
		if Geometry2D.is_point_in_polygon(p3, top):
			_fill_ellipse(ci, p3, 1.0 + rnd.next() * 1.4, 0.6 + rnd.next() * 0.6, lit(tc, 0.12 + rnd.next() * 0.12) if i % 2 == 0 else dk(tc, 0.3))
	var kc := dk(tc, 0.5)
	kc.a = 0.8
	for k in 2:
		var cp: Vector2 = pt.call(0.55)
		var crack := PackedVector2Array([cp])
		for i in 3:
			cp += Vector2((rnd.next() - 0.4) * 9.0, (rnd.next() - 0.5) * 4.0)
			crack.append(cp)
		ci.draw_polyline(crack, kc, 0.7, true)
	# 마루선: 이웃이 바위가 아닌 변만 밝게 (이어지는 변은 선 없음 → 하나의 큰 절벽)
	var rim := lit(tc, 0.28)
	rim.a = 0.7
	var rim_d := dk(tc, 0.35)
	rim_d.a = 0.5
	for e2: Array in [[e_u0, 1, true], [e_v0, 2, true], [e_v1, 4, false], [e_u1, 8, false]]:
		if (open & int(e2[1])) != 0:
			ci.draw_polyline(e2[0], rim if e2[2] else lit(tc, 0.3), 1.4, true)
