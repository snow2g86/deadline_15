extends SceneTree
## 1단계(기초) 머리 없는 시험
##   Godot --headless --path godot --script res://tests/check_foundation.gd
## 모든 JSON 읽기·manifest 개수 대조, 알려진 값 몇 개, 3개 언어 번역, Store 저장 왕복을 확인하고
## 통과 0 / 실패 1 로 끝난다. 진짜 저장(user://save.json)은 건드리지 않는다.

const TEST_SAVE := "user://test_foundation_save.json"
# --script 로 돌리면 오토로드 이름(Store 등)이 컴파일 때 보이지 않아, 같은 스크립트 형식으로 노드를 받아 쓴다
const StoreScript := preload("res://scripts/core/store.gd")
const DataDBScript := preload("res://scripts/core/data_db.gd")
const I18nScript := preload("res://scripts/core/i18n.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")
const NumParse := preload("res://scripts/core/num_parse.gd")
const NumFmt := preload("res://scripts/core/num.gd")

var Store: StoreScript
var DataDB: DataDBScript
var I18n: I18nScript

var _started := false
var _pass := 0
var _fail := 0
var _failures: PackedStringArray = PackedStringArray()


# _initialize 때는 오토로드가 아직 트리에 들어가기 전이라(_ready 전), 첫 프레임에서 시작한다
func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	print("── DEADLINE 15 · Godot 기초 시험 ──")
	Store = root.get_node_or_null("Store") as StoreScript
	DataDB = root.get_node_or_null("DataDB") as DataDBScript
	I18n = root.get_node_or_null("I18n") as I18nScript
	_check(Store != null and DataDB != null and I18n != null, "오토로드 Store·DataDB·I18n 이 있음")
	if Store == null or DataDB == null or I18n == null:
		_finish()
		return

	var real_path: String = Store.save_path
	Store.use_path(TEST_SAVE)
	Store.clear()
	I18n.reload()

	_test_data()
	_test_i18n()
	_test_store()
	_test_numbers()

	# 정리: 시험 저장 지우고 진짜 저장으로 되돌림
	Store.clear()
	Store.flush()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	Store.use_path(real_path)
	I18n.reload()
	_finish()


# ── 데이터 ──

func _test_data() -> void:
	print("[데이터]")
	var ok: bool = DataDB.load_all()
	_check(ok and DataDB.errors.is_empty(), "모든 JSON 읽기 + manifest 개수 대조 (오류 %d개)" % DataDB.errors.size())
	for e: String in DataDB.errors:
		print("    · " + e)

	var mods: Dictionary = DataDB.manifest.get("modules", {})
	_check(DataDB.module_names().size() == mods.size() and mods.size() >= 12,
		"데이터 모듈 %d개 읽음 (manifest %d개)" % [DataDB.module_names().size(), mods.size()])
	var n_globals := 0
	for m: String in mods.keys():
		n_globals += (mods[m]["globals"] as Dictionary).size()
	_check(DataDB.global_names().size() == n_globals, "전역 %d개 색인 (manifest %d개)" % [DataDB.global_names().size(), n_globals])

	var stages: Array = DataDB.global("STAGES")
	_check(stages.size() == 100, "STAGES 길이 100 (실제 %d)" % stages.size())
	var s56: Dictionary = _find_by_id(stages, 56)
	_check(String(s56.get("mapType", "")) == "abyss", "56스테이지 mapType == abyss (실제 %s)" % s56.get("mapType"))
	# js/logic/stages.js 가 적재 때 덧붙이는 값까지 들어왔는지 (가공 후 데이터)
	_check(s56.has("difficulty") and s56.has("sm") and s56.has("recommendedClasses"), "STAGES 에 logic/stages.js 가공 값(difficulty·sm·recommendedClasses) 있음")
	# 숫자 모델: 기본 float (JS 와 같음), 식별자·번호 키만 int
	var id56: Variant = (stages[55] as Dictionary).get("id")
	_check(typeof(id56) == TYPE_INT, "STAGES[55].id 가 int (typeof %d)" % typeof(id56))
	_check("%s" % id56 == "56" and [id56].has(56), "\"%s\" % id == \"56\", [id].has(56)")
	var vdot: Variant = ((DataDB.global("HAZARDS") as Dictionary)["volcano"] as Dictionary)["dot"]
	_check(typeof(vdot) == TYPE_FLOAT, "소수 값(0.035)은 float 유지")
	var legends: Dictionary = DataDB.global("LEGENDS")
	var exp_pct: Variant = ((legends["first_blade"] as Dictionary)["fx"] as Dictionary)["exp_pct"]
	_check(typeof(exp_pct) == TYPE_FLOAT, "LEGENDS.first_blade.fx.exp_pct 는 float (typeof %d)" % typeof(exp_pct))
	var all_float := true
	for lk: String in legends.keys():
		var fx: Dictionary = (legends[lk] as Dictionary).get("fx", {})
		for fk: String in fx.keys():
			if typeof(fx[fk]) == TYPE_INT:
				all_float = false
	_check(all_float, "LEGENDS.*.fx 숫자 전부 float")
	_check(1 + exp_pct / 100 == 1.5, "1 + exp_pct / 100 == 1.5 (JS 와 같음, 실제 %s)" % Num.fmt(1 + exp_pct / 100))
	var pity_max: Variant = DataDB.global("GACHA_PITY_MAX")
	var pity: Variant = 30.0   # 저장에서 읽은 숫자도 float (JS 처럼)
	_check(roundi(pity / pity_max * 100) == 30, "pity / GACHA_PITY_MAX * 100 == 30 (JS 와 같음, 실제 %s)" % Num.fmt(pity / pity_max * 100))
	var sm_types := {}
	for st: Variant in stages:
		var sm: Dictionary = (st as Dictionary)["sm"]
		sm_types[typeof(sm["hp"])] = true
		sm_types[typeof(sm["atk"])] = true
	_check(sm_types.size() == 1 and sm_types.has(TYPE_FLOAT), "STAGES[].sm.hp·atk 타입이 모두 float (섞이지 않음)")
	var tot: Variant = (stages[0] as Dictionary)["tot"]
	_check(typeof(tot) == TYPE_FLOAT and ceili(tot / DataDB.global("STAGE_MAX_WAVES")) == ceili(float(int(tot)) / 3.0), "tot 는 float (웹에서 나누는 값)")
	var ep: Dictionary = (DataDB.global("EPISODES") as Array)[0]
	_check(typeof((ep["stages"] as Array)[0]) == TYPE_INT and typeof(ep["id"]) == TYPE_INT, "EPISODES[].id·stages 는 int")
	var dep: Dictionary = (DataDB.global("DEPLOY") as Array)[0]
	_check(typeof(dep["x"]) == TYPE_INT and typeof(dep["y"]) == TYPE_INT, "DEPLOY[].x·y 는 int (칸 번호)")
	_test_num_fmt()
	_check(Num.fmt(56.0) == "56" and Num.fmt(0.035) == "0.035" and Num.fmt(56) == "56" and Num.fmt(-0.0) == "0" and Num.fmt(INF) == "Infinity" and Num.fmt(1.5) == "1.5",
		"Num.fmt: 56.0→\"56\", 0.035→\"0.035\", -0→\"0\", INF→\"Infinity\"")

	var hazards: Dictionary = DataDB.global("HAZARDS")
	var volcano_dot: float = (hazards.get("volcano", {}) as Dictionary).get("dot", -1.0)
	_check(is_equal_approx(volcano_dot, 0.035), "HAZARDS.volcano.dot == 0.035 (실제 %s)" % volcano_dot)
	var safe: Dictionary = DataDB.global("SAFE_ZONE")
	_check(int(safe.get("every", -1)) == 3, "SAFE_ZONE.every == 3 (실제 %s)" % safe.get("every"))
	var legion: Dictionary = DataDB.global("SYNERGY_LEGION")
	_check((legion.get("classes", []) as Array).size() == 5, "SYNERGY_LEGION.classes 길이 5")
	var ti: Dictionary = DataDB.global("TI")
	var rock_cost: float = (ti.get("rock", {}) as Dictionary).get("cost", 0.0)
	_check(is_inf(rock_cost) and rock_cost > 0.0, "TI.rock.cost == INF (Infinity 특수값 복원)")
	var jab: Dictionary = DataDB.global("JAB")
	_check(jab.has("warrior") and int((jab["warrior"]["base"] as Dictionary)["hp"]) == 100, "JAB.warrior.base.hp == 100")

	for code: String in ["ko", "en", "es"]:
		var st: Dictionary = DataDB.story(code)
		_check((st.get("episodes", {}) as Dictionary).size() == 10 and st.has("cast"), "스토리 %s: 에피소드 10개 + cast" % code)

	# 화면 쪽 표 (아이콘·캐릭터 그림·리그·모션·하단 탭·영혼석 키)
	for g: String in ["ITEM_SPRITE", "EMOJI_ICON", "ICON_RARITY", "CHAR_SPRITES", "CUTOUT_RIGS", "CHAR_FIG", "SPRITE_SHEETS", "ATK_MOTIONS", "NAV_TABS", "SOUL_KEY"]:
		_check(DataDB.has_global(g), "화면 표 %s 있음" % g)
	var item_sprite: Dictionary = DataDB.global("ITEM_SPRITE")
	var gold_pos: Array = item_sprite.get("gold", [])
	# 시트 좌표는 화이트리스트 밖이라 JS 처럼 float — 칸 번호로 쓸 때 int()
	_check(gold_pos.size() == 2 and int(gold_pos[0]) == 6 and int(gold_pos[1]) == 15, "ITEM_SPRITE.gold == [6, 15] (실제 %s)" % str(gold_pos))
	_check(String((DataDB.global("EMOJI_ICON") as Dictionary).get("🪙", "")) == "gold", "EMOJI_ICON[🪙] == gold")
	_check((DataDB.global("NAV_TABS") as Array).size() == 5 and DataDB.global("SOUL_KEY") == "game_soul", "NAV_TABS 5개 · SOUL_KEY == game_soul")
	var motions: Dictionary = DataDB.global("ATK_MOTIONS")
	_check(motions.has("_default") and int((motions["warrior"] as Dictionary)["dur"]) == 560, "ATK_MOTIONS.warrior.dur == 560, _default 있음")
	var sheets: Dictionary = DataDB.global("SPRITE_SHEETS")
	var src: String = ((sheets.get("knight_01", {}) as Dictionary).get("attack", {}) as Dictionary).get("src", "")
	_check(ResourceLoader.exists("res://assets/" + src), "SPRITE_SHEETS.knight_01.attack 그림이 assets 에 있음 (%s)" % src)

	var warns: Array = DataDB.manifest.get("warnings", [])
	print("    (변환 경고 %d개, 계산용 객체 제외 %d개 — manifest.json 참고)" % [warns.size(), (DataDB.manifest.get("skipped_logic", []) as Array).size()])


# ── 번역 ──

func _test_i18n() -> void:
	print("[번역]")
	var seen: Dictionary = {}
	for code: String in ["ko", "en", "es"]:
		I18n.set_language(code)
		_check(I18n.current_lang == code, "%s: 언어 바뀜" % code)
		var title := I18n.t("common.game_title")
		_check(title == "DEADLINE 15", "%s: common.game_title == DEADLINE 15 (실제 %s)" % [code, title])
		var safe := I18n.t("hazard.safe_zone", {"i": "❄️", "r": 3})
		_check(safe != "hazard.safe_zone" and safe.contains("3") and safe.begins_with("❄️") and not safe.contains("{"),
			"%s: hazard.safe_zone + 자리표시자 → \"%s\"" % [code, safe])
		for key: String in ["nav.sortie", "settings.language", "classes.warrior", "battle", "stages.boss_10"]:
			var v := I18n.t(key)
			if key == "battle":
				_check(v == "battle", "%s: 사전 키(battle)는 문자열이 아니라 키 그대로" % code)
			else:
				_check(v != key and not v.is_empty(), "%s: %s → \"%s\"" % [code, key, v])
		seen[code] = I18n.t("nav.sortie") + "|" + safe
		_check(I18n.t("no.such.key") == "no.such.key", "%s: 없는 키는 키 그대로" % code)
	_check(seen["ko"] != seen["en"] and seen["en"] != seen["es"], "언어마다 다른 문자열")
	var tips: Variant = I18n.t_raw("battle.loading_tips")
	_check(tips is Array and (tips as Array).size() > 0 and typeof((tips as Array)[0]) == TYPE_STRING, "t_raw: 배열 값(battle.loading_tips) 그대로")
	_check(I18n.t_raw("character.names") is Array, "t_raw: character.names 그대로")
	_check(I18n.t_raw("no.such") == "no.such" and I18n.t_raw("common.game_title") == "DEADLINE 15", "t_raw: 없는 키·문자열은 t() 와 같음")
	_check(I18n.interpolate("[{n}]", {"n": null}) == "[null]", "null 자리표시자 → \"null\" (웹과 같음)")
	_check(I18n.interpolate("a {x} {y}", {"y": 2.0}) == "a {x} 2", "없는 자리표시자는 그대로, 2.0 → \"2\"")
	var settings: Variant = Store.get_json("game_settings", {})
	_check(settings is Dictionary and (settings as Dictionary).get("language") == "es", "set_language 가 game_settings.language 에 저장")
	Store.set_json("game_settings", {"language": "en", "speed": 2})
	I18n.reload()
	_check(I18n.current_lang == "en", "Store game_settings.language 에서 언어 읽기")
	I18n.set_language("ko")
	var s2: Dictionary = Store.get_json("game_settings", {})
	_check(int(s2.get("speed", 0)) == 2, "set_language 가 다른 설정(speed)을 지우지 않음")
	Store.set_json("game_settings", {"language": "xx"})
	I18n.reload()
	_check(I18n.current_lang == "ko", "모르는 언어면 ko")
	Store.remove("game_settings")
	I18n.reload()
	_check(I18n.current_lang == "ko", "설정이 없으면 ko")


# ── 저장 ──

func _test_store() -> void:
	print("[저장]")
	_check(Store.get_str("game_save") == null, "없는 키 → null")
	_check(Store.set_str("game_save", "hello"), "set_str 성공")
	_check(Store.get_str("game_save") == "hello", "get_str 왕복")
	Store.set_str("game_soul", 3.0)
	_check(Store.get_str("game_soul") == "3", "숫자 3.0 은 웹 String() 처럼 \"3\"")
	var roster := {"chars": [{"uid": 1, "cls": "knight", "lv": 5}], "nextId": 2}
	_check(Store.set_json("game_roster", roster), "set_json 성공")
	var back: Variant = Store.get_json("game_roster", null)
	_check(back is Dictionary and int(back["nextId"]) == 2 and String(back["chars"][0]["cls"]) == "knight", "get_json 왕복")
	_check(typeof(back["nextId"]) == TYPE_INT and typeof(back["chars"][0]["uid"]) == TYPE_INT and typeof(back["chars"][0]["lv"]) == TYPE_INT,
		"저장 왕복 후 uid·lv·nextId int 유지")
	# 웹 형식 그대로의 저장 문자열 (localStorage 에 있는 모양)
	Store.set_str("game_roster", '{"chars":[{"uid":3,"nameId":4,"cls":"knight","lv":7,"exp":12.5,"equip":{"weapon":"eq_x_1"}}],"nextId":4}')
	var ro: Dictionary = Store.get_json("game_roster", {})
	var ch: Dictionary = (ro["chars"] as Array)[0]
	_check(typeof(ro["nextId"]) == TYPE_INT and typeof(ch["uid"]) == TYPE_INT and typeof(ch["nameId"]) == TYPE_INT and typeof(ch["lv"]) == TYPE_INT,
		"웹 로스터: nextId·uid·nameId·lv 는 int")
	_check(typeof(ch["exp"]) == TYPE_FLOAT, "웹 로스터: exp 는 float (나눗셈 값)")
	Store.set_str("game_parties", '{"parties":[{"id":1,"slots":[3,null,null,null,null]},{"id":2,"slots":[null,null,null,null,null]}],"activePartyId":1,"nextPartyId":6}')
	var pa: Dictionary = Store.get_json("game_parties", {})
	var slots: Array = (pa["parties"] as Array)[0]["slots"]
	_check(slots.has(3) and slots[1] == null and typeof(pa["activePartyId"]) == TYPE_INT and typeof(pa["nextPartyId"]) == TYPE_INT,
		"웹 파티: slots.has(3), null 유지, activePartyId·nextPartyId int")
	var active: Dictionary = {}
	for p: Variant in pa["parties"]:
		if (p as Dictionary)["id"] == pa["activePartyId"]:
			active = p
	_check(not active.is_empty(), "웹 파티: parties.find(p.id === activePartyId) 와 같은 비교 성공")
	Store.set_str("game_cleared", "[1,2,3]")
	var cl: Array = Store.get_json("game_cleared", [])
	_check(cl.has(2) and typeof(cl[0]) == TYPE_INT, "game_cleared [1,2,3]: cleared.has(2), int")
	Store.set_str("game_party", "[3,5]")
	_check((Store.get_json("game_party", []) as Array).has(5), "레거시 game_party [3,5]: has(5)")
	Store.set_str("game_inventory", '[{"type":"equip","eid":"eq_a","templateId":"wpn_knight","enhanceLv":3,"equipped":3,"stats":{"atk":12}}]')
	var it: Dictionary = (Store.get_json("game_inventory", []) as Array)[0]
	_check(typeof(it["enhanceLv"]) == TYPE_INT and it["equipped"] == 3 and typeof(it["templateId"]) == TYPE_STRING and typeof((it["stats"] as Dictionary)["atk"]) == TYPE_FLOAT,
		"웹 장비: enhanceLv·equipped int, templateId 문자열, stats float")
	Store.set_str("game_nav", '{"cStage":{"id":12,"tot":14},"party":[3,5]}')
	var nav: Dictionary = Store.get_json("game_nav", {})
	_check(typeof((nav["cStage"] as Dictionary)["id"]) == TYPE_INT and (nav["party"] as Array).has(3), "웹 game_nav: cStage.id int, party.has(3)")
	Store.set_json("game_save", {"gold": 1500, "cleared": [1, 2, 3], "exp_pct": 50})
	var sv: Dictionary = Store.get_json("game_save", {})
	_check(typeof(sv["gold"]) == TYPE_FLOAT and typeof(sv["exp_pct"]) == TYPE_FLOAT and typeof((sv["cleared"] as Array)[0]) == TYPE_INT,
		"저장 왕복: gold·exp_pct 는 float(나눗셈 안전), cleared 번호는 int")
	Store.set_str("game_save", "hello")
	# 지연 저장: 프레임 끝까지는 디스크에 안 씀 → flush() 로 바로 씀
	var before := FileAccess.get_file_as_string(TEST_SAVE) if FileAccess.file_exists(TEST_SAVE) else ""
	_check(not before.contains("game_roster"), "지연 저장: set 직후에는 아직 파일에 없음")
	_check(Store.flush(), "flush 성공")
	_check(FileAccess.get_file_as_string(TEST_SAVE).contains("game_roster"), "flush 뒤 파일에 있음")
	_check(not FileAccess.file_exists(TEST_SAVE + ".tmp"), "쓰기 뒤 .tmp 가 남지 않음 (rename 한 번)")
	Store.set_str("game_inventory", "{깨진")
	_check(Store.get_json("game_inventory", "기본") == "기본", "깨진 JSON → fallback")
	_check(Store.keys().has("game_roster") and Store.has("game_save"), "keys / has")
	# 디스크에서 다시 읽기
	Store.use_path(TEST_SAVE)
	_check(FileAccess.file_exists(TEST_SAVE), "user:// 에 저장 파일 생김")
	Store.save_path = "user://__other.json"
	Store.use_path(TEST_SAVE)
	_check(Store.get_str("game_save") == "hello" and int((Store.get_json("game_roster", {}) as Dictionary).get("nextId", 0)) == 4,
		"파일에서 다시 읽어도 값 같음")
	var raw := JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE)) as Dictionary
	_check(raw != null and typeof(raw.get("game_roster")) == TYPE_STRING, "파일 형식 = { localStorage 키: 문자열 }")
	var n: int = Store.import_web_dump({"game_daily": "{\"used\":1}", "game_save": "x"}, false)
	_check(n == 1 and Store.get_str("game_save") == "hello" and Store.get_str("game_daily") == "{\"used\":1}", "웹 덤프 가져오기 (덮어쓰지 않음)")
	Store.remove("game_save")
	_check(Store.get_str("game_save") == null, "remove")
	Store.clear()
	_check(Store.keys().is_empty(), "clear")
	# .tmp 복구: save.json 이 없고 .tmp 만 있으면 그것을 쓴다
	Store.flush()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var f := FileAccess.open(TEST_SAVE + ".tmp", FileAccess.WRITE)
	f.store_string(JSON.stringify({"game_gold": "123"}))
	f.close()
	Store.save_path = "user://__other.json"
	Store.use_path(TEST_SAVE)
	_check(Store.get_str("game_gold") == "123" and FileAccess.file_exists(TEST_SAVE) and not FileAccess.file_exists(TEST_SAVE + ".tmp"),
		".tmp 로 복구 (save.json 없을 때)")


# ── 표시용 숫자 (웹 String(number) 와 같은지) ──

func _test_num_fmt() -> void:
	# [이름, IEEE 754 비트(정수), node 의 String(number) 결과] — 기대값은 node 로 직접 계산
	# 비트로 만드는 이유: Godot 의 문자열→실수 변환은 1.79e308·5e-324 같은 끝값을 정확히 못 읽는다
	var cases := [
		["1e21", 4921056587992461136, "1e+21"],
		["0.1+0.2", 4599075939470750516, "0.30000000000000004"],
		["1/3", 4599676419421066581, "0.3333333333333333"],
		["1e-7", 4502148214488346440, "1e-7"],
		["5e-324", 1, "5e-324"],
		["123456789012345678", 4862596447618666293, "123456789012345680"],
		["1.79e308", 9218829891383704473, "1.79e+308"],
		["9.999999999999999e20", 4921056587992461135, "999999999999999900000"],
		["-1e-7", -4721223822366429368, "-1e-7"],
		["1e20", 4906019910204099648, "100000000000000000000"],
		["0.000001", 4517329193108106637, "0.000001"],
		["1.7976931348623157e308", 9218868437227405311, "1.7976931348623157e+308"],
	]
	var buf := PackedByteArray()
	buf.resize(8)
	for c: Array in cases:
		buf.encode_s64(0, c[1])
		var f := buf.decode_double(0)
		var got := Num.fmt(f)
		_check(got == c[2], "Num.fmt(%s) == \"%s\" (JS 와 같음, 실제 \"%s\")" % [c[0], c[2], got])
	_check(Num.fmt(0.1 + 0.2) == "0.30000000000000004" and Num.fmt(1.0 / 3.0) == "0.3333333333333333", "Num.fmt: 계산 결과 0.1+0.2, 1/3")


# ── 도움 ──

func _find_by_id(arr: Array, id: int) -> Dictionary:
	for x: Variant in arr:
		if x is Dictionary and int((x as Dictionary).get("id", -1)) == id:
			return x
	return {}


# ── 실수 정밀도 (json_exact.gd · num_parse.gd · num.gd) ──

func _test_numbers() -> void:
	print("[실수 정밀도]")
	# 1) 무작위 실수 1만 개: 쓰기(가장 짧은 표기) → 읽기 가 비트까지 같음 (Godot JSON 은 같은 일을 하면 상당수 틀림)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261014
	var bad := 0
	var godot_bad := 0
	var n := 0
	while n < 10000:
		var x: float
		if n % 2 == 0:   # 비트 무작위 (모든 크기)
			x = NumParse._from_bits((rng.randi() << 32) | rng.randi())
			if is_nan(x) or is_inf(x):
				continue
		else:            # 게임에 나오는 크기
			x = rng.randf() * pow(10.0, float(rng.randi_range(-6, 9)))
		n += 1
		var txt := JsonExact.stringify([x])
		var back: Variant = JsonExact.parse(txt)
		if typeof(back) != TYPE_ARRAY or NumParse._bits(back[0]) != NumParse._bits(x):
			bad += 1
			if bad <= 3:
				print("    · 왕복 실패 %s → %s" % [txt, str(back)])
		var g: Variant = JSON.parse_string(txt)
		if typeof(g) != TYPE_ARRAY or NumParse._bits(g[0]) != NumParse._bits(x):
			godot_bad += 1
	_check(bad == 0, "무작위 실수 1만 개 JSON 왕복이 비트까지 같음 (실패 %d — 참고: Godot JSON 이면 %d개 틀림)" % [bad, godot_bad])
	# 2) JS 정답 (tests/fixtures/js_numbers.json: node 의 String(x) 와 비트) — 읽기·쓰기 모두 JS 와 같음
	var fx: Variant = JsonExact.parse(FileAccess.get_file_as_string("res://tests/fixtures/js_numbers.json"))
	var pbad := 0
	var fbad := 0
	for e: Array in fx:
		var bits: int = String(e[1]).to_int()
		if NumParse._bits(JsonExact.parse_number(e[0])) != bits:
			pbad += 1
		if NumFmt.fmt(NumParse._from_bits(bits)) != e[0]:
			fbad += 1
			if fbad <= 3:
				print("    · 표기 %s ≠ JS %s" % [NumFmt.fmt(NumParse._from_bits(bits)), e[0]])
	_check(pbad == 0 and fbad == 0 and (fx as Array).size() > 1000, "JS 정답 %d개: 읽기 틀림 %d · 표기(Num.fmt) 틀림 %d" % [(fx as Array).size(), pbad, fbad])
	# 3) 검수에서 1ulp 어긋났던 값: 첫 클리어 신규 클랜원 actionRec = 직업 기본 + rollActionRec (toFixed(2)) — Store 왕복으로 정확히
	var sbad := 0
	for base: float in [1.0, 1.1, 1.2, 0.9, 0.8, 1.05, 0.95, 1.15]:
		for k in range(5, 21):
			var rec: float = base + float(k) / 100.0
			Store.set_json("test_num", {"chars": [{"uid": 9, "actionRec": rec}]})
			var got: Variant = Store.get_json("test_num", {})
			if NumParse._bits(got["chars"][0]["actionRec"]) != NumParse._bits(rec):
				sbad += 1
	Store.remove("test_num")
	_check(sbad == 0, "actionRec 류 값 128개 Store 저장·읽기 비트까지 같음 (틀림 %d)" % sbad)
	# (GDScript 소스의 실수 리터럴도 같은 Godot 변환을 거쳐 틀릴 수 있어 문자열로만 비교)
	var a := JsonExact.parse_number("1.3599999999999999")
	_check(a != JsonExact.parse_number("1.36") and NumFmt.fmt(a) == "1.3599999999999999" and (JsonExact.parse("[1.3599999999999999]") as Array)[0] == a,
		"1.3599999999999999 를 1.36 과 구별해 읽고 그대로 씀")
	var ok_fmt := true
	for t: String in ["5091.900000000001", "0.30000000000000004", "80185174942016600", "1.1500000000000001", "1e-7", "1.7976931348623157e+308", "5e-324"]:
		if NumFmt.fmt(JsonExact.parse_number(t)) != t:
			ok_fmt = false
			print("    · %s → %s" % [t, NumFmt.fmt(JsonExact.parse_number(t))])
	_check(ok_fmt, "Num.fmt 가 JS 처럼 가장 짧은 표기 (num_scientific 의 17자리 대신)")


func _check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  " + label)
	else:
		_fail += 1
		_failures.append(label)
		print("  FAIL  " + label)


func _finish() -> void:
	print("──────────────────────────────")
	if _fail == 0:
		print("RESULT: PASS (%d개 통과)" % _pass)
	else:
		print("RESULT: FAIL (%d개 실패 / %d개 통과)" % [_fail, _pass])
		for f: String in _failures:
			print("  - " + f)
	quit(0 if _fail == 0 else 1)
