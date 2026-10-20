extends RefCounted
## KayKit 모델용 외형 저장 형식 (v2) — 몸(머리·옷 통째)을 슬롯 하나로 보고, 투구·망토는 켜고 끄고, 무기·방패는 소품 번호
##   {"v":2, "s":{"body":2,"helm":1,"cape":1,"weapon":3,"shield":1}, "c":{"skin":1,"hair":4,"cloth":3,"metal":0}}   (metal 0 = 원래 색, 기사만 효과)
##   문자열: "2:2.1.1.3.1|1.4.3"
const BODIES := ["Knight", "Barbarian", "Mage", "Ranger", "Rogue", "Rogue_Hooded"]
const BODY_KO := ["기사", "야만전사", "마법사", "궁수", "도적", "후드 도적"]
const WEAPONS := ["", "sword_1handed", "sword_2handed", "axe_1handed", "axe_2handed", "dagger", "staff", "wand", "bow", "crossbow_2handed"]
const WEAPON_KO := ["없음", "한손검", "양손검", "한손도끼", "양손도끼", "단검", "지팡이", "마법봉", "활", "석궁"]
const SHIELDS := ["", "shield_round", "shield_round_color", "shield_badge", "shield_square", "shield_spikes"]
const SHIELD_KO := ["없음", "둥근", "둥근(색)", "문장", "사각", "가시"]
const SLOT_ORDER := ["body", "helm", "cape", "weapon", "shield"]
const COL_ORDER := ["skin", "hair", "cloth", "metal"]
## 몸마다 "색 바꾸기" 칸 목록 (아틀라스 칸 (가로,세로)) — 모델 안 칸 사용 분석으로 찾음 (tools/pilot3d 설명 참고)
##  skin: 피부 · hair: 머리카락 · c1: 옷 주색 · c2: 옷 보조색
const ROLES := {
	"Knight": {"skin": [[0, 0]], "hair": [[1, 0]], "c1": [[0, 1]], "c2": [[5, 0]], "metal": [[3, 0], [7, 0], [3, 1], [2, 1], [4, 0], [7, 1]]},
	"Barbarian": {"skin": [[0, 0]], "hair": [[1, 0]], "c1": [[6, 0], [5, 1]], "c2": [[6, 1]]},
	"Mage": {"skin": [[0, 0], [7, 2]], "hair": [[1, 0]], "c1": [[0, 1], [1, 1]], "c2": [[5, 0], [7, 1]]},
	"Ranger": {"skin": [[0, 0]], "hair": [[1, 0]], "c1": [[0, 1]], "c2": [[7, 0], [7, 2], [3, 2]]},
	"Rogue": {"skin": [[0, 0]], "hair": [[1, 0]], "c1": [[0, 1]], "c2": [[1, 1]]},
	"Rogue_Hooded": {"skin": [[0, 0]], "hair": [[1, 0]], "c1": [[0, 1]], "c2": [[1, 1]]},
}
const SKIN := [Color("f5bf9a"), Color("e0a98a"), Color("c68a62"), Color("9a6240"), Color("6c4228"), Color("f7dcc8")]
const HAIR := [Color("1b1918"), Color("5a3a22"), Color("8a5a2c"), Color("dcb06a"), Color("a8442a"), Color("c9c4bc"), Color("2e4a6e"), Color("5a7a3c")]
## 금속 칸 바꾸기 색 (0 = 원래 색 그대로)
const METAL := [Color("00000000"), Color("d6b24a"), Color("b0763c"), Color("5a6270")]
const CLOTH := [
	[Color("d32a30"), Color("b4582a")], [Color("247dbc"), Color("c9a24a")], [Color("00835a"), Color("6a4a2c")], [Color("7a4a9a"), Color("d8d0c0")],
	[Color("33333c"), Color("a83a3a")], [Color("c9a24a"), Color("3a4a7a")], [Color("a4195a"), Color("2e6c73")], [Color("b0642a"), Color("2e3a2e")],
]


static func default_look() -> Dictionary:
	return {"v": 2, "s": {"body": 0, "helm": 1, "cape": 1, "weapon": 1, "shield": 1}, "c": {"skin": 0, "hair": 3, "cloth": 0, "metal": 0}}


static func counts(slot: String) -> int:
	match slot:
		"body": return BODIES.size()
		"helm", "cape": return 2
		"weapon": return WEAPONS.size()
		"shield": return SHIELDS.size()
	return 1


static func col_count(k: String) -> int:
	match k:
		"skin": return SKIN.size()
		"hair": return HAIR.size()
		"metal": return METAL.size()
	return CLOTH.size()


static func sanitize(look: Dictionary) -> Dictionary:
	var out := default_look()
	var s: Dictionary = look.get("s", {})
	for slot: String in SLOT_ORDER:
		out["s"][slot] = clampi(int(s.get(slot, out["s"][slot])), 0, counts(slot) - 1)
	var c: Dictionary = look.get("c", {})
	for k: String in COL_ORDER:
		out["c"][k] = clampi(int(c.get(k, 0)), 0, col_count(k) - 1)
	return out


static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var out := default_look()
	out["s"]["body"] = rng.randi() % BODIES.size()
	out["s"]["helm"] = rng.randi() % 2
	out["s"]["cape"] = rng.randi() % 2
	out["s"]["weapon"] = 1 + rng.randi() % (WEAPONS.size() - 1)
	out["s"]["shield"] = (rng.randi() % SHIELDS.size()) if (rng.randf() < 0.5 and out["s"]["weapon"] in [1, 3, 5]) else 0
	for k: String in COL_ORDER:
		out["c"][k] = rng.randi() % col_count(k)
	return out


static func pack(look: Dictionary) -> String:
	var a: PackedStringArray = []
	for slot: String in SLOT_ORDER:
		a.append(str(look["s"][slot]))
	var b: PackedStringArray = []
	for k: String in COL_ORDER:
		b.append(str(look["c"][k]))
	return "2:%s|%s" % [".".join(a), ".".join(b)]


static func unpack(text: String) -> Dictionary:
	var out := default_look()
	var vs := text.split(":")
	if vs.size() < 2:
		return out
	var parts := vs[1].split("|")
	var sl := parts[0].split(".")
	for i in mini(sl.size(), SLOT_ORDER.size()):
		out["s"][SLOT_ORDER[i]] = int(sl[i])
	if parts.size() > 1:
		var cl := parts[1].split(".")
		for i in mini(cl.size(), COL_ORDER.size()):
			out["c"][COL_ORDER[i]] = int(cl[i])
	return sanitize(out)
