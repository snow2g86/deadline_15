extends SceneTree
## 4b-2 실제 창 한 판 — 진짜 입력(Input.parse_input_event: OS 입력과 같은 길)으로
##  로비 → 아래 탭 성소(부활 · 승급 탭) → 아래 탭 아카데미(전직 · 스킬북 탭) → 로비 → 도감(직업 상세 창 · 장비 탭) → 로비 → 가이드(탭) →
##  로비 → 톱니 → 설정 → 크레딧 → 설정 → 라이선스(전문 펼치기) → 설정 → 로비 → 스테이지 1-1 → 전투 한 판 → 로비
##   Godot --path godot --resolution 1280x720 --script res://tests/play_4b2.gd   [-- --size 1920x1080] → tests/screens/4b2_*.png
##  저장은 user://test_play_4b2_save.json (진짜 세이브는 건드리지 않음). 실패하면 바로 끝냄. 끝에 PLAY_RESULT: OK|FAIL

const OUT := "res://tests/screens/"
const PlayKit := preload("res://tests/play_kit.gd")
const SAVE := "user://test_play_4b2_save.json"
const JsonX := preload("res://scripts/core/json_exact.gd")
const Js := preload("res://scripts/logic/js.gd")

var store: Node
var log_lines: Array = []
var fails: Array = []
var _shot_n := 0
var fx: Dictionary
var stuck := 0
var tag := ""


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


func _ok(cond: bool, what: String) -> void:
	_say(("OK  " if cond else "FAIL ") + what)
	if not cond:
		fails.append(what)
		_abort()


## (4b-2) 실패하면 바로 끝냄 — 다음 단계가 없는 단추를 기다리며 시간을 쓰지 않게 (화면 사진 하나 남기고 저장 지우고 quit(1))
var _aborting := false


func _abort() -> void:
	if _aborting:
		return
	_aborting = true
	print("PLAY_LOG: " + " | ".join(log_lines))
	print("PLAY_RESULT: FAIL " + str(fails))
	var img := root.get_texture().get_image()
	if img != null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		img.save_png(ProjectSettings.globalize_path(OUT + "4b2_%sfail.png" % tag))
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	# quit 은 이 프레임 끝에 적용 — 부른 쪽은 다음 await 에서 멈추고 다시 이어지지 않음 (그 사이 다른 실패는 _aborting 으로 무시)
	quit(1)


func _shot(name: String) -> void:
	await _frames(4)
	if not await PlayKit.post_draw(self, 5.0):
		_ok(false, "화면 그리기(frame_post_draw)를 5초 안에 받지 못함")
		return
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_shot_n += 1
	var path := ProjectSettings.globalize_path(OUT + "4b2_%s%02d_%s.png" % [tag, _shot_n, name])
	img.save_png(path)
	print("  사진: " + path)


# ── 진짜 입력 ──

## 화면(뷰포트) 좌표 → 창 좌표 (--size 로 뷰포트를 창보다 크게 잡았을 때 — 창이 화면 크기로 줄어들어도 같은 곳을 누르게)
func _win(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _move_mouse(p0: Vector2) -> void:
	var p := _win(p0)
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	Input.parse_input_event(mv)
	await _frames(2)


## (4b-2) 누르기·떼기를 같은 프레임에 넣음 — 창이 OS 초점을 잃으면(다른 앱·실제 마우스) Viewport 가 누르는 중인 단추의
##  마우스 초점을 버려(WINDOW_FOCUS_OUT → _drop_mouse_focus) 떼기가 '누름'이 되지 않던 것 (1920×1080 첫 누르기가 가끔 먹히지 않은 원인).
##  같은 프레임이면 Input 버퍼가 둘을 이어서 내보내 그 사이에 OS 사건이 끼지 않음. 창 크기는 원인이 아님 (창 1920×1080 px = 960×540 pt, 변환 1.5 그대로)
func _click(p0: Vector2) -> void:
	await _move_mouse(p0)
	var p := _win(p0)
	for pressed: bool in [true, false]:
		var d := InputEventMouseButton.new()
		d.button_index = MOUSE_BUTTON_LEFT
		d.pressed = pressed
		d.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		d.position = p
		d.global_position = p
		Input.parse_input_event(d)
	await _frames(3)


## 스크롤 안이면 보이게 한 뒤 가운데를 누름
func _click_ctl(c0: Variant, what: String = "") -> bool:
	var c: Variant = c0
	if typeof(c0) == TYPE_STRING:
		# 이름으로 찾기: 장면이 막 바뀐 때는 부품이 보일 때까지 기다림 (최대 3초)
		var t0 := Time.get_ticks_msec()
		c = _find(c0)
		while not (c is Control and (c as Control).is_visible_in_tree()) and Time.get_ticks_msec() - t0 < 3000:
			await process_frame
			c = _find(c0)
	if not (c is Control) or not (c as Control).is_visible_in_tree():
		_ok(false, "누를 것이 없음: " + what)
		return false
	var a: Node = (c as Control).get_parent()
	while a != null:
		if a is ScrollContainer:
			(a as ScrollContainer).ensure_control_visible(c)
			break
		a = a.get_parent()
	await _frames(2)
	await _click((c as Control).get_global_rect().get_center())
	return true


func _key(k: Key, unicode: int = 0) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.unicode = unicode
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(1)
	var r := e.duplicate() as InputEventKey
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(2)


func _scene_is(tail: String) -> bool:
	var s := current_scene
	return s != null and s.get_script() != null and str((s.get_script() as Script).resource_path).ends_with(tail) and s.is_node_ready()


func _find(n: String) -> Node:
	return current_scene.find_child(n, true, false) if current_scene != null else null


func _gold() -> float:
	return Js.num((store.call("get_json", "game_save", {}) as Dictionary).get("gold"))


func _inv() -> Array:
	return store.call("get_json", "game_inventory", [])


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var si := args.find("--size")
	if si >= 0 and si + 1 < args.size():
		var wh := args[si + 1].split("x")
		root.size = Vector2i(wh[0].to_int(), wh[1].to_int())
		tag = "%sx%s_" % [wh[0], wh[1]]
	print("  창 %s · 뷰포트 %s · 변환 %s" % [str(DisplayServer.window_get_size()), str(root.size), str(root.get_final_transform())])
	store = root.get_node("Store")
	store.call("use_path", SAVE)
	store.call("clear")
	root.get_node("I18n").call("set_language", "ko")
	fx = JsonX.parse(FileAccess.get_file_as_string("res://tests/fixtures/outer_4b2_web.json"))
	var st: Dictionary = fx["sanctuary"][0]["store"]
	for k: String in st.keys():
		store.call("set_json", k, st[k])
	var pt: Dictionary = store.call("get_json", "game_parties")
	pt["parties"][0]["slots"] = [1, 2, 4, 6, 12]   # 1-1 바로 출격 (5명)
	store.call("set_json", "game_parties", pt)
	store.call("set_json", "game_settings", {"language": "ko", "playSpeed": 4})
	store.call("set_json", "game_story_seen", {"ep1_pro": true, "s1_pre": true, "s1_start": true})
	change_scene_to_file("res://scenes/boot.tscn")
	_ok(await _until(func() -> bool: return _scene_is("ui/lobby.gd"), 8.0), "시작 → 로비")
	await _wait(0.8)
	await _shot("lobby")
	# ── 성소 ──
	await _click_ctl("Tab_sanctuary", "아래 탭 성소")
	_ok(await _until(func() -> bool: return _scene_is("ui/sanctuary.gd"), 5.0), "아래 탭 → 성소")
	await _wait(0.4)
	await _shot("sanctuary_resurrect")
	var g0 := _gold()
	await _click_ctl(_find("Dead_31").find_child("Revive", true, false), "부활")
	await _wait(0.3)
	_ok(_gold() == g0 - 120.0 and _find("Dead_31") == null, "부활 → 골드 −120 · 카드 사라짐")
	await _click_ctl("Tab_promote", "승급 탭")
	await _wait(0.3)
	await _shot("sanctuary_promote")
	await _click_ctl(_find("Promote_12").find_child("PromoteBtn", true, false), "승급 단추")
	await _wait(0.3)
	await _click_ctl("Sac_13", "제물 13")
	await _wait(0.2)
	await _shot("sanctuary_sacrifice")
	await _click_ctl("Confirm", "승급")
	await _wait(0.3)
	await _shot("sanctuary_promote_confirm")
	await _click_ctl("Yes", "확인")
	await _wait(0.3)
	_ok(_char(13).is_empty() and _find("Alert") != null, "승급 → 제물 사라짐 · 결과 알림")
	await _shot("sanctuary_promote_result")
	await _click_ctl("Ok", "알림 확인")
	await _click_ctl("Tab_enchant", "마법부여 탭")
	await _wait(0.3)
	await _shot("sanctuary_enchant")
	await _click_ctl("Tab_rename", "개명 탭")
	await _wait(0.3)
	await _shot("sanctuary_rename")
	# ── 아카데미 ──
	await _click_ctl("Tab_academy", "아래 탭 아카데미")
	_ok(await _until(func() -> bool: return _scene_is("ui/academy.gd"), 5.0), "아래 탭 → 아카데미")
	await _wait(0.4)
	await _shot("academy_classchange")
	await _click_ctl(_find("Novice_6").find_child("ChangeBtn", true, false), "전직 단추")
	await _wait(0.3)
	await _shot("academy_scrolls")
	await _key(KEY_ESCAPE)
	await _wait(0.2)
	await _click_ctl(current_scene.find_child("Tabs", true, false).find_child("Tab_skillbook", true, false), "스킬북 탭")
	await _wait(0.3)
	await _shot("academy_skillbook")
	await _key(KEY_ESCAPE)
	_ok(await _until(func() -> bool: return _scene_is("ui/lobby.gd"), 5.0), "아카데미 Esc → 로비")
	await _wait(0.5)
	# ── 도감 ──
	await _click_ctl("Compendium", "도감 단추")
	_ok(await _until(func() -> bool: return _scene_is("ui/compendium.gd"), 6.0), "로비 → 도감")
	await _wait(0.5)
	await _shot("compendium_cls")
	await _click_ctl("Tile_warrior", "전사 타일")
	await _wait(0.4)
	_ok(current_scene.modal_open(), "직업 상세 창")
	await _shot("compendium_sheet")
	await _click_ctl("CloseX", "✕")
	await _wait(0.2)
	await _click_ctl(current_scene.find_child("Tabs", true, false).find_child("Tab_gear", true, false), "장비 탭")
	await _wait(0.5)
	await _shot("compendium_gear")
	await _click_ctl(current_scene.find_child("Tabs", true, false).find_child("Tab_stage", true, false), "스테이지 탭")
	await _wait(0.6)
	await _shot("compendium_stage")
	await _click_ctl("Back", "뒤로")
	_ok(await _until(func() -> bool: return _scene_is("ui/lobby.gd"), 5.0), "도감 뒤로 → 로비")
	await _wait(0.5)
	# ── 가이드 ──
	await _click_ctl("Guide", "가이드 단추")
	_ok(await _until(func() -> bool: return _scene_is("ui/guide.gd"), 6.0), "로비 → 가이드")
	await _wait(0.5)
	await _shot("guide_start")
	await _click_ctl(current_scene.find_child("Tabs", true, false).find_child("Tab_battle", true, false), "전투 탭")
	await _wait(0.4)
	await _shot("guide_battle")
	await _click_ctl(current_scene.find_child("Tabs", true, false).find_child("Tab_story", true, false), "스토리 탭")
	await _wait(0.4)
	await _shot("guide_story")
	await _key(KEY_ESCAPE)
	_ok(await _until(func() -> bool: return _scene_is("ui/lobby.gd"), 5.0), "가이드 Esc → 로비")
	await _wait(0.5)
	# ── 설정 → 크레딧 → 라이선스 ──
	await _click_ctl("Gear", "톱니")
	_ok(await _until(func() -> bool: return _scene_is("ui/settings_screen.gd"), 5.0), "→ 설정")
	await _wait(0.3)
	await _click_ctl("Credits", "Credits")
	_ok(await _until(func() -> bool: return _scene_is("ui/credits.gd"), 5.0), "설정 → 크레딧")
	await _wait(0.3)
	await _shot("credits")
	await _click_ctl("Back", "뒤로")
	_ok(await _until(func() -> bool: return _scene_is("ui/settings_screen.gd"), 5.0), "크레딧 뒤로 → 설정")
	await _wait(0.3)
	await _click_ctl("Licenses", "라이선스")
	_ok(await _until(func() -> bool: return _scene_is("ui/licenses.gd"), 5.0), "설정 → 라이선스")
	await _wait(0.3)
	await _shot("licenses")
	await _click_ctl("GodotTextBtn", "Godot 전문 보기")
	await _wait(0.3)
	_ok((_find("GodotText") as Control).visible, "Godot 라이선스 전문 펼침")
	await _shot("licenses_godot")
	await _key(KEY_ESCAPE)
	_ok(await _until(func() -> bool: return _scene_is("ui/settings_screen.gd"), 5.0), "라이선스 Esc → 설정")
	await _wait(0.3)
	await _key(KEY_ESCAPE)
	_ok(await _until(func() -> bool: return _scene_is("ui/lobby.gd"), 5.0), "설정 Esc → 로비")
	await _wait(0.5)
	await _shot("lobby_back")
	# ── 전투 한 판 ──
	await _click_ctl("Tab_stage", "아래 탭 스테이지")
	await _until(func() -> bool: return _scene_is("ui/stage_select.gd"), 5.0)
	await _wait(0.4)
	var ss: Node = current_scene
	await _click_ctl(ss.cards["ep:1"], "EP.1")
	await _frames(5)
	await _click_ctl(ss.cards["st:1"], "1-1")
	await _frames(10)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000 and not _scene_is("battle/battle_scene.gd"):
		if _scene_is("ui/stage_select.gd") and bool(ss.story_view.get("active")):
			await _key(KEY_ESCAPE)
		await process_frame
	if not _scene_is("battle/battle_scene.gd") and _scene_is("ui/party_select.gd"):
		var ps: Node = current_scene
		await _click_ctl(ps.start_btn, "출격")
		await _until(func() -> bool: return _scene_is("battle/battle_scene.gd"), 8.0)
	_ok(_scene_is("battle/battle_scene.gd"), "1-1 → 전투")
	var bt: Node = current_scene
	_ok(await _until(func() -> bool: return bt.is_awaiting() or bt.is_over() or bt.is_story_playing(), 30.0), "전투 로딩 뒤 30초 안에 입력 대기(또는 대사)")
	await _wait(0.4)
	await _shot("battle")
	await _play_battle(bt, 400)
	var t1 := Time.get_ticks_msec()
	while not (bt.ui.result_view.visible and bt.ui.result_view.buttons.has("back")) and Time.get_ticks_msec() - t1 < 30000:
		if bt.is_story_playing():
			await _key(KEY_ENTER)
		await process_frame
	await _wait(1.2)
	_say("결과: %s (%s)" % [str(bt.result.get("result")), str(bt.result.get("reason", ""))])
	await _shot("battle_result")
	await _click_ctl(bt.ui.result_view.buttons["back"], "로비로")
	_ok(await _until(func() -> bool: return _scene_is("ui/lobby.gd"), 6.0), "결과 → 로비")
	await _wait(0.8)
	await _shot("lobby_after")
	_ok(stuck == 0, "전투 중 '대상 고르기'에서 멈춤 없음 (%d)" % stuck)
	if _aborting:
		return
	print("PLAY_LOG: " + " | ".join(log_lines))
	print("PLAY_RESULT: " + ("OK" if fails.is_empty() else "FAIL " + str(fails)))
	if current_scene != null:
		current_scene.queue_free()
	await _frames(2)
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0 if fails.is_empty() else 1)


func _char(uid: int) -> Dictionary:
	for ch: Dictionary in (store.call("get_json", "game_roster") as Dictionary)["chars"]:
		if int(ch["uid"]) == uid:
			return ch
	return {}


# ═══════════ 전투 (play_4a 와 같은 간단한 규칙, 실행은 진짜 입력) ═══════════

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


## 칸 고르기 뒤 메뉴로 돌아올 때까지 — 고르기 상태에서 멈추면 세고 Esc 로 풀어 다음으로 (play_4a 멈춤 재발 확인)
func _after_pick(bt: Node, secs: float) -> void:
	var ok: bool = await _until(func() -> bool: return bt.is_over() or (bt.is_awaiting() and bt.mode == "menu"), secs)
	if not ok and bt.mode == "target":
		stuck += 1
		_say("멈춤: 대상 고르기에서 누르기를 받지 않음 (창 초점 %s)" % str(DisplayServer.window_is_focused()))
		await _key(KEY_ESCAPE)


func _play_battle(bt: Node, max_acts: int) -> void:
	var t0 := Time.get_ticks_msec()
	var acts := 0
	while not bt.is_over() and acts < max_acts and Time.get_ticks_msec() - t0 < 240000:
		if bt.is_story_playing():
			await _key(KEY_SPACE)
			await _wait(0.05)
			continue
		if not bt.is_awaiting() or bt.mode != "menu":
			await process_frame
			continue
		var u: Dictionary = bt.eng.awaiting_unit()
		acts += 1
		var tg: Array = bt.eng.q.attack_targets(u)["attack"]
		if not tg.is_empty():
			var c: Dictionary = tg[0]
			await _key(KEY_A)
			var p := await _ensure_visible(bt, int(c["x"]), int(c["y"]))
			await _click_cell(p)
			await _after_pick(bt, 6.0)
			continue
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
				await _after_pick(bt, 6.0)
				if bt.is_awaiting() and bt.eng.awaiting_unit() != null and bt.eng.awaiting_unit()["id"] == u["id"] and bt.eng.q.can_undo():
					continue
		await _key(KEY_SPACE)
		await _key(KEY_ENTER)
		await _until(func() -> bool: return bt.is_over() or (bt.is_awaiting() and bt.mode == "menu"), 8.0)
	if not bt.is_over() and max_acts > 100:
		await _click_ctl(bt.ui.settings.btn, "톱니")
		await _click_ctl(bt.ui.settings.panel.find_child("Surrender", true, false), "항복")
		await _click_ctl(bt.ui.settings.confirm.find_child("Yes", true, false), "항복 확인")
	_say("전투 행동 %d번 (%.0f초)" % [acts, float(Time.get_ticks_msec() - t0) / 1000.0])
