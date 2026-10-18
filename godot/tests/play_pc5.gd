extends SceneTree
## 5단계 실제 창 시험 — 창 모드·전체 화면·창 크기·최소 크기·모니터 배율·다음 실행 복원 (진짜 입력: Input.parse_input_event)
##   1차: Godot --path godot --script res://tests/play_pc5.gd               → tests/screens/pc5_*.png, 창 상태를 저장하고 끝
##   2차: Godot --path godot --script res://tests/play_pc5.gd -- --verify   → 1차에서 저장한 창 크기·위치·모드가 복원되는지
##  저장은 user://test_play_pc5_save.json (진짜 세이브는 건드리지 않음). --script 시험은 Display 가 창을 맡지 않으므로 manage() 로 켬.
##  마지막 줄 PC5_RESULT: OK / FAIL

const OUT := "res://tests/screens/"
const PlayKit := preload("res://tests/play_kit.gd")
const DisplayT := preload("res://scripts/core/display.gd")
const SAVE := "user://test_play_pc5_save.json"

var store: Node
var display: Node
var router: Node
var _fails: Array = []
var _passes := 0
## macOS 는 앞에 있지 않은(초점 없는) 창의 시스템 전체 화면 전환을 하지 않음 — 이때는 경고로 남김
var _warns: Array = []


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


func _check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
		print("  ok   " + what)
	else:
		_fails.append(what)
		print("  FAIL " + what)


func _shot(name: String) -> void:
	await _frames(4)
	if not await PlayKit.post_draw(self, 5.0):
		print("  (사진 실패: frame_post_draw 없음) " + name)
		return
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path := ProjectSettings.globalize_path(OUT + "pc5_%s.png" % name)
	img.save_png(path)
	print("  사진: %s (%dx%d)" % [path, img.get_width(), img.get_height()])


func _scene_is(tail: String) -> bool:
	var s := current_scene
	return s != null and s.get_script() != null and str((s.get_script() as Script).resource_path).ends_with(tail) and s.is_node_ready()


## 화면(뷰포트) 좌표 → 창 좌표 (늘이기 변환 — 레티나 배율·expand)
func _to_window(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _click_ctl(c: Control) -> void:
	var p := _to_window(c.get_global_rect().get_center())
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	Input.parse_input_event(mv)
	await _frames(2)
	for pressed: bool in [true, false]:
		var d := InputEventMouseButton.new()
		d.button_index = MOUSE_BUTTON_LEFT
		d.pressed = pressed
		d.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		d.position = p
		d.global_position = p
		Input.parse_input_event(d)
	await _frames(3)


func _key(k: Key, alt := false, ctrl := false, meta := false) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.alt_pressed = alt
	e.ctrl_pressed = ctrl
	e.meta_pressed = meta
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(1)
	var r := e.duplicate() as InputEventKey
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(2)


func _state() -> String:
	var w := root
	var sc: float = display.call("scale_of", DisplayServer.window_get_current_screen())
	return "모니터 %d(배율 %.1f) 창 %s px · 논리 %s · 위치 %s · 모드 %d · 최소 %s" % [DisplayServer.window_get_current_screen(), sc, str(w.size), str(display.call("window_logical_size")), str(w.position), w.mode, str(w.min_size)]


## macOS NSScreen 목록 [폭, 높이, 작업 영역 폭, 높이, backingScaleFactor] (포인트 — Godot 와 상관없는 값). macOS 가 아니면 빈 배열
func _ns_screens() -> Array:
	if OS.get_name() != "macOS":
		return []
	var js := "ObjC.import('AppKit'); var s=$.NSScreen.screens, o=[]; for (var i=0;i<s.count;i++){var c=s.objectAtIndex(i), f=c.frame, v=c.visibleFrame; o.push([f.size.width,f.size.height,v.size.width,v.size.height,c.backingScaleFactor]);} JSON.stringify(o)"
	var out: Array = []
	if OS.execute("osascript", ["-l", "JavaScript", "-e", js], out, true) != 0 or out.is_empty():
		return []
	var v: Variant = JSON.parse_string(str(out[0]).strip_edges())
	return v if v is Array else []


## Godot 모니터 번호 → 같은 모양(가로세로 비)의 NSScreen
func _ns_of(ns: Array, screen: int) -> Array:
	var g := Vector2(DisplayServer.screen_get_size(screen))
	var best: Array = []
	var bd := 1e9
	for a: Array in ns:
		var d := absf(float(a[0]) / float(a[1]) - g.x / g.y)
		if d < bd:
			bd = d
			best = a
	return best


## 창의 실제 크기 (포인트) = 창 ÷ 모니터 (Godot 단위끼리 비율) × 모니터 포인트 (NSScreen)
func _measured(ns: Array, screen: int) -> Vector2:
	var a := _ns_of(ns, screen)
	if a.is_empty():
		return Vector2.ZERO
	var g := Vector2(DisplayServer.screen_get_size(screen))
	return Vector2(root.size) / g * Vector2(float(a[0]), float(a[1]))


func _measure_ok(want: Vector2, ns: Array, screen: int) -> bool:
	var m := _measured(ns, screen)
	return absf(m.x - want.x) <= 2.0 and absf(m.y - want.y) <= 2.0


## 지금 맨 앞 앱 이름 (macOS NSWorkspace — Godot 과 상관없는 값)
func _front_app() -> String:
	var out: Array = []
	OS.execute("osascript", ["-l", "JavaScript", "-e", "ObjC.import('AppKit'); $.NSWorkspace.sharedWorkspace.frontmostApplication.localizedName.js"], out, true)
	return str(out[0]).strip_edges() if not out.is_empty() else ""


func _logical_is(v: Vector2i) -> bool:
	return display.call("window_logical_size") == v


func _main() -> void:
	store = root.get_node("Store")
	display = root.get_node("Display")
	router = root.get_node("Router")
	var verify := OS.get_cmdline_user_args().has("--verify")
	store.call("use_path", SAVE)
	if not verify:
		store.call("clear")
		store.call("set_json", "game_settings", {"language": "ko"})
	root.get_node("I18n").call("reload")
	_check(bool(display.get("active")) and not bool(display.get("managed")), "창 실행 · --script 시험이라 Display 가 창을 맡지 않음 (시작)")
	display.call("manage")
	DisplayServer.window_move_to_foreground()   # macOS 전체 화면은 앞에 있는 창이어야 바로 됨 (명령줄로 띄운 창은 뒤에 있을 수 있음)
	await _wait(0.6)
	print("  " + _state())
	if verify:
		await _verify()
	else:
		await _first()
	var ok := _fails.is_empty()
	print("PC5_RESULT: %s (%d개 통과, %d개 실패, 경고 %d)" % [("WARN" if not _warns.is_empty() else "OK") if ok else "FAIL", _passes, _fails.size(), _warns.size()])
	for w: String in _warns:
		print("  ! " + w)
	for f: String in _fails:
		print("  - " + f)
	if verify:
		store.call("clear")
		store.call("flush")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0 if ok else 1)


func _first() -> void:
	var scr := DisplayServer.window_get_current_screen()
	var sc: float = display.call("scale_of", scr)
	var usable: Vector2i = display.call("usable_logical", scr)
	var want_default := DisplayT.default_size(usable)
	_check(_logical_is(want_default), "처음 실행: 작업 영역(논리 %s)의 80%% 안 가장 큰 크기 %s (배율 %.1f → %s px)" % [str(usable), str(want_default), sc, str(Vector2i(Vector2(want_default) * sc))])
	_check(root.min_size == Vector2i(Vector2(DisplayT.MIN_LOGICAL) * sc), "최소 창 크기 = 1024×576 × 배율 %.1f = %s" % [sc, str(root.min_size)])
	_check(root.title == "DEADLINE 15", "창 제목 DEADLINE 15")
	router.call("go", "settings")
	await _until(func() -> bool: return _scene_is("ui/settings_screen.gd"), 5.0)
	await _wait(0.4)
	await _shot("01_settings_%dx%d" % [int(display.call("window_logical_size").x), int(display.call("window_logical_size").y)])
	# 창 크기 단추 (진짜 누르기)
	for sz: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		var b: Button = current_scene.find_child("Size_%d_%d" % [sz.x, sz.y], true, false)
		if b == null:
			_check(false, "창 크기 단추 %s 없음 (이 모니터에 들어가지 않음?)" % str(sz))
			continue
		await _click_ctl(b)
		await _wait(0.6)
		_check(_logical_is(sz) and root.size == Vector2i(Vector2(sz) * sc), "창 크기 단추 %d×%d → 창 %s px (%s)" % [sz.x, sz.y, str(root.size), _state()])
		await _shot("02_window_%dx%d" % [sz.x, sz.y])
	# 최소 크기보다 작게
	root.size = Vector2i(Vector2(700, 400) * sc)
	await _wait(0.5)
	_check(root.size.x >= int(1024 * sc) and root.size.y >= int(576 * sc), "최소보다 작게 줄이기 → 막힘 (%s px)" % str(root.size))
	display.call("set_window_size", Vector2i(1600, 900))
	await _wait(0.5)
	# (가) 창이 뒤에 있을 때: Finder 를 앞으로(open -a) → Alt+Enter. 판정 시간이 지난 뒤 저장값이 실제와 같아야 함
	#  (macOS 가 무시하면 창 모드로 되돌림 · 실제로 전체 화면이 되면 유지)
	if OS.get_name() == "macOS":
		OS.execute("open", ["-a", "Finder"])
		await _until(func() -> bool: return _front_app() == "Finder", 4.0)
		await _wait(0.6)
		var front := _front_app()
		await _key(KEY_ENTER, true)
		await _wait(0.3)
		_check(str(display.call("mode")) == "fullscreen", "뒤에 있는 창(맨 앞 앱 %s, Godot 초점 %s)에서 Alt+Enter → 전체 화면 요청" % [front, str(DisplayServer.window_is_focused())])
		await _wait(float(DisplayT.FS_CHECK) + 2.0)
		var saved_m := str(DisplayT.sanitize(store.call("get_json", DisplayT.KEY, {})).get("mode"))
		var real := bool(display.call("really_fullscreen"))
		var sb0: Button = current_scene.find_child("Size_1280_720", true, false)
		var consistent := (real and str(display.call("mode")) == "fullscreen" and saved_m == "fullscreen") or \
			(not real and str(display.call("mode")) == "windowed" and saved_m == "windowed" and root.mode == Window.MODE_WINDOWED and _logical_is(Vector2i(1600, 900)) and sb0 != null and not sb0.disabled)
		_check(consistent and front == "Finder", "뒤에 있는 창: %.0f초 뒤 저장값 = 실제 (%s · 저장 %s · %s)" % [DisplayT.FS_CHECK + 2.0, "전체 화면 유지" if real else "무시됨 → 창 모드로 되돌림", saved_m, _state()])
		if real:
			_warns.append("Finder 를 앞으로 보냈는데도 macOS 가 전체 화면으로 바꿈 — 되돌림 길은 이번에 지나지 않음 (단위 시험 check_pc5 가 맡음)")
			display.call("set_mode", "windowed")
			await _until(func() -> bool: return root.mode == Window.MODE_WINDOWED and _logical_is(Vector2i(1600, 900)), 6.0)
			await _wait(0.8)
	# (나) 창이 앞에 있을 때: 진짜 전체 화면은 유지
	DisplayServer.window_move_to_foreground()
	await _until(func() -> bool: return DisplayServer.window_is_focused(), 3.0)
	await _wait(0.5)
	var fg := DisplayServer.window_is_focused()
	await _key(KEY_ENTER, true)
	await _wait(1.0)
	var sb: Button = current_scene.find_child("Size_1280_720", true, false)
	_check(str(display.call("mode")) == "fullscreen" and sb != null and sb.disabled, "Alt+Enter → 전체 화면 요청 · 저장 · 창 크기 단추 꺼짐 (%s)" % _state())
	if fg:
		await _wait(float(DisplayT.FS_CHECK) + 1.0)   # 판정 시간이 지나도 그대로여야 함
		_check(str(display.call("mode")) == "fullscreen" and bool(display.call("really_fullscreen")) and str(DisplayT.sanitize(store.call("get_json", DisplayT.KEY, {})).get("mode")) == "fullscreen",
			"앞에 있는 창: 진짜 전체 화면은 %.0f초 뒤에도 유지 (%s)" % [DisplayT.FS_CHECK + 2.0, _state()])
		await _shot("03_fullscreen")
		await _key(KEY_ENTER, true)
		var ok_w := await _until(func() -> bool: return root.mode == Window.MODE_WINDOWED and _logical_is(Vector2i(1600, 900)), 6.0)
		await _wait(0.8)
		_check(ok_w, "Alt+Enter → 창 모드, 1600×900 으로 돌아옴 (%s)" % _state())
	else:
		_warns.append("창을 앞으로 가져오지 못해 진짜 전체 화면 유지는 확인 못 함")
		await _until(func() -> bool: return str(display.call("mode")) == "windowed", float(DisplayT.FS_CHECK) + 3.0)
	await _shot("04_windowed_back")
	# 설정 화면 단추 · macOS Cmd+Ctrl+F (앞에 있는 창 — 진짜 전체 화면이 될 때까지 기다린 뒤 되돌림)
	var mb: Button = current_scene.find_child("Mode_fullscreen", true, false)
	if mb != null:
		DisplayServer.window_move_to_foreground()
		await _click_ctl(mb)
		var ok2 := await _until(func() -> bool: return bool(display.call("really_fullscreen")), 6.0)
		await _wait(1.0)
		var wb: Button = current_scene.find_child("Mode_windowed", true, false)
		if wb != null:
			await _click_ctl(wb)
		var ok3 := await _until(func() -> bool: return root.mode == Window.MODE_WINDOWED and _logical_is(Vector2i(1600, 900)), 6.0)
		await _wait(1.0)
		_check((ok2 or not DisplayServer.window_is_focused()) and ok3 and str(display.call("mode")) == "windowed", "설정 화면 '전체 화면' · '창 모드' 단추 (전체 화면 %s · %s)" % [str(ok2), _state()])
	if OS.get_name() == "macOS":
		DisplayServer.window_move_to_foreground()
		await _key(KEY_F, false, true, true)
		var ok4 := await _until(func() -> bool: return bool(display.call("really_fullscreen")), 6.0)
		await _wait(1.0)
		await _key(KEY_F, false, true, true)
		var ok5 := await _until(func() -> bool: return root.mode == Window.MODE_WINDOWED and _logical_is(Vector2i(1600, 900)), 6.0)
		await _wait(1.0)
		_check((ok4 or not DisplayServer.window_is_focused()) and ok5 and str(display.call("mode")) == "windowed", "macOS Cmd+Ctrl+F → 전체 화면 → 창 (전체 화면 %s · %s)" % [str(ok4), _state()])
	# 다른 모니터로 옮기기 (있으면) — 창의 실제 크기를 Godot 계산과 따로 잼:
	#  macOS 가 알려 주는 모니터 크기(NSScreen, 포인트 — osascript)를 기준으로, 창이 그 모니터에서 차지하는 비율 × 모니터 포인트 = 창 포인트
	var ns := _ns_screens()
	if DisplayServer.get_screen_count() > 1 and not ns.is_empty():
		var cur := DisplayServer.window_get_current_screen()
		_check(_measure_ok(Vector2(1600, 900), ns, cur), "모니터 %d: 창 실제 크기 1600×900 포인트 (잰 값 %s)" % [cur, str(_measured(ns, cur))])
		for other in DisplayServer.get_screen_count():
			if other == cur:
				continue
			var u := DisplayServer.screen_get_usable_rect(other)
			root.position = u.position + (u.size - root.size) / 2
			await _until(func() -> bool: return DisplayServer.window_get_current_screen() == other, 4.0)
			await _wait(1.0)
			var nso: Array = _ns_of(ns, other)
			_check(DisplayServer.window_get_current_screen() == other and _measure_ok(Vector2(1600, 900), ns, other),
				"모니터 %d(macOS 배율 %s, %s 포인트)로 옮김 → 창 실제 크기 1600×900 포인트 그대로 (잰 값 %s · %s)" % [other, str(nso[4]) if nso.size() > 4 else "?", str(Vector2(nso[0], nso[1])) if nso.size() > 1 else "?", str(_measured(ns, other)), _state()])
			# 최소 크기: 작게 줄여도 1024×576 포인트 아래로 가지 않음
			root.size = Vector2i(200, 120)
			await _wait(0.6)
			var m := _measured(ns, other)
			_check(m.x >= 1024 - 2 and m.y >= 576 - 2, "모니터 %d: 최소 창 크기 실제 1024×576 포인트 이상 (잰 값 %s)" % [other, str(m)])
			# 크기 단추는 이 모니터의 작업 영역(포인트)에 들어가는 것만
			router.call("go", "settings")
			await _until(func() -> bool: return _scene_is("ui/settings_screen.gd"), 5.0)
			await _wait(0.4)
			var biggest := Vector2i.ZERO
			for b: Node in current_scene.find_child("SizeGrid", true, false).get_children():
				var p := str(b.name).trim_prefix("Size_").split("_")
				biggest = Vector2i(maxi(biggest.x, int(p[0])), maxi(biggest.y, int(p[1])))
			_check(nso.size() > 3 and biggest.x <= int(nso[2]) and biggest.y <= int(nso[3]), "모니터 %d: 가장 큰 크기 단추 %s ≤ 작업 영역 %s 포인트" % [other, str(biggest), str(Vector2(nso[2], nso[3])) if nso.size() > 3 else "?"])
			display.call("set_window_size", Vector2i(1280, 720))
			await _wait(0.6)
			_check(_measure_ok(Vector2(1280, 720), ns, other), "모니터 %d: '1280×720' → 실제 1280×720 포인트 (잰 값 %s)" % [other, str(_measured(ns, other))])
			await _shot("05_monitor%d" % other)
		# 원래 모니터로 돌아와 1600×900
		var u0 := DisplayServer.screen_get_usable_rect(cur)
		root.position = u0.position + Vector2i(40, 40)
		await _until(func() -> bool: return DisplayServer.window_get_current_screen() == cur, 4.0)
		await _wait(0.8)
		display.call("set_window_size", Vector2i(1600, 900))
		await _wait(0.5)
		_check(_measure_ok(Vector2(1600, 900), ns, cur), "원래 모니터로 → 1600×900 포인트 (잰 값 %s)" % str(_measured(ns, cur)))
	# 상점 (dev 판은 광고 카드가 보이고, stove 판은 숨김)
	root.get_node("Platform").call("override_store", "stove")
	store.call("set_json", "game_save", {"gold": 50000.0, "cleared": [1, 2, 3]})
	router.call("go", "shop")
	await _until(func() -> bool: return _scene_is("ui/shop.gd"), 5.0)
	await _wait(0.5)
	_check(current_scene.find_child("AdCard", true, false) == null, "stove 판 상점: 광고 카드 없음")
	await _shot("06_shop_stove")
	current_scene.call("switch_tab", "gold")
	await _wait(0.3)
	_check(current_scene.find_child("AdCard", true, false) == null and current_scene.find_child("IapGrid", true, false).get_child_count() == 4, "stove 판 골드 탭: 광고 없음 · 결제 카드 4개")
	await _shot("07_shop_stove_gold")
	root.get_node("Platform").call("override_store", "")
	router.call("go", "lobby")
	await _wait(0.6)
	# 창 닫기와 같은 저장 (창 크기·위치)
	auto_accept_quit = false
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await _frames(2)
	var saved: Dictionary = DisplayT.sanitize(store.call("get_json", DisplayT.KEY, {}))
	_check(saved.get("mode") == "windowed" and int(saved.get("w", 0)) == 1600 and int(saved.get("h", 0)) == 900 and saved.has("x"), "창 닫기 → 창 크기·위치 저장 %s" % str(saved))
	print("  PC5_SAVED %s" % JSON.stringify(saved))


func _verify() -> void:
	var saved: Dictionary = DisplayT.sanitize(store.call("get_json", DisplayT.KEY, {}))
	_check(saved.has("w"), "1차 실행에서 저장한 창 상태 있음 %s" % str(saved))
	if not saved.has("w"):
		return
	_check(_logical_is(Vector2i(int(saved["w"]), int(saved["h"]))) and root.mode == Window.MODE_WINDOWED, "다음 실행: 창 크기 %d×%d 복원 (%s)" % [int(saved["w"]), int(saved["h"]), _state()])
	_check(root.position == Vector2i(int(saved["x"]), int(saved["y"])), "다음 실행: 창 위치 %s 복원 (지금 %s)" % [str(Vector2i(int(saved["x"]), int(saved["y"]))), str(root.position)])
	change_scene_to_file("res://scenes/boot.tscn")
	await _until(func() -> bool: return _scene_is("ui/lobby.gd"), 8.0)
	await _wait(0.8)
	await _shot("08_restored_lobby")
	# 전체 화면으로 저장해 두면 다음 실행은 전체 화면 (저장 → 다시 manage)
	display.call("set_mode", "fullscreen")
	var ok := await _until(func() -> bool: return root.mode == Window.MODE_FULLSCREEN, 6.0)
	await _wait(1.0)
	display.call("set_mode", "windowed")
	await _until(func() -> bool: return root.mode == Window.MODE_WINDOWED, 6.0)
	await _wait(0.8)
	_check(ok and _logical_is(Vector2i(int(saved["w"]), int(saved["h"]))), "전체 화면 ↔ 창 뒤에도 저장 크기 그대로 (%s)" % _state())
