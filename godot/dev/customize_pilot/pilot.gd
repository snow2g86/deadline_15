extends Node2D
## 캐릭터 외형 커스터마이징 시범 — 개발용 장면 (게임에 연결되지 않음)
##  실행:  Godot --path godot res://dev/customize_pilot/pilot.tscn
##  전투 지도(BattleMap) 위에 조각 뼈대 기사를 세우고, 같은 직업의 지금 캐릭터(한 덩어리 그림)를 옆에 놓아 비교
##  단추: 랜덤 외형 / 머리·옷·표정·피부 고르기 / 앞·뒤 / 좌우 / 동작 / 확대
##  키: 1~3 머리, Q W E 옷, R 랜덤, Space 공격, Tab 앞뒤

const Ctx := preload("res://scripts/logic/ctx.gd")
const Iso := preload("res://scripts/battle/iso.gd")
const BattleMap := preload("res://scripts/battle/battle_map.gd")
const SpriteDB := preload("res://scripts/battle/sprite_db.gd")
const Look := preload("res://dev/customize_pilot/look.gd")
const PilotChar := preload("res://dev/customize_pilot/pilot_char.gd")
const LegacyChar := preload("res://dev/customize_pilot/legacy_char.gd")

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

var look: Dictionary = Look.default_look()
var view := "f"
var left := false
var anim := "idle"
var compare := true
var rng := RandomNumberGenerator.new()
var zoom_i := 1
const ZOOMS := [1.0, 3.0]

var main_char: Node2D
var legacy: Node2D


func _ready() -> void:
	rng.seed = 20261021
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
	world.name = "World"
	add_child(world)
	map = BattleMap.new()
	map.name = "Map"
	map.setup(iso, D, "plains", sdb, false)
	world.add_child(map)
	map.switch_dir()
	units = Node2D.new()
	units.name = "Units"
	world.add_child(units)
	cam = Camera2D.new()
	cam.name = "Cam"
	add_child(cam)
	cam.make_current()
	_build_ui()
	set_rows([[{"look": look, "view": view}]], true)


# ═══════════ 자리 놓기 ═══════════

var row_r0 := 8


## i 번째(왼쪽부터) 자리 — 화면에서 수평으로 이웃한 칸 = (c+1, r-1). 줄이 여럿이면 두 칸(+2,+2)씩 아래로
func _cell(i: int, n: int, row: int = 0) -> Vector2i:
	var c0 := maxi(0, 5 - n / 2)
	return Vector2i(c0 + i + 2 * row, row_r0 - i + 2 * row)


func clear_units() -> void:
	for ch in units.get_children():
		ch.queue_free()
		units.remove_child(ch)
	main_char = null
	legacy = null


## rows: 줄 목록, 줄 = 칸 목록. 칸 spec = {look, view, left, anim, t(고정 시각, 없으면 재생), u} 또는 {legacy: true, cls, gender, anim, t}
func set_rows(rows: Array, keep_compare := false) -> void:
	clear_units()
	row_r0 = 10 - 2 * (rows.size() - 1)
	var first_mid := Vector2.ZERO
	var last_mid := Vector2.ZERO
	for ri in rows.size():
		var items: Array = (rows[ri] as Array).duplicate()
		if keep_compare and compare and ri == 0:
			items.append({"legacy": true, "view": view, "anim": anim})
		for i in items.size():
			var sp: Dictionary = items[i]
			var cell := _cell(i, items.size(), ri)
			var node: Node2D
			if sp.get("legacy", false):
				node = LegacyChar.new()
				units.add_child(node)
				node.setup(sdb, str(sp.get("cls", "knight")), str(sp.get("gender", "m")))
				if bool(sp.get("left", false)):
					node.scale.x = -1.0
				if ri == 0 and keep_compare:
					legacy = node
			else:
				node = PilotChar.new()
				units.add_child(node)
				node.setup(str(sp.get("view", "f")), sp.get("look", look), float(sp.get("u", PilotChar.BATTLE_U)))
				node.face_left = bool(sp.get("left", false))
				if keep_compare and i == 0 and ri == 0:
					main_char = node
			node.position = iso.foot(cell.x, cell.y)
			node.z_index = iso.depth(cell.x, cell.y, 2)
			var a := str(sp.get("anim", "idle"))
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


func _focus_row(_n: int) -> void:
	pass


func set_zoom(z: float) -> void:
	cam.zoom = Vector2.ONE * z


# ═══════════ 외형·동작 조작 ═══════════

func apply_look(l: Dictionary) -> void:
	look = Look.normalize(l)
	if main_char != null:
		main_char.call("set_look", look)
	_refresh_label()


func set_key(key: String, v: int) -> void:
	apply_look(Look.with_key(look, key, v))


func do_random() -> void:
	apply_look(Look.roll(rng))


func set_anim(a: String) -> void:
	anim = a
	if main_char != null:
		main_char.call("play", a)
	if legacy != null:
		legacy.call("play", a)
	_refresh_label()


func set_view(v: String) -> void:
	view = v
	if main_char != null:
		main_char.call("set_view", v)
	_refresh_label()


func toggle_left() -> void:
	left = not left
	if main_char != null:
		main_char.face_left = left
	if legacy != null:
		legacy.scale.x = -1.0 if left else 1.0


func toggle_compare() -> void:
	compare = not compare
	set_rows([[{"look": look, "view": view, "left": left, "anim": anim}]], true)


func toggle_zoom() -> void:
	zoom_i = (zoom_i + 1) % ZOOMS.size()
	cam.zoom = Vector2.ONE * ZOOMS[zoom_i]


func _refresh_label() -> void:
	if label != null:
		label.text = "기사 시범 · %s · %s · %s · 조각 %d개" % [Look.describe(look), "앞" if view == "f" else "뒤", anim, int(main_char.get("parts_count")) if main_char != null else 0]


# ═══════════ 화면 단추 ═══════════

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -104
	box.offset_left = 8
	box.offset_right = -8
	box.offset_bottom = -4
	ui.add_child(box)
	label = Label.new()
	label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	box.add_child(label)
	var r1 := HBoxContainer.new()
	var r2 := HBoxContainer.new()
	box.add_child(r1)
	box.add_child(r2)
	_btn(r1, "랜덤 외형 (R)", do_random)
	for i in 3:
		_btn(r1, "머리 %d" % (i + 1), set_key.bind("h", i))
	for i in 3:
		_btn(r1, "옷 %d" % (i + 1), set_key.bind("o", i))
	for i in 2:
		_btn(r1, "얼굴 %d" % (i + 1), set_key.bind("f", i))
	for i in 3:
		_btn(r1, "피부 %d" % (i + 1), set_key.bind("t", i))
	for a: Array in [["대기", "idle"], ["이동", "move"], ["공격", "attack"], ["피격", "hit"]]:
		_btn(r2, a[0], set_anim.bind(a[1]))
	_btn(r2, "앞", set_view.bind("f"))
	_btn(r2, "뒤", set_view.bind("b"))
	_btn(r2, "좌우 뒤집기", toggle_left)
	_btn(r2, "지금 캐릭터 비교", toggle_compare)
	_btn(r2, "확대 ×1/×3", toggle_zoom)
	_btn(r2, "공격 반복", func() -> void:
		if main_char != null:
			main_char.set("loop_attack", not bool(main_char.get("loop_attack")))
			set_anim("attack"))
	_refresh_label()


func _btn(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)


func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return
	match k.keycode:
		KEY_1, KEY_2, KEY_3:
			set_key("h", k.keycode - KEY_1)
		KEY_Q:
			set_key("o", 0)
		KEY_W:
			set_key("o", 1)
		KEY_E:
			set_key("o", 2)
		KEY_R:
			do_random()
		KEY_SPACE:
			set_anim("attack")
		KEY_TAB:
			set_view("b" if view == "f" else "f")
