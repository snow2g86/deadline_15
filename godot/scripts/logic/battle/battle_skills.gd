extends RefCounted
## 스킬 — 웹 js/skills/{warrior,knight,assassin,mage,archer,priest,novice,summoner,shaman,brawler,lancer,sapper}.js + _registry.js
##  target(id, u, sk) → 칸 배열 | "instant" | null,  exec(id, u, tx, ty, sk) → 효과 → _skill_done(차례 끝) 또는 _skill_refund
##  Fx.later 는 연출을 끄면 즉시 실행 → 여기서도 바로 실행. G._mvU 는 unit_moved 를 내는 진짜 이동, Fx.animU 는 좌표만.
##  기록 사건 skill_fx: exec 시작 → _skill_done 사이에 바뀐 HP·위치. E = battle_engine.gd

const Js := preload("res://scripts/logic/js.gd")

const DIRS8 := [[-1, -1], [0, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [0, 1], [1, 1]]
const DIRS4 := [[0, -1], [1, 0], [0, 1], [-1, 0]]

const HANDLERS := ["warrior_powersmash", "warrior_cleave", "warrior_assault", "warrior_criticalstrike",
	"knight_switch", "knight_charge", "knight_sacrifice", "knight_capture",
	"assassin_assassinate", "assassin_ambush", "assassin_smoke",
	"mage_fireburst", "mage_freeze", "mage_grandwall",
	"archer_dash", "archer_snipe", "archer_rapidfire", "archer_steelrain",
	"priest_massheal", "priest_purify", "priest_sanctuary",
	"novice_throw", "novice_firstaid", "novice_tackle",
	"summoner_summon_spirit", "summoner_summon_golem", "summoner_empower", "summoner_soulburst",
	"shaman_curse", "shaman_exalt", "shaman_poisonmist", "shaman_spiritsurge",
	"brawler_disarm", "brawler_flurry", "brawler_crush",
	"lancer_pierce", "lancer_charge", "lancer_phalanx",
	"sapper_trap", "sapper_excavate", "sapper_detonate"]

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


func has_handler(id: String) -> bool:
	return HANDLERS.has(id)


# ── 공통 ──

func _mh(a: Dictionary, x: int, y: int) -> int:
	return Js.mh(a["x"], a["y"], x, y)


func _cells_of(units: Array) -> Array:
	var out: Array = []
	for v: Dictionary in units:
		out.append({"x": v["x"], "y": v["y"]})
	return out


func _enemies_within(u: Dictionary, r: float, min_r: float = 0.0) -> Array:
	var out: Array = []
	for v: Dictionary in S["units"]:
		if v["team"] == "enemy" and v["hp"] > 0 and float(_mh(u, v["x"], v["y"])) <= r and float(_mh(u, v["x"], v["y"])) >= min_r:
			out.append(v)
	return out


func _find(pred: Callable) -> Variant:
	for v: Dictionary in S["units"]:
		if pred.call(v):
			return v
	return null


func _enemy_at(x: int, y: int) -> Variant:
	return _find(func(v: Dictionary) -> bool: return v["hp"] > 0 and v["x"] == x and v["y"] == y and v["team"] == "enemy")


func _float(x: int, y: int, key: String, params: Dictionary = {}) -> void:
	E.fx_float(x, y, key, params)


func _rng(sk: Dictionary, key: String, dflt: float) -> float:
	return float(sk[key]) if Js.truthy(sk.get(key)) else dflt


func _sk_mul(u: Dictionary, id: String) -> float:
	return E.am.sk_mul(u, id)


func _exp(u: Dictionary, action: String) -> void:
	E.am.grant_exp(u, action)


func _rm_dead() -> void:
	E.gu.rm_dead()


## _skillDone — 차례 끝 (Fx.later 즉시) + 기록 skill_fx
## (5단계) 효과음 힌트 — 웹 스킬 코드의 G.sfxAtk(u.cls)·sfxHeal·sfxMove·sfxUIClick·sfxExplosion 자리.
##  소리만 (E.sfx → fx_event "sfx": 기록·순수 조회·규칙과 무관 — 황금 기록 그대로)
func _sfx(n: String, u: Dictionary = {}) -> void:
	E.sfx(n, str(u.get("cls", "")))


## 웹: if (tgt.hp <= 0) { G.sfxKill(); G.sfxDeath(); … }
func _sfx_kill(t: Dictionary) -> void:
	if t["hp"] <= 0:
		E.sfx("kill")
		E.sfx("death")


func _skill_done(u: Dictionary, opts: Dictionary = {}) -> void:
	if _skill_before_valid():
		var b: Dictionary = E._skill_before
		E._skill_before = null
		var hits: Array = []
		var moved: Array = []
		for e: Array in b["units"]:
			var v: Dictionary = e[0]
			if v["hp"] != e[1]:
				hits.append([v["id"], e[1], v["hp"]])
		for e2: Array in b["units"]:
			var v2: Dictionary = e2[0]
			if v2["x"] != e2[2] or v2["y"] != e2[3]:
				moved.append([v2["id"], v2["x"], v2["y"]])
		E.rec_r("skill_fx", b["rng"], {"skill": b["skill"], "u": b["u"], "hits": hits, "moved": moved})
	u["ha"] = true
	u["hm"] = true
	S["_curSkill"] = null
	if Js.truthy(opts.get("rTer")):
		E.fx("redraw_terrain")
	if Js.truthy(opts.get("rmDead")):
		_rm_dead()
	E.fx_redraw_units()
	if Js.truthy(opts.get("chkEnd")):
		E.chk_end()
	E.am.clr_sel()
	E.end_unit_turn(u)


func _skill_before_valid() -> bool:
	return E._skill_before != null


## _skillRefund — 비용 환불 + 행동 메뉴로
func _skill_refund(u: Dictionary, sk: Dictionary) -> void:
	u["res"] = float(u["res"]) + Js.num(sk.get("cost"))
	S["_curSkill"] = null
	S["atkT"] = []
	S["healT"] = []
	var a: Array = E.gu.atk_cells(u)
	var at: Array = []
	for cc: Dictionary in a:
		var v: Variant = E.gu.u_at(cc["x"], cc["y"])
		if v != null and v["team"] == "enemy":
			at.append(cc)
	S["atkT"] = at
	if u.get("role") == "healer":
		var ht: Array = []
		for cc2: Dictionary in a:
			var v2: Variant = E.gu.u_at(cc2["x"], cc2["y"])
			if v2 != null and v2["team"] == "ally" and v2["hp"] < v2["mhp"] and v2["id"] != u["id"]:
				ht.append(cc2)
		S["healT"] = ht
	E.fx_redraw_units()


func _no_empty(u: Dictionary, sk: Dictionary) -> void:
	_skill_refund(u, sk)
	_float(u["x"], u["y"], "messages.no_empty_tile")


func _cells_xy(pred: Callable) -> Array:   # x 바깥·y 안쪽 순서 (웹 스킬의 for x … for y)
	var out: Array = []
	for x in COLS:
		for y in ROWS:
			if pred.call(x, y):
				out.append({"x": x, "y": y})
	return out


func _free(x: int, y: int) -> bool:
	return E.gu.passable(x, y) and E.gu.u_at(x, y) == null


func _trap_at(x: int, y: int) -> bool:
	for tr: Dictionary in S["traps"]:
		if tr["x"] == x and tr["y"] == y:
			return true
	return false


# ═══════════ target ═══════════

func target(id: String, u: Dictionary, sk: Dictionary) -> Variant:
	match id:
		"warrior_powersmash", "warrior_criticalstrike":
			return _cells_of(_enemies_within(u, float(u["range"])))
		"warrior_cleave", "assassin_smoke", "priest_massheal", "priest_sanctuary", "lancer_phalanx":
			return "instant"
		"warrior_assault":
			return _cells_of(_enemies_within(u, _rng(sk, "assaultRange", 5.0)))
		"knight_switch":
			return _allies_within(u, _rng(sk, "switchRange", 2.0))
		"knight_charge":
			return _cells_of(_enemies_within(u, _rng(sk, "chargeRange", 1.0)))
		"knight_sacrifice":
			return _allies_within(u, _rng(sk, "sacrificeRange", 5.0))
		"knight_capture":
			return _cells_of(_enemies_within(u, _rng(sk, "captureRange", 5.0)))
		"assassin_assassinate":
			if not E.is_stealthed(u):
				return null
			if _find(func(v: Dictionary) -> bool: return v["team"] == "enemy" and v["hp"] > 0 and v["x"] == u["x"] and v["y"] == u["y"]) == null:
				return null
			return "instant"
		"assassin_ambush":
			if not E.is_stealthed(u):
				return null
			return _cells_of(_enemies_within(u, _rng(sk, "ambushRange", 2.0)))
		"mage_fireburst":
			return _cells_of(_enemies_within(u, float(u["range"])))
		"mage_freeze":
			return _cells_of(_enemies_within(u, _rng(sk, "freezeRange", 5.0)))
		"mage_grandwall":
			var wr := _rng(sk, "wallRange", 1.0)
			return _cells_xy(func(x: int, y: int) -> bool:
				var d := _mh(u, x, y)
				return float(d) <= wr and d > 0 and E.gu.passable(x, y) and E.gu.u_at(x, y) == null and not _trap_at(x, y))
		"archer_dash":
			var r := _rng(sk, "dashRange", 4.0)
			return _cells_xy(func(x: int, y: int) -> bool:
				var d := _mh(u, x, y)
				return d > 0 and float(d) <= r and E.gu.passable(x, y) and E.gu.u_at(x, y) == null)
		"archer_snipe":
			return _cells_of(_enemies_within(u, _rng(sk, "snipeMax", 10.0), _rng(sk, "snipeMin", 5.0)))
		"archer_rapidfire":
			return _cells_of(_enemies_within(u, _rng(sk, "rapidRange", 5.0)))
		"archer_steelrain":
			return _cells_xy(func(x: int, y: int) -> bool:
				var d := _mh(u, x, y)
				return float(d) <= float(u["range"]) and d > 0)
		"priest_purify":
			var pr := _rng(sk, "purifyRange", 5.0)
			var out: Array = []
			for v: Dictionary in S["units"]:
				if v["team"] == "ally" and v["hp"] > 0 and v["id"] != u["id"] and float(_mh(u, v["x"], v["y"])) <= pr \
						and (Js.num(v.get("stunned")) > 0 or Js.num(v.get("frozen")) > 0 or Js.num(v.get("disarmed")) > 0 or Js.num(v.get("_bleedTurns")) > 0 or Js.num(v.get("_rootedTurns")) > 0):
					out.append({"x": v["x"], "y": v["y"]})
			return out
		"novice_throw":
			return _cells_of(_enemies_within(u, _rng(sk, "throwRange", 4.0)))
		"novice_firstaid":
			var ar := _rng(sk, "aidRange", 1.0)
			var cells: Array = []
			for v2: Dictionary in S["units"]:
				if v2["team"] == "ally" and v2["hp"] > 0 and v2["hp"] < v2["mhp"] and not Js.truthy(v2.get("isSummon")) and float(_mh(u, v2["x"], v2["y"])) <= ar:
					cells.append({"x": v2["x"], "y": v2["y"]})
			return cells if not cells.is_empty() else null
		"novice_tackle":
			return _cells_of(_enemies_within(u, _rng(sk, "tackleRange", 2.0)))
		"summoner_summon_spirit", "summoner_summon_golem":
			for s: Dictionary in S["units"]:
				if Js.truthy(s.get("isSummon")) and Js.same(s.get("summonerId"), u["id"]):
					_float(u["x"], u["y"], "messages.summoner_limit")
					return null
			var sr := _rng(sk, "summonRange", 3.0)
			return _cells_xy(func(x: int, y: int) -> bool:
				var d := _mh(u, x, y)
				return float(d) <= sr and d > 0 and E.gu.passable(x, y) and E.gu.u_at(x, y) == null)
		"summoner_empower", "summoner_soulburst":
			var sums: Array = []
			for s2: Dictionary in S["units"]:
				if Js.truthy(s2.get("isSummon")) and Js.same(s2.get("summonerId"), u["id"]) and s2["hp"] > 0:
					sums.append(s2)
			if sums.is_empty():
				_float(u["x"], u["y"], "messages.summoner_no_summon")
				return null
			return _cells_of(sums)
		"shaman_curse":
			return _cells_of(_enemies_within(u, _rng(sk, "curseRange", 5.0)))
		"shaman_exalt":
			return _allies_within(u, _rng(sk, "exaltRange", 5.0))
		"shaman_poisonmist":
			var mr := _rng(sk, "mistRange", 5.0)
			return _cells_xy(func(x: int, y: int) -> bool:
				var d := _mh(u, x, y)
				return float(d) <= mr and d > 0)
		"shaman_spiritsurge":
			return _cells_of(_enemies_within(u, _rng(sk, "surgeRange", 5.0)))
		"brawler_disarm":
			return _cells_of(_enemies_within(u, _rng(sk, "disarmRange", 1.0)))
		"brawler_flurry", "brawler_crush":
			return _cells_of(_enemies_within(u, 1.0))
		"lancer_pierce":
			var plen := int(_rng(sk, "pierceLen", 3.0))
			var targets: Array = []
			for d4: Array in DIRS4:
				var line: Array = []
				for i in range(1, plen + 1):
					var px: int = u["x"] + d4[0] * i
					var py: int = u["y"] + d4[1] * i
					if px < 0 or px >= COLS or py < 0 or py >= ROWS:
						break
					line.append({"x": px, "y": py})
					if not E.gu.passable(px, py):
						break
				var has_e := false
				for cc: Dictionary in line:
					if _enemy_at(cc["x"], cc["y"]) != null:
						has_e = true
						break
				if has_e:
					targets.append_array(line)
			return targets
		"lancer_charge":
			var cr := int(_rng(sk, "chargeRange", 3.0))
			var t2: Array = []
			for d5: Array in DIRS4:
				for i2 in range(1, cr + 1):
					var px2: int = u["x"] + d5[0] * i2
					var py2: int = u["y"] + d5[1] * i2
					if px2 < 0 or px2 >= COLS or py2 < 0 or py2 >= ROWS:
						break
					if _enemy_at(px2, py2) != null:
						t2.append({"x": px2, "y": py2})
						break
					if not E.gu.passable(px2, py2):
						break
					if E.gu.u_at(px2, py2) != null:
						break
			return t2
		"sapper_trap":
			var tr := _rng(sk, "trapRange", 1.0)
			return _cells_xy(func(x: int, y: int) -> bool:
				var d := _mh(u, x, y)
				return d > 0 and float(d) <= tr and E.gu.passable(x, y) and E.gu.u_at(x, y) == null and not _trap_at(x, y))
		"sapper_excavate":
			var er := _rng(sk, "excavateRange", 1.0)
			return _cells_xy(func(x: int, y: int) -> bool:
				var d := _mh(u, x, y)
				return float(d) <= er and d > 0 and E.gu.tile(x, y) == "rock")
		"sapper_detonate":
			var dr := _rng(sk, "detonateRange", 5.0)
			var t3: Array = []
			for trp: Dictionary in S["traps"]:
				if trp["team"] == "ally" and float(_mh(u, trp["x"], trp["y"])) <= dr:
					t3.append({"x": trp["x"], "y": trp["y"]})
			return t3
	return null


func _allies_within(u: Dictionary, r: float) -> Array:
	var out: Array = []
	for v: Dictionary in S["units"]:
		if v["team"] == "ally" and v["hp"] > 0 and v["id"] != u["id"] and float(_mh(u, v["x"], v["y"])) <= r:
			out.append({"x": v["x"], "y": v["y"]})
	return out


# ═══════════ exec ═══════════

func exec(id: String, u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var units: Array = []
	for v: Dictionary in S["units"]:
		units.append([v, v["hp"], v["x"], v["y"]])
	E._skill_before = {"skill": sk["id"], "u": u["id"], "rng": E.c.rng.calls, "units": units}
	call("_x_" + id, u, tx, ty, sk)


func _dmg_sub(u: Dictionary, mul: float, id: String, tgt: Dictionary) -> float:
	return maxf(1.0, Js.round_js(u["atk"] * mul * _sk_mul(u, id)) - tgt["def"])


# ── 전사 ──

func _x_warrior_powersmash(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var tgt: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "enemy" and v["hp"] > 0 and float(_mh(u, v["x"], v["y"])) <= float(u["range"]))
	if tgt == null:
		_skill_refund(u, sk)
		return
	var dmg := maxf(1.0, Js.round_js(u["atk"] * 1.5 * _sk_mul(u, "warrior_powersmash")) - tgt["def"])
	tgt["hp"] = maxf(0.0, tgt["hp"] - dmg)
	_sfx("atk", u)
	_sfx_kill(tgt)
	E.fx_attack(u, tgt)
	_float(u["x"], u["y"], "skills.warrior_powersmash")
	E.proc_fury(u, tgt)
	if tgt["hp"] <= 0:
		_rm_dead()
	_exp(u, "attack")
	_skill_done(u, {"chkEnd": true})


func _x_warrior_cleave(u: Dictionary, _tx: int, _ty: int, _sk: Dictionary) -> void:
	for d: Array in DIRS8:
		var px: int = u["x"] + d[0]
		var py: int = u["y"] + d[1]
		if px < 0 or px >= COLS or py < 0 or py >= ROWS:
			continue
		var tgt: Variant = _enemy_at(px, py)
		if tgt != null:
			tgt["hp"] = maxf(0.0, tgt["hp"] - _dmg_sub(u, 1.2, "warrior_cleave", tgt))
			_sfx_kill(tgt)
			if tgt["hp"] <= 0:
				_rm_dead()
	_sfx("atk", u)
	_exp(u, "attack")
	_float(u["x"], u["y"], "messages.warrior_cleave")
	E.proc_fury(u, u)
	_skill_done(u, {"chkEnd": true})


func _x_warrior_assault(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var ar := _rng(sk, "assaultRange", 5.0)
	var tgt: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "enemy" and v["hp"] > 0 and float(_mh(u, v["x"], v["y"])) <= ar)
	if tgt == null:
		_skill_refund(u, sk)
		return
	var adj: Variant = E.am.find_adj(tgt["x"], tgt["y"], u)
	if adj == null:
		_no_empty(u, sk)
		return
	u["x"] = adj["x"]
	u["y"] = adj["y"]
	u["mo"] = true
	E.fx("move", {"id": u["id"], "x": u["x"], "y": u["y"]})
	for d: Array in DIRS8:
		var px: int = u["x"] + d[0]
		var py: int = u["y"] + d[1]
		if px < 0 or px >= COLS or py < 0 or py >= ROWS:
			continue
		var e: Variant = _enemy_at(px, py)
		if e != null:
			e["hp"] = maxf(0.0, e["hp"] - _dmg_sub(u, 0.8, "warrior_assault", e))
			_sfx_kill(e)
			if e["hp"] <= 0:
				_rm_dead()
	_sfx("atk", u)
	_sfx("explosion")
	_exp(u, "attack")
	_float(u["x"], u["y"], "messages.warrior_assault")
	E.proc_fury(u, u)
	_skill_done(u, {"chkEnd": true})


func _x_warrior_criticalstrike(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var tgt: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "enemy" and v["hp"] > 0 and float(_mh(u, v["x"], v["y"])) <= float(u["range"]))
	if tgt == null:
		_skill_refund(u, sk)
		return
	var dmg := maxf(1.0, Js.round_js(u["atk"] * _sk_mul(u, "warrior_criticalstrike")) - tgt["def"])
	tgt["hp"] = maxf(0.0, tgt["hp"] - dmg)
	tgt["_bleedTurns"] = 3.0
	tgt["_bleedDmg"] = maxf(1.0, Js.round_js(u["atk"] * 0.2))
	_sfx("atk", u)
	_sfx_kill(tgt)
	E.fx_attack(u, tgt)
	_float(tgt["x"], tgt["y"], "messages.warrior_bleed")
	_float(u["x"], u["y"], "messages.warrior_criticalstrike")
	E.proc_fury(u, tgt)
	if tgt["hp"] <= 0:
		_rm_dead()
	_exp(u, "attack")
	_skill_done(u, {"chkEnd": true})


# ── 기사 ──

func _x_knight_switch(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var sr := _rng(sk, "switchRange", 2.0)
	var ally: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "ally" and v["hp"] > 0 and v["id"] != u["id"] and float(_mh(u, v["x"], v["y"])) <= sr)
	if ally == null:
		_skill_refund(u, sk)
		return
	var ox: int = u["x"]
	var oy: int = u["y"]
	u["x"] = ally["x"]
	u["y"] = ally["y"]
	ally["x"] = ox
	ally["y"] = oy
	E.fx("move", {"id": u["id"], "x": u["x"], "y": u["y"]})
	E.fx("move", {"id": ally["id"], "x": ally["x"], "y": ally["y"]})
	_sfx("move")
	_float(u["x"], u["y"], "messages.knight_switch")
	E.proc_fury(u, u)
	_skill_done(u)


func _x_knight_charge(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var cr := _rng(sk, "chargeRange", 1.0)
	var tgt: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "enemy" and v["hp"] > 0 and float(_mh(u, v["x"], v["y"])) <= cr)
	if tgt == null:
		_skill_refund(u, sk)
		return
	var dmg := _dmg_sub(u, 0.8, "knight_charge", tgt)
	tgt["hp"] = maxf(0.0, tgt["hp"] - dmg)
	tgt["stunned"] = maxf(Js.num(tgt.get("stunned")), 1.0)
	_sfx("atk", u)
	_sfx_kill(tgt)
	E.fx_attack(u, tgt)
	_float(tgt["x"], tgt["y"], "messages.stunned")
	E.proc_fury(u, tgt)
	_float(u["x"], u["y"], "messages.knight_charge")
	if tgt["hp"] <= 0:
		_rm_dead()
	_exp(u, "attack")
	_skill_done(u, {"chkEnd": true})


func _x_knight_sacrifice(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var sr := _rng(sk, "sacrificeRange", 5.0)
	var ally: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "ally" and v["hp"] > 0 and v["id"] != u["id"] and float(_mh(u, v["x"], v["y"])) <= sr)
	if ally == null:
		_skill_refund(u, sk)
		return
	ally["_sacrificeKnight"] = u["id"]
	u["_sacrificeDmgCount"] = 2.0
	u["_sacrificeTarget"] = ally["id"]
	_sfx("heal")
	_float(u["x"], u["y"], "messages.knight_sacrifice")
	_float(ally["x"], ally["y"], "messages.knight_sacrifice_protect")
	E.proc_fury(u, u)
	_skill_done(u)


func _x_knight_capture(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var cr := _rng(sk, "captureRange", 5.0)
	var enemy: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "enemy" and v["hp"] > 0 and float(_mh(u, v["x"], v["y"])) <= cr)
	if enemy == null:
		_skill_refund(u, sk)
		return
	var adj: Variant = E.am.find_adj(u["x"], u["y"], enemy)
	if adj == null:
		_no_empty(u, sk)
		return
	if E.gu.resist_knock(enemy):
		_float(enemy["x"], enemy["y"], "messages.knock_resist")
		_skill_done(u)
		return
	enemy["x"] = adj["x"]
	enemy["y"] = adj["y"]
	E.fx("move", {"id": enemy["id"], "x": enemy["x"], "y": enemy["y"]})
	_sfx("atk", u)
	_float(u["x"], u["y"], "messages.knight_capture")
	_float(enemy["x"], enemy["y"], "messages.knight_captured")
	E.proc_fury(u, u)
	_exp(u, "attack")
	_skill_done(u)


# ── 암살자 ──

func _x_assassin_assassinate(u: Dictionary, _tx: int, _ty: int, sk: Dictionary) -> void:
	var tgt: Variant = _find(func(v: Dictionary) -> bool: return v["team"] == "enemy" and v["hp"] > 0 and v["x"] == u["x"] and v["y"] == u["y"])
	if tgt == null or not E.is_stealthed(u):
		_skill_refund(u, sk)
		return
	var dmg := maxf(1.0, Js.round_js(u["atk"] * 5.0 * _sk_mul(u, "assassin_assassinate")) - tgt["def"])
	tgt["hp"] = maxf(0.0, tgt["hp"] - dmg)
	_sfx("atk", u)
	_float(u["x"], u["y"], "messages.assassin_assassinate")
	var adj: Variant = E.am.find_adj(u["x"], u["y"], u)
	if adj != null:
		E.fx_move_unit(u, adj["x"], adj["y"])
	_sfx_kill(tgt)   # 웹 assassin.js: 공격음 → 옆 칸으로 이동 → 처치음
	_exp(u, "attack")
	_skill_done(u, {"rmDead": true, "chkEnd": true})


func _x_assassin_ambush(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	if not E.is_stealthed(u):
		_skill_refund(u, sk)
		return
	var r := _rng(sk, "ambushRange", 2.0)
	var tgt: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "enemy" and v["hp"] > 0 and float(_mh(u, v["x"], v["y"])) <= r)
	if tgt == null:
		_skill_refund(u, sk)
		return
	var adj: Variant = E.am.find_adj(tgt["x"], tgt["y"], u)
	if adj == null:
		_no_empty(u, sk)
		return
	E.fx_move_unit(u, adj["x"], adj["y"])
	u["mo"] = true
	var dmg := maxf(1.0, u["atk"] * 2.0 - tgt["def"])
	tgt["hp"] = maxf(0.0, tgt["hp"] - dmg)
	_sfx("atk", u)
	_sfx_kill(tgt)
	_float(u["x"], u["y"], "messages.assassin_raid")
	if tgt["hp"] <= 0:
		u["res"] = minf(u["maxRes"], u["res"] + 20.0)
		_rm_dead()
	_exp(u, "attack")
	_skill_done(u, {"chkEnd": true})


func _x_assassin_smoke(u: Dictionary, _tx: int, _ty: int, sk: Dictionary) -> void:
	E.buff_apply(u, {"type": "stealth", "duration": _rng(sk, "smokeTurns", 2.0), "icon": "🌫️", "source": "assassin_smoke"})
	u["stealthBroken"] = false
	_sfx("move")
	_float(u["x"], u["y"], "messages.assassin_smoke")
	_skill_done(u)


# ── 마법사 ──

func _x_mage_fireburst(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var hit: Array = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var px := tx + dx
			var py := ty + dy
			if px < 0 or px >= COLS or py < 0 or py >= ROWS:
				continue
			var tgt: Variant = _enemy_at(px, py)
			if tgt != null:
				hit.append(tgt)
	if hit.is_empty():
		_skill_refund(u, sk)
		return
	for tgt2: Dictionary in hit:
		tgt2["hp"] = maxf(0.0, tgt2["hp"] - _dmg_sub(u, 1.2, "mage_fireburst", tgt2))
		_sfx_kill(tgt2)
	_sfx("atk", u)
	_float(u["x"], u["y"], "messages.mage_fireball")
	_exp(u, "attack")
	_skill_done(u, {"rmDead": true, "chkEnd": true})


func _x_mage_freeze(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var tgt: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "enemy" and v["hp"] > 0)
	if tgt == null:
		_skill_refund(u, sk)
		return
	tgt["hp"] = maxf(0.0, tgt["hp"] - _dmg_sub(u, 1.2, "mage_freeze", tgt))
	tgt["frozen"] = maxf(Js.num(tgt.get("frozen")), 2.0)
	_sfx("atk", u)
	_sfx_kill(tgt)
	_float(tgt["x"], tgt["y"], "messages.frozen")
	_float(u["x"], u["y"], "messages.mage_freeze")
	if tgt["hp"] <= 0:
		_rm_dead()
	_exp(u, "attack")
	_skill_done(u, {"chkEnd": true})


func _x_mage_grandwall(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	if not E.gu.passable(tx, ty) or E.gu.u_at(tx, ty) != null or _trap_at(tx, ty):
		_skill_refund(u, sk)
		return
	S["ter"][ty][tx] = "wall"
	E.magic_walls.append({"x": tx, "y": ty})
	_sfx("uiclick")
	_float(tx, ty, "messages.mage_grandwall")
	_exp(u, "attack")
	_skill_done(u, {"rTer": true})


# ── 궁수 ──

func _x_archer_dash(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	if not E.gu.passable(tx, ty) or E.gu.u_at(tx, ty) != null:
		_skill_refund(u, sk)
		return
	E.fx_move_unit(u, tx, ty)
	u["mo"] = true
	_sfx("move")
	_float(u["x"], u["y"], "messages.archer_leap")
	_exp(u, "move")
	_skill_done(u)


func _x_archer_snipe(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var smin := _rng(sk, "snipeMin", 5.0)
	var smax := _rng(sk, "snipeMax", 10.0)
	var tgt: Variant = _find(func(v: Dictionary) -> bool:
		var d := float(_mh(u, v["x"], v["y"]))
		return v["x"] == tx and v["y"] == ty and v["team"] == "enemy" and v["hp"] > 0 and d >= smin and d <= smax)
	if tgt == null:
		_skill_refund(u, sk)
		return
	tgt["hp"] = maxf(0.0, tgt["hp"] - _dmg_sub(u, 1.5, "archer_snipe", tgt))
	_sfx("atk", u)
	_sfx_kill(tgt)
	_float(u["x"], u["y"], "messages.archer_snipe")
	if tgt["hp"] <= 0:
		_rm_dead()
	_exp(u, "attack")
	_skill_done(u, {"chkEnd": true})


func _x_archer_rapidfire(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var tgt: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "enemy" and v["hp"] > 0)
	if tgt == null:
		_skill_refund(u, sk)
		return
	var lvv: float = Js.num(u["skillLv"].get("archer_rapidfire"))
	var sk_lv := minf(lvv if lvv != 0.0 else 1.0, 3.0)
	var hits := int(sk_lv + 1.0)
	for i in hits:
		if tgt["hp"] <= 0:
			break
		tgt["hp"] = maxf(0.0, tgt["hp"] - _dmg_sub(u, 0.8, "archer_rapidfire", tgt))
	_sfx("atk", u)
	_sfx_kill(tgt)
	_float(u["x"], u["y"], "messages.archer_rapidfire", {"hits": hits})
	if tgt["hp"] <= 0:
		_rm_dead()
	_exp(u, "attack")
	_skill_done(u, {"chkEnd": true})


func _x_archer_steelrain(u: Dictionary, tx: int, ty: int, _sk: Dictionary) -> void:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var px := tx + dx
			var py := ty + dy
			if px < 0 or px >= COLS or py < 0 or py >= ROWS:
				continue
			var tgt: Variant = _enemy_at(px, py)
			if tgt != null:
				tgt["hp"] = maxf(0.0, tgt["hp"] - _dmg_sub(u, 1.0, "archer_steelrain", tgt))
				_sfx_kill(tgt)
				if tgt["hp"] <= 0:
					_rm_dead()
	_sfx("atk", u)
	_exp(u, "attack")
	_float(u["x"], u["y"], "messages.archer_steelrain")
	_skill_done(u, {"chkEnd": true})


# ── 사제 ──

func _x_priest_massheal(u: Dictionary, _tx: int, _ty: int, sk: Dictionary) -> void:
	var hr := _rng(sk, "healRange", 6.0)
	var targets: Array = []
	for v: Dictionary in S["units"]:
		if v["team"] == "ally" and v["hp"] > 0 and v["hp"] < v["mhp"] and float(_mh(u, v["x"], v["y"])) <= hr:
			targets.append(v)
	if targets.is_empty():
		_skill_refund(u, sk)
		return
	var amt := maxf(1.0, Js.round_js(u["atk"] * 0.8))
	if Js.num(u["skillLv"].get("priest_divinegrace")) >= 1:
		amt = Js.round_js(amt * 1.2)
	for t: Dictionary in targets:
		var heal := minf(t["mhp"] - t["hp"], amt)
		t["hp"] = t["hp"] + heal
	_sfx("heal")
	_float(u["x"], u["y"], "messages.priest_mass_heal")
	_exp(u, "heal")
	_skill_done(u)


func _x_priest_purify(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var tgt: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "ally" and v["hp"] > 0 and v["id"] != u["id"])
	if tgt == null:
		_skill_refund(u, sk)
		return
	for k: String in ["stunned", "frozen", "disarmed", "_bleedTurns", "_bleedDmg", "_rootedTurns"]:
		tgt[k] = 0.0
	_sfx("heal")
	_float(tgt["x"], tgt["y"], "messages.priest_purify")
	_float(u["x"], u["y"], "messages.priest_purify_cast")
	_exp(u, "heal")
	_skill_done(u)


func _x_priest_sanctuary(u: Dictionary, _tx: int, _ty: int, sk: Dictionary) -> void:
	var sr := _rng(sk, "sanctuaryRange", 6.0)
	var targets: Array = []
	for v: Dictionary in S["units"]:
		if v["team"] == "ally" and v["hp"] > 0 and float(_mh(u, v["x"], v["y"])) <= sr:
			targets.append(v)
	if targets.is_empty():
		_skill_refund(u, sk)
		return
	var amt := maxf(1.0, Js.round_js(u["atk"] * 0.5))
	if Js.num(u["skillLv"].get("priest_divinegrace")) >= 1:
		amt = Js.round_js(amt * 1.2)
	for t: Dictionary in targets:
		t["_sanctuaryTurns"] = 4.0
		t["_sanctuaryHeal"] = amt
	_sfx("heal")
	_float(u["x"], u["y"], "messages.priest_sanctuary")
	_exp(u, "heal")
	_skill_done(u)


# ── 노비스 ──

func _x_novice_throw(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var r := _rng(sk, "throwRange", 4.0)
	var tgt: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "enemy" and v["hp"] > 0 and float(_mh(u, v["x"], v["y"])) <= r)
	if tgt == null:
		_skill_refund(u, sk)
		return
	tgt["hp"] = maxf(0.0, tgt["hp"] - _dmg_sub(u, 0.8, "novice_throw", tgt))
	_sfx("atk", u)
	_sfx_kill(tgt)
	_float(u["x"], u["y"], "skills.novice_throw")
	if tgt["hp"] <= 0:
		_rm_dead()
	_exp(u, "attack")
	_skill_done(u, {"chkEnd": true})


func _x_novice_firstaid(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var r := _rng(sk, "aidRange", 1.0)
	var v: Variant = _find(func(w: Dictionary) -> bool: return w["x"] == tx and w["y"] == ty and w["team"] == "ally" and w["hp"] > 0 and float(_mh(u, w["x"], w["y"])) <= r)
	if v == null:
		_skill_refund(u, sk)
		return
	var pct := _rng(sk, "aidPct", 15.0)
	var heal := minf(v["mhp"] - v["hp"], maxf(1.0, Js.round_js(v["mhp"] * pct / 100.0 * _sk_mul(u, "novice_firstaid"))))
	v["hp"] = v["hp"] + heal
	_sfx("heal")
	_float(u["x"], u["y"], "messages.novice_firstaid")
	_exp(u, "heal")
	_skill_done(u)


func _x_novice_tackle(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var r := _rng(sk, "tackleRange", 2.0)
	var tgt: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "enemy" and v["hp"] > 0 and float(_mh(u, v["x"], v["y"])) <= r)
	if tgt == null:
		_skill_refund(u, sk)
		return
	if _mh(u, tgt["x"], tgt["y"]) > 1:
		var adj: Variant = E.am.find_adj(tgt["x"], tgt["y"], u)
		if adj == null:
			_no_empty(u, sk)
			return
		E.fx_move_unit(u, adj["x"], adj["y"])
		u["mo"] = true
	tgt["hp"] = maxf(0.0, tgt["hp"] - _dmg_sub(u, 0.9, "novice_tackle", tgt))
	_sfx("atk", u)
	_sfx_kill(tgt)
	_float(u["x"], u["y"], "messages.novice_tackle")
	if tgt["hp"] <= 0:
		_rm_dead()
	_exp(u, "attack")
	_skill_done(u, {"chkEnd": true})


# ── 소환사 ──

func _summon(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var occupied := _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty) != null
	if occupied or not E.gu.passable(tx, ty):
		_skill_refund(u, sk)
		_float(u["x"], u["y"], "messages.summoner_no_spawn")
		return
	var spirit: bool = sk["id"] == "summoner_summon_spirit"
	var cls: String = sk["summonType"]
	var hp: float
	var atk: float
	var def: float
	var mv: float
	var rg: float
	var role: String
	if spirit:
		hp = Js.round_js(u["mhp"] * 0.5)
		atk = Js.round_js(u["atk"] * 0.5)
		def = 0.0
		mv = 3.0
		rg = 3.0
		role = "ranged"
	else:
		hp = Js.round_js(u["mhp"] * 1.2)
		atk = Js.round_js(u["atk"] * 0.5)
		def = Js.round_js(u["def"] * 1.2)
		mv = 2.0
		rg = 1.0
		role = "melee"
	var summon := {
		"id": int(S["nid"]), "uid": 0, "name": cls, "team": "ally", "cls": cls,
		"isSummon": true, "summonerId": u["id"],
		"x": tx, "y": ty, "hp": hp, "mhp": hp, "atk": atk, "def": def,
		"move": mv, "range": rg, "role": role,
		"res": 0.0, "maxRes": 0.0, "resType": "none", "resRec": 0.0,
		"summonTurns": 5.0,
		"actionPow": 0.0, "actionRec": 1.0,
		"gender": u["gender"] if Js.truthy(u.get("gender")) else "m",
		"hm": false, "ha": false, "waited": false, "mo": false,
		"furyBuff": 0.0, "defBuff": 0.0, "stunned": 0.0, "frozen": 0.0,
		"skillLv": {}, "buffs": [],
	}
	S["nid"] = int(S["nid"]) + 1
	(S["units"] as Array).append(summon)
	_sfx("heal")
	_float(tx, ty, "messages.sapper_summon", {"name": cls})   # 화면이 'classes.<cls>' 로 번역 (웹: t('classes.' + summonCls))
	_exp(u, "attack")
	_skill_done(u)


func _x_summoner_summon_spirit(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	_summon(u, tx, ty, sk)


func _x_summoner_summon_golem(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	_summon(u, tx, ty, sk)


func _my_summon_at(u: Dictionary, tx: int, ty: int) -> Variant:
	return _find(func(s: Dictionary) -> bool: return s["x"] == tx and s["y"] == ty and Js.truthy(s.get("isSummon")) and Js.same(s.get("summonerId"), u["id"]) and s["hp"] > 0)


func _x_summoner_empower(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var s: Variant = _my_summon_at(u, tx, ty)
	if s == null:
		_skill_refund(u, sk)
		return
	s["_empowerTurns"] = 3.0
	s["_empowerMul"] = 1.5
	_sfx("heal")
	_float(s["x"], s["y"], "messages.summoner_empower")
	_exp(u, "attack")
	_skill_done(u)


func _x_summoner_soulburst(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var s: Variant = _my_summon_at(u, tx, ty)
	if s == null:
		_skill_refund(u, sk)
		return
	var burst: float = s["atk"] * 3.0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var px: int = s["x"] + dx
			var py: int = s["y"] + dy
			if px < 0 or px >= COLS or py < 0 or py >= ROWS:
				continue
			var tgt: Variant = _enemy_at(px, py)
			if tgt != null:
				tgt["hp"] = maxf(0.0, tgt["hp"] - maxf(1.0, burst - tgt["def"]))
				_sfx_kill(tgt)
	_sfx("atk", u)
	_sfx("explosion")
	_float(s["x"], s["y"], "messages.summoner_soulburst")
	var left: Array = []
	for v: Dictionary in S["units"]:
		if v["id"] != s["id"]:
			left.append(v)
	S["units"] = left
	_exp(u, "attack")
	_skill_done(u, {"rmDead": true, "chkEnd": true})


# ── 주술사 ──

func _x_shaman_curse(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var tgt: Variant = _enemy_at_any(tx, ty)
	if tgt == null:
		_skill_refund(u, sk)
		return
	tgt["_cursed"] = true
	tgt["_curseAtk"] = u["atk"]
	tgt["_curseDmgCount"] = 0.0
	_sfx("atk", u)
	_float(tgt["x"], tgt["y"], "messages.shaman_curse")
	_float(u["x"], u["y"], "messages.shaman_curse")
	_exp(u, "attack")
	_skill_done(u)


func _enemy_at_any(tx: int, ty: int) -> Variant:
	return _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "enemy" and v["hp"] > 0)


func _x_shaman_exalt(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var tgt: Variant = _find(func(v: Dictionary) -> bool: return v["x"] == tx and v["y"] == ty and v["team"] == "ally" and v["hp"] > 0)
	if tgt == null:
		_skill_refund(u, sk)
		return
	(tgt["buffs"] as Array).append({"type": "atk_up", "duration": 999.0, "value": 10.0, "source": "shaman_exalt", "_attackCount": 2.0})
	_sfx("heal")
	_float(tgt["x"], tgt["y"], "messages.shaman_exalt")
	_float(u["x"], u["y"], "messages.shaman_exalt")
	_exp(u, "heal")
	_skill_done(u)


func _x_shaman_poisonmist(u: Dictionary, tx: int, ty: int, _sk: Dictionary) -> void:
	(S["poisonMists"] as Array).append({"cx": tx, "cy": ty, "atk": u["atk"], "turns": 3.0, "team": "ally"})
	_sfx("atk", u)
	_float(tx, ty, "messages.shaman_poisonmist")
	_exp(u, "attack")
	_skill_done(u)


func _x_shaman_spiritsurge(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var tgt: Variant = _enemy_at_any(tx, ty)
	if tgt == null:
		_skill_refund(u, sk)
		return
	tgt["hp"] = maxf(0.0, tgt["hp"] - _dmg_sub(u, 1.0, "shaman_spiritsurge", tgt))
	tgt["_rootedTurns"] = 1.0
	_sfx("atk", u)
	_sfx_kill(tgt)
	_float(tgt["x"], tgt["y"], "messages.rooted")
	_float(u["x"], u["y"], "messages.shaman_spiritsurge")
	_exp(u, "attack")
	_skill_done(u, {"rmDead": true, "chkEnd": true})


# ── 무투가 ──

func _x_brawler_disarm(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var tgt: Variant = _enemy_at_any(tx, ty)
	if tgt == null:
		_skill_refund(u, sk)
		return
	tgt["disarmed"] = 3.0
	_sfx("atk", u)
	_float(tgt["x"], tgt["y"], "messages.brawler_disarm")
	_float(tgt["x"], tgt["y"], "messages.atk_reduced")
	_exp(u, "attack")
	_skill_done(u)


func _x_brawler_flurry(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var tgt: Variant = _enemy_at_any(tx, ty)
	if tgt == null:
		_skill_refund(u, sk)
		return
	for i in 3:
		if tgt["hp"] <= 0:
			break
		tgt["hp"] = maxf(0.0, tgt["hp"] - _dmg_sub(u, 0.6, "brawler_flurry", tgt))
	_sfx("atk", u)
	_sfx_kill(tgt)
	_float(u["x"], u["y"], "messages.brawler_flurry")
	_exp(u, "attack")
	_skill_done(u, {"rmDead": true, "chkEnd": true})


func _x_brawler_crush(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var tgt: Variant = _enemy_at_any(tx, ty)
	if tgt == null:
		_skill_refund(u, sk)
		return
	var dmg := maxf(1.0, Js.round_js(u["atk"] * 1.0 * _sk_mul(u, "brawler_crush")))
	tgt["hp"] = maxf(0.0, tgt["hp"] - dmg)
	_sfx("atk", u)
	_sfx_kill(tgt)
	_float(u["x"], u["y"], "messages.brawler_crush")
	_exp(u, "attack")
	_skill_done(u, {"rmDead": true, "chkEnd": true})


# ── 창병 ──

func _x_lancer_pierce(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var plen := int(_rng(sk, "pierceLen", 3.0))
	var dx := Js.sign_js(tx - int(u["x"]))
	var dy := Js.sign_js(ty - int(u["y"]))
	if dx != 0 and dy != 0:
		_skill_refund(u, sk)
		return
	var hit: Array = []
	for i in range(1, plen + 1):
		var px: int = u["x"] + dx * i
		var py: int = u["y"] + dy * i
		if px < 0 or px >= COLS or py < 0 or py >= ROWS:
			break
		var tgt: Variant = _enemy_at(px, py)
		if tgt != null:
			hit.append(tgt)
		if not E.gu.passable(px, py):
			break
	if hit.is_empty():
		_skill_refund(u, sk)
		return
	for t: Dictionary in hit:
		t["hp"] = maxf(0.0, t["hp"] - _dmg_sub(u, 1.0, "lancer_pierce", t))
		_sfx_kill(t)
	_sfx("atk", u)
	_float(u["x"], u["y"], "messages.lancer_pierce")
	E.proc_fury(u, hit[0])
	_exp(u, "attack")
	_skill_done(u, {"rmDead": true, "chkEnd": true})


func _x_lancer_charge(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var tgt: Variant = _enemy_at_any(tx, ty)
	if tgt == null:
		_skill_refund(u, sk)
		return
	var adj: Variant = E.am.find_adj(tgt["x"], tgt["y"], u)
	if adj == null:
		_no_empty(u, sk)
		return
	u["x"] = adj["x"]
	u["y"] = adj["y"]
	u["mo"] = true
	E.fx("move", {"id": u["id"], "x": u["x"], "y": u["y"]})
	tgt["hp"] = maxf(0.0, tgt["hp"] - _dmg_sub(u, 1.2, "lancer_charge", tgt))
	_sfx("atk", u)
	_sfx_kill(tgt)
	_float(u["x"], u["y"], "messages.lancer_charge")
	E.proc_fury(u, tgt)
	_exp(u, "attack")
	_skill_done(u, {"rmDead": true, "chkEnd": true})


func _x_lancer_phalanx(u: Dictionary, _tx: int, _ty: int, sk: Dictionary) -> void:
	var r := _rng(sk, "phalanxRange", 2.0)
	var allies: Array = []
	for v: Dictionary in S["units"]:
		if v["team"] == "ally" and v["hp"] > 0 and float(_mh(u, v["x"], v["y"])) <= r:
			allies.append(v)
	if allies.is_empty():
		_skill_refund(u, sk)
		return
	for a: Dictionary in allies:
		a["_phalanxTurns"] = 2.0
		a["_phalanxDef"] = 5.0
	_sfx("heal")
	_float(u["x"], u["y"], "messages.lancer_phalanx")
	E.proc_fury(u, u)
	_exp(u, "attack")
	_skill_done(u)


# ── 공병 ──

func _x_sapper_trap(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	if not E.gu.passable(tx, ty) or E.gu.u_at(tx, ty) != null or _trap_at(tx, ty):
		_skill_refund(u, sk)
		return
	var trap_dmg := Js.round_js(u["atk"] * 2.0)
	var enh: bool = Js.num(u["skillLv"].get("sapper_enhancedtrap")) >= 1
	(S["traps"] as Array).append({"x": tx, "y": ty, "team": u["team"], "dmg": Js.round_js(trap_dmg * 1.3) if enh else trap_dmg, "stun": 3.0 if enh else 2.0})
	_sfx("uiclick")
	_float(tx, ty, "messages.trap_installed")
	_exp(u, "attack")
	_skill_done(u, {"rTer": true})


func _x_sapper_excavate(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	if E.gu.tile(tx, ty) != "rock":
		_skill_refund(u, sk)
		return
	S["ter"][ty][tx] = "plain"
	_sfx("atk", u)
	_float(tx, ty, "messages.sapper_excavate")
	_exp(u, "attack")
	_skill_done(u, {"rTer": true})


func _x_sapper_detonate(u: Dictionary, tx: int, ty: int, sk: Dictionary) -> void:
	var trap: Variant = null
	for tr: Dictionary in S["traps"]:
		if tr["x"] == tx and tr["y"] == ty and tr["team"] == "ally":
			trap = tr
			break
	if trap == null:
		_skill_refund(u, sk)
		return
	var burst := Js.round_js(float(trap["dmg"]) * 1.5)
	for d: Array in [[-1, -1], [0, -1], [1, -1], [-1, 0], [0, 0], [1, 0], [-1, 1], [0, 1], [1, 1]]:
		var px: int = int(trap["x"]) + d[0]
		var py: int = int(trap["y"]) + d[1]
		if px < 0 or px >= COLS or py < 0 or py >= ROWS:
			continue
		var tgt: Variant = _enemy_at(px, py)
		if tgt != null:
			tgt["hp"] = maxf(0.0, tgt["hp"] - maxf(1.0, burst - tgt["def"]))
			_sfx_kill(tgt)
	var left: Array = []
	for tr2: Dictionary in S["traps"]:
		if tr2 != trap:
			left.append(tr2)
	S["traps"] = left
	_sfx("atk", u)
	_sfx("explosion")
	_float(tx, ty, "messages.sapper_detonate")
	_exp(u, "attack")
	_skill_done(u, {"rmDead": true, "chkEnd": true})
