extends "res://scripts/ui/info_page.gd"
## 크레딧 — 웹 credits.html (4b-2). 글은 웹처럼 영어 그대로 (웹도 번역 키가 없음): SPECIAL THANKS · philgooch (Reddit) · Feedback & Support · 아래 저작권 글


func page_id() -> String:
	return "credits"


func title_text() -> String:
	return "Credits"


func fill() -> void:
	var v := section("SpecialThanks")
	var tl := OKit.label(12, OKit.GOLD, 900)
	tl.text = "SPECIAL THANKS"
	v.add_child(tl)
	var row := OKit.hbox(10)
	row.name = "Person"
	var av := PanelContainer.new()
	av.custom_minimum_size = Vector2(38, 38)
	av.add_theme_stylebox_override("panel", OKit.box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.1), 19, 1, 0, 0))
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var acc := CenterContainer.new()
	acc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_child(acc)
	acc.add_child(OKit.tex_rect(emoji_tex("🤝"), Vector2(20, 20)))
	row.add_child(av)
	var iv := OKit.vbox(2)
	var nr := OKit.hbox(6)
	var nl := OKit.label(15, OKit.TEXT, 700)
	nl.text = "philgooch"
	nr.add_child(nl)
	var tag := OKit.pill("Reddit", 10, Color("ff4500"), Color(1.0, 69 / 255.0, 0, 0.1), Color(1.0, 69 / 255.0, 0, 0.2), 700)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nr.add_child(tag)
	iv.add_child(nr)
	var rl := OKit.label(12, OKit.DIM, 500)
	rl.text = "Feedback & Support"
	iv.add_child(rl)
	row.add_child(iv)
	v.add_child(row)
	footer("DEADLINE 15 © 2026 show4you")
