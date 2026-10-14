extends SceneTree
## 6개 언어 화면 사진 — 새 언어(ja·zh-CN·zh-TW)의 전투 HUD·설정 창·스토리 (창 모드 — --headless 로 돌리지 말 것):
##   Godot --path godot --resolution 1280x720 --script res://tests/shots_lang6.gd
##  → godot/tests/screens/lang6_godot_<언어>_hud.png · _settings.png · _story.png · _story_battle.png (git 제외)
##  저장은 user://test_shots_save.json — 진짜 세이브 무관

const BattleScene := preload("res://scripts/battle/battle_scene.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")
const SCENE := "res://scenes/battle/battle.tscn"
const OUT := "res://tests/screens/"

var store: Node


func _initialize() -> void:
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path := ProjectSettings.globalize_path(OUT + name + ".png")
	img.save_png(path)
	print("  사진: " + path)


func _cmds(name: String) -> Array:
	var g: Dictionary = JsonExact.parse(FileAccess.get_file_as_string("res://tests/golden/%s.json" % name))
	var out: Array = []
	for e: Dictionary in g["events"]:
		if e["ev"] == "cmd":
			out.append(e)
	return out


func _launch(name: String, speed: float, story: String) -> Node:
	var cfg := BattleScene.golden_cfg(name)
	cfg["speed"] = speed
	cfg["source"] = "test"
	cfg["story"] = story
	BattleScene.pending = cfg
	var sc: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	return sc


func _wait_menu(sc: Node, max_s: float = 30.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not sc.is_awaiting() and not sc.is_over() and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await process_frame


## 명령 하나를 화면 입구로 (check_battle_scene._drive 와 같음)
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


func _center_on(sc: Node, ids: Array) -> void:
	var p := Vector2.ZERO
	var n := 0
	for id: int in ids:
		if sc.units.has(id):
			p += sc.units[id].position
			n += 1
	if n > 0:
		sc.cam.position = p / n + Vector2(0, 30)


func _main() -> void:
	print("── 6개 언어 화면 사진 ──")
	store = root.get_node("Store")
	store.call("use_path", "user://test_shots_save.json")
	for lang: String in ["ja", "zh-CN", "zh-TW"]:
		store.call("clear")
		store.call("set_json", "game_settings", {"language": lang, "playSpeed": 1})
		root.get_node("I18n").call("reload")
		# HUD + 적 팝업
		var sc := _launch("legion5_s09", 1.0, "off")
		await _wait_menu(sc)
		await _secs(2.6)
		var enemy := -1
		for uv: Node in sc.units.values():
			if uv.d["team"] == "enemy" and uv.visible and enemy < 0:
				enemy = uv.id
		if enemy >= 0:
			_center_on(sc, [enemy, sc.awaiting_unit_id()])
			await _frames(3)
			sc.show_enemy_popup(enemy)
			await _secs(0.4)
		await _shot("lang6_godot_%s_hud" % lang)
		sc.ui.info.hide_popup()
		sc.ui.settings.open()
		await _secs(0.5)
		await _shot("lang6_godot_%s_settings" % lang)
		sc.ui.settings.close()
		sc.queue_free()
		await _frames(3)
		# 스토리 (전투 전 장면) · 전투 중 짧은 대사
		sc = _launch("boss_s10", 1.0, "on")
		var t2 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t2 < 15000:
			await process_frame
			if sc.ui.story.active and sc._story_cur.get("key", "") == "s10_pre":
				break
			if sc.ui.story.active and str(sc._story_cur.get("key", "")).begins_with("ep"):
				sc.ui.story.skip()
		sc.ui.story.advance()
		sc.ui.story.advance()
		sc.ui.story.advance()
		await _secs(1.8)
		await _shot("lang6_godot_%s_story" % lang)
		sc.ui.story.skip()
		await _secs(0.4)
		if sc.ui.story.active:
			sc.ui.story.skip()
			await _secs(0.4)
		await _wait_menu(sc)
		var bl: Variant = sc.story.lines_of("s10_boss")
		if bl is Array:
			sc._story_play([{"key": "shot_boss", "lines": bl, "title": "", "battle": true}])
			await _secs(2.4)
			await _shot("lang6_godot_%s_story_battle" % lang)
		sc.queue_free()
		await _frames(3)
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_shots_save.json"))
	print("RESULT: DONE")
	quit(0)
