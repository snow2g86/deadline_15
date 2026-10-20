extends RefCounted
## 임시 동작 — 관절 회전 키프레임을 코드로 만들어 AnimationPlayer 라이브러리로 넣는다.
##  동작 이름(표준): idle, walk, attack, hit  — 실제 동작 라이브러리를 받으면 NAME_MAP 으로 이름만 이어 붙임
##  회전은 오일러(도, X=앞뒤 · Y=비틀기 · Z=벌리기). 늘어진 팔다리: X 음수 = 앞으로, 양수 = 뒤로.
##  척추·머리: X 양수 = 앞으로 숙임.

const FPS := 24.0
const LEN := {"idle": 1.6, "walk": 0.8, "attack": 0.72, "hit": 0.5}
const LOOP := {"idle": true, "walk": true, "attack": false, "hit": false}
## 외부 라이브러리 이름 → 우리 표준 이름 (예: Mixamo "Idle" → "idle")
const NAME_MAP := {"idle": "idle", "walk": "walk", "attack": "attack", "hit": "hit"}
const ORDER := ["idle", "walk", "attack", "hit"]


static func _ss(a: float, b: float, t: float) -> float:
	var x := clampf((t - a) / (b - a), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## 키 목록 [[t, 값], ...] 사이를 부드럽게 이음
static func _k(keys: Array, t: float) -> float:
	if t <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if t <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			return lerpf(a[1], b[1], _ss(a[0], b[0], t))
	return keys[keys.size() - 1][1]


static func _e(x: float, y: float = 0.0, z: float = 0.0) -> Vector3:
	return Vector3(x, y, z)


## 시각 t(초)의 자세: {뼈 이름: 오일러(도)}, "_hips": Hips 위치 변화(유닛)
static func pose(anim: String, t: float) -> Dictionary:
	var p := {}
	var hips := Vector3.ZERO
	match anim:
		"idle":
			var s := sin(t / 1.6 * TAU)
			var s2 := sin(t / 1.6 * TAU - 0.9)
			hips.y = 0.005 * s
			p["Spine"] = _e(1.5 + 1.5 * s)
			p["Chest"] = _e(1.0 * s)
			p["Head"] = _e(-1.5 * s2)
			p["LeftUpperArm"] = _e(-6 + 3 * s2, 0, 7 + 2 * s)
			p["LeftLowerArm"] = _e(-10)
			p["RightUpperArm"] = _e(-32 + 3 * s2, 0, -8 - 2 * s)
			p["RightLowerArm"] = _e(-35)
			p["LeftUpperLeg"] = _e(-3, 0, 2)
			p["RightUpperLeg"] = _e(3, 0, -2)
			p["LeftLowerLeg"] = _e(5)
			p["RightLowerLeg"] = _e(3)
		"walk":
			var ph := t / 0.8 * TAU
			var sl := sin(ph)
			var sr := -sl
			hips.y = -0.012 * absf(cos(ph)) + 0.004
			hips.x = 0.0
			p["Hips"] = _e(0, 5 * sl, 0)
			p["Spine"] = _e(5, -6 * sl, 0)
			p["Head"] = _e(-3, 5 * sl, 0)
			p["LeftUpperLeg"] = _e(-38 * sl)
			p["RightUpperLeg"] = _e(-38 * sr)
			p["LeftLowerLeg"] = _e(6 + 52 * maxf(0.0, cos(ph)))
			p["RightLowerLeg"] = _e(6 + 52 * maxf(0.0, -cos(ph)))
			p["LeftUpperArm"] = _e(28 * sl, 0, 6)
			p["LeftLowerArm"] = _e(-12 - 10 * maxf(0.0, -sl))
			p["RightUpperArm"] = _e(-30 + 14 * sr, 0, -6)
			p["RightLowerArm"] = _e(-35)
		"attack":
			# 0~0.22 치켜들기, 0.22~0.36 내려치기, 0.36~0.5 멈춤, ~0.72 돌아옴
			var wu := [[0.0, -32], [0.22, -150], [0.3, -95], [0.36, 5], [0.5, 8], [0.72, -32]]
			p["RightUpperArm"] = _e(_k(wu, t), _k([[0, 0], [0.22, -10], [0.36, 12], [0.72, 0]], t), -8)
			p["RightLowerArm"] = _e(_k([[0, -35], [0.22, -50], [0.36, -12], [0.5, -15], [0.72, -35]], t))
			p["Spine"] = _e(_k([[0, 2], [0.22, -9], [0.36, 16], [0.5, 12], [0.72, 2]], t), _k([[0, 0], [0.22, 24], [0.36, -26], [0.5, -20], [0.72, 0]], t), 0)
			p["Chest"] = _e(0, _k([[0, 0], [0.22, 10], [0.36, -12], [0.72, 0]], t), 0)
			p["Head"] = _e(_k([[0, 0], [0.22, -6], [0.36, 8], [0.72, 0]], t), _k([[0, 0], [0.22, -15], [0.36, 12], [0.72, 0]], t), 0)
			p["LeftUpperArm"] = _e(_k([[0, -6], [0.22, 18], [0.36, -35], [0.72, -6]], t), 0, _k([[0, 8], [0.36, 22], [0.72, 8]], t))
			p["LeftLowerArm"] = _e(-20)
			p["LeftUpperLeg"] = _e(_k([[0, -3], [0.22, 12], [0.36, -34], [0.5, -32], [0.72, -3]], t), 0, 3)
			p["LeftLowerLeg"] = _e(_k([[0, 5], [0.22, 14], [0.36, 22], [0.72, 5]], t))
			p["RightUpperLeg"] = _e(_k([[0, 3], [0.22, -8], [0.36, 22], [0.5, 20], [0.72, 3]], t), 0, -3)
			p["RightLowerLeg"] = _e(_k([[0, 3], [0.36, 30], [0.72, 3]], t))
			hips.z = _k([[0, 0], [0.22, -0.03], [0.36, 0.1], [0.5, 0.09], [0.72, 0]], t)
			hips.y = _k([[0, 0], [0.22, 0.01], [0.36, -0.04], [0.5, -0.035], [0.72, 0]], t)
		"hit":
			var recoil := [[0.0, 0.0], [0.07, 1.0], [0.2, 0.75], [0.5, 0.0]]
			var r := _k(recoil, t)
			hips.z = -0.07 * r
			hips.y = -0.025 * r
			p["Hips"] = _e(0, 0, 4 * r)
			p["Spine"] = _e(-20 * r, 6 * r, 0)
			p["Chest"] = _e(-8 * r)
			p["Head"] = _e(-18 * r, -10 * r, 6 * r)
			p["LeftUpperArm"] = _e(24 * r, 0, 10 + 40 * r)
			p["LeftLowerArm"] = _e(-30 * r)
			p["RightUpperArm"] = _e(-32 + 70 * r, 0, -8 - 38 * r)
			p["RightLowerArm"] = _e(-35 + 15 * r)
			p["LeftUpperLeg"] = _e(-12 * r, 0, 4)
			p["RightUpperLeg"] = _e(10 * r, 0, -4)
			p["LeftLowerLeg"] = _e(18 * r)
			p["RightLowerLeg"] = _e(20 * r)
	p["_hips"] = hips
	return p


## Animation 라이브러리를 만든다 (뼈 트랙 경로: "Skeleton3D:<뼈 이름>", AnimationPlayer 루트 = 캐릭터 노드)
static func build_library(skel: Skeleton3D) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for name: String in ORDER:
		var a := Animation.new()
		var n: float = LEN[name]
		a.length = n
		a.loop_mode = Animation.LOOP_LINEAR if LOOP[name] else Animation.LOOP_NONE
		var tracks := {}
		var frames := int(round(n * FPS))
		var hips_idx := skel.find_bone("Hips")
		var hips_rest := skel.get_bone_rest(hips_idx).origin
		var tp := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(tp, NodePath("Skeleton3D:Hips"))
		for f in frames + 1:
			var t := minf(float(f) / FPS, n)
			var ps := pose(name, t if not LOOP[name] else fmod(t, n))
			a.position_track_insert_key(tp, t, hips_rest + (ps["_hips"] as Vector3))
			for bi in skel.get_bone_count():
				var b: String = skel.get_bone_name(bi)
				if b == "Hips" and not ps.has("Hips"):
					ps["Hips"] = Vector3.ZERO
				if not tracks.has(b):
					var ti := a.add_track(Animation.TYPE_ROTATION_3D)
					a.track_set_path(ti, NodePath("Skeleton3D:" + b))
					tracks[b] = ti
				var e: Vector3 = ps.get(b, Vector3.ZERO)
				var q := Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
				a.rotation_track_insert_key(tracks[b], t, q)
		# 모든 뼈에 트랙을 둠 — 동작을 바꿀 때 이전 자세가 남지 않게
		lib.add_animation(name, a)
	return lib
