extends RefCounted
## 장비 규칙 — 웹 js/logic/gear.js 의 Gear(옵션 굴리기·전설·세트·효과 합산) + js/logic/equip.js 의 생성·뽑기·장착 보너스 + hazards.js Rune
##  전투 중 장비 효과(GearFX)는 scripts/logic/battle/gear_fx.gd. 정적 함수, 첫 인자 c = ctx.gd
##  난수 호출 순서는 웹과 같다 (보물상자 장비 = gachaPull 전체 과정이 전투 난수 열을 밀어냄)

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")


static func _rnd(c: Object, r: Array, dec: bool) -> float:
	var v: float = r[0] + c.rand("_rnd") * (r[1] - r[0])
	return Js.round_js(v * 100.0) / 100.0 if dec else Js.round_js(v)


static func _is_dec(c: Object, id: String) -> bool:
	var fx: Dictionary = c.D["GEAR_FX"]
	return fx.has(id) and fx[id].get("u") == "dec"


static func _pick_w(c: Object, list: Array) -> Dictionary:
	var tot := 0.0
	for o: Dictionary in list:
		tot += float(o["w"]) if Js.truthy(o.get("w")) else 1.0
	var r: float = c.rand("_pickW") * tot
	for o2: Dictionary in list:
		r -= float(o2["w"]) if Js.truthy(o2.get("w")) else 1.0
		if r <= 0.0:
			return o2
	return list[list.size() - 1]


static func equip_template(c: Object, base_id: String) -> Variant:
	for d: Dictionary in c.D["EQUIP_DB"]:
		if d["baseId"] == base_id:
			return d
	return null


## equip.js genEid — Date.now() 와 난수 1회 (값은 저장 식별자일 뿐)
static func gen_eid(c: Object) -> String:
	c.eid_counter += 1
	var r: float = c.rand("genEid")
	return "eq_" + Js.base36(int(c.date_now())) + "_" + Js.base36(c.eid_counter) + "_" + Js.base36(int(r * 1679616.0))


static func roll_rarity(c: Object, min_rarity: Variant) -> String:
	var RAR: Dictionary = c.D["RARITY"]
	var min_tier: float = float(RAR[min_rarity]["tier"]) if Js.truthy(min_rarity) else 0.0
	var pool: Dictionary = {}
	var total := 0.0
	var rate: Dictionary = c.D["GACHA_RATE"]
	for r: String in rate.keys():
		if float(RAR[r]["tier"]) >= min_tier:
			pool[r] = rate[r]
			total += float(rate[r])
	var roll: float = c.rand("rollRarity") * total
	for r2: String in pool.keys():
		roll -= float(pool[r2])
		if roll <= 0.0:
			return r2
	return "common"


## equip.js generateEquip
static func generate_equip(c: Object, template: Dictionary, rarity: String, opts: Dictionary = {}) -> Dictionary:
	var mult: float = c.D["RARITY_MULT"][rarity]
	var rolled: Dictionary = {}
	var stats: Dictionary = template["stats"]
	for stat: String in stats.keys():
		var rg: Array = stats[stat]
		var base: float = rg[1] if Js.truthy(opts.get("maxRoll")) else rg[0] + c.rand("generateEquip") * (rg[1] - rg[0])
		rolled[stat] = Js.round_js(base * mult)
		if rolled[stat] < 1.0:
			rolled[stat] = 1.0
	var cls: Array
	if template.get("clsRestrict") != null:
		cls = (template["clsRestrict"] as Array).duplicate()
	elif Js.truthy(template.get("armorType")):
		cls = (c.D["ARMOR_TYPE"][template["armorType"]] as Array).duplicate()
	else:
		cls = (c.D["ALL_CLASSES"] as Array).duplicate()
	var item := {
		"type": "equip",
		"eid": gen_eid(c),
		"templateId": template["baseId"],
		"rarity": rarity,
		"slot": template["slot"],
		"hand": template["hand"] if Js.truthy(template.get("hand")) else null,
		"armorType": template["armorType"] if Js.truthy(template.get("armorType")) else null,
		"clsRestrict": cls,
		"setId": template["setId"] if Js.truthy(template.get("setId")) else null,
		"stats": rolled,
		"equipped": null,
		"enhanceLv": 0,
		"enhanceBonus": 0,
		"subs": [], "cOpt": null, "fx": null, "legend": null, "eOpts": {}, "broken": false,
		"gv": 2,
	}
	if not Js.truthy(opts.get("bare")):
		roll(c, item)
	return item


## Gear.roll — 등급에 맞게 옵션 붙이기
static func roll(c: Object, it: Dictionary) -> Dictionary:
	var RAR: Dictionary = c.D["RARITY"]
	var tier: float = float(RAR[it["rarity"]]["tier"]) if RAR.has(it["rarity"]) else 0.0
	var rm: Variant = (c.D["RARITY_MULT"] as Dictionary).get(it["rarity"])
	var mul: float = (float(rm) if Js.truthy(rm) else 1.0) / 1.6
	it["subs"] = []
	it["cOpt"] = null
	it["fx"] = null
	var pool := _sub_pool(c, it)
	var nv: Variant = (c.D["SUB_COUNT"] as Dictionary).get(it["rarity"])
	var n: int = int(nv) if Js.truthy(nv) else 0
	var i := 0
	while i < n and not pool.is_empty():
		var id: String = pool[int(floorf(c.rand("Gear.roll") * pool.size()))]
		pool.erase(id)
		var v := _rnd(c, c.D["SUB_RANGE"][id], _is_dec(c, id)) * mul
		(it["subs"] as Array).append({"id": id, "v": Js.round_js(v * 100.0) / 100.0 if _is_dec(c, id) else maxf(1.0, Js.round_js(v))})
		i += 1
	if tier >= 2.0:
		it["cOpt"] = _roll_class_opt(c, it, mul)
	if tier >= 3.0 and not Js.truthy(it.get("legend")):
		var UP: Array = c.D["UNIQUE_POOL"]
		var u: Dictionary = UP[int(floorf(c.rand("Gear.roll") * UP.size()))]
		it["fx"] = {"id": u["id"], "v": Js.round_js(_rnd(c, u["r"], false) * (1.25 if tier >= 4.0 else 1.0))}
	return it


static func _sub_pool(c: Object, it: Dictionary) -> Array:
	var SP: Dictionary = c.D["SUB_POOL"]
	if it["slot"] == "weapon":
		return (SP["weapon"] as Array).duplicate()
	if it["slot"] == "offhand":
		return (SP["offhand"] as Array).duplicate()
	if (c.D["SET_SLOTS"] as Array).has(it["slot"]):
		var p: Array = (SP["armor"] as Array).duplicate()
		var extra: Variant = (c.D["SUB_ARMOR_EXTRA"] as Dictionary).get(it.get("armorType"))
		if extra != null:
			for k: String in extra:
				if not p.has(k):
					p.append(k)
		return p
	return (SP["acc"] as Array).duplicate()


static func _roll_class_opt(c: Object, it: Dictionary, mul: float) -> Dictionary:
	var CO: Dictionary = c.D["CLASS_OPTS"]
	var classes: Array = []
	for cc: Variant in (it["clsRestrict"] if it.get("clsRestrict") != null else []):
		if CO.has(cc):
			classes.append(cc)
	if classes.is_empty():
		classes = CO.keys()
	var cls: String = classes[int(floorf(c.rand("_rollClassOpt") * classes.size()))]
	var o := _pick_w(c, CO[cls])
	var v := _rnd(c, o["r"], _is_dec(c, o["id"]))
	var fx: Dictionary = c.D["GEAR_FX"]
	if fx.has(o["id"]) and not Js.truthy(fx[o["id"]].get("noScale")):
		v = Js.round_js(v * mul * 100.0) / 100.0 if _is_dec(c, o["id"]) else maxf(1.0, Js.round_js(v * mul))
	return {"cls": cls, "id": o["id"], "v": v}


## Gear.makeLegend — 아직 없는 전설 우선 (id 를 주면 그 전설)
static func make_legend(c: Object, id: Variant = null) -> Dictionary:
	var LG: Dictionary = c.D["LEGENDS"]
	if not Js.truthy(id):
		var owned: Dictionary = {}
		var inv: Variant = c.store.get_json(Profile.INVENTORY_KEY)
		if typeof(inv) == TYPE_ARRAY:
			for x: Variant in inv:
				if typeof(x) == TYPE_DICTIONARY and Js.truthy(x.get("legend")):
					owned[x["legend"]] = 1
		var ids: Array = LG.keys()
		var fresh: Array = []
		for k: String in ids:
			if not owned.has(k):
				fresh.append(k)
		var pool: Array = fresh if not fresh.is_empty() else ids
		id = pool[int(floorf(c.rand("makeLegend") * pool.size()))]
	var L: Dictionary = LG[id]
	var tpl: Dictionary = equip_template(c, L["tpl"])
	var it := generate_equip(c, tpl, "legendary", {"maxRoll": true, "bare": true})
	it["legend"] = id
	it["setId"] = null
	roll(c, it)
	return it


## Gear.makeSetPiece
static func make_set_piece(c: Object, cls: String, slot: Variant, rarity: Variant) -> Dictionary:
	var SS: Array = c.D["SET_SLOTS"]
	if not Js.truthy(slot):
		slot = SS[int(floorf(c.rand("makeSetPiece") * SS.size()))]
	var at: Variant = (c.D["CLASS_ARMOR"] as Dictionary).get(cls)
	var type: String = at if Js.truthy(at) else "leather"
	var base: Variant = null
	for d: Dictionary in c.D["EQUIP_DB"]:
		if d["slot"] == slot and d.get("armorType") == type:
			base = d
			break
	var it := generate_equip(c, base, rarity if Js.truthy(rarity) else "rare", {"bare": true})
	it["clsRestrict"] = [cls]
	it["setId"] = "cls_" + cls
	it["setCls"] = cls
	roll(c, it)
	if Js.truthy(it.get("cOpt")):
		it["cOpt"]["cls"] = cls
	return it


static func give(c: Object, item: Dictionary) -> Dictionary:
	var inv := Profile.load_inventory(c)
	inv.append(item)
	Profile.save_inventory(c, inv)
	return item


## equip.js gachaPull
static func gacha_pull(c: Object, min_rarity: Variant, skip_pity: bool) -> Dictionary:
	var pity := Profile.load_pity(c)
	var rarity: String
	if not skip_pity and pity + 1 >= int(c.D["GACHA_PITY_MAX"]):
		rarity = "legendary"
	else:
		rarity = roll_rarity(c, min_rarity if Js.truthy(min_rarity) else null)
	if not skip_pity:
		Profile.save_pity(c, 0 if rarity == "legendary" else pity + 1)
	if rarity == "legendary":
		return make_legend(c)
	var DB: Array = c.D["EQUIP_DB"]
	var tpl: Dictionary = DB[int(floorf(c.rand("gachaPull") * DB.size()))]
	return generate_equip(c, tpl, rarity)


static func get_enhance_multiplier(c: Object, lvl: Variant) -> float:
	var mx: int = int(c.D["ENHANCE_MAX_LV"])
	var i: int = clampi(int(Js.num(lvl)), 0, mx)
	var v: Variant = (c.D["ENHANCE_STAT_PCT"] as Array)[i]
	return Js.num(v) / 100.0


static func get_enhanced_stats(c: Object, item: Dictionary) -> Dictionary:
	if not Js.truthy(item.get("enhanceLv")):
		return item["stats"]
	var mult := 1.0 + get_enhance_multiplier(c, item["enhanceLv"])
	var out: Dictionary = {}
	for stat: String in item["stats"].keys():
		out[stat] = Js.round_js(float(item["stats"][stat]) * mult)
	return out


## Gear.effects — 이 장비가 cls 에게 주는 효과 [{id, v}]
static func effects(c: Object, it: Variant, cls: Variant) -> Array:
	if it == null or Js.truthy(it.get("broken")):
		return []
	var out: Array = []
	var lv: float = Js.num(it.get("enhanceLv"))
	var s_mul := 1.0 + get_enhance_multiplier(c, lv)
	var fx_mul := 1.5 if lv >= 10.0 else (1.25 if lv >= 5.0 else 1.0)
	var GF: Dictionary = c.D["GEAR_FX"]
	var push := func(id: String, v: float, m: float) -> void:
		var d: Dictionary = GF.get(id, {})
		if m != 0.0 and not Js.truthy(d.get("noScale")):
			v = Js.round_js(v * m * 100.0) / 100.0 if _is_dec(c, id) else Js.round_js(v * m)
		out.append({"id": id, "v": v})
	for s: Dictionary in (it.get("subs") if it.get("subs") != null else []):
		push.call(s["id"], float(s["v"]), s_mul)
	if Js.truthy(it.get("cOpt")) and (not Js.truthy(cls) or it["cOpt"]["cls"] == cls):
		push.call(it["cOpt"]["id"], float(it["cOpt"]["v"]), 2.0 if lv >= 10.0 else 1.0)
	if Js.truthy(it.get("fx")):
		push.call(it["fx"]["id"], float(it["fx"]["v"]), fx_mul)
	var LG: Dictionary = c.D["LEGENDS"]
	if Js.truthy(it.get("legend")) and LG.has(it["legend"]):
		var f: Dictionary = LG[it["legend"]]["fx"]
		for k: String in f.keys():
			push.call(k, float(f[k]), fx_mul)
	var eo: Dictionary = it["eOpts"] if typeof(it.get("eOpts")) == TYPE_DICTIONARY else {}
	for k2: String in eo.keys():
		if Js.truthy(eo[k2]):
			push.call(eo[k2]["id"], float(eo[k2]["v"]), fx_mul if Js.truthy(eo[k2].get("uq")) else 1.0)
	return out


static func set_effects(c: Object, cls: String, count: int) -> Array:
	var s: Variant = (c.D["CLASS_SETS"] as Dictionary).get(cls)
	var out: Array = []
	if s == null:
		return out
	for n: int in [2, 3]:
		var key := str(n)
		if count >= n and Js.truthy(s.get(key)):
			for k: String in s[key].keys():
				out.append({"id": k, "v": float(s[key][k])})
	return out


## equip.js calcEquipBonus → { hp, atk, def, move, range, gear: {효과: 값}, fullSet }
static func calc_equip_bonus(c: Object, ch: Dictionary) -> Dictionary:
	var bonus := {"hp": 0.0, "atk": 0.0, "def": 0.0, "move": 0.0, "range": 0.0, "gear": {}, "fullSet": null}
	if not Js.truthy(ch.get("equip")):
		return bonus
	var inv := Profile.load_inventory(c)
	var inv_map: Dictionary = {}
	for x: Variant in inv:
		if typeof(x) == TYPE_DICTIONARY and x.get("type") == "equip":
			inv_map[str(x["eid"])] = x
	var set_counts: Dictionary = {}
	var pct := {"hp": 0.0, "atk": 0.0, "def": 0.0}
	var add := func(k: String, v: float) -> void:
		if k == "hp_pct" or k == "atk_pct" or k == "def_pct":
			pct[k.substr(0, k.length() - 4)] += v
		elif k == "move" or k == "range":
			bonus[k] += v
		else:
			bonus["gear"][k] = Js.num(bonus["gear"].get(k)) + v
	for slot: String in c.D["EQUIP_SLOTS"]:
		var eid: Variant = ch["equip"].get(slot)
		if not Js.truthy(eid):
			continue
		var item: Variant = inv_map.get(str(eid))
		if item == null or Js.truthy(item.get("broken")):
			continue
		var es := get_enhanced_stats(c, item)
		for stat: String in es.keys():
			if bonus.has(stat) and stat != "gear" and stat != "fullSet":
				bonus[stat] += float(es[stat])
		for e: Dictionary in effects(c, item, ch["cls"]):
			add.call(e["id"], float(e["v"]))
		if Js.truthy(item.get("setId")):
			set_counts[item["setId"]] = int(set_counts.get(item["setId"], 0)) + 1
	for set_id: String in set_counts.keys():
		var count: int = set_counts[set_id]
		if set_id.begins_with("cls_"):
			var cls := set_id.substr(4)
			if cls != ch["cls"]:
				continue
			for e2: Dictionary in set_effects(c, cls, count):
				add.call(e2["id"], float(e2["v"]))
			if count >= 3:
				bonus["fullSet"] = cls
			continue
		var set_def: Variant = (c.D["EQUIP_SETS"] as Dictionary).get(set_id)
		if set_def == null:
			continue
		for th: int in [3, 2]:
			if count >= th and Js.truthy(set_def.get(str(th))):
				var sb: Dictionary = set_def[str(th)]
				for sk: String in sb.keys():
					if bonus.has(sk) and sk != "gear" and sk != "fullSet":
						bonus[sk] += float(sb[sk])
				break
	for k3: String in ["hp", "atk", "def"]:
		if pct[k3] != 0.0:
			bonus[k3] += Js.round_js((Js.num(ch.get(k3)) + bonus[k3]) * pct[k3] / 100.0)
	return bonus


# ── 마법부여 룬 (hazards.js Rune) ──

static func rune_kinds(c: Object, cat: Variant = null) -> Array:
	var out: Array = []
	var EN: Dictionary = c.D["ENCHANTS"]
	for k: String in EN.keys():
		if not Js.truthy(cat) or EN[k]["cat"] == cat:
			out.append(k)
	return out


static func rune_random(c: Object) -> String:
	var k := rune_kinds(c)
	return k[int(floorf(c.rand("Rune.random") * k.size()))]


static func rune_add(c: Object, kind: String) -> String:
	var inv := Profile.load_inventory(c)
	inv.append({"type": "rune", "enchant": kind, "rid": c.date_now() + c.rand("Rune.add")})
	Profile.save_inventory(c, inv)
	return kind
