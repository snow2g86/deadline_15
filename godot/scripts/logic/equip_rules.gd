extends RefCounted
## 편성 화면의 장비·소모품·강화 규칙 (4b-1) — 웹 js/party-select.js(장비 탭·아이템 탭·강화 탭) + js/logic/equip.js(강화·수리·분해·Mats)
##  + js/logic/gear.js 표시(Gear.name·fmt·lines). 화면 코드 없이 정적 함수, 첫 인자 c = ctx.gd (store 는 진짜 Store 또는 메모리).
##  저장 형식은 웹과 같다: game_roster(ch.equip{슬롯: eid}) · game_inventory(item.equipped = uid|null) · game_mats{stone,protect,shard} · game_save.gold
##  난수 순서도 웹과 같다 (enhanceItem: 성공 판정 → 강화 옵션 / 실패면 보호 주문서가 없을 때만 파손 판정).
##  웹은 화면 함수(renderChars·renderInventoryInModal·renderEnhanceList·renderItemTab) 안에 규칙이 섞여 있어, 그 정렬·거르기·단추 조건을 여기로 옮겼다.
##  표시 글을 만드는 함수는 tfn(키, {자리표시자}) -> String 을 받는다 (I18n.t 또는 시험의 가짜 t).

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const Gear := preload("res://scripts/logic/gear.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")
const Num := preload("res://scripts/core/num.gd")

## 웹 party-select.js POTION_INFO (경험치 물약 이름 키·아이콘) — 웹 정답 파일과 같은지 시험이 확인
const POTION_INFO := {"exp_s": {"nameKey": "shop.potion_small", "icon": "🧪"}, "exp_m": {"nameKey": "shop.potion_medium", "icon": "⚗️"},
	"exp_l": {"nameKey": "shop.potion_large", "icon": "🏐"}}
const POTION_ORDER := ["exp_s", "exp_m", "exp_l"]
const INV_FILTERS := ["all", "weapon", "armor", "accessory"]


# ── 골드 · 재료 ──

## storage.js loadGold (d.gold || 0)
static func load_gold(c: Object) -> float:
	return Js.num(Profile.load_save(c).get("gold"))


## equip.js Mats.get (없거나 숫자가 아니면 0)
static func mats_get(c: Object, k: String) -> float:
	var m: Variant = c.store.get_json(Profile.MATS_KEY)
	if typeof(m) != TYPE_DICTIONARY:
		return 0.0
	return Js.num(m.get(k))


static func mats_add(c: Object, k: String, n: float) -> float:
	return Profile.mats_add(c, k, n)


# ── 조회 ──

static func ensure_equip_slots(c: Object, ch: Dictionary) -> Dictionary:
	if not Js.truthy(ch.get("equip")) or typeof(ch.get("equip")) != TYPE_DICTIONARY:
		var e: Dictionary = {}
		for s: String in c.D["EQUIP_SLOTS"]:
			e[s] = null
		ch["equip"] = e
	return ch


static func find_item(inv: Array, eid: Variant) -> Variant:
	if eid == null:
		return null
	for x: Variant in inv:
		if typeof(x) == TYPE_DICTIONARY and Js.same(x.get("eid"), eid):
			return x
	return null


## 장비만 eid → 물건 (웹 invMap)
static func inv_map(inv: Array) -> Dictionary:
	var m: Dictionary = {}
	for x: Variant in inv:
		if typeof(x) == TYPE_DICTIONARY and x.get("type") == "equip":
			m[str(x.get("eid"))] = x
	return m


static func tier_of(c: Object, item: Dictionary) -> float:
	var r: Variant = (c.D["RARITY"] as Dictionary).get(item.get("rarity"))
	return float(r["tier"]) if r is Dictionary else 0.0


static func rarity_color(c: Object, item: Variant) -> String:
	var r: Variant = (c.D["RARITY"] as Dictionary).get(item.get("rarity") if item is Dictionary else null)
	return str(r["color"]) if r is Dictionary else "#9ca3af"


static func is_member(c: Object, ch: Variant) -> bool:
	return ch is Dictionary and typeof(ch.get("cls")) == TYPE_STRING and not Js.truthy(ch.get("dead")) \
		and not str(ch["cls"]).begins_with("summon_") and ch["cls"] != c.D["COMMANDER_CLS"]


## party-select.js canEquip
static func can_equip(c: Object, ch: Variant, item: Variant, inv: Variant = null) -> bool:
	if not (ch is Dictionary) or not (item is Dictionary) or Js.truthy(item.get("broken")):
		return false
	var cr: Variant = item.get("clsRestrict")
	if Js.truthy(cr) and cr is Array and Js.index_of(cr, ch.get("cls")) == -1:
		return false
	if item.get("slot") == "offhand":
		ensure_equip_slots(c, ch)
		var w_eid: Variant = ch["equip"].get("weapon")
		if Js.truthy(w_eid):
			var list: Array = inv if inv is Array else Profile.load_inventory(c)
			var w: Variant = find_item(list, w_eid)
			if w != null and w.get("hand") == "2h":
				return false
	return true


# ── 장착 · 해제 · 판매 ──

static func _find_char(roster: Dictionary, uid: Variant) -> Variant:
	for ch: Variant in roster["chars"]:
		if typeof(ch) == TYPE_DICTIONARY and Js.same(ch.get("uid"), uid):
			return ch
	return null


## party-select.js equipItem → 했으면 true
static func equip_item(c: Object, uid: Variant, eid: Variant) -> bool:
	var roster := Profile.get_roster(c)
	var ch: Variant = _find_char(roster, uid)
	if ch == null:
		return false
	ensure_equip_slots(c, ch)
	var inv := Profile.load_inventory(c)
	var item: Variant = find_item(inv, eid)
	if item == null:
		return false
	var slot := str(item.get("slot"))
	if item.get("equipped") != null and not Js.same(item.get("equipped"), uid):
		var other: Variant = _find_char(roster, item["equipped"])
		if other != null:
			ensure_equip_slots(c, other)
			for s: String in c.D["EQUIP_SLOTS"]:
				if Js.same(other["equip"].get(s), eid):
					other["equip"][s] = null
					break
	var old_eid: Variant = ch["equip"].get(slot)
	if Js.truthy(old_eid):
		var old: Variant = find_item(inv, old_eid)
		if old != null:
			old["equipped"] = null
	if slot == "weapon" and item.get("hand") == "2h":
		var oh: Variant = ch["equip"].get("offhand")
		if Js.truthy(oh):
			var oi: Variant = find_item(inv, oh)
			if oi != null:
				oi["equipped"] = null
		ch["equip"]["offhand"] = null
	ch["equip"][slot] = item["eid"]
	item["equipped"] = ch["uid"]
	Profile.save_roster(c, roster)
	Profile.save_inventory(c, inv)
	return true


## party-select.js unequipItem
static func unequip_item(c: Object, uid: Variant, slot: String) -> bool:
	var roster := Profile.get_roster(c)
	var ch: Variant = _find_char(roster, uid)
	if ch == null:
		return false
	ensure_equip_slots(c, ch)
	var eid: Variant = ch["equip"].get(slot)
	if not Js.truthy(eid):
		return false
	var inv := Profile.load_inventory(c)
	var item: Variant = find_item(inv, eid)
	if item != null:
		item["equipped"] = null
	ch["equip"][slot] = null
	Profile.save_roster(c, roster)
	Profile.save_inventory(c, inv)
	return true


static func sell_price(c: Object, item: Dictionary) -> float:
	var p: Variant = (c.D["SELL_PRICE"] as Dictionary).get(item.get("rarity"))
	return float(p) if Js.truthy(p) else 30.0


## party-select.js sellEquip (확인 창 '확인' 뒤의 일) → 판 값 (못 팔면 -1). 장착 중이면 팔지 않음
static func sell_equip(c: Object, eid: Variant) -> float:
	var inv := Profile.load_inventory(c)
	var item: Variant = find_item(inv, eid)
	if item == null or Js.truthy(item.get("equipped")):
		return -1.0
	var price := sell_price(c, item)
	var left: Array = []
	for x: Variant in inv:
		if not (typeof(x) == TYPE_DICTIONARY and Js.same(x.get("eid"), eid)):
			left.append(x)
	Profile.save_inventory(c, left)
	Profile.save_gold(c, load_gold(c) + price)
	return price


# ── 강화 · 수리 · 분해 (equip.js) ──

static func enhance_lv(item: Dictionary) -> float:
	return Js.num(item.get("enhanceLv"))


static func calc_enhance_cost(c: Object, item: Dictionary) -> float:
	var g: Variant = (c.D["ENHANCE_GOLD"] as Dictionary).get(item.get("rarity"))
	return (float(g) if Js.truthy(g) else 40.0) * (enhance_lv(item) + 1.0)


static func _arr_at(a: Array, lv: float) -> Variant:
	if lv != floorf(lv) or lv < 0.0 or lv >= float(a.size()):
		return null
	return a[int(lv)]


static func calc_enhance_stones(c: Object, item: Dictionary) -> float:
	var v: Variant = _arr_at(c.D["ENHANCE_STONES"], enhance_lv(item))
	return float(v) if Js.truthy(v) else 4.0


static func calc_enhance_rate(c: Object, item: Dictionary) -> float:
	var v: Variant = _arr_at(c.D["ENHANCE_RATES"], enhance_lv(item))
	return minf(1.0, Js.num(v) + Js.num(item.get("enhanceBonus")) / 100.0)


static func can_enhance(c: Object, item: Dictionary) -> bool:
	return not Js.truthy(item.get("broken")) and enhance_lv(item) < float(c.D["ENHANCE_MAX_LV"])


## equip.js unequipEverywhere — 모든 클랜원에게서 빼고 item.equipped = null
static func unequip_everywhere(c: Object, item: Dictionary) -> void:
	var roster := Profile.get_roster(c)
	var changed := false
	for ch: Variant in roster["chars"]:
		if typeof(ch) != TYPE_DICTIONARY or typeof(ch.get("equip")) != TYPE_DICTIONARY:
			continue
		for k: Variant in (ch["equip"] as Dictionary).keys():
			if Js.same(ch["equip"][k], item.get("eid")):
				ch["equip"][k] = null
				changed = true
	if changed:
		Profile.save_roster(c, roster)
	item["equipped"] = null


## equip.js enhanceItem → { err } 또는 { from, ok, opt, lv, dropped, broken, protected }
static func enhance_item(c: Object, eid: Variant, use_protect: bool) -> Dictionary:
	var inv := Profile.load_inventory(c)
	var it: Variant = find_item(inv, eid)
	if it == null or it.get("type") != "equip":
		return {"err": "invalid"}
	if not can_enhance(c, it):
		return {"err": "broken" if Js.truthy(it.get("broken")) else "max"}
	var gold := load_gold(c)
	var cost := calc_enhance_cost(c, it)
	var stones := calc_enhance_stones(c, it)
	if gold < cost:
		return {"err": "gold"}
	if mats_get(c, "stone") < stones:
		return {"err": "stone"}
	var protect := use_protect and mats_get(c, "protect") > 0.0
	Profile.save_gold(c, gold - cost)
	mats_add(c, "stone", -stones)
	if protect:
		mats_add(c, "protect", -1.0)
	var res: Dictionary = {"from": enhance_lv(it)}
	if c.rand("enhanceItem") < calc_enhance_rate(c, it):
		it["enhanceLv"] = enhance_lv(it) + 1.0
		it["enhanceBonus"] = 0.0
		var opt: Variant = Gear.roll_enhance_opt(c, it, int(it["enhanceLv"]))
		if opt != null:
			if typeof(it.get("eOpts")) != TYPE_DICTIONARY:
				it["eOpts"] = {}
			it["eOpts"][Num.fmt(it["enhanceLv"])] = opt
		res["ok"] = true
		res["opt"] = opt
	else:
		it["enhanceBonus"] = minf(float(c.D["ENHANCE_FAIL_BONUS_MAX"]), Js.num(it.get("enhanceBonus")) + float(c.D["ENHANCE_FAIL_BONUS"]))
		if not protect and c.rand("enhanceItem.break") < float(c.D["ENHANCE_BREAK_CHANCE"]):
			it["broken"] = true
			res["broken"] = true
			unequip_everywhere(c, it)
		elif enhance_lv(it) >= float(c.D["ENHANCE_SAFE_BELOW"]):
			if typeof(it.get("eOpts")) == TYPE_DICTIONARY:
				(it["eOpts"] as Dictionary).erase(Num.fmt(enhance_lv(it)))
			it["enhanceLv"] = enhance_lv(it) - 1.0
			res["dropped"] = true
		res["protected"] = protect
	res["lv"] = it.get("enhanceLv")
	Profile.save_inventory(c, inv)
	return res


static func repair_cost(c: Object, item: Dictionary) -> float:
	var v: Variant = (c.D["REPAIR_GOLD"] as Dictionary).get(item.get("rarity"))
	return float(v) if Js.truthy(v) else 100.0


## equip.js repairItem → { err } | { ok, cost }
static func repair_item(c: Object, eid: Variant) -> Dictionary:
	var inv := Profile.load_inventory(c)
	var it: Variant = find_item(inv, eid)
	if it == null or not Js.truthy(it.get("broken")):
		return {"err": "invalid"}
	var cost := repair_cost(c, it)
	var gold := load_gold(c)
	if gold < cost:
		return {"err": "gold"}
	Profile.save_gold(c, gold - cost)
	it["broken"] = false
	it["enhanceLv"] = 0.0
	it["eOpts"] = {}
	it["enhanceBonus"] = 0.0
	Profile.save_inventory(c, inv)
	return {"ok": true, "cost": cost}


static func dismantle_yield(c: Object, item: Dictionary) -> float:
	var v: Variant = (c.D["DISMANTLE_STONES"] as Dictionary).get(item.get("rarity"))
	return (float(v) if Js.truthy(v) else 1.0) + (0.0 if Js.truthy(item.get("broken")) else floorf(enhance_lv(item) / 2.0))


## equip.js dismantleItem → { err } | { ok, stones, shard }
static func dismantle_item(c: Object, eid: Variant) -> Dictionary:
	var inv := Profile.load_inventory(c)
	var it: Variant = find_item(inv, eid)
	if it == null or it.get("type") != "equip":
		return {"err": "invalid"}
	if Js.truthy(it.get("equipped")):
		unequip_everywhere(c, it)
	var n := dismantle_yield(c, it)
	var shard := 1.0 if Js.truthy(it.get("legend")) else 0.0
	mats_add(c, "stone", n)
	if shard > 0.0:
		mats_add(c, "shard", shard)
	var left: Array = []
	for x: Variant in inv:
		if not (typeof(x) == TYPE_DICTIONARY and Js.same(x.get("eid"), eid)):
			left.append(x)
	Profile.save_inventory(c, left)
	return {"ok": true, "stones": n, "shard": shard}


# ── 장비 탭 화면 모델 ──

## renderChars: 살아 있는 클랜원 (지휘관·소환수 빼고), 활성 파티원 먼저 → 레벨 높은 순, 그 뒤 필터 (all · group_*)
static func equip_chars(c: Object, filter: String) -> Array:
	var roster := Profile.get_roster(c)
	var alive: Array = []
	for ch: Variant in roster["chars"]:
		if is_member(c, ch):
			alive.append(ch)
	var party: Array = PartyRules.get_active_party(c)
	alive = Js.stable_sort(alive, func(a: Dictionary, b: Dictionary) -> float:
		var ai := 1.0 if Js.index_of(party, a.get("uid")) >= 0 else 0.0
		var bi := 1.0 if Js.index_of(party, b.get("uid")) >= 0 else 0.0
		if bi != ai:
			return bi - ai
		return Js.num(b.get("lv")) - Js.num(a.get("lv")))
	if filter.begins_with("group_"):
		var g := filter.substr(6)
		var out: Array = []
		for ch2: Dictionary in alive:
			if (c.D["CLASS_GROUP_MAP"] as Dictionary).get(ch2["cls"]) == g:
				out.append(ch2)
		alive = out
	elif filter.begins_with("cls_"):
		var cl := filter.substr(4)
		var out2: Array = []
		for ch3: Dictionary in alive:
			if ch3["cls"] == cl:
				out2.append(ch3)
		alive = out2
	return alive


static func in_active_party(c: Object, uid: Variant) -> bool:
	return Js.index_of(PartyRules.get_active_party(c), uid) >= 0


## 카드의 장비 8칸: [{slot, item|null, upgrade(더 높은 등급의 안 낀 장비가 있음)}]
static func card_slots(c: Object, ch: Dictionary, inv: Array) -> Array:
	ensure_equip_slots(c, ch)
	var m := inv_map(inv)
	var free: Array = []
	for it: Variant in inv:
		if typeof(it) == TYPE_DICTIONARY and it.get("type") == "equip" and not Js.truthy(it.get("equipped")):
			free.append(it)
	var out: Array = []
	for slot: String in c.D["EQUIP_SLOTS"]:
		var eid: Variant = ch["equip"].get(slot)
		var cur: Variant = m.get(str(eid)) if Js.truthy(eid) else null
		var up := false
		if cur != null:
			for it2: Dictionary in free:
				if it2.get("slot") == slot and can_equip(c, ch, it2, inv) and tier_of(c, it2) > tier_of(c, cur):
					up = true
					break
		out.append({"slot": slot, "item": cur, "upgrade": up})
	return out


## 장비 창 왼쪽 칸: [{slot, item|null, locked(두손 무기 때문에 보조 칸 막힘)}]
static func modal_slots(c: Object, ch: Dictionary, inv: Array) -> Array:
	ensure_equip_slots(c, ch)
	var m := inv_map(inv)
	var out: Array = []
	for slot: String in c.D["EQUIP_SLOTS"]:
		var eid: Variant = ch["equip"].get(slot)
		var item: Variant = m.get(str(eid)) if Js.truthy(eid) else null
		var locked := false
		if slot == "offhand":
			var w_eid: Variant = ch["equip"].get("weapon")
			var w: Variant = m.get(str(w_eid)) if Js.truthy(w_eid) else null
			if w != null and w.get("hand") == "2h":
				locked = true
		out.append({"slot": slot, "item": item, "locked": locked})
	return out


## 장착한 세트 수 (슬롯 순서대로 처음 나온 순) → [[setId, n]]
static func set_counts(c: Object, ch: Dictionary, inv: Array) -> Array:
	ensure_equip_slots(c, ch)
	var m := inv_map(inv)
	var order: Array = []
	var cnt: Dictionary = {}
	for slot: String in c.D["EQUIP_SLOTS"]:
		var eid: Variant = ch["equip"].get(slot)
		if not Js.truthy(eid):
			continue
		var it: Variant = m.get(str(eid))
		if it != null and Js.truthy(it.get("setId")):
			var sid := str(it["setId"])
			if not cnt.has(sid):
				cnt[sid] = 0
				order.append(sid)
			cnt[sid] += 1
	var out: Array = []
	for s: String in order:
		out.append([s, cnt[s]])
	return out


## renderInventoryInModal: 장비 목록 (필터 → 등급 높은 순 → 슬롯 순) + 단추
##  [{item, here, other, can, actions: [equip|unequip|sell|dismantle|repair]}]
static func modal_inventory(c: Object, ch: Dictionary, filter: String, inv: Array) -> Array:
	ensure_equip_slots(c, ch)
	var list: Array = []
	var groups := {"weapon": ["weapon", "offhand"], "armor": ["helmet", "armor", "boots"], "accessory": ["necklace", "earring", "ring"]}
	for it: Variant in inv:
		if typeof(it) != TYPE_DICTIONARY or it.get("type") != "equip":
			continue
		if groups.has(filter) and not (groups[filter] as Array).has(it.get("slot")):
			continue
		list.append(it)
	var slots: Array = c.D["EQUIP_SLOTS"]
	list = Js.stable_sort(list, func(a: Dictionary, b: Dictionary) -> float:
		var ra := tier_of(c, a)
		var rb := tier_of(c, b)
		if rb != ra:
			return rb - ra
		return float(slots.find(a.get("slot")) - slots.find(b.get("slot"))))
	var out: Array = []
	for item: Dictionary in list:
		var can := can_equip(c, ch, item, inv)
		var equipped := Js.truthy(item.get("equipped"))
		var here := false
		for s: String in slots:
			if Js.same(ch["equip"].get(s), item.get("eid")):
				here = true
				break
		var other := equipped and not here
		var acts: Array = []
		if Js.truthy(item.get("broken")):
			acts = ["repair", "dismantle"]
		elif here:
			acts = ["unequip"]
		else:
			if can and not other:
				acts.append("equip")
			if not equipped:
				acts.append_array(["sell", "dismantle"])
		out.append({"item": item, "here": here, "other": other, "can": can, "actions": acts})
	return out


# ── 강화 탭 ──

## renderEnhanceList: 등급 높은 순 → 강화 단계 높은 순 → 장착 중 먼저, 파손은 따로 → {ok: [], broken: []}
static func enhance_list(c: Object) -> Dictionary:
	var inv := Profile.load_inventory(c)
	var eq: Array = []
	for x: Variant in inv:
		if typeof(x) == TYPE_DICTIONARY and x.get("type") == "equip":
			eq.append(x)
	eq = Js.stable_sort(eq, func(a: Dictionary, b: Dictionary) -> float:
		var d := tier_of(c, b) - tier_of(c, a)
		if d != 0.0:
			return d
		d = enhance_lv(b) - enhance_lv(a)
		if d != 0.0:
			return d
		return (1.0 if Js.truthy(b.get("equipped")) else 0.0) - (1.0 if Js.truthy(a.get("equipped")) else 0.0))
	var ok: Array = []
	var broken: Array = []
	for it: Dictionary in eq:
		if Js.truthy(it.get("broken")):
			broken.append(it)
		else:
			ok.append(it)
	return {"ok": ok, "broken": broken}


## 강화 확인 창 (showEnhanceConfirmModal 의 숫자): { lv, max, rate, rp, cost, stones, have_stone, have_protect, gain:[[stat, cur, next]], band_pct|-1, milestone(0|5|10), fail_keep, bonus }
static func enhance_preview(c: Object, item: Dictionary) -> Dictionary:
	var lv := enhance_lv(item)
	var rate := calc_enhance_rate(c, item)
	var cur := Gear.get_enhanced_stats(c, item)
	var nm := 1.0 + Gear.get_enhance_multiplier(c, lv + 1.0)
	var gain: Array = []
	var stats: Dictionary = item.get("stats", {}) if item.get("stats") is Dictionary else {}
	for st: String in stats.keys():
		var nx := Js.round_js(Js.num(stats[st]) * nm)
		if nx > Js.num(cur.get(st)):
			gain.append([st, Js.num(cur.get(st)), nx])
	var band_pct := -1.0
	for b: Dictionary in c.D["ENHANCE_OPT"]:
		if lv + 1.0 <= float(b["upTo"]):
			band_pct = Js.round_js(float(b["chance"]) * 100.0)
			break
	return {"lv": lv, "max": lv >= float(c.D["ENHANCE_MAX_LV"]), "rate": rate, "rp": Js.round_js(rate * 100.0), "cost": calc_enhance_cost(c, item),
		"stones": calc_enhance_stones(c, item), "have_stone": mats_get(c, "stone"), "have_protect": mats_get(c, "protect"), "gain": gain,
		"band_pct": band_pct, "milestone": int(lv + 1.0) if (lv + 1.0 == 5.0 or lv + 1.0 == 10.0) else 0,
		"fail_keep": lv < float(c.D["ENHANCE_SAFE_BELOW"]), "bonus": Js.num(item.get("enhanceBonus"))}


# ── 아이템 탭 (경험치 물약 · 공성 아이템) ──

## renderItemTab: { potions: [{potionId, exp, icon, count}] (exp_s·m·l 순, 그 밖의 id 는 웹처럼 안 보임), sieges: [{siegeId, icon, count}] (처음 나온 순) }
static func item_tab(c: Object) -> Dictionary:
	var inv := Profile.load_inventory(c)
	var groups: Dictionary = {}
	var sg: Dictionary = {}
	var s_order: Array = []
	for it: Variant in inv:
		if typeof(it) != TYPE_DICTIONARY:
			continue
		if it.get("type") == "potion":
			var id := str(it.get("potionId"))
			if not groups.has(id):
				groups[id] = {"potionId": id, "exp": it.get("exp"), "icon": it.get("icon"), "count": 0}
			groups[id]["count"] += 1
		elif it.get("type") == "siege":
			var sid := str(it.get("siegeId"))
			if not sg.has(sid):
				var icon: Variant = "⚙️"
				for sd: Dictionary in c.D["SIEGE_ITEMS"]:
					if sd["id"] == sid:
						icon = sd["icon"]
				sg[sid] = {"siegeId": sid, "icon": icon, "count": 0}
				s_order.append(sid)
			sg[sid]["count"] += 1
	var pots: Array = []
	for pid: String in POTION_ORDER:
		if groups.has(pid):
			pots.append(groups[pid])
	var sieges: Array = []
	for s: String in s_order:
		sieges.append(sg[s])
	return {"potions": pots, "sieges": sieges, "has_any": not groups.is_empty() or not s_order.is_empty()}


## showPotionUseModal 의 대상: 살아 있는 클랜원 중 레벨 상한 미만 (로스터 순)
static func potion_targets(c: Object) -> Array:
	var out: Array = []
	for ch: Variant in Profile.get_roster(c)["chars"]:
		if is_member(c, ch) and Js.num(ch.get("lv")) < Profile.max_level_of(c, ch):
			out.append(ch)
	return out


## 물약 하나 쓰기 (.pt-btn 누름) → { ok, exp, leveled, prevLv, lv } — 그 id 의 첫 물약을 빼고 경험치
static func use_potion(c: Object, potion_id: String, uid: Variant) -> Dictionary:
	var inv := Profile.load_inventory(c)
	var idx := -1
	for i in inv.size():
		if typeof(inv[i]) == TYPE_DICTIONARY and inv[i].get("type") == "potion" and inv[i].get("potionId") == potion_id:
			idx = i
			break
	if idx == -1:
		return {"ok": false}
	var used: Dictionary = inv[idx]
	inv.remove_at(idx)
	Profile.save_inventory(c, inv)
	var r := Profile.gain_exp(c, uid, Js.num(used.get("exp")))
	var ch: Variant = Profile.get_char(c, uid)
	return {"ok": true, "exp": used.get("exp"), "leveled": int(r["leveled"]), "prevLv": r["prevLv"], "lv": ch.get("lv") if ch != null else null}


# ── 표시 (Gear.name · fmt · lines) ──

## JS (+v).toFixed(n) 글
static func fixed_str(v: float, n: int) -> String:
	var f := Js.to_fixed_num(v, n)
	var s := Num.fmt(absf(f))
	if n > 0:
		if not s.contains("."):
			s += "."
		while s.length() - s.find(".") - 1 < n:
			s += "0"
	return ("-" if f < 0.0 else "") + s


static func gear_name(it: Variant, tfn: Callable) -> String:
	if not (it is Dictionary):
		return ""
	if Js.truthy(it.get("legend")):
		return tfn.call("gear.legend." + str(it["legend"]), {})
	if Js.truthy(it.get("setCls")):
		return tfn.call("gear.set_piece", {"set": tfn.call("gear.set." + str(it["setCls"]), {}), "slot": tfn.call("equip.slot." + str(it.get("slot")), {})})
	var k := "gear.item." + str(it.get("templateId"))
	var v: String = tfn.call(k, {})
	return v if v != "" and v != k else tfn.call("equip.item." + str(it.get("templateId")), {})


static func fmt(c: Object, id: String, v: Variant, tfn: Callable) -> String:
	var d: Dictionary = (c.D["GEAR_FX"] as Dictionary).get(id, {})
	var val := fixed_str(Js.num(v), 2) if d.get("u") == "dec" else (Num.fmt(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else str(v))
	return tfn.call("gear.fx." + id, {"v": val})


static func _sc(c: Object, id: String, v: float, m: float) -> float:
	var d: Dictionary = (c.D["GEAR_FX"] as Dictionary).get(id, {})
	if m == 0.0 or Js.truthy(d.get("noScale")):
		return v
	return Js.round_js(v * m * 100.0) / 100.0 if d.get("u") == "dec" else Js.round_js(v * m)


## Gear.lines → [{c: legend|fx|sub|copt|off|eopt|set, text}]
static func lines(c: Object, it: Variant, cls: Variant, tfn: Callable) -> Array:
	if not (it is Dictionary):
		return []
	var L: Array = []
	var lv := enhance_lv(it)
	var s_mul := 1.0 + Gear.get_enhance_multiplier(c, lv)
	var fx_mul := 1.5 if lv >= 10.0 else (1.25 if lv >= 5.0 else 1.0)
	var LG: Dictionary = c.D["LEGENDS"]
	if Js.truthy(it.get("legend")) and LG.has(it["legend"]):
		var f: Dictionary = LG[it["legend"]]["fx"]
		for k: String in f.keys():
			L.append({"c": "legend", "text": "★ " + fmt(c, k, _sc(c, k, float(f[k]), fx_mul), tfn)})
	if it.get("fx") is Dictionary:
		L.append({"c": "fx", "text": "◆ " + fmt(c, str(it["fx"]["id"]), _sc(c, str(it["fx"]["id"]), Js.num(it["fx"]["v"]), fx_mul), tfn)})
	for s: Variant in (it.get("subs") if it.get("subs") is Array else []):
		if s is Dictionary:
			L.append({"c": "sub", "text": "+ " + fmt(c, str(s["id"]), _sc(c, str(s["id"]), Js.num(s["v"]), s_mul), tfn)})
	if it.get("cOpt") is Dictionary:
		var co: Dictionary = it["cOpt"]
		var on: bool = not Js.truthy(cls) or co.get("cls") == cls
		L.append({"c": "copt" if on else "off", "text": "[" + tfn.call("classes." + str(co.get("cls")), {}) + "] " + fmt(c, str(co["id"]), _sc(c, str(co["id"]), Js.num(co["v"]), 2.0 if lv >= 10.0 else 1.0), tfn)})
	var eo: Dictionary = it["eOpts"] if it.get("eOpts") is Dictionary else {}
	var ks: Array = eo.keys()
	ks = Js.stable_sort(ks, func(a: Variant, b: Variant) -> float: return str(a).to_float() - str(b).to_float())
	for k2: Variant in ks:
		var o: Variant = eo[k2]
		if o is Dictionary:
			var vv: Variant = _sc(c, str(o["id"]), Js.num(o["v"]), fx_mul) if Js.truthy(o.get("uq")) else o["v"]
			L.append({"c": "eopt", "text": "+" + str(k2) + " " + fmt(c, str(o["id"]), vv, tfn)})
	if Js.truthy(it.get("setCls")) and (c.D["CLASS_SETS"] as Dictionary).has(it["setCls"]):
		var sd: Dictionary = c.D["CLASS_SETS"][it["setCls"]]
		for n: String in ["2", "3"]:
			var parts: Array = []
			for k3: String in sd[n].keys():
				parts.append(fmt(c, k3, sd[n][k3], tfn))
			L.append({"c": "set", "text": tfn.call("gear.set_bonus", {"n": int(n)}) + " " + " · ".join(parts)})
	return L


## 강화된 기본 능력치 글 ("공격력+12 체력+5")
static func stats_text(c: Object, item: Dictionary, tfn: Callable) -> String:
	var parts: Array = []
	var es := Gear.get_enhanced_stats(c, item)
	for st: String in es.keys():
		parts.append(tfn.call("common." + st, {}) + "+" + Num.fmt(es[st]))
	return " ".join(parts)


## 등급 머리글자 (t('equip.rarity.x').charAt(0).toUpperCase())
static func rarity_letter(item: Variant, tfn: Callable) -> String:
	var s: String = tfn.call("equip.rarity." + str(item.get("rarity") if item is Dictionary else ""), {})
	return s.substr(0, 1).to_upper()
