extends SceneTree
## 4b-2 시험 — 성소 · 아카데미 · 도감 · 가이드 · 크레딧 · 라이선스 · '준비 중' 없애기 · 4b-1 남은 것(이어하기 판 확인 · 포기 · V8 정렬)
##   Godot --headless --path godot --script res://tests/check_outer_4b2.gd   [-- --only rules,codex,v8,resume,screens,clicks,weird,lang,nosoon]
##  1) rules  : 성소(목록·부활·무료 부활·영혼석·승급·마법부여·개명)·아카데미(전직·스킬북)를 웹 코드 정답과 비교
##              (tests/fixtures/outer_4b2_web.json ← node tools/outer-4b2-expect.js, 같은 mulberry32 씨앗·시각 → 저장값·난수 호출 수까지).
##              웹과 다르게 한 곳(활성 파티 제물 제외 · 제물 장비 빼기 · 전직 미리보기 = 결과)은 정답을 그만큼 고쳐 비교
##  2) codex  : 도감 4탭(장비 거르기 8개 · 직업 상세 12개)·가이드 7탭의 글 조각이 웹 HTML 글 조각과 순서까지 같음 (ko · en, 진짜 언어 팩) · 없는 키 조회 0
##  3) v8     : Js.v8_sort = node(V8) Array.prototype.sort (64~700개 · 난수/일관 비교 함수 · 비교 호출 수)
##  4) resume : 이어하기 저장 판 확인(저장 형식·데이터 해시·게임 버전·state.format) · md5(cfg 포함) · 엔진 load_state 거절 · 전투 장면 방어 · 로비 안내·포기 흐름
##  5) screens: 진짜 장면 — 로비 → 성소 → 아카데미 → 도감 → 가이드 → 설정 → 크레딧 → 라이선스, 단추로 부활·승급·개명·마법부여·전직·스킬북·검색·상세 창·링크·키보드
##  6) clicks : 같은 프레임 연타 (진짜 입력 push_input) — 부활·무료 부활·합치기·승급·개명·마법부여·전직·스킬북·포기가 한 번만
##  7) weird  : 이상한 세이브 → 새 화면·창 모두 스크립트 오류 0, 정상 세이브는 다듬기에서 바이트 그대로 · 웹 왕복(--roundtrip)
##  8) lang   : 6개 언어 × 1280×720 · 1920×1080 × 새 화면·창 — 넘침 0 · 두부 0
##  9) nosoon : '준비 중' 안내가 남지 않음 (로비·아래 탭·설정이 모두 진짜 화면으로)
##  Godot 오류(Logger 로 셈) 0 이어야 통과. 저장은 user://test_outer_4b2_save.json (진짜 세이브는 건드리지 않음)

const JsonX := preload("res://scripts/core/json_exact.gd")
const JsonNorm := preload("res://scripts/core/json_norm.gd")
const FontsT := preload("res://scripts/core/fonts.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")
const SaveStore := preload("res://scripts/logic/save_store.gd")
const StoreCtx := preload("res://scripts/logic/store_ctx.gd")
const Js := preload("res://scripts/logic/js.gd")
const Rng := preload("res://scripts/logic/rng.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const Sanc := preload("res://scripts/logic/sanctuary_rules.gd")
const Acad := preload("res://scripts/logic/academy_rules.gd")
const CodexRules := preload("res://scripts/logic/codex_rules.gd")
const ResumeRules := preload("res://scripts/logic/resume_rules.gd")
const SaveSanitize := preload("res://scripts/logic/save_sanitize.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")
const BattleEngine := preload("res://scripts/logic/battle/battle_engine.gd")
const SAVE := "user://test_outer_4b2_save.json"
const LANGS := ["ko", "en", "es", "ja", "zh-CN", "zh-TW"]
const BATTLE := "res://scenes/battle/battle.tscn"

var _fails: Array = []
var _passes := 0
var _counter: ErrCounter
var store: Node
var i18n: Node
var router: Node
var D: Dictionary
var _only: Array = []
var _stats: Dictionary = {}
var fx: Dictionary
var NOW := 0.0


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


func _stat(k: String, n: int = 1) -> void:
	_stats[k] = int(_stats.get(k, 0)) + n


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var oi := args.find("--only")
	if oi >= 0 and oi + 1 < args.size():
		_only = Array(args[oi + 1].split(","))
	store = root.get_node("Store")
	i18n = root.get_node("I18n")
	router = root.get_node("Router")
	D = Ctx.globals_from_db(root.get_node("DataDB"))
	store.call("use_path", SAVE)
	store.call("clear")
	i18n.call("reload")
	root.size = Vector2i(1280, 720)
	var p: Variant = JsonX.parse(FileAccess.get_file_as_string("res://tests/fixtures/outer_4b2_web.json"))
	_check(p is Dictionary, "웹 정답 파일 읽음")
	if not (p is Dictionary):
		quit(1)
		return
	fx = p
	NOW = float(fx["now"])
	if _want("rules"):
		print("── 1) 성소·아카데미 규칙 ↔ 웹 정답 ──")
		_rules_sanctuary()
		_rules_academy()
	if _want("codex"):
		print("── 2) 도감·가이드 글 ↔ 웹 HTML ──")
		_codex()
	if _want("v8"):
		print("── 3) V8 정렬 64개 이상 ──")
		_v8()
	if _want("resume"):
		print("── 4) 이어하기 판 확인 · 포기 ──")
		await _resume()
	if _want("screens"):
		print("── 5) 진짜 장면 ──")
		await _screens()
	if _want("clicks"):
		print("── 6) 같은 프레임 연타 ──")
		await _clicks()
	if _want("weird"):
		print("── 7) 이상한 세이브 · 왕복 ──")
		await _weird()
	if _want("lang"):
		print("── 8) 6개 언어 넘침·두부 ──")
		await _langs()
	if _want("nosoon"):
		print("── 9) '준비 중' 없음 ──")
		_nosoon()
	if current_scene != null:
		change_scene_to_file("res://scenes/boot.tscn")
		await _frames(3)
		current_scene.queue_free()
		await _frames(3)
	ResumeRules.stamp_override = {}
	(load("res://scripts/battle/icons.gd") as GDScript).set("_inst", null)
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

func _mem_ctx(seed_store: Dictionary, seed: int = 4242) -> Object:
	var ss := SaveStore.new()
	for k: String in seed_store.keys():
		var v: Variant = seed_store[k]
		if typeof(v) == TYPE_STRING:
			ss.set_str(k, v)
		else:
			ss.set_json(k, JsonNorm.normalize_store(k, Js.deep(v)))
	var c := Ctx.new(D, seed, ss)
	var now := NOW
	c.clock = func() -> float: return now
	return c


## 저장소 전체 (웹 dumpStore 처럼 글로 저장된 값도 JSON 이면 읽음 — 예: game_sanc_ad_cooldown "1791990000000")
func _dump(c: Object) -> Dictionary:
	var o: Dictionary = {}
	for k: String in c.store.keys():
		var v: Variant = c.store.get_json(k)
		if typeof(v) == TYPE_STRING:
			var p: Array = JsonX.parse_ex(str(v))
			if p[0]:
				v = p[1]
		o[k] = v
	return o


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


func _diff(a: Variant, b: Variant, p: String = "") -> String:
	if _same(a, b):
		return ""
	if a is Dictionary and b is Dictionary:
		for k: Variant in (a as Dictionary).keys():
			if not (b as Dictionary).has(k):
				return "%s.%s: godot 에만" % [p, k]
			var d := _diff(a[k], b[k], "%s.%s" % [p, k])
			if d != "":
				return d
		for k2: Variant in (b as Dictionary).keys():
			if not (a as Dictionary).has(k2):
				return "%s.%s: 웹에만 (%s)" % [p, k2, JsonX.stringify(b[k2]).substr(0, 80)]
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return "%s: 길이 %d ≠ %d" % [p, (a as Array).size(), (b as Array).size()]
		for i in (a as Array).size():
			var d2 := _diff(a[i], b[i], "%s[%d]" % [p, i])
			if d2 != "":
				return d2
	return "%s: %s ≠ 웹 %s" % [p, JsonX.stringify(a).substr(0, 160), JsonX.stringify(b).substr(0, 160)]


func _cmp(what: String, mine: Variant, web: Variant) -> bool:
	var d := _diff(mine, web)
	if d != "":
		print("    [%s] %s" % [what, d])
	return d == ""


func _uids(arr: Array) -> Array:
	var out: Array = []
	for ch: Variant in arr:
		out.append(int(ch["uid"]))
	return out


func _re_all(pat: String, s: String) -> Array:
	var out: Array = []
	for m: RegExMatch in RegEx.create_from_string(pat).search_all(s):
		out.append(m)
	return out


# ═══════════ 1) 성소·아카데미 규칙 ═══════════

func _rules_sanctuary() -> void:
	var L: Dictionary = fx["sanctuary"][0]
	var c := _mem_ctx(L["store"], int(L["seed"]))
	var m: Dictionary = L["model"]
	# 부활 목록: 순서(죽은 시각 최근 순) · 비용 · 소환수·지휘관 제외
	var ops: Dictionary = fx["sanctuary"][1]
	var web_order: Array = ops["steps"][0]["order"]
	_check(_cmp("부활 순서", _uids(Sanc.dead_list(c)), web_order), "부활 목록 순서 = 웹 %s (죽은 소환수 9 빠짐)" % str(web_order))
	var costs: Array = []
	var res_html := ""
	for cd: Dictionary in m["resurrect"]["cards"]:
		res_html += str(cd["html"])
	for mm: RegExMatch in _re_all("resurrect_button\\{\"cost\":(\\d+)\\}", res_html):
		costs.append(int(mm.get_string(1)))
	var mine: Array = []
	for ch: Dictionary in Sanc.dead_list(c):
		mine.append(int(Sanc.revive_cost(c, ch)))
	_check(_cmp("부활 비용", mine, costs), "부활 비용 = 웹 %s" % str(costs))
	# 등급
	var grades: Dictionary = {}
	for ch2: Variant in Profile.get_roster(c)["chars"]:
		grades[str(int(ch2["uid"]))] = Profile.pot_grade(c, ch2)
	_check(_cmp("등급", grades, m["grades"]), "잠재력 등급 18명 = 웹")
	# 승급 카드: 순서 · 등급 · 단추 켜짐 · 영혼석 줄
	var web_cards: Array = []
	for card: Dictionary in m["promote"]:
		if str(card["cls"]) != "promote-card":
			continue
		var h := str(card["html"])
		var um := RegEx.create_from_string(">C(\\d+) <").search(h)
		var sm := RegEx.create_from_string("soul\\.need\\{\"have\":(\\d+),\"need\":(\\d+)\\}").search(h)
		web_cards.append({"uid": int(um.get_string(1)) if um != null else -1, "grade": RegEx.create_from_string("class=\"promote-grade\"[^>]*>([A-Z])<").search(h).get_string(1),
			"can": not h.contains("promote-btn disabled"), "soul": [int(sm.get_string(1)), int(sm.get_string(2))] if sm != null else []})
	var my_cards: Array = []
	for ch3: Dictionary in Sanc.promotable(c):
		var st := Sanc.promote_state(c, ch3)
		my_cards.append({"uid": int(ch3["uid"]), "grade": st["grade"], "can": st["can"], "soul": [int(st["soul_have"]), int(st["soul_need"])] if float(st["soul_need"]) > 0.0 else []})
	# 웹은 활성 파티 클랜원도 제물로 쳐서(옛 키) '할 수 있음' 이 다를 수 있음 → 카드의 can 은 Godot 제물 목록으로 다시 계산해 비교
	var web_cards2: Array = []
	var party := PartyRules.get_active_party(c)
	for wc: Dictionary in web_cards:
		var w2 := wc.duplicate()
		var sac_web: Array = m["sacrifices"].get(str(wc["uid"]), [])
		var sac_left := sac_web.filter(func(pr: Array) -> bool: return Js.index_of(party, int(pr[0])) < 0)
		var soul_ok := (wc["soul"] as Array).is_empty() or int(wc["soul"][0]) >= int(wc["soul"][1])
		w2["can"] = not sac_left.is_empty() and soul_ok
		web_cards2.append(w2)
	_check(_cmp("승급 카드", my_cards, web_cards2), "승급 카드 %d개: 순서·등급·영혼석 줄 = 웹, 단추 = 웹(활성 파티 제외 반영)" % my_cards.size())
	# 제물 후보: 웹(옛 키라 파티 무시) − 활성 파티
	var sac_ok := true
	var diff_n := 0
	for uid_s: String in (m["sacrifices"] as Dictionary).keys():
		var tgt: Variant = Profile.get_char(c, int(uid_s))
		var want: Array = []
		for pr2: Array in m["sacrifices"][uid_s]:
			if Js.index_of(party, int(pr2[0])) < 0:
				want.append([int(pr2[0]), int(pr2[1])])
			else:
				diff_n += 1
		var got: Array = []
		var tg := Profile.pot_grade(c, tgt)
		for s: Dictionary in Sanc.sacrifices(c, tgt):
			got.append([int(s["uid"]), Sanc.sacrifice_points(c, Profile.pot_grade(c, s), tg)])
		if not _cmp("제물 " + uid_s, got, want):
			sac_ok = false
	_check(sac_ok, "제물 후보·점수 = 웹 (웹은 옛 키 game_party 라 활성 파티도 후보 — Godot 은 뺌: %d건)" % diff_n)
	_check(diff_n > 0, "활성 파티 제외가 실제로 시험됨 (%d건)" % diff_n)
	_check(_cmp("영혼석 직업", Sanc.soul_owned(c), m["owned"]), "영혼석 보관함 직업 순서 = 웹 %s" % str(m["owned"]))
	var box: String = str(m["promote"][0]["html"])
	var box_ok := true
	for cls: String in Sanc.soul_owned(c):
		var want_s := "<b>%d</b><span>%d/%d</span>" % [int(Sanc.soul_stones(c, cls)), int(Sanc.soul_frags(c, cls)), int(D["SOUL"]["fragsPerStone"])]
		var can_c := Sanc.soul_frags(c, cls) >= float(D["SOUL"]["fragsPerStone"])
		box_ok = box_ok and box.contains(want_s) and box.contains("data-cls=\"%s\"" % cls) == can_c
	_check(box_ok, "영혼석 칸 숫자·합치기 단추 = 웹")
	# 개명 목록 순서
	var ren_web: Array = []
	for h2: String in m["rename"]:
		var um2 := RegEx.create_from_string(">C(\\d+) <").search(h2)
		ren_web.append(int(um2.get_string(1)) if um2 != null else -1)
	_check(_cmp("개명 목록", _uids(Sanc.alive(c)), ren_web), "개명 목록 순서 = 웹 (%d명)" % ren_web.size())
	# 마법부여: 장비 순서 · 낀 클랜원 · 지금 마법부여 · 룬 단추 켜짐
	var enc_web: Array = []
	var enc_mine: Array = []
	for e: Dictionary in m["enchant"]:
		if e["eid"] == null:
			continue
		var h3 := str(e["html"])
		var opts: Array = []
		for om: RegExMatch in _re_all("<button class=\"enc-opt( on)?\" data-k=\"([a-z]+)\"( disabled)?", h3):
			opts.append([om.get_string(2), om.get_string(1) != "", om.get_string(3) == ""])
		var own := RegEx.create_from_string("👤 C(\\d+)").search(h3)
		enc_web.append({"eid": e["eid"], "owner": int(own.get_string(1)) if own != null else null, "opts": opts})
	for it: Dictionary in Sanc.enchant_items(c):
		var ow: Variant = Sanc.owner_of(c, it)
		var opts2: Array = []
		for cat: String in ["def", "atk"]:
			for k: String in Gear_kinds(cat):
				var on := Js.same(it.get(D["ENCHANT_FIELD"][cat]), k)
				opts2.append([k, on, Sanc.rune_count(c, k) > 0 and not on])
		enc_mine.append({"eid": it["eid"], "owner": int(ow["uid"]) if ow != null else null, "opts": opts2})
	_check(_cmp("마법부여 목록", enc_mine, enc_web), "마법부여 장비 %d개: 순서(낀 것 → 등급)·낀 클랜원·룬 단추 켜짐 = 웹" % enc_mine.size())
	_check(_cmp("목록만", _dump(c), L["after"]) and c.rng.calls == int(L["calls"]), "목록을 그려도 저장값·난수 그대로 (웹과 같음)")
	_rules_sanc_ops()
	_rules_sanc_poor()


func Gear_kinds(cat: String) -> Array:
	var out: Array = []
	for k: String in (D["ENCHANTS"] as Dictionary).keys():
		if D["ENCHANTS"][k]["cat"] == cat:
			out.append(k)
	return out


func _rules_sanc_ops() -> void:
	var O: Dictionary = fx["sanctuary"][1]
	var c := _mem_ctx(O["store"], int(O["seed"]))
	var oks: Array = []
	var sac_all: Array = []
	for st: Dictionary in O["steps"]:
		match str(st["op"]):
			"revive":
				oks.append(Sanc.revive(c, int(st["uid"])))
			"ad":
				oks.append(((Sanc.ad_remain(c) <= 0.0) == bool(st["ready"])) and Sanc.ad_revive(c, int(st["uid"])))
			"ad_again":
				oks.append(Sanc.ad_remain(c) > 0.0 and not bool(st["ready"]) and str(st["html"]).contains("\"minutes\":%d" % Sanc.ad_minutes(c)) and not Sanc.ad_revive(c, 31))
			"combine":
				oks.append(Sanc.soul_combine(c, str(st["cls"])) == 2)
			"promote":
				var sel: Array = []
				for u: Variant in st["sac"]:
					sel.append(int(u))
				sac_all.append_array(sel)
				var c0: int = c.rng.calls
				var pv := Sanc.promote_preview(c, int(st["target"]), sel)
				var r := Sanc.promote(c, int(st["target"]), sel)
				var al := str(st["alert"])
				var ch: Dictionary = r.get("ch", {})
				oks.append(bool(r["ok"]) and not pv.is_empty() and c.rng.calls == int(st["callsAfter"]) and c0 == int(st["callsBefore"])
					and al.contains("HP %s / ATK %s / DEF %s" % [Js.num(ch.get("hp")), Js.num(ch.get("atk")), Js.num(ch.get("def"))].map(func(x: float) -> String: return Num_fmt(x))))
			"promote_nosoul":
				var r2 := Sanc.promote(c, int(st["target"]), [21])
				oks.append(not bool(r2["ok"]))
			"enchant":
				var it: Variant = null
				for x: Dictionary in Sanc.enchant_items(c):
					if x["eid"] == st["eid"]:
						it = x
				var k := str(st["k"])
				var on := Js.same(it.get(D["ENCHANT_FIELD"][D["ENCHANTS"][k]["cat"]]), k)
				var enabled := Sanc.rune_count(c, k) > 0 and not on
				if enabled != bool(st["clickable"]):
					oks.append(false)
				elif enabled:
					oks.append(typeof(Sanc.rune_apply(c, st["eid"], k)) == TYPE_BOOL)
				else:
					oks.append(true)
			"apply_codes":
				var codes: Array = [Sanc.rune_apply(c, "nope", "fire"), Sanc.rune_apply(c, O["store"]["game_inventory"][4]["eid"], "frost")]
				oks.append(_same(codes, st["codes"]))
			"rename":
				oks.append(Sanc.rename(c, int(st["uid"]), str(st["v"])) != null)
	var bad_steps: Array = []
	for i in oks.size():
		if not oks[i]:
			bad_steps.append("%d:%s" % [i, O["steps"][i]["op"]])
	_check(bad_steps.is_empty(), "성소 단계 %d개 결과 = 웹 (부활 · 무료 부활 · 대기 %d분 · 합치기 · 승급 2번(미리보기 난수 포함) · 영혼석 부족 · 마법부여 5 · 결과 코드 · 개명 3) %s" % [oks.size(), 30, str(bad_steps)])
	# 저장값: 웹과 같음 — 단, Godot 은 제물이 끼던 장비를 뺌 (웹은 없는 클랜원이 낀 채 남음)
	var want: Dictionary = Js.deep(O["after"])
	var freed := 0
	for it2: Variant in want["game_inventory"]:
		if it2 is Dictionary and it2.get("equipped") != null and Js.index_of(sac_all, int(it2["equipped"])) >= 0:
			it2["equipped"] = null
			freed += 1
	_check(_cmp("성소 저장값", _dump(c), want), "성소 차례 뒤 저장소 전체 = 웹 (제물 장비 빼기 %d개만 다름)" % freed)
	_check(freed > 0, "제물 장비 빼기가 실제로 시험됨 (%d개)" % freed)
	_check(c.rng.calls == int(O["calls"]), "난수 호출 수 = 웹 (%d)" % int(O["calls"]))
	_stat("rules.sanctuary_steps", oks.size())


func Num_fmt(v: Variant) -> String:
	return (load("res://scripts/core/num.gd") as GDScript).call("fmt", v)


func _rules_sanc_poor() -> void:
	var P: Dictionary = fx["sanctuary"][2]
	var c := _mem_ctx(P["store"], int(P["seed"]))
	var dead := Sanc.dead_list(c)
	var ok1 := not Sanc.revive(c, dead[0]["uid"])
	var ok2 := Sanc.ad_minutes(c) == 20 and str(P["ad"]).contains("\"minutes\":20") and str(P["ad"]).contains("disabled")
	var ok3 := Sanc.gold(c) < float(D["ENCHANT_FEE"]) and str(Sanc.rune_apply(c, P["store"]["game_inventory"][2]["eid"], "fire")) == "no_gold"
	_check(ok1 and ok2 and ok3, "골드 부족 부활 막힘 · 무료 부활 대기 20분(저장 시각) · 마법부여 골드 부족 = 웹")
	_check(_cmp("골드 부족 저장값", _dump(c), P["after"]) and c.rng.calls == int(P["calls"]), "골드 부족이면 저장값 그대로 = 웹")
	var wa: Array = P["alerts"]
	_check(wa.size() == 1 and str(wa[0]).begins_with("enchant.no_gold"), "웹도 마법부여 골드 부족 알림 하나")


func _rules_academy() -> void:
	var A: Dictionary = fx["academy"][0]
	var c := _mem_ctx(A["store"], int(A["seed"]))
	var nov: Array = []
	for h: String in A["cards"]:
		var um := RegEx.create_from_string(">C(\\d+) <").search(h)
		nov.append(int(um.get_string(1)) if um != null else -1)
	_check(_cmp("노비스", _uids(Acad.novices(c)), nov), "전직 노비스 목록 = 웹 %s" % str(nov))
	var sc_web: Array = []
	for mm: RegExMatch in _re_all("data-idx=\"(\\d+)\" data-cls=\"([a-z]+)\"", str(A["modal"])):
		sc_web.append([int(mm.get_string(1)), mm.get_string(2)])
	var sc_mine: Array = []
	for s: Dictionary in Acad.usable_scrolls(c):
		sc_mine.append([int(s["idx"]), str(s["item"]["scrollCls"])])
	_check(_cmp("전직서", sc_mine, sc_web), "전직서 고르기 창 목록 = 웹 (모르는 직업 전직서는 뺌) %s" % str(sc_web))
	var ch6: Variant = Profile.get_char(c, 6)
	var pv := Acad.preview_kept(c, ch6, "archer")
	var w0: Dictionary = A["previews"][0]["r"]
	var pv_cmp := {"hp": pv["hp"], "atk": pv["atk"], "def": pv["def"], "move": pv["move"], "range": pv["range"], "pot": pv["pot"]}
	_check(_cmp("전직 미리보기", pv_cmp, w0) and c.rng.calls == int(A["previews"][0]["calls"]), "전직 미리보기(확인 창 숫자) = 웹 · 난수 %d번" % int(A["previews"][0]["calls"]))
	# (4b-2 디렉터 결정) 보관: 다시 열어도 같은 값 · 난수 더 쓰지 않음
	var calls1: int = c.rng.calls
	var same_n := 0
	for i in 5:
		if _same(Acad.preview_kept(c, Profile.get_char(c, 6), "archer"), pv):
			same_n += 1
	var kept: Variant = c.store.get_json(Acad.PREVIEW_KEY)
	_check(same_n == 5 and c.rng.calls == calls1 and kept is Dictionary and (kept as Dictionary).has("6") and _same(kept["6"]["cls"]["archer"], pv),
		"전직 미리보기 보관 (gd_class_preview): 5번 다시 열어도 같은 값 · 난수 0번 더")
	var pvm := Acad.preview_kept(c, Profile.get_char(c, 6), "mage")
	_check(not pvm.is_empty() and c.rng.calls > calls1 and _same(Acad.preview_kept(c, Profile.get_char(c, 6), "archer"), pv), "다른 직업은 따로 한 번 굴림 · 궁수 값은 그대로")
	_rules_preview_invalid()
	var calls_before_change: int = c.rng.calls
	var r := Acad.change_class(c, 6, pv, int(sc_web[0][0]))
	# Godot: 미리보기 그대로 전직 → 웹 저장값(두 번째 굴림)의 그 클랜원 능력치·잠재력만 미리보기로 바꿔 비교
	_check(not c.store.has(Acad.PREVIEW_KEY), "전직 실행 → 그 클랜원 미리보기 지움 (키가 비어 지워짐)")
	var want1: Dictionary = Js.deep(A["after1"])
	for ch: Dictionary in want1["game_roster"]["chars"]:
		if int(ch["uid"]) == 6:
			for k: String in ["hp", "atk", "def", "pot"]:
				ch[k] = Js.deep(w0[k])
	_check(bool(r["ok"]) and _cmp("전직 뒤", _dump(c), want1), "전직 뒤 저장소 = 웹 (능력치·잠재력은 확인 창 숫자 그대로 — 웹은 다시 굴려 달라짐)")
	_check(c.rng.calls == calls_before_change, "전직 실행은 난수를 쓰지 않음 (확인 창의 미리보기 그대로 — 웹은 잠재력을 한 벌 더 굴림)")
	var books_web: Array = []
	for h2: String in A["books"]:
		var sm := RegEx.create_from_string("skills\\.([a-z_]+) <span class=\"sb-cls-tag\">classes\\.([a-z]+)<").search(h2)
		books_web.append([sm.get_string(1) if sm != null else "", sm.get_string(2) if sm != null else "", not h2.contains("game-btn--blue disabled")])
	var books_mine: Array = []
	for b: Dictionary in Acad.books(c):
		books_mine.append([str(b["item"]["id"]), str(b["item"]["cls"]), bool(b["has_target"])])
	_check(_cmp("스킬북", books_mine, books_web), "스킬북 목록·사용 단추 = 웹 %s" % str(books_web))
	var t1 := _uids(Acad.targets(c, {"id": "mage_freeze", "cls": "mage"}))
	var r1 := Acad.use_book(c, _book_idx(c, "mage_freeze"), 4, {"id": "mage_freeze", "cls": "mage"})
	var t2 := _uids(Acad.targets(c, {"id": "warrior_powersmash", "cls": "warrior"}))
	var r2 := Acad.use_book(c, _book_idx(c, "warrior_powersmash"), 1, {"id": "warrior_powersmash", "cls": "warrior"})
	_check(_cmp("대상", [t1, t2], A["targets"]), "스킬북 대상 = 웹 %s" % str(A["targets"]))
	_check(bool(r1["new_learn"]) and int(r1["lv"]) == 1 and not bool(r2["new_learn"]) and int(r2["lv"]) == 2, "스킬북: 습득형 0 → 1(습득) · 기본 스킬 1 → 2 = 웹 알림")
	var want2: Dictionary = Js.deep(A["after"])
	for ch2: Dictionary in want2["game_roster"]["chars"]:
		if int(ch2["uid"]) == 6:
			for k2: String in ["hp", "atk", "def", "pot"]:
				ch2[k2] = Js.deep(w0[k2])
	_check(_cmp("스킬북 뒤", _dump(c), want2), "스킬북 두 번 뒤 저장소 = 웹")
	var N: Dictionary = fx["academy"][1]
	var c2 := _mem_ctx(N["store"], int(N["seed"]))
	_check(Acad.usable_scrolls(c2).is_empty() and str(N["card"]).contains("academy.buy_scroll") and _same(N["hrefs"], ["shop.html?tab=scroll"]), "전직서 없음 → '전직서 구매' → 상점 전직서 탭 (웹 shop.html?tab=scroll)")


## 미리보기 무효 규칙: 레벨·잠재력이 바뀌면 다시 굴림, 클랜원이 없어지거나 노비스가 아니면 항목 지움, 이상한 값은 sanitize
func _rules_preview_invalid() -> void:
	var c := _mem_ctx(fx["academy"][0]["store"], 77)
	var a := Acad.preview_kept(c, Profile.get_char(c, 8), "archer")
	var r := Profile.get_roster(c)
	for ch: Dictionary in r["chars"]:
		if int(ch["uid"]) == 8:
			ch["lv"] = 16
	Profile.save_roster(c, r)
	var b := Acad.preview_kept(c, Profile.get_char(c, 8), "archer")
	var kept: Dictionary = c.store.get_json(Acad.PREVIEW_KEY)
	var ok1: bool = not _same(a, b) and int(kept["8"]["fp"]["lv"]) == 16
	Acad.preview_kept(c, Profile.get_char(c, 6), "mage")
	r = Profile.get_roster(c)
	r["chars"] = (r["chars"] as Array).filter(func(x: Dictionary) -> bool: return int(x["uid"]) != 8)
	Profile.save_roster(c, r)
	Acad.preview_kept(c, Profile.get_char(c, 6), "mage")
	kept = c.store.get_json(Acad.PREVIEW_KEY)
	var ok2: bool = not kept.has("8") and kept.has("6")
	_check(ok1 and ok2, "미리보기 무효: 레벨이 바뀌면 다시 굴림 · 클랜원이 없어지면 항목 지움")
	# 이상한 값 → sanitize
	var bad_cases: Array = ["5", "[1]", JsonX.stringify({"x": 1, "6": {"fp": 3}, "8": {"fp": {"lv": 15}, "cls": {"archer": {"hp": "x"}, "nope": {}, "mage": {"hp": 1, "atk": 2, "def": 3, "move": 3, "range": 4, "pot": {"hp": 1, "atk": 1, "def": 1}, "grade": "S", "cls": "mage"}}}})]
	var san_ok := true
	for raw: String in bad_cases:
		var c2 := _mem_ctx(fx["academy"][0]["store"], 5)
		c2.store.set_json(Acad.PREVIEW_KEY, JsonX.parse(raw))   # 메모리 저장소는 set_str 을 읽지 않으므로 읽은 값으로 (진짜 Store 는 글 → 같은 값)
		SaveSanitize.sanitize(c2)
		var v: Variant = c2.store.get_json(Acad.PREVIEW_KEY)
		if raw.begins_with("{"):
			san_ok = san_ok and v is Dictionary and (v as Dictionary).keys() == ["8"] and (v["8"]["cls"] as Dictionary).keys() == ["mage"]
		else:
			san_ok = san_ok and v == null
		var pv2 := Acad.preview_kept(c2, Profile.get_char(c2, 6), "archer")
		if not san_ok or pv2.is_empty():
			print("    sanitize 미리보기 '%s' → %s · pv %s" % [raw.substr(0, 30), JsonX.stringify(v).substr(0, 200), str(pv2.is_empty())])
		san_ok = san_ok and not pv2.is_empty()
	var c3 := _mem_ctx(fx["academy"][0]["store"], 5)
	Acad.preview_kept(c3, Profile.get_char(c3, 6), "archer")
	var before := str(c3.store.get_str(Acad.PREVIEW_KEY))
	var ch3 := SaveSanitize.sanitize(c3)
	if ch3.has(Acad.PREVIEW_KEY) or str(c3.store.get_str(Acad.PREVIEW_KEY)) != before:
		print("    정상 미리보기 바뀜: %s → %s" % [before.substr(0, 120), str(c3.store.get_str(Acad.PREVIEW_KEY)).substr(0, 120)])
	_check(san_ok and not ch3.has(Acad.PREVIEW_KEY) and str(c3.store.get_str(Acad.PREVIEW_KEY)) == before, "미리보기 보관함 이상한 값 → sanitize 가 지우거나 틀린 칸만 뺌 · 정상 값은 그대로")


func _book_idx(c: Object, id: String) -> int:
	for b: Dictionary in Acad.books(c):
		if b["item"]["id"] == id:
			return int(b["idx"])
	return -1


# ═══════════ 2) 도감·가이드 ═══════════

func _codex() -> void:
	var cx: Dictionary = fx["codex"]
	var total := [0]
	for lang: String in ["ko", "en"]:
		i18n.call("_apply", lang)
		var W: Dictionary = cx[lang]
		var c := _mem_ctx({})
		var R := CodexRules.new(c, func(k: String, p: Dictionary) -> String: return i18n.call("t", k, p), func(k: String) -> bool: return bool(i18n.call("has_key", k)))
		var bad: Array = []
		var cmp := func(what: String, mine: Array, web: Array) -> void:
			total[0] += web.size()
			if not _same(mine, web):
				var at := 0
				while at < mini(mine.size(), web.size()) and _same(mine[at], web[at]):
					at += 1
				bad.append("%s %s: %d번째 '%s' ≠ 웹 '%s' (길이 %d/%d)" % [lang, what, at, str(mine[at]) if at < mine.size() else "(끝)", str(web[at]) if at < web.size() else "(끝)", mine.size(), web.size()])
		for tab: String in ["cls", "cons", "stage"]:
			cmp.call("도감." + tab, CodexRules.tokens(R.comp_panel(tab)), W["comp"][tab])
		for f: String in CodexRules.GEAR_FILTERS:
			cmp.call("도감.장비." + f, CodexRules.tokens(R.comp_gear(f)), W["comp"]["gear"][f])
		for cls: String in CodexRules.PLAYER_CLASSES:
			cmp.call("도감.직업창." + cls, CodexRules.tokens(R.comp_class_sheet(cls)), W["comp"]["sheets"][cls])
		var hero: Array = [R.T("c.title"), R.T("c.sub")]
		for st: Array in R.comp_hero_stats():
			hero.append(str(st[0]))
			hero.append(str(st[1]))
		cmp.call("도감.머리", hero, W["comp"]["hero"])
		cmp.call("도감.탭", CodexRules.COMP_TABS.map(func(k: String) -> String: return R.T("c.tab_" + k)), W["comp"]["tabs"])
		cmp.call("도감.아래", CodexRules.rich_tokens(R.T("c.foot")), W["comp"]["foot"])
		cmp.call("도감.제목", [R.tt("nav.compendium", R.T("c.title"))], [W["comp"]["title"]])
		for gt: String in CodexRules.GUIDE_TABS:
			cmp.call("가이드." + gt, CodexRules.tokens(R.guide_panel(gt)), W["guide"]["panels"][gt])
		cmp.call("가이드.아래", CodexRules.rich_tokens(R.T("g.foot")), W["guide"]["foot"])
		cmp.call("가이드.탭", CodexRules.GUIDE_TABS.map(func(k: String) -> String: return R.T("g.tab_" + k)), W["guide"]["tabs"])
		cmp.call("가이드.머리", [R.T("g.title"), R.T("g.sub"), "100", R.T("c.st_stages"), "5", R.T("c.st_party"), "12", R.T("c.st_classes")], W["guide"]["hero"])
		for b: String in bad.slice(0, 12):
			print("    " + b)
		_check(bad.is_empty(), "[%s] 도감 4탭 · 장비 거르기 8 · 직업 창 12 · 가이드 7탭 · 머리·탭·아래 글 = 웹 HTML 글 조각 (문제 %d)" % [lang, bad.size()])
		_check(R.missing.is_empty(), "[%s] 도감·가이드가 없는 키를 조회하지 않음 (웹은 %d개: gear.item.* %d · maps.* %d) %s" % [lang, (W["missing"] as Array).size(),
			(W["missing"] as Array).filter(func(k: String) -> bool: return k.begins_with("gear.item.")).size(), (W["missing"] as Array).filter(func(k: String) -> bool: return k.begins_with("maps.")).size(),
			str(R.missing.slice(0, 5))])
	_check((fx["codex"]["ko"]["missing"] as Array).size() == 29, "웹의 '키 그대로' 조회 29개를 정답 파일이 기록 (gear.item 21 · maps 8)")
	_stat("codex.tokens", total[0])
	i18n.call("_apply", "ko")


# ═══════════ 3) V8 정렬 ═══════════

func _v8() -> void:
	var bad: Array = []
	for cs: Dictionary in fx["v8"]:
		var kind := str(cs["kind"])
		var r := Rng.new(int(cs["seed"]))
		var calls := [0]
		var cmp: Callable
		if kind == "rand":
			cmp = func(_a: Variant, _b: Variant) -> float:
				calls[0] += 1
				return r.next("") - 0.5
		elif kind == "desc":
			cmp = func(a: Variant, b: Variant) -> float:
				calls[0] += 1
				return float(b) - float(a)
		else:
			cmp = func(a: Variant, b: Variant) -> float:
				calls[0] += 1
				return float(a) - float(b)
		var out := Js.v8_sort(cs["input"], cmp)
		if not _same(out, cs["out"]) or calls[0] != int(cs["calls"]):
			bad.append("%d %s (비교 %d/%d)" % [int(cs["n"]), kind, calls[0], int(cs["calls"])])
	_check(bad.is_empty(), "Js.v8_sort = V8 (64~700개, 난수·오름·내림·섞임·같은 값 %d가지 — 결과·비교 호출 수) %s" % [(fx["v8"] as Array).size(), str(bad.slice(0, 5))])
	# 비교 함수가 일관되지 않아도(난수) 같은 씨앗이면 같은 결과, 오류 없이 (2000개)
	var a: Array = range(2000)
	var r1 := Rng.new(9)
	var r2 := Rng.new(9)
	var o1 := Js.v8_sort(a, func(_x: Variant, _y: Variant) -> float: return r1.next("") - 0.5)
	var o2 := Js.v8_sort(a, func(_x: Variant, _y: Variant) -> float: return r2.next("") - 0.5)
	var sorted_ok := o1.size() == 2000 and _same(o1, o2)
	var cp := o1.duplicate()
	cp.sort()
	_check(sorted_ok and _same(cp, a), "난수 비교 함수 2000개: 결정적 · 원소 그대로 (빠지거나 겹치지 않음)")
	_stat("v8.cases", (fx["v8"] as Array).size())


# ═══════════ 4) 이어하기 판 확인 · 포기 ═══════════

func _rc() -> Object:
	return Ctx.new(D, 1, StoreCtx.new(store))


func _store_battle_cfg(name: String) -> Dictionary:
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	var cfg: Dictionary = BS.call("golden_cfg", name)
	store.call("clear")
	for k: String in (cfg["save"] as Dictionary).keys():
		store.call("set_json", k, cfg["save"][k])
	cfg["save"] = BS.call("store_save", store)
	cfg["source"] = "store"
	cfg["speed"] = 0.0
	cfg["story"] = "off"
	cfg["loading"] = false
	return cfg


## 실제 세이브로 전투를 시작해 첫 입력 대기에서 gd_battle 저장 → cfg
func _make_gd() -> Dictionary:
	var cfg := _store_battle_cfg("balanced_s05")
	var eng := BattleEngine.new(D, int(cfg["seed"]))
	eng.start({"save": cfg["save"], "stage": cfg["stage"], "practice": bool(cfg.get("practice", false)), "inject": [], "maxRounds": 0})
	eng.begin()
	var st := eng.run()
	if st == "input":
		ResumeRules.save_gd(_rc(), cfg, eng.save_text())
	eng.dispose()
	return cfg


func _resume() -> void:
	var router_dry: bool = router.get("dry_run")
	router.set("dry_run", true)
	ResumeRules.stamp_override = {}
	_make_gd()
	var rc := _rc()
	var raw0 := str(store.call("get_str", ResumeRules.KEY))
	_check(ResumeRules.status(rc) == "gd" and ResumeRules.load_gd(rc) != null, "정상 저장 → 'gd' (이어하기)")
	var d0: Dictionary = JsonX.parse(raw0)
	var now := ResumeRules.current_stamp()
	_check(int(d0["format"]) == 2 and str(d0["cfg"]["saveFormat"]) == BattleEngine.SAVE_FORMAT and str(d0["cfg"]["dataHash"]) == str(now["dataHash"]) and str(d0["cfg"]["gameVersion"]) == str(ProjectSettings.get_setting("application/config/version")) and str(now["gameVersion"]) != "",
		"저장에 판 기록: format 2 · 저장 형식 %s · 데이터 해시 %s… · 게임 버전 %s" % [d0["cfg"]["saveFormat"], str(d0["cfg"]["dataHash"]).substr(0, 8), d0["cfg"]["gameVersion"]])
	# md5 = 저장 글 전체 (cfg 포함)
	var cases := {"cfg 연습 모드": raw0.replace("\"practice\":false", "\"practice\":true"), "cfg 씨앗": raw0.replace("\"seed\":%d" % int(d0["cfg"]["seed"]), "\"seed\":%d" % (int(d0["cfg"]["seed"]) + 1)),
		"state 한 글자": raw0.replace("\"turn\":1", "\"turn\":2"), "잘림": raw0.substr(0, raw0.length() - 20), "sum 바꿈": raw0.replace(str(d0["sum"]), "0".repeat(32))}
	var md5_ok := true
	for k: String in cases.keys():
		if str(cases[k]) == raw0:
			md5_ok = false
			print("    바꾸지 못함: " + k)
			continue
		store.call("set_str", ResumeRules.KEY, cases[k])
		var stt := ResumeRules.status(rc)
		if stt != "broken":
			md5_ok = false
			print("    %s → %s" % [k, stt])
	_check(md5_ok, "md5 가 저장 글 전체(cfg 포함)를 덮음: cfg·state 를 고치거나 자르면 'broken' (%d가지)" % cases.size())
	# 판이 다르면 'old'
	var old_ok := true
	for fld: String in ["saveFormat", "dataHash", "gameVersion"]:
		store.call("set_str", ResumeRules.KEY, raw0)
		var ov := now.duplicate()
		ov[fld] = str(ov[fld]) + "-x"
		ResumeRules.stamp_override = ov
		var s2 := ResumeRules.status(rc)
		if s2 != "old" or ResumeRules.load_gd(rc) != null:
			old_ok = false
			print("    %s 다름 → %s" % [fld, s2])
	ResumeRules.stamp_override = {}
	# state.format 이 엔진과 다름 (저장 형식 글자는 같게 두고 state 만)
	var st_old := raw0.replace("\"format\":\"%s\"" % BattleEngine.SAVE_FORMAT, "\"format\":\"deadline15-battle-save/0\"")
	var dd: Dictionary = JsonX.parse(st_old)
	ResumeRules.save_gd(rc, dd["cfg"], JsonX.stringify(dd["state"]))
	var s3 := ResumeRules.status(rc)
	# 4b-1 저장 (format 1, cfg 에 판 없음)
	var f1 := "{\"format\":1,\"cfg\":%s,\"sum\":\"%s\",\"state\":%s}" % [JsonX.stringify({"stage": {"id": 5}, "practice": false, "party": null, "seed": 3}), JsonX.stringify(d0["state"]).md5_text(), JsonX.stringify(d0["state"])]
	store.call("set_str", ResumeRules.KEY, f1)
	var s4 := ResumeRules.status(rc)
	_check(old_ok and s3 == "old" and s4 == "old", "판 확인: 저장 형식·데이터 해시·게임 버전 중 하나라도 다르면 · state.format 이 다르면 · 4b-1 저장(format 1)이면 'old' (%s · %s)" % [s3, s4])
	# 엔진 load_state 가 판이 다른 상태를 받지 않음 (아무것도 바꾸지 않음)
	var eng := BattleEngine.new(D, 1)
	var ok_load := eng.load_state(d0["state"])
	var eng2 := BattleEngine.new(D, 1)
	var bad_state: Dictionary = Js.deep(d0["state"])
	bad_state["format"] = "deadline15-battle-save/0"
	var s_before: Dictionary = eng2.S.duplicate(true)
	var rng_before: Variant = eng2.c.rng.get_state()
	var rej := eng2.load_state(bad_state)
	var rej2 := eng2.load_state({"units": []})
	_check(ok_load and not rej and not rej2 and _same(eng2.S, s_before) and _same(eng2.c.rng.get_state(), rng_before),
		"battle_engine.load_state: 같은 형식만 받음 (다른 형식·형식 없음 → false, 상태·난수 그대로) [%s %s %s]" % [ok_load, rej, rej2])
	eng.dispose()
	eng2.dispose()
	# 전투 장면 방어: 판이 다른 상태로 들어오면 새로 시작하지 않고 저장 지우고 로비로
	store.call("set_str", ResumeRules.KEY, raw0)
	var cfg2 := _store_battle_cfg("balanced_s05")
	store.call("set_str", ResumeRules.KEY, raw0)
	cfg2["resume"] = bad_state
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	BS.set("pending", cfg2)
	router.set("last_request", {})
	var e0 := _counter.errors.size()
	var bt: Node = (load(BATTLE) as PackedScene).instantiate()
	root.add_child(bt)
	await _frames(4)
	_check(bt.get("eng") == null and not store.call("has", ResumeRules.KEY) and (router.get("last_request") as Dictionary).get("name") == "lobby" and _counter.errors.size() == e0,
		"전투 장면: 판이 다른 이어하기 → 저장 지우고 로비로 (오류 0)")
	bt.queue_free()
	await _frames(2)
	# 로비: 'old' → 안내 + 포기
	_make_gd()
	var ov2 := now.duplicate()
	ov2["gameVersion"] = "0.0.1"
	ResumeRules.stamp_override = ov2
	var lb: Node = (load("res://scenes/outer/lobby.tscn") as PackedScene).instantiate()
	root.add_child(lb)
	await _frames(3)
	if lb.get("setup_dialog") != null:
		lb.commander_setup_done()
	_check(lb.resume_status == "old" and lb.resume_btn != null and lb.abandon_btn == null, "로비: 이전 판 전투 → 전투 재개 단추(✕ 포기 단추 없음)")
	lb.press_resume()
	await _frames(2)
	var notice: Node = lb.find_child("ResumeNotice", true, false)
	var lbl_ok: bool = notice != null and (notice.find_child("Scroll", true, false).get_child(0) as Label).text == i18n.call("t", "gd.resume.old_notice")
	_check(lbl_ok, "전투 재개 → '이전 버전의 전투라 이어할 수 없음' 안내 (gd.resume.old_notice) + 포기")
	(lb.find_child("Abandon", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(not store.call("has", ResumeRules.KEY) and lb.resume_btn == null and (router.get("last_request") as Dictionary).get("name") != "battle", "포기 → 저장 지움 · 단추 없어짐 · 전투로 가지 않음")
	lb.queue_free()
	await _frames(2)
	ResumeRules.stamp_override = {}
	# 로비: 정상 'gd' → ✕ 포기 → 확인 창 → 포기 (닫기는 그대로)
	_make_gd()
	lb = (load("res://scenes/outer/lobby.tscn") as PackedScene).instantiate()
	root.add_child(lb)
	await _frames(3)
	if lb.get("setup_dialog") != null:
		lb.commander_setup_done()
	_check(lb.resume_status == "gd" and lb.abandon_btn != null and lb.abandon_btn.is_visible_in_tree(), "로비: 정상 저장 전투 → 전투 재개 단추 + ✕ 포기 단추")
	lb.ask_abandon()
	await _frames(2)
	var conf: Node = lb.find_child("AbandonConfirm", true, false)
	_check(conf != null and (conf.find_child("Scroll", true, false).get_child(0) as Label).text.contains(i18n.call("t", "gd.resume.stage_n", {"n": 5})), "✕ → 확인 창 (스테이지 5 · 포기해도 전투 중 얻은 것은 남음)")
	(lb.find_child("Close", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(store.call("has", ResumeRules.KEY) and lb.resume_btn != null, "확인 창 닫기 → 저장 전투 그대로")
	lb._act_frame = -1
	lb.ask_abandon()
	await _frames(2)
	(lb.find_child("Abandon", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(not store.call("has", ResumeRules.KEY) and lb.resume_btn == null and lb.find_child("AbandonBtn", true, false) == null, "포기 → 저장 지움 · 단추 둘 다 없어짐")
	lb.queue_free()
	await _frames(2)
	# 정상 저장은 그대로 이어하기 (장면까지)
	var cfg3 := _make_gd()
	var gd: Variant = ResumeRules.load_gd(_rc())
	var Flow: GDScript = load("res://scripts/ui/flow.gd")
	var rcfg: Dictionary = Flow.call("resume_cfg", store, gd)
	rcfg["speed"] = 0.0
	rcfg["story"] = "off"
	rcfg["loading"] = false
	BS.set("pending", rcfg)
	e0 = _counter.errors.size()
	var bt2: Node = (load(BATTLE) as PackedScene).instantiate()
	root.add_child(bt2)
	await _frames(4)
	_check(bt2.resumed and bt2.get("eng") != null and _counter.errors.size() == e0 and cfg3.has("stage"), "같은 판 저장 → 전투 장면이 이어하기로 시작 (오류 0)")
	bt2.queue_free()
	await _frames(2)
	router.set("dry_run", router_dry)
	store.call("clear")
	_stat("resume.checks", 12)


# ═══════════ 5) 진짜 장면 ═══════════

func _scene() -> Node:
	return current_scene


func _wait_scene(tail: String, secs: float = 6.0) -> bool:
	return await _until(func() -> bool:
		var sc := current_scene
		return sc != null and sc.get_script() != null and str((sc.get_script() as Script).resource_path).ends_with(tail) and sc.is_node_ready(), secs)


func _press(b: Variant) -> bool:
	if b is BaseButton and not (b as BaseButton).disabled and (b as Control).is_visible_in_tree():
		(b as BaseButton).pressed.emit()
		return true
	return false


func _modal_btn(scr: Node, nm: String) -> Node:
	var l: Node = scr.find_child("Layer", true, false)
	return l.find_child(nm, true, false) if l != null else null


func _key(k: Key, unicode: int = 0) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.unicode = unicode
	ev.pressed = true
	root.push_input(ev)
	await process_frame
	var up := InputEventKey.new()
	up.keycode = k
	up.pressed = false
	root.push_input(up)
	await process_frame


func _base_save() -> void:
	store.call("clear")
	var st: Dictionary = fx["sanctuary"][0]["store"]
	for k: String in st.keys():
		store.call("set_json", k, Js.deep(st[k]))
	store.call("set_json", "game_settings", {"language": "ko", "playSpeed": 4})
	store.call("set_json", "game_story_seen", {"ep1_pro": true})
	i18n.call("_apply", "ko")


func _gold() -> float:
	return Js.num((store.call("get_json", "game_save", {}) as Dictionary).get("gold"))


func _char(uid: int) -> Dictionary:
	for ch: Dictionary in (store.call("get_json", "game_roster") as Dictionary)["chars"]:
		if int(ch["uid"]) == uid:
			return ch
	return {}


func _screens() -> void:
	router.set("dry_run", false)
	_base_save()
	router.call("go", "lobby")
	_check(await _wait_scene("ui/lobby.gd"), "로비")
	await _frames(3)
	var lb: Node = _scene()
	if lb.get("setup_dialog") != null:
		lb.commander_setup_done()
	# (4b-2) 로비: 10자 이름표가 아래 단추 줄(출격)과 겹치지 않음 · 골드 천 단위 쉼표
	var rr: Dictionary = store.call("get_json", "game_roster")
	for ch0: Dictionary in rr["chars"]:
		if str(ch0.get("cls")) != "commander":
			ch0["customName"] = "가나다라마바사아자차"
	store.call("set_json", "game_roster", rr)
	var over := 0
	for res: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = res
		lb._refresh()
		await _frames(4)
		var top_y: float = (lb.popups as Control).get_global_rect().position.y
		for b0: Node in (lb.popups as Control).get_children():
			top_y = minf(top_y, (b0 as Control).get_global_rect().position.y)
		for u: Dictionary in lb.hideout._units:
			var gr: Rect2 = (u["node"] as Control).get_global_rect()
			if gr.end.y > top_y or not lb.hideout.get_global_rect().grow(1.0).encloses(gr):
				over += 1
	root.size = Vector2i(1280, 720)
	_check(over == 0 and lb.hideout._units.size() >= 8, "로비: 10자 이름표가 아지트 안 · 출격 단추 줄 위에서 끝남 (1280·1920, 겹침 %d)" % over)
	_check(lb.gold_lbl.text == "5,000 G", "로비 골드 천 단위 쉼표 (%s)" % lb.gold_lbl.text)
	# 아래 탭 성소
	_press(lb.find_child("Tab_sanctuary", true, false))
	_check(await _wait_scene("ui/sanctuary.gd"), "아래 탭 성소 → 성소 화면 (준비 중 아님)")
	var sa: Node = _scene()
	await _frames(3)
	_check(sa.cur_tab == "resurrect" and sa.find_child("Dead_31", true, false) != null and sa.find_child("Dead_9", true, false) == null, "성소: 부활 탭 · 죽은 클랜원 카드 (소환수 없음)")
	var g0 := _gold()
	_press(sa.find_child("Dead_31", true, false).find_child("Revive", true, false))
	await _frames(2)
	_check(not bool(_char(31).get("dead")) and _gold() == g0 - 120.0 and sa.find_child("Dead_31", true, false) == null, "부활 단추 → 부활 · 골드 −120 · 카드 사라짐")
	_press(sa.find_child("AdBtn", true, false))
	await _frames(2)
	_press(_modal_btn(sa, "Pick_7"))
	await _frames(2)
	_check(not bool(_char(7).get("dead")) and store.call("has", Sanc.AD_KEY) and _modal_btn(sa, "Alert") != null, "무료 부활 → 고르기 창 → 7 부활 · 대기 시각 저장 · 알림")
	sa.close_all_modals()
	await _frames(1)
	_check((sa.find_child("AdBtn", true, false) as Button).disabled, "무료 부활 단추 → 대기 중 (꺼짐)")
	# 승급 탭: 합치기 · 승급
	_press(sa.find_child("Tab_promote", true, false))
	await _frames(2)
	_press(sa.find_child("Soul_mage", true, false).find_child("Combine", true, false))
	await _frames(2)
	var soul: Dictionary = store.call("get_json", "game_soul")
	_check(int(soul["stones"]["mage"]) == 2 and int(soul["frags"]["mage"]) == 3, "영혼석 합치기 → 마법사 영혼석 2 · 조각 3")
	sa.close_all_modals()
	await _frames(1)
	_press(sa.find_child("Promote_12", true, false).find_child("PromoteBtn", true, false))
	await _frames(2)
	var cb: Button = _modal_btn(sa, "Confirm")
	_check(cb != null and cb.disabled, "제물 창: 처음엔 승급 단추 꺼짐")
	_press(_modal_btn(sa, "Sac_11"))
	await _frames(1)
	_check(cb.disabled and (_modal_btn(sa, "PtsText") as Label).text == "1 / 4 pt", "제물 11 (1점) → 1 / 4 pt · 아직 꺼짐")
	_press(_modal_btn(sa, "Sac_13"))
	await _frames(1)
	_check(not cb.disabled and (_modal_btn(sa, "PtsText") as Label).text == "5 / 4 pt", "제물 13 (4점) → 5 / 4 pt · 켜짐")
	_press(cb)
	await _frames(2)
	_check(_modal_btn(sa, "SacModal") == null and _modal_btn(sa, "Yes") != null and (_modal_btn(sa, "Scroll").get_child(0) as Label).text.contains("~"), "승급 → 제물 창 닫힘 · 확인 창 (예상 능력치 ~)")
	_press(_modal_btn(sa, "Yes"))
	await _frames(2)
	_check(_char(11).is_empty() and _char(13).is_empty() and Profile.pot_grade(_rc(), _char(12)) == "A", "승급 확인 → 제물 사라짐 · 12 등급 A")
	sa.close_all_modals()
	# 개명 (키보드: 글 입력 + Enter)
	_press(sa.find_child("Tab_rename", true, false))
	await _frames(2)
	_press(sa.find_child("Rename_4", true, false).find_child("RenameBtn", true, false))
	await _frames(3)
	var inp: LineEdit = sa.rename_input
	_check(inp != null and inp.has_focus(), "개명 창: 이름 칸에 바로 입력 (포커스)")
	inp.text = "  하늘마녀  "
	inp.text_submitted.emit(inp.text)
	await _frames(2)
	_check(str(_char(4).get("customName")) == "하늘마녀", "개명 → Enter → '하늘마녀' (앞뒤 공백 지움)")
	sa.close_all_modals()
	_press(sa.find_child("Rename_4", true, false).find_child("RenameBtn", true, false))
	await _frames(2)
	sa.rename_input.text = "가나다라마바사아자차카타파하"
	sa.rename_input.text_changed.emit(sa.rename_input.text)
	_press(_modal_btn(sa, "Confirm"))
	await _frames(2)
	_check(str(_char(4).get("customName")) == "가나다라마바사아자차", "개명 10자 제한 (UTF-16 단위, 웹 maxlength)")
	sa.close_all_modals()
	# 마법부여
	_press(sa.find_child("Tab_enchant", true, false))
	await _frames(2)
	var eid0: String = fx["sanctuary"][0]["store"]["game_inventory"][0]["eid"]
	var opt: Node = sa.find_child("Enc_" + eid0, true, false).find_child("Opt_fire", true, false)
	_press(opt)
	await _frames(2)
	_press(_modal_btn(sa, "Yes"))
	await _frames(2)
	var inv: Array = store.call("get_json", "game_inventory")
	var it0: Dictionary = inv.filter(func(x: Variant) -> bool: return x is Dictionary and x.get("eid") == eid0)[0]
	_check(it0.get("enchant") == "fire" and Sanc.rune_count(_rc(), "fire") == 1, "마법부여: 불 룬 → 확인 → 장비 enchant=fire · 룬 1개 줄어듦")
	_check((sa.find_child("Enc_" + eid0, true, false).find_child("Opt_fire", true, false) as Button).disabled, "같은 룬 단추 → 꺼짐 (이미 같은 종류)")
	# Esc 로 로비 (창 없으면 뒤로)
	await _key(KEY_ESCAPE)
	_check(await _wait_scene("ui/lobby.gd"), "성소 Esc → 로비")
	lb = _scene()
	await _frames(2)
	# 아카데미: 전직 · 스킬북
	_press(lb.find_child("Tab_academy", true, false))
	_check(await _wait_scene("ui/academy.gd"), "아래 탭 아카데미 → 아카데미 화면")
	var ac: Node = _scene()
	await _frames(3)
	_press(ac.find_child("Novice_6", true, false).find_child("ChangeBtn", true, false))
	await _frames(2)
	var srow: Node = null
	for nd: Node in _modal_btn(ac, "Scrolls").get_children():
		if str(nd.name).begins_with("Scroll_") and (nd as Button).find_child("Title", true, false).text.contains(i18n.call("t", "classes.archer")):
			srow = nd
	_press(srow)
	await _frames(2)
	var yes: Node = _modal_btn(ac, "Yes")
	var conf_txt: String = (_modal_btn(ac, "Scroll").get_child(0) as Label).text if _modal_btn(ac, "Scroll") != null else ""
	_press(yes)
	await _frames(2)
	var c6 := _char(6)
	_check(c6.get("cls") == "archer" and conf_txt.contains("HP %s / ATK %s / DEF %s" % [Num_fmt(c6["hp"]), Num_fmt(c6["atk"]), Num_fmt(c6["def"])]), "전직: 전직서 고르기 → 확인 창 숫자 = 전직 결과 (궁수 HP %s)" % Num_fmt(c6.get("hp", 0)))
	ac.close_all_modals()
	_press(ac.find_child("Tab_skillbook", true, false))
	await _frames(2)
	var book_btn: Node = null
	for nd2: Node in ac.list.get_children():
		if str(nd2.name).begins_with("Book_") and nd2.find_child("UseBtn", true, false) != null and not (nd2.find_child("UseBtn", true, false) as Button).disabled:
			book_btn = nd2.find_child("UseBtn", true, false)
			break
	_press(book_btn)
	await _frames(2)
	var trow: Node = null
	for nd3: Node in _modal_btn(ac, "BookTargets").get_children():
		if str(nd3.name).begins_with("Target_"):
			trow = nd3
			break
	var n_books := Acad.books(_rc()).size()
	_press(trow)
	await _frames(2)
	_press(_modal_btn(ac, "Yes"))
	await _frames(2)
	_check(Acad.books(_rc()).size() == n_books - 1 and _modal_btn(ac, "Alert") != null, "스킬북: 사용 → 대상 → 확인 → 스킬북 하나 줄어듦 · 결과 알림")
	ac.close_all_modals()
	# (4b-2) 전직 미리보기: 확인 창을 닫았다 열어도 같은 숫자 · 게임(프로세스)을 다시 켜도 같은 숫자
	var msgs: Array = []
	for i in 4:
		ac.confirm_change(8, "mage", -1)
		await _frames(2)
		msgs.append((_modal_btn(ac, "Scroll").get_child(0) as Label).text)
		_press(_modal_btn(ac, "No"))
		await _frames(2)
	_check(msgs.size() == 4 and msgs.count(msgs[0]) == 4 and str(msgs[0]).contains("HP "), "전직 확인 창을 4번 닫았다 열어도 같은 예상 스탯")
	store.call("flush")
	store.call("use_path", "user://test_outer_4b2_other.json")
	store.call("use_path", SAVE)
	var pv_reload := Acad.preview_kept(_rc(), Profile.get_char(_rc(), 8), "mage")
	var out: Array = []
	OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/aux_class_preview.gd", "--", SAVE, "8", "mage"], out, true)
	var line := ""
	for ln: String in str(out[0]).split("\n"):
		if ln.begins_with("PV: "):
			line = ln.substr(4)
	var pv_proc: Variant = JsonX.parse(line) if line != "" else null
	var shown := str(msgs[0])
	_check(shown.contains("HP %s / ATK %s / DEF %s" % [Num_fmt(pv_reload["hp"]), Num_fmt(pv_reload["atk"]), Num_fmt(pv_reload["def"])]) and _same(pv_proc, pv_reload),
		"저장을 다시 읽어도 · 다른 프로세스에서도 같은 미리보기 (%s)" % line.substr(0, 60))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_outer_4b2_other.json"))
	# 스페인어 확인 창: 등급과 'Grado' 를 띄어 씀 (웹은 'BGrado')
	i18n.call("_apply", "es")
	ac.confirm_change(8, "mage", -1)
	await _frames(2)
	var es_txt := (_modal_btn(ac, "Scroll").get_child(0) as Label).text
	ac.close_all_modals()
	i18n.call("_apply", "ko")
	_check(RegEx.create_from_string("[A-Z] Grado").search(es_txt) != null and RegEx.create_from_string("[A-Z]Grado").search(es_txt) == null, "스페인어 전직 확인 창: '%s'" % es_txt.get_slice("\n", 0))
	# 전직서가 없으면 상점 전직서 탭으로
	var inv2: Array = store.call("get_json", "game_inventory")
	store.call("set_json", "game_inventory", inv2.filter(func(x: Variant) -> bool: return not (x is Dictionary and x.get("type") == "scroll")))
	ac.switch_tab("classchange")
	await _frames(2)
	_press(ac.find_child("BuyScroll", true, false))
	_check(await _wait_scene("ui/shop.gd"), "전직서 없음 → '전직서 구매' → 상점")
	await _frames(2)
	_check(_scene().cur_tab == "scroll", "상점 전직서 탭으로 (웹 shop.html?tab=scroll)")
	router.call("go", "lobby")
	await _wait_scene("ui/lobby.gd")
	lb = _scene()
	await _frames(2)
	# 도감: 로비 단추 · 탭 · 검색 · 직업 창 · 장비 거르기
	_press(lb.find_child("Compendium", true, false))
	_check(await _wait_scene("ui/compendium.gd"), "로비 도감 단추 → 도감 화면 (준비 중 아님)")
	var cp: Node = _scene()
	await _frames(3)
	_check(cp.title_lbl.text == i18n.call("t", "nav.compendium") and not cp.bottom_nav.visible, "도감: 제목 nav.compendium · 아래 탭 없음 (웹 같음)")
	_press(cp.find_child("Tile_mage", true, false))
	await _frames(3)
	_check(cp.modal_open() and cp.sheet_cls == "mage" and _modal_btn(cp, "SheetHead") != null, "직업 타일 → 상세 창 (마법사)")
	await _key(KEY_ESCAPE)
	await _frames(1)
	_check(not cp.modal_open() and _scene() == cp, "Esc → 상세 창만 닫힘")
	cp.search.text = "화염"
	cp.search.text_changed.emit(cp.search.text)
	await _frames(1)
	var vis := 0
	var hid := 0
	for t: Node in cp.current_panel().find_child("Tiles", true, false).get_children():
		if (t as Control).visible:
			vis += 1
		else:
			hid += 1
	_check(vis == 0 and hid == 12, "검색 '화염' → 직업 타일 12개 숨김 (웹 data-q 와 같은 규칙)")
	cp.search.text = i18n.call("t", "classes.mage")
	cp.search.text_changed.emit(cp.search.text)
	await _frames(1)
	vis = 0
	for t2: Node in cp.current_panel().find_child("Tiles", true, false).get_children():
		if (t2 as Control).visible:
			vis += 1
	_check(vis == 1, "검색 '마법사' → 타일 1개")
	_press(cp.find_child("Tabs", true, false).find_child("Tab_stage", true, false))
	await _frames(3)
	cp.search.text = i18n.call("t", "stages.stage_1_name")
	cp.search.text_changed.emit(cp.search.text)
	await _frames(1)
	var rows_vis := 0
	for sr: Node in cp.current_panel().find_children("Stage", "PanelContainer", true, false):
		if (sr as Control).visible:
			rows_vis += 1
	var accs_open := 0
	var stack: Array = [cp.current_panel()]
	while not stack.is_empty():
		var nn: Node = stack.pop_back()
		if nn.has_meta("acc") and bool(nn.get_meta("open", false)):
			accs_open += 1
		stack.append_array(nn.get_children())
	_check(accs_open == 1 and rows_vis == 1, "스테이지 탭 + 검색 '1-1 이름' → 그 스테이지 하나 · 그 에피소드만 펼침 (펼침 %d · 줄 %d)" % [accs_open, rows_vis])
	cp.search.text = ""
	cp.search.text_changed.emit("")
	_press(cp.find_child("Tabs", true, false).find_child("Tab_gear", true, false))
	await _frames(3)
	_press(cp.current_panel().find_child("Filter_rule", true, false))
	await _frames(3)
	_check(cp.gear_filter == "rule" and cp.current_panel().find_child("Table", true, false) != null, "장비 거르기 '등급·강화' → 표")
	await _key(KEY_ESCAPE)
	_check(await _wait_scene("ui/lobby.gd"), "도감 Esc → 이전 화면 (로비, 웹 history.back)")
	lb = _scene()
	await _frames(2)
	# 가이드: 로비 단추 · 탭 · 링크 → 도감 장비 탭
	_press(lb.find_child("Guide", true, false))
	_check(await _wait_scene("ui/guide.gd"), "로비 가이드 단추 → 가이드 화면")
	var gd: Node = _scene()
	await _frames(3)
	for tb: String in CodexRules.GUIDE_TABS:
		_press(gd.find_child("Tabs", true, false).find_child("Tab_" + tb, true, false))
		await _frames(1)
	_check(gd.cur_tab == "story", "가이드 탭 7개 차례로")
	_press(gd.find_child("Tabs", true, false).find_child("Tab_gear", true, false))
	await _frames(2)
	var link_rt: RichTextLabel = null
	var st2: Array = [gd.current_panel()]
	while not st2.is_empty():
		var n3: Node = st2.pop_back()
		if n3 is RichTextLabel and (n3 as RichTextLabel).get_parsed_text().contains(i18n.call("t", "codex.c.title") + " → "):
			link_rt = n3
		st2.append_array(n3.get_children())
	_check(link_rt != null, "가이드 장비 탭: '도감' 링크 글")
	if link_rt != null:
		link_rt.meta_clicked.emit("compendium:gear")
	_check(await _wait_scene("ui/compendium.gd"), "링크 → 도감")
	await _frames(2)
	_check(_scene().cur_tab == "gear", "도감 장비 탭으로 (웹 compendium.html?tab=gear)")
	await _key(KEY_ESCAPE)
	_check(await _wait_scene("ui/guide.gd"), "도감 Esc → 가이드로 (기록)")
	await _frames(2)
	_check(_scene().cur_tab == "gear", "돌아온 가이드는 같은 탭 (기록)")
	router.call("go", "lobby")
	await _wait_scene("ui/lobby.gd")
	await _frames(2)
	# 설정 → 라이선스 → 뒤로 → 크레딧 → 뒤로
	_press(_scene().find_child("Gear", true, false))
	_check(await _wait_scene("ui/settings_screen.gd"), "톱니 → 설정")
	await _frames(2)
	_press(_scene().find_child("Licenses", true, false))
	_check(await _wait_scene("ui/licenses.gd"), "설정 라이선스 → 라이선스 화면 (준비 중 아님)")
	var li: Node = _scene()
	await _frames(2)
	var txt := ""
	for nn2: Node in li.find_children("*", "Label", true, false):
		txt += (nn2 as Label).text + "\n"
	_check(txt.contains("Noto Sans KR") and txt.contains("Noto Sans JP") and txt.contains("Noto Sans SC") and txt.contains("Noto Sans TC") and txt.contains("SIL Open Font License")
		and txt.contains("Godot Engine") and txt.contains("MIT License") and txt.contains("Permission is hereby granted") and txt.contains("FreeType") and not txt.contains("Cinzel")
		and txt.contains("the V8 project authors") and txt.contains("BSD 3-Clause") and txt.contains("Neither the name of Google Inc."),
		"라이선스: Noto 4종(OFL) · OFL 전문 · Godot 엔진(MIT 전문) · V8(BSD-3 전문 — js.gd 이식) · 엔진 제3자 구성 요소(FreeType 등) · Cinzel 없음")
	var js_src := FileAccess.get_file_as_string("res://scripts/logic/js.gd")
	_check(js_src.contains("array-sort.tq — Copyright 2018 the V8 project authors") and js_src.contains("DoubleToRadixCString — Copyright the V8 project authors. BSD-3-Clause"), "js.gd 의 V8 이식 함수 위 출처 주석 (V8, BSD-3)")
	_press(li.find_child("OflTextBtn", true, false))
	await _frames(1)
	_check((li.find_child("OflText", true, false) as Label).visible and (li.find_child("OflText", true, false) as Label).text.contains("SIL OPEN FONT LICENSE Version 1.1"), "OFL 전문 펼치기 (godot/assets/fonts/OFL.txt)")
	await _key(KEY_ESCAPE)
	_check(await _wait_scene("ui/settings_screen.gd"), "라이선스 뒤로 → 설정")
	await _frames(2)
	_press(_scene().find_child("Credits", true, false))
	_check(await _wait_scene("ui/credits.gd"), "설정 Credits → 크레딧 화면")
	var cr: Node = _scene()
	await _frames(2)
	var ctxt := ""
	for nn3: Node in cr.find_children("*", "Label", true, false):
		ctxt += (nn3 as Label).text + "\n"
	_check(ctxt.contains("SPECIAL THANKS") and ctxt.contains("philgooch") and ctxt.contains("Reddit") and ctxt.contains("Feedback & Support") and ctxt.contains("DEADLINE 15 © 2026 show4you") and cr.title_lbl.text == "Credits",
		"크레딧: 웹과 같은 글 (SPECIAL THANKS · philgooch · Reddit · Feedback & Support · 저작권)")
	_press(cr.back_btn)
	_check(await _wait_scene("ui/settings_screen.gd"), "크레딧 뒤로 단추 → 설정")
	router.call("go", "lobby")
	await _wait_scene("ui/lobby.gd")
	await _frames(2)
	# 키보드만으로: 성소 탭 → Tab 으로 포커스 옮겨 Enter
	_scene().find_child("Tab_sanctuary", true, false).grab_focus()
	await _frames(1)
	await _key(KEY_ENTER)
	_check(await _wait_scene("ui/sanctuary.gd"), "키보드: 아래 탭 성소에 포커스 + Enter → 성소")
	await _frames(2)
	_scene().find_child("Tab_promote", true, false).grab_focus()
	await _key(KEY_ENTER)
	await _frames(1)
	_check(_scene().cur_tab == "promote", "키보드: 탭 단추 Enter → 승급 탭")
	router.call("go", "lobby")
	await _wait_scene("ui/lobby.gd")
	await _frames(2)
	_stat("screens.checks", 45)


# ═══════════ 6) 같은 프레임 연타 ═══════════

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


## 진짜 입력 한 번 누르기 (push_input)
func _click1(ctl: Variant) -> void:
	if not (ctl is Control):
		return
	await _reveal(ctl)
	var p := (ctl as Control).get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = p
	root.push_input(mv)
	await process_frame
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		root.push_input(ev)
	await _frames(3)


func _reveal(ctl: Control) -> void:
	var a: Node = ctl.get_parent()
	while a != null:
		if a is ScrollContainer:
			(a as ScrollContainer).ensure_control_visible(ctl)
			break
		a = a.get_parent()
	await _frames(2)


func _dc(ctl: Variant) -> void:
	if ctl is Control:
		await _reveal(ctl)
		await _double_click(ctl)


func _clicks() -> void:
	router.set("dry_run", false)
	var bad: Array = []
	_base_save()
	router.call("go", "sanctuary")
	await _wait_scene("ui/sanctuary.gd")
	var sa: Node = _scene()
	await _frames(3)
	# 부활 (두 번 → 한 번)
	var g0 := _gold()
	await _dc(sa.find_child("Dead_31", true, false).find_child("Revive", true, false))
	if _gold() != g0 - 120.0:
		bad.append("부활 %s" % (g0 - _gold()))
	# 무료 부활: 고르기 줄 두 번
	await _dc(sa.find_child("AdBtn", true, false))
	var alive_before := Sanc.alive(_rc()).size()
	await _dc(_modal_btn(sa, "Pick_15"))
	if Sanc.alive(_rc()).size() != alive_before + 1:
		bad.append("무료 부활 %d" % (Sanc.alive(_rc()).size() - alive_before))
	sa.close_all_modals()
	await _frames(1)
	# 합치기
	sa.switch_tab("promote")
	await _frames(2)
	await _dc(sa.find_child("Soul_mage", true, false).find_child("Combine", true, false))
	var soul: Dictionary = store.call("get_json", "game_soul")
	if int(soul["stones"]["mage"]) != 2:
		bad.append("합치기 %s" % str(soul["stones"]["mage"]))
	sa.close_all_modals()
	await _frames(1)
	# 승급 확인 두 번
	sa.open_sacrifice(42)
	await _frames(2)
	sa.toggle_sacrifice(41)
	(sa.find_child("Confirm", true, false) as Button).pressed.emit()
	await _frames(2)
	var n_ch: int = (store.call("get_json", "game_roster") as Dictionary)["chars"].size()
	var st_m: float = Sanc.soul_stones(_rc(), "mage")
	await _dc(_modal_btn(sa, "Yes"))
	if (store.call("get_json", "game_roster") as Dictionary)["chars"].size() != n_ch - 1 or Sanc.soul_stones(_rc(), "mage") != st_m - 1.0:
		bad.append("승급")
	sa.close_all_modals()
	await _frames(1)
	# 개명 확인 두 번 (알림 하나)
	sa.switch_tab("rename")
	await _frames(2)
	sa.open_rename(1)
	await _frames(2)
	sa.rename_input.text = "둘"
	await _dc(_modal_btn(sa, "Confirm"))
	var alerts := 0
	for nd: Node in sa.layer.get_children():
		if str(nd.name).begins_with("Alert"):
			alerts += 1
	if str(_char(1).get("customName")) != "둘" or alerts != 1:
		bad.append("개명 알림 %d" % alerts)
	sa.close_all_modals()
	await _frames(1)
	# 마법부여 확인 두 번 (룬·골드 한 번)
	sa.switch_tab("enchant")
	await _frames(2)
	var eid1: String = fx["sanctuary"][0]["store"]["game_inventory"][1]["eid"]
	await _dc(sa.find_child("Enc_" + eid1, true, false).find_child("Opt_fire", true, false))
	var g1 := _gold()
	var r1 := Sanc.rune_count(_rc(), "fire")
	await _dc(_modal_btn(sa, "Yes"))
	if _gold() != g1 - 100.0 or Sanc.rune_count(_rc(), "fire") != r1 - 1:
		bad.append("마법부여 골드 %s 룬 %d" % [g1 - _gold(), r1 - Sanc.rune_count(_rc(), "fire")])
	sa.close_all_modals()
	await _frames(1)
	# 아카데미: 전직 확인 두 번 · 스킬북 확인 두 번
	router.call("go", "academy")
	await _wait_scene("ui/academy.gd")
	var ac: Node = _scene()
	await _frames(3)
	var n_scroll := Acad.scrolls(_rc()).size()
	ac.confirm_change(8, "mage", Acad.usable_scrolls(_rc())[1]["idx"])
	await _frames(2)
	await _dc(_modal_btn(ac, "Yes"))
	if Acad.scrolls(_rc()).size() != n_scroll - 1 or _char(8).get("cls") != "mage":
		bad.append("전직")
	ac.close_all_modals()
	ac.switch_tab("skillbook")
	await _frames(2)
	var nb := Acad.books(_rc()).size()
	var bk: Dictionary = Acad.books(_rc())[0]
	ac.confirm_book(int(bk["idx"]), bk["item"], Acad.targets(_rc(), bk["item"])[0]["uid"])
	await _frames(2)
	await _dc(_modal_btn(ac, "Yes"))
	if Acad.books(_rc()).size() != nb - 1:
		bad.append("스킬북 %d" % (nb - Acad.books(_rc()).size()))
	ac.close_all_modals()
	# 로비: 포기 두 번
	router.call("go", "lobby")
	await _wait_scene("ui/lobby.gd")
	await _frames(2)
	router.set("dry_run", true)
	_make_gd()
	var lb: Node = (load("res://scenes/outer/lobby.tscn") as PackedScene).instantiate()
	root.add_child(lb)
	await _frames(3)
	if lb.get("setup_dialog") != null:
		lb.commander_setup_done()
	await _dc(lb.abandon_btn)
	var confs := 0
	for nd2: Node in lb.layer.get_children():
		if str(nd2.name).begins_with("AbandonConfirm"):
			confs += 1
	await _dc(_modal_btn(lb, "Abandon"))
	var toasts := 0
	for nd3: Node in lb.layer.get_children():
		if str(nd3.name).begins_with("Toast") and not nd3.is_queued_for_deletion():
			toasts += 1
	if confs != 1 or store.call("has", ResumeRules.KEY) or toasts != 1:
		bad.append("포기 확인 창 %d · 알림 %d" % [confs, toasts])
	lb.queue_free()
	await _frames(2)
	router.set("dry_run", false)
	for b: String in bad:
		print("    " + b)
	_check(bad.is_empty(), "같은 프레임 두 번 누르기: 부활·무료 부활·합치기·승급·개명·마법부여·전직·스킬북·포기(✕·확인) 모두 한 번만")
	_check(confs == 1 and toasts == 1, "포기: ✕ 두 번 → 확인 창 하나 · 포기 두 번 → 알림 하나, 저장 전투 지움 (push_input)")
	await _clicks_more()
	_stat("clicks.buttons", 10)
	router.call("go", "lobby")
	await _wait_scene("ui/lobby.gd")


## (4b-2 검수) 진짜 입력: 4점 미만 승급 거절 · 같은 스킬북 두 권 연타 · 저장 전투에 나간 클랜원은 제물 아님
func _clicks_more() -> void:
	router.set("dry_run", false)
	_base_save()
	var r: Dictionary = store.call("get_json", "game_roster")
	var JAB: Dictionary = D["JAB"]
	for spec: Array in [[51, 0.2], [52, 0.2], [53, 0.5]]:
		var g: Dictionary = JAB["warrior"]["growth"]
		var f: float = spec[1]
		r["chars"].append({"uid": spec[0], "cls": "warrior", "nameId": spec[0], "customName": "W%d" % spec[0], "lv": 3, "exp": 0, "dead": false, "hp": 110, "atk": 28, "def": 10,
			"move": 3, "range": 1, "pot": {"hp": g["hp"][0] + (g["hp"][1] - g["hp"][0]) * f, "atk": g["atk"][0] + (g["atk"][1] - g["atk"][0]) * f, "def": g["def"][0] + (g["def"][1] - g["def"][0]) * f, "actionRec": 0.1},
			"actionRec": 1.1, "gender": "m"})
	store.call("set_json", "game_roster", r)
	var inv: Array = store.call("get_json", "game_inventory")
	inv.append({"id": "mage_freeze", "cls": "mage", "lv": 1})
	store.call("set_json", "game_inventory", inv)
	router.call("go", "sanctuary", {"tab": "promote"})
	await _wait_scene("ui/sanctuary.gd")
	var sa: Node = _scene()
	await _frames(3)
	await _click1(sa.find_child("Promote_12", true, false).find_child("PromoteBtn", true, false))
	var pts_of := func() -> String: return (_modal_btn(sa, "PtsText") as Label).text
	await _click1(_modal_btn(sa, "Sac_11"))
	await _click1(_modal_btn(sa, "Sac_53"))
	var cb: Button = _modal_btn(sa, "Confirm")
	var p3: String = pts_of.call()
	await _click1(cb)
	var n_before: int = (store.call("get_json", "game_roster") as Dictionary)["chars"].size()
	var still_open: bool = _modal_btn(sa, "SacModal") != null and _modal_btn(sa, "Yes") == null
	var rr := Sanc.promote(_rc(), 12, [11, 53])
	_check(p3 == "3 / 4 pt" and cb.disabled and still_open and not bool(rr["ok"]) and str(rr["reason"]) == "points" and (store.call("get_json", "game_roster") as Dictionary)["chars"].size() == n_before,
		"승급 3점(C 1 + B 2): 단추 꺼짐 · 진짜 누르기도 무시 · 규칙도 거절 (필요 점수 4 — 바꾸면 잡힘) [%s]" % p3)
	await _click1(_modal_btn(sa, "Sac_51"))
	await _click1(_modal_btn(sa, "Sac_52"))
	await _click1(_modal_btn(sa, "Sac_11"))
	var p4: String = pts_of.call()
	await _click1(_modal_btn(sa, "Confirm"))
	await _dc(_modal_btn(sa, "Yes"))
	var ch12: Dictionary = _char(12)
	_check(p4 == "4 / 4 pt" and _char(51).is_empty() and _char(52).is_empty() and _char(53).is_empty() and not _char(11).is_empty() and Profile.pot_grade(_rc(), ch12) == "A",
		"승급 정확히 4점(C 1 + C 1 + B 2): 받아들임 · 확인 두 번 눌러도 한 번 [%s]" % p4)
	sa.close_all_modals()
	# 저장 전투(gd_battle)에 나간 클랜원은 제물 후보가 아님 → 포기하면 다시 후보
	var tgt: Dictionary = _char(12)
	var before: Array = _uids(Sanc.sacrifices(_rc(), tgt))
	store.call("set_str", ResumeRules.KEY, JsonX.stringify({"format": 2, "cfg": {"stage": {"id": 3}, "party": [14]}, "state": {"units": [{"uid": 13, "team": "ally"}, {"uid": 5, "team": "enemy"}]}}))
	var during: Array = _uids(Sanc.sacrifices(_rc(), tgt))
	sa.open_sacrifice(12)
	await _frames(2)
	var row_hidden: bool = _modal_btn(sa, "Sac_13") == null and _modal_btn(sa, "Sac_14") == null
	sa.close_all_modals()
	ResumeRules.abandon(_rc())
	var after: Array = _uids(Sanc.sacrifices(_rc(), tgt))
	_check(before.has(13) and before.has(14) and not during.has(13) and not during.has(14) and row_hidden and _same(after, before),
		"중단된 저장 전투에 나간 클랜원(13 유닛 · 14 cfg 파티)은 제물 후보에서 빠짐 · 포기하면 다시 후보 (%s → %s → %s)" % [str(before), str(during), str(after)])
	# 같은 스킬북 두 권: 사용 단추·대상·확인을 같은 프레임에 두 번씩 → 한 권씩만
	router.call("go", "academy", {"tab": "skillbook"})
	await _wait_scene("ui/academy.gd")
	var ac: Node = _scene()
	await _frames(3)
	var lvs: Array = []
	var counts: Array = []
	for round_i in 2:
		var row: Node = null
		for b: Dictionary in Acad.books(_rc()):
			if b["item"]["id"] == "mage_freeze":
				row = ac.list.find_child("Book_%d" % int(b["idx"]), true, false)
				break
		await _dc(row.find_child("UseBtn", true, false))
		var modals := 0
		for nd2: Node in ac.layer.get_children():
			if str(nd2.name).begins_with("BookModal") and not nd2.is_queued_for_deletion():
				modals += 1
		await _dc(_modal_btn(ac, "Target_4"))
		await _dc(_modal_btn(ac, "Yes"))
		lvs.append(PartyRules.char_skill_lv(_rc(), _char(4), "mage_freeze"))
		var nb := 0
		for it: Variant in store.call("get_json", "game_inventory"):
			if it is Dictionary and it.get("id") == "mage_freeze":
				nb += 1
		counts.append([modals, nb])
		ac.close_all_modals()
		await _frames(2)
	_check(_same(lvs, [1.0, 2.0]) and _same(counts, [[1, 1], [1, 0]]), "같은 스킬북 두 권: 단추·대상·확인 두 번씩 눌러도 한 번에 한 권 (레벨 %s · [창 수, 남은 권수] %s)" % [str(lvs), str(counts)])
	router.call("go", "lobby")
	await _wait_scene("ui/lobby.gd")


# ═══════════ 7) 이상한 세이브 · 왕복 ═══════════

var _rng := RandomNumberGenerator.new()


func _junk(depth: int = 0) -> Variant:
	var pool: Array = [null, 0, -1, 1, 1.5, 3, 99999, -0.5, "", "x", "50", "mage", "novice", "fire", "frost", "warrior", "weapon", "rare", "S", "commander", true, false]
	var r := _rng.randi() % 10
	if depth < 2 and r == 0:
		var a: Array = []
		for i in _rng.randi() % 4:
			a.append(_junk(depth + 1))
		return a
	if depth < 2 and r == 1:
		var d: Dictionary = {}
		for i in _rng.randi() % 3:
			d[["id", "v", "cls", "type", "hp", "mage", "1"][_rng.randi() % 7]] = _junk(depth + 1)
		return d
	return pool[_rng.randi() % pool.size()]


func _maybe(v: Variant, p: float = 0.3) -> Variant:
	return _junk() if _rng.randf() < p else v


func _fuzz() -> Dictionary:
	var st: Dictionary = Js.deep(fx["sanctuary"][0]["store"])
	var chars: Array = []
	for ch: Variant in st["game_roster"]["chars"]:
		var x: Variant = Js.deep(ch)
		if x is Dictionary and _rng.randf() < 0.35:
			var keys: Array = (x as Dictionary).keys()
			for j in 1 + _rng.randi() % 2:
				x[keys[_rng.randi() % keys.size()]] = _junk()
		if x is Dictionary and _rng.randf() < 0.15:
			x["skillLv"] = _maybe({"mage_freeze": _junk(), "warrior_powersmash": _maybe(10)}, 0.3)
		chars.append(_maybe(x, 0.05))
	st["game_roster"]["chars"] = chars
	var inv: Array = []
	for it: Variant in st["game_inventory"]:
		var y: Variant = Js.deep(it)
		if y is Dictionary and _rng.randf() < 0.35:
			var k2: Array = (y as Dictionary).keys()
			y[k2[_rng.randi() % k2.size()]] = _junk()
		inv.append(_maybe(y, 0.06))
	for i in _rng.randi() % 4:
		inv.append({"type": _maybe(["scroll", "rune", "equip"][_rng.randi() % 3], 0.3), "scrollCls": _junk(), "enchant": _junk(), "eid": _maybe("w%d" % i), "slot": _maybe("ring"),
			"rarity": _maybe("epic"), "stats": _maybe({"hp": 3}), "templateId": _maybe("ring_power"), "equipped": _junk(), "enchantAtk": _junk()})
		inv.append({"id": _maybe("mage_freeze"), "cls": _maybe("mage"), "lv": _junk()})
	st["game_inventory"] = inv
	st["game_soul"] = _maybe({"stones": _maybe({"warrior": _maybe(1), "mage": _junk()}), "frags": _maybe({"mage": _maybe(23), "knight": _junk()})}, 0.3)
	st["game_parties"] = _maybe(st["game_parties"], 0.15)
	st["game_save"] = _maybe({"gold": _maybe(5000.0, 0.2), "cleared": _maybe([1, 2])}, 0.1)
	var raw: Dictionary = {}
	for k: String in st.keys():
		var r := _rng.randf()
		if r < 0.04:
			continue
		elif r < 0.07:
			raw[k] = ""
		elif r < 0.09:
			raw[k] = "{bad"
		else:
			raw[k] = JsonX.stringify(st[k])
	if _rng.randf() < 0.4:
		raw["gd_class_preview"] = JsonX.stringify(_maybe({"6": _maybe({"fp": _maybe({"lv": 14, "pot": _junk()}), "cls": _maybe({"archer": _junk(), "mage": _maybe({"hp": 1, "atk": 1, "def": 1, "move": 3, "range": 4, "pot": _maybe({"hp": 1, "atk": 1, "def": 1}), "grade": "B", "cls": "mage"})})}), "8": _junk()}, 0.2))
	raw[Sanc.AD_KEY] = ["", "x", "1e3", str(int(NOW)), "-5", "{}", "Infinity", str(int(NOW) + 99999999)][_rng.randi() % 8]
	if _rng.randf() < 0.3:
		raw["gd_battle"] = ["{bad", "{\"format\":2,\"sum\":\"x\",\"cfg\":{},\"state\":{}}", "5", "{\"format\":1}"][_rng.randi() % 4]
	return raw


## 세이브 하나로 새 화면·창 모두 → [오류 수, 진입 실패]
func _try(raw: Dictionary) -> Array:
	store.call("clear")
	for k: String in raw.keys():
		store.call("set_str", k, raw[k])
	i18n.call("reload")
	var e0 := _counter.errors.size()
	var fails: Array = []
	router.set("params", {})
	var sa: Node = (load("res://scenes/outer/sanctuary.tscn") as PackedScene).instantiate()
	root.add_child(sa)
	await process_frame
	if not sa.is_node_ready():
		fails.append("sanctuary")
	for tab: String in ["resurrect", "promote", "rename", "enchant"]:
		sa.switch_tab(tab)
	var rc := _rc()
	for ch: Dictionary in Sanc.dead_list(rc).slice(0, 3):
		sa._act_frame = -1
		sa.revive(ch["uid"])
	sa.open_ad_revive()
	var pk: Node = _modal_btn(sa, "AdPick")
	if pk != null and pk.get_child_count() > 0:
		sa._act_frame = -1
		(pk.get_child(0) as Button).pressed.emit()
	sa.close_all_modals()
	for cls: String in Sanc.soul_owned(rc):
		sa._act_frame = -1
		sa.combine(cls)
		sa.close_all_modals()
	for ch2: Dictionary in Sanc.promotable(rc).slice(0, 4):
		sa.open_sacrifice(ch2["uid"])
		for s: Dictionary in Sanc.sacrifices(rc, ch2):
			sa.toggle_sacrifice(s["uid"])
		sa.confirm_promote()
		var y: Node = _modal_btn(sa, "Yes")
		if y != null:
			sa._act_frame = -1
			(y as Button).pressed.emit()
		sa.close_all_modals()
	for ch3: Dictionary in Sanc.alive(rc).slice(0, 2):
		sa.open_rename(ch3["uid"])
		sa.rename_input.text = "Z"
		sa._act_frame = -1
		sa.rename_done()
		sa.close_all_modals()
	sa.switch_tab("enchant")
	for it: Dictionary in Sanc.enchant_items(rc).slice(0, 3):
		for k2: String in ["fire", "flame"]:
			sa._act_frame = -1
			sa.ask_enchant(str(it.get("eid", "")), k2)
			var y2: Node = _modal_btn(sa, "Yes")
			if y2 != null:
				(y2 as Button).pressed.emit()
			sa.close_all_modals()
	await process_frame
	sa.queue_free()
	await process_frame
	var ac: Node = (load("res://scenes/outer/academy.tscn") as PackedScene).instantiate()
	root.add_child(ac)
	await process_frame
	if not ac.is_node_ready():
		fails.append("academy")
	for ch4: Dictionary in Acad.novices(rc).slice(0, 2):
		ac.open_scrolls(ch4["uid"])
		ac.close_all_modals()
		for s2: Dictionary in Acad.usable_scrolls(rc).slice(0, 1):
			ac.confirm_change(ch4["uid"], str(s2["item"]["scrollCls"]), int(s2["idx"]))
			var y3: Node = _modal_btn(ac, "Yes")
			if y3 != null:
				ac._act_frame = -1
				(y3 as Button).pressed.emit()
			ac.close_all_modals()
	ac.switch_tab("skillbook")
	for b: Dictionary in Acad.books(rc).slice(0, 3):
		ac.open_book(int(b["idx"]), b["item"])
		ac.close_all_modals()
		for tg: Dictionary in Acad.targets(rc, b["item"]).slice(0, 1):
			ac.confirm_book(int(b["idx"]), b["item"], tg["uid"])
			var y4: Node = _modal_btn(ac, "Yes")
			if y4 != null:
				ac._act_frame = -1
				(y4 as Button).pressed.emit()
			ac.close_all_modals()
	await process_frame
	ac.queue_free()
	await process_frame
	var lb: Node = (load("res://scenes/outer/lobby.tscn") as PackedScene).instantiate()
	root.add_child(lb)
	await process_frame
	if lb.get("setup_dialog") != null:
		lb.commander_setup_done()
	if lb.resume_btn != null:
		lb.press_resume()
		lb.close_all_modals()
		if lb.abandon_btn != null:
			lb.ask_abandon()
			lb.close_all_modals()
	await process_frame
	lb.queue_free()
	await process_frame
	return [_counter.errors.size() - e0, fails]


func _roundtrip(what: String) -> void:
	var raw: Dictionary = {}
	for k: String in store.call("keys"):
		raw[k] = store.call("get_str", k)
	var path := ProjectSettings.globalize_path("user://test_4b2_roundtrip.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JsonX.stringify(raw))
	f.close()
	var tool := ProjectSettings.globalize_path("res://").path_join("../tools/outer-4b2-expect.js").simplify_path()
	var out: Array = []
	var code := OS.execute("node", [tool, "--roundtrip", path], out, true)
	DirAccess.remove_absolute(path)
	var res: Variant = JsonX.parse(str(out[0]).strip_edges().get_slice("\n", str(out[0]).strip_edges().get_slice_count("\n") - 1)) if not out.is_empty() else null
	var ok: bool = code == 0 and res is Dictionary and bool(res.get("ok", false))
	if not ok:
		print("    왕복 %s: %s" % [what, str(out).substr(0, 400)])
	_check(ok, "Godot → 웹 왕복 (%s): 웹 성소 4탭·제물 창·개명 창·아카데미 2탭·전직서 창·스킬북 창·로비 점검 %s개 오류 0" % [what, str(int(res.get("checks", 0))) if res is Dictionary else "?"])


func _weird() -> void:
	root.size = Vector2i(1280, 720)
	var router_dry: bool = router.get("dry_run")
	router.set("dry_run", true)
	# 정상 세이브는 한 바이트도 바뀌지 않음
	store.call("clear")
	var raw0: Dictionary = {}
	var good: Dictionary = fx["sanctuary"][1]["after"]
	for k: String in good.keys():
		raw0[k] = JsonX.stringify(good[k]) if typeof(good[k]) != TYPE_STRING else good[k]
	for k2: String in raw0.keys():
		store.call("set_str", k2, raw0[k2])
	var ch := SaveSanitize.sanitize(_rc())
	var same := true
	for k3: String in raw0.keys():
		if str(store.call("get_str", k3)) != str(raw0[k3]):
			same = false
			print("    정상 세이브가 바뀜: %s" % k3)
	_check(same and ch.is_empty(), "정상 세이브(성소 뒤 · 무료 부활 시각 · 영혼석 · 룬 · 전직서 · 스킬북)는 다듬기에서 한 바이트도 안 바뀜 (%s)" % str(ch))
	# 왕복: 성소·아카데미에서 바꾼 세이브를 웹이 읽음
	_base_save()
	var c := _rc()
	Sanc.revive(c, 31)
	Sanc.ad_revive(c, 7)
	Sanc.soul_combine(c, "mage")
	Sanc.promote(c, 12, [11, 13])
	Sanc.rune_apply(c, fx["sanctuary"][0]["store"]["game_inventory"][0]["eid"], "fire")
	Sanc.rename(c, 1, "새 이름")
	var pv := Acad.preview(c, Profile.get_char(c, 6), "archer")
	Acad.change_class(c, 6, pv, Acad.usable_scrolls(c)[0]["idx"])
	Acad.use_book(c, _book_idx(c, "mage_freeze"), 4, {"id": "mage_freeze", "cls": "mage"})
	_roundtrip("성소·아카데미 뒤")
	# 손으로 만든 이상한 값
	var base: Dictionary = fx["sanctuary"][0]["store"]
	var cases: Array = [
		{Sanc.AD_KEY: "abc"}, {Sanc.AD_KEY: "{}"}, {"game_soul": "[1]"}, {"game_soul": JsonX.stringify({"stones": {"mage": "x", "warrior": -3}, "frags": {"mage": [1], "knight": 1e9}})},
		{"game_inventory": JsonX.stringify([{"type": "scroll", "scrollCls": 5}, {"type": "scroll", "scrollCls": "commander"}, {"type": "scroll"}, {"id": 5, "cls": "mage", "lv": 1}, {"id": "x", "cls": "nope", "lv": 1},
			{"id": "mage_freeze", "cls": "mage"}, {"type": "rune", "enchant": "nope"}, {"type": "equip", "eid": "q", "slot": "ring", "rarity": "nope", "stats": {}, "templateId": "ring_power", "equipped": 9999, "enchant": "zzz"}])},
		{"game_roster": JsonX.stringify({"chars": [{"uid": 1, "cls": "novice", "lv": "x", "pot": [], "dead": "yes"}, {"uid": 2, "cls": "mage", "skillLv": {"mage_freeze": "x"}}, {"uid": 3, "cls": "warrior", "dead": true, "diedAt": "x", "lv": -4}], "nextId": "z"})},
		{"game_parties": "5"}, {"gd_class_preview": "[1]"}, {"gd_class_preview": JsonX.stringify({"6": {"fp": {"lv": 14, "pot": {}}, "cls": {"archer": {"hp": "x"}, "mage": 5}}, "zz": 1, "8": []})},
		{"gd_battle": "{\"format\":2,\"sum\":\"00000000000000000000000000000000\",\"cfg\":{},\"state\":{}}"},
	]
	var bad: Array = []
	for i in cases.size():
		var raw: Dictionary = {}
		for k5: String in base.keys():
			raw[k5] = JsonX.stringify(base[k5])
		raw.merge(cases[i], true)
		var r: Array = await _try(raw)
		if int(r[0]) > 0 or not (r[1] as Array).is_empty():
			bad.append("[손 %d] 오류 %d · 진입 실패 %s" % [i, r[0], str(r[1])])
	_check(bad.is_empty(), "손으로 만든 이상한 세이브 %d개: 성소·아카데미·로비의 화면·창·단추 모두 오류 0" % cases.size())
	var n := 50
	var fbad: Array = []
	for j in n:
		_rng.seed = 7000 + j
		var r2: Array = await _try(_fuzz())
		if int(r2[0]) > 0 or not (r2[1] as Array).is_empty():
			fbad.append("[시드 %d] 오류 %d · 진입 실패 %s" % [7000 + j, r2[0], str(r2[1])])
	for b: String in (bad + fbad).slice(0, 20):
		print("    " + b)
	_check(fbad.is_empty(), "무작위로 망가뜨린 세이브 %d개: 오류 0 (문제 %d)" % [n, fbad.size()])
	# 도감·가이드·크레딧·라이선스는 세이브를 읽지 않음 — 이상한 세이브에서도 열림
	var e0 := _counter.errors.size()
	for sc: String in ["compendium", "guide", "credits", "licenses"]:
		var nd: Node = (load("res://scenes/outer/%s.tscn" % sc) as PackedScene).instantiate()
		root.add_child(nd)
		await process_frame
		nd.queue_free()
		await process_frame
	_check(_counter.errors.size() == e0, "이상한 세이브에서 도감·가이드·크레딧·라이선스 오류 0")
	_stat("weird.manual", cases.size())
	_stat("weird.fuzz", n)
	router.set("dry_run", router_dry)
	store.call("clear")


# ═══════════ 8) 6개 언어 넘침·두부 ═══════════

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
		if nd.get_meta("overflow_ok", false) or nd.is_queued_for_deletion() or str(nd.name) == "Hideout":
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
				if cp < 32 or cp == 0x200B or cp == 0xFFFC:
					continue
				if not FontsT.chain_has_char(lang, cp):
					tofu.append("%s '%s' U+%04X" % [ctl.get_path(), txt.substr(0, 20), cp])
					break
		if ctl is Label:
			var l := ctl as Label
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF and not l.clip_text and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
				if l.get_minimum_size().x > l.size.x + 1.0:
					overflow.append("%s 좁음 %.0f>%.0f '%s'" % [ctl.get_path(), l.get_minimum_size().x, l.size.x, l.text.substr(0, 24)])
		var par := ctl.get_parent() as Control
		if par != null and not (par is ScrollContainer) and ctl.size.x > 0.0 and not (ctl is ScrollContainer and par.name == "Box"):
			var pr := par.get_global_rect().grow(3.0)
			var r := ctl.get_global_rect()
			if not pr.encloses(r) and r.size.x > 0.0:
				overflow.append("%s 부모 밖 %s ⊄ %s '%s'" % [ctl.get_path(), str(r), str(pr), txt.substr(0, 20)])
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


## 넘침이 잘 드러나는 세이브: 긴 이름 · 영혼석 · 룬 많이 · 전직서 · 스킬북 · 저장 전투
func _rich_save() -> void:
	_base_save()
	var r: Dictionary = store.call("get_json", "game_roster")
	for ch: Dictionary in r["chars"]:
		if int(ch["uid"]) == 12:
			ch["customName"] = "가나다라마바사아자차"
		if int(ch["uid"]) == 11:
			ch["customName"] = "WWWWWWWWWW"
	store.call("set_json", "game_roster", r)
	store.call("set_json", "game_save", {"gold": 1234567, "cleared": [1, 2, 3]})
	store.call("set_json", "game_soul", {"stones": {"warrior": 12, "knight": 3, "mage": 99}, "frags": {"mage": 123, "knight": 9, "priest": 15, "archer": 30, "assassin": 2}})


func _langs() -> void:
	var all: Array = []
	var total := [0]
	router.set("dry_run", true)
	var add := func(scr: Node, lang: String, res: Vector2i, what: String) -> void:
		var a: Array = _audit(scr, lang)
		total[0] += int(a[2])
		for o: String in a[0]:
			all.append("[%dx%d %s %s] 넘침 %s" % [res.x, res.y, lang, what, o])
		for tf: String in a[1]:
			all.append("[%dx%d %s %s] 두부 %s" % [res.x, res.y, lang, what, tf])
	for res: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = res
		for lang: String in LANGS:
			_rich_save()
			i18n.call("_apply", lang)
			# 성소: 4탭 + 창 (무료 부활 · 제물 · 승급 확인 · 개명 · 마법부여 확인 · 결과 알림)
			router.set("params", {})
			var sa: Node = (load("res://scenes/outer/sanctuary.tscn") as PackedScene).instantiate()
			root.add_child(sa)
			await _frames(3)
			for stt: String in ["resurrect", "ad", "promote", "sac", "sac_confirm", "rename", "rename_modal", "enchant", "enchant_confirm", "promote_result"]:
				sa.close_all_modals()
				match stt:
					"resurrect", "promote", "rename", "enchant":
						sa.switch_tab(stt)
					"ad":
						sa.open_ad_revive()
					"sac":
						sa.switch_tab("promote")
						sa.open_sacrifice(12)
						sa.toggle_sacrifice(13)
					"sac_confirm":
						sa.open_sacrifice(12)
						sa.toggle_sacrifice(13)
						sa.confirm_promote()
					"rename_modal":
						sa.open_rename(12)
					"enchant_confirm":
						sa.switch_tab("enchant")
						sa._act_frame = -1
						sa.ask_enchant(str(fx["sanctuary"][0]["store"]["game_inventory"][1]["eid"]), "fire")
					"promote_result":
						sa.switch_tab("promote")
						sa._act_frame = -1
						sa.do_promote(42, [41])
				await _frames(3)
				add.call(sa, lang, res, "sanctuary." + stt)
			sa.queue_free()
			await _frames(2)
			_rich_save()
			var ac: Node = (load("res://scenes/outer/academy.tscn") as PackedScene).instantiate()
			root.add_child(ac)
			await _frames(3)
			for stt2: String in ["classchange", "scrolls", "confirm", "skillbook", "targets", "book_confirm"]:
				ac.close_all_modals()
				match stt2:
					"classchange", "skillbook":
						ac.switch_tab(stt2)
					"scrolls":
						ac.open_scrolls(6)
					"confirm":
						ac.confirm_change(6, "archer", 6)
					"targets":
						var b0: Dictionary = Acad.books(_rc())[0]
						ac.open_book(int(b0["idx"]), b0["item"])
					"book_confirm":
						var b1: Dictionary = Acad.books(_rc())[0]
						ac.confirm_book(int(b1["idx"]), b1["item"], 41)
				await _frames(3)
				add.call(ac, lang, res, "academy." + stt2)
			ac.queue_free()
			await _frames(2)
			# 도감: 4탭 · 장비 거르기(등급·강화 표 · 전설 · 직업 세트) · 직업 창 (모든 직업) · 스크롤 아래(붙는 탭)
			var cp: Node = (load("res://scenes/outer/compendium.tscn") as PackedScene).instantiate()
			root.add_child(cp)
			await _frames(3)
			for stt3: String in ["cls", "gear", "gear_rule", "gear_legend", "gear_set", "cons", "stage", "sticky", "sheets"]:
				cp.close_all_modals()
				match stt3:
					"cls", "gear", "cons", "stage":
						cp.switch_tab(stt3)
					"gear_rule", "gear_legend", "gear_set":
						cp.switch_tab("gear")
						cp.set_filter(stt3.trim_prefix("gear_"))
					"sticky":
						cp.switch_tab("cls")
						await _frames(2)
						cp.page_scroll.scroll_vertical = 2000
				await _frames(3)
				if stt3 == "sheets":
					for cls: String in CodexRules.PLAYER_CLASSES:
						cp.open_class(cls)
						await _frames(3)
						add.call(cp, lang, res, "compendium.sheet." + cls)
						cp.close_all_modals()
				else:
					add.call(cp, lang, res, "compendium." + stt3)
			cp.queue_free()
			await _frames(2)
			var gd: Node = (load("res://scenes/outer/guide.tscn") as PackedScene).instantiate()
			root.add_child(gd)
			await _frames(3)
			for gt: String in CodexRules.GUIDE_TABS:
				gd.switch_tab(gt)
				# 접는 칸 모두 펴기 (구간 공략 · 스포일러)
				var stack: Array = [gd.current_panel()]
				while not stack.is_empty():
					var nn: Node = stack.pop_back()
					if nn.has_meta("acc"):
						gd.view.set_open(nn, true)
					stack.append_array(nn.get_children())
				await _frames(3)
				add.call(gd, lang, res, "guide." + gt)
			gd.queue_free()
			await _frames(2)
			for sc: String in ["credits", "licenses"]:
				var nd: Node = (load("res://scenes/outer/%s.tscn" % sc) as PackedScene).instantiate()
				root.add_child(nd)
				await _frames(3)
				if sc == "licenses":
					for b: Node in nd.find_children("*Btn", "Button", true, false):
						(b as Button).pressed.emit()
					await _frames(3)
				add.call(nd, lang, res, sc)
				nd.queue_free()
				await _frames(2)
			# 로비: 포기 단추 · 포기 확인 · 이전 판 안내
			_make_gd()
			_rich_save_keep_gd()
			var lb: Node = (load("res://scenes/outer/lobby.tscn") as PackedScene).instantiate()
			root.add_child(lb)
			await _frames(3)
			if lb.get("setup_dialog") != null:
				lb.commander_setup_done()
			lb._act_frame = -1
			lb.ask_abandon()
			await _frames(3)
			add.call(lb, lang, res, "lobby.abandon")
			lb.close_all_modals()
			var ov := ResumeRules.current_stamp()
			ov["gameVersion"] = "x"
			ResumeRules.stamp_override = ov
			lb._act_frame = -1
			lb.press_resume()
			await _frames(3)
			add.call(lb, lang, res, "lobby.old")
			ResumeRules.stamp_override = {}
			lb.queue_free()
			await _frames(2)
	for p: String in all.slice(0, 40):
		print("    " + p)
	var ovf := 0
	var tf5 := 0
	for p2: String in all:
		if p2.contains("] 두부"):
			tf5 += 1
		else:
			ovf += 1
	_check(ovf == 0, "6개 언어 × 1280×720·1920×1080 넘침 0 (성소 10 · 아카데미 6 · 도감 8+직업 창 12 · 가이드 7 · 크레딧 · 라이선스 · 로비 2 상태, 글자 부품 %d개 검사, 넘침 %d)" % [total[0], ovf])
	_check(tf5 == 0, "6개 언어 두부 0 (RichText 글 포함, 두부 %d)" % tf5)
	_stat("lang.text_controls", total[0])
	_stat("lang.overflow", ovf)
	root.size = Vector2i(1280, 720)
	i18n.call("_apply", "ko")
	router.set("dry_run", false)
	store.call("clear")


## _make_gd 가 Store 를 황금 기록 세이브로 바꾸므로, 저장 전투만 남기고 넘침용 세이브로
func _rich_save_keep_gd() -> void:
	var gdraw: Variant = store.call("get_str", ResumeRules.KEY)
	_rich_save()
	if gdraw != null:
		store.call("set_str", ResumeRules.KEY, gdraw)


# ═══════════ 9) '준비 중' 없음 ═══════════

func _nosoon() -> void:
	var hits: Array = []
	for dir: String in ["res://scripts/ui", "res://scripts/battle", "res://scripts/core"]:
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir.path_join(f))
			if src.contains("coming_soon()") or src.contains("gd.outer.coming_soon") or src.contains("func coming_soon"):
				hits.append(f)
	_check(hits.is_empty(), "화면 코드에 '준비 중' 알림(coming_soon) 없음 %s" % str(hits))
	var extra_ok := true
	for lang: String in LANGS:
		var d: Variant = JsonX.parse(FileAccess.get_file_as_string("res://data/lang_extra/%s.json" % lang))
		if d is Dictionary and (d["gd"] as Dictionary).has("outer"):
			extra_ok = false
	_check(extra_ok, "번역에 gd.outer.coming_soon 없음 (6개 언어)")
	var R: Dictionary = router.get("SCREENS")
	var need := ["sanctuary", "academy", "compendium", "guide", "credits", "licenses"]
	var ok := true
	for k: String in need:
		ok = ok and R.has(k) and ResourceLoader.exists(R[k])
	_check(ok, "Router 화면 6개 (성소 · 아카데미 · 도감 · 가이드 · 크레딧 · 라이선스) 장면 있음")
	# 상점 광고 단추의 '추후 개발'(common.coming_soon)은 웹과 같은 꺼진 단추 — 일부러 남김 (보고서)
	var shop_src := FileAccess.get_file_as_string("res://scripts/ui/shop.gd")
	_check(shop_src.contains("common.coming_soon"), "상점 광고 단추 '추후 개발'은 웹(js/shop.js)과 같은 꺼진 단추로 남김 (Godot '준비 중' 안내 아님)")
