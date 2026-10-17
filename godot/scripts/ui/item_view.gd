extends RefCounted
## 아이템 그림·장비 카드 부품 (4b-1) — 웹 js/common/item-icons.js itemIcon(등급 테두리 + 안쪽 그림) · emoji-icons.js equipIcon ·
##  css/common.css .gear-line.gl-* (옵션 줄 색) · .eq-rar-* (등급 광채). 상점과 편성 화면이 같이 씀.

const OKit := preload("res://scripts/ui/outer_kit.gd")
const Kit := preload("res://scripts/battle/ui_kit.gd")

## 옵션 줄 색 (웹 .gear-line.gl-*)
const LINE_COLORS := {"sub": Color("cbd5e1"), "copt": Color("60a5fa"), "off": Color("6b7280"), "fx": Color("c4b5fd"),
	"legend": Color("f0c040"), "eopt": Color("fbbf24"), "set": Color("34d399")}


## itemIcon(key, size, 대체, 등급): 등급 테두리(없으면 어두운 바탕) + 안쪽 78% 그림. 그림이 없으면 대체 이모지의 그림
static func icon(icons: Object, key: String, size: float, fallback_emoji: String = "", rarity: String = "") -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(size, size)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = icons.call("item", key)
	if tex == null:
		var t2: Texture2D = icons.call("emoji", fallback_emoji) if fallback_emoji != "" else null
		var r2 := OKit.tex_rect(t2, Vector2(size, size))
		r2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(r2)
		return root
	var is_fx := key.begins_with("e_") or key.begins_with("frame_")
	var frame: Texture2D = null if is_fx else icons.call("rarity_frame", key, rarity)
	if not is_fx:
		if frame != null:
			var fr := OKit.tex_rect(frame, Vector2(size, size))
			fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			root.add_child(fr)
		else:
			var bg := Panel.new()
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg.add_theme_stylebox_override("panel", OKit.box(Color("2a2f3a"), Color(1, 1, 1, 0.08), int(roundf(size * 0.14)), 1, 0, 0))
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			root.add_child(bg)
	var inner := size * (0.78 if frame != null else (1.0 if is_fx else 0.88))
	var r := OKit.tex_rect(tex, Vector2(inner, inner))
	r.position = Vector2((size - inner) * 0.5, (size - inner) * 0.5)
	r.size = Vector2(inner, inner)
	root.add_child(r)
	return root


## equipIcon: 전설은 legend_<id> 그림, 아니면 틀 그림, 등급 테두리
static func equip_icon(icons: Object, D: Dictionary, it: Dictionary, size: float) -> Control:
	var tid := str(it.get("templateId", ""))
	var key := tid
	var leg: Variant = it.get("legend")
	if leg != null and str(leg) != "" and icons.call("item", "legend_" + str(leg)) != null:
		key = "legend_" + str(leg)
	var emo := str((D.get("EQUIP_EMOJI", {}) as Dictionary).get(tid, "📦"))
	var rar := "legendary" if (leg != null and str(leg) != "") else str(it.get("rarity", "common"))
	return icon(icons, key, size, emo, rar)


## 옵션 줄들 (EquipRules.lines 결과) → 글 묶음. w: 줄바꿈 폭
static func lines_box(lines: Array, w: float, size: int = 10) -> VBoxContainer:
	var v := OKit.vbox(1)
	v.name = "Lines"
	for l: Dictionary in lines:
		var lb := OKit.label(size, LINE_COLORS.get(str(l["c"]), Color("cbd5e1")), 800 if l["c"] == "legend" else 600)
		lb.text = str(l["text"])
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.custom_minimum_size = Vector2(w, 0)
		if l["c"] == "off":
			lb.modulate.a = 0.7
		v.add_child(lb)
	return v


## 등급 색 (RARITY[r].color)
static func rarity_color(D: Dictionary, r: Variant) -> Color:
	var d: Variant = (D.get("RARITY", {}) as Dictionary).get(r)
	return Color(str(d["color"])) if d is Dictionary else Color("9ca3af")
