extends RefCounted
## 진행·해금 규칙 — 웹 js/stage-select.js (renderEpisodes · renderStages · showStageInfo 의 규칙 부분)
##  + js/common/storage.js (loadStars · stageStars) + js/common/daily.js (요일 던전: 입장 횟수 · 오늘 직업 · 난이도 해금)
##  모두 정적 함수, 첫 인자 c = ctx.gd (D · store). 화면 코드는 여기 결과만 그린다.
##   에피소드: EP.1 은 늘 열림, 그 뒤는 이전 에피소드의 모든 스테이지 클리어 시
##   스테이지: 에피소드 안 첫 스테이지 또는 바로 앞 스테이지 클리어 시 (cleared = game_save.cleared)
##   요일 던전: game_daily = { date: 'YYYY-MM-DD'(기기 현지 날짜), used }, 하루 DAILY.perDay 회, 난이도는 최고 클리어 스테이지로 해금

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const StageRules := preload("res://scripts/logic/stage_rules.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")

const DAILY_KEY := "game_daily"


## 클리어 기록 (4a, 웹보다 관대하게: 숫자 글자 "50" 은 숫자로, 숫자가 아닌 것은 버림 — 오류 없이)
static func cleared_list(c: Object) -> Array:
	var d := Profile.load_save(c)
	var cl: Variant = d.get("cleared")
	if not (cl is Array):
		return []
	var out: Array = []
	for v: Variant in cl:
		var n: Variant = PartyRules.to_number(v)
		if n != null:
			out.append(int(n) if float(n) == floorf(float(n)) else n)
	return out


static func is_cleared(cleared: Array, id: Variant) -> bool:
	return Js.index_of(cleared, id) != -1


## loadStars — { "<id>": [0|1 ×3] }
## stars 가 사전이 아니면(배열 등) 없는 것으로
static func stars(c: Object) -> Dictionary:
	var s: Variant = Profile.load_save(c).get("stars")
	return s if s is Dictionary else {}


## 별 3칸 [0|1] (길이·형이 잘못된 값은 3칸으로 맞춤)
static func stage_star_flags(all_stars: Dictionary, id: Variant) -> Array:
	var f: Variant = all_stars.get(str(int(id)))
	if not (f is Array):
		return [0, 0, 0]
	var out: Array = []
	for i in 3:
		out.append(f[i] if i < (f as Array).size() and (typeof(f[i]) == TYPE_INT or typeof(f[i]) == TYPE_FLOAT) else (1 if i < (f as Array).size() and Js.truthy(f[i]) else 0))
	return out


static func stage_stars(all_stars: Dictionary, id: Variant) -> int:
	var n := 0
	for v: Variant in stage_star_flags(all_stars, id):
		if Js.truthy(v):
			n += 1
	return n


## 전체 진행도 (부제) → { n, total }
static func total_progress(c: Object) -> Dictionary:
	var cl := cleared_list(c)
	var total := 0
	var n := 0
	for ep: Dictionary in c.D["EPISODES"]:
		for sid: Variant in ep["stages"]:
			total += 1
			if is_cleared(cl, sid):
				n += 1
	return {"n": n, "total": total}


## 에피소드 카드 목록 → [{id, unlocked, done, current, clear_count, count, stars, max_stars}]
static func episodes(c: Object) -> Array:
	var cl := cleared_list(c)
	var st := stars(c)
	var out: Array = []
	var eps: Array = c.D["EPISODES"]
	for ep: Dictionary in eps:
		var id := int(ep["id"])
		var unlocked := id == 1
		if not unlocked and id > 1:
			for pe: Dictionary in eps:
				if int(pe["id"]) == id - 1:
					unlocked = true
					for sid: Variant in pe["stages"]:
						if not is_cleared(cl, sid):
							unlocked = false
							break
		var cc := 0
		var es := 0
		for sid2: Variant in ep["stages"]:
			if is_cleared(cl, sid2):
				cc += 1
			es += stage_stars(st, sid2)
		var n: int = (ep["stages"] as Array).size()
		var done := cc == n
		out.append({"id": id, "unlocked": unlocked, "done": done, "current": not done and unlocked, "clear_count": cc, "count": n,
			"stars": es, "max_stars": n * 3})
	return out


## 에피소드 안 스테이지 카드 → [{id, idx, cleared, unlocked, next, boss, flags}]
static func stages_of(c: Object, ep_id: int) -> Array:
	var ep: Variant = null
	for e: Dictionary in c.D["EPISODES"]:
		if int(e["id"]) == ep_id:
			ep = e
	if ep == null:
		return []
	var cl := cleared_list(c)
	var st := stars(c)
	var list: Array = []
	for s: Dictionary in c.D["STAGES"]:
		if Js.index_of(ep["stages"], s["id"]) != -1:
			list.append(s)
	var out: Array = []
	for i in list.size():
		var s2: Dictionary = list[i]
		var clr := is_cleared(cl, s2["id"])
		var unlocked := i == 0 or is_cleared(cl, list[i - 1]["id"])
		out.append({"id": int(s2["id"]), "idx": i + 1, "cleared": clr, "unlocked": unlocked, "next": unlocked and not clr,
			"boss": Js.truthy(s2.get("boss")), "flags": stage_star_flags(st, s2["id"])})
	return out


## 정보 창의 EP.x-y (웹 showStageInfo 는 번호로 계산 — 목록은 EPISODES 순번)
static func info_label(id: int) -> String:
	return "EP.%d-%d" % [floori(float(id - 1) / 10.0) + 1, ((id - 1) % 10) + 1]


## 적 구성 (enemyComposition 을 수 많은 순 — 같은 수는 원래 순서)
static func enemy_composition(st: Dictionary) -> Array:
	var comp: Dictionary = st.get("enemyComposition", {}) if typeof(st.get("enemyComposition")) == TYPE_DICTIONARY else {}
	var arr: Array = []
	for k: String in comp.keys():
		arr.append([k, Js.num(comp[k])])
	return Js.stable_sort(arr, func(a: Array, b: Array) -> float: return float(b[1]) - float(a[1]))


## 권장 전략 키 (스테이지 팁 + 적 기사·암살자 팁)
static func tip_keys(st: Dictionary) -> Array:
	var keys: Array = (st.get("strategyTips", []) as Array).duplicate() if st.get("strategyTips") is Array else []
	var en: Array = (st.get("en", []) as Array).duplicate() if st.get("en") is Array else []
	if Js.truthy(st.get("boss")):
		en.append(st["boss"]["cls"])
	if en.has("knight"):
		keys.append("stage.tip_enemy_knight")
	if en.has("assassin"):
		keys.append("stage.tip_enemy_assassin")
	return keys


## 연습 모드: 클리어한 스테이지만
static func can_practice(c: Object, id: int) -> bool:
	return is_cleared(cleared_list(c), id)


static func find_stage(c: Object, id: int) -> Variant:
	for s: Dictionary in c.D["STAGES"]:
		if int(s["id"]) == id:
			return s
	return null


static func next_stage_of(c: Object, id: int) -> Variant:
	return find_stage(c, id + 1)


# ── 요일 던전 (daily.js) ──

## Daily.today — 기기 현지 날짜 'YYYY-MM-DD' (date: Time.get_date_dict_from_system() 모양)
static func today_str(date: Dictionary) -> String:
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]


static func _daily_get(c: Object, date: Dictionary) -> Dictionary:
	var s: Variant = c.store.get_json(DAILY_KEY)
	if typeof(s) == TYPE_DICTIONARY and s.get("date") == today_str(date):
		return s
	return {"date": today_str(date), "used": 0}


## 쓴 횟수 (4a, 관대하게: 글자 "2" 는 숫자로, 소수는 올림, 없거나 숫자가 아니면 0, 음수는 0)
static func daily_used(c: Object, date: Dictionary) -> float:
	var n: Variant = PartyRules.to_number(_daily_get(c, date).get("used"))
	return maxf(0.0, ceilf(float(n))) if n != null else 0.0


static func daily_left(c: Object, date: Dictionary) -> int:
	return maxi(0, int(c.D["DAILY"]["perDay"]) - int(daily_used(c, date)))


static func daily_consume(c: Object, date: Dictionary) -> void:
	var s := _daily_get(c, date)
	s["used"] = daily_used(c, date) + 1.0
	c.store.set_json(DAILY_KEY, s)


## 오늘 열린 직업 (weekday 0 = 일요일 — Godot·JS getDay 같음). 일요일은 모든 직업
static func daily_classes(c: Object, weekday: int) -> Array:
	var DL: Dictionary = c.D["DAILY"]
	var s: Variant = DL["schedule"].get(str(weekday))
	if typeof(s) == TYPE_STRING and s == "all":
		return (DL["CLASSES"] as Array).duplicate()
	return (s as Array).duplicate() if s is Array else []


static func best_cleared(c: Object) -> float:
	var cl := cleared_list(c)
	var b := 0.0
	for v: Variant in cl:
		b = maxf(b, Js.num(v))
	return b if not cl.is_empty() else 0.0


static func daily_tier_open(c: Object, i: int) -> bool:
	return best_cleared(c) >= float(c.D["DAILY"]["tiers"][i]["unlock"])


## 전투용 요일 던전 스테이지 (id 900번대)
static func daily_stage(c: Object, cls: String, tier: int) -> Dictionary:
	return StageRules.daily_build_stage(c.D, cls, tier)


## 영혼석·조각 (soul.js Soul.stones / frags)
static func soul_counts(c: Object, cls: String) -> Array:
	var d: Variant = c.store.get_json("game_soul")
	if typeof(d) != TYPE_DICTIONARY or not (d.get("stones") is Dictionary) or not (d.get("frags") is Dictionary):
		return [0.0, 0.0]
	return [Js.num(d["stones"].get(cls)), Js.num(d["frags"].get(cls))]
