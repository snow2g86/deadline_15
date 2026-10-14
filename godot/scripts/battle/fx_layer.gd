extends Node2D
## 전장 위 연출 층 (z 500) — 떠오르는 글자(웹 Renderer.floatT), 입자(웹 VFX.spawn 일부), 적 행동 예고 화살표(rIntent),
##  공격 예상 피해(rPreview), 방향 고르기(showFacePicker) 그림. 3a 는 기본만 — 직업별 타격 효과·투사체는 3b.
##  입자는 배열 하나에 모아 _draw 한 번에 그림 (노드를 만들지 않음).

const Iso := preload("res://scripts/battle/iso.gd")
const FONT_PATH := "res://assets/fonts/NotoSansKR-VariableFont_wght.ttf"
const MAX_PARTICLES := 120

var iso: Iso
var speed := 1.0
var font: Font
var font_bold: Font

## 떠오르는 글자: {pos, text, color, size, t}
var _floats: Array = []
var _float_count: Dictionary = {}   # "x,y" → 겹친 수 (웹 _activeTexts)
## 입자: {p, v, life, decay, size, color, shape, gravity, rot, rot_spd}
var _parts: Array = []
## 적 → 노리는 클랜원 선 [[from, to], …], 노려지는 클랜원 머리 위 표시 {pos, n}
var intents: Array = []
var intent_badges: Array = []
## 공격 예상 [{pos, main, sub, kind}]
var previews: Array = []
## 방향 고르기 {center, opts:[{dx,dy,back,side,cur,best,pos,label}], tip, tip_pos} (없으면 빈 사전)
var picker: Dictionary = {}
var picker_hover := -1
var _t := 0.0
## 웹 rng 와 무관한 연출용 난수 (엔진 난수를 건드리지 않음)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 500
	_rng.seed = 12345
	var base: FontFile = load(FONT_PATH)
	font = base
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 900}
	font_bold = fv


func _process(delta: float) -> void:
	_t += delta
	var dt := delta * speed
	if not _floats.is_empty() or not _parts.is_empty() or not intents.is_empty() or not picker.is_empty() or not previews.is_empty():
		var i := 0
		while i < _floats.size():
			var f: Dictionary = _floats[i]
			f["t"] += dt
			if f["t"] >= 0.95:
				var k: String = f["key"]
				_float_count[k] = maxi(0, int(_float_count.get(k, 1)) - 1)
				_floats.remove_at(i)
			else:
				i += 1
		var steps := dt * 60.0   # 웹 입자는 프레임(60fps)마다 움직임
		var j := 0
		while j < _parts.size():
			var p: Dictionary = _parts[j]
			var v: Vector2 = p["v"]
			p["p"] += v * steps
			v.y += float(p["gravity"]) * steps
			p["v"] = v
			p["life"] -= float(p["decay"]) * steps
			p["rot"] += float(p["rot_spd"]) * steps
			if p["life"] <= 0.0:
				_parts.remove_at(j)
			else:
				j += 1
		queue_redraw()


func clear_all() -> void:
	_floats.clear()
	_float_count.clear()
	_parts.clear()
	queue_redraw()


# ── 떠오르는 글자 (웹 .float-text: damage #ff5252 17px · heal #5eff9a 15px · tactic #fbbf24 12px · debuff #c084fc) ──

func float_text(c: int, r: int, text: String, kind: String = "damage") -> void:
	if speed <= 0.0 or text == "":
		return
	var key := "%d,%d" % [c, r]
	var n := int(_float_count.get(key, 0)) + 1
	_float_count[key] = n
	var top := iso.tsy(c, r, iso.tile_z(c, r))
	var pos := Vector2(iso.tsx(c, r) + Iso.TW, top - Iso.UOY - 8.0 - (n - 1) * 18.0 + 14.0)
	var col := Color("ff5252")
	var size := 17
	match kind:
		"heal":
			col = Color("5eff9a")
			size = 15
		"tactic":
			col = Color("fbbf24")
			size = 12
		"debuff":
			col = Color("c084fc")
		"exp":
			col = Color("a78bfa")
		"info":
			col = Color("e2e8f0")
			size = 13
	_floats.append({"pos": pos, "text": text, "color": col, "size": size, "t": 0.0, "key": key})
	queue_redraw()


# ── 입자 (웹 VFX.spawn 의 옵션 이름 그대로) ──

func burst(at: Vector2, o: Dictionary) -> void:
	if speed <= 0.0:
		return
	var cnt := mini(int(o.get("count", 8)), MAX_PARTICLES - _parts.size())
	var cols: Array = o["colors"]
	for i in cnt:
		var spread := float(o.get("spread", 10.0))
		var sp := float(o.get("speed", 2.0))
		var vy: float = (float(o["vy"]) + (_rng.randf() - 0.5)) if o.has("vy") else (-_rng.randf() * sp)
		_parts.append({
			"p": at + Vector2((_rng.randf() - 0.5) * spread, (_rng.randf() - 0.5) * spread),
			"v": Vector2((_rng.randf() - 0.5) * sp, vy),
			"life": 1.0, "decay": float(o.get("decay", 0.015 + _rng.randf() * 0.02)),
			"size": float(o.get("size", 2.0 + _rng.randf() * 3.0)) * 1.2,
			"color": Color(str(cols[_rng.randi() % cols.size()])), "shape": str(o.get("shape", "circle")),
			"gravity": float(o.get("gravity", 0.0)), "rot": _rng.randf() * TAU, "rot_spd": (_rng.randf() - 0.5) * 0.2})
	queue_redraw()


# ── 그리기 ──

func _draw() -> void:
	_draw_intents()
	for p: Dictionary in _parts:
		_draw_part(p)
	for pv: Dictionary in previews:
		_draw_preview(pv)
	if not picker.is_empty():
		_draw_picker()
	for f: Dictionary in _floats:
		_draw_float(f)


## 웹 @keyframes isoFloat (.95s): 0% 투명·작게 → 15% 크게(1.35) → 30% 1 → 75% → 100% 위로 사라짐
func _draw_float(f: Dictionary) -> void:
	var k := float(f["t"]) / 0.95
	var keys := [[0.0, 4.0, 0.5, 0.0], [0.15, -10.0, 1.35, 1.0], [0.30, -14.0, 1.0, 1.0], [0.75, -26.0, 1.0, 1.0], [1.0, -38.0, 0.9, 0.0]]
	var y := 0.0
	var sc := 1.0
	var a := 1.0
	for i in keys.size() - 1:
		var k0: Array = keys[i]
		var k1: Array = keys[i + 1]
		if k <= float(k1[0]):
			var e := (k - float(k0[0])) / (float(k1[0]) - float(k0[0]))
			e = 1.0 - pow(1.0 - e, 2.0)
			y = lerpf(k0[1], k1[1], e)
			sc = lerpf(k0[2], k1[2], e)
			a = lerpf(k0[3], k1[3], e)
			break
	var size := int(round(float(f["size"]) * sc))
	if size < 4:
		return
	var text: String = f["text"]
	var w := font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos: Vector2 = f["pos"] + Vector2(-w / 2.0, y)
	draw_string_outline(font_bold, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.85 * a))
	draw_string(font_bold, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(f["color"], a))


func _draw_part(p: Dictionary) -> void:
	var life := float(p["life"])
	var col: Color = p["color"]
	col.a *= life
	var c: Vector2 = p["p"]
	var s := float(p["size"])
	match str(p["shape"]):
		"spark":
			draw_line(c, c - p["v"] * 4.0, col, 1.5, true)
			draw_circle(c, s * life * 0.6, col)
		"slash":
			var dv := Vector2(cos(p["rot"]), sin(p["rot"])) * s * 2.5
			draw_line(c - dv, c + dv, col, maxf(0.5, s * life * 0.8), true)
		"ring":
			draw_arc(c, s * (1.0 - life) * 3.5 + 2.0, 0, TAU, 20, col, 2.0 * life, true)
		"diamond":
			var q := s * life
			if q < 0.4:
				return
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -q), c + Vector2(q, 0), c + Vector2(0, q), c + Vector2(-q, 0)]), col)
		"star":
			var r := s * life
			if r < 0.6:
				return
			var pts := PackedVector2Array()
			for i in 5:
				pts.append(c + Vector2(cos(i * 1.256 - 0.785), sin(i * 1.256 - 0.785)) * r)
				pts.append(c + Vector2(cos(i * 1.256 + 0.628 - 0.785), sin(i * 1.256 + 0.628 - 0.785)) * r * 0.4)
			draw_colored_polygon(pts, col)
		_:
			draw_circle(c, maxf(0.3, s * life), col)


## 적 행동 예고: 점선 화살표 (웹 .intent-layer: #ff5a5a, 5px 4px 점선이 흐름) + 머리 위 배지
func _draw_intents() -> void:
	var col := Color(1.0, 90 / 255.0, 90 / 255.0, 0.6)
	var off := fmod(_t * 15.0, 9.0)
	for pr: Array in intents:
		var a: Vector2 = pr[0]
		var b: Vector2 = pr[1]
		var L := maxf(1.0, a.distance_to(b))
		var dir := (b - a) / L
		var e := b - dir * minf(18.0, L / 3.0)
		var tot := a.distance_to(e)
		var s := -off
		while s < tot:
			var s0 := maxf(0.0, s)
			var s1 := minf(tot, s + 5.0)
			if s1 > s0:
				draw_line(a + dir * s0, a + dir * s1, col, 1.6, true)
			s += 9.0
		var n := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([e + dir * 4.0, e - dir * 4.0 + n * 3.5, e - dir * 4.0 - n * 3.5]), Color(1.0, 90 / 255.0, 90 / 255.0, 0.9))
	for bd: Dictionary in intent_badges:
		var t := "◎" + (str(bd["n"]) if int(bd["n"]) > 1 else "")
		var p: Vector2 = bd["pos"]
		var w := font_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0
		var r := Rect2(p.x - w / 2.0, p.y - 8.0, w, 15.0)
		draw_rect(r, Color(127 / 255.0, 29 / 255.0, 29 / 255.0, 0.85))
		draw_rect(r, Color("f87171"), false, 1.0)
		draw_string(font_bold, Vector2(r.position.x + 4.0, r.position.y + 12.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fecaca"))


## 공격 예상 (웹 .dmg-prev: 대상 머리 위 '-피해', 처치면 해골 표시 대신 붉은 상자, 보조 줄)
func _draw_preview(pv: Dictionary) -> void:
	var main: String = pv["main"]
	var sub: String = pv["sub"]
	var p: Vector2 = pv["pos"]
	var mw := font_bold.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x if sub != "" else 0.0
	var w := maxf(mw, sw) + 10.0
	var h := 20.0 + (13.0 if sub != "" else 0.0)
	var r := Rect2(p.x - w / 2.0, p.y - h, w, h)
	var kind: String = pv["kind"]
	var bg := Color(0.05, 0.07, 0.12, 0.85)
	var bc := Color("ef4444")
	if kind == "kill":
		bg = Color(0.45, 0.05, 0.05, 0.9)
		bc = Color("fca5a5")
	elif kind == "block":
		bc = Color("60a5fa")
	draw_rect(r, bg)
	draw_rect(r, bc, false, 1.0)
	draw_string(font_bold, Vector2(p.x - mw / 2.0, r.position.y + 15.0), main, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffffff"))
	if sub != "":
		draw_string(font, Vector2(p.x - sw / 2.0, r.position.y + 29.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fde68a"))


## 방향 고르기 (웹 #face-picker: 유닛 둘레 네 칸에 64x40 타원 단추 + 바닥 삼각형 + 아래 글)
func _draw_picker() -> void:
	var opts: Array = picker["opts"]
	for i in opts.size():
		var o: Dictionary = opts[i]
		var c: Vector2 = o["pos"]
		var hov := i == picker_hover
		var bg := Color(15 / 255.0, 23 / 255.0, 42 / 255.0, 0.55)
		if o["cur"]:
			bg = Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.35)
		if hov:
			bg = Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.45)
		var sc := 1.08 if hov else 1.0
		var pts := PackedVector2Array()
		for k in 24:
			var a := TAU * k / 24.0
			pts.append(c + Vector2(cos(a) * 32.0, sin(a) * 20.0) * sc)
		draw_colored_polygon(pts, bg)
		pts.append(pts[0])
		draw_polyline(pts, Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.95) if o["best"] else Color(148 / 255.0, 163 / 255.0, 184 / 255.0, 0.5), 2.0, true)
		var tri := iso.face_tri(float(o["dx"]), float(o["dy"]), c, 0.19, 0.38, 0.15)
		draw_colored_polygon(tri, Color("facc15") if o["best"] else Color("93c5fd"))
		var lab: String = o["label"]
		var lw := font_bold.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var lr := Rect2(c.x - lw / 2.0 - 5.0, c.y + 22.0, lw + 10.0, 14.0)
		draw_rect(lr, Color(0, 0, 0, 0.7))
		draw_string(font_bold, Vector2(lr.position.x + 5.0, lr.position.y + 11.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	var tip: String = picker.get("tip", "")
	if tip != "":
		var tp: Vector2 = picker["tip_pos"]
		var tw := font_bold.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var tr := Rect2(tp.x - tw / 2.0 - 8.0, tp.y - 16.0, tw + 16.0, 20.0)
		draw_rect(tr, Color(0, 0, 0, 0.75))
		draw_string(font_bold, Vector2(tr.position.x + 8.0, tr.position.y + 14.0), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fde68a"))


## 방향 단추 찾기 (화면 좌표 → 단추 번호, 없으면 -1)
func picker_hit(p: Vector2) -> int:
	if picker.is_empty():
		return -1
	var opts: Array = picker["opts"]
	for i in opts.size():
		var c: Vector2 = opts[i]["pos"]
		var q := (p - c) / Vector2(32.0, 20.0)
		if q.length() <= 1.0:
			return i
	return -1
