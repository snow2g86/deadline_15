extends Node2D
## 시범 2차 기사 — 지금의 영상 동작 시트(몸)를 그대로 쓰고, 머리 조각을 기준점 표대로 얹고, 색·무늬·의상은 마스크 셰이더로 바꿈
##  anim: idle · combat(전투 대기) · move(이동) · attack · hit
const Pal := preload("res://dev/customize_pilot2/palettes.gd")
const KData := preload("res://dev/customize_pilot2/kdata.gd")
const BODY_SHADER := preload("res://dev/customize_pilot2/body.gdshader")
const HEAD_SHADER := preload("res://dev/customize_pilot2/head.gdshader")

var sdb: RefCounted
var cls := "knight"
var gender := "f"            # 시트는 knight_02 (여성 기사: 얼굴이 보이는 투구)
var look: Dictionary = Pal.default_look()
var anim := "idle"
var t := 0.0
var frozen := false
var loop_attack := false
var debug_boxes := false
var swap_enabled := true     # false 면 머리를 바꾸지 않음 (비교용)
var _body: Sprite2D
var _head: Sprite2D
var _deco: Sprite2D
var _dm: ShaderMaterial
var _dbg: Node2D
var _bm: ShaderMaterial
var _hm: ShaderMaterial
var _last_key := ""
var cur_kind := "idle"
var cur_frame := 0


func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.15))
	draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.32))


func setup(p_sdb: RefCounted, l: Dictionary) -> void:
	KData.load_all()
	sdb = p_sdb
	_body = Sprite2D.new()
	_body.centered = false
	_body.region_enabled = true
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bm = ShaderMaterial.new()
	_bm.shader = BODY_SHADER
	_body.material = _bm
	add_child(_body)
	_head = Sprite2D.new()
	_head.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hm = ShaderMaterial.new()
	_hm.shader = HEAD_SHADER
	_head.material = _hm
	add_child(_head)
	_deco = Sprite2D.new()
	_deco.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dm = ShaderMaterial.new()
	_dm.shader = HEAD_SHADER
	_deco.material = _dm
	_head.add_child(_deco)
	_dbg = Node2D.new()
	_dbg.set_script(preload("res://dev/customize_pilot2/dbg_boxes.gd"))
	add_child(_dbg)
	look = Pal.normalize(l)
	_last_key = ""
	_show(0.0)


func set_look(l: Dictionary) -> void:
	look = Pal.normalize(l)
	_last_key = ""
	_show(t)


func play(a: String) -> void:
	anim = a
	t = 0.0
	frozen = false
	_last_key = ""


func show_pose(a: String, time: float) -> void:
	anim = a
	t = time
	frozen = true
	_last_key = ""
	_show(t)


func _kind() -> String:
	match anim:
		"move":
			return "run"
		"attack":
			return "attack"
		"hit":
			return "hit"
		"combat":
			return "combat"
	return "idle"


func _process(d: float) -> void:
	if frozen or _body == null:
		return
	t += d
	_show(t)


func _show(time: float) -> void:
	var kind := _kind()
	var sh: Variant = sdb.call("sheet", cls, gender, kind)
	if typeof(sh) != TYPE_DICTIONARY:
		return
	var s: Dictionary = sh
	var pl: Variant = sdb.call("sheet_place", cls, gender, s)
	if typeof(pl) != TYPE_DICTIONARY:
		return
	var dur := float(s["dur"]) / 1000.0
	var n := int(s["frames"])
	var once := (kind == "attack" or kind == "hit")
	var fr: int
	if once:
		if time >= dur:
			if loop_attack and kind == "attack":
				t = 0.0
				time = 0.0
			else:
				anim = "combat" if kind == "attack" or kind == "hit" else "idle"
				anim = "idle"
				t = 0.0
				_show(0.0)
				return
		fr = clampi(int(time / dur * n), 0, n - 1)
	else:
		fr = int(fmod(time, dur) / dur * n) % n
	_body.texture = sdb.call("sheet_tex", s)
	_body.region_rect = Rect2(fr * float(s["w"]), 0, float(s["w"]), float(s["h"]))
	var P: Dictionary = pl
	_body.position = P["pos"]
	var z := float(P["scale"])
	_body.scale = Vector2.ONE * z
	var key := "%s:%d" % [kind, fr]
	cur_kind = kind
	cur_frame = fr
	if key != _last_key:
		_last_key = key
		_apply_frame(kind, fr, s, z)


func _apply_frame(kind: String, fr: int, s: Dictionary, z: float) -> void:
	var A: Dictionary = KData.anchors["sheets"][kind]
	var ha: Dictionary = A["head"][fr]
	var ta: Dictionary = A["torso"][fr]
	_bm.set_shader_parameter("mask", KData.tex("mask_%s.png" % kind))
	_bm.set_shader_parameter("frame_origin", Vector2(fr * float(s["w"]), 0.0))
	_bm.set_shader_parameter("torso", Vector3(float(ta["x"]), float(ta["y"]), float(ta["s"])))
	# 팔레트
	var st: Array = Pal.SETS[int(look["c"])]
	var kk: Vector3 = st[4]
	_bm.set_shader_parameter("c_metal", st[1])
	_bm.set_shader_parameter("c_red", st[2])
	_bm.set_shader_parameter("c_leather", st[3])
	var sk: Array = Pal.SKINS[int(look["k"])]
	_bm.set_shader_parameter("c_skin", sk[1])
	_bm.set_shader_parameter("k_str", Vector4(kk.x, kk.y, float(sk[2]), kk.z))
	var ref: Dictionary = KData.parts["class_ref_lum"]
	_bm.set_shader_parameter("ref_lum", Vector4(float(ref["metal"]), float(ref["red"]), float(ref["skin"]), float(ref["leather"])))
	# 무늬
	_bm.set_shader_parameter("pattern", int(look["p"]))
	_bm.set_shader_parameter("pat_a", Color(0.95, 0.8, 0.3) if int(look["c"]) != 1 and int(look["c"]) != 4 else Color(0.2, 0.25, 0.7))
	# 의상
	var co: Dictionary = Pal.COSTUMES[int(look["o"])]
	_bm.set_shader_parameter("cos_on", str(co["id"]) != "")
	if str(co["id"]) != "":
		_bm.set_shader_parameter("cos_tex", KData.tex("cos_%s.png" % str(co["id"])))
		var cm: Dictionary = KData.parts["costumes"][str(co["id"])]
		_bm.set_shader_parameter("cos_size", Vector2(float(cm["w"]), float(cm["h"])))
	# 머리
	var hd: Dictionary = Pal.HEADS[int(look["h"])]
	var active: bool = swap_enabled and str(hd["id"]) != "" and str(ha["vis"]) != "lost"
	_bm.set_shader_parameter("head_swap", active)
	_head.visible = active
	if active:
		var hid := str(hd["id"])
		_head.texture = KData.tex("head_%s.png" % hid)
		_hm.set_shader_parameter("mask", KData.tex("head_%s_m.png" % hid))
		var hair: Array = Pal.HAIRS[int(look["r"])]
		_hm.set_shader_parameter("c_hair", hair[1])
		_hm.set_shader_parameter("k_hair", float(hair[2]))
		_hm.set_shader_parameter("c_skin", sk[1])
		_hm.set_shader_parameter("k_skin", float(sk[2]))
		var hm: Dictionary = KData.parts["heads"][hid]
		_hm.set_shader_parameter("ref_hair", float(hm["hair_lum"]))
		_hm.set_shader_parameter("ref_skin", float(hm["skin_lum"]))
		var hs := float(ha["s"]) * float(hd.get("sc", 1.0))
		var ap := Vector2(float(ha["x"]) + float(hd.get("dx", 0.0)) * float(ha["s"]), float(ha["y"]) + float(hd.get("dy", 0.0)) * float(ha["s"]))
		_head.position = _body.position + ap * z
		_head.scale = Vector2.ONE * z * hs
		_head.rotation = -deg_to_rad(float(ha["r"]))
		# 머리 장식: 머리 조각 위쪽 가장자리에 모자 아랫선이 이마 위에 걸리게 (머리 조각 좌표계의 자식이라 같이 움직임)
		var dc: Dictionary = Pal.DECOS[int(look["d"])]
		_deco.visible = str(dc["id"]) != ""
		if _deco.visible:
			var did := str(dc["id"])
			_deco.texture = KData.tex("hat_%s.png" % did)
			var dmeta: Dictionary = KData.parts["heads"]["hat_" + did]
			_dm.set_shader_parameter("mask", KData.tex("hat_%s_m.png" % did))
			_dm.set_shader_parameter("c_hair", st[2] if int(look["c"]) > 0 else Color(1, 0.85, 0.2))
			_dm.set_shader_parameter("k_hair", 0.95 if int(look["c"]) > 0 else 0.0)
			_dm.set_shader_parameter("ref_hair", float(dmeta["ref_lum"]))
			_dm.set_shader_parameter("k_skin", 0.0)
			var hh := float(hm["h"])
			_deco.position = Vector2(0.0, -hh * 0.5 + float(dmeta["h"]) * 0.5 - 4.0)
	_dbg.call("set_info", debug_boxes, _body.position, z, ha, ta)
