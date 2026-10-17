extends RefCounted
## 전투 엔진 — 웹 js/battle/{state,event,turn,boot(initBattle)}.js + 화면 모듈에 섞여 있던 규칙(README '화면 모듈에 섞인 규칙')
##
##  화면·노드와 무관한 순수 규칙. 시간은 가상 시계 위의 작업 대기열(later)로만 흐르고, 실제 시간·프레임에 기대지 않는다.
##  웹의 setTimeout/await sl() 자리는 later()(대기열) 또는 _sl()(적 차례 안의 대기 = 멈춤 지점)로 옮겼다 — 순서가 웹과 같다.
##
##  사용 (3단계 화면도 같은 입구):
##    var eng := BattleEngine.new(data_globals, seed)        # data_globals = Ctx.globals_from_db(DataDB)
##    eng.start({ "save": {...}, "stage": {"id": 5}, "practice": false, "inject": [] })   # 저장소 값으로 전투 준비
##    eng.input_provider = func(u): return null              # null = 플레이어 입력을 기다림 (status "input")
##    eng.begin()                                            # 첫 차례 (TurnManager.nextAction)
##    var st := eng.run()        # "input" | "stopped"(전투 끝·라운드 상한) | "idle"
##    eng.command({"op": "move", "x": 3, "y": 9})            # 입력 대기 중인 클랜원에게 명령 → 다시 eng.run()
##  신호: bus_event(name, data) = 웹 EventBus 알림 그대로(유닛은 Dictionary), fx_event(kind, data) = 연출 힌트(규칙 영향 없음)
##  기록: trace(배열) = 황금 기록과 같은 형식의 사건 목록 (tests/golden/README.md)

signal bus_event(name: String, data: Dictionary)
signal fx_event(kind: String, data: Dictionary)

const Js := preload("res://scripts/logic/js.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const Synergy := preload("res://scripts/logic/synergy.gd")
const Hazards := preload("res://scripts/logic/hazards.gd")
const StageRules := preload("res://scripts/logic/stage_rules.gd")
const JsonNorm := preload("res://scripts/core/json_norm.gd")
const Num := preload("res://scripts/core/num.gd")
const GridUnits := preload("res://scripts/logic/battle/grid_units.gd")
const Combat := preload("res://scripts/logic/battle/combat.gd")
const GearFxScript := preload("res://scripts/logic/battle/gear_fx.gd")
const Action := preload("res://scripts/logic/battle/battle_action.gd")
const AIScript := preload("res://scripts/logic/battle/battle_ai.gd")
const Skills := preload("res://scripts/logic/battle/battle_skills.gd")
const BattleEnd := preload("res://scripts/logic/battle/battle_end.gd")
const Query := preload("res://scripts/logic/battle/battle_query.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")

# ── FSM 상태 (state.js BattleState) ──
const LOADING := "LOADING"
const ADVANCING_TICK := "ADVANCING_TICK"
const PLAYER_IDLE := "PLAYER_IDLE"
const UNIT_SELECTED := "UNIT_SELECTED"
const MOVE_MODE := "MOVE_MODE"
const ATTACK_MODE := "ATTACK_MODE"
const HEAL_MODE := "HEAL_MODE"
const ATTACK_HEAL_MODE := "ATTACK_HEAL_MODE"
const SKILL_TARGET := "SKILL_TARGET"
const ITEM_TARGET := "ITEM_TARGET"
const AI_TURN := "AI_TURN"
const ANIMATING := "ANIMATING"
const WAVE_TRANSITION := "WAVE_TRANSITION"
const BATTLE_END := "BATTLE_END"
const PLAYER_STATES := [PLAYER_IDLE, UNIT_SELECTED, MOVE_MODE, ATTACK_MODE, HEAL_MODE, ATTACK_HEAL_MODE, SKILL_TARGET, ITEM_TARGET]

const SKIP_EV := ["state_changed", "camera_focus", "wave_announce_end"]
const ST_KEYS := ["stunned", "frozen", "disarmed", "furyBuff", "defBuff", "_defend", "_overwatch", "_cursed", "_curseDmgCount", "_rootedTurns",
	"_bleedTurns", "_bleedDmg", "_sanctuaryTurns", "_sanctuaryHeal", "_phalanxTurns", "_phalanxDef", "_empowerTurns", "_empowerMul", "summonTurns",
	"_tenacityUsed", "_tenacityDef", "_sacrificeKnight", "_sacrificeDmgCount", "stealthBroken", "channeling", "_barrier", "_spearwallUsed",
	"_lastStandUsed", "_firstHit", "_focus", "_comboTgt", "_comboN", "_oath", "_movedDist"]

var c: Ctx
var D: Dictionary
## GameStore (웹과 같은 키 이름). units 의 각 유닛은 Dictionary
var S: Dictionary = {}
var fsm: String = LOADING

var gu: GridUnits
var cb: Combat
var gearfx: GearFxScript
var am: Action
var ai: AIScript
var sk: Skills
var be: BattleEnd
## 3단계 화면용 순수 조회 (피해 미리보기·이동/공격/스킬 칸·행동 목록·방향 추천·위협 범위) — battle_query.gd
var q: Query

## 그랜드 월 (웹 G.magicWalls — GameStore 가 아닌 G 프록시에 저장되는 값)
var magic_walls: Array = []

# ── 진행 ──
## 라운드 상한 (0 = 없음). 시뮬레이터·재생은 120 (넘으면 'stalled')
var max_rounds: int = 0
var ended: bool = false
var end_info: Dictionary = {}
var rewards: Variant = null
var turn_ends: int = 0
var _aborted: bool = false
var _q: Array = []        # [시각, 순번, Callable]
var _seq: int = 0

# ── 입력 (클랜원 차례) ──
## Callable(u: Dictionary) -> Variant(명령 Dictionary 또는 null). null 이면 command() 를 기다림
var input_provider: Callable
var _busy: bool = false
var _last_act: int = -1
var _await: Dictionary = {}

# ── 기록 ──
var trace: Array = []
var record_enabled: bool = true
var _known: Dictionary = {}      # id → 유닛 (지금 S.units 에 있는 것, 삽입 순서)
var _drawn: Dictionary = {}      # Renderer.rUnits 로 이미 그린 유닛 id
var _init_ter: Array = []
var _end_hp: Variant = null      # endUnitTurn 시작 때 {id, hp, rng} (env_dmg 기록용)
## 순수 조회 깊이 (> 0 이면 난수 고정·미사용, 기록·신호 없음 — battle_query.gd)
var _pure: int = 0
var _skill_before: Variant = null


func _init(data_globals: Dictionary, seed: int) -> void:
	c = Ctx.new(data_globals, seed)
	D = data_globals
	_reset_store()
	gu = GridUnits.new(self)
	cb = Combat.new(self)
	gearfx = GearFxScript.new(self)
	am = Action.new(self)
	ai = AIScript.new(self)
	sk = Skills.new(self)
	be = BattleEnd.new(self)
	q = Query.new(self)


## 순수 조회 구간 (battle_query.gd 가 씀): 난수는 상태를 바꾸지 않고 0.999, 기록·신호 없음
func pure_begin() -> void:
	_pure += 1
	c.rng.frozen += 1


func pure_end() -> void:
	_pure -= 1
	c.rng.frozen -= 1


## 순환 참조 끊기 (엔진을 버릴 때)
func dispose() -> void:
	gu = null
	cb = null
	gearfx = null
	am = null
	ai = null
	sk = null
	be = null
	q = null
	_q.clear()
	input_provider = Callable()


func _reset_store() -> void:
	S.clear()
	S.merge({
		"ter": [], "units": [], "nid": 1, "turn": 1, "_turnActed": {}, "sel": null, "curUnit": null, "actCount": 0,
		"mvT": [], "atkT": [], "healT": [], "coverT": [], "blockT": [],
		"cStage": null, "eSpwn": 0, "eQ": [], "cleared": [], "gold": 0.0, "party": [],
		"battleExp": {}, "allyPos": {}, "traps": [], "poisonMists": [],
		"_killCount": 0, "_killExpPool": 0.0, "_deadAllyUids": [], "_commanderFallen": false,
		"preMv": null, "_curSkill": null, "breached": 0, "gateHP": {}, "wallHP": {}, "practiceMode": false,
		"_battlePotions": [], "_battlePotionIndices": [], "_siegeItems": [], "_siegeInvIndices": [],
		"_synergies": [], "_hazard": null, "safeZones": [], "chests": [],
	})


# ═══════════ 공용 도우미 ═══════════

func num_str(v: float) -> String:
	return Num.fmt(v)


func fsm_is(states: Variant) -> bool:
	if typeof(states) == TYPE_ARRAY:
		return (states as Array).has(fsm)
	return fsm == states


func transition(st: String) -> void:
	if fsm == st:
		return
	fsm = st


func is_player_turn() -> bool:
	return PLAYER_STATES.has(fsm)


func accepts_cell_click() -> bool:
	return PLAYER_STATES.has(fsm)


func buff_has(u: Dictionary, type: String) -> bool:
	return cb.buff_has(u, type)


func buff_apply(u: Dictionary, def: Dictionary) -> Dictionary:
	return cb.buff_apply(u, def)


func buff_remove(u: Dictionary, type: String, source: String = "") -> Variant:
	return cb.buff_remove(u, type, source)


func is_stealthed(u: Dictionary) -> bool:
	return cb.is_stealthed(u)


func calc_dmg(a: Dictionary, t: Dictionary) -> float:
	return cb.calc_dmg(a, t)


func apply_dmg_to_ally(t: Dictionary, dmg: float) -> Dictionary:
	return cb.apply_dmg_to_ally(t, dmg)


func proc_fury(a: Dictionary, t: Dictionary) -> void:
	cb.proc_fury(a, t)


func unit_by_id(id: Variant) -> Variant:
	for u: Dictionary in S["units"]:
		if Js.same(u["id"], id):
			return u
	return null


## battle/constants.js killExp / actExp
func kill_exp(stage_id: float, cls: String) -> float:
	var K: Array = D["KILL_EXP"]
	var base: float = float(K[0]) + stage_id * float(K[1])
	var bonus := {"knight": 1.3, "mage": 1.2, "summoner": 1.2, "shaman": 1.2, "assassin": 1.1, "priest": 1.1, "brawler": 1.1, "lancer": 1.1, "sapper": 1.1, "novice": 1.0, "warrior": 1.0, "archer": 1.0}
	return floorf(base * float(bonus.get(cls, 1.0)))


func act_exp(stage_id: float, action: String) -> float:
	var base := {"move": 2.0, "attack": 5.0, "heal": 6.0}
	return floorf(float(base.get(action, 0.0)) * (1.0 + stage_id * 0.1))


## skills.js getSkills / getUnitSkills (기본 + 습득형, LEARNABLE_SKILLS 선언 순서)
func get_skills(cls: String) -> Array:
	var s: Variant = (D["SKILLS"] as Dictionary).get(cls)
	if s == null:
		return []
	if typeof(s) == TYPE_ARRAY:
		return s
	return [s]


func get_unit_skills(u: Dictionary) -> Array:
	var out: Array = get_skills(u["cls"]).duplicate()
	var LS: Dictionary = D["LEARNABLE_SKILLS"]
	for id: String in LS.keys():
		var l: Dictionary = LS[id]
		if l["cls"] == u["cls"] and Js.num(u["skillLv"].get(id)) >= 1:
			out.append(l)
	return out


# ═══════════ 작업 대기열 (웹 setTimeout 의 가상 시계) ═══════════

func later(ms: float, fn: Callable) -> void:
	_seq += 1
	_q.append([c.now_ms + maxf(0.0, ms), _seq, fn])


func _stop_cond() -> bool:
	return ended or (max_rounds > 0 and int(S["turn"]) > max_rounds)


## 적 차례 안의 대기(await sl) 자리 — 웹에서는 여기서 다른 작업으로 넘어가며, 전투가 끝났으면 이어지지 않는다.
## true 면 멈춤 (호출한 쪽은 바로 돌아가야 함)
func _sl(_ms: float = 0.0) -> bool:
	if _stop_cond():
		_aborted = true
		return true
	return false


func run(max_steps: int = 400000) -> String:
	var steps := 0
	while true:
		if _stop_cond():
			return "stopped"
		if _q.is_empty():
			return "input" if not _await.is_empty() else "idle"
		var bi := 0
		for i in range(1, _q.size()):
			var a: Array = _q[i]
			var b: Array = _q[bi]
			if a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]):
				bi = i
		var e: Array = _q[bi]
		_q.remove_at(bi)
		c.now_ms = e[0]
		(e[2] as Callable).call()
		steps += 1
		if steps > max_steps:
			return "max_steps"
	return "idle"


func pending() -> int:
	return _q.size()


# ═══════════ 기록 (황금 기록 형식) ═══════════

func _is_unit(v: Variant) -> bool:
	return typeof(v) == TYPE_DICTIONARY and (typeof(v.get("id")) == TYPE_INT or typeof(v.get("id")) == TYPE_FLOAT) and typeof(v.get("team")) == TYPE_STRING


static func clean_buff(b: Dictionary) -> Dictionary:
	var o := {"type": b.get("type"), "source": b["source"] if Js.truthy(b.get("source")) else ""}
	if b.has("duration"):   # JSON.stringify 는 undefined 를 뺌 (옛 필드 출혈·성역 틱의 가짜 버프)
		o["duration"] = b["duration"]
	o["value"] = b["value"] if Js.truthy(b.get("value")) else 0.0
	o["stacks"] = b["stacks"] if Js.truthy(b.get("stacks")) else 1.0
	o["meta"] = Js.deep(b["meta"]) if Js.truthy(b.get("meta")) else {}
	if b.has("_attackCount"):
		o["attackCount"] = b["_attackCount"]
	return o


func _ser_val(k: String, v: Variant) -> Variant:
	if _is_unit(v):
		return v["id"]
	if k == "buff" and typeof(v) == TYPE_DICTIONARY:
		return clean_buff(v)
	if k == "skill":
		return v["id"] if typeof(v) == TYPE_DICTIONARY else v
	if k == "trap" and typeof(v) == TYPE_DICTIONARY:
		return [v["x"], v["y"], v["team"], v["dmg"], v["stun"]]
	return Js.deep(v)


## 유닛 전체 정보 (키 이름순, name·gender 제외, 버프 id·공성 아이템 id 제외)
func unit_full(u: Dictionary) -> Dictionary:
	var o: Dictionary = {}
	var keys: Array = u.keys()
	keys.sort()
	for k: String in keys:
		if k == "name" or k == "gender":
			continue
		var v: Variant = u[k]
		if k == "buffs":
			var bl: Array = []
			for b: Dictionary in v:
				bl.append(clean_buff(b))
			o["buffs"] = bl
		elif k == "siegeItems":
			var sl: Array = []
			for s: Dictionary in v:
				sl.append({"type": s["type"], "cooldown": s["cooldown"]})
			o["siegeItems"] = sl
		else:
			o[k] = _json_val(v)
	return o


func _json_val(v: Variant) -> Variant:
	if _is_unit(v):
		return unit_full(v)   # (유닛 안에 유닛 참조는 없음 — 안전장치)
	return Js.deep(v)


func unit_snap(u: Dictionary) -> Dictionary:
	var st: Dictionary = {}
	for k: String in ST_KEYS:
		var v: Variant = u.get(k)
		if v == null:
			continue
		if typeof(v) == TYPE_BOOL and not v:
			continue
		if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and float(v) == 0.0:
			continue
		st[k] = v
	var o := {"id": u["id"], "team": u["team"], "cls": u["cls"], "x": u["x"], "y": u["y"], "hp": u["hp"], "mhp": u["mhp"], "atk": u["atk"],
		"def": u["def"], "move": u["move"], "range": u["range"], "res": u["res"], "ap": u["actionPow"],
		"face": [u.get("_gdx"), u.get("_gdy")]}
	if not st.is_empty():
		o["st"] = st
	if typeof(u.get("buffs")) == TYPE_ARRAY and not (u["buffs"] as Array).is_empty():
		var bl: Array = []
		for b: Dictionary in u["buffs"]:
			bl.append([b.get("type"), b["source"] if Js.truthy(b.get("source")) else "", b.get("duration"), b["value"] if Js.truthy(b.get("value")) else 0.0])
		o["buffs"] = bl
	if u.has("siegeItems"):
		var sl: Array = []
		for s: Dictionary in u["siegeItems"]:
			sl.append(str(s["type"]) + ":" + num_str(float(s["cooldown"])))
		o["siege"] = sl
	return o


func _sync_units() -> void:
	if not record_enabled or _pure > 0:
		return
	var now_ids: Dictionary = {}
	for u: Dictionary in S["units"]:
		now_ids[u["id"]] = u
	for id: Variant in _known.keys():
		if not now_ids.has(id):
			_known.erase(id)
			_push("gone", {"u": id})
	for u2: Dictionary in S["units"]:
		if not _known.has(u2["id"]):
			_known[u2["id"]] = u2
			_push("spawn", {"unit": unit_full(u2)})


func _push(ev: String, data: Dictionary) -> Dictionary:
	var e := {"ev": ev, "rng": c.rng.calls}
	e.merge(data)
	trace.append(e)
	return e


## 사건 기록 (유닛 등장·퇴장 먼저)
func rec(ev: String, data: Dictionary) -> Dictionary:
	if not record_enabled or _pure > 0:
		return {}
	_sync_units()
	return _push(ev, data)


## 감싼 함수의 결과 사건: rng = 시작 때, rngEnd = 지금
func rec_r(ev: String, rng0: int, data: Dictionary) -> void:
	if not record_enabled or _pure > 0:
		return
	_sync_units()
	var e := {"ev": ev, "rng": rng0, "rngEnd": c.rng.calls}
	e.merge(data)
	trace.append(e)


func snap_g() -> Dictionary:
	var ter_diff: Array = []
	if not _init_ter.is_empty():
		for y in int(D["ROWS"]):
			for x in int(D["COLS"]):
				if S["ter"][y][x] != _init_ter[y][x]:
					ter_diff.append([x, y, S["ter"][y][x]])
	var traps: Array = []
	for t: Dictionary in S["traps"]:
		traps.append([t["x"], t["y"], t["team"], t["dmg"], t["stun"]])
	var mists: Array = []
	for m: Dictionary in S["poisonMists"]:
		mists.append([m["cx"], m["cy"], m["atk"], m["turns"], m["team"]])
	var chests: Array = []
	for ch: Dictionary in S["chests"]:
		chests.append([ch["x"], ch["y"]])
	var walls: Array = []
	for w: Dictionary in magic_walls:
		walls.append([w["x"], w["y"]])
	var acted: Array = []
	for k: Variant in S["_turnActed"].keys():
		acted.append(k)
	acted.sort()   # JS Object.keys: 정수 키는 오름차순
	var exp: Dictionary = {}
	for k2: Variant in S["battleExp"].keys():
		exp[str(k2)] = S["battleExp"][k2]
	var pots: Array = []
	for p: Dictionary in S["_battlePotions"]:
		pots.append(p["potionId"])
	var sie: Array = []
	for s: Dictionary in S["_siegeItems"]:
		sie.append(s["siegeId"])
	return {"turn": S["turn"], "act": S["actCount"], "eSpwn": S["eSpwn"], "eQ": (S["eQ"] as Array).duplicate(), "breached": S["breached"],
		"gate": Js.deep(S["gateHP"]), "traps": traps, "mists": mists, "chests": chests, "safe": (S["safeZones"] as Array).duplicate(),
		"ter": ter_diff, "walls": walls, "wallHP": Js.deep(S["wallHP"]), "acted": acted, "exp": exp, "potions": pots, "siege": sie}


func snapshot(why: String) -> void:
	if not record_enabled or _pure > 0:
		return
	_sync_units()
	var us: Array = []
	for u: Dictionary in S["units"]:
		us.append(unit_snap(u))
	_push("snap", {"why": why, "g": snap_g(), "units": us})


# ═══════════ EventBus (구독 순서: GearFX → 화면 규칙(VFX) → 결과(Renderer)) ═══════════

func emit(name: String, data: Dictionary = {}) -> void:
	if _pure > 0:
		push_error("battle_engine: 순수 조회 중 알림 %s (조회 함수가 상태를 바꿈)" % name)
		return
	if record_enabled and not SKIP_EV.has(name):
		var o: Dictionary = {}
		for k: String in data.keys():
			if k == "message":
				continue
			o[k] = _ser_val(k, data[k])
		if name == "turn_start":
			o["r"] = S["turn"]
			o["ap"] = data["unit"]["actionPow"]
			if data["unit"]["team"] == "enemy":
				o["intent"] = data["unit"].get("_intent")
		rec(name, o)
	match name:
		"unit_killed":
			gearfx.on_unit_killed(data)
		"turn_end":
			gearfx.on_turn_end(data)
		"unit_moved":
			gearfx.on_unit_moved(data)
			_vfx_on_unit_moved(data)
		"skill_used":
			gearfx.on_skill_used(data)
		"unit_healed":
			gearfx.on_unit_healed(data)
		"buff_applied":
			gearfx.on_buff_applied(data)
		"unit_attacked":
			_vfx_on_unit_attacked(data)
		"battle_end":
			_on_battle_end_listener(data)
	if bus_event.get_connections().size() > 0:
		bus_event.emit(name, _event_view(data))
	match name:
		"turn_end":
			snapshot("turn_end")
		"wave_spawn":
			plan_rule()
		"round_end":
			snapshot("round_end")
		"battle_end":
			var msg := str(data.get("message", ""))
			end_info = {"result": "win" if data["win"] else "lose", "reason": msg.trim_prefix("messages.")}
			ended = true


## bus_event 로 넘길 사본: 유닛은 그 순간의 값만 담은 새 사전(unit_view) — 화면이 연출을 쌓아 두었다가 나중에 재생해도 그 시점 값
func _event_view(data: Dictionary) -> Dictionary:
	var o: Dictionary = {}
	for k: String in data.keys():
		var v: Variant = data[k]
		if _is_unit(v):
			o[k] = unit_view(v)
		elif typeof(v) == TYPE_DICTIONARY or typeof(v) == TYPE_ARRAY:
			o[k] = Js.deep(v)
		else:
			o[k] = v
	return o


## 화면용 유닛 요약 (사본 — 원본과 연결 없음)
func unit_view(u: Dictionary) -> Dictionary:
	var buffs: Array = []
	for b: Dictionary in u.get("buffs", []):
		buffs.append({"type": b.get("type"), "duration": b.get("duration"), "value": b.get("value", 0.0), "source": b.get("source", "")})
	return {"id": u["id"], "uid": u.get("uid", 0), "team": u["team"], "cls": u["cls"], "x": u["x"], "y": u["y"],
		"hp": u["hp"], "mhp": u["mhp"], "atk": u["atk"], "def": u["def"], "res": u["res"], "maxRes": u["maxRes"], "resType": u.get("resType"),
		"move": u["move"], "range": u["range"], "ap": u["actionPow"], "face": [u.get("_gdx"), u.get("_gdy")],
		"isBoss": Js.truthy(u.get("isBoss")), "isSummon": Js.truthy(u.get("isSummon")), "stealthed": is_stealthed(u),
		"defend": Js.truthy(u.get("_defend")), "overwatch": Js.truthy(u.get("_overwatch")), "intent": u.get("_intent"), "buffs": buffs}


# ═══════════ 화면 모듈에 섞인 규칙 (tests/golden/README.md '화면 모듈에 섞인 규칙' 1~8) ═══════════

## 연출 힌트 (규칙과 무관 — 3단계 화면이 받음)
func fx(kind: String, data: Dictionary = {}) -> void:
	if _pure > 0:
		return
	fx_event.emit(kind, data)


## Fx.float — 'messages.*' 글자는 규칙 결과를 알려 주므로 기록 (선택 안내 messages.select_* 제외)
func fx_float(x: int, y: int, text: String) -> void:
	if _pure > 0:
		return
	if text.begins_with("messages.") and not text.begins_with("messages.select_"):
		rec("float", {"x": x, "y": y, "key": text.substr(9)})
	fx("float", {"x": x, "y": y, "text": text})


## 2) VFX.faceDir — dx,dy 가 둘 다 0 이면 그대로 (정규화하지 않음)
func fx_face_dir(id: Variant, dx: int, dy: int) -> void:
	if dx == 0 and dy == 0:
		return
	var u: Variant = unit_by_id(id)
	if u != null:
		u["_gdx"] = dx
		u["_gdy"] = dy
	fx("face", {"id": id, "dx": dx, "dy": dy})


## 1) VFX._mvU — 좌표 이동 + allyPos + 'unit_moved'
func fx_move_unit(u: Dictionary, tx: int, ty: int) -> void:
	var from := {"x": u["x"], "y": u["y"]}
	u["x"] = tx
	u["y"] = ty
	if u["team"] == "ally":
		S["allyPos"][u["id"]] = {"x": tx, "y": ty}
	fx("move", {"id": u["id"], "x": tx, "y": ty})
	emit("unit_moved", {"unit": u, "from": from, "to": {"x": tx, "y": ty}})


## 3) Fx.attack → VFX.vfxAtk 첫 줄: 공격자가 대상을 바라봄
func fx_attack(a: Dictionary, t: Dictionary) -> void:
	fx_face_dir(a["id"], t["x"] - a["x"], t["y"] - a["y"])
	fx("attack", {"a": a["id"], "t": t["id"]})


## 6)·8) Renderer.rUnits — 처음 그려지는 유닛의 초기 방향(적 (0,1)/아군 (0,-1)) + allyPos, 쓰러진 클랜원 allyPos (99,99)
func fx_redraw_units() -> void:
	for u: Dictionary in S["units"]:
		if u["hp"] <= 0 or _drawn.has(u["id"]):
			continue
		_drawn[u["id"]] = true
		if u["team"] == "ally":
			S["allyPos"][u["id"]] = {"x": u["x"], "y": u["y"]}
		if not u.has("_gdx") and not u.has("_gdy"):
			u["_gdx"] = 0
			u["_gdy"] = 1 if u["team"] == "enemy" else -1
	for u2: Dictionary in S["units"]:
		if u2["team"] == "ally" and u2["hp"] <= 0:
			S["allyPos"][u2["id"]] = {"x": 99, "y": 99}
	fx("redraw_units")


## 4) 'unit_attacked' 구독: 스플래시가 아니면 공격자가 대상을 바라봄, _lastTactic = null
func _vfx_on_unit_attacked(d: Dictionary) -> void:
	var a: Dictionary = d["attacker"]
	var t: Dictionary = d["target"]
	if not Js.truthy(d.get("isSplash")):
		fx_face_dir(a["id"], t["x"] - a["x"], t["y"] - a["y"])
	a["_lastTactic"] = null


## 5) 'unit_moved' 구독: 이동 방향을 바라봄 + 클랜원(소환수 제외)이 상자 칸이면 Chest.open (난수) → 행동 예고 ④
func _vfx_on_unit_moved(d: Dictionary) -> void:
	var u: Dictionary = d["unit"]
	fx_face_dir(u["id"], int(d["to"]["x"]) - int(d["from"]["x"]), int(d["to"]["y"]) - int(d["from"]["y"]))
	if u["team"] != "ally" or Js.truthy(u.get("isSummon")):
		return
	var ch: Variant = cb.chest_at(d["to"]["x"], d["to"]["y"])
	if ch == null:
		return
	var r := cb.chest_open(ch, u)
	rec("chest_open", {"u": u["id"], "x": ch["x"], "y": ch["y"], "kind": r["kind"]})
	fx("chest_open", {"u": u["id"], "x": ch["x"], "y": ch["y"], "kind": r["kind"]})
	plan_rule()
	var log: Array = (S.get("_chestLog", []) as Array).duplicate()
	log.append(r["kind"])
	S["_chestLog"] = log


## 7) 'battle_end' 구독 → 보상 계산(BattleEnd.onBattleEnd) + 결과 화면의 첫 getChar(로스터 보정 난수)
func _on_battle_end_listener(d: Dictionary) -> void:
	be.on_battle_end(d["win"])
	var er: Variant = S.get("_expResults")
	if typeof(er) == TYPE_ARRAY and not (er as Array).is_empty():
		Profile.get_char(c, er[0]["uid"])
	rewards = be.rewards_summary(d["win"])


## 행동 예고 규칙: 정해진 시점에 AI.planIntents() 를 동기로 1회 (AI_TURN·BATTLE_END 면 건너뜀)
func plan_rule() -> void:
	if fsm == AI_TURN or fsm == BATTLE_END:
		return
	ai.plan_intents()


# ═══════════ 전투 준비 (BattleInit.initBattle) ═══════════

## cfg: { save: {키: 값}, stage: {id} | {daily:{cls,tier}}, practice, inject: [...], maxRounds }
## 반환: 준비 결과 (황금 기록 setup 과 같은 형식)
func start(cfg: Dictionary) -> Dictionary:
	c.store.load_from(cfg.get("save", {}))
	max_rounds = int(cfg.get("maxRounds", 0))
	var gd := Profile.load_gold_data(c)
	S["gold"] = gd["gold"]
	S["cleared"] = gd["cleared"]
	var st_spec: Dictionary = cfg["stage"]
	var stage: Variant
	if Js.truthy(st_spec.get("daily")):
		stage = StageRules.daily_build_stage(D, st_spec["daily"]["cls"], int(st_spec["daily"]["tier"]))
	else:
		stage = StageRules.find_stage(D, int(st_spec["id"]))
	if typeof(st_spec.get("override")) == TYPE_DICTIONARY:
		stage.merge(st_spec["override"], true)
	var party: Array = []
	var parties: Variant = c.store.get_json("game_parties")
	if typeof(parties) == TYPE_DICTIONARY:
		for p: Dictionary in parties["parties"]:
			if Js.same(p["id"], parties["activePartyId"]):
				for s: Variant in p["slots"]:
					if s != null:
						party.append(int(s))
	if typeof(cfg.get("party")) == TYPE_ARRAY:
		party = []
		for s2: Variant in cfg["party"]:
			party.append(int(s2))
	init_battle(stage, bool(cfg.get("practice", false)), party)
	_init_ter = []
	for row: Array in S["ter"]:
		_init_ter.append(row.duplicate())
	var init_events: Array = trace.duplicate()
	trace.clear()
	var inject_rec: Array = []
	var foes: Array = []
	for j: Dictionary in cfg.get("inject", []):
		if j.has("store"):
			for k: String in j["store"].keys():
				S[k] = JsonNorm.normalize(Js.deep(j["store"][k]))
			inject_rec.append({"store": j["store"]})
			continue
		var u: Variant = unit_by_id(int(j["unit"]))
		if u != null:
			var setv: Dictionary = JsonNorm.normalize(Js.deep(j["set"]))
			for k2: String in setv.keys():
				u[k2] = setv[k2]
			inject_rec.append({"unit": u["id"], "set": j["set"]})
	var units_full: Array = []
	for u2: Dictionary in S["units"]:
		units_full.append(unit_full(u2))
	var syn: Array = []
	for s3: Dictionary in S["_synergies"]:
		syn.append({"id": s3["id"], "eff": Js.deep(s3["eff"]), "to": s3.get("to"), "resonance": Js.truthy(s3.get("resonance"))})
	var chests: Array = []
	for ch: Dictionary in S["chests"]:
		chests.append([ch["x"], ch["y"]])
	var pots: Array = []
	for p2: Dictionary in S["_battlePotions"]:
		pots.append(p2["potionId"])
	var sie: Array = []
	for s4: Dictionary in S["_siegeItems"]:
		sie.append(s4["siegeId"])
	var stage_rec: Dictionary = Js.deep(S["cStage"])
	for k3: String in ["difficulty", "recommendedLevel", "enemyComposition", "recommendedClasses", "strategyTips", "story", "name"]:
		stage_rec.erase(k3)
	var ter: Array = []
	for row2: Array in S["ter"]:
		ter.append(row2.duplicate())
	return {
		"stage": stage_rec, "practice": S["practiceMode"], "inject": inject_rec,
		"ter": ter, "gateHP": Js.deep(S["gateHP"]), "wallHP": Js.deep(S["wallHP"]),
		"eQ": (S["eQ"] as Array).duplicate(), "safe": (S["safeZones"] as Array).duplicate(), "chests": chests,
		"synergies": syn, "hazard": S["_hazard"]["id"] if S["_hazard"] != null else null,
		"potions": pots, "siege": sie, "rngAfterInit": c.rng.calls, "initEvents": init_events, "units": units_full,
	}


## 첫 차례: 행동 예고 ①(전투 시작) → TurnManager.nextAction
func begin() -> void:
	plan_rule()
	next_action()


func init_battle(stage: Variant, practice: bool, party: Array) -> void:
	S["cStage"] = stage
	S["practiceMode"] = practice
	S["party"] = party
	fsm = LOADING
	if stage != null and Js.truthy(stage.get("en")):
		S["eQ"] = (stage["en"] as Array).duplicate()
		shuffle(S["eQ"], "shuffle(eQ)")
	gu.gen_t()
	var inv := Profile.load_inventory(c)
	for i in inv.size():
		var it: Variant = inv[i]
		if typeof(it) != TYPE_DICTIONARY:
			continue
		if it.get("type") == "battle_potion":
			(S["_battlePotions"] as Array).append(it)
			(S["_battlePotionIndices"] as Array).append(i)
		elif it.get("type") == "siege":
			(S["_siegeItems"] as Array).append(it)
			(S["_siegeInvIndices"] as Array).append(i)
	# 파티 배치 (가운데부터 바깥으로; 근접 11행, 원거리·치유 12행). 지휘관은 전투 불참
	var cols: Array = D["FORM_COLS"]
	var melee_idx := 0
	var ranged_idx := 0
	for uid: int in party:
		var ch: Variant = Profile.get_char(c, uid)
		if ch == null or ch["cls"] == D["COMMANDER_CLS"]:
			continue
		var role: Variant = D["ROLE_MAP"].get(ch["cls"])
		var is_ranged: bool = role == "ranged" or role == "healer"
		var idx: int
		if is_ranged:
			idx = ranged_idx
			ranged_idx += 1
		else:
			idx = melee_idx
			melee_idx += 1
		if idx < cols.size():
			gu.add_unit("ally", uid, int(cols[idx]), 12 if is_ranged else 11)
	var classes: Array = []
	for u: Dictionary in S["units"]:
		if u["team"] == "ally":
			classes.append(u["cls"])
	S["_synergies"] = Synergy.compute(D, classes)
	gearfx.resonance()
	Synergy.apply(D, S["units"], S["_synergies"])
	S["_hazard"] = Hazards.apply(D, S["units"], S["cStage"])
	place_safe()
	gearfx.init_battle()
	cb.chest_place()
	spawn_wave()
	fx_redraw_units()


## Hazard.placeSafe + 기록 safe_zones
func place_safe() -> void:
	var r0 := c.rng.calls
	Hazards.place_safe(c, S, S["_hazard"])
	if not (S["safeZones"] as Array).is_empty():
		rec_r("safe_zones", r0, {"cells": (S["safeZones"] as Array).duplicate()})


## constants.js shuffle — 끝에서부터 Fisher–Yates
func shuffle(a: Array, tag: String = "shuffle") -> void:
	var i := a.size() - 1
	while i > 0:
		var j := int(floorf(c.rand(tag) * (i + 1)))
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
		i -= 1


# ═══════════ TurnManager (turn.js) ═══════════

func advance_tick() -> Variant:
	var alive: Array = []
	for u: Dictionary in S["units"]:
		if u["hp"] > 0:
			alive.append(u)
	for u2: Dictionary in alive:
		if not Js.truthy(u2.get("actionRec")):
			u2["actionRec"] = 1.0
	for u3: Dictionary in alive:
		if float(u3["actionPow"]) >= 4.999:
			return get_next_unit()
	var min_delta := INF
	for u4: Dictionary in alive:
		min_delta = minf(min_delta, (5.0 - float(u4["actionPow"])) / float(u4["actionRec"]))
	for u5: Dictionary in alive:
		u5["actionPow"] = Js.round_js((float(u5["actionPow"]) + float(u5["actionRec"]) * min_delta) * 1000.0) / 1000.0
	return get_next_unit()


## 행동력 높은 순 → 회복 속도 높은 순 → S.units 순서 (안정 정렬 첫째)
func get_next_unit() -> Variant:
	var best: Variant = null
	for u: Dictionary in S["units"]:
		if u["hp"] > 0 and float(u["actionPow"]) >= 4.999:
			if best == null or float(u["actionPow"]) > float(best["actionPow"]) \
					or (float(u["actionPow"]) == float(best["actionPow"]) and float(u["actionRec"]) > float(best["actionRec"])):
				best = u
	return best


## TurnManager.endUnitTurn — 차례 끝 처리 순서는 웹과 같음 (README '차례 끝 처리 순서')
func end_unit_turn(u: Dictionary) -> void:
	turn_ends += 1
	_end_hp = {"id": u["id"], "hp": u["hp"], "rng": c.rng.calls}
	u["actionPow"] = maxf(0.0, Js.num(u.get("actionPow")) - 5.0)
	u["ha"] = false
	u["hm"] = false
	u["mo"] = false
	if u["resType"] == "mana":
		u["res"] = minf(u["maxRes"], u["res"] + u["resRec"])
	elif u["resType"] == "energy":
		var rec_v: float = u["resRec"]
		if u["cls"] == "assassin" and gu.tile(u["x"], u["y"]) == "forest":
			rec_v *= 2.0
		u["res"] = minf(u["maxRes"], u["res"] + rec_v)
	if u["hp"] > 1 and gu.near_lava(u["x"], u["y"]):
		var burn := minf(u["hp"] - 1.0, maxf(1.0, Js.round_js(u["mhp"] * float(D["TACTIC"]["lavaBurn"]))))
		u["hp"] = u["hp"] - burn
		fx("float", {"x": u["x"], "y": u["y"], "text": "🔥 -" + num_str(burn)})
		fx_redraw_units()
	var hz: Variant = S["_hazard"]
	if u["team"] == "ally" and Js.truthy(u.get("_hazardDot")) and u["hp"] > 1 and hz != null and not Hazards.in_safe(S, u):
		var dmg := minf(u["hp"] - 1.0, maxf(1.0, Js.round_js(u["mhp"] * Hazards.dot_pct(hz, S["cStage"]) * gearfx.hazard_mul(u))))
		u["hp"] = u["hp"] - dmg
		fx("float", {"x": u["x"], "y": u["y"], "text": str(hz["icon"]) + " -" + num_str(dmg)})
		fx_redraw_units()
	# BuffSystem.tick (기록: 그 전까지 줄어든 HP = env_dmg)
	if _end_hp != null and Js.same(_end_hp["id"], u["id"]) and u["hp"] < float(_end_hp["hp"]):
		rec_r("env_dmg", _end_hp["rng"], {"u": u["id"], "dmg": float(_end_hp["hp"]) - u["hp"], "lava": gu.near_lava(u["x"], u["y"]), "safe": Hazards.in_safe(S, u)})
	_end_hp = null
	cb.buff_tick(u)
	if Js.num(u.get("stunned")) > 0:
		u["stunned"] = float(u["stunned"]) - 1.0
	if Js.num(u.get("frozen")) > 0:
		u["frozen"] = float(u["frozen"]) - 1.0
	if Js.num(u.get("disarmed")) > 0:
		u["disarmed"] = float(u["disarmed"]) - 1.0
	if Js.num(u.get("furyBuff")) > 0:
		u["furyBuff"] = float(u["furyBuff"]) - 1.0
	if Js.num(u.get("defBuff")) > 0:
		u["defBuff"] = float(u["defBuff"]) - 1.0
	if Js.truthy(u.get("_tenacityDef")):
		u["_tenacityDef"] = false
	if Js.num(u.get("_bleedTurns")) > 0 and Js.num(u.get("_bleedDmg")) > 0:
		u["hp"] = maxf(1.0, u["hp"] - float(u["_bleedDmg"]))
		emit("buff_tick_damage", {"unit": u, "buff": {"type": "bleed", "icon": "🗡️"}, "damage": u["_bleedDmg"]})
		u["_bleedTurns"] = float(u["_bleedTurns"]) - 1.0
		if float(u["_bleedTurns"]) <= 0.0:
			u["_bleedDmg"] = 0.0
	if Js.num(u.get("_phalanxTurns")) > 0:
		u["_phalanxTurns"] = float(u["_phalanxTurns"]) - 1.0
		if float(u["_phalanxTurns"]) <= 0.0:
			u["_phalanxDef"] = 0.0
	if Js.num(u.get("_empowerTurns")) > 0:
		u["_empowerTurns"] = float(u["_empowerTurns"]) - 1.0
		if float(u["_empowerTurns"]) <= 0.0:
			u["_empowerMul"] = 0.0
	if Js.num(u.get("_rootedTurns")) > 0:
		u["_rootedTurns"] = float(u["_rootedTurns"]) - 1.0
	if Js.num(u.get("_sanctuaryTurns")) > 0 and Js.num(u.get("_sanctuaryHeal")) > 0:
		var heal: float = u["_sanctuaryHeal"]
		u["hp"] = minf(u["mhp"], u["hp"] + heal)
		emit("buff_tick_heal", {"unit": u, "buff": {"type": "sanctuary", "icon": "✝️"}, "heal": heal})
		u["_sanctuaryTurns"] = float(u["_sanctuaryTurns"]) - 1.0
		if float(u["_sanctuaryTurns"]) <= 0.0:
			u["_sanctuaryHeal"] = 0.0
	if Js.truthy(u.get("isSummon")) and u.has("summonTurns"):
		u["summonTurns"] = float(u["summonTurns"]) - 1.0
		if Js.num(u.get("_empowerTurns")) > 0:
			u["_empowerTurns"] = float(u["_empowerTurns"]) - 1.0
		if float(u["summonTurns"]) <= 0.0:
			u["hp"] = 0.0
			emit("unit_killed", {"killer": null, "target": u, "reason": "unsummon"})
			gu.rm_dead()
	if Js.truthy(u.get("_spearwallUsed")):
		u["_spearwallUsed"] = false
	emit("turn_end", {"unit": u})
	S["actCount"] = int(S["actCount"]) + 1
	_count_turn(u)
	next_action()


## 라운드 = 살아 있는 클랜원(소환수 제외)이 모두 한 번씩 행동
func _count_turn(u: Dictionary) -> void:
	if u["team"] != "ally" or Js.truthy(u.get("isSummon")):
		return
	S["_turnActed"][u["id"]] = true
	var allies: Array = []
	for v: Dictionary in S["units"]:
		if v["team"] == "ally" and not Js.truthy(v.get("isSummon")) and v["hp"] > 0:
			allies.append(v)
	if allies.is_empty():
		return
	for v2: Dictionary in allies:
		if not S["_turnActed"].has(v2["id"]):
			return
	S["turn"] = int(S["turn"]) + 1
	S["_turnActed"] = {}
	cb.tick_poison_mists()
	var hz: Variant = S["_hazard"]
	if hz != null and Js.truthy(hz.get("safe")) and (int(S["turn"]) - 1) % int(D["SAFE_ZONE"]["every"]) == 0:
		place_safe()
		fx("redraw_terrain")
	emit("round_end", {"turn": S["turn"]})


## TurnManager.spawnWave
func spawn_wave() -> void:
	var s: Variant = S["cStage"]
	if s == null:
		return
	var rem: float = float(s["tot"]) - float(S["eSpwn"])
	if rem <= 0:
		return
	var active := 0
	for u: Dictionary in S["units"]:
		if u["team"] == "enemy" and u["hp"] > 0:
			active += 1
	var max_c: int = int(D["MAX_ENEMIES_ON_FIELD"])
	if active >= max_c:
		return
	var cnt: int = int(minf(minf(float(s["spw"]), rem), minf(float((S["eQ"] as Array).size()), float(max_c - active))))
	var mid: int = int(D["MID_C"])
	if int(S["eSpwn"]) == 0 and Js.truthy(s.get("boss")):
		var bu: Variant = gu.add_unit("enemy", s["boss"]["cls"], mid, 2)
		if bu != null:
			bu["isBoss"] = true
			bu["name"] = s["boss"].get("name", "")
			bu["origSpawn"] = {"x": mid, "y": 2}
			var g: Dictionary = D["JAB"][bu["cls"]]["growth"]
			var m: float = float(D["ENEMY_BOSS_LV"])
			bu["lv"] = int(bu["lv"]) + int(m)
			bu["hp"] = Js.round_js(bu["mhp"] + (float(g["hp"][0]) + float(g["hp"][1])) / 2.0 * m * float(s["sm"]["hp"]))
			bu["mhp"] = bu["hp"]
			bu["atk"] = Js.round_js(bu["atk"] + (float(g["atk"][0]) + float(g["atk"][1])) / 2.0 * m * float(s["sm"]["atk"]))
			bu["def"] = Js.round_js(bu["def"] + (float(g["def"][0]) + float(g["def"][1])) / 2.0 * m)
		S["eSpwn"] = int(S["eSpwn"]) + 1
		var pos_l: Array = []
		for y: int in [4, 3]:
			for x: Variant in D["FORM_COLS"]:
				pos_l.append([int(x), y])
		var pidx := 0
		while int(S["eSpwn"]) < cnt and pidx < pos_l.size() and not (S["eQ"] as Array).is_empty():
			var cls: Variant = (S["eQ"] as Array).pop_front()
			if not Js.truthy(cls):
				break
			var p: Array = pos_l[pidx]
			pidx += 1
			if gu.u_at(p[0], p[1]) == null:
				gu.add_unit("enemy", cls, p[0], p[1])
				S["eSpwn"] = int(S["eSpwn"]) + 1
	else:
		var op: Array = []
		var is_off: bool = s.get("style") == "offense"
		var rows: Array = [2, 3] if is_off else [0, 1]
		for cx in int(D["COLS"]):
			if gu.u_at(cx, rows[0]) == null:
				op.append([cx, rows[0]])
		if op.size() < cnt:
			for cx2 in int(D["COLS"]):
				if gu.u_at(cx2, rows[1]) == null:
					op.append([cx2, rows[1]])
		shuffle(op, "shuffle(op)")
		for i in mini(cnt, op.size()):
			var cls2: Variant = (S["eQ"] as Array).pop_front() if not (S["eQ"] as Array).is_empty() else null
			if not Js.truthy(cls2):
				break
			gu.add_unit("enemy", cls2, op[i][0], op[i][1])
			S["eSpwn"] = int(S["eSpwn"]) + 1
	emit("wave_spawn", {"count": cnt})


## TurnManager.nextAction (웨이브 연출 600ms 동안은 대기열로 나눔)
func next_action() -> void:
	if fsm == BATTLE_END:
		return
	var any_ally := false
	for u: Dictionary in S["units"]:
		if u["team"] == "ally" and u["hp"] > 0 and not Js.truthy(u.get("isSummon")):
			any_ally = true
			break
	if not any_ally:
		chk_end()
		return
	var stage: Variant = S["cStage"]
	if stage != null and float(S["eSpwn"]) < float(stage["tot"]):
		var interval: int = int(stage["si"]) * 2
		if int(S["actCount"]) > 0 and int(S["actCount"]) % interval == 0:
			transition(WAVE_TRANSITION)
			emit("wave_announce", {"remaining": float(stage["tot"]) - float(S["eSpwn"])})
			spawn_wave()
			fx_redraw_units()
			later(600.0, func() -> void:
				emit("wave_announce_end")
				_next_action_after_wave())
			return
	_next_action_after_wave()


func _next_action_after_wave() -> void:
	transition(ADVANCING_TICK)
	var nu: Variant = advance_tick()
	if nu == null:
		return
	S["curUnit"] = nu
	nu["_defend"] = false
	nu["_overwatch"] = false
	am.clr_sel()
	if nu["team"] == "ally":
		transition(PLAYER_IDLE)
		emit("turn_start", {"unit": nu, "phase": "player"})
		if Js.num(nu.get("stunned")) > 0 or buff_has(nu, "stun"):
			later(500.0, end_unit_turn.bind(nu))
		else:
			later(350.0, am.sel_u.bind(nu))
	else:
		transition(AI_TURN)
		emit("turn_start", {"unit": nu, "phase": "enemy"})
		if gu.is_cc(nu):
			fx_float(nu["x"], nu["y"], "messages.cc_skip")
			later(500.0, end_unit_turn.bind(nu))
			return
		later(450.0 * float(D["ENEMY_TURN_PACE"]), _ai_turn.bind(nu))


func _ai_turn(u: Dictionary) -> void:
	if not _q.is_empty():
		push_warning("battle_engine: 적 차례 시작 때 대기열에 작업 %d개 (동기 AI 가정 위반 가능)" % _q.size())
	_aborted = false
	if fsm != BATTLE_END:
		ai.e_ai(u)
	if _aborted:
		return
	end_unit_turn(u)


## TurnManager.chkEnd — 돌파 패배는 여기서만 판정
func chk_end() -> void:
	if fsm == BATTLE_END:
		return
	var al := gu.alive("ally")
	var en := gu.alive("enemy")
	var cmd_down := Js.truthy(S.get("_commanderFallen"))
	if not cmd_down:
		for u: Dictionary in S["units"]:
			if u["team"] == "ally" and u["cls"] == D["COMMANDER_CLS"] and u["hp"] <= 0:
				cmd_down = true
	if cmd_down:
		transition(BATTLE_END)
		emit("battle_end", {"win": false, "message": "commander_msg.fallen"})
		return
	var dead_summoners: Array = []
	for u2: Dictionary in S["units"]:
		if u2["cls"] == "summoner" and u2["hp"] <= 0:
			dead_summoners.append(u2)
	for ds: Dictionary in dead_summoners:
		for s: Dictionary in S["units"]:
			if Js.truthy(s.get("isSummon")) and Js.same(s.get("summonerId"), ds["id"]):
				emit("unit_killed", {"killer": null, "target": s, "reason": "unsummon"})
		var left: Array = []
		for v: Dictionary in S["units"]:
			if not (Js.truthy(v.get("isSummon")) and Js.same(v.get("summonerId"), ds["id"])):
				left.append(v)
		S["units"] = left
	var any_real := false
	for a: Dictionary in al:
		if not Js.truthy(a.get("isSummon")):
			any_real = true
	if not any_real:
		transition(BATTLE_END)
		emit("battle_end", {"win": false, "message": "messages.all_defeated"})
		return
	var s2: Variant = S["cStage"]
	if s2 != null:
		var limit := ceilf(float(s2["tot"]) / 4.0)
		if float(S["breached"]) >= limit:
			transition(BATTLE_END)
			emit("battle_end", {"win": false, "message": "messages.enemy_breached"})
			return
	for team: Array in [en, al]:
		if team.is_empty():
			continue
		var all_st := true
		for u3: Dictionary in team:
			if not is_stealthed(u3):
				all_st = false
				break
		if all_st:
			for u4: Dictionary in team:
				u4["stealthBroken"] = true
			fx_redraw_units()
	if s2 != null and float(S["eSpwn"]) >= float(s2["tot"]) and en.is_empty():
		transition(BATTLE_END)
		emit("battle_end", {"win": true, "message": "messages.stage_clear"})


func has_ally_wall() -> bool:
	for k: String in S["gateHP"].keys():
		if k.ends_with(",14") and float(S["gateHP"][k]) > 0:
			return true
	return false


# ═══════════ 클랜원 입력 (화면 버튼과 같은 입구 — 시험 정책 policy.js 의 재생 규칙) ═══════════

## ActionManager.selU 뒤: 행동 예고 ② + 차례 시작이면 100ms 뒤 입력 받기
func after_sel_u(u: Dictionary) -> void:
	if S["sel"] == u:
		plan_rule()
	if u["team"] == "ally" and S["curUnit"] == u and fsm == UNIT_SELECTED and not _busy and not ended and _last_act != int(S["actCount"]):
		_last_act = int(S["actCount"])
		later(100.0, _input_turn.bind(u))


func _input_turn(u: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	_input_step(u, turn_ends)


func _input_step(u: Dictionary, start: int) -> void:
	if turn_ends != start or ended:
		_busy = false
		return
	var cmd: Variant = input_provider.call(u) if input_provider.is_valid() else null
	if cmd == null:
		_await = {"u": u, "start": start}
		return
	_do_cmd(u, start, cmd)


## 입력을 기다리는 클랜원 (없으면 null)
func awaiting_unit() -> Variant:
	return _await.get("u")


## 입력 대기 중인 클랜원에게 명령 하나 → { ok, reason } (기록을 꺼도 같음)
##  op: move·attack·heal·shove{x,y} · skill{idx,x,y} · wait·defend·overwatch{dx,dy} · siege·climb·potion{idx,x,y} · undo
##  reason (ok=false): not_waiting · bad_op · wrong_unit · bad_dir · bad_skill · bad_item · bad_cell — 실행하지 않고 거절 (기록도 없음)
##                     move_failed · attack_failed · no_resource · skill_failed · cannot_act · item_failed · cannot_undo — 실행했지만 안 됨 (웹처럼 기록됨, 같은 클랜원이 계속 입력)
func command(cmd: Dictionary) -> Dictionary:
	if _await.is_empty():
		return {"ok": false, "reason": "not_waiting"}
	var u: Dictionary = _await["u"]
	var bad := _validate_cmd(u, cmd)
	if bad != "":
		return {"ok": false, "reason": bad}
	var start: int = _await["start"]
	_await = {}
	return _do_cmd(u, start, cmd)


const CMD_OPS := ["move", "attack", "heal", "shove", "skill", "wait", "defend", "overwatch", "siege", "climb", "potion", "undo"]


func _is_int_like(v: Variant) -> bool:
	return (typeof(v) == TYPE_INT) or (typeof(v) == TYPE_FLOAT and float(v) == floorf(float(v)))


func _validate_cmd(u: Dictionary, cmd: Dictionary) -> String:
	var op: Variant = cmd.get("op")
	if typeof(op) != TYPE_STRING or not CMD_OPS.has(op):
		return "bad_op"
	if cmd.has("u") and not Js.same(cmd["u"], u["id"]):
		return "wrong_unit"
	if op == "wait" or op == "defend" or op == "overwatch":
		var dx: Variant = cmd.get("dx", 0)
		var dy: Variant = cmd.get("dy", 0)
		if not _is_int_like(dx) or not _is_int_like(dy) or absi(int(dx)) > 1 or absi(int(dy)) > 1 or absi(int(dx)) + absi(int(dy)) > 1:
			return "bad_dir"
		return ""
	if op == "undo":
		return ""
	for k: String in ["x", "y"]:
		if cmd.has(k) and not _is_int_like(cmd[k]):
			return "bad_cell"
	if op == "skill":
		if not _is_int_like(cmd.get("idx")) or int(cmd["idx"]) < 0 or int(cmd["idx"]) >= get_unit_skills(u).size():
			return "bad_skill"
	elif op == "potion":
		if not _is_int_like(cmd.get("idx")) or int(cmd["idx"]) < 0 or int(cmd["idx"]) >= (S["_battlePotions"] as Array).size():
			return "bad_item"
	elif op == "siege" or op == "climb":
		if not _is_int_like(cmd.get("idx")) or int(cmd["idx"]) < 0 or int(cmd["idx"]) >= (S["_siegeItems"] as Array).size():
			return "bad_item"
	elif not cmd.has("x") or not cmd.has("y"):
		return "bad_cell"
	return ""


func _do_cmd(u: Dictionary, start: int, cmd: Dictionary) -> Dictionary:
	var op: String = cmd["op"]
	var no_res := false
	if op == "skill":
		var sk_list := get_unit_skills(u)
		var idx := int(cmd.get("idx", -1))
		if idx >= 0 and idx < sk_list.size() and (sk_list[idx] as Dictionary).has("cost") and float(u["res"]) < float(sk_list[idx]["cost"]):
			no_res = true
	var bx: int = u["x"]
	var by: int = u["y"]
	var ok := am.exec_cmd(u, cmd)   # ok = 기록되는 cmd.ok (웹 시험 정책과 같은 정의)
	if not ok:
		_input_step(u, start)
		return {"ok": false, "reason": _fail_reason(op, no_res)}
	if op == "move" or op == "climb" or op == "undo":
		later(400.0, _input_step.bind(u, start))
	else:
		_busy = false
	if op == "move" and u["x"] == bx and u["y"] == by:
		return {"ok": false, "reason": "move_failed"}   # 제자리 '이동' — 기록상 ok 지만 실제로 움직이지 않음
	return {"ok": true, "reason": ""}


func _fail_reason(op: String, no_res: bool) -> String:
	match op:
		"move":
			return "move_failed"
		"attack", "heal", "shove":
			return "attack_failed"
		"skill":
			return "no_resource" if no_res else "skill_failed"
		"wait", "defend", "overwatch":
			return "cannot_act"
		"siege", "climb", "potion":
			return "item_failed"
		"undo":
			return "cannot_undo"
	return "failed"


# ═══════════ 끝 ═══════════

## 전투가 멈춘 뒤 결과 (황금 기록 end 와 같은 형식, saveAfter 포함)
func finish(status: String) -> Dictionary:
	var end := end_info.duplicate()
	if end.is_empty():
		if max_rounds > 0 and int(S["turn"]) > max_rounds:
			end = {"result": "stalled"}
		else:
			end = {"result": "max_steps" if status == "max_steps" else "stuck"}
	snapshot("end")
	var allies: Array = []
	var enemies: Array = []
	for u: Dictionary in S["units"]:
		if u["team"] == "ally" and not Js.truthy(u.get("isSummon")):
			allies.append(u["id"])
		elif u["team"] == "enemy":
			enemies.append(u["id"])
	end["rounds"] = S["turn"]
	end["actCount"] = S["actCount"]
	end["rngCalls"] = c.rng.calls
	end["virtualMs"] = c.now_ms
	end["allies"] = allies
	end["enemies"] = enemies
	end["kills"] = S["_killCount"]
	end["breached"] = S["breached"]
	end["chestLog"] = (S.get("_chestLog", []) as Array).duplicate()
	end["rewards"] = rewards
	var sa: Dictionary = {}
	var keys: Array = c.store.keys()
	keys.sort()
	for k: String in keys:
		sa[k] = c.store.get_json(k)
	end["saveAfter"] = sa
	return end


# ═══════════ 전투 저장·이어하기 ═══════════
#  저장은 대기열이 빈 때만 (run() 이 "input"/"idle" 을 돌려준 뒤 — 클랜원 입력 대기). 복원한 엔진을 이어 돌린 결과는
#  끊지 않고 돌린 것과 사건 하나까지 같다 (tests/replay_golden.gd --resume). 형식은 JSON 으로 쓸 수 있는 사전 (JsonExact 로 정확히).

const SAVE_FORMAT := "deadline15-battle-save/1"
const S_INT_KEYS := ["nid", "turn", "actCount", "eSpwn", "breached", "_killCount"]
const S_UNIT_KEYS := ["curUnit", "sel"]
const UNIT_INT_KEYS := ["summonerId", "_gdx", "_gdy", "_intent", "_sacrificeKnight", "_sacrificeTarget", "_comboTgt"]


func can_save() -> bool:
	return _q.is_empty() and _pure == 0


func save_state() -> Dictionary:
	if not can_save():
		push_error("battle_engine: 대기열에 작업이 남아 저장할 수 없음 (입력 대기 때 저장)")
		return {}
	var table: Dictionary = {}
	var add := func(u: Variant) -> void:
		if typeof(u) == TYPE_DICTIONARY and _is_unit(u) and not table.has(u["id"]):
			table[u["id"]] = u
	for u: Dictionary in S["units"]:
		add.call(u)
	for u2: Variant in _known.values():
		add.call(u2)
	for k: String in S_UNIT_KEYS:
		add.call(S.get(k))
	for u3: Variant in S.get("potionTargets", []):
		add.call(u3)
	if not _await.is_empty():
		add.call(_await["u"])
	var units: Array = []
	for id: Variant in table.keys():
		units.append(Js.deep(table[id]))
	var st: Dictionary = {}
	for k2: String in S.keys():
		var v: Variant = S[k2]
		if k2 == "units":
			var ids: Array = []
			for u4: Dictionary in v:
				ids.append(u4["id"])
			st[k2] = ids
		elif S_UNIT_KEYS.has(k2):
			st[k2] = v["id"] if v != null else null
		elif k2 == "potionTargets":
			var pids: Array = []
			for u5: Dictionary in (v if v != null else []):
				pids.append(u5["id"])
			st[k2] = pids
		elif k2 == "_curSkill":
			st[k2] = v["id"] if v != null else null
		elif k2 == "_curPotion" or k2 == "_curSiege":
			st[k2] = {"idx": v["idx"]} if Js.truthy(v) else null
		else:
			st[k2] = Js.deep(v)
	return {
		"format": SAVE_FORMAT, "units": units, "S": st, "fsm": fsm, "magic_walls": Js.deep(magic_walls),
		"max_rounds": max_rounds, "ended": ended, "end_info": Js.deep(end_info), "rewards": Js.deep(rewards), "turn_ends": turn_ends,
		"busy": _busy, "last_act": _last_act, "await": {"u": _await["u"]["id"], "start": _await["start"]} if not _await.is_empty() else null,
		"seq": _seq, "now_ms": c.now_ms, "eid_counter": c.eid_counter, "rng": c.rng.get_state(),
		"record": record_enabled, "known": _known.keys(), "drawn": _drawn.keys(), "init_ter": Js.deep(_init_ter),
		"store": c.store.dump(),
	}


## 저장 문자열 (실수 정확)
func save_text() -> String:
	return JsonExact.stringify(save_state())


## (4b-2) 저장 형식이 이 엔진과 같은지 (다르면 load_state 가 받지 않음)
static func state_format_ok(d: Variant) -> bool:
	return d is Dictionary and typeof((d as Dictionary).get("format")) == TYPE_STRING and str(d["format"]) == SAVE_FORMAT


## 새 엔진(같은 데이터로 만든 것)에 복원. d 는 save_state() 결과 또는 그 JSON 을 읽은 것
##  (4b-2) d.format 이 SAVE_FORMAT 과 다르면 아무것도 바꾸지 않고 false (이전 판 저장은 이어하지 않음 — resume_rules.gd)
func load_state(d: Dictionary) -> bool:
	if not state_format_ok(d):
		return false
	_q.clear()
	var table: Dictionary = {}
	for uv: Variant in d["units"]:
		var u: Dictionary = JsonNorm.normalize(Js.deep(uv))
		for k: String in UNIT_INT_KEYS:
			if u.get(k) != null and (typeof(u[k]) == TYPE_FLOAT or typeof(u[k]) == TYPE_INT):
				u[k] = int(u[k])
		table[int(u["id"])] = u
	var unit_of := func(id: Variant) -> Variant:
		return table.get(int(id)) if id != null else null
	var st: Dictionary = d["S"]
	S.clear()
	for k2: String in st.keys():
		var v: Variant = st[k2]
		if k2 == "units":
			var arr: Array = []
			for id: Variant in v:
				arr.append(unit_of.call(id))
			S[k2] = arr
		elif S_UNIT_KEYS.has(k2):
			S[k2] = unit_of.call(v)
		elif k2 == "potionTargets":
			var pa: Array = []
			for id2: Variant in (v if v != null else []):
				pa.append(unit_of.call(id2))
			S[k2] = pa
		else:
			S[k2] = JsonNorm.normalize(Js.deep(v))
	for k3: String in S_INT_KEYS:
		if S.has(k3):
			S[k3] = int(S[k3])
	for k4: String in ["battleExp", "_turnActed", "allyPos"]:
		var dd: Dictionary = {}
		for kk: Variant in (S.get(k4, {}) as Dictionary).keys():
			dd[int(kk)] = S[k4][kk]
		S[k4] = dd
	for k5: String in ["_battlePotionIndices", "_siegeInvIndices", "_deadAllyUids", "party"]:
		var ia: Array = []
		for x: Variant in S.get(k5, []):
			ia.append(int(x))
		S[k5] = ia
	for m: Dictionary in S.get("poisonMists", []):
		m["cx"] = int(m["cx"])
		m["cy"] = int(m["cy"])
	if S.get("_curSkill") != null:
		var sid: String = S["_curSkill"]
		S["_curSkill"] = null
		var cu: Variant = S.get("sel")
		if cu != null:
			for skd: Dictionary in get_unit_skills(cu):
				if skd["id"] == sid:
					S["_curSkill"] = skd
	if Js.truthy(S.get("_curPotion")):
		var pi := int(S["_curPotion"]["idx"])
		var pot: Dictionary = S["_battlePotions"][pi]
		S["_curPotion"] = {"idx": pi, "def": D["BATTLE_POTIONS"][pot["potionId"]], "pot": pot}
	if Js.truthy(S.get("_curSiege")):
		var si := int(S["_curSiege"]["idx"])
		var sie: Dictionary = S["_siegeItems"][si]
		for sd: Dictionary in D["SIEGE_ITEMS"]:
			if sd["id"] == sie["siegeId"]:
				S["_curSiege"] = {"idx": si, "def": sd, "si": sie}
	fsm = d["fsm"]
	magic_walls = JsonNorm.normalize(Js.deep(d["magic_walls"]))
	max_rounds = int(d["max_rounds"])
	ended = bool(d["ended"])
	end_info = Js.deep(d["end_info"])
	rewards = Js.deep(d["rewards"])
	turn_ends = int(d["turn_ends"])
	_busy = bool(d["busy"])
	_last_act = int(d["last_act"])
	_await = {}
	if d.get("await") != null:
		_await = {"u": unit_of.call(d["await"]["u"]), "start": int(d["await"]["start"])}
	_seq = int(d["seq"])
	c.now_ms = float(d["now_ms"])
	c.eid_counter = int(d["eid_counter"])
	c.rng.set_state(d["rng"])
	record_enabled = bool(d["record"])
	_known = {}
	for id3: Variant in d["known"]:
		_known[int(id3)] = unit_of.call(id3)
	_drawn = {}
	for id4: Variant in d["drawn"]:
		_drawn[int(id4)] = true
	_init_ter = Js.deep(d["init_ter"])
	c.store = c.store.get_script().new()
	c.store.load_from(d["store"])
	_end_hp = null
	_skill_before = null
	_aborted = false
	trace = []
	return true
