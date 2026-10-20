extends Node2D
## 지금 게임의 한 덩어리 캐릭터 (영상에서 뽑은 동작 시트) — 비교용. 게임의 SpriteDB 를 그대로 써서 같은 크기·같은 자리에 그림
##  anim: idle→시트 idle, move→run, attack→attack(1회), hit→hit(1회)

var sdb: RefCounted
var cls := "knight"
var gender := "m"
var anim := "idle"
var t := 0.0
var frozen := false
var _spr: Sprite2D


## 발밑 그림자 (게임 unit_view 의 .u-shadow 40x6 과 같은 크기)
func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.15))
	draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.32))


func setup(p_sdb: RefCounted, p_cls: String, p_gender: String) -> void:
	sdb = p_sdb
	cls = p_cls
	gender = p_gender
	_spr = Sprite2D.new()
	_spr.centered = false
	_spr.region_enabled = true
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 게임 unit_view 와 같음
	add_child(_spr)
	_show(0.0)


func play(a: String) -> void:
	anim = a
	t = 0.0
	frozen = false


func show_pose(a: String, time: float) -> void:
	anim = a
	t = time
	frozen = true
	_show(t)


func _kind() -> String:
	match anim:
		"move":
			return "run"
		"attack":
			return "attack"
		"hit":
			return "hit"
	return "idle"


func _process(d: float) -> void:
	if frozen or _spr == null:
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
	var once := kind == "attack" or kind == "hit"
	var fr: int
	if once:
		if time >= dur:
			if kind == "attack" or kind == "hit":
				anim = "idle"
				t = 0.0
				_show(0.0)
				return
		fr = clampi(int(time / dur * n), 0, n - 1)
	else:
		fr = int(fmod(time, dur) / dur * n) % n
	_spr.texture = sdb.call("sheet_tex", s)
	_spr.region_rect = Rect2(fr * float(s["w"]), 0, float(s["w"]), float(s["h"]))
	_spr.position = (pl as Dictionary)["pos"]
	_spr.scale = Vector2.ONE * float((pl as Dictionary)["scale"])
