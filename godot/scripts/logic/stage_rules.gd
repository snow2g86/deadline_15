extends RefCounted
## 스테이지 계산 — 웹 js/logic/stages.js (stageSm·적 레벨·스킬 레벨·보스 이름) + js/common/daily.js (요일 던전 스테이지, stageLevel)
##  STAGES 의 sm·tot·spw 가공은 변환기가 이미 반영 (godot/data/stages.json). 여기는 실행 중에 쓰는 함수만.

const Js := preload("res://scripts/logic/js.gd")


## stageLevel(st) — 요일 던전은 같은 강함의 스테이지 번호. **float 로 돌려줌** (stageLevel/100 이 JS 처럼 실수 나눗셈이 되도록)
static func stage_level(st: Variant) -> float:
	if st == null:
		return 1.0
	if Js.truthy(st.get("daily")):
		return float(st["daily"]["eq"])
	return float(st["id"])


static func stage_sm(D: Dictionary, id: float) -> float:
	return Js.round_js(float(D["ENEMY_SM_BASE"]) * pow(float(D["ENEMY_SM_GROWTH"]), id - 1.0) * 100.0) / 100.0


static func stage_enemy_lv(D: Dictionary, id: float) -> float:
	return 1.0 + floorf((id - 1.0) * float(D["ENEMY_LV_PER_STAGE"]))


static func stage_enemy_skill_lv(D: Dictionary, id: float) -> float:
	return minf(10.0, 1.0 + floorf(id / float(D["ENEMY_SKILL_EVERY"])))


## 스테이지 id 로 찾은 사본 (웹 battle-sim buildStage: JSON 깊은 복사)
static func find_stage(D: Dictionary, id: int) -> Variant:
	for s: Dictionary in D["STAGES"]:
		if int(s["id"]) == id:
			return Js.deep(s)
	return null


## Daily.buildStage(cls, tierIdx) — 요일 던전 전투용 스테이지 (id 900번대)
static func daily_build_stage(D: Dictionary, cls: String, tier_idx: int) -> Dictionary:
	var DL: Dictionary = D["DAILY"]
	var T: Dictionary = DL["tiers"][tier_idx]
	var k := stage_sm(D, float(T["eq"]))
	var esc: String = DL["escort"].get(cls, "warrior")
	var en: Array = []
	for i in int(T["tot"]):
		en.append(esc if i % 3 == 2 else cls)
	return {
		"id": 901 + tier_idx, "phase": 0, "style": "mixed", "mapType": T["map"], "tot": float(T["tot"]),
		"spw": int(ceilf(float(T["tot"]) / 2.0)), "si": 2, "boss": null,
		"en": en, "sm": {"hp": k, "atk": k}, "daily": {"cls": cls, "tier": T["key"], "frags": T["frags"], "eq": T["eq"]},
	}
