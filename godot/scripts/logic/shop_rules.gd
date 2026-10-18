extends RefCounted
## 상점 규칙 (4b-1) — 웹 js/shop.js (+ js/common/character.js addChar · soul.js · equip.js gachaPull · hazards.js Rune · gear.js exchangeLegend)
##  화면 코드 없이 정적 함수, 첫 인자 c = ctx.gd. 저장 형식은 웹과 같다:
##   game_shop = { ts: 만든 시각(ms), items: [ {type:'char'|'skillbook'|'soulstone'|'scroll'|'potion'|'battle_potion'|'siege', …, cost, sold} ] }
##   인벤토리에 넣는 물건 모양도 웹 그대로 (경험치 물약 {type:'potion', pid, potionId, exp, icon, quantity} …)
##  무작위: 웹과 같은 씨앗·같은 순서 (Math.random 호출 순서를 줄 단위로 맞춤). 웹의 `.sort(() => Math.random() - 0.5)` 는
##   V8 정렬의 비교 호출 순서까지 Js.v8_sort 로 재현하고, id 꼬리 `Math.random().toString(36).slice(2, 6)` 도 Js.rand36_4 로 같은 글.
##   → tests/check_outer_4b1.gd 가 같은 씨앗·같은 시각으로 웹 코드(node tools/legacy-web/outer-4b1-expect.js)와 저장값을 바이트 단위로 비교.
##  용병 이름은 웹처럼 '지금 언어'의 character.names 에서 고른 글자를 저장하므로 names(배열)를 받는다.

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const Gear := preload("res://scripts/logic/gear.gd")
const EquipRules := preload("res://scripts/logic/equip_rules.gd")

const SHOP_KEY := "game_shop"
## 웹 shop.js 의 상수 (data/*.js 가 아니라 화면 파일 안에 있음 — 웹 정답 파일과 같은지 시험이 확인)
const EXP_POTIONS := [
	{"id": "exp_s", "name": "소형 경험치 물약", "icon": "🧪", "exp": 50, "cost": 400, "weight": 50},
	{"id": "exp_m", "name": "중형 경험치 물약", "icon": "⚗️", "exp": 150, "cost": 1000, "weight": 35},
	{"id": "exp_l", "name": "대형 경험치 물약", "icon": "🏐", "exp": 400, "cost": 2400, "weight": 15},
]
const BATTLE_POTION_LIST := [
	{"potionId": "potion_heal", "weight": 40}, {"potionId": "potion_resource", "weight": 30}, {"potionId": "potion_atk_buff", "weight": 20},
	{"potionId": "potion_def_buff", "weight": 20}, {"potionId": "potion_atk_debuff", "weight": 15}, {"potionId": "potion_def_debuff", "weight": 15},
]
const SCROLL_CLASSES := ["warrior", "knight", "assassin", "brawler", "lancer", "sapper", "archer", "mage", "summoner", "shaman", "priest"]
const POTION_KEYS := {"exp_s": "potion_small", "exp_m": "potion_medium", "exp_l": "potion_large"}
const SHOP_REFRESH_INTERVAL := 3600000.0
const TABS := ["mercenary", "consumable", "equip", "skill", "scroll", "gold"]
## 탭 → 보이는 물건 종류 (scroll 탭은 따로, equip·gold 탭은 물건 목록 없음)
const TAB_TYPES := {"mercenary": ["char"], "consumable": ["potion", "battle_potion", "siege"], "skill": ["soulstone", "skillbook"], "scroll": ["scroll"]}
const TIMER_HIDDEN := ["consumable", "gold"]
## 골드 탭 결제 꾸러미 — (결제층 A) 데이터 data/iap.json 의 IAP_PRODUCTS 에서 읽음 (예전 상수 GOLD_PACKAGES 를 옮김).
##  [{id, gold, key(번역 키 'shop.' 뒤), price(가게 가격을 못 받았을 때의 글), krw}] — 상품·가격 규칙은 scripts/logic/iap_rules.gd
static func gold_packages(c: Object) -> Array:
	var out: Array = []
	var P: Variant = c.D.get("IAP_PRODUCTS")
	if not (P is Array):
		return out
	for p: Variant in P:
		if p is Dictionary:
			out.append({"id": str(p["id"]), "gold": float(p["gold"]), "key": str(p["label"]).trim_prefix("shop."), "price": str(p.get("fallback_price", "")), "krw": float(p.get("krw", 0))})
	return out


static func _cmp_random(c: Object) -> Callable:
	return func(_a: Variant, _b: Variant) -> float: return c.rand("sort") - 0.5


## 잠재력 등급 (웹 genRotatingItems · renderCharCard) → [등급, 평균 점수]
static func grade_of(c: Object, cls: String, pot: Dictionary) -> Array:
	var g: Dictionary = c.D["JAB"][cls]["growth"]
	var tot := 0.0
	for k: String in ["hp", "atk", "def"]:
		var mn: float = g[k][0]
		var mx: float = g[k][1]
		var rng := mx - mn
		tot += (Js.num(pot.get(k)) - mn) / rng if rng > 0.0 else 0.5
	var avg := tot / 3.0
	var grade := "S" if avg >= 0.85 else ("A" if avg >= 0.65 else ("B" if avg >= 0.35 else "C"))
	return [grade, avg]


## shop.js genRotatingItems — 용병 6 · 스킬북 6 · 영혼석 3 · 전직서 6
static func gen_rotating(c: Object, names: Array) -> Array:
	var JAB: Dictionary = c.D["JAB"]
	var classes: Array = []
	for k: String in JAB.keys():
		if not k.begins_with("summon") and not Js.truthy(JAB[k].get("unique")):
			classes.append(k)
	var items: Array = []
	for i in 6:
		var cls: String = classes[int(floorf(c.rand("shop.cls") * classes.size()))]
		var d: Dictionary = JAB[cls]
		var gr: Dictionary = d["growth"]
		var pot := {}
		for k2: String in ["hp", "atk", "def"]:
			pot[k2] = Js.to_fixed_num(float(gr[k2][0]) + c.rand("shop.pot") * (float(gr[k2][1]) - float(gr[k2][0])), 1)
		pot["actionRec"] = Profile.roll_action_rec(c)
		var name: Variant = names[int(floorf(c.rand("shop.name") * names.size()))] if not names.is_empty() else null
		var ga := grade_of(c, cls, pot)
		var cost := Js.round_js(float(c.D["ECON"]["merc"][ga[0]]) * (0.9 + float(ga[1]) * 0.2))
		items.append({"type": "char", "cls": cls, "name": name, "pot": pot, "cost": cost, "sold": false, "gender": Profile.random_gender(c)})
	var LS: Dictionary = c.D["LEARNABLE_SKILLS"]
	var ls_keys: Array = []
	for k3: String in LS.keys():
		if LS[k3].get("cls") != "commander":
			ls_keys.append(k3)
	ls_keys = Js.v8_sort(ls_keys, _cmp_random(c))
	for sb in mini(6, ls_keys.size()):
		var sk: Dictionary = LS[ls_keys[sb]]
		var base: float = float(sk["bookCost"]) if Js.truthy(sk.get("bookCost")) else (1500.0 if sk.get("cls") == "commander" else 800.0)
		items.append({"type": "skillbook", "skillId": sk["id"], "cls": sk["cls"], "cost": Js.round_js(base * float(c.D["ECON"]["bookMul"])), "sold": false})
	var soul_cls: Array = Js.v8_sort((c.D["DAILY"]["CLASSES"] as Array).duplicate(), _cmp_random(c)).slice(0, 3)
	for sc: String in soul_cls:
		items.append({"type": "soulstone", "cls": sc, "cost": c.D["ECON"]["soulStone"], "sold": false})
	var shuffled: Array = Js.v8_sort(SCROLL_CLASSES.duplicate(), _cmp_random(c))
	for si in 6:
		items.append({"type": "scroll", "scrollCls": shuffled[si], "cost": c.D["ECON"]["scroll"], "sold": false})
	return items


## shop.js genFixedItems — 경험치 물약 3 · 전투 물약 6 · 공성 아이템 전부 (난수 없음)
static func gen_fixed(c: Object) -> Array:
	var items: Array = []
	for p: Dictionary in EXP_POTIONS:
		items.append({"type": "potion", "potionId": p["id"], "name": p["name"], "i18nNameKey": "shop." + str(POTION_KEYS[p["id"]]),
			"icon": p["icon"], "exp": p["exp"], "cost": p["cost"], "sold": false, "quantity": 1})
	var BP: Dictionary = c.D["BATTLE_POTIONS"]
	for bp: Dictionary in BATTLE_POTION_LIST:
		var d: Variant = BP.get(bp["potionId"])
		if d != null:
			items.append({"type": "battle_potion", "potionId": bp["potionId"], "name": d["name"], "icon": d["icon"], "cost": c.D["ECON"]["battlePotion"], "sold": false, "quantity": 1})
	for s: Dictionary in c.D["SIEGE_ITEMS"]:
		items.append({"type": "siege", "siegeId": s["id"], "icon": s["icon"], "cost": s["cost"], "sold": false, "quantity": 1})
	return items


static func save_shop(c: Object, data: Dictionary) -> void:
	c.store.set_json(SHOP_KEY, data)


## shop.js genShop
static func gen_shop(c: Object, names: Array) -> Dictionary:
	var items := gen_fixed(c)
	items.append_array(gen_rotating(c, names))
	var data := {"ts": c.date_now(), "items": items}
	save_shop(c, data)
	return data


## shop.js refreshRotatingItems — 고정 물건(물약·전투 물약·공성)은 그대로, 갱신 물건만 새로
static func refresh_rotating(c: Object, data: Dictionary, names: Array) -> void:
	var rot := gen_rotating(c, names)
	var keep: Array = []
	for it: Variant in data["items"]:
		if it is Dictionary and ["potion", "battle_potion", "siege"].has(it.get("type")):
			keep.append(it)
	keep.append_array(rot)
	data["items"] = keep
	data["ts"] = c.date_now()
	save_shop(c, data)


## shop.js loadShop — 있으면 읽고 1시간이 지났으면 갱신 물건만 새로, 없거나 깨졌으면 새 상점 (들어올 때 한 번 — 웹도 페이지를 열 때만)
static func load_shop(c: Object, names: Array) -> Dictionary:
	var data: Variant = c.store.get_json(SHOP_KEY)
	if data is Dictionary and data.get("items") is Array:
		var ts: Variant = data.get("ts")
		if (typeof(ts) == TYPE_INT or typeof(ts) == TYPE_FLOAT) and c.date_now() - float(ts) >= SHOP_REFRESH_INTERVAL:
			refresh_rotating(c, data, names)
		return data
	return gen_shop(c, names)


## 갱신까지 남은 시간 {hours, minutes, seconds} (없으면 {})
static func refresh_time(c: Object, data: Dictionary) -> Dictionary:
	var ts: Variant = data.get("ts")
	if not Js.truthy(ts) or not (typeof(ts) == TYPE_INT or typeof(ts) == TYPE_FLOAT):
		return {}
	var elapsed: float = c.date_now() - float(ts)
	var remaining := SHOP_REFRESH_INTERVAL - fmod(elapsed, SHOP_REFRESH_INTERVAL)   # JS % (나눠지는 수의 부호)
	var total := int(floorf(remaining / 1000.0))
	return {"hours": total / 3600, "minutes": (total % 3600) / 60, "seconds": total % 60}


## 탭 타이머 글 (웹 updateShopTimer — 소모품·골드 탭은 숨김 → "")
static func timer_text(c: Object, data: Dictionary, tab: String, tfn: Callable) -> String:
	if TIMER_HIDDEN.has(tab):
		return ""
	var tm := refresh_time(c, data)
	if tm.is_empty():
		return ""
	return tfn.call("shop.refresh_timer", {"hours": tm["hours"], "minutes": ("0" + str(tm["minutes"])).right(2), "seconds": ("0" + str(tm["seconds"])).right(2)})


## 탭에 보일 물건 (번호 = data.items 의 자리)
static func tab_items(data: Dictionary, tab: String) -> Array:
	var types: Array = TAB_TYPES.get(tab, [])
	var out: Array = []
	var items: Array = data.get("items", [])
	for i in items.size():
		var it: Variant = items[i]
		if it is Dictionary and types.has(str(it["type"]) if Js.truthy(it.get("type")) else "char"):
			out.append(i)
	return out


static func gold(c: Object) -> float:
	return EquipRules.load_gold(c)


static func _pay(c: Object, cost: float) -> bool:
	var g := gold(c)
	if g < cost:
		return false
	Profile.save_gold(c, g - cost)
	return true


## 'pot_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 6)
static func gen_id(c: Object, prefix: String) -> String:
	return prefix + "_" + Js.base36(int(c.date_now())) + "_" + Js.rand36_4(c.rand("genId"))


## character.js addChar
static func add_char(c: Object, cls: String, name_id: Variant, pot: Dictionary, gender: Variant) -> Variant:
	var d: Variant = (c.D["JAB"] as Dictionary).get(cls)
	if d == null:
		return null
	var roster := Profile.get_roster(c)
	var uid := int(Js.num(roster.get("nextId")))
	roster["nextId"] = uid + 1
	var ch := {"uid": uid, "cls": cls, "nameId": name_id, "lv": 1, "exp": 0, "dead": false,
		"hp": d["base"]["hp"], "atk": d["base"]["atk"], "def": d["base"]["def"], "move": d["base"]["move"], "range": d["base"]["range"],
		"pot": pot, "actionRec": float(d["actionRec"]) + Js.num(pot.get("actionRec")),
		"gender": gender if Js.truthy(gender) else Profile.random_gender(c)}
	(roster["chars"] as Array).append(ch)
	Profile.save_roster(c, roster)
	return ch


static func _item(data: Dictionary, idx: int) -> Variant:
	var items: Array = data.get("items", [])
	if idx < 0 or idx >= items.size() or not (items[idx] is Dictionary):
		return null
	return items[idx]


## 사기 (확인 창 '확인' 뒤의 일 — 용병은 웹도 확인 없이 바로) → 결과 { ok, kind, … } 또는 { ok:false, err:"gold"|"sold"|"invalid" }
static func buy(c: Object, data: Dictionary, idx: int, names: Array) -> Dictionary:
	var it: Variant = _item(data, idx)
	if it == null:
		return {"ok": false, "err": "invalid"}
	var ty := str(it["type"]) if Js.truthy(it.get("type")) else "char"
	var cost := Js.num(it.get("cost"))
	var once := ["char", "skillbook", "soulstone", "scroll"].has(ty)
	if once and Js.truthy(it.get("sold")):
		return {"ok": false, "err": "sold"}
	if not _pay(c, cost):
		return {"ok": false, "err": "gold"}
	match ty:
		"char":
			var nidx := Js.index_of(names, it.get("name"))
			if nidx < 0:
				nidx = int(floorf(c.rand("shop.nameIdx") * names.size()))
			var ch: Variant = add_char(c, str(it["cls"]), nidx, Js.deep(it["pot"]), it.get("gender"))
			it["sold"] = true
			save_shop(c, data)
			return {"ok": true, "kind": ty, "char": ch}
		"potion":
			var inv := Profile.load_inventory(c)
			inv.append({"type": "potion", "pid": gen_id(c, "pot"), "potionId": it["potionId"], "exp": it["exp"], "icon": it["icon"],
				"quantity": it["quantity"] if Js.truthy(it.get("quantity")) else 1})
			Profile.save_inventory(c, inv)
			return {"ok": true, "kind": ty}
		"battle_potion":
			var bd: Variant = (c.D["BATTLE_POTIONS"] as Dictionary).get(it.get("potionId"))
			var inv2 := Profile.load_inventory(c)
			inv2.append({"type": "battle_potion", "pid": gen_id(c, "pot"), "potionId": it["potionId"], "icon": bd["icon"] if bd != null else it.get("icon"),
				"quantity": it["quantity"] if Js.truthy(it.get("quantity")) else 1})
			Profile.save_inventory(c, inv2)
			return {"ok": true, "kind": ty}
		"siege":
			var inv3 := Profile.load_inventory(c)
			inv3.append({"type": "siege", "sid": gen_id(c, "siege"), "siegeId": it["siegeId"], "icon": it["icon"],
				"quantity": it["quantity"] if Js.truthy(it.get("quantity")) else 1})
			Profile.save_inventory(c, inv3)
			return {"ok": true, "kind": ty}
		"skillbook":
			var inv4 := Profile.load_inventory(c)
			inv4.append({"id": it["skillId"], "cls": it["cls"], "lv": 1})
			Profile.save_inventory(c, inv4)
			it["sold"] = true
			save_shop(c, data)
			return {"ok": true, "kind": ty}
		"soulstone":
			Profile.soul_add(c, "stone", it["cls"], 1.0)
			it["sold"] = true
			save_shop(c, data)
			return {"ok": true, "kind": ty}
		"scroll":
			var inv5 := Profile.load_inventory(c)
			inv5.append({"type": "scroll", "scrollCls": it["scrollCls"]})
			Profile.save_inventory(c, inv5)
			it["sold"] = true
			save_shop(c, data)
			return {"ok": true, "kind": ty}
	return {"ok": false, "err": "invalid"}


## 마법부여 룬 뽑기 (확인 없이 바로) → 얻은 룬 종류, 골드 부족이면 ""
static func rune_gacha(c: Object) -> String:
	if not _pay(c, float(c.D["RUNE_GACHA_COST"])):
		return ""
	return Gear.rune_add(c, Gear.rune_random(c))


static func rune_count(c: Object, kind: String) -> int:
	var n := 0
	for it: Variant in Profile.load_inventory(c):
		if it is Dictionary and it.get("type") == "rune" and it.get("enchant") == kind:
			n += 1
	return n


## shop.js doGacha(1 | 10) → 뽑은 장비 (골드 부족이면 [])
static func gacha(c: Object, count: int) -> Array:
	var cost := float(c.D["GACHA_COST_1"] if count == 1 else c.D["GACHA_COST_10"])
	var pulls := 1 if count == 1 else int(c.D["GACHA_MULTI_COUNT"])
	if not _pay(c, cost):
		return []
	var results: Array = []
	for i in pulls:
		results.append(Gear.gacha_pull(c, "rare" if (count == 10 and i == pulls - 1) else null, false))
	var inv := Profile.load_inventory(c)
	inv.append_array(results)
	Profile.save_inventory(c, inv)
	return results


## 강화 재료 사기 (stone · protect, 확인 없이 바로)
static func buy_mat(c: Object, k: String) -> bool:
	if not _pay(c, float(c.D["MATS_PRICE"][k])):
		return false
	Profile.mats_add(c, k, 1.0)
	return true


## gear.js Gear.exchangeLegend → 받은 장비 또는 null
static func exchange_legend(c: Object, id: String) -> Variant:
	if not (c.D["LEGENDS"] as Dictionary).has(id) or EquipRules.mats_get(c, "shard") < float(c.D["LEGEND_SHARD_COST"]):
		return null
	Profile.mats_add(c, "shard", -float(c.D["LEGEND_SHARD_COST"]))
	return Gear.give(c, Gear.make_legend(c, id))


## 확률표 [[rarity, "60"]] (웹 gachaRatesHtml 의 숫자 글)
static func gacha_rates(c: Object) -> Array:
	var out: Array = []
	var GR: Dictionary = c.D["GACHA_RATE"]
	for r: String in GR.keys():
		var pct := float(GR[r]) * 100.0
		out.append([r, EquipRules.fixed_str(pct, 0 if pct >= 1.0 else (1 if pct >= 0.1 else 2))])
	return out
