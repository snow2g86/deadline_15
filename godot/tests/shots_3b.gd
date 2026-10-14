extends SceneTree
## 3b 화면 사진 (창 모드 — --headless 로 돌리지 말 것):
##   Godot --path godot --resolution 1280x720 --script res://tests/shots_3b.gd
##  → godot/tests/screens/3b_hud.png · 3b_popup_tooltip.png · 3b_preview.png · 3b_vfx.png · 3b_result.png · 3b_story.png · 3b_story_battle.png
##  황금 기록의 명령을 화면 입구로 넣어 원하는 상태를 만든 뒤 화면을 그대로 저장 (저장은 user://test_shots_save.json — 진짜 세이브 무관)

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
	print("── 3b 화면 사진 ──")
	store = root.get_node("Store")
	store.call("use_path", "user://test_shots_save.json")
	store.call("clear")
	store.call("set_json", "game_settings", {"language": "ko", "playSpeed": 1})
	root.get_node("I18n").call("reload")

	# ① HUD 전체 + ② 적 팝업·툴팁
	var sc := _launch("legion5_s09", 1.0, "off")
	await _wait_menu(sc)
	await _secs(2.6)
	await _shot("3b_hud")
	var enemy := -1
	var ally := -1
	for uv: Node in sc.units.values():
		if uv.d["team"] == "enemy" and uv.visible and enemy < 0:
			enemy = uv.id
		if uv.d["team"] == "ally" and ally < 0 and uv.id != sc.awaiting_unit_id():
			ally = uv.id
	if enemy < 0:
		for uv2: Node in sc.units.values():
			if uv2.d["team"] == "enemy":
				enemy = uv2.id
				uv2.visible = true
				break
	_center_on(sc, [enemy, ally])
	await _frames(3)
	sc.show_enemy_popup(enemy)
	sc._hover_key = "u:%d" % ally
	sc._hover_pos = sc._unit_screen(ally) + Vector2(4, 10)
	sc._hover_t = 1.0
	await _secs(0.4)
	await _shot("3b_popup_tooltip")
	sc.ui.info.hide_popup()
	sc._hover_key = ""
	sc.queue_free()
	await _frames(3)

	# ③ 공격 예상 + ④ 큰 연출 (처치하는 공격 — 투사체·타격·죽음 입자·화면 흔들림)
	var gname := "mono_warrior_s03"
	var events: Array = (JsonExact.parse(FileAccess.get_file_as_string("res://tests/golden/%s.json" % gname)) as Dictionary)["events"]
	var cmds := _cmds(gname)
	var kill_ci := -1
	var k_i := -1
	for ei in events.size():
		var ev: Dictionary = events[ei]
		if ev["ev"] == "cmd":
			k_i += 1
			if ev["op"] == "attack":
				for ej in range(ei + 1, mini(events.size(), ei + 30)):
					if events[ej]["ev"] == "cmd":
						break
					if events[ej]["ev"] == "unit_killed" and int(events[ej].get("killer", -1)) == int(ev["u"]):
						kill_ci = k_i
						break
			if kill_ci >= 0:
				break
	sc = _launch(gname, 0.0, "off")
	var ci := 0
	var target_cmd: Dictionary = {}
	while ci < cmds.size():
		await _wait_menu(sc)
		if sc.is_over():
			break
		if ci == kill_ci:
			target_cmd = cmds[ci]
			break
		_drive(sc, cmds[ci])
		ci += 1
	sc.set_speed_index(0)
	await _frames(2)
	if not target_cmd.is_empty():
		sc.ui_action("attack")
		var tu: Variant = null
		for u: Dictionary in sc.eng.S["units"]:
			if int(u["x"]) == int(target_cmd["x"]) and int(u["y"]) == int(target_cmd["y"]) and float(u["hp"]) > 0.0:
				tu = u
		_center_on(sc, [sc.awaiting_unit_id(), int(tu["id"]) if tu != null else -1])
		sc._show_previews(sc.eng.awaiting_unit(), sc.eng.q.attack_targets(sc.eng.awaiting_unit()))
		await _secs(0.6)
		await _shot("3b_preview")
		sc.ui_click_cell(int(target_cmd["x"]), int(target_cmd["y"]))
		# 맞는 순간: 픽셀 임팩트가 터지고 죽음 입자가 퍼질 때
		var t0 := Time.get_ticks_msec()
		var shot := false
		while Time.get_ticks_msec() - t0 < 3000:
			await process_frame
			# 죽음 입자(25개)와 타격 불꽃이 함께 퍼진 직후
			if sc.fx._parts.size() >= 30:
				await _frames(3)
				await _shot("3b_vfx")
				shot = true
				break
		if not shot:
			await _shot("3b_vfx")
	sc.queue_free()
	await _frames(3)

	# ⑤ 결과 (첫 클리어 — 별·보상·새 클랜원·경험치)
	sc = _launch("firstclear_s02", 0.0, "off")
	cmds = _cmds("firstclear_s02")
	ci = 0
	var t1 := Time.get_ticks_msec()
	while not sc.is_over() and Time.get_ticks_msec() - t1 < 60000:
		await process_frame
		if sc.is_awaiting() and ci < cmds.size():
			_drive(sc, cmds[ci])
			ci += 1
	await _secs(1.8)
	await _shot("3b_result")
	sc.queue_free()
	await _frames(3)

	# ⑥ 스토리 (전투 전 장면 — 초상화 둘·이름표) · ⑦ 전투 중 짧은 대사 (보스)
	sc = _launch("boss_s10", 1.0, "on")
	var t2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 15000:
		await process_frame
		if sc.ui.story.active and sc._story_cur.get("key", "") == "s10_pre":
			break
		if sc.ui.story.active and str(sc._story_cur.get("key", "")).begins_with("ep"):
			sc.ui.story.skip()
	# 둘째 줄까지 넘기고 글자가 다 나올 때까지
	sc.ui.story.advance()
	sc.ui.story.advance()
	sc.ui.story.advance()
	await _secs(1.6)
	await _shot("3b_story")
	sc.ui.story.skip()
	await _secs(0.4)
	if sc.ui.story.active:
		sc.ui.story.skip()
		await _secs(0.4)
	await _wait_menu(sc)
	var bl: Variant = sc.story.lines_of("s10_boss")
	if bl is Array:
		sc._story_play([{"key": "shot_boss", "lines": bl, "title": "", "battle": true}])
		await _secs(2.2)
		await _shot("3b_story_battle")
	sc.queue_free()
	await _frames(3)
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_shots_save.json"))
	print("RESULT: DONE")
	quit(0)
