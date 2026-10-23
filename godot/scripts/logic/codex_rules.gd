extends RefCounted
## 도감·가이드 내용 (4b-2) — 웹 compendium.html · guide.html 의 <script> (모든 표·카드를 게임 데이터에서 만듦)
##  화면 코드 없이 '블록' 사전 목록을 만든다. 화면(scripts/ui/codex_view.gd)이 그리고, 시험(tests/check_outer_4b2.gd)이
##  tokens() 로 글 조각을 뽑아 웹 정답(node 로 웹 HTML 을 만들어 태그를 걷어낸 글 조각, tools/legacy-web/outer-4b2-expect.js)과 순서까지 비교한다.
##
##  번역: t(k, p) 와 has(k) 를 받는다. 웹 tt(k, 대체) 는 t 가 키를 그대로 돌려주면(없는 키) 대체를 쓰는데, 여기서는 **있는 키만 조회**하고
##   없으면 바로 대체 (웹에서 gear.item.* 21개·maps.* 8개가 '없는 키 조회'로 키를 돌려받던 것 — 화면 글은 같음). 시험이 '없는 키 조회 0' 을 확인.
##   (maps.* 는 어느 언어 팩에도 없는 키라 웹도 늘 대체(mapType id)를 씀 — 검색 글에만 쓰임)
##
##  블록 (모두 사전, "t" 가 종류):
##   sec{h, sm, kids}        구역 (웹 .cx-sec: 제목 + 작은 영문)       lead{rich}        설명 문단 (.cx-lead)
##   note{kind, ic, rich}    안내 상자 (.cx-note tip·warn)            grid{cols, kids}  카드 격자 (.cx-grid2 = 2, .cx-grid-gear = 3, .cx-grid = 4)
##   card{parts, q, rar, cls_id}  카드 (.cx-card) — parts 는 차례대로 {k:"h", ic, text} · {k:"p", rich} · {k:"pills", items} · {k:"lines", items:[[색, 글]]} ·
##                           {k:"ul", items:[rich]} · {k:"wear", all|list}
##   table{head, rows, nw}   표 — 칸은 {rich, n(숫자 칸), color, cls(직업 아이콘)}
##   acc{ic, h, sub, open, kids}  접고 펴기 (<details>)                stage{no, nm, sub, tags, boss, q}  스테이지 줄
##   tiles{items:[{cls, name, role, role_text, q}]}  직업 타일          person{pics, h, pill, role, p}  인물 카드
##   subh{text} · head{cls, name, role, role_text, desc} · bars{items:[{k, name, v, pct, color}]} · skill{id, name, small, desc} · pills{items} · plist{items}
##  아이콘(ic): {emoji} (글 조각) · {text} (글 조각) · {item, emoji} · {cls} · {skill} (그림 — 웹 시험에서는 빈 글)
##  pill: {text, kind("" g r b p gr), ic, tip}

const Js := preload("res://scripts/logic/js.gd")
const Num := preload("res://scripts/core/num.gd")
const EquipRules := preload("res://scripts/logic/equip_rules.gd")
const Gear := preload("res://scripts/logic/gear.gd")
const OddsRules := preload("res://scripts/logic/odds_rules.gd")
const Hazards := preload("res://scripts/logic/hazards.gd")
const StageRules := preload("res://scripts/logic/stage_rules.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")

const PLAYER_CLASSES := ["warrior", "knight", "lancer", "brawler", "assassin", "archer", "mage", "summoner", "shaman", "priest", "sapper", "novice"]
const EXP_POTIONS := [{"id": "exp_s", "icon": "🧪", "exp": 50, "cost": 400}, {"id": "exp_m", "icon": "⚗️", "exp": 150, "cost": 1000}, {"id": "exp_l", "icon": "🏺", "exp": 400, "cost": 2400}]
const GEAR_FILTERS := ["all", "weapon", "offhand", "armor", "acc", "legend", "set", "rule"]
const COMP_TABS := ["cls", "gear", "cons", "stage"]
const GUIDE_TABS := ["start", "grow", "gear", "battle", "map", "route", "story"]
const CAST := ["bram", "sera", "bark", "kasha", "ordin"]
const STAT_COLORS := {"hp": "#22c55e", "atk": "#ef4444", "def": "#3b82f6", "move": "#f0c040", "range": "#a78bfa"}

var c: Object
var D: Dictionary
var _t: Callable
var _has: Callable
## 시험용: 조회한 키 중 없는 키 (있는 키만 조회하므로 늘 비어야 함)
var missing: Array = []


func _init(p_c: Object, p_t: Callable, p_has: Callable) -> void:
	c = p_c
	D = p_c.D
	_t = p_t
	_has = p_has


# ── 번역 ──

func t(k: String, p: Dictionary = {}) -> String:
	if not bool(_has.call(k)):
		missing.append(k)
	return str(_t.call(k, p))


## 웹 tt(k, 대체, p): 있는 키면 그 글(빈 글이면 대체), 없으면 대체(없으면 키)
func tt(k: String, fb: Variant = null, p: Dictionary = {}) -> String:
	if bool(_has.call(k)):
		var v := str(_t.call(k, p))
		if v != "":
			return v
	return str(fb) if fb != null else k


func T(k: String, p: Dictionary = {}) -> String:
	return t("codex." + k, p)


func num(v: Variant) -> String:
	return Num.fmt(v) if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT else str(v)


func _tw() -> Callable:
	return func(k: String, p: Dictionary) -> String: return tt(k, null, p)


func role_of(cls: String) -> String:
	var r: Variant = (D["ROLE_MAP"] as Dictionary).get(cls)
	return str(r) if Js.truthy(r) else "melee"


func role_name(r: String) -> String:
	return T("c.role_support") if r == "support" else tt("roles." + r, r)


func stat_name(k: String) -> String:
	return tt("codex.c.stat_" + k, "codex.c.stat_" + k)


## Gear.name({templateId}) — 있는 키만 (gear.item.* 이 없으면 equip.item.*)
func gear_name_tid(tid: String) -> String:
	var k := "gear.item." + tid
	if bool(_has.call(k)):
		var v := str(_t.call(k, {}))
		if v != "" and v != k:
			return v
	return t("equip.item." + tid)


func gear_fmt(id: String, v: Variant) -> String:
	return EquipRules.fmt(c, id, v, _tw())


func boss_name(st: Dictionary) -> String:
	if not Js.truthy(st.get("boss")):
		return ""
	var k := "stages.boss_%s" % num(st["id"])
	return t(k) if bool(_has.call(k)) else str(st["boss"].get("name", ""))


func synergy_name_mono(cls: String) -> String:
	return t("synergy.mono_" + cls)


func synergy_describe(e: Dictionary) -> String:
	var parts: Array = []
	for k: String in ["atk", "def", "hp", "heal", "frag"]:
		if Js.truthy(e.get(k)) and float(e[k]) != 1.0:
			parts.append(t("synergy.stat_" + k) + " ×" + num(Js.to_fixed_num(float(e[k]), 2)))
	for k2: String in ["move", "range"]:
		if Js.truthy(e.get(k2)):
			parts.append(t("synergy.stat_" + k2) + " " + ("+" if float(e[k2]) > 0.0 else "") + num(e[k2]))
	return " · ".join(parts)


func hazard_describe(h: Dictionary, stage: Variant) -> String:
	var p: Array = []
	if Js.truthy(h.get("dot")):
		p.append(t("hazard.fx_dot", {"n": Js.round_js(Hazards.dot_pct(h, stage) * 100.0)}))
	if Js.truthy(h.get("move")):
		p.append(t("hazard.fx_move", {"n": h["move"]}))
	if Js.truthy(h.get("range")):
		p.append(t("hazard.fx_range", {"n": h["range"]}))
	if Js.truthy(h.get("def")):
		p.append(t("hazard.fx_def", {"n": Js.round_js((1.0 - float(h["def"])) * 100.0)}))
	if Js.truthy(h.get("heal")):
		p.append(t("hazard.fx_heal", {"n": Js.round_js((1.0 - float(h["heal"])) * 100.0)}))
	var ench: Dictionary = D["ENCHANTS"][h["enchant"]]
	var s := " · ".join(p) + " — " + t("hazard.counter", {"e": str(ench["icon"]) + " " + t("enchant." + str(h["enchant"]))})
	if Js.truthy(h.get("safe")):
		s += " · " + t("hazard.safe_zone", {"i": D["SAFE_ZONE"]["icon"], "r": D["SAFE_ZONE"]["every"]})
	return s


func hazard_label(h: Dictionary) -> String:
	return tt("hazard." + str(h["id"]), h["id"])


func rarity_label(r: String) -> String:
	var nm := tt("equip.rarity." + r, r)
	var re := RegEx.create_from_string("^[A-Z] - ")
	return str(D["RARITY"][r]["grade"]) + " " + re.sub(nm, "", false)


# ── 블록 만들기 ──

static func sec(h: String, sm: String, kids: Array) -> Dictionary:
	return {"t": "sec", "h": h, "sm": sm, "kids": kids}


static func lead(rich: String) -> Dictionary:
	return {"t": "lead", "rich": rich}


static func note(kind: String, ic: String, rich: String) -> Dictionary:
	return {"t": "note", "kind": kind, "ic": {"emoji": ic}, "rich": rich}


static func grid(kids: Array, cols: int = 2) -> Dictionary:
	return {"t": "grid", "cols": cols, "kids": kids}


static func card(parts: Array, q: String = "", extra: Dictionary = {}) -> Dictionary:
	var d := {"t": "card", "parts": parts, "q": q}
	d.merge(extra, true)
	return d


static func ph(ic: Variant, text: String) -> Dictionary:
	return {"k": "h", "ic": ic, "text": text}


static func pp(rich: String) -> Dictionary:
	return {"k": "p", "rich": rich}


static func pills(items: Array) -> Dictionary:
	return {"k": "pills", "items": items}


static func pill(text: String, kind: String = "", ic: Variant = null, tip: String = "") -> Dictionary:
	return {"text": text, "kind": kind, "ic": ic, "tip": tip}


static func emo(e: String) -> Dictionary:
	return {"emoji": e}


static func cell(rich: String, n: bool = false, extra: Dictionary = {}) -> Dictionary:
	var d := {"rich": rich, "n": n}
	d.merge(extra, true)
	return d


static func table(head: Array, rows: Array, nw: bool = false) -> Dictionary:
	return {"t": "table", "head": head, "rows": rows, "nw": nw}


# ═══════════ 도감 (compendium.html) ═══════════

func comp_hero_stats() -> Array:
	return [[PLAYER_CLASSES.size(), T("c.st_classes")], [(D["EQUIP_DB"] as Array).size(), T("c.st_gear")], [(D["LEGENDS"] as Dictionary).size(), T("c.st_legend")],
		[(D["STAGES"] as Array).size(), T("c.st_stages")]]


func _skills_of(cls: String) -> Dictionary:
	var sk: Variant = (D["SKILLS"] as Dictionary).get(cls)
	var base: Array = []
	if sk is Array:
		base = (sk as Array).duplicate()
	elif sk != null:
		base = [sk]
	var learn: Array = []
	for v: Variant in (D["LEARNABLE_SKILLS"] as Dictionary).values():
		if Js.same(v.get("cls"), cls):
			learn.append(v)
	return {"base": base, "learn": learn}


func comp_classes() -> Array:
	var tiles: Array = []
	for cls: String in PLAYER_CLASSES:
		var r := role_of(cls)
		var nm := tt("classes." + cls)
		tiles.append({"cls": cls, "name": nm, "role": r, "role_text": role_name(r), "q": nm + " " + cls + " " + role_name(r)})
	var res := {"fury": ["💢", "fury", T("c.res_fury")], "energy": ["⚡", "energy", T("c.res_energy")], "mana": ["🔮", "mana", T("c.res_mana")]}
	var rcards: Array = []
	for k: String in res.keys():
		var who: Array = []
		for cl: String in PLAYER_CLASSES:
			if (D["JAB"] as Dictionary).has(cl) and Js.same(D["JAB"][cl].get("res"), k):
				who.append(tt("classes." + cl))
		rcards.append(card([ph(emo(res[k][0]), tt("resources." + k, res[k][1])), pp(res[k][2]), pills([pill(" · ".join(who))])]))
	return [sec(T("c.s_cls"), "12 classes", [lead(T("c.cls_p")), {"t": "tiles", "items": tiles}]), sec(T("c.s_res"), "resources", [grid(rcards)])]


## 직업 상세 창 (웹 openClass)
func comp_class_sheet(cls: String) -> Array:
	var d: Dictionary = D["JAB"][cls]
	var b: Dictionary = d["base"]
	var g: Dictionary = d["growth"]
	var r := role_of(cls)
	var out: Array = [{"t": "head", "cls": cls, "name": tt("classes." + cls), "role": r, "role_text": role_name(r), "desc": tt("class_desc." + cls, "")}]
	out.append({"t": "subh", "text": T("c.sh_base")})
	var bars: Array = []
	for k: String in ["hp", "atk", "def", "move", "range"]:
		var mx := 0.0
		for pc: String in PLAYER_CLASSES:
			mx = maxf(mx, float(D["JAB"][pc]["base"][k]))
		bars.append({"k": k, "name": stat_name(k), "v": num(b[k]), "pct": Js.round_js(float(b[k]) / mx * 100.0), "color": STAT_COLORS[k]})
	out.append({"t": "bars", "items": bars})
	var gp: Array = [pill(T("c.sh_perlv"), "p")]
	for k2: String in ["hp", "atk", "def"]:
		gp.append(pill("%s +%s~%s" % [stat_name(k2), num(g[k2][0]), num(g[k2][1])]))
	gp.append(pill("%s %s" % [tt("resources." + str(d["res"]), d["res"]), num(d["maxRes"])]))
	gp.append(pill(T("c.sh_speed", {"n": d["actionRec"] if Js.truthy(d.get("actionRec")) else 1})))
	out.append({"t": "pills", "items": gp})
	var sk := _skills_of(cls)
	out.append({"t": "subh", "text": T("c.sh_skills")})
	for s: Dictionary in sk["base"]:
		out.append(_skill_row(s))
	if not (sk["learn"] as Array).is_empty():
		out.append({"t": "subh", "text": T("c.sh_learn")})
		for s2: Dictionary in sk["learn"]:
			out.append(_skill_row(s2))
	var syn: Array = []
	var MONO: Dictionary = D["SYNERGY_MONO"]
	var TRIO: Dictionary = D["SYNERGY_TRIO"]
	if MONO.has(cls):
		syn.append({"t": "pills", "items": [pill(T("c.sh_5"), "g"), pill(synergy_name_mono(cls)), pill(synergy_describe(MONO[cls]["eff"]))]})
	if TRIO.has(cls):
		syn.append({"t": "pills", "items": [pill(T("c.sh_3"), "b"), pill(synergy_describe(TRIO[cls]))]})
	if not syn.is_empty():
		out.append({"t": "subh", "text": T("c.sh_syn")})
		out.append_array(syn)
	out.append({"t": "subh", "text": T("c.sh_gear")})
	var wpn: Variant = Gear.equip_template(c, "wpn_" + cls)
	var armors: Array = []
	for a: String in (D["ARMOR_TYPE"] as Dictionary).keys():
		if (D["ARMOR_TYPE"][a] as Array).has(cls):
			armors.append(tt("gear.armor." + a, a))
	var hand := T("c.two_h") if wpn != null and wpn.get("hand") == "2h" else T("c.one_h")
	out.append({"t": "pills", "items": [pill(gear_name_tid("wpn_" + cls) + " · " + hand, "", {"item": "wpn_" + cls, "emoji": str((D["EQUIP_EMOJI"] as Dictionary).get("wpn_" + cls, ""))}),
		pill(T("c.armors", {"list": " · ".join(armors)}))]})
	var wl := ""
	for k3: String in (D["LEGENDS"] as Dictionary).keys():
		if D["LEGENDS"][k3]["tpl"] == "wpn_" + cls:
			wl = k3
			break
	if wl != "":
		var lines: Array = []
		var fx: Dictionary = D["LEGENDS"][wl]["fx"]
		for k4: String in fx.keys():
			lines.append(["legend", "★ " + gear_fmt(k4, fx[k4])])
		out.append(card([ph({"item": "legend_" + wl, "emoji": "★"}, tt("gear.legend." + wl)), {"k": "lines", "items": lines}], "", {"rar": "legendary", "item": true}))
	var setd: Variant = (D["CLASS_SETS"] as Dictionary).get(cls)
	if setd != null:
		out.append({"t": "subh", "text": T("c.sh_set", {"set": tt("gear.set." + cls)})})
		for n: int in [2, 3]:
			var ps: Array = [pill(T("c.n_set", {"n": n}), "g" if n == 3 else "")]
			var sd: Dictionary = setd[str(n)]
			for k5: String in sd.keys():
				ps.append(pill(gear_fmt(k5, sd[k5])))
			out.append({"t": "pills", "items": ps})
		out.append({"t": "plist", "rich": T("c.set_note", {"cls": tt("classes." + cls)})})
	return out


func _skill_row(s: Dictionary) -> Dictionary:
	var small := ""
	if Js.truthy(s.get("passive")):
		small = T("c.passive")
	elif Js.truthy(s.get("cost")):
		small = num(s["cost"]) + " " + tt("resources." + str(s.get("costType")), s.get("costType"))
	return {"t": "skill", "id": str(s["id"]), "icon": str(s.get("icon", "")), "name": tt("skills." + str(s["id"]), s.get("name")), "small": small,
		"desc": tt("skills_desc." + str(s["id"]), s.get("desc"))}


static func slot_group(slot: String) -> String:
	if slot == "weapon":
		return "weapon"
	if slot == "offhand":
		return "offhand"
	if ["helmet", "armor", "boots"].has(slot):
		return "armor"
	return "acc"


func stat_range(tpl: Dictionary, rar: String) -> String:
	var m := float(D["RARITY_MULT"][rar])
	var parts: Array = []
	var st: Dictionary = tpl["stats"]
	for k: String in st.keys():
		parts.append("%s %s~%s" % [stat_name(k), num(maxf(1.0, Js.round_js(float(st[k][0]) * m))), num(Js.round_js(float(st[k][1]) * m))])
	return " · ".join(parts)


func wearers(tpl: Dictionary) -> Dictionary:
	var lst: Variant = tpl.get("clsRestrict")
	if lst == null and Js.truthy(tpl.get("armorType")):
		lst = (D["ARMOR_TYPE"] as Dictionary).get(tpl["armorType"])
	if lst == null or (lst as Array).size() >= 12:
		return {"k": "wear", "all": T("c.all_cls"), "list": []}
	var names: Array = []
	for cl: String in lst:
		names.append(tt("classes." + cl))
	return {"k": "wear", "all": "", "list": (lst as Array).duplicate(), "names": names}


func comp_gear(filter: String) -> Array:
	var fl0: Array = []
	for fk: String in GEAR_FILTERS:
		fl0.append({"k": fk, "text": T("c.f_" + fk), "on": fk == filter})
	var out: Array = []
	var show := func(f: String) -> bool: return filter == "all" or filter == f
	for grp: String in ["weapon", "offhand", "armor", "acc"]:
		if not show.call(grp):
			continue
		var cards: Array = []
		for tpl: Dictionary in D["EQUIP_DB"]:
			if slot_group(str(tpl["slot"])) != grp:
				continue
			var tid := str(tpl["baseId"])
			var nm := gear_name_tid(tid)
			var tag := ""
			if Js.truthy(tpl.get("armorType")):
				tag = tt("gear.armor." + str(tpl["armorType"]), tpl["armorType"])
			elif Js.truthy(tpl.get("hand")):
				tag = T("c.two_h") if tpl["hand"] == "2h" else T("c.one_h")
			elif Js.truthy(tpl.get("setId")):
				tag = tt("equip.set." + str(tpl["setId"]), tpl["setId"])
			var slot_nm := tt("equip.slot." + str(tpl["slot"]))
			var ps: Array = [pill(slot_nm)]
			if tag != "":
				ps.append(pill(tag, "b"))
			cards.append(card([ph({"item": tid, "emoji": str((D["EQUIP_EMOJI"] as Dictionary).get(tid, ""))}, nm), pills(ps),
				pp("D %s<br><b>S %s</b>" % [stat_range(tpl, "common"), stat_range(tpl, "legendary")]), wearers(tpl)],
				nm + " " + tag + " " + slot_nm, {"rar": "rare", "item": true}))
		out.append(sec(T("c.g_" + grp), str(cards.size()), [grid(cards, 3)]))
	if show.call("legend"):
		var cards2: Array = []
		for id: String in (D["LEGENDS"] as Dictionary).keys():
			var L: Dictionary = D["LEGENDS"][id]
			var tpl2: Variant = Gear.equip_template(c, str(L["tpl"]))
			var nm2 := tt("gear.legend." + id)
			var fx: Array = []
			for k: String in (L["fx"] as Dictionary).keys():
				fx.append(gear_fmt(k, L["fx"][k]))
			var lines: Array = []
			for f: String in fx:
				lines.append(["legend", "★ " + f])
			var tname := gear_name_tid(str(L["tpl"]))
			var parts: Array = [ph({"item": "legend_" + id, "emoji": str((D["EQUIP_EMOJI"] as Dictionary).get(L["tpl"], ""))}, nm2), pills([pill("S", "g"), pill(tname)]),
				{"k": "lines", "items": lines}]
			if tpl2 != null:
				parts.append(wearers(tpl2))
			cards2.append(card(parts, nm2 + " " + " ".join(fx) + " " + tname, {"rar": "legendary", "item": true}))
		var GD: Dictionary = D["GEAR_DROP"]
		out.append(sec(T("c.s_legend"), "%d legends" % cards2.size(), [note("tip", "★", T("c.legend_note", {"a": Js.round_js(float(GD["bossLegend"]["first"]) * 100.0),
			"b": Js.round_js(float(GD["bossLegend"]["repeat"]) * 100.0), "c": Js.round_js(float(GD["dailyLegendHell"]) * 100.0), "d": D["GACHA_PITY_MAX"], "e": D["LEGEND_SHARD_COST"]})),
			grid(cards2)]))
	if show.call("set"):
		var cards3: Array = []
		for cls: String in (D["CLASS_SETS"] as Dictionary).keys():
			var s: Dictionary = D["CLASS_SETS"][cls]
			var nm3 := tt("gear.set." + cls)
			var lines3: Array = []
			for n: int in [2, 3]:
				var fl: Array = []
				for k2: String in (s[str(n)] as Dictionary).keys():
					fl.append(gear_fmt(k2, s[str(n)][k2]))
				lines3.append(["set", "%s: %s" % [T("c.n_set", {"n": n}), " · ".join(fl)]])
			var ca := str(D["CLASS_ARMOR"].get(cls, ""))
			cards3.append(card([ph({"cls": cls}, tt("gear.set_name", nm3, {"set": nm3})), pills([pill(T("c.set_only", {"cls": tt("classes." + cls)})), pill(tt("gear.armor." + ca, ca), "b")]),
				{"k": "lines", "items": lines3}], nm3 + " " + tt("classes." + cls)))
		var DS: Dictionary = D["GEAR_DROP"]["dailySet"]
		out.append(sec(T("c.f_set"), T("c.set_sub"), [note("", "🗓️", T("c.set_drop", {"a": Js.round_js(float(DS["normal"]) * 100.0), "b": Js.round_js(float(DS["hard"]) * 100.0),
			"c": Js.round_js(float(DS["hell"]) * 100.0)})), grid(cards3)]))
	if show.call("rule"):
		var rows: Array = []
		for r: String in D["RARITY_ORDER"]:
			var rate := float(D["GACHA_RATE"][r])
			rows.append([cell(rarity_label(r), false, {"color": str(D["RARITY"][r]["color"])}), cell("×" + num(D["RARITY_MULT"][r]), true), cell(num(D["SUB_COUNT"][r]), true),
				cell("○" if float(D["RARITY"][r]["tier"]) >= 2.0 else "−"), cell(T("c.legend_fx") if r == "legendary" else (T("c.random1") if r == "epic" else "−")),
				cell(OddsRules.pct(rate / _gacha_total()), true)])
		var enh: Array = []
		var ER: Array = D["ENHANCE_RATES"]
		for lv in ER.size():
			enh.append([cell("+%d → +%d" % [lv, lv + 1]), cell(OddsRules.pct(minf(1.0, float(ER[lv]))), true), cell(T("c.keep") if float(lv) < float(D["ENHANCE_SAFE_BELOW"]) else T("c.drop1")),
				cell(num(D["ENHANCE_STONES"][lv]), true), cell("+" + num(D["ENHANCE_STAT_PCT"][lv + 1]) + "%", true)])
		out.append(sec(T("c.s_rarity"), "rarity", [table([T("c.th_grade"), T("c.th_stats"), T("c.th_sub"), T("c.th_copt"), T("c.th_unique"), T("c.th_gacha")], rows)]))
		out.append(sec(T("c.s_enh"), "+1 ~ +10", [table([T("c.th_step"), T("c.th_success"), T("c.th_onfail"), T("c.th_stones"), T("c.th_stat")], enh),
			note("warn", "💥", T("c.break_note", {"p": float(D["ENHANCE_BREAK_CHANCE"]) * 100.0, "b": D["ENHANCE_FAIL_BONUS"], "m": D["ENHANCE_FAIL_BONUS_MAX"]})),
			note("tip", "✨", T("c.eopt_note", _eopt_params()))]))
	if out.is_empty():
		out.append({"t": "empty", "text": T("c.empty")})
	return [{"t": "filters", "items": fl0}] + out


func _cons_card(key: String, e: String, name: String, desc: String, ps: Array) -> Dictionary:
	var parts: Array = [ph({"item": key, "emoji": e}, name), pp(desc)]
	if not ps.is_empty():
		parts.append(pills(ps))
	return card(parts, name + " " + desc)


func comp_cons() -> Array:
	var potions: Array = []
	for p: Dictionary in (D["BATTLE_POTIONS"] as Dictionary).values():
		var id := str(p["id"])
		var ps: Array = [pill(T("c.action1")), pill(T("c.range_n", {"n": p["range"]}))]
		if Js.truthy(p.get("duration")):
			ps.append(pill(T("c.turns_n", {"n": p["duration"]})))
		ps.append(pill(num(D["ECON"]["battlePotion"]) + "G", "g"))
		potions.append(_cons_card(id, str(p["icon"]), tt("battle_potions." + id), tt("battle_potions." + id + "_desc", ""), ps))
	var exps: Array = []
	var pk := {"exp_s": "small", "exp_m": "medium", "exp_l": "large"}
	for e: Dictionary in EXP_POTIONS:
		exps.append(_cons_card(str(e["id"]), str(e["icon"]), tt("shop.potion_" + str(pk[e["id"]]), e["id"]), T("c.exp_desc"),
			[pill("EXP +" + num(e["exp"]), "b"), pill(num(e["cost"]) + "G", "g")]))
	var sieges: Array = []
	for s: Dictionary in D["SIEGE_ITEMS"]:
		sieges.append(_cons_card(str(s["id"]), str(s["icon"]), tt("shop." + str(s["id"])), tt("shop." + str(s["id"]) + "_desc", ""),
			[pill(T("c.range_n", {"n": s["range"]})), pill(num(s["cost"]) + "G", "g")]))
	var runes: Array = []
	for k: String in (D["ENCHANTS"] as Dictionary).keys():
		var atk: bool = D["ENCHANTS"][k]["cat"] == "atk"
		runes.append(_cons_card("rune_" + k, str(D["ENCHANTS"][k]["icon"]), tt("enchant.rune_name", k, {"e": tt("enchant." + k, k)}), tt("enchant.desc_" + k, ""),
			[pill(T("c.rune_atk") if atk else T("c.rune_def"), "r" if atk else "b")]))
	var MP: Dictionary = D["MATS_PRICE"]
	var mats: Array = [
		_cons_card("mat_stone", "🔩", tt("gear.stone", "stone"), T("c.stone_desc"), [pill(num(MP["stone"]) + "G", "g")]),
		_cons_card("mat_protect", "📜", tt("gear.protect", "protect"), T("c.protect_desc"), [pill(num(MP["protect"]) + "G", "g")]),
		_cons_card("mat_shard", "✦", tt("gear.shard", "shard"), T("c.shard_desc", {"n": D["LEGEND_SHARD_COST"]}), []),
		_cons_card("soul_stone", "💠", T("c.soul"), T("c.soul_desc", {"a": D["SOUL"]["promote"]["B"], "b": D["SOUL"]["promote"]["A"], "f": D["SOUL"]["fragsPerStone"]}),
			[pill(num(D["ECON"]["soulStone"]) + "G", "g")]),
	]
	var CH: Dictionary = D["CHEST"]
	var odds: Array = []
	for k2: String in (CH["odds"] as Dictionary).keys():
		odds.append(pill("%s %s%%" % [T("c.odd_" + k2), num(Js.round_js(float(CH["odds"][k2]) * 100.0))]))
	return [
		sec(T("c.s_potion"), "battle potions", [lead(T("c.potion_p")), grid(potions)]),
		sec(T("c.s_exp"), "exp", [grid(exps)]),
		sec(T("c.s_siege"), "siege", [grid(sieges)]),
		sec(T("c.s_rune"), "runes", [note("", "🔮", T("c.rune_note", {"fee": D["ENCHANT_FEE"], "p": Js.round_js(float(D["RUNE_DROP_CHANCE"]) * 100.0), "g": D["RUNE_GACHA_COST"]})), grid(runes)]),
		sec(T("c.s_mats"), "materials", [grid(mats)]),
		sec(T("c.s_chest"), "chest", [card([pp(T("c.chest_p", {"a": CH["min"], "b": CH["max"]})), pills(odds)])]),
	]


func episodes() -> Dictionary:
	var eps: Dictionary = {}
	for s: Dictionary in D["STAGES"]:
		var e := int(ceilf(float(s["id"]) / 10.0))
		if not eps.has(e):
			eps[e] = []
		(eps[e] as Array).append(s)
	return eps


func comp_stages() -> Array:
	var eps := episodes()
	var scale: Array = []
	for e: int in eps.keys():
		var ss: Array = eps[e]
		var a: Dictionary = ss[0]
		var z: Dictionary = ss[ss.size() - 1]
		var mn := INF
		var mx := -INF
		for s: Dictionary in ss:
			mn = minf(mn, float(s["tot"]))
			mx = maxf(mx, float(s["tot"]))
		scale.append([cell("Ep%d" % e), cell("%s~%s" % [num(mn), num(mx)], true), cell("%s~%s" % [num(StageRules.stage_enemy_lv(D, float(a["id"]))), num(StageRules.stage_enemy_lv(D, float(z["id"])))], true),
			cell("×%s~%s" % [num(a["sm"]["hp"]), num(z["sm"]["hp"])], true), cell("×%s~%s" % [num(a["sm"]["atk"]), num(z["sm"]["atk"])], true)])
	var hz: Array = []
	for m: String in (D["HAZARDS"] as Dictionary).keys():
		var h: Dictionary = D["HAZARDS"][m]
		hz.append(card([ph(emo(str(h["icon"])), hazard_label(h)), pp(hazard_describe(h, D["STAGES"][0]))], hazard_label(h) + " " + tt("maps." + m, m)))
	var accs: Array = []
	for e2: int in eps.keys():
		var rows: Array = []
		for s2: Dictionary in eps[e2]:
			var h2: Variant = Hazards.for_stage(D, s2)
			var sid := int(s2["id"])
			var nm := tt("stages.stage_%d_name" % sid, s2["name"] if Js.truthy(s2.get("name")) else "Stage %d" % sid)
			var tags: Array = [pill(T("c.style_" + str(s2["style"]))), pill(T("c.enemies", {"n": s2["tot"]}))]
			if h2 != null:
				tags.append(pill("%s %s" % [h2["icon"], hazard_label(h2)], "p", null, hazard_describe(h2, s2)))
			var boss := Js.truthy(s2.get("boss"))
			if boss:
				tags.append(pill("💀 " + boss_name(s2), "r"))
			rows.append({"t": "stage", "no": str(sid), "nm": nm, "sub": tt("stages.stage_%d_story" % sid, ""), "tags": tags, "boss": boss,
				"q": "%d %s %s %s" % [sid, nm, boss_name(s2) if boss else "", tt("hazard." + str(h2["id"]), "") if h2 != null else ""]})
		accs.append({"t": "acc", "ic": {"text": str(e2)}, "h": tt("episode.%d.name" % e2, "Episode %d" % e2), "sub": tt("episode.%d.desc" % e2, ""), "open": e2 == 1, "kids": rows})
	return [
		sec(T("c.s_ep"), "100 stages", accs),
		sec(T("c.s_scale"), "scaling", [lead(T("c.scale_p", {"a": D["STAGE_TOT_CAP_MAX"], "b": D["STAGE_TOT_CAP_BOSS"]})),
			table([T("c.th_range"), T("c.th_enemies"), T("c.th_elv"), T("c.th_hp"), T("c.th_atk")], scale)]),
		sec(T("c.s_hz"), "hazards", [grid(hz)]),
	]


func comp_panel(tab: String, gear_filter: String = "all") -> Array:
	match tab:
		"cls":
			return comp_classes()
		"gear":
			return comp_gear(gear_filter)
		"cons":
			return comp_cons()
		"stage":
			return comp_stages()
	return []


# ═══════════ 가이드 (guide.html) ═══════════

## 강화 옵션 단계(+1~3 …)별 붙는 확률 — 문구의 {r1}·{p1} … 자리 (데이터 ENHANCE_OPT 에서)
func _eopt_params() -> Dictionary:
	var out: Dictionary = {}
	var bands := OddsRules.enhance_opt_bands(c)
	for i in bands.size():
		out["r%d" % (i + 1)] = bands[i]["range"]
		out["p%d" % (i + 1)] = bands[i]["p"]
	return out


## 뽑기 등급 확률의 합 (확률 창·상점과 같은 식: 등급 확률 ÷ 합)
func _gacha_total() -> float:
	var t := 0.0
	for v: Variant in (D["GACHA_RATE"] as Dictionary).values():
		t += float(v)
	return t


func gcard(ic: String, h: String, p: String, params: Dictionary = {}) -> Dictionary:
	return card([ph({"text": ic} if ic.length() <= 1 and ic.unicode_at(0) < 128 else emo(ic), T(h)), pp(T(p, params))])


func guide_panel(tab: String) -> Array:
	match tab:
		"start":
			return [sec(T("g.s_overview"), "overview", [lead(T("g.overview_p")), note("warn", "📈", T("g.overview_warn"))]),
				sec(T("g.s_first"), "first steps", [gcard("1", "g.first1_h", "g.first1_p"), gcard("2", "g.first2_h", "g.first2_p"), gcard("3", "g.first3_h", "g.first3_p")]),
				sec(T("g.s_daily"), "daily", [grid([gcard("🗓️", "g.daily1_h", "g.daily1_p"), gcard("🛒", "g.daily2_h", "g.daily2_p")])])]
		"grow":
			var SP: Dictionary = D["SOUL"]["promote"]
			var grades: Array = []
			for gr: Array in [["C", 0.8, "−"], ["B", 0.9, "−"], ["A", 1.0, T("c.soul_ba", {"n": SP["B"]})], ["S", 1.1, T("c.soul_as", {"n": SP["A"]})]]:
				grades.append([cell(gr[0]), cell(num(D["GRADE_LV_CAP"][gr[0]]), true), cell("×" + num(gr[1]), true), cell(gr[2])])
			var gold_li: Array = []
			for i in range(1, 7):
				gold_li.append(T("g.gold_%d" % i))
			return [sec(T("g.s_level"), "level · grade", [table([T("c.th_grade"), T("c.th_lvcap"), T("c.th_mult"), T("c.th_soul")], grades), note("tip", "💡", T("g.level_tip"))]),
				sec(T("g.s_promote"), "sanctuary", [card([{"k": "ul", "items": [T("g.promote_li1"), T("g.promote_soul", {"a": SP["B"], "b": SP["A"]}), T("g.promote_li3")]}]),
					note("", "💠", T("g.promote_note"))]),
				sec(T("g.s_gold"), "gold", [card([ph(emo("🪙"), T("g.gold_h")), {"k": "ul", "items": gold_li}]), note("warn", "⚠️", T("g.gold_warn"))])]
		"gear":
			var rar: Array = []
			for r: String in D["RARITY_ORDER"]:
				rar.append([cell(rarity_label(r), false, {"color": str(D["RARITY"][r]["color"])}), cell(num(D["SUB_COUNT"][r]), true), cell("○" if float(D["RARITY"][r]["tier"]) >= 2.0 else "−"),
					cell(T("c.legend_fx19") if r == "legendary" else (T("c.random1") if r == "epic" else "−"))])
			var enh: Array = []
			var ER: Array = D["ENHANCE_RATES"]
			for lv in ER.size():
				enh.append([cell("+%d→+%d" % [lv, lv + 1]), cell(OddsRules.pct(minf(1.0, float(ER[lv]))), true), cell(T("c.keep") if float(lv) < float(D["ENHANCE_SAFE_BELOW"]) else T("c.drop1")),
					cell(num(D["ENHANCE_STONES"][lv]), true), cell("+" + num(D["ENHANCE_STAT_PCT"][lv + 1]) + "%", true)])
			var picks: Array = []
			for k: String in ["unyielding", "saint_tear", "king_seal", "dragon_scale"]:
				if (D["LEGENDS"] as Dictionary).has(k):
					picks.append(pill(tt("gear.legend." + k), "g", {"item": "legend_" + k, "emoji": "★"}))
			var tips: Array = []
			for i2 in range(1, 5):
				tips.append(T("g.tip%d" % i2))
			return [sec(T("g.s_gearstruct"), "equipment", [grid([gcard("🗡️", "g.wpn_h", "g.wpn_p"), gcard("🥋", "g.arm_h", "g.arm_p")]),
					table([T("c.th_grade"), T("c.th_sub"), T("c.th_copt"), T("c.th_unique")], rar), note("tip", "🎯", T("g.copt_tip"))]),
				sec(T("g.s_enh"), "enhance", [table([T("c.th_step"), T("c.th_success"), T("c.th_onfail"), T("c.th_stones"), T("c.th_stat")], enh),
					grid([gcard("💥", "g.break_h", "g.break_p", {"p": OddsRules.pct(float(D["ENHANCE_BREAK_CHANCE"]))}), gcard("✨", "g.eopt_h", "g.eopt_p")]), card([ph(emo("💡"), T("g.tips_h")), {"k": "ul", "items": tips}])]),
				sec(T("g.s_legset"), "legend · set", [grid([card([ph({"text": "★"}, T("g.leg_h")), pp(T("g.leg_p")), pills(picks)]), gcard("🔗", "g.set_h", "g.set_p")]), lead(T("g.more_gear"))])]
		"battle":
			var syn: Array = []
			for cl: String in PLAYER_CLASSES:
				if not (D["SYNERGY_MONO"] as Dictionary).has(cl):
					continue
				var trio: Variant = (D["SYNERGY_TRIO"] as Dictionary).get(cl)
				syn.append([cell(tt("classes." + cl), false, {"cls": cl}), cell("<b>%s</b><br>%s" % [synergy_name_mono(cl), synergy_describe(D["SYNERGY_MONO"][cl]["eff"])]),
					cell(synergy_describe(trio) if trio != null else "−")])
			var tac: Array = []
			for i3 in range(1, 10):
				var row: Array = []
				for x: String in T("g.t%d" % i3).split("|"):
					row.append(cell(x))
				tac.append(row)
			return [sec(T("g.s_syn"), "synergy", [lead(T("g.syn_p")), table([T("c.th_cls"), T("c.n5"), T("c.n3")], syn, true)]),
				sec(T("g.s_tactics"), "tactics", [table([T("g.th_elem"), T("g.th_effect"), T("g.th_use")], tac)]),
				sec(T("g.s_win"), "stars", [grid([gcard("🏰", "g.def_h", "g.def_p"), gcard("⚔️", "g.off_h", "g.off_p"), gcard("⭐", "g.star_h", "g.star_p")])])]
		"map":
			var hz: Array = []
			for m: String in (D["HAZARDS"] as Dictionary).keys():
				var h: Dictionary = D["HAZARDS"][m]
				hz.append(card([ph(emo(str(h["icon"])), hazard_label(h)), pp(hazard_describe(h, D["STAGES"][0]))]))
			var runes: Array = []
			for k2: String in Gear.rune_kinds(c, "atk"):
				runes.append(card([ph({"item": "rune_" + k2, "emoji": str(D["ENCHANTS"][k2]["icon"])}, tt("enchant." + k2, k2)), pp(tt("enchant.desc_" + k2, ""))]))
			var odds: Array = []
			for k3: String in (D["CHEST"]["odds"] as Dictionary).keys():
				odds.append(pill("%s %s%%" % [T("c.odd_" + k3), num(Js.round_js(float(D["CHEST"]["odds"][k3]) * 100.0))]))
			return [sec(T("g.s_hz"), "hazards", [lead(T("g.hz_p")), grid(hz), note("tip", "☄️", T("g.hz_tip"))]),
				sec(T("g.s_enchant"), "enchant", [card([{"k": "ul", "items": [T("g.ench1"), T("g.ench2"), T("g.ench3")]}]), grid(runes)]),
				sec(T("g.s_chest"), "chest", [card([pp(T("g.chest_p")), pills(odds)])])]
		"route":
			var eps := episodes()
			var accs: Array = []
			for e: int in eps.keys():
				var ss: Array = eps[e]
				var bosses: Array = []
				var maps: Array = []
				var mn := INF
				var mx := -INF
				for s: Dictionary in ss:
					mn = minf(mn, float(s["tot"]))
					mx = maxf(mx, float(s["tot"]))
					if Js.truthy(s.get("boss")):
						bosses.append(pill("💀 %d %s" % [int(s["id"]), boss_name(s)], "r"))
					var h2: Variant = Hazards.for_stage(D, s)
					if h2 != null:
						var lbl := "%s %s" % [h2["icon"], hazard_label(h2)]
						if not maps.has(lbl):
							maps.append(lbl)
				var mp: Array = []
				for lb: String in maps:
					mp.append(pill(lb, "p"))
				var meta := T("g.route_meta", {"a": (e - 1) * 10 + 1, "b": e * 10, "c": mn, "d": mx, "e": StageRules.stage_enemy_lv(D, float(ss[0]["id"])),
					"f": StageRules.stage_enemy_lv(D, float(ss[ss.size() - 1]["id"]))})
				accs.append({"t": "acc", "ic": {"text": str(e)}, "h": tt("episode.%d.name" % e, "Ep%d" % e), "sub": meta, "open": false,
					"kids": [lead(T("g.r%d" % e)), {"t": "pills", "items": bosses + mp}]})
			var bot: Array = []
			for i4 in range(1, 5):
				var abc := T("g.b%d" % i4).split("|")
				bot.append([cell(abc[0] if abc.size() > 0 else ""), cell(abc[1] if abc.size() > 1 else "", true), cell(abc[2] if abc.size() > 2 else "")])
			return [sec(T("g.s_route"), "route", accs), sec(T("g.s_bot"), "autoplay", [table([T("g.th_combo"), T("g.th_reach"), T("g.th_trait")], bot), note("", "🤖", T("g.bot_note"))])]
		"story":
			var cast: Array = []
			for k4: String in CAST:
				cast.append({"t": "person", "pics": [k4], "h": T("g.cast_%s_n" % k4), "pill": "", "role": T("g.cast_%s_r" % k4), "p": T("g.cast_%s_p" % k4)})
			var bosses2: Array = []
			for s3: Dictionary in D["STAGES"]:
				if Js.truthy(s3.get("boss")):
					bosses2.append({"t": "person", "pics": ["boss_%d" % int(s3["id"])], "h": boss_name(s3), "pill": str(int(s3["id"])), "role": "", "p": T("g.boss_%d" % int(s3["id"]))})
			var sp: Array = []
			for i5 in range(1, 6):
				sp.append(T("g.spoil_%d" % i5))
			return [sec(T("g.s_story"), "story", [lead(T("g.story_p"))]),
				sec(T("g.s_hero"), "commander", [{"t": "person", "pics": ["commander_m", "commander_f"], "h": T("g.hero_h"), "pill": "", "role": "", "p": T("g.hero_p")}]),
				sec(T("g.s_cast"), "cast", [grid(cast)]),
				sec(T("g.s_boss"), "bosses", [lead(T("g.boss_p")), grid(bosses2)]),
				sec(T("g.s_spoil"), "spoiler", [{"t": "acc", "ic": {"text": "!"}, "h": T("g.spoil_sum"), "sub": "", "open": false, "kids": [card([{"k": "ul", "items": sp}])]}])]
	return []


# ═══════════ 글 조각 (시험: 웹 HTML 에서 태그를 걷어낸 조각과 같은 순서) ═══════════

## 웹 글(태그가 섞인 것) → 조각: 태그에서 자르고, 앞뒤 공백을 지우고, 빈 것은 버림 (&amp; 등은 글자로)
static func rich_tokens(s: String) -> Array:
	var out: Array = []
	var re := RegEx.create_from_string("<[^>]*>")
	var pos := 0
	for m: RegExMatch in re.search_all(s):
		_push_tok(out, s.substr(pos, m.get_start() - pos))
		pos = m.get_end()
	_push_tok(out, s.substr(pos))
	return out


static func _push_tok(out: Array, raw: String) -> void:
	var x := raw.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'").replace("&amp;", "&").strip_edges()
	if x != "":
		out.append(x)


static func _ic_tokens(ic: Variant, out: Array) -> void:
	if ic is Dictionary:
		if ic.has("emoji") and not ic.has("item"):
			_push_tok(out, str(ic["emoji"]))
		elif ic.has("text"):
			_push_tok(out, str(ic["text"]))


static func _pill_tokens(p: Dictionary, out: Array) -> void:
	_push_tok(out, str(p["text"]))


## 블록 목록 → 조각 (웹 DOM 순서)
static func tokens(blocks: Array) -> Array:
	var out: Array = []
	for b: Variant in blocks:
		_block_tokens(b, out)
	return out


static func _block_tokens(b: Dictionary, out: Array) -> void:
	match str(b["t"]):
		"sec":
			_push_tok(out, str(b["h"]))
			_push_tok(out, str(b["sm"]))
			for k: Variant in b["kids"]:
				_block_tokens(k, out)
		"lead", "plist":
			out.append_array(rich_tokens(str(b["rich"])))
		"note":
			_ic_tokens(b["ic"], out)
			out.append_array(rich_tokens(str(b["rich"])))
		"grid":
			for k2: Variant in b["kids"]:
				_block_tokens(k2, out)
		"card":
			for p: Dictionary in b["parts"]:
				match str(p["k"]):
					"h":
						_ic_tokens(p["ic"], out)
						_push_tok(out, str(p["text"]))
					"p":
						out.append_array(rich_tokens(str(p["rich"])))
					"pills":
						for pl: Dictionary in p["items"]:
							_pill_tokens(pl, out)
					"lines":
						for ln: Array in p["items"]:
							_push_tok(out, str(ln[1]))
					"ul":
						for li: String in p["items"]:
							out.append_array(rich_tokens(li))
					"wear":
						if str(p["all"]) != "":
							_push_tok(out, str(p["all"]))
		"table":
			for h: String in b["head"]:
				out.append_array(rich_tokens(h))
			for row: Array in b["rows"]:
				for cl: Dictionary in row:
					out.append_array(rich_tokens(str(cl["rich"])))
		"acc":
			_ic_tokens(b["ic"], out)
			out.append_array(rich_tokens(str(b["h"])))
			out.append_array(rich_tokens(str(b["sub"])))
			for k3: Variant in b["kids"]:
				_block_tokens(k3, out)
		"stage":
			_push_tok(out, str(b["no"]))
			_push_tok(out, str(b["nm"]))
			_push_tok(out, str(b["sub"]))
			for pl2: Dictionary in b["tags"]:
				_pill_tokens(pl2, out)
		"tiles":
			for it: Dictionary in b["items"]:
				_push_tok(out, str(it["name"]))
				_push_tok(out, str(it["role_text"]))
		"person":
			if str(b["pill"]) != "":
				_push_tok(out, str(b["pill"]))
			out.append_array(rich_tokens(str(b["h"])))
			_push_tok(out, str(b["role"]))
			out.append_array(rich_tokens(str(b["p"])))
		"pills":
			for pl3: Dictionary in b["items"]:
				_pill_tokens(pl3, out)
		"subh":
			_push_tok(out, str(b["text"]))
		"head":
			_push_tok(out, str(b["name"]))
			_push_tok(out, str(b["role_text"]))
			_push_tok(out, str(b["desc"]))
		"bars":
			for it2: Dictionary in b["items"]:
				_push_tok(out, str(it2["name"]))
				_push_tok(out, str(it2["v"]))
		"skill":
			_push_tok(out, str(b["name"]))
			_push_tok(out, str(b["small"]))
			out.append_array(rich_tokens(str(b["desc"])))
		"empty":
			_push_tok(out, str(b["text"]))
		"filters":
			for it3: Dictionary in b["items"]:
				_push_tok(out, str(it3["text"]))

