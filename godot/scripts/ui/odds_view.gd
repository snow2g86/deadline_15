extends RefCounted
## 확률 정보 창 (결제층 A) — 상점(장비·소모품 탭)과 편성 화면 강화 탭의 '확률 정보' 단추가 연다.
##  표·숫자는 scripts/logic/odds_rules.gd sections() 그대로 (데이터에서 계산 — 손으로 적은 숫자 없음). 모양은 기존 창(open_modal)·글자 크기를 따름.

const OKit := preload("res://scripts/ui/outer_kit.gd")
const OddsRules := preload("res://scripts/logic/odds_rules.gd")

const W := 640.0


## 창 내용 (시험이 이름으로 찾음: OddsBody > Sec_<id> > Grid_<id> 의 Label 글 = sections() 의 글)
static func build(scr: Control) -> Control:
	var tw := func(k: String, p: Dictionary) -> String: return scr.t(k, p)
	var v := OKit.vbox(16)
	v.name = "OddsBody"
	v.custom_minimum_size = Vector2(W, 0)
	var src := OKit.label(11, OKit.DIM, 600)
	src.text = scr.t("gd.odds.source")
	src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	src.custom_minimum_size = Vector2(W, 0)
	v.add_child(src)
	for sec: Dictionary in OddsRules.sections(scr.c, tw):
		var box := PanelContainer.new()
		box.name = "Sec_" + str(sec["id"])
		box.add_theme_stylebox_override("panel", OKit.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08), 10, 1, 14, 12))
		var sv := OKit.vbox(8)
		box.add_child(sv)
		var tl := OKit.label(15, OKit.GOLD, 900)
		tl.name = "Title"
		tl.text = str(sec["title"])
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size = Vector2(W - 28.0, 0)
		sv.add_child(tl)
		var head: Array = sec["head"]
		var g := GridContainer.new()
		g.name = "Grid_" + str(sec["id"])
		g.columns = head.size()
		g.add_theme_constant_override("h_separation", 10)
		g.add_theme_constant_override("v_separation", 4)
		var colw := (W - 28.0 - 10.0 * float(head.size() - 1)) / float(head.size())
		for h: Variant in head:
			g.add_child(_cell(str(h), 11, OKit.DIM2, 800, colw))
		for row: Array in sec["rows"]:
			for i in row.size():
				g.add_child(_cell(str(row[i]), 12, OKit.TEXT if i > 0 else Color.WHITE, 700 if i > 0 else 800, colw))
		sv.add_child(g)
		for n: Variant in sec["notes"]:
			var nl := OKit.label(10, OKit.DIM, 500)
			nl.text = "· " + str(n)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.custom_minimum_size = Vector2(W - 28.0, 0)
			sv.add_child(nl)
		v.add_child(box)
	return v


static func _cell(text: String, size: int, col: Color, w: int, width: float) -> Label:
	var l := OKit.label(size, col, w)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


static func open(scr: Control) -> Control:
	return scr.open_modal(build(scr), {"name": "OddsModal", "title": scr.t("gd.odds.title"), "title_size": 22, "width": W + 88.0,
		"buttons": [{"text": scr.t("common.close"), "name": "Ok"}]})
