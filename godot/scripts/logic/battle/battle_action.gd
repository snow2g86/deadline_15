extends RefCounted
## 클랜원 행동 — 웹 js/battle/action.js (ActionManager: 선택·cellCk 상태 기계·이동·공격·회복·스킬·물약·공성·밀치기·방향 고르기·이동 취소)
##  + 시험 정책(tools/legacy-web/battle-sim/policy.js)의 exec: 명령 하나를 화면 버튼과 같은 입구로 실행 (exec_cmd)
##  웹의 setTimeout 은 E.later (가상 시계 대기열). E = battle_engine.gd

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const StageRules := preload("res://scripts/logic/stage_rules.gd")

var E: Object
var S: Dictionary
var D: Dictionary


func _init(engine: Object) -> void:
	E = engine
	S = engine.S
	D = engine.D


func _redraw() -> void:
	E.fx_redraw_units()


# ── 선택 ──

func sel_u(u: Dictionary) -> void:
	_sel_u_raw(u)
	E.after_sel_u(u)


func _sel_u_raw(u: Dictionary) -> void:
	if S["curUnit"] != null and u["id"] != S["curUnit"]["id"] and u["team"] == "ally":
		return
	if not E.is_player_turn() or E.fsm == E.BATTLE_END:
		return
	if u["team"] == "ally" and Js.truthy(u.get("ha")):
		return
	S["sel"] = u
	E.transition(E.UNIT_SELECTED)
	if u["team"] == "ally" and not Js.truthy(u.get("ha")):
		S["mvT"] = []
		if Js.truthy(u.get("channeling")):
			S["atkT"] = []
			S["healT"] = []
		else:
			_set_targets(u)
	else:
		S["mvT"] = []
		S["atkT"] = []
		S["healT"] = []
	_redraw()


func clr_sel() -> void:
	S["sel"] = null
	S["mvT"] = []
	S["atkT"] = []
	S["coverT"] = []
	S["blockT"] = []
	S["healT"] = []
	S["_shove"] = false
	S["_curSkill"] = null
	S["preMv"] = null
	if E.is_player_turn():
		E.transition(E.PLAYER_IDLE)
	_redraw()


func _enemy_targets(u: Dictionary, cells: Array) -> Array:
	S["atkT"] = []
	S["coverT"] = []
	S["blockT"] = []
	for cc: Dictionary in cells:
		var v: Variant = E.gu.u_at(cc["x"], cc["y"])
		if v == null or v["team"] != "enemy" or E.is_stealthed(v):
			continue
		if E.gu.cover_of(u, v) != null:
			(S["coverT"] as Array).append(cc)
		else:
			(S["atkT"] as Array).append(cc)
		if E.gu.intercept_of(u, v) != null:
			(S["blockT"] as Array).append(cc)
	return S["atkT"]


func _heal_cells(u: Dictionary, a: Array) -> Array:
	var out: Array = []
	if u.get("role") != "healer":
		return out
	for cc: Dictionary in a:
		var v: Variant = E.gu.u_at(cc["x"], cc["y"])
		if v != null and v["team"] == "ally" and v["hp"] < v["mhp"] and v["id"] != u["id"]:
			out.append(cc)
	return out


func _set_targets(u: Dictionary) -> void:
	var a: Array = E.gu.atk_cells(u)
	_enemy_targets(u, a)
	S["healT"] = _heal_cells(u, a)


func _in(cells: Variant, x: int, y: int) -> bool:
	return typeof(cells) == TYPE_ARRAY and E.gu.has_cell(cells, x, y)


# ── cellCk (상태별 칸 클릭) ──

func cell_ck(x: int, y: int) -> void:
	if Js.truthy(S.get("_facePick")):
		return
	if E.fsm_is([E.BATTLE_END, E.AI_TURN, E.ANIMATING]):
		return
	if not E.accepts_cell_click():
		return
	var cl: Variant = E.gu.u_at(x, y)
	var s: Variant = S["sel"]
	if Js.truthy(S.get("_shove")) and s != null:
		if cl != null and _in(S["atkT"], x, y):
			do_shove(s, cl)
			return
		S["_shove"] = false
		_set_targets(s)
		E.transition(E.UNIT_SELECTED)
		return
	if E.fsm == E.SKILL_TARGET:
		if _in(S["atkT"], x, y):
			do_skill(s, x, y)
			return
		S["atkT"] = []
		S["healT"] = []
		_set_targets(s)
		E.transition(E.UNIT_SELECTED)
		return
	if E.fsm == E.ITEM_TARGET:
		if Js.truthy(S.get("_curPotion")) and Js.truthy(S.get("potionTargets")):
			for pt: Dictionary in S["potionTargets"]:
				if pt["x"] == x and pt["y"] == y:
					do_potion(pt)
					return
			S["_curPotion"] = null
			S["potionTargets"] = []
			E.transition(E.UNIT_SELECTED)
			return
		if Js.truthy(S.get("_curSiege")):
			if _in(S["atkT"], x, y):
				do_siege(s, x, y)
				return
			S["_curSiege"] = null
			S["atkT"] = []
			E.transition(E.UNIT_SELECTED)
			return
		return
	if E.fsm == E.MOVE_MODE and s != null:
		var valid := _in(S["mvT"], x, y)
		if cl != null and cl["team"] == "enemy" and s["cls"] == "assassin" and s["team"] == "ally" and not Js.truthy(s.get("ha")) \
				and E.gu.tile(x, y) == "forest" and valid:
			do_mv(s, x, y)
			return
		if cl == null and valid:
			do_mv(s, x, y)
			return
		S["mvT"] = []
		_set_targets(s)
		E.transition(E.UNIT_SELECTED)
		return
	if (E.fsm == E.ATTACK_MODE or E.fsm == E.ATTACK_HEAL_MODE) and s != null and cl != null and cl["team"] == "enemy" and _in(S.get("coverT", []), x, y):
		E.fx_float(cl["x"], cl["y"], "messages.covered")
		return
	if E.fsm == E.ATTACK_MODE and s != null:
		if cl != null and cl["team"] == "enemy" and _in(S["atkT"], x, y):
			do_atk(s, cl)
			return
		S["atkT"] = []
		_set_targets(s)
		E.transition(E.UNIT_SELECTED)
		return
	if E.fsm == E.HEAL_MODE and s != null:
		if cl != null and cl["team"] == "ally" and cl["id"] != s["id"] and _in(S["healT"], x, y):
			do_heal(s, cl)
			return
		S["healT"] = []
		_set_targets(s)
		E.transition(E.UNIT_SELECTED)
		return
	if E.fsm == E.ATTACK_HEAL_MODE and s != null:
		if cl != null and cl["team"] == "enemy" and _in(S["atkT"], x, y):
			do_atk(s, cl)
			return
		if cl != null and cl["team"] == "ally" and cl["id"] != s["id"] and _in(S["healT"], x, y):
			do_heal(s, cl)
			return
		S["atkT"] = []
		S["healT"] = []
		_set_targets(s)
		E.transition(E.UNIT_SELECTED)
		return
	if E.fsm == E.UNIT_SELECTED:
		if cl != null and cl["team"] == "enemy":
			return
		if cl != null and cl["team"] == "ally" and (S["curUnit"] == null or cl["id"] == S["curUnit"]["id"]):
			sel_u(cl)
			return
		return
	if E.fsm == E.PLAYER_IDLE:
		if cl != null and cl["team"] == "ally" and (S["curUnit"] == null or cl["id"] == S["curUnit"]["id"]):
			sel_u(cl)
			return
		if cl != null and cl["team"] == "enemy":
			return
	if s != null and cl != null and cl["team"] == "ally":
		if S["curUnit"] == null or cl["id"] == S["curUnit"]["id"]:
			sel_u(cl)
		return
	clr_sel()


# ── 행동 버튼 ──

func act_move() -> void:
	if S["sel"] == null:
		return
	var u: Dictionary = S["sel"]
	S["mvT"] = [] if (Js.truthy(u.get("hm")) or Js.truthy(u.get("mo"))) else E.gu.mv_cells(u)
	E.transition(E.MOVE_MODE)
	E.fx_float(u["x"], u["y"], "messages.select_move_target")


func act_attack() -> void:
	if S["sel"] == null:
		return
	if S["sel"].get("role") == "healer":
		E.transition(E.ATTACK_HEAL_MODE)
	else:
		S["healT"] = []
		E.transition(E.ATTACK_MODE)


func act_wait() -> void:
	if S["sel"] == null:
		return
	var u: Dictionary = S["sel"]
	u["ha"] = true
	if u["team"] == "ally":
		S["allyPos"][u["id"]] = {"x": u["x"], "y": u["y"]}
	_redraw()
	clr_sel()
	E.end_unit_turn(u)


func act_shove() -> void:
	var u: Variant = S["sel"]
	if u == null:
		return
	var ts: Array = E.gu.shove_targets(u)
	if ts.is_empty():
		return
	S["_shove"] = true
	var cells: Array = []
	for v: Dictionary in ts:
		cells.append({"x": v["x"], "y": v["y"]})
	S["atkT"] = cells
	S["coverT"] = []
	S["healT"] = []
	E.transition(E.ATTACK_MODE)
	E.fx_float(u["x"], u["y"], "messages.select_shove_target")


## 밀치기: 1칸 밀어냄. 막히면 충돌 피해, 유닛과 부딪히면 둘 다 피해 (밀려난 쪽은 바라보는 방향 유지)
func do_shove(a: Dictionary, tgt: Dictionary) -> void:
	var plan: Dictionary = E.gu.shove_plan(a, tgt)
	S["_shove"] = false
	S["atkT"] = []
	if not plan["ok"]:
		return
	_grant_exp(a, "attack")
	E.fx_face_dir(a["id"], tgt["x"] - a["x"], tgt["y"] - a["y"])
	a["ha"] = true
	a["hm"] = true
	E.transition(E.ANIMATING)
	var resisted: bool = E.gu.resist_knock(tgt)
	E.later(0.0, _shove_hit.bind(a, tgt, plan, resisted))   # setTimeout(…, playAtkMotion() → 0)


func _shove_hit(a: Dictionary, tgt: Dictionary, plan: Dictionary, resisted: bool) -> void:
	var hurt := func(v: Dictionary, dmg: float) -> void:
		var actual: Dictionary
		if v["team"] == "ally":
			actual = E.apply_dmg_to_ally(v, dmg)
		else:
			v["hp"] = maxf(0.0, v["hp"] - dmg)
			actual = v
		E.fx("float", {"x": actual["x"], "y": actual["y"], "text": "-" + E.num_str(dmg)})
		if actual["hp"] <= 0:
			E.emit("unit_killed", {"killer": a, "target": actual})
	if resisted:
		E.fx_float(tgt["x"], tgt["y"], "messages.knock_resist")
	elif plan["to"] != null:
		var gx: Variant = tgt.get("_gdx")
		var gy: Variant = tgt.get("_gdy")
		tgt["x"] = plan["to"]["x"]
		tgt["y"] = plan["to"]["y"]
		E.fx("move", {"id": tgt["id"], "x": tgt["x"], "y": tgt["y"]})
		_restore_face(tgt, gx, gy)
		E.fx_float(tgt["x"], tgt["y"], "messages.shoved")
		E.gu.chk_trap(tgt)
		if tgt["hp"] <= 0:
			E.emit("unit_killed", {"killer": a, "target": tgt})
	else:
		E.fx_float(tgt["x"], tgt["y"], "messages.shove_crash")
		var mul: float = float(D["TACTICS_ACT"]["shoveUnit"]) if plan["hit"] == "unit" else float(D["TACTICS_ACT"]["shoveCollide"])
		hurt.call(tgt, maxf(1.0, Js.round_js(a["atk"] * mul)))
		if plan.get("other") != null:
			hurt.call(plan["other"], maxf(1.0, Js.round_js(a["atk"] * mul)))
	E.later(450.0, func() -> void:
		E.gu.rm_dead()
		_redraw()
		E.chk_end()
		clr_sel()
		E.end_unit_turn(a))


## u._gdx = gx (undefined 면 키도 undefined 로 — JSON 에서 빠짐)
func _restore_face(u: Dictionary, gx: Variant, gy: Variant) -> void:
	if gx == null:
		u.erase("_gdx")
	else:
		u["_gdx"] = gx
	if gy == null:
		u.erase("_gdy")
	else:
		u["_gdy"] = gy


## 대기·방어 태세·경계 전 방향 고르기
func ask_face(kind: String) -> void:
	var u: Variant = S["sel"]
	if u == null:
		return
	if kind != "wait" and Js.truthy(u.get("ha")):
		return
	S["_facePick"] = {"kind": kind}


func face_done(dx: int, dy: int) -> void:
	var u: Variant = S["sel"]
	var p: Variant = S.get("_facePick")
	if u == null or not Js.truthy(p):
		return
	S["_facePick"] = null
	if dx != 0 or dy != 0:
		u["_gdx"] = dx
		u["_gdy"] = dy
	if p["kind"] == "wait":
		act_wait()
	else:
		act_stance(p["kind"])


func cancel_face() -> void:
	if not Js.truthy(S.get("_facePick")):
		return
	S["_facePick"] = null


func act_stance(kind: String) -> void:
	var u: Variant = S["sel"]
	if u == null or Js.truthy(u.get("ha")):
		return
	if kind == "defend":
		u["_defend"] = true
	else:
		u["_overwatch"] = true
	E.fx_float(u["x"], u["y"], "messages.defend_on" if kind == "defend" else "messages.overwatch_on")
	act_wait()


## 이동 취소 (+ 행동 예고 ⑤ — 되돌렸을 때만)
func act_cancel() -> void:
	var had: bool = Js.truthy(S.get("preMv")) and not Js.truthy(S.get("_facePick")) and not Js.truthy(S.get("_shove")) \
		and not Js.truthy(S.get("_skillMenuOpen")) and not Js.truthy(S.get("_itemMenuOpen")) and not Js.truthy(S.get("_curPotion")) and not Js.truthy(S.get("_curSiege"))
	_act_cancel_raw()
	if had:
		E.plan_rule()


func _act_cancel_raw() -> void:
	if S["sel"] == null:
		return
	if Js.truthy(S.get("_facePick")):
		cancel_face()
		return
	if Js.truthy(S.get("_shove")):
		S["_shove"] = false
		_set_targets(S["sel"])
		E.transition(E.UNIT_SELECTED)
		return
	if Js.truthy(S.get("_skillMenuOpen")):
		S["_skillMenuOpen"] = false
		return
	if Js.truthy(S.get("_itemMenuOpen")):
		S["_itemMenuOpen"] = false
		return
	if Js.truthy(S.get("_curPotion")):
		S["_curPotion"] = null
		S["potionTargets"] = []
		E.transition(E.UNIT_SELECTED)
		_redraw()
		return
	if Js.truthy(S.get("_curSiege")):
		S["_curSiege"] = null
		S["atkT"] = []
		E.transition(E.UNIT_SELECTED)
		return
	if not Js.truthy(S.get("preMv")):
		return
	var u: Dictionary = S["sel"]
	var gx: Variant = u.get("_gdx")
	var gy: Variant = u.get("_gdy")
	var pm: Dictionary = S["preMv"]
	if Js.truthy(pm.get("exp")) and Js.truthy(u.get("uid")):
		S["battleExp"][u["uid"]] = Js.num(S["battleExp"].get(u["uid"])) - float(pm["exp"])
	u["x"] = pm["x"]
	u["y"] = pm["y"]
	u["hm"] = false
	u["mo"] = false
	E.fx("move", {"id": u["id"], "x": u["x"], "y": u["y"]})
	_restore_face(u, gx, gy)
	S["preMv"] = null
	S["_curSkill"] = null
	E.transition(E.PLAYER_IDLE)
	E.later(340.0, clr_sel)


# ── 경험치 ──

func _grant_exp(u: Dictionary, action: String) -> float:
	if u["team"] == "ally" and Js.truthy(u.get("uid")):
		var e: float = E.act_exp(StageRules.stage_level(S["cStage"]), action)
		if e > 0.0:
			S["battleExp"][u["uid"]] = Js.num(S["battleExp"].get(u["uid"])) + e
			E.fx("float", {"x": u["x"], "y": u["y"], "text": "+" + E.num_str(e) + " EXP"})
		return e
	return 0.0


func grant_exp(u: Dictionary, action: String) -> float:
	return _grant_exp(u, action)


func sk_mul(u: Dictionary, sk_id: String) -> float:
	var v: float = Js.num(u["skillLv"].get(sk_id))
	var lv := minf(v if v != 0.0 else 1.0, 10.0)
	return 1.0 + 0.1 * (lv - 1.0)


# ── 이동 ──

func do_mv(u: Dictionary, tx: int, ty: int) -> void:
	var mxp := _grant_exp(u, "move")
	S["preMv"] = {"x": u["x"], "y": u["y"], "exp": mxp}
	E.fx_move_unit(u, tx, ty)
	u["hm"] = true
	u["mo"] = true
	E.transition(E.UNIT_SELECTED)
	if Js.truthy(u.get("_cursed")):
		E.cb.curse_move_tick(u)
	E.gu.chk_trap(u)
	chk_trap_detect(u)
	var a: Array = E.gu.atk_cells(u)
	_enemy_targets(u, a)
	S["healT"] = _heal_cells(u, a)
	S["mvT"] = []


## 함정 감지 패시브 (암살자)
func chk_trap_detect(u: Dictionary) -> void:
	if u["cls"] != "assassin" or Js.num(u["skillLv"].get("assassin_trapdetect")) < 1:
		return
	var enemy := "enemy" if u["team"] == "ally" else "ally"
	var det: Array = []
	for tr: Dictionary in S["traps"]:
		if tr["team"] == enemy and Js.mh(u["x"], u["y"], tr["x"], tr["y"]) <= 2:
			det.append(tr)
	for tr2: Dictionary in det:
		var left: Array = []
		for t3: Dictionary in S["traps"]:
			if t3 != tr2:
				left.append(t3)
		S["traps"] = left
		E.fx_float(tr2["x"], tr2["y"], "messages.trap_detected")


# ── 공격 ──

func do_atk(a: Dictionary, tgt: Dictionary) -> void:
	if typeof(a.get("buffs")) == TYPE_ARRAY:
		var arr: Array = a["buffs"]
		var i := arr.size() - 1
		while i >= 0:
			var b: Dictionary = arr[i]
			if b.get("source") == "shaman_exalt" and Js.num(b.get("_attackCount")) > 0:
				b["_attackCount"] = float(b["_attackCount"]) - 1.0
				if float(b["_attackCount"]) <= 0.0:
					arr.remove_at(i)
					E.fx_float(a["x"], a["y"], "messages.buff_end")
			i -= 1
	var blk: Variant = E.gu.intercept_of(a, tgt)
	if blk != null:
		tgt = blk
		E.fx_float(blk["x"], blk["y"], "messages.intercepted")
	if E.gu.roll_evade(tgt) != null:
		E.fx_face_dir(a["id"], tgt["x"] - a["x"], tgt["y"] - a["y"])
		E.fx_float(tgt["x"], tgt["y"], "messages.evasion")
		a["ha"] = true
		a["hm"] = true
		_redraw()
		clr_sel()
		E.end_unit_turn(a)
		return
	var b_counter: bool = Js.num(tgt["skillLv"].get("brawler_counter")) >= 1 and not (Js.num(tgt.get("stunned")) > 0) and not (Js.num(tgt.get("frozen")) > 0) \
		and float(Js.mh(tgt["x"], tgt["y"], a["x"], a["y"])) <= float(tgt["range"]) and E.c.rand("doAtk.brawler_counter") < 0.3
	var sup: Variant = null
	var ctr_at := 420.0
	if b_counter:
		E.later(420.0, func() -> void:
			var cdmg := maxf(1.0, Js.round_js(tgt["atk"] * 0.5) - a["def"])
			a["hp"] = maxf(0.0, a["hp"] - cdmg)
			_grant_exp(tgt, "attack")
			E.emit("unit_attacked", {"attacker": tgt, "target": a, "damage": cdmg, "isCounter": true}))
	else:
		var dmg: float = E.cb.ench_mod_damage(a, tgt, E.calc_dmg(a, tgt))
		if blk != null:
			dmg = E.gearfx.intercept(blk, maxf(1.0, Js.round_js(dmg * float(D["TACTICS_ACT"]["interceptMul"]))))
		_grant_exp(a, "attack")
		if E.gu.shield_mul(tgt) < 1.0:
			dmg = maxf(1.0, Js.round_js(dmg * E.gu.shield_mul(tgt)))
		tgt["hp"] = maxf(0.0, tgt["hp"] - dmg)
		E.emit("unit_attacked", {"attacker": a, "target": tgt, "damage": dmg})
		E.cb.ench_after_hit(a, tgt, dmg)
		if a["cls"] == "mage" and blk == null:
			var spl := maxf(1.0, Js.round_js(dmg * 0.5))
			for d: Array in [[0, -1], [0, 1], [-1, 0], [1, 0]]:
				var su: Variant = E.gu.u_at(tgt["x"] + d[0], tgt["y"] + d[1])
				if su != null and su["hp"] > 0 and su["team"] == tgt["team"] and su["id"] != tgt["id"]:
					su["hp"] = maxf(0.0, su["hp"] - spl)
					E.emit("unit_attacked", {"attacker": a, "target": su, "damage": spl, "isSplash": true})
					if su["hp"] <= 0:
						E.emit("unit_killed", {"killer": a, "target": su})
		if Js.truthy(a.get("_lastCrit")):
			E.fx_float(a["x"], a["y"], "messages.critical_hit")
		if Js.num(a.get("furyBuff")) > 0:
			E.fx_float(a["x"], a["y"], "messages.fury_buff")
		E.proc_fury(a, tgt)
		var sup_at := 380.0
		ctr_at = 420.0
		sup = E.gu.roll_support(a, tgt)
		if sup != null:
			ctr_at += 400.0
			_grant_exp(sup["sp"], "attack")
			var sp_v: Dictionary = sup
			E.later(sup_at, func() -> void:
				E.gu.emit_support(sp_v)
				if tgt["hp"] <= 0:
					E.emit("unit_killed", {"killer": sp_v["sp"], "target": tgt}))
		if tgt["hp"] > 0 and a["hp"] > 0 and float(Js.mh(tgt["x"], tgt["y"], a["x"], a["y"])) <= float(tgt["range"]) \
				and not (Js.num(tgt.get("stunned")) > 0) and not (Js.num(tgt.get("frozen")) > 0):
			E.later(ctr_at, func() -> void:
				_grant_exp(tgt, "attack")
				var cdmg2: float = E.calc_dmg(tgt, a)
				var da: Dictionary = E.apply_dmg_to_ally(a, cdmg2)
				E.emit("unit_attacked", {"attacker": tgt, "target": da, "damage": cdmg2, "isCounter": true})
				E.proc_fury(tgt, a))
	a["ha"] = true
	a["hm"] = true
	var extra := 450.0 if sup != null else 0.0
	var end_hit := 650.0 + extra
	var cleanup1 := func() -> void:
		E.gu.rm_dead()
		_redraw()
		E.chk_end()
		clr_sel()
		E.end_unit_turn(a)
	var cleanup2 := func() -> void:
		_redraw()
		clr_sel()
		E.end_unit_turn(a)
	if tgt["hp"] <= 0:
		if sup == null:
			E.emit("unit_killed", {"killer": a, "target": tgt})
		E.later(end_hit, cleanup1)
	elif a["hp"] <= 0:
		E.emit("unit_killed", {"killer": tgt, "target": a})
		E.later(maxf(650.0 + extra, ctr_at + 250.0), cleanup1)
	else:
		var can_counter: bool = tgt["hp"] > 0 and a["hp"] > 0 and float(Js.mh(tgt["x"], tgt["y"], a["x"], a["y"])) <= float(tgt["range"]) \
			and not (Js.num(tgt.get("stunned")) > 0) and not (Js.num(tgt.get("frozen")) > 0)
		if can_counter:
			E.later(maxf(650.0 + extra, ctr_at + 250.0), cleanup2)
		else:
			E.later(500.0 + extra, cleanup2)


# ── 회복 ──

func do_heal(h: Dictionary, tgt: Dictionary) -> void:
	var amt := Js.round_js(h["atk"] * 1.5)
	if Js.num(h["skillLv"].get("priest_divinegrace")) >= 1:
		amt = Js.round_js(amt * 1.2)
	if Js.truthy(h.get("_healMul")):
		amt = Js.round_js(amt * float(h["_healMul"]))
	_grant_exp(h, "heal")
	tgt["hp"] = minf(tgt["mhp"], tgt["hp"] + amt)
	E.emit("unit_healed", {"healer": h, "target": tgt, "amount": amt})
	h["ha"] = true
	h["hm"] = true
	E.later(300.0, func() -> void:
		_redraw()
		clr_sel()
		E.end_unit_turn(h))


# ── 스킬 ──

func act_skill(idx: int) -> void:
	if S["sel"] == null:
		return
	var u: Dictionary = S["sel"]
	var skills: Array = E.get_unit_skills(u)
	if idx < 0 or idx >= skills.size():
		return
	var skd: Dictionary = skills[idx]
	if skd.has("cost") and float(u["res"]) < float(skd["cost"]):
		return
	S["_skillMenuOpen"] = false
	S["_curSkill"] = skd
	E.transition(E.SKILL_TARGET)
	if E.sk.has_handler(skd["id"]):
		var result: Variant = E.sk.target(skd["id"], u, skd)
		if result == null:
			E.transition(E.UNIT_SELECTED)
			S["_curSkill"] = null
			return
		if typeof(result) == TYPE_STRING and result == "instant":
			E.transition(E.UNIT_SELECTED)
			do_skill(u, u["x"], u["y"])
			S["_curSkill"] = null
			_redraw()
			return
		S["atkT"] = result
		S["healT"] = []
	else:
		var cells: Array = []
		for d: Array in [[0, -1], [1, 0], [0, 1], [-1, 0]]:
			var px: int = u["x"] + d[0]
			var py: int = u["y"] + d[1]
			if px >= 0 and px < int(D["COLS"]) and py >= 0 and py < int(D["ROWS"]):
				cells.append({"x": px, "y": py})
		S["atkT"] = cells
		S["healT"] = []


func do_skill(u: Dictionary, tx: int, ty: int) -> void:
	var skv: Variant = S.get("_curSkill")
	if skv == null:
		var base: Array = E.get_skills(u["cls"])
		skv = base[0] if not base.is_empty() else null
	if skv == null:
		return
	var sko: Dictionary = skv
	var cost: float = Js.num(sko.get("cost"))
	if float(u["res"]) < cost:
		return
	u["res"] = float(u["res"]) - cost
	E.emit("skill_used", {"unit": u, "skill": sko, "tx": tx, "ty": ty})
	if E.sk.has_handler(sko["id"]):
		E.sk.exec(sko["id"], u, tx, ty, sko)
		return
	u["res"] = float(u["res"]) + cost


## ActionManager._findAdj — 빈 이웃 칸 (방향 위·오른·아래·왼, u 와 가까운 순 안정 정렬)
func find_adj(x: int, y: int, u: Variant) -> Variant:
	var cands: Array = []
	for d: Array in [[0, -1], [1, 0], [0, 1], [-1, 0]]:
		var nx: int = x + d[0]
		var ny: int = y + d[1]
		if nx < 0 or nx >= int(D["COLS"]) or ny < 0 or ny >= int(D["ROWS"]):
			continue
		if not E.gu.passable(nx, ny):
			continue
		if E.gu.u_at(nx, ny) == null:
			cands.append({"x": nx, "y": ny})
	if cands.is_empty():
		return null
	if u == null:
		return cands[0]
	var best: Dictionary = cands[0]
	var bd := Js.mh(best["x"], best["y"], u["x"], u["y"])
	for cc: Dictionary in cands:
		var dd := Js.mh(cc["x"], cc["y"], u["x"], u["y"])
		if dd < bd:
			best = cc
			bd = dd
	return best


# ── 물약 ──

func act_potion(idx: int) -> void:
	if S["sel"] == null:
		return
	var pots: Array = S["_battlePotions"]
	if idx < 0 or idx >= pots.size():
		return
	var pot: Dictionary = pots[idx]
	var def: Variant = (D["BATTLE_POTIONS"] as Dictionary).get(pot["potionId"])
	if def == null:
		return
	S["_itemMenuOpen"] = false
	S["_curPotion"] = {"idx": idx, "def": def, "pot": pot}
	E.transition(E.ITEM_TARGET)
	var u: Dictionary = S["sel"]
	var targets: Array = []
	var is_debuff: bool = def["type"] == "debuff"
	for tu: Dictionary in S["units"]:
		if tu["hp"] <= 0:
			continue
		if float(Js.mh(u["x"], u["y"], tu["x"], tu["y"])) > float(def["range"]):
			continue
		if is_debuff:
			if tu["team"] == "enemy":
				targets.append(tu)
		elif tu["team"] == "ally":
			targets.append(tu)
	if targets.is_empty():
		S["_curPotion"] = null
		E.transition(E.UNIT_SELECTED)
		E.fx_float(u["x"], u["y"], "messages.potion_no_target")
		return
	S["potionTargets"] = targets
	E.fx_float(u["x"], u["y"], "messages.select_potion_target")
	_redraw()


func do_potion(target_u: Dictionary) -> void:
	var potion: Variant = S.get("_curPotion")
	if not Js.truthy(potion):
		return
	var def: Dictionary = potion["def"]
	var u: Dictionary = S["sel"]
	match def["type"]:
		"heal":
			var heal := Js.round_js(target_u["mhp"] * float(def["value"]) / 100.0)
			target_u["hp"] = minf(target_u["mhp"], target_u["hp"] + heal)
			E.emit("unit_healed", {"healer": u, "target": target_u, "amount": heal, "isPotion": true})
		"resource":
			target_u["res"] = minf(target_u["maxRes"], target_u["res"] + float(def["value"]))
			E.emit("unit_healed", {"healer": u, "target": target_u, "amount": def["value"], "isPotion": true})
		"buff":
			(target_u["buffs"] as Array).append({"type": str(def["stat"]) + "_up", "duration": def["duration"], "value": def["value"], "source": "potion"})
			E.emit("buff_applied", {"unit": target_u, "buff": target_u["buffs"][(target_u["buffs"] as Array).size() - 1]})
		"debuff":
			(target_u["buffs"] as Array).append({"type": str(def["stat"]) + "_down", "duration": def["duration"], "value": absf(float(def["value"])), "source": "potion"})
			E.emit("buff_applied", {"unit": target_u, "buff": target_u["buffs"][(target_u["buffs"] as Array).size() - 1]})
	var inv: Array = Profile.load_inventory(E.c)
	var pidx: int = potion["idx"]
	var inv_idx: int = int((S["_battlePotionIndices"] as Array)[pidx])
	if inv_idx >= 0 and inv_idx < inv.size() and Js.truthy(inv[inv_idx]):
		inv[inv_idx]["quantity"] = (float(inv[inv_idx]["quantity"]) if Js.truthy(inv[inv_idx].get("quantity")) else 1.0) - 1.0
		if float(inv[inv_idx]["quantity"]) <= 0.0:
			inv.remove_at(inv_idx)
			(S["_battlePotions"] as Array).remove_at(pidx)
			(S["_battlePotionIndices"] as Array).remove_at(pidx)
			_inv_removed(inv_idx)
		Profile.save_inventory(E.c, inv)
	S["_curPotion"] = null
	S["potionTargets"] = []
	u["ha"] = true
	_redraw()
	clr_sel()
	E.end_unit_turn(u)


## 인벤토리에서 invIdx 칸을 지운 뒤 물약·공성 번호 목록 둘 다 보정 (2a 에서 고친 웹 버그)
func _inv_removed(inv_idx: int) -> void:
	for key: String in ["_battlePotionIndices", "_siegeInvIndices"]:
		var list: Array = S[key]
		for i in list.size():
			if int(list[i]) > inv_idx:
				list[i] = int(list[i]) - 1


# ── 공성 아이템 ──

func act_siege(idx: int) -> void:
	if S["sel"] == null:
		return
	var items: Array = S["_siegeItems"]
	if idx < 0 or idx >= items.size():
		return
	var si: Dictionary = items[idx]
	var def: Variant = null
	for d: Dictionary in D["SIEGE_ITEMS"]:
		if d["id"] == si["siegeId"]:
			def = d
			break
	if def == null:
		return
	S["_itemMenuOpen"] = false
	S["_curSiege"] = {"idx": idx, "def": def, "si": si}
	E.transition(E.ITEM_TARGET)
	var u: Dictionary = S["sel"]
	var targets: Array = []
	for r in int(D["ROWS"]):
		for cc in int(D["COLS"]):
			if float(Js.mh(u["x"], u["y"], cc, r)) > float(def["range"]):
				continue
			var tl: Variant = S["ter"][r][cc]
			if def["targetType"] == "wall" and (tl == "wall" or tl == "gate"):
				targets.append({"x": cc, "y": r})
			elif def["targetType"] == "wall_rock" and (tl == "wall" or tl == "gate" or tl == "rock"):
				targets.append({"x": cc, "y": r})
			elif def["targetType"] == "water" and tl == "water":
				targets.append({"x": cc, "y": r})
	if targets.is_empty():
		S["_curSiege"] = null
		E.transition(E.UNIT_SELECTED)
		E.fx_float(u["x"], u["y"], "messages.siege_no_target")
		return
	S["atkT"] = targets
	S["healT"] = []
	S["mvT"] = []
	E.fx_float(u["x"], u["y"], "messages.select_siege_target")


func do_siege(u: Dictionary, tx: int, ty: int) -> void:
	var siege: Variant = S.get("_curSiege")
	if not Js.truthy(siege):
		return
	var def: Dictionary = siege["def"]
	if def["effect"] == "climb":
		var dx := tx - int(u["x"])
		var dy := ty - int(u["y"])
		var found := false
		var lx := 0
		var ly := 0
		for step in range(1, 4):
			var cx := tx + dx * step
			var cy := ty + dy * step
			if cx < 0 or cx >= int(D["COLS"]) or cy < 0 or cy >= int(D["ROWS"]):
				break
			if E.gu.passable(cx, cy) and E.gu.u_at(cx, cy) == null:
				lx = cx
				ly = cy
				found = true
				break
		if not found:
			E.fx_float(u["x"], u["y"], "messages.siege_no_target")
			S["_curSiege"] = null
			E.transition(E.UNIT_SELECTED)
			return
		E.fx_move_unit(u, lx, ly)
		u["hm"] = true
		u["mo"] = true
		E.emit("siege_used", {"unit": u, "type": "climb", "tx": tx, "ty": ty})
	elif def["effect"] == "destroy":
		S["ter"][ty][tx] = "plain"
		var wk := str(tx) + "," + str(ty)
		if Js.truthy(S["wallHP"].get(wk)):
			S["wallHP"][wk] = 0.0
		if Js.truthy(S["gateHP"].get(wk)):
			S["gateHP"][wk] = 0.0
		E.emit("siege_used", {"unit": u, "type": "destroy", "tx": tx, "ty": ty})
	elif def["effect"] == "bridge":
		S["ter"][ty][tx] = "plain"
		E.emit("siege_used", {"unit": u, "type": "bridge", "tx": tx, "ty": ty})
	var sidx: int = siege["idx"]
	var inv_idx: int = int((S["_siegeInvIndices"] as Array)[sidx])
	var inv: Array = Profile.load_inventory(E.c)
	if inv_idx >= 0 and inv_idx < inv.size():
		inv.remove_at(inv_idx)
		Profile.save_inventory(E.c, inv)
	(S["_siegeItems"] as Array).remove_at(sidx)
	(S["_siegeInvIndices"] as Array).remove_at(sidx)
	_inv_removed(inv_idx)
	if def["effect"] != "climb":
		u["ha"] = true
	S["_curSiege"] = null
	E.fx("redraw_terrain")
	_redraw()
	if def["effect"] == "climb":
		E.transition(E.UNIT_SELECTED)
	else:
		clr_sel()
		E.end_unit_turn(u)


# ═══════════ 명령 실행 (policy.js exec 와 같은 입구·ok 판정) ═══════════

## cmd: { op, x?, y?, target?, skill?, idx?, item?, dx?, dy? } — 기록 사건 cmd 를 효과보다 먼저 남김
func exec_cmd(u: Dictionary, cmd: Dictionary) -> bool:
	var data: Dictionary = {}
	for k: String in cmd.keys():
		if k == "ev" or k == "rng" or k == "ok":
			continue
		data[k] = cmd[k]
	data["u"] = u["id"]
	var ev: Dictionary = E.rec("cmd", data)
	if S["sel"] != u:
		sel_u(u)
	var bx: int = u["x"]
	var by: int = u["y"]
	var ends: int = E.turn_ends
	var op: String = cmd["op"]
	var ok := true
	var x: int = int(cmd.get("x", -1)) if cmd.get("x") != null else -1
	var y: int = int(cmd.get("y", -1)) if cmd.get("y") != null else -1
	match op:
		"undo":
			act_cancel()
			ok = not Js.truthy(u.get("hm")) and not Js.truthy(S.get("preMv"))
		"move":
			act_move()
			cell_ck(x, y)
			ok = u["x"] == x and u["y"] == y
		"attack", "heal":
			act_attack()
			cell_ck(x, y)
			ok = Js.truthy(u.get("ha"))
		"shove":
			act_shove()
			cell_ck(x, y)
			ok = Js.truthy(u.get("ha"))
		"skill":
			act_skill(int(cmd["idx"]))
			if E.fsm == E.SKILL_TARGET:
				cell_ck(x, y)
			ok = E.turn_ends != ends
			if not ok and E.fsm == E.SKILL_TARGET:
				cell_ck(-1, -1)
		"wait", "defend", "overwatch":
			ask_face(op)
			face_done(int(cmd.get("dx", 0)), int(cmd.get("dy", 0)))
			ok = E.turn_ends != ends
		"siege", "climb":
			act_siege(int(cmd["idx"]))
			if E.fsm == E.ITEM_TARGET:
				cell_ck(x, y)
			ok = (u["x"] != bx or u["y"] != by) if op == "climb" else E.turn_ends != ends
			if not ok and E.fsm == E.ITEM_TARGET:
				act_cancel()
		"potion":
			act_potion(int(cmd["idx"]))
			if E.fsm == E.ITEM_TARGET:
				cell_ck(x, y)
			ok = E.turn_ends != ends
			if not ok and E.fsm == E.ITEM_TARGET:
				act_cancel()
		_:
			push_error("battle_action: 알 수 없는 명령 " + op)
			ok = false
	if not ev.is_empty():
		ev["ok"] = ok
	return ok
