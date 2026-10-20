extends RefCounted
## 부품 목록 — 임시 사람용 기본 도형(구·캡슐·상자·원통)으로 만든 부품 모음
##  나중에 glTF 부품(머리·옷·무기 .glb) 으로 교체할 때도 같은 슬롯 이름·번호를 씀 (docs/customize/pilot3d-notes.md)
##  조각(piece): {s: 모양 s/c/b/y, ch: 색 채널, p: 위치, d: 크기(지름 기준), b: 붙을 뼈(비면 소켓 부착물), r: 회전(도), t: 위쪽 반지름 비율(원통)}
##  좌표는 휴식 자세 모델 공간 (발바닥 0, +Z 앞, 왼쪽 +X). 소켓 부품(weapon·shield)은 손 뼈 기준 로컬 좌표.

const CH := {"skin": 0, "hair": 1, "c1": 2, "c2": 3, "metal": 4, "leather": 5, "wood": 6, "eye": 7, "white": 8, "blush": 9}

## 슬롯 → 소켓이면 true (BoneAttachment3D 로 붙임), 아니면 스킨 메시로 합침
const SOCKET_SLOTS := ["weapon", "shield"]
## 0번이 "없음" 인 슬롯
const OPTIONAL_SLOTS := ["helm", "cape", "weapon", "shield"]
const SLOT_ORDER := ["hair", "face", "top", "bottom", "shoes", "helm", "cape", "weapon", "shield"]
const SLOT_LABEL := {"hair": "머리", "face": "얼굴", "top": "윗옷", "bottom": "하의", "shoes": "신발", "helm": "투구·모자", "cape": "망토", "weapon": "무기", "shield": "방패"}

static var _db: Dictionary = {}
static var _cache: Dictionary = {}


static func P(s: String, ch: String, p: Vector3, d: Vector3, b: String, r: Vector3 = Vector3.ZERO, t: float = 1.0) -> Dictionary:
	return {"s": s, "ch": CH[ch], "p": p, "d": d, "b": b, "r": r, "t": t}


static func V(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


## 좌우 한 쌍
static func LR(s: String, ch: String, p: Vector3, d: Vector3, bl: String, br: String, r: Vector3 = Vector3.ZERO, t: float = 1.0) -> Array:
	return [P(s, ch, p, d, bl, r, t), P(s, ch, V(-p.x, p.y, p.z), d, br, V(r.x, -r.y, -r.z), t)]


static func base_body() -> Array:
	var a: Array = []
	a.append(P("s", "skin", V(0, 0.715, 0), V(0.33, 0.31, 0.32), "Head"))
	a.append(P("y", "skin", V(0, 0.57, 0), V(0.07, 0.07, 0.07), "Neck"))
	a.append(P("s", "skin", V(0, 0.31, 0), V(0.2, 0.13, 0.13), "Hips"))
	a.append(P("c", "skin", V(0, 0.43, 0), V(0.19, 0.25, 0.12), "Chest"))
	a += LR("c", "skin", V(0.15, 0.41, 0), V(0.065, 0.13, 0.065), "LeftUpperArm", "RightUpperArm")
	a += LR("c", "skin", V(0.15, 0.31, 0), V(0.06, 0.12, 0.06), "LeftLowerArm", "RightLowerArm")
	a += LR("s", "skin", V(0.15, 0.245, 0), V(0.065, 0.065, 0.065), "LeftHand", "RightHand")
	a += LR("c", "skin", V(0.07, 0.222, 0), V(0.085, 0.17, 0.085), "LeftUpperLeg", "RightUpperLeg")
	a += LR("c", "skin", V(0.07, 0.09, 0), V(0.075, 0.16, 0.075), "LeftLowerLeg", "RightLowerLeg")
	a += LR("b", "skin", V(0.07, 0.03, 0.02), V(0.075, 0.05, 0.13), "LeftFoot", "RightFoot")
	return a


static func _build_db() -> Dictionary:
	var db := {}
	# ── 머리 ──
	var cap := P("s", "hair", V(0, 0.745, -0.02), V(0.355, 0.30, 0.345), "Head")
	var fringe := P("s", "hair", V(0, 0.79, 0.09), V(0.30, 0.10, 0.12), "Head")
	db["hair"] = [
		{"name": "짧은 머리", "pieces": [cap, fringe]},
		{"name": "긴 머리", "pieces": [cap, fringe, P("c", "hair", V(0, 0.60, -0.115), V(0.27, 0.36, 0.12), "Head")]},
		{"name": "뾰족 머리", "pieces": [P("s", "hair", V(0, 0.75, -0.015), V(0.345, 0.27, 0.33), "Head"),
			P("y", "hair", V(0, 0.9, 0), V(0.09, 0.15, 0.09), "Head", V(0, 0, 0), 0.0),
			P("y", "hair", V(0.1, 0.875, -0.01), V(0.09, 0.14, 0.09), "Head", V(0, 0, -35), 0.0),
			P("y", "hair", V(-0.1, 0.875, -0.01), V(0.09, 0.14, 0.09), "Head", V(0, 0, 35), 0.0),
			P("y", "hair", V(0, 0.87, -0.11), V(0.09, 0.14, 0.09), "Head", V(-40, 0, 0), 0.0),
			P("y", "hair", V(0, 0.865, 0.1), V(0.09, 0.12, 0.09), "Head", V(40, 0, 0), 0.0)]},
		{"name": "쪽 머리", "pieces": [cap, fringe, P("s", "hair", V(0, 0.9, -0.07), V(0.14, 0.13, 0.14), "Head"),
			P("c", "hair", V(0, 0.68, -0.17), V(0.07, 0.22, 0.07), "Head", V(15, 0, 0))]},
	]
	# ── 얼굴 ──
	db["face"] = [
		{"name": "점눈", "pieces": LR("s", "eye", V(0.065, 0.705, 0.148), V(0.04, 0.05, 0.03), "Head", "Head") + [P("b", "eye", V(0, 0.645, 0.152), V(0.04, 0.012, 0.02), "Head")]},
		{"name": "날카로운 눈", "pieces": LR("b", "eye", V(0.065, 0.703, 0.15), V(0.055, 0.022, 0.03), "Head", "Head", V(0, 0, 14))
			+ LR("b", "eye", V(0.07, 0.742, 0.147), V(0.055, 0.01, 0.03), "Head", "Head", V(0, 0, 14)) + [P("b", "eye", V(0, 0.642, 0.153), V(0.05, 0.012, 0.02), "Head")]},
		{"name": "큰 눈", "pieces": LR("s", "white", V(0.065, 0.705, 0.145), V(0.065, 0.075, 0.03), "Head", "Head")
			+ LR("s", "eye", V(0.065, 0.702, 0.157), V(0.04, 0.055, 0.02), "Head", "Head")
			+ LR("s", "blush", V(0.105, 0.66, 0.125), V(0.045, 0.028, 0.02), "Head", "Head") + [P("b", "eye", V(0, 0.642, 0.153), V(0.03, 0.012, 0.02), "Head")]},
		{"name": "웃는 눈", "pieces": LR("b", "eye", V(0.065, 0.705, 0.152), V(0.055, 0.013, 0.02), "Head", "Head")
			+ [P("b", "eye", V(0, 0.644, 0.153), V(0.07, 0.013, 0.02), "Head")]},
	]
	# ── 윗옷 ──
	var belt := P("b", "leather", V(0, 0.335, 0), V(0.235, 0.035, 0.165), "Spine")
	db["top"] = [
		{"name": "튜닉", "pieces": [P("c", "c1", V(0, 0.42, 0), V(0.225, 0.26, 0.155), "Chest"), belt,
			P("b", "c2", V(0, 0.45, 0.076), V(0.07, 0.07, 0.02), "Chest")]
			+ LR("s", "c1", V(0.15, 0.46, 0), V(0.1, 0.1, 0.1), "LeftUpperArm", "RightUpperArm")},
		{"name": "로브", "pieces": [P("y", "c1", V(0, 0.33, 0), V(0.30, 0.44, 0.22), "Spine", V(0, 0, 0), 0.66),
			P("b", "c2", V(0, 0.385, 0), V(0.265, 0.04, 0.195), "Spine"), P("s", "c2", V(0, 0.545, -0.01), V(0.17, 0.06, 0.14), "Chest")]
			+ LR("c", "c1", V(0.15, 0.41, 0), V(0.085, 0.14, 0.085), "LeftUpperArm", "RightUpperArm")
			+ LR("c", "c1", V(0.15, 0.31, 0), V(0.08, 0.13, 0.08), "LeftLowerArm", "RightLowerArm")
			+ LR("y", "c2", V(0.15, 0.255, 0), V(0.085, 0.03, 0.085), "LeftLowerArm", "RightLowerArm")},
		{"name": "갑옷", "pieces": [P("c", "metal", V(0, 0.43, 0), V(0.235, 0.27, 0.165), "Chest"), belt,
			P("y", "c2", V(0, 0.29, 0), V(0.24, 0.11, 0.17), "Hips", V(0, 0, 0), 0.8)]
			+ LR("s", "metal", V(0.155, 0.49, 0), V(0.125, 0.09, 0.115), "LeftUpperArm", "RightUpperArm")
			+ LR("c", "c2", V(0.15, 0.41, 0), V(0.072, 0.13, 0.072), "LeftUpperArm", "RightUpperArm")},
	]
	# ── 하의 ──
	db["bottom"] = [
		{"name": "바지", "pieces": [P("b", "c2", V(0, 0.30, 0), V(0.2, 0.1, 0.135), "Hips")]
			+ LR("c", "c2", V(0.07, 0.222, 0), V(0.097, 0.17, 0.097), "LeftUpperLeg", "RightUpperLeg")
			+ LR("c", "c2", V(0.07, 0.095, 0), V(0.083, 0.165, 0.083), "LeftLowerLeg", "RightLowerLeg")},
		{"name": "치마", "pieces": [P("y", "c2", V(0, 0.26, 0), V(0.27, 0.15, 0.23), "Hips", V(0, 0, 0), 0.55)]
			+ LR("c", "c1", V(0.07, 0.085, 0), V(0.082, 0.14, 0.082), "LeftLowerLeg", "RightLowerLeg")},
		{"name": "경갑", "pieces": [P("b", "c2", V(0, 0.30, 0), V(0.2, 0.1, 0.135), "Hips")]
			+ LR("c", "c2", V(0.07, 0.222, 0), V(0.097, 0.17, 0.097), "LeftUpperLeg", "RightUpperLeg")
			+ LR("c", "metal", V(0.07, 0.095, 0), V(0.09, 0.16, 0.09), "LeftLowerLeg", "RightLowerLeg")
			+ LR("s", "metal", V(0.07, 0.16, 0.04), V(0.075, 0.075, 0.07), "LeftLowerLeg", "RightLowerLeg")},
	]
	# ── 신발 ──
	db["shoes"] = [
		{"name": "장화", "pieces": LR("c", "leather", V(0.07, 0.072, 0), V(0.093, 0.11, 0.093), "LeftLowerLeg", "RightLowerLeg")
			+ LR("b", "leather", V(0.07, 0.028, 0.026), V(0.085, 0.056, 0.15), "LeftFoot", "RightFoot")},
		{"name": "단화", "pieces": LR("b", "c2", V(0.07, 0.026, 0.024), V(0.082, 0.052, 0.145), "LeftFoot", "RightFoot")
			+ LR("s", "c2", V(0.07, 0.03, 0.09), V(0.08, 0.055, 0.07), "LeftFoot", "RightFoot")},
		{"name": "철제 신발", "pieces": LR("b", "metal", V(0.07, 0.03, 0.028), V(0.09, 0.06, 0.16), "LeftFoot", "RightFoot")
			+ LR("c", "metal", V(0.07, 0.06, 0), V(0.088, 0.07, 0.088), "LeftLowerLeg", "RightLowerLeg")},
	]
	# ── 투구·모자 (0 = 없음) ──
	db["helm"] = [
		null,
		{"name": "두건", "pieces": [P("s", "c2", V(0, 0.755, -0.01), V(0.375, 0.30, 0.355), "Head"), P("s", "c2", V(0, 0.8, 0.095), V(0.31, 0.07, 0.1), "Head")]},
		{"name": "철투구", "pieces": [P("s", "metal", V(0, 0.76, -0.005), V(0.375, 0.29, 0.36), "Head"), P("b", "metal", V(0, 0.705, 0.17), V(0.03, 0.11, 0.02), "Head"),
			P("c", "c1", V(0, 0.915, -0.03), V(0.045, 0.22, 0.045), "Head", V(90, 0, 0))]},
		{"name": "마법사 모자", "pieces": [P("y", "c2", V(0, 0.81, 0), V(0.42, 0.025, 0.42), "Head"), P("y", "c1", V(0, 0.84, 0), V(0.27, 0.035, 0.27), "Head"),
			P("y", "c2", V(0, 0.94, -0.012), V(0.25, 0.2, 0.25), "Head", V(-8, 0, 0), 0.0)]},
	]
	# ── 망토 (0 = 없음) ──
	db["cape"] = [
		null,
		{"name": "짧은 망토", "pieces": [P("b", "c2", V(0, 0.40, -0.095), V(0.25, 0.30, 0.025), "Chest", V(6, 0, 0)), P("s", "metal", V(0, 0.54, 0.055), V(0.045, 0.045, 0.03), "Chest")]},
		{"name": "긴 망토", "pieces": [P("b", "c2", V(0, 0.30, -0.105), V(0.27, 0.5, 0.025), "Chest", V(5, 0, 0)), P("b", "c1", V(0, 0.54, -0.095), V(0.2, 0.05, 0.05), "Chest"),
			P("s", "metal", V(0, 0.54, 0.055), V(0.045, 0.045, 0.03), "Chest")]},
	]
	# ── 무기 (손 뼈 로컬: 쥔 곳이 원점, +Y 가 날 쪽) ──
	db["weapon"] = [
		null,
		{"name": "검", "pieces": [P("c", "leather", V(0, 0, 0), V(0.032, 0.1, 0.032), ""), P("b", "metal", V(0, 0.06, 0), V(0.12, 0.022, 0.04), ""),
			P("b", "metal", V(0, 0.24, 0), V(0.048, 0.3, 0.014), ""), P("y", "metal", V(0, 0.415, 0), V(0.048, 0.05, 0.014), "", V(0, 0, 0), 0.0), P("s", "metal", V(0, -0.055, 0), V(0.045, 0.045, 0.045), "")]},
		{"name": "지팡이", "pieces": [P("c", "wood", V(0, 0.16, 0), V(0.028, 0.72, 0.028), ""), P("s", "c1", V(0, 0.54, 0), V(0.1, 0.1, 0.1), ""),
			P("y", "metal", V(0, 0.48, 0), V(0.075, 0.02, 0.075), "")]},
		{"name": "도끼", "pieces": [P("c", "wood", V(0, 0.14, 0), V(0.032, 0.56, 0.032), ""), P("b", "metal", V(0, 0.34, 0.055), V(0.03, 0.16, 0.1), ""),
			P("s", "metal", V(0, 0.34, 0.11), V(0.024, 0.2, 0.1), "")]},
		{"name": "철퇴", "pieces": [P("c", "wood", V(0, 0.1, 0), V(0.032, 0.42, 0.032), ""), P("s", "metal", V(0, 0.34, 0), V(0.11, 0.11, 0.11), ""),
			P("y", "metal", V(0, 0.4, 0), V(0.04, 0.05, 0.04), "", V(0, 0, 0), 0.0), P("y", "metal", V(0, 0.34, 0.06), V(0.04, 0.05, 0.04), "", V(90, 0, 0), 0.0),
			P("y", "metal", V(0, 0.34, -0.06), V(0.04, 0.05, 0.04), "", V(-90, 0, 0), 0.0)]},
	]
	# ── 방패 (왼손, 바깥면이 +X) ──
	db["shield"] = [
		null,
		{"name": "둥근 방패", "pieces": [P("y", "wood", V(0.045, 0.02, 0.02), V(0.23, 0.03, 0.23), "", V(0, 0, 90)), P("y", "metal", V(0.035, 0.02, 0.02), V(0.245, 0.02, 0.245), "", V(0, 0, 90)),
			P("s", "metal", V(0.065, 0.02, 0.02), V(0.05, 0.07, 0.07), "")]},
		{"name": "연 방패", "pieces": [P("s", "metal", V(0.04, 0.0, 0.02), V(0.03, 0.31, 0.22), ""), P("s", "c1", V(0.05, 0.0, 0.02), V(0.026, 0.27, 0.19), ""),
			P("b", "c2", V(0.062, 0.01, 0.02), V(0.012, 0.22, 0.03), ""), P("b", "c2", V(0.062, 0.03, 0.02), V(0.012, 0.03, 0.15), "")]},
		{"name": "작은 방패", "pieces": [P("y", "metal", V(0.05, 0.03, 0.03), V(0.15, 0.03, 0.15), "", V(0, 0, 90)), P("s", "c1", V(0.065, 0.03, 0.03), V(0.04, 0.07, 0.07), "")]},
	]
	return db


static func db() -> Dictionary:
	if _db.is_empty():
		_db = _build_db()
	return _db


## 슬롯 번호 개수 (번호 범위 0..count-1)
static func count(slot: String) -> int:
	return (db()[slot] as Array).size()


static func part_name(slot: String, idx: int) -> String:
	var v: Variant = (db()[slot] as Array)[idx]
	if v == null:
		return "없음"
	return str((v as Dictionary)["name"])


# ── 도형 → 메시 배열 ──
static func _prim(shape: String) -> Mesh:
	match shape:
		"s":
			var m := SphereMesh.new()
			m.radius = 0.5
			m.height = 1.0
			m.radial_segments = 10
			m.rings = 5
			return m
		"c":
			var m2 := CapsuleMesh.new()
			m2.radius = 0.5
			m2.height = 1.8
			m2.rings = 1
			m2.radial_segments = 8
			m2.rings = 2
			return m2
		"b":
			return BoxMesh.new()
		_:
			var m3 := CylinderMesh.new()
			m3.radial_segments = 10
			m3.rings = 1
			return m3


## 조각 목록 → 배열 묶음 (스키닝이 있으면 bones/weights 포함)
static func build_arrays(pieces: Array, skel: Skeleton3D, skinned: bool) -> Dictionary:
	var V_ := PackedVector3Array()
	var N := PackedVector3Array()
	var T := PackedFloat32Array()
	var C := PackedColorArray()
	var B := PackedInt32Array()
	var W := PackedFloat32Array()
	var I := PackedInt32Array()
	for pc: Dictionary in pieces:
		var shape: String = pc["s"]
		var mesh := _prim(shape)
		var d: Vector3 = pc["d"]
		var scale := d
		if shape == "c":
			scale = Vector3(d.x, d.y / 1.8, d.z)   # 캡슐 기본 높이 1.8 · 지름 1
		elif shape == "b":
			scale = d
		elif shape == "y":
			(mesh as CylinderMesh).top_radius = 0.5 * float(pc["t"])
			(mesh as CylinderMesh).bottom_radius = 0.5
			scale = d
		else:
			scale = d
		var rot: Vector3 = pc["r"]
		var basis := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)), EULER_ORDER_YXZ)
		var xf := Transform3D(basis * Basis.from_scale(scale), pc["p"])
		var nb := (basis * Basis.from_scale(scale)).inverse().transposed()
		var arr: Array = mesh.get_mesh_arrays()
		var av: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var an: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ai: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var base := V_.size()
		var chn: int = pc["ch"]
		var col := Color(float(chn) / 16.0, 0.0 if (chn == 7 or chn == 9) else 1.0, 0, 1)
		var bone_idx := 0
		if skinned:
			bone_idx = skel.find_bone(pc["b"]) if pc["b"] != "" else 0
		var center: Vector3 = pc["p"]
		for i in av.size():
			var wp := xf * av[i]
			V_.append(wp)
			N.append((nb * an[i]).normalized())
			var sd := (wp - center).normalized()
			T.append(sd.x)
			T.append(sd.y)
			T.append(sd.z)
			T.append(1.0)
			C.append(col)
			if skinned:
				B.append(bone_idx)
				B.append(0)
				B.append(0)
				B.append(0)
				W.append(1.0)
				W.append(0.0)
				W.append(0.0)
				W.append(0.0)
		for j in ai.size():
			I.append(ai[j] + base)
	return {"v": V_, "n": N, "t": T, "c": C, "b": B, "w": W, "i": I}


## 배열 묶음 여러 개를 하나로 합침
static func merge(list: Array) -> Dictionary:
	var V_ := PackedVector3Array()
	var N := PackedVector3Array()
	var T := PackedFloat32Array()
	var C := PackedColorArray()
	var B := PackedInt32Array()
	var W := PackedFloat32Array()
	var I := PackedInt32Array()
	for a: Dictionary in list:
		var off := V_.size()
		V_.append_array(a["v"])
		N.append_array(a["n"])
		T.append_array(a["t"])
		C.append_array(a["c"])
		B.append_array(a["b"])
		W.append_array(a["w"])
		var idx: PackedInt32Array = a["i"]
		for k in idx.size():
			I.append(idx[k] + off)
	return {"v": V_, "n": N, "t": T, "c": C, "b": B, "w": W, "i": I}


static func to_mesh(a: Dictionary, skinned: bool) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = a["v"]
	arrays[Mesh.ARRAY_NORMAL] = a["n"]
	arrays[Mesh.ARRAY_TANGENT] = a["t"]
	arrays[Mesh.ARRAY_COLOR] = a["c"]
	if skinned:
		arrays[Mesh.ARRAY_BONES] = a["b"]
		arrays[Mesh.ARRAY_WEIGHTS] = a["w"]
	arrays[Mesh.ARRAY_INDEX] = a["i"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.custom_aabb = AABB(Vector3(-1, -0.2, -1), Vector3(2, 1.6, 2))
	return m


## 슬롯/번호의 배열 (캐시). 스킨 부품은 skel 이 필요 (뼈 번호 찾기용 — 뼈 목록은 모든 캐릭터가 같음)
static func part_arrays(slot: String, idx: int, skel: Skeleton3D) -> Dictionary:
	var key := "%s:%d" % [slot, idx]
	if _cache.has(key):
		return _cache[key]
	var v: Variant = (db()[slot] as Array)[idx]
	if v == null:
		return {}
	var skinned := not (slot in SOCKET_SLOTS)
	var a := build_arrays((v as Dictionary)["pieces"], skel, skinned)
	_cache[key] = a
	return a


static func base_arrays(skel: Skeleton3D) -> Dictionary:
	if _cache.has("base"):
		return _cache["base"]
	var a := build_arrays(base_body(), skel, true)
	_cache["base"] = a
	return a
