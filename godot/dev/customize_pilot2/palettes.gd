extends RefCounted
## 시범 2차 — 색 팔레트·머리·의상 목록과 저장 형식 (개발용, 세이브에는 쓰지 않음)
##
## 저장 형식 제안 (클랜원 dict 안에 한 줄):
##   "look": {"v": 2, "h": 머리 번호, "c": 갑옷·천 팔레트 번호, "k": 피부색 번호, "r": 머리카락색 번호, "o": 의상 번호, "p": 무늬 번호, "d": 머리 장식 번호}
##   모든 번호는 0 = 원래 모습 (기사 투구·원래 갑옷·원래 색). 번호는 고정이며 새 항목은 뒤에만 덧붙임.
##   직업은 따로 (look 은 직업 위에 얹는 값): 같은 look 을 다른 직업에 줘도 번호 뜻이 직업마다 자기 자료에서 풀린다.

const VERSION := 2

## 머리: 0 = 원래 투구 (바꾸지 않음) / 나머지 = 머리 조각 id.  dy·dx = 기준점에서의 어긋남(크기 1 기준 px), sc = 크기 배율
const HEADS: Array[Dictionary] = [
	{"id": "", "name": "원래 투구"},
	{"id": "priest", "name": "금발 풍성", "dx": 2.0, "dy": -1.0, "sc": 1.0},
	{"id": "archer", "name": "엘프 금발", "dx": 2.0, "dy": -1.0, "sc": 1.0},
	{"id": "mage", "name": "백발 수염", "dx": 1.0, "dy": -1.0, "sc": 1.0},
	{"id": "assassin", "name": "검은 두건", "dx": 1.0, "dy": 0.0, "sc": 1.05},
	{"id": "brawler", "name": "민머리", "dx": 1.0, "dy": 1.0, "sc": 1.05},
	{"id": "lancer", "name": "붉은 말총", "dx": 0.0, "dy": -1.0, "sc": 1.0},
	{"id": "dancer", "name": "검은 긴머리", "dx": 2.0, "dy": -1.0, "sc": 1.0},
	{"id": "novice", "name": "뾰족 갈색", "dx": 1.0, "dy": 0.0, "sc": 0.95},
]

## 갑옷·천·가죽 팔레트: [이름, 갑옷, 천, 가죽, 세기(갑옷, 천, 가죽)]
const SETS: Array = [
	["원래", Color.WHITE, Color(0.72, 0.14, 0.14), Color.WHITE, Vector3(0, 0, 0)],
	["황금·남색", Color(0.95, 0.78, 0.28), Color(0.15, 0.25, 0.7), Color(0.45, 0.28, 0.15), Vector3(0.9, 0.95, 0.8)],
	["흑철·자주", Color(0.30, 0.31, 0.38), Color(0.62, 0.15, 0.62), Color(0.3, 0.2, 0.2), Vector3(0.95, 0.95, 0.8)],
	["청동·초록", Color(0.80, 0.52, 0.28), Color(0.15, 0.55, 0.28), Color(0.4, 0.25, 0.12), Vector3(0.9, 0.95, 0.8)],
	["은백·금", Color(0.95, 0.95, 1.0), Color(0.95, 0.75, 0.2), Color(0.55, 0.45, 0.3), Vector3(0.8, 0.95, 0.8)],
	["청강·흰", Color(0.45, 0.62, 0.95), Color(0.95, 0.95, 0.95), Color(0.3, 0.3, 0.5), Vector3(0.9, 0.95, 0.8)],
	["적동·검정", Color(0.78, 0.38, 0.30), Color(0.14, 0.14, 0.16), Color(0.25, 0.12, 0.1), Vector3(0.9, 0.95, 0.8)],
	["숲·갈색", Color(0.40, 0.58, 0.35), Color(0.55, 0.36, 0.18), Color(0.3, 0.22, 0.12), Vector3(0.9, 0.95, 0.8)],
]
const SKINS: Array = [["원래", Color.WHITE, 0.0], ["흰 피부", Color(1.0, 0.86, 0.78), 0.9], ["구릿빛", Color(0.78, 0.5, 0.3), 0.9], ["짙은 갈색", Color(0.45, 0.28, 0.18), 0.9], ["올리브", Color(0.72, 0.68, 0.4), 0.9]]
const HAIRS: Array = [["원래", Color.WHITE, 0.0], ["검정", Color(0.1, 0.09, 0.11), 0.95], ["밤색", Color(0.42, 0.24, 0.12), 0.95], ["붉은", Color(0.75, 0.2, 0.12), 0.95], ["은빛", Color(0.78, 0.82, 0.9), 0.95], ["분홍", Color(0.95, 0.5, 0.7), 0.95], ["청록", Color(0.15, 0.62, 0.62), 0.95]]
## 의상: 0 = 원래 갑옷 (바꾸지 않음) — 몸통 겹침 조각
const COSTUMES: Array[Dictionary] = [
	{"id": "", "name": "원래 갑옷"},
	{"id": "tabard", "name": "사제 흰 예복"},
	{"id": "robe", "name": "마법사 로브"},
	{"id": "tunic", "name": "궁수 튜닉"},
	{"id": "wrap", "name": "암살자 겉옷"},
	{"id": "gi", "name": "무투가 도복"},
]
## 머리 위 장식 (투구·모자): 0 = 없음
const DECOS: Array[Dictionary] = [
	{"id": "", "name": "장식 없음"},
	{"id": "hardhat", "name": "공병 안전모"},
]
const PATTERNS: Array = ["무늬 없음", "비스듬한 줄", "바둑", "가장자리 장식", "가슴 십자"]


static func default_look() -> Dictionary:
	return {"v": VERSION, "h": 0, "c": 0, "k": 0, "r": 0, "o": 0, "p": 0, "d": 0}


static func counts() -> Dictionary:
	return {"h": HEADS.size(), "c": SETS.size(), "k": SKINS.size(), "r": HAIRS.size(), "o": COSTUMES.size(), "p": PATTERNS.size(), "d": DECOS.size()}


static func normalize(raw: Variant) -> Dictionary:
	var out := default_look()
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var cn := counts()
	for k: String in cn.keys():
		var v: Variant = (raw as Dictionary).get(k, 0)
		var n := int(v) if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) else 0
		out[k] = n if n >= 0 and n < int(cn[k]) else 0
	return out


static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var cn := counts()
	var out := default_look()
	for k: String in cn.keys():
		out[k] = rng.randi_range(0, int(cn[k]) - 1)
	return out


static func describe(l: Dictionary) -> String:
	return "머리 %s · 장식 %s · 팔레트 %s · 피부 %s · 머리색 %s · 의상 %s · %s" % [HEADS[l["h"]]["name"], DECOS[l["d"]]["name"], SETS[l["c"]][0], SKINS[l["k"]][0], HAIRS[l["r"]][0], COSTUMES[l["o"]]["name"], PATTERNS[l["p"]]]
