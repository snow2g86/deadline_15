extends SceneTree
## 2b 시험: 황금 기록(tests/golden/*.json)을 GDScript 전투 규칙으로 다시 돌려 사건 하나·난수 호출 하나까지 같은지 확인
##   Godot --headless --path godot --script res://tests/replay_golden.gd [-- --only 이름[,이름…]] [--rng-log] [--verbose]
##  시나리오마다: 같은 세이브·스테이지·시드·주입으로 전투를 준비(setup 비교) → 기록된 아군 명령을 재생 → 모든 사건(rng/rngEnd 포함)·
##  스냅샷·end(결과·보상·saveAfter) 비교. 첫 불일치에서 그 시나리오를 멈추고 자세히 출력. 모두 통과해야 종료 코드 0.
##  --rng-log: 시나리오마다 user://rng-log/<이름>.txt 에 '번호<TAB>웹 함수 이름' (node tools/battle-sim.js --rng-log 와 비교)
##  비교에서 빼는 값: end.virtualMs(가상 시각), saveAfter 의 시계 기반 값(eid·rid·pid·diedAt) — tests/golden/README.md

const DataDBScript := preload("res://scripts/core/data_db.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")
const BattleEngine := preload("res://scripts/logic/battle/battle_engine.gd")

const GOLDEN := "res://tests/golden/"
const CLOCK_KEYS := ["eid", "rid", "pid", "diedAt"]

var _started := false
var _only: PackedStringArray = PackedStringArray()
var _rng_log := false
var _verbose := false
## --external: input_provider 없이 run() 이 "input" 을 돌려줄 때마다 command() 로 명령을 넣음 (3단계 화면이 쓰는 입구 시험)
var _external := false
## --resume [N]: --external 처럼 재생하며 N 번째 입력 대기마다 전투를 저장(정확한 JSON 문자열) → 새 엔진에 복원 → 이어서 (기본 N=1: 모든 입력 대기)
var _resume := 0


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var code := _run()
		quit(code)
	return false


func _run() -> int:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--only" and i + 1 < args.size():
			_only = args[i + 1].split(",")
		elif args[i] == "--rng-log":
			_rng_log = true
		elif args[i] == "--verbose":
			_verbose = true
		elif args[i] == "--external":
			_external = true
		elif args[i] == "--resume":
			_external = true
			_resume = 1
			if i + 1 < args.size() and args[i + 1].is_valid_int():
				_resume = args[i + 1].to_int()
	var db: Object = root.get_node_or_null("DataDB")
	var own_db: Node = null
	if db == null:
		own_db = DataDBScript.new()
		db = own_db
	if not db.call("load_all"):
		print("RESULT: FAIL (데이터 읽기 실패)")
		return 1
	var globals := Ctx.globals_from_db(db)
	var index: Variant = _read_json(GOLDEN + "index.json")
	if typeof(index) != TYPE_DICTIONARY:
		print("RESULT: FAIL (index.json 없음)")
		return 1
	print("── DEADLINE 15 · 2b 전투 규칙 재생 시험 (황금 기록 %d개) ──" % (index["scenarios"] as Array).size())
	var rows: Array = []
	var all_ok := true
	for row: Dictionary in index["scenarios"]:
		var name: String = row["name"]
		if not _only.is_empty() and not _only.has(name):
			continue
		var t0 := Time.get_ticks_msec()
		var res := _replay(name, globals)
		res["ms"] = Time.get_ticks_msec() - t0
		rows.append(res)
		if not res["ok"]:
			all_ok = false
	print("")
	print("시나리오                 결과   사건 비교           난수     시간")
	for r: Dictionary in rows:
		print("%-24s %-6s %-19s %-8s %5dms" % [r["name"], "PASS" if r["ok"] else "FAIL", "%d/%d" % [r["matched"], r["total"]], str(r["rng"]), r["ms"]])
	var npass := 0
	for r2: Dictionary in rows:
		if r2["ok"]:
			npass += 1
	print("")
	if own_db != null:
		own_db.free()
	if all_ok and not rows.is_empty():
		print("RESULT: PASS (%d/%d)" % [npass, rows.size()])
		return 0
	print("RESULT: FAIL (%d/%d 통과)" % [npass, rows.size()])
	return 1


func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JsonExact.parse(f.get_as_text())


func _replay(name: String, globals: Dictionary) -> Dictionary:
	var out := {"name": name, "ok": false, "matched": 0, "total": 0, "rng": 0}
	var gold: Variant = _read_json(GOLDEN + name + ".json")
	if typeof(gold) != TYPE_DICTIONARY:
		print("[%s] 기록 파일을 읽지 못함" % name)
		return out
	var sc: Dictionary = gold["scenario"]
	var gsetup: Dictionary = gold["setup"]
	var gevents: Array = gold["events"]
	out["total"] = gevents.size()
	var cmds: Array = []
	for e: Dictionary in gevents:
		if e["ev"] == "cmd":
			cmds.append(e)
	var ci := [0]
	var eng := BattleEngine.new(globals, int(sc["seed"]))
	eng.c.rng.log_enabled = _rng_log
	if not _external:
		eng.input_provider = func(u: Dictionary) -> Variant:
			if ci[0] >= cmds.size():
				return null
			var cmd: Dictionary = cmds[ci[0]]
			ci[0] += 1
			return cmd
	var cfg := {"save": gold["save"], "stage": sc["stage"], "practice": sc["practice"], "inject": gsetup["inject"], "maxRounds": int(sc["maxRounds"])}
	var setup := eng.start(cfg)
	# ── setup 비교 ──
	for k: String in gsetup.keys():
		if k == "initEvents":
			var ge: Array = gsetup[k]
			var me: Array = setup.get(k, [])
			for i in maxi(ge.size(), me.size()):
				var a: Variant = ge[i] if i < ge.size() else null
				var b: Variant = me[i] if i < me.size() else null
				var d := _diff(a, b, "setup.initEvents[%d]" % i)
				if d != "":
					print("[%s] FAIL setup.initEvents[%d] (난수 %s)\n  %s\n  기대: %s\n  실제: %s" % [name, i, str(a.get("rng") if a != null else "-"), d, _j(a), _j(b)])
					_dump_rng(name, eng)
					eng.dispose()
					return out
			continue
		var d2 := _diff(gsetup[k], setup.get(k), "setup." + k)
		if d2 != "":
			print("[%s] FAIL setup.%s\n  %s\n  기대: %s\n  실제: %s" % [name, k, d2, _j(gsetup[k]).left(1500), _j(setup.get(k)).left(1500)])
			_dump_rng(name, eng)
			eng.dispose()
			return out
	# ── 실행 ──
	eng.begin()
	var status := eng.run()
	var traces: Array = []
	var waits := 0
	var cuts := 0
	while _external and status == "input" and ci[0] < cmds.size():
		waits += 1
		if _resume > 0 and waits % _resume == 0:
			var text: String = eng.save_text()
			traces.append_array(eng.trace)
			eng.dispose()
			eng = BattleEngine.new(globals, int(sc["seed"]))
			eng.c.rng.log_enabled = _rng_log
			eng.load_state(JsonExact.parse(text))
			cuts += 1
		var u: Variant = eng.awaiting_unit()
		if u == null or int(u["id"]) != int(cmds[ci[0]]["u"]):
			print("[%s] 입력 대기 유닛 %s ≠ 다음 명령 유닛 %s" % [name, str(u["id"] if u != null else null), str(cmds[ci[0]]["u"])])
			break
		eng.command(cmds[ci[0]])
		ci[0] += 1
		status = eng.run()
	var end := eng.finish(status)
	traces.append_array(eng.trace)
	var trace: Array = traces
	if _resume > 0 and _verbose:
		print("[%s] 저장·복원 %d번" % [name, cuts])
	# ── 사건 비교 ──
	var n := mini(gevents.size(), trace.size())
	for i2 in n:
		var d3 := _diff(gevents[i2], trace[i2], "events[%d]" % i2)
		if d3 != "":
			print("[%s] FAIL 사건 %d (%s, 난수 %s)\n  %s" % [name, i2, gevents[i2].get("ev"), str(gevents[i2].get("rng")), d3])
			for j in range(maxi(0, i2 - 3), i2):
				print("    앞 %d: %s" % [j, _j(gevents[j]).left(300)])
			print("  기대: %s\n  실제: %s" % [_j(gevents[i2]).left(2500), _j(trace[i2]).left(2500)])
			out["matched"] = i2
			out["rng"] = eng.c.rng.calls
			_dump_rng(name, eng)
			eng.dispose()
			return out
	out["matched"] = n
	out["rng"] = eng.c.rng.calls
	if gevents.size() != trace.size():
		print("[%s] FAIL 사건 수 기대 %d / 실제 %d (실행 상태 %s, 남은 명령 %d)" % [name, gevents.size(), trace.size(), status, cmds.size() - ci[0]])
		if trace.size() > n:
			print("  더 나온 사건: %s" % _j(trace[n]).left(600))
		else:
			print("  빠진 사건: %s" % _j(gevents[n]).left(600))
		_dump_rng(name, eng)
		eng.dispose()
		return out
	# ── end 비교 ──
	var gend: Dictionary = gold["end"]
	for k2: String in gend.keys():
		if k2 == "virtualMs":
			continue
		var d4 := _diff(gend[k2], end.get(k2), "end." + k2)
		if d4 != "":
			print("[%s] FAIL end.%s\n  %s\n  기대: %s\n  실제: %s" % [name, k2, d4, _j(gend[k2]).left(2500), _j(end.get(k2)).left(2500)])
			_dump_rng(name, eng)
			eng.dispose()
			return out
	if ci[0] != cmds.size():
		print("[%s] FAIL 명령 %d개 중 %d개만 재생" % [name, cmds.size(), ci[0]])
		eng.dispose()
		return out
	_dump_rng(name, eng)
	eng.dispose()
	out["ok"] = true
	if _verbose:
		print("[%s] PASS" % name)
	return out


func _dump_rng(name: String, eng: Object) -> void:
	if not _rng_log:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://rng-log"))
	var f := FileAccess.open("user://rng-log/%s.txt" % name, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(eng.c.rng.log) + "\n")
		print("  난수 기록: %s" % ProjectSettings.globalize_path("user://rng-log/%s.txt" % name))


func _j(v: Variant) -> String:
	return JSON.stringify(_plain(v))


## 비교·출력용: 사전 키를 문자열로
func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var o: Dictionary = {}
			for k: Variant in v.keys():
				o[str(k)] = _plain(v[k])
			return o
		TYPE_ARRAY:
			var a: Array = []
			for x: Variant in v:
				a.append(_plain(x))
			return a
	return v


## 첫 차이를 '경로: 기대 vs 실제' 로 (같으면 "")
func _diff(a: Variant, b: Variant, path: String) -> String:
	var ta := typeof(a)
	var tb := typeof(b)
	var na := ta == TYPE_INT or ta == TYPE_FLOAT
	var nb := tb == TYPE_INT or tb == TYPE_FLOAT
	if na and nb:
		if float(a) == float(b):
			return ""
		return "%s: %s ≠ %s" % [path, str(a), str(b)]
	if ta == TYPE_DICTIONARY and tb == TYPE_DICTIONARY:
		var bd: Dictionary = {}
		for k: Variant in b.keys():
			bd[str(k)] = b[k]
		for k2: Variant in a.keys():
			var ks := str(k2)
			if CLOCK_KEYS.has(ks) and path.begins_with("end.saveAfter"):
				continue
			if not bd.has(ks):
				return "%s.%s: 실제에 없음 (기대 %s)" % [path, ks, _j(a[k2]).left(200)]
			var d := _diff(a[k2], bd[ks], path + "." + ks)
			if d != "":
				return d
		for k3: String in bd.keys():
			var found := false
			for k4: Variant in a.keys():
				if str(k4) == k3:
					found = true
					break
			if not found:
				return "%s.%s: 기대에 없음 (실제 %s)" % [path, k3, _j(bd[k3]).left(200)]
		return ""
	if ta == TYPE_ARRAY and tb == TYPE_ARRAY:
		if (a as Array).size() != (b as Array).size():
			return "%s: 길이 %d ≠ %d" % [path, (a as Array).size(), (b as Array).size()]
		for i in (a as Array).size():
			var d2 := _diff(a[i], b[i], "%s[%d]" % [path, i])
			if d2 != "":
				return d2
		return ""
	if ta != tb:
		return "%s: 형 %s(%s) ≠ %s(%s)" % [path, type_string(ta), str(a).left(80), type_string(tb), str(b).left(80)]
	if a != b:
		return "%s: %s ≠ %s" % [path, str(a).left(120), str(b).left(120)]
	return ""
