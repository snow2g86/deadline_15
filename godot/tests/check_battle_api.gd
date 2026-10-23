extends SceneTree
## 전투 엔진 API 시험 (3단계 화면용 입구)
##   Godot --headless --path godot --script res://tests/check_battle_api.gd
##  1) 조회 함수가 순수한지: 황금 기록 몇 개를 command() 로 재생하며 **모든 입력 대기 때마다** 모든 조회를 부르고,
##     호출 전후의 전투 저장 문자열(난수 상태·호출 수·유닛·저장소·기록기 상태 전부)·기록 길이·신호 수가 같은지
##  2) command() 결과·검사 (방향 값, 대기 아님, 잘못된 번호)  3) bus_event 의 유닛이 그 시점 사본인지
##  4) plan_rule 이 AI_TURN·BATTLE_END 에서 건너뛰는지  5) 규칙 코드의 실수 리터럴이 정확히 컴파일되는지

const BaselineData := preload("res://tests/baseline_data.gd")
const DataDBScript := preload("res://scripts/core/data_db.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")
const NumParse := preload("res://scripts/core/num_parse.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")
const BattleEngine := preload("res://scripts/logic/battle/battle_engine.gd")

const SCENARIOS := ["balanced_s05", "legion5_s09", "swamp_s21", "assassins_s06", "siege_items_s13", "gear_s15"]

var _started := false
var _pass := 0
var _fail := 0
var _failures: PackedStringArray = PackedStringArray()
var _globals: Dictionary
var _bus_n := 0
var _fx_n := 0


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		quit(_run())
	return false


var _cons_bad := 0   # 도입 3·4 조회 값 일치 위반 수


func _check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  " + label)
	else:
		_fail += 1
		_failures.append(label)
		print("  FAIL  " + label)


func _run() -> int:
	print("── DEADLINE 15 · 전투 엔진 API 시험 ──")
	var db: Object = root.get_node_or_null("DataDB")
	var own: Node = null
	if db == null:
		own = DataDBScript.new()
		db = own
	BaselineData.apply_db(db)   # 기준 데이터 (tests/baseline_data.gd)
	_globals = Ctx.globals_from_db(db)
	_test_purity()
	_test_command()
	_test_bus_snapshot()
	_test_plan_rule()
	_test_literals()
	_test_gear_drop_items()
	if own != null:
		own.free()
	print("──────────────────────────────")
	if _fail == 0:
		print("RESULT: PASS (%d개 통과)" % _pass)
		return 0
	print("RESULT: FAIL (%d개 실패 / %d개 통과)" % [_fail, _pass])
	for f: String in _failures:
		print("  - " + f)
	return 1


func _gold(name: String) -> Dictionary:
	return JsonExact.parse(FileAccess.get_file_as_string("res://tests/golden/%s.json" % name))


## 황금 기록대로 준비한 엔진 + 명령 목록
func _make(name: String) -> Array:
	var g := _gold(name)
	var sc: Dictionary = g["scenario"]
	var eng := BattleEngine.new(_globals, int(sc["seed"]))
	eng.start({"save": g["save"], "stage": sc["stage"], "practice": sc["practice"], "inject": g["setup"]["inject"], "maxRounds": int(sc["maxRounds"])})
	var cmds: Array = []
	for e: Dictionary in g["events"]:
		if e["ev"] == "cmd":
			cmds.append(e)
	eng.bus_event.connect(func(_n: String, _d: Dictionary) -> void: _bus_n += 1)
	eng.fx_event.connect(func(_k: String, _d: Dictionary) -> void: _fx_n += 1)
	return [eng, cmds, g]


func _fingerprint(eng: Object) -> String:
	return "%s|%d|%d|%d" % [eng.save_text(), eng.trace.size(), _bus_n, _fx_n]


## 모든 조회를 부름 (지금 차례 클랜원 + 모든 유닛 쌍 미리보기 + 모든 스킬 대상)
func _query_all(eng: Object) -> int:
	var n := 0
	var u: Variant = eng.awaiting_unit()
	var units: Array = eng.S["units"]
	n += eng.q.gear_drop_items(eng.q.inventory_eids()).size()
	for a: Dictionary in units:
		n += eng.q.move_cells(a).size()
		var at: Dictionary = eng.q.attack_targets(a)
		n += (at["attack"] as Array).size()
		for t: Dictionary in units:
			if t["team"] != a["team"] and t["hp"] > 0:
				var p: Dictionary = eng.q.preview_attack(a, t)
				n += int(p["dmg"])
				# 3b: 실제 공격처럼 계산하는 미리보기(고양 버프를 잠시 뺌)도 순수해야 함
				var p2: Dictionary = eng.q.preview_attack(a, t, true)
				n += int(p2["dmg"])
				# 도입 3: 계산 내역 조회도 순수 + preview_attack 의 값과 맞아야 함 (식 불변 확인)
				var pp: Dictionary = eng.q.preview_parts(a, t)
				n += int(pp["base"])
				if p["intercept"] == null and not (float(pp["pct"]) == float(p["pct"]) and (pp["tags"] as Array) == (p["tags"] as Array)):
					_cons_bad += 1
		if a["team"] == "enemy":
			n += (eng.q.enemy_range(a)["attack"] as Array).size()
		n += eng.q.face_options(a).size()
		if a["team"] == "ally":
			for st: Dictionary in eng.q.skill_status(a):
				n += 1 if st["usable"] else 0
			for i in eng.get_unit_skills(a).size():
				n += (eng.q.skill_targets(a, i)["cells"] as Array).size()
	if u != null:
		n += eng.q.actions(u).size()
		n += 1 if eng.q.can_undo() else 0
		# 3a 에서 더한 조회 (밀치기·물약·공성 아이템 대상)
		n += eng.q.shove_cells(u).size()
		for i2 in (eng.S["_battlePotions"] as Array).size():
			n += (eng.q.potion_targets(u, i2)["cells"] as Array).size()
		for i3 in (eng.S["_siegeItems"] as Array).size():
			n += (eng.q.siege_targets(u, i3)["cells"] as Array).size()
	n += eng.q.threat_cells().size()
	n += eng.q.threat_cells(false).size()
	# 도입 4: 적 한 명 범위들의 공격 칸 합집합(보이는 적)이 전체 위협과 같아야 함
	var uni: Dictionary = {}
	var vis: Dictionary = eng.q.fog_visible()
	for e: Dictionary in units:
		if e["team"] == "enemy" and e["hp"] > 0 and not eng.is_stealthed(e) and vis.has("%d,%d" % [e["x"], e["y"]]):
			for k: String in eng.q.enemy_range(e)["attack"]:
				uni[k] = true
	var thr: Dictionary = {}
	for k2: String in eng.q.threat_cells():
		thr[k2] = true
	if uni != thr:
		_cons_bad += 1
	return n


func _test_purity() -> void:
	print("[조회 함수 순수성]")
	for name: String in SCENARIOS:
		var mk := _make(name)
		var eng: Object = mk[0]
		var cmds: Array = mk[1]
		var ci := 0
		var points := 0
		var bad := 0
		eng.begin()
		var st: String = eng.run()
		while st == "input" and ci < cmds.size():
			var before := _fingerprint(eng)
			_query_all(eng)
			_query_all(eng)
			var after := _fingerprint(eng)
			points += 1
			if before != after:
				bad += 1
				if bad == 1:
					print("    · %s 입력 대기 %d: 조회 뒤 상태가 바뀜" % [name, points])
			eng.command(cmds[ci])
			ci += 1
			st = eng.run()
		_check(_cons_bad == 0, "%s: 도입 3·4 조회 일치 (preview_parts 전술 보정 = preview_attack · 적 범위 합집합 = 전체 위협) 위반 %d" % [name, _cons_bad])
		_cons_bad = 0
		var end: Dictionary = eng.finish(st)
		var gend: Dictionary = mk[2]["end"]
		_check(bad == 0 and points > 10 and end["rngCalls"] == gend["rngCalls"] and end["result"] == gend["result"] and eng.trace.size() == (mk[2]["events"] as Array).size(),
			"%s: 입력 대기 %d번마다 모든 조회 → 상태·난수·기록·신호 그대로, 끝까지 기록과 같음 (난수 %d)" % [name, points, end["rngCalls"]])
		eng.dispose()


func _test_command() -> void:
	print("[command() 결과]")
	var mk := _make("balanced_s05")
	var eng: Object = mk[0]
	var cmds: Array = mk[1]
	_check(eng.command({"op": "wait"})["reason"] == "not_waiting", "입력 대기 전 명령 → not_waiting")
	eng.begin()
	var st: String = eng.run()
	_check(st == "input" and eng.awaiting_unit() != null, "run() 이 클랜원 입력 대기에서 멈춤")
	var fp := _fingerprint(eng)
	var r1: Dictionary = eng.command({"op": "defend", "dx": 1, "dy": 1})
	var r2: Dictionary = eng.command({"op": "wait", "dx": 2, "dy": 0})
	var r3: Dictionary = eng.command({"op": "fly"})
	var r4: Dictionary = eng.command({"op": "skill", "idx": 99, "x": 0, "y": 0})
	var r5: Dictionary = eng.command({"op": "potion", "idx": 0, "x": 0, "y": 0})
	var r6: Dictionary = eng.command({"op": "move", "x": 1.5, "y": 3})
	_check(r1["reason"] == "bad_dir" and r2["reason"] == "bad_dir" and r3["reason"] == "bad_op" and r4["reason"] == "bad_skill" and r5["reason"] == "bad_item" and r6["reason"] == "bad_cell",
		"잘못된 명령 거절: 대각선·범위 밖 방향 bad_dir, 없는 op, 없는 스킬·물약 번호, 정수 아닌 칸")
	_check(_fingerprint(eng) == fp, "거절된 명령은 상태·기록을 바꾸지 않음")
	var u: Dictionary = eng.awaiting_unit()
	var r7: Dictionary = eng.command({"op": "move", "x": u["x"], "y": u["y"]})
	eng.run()
	var r9: Dictionary = eng.command({"op": "move", "x": -1, "y": -1})
	_check(not r7["ok"] and r7["reason"] == "move_failed" and not r9["ok"] and r9["reason"] == "move_failed" and eng.awaiting_unit() == u,
		"실행했지만 안 된 이동(제자리·맵 밖) → ok=false, move_failed, 같은 클랜원이 계속 입력")
	# 기록을 꺼도 결과가 나옴
	eng.record_enabled = false
	var r8: Dictionary = eng.command(cmds[0])
	_check(r8.has("ok") and r8.has("reason"), "기록을 꺼도 command() 가 { ok, reason } 을 돌려줌")
	eng.dispose()


func _test_bus_snapshot() -> void:
	print("[bus_event 사본]")
	var mk := _make("balanced_s05")
	var eng: Object = mk[0]
	var cmds: Array = mk[1]
	var got: Array = []
	eng.bus_event.connect(func(n: String, d: Dictionary) -> void:
		if n == "unit_attacked":
			got.append([d, d["target"]["hp"]]))
	var ci := 0
	eng.begin()
	var st: String = eng.run()
	while st == "input" and ci < cmds.size():
		eng.command(cmds[ci])
		ci += 1
		st = eng.run()
	var same := true
	var copies := true
	for e: Array in got:
		if e[0]["target"]["hp"] != e[1]:
			same = false
		if eng.unit_by_id(e[0]["target"]["id"]) != null and is_same(eng.unit_by_id(e[0]["target"]["id"]), e[0]["target"]):
			copies = false
	_check(got.size() > 10 and same and copies, "unit_attacked %d개: 넘어온 유닛은 사본이고, 전투가 끝난 뒤에도 그 시점 HP 그대로" % got.size())
	eng.dispose()


func _test_plan_rule() -> void:
	print("[행동 예고 plan_rule]")
	var mk := _make("knights_s11")
	var eng: Object = mk[0]
	var enemies: Array = []
	for u: Dictionary in eng.S["units"]:
		if u["team"] == "enemy":
			enemies.append(u)
			u["_intent"] = -7
	for st: String in [BattleEngine.AI_TURN, BattleEngine.BATTLE_END]:
		eng.fsm = st
		eng.plan_rule()
	var kept := true
	for e: Dictionary in enemies:
		if e["_intent"] != -7:
			kept = false
	_check(not enemies.is_empty() and kept, "AI_TURN·BATTLE_END 에서는 예고를 다시 계산하지 않음")
	eng.fsm = BattleEngine.PLAYER_IDLE
	var r0: int = eng.c.rng.calls
	eng.plan_rule()
	var changed := true
	for e2: Dictionary in enemies:
		if e2["_intent"] == -7:
			changed = false
	_check(changed and eng.c.rng.calls == r0, "그 밖의 상태에서는 다시 계산 (난수 안 씀)")
	eng.dispose()


## 규칙·기반 코드의 실수 리터럴이 정확히 컴파일됐는지 (GDScript 리터럴도 Godot 의 부정확한 문자열→실수 변환을 거침)
## gear_drop_items: 전투 뒤 새로 생긴 물건 중 eid 있는 것(장비)만 장비 보상과 짝지음 — 룬·스킬북(eid 없음)은 건너뜀
func _test_gear_drop_items() -> void:
	print("[gear_drop_items]")
	var r := _make("gear_s15")
	var eng: Object = r[0]
	var store: Object = eng.c.store
	var key := str(_globals.get("INV_KEY", "game_inventory"))
	var keep: Variant = store.get_json(key)
	store.set_json(key, [{"type": "equip", "eid": "eq_old", "templateId": "wpn_old"}])
	var before: Dictionary = eng.q.inventory_eids()
	store.set_json(key, [
		{"type": "equip", "eid": "eq_old", "templateId": "wpn_old"},
		{"type": "rune", "id": "rune_fire"},
		{"type": "equip", "eid": "eq_new1", "templateId": "wpn_a"},
		{"type": "skillbook", "id": "sb_x", "eid": null},
		{"type": "equip", "eid": "eq_new2", "templateId": "arm_b"},
		{"type": "rune", "id": "rune_ice"},
	])
	var drops_keep: Variant = eng.S.get("_gearDrops")
	eng.S["_gearDrops"] = [{"templateId": "wpn_a"}, {"stone": 2}, {"templateId": "arm_b", "legend": true}]
	var out: Array = eng.q.gear_drop_items(before)
	eng.S["_gearDrops"] = drops_keep
	store.set_json(key, keep if keep != null else [])
	eng.dispose()
	_check(before.size() == 1 and before.has("eq_old"), "inventory_eids: eid 있는 물건만 (%s)" % str(before.keys()))
	var ok: bool = out.size() == 3 and out[0]["item"] != null and str(out[0]["item"]["eid"]) == "eq_new1" and out[1].has("stone") \
		and out[2]["item"] != null and str(out[2]["item"]["eid"]) == "eq_new2" and bool(out[2]["legend"])
	_check(ok, "장비 보상 2개 ↔ 새 장비 eq_new1·eq_new2 (룬·스킬북 건너뜀) %s" % str(out))


func _test_literals() -> void:
	print("[실수 리터럴]")
	var re := RegEx.new()
	re.compile("(?<![\\w.])([0-9]+\\.[0-9]+(?:[eE][+-]?[0-9]+)?|[0-9]+[eE][+-]?[0-9]+)(?![\\w.])")
	var files: Array = []
	for dir: String in ["res://scripts/core/", "res://scripts/logic/", "res://scripts/logic/battle/"]:
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				files.append(dir + f)
	var n := 0
	var bad: PackedStringArray = PackedStringArray()
	for path: String in files:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var code := line.split("#")[0]
			var strip := RegEx.new()
			strip.compile("\"[^\"]*\"")
			code = strip.sub(code, "", true)
			for m: RegExMatch in re.search_all(code):
				n += 1
				var lit := m.get_string(1)
				var compiled: Variant = str_to_var(lit)   # 컴파일러와 같은 변환
				if NumParse._bits(float(compiled)) != NumParse._bits(NumParse.parse_number(lit)):
					bad.append(path.get_file() + ": " + lit)
	_check(n > 50 and bad.is_empty(), "실수 리터럴 %d개가 정확히 컴파일됨 %s" % [n, "" if bad.is_empty() else str(bad)])
