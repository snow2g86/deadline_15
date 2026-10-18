extends RefCounted
## 성소 규칙 (4b-2) — 웹 js/sanctuary.js + js/common/soul.js(Soul) + js/common/character.js(_rollPotentialWithGrade · gradeMultiplier) + js/logic/hazards.js(Rune.apply)
##  모두 정적 함수, 첫 인자 c = ctx.gd. 저장 키·형식·난수 순서는 웹과 같음 (tests/check_outer_4b2.gd 가 node 로 돌린 웹 코드와 비교).
##   부활 : 죽은 클랜원(소환수·지휘관 제외)을 ECON.revive[0] + 레벨 × ECON.revive[1] 골드로 · 무료 부활(30분마다 1명, game_sanc_ad_cooldown)
##   승급 : 같은 직업 제물(윗등급 4점 · 같은 등급 2점 · 한 단계 아래 1점, 4점 필요) + B→A·A→S 는 그 직업 영혼석 → 잠재력 다시 굴림 · 스킬 계승(최대면 스킬북)
##   영혼석 보관함: 직업별 영혼석·조각, 조각 SOUL.fragsPerStone 개 → 영혼석 1개
##   개명 : 앞뒤 공백을 지운 이름(웹 input maxlength 10 = UTF-16 단위), 비면 원래 이름(customName 지움)
##   마법부여: 장비에 룬 1개 + ENCHANT_FEE 골드 → 방어(enchant)·공격(enchantAtk) 칸 하나씩 (같은 종류는 불가, 다른 종류는 덮어씀)
##  웹과 다른 점 (README '4b-2 웹판과 다른 점'):
##   - 제물 후보에서 빼는 '파티 편성' 은 웹이 옛 키 game_party(이미 지워진 레거시)를 봐서 늘 비어 있음 → Godot 은 지금 활성 파티(game_parties)의 클랜원과
##     (디렉터 결정) 중단된 저장 전투(gd_battle)에 나가 있는 클랜원을 뺌 (그 전투를 포기하거나 끝내면 다시 후보)
##   - 제물이 끼고 있던 장비는 웹이 그대로 두어 '없는 클랜원이 낀 장비'가 됨 → Godot 은 그 장비의 equipped 를 비움
##   - 부활: 웹은 페이지를 연 때의 골드(_gold)로 계산 → Godot 은 누를 때의 저장 골드. 없는 클랜원이면 골드를 쓰지 않음

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const EquipRules := preload("res://scripts/logic/equip_rules.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")
const LobbyRules := preload("res://scripts/logic/lobby_rules.gd")
const ResumeRules := preload("res://scripts/logic/resume_rules.gd")

const REQUIRED_POINTS := 4
const AD_KEY := "game_sanc_ad_cooldown"
const AD_COOLDOWN_MS := 30.0 * 60.0 * 1000.0
const NAME_LEN := 10


# ── 공통 ──

## 성소에서 다루는 클랜원 (사전 · 알려진 직업 · 소환수·지휘관 아님)
static func is_member(c: Object, ch: Variant) -> bool:
	return LobbyRules.is_member(c, ch) and typeof(ch.get("cls")) == TYPE_STRING and (c.D["JAB"] as Dictionary).has(ch["cls"]) and (typeof(ch.get("uid")) == TYPE_INT or typeof(ch.get("uid")) == TYPE_FLOAT)


static func _find(roster: Dictionary, uid: Variant) -> Variant:
	for ch: Variant in roster["chars"]:
		if typeof(ch) == TYPE_DICTIONARY and Js.same(ch.get("uid"), uid):
			return ch
	return null


static func gold(c: Object) -> float:
	return EquipRules.load_gold(c)


static func grade_multiplier(grade: String) -> float:
	match grade:
		"S":
			return 1.1
		"A":
			return 1.0
		"B":
			return 0.9
	return 0.8


static func next_grade(c: Object, grade: String) -> Variant:
	var order: Array = c.D["GRADE_ORDER"]
	var i := order.find(grade)
	return order[i + 1] if i >= 0 and i < order.size() - 1 else null


## character.js _rollPotential (난수 4번: hp · atk · def · actionRec)
static func roll_potential(c: Object, cls: String) -> Dictionary:
	var g: Dictionary = c.D["JAB"][cls]["growth"]
	var roll := func(mm: Array) -> float: return Js.to_fixed_num(float(mm[0]) + c.rand("_rollPotential") * (float(mm[1]) - float(mm[0])), 1)
	var hp: float = roll.call(g["hp"])
	var atk: float = roll.call(g["atk"])
	var df: float = roll.call(g["def"])
	return {"hp": hp, "atk": atk, "def": df, "actionRec": Profile.roll_action_rec(c)}


## character.js _rollPotentialWithGrade — 그 등급 범위가 나올 때까지 최대 100번, 안 되면 범위 가운데
static func roll_potential_with_grade(c: Object, cls: String, grade: String) -> Dictionary:
	var g: Dictionary = c.D["JAB"][cls]["growth"]
	var tmin := 0.85 if grade == "S" else (0.65 if grade == "A" else (0.35 if grade == "B" else 0.0))
	var tmax := 1.0 if grade == "S" else (0.85 if grade == "A" else (0.65 if grade == "B" else 0.35))
	for attempt in 100:
		var pot := roll_potential(c, cls)
		var tot := 0.0
		for k: String in ["hp", "atk", "def"]:
			var mn := float(g[k][0])
			var rng := float(g[k][1]) - mn
			tot += (float(pot[k]) - mn) / rng if rng > 0.0 else 0.5
		var avg := tot / 3.0
		if avg >= tmin and avg < tmax:
			return pot
	var mid := (tmin + tmax) / 2.0
	return {"hp": Js.to_fixed_num(float(g["hp"][0]) + (float(g["hp"][1]) - float(g["hp"][0])) * mid, 1),
		"atk": Js.to_fixed_num(float(g["atk"][0]) + (float(g["atk"][1]) - float(g["atk"][0])) * mid, 1),
		"def": Js.to_fixed_num(float(g["def"][0]) + (float(g["def"][1]) - float(g["def"][0])) * mid, 1),
		"actionRec": Profile.roll_action_rec(c)}


## 등급이 정한 새 잠재력으로 능력치 (승급·전직 공통): round(기본 × 배율 + 잠재력 × (레벨 − 1))
static func stats_with(c: Object, cls: String, grade: String, pot: Dictionary, lv: float) -> Dictionary:
	var b: Dictionary = c.D["JAB"][cls]["base"]
	var gm := grade_multiplier(grade)
	var lg := lv - 1.0
	return {"hp": Js.round_js(float(b["hp"]) * gm + float(pot["hp"]) * lg), "atk": Js.round_js(float(b["atk"]) * gm + float(pot["atk"]) * lg),
		"def": Js.round_js(float(b["def"]) * gm + float(pot["def"]) * lg)}


# ── 부활 ──

static func dead_list(c: Object) -> Array:
	var roster := Profile.get_roster(c)
	var out: Array = []
	for ch: Variant in roster["chars"]:
		if is_member(c, ch) and Js.truthy(ch.get("dead")):
			out.append(ch)
	return Js.stable_sort(out, func(a: Dictionary, b: Dictionary) -> float: return Js.num(b.get("diedAt")) - Js.num(a.get("diedAt")))


static func revive_cost(c: Object, ch: Dictionary) -> float:
	var r: Array = c.D["ECON"]["revive"]
	return float(r[0]) + Js.num(ch.get("lv")) * float(r[1])


## 골드로 부활 → true (골드 부족·없는 클랜원·살아 있음 → false, 아무것도 바꾸지 않음)
static func revive(c: Object, uid: Variant) -> bool:
	var roster := Profile.get_roster(c)
	var ch: Variant = _find(roster, uid)
	if ch == null or not is_member(c, ch) or not Js.truthy(ch.get("dead")):
		return false
	var cost := revive_cost(c, ch)
	var g := gold(c)
	if g < cost:
		return false
	Profile.save_gold(c, g - cost)
	ch["dead"] = false
	ch.erase("diedAt")
	Profile.save_roster(c, roster)
	return true


## 무료 부활 남은 시간 (ms, 0 이면 가능) — 웹 +Store.get(키) || 0 (글자·NaN 은 0)
static func ad_remain(c: Object) -> float:
	var raw: Variant = c.store.get_str(AD_KEY)
	var v := 0.0
	if raw != null:
		var s := str(raw).strip_edges()
		if s.is_valid_float():
			v = s.to_float()
		elif s == "":
			v = 0.0
	if is_nan(v) or is_inf(v):
		v = 0.0
	return maxf(0.0, AD_COOLDOWN_MS - (c.date_now() - v))


static func ad_minutes(c: Object) -> int:
	return int(ceilf(ad_remain(c) / 60000.0))


## 무료 부활 (대기 시간이 끝났을 때만) → true
static func ad_revive(c: Object, uid: Variant) -> bool:
	if ad_remain(c) > 0.0:
		return false
	var roster := Profile.get_roster(c)
	var ch: Variant = _find(roster, uid)
	if ch == null or not is_member(c, ch) or not Js.truthy(ch.get("dead")):
		return false
	c.store.set_str(AD_KEY, str(int(c.date_now())))
	ch["dead"] = false
	ch.erase("diedAt")
	Profile.save_roster(c, roster)
	return true


# ── 영혼석 (soul.js) ──

static func _soul(c: Object) -> Dictionary:
	var d: Variant = c.store.get_json(Profile.SOUL_KEY)
	if d is Dictionary and Js.truthy(d.get("stones")) and Js.truthy(d.get("frags")) and d["stones"] is Dictionary and d["frags"] is Dictionary:
		return d
	return {"stones": {}, "frags": {}}


static func soul_stones(c: Object, cls: String) -> float:
	return Js.num(_soul(c)["stones"].get(cls))


static func soul_frags(c: Object, cls: String) -> float:
	return Js.num(_soul(c)["frags"].get(cls))


static func soul_need(c: Object, grade: String) -> float:
	return Js.num((c.D["SOUL"]["promote"] as Dictionary).get(grade))


## 영혼석·조각을 하나라도 가진 직업 (웹 Object.keys(Object.assign({}, stones, frags)) 순서)
static func soul_owned(c: Object) -> Array:
	var d := _soul(c)
	var keys: Array = (d["stones"] as Dictionary).keys()
	for k: String in (d["frags"] as Dictionary).keys():
		if not keys.has(k):
			keys.append(k)
	var out: Array = []
	for k2: String in keys:
		if Js.num(d["stones"].get(k2)) + Js.num(d["frags"].get(k2)) > 0.0:
			out.append(k2)
	return out


## 조각 합치기 → 새로 만든 영혼석 수
static func soul_combine(c: Object, cls: String) -> int:
	var d := _soul(c)
	var f := Js.num(d["frags"].get(cls))
	var per := float(c.D["SOUL"]["fragsPerStone"])
	var k := int(floorf(f / per))
	if k == 0:
		return 0
	d["frags"][cls] = f - k * per
	d["stones"][cls] = Js.num(d["stones"].get(cls)) + k
	c.store.set_json(Profile.SOUL_KEY, d)
	return k


static func soul_spend(c: Object, cls: String, n: float) -> bool:
	if n == 0.0:
		return true
	var d := _soul(c)
	if Js.num(d["stones"].get(cls)) < n:
		return false
	d["stones"][cls] = Js.num(d["stones"].get(cls)) - n
	c.store.set_json(Profile.SOUL_KEY, d)
	return true


# ── 승급 ──

static func sacrifice_points(c: Object, sac_grade: String, target_grade: String) -> int:
	var order: Array = c.D["GRADE_ORDER"]
	var si := order.find(sac_grade)
	var ti := order.find(target_grade)
	if si > ti:
		return 4
	if si == ti:
		return 2
	if si == ti - 1:
		return 1
	return 0


## 살아 있는 성소 클랜원
static func alive(c: Object) -> Array:
	var out: Array = []
	for ch: Variant in Profile.get_roster(c)["chars"]:
		if is_member(c, ch) and not Js.truthy(ch.get("dead")):
			out.append(ch)
	return out


## 승급할 수 있는 클랜원 (S 가 아닌)
static func promotable(c: Object) -> Array:
	var out: Array = []
	for ch: Dictionary in alive(c):
		if Profile.pot_grade(c, ch) != "S":
			out.append(ch)
	return out


## 승급 탭을 한 번 그릴 때 함께 쓰는 값 — 로스터·활성 파티·저장 전투(gd_battle, 큰 JSON)·영혼석을 **한 번만** 읽음 (2026-10-18 성능:
##  카드마다 다시 읽어 클랜원 60명에 0.6~0.9초 걸리던 것). 저장소가 바뀌면(승급·제물) 새로 만들 것
static func promote_ctx(c: Object) -> Dictionary:
	var al := alive(c)
	var grades := {}
	for ch: Dictionary in al:
		grades[int(ch["uid"])] = Profile.pot_grade(c, ch)
	return {"alive": al, "grades": grades, "party": PartyRules.get_active_party(c) + ResumeRules.battle_uids(c), "soul": _soul(c)}


## 제물 후보 (같은 직업 · 자신 아님 · 활성 파티에 없음 · 중단된 저장 전투에 나가 있지 않음 · 점수 > 0). pc = promote_ctx (없으면 새로 읽음)
static func sacrifices(c: Object, target: Dictionary, pc: Dictionary = {}) -> Array:
	if pc.is_empty():
		pc = promote_ctx(c)
	var grades: Dictionary = pc["grades"]
	var tg := str(grades[int(target["uid"])]) if grades.has(int(target["uid"])) else Profile.pot_grade(c, target)
	var party: Array = pc["party"]
	var out: Array = []
	for ch: Dictionary in pc["alive"]:
		if Js.same(ch["uid"], target["uid"]) or not Js.same(ch["cls"], target["cls"]) or Js.index_of(party, ch["uid"]) >= 0:
			continue
		if sacrifice_points(c, str(grades[int(ch["uid"])]), tg) > 0:
			out.append(ch)
	return out


## 카드 상태: { grade, sacrifices(수), soul_need, soul_have, can }. 여러 카드를 그릴 때는 pc(promote_ctx) 하나를 함께 넘길 것
static func promote_state(c: Object, ch: Dictionary, pc: Dictionary = {}) -> Dictionary:
	if pc.is_empty():
		pc = promote_ctx(c)
	var g: String = pc["grades"].get(int(ch["uid"]), Profile.pot_grade(c, ch))
	var need := soul_need(c, g)
	var have := Js.num(pc["soul"]["stones"].get(str(ch["cls"])))
	var n := sacrifices(c, ch, pc).size()
	return {"grade": g, "sacrifices": n, "soul_need": need, "soul_have": have, "can": n > 0 and have >= need}


static func points_of(c: Object, target: Dictionary, sel: Array) -> int:
	var tg := Profile.pot_grade(c, target)
	var tot := 0
	for ch: Dictionary in sacrifices(c, target):
		if Js.index_of(sel, ch["uid"]) >= 0:
			tot += sacrifice_points(c, Profile.pot_grade(c, ch), tg)
	return tot


## 확인 창 미리보기 (웹 confirmPromote — 잠재력을 한 번 굴려 '~' 예상치를 보임, 난수를 씀) → {} 이면 할 수 없음
static func promote_preview(c: Object, uid: Variant, sel: Array) -> Dictionary:
	var target: Variant = _find(Profile.get_roster(c), uid)
	if target == null or not is_member(c, target):
		return {}
	var cur := Profile.pot_grade(c, target)
	var nx: Variant = next_grade(c, cur)
	if nx == null:
		return {}
	var cls := str(target["cls"])
	var pot := roll_potential_with_grade(c, cls, str(nx))
	var st := stats_with(c, cls, str(nx), pot, Js.num(target.get("lv")))
	var skills: Array = []
	var overflow := false
	var mx := float(c.D["MAX_SKILL_LV"])
	for sk: Variant in PartyRules.char_skills(c, cls):
		var cl := PartyRules.char_skill_lv(c, target, str(sk["id"]))
		if cl >= mx:
			overflow = true
		skills.append({"id": str(sk["id"]), "cur": cl, "new": minf(cl + sel.size(), mx)})
	return {"cur": cur, "next": nx, "hp": st["hp"], "atk": st["atk"], "def": st["def"], "skills": skills, "overflow": overflow, "soul": soul_need(c, cur)}


## 승급 실행 (웹 executePromote 순서 그대로) → { ok, reason("no_target"·"max"·"no_soul"·"points"), grade, books:[스킬 id], ch }
static func promote(c: Object, uid: Variant, sel: Array) -> Dictionary:
	var roster := Profile.get_roster(c)
	var target: Variant = _find(roster, uid)
	if target == null or not is_member(c, target) or Js.truthy(target.get("dead")):
		return {"ok": false, "reason": "no_target"}
	# 화면 밖에서 불러도 웹 화면과 같은 조건: 고른 제물이 모두 후보이고 4점 이상
	var cands := sacrifices(c, target)
	for su: Variant in sel:
		var found := false
		for cc: Dictionary in cands:
			if Js.same(cc["uid"], su):
				found = true
		if not found:
			return {"ok": false, "reason": "points"}
	if sel.is_empty() or points_of(c, target, sel) < REQUIRED_POINTS:
		return {"ok": false, "reason": "points"}
	var cur := Profile.pot_grade(c, target)
	var nx: Variant = next_grade(c, cur)
	if nx == null:
		return {"ok": false, "reason": "max"}
	var cls := str(target["cls"])
	if not soul_spend(c, cls, soul_need(c, cur)):
		return {"ok": false, "reason": "no_soul"}
	var skills := PartyRules.char_skills(c, cls)
	if typeof(target.get("skillLv")) != TYPE_DICTIONARY:
		target["skillLv"] = {}
	var inv := Profile.load_inventory(c)
	var books: Array = []
	var mx := float(c.D["MAX_SKILL_LV"])
	var LS: Dictionary = c.D.get("LEARNABLE_SKILLS", {})
	for su2: Variant in sel:
		var sac: Variant = _find(roster, su2)
		for sk: Variant in skills:
			var sid := str(sk["id"])
			var slv: Dictionary = target["skillLv"]
			if LS.has(sid):
				var sac_has: bool = sac != null and typeof(sac.get("skillLv")) == TYPE_DICTIONARY and Js.num(sac["skillLv"].get(sid)) >= 1.0
				if not sac_has:
					continue
				if not Js.truthy(slv.get(sid)):
					slv[sid] = 0
				if Js.num(slv[sid]) >= mx:
					inv.append({"id": sid, "cls": cls, "lv": 1})
					books.append(sid)
				else:
					slv[sid] = int(Js.num(slv[sid])) + 1
				continue
			if not Js.truthy(slv.get(sid)):
				slv[sid] = 1
			if Js.num(slv[sid]) >= mx:
				inv.append({"id": sid, "cls": cls, "lv": 1})
				books.append(sid)
			else:
				slv[sid] = int(Js.num(slv[sid])) + 1
	if not books.is_empty():
		Profile.save_inventory(c, inv)
	var kept: Array = []
	for ch: Variant in roster["chars"]:
		if typeof(ch) == TYPE_DICTIONARY and Js.index_of(sel, ch.get("uid")) >= 0:
			continue
		kept.append(ch)
	roster["chars"] = kept
	var pot := roll_potential_with_grade(c, cls, str(nx))
	var st := stats_with(c, cls, str(nx), pot, Js.num(target.get("lv")))
	target["pot"] = pot
	target["hp"] = st["hp"]
	target["atk"] = st["atk"]
	target["def"] = st["def"]
	Profile.save_roster(c, roster)
	# (Godot) 제물이 끼던 장비는 빼 둠 (웹은 없는 클랜원이 낀 장비로 남음)
	var inv2: Variant = c.store.get_json(Profile.INVENTORY_KEY)
	if inv2 is Array:
		var changed := false
		for it: Variant in inv2:
			if it is Dictionary and it.get("equipped") != null and Js.index_of(sel, it["equipped"]) >= 0:
				it["equipped"] = null
				changed = true
		if changed:
			Profile.save_inventory(c, inv2)
	return {"ok": true, "grade": nx, "books": books, "ch": target}


## 스킬 레벨 글 (웹 formatSkillLvs: 레벨 2 이상만) → [{id, lv}]
static func skill_lvs(c: Object, ch: Dictionary) -> Array:
	var out: Array = []
	for sk: Variant in PartyRules.char_skills(c, str(ch["cls"])):
		var lv := PartyRules.char_skill_lv(c, ch, str(sk["id"]))
		if lv > 1.0:
			out.append({"id": str(sk["id"]), "lv": lv})
	return out


# ── 개명 ──

## 웹: input maxlength 10(UTF-16) → trim → 비면 customName 지움 → 저장. 바뀐 클랜원 또는 null
static func rename(c: Object, uid: Variant, raw: String) -> Variant:
	var roster := Profile.get_roster(c)
	var ch: Variant = _find(roster, uid)
	if ch == null or not is_member(c, ch) or Js.truthy(ch.get("dead")):
		return null
	var nm := LobbyRules.js_trim(LobbyRules.utf16_slice(raw, NAME_LEN))
	if nm == "":
		ch.erase("customName")
	else:
		ch["customName"] = nm
	Profile.save_roster(c, roster)
	return ch


# ── 마법부여 (hazards.js Rune) ──

static func rune_count(c: Object, kind: String = "") -> int:
	var n := 0
	for it: Variant in Profile.load_inventory(c):
		if it is Dictionary and it.get("type") == "rune" and (kind == "" or it.get("enchant") == kind):
			n += 1
	return n


## 장비 목록 (낀 것 먼저, 그다음 등급 높은 순 — 웹 sort 와 같은 안정 정렬)
static func enchant_items(c: Object) -> Array:
	var RAR: Dictionary = c.D["RARITY"]
	var out: Array = []
	for it: Variant in Profile.load_inventory(c):
		if it is Dictionary and it.get("type") == "equip":
			out.append(it)
	var tier := func(it: Dictionary) -> float: return float(RAR[it["rarity"]]["tier"]) if typeof(it.get("rarity")) == TYPE_STRING and RAR.has(it["rarity"]) else 0.0
	return Js.stable_sort(out, func(a: Dictionary, b: Dictionary) -> float:
		var d := (1.0 if Js.truthy(b.get("equipped")) else 0.0) - (1.0 if Js.truthy(a.get("equipped")) else 0.0)
		return d if d != 0.0 else float(tier.call(b)) - float(tier.call(a)))


## 장비를 낀 클랜원 (없으면 null)
static func owner_of(c: Object, it: Dictionary) -> Variant:
	if not Js.truthy(it.get("equipped")):
		return null
	return _find(Profile.get_roster(c), it["equipped"])


## Rune.apply → true 또는 사유 "no_item" · "already" · "no_rune" · "no_gold"
static func rune_apply(c: Object, eid: Variant, kind: String) -> Variant:
	var EN: Dictionary = c.D["ENCHANTS"]
	if not EN.has(kind):
		return "no_rune"
	var inv := Profile.load_inventory(c)
	var it: Variant = null
	for x: Variant in inv:
		if x is Dictionary and Js.same(x.get("eid"), eid) and x.get("type") == "equip":
			it = x
			break
	if it == null:
		return "no_item"
	var field: String = c.D["ENCHANT_FIELD"][EN[kind]["cat"]]
	if Js.same(it.get(field), kind):
		return "already"
	var ri := -1
	for i in inv.size():
		if inv[i] is Dictionary and inv[i].get("type") == "rune" and inv[i].get("enchant") == kind:
			ri = i
			break
	if ri < 0:
		return "no_rune"
	var g := gold(c)
	var fee := float(c.D["ENCHANT_FEE"])
	if g < fee:
		return "no_gold"
	inv.remove_at(ri)
	it[field] = kind
	Profile.save_inventory(c, inv)
	Profile.save_gold(c, g - fee)
	return true
