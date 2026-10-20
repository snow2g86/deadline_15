extends SceneTree
## 시범 2차 화면 사진 + 성능 측정 (개발용)
##  HOME=<임시폴더> Godot --path godot --resolution 1280x720 --script res://dev/customize_pilot2/shoot2.gd
##  → godot/tests/screens/cust2_*.png
const Pal := preload("res://dev/customize_pilot2/palettes.gd")
const Char2 := preload("res://dev/customize_pilot2/pilot2_char.gd")
const KData := preload("res://dev/customize_pilot2/kdata.gd")
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
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("  사진 ", name, " ", img.get_size())


func L(h := 0, c := 0, k := 0, r := 0, o := 0, p := 0, d := 0) -> Dictionary:
	return {"v": 2, "h": h, "c": c, "k": k, "r": r, "o": o, "p": p, "d": d}


## 동작 이름 → 시트 종류, 칸 번호 → 시간(초)
func T(a: String, f: int) -> float:
	var kind := {"move": "run"}.get(a, a) as String
	var sh: Dictionary = P.sdb.call("sheet", "knight", "f", kind)
	return (f + 0.5) / float(sh["frames"]) * float(sh["dur"]) / 1000.0


func mine(l: Dictionary, a: String, f: int, extra := {}) -> Dictionary:
	var d := {"mine": true, "look": l, "anim": a, "t": T(a, f)}
	d.merge(extra, true)
	return d


func orig(a: String, f: int, extra := {}) -> Dictionary:
	var d := {"legacy": true, "anim": a, "t": T(a, f)}
	d.merge(extra, true)
	return d


func _fit(n: int) -> float:
	return minf(3.0, 1180.0 / (float(n - 1) * 97.0 + 110.0))


func _show(rows: Array, name: String, zoom: float = -1.0) -> void:
	P.set_rows(rows)
	var n := 0
	for r: Array in rows:
		n = maxi(n, r.size())
	P.cam.zoom = Vector2.ONE * (zoom if zoom > 0.0 else _fit(n))
	await _frames(6)
	await _shot(name)


func _main() -> void:
	var scene: PackedScene = load("res://dev/customize_pilot2/pilot2.tscn")
	P = scene.instantiate()
	root.add_child(P)
	await _frames(60)
	print("── 캐릭터 외형 커스터마이징 시범 2차: 화면 사진 ──")
	P.set_anim("idle")
	await _frames(20)
	await _shot("cust2_00_scene_ui")
	P.ui.visible = false

	var base := L(1, 1, 0, 0, 0, 0)

	# 1. 나란히: 내 기사(머리 바꿈+색) / 지금 원본 / 1차 시범
	await _show([[mine(base, "idle", 0, {"cap": "2차(머리+색)"}), orig("idle", 0, {"cap": "지금 원본"}), {"p1": true, "anim": "idle", "cap": "1차 시범"}]], "cust2_01_side_by_side", 3.0)

	# 2. 실제 전투 크기 ×1 + ×3 확대
	P.set_rows([[mine(L(1, 1, 0, 0, 0, 0), "idle", 0), mine(L(2, 3, 0, 0, 1, 0), "combat", 2), mine(L(4, 6, 0, 0, 3, 1), "idle", 4), orig("idle", 0), {"p1": true, "anim": "idle"}]])
	P.cam.zoom = Vector2.ONE
	await _frames(8)
	var vr := root.get_visible_rect()
	var c := Vector2i(vr.size / 2.0)
	var reg := Rect2i(c.x - 270, c.y - 70, 540, 140)
	await _shot("cust2_02_realsize_x1", reg)
	await _frames(2)
	var img := root.get_texture().get_image().get_region(reg)
	img.resize(reg.size.x * 3, reg.size.y * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(OUT + "cust2_02_realsize_x3.png"))

	# 3. 동작 5종: 위 = 2차(머리·색), 아래 = 지금 원본 (같은 칸)
	var strips := {
		"idle": [0, 2, 4, 6, 8, 10],
		"combat": [0, 2, 4, 6, 8, 10],
		"move": [0, 2, 4, 6, 9, 12],
		"hit": [0, 3, 6, 7, 8],
	}
	for a: String in strips.keys():
		var top: Array = []
		var bot: Array = []
		for f: int in strips[a]:
			top.append(mine(L(1, 1, 0, 0, 0, 0), a, f))
			bot.append(orig(a, f))
		await _show([top, bot], "cust2_03_motion_%s" % a)
	for part in 2:
		var top: Array = []
		var bot: Array = []
		var fr: Array = range(part * 7, part * 7 + 7)
		for f: int in fr:
			top.append(mine(L(1, 1, 0, 0, 0, 0), "attack", f, {"cap": "f%d" % f}))
			bot.append(orig("attack", f))
		await _show([top, bot], "cust2_03_motion_attack_%d" % (part + 1))

	# 4. 조합 12개 (머리 × 의상 × 색): 대기 / 이동 / 공격 칸
	var combos: Array = [
		L(1, 1, 0, 0, 0, 0), L(2, 2, 1, 2, 1, 0), L(3, 4, 0, 0, 2, 0), L(4, 3, 2, 0, 3, 0),
		L(5, 5, 0, 3, 4, 2), L(6, 7, 4, 0, 5, 0), L(7, 2, 0, 1, 1, 3), L(8, 6, 3, 0, 2, 1),
		L(1, 1, 0, 4, 3, 0), L(2, 4, 0, 0, 4, 0, 1), L(5, 3, 2, 0, 5, 3, 1), L(7, 5, 0, 5, 1, 4),
	]
	for pose: Array in [["idle", 3, "idle"], ["move", 3, "run"], ["attack", 1, "attack1"], ["attack", 11, "attack11"], ["combat", 5, "combat"], ["hit", 7, "hit"]]:
		var rows: Array = []
		for r in 3:
			var row: Array = []
			for i in 4:
				row.append(mine(combos[r * 4 + i], pose[0], pose[1]))
			rows.append(row)
		await _show(rows, "cust2_04_combos_%s" % pose[2], 1.7)

	# 5. 색 팔레트 8벌 (원본 머리 + 의상 그대로): 대기 한 줄 + 이동/공격 줄
	for pose: Array in [["idle", 4, "idle"], ["move", 3, "run"], ["attack", 1, "attack1"], ["attack", 12, "attack12"]]:
		var row1: Array = []
		var row2: Array = []
		for i in 8:
			(row1 if i < 4 else row2).append(mine(L(0, i, 0, 0, 0, 0), pose[0], pose[1]))
		await _show([row1, row2], "cust2_05_palettes_%s" % pose[2], 1.8)
	# 피부·머리카락 색 (머리 조각)
	var rowh: Array = []
	for i in 6:
		rowh.append(mine(L(1, 0, i % 5, [0, 1, 2, 3, 4, 5][i], 0, 0), "idle", 0))
	var rowm: Array = []
	for i in 6:
		rowm.append(mine(L(3, 0, 0, [0, 1, 2, 3, 5, 6][i], 0, 0), "idle", 0))
	await _show([rowh, rowm], "cust2_05_hair_skin", 1.7)

	# 6. 무늬 5종 (색 1 + 2): 대기·이동
	for pose: Array in [["idle", 4, "idle"], ["move", 3, "run"]]:
		var rowp: Array = []
		var rowq: Array = []
		for i in 5:
			rowp.append(mine(L(0, 3, 0, 0, 0, i), pose[0], pose[1]))
			rowq.append(mine(L(0, 5, 0, 0, 0, i), pose[0], pose[1]))
		await _show([rowp, rowq], "cust2_06_patterns_%s" % pose[2], 1.9)

	# 7. 의상 6종 × 동작 (의상 방법 2 의 한계: 이동·공격에서 몸통 조각이 빠짐)
	var cos_rows := {
		"idle": [["idle", 0], ["idle", 6]],
		"combat": [["combat", 3]],
		"run": [["move", 2], ["move", 6]],
		"attack": [["attack", 0], ["attack", 2], ["attack", 5], ["attack", 11]],
		"hit": [["hit", 0], ["hit", 8]],
	}
	for key: String in cos_rows.keys():
		var rows: Array = []
		for pf: Array in cos_rows[key]:
			var row: Array = []
			for o in 6:
				row.append(mine(L(0, 0, 0, 0, o, 0), pf[0], pf[1]))
			rows.append(row)
		await _show(rows, "cust2_07_costume_%s" % key, 1.9 if rows.size() <= 2 else 1.7)

	# 7b. 머리 장식(안전모) — 머리 6종 × (없음/있음), 대기·이동·공격
	for pose: Array in [["idle", 3, "idle"], ["move", 3, "run"], ["attack", 1, "attack1"]]:
		var rw1: Array = []
		var rw2: Array = []
		for i in 6:
			rw1.append(mine(L(1 + i, 0, 0, 0, 0, 0, 0), pose[0], pose[1]))
			rw2.append(mine(L(1 + i, 2, 0, 0, 0, 0, 1), pose[0], pose[1]))
		await _show([rw1, rw2], "cust2_07b_deco_%s" % pose[2], 1.9)

	# 8. 문제 칸: 공격 3~10 (머리를 잃는 칸) — 위 = 머리 바꿈, 아래 = 원본, 크게 (두 장)
	for part in 2:
		var up: Array = []
		var lo: Array = []
		for f in range(3 + part * 4, 7 + part * 4):
			up.append(mine(L(1, 0, 0, 0, 0, 0), "attack", f, {"cap": "f%d %s" % [f, str(KData.anchors["sheets"]["attack"]["head"][f]["vis"])]}))
			lo.append(orig("attack", f))
		await _show([up, lo], "cust2_08_problem_attack_%d_%d" % [3 + part * 4, 6 + part * 4], 2.4)
	# 기준점 상자 (초록 믿음 · 노랑 약함 · 빨강 잃음) — 머리 바꿈 없이 원래 모습 위에
	for pose: Array in [["idle", [0, 3, 6, 9], "idle"], ["move", [0, 2, 4, 8], "run"], ["attack", [0, 3, 4, 6], "attack_a"], ["attack", [8, 10, 12, 13], "attack_b"], ["hit", [0, 7, 8], "hit"]]:
		var row: Array = []
		for f: int in pose[1]:
			row.append(mine(L(0, 0, 0, 0, 0, 0), pose[0], f, {"debug": true, "cap": "f%d" % f}))
		await _show([row], "cust2_09_anchor_boxes_%s" % pose[2], 2.6 if row.size() <= 4 else 1.7)

	# 9. 좌우 뒤집기
	await _show([[mine(L(2, 2, 0, 0, 2, 0), "attack", 1, {"left": true}), mine(L(2, 2, 0, 0, 2, 0), "attack", 11, {"left": true}), mine(L(2, 2, 0, 0, 2, 0), "attack", 1), orig("attack", 1, {"left": true})]], "cust2_10_flip", 2.6)

	# 10. 1차 시범·원본과 비교 (같은 대기, 확대)
	await _show([[mine(L(1, 1, 0, 0, 0, 0), "idle", 0, {"cap": "2차"}), mine(L(0, 4, 0, 0, 0, 0), "idle", 0, {"cap": "2차(원래 투구+색)"}), orig("idle", 0, {"cap": "원본"}), {"p1": true, "anim": "idle", "cap": "1차"}]], "cust2_11_compare_p1", 3.0)

	# 11. 측정 — 지도를 숨기고 캐릭터만의 그리기 호출·처리 시간 (9 / 27 명, 2차 vs 원본)
	P.map.visible = false
	P.cam.zoom = Vector2.ONE
	print("── 측정 (창 1280x720, 지도 숨김) ──")
	for n in [9, 27]:
		for kind in ["mine_swap", "mine_color_only", "legacy"]:
			var rows: Array = []
			var row: Array = []
			for i in n:
				match kind:
					"mine_swap":
						row.append({"mine": true, "look": combos[i % 12], "anim": "idle"})
					"mine_color_only":
						row.append({"mine": true, "look": L(0, 1 + i % 7, 0, 0, 0, 0), "anim": "idle"})
					_:
						row.append({"legacy": true, "anim": "idle"})
				if row.size() == 7:
					rows.append(row)
					row = []
			if not row.is_empty() or rows.is_empty():
				rows.append(row)
			P.set_rows(rows)
			var st := await _measure(40)
			print("  %-16s %2d명: %s" % [kind, n, st])
	var ch := Char2.new()
	P.add_child(ch)
	ch.setup(P.sdb, L(1, 1, 0, 0, 1, 1))
	var tex_bytes := 0
	var disk := 0
	var files := 0
	var d := DirAccess.open("res://assets/pilot/knight2")
	for fn in d.get_files():
		if fn.ends_with(".png"):
			var pth := ProjectSettings.globalize_path("res://assets/pilot/knight2/" + fn)
			var im := Image.load_from_file(pth)
			tex_bytes += im.get_width() * im.get_height() * 4
			disk += FileAccess.get_file_as_bytes(pth).size()
			files += 1
	print("  추가 그림 %d장: 디스크 %.0f KB, 메모리(RGBA) %.2f MB" % [files, disk / 1024.0, tex_bytes / 1048576.0])
	print("DONE")
	quit(0)


func _measure(frames: int) -> Dictionary:
	await _frames(10)
	var calls := 0
	var objs := 0
	for i in frames:
		await _post_draw()
		calls += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objs += int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var us: Array = P.units.get_children()
	var t0 := Time.get_ticks_usec()
	for i in 200:
		for ch in us:
			ch._process(1.0 / 60.0)
	var per := float(Time.get_ticks_usec() - t0) / 200.0 / 1000.0
	return {"draw_calls": snappedf(float(calls) / frames, 0.1), "objects": snappedf(float(objs) / frames, 0.1), "script_ms_per_frame": snappedf(per, 0.001),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}
