extends RefCounted
## 로비 규칙 — 웹 js/index.js (ensureRoster · validateAndRepairGameData · 성별 마이그레이션 · 자동 부활 · 아지트 클랜원 · 전투 재개 확인)
##  + js/common/commander.js (지휘관 첫 설정: 남·여 · 이름)
##  모두 정적 함수, 첫 인자 c = ctx.gd (D · rng · store). 무작위(이름표·잠재력·성별)는 c.rand — 웹 Math.random 과 같은 순서로 부름.
##  로비에 들어올 때 웹과 같은 순서로: ensure_roster → validate_and_repair → (지휘관 설정) → migrate_gender → auto_revive

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")

const ROSTER_KEY := "game_roster"
const SAVE_KEY := "game_save"
const KNOWN_ITEM_TYPES := ["equip", "potion", "battle_potion", "siege", "scroll", "rune"]
const NAME_LEN := 10


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## 저장 키 읽기 → { exists, ok(JSON 으로 읽힘), v } (웹: raw 가 없으면 기본값, JSON.parse 가 실패하면 예외 → 그 단계 복구)
static func _read(c: Object, key: String) -> Dictionary:
	var raw: Variant = c.store.get_str(key)
	if raw == null or str(raw) == "":   # 빈 문자열 원본 = 웹 !raw (없는 것과 같음)
		return {"exists": false, "ok": true, "v": null}
	var r: Array = JsonExact.parse_ex(str(raw))
	if not r[0]:
		return {"exists": true, "ok": false, "v": null}
	return {"exists": true, "ok": true, "v": c.store.get_json(key)}


static func _empty_raw(rd: Dictionary) -> bool:
	var v: Variant = rd["v"]
	return not rd["exists"] or (v is Dictionary and (v as Dictionary).is_empty()) or (v is Array and (v as Array).is_empty())


static func is_member(c: Object, ch: Variant) -> bool:
	return typeof(ch) == TYPE_DICTIONARY and not str(ch.get("cls", "")).begins_with("summon_") and not Js.same(ch.get("cls"), c.D["COMMANDER_CLS"])


## 첫 실행: 노비스 5명 + 지휘관 + 기본 파티 5개 + 골드 2000 (로스터가 이미 있으면 아무것도 안 함 → false)
##  names_total: 언어 팩 character.names 개수 (없으면 300)
static func ensure_roster(c: Object, names_total: int) -> bool:
	var d: Variant = c.store.get_json(ROSTER_KEY)
	if typeof(d) == TYPE_DICTIONARY and d.get("chars") is Array and not (d["chars"] as Array).is_empty():
		return false
	if not c.D["JAB"].has("novice"):
		return false
	var nov: Dictionary = c.D["JAB"]["novice"]
	var total := names_total if names_total > 0 else 300
	var used: Dictionary = {}
	var chars: Array = []
	var next_id := 1
	for i in 5:
		var name_id := 0
		while true:
			name_id = int(floorf(c.rand("ensureRoster.name") * float(total)))
			if not used.has(name_id):
				break
		used[name_id] = true
		var g: Dictionary = nov["growth"]
		var roll := func(mm: Array) -> float: return Js.to_fixed_num(float(mm[0]) + c.rand("ensureRoster.pot") * (float(mm[1]) - float(mm[0])), 1)
		var p := {"hp": roll.call(g["hp"]), "atk": roll.call(g["atk"]), "def": roll.call(g["def"]), "actionRec": Profile.roll_action_rec(c)}
		chars.append({"uid": next_id, "cls": "novice", "nameId": name_id, "lv": 1, "exp": 0.0, "dead": false,
			"hp": nov["base"]["hp"], "atk": nov["base"]["atk"], "def": nov["base"]["def"],
			"move": nov["base"]["move"], "range": nov["base"]["range"], "pot": p,
			"actionRec": float(nov["actionRec"]) + float(p["actionRec"]), "gender": Profile.random_gender(c)})
		next_id += 1
	c.store.set_json(ROSTER_KEY, {"chars": chars, "nextId": next_id})
	Profile.get_roster(c)   # 지휘관 자동 추가
	var uids: Array = []
	for ch: Dictionary in chars:
		uids.append(ch["uid"])
	PartyRules.save_parties(c, PartyRules.create_default_parties(uids))
	c.store.set_json(SAVE_KEY, {"gold": 2000.0})
	return true


## validateAndRepairGameData — 깨진 저장값 고치기. → { ok(고칠 것 없었음), repaired, errors }
static func validate_and_repair(c: Object, names_total: int) -> Dictionary:
	var repaired := false
	var errors: Array = []
	var JAB: Dictionary = c.D["JAB"]
	# 1. 로스터
	var rr0 := _read(c, ROSTER_KEY)
	var roster: Variant = rr0["v"]
	var bad := false
	if _empty_raw(rr0):
		errors.append("roster_empty")
		bad = true
	elif not rr0["ok"] or typeof(roster) != TYPE_DICTIONARY:
		bad = true
	elif not (roster.get("chars") is Array):
		errors.append("roster_structure")
		bad = true
	if bad:
		ensure_roster(c, names_total)
		repaired = true
	else:
		var seen: Dictionary = {}
		var keep: Array = []
		for ch: Variant in roster["chars"]:
			if typeof(ch) != TYPE_DICTIONARY:
				continue
			if not Js.truthy(ch.get("uid")) or not _is_num(ch.get("uid")):
				continue
			var u := float(ch["uid"])
			if seen.has(u):
				errors.append("duplicate_uid_%d" % int(u))
				continue
			seen[u] = true
			if not Js.truthy(ch.get("cls")):
				ch["cls"] = "novice"
			if not JAB.has(str(ch["cls"])):
				ch["cls"] = "novice"
			var base: Dictionary = JAB[ch["cls"]]["base"]
			if not _is_num(ch.get("lv")) or float(ch["lv"]) < 1.0:
				ch["lv"] = 1
			if not _is_num(ch.get("exp")) or float(ch["exp"]) < 0.0:
				ch["exp"] = 0.0
			if not _is_num(ch.get("hp")) or float(ch["hp"]) <= 0.0:
				ch["hp"] = base["hp"] if Js.truthy(base.get("hp")) else 10.0
			if not _is_num(ch.get("atk")) or float(ch["atk"]) <= 0.0:
				ch["atk"] = base["atk"] if Js.truthy(base.get("atk")) else 1.0
			if not _is_num(ch.get("def")) or float(ch["def"]) < 0.0:
				ch["def"] = base["def"] if Js.truthy(base.get("def")) else 0.0
			if typeof(ch.get("pot")) != TYPE_DICTIONARY:
				ch["pot"] = {"hp": 0.5, "atk": 0.5, "def": 0.5}
			for k: String in ["hp", "atk", "def"]:
				if not _is_num(ch["pot"].get(k)):
					ch["pot"][k] = 0.5
			if not _is_num(ch.get("move")):
				ch["move"] = base["move"] if Js.truthy(base.get("move")) else 3.0
			if not _is_num(ch.get("range")):
				ch["range"] = base["range"] if Js.truthy(base.get("range")) else 1.0
			if typeof(ch.get("dead")) != TYPE_BOOL:
				ch["dead"] = false
			if not Js.truthy(ch.get("gender")):
				ch["gender"] = "m"
			if Js.truthy(ch.get("dead")) and not _is_num(ch.get("diedAt")):
				ch.erase("diedAt")
			keep.append(ch)
		roster["chars"] = keep
		if not Js.truthy(roster.get("nextId")) or not _is_num(roster.get("nextId")):
			var mx := -INF
			for ch2: Dictionary in keep:
				mx = maxf(mx, Js.num(ch2.get("uid")))
			roster["nextId"] = mx + 1.0
			repaired = true
		if repaired or not errors.is_empty():
			c.store.set_json(ROSTER_KEY, roster)
	# 2. 파티
	var rp := _read(c, PartyRules.PARTIES_KEY)
	var parties: Variant = rp["v"]
	var r2: Variant = c.store.get_json(ROSTER_KEY)
	var rchars: Array = r2["chars"] if typeof(r2) == TYPE_DICTIONARY and r2.get("chars") is Array else []
	var pbad: bool = _empty_raw(rp) or not rp["ok"]
	if not pbad and (typeof(parties) != TYPE_DICTIONARY or not (parties.get("parties") is Array)):
		pbad = true
	if not pbad:
		var valid: Dictionary = {}
		for ch3: Variant in rchars:
			if typeof(ch3) == TYPE_DICTIONARY:
				valid[Js.num(ch3.get("uid"))] = true
		var idx := 0
		for party: Variant in parties["parties"]:
			if typeof(party) != TYPE_DICTIONARY:
				idx += 1
				continue
			if not (party.get("slots") is Array):
				party["slots"] = []
			var ns: Array = []
			for u2: Variant in party["slots"]:
				if not Js.truthy(u2):
					ns.append(null)
				else:
					ns.append(u2 if (_is_num(u2) and valid.has(float(u2))) else null)
			while ns.size() < PartyRules.SLOTS:
				ns.append(null)
			party["slots"] = ns.slice(0, PartyRules.SLOTS)
			if not _is_num(party.get("id")):
				party["id"] = idx
			idx += 1
		var has_active := false
		for p3: Variant in parties["parties"]:
			if typeof(p3) == TYPE_DICTIONARY and Js.same(p3.get("id"), parties.get("activePartyId")):
				has_active = true
		if not has_active:
			parties["activePartyId"] = parties["parties"][0].get("id") if not (parties["parties"] as Array).is_empty() else 1
		PartyRules.save_parties(c, parties)
	else:
		var first: Array = []
		for i in 5:
			first.append(rchars[i].get("uid") if i < rchars.size() and typeof(rchars[i]) == TYPE_DICTIONARY and Js.truthy(rchars[i].get("uid")) else null)
		PartyRules.save_parties(c, PartyRules.create_default_parties(first))
		repaired = true
	# 3. 인벤토리 (깨진 항목만 뺌)
	var ri := _read(c, "game_inventory")
	var inv: Variant = ri["v"] if ri["exists"] else []
	if not ri["ok"] or not (inv is Array):
		c.store.set_json("game_inventory", [])
		repaired = true
	else:
		var keep_inv: Array = []
		for it: Variant in inv:
			if typeof(it) != TYPE_DICTIONARY:
				continue
			if KNOWN_ITEM_TYPES.has(it.get("type")):
				keep_inv.append(it)
			elif not Js.truthy(it.get("type")) and Js.truthy(it.get("id")) and Js.truthy(it.get("cls")):
				keep_inv.append(it)
		c.store.set_json("game_inventory", keep_inv)
	# 4. 골드
	var rs := _read(c, SAVE_KEY)
	var sv: Variant = rs["v"]
	if not rs["ok"] or (rs["exists"] and sv == null):
		c.store.set_json(SAVE_KEY, {"gold": 2000.0})   # 'null' 등 → 웹은 예외 → 새로
		repaired = true
	else:
		var save: Dictionary = sv if typeof(sv) == TYPE_DICTIONARY else {}
		if not _is_num(save.get("gold")) or float(save["gold"]) < 0.0:
			save["gold"] = 2000.0
		# (4a, 웹보다 관대하게) 클리어 기록: 숫자 글자는 숫자로, 숫자가 아닌 것은 뺌 · 별 기록이 사전이 아니면 지움
		if save.has("cleared"):
			var fixed: Array = []
			var src: Array = save["cleared"] if save["cleared"] is Array else []
			for v0: Variant in src:
				var n0: Variant = PartyRules.to_int_id(v0)
				if n0 != null:
					fixed.append(n0)
			if not (save["cleared"] is Array) or JsonExact.stringify(fixed) != JsonExact.stringify(save["cleared"]):
				save["cleared"] = fixed
		if save.has("stars") and not (save["stars"] is Dictionary):
			save.erase("stars")
		c.store.set_json(SAVE_KEY, save)
	# 5. 클리어 기록 (game_cleared — 옛 키, 숫자 1~100 만)
	var rc := _read(c, "game_cleared")
	var cl: Variant = rc["v"]
	var cl2: Array = []
	if not rc["ok"]:
		repaired = true
	elif cl is Array:
		for v: Variant in cl:
			if _is_num(v) and float(v) > 0.0 and float(v) <= 100.0:
				cl2.append(v)
	c.store.set_json("game_cleared", cl2)
	# 6. 전투 아이템 (game_battle_items — 배열 아니면 빈 배열)
	var rb := _read(c, PartyRules.BATTLE_ITEMS_KEY)
	var bi: Variant = rb["v"]
	var bi2: Array = []
	if not rb["ok"]:
		repaired = true
	elif bi is Array:
		for it2: Variant in bi:
			if typeof(it2) == TYPE_DICTIONARY and Js.truthy(it2.get("id")) and _is_num(it2.get("count")) and float(it2["count"]) >= 0.0:
				bi2.append(it2)
	c.store.set_json(PartyRules.BATTLE_ITEMS_KEY, bi2)
	return {"ok": not repaired, "repaired": repaired, "errors": errors}


## 성별 없는 클랜원에 무작위 성별 (index.js init 의 Migrate)
static func migrate_gender(c: Object) -> bool:
	var rd: Variant = c.store.get_json(ROSTER_KEY)
	if typeof(rd) != TYPE_DICTIONARY or not (rd.get("chars") is Array):
		return false
	var changed := false
	for ch: Variant in rd["chars"]:
		if typeof(ch) == TYPE_DICTIONARY and not Js.truthy(ch.get("gender")):
			ch["gender"] = Profile.random_gender(c)
			changed = true
	if changed:
		c.store.set_json(ROSTER_KEY, rd)
	return changed


## 자동 부활: 살아 있는 클랜원이 5명 미만이면 최근에 죽은 순서로 5명까지 (HP 는 직업 기본값) → 부활한 클랜원 사전 목록
static func auto_revive(c: Object) -> Array:
	var rr: Variant = c.store.get_json(ROSTER_KEY)
	if typeof(rr) != TYPE_DICTIONARY or not (rr.get("chars") is Array):
		return []
	var alive := 0
	var dead: Array = []
	for ch: Variant in rr["chars"]:
		if not is_member(c, ch):
			continue
		if Js.truthy(ch.get("dead")):
			dead.append(ch)
		else:
			alive += 1
	if alive >= 5 or dead.is_empty():
		return []
	dead = Js.stable_sort(dead, func(a: Dictionary, b: Dictionary) -> float: return Js.num(b.get("diedAt")) - Js.num(a.get("diedAt")))
	var need := mini(5 - alive, dead.size())
	var out: Array = []
	for i in need:
		var d: Dictionary = dead[i]
		d["dead"] = false
		d.erase("diedAt")
		d["hp"] = c.D["JAB"][d["cls"]]["base"]["hp"] if c.D["JAB"].has(d["cls"]) else 1.0
		out.append(d)
	c.store.set_json(ROSTER_KEY, rr)
	return out


## 아지트에 앉을 클랜원 (살아 있는 클랜원, 레벨 높은 순, 최대 10명)
static func hideout_chars(c: Object) -> Array:
	var r: Variant = c.store.get_json(ROSTER_KEY)
	if typeof(r) != TYPE_DICTIONARY or not (r.get("chars") is Array):
		return []
	var list: Array = []
	for ch: Variant in r["chars"]:
		if is_member(c, ch) and not Js.truthy(ch.get("dead")):
			list.append(ch)
	list = Js.stable_sort(list, func(a: Dictionary, b: Dictionary) -> float: return Js.num(b.get("lv")) - Js.num(a.get("lv")))
	return list.slice(0, 10)




static func gold(c: Object) -> float:
	return Js.num(Profile.load_save(c).get("gold"))


# ── 지휘관 (commander.js) ──

static func commander(c: Object) -> Variant:
	for ch: Variant in Profile.get_roster(c)["chars"]:
		if typeof(ch) == TYPE_DICTIONARY and Js.same(ch.get("cls"), c.D["COMMANDER_CLS"]):
			return ch
	return null


## 아직 고르지 않았으면 설정 화면을 열어야 함
static func commander_needs_setup(c: Object) -> bool:
	var ch: Variant = commander(c)
	return ch != null and not Js.truthy(ch.get("setup"))


## 표시 이름: 설정했으면 customName, 아니면 언어별 기본 이름(default_name)
static func commander_display_name(c: Object, default_name: String) -> String:
	var ch: Variant = commander(c)
	if ch != null and Js.truthy(ch.get("setup")) and Js.truthy(ch.get("customName")):
		return str(ch["customName"])
	return default_name


## JS String.prototype.trim 이 지우는 공백 (WhiteSpace + LineTerminator: 탭·줄바꿈·NBSP·전각 공백 U+3000·BOM U+FEFF 등)
const JS_SPACE := [0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0xA0, 0x1680, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007,
	0x2008, 0x2009, 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF]


static func js_trim(s: String) -> String:
	var a := 0
	var b := s.length()
	while a < b and JS_SPACE.has(s.unicode_at(a)):
		a += 1
	while b > a and JS_SPACE.has(s.unicode_at(b - 1)):
		b -= 1
	return s.substr(a, b - a)


## JS s.slice(0, n) — 길이를 UTF-16 단위로 셈 (U+FFFF 넘는 글자는 2). 끝에서 글자가 반으로 갈리면 그 글자는 뺌 (Godot 문자열은 반쪽 글자를 담지 못함)
static func utf16_slice(s: String, n: int) -> String:
	var units := 0
	var out := ""
	for i in s.length():
		var w := 2 if s.unicode_at(i) > 0xFFFF else 1
		if units + w > n:
			break
		units += w
		out += s[i]
	return out


static func utf16_len(s: String) -> int:
	var units := 0
	for i in s.length():
		units += 2 if s.unicode_at(i) > 0xFFFF else 1
	return units


## 입력 이름 다듬기 (commander.js: input.value.trim().slice(0, 10) || defaultName())
static func clean_name(raw: String, default_name: String) -> String:
	var s := utf16_slice(js_trim(raw), NAME_LEN)
	return s if s != "" else default_name


static func commander_apply(c: Object, gender: String, raw_name: String, default_name: String) -> Variant:
	var roster := Profile.get_roster(c)
	for ch: Variant in roster["chars"]:
		if typeof(ch) == TYPE_DICTIONARY and Js.same(ch.get("cls"), c.D["COMMANDER_CLS"]):
			ch["gender"] = gender
			ch["customName"] = clean_name(raw_name, default_name)
			ch["setup"] = true
			Profile.save_roster(c, roster)
			return ch
	return null
