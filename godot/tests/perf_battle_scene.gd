extends SceneTree
## 성능 확인 (창 모드 — 실제로 그려야 하므로 --headless 로 돌리지 말 것)
##   Godot --path godot --script res://tests/perf_battle_scene.gd [-- --golden balanced_s05 --units 40 --frames 600]
##  밀림(숲 40%) 지도에 화면용 유닛을 더 세워 ~40명으로 만들고, 카메라를 천천히 움직이며 수직 동기 없이 프레임 시간을 잼.
##  (3b) HUD 전부 켬 + 30프레임마다 연출(직업별 타격·픽셀 투사체·떠오르는 글자·죽음 입자)을 터뜨리고, 중간에 카메라를 네 번 돌려
##       회전 프레임의 시간을 따로 출력 (3a: 회전 때 ~35ms 끊김 → 3b 는 방향별 노드 묶음을 미리 만들어 보이기만 바꿈)
##  -- --no-hud (HUD 끔) · --no-fx (연출 부하 없음) · --no-prebuild (로딩 때 방향 묶음을 미리 만들지 않음 → 첫 회전마다 만듦) · --hide map,units,fx,pfx
##  ※ 다른 프로그램이 CPU 를 쓰면 숫자가 크게 흔들림 — 여러 번 재서 비교
##  엔진 규칙은 건드리지 않음 (더한 유닛은 그림뿐). 끝에 평균 fps · 95% 프레임 시간 · 최대 · 회전 프레임 최대를 출력.

const BattleScene := preload("res://scripts/battle/battle_scene.gd")
const UnitView := preload("res://scripts/battle/unit_view.gd")
const PixelFx := preload("res://scripts/battle/pixel_fx.gd")

var _golden := "balanced_s05"
var _units := 40
var _frames := 600
var _no_hud := false
var _no_fx := false
var _hide: PackedStringArray = PackedStringArray()


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
			"--no-hud":
				_no_hud = true
			"--no-fx":
				_no_fx = true
			"--hide":
				_hide = args[i + 1].split(",")
	_main.call_deferred()


func _main() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var cfg := BattleScene.golden_cfg(_golden)
	cfg["speed"] = 1.0
	cfg["story"] = "off"
	cfg["source"] = "test"
	if OS.get_cmdline_user_args().has("--no-prebuild"):
		cfg["loading"] = false
	BattleScene.pending = cfg
	var sc: Node = (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	root.add_child(sc)
	# 로딩(네 방향 묶음 미리 만들기 + 타일 그림 굽기)이 끝날 때까지
	# + 첫 입력 대기까지 (재생 중 전장 사본이 화면용으로 더한 유닛을 지우지 않게)
	var w := 0
	while (sc._loading_on or sc.map._baking or not sc.is_awaiting()) and w < 3000:
		await process_frame
		w += 1
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
				"hp": 80.0, "mhp": 100.0, "res": 30.0, "maxRes": 100.0, "resType": "mana", "move": 3.0, "face": [0, 1 if team == "enemy" else -1],
				"ap": float(k % 5), "actionRec": 1.0, "lv": 5, "atk": 20.0, "def": 5.0, "range": 1.0}
			sc._add_unit(v, false)
			k += 1
			n += 1
	sc._refresh_fog_view()
	sc._refresh_loops()
	if _no_hud:
		sc.ui.visible = false
		sc.ui.set_process(false)
	for h: String in _hide:
		var nd: Node = {"map": sc.map, "units": sc.unit_layer, "fx": sc.fx, "pfx": sc.pfx, "minimap": sc.ui.minimap, "order": sc.ui.order,
			"cards": sc.ui.cards, "top": sc.ui.top, "menu": sc.ui.menu}.get(h)
		if nd != null:
			nd.visible = false

	var props := 0
	var trees := 0
	var set_root: Node = sc.map._sets[sc.map._set_dir]["root"]
	for ch: Node in set_root.get_children():
		var p: Variant = ch.get("props")
		if typeof(p) == TYPE_ARRAY:
			props += (p as Array).size()
			if ch.z_index >= 100:
				trees += (p as Array).size()
	var vp_rid: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var rcpu: Array = []
	var rgpu: Array = []
	var times: Array = []
	var rot_times: Array = []
	var rot_script: Array = []
	var t_prev := Time.get_ticks_usec()
	var start: Vector2 = sc.cam.position
	var ids: Array = sc.units.keys()
	# 회전은 연출 부하(30프레임마다)와 겹치지 않는 프레임에 (+15)
	var rot_frames := [_frames / 5 + 15, _frames * 2 / 5 + 15, _frames * 3 / 5 + 15, _frames * 4 / 5 + 15]
	var rotated_last := false
	for f in _frames:
		await process_frame
		var t := Time.get_ticks_usec()
		var ms := float(t - t_prev) / 1000.0
		times.append(ms)
		rcpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu())
		rgpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))
		if rotated_last:
			rot_times.append(ms)
		rotated_last = false
		t_prev = t
		sc.cam.position = start + Vector2(sin(f * 0.02) * 120.0, cos(f * 0.015) * 60.0)
		if rot_frames.has(f) and not OS.get_cmdline_user_args().has("--no-rotate"):
			var r0 := Time.get_ticks_usec()
			sc.rotate_cam(1)
			rot_script.append(float(Time.get_ticks_usec() - r0) / 1000.0)
			rotated_last = true
		# 연출 부하 (실제 전투의 큰 순간 정도: 타격 효과 둘 + 투사체 + 글자 + 죽음 입자)
		if f % 30 == 0 and not _no_fx:
			var a: Node = sc.units.get(ids[f / 30 % ids.size()])
			var b: Node = sc.units.get(ids[(f / 30 + 3) % ids.size()])
			if a == null or b == null:
				continue
			var ap: Vector2 = a.position + Vector2(0, -24)
			var bp: Vector2 = b.position + Vector2(0, -24)
			sc.fx.hit_fx("warrior", ap, bp)
			sc.fx.hit_fx("assassin", ap, bp)
			sc.pfx.shoot(["archer", "mage", "priest", "shaman"][f / 30 % 4], ap.x, ap.y, bp.x, bp.y, 240.0)
			sc.pfx.impact(["archer", "mage", "priest", "shaman"][f / 30 % 4], bp.x, bp.y)
			sc.fx.float_text(int(b.d["x"]), int(b.d["y"]), "-42", "damage")
			sc.fx.death_fx(bp, false)
			sc._hud_dirty = true
	var buckets := PackedStringArray()
	for b0 in range(0, times.size(), 100):
		var bt := 0.0
		var bs: Array = times.slice(b0, mini(times.size(), b0 + 100))
		for x0: float in bs:
			bt += x0
		buckets.append("%.1f" % (bt / maxf(1.0, bs.size())))
	print("회전 함수(스크립트) ms: %s" % str(rot_script))
	print("100프레임마다 평균 ms: " + " / ".join(buckets))
	times = times.slice(5)
	var tot := 0.0
	for x: float in times:
		tot += x
	var sorted := times.duplicate()
	sorted.sort()
	var avg := tot / times.size()
	var rmax := 0.0
	for x2: float in rot_times:
		rmax = maxf(rmax, x2)
	print("── 3b 성능 ── %s · 유닛 %d · 맵 오브젝트 %d (나무 %d) · %d 프레임 · HUD+연출" % [_golden, sc.units.size(), props, trees, times.size()])
	print("평균 %.2f ms (%.0f fps) · 95%% %.2f ms · 최대 %.2f ms · 회전 프레임 최대 %.2f ms (%d번)" % [avg, 1000.0 / avg, sorted[int(sorted.size() * 0.95)], sorted[sorted.size() - 1], rmax, rot_times.size()])
	rcpu.sort()
	rgpu.sort()
	print("중앙값 %.2f ms · 그리기(CPU) 중앙값 %.2f ms · 그리기(GPU) 중앙값 %.2f ms" % [sorted[sorted.size() / 2], rcpu[rcpu.size() / 2], rgpu[rgpu.size() / 2]])
	print("그리기 호출 %d · 그린 항목 %d · 노드 %d" % [int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	print("렌더러: %s · %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method()])
	quit(0)

