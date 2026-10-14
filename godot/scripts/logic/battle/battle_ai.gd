extends RefCounted
## 적 AI — 웹 js/battle/ai.js
##  웹의 async/await 는 동기 함수로 옮겼다. 적 차례 동안 대기열에 다른 작업이 없으므로 순서는 같고,
##  웹의 await sl() 자리(멈춤 지점)는 `if E._sl(): return` — 그 지점에서 전투가 이미 끝났으면 웹처럼 그 뒤를 실행하지 않는다.
##  _sl() 뒤에 부른 함수가 멈췄으면(E._aborted) 호출한 쪽도 바로 돌아간다. E = battle_engine.gd

const Js := preload("res://scripts/logic/js.gd")

var E: Object
var S: Dictionary
var D: Dictionary


func _init(engine: Object) -> void:
	E = engine
	S = engine.S
	D = engine.D


func _profile(cls: String) -> Dictionary:
	var P: Dictionary = D["AI_PROFILES"]
	return P[cls] if P.has(cls) else P["novice"]


func _mistake() -> float:
	return float(D["AI_MISTAKE_CHANCE"])


func _stealth(u: Dictionary) -> bool:
	return E.is_stealthed(u)


## 정렬 (JS sort 안정) 결과의 첫째 = 비교값이 가장 작은 첫 원소
func _min_by(arr: Array, key: Callable) -> Variant:
	var best: Variant = null
	var bk := 0.0
	for v: Variant in arr:
		var k: float = key.call(v)
		if best == null or k < bk:
			best = v
			bk = k
	return best


# ── 타깃 선택 ──

func select_target(u: Dictionary, in_range: Array, profile: Dictionary) -> Variant:
	if in_range.is_empty():
		return null
	if E.c.rand("selectTarget.mistake") < _mistake():
		return in_range[int(floorf(E.c.rand("selectTarget.pick") * in_range.size()))]
	var p: String = profile["targetPriority"]
	if p == "low_hp":
		var kl: Array = []
		for a: Dictionary in in_range:
			if a["hp"] <= maxf(1.0, u["atk"] - a["def"]):
				kl.append(a)
		if not kl.is_empty():
			return _min_by(kl, func(a: Dictionary) -> float: return a["hp"])
		return _min_by(in_range, func(a: Dictionary) -> float: return a["hp"])
	if p == "nearest":
		return _min_by(in_range, func(a: Dictionary) -> float: return float(Js.mh(u["x"], u["y"], a["x"], a["y"])))
	if p == "nearest_threat":
		var o: Dictionary = u["origSpawn"] if Js.truthy(u.get("origSpawn")) else {"x": u["x"], "y": u["y"]}
		return _min_by(in_range, func(a: Dictionary) -> float: return float(Js.mh(o["x"], o["y"], a["x"], a["y"])))
	if p == "random_weak":
		var s: Array = Js.stable_sort(in_range.duplicate(), func(a: Dictionary, b: Dictionary) -> float: return a["hp"] - b["hp"])
		var w: Array = s.slice(0, int(ceilf(float(s.size()) / 2.0)))
		return w[int(floorf(E.c.rand("selectTarget.random_weak") * w.size()))]
	if p == "cluster":
		var bt: Variant = null
		var bn := 0
		for tgt: Dictionary in in_range:
			var n := 0
			for a2: Dictionary in E.gu.alive("ally"):
				if a2["id"] != tgt["id"] and Js.mh(tgt["x"], tgt["y"], a2["x"], a2["y"]) <= 2:
					n += 1
			if n > bn:
				bn = n
				bt = tgt
		return bt if bt != null else in_range[0]
	return in_range[int(floorf(E.c.rand("selectTarget.random") * in_range.size()))]


# ── 스킬 ──

func try_use_skill(u: Dictionary, profile: Dictionary) -> bool:
	var p: float = Js.num(profile.get("skillUseProbability"))
	if p == 0.0 or E.c.rand("tryUseSkill") > p:
		return false
	var al: Array = E.gu.alive("ally")
	if al.is_empty():
		return false
	if u["cls"] == "warrior" and u["res"] >= 3:
		var in_r: Array = []
		for cc: Dictionary in E.gu.atk_cells(u):
			var v: Variant = E.gu.u_at(cc["x"], cc["y"])
			if v != null and v["team"] == "ally" and not _stealth(v):
				in_r.append(E.gu.u_at(cc["x"], cc["y"]))
		for tgt: Dictionary in in_r:
			var dmg := maxf(1.0, Js.round_js(u["atk"] * 1.5 - tgt["def"]))
			if tgt["hp"] <= dmg:
				u["res"] = u["res"] - 3.0
				tgt["hp"] = 0.0
				E.emit("unit_attacked", {"attacker": u, "target": tgt, "damage": dmg, "counter": false})
				E.emit("unit_killed", {"killer": u, "target": tgt})
				E.gu.rm_dead()
				u["ha"] = true
				E.fx_redraw_units()
				return true
	if u["cls"] == "brawler" and u["res"] >= 30:
		var high: Array = []
		for v2: Dictionary in al:
			if Js.mh(u["x"], u["y"], v2["x"], v2["y"]) <= 1 and v2["atk"] >= 25 and not E.buff_has(v2, "disarm"):
				high.append(v2)
		if not high.is_empty():
			var t2: Dictionary = high[0]
			u["res"] = u["res"] - 30.0
			E.buff_apply(t2, {"type": "disarm", "duration": 3.0, "icon": "🤛", "source": "brawler_disarm"})
			E.emit("skill_used", {"caster": u, "skill": "brawler_disarm", "target": t2})
			u["ha"] = true
			if E._sl(200):
				return true
			return true
	if u["cls"] == "mage" and u["res"] >= 40:
		var target_cell: Variant = null
		var max_c := 0
		for y in range(u["y"] - 1, u["y"] + 2):
			for x in range(u["x"] - 1, u["x"] + 2):
				if x == u["x"] and y == u["y"]:
					continue
				var cnt := 0
				for a: Dictionary in al:
					if not _stealth(a) and absi(a["x"] - x) <= 1 and absi(a["y"] - y) <= 1:
						cnt += 1
				if cnt >= 2 and cnt > max_c:
					max_c = cnt
					target_cell = {"x": x, "y": y}
		if target_cell != null:
			u["res"] = u["res"] - 40.0
			for y2 in range(int(target_cell["y"]) - 1, int(target_cell["y"]) + 2):
				for x2 in range(int(target_cell["x"]) - 1, int(target_cell["x"]) + 2):
					var tg: Variant = E.gu.u_at(x2, y2)
					if tg != null and tg["team"] == "ally" and not _stealth(tg):
						var d2: float = E.calc_dmg(u, tg)
						tg["hp"] = maxf(0.0, tg["hp"] - d2)
						E.emit("unit_attacked", {"attacker": u, "target": tg, "damage": d2, "counter": false, "isAoE": true})
						if tg["hp"] <= 0:
							E.emit("unit_killed", {"killer": u, "target": tg})
			E.emit("skill_used", {"caster": u, "skill": "mage_fireball", "targetCell": target_cell})
			u["ha"] = true
			if E._sl(300):
				return true
			E.gu.rm_dead()
			E.fx_redraw_units()
			return true
	return false


# ── 전술 이동 점수 (후보 칸마다 난수 1회) ──

func _tactic_score(u: Dictionary, m: Dictionary, al: Array) -> float:
	var tl: Variant = E.gu.tile(m["x"], m["y"])
	var me := {"id": u["id"], "team": u["team"], "cls": u["cls"], "x": m["x"], "y": m["y"]}
	var rng: float = float(u["range"]) + (float(D["TACTIC"]["highRange"]) if tl == "hill" and float(u["range"]) > 1.0 else 0.0)
	var best := -1.0
	for a: Dictionary in al:
		if a["hp"] <= 0 or _stealth(a) or float(Js.mh(m["x"], m["y"], a["x"], a["y"])) > rng:
			continue
		if E.gu.cover_of(me, a) != null or E.gu.intercept_of(me, a) != null:
			continue
		var tb: Dictionary = E.gu.tactic_bonus(me, a)
		var killable: bool = a["hp"] <= maxf(1.0, Js.round_js((u["atk"] - a["def"]) * float(tb["mul"])))
		best = maxf(best, (float(tb["mul"]) - 1.0) * 100.0 + (25.0 if killable else 0.0))
	var s := 40.0 + best if best >= 0.0 else 0.0
	if E.gu.in_zoc(u, m["x"], m["y"]) and best < 0.0:
		s -= 15.0
	if tl == "forest":
		s += 5.0
	if tl == "hill" and float(u["range"]) > 1.0:
		s += 8.0
	if tl == "shallow":
		s -= 8.0
	if best < 0.0:
		for a2: Dictionary in S["units"]:
			if a2["hp"] > 0 and Js.truthy(a2.get("_overwatch")) and a2["team"] != u["team"] and float(Js.mh(a2["x"], a2["y"], m["x"], m["y"])) <= float(a2["range"]):
				s -= 20.0
				break
	if E.gu.near_lava(m["x"], m["y"]):
		s -= 10.0
	if Js.truthy(u.get("_intent")):
		var it: Variant = null
		for a3: Dictionary in al:
			if Js.same(a3["id"], u["_intent"]):
				it = a3
				break
		if it != null and it["hp"] > 0 and float(Js.mh(m["x"], m["y"], it["x"], it["y"])) <= rng and E.gu.cover_of(me, it) == null and E.gu.intercept_of(me, it) == null:
			s += 30.0
	return s * 0.3 if E.c.rand("_tacticScore") < _mistake() else s


# ── 행동 예고 (결정적, 난수 없음) ──

func plan_intents() -> void:
	var al: Array = []
	for a: Dictionary in E.gu.alive("ally"):
		if not _stealth(a):
			al.append(a)
	var defense: bool = S["cStage"] != null and S["cStage"].get("style") == "defense"
	for e: Dictionary in S["units"]:
		if e["team"] != "enemy":
			continue
		e["_intent"] = null
		if e["hp"] <= 0 or al.is_empty() or E.gu.is_cc(e):
			continue
		var profile := _profile(e["cls"])
		if profile["targetPriority"] == "never" or (Js.truthy(profile.get("avoidCombat")) and e["hp"] > e["mhp"] * 0.7):
			continue
		var o: Dictionary = e["origSpawn"] if Js.truthy(e.get("origSpawn")) else {"x": e["x"], "y": e["y"]}
		var lim := 15 if defense else 5
		if profile["style"] == "defensive":
			lim = 12 if defense else 3
		if profile["style"] == "support":
			lim = 10 if defense else 2
		var can_move: bool = not E.buff_has(e, "root") and not (Js.num(e.get("_rootedTurns")) > 0) and (Js.truthy(e.get("isBoss")) or Js.mh(e["x"], e["y"], o["x"], o["y"]) < lim)
		var spots: Array = [{"x": e["x"], "y": e["y"]}]
		if can_move:
			for m: Dictionary in E.gu.e_mv_cells(e):
				if Js.truthy(e.get("isBoss")) or Js.mh(m["x"], m["y"], o["x"], o["y"]) <= lim:
					spots.append(m)
		var best: Variant = null
		var bs := -INF
		for p: Dictionary in spots:
			var tl: Variant = E.gu.tile(p["x"], p["y"])
			var rng: float = float(e["range"]) + (float(D["TACTIC"]["highRange"]) if tl == "hill" and float(e["range"]) > 1.0 else 0.0)
			var me := {"id": e["id"], "team": e["team"], "cls": e["cls"], "x": p["x"], "y": p["y"]}
			for a2: Dictionary in al:
				if float(Js.mh(p["x"], p["y"], a2["x"], a2["y"])) > rng or E.gu.cover_of(me, a2) != null or E.gu.intercept_of(me, a2) != null:
					continue
				var tb: Dictionary = E.gu.tactic_bonus(me, a2)
				var dmg := maxf(1.0, Js.round_js((e["atk"] - a2["def"]) * float(tb["mul"])))
				var sc: float = (1000.0 if a2["hp"] <= dmg else 0.0) + (float(tb["mul"]) - 1.0) * 100.0 - a2["hp"] / a2["mhp"] * 50.0 - (0.0 if (p["x"] == e["x"] and p["y"] == e["y"]) else 1.0)
				if sc > bs:
					bs = sc
					best = a2
		e["_intent"] = best["id"] if best != null else null


func _visible_allies(u: Dictionary) -> Array:
	var all: Array = []
	for cc: Dictionary in E.gu.atk_cells(u):
		var v: Variant = E.gu.u_at(cc["x"], cc["y"])
		if v != null and v["team"] == "ally" and not _stealth(v) and E.gu.cover_of(u, v) == null:
			all.append(E.gu.u_at(cc["x"], cc["y"]))
	var clear: Array = []
	for v2: Dictionary in all:
		if E.gu.intercept_of(u, v2) == null:
			clear.append(v2)
	return clear if not clear.is_empty() else all


func _try_attack(u: Dictionary, targets: Array, profile: Dictionary) -> bool:
	if targets.is_empty() or profile["targetPriority"] == "never":
		return false
	if try_use_skill(u, profile):
		return true
	if E._aborted:
		return true
	var target: Variant = null
	if Js.truthy(u.get("_intent")):
		for a: Dictionary in targets:
			if Js.same(a["id"], u["_intent"]):
				target = a
				break
	if target == null and E.c.rand("_tryAttack") >= _mistake():
		var bs := 29.0
		for a2: Dictionary in targets:
			var tb: Dictionary = E.gu.tactic_bonus(u, a2)
			var sc: float = (float(tb["mul"]) - 1.0) * 100.0 + (100.0 if a2["hp"] <= maxf(1.0, Js.round_js((u["atk"] - a2["def"]) * float(tb["mul"]))) else 0.0)
			if sc > bs:
				bs = sc
				target = a2
	if target == null:
		target = select_target(u, targets, profile)
	if target != null:
		e_atk_async(u, target)
		return true
	return false


## 메인 진입점
func e_ai(u: Dictionary) -> void:
	var al: Array = E.gu.alive("ally")
	if al.is_empty() and not E.has_ally_wall():
		return
	var profile := _profile(u["cls"])
	if Js.truthy(profile.get("avoidCombat")) and u["hp"] > u["mhp"] * 0.7:
		e_mv(u, al)
		return
	if _try_attack(u, _visible_allies(u), profile):
		return
	if E._aborted:
		return
	if try_gate_atk(u):
		E._sl(250)
		return
	if try_wall_climb(u):
		return
	if E._aborted:
		return
	e_mv(u, al)
	if E._aborted:
		return
	if E.fsm == E.BATTLE_END or u["hp"] <= 0:
		return
	if Js.truthy(profile.get("avoidCombat")) and u["hp"] > u["mhp"] * 0.7:
		return
	if E._sl(200):
		return
	if _try_attack(u, _visible_allies(u), profile):
		return
	if E._aborted:
		return
	if try_siege_item_use(u):
		return
	if try_gate_atk(u):
		return
	if profile["style"] == "defensive":
		u["_defend"] = true
		E.fx_float(u["x"], u["y"], "messages.defend_on")


# ── 공성 아이템 ──

func analyze_situation(u: Dictionary) -> Dictionary:
	var al: Array = E.gu.alive("ally")
	var hp_pct: float = u["hp"] / u["mhp"]
	var nearby := 0
	for a: Dictionary in al:
		if not _stealth(a) and Js.mh(u["x"], u["y"], a["x"], a["y"]) <= 2:
			nearby += 1
	var move_opts: int = (E.gu.e_mv_cells(u) as Array).size()
	var nt := 0
	for d: Array in [[0, -1], [0, 1], [-1, 0], [1, 0]]:
		var nx: int = u["x"] + d[0]
		var ny: int = u["y"] + d[1]
		if nx >= 0 and nx < int(D["COLS"]) and ny >= 0 and ny < int(D["ROWS"]):
			var tl: Variant = S["ter"][ny][nx]
			if tl == "wall" or tl == "gate" or tl == "rock":
				nt += 1
	var type := "safe"
	if hp_pct < 0.3:
		type = "weakened"
	elif nearby >= 3:
		type = "surrounded"
	elif move_opts == 0:
		type = "blocked"
	elif nearby > 0:
		type = "distant"
	var severity := (1.0 - hp_pct) * 0.4 + (float(nearby) / 5.0) * 0.4 + (1.0 - float(move_opts) / 4.0) * 0.2
	return {"type": type, "severity": maxf(0.0, minf(1.0, severity)), "blockCount": 4 - move_opts, "nearbyAllies": nearby, "hpPercent": hp_pct, "nearbyTerrain": nt}


func select_siege_item(u: Dictionary, situation: Dictionary) -> Variant:
	if typeof(u.get("siegeItems")) != TYPE_ARRAY or (u["siegeItems"] as Array).is_empty():
		return null
	var available: Array = []
	for i: Dictionary in u["siegeItems"]:
		if float(i["cooldown"]) == 0.0:
			available.append(i)
	if available.is_empty():
		return null
	var pm := {
		"blocked": {"bomb": 90.0, "ladder": 70.0, "detour": 80.0},
		"distant": {"detour": 80.0, "bomb": 60.0, "ladder": 50.0},
		"weakened": {"shield": 100.0, "evasion": 80.0},
		"surrounded": {"evasion": 90.0, "bomb": 70.0, "detour": 60.0},
		"safe": {},
	}
	var priors: Dictionary = pm.get(situation["type"], {})
	var best: Variant = null
	var best_score := -1.0
	for item: Dictionary in available:
		var score: float = float(priors.get(item["type"], 0.0)) + E.c.rand("selectSiegeItem") * 10.0
		if score > best_score:
			best_score = score
			best = item
	return best


func _siege_bomb(u: Dictionary) -> bool:
	var best: Variant = null
	var best_d := INF
	for r in int(D["ROWS"]):
		for cc in int(D["COLS"]):
			var d := Js.mh(u["x"], u["y"], cc, r)
			if d < 1 or d > 3:
				continue
			var tl: Variant = S["ter"][r][cc]
			if tl == "wall" or tl == "gate" or tl == "rock":
				if float(d) < best_d:
					best_d = float(d)
					best = {"x": cc, "y": r}
	if best == null:
		return false
	S["ter"][best["y"]][best["x"]] = "plain"
	var wk := str(best["x"]) + "," + str(best["y"])
	if Js.truthy(S["wallHP"].get(wk)):
		S["wallHP"][wk] = 0.0
	if Js.truthy(S["gateHP"].get(wk)):
		S["gateHP"][wk] = 0.0
	E.emit("siege_used", {"unit": u, "type": "bomb", "target": best})
	E.fx("redraw_terrain")
	return true


func use_siege_item(u: Dictionary, item: Dictionary) -> bool:
	var success := false
	match item["type"]:
		"bomb":
			success = _siege_bomb(u)
		"shield":
			E.buff_apply(u, {"type": "shield", "duration": 3.0, "value": 0.5, "icon": "🛡️", "source": "siege"})
			E.emit("siege_used", {"unit": u, "type": "shield"})
			success = true
		"evasion":
			E.buff_apply(u, {"type": "evasion", "duration": 1.0, "value": 0.3, "icon": "⚡", "source": "siege"})
			E.emit("siege_used", {"unit": u, "type": "evasion"})
			success = true
		_:
			return false
	if success:
		item["cooldown"] = 3.0
		return true
	return false


func try_siege_item_use(u: Dictionary) -> bool:
	if typeof(u.get("siegeItems")) != TYPE_ARRAY or (u["siegeItems"] as Array).is_empty():
		return false
	var situation := analyze_situation(u)
	if situation["type"] == "blocked":
		var item: Variant = select_siege_item(u, situation)
		if item == null:
			return false
		return use_siege_item(u, item)
	if float(situation["severity"]) < 0.3:
		return false
	var item2: Variant = select_siege_item(u, situation)
	if item2 == null:
		return false
	return use_siege_item(u, item2)


func try_gate_atk(u: Dictionary) -> bool:
	for d: Array in [[0, 1], [0, -1], [-1, 0], [1, 0]]:
		var nx: int = u["x"] + d[0]
		var ny: int = u["y"] + d[1]
		if ny != 14 or nx < 0 or nx >= int(D["COLS"]):
			continue
		if S["ter"][ny][nx] != "gate":
			continue
		var k := str(nx) + "," + str(ny)
		if not Js.truthy(S["gateHP"].get(k)) or float(S["gateHP"][k]) <= 0:
			continue
		S["gateHP"][k] = float(S["gateHP"][k]) - 1.0
		E.emit("gate_attacked", {"unit": u, "x": nx, "y": ny, "hp": S["gateHP"][k]})
		if float(S["gateHP"][k]) <= 0:
			S["ter"][ny][nx] = "plain"
			E.emit("gate_destroyed", {"unit": u, "x": nx, "y": ny})
		E.fx("redraw_terrain")
		return true
	return false


## 벽 등반 (성벽 이웃마다 난수) — 성공하면 기록 wall_climb (멈추면 기록 안 됨: 웹도 그 뒤가 실행되지 않음)
func try_wall_climb(u: Dictionary) -> bool:
	var r0: int = E.c.rng.calls
	for d: Array in [[0, 1], [0, -1], [-1, 0], [1, 0]]:
		var nx: int = u["x"] + d[0]
		var ny: int = u["y"] + d[1]
		if ny != 14 or nx < 0 or nx >= int(D["COLS"]):
			continue
		if S["ter"][ny][nx] != "wall":
			continue
		if E.c.rand("tryWallClimb") > 0.3:
			continue
		var ox: int = u["x"]
		var oy: int = u["y"]
		u["x"] = nx
		u["y"] = ny
		E.emit("unit_moved", {"unit": u, "from": {"x": ox, "y": oy}, "to": {"x": nx, "y": ny}})
		if E._sl(340):
			return true
		on_breach(u)
		E.rec_r("wall_climb", r0, {"u": u["id"], "x": u["x"], "y": u["y"]})
		return true
	return false


func on_breach(u: Dictionary) -> void:
	S["breached"] = int(S["breached"]) + 1
	var s: Variant = S["cStage"]
	if s == null:
		return
	var limit := ceilf(float(s["tot"]) / 4.0)
	E.emit("breach", {"unit": u, "count": S["breached"], "limit": limit})


# ── 적 공격 ──

func e_atk_async(a: Dictionary, tgt: Dictionary) -> void:
	E.emit("camera_focus", {"unit": tgt})
	if E._sl(250):
		return
	e_atk(a, tgt)
	if E._aborted:
		return
	E._sl(500 if tgt["hp"] <= 0 else 300)


func e_atk(a: Dictionary, tgt: Dictionary) -> void:
	var blk: Variant = E.gu.intercept_of(a, tgt)
	if blk != null:
		tgt = blk
		E.fx_float(blk["x"], blk["y"], "messages.intercepted")
	if E.gu.roll_evade(tgt) != null:
		E.fx_face_dir(a["id"], tgt["x"] - a["x"], tgt["y"] - a["y"])
		E.emit("evasion", {"unit": tgt})
		return
	var b_counter: bool = Js.num(tgt["skillLv"].get("brawler_counter")) >= 1 and not E.gu.is_cc(tgt) \
		and float(Js.mh(tgt["x"], tgt["y"], a["x"], a["y"])) <= float(tgt["range"]) and E.c.rand("eAtk.brawler_counter") < 0.3
	var sup_killer: Variant = null
	var slept := false   # 웹: left = hd(0) + 120 - 지난 시간 → 한 번도 안 기다렸으면 처치 때 sl(120) 멈춤 지점
	if b_counter:
		slept = true
		if E._sl(420):
			return
		var cdmg := maxf(1.0, Js.round_js(tgt["atk"] * 0.5) - a["def"])
		a["hp"] = maxf(0.0, a["hp"] - cdmg)
		E.emit("unit_attacked", {"attacker": tgt, "target": a, "damage": cdmg, "counter": true})
	else:
		var dmg: float = E.calc_dmg(a, tgt)
		if blk != null:
			dmg = E.gearfx.intercept(blk, maxf(1.0, Js.round_js(dmg * float(D["TACTICS_ACT"]["interceptMul"]))))
		if E.gu.shield_mul(tgt) < 1.0:
			dmg = maxf(1.0, Js.round_js(dmg * E.gu.shield_mul(tgt)))
			E.emit("shield_active", {"unit": tgt})
		var actual: Dictionary
		if tgt["team"] == "ally":
			actual = E.apply_dmg_to_ally(tgt, dmg)
		else:
			tgt["hp"] = maxf(0.0, tgt["hp"] - dmg)
			actual = tgt
		E.emit("unit_attacked", {"attacker": a, "target": actual, "damage": dmg, "counter": false})
		if a["cls"] == "mage" and blk == null:
			var spl := maxf(1.0, Js.round_js(dmg * 0.5))
			for d: Array in [[0, -1], [0, 1], [-1, 0], [1, 0]]:
				var su: Variant = E.gu.u_at(tgt["x"] + d[0], tgt["y"] + d[1])
				if su != null and su["hp"] > 0 and su["team"] == tgt["team"] and su["id"] != tgt["id"]:
					su["hp"] = maxf(0.0, su["hp"] - spl)
					E.emit("unit_attacked", {"attacker": a, "target": su, "damage": spl, "isSplash": true})
					if su["hp"] <= 0:
						E.emit("unit_killed", {"killer": a, "target": su})
		if E.buff_has(a, "fury_buff"):
			E.emit("fury_triggered", {"unit": a})
		E.proc_fury(a, tgt)
		var sup: Variant = E.gu.roll_support(a, tgt)
		if sup != null:
			slept = true
			if E._sl(380):
				return
			E.gu.emit_support(sup)
			if tgt["hp"] <= 0:
				sup_killer = sup["sp"]
		if tgt["hp"] > 0 and a["hp"] > 0 and float(Js.mh(tgt["x"], tgt["y"], a["x"], a["y"])) <= float(tgt["range"]) and not E.gu.is_cc(tgt):
			slept = true
			if E._sl(420):
				return
			var cdmg2 := maxf(1.0, Js.round_js(E.cb.ench_mod_damage(tgt, a, E.calc_dmg(tgt, a)) * E.gearfx.counter_mul(tgt)))
			a["hp"] = maxf(0.0, a["hp"] - cdmg2)
			E.emit("unit_attacked", {"attacker": tgt, "target": a, "damage": cdmg2, "counter": true})
			E.cb.ench_after_hit(tgt, a, cdmg2)
			E.proc_fury(tgt, a)
	# 사망 처리 — 투사체가 맞을 때까지 기다림 (연출을 끄면 hd = 0)
	if tgt["hp"] <= 0 and not slept:
		if E._sl(120):
			return
	if tgt["hp"] <= 0:
		E.emit("unit_killed", {"killer": sup_killer if sup_killer != null else a, "target": tgt})
		E.gu.rm_dead()
		E.fx_redraw_units()
		E.chk_end()
	elif a["hp"] <= 0:
		E.emit("unit_killed", {"killer": tgt, "target": a})
		E.gu.rm_dead()
		E.fx_redraw_units()
		E.chk_end()
	else:
		E.fx_redraw_units()


# ── 이동 ──

func _move_unit(u: Dictionary, nx: int, ny: int) -> void:
	var ox: int = u["x"]
	var oy: int = u["y"]
	u["x"] = nx
	u["y"] = ny
	E.emit("unit_moved", {"unit": u, "from": {"x": ox, "y": oy}, "to": {"x": nx, "y": ny}})
	if E._sl(340):
		return
	if Js.truthy(u.get("_cursed")):
		E.cb.curse_move_tick(u)
	E.gu.chk_trap(u)
	E.gu.chk_spearwall(u)
	_overwatch(u)
	if E._aborted:
		return
	if u["hp"] <= 0:
		E.emit("unit_killed", {"killer": null, "target": u, "reason": "trap_or_spearwall"})
		E.gu.rm_dead()
		E.fx_redraw_units()


## 경계 발동 — 쏜 유닛을 기록 overwatch (함수가 끝까지 돈 경우만)
func _overwatch(e: Dictionary) -> void:
	var before: Array = []
	for a: Dictionary in S["units"]:
		if Js.truthy(a.get("_overwatch")):
			before.append(a["id"])
	var r0: int = E.c.rng.calls
	_overwatch_raw(e)
	if E._aborted:
		return
	for id: Variant in before:
		var a2: Variant = E.unit_by_id(id)
		if a2 == null or not Js.truthy(a2.get("_overwatch")):
			E.rec_r("overwatch", r0, {"w": id, "e": e["id"]})
			return


func _overwatch_raw(e: Dictionary) -> void:
	if e["hp"] <= 0 or _stealth(e):
		return
	var w: Variant = null
	for a: Dictionary in S["units"]:
		if a["hp"] > 0 and Js.truthy(a.get("_overwatch")) and a["team"] != e["team"] and not E.gu.is_cc(a) \
				and E.gu.has_cell(E.gu.atk_cells(a), e["x"], e["y"]) and E.gu.cover_of(a, e) == null:
			w = a
			break
	if w == null:
		return
	w["_overwatch"] = false
	E.fx_float(w["x"], w["y"], "messages.overwatch_fire")
	E.fx_face_dir(w["id"], e["x"] - w["x"], e["y"] - w["y"])
	var blk: Variant = E.gu.intercept_of(w, e)
	var hit: Dictionary = blk if blk != null else e
	if blk != null:
		E.fx_float(blk["x"], blk["y"], "messages.intercepted")
	var TA: Dictionary = D["TACTICS_ACT"]
	var dmg := maxf(1.0, Js.round_js(E.cb.ench_mod_damage(w, hit, E.calc_dmg(w, hit)) * float(TA["overwatchMul"]) * (float(TA["interceptMul"]) if blk != null else 1.0) * E.gu.shield_mul(hit)))
	hit["hp"] = maxf(0.0, hit["hp"] - dmg)
	E.emit("unit_attacked", {"attacker": w, "target": hit, "damage": dmg})
	E.cb.ench_after_hit(w, hit, dmg)
	if E._sl(550):
		return
	if hit["hp"] <= 0:
		E.emit("unit_killed", {"killer": w, "target": hit})
		E.gu.rm_dead()
		E.fx_redraw_units()
		E.chk_end()


func _check_breach(u: Dictionary, ny: int) -> bool:
	if ny == 14:
		on_breach(u)
		return true
	return false


func e_mv(u: Dictionary, al: Array) -> void:
	if E.buff_has(u, "root") or Js.num(u.get("_rootedTurns")) > 0:
		E.emit("root_blocked", {"unit": u})
		return
	var orig: Dictionary = u["origSpawn"] if Js.truthy(u.get("origSpawn")) else {"x": u["x"], "y": u["y"]}
	var profile := _profile(u["cls"])
	var hp_pct: float = u["hp"] / u["mhp"]
	var is_boss: bool = Js.truthy(u.get("isBoss"))
	var should_retreat: bool = hp_pct < float(profile["retreatThreshold"]) and E.c.rand("eMv.retreat") < 0.3
	if should_retreat and not is_boss:
		var mc: Array = E.gu.e_mv_cells(u)
		if mc.is_empty():
			return
		var bm: Variant = null
		var bd := INF
		for m: Dictionary in mc:
			var d := float(Js.mh(m["x"], m["y"], orig["x"], orig["y"]))
			if d < bd:
				bd = d
				bm = m
		if bm != null and Js.mh(bm["x"], bm["y"], orig["x"], orig["y"]) < Js.mh(u["x"], u["y"], orig["x"], orig["y"]):
			_move_unit(u, bm["x"], bm["y"])
			if E._aborted:
				return
			E.emit("retreat", {"unit": u})
			return
	var defense: bool = S["cStage"] != null and S["cStage"].get("style") == "defense"
	var adv_limit := 15.0 if defense else 5.0
	if profile["style"] == "defensive":
		adv_limit = 12.0 if defense else 3.0
	if profile["style"] == "support":
		adv_limit = 10.0 if defense else 2.0
	var adv_dist := float(Js.mh(u["x"], u["y"], orig["x"], orig["y"]))
	if defense and not is_boss:
		var allies: Array = []
		for e: Dictionary in E.gu.alive("enemy"):
			if e["id"] != u["id"] and not Js.truthy(e.get("isBoss")):
				allies.append(e)
		if not allies.is_empty():
			var sum := 0.0
			for a: Dictionary in allies:
				sum += float(a["y"])
			var avg_y := sum / float(allies.size())
			if float(u["y"]) > avg_y + 3.0:
				return
			var nearest := INF
			for a2: Dictionary in allies:
				nearest = minf(nearest, float(Js.mh(u["x"], u["y"], a2["x"], a2["y"])))
			if nearest > 5.0:
				adv_limit = minf(adv_limit, adv_dist + 2.0)
	if adv_dist >= adv_limit and not is_boss:
		return
	var mc2: Array = E.gu.e_mv_cells(u)
	if mc2.is_empty():
		return
	var valid: Array = []
	for m2: Dictionary in mc2:
		if float(Js.mh(m2["x"], m2["y"], orig["x"], orig["y"])) <= adv_limit or is_boss:
			valid.append(m2)
	if valid.is_empty():
		return
	var bt: Variant = null
	var bdist := INF
	for a3: Dictionary in al:
		if _stealth(a3):
			continue
		var d2 := float(Js.mh(u["x"], u["y"], a3["x"], a3["y"]))
		if d2 < bdist:
			bdist = d2
			bt = a3
	if u["cls"] == "assassin":
		var best_m: Variant = null
		var best_s := -INF
		for m3: Dictionary in valid:
			var tr: Variant = E.gu.tile(m3["x"], m3["y"])
			var score := 0.0
			if tr == "forest":
				score += 50.0
			if bt != null:
				score += float(Js.mh(u["x"], u["y"], bt["x"], bt["y"]) - Js.mh(m3["x"], m3["y"], bt["x"], bt["y"])) * 10.0
			score += float(m3["y"] - u["y"]) * 3.0
			score += _tactic_score(u, m3, al)
			if score > best_s:
				best_s = score
				best_m = m3
		if best_m != null:
			_move_unit(u, best_m["x"], best_m["y"])
			if E._aborted:
				return
			if u["hp"] <= 0:
				return
			_check_breach(u, best_m["y"])
			return
	if Js.truthy(profile.get("guardMode")) and not is_boss:
		var allies2: Array = []
		for e2: Dictionary in E.gu.alive("enemy"):
			if e2["id"] != u["id"]:
				allies2.append(e2)
		if not allies2.is_empty():
			var bm2: Variant = null
			var bs2 := -INF
			for m4: Dictionary in valid:
				var score2 := 0.0
				var sumd := 0.0
				for a4: Dictionary in allies2:
					sumd += float(Js.mh(m4["x"], m4["y"], a4["x"], a4["y"]))
				var avg_d := sumd / float(allies2.size())
				score2 -= avg_d * 5.0
				score2 -= float(Js.mh(m4["x"], m4["y"], orig["x"], orig["y"])) * float(profile["advanceBonus"])
				if score2 > bs2:
					bs2 = score2
					bm2 = m4
			if bm2 != null:
				_move_unit(u, bm2["x"], bm2["y"])
				return
	var cbt: Variant = null
	var cbd := INF
	for a5: Dictionary in al:
		if _stealth(a5):
			continue
		var d3 := float(Js.mh(u["x"], u["y"], a5["x"], a5["y"]))
		if d3 < cbd:
			cbd = d3
			cbt = a5
	if Js.truthy(profile.get("keepDistance")) and cbt != null and Js.mh(u["x"], u["y"], cbt["x"], cbt["y"]) <= 2:
		var bm3: Variant = null
		var bdist3 := 0.0
		for m5: Dictionary in valid:
			var dist := float(Js.mh(m5["x"], m5["y"], cbt["x"], cbt["y"]))
			if dist > bdist3 and dist <= float(u["range"]):
				bdist3 = dist
				bm3 = m5
		if bm3 != null and bdist3 > float(Js.mh(u["x"], u["y"], cbt["x"], cbt["y"])):
			_move_unit(u, bm3["x"], bm3["y"])
			return
	if bt == null or bdist > 8.0:
		var gate_t := {"x": 4 if int(u["x"]) <= 4 else 5, "y": 13}
		var bc2: Variant = null
		var bs3 := -INF
		for c2: Dictionary in valid:
			var s2: float = -float(Js.mh(c2["x"], c2["y"], gate_t["x"], gate_t["y"])) * 10.0 + float(c2["y"] - u["y"]) * (5.0 + float(profile["advanceBonus"]))
			if s2 > bs3:
				bs3 = s2
				bc2 = c2
		if bc2 != null:
			_move_unit(u, bc2["x"], bc2["y"])
			return
	var bc: Variant = null
	var bs4 := -INF
	for c3: Dictionary in valid:
		var s3 := 0.0
		if bt != null:
			s3 += float(Js.mh(u["x"], u["y"], bt["x"], bt["y"]) - Js.mh(c3["x"], c3["y"], bt["x"], bt["y"])) * 10.0
		s3 += float(c3["y"] - u["y"]) * (3.0 + float(profile["advanceBonus"]) * 0.3)
		s3 += _tactic_score(u, c3, al)
		if s3 > bs4:
			bs4 = s3
			bc = c3
	if bc != null:
		_move_unit(u, bc["x"], bc["y"])
		if E._aborted:
			return
		if u["hp"] <= 0:
			return
		_check_breach(u, bc["y"])
