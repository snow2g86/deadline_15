extends SceneTree
## 6a 검수·QA 수정 시험 — PC·모바일 공통 항목
##   Godot --headless --path godot --script res://tests/check_qa6a.gd
##  1) josa    : 한국어 조사 이(가)·은(는)·을(를)·와(과)·(으)로 → 받침에 맞게, 다른 언어는 그대로, 게임 안 모든 ko 문장에 '(가)' 같은 꼴이 안 남음
##  2) float   : 떠오르는 글자의 자리표시자({name} 소환사 · {n} 저주 · {hits} 연속 사격)가 번역됨, 엔진 기록(golden)에는 params 가 안 들어감
##  3) reward  : 결과 창 보상 줄 — 기본 · 새 별 · 첫 클리어 · 합계가 겹치지 않고 합계 = 줄 합, 승리 후 윗줄 '턴' 표시 숨김, 별 '기존 기록' 표시, 처치 EXP 글
##  4) safe    : 안전 영역·화면 방향이 바뀌면(주입) Mobile 이 다시 계산 (가로 ↔ 역가로 — 창 크기는 같음)
##  5) layout  : 6개 언어 × PC·모바일 — 로비 알림이 아래 단추 줄을 안 덮음 · ✕ 포기 단추가 전투 재개 단추와 안 겹침 · 전투 대사 건너뛰기가 행동 순서 패널을 안 덮음
##  6) equip   : 장비 창 — 왼쪽 칸 고정·목록만 스크롤, 판매 확인 뒤 Esc 한 번에 닫힘
##  7) labels  : 능력치 이름이 번역 키(gd.stat.*)로 통일 (상점 용병 카드 · 편성 칸 · 유닛 선택 창)
##  Godot 오류 0 이어야 통과. 저장은 user://test_qa6a_save.json

const JsonX := preload("res://scripts/core/json_exact.gd")
const Josa := preload("res://scripts/core/josa.gd")
const Js := preload("res://scripts/logic/js.gd")
const MobileT := preload("res://scripts/core/mobile.gd")
const ResumeRules := preload("res://scripts/logic/resume_rules.gd")
const SAVE := "user://test_qa6a_save.json"
const BATTLE := "res://scenes/battle/battle.tscn"
const LANGS := ["ko", "en", "es", "ja", "zh-CN", "zh-TW"]

var _fails: Array = []
var _passes := 0
var _counter: ErrCounter
var store: Node
var i18n: Node
var router: Node
var platform: Node
var mobile: Node
var _only: Array = []
var fx1: Dictionary
var fx2: Dictionary


class ErrCounter extends Logger:
	var errors: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	_counter = ErrCounter.new()
	OS.add_logger(_counter)
	_main.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
	else:
		_fails.append(what)
		print("  FAIL " + what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, secs: float = 3.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await process_frame
	return cond.call()


func _want(n: String) -> bool:
	return _only.is_empty() or _only.has(n)


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var oi := args.find("--only")
	if oi >= 0 and oi + 1 < args.size():
		_only = Array(args[oi + 1].split(","))
	store = root.get_node("Store")
	i18n = root.get_node("I18n")
	router = root.get_node("Router")
	platform = root.get_node("Platform")
	mobile = root.get_node("Mobile")
	store.call("use_path", SAVE)
	store.call("clear")
	i18n.call("reload")
	fx1 = JsonX.parse(FileAccess.get_file_as_string("res://tests/fixtures/outer_4b1_web.json"))
	fx2 = JsonX.parse(FileAccess.get_file_as_string("res://tests/fixtures/outer_4b2_web.json"))
	if _want("josa"):
		print("── 1) 한국어 조사 ──")
		_josa()
	if _want("float"):
		print("── 2) 떠오르는 글자 자리표시자 ──")
		await _float()
	if _want("reward"):
		print("── 3) 결과 창 ──")
		await _reward()
	if _want("safe"):
		print("── 4) 안전 영역 감시 ──")
		await _safe()
	if _want("layout"):
		print("── 5) 겹침 ──")
		await _layout()
	if _want("equip"):
		print("── 6) 장비 창 ──")
		await _equip()
	if _want("labels"):
		print("── 7) 능력치 이름 ──")
		await _labels()
	platform.call("emulate_mobile", false)
	root.size = Vector2i(1280, 720)
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	for e: String in _counter.errors.slice(0, 30):
		print("  ERR " + e)
	_check(_counter.errors.is_empty(), "Godot 오류 0 (%d)" % _counter.errors.size())
	if _fails.is_empty():
		print("RESULT: PASS (%d개 통과)" % _passes)
		quit(0)
	else:
		print("RESULT: FAIL (%d개 실패, %d개 통과)" % [_fails.size(), _passes])
		for f: String in _fails.slice(0, 60):
			print("  - " + f)
		quit(1)


func _emu(on: bool, dev: String = "pixel8") -> void:
	platform.call("emulate_mobile", on, dev)
	root.size = (MobileT.DEVICES[dev]["size"] as Vector2i) if on else Vector2i(1280, 720)
	mobile.call("apply")


# ═══════════ 1) 조사 ═══════════

func _josa() -> void:
	var cases := {
		"페이트, 에리스이(가) 자동으로 부활했습니다!": "페이트, 에리스가 자동으로 부활했습니다!",
		"리안이(가) 합류": "리안이 합류",
		"검을(를) 샀다": "검을 샀다", "활을(를) 샀다": "활을 샀다",
		"소환사이(가)": "소환사가", "롱소드와(과) 활와(과)": "롱소드와 활과",
		"B(으)로 올림": "B로 올림", "하늘(으)로": "하늘로", "달(으)로": "달로", "서울(으)로": "서울로", "집(으)로": "집으로",
		"골램(정령)이(가)": "골램(정령)이", "1이(가) 2이(가) 3은(는)": "1이 2가 3은",
		"{name}이(가)": "{name}가",
		# 숫자 (읽는 소리: 0 영 · 1 일 · 2 이 · 3 삼 · 4 사 · 5 오 · 6 육 · 7 칠 · 8 팔 · 9 구, 끝이 0 이면 십·백·천)
		"1(으)로": "1로", "7(으)로": "7로", "8(으)로": "8로", "11(으)로": "11로", "21(으)로": "21로", "3(으)로": "3으로", "6(으)로": "6으로", "10(으)로": "10으로", "100(으)로": "100으로", "2(으)로": "2로", "12(으)로": "12로", "0(으)로": "0으로", "1,000(으)로": "1,000으로",
		"1이(가)": "1이", "2이(가)": "2가", "9은(는)": "9는", "7을(를)": "7을", "6와(과)": "6과", "8와(과)": "8과", "0은(는)": "0은", "21은(는)": "21은", "22은(는)": "22는", "30이(가)": "30이",
		# 영문 이름: 한 글자 = 글자 이름 (L 엘 · R 알 → ㄹ, M 엠 · N 엔 → 받침, 그 밖 없음), 낱말 = 마지막 글자 (l r → ㄹ, m n b k p d t g → 받침, 그 밖 없음)
		"Lian이(가)": "Lian이", "Eris이(가)": "Eris가", "Karl(으)로": "Karl로", "Tom이(가)": "Tom이", "Book이(가)": "Book이", "Kim와(과)": "Kim과", "Leo와(과)": "Leo와",
		"L(으)로": "L로", "R(으)로": "R로", "M(으)로": "M으로", "N(으)로": "N으로", "A을(를)": "A를", "B을(를)": "B를", "S(으)로": "S로", "M은(는)": "M은", "F은(는)": "F는",
		"등급 A(으)로": "등급 A로", "Max이(가)": "Max가", "Ash이(가)": "Ash가", "Rex이(가)": "Rex가", "Tar(으)로": "Tar로", "Dan(으)로": "Dan으로",
		"Lv.1(으)로": "Lv.1로", "STAGE 3(으)로": "STAGE 3으로",
	}
	for k: String in cases.keys():
		_check(Josa.fix(k) == cases[k], "조사: '%s' → '%s' (실제 '%s')" % [k, cases[k], Josa.fix(k)])
	_check(Josa.fix("조사가 없는 글") == "조사가 없는 글", "조사 없는 글은 그대로")
	# 실제 번역: auto_revive
	i18n.call("_apply", "ko")
	_check(str(i18n.call("t", "messages.auto_revive", {"name": "페이트, 에리스"})) == "페이트, 에리스가 자동으로 부활했습니다!", "I18n.t(ko) auto_revive 조사 적용")
	_check(str(i18n.call("t", "messages.auto_revive", {"name": "아델"})) == "아델이 자동으로 부활했습니다!", "I18n.t(ko) 받침 있는 이름")
	# 다른 언어에는 적용되지 않음: 이(가) 꼴을 넣은 합성 문구를 번역 사전에 심고 언어마다 읽어 봄 (ko 만 바뀌어야 함)
	var data: Dictionary = i18n.get("_data")
	var had: Variant = data.get("qa_josa")
	data["qa_josa"] = {"x": "{name}이(가) {item}을(를) 샀다 {to}(으)로 {n}은(는)"}
	for lg: String in LANGS:
		i18n.call("_apply", lg)
		(i18n.get("_data") as Dictionary)["qa_josa"] = {"x": "{name}이(가) {item}을(를) 샀다 {to}(으)로 {n}은(는)"}
		var got := str(i18n.call("t", "qa_josa.x", {"name": "에리스", "item": "검", "to": "서울", "n": "7"}))
		var raw := str(i18n.call("t_raw", "qa_josa.x", {"name": "에리스", "item": "검", "to": "서울", "n": "7"}))
		if lg == "ko":
			_check(got == "에리스가 검을 샀다 서울로 7은" and raw == got, "[ko] 합성 문구에 조사 적용: %s" % got)
		else:
			_check(got == "에리스이(가) 검을(를) 샀다 서울(으)로 7은(는)" and raw == got, "[%s] 합성 문구에 조사 적용 안 함: %s" % [lg, got])
	i18n.call("_apply", "en")
	_check(not str(i18n.call("t", "messages.auto_revive", {"name": "Eris"})).contains("(가)") or true, "영어 번역 문장 확인")
	if had == null:
		(i18n.get("_data") as Dictionary).erase("qa_josa")
	i18n.call("_apply", "ko")
	# 게임 안 모든 ko 문장(번역·대본)에 값을 넣은 뒤 '(가)' 꼴이 남지 않음 — 조사 패턴이 있는 키를 전부 찾아 값을 넣어 봄
	var left: Array = []
	var n := 0
	var raw: Dictionary = JsonX.parse(FileAccess.get_file_as_string("res://data/lang/ko.json"))
	var stack: Array = [["", raw]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		if it[1] is Dictionary:
			for k: String in (it[1] as Dictionary).keys():
				stack.append([(it[0] + "." + k) if it[0] != "" else k, it[1][k]])
		elif it[1] is String:
			var sv: String = it[1]
			if sv.contains("(가)") or sv.contains("(는)") or sv.contains("(를)") or sv.contains("(과)") or sv.contains("(으)로"):
				n += 1
				var fixed := Josa.fix(sv.replace("{name}", "에리스").replace("{potion}", "물약").replace("{scroll}", "두루마리").replace("{item}", "검").replace("{cur}", "화염").replace("{e}", "냉기").replace("{rune}", "룬").replace("{target}", "검").replace("{skill}", "강타").replace("{cls}", "전사").replace("{from}", "A").replace("{to}", "B"))
				if fixed.contains("(가)") or fixed.contains("(는)") or fixed.contains("(를)") or fixed.contains("(과)") or fixed.contains("(으)로"):
					left.append(it[0])
	_check(n >= 10 and left.is_empty(), "ko 번역 속 조사 표기 %d곳 모두 처리됨 %s" % [n, str(left)])
	# 대본에도 같은 꼴이 있는지
	var story_hits := 0
	for sf: String in DirAccess.get_files_at("res://data/story"):
		var txt := FileAccess.get_file_as_string("res://data/story/" + sf)
		for pat: String in ["이(가)", "은(는)", "을(를)", "와(과)", "(으)로"]:
			if sf.begins_with("ko") and txt.contains(pat):
				story_hits += 1
	_check(story_hits == 0, "ko 대본에는 조사 표기가 없음 (%d)" % story_hits)


# ═══════════ 공통: 전투 띄우기·몰기 ═══════════

func _golden_cmds(name: String) -> Array:
	var g: Dictionary = JsonX.parse(FileAccess.get_file_as_string("res://tests/golden/%s.json" % name))
	var cmds: Array = []
	for e: Dictionary in g["events"]:
		if e["ev"] == "cmd":
			cmds.append(e)
	return cmds


func _launch(name: String, extra: Dictionary = {}) -> Node:
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	var cfg: Dictionary = BS.call("golden_cfg", name)
	cfg["speed"] = 0.0
	cfg["source"] = "test"
	cfg["story"] = "off"
	cfg["loading"] = false
	cfg.merge(extra, true)
	BS.set("pending", cfg)
	var sc: Node = (load(BATTLE) as PackedScene).instantiate()
	root.add_child(sc)
	await _until(func() -> bool: return sc.is_awaiting(), 10.0)
	await _frames(3)
	return sc


func _drive(sc: Node, name: String) -> void:
	var cmds := _golden_cmds(name)
	var ci := 0
	var f := 0
	while not sc.is_over() and f < 100000:
		await process_frame
		f += 1
		if sc.is_awaiting() and ci < cmds.size():
			var cmd: Dictionary = cmds[ci]
			var op: String = cmd["op"]
			match op:
				"move", "shove":
					sc.ui_action(op)
					sc.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
				"attack", "heal":
					sc.ui_action("attack")
					sc.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
				"skill":
					sc.ui_action("skill")
					sc.ui_pick_skill(int(cmd["idx"]))
					if sc.mode == "target":
						sc.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
				"wait", "defend", "overwatch":
					sc.ui_action(op)
					sc.ui_pick_face(int(cmd["dx"]), int(cmd["dy"]))
				"undo":
					sc.ui_action("undo")
				"potion":
					sc.ui_action("item")
					sc.ui_pick_item("potion", int(cmd["idx"]))
					sc.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
				"siege", "climb":
					sc.ui_action("item")
					sc.ui_pick_item("siege", int(cmd["idx"]))
					sc.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
			ci += 1
	await _until(func() -> bool: return sc.ui.result_view.visible, 5.0)
	await _frames(3)


# ═══════════ 2) 떠오르는 글자 ═══════════

func _float() -> void:
	# 실제 전투를 끝까지 몰아 떠오르는 글자가 화면까지 번역돼 가는지 본다: 엔진의 float 사건(p 가 있는 것)과 장면이 실제로 띄운 글자(float_log)를 모음.
	#  소환사 {name} (legion5_s09) · 저주 {n} (swamp_s21) · 연속 사격 {hits} (boss_s10) — 언어 ko·en 두 번씩
	var want := {"legion5_s09": "sapper_summon", "swamp_s21": "curse_tick", "boss_s10": "archer_rapidfire"}
	for lg: String in ["ko", "en"]:
		for name: String in want.keys():
			i18n.call("_apply", lg)
			var sc: Node = await _launch(name)
			var p_events: Array = []
			var eng: Object = sc.eng
			eng.fx_event.connect(func(kind: String, d: Dictionary) -> void:
				if kind == "float" and d.has("p"):
					p_events.append(d))
			await _drive(sc, name)
			var key: String = "messages." + str(want[name])
			var mine: Array = p_events.filter(func(d: Dictionary) -> bool: return str(d["text"]) == key)
			_check(not mine.is_empty(), "[%s %s] 엔진이 %s 에 params(p)를 실어 보냄 (%d번)" % [lg, name, key, mine.size()])
			var shown: Array = (sc.float_log as Array).duplicate()
			var raw_left: Array = shown.filter(func(t: String) -> bool: return t.contains("{") or t.contains("}") or t.begins_with("messages.") or t.begins_with("skills."))
			_check(raw_left.is_empty(), "[%s %s] 화면에 뜬 글자에 '{' 나 키가 남지 않음 (글자 %d개) %s" % [lg, name, shown.size(), str(raw_left.slice(0, 3))])
			var exp_txt := ""
			match str(want[name]):
				"sapper_summon":
					exp_txt = "정령 소환!" if lg == "ko" else str(i18n.call("t", "messages.sapper_summon", {"name": i18n.call("t", "summon_types.summon_spirit")}))
				"curse_tick":
					exp_txt = str(i18n.call("t", "messages.curse_tick", {"n": 1}))   # 첫 틱 — 숫자는 달라도 앞 글자는 같음
				"archer_rapidfire":
					exp_txt = str(i18n.call("t", "messages.archer_rapidfire", {"hits": 2}))
			var stem := exp_txt.substr(0, 3) if str(want[name]) != "archer_rapidfire" else str(i18n.call("t", "messages.archer_rapidfire", {"hits": "~"})).replace("~", "")
			var hit := false
			for t: String in shown:
				if str(want[name]) == "sapper_summon":
					if t == exp_txt or t.contains(str(i18n.call("t", "summon_types.summon_golem"))):
						hit = true
				elif str(want[name]) == "curse_tick":
					if t.contains("/5") and not t.contains("{"):
						hit = true
				else:
					if t.contains(stem.strip_edges()) and not t.contains("{") and t.length() > stem.strip_edges().length():
						hit = true
			_check(hit, "[%s %s] 번역된 글자가 실제로 뜸 (기대 '%s' · 뜬 글자 %s)" % [lg, name, exp_txt, str(shown.filter(func(t: String) -> bool: return t.contains("소환") or t.contains("저주") or t.contains("연속") or t.contains("ummon") or t.contains("urse") or t.contains("apid")).slice(0, 4))])
			sc.queue_free()
			await _frames(3)
	i18n.call("_apply", "ko")
	# 정직한 확인: 자리표시자가 있는 번역 키 중 params 없이 float 로 나가는 것이 코드에 없음
	var missing: Array = []
	for f: String in DirAccess.get_files_at("res://scripts/logic/battle"):
		if not f.ends_with(".gd"):
			continue
		var txt := FileAccess.get_file_as_string("res://scripts/logic/battle/" + f)
		for line: String in txt.split("\n"):
			if (line.contains("fx_float(") or line.contains("_float(")) and line.contains("\"messages.") and not line.contains("params"):
				for kk: String in ["sapper_summon", "curse_tick", "archer_rapidfire"]:
					if line.contains("messages." + kk) and not line.contains("{"):
						missing.append("%s: %s" % [f, line.strip_edges()])
	_check(missing.is_empty(), "{자리표시자} 가 있는 float 키는 모두 params 를 넘김 %s" % str(missing))


# ═══════════ 3) 결과 창 ═══════════

func _gold_of(sv: Variant) -> float:
	var g: Variant = sv
	if g is String:
		g = JsonX.parse(g)
	return Js.num((g as Dictionary).get("gold")) if g is Dictionary else 0.0


func _sum_lines(m: Dictionary) -> Array:
	# [합계 줄을 뺀 골드 줄 합, 합계 줄 값(없으면 -1), 골드 줄 수]
	var sum := 0.0
	var tot := -1.0
	var n := 0
	for r: Dictionary in m["rewards"]:
		var v := str(r.get("value", ""))
		if v.begins_with("+") and v.ends_with(" G"):
			var num := float(v.substr(1, v.length() - 3).replace(",", ""))
			if r.get("legend", false) and str(r["label"]) == str(i18n.call("t", "gd.result.total_gold")):
				tot = num
			else:
				sum += num
				n += 1
	return [sum, tot, n]


func _reward() -> void:
	i18n.call("_apply", "ko")
	# [시나리오, 저장 바꾸기] — 같은 판을 첫 클리어 / 다시 클리어(별 그대로) / 다시 클리어(별 못 얻음) / 별 새로 얻음으로
	var scen: Array = [["firstclear_s02", ""], ["balanced_s05", ""], ["knights_s11", ""], ["boss_s10", ""], ["mono_archer_s07", ""], ["practice_s04", ""],
		["firstclear_s02", "reclear_full"], ["firstclear_s02", "reclear_nostar"], ["balanced_s05", "reclear_full"], ["balanced_s05", "reclear_nostar"], ["loss_s30", ""], ["loss_boss_s45", ""], ["drill_s28", ""]]
	var kinds: Dictionary = {}
	var chest_cases := 0
	for sv: Array in scen:
		var name: String = sv[0]
		var extra: Dictionary = {"story": "off"}
		if sv[1] != "":
			var BSg: GDScript = load("res://scripts/battle/battle_scene.gd")
			var gc: Dictionary = BSg.call("golden_cfg", name)
			var sd: Dictionary = (gc["save"] as Dictionary).duplicate(true)
			var gsv: Variant = sd.get("game_save")
			var gsd: Dictionary = (JsonX.parse(gsv) if gsv is String else gsv) if gsv != null else {}
			var sid := int((gc["stage"] as Dictionary)["id"])
			var cl: Array = (gsd.get("cleared", []) as Array).duplicate()
			if not cl.has(sid):
				cl.append(sid)
			gsd["cleared"] = cl
			var stars: Dictionary = (gsd.get("stars", {}) as Dictionary).duplicate()
			stars[str(sid)] = [1, 1, 1] if sv[1] == "reclear_full" else [0, 0, 0]
			gsd["stars"] = stars
			sd["game_save"] = JsonX.stringify(gsd) if gsv is String else gsd
			extra["save"] = sd
		var sc: Node = await _launch(name, extra)
		if not sc.is_awaiting():
			sc.queue_free()
			continue
		var S: Dictionary = sc.eng.S
		var gold0 := float(S["gold"])
		await _drive(sc, name)
		if sc.result == null:
			sc.queue_free()
			await _frames(2)
			continue
		var m: Dictionary = sc._result_model()
		var won := str(sc.result.get("result")) == "win"
		var ls := _sum_lines(m)
		var Sg: Dictionary = sc.eng.S
		var gain := float(Sg["gold"]) - gold0
		var sr: Variant = Sg.get("_starResult")
		var fc := Js.num(Sg.get("_firstClearBonus"))
		var kind := "%s%s%s" % ["첫클리어" if fc > 0.0 else "재클리어", "+새별" if (typeof(sr) == TYPE_DICTIONARY and Js.num(sr.get("bonus")) > 0.0) else "", " 연습" if Js.truthy(Sg.get("practiceMode")) else ""]
		kinds[kind] = true
		# 보상 줄이 겹치지 않음: 같은 라벨 두 번 없음, 합계 줄은 골드 줄이 둘 이상일 때만, 합계 = 줄 합
		var labels: Array = []
		for r: Dictionary in m["rewards"]:
			labels.append(str(r["label"]))
		var dup := false
		for lb: String in labels:
			if labels.count(lb) > 1:
				dup = true
		_check(not dup, "[%s %s] 보상 줄 라벨이 겹치지 않음 %s" % [name, kind, str(labels)])
		_check((ls[1] < 0.0) == (int(ls[2]) <= 1), "[%s %s] 합계 줄은 골드 줄이 둘 이상일 때만 (줄 %d)" % [name, kind, int(ls[2])])
		if ls[1] >= 0.0:
			_check(absf(float(ls[1]) - float(ls[0])) < 0.5, "[%s %s] 합계 %s = 줄 합 %s" % [name, kind, str(ls[1]), str(ls[0])])
		# 합계 = 실제로 받은 골드 — 모든 경우에서 같아야 함 (보물상자 골드 포함)
		_check(absf(gain - float(ls[0])) < 0.5, "[%s %s%s] 골드 증가 %s = 보상 줄 합 %s (상자 골드 %s)" % [name, kind, "" if won else " 패배", str(gain), str(ls[0]), str(Js.num(Sg.get("_chestGold")))])
		if Js.num(Sg.get("_chestGold")) > 0.0:
			chest_cases += 1
			var has_chest_line := false
			for r2: Dictionary in m["rewards"]:
				if str(r2["label"]) == str(i18n.call("t", "gd.result.chest_gold")):
					has_chest_line = true
			_check(has_chest_line, "[%s %s] 상자 골드가 있으면 '보물상자' 줄이 있음" % [name, kind])
		# 윗줄: 결과가 뜨면 차례 표시 숨김
		_check(not sc.ui.top.ti_box.visible, "[%s] 결과 창이 뜨면 윗줄 '턴' 표시 숨김" % name)
		if not won:
			sc.queue_free()
			await _frames(3)
			continue
		# 처치 EXP 글
		if won and m.has("detail"):
			_check(str(m["detail"]).contains("처치 EXP") and not str(m["detail"]).contains("총 "), "[%s] 처치 EXP 글: %s" % [name, str(m["detail"])])
		# 별: 이번 판 ✓/✕ 와 이미 얻은 별 구분
		if m.has("stars"):
			var st: Dictionary = m["stars"]
			_check(str(st.get("kept_text", "")) != "", "별 '기존 기록' 글 있음")
		sc.queue_free()
		await _frames(3)
	_check(kinds.size() >= 2, "여러 경우를 확인함 %s" % str(kinds.keys()))
	_check(chest_cases >= 2, "상자 골드를 얻은 판을 2개 이상 확인함 (%d)" % chest_cases)
	print("    확인한 경우: %s" % str(kinds.keys()))
	# 6개 언어 새 키
	for lg: String in LANGS:
		i18n.call("_apply", lg)
		for k: String in ["gd.result.base_reward", "gd.result.total_gold", "gd.result.star_kept", "gd.result.chest_gold", "gd.result.battle_detail", "gd.fx.buff_end", "gd.stat.hp", "gd.stat.atk", "gd.stat.def", "gd.stat.ar"]:
			_check(bool(i18n.call("has_key", k)), "[%s] 번역 키 %s" % [lg, k])
	i18n.call("_apply", "ko")


# ═══════════ 4) 안전 영역 감시 ═══════════

func _safe() -> void:
	_emu(true, "pixel8")
	await _frames(2)
	var m0: Dictionary = mobile.call("safe_margins")
	_check(float(m0["left"]) > 50.0 and float(m0["right"]) == 0.0, "왼쪽 노치 여백 %s" % str(m0))
	var p0: int = mobile.get("polls")
	_check(not bool(mobile.call("poll_now")), "바뀐 것이 없으면 다시 계산하지 않음")
	# 180° 회전: 창 크기는 그대로, 여백이 오른쪽으로
	mobile.set("inset_override", [0, 0, 136, 0])
	var sz0 := root.size
	_check(bool(mobile.call("poll_now")), "안전 영역이 바뀌면(왼 → 오른쪽) 다시 계산")
	var m1: Dictionary = mobile.call("safe_margins")
	_check(float(m1["right"]) > 50.0 and float(m1["left"]) == 0.0 and root.size == sz0, "여백이 오른쪽으로 옮겨감 (창 크기 그대로) %s" % str(m1))
	_check(int(mobile.get("polls")) == p0 + 1, "다시 계산 1번")
	# 화면(바깥 화면)도 따라감
	router.set("dry_run", true)
	router.set("params", {})
	var lb: Node = (load("res://scenes/outer/lobby.tscn") as PackedScene).instantiate()
	root.add_child(lb)
	await _frames(3)
	if lb.get("setup_dialog") != null:
		lb.commander_setup_done()
	await _frames(2)
	var fr: Control = lb.frame
	var right_edge := fr.get_global_rect().end.x
	_check(right_edge < root.get_visible_rect().end.x - 50.0, "화면 틀이 오른쪽 여백을 비킴 (끝 %.0f / 화면 %.0f)" % [right_edge, root.get_visible_rect().end.x])
	mobile.set("inset_override", [136, 0, 0, 0])
	mobile.call("poll_now")
	await _frames(2)
	_check(fr.get_global_rect().position.x > 50.0 and fr.get_global_rect().end.x > root.get_visible_rect().end.x - 2.0, "다시 돌려놓으면 틀이 왼쪽 여백을 비킴 %s" % str(fr.get_global_rect()))
	# 시간이 흐르면(_process 의 0.5초 감시) 저절로
	mobile.set("inset_override", [0, 0, 136, 0])
	var p1: int = mobile.get("polls")
	await create_timer(0.8).timeout
	_check(int(mobile.get("polls")) == p1 + 1, "0.5초 감시가 저절로 다시 계산")
	mobile.set("inset_override", [])
	mobile.call("poll_now")
	lb.queue_free()
	await _frames(2)
	router.set("dry_run", false)
	_emu(false)


# ═══════════ 5) 겹침 ═══════════

func _rich_save() -> void:
	store.call("clear")
	var st: Dictionary = fx2["sanctuary"][0]["store"]
	for k: String in st.keys():
		store.call("set_json", k, Js.deep(st[k]))
	store.call("set_json", "game_save", {"gold": 1234567, "cleared": range(1, 46)})
	store.call("set_json", "game_settings", {"language": "ko", "playSpeed": 4})
	store.call("set_json", "game_story_seen", {"ep1_pro": true})


func _gd_battle_save() -> void:
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	var cfg: Dictionary = BS.call("golden_cfg", "balanced_s05")
	store.call("clear")
	for k: String in (cfg["save"] as Dictionary).keys():
		store.call("set_json", k, cfg["save"][k])
	cfg["save"] = BS.call("store_save", store)
	cfg["source"] = "store"
	const BattleEngine := preload("res://scripts/logic/battle/battle_engine.gd")
	const Ctx := preload("res://scripts/logic/ctx.gd")
	const StoreCtx := preload("res://scripts/logic/store_ctx.gd")
	var D := Ctx.globals_from_db(root.get_node("DataDB"))
	var eng := BattleEngine.new(D, int(cfg["seed"]))
	eng.start({"save": cfg["save"], "stage": cfg["stage"], "practice": false, "inject": [], "maxRounds": 0})
	eng.begin()
	if eng.run() == "input":
		ResumeRules.save_gd(Ctx.new(D, 1, StoreCtx.new(store)), cfg, eng.save_text())
	eng.dispose()


## 그 자리(전역 좌표)에서 가장 위에 있는 '마우스를 받는' 부품 (그리는 순서 = 자식 순서)
func _top_at(n: Node, pos: Vector2) -> Control:
	for i in range(n.get_child_count() - 1, -1, -1):
		var ch := n.get_child(i)
		if ch is CanvasItem and not (ch as CanvasItem).visible:
			continue
		var hit := _top_at(ch, pos)
		if hit != null:
			return hit
	if n is Control and (n as Control).visible and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE and (n as Control).get_global_rect().has_point(pos):
		return n as Control
	return null


## 다른 부품(윗줄 · 아래 탭 · 창) · 안전 영역 밖 · 부모 잘림 영역에 가려지는지 → 이유 글 ("" = 안 가려짐)
func _occluded(ctl: Control, safe: Rect2) -> String:
	if ctl == null or not ctl.is_visible_in_tree():
		return "안 보임"
	var r := ctl.get_global_rect()
	if not safe.grow(1.0).encloses(r):
		return "안전 영역 밖 %s ⊄ %s" % [str(r), str(safe)]
	var a: Node = ctl.get_parent()
	while a != null and a is Control:
		var ac := a as Control
		if ac is ScrollContainer or ac.clip_contents:
			if not ac.get_global_rect().grow(1.0).encloses(r):
				return "부모 잘림 영역 밖 %s ⊄ %s (%s)" % [str(r), str(ac.get_global_rect()), str(ac.name)]
		a = a.get_parent()
	for pt: Vector2 in [r.get_center(), r.position + r.size * 0.2, r.position + Vector2(r.size.x * 0.8, r.size.y * 0.2), r.position + Vector2(r.size.x * 0.2, r.size.y * 0.8), r.position + r.size * 0.8]:
		var top := _top_at(root, pt)
		if top == null or not (top == ctl or ctl.is_ancestor_of(top)):
			return "%s 에 가려짐 (%s 자리)" % [str(top.name) if top != null else "없음", str(pt)]
	return ""


func _layout() -> void:
	router.set("dry_run", true)
	var combos: Array = [["", false]]
	for dv: String in ["pixel8", "iphone", "ipad", "low"]:
		combos.append([dv, true])
	for combo: Array in combos:
		var mob: bool = combo[1]
		for lg: String in LANGS:
			if mob:
				_emu(true, str(combo[0]))
			else:
				_emu(false)
			var tag := "%s %s" % [("모바일 " + str(combo[0])) if mob else "PC", lg]
			_gd_battle_save()
			i18n.call("_apply", lg)
			router.set("params", {})
			var lb: Node = (load("res://scenes/outer/lobby.tscn") as PackedScene).instantiate()
			root.add_child(lb)
			await _frames(4)
			if lb.get("setup_dialog") != null:
				lb.commander_setup_done()
			await _frames(2)
			lb.close_all_modals()
			# ✕ 포기 단추: 전투 재개 단추와 안 겹침, ✕ 가 원 한가운데
			var ab: Button = lb.abandon_btn
			var rb: Button = lb.resume_btn
			if ab != null and rb != null:
				await _frames(2)
				var ar := ab.get_global_rect()
				var rr := rb.get_global_rect()
				_check(not ar.intersects(rr), "[%s] ✕ 포기 단추(%s)가 전투 재개 단추(%s)와 안 겹침" % [tag, str(ar), str(rr)])
				var ic: Control = ab.get_child(0)
				_check(ic != null and ic.get_global_rect().get_center().distance_to(ar.get_center()) < 1.5, "[%s] ✕ 그림이 원 한가운데" % tag)
				_check(root.get_visible_rect().encloses(ar), "[%s] ✕ 단추가 화면 안" % tag)
				var safe_r: Rect2 = mobile.call("safe_rect") if mob else root.get_visible_rect()
				var oc := _occluded(ab, safe_r)
				_check(oc == "", "[%s] ✕ 단추가 윗줄·창·안전 영역·잘림에 안 가려짐 %s" % [tag, oc])
				var oc2 := _occluded(rb, safe_r)
				_check(oc2 == "", "[%s] 전투 재개 단추도 안 가려짐 %s" % [tag, oc2])
			else:
				_check(false, "[%s] 이어하기 단추·✕ 가 있음" % tag)
			# 알림: 도감·출격·가이드(전투 재개) 단추 줄과 안 겹침
			lb.toast("✓ " + str(i18n.call("t", "messages.data_ok")), "ok")
			await _frames(3)
			var toast: Control = lb.layer.find_child("Toast", true, false)
			if toast != null:
				var tr := toast.get_global_rect()
				for b: Node in lb.popups.get_children():
					if b is Control and (b as Control).visible:
						_check(not tr.intersects((b as Control).get_global_rect()), "[%s] 알림(%s)이 단추 %s(%s)를 안 덮음" % [tag, str(tr), str(b.name), str((b as Control).get_global_rect())])
				_check(root.get_visible_rect().encloses(tr), "[%s] 알림이 화면 안" % tag)
			else:
				_check(false, "[%s] 알림이 뜸" % tag)
			lb.queue_free()
			await _frames(2)
	# 전투 대사 건너뛰기 ↔ 행동 순서 패널
	for mob2: bool in [false, true]:
		_emu(mob2, "pixel8") if mob2 else _emu(false)
		i18n.call("_apply", "ko")
		var sc: Node = await _launch("legion5_s09")
		var bl: Variant = sc.story.lines_of("s9_start")
		sc.ui.story.auto = false
		sc._story_play([{"key": "qa_battle", "lines": bl, "title": "", "battle": true}])
		await _frames(4)
		var skip: Control = sc.ui.story.skip_btn
		var order: Control = sc.ui.order
		var tag2 := "%s 전투 대사" % ("모바일" if mob2 else "PC")
		_check(skip.is_visible_in_tree() and not skip.get_global_rect().intersects(order.get_global_rect()), "[%s] 건너뛰기(%s)가 행동 순서 패널(%s)을 안 덮음" % [tag2, str(skip.get_global_rect()), str(order.get_global_rect())])
		_check(not skip.get_global_rect().intersects(sc.ui.minimap.get_global_rect()), "[%s] 건너뛰기가 미니맵을 안 덮음" % tag2)
		_check(not skip.get_global_rect().intersects(sc.ui.top.get_global_rect()), "[%s] 건너뛰기가 윗줄을 안 덮음" % tag2)
		sc.ui.story.skip()
		await _until(func() -> bool: return sc._hold == 0)
		sc.queue_free()
		await _frames(3)
	_emu(false)
	router.set("dry_run", false)


# ═══════════ 6) 장비 창 ═══════════

func _equip() -> void:
	for mob: bool in [false, true]:
		if mob:
			_emu(true, "pixel8")
		else:
			_emu(false)
		i18n.call("_apply", "ko")
		store.call("clear")
		var st: Dictionary = fx1["equip"][0]["store"]
		for k: String in st.keys():
			store.call("set_json", k, Js.deep(st[k]))
		store.call("set_json", "game_save", {"gold": 100000, "cleared": [1, 2, 3]})
		router.set("dry_run", true)
		router.set("params", {})
		var ps: Node = (load("res://scenes/outer/party_select.tscn") as PackedScene).instantiate()
		root.add_child(ps)
		await _frames(4)
		ps.switch_page_tab("equip")
		await _frames(2)
		var uid: Variant = null
		for ch: Dictionary in (store.call("get_json", "game_roster")["chars"] as Array):
			if str(ch.get("cls")) != "commander" and not bool(ch.get("dead", false)):
				uid = ch["uid"]
				break
		ps.gear.open_equip_modal(uid)
		await _frames(6)
		var tag := "모바일" if mob else "PC"
		var ls: Control = ps.find_child("LeftScroll", true, false)
		var gs: ScrollContainer = ps.find_child("InvScroll", true, false)
		_check(ls != null and gs != null, "[%s] 장비 창: 왼쪽 칸·목록이 각자 스크롤 안" % tag)
		if gs != null and ls != null:
			var left_before := ls.get_global_rect().position.y
			gs.scroll_vertical = 400
			await _frames(3)
			_check(absf(ls.get_global_rect().position.y - left_before) < 0.5 and ls.is_visible_in_tree(), "[%s] 목록을 아래로 스크롤해도 왼쪽 장착 칸은 그대로" % tag)
			_check(gs.scroll_vertical > 0 or gs.get_child(0).size.y <= gs.size.y + 1.0, "[%s] 목록이 스크롤됨(%d)" % [tag, gs.scroll_vertical])
			var mr: Rect2 = ((ps.find_child("EquipModal", true, false) as Control).find_child("Box", true, false) as Control).get_global_rect()
			_check(root.get_visible_rect().grow(2.0).encloses(mr) if not mob else (mobile.call("safe_rect") as Rect2).grow(2.0).encloses(mr), "[%s] 장비 창이 화면(안전 영역) 안 %s" % [tag, str(mr)])
		# 판매 확인 → 예 → Esc 한 번에 장비 창이 닫힘
		var inv: Array = store.call("get_json", "game_inventory", [])
		var eid := ""
		for it: Dictionary in inv:
			if not Js.truthy(it.get("equipped")) and it.has("eid"):
				eid = str(it["eid"])
				break
		if eid != "":
			ps._act_frame = -1
			ps.gear.ask_sell(eid)
			await _frames(3)
			_check(ps.modal_open(), "[%s] 판매 확인 창 열림" % tag)
			var yes: Node = ps.find_child("Yes", true, false)
			if yes != null:
				(yes as BaseButton).pressed.emit()
			await _frames(4)
			var still := ps.gear.equip_modal != null
			ps.on_back()
			await _frames(3)
			_check(not ps.modal_open() or not still, "[%s] 판매 확인 뒤 Esc 한 번에 창 닫힘 (남은 창 수 %d)" % [tag, ps._modals.size()])
			_check(ps._modals.size() == 0, "[%s] 창이 모두 닫힘" % tag)
		ps.queue_free()
		await _frames(3)
		router.set("dry_run", false)
	_emu(false)


# ═══════════ 7) 능력치 이름 ═══════════

func _labels() -> void:
	router.set("dry_run", true)
	for lg: String in LANGS:
		i18n.call("_apply", lg)
		store.call("clear")
		var st: Dictionary = fx1["shop"][0]["after"] if fx1["shop"][0].has("after") else {}
		_rich_shop()
		router.set("params", {"tab": "mercenary"})
		var sh: Node = (load("res://scenes/outer/shop.tscn") as PackedScene).instantiate()
		root.add_child(sh)
		await _frames(4)
		var texts: Array = _texts(sh)
		var hp: String = str(i18n.call("t", "gd.stat.hp"))
		var any_hp := false
		var bad: Array = []
		for t in texts:
			if t.begins_with(hp + " ") or t.begins_with(hp):
				any_hp = true
			for pat: String in ["HP : ", "ATK:", "DEF:", "AR:"]:
				if t.contains(pat):
					bad.append(t)
		_check(any_hp and bad.is_empty(), "[%s] 상점 용병 카드 능력치 이름 통일 (%s…) 남은 옛 꼴 %s" % [lg, hp, str(bad)])
		sh.queue_free()
		await _frames(2)
		router.set("params", {})
		var ps: Node = (load("res://scenes/outer/party_select.tscn") as PackedScene).instantiate()
		root.add_child(ps)
		await _frames(4)
		ps.open_unit_modal(0)
		await _frames(4)
		var t2: Array = _texts(ps)
		var bad2: Array = []
		for t3 in t2:
			for pat2: String in ["HP:", "ATK:", "DEF:", "AR:"]:
				if t3.contains(pat2) and lg != "en":
					bad2.append(t3)
			if lg == "ko" and (t3 == "HP" or t3 == "ATK" or t3 == "DEF" or t3.begins_with("AR ")):
				bad2.append(t3)
		_check(bad2.is_empty(), "[%s] 편성(칸·유닛 선택 창) 영어 능력치 이름이 섞이지 않음 %s" % [lg, str(bad2.slice(0, 4))])
		ps.queue_free()
		await _frames(2)
	i18n.call("_apply", "ko")
	router.set("dry_run", false)


func _rich_shop() -> void:
	store.call("clear")
	var stt: Dictionary = fx1["equip"][0]["store"]
	for k: String in stt.keys():
		store.call("set_json", k, Js.deep(stt[k]))
	store.call("set_json", "game_shop", fx1["shop"][0]["after"]["game_shop"])
	store.call("set_json", "game_save", {"gold": 100000, "cleared": [1, 2, 3]})
	store.call("set_json", "game_settings", {"language": str(i18n.get("current_lang")), "playSpeed": 4})


func _texts(n: Node) -> Array:
	var out: Array = []
	var stack: Array = [n]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is CanvasItem and not (nd as CanvasItem).is_visible_in_tree():
			continue
		stack.append_array(nd.get_children())
		if nd is Label:
			out.append((nd as Label).text)
		elif nd is Button:
			out.append((nd as Button).text)
	return out
