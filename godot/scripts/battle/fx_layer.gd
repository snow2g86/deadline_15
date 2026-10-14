extends Node2D
## 전장 위 연출 층 (z 500) — 웹 render.js floatT(떠오르는 글자) · vfx.js spawn/_loop(입자 모양 전부) · _vfxHit(직업별 타격 효과) ·
##  vfxHeal · vfxDeath · vfxBuff · vfxSiege · motion.js _fx(무기 궤적 한 장) · rIntent(행동 예고 화살표·🎯 배지) · rPreview(공격 예상 상자) ·
##  showFacePicker(방향 고르기). 입자는 배열 하나에 모아 _draw 한 번에 그림 (노드를 만들지 않음). 픽셀 투사체는 pixel_fx.gd.
##  떠오르는 글자 속 이모지는 그림 아이콘으로 (웹 EmojiIcons 자동 교체와 같음)

const Iso := preload("res://scripts/battle/iso.gd")
const Kit := preload("res://scripts/battle/ui_kit.gd")
## 웹 MAX_PARTICLES (spawn 으로 만드는 입자 상한 — _fx 궤적은 따로)
const MAX_PARTICLES := 80

var iso: Iso
var icons: Object
var speed := 1.0
var font: Font
var font_bold: Font
var font_tactic: Font

## 떠오르는 글자: {pos, segs([글|Texture2D]), w, color, size, t, key}
var _floats: Array = []
var _float_count: Dictionary = {}   # "x,y" → 겹친 수 (웹 _activeTexts)
## 입자: {p, v, life, decay, size, color, shape, gravity, rot, rot_spd, counted}
var _parts: Array = []
var _n_counted := 0
## 지연 입자 (암살자·격투가 연타 등 setTimeout) [{t, fn}]
var _later: Array = []
## 적 → 노리는 클랜원 선 [[from, to], …], 노려지는 클랜원 머리 위 표시 {pos, n}
var intents: Array = []
var intent_badges: Array = []
## 공격 예상 [{pos, main, sub, kind(dmg|kill|block), icon}]
var previews: Array = []
var _prev_t := 0.0
## 방향 고르기 {center, opts:[{dx,dy,back,side,cur,best,pos,label}], tip, tip_pos} (없으면 빈 사전)
var picker: Dictionary = {}
var picker_hover := -1
var _t := 0.0
## 웹 rng 와 무관한 연출용 난수 (엔진 난수를 건드리지 않음)
var _rng := RandomNumberGenerator.new()
## 매 프레임 새로 만들지 않게 한 번 만든 상자 모양
var _badge_sb := StyleBoxFlat.new()
var _prev_sb := StyleBoxFlat.new()


func _ready() -> void:
	z_index = 500
	_rng.seed = 12345
	font = Kit.font()
	font_bold = Kit.bold(900)
	font_tactic = Kit.bold(800)
	_badge_sb.bg_color = Color(127 / 255.0, 29 / 255.0, 29 / 255.0, 0.85)
	_badge_sb.border_color = Color("f87171")
	_badge_sb.set_border_width_all(1)
	_badge_sb.set_corner_radius_all(9)
	_prev_sb.set_corner_radius_all(6)
	_prev_sb.set_border_width_all(1)


func _process(delta: float) -> void:
	_t += delta
	var dt := delta * speed
	_prev_t += delta
	if not _later.is_empty():
		var j0 := 0
		while j0 < _later.size():
			var l: Array = _later[j0]
			l[0] -= dt
			if l[0] <= 0.0:
				_later.remove_at(j0)
				(l[1] as Callable).call()
			else:
				j0 += 1
	if not _floats.is_empty() or not _parts.is_empty() or not intents.is_empty() or not intent_badges.is_empty() or not picker.is_empty() or not previews.is_empty():
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
				if p["counted"]:
					_n_counted -= 1
				_parts.remove_at(j)
			else:
				j += 1
		queue_redraw()


func clear_all() -> void:
	_floats.clear()
	_float_count.clear()
	_parts.clear()
	_later.clear()
	_n_counted = 0
	queue_redraw()


func _after(secs: float, fn: Callable) -> void:
	if secs <= 0.0:
		fn.call()
	else:
		_later.append([secs, fn])


# ── 떠오르는 글자 (웹 .float-text: damage #ff5252 19px · heal #5eff9a 15px · tactic #fbbf24 12px · debuff #c084fc · exp #a78bfa) ──

func float_text(c: int, r: int, text: String, kind: String = "damage") -> void:
	if speed <= 0.0 or text == "":
		return
	var key := "%d,%d" % [c, r]
	var n := int(_float_count.get(key, 0)) + 1
	_float_count[key] = n
	var top := iso.tsy(c, r, iso.tile_z(c, r))
	var pos := Vector2(iso.tsx(c, r) + Iso.TW, top - Iso.UOY - 8.0 - (n - 1) * 18.0 + 14.0)
	var col := Color("ff5252")
	var size := 19
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
		"crit":
			col = Color("fde047")
			size = 22
	var segs: Array = icons.call("split", text) if icons != null else [text]
	_floats.append({"pos": pos, "segs": segs, "color": col, "size": size, "t": 0.0, "key": key, "tactic": kind == "tactic"})
	queue_redraw()


# ── 입자 (웹 VFX.spawn 의 옵션 이름 그대로) ──

func burst(at: Vector2, o: Dictionary) -> void:
	if speed <= 0.0:
		return
	var cnt := mini(int(o.get("count", 8)), MAX_PARTICLES - _n_counted)
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
			"gravity": float(o.get("gravity", 0.0)), "rot": _rng.randf() * TAU, "rot_spd": (_rng.randf() - 0.5) * 0.2, "counted": true})
		_n_counted += 1
	queue_redraw()


## 궤적 한 장 (웹 motion.js VFX._fx: 퍼짐 없음, 상한 제외)
func trail(at: Vector2, shape: String, color: Color, size: float, rot: float, decay: float = 0.08, rot_spd: float = 0.0) -> void:
	if speed <= 0.0:
		return
	_parts.append({"p": at, "v": Vector2.ZERO, "life": 1.0, "decay": decay, "size": size, "color": color, "shape": shape,
		"gravity": 0.0, "rot": rot, "rot_spd": rot_spd, "counted": false})
	queue_redraw()


# ── 직업별 효과 (웹 vfx.js) ──

## 근접·기본 타격 (웹 _vfxHit — 원거리 직업은 pixel_fx 임팩트가 대신). a, t = 몸통 위치
func hit_fx(cls: String, a: Vector2, t: Vector2) -> void:
	if speed <= 0.0:
		return
	match cls:
		"warrior":
			burst(t, {"count": 10, "colors": ["#fff", "#aaddff", "#88bbff"], "shape": "slash", "speed": 3, "spread": 10, "decay": 0.04, "size": 4})
			burst(t, {"count": 6, "colors": ["#ffffff", "#aaddff"], "shape": "spark", "speed": 4, "spread": 8, "decay": 0.03, "size": 2.5})
		"knight":
			burst(t, {"count": 12, "colors": ["#ffcc44", "#ff8800", "#ffffff"], "shape": "circle", "speed": 2.5, "spread": 8, "decay": 0.025, "size": 4, "gravity": 0.08})
			burst(t, {"count": 4, "colors": ["#fff", "#ffcc44"], "shape": "spark", "speed": 3, "spread": 6, "decay": 0.035, "size": 2})
		"assassin":
			for i in 3:
				_after(i * 0.05, func() -> void:
					burst(t + Vector2((_rng.randf() - 0.5) * 10.0, (_rng.randf() - 0.5) * 10.0), {"count": 5, "colors": ["#cc44ff", "#ff44cc", "#ffffff"], "shape": "slash", "speed": 4, "spread": 8, "decay": 0.045, "size": 3.5}))
			burst(t, {"count": 6, "colors": ["#cc44ff66", "#8844ff66"], "shape": "diamond", "speed": 2, "spread": 12, "decay": 0.03, "size": 4})
		"novice":
			burst(t, {"count": 6, "colors": ["#cccccc", "#ffffff", "#aaaaaa"], "shape": "spark", "speed": 2.5, "spread": 8, "decay": 0.04, "size": 2.5})
		"brawler":
			for i2 in 3:
				_after(i2 * 0.04, func() -> void:
					burst(t + Vector2((_rng.randf() - 0.5) * 10.0, (_rng.randf() - 0.5) * 10.0), {"count": 5, "colors": ["#f97316", "#fbbf24", "#ffffff"], "shape": "slash", "speed": 4, "spread": 6, "decay": 0.045, "size": 3.5}))
			burst(t, {"count": 4, "colors": ["#f97316", "#ff4400"], "shape": "spark", "speed": 4, "spread": 6, "decay": 0.035, "size": 2.5})
		"lancer":
			var d := (t - a)
			var n := d / maxf(1.0, d.length())
			for i3 in 4:
				var p := t - n * i3 * 6.0
				_after(i3 * 0.025, func() -> void:
					burst(p, {"count": 3, "colors": ["#60a5fa", "#3b82f6", "#ffffff"], "shape": "spark", "speed": 5, "spread": 4, "decay": 0.045, "size": 2.5}))
			burst(t, {"count": 8, "colors": ["#60a5fa", "#93c5fd", "#ffffff"], "shape": "spark", "speed": 4, "spread": 8, "decay": 0.03, "size": 3})
		"sapper":
			burst(t, {"count": 10, "colors": ["#f97316", "#ff6600", "#ffcc00"], "shape": "spark", "speed": 3, "spread": 10, "decay": 0.035, "size": 3})
			burst(t, {"count": 4, "colors": ["#aaaaaa", "#888888"], "shape": "circle", "speed": 1.5, "spread": 6, "decay": 0.025, "size": 2.5, "gravity": 0.08})
		_:
			# 소환수 골렘 등 (웹은 효과 없음 — 작은 불꽃만)
			burst(t, {"count": 8, "colors": ["#ffffff", "#ffcc44", "#ff8800"], "shape": "spark", "speed": 3, "spread": 8, "decay": 0.035, "size": 2.5})


## 무기 궤적 (웹 motion.js _atkTrail — 스프라이트 시트가 없는 유닛(소환수)만): m = ATK_MOTIONS[cls], hit_s = 타격까지 (재생 속도 1 기준 초)
func atk_trail(m: Dictionary, a: Vector2, t: Vector2, hit_s: float) -> void:
	if speed <= 0.0:
		return
	var dir := (t - a).normalized() if t != a else Vector2.RIGHT
	var face := -1.0 if dir.x < 0.0 else 1.0
	var ang := dir.angle()
	var f := a + dir * 16.0
	var col := Color(str(m.get("color", "#ffffff")))
	var glow := Color(str(m.get("glow", "#ffffff")))
	var dur := float(m.get("dur", 400)) / 1000.0
	var sp := 1.0   # _after 는 이미 재생 속도로 흐름
	match str(m.get("trail", "")):
		"arc":
			_after(maxf(0.0, hit_s - 0.04 / sp), func() -> void:
				trail(f, "arcSlash", col, 18, ang - 0.9 * face, 0.09, 0.16 * face)
				trail(f, "arcSlash", Color.WHITE, 14, ang - 0.9 * face, 0.12, 0.16 * face))
		"bash":
			_after(hit_s, func() -> void: trail(f, "ring", col, 6, 0.0, 0.07))
		"dash":
			_after(maxf(0.0, hit_s - 0.06 / sp), func() -> void: trail(a + dir * 6.0, "streak", col, 30, ang, 0.1))
			_after(hit_s + 0.04 / sp, func() -> void: trail(f, "arcSlash", col, 14, ang + 0.9 * face, 0.12, -0.2 * face))
		"jab":
			for i in 3:
				var at: float = dur * [0.12, 0.38, 0.66][i] / sp
				_after(at, func() -> void: trail(f, "streak", col, 12 + i * 4, ang, 0.14))
		"thrust":
			_after(maxf(0.0, hit_s - 0.03 / sp), func() -> void:
				trail(f + dir * 18.0, "streak", col, 34, ang, 0.09)
				trail(f + dir * 18.0, "streak", Color.WHITE, 22, ang, 0.13))
		"lob":
			_after(maxf(0.0, hit_s - 0.06 / sp), func() -> void: projectile(f + Vector2(0, -6), t, ["#ffcc00", "#f97316"], 6))
		"muzzle":
			_after(dur * 0.38 / sp, func() -> void: trail(f, "implode", col, 10, 0.0, 0.1))
		"bolt":
			_after(0.08 / sp, func() -> void: trail(a + Vector2(0, -4), "implode", glow, 16, 0.0, 0.05))
			_after(dur * 0.4 / sp, func() -> void: projectile(f + Vector2(0, -4), t, [m.get("glow", "#fff"), m.get("color", "#fff"), "#ffffff"], 4))


## 직선 투사체 궤적 (점점이 이어지는 불꽃 — 웹 _projectile)
func projectile(a: Vector2, t: Vector2, colors: Array, steps: int) -> void:
	for i in steps + 1:
		var k := float(i) / float(steps)
		_after(i * 0.018, func() -> void:
			burst(a.lerp(t, k), {"count": 2, "colors": colors, "shape": "spark", "speed": 1.2, "spread": 3, "decay": 0.07, "size": 2.4}))


func heal_fx(at: Vector2) -> void:
	burst(at, {"count": 18, "colors": ["#44ff88", "#88ffaa", "#aaffcc", "#ffffff"], "shape": "circle", "speed": 1.5, "spread": 14, "decay": 0.018, "size": 3, "vy": -1.5, "gravity": -0.02})
	burst(at, {"count": 5, "colors": ["#44ff8844"], "shape": "ring", "speed": 0, "spread": 3, "decay": 0.015, "size": 14})
	burst(at, {"count": 8, "colors": ["#aaffcc", "#ffffff"], "shape": "star", "speed": 1, "spread": 10, "decay": 0.02, "size": 2.5, "vy": -2, "gravity": -0.01})


func death_fx(at: Vector2, ally: bool) -> void:
	var bc: Array = (["#3b82f6", "#60a5fa", "#93c5fd", "#bfdbfe"] if ally else ["#ef4444", "#f87171", "#fca5a5", "#fecaca"]) + ["#ffffff88"]
	burst(at, {"count": 25, "colors": bc, "shape": "diamond", "speed": 1.5, "spread": 16, "decay": 0.012, "size": 3, "gravity": 0.03, "vy": -0.5})
	burst(at, {"count": 10, "colors": ["#ffffff44"], "shape": "circle", "speed": 0.8, "spread": 12, "decay": 0.01, "size": 2, "vy": -1, "gravity": -0.01})


func buff_fx(at: Vector2) -> void:
	burst(at, {"count": 8, "colors": ["#22c55e", "#4ade80", "#ffffff"], "shape": "star", "speed": 1.5, "spread": 12, "decay": 0.025, "size": 2.5, "vy": -1})


func siege_fx(item: String, at: Vector2) -> void:
	match item:
		"siege_ladder":
			burst(at, {"count": 10, "colors": ["#d4a574", "#b08050", "#fff8"], "shape": "spark", "speed": 2, "spread": 10, "decay": 0.025, "size": 2.5, "vy": -2})
		"siege_bomb":
			burst(at, {"count": 30, "colors": ["#f84", "#f60", "#ff4", "#fff"], "shape": "spark", "speed": 4, "spread": 16, "decay": 0.02, "size": 3.5})
			burst(at, {"count": 8, "colors": ["#f8440088"], "shape": "ring", "speed": 0, "spread": 4, "decay": 0.012, "size": 18})
			burst(at, {"count": 12, "colors": ["#888", "#666", "#aaa"], "shape": "circle", "speed": 2, "spread": 14, "decay": 0.015, "size": 3, "vy": -1.5, "gravity": 0.06})
		"siege_bridge":
			burst(at, {"count": 12, "colors": ["#8B4513", "#A0522D", "#D2B48C"], "shape": "circle", "speed": 1.5, "spread": 12, "decay": 0.02, "size": 2.5, "vy": -1})


## 소환수 등장 (Godot — 웹은 spawnPop 만): 보랏빛 고리 + 반짝임
func summon_fx(at: Vector2) -> void:
	burst(at, {"count": 4, "colors": ["#a855f788", "#c084fc88"], "shape": "ring", "speed": 0, "spread": 3, "decay": 0.03, "size": 12})
	burst(at, {"count": 12, "colors": ["#d8b4fe", "#a855f7", "#ffffff"], "shape": "star", "speed": 1.6, "spread": 14, "decay": 0.03, "size": 2.6, "vy": -1.2})


## 공격 예상 상자를 다시 띄울 때 (웹 dpIn .15s)
func set_previews(list: Array) -> void:
	previews = list
	_prev_t = 0.0
	queue_redraw()


# ── 그리기 ──

func _draw() -> void:
	_draw_intents()
	for p: Dictionary in _parts:
		_draw_part(p)
	draw_set_transform(Vector2.ZERO)
	for pv: Dictionary in previews:
		_draw_preview(pv)
	if not picker.is_empty():
		_draw_picker()
	for f: Dictionary in _floats:
		_draw_float(f)


## 웹 @keyframes isoFloat (.95s): 0% 투명·작게 → 15% 크게(1.35) → 30% 1 → 75% → 100% 위로 사라짐
const FLOAT_KEYS := [[0.0, 4.0, 0.5, 0.0], [0.15, -10.0, 1.35, 1.0], [0.30, -14.0, 1.0, 1.0], [0.75, -26.0, 1.0, 1.0], [1.0, -38.0, 0.9, 0.0]]


func _draw_float(f: Dictionary) -> void:
	var k := float(f["t"]) / 0.95
	var y := 0.0
	var sc := 1.0
	var a := 1.0
	for i in FLOAT_KEYS.size() - 1:
		var k0: Array = FLOAT_KEYS[i]
		var k1: Array = FLOAT_KEYS[i + 1]
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
	var fnt: Font = font_tactic if f["tactic"] else font_bold
	var segs: Array = f["segs"]
	var w := 0.0
	for s: Variant in segs:
		w += fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if typeof(s) == TYPE_STRING else (size * 1.2 if s != null else 0.0)
	var x: float = f["pos"].x - w / 2.0
	var by: float = f["pos"].y + y
	for s2: Variant in segs:
		if typeof(s2) == TYPE_STRING:
			var p := Vector2(x, by)
			draw_string_outline(fnt, p, s2, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.85 * a))
			draw_string(fnt, p, s2, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(f["color"], a))
			x += fnt.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		elif s2 != null:
			var isz := size * 1.2
			draw_texture_rect(s2, Rect2(x, by - isz * 0.85, isz, isz), false, Color(1, 1, 1, a))
			x += isz


func _draw_part(p: Dictionary) -> void:
	var life := float(p["life"])
	var col: Color = p["color"]
	col.a *= life
	var s := float(p["size"])
	draw_set_transform(p["p"], float(p["rot"]))
	match str(p["shape"]):
		"spark":
			draw_line(Vector2.ZERO, -(p["v"] as Vector2) * 4.0, col, 1.5, true)
			draw_circle(Vector2.ZERO, maxf(0.2, s * life * 0.6), col)
		"slash":
			draw_line(Vector2(-s * 2.5, s * 2.5), Vector2(s * 2.5, -s * 2.5), col, maxf(0.5, s * life * 0.8), true)
		"ring":
			draw_arc(Vector2.ZERO, s * (1.0 - life) * 3.5 + 2.0, 0, TAU, 20, col, maxf(0.3, 2.0 * life), true)
		"diamond":
			var q := s * life
			if q >= 0.4:
				draw_colored_polygon(PackedVector2Array([Vector2(0, -q), Vector2(q, 0), Vector2(0, q), Vector2(-q, 0)]), col)
		"star":
			var r := s * life
			if r >= 0.6:
				var pts := PackedVector2Array()
				for i in 5:
					pts.append(Vector2(cos(i * 1.256 - 0.785), sin(i * 1.256 - 0.785)) * r)
					pts.append(Vector2(cos(i * 1.256 + 0.628 - 0.785), sin(i * 1.256 + 0.628 - 0.785)) * r * 0.4)
				draw_colored_polygon(pts, col)
		"arcSlash":
			# 초승달 무기 궤적 (rot = 시작 각도, rot_spd 로 휘두름)
			draw_arc(Vector2.ZERO, s, 0.0, 1.8, 14, col, maxf(0.3, s * 0.32 * life), true)
			draw_arc(Vector2.ZERO, s * 0.8, 0.2, 1.6, 12, col, maxf(0.3, s * 0.12 * life), true)
		"streak":
			draw_polyline_colors(PackedVector2Array([Vector2(-s, 0), Vector2.ZERO]), PackedColorArray([Color(1, 1, 1, 0), col]), 3.0 * life + 1.0, true)
		"implode":
			draw_arc(Vector2.ZERO, s * life + 1.0, 0, TAU, 20, col, 2.5 * (1.0 - life) + 0.5, true)
		"cross":
			var s2 := s * 2.0
			draw_line(Vector2(-s2, 0), Vector2(s2, 0), col, maxf(0.3, s * life * 0.5), true)
			draw_line(Vector2(0, -s2), Vector2(0, s2), col, maxf(0.3, s * life * 0.5), true)
		"arrow":
			draw_polyline(PackedVector2Array([Vector2(0, s * 3.0), Vector2(0, -s * 3.0)]), col, 2.0 * life, true)
			draw_polyline(PackedVector2Array([Vector2(-s, -s), Vector2(0, -s * 3.0), Vector2(s, -s)]), col, 2.0 * life, true)
		_:
			draw_circle(Vector2.ZERO, maxf(0.3, s * life), col)


## 적 행동 예고: 점선 화살표 (웹 .intent-layer: #ff5a5a, 5px 4px 점선이 흐름) + 머리 위 🎯 배지 (웹 .u-intent)
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
	var tgt: Texture2D = icons.call("emoji", "🎯") if icons != null else null
	var pulse := 0.5 - 0.5 * cos(_t / 1.4 * TAU)
	for bd: Dictionary in intent_badges:
		var cnt := int(bd["n"])
		var t := str(cnt) if cnt > 1 else ""
		var p: Vector2 = bd["pos"]
		var tw := font_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x if t != "" else 0.0
		var w := 14.0 + tw + 8.0
		var r := Rect2(p.x - w / 2.0, p.y - 9.0, w, 17.0)
		var sb := _badge_sb
		sb.shadow_color = Color(248 / 255.0, 113 / 255.0, 113 / 255.0, 0.35 + 0.4 * pulse)
		sb.shadow_size = int(3 + 4 * pulse)
		draw_style_box(sb, r)
		if tgt != null:
			draw_texture_rect(tgt, Rect2(r.position.x + 3.0, r.position.y + 1.5, 14, 14), false)
		if t != "":
			draw_string(font_bold, Vector2(r.position.x + 18.0, r.position.y + 13.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fecaca"))


## 공격 예상 (웹 .dmg-prev: 대상 머리 위 '-피해', 처치면 💀·금빛, 차단이면 🛡️·파랑, 아래 보조 줄)
func _draw_preview(pv: Dictionary) -> void:
	var main: String = pv["main"]
	var sub: String = pv["sub"]
	var kind: String = pv["kind"]
	var icon: Variant = pv.get("icon")
	var k := clampf(_prev_t / 0.15, 0.0, 1.0)
	var p: Vector2 = pv["pos"] + Vector2(0, 3.0 * (1.0 - k))
	var ms := 14
	var mw := font_bold.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, ms).x + (16.0 if icon != null else 0.0)
	var sw := font_tactic.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x if sub != "" else 0.0
	var w := maxf(mw, sw) + 14.0
	var h := 21.0 + (12.0 if sub != "" else 0.0)
	var r := Rect2(p.x - w / 2.0, p.y - h, w, h)
	var sb := _prev_sb
	sb.bg_color = Color(10 / 255.0, 14 / 255.0, 26 / 255.0, 0.9 * k)
	sb.border_color = Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.6 * k)
	sb.shadow_color = Color(0, 0, 0, 0.5 * k)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	var mc := Color("ff6b6b")
	if kind == "kill":
		sb.border_color = Color(250 / 255.0, 204 / 255.0, 21 / 255.0, k)
		sb.shadow_color = Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.45 * k)
		sb.shadow_offset = Vector2.ZERO
		mc = Color("facc15")
	elif kind == "block":
		sb.border_color = Color(96 / 255.0, 165 / 255.0, 250 / 255.0, k)
		mc = Color("93c5fd")
	draw_style_box(sb, r)
	var x := p.x - mw / 2.0
	if icon != null:
		draw_texture_rect(icon, Rect2(x, r.position.y + 3.0, 14, 14), false, Color(1, 1, 1, k))
		x += 16.0
	draw_string(font_bold, Vector2(x, r.position.y + 16.0), main, HORIZONTAL_ALIGNMENT_LEFT, -1, ms, Color(mc, k))
	if sub != "":
		draw_string(font_tactic, Vector2(p.x - sw / 2.0, r.position.y + 29.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(203 / 255.0, 213 / 255.0, 225 / 255.0, k))


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
