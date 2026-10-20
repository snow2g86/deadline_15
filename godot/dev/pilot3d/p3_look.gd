extends RefCounted
## 외형 저장 형식 (look) — 가볍고 사람이 읽을 수 있는 딕셔너리, 문자열로도 묶어 저장 가능
##   {"v": 1, "s": {"hair":2,"face":1,"top":0,"bottom":1,"shoes":0,"helm":0,"cape":1,"weapon":1,"shield":2},
##    "c": {"skin":1,"hair":4,"cloth":3,"metal":0}}
##   s = 슬롯별 부품 번호 (helm·cape·weapon·shield 는 0 = 없음), c = 색 번호 (아래 표). v = 형식 버전 (더 늘려도 옛 데이터 읽기 가능)
##   문자열: "1:2.1.0.1.0.0.1.1.2|1.4.3.0"  (슬롯 순서 SLOT_ORDER, 색 순서 COL_ORDER)

const Parts := preload("res://dev/pilot3d/p3_parts.gd")
const COL_ORDER := ["skin", "hair", "cloth", "metal"]

const SKIN := [Color("f1c9a5"), Color("e0a98a"), Color("c68a62"), Color("9a6240"), Color("6c4228"), Color("f3d9c4")]
const HAIR := [Color("2a2420"), Color("5a3a22"), Color("8a5a2c"), Color("d1a64a"), Color("a8442a"), Color("c9c4bc"), Color("2e4a6e"), Color("5a7a3c")]
## 옷 (주색, 보조색)
const CLOTH := [
	[Color("a83a3a"), Color("3a2e2a")], [Color("3a5ea8"), Color("c9a24a")], [Color("4a7a3a"), Color("6a4a2c")], [Color("7a4a9a"), Color("d8d0c0")],
	[Color("2e2e36"), Color("a83a3a")], [Color("c9a24a"), Color("3a4a7a")], [Color("c0bcb4"), Color("4a5a6a")], [Color("b0642a"), Color("2e3a2e")],
]
const METAL := [Color("a9afb8"), Color("b9894a"), Color("d6b24a"), Color("6a7280")]
const LEATHER := Color("6a4429")
const WOOD := Color("8a6038")


static func default_look() -> Dictionary:
	return {"v": 1, "s": {"hair": 0, "face": 0, "top": 0, "bottom": 0, "shoes": 0, "helm": 0, "cape": 0, "weapon": 1, "shield": 0},
		"c": {"skin": 1, "hair": 1, "cloth": 0, "metal": 0}}


static func col_count(k: String) -> int:
	match k:
		"skin": return SKIN.size()
		"hair": return HAIR.size()
		"cloth": return CLOTH.size()
	return METAL.size()


## 값이 범위 밖이어도 안전하게 고침 (옛 버전 데이터·깨진 저장도 읽힘)
static func sanitize(look: Dictionary) -> Dictionary:
	var out := default_look()
	var s: Dictionary = look.get("s", {})
	for slot: String in Parts.SLOT_ORDER:
		var n: int = Parts.count(slot)
		out["s"][slot] = clampi(int(s.get(slot, out["s"][slot])), 0, n - 1)
	var c: Dictionary = look.get("c", {})
	for k: String in COL_ORDER:
		out["c"][k] = clampi(int(c.get(k, 0)), 0, col_count(k) - 1)
	return out


## 무작위 외형 — 장비(무기·방패·투구·망토)는 있을 확률을 둠
static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var out := default_look()
	for slot: String in Parts.SLOT_ORDER:
		var n: int = Parts.count(slot)
		if slot in Parts.OPTIONAL_SLOTS:
			var p := 0.6 if slot == "weapon" else 0.45
			out["s"][slot] = (1 + rng.randi() % (n - 1)) if rng.randf() < p else 0
		else:
			out["s"][slot] = rng.randi() % n
	for k: String in COL_ORDER:
		out["c"][k] = rng.randi() % col_count(k)
	return out


static func pack(look: Dictionary) -> String:
	var a: PackedStringArray = []
	for slot: String in Parts.SLOT_ORDER:
		a.append(str(look["s"][slot]))
	var b: PackedStringArray = []
	for k: String in COL_ORDER:
		b.append(str(look["c"][k]))
	return "%d:%s|%s" % [int(look.get("v", 1)), ".".join(a), ".".join(b)]


static func unpack(text: String) -> Dictionary:
	var out := default_look()
	var vs := text.split(":")
	if vs.size() < 2:
		return out
	var parts := vs[1].split("|")
	var sl := parts[0].split(".")
	for i in mini(sl.size(), Parts.SLOT_ORDER.size()):
		out["s"][Parts.SLOT_ORDER[i]] = int(sl[i])
	if parts.size() > 1:
		var cl := parts[1].split(".")
		for i in mini(cl.size(), COL_ORDER.size()):
			out["c"][COL_ORDER[i]] = int(cl[i])
	return sanitize(out)


## 재질 파라미터로 변환 (셰이더 uniform 이름 → Color)
static func colors(look: Dictionary) -> Dictionary:
	var cp: Array = CLOTH[look["c"]["cloth"]]
	return {"c_skin": SKIN[look["c"]["skin"]], "c_hair": HAIR[look["c"]["hair"]], "c_cloth1": cp[0], "c_cloth2": cp[1], "c_metal": METAL[look["c"]["metal"]]}
