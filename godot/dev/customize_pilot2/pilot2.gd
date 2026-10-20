extends Node2D
## 캐릭터 외형 커스터마이징 시범 2차 — 개발용 장면 (게임에 연결되지 않음)
##  실행:  Godot --path godot res://dev/customize_pilot2/pilot2.tscn
##  몸 = 지금의 영상 동작 시트 그대로 (knight_02) / 머리 = 다른 캐릭터에서 잘라 온 조각을 기준점 표대로 얹음 / 색·무늬·의상 = 마스크 셰이더
##  옆에 지금 원본, 1차 시범 기사를 놓아 비교 (단추로 켬/끔)
##  키: 1~6 머리, R 랜덤, Space 공격

const Ctx := preload("res://scripts/logic/ctx.gd")
const Iso := preload("res://scripts/battle/iso.gd")
const BattleMap := preload("res://scripts/battle/battle_map.gd")
const SpriteDB := preload("res://scripts/battle/sprite_db.gd")
const Pal := preload("res://dev/customize_pilot2/palettes.gd")
const Char2 := preload("res://dev/customize_pilot2/pilot2_char.gd")
const LegacyChar := preload("res://dev/customize_pilot/legacy_char.gd")
const PilotChar := preload("res://dev/customize_pilot/pilot_char.gd")
const Look1 := preload("res://dev/customize_pilot/look.gd")

const COLS := 11
const ROWS := 11

var D: Dictionary
var iso: Iso
var map: BattleMap
var sdb: SpriteDB
var world: Node2D
var cam: Camera2D
var units: Node2D
var ui: CanvasLayer
var label: Label

var look: Dictionary = Pal.default_look()
var left := false
var anim := "idle"
var show_orig := true
var show_p1 := false
var debug_boxes := false
var rng := RandomNumberGenerator.new()
var zoom_i := 1
const ZOOMS := [1.0, 3.0]
var main_char: Node2D
var extra: Array = []
var look1 := {"v": 1, "h": 2, "f": 1, "o": 0, "t": 0}


func _ready() -> void:
	rng.seed = 20261022
	D = Ctx.globals_from_db(get_node("/root/DataDB"))
	sdb = SpriteDB.new(D)
	iso = Iso.new(COLS, ROWS, D["TI"])
	var ter: Array = []
	for r in ROWS:
		var row: Array = []
		for c in COLS:
			row.append("plain")
		ter.append(row)
	iso.ter = ter
	world = Node2D.new()
	add_child(world)
	map = BattleMap.new()
	map.name = "Map"
	map.setup(iso, D, "plains", sdb, false)
	world.add_child(map)
	map.switch_dir()
	units = Node2D.new()
	world.add_child(units)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	_build_ui()
	rebuild()


var row_r0 := 8


func _cell(i: int, n: int, row: int = 0) -> Vector2i:
	var c0 := maxi(0, 5 - n / 2)
	return Vector2i(c0 + i + 2 * row, row_r0 - i + 2 * row)


func clear_units() -> void:
	for ch in units.get_children():
		units.remove_child(ch)
		ch.queue_free()
	main_char = null
	extra.clear()


## 기본 배치: [내 기사] [지금 원본] [1차 시범] — 한 줄
func rebuild() -> void:
	var items: Array = [{"mine": true, "look": look}]
	if show_orig:
		items.append({"legacy": true})
	if show_p1:
		items.append({"p1": true})
	set_rows([items], true)


## rows: 줄 목록, 줄 = 칸 목록. 칸 spec = {mine, look, anim, t, left, swap, debug} | {legacy} | {p1}
func set_rows(rows: Array, main_row := false) -> void:
	clear_units()
	row_r0 = 10 - 2 * (rows.size() - 1) if rows.size() > 1 else 8
	var first_mid := Vector2.ZERO
	var last_mid := Vector2.ZERO
	for ri in rows.size():
		var items: Array = rows[ri]
		for i in items.size():
			var sp: Dictionary = items[i]
			var cell := _cell(i, items.size(), ri)
			var node: Node2D
			var a := str(sp.get("anim", anim))
			if sp.get("legacy", false):
				node = LegacyChar.new()
				units.add_child(node)
				node.setup(sdb, str(sp.get("cls", "knight")), str(sp.get("gender", "f")))
				a = "idle" if a == "combat" else a
			elif sp.get("p1", false):
				node = PilotChar.new()
				units.add_child(node)
				node.setup("f", Look1.normalize(sp.get("look1", look1)), float(PilotChar.BATTLE_U))
				a = "idle" if a == "combat" else a
				node.face_left = bool(sp.get("left", left))
			else:
				node = Char2.new()
				units.add_child(node)
				node.setup(sdb, sp.get("look", look))
				node.debug_boxes = bool(sp.get("debug", debug_boxes))
				node.swap_enabled = bool(sp.get("swap", true))
				node.set_look(sp.get("look", look))
				if main_row and i == 0 and ri == 0:
					main_char = node
			if sp.has("cap"):
				var lb := Label.new()
				lb.text = str(sp["cap"])
				lb.add_theme_font_size_override("font_size", 16)
				lb.add_theme_color_override("font_color", Color(1, 1, 0.7))
				lb.add_theme_color_override("font_outline_color", Color.BLACK)
				lb.add_theme_constant_override("outline_size", 6)
				lb.scale = Vector2.ONE * 0.4
				lb.position = Vector2(-36, 4)
				lb.z_index = 50
				node.add_child(lb)
			if bool(sp.get("left", left)) and not sp.get("p1", false):
				node.scale.x = -1.0
			node.position = iso.foot(cell.x, cell.y)
			node.z_index = iso.depth(cell.x, cell.y, 2)
			if sp.has("t"):
				node.call("show_pose", a, float(sp["t"]))
			else:
				node.call("play", a)
		var mid := _cell((items.size() - 1) / 2, items.size(), ri)
		var p := iso.foot(mid.x, mid.y)
		if items.size() % 2 == 0:
			p += Vector2(Iso.TW, 0)
		if ri == 0:
			first_mid = p
		last_mid = p
	cam.position = (first_mid + last_mid) / 2.0 + Vector2(0, -26)
	cam.zoom = Vector2.ONE * ZOOMS[zoom_i]


func apply_look(l: Dictionary) -> void:
	look = Pal.normalize(l)
	if main_char != null:
		main_char.call("set_look", look)
	_refresh_label()


func set_key(key: String, v: int) -> void:
	var l := look.duplicate()
	l[key] = v
	apply_look(l)


func do_random() -> void:
	apply_look(Pal.roll(rng))


func set_anim(a: String) -> void:
	anim = a
	for ch in units.get_children():
		ch.call("play", "idle" if (a == "combat" and not (ch is Char2)) else a)
	_refresh_label()


func toggle_left() -> void:
	left = not left
	rebuild()


func toggle_zoom() -> void:
	zoom_i = (zoom_i + 1) % ZOOMS.size()
	cam.zoom = Vector2.ONE * ZOOMS[zoom_i]


func _refresh_label() -> void:
	if label != null:
		label.text = "기사 시범 2차 · %s · %s" % [Pal.describe(look), anim]


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -170
	box.offset_left = 8
	box.offset_right = -8
	box.offset_bottom = -4
	ui.add_child(box)
	label = Label.new()
	label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	box.add_child(label)
	var rows: Array = []
	for i in 4:
		var r := HBoxContainer.new()
		box.add_child(r)
		rows.append(r)
	_btn(rows[0], "랜덤 (R)", do_random)
	for i in Pal.HEADS.size():
		_btn(rows[0], "머리:" + str(Pal.HEADS[i]["name"]), set_key.bind("h", i))
	for i in Pal.COSTUMES.size():
		_btn(rows[1], "의상:" + str(Pal.COSTUMES[i]["name"]), set_key.bind("o", i))
	for i in Pal.PATTERNS.size():
		_btn(rows[1], Pal.PATTERNS[i], set_key.bind("p", i))
	for i in Pal.DECOS.size():
		_btn(rows[1], Pal.DECOS[i]["name"], set_key.bind("d", i))
	for i in Pal.SETS.size():
		_btn(rows[2], "색:" + str(Pal.SETS[i][0]), set_key.bind("c", i))
	for i in Pal.SKINS.size():
		_btn(rows[2], "피부:" + str(Pal.SKINS[i][0]), set_key.bind("k", i))
	for i in Pal.HAIRS.size():
		_btn(rows[3], "머리색:" + str(Pal.HAIRS[i][0]), set_key.bind("r", i))
	for a: Array in [["대기", "idle"], ["전투대기", "combat"], ["이동", "move"], ["공격", "attack"], ["피격", "hit"]]:
		_btn(rows[3], a[0], set_anim.bind(a[1]))
	_btn(rows[3], "원본 비교", func() -> void:
		show_orig = not show_orig
		rebuild())
	_btn(rows[3], "1차 비교", func() -> void:
		show_p1 = not show_p1
		rebuild())
	_btn(rows[3], "기준점 상자", func() -> void:
		debug_boxes = not debug_boxes
		rebuild())
	_btn(rows[3], "좌우", toggle_left)
	_btn(rows[3], "확대", toggle_zoom)
	_refresh_label()


func _btn(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(cb)
	parent.add_child(b)


func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return
	if k.keycode >= KEY_1 and k.keycode <= KEY_9:
		set_key("h", k.keycode - KEY_1)
	elif k.keycode == KEY_R:
		do_random()
	elif k.keycode == KEY_SPACE:
		set_anim("attack")
