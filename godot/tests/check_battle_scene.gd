extends SceneTree
## 3a 시험: 전투 장면(scenes/battle/battle.tscn)을 머리 없이 띄우고, 황금 기록의 아군 명령을 **화면 입구(UI 수준 API)** 로 재생해
##  엔진 결과가 황금 기록과 같은지 확인 — 화면 연결이 규칙을 바꾸지 않음을 보임.
##   Godot --headless --path godot --script res://tests/check_battle_scene.gd [-- --only 이름[,이름…]] [--speed n]
##  명령 → 화면 조작:  move·attack·heal·shove → ui_action + ui_click_cell / skill → ui_action("skill") + ui_pick_skill (+ ui_click_cell)
##                    wait·defend·overwatch → ui_action + ui_pick_face / undo → ui_action("undo") / potion·siege·climb → ui_action("item") + ui_pick_item + ui_click_cell
##  비교: end 전체 (virtualMs·시계 기반 값 제외, replay_golden.gd 와 같은 규칙) + 사건 기록 전체 (cmd 사건은 u·op·ok·idx 만 —
##        화면은 정책이 붙인 참고 키(target·skill·item)와 즉시형 스킬의 x·y 를 보내지 않으므로)
##  안내 줄: 진짜 실패한 명령 뒤엔 메뉴로 돌아와도(다음 프레임까지) 실패 안내가 남고, 정상 명령·회피된 공격 뒤엔 안내가 없어야 함
##  끝에 회귀 시험 하나: rotate:boss_s10 — 실제 연출 속도(8x)로 재생하며 유닛이 움직일 때마다 카메라를 돌려, 멈춘 유닛이 늘 자기 칸에 있는지
##  기본은 연출 없이(speed 0 — 재생 처리기는 모두 돌지만 기다리지 않음). --speed 4 처럼 주면 실제 연출 속도로 (느림)
##  (3b) HUD·연출·스토리 대사를 모두 켠 채 재생: 스토리는 story=auto (대사를 프레임마다 저절로 넘김 — 재생을 붙잡는 경로를 그대로 지남).
##       끝나면 결과 화면이 떠야 하고(이긴 판은 클랜원 경험치 줄), 재생한 스토리 장면 수를 출력 (보스전 등에서 0 이면 실패)

const JsonExact := preload("res://scripts/core/json_exact.gd")
const BattleScene := preload("res://scripts/battle/battle_scene.gd")
const SCENE := "res://scenes/battle/battle.tscn"
const GOLDEN := "res://tests/golden/"
const CLOCK_KEYS := ["eid", "rid", "pid", "diedAt"]
const MAX_FRAMES := 200000
## 이동 중 회전 회귀 시험에 쓸 기록 (보스전: 이동이 많음)
const ROTATE_SCENARIO := "boss_s10"

var _only: PackedStringArray = PackedStringArray()
var _story_total := 0
var _speed := 0.0
## --smoke: 황금 기록 대신 테마·진형이 다른 스테이지들을 디버그 세이브로 띄워 '방어 태세'만 반복 (화면 코드가 모든 지도에서 오류 없이 도는지)
var _smoke := false
const SMOKE_STAGES := [1, 3, 6, 7, 10, 11, 14, 17, 19, 21, 24, 27, 30, 33, 40, 50, 60, 75, 90, 100]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--only" and i + 1 < args.size():
			_only = args[i + 1].split(",")
		elif args[i] == "--speed" and i + 1 < args.size():
			_speed = args[i + 1].to_float()
		elif args[i] == "--smoke":
			_smoke = true
	if _smoke:
		_smoke_main.call_deferred()
	else:
		_main.call_deferred()


func _smoke_main() -> void:
	print("── 3b 전투 장면 연기 시험 (여러 지도·진형, 방어 태세만 · HUD·스토리 켬) ──")
	for sid: int in SMOKE_STAGES:
		var cfg := BattleScene.golden_cfg("balanced_s05")
		cfg["stage"] = {"id": sid}
		cfg["inject"] = []
		cfg["maxRounds"] = 6
		cfg["speed"] = _speed
		cfg["seed"] = 100 + sid
		cfg["story"] = "auto"
		BattleScene.pending = cfg
		var scene: Node = (load(SCENE) as PackedScene).instantiate()
		root.add_child(scene)
		var n := 0
		var frames := 0
		while frames < 20000 and not scene.is_over():
			await process_frame
			frames += 1
			if scene.is_awaiting():
				# 방어 태세(지금 방향)만, 가끔 카메라 회전
				if n % 7 == 3:
					scene.rotate_cam(1)
				scene.ui_action("defend")
				scene.ui_pick_face(0, 0)
				n += 1
		var st: Dictionary = scene.eng.S["cStage"]
		print("  스테이지 %3d %-9s %-8s 명령 %3d → %s (%d라운드)" % [sid, st.get("mapType"), st.get("style"), n, str(scene.result.get("result", "끝나지 않음")), int(scene.result.get("rounds", 0))])
		scene.queue_free()
		await process_frame
	print("RESULT: DONE (위 출력에 Godot 오류 줄이 없으면 통과)")
	quit(0)


func _main() -> void:
	print("── DEADLINE 15 · 3b 전투 장면 시험 (화면 입구로 황금 기록 재생 · HUD·연출·스토리 켬) ──")
	var index: Dictionary = JsonExact.parse(FileAccess.get_file_as_string(GOLDEN + "index.json"))
	var rows: Array = []
	var npass := 0
	for row: Dictionary in index["scenarios"]:
		var name: String = row["name"]
		if not _only.is_empty() and not _only.has(name):
			continue
		var t0 := Time.get_ticks_msec()
		var r: Dictionary = await _run_one(name)
		r["ms"] = Time.get_ticks_msec() - t0
		rows.append(r)
		if r["ok"]:
			npass += 1
	# 안내 줄 직접 시험: 다른 클랜원이 선 칸으로 이동(move_failed) → 안내가 남고, 다음 조작 때 지워짐
	if _only.is_empty() or _only.has("hint_probe"):
		var hp: Dictionary = await _hint_probe()
		rows.append(hp)
		if hp["ok"]:
			npass += 1
	# 회귀: 유닛이 움직이는 중에 카메라를 돌려도 화면 위치가 칸과 어긋나지 않는지 (실제 연출 속도로 1개)
	if _only.is_empty() or _only.has("rotate:" + ROTATE_SCENARIO):
		var t1 := Time.get_ticks_msec()
		var rr: Dictionary = await _run_one(ROTATE_SCENARIO, true)
		rr["name"] = "rotate:" + ROTATE_SCENARIO
		rr["ms"] = Time.get_ticks_msec() - t1
		rows.append(rr)
		if rr["ok"]:
			npass += 1
	print("")
	print("재생한 스토리 장면 합계 %d" % _story_total)
	if _story_total == 0 and (_only.is_empty() or _only.has("boss_s10")):
		print("[story] FAIL 스토리 장면이 하나도 재생되지 않음")
		rows.append({"name": "story", "ok": false, "cmds": 0, "cmds_done": 0, "events": 0, "ms": 0})
	print("시나리오                 결과   명령     사건      시간")
	for r2: Dictionary in rows:
		print("%-24s %-6s %-8s %-9s %5dms" % [r2["name"], "PASS" if r2["ok"] else "FAIL", "%d/%d" % [r2["cmds_done"], r2["cmds"]], str(r2["events"]), r2["ms"]])
	print("")
	if npass == rows.size() and not rows.is_empty():
		print("RESULT: PASS (%d/%d)" % [npass, rows.size()])
		quit(0)
	else:
		print("RESULT: FAIL (%d/%d 통과)" % [npass, rows.size()])
		quit(1)


func _run_one(name: String, rotate: bool = false) -> Dictionary:
	var out := {"name": name, "ok": false, "cmds": 0, "cmds_done": 0, "events": 0}
	var gold: Dictionary = JsonExact.parse(FileAccess.get_file_as_string(GOLDEN + name + ".json"))
	var cmds: Array = []
	for e: Dictionary in gold["events"]:
		if e["ev"] == "cmd":
			cmds.append(e)
	out["cmds"] = cmds.size()
	var cfg := BattleScene.golden_cfg(name)
	cfg["record"] = true
	cfg["speed"] = 8.0 if rotate else _speed
	cfg["source"] = "test"
	cfg["story"] = "auto"
	BattleScene.pending = cfg
	var rotations := 0
	var misplaced := 0
	var hint_fail := 0       # 실패 안내가 제대로 남은 명령 수
	var hint_pass_over := 0  # ok=false 지만 차례가 넘어가 안내 없음이 맞은 수 (회피된 공격 등)
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	var ci := 0
	var frames := 0
	var fail := ""
	while frames < MAX_FRAMES:
		await process_frame
		frames += 1
		if scene.is_over():
			break
		if rotate:
			# 누군가 움직이는 중이면 돌림 (최대 60번)
			if rotations < 60:
				for uv: Node in scene.units.values():
					if uv.moving:
						scene.rotate_cam(1)
						rotations += 1
						break
			# 움직이지 않는 유닛은 늘 자기 칸 발 위치에
			for uv2: Node in scene.units.values():
				if not uv2.moving and not uv2.dying and uv2.position.distance_to(scene.iso.foot(int(uv2.d["x"]), int(uv2.d["y"]))) > 0.5:
					misplaced += 1
		if not scene.is_awaiting():
			continue
		# 안내 줄 검사: 앞 명령이 실패(last_result.ok=false)했고 같은 클랜원이 다시 기다리면 안내가 있어야 하고(다음 프레임에도),
		#  그 밖(정상 명령·회피된 공격처럼 차례가 넘어간 경우)엔 안내가 없어야 함
		if ci > 0 and not rotate:
			var prev: Dictionary = cmds[ci - 1]
			var want: bool = not bool(scene.last_result.get("ok", true)) and scene.awaiting_unit_id() == int(prev["u"])
			var h1: String = scene.current_hint()
			await process_frame
			var h2: String = scene.current_hint()
			if want and (h1 == "" or h2 == ""):
				fail = "명령 %d 실패 안내가 없음/사라짐 (%s → '%s' / '%s')" % [ci - 1, JSON.stringify(scene.last_result), h1, h2]
				break
			if not want and (h1 != "" or h2 != ""):
				fail = "명령 %d 뒤 불필요한 안내 '%s' (%s, 기록 ok=%s)" % [ci - 1, h1, JSON.stringify(scene.last_result), str(prev["ok"])]
				break
			if want:
				hint_fail += 1
			elif not bool(scene.last_result.get("ok", true)):
				hint_pass_over += 1
			if not scene.is_awaiting():
				continue
		if rotate:
			# 입력 대기 때: 화면 유닛 칸 = 엔진 칸
			for uv3: Node in scene.units.values():
				var eu: Variant = scene.eng.unit_by_id(uv3.id)
				if eu != null and (int(eu["x"]) != int(uv3.d["x"]) or int(eu["y"]) != int(uv3.d["y"])):
					misplaced += 1
		if ci >= cmds.size():
			fail = "명령이 모자람 (입력 대기 %d번째)" % ci
			break
		var cmd: Dictionary = cmds[ci]
		var uid: int = scene.awaiting_unit_id()
		if uid != int(cmd["u"]):
			fail = "입력 대기 유닛 %d ≠ 다음 명령 유닛 %d (명령 %d)" % [uid, int(cmd["u"]), ci]
			break
		var ok := _drive(scene, cmd)
		if not ok:
			fail = "화면 조작 실패: 명령 %d %s (모드 %s)" % [ci, JSON.stringify(cmd), scene.mode]
			break
		if bool(scene.last_result.get("ok", false)) != bool(cmd["ok"]) and cmd["op"] != "move":
			fail = "명령 %d 결과 %s ≠ 기록 ok=%s (%s)" % [ci, JSON.stringify(scene.last_result), str(cmd["ok"]), JSON.stringify(cmd)]
			break
		ci += 1
	out["cmds_done"] = ci
	if fail == "" and not scene.is_over():
		fail = "끝나지 않음 (프레임 %d)" % frames
	if fail == "" and ci != cmds.size():
		fail = "명령 %d개 중 %d개만 씀" % [cmds.size(), ci]
	if fail == "" and rotate and (misplaced > 0 or rotations < 10):
		fail = "이동 중 회전: 어긋난 프레임 %d · 회전 %d번" % [misplaced, rotations]
	if fail == "":
		fail = _compare(gold, scene)
	# 결과 화면 (승리 뒤 스토리가 있으면 대사가 끝난 다음)
	if fail == "":
		var wf := 0
		while not scene.ui.result_view.visible and wf < 3000:
			await process_frame
			wf += 1
		if not scene.ui.result_view.visible:
			fail = "결과 화면이 뜨지 않음"
		else:
			var rm: Dictionary = scene._result_model()
			if str(rm["title"]) == "" or (rm["buttons"] as Array).is_empty():
				fail = "결과 화면 내용이 비었음 %s" % str(rm)
			elif scene.result.get("result") == "win" and not (scene.result.get("rewards", {}).get("exp", []) as Array).is_empty() and (rm["exp"] as Array).is_empty():
				fail = "이긴 판인데 결과 화면에 경험치 줄이 없음"
	_story_total += scene.story_log.size()
	if not scene.story_log.is_empty():
		print("[%s] 스토리 장면 %s" % [name, ",".join(scene.story_log)])
	if hint_fail + hint_pass_over > 0:
		print("[%s] 안내 줄: 실패 안내 %d번 · 차례 넘어감(안내 없음) %d번" % [name, hint_fail, hint_pass_over])
	if rotate:
		print("[%s] 이동 중 회전 %d번 · 어긋난 프레임 %d" % [name, rotations, misplaced])
	out["events"] = (scene.eng.trace as Array).size()
	if fail != "":
		print("[%s] FAIL %s" % [name, fail])
	else:
		out["ok"] = true
	scene.queue_free()
	await process_frame
	return out


## 황금 명령 하나를 사람이 누르는 순서대로 화면 입구에 넣기
func _drive(scene: Node, cmd: Dictionary) -> bool:
	var op: String = cmd["op"]
	match op:
		"move", "shove":
			return scene.ui_action(op) and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"attack", "heal":
			return scene.ui_action("attack") and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"skill":
			if not (scene.ui_action("skill") and scene.ui_pick_skill(int(cmd["idx"]))):
				return false
			if scene.mode == "target":
				return scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
			return true
		"wait", "defend", "overwatch":
			return scene.ui_action(op) and scene.ui_pick_face(int(cmd["dx"]), int(cmd["dy"]))
		"undo":
			return scene.ui_action("undo")
		"potion":
			return scene.ui_action("item") and scene.ui_pick_item("potion", int(cmd["idx"])) and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"siege", "climb":
			if not (scene.ui_action("item") and scene.ui_pick_item("siege", int(cmd["idx"]))):
				return false
			if scene.target_op != op:
				return false
			return scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
	return false


func _compare(gold: Dictionary, scene: Node) -> String:
	var gend: Dictionary = gold["end"]
	var end: Dictionary = scene.result
	for k: String in gend.keys():
		if k == "virtualMs":
			continue
		var d := _diff(gend[k], end.get(k), "end." + k)
		if d != "":
			return d
	var gev: Array = gold["events"]
	var tr: Array = scene.eng.trace
	if gev.size() != tr.size():
		return "사건 수 기대 %d / 실제 %d" % [gev.size(), tr.size()]
	for i in gev.size():
		var a: Dictionary = gev[i]
		var b: Dictionary = tr[i]
		if a["ev"] == "cmd":
			for k2: String in ["ev", "u", "op", "ok", "idx", "rng"]:
				if a.has(k2) and (not b.has(k2) or _diff(a[k2], b[k2], "") != ""):
					return "사건 %d (cmd).%s: %s ≠ %s" % [i, k2, str(a.get(k2)), str(b.get(k2))]
			continue
		var d2 := _diff(a, b, "events[%d]" % i)
		if d2 != "":
			return d2
	return ""


func _diff(a: Variant, b: Variant, path: String) -> String:
	var ta := typeof(a)
	var tb := typeof(b)
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return "" if float(a) == float(b) else "%s: %s ≠ %s" % [path, str(a), str(b)]
	if ta == TYPE_DICTIONARY and tb == TYPE_DICTIONARY:
		var bd: Dictionary = {}
		for k: Variant in b.keys():
			bd[str(k)] = b[k]
		var ad: Dictionary = {}
		for k2: Variant in a.keys():
			ad[str(k2)] = a[k2]
		for ks: String in ad.keys():
			if CLOCK_KEYS.has(ks) and path.begins_with("end.saveAfter"):
				continue
			if not bd.has(ks):
				return "%s.%s: 실제에 없음" % [path, ks]
			var d := _diff(ad[ks], bd[ks], path + "." + ks)
			if d != "":
				return d
		for ks2: String in bd.keys():
			if not ad.has(ks2):
				return "%s.%s: 기대에 없음" % [path, ks2]
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
		return "%s: 형 %s ≠ %s (%s / %s)" % [path, type_string(ta), type_string(tb), str(a).left(60), str(b).left(60)]
	if a != b:
		return "%s: %s ≠ %s" % [path, str(a).left(100), str(b).left(100)]
	return ""


func _hint_probe() -> Dictionary:
	var out := {"name": "hint_probe", "ok": false, "cmds": 1, "cmds_done": 0, "events": 0, "ms": 0}
	var t0 := Time.get_ticks_msec()
	var cfg := BattleScene.golden_cfg("balanced_s05")
	cfg["speed"] = 0.0
	cfg["source"] = "test"
	cfg["story"] = "auto"
	BattleScene.pending = cfg
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	var fail := ""
	while not scene.is_awaiting():
		await process_frame
	var me: int = scene.awaiting_unit_id()
	var other: Variant = null
	for u: Dictionary in scene.eng.S["units"]:
		if u["team"] == "ally" and int(u["id"]) != me and float(u["hp"]) > 0.0:
			other = u
			break
	scene.ui_action("move")
	scene.ui_click_cell(int(other["x"]), int(other["y"]))
	var frames := 0
	while not scene.is_awaiting() and frames < 100:
		await process_frame
		frames += 1
	await process_frame
	await process_frame
	var h: String = scene.current_hint()
	if str(scene.last_result.get("reason")) != "move_failed" or scene.awaiting_unit_id() != me:
		fail = "move_failed 가 나지 않음 %s" % JSON.stringify(scene.last_result)
	elif h == "":
		fail = "실패 안내가 2프레임 뒤 사라짐"
	else:
		scene.ui_action("move")
		if scene.current_hint() == str(h):
			fail = "다음 조작 뒤에도 실패 안내가 남음"
		out["cmds_done"] = 1
	print("[hint_probe] 실패 안내 '%s'" % h)
	if fail != "":
		print("[hint_probe] FAIL " + fail)
	else:
		out["ok"] = true
	out["ms"] = Time.get_ticks_msec() - t0
	scene.queue_free()
	await process_frame
	return out
