extends SceneTree
## 4a 실제 창 한 판 — 시작 화면부터 마우스·키 입력(Input.parse_input_event: OS 입력과 같은 길)으로
##  지휘관 설정 → 로비 → 출격 → EP.1 → 1-1 → 출전 전 스토리 → 전투(이동·공격·대기를 단추·칸 누르기로) → 결과 → 로비
##   Godot --path godot --resolution 1280x720 --script res://tests/play_4a.gd   → tests/screens/4a_play_*.png
##  전투의 '무엇을 할지'만 간단한 규칙(공격할 수 있으면 공격, 아니면 가장 가까운 적 쪽으로 이동)으로 고르고, 실행은 모두 진짜 입력.
##  저장은 user://test_play_4a_save.json (진짜 세이브는 건드리지 않음)

const OUT := "res://tests/screens/"
const PlayKit := preload("res://tests/play_kit.gd")
const SAVE := "user://test_play_4a_save.json"

var store: Node
var log_lines: Array = []
var _shot_n := 0
## '대상 고르기'에서 칸 누르기가 먹히지 않아 메뉴로 돌아오지 않은 횟수 (4b-1: 원인은 로딩 화면이 흐려지는 0.4초 동안 누르기를 막던 것 — 고침)
var stuck := 0
var timed_out := false


func _initialize() -> void:
	_main.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _until(cond: Callable, secs: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await process_frame
	return cond.call()


func _say(s: String) -> void:
	print("  " + s)
	log_lines.append(s)


func _shot(name: String) -> void:
	await _frames(4)
	if not await PlayKit.post_draw(self, 5.0):
		_fail_quit("화면 그리기(frame_post_draw)를 5초 안에 받지 못함")
		return
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_shot_n += 1
	var path := ProjectSettings.globalize_path(OUT + "4a_play_%02d_%s.png" % [_shot_n, name])
	img.save_png(path)
	print("  사진: " + path)


# ── 진짜 입력 ──

func _move_mouse(p: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	Input.parse_input_event(mv)
	await _frames(2)


func _click(p: Vector2) -> void:
	await _move_mouse(p)
	# (4b-2) 누르기·떼기를 같은 프레임에 (play_4b1 과 같음 — 사이에 창 초점 잃음 사건이 끼면 누르는 중인 것이 버려짐)
	for pressed: bool in [true, false]:
		var d := InputEventMouseButton.new()
		d.button_index = MOUSE_BUTTON_LEFT
		d.pressed = pressed
		d.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		d.position = p
		d.global_position = p
		Input.parse_input_event(d)
	await _frames(3)


func _click_ctl(c: Control) -> void:
	await _click(c.get_global_rect().get_center())


func _key(k: Key, unicode: int = 0, ctrl: bool = false) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.unicode = unicode
	e.ctrl_pressed = ctrl
	e.meta_pressed = false
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(1)
	var r := e.duplicate() as InputEventKey
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(2)


func _type(text: String) -> void:
	for i in text.length():
		await _key(KEY_NONE, text.unicode_at(i))


func _scene_is(tail: String) -> bool:
	var s := current_scene
	return s != null and s.get_script() != null and str((s.get_script() as Script).resource_path).ends_with(tail) and s.is_node_ready()


func _main() -> void:
	store = root.get_node("Store")
	store.call("use_path", SAVE)
	store.call("clear")
	root.get_node("I18n").call("set_language", "ko")
	store.call("set_json", "game_settings", {"language": "ko", "playSpeed": 4})
	change_scene_to_file("res://scenes/boot.tscn")
	await _until(func() -> bool: return _scene_is("ui/lobby.gd"), 8.0)
	await _wait(0.6)
	var lobby: Node = current_scene
	_say("로비 + 지휘관 설정 창")
	await _shot("commander_setup")
	await _click_ctl(lobby.setup_dialog.find_child("Card_f", true, false))
	await _click_ctl(lobby.setup_input)
	await _key(KEY_END)
	for i in 12:
		await _key(KEY_BACKSPACE)
	await _type("하늘")
	await _key(KEY_ENTER)
	await _frames(5)
	_say("지휘관 이름: %s" % lobby.cmd_name.text)
	await _wait(0.4)
	await _shot("lobby")
	await _click_ctl(lobby.cta)
	await _until(func() -> bool: return _scene_is("ui/stage_select.gd"), 5.0)
	var ss: Node = current_scene
	await _wait(0.3)
	await _shot("episodes")
	await _click_ctl(ss.cards["ep:1"])
	await _frames(5)
	await _shot("stages")
	await _click_ctl(ss.cards["st:1"])
	await _frames(10)
	# 스토리: 몇 줄은 누르기·Space 로 넘기고, 나머지는 Esc 로 건너뜀
	var advanced := 0
	for i in 6:
		if not bool(ss.story_view.get("active")):
			break
		if i == 2:
			await _wait(0.5)
			await _shot("story")
		if i % 2 == 0:
			await _click(Vector2(640, 600))
		else:
			await _key(KEY_SPACE)
		advanced += 1
		await _wait(0.2)
	var skipped := 0
	var idle := Time.get_ticks_msec()
	while Time.get_ticks_msec() - idle < 700 and _scene_is("ui/stage_select.gd"):
		if bool(ss.story_view.get("active")):
			await _key(KEY_ESCAPE)
			skipped += 1
			idle = Time.get_ticks_msec()
		await process_frame
	_say("스토리: %d번 넘기고 %d장면 건너뜀" % [advanced, skipped])
	if not await _until(func() -> bool: return _scene_is("battle/battle_scene.gd"), 10.0):
		_fail_quit("10초 안에 전투 장면으로 가지 못함")
		return
	var bt: Node = current_scene
	# 로딩(지형 굽기 포함) 뒤 첫 입력 대기까지 시간 제한
	if not await _until(func() -> bool: return bt.is_awaiting() or bt.is_over() or bt.is_story_playing() or not bt.ui.loading.visible, 30.0):
		_fail_quit("전투 로딩(지형 굽기)이 30초 안에 끝나지 않음")
		return
	_say("전투 시작 (스테이지 %d, 파티 %s)" % [int(bt.cfg["stage"]["id"]), str(bt.cfg.get("party"))])
	await _play_battle(bt)
	# 승리 뒤 대사(스테이지 post)는 Enter 로 넘김
	var t1 := Time.get_ticks_msec()
	while not (bt.ui.result_view.visible and bt.ui.result_view.buttons.has("back")) and Time.get_ticks_msec() - t1 < 30000:
		if bt.is_story_playing():
			await _key(KEY_ENTER)
		await process_frame
	await _wait(1.2)
	_say("결과: %s (%s)" % [str(bt.result.get("result")), str(bt.result.get("reason", ""))])
	await _shot("result")
	await _until(func() -> bool: return bt.ui.result_view.buttons.has("back"), 5.0)
	_say("결과 단추: %s" % str(bt.ui.result_view.buttons.keys()))
	# 승리했으면 '다음 스테이지' (5명 → 바로 1-2 전투) → 한 판 더 → '로비로'
	if bt.ui.result_view.buttons.has("next"):
		var old_id := bt.get_instance_id()
		await _click_ctl(bt.ui.result_view.buttons["next"])
		if not await _until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id and _scene_is("battle/battle_scene.gd"), 10.0):
			_fail_quit("다음 스테이지 전투 장면으로 가지 못함")
			return
		bt = current_scene
		if not await _until(func() -> bool: return bt.is_awaiting() or bt.is_over() or bt.is_story_playing() or not bt.ui.loading.visible, 30.0):
			_fail_quit("다음 스테이지 로딩 뒤 입력 대기가 오지 않음")
			return
		_say("다음 스테이지 → 전투 (스테이지 %d)" % int(bt.cfg["stage"]["id"]))
		await _play_battle(bt)
		var t2 := Time.get_ticks_msec()
		while not (bt.ui.result_view.visible and bt.ui.result_view.buttons.has("back")) and Time.get_ticks_msec() - t2 < 30000:
			if bt.is_story_playing():
				await _key(KEY_ENTER)
			await process_frame
		await _wait(1.2)
		_say("두 번째 결과: %s (%s)" % [str(bt.result.get("result")), str(bt.result.get("reason", ""))])
		await _shot("result2")
	await _click_ctl(bt.ui.result_view.buttons["back"])
	await _until(func() -> bool: return _scene_is("ui/lobby.gd"), 6.0)
	await _wait(0.8)
	_say("로비로 돌아옴: %s · 골드 %s · 클리어 %s" % [str(_scene_is("ui/lobby.gd")), current_scene.gold_lbl.text, str(store.call("get_json", "game_save").get("cleared", []))])
	await _shot("lobby_after")
	print("PLAY_LOG: " + " | ".join(log_lines))
	var clear_n: int = (store.call("get_json", "game_save", {}) as Dictionary).get("cleared", []).size()
	var ok := stuck == 0 and _scene_is("ui/lobby.gd") and not timed_out
	print("PLAY_RESULT: %s (멈춤 %d · 클리어 %d)" % ["OK" if ok else "FAIL", stuck, clear_n])
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0 if ok else 1)


# ═══════════ 전투: 진짜 입력으로 한 판 ═══════════

func _cell_screen(bt: Node, x: int, y: int) -> Vector2:
	return bt.get_viewport().get_canvas_transform() * bt.iso.top_center(x, y)


## 칸이 논리 화면 가운데 쪽에 오고 HUD 위가 아닐 때까지 화살표 키로 카메라를 옮김 (tests/play_kit.gd) → 누를 곳, 못 누르면 Vector2.INF
func _ensure_visible(bt: Node, x: int, y: int) -> Vector2:
	var r: Array = await PlayKit.ensure_visible(self, bt, x, y, _key)
	return r[0] if r[1] else Vector2.INF


## 칸 누르기 — HUD 에 가려 누를 수 없으면 누르지 않고 Esc (고르기 취소)
var hud_blocked := 0


func _click_cell(p: Vector2) -> void:
	if p == Vector2.INF:
		hud_blocked += 1
		print("  HUD 에 가려 칸을 누르지 않음 (Esc)")
		await _key(KEY_ESCAPE)
		return
	await _click(p)


func _enemies(bt: Node) -> Array:
	var out: Array = []
	for u: Dictionary in bt.eng.S["units"]:
		if u["team"] == "enemy" and float(u["hp"]) > 0.0 and not bt.eng.is_stealthed(u):
			out.append(u)
	return out


## 칸을 누른 뒤 메뉴(또는 끝)로 돌아올 때까지 — '대상 고르기'에 남으면 멈춤으로 세고 Esc 로 풀어 계속 (예전에는 여기서 240초 동안 멈춤)
func _after_pick(bt: Node) -> void:
	var ok: bool = await _until(func() -> bool: return bt.is_over() or (bt.is_awaiting() and bt.mode == "menu"), 6.0)
	if not ok and bt.mode == "target":
		stuck += 1
		_say("멈춤: 대상 고르기에서 누르기를 받지 않음 (창 초점 %s)" % str(DisplayServer.window_is_focused()))
		await _key(KEY_ESCAPE)


func _play_battle(bt: Node) -> void:
	var t0 := Time.get_ticks_msec()
	var acts := 0
	var shot_mid := false
	while not bt.is_over() and Time.get_ticks_msec() - t0 < 240000:
		if bt.is_story_playing():
			await _key(KEY_SPACE)
			await _wait(0.05)
			continue
		if not bt.is_awaiting() or bt.mode != "menu":
			await process_frame
			continue
		var u: Dictionary = bt.eng.awaiting_unit()
		acts += 1
		if acts == 6 and not shot_mid:
			shot_mid = true
			await _shot("battle")
		# 1) 공격할 수 있으면 A + 적 칸 누르기
		var tg: Array = bt.eng.q.attack_targets(u)["attack"]
		if not tg.is_empty():
			var c: Dictionary = tg[0]
			await _key(KEY_A)
			var p := await _ensure_visible(bt, int(c["x"]), int(c["y"]))
			await _click_cell(p)
			await _after_pick(bt)
			continue
		# 2) 이동 전이면 M + 가장 가까운 적 쪽 칸 누르기
		var cells: Array = bt.eng.q.move_cells(u)
		var en := _enemies(bt)
		if not cells.is_empty() and not en.is_empty() and not bt.eng.q.can_undo():
			var best: Dictionary = {}
			var bd := INF
			for mc: Dictionary in cells:
				if mc.get("vault", false):
					continue
				for e: Dictionary in en:
					var d := absf(float(mc["x"]) - float(e["x"])) + absf(float(mc["y"]) - float(e["y"]))
					if d < bd:
						bd = d
						best = mc
			if not best.is_empty():
				await _key(KEY_M)
				var p2 := await _ensure_visible(bt, int(best["x"]), int(best["y"]))
				await _click_cell(p2)
				await _after_pick(bt)
				if bt.is_awaiting() and bt.eng.awaiting_unit() != null and bt.eng.awaiting_unit()["id"] == u["id"] and bt.eng.q.can_undo():
					continue   # 이동했으면 같은 유닛 다시 (공격할 수 있나)
		# 3) 대기 (Space) + 지금 방향 (Enter)
		await _key(KEY_SPACE)
		await _key(KEY_ENTER)
		await _until(func() -> bool: return bt.is_over() or (bt.is_awaiting() and bt.mode == "menu"), 8.0)
	if not bt.is_over():
		timed_out = true
		# 시간 안에 끝나지 않으면 톱니 → 항복 → 확인 (마우스)
		await _click_ctl(bt.ui.settings.btn)
		await _click_ctl(bt.ui.settings.panel.find_child("Surrender", true, false))
		await _click_ctl(bt.ui.settings.confirm.find_child("Yes", true, false))
	_say("전투 행동 %d번 (%.0f초)" % [acts, float(Time.get_ticks_msec() - t0) / 1000.0])


## (4b-2) 기다림 시간 초과 등: 바로 실패로 끝냄 (저장 지우고 quit(1))
var _quitting := false


func _fail_quit(why: String) -> void:
	if _quitting:
		return
	_quitting = true
	print("  FAIL " + why)
	print("PLAY_RESULT: FAIL (%s)" % why)
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(1)
