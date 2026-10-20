extends Node2D
## 3D 캐릭터 → 2D 맵 위 스프라이트 (Sprite2D) — 세 가지 방식을 같은 모양으로 바꿔 쓸 수 있음
##   INDIVIDUAL : 캐릭터마다 SubViewport 하나 (직교 카메라 · 투명 배경)
##   ATLAS      : SubViewport 하나에 여러 명을 칸(셀)으로 나눠 그리고, 스프라이트마다 AtlasTexture 로 한 칸씩 나눠 씀
##   BAKED      : 한 번만 그려서(방향×프레임) ImageTexture 로 읽어 두고 SubViewport 는 버림 (이후엔 2D 스프라이트만)
## 스프라이트 발 위치 = 3D 월드 (x=c, z=r) → Iso.to_screen — 2D 맵의 y 정렬(앞뒤 가림)을 그대로 씀

const Iso := preload("res://dev/pilot3d/p3_iso.gd")
const Char := preload("res://dev/pilot3d/p3_char.gd")
const Anims := preload("res://dev/pilot3d/p3_anims.gd")

enum Mode { INDIVIDUAL, ATLAS, BAKED }
const MODE_NAME := ["개별 SubViewport", "아틀라스(공유 SubViewport)", "구워 두기(캐시)"]
const BASE_CELL := Vector2(112, 128)
const BASE_FOOT := Vector2(56, 104)
## 게임과 같은 발 위치: 타일 윗면 가운데에서 3px 위 (iso.gd foot)
const FOOT_LIFT := -3.0

var mode: int = Mode.ATLAS
var k := 1.0
var cell := Vector2i(112, 128)
var foot := Vector2(56, 104)
var items: Array = []        # {look, pos(Vector3), dir, anim, char, sprite, ...}
var post_mat: ShaderMaterial
var style: Dictionary = {}
var _owned: Array = []       # SubViewport 들
var _bake: Dictionary = {}   # 구운 결과 (item → {tex, frames, dirs})
var bake_ms := 0.0
var _t := 0.0
var char_script: GDScript = Char    # 캐릭터 구현 (임시 사람 P3Char / KayKit P3bChar)
var atlas_group := 0    # 0 = 전부 한 SubViewport


func _ready() -> void:
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://dev/pilot3d/post.gdshader")


func clear() -> void:
	for it: Dictionary in items:
		if it.get("sprite") != null:
			(it["sprite"] as Node).queue_free()
		if it.get("char") != null and is_instance_valid(it["char"]):
			(it["char"] as Node).queue_free()
	for vp: Node in _owned:
		if is_instance_valid(vp):
			vp.queue_free()
	_owned.clear()
	items.clear()
	_bake.clear()


func _make_vp(size: Vector2i, once: bool = false) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE if once else SubViewport.UPDATE_ALWAYS
	add_child(vp)
	_owned.append(vp)
	return vp


func _cam(vp: SubViewport, target: Vector3) -> Camera3D:
	var cam := Iso.make_camera(float(vp.size.y), k)
	vp.add_child(cam)
	Iso.aim(cam, target)
	cam.current = true
	return cam


func _new_sprite(it: Dictionary) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.offset = -foot / k
	s.scale = Vector2(1.0 / k, 1.0 / k)
	s.position = Iso.to_screen(it["pos"]) + Vector2(0, FOOT_LIFT)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = post_mat
	add_child(s)
	return s


func _new_char(it: Dictionary) -> Node3D:
	var c: Node3D = char_script.new()
	c.apply_look(it["look"])
	c.set_dir(it.get("dir", 0))
	c.set_style(style)
	var len_: float = char_script.len_for(it["look"], it.get("anim", "idle"))
	c.play(it.get("anim", "idle"), float(it.get("speed", 1.0)), fmod(float(it.get("phase", 0.0)), len_))
	return c


## entries: [{look, pos: Vector3(월드), dir, anim, phase}]
func build(entries: Array, p_mode: int, p_k: float, p_style: Dictionary) -> void:
	clear()
	mode = p_mode
	k = p_k
	style = p_style
	cell = Vector2i(ceili(BASE_CELL.x * k), ceili(BASE_CELL.y * k))
	foot = BASE_FOOT * k
	if entries.is_empty():
		return
	for e: Dictionary in entries:
		items.append(e.duplicate())
	var t0 := Time.get_ticks_usec()
	match mode:
		Mode.INDIVIDUAL:
			for it: Dictionary in items:
				var vp := _make_vp(cell)
				_cam(vp, Iso.target_for_foot(Vector3.ZERO, float(cell.y), foot.y, k))
				var c := _new_char(it)
				vp.add_child(c)
				it["char"] = c
				it["vp"] = vp
				var sp := _new_sprite(it)
				sp.texture = vp.get_texture()
				it["sprite"] = sp
		Mode.ATLAS:
			# atlas_group 명씩 한 SubViewport 에 묶음 (기본 전부)
			var gsize := atlas_group if atlas_group > 0 else items.size()
			var start := 0
			while start < items.size():
				var n := mini(gsize, items.size() - start)
				var cols := mini(n, 6)
				var rows := ceili(float(n) / float(cols))
				var vp := _make_vp(Vector2i(cols * cell.x, rows * cell.y))
				_cam(vp, Vector3.ZERO)
				var b := Iso.cam_basis()
				for i in n:
					var it: Dictionary = items[start + i]
					var ci := i % cols
					var ri := i / cols
					var dx := float(ci * cell.x) + foot.x - float(vp.size.x) * 0.5
					var dy := float(ri * cell.y) + foot.y - float(vp.size.y) * 0.5
					var c := _new_char(it)
					c.position = b.x * (dx / (Iso.PPU * k)) - b.y * (dy / (Iso.PPU * k))
					vp.add_child(c)
					it["char"] = c
					var at := AtlasTexture.new()
					at.atlas = vp.get_texture()
					at.region = Rect2(ci * cell.x, ri * cell.y, cell.x, cell.y)
					var sp := _new_sprite(it)
					sp.texture = at
					it["sprite"] = sp
				start += n
		Mode.BAKED:
			for it: Dictionary in items:
				var r: Dictionary = await bake_sheet(it["look"], it.get("anim", "idle"), 8, [it.get("dir", 0)])
				var sp := _new_sprite(it)
				var at := AtlasTexture.new()
				at.atlas = r["tex"]
				at.region = Rect2(0, 0, cell.x, cell.y)
				sp.texture = at
				it["sprite"] = sp
				it["bake"] = r
	bake_ms = (Time.get_ticks_usec() - t0) / 1000.0


## 방향 × 프레임을 한 장(ImageTexture)으로 구워 둠. 칸 = (프레임 f, 방향 d) → 가로 f, 세로 d
func bake_sheet(look: Dictionary, anim: String, frames: int, dirs: Array) -> Dictionary:
	var vp := _make_vp(Vector2i(cell.x * frames, cell.y * dirs.size()), true)
	_cam(vp, Vector3.ZERO)
	var b := Iso.cam_basis()
	var len_: float = char_script.len_for(look, anim)
	for di in dirs.size():
		for f in frames:
			var c: Node3D = char_script.new()
			c.apply_look(look)
			c.set_style(style)
			c.set_manual(true)
			c.set_dir(dirs[di])
			c.pose_at(anim, len_ * float(f) / float(frames))
			var dx := float(f * cell.x) + foot.x - float(vp.size.x) * 0.5
			var dy := float(di * cell.y) + foot.y - float(vp.size.y) * 0.5
			c.position = b.x * (dx / (Iso.PPU * k)) - b.y * (dy / (Iso.PPU * k))
			vp.add_child(c)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	_owned.erase(vp)
	vp.queue_free()
	return {"tex": ImageTexture.create_from_image(img), "frames": frames, "dirs": dirs, "bytes": img.get_data().size(), "len": len_}


func set_post(d: Dictionary) -> void:
	for key: String in d.keys():
		post_mat.set_shader_parameter(key, d[key])


func _process(delta: float) -> void:
	_t += delta
	if mode == Mode.BAKED:
		for it: Dictionary in items:
			if it.has("bake") and it.get("sprite") != null:
				var r: Dictionary = it["bake"]
				var f := int(floor(fmod(_t + float(it.get("phase", 0.0)), float(r["len"])) / float(r["len"]) * float(r["frames"])))
				((it["sprite"] as Sprite2D).texture as AtlasTexture).region = Rect2(f * cell.x, 0, cell.x, cell.y)
