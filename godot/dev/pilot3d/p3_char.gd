extends Node3D
## 3D 캐릭터 한 명 — 뼈대(Skeleton3D) 하나를 공유하는 스킨 메시(몸·머리·옷) + 손 소켓(BoneAttachment3D: 무기·방패)
##  look 딕셔너리(P3Look) 하나로 외형이 정해지고, 동작은 AnimationPlayer(idle·walk·attack·hit)
##  방향: face(dir 0..7) — 0 = +Z(+r, 화면 왼쪽 아래), 2 = +X(+c, 오른쪽 아래), 4 = -Z, 6 = -X (45° 간격)

const Rig := preload("res://dev/pilot3d/p3_rig.gd")
const Parts := preload("res://dev/pilot3d/p3_parts.gd")
const Look := preload("res://dev/pilot3d/p3_look.gd")
const Anims := preload("res://dev/pilot3d/p3_anims.gd")
const Iso := preload("res://dev/pilot3d/p3_iso.gd")

static var _toon: Shader
static var _outline: Shader
static var _lib: AnimationLibrary

signal anim_done(name: String)

var skel: Skeleton3D
var player: AnimationPlayer
var body_mi: MeshInstance3D
var mat: ShaderMaterial
var hull: ShaderMaterial
var look: Dictionary = {}
var dir: int = 0
var cur_anim: String = "idle"
var sockets: Dictionary = {}     # slot → BoneAttachment3D
var _sock_mi: Dictionary = {}    # slot → MeshInstance3D
var auto_return := true
## 가로(앞뒤·좌우) 굵기 배율 — 기존 2D 캐릭터가 더 통통해서 맞춤 (키는 그대로)
const CHUNK := 1.2


func _init() -> void:
	scale = Vector3(CHUNK, 1.0, CHUNK)
	if _toon == null:
		_toon = load("res://dev/pilot3d/toon.gdshader")
		_outline = load("res://dev/pilot3d/outline.gdshader")
	skel = Rig.build_skeleton()
	add_child(skel)
	if _lib == null:
		_lib = Anims.build_library(skel)
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	player.add_animation_library("", _lib)
	player.animation_finished.connect(_on_finished)
	mat = ShaderMaterial.new()
	mat.shader = _toon
	hull = ShaderMaterial.new()
	hull.shader = _outline
	mat.next_pass = hull
	mat.set_shader_parameter("c_leather", Look.LEATHER)
	mat.set_shader_parameter("c_wood", Look.WOOD)
	body_mi = MeshInstance3D.new()
	body_mi.name = "Outfit"
	body_mi.skeleton = NodePath("..")
	body_mi.material_override = mat
	skel.add_child(body_mi)
	body_mi.skin = skel.create_skin_from_rest_transforms()
	for slot: String in Parts.SOCKET_SLOTS:
		var sd: Dictionary = Rig.SOCKETS[slot]
		var ba := BoneAttachment3D.new()
		ba.name = "Socket_" + slot
		skel.add_child(ba)
		ba.bone_name = sd["bone"]
		var mi := MeshInstance3D.new()
		mi.material_override = mat
		mi.position = sd["pos"]
		mi.rotation_degrees = sd["rot"]
		ba.add_child(mi)
		sockets[slot] = ba
		_sock_mi[slot] = mi
	apply_look(Look.default_look())


var _pending_t := -1.0
var _speed := 1.0


func _ready() -> void:
	player.speed_scale = _speed
	player.play(cur_anim)
	if _pending_t >= 0.0:
		player.seek(_pending_t, true)
		player.advance(0.0)


func apply_look(p_look: Dictionary) -> void:
	look = Look.sanitize(p_look)
	var list: Array = [Parts.base_arrays(skel)]
	for slot: String in Parts.SLOT_ORDER:
		if slot in Parts.SOCKET_SLOTS:
			continue
		var a := Parts.part_arrays(slot, look["s"][slot], skel)
		if not a.is_empty():
			list.append(a)
	body_mi.mesh = Parts.to_mesh(Parts.merge(list), true)
	for slot: String in Parts.SOCKET_SLOTS:
		var a2 := Parts.part_arrays(slot, look["s"][slot], skel)
		var mi: MeshInstance3D = _sock_mi[slot]
		mi.mesh = null if a2.is_empty() else Parts.to_mesh(a2, false)
	var cols := Look.colors(look)
	for k: String in cols.keys():
		mat.set_shader_parameter(k, cols[k])


## 외곽선·명암 단계 같은 그림체 변수
static func len_for(_look: Dictionary, anim: String) -> float:
	return Anims.LEN[anim]


func set_style(d: Dictionary) -> void:
	for k: String in d.keys():
		if k == "outline_width":
			hull.set_shader_parameter("width", d[k])
		elif k == "outline_color":
			hull.set_shader_parameter("line_color", d[k])
		elif k == "outline_on":
			mat.next_pass = hull if d[k] else null
		else:
			mat.set_shader_parameter(k, d[k])


func set_dir(d: int) -> void:
	dir = posmod(d, 8)
	rotation.y = float(dir) * PI / 4.0


func play(name: String, speed: float = 1.0, phase: float = -1.0) -> void:
	cur_anim = name
	_speed = speed
	_pending_t = phase
	if is_inside_tree():
		player.speed_scale = speed
		player.play(name)
		if phase >= 0.0:
			player.seek(phase, true)


## 수동 진행 모드 (구워 두기·아틀라스용): 시각을 직접 지정해 자세를 만든다
func set_manual(on: bool) -> void:
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if on else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE


func pose_at(name: String, t: float) -> void:
	cur_anim = name
	_pending_t = t
	if is_inside_tree():
		if player.current_animation != name:
			player.play(name)
		player.seek(t, true)
		player.advance(0.0)


func _on_finished(name: StringName) -> void:
	anim_done.emit(String(name))
	if auto_return and (name == &"attack" or name == &"hit"):
		play("idle")
