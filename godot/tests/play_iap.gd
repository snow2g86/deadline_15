extends SceneTree
## 결제층 A 실제 창 시험 — 진짜 입력(Input.parse_input_event)으로 상점 결제 흐름 한 번 (가짜 가게 · 가짜 서버, 디버그 빌드)
##  로비 → 아래 탭 상점 → 골드 탭 → 1,200 골드 '구매' → 구매 확인 창(청약철회·미성년자 안내) → '구매' → 진행 중 → 결과 → 골드 배지
##  → 용병 탭 광고 카드 '광고 보기' → 가짜 광고 → 끝까지 → '보상 받고 닫기' → 보상 창 → 장비 탭 '확률 정보' 창
##   caffeinate -d Godot --path godot --resolution 1280x720 --script res://tests/play_iap.gd   → tests/screens/iapA_*.png
##  저장은 user://test_play_iap_save.json, 가짜 가게·서버는 user://fake_iap/ (끝나면 지움). 끝 줄 PLAY_RESULT: OK|FAIL

const OUT := "res://tests/screens/"
const PlayKit := preload("res://tests/play_kit.gd")
const SAVE := "user://test_play_iap_save.json"
const JsonX := preload("res://scripts/core/json_exact.gd")
const Js := preload("res://scripts/logic/js.gd")
const Files := preload("res://scripts/core/billing/fake_files.gd")

var store: Node
var billing
var ads
var log_lines: Array = []
var fails: Array = []
var _shot_n := 0


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


func _ok(cond: bool, what: String) -> void:
	var s := ("OK  " if cond else "FAIL ") + what
	print("  " + s)
	log_lines.append(s)
	if not cond:
		fails.append(what)


func _shot(name: String) -> void:
	await _frames(4)
	if not await PlayKit.post_draw(self, 5.0):
		_ok(false, "화면 그리기(frame_post_draw)를 5초 안에 받지 못함 (%s)" % name)
		return
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_shot_n += 1
	var path := ProjectSettings.globalize_path(OUT + "iapA_%02d_%s.png" % [_shot_n, name])
	img.save_png(path)
	print("  사진: " + path)


func _win(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _click(p0: Vector2) -> void:
	var p := _win(p0)
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


## 맨 위 창(모달)부터 이름으로 찾기 — 없으면 화면에서
func _find(n: String) -> Node:
	if current_scene == null:
		return null
	var layer: Node = current_scene.find_child("Layer", true, false)
	if layer != null:
		var kids := layer.get_children()
		kids.reverse()
		for m: Node in kids:
			if m.is_queued_for_deletion():
				continue
			var f: Node = m.find_child(n, true, false)
			if f != null:
				return f
	return current_scene.find_child(n, true, false)


func _click_ctl(c0: Variant, what: String) -> bool:
	var c: Variant = c0
	if typeof(c0) == TYPE_STRING:
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


func _scene_is(tail: String) -> bool:
	var s := current_scene
	return s != null and s.get_script() != null and str((s.get_script() as Script).resource_path).ends_with(tail) and s.is_node_ready()


func _gold() -> float:
	return Js.num((store.call("get_json", "game_save", {}) as Dictionary).get("gold"))


func _main() -> void:
	print("  창 %s · 뷰포트 %s" % [str(DisplayServer.window_get_size()), str(root.size)])
	store = root.get_node("Store")
	billing = root.get_node("Billing")
	ads = root.get_node("Ads")
	store.call("use_path", SAVE)
	store.call("clear")
	Files.reset()
	root.get_node("I18n").call("set_language", "ko")
	var fx: Dictionary = JsonX.parse(FileAccess.get_file_as_string("res://tests/fixtures/outer_4b1_web.json"))
	var st: Dictionary = fx["equip"][0]["store"]
	for k: String in st.keys():
		store.call("set_json", k, st[k])
	store.call("set_json", "game_save", {"gold": 5000, "cleared": [1, 2, 3]})
	store.call("set_json", "game_settings", {"language": "ko", "playSpeed": 4})
	store.call("set_json", "game_story_seen", {"ep1_pro": true, "s1_pre": true, "s1_start": true})
	store.call("flush")
	_ok(billing.set_scenario("success"), "가짜 가게 시나리오 success (디버그 빌드)")
	billing.backend.delay = 1.2   # 진행 중 창을 사진에 담을 만큼
	ads.fake_secs = 2.0
	change_scene_to_file("res://scenes/boot.tscn")
	_ok(await _until(func() -> bool: return _scene_is("ui/lobby.gd"), 8.0), "시작 → 로비")
	await _wait(0.6)
	await _click_ctl("Tab_shop", "아래 탭 상점")
	_ok(await _until(func() -> bool: return _scene_is("ui/shop.gd"), 5.0), "아래 탭 → 상점")
	await _wait(0.3)
	await _click_ctl("Tab_gold", "골드 탭")
	await _wait(0.4)
	var price: Label = _find("Iap_gold_1200").find_child("Price", true, false) if _find("Iap_gold_1200") != null else null
	_ok(price != null and price.text == "₩2,500", "골드 탭: 결제 카드 · 가격 ₩2,500 (가짜 가게 가격)")
	await _shot("gold_tab")
	var g0 := _gold()
	await _click_ctl(_find("Iap_gold_1200").find_child("Buy", true, false), "1,200 골드 구매")
	await _wait(0.3)
	_ok(_find("IapConfirmModal") != null and _find("notice_minor") != null, "구매 확인 창 (청약철회 · 사용한 재화 · 미성년자 안내)")
	await _shot("confirm")
	await _click_ctl("Yes", "확인 창 '구매'")
	await _wait(0.2)
	_ok(_find("IapProgress") != null and bool(billing.busy()), "결제 진행 중 창")
	await _shot("processing")
	_ok(await _until(func() -> bool: return not bool(billing.busy()) and _find("Alert") != null, 6.0), "결과 창")
	await _wait(0.3)
	var al: Node = _find("Alert")
	_ok(al != null and str(al.get_meta("iap_status", "")) == "granted" and _gold() == g0 + 1200.0, "결제 완료: 골드 %s → %s" % [g0, _gold()])
	await _shot("result")
	await _click_ctl("Ok", "결과 창 확인")
	await _wait(0.3)
	_ok(current_scene.gold_lbl.text == "6,200 G", "골드 배지 6,200 G")
	var orders: Dictionary = (store.call("get_json", "game_iap", {}) as Dictionary).get("orders", {})
	_ok(orders.size() == 1 and str(orders.values()[0]["st"]) == "done", "결제 기록 1개 · done (서버 consume · 가게 finish)")
	await _shot("after")
	# ── 광고 ──
	await _click_ctl("Tab_mercenary", "용병 탭")
	await _wait(0.3)
	await _click_ctl("AdBtn", "광고 보기")
	await _wait(0.4)
	_ok(ads.find_child("FakeAd", true, false) != null, "가짜 광고 화면")
	var ad_root: Node = ads.find_child("FakeAd", true, false)
	await _shot("fake_ad")
	var close_b: Button = ad_root.find_child("AdClose", true, false) if ad_root != null else null
	_ok(close_b != null and await _until(func() -> bool: return close_b.text == root.get_node("I18n").call("t", "gd.ads.close_reward"), 5.0), "광고 끝까지 → '보상 받고 닫기'")
	await _shot("fake_ad_done")
	var g1 := _gold()
	await _click(close_b.get_global_rect().get_center())
	await _wait(0.3)
	_ok(_gold() == g1 + 100.0 and _find("Alert") != null, "광고 보상 +100 (%s → %s)" % [g1, _gold()])
	await _shot("ad_reward")
	await _click_ctl("Ok", "보상 창 확인")
	await _wait(0.3)
	var left: Label = _find("AdLeft")
	_ok(left != null and left.text.contains("2/3"), "오늘 남은 광고 2/3")
	# ── 확률 정보 ──
	await _click_ctl("Tab_equip", "장비 탭")
	await _wait(0.3)
	await _click_ctl("OddsBtn", "확률 정보")
	await _wait(0.4)
	_ok(_find("OddsModal") != null, "확률 정보 창")
	await _shot("odds")
	await _click_ctl("Ok", "확률 창 닫기")
	await _wait(0.2)
	var ok := fails.is_empty()
	print("PLAY_LOG: " + " | ".join(log_lines))
	print("PLAY_RESULT: %s (%d개)" % ["OK" if ok else "FAIL " + str(fails), log_lines.size()])
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Files.reset()
	quit(0 if ok else 1)
