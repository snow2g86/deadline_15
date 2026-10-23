extends RefCounted
## 3단계 화면용 조회 — 모두 **순수**: 난수 호출 수·난수 상태·유닛/전투 상태·기록(trace)·신호를 바꾸지 않는다 (tests/check_battle_api.gd 가 확인)
##  계산 중 웹 함수가 공격자에 남기는 표시 값(_lastTactic·_lastCrit·방향)은 원래대로 되돌리고, 확률 요소는 웹 미리보기처럼 0.999(발동 안 함)로 본다.
##  E.q.preview_attack(a, t)   — 웹 Renderer.previewAttack + rPreview(투사체 차단)
##  E.q.move_cells(u) · attack_targets(u) · skill_targets(u, idx) · skill_status(u) · can_undo() · actions(u) · face_options(u) · threat_cells()
##  (3a 추가) shove_cells(u) · potion_targets(u, idx) · siege_targets(u, idx)
##  E = battle_engine.gd

const Js := preload("res://scripts/logic/js.gd")

const MARK_KEYS := ["_lastTactic", "_lastCrit", "_gdx", "_gdy"]

var E: Object
var S: Dictionary
var D: Dictionary


func _init(engine: Object) -> void:
	E = engine
	S = engine.S
	D = engine.D


func _keep(units: Array) -> Array:
	var saved: Array = []
	for u: Dictionary in units:
		var o: Dictionary = {}
		for k: String in MARK_KEYS:
			if u.has(k):
				o[k] = Js.deep(u[k])
		saved.append([u, o])
	return saved


func _restore(saved: Array) -> void:
	for e: Array in saved:
		var u: Dictionary = e[0]
		var o: Dictionary = e[1]
		for k: String in MARK_KEYS:
			if o.has(k):
				u[k] = o[k]
			else:
				u.erase(k)


# ── 피해 미리보기 ──

## a 가 t 를 일반 공격할 때 예상 → { dmg, kill, tags, pct, support(%), shallow, evade(%), evade_buff, shield, counter, intercept, intercept_dmg }
##  투사체가 기사에게 막히면 intercept = 기사 id, intercept_dmg = 기사가 받을 피해 (웹 rPreview), dmg 는 그 기사 기준
##  as_exec = true (3b 화면, Godot 만): 실제 공격(do_atk)처럼 계산 — 주술사 고양(shaman_exalt atk_up, _attackCount ≤ 1)은
##   피해 계산 **전에** 소모되어 마지막 공격에는 붙지 않으므로 미리보기에서도 뺌. 웹 미리보기는 이 버프를 넣고 계산해 실제보다 크게 보임.
##   (기본값 false 는 웹 previewAttack 과 같은 값 — tests/check_battle_api.gd)
func preview_attack(a: Dictionary, t: Dictionary, as_exec: bool = false) -> Dictionary:
	E.pure_begin()
	var held: Array = []   # [번호, 버프] — 계산 동안 잠시 뺀 고양 버프 (끝나면 같은 자리에)
	if as_exec and typeof(a.get("buffs")) == TYPE_ARRAY:
		var arr: Array = a["buffs"]
		for i in range(arr.size() - 1, -1, -1):
			var b: Dictionary = arr[i]
			if b.get("source") == "shaman_exalt" and Js.num(b.get("_attackCount")) > 0 and Js.num(b.get("_attackCount")) - 1.0 <= 0.0:
				held.push_front([i, b])
				arr.remove_at(i)
	var saved := _keep([a, t])
	var out: Dictionary
	var blk: Variant = E.gu.intercept_of(a, t)
	if blk != null:
		var saved2 := _keep([blk])
		out = _preview(a, blk)
		_restore(saved2)
		out["intercept"] = blk["id"]
		out["intercept_dmg"] = maxf(1.0, Js.round_js(float(out["dmg"]) * float(D["TACTICS_ACT"]["interceptMul"])))
	else:
		out = _preview(a, t)
		out["intercept"] = null
		out["intercept_dmg"] = 0.0
	_restore(saved)
	for h: Array in held:
		(a["buffs"] as Array).insert(int(h[0]), h[1])
	E.pure_end()
	return out


func _preview(a: Dictionary, t: Dictionary) -> Dictionary:
	var tb: Dictionary = E.gu.tactic_bonus(a, t)
	var dmg := maxf(1.0, Js.round_js(E.cb.ench_mod_damage(a, t, E.cb._calc_dmg_raw(a, t)) * E.gu.shield_mul(t)))
	var kill: bool = dmg >= t["hp"]
	var tile: Variant = E.gu.tile(t["x"], t["y"])
	var counter := 0.0
	if not kill and float(Js.mh(t["x"], t["y"], a["x"], a["y"])) <= float(t["range"]) and not E.gu.is_cc(t):
		a["_gdx"] = t["x"] - a["x"]
		a["_gdy"] = t["y"] - a["y"]
		counter = E.cb._calc_dmg_raw(t, a)
	var sp: Variant = null if kill else E.gu.supporter_of(a, t)
	return {"dmg": dmg, "kill": kill, "tags": (tb["tags"] as Array).duplicate(), "pct": Js.round_js((float(tb["mul"]) - 1.0) * 100.0),
		"support": Js.round_js(float(D["SUPPORT"]["chance"]) * 100.0) if sp != null else 0.0, "shallow": tile == "shallow",
		"evade": Js.round_js(float(D["TACTIC"]["forestEvade"]) * 100.0) if tile == "forest" else 0.0,
		"evade_buff": E.buff_has(t, "evasion"), "shield": E.gu.shield_mul(t) < 1.0, "counter": counter}


# ── 칸 ──

## 이동 가능 칸 [{x, y, vault?}] — 이미 이동했으면 [] (웹 actMove)
func move_cells(u: Dictionary) -> Array:
	if Js.truthy(u.get("hm")) or Js.truthy(u.get("mo")):
		return []
	E.pure_begin()
	var r: Array = Js.deep(E.gu.mv_cells(u))
	E.pure_end()
	return r


## 공격·회복 대상 칸 (웹 _setTargets 를 상태 없이) → { attack, cover(엄호로 막힌 적), block(투사체가 기사에 막히는 적), heal }
func attack_targets(u: Dictionary) -> Dictionary:
	var out := {"attack": [], "cover": [], "block": [], "heal": []}
	if Js.truthy(u.get("channeling")):
		return out
	E.pure_begin()
	var cells: Array = E.gu.atk_cells(u)
	for cc: Dictionary in cells:
		var v: Variant = E.gu.u_at(cc["x"], cc["y"])
		if v == null:
			continue
		if v["team"] == "enemy" and not E.is_stealthed(v):
			if E.gu.cover_of(u, v) != null:
				(out["cover"] as Array).append(cc)
			else:
				(out["attack"] as Array).append(cc)
			if E.gu.intercept_of(u, v) != null:
				(out["block"] as Array).append(cc)
		if u.get("role") == "healer" and v["team"] == "ally" and v["hp"] < v["mhp"] and v["id"] != u["id"]:
			(out["heal"] as Array).append(cc)
	E.pure_end()
	return out


## 스킬 대상 → { ok, cells([{x,y}] — 즉시형은 [] ), instant, reason } (소환 제한 등 안내 글자는 내지 않음)
func skill_targets(u: Dictionary, idx: int) -> Dictionary:
	var skills: Array = E.get_unit_skills(u)
	if idx < 0 or idx >= skills.size():
		return {"ok": false, "cells": [], "instant": false, "reason": "bad_skill"}
	var skd: Dictionary = skills[idx]
	if Js.truthy(skd.get("passive")) or not E.sk.has_handler(skd["id"]):
		return {"ok": false, "cells": [], "instant": false, "reason": "passive"}
	E.pure_begin()
	var r: Variant = E.sk.target(skd["id"], u, skd)
	E.pure_end()
	if r == null:
		return {"ok": false, "cells": [], "instant": false, "reason": "no_target"}
	if typeof(r) == TYPE_STRING:
		return {"ok": true, "cells": [], "instant": true, "reason": ""}
	return {"ok": not (r as Array).is_empty(), "cells": Js.deep(r), "instant": false, "reason": "" if not (r as Array).is_empty() else "no_target"}


## 스킬마다 쓸 수 있는지 → [{ idx, id, cost, passive, usable, reason }]  reason: passive · acted · no_resource · no_target
##  (웹에는 재사용 대기(쿨다운)가 없음 — 비용·대상만)
func skill_status(u: Dictionary) -> Array:
	var out: Array = []
	var skills: Array = E.get_unit_skills(u)
	for i in skills.size():
		var skd: Dictionary = skills[i]
		var o := {"idx": i, "id": skd["id"], "cost": skd.get("cost", 0.0), "passive": Js.truthy(skd.get("passive")), "usable": false, "reason": ""}
		if o["passive"]:
			o["reason"] = "passive"
		elif Js.truthy(u.get("ha")):
			o["reason"] = "acted"
		elif skd.has("cost") and float(u["res"]) < float(skd["cost"]):
			o["reason"] = "no_resource"
		else:
			var t := skill_targets(u, i)
			o["usable"] = t["ok"]
			o["reason"] = t["reason"]
		out.append(o)
	return out


## 밀치기 대상 칸 [{x, y}] (웹 act_shove 의 atkT — 인접 적 중 밀 수 있는 것)
func shove_cells(u: Dictionary) -> Array:
	E.pure_begin()
	var out: Array = []
	for v: Dictionary in E.gu.shove_targets(u):
		out.append({"x": v["x"], "y": v["y"]})
	E.pure_end()
	return out


## 물약 대상 → { ok, cells([{x,y}]), debuff } (웹 act_potion 의 potionTargets — 사거리 안 아군, 약화 물약은 적)
func potion_targets(u: Dictionary, idx: int) -> Dictionary:
	var pots: Array = S["_battlePotions"]
	if idx < 0 or idx >= pots.size():
		return {"ok": false, "cells": [], "debuff": false}
	var def: Variant = (D["BATTLE_POTIONS"] as Dictionary).get(pots[idx]["potionId"])
	if def == null:
		return {"ok": false, "cells": [], "debuff": false}
	var is_debuff: bool = def["type"] == "debuff"
	var cells: Array = []
	for tu: Dictionary in S["units"]:
		if tu["hp"] <= 0 or float(Js.mh(u["x"], u["y"], tu["x"], tu["y"])) > float(def["range"]):
			continue
		if (is_debuff and tu["team"] == "enemy") or (not is_debuff and tu["team"] == "ally"):
			cells.append({"x": tu["x"], "y": tu["y"]})
	return {"ok": not cells.is_empty(), "cells": cells, "debuff": is_debuff}


## 공성 아이템 대상 → { ok, cells([{x,y}]), effect } (웹 act_siege 의 atkT — 사거리 안 성벽·성문(·바위)·물 칸)
func siege_targets(u: Dictionary, idx: int) -> Dictionary:
	var items: Array = S["_siegeItems"]
	if idx < 0 or idx >= items.size():
		return {"ok": false, "cells": [], "effect": ""}
	var def: Variant = null
	for d: Dictionary in D["SIEGE_ITEMS"]:
		if d["id"] == items[idx]["siegeId"]:
			def = d
			break
	if def == null:
		return {"ok": false, "cells": [], "effect": ""}
	var cells: Array = []
	for r in int(D["ROWS"]):
		for cc in int(D["COLS"]):
			if float(Js.mh(u["x"], u["y"], cc, r)) > float(def["range"]):
				continue
			var tl: Variant = S["ter"][r][cc]
			if (def["targetType"] == "wall" and (tl == "wall" or tl == "gate")) \
					or (def["targetType"] == "wall_rock" and (tl == "wall" or tl == "gate" or tl == "rock")) \
					or (def["targetType"] == "water" and tl == "water"):
				cells.append({"x": cc, "y": r})
	return {"ok": not cells.is_empty(), "cells": cells, "effect": str(def.get("effect", ""))}


## 이동 취소 가능 (방금 이동한 뒤, 아직 행동 전)
func can_undo() -> bool:
	return S["sel"] != null and Js.truthy(S.get("preMv")) and E.is_player_turn() and not Js.truthy(S["sel"].get("ha"))


## 지금 고를 수 있는 행동 → [{ op, ok, reason }] (op: move·attack·heal·shove·skill·potion·siege·wait·defend·overwatch·undo)
func actions(u: Dictionary) -> Array:
	var acted: bool = Js.truthy(u.get("ha"))
	var out: Array = []
	var mv := move_cells(u)
	out.append({"op": "move", "ok": not acted and not mv.is_empty(), "reason": "acted" if acted else ("moved" if (Js.truthy(u.get("hm")) or Js.truthy(u.get("mo"))) else ("" if not mv.is_empty() else "no_cell"))})
	var at := attack_targets(u)
	out.append({"op": "attack", "ok": not acted and not (at["attack"] as Array).is_empty(), "reason": "acted" if acted else ("" if not (at["attack"] as Array).is_empty() else "no_target")})
	if u.get("role") == "healer":
		out.append({"op": "heal", "ok": not acted and not (at["heal"] as Array).is_empty(), "reason": "acted" if acted else ("" if not (at["heal"] as Array).is_empty() else "no_target")})
	E.pure_begin()
	var shove: Array = E.gu.shove_targets(u)
	E.pure_end()
	out.append({"op": "shove", "ok": not acted and not shove.is_empty(), "reason": "acted" if acted else ("" if not shove.is_empty() else "no_target")})
	var any_sk := false
	for st: Dictionary in skill_status(u):
		if st["usable"]:
			any_sk = true
	out.append({"op": "skill", "ok": any_sk, "reason": "" if any_sk else ("acted" if acted else "no_skill")})
	var has_pot := not (S["_battlePotions"] as Array).is_empty()
	out.append({"op": "potion", "ok": not acted and has_pot, "reason": "acted" if acted else ("" if has_pot else "no_item")})
	var has_siege := not (S["_siegeItems"] as Array).is_empty()
	out.append({"op": "siege", "ok": not acted and has_siege, "reason": "acted" if acted else ("" if has_siege else "no_item")})
	out.append({"op": "wait", "ok": true, "reason": ""})
	out.append({"op": "defend", "ok": not acted, "reason": "acted" if acted else ""})
	out.append({"op": "overwatch", "ok": not acted, "reason": "acted" if acted else ""})
	out.append({"op": "undo", "ok": can_undo(), "reason": "" if can_undo() else "no_move"})
	return out


## 방향 선택지 (웹 ActionManager.faceOptions): 네 방향마다 그 방향을 볼 때 등(후방)·옆구리(측면)에 놓이는 적 수, best = 추천
func face_options(u: Dictionary) -> Array:
	var foes: Array = []
	for v: Dictionary in S["units"]:
		if v["hp"] > 0 and v["team"] != u["team"]:
			foes.append(v)
	var opts: Array = []
	for f: Array in [[0, -1], [1, 0], [0, 1], [-1, 0]]:
		var back := 0
		var side := 0
		for v2: Dictionary in foes:
			var dx := float(v2["x"] - u["x"])
			var dy := float(v2["y"] - u["y"])
			var d := Js.hypot(dx, dy)
			if d == 0.0:
				continue
			var cosv: float = (dx * f[0] + dy * f[1]) / d
			if cosv < -0.5:
				back += 1
			elif cosv <= 0.5:
				side += 1
		opts.append({"dx": f[0], "dy": f[1], "back": back, "side": side,
			"cur": int(Js.num(u.get("_gdx"))) == f[0] and int(Js.num(u.get("_gdy"))) == f[1], "best": false})
	var best: Dictionary = opts[0]
	for o: Dictionary in opts:
		if o["back"] * 3 + o["side"] < best["back"] * 3 + best["side"]:
			best = o
	best["best"] = true
	return opts


## 아군 시야 (웹 Grid.calcFOW: 클랜원마다 이동력+1 칸) → {"x,y": true}
func fog_visible() -> Dictionary:
	var vis: Dictionary = {}
	for u: Dictionary in E.gu.alive("ally"):
		var vision := int(u["move"]) + 1
		for r in int(D["ROWS"]):
			for cc in int(D["COLS"]):
				if Js.mh(u["x"], u["y"], cc, r) <= vision:
					vis[str(cc) + "," + str(r)] = true
	return vis


## 적 위협 범위 (웹 Renderer.calcThreat): 보이는 적들이 이동 후 공격할 수 있는 칸 → ["x,y", …]
func threat_cells(only_visible: bool = true) -> Array:
	E.pure_begin()
	var vis := fog_visible()
	var set: Dictionary = {}
	for e: Dictionary in S["units"]:
		if e["team"] != "enemy" or e["hp"] <= 0 or E.is_stealthed(e):
			continue
		if only_visible and not vis.has(str(e["x"]) + "," + str(e["y"])):
			continue
		var prof: Variant = (D["AI_PROFILES"] as Dictionary).get(e["cls"])
		if E.gu.is_cc(e) or (prof != null and prof["targetPriority"] == "never"):
			continue
		var spots: Array = [{"x": e["x"], "y": e["y"]}]
		if not E.buff_has(e, "root"):
			spots.append_array(E.gu.e_mv_cells(e))
		for p: Dictionary in spots:
			var tl: Variant = E.gu.tile(p["x"], p["y"])
			var rng: int = int(float(e["range"]) + (float(D["TACTIC"]["highRange"]) if tl == "hill" and float(e["range"]) > 1.0 else 0.0))
			for dy in range(-rng, rng + 1):
				for dx in range(-rng, rng + 1):
					var x: int = p["x"] + dx
					var y: int = p["y"] + dy
					if (dx != 0 or dy != 0) and absi(dx) + absi(dy) <= rng and x >= 0 and x < int(D["COLS"]) and y >= 0 and y < int(D["ROWS"]):
						set[str(x) + "," + str(y)] = true
	E.pure_end()
	return set.keys()


## (도입 4) 적 한 명의 범위 — threat_cells 와 같은 규칙(이동 가능 칸 + 이동 뒤 사거리, 언덕 위 원거리 +highRange)을 그 적 하나에만
##  → { move: ["x,y"…](제자리 포함), attack: ["x,y"…], cc: 행동 불가(기절·빙결 등), passive: 적극 공격 안 함(targetPriority never) }
##  순수 (난수·상태 불변 — tests/check_battle_api.gd 순수성 시험에 포함)
func enemy_range(e: Dictionary) -> Dictionary:
	var out := {"move": [], "attack": [], "cc": false, "passive": false}
	if e["team"] != "enemy" or e["hp"] <= 0:
		return out
	E.pure_begin()
	var prof: Variant = (D["AI_PROFILES"] as Dictionary).get(e["cls"])
	if E.gu.is_cc(e):
		out["cc"] = true
	elif prof != null and prof["targetPriority"] == "never":
		out["passive"] = true
	else:
		var mv: Dictionary = {str(e["x"]) + "," + str(e["y"]): true}
		var spots: Array = [{"x": e["x"], "y": e["y"]}]
		if not E.buff_has(e, "root"):
			for p: Dictionary in E.gu.e_mv_cells(e):
				mv[str(p["x"]) + "," + str(p["y"])] = true
				spots.append({"x": p["x"], "y": p["y"]})
		var at: Dictionary = {}
		for p2: Dictionary in spots:
			var tl: Variant = E.gu.tile(p2["x"], p2["y"])
			var rng: int = int(float(e["range"]) + (float(D["TACTIC"]["highRange"]) if tl == "hill" and float(e["range"]) > 1.0 else 0.0))
			for dy in range(-rng, rng + 1):
				for dx in range(-rng, rng + 1):
					var x: int = p2["x"] + dx
					var y: int = p2["y"] + dy
					if (dx != 0 or dy != 0) and absi(dx) + absi(dy) <= rng and x >= 0 and x < int(D["COLS"]) and y >= 0 and y < int(D["ROWS"]):
						at[str(x) + "," + str(y)] = true
		out["move"] = mv.keys()
		out["attack"] = at.keys()
	E.pure_end()
	return out


## (도입 3) 예상 피해의 계산 내역 — 엔진이 쓰는 같은 함수(combat._calc_parts · grid_units.tactic_bonus)를 읽기만 함 (식은 안 바뀜)
##  → { atk, def, base(=max(1, atk−def)), mods(["fury1.5"…]), tactic_mul, tags, pct, tile(대상 지형), high(공격자가 언덕 위 원거리) }
func preview_parts(a: Dictionary, t: Dictionary) -> Dictionary:
	E.pure_begin()
	var saved := _keep([a, t])
	var parts: Dictionary = E.cb._calc_parts(a, t)
	var tb: Dictionary = E.gu.tactic_bonus(a, t)
	var tile_t: Variant = E.gu.tile(t["x"], t["y"])
	var tile_a: Variant = E.gu.tile(a["x"], a["y"])
	_restore(saved)
	E.pure_end()
	return {"atk": parts["atk"], "def": parts["def"], "base": parts["base"], "mods": (parts["mods"] as Array).duplicate(),
		"tactic_mul": tb["mul"], "tags": (tb["tags"] as Array).duplicate(), "pct": Js.round_js((float(tb["mul"]) - 1.0) * 100.0),
		"tile": tile_t if tile_t != null else "", "high": tile_a == "hill" and float(a["range"]) > 1.0}


## 전투 끝 장비 보상의 실제 물건 (3b 결과 화면용, 순수) — before_eids: 전투 시작 때 인벤토리의 eid 들 {eid: true}
##  S._gearDrops 는 templateId·legend 만 담으므로, 이번 전투에 새로 생긴 물건(시작 때 없던 eid) 중 끝에서부터
##  드랍 수만큼을 _gearDrops 순서대로 짝지음 (보물상자 장비는 전투 중에 먼저 들어가므로 앞쪽, 끝 보상은 마지막에 들어감)
##  → [{stone: n} | {templateId, legend, item(사본|null)}]
func gear_drop_items(before_eids: Dictionary) -> Array:
	var out: Array = []
	var drops: Variant = S.get("_gearDrops")
	if typeof(drops) != TYPE_ARRAY:
		return out
	var inv: Variant = E.c.store.get_json(str(D.get("INV_KEY", "game_inventory")))
	var fresh: Array = []
	if typeof(inv) == TYPE_ARRAY:
		for it: Variant in inv:
			# eid 가 있는 물건(장비)만 — 룬·스킬북처럼 eid 없는 물건은 장비 보상과 짝짓지 않음
			if typeof(it) == TYPE_DICTIONARY and Js.truthy(it.get("eid")) and not before_eids.has(str(it.get("eid"))):
				fresh.append(it)
	var n := 0
	for g: Dictionary in drops:
		if g.has("templateId"):
			n += 1
	var tail: Array = fresh.slice(maxi(0, fresh.size() - n))
	var ti := 0
	for g2: Dictionary in drops:
		if g2.has("stone"):
			out.append({"stone": g2["stone"]})
			continue
		var it2: Variant = tail[ti] if ti < tail.size() else null
		ti += 1
		out.append({"templateId": g2.get("templateId"), "legend": Js.truthy(g2.get("legend")), "item": Js.deep(it2) if it2 != null else null})
	return out


## 지금 인벤토리의 eid 들 (gear_drop_items 의 기준점, 순수)
func inventory_eids() -> Dictionary:
	var out: Dictionary = {}
	var inv: Variant = E.c.store.get_json(str(D.get("INV_KEY", "game_inventory")))
	if typeof(inv) == TYPE_ARRAY:
		for it: Variant in inv:
			if typeof(it) == TYPE_DICTIONARY and Js.truthy(it.get("eid")):
				out[str(it.get("eid"))] = true
	return out
