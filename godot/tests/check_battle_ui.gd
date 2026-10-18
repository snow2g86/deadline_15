extends SceneTree
## 3b UI 연기 시험 — 전투 장면을 띄워 모든 패널·팝업·툴팁·메뉴·결과·스토리·로딩·연출을 한 번씩 열고, 언어를 바꿔도 오류가 없는지
##   Godot --headless --path godot --script res://tests/check_battle_ui.gd
##  Godot 오류(push_error·스크립트 오류)는 Logger 로 세어 0 이어야 통과. 저장은 user://test_battle_ui_save.json (진짜 세이브는 건드리지 않음)

const BaselineData := preload("res://tests/baseline_data.gd")
const BattleScene := preload("res://scripts/battle/battle_scene.gd")
const PixelFx := preload("res://scripts/battle/pixel_fx.gd")
const JsonX := preload("res://scripts/core/json_exact.gd")
const FontsT := preload("res://scripts/core/fonts.gd")
const SCENE := "res://scenes/battle/battle.tscn"
const SAVE := "user://test_battle_ui_save.json"

var _fails: Array = []
var _passes := 0
var _counter: ErrCounter


class ErrCounter extends Logger:
	var errors: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	BaselineData.apply(self)   # 황금 기록·기준 데이터 (tests/baseline_data.gd)
	_counter = ErrCounter.new()
	OS.add_logger(_counter)
	_main.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
	else:
		_fails.append(what)
		print("  FAIL " + what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## 조건이 맞을 때까지 (실제 시간 secs 까지) — 트윈은 실제 시간으로 흐르고 머리 없는 실행은 프레임이 아주 짧음
func _until(cond: Callable, secs: float = 2.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await process_frame
	return cond.call()


func _main() -> void:
	print("── 3b UI 연기 시험 (패널·팝업·툴팁·결과·스토리·언어) ──")
	var store: Node = root.get_node("Store")
	var i18n: Node = root.get_node("I18n")
	store.call("use_path", SAVE)
	store.call("clear")
	i18n.call("reload")
	var cfg := BattleScene.golden_cfg("legion5_s09")
	cfg["speed"] = 0.0
	cfg["source"] = "test"
	cfg["story"] = "auto"
	BattleScene.pending = cfg
	var sc: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	var f := 0
	while not sc.is_awaiting() and f < 3000:
		await process_frame
		f += 1
	_check(sc.is_awaiting(), "입력 대기까지 옴")
	sc.set_speed_index(0)   # 이제부터 실제 연출 속도 (애니메이션 경로도 지나게)
	var ui: Node = sc.ui
	await _frames(3)

	# ── 윗줄·행동 순서·카드·미니맵 ──
	var chip_names: Array = []
	for c: Node in ui.top.chips.get_children():
		chip_names.append(str(c.name))
	_check(chip_names.has("Chip_wave") and chip_names.has("Chip_foe") and chip_names.has("Chip_hazard") and chip_names.has("Chip_syn"), "윗줄 칩 (증원·적·환경·조합) %s" % str(chip_names))
	var hz_tip := ""
	for c2: Node in ui.top.chips.get_children():
		if str(c2.name) == "Chip_hazard":
			hz_tip = (c2 as Control).tooltip_text
	_check(hz_tip.contains("—"), "환경 칩 툴팁 = 이름 — 설명 (%s)" % hz_tip)
	var vis_rows := 0
	for r: Node in ui.order.get_children():
		if r is PanelContainer and (r as Control).visible:
			vis_rows += 1
	_check(vis_rows >= 3, "행동 순서 줄 %d" % vis_rows)
	var vis_cards := 0
	for c3: Node in ui.cards.row.get_children():
		if (c3 as Control).visible:
			vis_cards += 1
	_check(vis_cards >= 3, "클랜원 카드 %d" % vis_cards)
	var cam_before: Vector2 = sc.cam.position
	ui.minimap.pan_to.emit(Vector2(120, 140))
	_check(sc.cam.position.distance_to(cam_before) > 1.0, "미니맵 누르기 → 카메라 이동")
	var ally_id := -1
	var enemy_id := -1
	for uv: Node in sc.units.values():
		if uv.d["team"] == "ally" and ally_id < 0:
			ally_id = uv.id
		if uv.d["team"] == "enemy" and uv.visible and enemy_id < 0:
			enemy_id = uv.id
	if enemy_id < 0:
		for uv2: Node in sc.units.values():
			if uv2.d["team"] == "enemy":
				enemy_id = uv2.id
				break
	ui.cards.unit_clicked.emit(ally_id)
	ui.order.unit_clicked.emit(ally_id)
	ui.cards.unit_hover.emit(ally_id)
	_check(sc.units[ally_id].hover, "카드에 마우스 → 맵 유닛 강조")
	ui.cards.unit_hover.emit(-1)
	_check(not sc.units[ally_id].hover, "강조 해제")
	await _frames(20)

	# ── 툴팁 (유닛·칸) · 적 팝업 ──
	sc._hover_key = "u:%d" % ally_id
	sc._hover_pos = Vector2(300, 420)
	ui.hide_menu()
	sc._hover_t = 0.0
	sc._update_hover(0.3)
	_check(ui.info.tip.visible, "유닛 툴팁")
	var stops: Array = []
	var st_stack: Array = [ui.info.tip]
	while not st_stack.is_empty():
		var nd: Node = st_stack.pop_back()
		if nd is Control and (nd as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			stops.append(str(nd.name))
		st_stack.append_array(nd.get_children())
	_check(stops.is_empty(), "툴팁 안 부품은 모두 마우스 무시 %s" % str(stops))
	sc._hover_key = "c:3,4"
	sc._hover_t = 0.0
	sc._update_hover(0.3)
	_check(ui.info.tip.visible, "칸 툴팁")
	sc.show_enemy_popup(enemy_id)
	await _frames(2)
	_check(ui.info.popup.visible and ui.info.popup_unit == enemy_id, "적 정보 팝업")
	var pm: Dictionary = sc._unit_model(sc.units[enemy_id], true)
	_check(not (pm.get("skills", []) as Array).is_empty() and str(pm.get("ai", "")) != "", "팝업: 스킬·AI 성향 (%s)" % str(pm.get("ai", "")))
	sc.ui_cancel()
	_check(not ui.info.popup.visible, "취소로 팝업 닫힘")

	# ── 행동 메뉴·하위 메뉴·공격 예상·방향 고르기 ──
	sc._show_main_menu(sc.eng.awaiting_unit())
	await _frames(2)
	_check(ui.menu.visible and ui.menu_buttons.size() >= 3, "행동 메뉴 단추 %d" % ui.menu_buttons.size())
	var has_tex := false
	for mb: Dictionary in ui.menu_buttons:
		if mb["item"].get("tex") is Texture2D:
			has_tex = true
	_check(has_tex, "행동 메뉴에 그림 아이콘")
	if sc.ui_action("skill"):
		await _frames(2)
		_check(sc.mode == "skills" and ui.menu.visible, "스킬 하위 메뉴")
		sc.ui_cancel()
	if (sc.eng.S["_battlePotions"] as Array).size() + (sc.eng.S["_siegeItems"] as Array).size() > 0:
		sc.ui_action("item")
		await _frames(2)
		_check(sc.mode == "items", "아이템 하위 메뉴")
		sc.ui_cancel()
	sc.ui_action("attack")
	await _frames(2)
	_check(sc.mode == "target", "공격 칸 고르기")
	sc.ui_cancel()
	sc.ui_action("move")
	await _frames(2)
	_check(sc.mode == "target", "이동 칸 고르기")
	sc.ui_cancel()
	sc.ui_action("wait")
	await _frames(2)
	_check(sc.mode == "face" and not sc.fx.picker.is_empty(), "방향 고르기")
	sc.ui_cancel()
	_check(sc.mode == "menu", "취소 → 메뉴")

	# ── 카메라·위협 ──
	for k in 4:
		sc.rotate_cam(1)
		await _frames(2)
	_check(sc.iso.cam_dir == 0, "카메라 네 번 회전")
	sc.toggle_threat()
	await _frames(2)
	_check(sc.show_threat and ui.top.threat_btn.button_pressed, "위협 범위 켬")
	sc.toggle_threat()

	# ── 설정·언어 ──
	ui.settings.open()
	await _frames(2)
	_check(ui.settings.panel.visible, "설정 창")
	var ph_ko := str(ui.top.ti_label.text)
	var menu_ko := str(ui.menu_buttons[0]["item"]["label"]) if not ui.menu_buttons.is_empty() else ""
	var grid: Node = ui.settings.panel.find_child("LangGrid", true, false)
	_check(grid != null and grid.get_child_count() == 6, "설정 창 언어 단추 6개")
	var natives := {"ko": "한국어", "en": "English", "es": "Español", "ja": "日本語", "zh-CN": "简体中文", "zh-TW": "繁體中文"}
	var prev_top := ph_ko
	var prev_menu := menu_ko
	for code: String in ["en", "es", "ja", "zh-CN", "zh-TW", "ko"]:
		var lb: Button = ui.settings.panel.find_child("Lang_" + code, true, false)
		_check(lb != null and lb.text == natives[code], "언어 단추 %s = %s" % [code, lb.text if lb != null else "?"])
		if lb != null:
			lb.pressed.emit()
		await _frames(3)
		_check(str(i18n.get("current_lang")) == code and FontsT.lang == code, "언어 %s: I18n·글꼴 사슬 바뀜" % code)
		var top_now := str(ui.top.ti_label.text)
		var menu_now := str(ui.menu_buttons[0]["item"]["label"]) if not ui.menu_buttons.is_empty() else ""
		# zh-CN → zh-TW 는 윗줄(我方回合)이 같을 수 있어 둘 중 하나만 바뀌어도 됨
		_check(top_now != prev_top or menu_now != prev_menu, "언어 %s: 윗줄·행동 메뉴 바뀜 (%s → %s / %s → %s)" % [code, prev_top, top_now, prev_menu, menu_now])
		_check(ui.settings.panel.visible and ui.settings.panel.find_child("LangGrid", true, false) != null, "언어 %s: 설정 창 다시 그림" % code)
		prev_top = top_now
		prev_menu = menu_now
	_check(str(i18n.get("current_lang")) == "ko", "언어 ko 로 돌아옴")
	var rm: CheckButton = ui.settings.panel.find_child("Toggle_reduceMotion", true, false)
	_check(rm != null, "움직임 줄이기 스위치")
	if rm != null:
		rm.button_pressed = true
		await _frames(1)
		_check(sc.reduce_motion, "움직임 줄이기 켬")
		rm = ui.settings.panel.find_child("Toggle_reduceMotion", true, false)
		rm.button_pressed = false
	var sp4: Button = ui.settings.panel.find_child("Speed4", true, false)
	if sp4 != null:
		sp4.pressed.emit()
		await _frames(1)
		_check(sc.speed == 4.0, "속도 4x")
	var sp1: Button = ui.settings.panel.find_child("Speed1", true, false)
	if sp1 != null:
		sp1.pressed.emit()
	var sl: HSlider = ui.settings.panel.find_child("Slider_bgmVol", true, false)
	if sl != null:
		sl.value = 30
		var gs: Variant = store.call("get_json", "game_settings", {})
		_check(gs is Dictionary and absf(float(gs.get("bgmVol", 0)) - 0.3) < 0.001, "배경음 음량 저장 (game_settings.bgmVol)")
	ui.settings.ask_surrender()
	await _frames(2)
	_check(ui.settings.confirm_open(), "항복 확인 창")
	var no: Button = ui.settings.confirm.find_child("No", true, false)
	no.pressed.emit()
	_check(not ui.settings.is_open() and not sc.is_over(), "항복 취소")

	# ── 띠·번쩍임·로딩 ──
	ui.show_banner("WAVE", 0.5)
	ui.show_stage_banner("EP.1-9", "TEST")
	ui.turn_flash("enemy")
	ui.big_flash(Color(1, 0.8, 0.2, 0.2))
	ui.loading.show_for("STAGE 9", "tip")
	ui.loading.progress(0.5)
	ui.loading.finish(true)
	await _frames(30)
	_check(not ui.loading.visible, "로딩 화면 닫힘")

	# ── 연출 (직업별 타격·픽셀 투사체·죽음·회복·공성·소환·흔들림) ──
	var a: Vector2 = sc.units[ally_id].position + Vector2(0, -24)
	var t: Vector2 = sc.units[enemy_id].position + Vector2(0, -24)
	for cls: String in ["warrior", "knight", "assassin", "novice", "brawler", "lancer", "sapper", "summon_golem"]:
		sc.fx.hit_fx(cls, a, t)
	for kind: String in PixelFx.KINDS.keys():
		sc.pfx.shoot(kind, a.x, a.y, t.x, t.y, 200.0)
		sc.pfx.impact(kind, t.x, t.y)
	var M: Dictionary = sc.D["ATK_MOTIONS"]
	for mk: String in M.keys():
		sc.fx.atk_trail(M[mk], a, t, 0.1)
	sc.fx.death_fx(t, false)
	sc.fx.heal_fx(a)
	sc.fx.buff_fx(a)
	sc.fx.summon_fx(a)
	for it: String in ["siege_ladder", "siege_bomb", "siege_bridge"]:
		sc.fx.siege_fx(it, t)
	sc.fx.float_text(3, 4, "🎁 ✓ crit", "crit")
	sc.screen_shake(true)
	sc.units[ally_id].glow()
	sc.units[ally_id].hop()
	sc.units[enemy_id].play_motion(M["warrior"], Vector2.RIGHT)
	await _frames(90)
	_check(true, "연출 실행")

	# ── 스토리 대사 (수동 넘기기·건너뛰기) ──
	ui.story.auto = false
	var lines: Variant = sc.story.lines_of("s9_pre")
	_check(lines is Array and not (lines as Array).is_empty(), "대본 s9_pre")
	sc._story_play([{"key": "test_scene", "lines": lines, "title": "EP.1-9", "battle": false}])
	await _frames(3)
	_check(ui.story.visible and ui.story.active, "대사 창 열림")
	_check(sc._hold > 0, "대사 중 재생 붙잡음")
	ui.story.advance()
	ui.story.advance()
	await _frames(2)
	_check(ui.story._idx >= 1, "대사 넘기기 (%d)" % ui.story._idx)
	ui.story.skip()
	await _until(func() -> bool: return sc.story_log.has("test_scene") and sc._hold == 0)
	_check(not ui.story.active and sc.story_log.has("test_scene"), "건너뛰기 → 닫힘·본 장면 기록")
	_check(sc._hold == 0, "대사 끝 → 붙잡기 풀림")
	# 전투 중 언어를 바꾸면 다음 대사는 바뀐 언어로
	i18n.call("set_language", "en")
	await _frames(2)
	sc._story_play([{"key": "s9_pre", "lines": lines, "title": "", "battle": false}])
	await _frames(2)
	var en_story: Dictionary = root.get_node("DataDB").call("story", "en")
	var en_first := str(en_story["stages"]["9"]["pre"][0]["text"])
	_check(ui.story.active and ui.story._full == sc.story._fmt(en_first), "언어를 바꾼 뒤 대사는 바뀐 언어 (%s)" % ui.story._full.left(30))
	ui.story.skip()
	await _until(func() -> bool: return sc._hold == 0)
	for code: String in ["ja", "zh-CN", "zh-TW"]:
		i18n.call("set_language", code)
		await _frames(2)
		sc._story_play([{"key": "s9_pre", "lines": lines, "title": "", "battle": false}])
		await _frames(2)
		var st_l: Dictionary = root.get_node("DataDB").call("story", code)
		var first_l := str(st_l["stages"]["9"]["pre"][0]["text"])
		_check(ui.story.active and ui.story._full == sc.story._fmt(first_l), "언어 %s: 대사도 그 언어 (%s)" % [code, ui.story._full.left(24)])
		ui.story.skip()
		await _until(func() -> bool: return sc._hold == 0)
	i18n.call("set_language", "ko")
	await _frames(2)
	# 전투 대사 (작은 창) 한 번
	var bl: Variant = sc.story.lines_of("s9_start")
	if bl is Array and not (bl as Array).is_empty():
		sc._story_play([{"key": "test_battle", "lines": bl, "title": "", "battle": true}])
		await _frames(3)
		_check(ui.story.battle_mode and ui.story.active, "전투 대사 모드")
		ui.story.skip()
		await _until(func() -> bool: return sc._hold == 0)

	# ── 항복 → 결과 ──
	sc.surrender()
	var w := 0
	while not ui.result_view.visible and w < 600:
		await process_frame
		w += 1
	_check(ui.result_view.visible and sc.is_over(), "항복 → 결과 화면")
	_check(str(sc.result.get("result")) == "lose" and str(sc.result.get("reason")) == "surrender", "항복 결과 lose/surrender (%s)" % str(sc.result))
	_check(ui.result_view.buttons.has("back") and ui.result_view.buttons.has("retry"), "결과 단추 (돌아가기·다시)")
	i18n.call("set_language", "en")
	await _frames(3)
	var title_lbl: Label = ui.result_view.find_child("Title", true, false)
	_check(title_lbl != null and title_lbl.text.contains("DEFEAT"), "결과 화면 언어 바꿈")
	for code: String in ["ja", "zh-CN", "zh-TW"]:
		i18n.call("set_language", code)
		await _frames(3)
		# 제목(💀 DEFEAT)은 모든 언어에서 같아서, 다시 그린 단추 글자로 확인
		var rb: Variant = ui.result_view.buttons.get("retry")
		var want := str(i18n.call("t", "gd.result.retry"))
		_check(rb is Button and is_instance_valid(rb) and (rb as Button).text.contains(want), "결과 화면 %s: 다시 그림 (%s)" % [code, (rb as Button).text if rb is Button and is_instance_valid(rb) else "?"])
	i18n.call("set_language", "ko")
	await _frames(3)
	sc.queue_free()
	await _frames(3)

	# ── 이긴 판 결과 화면 (보상·별·경험치) ──
	await _win_result()
	# ── 실제 입력: 항복을 마우스 누르기로 (여러 해상도·언어) ──
	for res: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 600), Vector2i(1920, 1080)]:
		for lang: String in (["ko", "es", "ja", "zh-TW"] if res == Vector2i(1024, 600) else ["ko", "es"]):
			await _click_surrender(res, lang)
	root.size = Vector2i(1280, 720)
	i18n.call("set_language", "ko")
	# ── 입력 세부 (팝업 다음 누르기·단축키·메뉴 폭·대기 중 항복 미루기) ──
	await _input_details()
	# ── 실제 세이브 전투: 끝나고 Store 의 다른 키(game_soul·game_mats)를 덮어쓰지 않음 ──
	await _store_writeback()

	OS.remove_logger(_counter)
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("")
	if not _counter.errors.is_empty():
		print("Godot 오류 %d개:" % _counter.errors.size())
		for e: String in _counter.errors.slice(0, 20):
			print("  " + e)
		_fails.append("Godot 오류 %d개" % _counter.errors.size())
	if _fails.is_empty():
		print("RESULT: PASS (%d개 통과, Godot 오류 0)" % _passes)
		quit(0)
	else:
		print("RESULT: FAIL (%d개 실패) %s" % [_fails.size(), str(_fails)])
		quit(1)


## 황금 기록 하나를 화면 입구로 끝까지 → 이긴 결과 화면 내용 확인
func _win_result() -> void:
	const JsonExact := preload("res://scripts/core/json_exact.gd")
	var name := "firstclear_s02"
	var gold: Dictionary = JsonExact.parse(FileAccess.get_file_as_string("res://tests/golden/%s.json" % name))
	var cmds: Array = []
	for e: Dictionary in gold["events"]:
		if e["ev"] == "cmd":
			cmds.append(e)
	var cfg := BattleScene.golden_cfg(name)
	cfg["speed"] = 0.0
	cfg["source"] = "test"
	cfg["story"] = "auto"
	BattleScene.pending = cfg
	var sc: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	var ci := 0
	var f := 0
	while not sc.is_over() and f < 100000:
		await process_frame
		f += 1
		if sc.is_awaiting() and ci < cmds.size():
			var cmd: Dictionary = cmds[ci]
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
			ci += 1
	var w := 0
	while not sc.ui.result_view.visible and w < 3000:
		await process_frame
		w += 1
	_check(sc.ui.result_view.visible and str(sc.result.get("result")) == "win", "%s 승리 결과 화면" % name)
	var m: Dictionary = sc._result_model()
	_check(m.has("stars"), "별 3개·조건")
	var labels: Array = []
	for r: Dictionary in m["rewards"]:
		labels.append(str(r["label"]))
		_check(r.get("tex") is Texture2D, "보상 아이콘 그림: %s" % str(r["label"]))
	_check((m["rewards"] as Array).size() >= 2, "보상 줄 %d (%s)" % [(m["rewards"] as Array).size(), ", ".join(labels)])
	_check(not (m["exp"] as Array).is_empty(), "클랜원 경험치 줄 %d" % (m["exp"] as Array).size())
	var has_next := false
	for b: Dictionary in m["buttons"]:
		if b["id"] == "next":
			has_next = true
	_check(has_next, "다음 스테이지 단추")
	print("  [%s] 보상: %s" % [name, ", ".join(labels)])
	sc.queue_free()
	await _frames(3)


func _click(p: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	root.push_input(mv, true)
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		root.push_input(e, true)
		await process_frame


func _key(k: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		root.push_input(e, true)
		await process_frame


func _on_screen(c: Control) -> bool:
	if c == null or not c.is_visible_in_tree():
		return false
	var r := c.get_global_rect()
	return root.get_visible_rect().encloses(r) and r.size.x > 0.0


func _launch_test(name: String, extra: Dictionary = {}) -> Node:
	var cfg := BattleScene.golden_cfg(name)
	cfg["speed"] = 0.0
	cfg["source"] = "test"
	cfg["story"] = "auto"
	cfg.merge(extra, true)
	BattleScene.pending = cfg
	var sc: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	await _until(func() -> bool: return sc.is_awaiting(), 10.0)
	return sc


## 톱니 → 항복 → 확인을 진짜 마우스 누르기로
func _click_surrender(res: Vector2i, lang: String) -> void:
	root.size = res
	root.get_node("I18n").call("set_language", lang)
	var sc: Node = await _launch_test("balanced_s05")
	await _frames(3)
	var tag := "%dx%d %s" % [res.x, res.y, lang]
	var ui: Node = sc.ui
	await _click(ui.settings.btn.get_global_rect().get_center())
	await _frames(3)
	var sb: Button = ui.settings.panel.find_child("Surrender", true, false)
	_check(ui.settings.panel.visible and _on_screen(ui.settings.panel), "[%s] 설정 창이 화면 안 (%s)" % [tag, str(ui.settings.panel.get_global_rect())])
	if sb != null:
		await _click(sb.get_global_rect().get_center())
	await _frames(3)
	var yes: Button = ui.settings.confirm.find_child("Yes", true, false)
	_check(ui.settings.confirm_open() and _on_screen(ui.settings.confirm), "[%s] 항복 확인 창이 화면 안 (%s)" % [tag, str(ui.settings.confirm.get_global_rect())])
	if yes != null and _on_screen(yes):
		await _click(yes.get_global_rect().get_center())
	await _until(func() -> bool: return ui.result_view.visible, 3.0)
	await _frames(3)
	_check(sc.is_over() and str(sc.result.get("reason")) == "surrender", "[%s] 마우스로 항복 → 결과" % tag)
	var back: Control = ui.result_view.buttons.get("back")
	_check(back != null and _on_screen(back), "[%s] 결과 단추가 화면 안 (스크롤 밖)" % tag)
	sc.queue_free()
	await _frames(3)


func _input_details() -> void:
	var sc: Node = await _launch_test("balanced_s05")
	var ui: Node = sc.ui
	await _frames(2)
	# Space = 대기 (방향 고르기), Backspace = 취소
	await _key(KEY_SPACE)
	_check(sc.mode == "face", "Space → 대기(방향 고르기) (%s)" % sc.mode)
	await _key(KEY_BACKSPACE)
	_check(sc.mode == "menu", "Backspace → 취소 (%s)" % sc.mode)
	# 적 팝업이 떠 있어도 다음 누르기가 그대로 처리됨: 이동 칸 고르기 중 칸을 누르면 팝업 닫힘 + 이동
	var u: Dictionary = sc.eng.awaiting_unit()
	var cells: Array = sc.eng.q.move_cells(u)
	var cell: Variant = null
	for c: Dictionary in cells:
		if sc.iso.tile_z(int(c["x"]), int(c["y"])) == 0.0 and not c.get("vault", false):
			cell = c
			break
	var enemy := -1
	for uv: Node in sc.units.values():
		if uv.d["team"] == "enemy":
			enemy = uv.id
			break
	if cell != null:
		sc.ui_action("move")
		sc.cam.position = sc.iso.top_center(int(cell["x"]), int(cell["y"]))
		await _frames(2)
		sc.show_enemy_popup(enemy)
		await _frames(2)
		var sp: Vector2 = sc.get_viewport().get_canvas_transform() * sc.iso.top_center(int(cell["x"]), int(cell["y"]))
		await _click(sp)
		await _frames(2)
		_check(not ui.info.popup.visible, "팝업 위·밖 누르기 → 팝업 닫힘")
		_check(sc.mode != "target" and str(sc.last_result.get("reason", "?")) != "move_failed", "그 누르기로 이동 명령도 처리 (%s, %s)" % [sc.mode, str(sc.last_result)])
	await _until(func() -> bool: return sc.is_awaiting(), 5.0)
	# HUD 위를 눌러도 팝업이 닫히고, 그 누르기는 HUD 가 그대로 받음 (웹은 어디를 누르든 닫힘)
	if enemy >= 0:
		sc.show_enemy_popup(enemy)
		await _frames(2)
		_check(ui.info.popup.visible, "적 팝업 다시 엶")
		var sb: Control = ui.settings.btn
		await _click(sb.get_global_rect().get_center())
		await _frames(2)
		_check(not ui.info.popup.visible and ui.settings.panel.visible, "HUD(설정 단추) 누르기 → 팝업 닫힘 + 설정 창 열림")
		ui.settings.close()
		await _frames(1)
		sc.show_enemy_popup(enemy)
		await _frames(2)
		var mm: Control = ui.minimap
		await _click(mm.get_global_rect().get_center())
		await _frames(2)
		_check(not ui.info.popup.visible, "HUD(미니맵) 누르기 → 팝업 닫힘")
		await _until(func() -> bool: return sc.is_awaiting(), 5.0)
	# 대기 중이 아닐 때 항복 → 연출이 끝나고 입력 대기 때 항복
	sc.ui_action("defend")
	sc.ui_pick_face(0, 0)
	_check(sc.mode == "busy", "명령 뒤 연출 중")
	sc.surrender()
	_check(not sc.is_over() and sc._surrender_pending, "연출 중 항복은 미룸")
	await _until(func() -> bool: return sc.is_over(), 5.0)
	_check(sc.is_over() and str(sc.result.get("reason")) == "surrender", "연출이 끝난 뒤 항복")
	sc.queue_free()
	await _frames(3)
	# 스페인어 메뉴: 글이 단추 폭 안에 (잘리지 않음)
	root.get_node("I18n").call("set_language", "es")
	sc = await _launch_test("balanced_s05")
	await _frames(3)
	var bad: Array = []
	for mb: Dictionary in sc.ui.menu_buttons:
		var b: Button = mb["button"]
		var row: Control = b.get_child(0)
		if row.get_combined_minimum_size().x > b.size.x - 12.0:
			bad.append(str(mb["item"].get("sub", "")))
	_check(bad.is_empty() and not sc.ui.menu_buttons.is_empty(), "es 메뉴 글이 단추 안에 %s" % str(bad))
	root.get_node("I18n").call("set_language", "ko")
	sc.queue_free()
	await _frames(3)


func _store_writeback() -> void:
	var store: Node = root.get_node("Store")
	store.call("clear")
	var g: Dictionary = BattleScene.golden_cfg("balanced_s05")
	for k: String in (g["save"] as Dictionary).keys():
		store.call("set_json", k, g["save"][k])
	var soul := {"warrior": {"stone": 3, "frag": 7}}
	var mats := {"stone": 12, "protect": 2, "shard": 1}
	store.call("set_json", "game_soul", soul)
	store.call("set_json", "game_mats", mats)
	store.call("set_json", "game_other_page", {"x": 1})
	var sc: Node = await _launch_test("balanced_s05", {"save": BattleScene.store_save(store), "source": "store"})
	sc.surrender()
	await _until(func() -> bool: return sc.is_over(), 5.0)
	await _frames(3)
	_check(JsonX.stringify(store.call("get_json", "game_soul")) == JsonX.stringify(soul), "실제 세이브 전투 뒤 game_soul 그대로 (%s)" % JsonX.stringify(store.call("get_json", "game_soul")))
	_check(JsonX.stringify(store.call("get_json", "game_mats")) == JsonX.stringify(mats), "실제 세이브 전투 뒤 game_mats 그대로")
	_check(store.call("get_json", "game_other_page") != null, "다른 화면의 키도 그대로")
	var seen: Variant = store.call("get_json", "game_story_seen")
	_check(seen is Dictionary and not (seen as Dictionary).is_empty(), "본 스토리 기록이 Store 에")
	sc.queue_free()
	await _frames(3)
	# 이긴 보스전 (첫 클리어 영혼석): 보상은 원래 값에 더해지고 다른 직업 값은 남아야 함
	store.call("clear")
	var g2: Dictionary = BattleScene.golden_cfg("boss_s10")
	for k2: String in (g2["save"] as Dictionary).keys():
		store.call("set_json", k2, g2["save"][k2])
	var soul2 := {"stones": {"zz_test": 5.0}, "frags": {"mage": 4.0}}
	store.call("set_json", "game_soul", soul2)
	store.call("set_json", "game_mats", mats)
	sc = await _launch_test("boss_s10", {"save": BattleScene.store_save(store), "source": "store"})
	await _drive_all(sc, "boss_s10")
	await _frames(3)
	var sr: Variant = sc.eng.S.get("_soulReward")
	var after: Variant = store.call("get_json", "game_soul")
	_check(str(sc.result.get("result")) == "win" and typeof(sr) == TYPE_DICTIONARY, "보스전 승리 + 영혼석 보상 (%s)" % str(sr))
	if typeof(sr) == TYPE_DICTIONARY and after is Dictionary:
		var kind := "stones" if sr["kind"] == "stone" else "frags"
		var want := float(soul2[kind].get(sr["cls"], 0.0)) + float(sr["n"])
		_check(float(after[kind].get(sr["cls"], 0.0)) == want, "영혼석이 원래 값에 더해짐 (%s)" % JsonX.stringify(after))
		_check(float(after["stones"].get("zz_test", 0.0)) == 5.0 and float(after["frags"].get("mage", 0.0)) == 4.0, "다른 영혼석 값 남음")
	_check(JsonX.stringify(store.call("get_json", "game_mats")) == JsonX.stringify(mats), "game_mats 그대로 (보상 없음)")
	sc.queue_free()
	await _frames(3)
	store.call("clear")


func _drive_all(sc: Node, name: String) -> void:
	var gold: Dictionary = JsonX.parse(FileAccess.get_file_as_string("res://tests/golden/%s.json" % name))
	var cmds: Array = []
	for e: Dictionary in gold["events"]:
		if e["ev"] == "cmd":
			cmds.append(e)
	var ci := 0
	var f := 0
	while not sc.is_over() and f < 100000:
		await process_frame
		f += 1
		if sc.is_awaiting() and ci < cmds.size():
			var cmd: Dictionary = cmds[ci]
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
			ci += 1
