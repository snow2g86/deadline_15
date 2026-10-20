extends Node2D
## 3D 캐릭터 → 2.5D 등각 시범 (개발용) — 실행: Godot --path godot res://dev/pilot3d/pilot3d.tscn
##   -- --auto            사진 일괄 저장 (tests/screens/p3_*.png) 후 종료
##   -- --bench           렌더링 비용 측정 (JSON 을 --out=경로 로 저장) 후 종료

const Iso := preload("res://dev/pilot3d/p3_iso.gd")
const Look := preload("res://dev/pilot3d/p3_look.gd")
const Parts := preload("res://dev/pilot3d/p3_parts.gd")
const Anims := preload("res://dev/pilot3d/p3_anims.gd")
const Layer := preload("res://dev/pilot3d/p3_layer.gd")
const TerrainTex := preload("res://scripts/battle/terrain_tex.gd")
const SpriteDB := preload("res://scripts/battle/sprite_db.gd")
const SHOT_DIR := "res://tests/screens/"

const GRID := Vector2i(8, 8)
const PLAINS := {"tc": Color("2e4a30"), "lc": Color("223a24"), "rc": Color("1a2e1c")}

# 직업별 "비슷한 장비" 외형 (2D 와 나란히 놓을 때)
const CLASS_LOOKS := {
	"knight_01": {"v": 1, "s": {"hair": 0, "face": 1, "top": 2, "bottom": 2, "shoes": 2, "helm": 2, "cape": 0, "weapon": 1, "shield": 2}, "c": {"skin": 1, "hair": 1, "cloth": 6, "metal": 3}},
	"mage_01": {"v": 1, "s": {"hair": 1, "face": 0, "top": 1, "bottom": 0, "shoes": 0, "helm": 3, "cape": 0, "weapon": 2, "shield": 0}, "c": {"skin": 0, "hair": 5, "cloth": 3, "metal": 2}},
	"brawler_01": {"v": 1, "s": {"hair": 2, "face": 1, "top": 0, "bottom": 0, "shoes": 0, "helm": 0, "cape": 0, "weapon": 4, "shield": 0}, "c": {"skin": 2, "hair": 4, "cloth": 7, "metal": 3}},
	"priest_01": {"v": 1, "s": {"hair": 3, "face": 2, "top": 1, "bottom": 0, "shoes": 1, "helm": 0, "cape": 1, "weapon": 4, "shield": 0}, "c": {"skin": 5, "hair": 3, "cloth": 6, "metal": 2}},
}

var args: PackedStringArray = []
var world: Node2D
var floor_draw: Node2D
var layer: Node2D
var overlay: Node2D
var ui: CanvasLayer
var panel: PanelContainer
var info: Label
var look_label: LineEdit
var legacy_nodes: Array = []
var sprites_json: Dictionary = {}
var sdb: RefCounted
var pal_tex: ImageTexture
var pal_json: Dictionary = {}

# 상태
var cur_look: Dictionary = Look.default_look()
var cur_klook: Dictionary = {"v": 2, "s": {"body": 0, "helm": 1, "cape": 1, "weapon": 1, "shield": 1}, "c": {"skin": 0, "hair": 3, "cloth": 0, "metal": 0}}
var cur_dir := 2
var cur_anim := "idle"
var mode: int = Layer.Mode.ATLAS
var kk := 1.0
var count := 1
var zoom := 2.0
var compare := false
var compare_cls := "knight_01"
var show_overlay := false
var post_mode := 1
var post_levels := 6.0
var post_outline := false
var hull_on := true
var cel_steps := 4
var dither := 0.0
var line_w := 1.0
var rng := RandomNumberGenerator.new()
var _opts: Dictionary = {}
var _entries: Array = []
var entries_override: Array = []     # 사진용: 직접 지정한 배치 [{look, tile, dir, anim, phase, speed}]
var legacy_override: Array = []      # 사진용: [{key, tile}]
var _busy := false
var _t := 0.0
var _fps_acc := 0.0
var _fps_n := 0


class FloorDraw extends Node2D:
	var cols := 8
	var rows := 8
	var wire := false
	var marks: Array = []

	func _draw() -> void:
		for s in range(0, cols + rows - 1):
			for c in cols:
				var r := s - c
				if r < 0 or r >= rows:
					continue
				var o := Vector2(float(c - r) * 48.0 - 48.0, float(c + r) * 24.0)
				TerrainTex.draw_tile(self, o, "plain", PLAINS, TerrainTex.variant_of(c, r), 0.0, 0)
		if wire:
			var col := Color(1, 1, 0, 0.9)
			for c in cols + 1:
				draw_line(Vector2(float(c) * 48.0, float(c) * 24.0), Vector2(float(c - rows) * 48.0, float(c + rows) * 24.0), col, 1.0)
			for r in rows + 1:
				draw_line(Vector2(float(-r) * 48.0, float(r) * 24.0), Vector2(float(cols - r) * 48.0, float(cols + r) * 24.0), col, 1.0)


func _ready() -> void:
	args = OS.get_cmdline_user_args()
	rng.seed = 20261020
	_load_data()
	world = Node2D.new()
	add_child(world)
	floor_draw = FloorDraw.new()
	world.add_child(floor_draw)
	layer = Layer.new()
	world.add_child(layer)
	overlay = Node2D.new()
	world.add_child(overlay)
	ui = CanvasLayer.new()
	add_child(ui)
	_build_ui()
	var bg := ColorRect.new()
	bg.color = Color("0a0e1a")
	bg.z_index = -100
	bg.size = Vector2(4000, 3000)
	bg.position = Vector2(-1500, -1000)
	add_child(bg)
	move_child(bg, 0)
	_layout()
	await _refresh()
	if "--nomerge" in args:
		KChar.merge_meshes = false
	if "--bench" in args and "--kay" in args:
		layer.char_script = KChar
		KChar.tex_levels_default = 3
		post_mode = 1
	if "--autob" in args:
		_auto_b.call_deferred()
	elif "--auto" in args:
		_auto.call_deferred()
	elif "--bench" in args:
		_bench.call_deferred()


func _load_data() -> void:
	var f := FileAccess.open("res://data/sprites.json", FileAccess.READ)
	sprites_json = JSON.parse_string(f.get_as_text())
	sdb = SpriteDB.new(sprites_json)
	var pf := FileAccess.open("res://assets/pilot3d/palette.json", FileAccess.READ)
	pal_json = JSON.parse_string(pf.get_as_text())
	var cols: Array = pal_json["colors32"]
	var img := Image.create(cols.size(), 1, false, Image.FORMAT_RGBA8)
	for i in cols.size():
		img.set_pixel(i, 0, Color(str(cols[i])))
	pal_tex = ImageTexture.create_from_image(img)


# ── 배치 ──

func _layout() -> void:
	var win := get_viewport().get_visible_rect().size
	world.scale = Vector2(zoom, zoom)
	# 격자 가운데(월드 화면 좌표 (0, 192)) 를 오른쪽 작업 영역 가운데에
	var cx := win.x * 0.5 + (150.0 if (ui != null and panel != null and panel.visible) else 0.0)
	world.position = Vector2(cx, win.y * 0.5 + 10.0) - Vector2(0, 168) * zoom


func _tile_world(c: float, r: float) -> Vector3:
	return Vector3(c + 0.5, 0.0, r + 0.5)


func _make_entries() -> Array:
	var out: Array = []
	var ph := 0.0
	if not entries_override.is_empty():
		for e: Dictionary in entries_override:
			var t: Vector2 = e["tile"]
			var d: Dictionary = e.duplicate()
			d["pos"] = _tile_world(t.x, t.y)
			out.append(d)
		return out
	var kay: bool = (layer.char_script == KChar)
	var RL: GDScript = KLook if kay else Look
	var base_look: Dictionary = cur_klook if kay else cur_look
	if count == 1:
		out.append({"look": base_look, "pos": _tile_world(3, 3), "dir": cur_dir, "anim": cur_anim, "phase": 0.0})
	elif count == 9:
		var r2 := RandomNumberGenerator.new()
		r2.seed = 77
		for i in 9:
			var c := 1 + (i % 3) * 2
			var r := 1 + (i / 3) * 2
			var lk: Dictionary = base_look if i == 0 else RL.random_look(r2)
			out.append({"look": lk, "pos": _tile_world(c, r), "dir": cur_dir, "anim": cur_anim, "phase": ph})
			ph += 0.37
	else:
		var r3 := RandomNumberGenerator.new()
		r3.seed = 99
		var i := 0
		for r in 5:
			for c in 6:
				if i >= count:
					break
				out.append({"look": RL.random_look(r3), "pos": _tile_world(c + 1, r + 1), "dir": (cur_dir + (i % 3)) % 8, "anim": cur_anim, "phase": ph})
				ph += 0.23
				i += 1
	return out


func _style() -> Dictionary:
	return {"steps": cel_steps, "dither": dither, "outline_on": hull_on, "outline_width": line_w / (Iso.PPU * kk)}


func _post() -> Dictionary:
	return {"mode": post_mode, "levels": post_levels, "outline_on": post_outline, "pal_tex": pal_tex, "pal_n": (pal_json["colors32"] as Array).size()}


func _refresh() -> void:
	if _busy:
		return
	_busy = true
	_entries = _make_entries()
	await layer.build(_entries, mode, kk, _style())
	layer.set_post(_post())
	_build_legacy()
	_update_overlay()
	if look_label != null:
		look_label.text = Look.pack(cur_look)
	_busy = false


func _build_legacy() -> void:
	for n: Node in legacy_nodes:
		n.queue_free()
	legacy_nodes.clear()
	if not compare and legacy_override.is_empty():
		return
	var cls := ""
	var g := "m"
	var sh: Variant = null
	var pl: Dictionary = {}
	var tex: Texture2D = null
	var tiles: Array = [{"key": compare_cls, "tile": Vector2(4, 2)}] if count == 1 else []
	if not legacy_override.is_empty():
		tiles = legacy_override
	for te: Dictionary in tiles:
		var t: Vector2 = te["tile"]
		var parts2 := str(te["key"]).split("_")
		cls = parts2[0]
		g = "f" if parts2[1] == "02" else "m"
		sh = sdb.sheet(cls, g, "idle")
		pl = sdb.sheet_place(cls, g, sh)
		tex = sdb.sheet_tex(sh)
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.region_enabled = true
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var foot := Iso.to_screen(_tile_world(t.x, t.y)) + Vector2(0, -3)
		sp.position = foot + (pl["pos"] as Vector2)
		sp.scale = Vector2(float(pl["scale"]), float(pl["scale"]))
		sp.set_meta("sh", sh)
		sp.region_rect = Rect2(0, 0, float((sh as Dictionary)["w"]), float((sh as Dictionary)["h"]))
		world.add_child(sp)
		legacy_nodes.append(sp)
		sp.z_index = int(t.x + t.y) * 3


func _update_overlay() -> void:
	for ch in overlay.get_children():
		ch.queue_free()
	(floor_draw as FloorDraw).wire = show_overlay
	floor_draw.queue_redraw()
	if not show_overlay:
		return
	var R := Rect2(-420, -150, 840, 600)
	var vp := SubViewport.new()
	vp.size = Vector2i(R.size)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	overlay.add_child(vp)
	var ctr := R.get_center()
	var tx := (ctr.x / 48.0 + ctr.y / 24.0) * 0.5
	var tz := (ctr.y / 24.0 - ctr.x / 48.0) * 0.5
	var cam := Iso.make_camera(R.size.y, 1.0)
	vp.add_child(cam)
	Iso.aim(cam, Vector3(tx, 0, tz))
	cam.current = true
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var mg := Color(1, 0.1, 0.9)
	for c in GRID.x + 1:
		im.surface_set_color(mg); im.surface_add_vertex(Vector3(c, 0, 0))
		im.surface_set_color(mg); im.surface_add_vertex(Vector3(c, 0, GRID.y))
	for r in GRID.y + 1:
		im.surface_set_color(mg); im.surface_add_vertex(Vector3(0, 0, r))
		im.surface_set_color(mg); im.surface_add_vertex(Vector3(GRID.x, 0, r))
	# 높이 1 유닛 상자 (타일 한 칸 크기 정육면체) 두 개 + 기둥 — 높이 눈금
	var cy := Color(0.2, 1, 1)
	for bc: Vector2 in [Vector2(1, 5), Vector2(6, 2)]:
		var p: Array = [Vector3(bc.x, 0, bc.y), Vector3(bc.x + 1, 0, bc.y), Vector3(bc.x + 1, 0, bc.y + 1), Vector3(bc.x, 0, bc.y + 1)]
		for i in 4:
			var a: Vector3 = p[i]
			var b: Vector3 = p[(i + 1) % 4]
			im.surface_set_color(cy); im.surface_add_vertex(a + Vector3(0, 1, 0))
			im.surface_set_color(cy); im.surface_add_vertex(b + Vector3(0, 1, 0))
			im.surface_set_color(cy); im.surface_add_vertex(a)
			im.surface_set_color(cy); im.surface_add_vertex(a + Vector3(0, 1, 0))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	vp.add_child(mi)
	var sp := Sprite2D.new()
	sp.texture = vp.get_texture()
	sp.centered = false
	sp.position = R.position
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.z_index = 4000
	overlay.add_child(sp)
	# 숫자 검증: 3D 카메라가 투영한 격자 꼭짓점 vs 2D 식
	await get_tree().process_frame
	var worst := 0.0
	for c in GRID.x + 1:
		for r in GRID.y + 1:
			var p3 := cam.unproject_position(Vector3(c, 0, r))
			var p2 := Iso.to_screen(Vector3(c, 0, r)) - R.position
			worst = maxf(worst, p3.distance_to(p2))
	var ph := cam.unproject_position(Vector3(0, 1, 0)).distance_to(Iso.to_screen(Vector3(0, 1, 0)) - R.position)
	overlay.set_meta("err", worst)
	overlay.set_meta("err_h", ph)


# ── UI ──

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(6, 6)
	panel.custom_minimum_size = Vector2(250, 0)
	ui.add_child(panel)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(250, 700)
	panel.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	sc.add_child(vb)
	var t := Label.new()
	t.text = "3D 캐릭터 시범 (2.5D 등각)"
	vb.add_child(t)
	_opt(vb, "모델", ["임시 사람(도형)", "KayKit(CC0 실제 모델)"], 0, func(i: int) -> void:
		_use_model(i == 1)
		_refresh())
	for slot: String in Parts.SLOT_ORDER:
		var items: Array = []
		for i in Parts.count(slot):
			items.append(Parts.part_name(slot, i))
		_opt(vb, Parts.SLOT_LABEL[slot], items, cur_look["s"][slot], func(i: int) -> void: _set_slot(slot, i))
	for k: String in Look.COL_ORDER:
		var items2: Array = []
		for i in Look.col_count(k):
			items2.append("%s %d" % [{"skin": "피부", "hair": "머리색", "cloth": "옷색", "metal": "금속"}[k], i + 1])
		_opt(vb, "색 · " + k, items2, cur_look["c"][k], func(i: int) -> void: _set_col(k, i))
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	_btn(hb, "무작위 외형", func() -> void:
		cur_klook = KLook.random_look(rng)
		cur_look = Look.random_look(rng)
		_sync_opts()
		_refresh())
	_btn(hb, "기본", func() -> void:
		cur_look = Look.default_look()
		_sync_opts()
		_refresh())
	look_label = LineEdit.new()
	look_label.text = Look.pack(cur_look)
	look_label.text_submitted.connect(func(s: String) -> void:
		cur_look = Look.unpack(s)
		_sync_opts()
		_refresh())
	vb.add_child(look_label)
	var h2 := HBoxContainer.new()
	vb.add_child(h2)
	for a: String in Anims.ORDER:
		var an := a
		_btn(h2, an, func() -> void:
			cur_anim = an
			_refresh())
	var h3 := HBoxContainer.new()
	vb.add_child(h3)
	_btn(h3, "◀", func() -> void:
		cur_dir = posmod(cur_dir - 1, 8)
		_refresh())
	_btn(h3, "▶", func() -> void:
		cur_dir = posmod(cur_dir + 1, 8)
		_refresh())
	_opt(vb, "시점 줌", ["1배", "2배", "3배", "4배"], int(zoom) - 1, func(i: int) -> void:
		zoom = float(i + 1)
		_layout())
	_opt(vb, "렌더 방식", Layer.MODE_NAME, mode, func(i: int) -> void:
		mode = i
		_refresh())
	_opt(vb, "인원", ["1명", "9명", "27명"], 0, func(i: int) -> void:
		count = [1, 9, 27][i]
		_refresh())
	_opt(vb, "해상도(k)", ["k=1 (화면과 같은 도트)", "k=2 (2배 촘촘)"], 0, func(i: int) -> void:
		kk = [1.0, 2.0][i]
		_refresh())
	_opt(vb, "색 줄이기", ["끔", "HSV 끊기", "게임 팔레트 32색"], 1, func(i: int) -> void:
		post_mode = i
		_refresh())
	_opt(vb, "명암 단계", ["2단", "3단", "4단"], 2, func(i: int) -> void:
		cel_steps = i + 2
		_refresh())
	_chk(vb, "외곽선(뒤집은 메시)", hull_on, func(v: bool) -> void:
		hull_on = v
		_refresh())
	_chk(vb, "외곽선(후처리)", post_outline, func(v: bool) -> void:
		post_outline = v
		_refresh())
	_chk(vb, "도트 디더", false, func(v: bool) -> void:
		dither = 1.0 if v else 0.0
		_refresh())
	_chk(vb, "2D 캐릭터 나란히", compare, func(v: bool) -> void:
		compare = v
		if v:
			cur_look = (CLASS_LOOKS[compare_cls] as Dictionary).duplicate(true)
			_sync_opts()
		_refresh())
	_opt(vb, "2D 직업", ["knight_01", "mage_01", "brawler_01", "priest_01"], 0, func(i: int) -> void:
		compare_cls = ["knight_01", "mage_01", "brawler_01", "priest_01"][i]
		cur_look = (CLASS_LOOKS[compare_cls] as Dictionary).duplicate(true)
		_sync_opts()
		_refresh())
	_chk(vb, "3D 격자 겹쳐 보기", show_overlay, func(v: bool) -> void:
		show_overlay = v
		_refresh())
	_btn(vb, "성능 시험 (콘솔·화면)", func() -> void: _bench())
	info = Label.new()
	info.text = ""
	vb.add_child(info)


func _opt(parent: Node, label: String, items: Array, sel: int, cb: Callable) -> OptionButton:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(88, 0)
	h.add_child(l)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in items.size():
		o.add_item(str(items[i]), i)
	o.select(sel)
	o.item_selected.connect(cb)
	h.add_child(o)
	_opts[label] = o
	return o


func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _chk(parent: Node, text: String, v: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = v
	c.toggled.connect(cb)
	parent.add_child(c)
	return c


func _set_slot(slot: String, i: int) -> void:
	cur_look["s"][slot] = i
	_refresh()


func _set_col(k: String, i: int) -> void:
	cur_look["c"][k] = i
	_refresh()


func _sync_opts() -> void:
	for slot: String in Parts.SLOT_ORDER:
		(_opts[Parts.SLOT_LABEL[slot]] as OptionButton).select(cur_look["s"][slot])
	for k: String in Look.COL_ORDER:
		(_opts["색 · " + k] as OptionButton).select(cur_look["c"][k])


func _process(delta: float) -> void:
	_t += delta
	if _bench_on:
		_bench_dt.append(delta)
	for n: Node in legacy_nodes:
		var sp := n as Sprite2D
		var sh: Dictionary = sp.get_meta("sh")
		var fr := int(sh["frames"])
		var f := int(floor(fmod(_t, float(sh["dur"]) / 1000.0) / (float(sh["dur"]) / 1000.0) * float(fr)))
		sp.region_rect = Rect2(f * float(sh["w"]), 0, float(sh["w"]), float(sh["h"]))
	_fps_acc += delta
	_fps_n += 1
	if _fps_acc > 0.5 and info != null:
		info.text = "%.1f fps · 그리기 호출 %d · 영상메모리 %.1f MB" % [float(_fps_n) / _fps_acc, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]
		_fps_acc = 0.0
		_fps_n = 0


# ── 사진 ──

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _shot(name: String, crop: Variant = null, dir: String = SHOT_DIR) -> void:
	await _frames(6)
	var img := get_viewport().get_texture().get_image()
	if crop != null:
		var sc := float(img.get_width()) / get_viewport().get_visible_rect().size.x
		var r: Rect2 = crop
		img = img.get_region(Rect2i(Vector2i(r.position * sc), Vector2i(r.size * sc)))
	var path := ProjectSettings.globalize_path(dir + name + ".png") if dir.begins_with("res://") else dir + name + ".png"
	img.save_png(path)
	print("[p3] shot ", path, " ", img.get_size())


func _setup(p_count: int, p_zoom: float, p_anim: String = "idle", p_dir: int = 2) -> void:
	count = p_count
	zoom = p_zoom
	cur_anim = p_anim
	cur_dir = p_dir
	_layout()
	await _refresh()


func _hide_ui(v: bool) -> void:
	panel.visible = not v
	_layout()


func _look9(i: int) -> Dictionary:
	var helm := [0, 1, 2, 3, 0, 2, 3, 1, 0]
	var cape := [0, 1, 2, 0, 1, 0, 2, 1, 0]
	var wep := [1, 2, 3, 4, 1, 3, 2, 1, 4]
	var shd := [0, 1, 2, 3, 0, 0, 1, 2, 3]
	return {"v": 1, "s": {"hair": i % 4, "face": (i + 1) % 4, "top": i % 3, "bottom": (i + 1) % 3, "shoes": (i + 2) % 3, "helm": helm[i], "cape": cape[i], "weapon": wep[i], "shield": shd[i]},
		"c": {"skin": i % 6, "hair": (i * 3) % 8, "cloth": (i * 5 + 1) % 8, "metal": i % 4}}


## 한 줄(화면 가로) 배치: 칸 (c+i, r-i) 은 화면 y 가 같고 x 만 96px 씩 벌어짐
func _row(looks: Array, c0: float, r0: float, dir: int, anim: String = "idle", speed: float = 1.0, phases: Array = []) -> Array:
	var out: Array = []
	for i in looks.size():
		out.append({"look": looks[i], "tile": Vector2(c0 + i, r0 - i), "dir": dir, "anim": anim, "phase": (phases[i] if phases.size() > i else 0.3 * i), "speed": speed})
	return out


func _stage(entries: Array, p_zoom: float, center_tile: Vector2 = Vector2(4, 4)) -> void:
	entries_override = entries
	count = max(1, entries.size())
	zoom = p_zoom
	var win := get_viewport().get_visible_rect().size
	var cs := Iso.to_screen(_tile_world(center_tile.x, center_tile.y))
	world.scale = Vector2(zoom, zoom)
	world.position = win * 0.5 - cs * zoom
	await _refresh()


func _auto() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _frames(5)
	var only := ""
	for a in args:
		if a.begins_with("--only="):
			only = a.substr(7)
	if only == "" or only == "ui":
		compare = true
		compare_cls = "knight_01"
		cur_look = (CLASS_LOOKS[compare_cls] as Dictionary).duplicate(true)
		_sync_opts()
		cur_dir = 1
		await _setup(1, 2.0, "idle", 1)
		await _shot("p3_00_dev_scene_ui")
		compare = false
		_build_legacy()
	_hide_ui(true)
	if only == "" or only == "camera":
		show_overlay = false
		await _setup(1, 2.0)
		await _shot("p3_01_camera_2d_only")
		show_overlay = true
		await _refresh()
		await _frames(3)
		await _shot("p3_02_camera_overlay")
		print("[p3] camera error px: grid ", overlay.get_meta("err", -1), " height1 ", overlay.get_meta("err_h", -1))
		show_overlay = false
		entries_override = []
	if only == "" or only == "looks":
		var ls: Array = []
		for i in 9:
			ls.append(_look9(i))
		var en: Array = []
		for i in 9:
			en.append({"look": ls[i], "tile": Vector2(2 + (i % 3) * 2, 2 + (i / 3) * 2 - (i % 3) * 2 + (i % 3) * 2 - 0), "dir": 1, "anim": "idle", "phase": 0.2 * i})
		# 3x3 를 화면에서 보기 좋게: (c, r) = (2+2a, 2+2b)
		en.clear()
		for i in 9:
			en.append({"look": ls[i], "tile": Vector2(2 + (i % 3) * 2, 2 + (i / 3) * 2), "dir": 1, "anim": "idle", "phase": 0.2 * i})
		await _stage(en, 2.0, Vector2(4.5, 4.5))
		await _shot("p3_03_looks9")
		print("[p3] look sample: ", Look.pack(ls[0]), " ", Look.pack(ls[5]))
		# 슬롯별 한 줄씩
		var rows: Array = []
		var row_names := ["hair", "face", "top", "bottom", "shoes"]
		var en2: Array = []
		for ri in row_names.size():
			var slot: String = row_names[ri]
			var n: int = Parts.count(slot)
			var lks: Array = []
			for j in n:
				var lk := Look.default_look()
				lk["s"][slot] = j
				lk["c"]["cloth"] = 1 if slot != "top" else 3
				lks.append(lk)
			var row := _row(lks, 1.5 + ri * 1.0 - 1, 3.5 + ri * 1.0 + 0.0, 1, "idle", 0.0)
			en2.append_array(row)
		await _stage(en2, 2.0, Vector2(3.0, 4.0))
		await _shot("p3_04_slots_a")
		var en3: Array = []
		var row_names2 := ["helm", "cape", "weapon", "shield"]
		for ri in row_names2.size():
			var slot2: String = row_names2[ri]
			var n2: int = Parts.count(slot2)
			var lks2: Array = []
			for j in n2:
				var lk2 := Look.default_look()
				lk2["s"][slot2] = j
				lk2["s"]["weapon"] = 1 if slot2 != "weapon" else j
				if slot2 == "cape":
					lk2["c"]["cloth"] = 1
				lks2.append(lk2)
			en3.append_array(_row(lks2, 1.5 + ri * 1.0 - 1, 3.5 + ri * 1.0, 3 if slot2 == "cape" else 1, "idle", 0.0))
		await _stage(en3, 2.0, Vector2(3.0, 3.8))
		await _shot("p3_04_slots_b")
		var en7: Array = []
		for i in 4:
			var lh := Look.default_look()
			lh["s"]["hair"] = i
			lh["s"]["face"] = 0
			lh["s"]["weapon"] = 0
			en7.append({"look": lh, "tile": Vector2(0.0 + i, 3.0 - i), "dir": 1, "anim": "idle", "phase": 0.0, "speed": 0.0})
			var lf := Look.default_look()
			lf["s"]["face"] = i
			lf["s"]["weapon"] = 0
			lf["s"]["hair"] = 0
			en7.append({"look": lf, "tile": Vector2(2.0 + i, 5.0 - i), "dir": 1, "anim": "idle", "phase": 0.0, "speed": 0.0})
		await _stage(en7, 3.0, Vector2(2.5, 3.5))
		await _shot("p3_04_heads")
		entries_override = []
	if only == "close":
		var en5: Array = []
		var i5 := 0
		for cls2: String in ["knight_01", "mage_01", "brawler_01", "priest_01"]:
			en5.append({"look": CLASS_LOOKS[cls2], "tile": Vector2(1.0 + i5, 4.0 - i5), "dir": 1, "anim": "idle", "phase": 0.0, "speed": 0.0})
			i5 += 1
		await _stage(en5, 5.0, Vector2(2.5, 2.5))
		await _shot("p3_dbg_close")
		_auto_done()
		return
	if only == "" or only == "anim":
		var lk3: Dictionary = (CLASS_LOOKS["knight_01"] as Dictionary).duplicate(true)
		lk3["s"]["helm"] = 0
		lk3["s"]["face"] = 0
		lk3["c"]["cloth"] = 1
		for an: String in Anims.ORDER:
			var len_: float = Anims.LEN[an]
			var en6: Array = []
			for i in 8:
				var ph2 := len_ * float(i) / 8.0 if Anims.LOOP[an] else len_ * float(i) / 7.0 * 0.985
				en6.append({"look": lk3, "tile": Vector2(1.0 + (i % 4), 3.0 - (i % 4) + (i / 4) * 2.0), "dir": 2, "anim": an, "phase": ph2, "speed": 0.0})
			await _stage(en6, 3.0, Vector2(2.0, 3.0))
			await _shot("p3_05_anim_" + an)
		entries_override = []
	if only == "" or only == "dirs":
		var lk4: Dictionary = (CLASS_LOOKS["knight_01"] as Dictionary).duplicate(true)
		lk4["s"]["helm"] = 0
		lk4["s"]["face"] = 0
		lk4["s"]["hair"] = 0
		lk4["c"]["cloth"] = 1
		var en4: Array = []
		for d in 8:
			en4.append({"look": lk4, "tile": Vector2(1.0 + (d % 4) + 2.0 * (d / 4), 3.0 - (d % 4) + 2.0 * (d / 4)), "dir": d, "anim": "idle", "phase": 0.0, "speed": 0.0})
		await _stage(en4, 2.0, Vector2(3.5, 3.0))
		await _shot("p3_06_dirs8")
		entries_override = []
	if only == "" or only == "compare":
		compare = true
		for cls: String in ["knight_01", "mage_01", "brawler_01", "priest_01"]:
			compare_cls = cls
			cur_look = (CLASS_LOOKS[cls] as Dictionary).duplicate(true)
			entries_override = []
			count = 1
			cur_dir = 1
			zoom = 3.0
			world.scale = Vector2(3, 3)
			var cs2 := Iso.to_screen(Vector3(3.9, 0, 2.9))
			world.position = get_viewport().get_visible_rect().size * 0.5 - cs2 * 3.0 + Vector2(0, 50)
			for pm in [0, 1, 2]:
				post_mode = pm
				await _refresh()
				await _shot("p3_07_compare_%s_post%d" % [cls, pm])
		compare = false
	if only == "export":
		var sdir2 := ""
		for a in args:
			if a.begins_with("--tmp="):
				sdir2 = a.substr(6)
		var en9: Array = []
		var i9 := 0
		for cls3: String in ["knight_01", "mage_01", "brawler_01", "priest_01"]:
			en9.append({"look": CLASS_LOOKS[cls3], "tile": Vector2(1.0 + i9, 4.0 - i9), "dir": 2, "anim": "idle", "phase": 0.0, "speed": 0.0})
			i9 += 1
		post_mode = 0
		layer.atlas_group = 0
		mode = Layer.Mode.ATLAS
		await _stage(en9, 1.0, Vector2(2.5, 2.5))
		await _frames(5)
		var img3: Image = (layer._owned[0] as SubViewport).get_texture().get_image()
		img3.save_png(sdir2 + "atlas_k1_raw.png")
		kk = 2.0
		await _refresh()
		await _frames(5)
		var img4: Image = (layer._owned[0] as SubViewport).get_texture().get_image()
		img4.save_png(sdir2 + "atlas_k2_raw.png")
		_auto_done()
		return
	if only == "style":
		var sdir := ""
		for a in args:
			if a.begins_with("--tmp="):
				sdir = a.substr(6)
		var variants: Array = [
			{"steps": 3, "dither": 0.0, "hull": true, "pm": 0, "po": false},
			{"steps": 4, "dither": 0.0, "hull": true, "pm": 1, "po": false},
			{"steps": 4, "dither": 1.0, "hull": true, "pm": 1, "po": false},
			{"steps": 3, "dither": 0.0, "hull": true, "pm": 2, "po": false},
		]
		compare = true
		for cls: String in ["knight_01", "brawler_01"]:
			compare_cls = cls
			cur_look = (CLASS_LOOKS[cls] as Dictionary).duplicate(true)
			entries_override = []
			count = 1
			cur_dir = 1
			zoom = 3.0
			world.scale = Vector2(3, 3)
			world.position = get_viewport().get_visible_rect().size * 0.5 - Iso.to_screen(Vector3(3.9, 0, 2.9)) * 3.0 + Vector2(0, 50)
			for vi in variants.size():
				var v: Dictionary = variants[vi]
				cel_steps = v["steps"]
				dither = v["dither"]
				hull_on = v["hull"]
				post_mode = v["pm"]
				post_outline = v["po"]
				await _refresh()
				await _shot("v%d_%s" % [vi, cls], Rect2(340, 170, 600, 400), sdir)
		_auto_done()
		return
	if only == "" or only == "battle":
		# 실제 전투 크기 (줌 1) — 3D 캐릭터 6명(아군) 과 2D 캐릭터 5명(적) 이 한 화면에
		var r5 := RandomNumberGenerator.new()
		r5.seed = 5
		var en8: Array = []
		var cl_keys := ["knight_01", "mage_01", "brawler_01", "priest_01"]
		for i in 6:
			var lk8: Dictionary = (CLASS_LOOKS[cl_keys[i % 4]] as Dictionary).duplicate(true) if i < 4 else Look.random_look(r5)
			en8.append({"look": lk8, "tile": Vector2(1 + (i % 3), 2 + (i / 3) * 1), "dir": 2, "anim": "idle", "phase": 0.17 * i})
		legacy_override = [{"key": "knight_02", "tile": Vector2(4, 4)}, {"key": "archer_01", "tile": Vector2(5, 4)}, {"key": "brawler_01", "tile": Vector2(5, 5)}, {"key": "mage_02", "tile": Vector2(6, 5)}, {"key": "priest_01", "tile": Vector2(4, 6)}]
		post_mode = 0
		await _stage(en8, 1.0, Vector2(3.5, 4.0))
		await _shot("p3_08_battle_size")
		await _shot("p3_08_battle_size_crop", Rect2(300, 190, 520, 300))
		legacy_override = []
		entries_override = []
		_build_legacy()
	if only == "" or only == "27":
		count = 27
		cur_anim = "idle"
		cur_dir = 2
		zoom = 1.0
		for m in [Layer.Mode.ATLAS, Layer.Mode.INDIVIDUAL, Layer.Mode.BAKED]:
			mode = m
			_layout()
			world.position = get_viewport().get_visible_rect().size * 0.5 - Iso.to_screen(_tile_world(3.5, 3.0)) * zoom
			await _refresh()
			await _frames(30)
			await _shot("p3_09_27_mode%d" % m)
		mode = Layer.Mode.ATLAS
	_auto_done()


func _auto_done() -> void:
	print("[p3] auto done")
	get_tree().quit()


var _bench_on := false
var _bench_dt: Array = []


func _all_vp_rids() -> Array:
	var out: Array = [get_viewport().get_viewport_rid()]
	for v: Node in layer._owned:
		if is_instance_valid(v):
			out.append((v as SubViewport).get_viewport_rid())
	return out


func _bench_case(p_mode: int, n: int, p_k: float, anim: String = "walk") -> Dictionary:
	count = n
	mode = p_mode
	kk = p_k
	cur_anim = anim
	entries_override = []
	if n == 0:
		layer.clear()
		_build_legacy()
	else:
		await _refresh()
	var rids := _all_vp_rids()
	for r: RID in rids:
		RenderingServer.viewport_set_measure_render_time(r, true)
	await _frames(40)
	_bench_dt.clear()
	_bench_on = true
	var calls := 0.0
	var prims := 0.0
	var tproc := 0.0
	var ns := 0
	for i in 240:
		await get_tree().process_frame
		if i >= 200:
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			tproc += Performance.get_monitor(Performance.TIME_PROCESS)
			ns += 1
	_bench_on = false
	var gpu := 0.0
	var cpu := 0.0
	for r: RID in rids:
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(r)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(r)
	var arr := _bench_dt.duplicate()
	arr.sort()
	var sum := 0.0
	for v: float in arr:
		sum += v
	var baked_bytes := 0
	for it: Dictionary in layer.items:
		if it.has("bake"):
			baked_bytes += int((it["bake"] as Dictionary)["bytes"])
	return {"mode": Layer.MODE_NAME[p_mode], "n": n, "k": p_k, "anim": anim,
		"frame_ms_avg": snappedf(sum / float(arr.size()) * 1000.0, 0.01), "frame_ms_p95": snappedf(float(arr[int(arr.size() * 0.95)]) * 1000.0, 0.01),
		"frame_ms_max": snappedf(float(arr[arr.size() - 1]) * 1000.0, 0.01),
		"draw_calls": snappedf(calls / float(ns), 0.1), "primitives": int(prims / float(ns)), "process_ms": snappedf(tproc / float(ns) * 1000.0, 0.01),
		"vmem_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"tex_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)), "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"build_ms": snappedf(layer.bake_ms, 0.1), "baked_mb": snappedf(float(baked_bytes) / 1048576.0, 2), "gpu_ms": gpu, "cpu_render_ms": cpu, "viewports": rids.size()}


func _bench() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_hide_ui(true)
	panel.visible = false
	show_overlay = false
	compare = false
	zoom = 1.0
	_layout()
	post_mode = 0
	var res: Array = []
	floor_draw.visible = "--floor" in args
	var Md := Layer.Mode
	res.append(await _bench_case(Md.ATLAS, 0, 1.0))
	var short := "--short" in args
	for n in ([1, 27] if short else [1, 9, 27]):
		for m in ([Md.INDIVIDUAL, Md.ATLAS, Md.BAKED] if n != 27 else [Md.ATLAS, Md.INDIVIDUAL, Md.BAKED, Md.ATLAS, Md.INDIVIDUAL]):
			var r: Dictionary = await _bench_case(m, n, 1.0)
			print("[p3] bench ", JSON.stringify(r))
			res.append(r)
	for m in ([] if short else [Md.INDIVIDUAL, Md.ATLAS]):
		var r2: Dictionary = await _bench_case(m, 27, 2.0)
		print("[p3] bench ", JSON.stringify(r2))
		res.append(r2)
	for g in ([] if short else [9, 3, 1]):
		layer.atlas_group = g
		var rg: Dictionary = await _bench_case(Md.ATLAS, 27, 1.0)
		rg["note"] = "아틀라스 묶음 %d명씩" % g
		print("[p3] bench ", JSON.stringify(rg))
		res.append(rg)
	layer.atlas_group = 0
	if not short:
		var r3: Dictionary = await _bench_case(Md.ATLAS, 27, 1.0, "idle")
		r3["note"] = "idle"
		res.append(r3)
		var r4: Dictionary = await _bench_case(Md.BAKED, 27, 2.0)
		res.append(r4)
	# 한 캐릭터를 8방향 × 8프레임으로 구울 때 크기
	var one: Dictionary = await layer.bake_sheet(Look.default_look(), "walk", 8, [0, 1, 2, 3, 4, 5, 6, 7])
	res.append({"note": "한 명 walk 8프레임×8방향 구움 MB (k=1)", "mb": snappedf(float(one["bytes"]) / 1048576.0, 2)})
	var path := "user://p3_bench.json"
	for a in args:
		if a.begins_with("--out="):
			path = a.substr(6)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	print("[p3] bench saved ", path)
	if "--bench" in args:
		get_tree().quit()


# ══════════ 2단계: KayKit 실제 모델 ══════════
const KChar := preload("res://dev/pilot3d/p3b_char.gd")
const KLook := preload("res://dev/pilot3d/p3b_look.gd")


func _use_model(kay: bool) -> void:
	layer.char_script = KChar if kay else preload("res://dev/pilot3d/p3_char.gd")


func _klook(body: int, helm: int, cape: int, weapon: int, shield: int, skin: int = 0, hair: int = 3, cloth: int = 0, metal: int = 0) -> Dictionary:
	return {"v": 2, "s": {"body": body, "helm": helm, "cape": cape, "weapon": weapon, "shield": shield}, "c": {"skin": skin, "hair": hair, "cloth": cloth, "metal": metal}}


func _auto_b() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _frames(5)
	_hide_ui(true)
	_use_model(true)
	var only := ""
	for a in args:
		if a.begins_with("--only="):
			only = a.substr(7)
	post_mode = 0
	cel_steps = 4
	if only == "m1":
		for m in [Layer.Mode.INDIVIDUAL, Layer.Mode.ATLAS]:
			mode = m
			await _stage([{"look": _klook(0, 1, 1, 1, 1), "tile": Vector2(3, 3), "dir": 1, "anim": "idle", "phase": 0.3}], 4.0, Vector2(3.5, 3.5))
			await _frames(10)
			await _shot("p3b_dbg_m1_%d" % m)
		_auto_done()
		return
	if only == "" or only == "models":
		var en: Array = []
		for i in 6:
			en.append({"look": _klook(i, 1, 1, [1, 2, 3, 8, 5, 6][i], [1, 0, 0, 0, 0, 0][i], 0, [3, 1, 0, 2, 1, 4][i], i), "tile": Vector2(1.0 + (i % 3), 3.0 - (i % 3) + 2.0 * (i / 3)), "dir": 1, "anim": "idle", "phase": 0.2 * i})
		await _stage(en, 3.0, Vector2(2.0, 3.0))
		await _shot("p3b_01_models")
	if only == "post":
		var tmp := ""
		for a in args:
			if a.begins_with("--tmp="):
				tmp = a.substr(6)
		var en2: Array = []
		for i in 3:
			en2.append({"look": _klook([0, 2, 3][i], 1, 1, [1, 6, 8][i], [1, 0, 0][i], 0, [3, 0, 2][i], [0, 3, 1][i]), "tile": Vector2(2.0 + i, 3.0 - i), "dir": 1, "anim": "idle", "phase": 0.2 * i, "speed": 0.0})
		var variants: Array = [
			{"n": "A 원본 텍스처 · 4단 셀", "tl": 0, "pm": 0, "st": 4},
			{"n": "B + HSV 끊기(명도6)", "tl": 0, "pm": 1, "st": 4},
			{"n": "C 칸 안 그라데이션 3단 + HSV", "tl": 3, "pm": 1, "st": 4},
			{"n": "D 칸마다 한 색 + 3단 셀 + HSV", "tl": 1, "pm": 1, "st": 3},
		]
		for vi in variants.size():
			var v: Dictionary = variants[vi]
			post_mode = v["pm"]
			cel_steps = v["st"]
			layer.char_script.tex_levels_default = v["tl"]
			await _stage(en2, 3.5, Vector2(3.0, 2.0))
			await _shot("v%d" % vi, Rect2(200, 40, 800, 400), tmp)
		_auto_done()
		return
	var kcls := {"knight_01": _klook(0, 1, 1, 1, 1, 0, 3, 0), "mage_01": _klook(2, 1, 0, 6, 0, 0, 0, 3), "brawler_01": _klook(1, 0, 0, 4, 0, 2, 4, 7), "priest_01": _klook(2, 0, 1, 7, 0, 5, 5, 6)}
	if only == "" or only == "compare":
		compare = true
		for cls: String in ["knight_01", "mage_01", "brawler_01", "priest_01"]:
			compare_cls = cls
			for pm in [0, 1]:
				post_mode = pm
				await _stage([{"look": kcls[cls], "tile": Vector2(3, 3), "dir": 1, "anim": "idle", "phase": 0.2}], 4.0, Vector2(3.5, 2.5))
				await _shot("p3b_03_compare_%s_post%d" % [cls, pm])
		compare = false
		post_mode = 1
		_build_legacy()
	if only == "" or only == "battle":
		var kk8: Array = ["knight_01", "mage_01", "brawler_01", "priest_01"]
		var en8: Array = []
		var r5 := RandomNumberGenerator.new()
		r5.seed = 5
		for i in 6:
			var lk8: Dictionary = (kcls[kk8[i]] as Dictionary) if i < 4 else KLook.random_look(r5)
			en8.append({"look": lk8, "tile": Vector2(1 + (i % 3), 3 + (i / 3) * 1), "dir": 2, "anim": "idle", "phase": 0.17 * i})
		legacy_override = [{"key": "knight_02", "tile": Vector2(5, 1)}, {"key": "archer_01", "tile": Vector2(6, 1)}, {"key": "brawler_01", "tile": Vector2(5, 2)}, {"key": "mage_02", "tile": Vector2(6, 2)}, {"key": "priest_01", "tile": Vector2(7, 2)}]
		await _stage(en8, 1.0, Vector2(4.0, 2.5))
		await _shot("p3b_04_battle_size")
		await _shot("p3b_04_battle_size_crop", Rect2(340, 230, 560, 240))
		await _stage(en8, 2.0, Vector2(4.0, 2.5))
		await _shot("p3b_04_battle_size_x2", Rect2(120, 110, 1040, 500))
		legacy_override = []
		_build_legacy()
	if only == "" or only == "dirs":
		var en4: Array = []
		for d in 8:
			en4.append({"look": kcls["knight_01"], "tile": Vector2(1.0 + (d % 4) + 2.0 * (d / 4), 3.0 - (d % 4) + 2.0 * (d / 4)), "dir": d, "anim": "idle", "phase": 0.0, "speed": 0.0})
		await _stage(en4, 2.0, Vector2(3.5, 3.0))
		await _shot("p3b_05_dirs8")
	if only == "" or only == "anim":
		for an: String in ["idle", "walk", "attack", "hit"]:
			var lk3: Dictionary = kcls["knight_01"]
			var len_: float = KChar.len_for(lk3, an)
			var en6: Array = []
			for i in 8:
				var ph2 := len_ * float(i) / 8.0 if an in ["idle", "walk"] else len_ * float(i) / 7.0 * 0.985
				en6.append({"look": lk3, "tile": Vector2(1.0 + (i % 4), 3.0 - (i % 4) + (i / 4) * 2.0), "dir": 2, "anim": an, "phase": ph2, "speed": 0.0})
			await _stage(en6, 3.0, Vector2(2.5, 3.0))
			await _shot("p3b_06_anim_" + an)
		# 직업별 공격(무기에 맞는 동작)
		var en7: Array = []
		var cls_att := [["knight_01", "attack"], ["brawler_01", "attack"], ["mage_01", "attack"], ["priest_01", "cast"]]
		for ci in 4:
			var lk4: Dictionary = kcls[cls_att[ci][0]]
			var an4: String = cls_att[ci][1]
			var l4: float = KChar.len_for(lk4, an4)
			for fi in 3:
				en7.append({"look": lk4, "tile": Vector2(1.0 + fi + 2.0 * (ci % 2), 3.0 - fi + 2.0 * (ci / 2) + 2.0 * (ci % 2)), "dir": 2, "anim": an4, "phase": l4 * (0.2 + 0.28 * fi), "speed": 0.0})
		await _stage(en7, 2.0, Vector2(3.5, 4.0))
		await _shot("p3b_06_anim_by_class")
	if only == "" or only == "looks":
		var r9 := RandomNumberGenerator.new()
		r9.seed = 11
		var en9: Array = []
		for i in 9:
			en9.append({"look": KLook.random_look(r9), "tile": Vector2(1 + (i % 3) * 2, 1 + (i / 3) * 2), "dir": 1, "anim": "idle", "phase": 0.2 * i})
		await _stage(en9, 2.0, Vector2(3.5, 3.5))
		await _shot("p3b_07_looks9")
		# 색 바꾸기: 같은 기사 8색 / 마법사 머리색·피부색
		var en10: Array = []
		for i in 8:
			en10.append({"look": _klook(0, 0, 1, 1, 1, i % 6, [3, 1, 4, 5, 0, 2, 6, 7][i], i, [0, 1, 2, 3, 0, 1, 2, 3][i]), "tile": Vector2(1.0 + (i % 4), 3.0 - (i % 4) + (i / 4) * 2.0), "dir": 1, "anim": "idle", "phase": 0.0, "speed": 0.0})
		await _stage(en10, 3.0, Vector2(2.5, 3.0))
		await _shot("p3b_08_colors_knight")
		var en11: Array = []
		for i in 8:
			en11.append({"look": _klook(2, 0, 0, 6, 0, [0, 1, 2, 3, 4, 5, 0, 2][i], i, 3), "tile": Vector2(1.0 + (i % 4), 3.0 - (i % 4) + (i / 4) * 2.0), "dir": 1, "anim": "idle", "phase": 0.0, "speed": 0.0})
		await _stage(en11, 3.0, Vector2(2.5, 3.0))
		await _shot("p3b_08_colors_mage_hair_skin")
		var en12: Array = []
		for i in 6:
			en12.append({"look": _klook(i, 1, 1, 0, 0, 0, 3, 1), "tile": Vector2(1.0 + (i % 3), 3.0 - (i % 3) + (i / 3) * 2.0), "dir": 1, "anim": "idle", "phase": 0.0, "speed": 0.0})
		await _stage(en12, 3.0, Vector2(2.0, 3.0))
		await _shot("p3b_08_colors_all_blue")
	if only == "" or only == "problems":
		var enp: Array = []
		var lkp1 := _klook(1, 1, 1, 4, 1, 2, 4, 7)
		var lkp2 := _klook(3, 1, 1, 8, 0, 0, 3, 1)
		var lkp3 := _klook(0, 0, 0, 1, 1, 1, 3, 1)
		var lkp4 := _klook(2, 0, 0, 7, 0, 3, 4, 3)
		var spec := [[lkp1, "attack", 0.35], [lkp2, "attack", 0.45], [lkp3, "idle", 0.0], [lkp4, "cast", 0.4]]
		for i in 4:
			var lp: Dictionary = spec[i][0]
			enp.append({"look": lp, "tile": Vector2(1.0 + i, 4.0 - i), "dir": 1 if i != 0 else 2, "anim": spec[i][1], "phase": float(spec[i][2]), "speed": 0.0})
		await _stage(enp, 3.0, Vector2(2.5, 3.0))
		await _shot("p3b_09_problems")
	if only == "" or only == "27":
		count = 27
		zoom = 1.0
		entries_override = []
		cur_anim = "idle"
		cur_dir = 2
		for m in [Layer.Mode.ATLAS, Layer.Mode.INDIVIDUAL, Layer.Mode.BAKED]:
			mode = m
			_layout()
			world.position = get_viewport().get_visible_rect().size * 0.5 - Iso.to_screen(_tile_world(3.5, 3.0)) * zoom
			await _refresh()
			await _frames(30)
			await _shot("p3b_10_27_mode%d" % m)
	_auto_done()
