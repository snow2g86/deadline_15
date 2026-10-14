extends RefCounted
## 맵 환경 — 웹 js/logic/hazards.js 의 Hazard (환경 디버프 적용·지속 피해율·냉기 결계 배치)
##  공격 마법부여(EnchantFX)·보물상자(Chest)는 전투 상태를 만지므로 scripts/logic/battle/ 쪽에 있다.

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const StageRules := preload("res://scripts/logic/stage_rules.gd")


static func for_stage(D: Dictionary, stage: Variant) -> Variant:
	if stage == null:
		return null
	return (D["HAZARDS"] as Dictionary).get(stage.get("mapType"))


## 후반일수록 지속 피해가 커짐: dot × (1 + 스테이지 레벨/100) — 실수 나눗셈 (stage_level 이 float)
static func dot_pct(h: Variant, stage: Variant) -> float:
	if h == null or not Js.truthy(h.get("dot")):
		return 0.0
	return float(h["dot"]) * (1.0 + StageRules.stage_level(stage) / 100.0)


## 이 캐릭터가 장착한 장비의 마법부여 목록
static func enchants_of(c: Object, ch: Variant) -> Array:
	if ch == null or not Js.truthy(ch.get("equip")):
		return []
	var inv := Profile.load_inventory(c)
	var out: Array = []
	for slot: String in ch["equip"].keys():
		var eid: Variant = ch["equip"][slot]
		if not Js.truthy(eid):
			continue
		var it: Variant = null
		for x: Variant in inv:
			if typeof(x) == TYPE_DICTIONARY and Js.same(x.get("eid"), eid):
				it = x
				break
		if it == null:
			continue
		for k: Variant in [it.get("enchant"), it.get("enchantAtk")]:
			if Js.truthy(k) and not out.has(k):
				out.append(k)
	return out


static func protects(u: Dictionary, h: Variant) -> bool:
	return h != null and Js.truthy(u.get("enchants")) and (u["enchants"] as Array).has(h["enchant"])


## 전투 시작 때 클랜원에 적용 → 환경 (없으면 null)
static func apply(D: Dictionary, units: Array, stage: Variant) -> Variant:
	var h: Variant = for_stage(D, stage)
	if h == null:
		return null
	for u: Dictionary in units:
		if u["team"] != "ally" or Js.truthy(u.get("isSummon")):
			continue
		if protects(u, h):
			u["_hazardSafe"] = true
			continue
		if Js.truthy(h.get("move")):
			u["move"] = maxf(1.0, u["move"] + h["move"])
		if Js.truthy(h.get("range")) and u["range"] > 1:
			u["range"] = maxf(2.0, u["range"] + h["range"])
		if Js.truthy(h.get("def")):
			u["def"] = Js.round_js(u["def"] * h["def"])
		if Js.truthy(h.get("heal")):
			u["_healMul"] = (float(u["_healMul"]) if Js.truthy(u.get("_healMul")) else 1.0) * h["heal"]
		if Js.truthy(h.get("dot")):
			u["_hazardDot"] = true
	return h


## 냉기 결계: 맵 가운데 구역에 붙어 있는 칸 묶음 → S.safeZones (삽입 순서를 지키는 'x,y' 배열 — 웹은 Set)
static func place_safe(c: Object, S: Dictionary, h: Variant) -> void:
	S["safeZones"] = []
	if h == null or not Js.truthy(h.get("safe")):
		return
	var TI: Dictionary = c.D["TI"]
	var SZ: Dictionary = c.D["SAFE_ZONE"]
	var cols: int = int(c.D["COLS"])
	var safe: Array = S["safeZones"]
	var ok := func(x: int, y: int) -> bool:
		if y < 0 or y >= (S["ter"] as Array).size() or x < 0 or x >= (S["ter"][y] as Array).size():
			return false
		var tl: Variant = S["ter"][y][x]
		return Js.truthy(tl) and TI.has(tl) and Js.truthy(TI[tl]["pass"]) and tl != "shallow" and not safe.has(str(x) + "," + str(y))
	var cells: Array = []
	for y in range(int(SZ["rows"][0]), int(SZ["rows"][1]) + 1):
		for x in cols:
			if ok.call(x, y):
				cells.append([x, y])
	var z := 0
	while z < int(SZ["zones"]) and not cells.is_empty():
		var ci := int(floorf(c.rand("placeSafe") * cells.size()))
		var cc: Array = cells[ci]
		cells.remove_at(ci)
		var zone: Array = [cc]
		while zone.size() < int(SZ["size"]):
			var nb: Array = []
			for p: Array in zone:
				for d: Array in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var nx: int = p[0] + d[0]
					var ny: int = p[1] + d[1]
					if ok.call(nx, ny):
						var dup := false
						for q: Array in zone:
							if q[0] == nx and q[1] == ny:
								dup = true
								break
						if not dup:
							nb.append([nx, ny])
			if nb.is_empty():
				break
			zone.append(nb[int(floorf(c.rand("placeSafe") * nb.size()))])
		for p2: Array in zone:
			var key := str(p2[0]) + "," + str(p2[1])
			if not safe.has(key):
				safe.append(key)
		var left: Array = []
		for p3: Array in cells:
			if not safe.has(str(p3[0]) + "," + str(p3[1])):
				left.append(p3)
		cells = left
		z += 1


static func in_safe(S: Dictionary, u: Dictionary) -> bool:
	return Js.truthy(S.get("safeZones")) and (S["safeZones"] as Array).has(str(u["x"]) + "," + str(u["y"]))
