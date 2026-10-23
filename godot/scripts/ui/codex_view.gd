extends RefCounted
## 도감·가이드 블록 그리기 (4b-2) — scripts/logic/codex_rules.gd 의 블록 → Control. 웹 css/codex.css 의 색·모양
##  글 속 <b> 는 금빛 굵은 글, <br> 는 줄바꿈, <a href="compendium.html?tab=…"> 는 누르면 도감 그 탭 (meta "compendium:탭").
##  글 속 이모지는 그림 (웹 EmojiIcons), 그림이 없는 이모지는 지움. 검색이 걸리는 블록에는 meta "q" (소문자 비교는 화면이).

const OKit := preload("res://scripts/ui/outer_kit.gd")
const Kit := preload("res://scripts/battle/ui_kit.gd")
const ItemView := preload("res://scripts/ui/item_view.gd")

const CARD := Color(1, 1, 1, 0.035)
const CARD2 := Color(1, 1, 1, 0.06)
const LINE := Color(1, 1, 1, 0.08)
const LINE2 := Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.28)
const GOLD2 := Color("ffd76a")
const TEXT2 := Color("a3b1c6")
const BODY := Color("cbd5e1")
const PILL_COLORS := {"": [Color("e2e8f0"), Color(1, 1, 1, 0.05), LINE], "g": [Color("1a1406"), Color("f0c040"), Color(0, 0, 0, 0)],
	"r": [Color("fecaca"), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.14), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.35)],
	"b": [Color("bfdbfe"), Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.14), Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.35)],
	"gr": [Color("bbf7d0"), Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.13), Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.32)],
	"p": [Color("ddd6fe"), Color(167 / 255.0, 139 / 255.0, 250 / 255.0, 0.14), Color(167 / 255.0, 139 / 255.0, 250 / 255.0, 0.35)]}
const ROLE_COLORS := {"melee": [Color("fecaca"), Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.14)], "ranged": [Color("bfdbfe"), Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.14)],
	"healer": [Color("bbf7d0"), Color(34 / 255.0, 197 / 255.0, 94 / 255.0, 0.14)], "support": [Color("fde68a"), Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.14)]}
const RAR_COLORS := {"common": Color("9ca3af"), "uncommon": Color("4ade80"), "rare": Color("60a5fa"), "epic": Color("a78bfa"), "legendary": Color("f0c040")}

var scr: Control
var icons: Object
var D: Dictionary
## 너비 (격자 칸 수 계산) — 화면이 정함
var width := 848.0
## (6a) 모바일: 글자가 커져(최소 12pt) 칸이 넓어지므로 열 수를 정하는 칸 최소 폭을 키움 (PC 1.0 — 그대로)
var min_scale := 1.0
## 직업 타일을 눌렀을 때 (cls) · 글 속 링크를 눌렀을 때 (meta 글)
var on_class: Callable = Callable()
var on_link: Callable = Callable()
var on_filter: Callable = Callable()


func _init(p_scr: Control) -> void:
	scr = p_scr
	icons = p_scr.get("icons")
	D = p_scr.get("D")


# ── 글 ──

static func _bb_escape(s: String) -> String:
	return s.replace("[", "[lb]")


static func _decode(s: String) -> String:
	return s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'").replace("&amp;", "&")


## RichTextLabel 에 웹 글(<b> <br> <a>) 채우기 — 이모지는 그림
func fill(rt: RichTextLabel, html: String, px: int, col: Color) -> void:
	rt.clear()
	rt.push_color(col)
	var re := RegEx.create_from_string("<[^>]*>")
	var pos := 0
	var stack: Array = []
	for m: RegExMatch in re.search_all(html):
		_add_text(rt, _decode(html.substr(pos, m.get_start() - pos)), px)
		pos = m.get_end()
		var tag := m.get_string().to_lower()
		if tag.begins_with("<br"):
			rt.add_text("\n")
		elif tag.begins_with("<b"):
			rt.push_font(Kit.bold(800))
			rt.push_color(GOLD2)
			stack.append(2)
		elif tag.begins_with("<a"):
			var hm := RegEx.create_from_string("tab=([a-z]+)").search(tag)
			rt.push_meta("compendium:" + (hm.get_string(1) if hm != null else ""))
			rt.push_color(OKit.GOLD)
			rt.push_underline()
			stack.append(3)
		elif tag.begins_with("</b") or tag.begins_with("</a"):
			if not stack.is_empty():
				for i in int(stack.pop_back()):
					rt.pop()
	_add_text(rt, _decode(html.substr(pos)), px)
	while not stack.is_empty():
		for i in int(stack.pop_back()):
			rt.pop()
	rt.pop()


func _add_text(rt: RichTextLabel, s: String, px: int) -> void:
	if s == "":
		return
	for p: Variant in icons.call("split", s):
		if typeof(p) == TYPE_STRING:
			rt.add_text(p)
		elif p != null:
			var sz := int(round(px * 1.2))
			rt.add_image(p, sz, sz, Color.WHITE, INLINE_ALIGNMENT_CENTER)


func rich(html: String, px: int, col: Color = BODY, w: int = 500, min_w: float = 0.0) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.name = "Rich"
	rt.bbcode_enabled = false
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.mouse_filter = Control.MOUSE_FILTER_PASS
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.custom_minimum_size = Vector2(min_w, 0)
	rt.add_theme_font_size_override("normal_font_size", px)
	rt.add_theme_font_override("normal_font", Kit.bold(w))
	rt.add_theme_constant_override("line_separation", int(px * 0.45))
	fill(rt, html, px, col)
	rt.meta_clicked.connect(func(meta: Variant) -> void:
		if on_link.is_valid():
			on_link.call(str(meta)))
	return rt


## 글 한 줄 (이모지는 그림) — 길면 줄바꿈되도록 RichText
func text_line(s: String, px: int, col: Color, w: int = 700) -> Control:
	return rich(_bb_escape_html(s), px, col, w)


static func _bb_escape_html(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


func ic_box(ic: Variant, sz: float = 30.0) -> Control:
	if not (ic is Dictionary):
		return null
	if ic.has("cls"):
		var r := OKit.tex_rect(icons.call("image", "icon/jab/%s.png" % str(ic["cls"])), Vector2(sz, sz))
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return r
	if ic.has("item"):
		var it := ItemView.icon(icons, str(ic["item"]), sz - 4.0, str(ic.get("emoji", "")))
		it.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return it
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(sz, sz)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", OKit.box(Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.1), LINE2, 9, 1, 0, 0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(cc)
	if ic.has("emoji"):
		var tex: Texture2D = icons.call("emoji", str(ic["emoji"]))
		if tex != null:
			cc.add_child(OKit.tex_rect(tex, Vector2(sz * 0.6, sz * 0.6)))
		else:
			var l0 := OKit.label(int(sz * 0.5), GOLD2, 900)
			l0.text = icons.call("strip", str(ic["emoji"]))
			cc.add_child(l0)
	elif ic.has("text"):
		var l := OKit.label(int(sz * 0.5), GOLD2, 900)
		l.text = str(ic["text"])
		cc.add_child(l)
	return p


func pill(pd: Dictionary, px: int = 12) -> Control:
	var cols: Array = PILL_COLORS.get(str(pd.get("kind", "")), PILL_COLORS[""])
	var p := PanelContainer.new()
	p.name = "Pill"
	p.add_theme_stylebox_override("panel", OKit.box(cols[1], cols[2], 999, 1, 9, 3))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	if str(pd.get("tip", "")) != "":
		p.tooltip_text = icons.call("strip", str(pd["tip"]))
	var h := OKit.hbox(4)
	p.add_child(h)
	var icn: Variant = pd.get("ic")
	if icn is Dictionary:
		var ib := ic_box(icn, px + 6.0)
		if ib != null:
			h.add_child(ib)
	var txt := str(pd["text"])
	var maxw := width - 60.0
	var font := Kit.bold(700)
	var tw := font.get_string_size(icons.call("strip", txt), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if tw > maxw:
		var rt := rich(_bb_escape_html(txt), px, cols[0], 700, maxw)
		h.add_child(rt)
	else:
		var row: HBoxContainer = scr.call("emoji_row", txt, px, cols[0], 700)
		h.add_child(row)
	return p


func pills_flow(items: Array, px: int = 12) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.name = "Pills"
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pd: Dictionary in items:
		f.add_child(pill(pd, px))
	return f


# ── 블록 ──

func build(blocks: Array) -> VBoxContainer:
	var v := OKit.vbox(10)
	v.name = "Blocks"
	for b: Dictionary in blocks:
		var ctl := block(b)
		if ctl != null:
			v.add_child(ctl)
	return v


func block(b: Dictionary) -> Control:
	match str(b["t"]):
		"sec":
			return _sec(b)
		"lead", "plist":
			return rich(str(b["rich"]), 14 if str(b["t"]) == "lead" else 12, BODY if str(b["t"]) == "lead" else TEXT2)
		"note":
			return _note(b)
		"grid":
			return _grid(b)
		"card":
			return _card(b)
		"table":
			return _table(b)
		"acc":
			return _acc(b)
		"stage":
			return _stage(b)
		"tiles":
			return _tiles(b)
		"person":
			return _person(b)
		"pills":
			return pills_flow(b["items"])
		"subh":
			var l := OKit.label(12, OKit.GOLD, 800)
			l.text = str(b["text"]).to_upper()
			l.name = "SubH"
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(200, 0)
			var m := MarginContainer.new()
			m.add_theme_constant_override("margin_top", 10)
			m.mouse_filter = Control.MOUSE_FILTER_IGNORE
			m.add_child(l)
			return m
		"head":
			return _head(b)
		"bars":
			return _bars(b)
		"skill":
			return _skill(b)
		"filters":
			return _filters(b)
		"empty":
			var e := OKit.label(13, OKit.DIM, 600)
			e.text = str(b["text"])
			e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			e.custom_minimum_size = Vector2(0, 80)
			return e
	return null


func _sec(b: Dictionary) -> Control:
	var v := OKit.vbox(10)
	v.name = "Sec"
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var h := HFlowContainer.new()
	h.name = "SecHead"
	h.add_theme_constant_override("h_separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := OKit.label(18, OKit.TEXT, 900)
	t.text = icons.call("strip", str(b["h"]))
	t.name = "H2"
	h.add_child(t)
	var sm := OKit.label(11, Color(OKit.GOLD, 0.8), 700)
	sm.text = str(b["sm"]).to_upper()
	sm.name = "Small"
	sm.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(sm)
	v.add_child(h)
	for k: Dictionary in b["kids"]:
		var ctl := block(k)
		if ctl != null:
			v.add_child(ctl)
	return v


func _note(b: Dictionary) -> Control:
	var kind := str(b["kind"])
	var bg := Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.08)
	var bd := Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.28)
	if kind == "tip":
		bg = Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.08)
		bd = LINE2
	elif kind == "warn":
		bg = Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.08)
		bd = Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.32)
	var p := PanelContainer.new()
	p.name = "Note"
	p.add_theme_stylebox_override("panel", OKit.box(bg, bd, 12, 1, 14, 12))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := OKit.hbox(10)
	p.add_child(h)
	var e: String = b["ic"]["emoji"]
	var tex: Texture2D = icons.call("emoji", e)
	if tex != null:
		var r := OKit.tex_rect(tex, Vector2(18, 18))
		r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(r)
	elif icons.call("strip", e) != "":
		var l := OKit.label(16, OKit.GOLD, 900)
		l.text = icons.call("strip", e)
		l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(l)
	h.add_child(rich(str(b["rich"]), 13, OKit.TEXT))
	return p


func _cols(kind: int, avail: float) -> int:
	var mins := {2: 250.0, 3: 165.0, 4: 150.0}
	var gap := 8.0 if kind == 3 else 10.0
	return maxi(1, int(floor((avail + gap) / (float(mins.get(kind, 250.0)) * min_scale + gap))))


func _grid(b: Dictionary) -> Control:
	var g := GridContainer.new()
	g.name = "Grid"
	var kind := int(b["cols"])
	g.columns = mini(_cols(kind, width), maxi(1, (b["kids"] as Array).size()))
	var gap := 8 if kind == 3 else 10
	g.add_theme_constant_override("h_separation", gap)
	g.add_theme_constant_override("v_separation", gap)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cw := (width - gap * (g.columns - 1)) / float(g.columns)
	if (b["kids"] as Array).size() < _cols(kind, width):
		cw = (width - gap * (_cols(kind, width) - 1)) / float(_cols(kind, width))
	for k: Dictionary in b["kids"]:
		var ctl := block(k)
		if ctl != null:
			ctl.custom_minimum_size.x = cw
			ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(ctl)
	return g


func _card(b: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.name = "Card"
	var rar := str(b.get("rar", ""))
	var bg := CARD
	if rar == "legendary":
		bg = Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.07)
	var sb := OKit.box(bg, LINE if rar != "legendary" else Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.25), 14, 1, 14, 13)
	if rar != "":
		# 웹 border-left: 3px 등급색 (나머지 테두리는 옅은 선 — StyleBoxFlat 은 테두리 색이 하나라 왼쪽만 그림)
		sb.border_width_left = 3
		sb.border_width_top = 0
		sb.border_width_right = 0
		sb.border_width_bottom = 0
		sb.border_color = RAR_COLORS.get(rar, LINE)
		sb.content_margin_left = 14
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	if str(b.get("q", "")) != "":
		p.set_meta("q", str(b["q"]).to_lower())
	var v := OKit.vbox(7)
	p.add_child(v)
	for part: Dictionary in b["parts"]:
		match str(part["k"]):
			"h":
				var h := OKit.hbox(8)
				h.name = "H3"
				var ib := ic_box(part["ic"])
				if ib != null:
					h.add_child(ib)
				var tl := rich(_bb_escape_html(str(part["text"])), 15, OKit.TEXT, 800)
				tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				h.add_child(tl)
				v.add_child(h)
			"p":
				v.add_child(rich(str(part["rich"]), 13, BODY))
			"pills":
				v.add_child(pills_flow(part["items"], 12))
			"lines":
				var lv := OKit.vbox(1)
				lv.name = "Lines"
				for ln: Array in part["items"]:
					lv.add_child(rich(_bb_escape_html(str(ln[1])), 12, ItemView.LINE_COLORS.get(str(ln[0]), BODY), 600))
				v.add_child(lv)
			"ul":
				var uv := OKit.vbox(3)
				uv.name = "Ul"
				for li: String in part["items"]:
					var lh := OKit.hbox(6)
					var dot := OKit.label(13, OKit.GOLD, 900)
					dot.text = "•"
					dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
					lh.add_child(dot)
					lh.add_child(rich(li, 13, BODY))
					uv.add_child(lh)
				v.add_child(uv)
			"wear":
				var wf := HFlowContainer.new()
				wf.name = "Wear"
				wf.add_theme_constant_override("h_separation", 2)
				wf.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if str(part["all"]) != "":
					wf.add_child(pill({"text": part["all"], "kind": ""}, 11))
				else:
					var names: Array = part.get("names", [])
					for i in (part["list"] as Array).size():
						var ci: TextureRect = OKit.tex_rect(icons.call("image", "icon/jab/%s.png" % str(part["list"][i])), Vector2(20, 20))
						ci.mouse_filter = Control.MOUSE_FILTER_PASS
						ci.tooltip_text = str(names[i]) if i < names.size() else ""
						wf.add_child(ci)
				v.add_child(wf)
	return p


## 표 (웹 .cx-table): 칸 너비는 글 길이로, 모두 합쳐 너비를 넘으면 긴 칸부터 줄여 줄바꿈
func _table(b: Dictionary) -> Control:
	var head: Array = b["head"]
	var rows: Array = b["rows"]
	var n := head.size()
	var font := Kit.bold(600)
	var avail := width - 2.0
	var wid: Array = []
	for i in n:
		var w := font.get_string_size(str(head[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 22.0
		for r: Array in rows:
			if i < r.size():
				var s: String = icons.call("strip", CodexStrip.strip_tags(str(r[i]["rich"])))
				var lines := s.split("\n")
				for ln: String in lines:
					w = maxf(w, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 22.0 + (22.0 if r[i].has("cls") else 0.0))
		wid.append(minf(w, 420.0))
	var tot := 0.0
	for w2: float in wid:
		tot += w2
	while tot > avail:
		var mi := 0
		for i2 in n:
			if wid[i2] > wid[mi]:
				mi = i2
		var cut := minf(tot - avail, float(wid[mi]) - 90.0)
		if cut <= 0.0:
			break
		wid[mi] = float(wid[mi]) - cut
		tot -= cut
	if tot < avail:
		var extra := (avail - tot) / float(n)
		for i3 in n:
			wid[i3] = float(wid[i3]) + extra
	var p := PanelContainer.new()
	p.name = "Table"
	p.add_theme_stylebox_override("panel", OKit.box(CARD, LINE, 12, 1, 0, 0))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var g := GridContainer.new()
	g.columns = n
	g.add_theme_constant_override("h_separation", 0)
	g.add_theme_constant_override("v_separation", 0)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(g)
	for i4 in n:
		var hc := PanelContainer.new()
		var hsb := OKit.box(Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.07), Color(0, 0, 0, 0), 0, 0, 10, 9)
		hsb.border_width_bottom = 1
		hsb.border_color = LINE2
		hc.add_theme_stylebox_override("panel", hsb)
		hc.custom_minimum_size = Vector2(wid[i4], 0)
		hc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hl := rich(_bb_escape_html(str(head[i4])), 12, OKit.GOLD, 800)
		hc.add_child(hl)
		g.add_child(hc)
	for ri in rows.size():
		var r2: Array = rows[ri]
		for i5 in n:
			var cd: Dictionary = r2[i5] if i5 < r2.size() else {"rich": ""}
			var cc := PanelContainer.new()
			var csb := OKit.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 10, 8)
			if ri < rows.size() - 1:
				csb.border_width_bottom = 1
				csb.border_color = LINE
			cc.add_theme_stylebox_override("panel", csb)
			cc.custom_minimum_size = Vector2(wid[i5], 0)
			cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var col := OKit.TEXT if (i5 == 0 or bool(cd.get("n", false))) else BODY
			if cd.has("color"):
				col = Color(str(cd["color"]))
			var ch := OKit.hbox(6)
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if cd.has("cls"):
				var ci := OKit.tex_rect(icons.call("image", "icon/jab/%s.png" % str(cd["cls"])), Vector2(18, 18))
				ci.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				ch.add_child(ci)
			var rt := rich(str(cd["rich"]), 13, col, 700 if (i5 == 0 or bool(cd.get("n", false))) else 500)
			if bool(cd.get("n", false)):
				rt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			ch.add_child(rt)
			cc.add_child(ch)
			g.add_child(cc)
	return p


func _acc(b: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.name = "Acc"
	p.add_theme_stylebox_override("panel", OKit.box(CARD, LINE, 14, 1, 0, 0))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := OKit.vbox(0)
	p.add_child(v)
	var btn := OKit.styled_button(StyleBoxEmpty.new(), OKit.box(Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 0.04), Color(0, 0, 0, 0), 14, 0, 0, 0), null, 14)
	btn.name = "Summary"
	btn.custom_minimum_size = Vector2(0, 52)
	var h := OKit.hbox(10)
	OKit.set_content(btn, h, Vector4(14, 11, 14, 11))
	var ib := ic_box(b["ic"])
	if ib != null:
		h.add_child(ib)
	var tv := OKit.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tt := rich(str(b["h"]), 14, OKit.TEXT, 800)
	tt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(tt)
	if str(b["sub"]) != "":
		var st := rich(str(b["sub"]), 12, TEXT2, 600)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(st)
	h.add_child(tv)
	var chev := OKit.vec_icon("chev_r", 16, OKit.DIM)
	chev.name = "Chev"
	h.add_child(chev)
	v.add_child(btn)
	var body := OKit.vbox(0)
	body.name = "AccBody"
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 12)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(OKit.divider(0.08))
	body.add_child(m)
	var kids := OKit.vbox(0)
	kids.name = "Kids"
	m.add_child(kids)
	for k: Dictionary in b["kids"]:
		var ctl := block(k)
		if ctl != null:
			kids.add_child(ctl)
	v.add_child(body)
	set_open(p, bool(b["open"]))
	btn.pressed.connect(func() -> void: set_open(p, not bool(p.get_meta("open", false))))
	p.set_meta("acc", true)
	return p


func set_open(acc: Control, on: bool) -> void:
	acc.set_meta("open", on)
	var body: Control = acc.find_child("AccBody", true, false)
	body.visible = on
	var chev: Control = acc.find_child("Chev", true, false)
	chev.set("kind", "chev_d" if on else "chev_r")
	chev.set("color", OKit.GOLD if on else OKit.DIM)
	chev.queue_redraw()


func _stage(b: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.name = "Stage"
	var boss := bool(b["boss"])
	var sb := OKit.box(Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.07) if boss else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 10 if boss else 0, 0, 2, 10)
	sb.border_width_top = 1
	sb.border_color = LINE
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.set_meta("q", str(b["q"]).to_lower())
	var h := OKit.hbox(8)
	p.add_child(h)
	var no := OKit.label(12, OKit.RED if boss else OKit.DIM, 900)
	no.text = str(b["no"])
	no.custom_minimum_size = Vector2(30, 0)
	no.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(no)
	var v := OKit.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(rich(_bb_escape_html(str(b["nm"])), 14, Color("fecaca") if boss else OKit.TEXT, 800))
	if str(b["sub"]) != "":
		v.add_child(rich(_bb_escape_html(str(b["sub"])), 12, TEXT2, 500))
	v.add_child(pills_flow(b["tags"], 11))
	return p


func _tiles(b: Dictionary) -> Control:
	var g := GridContainer.new()
	g.name = "Tiles"
	g.columns = _cols(4, width)
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cw := (width - 10.0 * (g.columns - 1)) / float(g.columns)
	for it: Dictionary in b["items"]:
		var bt := OKit.styled_button(OKit.box(CARD, LINE, 13, 1, 0, 0), OKit.box(CARD2, LINE2, 13, 1, 0, 0), null, 13)
		bt.name = "Tile_" + str(it["cls"])
		bt.custom_minimum_size = Vector2(cw, 66)
		bt.set_meta("q", str(it["q"]).to_lower())
		bt.tooltip_text = str(it["name"])
		var h := OKit.hbox(10)
		OKit.set_content(bt, h, Vector4(11, 11, 11, 11))
		var ib := PanelContainer.new()
		ib.add_theme_stylebox_override("panel", OKit.box(Color(0, 0, 0, 0.3), LINE, 11, 1, 0, 0))
		ib.custom_minimum_size = Vector2(44, 44)
		ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ib.add_child(OKit.tex_rect(icons.call("image", "icon/jab/%s.png" % str(it["cls"])), Vector2(44, 44)))
		h.add_child(ib)
		var tv := OKit.vbox(3)
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := OKit.label(14, OKit.TEXT, 800)
		nl.text = str(it["name"])
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.clip_text = true
		nl.custom_minimum_size = Vector2(maxf(40.0, cw - 90.0), 0)
		nl.name = "Name"
		tv.add_child(nl)
		tv.add_child(role_pill(str(it["role"]), str(it["role_text"])))
		h.add_child(tv)
		var cls := str(it["cls"])
		bt.pressed.connect(func() -> void:
			if on_class.is_valid():
				on_class.call(cls))
		g.add_child(bt)
	return g


func role_pill(role: String, text: String) -> Control:
	var cols: Array = ROLE_COLORS.get(role, ROLE_COLORS["melee"])
	var p := OKit.pill(text, 11, cols[0], cols[1])
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p


func _person(b: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.name = "Person"
	p.add_theme_stylebox_override("panel", OKit.box(CARD, LINE, 14, 1, 14, 13))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := OKit.hbox(12)
	p.add_child(h)
	for k: String in b["pics"]:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", OKit.box(Color(1, 1, 1, 0.05), LINE, 12, 1, 0, 0))
		pc.custom_minimum_size = Vector2(64, 72)
		pc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr := OKit.tex_rect(icons.call("image", "character/story/%s.webp" % k), Vector2(64, 72))
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pc.add_child(tr)
		h.add_child(pc)
	var v := OKit.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var hr := OKit.hbox(6)
	if str(b["pill"]) != "":
		var pl := pill({"text": b["pill"], "kind": "r"}, 11)
		pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hr.add_child(pl)
	var hl := rich(str(b["h"]), 15, OKit.TEXT, 800)
	hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(hl)
	v.add_child(hr)
	if str(b["role"]) != "":
		v.add_child(rich(_bb_escape_html(str(b["role"])), 12, GOLD2, 700))
	v.add_child(rich(str(b["p"]), 13, BODY))
	return p


func _head(b: Dictionary) -> Control:
	var h := OKit.hbox(12)
	h.name = "SheetHead"
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", OKit.box(Color(0, 0, 0, 0.3), LINE2, 16, 1, 0, 0))
	pc.custom_minimum_size = Vector2(64, 64)
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(OKit.tex_rect(icons.call("image", "icon/jab/%s.png" % str(b["cls"])), Vector2(64, 64)))
	h.add_child(pc)
	var v := OKit.vbox(5)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := OKit.label(22, GOLD2, 900)
	nl.text = str(b["name"])
	nl.name = "Name"
	v.add_child(nl)
	v.add_child(role_pill(str(b["role"]), str(b["role_text"])))
	if str(b["desc"]) != "":
		v.add_child(rich(_bb_escape_html(str(b["desc"])), 13, TEXT2, 500))
	h.add_child(v)
	return h


func _bars(b: Dictionary) -> Control:
	var g := GridContainer.new()
	g.name = "Bars"
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 6)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := Kit.bold(700)
	var lw := 38.0
	for it: Dictionary in b["items"]:
		lw = maxf(lw, font.get_string_size(str(it["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 4.0)
	for it2: Dictionary in b["items"]:
		var nl := OKit.label(12, TEXT2, 700)
		nl.text = str(it2["name"])
		nl.custom_minimum_size = Vector2(lw, 0)
		g.add_child(nl)
		var bar := Kit.Bar.new()
		bar.custom_minimum_size = Vector2(120, 8)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.track = Color(1, 1, 1, 0.06)
		var col := Color(str(it2["color"]))
		bar.set_value(float(it2["pct"]) / 100.0, col, col.lerp(Color.WHITE, 0.4))
		g.add_child(bar)
		var vl := OKit.label(12, OKit.TEXT, 800)
		vl.text = str(it2["v"])
		vl.custom_minimum_size = Vector2(36, 0)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(vl)
	return g


func _skill(b: Dictionary) -> Control:
	var h := OKit.hbox(10)
	h.name = "Skill"
	var si := OKit.tex_rect(icons.call("skill", str(b["id"]), str(b.get("icon", ""))), Vector2(34, 34))
	si.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(si)
	var v := OKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nr := OKit.hbox(6)
	var nl := rich(_bb_escape_html(str(b["name"])), 13, OKit.TEXT, 800)
	nl.size_flags_horizontal = Control.SIZE_FILL
	nl.fit_content = true
	nl.autowrap_mode = TextServer.AUTOWRAP_OFF
	nr.add_child(nl)
	if str(b["small"]) != "":
		var sl := OKit.label(11, OKit.GOLD, 700)
		sl.text = str(b["small"])
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nr.add_child(sl)
	v.add_child(nr)
	v.add_child(rich(_bb_escape_html(str(b["desc"])), 12, TEXT2, 500))
	h.add_child(v)
	return h


func _filters(b: Dictionary) -> Control:
	var f := HFlowContainer.new()
	f.name = "GearFilters"
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for it: Dictionary in b["items"]:
		var on := bool(it["on"])
		var bt := tab_button(str(it["text"]), on)
		bt.name = "Filter_" + str(it["k"])
		var k := str(it["k"])
		bt.pressed.connect(func() -> void:
			if on_filter.is_valid():
				on_filter.call(k))
		f.add_child(bt)
	return f


## 웹 .cx-tab (알약 모양, 켜지면 금빛)
func tab_button(text: String, on: bool) -> Button:
	var n := OKit.box(Color(240 / 255.0, 192 / 255.0, 64 / 255.0, 1.0) if on else CARD, Color(0, 0, 0, 0) if on else LINE, 999, 1, 13, 8)
	var hv := OKit.box(Color("ffd76a") if on else CARD2, LINE2, 999, 1, 13, 8)
	var b := OKit.styled_button(n, hv, null, 999)
	scr.call("set_button_text", b, text, 14)
	b.add_theme_font_size_override("font_size", 13)
	var fg := Color("1a1406") if on else TEXT2
	for k: String in ["font_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_hover_color", Color("1a1406") if on else OKit.TEXT)
	return b


## 글에서 태그 빼기 (표 칸 너비 재기)
class CodexStrip:
	static func strip_tags(s: String) -> String:
		var re := RegEx.create_from_string("<br\\s*/?>")
		var x := re.sub(s, "\n", true)
		return RegEx.create_from_string("<[^>]*>").sub(x, "", true)
