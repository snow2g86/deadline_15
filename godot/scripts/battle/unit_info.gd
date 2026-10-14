extends RefCounted
## 화면에 보일 유닛·스테이지 정보 (규칙 없음 — 화면 사본을 읽기만)
##  웹 render.js getBuffs · rUnits 배지 · unitName, js/skills/_common.js getSkillBuffs, js/logic/hazards.js Hazard.name/describe,
##  js/logic/synergy.js Synergy.name/describe, stages.js bossName 을 옮김.
##  유닛 사전(u)은 화면 사본 (battle_scene._unit_snap: unit_view + 배지·카드에 필요한 몇 값)

const Js := preload("res://scripts/logic/js.gd")
const Num := preload("res://scripts/core/num.gd")
const Hazards := preload("res://scripts/logic/hazards.gd")

## 버프 종류 → 웹 아이콘 (BuffSystem.apply 에 넘기는 icon · getSkillBuffs 기본값)
const TYPE_ICON := {"atk_up": "🔥", "def_up": "🛡️", "atk_down": "💢", "def_down": "💢", "fury_buff": "💢", "iron_will": "🛡️",
	"iron_phalanx": "🛡️", "stun": "⚡", "freeze": "❄️", "root": "🌿", "disarm": "🤛", "bleed": "🗡️", "poison": "🧪", "regen": "💚",
	"sanctuary": "✝️", "shield": "🛡️", "evasion": "🌫️", "stealth": "🌙", "phalanx_def": "🛡️", "tenacity": "💪", "sacrifice": "🛡️",
	"curse": "☠️", "empower": "⬆️", "channel_curse": "☠️", "channel_exalt": "🔺"}
const DEBUFF_TYPES := ["atk_down", "def_down", "stun", "freeze", "root", "disarm", "bleed", "poison", "curse"]

var D: Dictionary
var i18n: Node
## uid → 로스터 캐릭터 (전투 세이브의 game_roster — 이름은 customName·nameId 로, 결과 화면과 같은 규칙)
var roster_by_uid: Dictionary = {}


func _init(p_D: Dictionary, p_i18n: Node) -> void:
	D = p_D
	i18n = p_i18n


func t(key: String, p: Dictionary = {}) -> String:
	return i18n.t(key, p) if i18n != null else key


func _has(key: String) -> bool:
	return i18n != null and i18n.has_key(key)


func num(v: Variant) -> String:
	return Num.fmt(float(v)) if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT else str(v)


# ── 이름 ──

func set_roster(roster: Variant) -> void:
	roster_by_uid = {}
	if typeof(roster) == TYPE_DICTIONARY and typeof(roster.get("chars")) == TYPE_ARRAY:
		for ch: Variant in roster["chars"]:
			if typeof(ch) == TYPE_DICTIONARY and ch.get("uid") != null:
				roster_by_uid[int(ch["uid"])] = ch


## 로스터 캐릭터 이름 (웹 toBattleStats: customName → character.names[nameId] → 직업 이름). nameId 가 없으면 직업 이름
func char_name(ch: Dictionary) -> String:
	if Js.truthy(ch.get("customName")):
		return str(ch["customName"])
	var nid: Variant = ch.get("nameId")
	if (typeof(nid) == TYPE_INT or typeof(nid) == TYPE_FLOAT) and i18n != null:
		var names: Variant = i18n.t_raw("character.names")
		if names is Array and int(nid) >= 0 and int(nid) < (names as Array).size():
			return str(names[int(nid)])
	return class_name_of(str(ch.get("cls", "")))


## 웹 unitName: 클랜원은 로스터(uid)의 이름 → 보스 이름 → 직업·소환수 이름
func unit_name(u: Dictionary, stage: Variant = null) -> String:
	var cls := str(u.get("cls", ""))
	if Js.truthy(u.get("isBoss")) and stage != null:
		var bn := boss_name(stage)
		if bn != "":
			return bn
	var uid: Variant = u.get("uid")
	if (typeof(uid) == TYPE_INT or typeof(uid) == TYPE_FLOAT) and int(uid) != 0 and roster_by_uid.has(int(uid)):
		return char_name(roster_by_uid[int(uid)])
	var nm: Variant = u.get("name")
	if typeof(nm) == TYPE_STRING and nm != "" and nm != cls and nm != "<null>" and nm != "null":
		var s: String = nm
		if s.is_valid_int() and i18n != null:
			var names: Variant = i18n.t_raw("character.names")
			if names is Array and s.to_int() >= 0 and s.to_int() < (names as Array).size():
				return str(names[s.to_int()])
		elif not s.is_valid_int():
			return s
	return class_name_of(cls)


func class_name_of(cls: String) -> String:
	return t(("summon_types." if cls.begins_with("summon_") else "classes.") + cls)


## stages.js bossName
func boss_name(st: Variant) -> String:
	if st == null or not Js.truthy(st.get("boss")):
		return ""
	var k := "stages.boss_%s" % num(st["id"])
	return t(k) if _has(k) else str(st["boss"].get("name", ""))


## 스테이지 제목 (웹 uUI si-title): 요일 던전이면 난이도·직업, 아니면 STAGE n + 이름
func stage_title(st: Variant) -> Array:
	if st == null:
		return ["STAGE 1", ""]
	if Js.truthy(st.get("daily")):
		return [t("daily.title"), "%s · %s" % [t("daily.tier_" + str(st["daily"]["tier"])), t("classes." + str(st["daily"]["cls"]))]]
	return ["STAGE %s" % num(st["id"]), t("stages.stage_%s_name" % num(st["id"]))]


# ── 버프 목록 (웹 getBuffs = 지형 + getSkillBuffs + 숲 속 암살자 + 뿌리) ──
##  [{icon, type("buff"|"debuff"), turns, label}] — ctx: {ter, units(같은 편 정신 집중 확인용)}

func buffs(u: Dictionary, ter: Array, units: Array) -> Array:
	var out: Array = []
	var x := int(u.get("x", 0))
	var y := int(u.get("y", 0))
	var tile := _tile(ter, x, y)
	var TI: Dictionary = D["TI"]
	if tile != "" and TI.has(tile) and TI[tile].get("buff") != null:
		var b: Dictionary = TI[tile]["buff"]
		var lab := t("terrain_buff." + tile) + " · " + t("terrain_buff_desc." + tile) if _has("terrain_buff." + tile) else t("terrain." + tile)
		if tile == "shallow":
			lab = t("terrain.shallow") + " · " + t("battle.tactic_shallow", {"n": Js.round_js(float(D["TACTIC"]["shallowVuln"]) * 100.0)})
		_add(out, str(b["icon"]), str(b["type"]), 0, lab)
	_skill_buffs(u, units, out)
	if u.get("cls") == "assassin" and tile == "forest":
		_add(out, "🌙", "buff", 0, t("gd.buff.stealth_forest"))
	if Js.num(u.get("_rootedTurns")) > 0:
		_add(out, "🔗", "debuff", int(Js.num(u.get("_rootedTurns"))), t("gd.buff.root"))
	return out


func _add(out: Array, icon: String, type: String, turns: int, label: String) -> void:
	for e: Dictionary in out:
		if e["icon"] == icon and e["label"] == label:
			e["turns"] = maxi(int(e["turns"]), turns)
			return
	out.append({"icon": icon, "type": type, "turns": turns, "label": label})


func _lv(u: Dictionary, sk: String) -> float:
	var sl: Variant = u.get("skillLv")
	return Js.num(sl.get(sk)) if typeof(sl) == TYPE_DICTIONARY else 0.0


## js/skills/_common.js getSkillBuffs
func _skill_buffs(u: Dictionary, units: Array, out: Array) -> void:
	var res := float(Js.num(u.get("res")))
	var mres := float(Js.num(u.get("maxRes")))
	if u.get("resType") == "fury" and mres > 0.0 and res >= mres:
		_add(out, "🔥", "buff", 0, t("gd.buff.fury_full"))
	if Js.num(u.get("furyBuff")) > 0:
		_add(out, "💢", "buff", int(Js.num(u.get("furyBuff"))), t("passives.fury_buff"))
	if Js.num(u.get("defBuff")) > 0:
		_add(out, "🛡️", "buff", int(Js.num(u.get("defBuff"))), t("passives.iron_phalanx" if u.get("cls") == "lancer" else "passives.iron_will"))
	if Js.num(u.get("disarmed")) > 0:
		_add(out, "🤛", "debuff", int(Js.num(u.get("disarmed"))), t("gd.buff.disarm"))
	var ch: Variant = u.get("channeling")
	if ch == "shaman_curse":
		_add(out, "☠️", "debuff", 0, t("skills.shaman_curse"))
	if ch == "shaman_exalt":
		_add(out, "🔺", "buff", 0, t("skills.shaman_exalt"))
	if not Js.truthy(ch):
		for o: Dictionary in units:
			if o.get("team") == u.get("team") and float(Js.num(o.get("hp"))) > 0.0 and o.get("channeling") == "shaman_exalt":
				_add(out, "🔺", "buff", 0, t("skills.shaman_exalt"))
				break
	if u.get("cls") == "knight" and _lv(u, "knight_painshare") >= 1:
		_add(out, "💔", "buff", 0, t("skills.knight_painshare"))
	if Js.truthy(u.get("_sacrificeKnight")):
		_add(out, "🛡️", "buff", 0, t("skills.knight_sacrifice"))
	if Js.num(u.get("_sacrificeDmgCount")) > 0:
		_add(out, "🛡️", "buff", int(Js.num(u.get("_sacrificeDmgCount"))), t("skills.knight_sacrifice"))
	if Js.truthy(u.get("_tenacityDef")):
		_add(out, "💪", "buff", 1, t("skills.knight_tenacity"))
	if u.get("cls") == "warrior" and _lv(u, "warrior_bloodthirst") >= 1:
		_add(out, "🩸", "buff", 0, t("skills.warrior_bloodthirst"))
	if Js.num(u.get("_bleedTurns")) > 0:
		_add(out, "🗡️", "debuff", int(Js.num(u.get("_bleedTurns"))), t("gd.buff.bleed"))
	if Js.num(u.get("stunned")) > 0:
		_add(out, "⚡", "debuff", int(Js.num(u.get("stunned"))), t("gd.buff.stun"))
	if Js.num(u.get("frozen")) > 0:
		_add(out, "❄️", "debuff", int(Js.num(u.get("frozen"))), t("gd.buff.freeze"))
	if Js.num(u.get("_sanctuaryTurns")) > 0:
		_add(out, "✝️", "buff", int(Js.num(u.get("_sanctuaryTurns"))), t("skills.priest_sanctuary"))
	if Js.truthy(u.get("isSummon")) and u.has("summonTurns") and u["summonTurns"] != null:
		_add(out, "⏳", "buff", int(Js.num(u["summonTurns"])), t("gd.buff.summon_turns"))
	if Js.num(u.get("_phalanxTurns")) > 0:
		_add(out, "🛡️", "buff", int(Js.num(u.get("_phalanxTurns"))), t("skills.lancer_phalanx"))
	if Js.truthy(u.get("isSummon")) and Js.num(u.get("_empowerTurns")) > 0:
		_add(out, "⬆️", "buff", int(Js.num(u.get("_empowerTurns"))), t("skills.summoner_empower"))
	if Js.num(u.get("_rootedTurns")) > 0:
		_add(out, "🌿", "debuff", int(Js.num(u.get("_rootedTurns"))), t("gd.buff.root"))
	if Js.truthy(u.get("_cursed")):
		_add(out, "☠️", "debuff", 0, t("gd.buff.cursed"))
	if u.get("cls") == "lancer" and _lv(u, "lancer_spearwall") >= 1:
		_add(out, "🔱", "buff", 0, t("skills.lancer_spearwall"))
	if u.get("cls") == "brawler" and _lv(u, "brawler_counter") >= 1:
		_add(out, "🔁", "buff", 0, t("skills.brawler_counter"))
	if u.get("cls") == "shaman" and _lv(u, "shaman_medium") >= 1 and Js.truthy(ch):
		_add(out, "🔮", "buff", 0, t("skills.shaman_medium"))
	if u.get("cls") == "sapper" and _lv(u, "sapper_enhancedtrap") >= 1:
		_add(out, "⚙️", "buff", 0, t("skills.sapper_enhancedtrap"))
	if u.get("cls") == "mage" and _lv(u, "mage_manasurge") >= 1 and mres > 0.0 and res >= mres * 0.8:
		_add(out, "🌊", "buff", 0, t("skills.mage_manasurge"))
	if u.get("cls") == "priest" and _lv(u, "priest_divinegrace") >= 1:
		_add(out, "🕊️", "buff", 0, t("skills.priest_divinegrace"))
	var mhp := float(Js.num(u.get("mhp")))
	if u.get("cls") == "novice" and _lv(u, "novice_grit") >= 1 and mhp > 0.0 and float(Js.num(u.get("hp"))) <= mhp * 0.3:
		_add(out, "✊", "buff", 0, t("skills.novice_grit"))
	for b: Dictionary in u.get("buffs", []):
		var tp := str(b.get("type", ""))
		var icon: String = TYPE_ICON.get(tp, "🔥" if tp == "atk_up" else ("🛡️" if tp == "def_up" else ("💢" if tp == "atk_down" else "❄️")))
		var dur := int(Js.num(b.get("duration")))
		var lab := t("gd.buff." + tp) if _has("gd.buff." + tp) else tp
		if b.get("source") != null and _has("skills." + str(b.get("source"))):
			lab = t("skills." + str(b["source"]))
		_add(out, icon, "debuff" if (tp.contains("down") or DEBUFF_TYPES.has(tp)) else "buff", 0 if dur >= 999 or dur < 0 else dur, lab)


## 머리 위 배지 (웹 rUnits .u-badges): [{icon, kind(buff·debuff·cover)}]
func badges(u: Dictionary, ter: Array, units: Array, lava_map: bool) -> Array:
	var out: Array = []
	var x := int(u.get("x", 0))
	var y := int(u.get("y", 0))
	var tile := _tile(ter, x, y)
	var TI: Dictionary = D["TI"]
	if tile != "" and TI.has(tile) and TI[tile].get("buff") != null:
		out.append({"icon": str(TI[tile]["buff"]["icon"]), "kind": str(TI[tile]["buff"]["type"])})
	if lava_map:
		for d: Array in [[0, -1], [0, 1], [-1, 0], [1, 0]]:
			if _tile(ter, x + d[0], y + d[1]) == "water":
				out.append({"icon": "🔥", "kind": "debuff"})
				break
	if _has_guard(u, units):
		out.append({"icon": "🛡️", "kind": "cover"})
	if Js.truthy(u.get("defend")):
		out.append({"icon": "🧱", "kind": "buff"})
	if Js.truthy(u.get("overwatch")):
		out.append({"icon": "👁", "kind": "buff"})
	if Js.num(u.get("furyBuff")) > 0:
		out.append({"icon": "💢", "kind": "buff"})
	if Js.num(u.get("defBuff")) > 0:
		out.append({"icon": "🛡️", "kind": "buff"})
	if Js.num(u.get("disarmed")) > 0:
		out.append({"icon": "🤛", "kind": "debuff"})
	var ch: Variant = u.get("channeling")
	if Js.truthy(ch):
		out.append({"icon": "☠️" if ch == "shaman_curse" else "🔺", "kind": "debuff" if ch == "shaman_curse" else "buff"})
	return out


## UnitManager.hasGuard (표시용): 옆에 엄호해 줄 탱커가 있는가
func _has_guard(u: Dictionary, units: Array) -> bool:
	var GC: Array = D["GUARD_CLASSES"]
	if GC.has(u.get("cls")):
		return false
	for g: Dictionary in units:
		if float(Js.num(g.get("hp"))) > 0.0 and g.get("id") != u.get("id") and g.get("team") == u.get("team") and GC.has(g.get("cls")) \
				and not (Js.num(g.get("stunned")) > 0 or Js.num(g.get("frozen")) > 0) \
				and absi(int(g["x"]) - int(u["x"])) + absi(int(g["y"]) - int(u["y"])) == 1:
			return true
	return false


static func _tile(ter: Array, x: int, y: int) -> String:
	if y < 0 or y >= ter.size():
		return ""
	var row: Array = ter[y]
	if x < 0 or x >= row.size():
		return ""
	return str(row[x])


# ── 환경·조합 버프 (웹 Hazard.name/describe, Synergy.name/describe) ──

func hazard_name(h: Dictionary) -> String:
	return t("hazard." + str(h["id"]))


func hazard_describe(h: Dictionary, stage: Variant) -> String:
	var p: Array = []
	if Js.truthy(h.get("dot")):
		p.append(t("hazard.fx_dot", {"n": Js.round_js(Hazards.dot_pct(h, stage) * 100.0)}))
	if Js.truthy(h.get("move")):
		p.append(t("hazard.fx_move", {"n": h["move"]}))
	if Js.truthy(h.get("range")):
		p.append(t("hazard.fx_range", {"n": h["range"]}))
	if Js.truthy(h.get("def")):
		p.append(t("hazard.fx_def", {"n": Js.round_js((1.0 - float(h["def"])) * 100.0)}))
	if Js.truthy(h.get("heal")):
		p.append(t("hazard.fx_heal", {"n": Js.round_js((1.0 - float(h["heal"])) * 100.0)}))
	var ench: Dictionary = D["ENCHANTS"][h["enchant"]]
	var s := " · ".join(p) + " — " + t("hazard.counter", {"e": str(ench["icon"]) + " " + t("enchant." + str(h["enchant"]))})
	if Js.truthy(h.get("safe")):
		s += " · " + t("hazard.safe_zone", {"i": D["SAFE_ZONE"]["icon"], "r": D["SAFE_ZONE"]["every"]})
	return s


func synergy_name(s: Dictionary) -> String:
	var res := " ✦" + t("gear.resonance") if Js.truthy(s.get("resonance")) else ""
	var id := str(s["id"])
	if id.begins_with("mono_"):
		return t("synergy.mono_" + str(s.get("cls", id.trim_prefix("mono_")))) + res
	if id.begins_with("trio_"):
		return t("synergy.trio", {"cls": t("classes." + str(s.get("cls", id.trim_prefix("trio_"))))}) + res
	return t("synergy." + id) + res


func synergy_describe(s: Dictionary) -> String:
	var e: Dictionary = s.get("eff", {})
	var parts: Array = []
	for k: String in ["atk", "def", "hp", "heal", "frag"]:
		if Js.truthy(e.get(k)) and float(e[k]) != 1.0:
			parts.append(t("synergy.stat_" + k) + " ×" + num(Js.to_fixed_num(float(e[k]), 2)))
	for k2: String in ["move", "range"]:
		if Js.truthy(e.get(k2)):
			parts.append(t("synergy.stat_" + k2) + " " + ("+" if float(e[k2]) > 0.0 else "") + num(e[k2]))
	var txt := " · ".join(parts)
	if Js.truthy(s.get("to")):
		txt = t("synergy.only_" + str(s["to"])) + " " + txt
	return txt


# ── 지형 설명 (칸 위 마우스) ──

func terrain_lines(tile: String) -> Array:
	var out: Array = []
	var TI: Dictionary = D["TI"]
	if not TI.has(tile):
		return out
	var ti: Dictionary = TI[tile]
	var cost: Variant = ti.get("cost")
	if typeof(cost) == TYPE_FLOAT and is_inf(float(cost)) or not Js.truthy(ti.get("pass", true)):
		out.append(t("gd.tip.impassable"))
	else:
		out.append(t("gd.tip.move_cost", {"n": cost}))
	if float(ti.get("z", 0.0)) > 0.0:
		out.append(t("gd.tip.height", {"n": ti["z"]}))
	if _has("terrain_buff." + tile):
		out.append(t("terrain_buff." + tile) + " · " + t("terrain_buff_desc." + tile))
	if tile == "shallow":
		out.append(t("battle.tactic_shallow", {"n": Js.round_js(float(D["TACTIC"]["shallowVuln"]) * 100.0)}))
	if tile == "forest":
		out.append(t("gd.tip.forest_hide"))
	return out
