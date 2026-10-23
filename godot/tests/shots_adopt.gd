extends SceneTree
## 전투 UI 도입 1~4 · 왼쪽 클랜원 패널 화면 사진 (창 모드 — --headless 금지):
##   HOME=<임시> Godot --path godot --resolution 1280x720 --script res://tests/shots_adopt.gd -- --tag after --lang ko [--dev pixel8|iphone|ipad|low] [--out <폴더>] [--phase layout|all]
##  사진: <out>/<tag>_<기기or해상도>_<언어>_<이름>.png   저장은 user://test_shots_save.json

const BattleScene := preload("res://scripts/battle/battle_scene.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")
const MobileT := preload("res://scripts/core/mobile.gd")
const SCENE := "res://scenes/battle/battle.tscn"

var _opt := {"tag": "after", "lang": "ko", "dev": "", "out": "", "phase": "layout"}
var store: Node


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


func _secs(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var dir := str(_opt["out"])
	DirAccess.make_dir_recursive_absolute(dir)
	var label: String = str(_opt["dev"]) if str(_opt["dev"]) != "" else "%dx%d" % [root.size.x, root.size.y]
	var path := "%s/%s_%s_%s_%s.png" % [dir, _opt["tag"], label, _opt["lang"], name]
	img.save_png(path)
	print("  사진: " + path)


func _launch(name: String) -> Node:
	var cfg := BattleScene.golden_cfg(name)
	cfg["speed"] = 1.0
	cfg["source"] = "test"
	cfg["story"] = "off"
	BattleScene.pending = cfg
	var sc: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	return sc


func _wait_menu(sc: Node, max_s: float = 30.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not sc.is_awaiting() and not sc.is_over() and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await process_frame


func _main() -> void:
	store = root.get_node("Store")
	store.call("use_path", "user://test_shots_save.json")
	store.call("clear")
	store.call("set_json", "game_settings", {"language": _opt["lang"], "playSpeed": 1})
	root.get_node("I18n").call("reload")
	var dev := str(_opt["dev"])
	if dev != "":
		root.get_node("Platform").call("emulate_mobile", true, dev)
		root.size = (MobileT.DEVICES[dev]["size"] as Vector2i) / 2
		root.get_node("Mobile").call("apply")
	await _frames(3)
	var sc := _launch("legion5_s09")
	await _wait_menu(sc)
	await _secs(2.8)
	print("  가시 화면 %s  패널 %s" % [str(root.get_visible_rect().size), str(sc.ui.get("cards_rect"))])
	await _shot("hud_menu")
	if str(_opt["phase"]) == "all":
		await _features(sc)
	sc.queue_free()
	await _frames(3)
	quit(0)


func _cmds(name: String) -> Array:
	var g: Dictionary = JsonExact.parse(FileAccess.get_file_as_string("res://tests/golden/%s.json" % name))
	var out: Array = []
	for e: Dictionary in g["events"]:
		if e["ev"] == "cmd":
			out.append(e)
	return out


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


## 도입 1~4 장면: 순서 바 강조 · 적 범위 · 이동 취소 · 턴 종료 확인 · 공격 예상 + 계산 내역
func _features(sc: Node) -> void:
	# 이동 → 메뉴에 '이동 취소'
	var u: Dictionary = sc.eng.awaiting_unit()
	var cells: Array = sc.eng.q.move_cells(u)
	if not cells.is_empty():
		sc.ui_action("move")
		await _secs(0.4)
		await _shot("2_move_targets")
		sc.ui_click_cell(int(cells[0]["x"]), int(cells[0]["y"]))
		await _wait_menu(sc)
		await _secs(0.8)
		await _shot("2_undo_menu")
		sc.ui_action("undo")
		await _wait_menu(sc)
		await _secs(0.5)
	sc._user_action("wait")
	await _secs(0.4)
	await _shot("2_end_confirm")
	sc.ui.close_end_confirm()
	sc.ui.end_turn_canceled.emit()
	await _frames(3)
	# 공격 대상이 생길 때까지 황금 기록 명령을 사람처럼 따라감 (최대 40번)
	var cmds := _cmds("legion5_s09")
	var i := 0
	while i < cmds.size() and i < 40:
		var uu: Dictionary = sc.eng.awaiting_unit()
		if uu != null and uu["team"] == "ally" and not (sc.eng.q.attack_targets(uu)["attack"] as Array).is_empty():
			break
		_drive(sc, cmds[i])
		i += 1
		await _wait_menu(sc)
		await _secs(0.3)
	var u2: Variant = sc.eng.awaiting_unit()
	if u2 != null and not (sc.eng.q.attack_targets(u2)["attack"] as Array).is_empty():
		sc.ui_action("attack")
		await _secs(0.5)
		await _shot("3_preview_default")
		sc.ui.set_calc_open(true)
		await _secs(0.5)
		await _shot("3_preview_calc")
		sc.ui.set_calc_open(false)
		sc.ui_cancel()
		await _frames(3)
	else:
		print("  (공격 대상이 생기지 않음)")
	var enemy := -1
	for uv: Node in sc.units.values():
		if uv.d["team"] == "enemy" and uv.visible and enemy < 0:
			enemy = uv.id
	if enemy >= 0:
		sc.ui.order.unit_clicked.emit(enemy)
		await _secs(0.5)
		await _shot("1_order_focus")
		sc.set_focus(-1)
		sc.toggle_enemy_range(enemy)
		sc.set_focus(enemy)
		await _secs(0.4)
		await _shot("4_enemy_range")
		sc.clear_enemy_range()
		sc.set_focus(-1)

