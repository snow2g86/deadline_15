extends RefCounted
## 지형·길찾기·유닛 — 웹 js/battle/grid.js (Grid) + js/battle/unit.js (UnitManager)
##  유닛은 웹 객체와 같은 키를 가진 Dictionary (id·uid·x·y 는 int, 나머지 숫자는 float). 키가 있고 없음까지 웹과 같게 둔다
##  (황금 기록의 spawn 이 유닛 전체를 비교하므로). E = battle_engine.gd

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const Gear := preload("res://scripts/logic/gear.gd")
const Hazards := preload("res://scripts/logic/hazards.gd")
const StageRules := preload("res://scripts/logic/stage_rules.gd")

const DIRS4 := [[0, -1], [0, 1], [-1, 0], [1, 0]]

var E: Object
var S: Dictionary
var D: Dictionary
var COLS: int
var ROWS: int


func _init(engine: Object) -> void:
	E = engine
	S = engine.S
	D = engine.D
	COLS = int(D["COLS"])
	ROWS = int(D["ROWS"])


func tile(x: int, y: int) -> Variant:
	if y < 0 or y >= (S["ter"] as Array).size():
		return null
	var row: Array = S["ter"][y]
	if x < 0 or x >= row.size():
		return null
	return row[x]


func ti(t: Variant) -> Dictionary:
	return D["TI"].get(t, {})


func passable(x: int, y: int) -> bool:
	var t: Variant = tile(x, y)
	return t != null and Js.truthy(ti(t).get("pass"))


# ═══════════ Grid ═══════════

## Grid.genT — 지형 생성 (가운데 행 칸마다 난수 1회) + 길 보장
func gen_t() -> void:
	S["ter"] = []
	S["gateHP"] = {}
	S["wallHP"] = {}
	S["breached"] = 0
	var mid: int = int(D["MID_C"])
	var wall_row := func(row: int) -> Array:
		var r: Array = []
		for c in COLS:
			if (c >= mid - 3 and c <= mid - 2) or (c >= mid + 1 and c <= mid + 2):
				r.append("wall")
				S["wallHP"][str(c) + "," + str(row)] = 200.0
			elif c >= mid - 1 and c <= mid:
				r.append("gate")
				S["gateHP"][str(c) + "," + str(row)] = 2.0
			else:
				r.append("water")
		return r
	var moat_row := func() -> Array:
		var r: Array = []
		for c in COLS:
			r.append("plain" if (c >= mid - 1 and c <= mid) else "water")
		return r
	var st: Variant = S.get("cStage")
	var is_off: bool = st != null and st.get("style") == "offense"
	for r in ROWS:
		var row: Array
		if not is_off and r == 14:
			row = wall_row.call(r)
		elif not is_off and r == 13:
			row = moat_row.call()
		elif is_off and r == 0:
			row = wall_row.call(r)
		elif is_off and r == 1:
			row = moat_row.call()
		elif r <= 1 or r >= 11:
			row = []
			for c in COLS:
				row.append("plain")
		else:
			var mt: Variant = st.get("mapType") if st != null else null
			var theme: Dictionary = D["MAP_THEMES"][mt if Js.truthy(mt) else "plains"]
			var d: Dictionary = theme["dist"]
			row = []
			for c in COLS:
				var rn: float = E.c.rand("genT")
				var acc := 0.0
				var t := "plain"
				acc += Js.num(d.get("rock"))
				if rn < acc:
					t = "rock"
				else:
					acc += Js.num(d.get("hill"))
					if rn < acc:
						t = "hill"
					else:
						acc += Js.num(d.get("forest"))
						if rn < acc:
							t = "forest"
						else:
							acc += Js.num(d.get("water"))
							if rn < acc:
								t = "water"
							else:
								acc += Js.num(d.get("shallow"))
								if rn < acc:
									t = "shallow"
				row.append(t)
		(S["ter"] as Array).append(row)
	_ensure_path(2 if is_off else 1)


func _path_ok(goal_row: int) -> bool:
	var seen: Dictionary = {}
	var q: Array = []
	for c in COLS:
		if passable(c, 11):
			q.append([c, 11])
			seen[str(c) + ",11"] = true
	var qi := 0
	while qi < q.size():
		var p: Array = q[qi]
		qi += 1
		var x: int = p[0]
		var y: int = p[1]
		if y <= goal_row:
			return true
		for d: Array in [[0, -1], [1, 0], [-1, 0], [0, 1]]:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			var k := str(nx) + "," + str(ny)
			if nx < 0 or nx >= COLS or ny < goal_row or ny > 11 or seen.has(k) or not passable(nx, ny):
				continue
			seen[k] = true
			q.append([nx, ny])
	return false


func _ensure_path(goal_row: int) -> void:
	if _path_ok(goal_row):
		return
	var open1 := func(x: int, y: int) -> void:
		if x >= 0 and x < COLS and not passable(x, y):
			S["ter"][y][x] = "plain"
	var open := func(x: int, y: int) -> void:
		open1.call(x, y)
		open1.call(x + (1 if x < COLS - 1 else -1), y)
	var x := 1 + int(floorf(E.c.rand("_ensurePath") * (COLS - 2)))
	var y := 10
	while y > goal_row:
		open.call(x, y)
		if E.c.rand("_ensurePath") < 0.4:
			var nx := maxi(0, mini(COLS - 1, x + (-1 if E.c.rand("_ensurePath") < 0.5 else 1)))
			open.call(nx, y)
			x = nx
		y -= 1
	open.call(x, goal_row)


func terrain_cost(t: Variant) -> float:
	var info := ti(t)
	if info.is_empty() or not Js.truthy(info.get("pass")):
		return INF
	if t == "forest":
		return 1.5
	if t == "hill":
		return 2.0
	return float(info["cost"]) if Js.truthy(info.get("cost")) else 1.0


## Grid.mvCells — 아군 이동 범위 (BFS 큐 순서·중복 그대로)
func mv_cells(u: Dictionary) -> Array:
	if E.buff_has(u, "stun") or E.buff_has(u, "freeze"):
		return []
	var res: Array = []
	var vis: Dictionary = {}
	var q: Array = [[u["x"], u["y"], 0.0]]
	var is_stealth: bool = u["cls"] == "assassin" and u["team"] == "ally" and tile(u["x"], u["y"]) == "forest"
	vis[str(u["x"]) + "," + str(u["y"])] = 0.0
	var qi := 0
	while qi < q.size():
		var p: Array = q[qi]
		qi += 1
		var x: int = p[0]
		var y: int = p[1]
		var cst: float = p[2]
		var occ: Variant = u_at(x, y)
		var occ_hidden: bool = occ != null and occ["team"] != u["team"] and E.is_stealthed(occ)
		if cst > 0.0 and (occ == null or occ_hidden):
			res.append({"x": x, "y": y})
		if cst > 0.0 and occ != null and occ["team"] != u["team"] and not occ_hidden and is_stealth and tile(x, y) == "forest":
			res.append({"x": x, "y": y})
		if cst > 0.0 and in_zoc(u, x, y):
			continue
		for d: Array in DIRS4:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			if nx < 0 or nx >= COLS or ny < 0 or ny >= ROWS:
				continue
			var info := ti(S["ter"][ny][nx])
			if not Js.truthy(info.get("pass")):
				continue
			var tcost: float = float(info["cost"])
			var o: Variant = u_at(nx, ny)
			var o_hidden: bool = o != null and o["team"] != u["team"] and E.is_stealthed(o)
			var k := str(nx) + "," + str(ny)
			if o != null and o["team"] != u["team"] and not o_hidden:
				if is_stealth and S["ter"][ny][nx] == "forest":
					var nc := cst + tcost
					if nc <= float(u["move"]):
						if not vis.has(k) or float(vis[k]) > nc:
							vis[k] = nc
				continue
			if o != null and o["team"] == u["team"]:
				var nc2 := cst + tcost
				if nc2 > float(u["move"]):
					continue
				if not vis.has(k) or float(vis[k]) > nc2:
					vis[k] = nc2
					q.append([nx, ny, nc2])
				continue
			var nc3 := cst + tcost
			if nc3 > float(u["move"]):
				continue
			if not vis.has(k) or float(vis[k]) > nc3:
				vis[k] = nc3
				q.append([nx, ny, nc3])
	_add_vault(u, vis, res)
	return res


## Grid._addVault — 도움닫기 (궁수·암살자): vis 삽입 순서대로
func _add_vault(u: Dictionary, vis: Dictionary, res: Array) -> void:
	if not (D["VAULT_CLASSES"] as Array).has(u["cls"]):
		return
	var has: Dictionary = {}
	for m: Dictionary in res:
		has[str(m["x"]) + "," + str(m["y"])] = true
	var vd: int = int(D["VAULT_DIST"])
	for key: String in vis.keys():
		var parts := key.split(",")
		var x := parts[0].to_int()
		var y := parts[1].to_int()
		var start: bool = x == u["x"] and y == u["y"]
		if not start and in_zoc(u, x, y):
			continue
		var here: Variant = u_at(x, y)
		if not start and here != null and here["team"] != u["team"]:
			continue
		for d: Array in DIRS4:
			var dx: int = d[0]
			var dy: int = d[1]
			var mate: Variant = u_at(x + dx, y + dy)
			if mate == null or mate["id"] == u["id"] or mate["team"] != u["team"] or mate["hp"] <= 0:
				continue
			for i in range(1, vd + 1):
				var lx := x + dx * (1 + i)
				var ly := y + dy * (1 + i)
				if lx < 0 or lx >= COLS or ly < 0 or ly >= ROWS or not passable(lx, ly):
					break
				var o: Variant = u_at(lx, ly)
				if o != null and not (o["team"] != u["team"] and E.is_stealthed(o)):
					continue
				var k := str(lx) + "," + str(ly)
				if not has.has(k) and not (lx == u["x"] and ly == u["y"]):
					has[k] = true
					res.append({"x": lx, "y": ly, "vault": true})


## Grid.eMvCells — 적 이동 범위 (지형 비용 적용)
func e_mv_cells(u: Dictionary) -> Array:
	var res: Array = []
	var vis: Dictionary = {}
	var q: Array = [[u["x"], u["y"], 0.0]]
	vis[str(u["x"]) + "," + str(u["y"])] = 0.0
	var qi := 0
	while qi < q.size():
		var p: Array = q[qi]
		qi += 1
		var x: int = p[0]
		var y: int = p[1]
		var cst: float = p[2]
		var occ: Variant = u_at(x, y)
		var occ_st: bool = occ != null and E.is_stealthed(occ)
		if cst > 0.0 and (occ == null or occ_st):
			res.append({"x": x, "y": y})
		if cst > 0.0 and in_zoc(u, x, y):
			continue
		for d: Array in DIRS4:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			if nx < 0 or nx >= COLS or ny < 0 or ny >= ROWS:
				continue
			var t: Variant = S["ter"][ny][nx]
			if not Js.truthy(ti(t).get("pass")):
				continue
			var o: Variant = u_at(nx, ny)
			if o != null and o["team"] != u["team"] and not E.is_stealthed(o):
				continue
			var nc := cst + terrain_cost(t)
			if nc > float(u["move"]):
				continue
			var k := str(nx) + "," + str(ny)
			if not vis.has(k) or float(vis[k]) > nc:
				vis[k] = nc
				q.append([nx, ny, nc])
	_add_vault(u, vis, res)
	return res


## Grid.atkCells — 행(y) 바깥·열(x) 안쪽 순서 (언덕 위 원거리 +1)
func atk_cells(u: Dictionary) -> Array:
	var cells: Array = []
	var on_hill: bool = tile(u["x"], u["y"]) == "hill"
	var rng: float = float(u["range"]) + (float(D["TACTIC"]["highRange"]) if on_hill and float(u["range"]) > 1.0 else 0.0)
	for r in ROWS:
		for c in COLS:
			if float(Js.mh(u["x"], u["y"], c, r)) <= rng and not (c == u["x"] and r == u["y"]):
				cells.append({"x": c, "y": r})
	return cells


func has_cell(cells: Array, x: int, y: int) -> bool:
	for c: Dictionary in cells:
		if c["x"] == x and c["y"] == y:
			return true
	return false


## Grid.chkTrap
func chk_trap(u: Dictionary) -> bool:
	var enemy := "enemy" if u["team"] == "ally" else "ally"
	var trap: Variant = null
	for tr: Dictionary in S["traps"]:
		if tr["x"] == u["x"] and tr["y"] == u["y"] and tr["team"] == enemy:
			trap = tr
			break
	if trap == null:
		return false
	var trap_stun: float = float(trap["stun"]) if Js.truthy(trap.get("stun")) else 2.0
	u["hp"] = maxf(0.0, u["hp"] - float(trap["dmg"]))
	E.buff_apply(u, {"type": "stun", "duration": trap_stun, "icon": "⚡", "source": "trap"})
	var left: Array = []
	for tr2: Dictionary in S["traps"]:
		if tr2 != trap:
			left.append(tr2)
	S["traps"] = left
	E.emit("trap_triggered", {"unit": u, "trap": trap, "damage": trap["dmg"], "stun": trap_stun})
	return true


## Grid.chkSpearwall — 창병 패시브 창벽
func chk_spearwall(enemy: Dictionary) -> void:
	if enemy["team"] != "enemy" or enemy["hp"] <= 0:
		return
	for u: Dictionary in S["units"]:
		if u["team"] == "ally" and u["hp"] > 0 and Js.num(u["skillLv"].get("lancer_spearwall")) >= 1 \
				and not Js.truthy(u.get("_spearwallUsed")) and not E.buff_has(u, "stun") and not E.buff_has(u, "freeze") \
				and float(Js.mh(u["x"], u["y"], enemy["x"], enemy["y"])) <= float(u["range"]):
			u["_spearwallUsed"] = true
			var dmg := maxf(1.0, Js.round_js(u["atk"] * 0.5) - enemy["def"])
			enemy["hp"] = maxf(0.0, enemy["hp"] - dmg)
			E.emit("unit_attacked", {"attacker": u, "target": enemy, "damage": dmg, "isSpearwall": true})
			if enemy["hp"] <= 0:
				E.emit("unit_killed", {"killer": u, "target": enemy})
			return


# ═══════════ UnitManager ═══════════

func _select_random_siege_type() -> String:
	var types := [["bomb", 40.0], ["shield", 30.0], ["evasion", 20.0], ["detour", 10.0]]
	var rand: float = E.c.rand("_selectRandomSiegeType") * 100.0
	for t: Array in types:
		if rand < float(t[1]):
			return t[0]
		rand -= float(t[1])
	return "bomb"


func _create_siege_item(type: String) -> Dictionary:
	var defs := {
		"bomb": ["💣 폭탄", "폭발로 주변 피해"], "shield": ["🛡️ 방어막", "일시적 방어 증가"],
		"evasion": ["⚡ 회피", "다음 공격 회피"], "detour": ["🛣️ 우회로", "이동 경로 개선"],
	}
	var d: Array = defs.get(type, defs["bomb"])
	return {"id": E.c.rand("_createSiegeItem"), "type": type, "name": d[0], "description": d[1], "targetType": "self", "cooldown": 0.0}


## battle/constants.js toBattleStats(uid)
func to_battle_stats(uid: Variant) -> Variant:
	var c: Object = E.c
	var ch: Variant = Profile.get_char(c, uid)
	if ch == null:
		return null
	var d: Dictionary = D["JAB"][ch["cls"]]
	if not Js.truthy(ch.get("equip")):
		ch["equip"] = {"weapon": null, "offhand": null, "helmet": null, "armor": null, "boots": null, "necklace": null, "earring": null, "ring": null}
	var eq := Gear.calc_equip_bonus(c, ch)
	var gear: Dictionary = eq["gear"] if eq.get("gear") != null else {}
	var range_add: float = eq["range"] if float(ch["range"]) > 1.0 else 0.0
	var res_rec: float = d["resRec"]
	if d["res"] == "mana" or d["res"] == "energy":
		res_rec = Js.round_js((res_rec + Js.num(gear.get("res_rec"))) * (1.0 + Js.num(gear.get("res_rec_pct")) / 100.0))
	var enchants := Hazards.enchants_of(c, ch)
	if Js.truthy(gear.get("immune_fire")):
		enchants.append("fire")
	if Js.truthy(gear.get("immune_heat")):
		enchants.append("heat")
	var rec_base: float = Js.num(ch.get("actionRec"))
	if rec_base == 0.0:
		rec_base = Js.num(d.get("actionRec"))
	if rec_base == 0.0:
		rec_base = 1.0
	return {
		"uid": ch["uid"], "cls": ch["cls"], "lv": ch["lv"],
		"name": ch["customName"] if Js.truthy(ch.get("customName")) else str(ch.get("nameId")),
		"hp": float(ch["hp"]) + eq["hp"], "mhp": float(ch["hp"]) + eq["hp"], "atk": float(ch["atk"]) + eq["atk"], "def": float(ch["def"]) + eq["def"],
		"move": minf(float(ch["move"]) + eq["move"], 6.0), "range": minf(float(ch["range"]) + range_add, 5.0),
		"role": D["ROLE_MAP"].get(ch["cls"]),
		"res": float(d["maxRes"]) if d["res"] == "mana" else 0.0,
		"maxRes": d["maxRes"], "resType": d["res"], "resRec": res_rec,
		"actionRec": Js.round_js((rec_base + Js.num(gear.get("speed"))) * 100.0) / 100.0,
		"skillLv": ch["skillLv"] if typeof(ch.get("skillLv")) == TYPE_DICTIONARY else {},
		"gender": ch["gender"] if Js.truthy(ch.get("gender")) else "m",
		"enchants": enchants,
		"gear": gear, "fullSet": eq.get("fullSet"),
	}


## UnitManager.addUnit — 아군은 uid(int), 적·기타는 직업 이름
func add_unit(team: String, src: Variant, x: int, y: int) -> Variant:
	var cls: String
	var hp: float
	var mhp: float
	var atk: float
	var def: float
	var mv: float
	var rng: float
	var role: Variant
	var res_type: Variant
	var max_res: float
	var res_rec: float
	var init_res: float
	var uid: Variant = 0
	var lv: Variant = 1
	var gender := "m"
	var action_rec := 1.0
	var skill_lv: Variant = null
	var bs: Variant = null
	if team == "ally" and typeof(src) == TYPE_INT:
		bs = to_battle_stats(src)
		if bs == null:
			return null
		cls = bs["cls"]
		hp = bs["hp"]
		mhp = bs["mhp"]
		atk = bs["atk"]
		def = bs["def"]
		mv = bs["move"]
		rng = bs["range"]
		role = bs["role"]
		res_type = bs["resType"]
		max_res = bs["maxRes"]
		res_rec = bs["resRec"]
		init_res = bs["res"]
		uid = bs["uid"]
		lv = bs["lv"]
		gender = bs["gender"]
		action_rec = bs["actionRec"]
		skill_lv = bs["skillLv"]
	else:
		cls = src
		var d: Dictionary = D["JAB"][cls]
		var st: Variant = S.get("cStage")
		hp = d["base"]["hp"]
		atk = d["base"]["atk"]
		def = d["base"]["def"]
		mv = d["base"]["move"]
		rng = d["base"]["range"]
		role = D["ROLE_MAP"].get(cls)
		res_type = d["res"]
		max_res = d["maxRes"]
		res_rec = d["resRec"]
		if team == "enemy" and st != null:
			var sl := StageRules.stage_level(st)
			var g: Dictionary = d["growth"]
			var avg := func(k: String) -> float: return (float(g[k][0]) + float(g[k][1])) / 2.0
			var lvf := StageRules.stage_enemy_lv(D, sl)
			lv = int(lvf)
			hp = float(d["base"]["hp"]) + avg.call("hp") * float(D["ENEMY_HP_GROWTH_MUL"]) * (lvf - 1.0)
			atk = float(d["base"]["atk"]) + avg.call("atk") * (lvf - 1.0)
			def = Js.round_js(float(d["base"]["def"]) + avg.call("def") * float(D["ENEMY_DEF_GROWTH_MUL"]) * (lvf - 1.0))
			hp = Js.round_js(hp * float(st["sm"]["hp"]))
			atk = Js.round_js(atk * float(st["sm"]["atk"]))
			var skl := StageRules.stage_enemy_skill_lv(D, sl)
			skill_lv = {}
			if skl > 1.0:
				for sk: Dictionary in E.get_skills(cls):
					skill_lv[sk["id"]] = skl
		mhp = hp
		init_res = max_res if d["res"] == "mana" else 0.0
		gender = Profile.random_gender(E.c)
		action_rec = float(d["actionRec"]) if Js.truthy(d.get("actionRec")) else 1.0
	var u := {
		"id": int(S["nid"]), "uid": uid, "team": team, "cls": cls, "lv": lv, "x": x, "y": y, "hp": hp, "mhp": mhp, "atk": atk, "def": def,
		"move": mv, "range": rng, "role": role, "name": cls, "gender": gender,
		"res": init_res, "maxRes": max_res, "resType": res_type, "resRec": res_rec,
		"actionPow": 0.0, "actionRec": action_rec,
		"hm": false, "ha": false, "waited": false, "mo": false,
		"furyBuff": 0.0, "defBuff": 0.0, "stunned": 0.0, "frozen": 0.0, "disarmed": 0.0,
		"channeling": null,
		"buffs": [],
		"skillLv": skill_lv if skill_lv != null else {},
	}
	S["nid"] = int(S["nid"]) + 1
	if team == "ally" and bs != null:
		u["enchants"] = bs["enchants"]
		if not (bs["gear"] as Dictionary).is_empty():
			u["gear"] = bs["gear"]
		if Js.truthy(bs["fullSet"]):
			u["_fullSet"] = bs["fullSet"]
	if team == "enemy":
		u["origSpawn"] = {"x": x, "y": y}
		u["siegeItems"] = [_create_siege_item(_select_random_siege_type())]
	(S["units"] as Array).append(u)
	E.emit("unit_added", {"unit": u})
	return u


## UnitManager.uAt — 같은 칸에 여럿이면 적을 먼저 (암살자 겹침)
func u_at(x: int, y: int) -> Variant:
	var first: Variant = null
	var count := 0
	for u: Dictionary in S["units"]:
		if u["x"] == x and u["y"] == y and u["hp"] > 0:
			count += 1
			if first == null:
				first = u
			if count > 1:
				break
	if count <= 1:
		return first
	for u2: Dictionary in S["units"]:
		if u2["x"] == x and u2["y"] == y and u2["hp"] > 0 and u2["team"] == "enemy":
			return u2
	return first


func alive(team: String) -> Array:
	var out: Array = []
	for u: Dictionary in S["units"]:
		if u["team"] == team and u["hp"] > 0:
			out.append(u)
	return out


## UnitManager.rmDead — 영적 유대·처치 수·경험치 풀·전사자 기록 후 제거
func rm_dead() -> void:
	for u: Dictionary in S["units"]:
		if u["hp"] > 0:
			continue
		if Js.truthy(u.get("isSummon")) and Js.truthy(u.get("summonerId")):
			for s: Dictionary in S["units"]:
				if s["id"] == u["summonerId"] and s["hp"] > 0 and Js.num(s["skillLv"].get("summoner_soulbond")) >= 1:
					s["res"] = minf(s["maxRes"], s["res"] + 40.0)
					E.emit("soulbond_restore", {"summoner": s, "amount": 40.0})
					break
		if u["team"] == "enemy" and not Js.truthy(u.get("_counted")):
			u["_counted"] = true
			S["_killCount"] = int(S["_killCount"]) + 1
			S["_killExpPool"] = float(S["_killExpPool"]) + E.kill_exp(StageRules.stage_level(S["cStage"]), u["cls"])
		if u["team"] == "ally" and Js.truthy(u.get("uid")) and not Js.truthy(u.get("_counted")):
			u["_counted"] = true
			(S["_deadAllyUids"] as Array).append(u["uid"])
			if u["cls"] == D["COMMANDER_CLS"]:
				S["_commanderFallen"] = true
	var left: Array = []
	for u2: Dictionary in S["units"]:
		if u2["hp"] > 0:
			left.append(u2)
	S["units"] = left


func is_stunned(u: Dictionary) -> bool:
	return E.buff_has(u, "stun") or Js.num(u.get("stunned")) > 0


func is_frozen(u: Dictionary) -> bool:
	return E.buff_has(u, "freeze") or Js.num(u.get("frozen")) > 0


func is_cc(u: Dictionary) -> bool:
	return is_stunned(u) or is_frozen(u)


## 엄호: 대상 옆 같은 편 기사가 공격자에게 더 가까우면 그 기사 (일반 단일 공격만)
func cover_of(attacker: Variant, target: Variant) -> Variant:
	if attacker == null or target == null or (D["COVER_IGNORE_CLASSES"] as Array).has(attacker["cls"]):
		return null
	if (D["PROJECTILE_CLASSES"] as Array).has(attacker["cls"]):
		return null
	var dT := Js.mh(attacker["x"], attacker["y"], target["x"], target["y"])
	for g: Dictionary in S["units"]:
		if g["hp"] > 0 and g["id"] != target["id"] and g["team"] == target["team"] and (D["GUARD_CLASSES"] as Array).has(g["cls"]) \
				and not is_cc(g) and Js.mh(g["x"], g["y"], target["x"], target["y"]) == 1 and Js.mh(attacker["x"], attacker["y"], g["x"], g["y"]) < dT:
			return g
	return null


## 투사체 차단: 지나가는 칸의 대상 편 기사
func intercept_of(attacker: Variant, target: Variant) -> Variant:
	if attacker == null or target == null or not (D["PROJECTILE_CLASSES"] as Array).has(attacker["cls"]):
		return null
	for c: Dictionary in line_cells(attacker["x"], attacker["y"], target["x"], target["y"]):
		var g: Variant = u_at(c["x"], c["y"])
		if g != null and g["hp"] > 0 and g["id"] != target["id"] and g["team"] == target["team"] and (D["GUARD_CLASSES"] as Array).has(g["cls"]):
			return g
	return null


func line_cells(x0: int, y0: int, x1: int, y1: int) -> Array:
	var out: Array = []
	var seen: Dictionary = {str(x0) + "," + str(y0): true, str(x1) + "," + str(y1): true}
	var n := maxi(absi(x1 - x0), absi(y1 - y0)) * 4
	var add := func(x: int, y: int) -> void:
		var k := str(x) + "," + str(y)
		if not seen.has(k):
			seen[k] = true
			out.append({"x": x, "y": y})
	for i in range(1, n):
		var fx := float(x0) + float(x1 - x0) * float(i) / float(n)
		var fy := float(y0) + float(y1 - y0) * float(i) / float(n)
		var hx := absf(fx - floorf(fx) - 0.5) < 1e-9
		var hy := absf(fy - floorf(fy) - 0.5) < 1e-9
		if hx and hy:
			continue
		var rx := Js.round_i(fx)
		var ry := Js.round_i(fy)
		if hx:
			add.call(int(floorf(fx)), ry)
			add.call(int(ceilf(fx)), ry)
		elif hy:
			add.call(rx, int(floorf(fy)))
			add.call(rx, int(ceilf(fy)))
		else:
			add.call(rx, ry)
	return out


## 전술 보너스 → { mul, tags, capped }
func tactic_bonus(a: Dictionary, t: Dictionary) -> Dictionary:
	var T: Dictionary = D["TACTIC"]
	var tags: Array = []
	var add := 0.0
	var fx: float = Js.num(t.get("_gdx"))
	var fy: float = Js.num(t.get("_gdy"))
	var dx: float = float(a["x"] - t["x"])
	var dy: float = float(a["y"] - t["y"])
	if (fx != 0.0 or fy != 0.0) and (dx != 0.0 or dy != 0.0) and not Js.truthy(t.get("_defend")):
		var cosv := (dx * fx + dy * fy) / (Js.hypot(dx, dy) * Js.hypot(fx, fy))
		if cosv < -0.5:
			add += float(T["back"])
			tags.append("back")
		elif cosv <= 0.5:
			add += float(T["side"])
			tags.append("side")
	for p: Dictionary in S["units"]:
		if p["hp"] > 0 and p["id"] != a["id"] and p["team"] == a["team"] and Js.mh(p["x"], p["y"], t["x"], t["y"]) == 1 \
				and float(p["x"] - t["x"]) * dx + float(p["y"] - t["y"]) * dy < 0.0:
			add += float(T["pincer"])
			tags.append("pincer")
			break
	if tile(a["x"], a["y"]) == "hill" and tile(t["x"], t["y"]) != "hill":
		add += float(T["high"])
		tags.append("high")
	return {"mul": 1.0 + minf(add, float(T["cap"])), "tags": tags, "capped": add > float(T["cap"])}


## 일반 공격 회피 (공성 회피 버프 → 숲) → 'siege' | 'forest' | null   [기록: evade]
func roll_evade(tgt: Dictionary) -> Variant:
	var r0: int = E.c.rng.calls
	var r: Variant = null
	if E.buff_has(tgt, "evasion") and E.c.rand("rollEvade") < 0.3:
		E.buff_remove(tgt, "evasion", "siege")
		r = "siege"
	elif tile(tgt["x"], tgt["y"]) == "forest" and E.c.rand("rollEvade") < float(D["TACTIC"]["forestEvade"]):
		r = "forest"
	if r != null:
		E.rec_r("evade", r0, {"u": tgt["id"], "kind": r})
	return r


func shield_mul(tgt: Dictionary) -> float:
	return 0.5 if E.buff_has(tgt, "shield") else 1.0


func in_zoc(u: Dictionary, x: int, y: int) -> bool:
	if (D["COVER_IGNORE_CLASSES"] as Array).has(u["cls"]):
		return false
	for g: Dictionary in S["units"]:
		if g["hp"] > 0 and g["team"] != u["team"] and (D["GUARD_CLASSES"] as Array).has(g["cls"]) and not is_cc(g) and Js.mh(g["x"], g["y"], x, y) == 1:
			return true
	return false


## 밀치기 결과 (부작용 없음) → { ok, to, hit, other }
func shove_plan(a: Dictionary, t: Dictionary) -> Dictionary:
	var dx := Js.sign_js(t["x"] - a["x"])
	var dy := Js.sign_js(t["y"] - a["y"])
	if Js.mh(a["x"], a["y"], t["x"], t["y"]) != 1 or Js.truthy(t.get("isBoss")):
		return {"ok": false}
	var nx: int = t["x"] + dx
	var ny: int = t["y"] + dy
	var tl: Variant = tile(nx, ny)
	if nx < 0 or ny < 0 or nx >= COLS or ny >= ROWS or tl == null or not Js.truthy(ti(tl).get("pass")):
		return {"ok": true, "to": null, "hit": "wall"}
	var o: Variant = u_at(nx, ny)
	if o != null and o["hp"] > 0:
		return {"ok": true, "to": null, "hit": "unit", "other": o}
	return {"ok": true, "to": {"x": nx, "y": ny}, "hit": null}


## 넉백 저항 (기사 70% + 장비)   [기록: knock]
func resist_knock(t: Dictionary) -> bool:
	var r0: int = E.c.rng.calls
	var r := minf(1.0, Js.num((D["KNOCK_RESIST"] as Dictionary).get(t["cls"])) + E.gearfx.knock_resist(t))
	var res: bool = r > 0.0 and E.c.rand("resistKnock") < r
	E.rec_r("knock", r0, {"u": t["id"], "resisted": res})
	return res


func shove_targets(a: Dictionary) -> Array:
	var out: Array = []
	for v: Dictionary in S["units"]:
		if v["hp"] > 0 and v["team"] != a["team"] and not E.is_stealthed(v) and Js.mh(a["x"], a["y"], v["x"], v["y"]) == 1 and shove_plan(a, v)["ok"]:
			out.append(v)
	return out


## 지원 공격자: 대상 옆 같은 편 중 공격력이 가장 높은 하나 (안정 정렬 첫째)
func supporter_of(a: Dictionary, tgt: Dictionary) -> Variant:
	var best: Variant = null
	for p: Dictionary in S["units"]:
		if p["hp"] > 0 and p["id"] != a["id"] and p["team"] == a["team"] and not Js.truthy(p.get("isSummon")) \
				and p.get("role") != "healer" and not is_cc(p) and not (Js.num(p.get("disarmed")) > 0) and not E.buff_has(p, "disarm") \
				and not E.is_stealthed(p) and Js.mh(p["x"], p["y"], tgt["x"], tgt["y"]) == 1:
			if best == null or p["atk"] > best["atk"]:
				best = p
	return best


## 지원 공격 판정 + 피해 적용 → { sp, dmg, actual } | null   [기록: support]
func roll_support(a: Dictionary, tgt: Dictionary) -> Variant:
	var r0: int = E.c.rng.calls
	if tgt["hp"] <= 0:
		return null
	var sp: Variant = supporter_of(a, tgt)
	if sp == null or E.c.rand("rollSupport") >= float(D["SUPPORT"]["chance"]):
		return null
	var dmg := maxf(1.0, Js.round_js(E.calc_dmg(sp, tgt) * float(D["SUPPORT"]["mul"]) * shield_mul(tgt)))
	sp["_lastTactic"] = null
	var actual: Dictionary
	if tgt["team"] == "ally":
		actual = E.apply_dmg_to_ally(tgt, dmg)
	else:
		tgt["hp"] = maxf(0.0, tgt["hp"] - dmg)
		actual = tgt
	var r := {"sp": sp, "dmg": dmg, "actual": actual}
	E.rec_r("support", r0, {"sp": sp["id"], "a": a["id"], "t": tgt["id"], "dmg": dmg, "hit": actual["id"]})
	return r


func emit_support(r: Dictionary) -> void:
	var sp: Dictionary = r["sp"]
	var actual: Dictionary = r["actual"]
	E.fx_face_dir(sp["id"], actual["x"] - sp["x"], actual["y"] - sp["y"])
	E.emit("unit_attacked", {"attacker": sp, "target": actual, "damage": r["dmg"], "isSupport": true})
	E.proc_fury(sp, actual)


func is_lava_map() -> bool:
	return S.get("cStage") != null and S["cStage"].get("mapType") == "volcano"


## 용암(화산 맵의 물)과 상하좌우로 붙어 있는가
func near_lava(x: int, y: int) -> bool:
	if not is_lava_map():
		return false
	for d: Array in DIRS4:
		if tile(x + d[0], y + d[1]) == "water":
			return true
	return false
