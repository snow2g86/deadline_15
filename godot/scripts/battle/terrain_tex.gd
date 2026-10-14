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
		"hill":
			# 등고선 + 자갈
			for i in range(1, 3):
				var k := 0.25 * i + 0.1
				ci.draw_polyline(ellipse_pts(o + Vector2(TW, TH), TW * k, TH * k, 0.0, 3.4, 6.0, 16), lit(tc, 0.22), 0.7, true)
			for i in 4:
				var p3: Vector2 = pt.call(0.75)
				_fill_ellipse(ci, p3, 1.6, 1.0, dk(tc, 0.3))
		"rock":
			for i in 3:
				var p4: Vector2 = pt.call(0.8)
				_fill_ellipse(ci, p4, 2.2, 1.4, lit(tc, 0.15))
			var cx := TW + (rnd.next() - 0.5) * 6.0
			var cy := TH - 1.0
			var R := 20.0 + v * 2.0
			var blob := PackedVector2Array()
			for i in 7:
				var a := float(i) / 7.0 * 6.283 + rnd.next() * 0.4
				var bx := cx + cos(a) * R * (0.8 + rnd.next() * 0.3)
				var by := cy + sin(a) * R * 0.55 * (0.8 + rnd.next() * 0.3)
				blob.append(o + Vector2(bx, by))
			_fill_ellipse(ci, o + Vector2(cx + 2, cy + 5), R, R * 0.4, _rgba(0, 0, 0, 0.3))
			ci.draw_polygon(blob, _lin(blob, o + Vector2(cx - R, cy - R), o + Vector2(cx + R, cy + R), lit(tc, 0.3), dk(tc, 0.25)))
			var sc := dk(tc, 0.45)
			_stroke(ci, blob, sc, 0.7, true)
			# 불규칙한 균열 2줄 + 윗면 하이라이트
			for k in 2:
				var x := cx + (rnd.next() - 0.5) * R
				var y := cy - R * 0.35 + rnd.next() * 3.0
				var crack := PackedVector2Array([o + Vector2(x, y)])
				for i in 3:
					x += (rnd.next() - 0.3) * R * 0.3
					y += R * 0.12 + rnd.next() * 2.0
					crack.append(o + Vector2(x, y))
				ci.draw_polyline(crack, sc, 0.7, true)
			_fill_ellipse(ci, o + Vector2(cx - R * 0.25, cy - R * 0.25), R * 0.35, R * 0.15, _rgba(255, 255, 255, 0.10), -0.3)
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

const _EDGE_BITS := [1, 2, 4, 8]


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
