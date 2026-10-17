extends RefCounted
## 이상한 값이 든 세이브 다듬기 (4a, 디렉터 결정: 웹보다 관대하게, 하지만 절대 오류 없이)
##  바깥 화면에 들어올 때마다(screen_base._ready, 규칙보다 먼저) 한 번 부른다. 올바른 세이브는 손대지 않으며(바뀐 키만 다시 씀),
##  잘못된 항목만 걸러내거나 기본값으로 바꾼다 — 웹처럼 파티를 통째로 초기화하는 식의 처리는 하지 않음.
##  목적: 규칙·화면 코드가 형을 믿고 쓸 수 있게 (GDScript 는 형이 다른 값끼리 ==·!= 만 해도 오류)
##   - 로스터: 사전이 아닌 항목·정수가 아닌 uid 는 뺌, 직업이 글자가 아니거나 모르는 직업이면 novice(웹 점검과 같음),
##     숫자 칸(lv·exp·hp·atk·def·move·range·actionRec)·잠재력·성별·이름·장비·스킬 레벨은 형이 맞지 않으면 기본값·지움
##   - 파티: party_rules.normalize_parties (null·숫자 항목 빼기, 글자 id·칸은 숫자로)
##   - game_save: 사전이 아니면 {gold:2000}, 클리어 기록의 숫자 글자는 숫자로(숫자 아닌 것은 뺌), stars 가 사전이 아니면 지움
##   - 인벤토리: 사전이 아닌 항목·쓸 수 없는 장비(부위·등급·능력치가 잘못됨) 뺌
##   - 요일 던전·본 장면·설정·출격 정보·영혼석: 형이 맞지 않는 부분만 지우거나 기본값
##   (4b-1) 상점(game_shop): 사전이 아니거나 items 가 배열이 아니면 지움(들어가면 새로 만듦), 모르는 물건·형이 틀린 물건은 뺌, ts 가 숫자가 아니면 0(→ 갱신)
##          재료(game_mats): 숫자가 아닌 값은 뺌 · 천장(game_gacha_pity): 숫자가 아니면 지움 · 편성 탭(ps_active_tab): 모르는 탭이면 지움
##          인벤토리: 장비의 옵션(subs·eOpts·fx·cOpt)·직업 제한·장착자·전설·세트·강화 보정 형 정리, 물약·전투 물약·공성·룬·전직서는 모르는 종류면 뺌
##  빈 문자열 원본("")은 없는 것으로 (웹 !raw)

const Js := preload("res://scripts/logic/js.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")

const NUM_FIELDS := ["exp", "hp", "atk", "def", "move", "range"]


static func _is_num(v: Variant) -> bool:
	return (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and not is_nan(float(v)) and not is_inf(float(v))


## 원본 읽기: [있음, JSON 으로 읽힘, 값]
static func _raw(c: Object, key: String) -> Array:
	var r: Variant = c.store.get_str(key)
	if r == null:
		return [false, true, null]
	if str(r) == "":
		c.store.remove(key)
		return [false, true, null]
	var p: Array = JsonExact.parse_ex(str(r))
	if not p[0]:
		return [true, false, null]
	return [true, true, c.store.get_json(key)]


static func _put(c: Object, key: String, before: Variant, after: Variant) -> bool:
	if JsonExact.stringify(before) == JsonExact.stringify(after):
		return false
	c.store.set_json(key, after)
	return true


## 모두 다듬기 → 바뀐 키 목록
static func sanitize(c: Object) -> Array:
	var changed: Array = []
	var tab: Variant = c.store.get_str("ps_active_tab")
	if tab != null and not ["party", "equip", "item", "enhance"].has(str(tab)):
		c.store.remove("ps_active_tab")
		changed.append("ps_active_tab")
	for k: String in ["game_roster", "game_parties", "game_save", "game_inventory", "game_daily", "game_story_seen", "game_settings", "game_nav", "game_soul", "game_party", "game_cleared",
			"game_shop", "game_mats", "game_gacha_pity", "gd_class_preview"]:
		var r := _raw(c, k)
		if not r[0]:
			continue
		if not r[1]:
			# 깨진 JSON: 로스터·파티·골드·인벤토리는 로비 점검(웹과 같은 복구)이 처리 — 나머지는 지움
			if not ["game_roster", "game_parties", "game_save", "game_inventory", "game_cleared"].has(k):
				c.store.remove(k)
				changed.append(k)
			continue
		var v: Variant = r[2]
		var before: Variant = Js.deep(v)
		var after: Variant = v
		match k:
			"game_roster":
				after = _roster(c, v)
			"game_parties":
				if v is Dictionary:
					PartyRules.normalize_parties(v)
				after = v
			"game_save":
				after = _save(v)
			"game_inventory":
				after = _inventory(c, v)
			"game_daily":
				if not (v is Dictionary):
					after = null
				elif v.has("date") and typeof(v["date"]) != TYPE_STRING:
					v.erase("date")
			"game_story_seen":
				after = v if v is Dictionary else {}
			"game_settings":
				after = _settings(v)
			"game_nav":
				after = _nav(v)
			"game_soul":
				after = _soul(v)
			"game_party":
				after = v if v is Array else null
			"game_cleared":
				after = v if v is Array else []
			"game_shop":
				after = _shop(c, v)
			"game_mats":
				after = _mats(v)
			"game_gacha_pity":
				after = v if _is_num(v) else null
			"gd_class_preview":
				after = _class_preview(c, v)
		if after == null:
			c.store.remove(k)
			changed.append(k)
		elif _put(c, k, before, after):
			changed.append(k)
	return changed


static func _roster(c: Object, v: Variant) -> Variant:
	if not (v is Dictionary):
		return v   # 로비 점검이 웹처럼 새로 (지킬 것이 없음)
	var JAB: Dictionary = c.D["JAB"]
	var chars: Array = []
	var seen: Dictionary = {}
	for ch: Variant in (v.get("chars") if v.get("chars") is Array else []):
		if not (ch is Dictionary):
			continue
		var uid: Variant = PartyRules.to_int_id(ch.get("uid"))
		if uid == null or int(uid) <= 0 or seen.has(int(uid)):
			continue
		seen[int(uid)] = true
		ch["uid"] = uid
		if typeof(ch.get("cls")) != TYPE_STRING or not JAB.has(ch["cls"]):
			ch["cls"] = "novice"
		var base: Dictionary = JAB[ch["cls"]].get("base", {})
		var nid: Variant = PartyRules.to_int_id(ch.get("nameId"))
		if ch.has("nameId") and ch["nameId"] != null:
			ch["nameId"] = nid if nid != null and int(nid) >= 0 else null
		var lv: Variant = PartyRules.to_number(ch.get("lv"))
		ch["lv"] = maxi(1, int(lv)) if lv != null else 1
		for f: String in NUM_FIELDS:
			if not _is_num(ch.get(f)):
				var n: Variant = PartyRules.to_number(ch.get(f))
				ch[f] = n if n != null else (0.0 if f == "exp" else Js.num(base.get(f)))
		if ch.has("actionRec") and not _is_num(ch["actionRec"]):
			ch.erase("actionRec")
		if typeof(ch.get("dead")) != TYPE_BOOL:
			ch["dead"] = Js.truthy(ch.get("dead")) and not (typeof(ch.get("dead")) == TYPE_STRING and ch["dead"] == "false")
		if ch.has("diedAt") and not _is_num(ch["diedAt"]):
			ch.erase("diedAt")
		if ch.has("pot"):
			if not (ch["pot"] is Dictionary):
				ch.erase("pot")
			else:
				for pk: String in ["hp", "atk", "def"]:
					if not _is_num(ch["pot"].get(pk)):
						var pn: Variant = PartyRules.to_number(ch["pot"].get(pk))
						ch["pot"][pk] = pn if pn != null else 0.5
				if ch["pot"].has("actionRec") and not _is_num(ch["pot"]["actionRec"]):
					ch["pot"].erase("actionRec")
		# 성별이 없으면 그대로 둔다 — 로비의 migrate_gender(웹 index.js 규칙)가 무작위로 채움
		if ch.has("gender"):
			var gd: Variant = ch["gender"]
			if typeof(gd) != TYPE_STRING or not ["m", "f"].has(gd):
				ch.erase("gender")
		if ch.has("customName") and ch["customName"] != null and typeof(ch["customName"]) != TYPE_STRING:
			ch["customName"] = str(ch["customName"]) if _is_num(ch["customName"]) else null
		if ch.has("setup") and typeof(ch["setup"]) != TYPE_BOOL:
			ch["setup"] = Js.truthy(ch["setup"])
		if ch.has("equip"):
			if not (ch["equip"] is Dictionary):
				ch.erase("equip")
			else:
				for sk: Variant in (ch["equip"] as Dictionary).keys():
					var e: Variant = ch["equip"][sk]
					if e != null and typeof(e) != TYPE_STRING:
						if _is_num(e):
							ch["equip"][sk] = str(int(e)) if float(e) == floorf(float(e)) else str(e)
						else:
							ch["equip"][sk] = null
		if ch.has("skillLv"):
			if not (ch["skillLv"] is Dictionary):
				ch.erase("skillLv")
			else:
				for sid: Variant in (ch["skillLv"] as Dictionary).keys():
					if not _is_num(ch["skillLv"][sid]):
						ch["skillLv"].erase(sid)
		chars.append(ch)
	v["chars"] = chars
	if not _is_num(v.get("nextId")):
		var nid2: Variant = PartyRules.to_int_id(v.get("nextId"))
		if nid2 != null:
			v["nextId"] = nid2
		elif v.has("nextId") or not chars.is_empty():
			var mx := 0
			for ch2: Dictionary in chars:
				mx = maxi(mx, int(ch2["uid"]))
			v["nextId"] = mx + 1
	return v


static func _save(v: Variant) -> Variant:
	if not (v is Dictionary):
		return {"gold": 2000.0}
	if v.has("gold") and not _is_num(v["gold"]):
		var g: Variant = PartyRules.to_number(v["gold"])
		v["gold"] = g if g != null else 2000.0
	if v.has("cleared"):
		var out: Array = []
		for x: Variant in (v["cleared"] if v["cleared"] is Array else []):
			var n: Variant = PartyRules.to_int_id(x)
			if n != null:
				out.append(n)
		v["cleared"] = out
	if v.has("stars"):
		if not (v["stars"] is Dictionary):
			v.erase("stars")
		else:
			for sk: Variant in (v["stars"] as Dictionary).keys():
				if not (v["stars"][sk] is Array):
					v["stars"].erase(sk)
	return v


static func _inventory(c: Object, v: Variant) -> Variant:
	if not (v is Array):
		return []
	var out: Array = []
	for it: Variant in v:
		if not (it is Dictionary):
			continue
		var ty: Variant = it.get("type")
		if ty != null and typeof(ty) != TYPE_STRING:
			continue
		if ty == null:
			# 스킬북 {id, cls, lv} (웹 점검과 같은 조건 + 글자 형)
			if typeof(it.get("id")) == TYPE_STRING and typeof(it.get("cls")) == TYPE_STRING:
				out.append(it)
			continue
		if ty == "equip":
			var ok: bool = typeof(it.get("slot")) == TYPE_STRING and (c.D["EQUIP_SLOTS"] as Array).has(it["slot"]) \
				and typeof(it.get("rarity")) == TYPE_STRING and (c.D["RARITY"] as Dictionary).has(it["rarity"]) \
				and it.get("stats") is Dictionary and typeof(it.get("templateId")) == TYPE_STRING \
				and (typeof(it.get("eid")) == TYPE_STRING or _is_num(it.get("eid")))
			if not ok:
				continue
			for st: Variant in (it["stats"] as Dictionary).keys():
				if not _is_num(it["stats"][st]):
					it["stats"].erase(st)
			if it.has("enhanceLv") and not _is_num(it["enhanceLv"]):
				var en: Variant = PartyRules.to_number(it["enhanceLv"])
				it["enhanceLv"] = en if en != null else 0.0
			if it.has("armorType") and it["armorType"] != null and typeof(it["armorType"]) != TYPE_STRING:
				it.erase("armorType")
			_equip_fields(c, it)
		elif ty == "potion" or ty == "battle_potion":
			if typeof(it.get("potionId")) != TYPE_STRING:
				continue
			if ty == "battle_potion" and not (c.D["BATTLE_POTIONS"] as Dictionary).has(it["potionId"]):
				continue
			if ty == "potion" and not _is_num(it.get("exp")):
				var ex: Variant = PartyRules.to_number(it.get("exp"))
				it["exp"] = ex if ex != null else 0.0
		elif ty == "siege":
			var known := false
			for sd: Dictionary in c.D["SIEGE_ITEMS"]:
				if Js.same(sd["id"], it.get("siegeId")):
					known = true
			if not known:
				continue
		elif ty == "rune":
			if typeof(it.get("enchant")) != TYPE_STRING or not (c.D["ENCHANTS"] as Dictionary).has(it["enchant"]):
				continue
		elif ty == "scroll":
			if typeof(it.get("scrollCls")) != TYPE_STRING:
				continue
		if it.has("quantity") and it["quantity"] != null and not _is_num(it["quantity"]):
			it.erase("quantity")
		out.append(it)
	return out


## 장비 옵션·부가 칸 형 정리 (규칙·화면이 형을 믿고 씀)
static func _equip_fields(c: Object, it: Dictionary) -> void:
	var FX: Dictionary = c.D["GEAR_FX"]
	var opt_ok := func(o: Variant) -> bool: return o is Dictionary and typeof(o.get("id")) == TYPE_STRING and FX.has(o["id"]) and _is_num(o.get("v"))
	if it.has("subs"):
		if not (it["subs"] is Array):
			it["subs"] = []
		else:
			var keep: Array = []
			for sub: Variant in it["subs"]:
				if opt_ok.call(sub):
					keep.append(sub)
			if keep.size() != (it["subs"] as Array).size():
				it["subs"] = keep
	if it.has("eOpts"):
		if not (it["eOpts"] is Dictionary):
			it["eOpts"] = {}
		else:
			for k: Variant in (it["eOpts"] as Dictionary).keys():
				var o: Variant = it["eOpts"][k]
				if o != null and not opt_ok.call(o):
					it["eOpts"].erase(k)
	for f: String in ["fx", "cOpt"]:
		if it.has(f) and it[f] != null and not opt_ok.call(it[f]):
			it[f] = null
	if it.get("cOpt") is Dictionary and typeof(it["cOpt"].get("cls")) != TYPE_STRING:
		it["cOpt"] = null
	if it.has("clsRestrict") and it["clsRestrict"] != null:
		if not (it["clsRestrict"] is Array):
			it.erase("clsRestrict")
		else:
			var cl: Array = []
			for x: Variant in it["clsRestrict"]:
				if typeof(x) == TYPE_STRING:
					cl.append(x)
			if cl.size() != (it["clsRestrict"] as Array).size():
				it["clsRestrict"] = cl
	if it.has("equipped") and it["equipped"] != null:
		var eu: Variant = PartyRules.to_int_id(it["equipped"])
		if typeof(it["equipped"]) == TYPE_BOOL or eu == null:
			it["equipped"] = null
		elif not _is_num(it["equipped"]):
			it["equipped"] = eu
	if it.has("legend") and it["legend"] != null and not (typeof(it["legend"]) == TYPE_STRING and (c.D["LEGENDS"] as Dictionary).has(it["legend"])):
		it["legend"] = null
	if it.has("setCls") and it["setCls"] != null and not (typeof(it["setCls"]) == TYPE_STRING and (c.D["CLASS_SETS"] as Dictionary).has(it["setCls"])):
		it.erase("setCls")
	if it.has("setId") and it["setId"] != null and typeof(it["setId"]) != TYPE_STRING:
		it["setId"] = null
	if it.has("hand") and it["hand"] != null and typeof(it["hand"]) != TYPE_STRING:
		it["hand"] = null
	if it.has("enhanceBonus") and not _is_num(it["enhanceBonus"]):
		it["enhanceBonus"] = 0.0
	if it.has("enhanceLv") and _is_num(it["enhanceLv"]) and float(it["enhanceLv"]) < 0.0:
		it["enhanceLv"] = 0.0
	if it.has("broken") and typeof(it["broken"]) != TYPE_BOOL:
		it["broken"] = Js.truthy(it["broken"])


## (4b-1) 상점 저장: 형이 틀린 물건만 뺌. 통째로 쓸 수 없으면 null (지움 → 들어갈 때 새 상점)
static func _shop(c: Object, v: Variant) -> Variant:
	if not (v is Dictionary) or not (v.get("items") is Array):
		return null
	if not _is_num(v.get("ts")):
		v["ts"] = 0.0
	var JAB: Dictionary = c.D["JAB"]
	var keep: Array = []
	for it: Variant in v["items"]:
		if not (it is Dictionary) or not _is_num(it.get("cost")):
			continue
		var ty: String = str(it["type"]) if typeof(it.get("type")) == TYPE_STRING else ("char" if it.get("type") == null else "")
		var ok := false
		match ty:
			"char":
				ok = typeof(it.get("cls")) == TYPE_STRING and JAB.has(it["cls"]) and JAB[it["cls"]].get("growth") is Dictionary and it.get("pot") is Dictionary
				if ok:
					for pk: String in ["hp", "atk", "def", "actionRec"]:
						if not _is_num(it["pot"].get(pk)):
							ok = false
				if ok and it.has("name") and it["name"] != null and typeof(it["name"]) != TYPE_STRING:
					it["name"] = str(it["name"]) if _is_num(it["name"]) else null
				if ok and it.has("gender") and not ["m", "f"].has(it["gender"]):
					it.erase("gender")
			"skillbook":
				ok = typeof(it.get("skillId")) == TYPE_STRING and (c.D["LEARNABLE_SKILLS"] as Dictionary).has(it["skillId"]) and typeof(it.get("cls")) == TYPE_STRING
			"soulstone":
				ok = typeof(it.get("cls")) == TYPE_STRING
			"scroll":
				ok = typeof(it.get("scrollCls")) == TYPE_STRING and JAB.has(it["scrollCls"])
			"potion":
				ok = typeof(it.get("potionId")) == TYPE_STRING and _is_num(it.get("exp"))
			"battle_potion":
				ok = typeof(it.get("potionId")) == TYPE_STRING and (c.D["BATTLE_POTIONS"] as Dictionary).has(it["potionId"])
			"siege":
				for sd: Dictionary in c.D["SIEGE_ITEMS"]:
					if Js.same(sd["id"], it.get("siegeId")):
						ok = true
		if not ok:
			continue
		if it.has("sold") and typeof(it["sold"]) != TYPE_BOOL:
			it["sold"] = Js.truthy(it["sold"])
		if it.has("quantity") and not _is_num(it["quantity"]):
			it["quantity"] = 1
		keep.append(it)
	v["items"] = keep
	return v


static func _mats(v: Variant) -> Variant:
	if not (v is Dictionary):
		return {}
	for k: Variant in (v as Dictionary).keys():
		if not _is_num(v[k]):
			v.erase(k)
	return v


static func _settings(v: Variant) -> Variant:
	if not (v is Dictionary):
		return null
	if v.has("language") and typeof(v["language"]) != TYPE_STRING:
		v.erase("language")
	return v


static func _nav(v: Variant) -> Variant:
	if not (v is Dictionary) or not (v.get("cStage") is Dictionary):
		return null
	var st: Dictionary = v["cStage"]
	if st.get("daily") is Dictionary:
		if typeof(st["daily"].get("cls")) != TYPE_STRING or typeof(st["daily"].get("tier")) != TYPE_STRING:
			return null
	else:
		var id: Variant = PartyRules.to_int_id(st.get("id"))
		if id == null:
			return null
		st["id"] = id
	if v.has("party") and not (v["party"] is Array):
		v.erase("party")
	elif v.has("party"):
		var p: Array = []
		for u: Variant in v["party"]:
			var iu: Variant = PartyRules.to_int_id(u)
			if iu != null:
				p.append(iu)
		v["party"] = p
	if v.has("practiceMode") and typeof(v["practiceMode"]) != TYPE_BOOL:
		v["practiceMode"] = Js.truthy(v["practiceMode"])
	return v


static func _soul(v: Variant) -> Variant:
	if not (v is Dictionary):
		return {"stones": {}, "frags": {}}
	for b: String in ["stones", "frags"]:
		if not (v.get(b) is Dictionary):
			v[b] = {}
		for k: Variant in (v[b] as Dictionary).keys():
			if not _is_num(v[b][k]):
				v[b].erase(k)
	return v


## (4b-2) 전직 미리보기 보관함: 사전이 아니면 지움, 모양이 틀린 항목·직업만 뺌 (오래된 uid·레벨 변화 같은 '무효'는 academy_rules 가 쓸 때 정리)
static func _class_preview(c: Object, v: Variant) -> Variant:
	if not (v is Dictionary):
		return null
	var AR: GDScript = load("res://scripts/logic/academy_rules.gd")
	for k: Variant in (v as Dictionary).keys():
		var e: Variant = v[k]
		if not str(k).is_valid_int() or not (e is Dictionary) or not (e.get("fp") is Dictionary) or not (e.get("cls") is Dictionary):
			v.erase(k)
			continue
		for cl: Variant in (e["cls"] as Dictionary).keys():
			if not bool(AR.call("pv_ok", c, e["cls"][cl], str(cl))):
				(e["cls"] as Dictionary).erase(cl)
	return null if (v as Dictionary).is_empty() else v
