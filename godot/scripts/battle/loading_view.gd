extends Control
## 로딩 화면 — 웹 #battle-loading (boot.js): 스테이지 이름 · 금빛 진행 막대 · 팁 한 줄 (battle.loading_tips 중 하나, 화면 난수 — 엔진 난수와 무관)
##  장면이 progress(0~1) 를 올리고 finish() 로 0.4초 흐려지며 사라짐

const Kit := preload("res://scripts/battle/ui_kit.gd")

signal finished

var title: Label
var bar: Kit.Bar
var tip: Label
var _done := false


func setup() -> void:
	name = "Loading"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("0a0e1a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(340, 0)
	v.add_theme_constant_override("separation", 14)
	cc.add_child(v)
	title = Kit.label(18, Kit.GOLD, 900)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	bar = Kit.Bar.new()
	bar.custom_minimum_size = Vector2(340, 6)
	bar.track = Color(1, 1, 1, 0.08)
	v.add_child(bar)
	tip = Kit.label(12, Kit.DIM, 500)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(340, 0)
	v.add_child(tip)


func show_for(stage_name: String, tip_text: String) -> void:
	title.text = stage_name
	tip.text = tip_text
	progress(0.0)
	modulate.a = 1.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_done = false


func progress(f: float) -> void:
	bar.set_value(f, Kit.GOLD_D, Kit.GOLD)


func finish(instant: bool = false) -> void:
	if _done:
		return
	_done = true
	progress(1.0)
	# (4b-1) 흐려지는 0.4초 동안 누르기를 막지 않음 — 그 사이 전투는 이미 시작되어 행동 메뉴가 뜰 수 있는데,
	#  보이는 채로 STOP 이면 맵 칸 누르기를 먹어 '대상 고르기'에서 멈춘 것처럼 보였음 (tests/play_4a.gd 멈춤의 원인)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if instant:
		visible = false
		finished.emit()
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		visible = false
		finished.emit())
