extends Node2D
## 조각 뼈대 캐릭터 (기사 시범) — Node2D 계층 + Sprite2D 조각, 동작은 코드로 만든 자세표
##  조각 그림 = res://assets/pilot/knight/<f|b>/<조각>.png (tools/pilot/make_parts.py 가 그림), 자리·관절 = rig.json
##  원점 = 발 (타일 윗면 가운데 위 3px). 앞(f) = 오른쪽을 보는 3/4, 뒤(b) = 등. 왼쪽을 보려면 face_left = true (좌우 뒤집기)
##  관절 계층: bob(몸 전체 흔들림) → leg_f · leg_n · torso_g(엉덩이) → arm_f(+방패) · 몸통 · neck(머리 조각 4겹) · arm_n(+칼)

const Look := preload("res://dev/customize_pilot/look.gd")
const DIR := "res://assets/pilot/knight/"
## 화면 몸 높이를 기존 캐릭터(FIG_H 50px)에 맞춤 — 머리끝~발끝 약 106칸 → 50px
const BATTLE_U := 0.47

static var _rig: Dictionary = {}
static var _tex_cache: Dictionary = {}

var view := "f"
var look: Dictionary = Look.default_look()
var u := BATTLE_U
var face_left := false:
	set(v):
		face_left = v
		scale.x = -1.0 if v else 1.0

var anim := "idle"
var t := 0.0
var loop_attack := false
var frozen := false          # true 면 시간을 흘리지 않고 t 자리의 자세로 고정
var parts_count := 0         # 쓰인 Sprite2D 수 (측정용)

var _k: Node2D
var _n: Dictionary = {}      # 관절 이름 → Node2D
var _tone_sprite: Sprite2D
var _flash := 0.0

## 쉬는 자세 (도 단위 회전, 칸 단위 이동) — 칼은 팔 끝에서 위 앞쪽 35도로 겨눔
const REST := {"bx": 0.0, "by": 0.0, "lean": 0.0, "head": 0.0, "arm_n": -35.0, "sword": 70.0, "arm_f": -15.0, "shield": 0.0,
	"leg_n": 0.0, "leg_f": 0.0, "flash": 0.0}

## 공격: 준비(칼을 머리 뒤로) → 내려치기 → 마무리 → 복귀. [시각, {바뀌는 값}]
const ATTACK := [
	[0.0, {}],
	[0.24, {"lean": -10.0, "bx": -3.0, "arm_n": -170.0, "sword": 130.0, "arm_f": -45.0, "shield": -12.0, "head": -4.0, "leg_n": -8.0, "leg_f": 10.0, "by": 1.0}],
	[0.38, {"lean": 12.0, "bx": 7.0, "arm_n": -80.0, "sword": 173.0, "arm_f": -5.0, "shield": 6.0, "head": 6.0, "leg_n": 16.0, "leg_f": -10.0, "by": 2.0}],
	[0.52, {"lean": 14.0, "bx": 8.0, "arm_n": -72.0, "sword": 184.0, "arm_f": -2.0, "shield": 8.0, "head": 8.0, "leg_n": 16.0, "leg_f": -10.0, "by": 2.0}],
	[0.85, {}],
]
const ATTACK_DUR := 0.85
const ATTACK_HIT := 0.38

## 피격: 뒤로 젖혀지며 번쩍
const HIT := [
	[0.0, {}],
	[0.07, {"bx": -6.0, "lean": -14.0, "head": -12.0, "arm_n": -10.0, "sword": 100.0, "arm_f": 12.0, "leg_n": -10.0, "leg_f": 6.0, "flash": 1.0}],
	[0.2, {"bx": -4.0, "lean": -9.0, "head": -8.0, "arm_n": -18.0, "sword": 95.0, "arm_f": 6.0, "leg_n": -6.0, "leg_f": 4.0, "flash": 0.3}],
	[0.5, {}],
]
const HIT_DUR := 0.5


static func rig() -> Dictionary:
	if _rig.is_empty():
		var s := FileAccess.get_file_as_string(DIR + "rig.json")
		var j: Variant = JSON.parse_string(s)
		_rig = j if typeof(j) == TYPE_DICTIONARY else {}
	return _rig


static func load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	else:
		# 아직 편집기 가져오기(import)를 안 한 그림 — 실행 중에 직접 읽음 (개발용)
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_tex_cache[path] = t
	return t


## 발밑 그림자 (게임 unit_view 의 .u-shadow 40x6 과 같은 크기)
func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.15))
	draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.32))


func setup(p_view: String, p_look: Dictionary, p_u: float = BATTLE_U) -> void:
	view = p_view
	look = Look.normalize(p_look)
	u = p_u
	_build()


func set_look(p_look: Dictionary) -> void:
	look = Look.normalize(p_look)
	_build()


func set_view(v: String) -> void:
	view = v
	_build()


func play(a: String) -> void:
	anim = a
	t = 0.0
	frozen = false


func show_pose(a: String, time: float) -> void:
	anim = a
	t = time
	frozen = true
	_apply(_pose(anim, t))


func _build() -> void:
	if _k != null:
		_k.queue_free()
		remove_child(_k)
	_n.clear()
	parts_count = 0
	var R := rig()
	if R.is_empty():
		push_error("pilot_char: rig.json 이 없음")
		return
	var J: Dictionary = (R["joints"] as Dictionary)[view]
	var hip := _v(J["hip"])
	_k = Node2D.new()
	_k.name = "Rig"
	_k.scale = Vector2(u, u)
	_k.position = Vector2(-hip.x * u, -float(R["floor"]) * u)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_k)
	var bob := _node(_k, "bob", Vector2.ZERO)
	var leg_f := _node(bob, "leg_f", _v(J["leg_f"]))
	_sprite(leg_f, "leg_f", _v(J["leg_f"]))
	var leg_n := _node(bob, "leg_n", _v(J["leg_n"]))
	_sprite(leg_n, "leg_n", _v(J["leg_n"]))
	var tg := _node(bob, "torso_g", hip)
	var o := int(look["o"])
	var arm_f := _node(tg, "arm_f", _v(J["sh_f"]) - hip)
	_sprite(arm_f, "arm_f_%d" % o, _v(J["sh_f"]))
	var shield := _node(arm_f, "shield", _v(J["wr_f"]) - _v(J["sh_f"]))
	_sprite(shield, "shield", _v(J["wr_f"]))
	var torso := _node(tg, "torso", Vector2.ZERO)
	_sprite(torso, "torso_%d" % o, hip)
	var neck := _node(tg, "neck", _v(J["neck"]) - hip)
	var nk := _v(J["neck"])
	var h := int(look["h"])
	if view == "f":
		_sprite(neck, "hair_back_%d" % h, nk)
		_tone_sprite = _sprite(neck, "head_skin", nk)
		_sprite(neck, "face_%d" % int(look["f"]), nk)
	else:
		_tone_sprite = _sprite(neck, "head_skin", nk)
		_sprite(neck, "hair_back_%d" % h, nk)
	_sprite(neck, "hair_front_%d" % h, nk)
	if _tone_sprite != null:
		_tone_sprite.modulate = Look.TONES[int(look["t"])]
	var arm_n := _node(tg, "arm_n", _v(J["sh_n"]) - hip)
	_sprite(arm_n, "arm_n_%d" % o, _v(J["sh_n"]))
	var sword := _node(arm_n, "sword", _v(J["wr_n"]) - _v(J["sh_n"]))
	_sprite(sword, "sword", _v(J["wr_n"]))
	_apply(_pose(anim, t))


func _v(a: Variant) -> Vector2:
	return Vector2(float((a as Array)[0]), float((a as Array)[1]))


func _node(parent: Node, nm: String, pos: Vector2) -> Node2D:
	var n := Node2D.new()
	n.name = nm
	n.position = pos
	parent.add_child(n)
	_n[nm] = n
	return n


## 조각 그림 하나 (없는 조각 — 예: 뒤 모습의 얼굴 — 은 건너뜀). joint = 이 조각 노드의 관절(기준 칸 좌표)
func _sprite(parent: Node2D, part: String, joint: Vector2) -> Sprite2D:
	var R := rig()
	var key := "%s/%s" % [view, part]
	var parts: Dictionary = R["parts"]
	if not parts.has(key):
		return null
	var p: Dictionary = parts[key]
	var tex := load_tex(DIR + key + ".png")
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.name = part
	s.texture = tex
	s.centered = false
	s.scale = Vector2.ONE / float(R["K"])
	s.position = Vector2(float(p["x"]), float(p["y"])) - joint
	parent.add_child(s)
	parts_count += 1
	return s


func _process(d: float) -> void:
	if _k == null or frozen:
		return
	t += d
	var dur := _dur(anim)
	if dur > 0.0 and t >= dur:
		if anim == "attack" and loop_attack:
			t = fmod(t, dur)
		else:
			anim = "idle"
			t = 0.0
	_apply(_pose(anim, t))


func _dur(a: String) -> float:
	match a:
		"attack":
			return ATTACK_DUR
		"hit":
			return HIT_DUR
	return 0.0


## 시간 t 의 자세 (REST 에서 바뀐 값만 채운 dict 가 아니라 전부 채운 dict)
func _pose(a: String, time: float) -> Dictionary:
	var p: Dictionary = REST.duplicate()
	match a:
		"idle":
			var ph := time * TAU / 1.8
			p["by"] = 1.4 * sin(ph)
			p["lean"] = 1.2 * sin(ph + 0.5)
			p["head"] = 2.0 * sin(ph - 0.6)
			p["arm_n"] += 2.0 * sin(ph + 1.0)
			p["sword"] += 2.5 * sin(ph)
			p["arm_f"] += 1.5 * sin(ph + 1.0)
		"move":
			var ph2 := time * TAU / 0.56
			var s := sin(ph2)
			p["by"] = -3.0 * absf(s)
			p["lean"] = 5.0
			p["head"] = -2.5 * absf(s) - 2.0
			p["leg_n"] = 32.0 * s
			p["leg_f"] = -32.0 * s
			p["arm_n"] += 14.0 * s
			p["sword"] -= 10.0 * s
			p["arm_f"] -= 30.0 * s
			p["shield"] = -8.0 * s
		"attack":
			_keys(p, ATTACK, time)
		"hit":
			_keys(p, HIT, time)
	return p


## 자세표 보간: 구간마다 부드럽게(smoothstep). 키에 없는 값은 쉬는 자세
func _keys(p: Dictionary, keys: Array, time: float) -> void:
	var tt := clampf(time, 0.0, float(keys[keys.size() - 1][0]))
	var i := 0
	while i < keys.size() - 2 and tt > float(keys[i + 1][0]):
		i += 1
	var a: Array = keys[i]
	var b: Array = keys[i + 1]
	var span := float(b[0]) - float(a[0])
	var f := 0.0 if span <= 0.0 else clampf((tt - float(a[0])) / span, 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	for k: String in REST.keys():
		var va: float = float((a[1] as Dictionary).get(k, REST[k]))
		var vb: float = float((b[1] as Dictionary).get(k, REST[k]))
		p[k] = lerpf(va, vb, f)


func _apply(p: Dictionary) -> void:
	if _k == null:
		return
	(_n["bob"] as Node2D).position = Vector2(float(p["bx"]), float(p["by"]))
	(_n["torso_g"] as Node2D).rotation_degrees = p["lean"]
	(_n["neck"] as Node2D).rotation_degrees = p["head"]
	(_n["arm_n"] as Node2D).rotation_degrees = p["arm_n"]
	(_n["sword"] as Node2D).rotation_degrees = p["sword"]
	(_n["arm_f"] as Node2D).rotation_degrees = p["arm_f"]
	(_n["shield"] as Node2D).rotation_degrees = p["shield"]
	(_n["leg_n"] as Node2D).rotation_degrees = p["leg_n"]
	(_n["leg_f"] as Node2D).rotation_degrees = p["leg_f"]
	var fl := float(p["flash"])
	_k.modulate = Color(1.0 + 0.9 * fl, 1.0 + 0.5 * fl, 1.0 + 0.5 * fl)


## 타격 시점(초) — 피해 숫자·이펙트를 띄울 때
func hit_time() -> float:
	return ATTACK_HIT
