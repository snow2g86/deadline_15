extends Node3D
## KayKit(CC0) 실제 모델 캐릭터 — p3_char.gd(임시 사람)와 같은 겉모습(apply_look·set_dir·play·pose_at·set_style)
##  glb 를 런타임에 GLTFDocument 로 읽음 (프로젝트 임포트 없이도 동작). 뼈대 = Rig_Medium (동작 묶음과 같은 뼈 이름 → 리타게팅 불필요)
##  몸(머리·옷 포함)을 슬롯 하나로 바꿔 끼움, 투구·망토는 메시 켜고 끄기, 무기·방패는 handslot 뼈 BoneAttachment3D

const Look := preload("res://dev/pilot3d/p3b_look.gd")
const K := "res://assets/pilot3d/kaykit/"
## 키(발~투구 끝)를 이 유닛 수로 맞춤. 2D 몸 높이 50px(=0.85) + 투구/모자가 얹히는 정도
const TARGET_H := 0.75
const ANIM_FILES := ["General", "MovementBasic", "MovementAdvanced", "CombatMelee", "CombatRanged", "Special"]
const HELM_PARTS := ["Helmet", "HelmetVisor", "Hat", "BearHat", "Mask"]
const LOOPS := ["Idle_A", "Idle_B", "Walking_A", "Walking_B", "Walking_C", "Running_A", "Running_B", "Melee_2H_Idle", "Melee_Unarmed_Idle", "Ranged_Bow_Idle", "Ranged_Bow_Aiming_Idle", "Melee_Blocking", "Running_HoldingBow", "Sneaking"]

static var _toon: Shader
static var _outline: Shader
static var _templates: Dictionary = {}   # 몸 이름 → {root, tex, lum, height}
static var _props: Dictionary = {}       # 소품 이름 → Node
static var _lib: AnimationLibrary
static var tex_levels_default := 0

var look: Dictionary = {}
var model: Node3D
var skel: Skeleton3D
var player: AnimationPlayer
var mat: ShaderMaterial
var hull: ShaderMaterial
var dir: int = 0
var cur_anim: String = "idle"
var auto_return := true
var _body := -1
var _attach: Dictionary = {}
var _speed := 1.0
var _pending_t := -1.0
var _scale := 0.4
var _outline_world := 0.0147
var _tex_levels := 0
var _have_role := true
var _parts: Array = []
var _merged: MeshInstance3D = null
## 보이는 몸 메시들을 한 메시로 합침 (그리기 호출·스킨 갱신 횟수를 줄임). 끄면 부분별 메시 그대로
static var merge_meshes := true
signal anim_done(name: String)


static func load_glb(path: String) -> Node:
	var st := GLTFState.new()
	var d := GLTFDocument.new()
	if d.append_from_file(ProjectSettings.globalize_path(path), st) != OK:
		push_error("glb 읽기 실패 " + path)
		return null
	return d.generate_scene(st)


## 메시마다 "부드러운 바깥 방향"(같은 자리 꼭짓점 법선 평균)을 TANGENT 에 넣은 새 메시로 바꿈 → 뒤집은 메시 외곽선이 모서리에서 안 갈라짐
static func _smooth_mesh(mi: MeshInstance3D) -> void:
	var src := mi.mesh as ArrayMesh
	var arr: Array = src.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var acc := {}
	for i in v.size():
		var key := Vector3i(roundi(v[i].x * 500.0), roundi(v[i].y * 500.0), roundi(v[i].z * 500.0))
		acc[key] = (acc[key] as Vector3 if acc.has(key) else Vector3.ZERO) + n[i]
	var t := PackedFloat32Array()
	t.resize(v.size() * 4)
	for i in v.size():
		var key2 := Vector3i(roundi(v[i].x * 500.0), roundi(v[i].y * 500.0), roundi(v[i].z * 500.0))
		var s: Vector3 = (acc[key2] as Vector3).normalized()
		t[i * 4] = s.x
		t[i * 4 + 1] = s.y
		t[i * 4 + 2] = s.z
		t[i * 4 + 3] = 1.0
	arr[Mesh.ARRAY_TANGENT] = t
	var nm := ArrayMesh.new()
	nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	nm.custom_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 5, 4))
	mi.mesh = nm


static func _template(body: String) -> Dictionary:
	if _templates.has(body):
		return _templates[body]
	var root := load_glb(K + "characters/%s.glb" % body)
	for m in root.find_children("*", "MeshInstance3D", true, false):
		_smooth_mesh(m as MeshInstance3D)
	var first := root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var tex_path := K + "characters/%s_texture.png" % ("rogue" if body.begins_with("Rogue") else body.to_lower())
	var img := Image.load_from_file(ProjectSettings.globalize_path(tex_path))
	img.convert(Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	# 칸 평균 밝기 (선형 색 기준, 칸 가운데 띠)
	var lum := PackedFloat32Array()
	lum.resize(32)
	for cy in 4:
		for cx in 8:
			var s := 0.0
			var cnt := 0
			for y in range(cy * 256 + 8, cy * 256 + 248, 8):
				for x in range(cx * 128 + 16, cx * 128 + 112, 16):
					var c := img.get_pixel(x, y).srgb_to_linear()
					s += 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
					cnt += 1
			lum[cx + cy * 8] = s / float(cnt)
	var h := 0.0
	var sk := root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.name.ends_with("Cape"):
			continue
		var a := mi.get_aabb()
		h = maxf(h, a.position.y + a.size.y)
	var t := {"root": root, "tex": tex, "lum": lum, "height": h}
	_templates[body] = t
	return t


static func _prop(name: String) -> Node:
	if not _props.has(name):
		_props[name] = load_glb(K + "props/%s.gltf" % name)
	return _props[name]


## 동작 묶음 → 하나의 라이브러리 (KayKit 동작 이름 그대로 + 표준 이름은 resolve() 가 이어 줌)
static func lib() -> AnimationLibrary:
	if _lib != null:
		return _lib
	_lib = AnimationLibrary.new()
	for f: String in ANIM_FILES:
		var r := load_glb(K + "anims/Rig_Medium_%s.glb" % f)
		var ap := r.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		for an: String in ap.get_animation_list():
			if _lib.has_animation(an) or an == "T-Pose":
				continue
			var a := ap.get_animation(an).duplicate() as Animation
			a.loop_mode = Animation.LOOP_LINEAR if an in LOOPS else Animation.LOOP_NONE
			_lib.add_animation(an, a)
		r.free()
	return _lib


## 표준 이름(idle walk run attack hit block cast death) → 이 외형에서 쓸 KayKit 동작 이름
static func resolve(look_: Dictionary, std: String) -> String:
	var w: String = Look.WEAPONS[look_["s"]["weapon"]]
	var two := w in ["sword_2handed", "axe_2handed"]
	match std:
		"idle":
			if two: return "Melee_2H_Idle"
			if w == "bow": return "Ranged_Bow_Idle"
			return "Idle_A"
		"walk": return "Walking_A"
		"run": return "Running_HoldingBow" if w == "bow" else "Running_A"
		"hit": return "Hit_A"
		"hit2": return "Hit_B"
		"block": return "Melee_Block"
		"death": return "Death_A"
		"cast": return "Ranged_Magic_Spellcasting"
		"attack":
			if w == "bow": return "Ranged_Bow_Release"
			if w == "crossbow_2handed": return "Ranged_2H_Shoot"
			if w in ["staff", "wand"]: return "Ranged_Magic_Shoot"
			if two: return "Melee_2H_Attack_Chop"
			if w == "dagger": return "Melee_1H_Attack_Stab"
			if w == "":
				return "Melee_Unarmed_Attack_Punch_A"
			return "Melee_1H_Attack_Chop"
	return std


static func len_for(look_: Dictionary, std: String) -> float:
	return lib().get_animation(resolve(Look.sanitize(look_), std)).length


func anim_len(std: String) -> float:
	return len_for(look, std)


func _init() -> void:
	if _toon == null:
		_toon = load("res://dev/pilot3d/toon_tex.gdshader")
		_outline = load("res://dev/pilot3d/outline.gdshader")
	mat = ShaderMaterial.new()
	mat.shader = _toon
	hull = ShaderMaterial.new()
	hull.shader = _outline
	mat.next_pass = hull
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	player.add_animation_library("", lib())
	player.animation_finished.connect(_on_finished)
	apply_look(Look.default_look())


func _ready() -> void:
	player.speed_scale = _speed
	player.play(resolve(look, cur_anim))
	if _pending_t >= 0.0:
		player.seek(_pending_t, true)
		player.advance(0.0)


func _build_body(idx: int) -> void:
	if model != null:
		remove_child(model)
		model.queue_free()
		model = null
	_attach.clear()
	var t := _template(Look.BODIES[idx])
	model = (t["root"] as Node).duplicate() as Node3D
	model.name = "Model"
	add_child(model)
	skel = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_scale = TARGET_H / float(t["height"])
	scale = Vector3.ONE * _scale
	mat.set_shader_parameter("albedo_tex", t["tex"])
	mat.set_shader_parameter("tex_levels", tex_levels_default)
	mat.set_shader_parameter("cell_lum", t["lum"])
	for m in model.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = mat
	_parts.clear()
	for m in model.find_children("*", "MeshInstance3D", true, false):
		_parts.append(m)
	_merged = null
	player.root_node = NodePath("../Model")
	_body = idx
	for sl in ["weapon", "shield"]:
		var ba := BoneAttachment3D.new()
		ba.name = "Socket_" + sl
		skel.add_child(ba)
		ba.bone_name = "handslot.r" if sl == "weapon" else "handslot.l"
		_attach[sl] = ba
	set_style({"outline_width": _outline_world})


func apply_look(p_look: Dictionary) -> void:
	look = Look.sanitize(p_look)
	var bi: int = look["s"]["body"]
	if bi != _body:
		_build_body(bi)
	for m in _parts:
		var mi := m as MeshInstance3D
		var nm := String(mi.name)
		var show := true
		for hp in HELM_PARTS:
			if nm.ends_with("_" + hp) or nm.ends_with(hp):
				show = look["s"]["helm"] == 1
		if nm.ends_with("Cape"):
			show = look["s"]["cape"] == 1
		mi.visible = show
	if merge_meshes:
		_rebuild_merged()
	var slot_names := {"weapon": Look.WEAPONS[look["s"]["weapon"]], "shield": Look.SHIELDS[look["s"]["shield"]]}
	for sl: String in slot_names.keys():
		var ba: BoneAttachment3D = _attach[sl]
		for ch in ba.get_children():
			ch.queue_free()
		var pn: String = slot_names[sl]
		if pn != "":
			var inst := (_prop(pn) as Node).duplicate() as Node3D
			for m in inst.find_children("*", "MeshInstance3D", true, false):
				_smooth_mesh(m as MeshInstance3D)
				(m as MeshInstance3D).material_override = mat
			ba.add_child(inst)
	# 색 바꾸기
	var roles: Dictionary = Look.ROLES[Look.BODIES[bi]]
	var cr := PackedFloat32Array()
	cr.resize(32)
	cr.fill(-1.0)
	var rn := ["skin", "hair", "c1", "c2", "metal"]
	for ri in 5:
		if ri == 4 and look["c"]["metal"] == 0:
			continue
		for cell: Array in roles.get(rn[ri], []):
			cr[int(cell[0]) + int(cell[1]) * 8] = float(ri)
	var cp: Array = Look.CLOTH[look["c"]["cloth"]]
	mat.set_shader_parameter("cell_role", cr)
	mat.set_shader_parameter("role_col", PackedColorArray([Look.SKIN[look["c"]["skin"]], Look.HAIR[look["c"]["hair"]], cp[0], cp[1], Look.METAL[look["c"]["metal"]]]))
	mat.set_shader_parameter("use_roles", _have_role)
	if is_inside_tree():
		_replay()


func _replay() -> void:
	var cur := player.current_animation_position
	var was := cur_anim
	player.play(resolve(look, was))


## 같은 모양의 변수 이름 (p3_char.gd 와 호환) + 색 바꾸기 끄기 · 텍스처 단계 끊기
func set_style(d: Dictionary) -> void:
	for k: String in d.keys():
		if k == "outline_width":
			_outline_world = d[k]
			hull.set_shader_parameter("width", float(d[k]) / _scale)
		elif k == "outline_color":
			hull.set_shader_parameter("line_color", d[k])
		elif k == "outline_on":
			mat.next_pass = hull if d[k] else null
		elif k == "use_roles":
			_have_role = d[k]
			mat.set_shader_parameter("use_roles", d[k])
		else:
			mat.set_shader_parameter(k, d[k])


func set_dir(d: int) -> void:
	dir = posmod(d, 8)
	rotation.y = float(dir) * PI / 4.0


func play(std: String, speed: float = 1.0, phase: float = -1.0) -> void:
	cur_anim = std
	_speed = speed
	_pending_t = phase
	if is_inside_tree():
		player.speed_scale = speed
		player.play(resolve(look, std))
		if phase >= 0.0:
			player.seek(phase, true)


func set_manual(on: bool) -> void:
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if on else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE


func pose_at(std: String, t: float) -> void:
	cur_anim = std
	_pending_t = t
	if is_inside_tree():
		var rn := resolve(look, std)
		if player.current_animation != rn:
			player.play(rn)
		player.seek(t, true)
		player.advance(0.0)


func _on_finished(an: StringName) -> void:
	anim_done.emit(String(an))
	if auto_return and cur_anim in ["attack", "hit", "hit2", "cast"]:
		play("idle")


## 보이는 부분(머리·몸·팔·다리·투구·망토…)을 하나의 스킨 메시로 합침 — 같은 뼈대·같은 재질이라 그대로 합쳐짐
func _rebuild_merged() -> void:
	if _merged != null:
		_merged.queue_free()
		_merged = null
	var V := PackedVector3Array()
	var N := PackedVector3Array()
	var T := PackedFloat32Array()
	var U := PackedVector2Array()
	var B := PackedInt32Array()
	var W := PackedFloat32Array()
	var I := PackedInt32Array()
	var skin: Skin = null
	for m in _parts:
		var mi := m as MeshInstance3D
		if not mi.visible:
			continue
		mi.visible = false
		var arr: Array = mi.mesh.surface_get_arrays(0)
		var off := V.size()
		V.append_array(arr[Mesh.ARRAY_VERTEX])
		N.append_array(arr[Mesh.ARRAY_NORMAL])
		T.append_array(arr[Mesh.ARRAY_TANGENT])
		U.append_array(arr[Mesh.ARRAY_TEX_UV])
		B.append_array(arr[Mesh.ARRAY_BONES])
		W.append_array(arr[Mesh.ARRAY_WEIGHTS])
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for k in idx.size():
			I.append(idx[k] + off)
		skin = mi.skin
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = V
	arrays[Mesh.ARRAY_NORMAL] = N
	arrays[Mesh.ARRAY_TANGENT] = T
	arrays[Mesh.ARRAY_TEX_UV] = U
	arrays[Mesh.ARRAY_BONES] = B
	arrays[Mesh.ARRAY_WEIGHTS] = W
	arrays[Mesh.ARRAY_INDEX] = I
	var nm := ArrayMesh.new()
	nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	nm.custom_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 5, 4))
	_merged = MeshInstance3D.new()
	_merged.name = "Merged"
	_merged.mesh = nm
	_merged.skin = skin
	_merged.skeleton = NodePath("..")
	_merged.material_override = mat
	skel.add_child(_merged)
