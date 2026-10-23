extends SceneTree
## 확률 표시 화면 사진 (창 모드 — --headless 금지):
##   HOME=<임시> Godot --path godot --resolution 1280x720 --script res://tests/shots_odds.gd -- --lang ko [--dev pixel8|iphone|ipad|low] [--out <폴더>]
##  사진: <out>/<기기or해상도>_<언어>_<이름>.png — 상점 장비·소모품(룬)·골드 · 구매 확인 창 · 설정 · 확률 창(구역별로 내려가며)
##  저장은 user://test_shots_odds.json, 가짜 결제 가게(디버그 빌드)

const MobileT := preload("res://scripts/core/mobile.gd")
const Files := preload("res://scripts/core/billing/fake_files.gd")

var _opt := {"lang": "ko", "dev": "", "out": ""}
var store: Node
var router: Node
var i18n: Node


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var k := str(a[i]).trim_prefix("--")
		if _opt.has(k) and i + 1 < a.size():
			_opt[k] = a[i + 1]
			i += 1
		i += 1
	_main.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, secs: float = 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await process_frame
	return cond.call()


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var dir := str(_opt["out"])
	DirAccess.make_dir_recursive_absolute(dir)
	var label: String = str(_opt["dev"]) if str(_opt["dev"]) != "" else "%dx%d" % [root.size.x, root.size.y]
	var path := "%s/%s_%s_%s.png" % [dir, label, _opt["lang"], name]
	img.save_png(path)
	print("  사진: " + path)


func _screen_is(tail: String) -> bool:
	var s := current_scene
	return s != null and s.get_script() != null and str((s.get_script() as Script).resource_path).ends_with(tail) and s.is_node_ready()


func _open(scene: String, params: Dictionary = {}) -> Node:
	router.call("go", scene, params)
	var tail := {"shop": "ui/shop.gd", "settings": "ui/settings_screen.gd"}[scene] as String
	await _until(func() -> bool: return _screen_is(tail), 6.0)
	await _frames(6)
	return current_scene


func _scroll_list(sh: Node, y: float) -> void:
	sh.list_scroll.scroll_vertical = int(y)
	await _frames(3)


func _main() -> void:
	store = root.get_node("Store")
	router = root.get_node("Router")
	i18n = root.get_node("I18n")
	var platform: Node = root.get_node("Platform")
	var billing: Node = root.get_node("Billing")
	store.call("use_path", "user://test_shots_odds.json")
	store.call("clear")
	store.call("set_json", "game_settings", {"language": _opt["lang"], "playSpeed": 1})
	store.call("set_json", "game_save", {"gold": 50000, "cleared": [1, 2, 3]})
	store.call("flush")
	i18n.call("reload")
	platform.call("override_store", "dev")
	billing.call("_ensure_backend")
	Files.reset()
	billing.set_scenario("success")
	var dev := str(_opt["dev"])
	if dev != "":
		platform.call("emulate_mobile", true, dev)
		root.size = (MobileT.DEVICES[dev]["size"] as Vector2i) / 2
		root.get_node("Mobile").call("apply")
	await _frames(3)
	# 상점 장비 탭: 위쪽(확률 줄·천장) · 뽑기 카드
	var sh := await _open("shop", {"tab": "equip"})
	await _shot("shop_equip_top")
	var g1: Node = sh.list.find_child("Rates", true, false)   # 확률 줄 + 뽑기 카드 두 장이 한 화면에
	await _scroll_list(sh, g1.get_global_rect().position.y - sh.list_scroll.get_global_rect().position.y + sh.list_scroll.scroll_vertical - 6.0)
	await _shot("shop_equip_cards")
	var g2: Node = sh.list.find_child("Gacha1", true, false)   # 모바일은 카드가 커서 한 장면 더: 카드 맨 위부터 구매 단추까지
	await _scroll_list(sh, g2.get_global_rect().position.y - sh.list_scroll.get_global_rect().position.y + sh.list_scroll.scroll_vertical - 6.0)
	await _shot("shop_equip_cards_buy")
	# 소모품 탭: 룬 카드
	sh.switch_tab("consumable")
	await _frames(4)
	await _shot("shop_consumable_rune")
	# 골드 탭 + 구매 확인 창
	sh.switch_tab("gold")
	await _frames(4)
	await _shot("shop_gold")
	sh._act_frame = -1
	sh.buy_iap("gold_1200")
	await _frames(5)
	await _shot("shop_iap_confirm")
	sh.close_all_modals()
	await _frames(2)
	# 확률 창 (구역마다 내려가며)
	sh.switch_tab("equip")
	await _frames(3)
	sh._act_frame = -1
	sh.open_odds()
	await _frames(6)
	await _shot("odds_0_top")
	var modal: Node = sh.find_child("OddsModal", true, false)
	var sc: ScrollContainer = null
	for n: Node in modal.find_children("*", "ScrollContainer", true, false):
		sc = n as ScrollContainer
	var body: Node = modal.find_child("OddsBody", true, false)
	var shown := 0
	for id: String in ["pity", "kinds", "legends", "enh_opt_1", "enh_opt_3", "enh_opt_4", "stat_base", "stat_sub"]:
		var secn: Control = body.find_child("Sec_" + id, true, false)
		if secn == null or sc == null:
			continue
		sc.scroll_vertical = int(secn.get_global_rect().position.y - sc.get_global_rect().position.y + sc.scroll_vertical - 8.0)
		await _frames(4)
		shown += 1
		await _shot("odds_%d_%s" % [shown, id])
	sh.close_all_modals()
	# 설정
	var ss := await _open("settings")
	var scr: ScrollContainer = ss.find_child("Scroll", true, false)
	if scr != null:
		scr.scroll_vertical = 100000
		await _frames(4)
	await _shot("settings")
	ss.find_child("OddsInfo", true, false).pressed.emit()
	await _frames(6)
	await _shot("settings_odds")
	ss.close_all_modals()
	platform.call("override_store", "")
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_shots_odds.json"))
	Files.reset()
	quit(0)
