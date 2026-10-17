extends RefCounted
## 실제 창 시험(play_4a · play_4b1 · play_4b2) 공용 도우미 (4b-2)
##  - post_draw(tree, 초): 화면 사진용 frame_post_draw 를 시간 제한으로 기다림 (창이 가려져 그리기가 멈추면 끝없이 기다리던 것) → 성공 여부
##  - ensure_visible(tree, bt, x, y, key): 칸이 화면 가운데 쪽(논리 크기 root.get_visible_rect() 기준)에 오고 HUD(ui.over_hud) 위가 아닐 때까지
##    화살표 키(진짜 입력, key 는 키를 누르는 코루틴 Callable)로 카메라를 옮김 → [칸 화면 좌표, 누를 수 있는지]
##    (예전에는 Vector2(root.size) = 물리 크기로 재서 1920×1080 창에서 '가운데'가 논리 화면 밖까지 넓어져, HUD 밑의 칸을 눌러
##     '대상 고르기'가 풀리지 않는 일이 있었음)


static func post_draw(tree: SceneTree, secs: float = 3.0) -> bool:
	var done := [false]
	var cb := func() -> void: done[0] = true
	RenderingServer.frame_post_draw.connect(cb, CONNECT_ONE_SHOT)
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await tree.process_frame
	if not done[0] and RenderingServer.frame_post_draw.is_connected(cb):
		RenderingServer.frame_post_draw.disconnect(cb)
	return done[0]


static func cell_screen(bt: Node, x: int, y: int) -> Vector2:
	return bt.get_viewport().get_canvas_transform() * bt.iso.top_center(x, y)


static func ensure_visible(tree: SceneTree, bt: Node, x: int, y: int, key: Callable) -> Array:
	var vr := tree.root.get_visible_rect()
	var r := Rect2(vr.position + vr.size * Vector2(0.2, 0.17), vr.size * Vector2(0.6, 0.58))
	var p := cell_screen(bt, x, y)
	for i in 40:
		p = cell_screen(bt, x, y)
		if r.has_point(p) and not bt.ui.over_hud(p):
			break
		var d := p - r.get_center()
		if d.length() < 8.0:
			d = Vector2(0, 1)   # 가운데인데 HUD 위면 아래로 한 칸 (위쪽 HUD 가 더 많음)
		if absf(d.x) > absf(d.y):
			await key.call(KEY_RIGHT if d.x > 0 else KEY_LEFT)
		else:
			await key.call(KEY_DOWN if d.y > 0 else KEY_UP)
		# 카메라가 움직이는 동안 좌표가 바뀌므로 멈출 때까지
		var last := Vector2.INF
		for j in 30:
			var q := cell_screen(bt, x, y)
			if q.distance_to(last) < 0.5:
				break
			last = q
			await tree.process_frame
	p = cell_screen(bt, x, y)
	return [p, r.has_point(p) and not bt.ui.over_hud(p)]
