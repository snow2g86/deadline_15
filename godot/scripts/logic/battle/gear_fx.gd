extends RefCounted
## 장비 전투 효과 — 웹 js/logic/gear.js 의 GearFX (calcDmg·EnchantFX.afterHit·applyDmgToAlly·EventBus 구독)
##  구독(on_*)은 engine.emit 이 웹과 같은 순서(GearFX → 화면 규칙 → 결과)로 부른다. E = battle_engine.gd

const Js := preload("res://scripts/logic/js.gd")

var E: Object
var S: Dictionary
var D: Dictionary


func _init(engine: Object) -> void:
	E = engine
	S = engine.S
	D = engine.D


func g(u: Variant, k: String) -> float:
	if u == null or typeof(u.get("gear")) != TYPE_DICTIONARY:
		return 0.0
	return Js.num(u["gear"].get(k))


func _float(u: Dictionary, txt: String) -> void:
	E.fx("float", {"x": u["x"], "y": u["y"], "text": txt})


## 전투 시작: 보호막·회복량·선공·파티 공격
func init_battle() -> void:
	var allies: Array = []
	for u: Dictionary in S["units"]:
		if u["team"] == "ally" and not Js.truthy(u.get("isSummon")):
			allies.append(u)
	var party_atk := 0.0
	for u2: Dictionary in allies:
		if g(u2, "start_shield") != 0.0:
			u2["_barrier"] = Js.round_js(u2["mhp"] * g(u2, "start_shield") / 100.0)
		if g(u2, "heal_pct") != 0.0:
			u2["_healMul"] = (float(u2["_healMul"]) if Js.truthy(u2.get("_healMul")) else 1.0) * (1.0 + g(u2, "heal_pct") / 100.0)
		if g(u2, "start_ap") != 0.0:
			u2["actionPow"] = 5.0
		party_atk = maxf(party_atk, g(u2, "party_atk"))
	if party_atk != 0.0:
		for u3: Dictionary in allies:
			u3["atk"] = Js.round_js(u3["atk"] * (1.0 + party_atk / 100.0))


## 파티 공명: 같은 직업 세트를 다 갖춘 클랜원 2명 이상 → 그 직업 조합 버프 강화
func resonance() -> void:
	var n: Dictionary = {}
	for u: Dictionary in S["units"]:
		if u["team"] == "ally" and Js.truthy(u.get("_fullSet")):
			n[u["_fullSet"]] = int(n.get(u["_fullSet"], 0)) + 1
	for s: Dictionary in S.get("_synergies", []):
		if not Js.truthy(s.get("cls")) or int(n.get(s["cls"], 0)) < 2:
			continue
		var e: Dictionary = {}
		for k: String in s["eff"].keys():
			var v: Variant = s["eff"][k]
			if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and ["atk", "def", "hp", "heal"].has(k) and float(v) > 1.0:
				e[k] = Js.round_js((1.0 + (float(v) - 1.0) * float(D["RESONANCE_MUL"])) * 100.0) / 100.0
			else:
				e[k] = v
		s["eff"] = e
		s["resonance"] = true


# ── EventBus 구독 (GearFX.bind) ──

func on_unit_killed(d: Dictionary) -> void:
	var k: Variant = d.get("killer")
	if k == null or k["hp"] <= 0 or not Js.truthy(k.get("gear")):
		return
	var kh := g(k, "kill_heal")
	if kh != 0.0:
		var h := minf(k["mhp"] - k["hp"], Js.round_js(k["mhp"] * kh / 100.0))
		if h > 0.0:
			k["hp"] = k["hp"] + h
			_float(k, "+" + E.num_str(h))
	var ap := g(k, "kill_ap")
	if ap != 0.0:
		k["actionPow"] = Js.num(k.get("actionPow")) + ap
		_float(k, "⚡+" + E.num_str(ap))


func on_turn_end(d: Dictionary) -> void:
	var u: Variant = d.get("unit")
	if u == null:
		return
	u["_movedDist"] = 0.0
	if not Js.truthy(u.get("gear")) or u["hp"] <= 0:
		return
	var rg := g(u, "regen")
	if rg != 0.0 and u["hp"] < u["mhp"]:
		var h := minf(u["mhp"] - u["hp"], maxf(1.0, Js.round_js(u["mhp"] * rg / 100.0)))
		u["hp"] = u["hp"] + h
		_float(u, "+" + E.num_str(h))
	var cl := g(u, "cleanse")
	if cl != 0.0 and E.c.rand("GearFX.cleanse") < cl / 100.0 and cleanse(u, 1):
		_float(u, "✨")


func on_unit_moved(d: Dictionary) -> void:
	var u: Variant = d.get("unit")
	if u == null or d.get("from") == null or d.get("to") == null:
		return
	u["_movedDist"] = Js.num(u.get("_movedDist")) + float(absi(int(d["from"]["x"]) - int(d["to"]["x"])) + absi(int(d["from"]["y"]) - int(d["to"]["y"])))


func on_skill_used(d: Dictionary) -> void:
	var u: Variant = d.get("unit") if d.get("unit") != null else d.get("caster")
	if u == null or not Js.truthy(u.get("gear")):
		return
	if g(u, "focus") != 0.0:
		u["_focus"] = true
	var sk: Variant = d.get("skill") if typeof(d.get("skill")) == TYPE_DICTIONARY else null
	var mf := g(u, "mana_free")
	if mf != 0.0 and sk != null and Js.truthy(sk.get("cost")) and E.c.rand("GearFX.mana_free") < mf / 100.0:
		u["res"] = minf(u["maxRes"], u["res"] + float(sk["cost"]))
		_float(u, "🌟")
	if g(u, "summon_pct") != 0.0 or g(u, "summon_turns") != 0.0:
		# 웹 setTimeout(0): 스킬 처리 직후(같은 콜백 뒤) 새로 생긴 소환수 강화
		E.later(0.0, _buff_summons.bind(u))


func _buff_summons(u: Dictionary) -> void:
	for s: Dictionary in S["units"]:
		if not Js.truthy(s.get("isSummon")) or not Js.same(s.get("summonerId"), u["id"]) or Js.truthy(s.get("_gearBuffed")):
			continue
		s["_gearBuffed"] = true
		var m := 1.0 + g(u, "summon_pct") / 100.0
		s["mhp"] = Js.round_js(s["mhp"] * m)
		s["hp"] = Js.round_js(s["hp"] * m)
		s["atk"] = Js.round_js(s["atk"] * m)
		s["def"] = Js.round_js(s["def"] * m)
		if s.has("summonTurns"):
			s["summonTurns"] = float(s["summonTurns"]) + g(u, "summon_turns")


func on_unit_healed(d: Dictionary) -> void:
	if d.get("healer") == null or d.get("target") == null or Js.truthy(d.get("isPotion")):
		return
	var hc := g(d["healer"], "heal_cleanse")
	if hc != 0.0 and E.c.rand("GearFX.heal_cleanse") < hc / 100.0 and cleanse(d["target"], 99 if hc >= 100.0 else 1):
		_float(d["target"], "✨")


func on_buff_applied(d: Dictionary) -> void:
	var b: Variant = d.get("buff")
	var tgt: Variant = d.get("unit")
	if b == null or tgt == null or tgt["team"] != "enemy" or not str(b.get("source", "")).begins_with("shaman") or Js.truthy(b.get("_gearMod")):
		return
	if not E.cb.is_debuff(b.get("type")):
		return
	var sh: Variant = null
	for u: Dictionary in S["units"]:
		if u["team"] == "ally" and u["hp"] > 0 and Js.truthy(u.get("gear")) and (Js.truthy(u["gear"].get("debuff_pct")) or Js.truthy(u["gear"].get("debuff_turns"))):
			if sh == null or Js.num(u["gear"].get("debuff_pct")) > Js.num(sh["gear"].get("debuff_pct")):
				sh = u
	if sh == null:
		return
	b["_gearMod"] = true
	if Js.truthy(b.get("value")):
		b["value"] = Js.round_js(float(b["value"]) * (1.0 + g(sh, "debuff_pct") / 100.0))
	b["duration"] = (float(b["duration"]) if Js.truthy(b.get("duration")) else 1.0) + g(sh, "debuff_turns")


## 디버프 해제 (n개, 99 = 전부)
func cleanse(u: Dictionary, n: int) -> bool:
	var done := 0
	if typeof(u.get("buffs")) == TYPE_ARRAY:
		var arr: Array = u["buffs"]
		var i := arr.size() - 1
		while i >= 0 and done < n:
			if E.cb.is_debuff(arr[i].get("type")):
				arr.remove_at(i)
				done += 1
			i -= 1
	for k: String in ["stunned", "frozen", "disarmed", "_rootedTurns", "_bleedTurns"]:
		if done < n and Js.num(u.get(k)) > 0:
			u[k] = 0.0
			done += 1
	return done > 0


## 피해 보정 (calcDmg 끝) — 치명타 판정만 난수
func mod(a: Variant, t: Variant, dmg: float) -> float:
	if a == null or t == null:
		return dmg
	var m := 1.0
	if Js.truthy(a.get("gear")):
		var cr := g(a, "crit")
		if cr != 0.0 and E.c.rand("GearFX.mod.crit") < cr / 100.0:
			m *= 1.5
			a["_lastCrit"] = true
		if g(a, "first_crit") != 0.0 and not Js.truthy(a.get("_firstHit")):
			m *= 1.0 + g(a, "first_crit") / 100.0
			a["_lastCrit"] = true
		if g(a, "desperate") != 0.0 and a["hp"] <= a["mhp"] * 0.3:
			m *= 1.0 + g(a, "desperate") / 100.0
		if g(a, "charge") != 0.0 and Js.num(a.get("_movedDist")) >= 2:
			m *= 1.0 + g(a, "charge") / 100.0
		if g(a, "focus") != 0.0 and Js.truthy(a.get("_focus")):
			m *= 1.0 + g(a, "focus") / 100.0
		var lt: Variant = a.get("_lastTactic")
		if g(a, "backstab") != 0.0 and Js.truthy(lt) and Js.truthy(lt.get("tags")) and (lt["tags"] as Array).has("back"):
			m *= 1.0 + g(a, "backstab") / 100.0
		if g(a, "combo") != 0.0 and Js.same(a.get("_comboTgt"), t["id"]):
			m *= 1.0 + g(a, "combo") / 100.0 * minf(5.0, Js.num(a.get("_comboN")))
		if g(a, "stack_atk") != 0.0:
			m *= 1.0 + g(a, "stack_atk") / 100.0 * minf(5.0, Js.num(a.get("_oath")))
	if Js.truthy(t.get("gear")) and g(t, "dmg_red") != 0.0:
		m *= 1.0 - minf(80.0, g(t, "dmg_red")) / 100.0
	var aura := 0.0
	for v: Dictionary in S["units"]:
		if v["hp"] > 0 and v["id"] != t["id"] and v["team"] == t["team"] and Js.truthy(v.get("gear")) and Js.truthy(v["gear"].get("guard_aura")) \
				and absi(v["x"] - t["x"]) + absi(v["y"] - t["y"]) == 1:
			aura = maxf(aura, float(v["gear"]["guard_aura"]))
	if aura != 0.0:
		m *= 1.0 - minf(50.0, aura) / 100.0
	return dmg if m == 1.0 else maxf(1.0, Js.round_js(dmg * m))


## 명중 뒤 (EnchantFX.afterHit 끝): 누적·연타·분노·폭발·관통
func after_hit(a: Variant, t: Variant, dmg: float) -> void:
	if a == null or not Js.truthy(a.get("gear")) or t == null:
		return
	a["_firstHit"] = true
	a["_focus"] = false
	if g(a, "combo") != 0.0:
		if Js.same(a.get("_comboTgt"), t["id"]):
			a["_comboN"] = Js.num(a.get("_comboN")) + 1.0
		else:
			a["_comboTgt"] = t["id"]
			a["_comboN"] = 1.0
	if g(a, "stack_atk") != 0.0:
		a["_oath"] = minf(5.0, Js.num(a.get("_oath")) + 1.0)
	if g(a, "fury_gain") != 0.0 and a.get("resType") == "fury":
		a["res"] = minf(a["maxRes"], a["res"] + g(a, "fury_gain"))
	var hit_at := func(x: int, y: int, pct: float) -> void:
		var v: Variant = E.gu.u_at(x, y)
		if v == null or v["hp"] <= 0 or v["team"] != t["team"] or v["id"] == t["id"]:
			return
		var d2 := maxf(1.0, Js.round_js(dmg * pct / 100.0))
		v["hp"] = maxf(0.0, v["hp"] - d2)
		E.emit("unit_attacked", {"attacker": a, "target": v, "damage": d2, "isSplash": true})
		if v["hp"] <= 0:
			E.emit("unit_killed", {"killer": a, "target": v})
	var bl := g(a, "blast")
	if bl != 0.0:
		for d: Array in [[0, -1], [0, 1], [-1, 0], [1, 0]]:
			hit_at.call(t["x"] + d[0], t["y"] + d[1], bl)
	var pl := g(a, "pierce_line")
	if pl != 0.0:
		var dx: int = t["x"] - a["x"]
		var dy: int = t["y"] - a["y"]
		if absi(dx) >= absi(dy):
			dx = Js.sign_js(dx)
			dy = 0
		else:
			dy = Js.sign_js(dy)
			dx = 0
		if dx != 0 or dy != 0:
			hit_at.call(t["x"] + dx, t["y"] + dy, pl)


## 클랜원이 받는 피해 흡수: 보호막 → 성자의 눈물
func absorb(u: Variant, dmg: float) -> float:
	if u == null or dmg <= 0.0:
		return dmg
	if Js.num(u.get("_barrier")) > 0:
		var a := minf(float(u["_barrier"]), dmg)
		u["_barrier"] = float(u["_barrier"]) - a
		dmg -= a
		_float(u, "🛡️-" + E.num_str(a))
	if dmg >= u["hp"] and g(u, "last_stand") != 0.0 and not Js.truthy(u.get("_lastStandUsed")):
		u["_lastStandUsed"] = true
		u["hp"] = maxf(1.0, Js.round_js(u["mhp"] * g(u, "last_stand") / 100.0))
		_float(u, "💧")
		return 0.0
	return dmg


func intercept(blk: Variant, dmg: float) -> float:
	if blk == null or not Js.truthy(blk.get("gear")):
		return dmg
	var r := g(blk, "intercept_red")
	if r != 0.0:
		dmg = maxf(1.0, Js.round_js(dmg * (1.0 - minf(80.0, r) / 100.0)))
	if g(blk, "intercept_fury") != 0.0 and blk.get("resType") == "fury":
		blk["res"] = minf(blk["maxRes"], blk["res"] + g(blk, "intercept_fury"))
	return dmg


func counter_mul(u: Dictionary) -> float:
	return 1.0 + g(u, "counter_up") / 100.0


func knock_resist(u: Dictionary) -> float:
	if g(u, "knock_immune") != 0.0:
		return 1.0
	return g(u, "knock_res") / 100.0


func hazard_mul(u: Dictionary) -> float:
	return 1.0 - minf(90.0, g(u, "hazard_res")) / 100.0
