extends RefCounted
## 확률 정보 (결제층 A) — 장비 뽑기 · 마법부여 룬 뽑기 · 장비 강화. 화면 코드 없이 정적 함수, 첫 인자 c = ctx.gd (D)
##  숫자는 모두 게임 데이터(GACHA_RATE · GACHA_PITY_MAX · GACHA_MULTI_COUNT · RARITY · EQUIP_DB · LEGENDS · ENCHANTS · RUNE_GACHA_COST ·
##  ENHANCE_RATES · ENHANCE_BREAK_CHANCE · ENHANCE_SAFE_BELOW · ENHANCE_FAIL_BONUS(_MAX) · ENHANCE_OPT · ENHANCE_MAX_LV)에서 계산한다.
##  손으로 적은 숫자 없음 — 규칙(gear.gd roll_rarity · gacha_pull · rune_random, equip_rules.gd enhance_item)과 같은 식.
##  같은 표를 게임 안 창(scripts/ui/odds_view.gd)과 스토어 설명용 글(tools/odds_export.gd → docs/store/probabilities.<언어>.md)이 쓴다.

const Js := preload("res://scripts/logic/js.gd")


## 비율(0~1) → "60%" · "4.5%" · "0.05%" · "8.333%" (퍼센트 소수 셋째 자리에서 반올림, 끝의 0 지움)
static func pct(rate: float) -> String:
	var p := snappedf(rate * 100.0, 0.001)
	var s := String.num(p, 3)
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
	return out
