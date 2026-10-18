extends RefCounted
## 보상형 광고 규칙 (결제층 A) — 화면 코드 없이 정적 함수, 첫 인자 c = ctx.gd (D · store)
##
##  보상은 골드만, 하루 횟수는 전체 합계 (상점 어느 탭의 광고 카드로 봐도 같은 횟수에서 뺌).
##  수치: data/iap.json 의 AD_REWARD {gold, daily} (디렉터가 정한 100G · 하루 3회 — 데이터로 바꿈)
##  저장 키 game_ads = {v:1, day:"YYYY-MM-DD"(기기 로컬 날짜), n:그날 받은 횟수, seen:{다녀간 다른 날: 그날 횟수}(최근 SEEN_MAX 개)}
##
##  날짜 바뀜: 기기 로컬 날짜(today)가 저장된 day 보다 '뒤'면 새 날 → 횟수 0 부터.
##  시계 되돌림 정책: day 는 앞으로만 간다. today 가 저장된 day 보다 '앞'(기기 시계를 되돌림)이면 새 날로 보지 않고
##   저장된 day 의 횟수를 그대로 쓴다 → 시계를 하루 앞으로 돌려 받고 다시 되돌려도 그만큼 기다려야 함 (앞당겨 받은 몫을 갚음).
##   (진짜 날짜가 저장된 day 를 지나면 정상으로 돌아옴. 서버 시각 확인(AdMob 서버 측 확인)은 모바일 SDK 작업 때)
##   단, 저장된 day 가 기기 날짜보다 **2일 넘게** 앞서 있으면(CLOCK_FIX_DAYS) 시계가 잘못됐다가 고쳐진 것으로 보고 기기 날짜로 다시 맞춤
##   — 이때 그날 횟수는 **다 쓴 것(daily)** 으로 둠 (재검수 디렉터 결정: 정직한 사용자는 하루만 손해, 다음 날부터 정상).
##   다녀간 날의 횟수는 seen 에 남겨, 시계를 앞뒤로 오가도(18일↔21일) 같은 날을 두 번 새로 받지 못함.

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")

const KEY := "game_ads"
const VERSION := 1


static func reward_gold(c: Object) -> float:
	var A: Variant = c.D.get("AD_REWARD")
	return float(A.get("gold", 0)) if A is Dictionary else 0.0


static func daily_max(c: Object) -> int:
	var A: Variant = c.D.get("AD_REWARD")
	return int(A.get("daily", 0)) if A is Dictionary else 0


## 기기 로컬 날짜 사전(Time.get_date_dict_from_system()) → "YYYY-MM-DD"
static func day_str(date: Dictionary) -> String:
	return "%04d-%02d-%02d" % [int(date.get("year", 1970)), int(date.get("month", 1)), int(date.get("day", 1))]


const CLOCK_FIX_DAYS := 2


static func _unix_day(day: String) -> int:
	if day.length() != 10:
		return 0
	return int(Time.get_unix_time_from_datetime_string(day + "T00:00:00") / 86400)


const SEEN_MAX := 14


static func _load(c: Object) -> Dictionary:
	var d: Variant = c.store.get_json(KEY)
	if d is Dictionary and typeof(d.get("day")) == TYPE_STRING:
		if not (d.get("seen") is Dictionary):
			d["seen"] = {}
		return d
	return {"v": VERSION, "day": "", "n": 0.0, "seen": {}}


## 오늘(today)에 맞춰 상태를 옮김 (d 를 고침) — 쓸 날 = d.day, 그날 횟수 = d.n
static func _resolve(c: Object, d: Dictionary, today: String) -> void:
	var day := str(d["day"])
	if today == day:
		return
	var seen: Dictionary = d["seen"]
	var n := Js.num(d.get("n"))
	var next_n := -1.0
	if seen.has(today):
		next_n = Js.num(seen[today])               # 다녀간 날로 시계가 돌아옴 — 그날 횟수 그대로
	elif day == "" or today > day:
		next_n = 0.0                                 # 새 날
	elif _unix_day(day) - _unix_day(today) > CLOCK_FIX_DAYS:
		next_n = float(daily_max(c))                 # 시계를 고침 — 그날은 다 쓴 것으로
	else:
		return                                       # 2일 이내로 되돌림 — 저장된 날의 횟수를 그대로 씀
	if day != "":
		seen[day] = n
	seen.erase(today)
	var ks: Array = seen.keys()
	ks.sort()
	while ks.size() > SEEN_MAX:
		seen.erase(ks.pop_front())
	d["day"] = today
	d["n"] = next_n


## 오늘 쓴 횟수
static func used(c: Object, today: String) -> int:
	var d := _load(c)
	_resolve(c, d, today)
	return int(Js.num(d.get("n")))


static func left(c: Object, today: String) -> int:
	return maxi(0, daily_max(c) - used(c, today))


## 광고를 끝까지 본 뒤 보상 (골드 + 횟수 한 번에) → {ok:true, gold, left} | {err:"limit"}
static func grant(c: Object, today: String) -> Dictionary:
	var d := _load(c)
	_resolve(c, d, today)
	d["v"] = VERSION
	var n := int(Js.num(d.get("n")))
	if n >= daily_max(c):
		c.store.set_json(KEY, d)   # 날짜 옮김(시계 고침 등)은 남김
		return {"err": "limit"}
	d["n"] = float(n + 1)
	var g := reward_gold(c)
	Profile.save_gold(c, Js.num(Profile.load_save(c).get("gold")) + g)
	c.store.set_json(KEY, d)
	return {"ok": true, "gold": g, "left": maxi(0, daily_max(c) - (n + 1))}


static func sanitize_value(v: Variant) -> Variant:
	if not (v is Dictionary):
		return null
	var d: Dictionary = v
	if typeof(d.get("day")) != TYPE_STRING:
		return null
	var n: Variant = d.get("n")
	if not ((typeof(n) == TYPE_INT or typeof(n) == TYPE_FLOAT) and is_finite(float(n)) and float(n) >= 0.0):
		d["n"] = 0.0
	if d.has("seen"):
		if not (d["seen"] is Dictionary):
			d.erase("seen")
		else:
			for k: Variant in (d["seen"] as Dictionary).keys():
				var sv: Variant = d["seen"][k]
				if typeof(k) != TYPE_STRING or not ((typeof(sv) == TYPE_INT or typeof(sv) == TYPE_FLOAT) and is_finite(float(sv))):
					(d["seen"] as Dictionary).erase(k)
	return d
