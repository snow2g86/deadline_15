extends RefCounted
## 저장 데이터 규칙 — 웹 js/common/storage.js · character.js · soul.js, js/logic/equip.js 의 인벤토리·Mats
##  모두 정적 함수, 첫 인자 c = ctx.gd (D·rng·store). 저장 키 이름은 웹과 같다 (game_save, game_roster …)

const Js := preload("res://scripts/logic/js.gd")

const SAVE_KEY := "game_save"
const ROSTER_KEY := "game_roster"
const INVENTORY_KEY := "game_inventory"
const SOUL_KEY := "game_soul"
const MATS_KEY := "game_mats"
const PITY_KEY := "game_gacha_pity"


# ── game_save ──

static func load_save(c: Object) -> Dictionary:
	var d: Variant = c.store.get_json(SAVE_KEY)
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func save_save(c: Object, d: Dictionary) -> void:
	c.store.set_json(SAVE_KEY, d)


## battle/constants.js loadGoldData → { gold, cleared(배열, 웹은 Set) }
static func load_gold_data(c: Object) -> Dictionary:
	var d: Variant = c.store.get_json(SAVE_KEY)
	if typeof(d) == TYPE_DICTIONARY:
		var cl: Array = []
		for v: Variant in (d.get("cleared", []) if d.get("cleared") != null else []):
			if Js.index_of(cl, v) < 0:
				cl.append(v)
		return {"gold": Js.num(d.get("gold")), "cleared": cl}
	return {"gold": 2000.0, "cleared": []}


static func save_gold(c: Object, gold: float, cleared: Variant = null) -> void:
	var d: Variant = c.store.get_json(SAVE_KEY)
	if typeof(d) != TYPE_DICTIONARY:
		d = {}
	d["gold"] = gold
	if cleared != null:
		d["cleared"] = cleared
	c.store.set_json(SAVE_KEY, d)


static func star_turn_limit(stage: Variant) -> float:
	if stage == null:
		return 0.0
	if Js.truthy(stage.get("starTurns")):
		return float(stage["starTurns"])
	var tot: float = float(stage["tot"]) if Js.truthy(stage.get("tot")) else 6.0
	return ceilf(tot * 0.75) + 4.0


## 이번 판 결과(flags)를 합쳐 저장 → { merged, newly }
static func save_stage_stars(c: Object, stage_id: Variant, flags: Array) -> Dictionary:
	var d := load_save(c)
	if typeof(d.get("stars")) != TYPE_DICTIONARY:
		d["stars"] = {}
	var key := str(stage_id)
	var prev: Array = d["stars"][key] if d["stars"].has(key) else [0, 0, 0]
	var merged: Array = []
	for i in prev.size():
		merged.append(1 if (Js.truthy(prev[i]) or Js.truthy(flags[i])) else 0)
	var newly: Array = []
	for i in merged.size():
		if Js.truthy(merged[i]) and not Js.truthy(prev[i]):
			newly.append(i)
	d["stars"][key] = merged
	save_save(c, d)
	return {"merged": merged, "newly": newly}


# ── 로스터 ──

static func roll_action_rec(c: Object) -> float:
	return Js.to_fixed_num(0.05 + c.rand("rollActionRec") * 0.15, 2)


static func random_gender(c: Object) -> String:
	return "m" if c.rand("randomGender") < 0.5 else "f"


## storage.js getRoster (마이그레이션 보정 포함 — 첫 클리어 신규 클랜원의 actionRec 보정이 여기서 난수를 씀)
static func get_roster(c: Object) -> Dictionary:
	var roster: Variant = c.store.get_json(ROSTER_KEY)
	if typeof(roster) != TYPE_DICTIONARY:
		return {"chars": [], "nextId": 1}
	var JAB: Dictionary = c.D["JAB"]
	var need_save := false
	if typeof(roster.get("chars")) == TYPE_ARRAY:
		for ch: Variant in roster["chars"]:
			if typeof(ch) != TYPE_DICTIONARY:
				continue
			if typeof(ch.get("skillLv")) == TYPE_DICTIONARY:
				var cmd_keys: Array = []
				for k: String in ch["skillLv"].keys():
					if k.begins_with("commander_"):
						cmd_keys.append(k)
				if not cmd_keys.is_empty():
					for k: String in cmd_keys:
						ch["skillLv"].erase(k)
					need_save = true
					var inv: Variant = c.store.get_json(INVENTORY_KEY)
					if typeof(inv) == TYPE_ARRAY:
						var left: Array = []
						for i: Variant in inv:
							if not (typeof(i) == TYPE_DICTIONARY and i.get("type") == null and typeof(i.get("id")) == TYPE_STRING and String(i["id"]).begins_with("commander_")):
								left.append(i)
						if left.size() != inv.size():
							c.store.set_json(INVENTORY_KEY, left)
			# (4a) 잘못된 형의 pot([] · 숫자 · 글자)은 없는 것으로 (웹은 [] 에 속성을 붙여 저장 때 사라짐 — 오류 없이 새로 만듦)
			if ch.has("pot") and typeof(ch.get("pot")) != TYPE_DICTIONARY and Js.truthy(ch.get("pot")):
				ch.erase("pot")
			var cls_ok := typeof(ch.get("cls")) == TYPE_STRING and JAB.has(ch["cls"])
			if not Js.truthy(ch.get("pot")):
				var gj: Variant = JAB[ch["cls"]].get("growth") if cls_ok else null
				if gj != null:
					ch["pot"] = {
						"hp": Js.to_fixed_num(gj["hp"][0] + (gj["hp"][1] - gj["hp"][0]) * 0.5, 1),
						"atk": Js.to_fixed_num(gj["atk"][0] + (gj["atk"][1] - gj["atk"][0]) * 0.5, 1),
						"def": Js.to_fixed_num(gj["def"][0] + (gj["def"][1] - gj["def"][0]) * 0.5, 1),
						"actionRec": roll_action_rec(c),
					}
					need_save = true
			if Js.truthy(ch.get("pot")) and not Js.truthy(ch["pot"].get("actionRec")):
				ch["pot"]["actionRec"] = roll_action_rec(c)
				need_save = true
			if not Js.truthy(ch.get("actionRec")):
				var base_rec: float = float(JAB[ch["cls"]]["actionRec"]) if cls_ok and Js.truthy(JAB[ch["cls"]].get("actionRec")) else 1.0
				var pot_rec := 0.0
				if Js.truthy(ch.get("pot")):
					pot_rec = Js.num(ch["pot"].get("actionRec"))
				ch["actionRec"] = base_rec + pot_rec
				need_save = true
	var CMD: String = c.D["COMMANDER_CLS"]
	if typeof(roster.get("chars")) == TYPE_ARRAY and JAB.has(CMD):
		for ch2: Variant in roster["chars"]:
			if typeof(ch2) != TYPE_DICTIONARY or not Js.same(ch2.get("cls"), CMD) or Js.same(ch2.get("buffer"), 2):
				continue
			var d: Dictionary = JAB[CMD]
			var lv: float = (Js.num(ch2.get("lv")) if Js.truthy(ch2.get("lv")) else 1.0) - 1.0
			var p: Dictionary = ch2["pot"] if typeof(ch2.get("pot")) == TYPE_DICTIONARY else {}
			ch2["hp"] = Js.round_js(d["base"]["hp"] + lv * (Js.num(p["hp"]) if Js.truthy(p.get("hp")) else 8.0))
			ch2["atk"] = Js.round_js(d["base"]["atk"] + lv * (Js.num(p["atk"]) if Js.truthy(p.get("atk")) else 1.5))
			ch2["def"] = Js.round_js(d["base"]["def"] + lv * (Js.num(p["def"]) if Js.truthy(p.get("def")) else 0.6))
			ch2["move"] = d["base"]["move"]
			ch2["range"] = d["base"]["range"]
			ch2["buffer"] = 2
			need_save = true
	if typeof(roster.get("chars")) == TYPE_ARRAY and not (roster["chars"] as Array).is_empty() and JAB.has(CMD):
		var has_cmd := false
		for ch3: Variant in roster["chars"]:
			if typeof(ch3) == TYPE_DICTIONARY and Js.same(ch3.get("cls"), CMD):
				has_cmd = true
		if not has_cmd:
			var nid: int = int(roster["nextId"])
			roster["nextId"] = nid + 1
			(roster["chars"] as Array).push_front(new_commander(c, nid))
			need_save = true
	if need_save:
		c.store.set_json(ROSTER_KEY, roster)
		roster = c.store.get_json(ROSTER_KEY)
	# (4a) chars 가 배열이 아닌 세이브: 부르는 쪽이 늘 배열을 쓰도록 (저장값은 그대로 둠)
	if typeof(roster.get("chars")) != TYPE_ARRAY:
		roster["chars"] = []
	return roster


static func new_commander(c: Object, uid: int) -> Dictionary:
	var d: Dictionary = c.D["JAB"][c.D["COMMANDER_CLS"]]
	var g: Dictionary = d["growth"]
	var mid := func(mm: Array) -> float: return Js.to_fixed_num(mm[0] + (mm[1] - mm[0]) * 0.6, 1)
	var pot := {"hp": mid.call(g["hp"]), "atk": mid.call(g["atk"]), "def": mid.call(g["def"]), "actionRec": 0.12}
	return {"uid": uid, "cls": c.D["COMMANDER_CLS"], "nameId": null, "customName": c.D["COMMANDER_DEFAULT_NAME"], "lv": 1, "exp": 0.0, "dead": false,
		"hp": d["base"]["hp"], "atk": d["base"]["atk"], "def": d["base"]["def"], "move": d["base"]["move"], "range": d["base"]["range"],
		"pot": pot, "actionRec": d["actionRec"] + pot["actionRec"], "gender": "m", "buffer": 2}


static func save_roster(c: Object, data: Dictionary) -> void:
	c.store.set_json(ROSTER_KEY, data)


## character.js getChar
static func get_char(c: Object, uid: Variant) -> Variant:
	var roster := get_roster(c)
	for ch: Variant in roster["chars"]:
		if typeof(ch) == TYPE_DICTIONARY and Js.same(ch.get("uid"), uid):
			return ch
	return null


static func exp_for_level(c: Object, lv: float) -> float:
	var L: Array = c.D["LEVEL_EXP"]
	return L[0] + L[1] * lv + L[2] * lv * lv


static func pot_grade(c: Object, ch: Dictionary) -> String:
	# (4a) 직업·잠재력 형이 잘못된 세이브는 C (오류 없이)
	if typeof(ch.get("cls")) != TYPE_STRING or not c.D["JAB"].has(ch["cls"]) or typeof(ch.get("pot")) != TYPE_DICTIONARY:
		return "C"
	var g: Dictionary = c.D["JAB"][ch["cls"]]["growth"]
	var tot := 0.0
	for k: String in ["hp", "atk", "def"]:
		var mn: float = g[k][0]
		var mx: float = g[k][1]
		var rng := mx - mn
		tot += (Js.num(ch["pot"].get(k)) - mn) / rng if rng > 0.0 else 0.5
	var avg := tot / 3.0
	if avg >= 0.85:
		return "S"
	if avg >= 0.65:
		return "A"
	if avg >= 0.35:
		return "B"
	return "C"


static func max_level_of(c: Object, ch: Variant) -> float:
	if ch != null:
		var cap: Variant = (c.D["GRADE_LV_CAP"] as Dictionary).get(pot_grade(c, ch))
		if Js.truthy(cap):
			return float(cap)
	return float(c.D["MAX_LEVEL"])


## character.js gainExp → { leveled, prevLv }
static func gain_exp(c: Object, uid: Variant, amount: float) -> Dictionary:
	var roster := get_roster(c)
	var ch: Variant = null
	for x: Variant in roster["chars"]:
		if typeof(x) == TYPE_DICTIONARY and Js.same(x.get("uid"), uid):
			ch = x
			break
	if ch == null or float(ch["lv"]) >= max_level_of(c, ch):
		return {"leveled": 0, "prevLv": ch["lv"] if ch != null else 0}
	var prev_lv: Variant = ch["lv"]
	ch["exp"] = Js.num(ch.get("exp")) + amount
	var leveled := 0
	while float(ch["lv"]) < max_level_of(c, ch):
		var need := exp_for_level(c, float(ch["lv"]))
		if float(ch["exp"]) < need:
			break
		ch["exp"] = float(ch["exp"]) - need
		ch["lv"] = int(ch["lv"]) + 1
		ch["hp"] = Js.round_js(float(ch["hp"]) + float(ch["pot"]["hp"]))
		ch["atk"] = Js.round_js(float(ch["atk"]) + float(ch["pot"]["atk"]))
		ch["def"] = Js.round_js(float(ch["def"]) + float(ch["pot"]["def"]))
		leveled += 1
	if float(ch["lv"]) >= max_level_of(c, ch):
		ch["exp"] = 0.0
	save_roster(c, roster)
	return {"leveled": leveled, "prevLv": prev_lv}


## battle/constants.js markDead (지휘관은 패배로 끝나므로 표시 안 함)
static func mark_dead(c: Object, uid: Variant) -> void:
	var roster := get_roster(c)
	for ch: Variant in roster["chars"]:
		if typeof(ch) == TYPE_DICTIONARY and Js.same(ch.get("uid"), uid):
			if Js.same(ch.get("cls"), c.D["COMMANDER_CLS"]):
				return
			ch["dead"] = true
			ch["diedAt"] = c.date_now()
			save_roster(c, roster)
			return


static func clear_battle(c: Object) -> void:
	c.store.remove("game_battle")


# ── 인벤토리 (equip.js loadInventory: 읽을 때 gv 없는 옛 장비를 새 구조로 전환하고 저장 — 웹과 같은 시점·같은 난수) ──
#  웹 세이브를 가져오면(Store.import_web_dump) 값은 그대로 들어오고, 처음 인벤토리를 읽는 규칙 함수가 여기서 전환한다 (웹도 그 시점).
#  전투 안이면 전투 난수, 전투 밖(로비 등)이면 그 ctx 의 난수를 쓴다.

static func load_inventory(c: Object) -> Array:
	var inv: Variant = c.store.get_json(INVENTORY_KEY)
	if typeof(inv) != TYPE_ARRAY:
		return []
	if (load("res://scripts/logic/gear.gd") as GDScript).call("migrate_inventory", c, inv):   # gear.gd 가 이 파일을 preload 해서 순환 preload 를 피함
		save_inventory(c, inv)
	return inv


static func save_inventory(c: Object, inv: Array) -> void:
	c.store.set_json(INVENTORY_KEY, inv)


# ── 영혼석 (soul.js) ──

static func soul_add(c: Object, kind: String, cls: Variant, n: float) -> void:
	if not Js.truthy(cls) or not Js.truthy(n):
		return
	var d: Variant = c.store.get_json(SOUL_KEY)
	if typeof(d) != TYPE_DICTIONARY or not Js.truthy(d.get("stones")) or not Js.truthy(d.get("frags")):
		d = {"stones": {}, "frags": {}}
	var b: Dictionary = d["stones"] if kind == "stone" else d["frags"]
	b[cls] = Js.num(b.get(cls)) + n
	c.store.set_json(SOUL_KEY, d)


# ── 강화 재료 (equip.js Mats) ──

static func mats_add(c: Object, k: String, n: float) -> float:
	var m: Variant = c.store.get_json(MATS_KEY)
	if typeof(m) != TYPE_DICTIONARY:
		m = {}
	m[k] = maxf(0.0, Js.num(m.get(k)) + n)
	c.store.set_json(MATS_KEY, m)
	return m[k]


static func load_pity(c: Object) -> int:
	var v: Variant = c.store.get_json(PITY_KEY)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	if typeof(v) == TYPE_STRING and String(v).is_valid_int():
		return String(v).to_int()
	return 0


static func save_pity(c: Object, n: int) -> void:
	c.store.set_json(PITY_KEY, n)
