extends SceneTree
## 시범 화면 사진 찍기 + 성능 측정 (개발용)
##  HOME=<임시폴더> Godot --path godot --resolution 1280x720 --script res://dev/customize_pilot/shoot.gd
##  → godot/tests/screens/cust_*.png  (창이 있어야 함: 머리 없이는 그림이 안 그려짐)

const Look := preload("res://dev/customize_pilot/look.gd")
const PilotChar := preload("res://dev/customize_pilot/pilot_char.gd")
const OUT := "res://tests/screens/"

var P: Node2D


func _initialize() -> void:
	_main.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _post_draw() -> void:
	var done := [false]
	var cb := func() -> void: done[0] = true
	RenderingServer.frame_post_draw.connect(cb, CONNECT_ONE_SHOT)
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 5000:
		await process_frame


func _shot(name: String, region: Rect2i = Rect2i()) -> void:
	await _frames(3)
	await _post_draw()
	var img := root.get_texture().get_image()
	if region.size != Vector2i.ZERO:
		img = img.get_region(region)
	var path := ProjectSettings.globalize_path(OUT + name + ".png")
	img.save_png(path)
	print("  사진 ", name, " ", img.get_size())


func _pl(l: Dictionary, view := "f", a := "idle", tt := -1.0, left := false) -> Dictionary:
	var d := {"look": l, "view": view, "anim": a, "left": left}
	if tt >= 0.0:
		d["t"] = tt
	return d


func _lg(gender := "m", a := "idle", tt := -1.0, left := false) -> Dictionary:
	var d := {"legacy": true, "cls": "knight", "gender": gender, "anim": a, "left": left}
	if tt >= 0.0:
		d["t"] = tt
	return d


func _lk(h: int, f: int, o: int, t: int) -> Dictionary:
	return {"v": 1, "h": h, "f": f, "o": o, "t": t}


func _main() -> void:
	var scene: PackedScene = load("res://dev/customize_pilot/pilot.tscn")
	P = scene.instantiate()
	root.add_child(P)
	await _frames(20)   # 지도 타일 굽기
	for i in 40:
		await process_frame
	print("── 기사 커스터마이징 시범: 화면 사진 ──")

	# 0. 처음 화면 (단추 포함, 실제 크기)
	P.set_anim("idle")
	await _frames(30)
	await _shot("cust_00_scene_ui")

	P.ui.visible = false

	# 1. 나란히 비교 (확대 ×3): 시범 기사 2명 + 지금 캐릭터(남·여)
	P.set_rows([[_pl(_lk(0, 0, 0, 0)), _pl(_lk(2, 1, 1, 0)), _lg("m"), _lg("f")]])
	P.cam.zoom = Vector2.ONE * 3.0
	await _frames(10)
	await _shot("cust_01_side_by_side_front")

	# 2. 실제 전투 크기 (×1) + 같은 사진을 확대(×3, 가까운 점 보간 없이)한 것
	P.set_rows([[_pl(_lk(0, 0, 0, 0)), _pl(_lk(1, 0, 1, 0)), _pl(_lk(2, 1, 2, 0)), _lg("m"), _lg("f")]])
	P.cam.zoom = Vector2.ONE * 1.0
	await _frames(10)
	var vr := root.get_visible_rect()
	var c := Vector2i(vr.size / 2.0)
	var reg := Rect2i(c.x - 270, c.y - 70, 540, 140)
	await _shot("cust_02_realsize_x1", reg)
	await _frames(2)
	var img := root.get_texture().get_image().get_region(reg)
	img.resize(reg.size.x * 3, reg.size.y * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(OUT + "cust_02_realsize_x3.png"))

	# 3. 외형 조합 9개 (머리 3 × 옷 3, 얼굴·피부는 어긋나게) — 한 줄(앞·뒤) + 3x3 표
	var combos: Array = []
	for h in 3:
		for o in 3:
			combos.append(_lk(h, (h + o) % 2, o, (h * 2 + o) % 3))
	for v in ["f", "b"]:
		var row: Array = []
		for l in combos:
			row.append(_pl(l, v))
		P.set_rows([row])
		P.cam.zoom = Vector2.ONE * 1.35
		await _frames(10)
		await _shot("cust_03_combos_row_" + v)
		var grid: Array = []
		for r in 3:
			grid.append(row.slice(r * 3, r * 3 + 3))
		P.set_rows(grid)
		P.cam.zoom = Vector2.ONE * 2.2
		await _frames(10)
		await _shot("cust_04_combos_grid_" + v)

	# 4. 동작 띠: 위 = 시범 기사(앞), 아래 = 지금 캐릭터 (같은 때)
	var look := _lk(2, 1, 0, 0)
	var strips := {
		"idle": [[0.0, 0.3, 0.6, 0.9, 1.2, 1.5], 1.0],
		"move": [[0.0, 0.09, 0.19, 0.28, 0.37, 0.47], 2.68],
		"attack": [[0.0, 0.14, 0.24, 0.38, 0.52, 0.72], 0.988],
		"hit": [[0.0, 0.07, 0.14, 0.22, 0.32, 0.45], 1.04],
	}
	for a: String in strips.keys():
		var ts: Array = strips[a][0]
		var ratio: float = strips[a][1]
		var top: Array = []
		var bot: Array = []
		for t in ts:
			top.append(_pl(look, "f", a, float(t)))
			bot.append(_lg("m", a, float(t) * ratio))
		P.set_rows([top, bot])
		P.cam.zoom = Vector2.ONE * 2.0
		await _frames(10)
		await _shot("cust_05_anim_%s_front" % a)
		var topb: Array = []
		for t in ts:
			topb.append(_pl(look, "b", a, float(t)))
		P.set_rows([topb])
		P.cam.zoom = Vector2.ONE * 2.0
		await _frames(10)
		await _shot("cust_06_anim_%s_back" % a)

	# 5. 왼쪽을 볼 때 (좌우 뒤집기)
	P.set_rows([[_pl(look, "f", "attack", 0.38, true), _pl(look, "b", "attack", 0.38, true), _pl(look, "f", "attack", 0.38, false), _lg("m", "attack", 0.38 * 0.988, true)]])
	P.cam.zoom = Vector2.ONE * 3.0
	await _frames(10)
	await _shot("cust_07_flip_attack")

	# 6. 측정 — 지도를 숨겨 캐릭터만의 그리기 호출을 잼 (9명 / 27명, 시범 기사 vs 지금 캐릭터), 처리 시간은 공격 반복 중 평균
	P.map.visible = false
	P.cam.zoom = Vector2.ONE
	print("── 측정 (창 1280x720, 지도 숨김) ──")
	for n in [0, 9, 27]:
		for kind in ["pilot", "legacy"]:
			if n == 0 and kind == "legacy":
				continue
			var rows: Array = []
			var row: Array = []
			for i in n:
				if kind == "pilot":
					row.append(_pl(combos[i % 9], "f", "attack"))
				else:
					row.append(_lg("m" if i % 2 == 0 else "f", "attack"))
				if row.size() == 7:
					rows.append(row)
					row = []
			if not row.is_empty() or rows.is_empty():
				rows.append(row)
			P.set_rows(rows)
			if kind == "pilot":
				for ch in P.units.get_children():
					ch.loop_attack = true
			var st := await _measure(40)
			print("  %-6s %2d명: %s" % [kind, n, st])
	var ch := PilotChar.new()
	P.add_child(ch)
	ch.setup("f", _lk(0, 0, 0, 0))
	print("  기사 1명: 조각(Sprite2D) %d개, 노드 %d개" % [ch.parts_count, _count_nodes(ch)])
	var tex_bytes := 0
	var files := 0
	var disk := 0
	for dn in ["f", "b"]:
		var d := DirAccess.open("res://assets/pilot/knight/" + dn)
		for fn in d.get_files():
			if fn.ends_with(".png"):
				var pth := ProjectSettings.globalize_path("res://assets/pilot/knight/%s/%s" % [dn, fn])
				var im := Image.load_from_file(pth)
				tex_bytes += im.get_width() * im.get_height() * 4
				disk += FileAccess.get_file_as_bytes(pth).size()
				files += 1
	print("  조각 그림 %d장: 디스크 %.0f KB, 메모리(RGBA·밉맵 제외) %.2f MB" % [files, disk / 1024.0, tex_bytes / 1048576.0])
	print("DONE")
	quit(0)


## 몇 프레임 지난 뒤 평균 그리기 호출·물체 수 + 캐릭터 _process(자세 계산·적용) 만의 CPU 시간(프레임당 ms)
func _measure(frames: int) -> Dictionary:
	await _frames(10)
	var calls := 0
	var objs := 0
	for i in frames:
		await _post_draw()
		calls += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objs += int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var units: Array = P.units.get_children()
	var t0 := Time.get_ticks_usec()
	for i in 200:
		for ch in units:
			ch._process(1.0 / 60.0)
	var per := float(Time.get_ticks_usec() - t0) / 200.0 / 1000.0
	return {"draw_calls": snappedf(float(calls) / frames, 0.1), "objects": snappedf(float(objs) / frames, 0.1), "script_ms_per_frame": snappedf(per, 0.001),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}


func _stats() -> Dictionary:
	return {"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"tex_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"fps": int(Performance.get_monitor(Performance.TIME_FPS))}


func _count_nodes(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _count_nodes(k)
	return c
