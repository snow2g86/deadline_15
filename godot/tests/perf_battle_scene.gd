extends SceneTree
## 3a 성능 확인 (창 모드 — 실제로 그려야 하므로 --headless 로 돌리지 말 것)
##   Godot --path godot --script res://tests/perf_battle_scene.gd [-- --golden balanced_s05 --units 40 --frames 600]
##  밀림(숲 40%) 지도에 화면용 유닛을 더 세워 ~40명으로 만들고, 카메라를 천천히 움직이며 수직 동기 없이 프레임 시간을 잼.
##  엔진 규칙은 건드리지 않음 (더한 유닛은 그림뿐). 끝에 평균 fps · 95% 프레임 시간 · 그림 수를 출력.

const BattleScene := preload("res://scripts/battle/battle_scene.gd")
const UnitView := preload("res://scripts/battle/unit_view.gd")

var _golden := "balanced_s05"
var _units := 40
var _frames := 600


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--golden":
				_golden = args[i + 1]
			"--units":
				_units = args[i + 1].to_int()
			"--frames":
				_frames = args[i + 1].to_int()
	_main.call_deferred()


func _main() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var cfg := BattleScene.golden_cfg(_golden)
	cfg["speed"] = 1.0
	BattleScene.pending = cfg
	var sc: Node = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	root.add_child(sc)
	for i in 10:
		await process_frame
	# 빈 칸에 화면용 유닛 더하기 (번갈아 아군·적, 직업 돌려 가며)
	var classes := ["warrior", "knight", "archer", "mage", "priest", "assassin", "brawler", "lancer", "sapper", "shaman", "summoner", "novice"]
	var used: Dictionary = {}
	for uv: Node in sc.units.values():
		used["%d,%d" % [int(uv.d["x"]), int(uv.d["y"])]] = true
	var n: int = sc.units.size()
	var k := 0
	for r in sc.iso.rows:
		for c in sc.iso.cols:
			if n >= _units:
				break
			var tp: String = sc.iso.tile_type(c, r)
			if used.has("%d,%d" % [c, r]) or tp == "water" or tp == "rock" or tp == "wall":
				continue
			var team := "ally" if k % 2 == 0 else "enemy"
			var v := {"id": 1000 + k, "team": team, "cls": classes[k % classes.size()], "gender": "f" if k % 3 == 0 else "m", "x": c, "y": r,
				"hp": 80.0, "mhp": 100.0, "res": 30.0, "maxRes": 100.0, "resType": "mana", "move": 3.0, "face": [0, 1 if team == "enemy" else -1]}
			sc._add_unit(v, false)
			k += 1
			n += 1
	sc._refresh_fog_view()
	sc._refresh_loops()
	var props := 0
	var trees := 0
	for ch: Node in sc.map.get_children():
		var p: Variant = ch.get("props")
		if typeof(p) == TYPE_ARRAY:
			props += (p as Array).size()
			if ch.z_index >= 100:
				trees += (p as Array).size()
	var times: Array = []
	var t_prev := Time.get_ticks_usec()
	var start: Vector2 = sc.cam.position
	for f in _frames:
		await process_frame
		var t := Time.get_ticks_usec()
		times.append(float(t - t_prev) / 1000.0)
		t_prev = t
		sc.cam.position = start + Vector2(sin(f * 0.02) * 120.0, cos(f * 0.015) * 60.0)
		if f == _frames / 2:
			sc.rotate_cam(1)
	times = times.slice(5)
	var tot := 0.0
	for x: float in times:
		tot += x
	var sorted := times.duplicate()
	sorted.sort()
	var avg := tot / times.size()
	print("── 3a 성능 ── %s · 유닛 %d · 맵 오브젝트 %d (나무 %d) · %d 프레임" % [_golden, sc.units.size(), props, trees, times.size()])
	print("평균 %.2f ms (%.0f fps) · 95%% %.2f ms · 최대 %.2f ms" % [avg, 1000.0 / avg, sorted[int(sorted.size() * 0.95)], sorted[sorted.size() - 1]])
	print("렌더러: %s · %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method()])
	quit(0)
