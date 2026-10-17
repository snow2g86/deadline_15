extends "res://scripts/ui/codex_screen.gd"
## 도감 — 웹 compendium.html (4b-2). 탭 4개(직업 · 장비 · 소모품·재료 · 스테이지) + 검색(이름·효과)
##  직업 타일을 누르면 상세 창(능력치 막대 · 레벨당 성장 · 스킬 · 습득 스킬 · 조합 버프 · 장비 · 전설 무기 · 직업 세트) — 웹 아래에서 올라오는 창 대신 가운데 창
##  장비 탭은 거르기 8개(전체 · 무기 · 보조 · 방어구 · 장신구 · 전설 · 직업 세트 · 등급·강화). 다른 화면에서 {tab: "gear"} 로 들어올 수 있음 (웹 ?tab=)
##  내용은 scripts/logic/codex_rules.gd (웹과 같은 글 — tests/check_outer_4b2.gd 가 웹 HTML 글 조각과 비교)

var gear_filter := "all"
var sheet: Control
var sheet_cls := ""


func page_id() -> String:
	return "compendium"


func title_text() -> String:
	return rules.tt("nav.compendium", rules.T("c.title")) if rules != null else ""


func emblem() -> String:
	return "📖"


func hero_title() -> String:
	return rules.T("c.title")


func hero_sub() -> String:
	return rules.T("c.sub")


func hero_stats() -> Array:
	return rules.comp_hero_stats()


func tabs() -> Array:
	return CodexRules.COMP_TABS


func tab_text(k: String) -> String:
	return rules.T("c.tab_" + k)


func has_search() -> bool:
	return true


func search_hint() -> String:
	return rules.T("c.search")


func foot() -> String:
	return rules.T("c.foot")


func panel(k: String) -> Array:
	return rules.comp_panel(k, gear_filter)


func _build() -> void:
	super._build()
	view.on_class = open_class
	view.on_filter = set_filter


func set_filter(f: String) -> void:
	gear_filter = f
	drop_panel("gear")
	render_panel()
	var b: Node = current_panel().find_child("Filter_" + f, true, false)
	if b != null:
		(b as Control).grab_focus.call_deferred()


## 직업 상세 창 (웹 openClass · 시트) — ✕ · Esc · 바깥 누르기로 닫힘
func open_class(cls: String) -> void:
	if modal_open():
		return
	sheet_cls = cls
	var v := OKit.vbox(8)
	v.name = "ClassSheet"
	var top := OKit.hbox(0)
	top.add_child(OKit.spacer())
	var cx := OKit.styled_button(OKit.box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.08), 10, 1, 0, 0), OKit.box(Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.08), 10, 1, 0, 0), null, 10)
	cx.name = "CloseX"
	cx.custom_minimum_size = Vector2(32, 32)
	cx.tooltip_text = "Esc"
	var xi := OKit.vec_icon("close", 14, OKit.TEXT)
	xi.position = Vector2(9, 9)
	cx.add_child(xi)
	cx.pressed.connect(close_modal)
	top.add_child(cx)
	v.add_child(top)
	var old_w: float = view.width
	view.width = 560.0
	v.add_child(view.build(rules.comp_class_sheet(cls)))
	view.width = old_w
	var sb := OKit.box(Color("131a30"), Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.28), 20, 1, 40, 22)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 30
	sheet = open_modal(v, {"name": "ClassModal", "width": 640.0, "box": sb, "on_close": func() -> void: sheet_cls = ""})
	cx.grab_focus.call_deferred()
