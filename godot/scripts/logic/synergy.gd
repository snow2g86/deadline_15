extends RefCounted
## 클래스 조합 버프 — 웹 js/logic/synergy.js (데이터는 data/synergy.js → godot/data/synergy.json)
##  SYNERGY_ROLE 의 조건(test 함수)은 JSON 으로 옮길 수 없어 여기 _role_test 에 다시 썼다 (웹 synergy.js 와 같은 조건)

const Js := preload("res://scripts/logic/js.gd")


static func _role_test(id: String, c: Dictionary, n: Dictionary) -> bool:
	var has := func(k: String) -> bool: return Js.truthy(c.get(k))
	match id:
		"balanced":
			return (has.call("knight") or has.call("lancer")) and has.call("priest") \
				and (has.call("archer") or has.call("mage") or has.call("shaman") or has.call("summoner")) \
				and (has.call("warrior") or has.call("assassin") or has.call("brawler") or has.call("sapper") or has.call("novice"))
		"diverse":
			return int(n["distinct"]) >= 5
		"artillery":
			return int(n["ranged"]) >= 3
		"vanguard":
			return int(n["melee"]) >= 4
		"bulwark":
			return int(c.get("knight", 0)) + int(c.get("lancer", 0)) >= 2
	return false


## Synergy.compute(classes) → [{ id, icon, eff, to, cls? }]
static func compute(D: Dictionary, classes: Array) -> Array:
	var c: Dictionary = {}
	var n := {"ranged": 0, "melee": 0, "distinct": 0}
	var RM: Dictionary = D["ROLE_MAP"]
	for k: Variant in classes:
		if not Js.truthy(k) or k == "commander" or String(k).begins_with("summon_"):
			continue
		c[k] = int(c.get(k, 0)) + 1
		var role: Variant = RM.get(k)
		if role == "ranged":
			n["ranged"] += 1
		elif role == "melee":
			n["melee"] += 1
	n["distinct"] = c.size()
	var out: Array = []
	var MONO: Dictionary = D["SYNERGY_MONO"]
	var TRIO: Dictionary = D["SYNERGY_TRIO"]
	for k2: String in c.keys():
		if int(c[k2]) >= 5 and MONO.has(k2):
			out.append({"id": "mono_" + k2, "cls": k2, "icon": MONO[k2]["icon"], "eff": Js.deep(MONO[k2]["eff"])})
		elif int(c[k2]) >= 3 and TRIO.has(k2):
			out.append({"id": "trio_" + k2, "cls": k2, "icon": "✦", "eff": Js.deep(TRIO[k2])})
	for r: Dictionary in D["SYNERGY_ROLE"]:
		if _role_test(r["id"], c, n):
			out.append({"id": r["id"], "icon": r["icon"], "eff": Js.deep(r["eff"]), "to": r["to"] if Js.truthy(r.get("to")) else null})
	var LG: Dictionary = D["SYNERGY_LEGION"]
	var lg := 0
	for k3: String in LG["classes"]:
		lg += int(c.get(k3, 0))
	if lg >= 3:
		out.append({"id": "legion", "icon": LG["icon"], "eff": Js.deep(LG["full"] if lg >= 5 else LG["part"])})
	return out


## Synergy.frags(list, n) — 조각 n 개 → 올림(n × 배율)
static func frags(list: Variant, n: float) -> float:
	var m := 1.0
	if list != null:
		for s: Dictionary in list:
			var f: Variant = s["eff"].get("frag") if Js.truthy(s.get("eff")) else null
			m *= float(f) if Js.truthy(f) else 1.0
	return ceilf(n * m)


## Synergy.apply(units, list) — 클랜원(소환수 제외)에 적용
static func apply(D: Dictionary, units: Array, list: Array) -> void:
	var RM: Dictionary = D["ROLE_MAP"]
	for u: Dictionary in units:
		if u["team"] != "ally" or Js.truthy(u.get("isSummon")):
			continue
		for s: Dictionary in list:
			if Js.truthy(s.get("to")) and RM.get(u["cls"]) != s["to"]:
				continue
			var e: Dictionary = s["eff"]
			if Js.truthy(e.get("hp")):
				u["mhp"] = maxf(1.0, Js.round_js(u["mhp"] * e["hp"]))
				u["hp"] = minf(u["mhp"], Js.round_js(u["hp"] * e["hp"]))
			if Js.truthy(e.get("atk")):
				u["atk"] = maxf(1.0, Js.round_js(u["atk"] * e["atk"]))
			if Js.truthy(e.get("def")):
				u["def"] = maxf(0.0, Js.round_js(u["def"] * e["def"]))
			if Js.truthy(e.get("move")):
				u["move"] = maxf(1.0, minf(6.0, u["move"] + e["move"]))
			if Js.truthy(e.get("range")) and u["range"] > 1:
				u["range"] = minf(6.0, u["range"] + e["range"])
			if Js.truthy(e.get("heal")):
				u["_healMul"] = (float(u["_healMul"]) if Js.truthy(u.get("_healMul")) else 1.0) * e["heal"]
