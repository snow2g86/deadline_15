extends SceneTree
## 1단계(기초) 머리 없는 시험
##   Godot --headless --path godot --script res://tests/check_foundation.gd
## 모든 JSON 읽기·manifest 개수 대조, 알려진 값 몇 개, 6개 언어 번역(키 맞춤·글꼴 사슬), Store 저장 왕복을 확인하고
## 통과 0 / 실패 1 로 끝난다. 진짜 저장(user://save.json)은 건드리지 않는다.

const TEST_SAVE := "user://test_foundation_save.json"
# --script 로 돌리면 오토로드 이름(Store 등)이 컴파일 때 보이지 않아, 같은 스크립트 형식으로 노드를 받아 쓴다
const StoreScript := preload("res://scripts/core/store.gd")
const DataDBScript := preload("res://scripts/core/data_db.gd")
const I18nScript := preload("res://scripts/core/i18n.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")
const NumParse := preload("res://scripts/core/num_parse.gd")
const NumFmt := preload("res://scripts/core/num.gd")
const FontsT := preload("res://scripts/core/fonts.gd")
const DF := preload("res://tools/data_format.gd")
const LANGS: PackedStringArray = ["ko", "en", "es", "ja", "zh-CN", "zh-TW"]

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
	_test_source()
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


# ── 데이터 원본 (2026-10-18~ godot/data 가 원본) ──

func _test_source() -> void:
	print("[데이터 원본]")
	var r := DF.run(DF.DATA_DIR, false)
	_check(r["ok"] and (r["changed"] as Array).is_empty(), "godot/data %d개 파일이 정해진 모양 + manifest 최신 (data_tool --check) %s" % [r["files"], str(r["changed"]) + str(r["errors"])])
	var rb := DF.run(DF.BASELINE_DIR, false)
	_check(rb["ok"] and (rb["changed"] as Array).is_empty(), "기준 데이터 tests/baseline/data %d개 파일 모양·manifest 맞음" % rb["files"])
	var lk := DF.lock_check()
	_check(lk["ok"], "기준 잠금 LOCK.json = golden·fixtures·baseline/data 파일 (%d개) %s" % [DF.lock_scan().size(), str((lk["errors"] as Array).slice(0, 3))])
	var man: Dictionary = JsonExact.parse(FileAccess.get_file_as_string("res://data/manifest.json"))
	_check(str(man.get("generator", "")) == "godot/tools/data_tool.gd" and int(man.get("format", 0)) == 2, "manifest 는 data_tool 이 만든 형식 2 (웹 변환기 아님)")
	# 정해진 모양이 값을 바꾸지 않음: 모든 파일을 다시 읽어 canon → parse → 같은 글 (멱등) + 실수 비트 그대로
	var stable := true
	for rel: String in ["stages.json", "jab.json", "battle_constants.json", "lang/ko.json", "story/ja.json"]:
		var t := FileAccess.get_file_as_string("res://data/" + rel)
		var t2 := DF.canon(JsonExact.parse(t))
		stable = stable and t == t2
	_check(stable, "정해진 모양은 멱등 (읽고 다시 써도 같은 글)")
	_check(DataDB.data_dir == "res://data/" and not DataDB.is_baseline and not DataDB.sha_mismatch,
		"게임 DataDB 는 지금 데이터 res://data/ (기준 사본 아님 · sha1 어긋남 없음) — %s" % DataDB.data_dir)
	_test_bad_inputs()
	var RR: GDScript = load("res://scripts/logic/resume_rules.gd")
	var h0 := str(RR.call("current_stamp")["dataHash"])
	DataDB.sha_mismatch = true
	var h1 := str(RR.call("current_stamp")["dataHash"])
	DataDB.sha_mismatch = false
	_check(h0.length() == 32 and h1 == str(RR.get("INVALID_HASH")), "sha1 이 어긋난 실행에서는 이어하기 데이터 해시가 무효 (%s → %s)" % [h0.left(8), h1])
	var n_last := 0
	for code: String in ["ko", "en", "es", "ja", "zh-CN", "zh-TW", "sample"]:
		var sts: Dictionary = DataDB.story(code).get("stages", {})
		for sid: Variant in sts.keys():
			var b: Variant = (sts[sid] as Dictionary).get("battle")
			if b is Dictionary and (b as Dictionary).has("last"):
				n_last += 1
	_check(n_last == 0, "대본에 쓰이지 않는 'last'(마지막 적) 대사 없음 — 7개 대본 (%d)" % n_last)
	var odd := [0.1 + 0.2]
	for ns: String in ["1.3599999999999999", "5e-324", "1.7976931348623157e+308", "123456789012345680000", "-0.000001", "0.07"]:
		odd.append(JsonExact.parse_number(ns))   # GDScript 17자리 실수 리터럴은 정확하지 않아 문자열에서
	var back: Array = JsonExact.parse(DF.canon({"v": odd}))["v"]
	var bits_ok := true
	for i in odd.size():
		bits_ok = bits_ok and PackedFloat64Array([odd[i]]).to_byte_array() == PackedFloat64Array([back[i]]).to_byte_array()
	_check(bits_ok, "정해진 모양으로 쓰고 읽은 실수가 비트 단위로 같음 %s" % DF.canon(odd).strip_edges())


## (2026-10-18 검수) 나쁜 입력: 고친 바이트 → sha1 오류 · 1e999 → --write 가 아무것도 쓰지 않고 실패 · 중복 키 → 점검·쓰기·DataDB 모두 오류
func _test_bad_inputs() -> void:
	var tmp := "user://test_datatool/"
	# 1) 바이트 하나 고침 (data_tool 을 안 돌림) → DataDB sha1 오류 · sha_mismatch
	_copy_data(tmp)
	var jab := FileAccess.get_file_as_string(tmp + "jab.json")
	_put(tmp + "jab.json", jab.replace("\"atk\": 25", "\"atk\": 26"))
	var db := DataDBScript.new()
	db.use_dir(tmp)
	var sha_err := false
	for e: String in db.errors:
		sha_err = sha_err or (e.contains("jab.json") and e.contains("sha1"))
	_check(sha_err and db.sha_mismatch and jab.contains("\"atk\": 25"), "JSON 을 고치고 --write 를 잊으면 DataDB 가 sha1 오류 · sha_mismatch (이어하기 해시 무효)")
	db.free()
	# 2) 1e999 (읽으면 무한) → --write 도 실패 · 아무 파일도 안 바뀜
	_copy_data(tmp)
	var bad := jab.replace("\"resRec\": 0", "\"resRec\": 1e999")
	_put(tmp + "jab.json", bad)
	var man0 := FileAccess.get_file_as_string(tmp + "manifest.json")
	var r := DF.run(tmp, true)
	var num_err := false
	for e2: String in r["errors"]:
		num_err = num_err or e2.contains("쓸 수 없는 숫자")
	_check(not r["ok"] and num_err and FileAccess.get_file_as_string(tmp + "jab.json") == bad and FileAccess.get_file_as_string(tmp + "manifest.json") == man0,
		"1e999 → data_tool --write 가 실패 (오류: %s) · 어떤 파일도 쓰지 않음" % str(r["errors"]).left(90))
	var ce: Array = []
	DF.canon({"a": [1, INF]}, ce)
	_check(ce.size() == 1 and str(ce[0]).begins_with("a[1]"), "canon: NaN·무한 실수는 경로와 함께 오류 (%s)" % str(ce))
	# 3) 같은 사전에 같은 키 두 번 → 점검·쓰기·DataDB 모두 오류
	_copy_data(tmp)
	var ui := FileAccess.get_file_as_string(tmp + "ui.json")
	var dup := ui.substr(0, 2) + "  \"NAV_TABS\": 1,\n" + ui.substr(2)   # 맨 위 "{\n" 바로 뒤에 같은 전역 이름
	_put(tmp + "ui.json", dup)
	var rc := DF.run(tmp, false)
	var rw := DF.run(tmp, true)
	var db2 := DataDBScript.new()
	db2.use_dir(tmp)
	var dup_db := false
	for e3: String in db2.errors:
		dup_db = dup_db or e3.contains("같은 키가 두 번")
	db2.free()
	_check(not rc["ok"] and not rw["ok"] and str(rc["errors"]).contains("NAV_TABS") and FileAccess.get_file_as_string(tmp + "ui.json") == dup and dup_db,
		"중복 키 → 점검·--write 실패 (쓰지 않음) · DataDB 오류 (%s)" % str(rc["errors"]).left(90))
	_rm_dir(tmp)


func _copy_data(dst: String) -> void:
	_rm_dir(dst)
	for rel: String in ["", "lang/", "story/"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst + rel))
		for f: String in DirAccess.get_files_at("res://data/" + rel):
			if f.get_extension() == "json":
				_put(dst + rel + f, FileAccess.get_file_as_string("res://data/" + rel + f))


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _rm_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for rel: String in ["lang/", "story/", ""]:
		for f: String in DirAccess.get_files_at(dir + rel):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + rel + f))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + rel))


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

	for code: String in LANGS:
		var st: Dictionary = DataDB.story(code)
		_check((st.get("episodes", {}) as Dictionary).size() == 10 and st.has("cast"), "스토리 %s: 에피소드 10개 + cast" % code)
	# 새 언어 대본: 한국어 대본과 장면 구성이 같은지 (에피소드·장면 키·대사 줄 수)
	var st_ko: Dictionary = DataDB.story("ko")
	for code: String in ["ja", "zh-CN", "zh-TW"]:
		var st2: Dictionary = DataDB.story(code)
		var diff := _story_shape_diff(st_ko, st2)
		_check(diff.is_empty(), "스토리 %s: 장면 키·대사 줄 수가 ko 와 같음%s" % [code, ("" if diff.is_empty() else " — " + ", ".join(diff.slice(0, 5)))])
	var cn: String = ((DataDB.story("zh-CN").get("cast", {}) as Dictionary).get("commander", {}) as Dictionary).get("name", "")
	_check(cn == "里安", "스토리 zh-CN cast.commander.name == 里安 (실제 %s)" % cn)

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
	_check(I18n.LANGS == LANGS and DataDB.lang_codes().size() == 6, "6개 언어: I18n.LANGS == %s, DataDB 언어 팩 %d개" % [str(LANGS), DataDB.lang_codes().size()])
	var seen: Dictionary = {}
	for code: String in LANGS:
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
	var uniq := {}
	for code: String in LANGS:
		uniq[seen[code]] = true
	_check(uniq.size() == LANGS.size(), "언어마다 다른 문자열 (6개 모두)")
	var saved: Variant = Store.get_json("game_settings", {})
	_check(saved is Dictionary and (saved as Dictionary).get("language") == "zh-TW", "set_language 가 game_settings.language 에 저장 (마지막 zh-TW)")
	_test_i18n_new_langs()
	var tips: Variant = I18n.t_raw("battle.loading_tips")
	_check(tips is Array and (tips as Array).size() > 0 and typeof((tips as Array)[0]) == TYPE_STRING, "t_raw: 배열 값(battle.loading_tips) 그대로")
	_check(I18n.t_raw("character.names") is Array, "t_raw: character.names 그대로")
	_check(I18n.t_raw("no.such") == "no.such" and I18n.t_raw("common.game_title") == "DEADLINE 15", "t_raw: 없는 키·문자열은 t() 와 같음")
	_check(I18n.interpolate("[{n}]", {"n": null}) == "[null]", "null 자리표시자 → \"null\" (웹과 같음)")
	_check(I18n.interpolate("a {x} {y}", {"y": 2.0}) == "a {x} 2", "없는 자리표시자는 그대로, 2.0 → \"2\"")
	Store.set_json("game_settings", {"language": "en", "speed": 2})
	I18n.reload()
	_check(I18n.current_lang == "en", "Store game_settings.language 에서 언어 읽기")
	I18n.set_language("ko")
	var s2: Dictionary = Store.get_json("game_settings", {})
	_check(int(s2.get("speed", 0)) == 2, "set_language 가 다른 설정(speed)을 지우지 않음")
	Store.set_json("game_settings", {"language": "xx"})
	I18n.reload()
	_check(I18n.current_lang == I18nScript.detect_lang(OS.get_locale()), "저장된 언어가 모르는 값이면 OS 언어 감지로")
	Store.remove("game_settings")
	I18n.reload()
	var os_lang: String = I18nScript.detect_lang(OS.get_locale())
	_check(I18n.current_lang == os_lang, "설정이 없으면 OS 언어(%s → %s, 웹 navigator.language 와 같은 규칙)" % [OS.get_locale(), os_lang])
	# 웹 i18n.js _detectLang 과 같은 표
	var cases := {"ko_KR": "ko", "en_US": "en", "es_MX": "es", "ja_JP": "ja", "ja": "ja", "zh_CN": "zh-CN", "zh": "zh-CN", "zh_SG": "zh-CN",
		"zh_TW": "zh-TW", "zh_HK": "zh-TW", "zh_MO": "zh-TW", "zh_Hant": "zh-TW", "zh_Hant_TW": "zh-TW", "zh-Hans-HK": "zh-CN", "zh-TW": "zh-TW",
		"ko": "ko", "ko-KR": "ko", "zh-Hans": "zh-CN", "zh-CN": "zh-CN", "zh-Hant": "zh-TW", "zh-HK": "zh-TW", "es": "es", "en": "en",
		"fr_FR": "en", "fr-FR": "en", "de": "en", "de_DE": "en", "pt-BR": "en", "pt_BR": "en", "kok": "en", "": "en"}
	var bad := []
	for loc: String in cases.keys():
		if I18nScript.detect_lang(loc) != cases[loc]:
			bad.append("%s→%s" % [loc, I18nScript.detect_lang(loc)])
	_check(bad.is_empty(), "detect_lang: ko→ko, ja→ja, zh-TW·HK·MO·Hant→zh-TW, 그 밖의 zh→zh-CN, 지원 안 하는 언어·빈 값→en %s" % str(bad))
	Store.set_json("game_settings", {"language": "zh-TW"})
	I18n.reload()
	_check(I18n.current_lang == "zh-TW" and FontsT.lang == "zh-TW", "설정 zh-TW → 언어·글꼴 사슬 zh-TW")
	Store.remove("game_settings")
	I18n.set_language("ko")
	Store.remove("game_settings")


## ja·zh-CN·zh-TW: 언어 팩 키가 ko 와 같음 (빠짐·남음 0), 자리표시자 같음, gd.* 키는 6개 언어 모두 같음, 글꼴 사슬
func _test_i18n_new_langs() -> void:
	var ko_leaves := {}
	_leaves(DataDB.lang("ko"), "", ko_leaves)
	var ph := RegEx.create_from_string("\\{(\\w+)\\}")
	for code: String in ["ja", "zh-CN", "zh-TW"]:
		var lv := {}
		_leaves(DataDB.lang(code), "", lv)
		var miss := []
		var extra := []
		var ph_bad := []
		for k: String in ko_leaves.keys():
			if not lv.has(k):
				miss.append(k)
			elif typeof(ko_leaves[k]) == TYPE_STRING and _ph_set(ph, str(ko_leaves[k])) != _ph_set(ph, str(lv[k])):
				ph_bad.append(k)
		for k: String in lv.keys():
			if not ko_leaves.has(k):
				extra.append(k)
		_check(miss.is_empty() and extra.is_empty(), "%s: 웹 언어 팩 키 %d개가 ko 와 같음 (빠짐 %d · 남음 %d %s)" % [code, lv.size(), miss.size(), extra.size(), str(miss.slice(0, 3) + extra.slice(0, 3))])
		_check(ph_bad.is_empty(), "%s: 자리표시자 {..} 가 ko 와 같음 %s" % [code, str(ph_bad.slice(0, 5))])
	# Godot 화면 글 (gd.* — 2026-10-18 lang_extra 를 언어 팩 안 "gd" 로 합침) — 6개 언어 모두 같은 키
	_check(not DirAccess.dir_exists_absolute("res://data/lang_extra"), "data/lang_extra 폴더 없음 (gd.* 는 data/lang/<언어>.json 안)")
	var extra_keys := {}
	for code: String in LANGS:
		var d: Variant = DataDB.lang(code).get("gd")
		var lv2 := {}
		if d is Dictionary:
			_leaves(d, "gd", lv2)
		extra_keys[code] = lv2
	var base: Dictionary = extra_keys["ko"]
	for code: String in LANGS:
		var other: Dictionary = extra_keys[code]
		var same := other.size() == base.size()
		var ph_bad2 := []
		for k: String in base.keys():
			if not other.has(k):
				same = false
			elif _ph_set(ph, str(base[k])) != _ph_set(ph, str(other[k])):
				ph_bad2.append(k)
		_check(same and base.size() > 50 and ph_bad2.is_empty(), "lang/%s.json gd.*: 키 %d개 ko 와 같음, 자리표시자 같음 %s" % [code, other.size(), str(ph_bad2)])
	# 견본 문자열 (웹 팩 + Godot 전용)
	var samples := {
		"ja": {"nav.sortie": "出撃", "battle.surrender": "降伏", "gd.result.retry": "再挑戦", "settings.language_ja": "日本語 (Japanese)"},
		"zh-CN": {"battle.surrender": "投降", "gd.buff.shield": "护盾", "gd.result.retry": "重新挑战", "settings.language_zh-CN": "简体中文 (Simplified Chinese)"},
		"zh-TW": {"battle.surrender": "投降", "gd.buff.shield": "護盾", "gd.result.retry": "重新挑戰", "settings.language_zh-TW": "繁體中文 (Traditional Chinese)"},
	}
	for code: String in samples.keys():
		I18n.set_language(code)
		var sm: Dictionary = samples[code]
		var bad := []
		for k: String in sm.keys():
			if I18n.t(k) != sm[k]:
				bad.append("%s=%s" % [k, I18n.t(k)])
		var tp := I18n.t("gd.tip.turns", {"n": 3})
		_check(bad.is_empty() and tp.contains("3") and not tp.contains("{"), "%s: 견본 문자열 %s · gd.tip.turns → %s" % [code, str(bad), tp])
		_check(FontsT.lang == code and FontsT.chain_keys(code)[0] == {"ja": "jp", "zh-CN": "sc", "zh-TW": "tc"}[code], "%s: 글꼴 사슬 맨 앞 %s" % [code, FontsT.chain_keys(code)])
	# 설정 화면 라벨: 6개 언어 이름이 모든 언어에서 같은 자기 이름
	var labels_ok := true
	for code: String in LANGS:
		I18n.set_language(code)
		for c2: String in LANGS:
			if I18n.t("settings.language_" + c2) != (DataDB.lang("ko")["settings"] as Dictionary)["language_" + c2]:
				labels_ok = false
	_check(labels_ok, "settings.language_* 6개 라벨이 모든 언어에서 같음 (자기 언어 이름)")
	# 언어를 바꿔도 굵기 글꼴은 같은 객체 (덮어쓴 글꼴이 그대로 새 사슬로 그려짐)
	var f700: Font = FontsT.weight(700)
	I18n.set_language("ja")
	var rid_ja: RID = f700.get_rids()[0]
	I18n.set_language("zh-CN")
	_check(FontsT.weight(700) == f700 and f700.get_rids()[0] != rid_ja and f700.get_rids().size() == 3, "언어를 바꾸면 같은 글꼴 객체의 사슬이 바뀜 (ja → zh-CN)")
	I18n.set_language("ko")
	_check(f700.get_rids().size() == 4 and FontsT.chain_keys("ko") == ["kr", "jp", "sc", "tc"] and FontsT.chain_keys("ja") == ["jp", "kr", "sc"]
		and FontsT.chain_keys("zh-CN") == ["sc", "tc", "kr"] and FontsT.chain_keys("zh-TW") == ["tc", "sc", "kr"], "글꼴 사슬 순서 (ko·en·es KR→JP→SC→TC, ja JP→KR→SC, zh-CN SC→TC→KR, zh-TW TC→SC→KR)")


func _leaves(node: Variant, pre: String, out: Dictionary) -> void:
	if node is Dictionary:
		for k: Variant in (node as Dictionary).keys():
			_leaves(node[k], (pre + "." + str(k)) if pre != "" else str(k), out)
	else:
		out[pre] = node


func _ph_set(re: RegEx, text: String) -> String:
	var names := {}
	for m: RegExMatch in re.search_all(text):
		names[m.get_string(1)] = true
	var arr := names.keys()
	arr.sort()
	return ",".join(arr)


## 대본 모양 비교: episodes.<n>.<장면> 키와 각 장면 대사 줄 수
func _story_shape_diff(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	var ea: Dictionary = a.get("episodes", {})
	var eb: Dictionary = b.get("episodes", {})
	for ek: Variant in ea.keys():
		if not eb.has(ek):
			out.append("ep %s 없음" % ek)
			continue
		var sa: Variant = ea[ek]
		var sb: Variant = eb[ek]
		if sa is Dictionary and sb is Dictionary:
			for sk: Variant in (sa as Dictionary).keys():
				if not (sb as Dictionary).has(sk):
					out.append("%s.%s 없음" % [ek, sk])
				elif sa[sk] is Array and (not (sb[sk] is Array) or (sa[sk] as Array).size() != (sb[sk] as Array).size()):
					out.append("%s.%s 줄 수" % [ek, sk])
	return out


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
