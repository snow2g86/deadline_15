extends "res://scripts/ui/screen_base.gd"
## 크레딧·라이선스 공통 틀 (4b-2) — 웹 credits.html · licenses.html: 윗줄(뒤로 · 제목, 톱니 없음), 가운데 500px 상자 목록(.cr-section · .lic-section), 아래 글
##  아래 탭 없음. 뒤로 = 연 화면(설정) — 웹은 늘 settings.html

const COL_W := 500.0

var scroll: ScrollContainer
var col: VBoxContainer


func has_gear() -> bool:
	return false


func has_bottom_nav() -> bool:
	return false


func go_back() -> void:
	router.call("back")


func _build() -> void:
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	var mw := OKit.MaxWidth.new()
	mw.max_w = COL_W
	mw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(mw)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 40)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mw.add_child(m)
	col = OKit.vbox(16)
	col.name = "Col"
	m.add_child(col)


func _refresh() -> void:
	for ch: Node in col.get_children():
		col.remove_child(ch)
		ch.queue_free()
	fill()


func fill() -> void:
	pass


## 웹 .cr-section / .lic-section
func section(nm: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.name = nm
	p.add_theme_stylebox_override("panel", OKit.box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.08), 10, 1, 16, 14))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := OKit.vbox(6)
	p.add_child(v)
	col.add_child(p)
	return v


func wrap_label(text: String, size: int, c2: Color, w: int = 500) -> Label:
	var l := OKit.label(size, c2, w)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(COL_W - 40.0, 0)
	return l


func footer(text: String) -> void:
	var l := OKit.label(11, Color(1, 1, 1, 0.3), 500)
	l.name = "Footer"
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
