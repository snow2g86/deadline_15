extends Node2D
## 유닛 하나의 그림 — 웹 render.js rUnits 의 .unit-sprite + rig.js 스프라이트 시트 + vfx.js 방향 삼각형 · motion.js 공격 키프레임
##  원점 = 발 위치 (타일 윗면 가운데에서 3px 위). z_index = Grid.depth(x, y, 2) (도착 칸 기준, 웹과 같음)
##  화면 상태(d)는 엔진 사건의 사본으로만 바뀜 — 엔진 상태를 직접 읽지 않음 (연출이 엔진보다 늦게 재생되므로)
##  구성: 자기 _draw (그림자·발밑 방향 삼각형) → Body (시트 한 칸, 셰이더) → Bars (HP·자원 막대) → Top (버프 배지·기절 수·소환 턴)
##  (3b) 매 프레임 할 일을 줄임: 시트·자리·텍스처는 직업·성별·동작마다 한 번 찾아 두고, 프레임 번호가 바뀔 때만 다시 그림.
##       숲 여부는 칸이 바뀔 때만 계산. 셰이더 값은 바뀐 것만 넘김.

const Iso := preload("res://scripts/battle/iso.gd")
const SpriteDB := preload("res://scripts/battle/sprite_db.gd")
const UnitShader := preload("res://scripts/battle/shaders/unit.gdshader")
const Kit := preload("res://scripts/battle/ui_kit.gd")

const ALLY_FACE := Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.95)
const ENEMY_FACE := Color(248 / 255.0, 113 / 255.0, 113 / 255.0, 0.95)
const HP_ALLY := Color("22c55e")
const HP_ENEMY := Color("ef4444")
## 발밑 방향 삼각형 (웹 VFX.FACE_TIP·FACE_LEN·FACE_HALF — 칸 단위)
const FACE_TIP := 0.5
const FACE_LEN := 0.2
const FACE_HALF := 0.12
## 웹 motion.js _MS: 키프레임 px 는 36px 아이콘 기준 → UI(52) 크기
const MS := 52.0 / 36.0
const BADGE_BG := {"buff": Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.7), "debuff": Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.7), "cover": Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.75)}

var id: int = 0
var d: Dictionary = {}          # 화면 상태: team, cls, gender, x, y, hp, mhp, res, maxRes, resType, face[gdx,gdy], stealthed, ha, stunned …
var iso: Iso
var sdb: SpriteDB
var icons: Object

var body: Body
var bars: Bars
var top: Top
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
var hover := false             # 행동 순서·카드에 마우스 (웹 .nav-hover)
var in_fog := false
var dying := false
var reduce_motion := false
var _die_t := 0.0
var _spawn_t := 9.0
var _shake_t := 9.0
var _hop_t := 9.0
var _glow_t := 9.0
var _move_tw: Tween
var _move_token := 0
var _t := 0.0
## 연출 속도 배율 (0 = 즉시)
var speed := 1.0

## 시트 찾기 결과 (직업·성별이 정해지면 한 번): 동작 → {sh, tex, pl, frames, dur, w, h, z, m} | null
var _sheet_cache: Dictionary = {}
var _cur_sheet: Variant = null
var _cur_fi := -1
var _in_forest := false
var _is_enemy := false
var _is_ally := false
## 키프레임 공격 동작 (시트가 없는 유닛 — 웹 playAtkMotion 의 Web Animations)
var _motion: Dictionary = {}
var _motion_t := 9.0
var _motion_dir := Vector2.RIGHT
var _motion_face := 1.0


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


## 머리 위: 버프 배지(웹 .u-badges) · 기절 수(.stun-label — 발밑) · 소환 턴(.summon-turns)
class Top extends Node2D:
	var u: Node
	var badges: Array = []   # [{tex, kind, glyph}]
	var stun := ""
	var summon := ""

	func _draw() -> void:
		u._draw_top(self)


func setup(p_iso: Iso, p_sdb: SpriteDB, data: Dictionary, p_speed: float, p_icons: Object = null) -> void:
	iso = p_iso
	sdb = p_sdb
	icons = p_icons
	speed = p_speed
	d = data.duplicate(true)
	id = int(d["id"])
	_is_enemy = d.get("team") == "enemy"
	_is_ally = d.get("team") == "ally"
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
	top = Top.new()
	top.u = self
	top.z_index = 1
	add_child(top)
	place_now()
	_apply_face()
	_refresh_frame()
	_update_top()


## 칸 위치로 바로
func place_now() -> void:
	position = iso.foot(int(d["x"]), int(d["y"]))
	z_index = iso.depth(int(d["x"]), int(d["y"]), 2)
	_in_forest = iso.tile_type(int(d["x"]), int(d["y"])) == "forest"


func spawn_anim() -> void:
	_spawn_t = 0.0 if speed > 0.0 else 9.0


# ── 상태 반영 ──

const STAT_KEYS := ["hp", "mhp", "res", "maxRes", "resType", "stealthed", "defend", "overwatch", "isBoss", "isSummon", "buffs", "move", "ap", "atk", "def", "range", "intent"]
## 화면 사본의 덧붙인 값 (battle_scene._unit_snap — 배지·카드·툴팁용)
const EXTRA_KEYS := ["ha", "stunned", "frozen", "summonTurns", "lv", "name", "role", "actionRec", "furyBuff", "defBuff", "disarmed", "channeling",
	"_rootedTurns", "_bleedTurns", "_sanctuaryTurns", "_phalanxTurns", "_empowerTurns", "_cursed", "_sacrificeKnight", "_sacrificeDmgCount",
	"_tenacityDef", "skillLv", "summonerId", "badges"]


## 사건 사본(unit_view)으로 수치 갱신 — 위치는 이동 연출이 따로 맡음
func apply_stats(v: Dictionary) -> void:
	for k: String in STAT_KEYS:
		if v.has(k):
			d[k] = v[k]
	for k2: String in EXTRA_KEYS:
		if v.has(k2):
			d[k2] = v[k2]
	var f: Variant = v.get("face")
	if typeof(f) == TYPE_ARRAY and f[0] != null and f[1] != null:
		set_face(int(f[0]), int(f[1]))
	if speed <= 0.0:
		hp_disp = float(d["hp"])
		res_disp = float(d.get("res", 0.0))
	queue_redraw()
	bars.queue_redraw()
	_update_top()


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
	body.scale.x = -absf(body.scale.x) if _flip else absf(body.scale.x)


## 카메라 회전: 이동 중이던 트윈은 옛 화면 좌표로 끝나므로 멈추고 목적지(d.x·y)에 바로 놓음 (달리기 동작·moving 표시는 타이머가 정리)
func refresh_camera() -> void:
	if _move_tw != null and _move_tw.is_valid():
		_move_tw.kill()
	place_now()
	_apply_face()
	queue_redraw()


## 머리 위 배지 다시 (d["badges"] = [{icon, kind}] 를 장면이 넣어 줌)
func _update_top() -> void:
	var list: Array = []
	for b: Dictionary in d.get("badges", []):
		var tex: Texture2D = icons.call("emoji", str(b["icon"])) if icons != null else null
		list.append({"tex": tex, "kind": str(b["kind"])})
	var st := ""
	var fr := _num(d.get("frozen"))
	var sn := _num(d.get("stunned"))
	if fr > 0.0:
		st = "❄" + str(int(fr))
	elif sn > 0.0:
		st = str(int(sn))
	var sm := ""
	if bool(d.get("isSummon", false)) and d.get("summonTurns") != null:
		sm = str(int(float(d["summonTurns"])))
	if str(list) != str(top.badges) or st != top.stun or sm != top.summon:
		top.badges = list
		top.stun = st
		top.summon = sm
		top.queue_redraw()


# ── 동작 ──

func set_loop(kind: String) -> void:
	if kind == loop_kind:
		return
	loop_kind = kind
	_refresh_frame()


## 시트 + 자리 + 텍스처를 한 번 찾아 둠
func _sheet(kind: String) -> Variant:
	if _sheet_cache.has(kind):
		return _sheet_cache[kind]
	var cls := str(d["cls"])
	var g := str(d.get("gender", "m"))
	var sh: Variant = sdb.sheet(cls, g, kind)
	var out: Variant = null
	if sh != null:
		var tx := sdb.sheet_tex(sh)
		var pl: Variant = sdb.sheet_place(cls, g, sh)
		if tx != null and pl != null:
			var z := float(pl["scale"])
			out = {"sh": sh, "tex": tx, "pl": pl, "frames": int(sh["frames"]), "dur": float(sh["dur"]) / 1000.0, "w": float(sh["w"]), "h": float(sh["h"]),
				"z": z, "m": ceilf(10.0 / z), "hit": (float(sh["dur"]) * float(sh["hit"]) / float(sh["frames"]) / 1000.0) if sh.has("hit") else 0.0,
				"ts": Vector2(tx.get_width(), tx.get_height())}
	_sheet_cache[kind] = out
	return out


func has_sheet(kind: String) -> bool:
	return _sheet(kind) != null


## 1회 동작 (attack·hit). 반환: 타격 시점까지 초 (시트가 없으면 0)
func play_once(kind: String) -> float:
	var s: Variant = _sheet(kind)
	if s == null:
		return 0.0
	_once_kind = kind
	_once_t = 0.0
	_refresh_frame()
	return float(s["hit"])


## 시트 공격 동작의 타격 시점 (움직임 줄이기로 재생하지 않을 때도 타이밍은 같게 — 웹 atkHitDelay)
func sheet_hit(kind: String) -> float:
	var s: Variant = _sheet(kind)
	return float(s["hit"]) if s != null else 0.0


## 키프레임 공격 동작 (웹 motion.js playAtkMotion — 시트가 없는 유닛). m = ATK_MOTIONS[cls], dir = 화면에서 대상 쪽 단위 벡터
func play_motion(m: Dictionary, dir: Vector2) -> float:
	var hit := float(m.get("dur", 400)) * float(m.get("hit", 0.5)) / 1000.0
	if reduce_motion or speed <= 0.0:
		return hit
	_motion = m
	_motion_t = 0.0
	_motion_dir = dir
	_motion_face = -1.0 if dir.x < 0.0 else 1.0
	return hit


## 이동 (웹 animU: transform .32s + 달리기 시트, 420ms 뒤 멈춤)
func move_to(x: int, y: int) -> void:
	d["x"] = x
	d["y"] = y
	var target := iso.foot(x, y)
	z_index = iso.depth(x, y, 2)
	_in_forest = iso.tile_type(x, y) == "forest"
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


## 동료를 딛고 넘는 도약 (웹 vaultHop: 아이콘만 포물선 .42s, 26px)
func hop() -> void:
	if speed > 0.0 and not reduce_motion:
		_hop_t = 0.0


## 버프 빛 (웹 .buff-glow .5s: 밝아짐 + 초록 빛)
func glow() -> void:
	if speed > 0.0:
		_glow_t = 0.0


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
	var hp := float(d["hp"])
	if absf(hp_disp - hp) > 0.01:
		hp_disp = move_toward(hp_disp, hp, maxf(1.0, absf(hp - hp_disp)) * dt / 0.3 + 0.5)
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
		if not reduce_motion:
			off = Vector2(sin(k * TAU * 2.0) * 3.0, cos(k * TAU * 2.0) * 2.0) * (1.0 - k)
		flash = 0.6 * (1.0 - k)
	if _hop_t < 0.42:
		_hop_t += dt
		var kh := clampf(_hop_t / 0.42, 0.0, 1.0)
		off.y -= 26.0 * (kh / 0.45 if kh < 0.45 else 1.0 - (kh - 0.45) / 0.55) * (1.0 - 0.15 * kh)
	var glow_k := 0.0
	if _glow_t < 0.5:
		_glow_t += dt
		glow_k = sin(clampf(_glow_t / 0.5, 0.0, 1.0) * PI)
		flash = maxf(flash, 0.35 * glow_k)
	# 키프레임 공격 동작
	var rot := 0.0
	var msx := 1.0
	var msy := 1.0
	var malpha := 1.0
	var mglow := 0.0
	if not _motion.is_empty():
		var dur := float(_motion.get("dur", 400)) / 1000.0
		_motion_t += dt
		var kk := _motion_t / dur
		if kk >= 1.0:
			_motion = {}
		else:
			var fr := _motion_frame(kk)
			off += _motion_dir * fr[0] * MS + Vector2(0, -fr[1] * MS)
			rot = deg_to_rad(fr[2] * _motion_face)
			msx = fr[3]
			msy = fr[4]
			mglow = fr[5]
			malpha = fr[6]
	body.position = off
	body.rotation = rot
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
	body.scale = Vector2((-1.0 if _flip else 1.0) * sc * msx, sc * msy)
	_update_material(flash, glow_k, mglow)
	modulate.a = alpha * _base_alpha() * malpha


## 키프레임 보간 → [f, u, r, sx, sy, g, a] (웹: 구간마다 cubic-bezier(.3,.7,.4,1))
func _motion_frame(k: float) -> Array:
	var keys: Array = _motion.get("keys", [])
	for i in keys.size() - 1:
		var k0: Dictionary = keys[i]
		var k1: Dictionary = keys[i + 1]
		var o0 := float(k0.get("o", 0.0))
		var o1 := float(k1.get("o", 1.0))
		if k <= o1:
			var e := clampf((k - o0) / maxf(0.0001, o1 - o0), 0.0, 1.0)
			e = 1.0 - pow(1.0 - e, 2.2)
			var out: Array = []
			for f: Array in [["f", 0.0], ["u", 0.0], ["r", 0.0], ["sx", 1.0], ["sy", 1.0], ["g", 0.0], ["a", 1.0]]:
				out.append(lerpf(float(k0.get(f[0], f[1])), float(k1.get(f[0], f[1])), e))
			return out
	return [0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0]


## 웹 클래스 → 투명도: acted .7, 은신(아군) .5 — 은신 적·안개 속 적은 숨김 (visible 은 장면이 정함)
func _base_alpha() -> float:
	var a := 1.0
	if _is_ally and bool(d.get("ha", false)) and not selected:
		a *= 0.7
	if _is_ally and bool(d.get("stealthed", false)):
		a *= 0.5
	return a


func _update_material(flash: float, glow_k: float = 0.0, mglow: float = 0.0) -> void:
	var glow := Color(0, 0, 0, 0)
	var gpx := 5.0
	if hover:
		glow = Color(1, 1, 1, 0.9)
		gpx = 6.0
	elif cur_turn:
		var ph := 0.5 - 0.5 * cos(_t / 2.0 * TAU)
		glow = Color(250 / 255.0, 204 / 255.0, 21 / 255.0, lerpf(0.6, 1.0, ph))
		gpx = lerpf(6.0, 10.0, ph)
	elif _is_enemy:
		glow = Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.6)
	elif _is_ally and bool(d.get("stealthed", false)):
		glow = Color(139 / 255.0, 92 / 255.0, 246 / 255.0, 0.5)
	if glow_k > 0.0:
		glow = glow.lerp(Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.8), glow_k)
		gpx = lerpf(gpx, 8.0, glow_k)
	if mglow > 0.0 and not _motion.is_empty():
		glow = glow.lerp(Color(str(_motion.get("glow", "#ffffff"))), mglow)
		gpx = lerpf(gpx, 4.0 + mglow * 8.0, mglow)
	var z: float = maxf(0.01, absf(float(body.get_meta("z", 1.0))))
	var stunned := _num(d.get("stunned")) > 0.0 or _num(d.get("frozen")) > 0.0
	_set_param(&"glow_color", glow)
	_set_param(&"glow_px", gpx / z)
	_set_param(&"shadow_px", 4.0 / z)
	_set_param(&"shadow_dy", 2.0 / z)
	_set_param(&"gray", 1.0 if stunned else 0.0)
	_set_param(&"flash", flash)
	_set_param(&"body_alpha", 0.55 if _in_forest else 1.0)


static func _num(v: Variant) -> float:
	return float(v) if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT else 0.0


## 바뀐 값만 셰이더에 넘김 (매 프레임 같은 값을 넣지 않게)
var _params: Dictionary = {}


func _set_param(k: StringName, v: Variant) -> void:
	if _params.get(k) == v:
		return
	_params[k] = v
	_mat.set_shader_parameter(k, v)


## 지금 보일 시트 칸 계산 → Body 에 반영 (프레임 번호·시트가 바뀔 때만 다시 그림)
func _refresh_frame() -> void:
	var s: Variant = null
	var t := 0.0
	var once := false
	if _once_kind != "":
		s = _sheet(_once_kind)
		if s != null and _once_t < float(s["dur"]):
			t = _once_t
			once = true
		else:
			_once_kind = ""
			s = null
	if s == null:
		s = _sheet(loop_kind)
		if s == null:
			s = _sheet("idle")
		t = _loop_t
	if s != null:
		var frames: int = s["frames"]
		var dur: float = s["dur"]
		var fi: int
		if once:
			fi = mini(frames - 1, int(t / dur * frames))
		else:
			fi = int(fposmod(t, dur) / dur * frames) % frames
		if is_same(s, _cur_sheet) and fi == _cur_fi:
			return
		_cur_sheet = s
		_cur_fi = fi
		var w: float = s["w"]
		var h: float = s["h"]
		var z: float = s["z"]
		var m: float = s["m"]
		var tx: Texture2D = s["tex"]
		body.tex = tx
		body.src = Rect2(fi * w - m, -m, w + 2.0 * m, h + 2.0 * m)
		var p: Vector2 = s["pl"]["pos"]
		body.dst = Rect2(p - Vector2(m, m) * z, Vector2(w + 2.0 * m, h + 2.0 * m) * z)
		body.set_meta("z", z)
		var ts: Vector2 = s["ts"]
		_mat.set_shader_parameter("region", Vector4(fi * w / ts.x, 0.0, (fi + 1) * w / ts.x, h / ts.y))
		body.queue_redraw()
		return
	# 정지 그림 (시트 없음 — 소환수 등)
	if _cur_sheet != null or body.tex == null:
		_cur_sheet = null
		var st: Variant = sdb.still(str(d["cls"]), str(d.get("gender", "m")))
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
		draw_colored_polygon(tri, ENEMY_FACE if _is_enemy else ALLY_FACE)


## HP·자원 막대 (웹 .hp-bg 48x4 / .mp-bg 48x3, 타일 가운데 +5 / +11)
func _draw_bars(ci: CanvasItem) -> void:
	var y0 := 3.0 + 5.0
	ci.draw_rect(Rect2(-24, y0, 48, 4), Color("222222"))
	var mhp := maxf(1.0, float(d.get("mhp", 1.0)))
	ci.draw_rect(Rect2(-24, y0, 48.0 * clampf(hp_disp / mhp, 0.0, 1.0), 4), HP_ENEMY if _is_enemy else HP_ALLY)
	var mr := float(d.get("maxRes", 0.0))
	ci.draw_rect(Rect2(-24, y0 + 6, 48, 3), Color("181818"))
	if mr > 0.0:
		var rt := str(d.get("resType", ""))
		var rc := Color("4488ff") if rt == "mana" else (Color("f0c040") if rt == "energy" else Color("ff6644"))
		ci.draw_rect(Rect2(-24, y0 + 6, 48.0 * clampf(res_disp / mr, 0.0, 1.0), 3), rc)


## 배지 (웹 .u-badges: 머리 위 가운데 16px 원, 초록·빨강·파랑 바탕) · 기절 수 (빨간 상자, 발밑) · 소환 턴 (보라 원, 오른쪽 위)
func _draw_top(ci: Top) -> void:
	var head := -60.0
	var n := ci.badges.size()
	if n > 0:
		var w := n * 17.0 - 1.0
		var x0 := -w / 2.0
		for i in n:
			var b: Dictionary = ci.badges[i]
			var c := Vector2(x0 + i * 17.0 + 8.0, head - 4.0)
			ci.draw_circle(c, 8.0, BADGE_BG.get(b["kind"], BADGE_BG["buff"]))
			ci.draw_arc(c, 8.0, 0, TAU, 18, Color(1, 1, 1, 0.5), 1.0, true)
			if b["tex"] != null:
				ci.draw_texture_rect(b["tex"], Rect2(c - Vector2(6, 6), Vector2(12, 12)), false)
	if ci.stun != "":
		var f := Kit.bold(800)
		var tw := f.get_string_size(ci.stun, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var r := Rect2(-tw / 2.0 - 6.0, 13.0, tw + 12.0, 16.0)
		ci.draw_rect(r, Color("ff4444"))
		ci.draw_string(f, Vector2(r.position.x + 6.0, r.position.y + 12.5), ci.stun, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	if ci.summon != "":
		var c2 := Vector2(26, head + 6.0)
		ci.draw_circle(c2, 10.0, Color("8b5cf6"))
		ci.draw_arc(c2, 10.0, 0, TAU, 20, Color.WHITE, 2.0, true)
		var f2 := Kit.bold(800)
		var sw := f2.get_string_size(ci.summon, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		ci.draw_string(f2, c2 + Vector2(-sw / 2.0, 4.0), ci.summon, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
