extends RefCounted
## 임시 사람 뼈대 — glTF 휴머노이드(Mixamo·VRM 비슷한) 이름을 써서 나중에 실제 모델과 이름 매핑이 쉽게 함
##  모델은 +Z 를 봄 (glTF 규약), 캐릭터의 왼쪽 = +X. 휴식 자세는 팔다리가 -Y 로 늘어진 자세.
##  키 (발바닥 0 ~ 머리끝 0.86 유닛) = 화면 몸 높이 50px 에 가깝게 (기존 FIG_H = 50)

## [이름, 부모(없으면 ""), 부모 기준 위치]
const BONES := [
	["Hips", "", Vector3(0, 0.30, 0)],
	["Spine", "Hips", Vector3(0, 0.06, 0)],
	["Chest", "Spine", Vector3(0, 0.10, 0)],
	["Neck", "Chest", Vector3(0, 0.08, 0)],
	["Head", "Neck", Vector3(0, 0.04, 0)],
	["LeftUpperArm", "Chest", Vector3(0.15, 0.0, 0)],
	["LeftLowerArm", "LeftUpperArm", Vector3(0, -0.10, 0)],
	["LeftHand", "LeftLowerArm", Vector3(0, -0.10, 0)],
	["RightUpperArm", "Chest", Vector3(-0.15, 0.0, 0)],
	["RightLowerArm", "RightUpperArm", Vector3(0, -0.10, 0)],
	["RightHand", "RightLowerArm", Vector3(0, -0.10, 0)],
	["LeftUpperLeg", "Hips", Vector3(0.07, -0.01, 0)],
	["LeftLowerLeg", "LeftUpperLeg", Vector3(0, -0.135, 0)],
	["LeftFoot", "LeftLowerLeg", Vector3(0, -0.13, 0)],
	["RightUpperLeg", "Hips", Vector3(-0.07, -0.01, 0)],
	["RightLowerLeg", "RightUpperLeg", Vector3(0, -0.135, 0)],
	["RightFoot", "RightLowerLeg", Vector3(0, -0.13, 0)],
]

## 슬롯 부착점 (BoneAttachment3D) — 실제 모델에서는 뼈대 이름만 바꿔 주면 됨
const SOCKETS := {
	"weapon": {"bone": "RightHand", "pos": Vector3(0, -0.005, 0), "rot": Vector3(0, 0, 0)},
	"shield": {"bone": "LeftHand", "pos": Vector3(0.025, 0.0, 0.0), "rot": Vector3(0, 0, 0)},
}


static func bone_index(name: String) -> int:
	for i in BONES.size():
		if BONES[i][0] == name:
			return i
	return -1


## Skeleton3D 를 코드로 만든다 (이름 "Skeleton3D")
static func build_skeleton() -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	for b in BONES:
		sk.add_bone(b[0])
	for i in BONES.size():
		var b: Array = BONES[i]
		if b[1] != "":
			sk.set_bone_parent(i, sk.find_bone(b[1]))
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, b[2]))
	sk.reset_bone_poses()
	return sk
