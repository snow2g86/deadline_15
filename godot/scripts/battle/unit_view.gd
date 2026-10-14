extends Node2D
## 유닛 하나의 그림 — 웹 render.js rUnits 의 .unit-sprite + rig.js 스프라이트 시트 + vfx.js 방향 삼각형
##  원점 = 발 위치 (타일 윗면 가운데에서 3px 위). z_index = Grid.depth(x, y, 2) (도착 칸 기준, 웹과 같음)
##  화면 상태(d)는 엔진 사건의 사본으로만 바뀜 — 엔진 상태를 직접 읽지 않음 (연출이 엔진보다 늦게 재생되므로)
##  구성: 자기 _draw (그림자·발밑 방향 삼각형) → Body (시트 한 칸, 셰이더) → Bars (HP·자원 막대)

const Iso := preload("res://scripts/battle/iso.gd")
const SpriteDB := preload("res://scripts/battle/sprite_db.gd")
const UnitShader := preload("res://scripts/battle/shaders/unit.gdshader")

const ALLY_FACE := Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.95)
const ENEMY_FACE := Color(248 / 255.0, 113 / 255.0, 113 / 255.0, 0.95)
const HP_ALLY := Color("22c55e")
const HP_ENEMY := Color("ef4444")
## 발밑 방향 삼각형 (웹 VFX.FACE_TIP·FACE_LEN·FACE_HALF — 칸 단위)
const FACE_TIP := 0.5
const FACE_LEN := 0.2
const FACE_HALF := 0.12

var id: int = 0
var d: Dictionary = {}          # 화면 상태: team, cls, gender, x, y, hp, mhp, res, maxRes, resType, face[gdx,gdy], stealthed, ha, stunned …
var iso: Iso
var sdb: SpriteDB

var body: Body
var bars: Bars
var _mat: ShaderMaterial

var loop_kind := "idle"
var _loop_t := 0.0
var _once_kind := ""
var _once_t := 0.0
var _flip := false
var hp_disp := 0.0
var res_disp := 0.0

var moving := false
var face_hidden := false       # 방향 고르는 중
var cur_turn := false
var selected := false
var in_fog := false
var dying := false
var _die_t := 0.0
var _spawn_t := 9.0
var _shake_t := 9.0
var _move_tw: Tween
var _move_token := 0
var _t := 0.0
## 연출 속도 배율 (0 = 즉시)
var speed := 1.0


## 시트 한 칸 그리기 (여백을 두고 그려 셰이더 빛·그림자가 칸 밖으로 번질 자리를 남김)
class Body extends Node2D:
	var tex: Texture2D
	var src := Rect2()
	var dst := Rect2()

	func _draw() -> void:
		if tex != null:
			draw_texture_rect_region(tex, dst, src)


class Bars extends Node2D:
	var u: Node   # unit_view

	func _draw() -> void:
		u._draw_bars(self)


func setup(p_iso: Iso, p_sdb: SpriteDB, data: Dictionary, p_speed: float) -> void:
	iso = p_iso
	sdb = p_sdb
	speed = p_speed
	d = data.duplicate(true)
	id = int(d["id"])
	hp_disp = float(d["hp"])
	res_disp = float(d.get("res", 0.0))
	# 유닛마다 반복 동작 시작 위치를 다르게 (웹: delay -Math.random()*dur — 여기선 id 로 고정, 엔진 난수와 무관)
	_loop_t = float(hash(id) % 1000) / 1000.0 * 2.4
	body = Body.new()
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = ShaderMaterial.new()
	_mat.shader = UnitShader
	body.material = _mat
	add_child(body)
	bars = Bars.new()
	bars.u = self
	add_child(bars)
	place_now()
	_apply_face()
	_refresh_frame()


## 칸 위치로 바로
func place_now() -> void:
	position = iso.foot(int(d["x"]), int(d["y"]))
	z_index = iso.depth(int(d["x"]), int(d["y"]), 2)


func spawn_anim() -> void:
	_spawn_t = 0.0 if speed > 0.0 else 9.0


# ── 상태 반영 ──

## 사건 사본(unit_view)으로 수치 갱신 — 위치는 이동 연출이 따로 맡음
func apply_stats(v: Dictionary) -> void:
	for k: String in ["hp", "mhp", "res", "maxRes", "resType", "stealthed", "defend", "overwatch", "isBoss", "isSummon", "buffs", "move"]:
		if v.has(k):
			d[k] = v[k]
	if v.has("ha"):
		d["ha"] = v["ha"]
	if v.has("stunned"):
		d["stunned"] = v["stunned"]
	if v.has("frozen"):
		d["frozen"] = v["frozen"]
	if v.has("summonTurns"):
		d["summonTurns"] = v["summonTurns"]
	var f: Variant = v.get("face")
	if typeof(f) == TYPE_ARRAY and f[0] != null and f[1] != null:
		set_face(int(f[0]), int(f[1]))
	if speed <= 0.0:
		hp_disp = float(d["hp"])
		res_disp = float(d.get("res", 0.0))
	queue_redraw()
	bars.queue_redraw()


func set_face(dx: int, dy: int) -> void:
	if dx == 0 and dy == 0:
		return
	d["face"] = [dx, dy]
	_apply_face()
	queue_redraw()


## 화면 방향에 따라 좌우 뒤집기 (웹 VFX._applyFace: 원본 그림은 오른쪽을 봄, 화면 가로 성분이 0 이면 그대로)
func _apply_face() -> void:
	var f: Array = d.get("face", [0, 0])
	if f[0] == null or f[1] == null:
		return
	var sx := iso.g2sx(float(f[0]), float(f[1]))
	if sx != 0.0:
		_flip = sx < 0.0
	body.scale.x = -1.0 if _flip else 1.0


## 카메라 회전: 이동 중이던 트윈은 옛 화면 좌표로 끝나므로 멈추고 목적지(d.x·y)에 바로 놓음 (달리기 동작·moving 표시는 타이머가 정리)
func refresh_camera() -> void:
	if _move_tw != null and _move_tw.is_valid():
		_move_tw.kill()
	place_now()
	_apply_face()
	queue_redraw()


# ── 동작 ──

func set_loop(kind: String) -> void:
	if kind == loop_kind:
		return
	loop_kind = kind
	_refresh_frame()


## 1회 동작 (attack·hit). 반환: 타격 시점까지 초 (시트가 없으면 0)
func play_once(kind: String) -> float:
	var sh: Variant = sdb.sheet(str(d["cls"]), str(d.get("gender", "m")), kind)
	if sh == null:
		return 0.0
	_once_kind = kind
	_once_t = 0.0
	_refresh_frame()
	if sh.has("hit"):
		return float(sh["dur"]) * float(sh["hit"]) / float(sh["frames"]) / 1000.0
	return 0.0


## 이동 (웹 animU: transform .32s + 달리기 시트, 420ms 뒤 멈춤)
func move_to(x: int, y: int) -> void:
	d["x"] = x
	d["y"] = y
	var target := iso.foot(x, y)
	z_index = iso.depth(x, y, 2)
	if _move_tw != null and _move_tw.is_valid():
		_move_tw.kill()
	if speed <= 0.0:
		position = target
		moving = false
		return
	moving = true
	_move_token += 1
	var tok := _move_token
	set_loop("run")
	_move_tw = create_tween()
	_move_tw.tween_property(self, "position", target, 0.32 / speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.42 / speed).timeout.connect(func() -> void:
		if tok == _move_token:
			moving = false
			queue_redraw())


func shake() -> void:
	if speed > 0.0:
		_shake_t = 0.0


func die() -> void:
	dying = true
	_die_t = 0.0
	if speed <= 0.0:
		queue_free()


# ── 매 프레임 ──

func _process(delta: float) -> void:
	_t += delta
	var dt := delta * speed
	_loop_t += dt
	var redraw_bars := false
	if _once_kind != "":
		_once_t += dt
	if absf(hp_disp - float(d["hp"])) > 0.01:
		hp_disp = move_toward(hp_disp, float(d["hp"]), maxf(1.0, absf(float(d["hp"]) - hp_disp)) * dt / 0.3 + 0.5)
		redraw_bars = true
	var rv := float(d.get("res", 0.0))
	if absf(res_disp - rv) > 0.01:
		res_disp = move_toward(res_disp, rv, maxf(1.0, absf(rv - res_disp)) * dt / 0.3 + 0.5)
		redraw_bars = true
	if redraw_bars:
		bars.queue_redraw()
	_refresh_frame()
	# 흔들림·번쩍임 (웹 .shaking: atkShake .25s + hitFlash)
	var off := Vector2.ZERO
	var flash := 0.0
	if _shake_t < 0.3:
		_shake_t += dt
		var k := clampf(_shake_t / 0.25, 0.0, 1.0)
		off = Vector2(sin(k * TAU * 2.0) * 3.0, cos(k * TAU * 2.0) * 2.0) * (1.0 - k)
		flash = 0.6 * (1.0 - k)
	body.position = off
	# 등장 (spawnPop .4s)
	var sc := 1.0
	var alpha := 1.0
	if _spawn_t < 0.4:
		_spawn_t += dt
		var k2 := clampf(_spawn_t / 0.4, 0.0, 1.0)
		sc = lerpf(0.3, 1.0, k2) if k2 < 0.6 else lerpf(1.12, 1.0, (k2 - 0.6) / 0.4)
		alpha = k2
	# 쓰러짐 (deathDissolve .6s: 밝아지며 사라짐, 0.7배로 줄어듦)
	if dying:
		_die_t += dt
		var k3 := clampf(_die_t / 0.6, 0.0, 1.0)
		alpha = 1.0 - k3
		sc = lerpf(1.0, 0.7, k3)
		flash = maxf(flash, k3)
		if _die_t >= 0.6:
			queue_free()
			return
	body.scale = Vector2((-1.0 if _flip else 1.0) * sc, sc)
	_update_material(flash)
	modulate.a = alpha * _base_alpha()


## 웹 클래스 → 투명도: acted .7, 은신(아군) .5 — 은신 적·안개 속 적은 숨김 (visible 은 장면이 정함)
func _base_alpha() -> float:
	var a := 1.0
	if d.get("team") == "ally" and bool(d.get("ha", false)) and not selected:
		a *= 0.7
	if d.get("team") == "ally" and bool(d.get("stealthed", false)):
		a *= 0.5
	return a


func _update_material(flash: float) -> void:
	var glow := Color(0, 0, 0, 0)
	var gpx := 5.0
	if cur_turn:
		var ph := 0.5 - 0.5 * cos(_t / 2.0 * TAU)
		glow = Color(250 / 255.0, 204 / 255.0, 21 / 255.0, lerpf(0.6, 1.0, ph))
		gpx = lerpf(6.0, 10.0, ph)
	elif d.get("team") == "enemy":
		glow = Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.6)
	elif d.get("team") == "ally" and bool(d.get("stealthed", false)):
		glow = Color(139 / 255.0, 92 / 255.0, 246 / 255.0, 0.5)
	var z: float = maxf(0.01, absf(body.get_meta("z", 1.0)))
	var stunned := float(d.get("stunned", 0.0)) > 0.0 or float(d.get("frozen", 0.0)) > 0.0
	var in_forest := iso.tile_type(int(d["x"]), int(d["y"])) == "forest"
	_set_param("glow_color", glow)
	_set_param("glow_px", gpx / z)
	_set_param("shadow_px", 4.0 / z)
	_set_param("shadow_dy", 2.0 / z)
	_set_param("gray", 1.0 if stunned else 0.0)
	_set_param("flash", flash)
	_set_param("body_alpha", 0.55 if in_forest else 1.0)


## 바뀐 값만 셰이더에 넘김 (매 프레임 같은 값을 넣지 않게)
var _params: Dictionary = {}


func _set_param(k: StringName, v: Variant) -> void:
	if _params.get(k) == v:
		return
	_params[k] = v
	_mat.set_shader_parameter(k, v)


## 지금 보일 시트 칸 계산 → Body 에 반영
func _refresh_frame() -> void:
	var cls := str(d["cls"])
	var g := str(d.get("gender", "m"))
	var sh: Variant = null
	var t := 0.0
	var once := false
	if _once_kind != "":
		sh = sdb.sheet(cls, g, _once_kind)
		if sh != null and _once_t * 1000.0 < float(sh["dur"]):
			t = _once_t
			once = true
		else:
			_once_kind = ""
			sh = null
	if sh == null:
		sh = sdb.sheet(cls, g, loop_kind)
		if sh == null:
			sh = sdb.sheet(cls, g, "idle")
		t = _loop_t
	if sh != null:
		var tx := sdb.sheet_tex(sh)
		var pl: Variant = sdb.sheet_place(cls, g, sh)
		if tx != null and pl != null:
			var frames := int(sh["frames"])
			var dur := float(sh["dur"]) / 1000.0
			var fi: int
			if once:
				fi = mini(frames - 1, int(t / dur * frames))
			else:
				fi = int(fposmod(t, dur) / dur * frames) % frames
			var w := float(sh["w"])
			var h := float(sh["h"])
			var z := float(pl["scale"])
			var m := ceilf(10.0 / z)   # 여백 (텍스처 px)
			var src := Rect2(fi * w - m, -m, w + 2.0 * m, h + 2.0 * m)
			if body.tex != tx or body.src != src:
				body.tex = tx
				body.src = src
				var p: Vector2 = pl["pos"]
				body.dst = Rect2(p - Vector2(m, m) * z, Vector2(w + 2.0 * m, h + 2.0 * m) * z)
				body.set_meta("z", z)
				var ts := Vector2(tx.get_width(), tx.get_height())
				_mat.set_shader_parameter("region", Vector4(fi * w / ts.x, 0.0, (fi + 1) * w / ts.x, h / ts.y))
				body.queue_redraw()
			return
	# 정지 그림 (시트 없음 — 소환수 등)
	var st: Variant = sdb.still(cls, g)
	if st != null and body.tex != st["tex"]:
		var t2: Texture2D = st["tex"]
		body.tex = t2
		body.src = Rect2(0, 0, t2.get_width(), t2.get_height())
		body.dst = st["rect"]
		body.set_meta("z", (st["rect"] as Rect2).size.x / float(t2.get_width()))
		_mat.set_shader_parameter("region", Vector4(0, 0, 1, 1))
		body.queue_redraw()


# ── 그리기 ──

func _draw() -> void:
	# 그림자 (웹 .u-shadow 40x6, 타일 가운데 +1)
	var sc := Vector2(0, 4)
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(sc + Vector2(cos(a) * 20.0, sin(a) * 3.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.35))
	# 발밑 방향 삼각형 (이동 중·방향 고르는 중·쓰러지는 중엔 숨김)
	var f: Array = d.get("face", [0, 0])
	if not moving and not face_hidden and not dying and f[0] != null and f[1] != null and (int(f[0]) != 0 or int(f[1]) != 0):
		var tri := iso.face_tri(float(f[0]), float(f[1]), sc, FACE_TIP, FACE_LEN, FACE_HALF)
		var sh := PackedVector2Array()
		for p: Vector2 in tri:
			sh.append(p + (p - (tri[0] + tri[1] + tri[2]) / 3.0) * 0.35)
		draw_colored_polygon(sh, Color(0, 0, 0, 0.55))
		draw_colored_polygon(tri, ENEMY_FACE if d.get("team") == "enemy" else ALLY_FACE)


## HP·자원 막대 (웹 .hp-bg 48x4 / .mp-bg 48x3, 타일 가운데 +5 / +11)
func _draw_bars(ci: CanvasItem) -> void:
	var y0 := 3.0 + 5.0
	ci.draw_rect(Rect2(-24, y0, 48, 4), Color("222222"))
	var mhp := maxf(1.0, float(d.get("mhp", 1.0)))
	ci.draw_rect(Rect2(-24, y0, 48.0 * clampf(hp_disp / mhp, 0.0, 1.0), 4), HP_ENEMY if d.get("team") == "enemy" else HP_ALLY)
	var mr := float(d.get("maxRes", 0.0))
	ci.draw_rect(Rect2(-24, y0 + 6, 48, 3), Color("181818"))
	if mr > 0.0:
		var rt := str(d.get("resType", ""))
		var rc := Color("4488ff") if rt == "mana" else (Color("f0c040") if rt == "energy" else Color("ff6644"))
		ci.draw_rect(Rect2(-24, y0 + 6, 48.0 * clampf(res_disp / mr, 0.0, 1.0), 3), rc)
