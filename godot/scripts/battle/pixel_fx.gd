extends Node2D
## 코드로 그리는 픽셀 투사체·임팩트 — 웹 js/battle/pixelfx.js 를 그대로 옮김 (원거리 직업 기본 공격)
##  2px 도트 격자(전장 해상도의 1/2)에 고정 팔레트로만 그림. 위치는 60Hz 고정 간격(재생 속도 배율 반영), 임팩트 프레임은 4틱마다.
##  파티클은 미리 할당한 배열 풀을 다시 씀 (프레임마다 새 객체 없음). 캐릭터 몸에는 아무것도 붙이지 않음.
##  직업 추가: KINDS 에 {fl(비행 ms), arc, wave, draw, trail, hist, impact, burst, up} 한 줄

const P := 2.0
const COL := {
	"w": Color("ffffff"), "y0": Color("fff6d5"), "y1": Color("ffd75e"), "y2": Color("f59e0b"), "y3": Color("b45309"), "br": Color("8a5a2b"), "bd": Color("3b2a1a"),
	"sh0": Color("d9ad6c"), "sh1": Color("8a5a30"), "hd0": Color("eef2fa"), "hd1": Color("9aa3b8"), "fl0": Color("f1ece0"), "fl1": Color("c0392b"),
	"m0": Color("ffffff"), "m1": Color("c9f1ff"), "m2": Color("6fd3ff"), "m3": Color("3b82f6"), "m4": Color("4338ca"), "m5": Color("1e1b4b"),
	"v0": Color("f5e8ff"), "v1": Color("d8b4fe"), "v2": Color("a855f7"), "v3": Color("7e22ce"), "v4": Color("3b0764"),
	"g0": Color("ecfccb"), "g1": Color("86efac"), "g2": Color("22c55e"), "g3": Color("15803d"), "pu": Color("9333ea"), "pd": Color("581c87"),
	"ol": Color("1c1408"),
}
var PALS: Array = []
const SPOKES := [[1.0, 0.0], [-1.0, 0.0], [0.0, 1.0], [0.0, -1.0], [0.7, 0.7], [-0.7, 0.7], [0.7, -0.7], [-0.7, -0.7]]

# 스프라이트 (문자 격자, 가운데 기준)
const ORB := ["..bbb..", ".bcccb.", "bcwwwcb", "bcwwwcb", "bcwwwcb", ".bcccb.", "..bbb.."]
const ORB2 := ["...b...", ".bbcbb.", ".ccwcc.", "bcwwwcb", ".ccwcc.", ".bbcbb.", "...b..."]
const HOLY := ["..w..", ".wyw.", "wyWyw", ".wyw.", "..w.."]
const HOLY2 := ["w...w", ".wyw.", ".yWy.", ".wyw.", "w...w"]
const RUNE := ["...a...", "..aba..", ".abcba.", "abcwcba", ".abcba.", "..aba..", "...a..."]
const RUNE2 := [".aaaaa.", "ab...ba", "a.bcb.a", "a.cwc.a", "a.bcb.a", "ab...ba", ".aaaaa."]
const WISP := [".bbb.", "bcccb", "bcwcb", "bcccb", ".bbb."]
const WISP2 := ["..b..", ".bcb.", "bcwcb", ".bcb.", "..b.."]

## 직업 → 투사체 설정 (웹 KINDS)
const KINDS := {
	"archer": {"fl": 220.0, "arc": 0.14, "draw": "arrow", "hist": true, "impact": "archer", "burst": "archer", "up": 4.0},
	"mage": {"fl": 240.0, "draw": "orb", "trail": "mage", "impact": "mage", "burst": "mage", "up": 10.0},
	"priest": {"fl": 230.0, "draw": "holy", "trail": "holy", "impact": "priest", "burst": "priest", "up": 10.0},
	"summoner": {"fl": 250.0, "wave": 4.0, "draw": "rune", "trail": "rune", "impact": "summoner", "burst": "summoner", "up": 8.0},
	"summon_spirit": {"fl": 250.0, "wave": 4.0, "draw": "rune", "trail": "rune", "impact": "summoner", "burst": "summoner", "up": 8.0},
	"shaman": {"fl": 260.0, "arc": 0.08, "draw": "wisp", "impact": "shaman", "burst": "shaman", "up": 6.0},
}

const N := 320
var pX := PackedFloat32Array()
var pY := PackedFloat32Array()
var pVX := PackedFloat32Array()
var pVY := PackedFloat32Array()
var pLife := PackedFloat32Array()
var pMax := PackedFloat32Array()
var pG := PackedFloat32Array()
var pFloor := PackedFloat32Array()
var pPal := PackedInt32Array()
var pOn := PackedByteArray()
var _n_on := 0
var SHOTS: Array = []
var HITS: Array = []
var time_scale := 1.0
var _acc := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	z_index = 501
	_rng.seed = 4242
	PALS = [[COL.y0, COL.y1, COL.y2, COL.y3, COL.bd], [COL.sh0, COL.br, COL.br, COL.bd], [COL.m0, COL.m1, COL.m2, COL.m3, COL.m4, COL.m5],
		[COL.y1, COL.y2, COL.y3], [COL.w, COL.y0, COL.y1, COL.y2], [COL.v0, COL.v1, COL.v2, COL.v3, COL.v4], [COL.g0, COL.g1, COL.g2, COL.g3], [COL.pu, COL.pd, COL.pd]]
	pX.resize(N); pY.resize(N); pVX.resize(N); pVY.resize(N); pLife.resize(N); pMax.resize(N); pG.resize(N); pFloor.resize(N)
	pPal.resize(N)
	pOn.resize(N)
	for i in 16:
		var hist := PackedFloat32Array()
		hist.resize(12)
		SHOTS.append({"on": false, "kind": "", "fx": 0.0, "fy": 0.0, "tx": 0.0, "ty": 0.0, "x": 0.0, "y": 0.0, "ang": 0.0, "t": 0, "dur": 1, "arc": 0.0, "hist": hist, "hn": 0})
		HITS.append({"on": false, "kind": "", "x": 0.0, "y": 0.0, "t": 0})


static func handles(cls: String) -> bool:
	return KINDS.has(cls)


## 비행 시간 (초)
static func flight(cls: String) -> float:
	return float(KINDS[cls]["fl"]) / 1000.0 if KINDS.has(cls) else 0.0


static func up_of(cls: String) -> float:
	return float(KINDS[cls].get("up", 0.0)) if KINDS.has(cls) else 0.0


func busy() -> bool:
	if _n_on > 0:
		return true
	for s: Dictionary in SHOTS:
		if s["on"]:
			return true
	for h: Dictionary in HITS:
		if h["on"]:
			return true
	return false


## 투사체 발사 (전장 px 좌표, 비행 ms)
func shoot(kind: String, fx: float, fy: float, tx: float, ty: float, ms: float = 0.0) -> void:
	if not KINDS.has(kind):
		return
	var s: Variant = _free(SHOTS)
	if s == null:
		return
	var K: Dictionary = KINDS[kind]
	s["on"] = true
	s["kind"] = kind
	s["fx"] = fx / P
	s["x"] = fx / P
	s["fy"] = fy / P
	s["y"] = fy / P
	s["tx"] = tx / P
	s["ty"] = ty / P
	s["t"] = 0
	s["hn"] = 0
	s["ang"] = atan2(s["ty"] - s["fy"], s["tx"] - s["fx"])
	s["dur"] = maxi(4, roundi((ms if ms > 0.0 else float(K["fl"])) / (1000.0 / 60.0)))
	s["arc"] = minf(14.0, absf(s["tx"] - s["fx"]) * float(K["arc"]) + 3.0) if K.has("arc") else 0.0
	queue_redraw()


## 명중 임팩트 + 파편
func impact(kind: String, x: float, y: float) -> void:
	if not KINDS.has(kind):
		return
	var h: Variant = _free(HITS)
	if h == null:
		return
	h["on"] = true
	h["kind"] = kind
	h["x"] = x / P
	h["y"] = y / P
	h["t"] = 0
	_burst(str(KINDS[kind]["burst"]), x / P, y / P)
	queue_redraw()


func clear_all() -> void:
	for i in N:
		pOn[i] = 0
	_n_on = 0
	for s: Dictionary in SHOTS:
		s["on"] = false
	for h: Dictionary in HITS:
		h["on"] = false
	queue_redraw()


static func _free(arr: Array) -> Variant:
	for o: Dictionary in arr:
		if not o["on"]:
			return o
	return null


func _rnd(a: float, b: float) -> float:
	return a + _rng.randf() * (b - a)


func _emit(x: float, y: float, vx: float, vy: float, life: float, pal: int, g: float = 0.0, floor_y: float = 1e9) -> void:
	for i in N:
		if pOn[i] == 0:
			pOn[i] = 1
			_n_on += 1
			pX[i] = x
			pY[i] = y
			pVX[i] = vx
			pVY[i] = vy
			pLife[i] = life
			pMax[i] = life
			pPal[i] = pal
			pG[i] = g
			pFloor[i] = floor_y
			return


# ── 진행 (60Hz) ──

func _process(delta: float) -> void:
	if not busy():
		return
	_acc += minf(0.1, delta) * time_scale
	var step := 1.0 / 60.0
	while _acc >= step:
		_update()
		_acc -= step
	queue_redraw()


func _update() -> void:
	if _n_on > 0:
		for i in N:
			if pOn[i] == 0:
				continue
			pX[i] += pVX[i]
			pY[i] += pVY[i]
			pVY[i] += pG[i]
			pVX[i] *= 0.94
			pVY[i] *= 0.94
			if pY[i] > pFloor[i]:
				pY[i] = pFloor[i]
				pVY[i] *= -0.3
				pVX[i] *= 0.5
			pLife[i] -= 1.0
			if pLife[i] <= 0.0:
				pOn[i] = 0
				_n_on -= 1
	for s: Dictionary in SHOTS:
		if not s["on"]:
			continue
		var K: Dictionary = KINDS[s["kind"]]
		s["t"] = int(s["t"]) + 1
		var k := minf(1.0, float(s["t"]) / float(s["dur"]))
		var dx: float = s["tx"] - s["fx"]
		var dy: float = s["ty"] - s["fy"]
		var ln := maxf(0.0001, Vector2(dx, dy).length())
		var off := sin(k * PI * 2.0) * float(K["wave"]) * sin(k * PI) if K.has("wave") else 0.0
		var nx: float = s["x"]
		var ny: float = s["y"]
		s["x"] = s["fx"] + dx * k - dy / ln * off
		s["y"] = s["fy"] + dy * k + dx / ln * off - float(s["arc"]) * 4.0 * k * (1.0 - k)
		if int(s["t"]) > 1:
			s["ang"] = atan2(s["y"] - ny, s["x"] - nx)
		if K.get("hist", false):
			var hist: PackedFloat32Array = s["hist"]
			hist[(int(s["hn"]) % 6) * 2] = s["x"]
			hist[(int(s["hn"]) % 6) * 2 + 1] = s["y"]
			s["hist"] = hist
			s["hn"] = int(s["hn"]) + 1
		if K.has("trail"):
			_trail(str(K["trail"]), s)
		if int(s["t"]) >= int(s["dur"]):
			s["on"] = false
	for h: Dictionary in HITS:
		if h["on"]:
			h["t"] = int(h["t"]) + 1
			if int(h["t"]) > 40:
				h["on"] = false


func _trail(kind: String, s: Dictionary) -> void:
	var c := cos(float(s["ang"]))
	var t: int = s["t"]
	match kind:
		"mage":
			_emit(s["x"] - 3.0 * c, s["y"] + _rnd(-1.5, 1.5), -c * _rnd(0.4, 0.8), _rnd(-0.2, 0.2), _rnd(14, 22), 2)
		"holy":
			if t % 2 == 0:
				_emit(s["x"] + _rnd(-2, 2), s["y"] + _rnd(-1, 2), _rnd(-0.2, 0.2), _rnd(-0.7, -0.3), _rnd(16, 24), 4)
		"rune":
			_emit(s["x"] - 3.0 * c + _rnd(-1, 1), s["y"] + _rnd(-1.5, 1.5), _rnd(-0.3, 0.3), _rnd(-0.3, 0.3), _rnd(12, 20), 5)


func _burst(kind: String, x: float, y: float) -> void:
	match kind:
		"archer":
			for i in 7:
				_emit(x, y, _rnd(-1.2, 1.2), _rnd(-2.6, -0.4), _rnd(26, 38), 1 if i < 4 else 0, 0.14, y + 14.0)
		"mage":
			for i in 12:
				var a := float(i) / 12.0 * TAU
				_emit(x, y, cos(a) * 1.8, sin(a) * 1.8, _rnd(18, 28), 2)
		"priest":
			for i in 12:
				_emit(x + _rnd(-7, 7), y + _rnd(-2, 6), _rnd(-0.15, 0.15), _rnd(-1.1, -0.4), _rnd(26, 38), 4, -0.01)
		"summoner":
			for i in 4:
				for k in range(1, 3):
					var sp: Array = SPOKES[4 + i]
					_emit(x, y, float(sp[0]) * 1.4 * k, float(sp[1]) * 1.4 * k, _rnd(16, 24), 5)
		"shaman":
			for i in 9:
				_emit(x, y, _rnd(-1.6, 1.6), _rnd(-2.2, -0.6), _rnd(24, 34), 6, 0.13, y + 12.0)
			for i in 5:
				_emit(x + _rnd(-4, 4), y + _rnd(-2, 2), _rnd(-0.2, 0.2), _rnd(-0.5, -0.25), _rnd(30, 40), 7, -0.004)


# ── 그리기 (도트 = P×P 사각) ──

func _px(x: float, y: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x + 0.5) * P, floorf(y + 0.5) * P, P, P), c)


func _sprite(g: Array, x: float, y: float, cmap: Dictionary, ol: bool = false) -> void:
	var h := g.size()
	var w: int = str(g[0]).length()
	var ox := floorf(x - w / 2.0 + 0.5)
	var oy := floorf(y - h / 2.0 + 0.5)
	if ol:
		for j in h:
			var row: String = g[j]
			for i in w:
				if row[i] != ".":
					draw_rect(Rect2((ox + i - 1) * P, (oy + j) * P, 3.0 * P, P), COL.ol)
					draw_rect(Rect2((ox + i) * P, (oy + j - 1) * P, P, 3.0 * P), COL.ol)
	for j2 in h:
		var row2: String = g[j2]
		for i2 in w:
			var ch := row2[i2]
			if ch != ".":
				draw_rect(Rect2((ox + i2) * P, (oy + j2) * P, P, P), cmap[ch])


func _ring(cx: float, cy: float, r: int, c: Color, gap: bool = false) -> void:
	var x := r
	var y := 0
	var e := 1 - r
	var n := 0
	while x >= y:
		if not gap or (n % 2 == 0):
			_px(cx + x, cy + y, c); _px(cx + y, cy + x, c); _px(cx - y, cy + x, c); _px(cx - x, cy + y, c)
			_px(cx - x, cy - y, c); _px(cx - y, cy - x, c); _px(cx + y, cy - x, c); _px(cx + x, cy - y, c)
		n += 1
		y += 1
		if e < 0:
			e += 2 * y + 1
		else:
			x -= 1
			e += 2 * (y - x) + 1


func _diamond(cx: float, cy: float, r: int, c: Color) -> void:
	for i in r + 1:
		_px(cx + i, cy + r - i, c); _px(cx - i, cy + r - i, c); _px(cx + i, cy - r + i, c); _px(cx - i, cy - r + i, c)


func _filled(cx: float, cy: float, r: int, c: Color) -> void:
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			if absi(i) + absi(j) <= r + (1 if r > 1 else 0):
				_px(cx + i, cy + j, c)


func _hist_tail(s: Dictionary, pal: Array, back: float, ln: int) -> void:
	var tc := cos(float(s["ang"])) * back
	var ts := sin(float(s["ang"])) * back
	var hist: PackedFloat32Array = s["hist"]
	var hn: int = s["hn"]
	for i in range(1, mini(hn, ln)):
		var a := ((hn - 1 - i) % 6) * 2
		var b := ((hn - i) % 6) * 2
		var c: Color = pal[mini(pal.size() - 1, i >> 1)]
		for q in 5:
			_px(hist[a] + (hist[b] - hist[a]) * q / 4.0 - tc, hist[a + 1] + (hist[b + 1] - hist[a + 1]) * q / 4.0 - ts, c)


func _draw() -> void:
	for s: Dictionary in SHOTS:
		if s["on"]:
			_draw_shot(s)
	for h: Dictionary in HITS:
		if h["on"]:
			_draw_impact(str(KINDS[h["kind"]]["impact"]), h["x"], h["y"], int(h["t"]) >> 2)
	if _n_on > 0:
		for i in N:
			if pOn[i] != 0:
				var pal: Array = PALS[pPal[i]]
				var k := mini(pal.size() - 1, floori((1.0 - pLife[i] / pMax[i]) * pal.size()))
				_px(pX[i], pY[i], pal[k])


func _draw_shot(s: Dictionary) -> void:
	var t: int = s["t"]
	var x: float = s["x"]
	var y: float = s["y"]
	match str(KINDS[s["kind"]]["draw"]):
		"arrow":
			_hist_tail(s, PALS[3], 11.0, 6)
			var c := cos(float(s["ang"]))
			var sn := sin(float(s["ang"]))
			for i in 10:
				_px(x - c * i, y - sn * i, COL.sh0 if i % 3 != 0 else COL.sh1)
			_px(x + c, y + sn, COL.hd0)
			_px(x + c * 2, y + sn * 2, COL.hd0)
			_px(x - sn, y + c, COL.hd1)
			_px(x + sn, y - c, COL.hd1)
			for i2 in range(8, 11):
				var f: Color = COL.fl1 if i2 == 9 else COL.fl0
				_px(x - c * i2 - sn, y - sn * i2 + c, f)
				_px(x - c * i2 + sn, y - sn * i2 - c, f)
		"orb":
			_sprite(ORB if (t >> 2) % 2 == 1 else ORB2, x, y, {"w": COL.m0, "c": COL.m1, "b": COL.m3})
		"holy":
			_sprite(HOLY if (t >> 2) % 2 == 1 else HOLY2, x, y, {"W": COL.w, "w": COL.y0, "y": COL.y1}, true)
		"rune":
			_sprite(RUNE if (t >> 2) % 2 == 1 else RUNE2, x, y, {"w": COL.v0, "c": COL.v1, "b": COL.v2, "a": COL.v3}, true)
		"wisp":
			var c2 := cos(float(s["ang"]))
			var sn2 := sin(float(s["ang"]))
			var TAIL := [COL.g1, COL.g2, COL.g2, COL.g3, COL.pu]
			for i3 in range(1, 6):
				var d := 2.0 + i3 * 1.8
				var fl := sin(t * 0.7 + i3 * 0.9) * i3 * 0.45
				var px2 := x - c2 * d - sn2 * fl
				var py2 := y - sn2 * d + c2 * fl
				_px(px2, py2, TAIL[i3 - 1])
				if i3 <= 2:
					_px(px2 - sn2, py2 + c2, TAIL[i3 - 1])
					_px(px2 + sn2, py2 - c2, TAIL[i3])
			_sprite(WISP if (t >> 2) % 2 == 1 else WISP2, x, y, {"w": COL.g0, "c": COL.g1, "b": COL.g2}, true)


const MR := [2, 4, 7, 9, 11, 12, 13]


func _draw_impact(kind: String, cx: float, cy: float, f: int) -> void:
	match kind:
		"archer":
			if f == 0:
				for d in range(-2, 3):
					_px(cx + d, cy, COL.w)
					_px(cx, cy + d, COL.w)
				_px(cx + 1, cy + 1, COL.y0)
				_px(cx - 1, cy - 1, COL.y0)
			elif f == 1:
				_px(cx, cy, COL.w)
				for j in 8:
					var L := 4 if j < 4 else 3
					for r in range(2, L + 1):
						_px(cx + SPOKES[j][0] * r, cy + SPOKES[j][1] * r, COL.y1 if r == L else COL.y0)
			elif f == 2:
				for j in 8:
					var L2 := 7 if j < 4 else 5
					for r in range(4, L2 + 1):
						_px(cx + SPOKES[j][0] * r, cy + SPOKES[j][1] * r, COL.y2 if r == L2 else COL.y1)
			elif f == 3:
				for j in 8:
					var L3 := 8 if j < 4 else 6
					_px(cx + SPOKES[j][0] * L3, cy + SPOKES[j][1] * L3, COL.y2)
					_px(cx + SPOKES[j][0] * (L3 - 1), cy + SPOKES[j][1] * (L3 - 1), COL.y3)
			elif f == 4:
				for j in 4:
					_px(cx + SPOKES[j][0] * 9, cy + SPOKES[j][1] * 9, COL.y3)
		"mage":
			var MC := [COL.m0, COL.m1, COL.m2, COL.m3, COL.m4, COL.m5, COL.m5]
			if f == 0:
				_filled(cx, cy, 2, COL.m0)
			elif f < 7:
				_ring(cx, cy, MR[f], MC[f])
				if f < 3:
					_ring(cx, cy, MR[f] - 2, COL.m0)
				if f == 1:
					_px(cx, cy, COL.m0)
		"priest":
			if f == 0:
				_filled(cx, cy, 2, COL.w)
			elif f == 1:
				_arm(cx, cy, 6, COL.y0, 1)
				_px(cx, cy, COL.w)
				_diamond(cx, cy, 3, COL.y1)
			elif f == 2:
				_arm(cx, cy, 9, COL.y1, 4)
				_diamond(cx, cy, 5, COL.y0)
			elif f == 3:
				_arm(cx, cy, 10, COL.y2, 8)
				_diamond(cx, cy, 7, COL.y1)
			elif f == 4:
				_diamond(cx, cy, 8, COL.y2)
		"summoner":
			var R := [2, 4, 6, 8, 10, 11, 12]
			var C := [COL.v0, COL.v0, COL.v1, COL.v2, COL.v3, COL.v4, COL.v4]
			if f == 0:
				_filled(cx, cy, 2, COL.v0)
				_px(cx, cy, COL.w)
			elif f < 7:
				_diamond(cx, cy, R[f], C[f])
				if f < 3:
					_diamond(cx, cy, R[f] - 2, COL.w)
				if f == 2 or f == 3:
					_diamond(cx, cy, 1, COL.v1)
		"shaman":
			if f == 0:
				_filled(cx, cy, 2, COL.g1)
			elif f == 1:
				_filled(cx, cy, 2, COL.g2)
				_ring(cx, cy, 4, COL.g1)
				_px(cx, cy, COL.g0)
			elif f == 2:
				_ring(cx, cy, 6, COL.g2, true)
				_ring(cx, cy, 3, COL.g3, true)
			elif f == 3:
				_ring(cx, cy, 7, COL.g3, true)
			elif f == 4:
				_ring(cx, cy, 8, COL.pu, true)


func _arm(cx: float, cy: float, L: int, c: Color, from: int) -> void:
	for r in range(from, L + 1):
		_px(cx + r, cy, c)
		_px(cx - r, cy, c)
		_px(cx, cy + r, c)
		_px(cx, cy - r - 1, c)
