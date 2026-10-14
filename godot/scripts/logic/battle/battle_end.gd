extends RefCounted
## 전투 끝 보상 — 웹 js/battle/end.js (BattleEnd.onBattleEnd: 경험치·골드·별점·첫 클리어 신규 클랜원·영혼석·전설·룬·스킬북·요일 던전)
##  웹은 결과 화면(Renderer.showRes)에서 부르지만 규칙이므로 여기 둔다 (engine 의 battle_end 구독). E = battle_engine.gd

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const Gear := preload("res://scripts/logic/gear.gd")
const Synergy := preload("res://scripts/logic/synergy.gd")

var E: Object
var S: Dictionary
var D: Dictionary


func _init(engine: Object) -> void:
	E = engine
	S = engine.S
	D = engine.D


func on_battle_end(win: bool) -> void:
	var c: Object = E.c
	var kill_pool: float = S["_killExpPool"]
	var survivors: Array = []
	for u: Dictionary in S["units"]:
		if u["team"] == "ally" and u["hp"] > 0 and Js.truthy(u.get("uid")):
			survivors.append(u)
	var kill_each := floorf(kill_pool / float(survivors.size())) if not survivors.is_empty() else 0.0
	S["_expResults"] = []
	for u2: Dictionary in survivors:
		var act_e: float = Js.num(S["battleExp"].get(u2["uid"]))
		var exp_mul := 1.0 + Js.num(u2["gear"].get("exp_pct") if Js.truthy(u2.get("gear")) else 0.0) / 100.0
		var total := Js.round_js((act_e + kill_each) * exp_mul)
		if total == 0.0:
			continue
		var r := Profile.gain_exp(c, u2["uid"], total)
		(S["_expResults"] as Array).append({"uid": u2["uid"], "exp": total, "actExp": act_e, "killExp": kill_each, "leveled": r["leveled"], "prevLv": r["prevLv"]})
	S["_totalExp"] = kill_pool
	S["_deadEnemyCount"] = S["_killCount"]
	S["_gearDrops"] = []
	var st: Variant = S["cStage"]
	if st != null and Js.truthy(st.get("daily")):
		S["_soulReward"] = null
		if win:
			var nf := Synergy.frags(S["_synergies"], float(st["daily"]["frags"]))
			Profile.soul_add(c, "frag", st["daily"]["cls"], nf)
			S["_soulReward"] = {"kind": "frag", "cls": st["daily"]["cls"], "n": nf}
			S["_runeDrop"] = Gear.rune_add(c, Gear.rune_random(c)) if c.rand("onBattleEnd.rune") < float(D["RUNE_DROP_CHANCE"]) else null
			_daily_gear()
		for uid: Variant in S["_deadAllyUids"]:
			Profile.mark_dead(c, uid)
		Profile.clear_battle(c)
		return
	if win:
		var sid: float = float(st["id"]) if st != null else 0.0
		var EC: Dictionary = D["ECON"]
		var reward: float = float(EC["win"][0]) + float(EC["win"][1]) * sid
		var fc_bonus := 0.0
		if S["practiceMode"]:
			reward = floorf(reward * float(EC["practiceMul"]))
			S["_practiceMode"] = true
			S["_baseReward"] = reward
		else:
			var is_first: bool = st != null and Js.index_of(S["cleared"], st["id"]) < 0
			if is_first:
				fc_bonus = float(EC["firstClear"][0]) + float(EC["firstClear"][1]) * sid
				S["_firstClearBonus"] = fc_bonus
			if st != null and Js.index_of(S["cleared"], st["id"]) < 0:
				(S["cleared"] as Array).append(st["id"])
			S["_baseReward"] = reward
			S["_bonusReward"] = fc_bonus
		S["_starResult"] = null
		if not S["practiceMode"] and st != null:
			var limit := Profile.star_turn_limit(st)
			var flags := [1, 1 if (S["_deadAllyUids"] as Array).is_empty() else 0, 1 if float(S["turn"]) <= limit else 0]
			var r2 := Profile.save_stage_stars(c, st["id"], flags)
			var each: float = float(EC["star"][0]) + float(EC["star"][1]) * float(st["id"])
			var nnew := 0
			for i: Variant in r2["newly"]:
				if int(i) > 0:
					nnew += 1
			var bonus := float(nnew) * each
			S["_starResult"] = {"flags": flags, "merged": r2["merged"], "newly": r2["newly"], "limit": limit, "turn": S["turn"], "bonus": bonus}
			S["gold"] = float(S["gold"]) + bonus
		S["gold"] = float(S["gold"]) + reward + fc_bonus
		Profile.save_gold(c, S["gold"], (S["cleared"] as Array).duplicate())
		if not S["practiceMode"]:
			var is_fc: bool = st != null and Js.truthy(S.get("_firstClearBonus"))
			if is_fc:
				var stage_id: Variant = st["id"]
				var give_unit: bool = Js.index_of(EC["freeUnitStages"], stage_id) != -1 or Js.truthy(st.get("boss"))
				if give_unit:
					_first_clear_unit()
			S["_soulReward"] = null
			if Js.truthy(st.get("boss")):
				var pcls: Array = []
				for u3: Dictionary in S["units"]:
					if u3["team"] == "ally" and Js.truthy(u3.get("uid")) and not Js.truthy(u3.get("isSummon")):
						pcls.append(u3["cls"])
				var cls: String = pcls[int(floorf(c.rand("onBattleEnd.soul") * pcls.size()))] if not pcls.is_empty() else st["boss"]["cls"]
				var SO: Dictionary = D["SOUL"]
				if is_fc:
					Profile.soul_add(c, "stone", cls, float(SO["bossFirstStone"]))
					S["_soulReward"] = {"kind": "stone", "cls": cls, "n": SO["bossFirstStone"]}
				else:
					var nf2 := Synergy.frags(S["_synergies"], float(SO["bossRepeatFrags"]))
					Profile.soul_add(c, "frag", cls, nf2)
					S["_soulReward"] = {"kind": "frag", "cls": cls, "n": nf2}
			var GD: Dictionary = D["GEAR_DROP"]
			if Js.truthy(st.get("boss")) and c.rand("onBattleEnd.legend") < float(GD["bossLegend"]["first"] if is_fc else GD["bossLegend"]["repeat"]):
				var it := Gear.give(c, Gear.make_legend(c))
				(S["_gearDrops"] as Array).append({"templateId": it["templateId"], "legend": true})
			S["_runeDrop"] = Gear.rune_add(c, Gear.rune_random(c)) if c.rand("onBattleEnd.rune") < float(D["RUNE_DROP_CHANCE"]) else null
			if c.rand("onBattleEnd.book") < 0.05:
				var ls_keys: Array = (D["LEARNABLE_SKILLS"] as Dictionary).keys()
				if not ls_keys.is_empty():
					var skd: Dictionary = D["LEARNABLE_SKILLS"][ls_keys[int(floorf(c.rand("onBattleEnd.book") * ls_keys.size()))]]
					var inv := Profile.load_inventory(c)
					inv.append({"id": skd["id"], "cls": skd["cls"], "lv": 1})
					Profile.save_inventory(c, inv)
					S["_droppedBook"] = skd["id"]
	if S["practiceMode"]:
		S["_autoRevivedCount"] = (S["_deadAllyUids"] as Array).size()
		S["_deadAllyUids"] = []
	else:
		for uid2: Variant in S["_deadAllyUids"]:
			Profile.mark_dead(c, uid2)
	Profile.clear_battle(c)


## 첫 클리어 신규 클랜원 (직업·잠재력·이름·성별 난수). actionRec 은 없음 → 다음 getRoster 가 보정(난수)
func _first_clear_unit() -> void:
	var c: Object = E.c
	var JAB: Dictionary = D["JAB"]
	var non_novice: Array = []
	for k: String in JAB.keys():
		if k != "novice" and not k.begins_with("summon_") and not Js.truthy(JAB[k].get("unique")):
			non_novice.append(k)
	var r_cls: String = non_novice[int(floorf(c.rand("onBattleEnd.newUnit.cls") * non_novice.size()))]
	var d: Dictionary = JAB[r_cls]
	var rd: Variant = c.store.get_json(Profile.ROSTER_KEY)
	if typeof(rd) != TYPE_DICTIONARY:
		return
	var g: Dictionary = d["growth"]
	var roll := func(mm: Array) -> float: return Js.to_fixed_num(float(mm[0]) + c.rand("onBattleEnd.newUnit.pot") * (float(mm[1]) - float(mm[0])), 1)
	var names: Dictionary = {}
	for ch: Dictionary in rd["chars"]:
		names[str(ch.get("nameId"))] = 1
	var name_id: int
	while true:
		name_id = int(floorf(c.rand("onBattleEnd.newUnit.name") * 300.0))
		if not names.has(str(name_id)):
			break
	var uid: int = int(rd["nextId"])
	rd["nextId"] = uid + 1
	var pot_hp: float = roll.call(g["hp"])
	var pot_atk: float = roll.call(g["atk"])
	var pot_def: float = roll.call(g["def"])
	var ch2 := {
		"uid": uid, "cls": r_cls, "nameId": name_id, "lv": 1, "exp": 0.0, "dead": false,
		"hp": d["base"]["hp"], "atk": d["base"]["atk"], "def": d["base"]["def"],
		"move": d["base"]["move"], "range": d["base"]["range"],
		"pot": {"hp": pot_hp, "atk": pot_atk, "def": pot_def},
		"gender": Profile.random_gender(c),
	}
	(rd["chars"] as Array).append(ch2)
	c.store.set_json(Profile.ROSTER_KEY, rd)
	S["_firstClearUnit"] = ch2


## 요일 던전 장비 보상
func _daily_gear() -> void:
	var c: Object = E.c
	var dl: Dictionary = S["cStage"]["daily"]
	var tier: String = dl["tier"]
	var GD: Dictionary = D["GEAR_DROP"]
	var st_n: float = float(GD["dailyStones"][tier]) if Js.truthy(GD["dailyStones"].get(tier)) else 2.0
	Profile.mats_add(c, "stone", st_n)
	(S["_gearDrops"] as Array).append({"stone": st_n})
	if c.rand("_dailyGear.set") < Js.num(GD["dailySet"].get(tier)):
		var rar: Variant = GD["setRarity"].get(tier)
		var it := Gear.give(c, Gear.make_set_piece(c, dl["cls"], null, rar if Js.truthy(rar) else "rare"))
		(S["_gearDrops"] as Array).append({"templateId": it["templateId"]})
	if tier == "hell" and c.rand("_dailyGear.legend") < float(GD["dailyLegendHell"]):
		var it2 := Gear.give(c, Gear.make_legend(c))
		(S["_gearDrops"] as Array).append({"templateId": it2["templateId"], "legend": true})


## battle-sim 의 rewards 요약 (황금 기록 end.rewards 와 같은 형식)
func rewards_summary(win: bool) -> Dictionary:
	var exp: Array = []
	for e: Dictionary in S.get("_expResults", []):
		exp.append({"uid": e["uid"], "exp": e["exp"], "actExp": e["actExp"], "killExp": e["killExp"], "leveled": e["leveled"]})
	var fcu: Variant = S.get("_firstClearUnit")
	return {
		"win": win, "exp": exp, "killPool": S.get("_totalExp"), "kills": S.get("_deadEnemyCount"), "gold": S["gold"],
		"baseReward": S.get("_baseReward", 0.0) if Js.truthy(S.get("_baseReward")) else 0.0,
		"bonusReward": S.get("_bonusReward", 0.0) if Js.truthy(S.get("_bonusReward")) else 0.0,
		"stars": Js.deep(S.get("_starResult")), "soul": Js.deep(S.get("_soulReward")), "rune": S.get("_runeDrop"), "book": S.get("_droppedBook"),
		"newUnit": fcu["cls"] if fcu != null else null, "gearDrops": (S["_gearDrops"] as Array).size(),
		"deadAllies": (S["_deadAllyUids"] as Array).duplicate(), "autoRevived": S["_autoRevivedCount"] if Js.truthy(S.get("_autoRevivedCount")) else 0,
	}
