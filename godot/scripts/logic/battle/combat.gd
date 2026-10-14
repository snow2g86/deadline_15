extends RefCounted
## 전투 계산 — 웹 js/battle/buff.js (BuffSystem) · js/skills/_common.js (calcDmg·applyDmgToAlly·procFury·분노 패시브)
##  · js/logic/hazards.js (EnchantFX·Chest) · js/skills/shaman.js (저주 틱·독안개 틱)
##  장비 전투 효과(GearFX)는 gear_fx.gd. E = battle_engine.gd

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const Gear := preload("res://scripts/logic/gear.gd")
const Synergy := preload("res://scripts/logic/synergy.gd")
const StageRules := preload("res://scripts/logic/stage_rules.gd")

const DEBUFFS := ["atk_down", "def_down", "stun", "freeze", "root", "disarm", "bleed", "poison", "curse"]

var E: Object
var S: Dictionary
var D: Dictionary


func _init(engine: Object) -> void:
	E = engine
	S = engine.S
	D = engine.D


static func is_debuff(type: Variant) -> bool:
	return DEBUFFS.has(type)


# ═══════════ BuffSystem ═══════════

## BuffSystem.apply — 같은 타입+출처면 갱신(난수 없음), 새 버프면 id 를 위해 난수 1회 (buffDef.id 를 주면 0회)
func buff_apply(unit: Dictionary, def: Dictionary) -> Dictionary:
	if typeof(unit.get("buffs")) != TYPE_ARRAY:
		unit["buffs"] = []
	for b: Dictionary in unit["buffs"]:
		if b.get("type") == def.get("type") and b.get("source") == def.get("source"):
			if def.has("duration"):
				b["duration"] = maxf(Js.num(b.get("duration")), float(def["duration"]))
			if def.has("value"):
				b["value"] = def["value"]
			if def.has("stacks"):
				b["stacks"] = Js.num(b.get("stacks")) + float(def["stacks"])
			if Js.truthy(def.get("meta")):
				if typeof(b.get("meta")) != TYPE_DICTIONARY:
					b["meta"] = {}
				for k: Variant in def["meta"].keys():
					b["meta"][k] = def["meta"][k]
			return b
	var bid: Variant = def.get("id")
	if not Js.truthy(bid):
		var r: float = E.c.rand("BuffSystem.apply")
		bid = str(def["type"]) + "_" + Js.base36(int(r * 1679616.0))
	var buff := {
		"id": bid,
		"type": def["type"],
		"duration": float(def["duration"]) if def.has("duration") else 1.0,
		"value": def["value"] if Js.truthy(def.get("value")) else 0.0,
		"stacks": def["stacks"] if Js.truthy(def.get("stacks")) else 1.0,
		"source": def["source"] if Js.truthy(def.get("source")) else "",
		"icon": def["icon"] if Js.truthy(def.get("icon")) else "",
		"meta": def["meta"] if Js.truthy(def.get("meta")) else {},
	}
	(unit["buffs"] as Array).append(buff)
	E.emit("buff_applied", {"unit": unit, "buff": buff})
	return buff


func buff_remove(unit: Dictionary, type: String, source: String = "") -> Variant:
	if typeof(unit.get("buffs")) != TYPE_ARRAY:
		return null
	var arr: Array = unit["buffs"]
	for i in arr.size():
		var b: Dictionary = arr[i]
		if b.get("type") == type and (source == "" or b.get("source") == source):
			arr.remove_at(i)
			E.emit("buff_removed", {"unit": unit, "buff": b})
			return b
	return null


## BuffSystem.tick — 뒤에서부터: 지속 피해/회복 → 지속 감소 → 만료 제거
func buff_tick(unit: Dictionary) -> void:
	if typeof(unit.get("buffs")) != TYPE_ARRAY:
		return
	var arr: Array = unit["buffs"]
	var i := arr.size() - 1
	while i >= 0:
		if i >= arr.size():
			i -= 1
			continue
		var b: Dictionary = arr[i]
		var t: Variant = b.get("type")
		var v: float = Js.num(b.get("value"))
		if t == "bleed" and v > 0.0:
			unit["hp"] = maxf(1.0, unit["hp"] - v)
			E.emit("buff_tick_damage", {"unit": unit, "buff": b, "damage": b["value"]})
		if t == "poison" and v > 0.0:
			unit["hp"] = maxf(1.0, unit["hp"] - v)
			E.emit("buff_tick_damage", {"unit": unit, "buff": b, "damage": b["value"]})
		if t == "regen" and v > 0.0:
			unit["hp"] = minf(unit["mhp"], unit["hp"] + v)
			E.emit("buff_tick_heal", {"unit": unit, "buff": b, "heal": b["value"]})
		if t == "sanctuary" and v > 0.0:
			unit["hp"] = minf(unit["mhp"], unit["hp"] + v)
			E.emit("buff_tick_heal", {"unit": unit, "buff": b, "heal": b["value"]})
		if Js.same(b.get("duration"), -1):
			i -= 1
			continue
		b["duration"] = Js.num(b.get("duration")) - 1.0
		if float(b["duration"]) <= 0.0:
			arr.remove_at(i)
			E.emit("buff_removed", {"unit": unit, "buff": b})
		i -= 1


func buff_has(unit: Dictionary, type: String) -> bool:
	var arr: Variant = unit.get("buffs")
	if typeof(arr) != TYPE_ARRAY:
		return false
	for b: Dictionary in arr:
		if b.get("type") == type and not Js.same(b.get("duration"), 0):
			return true
	return false


# ═══════════ 은신 ═══════════

func is_stealthed(u: Dictionary) -> bool:
	if Js.truthy(u.get("stealthBroken")):
		return false
	if u["cls"] != "assassin":
		return false
	if buff_has(u, "stealth"):
		return true
	return E.gu.tile(u["x"], u["y"]) == "forest"


# ═══════════ calcDmg ═══════════

## calcDmg 를 그대로 + 기록 사건 calc (parts 는 battle-sim calcParts 와 같은 디버깅용 내역)
func calc_dmg(a: Dictionary, t: Dictionary) -> float:
	var parts := _calc_parts(a, t)
	var r0: int = E.c.rng.calls
	var dmg := _calc_dmg_raw(a, t)
	var tl: Variant = E.gu.tile(t["x"], t["y"])
	var at: Variant = E.gu.tile(a["x"], a["y"])
	var lt: Variant = a.get("_lastTactic")
	E.rec_r("calc", r0, {"a": a["id"], "t": t["id"], "dmg": dmg,
		"tags": (lt["tags"] as Array).duplicate() if Js.truthy(lt) else [],
		"crit": Js.truthy(a.get("_lastCrit")), "shallow": tl == "shallow",
		"dist": Js.mh(a["x"], a["y"], t["x"], t["y"]), "hill": at == "hill" and float(a["range"]) > 1.0, "parts": parts})
	return dmg


func _exalt_on(team: String) -> bool:
	for u: Dictionary in S["units"]:
		if u["team"] == team and u["hp"] > 0 and u.get("channeling") == "shaman_exalt":
			return true
	return false


func _calc_atk_def(a: Dictionary, t: Dictionary) -> Array:
	var atk: float = a["atk"]
	if a["cls"] == "warrior" and Js.num(a["skillLv"].get("warrior_bloodthirst")) >= 1 and a["mhp"] > 0:
		var hp_ratio: float = 1.0 - (a["hp"] / a["mhp"])
		atk = Js.round_js(atk * (1.0 + 0.5 * hp_ratio))
	if Js.num(a.get("disarmed")) > 0:
		atk = Js.round_js(atk * 0.5)
	if Js.truthy(a.get("isSummon")) and Js.num(a.get("_empowerTurns")) > 0 and Js.num(a.get("_empowerMul")) > 0:
		atk = Js.round_js(atk * float(a["_empowerMul"]))
	for b: Dictionary in a["buffs"]:
		if b.get("type") == "atk_up":
			atk = Js.round_js(atk * (1.0 + Js.num(b.get("value")) / 100.0))
	for b2: Dictionary in a["buffs"]:
		if b2.get("type") == "atk_down":
			atk = Js.round_js(atk * (1.0 - Js.num(b2.get("value")) / 100.0))
	var def: float = t["def"]
	if Js.truthy(t.get("_tenacityDef")):
		def += 10000.0
	if Js.num(t.get("defBuff")) > 0:
		def = Js.round_js(def * 1.5)
	for b3: Dictionary in t["buffs"]:
		if b3.get("type") == "def_up":
			def = Js.round_js(def * (1.0 + Js.num(b3.get("value")) / 100.0))
	for b4: Dictionary in t["buffs"]:
		if b4.get("type") == "def_down":
			def = Js.round_js(def * (1.0 - Js.num(b4.get("value")) / 100.0))
	if Js.num(t.get("_phalanxDef")) > 0:
		def += float(t["_phalanxDef"])
	if t["cls"] == "novice" and Js.num(t["skillLv"].get("novice_grit")) >= 1 and t["mhp"] > 0 and t["hp"] <= t["mhp"] * 0.3:
		def = Js.round_js(def * 1.3)
	if Js.truthy(t.get("_defend")):
		def = Js.round_js(def * float(D["TACTICS_ACT"]["defendDef"]))
	return [atk, def]


func _calc_parts(a: Dictionary, t: Dictionary) -> Dictionary:
	var ad := _calc_atk_def(a, t)
	var mods: Array = []
	if Js.num(a.get("furyBuff")) > 0:
		mods.append("fury1.5")
	if _exalt_on(a["team"]):
		mods.append("exalt1.25")
	if a["cls"] == "mage" and Js.num(a["skillLv"].get("mage_manasurge")) >= 1 and a["res"] >= a["maxRes"] * 0.8:
		mods.append("manasurge1.2")
	var tb: Dictionary = E.gu.tactic_bonus(a, t)
	if not (tb["tags"] as Array).is_empty():
		mods.append("tactic" + E.num_str(tb["mul"]))
	if E.gu.tile(t["x"], t["y"]) == "shallow":
		mods.append("shallow" + E.num_str(1.0 + float(D["TACTIC"]["shallowVuln"])))
	if Js.truthy(a.get("gear")):
		mods.append("gear")
	return {"atk": ad[0], "def": ad[1], "base": maxf(1.0, ad[0] - ad[1]), "mods": mods}


func _calc_dmg_raw(a: Dictionary, t: Dictionary) -> float:
	var ad := _calc_atk_def(a, t)
	var dmg := maxf(1.0, float(ad[0]) - float(ad[1]))
	if Js.num(a.get("furyBuff")) > 0:
		dmg = maxf(1.0, Js.round_js(dmg * 1.5))
	if _exalt_on(a["team"]):
		dmg = maxf(1.0, Js.round_js(dmg * 1.25))
	if a["cls"] == "mage" and Js.num(a["skillLv"].get("mage_manasurge")) >= 1 and a["res"] >= a["maxRes"] * 0.8:
		dmg = maxf(1.0, Js.round_js(dmg * 1.2))
	a["_lastTactic"] = null
	var tb: Dictionary = E.gu.tactic_bonus(a, t)
	if not (tb["tags"] as Array).is_empty():
		dmg = maxf(1.0, Js.round_js(dmg * float(tb["mul"])))
		a["_lastTactic"] = tb
	if E.gu.tile(t["x"], t["y"]) == "shallow":
		dmg = maxf(1.0, Js.round_js(dmg * (1.0 + float(D["TACTIC"]["shallowVuln"]))))
	a["_lastCrit"] = false
	if a["cls"] == "commander" and E.c.rand("calcDmg.commander") < 0.01:
		dmg = maxf(1.0, Js.round_js(dmg * 10.0))
		a["_lastCrit"] = true
	if a["cls"] == "archer" and Js.num(a["skillLv"].get("archer_weakspot")) >= 1:
		if E.c.rand("calcDmg.weakspot") < 0.3:
			dmg = maxf(1.0, Js.round_js(dmg * 1.5))
			a["_lastCrit"] = true
	dmg = E.gearfx.mod(a, t, dmg)
	return dmg


# ═══════════ 아군 피해 적용 (희생·고통 분담·장비 흡수·강인한) ═══════════

func apply_dmg_to_ally(tgt: Dictionary, dmg: float) -> Dictionary:
	var actual: Dictionary = tgt
	if Js.truthy(tgt.get("_sacrificeKnight")):
		var knight: Variant = null
		for v: Dictionary in S["units"]:
			if Js.same(v["id"], tgt["_sacrificeKnight"]) and v["hp"] > 0:
				knight = v
				break
		if knight != null and Js.num(knight.get("_sacrificeDmgCount")) > 0:
			actual = knight
			knight["_sacrificeDmgCount"] = float(knight["_sacrificeDmgCount"]) - 1.0
			if float(knight["_sacrificeDmgCount"]) <= 0.0:
				tgt.erase("_sacrificeKnight")
				knight.erase("_sacrificeTarget")
				E.fx("float", {"x": knight["x"], "y": knight["y"], "text": "messages.knight_sacrifice_end"})
	if actual == tgt:
		var ps: Variant = null
		var best_d := 0
		for v2: Dictionary in S["units"]:
			if v2["team"] == "ally" and v2["hp"] > 0 and v2["id"] != tgt["id"] and v2["cls"] == "knight" \
					and Js.num(v2["skillLv"].get("knight_painshare")) >= 1 and Js.mh(v2["x"], v2["y"], tgt["x"], tgt["y"]) <= 5:
				var dd := Js.mh(v2["x"], v2["y"], tgt["x"], tgt["y"])
				if ps == null or dd < best_d:
					ps = v2
					best_d = dd
		if ps != null:
			var shared := floorf(dmg / 3.0)
			var remain := dmg - shared
			ps["hp"] = maxf(1.0, ps["hp"] - shared)
			E.fx("float", {"x": ps["x"], "y": ps["y"], "text": "-" + E.num_str(shared)})
			tgt["hp"] = maxf(0.0, tgt["hp"] - E.gearfx.absorb(tgt, remain))
			if tgt["hp"] <= 0 and tgt["cls"] == "knight" and Js.num(tgt["skillLv"].get("knight_tenacity")) >= 1 and not Js.truthy(tgt.get("_tenacityUsed")):
				tgt["hp"] = 1.0
				tgt["_tenacityUsed"] = true
				tgt["_tenacityDef"] = true
			return tgt
	dmg = E.gearfx.absorb(actual, dmg)
	actual["hp"] = maxf(0.0, actual["hp"] - dmg)
	if actual["hp"] <= 0 and actual["cls"] == "knight" and Js.num(actual["skillLv"].get("knight_tenacity")) >= 1 and not Js.truthy(actual.get("_tenacityUsed")):
		actual["hp"] = 1.0
		actual["_tenacityUsed"] = true
		actual["_tenacityDef"] = true
	if actual != tgt and actual["hp"] <= 0:
		E.gu.rm_dead()
		E.fx_redraw_units()   # Fx.later(() => ctx.rUnits(), 500) — 연출을 끄면 즉시
	return actual


# ═══════════ 분노 ═══════════

func proc_fury(attacker: Dictionary, target: Dictionary) -> void:
	if attacker.get("resType") == "fury":
		attacker["res"] = minf(attacker["maxRes"], attacker["res"] + 1.0)
	if target["hp"] > 0 and target.get("resType") == "fury":
		target["res"] = minf(target["maxRes"], target["res"] + 2.0)
		if target["res"] >= target["maxRes"]:
			match target["cls"]:
				"warrior":
					target["furyBuff"] = 2.0
					target["res"] = 0.0
					E.fx("float", {"x": target["x"], "y": target["y"], "text": "passives.fury_activated"})
				"knight":
					target["defBuff"] = 2.0
					target["res"] = 0.0
					E.fx("float", {"x": target["x"], "y": target["y"], "text": "passives.iron_will_activated"})
				"lancer":
					target["defBuff"] = 2.0
					target["res"] = 0.0
					E.fx("float", {"x": target["x"], "y": target["y"], "text": "passives.iron_phalanx_activated"})


# ═══════════ 공격용 마법부여 (EnchantFX) ═══════════

func _atk_enchants(u: Variant) -> Array:
	var out: Array = []
	if u == null or typeof(u.get("enchants")) != TYPE_ARRAY:
		return out
	var EN: Dictionary = D["ENCHANTS"]
	for k: Variant in u["enchants"]:
		if EN.has(k) and EN[k]["cat"] == "atk":
			out.append(k)
	return out


## EnchantFX.modDamage (번개 +%, 파쇄 방어 일부 무시)   [기록: ench_dmg]
func ench_mod_damage(a: Dictionary, t: Dictionary, dmg: float) -> float:
	var r0: int = E.c.rng.calls
	var d0 := dmg
	var EN: Dictionary = D["ENCHANTS"]
	var list := _atk_enchants(a)
	for k: String in list:
		var e: Dictionary = EN[k]
		if Js.truthy(e.get("dmg")):
			dmg = Js.round_js(dmg * (1.0 + float(e["dmg"])))
		if Js.truthy(e.get("pierce")):
			dmg += Js.round_js(Js.num(t.get("def")) * float(e["pierce"]))
	var r := maxf(1.0, dmg)
	if not list.is_empty():
		E.rec_r("ench_dmg", r0, {"a": a["id"], "t": t["id"], "before": d0, "after": r})
	return r


## EnchantFX.afterHit (화상·독·빙결·흡혈 → GearFX.afterHit)   [기록: ench_hit]
func ench_after_hit(a: Variant, t: Variant, dmg: float) -> void:
	var r0: int = E.c.rng.calls
	var ah: float = a["hp"] if a != null else 0.0
	var nb: int = (t["buffs"] as Array).size() if t != null and typeof(t.get("buffs")) == TYPE_ARRAY else 0
	_ench_after_hit_raw(a, t, dmg)
	if not _atk_enchants(a).is_empty():
		var nbs: Array = []
		var arr: Array = t["buffs"] if typeof(t.get("buffs")) == TYPE_ARRAY else []
		for i in range(nb, arr.size()):
			nbs.append(arr[i]["type"])
		E.rec_r("ench_hit", r0, {"a": a["id"], "t": t["id"], "dmg": dmg, "drain": a["hp"] - ah, "newBuffs": nbs})


func _ench_after_hit_raw(a: Variant, t: Variant, dmg: float) -> void:
	if a == null or t == null or dmg <= 0.0:
		return
	var EN: Dictionary = D["ENCHANTS"]
	for k: String in _atk_enchants(a):
		var e: Dictionary = EN[k]
		if t["hp"] > 0 and Js.truthy(e.get("burn")):
			buff_apply(t, {"type": "bleed", "duration": e["turns"], "value": maxf(1.0, Js.round_js(a["atk"] * float(e["burn"]))), "icon": e["icon"], "source": "enchant_flame"})
		if t["hp"] > 0 and Js.truthy(e.get("poison")):
			buff_apply(t, {"type": "poison", "duration": e["turns"], "value": maxf(1.0, Js.round_js(a["atk"] * float(e["poison"]))), "icon": e["icon"], "source": "enchant_venom"})
		if t["hp"] > 0 and Js.truthy(e.get("freeze")) and E.c.rand("EnchantFX.freeze") < float(e["freeze"]):
			buff_apply(t, {"type": "freeze", "duration": 1.0, "icon": e["icon"], "source": "enchant_frost"})
		if Js.truthy(e.get("drain")) and a["hp"] > 0:
			var h := minf(a["mhp"] - a["hp"], maxf(1.0, Js.round_js(dmg * float(e["drain"]))))
			if h > 0.0:
				a["hp"] = a["hp"] + h
	E.gearfx.after_hit(a, t, dmg)


# ═══════════ 보물상자 (Chest) ═══════════

func chest_place() -> void:
	var CH: Dictionary = D["CHEST"]
	var n: int = int(CH["min"]) + int(floorf(E.c.rand("Chest.place") * (float(CH["max"]) - float(CH["min"]) + 1.0)))
	var cells: Array = []
	var cols: int = int(D["COLS"])
	for y in range(int(CH["rows"][0]), int(CH["rows"][1]) + 1):
		for x in cols:
			var tl: Variant = S["ter"][y][x]
			if D["TI"].has(tl) and Js.truthy(D["TI"][tl]["pass"]) and tl != "shallow" and E.gu.u_at(x, y) == null:
				cells.append({"x": x, "y": y})
	S["chests"] = []
	var i := 0
	while i < n and not cells.is_empty():
		var ci := int(floorf(E.c.rand("Chest.place") * cells.size()))
		(S["chests"] as Array).append(cells[ci])
		cells.remove_at(ci)
		i += 1


func chest_at(x: int, y: int) -> Variant:
	for c: Dictionary in S.get("chests", []):
		if c["x"] == x and c["y"] == y:
			return c
	return null


## Chest.open — 보상을 바로 저장 → { kind }
func chest_open(chest: Dictionary, opener: Dictionary) -> Dictionary:
	var c: Object = E.c
	var left: Array = []
	for k: Dictionary in S["chests"]:
		if k != chest:
			left.append(k)
	S["chests"] = left
	var r: float = c.rand("Chest.open")
	var o: Dictionary = D["CHEST"]["odds"]
	var lv := StageRules.stage_level(S["cStage"])
	var acc: float = float(o["gold"])
	if r < acc:
		var g := Js.round_js((40.0 + lv * 8.0) * (0.8 + c.rand("Chest.gold") * 0.4))
		S["gold"] = float(S["gold"]) + g
		Profile.save_gold(c, S["gold"])
		return {"kind": "gold"}
	acc = float(o["gold"]) + float(o["potion"])
	if r < acc:
		var keys: Array = (D["BATTLE_POTIONS"] as Dictionary).keys()
		var pid: String = keys[int(floorf(c.rand("Chest.potion") * keys.size()))]
		var def: Dictionary = D["BATTLE_POTIONS"][pid]
		var inv := Profile.load_inventory(c)
		inv.append({"type": "battle_potion", "pid": c.date_now(), "potionId": pid, "icon": def["icon"], "quantity": 1.0})
		Profile.save_inventory(c, inv)
		(S["_battlePotions"] as Array).append(Js.deep(inv[inv.size() - 1]))
		(S["_battlePotionIndices"] as Array).append(inv.size() - 1)
		return {"kind": "potion"}
	acc = float(o["gold"]) + float(o["potion"]) + float(o["rune"])
	if r < acc:
		Gear.rune_add(c, Gear.rune_random(c))
		return {"kind": "rune"}
	acc = float(o["gold"]) + float(o["potion"]) + float(o["rune"]) + float(o["equip"])
	if r < acc:
		var it := Gear.gacha_pull(c, null, true)
		var inv2 := Profile.load_inventory(c)
		inv2.append(it)
		Profile.save_inventory(c, inv2)
		return {"kind": "equip"}
	acc = float(o["gold"]) + float(o["potion"]) + float(o["rune"]) + float(o["equip"]) + float(o["stone"])
	if r < acc:
		var ns := 1.0 + floorf(c.rand("Chest.stone") * 3.0)
		Profile.mats_add(c, "stone", ns)
		return {"kind": "stone"}
	acc = float(o["gold"]) + float(o["potion"]) + float(o["rune"]) + float(o["equip"]) + float(o["stone"]) + float(o["protect"])
	if r < acc:
		Profile.mats_add(c, "protect", 1.0)
		return {"kind": "protect"}
	var cls: String = opener["cls"] if opener != null and opener["cls"] != "commander" else "novice"
	var nf := Synergy.frags(S.get("_synergies"), 2.0)
	Profile.soul_add(c, "frag", cls, nf)
	return {"kind": "soul"}


# ═══════════ 주술사 틱 ═══════════

## curseMoveTick — 저주받은 유닛이 이동할 때마다 최대 HP 5% (사망 안 함, 5회 후 해제)   [기록: curse_tick]
func curse_move_tick(u: Dictionary) -> void:
	var h0: float = u["hp"]
	var r0: int = E.c.rng.calls
	if not Js.truthy(u.get("_cursed")) or not (u["mhp"] > 0) or u["hp"] <= 0:
		return
	var dmg := maxf(1.0, Js.round_js(u["mhp"] * 0.05))
	u["hp"] = maxf(1.0, u["hp"] - dmg)
	u["_curseDmgCount"] = Js.num(u.get("_curseDmgCount")) + 1.0
	E.fx_float(u["x"], u["y"], "messages.curse_tick")
	if float(u["_curseDmgCount"]) >= 5.0:
		u["_cursed"] = false
		u["_curseAtk"] = 0.0
		u["_curseDmgCount"] = 0.0
		E.fx_float(u["x"], u["y"], "messages.curse_end")
	if u["hp"] != h0:
		E.rec_r("curse_tick", r0, {"u": u["id"], "dmg": h0 - u["hp"], "n": u["_curseDmgCount"]})


## tickPoisonMists — 라운드마다 안개(3×3) 안의 상대에게 시전자 ATK×0.3 (사망 안 함)   [기록: mist_tick]
func tick_poison_mists() -> void:
	var hp0: Dictionary = {}
	for u: Dictionary in S["units"]:
		hp0[u["id"]] = u["hp"]
	var r0: int = E.c.rng.calls
	var n: int = (S["poisonMists"] as Array).size() if typeof(S.get("poisonMists")) == TYPE_ARRAY else 0
	if n > 0:
		for m: Dictionary in S["poisonMists"]:
			var foe := "enemy" if m["team"] == "ally" else "ally"
			var dmg := maxf(1.0, Js.round_js(float(m["atk"]) * 0.3))
			for v: Dictionary in S["units"]:
				if v["team"] == foe and v["hp"] > 0 and absi(v["x"] - int(m["cx"])) <= 1 and absi(v["y"] - int(m["cy"])) <= 1:
					var d := minf(dmg, v["hp"] - 1.0)
					if d <= 0.0:
						continue
					v["hp"] = v["hp"] - d
			m["turns"] = float(m["turns"]) - 1.0
		var left: Array = []
		for m2: Dictionary in S["poisonMists"]:
			if float(m2["turns"]) > 0.0:
				left.append(m2)
		S["poisonMists"] = left
		E.fx_redraw_units()
	if n > 0:
		var hits: Array = []
		for u2: Dictionary in S["units"]:
			if hp0.has(u2["id"]) and u2["hp"] < float(hp0[u2["id"]]):
				hits.append([u2["id"], float(hp0[u2["id"]]) - u2["hp"]])
		E.rec_r("mist_tick", r0, {"mists": n, "hits": hits})
