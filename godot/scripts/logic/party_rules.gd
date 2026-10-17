extends RefCounted
## 파티 편성 규칙 — 웹 js/common/storage.js (createDefaultParties · loadParties · saveParties · _dropCommander · getActiveParty · loadParty)
##  + js/party-select.js 의 규칙 부분 (슬롯 배치·빼기·활성 파티·죽은 클랜원 빼기·유닛 목록 거르기·정렬·출격)
##  + js/stage-select.js _launchStage · js/battle/end.js goNextStage (5명이면 바로 전투, 아니면 편성 화면)
##  모두 정적 함수, 첫 인자 c = ctx.gd (D · rng · store). 저장 키·모양은 웹과 같음:
##   game_parties = { parties: [{id, slots:[uid|null ×5]}], activePartyId, nextPartyId }
##   game_nav = { cStage, party?, practiceMode? }   ps_can_start = 'true' | 'false' (문자열)

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")

const PARTIES_KEY := "game_parties"
const PARTY_KEY := "game_party"   # 레거시 (마이그레이션용)
const NAV_KEY := "game_nav"
const CAN_START_KEY := "ps_can_start"
const ACTIVE_TAB_KEY := "ps_active_tab"
const BATTLE_ITEMS_KEY := "game_battle_items"
const GROUP_ORDER := ["beginner", "melee", "ranged", "support"]
const SLOTS := 5


static func create_default_parties(first_slots: Variant = null) -> Dictionary:
	var slots: Array = []
	if first_slots is Array:
		slots = (first_slots as Array).slice(0, SLOTS)
	while slots.size() < SLOTS:
		slots.append(null)
	var parties: Array = [{"id": 1, "slots": slots}]
	for i in range(2, 6):
		parties.append({"id": i, "slots": [null, null, null, null, null]})
	return {"parties": parties, "activePartyId": 1, "nextPartyId": 6}


static func commander_uid(c: Object) -> Variant:
	for ch: Variant in Profile.get_roster(c)["chars"]:
		if typeof(ch) == TYPE_DICTIONARY and Js.same(ch.get("cls"), c.D["COMMANDER_CLS"]):
			return ch["uid"]
	return null


## 지휘관은 전투에 나가지 않음 → 모든 파티에서 빼고 빈 칸은 뒤로 (바뀌었으면 true)
static func drop_commander(c: Object, data: Variant) -> bool:
	var cu: Variant = commander_uid(c)
	if cu == null or typeof(data) != TYPE_DICTIONARY or not Js.truthy(data.get("parties")):
		return false
	var changed := false
	for p: Variant in data["parties"]:
		if typeof(p) != TYPE_DICTIONARY or typeof(p.get("slots")) != TYPE_ARRAY or Js.index_of(p["slots"], cu) == -1:
			continue
		var ns: Array = []
		for s: Variant in p["slots"]:
			if not Js.same(s, cu):
				ns.append(s)
		while ns.size() < SLOTS:
			ns.append(null)
		p["slots"] = ns
		changed = true
	return changed


static func save_parties(c: Object, data: Dictionary) -> void:
	drop_commander(c, data)
	c.store.set_json(PARTIES_KEY, data)


static func _load_legacy_party(c: Object) -> Array:
	var p: Variant = c.store.get_json(PARTY_KEY)
	if not (p is Array):
		return []
	var out: Array = []
	for u: Variant in p:
		var iu: Variant = to_int_id(u)
		out.append(iu if iu != null and int(iu) > 0 else null)
	return out


## 숫자로 (JS +v 처럼: 숫자 · 숫자 글자 "3" → 3, 그 밖은 null)
static func to_number(v: Variant) -> Variant:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			return null if is_nan(float(v)) or is_inf(float(v)) else v
		TYPE_STRING:
			var t := String(v).strip_edges()
			if t.is_valid_int():
				return t.to_int()
			if t.is_valid_float():
				return t.to_float()
	return null


## uid·id 처럼 정수여야 하는 값 (정수 값이 아니면 null)
static func to_int_id(v: Variant) -> Variant:
	var n: Variant = to_number(v)
	if n == null or float(n) != floorf(float(n)):
		return null
	return int(n)


## (4a, 웹보다 관대하게) 파티 저장값의 잘못된 항목만 고침 — 바뀌었으면 true
##  파티 목록의 사전이 아닌 항목은 뺌, id 는 숫자로(글자 "2" → 2, 숫자가 아니면 겹치지 않는 새 번호),
##  칸은 배열 5칸(정수 uid 또는 null — 숫자 글자는 숫자로, 그 밖은 null), 활성 id·nextPartyId 도 숫자로.
##  올바른 세이브는 손대지 않음 (웹과 같은 결과)
static func normalize_parties(d: Dictionary) -> bool:
	if not (d.get("parties") is Array):
		return false
	var changed := false
	var keep: Array = []
	for p: Variant in d["parties"]:
		if typeof(p) == TYPE_DICTIONARY:
			keep.append(p)
		else:
			changed = true
	var used: Dictionary = {}
	var fix_id: Array = []
	for p2: Dictionary in keep:
		var raw: Variant = p2.get("id")
		var id: Variant = to_number(raw)
		if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
			id = raw
		if id == null or used.has(float(id)):
			fix_id.append(p2)
			continue
		if typeof(raw) != typeof(id):
			p2["id"] = id
			changed = true
		used[float(id)] = true
		var sl: Variant = p2.get("slots")
		var ns: Array = []
		var src: Array = sl if sl is Array else []
		if not (sl is Array):
			changed = true
		for u: Variant in src:
			if u == null:
				ns.append(null)
				continue
			var iu: Variant = to_int_id(u)
			if iu == null or int(iu) <= 0:
				ns.append(null)
				changed = true
			else:
				if typeof(u) == TYPE_STRING:
					changed = true
				ns.append(iu)
		if ns.size() != SLOTS:
			changed = true
		while ns.size() < SLOTS:
			ns.append(null)
		p2["slots"] = ns.slice(0, SLOTS)
	for p3: Dictionary in fix_id:
		var nid := 1
		while used.has(float(nid)):
			nid += 1
		used[float(nid)] = true
		p3["id"] = nid
		var sl2: Variant = p3.get("slots")
		var ns2: Array = []
		for u2: Variant in (sl2 if sl2 is Array else []):
			var iu2: Variant = to_int_id(u2)
			ns2.append(iu2 if iu2 != null and int(iu2) > 0 else null)
		while ns2.size() < SLOTS:
			ns2.append(null)
		p3["slots"] = ns2.slice(0, SLOTS)
		changed = true
	if changed:
		d["parties"] = keep
	var ap: Variant = d.get("activePartyId")
	if typeof(ap) == TYPE_STRING and to_number(ap) != null:
		d["activePartyId"] = to_number(ap)
		changed = true
	var npi: Variant = d.get("nextPartyId")
	if typeof(npi) == TYPE_STRING and to_number(npi) != null:
		d["nextPartyId"] = to_number(npi)
		changed = true
	return changed


## storage.js loadParties (활성 id 보정 · 지휘관 빼기 · 옛 1파티 세이브 5파티로 · 레거시 game_party 옮기기)
static func load_parties(c: Object) -> Dictionary:
	var d: Variant = c.store.get_json(PARTIES_KEY)
	if typeof(d) == TYPE_DICTIONARY and normalize_parties(d):
		save_parties(c, d)
	if typeof(d) == TYPE_DICTIONARY and d.get("parties") is Array and not (d["parties"] as Array).is_empty():
		var has_active := false
		for p: Variant in d["parties"]:
			if typeof(p) == TYPE_DICTIONARY and Js.same(p.get("id"), d.get("activePartyId")):
				has_active = true
		if not has_active:
			d["activePartyId"] = d["parties"][0].get("id")
		if drop_commander(c, d):
			save_parties(c, d)
		var npi: Variant = d.get("nextPartyId")
		if typeof(npi) != TYPE_INT and typeof(npi) != TYPE_FLOAT:
			var mx := -INF
			for p2: Variant in d["parties"]:
				var v := Js.num(p2.get("id")) if typeof(p2) == TYPE_DICTIONARY else 0.0
				mx = maxf(mx, v if not is_nan(v) and v != 0.0 else 0.0)
			var nxt := int(mx) + 1
			while (d["parties"] as Array).size() < SLOTS:
				d["parties"].append({"id": nxt, "slots": [null, null, null, null, null]})
				nxt += 1
			d["nextPartyId"] = nxt
			save_parties(c, d)
		return d
	var nd := create_default_parties(_load_legacy_party(c))
	save_parties(c, nd)
	c.store.remove(PARTY_KEY)
	return nd


static func find_party(data: Dictionary, pid: Variant) -> Variant:
	for p: Variant in data.get("parties", []):
		if typeof(p) == TYPE_DICTIONARY and Js.same(p.get("id"), pid):
			return p
	return null


## getActiveParty — 활성 파티의 uid (빈 칸 빼고)
static func get_active_party(c: Object) -> Array:
	var data := load_parties(c)
	var ap: Variant = find_party(data, data.get("activePartyId"))
	var out: Array = []
	if ap != null and ap.get("slots") is Array:
		for u: Variant in ap["slots"]:
			if u != null:
				out.append(u)
	return out


static func set_active(c: Object, data: Dictionary, pid: Variant) -> void:
	data["activePartyId"] = pid
	save_parties(c, data)


static func count_filled(party: Variant) -> int:
	var n := 0
	if party != null:
		for u: Variant in party.get("slots", []):
			if u != null:
				n += 1
	return n


## removeFromSlot
static func remove_from_slot(c: Object, data: Dictionary, pid: Variant, idx: int) -> void:
	var p: Variant = find_party(data, pid)
	if p == null:
		return
	p["slots"][idx] = null
	save_parties(c, data)


## selectUnitForSlot — 이미 다른 칸에 있으면 그 칸을 비우고 이 칸에
static func select_unit_for_slot(c: Object, data: Dictionary, pid: Variant, idx: int, uid: Variant) -> void:
	var p: Variant = find_party(data, pid)
	if p == null:
		return
	var slots: Array = p["slots"]
	for i in slots.size():
		if Js.same(slots[i], uid):
			slots[i] = null
			break
	slots[idx] = uid
	save_parties(c, data)


## party-select init: 죽은 클랜원을 모든 파티 칸에서 빼고 저장
static func drop_dead(c: Object, data: Dictionary) -> void:
	var by_uid := roster_map(c)
	for p: Variant in data["parties"]:
		var ns: Array = []
		for u: Variant in p["slots"]:
			if u == null or not Js.truthy(u):
				ns.append(null)
				continue
			var ch: Variant = by_uid.get(u)
			ns.append(null if (ch != null and Js.truthy(ch.get("dead"))) else u)
		p["slots"] = ns
	save_parties(c, data)


## party-select init: 인벤토리 장비의 equipped 필드 정규화 (없으면 null). 인벤토리는 equip.js loadInventory 처럼 옛 장비 전환을 거쳐 읽음
static func normalize_equipped(c: Object) -> void:
	var inv := Profile.load_inventory(c)
	var changed := false
	for it: Variant in inv:
		if typeof(it) == TYPE_DICTIONARY and it.get("type") == "equip" and not it.has("equipped"):
			it["equipped"] = null
			changed = true
	if changed:
		Profile.save_inventory(c, inv)


static func roster_map(c: Object) -> Dictionary:
	var m: Dictionary = {}
	for ch: Variant in Profile.get_roster(c)["chars"]:
		if typeof(ch) == TYPE_DICTIONARY:
			m[ch.get("uid")] = ch
	return m


## 편성에 쓸 수 있는 클랜원 (살아 있음 · 소환수 아님 · 지휘관 아님) — 로스터 순서 그대로
static func available(c: Object) -> Array:
	var out: Array = []
	for ch: Variant in Profile.get_roster(c)["chars"]:
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		if Js.truthy(ch.get("dead")) or str(ch.get("cls", "")).begins_with("summon_") or Js.same(ch.get("cls"), c.D["COMMANDER_CLS"]):
			continue
		out.append(ch)
	return out


## 필터 탭: 가진 직업군만 (고정 순서 beginner · melee · ranged · support)
static func groups_present(c: Object) -> Array:
	var have: Dictionary = {}
	var gm: Dictionary = c.D["CLASS_GROUP_MAP"]
	for ch: Dictionary in available(c):
		var g: Variant = gm.get(ch["cls"])
		if g != null:
			have[g] = true
	var out: Array = []
	for g2: String in GROUP_ORDER:
		if have.has(g2):
			out.append(g2)
	return out


## renderUnitCards: 필터('all' | group_x | role_x | cls_x) → 정렬(이 파티에 있는 클랜원 먼저 → 레벨 높은 순, 같으면 원래 순서)
static func unit_list(c: Object, data: Dictionary, pid: Variant, filter: String) -> Array:
	var alive := available(c)
	if filter != "all":
		var keep: Array = []
		for ch: Dictionary in alive:
			var ok := true
			if filter.begins_with("group_"):
				ok = c.D["CLASS_GROUP_MAP"].get(ch["cls"]) == filter.trim_prefix("group_")
			elif filter.begins_with("role_"):
				ok = c.D["ROLE_MAP"].get(ch["cls"]) == filter.trim_prefix("role_")
			elif filter.begins_with("cls_"):
				ok = Js.same(ch["cls"], filter.trim_prefix("cls_"))
			if ok:
				keep.append(ch)
		alive = keep
	var inp: Dictionary = {}
	var p: Variant = find_party(data, pid)
	if p != null:
		for u: Variant in p["slots"]:
			if Js.truthy(u):
				inp[u] = true
	return Js.stable_sort(alive, func(a: Dictionary, b: Dictionary) -> float:
		var ia := 1 if inp.has(a["uid"]) else 0
		var ib := 1 if inp.has(b["uid"]) else 0
		if ib != ia:
			return float(ib - ia)
		return Js.num(b.get("lv")) - Js.num(a.get("lv")))


# ── 스킬 (character.js getCharSkills · getCharSkillLv) ──

static func char_skills(c: Object, cls: String) -> Array:
	var sk: Variant = c.D["SKILLS"].get(cls)
	if sk == null:
		return []
	var arr: Array = (sk as Array).duplicate() if sk is Array else [sk]
	var L: Dictionary = c.D.get("LEARNABLE_SKILLS", {})
	for id: String in L.keys():
		if Js.same(L[id].get("cls"), cls):
			arr.append(L[id])
	return arr


static func char_skill_lv(c: Object, ch: Dictionary, skill_id: String) -> float:
	if typeof(ch.get("skillLv")) == TYPE_DICTIONARY and Js.truthy(ch["skillLv"].get(skill_id)):
		return Js.num(ch["skillLv"][skill_id])
	if (c.D.get("LEARNABLE_SKILLS", {}) as Dictionary).has(skill_id):
		return 0.0
	return 1.0


## 직업명 옆·카드에 보이는 배운 스킬 [{id, lv}]
static func learned_skills(c: Object, ch: Dictionary) -> Array:
	var out: Array = []
	for sk: Variant in char_skills(c, str(ch["cls"])):
		if typeof(sk) != TYPE_DICTIONARY:
			continue
		var lv := char_skill_lv(c, ch, str(sk["id"]))
		if lv > 0.0:
			out.append({"id": str(sk["id"]), "lv": lv, "icon": str(sk.get("icon", ""))})
	return out


# ── 출격 ──

static func load_nav(c: Object) -> Variant:
	return c.store.get_json(NAV_KEY)


static func save_nav(c: Object, nav: Dictionary) -> void:
	c.store.set_json(NAV_KEY, nav)


static func clear_nav(c: Object) -> void:
	c.store.remove(NAV_KEY)


static func can_start_flag(c: Object) -> bool:
	return str(c.store.get_str(CAN_START_KEY)) == "true"


static func set_can_start(c: Object, on: bool) -> void:
	c.store.set_str(CAN_START_KEY, "true" if on else "false")


## stage-select _launchStage: 활성 파티의 산 클랜원이 MIN_P 이상이면 바로 전투, 아니면 편성 화면(출격 단추 켬)
##  → { to: "battle" | "party", nav } (nav 는 game_nav 에 저장한 값)
static func launch_stage(c: Object, stage: Dictionary, practice: bool) -> Dictionary:
	var by_uid := roster_map(c)
	var party: Array = []
	for u: Variant in get_active_party(c):
		var ch: Variant = by_uid.get(u)
		if ch != null and not Js.truthy(ch.get("dead")):
			party.append(u)
	if party.size() >= int(c.D["MIN_P"]):
		var nav := {"cStage": stage, "party": party, "practiceMode": practice}
		save_nav(c, nav)
		return {"to": "battle", "nav": nav}
	var nav2 := {"cStage": stage, "practiceMode": practice}
	save_nav(c, nav2)
	set_can_start(c, true)
	return {"to": "party", "nav": nav2}


## battle/end.js goNextStage (연습 모드 값은 넘기지 않음 = 일반)
static func next_stage(c: Object, stage: Dictionary) -> Dictionary:
	var by_uid := roster_map(c)
	var party: Array = []
	for u: Variant in get_active_party(c):
		var ch: Variant = by_uid.get(u)
		if ch != null and not Js.truthy(ch.get("dead")):
			party.append(u)
	if party.size() >= int(c.D["MIN_P"]):
		var nav := {"cStage": stage, "party": party}
		save_nav(c, nav)
		return {"to": "battle", "nav": nav}
	var nav2 := {"cStage": stage}
	save_nav(c, nav2)
	set_can_start(c, true)   # 웹 end.js goNextStage 도 같이 고침 (예전엔 출격 단추가 안 켜져 막다른 길)
	return {"to": "party", "nav": nav2}


## party-select confirmP: 활성 파티가 MIN_P 이상이면 nav 를 써서 전투로 (아니면 null)
static func confirm_start(c: Object, stage: Variant, practice: bool) -> Variant:
	var ap := get_active_party(c)
	if ap.size() < int(c.D["MIN_P"]):
		return null
	var nav := {"cStage": stage, "party": ap, "practiceMode": practice}
	save_nav(c, nav)
	return nav


## nav.cStage → 전투 엔진 스테이지 지정 ({id} 또는 요일 던전 {daily:{cls, tier(번호)}})
static func stage_spec(c: Object, st: Variant) -> Dictionary:
	if typeof(st) != TYPE_DICTIONARY:
		return {}
	if typeof(st.get("daily")) == TYPE_DICTIONARY:
		var tiers: Array = c.D["DAILY"]["tiers"]
		var ti := 0
		for i in tiers.size():
			if tiers[i]["key"] == st["daily"].get("tier"):
				ti = i
		return {"daily": {"cls": str(st["daily"]["cls"]), "tier": ti}}
	return {"id": int(st["id"])}
