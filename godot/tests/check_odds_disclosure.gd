extends SceneTree
## 확률형 아이템 표시 시험 (게임산업법 확률정보 · Google Play 결제 정책 · App Store 3.1.1)
##   Godot --headless --path godot --script res://tests/check_odds_disclosure.gd   [-- --only pct,inline,near,gold,settings,tables,mc,lang]
##  1) pct      : 반올림 규칙 (0이 아닌 첫 자리보다 4자리 아래에서만) · 4.5% 가 5% 가 되지 않음
##  2) inline   : 상점 인라인 확률(등급 5개) = 확률 창 표의 값 = 데이터 · 합계 정확히 100%
##  3) near     : 구매 지점 근처 — 장비 뽑기 2·룬 뽑기 카드에 확률 요약 + '확률 보기' 단추(구매 단추 위), 단추가 확률 창을 엶 · 모바일 터치 크기
##  4) gold     : 골드 탭·구매 확인 창의 '골드는 확률형 뽑기·강화에 쓰입니다' 안내 6개 언어
##  5) settings : 설정 화면 '확률 정보' 단추 → 확률 창 (모든 구역의 글 = 표)
##  6) tables   : 새 구역(천장·종류별·전설별·강화 옵션·고유 효과·능력치 범위)의 값 = 데이터에서 독립 계산한 값, 합계 100%
##  7) mc       : 규칙 코드(gear.gd)로 직접 뽑은 빈도 = 표 (종류별 · 전설별 · 강화 옵션 · 고유 효과 · 능력치 범위 끝값)
##  8) lang     : 6개 언어 — 새 문구 키 · 자리표시자 일치 · 하드코딩 확률 숫자 없음 · 스페인어 천장 용어 · 번역 빠짐/찌꺼기 없음 · 길이
##  Godot 오류(Logger 로 셈) 0 이어야 통과. 저장은 user://test_odds_save.json

const Ctx := preload("res://scripts/logic/ctx.gd")
const StoreCtx := preload("res://scripts/logic/store_ctx.gd")
const OddsRules := preload("res://scripts/logic/odds_rules.gd")
const ShopRules := preload("res://scripts/logic/shop_rules.gd")
const Gear := preload("res://scripts/logic/gear.gd")
const Js := preload("res://scripts/logic/js.gd")
const CodexRules := preload("res://scripts/logic/codex_rules.gd")
const Files := preload("res://scripts/core/billing/fake_files.gd")

const SAVE := "user://test_odds_save.json"
const LANGS := ["ko", "en", "es", "ja", "zh-CN", "zh-TW"]
## 문구 키 (점으로 이은 경로) — 모든 언어에 있어야 하고 자리표시자가 같아야 함
const KEYS_SINGLE := ["gd.iap.gold_use", "gear.enh_break", "codex.g.break_p", "codex.c.eopt_note", "shop.gacha_pity"]

var _fails: Array = []
var _passes := 0
var _counter: ErrCounter
var _only: Array = []
var _stats: Dictionary = {}
var store: Node
var i18n: Node
var router: Node
var platform: Node
var billing
var db: Node


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
		print("  ok   " + what)
	else:
		_fails.append(what)
		print("  FAIL " + what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, secs: float = 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await process_frame
	return cond.call()


func _want(name: String) -> bool:
	return _only.is_empty() or _only.has(name)


func _screen_is(tail: String) -> bool:
	var s := current_scene
	return s != null and s.get_script() != null and str((s.get_script() as Script).resource_path).ends_with(tail) and s.is_node_ready()


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var oi := args.find("--only")
	if oi >= 0 and oi + 1 < args.size():
		_only = Array(args[oi + 1].split(","))
	store = root.get_node("Store")
	i18n = root.get_node("I18n")
	router = root.get_node("Router")
	platform = root.get_node("Platform")
	billing = root.get_node("Billing")
	db = root.get_node("DataDB")
	store.call("use_path", SAVE)
	store.call("clear")
	platform.call("override_store", "dev")
	billing.call("_ensure_backend")
	Files.reset()
	i18n.call("_apply", "ko")
	root.size = Vector2i(1280, 720)
	billing.set_scenario("success")
	for sec: Array in [["pct", "1) 반올림 규칙"], ["inline", "2) 상점 인라인 확률 = 확률 창 = 데이터"], ["near", "3) 구매 지점 근처 표시"], ["gold", "4) 골드 구매 안내"],
			["settings", "5) 설정 > 확률 정보"], ["tables", "6) 새 구역 값 = 데이터"], ["mc", "7) 규칙 코드로 뽑은 빈도 = 표"], ["lang", "8) 6개 언어 문구"]]:
		if not _want(sec[0]):
			continue
		print("── %s ──" % sec[1])
		await call("_t_" + str(sec[0]))
	platform.call("override_store", "")
	platform.call("emulate_mobile", false, "")
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Files.reset()
	await _frames(2)
	_check(_counter.errors.is_empty(), "Godot 오류 0 (%d)" % _counter.errors.size())
	for e: String in _counter.errors.slice(0, 12):
		print("    " + e)
	var keys := _stats.keys()
	keys.sort()
	for k: String in keys:
		print("  STAT %s = %s" % [k, str(_stats[k])])
	if _fails.is_empty():
		print("RESULT: PASS (%d개 통과)" % _passes)
		quit(0)
	else:
		print("RESULT: FAIL (%d개 통과, %d개 실패)" % [_passes, _fails.size()])
		for f: String in _fails:
			print("  - " + f)
		quit(1)


func _ctx(seed: int = 7) -> Object:
	return Ctx.new(Ctx.globals_from_db(db), seed, StoreCtx.new(store))


func _mem_ctx(seed: int = 7) -> Object:
	return Ctx.new(Ctx.globals_from_db(db), seed)


func _tfn() -> Callable:
	return func(k: String, p: Dictionary) -> String: return str(i18n.call("t", k, p))


## "4.5%" → 4.5 (퍼센트 숫자)
func _num(s: String) -> float:
	return float(s.trim_suffix("%"))


## pct() 와 따로 만든 숫자 글 — 소수 9자리까지 반올림하고 끝의 0 을 지움 (4.5% · 0.05% 처럼 정확히 떨어지는 값 비교용)
func _exact(rate: float) -> String:
	var s := String.num(snappedf(rate * 100.0, 1e-9), 9)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s + "%"


# ═══════════ 1) 반올림 규칙 ═══════════

func _t_pct() -> void:
	_check(OddsRules.pct(0.045) == "4.5%" and OddsRules.pct(0.0045) == "0.45%" and OddsRules.pct(0.0005) == "0.05%" and OddsRules.pct(0.6) == "60%" and OddsRules.pct(0.35) == "35%",
		"등급 확률 60 · 35 · 4.5 · 0.45 · 0.05 (5% · 0.5% 로 반올림하지 않음)")
	_check(OddsRules.pct(1.0 / 12.0) == "8.333%" and OddsRules.pct(0.0005 / 19.0) == "0.002632%" and OddsRules.pct(0.0) == "0%" and OddsRules.pct(1.0) == "100%",
		"8.333% · 0.002632% (0.003% 로 줄이지 않음) · 0% · 100%")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var worst := 0.0
	for i in 4000:
		var r := pow(10.0, rng.randf_range(-7.0, 0.0))
		var s := OddsRules.pct(r)
		var back := _num(s) / 100.0
		worst = maxf(worst, absf(back - r) / r)
	_check(worst < 6e-4, "무작위 4000개: 보이는 값의 상대 오차 ≤ 0.06%% (유효숫자 4자리 이상, 최대 %s)" % str(snappedf(worst, 1e-6)))
	_stats["pct.worst_rel_err"] = snappedf(worst, 1e-7)


# ═══════════ 2) 상점 인라인 = 확률 창 = 데이터 ═══════════

func _t_inline() -> void:
	var c := _mem_ctx()
	var GR: Dictionary = c.D["GACHA_RATE"]
	var raw := 0.0
	for v: Variant in GR.values():
		raw += float(v)
	var rates := ShopRules.gacha_rates(c)
	var secs := OddsRules.sections(c, _tfn())
	var g: Dictionary = secs[0]
	var ok := rates.size() == GR.size()
	var sum := 0.0
	var i := 0
	var shown: Array = []
	for r: String in GR.keys():
		ok = ok and rates[i][0] == r and rates[i][1] == _exact(float(GR[r]) / raw) and rates[i][1] == g["rows"][i][1]
		sum += _num(rates[i][1])
		shown.append(rates[i][1])
		i += 1
	_check(ok, "ShopRules.gacha_rates = 데이터 확률 = 확률 창 표 1열 (%s)" % " / ".join(shown))
	_check(absf(sum - 100.0) < 1e-9, "인라인 확률 합계 = 100%% (%s)" % str(sum))
	# 실제 상점 화면의 글
	_reset_save(5000.0)
	var sh := await _open_shop("equip")
	var rp: Node = sh.list.find_child("Rates", true, false)
	var texts: Array = []
	if rp != null:
		for ch: Node in rp.find_children("*", "Label", true, false):
			texts.append((ch as Label).text)
	var want: Array = []
	for j in rates.size():
		want.append("%s %s" % [i18n.call("t", "equip.rarity." + str(rates[j][0])), rates[j][1]])
	_check(texts == want, "상점 장비 탭 확률 줄의 글 = 표 (%s)" % " | ".join(texts))
	var tot := 0.0
	for tx: String in texts:
		tot += _num(tx.get_slice(" ", tx.count(" ")))
	_check(absf(tot - 100.0) < 1e-9, "화면에 보이는 숫자를 더하면 정확히 100%% (%s)" % str(tot))
	_check(not "\n".join(texts).contains("5%") or "\n".join(texts).contains("4.5%"), "'희귀 5%'(반올림 오류) 없음")


# ═══════════ 3) 구매 지점 근처 ═══════════

func _t_near() -> void:
	_reset_save(50000.0)
	var sh := await _open_shop("equip")
	for nm: String in ["Gacha1", "Gacha10"]:
		var card: Node = sh.list.find_child(nm, true, false)
		await _near_check(sh, card, nm)
	sh.switch_tab("consumable")
	await _frames(3)
	var rc: Node = sh.list.find_child("RuneCard", true, false)
	await _near_check(sh, rc, "RuneCard")
	var line: Label = rc.find_child("OddsLine", true, false)
	var ru := OddsRules.rune(_mem_ctx())
	_check(line != null and line.text.contains(OddsRules.pct(float(ru["rows"][0]["rate"]))) and line.text.contains(str((ru["rows"] as Array).size())), "룬 카드 요약: 종류 수와 각 확률 (%s)" % (line.text if line != null else ""))
	# 단추 → 확률 창 (룬 카드 · 뽑기 카드 모두)
	(rc.find_child("OddsLink", true, false) as Button).pressed.emit()
	await _frames(3)
	_check(sh.find_child("Layer", true, false).find_child("OddsModal", true, false) != null, "룬 카드 '확률 보기' → 확률 창")
	sh.close_all_modals()
	await _frames(2)
	sh.switch_tab("equip")
	await _frames(3)
	sh._act_frame = -1
	(sh.list.find_child("Gacha10", true, false).find_child("OddsLink", true, false) as Button).pressed.emit()
	await _frames(3)
	var m: Node = sh.find_child("Layer", true, false).find_child("OddsModal", true, false)
	_check(m != null and m.find_child("Grid_pity", true, false) != null and m.find_child("Grid_kinds", true, false) != null, "10+1 카드 '확률 보기' → 천장·종류별 표까지 있는 확률 창")
	sh.close_all_modals()
	# 모바일 흉내: 터치 대상 44pt · 글자 12pt 이상
	platform.call("emulate_mobile", true, "pixel8")
	root.size = Vector2i(1067, 480)
	root.get_node("Mobile").call("apply")
	await _frames(3)
	router.call("go", "lobby")
	await _frames(4)
	sh = await _open_shop("equip")
	await _frames(4)
	var mob: Node = root.get_node("Mobile")
	var min_t := float(mob.call("min_target"))
	var min_f := int(mob.call("min_font"))
	var bad: Array = []
	for nm2: String in ["Gacha1", "Gacha10"]:
		var card2: Node = sh.list.find_child(nm2, true, false)
		for ln: Node in [card2.find_child("OddsLink", true, false), card2.find_child("Buy", true, false)]:
			var b := ln as Button
			if b.size.y + 0.5 < min_t or b.size.x + 0.5 < min_t:
				bad.append("%s %s %s<%s" % [nm2, b.name, str(b.size), str(min_t)])
		var ol := card2.find_child("OddsLine", true, false) as Label
		if ol.get_theme_font_size("font_size") < min_f:
			bad.append("%s 글자 %d<%d" % [nm2, ol.get_theme_font_size("font_size"), min_f])
	sh.switch_tab("consumable")
	await _frames(4)
	var rc2: Node = sh.list.find_child("RuneCard", true, false)
	var rb := rc2.find_child("OddsLink", true, false) as Button
	if rb.size.y + 0.5 < min_t or rb.size.x + 0.5 < min_t:
		bad.append("RuneCard OddsLink %s<%s" % [str(rb.size), str(min_t)])
	_check(bad.is_empty(), "pixel8 흉내: 확률 보기·구매 단추 ≥ %.0fpx(44pt) · 확률 요약 글자 ≥ %d %s" % [min_t, min_f, str(bad)])
	# 스페인어(가장 긴 등급 이름)에서도 확률 줄이 카드 열 안에 들어옴
	i18n.call("_apply", "es")
	sh.switch_tab("equip")
	await _frames(5)
	var rcard := sh.list.find_child("Rates", true, false) as Control
	var lr: Rect2 = sh.list.get_global_rect()
	var rr: Rect2 = rcard.get_global_rect()
	_check(rr.position.x >= lr.position.x - 1.0 and rr.end.x <= lr.end.x + 1.0, "pixel8 es: 확률 줄 카드가 목록 폭 안 (%s ⊂ %s)" % [str(rr), str(lr)])
	i18n.call("_apply", "ko")
	router.call("go", "lobby")
	await _frames(3)
	platform.call("emulate_mobile", false, "")
	root.size = Vector2i(1280, 720)
	root.get_node("Mobile").call("apply")
	await _frames(2)


func _near_check(sh: Node, card: Node, nm: String) -> void:
	var line: Label = card.find_child("OddsLine", true, false) if card != null else null
	var link: Button = card.find_child("OddsLink", true, false) if card != null else null
	var buy: Button = card.find_child("Buy", true, false) if card != null else null
	var ok := line != null and link != null and buy != null
	if ok:
		ok = line.get_global_rect().position.y < link.get_global_rect().position.y and link.get_global_rect().position.y < buy.get_global_rect().position.y
	_check(ok, "%s: 확률 요약 · '확률 보기' 단추가 구매 단추 바로 위 (같은 카드 안)" % nm)
	if line != null and nm != "RuneCard":
		var c := _mem_ctx()
		var GR := OddsRules.rarity_rates(c, "rare" if nm == "Gacha10" else null)
		var has_all := true
		for r: Dictionary in GR:
			if float(r["rate"]) > 0.0:
				has_all = has_all and line.text.contains(OddsRules.pct(float(r["rate"])))
		_check(has_all and line.text.contains(str(int(c.D["GACHA_PITY_MAX"]))) and not line.text.contains("{"), "%s 요약에 등급별 확률 전부 + 천장 횟수: %s" % [nm, line.text])


# ═══════════ 4) 골드 구매 안내 ═══════════

func _t_gold() -> void:
	for lang: String in LANGS:
		i18n.call("_apply", lang)
		_reset_save(1000.0)
		var sh := await _open_shop("gold")
		var note: Label = sh.list.find_child("GoldUseNote", true, false)
		var want := str(i18n.call("t", "gd.iap.gold_use", {}))
		var ob: Button = sh.find_child("OddsBtn", true, false)
		_check(note != null and note.text == want and want != "" and not want.begins_with("gd."), "[%s] 골드 탭: 안내 글 (%d자)" % [lang, want.length()])
		_check(ob.visible and sh.list.find_child("OddsLink", true, false) != null, "[%s] 골드 탭: '확률' 단추 (상단 + 안내 카드)" % lang)
		sh._act_frame = -1
		sh.buy_iap("gold_500")
		await _frames(3)
		var cm: Node = sh.find_child("Layer", true, false).find_child("IapConfirmModal", true, false)
		var n2: Label = cm.find_child("GoldUseNote", true, false) if cm != null else null
		_check(n2 != null and n2.text == want and cm.find_child("Notice", true, false) != null, "[%s] 구매 확인 창: 안내 글 + 기존 법정 안내 그대로" % lang)
		sh.close_all_modals()
		await _frames(2)
	i18n.call("_apply", "ko")


# ═══════════ 5) 설정 ═══════════

func _t_settings() -> void:
	_reset_save(1000.0)
	router.call("go", "settings")
	await _until(func() -> bool: return _screen_is("ui/settings_screen.gd"), 5.0)
	await _frames(4)
	var ss := current_scene
	var b: Button = ss.find_child("OddsInfo", true, false)
	_check(b != null and b.text == str(i18n.call("t", "gd.odds.title", {})), "설정 화면에 '확률 정보' 단추")
	b.pressed.emit()
	await _frames(3)
	var secs := OddsRules.sections(_mem_ctx(), _tfn())
	_check(_odds_matches(ss, secs), "설정 > 확률 정보 창의 글 = 표 (%d개 구역 · 머리·칸 모두)" % secs.size())
	ss.close_all_modals()
	router.call("go", "lobby")
	await _frames(3)


func _odds_matches(scr: Node, secs: Array) -> bool:
	var m: Node = scr.find_child("Layer", true, false).find_child("OddsModal", true, false)
	if m == null:
		return false
	for sec: Dictionary in secs:
		var gd: GridContainer = m.find_child("Grid_" + str(sec["id"]), true, false)
		if gd == null:
			print("    구역 없음 " + str(sec["id"]))
			return false
		var want: Array = (sec["head"] as Array).duplicate()
		for row: Array in sec["rows"]:
			if row.size() != (sec["head"] as Array).size():
				print("    줄 칸 수 다름 %s: %d ≠ %d" % [sec["id"], row.size(), (sec["head"] as Array).size()])
				return false
			want.append_array(row)
		var got: Array = []
		for ch: Node in gd.get_children():
			got.append((ch as Label).text)
		if got != want:
			print("    표 다름 %s" % sec["id"])
			return false
	return true


# ═══════════ 6) 새 구역 값 = 데이터 ═══════════

func _sec(secs: Array, id: String) -> Dictionary:
	for s: Dictionary in secs:
		if s["id"] == id:
			return s
	return {}


func _t_tables() -> void:
	var c := _mem_ctx()
	var tfn := _tfn()
	var secs := OddsRules.sections(c, tfn)
	var ids: Array = secs.map(func(s: Dictionary) -> String: return str(s["id"]))
	_check(ids.slice(0, 3) == ["gacha", "rune", "enhance"] and ids.has("pity") and ids.has("kinds") and ids.has("legends") and ids.has("enh_opt_1") and ids.has("enh_opt_4")
		and ids.has("class_opt") and ids.has("stat_base") and ids.has("stat_sub"), "구역: 기존 3개 + 천장·종류별·전설별·강화 옵션 4단계·직업 옵션·능력치 범위 2개 (%s)" % ",".join(ids))
	var GR: Dictionary = c.D["GACHA_RATE"]
	var raw := 0.0
	for v: Variant in GR.values():
		raw += float(v)
	var hi := float(GR["rare"]) + float(GR["epic"]) + float(GR["legendary"])   # 10+1 마지막 장비는 희귀 이상만
	# 천장 표
	var py := _sec(secs, "pity")
	var mx := int(c.D["GACHA_PITY_MAX"])
	var p0: Array = py["rows"][0]
	var p1: Array = py["rows"][1]
	var ok: bool = p0.size() == GR.size() + 1 and p1.size() == GR.size() + 1 and str(p1[0]).contains(str(mx))
	var j := 1
	for r: String in GR.keys():
		ok = ok and p0[j] == _exact(float(GR[r]) / raw) and p1[j] == ("100%" if r == "legendary" else "0%")
		j += 1
	_check(ok, "천장 표: 1~%d회째 = 평소 확률 · %d회째 전설 100%% (나머지 0%%)" % [mx - 1, mx])
	# 종류별
	var kd := _sec(secs, "kinds")
	var n := (c.D["EQUIP_DB"] as Array).size()
	var rows: Array = kd["rows"]
	ok = rows.size() == n + 1
	var names: Dictionary = {}
	var rar: Array = GR.keys().filter(func(r: String) -> bool: return r != "legendary")
	for i in n:
		var row: Array = rows[i]
		names[row[0]] = true
		for k in rar.size():
			ok = ok and row[1 + k] == OddsRules.pct(float(GR[rar[k]]) / raw / float(n))
		ok = ok and row[row.size() - 2] == OddsRules.pct(float(GR["rare"]) / hi / float(n)) and row[row.size() - 1] == OddsRules.pct(float(GR["epic"]) / hi / float(n))
	_check(ok and names.size() == n, "종류별 표: %d종 각 칸 = 등급 확률 ÷ %d · 이름 겹침/빠짐 없음" % [n, n])
	var sum_row: Array = rows[n]
	ok = true
	for k in rar.size():
		ok = ok and sum_row[1 + k] == _exact(float(GR[rar[k]]) / raw)
	_check(ok and sum_row[sum_row.size() - 2] == _exact(float(GR["rare"]) / hi) and sum_row[sum_row.size() - 1] == _exact(float(GR["epic"]) / hi), "종류별 합계 줄 = 등급 확률 (60/35/4.5/0.45, 10+1 마지막 90/9) — 전설은 전설 표")
	# 전설별
	var lg := _sec(secs, "legends")
	var L := (c.D["LEGENDS"] as Dictionary).size()
	var lrows: Array = lg["rows"]
	ok = lrows.size() == L + 1
	for i in L:
		ok = ok and lrows[i][1] == OddsRules.pct(float(GR["legendary"]) / raw / float(L)) and lrows[i][2] == OddsRules.pct(float(GR["legendary"]) / hi / float(L)) and lrows[i][3] == OddsRules.pct(1.0 / float(L)) and lrows[i][4] != "-"
	_check(ok and lrows[L][1] == _exact(float(GR["legendary"]) / raw) and lrows[L][2] == _exact(float(GR["legendary"]) / hi) and lrows[L][3] == "100%", "전설별 표: %d종 각 = 전설 확률 ÷ %d · 합계 0.05%% / 1%% / 100%%" % [L, L])
	# 강화 옵션 단계
	var bands := OddsRules.enhance_opts(c)
	ok = bands.size() == (c.D["ENHANCE_OPT"] as Array).size()
	for bi in bands.size():
		var s := _sec(secs, "enh_opt_%d" % (bi + 1))
		var b: Dictionary = bands[bi]
		var rr: Array = s["rows"]
		var tot := 0.0
		for q in (b["rows"] as Array).size():
			tot += float(b["rows"][q]["share"])
			ok = ok and rr[q][1] == OddsRules.pct(float(b["rows"][q]["share"])) and rr[q][2] == OddsRules.pct(float(b["chance"]) * float(b["rows"][q]["share"]))
		ok = ok and absf(tot - 1.0) < 1e-9 and rr.back()[1] == "100%" and rr.back()[2] == OddsRules.pct(float(b["chance"]))
	_check(ok, "강화 옵션 %d단계 표: 옵션별 가중치 확률 합 100%% · 성공 한 번당 = 단계 확률 × 비율" % bands.size())
	var ENH: Array = c.D["ENHANCE_OPT"]
	var w3 := 0.0
	for k: String in ENH[2]["pool"].keys():
		var rg: Array = ENH[2]["pool"][k]
		w3 += float(rg[2]) if rg.size() > 2 else 1.0
	var mv_row: Array = []
	for r: Array in _sec(secs, "enh_opt_3")["rows"]:
		if str(r[0]).contains(str(i18n.call("t", "gear.fx.move", {"v": "1"}))):
			mv_row = r
	_check(mv_row.size() == 3 and mv_row[1] == OddsRules.pct(0.3 / w3), "+7~9 단계 이동은 가중치 0.3 → %s (표 %s)" % [OddsRules.pct(0.3 / w3), str(mv_row)])
	var uq := _sec(secs, "enh_opt_4")
	var un := (c.D["UNIQUE_POOL"] as Array).size()
	_check((uq["rows"] as Array).size() == un + 1 and uq["rows"][0][1] == OddsRules.pct(1.0 / float(un)) and uq["rows"][0][2] == OddsRules.pct(1.0 / float(un)), "+10 고유 효과 풀: %d가지 각 %s (성공 시 100%%)" % [un, OddsRules.pct(1.0 / float(un))])
	# 능력치 범위
	var sb := _sec(secs, "stat_base")
	_check((sb["rows"] as Array).size() == n and (sb["head"] as Array).size() == rar.size() + 1, "기본 능력치 범위 표: %d종 × 등급 %d" % [n, rar.size()])
	var tpl: Dictionary = c.D["EQUIP_DB"][0]
	var r0 := OddsRules.base_stat_range(c, tpl, "rare", false)
	var mult := float(c.D["RARITY_MULT"]["rare"])
	var rg0: Array = tpl["stats"][r0[0]["stat"]]
	_check(r0[0]["lo"] == maxf(1.0, Js.round_js(float(rg0[0]) * mult)) and r0[0]["hi"] == maxf(1.0, Js.round_js(float(rg0[1]) * mult)), "기본 능력치 범위 = round(범위 × 등급 배율) (%s %s~%s)" % [tpl["baseId"], str(r0[0]["lo"]), str(r0[0]["hi"])])
	var ssub := _sec(secs, "stat_sub")
	_check((ssub["rows"] as Array).size() == (c.D["SUB_RANGE"] as Dictionary).size() and (ssub["head"] as Array).size() == 1 + (c.D["SUB_COUNT"] as Dictionary).values().filter(func(v: Variant) -> bool: return float(v) > 0.0).size(), "부가 옵션 범위 표: 옵션 %d종 × 부가 옵션이 있는 등급" % (c.D["SUB_RANGE"] as Dictionary).size())
	# 직업 옵션 표
	var CO: Dictionary = c.D["CLASS_OPTS"]
	var cs := _sec(secs, "class_opt")
	var want_rows := 0
	for k0: String in CO.keys():
		want_rows += (CO[k0] as Array).size()
	var crows: Array = cs["rows"]
	ok = crows.size() == want_rows
	var ri := 0
	for k1: String in CO.keys():
		var wt := 0.0
		for o: Dictionary in CO[k1]:
			wt += float(o["w"]) if o.has("w") else 1.0
		var ssum := 0.0
		for o2: Dictionary in CO[k1]:
			var sh_ := (float(o2["w"]) if o2.has("w") else 1.0) / wt
			ssum += sh_
			ok = ok and crows[ri][0] == str(i18n.call("t", "classes." + k1, {})) and crows[ri][2] == OddsRules.pct(sh_)
			ri += 1
		ok = ok and absf(ssum - 1.0) < 1e-9
	_check(ok and (cs["head"] as Array).size() == 5, "직업 옵션 표: %d줄 · 직업마다 옵션 가중치 확률 합 100%% (궁수 사거리 가중치 0.25 반영)" % want_rows)
	var ar_row: Array = []
	for r13: Array in crows:
		if str(r13[1]).contains(str(i18n.call("t", "gear.fx.range", {"v": "1"}))):
			ar_row = r13
	_check(ar_row.size() == 5 and ar_row[2] == OddsRules.pct(0.25 / 2.25), "궁수 사거리 +1 = 0.25 / 2.25 = %s" % OddsRules.pct(0.25 / 2.25))
	# 도감 등급표 '뽑기' 열 · 강화 성공률 = 확률 창과 같은 pct()
	var blobc := JSON.stringify(R2_comp(c, tfn))
	ok = true
	for r14: Dictionary in OddsRules.rarity_rates(c):
		ok = ok and blobc.contains("\"" + OddsRules.pct(float(r14["rate"])) + "\"")
	for lv14 in (c.D["ENHANCE_RATES"] as Array).size():
		ok = ok and blobc.contains("\"" + OddsRules.pct(minf(1.0, float(c.D["ENHANCE_RATES"][lv14]))) + "\"")
	_check(ok and not blobc.contains("\"5\"%"), "도감 등급표 '뽑기' 열 · 강화 성공률이 확률 창과 같은 값 (4.5%% · 0.45%% · 0.05%%)")
	# 문구용 숫자 (강화 옵션 단계 · 파손)
	var eb := OddsRules.enhance_opt_bands(c)
	_check(eb.size() == 4 and eb[0]["p"] == "25%" and eb[1]["p"] == "40%" and eb[2]["p"] == "60%" and eb[3]["p"] == "100%" and eb[0]["range"] == "+1~3" and eb[3]["range"] == "+10", "도감 문구용 강화 옵션 단계: +1~3 25 · +4~6 40 · +7~9 60 · +10 100")
	# 도감·가이드·강화 창 문구가 데이터 숫자를 씀
	var R := CodexRules.new(c, tfn, func(k: String) -> bool: return bool(i18n.call("has_key", k)))
	var blob := JSON.stringify(R.comp_panel("gear")) + JSON.stringify(R.guide_panel("gear"))
	var brk := OddsRules.pct(float(c.D["ENHANCE_BREAK_CHANCE"]))
	_check(blob.contains("<b>" + brk + "</b>") and blob.contains("+4~6 40%") and blob.contains("+7~9 60%") and blob.contains("+10 100%") and not blob.contains("{p") and not blob.contains("{r"), "도감·가이드 문구: 파손 %s · 강화 옵션 단계 확률이 데이터에서 채워짐" % brk)


func R2_comp(c: Object, tfn: Callable) -> Array:
	var R := CodexRules.new(c, tfn, func(k: String) -> bool: return bool(i18n.call("has_key", k)))
	var out: Array = []
	for t: String in CodexRules.COMP_TABS:
		out.append(R.comp_panel(t))
	for t2: String in CodexRules.GUIDE_TABS:
		out.append(R.guide_panel(t2))
	return out


## 양 끝 값은 다른 값의 절반 확률 (연속 균등 뽑기 → 반올림) — counts: {값: 횟수}
func _ends_half_ok(counts: Dictionary, lo: int, hi: int) -> bool:
	var tot := 0.0
	for v: Variant in counts.values():
		tot += float(v)
	if tot < 500.0 or hi <= lo:
		return false
	for x in range(lo, hi + 1):
		var p := (0.5 if x == lo or x == hi else 1.0) / float(hi - lo)
		var f := float(counts.get(x, 0)) / tot
		if absf(f - p) > 5.5 * sqrt(p * (1.0 - p) / tot):
			print("    끝값 비율 %d: %.4f vs %.4f" % [x, f, p])
			return false
	return true


# ═══════════ 7) 규칙 코드로 뽑은 빈도 ═══════════

func _t_mc() -> void:
	var c := _mem_ctx(20261023)
	var GR: Dictionary = c.D["GACHA_RATE"]
	var raw := 0.0
	for v: Variant in GR.values():
		raw += float(v)
	var n := (c.D["EQUIP_DB"] as Array).size()
	var N := 60000
	var cnt: Dictionary = {}
	var leg := 0
	for i in N:
		var it := Gear.gacha_pull(c, null, true)
		if Js.truthy(it.get("legend")):
			leg += 1
			continue
		var k := "%s|%s" % [it["templateId"], it["rarity"]]
		cnt[k] = int(cnt.get(k, 0)) + 1
	var bad: Array = []
	var worst := 0.0
	for d: Dictionary in c.D["EQUIP_DB"]:
		for r: String in GR.keys():
			if r == "legendary":
				continue
			var p := float(GR[r]) / raw / float(n)
			var f := float(cnt.get("%s|%s" % [d["baseId"], r], 0)) / float(N)
			var sd := sqrt(p * (1.0 - p) / float(N))
			worst = maxf(worst, absf(f - p) / sd)
			if absf(f - p) > 5.5 * sd:
				bad.append("%s %s %.4f%% vs %.4f%%" % [d["baseId"], r, f * 100.0, p * 100.0])
	_check(bad.is_empty(), "gacha_pull %d번: 종류 %d × 등급 4 = %d칸 모두 표의 확률 ±5.5σ (최대 %.2fσ) %s" % [N, n, n * 4, worst, str(bad.slice(0, 3))])
	_stats["mc.kinds_worst_sigma"] = snappedf(worst, 0.01)
	_check(absf(float(leg) / float(N) - float(GR["legendary"]) / raw) < 5.5 * sqrt(0.0005 / float(N)), "전설 등급 빈도 %d/%d ≈ 0.05%%" % [leg, N])
	# 전설 종류 (가진 것이 없을 때 균등)
	var L := (c.D["LEGENDS"] as Dictionary).size()
	var lc: Dictionary = {}
	var NL := 38000
	for i in NL:
		var it2 := Gear.make_legend(c)
		lc[it2["legend"]] = int(lc.get(it2["legend"], 0)) + 1
	var lbad := lc.size() != L
	for k2: String in lc.keys():
		var p2 := 1.0 / float(L)
		lbad = lbad or absf(float(lc[k2]) / float(NL) - p2) > 5.5 * sqrt(p2 * (1.0 - p2) / float(NL))
	_check(not lbad, "make_legend %d번: 전설 %d종 균등 (표 %s)" % [NL, L, OddsRules.pct(1.0 / float(L))])
	# 강화 옵션 (단계별)
	var bands := OddsRules.enhance_opts(c)
	var NE := 60000
	var ebad: Array = []
	for bi in bands.size():
		var b: Dictionary = bands[bi]
		var lv := int(b["hi"])
		var ec: Dictionary = {}
		var none := 0
		for i in NE:
			var item := {"eOpts": {}, "fx": null, "legend": null}
			var o: Variant = Gear.roll_enhance_opt(c, item, lv)
			if o == null:
				none += 1
			else:
				ec[o["id"]] = int(ec.get(o["id"], 0)) + 1
		var pn := 1.0 - float(b["chance"])
		if float(b["chance"]) < 1.0 and absf(float(none) / float(NE) - pn) > 5.5 * sqrt(pn * (1.0 - pn) / float(NE)):
			ebad.append("%d단계 없음 %.4f vs %.4f" % [bi + 1, float(none) / float(NE), pn])
		if float(b["chance"]) >= 1.0 and none != 0:
			ebad.append("%d단계 없음 %d" % [bi + 1, none])
		for rw: Dictionary in b["rows"]:
			var p3 := float(b["chance"]) * float(rw["share"])
			var f3 := float(ec.get(rw["id"], 0)) / float(NE)
			if absf(f3 - p3) > 5.5 * sqrt(p3 * (1.0 - p3) / float(NE)):
				ebad.append("%d단계 %s %.4f%% vs %.4f%%" % [bi + 1, rw["id"], f3 * 100.0, p3 * 100.0])
	_check(ebad.is_empty(), "roll_enhance_opt %d번 × %d단계: 옵션별 빈도 = 단계 확률 × 비율 %s" % [NE, bands.size(), str(ebad.slice(0, 3))])
	# 강화 옵션·고유 효과 수치: 양 끝 값은 절반 확률 (hp_pct +2~4 → 1/4 · 1/2 · 1/4, kill_heal 8~12)
	var hp_vals: Dictionary = {}
	var kh_vals: Dictionary = {}
	for i in 90000:
		var o1: Variant = Gear.roll_enhance_opt(c, {"eOpts": {}, "fx": null, "legend": null}, 3)
		if o1 != null and o1["id"] == "hp_pct":
			hp_vals[int(o1["v"])] = int(hp_vals.get(int(o1["v"]), 0)) + 1
		var o2: Variant = Gear.roll_enhance_opt(c, {"eOpts": {}, "fx": null, "legend": null}, 10)
		if o2 != null and o2["id"] == "kill_heal":
			kh_vals[int(o2["v"])] = int(kh_vals.get(int(o2["v"]), 0)) + 1
	_check(_ends_half_ok(hp_vals, 2, 4), "강화 옵션 체력 +2~4%%: 값별 빈도 %s = 1/4 · 1/2 · 1/4 (양 끝은 절반)" % str(hp_vals))
	_check(_ends_half_ok(kh_vals, 8, 12), "+10 고유 효과 처치 회복 8~12: 값별 빈도 %s = 1/8 · 1/4 · 1/4 · 1/4 · 1/8" % str(kh_vals))
	# 직업 옵션: 직업(장비가 쓸 수 있는 직업 균등) · 옵션(가중치) · 수치 범위(등급 배율)
	var co := OddsRules.class_opts(c)
	var cbad: Array = []
	var DB: Array = c.D["EQUIP_DB"]
	var tpl_w: Dictionary = DB[4]            # 장궁: 전용 직업 궁수 1개 (사거리 가중치 0.25)
	var tpl_ring: Dictionary = {}
	var tpl_plate: Dictionary = {}
	for d: Dictionary in DB:
		if d["baseId"] == "ring_power":
			tpl_ring = d
		if d["baseId"] == "plate_armor":
			tpl_plate = d
	for ti in (co["tiers"] as Array).size():
		var rar3: String = co["tiers"][ti]
		var oc: Dictionary = {}
		var mn: Dictionary = {}
		var mx: Dictionary = {}
		var NC := 24000
		for i in NC:
			var itw := Gear.generate_equip(c, tpl_w, rar3)
			var co1: Dictionary = itw["cOpt"]
			if co1["cls"] != "archer":
				cbad.append("장궁 직업 %s" % co1["cls"])
			oc[co1["id"]] = int(oc.get(co1["id"], 0)) + 1
			mn[co1["id"]] = minf(float(mn.get(co1["id"], 1e9)), float(co1["v"]))
			mx[co1["id"]] = maxf(float(mx.get(co1["id"], -1e9)), float(co1["v"]))
		for rw: Dictionary in co["rows"]:
			if rw["cls"] != "archer":
				continue
			var pe := float(rw["share"])
			var fe := float(oc.get(rw["id"], 0)) / float(NC)
			if absf(fe - pe) > 5.5 * sqrt(pe * (1.0 - pe) / float(NC)):
				cbad.append("%s %s 옵션 %.4f vs %.4f" % [rar3, rw["id"], fe, pe])
			if absf(float(mn.get(rw["id"], 0)) - float(rw["per"][ti][0])) > 1e-9 or absf(float(mx.get(rw["id"], 0)) - float(rw["per"][ti][1])) > 1e-9:
				cbad.append("%s %s 수치 %s~%s ≠ 표 %s~%s" % [rar3, rw["id"], str(mn.get(rw["id"])), str(mx.get(rw["id"])), str(rw["per"][ti][0]), str(rw["per"][ti][1])])
	_check(cbad.is_empty(), "직업 옵션(장궁 · 희귀/영웅/전설 × 24000번): 옵션별 빈도 · 수치 최소·최대 = 표 %s" % str(cbad.slice(0, 3)))
	var cls_ring: Dictionary = {}
	var cls_plate: Dictionary = {}
	var NR := 36000
	for i in NR:
		var ir := Gear.generate_equip(c, tpl_ring, "rare")
		cls_ring[ir["cOpt"]["cls"]] = int(cls_ring.get(ir["cOpt"]["cls"], 0)) + 1
		var ip := Gear.generate_equip(c, tpl_plate, "rare")
		cls_plate[ip["cOpt"]["cls"]] = int(cls_plate.get(ip["cOpt"]["cls"], 0)) + 1
	var okc := cls_ring.size() == (c.D["ALL_CLASSES"] as Array).size() and cls_plate.size() == (c.D["ARMOR_TYPE"]["plate"] as Array).size()
	for k: String in cls_ring.keys():
		var p1 := 1.0 / float(cls_ring.size())
		okc = okc and absf(float(cls_ring[k]) / float(NR) - p1) < 5.5 * sqrt(p1 * (1.0 - p1) / float(NR))
	for k2: String in cls_plate.keys():
		var p2 := 1.0 / float(cls_plate.size())
		okc = okc and absf(float(cls_plate[k2]) / float(NR) - p2) < 5.5 * sqrt(p2 * (1.0 - p2) / float(NR))
	_check(okc, "직업 옵션의 직업: 장신구 %d개 직업 균등 · 판금 갑옷 %d개 직업 균등 (%d번)" % [cls_ring.size(), cls_plate.size(), NR])
	var none_ok := true
	for rar4: String in ["common", "uncommon"]:
		for i in 300:
			none_ok = none_ok and Gear.generate_equip(c, tpl_w, rar4)["cOpt"] == null
	_check(none_ok, "일반·고급 장비에는 직업 옵션이 없음 (희귀 이상만 항상 1개)")
	# 기본 능력치 끝값은 가운데보다 낮은 확률 (연속 균등 → 반올림)
	var bs: Dictionary = {}
	for i in 60000:
		var ib := Gear.generate_equip(c, DB[0], "common", {"bare": true})   # 대검 공격 6~10 (×1)
		var a := int(ib["stats"]["atk"])
		bs[a] = int(bs.get(a, 0)) + 1
	_check(_ends_half_ok(bs, 6, 10), "기본 능력치 대검 공격 6~10: 값별 빈도 %s (양 끝은 절반)" % str(bs))
	# 수치 범위 끝값: 기본 능력치 · 부가 옵션
	var rbad: Array = []
	for rar: String in ["common", "uncommon", "rare", "epic"]:
		var tpl: Dictionary = c.D["EQUIP_DB"][1]   # 기사검: 공격 + 체력
		var rg := OddsRules.base_stat_range(c, tpl, rar, false)
		var seen: Dictionary = {}
		for i in 4000:
			var it3 := Gear.generate_equip(c, tpl, rar, {"bare": true})
			for q in rg.size():
				var v3: float = it3["stats"][rg[q]["stat"]]
				var key := str(rg[q]["stat"])
				var cur: Array = seen.get(key, [1e9, -1e9])
				seen[key] = [minf(cur[0], v3), maxf(cur[1], v3)]
		for q2 in rg.size():
			var sn: Array = seen[rg[q2]["stat"]]
			if sn[0] != rg[q2]["lo"] or sn[1] != rg[q2]["hi"]:
				rbad.append("%s %s 뽑힘 %s~%s ≠ 표 %s~%s" % [rar, rg[q2]["stat"], str(sn[0]), str(sn[1]), str(rg[q2]["lo"]), str(rg[q2]["hi"])])
	_check(rbad.is_empty(), "기본 능력치: generate_equip 4000번의 최소·최대 = 표의 범위 (기사검 4등급) %s" % str(rbad.slice(0, 3)))
	var sbad: Array = []
	for rar2: String in ["uncommon", "rare", "epic", "legendary"]:
		var seen2: Dictionary = {}
		for i in 6000:
			var it4 := Gear.generate_equip(c, c.D["EQUIP_DB"][27], rar2)   # 목걸이 (장신구 풀 8종)
			for sb: Dictionary in it4["subs"]:
				var cur2: Array = seen2.get(sb["id"], [1e9, -1e9])
				seen2[sb["id"]] = [minf(cur2[0], float(sb["v"])), maxf(cur2[1], float(sb["v"]))]
		for id: String in seen2.keys():
			var sr := OddsRules.sub_range(c, id, rar2)
			var sn2: Array = seen2[id]
			if absf(sn2[0] - float(sr[0])) > 1e-9 or absf(sn2[1] - float(sr[1])) > 1e-9:
				sbad.append("%s %s 뽑힘 %s~%s ≠ 표 %s~%s" % [rar2, id, str(sn2[0]), str(sn2[1]), str(sr[0]), str(sr[1])])
	_check(sbad.is_empty(), "부가 옵션: generate_equip 6000번의 최소·최대 = 표의 범위 (장신구 4등급 × 옵션 8종) %s" % str(sbad.slice(0, 3)))


# ═══════════ 8) 6개 언어 문구 ═══════════

func _flat(d: Variant, prefix: String, out: Dictionary) -> void:
	if d is Dictionary:
		for k: String in (d as Dictionary).keys():
			_flat(d[k], prefix + "." + k if prefix != "" else k, out)
	else:
		out[prefix] = d


func _holders(s: String) -> Array:
	var re := RegEx.new()
	re.compile("\\{(\\w+)\\}")
	var out: Array = []
	for m in re.search_all(s):
		if not out.has(m.get_string(1)):
			out.append(m.get_string(1))
	out.sort()
	return out


func _t_lang() -> void:
	var packs: Dictionary = {}
	for lang: String in LANGS:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/lang/%s.json" % lang))
		var flat: Dictionary = {}
		_flat(d, "", flat)
		packs[lang] = flat
	var keys: Array = KEYS_SINGLE.duplicate()
	for k: String in (packs["ko"] as Dictionary).keys():
		if k.begins_with("gd.odds."):
			keys.append(k)
	var missing: Array = []
	var mismatch: Array = []
	for k2: String in keys:
		var base: Array = _holders(str(packs["ko"].get(k2, "")))
		for lang2: String in LANGS:
			if not (packs[lang2] as Dictionary).has(k2) or str(packs[lang2][k2]) == "":
				missing.append(lang2 + ":" + k2)
				continue
			if _holders(str(packs[lang2][k2])) != base:
				mismatch.append("%s:%s %s≠%s" % [lang2, k2, str(_holders(str(packs[lang2][k2]))), str(base)])
	_check(missing.is_empty(), "새·바뀐 문구 키 %d개가 6개 언어에 모두 있음 %s" % [keys.size(), str(missing.slice(0, 4))])
	_check(mismatch.is_empty(), "6개 언어의 {자리표시자}가 ko 와 같음 %s" % str(mismatch.slice(0, 4)))
	# 하드코딩된 확률 숫자 없음
	var re_num := RegEx.new()
	re_num.compile("\\d+([.,]\\d+)?\\s*%")
	var hard: Array = []
	for lang3: String in LANGS:
		for k3: String in ["gear.enh_break", "codex.g.break_p", "codex.c.eopt_note"]:
			var s := str(packs[lang3][k3])
			var stripped := s.replace("×1.25", "").replace("×1,25", "").replace("×1.5", "").replace("×1,5", "")
			if re_num.search(stripped) != null:
				hard.append(lang3 + ":" + k3)
	_check(hard.is_empty(), "파손·강화 옵션 문구에 확률 숫자(0.5%% · 25%% …)가 하드코딩되어 있지 않음 %s" % str(hard))
	var re_dc := RegEx.new()
	re_dc.compile("\\d,\\d")
	var comma: Array = []
	for k5: String in (packs["es"] as Dictionary).keys():
		var v5 := str(packs["es"][k5])
		if re_dc.search(v5) != null and not k5.begins_with("shop.gold_iap_"):
			comma.append(k5)
	_check(comma.is_empty(), "스페인어 소수점은 점으로 통일 (문장 속 쉼표 소수 없음; 천 단위 구분 '1,200 Oro' 만 예외) %s" % str(comma))
	# 천장 번역
	var pity_keys := ["shop.gacha_pity", "gd.odds.gacha_pity", "gd.odds.pity_title", "gd.odds.pity_note", "gd.odds.col_at_pity"]
	var es_bad: Array = []
	for k4: String in pity_keys:
		var s2 := str(packs["es"][k4])
		if s2.to_lower().contains("piedad"):
			es_bad.append(k4)
	var es_ok := str(packs["es"]["shop.gacha_pity"]).begins_with("Garantía") and str(packs["es"]["gd.odds.gacha_pity"]).begins_with("Garantía")
	var re_pi := RegEx.new()
	re_pi.compile("(?i)\\bpiedad\\b")   # 'propiedad'(Google 문구)는 해당 없음
	var all_es := JSON.stringify(packs["es"])
	_check(es_bad.is_empty() and es_ok and re_pi.search(all_es) == null, "스페인어 천장 = 'Garantía' (Piedad 는 es.json 어디에도 없음)")
	var zh_ok := not str(packs["zh-CN"]["shop.gacha_pity"]).contains("距") and not str(packs["zh-TW"]["shop.gacha_pity"]).contains("距")
	_check(zh_ok and str(packs["en"]["shop.gacha_pity"]).begins_with("Pity") and str(packs["ja"]["shop.gacha_pity"]).contains("天井") and str(packs["ko"]["shop.gacha_pity"]).contains("천장"), "천장 용어: ko 천장 · en Pity · ja 天井 · zh 保底(진행 표시) · es Garantía")
	# 그려 낸 표·카드 글에 번역 빠짐({} · 키 글자)이 없음 + 길이 통계
	var c := _mem_ctx()
	var rep: Array = []
	var maxlen: Dictionary = {}
	for lang4: String in LANGS:
		i18n.call("_apply", lang4)
		var secs := OddsRules.sections(c, _tfn())
		var texts: Array = []
		for sec: Dictionary in secs:
			texts.append(sec["title"])
			texts.append_array(sec["head"])
			for row: Array in sec["rows"]:
				texts.append_array(row)
			texts.append_array(sec["notes"])
		var tfn := _tfn()
		texts.append(OddsRules.rate_line(c, tfn))
		texts.append(str(i18n.call("t", "gd.odds.card_single", {"rates": OddsRules.rate_line(c, tfn), "n": 100})))
		texts.append(str(i18n.call("t", "gd.odds.card_multi", {"j": 10, "k": 11, "rates": OddsRules.rate_line(c, tfn, "rare"), "n": 100})))
		texts.append(str(i18n.call("t", "gd.odds.card_rune", {"n": 12, "p": "8.333%"})))
		texts.append(str(i18n.call("t", "gd.iap.gold_use", {})))
		for tx in texts:
			var s3 := str(tx)
			if s3.contains("{") or s3.contains("}") or s3.begins_with("gd.") or s3.begins_with("gear.") or s3.begins_with("equip.") or s3.begins_with("common.") or s3.begins_with("enchant."):
				rep.append("%s: %s" % [lang4, s3.left(50)])
		maxlen[lang4] = [str(i18n.call("t", "gd.odds.card_single", {"rates": OddsRules.rate_line(c, tfn), "n": 100})).length(),
			str(i18n.call("t", "gd.odds.card_multi", {"j": 10, "k": 11, "rates": OddsRules.rate_line(c, tfn, "rare"), "n": 100})).length(),
			str(i18n.call("t", "gd.iap.gold_use", {})).length()]
	i18n.call("_apply", "ko")
	var hdr_bad: Array = []
	for lang6: String in LANGS:
		i18n.call("_apply", lang6)
		var tf6 := _tfn()
		var rare_nm := str(i18n.call("t", "equip.rarity.rare", {}))
		var kh := str(tf6.call("gd.odds.col_last_r", {"n": 11, "r": "RRR", "m": rare_nm}))
		var lh := str(tf6.call("gd.odds.col_last_leg", {"n": 11, "m": rare_nm}))
		if not (kh.contains(rare_nm) and kh.contains("RRR") and lh.contains(rare_nm) and lh.contains("11") and not kh.contains("{") and not lh.contains("{")):
			hdr_bad.append(lang6)
	i18n.call("_apply", "ko")
	_check(hdr_bad.is_empty(), "'10+1회 N번째' 열 머리글이 '희귀 이상 풀 중'(풀 이름 + 번호)을 6개 언어로 밝힘 %s" % str(hdr_bad))
	_check(rep.is_empty(), "6개 언어로 그린 확률 창·카드 글에 빠진 번역({} · 키 글자)이 없음 %s" % str(rep.slice(0, 3)))
	var long_ok := true
	for lang5: String in LANGS:
		var m: Array = maxlen[lang5]
		long_ok = long_ok and int(m[0]) <= 260 and int(m[1]) <= 330 and int(m[2]) <= 260
		_stats["len.%s" % lang5] = "single/multi/gold_use = %s" % str(m)
	_check(long_ok, "카드 요약·골드 안내 길이 상한 (단일 ≤260 · 10+1 ≤330 · 골드 안내 ≤260자) — 넘침은 mobile6a·qa6a 가 화면에서 확인")


# ═══════════ 도우미 ═══════════

func _reset_save(gold: float) -> void:
	Files.reset()
	store.call("clear")
	store.call("set_json", "game_save", {"gold": gold, "cleared": [1, 2, 3]})
	store.call("flush")


func _open_shop(tab: String) -> Node:
	router.call("go", "shop", {"tab": tab})
	await _until(func() -> bool: return _screen_is("ui/shop.gd"), 5.0)
	await _frames(4)
	return current_scene
