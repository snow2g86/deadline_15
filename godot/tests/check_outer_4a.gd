extends SceneTree
## 4a 시험 — 바깥 화면(로비 · 스테이지 선택 · 편성 · 설정 · 스토리)과 흐름
##   Godot --headless --path godot --script res://tests/check_outer_4a.gd   [-- --only rules,flow,lang,sizes,party,lobby,settings]
##  1) rules   : 해금·별·요일 던전·출격 판단·파티 저장·저장값 점검을 웹 코드의 정답(tests/fixtures/outer_4a_web.json — node tools/outer-4a-expect.js)과 비교
##  2) party   : 편성 저장·불러오기 (칸 배치·옮기기·빼기·활성 파티·죽은 클랜원·지휘관 빼기·필터·정렬)
##  3) lobby   : 첫 실행 클랜원·지휘관 설정·자동 부활·성별 보정·아지트
##  4) settings: 설정 저장 키 (바깥 설정 = 전투 설정 창), 언어는 고를 때만 저장
##  5) flow    : 진짜 장면 전환 — 시작 → 지휘관 설정 → 로비 → 스테이지(에피소드·스테이지) → 출전 전 스토리 → 전투 → 결과 → 로비,
##               5명 미만 → 편성 → 출격, 다음 스테이지, 요일 던전 → 돌아오기, Esc·마우스 뒤로 단추, 아래 탭, 준비 중
##  6) lang    : 6개 언어 × 모든 화면·창 — 글자가 부모 밖으로 넘치지 않음 · 두부(글꼴에 없는 글자) 0
##  8) weird   : 이상한 값이 든 세이브 (손으로 만든 경우 + 무작위 퍼징) → 모든 화면 진입·창 열기에서 스크립트 오류 0, 지휘관은 파티에 없음
##  7) sizes   : 창 크기 1280×720 · 1920×1080 · 1024×600 · 800×1000(좁은 창) · 480×900(휴대폰 폭) — 주요 단추가 화면 안 · 넘침 0
##  Godot 오류(Logger 로 셈) 0 이어야 통과. 저장은 user://test_outer_4a_save.json (진짜 세이브는 건드리지 않음)

const JsonX := preload("res://scripts/core/json_exact.gd")
const JsonNorm := preload("res://scripts/core/json_norm.gd")
const FontsT := preload("res://scripts/core/fonts.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")
const SaveStore := preload("res://scripts/logic/save_store.gd")
const Js := preload("res://scripts/logic/js.gd")
const ProgressRules := preload("res://scripts/logic/progress_rules.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")
const LobbyRules := preload("res://scripts/logic/lobby_rules.gd")
const SettingsRules := preload("res://scripts/logic/settings_rules.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const Gear := preload("res://scripts/logic/gear.gd")
const HudSettings := preload("res://scripts/battle/hud_settings.gd")
const SAVE := "user://test_outer_4a_save.json"
const SCREENS := {"lobby": "res://scenes/outer/lobby.tscn", "stage_select": "res://scenes/outer/stage_select.tscn",
	"party_select": "res://scenes/outer/party_select.tscn", "settings": "res://scenes/outer/settings.tscn"}
const LANGS := ["ko", "en", "es", "ja", "zh-CN", "zh-TW"]

var _fails: Array = []
var _passes := 0
var _counter: ErrCounter
var store: Node
var i18n: Node
var router: Node
var D: Dictionary
var _only: Array = []
var _stats: Dictionary = {}   # 항목 → 수


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


func _want(name: String) -> bool:
	return _only.is_empty() or _only.has(name)


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var oi := args.find("--only")
	if oi >= 0 and oi + 1 < args.size():
		_only = Array(args[oi + 1].split(","))
	store = root.get_node("Store")
	i18n = root.get_node("I18n")
	router = root.get_node("Router")
	var db: Node = root.get_node("DataDB")
	D = Ctx.globals_from_db(db)
	store.call("use_path", SAVE)
	store.call("clear")
	i18n.call("reload")
	root.size = Vector2i(1280, 720)
	if _want("rules"):
		print("── 1) 규칙 ↔ 웹 정답 ──")
		_rules_vs_web()
	if _want("party"):
		print("── 2) 편성 저장·불러오기 ──")
		_party_rules()
	if _want("lobby"):
		print("── 3) 로비 규칙 ──")
		_lobby_rules()
	if _want("settings"):
		print("── 4) 설정 저장 키 ──")
		await _settings()
	if _want("flow"):
		print("── 5) 화면 흐름 (진짜 장면 전환) ──")
		await _flow()
	if _want("lang"):
		print("── 6) 6개 언어 넘침·두부 ──")
		await _langs()
	if _want("sizes"):
		print("── 7) 창 크기 ──")
		await _sizes()
	if _want("weird"):
		print("── 8) 이상한 값이 든 세이브 (손으로 만든 것 + 무작위) ──")
		await _weird()
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	for e: String in _counter.errors:
		print("  ERR " + e)
	_check(_counter.errors.is_empty(), "Godot 오류 0 (%d)" % _counter.errors.size())
	print("  수치: %s" % JsonX.stringify(_stats))
	if _fails.is_empty():
		print("RESULT: PASS (%d개 통과)" % _passes)
		quit(0)
	else:
		print("RESULT: FAIL (%d개 실패, %d개 통과)" % [_fails.size(), _passes])
		for f: String in _fails:
			print("  - " + f)
		quit(1)


# ═══════════ 공용 ═══════════

func _mem_ctx(seed_store: Dictionary) -> Object:
	var ss := SaveStore.new()
	for k: String in seed_store.keys():
		ss.set_json(k, JsonNorm.normalize_store(k, Js.deep(seed_store[k])))
	return Ctx.new(D, 4242, ss)


## 깊은 비교 (숫자는 int·float 상관없이 값, 사전은 키 집합까지)
func _same(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return float(a) == float(b)
	if ta != tb:
		return false
	if ta == TYPE_DICTIONARY:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k: Variant in (a as Dictionary).keys():
			if not (b as Dictionary).has(k) or not _same(a[k], b[k]):
				return false
		return true
	if ta == TYPE_ARRAY:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _same(a[i], b[i]):
				return false
		return true
	return a == b


func _dump(c: Object) -> Dictionary:
	var o: Dictionary = {}
	for k: String in c.store.keys():
		o[k] = c.store.get_json(k)
	return o


func _stat(k: String, n: int = 1) -> void:
	_stats[k] = int(_stats.get(k, 0)) + n


# ═══════════ 1) 규칙 ↔ 웹 정답 ═══════════

func _rules_vs_web() -> void:
	var fx: Variant = JsonX.parse(FileAccess.get_file_as_string("res://tests/fixtures/outer_4a_web.json"))
	_check(typeof(fx) == TYPE_DICTIONARY, "웹 정답 파일 읽음")
	if typeof(fx) != TYPE_DICTIONARY:
		return
	# 진행·해금 (에피소드 카드 · 스테이지 카드)
	var bad := 0
	var n := 0
	for P: Dictionary in fx["progress"]:
		var c := _mem_ctx(P["store"])
		var tp := ProgressRules.total_progress(c)
		var sub := "stage.total_progress" + JsonX.stringify({"n": tp["n"], "total": tp["total"]})
		n += 1
		if sub != str(P["subtitle"]):
			bad += 1
			print("    [%s] 진행도 %s ≠ %s" % [P["name"], sub, P["subtitle"]])
		var eps := ProgressRules.episodes(c)
		var web_eps: Array = P["episodes"]
		n += 1
		if eps.size() != web_eps.size():
			bad += 1
			continue
		for i in eps.size():
			var e: Dictionary = eps[i]
			var w: Dictionary = web_eps[i]
			var cls := str(w["cls"])
			var mine := "episode-card" + ("" if e["unlocked"] else " locked") + (" done" if e["done"] else (" current" if e["unlocked"] else ""))
			var prog := [e["stars"], e["max_stars"], e["clear_count"], e["count"]]
			n += 1
			if mine != cls or bool(w["onclick"]) != bool(e["unlocked"]) or not _same(prog, w["prog"]):
				bad += 1
				print("    [%s] EP.%d %s %s ≠ 웹 %s %s" % [P["name"], e["id"], mine, str(prog), cls, str(w["prog"])])
		for ep_id: String in (P["stages"] as Dictionary).keys():
			var sts := ProgressRules.stages_of(c, int(ep_id))
			var ws: Array = P["stages"][ep_id]
			n += 1
			if sts.size() != ws.size():
				bad += 1
				print("    [%s] EP.%s 스테이지 수 %d ≠ %d" % [P["name"], ep_id, sts.size(), ws.size()])
				continue
			for j in sts.size():
				var sv: Dictionary = sts[j]
				var wv: Dictionary = ws[j]
				var mine2 := "stage-btn" + (" cleared" if sv["cleared"] else "") + ("" if sv["unlocked"] else " locked") + (" next" if sv["next"] else "") + (" boss" if sv["boss"] else "")
				var stars: Array = []
				if sv["cleared"]:
					for f: Variant in sv["flags"]:
						stars.append(1 if Js.truthy(f) else 0)
				n += 1
				if mine2 != str(wv["cls"]) or bool(wv["onclick"]) != bool(sv["unlocked"]) or not _same(stars, wv["stars"]):
					bad += 1
					print("    [%s] 스테이지 %d %s %s ≠ 웹 %s %s" % [P["name"], sv["id"], mine2, str(stars), wv["cls"], str(wv["stars"])])
	_check(bad == 0, "에피소드·스테이지 해금·별·진행도 = 웹 (%d개 비교, 다름 %d)" % [n, bad])
	_stat("rules.progress", n)
	# 요일 던전
	bad = 0
	n = 0
	for Dc: Dictionary in fx["daily"]:
		var c2 := _mem_ctx(Dc["store"])
		var dt: Array = Dc["date"]
		var date := {"year": int(dt[0]), "month": int(dt[1]), "day": int(dt[2]), "weekday": int(Dc["weekday"])}
		var opens: Array = []
		for i in (D["DAILY"]["tiers"] as Array).size():
			opens.append(ProgressRules.daily_tier_open(c2, i))
		var ok := ProgressRules.daily_left(c2, date) == int(Dc["left"]) and _same(ProgressRules.daily_classes(c2, int(Dc["weekday"])), Dc["classes"]) \
			and _same(opens, Dc["tierOpen"]) and ProgressRules.best_cleared(c2) == float(Dc["best"])
		ProgressRules.daily_consume(c2, date)
		ok = ok and _same(c2.store.get_json("game_daily"), Dc["afterConsume"]) and ProgressRules.daily_left(c2, date) == int(Dc["leftAfter"])
		n += 1
		if not ok:
			bad += 1
			print("    요일 던전 %s 다름" % str(Dc["date"]))
	_check(bad == 0, "요일 던전 입장·직업·난이도 해금 = 웹 (%d경우, 다름 %d)" % [n, bad])
	_stat("rules.daily", n)
	# 다음 스테이지 (battle/end.js goNextStage — 웹도 출격 단추 켜도록 고침)
	bad = 0
	for Nx: Dictionary in fx["next"]:
		var cn := _mem_ctx(Nx["store"])
		var rn := PartyRules.next_stage(cn, Js.deep(ProgressRules.find_stage(cn, int(Nx["stage"]))))
		var navn: Dictionary = cn.store.get_json("game_nav")
		var ton := "battle.html" if rn["to"] == "battle" else "party-select.html"
		var csn: Variant = cn.store.get_str("ps_can_start")
		if not (ton == str(Nx["to"]) and _same(navn.get("party"), Nx["party"]) and _same(navn.get("practiceMode"), Nx["practiceMode"]) and int(navn["cStage"]["id"]) == int(Nx["navStageId"]) and _same(csn, Nx["canStart"])):
			bad += 1
			print("    다음 스테이지 [%s] %s %s %s ≠ 웹 %s %s %s" % [Nx["name"], ton, str(navn.get("party")), str(csn), Nx["to"], str(Nx["party"]), str(Nx["canStart"])])
	_check(bad == 0, "다음 스테이지(5명 미만이면 편성 + 출격 단추 켬) = 웹 (%d경우, 다름 %d)" % [(fx["next"] as Array).size(), bad])
	# 출격 판단
	bad = 0
	for L: Dictionary in fx["launch"]:
		var c3 := _mem_ctx(L["store"])
		var st: Dictionary = Js.deep(ProgressRules.find_stage(c3, int(L["stage"])))
		var res := PartyRules.launch_stage(c3, st, bool(L["practice"]))
		var nav: Dictionary = c3.store.get_json("game_nav")
		var to := "battle.html" if res["to"] == "battle" else "party-select.html"
		var cs: Variant = c3.store.get_str("ps_can_start")
		var ok2: bool = to == str(L["to"]) and _same(nav.get("party"), L["party"]) and _same(nav.get("practiceMode"), L["practiceMode"]) \
			and int(nav["cStage"]["id"]) == int(L["navStageId"]) and _same(cs, L["canStart"]) and _same(c3.store.get_json("game_parties"), L["parties"])
		if not ok2:
			bad += 1
			print("    출격 [%s] %s %s %s %s ≠ 웹 %s %s %s" % [L["name"], to, str(nav.get("party")), str(cs), JsonX.stringify(c3.store.get_json("game_parties")), L["to"], str(L["party"]), str(L["canStart"])])
	_check(bad == 0, "출격 판단(5명이면 전투·아니면 편성) = 웹 (%d경우, 다름 %d)" % [(fx["launch"] as Array).size(), bad])
	_stat("rules.launch", (fx["launch"] as Array).size())
	# 파티 불러오기 (마이그레이션)
	bad = 0
	for Pc: Dictionary in fx["parties"]:
		var c4 := _mem_ctx(Pc["store"])
		var loaded := PartyRules.load_parties(c4)
		var active := PartyRules.get_active_party(c4)
		if not (_same(loaded, Pc["loaded"]) and _same(active, Pc["active"]) and _same(_dump(c4), Pc["after"])):
			bad += 1
			print("    파티 [%s] %s / %s ≠ 웹 %s / %s" % [Pc["name"], JsonX.stringify(loaded), JsonX.stringify(_dump(c4)), JsonX.stringify(Pc["loaded"]), JsonX.stringify(Pc["after"])])
	_check(bad == 0, "파티 불러오기·마이그레이션·지휘관 빼기 = 웹 (%d경우, 다름 %d)" % [(fx["parties"] as Array).size(), bad])
	_stat("rules.parties", (fx["parties"] as Array).size())
	# 저장값 점검·복구
	bad = 0
	for V: Dictionary in fx["validate"]:
		var c5 := _mem_ctx(V["store"])
		var r := LobbyRules.validate_and_repair(c5, 300)
		var after := _dump(c5)
		if not (bool(r["ok"]) == bool(V["ok"]) and _same(after, V["after"])):
			bad += 1
			print("    점검 [%s] ok %s ≠ %s\n      godot %s\n      웹    %s" % [V["name"], r["ok"], V["ok"], JsonX.stringify(after), JsonX.stringify(V["after"])])
	_check(bad == 0, "저장값 점검·복구 = 웹 (%d경우, 다름 %d)" % [(fx["validate"] as Array).size(), bad])
	_stat("rules.validate", (fx["validate"] as Array).size())


# ═══════════ 2) 편성 저장·불러오기 ═══════════

func _roster(n: int) -> Dictionary:
	var chars: Array = [{"uid": 100, "cls": "commander", "nameId": null, "customName": "X", "lv": 1, "exp": 0, "dead": false, "hp": 95, "atk": 12, "def": 6, "move": 2, "range": 2,
		"pot": {"hp": 8.4, "atk": 1.6, "def": 0.6, "actionRec": 0.12}, "actionRec": 1.22, "gender": "m", "buffer": 2}]
	var classes := ["novice", "warrior", "archer", "priest", "knight", "mage", "novice", "assassin"]
	for i in range(1, n + 1):
		var cls: String = classes[(i - 1) % classes.size()]
		var b: Dictionary = D["JAB"][cls]["base"]
		chars.append({"uid": i, "cls": cls, "nameId": i, "lv": (i * 3) % 7 + 1, "exp": 0, "dead": false, "hp": b["hp"], "atk": b["atk"], "def": b["def"], "move": b["move"], "range": b["range"],
			"pot": {"hp": 8, "atk": 2, "def": 1, "actionRec": 0.1}, "actionRec": 1.1, "gender": "f" if i % 2 == 0 else "m"})
	return {"chars": chars, "nextId": 101}


func _party_rules() -> void:
	var c := _mem_ctx({"game_roster": _roster(8)})
	var data := PartyRules.load_parties(c)
	_check((data["parties"] as Array).size() == 5 and int(data["activePartyId"]) == 1 and int(data["nextPartyId"]) == 6, "새 세이브: 파티 5개 · 활성 1 · nextPartyId 6")
	PartyRules.select_unit_for_slot(c, data, 1, 0, 3)
	PartyRules.select_unit_for_slot(c, data, 1, 1, 5)
	PartyRules.select_unit_for_slot(c, data, 1, 2, 3)   # 이미 0 칸에 있음 → 옮김
	var p1: Dictionary = PartyRules.find_party(c.store.get_json("game_parties"), 1)
	_check(_same(p1["slots"], [null, 5, 3, null, null]), "배치·옮기기 저장 %s" % JsonX.stringify(p1["slots"]))
	PartyRules.remove_from_slot(c, data, 1, 1)
	p1 = PartyRules.find_party(c.store.get_json("game_parties"), 1)
	_check(_same(p1["slots"], [null, null, 3, null, null]), "빼기 저장")
	PartyRules.select_unit_for_slot(c, data, 1, 0, 100)   # 지휘관은 저장 때 빠짐
	_check(Js.index_of(PartyRules.find_party(c.store.get_json("game_parties"), 1)["slots"], 100) == -1, "지휘관은 파티에 저장되지 않음")
	PartyRules.set_active(c, data, 3)
	for u: int in [1, 2, 4, 6, 7]:
		PartyRules.select_unit_for_slot(c, data, 3, [1, 2, 4, 6, 7].find(u), u)
	_check(int(c.store.get_json("game_parties")["activePartyId"]) == 3 and _same(PartyRules.get_active_party(c), [1, 2, 4, 6, 7]), "활성 파티 3 저장 · 활성 파티 uid")
	# 다시 불러오기 (새 ctx — 저장 값에서)
	var c2 := _mem_ctx({"game_roster": _roster(8), "game_parties": c.store.get_json("game_parties")})
	var data2 := PartyRules.load_parties(c2)
	_check(_same(data2, c.store.get_json("game_parties")), "저장한 파티를 그대로 다시 불러옴")
	# 죽은 클랜원 빼기
	var r := _roster(8)
	r["chars"][2]["dead"] = true   # uid 2
	var c3 := _mem_ctx({"game_roster": r, "game_parties": c.store.get_json("game_parties")})
	var d3 := PartyRules.load_parties(c3)
	PartyRules.drop_dead(c3, d3)
	_check(_same(PartyRules.find_party(c3.store.get_json("game_parties"), 3)["slots"], [1, null, 4, 6, 7]), "편성 화면 들어올 때 죽은 클랜원 칸 비움")
	_check(PartyRules.launch_stage(c3, ProgressRules.find_stage(c3, 1), false)["to"] == "party" and PartyRules.can_start_flag(c3), "4명 → 편성 화면 + 출격 단추 켬")
	# 유닛 목록: 필터·정렬 (이 파티 먼저 → 레벨 높은 순)
	var lst := PartyRules.unit_list(c, data, 3, "all")
	var first5: Array = []
	for i in 5:
		first5.append(int(lst[i]["uid"]))
	first5.sort()
	_check(first5 == [1, 2, 4, 6, 7] and lst.size() == 8, "유닛 목록: 파티원 먼저, 지휘관 제외 (%d명)" % lst.size())
	var ok_sort := true
	for i in range(1, 5):
		if float(lst[i]["lv"]) > float(lst[i - 1]["lv"]):
			ok_sort = false
	_check(ok_sort, "파티원끼리 레벨 높은 순")
	var melee := PartyRules.unit_list(c, data, 3, "group_melee")
	var all_melee := true
	for ch: Dictionary in melee:
		if D["CLASS_GROUP_MAP"][ch["cls"]] != "melee":
			all_melee = false
	_check(all_melee and not melee.is_empty(), "직업군 필터 (근접 %d명)" % melee.size())
	_check(PartyRules.groups_present(c) == ["beginner", "melee", "ranged", "support"], "필터 탭 = 가진 직업군 (고정 순서) %s" % str(PartyRules.groups_present(c)))
	# stage_spec (요일 던전 · 일반)
	_check(_same(PartyRules.stage_spec(c, ProgressRules.daily_stage(c, "mage", 2)), {"daily": {"cls": "mage", "tier": 2}}) and _same(PartyRules.stage_spec(c, {"id": 7}), {"id": 7}), "전투 스테이지 지정 (일반·요일 던전)")
	# profile.gd 형 검사 (다듬기 전 원본 그대로): pot [] · 숫자, cls 숫자 → 오류 없이 지휘관 찾고 파티에서 뺌
	var rw := _roster(5)
	rw["chars"][1]["pot"] = []
	rw["chars"][2]["pot"] = 7
	rw["chars"][3]["cls"] = 5
	var e0 := _counter.errors.size()
	var cw := _mem_ctx({"game_roster": rw, "game_parties": {"parties": [{"id": 1, "slots": [100, 1, 2, 3, 4]}], "activePartyId": 1, "nextPartyId": 2}})
	var dw := PartyRules.load_parties(cw)
	_check(_counter.errors.size() == e0 and Js.index_of(dw["parties"][0]["slots"], 100) == -1 and Profile.pot_grade(cw, rw["chars"][3]) == "C", "pot []·숫자 · cls 숫자: 오류 0 · 지휘관 파티 밖 %s" % JsonX.stringify(dw["parties"][0]["slots"]))
	# 다음 스테이지 막다른 길: 4명이면 편성 + 출격 단추 켬 → 다시 5명으로 채우면 출격
	var rn := _roster(6)
	rn["chars"][2]["dead"] = true
	var cn := _mem_ctx({"game_roster": rn, "game_parties": PartyRules.create_default_parties([1, 2, 3, 4, 5]), "ps_can_start": "false"})
	var res := PartyRules.next_stage(cn, ProgressRules.find_stage(cn, 5))
	var dn := PartyRules.load_parties(cn)
	PartyRules.drop_dead(cn, dn)
	PartyRules.select_unit_for_slot(cn, dn, 1, 1, 6)
	_check(res["to"] == "party" and PartyRules.can_start_flag(cn) and PartyRules.confirm_start(cn, ProgressRules.find_stage(cn, 5), false) != null, "다음 스테이지 4명 → 편성(출격 단추 켬) → 6번 넣고 출격 가능")
	_stat("party.checks", 14)


# ═══════════ 3) 로비 규칙 ═══════════

func _lobby_rules() -> void:
	var c := _mem_ctx({})
	_check(LobbyRules.ensure_roster(c, 300), "첫 실행: 클랜원 만듦")
	var r: Dictionary = c.store.get_json("game_roster")
	var nov := 0
	var cmd: Variant = null
	var names: Dictionary = {}
	for ch: Dictionary in r["chars"]:
		if ch["cls"] == "novice":
			nov += 1
			names[ch["nameId"]] = true
		if ch["cls"] == "commander":
			cmd = ch
	_check(nov == 5 and names.size() == 5 and cmd != null and int(cmd["uid"]) == 6 and int(r["nextId"]) == 7, "노비스 5명(이름 겹치지 않음) + 지휘관(uid 6)")
	_check(_same(PartyRules.find_party(c.store.get_json("game_parties"), 1)["slots"], [1, 2, 3, 4, 5]) and float(c.store.get_json("game_save")["gold"]) == 2000.0, "기본 파티 [1..5] · 골드 2000")
	_check(not LobbyRules.ensure_roster(c, 300), "두 번째: 그대로")
	_check(LobbyRules.commander_needs_setup(c), "지휘관 설정 필요 (setup 없음)")
	_check(LobbyRules.commander_display_name(c, "Rian") == "Rian", "설정 전 이름 = 언어별 기본 이름")
	LobbyRules.commander_apply(c, "f", "   가나다라마바사아자차카타   ", "Rian")
	var cm: Dictionary = LobbyRules.commander(c)
	_check(cm["gender"] == "f" and cm["customName"] == "가나다라마바사아자차" and cm["setup"] == true and not LobbyRules.commander_needs_setup(c), "지휘관 설정: 성별·이름(앞뒤 공백·10자)·setup")
	# JS trim 공백(전각·NBSP·BOM) · UTF-16 길이
	_check(LobbyRules.clean_name("\u3000\u00a0가\ufeff\u2003", "R") == "가" and LobbyRules.clean_name("\u3000", "R") == "R", "이름: JS trim 과 같은 공백 지움")
	var emo := "😀😀😀😀😀😀"
	_check(LobbyRules.clean_name(emo, "R") == "😀😀😀😀😀" and LobbyRules.utf16_len(emo) == 12 and LobbyRules.clean_name("a" + emo, "R") == "a😀😀😀😀", "이름: 10자 제한은 UTF-16 단위 (반쪽 글자는 뺌)")
	LobbyRules.commander_apply(c, "m", "   ", "Rian")
	_check(LobbyRules.commander(c)["customName"] == "Rian", "빈 이름 → 기본 이름")
	# 자동 부활 (살아 있는 클랜원 5명 미만 → 최근에 죽은 순)
	var ro := _roster(7)
	for i in [1, 2, 3, 4]:
		ro["chars"][i]["dead"] = true
		ro["chars"][i]["diedAt"] = float(i * 10)
		ro["chars"][i]["hp"] = 999
	var c2 := _mem_ctx({"game_roster": ro})
	var rv := LobbyRules.auto_revive(c2)
	var rv_ids: Array = []
	for ch2: Dictionary in rv:
		rv_ids.append(int(ch2["uid"]))
	var r2: Dictionary = c2.store.get_json("game_roster")
	_check(rv_ids == [4, 3], "자동 부활: 3명 살아 있음 → 최근에 죽은 2명 (%s)" % str(rv_ids))
	_check(not r2["chars"][4]["dead"] and not r2["chars"][4].has("diedAt") and float(r2["chars"][4]["hp"]) == float(D["JAB"][r2["chars"][4]["cls"]]["base"]["hp"]) and r2["chars"][1]["dead"], "부활: dead·diedAt 지움 · HP 직업 기본값 · 나머지는 그대로")
	_check(LobbyRules.auto_revive(c2).is_empty(), "5명이면 부활 없음")
	# 성별 보정 · 아지트
	var ro3 := _roster(12)
	ro3["chars"][3].erase("gender")
	var c3 := _mem_ctx({"game_roster": ro3})
	_check(LobbyRules.migrate_gender(c3) and ["m", "f"].has(c3.store.get_json("game_roster")["chars"][3]["gender"]), "성별 없는 클랜원에 성별")
	var ho := LobbyRules.hideout_chars(c3)
	var sorted_ok := ho.size() == 10
	for i in range(1, ho.size()):
		if float(ho[i]["lv"]) > float(ho[i - 1]["lv"]) or ho[i]["cls"] == "commander":
			sorted_ok = false
	_check(sorted_ok, "아지트: 지휘관 제외 · 레벨 높은 순 · 최대 10명")
	_stat("lobby.checks", 13)


# ═══════════ 4) 설정 저장 키 ═══════════

func _settings() -> void:
	store.call("clear")
	i18n.call("reload")
	_check(not (store.call("get_json", "game_settings", {}) as Dictionary).has("language"), "언어를 고르기 전에는 game_settings.language 없음")
	var expect_lang: String = i18n.call("detect_lang", OS.get_locale())
	_check(str(i18n.get("current_lang")) == expect_lang, "저장값 없으면 OS 언어 (%s → %s)" % [OS.get_locale(), expect_lang])
	_check(i18n.call("detect_lang", "fr_FR") == "en" and i18n.call("detect_lang", "zh_HK") == "zh-TW" and i18n.call("detect_lang", "pt-BR") == "en", "지원하지 않는 언어 → en, zh_HK → zh-TW")
	var sc: Node = (load(SCREENS["settings"]) as PackedScene).instantiate()
	root.add_child(sc)
	await _frames(2)
	sc.set_value("bgmVol", 0.3, false)
	sc.set_value("sfxOn", false, false)
	sc.set_value("playSpeed", 4, true)
	sc.set_value("reduceMotion", true, false)
	await _frames(2)
	var gs: Dictionary = store.call("get_json", "game_settings", {})
	var keys_outer: Array = gs.keys()
	keys_outer.sort()
	_check(keys_outer == ["bgmOn", "bgmVol", "playSpeed", "reduceMotion", "sfxOn", "sfxVol"], "바깥 설정 저장 키 %s (language 없음)" % str(keys_outer))
	_check(float(gs["bgmVol"]) == 0.3 and gs["sfxOn"] == false and int(gs["playSpeed"]) == 4 and gs["reduceMotion"] == true, "값 저장")
	# 전투 설정 창(hud_settings)과 같은 키·값 읽기
	var hs: Control = HudSettings.new()
	root.add_child(hs)
	hs.setup(store, i18n)
	var hk: Array = (hs.s as Dictionary).keys()
	hk.sort()
	_check(hk == keys_outer and _same(hs.s, gs), "전투 설정 창이 같은 키·값을 읽음 %s" % JsonX.stringify(hs.s))
	hs.s["bgmVol"] = 0.9
	hs.save_settings()
	var sc2: Node = (load(SCREENS["settings"]) as PackedScene).instantiate()
	root.add_child(sc2)
	await _frames(2)
	_check(float(sc2.s["bgmVol"]) == 0.9, "전투에서 바꾼 값을 바깥 설정이 읽음")
	# 웹 전용 speed 는 건드리지 않음
	var g2: Dictionary = store.call("get_json", "game_settings", {})
	g2["speed"] = 1.5
	store.call("set_json", "game_settings", g2)
	sc2.set_value("bgmOn", false, false)
	_check(float(store.call("get_json", "game_settings", {})["speed"]) == 1.5, "웹 speed 값은 그대로 남음")
	# 웹 speed 옮기기: playSpeed 없음 + speed ≤ 0.5 → 2x, 그 밖 1x (speed 는 그대로)
	for sp: Array in [[0.5, 2], [0.4, 2], [1.0, 1], [2.0, 1]]:
		store.call("set_json", "game_settings", {"bgmOn": true, "speed": sp[0]})
		var ms := SettingsRules.load_settings(store)
		var gs2: Dictionary = store.call("get_json", "game_settings", {})
		_check(int(ms["playSpeed"]) == int(sp[1]) and int(gs2.get("playSpeed", 0)) == int(sp[1]) and float(gs2["speed"]) == float(sp[0]), "웹 speed %s → playSpeed %dx (저장, speed 그대로)" % [str(sp[0]), sp[1]])
	store.call("set_json", "game_settings", {"speed": 0.5, "playSpeed": 1})
	_check(int(SettingsRules.load_settings(store)["playSpeed"]) == 1, "playSpeed 가 이미 있으면 그대로")
	store.call("set_json", "game_settings", g2)
	# 언어: 고를 때만 저장 · 바로 바뀜
	var lb: Button = sc2.find_child("Lang_ja", true, false)
	lb.pressed.emit()
	await _frames(2)
	_check(str(store.call("get_json", "game_settings", {}).get("language", "")) == "ja" and str(i18n.get("current_lang")) == "ja", "언어 단추 → 저장 + 바뀜")
	_check((sc2.find_child("Title", true, false) as Label).text == i18n.call("t", "settings.title"), "제목이 바로 그 언어로")
	i18n.call("set_language", "ko")
	hs.queue_free()
	sc.queue_free()
	sc2.queue_free()
	await _frames(3)
	store.call("clear")
	i18n.call("reload")
	_stat("settings.checks", 10)


# ═══════════ 5) 흐름 ═══════════

func _scene() -> Node:
	return current_scene


func _wait_scene(script_tail: String, secs: float = 6.0) -> bool:
	return await _until(func() -> bool:
		var s := current_scene
		return s != null and s.get_script() != null and str((s.get_script() as Script).resource_path).ends_with(script_tail) and s.is_node_ready(), secs)


func _press(b: Control) -> void:
	if b is BaseButton and not (b as BaseButton).disabled:
		(b as BaseButton).pressed.emit()


func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	root.push_input(ev)
	await process_frame
	var up := InputEventKey.new()
	up.keycode = k
	up.pressed = false
	root.push_input(up)
	await process_frame


## 같은 프레임에 누름·뗌 두 쌍 (진짜 마우스 입력 — push_input)
func _double_click(ctl: Control) -> void:
	var p := ctl.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = p
	root.push_input(mv)
	await process_frame
	for i in 2:
		for pressed: bool in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = p
			root.push_input(ev)
	await _frames(3)


func _mouse_back() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_XBUTTON1
	ev.pressed = true
	ev.position = Vector2(400, 300)
	root.push_input(ev)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_XBUTTON1
	up.pressed = false
	up.position = Vector2(400, 300)
	root.push_input(up)
	await process_frame


## 스토리 창이 열려 있으면 모두 건너뜀 (Esc) — 장면이 이어지므로 0.6초 동안 새 장면이 없을 때까지
func _skip_story(scr: Node) -> int:
	var n := 0
	var idle_t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - idle_t0 < 600 and n < 30:
		if not is_instance_valid(scr) or scr.get("story_view") == null:
			break
		if bool(scr.get("story_view").get("active")):
			await _key(KEY_ESCAPE)
			n += 1
			idle_t0 = Time.get_ticks_msec()
		await process_frame
	return n


func _battle_until_over(sc: Node) -> void:
	var t0 := Time.get_ticks_msec()
	var asked := false
	while Time.get_ticks_msec() - t0 < 60000:
		if not is_instance_valid(sc):
			return
		if sc.is_over() and sc.ui.result_view.visible:
			return
		if sc.is_story_playing():
			await _key(KEY_ESCAPE)
		elif sc.is_awaiting() and not asked:
			sc.surrender()
			asked = true
		await process_frame


func _flow() -> void:
	store.call("clear")
	i18n.call("set_language", "ko")
	store.call("set_json", "game_settings", {"language": "ko", "playSpeed": 4})
	router.set("history", [])
	change_scene_to_file("res://scenes/boot.tscn")
	_check(await _wait_scene("ui/lobby.gd"), "시작 → 로비")
	var lobby: Node = _scene()
	await _frames(3)
	_check(lobby.created_roster and lobby.setup_dialog != null and is_instance_valid(lobby.setup_dialog), "첫 실행: 클랜원 만들고 지휘관 설정 창 엶")
	_check(lobby.setup_input.text == i18n.call("t", "commander_setup.default_name"), "이름 칸 = 언어별 기본 이름 (%s)" % lobby.setup_input.text)
	await _key(KEY_ESCAPE)
	_check(is_instance_valid(lobby.setup_dialog), "첫 설정 창은 Esc 로 닫히지 않음")
	_press(lobby.setup_dialog.find_child("Card_f", true, false))
	lobby.setup_input.text = "\u3000하늘\u00a0\ufeff"
	await _double_click(lobby.setup_dialog.find_child("Confirm", true, false))   # 확정 두 번 누름
	await _frames(2)
	var cm: Dictionary = LobbyRules.commander(_mem_ctx({"game_roster": store.call("get_json", "game_roster")}))
	_check(cm.get("setup") == true and cm["gender"] == "f" and cm["customName"] == "하늘" and lobby.setup_dialog == null, "지휘관 설정 저장 (여 · 하늘)")
	_check(lobby.cmd_name.text == "하늘", "로비 지휘관 단추 이름")
	_check(lobby.hideout._units.size() == 5, "아지트 클랜원 5명")
	_check(lobby.gold_lbl.text == "2000 G", "골드 2000 G")
	_check(lobby.find_child("Resume", true, false) == null, "저장 전투가 없으면 전투 재개 단추 없음")
	# 준비 중 (도감 · 아래 탭 성소)
	_press(lobby.find_child("Compendium", true, false))
	await _frames(1)
	var toast: Node = lobby.find_child("Toast", true, false)
	_check(toast != null and str((toast.get_child(0) as Label).text) == i18n.call("t", "gd.outer.coming_soon"), "도감 → '준비 중' 알림")
	_press(lobby.find_child("Tab_sanctuary", true, false))
	await _frames(1)
	_check(_scene() == lobby, "아래 탭 성소 → 화면 그대로 (준비 중)")
	# 출격 → 스테이지 선택
	await _double_click(lobby.cta)
	_check(await _wait_scene("ui/stage_select.gd"), "출격 → 스테이지 선택")
	var ss: Node = _scene()
	await _frames(3)
	_check(ss.view_mode == "episodes" and not ss.cards["ep:1"].disabled and ss.cards["ep:2"].disabled, "에피소드: EP.1 열림 · EP.2 잠김")
	_check(ss.find_child("StoryReplay", true, false) == null, "본 장면이 없으면 다시 보기 단추 없음")
	_press(ss.cards["ep:1"])
	await _frames(2)
	_check(ss.view_mode == "stages" and ss.cards["st:1"].get_meta("next") and ss.cards["st:2"].disabled, "EP.1 스테이지: 1-1 NEXT · 1-2 잠김")
	_check(ss.title_lbl.text.begins_with("EP.1 "), "제목 EP.1 + 이름")
	# 상세 정보 → Esc 로 닫힘 → Esc 로 에피소드 목록 → 마우스 뒤로 단추로 로비
	ss.show_stage_info(1)
	await _frames(2)
	_check(ss.modal_open() and ss.find_child("Practice", true, false) == null, "정보 창 (클리어 전이라 연습 모드 없음)")
	await _key(KEY_ESCAPE)
	await _frames(1)
	_check(not ss.modal_open() and ss.view_mode == "stages", "Esc → 창만 닫힘")
	await _key(KEY_ESCAPE)
	await _frames(1)
	_check(ss.view_mode == "episodes", "Esc → 에피소드 목록")
	await _mouse_back()
	_check(await _wait_scene("ui/lobby.gd"), "마우스 뒤로 단추 → 로비")
	# 아래 탭 스테이지 → 1-1 → 프롤로그·전투 전 대사 → 전투 (5명)
	_press(_scene().find_child("Tab_stage", true, false))
	_check(await _wait_scene("ui/stage_select.gd"), "아래 탭 스테이지 → 스테이지 선택")
	ss = _scene()
	await _frames(2)
	ss.open_episode(1)
	await _frames(1)
	await _double_click(ss.cards["st:1"])
	await _frames(3)
	_check(bool(ss.story_view.get("active")), "출전 전 스토리 재생 (%s)" % str(ss.story_log))
	var skipped := await _skip_story(ss)
	var seen: Dictionary = store.call("get_json", "game_story_seen", {})
	_check(seen.has("ep1_pro") and skipped >= 1, "에피소드 1 프롤로그 본 것으로 기록 (%d장면 건너뜀, %s)" % [skipped, str(seen.keys())])
	_stat("flow.story_scenes", skipped)
	_check(await _wait_scene("battle/battle_scene.gd", 10.0), "5명 → 바로 전투")
	var bt: Node = _scene()
	_check(bt.cfg.get("source") == "store" and _same(bt.cfg.get("party"), [1, 2, 3, 4, 5]) and int(bt.cfg["stage"]["id"]) == 1 and not store.call("has", "game_nav"), "전투 설정: 실제 세이브 · 파티 · 스테이지 1 · game_nav 지움")
	await _battle_until_over(bt)
	_check(bt.is_over(), "전투 끝 (항복)")
	_check(bt.ui.result_view.buttons.has("back"), "결과: 로비로 단추")
	await create_timer(1.0).timeout   # 결과 창이 나타나는 움직임이 끝난 뒤 누름
	await _double_click(bt.ui.result_view.buttons["back"])
	_check(await _wait_scene("ui/lobby.gd"), "결과 → 로비 (두 번 누름)")
	_check(router.current == "lobby" and (router.history as Array).is_empty(), "로비 = 기록 비움")
	# 4명 → 편성 화면 → 채우고 출격
	var ps_data: Dictionary = store.call("get_json", "game_parties")
	ps_data["parties"][0]["slots"][4] = null
	store.call("set_json", "game_parties", ps_data)
	_press(_scene().cta)
	await _wait_scene("ui/stage_select.gd")
	ss = _scene()
	await _frames(2)
	ss.launch(ProgressRules.find_stage(_mem_ctx({}), 1), false)
	_check(await _wait_scene("ui/party_select.gd"), "4명 → 편성 화면")
	var ps: Node = _scene()
	await _frames(3)
	_check(not ps.start_btn.visible and ps.counter.text == "4 / 5", "편성: 4/5 · 출격 단추 숨김")
	_press(ps.find_child("Slot4", true, false))
	await _frames(3)
	_check(ps.modal_open() and ps.unit_modal != null, "빈 칸 → 유닛 고르기 창")
	var cards: Node = ps.unit_modal.find_child("Cards", true, false)
	var pick: Button = null
	for b: Node in cards.get_children():
		if b is Button and str(b.name) == "Unit_5":
			pick = b
	_check(pick != null, "유닛 카드 (uid 5)")
	_press(pick)
	await _frames(3)
	_check(not ps.modal_open() and ps.counter.text == "5 / 5" and ps.start_btn.visible, "배치 → 5/5 · 출격 단추")
	_check(_same(PartyRules.find_party(store.call("get_json", "game_parties"), 1)["slots"], [1, 2, 3, 4, 5]), "배치 저장")
	# 칸에서 빼기 · 다시 넣기 (키보드: 카드에 포커스 + Enter)
	_press(ps.find_child("Slot1", true, false).find_child("Remove", true, false))
	await _frames(2)
	_check(ps.counter.text == "4 / 5", "✕ → 빼기")
	ps.open_unit_modal(1)
	await _frames(3)
	var fb: Control = ps.get_viewport().gui_get_focus_owner()
	_check(fb != null and str(fb.name).begins_with("Unit_"), "창의 첫 카드에 키보드 포커스 (%s)" % (str(fb.name) if fb != null else "없음"))
	# 첫 카드는 이 파티 클랜원(정렬: 파티원 먼저) — 뺀 클랜원(uid 2) 카드로 포커스를 옮겨 Enter
	var c2: Control = ps.unit_modal.find_child("Unit_2", true, false)
	if c2 != null:
		c2.grab_focus()
	await _frames(1)
	await _key(KEY_ENTER)
	await _frames(3)
	_check(ps.counter.text == "5 / 5", "Enter → 고름")
	# 페이지 탭 장비 (4b-1: 진짜 탭 — 출격 단추는 파티 탭에서만) → 파티 탭으로 돌아옴
	_press(ps.find_child("PageTab_equip", true, false))
	await _frames(2)
	_check(ps.gear.sections["equip"].visible and not ps.start_btn.is_visible_in_tree(), "장비 탭 → 장비 탭 (출격 단추 안 보임)")
	_press(ps.find_child("PageTab_party", true, false))
	await _frames(2)
	_check(ps.start_btn.is_visible_in_tree() and store.call("get_str", "ps_active_tab") == "party", "파티 탭으로 돌아옴 (출격 단추)")
	await _double_click(ps.start_btn)
	_check(await _wait_scene("battle/battle_scene.gd", 10.0), "출격 → 전투")
	bt = _scene()
	await _battle_until_over(bt)
	# 다음 스테이지 흐름 (승리 대신 함수로): 5명 → 바로 전투
	var old_id := bt.get_instance_id()
	bt._on_result_button("next")
	bt._on_result_button("next")   # 같은 프레임 두 번 → 한 번만
	_check(await _until(func() -> bool: return _scene() != null and _scene().get_instance_id() != old_id and _scene().has_method("is_over"), 8.0), "다음 스테이지 → 바로 전투")
	bt = _scene()
	await _frames(2)
	_check(int(bt.cfg["stage"]["id"]) == 2 and not bt.cfg.get("practice", false), "다음 스테이지 = 2 · 연습 아님")
	await _battle_until_over(bt)
	_press(bt.ui.result_view.buttons["back"])
	await _wait_scene("ui/lobby.gd")
	# 요일 던전: 입장 → 전투 → '요일 던전으로' → 스테이지 선택 + 요일 던전 창
	_press(_scene().cta)
	await _wait_scene("ui/stage_select.gd")
	ss = _scene()
	await _frames(2)
	var left0 := ProgressRules.daily_left(_mem_ctx({"game_daily": store.call("get_json", "game_daily")}), Time.get_date_dict_from_system())
	ss.open_daily()
	await _frames(2)
	_check(ss.modal_open() and ss.find_child("Tier_easy", true, false) != null and ss.find_child("Tier_hell", true, false).disabled, "요일 던전 창: 쉬움 열림 · 지옥 잠김")
	var used0 := ProgressRules.daily_used(_mem_ctx({"game_daily": store.call("get_json", "game_daily")}), Time.get_date_dict_from_system())
	await _double_click(ss.find_child("Tier_easy", true, false))
	_check(await _wait_scene("battle/battle_scene.gd", 10.0), "요일 던전 → 전투")
	_check(ProgressRules.daily_used(_mem_ctx({"game_daily": store.call("get_json", "game_daily")}), Time.get_date_dict_from_system()) == used0 + 1.0, "같은 프레임 두 번 누르기(진짜 입력) → 입장 1회만 소모")
	bt = _scene()
	_check(bt.cfg["stage"].has("daily"), "요일 던전 스테이지 지정")
	_check(ProgressRules.daily_left(_mem_ctx({"game_daily": store.call("get_json", "game_daily")}), Time.get_date_dict_from_system()) == left0 - 1, "입장 1회 소모")
	await _battle_until_over(bt)
	_check(not bt.ui.result_view.buttons.has("retry"), "요일 던전 결과: 다시 도전 없음")
	_press(bt.ui.result_view.buttons["back"])
	_check(await _wait_scene("ui/stage_select.gd"), "요일 던전 결과 → 스테이지 선택")
	await _frames(3)
	_check(_scene().modal_open() and _scene().find_child("DailyModal", true, false) != null, "요일 던전 창이 열려 있음")
	# 스토리 다시 보기
	_scene().close_all_modals()
	_scene()._refresh()
	await _frames(2)
	var rb: Node = _scene().find_child("StoryReplay", true, false)
	_check(rb != null, "본 장면이 있으면 다시 보기 단추")
	_press(rb)
	await _frames(2)
	var item: Node = _scene().find_child("Replay_ep1_pro", true, false)
	_check(item != null, "다시 보기 목록에 EP.1 프롤로그")
	_press(item)
	await _frames(2)
	_check(bool(_scene().story_view.get("active")), "다시 보기 재생")
	await _skip_story(_scene())
	await _frames(2)
	_check(_scene().modal_open(), "다시 보기가 끝나면 목록으로")
	_scene().close_all_modals()
	# 설정 화면: 톱니 → 설정 → 뒤로 = 열기 전 화면 (고른 에피소드 유지, 요일 던전 창은 한 번만)
	_scene().open_episode(1)
	await _frames(1)
	_press(_scene().gear_btn)
	_check(await _wait_scene("ui/settings_screen.gd"), "톱니 → 설정")
	await _key(KEY_ESCAPE)
	_check(await _wait_scene("ui/stage_select.gd"), "설정에서 Esc → 열기 전 화면(스테이지 선택)")
	await _frames(3)
	_check(_scene().view_mode == "stages" and _scene().selected_ep == 1 and not _scene().modal_open(), "돌아와도 고른 에피소드 유지 · 요일 던전 창은 다시 안 열림 (기록 %s)" % JsonX.stringify(router.history))
	# 편성 탭 → 뒤로 = 로비 (출격 단추 끔)
	_press(_scene().find_child("Tab_party", true, false))
	await _wait_scene("ui/party_select.gd")
	_check(store.call("get_str", "ps_can_start") == "false" and not _scene().start_btn.visible, "아래 탭으로 편성 → 출격 단추 꺼짐")
	_press(_scene().back_btn)
	_check(await _wait_scene("ui/lobby.gd"), "편성 뒤로 → 로비")
	# 초기화 → 처음부터
	_press(_scene().gear_btn)
	await _wait_scene("ui/settings_screen.gd")
	var st_sc: Node = _scene()
	await _frames(2)
	_press(st_sc.find_child("Reset", true, false))
	await _frames(2)
	await _double_click(st_sc.find_child("Yes", true, false))
	_check(await _wait_scene("ui/lobby.gd", 8.0), "모든 데이터 초기화 → 시작 화면 → 로비")
	await _frames(3)
	_check(_scene().created_roster and _scene().setup_dialog != null, "초기화 뒤 첫 실행처럼 (클랜원 새로 · 지휘관 설정)")
	_scene().commander_setup_done()
	await _frames(2)
	_stat("flow.screens", 9)
	change_scene_to_file("res://scenes/boot.tscn")
	await _frames(2)
	current_scene.queue_free()
	await _frames(2)


# ═══════════ 6) 6개 언어: 넘침 · 두부 ═══════════

## 화면 안 모든 글자 부품 검사 → [넘침 목록, 두부 목록, 검사한 글자 부품 수]
func _audit(scr: Node, lang: String) -> Array:
	var overflow: Array = []
	var tofu: Array = []
	var n := 0
	var vr := root.get_visible_rect()
	var stack: Array = [scr]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is Control and not (nd as Control).is_visible_in_tree():
			continue
		if nd.get_meta("overflow_ok", false) or str(nd.name) == "Hideout":
			continue
		stack.append_array(nd.get_children())
		if not (nd is Control):
			continue
		var ctl := nd as Control
		var txt := ""
		if ctl is Label:
			txt = (ctl as Label).text
		elif ctl is Button:
			txt = (ctl as Button).text
		elif ctl is RichTextLabel:
			txt = (ctl as RichTextLabel).get_parsed_text()
		elif ctl is LineEdit:
			txt = (ctl as LineEdit).text + (ctl as LineEdit).placeholder_text
		if txt != "":
			n += 1
			for i in txt.length():
				var cp := txt.unicode_at(i)
				if cp < 32 or cp == 0x200B:
					continue
				if not FontsT.chain_has_char(lang, cp):
					tofu.append("%s '%s' U+%04X" % [ctl.get_path(), txt.substr(0, 20), cp])
					break
		# 넘침: 글자 부품이 실제 필요한 폭보다 좁게 잘림 (말줄임·자르기 설정이 없을 때)
		if ctl is Label:
			var l := ctl as Label
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF and not l.clip_text and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
				if l.get_minimum_size().x > l.size.x + 1.0:
					overflow.append("%s 좁음 %.0f>%.0f '%s'" % [ctl.get_path(), l.get_minimum_size().x, l.size.x, l.text.substr(0, 24)])
		# 부모 밖으로 (스크롤 안 내용은 가로만)
		var par := ctl.get_parent() as Control
		if par != null and not (par is ScrollContainer) and ctl.size.x > 0.0 and not (ctl is ScrollContainer and par.name == "Box"):
			var pr := par.get_global_rect().grow(3.0)
			var r := ctl.get_global_rect()
			if not pr.encloses(r) and r.size.x > 0.0:
				overflow.append("%s 부모 밖 %s ⊄ %s '%s'" % [ctl.get_path(), str(r), str(pr), txt.substr(0, 20)])
		# 화면 밖 (스크롤 안은 가로만)
		if txt != "":
			var r2 := ctl.get_global_rect()
			var in_scroll := false
			var a: Node = ctl.get_parent()
			while a != null:
				if a is ScrollContainer:
					in_scroll = true
					var sr := (a as Control).get_global_rect().grow(2.0)
					if r2.position.x < sr.position.x or r2.end.x > sr.end.x:
						overflow.append("%s 스크롤 가로 밖 '%s'" % [ctl.get_path(), txt.substr(0, 20)])
					break
				a = a.get_parent()
			if not in_scroll and not vr.grow(1.0).encloses(r2):
				overflow.append("%s 화면 밖 %s '%s'" % [ctl.get_path(), str(r2), txt.substr(0, 20)])
	return [overflow, tofu, n]


## 화면을 띄워 여러 상태(창 포함)를 차례로 검사 → 문제 목록
func _audit_screen(key: String, lang: String) -> Array:
	var problems: Array = []
	var count := 0
	router.set("params", {})
	var scr: Node = (load(SCREENS[key]) as PackedScene).instantiate()
	root.add_child(scr)
	await _frames(4)
	var states: Array = ["base"]
	match key:
		"lobby":
			states = ["base", "commander"]
		"stage_select":
			states = ["base", "stages", "info", "info_boss", "daily", "replay"]
		"party_select":
			states = ["base", "unit_modal"]
		"settings":
			states = ["base", "confirm"]
	for stt: String in states:
		match stt:
			"commander":
				scr.open_commander_setup(false)
			"stages":
				scr.open_episode(1)
			"info":
				scr.show_stage_info(10)
			"info_boss":
				scr.close_all_modals()
				scr.show_stage_info(45)
			"daily":
				scr.close_all_modals()
				scr.open_daily()
			"replay":
				scr.close_all_modals()
				scr.open_replay()
			"unit_modal":
				scr.open_unit_modal(0)
			"confirm":
				scr.ask_reset()
		await _frames(4)
		var res := _audit(scr, lang)
		count += int(res[2])
		for o: String in res[0]:
			problems.append("[%s %s %s] 넘침 %s" % [lang, key, stt, o])
		for tf: String in res[1]:
			problems.append("[%s %s %s] 두부 %s" % [lang, key, stt, tf])
	scr.queue_free()
	await _frames(2)
	return [problems, count]


## 다양한 세이브 (긴 이름 · 여러 직업 · 장비 · 진행) — 넘침을 잘 드러내도록
func _rich_save() -> void:
	store.call("clear")
	var r := _roster(14)
	r["chars"][0]["customName"] = "가나다라마바사아자차"
	r["chars"][0]["setup"] = true
	r["chars"][3]["customName"] = "WWWWWWWWWW"
	var gc := _mem_ctx({})
	var w1 := Gear.generate_equip(gc, Gear.equip_template(gc, "wpn_archer"), "epic")
	var h1 := Gear.generate_equip(gc, Gear.equip_template(gc, "leather_cap"), "legendary")
	w1["enhanceLv"] = 7
	h1["enhanceLv"] = 12
	w1["equipped"] = 3
	h1["equipped"] = 3
	r["chars"][3]["equip"] = {"weapon": w1["eid"], "helmet": h1["eid"]}
	store.call("set_json", "game_roster", r)
	store.call("set_json", "game_parties", PartyRules.create_default_parties([4, 2, 3, 5, 6]))
	store.call("set_json", "game_save", {"gold": 1234567.0, "cleared": range(1, 46), "stars": {"1": [1, 1, 1], "10": [1, 0, 1]}})
	store.call("set_json", "game_inventory", [w1, h1])
	store.call("set_json", "game_story_seen", {"ep1_pro": true, "s1_pre": true, "s1_start": true, "s10_post": true, "ep1_epi": true})
	store.call("set_json", "game_soul", {"stones": {"mage": 12}, "frags": {"mage": 7}})
	store.call("set_str", "ps_can_start", "true")
	store.call("set_json", "game_nav", {"cStage": ProgressRules.find_stage(_mem_ctx({}), 3)})


func _langs() -> void:
	root.size = Vector2i(1280, 720)
	var all_problems: Array = []
	var total := 0
	for lang: String in LANGS:
		_rich_save()
		i18n.call("_apply", lang)
		for key: String in SCREENS.keys():
			var res: Array = await _audit_screen(key, lang)
			all_problems.append_array(res[0])
			total += int(res[1])
	for p: String in all_problems.slice(0, 40):
		print("    " + p)
	var ovf := 0
	var tf := 0
	for p2: String in all_problems:
		if p2.contains("] 두부"):
			tf += 1
		else:
			ovf += 1
	_check(ovf == 0, "6개 언어 넘침 0 (글자 부품 %d개 검사, 넘침 %d)" % [total, ovf])
	_check(tf == 0, "6개 언어 두부 0 (두부 %d)" % tf)
	_stat("lang.text_controls", total)
	_stat("lang.overflow", ovf)
	_stat("lang.tofu", tf)
	i18n.call("_apply", "ko")


# ═══════════ 7) 창 크기 ═══════════

func _on_screen(c: Control) -> bool:
	if c == null or not c.is_visible_in_tree():
		return false
	var r := c.get_global_rect()
	return root.get_visible_rect().grow(1.0).encloses(r) and r.size.x > 0.0


func _sizes() -> void:
	var sizes := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 600), Vector2i(800, 1000), Vector2i(480, 900)]
	var bad: Array = []
	var checks := 0
	for res: Vector2i in sizes:
		root.size = res
		for lang: String in ["ko", "es"]:
			_rich_save()
			i18n.call("_apply", lang)
			for key: String in SCREENS.keys():
				var scr: Node = (load(SCREENS[key]) as PackedScene).instantiate()
				root.add_child(scr)
				await _frames(4)
				var must: Array = [scr.top_nav]
				if scr.has_bottom_nav():
					must.append(scr.bottom_nav)
				match key:
					"lobby":
						must.append_array([scr.cta, scr.cmd_btn, scr.hideout, scr.find_child("Compendium", true, false), scr.find_child("Guide", true, false)])
					"stage_select":
						must.append_array([scr.find_child("DailyEntry", true, false), scr.cards["ep:1"]])
					"party_select":
						must.append_array([scr.start_btn, scr.counter, scr.find_child("Slot0", true, false), scr.find_child("PageTab_enhance", true, false)])
					"settings":
						must.append_array([scr.find_child("Lang_zh-TW", true, false), scr.find_child("Toggle_bgmOn", true, false)])
				for m: Variant in must:
					checks += 1
					if not _on_screen(m):
						bad.append("[%dx%d %s %s] %s 화면 밖·안 보임 %s" % [res.x, res.y, lang, key, (m as Node).name if m != null else "null", str((m as Control).get_global_rect()) if m != null else ""])
				# 위·아래 줄과 겹치지 않음 (본문 부품이 위 줄 아래에서 시작)
				var a := _audit(scr, lang)
				for o: String in a[0]:
					bad.append("[%dx%d %s %s] 넘침 %s" % [res.x, res.y, lang, key, o])
				checks += int(a[2])
				scr.queue_free()
				await _frames(2)
	for b: String in bad.slice(0, 30):
		print("    " + b)
	_check(bad.is_empty(), "창 크기 %d가지 × 2개 언어 × 4개 화면: 주요 부품 화면 안 · 넘침 0 (%d개 검사, 문제 %d)" % [sizes.size(), checks, bad.size()])
	_stat("sizes.checks", checks)
	root.size = Vector2i(1280, 720)
	i18n.call("_apply", "ko")


# ═══════════ 8) 이상한 값이 든 세이브 ═══════════

var _rng := RandomNumberGenerator.new()


func _junk(depth: int = 0) -> Variant:
	var pool: Array = [null, 0, -1, 1, 1.5, 3, 99999, -0.5, "", "x", "50", "2", "null", "NaN", true, false]
	var r := _rng.randi() % 10
	if depth < 2 and r == 0:
		var a: Array = []
		for i in _rng.randi() % 4:
			a.append(_junk(depth + 1))
		return a
	if depth < 2 and r == 1:
		var d: Dictionary = {}
		for i in _rng.randi() % 3:
			d[["a", "id", "slots", "1", "used"][_rng.randi() % 5]] = _junk(depth + 1)
		return d
	return pool[_rng.randi() % pool.size()]


func _maybe(v: Variant, p: float = 0.3) -> Variant:
	return _junk() if _rng.randf() < p else v


## 무작위로 망가뜨린 세이브 하나 (키마다 원본 문자열) — 정상 구조에 이상한 값을 섞거나 통째로 쓰레기
func _fuzz_save() -> Dictionary:
	var raw: Dictionary = {}
	var classes := ["novice", "warrior", "archer", "commander", "nope", "summon_wolf", 7]
	var chars: Array = []
	for i in _rng.randi() % 9:
		var ch := {"uid": _maybe(i + 1, 0.2), "cls": _maybe(classes[_rng.randi() % classes.size()], 0.2), "nameId": _maybe(i, 0.2), "lv": _maybe(1 + _rng.randi() % 9, 0.2),
			"exp": _maybe(0, 0.15), "dead": _maybe(_rng.randf() < 0.3, 0.2), "hp": _maybe(80, 0.15), "atk": _maybe(20, 0.15), "def": _maybe(8, 0.15),
			"move": _maybe(3, 0.1), "range": _maybe(1, 0.1), "pot": _maybe({"hp": _maybe(8.0, 0.2), "atk": _maybe(2.0, 0.2), "def": _maybe(1.0, 0.2), "actionRec": _maybe(0.1, 0.2)}, 0.3),
			"actionRec": _maybe(1.1, 0.2), "gender": _maybe(["m", "f"][_rng.randi() % 2], 0.2)}
		if _rng.randf() < 0.3:
			ch["customName"] = _maybe("이름", 0.5)
		if _rng.randf() < 0.3:
			ch["equip"] = _maybe({"weapon": _maybe("e1", 0.5)}, 0.5)
		if _rng.randf() < 0.2:
			ch["skillLv"] = _junk()
		if _rng.randf() < 0.2:
			ch["diedAt"] = _junk()
		chars.append(_maybe(ch, 0.1))
	var roster: Variant = {"chars": chars, "nextId": _maybe(20, 0.3)}
	var parties: Array = []
	for i in _rng.randi() % 7:
		var sl: Array = []
		for j in _rng.randi() % 8:
			sl.append(_maybe([1, 2, 3, 100, null, 5][_rng.randi() % 6], 0.3))
		parties.append(_maybe({"id": _maybe(i + 1, 0.3), "slots": _maybe(sl, 0.2)}, 0.2))
	var pd: Variant = {"parties": _maybe(parties, 0.15), "activePartyId": _maybe(1, 0.3), "nextPartyId": _maybe(6, 0.3)}
	var cl: Array = []
	for i in _rng.randi() % 15:
		cl.append(_maybe(i + 1, 0.3))
	var save: Variant = {"gold": _maybe(500, 0.3), "cleared": _maybe(cl, 0.2), "stars": _maybe({"1": _maybe([1, 0, 1], 0.4), "3": _junk()}, 0.3)}
	var vals := {"game_roster": _maybe(roster, 0.1), "game_parties": _maybe(pd, 0.15), "game_save": _maybe(save, 0.15),
		"game_daily": _maybe({"date": _maybe(ProgressRules.today_str(Time.get_date_dict_from_system()), 0.3), "used": _junk()}, 0.2),
		"game_story_seen": _maybe({"ep1_pro": true, "s1_pre": _junk()}, 0.3), "game_inventory": _maybe([_junk(), {"type": "equip", "eid": "e1", "slot": _junk(), "rarity": _junk(), "enhanceLv": _junk()}], 0.3),
		"game_settings": _maybe({"bgmOn": _junk(), "bgmVol": _junk(), "playSpeed": _junk(), "speed": _junk(), "language": _maybe("ja", 0.5)}, 0.3),
		"game_nav": _maybe({"cStage": _maybe({"id": _maybe(3, 0.4)}, 0.4), "practiceMode": _junk()}, 0.3),
		"game_soul": _maybe({"stones": _junk(), "frags": _junk()}, 0.3), "game_party": _junk(), "game_cleared": _junk(), "game_battle_items": _junk(), "game_battle": _junk()}
	for k: String in vals.keys():
		var r := _rng.randf()
		if r < 0.08:
			continue   # 없음
		elif r < 0.12:
			raw[k] = ""   # 빈 문자열 원본
		elif r < 0.15:
			raw[k] = ["{bad", "undefined", "NaN", "[1,", "\"str\""][_rng.randi() % 5]
		else:
			raw[k] = JsonX.stringify(vals[k])
	if _rng.randf() < 0.3:
		raw["ps_can_start"] = ["true", "false", "", "1"][_rng.randi() % 4]
	return raw


## 손으로 만든 이상한 세이브 (검수에서 나온 것 + 형 하나씩)
func _weird_cases() -> Array:
	var good := _roster(6)
	var out: Array = []
	var add := func(name: String, kv: Dictionary) -> void:
		var raw: Dictionary = {"game_roster": JsonX.stringify(good)}
		for k: String in kv.keys():
			raw[k] = kv[k] if typeof(kv[k]) == TYPE_STRING and (k == "ps_can_start" or str(kv[k]) == "" or str(kv[k]).begins_with("{bad")) else JsonX.stringify(kv[k])
		out.append([name, raw])
	add.call("파티 목록에 null·숫자", {"game_parties": {"parties": [null, 3, {"id": 1, "slots": [1, 2, null, 4, 5]}], "activePartyId": 1, "nextPartyId": 6}})
	add.call("파티 id 글자·nextPartyId 없음", {"game_parties": {"parties": [{"id": "2", "slots": [1, 2, 3, 4, 5]}, {"id": "x", "slots": [6]}], "activePartyId": "2"}})
	add.call("파티 칸 글자·소수·음수·지휘관", {"game_parties": {"parties": [{"id": 1, "slots": ["1", 2.5, -3, 100, "abc", {}, []]}], "activePartyId": 1, "nextPartyId": 2}})
	add.call("파티 slots 가 숫자", {"game_parties": {"parties": [{"id": 1, "slots": 5}], "activePartyId": 1}})
	add.call("parties 가 사전", {"game_parties": {"parties": {"a": 1}, "activePartyId": 1}})
	add.call("game_parties 가 배열", {"game_parties": [1, 2]})
	add.call("클리어 글자 숫자", {"game_save": {"gold": 10, "cleared": ["50", "1", "x", 2, null, 3.0, {}]}})
	add.call("클리어가 글자", {"game_save": {"gold": 10, "cleared": "1,2,3"}})
	add.call("stars 가 배열", {"game_save": {"gold": 10, "cleared": [1], "stars": [[1, 1, 1]]}})
	add.call("stars 칸이 이상", {"game_save": {"gold": 10, "cleared": [1, 2], "stars": {"1": "x", "2": [1], "3": [1, 1, 1, 1, 1]}}})
	add.call("game_save 가 숫자", {"game_save": 5})
	add.call("game_save 가 배열", {"game_save": [1, 2]})
	add.call("game_save 빈 문자열", {"game_save": ""})
	add.call("game_save 깨진 JSON", {"game_save": "{bad"})
	add.call("요일 used 글자", {"game_daily": {"date": ProgressRules.today_str(Time.get_date_dict_from_system()), "used": "2"}})
	add.call("요일 used 소수", {"game_daily": {"date": ProgressRules.today_str(Time.get_date_dict_from_system()), "used": 1.5}})
	add.call("요일 used 없음", {"game_daily": {"date": ProgressRules.today_str(Time.get_date_dict_from_system())}})
	add.call("요일 used 음수·사전", {"game_daily": {"date": ProgressRules.today_str(Time.get_date_dict_from_system()), "used": {"a": 1}}})
	add.call("game_daily 가 배열", {"game_daily": [1]})
	add.call("본 장면이 배열", {"game_story_seen": [1, 2]})
	add.call("nav 이상", {"game_nav": {"cStage": "x", "party": "y"}, "ps_can_start": "true"})
	add.call("nav cStage id 글자", {"game_nav": {"cStage": {"id": "3"}}, "ps_can_start": "true"})
	add.call("설정 이상", {"game_settings": {"bgmOn": "x", "bgmVol": "loud", "playSpeed": 7, "speed": "fast", "language": 5}})
	add.call("인벤토리 이상", {"game_inventory": [null, 5, {"type": "equip"}, {"type": "equip", "eid": 5, "rarity": "zzz", "enhanceLv": "x", "slot": 3}]})
	add.call("영혼석 이상", {"game_soul": {"stones": [], "frags": "x"}})
	add.call("빈 문자열 원본 여러 개", {"game_parties": "", "game_save": "", "game_inventory": "", "game_daily": ""})
	var r1 := _roster(6)
	r1["chars"][2]["pot"] = []
	r1["chars"][3]["cls"] = 5
	out.append(["pot [] · cls 숫자 (profile.gd)", {"game_roster": JsonX.stringify(r1), "game_parties": JsonX.stringify({"parties": [{"id": 1, "slots": [100, 1, 2, 3, 4]}], "activePartyId": 1, "nextPartyId": 2})}])
	var r2 := _roster(4)
	r2["chars"][1]["pot"] = 5
	r2["chars"][2]["skillLv"] = []
	r2["chars"][3]["equip"] = []
	r2["chars"][4]["customName"] = 123
	r2["chars"][4]["nameId"] = "x"
	out.append(["pot 숫자 · skillLv [] · equip [] · 이름 숫자", {"game_roster": JsonX.stringify(r2)}])
	out.append(["chars 가 글자", {"game_roster": JsonX.stringify({"chars": "x", "nextId": 3})}])
	out.append(["chars 에 null·숫자", {"game_roster": JsonX.stringify({"chars": [null, 5, {"uid": 1, "cls": "novice"}], "nextId": 3})}])
	out.append(["로스터 빈 문자열", {"game_roster": ""}])
	out.append(["모두 깨진 JSON", {"game_roster": "{bad", "game_parties": "{bad", "game_save": "{bad", "game_inventory": "[1,"}])
	return out


## 세이브 하나로 모든 화면 진입·창 열기 → [오류 수, 화면 진입 실패 목록, 지휘관이 파티에 있음]
func _try_save(raw: Dictionary) -> Array:
	store.call("clear")
	for k: String in raw.keys():
		store.call("set_str", k, raw[k])
	i18n.call("reload")
	var e0 := _counter.errors.size()
	var fails: Array = []
	router.set("params", {})
	for key: String in ["lobby", "stage_select", "party_select", "settings"]:
		var scr: Node = (load(SCREENS[key]) as PackedScene).instantiate()
		root.add_child(scr)
		await process_frame
		if not scr.is_node_ready() or scr.get("body") == null:
			fails.append(key)
		match key:
			"lobby":
				if scr.get("setup_dialog") != null:
					scr.commander_setup_done()
			"stage_select":
				scr.open_episode(1)
				scr.show_stage_info(1)
				scr.close_all_modals()
				scr.open_daily()
				scr.close_all_modals()
				scr.open_replay()
				scr.close_all_modals()
				scr.go_back()
			"party_select":
				scr.open_unit_modal(0)
				var cards: Node = scr.find_child("Cards", true, false)
				if cards != null and cards.get_child_count() > 0 and cards.get_child(0) is Button:
					(cards.get_child(0) as Button).pressed.emit()
				scr.close_all_modals()
				scr.set_active_party(PartyRules.load_parties(_mem_ctx({})).get("activePartyId", 1))
		await process_frame
		scr.queue_free()
		await process_frame
	# 지휘관은 어느 파티에도 없어야 함
	var cmd_in := false
	var c := Ctx.new(D, 1, load("res://scripts/logic/store_ctx.gd").new(store))
	var cu: Variant = PartyRules.commander_uid(c)
	var pd := PartyRules.load_parties(c)
	if cu != null:
		for p: Variant in pd["parties"]:
			if Js.index_of(p["slots"], cu) != -1:
				cmd_in = true
	return [_counter.errors.size() - e0, fails, cmd_in]


func _weird() -> void:
	root.size = Vector2i(1280, 720)
	var router_dry: bool = router.get("dry_run")
	router.set("dry_run", true)   # 화면 안의 이동 단추가 진짜 장면을 바꾸지 않게
	var bad: Array = []
	var cases := _weird_cases()
	for wc: Array in cases:
		var r: Array = await _try_save(wc[1])
		if int(r[0]) > 0 or not (r[1] as Array).is_empty() or r[2]:
			bad.append("[%s] 오류 %d · 진입 실패 %s · 지휘관 파티 %s" % [wc[0], r[0], str(r[1]), str(r[2])])
	_check(bad.is_empty(), "손으로 만든 이상한 세이브 %d개: 오류 0 · 모든 화면 진입 · 지휘관 파티 밖" % cases.size())
	_stat("weird.manual", cases.size())
	var n := 200
	var fbad: Array = []
	for i in n:
		_rng.seed = 1000 + i
		var raw := _fuzz_save()
		var r2: Array = await _try_save(raw)
		if int(r2[0]) > 0 or not (r2[1] as Array).is_empty() or r2[2]:
			fbad.append("[시드 %d] 오류 %d · 진입 실패 %s · 지휘관 파티 %s" % [1000 + i, r2[0], str(r2[1]), str(r2[2])])
	for b: String in (bad + fbad).slice(0, 30):
		print("    " + b)
	_check(fbad.is_empty(), "무작위 퍼징 세이브 %d개: 오류 0 · 모든 화면 진입 · 지휘관 파티 밖 (문제 %d)" % [n, fbad.size()])
	_stat("weird.fuzz", n)
	_stat("weird.problems", bad.size() + fbad.size())
	router.set("dry_run", router_dry)
	store.call("clear")
	i18n.call("_apply", "ko")
