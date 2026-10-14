extends Node2D
## 전장 바닥 — 웹 render.js rTerBg·rTer (타일·하이라이트·안개·냉기 결계·위협) + props.js (숲 나무·평지 풀돌) + 보물상자
##  앞뒤 순서 (z_index, 웹 z-index 와 같은 규칙):
##    대각선 k = vc+vr 마다 타일 노드 z = 2k (+ 같은 z 의 바닥 장식·물 반짝임), 하이라이트 노드 z = 2k+1
##    나무 (칸마다 한 노드) z = Grid.depth(c,r,1) = 100 + 3k + 1, 보물상자 z = 100 + 3k, 유닛 z = 100 + 3k + 2 (unit_view.gd)
##  타일 그림은 바뀔 때(카메라 회전·지형 변화)만 다시 그림. 하이라이트는 깜빡임 때문에 보일 때만 매 프레임 다시 그림.
##  (3b) 카메라 방향마다 노드 묶음(타일·장식·나무·하이라이트)을 따로 만들어 두고, 회전은 묶음을 바꿔 보이기만 함 (다시 만들지 않음 →
##       회전 끊김 제거). 지형이 바뀌면 묶음을 모두 버리고 다시. prebuild_step() 으로 로딩 중에 네 방향을 미리 만들고 타일 그림도 미리 구움.

const Iso := preload("res://scripts/battle/iso.gd")
const TerrainTex := preload("res://scripts/battle/terrain_tex.gd")
const SpriteDB := preload("res://scripts/battle/sprite_db.gd")
const PropShader := preload("res://scripts/battle/shaders/prop.gdshader")
const WaterShader := preload("res://scripts/battle/shaders/water.gdshader")

const TW := Iso.TW
const TH := Iso.TH

var iso: Iso
var TI: Dictionary
var theme: Dictionary = {}
var theme_name := "plains"
var tile_props: Dictionary = {}
var prop_art: Dictionary = {}
var sdb: SpriteDB
var lava := false

## 하이라이트 상태 ("x,y" → 종류): move · vault · attack · block · heal · cover · selected
var hl: Dictionary = {}
var fog_vis: Dictionary = {}      # "x,y" → true (보이는 칸). 비어 있으면 안개 없음 취급 안 함 — fog_on 으로
var fog_on := true
var threat: Dictionary = {}
var safe: Dictionary = {}
var chests: Array = []            # [[x, y], …]
var move_color := Color("3b82f6")

var _tile_nodes: Array = []
var _hl_nodes: Array = []         # 대각선마다 HlDiag
var _tree_nodes: Dictionary = {}  # "x,y" → TreeNode
## 카메라 방향 → {root: Node2D, tiles, hls, trees} (지금 방향 묶음만 보임)
var _sets: Dictionary = {}
var _set_dir := -1
var _chest_nodes: Array = []
var _prop_mat: ShaderMaterial
var _clr: Dictionary = {}         # 타일 종류 → {tc, lc, rc} (Color)
var _t := 0.0


# ═══════════ 노드 종류 ═══════════

## 한 대각선의 타일 그림
##  타일 그림은 종류·색·변형·높이·성가퀴마다 한 번 텍스처로 구워 두고(웹 TerrainTex 캐시와 같은 생각) 한 장씩 붙인다.
##  아직 굽지 못했거나 화면 없이(headless) 돌 때는 같은 그림을 벡터로 바로 그림 — 결과 모양은 같음.
class TileDiag extends Node2D:
	var map: Node
	var tiles: Array = []   # {o, tp, clr, v, h, open, key}

	func _draw() -> void:
		for t: Dictionary in tiles:
			var tex: Texture2D = map._tile_tex(t)
			if tex != null:
				var cap: float = TerrainTex.CAP.get(t["tp"], 0.0)
				draw_texture_rect(tex, Rect2(t["o"] - Vector2(0, cap), Vector2(TerrainTex.TW * 2.0, TerrainTex.TH * 2.0 + float(t["h"]) + 2.0 + cap)), false)
			else:
				TerrainTex.draw_tile(self, t["o"], t["tp"], t["clr"], t["v"], t["h"], t["open"])


## 타일 하나를 원점 (0, CAP) 에 BAKE_K 배로 그리는 붓 (SubViewport 안)
class BakePainter extends Node2D:
	var t: Dictionary

	func _draw() -> void:
		TerrainTex.draw_tile(self, Vector2(0, TerrainTex.CAP.get(t["tp"], 0.0)), t["tp"], t["clr"], t["v"], t["h"], t["open"])


## 한 대각선의 바닥 장식 (평지 풀·돌) — 테마 색 보정 셰이더
class GroundDiag extends Node2D:
	var map: Node
	var props: Array = []   # {tex, rect, flip, key}

	func _draw() -> void:
		for p: Dictionary in props:
			var r: Rect2 = p["rect"]
			if p["flip"]:
				r = Rect2(r.position.x + r.size.x, r.position.y, -r.size.x, r.size.y)
			# 안개 칸 장식은 어둡게 (웹 .map-prop.fow: brightness(.4))
			var dark: bool = map.fog_on and not map.fog_vis.has(p["key"])
			draw_texture_rect(p["tex"], r, false, Color(0.4, 0.4, 0.4) if dark else Color.WHITE)


## 물·용암 반짝임 (셰이더 — 타일 그림 좌표를 UV 로)
class WaterDiag extends Node2D:
	var polys: Array = []   # PackedVector2Array (윗면 마름모), uv

	func _draw() -> void:
		for p: Array in polys:
			draw_polygon(p[0], PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), p[1])


## 칸 하나의 나무들 (숲) — 가리면 반투명, 안개면 어둡게
class TreeNode extends Node2D:
	var props: Array = []   # {tex, rect, flip, fx, fy, hw, h, fade}

	func _draw() -> void:
		for p: Dictionary in props:
			var r: Rect2 = p["rect"]
			if p["flip"]:
				r = Rect2(r.position.x + r.size.x, r.position.y, -r.size.x, r.size.y)
			draw_texture_rect(p["tex"], r, false, Color(1, 1, 1, 0.4) if p["fade"] else Color.WHITE)


## 보물상자 (웹 .chest-marker: 위아래로 흔들림)
class ChestNode extends Node2D:
	var tex: Texture2D
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var bob := -4.0 * (0.5 - 0.5 * cos(t / 1.6 * TAU))
		draw_circle(Vector2(0, -8 + bob), 13.0, Color(0.98, 0.8, 0.08, 0.16))
		if tex != null:
			draw_texture_rect(tex, Rect2(-13, -22 + bob, 26, 26), false)


## 하이라이트·안개·결계·위협 (대각선마다)
class HlDiag extends Node2D:
	var map: Node   # battle_map
	var cells: Array = []   # {key, o, h, shape, inset}
	var stripes: Dictionary = {}   # key → [[poly, color], …] (줄무늬 — 하이라이트가 바뀔 때만 계산)
	var animated := false   # 깜빡이는 칸이 있음 (상태가 바뀔 때만 다시 계산)

	func _draw() -> void:
		map._draw_hl_diag(self)


# ═══════════ 준비 ═══════════

func setup(p_iso: Iso, D: Dictionary, p_theme: String, p_sdb: SpriteDB, p_lava: bool) -> void:
	iso = p_iso
	TI = D["TI"]
	sdb = p_sdb
	theme_name = p_theme
	var themes: Dictionary = D["MAP_THEMES"]
	theme = themes.get(p_theme, themes["plains"])
	move_color = Color(str(theme.get("move", "#3b82f6")))
	tile_props = D.get("TILE_PROPS", {})
	prop_art = D.get("PROP_ART", {})
	lava = p_lava
	# 테마 색 (웹 Grid._tColors: 테마에 있으면 테마 색, 없으면 TI 기본)
	var tcol: Dictionary = theme.get("colors", {})
	for tp: String in TI.keys():
		var src: Dictionary = tcol[tp] if tcol.has(tp) else TI[tp]
		_clr[tp] = {"tc": Color(str(src["tc"])), "lc": Color(str(src["lc"])), "rc": Color(str(src["rc"]))}
	_prop_mat = ShaderMaterial.new()
	_prop_mat.shader = PropShader
	var filt: String = str((D.get("PROP_THEME_FILTER", {}) as Dictionary).get(p_theme, ""))
	var m := SpriteDB.css_filter_matrix(filt)
	# Basis 는 열 벡터 — 행 = (x[i], y[i], z[i])
	_prop_mat.set_shader_parameter("row0", Vector3(m.x.x, m.y.x, m.z.x))
	_prop_mat.set_shader_parameter("row1", Vector3(m.x.y, m.y.y, m.z.y))
	_prop_mat.set_shader_parameter("row2", Vector3(m.x.z, m.y.z, m.z.z))


func _process(d: float) -> void:
	_t += d
	# 깜빡이는 하이라이트가 있는 대각선만 다시 그림 (깜빡임 여부는 상태가 바뀔 때 _redraw_hl 이 계산)
	for n: HlDiag in _hl_nodes:
		if n.animated:
			n.queue_redraw()


const ANIM_KINDS := {"move": true, "attack": true, "heal": true, "selected": true, "skill": true}


func _diag_animated(n: HlDiag) -> bool:
	for c: Dictionary in n.cells:
		var k: String = c["key"]
		if safe.has(k):
			return true
		if hl.has(k) and (not fog_on or fog_vis.has(k)) and ANIM_KINDS.has(hl[k]):
			return true
	return false


## 전부 다시 만들기 (카메라 회전·지형 변화)
# ── 타일 텍스처 굽기 ──

const BAKE_K := 3.0
var _tex_cache: Dictionary = {}     # 키 → ImageTexture
var _bake_wait: Dictionary = {}     # 키 → 타일 자료 (구울 차례)
var _baking := false
var can_bake := DisplayServer.get_name() != "headless"


func _tile_tex(t: Dictionary) -> Texture2D:
	var key: String = t["key"]
	if _tex_cache.has(key):
		return _tex_cache[key]
	if can_bake and not _bake_wait.has(key):
		_bake_wait[key] = t
		if not _baking:
			_baking = true
			_bake_batch.call_deferred()
	return null


## 기다리는 타일을 한꺼번에 굽기: 타일마다 SubViewport 하나 → 한 프레임 그린 뒤 이미지로 읽어 캐시
func _bake_batch() -> void:
	var jobs: Array = []
	for key: String in _bake_wait.keys():
		var t: Dictionary = _bake_wait[key]
		var cap: float = TerrainTex.CAP.get(t["tp"], 0.0)
		var vp := SubViewport.new()
		vp.size = Vector2i(ceili(TerrainTex.TW * 2.0 * BAKE_K), ceili((TerrainTex.TH * 2.0 + float(t["h"]) + 2.0 + cap) * BAKE_K))
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var p := BakePainter.new()
		p.t = t
		p.scale = Vector2(BAKE_K, BAKE_K)
		vp.add_child(p)
		add_child(vp)
		jobs.append([key, vp])
	_bake_wait.clear()
	await RenderingServer.frame_post_draw
	for j: Array in jobs:
		var vp2: SubViewport = j[1]
		var img := vp2.get_texture().get_image()
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			_tex_cache[j[0]] = ImageTexture.create_from_image(img)
		vp2.queue_free()
	_baking = false
	# 구운 그림으로 다시 그림 (숨은 방향 묶음도 — 그래야 나중에 보일 때 벡터 그림 대신 구운 그림)
	for st: Dictionary in _sets.values():
		for n: Node in st["tiles"]:
			if is_instance_valid(n):
				(n as CanvasItem).queue_redraw()
	if not _bake_wait.is_empty():
		_baking = true
		_bake_batch.call_deferred()


## 지형이 바뀜 (또는 처음): 방향별 묶음을 모두 버리고 지금 방향을 다시 만듦
func rebuild() -> void:
	for dir: int in _sets.keys():
		(_sets[dir]["root"] as Node).queue_free()
	_sets.clear()
	_set_dir = -1
	switch_dir()


## 카메라 회전: 그 방향 묶음이 있으면 보이기만, 없으면 만듦 (지형은 그대로)
func switch_dir() -> void:
	var dir := iso.cam_dir
	if not _sets.has(dir):
		_build_set(dir)
	_activate(dir)


## 아직 없는 방향 묶음 하나를 미리 만듦 (로딩 중 프레임마다) — 더 만들 것이 남았으면 true
func prebuild_step() -> bool:
	for k in 4:
		var dir := (iso.cam_dir + k) % 4
		if not _sets.has(dir):
			var keep := iso.cam_dir
			iso.cam_dir = dir
			_build_set(dir)
			iso.cam_dir = keep
			# 로딩 화면이 덮고 있는 동안은 보이게 두어 한 번 그려 둠 (그리기 명령이 기록되어, 나중에 보이기만 바꿀 때 _draw 를 다시 안 함)
			#  — finish_prebuild() 가 지금 방향 묶음만 남기고 숨김. 타일 그림도 이때 함께 구워짐
			for tn: TileDiag in _sets[dir]["tiles"]:
				for t: Dictionary in tn.tiles:
					_tile_tex(t)
			return true
	return false


## 로딩 끝: 지금 방향 묶음만 보이게
func finish_prebuild() -> void:
	for d2: int in _sets.keys():
		(_sets[d2]["root"] as Node2D).visible = d2 == _set_dir


func _activate(dir: int) -> void:
	for d2: int in _sets.keys():
		(_sets[d2]["root"] as Node2D).visible = d2 == dir
	var st: Dictionary = _sets[dir]
	_tile_nodes = st["tiles"]
	_hl_nodes = st["hls"]
	_tree_nodes = st["trees"]
	_set_dir = dir
	_rebuild_chests()
	_restripe()
	apply_fog_to_props()
	_redraw_hl()


## 한 방향의 노드 묶음 (iso.cam_dir 가 그 방향인 상태에서 부름)
func _build_set(dir: int) -> void:
	var root := Node2D.new()
	root.name = "Dir%d" % dir
	add_child(root)
	var keep_trees := _tree_nodes
	_tree_nodes = {}
	var hls: Array = []
	var nd := iso.diag_count()
	var tdiag: Array = []
	var gdiag: Array = []
	var wdiag: Array = []
	for k in nd:
		var t := TileDiag.new()
		t.map = self
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		t.z_index = 2 * k
		t.name = "Tiles%d" % k
		tdiag.append(t)
		var g := GroundDiag.new()
		g.z_index = 2 * k
		g.material = _prop_mat
		g.map = self
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gdiag.append(g)
		var w := WaterDiag.new()
		w.z_index = 2 * k
		var wm := ShaderMaterial.new()
		wm.shader = WaterShader
		if lava:
			wm.set_shader_parameter("band", Color(1.0, 140.0 / 255.0, 40.0 / 255.0, 0.28))
			wm.set_shader_parameter("period", 2.6)
			wm.set_shader_parameter("half_w", 0.2)
		w.material = wm
		wdiag.append(w)
		var h := HlDiag.new()
		h.z_index = 2 * k + 1
		h.map = self
		hls.append(h)
	for r in iso.rows:
		for c in iso.cols:
			var tp := iso.tile_type(c, r)
			if tp == "" or not TI.has(tp):
				continue
			var k2 := iso.diag(c, r)
			var h2 := float(TI[tp]["z"]) * Iso.ZH
			var o := Vector2(iso.tsx(c, r), iso.tsy(c, r, float(TI[tp]["z"])))
			var v2 := TerrainTex.variant_of(c, r)
			var op2 := _wall_open(c, r) if tp == "wall" else 0
			(tdiag[k2] as TileDiag).tiles.append({"o": o, "tp": tp, "clr": _clr[tp], "v": v2, "h": h2, "open": op2, "key": "%s|%s|%d|%d|%d" % [tp, theme_name, v2, int(h2), op2]})
			if tp == "water":
				var uv := PackedVector2Array([Vector2(TW, 0), Vector2(TW * 2, TH), Vector2(TW, TH * 2), Vector2(0, TH)])
				(wdiag[k2] as WaterDiag).polys.append([Iso.diamond(o), uv])
			(hls[k2] as HlDiag).cells.append({"key": "%d,%d" % [c, r], "c": c, "r": r, "o": o, "h": h2,
				"shape": Iso.hl_shape(o, h2), "inset": _inset(Iso.hl_shape(o, h2))})
			_place_props(c, r, tp, gdiag[k2])
	for k3 in nd:
		root.add_child(tdiag[k3])
		if not (gdiag[k3] as GroundDiag).props.is_empty():
			root.add_child(gdiag[k3])
		else:
			(gdiag[k3] as Node).free()
		if not (wdiag[k3] as WaterDiag).polys.is_empty():
			root.add_child(wdiag[k3])
		else:
			(wdiag[k3] as Node).free()
		root.add_child(hls[k3])
	for key: String in _tree_nodes.keys():
		root.add_child(_tree_nodes[key])
	_sets[dir] = {"root": root, "tiles": tdiag, "hls": hls, "trees": _tree_nodes}
	_tree_nodes = keep_trees


## 성벽 성가퀴: 이웃이 성벽이 아닌 화면 가장자리 (1 뒤-왼쪽, 2 뒤-오른쪽, 4 앞-왼쪽, 8 앞-오른쪽 — 카메라 회전 반영)
func _wall_open(c: int, r: int) -> int:
	var open := 0
	var v0 := iso.g2v(c, r)
	var dm := iso.vdim()
	for e: Array in [[1, -1, 0], [2, 0, -1], [4, 0, 1], [8, 1, 0]]:
		var vc: int = v0.x + int(e[1])
		var vr: int = v0.y + int(e[2])
		var is_wall := false
		if vc >= 0 and vr >= 0 and vc < dm.x and vr < dm.y:
			var g := iso.v2g(vc, vr)
			is_wall = iso.tile_type(g.x, g.y) == "wall"
		if not is_wall:
			open |= int(e[0])
	return open


static func _inset(shape: PackedVector2Array) -> PackedVector2Array:
	var r := Geometry2D.offset_polygon(shape, -1.0)
	if r.is_empty():
		return shape
	var p: PackedVector2Array = r[0]
	p.append(p[0])
	return p


# ── 맵 오브젝트 (웹 props.js) ──

## 칸 좌표로 고정되는 0~1 난수 (웹 Props._rnd)
static func prop_rnd(c: int, r: int, k: int) -> float:
	var a := TerrainTex._i32((c + 1) * 73856093)
	var b := TerrainTex._i32((r + 1) * 19349663)
	var e := TerrainTex._i32(k * 83492791)
	return float(((a ^ b ^ e) & 0xFFFFFFFF) % 10000) / 10000.0


func _place_props(c: int, r: int, tp: String, gnode: GroundDiag) -> void:
	var def: Variant = tile_props.get(tp)
	if typeof(def) != TYPE_DICTIONARY:
		return
	if def.get("chance") != null and prop_rnd(c, r, 1) >= float(def["chance"]):
		return
	var spots: Array = [def.get("at", [0, 0])]
	if def.has("spots"):
		var sp: Array = def["spots"]
		var cnt: Array = def["count"]
		var n := int(cnt[0]) + floori(prop_rnd(c, r, 6) * (float(cnt[1]) - float(cnt[0]) + 1.0))
		var s0 := floori(prop_rnd(c, r, 7) * sp.size())
		spots = []
		for i in mini(n, sp.size()):
			spots.append(sp[(s0 + i) % sp.size()])
	# 뒤쪽(화면 위)부터 — 웹 sort((p, q) => p[1] - q[1]) (안정 정렬)
	var idx: Array = range(spots.size())
	idx.sort_custom(func(a: int, b: int) -> bool:
		var da := float(spots[a][1])
		var db := float(spots[b][1])
		return da < db if da != db else a < b)
	var arts: Array = def["art"]
	var ground: bool = bool(def.get("ground", false))
	var tree: TreeNode = null
	var top := iso.top_center(c, r)
	for i in idx.size():
		var at: Array = spots[idx[i]]
		var k := 10 + i * 7
		var name := str(arts[floori(prop_rnd(c, r, k) * arts.size())])
		var art: Dictionary = prop_art.get(name, {"h": 40})
		var t := sdb.tex(SpriteDB.IMG + "map/" + name + ".png")
		if t == null:
			continue
		var sc := 1.0
		if def.has("scale"):
			sc = float(def["scale"][0]) + prop_rnd(c, r, k + 1) * (float(def["scale"][1]) - float(def["scale"][0]))
		var h := roundf(float(art["h"]) * sc)
		var w := h * float(t.get_width()) / float(t.get_height())
		var spread := float(def.get("spread", 0.0))
		var fx := top.x + (float(at[0]) + (prop_rnd(c, r, k + 2) - 0.5) * spread) * TW
		var fy := top.y + (float(at[1]) + (prop_rnd(c, r, k + 3) - 0.5) * spread) * TH
		var p := {"tex": t, "rect": Rect2(fx - w / 2.0, fy - h, w, h), "flip": prop_rnd(c, r, k + 4) < 0.5, "fx": fx, "fy": fy, "hw": w / 2.0, "h": h, "fade": false, "key": "%d,%d" % [c, r]}
		if ground:
			gnode.props.append(p)
		else:
			if tree == null:
				tree = TreeNode.new()
				tree.z_index = iso.depth(c, r, 1)
				tree.material = _prop_mat
				tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tree.set_meta("key", "%d,%d" % [c, r])
				_tree_nodes["%d,%d" % [c, r]] = tree
			tree.props.append(p)


## 나무가 뒤쪽 유닛을 가리면 반투명 (웹 Props.fade) — units: [{p: 타일 윗면 가운데, d: 깊이}]
func update_fade(units: Array) -> void:
	for key: String in _tree_nodes.keys():
		var tn: TreeNode = _tree_nodes[key]
		var changed := false
		for p: Dictionary in tn.props:
			var f := false
			for u: Dictionary in units:
				var up: Vector2 = u["p"]
				if int(u["d"]) < tn.z_index and absf(up.x - float(p["fx"])) < float(p["hw"]) + 14.0 and up.y < float(p["fy"]) and up.y > float(p["fy"]) - float(p["h"]) - Iso.UH * 0.6:
					f = true
					break
			if f != bool(p["fade"]):
				p["fade"] = f
				changed = true
		if changed:
			tn.queue_redraw()


func apply_fog_to_props() -> void:
	for key: String in _tree_nodes.keys():
		var tn: TreeNode = _tree_nodes[key]
		tn.modulate = Color(0.4, 0.4, 0.4) if fog_on and not fog_vis.has(key) else Color.WHITE
	for ch: Node2D in _chest_nodes:
		ch.visible = not fog_on or fog_vis.has(str(ch.get_meta("key")))
	if _sets.has(_set_dir):
		for n: Node in (_sets[_set_dir]["root"] as Node).get_children():
			if n is GroundDiag:
				(n as CanvasItem).queue_redraw()


# ── 보물상자 ──

func set_chests(list: Array) -> void:
	chests = list.duplicate(true)
	_rebuild_chests()
	apply_fog_to_props()


func _rebuild_chests() -> void:
	for n: Node in _chest_nodes:
		n.queue_free()
	_chest_nodes.clear()
	var tex := sdb.tex(SpriteDB.IMG + "icon/item/chest.png")
	for ch: Array in chests:
		var c: int = int(ch[0])
		var r: int = int(ch[1])
		var n := ChestNode.new()
		n.tex = tex
		n.position = iso.top_center(c, r)
		n.z_index = iso.depth(c, r, 0)
		n.set_meta("key", "%d,%d" % [c, r])
		add_child(n)
		_chest_nodes.append(n)


# ── 하이라이트 상태 ──

func set_hl(m: Dictionary) -> void:
	hl = m
	_restripe()
	_redraw_hl()


func set_fog(vis: Dictionary) -> void:
	if vis == fog_vis:
		return   # 시야가 그대로면 다시 그리지 않음
	fog_vis = vis
	apply_fog_to_props()
	_redraw_hl()


func set_threat(cells: Array) -> void:
	threat = {}
	for k: String in cells:
		threat[k] = true
	_restripe()
	_redraw_hl()


func set_safe(cells: Array) -> void:
	safe = {}
	for k: String in cells:
		safe[k] = true
	_redraw_hl()


func _redraw_hl() -> void:
	for n: HlDiag in _hl_nodes:
		n.animated = n.visible and _diag_animated(n)
		n.queue_redraw()


## 줄무늬 (repeating-linear-gradient) 를 칸 모양으로 잘라 미리 계산 — vault·block·cover·threat
func _restripe() -> void:
	for n: HlDiag in _hl_nodes:
		n.stripes.clear()
		for c: Dictionary in n.cells:
			var k: String = c["key"]
			var list: Array = []
			match str(hl.get(k, "")):
				"vault":
					list.append_array(_stripes(c["shape"], -45.0, 5.0, 10.0, Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.38), Color(move_color, 0.16)))
				"block":
					list.append_array(_stripes(c["shape"], 45.0, 5.0, 10.0, Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.36), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.24)))
				"cover":
					list.append_array(_stripes(c["shape"], 45.0, 6.0, 12.0, Color(148 / 255.0, 163 / 255.0, 184 / 255.0, 0.18), Color(148 / 255.0, 163 / 255.0, 184 / 255.0, 0.06)))
			if threat.has(k):
				list.append_array(_stripes(c["shape"], -45.0, 4.0, 9.0, Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.22), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.06)))
			if not list.is_empty():
				n.stripes[k] = list


## CSS repeating-linear-gradient(각도, A 0 a, B a period) 를 모양 안의 띠 다각형들로
static func _stripes(shape: PackedVector2Array, deg: float, a: float, period: float, ca: Color, cb: Color) -> Array:
	var rad := deg_to_rad(deg)
	var d := Vector2(sin(rad), -cos(rad))   # 그라디언트 진행 방향
	var n := Vector2(-d.y, d.x)
	var c := Vector2.ZERO
	for p: Vector2 in shape:
		c += p
	c /= float(shape.size())
	var smin := INF
	var smax := -INF
	for p2: Vector2 in shape:
		var s := (p2 - c).dot(d)
		smin = minf(smin, s)
		smax = maxf(smax, s)
	var out: Array = []
	var s0 := floorf(smin / period) * period
	var big := 200.0
	while s0 < smax:
		for band: Array in [[s0, s0 + a, ca], [s0 + a, s0 + period, cb]]:
			var p0: Vector2 = c + d * float(band[0])
			var p1: Vector2 = c + d * float(band[1])
			var quad := PackedVector2Array([p0 - n * big, p1 - n * big, p1 + n * big, p0 + n * big])
			for poly: PackedVector2Array in Geometry2D.intersect_polygons(quad, shape):
				out.append([poly, band[2]])
		s0 += period
	return out


## 대각선 하나의 하이라이트 그리기 (웹 .iso-tile-hl 클래스들)
func _draw_hl_diag(n: HlDiag) -> void:
	var tm := _t
	for c: Dictionary in n.cells:
		var k: String = c["key"]
		var shape: PackedVector2Array = c["shape"]
		var inset: PackedVector2Array = c["inset"]
		var dark := fog_on and not fog_vis.has(k)
		var kind := str(hl.get(k, ""))
		if dark:
			n.draw_colored_polygon(shape, Color(10 / 255.0, 14 / 255.0, 26 / 255.0, 0.55))
		elif kind != "":
			match kind:
				"move":
					var ph := 0.5 - 0.5 * cos(tm / 1.4 * TAU)
					n.draw_colored_polygon(shape, Color(move_color, lerpf(0.10, 0.25, ph)))
					n.draw_polyline(inset, Color(move_color, lerpf(0.40, 0.80, ph)), 2.0, true)
				"attack", "skill":
					var ph2 := 0.5 - 0.5 * cos(tm / 1.2 * TAU)
					n.draw_colored_polygon(shape, Color(239 / 255.0, 68 / 255.0, 68 / 255.0, lerpf(0.18, 0.40, ph2)))
					n.draw_polyline(inset, Color(239 / 255.0, 68 / 255.0, 68 / 255.0, lerpf(0.6, 1.0, ph2)), 2.0, true)
				"heal":
					var ph3 := 0.5 - 0.5 * cos(tm / 1.2 * TAU)
					n.draw_colored_polygon(shape, Color(34 / 255.0, 197 / 255.0, 94 / 255.0, lerpf(0.18, 0.40, ph3)))
					n.draw_polyline(inset, Color(34 / 255.0, 197 / 255.0, 94 / 255.0, lerpf(0.6, 1.0, ph3)), 2.0, true)
				"selected":
					var op := lerpf(1.0, 0.45, 0.5 - 0.5 * cos(tm / 1.2 * TAU))
					n.draw_colored_polygon(shape, Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.15 * op))
					n.draw_polyline(inset, Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.9 * op), 2.0, true)
				"vault":
					n.draw_polyline(inset, Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.8), 2.0, true)
				"block":
					n.draw_polyline(inset, Color(96 / 255.0, 165 / 255.0, 250 / 255.0, 0.85), 2.0, true)
				"cover":
					n.draw_polyline(inset, Color(148 / 255.0, 163 / 255.0, 184 / 255.0, 0.6), 2.0, true)
		if n.stripes.has(k):
			for s: Array in n.stripes[k]:
				# 안개 칸에서는 위협 줄무늬만 (웹: fow-dark 가 하이라이트 배경을 덮지만 ::after 위협은 남음)
				if dark and not threat.has(k):
					continue
				n.draw_colored_polygon(s[0], s[1])
		if safe.has(k):
			_draw_safe(n, c["o"] + Vector2(TW, TH), 0.75 + 0.25 * (0.5 - 0.5 * cos(tm / 2.4 * TAU)), c)


## 냉기 결계 (웹 .safe-zone::before: 하늘색 고리 + 가운데 빛) — 모양은 칸마다 한 번, 색은 밝기 16단계로 한 번씩 만들어 둠 (매 프레임 새 배열 없음)
static var _safe_cols: Dictionary = {}   # 단계 → PackedColorArray
static var _safe_idx: PackedInt32Array = PackedInt32Array()
const SAFE_SEG := 28
const SAFE_RINGS := [[44.0, 22.0, [0.58, 0.72, 0.82]], [30.0, 15.0, [0.0, 0.7, 1.0]]]


static func _draw_safe(ci: CanvasItem, ctr: Vector2, op: float, cell: Dictionary = {}) -> void:
	var pts: PackedVector2Array
	if cell.has("safe_pts"):
		pts = cell["safe_pts"]
	else:
		pts = _safe_points(ctr)
		if not cell.is_empty():
			cell["safe_pts"] = pts
	if _safe_idx.is_empty():
		for ring in 2:
			var base := ring * 3 * SAFE_SEG
			for ri2 in 2:
				for i2 in SAFE_SEG:
					var a0 := base + ri2 * SAFE_SEG + i2
					var a1 := base + ri2 * SAFE_SEG + (i2 + 1) % SAFE_SEG
					var b0 := base + (ri2 + 1) * SAFE_SEG + i2
					var b1 := base + (ri2 + 1) * SAFE_SEG + (i2 + 1) % SAFE_SEG
					_safe_idx.append_array([a0, b0, b1, a0, b1, a1])
	var lv := clampi(int(round((op - 0.75) / 0.25 * 15.0)), 0, 15)
	if not _safe_cols.has(lv):
		var o := 0.75 + 0.25 * float(lv) / 15.0
		var cols := PackedColorArray()
		var ring_cols := [[Color(125 / 255.0, 211 / 255.0, 252 / 255.0, 0.0), Color(125 / 255.0, 211 / 255.0, 252 / 255.0, 0.6 * o), Color(125 / 255.0, 211 / 255.0, 252 / 255.0, 0.0)],
			[Color(186 / 255.0, 230 / 255.0, 253 / 255.0, 0.4 * o), Color(56 / 255.0, 189 / 255.0, 248 / 255.0, 0.12 * o), Color(56 / 255.0, 189 / 255.0, 248 / 255.0, 0.0)]]
		for ring2 in 2:
			for ri3 in 3:
				for i3 in SAFE_SEG:
					cols.append(ring_cols[ring2][ri3])
		_safe_cols[lv] = cols
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _safe_idx, pts, _safe_cols[lv])


static func _safe_points(c: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for rg: Array in SAFE_RINGS:
		var fr: Array = rg[2]
		for ri in 3:
			for i in SAFE_SEG:
				var a := TAU * float(i) / float(SAFE_SEG)
				pts.append(c + Vector2(cos(a) * float(rg[0]), sin(a) * float(rg[1])) * float(fr[ri]))
	return pts
