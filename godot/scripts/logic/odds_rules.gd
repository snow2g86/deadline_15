extends RefCounted
## 확률 정보 (결제층 A) — 장비 뽑기 · 마법부여 룬 뽑기 · 장비 강화. 화면 코드 없이 정적 함수, 첫 인자 c = ctx.gd (D)
##  숫자는 모두 게임 데이터(GACHA_RATE · GACHA_PITY_MAX · GACHA_MULTI_COUNT · RARITY · EQUIP_DB · LEGENDS · ENCHANTS · RUNE_GACHA_COST ·
##  ENHANCE_RATES · ENHANCE_BREAK_CHANCE · ENHANCE_SAFE_BELOW · ENHANCE_FAIL_BONUS(_MAX) · ENHANCE_OPT · ENHANCE_MAX_LV)에서 계산한다.
##  손으로 적은 숫자 없음 — 규칙(gear.gd roll_rarity · gacha_pull · rune_random, equip_rules.gd enhance_item)과 같은 식.
##  같은 표를 게임 안 창(scripts/ui/odds_view.gd)과 스토어 설명용 글(tools/odds_export.gd → docs/store/probabilities.<언어>.md)이 쓴다.

const Js := preload("res://scripts/logic/js.gd")


## 비율(0~1) → "60%" · "4.5%" · "0.05%" · "8.333%" · "0.002632%"
##  반올림은 0이 아닌 첫 자리에서 4자리 아래(유효숫자 4자리 이상)에서만: 1% 이상은 소수 셋째 자리, 1% 미만은 첫 유효숫자 아래 3자리 (끝의 0 지움).
##  상점 인라인 표시·확률 창·스토어 글이 모두 이 함수 하나 — 값이 서로 어긋나지 않는다.
static func pct(rate: float) -> String:
	var p := rate * 100.0
	if p <= 0.0:
		return "0%"
	var dec := clampi(3 - int(floorf(log(p) / log(10.0))), 3, 12)
	var s := String.num(snappedf(p, pow(10.0, -float(dec))), dec)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s + "%"


static func _rarities(c: Object) -> Array:
	return (c.D["GACHA_RATE"] as Dictionary).keys()


## 등급 뽑기 확률 (gear.gd roll_rarity 와 같은 식: min_rarity 이상의 등급만 남겨 그 합으로 나눔)
static func rarity_rates(c: Object, min_rarity: Variant = null) -> Array:
	var RAR: Dictionary = c.D["RARITY"]
	var GR: Dictionary = c.D["GACHA_RATE"]
	var min_tier := float(RAR[min_rarity]["tier"]) if min_rarity != null else 0.0
	var total := 0.0
	for r: String in GR.keys():
		if float(RAR[r]["tier"]) >= min_tier:
			total += float(GR[r])
	var out: Array = []
	for r2: String in GR.keys():
		var on := float(RAR[r2]["tier"]) >= min_tier
		out.append({"rarity": r2, "rate": float(GR[r2]) / total if on and total > 0.0 else 0.0})
	return out


static func gacha(c: Object) -> Dictionary:
	var base := rarity_rates(c)
	var sum := 0.0
	for r: Dictionary in base:
		sum += float(r["rate"])
	var raw_sum := 0.0
	for v: Variant in (c.D["GACHA_RATE"] as Dictionary).values():
		raw_sum += float(v)
	return {"rows": base, "sum": sum, "raw_sum": raw_sum, "multi_last": rarity_rates(c, "rare"), "multi_min": "rare",
		"pity": int(c.D["GACHA_PITY_MAX"]), "multi_count": int(c.D["GACHA_MULTI_COUNT"]),
		"cost1": float(c.D["GACHA_COST_1"]), "cost10": float(c.D["GACHA_COST_10"]),
		"kinds": (c.D["EQUIP_DB"] as Array).size(), "legends": (c.D["LEGENDS"] as Dictionary).size()}


static func rune(c: Object) -> Dictionary:
	var kinds: Array = (c.D["ENCHANTS"] as Dictionary).keys()
	var rows: Array = []
	for k: String in kinds:
		rows.append({"kind": k, "rate": 1.0 / float(kinds.size())})
	return {"rows": rows, "cost": float(c.D["RUNE_GACHA_COST"]), "sum": float(rows.size()) * (1.0 / float(kinds.size()))}


## 강화 한 번 시도 (보너스 0 · 보호 주문서 없음): 성공 · 실패 · 실패하면(유지/−1) · 파손(시도당) · 성공 시 강화 옵션
static func enhance(c: Object) -> Dictionary:
	var rates: Array = c.D["ENHANCE_RATES"]
	var brk := float(c.D["ENHANCE_BREAK_CHANCE"])
	var safe := float(c.D["ENHANCE_SAFE_BELOW"])
	var mx := int(c.D["ENHANCE_MAX_LV"])
	var rows: Array = []
	for lv in mx:
		var r := minf(1.0, Js.num(rates[lv]) if lv < rates.size() else 0.0)
		var opt := 0.0
		for b: Dictionary in c.D["ENHANCE_OPT"]:
			if float(lv + 1) <= float(b["upTo"]):
				opt = float(b["chance"])
				break
		rows.append({"from": lv, "to": lv + 1, "success": r, "fail": 1.0 - r, "drop": float(lv) >= safe,
			"break": (1.0 - r) * brk, "opt": opt})
	return {"rows": rows, "break_on_fail": brk, "bonus": float(c.D["ENHANCE_FAIL_BONUS"]), "bonus_max": float(c.D["ENHANCE_FAIL_BONUS_MAX"]),
		"safe_below": int(safe), "max": mx}


# ── 공개 항목 보강 (종류별 · 천장 · 강화 옵션 · 고유 효과 · 능력치 범위) — 모두 코드(gear.gd · equip_rules.gd)와 같은 식으로 데이터에서 계산 ──

## 부가 옵션 수치 = 범위 값 × (등급 배율 ÷ 이 값) — gear.gd roll() 의 `/ 1.6`
const SUB_MUL_DIV := 1.6
## 뽑기에서 전설은 종류 표(EQUIP_DB)가 아니라 전설 장비 목록(LEGENDS)에서 뽑음 — gear.gd gacha_pull 의 "legendary"
const LEGEND_RARITY := "legendary"


static func _is_dec(c: Object, id: String) -> bool:
	var fx: Dictionary = c.D["GEAR_FX"]
	return fx.has(id) and fx[id].get("u") == "dec"


## 수치 글 — 소수 효과(행동 속도)는 소수 둘째 자리, 나머지는 정수
static func _num(v: float, dec: bool) -> String:
	return String.num(snappedf(v, 0.01), 2) if dec else str(int(Js.round_js(v)))


static func _range_txt(lo: float, hi: float, dec: bool) -> String:
	var a := _num(lo, dec)
	var b := _num(hi, dec)
	return a if a == b else a + "~" + b


## 효과 이름 + 수치 범위 ("체력 +3~6%") — 번역 gear.fx.<id> 의 {v} 자리에 범위
static func _fx_txt(tfn: Callable, id: String, rng: String) -> String:
	return str(tfn.call("gear.fx." + id, {"v": rng}))


## 장비 종류 이름 (equip_rules.gd gear_name 과 같은 순서: gear.item.<id> → equip.item.<id>)
static func kind_name(tfn: Callable, base_id: String) -> String:
	var k := "gear.item." + base_id
	var v := str(tfn.call(k, {}))
	return v if v != "" and v != k else str(tfn.call("equip.item." + base_id, {}))


## 등급 확률 한 줄 — "D - 일반 60% · C - 고급 35% · …" (min_rarity 를 주면 그 이상만, 0% 는 뺌). 상점 카드 요약용
static func rate_line(c: Object, tfn: Callable, min_rarity: Variant = null) -> String:
	var parts: Array = []
	for r: Dictionary in rarity_rates(c, min_rarity):
		if float(r["rate"]) > 0.0:
			parts.append("%s %s" % [tfn.call("equip.rarity." + str(r["rarity"]), {}), pct(float(r["rate"]))])
	return " · ".join(parts)


## 천장 횟수별 등급 확률 — gear.gd gacha_pull: 카운터+1 이 GACHA_PITY_MAX 에 이르면 전설 확정, 아니면 평소 확률
static func pity(c: Object) -> Dictionary:
	var mx := int(c.D["GACHA_PITY_MAX"])
	var base := rarity_rates(c)
	var at: Array = []
	for r: Dictionary in base:
		at.append({"rarity": r["rarity"], "rate": 1.0 if str(r["rarity"]) == LEGEND_RARITY else 0.0})
	return {"max": mx, "base": base, "at": at}


## 장비 종류별 확률 — 전설이 아닌 등급은 EQUIP_DB 에서 같은 확률로 (gear.gd gacha_pull: DB[floor(rand × size)])
static func kinds(c: Object) -> Dictionary:
	var db: Array = c.D["EQUIP_DB"]
	var n := db.size()
	var last_min := "rare"
	var one: Array = []
	var last: Array = []
	for r: Dictionary in rarity_rates(c):
		if str(r["rarity"]) != LEGEND_RARITY:
			one.append({"rarity": r["rarity"], "rate": float(r["rate"]) / float(n)})
	for r2: Dictionary in rarity_rates(c, last_min):
		if str(r2["rarity"]) != LEGEND_RARITY and float(r2["rate"]) > 0.0:
			last.append({"rarity": r2["rarity"], "rate": float(r2["rate"]) / float(n)})
	return {"n": n, "one": one, "last": last, "last_min": last_min, "ids": db.map(func(d: Dictionary) -> String: return str(d["baseId"]))}


## 전설 장비별 확률 — 전설 등급 확률 ÷ 전설 종류 수 (아직 하나도 없을 때. gear.gd make_legend: 가진 것을 뺀 나머지에서 같은 확률)
static func legends(c: Object) -> Dictionary:
	var ids: Array = (c.D["LEGENDS"] as Dictionary).keys()
	var n := ids.size()
	var one := 0.0
	for r: Dictionary in rarity_rates(c):
		if str(r["rarity"]) == LEGEND_RARITY:
			one = float(r["rate"])
	var last := 0.0
	for r2: Dictionary in rarity_rates(c, "rare"):
		if str(r2["rarity"]) == LEGEND_RARITY:
			last = float(r2["rate"])
	return {"n": n, "ids": ids, "one": one / float(n), "last": last / float(n), "pity": 1.0 / float(n)}


## 기본 능력치 범위 (등급 배율 적용) — gear.gd generate_equip: round(범위 균등 × 배율), 최소 1. maxRoll(전설)은 범위의 최대값
static func base_stat_range(c: Object, tpl: Dictionary, rarity: String, max_roll: bool) -> Array:
	var mult := float(c.D["RARITY_MULT"][rarity])
	var out: Array = []
	var stats: Dictionary = tpl["stats"]
	for k: String in stats.keys():
		var rg: Array = stats[k]
		var lo := maxf(1.0, Js.round_js(float(rg[1] if max_roll else rg[0]) * mult))
		var hi := maxf(1.0, Js.round_js(float(rg[1]) * mult))
		out.append({"stat": k, "lo": lo, "hi": hi})
	return out


static func _stat_txt(tfn: Callable, rngs: Array) -> String:
	var parts: Array = []
	for x: Dictionary in rngs:
		parts.append("%s %s" % [tfn.call("common." + str(x["stat"]), {}), _range_txt(float(x["lo"]), float(x["hi"]), false)])
	return " · ".join(parts)


## 부가 옵션 수치 범위 — gear.gd roll(): (범위 값 반올림) × (등급 배율 ÷ 1.6), 정수는 반올림·최소 1, 소수 효과는 소수 둘째 자리
static func sub_range(c: Object, id: String, rarity: String) -> Array:
	var rg: Array = c.D["SUB_RANGE"][id]
	var dec := _is_dec(c, id)
	var mul := float(c.D["RARITY_MULT"][rarity]) / SUB_MUL_DIV
	var out: Array = []
	for b: Variant in rg:
		var v := (Js.round_js(float(b) * 100.0) / 100.0 if dec else Js.round_js(float(b))) * mul
		out.append(Js.round_js(v * 100.0) / 100.0 if dec else maxf(1.0, Js.round_js(v)))
	return out


## 강화 옵션 단계 묶음 (ENHANCE_OPT) — [{lo, hi, chance, unique, rows:[{id, lo, hi, share}]}]. gear.gd roll_enhance_opt: 가중치(기본 1)로 뽑기
static func enhance_opts(c: Object) -> Array:
	var out: Array = []
	var prev := 0
	for b: Dictionary in c.D["ENHANCE_OPT"]:
		var band := {"lo": prev + 1, "hi": int(b["upTo"]), "chance": float(b["chance"]), "unique": Js.truthy(b.get("unique")), "rows": []}
		prev = int(b["upTo"])
		if band["unique"]:
			var up: Array = c.D["UNIQUE_POOL"]
			for u: Dictionary in up:
				(band["rows"] as Array).append({"id": u["id"], "lo": float(u["r"][0]), "hi": float(u["r"][1]), "share": 1.0 / float(up.size())})
		else:
			var tot := 0.0
			for k: String in b["pool"].keys():
				var r: Array = b["pool"][k]
				tot += float(r[2]) if r.size() > 2 and Js.truthy(r[2]) else 1.0
			for k2: String in b["pool"].keys():
				var r2: Array = b["pool"][k2]
				var w := float(r2[2]) if r2.size() > 2 and Js.truthy(r2[2]) else 1.0
				(band["rows"] as Array).append({"id": k2, "lo": float(r2[0]), "hi": float(r2[1]), "share": w / tot})
		out.append(band)
	return out


## 문구용: 강화 옵션 단계별 {range: "+1~3", p: "25%"} (도감 설명이 데이터에서 숫자를 가져오게)
static func enhance_opt_bands(c: Object) -> Array:
	var out: Array = []
	for b: Dictionary in enhance_opts(c):
		out.append({"range": ("+%d" % int(b["lo"])) if int(b["lo"]) == int(b["hi"]) else "+%d~%d" % [int(b["lo"]), int(b["hi"])], "p": pct(float(b["chance"]))})
	return out


static func _sum_row(tfn: Callable, cells: Array) -> Array:
	var row: Array = [tfn.call("gd.odds.sum", {})]
	row.append_array(cells)
	return row


## 직업 옵션(cOpt) — gear.gd roll() 이 희귀(tier 2) 이상 장비에 항상 1개: 직업은 장비가 쓸 수 있는 직업(clsRestrict) 중 같은 확률,
##  그 직업의 옵션 3종은 가중치(w, 기본 1)로, 수치는 범위(반올림)에 등급 배율(÷1.6)을 곱해 반올림 (noScale 효과는 배율 없음)
static func class_opts(c: Object) -> Dictionary:
	var tiers: Array = []
	for r: String in _rarities(c):
		if float(c.D["RARITY"][r]["tier"]) >= 2.0:
			tiers.append(r)
	var CO: Dictionary = c.D["CLASS_OPTS"]
	var rows: Array = []
	for cls: String in CO.keys():
		var tot := 0.0
		for o: Dictionary in CO[cls]:
			tot += float(o["w"]) if Js.truthy(o.get("w")) else 1.0
		for o2: Dictionary in CO[cls]:
			var id := str(o2["id"])
			var dec := _is_dec(c, id)
			var scale: bool = c.D["GEAR_FX"].has(id) and not Js.truthy(c.D["GEAR_FX"][id].get("noScale"))
			var per: Array = []
			for r2: String in tiers:
				var mul := float(c.D["RARITY_MULT"][r2]) / SUB_MUL_DIV
				var ends: Array = []
				for b: Variant in o2["r"]:
					var v := Js.round_js(float(b) * 100.0) / 100.0 if dec else Js.round_js(float(b))
					if scale:
						v = Js.round_js(v * mul * 100.0) / 100.0 if dec else maxf(1.0, Js.round_js(v * mul))
					ends.append(v)
				per.append(ends)
			rows.append({"cls": cls, "id": id, "dec": dec, "share": (float(o2["w"]) if Js.truthy(o2.get("w")) else 1.0) / tot, "per": per})
	return {"tiers": tiers, "rows": rows}


## 새 구역들 (확률 창 · 스토어 글 공용) — sections() 가 기존 3구역 뒤에 붙임
static func detail_sections(c: Object, tfn: Callable) -> Array:
	var out: Array = []
	var RAR: Array = _rarities(c)
	var rname := func(r: String) -> String: return str(tfn.call("equip.rarity." + r, {}))
	# ── 천장 횟수별 ──
	var py := pity(c)
	var mx: int = py["max"]
	var multi_n := int(c.D["GACHA_MULTI_COUNT"])
	var prow: Array = [tfn.call("gd.odds.pity_range", {"a": 1, "b": mx - 1})]
	for r: Dictionary in py["base"]:
		prow.append(pct(float(r["rate"])))
	var prow2: Array = [tfn.call("gd.odds.pity_at", {"n": mx})]
	for r2: Dictionary in py["at"]:
		prow2.append(pct(float(r2["rate"])))
	var phead: Array = [tfn.call("gd.odds.col_count", {})]
	for r3: String in RAR:
		phead.append(rname.call(r3))
	out.append({"id": "pity", "title": tfn.call("gd.odds.pity_title", {}), "head": phead, "rows": [prow, prow2],
		"notes": [tfn.call("gd.odds.pity_note", {"n": mx, "m": multi_n})]})
	# ── 장비 종류별 ──
	var kd := kinds(c)
	var one: Array = kd["one"]
	var last: Array = kd["last"]
	var khead: Array = [tfn.call("gd.odds.col_kind", {})]
	for x: Dictionary in one:
		khead.append(rname.call(str(x["rarity"])))
	for y: Dictionary in last:
		khead.append(tfn.call("gd.odds.col_last_r", {"n": multi_n, "r": rname.call(str(y["rarity"])), "m": rname.call(str(kd["last_min"]))}))
	var krows: Array = []
	for id: String in kd["ids"]:
		var row: Array = [kind_name(tfn, id)]
		for x2: Dictionary in one:
			row.append(pct(float(x2["rate"])))
		for y2: Dictionary in last:
			row.append(pct(float(y2["rate"])))
		krows.append(row)
	var ksum: Array = []
	for x3: Dictionary in one:
		ksum.append(pct(float(x3["rate"]) * float(kd["n"])))
	for y3: Dictionary in last:
		ksum.append(pct(float(y3["rate"]) * float(kd["n"])))
	krows.append(_sum_row(tfn, ksum))
	out.append({"id": "kinds", "title": tfn.call("gd.odds.kinds_title", {"n": kd["n"]}), "head": khead, "rows": krows,
		"cw": [2.2, 1, 1, 1, 1, 1, 1], "notes": [tfn.call("gd.odds.kinds_note", {"n": kd["n"]})]})
	# ── 전설 장비별 ──
	var lg := legends(c)
	var lrows: Array = []
	var LGD: Dictionary = c.D["LEGENDS"]
	for id2: String in lg["ids"]:
		var tpl: Variant = null
		for d: Dictionary in c.D["EQUIP_DB"]:
			if d["baseId"] == LGD[id2]["tpl"]:
				tpl = d
		lrows.append([tfn.call("gear.legend." + id2, {}), pct(float(lg["one"])), pct(float(lg["last"])), pct(float(lg["pity"])),
			_stat_txt(tfn, base_stat_range(c, tpl, LEGEND_RARITY, true)) if tpl != null else "-"])
	lrows.append(_sum_row(tfn, [pct(float(lg["one"]) * float(lg["n"])), pct(float(lg["last"]) * float(lg["n"])), pct(float(lg["pity"]) * float(lg["n"])), ""]))
	out.append({"id": "legends", "title": tfn.call("gd.odds.legends_title", {"n": lg["n"]}),
		"head": [tfn.call("gd.odds.col_legend", {}), tfn.call("gd.odds.col_one", {}), tfn.call("gd.odds.col_last_leg", {"n": multi_n, "m": rname.call("rare")}), tfn.call("gd.odds.col_at_pity", {}), tfn.call("gd.odds.col_stats", {})],
		"rows": lrows, "cw": [1.6, 1, 1.2, 1, 2], "notes": [tfn.call("gd.odds.legends_note", {"n": lg["n"]})]})
	# ── 강화 옵션 종류별 / +10 고유 효과 ──
	var uniq_n := (c.D["UNIQUE_POOL"] as Array).size()
	var bands := enhance_opts(c)
	for bi in bands.size():
		var b: Dictionary = bands[bi]
		var brows: Array = []
		var tot_share := 0.0
		for r4: Dictionary in b["rows"]:
			var dec := _is_dec(c, str(r4["id"]))
			brows.append([_fx_txt(tfn, str(r4["id"]), _range_txt(float(r4["lo"]), float(r4["hi"]), dec)), pct(float(r4["share"])), pct(float(b["chance"]) * float(r4["share"]))])
			tot_share += float(r4["share"])
		brows.append(_sum_row(tfn, [pct(tot_share), pct(float(b["chance"]) * tot_share)]))
		# 설명은 첫 단계와, 이동·사거리(이미 가지면 빠짐)가 있는 단계에만 (같은 글이 세 번 나오지 않게)
		var has_mr := false
		for r4b: Dictionary in b["rows"]:
			has_mr = has_mr or str(r4b["id"]) == "move" or str(r4b["id"]) == "range"
		var enh_notes: Array = []
		if bool(b["unique"]):
			enh_notes.append(tfn.call("gd.odds.enhopt_unique_note", {"n": uniq_n}))
		elif bi == 0 or has_mr:
			enh_notes.append(tfn.call("gd.odds.enhopt_note", {}))
		var rng_txt := ("+%d" % int(b["lo"])) if int(b["lo"]) == int(b["hi"]) else "+%d~%d" % [int(b["lo"]), int(b["hi"])]
		out.append({"id": "enh_opt_%d" % (bi + 1),
			"title": tfn.call("gd.odds.enhopt_unique_title" if bool(b["unique"]) else "gd.odds.enhopt_title", {"r": rng_txt, "p": pct(float(b["chance"]))}),
			"head": [tfn.call("gd.odds.col_effect", {}), tfn.call("gd.odds.col_given", {}), tfn.call("gd.odds.col_per_success", {})], "rows": brows, "cw": [3, 1, 1],
			"notes": enh_notes})
	# ── 직업 옵션 (희귀 이상 장비에 항상 1개) ──
	var co := class_opts(c)
	var tiers: Array = co["tiers"]
	var chead: Array = [tfn.call("gd.odds.col_class", {}), tfn.call("gd.odds.col_effect_at", {"r": rname.call(str(tiers[0]))}), tfn.call("gd.odds.col_in_class", {})]
	for ti in range(1, tiers.size()):
		chead.append(rname.call(str(tiers[ti])))
	var crows: Array = []
	for r12: Dictionary in co["rows"]:
		var per: Array = r12["per"]
		var crow: Array = [tfn.call("classes." + str(r12["cls"]), {}), _fx_txt(tfn, str(r12["id"]), _range_txt(float(per[0][0]), float(per[0][1]), bool(r12["dec"]))), pct(float(r12["share"]))]
		for ti2 in range(1, tiers.size()):
			crow.append(_range_txt(float(per[ti2][0]), float(per[ti2][1]), bool(r12["dec"])))
		crows.append(crow)
	var armor_cnt: Array = []
	for at: String in (c.D["ARMOR_TYPE"] as Dictionary).keys():
		armor_cnt.append("%s %d" % [tfn.call("gear.armor." + at, {}), (c.D["ARMOR_TYPE"][at] as Array).size()])
	var off_n := 0
	for d3: Dictionary in c.D["EQUIP_DB"]:
		if d3["slot"] == "offhand":
			off_n = (d3["clsRestrict"] as Array).size()
	out.append({"id": "class_opt", "title": tfn.call("gd.odds.classopt_title", {}), "head": chead, "rows": crows, "cw": [1.2, 2.6, 1.3, 1, 1],
		"notes": [tfn.call("gd.odds.classopt_note", {"r": rname.call(str(tiers[0])), "off": off_n, "armor": " · ".join(armor_cnt), "acc": (c.D["ALL_CLASSES"] as Array).size(), "d": SUB_MUL_DIV})]})
	# ── 능력치 롤 범위: 기본 능력치 (종류 × 등급) ──
	var srows: Array = []
	var shead: Array = [tfn.call("gd.odds.col_kind", {})]
	var nl: Array = []
	for r5: String in RAR:
		if r5 != LEGEND_RARITY:
			shead.append(rname.call(r5))
			nl.append(r5)
	for d2: Dictionary in c.D["EQUIP_DB"]:
		var srow: Array = [kind_name(tfn, str(d2["baseId"]))]
		for r6: String in nl:
			srow.append(_stat_txt(tfn, base_stat_range(c, d2, r6, false)))
		srows.append(srow)
	var mults: Array = []
	for r7: String in RAR:
		mults.append("×" + String.num(float(c.D["RARITY_MULT"][r7]), 2).rstrip("0").rstrip("."))
	out.append({"id": "stat_base", "title": tfn.call("gd.odds.statbase_title", {}), "head": shead, "rows": srows, "cw": [1.6, 1, 1, 1, 1],
		"notes": [tfn.call("gd.odds.statbase_note", {"m": " / ".join(mults)})]})
	# ── 능력치 롤 범위: 부가 옵션 ──
	var sub_rar: Array = []
	for r8: String in RAR:
		if int(c.D["SUB_COUNT"].get(r8, 0)) > 0:
			sub_rar.append(r8)
	var uhead: Array = [tfn.call("gd.odds.col_sub", {})]
	for r9: String in sub_rar:
		uhead.append(rname.call(r9))
	var urows: Array = []
	for id3: String in (c.D["SUB_RANGE"] as Dictionary).keys():
		var dec2 := _is_dec(c, id3)
		var base_rg: Array = c.D["SUB_RANGE"][id3]
		var urow: Array = [_fx_txt(tfn, id3, _range_txt(float(base_rg[0]), float(base_rg[1]), dec2))]
		for r10: String in sub_rar:
			var sr := sub_range(c, id3, r10)
			urow.append(_range_txt(float(sr[0]), float(sr[1]), dec2))
		urows.append(urow)
	var cnts: Array = []
	for r11: String in sub_rar:
		cnts.append("%s %d" % [rname.call(r11), int(c.D["SUB_COUNT"][r11])])
	var SP: Dictionary = c.D["SUB_POOL"]
	out.append({"id": "stat_sub", "title": tfn.call("gd.odds.statsub_title", {}), "head": uhead, "rows": urows, "cw": [2.4, 1, 1, 1, 1],
		"notes": [tfn.call("gd.odds.statsub_note", {"cnt": " · ".join(cnts), "w": (SP["weapon"] as Array).size(), "o": (SP["offhand"] as Array).size(),
			"a": (SP["armor"] as Array).size(), "x": (SP["acc"] as Array).size(), "d": SUB_MUL_DIV})]})
	return out


## 화면·글 공용 표 — [{id, title, notes:[글], head:[글], rows:[[글]]}] (tfn = 번역 (key, params) -> String)
static func sections(c: Object, tfn: Callable) -> Array:
	var out: Array = []
	var g := gacha(c)
	var grows: Array = []
	var last: Array = g["multi_last"]
	for i in (g["rows"] as Array).size():
		var r: Dictionary = g["rows"][i]
		grows.append([tfn.call("equip.rarity." + str(r["rarity"]), {}), pct(float(r["rate"])), pct(float(last[i]["rate"])) if float(last[i]["rate"]) > 0.0 else "-"])
	var lsum := 0.0
	for x: Dictionary in last:
		lsum += float(x["rate"])
	grows.append([tfn.call("gd.odds.sum", {}), pct(float(g["sum"])), pct(lsum)])
	out.append({"id": "gacha", "title": tfn.call("gd.odds.gacha_title", {"c1": Js.round_js(float(g["cost1"])), "c10": Js.round_js(float(g["cost10"]))}),
		"head": [tfn.call("gd.odds.col_rarity", {}), tfn.call("gd.odds.col_rate", {}), tfn.call("gd.odds.col_multi_last", {"n": g["multi_count"]})],
		"rows": grows,
		"notes": [tfn.call("gd.odds.gacha_pity", {"n": g["pity"]}), tfn.call("gd.odds.gacha_multi", {"n": g["multi_count"], "r": tfn.call("equip.rarity." + str(g["multi_min"]), {})}),
			tfn.call("gd.odds.gacha_kinds", {"n": g["kinds"], "m": g["legends"]})]})
	var ru := rune(c)
	var rrows: Array = []
	for r2: Dictionary in ru["rows"]:
		rrows.append([tfn.call("enchant.rune_name", {"e": tfn.call("enchant." + str(r2["kind"]), {})}), pct(float(r2["rate"]))])
	rrows.append([tfn.call("gd.odds.sum", {}), pct(float(ru["sum"]))])
	out.append({"id": "rune", "title": tfn.call("gd.odds.rune_title", {"gold": Js.round_js(float(ru["cost"]))}),
		"head": [tfn.call("gd.odds.col_rune", {}), tfn.call("gd.odds.col_rate", {})], "rows": rrows,
		"notes": [tfn.call("gd.odds.rune_note", {"n": (ru["rows"] as Array).size()})]})
	var e := enhance(c)
	var erows: Array = []
	for r3: Dictionary in e["rows"]:
		erows.append(["+%d → +%d" % [int(r3["from"]), int(r3["to"])], pct(float(r3["success"])), pct(float(r3["fail"])),
			tfn.call("gd.odds.drop" if bool(r3["drop"]) else "gd.odds.keep", {}), pct(float(r3["break"])), pct(float(r3["opt"]))])
	out.append({"id": "enhance", "title": tfn.call("gd.odds.enh_title", {}),
		"head": [tfn.call("gd.odds.col_step", {}), tfn.call("gd.odds.col_success", {}), tfn.call("gd.odds.col_fail", {}), tfn.call("gd.odds.col_on_fail", {}),
			tfn.call("gd.odds.col_break", {}), tfn.call("gd.odds.col_opt", {})],
		"rows": erows,
		"notes": [tfn.call("gd.odds.enh_bonus", {"n": Js.round_js(float(e["bonus"])), "max": Js.round_js(float(e["bonus_max"]))}),
			tfn.call("gd.odds.enh_break", {"p": pct(float(e["break_on_fail"]))}), tfn.call("gd.odds.enh_drop", {"n": e["safe_below"]}),
			tfn.call("gd.odds.enh_opt", {})]})
	out.append_array(detail_sections(c, tfn))
	return out
