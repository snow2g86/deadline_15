extends SceneTree
## 전투 UI 도입 1~4 시험 (머리 없이):
##   Godot --headless --path godot --script res://tests/check_battle_ui_adopt.gd
##  A) 엔진: 이동 → 이동 취소(undo) 뒤 상태가 이동 전과 같고(난수·유닛·전투 상태), 같은 행동을 다시 하면 처음부터 바로 한 것과 결과가 같음
##  B) 도입 1 순서 바 ↔ 맵 상호 강조 · 팀 색 · 한도 넘으면 '+N명' · 라운드 구분선
##  C) 도입 2 이동 취소 단추·취소 불가 규칙 · 턴 종료(대기) 확인 흐름
##  D) 도입 3 접힘 패널 값 = battle_query 값 · 유리/불리/보통 · 약점 · 엔진 상태 불변
##  E) 도입 4 적 범위 켜기/끄기 · 우선순위 · 전체 위협과 별도
##  저장은 user://test_battle_ui_adopt_save.json

const BattleScene := preload("res://scripts/battle/battle_scene.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")
const BattleEngine := preload("res://scripts/logic/battle/battle_engine.gd")
const Js := preload("res://scripts/logic/js.gd")
const MobileT := preload("res://scripts/core/mobile.gd")
const SCENE := "res://scenes/battle/battle.tscn"
const SAVE := "user://test_battle_ui_adopt_save.json"
const SCENARIOS := ["balanced_s05", "legion5_s09", "swamp_s21", "assassins_s06", "gear_s15"]

var _fails: Array = []
var _passes := 0
var _counter: ErrCounter
var _globals: Dictionary


class ErrCounter extends Logger:
	var errors: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	# 지금 데이터(godot/data) 그대로 — 새 번역 키 gd.adopt.* 는 기준 사본(tests/baseline)에 없음. 수치는 기준과 같음
	_counter = ErrCounter.new()
	OS.add_logger(_counter)
	_main.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
		print("  PASS  " + what)
	else:
		_fails.append(what)
		print("  FAIL  " + what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, secs: float = 6.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await process_frame
	return cond.call()


func _main() -> void:
	print("── 전투 UI 도입 1~4 시험 ──")
	var db: Node = root.get_node("DataDB")
	_globals = Ctx.globals_from_db(db)
	_engine_undo()
	await _scene_part()
	await _layout_part()
	await _touch_part()
	_check(_counter.errors.is_empty(), "Godot 오류 0 %s" % str(_counter.errors.slice(0, 3)))
	print("──────────────────────────────")
	if _fails.is_empty():
		print("RESULT: PASS (%d개 통과)" % _passes)
		quit(0)
	else:
		print("RESULT: FAIL (%d개 실패 / %d개 통과)" % [_fails.size(), _passes])
		quit(1)


# ═══════════ A) 엔진: 이동 취소 뒤 상태 동일 ═══════════

func _gold(name: String) -> Dictionary:
	return JsonExact.parse(FileAccess.get_file_as_string("res://tests/golden/%s.json" % name))


func _make(name: String) -> Array:
	var g := _gold(name)
	var sc: Dictionary = g["scenario"]
	var eng := BattleEngine.new(_globals, int(sc["seed"]))
	eng.start({"save": g["save"], "stage": sc["stage"], "practice": sc["practice"], "inject": g["setup"]["inject"], "maxRounds": int(sc["maxRounds"])})
	var cmds: Array = []
	for e: Dictionary in g["events"]:
		if e["ev"] == "cmd":
			cmds.append(e)
	return [eng, cmds]


## 엔진 상태 지문 — 기록(trace)·시각(now_ms)·순번(seq) 같은 '기록기' 값은 뺌 (취소 명령 자체가 기록에 남는 것은 정상)
func _state_fp(eng: Object) -> String:
	var d: Dictionary = eng.save_state()
	d.erase("seq")
	d.erase("now_ms")
	return JsonExact.stringify(d)


func _engine_undo() -> void:
	print("[A) 엔진: 이동 → 이동 취소(저장 되돌리기) → 같은 행동]")
	var tested := 0
	var same_after_undo := 0
	var same_after_replay := 0
	var rng_same := 0
	var web_undo_diff := 0
	var web_undo_n := 0
	for name: String in SCENARIOS:
		var a := _make(name)
		var b := _make(name)
		var ea: Object = a[0]
		var eb: Object = b[0]
		ea.record_enabled = false
		eb.record_enabled = false
		var cmds: Array = a[1]
		ea.begin()
		eb.begin()
		var sa: String = ea.run()
		var sb: String = eb.run()
		var ci := 0
		while sa == "input" and sb == "input" and ci < cmds.size() and tested < 80:
			var cmd: Dictionary = cmds[ci]
			var ub: Dictionary = eb.awaiting_unit()
			var cells: Array = eb.q.move_cells(ub)
			var did := false
			if not cells.is_empty() and ub["team"] == "ally" and cmd["op"] != "undo" and cmd["op"] != "move" and eb.can_save():
				var cell: Dictionary = cells[0]
				var pre_fp := _state_fp(eb)
				var snap: Dictionary = eb.save_state()
				var rng0: int = eb.c.rng.calls
				var rs0: Variant = eb.c.rng.get_state()
				var r1: Dictionary = eb.command({"op": "move", "x": cell["x"], "y": cell["y"]})
				sb = eb.run()
				if bool(r1["ok"]) and eb.q.can_undo():
					# (참고) 엔진의 기존 undo 명령은 방향·이동 거리를 못 돌림 — 기록용 집계만 (복사본 엔진 불필요: 상태 지문만 비교하고 되돌림)
					web_undo_n += 1
					if not eb.load_state(snap):
						_check(false, "load_state 실패")
						return
					sb = "input"
					tested += 1
					did = true
					var post_fp := _state_fp(eb)
					if post_fp == pre_fp:
						same_after_undo += 1
					else:
						_diff_report(pre_fp, post_fp, name)
					if eb.c.rng.calls == rng0 and eb.c.rng.get_state() == rs0:
						rng_same += 1
				else:
					eb.load_state(snap)
					sb = "input"
			# 같은 명령 (A 는 곧바로, B 는 이동→취소를 거친 뒤)
			var okA: Dictionary = ea.command(cmd)
			var okB: Dictionary = eb.command(cmd)
			sa = ea.run()
			sb = eb.run()
			if did:
				if bool(okA["ok"]) == bool(okB["ok"]) and _state_fp(ea) == _state_fp(eb):
					same_after_replay += 1
				else:
					print("    · %s 명령 %d: 취소 뒤 같은 행동 결과가 다름" % [name, ci])
			ci += 1
	# 참고: 엔진 undo 명령 (웹 그대로 — 골든 firstclear_s02 가 씀) 이 이동 전과 다른 점
	var wa := _make("legion5_s09")
	var we: Object = wa[0]
	we.record_enabled = false
	we.begin()
	var ws: String = we.run()
	var wn := 0
	while ws == "input" and wn < 12:
		var wu: Dictionary = we.awaiting_unit()
		var wc: Array = we.q.move_cells(wu)
		if not wc.is_empty() and wu["team"] == "ally":
			var before := _state_fp(we)
			we.command({"op": "move", "x": wc[0]["x"], "y": wc[0]["y"]})
			ws = we.run()
			we.command({"op": "undo"})
			ws = we.run()
			wn += 1
			if _state_fp(we) != before:
				web_undo_diff += 1
		we.command({"op": "wait", "dx": 0, "dy": 1})
		ws = we.run()
	print("    · 참고: 엔진 undo 명령은 이동 전과 %d/%d번 다름 (방향 _gdx·_gdy, 이동 거리 _movedDist — 웹 그대로라 규칙은 안 바꿈)" % [web_undo_diff, wn])
	_check(tested >= 20, "이동 → 취소를 %d번 시도 (장면 5개)" % tested)
	_check(same_after_undo == tested, "이동 → 취소(상태 되돌리기) 뒤 전투 상태(유닛·난수·전투 변수·저장소)가 이동 전과 같음 %d/%d" % [same_after_undo, tested])
	_check(rng_same == tested, "난수 호출 수·상태 복원 %d/%d" % [rng_same, tested])
	_check(same_after_replay == tested, "취소 뒤 같은 행동 재실행 결과 = 곧바로 한 것과 같음 %d/%d" % [same_after_replay, tested])


func _diff_report(a: String, b: String, name: String) -> void:
	var da: Dictionary = JsonExact.parse(a)
	var db_: Dictionary = JsonExact.parse(b)
	for k: String in da.keys():
		if JsonExact.stringify(da[k]) != JsonExact.stringify(db_.get(k)):
			print("    · %s: 달라진 키 %s" % [name, k])
			if k == "units":
				var ua: Array = da[k]
				var ub2: Array = db_[k]
				for i in ua.size():
					for k3: String in (ua[i] as Dictionary).keys():
						if JsonExact.stringify(ua[i][k3]) != JsonExact.stringify(ub2[i].get(k3)):
							print("        unit %s.%s: %s → %s" % [ua[i]["id"], k3, JsonExact.stringify(ua[i][k3]), JsonExact.stringify(ub2[i].get(k3))])
					for k4: String in (ub2[i] as Dictionary).keys():
						if not (ua[i] as Dictionary).has(k4):
							print("        unit %s.%s 새로 생김: %s" % [ua[i]["id"], k4, JsonExact.stringify(ub2[i][k4])])
			if k == "S":
				for k2: String in (da[k] as Dictionary).keys():
					if JsonExact.stringify(da[k][k2]) != JsonExact.stringify(db_[k].get(k2)):
						print("        S.%s" % k2)
			break


# ═══════════ B~E) 장면 ═══════════

func _drive(sc: Node, cmd: Dictionary) -> void:
	var op: String = cmd["op"]
	match op:
		"move", "shove":
			sc.ui_action(op)
			sc.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"attack", "heal":
			sc.ui_action("attack")
			sc.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"skill":
			sc.ui_action("skill")
			sc.ui_pick_skill(int(cmd["idx"]))
			if sc.mode == "target":
				sc.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"wait", "defend", "overwatch":
			sc.ui_action(op)
			sc.ui_pick_face(int(cmd["dx"]), int(cmd["dy"]))
		"undo":
			sc.ui_action("undo")
		"potion":
			sc.ui_action("item")
			sc.ui_pick_item("potion", int(cmd["idx"]))
			sc.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"siege", "climb":
			sc.ui_action("item")
			sc.ui_pick_item("siege", int(cmd["idx"]))
			sc.ui_click_cell(int(cmd["x"]), int(cmd["y"]))


func _wait_menu(sc: Node) -> void:
	await _until(func() -> bool: return sc.is_awaiting() or sc.is_over(), 10.0)
	await _frames(2)


func _scene_part() -> void:
	var store: Node = root.get_node("Store")
	store.call("use_path", SAVE)
	store.call("clear")
	root.get_node("I18n").call("reload")
	var cfg := BattleScene.golden_cfg("legion5_s09")
	cfg["speed"] = 0.0
	cfg["source"] = "test"
	cfg["story"] = "off"
	BattleScene.pending = cfg
	var sc: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	await _wait_menu(sc)
	await _frames(5)
	var ui: Node = sc.ui
	var cmds: Array = []
	for e: Dictionary in _gold("legion5_s09")["events"]:
		if e["ev"] == "cmd":
			cmds.append(e)

	# 공격 대상이 생길 때까지 황금 기록 명령을 따라감 (이 사이 여러 클랜원이 움직여 적이 보이게 됨)
	var ci := 0
	while ci < 40 and ci < cmds.size():
		var uu: Variant = sc.eng.awaiting_unit()
		if uu != null and uu["team"] == "ally" and not (sc.eng.q.attack_targets(uu)["attack"] as Array).is_empty():
			break
		_drive(sc, cmds[ci])
		ci += 1
		await _wait_menu(sc)
	var u: Dictionary = sc.eng.awaiting_unit()
	_check(u != null and not (sc.eng.q.attack_targets(u)["attack"] as Array).is_empty(), "공격 가능한 대상이 있는 입력 대기까지 진행 (명령 %d개)" % ci)

	# ── B) 도입 1 ──
	print("[B) 순서 바 ↔ 맵 상호 강조]")
	var enemy_id := -1
	var ally_other := -1
	for uv: Node in sc.units.values():
		if uv.d["team"] == "enemy" and uv.visible and enemy_id < 0:
			enemy_id = uv.id
		if uv.d["team"] == "ally" and uv.id != sc.awaiting_unit_id() and ally_other < 0:
			ally_other = uv.id
	_check(enemy_id >= 0 and ally_other >= 0, "보이는 적 · 다른 클랜원 있음")
	ui.order.unit_clicked.emit(enemy_id)
	await _frames(2)
	_check(sc.focus_id == enemy_id and sc.units[enemy_id].focus, "순서 바에서 적을 누름 → 맵 유닛 하이라이트 링")
	var row_e: Object = ui.order.row_of(enemy_id)
	_check(row_e != null and row_e.focus, "순서 바 그 줄 강조 (흰 테두리)")
	_check(row_e != null and row_e.tc.is_equal_approx(Color("ef4444")), "적 줄 팀 색 = 빨강")
	var row_a: Object = ui.order.row_of(ally_other)
	_check(row_a != null and row_a.tc.is_equal_approx(Color("3b82f6")), "아군 줄 팀 색 = 파랑")
	ui.cards.unit_clicked.emit(ally_other)
	await _frames(2)
	_check(sc.focus_id == ally_other and sc.units[ally_other].focus and not sc.units[enemy_id].focus, "카드 탭 → 맵 링이 그 클랜원으로 (이전 것은 꺼짐)")
	_check(ui.cards.focus_id == ally_other and ui.order.row_of(ally_other).focus, "카드 · 순서 바 같이 강조")
	_check(not ui.order.row_of(enemy_id).focus, "이전 줄 강조 해제")
	# 맵에서 유닛 탭 → 순서 바 강조 (실제 _click 경로)
	sc.set_focus(-1)
	await _frames(2)
	_check(not ui.order.row_of(enemy_id).focus, "해제하면 줄 강조 없음")
	var tap_p: Vector2 = (sc.units[ally_other] as Node2D).position + Vector2(0, -20)
	sc.mode = "menu"
	sc._click(tap_p)
	await _frames(2)
	_check(sc.focus_id == ally_other and ui.order.row_of(ally_other).focus, "맵에서 클랜원을 탭 → 순서 바 그 줄 강조")
	sc._click(Vector2(-9000, -9000))
	await _frames(2)
	_check(sc.focus_id == -1 and not ui.order.row_of(ally_other).focus, "빈 곳을 탭 → 강조 해제")
	# 카메라: 화면 가운데 근처면 안 움직임
	sc.cam.position = (sc.units[ally_other] as Node2D).position + Vector2(0, -20)
	sc.cam.force_update_scroll()
	var cp: Vector2 = sc.cam.position
	sc._ensure_visible((sc.units[ally_other] as Node2D).position + Vector2(0, -20))
	await _frames(3)
	_check(sc.cam.position.distance_to(cp) < 0.5, "이미 화면 가운데 근처면 카메라를 옮기지 않음 (링만)")
	# 한도 넘으면 +N명
	var total: int = ui.order._last_rows.size()
	ui.order.max_rows = 3
	ui.order._sig = ""
	sc._refresh_hud()
	await _frames(2)
	_check(ui.order.hidden_count == total - 3 and ui.order._more.visible and ui.order._more_lbl.text.contains(str(total - 3)), "표시 한도 3 → '+%d명' 칩 (%s)" % [total - 3, ui.order._more_lbl.text])
	_check(ui.order._more.custom_minimum_size.y >= 44.0, "'+N명' 칩 터치 영역 44 이상")
	ui.order._more.gui_input.emit(_left_click())
	await _frames(2)
	_check(ui.order.expanded and ui.order.hidden_count == 0 and ui.order.shown_count == total, "'+N명' 탭 → 전부 펼침 (%d줄)" % total)
	ui.order._more.gui_input.emit(_left_click())
	await _frames(2)
	_check(not ui.order.expanded and ui.order.hidden_count == total - 3, "다시 탭 → 접힘")
	ui.order.max_rows = 99
	ui.order.expanded = false
	ui.order._sig = ""
	sc._refresh_hud()
	# 라운드 구분선
	var fake: Array = []
	for i in 4:
		fake.append({"id": 900 + i, "team": "ally" if i % 2 == 0 else "enemy", "boss": false, "cur": i == 0, "name": "t%d" % i, "tip": "", "hp_ratio": 1.0, "ap_ratio": 0.5,
			"eta": "1.0", "ready": false, "tex": null, "summon": false, "round2": i >= 2})
	ui.order._sig = ""
	ui.order.update(fake)
	_check(ui.order.divider_before == 2 and ui.order._div.visible, "라운드 구분선이 3번째 줄 앞에 (round2 첫 줄)")
	ui.order.update(fake.map(func(m: Dictionary) -> Dictionary:
		var c := m.duplicate()
		c["round2"] = false
		return c))
	_check(not ui.order._div.visible, "다음 라운드 유닛이 없으면 구분선 없음")
	ui.order._sig = ""
	sc._refresh_hud()

	# ── C) 도입 2 ──
	print("[C) 이동 취소 · 턴 종료 확인]")
	u = sc.eng.awaiting_unit()
	var acted: bool = Js.truthy(u.get("ha")) or Js.truthy(u.get("hm"))
	if acted:
		sc.ui_action("wait")
		sc.ui_pick_face(0, 0)
		await _wait_menu(sc)
		u = sc.eng.awaiting_unit()
	var fp_before: String = sc.eng.save_text()
	var n_un: int = sc.unacted_allies()
	_check(n_un >= 1, "행동하지 않은 클랜원 수 %d (이 클랜원 포함)" % n_un)
	var ec0: int = sc.end_confirms
	sc._user_action("wait")
	await _frames(2)
	_check(ui.end_confirm_open() and sc.end_confirms == ec0 + 1 and sc.mode == "menu", "이동·행동 없이 대기 → 확인 창 (아직 턴은 그대로)")
	_check(ui.end_msg.text.contains(str(n_un)), "확인 문구에 인원 %d 포함: %s" % [n_un, ui.end_msg.text])
	_check(sc.eng.save_text() == fp_before, "확인 창이 떠 있는 동안 엔진 상태 불변")
	_check(ui.end_yes.custom_minimum_size.y >= 44.0 and ui.end_no.custom_minimum_size.y >= 44.0, "확인 단추 터치 44 이상")
	# 회귀: 확인창이 열린 동안 Space·중복 호출은 무시, Esc·뒤로가기·우클릭은 '돌아가기'
	var ec1: int = sc.end_confirms
	sc._user_action("wait")
	sc._unhandled_input(_key_ev(KEY_SPACE))
	sc._unhandled_input(_key_ev(KEY_W))
	await _frames(1)
	_check(ui.end_confirm_open() and sc.end_confirms == ec1 and sc.mode == "menu", "확인창 중 Space·W·중복 호출 무시 (end_confirms 그대로 %d)" % ec1)
	sc._unhandled_input(_key_ev(KEY_ESCAPE))
	await _frames(2)
	_check(not ui.end_confirm_open() and ui.menu.visible and sc.mode == "menu", "확인창 중 Esc → 돌아가기 (뒤쪽 취소·설정 안 열림)")
	_check(not ui.settings.is_open(), "Esc 로 설정 창이 안 열림")
	sc._user_action("wait")
	await _frames(1)
	sc.on_system_back()
	await _frames(2)
	_check(not ui.end_confirm_open() and sc.mode == "menu" and not ui.settings.is_open(), "확인창 중 안드로이드 뒤로가기 → 돌아가기 (설정 안 열림)")
	sc._user_action("wait")
	await _frames(1)
	var rc := InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.pressed = true
	sc._unhandled_input(rc)
	await _frames(2)
	_check(not ui.end_confirm_open() and sc.mode == "menu", "확인창 중 우클릭 → 돌아가기")
	sc._user_action("wait")
	await _frames(2)
	ui.end_no.pressed.emit()
	await _frames(2)
	_check(not ui.end_confirm_open() and ui.menu.visible and sc.mode == "menu", "돌아가기 → 확인 창 닫힘 · 행동 메뉴 그대로")
	sc._user_action("wait")
	await _frames(2)
	ui.end_yes.pressed.emit()
	ui.end_yes.pressed.emit()   # 같은 프레임 두 번 → 한 번만
	await _frames(2)
	_check(not ui.end_confirm_open() and sc.mode == "face", "한 번 더 눌러(턴 종료) → 방향 고르기로 (대기 진행)")
	sc.ui_cancel()
	await _frames(2)
	_check(sc.mode == "menu", "방향 고르기 취소 → 메뉴")
	# 이동 취소
	u = sc.eng.awaiting_unit()
	var cells: Array = sc.eng.q.move_cells(u)
	_check(not cells.is_empty(), "이동 가능한 칸 있음")
	var x0 := int(u["x"])
	var y0 := int(u["y"])
	var move_cell: Dictionary = cells[0]
	var fp_pre_move := _state_fp(sc.eng)
	var exact0: int = sc.undo_exact_count
	sc.ui_action("move")
	sc.ui_click_cell(int(move_cell["x"]), int(move_cell["y"]))
	await _wait_menu(sc)
	var ub: Dictionary = _undo_button(ui)
	_check(not ub.is_empty(), "이동 직후 메뉴 맨 아래에 '이동 취소' 단추")
	if not ub.is_empty():
		var btn: Button = ub["button"]
		_check(btn.get_index() == btn.get_parent().get_child_count() - 1, "'이동 취소' 가 메뉴 마지막")
		_check(str(ub["item"]["label"]) == str(root.get_node("I18n").call("t", "gd.adopt.undo_move")), "라벨 = gd.adopt.undo_move")
	if sc.undo_block == "":
		sc.ui_action("undo")
		await _wait_menu(sc)
		u = sc.eng.awaiting_unit()
		_check(int(u["x"]) == x0 and int(u["y"]) == y0 and not Js.truthy(u.get("hm")), "이동 취소 → 이동 전 위치 (%d,%d)·이동력 복원" % [x0, y0])
		_check(_undo_button(ui).is_empty(), "취소한 뒤에는 '이동 취소' 단추 없음")
		_check(sc.undo_exact_count == exact0 + 1, "장면의 이동 취소는 상태 되돌리기(load_state) 경로")
		_check(_state_fp(sc.eng) == fp_pre_move, "장면 이동 취소 뒤 엔진 상태(난수·방향·이동 거리 포함)가 이동 전과 완전히 같음")
	else:
		print("    (이 이동은 취소 불가 규칙 %s 에 걸림 — 아래 규칙 시험으로 대체)" % sc.undo_block)
		sc.undo_block = ""
		sc.ui_action("undo")
		await _wait_menu(sc)
	# 취소 불가 규칙 (reveal: 이동으로 새 적이 시야에 들어옴 · event: HP 변화)
	u = sc.eng.awaiting_unit()
	var cells2: Array = sc.eng.q.move_cells(u)
	sc.ui_action("move")
	sc.ui_click_cell(int(cells2[0]["x"]), int(cells2[0]["y"]))
	await _wait_menu(sc)
	u = sc.eng.awaiting_unit()
	if sc.eng.q.can_undo():
		sc.undo_block = ""
		sc._mv_snap = {"uid": int(u["id"]), "vis_enemies": [], "hp": float(u["hp"]), "buffs": (u["buffs"] as Array).size(), "chests": sc.view_chests.size()}
		var any_vis: bool = not sc._visible_enemy_ids().is_empty()
		sc._eval_undo_block(u)
		_check(sc.undo_block == ("reveal" if any_vis else ""), "이전에 안 보이던 적이 보이게 되면 '이동 취소' 불가 (reveal)")
		sc._mv_snap = {"uid": int(u["id"]), "vis_enemies": sc._visible_enemy_ids(), "hp": float(u["hp"]) + 5.0, "buffs": (u["buffs"] as Array).size(), "chests": sc.view_chests.size()}
		sc._eval_undo_block(u)
		_check(sc.undo_block == "event", "이동 중 HP·상태·상자가 바뀌면 불가 (event)")
		sc._show_main_menu(u)
		var ub2: Dictionary = _undo_button(ui)
		_check(not ub2.is_empty() and (ub2["button"] as Button).disabled and str(ub2["item"]["sub"]) != "", "불가일 때 꺼진 단추 + 이유 글")
		var xy := [int(u["x"]), int(u["y"])]
		sc.ui_cancel()
		await _frames(2)
		_check(int(sc.eng.awaiting_unit()["x"]) == xy[0] and int(sc.eng.awaiting_unit()["y"]) == xy[1], "불가일 때 Esc(ui_cancel)로도 취소되지 않음")
		sc.undo_block = ""
		sc.ui_action("undo")
		await _wait_menu(sc)
	else:
		print("    (취소 규칙 시험: 이 이동은 이미 취소 불가)")
	_check(sc.ui_action("wait") and sc.mode == "face", "시험·자동 재생 입구 ui_action(wait) 는 확인 없이 바로 진행")
	sc.ui_cancel()
	await _frames(2)

	# ── D) 도입 3 ──
	print("[D) 접힘 패널 값 = battle_query]")
	var guard := 0
	while guard < 30 and ci < cmds.size():
		var uq: Variant = sc.eng.awaiting_unit()
		if uq != null and uq["team"] == "ally" and not (sc.eng.q.attack_targets(uq)["attack"] as Array).is_empty() and sc.mode == "menu":
			break
		_drive(sc, cmds[ci])
		ci += 1
		guard += 1
		await _wait_menu(sc)
	u = sc.eng.awaiting_unit()
	var at: Dictionary = sc.eng.q.attack_targets(u)
	_check(not (at["attack"] as Array).is_empty(), "공격 대상 있음")
	var fp_eng: String = sc.eng.save_text()
	sc.ui_action("attack")
	await _frames(3)
	_check(sc.eng.save_text() == fp_eng, "공격 대상 고르기·미리보기 계산이 엔진 상태(난수 포함)를 안 바꿈")
	_check(ui.calc_panel.visible and not ui.calc_scroll.visible, "기본: 접힘 패널은 단추만 (계산 내역은 접힘)")
	_check(ui.calc_btn.custom_minimum_size.y >= 44.0, "접힘 단추 터치 44 이상")
	_check(not sc.fx.preview_detail, "기본: 예상 상자는 숫자 + 유리/불리 마크만")
	ui.calc_btn.pressed.emit()
	await _frames(2)
	_check(ui.calc_open and ui.calc_scroll.visible and sc.fx.preview_detail, "탭 → 펼침 · 예상 상자에 계산 한 줄도 보임")
	var joined := "\n".join(_all_label_texts(ui.calc_box))
	var checked := 0
	var marks_ok := 0
	var weak_ok := 0
	for c: Dictionary in at["attack"]:
		var t: Variant = null
		for w: Dictionary in sc.eng.S["units"]:
			if float(w["hp"]) > 0.0 and int(w["x"]) == int(c["x"]) and int(w["y"]) == int(c["y"]):
				t = w
		if t == null:
			continue
		var p: Dictionary = sc.eng.q.preview_attack(u, t, true)
		if p["intercept"] != null:
			continue
		var pr: Dictionary = sc.eng.q.preview_parts(u, t)
		var dmg_txt: String = sc._num(p["dmg"])
		checked += 1
		_check(joined.contains("-" + dmg_txt), "대상 %s: 패널 예상 피해 -%s = preview_attack" % [t["id"], dmg_txt])
		_check(joined.contains(sc._num(pr["atk"])) and joined.contains(sc._num(pr["def"])) and joined.contains(sc._num(pr["base"])), "대상 %s: 공격 %s · 방어 %s · 기본 %s = preview_parts" % [t["id"], sc._num(pr["atk"]), sc._num(pr["def"]), sc._num(pr["base"])])
		_check(float(pr["base"]) == maxf(1.0, float(pr["atk"]) - float(pr["def"])), "기본 피해 = max(1, 공격 − 방어)")
		var verdict: String = sc.preview_verdict(p)
		var should_adv: bool = float(p["pct"]) > 0.0 or bool(p["shallow"])
		var should_dis: bool = bool(p["shield"]) or float(p["evade"]) > 0.0 or bool(p["evade_buff"])
		if (verdict == "adv" and should_adv and not should_dis) or (verdict == "dis" and should_dis and not should_adv) or (verdict == "even" and (should_adv == should_dis)):
			marks_ok += 1
		var wk: bool = sc.preview_weak(p)
		if (sc.units[int(t["id"])] as Node).weak == wk:
			weak_ok += 1
	_check(checked >= 1 and marks_ok == checked, "유리/불리/보통 마크가 preview_attack 값(전술 보정·방어막·회피·여울)과 일치 %d/%d" % [marks_ok, checked])
	_check(weak_ok >= checked, "약점(여울·등 뒤)인 대상만 체력바 번쩍임")
	var pv_marks := 0
	for pv: Dictionary in sc.fx.previews:
		if str(pv.get("mark_text", "")) != "" or str(pv["kind"]) == "block":
			pv_marks += 1
	_check(pv_marks == sc.fx.previews.size() and not sc.fx.previews.is_empty(), "예상 상자마다 마크 있음")
	var any_uv: Node = sc.units[int(u["id"])]
	any_uv.weak = true
	_check(any_uv.weak, "UnitView.weak 켜짐 (체력바 번쩍임)")
	any_uv.weak = false
	sc.ui_cancel()
	await _frames(2)
	_check(not ui.calc_panel.visible and sc.fx.previews.is_empty(), "공격 고르기 취소 → 패널·예상 상자 사라짐")
	ui.set_calc_open(false)

	# ── E) 도입 4 ──
	print("[E) 적 범위 표시]")
	enemy_id = -1
	for uv2: Node in sc.units.values():
		if uv2.d["team"] == "enemy" and uv2.visible and enemy_id < 0:
			enemy_id = uv2.id
	_check(enemy_id >= 0, "보이는 적 있음")
	var eu: Dictionary = sc.eng.unit_by_id(enemy_id)
	var rg: Dictionary = sc.eng.q.enemy_range(eu)
	sc.mode = "menu"
	sc.toggle_enemy_range(enemy_id)
	var n_a := 0
	var n_m := 0
	for k: String in sc.map.erange.keys():
		var v: String = sc.map.erange[k]
		n_a += 1 if v.contains("a") else 0
		n_m += 1 if v.contains("m") else 0
	_check(sc.enemy_range_id == enemy_id and n_a == (rg["attack"] as Array).size() and n_m == (rg["move"] as Array).size() and n_m > 0, "적을 켬 → 이동 %d칸(파랑)·공격 %d칸(빨강) = enemy_range" % [n_m, n_a])
	sc.toggle_enemy_range(enemy_id)
	_check(sc.enemy_range_id == -1 and sc.map.erange.is_empty(), "같은 적 다시 → 해제")
	var ep: Vector2 = (sc.units[enemy_id] as Node2D).position + Vector2(0, -20)
	sc._click(ep)
	await _frames(2)
	_check(sc.enemy_range_id == enemy_id and sc.focus_id == enemy_id and not sc.map.erange.is_empty(), "적 탭 → 범위 + 링 + 순서 바 강조")
	_check(ui.info.popup.visible, "켤 때 정보 팝업도 같이")
	sc._click(ep)
	await _frames(2)
	_check(sc.enemy_range_id == -1 and sc.map.erange.is_empty(), "다시 탭 → 해제")
	sc._click(ep)
	var uA: Dictionary = sc.eng.awaiting_unit()
	if not (sc.eng.q.attack_targets(uA)["attack"] as Array).is_empty():
		sc.ui_action("attack")
		await _frames(2)
		_check(sc.enemy_range_id == enemy_id and sc.map.erange.is_empty(), "우선순위: 공격 대상 고르는 중에는 적 범위를 숨김 (선택 유지)")
		sc.ui_cancel()
		await _frames(2)
		_check(sc.enemy_range_id == enemy_id and not sc.map.erange.is_empty(), "고르기에서 돌아오면 다시 표시")
	sc.toggle_threat()
	_check(not sc.map.threat.is_empty() and not sc.map.erange.is_empty(), "전체 위협 켜도 개별 범위는 따로 유지 (다른 층)")
	var thr_n: int = sc.map.threat.size()
	sc.toggle_enemy_range(enemy_id)
	_check(sc.map.threat.size() == thr_n and sc.map.erange.is_empty(), "개별 범위를 꺼도 전체 위협은 그대로")
	sc.toggle_threat()
	sc.toggle_enemy_range(enemy_id)
	sc._send({"op": "wait", "dx": 0, "dy": 1})
	_check(sc.enemy_range_id == -1 and sc.map.erange.is_empty(), "명령을 내리면(상태 변화) 적 범위 해제")
	await _wait_menu(sc)
	sc.queue_free()
	await _frames(3)


func _key_ev(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	return e


func _left_click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


func _undo_button(ui: Node) -> Dictionary:
	for mb: Dictionary in ui.menu_buttons:
		if mb["op"] == "undo":
			return mb
	return {}


func _all_label_texts(n: Node) -> Array:
	var out: Array = []
	for c: Node in n.get_children():
		if c is Label:
			out.append((c as Label).text)
		out.append_array(_all_label_texts(c))
	return out


# ═══════════ F) 터치 (pixel8 흉내) ═══════════

func _win(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _touch_ev(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = _win(pos)
	e.pressed = pressed
	Input.parse_input_event(e)


## 손가락 탭 (논리 좌표) — 눌렀다 떼기
func _tap(pos: Vector2) -> void:
	_touch_ev(0, pos, true)
	await _frames(2)
	_touch_ev(0, pos, false)
	await _frames(3)


func _touch_part() -> void:
	print("[F) 터치 — pixel8 흉내]")
	var plat: Node = root.get_node("Platform")
	var mob: Node = root.get_node("Mobile")
	plat.call("emulate_mobile", true, "pixel8")
	root.size = MobileT.DEVICES["pixel8"]["size"]
	mob.call("apply")
	await _frames(3)
	var cfg := BattleScene.golden_cfg("legion5_s09")
	cfg["speed"] = 0.0
	cfg["source"] = "test"
	cfg["story"] = "off"
	cfg["loading"] = false
	BattleScene.pending = cfg
	var sc: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	await _wait_menu(sc)
	await _frames(5)
	var ui: Node = sc.ui
	var cmds: Array = []
	for e: Dictionary in _gold("legion5_s09")["events"]:
		if e["ev"] == "cmd":
			cmds.append(e)
	var ci := 0
	while ci < 40 and ci < cmds.size():
		var uu: Variant = sc.eng.awaiting_unit()
		if uu != null and uu["team"] == "ally" and not (sc.eng.q.attack_targets(uu)["attack"] as Array).is_empty():
			break
		_drive(sc, cmds[ci])
		ci += 1
		await _wait_menu(sc)
	var tmin: float = mob.call("min_target")
	print("    · 논리 화면 %s · 터치 최소 %.1f px (44pt)" % [str(root.get_visible_rect().size), tmin])
	_check(ui.cards.compact, "낮은 화면(논리 높이 %d) → 클랜원 패널이 얇은 아이콘형으로 자동 접힘" % int(root.get_visible_rect().size.y))
	var small: Array = []
	for c: Node in ui.cards.row.get_children():
		if (c as Control).visible and (c as Control).size.y < tmin - 0.5:
			small.append(c.name)
	_check(small.is_empty(), "클랜원 카드 높이 모두 ≥ 44pt (%.1f px)" % tmin)
	var small_rows: Array = []
	for r: Node in ui.order.get_children():
		if r is PanelContainer and (r as Control).visible and (r as Control).size.y < tmin - 0.5:
			small_rows.append(r.name)
	_check(small_rows.is_empty(), "순서 바 줄 높이 모두 ≥ 44pt")
	# 끌기로 스크롤: 카드 위에서 문턱보다 크게 끌면 패널이 스크롤되고 카드는 안 눌림 (탭으로 안 셈)
	var cs: ScrollContainer = ui.cards.scroll
	var overflow: bool = ui.cards.col.size.y > cs.size.y + 2.0
	print("    · 카드 목록 %.0f px / 패널 %.0f px (넘침 %s)" % [ui.cards.col.size.y, cs.size.y, str(overflow)])
	if overflow:
		var c0: Control = null
		for c3: Node in ui.cards.row.get_children():
			if (c3 as Control).visible:
				c0 = c3
				break
		var f0: int = sc.focus_id
		var p0: Vector2 = c0.get_global_rect().get_center()
		var sv0: int = cs.scroll_vertical
		_touch_ev(0, p0, true)
		await _frames(1)
		for i in 8:
			var dp := Vector2(0, -12.0 * (i + 1))
			var de := InputEventScreenDrag.new()
			de.index = 0
			de.position = _win(p0 + dp)
			de.relative = root.get_final_transform().basis_xform(Vector2(0, -12))
			Input.parse_input_event(de)
			await _frames(1)
		_touch_ev(0, p0 + Vector2(0, -96), false)
		await _frames(3)
		_check(cs.scroll_vertical > sv0, "카드를 끌면 패널이 스크롤됨 (%d → %d)" % [sv0, cs.scroll_vertical])
		_check(sc.focus_id == f0, "끌기는 탭으로 안 셈 (강조 그대로)")
		cs.scroll_vertical = 0
		await _frames(2)
	# 맵의 적 탭 → 범위
	var enemy_id := -1
	for uv: Node in sc.units.values():
		if uv.d["team"] == "enemy" and uv.visible and enemy_id < 0:
			enemy_id = uv.id
	_check(enemy_id >= 0, "보이는 적")
	sc.cam.position = (sc.units[enemy_id] as Node2D).position + Vector2(0, -20)
	sc.cam.force_update_scroll()
	await _frames(3)
	ui.hide_menu()   # 행동 메뉴가 그 자리를 덮고 있으면 메뉴가 눌림 — 치우고 맵을 탭
	var sp: Vector2 = sc.get_viewport().get_canvas_transform() * ((sc.units[enemy_id] as Node2D).position + Vector2(0, -20))
	await _tap(sp)
	_check(sc.enemy_range_id == enemy_id and not sc.map.erange.is_empty(), "손가락 탭: 적 범위 켜짐")
	var er: Object = ui.order.row_of(enemy_id)
	_check((er != null and er.focus) or (er == null and ui.order._more.visible), "손가락 탭: 순서 바 그 적 줄 강조 (줄이 한도 밖이면 '+N명' 칩이 강조)")
	await _tap(sp)
	_check(sc.enemy_range_id == -1, "다시 탭: 적 범위 해제")
	sc._show_main_menu(sc.eng.awaiting_unit())
	# 순서 바 줄 탭 → 맵 링
	var row_ally: Object = null
	for r2: Node in ui.order.get_children():
		if r2 is PanelContainer and (r2 as Control).visible and r2.get("team") == "ally" and int(r2.get("id")) != sc.awaiting_unit_id():
			row_ally = r2
			break
	if row_ally != null:
		await _tap((row_ally as Control).get_global_rect().get_center())
		_check(sc.focus_id == int(row_ally.id) and sc.units[sc.focus_id].focus, "손가락 탭: 순서 바 줄 → 맵 링")
	# 카드 탭 → 맵 링
	var card: Control = null
	for c2: Node in ui.cards.row.get_children():
		if (c2 as Control).visible and int(c2.get("id")) != sc.focus_id:
			card = c2
			break
	if card != null:
		await _tap(card.get_global_rect().get_center())
		_check(sc.focus_id == int(card.get("id")), "손가락 탭: 클랜원 카드 → 맵 링 (얇은 패널)")
	# 계산 내역 접힘 단추 (손가락)
	var uA: Dictionary = sc.eng.awaiting_unit()
	if not (sc.eng.q.attack_targets(uA)["attack"] as Array).is_empty():
		sc.ui_action("attack")
		await _frames(3)
		_check(ui.calc_btn.size.y >= tmin - 0.5 and ui.calc_btn.size.x >= tmin, "접힘 단추 ≥ 44pt (%s)" % str(ui.calc_btn.size))
		await _tap(ui.calc_btn.get_global_rect().get_center())
		_check(ui.calc_open and ui.calc_scroll.visible, "손가락 탭: 계산 내역 펼침")
		var pr: Rect2 = ui.calc_panel.get_global_rect()
		var vs: Vector2 = root.get_visible_rect().size
		_check(pr.position.x >= ui.cards_rect.size.x - 1.0 and pr.end.x <= vs.x - 190.0 + 2.0 and pr.position.y >= 60.0, "펼친 패널이 왼쪽 패널·오른쪽 순서 바·윗줄과 안 겹침 %s" % str(pr))
		ui.set_calc_open(false)
		sc.ui_cancel()
		await _frames(2)
	# 확인 창 단추 (손가락)
	sc._user_action("wait")
	await _frames(2)
	if ui.end_confirm_open():
		_check(ui.end_yes.size.y >= tmin - 0.5 and ui.end_no.size.y >= tmin - 0.5, "확인 단추 ≥ 44pt")
		await _tap(ui.end_no.get_global_rect().get_center())
		_check(not ui.end_confirm_open() and sc.mode == "menu", "손가락 탭: 돌아가기")
	# 메뉴가 왼쪽 패널·오른쪽 순서 바와 겹치지 않음
	var mr: Rect2 = ui.menu.get_global_rect()
	if ui.menu.visible:
		_check(mr.position.x >= ui.cards_rect.size.x - 1.0 and mr.end.x <= root.get_visible_rect().size.x - 8.0, "행동 메뉴가 왼쪽 패널 밖 %s" % str(mr))
	sc.queue_free()
	await _frames(3)
	plat.call("emulate_mobile", false)
	root.size = Vector2i(1280, 720)
	mob.call("apply")
	await _frames(2)


# ═══════════ G) 낮은 화면에서 순서 바와 나침반이 안 겹침 ═══════════

func _layout_part() -> void:
	print("[G) 순서 바 ↔ 나침반 겹침 (논리 높이 360·400·480)]")
	for h: int in [360, 400, 480]:
		var cfg := BattleScene.golden_cfg("legion5_s09")
		cfg["speed"] = 0.0
		cfg["source"] = "test"
		cfg["story"] = "off"
		cfg["loading"] = false
		BattleScene.pending = cfg
		var sc: Node = (load(SCENE) as PackedScene).instantiate()
		root.add_child(sc)
		await _wait_menu(sc)
		await _frames(6)
		var ui: Node = sc.ui
		# 가상 화면: HUD 루트를 1067×h 논리 크기로 (창 크기는 그대로)
		ui.root.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		ui.root.size = Vector2(1067, h)
		await _frames(4)
		var order: Control = ui.order
		var comp: Control = ui.compass
		var total: int = order._last_rows.size()
		var order_bottom: float = order.get_global_rect().position.y + order.get_combined_minimum_size().y
		_check(order_bottom <= comp.get_global_rect().position.y + 0.5, "높이 %d: 순서 바 아래 %.0f ≤ 나침반 위 %.0f (표시 %d/%d줄, '+N명' %s)" % [h, order_bottom, comp.get_global_rect().position.y, order.shown_count, total, str(order._more.visible)])
		_check(order.shown_count >= 1, "높이 %d: 최소 1줄은 보임" % h)
		# 구분선이 켜져도 안 겹침 (합성 줄 — 다음 라운드 표시 + 한도 넘침)
		var fake: Array = []
		for i in 12:
			fake.append({"id": 900 + i, "team": "ally" if i % 2 == 0 else "enemy", "boss": false, "cur": i == 0, "name": "t%d" % i, "tip": "", "hp_ratio": 1.0, "ap_ratio": 0.5,
				"eta": "1.0", "ready": false, "tex": null, "summon": false, "round2": i >= 2})
		order._sig = ""
		order.update(fake)
		await _frames(3)
		var ob2: float = order.get_global_rect().position.y + order.get_combined_minimum_size().y
		_check(order._div.visible or order.shown_count <= 2, "높이 %d: 구분선 %s" % [h, str(order._div.visible)])
		_check(ob2 <= comp.get_global_rect().position.y + 0.5, "높이 %d: 구분선·'+N명' 포함해도 나침반과 안 겹침 (%.0f ≤ %.0f, %d줄)" % [h, ob2, comp.get_global_rect().position.y, order.shown_count])
		sc.queue_free()
		await _frames(3)
