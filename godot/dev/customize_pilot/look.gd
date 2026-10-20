extends RefCounted
## 외형 키와 무작위 뽑기 (시범) — 개발용. 실제 세이브에는 쓰지 않는다.
##
## 저장 형식 제안 (클랜원 한 명의 dict 안에 한 줄):
##   "look": {"v": 1, "h": 2, "f": 0, "o": 1, "t": 2}
##     v = 형식 버전 (조각 풀이 커져도 옛 저장을 읽기 위해)
##     h = 머리 모양 번호 (0부터)      f = 얼굴 표정 번호      o = 옷 번호      t = 피부색 번호
##   번호는 '조각 목록의 자리'가 아니라 '고정된 번호'여야 한다 — 새 조각은 뒤에만 덧붙이고, 기존 번호의 뜻은 바꾸지 않는다.
##   저장에 없으면(옛 세이브) 클랜원 id 로 같은 결과가 나오는 시드 뽑기(roll_seeded)를 써서 자동 채운 뒤 그때부터 저장한다.
##   미지의 번호(조각이 지워진 경우)는 normalize() 가 0번으로 돌린다.

const VERSION := 1
## 직업별 조각 개수 (기사 시범). 나중에는 직업 자료(data)에서 읽는다.
const COUNTS := {"h": 3, "f": 2, "o": 3, "t": 3}
## 피부색 (머리 바탕 조각에 곱하는 색) — 0 은 원래 색
const TONES: Array[Color] = [Color(1, 1, 1), Color(0.86, 0.72, 0.62), Color(1.0, 0.9, 0.86)]


static func default_look() -> Dictionary:
	return {"v": VERSION, "h": 0, "f": 0, "o": 0, "t": 0}


## 영입할 때 뽑기: 키마다 독립 무작위
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	return {"v": VERSION, "h": rng.randi_range(0, COUNTS["h"] - 1), "f": rng.randi_range(0, COUNTS["f"] - 1),
		"o": rng.randi_range(0, COUNTS["o"] - 1), "t": rng.randi_range(0, COUNTS["t"] - 1)}


## 같은 시드(예: 클랜원 id)면 늘 같은 외형 — 옛 세이브·가짜 영입 시험용
static func roll_seeded(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return roll(rng)


## 저장에서 읽은 값 정리: 빠진 키는 0, 범위를 벗어난 번호는 0, 숫자가 아니면 0
static func normalize(raw: Variant) -> Dictionary:
	var out := default_look()
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for k: String in COUNTS.keys():
		var v: Variant = (raw as Dictionary).get(k, 0)
		var n := int(v) if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) else 0
		out[k] = n if n >= 0 and n < int(COUNTS[k]) else 0
	return out


## 한 키만 바꾼 새 외형 (사용자가 직접 고를 때)
static func with_key(look: Dictionary, key: String, value: int) -> Dictionary:
	var out := normalize(look)
	if COUNTS.has(key):
		out[key] = clampi(value, 0, int(COUNTS[key]) - 1)
	return out


static func describe(look: Dictionary) -> String:
	return "머리%d 얼굴%d 옷%d 피부%d" % [int(look["h"]) + 1, int(look["f"]) + 1, int(look["o"]) + 1, int(look["t"]) + 1]
