extends RefCounted
## 아카데미 규칙 (4b-2) — 웹 js/academy.js (+ character.js _rollPotentialWithGrade)
##  모두 정적 함수, 첫 인자 c = ctx.gd. 저장 키·형식·난수 순서는 웹과 같음 (tests/check_outer_4b2.gd 가 웹 코드 정답과 비교).
##   전직 : 살아 있는 노비스 + 인벤토리의 전직서(type scroll, scrollCls) 하나 → 그 직업으로. 잠재력은 지금 등급 그대로 다시 굴림,
##          능력치 = round(round(기본 × 등급 배율) + 잠재력 × (레벨 − 1)), 이동·사거리는 새 직업 기본값. 전직서는 사라짐
##   스킬북: 인벤토리의 스킬북(type 없음 · id · cls · lv) 하나를 같은 직업의 살아 있는 클랜원(그 스킬 최대 레벨 미만)에게 → 레벨 +1 (습득형은 0 → 1 = 습득)
##  웹과 다른 점 (README '4b-2'):
##   - 웹 확인 창은 잠재력을 한 번 굴려 '전직 후 예상 스탯'을 보이고, 실행 때 다시 굴려 실제 능력치가 예상과 달라짐 →
##     Godot 은 확인 창에서 굴린 잠재력(preview)을 그대로 씀 (예상 = 결과). 난수는 웹보다 한 번(잠재력 한 벌) 적게 씀
##   - 웹은 확인 창을 연 때의 인벤토리 번호로 전직서·스킬북을 지움 → Godot 은 그 번호의 물건이 맞는지 확인하고, 다르면 같은 물건을 다시 찾음
##   - (4b-2 디렉터 결정) 미리보기는 클랜원 + 대상 직업마다 **한 번만** 굴려 Store 키 gd_class_preview 에 보관 — 창을 닫았다 열거나
##     게임을 다시 켜도 같은 값 (웹은 열 때마다 다시 굴려 '다시 뽑기'가 됨). 형식·무효 규칙은 아래 PREVIEW_KEY 설명과 README

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")
const Sanctuary := preload("res://scripts/logic/sanctuary_rules.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")


static func _find(roster: Dictionary, uid: Variant) -> Variant:
	for ch: Variant in roster["chars"]:
		if typeof(ch) == TYPE_DICTIONARY and Js.same(ch.get("uid"), uid):
			return ch
	return null


# ── 전직 ──

static func novices(c: Object) -> Array:
	var out: Array = []
	for ch: Dictionary in Sanctuary.alive(c):
		if ch["cls"] == "novice":
			out.append(ch)
	return out


## 인벤토리의 전직서 [{idx, item}] (모르는 직업의 전직서는 웹 목록처럼 뺌)
static func scrolls(c: Object) -> Array:
	var out: Array = []
	var inv := Profile.load_inventory(c)
	for i in inv.size():
		var it: Variant = inv[i]
		if it is Dictionary and it.get("type") == "scroll":
			out.append({"idx": i, "item": it})
	return out


static func usable_scrolls(c: Object) -> Array:
	var out: Array = []
	for s: Dictionary in scrolls(c):
		var cls: Variant = s["item"].get("scrollCls")
		if typeof(cls) == TYPE_STRING and (c.D["JAB"] as Dictionary).has(cls):
			out.append(s)
	return out


## 전직 미리보기 (웹 previewClassChange — 잠재력을 한 번 굴림) → {} 이면 노비스가 아님
static func preview(c: Object, ch: Variant, new_cls: String) -> Dictionary:
	if not (ch is Dictionary) or ch.get("cls") != "novice" or not (c.D["JAB"] as Dictionary).has(new_cls):
		return {}
	var nd: Dictionary = c.D["JAB"][new_cls]
	var grade := Profile.pot_grade(c, ch)
	var pot := Sanctuary.roll_potential_with_grade(c, new_cls, grade)
	var gm := Sanctuary.grade_multiplier(grade)
	var lg := Js.num(ch.get("lv")) - 1.0
	var bh := Js.round_js(float(nd["base"]["hp"]) * gm)
	var ba := Js.round_js(float(nd["base"]["atk"]) * gm)
	var bd := Js.round_js(float(nd["base"]["def"]) * gm)
	return {"hp": Js.round_js(bh + float(pot["hp"]) * lg), "atk": Js.round_js(ba + float(pot["atk"]) * lg), "def": Js.round_js(bd + float(pot["def"]) * lg),
		"move": nd["base"]["move"], "range": nd["base"]["range"], "pot": pot, "grade": grade, "cls": new_cls}


# ── 미리보기 보관 (gd_class_preview) ──
##  { "<uid>": { "fp": { "lv": 레벨, "pot": 잠재력 사전 }, "cls": { "<직업>": { hp, atk, def, move, range, pot, grade, cls } } } }
##  무효 규칙: 그 uid 가 없거나 · 죽었거나 · 노비스가 아니면(전직·승급 제물로 사라짐 등) 항목을 지움.
##            레벨이나 잠재력(fp)이 바뀌면(레벨 업 · 승급) 그 클랜원의 미리보기를 모두 버리고 새로 굴림.
##            전직을 실행하면 그 클랜원 항목을 지움. 키가 비면 키를 지움.
const PREVIEW_KEY := "gd_class_preview"
const PV_FIELDS := ["hp", "atk", "def", "move", "range"]


static func _fp(ch: Dictionary) -> Dictionary:
	return {"lv": ch.get("lv"), "pot": ch.get("pot")}


static func _same_json(a: Variant, b: Variant) -> bool:
	return JsonExact.stringify(a) == JsonExact.stringify(b)


## 보관한 미리보기 하나가 쓸 수 있는 모양인지
static func pv_ok(c: Object, v: Variant, cls: String) -> bool:
	if not (v is Dictionary) or v.get("cls") != cls or not (v.get("pot") is Dictionary) or typeof(v.get("grade")) != TYPE_STRING:
		return false
	for k: String in PV_FIELDS:
		if not (typeof(v.get(k)) == TYPE_INT or typeof(v.get(k)) == TYPE_FLOAT):
			return false
	for k2: String in ["hp", "atk", "def"]:
		if not (typeof(v["pot"].get(k2)) == TYPE_INT or typeof(v["pot"].get(k2)) == TYPE_FLOAT):
			return false
	return (c.D["JAB"] as Dictionary).has(cls)


## 보관함 정리 (무효 항목 지움) → 정리된 사전. changed 면 저장
static func _kept(c: Object) -> Dictionary:
	var raw: Variant = c.store.get_json(PREVIEW_KEY)
	var all: Dictionary = raw if raw is Dictionary else {}
	var changed := not (raw is Dictionary) and raw != null
	var roster := Profile.get_roster(c)
	for k: Variant in all.keys():
		var e: Variant = all[k]
		var ch: Variant = _find(roster, int(str(k))) if str(k).is_valid_int() else null
		var bad: bool = ch == null or not Sanctuary.is_member(c, ch) or Js.truthy(ch.get("dead")) or ch.get("cls") != "novice" \
			or not (e is Dictionary) or not (e.get("cls") is Dictionary) or not _same_json(e.get("fp"), _fp(ch))
		if not bad:
			for cl: Variant in (e["cls"] as Dictionary).keys():
				if not pv_ok(c, e["cls"][cl], str(cl)):
					(e["cls"] as Dictionary).erase(cl)
					changed = true
		if bad:
			all.erase(k)
			changed = true
	if changed:
		if all.is_empty():
			c.store.remove(PREVIEW_KEY)
		else:
			c.store.set_json(PREVIEW_KEY, all)
	return all


## 확인 창 미리보기: 보관한 것이 있으면 그것, 없으면 한 번 굴려(preview) 보관 → {} 이면 노비스가 아님
static func preview_kept(c: Object, ch: Variant, new_cls: String) -> Dictionary:
	if not (ch is Dictionary) or ch.get("cls") != "novice" or not (c.D["JAB"] as Dictionary).has(new_cls):
		return {}
	var all := _kept(c)
	var key := str(int(ch["uid"]))
	var e: Variant = all.get(key)
	if e is Dictionary and pv_ok(c, e["cls"].get(new_cls), new_cls):
		return (e["cls"][new_cls] as Dictionary).duplicate(true)
	var pv := preview(c, ch, new_cls)
	if pv.is_empty():
		return pv
	if not (e is Dictionary):
		e = {"fp": Js.deep(_fp(ch)), "cls": {}}
		all[key] = e
	e["cls"][new_cls] = Js.deep(pv)
	c.store.set_json(PREVIEW_KEY, all)
	return pv


static func forget_preview(c: Object, uid: Variant) -> void:
	var raw: Variant = c.store.get_json(PREVIEW_KEY)
	if raw is Dictionary and (raw as Dictionary).has(str(uid)):
		(raw as Dictionary).erase(str(uid))
		if (raw as Dictionary).is_empty():
			c.store.remove(PREVIEW_KEY)
		else:
			c.store.set_json(PREVIEW_KEY, raw)


## 전직 실행: 확인 창의 미리보기(pv)를 그대로 적용 + 전직서 하나 지움 → { ok, reason("no_char"·"no_scroll"), old, ch }
static func change_class(c: Object, uid: Variant, pv: Dictionary, scroll_idx: int) -> Dictionary:
	var new_cls := str(pv.get("cls", ""))
	var roster := Profile.get_roster(c)
	var ch: Variant = _find(roster, uid)
	if ch == null or not Sanctuary.is_member(c, ch) or Js.truthy(ch.get("dead")) or ch.get("cls") != "novice" or not (c.D["JAB"] as Dictionary).has(new_cls):
		return {"ok": false, "reason": "no_char"}
	var inv := Profile.load_inventory(c)
	var at := -1
	if scroll_idx >= 0 and scroll_idx < inv.size() and inv[scroll_idx] is Dictionary and inv[scroll_idx].get("type") == "scroll" and inv[scroll_idx].get("scrollCls") == new_cls:
		at = scroll_idx
	else:
		for i in inv.size():
			if inv[i] is Dictionary and inv[i].get("type") == "scroll" and inv[i].get("scrollCls") == new_cls:
				at = i
				break
	if at < 0:
		return {"ok": false, "reason": "no_scroll"}
	inv.remove_at(at)
	Profile.save_inventory(c, inv)
	roster = Profile.get_roster(c)
	ch = _find(roster, uid)
	ch["cls"] = new_cls
	ch["hp"] = pv["hp"]
	ch["atk"] = pv["atk"]
	ch["def"] = pv["def"]
	ch["move"] = pv["move"]
	ch["range"] = pv["range"]
	ch["pot"] = pv["pot"]
	Profile.save_roster(c, roster)
	forget_preview(c, int(uid))
	return {"ok": true, "old": "novice", "ch": ch}


# ── 스킬북 ──

static func is_book(c: Object, it: Variant) -> bool:
	if not (it is Dictionary):
		return false
	if Js.truthy(it.get("type")) or not Js.truthy(it.get("id")) or not Js.truthy(it.get("cls")) or not it.has("lv"):
		return false
	return typeof(it["cls"]) == TYPE_STRING and (c.D["JAB"] as Dictionary).has(it["cls"]) and typeof(it["id"]) == TYPE_STRING


## 인벤토리의 스킬북 [{idx, item, has_target}]
static func books(c: Object) -> Array:
	var out: Array = []
	var inv := Profile.load_inventory(c)
	for i in inv.size():
		if is_book(c, inv[i]):
			out.append({"idx": i, "item": inv[i], "has_target": not targets(c, inv[i]).is_empty()})
	return out


## 스킬북을 쓸 수 있는 클랜원 (같은 직업 · 살아 있음 · 그 스킬 최대 레벨 미만)
static func targets(c: Object, book: Dictionary) -> Array:
	var out: Array = []
	var mx := float(c.D["MAX_SKILL_LV"])
	for ch: Dictionary in Sanctuary.alive(c):
		if Js.same(ch["cls"], book.get("cls")) and PartyRules.char_skill_lv(c, ch, str(book["id"])) < mx:
			out.append(ch)
	return out


## 스킬북 사용 → { ok, reason, new_learn, lv, ch }
static func use_book(c: Object, idx: int, uid: Variant, book_ref: Dictionary = {}) -> Dictionary:
	var inv := Profile.load_inventory(c)
	var at := idx
	if not (at >= 0 and at < inv.size() and is_book(c, inv[at]) and (book_ref.is_empty() or (Js.same(inv[at].get("id"), book_ref.get("id")) and Js.same(inv[at].get("cls"), book_ref.get("cls"))))):
		at = -1
		if not book_ref.is_empty():
			for i in inv.size():
				if is_book(c, inv[i]) and Js.same(inv[i].get("id"), book_ref.get("id")) and Js.same(inv[i].get("cls"), book_ref.get("cls")):
					at = i
					break
	if at < 0:
		return {"ok": false, "reason": "no_book"}
	var book: Dictionary = inv[at]
	var roster := Profile.get_roster(c)
	var ch: Variant = _find(roster, uid)
	if ch == null or not Sanctuary.is_member(c, ch) or Js.truthy(ch.get("dead")) or not Js.same(ch.get("cls"), book["cls"]) \
			or PartyRules.char_skill_lv(c, ch, str(book["id"])) >= float(c.D["MAX_SKILL_LV"]):
		return {"ok": false, "reason": "no_target"}
	var sid := str(book["id"])
	if typeof(ch.get("skillLv")) != TYPE_DICTIONARY:
		ch["skillLv"] = {}
	var learnable := (c.D.get("LEARNABLE_SKILLS", {}) as Dictionary).has(sid)
	var slv: Dictionary = ch["skillLv"]
	var new_learn := learnable and not Js.truthy(slv.get(sid))
	if not Js.truthy(slv.get(sid)):
		slv[sid] = 0 if learnable else 1
	slv[sid] = int(Js.num(slv[sid])) + 1
	inv.remove_at(at)
	Profile.save_roster(c, roster)
	Profile.save_inventory(c, inv)
	return {"ok": true, "new_learn": new_learn, "lv": slv[sid], "ch": ch, "skill": sid}
