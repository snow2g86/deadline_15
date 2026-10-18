extends SceneTree
## 결제층 A 시험 — 게임 쪽 공통 결제·광고 층 (가짜 가게 · 가짜 서버로 끝까지)
##   Godot --headless --path godot --script res://tests/check_iap.gd   [-- --only data,rules,sanitize,flow,crash,battle,tap,ads,odds,lang]
##  1) data     : data/iap.json 상품 4개(id·골드·원화·Apple id) · 상점 꾸러미가 데이터에서 · 광고 100G/3회 · 서버 주소 dev/stage/prod · 기준 데이터 덮어 읽기
##  2) rules    : IapRules.grant(중복 {dup}) · revoke(0 바닥 · 두 번째 무시 · 모르는 주문은 뒤의 지급을 막음) · 설치 식별자
##  3) sanitize : 정상 세이브는 바이트 그대로 · 형이 틀린 주문만 뺌 · 깨진/사전 아닌 기록은 game_iap_bak 에 보관 (지우지 않음)
##  4) flow     : 가짜 시나리오 8개 (success·cancel·pending·fail·net_fail·crash 둘은 5)·refund) — 중복 지급 0, 재전달(dup), 네트워크 실패 재시도,
##                환불 회수(0 바닥), 서버 거절(invalid), 같은 프레임 buy 두 번
##  5) crash    : 다른 프로세스(tests/aux_iap_crash.gd)가 지급 직전·직후에 죽음 → 이 프로세스가 그 세이브를 다시 읽어 restore → 골드 한 번만
##  5b) durable : 저장 폴더 쓰기 금지 — flush 거짓 성공 없음 · 디스크에 기록이 없으면 consume·finish 안 함 → 풀리면 저장 뒤 마무리
##  6) battle   : 실제 전투 장면 — 전투 중 Store 에 직접 더한 골드가 전투 끝(_write_back)에 사라지는 위험 재현 → Billing 은 미뤘다가 전투 뒤 지급(골드 남음)
##  6b) sortie : 서버 응답 프레임에 출격(store_save 사본 직후) → 지급 미룸 · 환불 목록 응답 프레임에 출격 → 회수 미룸 (전투 결과를 덮어쓰지 않음)
##  6c) claim  : 재설치 재claim 24시간·1번·가게 소모 규칙 · 주인을 잃은 설치의 회수 · consumed 우선 · 공격자 iid + 피해자 account_id 거부 · env
##  6d) misc   : iid(Crypto) · 초기화 때 game_iap 보존 · 진행 중 창 탈출구 · restore 가 먼저 지급한 구매 = '지급 완료' · 카드 그림 · 해시 · 허용 목록
##  6e) errors : 서버 429 rate_limited(verify · consume) · 501 not_implemented(STOVE) → 지급 없이 다시 시도 (가짜 서버 force_429 · 로컬 Worker /v1/dev/force429)
##  7) tap      : 상점 화면 진짜 입력(push_input) 같은 프레임 두 번 — 확인 창 1개 · 주문 1개 · 결과 창 1개, 결제 카드 숨김/꺼짐(steam·stove)
##  8) ads      : 하루 3회(전체 합계) · 날짜 바뀜 · 시계 되돌림 · 가짜 광고 끝까지/중간 닫기 · PC(stove)는 광고 카드 없음 · google 은 꺼진 카드
##  9) odds     : 확률표 = 데이터에서 계산한 값 (등급 합 100%) · 규칙 함수로 뽑아 본 빈도와 맞음 · 창의 글 = 표 · docs/store 6개 파일이 최신
## 10) lang     : 6개 언어 × 1280×720 · 1024×576 — 결제 카드·확인 창·진행 창·결과 창 9가지·광고 카드·가짜 광고·확률 창(상점·강화 탭) 넘침 0 · 두부 0
##  -- --server http://127.0.0.1:8951 : 가짜 서버 대신 진짜 로컬 Worker (server/ 에서 `npm run dev`) 로 같은 시험을 모두 돌림 (결제층 B)
##  Godot 오류(Logger 로 셈) 0 이어야 통과. 저장은 user://test_iap_save.json, 가짜 가게·서버는 user://fake_iap/ (끝나면 지움)

const BaselineData := preload("res://tests/baseline_data.gd")
const JsonX := preload("res://scripts/core/json_exact.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")
const StoreCtx := preload("res://scripts/logic/store_ctx.gd")
const SaveStore := preload("res://scripts/logic/save_store.gd")
const IapRules := preload("res://scripts/logic/iap_rules.gd")
const AdRules := preload("res://scripts/logic/ad_rules.gd")
const OddsRules := preload("res://scripts/logic/odds_rules.gd")
const ShopRules := preload("res://scripts/logic/shop_rules.gd")
const SaveSanitize := preload("res://scripts/logic/save_sanitize.gd")
const Gear := preload("res://scripts/logic/gear.gd")
const Files := preload("res://scripts/core/billing/fake_files.gd")
const FontsT := preload("res://scripts/core/fonts.gd")
const OddsExport := preload("res://tools/odds_export.gd")
const ResumeRules := preload("res://scripts/logic/resume_rules.gd")
const DataDBT := preload("res://scripts/core/data_db.gd")

const SAVE := "user://test_iap_save.json"
const CRASH_SAVE := "user://test_iap_crash.json"
const BATTLE := "res://scenes/battle/battle.tscn"
const LANGS := ["ko", "en", "es", "ja", "zh-CN", "zh-TW"]

var _fails: Array = []
var _passes := 0
var _counter: ErrCounter
var store: Node
var i18n: Node
var router: Node
var platform: Node
var billing
var ads
var db: Node
var _only: Array = []
var _stats: Dictionary = {}
## -- --server <주소>: 진짜 로컬 Worker 로 (비어 있으면 가짜 서버)
var _server_url := ""
const Remote := preload("res://tests/iap_remote.gd")


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


func _stat(k: String, v: Variant) -> void:
	_stats[k] = v


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
	var si := args.find("--server")
	if si >= 0 and si + 1 < args.size():
		_server_url = args[si + 1]
	BaselineData.apply(self)   # 전투 시험(황금 기록 세이브)용 기준 데이터 — iap 모듈은 기준 뒤에 생겨 지금 데이터에서 덧붙음 (DataDB._overlay_new_modules)
	store = root.get_node("Store")
	i18n = root.get_node("I18n")
	router = root.get_node("Router")
	platform = root.get_node("Platform")
	billing = root.get_node("Billing")
	ads = root.get_node("Ads")
	db = root.get_node("DataDB")
	store.call("use_path", SAVE)
	store.call("clear")
	if _server_url != "":
		# 결제층 B: 가짜 서버(fake_server.gd) 대신 진짜 로컬 Worker (server/ 의 wrangler dev). 가짜 가게 장부는 /v1/dev/ledger 로 비춤
		billing.set("server_override", _server_url)
		billing.set("env", "local")
		billing.set("_store_name", "")
		var h := Remote.new(_server_url).handle("GET", "/v1/health", {}, {}, {})
		if int(h["status"]) != 200 or str(h["body"].get("env", "")) != "dev":
			print("RESULT: FAIL (로컬 서버 %s 가 답하지 않음 — server/ 에서 npm run dev)" % _server_url)
			quit(1)
			return
		print("── 서버: 진짜 로컬 Worker %s (env %s) ──" % [_server_url, str(h["body"]["env"])])
	platform.call("override_store", "dev")
	billing.call("_ensure_backend")
	Files.reset()
	i18n.call("_apply", "ko")
	root.size = Vector2i(1280, 720)
	billing.set_scenario("success")
	billing.backend.delay = 0.05
	ads.fake_secs = 0.15
	for sec: Array in [["data", "1) 데이터"], ["rules", "2) 지급·회수 규칙"], ["sanitize", "3) 세이브 다듬기"], ["flow", "4) 가짜 시나리오"],
			["crash", "5) 앱이 죽었을 때 복구 (다른 프로세스)"], ["durable", "5b) 저장 폴더 쓰기 금지 — 디스크에 남기 전에는 '끝'을 알리지 않음"],
			["battle", "6) 전투 중 미루기"], ["sortie", "6b) 출격 직전 같은 프레임 · 환불 경로"], ["claim", "6c) 재설치 재claim 24시간·1번·가게 소모 규칙 · 보안"], ["misc", "6d) 초기화 보존 · 탈출구 · 그 밖"], ["errors", "6e) 서버 429 · 501 → 지급 없이 다시 시도"], ["tap", "7) 상점 화면 · 같은 프레임 연타"],
			["ads", "8) 보상형 광고"], ["odds", "9) 확률표"], ["lang", "10) 6개 언어 넘침·두부"]]:
		if not _want(sec[0]):
			continue
		print("── %s ──" % sec[1])
		await call("_t_" + str(sec[0]))
	platform.call("override_store", "")
	ads.today_override = ""
	store.call("clear")
	store.call("flush")
	for p: String in [SAVE, CRASH_SAVE, CRASH_SAVE + ".2"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
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


func _ctx() -> Object:
	return Ctx.new(Ctx.globals_from_db(db), 7, StoreCtx.new(store))


func _mem_ctx(save: Dictionary) -> Object:
	var ss := SaveStore.new()
	ss.load_from(save)
	return Ctx.new(Ctx.globals_from_db(db), 7, ss)


func _gold() -> float:
	var d: Variant = store.call("get_json", "game_save")
	return float(d.get("gold", 0)) if d is Dictionary else 0.0


func _fresh(gold: float) -> void:
	Files.reset()
	store.call("clear")
	store.call("set_json", "game_save", {"gold": gold, "cleared": [1, 2, 3]})
	store.call("flush")
	billing.verifier.net_down = false
	billing.verifier.net_fail_left = 0
	billing.set("_last_refund_ms", -Billing_GAP())
	for k: String in billing.stats.keys():
		billing.stats[k] = 0


static func Billing_GAP() -> int:
	return 60000


func _ledger() -> Dictionary:
	return Files.read(Files.STORE_FILE, {"orders": {}})


func _server() -> Dictionary:
	return Files.read(Files.SERVER_FILE, {"orders": {}})


func _orders() -> Dictionary:
	return IapRules.load_iap(_ctx())["orders"]


func _buy_wait(id: String) -> Dictionary:
	var box := {"r": null}
	var cb := func(i: String, r: Dictionary) -> void:
		if i == id and box["r"] == null:
			box["r"] = r
	billing.purchase_finished.connect(cb)
	var ok: bool = billing.buy(id)
	if ok:
		await _until(func() -> bool: return box["r"] != null, 10.0)
	billing.purchase_finished.disconnect(cb)
	return box["r"] if box["r"] != null else {"refused": true}


func _restore() -> void:
	await _until(func() -> bool: return not bool(billing.get("_restoring")), 10.0)
	await billing.restore(true)
	await _until(func() -> bool: return not bool(billing.get("_restoring")), 10.0)
	await _frames(2)


# ═══════════ 1) 데이터 ═══════════

func _t_data() -> void:
	var c := _ctx()
	var P: Array = IapRules.products(c)
	var want := [["gold_500", 500.0, 1200.0], ["gold_1200", 1200.0, 2500.0], ["gold_3000", 3000.0, 6500.0], ["gold_6500", 6500.0, 12000.0]]
	var ok := P.size() == 4
	for i in mini(4, P.size()):
		var p: Dictionary = P[i]
		var gid := str(want[i][0])
		ok = ok and str(p["id"]) == gid and float(p["gold"]) == want[i][1] and float(p["krw"]) == want[i][2] \
			and str(p["google"]) == gid and str(p["stove_item"]) == gid and str(p["apple"]) == "xyz.show4you.deadline15." + gid \
			and str(p["label"]) == "shop.gold_iap_" + str(int(want[i][1])) and str(p["fallback_price"]).begins_with("₩")
	_check(ok, "상품 4개: id · 골드 · 원화 · Google = 게임 id · STOVE = 게임 id · Apple = xyz.show4you.deadline15.<id>")
	var pk := ShopRules.gold_packages(c)
	var ok2 := pk.size() == 4
	for i in mini(4, pk.size()):
		ok2 = ok2 and pk[i]["id"] == P[i]["id"] and float(pk[i]["gold"]) == float(P[i]["gold"]) and str(pk[i]["price"]) == str(P[i]["fallback_price"])
	_check(ok2 and not (ShopRules as GDScript).get_script_constant_map().has("GOLD_PACKAGES"), "상점 꾸러미(ShopRules.gold_packages) = data/iap.json (예전 상수 GOLD_PACKAGES 없음)")
	_check(AdRules.reward_gold(c) == 100.0 and AdRules.daily_max(c) == 3, "광고 보상 100G · 하루 3회 (AD_REWARD)")
	var S: Dictionary = c.D["IAP_SERVER"]
	_check(S.has("dev") and S.has("stage") and S.has("prod") and str(S["dev"]["url"]).begins_with("fake://"), "서버 주소 dev(fake://) · stage · prod 를 데이터로")
	_check(bool(db.get("is_baseline")) and db.call("has_global", "IAP_PRODUCTS") and db.call("has_global", "STAGES") and (db.get("errors") as PackedStringArray).is_empty(),
		"기준 데이터 시험에서도 iap 모듈은 지금 데이터에서 덧붙음 (DataDB 오류 0)")
	var Bp: Array = billing.products()
	_check(Bp.size() == 4 and str(Bp[0]["id"]) == "gold_500", "Billing.products() 4개 (data 순서)")
	await billing.refresh_products()
	Bp = billing.products()
	_check(str(Bp[1]["price"]) == "₩2,500" and str(Bp[3]["price"]) == "₩12,000", "가짜 가게 가격 글 ₩2,500 · ₩12,000 (%s)" % str(Bp.map(func(x: Dictionary) -> String: return str(x["price"]))))
	# 비밀 키 없음: 게임 쪽 코드·데이터에 서버 비밀이 없음 (가짜 가게 서명 글만 — 디버그 전용)
	var leak: Array = []
	for f: String in ["res://scripts/core/billing.gd", "res://scripts/core/billing/verifier.gd", "res://data/iap.json"]:
		var src := FileAccess.get_file_as_string(f).to_lower()
		for w: String in ["secret", "api_key", "private_key", "service_account", "bearer"]:
			if src.contains(w):
				leak.append("%s:%s" % [f, w])
	_check(leak.is_empty(), "결제 코드·데이터에 비밀 키 글 없음 %s" % str(leak))


# ═══════════ 2) 규칙 ═══════════

func _t_rules() -> void:
	var c := _mem_ctx({"game_save": {"gold": 1000.0, "cleared": [1]}})
	var g := IapRules.grant(c, "dev", "A1", "gold_500", 1.0)
	_check(g.get("ok", false) and float(g["gold"]) == 500.0 and IapRules.order(c, "dev", "A1")["st"] == "granted" and _mgold(c) == 1500.0, "grant: 골드 +500 과 기록(granted)을 함께")
	var g2 := IapRules.grant(c, "dev", "A1", "gold_500", 2.0)
	_check(g2.get("dup", false) and _mgold(c) == 1500.0, "같은 주문 다시 grant → {dup:true}, 골드 그대로")
	_check(IapRules.grant(c, "google", "A1", "gold_500", 3.0).get("ok", false) and _mgold(c) == 2000.0, "가게가 다르면 다른 주문 (google:A1)")
	_check(IapRules.grant(c, "dev", "A2", "nope", 1.0).get("err") == "product" and IapRules.grant(c, "dev", "", "gold_500", 1.0).get("err") == "order", "모르는 상품 · 빈 주문 번호는 지급 안 함")
	_check(IapRules.mark_done(c, "dev", "A1") and IapRules.order(c, "dev", "A1")["st"] == "done" and not IapRules.mark_done(c, "dev", "A1"), "mark_done: granted → done (한 번)")
	Profile_set_gold(c, 200.0)
	var rv := IapRules.revoke(c, "dev", "A1", 9.0)
	_check(rv.get("ok", false) and float(rv["taken"]) == 200.0 and _mgold(c) == 0.0 and IapRules.order(c, "dev", "A1")["st"] == "revoked", "환불 회수: 500G 주문인데 200G 남음 → 200 만 빼고 0 (0 밑으로 안 감)")
	_check(IapRules.revoke(c, "dev", "A1", 10.0).get("ignored") == "already" and _mgold(c) == 0.0, "이미 회수한 주문은 무시")
	_check(IapRules.grant(c, "dev", "A1", "gold_500", 11.0).get("dup", false) and _mgold(c) == 0.0, "회수한 주문이 다시 와도 지급 안 함")
	var rv2 := IapRules.revoke(c, "dev", "B9", 12.0, "gold_1200")
	_check(rv2.get("unknown", false) and IapRules.grant(c, "dev", "B9", "gold_1200", 13.0).get("dup", false) and _mgold(c) == 0.0, "모르는 주문의 환불이 먼저 오면 기록만 남겨 뒤의 지급을 막음")
	Profile_set_gold(c, 5000.0)
	var rv3 := IapRules.revoke(c, "google", "A1", 14.0)
	_check(float(rv3["taken"]) == 500.0 and _mgold(c) == 4500.0, "골드가 넉넉하면 주문 골드만큼 회수")
	var iid := IapRules.install_id(c, func() -> String: return "0123456789abcdef0123456789abcdef")
	_check(iid.length() == 32 and IapRules.install_id(c, func() -> String: return "ffffffffffffffffffffffffffffffff") == iid, "설치 식별자 32자 (한 번 만들면 그대로)")
	_check(IapRules.unfinished(c).size() == 0, "unfinished: granted 없음")
	IapRules.grant(c, "dev", "C1", "gold_3000", 15.0)
	_check(IapRules.unfinished(c) == [{"store": "dev", "oid": "C1", "pid": "gold_3000"}], "unfinished: 지급만 하고 '끝'을 못 알린 주문")
	_check(IapRules.store_product_id(IapRules.product(c, "gold_500"), "apple") == "xyz.show4you.deadline15.gold_500" and IapRules.pid_from_store(c, "apple", "xyz.show4you.deadline15.gold_6500") == "gold_6500",
		"가게 상품 id ↔ 게임 id")


func _mgold(c: Object) -> float:
	var d: Variant = c.store.get_json("game_save")
	return float(d.get("gold", 0)) if d is Dictionary else 0.0


func Profile_set_gold(c: Object, g: float) -> void:
	var d: Dictionary = c.store.get_json("game_save")
	d["gold"] = g
	c.store.set_json("game_save", d)


# ═══════════ 3) 세이브 다듬기 ═══════════

func _t_sanitize() -> void:
	store.call("clear")
	var good := {"v": 1, "iid": "0123456789abcdef0123456789abcdef", "rf": "3", "orders": {"dev:FAKE.1.1": {"pid": "gold_500", "gold": 500, "at": 1791936000000, "st": "done"},
		"google:GPA.1": {"pid": "gold_1200", "gold": 1200, "at": 1791936000001, "st": "granted"}, "dev:X": {"pid": "gold_500", "gold": 0, "at": 1, "st": "revoked", "taken": 0, "rv": 1}}}
	store.call("set_json", "game_save", {"gold": 10.0, "cleared": [1]})
	store.call("set_json", IapRules.KEY, good)
	store.call("set_json", AdRules.KEY, {"v": 1, "day": "2026-10-18", "n": 2})
	var raw0: String = store.call("get_str", IapRules.KEY)
	var raw_a: String = store.call("get_str", AdRules.KEY)
	var ch := SaveSanitize.sanitize(_ctx())
	_check(not ch.has(IapRules.KEY) and not ch.has(AdRules.KEY) and store.call("get_str", IapRules.KEY) == raw0 and store.call("get_str", AdRules.KEY) == raw_a,
		"정상 game_iap · game_ads 는 바이트 그대로 (바뀐 키 %s)" % str(ch))
	var bad := JsonX.parse(raw0) as Dictionary
	bad["orders"]["nocolon"] = {"pid": "gold_500", "gold": 500, "at": 1, "st": "done"}
	bad["orders"]["dev:BAD1"] = 7
	bad["orders"]["dev:BAD2"] = {"pid": 5, "gold": 500, "st": "done"}
	bad["orders"]["dev:BAD3"] = {"pid": "gold_500", "gold": "x", "st": "done"}
	bad["orders"]["dev:BAD4"] = {"pid": "gold_500", "gold": 500, "st": "weird"}
	bad["orders"]["dev:FIX"] = {"pid": "gold_500", "gold": 500, "at": "x", "st": "granted"}
	bad["iid"] = 5
	store.call("set_json", IapRules.KEY, bad)
	ch = SaveSanitize.sanitize(_ctx())
	var after: Dictionary = store.call("get_json", IapRules.KEY)
	var ks: Array = (after["orders"] as Dictionary).keys()
	ks.sort()
	_check(ch.has(IapRules.KEY) and ks == ["dev:FAKE.1.1", "dev:FIX", "dev:X", "google:GPA.1"] and float(after["orders"]["dev:FIX"]["at"]) == 0.0 and not after.has("iid") and str(after["rf"]) == "3",
		"형이 틀린 주문만 뺌 (좋은 주문 3개 + 고친 1개는 남음) %s" % str(ks))
	var bl: Array = IapRules.bak_list(_ctx())
	_check(bl.size() == 1 and str(bl[0]["why"]) == "bad_items" and str(bl[0]["raw"]).contains("BAD4") and str(bl[0]["raw"]).contains("\"iid\":5"), "뺀 주문·iid 원본은 game_iap_bak 에 남김")
	var broken := "{\"v\":1,\"iid\":\"0123456789abcdef0123456789abcdef\",\"rf\":\"7\",\"orders\":{\"dev:OK1\":{\"pid\":\"gold_500\",\"gold\":500,\"at\":1,\"st\":\"done\"},\"google:OK2\":{\"pid\":\"gold_1200\",\"gold\":1200,\"at\":2,\"st\":\"granted\"},\"dev:CUT\":{\"pid\":\"gold_"
	store.call("set_str", IapRules.KEY, broken)
	SaveSanitize.sanitize(_ctx())
	var sv: Dictionary = store.call("get_json", IapRules.KEY)
	var sk: Array = (sv["orders"] as Dictionary).keys()
	sk.sort()
	bl = IapRules.bak_list(_ctx())
	_check(str(sv.get("iid")) == "0123456789abcdef0123456789abcdef" and str(sv.get("rf")) == "7" and sk == ["dev:CUT", "dev:OK1", "google:OK2"] and bool(sv["orders"]["dev:CUT"].get("lost", false)) and str(sv["orders"]["dev:CUT"]["st"]) == "done" and bl.size() == 2 and str(bl[1]["raw"]) == broken,
		"깨진 game_iap → 원본은 bak 에 쌓고, 읽을 수 있는 iid · 환불 커서 · 주문 2개는 살리고, 내용이 잘린 주문(CUT)은 '끝남' 표시로 %s" % str(sk))
	store.call("set_json", IapRules.KEY, [1, 2])
	SaveSanitize.sanitize(_ctx())
	bl = IapRules.bak_list(_ctx())
	_check(bl.size() == 3 and str(bl[2]["why"]) == "not_object" and str(bl[2]["raw"]) == "[1,2]" and store.call("get_json", IapRules.KEY) is Dictionary, "사전이 아닌 game_iap 도 원본을 bak 에 쌓음 (덮어쓰지 않음 — 3개)")
	for i in 30:
		IapRules.bak_push(_ctx(), "t", str(i), float(i))
	bl = IapRules.bak_list(_ctx())
	_check(bl.size() == IapRules.BAK_MAX and str(bl.back()["raw"]) == "29", "bak 은 최근 %d개까지" % IapRules.BAK_MAX)
	store.call("set_json", AdRules.KEY, {"day": 5, "n": 1})
	SaveSanitize.sanitize(_ctx())
	_check(not store.call("has", AdRules.KEY), "이상한 game_ads → 지움 (오늘 0회부터)")
	store.call("set_json", AdRules.KEY, {"day": "2026-10-18", "n": "x"})
	SaveSanitize.sanitize(_ctx())
	_check(float((store.call("get_json", AdRules.KEY) as Dictionary)["n"]) == 0.0, "game_ads.n 이 숫자가 아니면 0")
	store.call("clear")


# ═══════════ 4) 가짜 시나리오 ═══════════

func _t_flow() -> void:
	# success
	_fresh(1000.0)
	billing.set_scenario("success")
	var r := await _buy_wait("gold_1200")
	var L := _ledger()
	var oid := str(r.get("order_id", ""))
	_check(r.get("status") == "granted" and _gold() == 2200.0 and _orders().size() == 1 and str(_orders()["dev:" + oid]["st"]) == "done"
		and bool(L["orders"][oid]["finished"]) and str(_server()["orders"]["dev:" + oid]["st"]) == "consumed", "success: +1200 · 기록 done · 가게 finish · 서버 consume")
	var disk := _disk(SAVE)
	_check(disk.has(IapRules.KEY) and float((JsonX.parse(str(disk["game_save"])) as Dictionary)["gold"]) == 2200.0, "지급은 디스크에 (Store.flush 뒤에만 finish)")
	await _restore()
	_check(_gold() == 2200.0 and int(billing.stats["grants"]) == 1, "다시 처리해도 그대로 (지급 1번)")
	# 가게가 같은 거래를 다시 알림 (finish 를 잃어버린 것처럼)
	L = _ledger()
	L["orders"][oid]["finished"] = false
	Files.write(Files.STORE_FILE, L)
	await _restore()
	_check(_gold() == 2200.0 and int(billing.stats["dups"]) >= 1 and bool(_ledger()["orders"][oid]["finished"]), "같은 주문 재전달 → dup (골드 그대로), 다시 finish")
	# 세이브를 잃고(기록 없음) 같은 주문이 다시 와도: 서버가 'consumed' → 지급 안 함
	var keep_iid: String = (store.call("get_json", IapRules.KEY) as Dictionary)["iid"]
	store.call("set_json", IapRules.KEY, {"v": 1, "iid": keep_iid, "orders": {}})
	L = _ledger()
	L["orders"][oid]["finished"] = false
	Files.write(Files.STORE_FILE, L)
	await _restore()
	_check(_gold() == 2200.0 and _orders().is_empty() and bool(_ledger()["orders"][oid]["finished"]), "기록을 잃어도 서버가 consumed → 다시 주지 않음")
	# 다른 설치가 같은 영수증 → 서버 거절 (order_claimed)
	store.call("set_json", IapRules.KEY, {"v": 1, "iid": "ffffffffffffffffffffffffffffffff", "orders": {}})
	L = _ledger()
	L["orders"][oid]["finished"] = false
	Files.write(Files.STORE_FILE, L)
	await _restore()
	_check(_gold() == 2200.0 and _orders().is_empty() and bool(_ledger()["orders"][oid]["finished"]), "다른 설치의 같은 영수증(이미 consumed) → consumed 가 먼저 (지급 안 함) — 24시간 안 claim 거절은 6c)")
	# cancel / fail
	_fresh(1000.0)
	billing.set_scenario("cancel")
	r = await _buy_wait("gold_500")
	_check(r.get("status") == "cancelled" and _gold() == 1000.0 and _orders().is_empty() and (_ledger()["orders"] as Dictionary).is_empty(), "cancel: 골드·기록·주문 없음")
	billing.set_scenario("fail")
	r = await _buy_wait("gold_500")
	_check(r.get("status") == "failed" and str(r.get("code")) == "store_error" and _gold() == 1000.0 and _orders().is_empty(), "fail: 실패 (store_error), 지급 없음")
	# pending
	_fresh(1000.0)
	billing.set_scenario("pending")
	r = await _buy_wait("gold_3000")
	_check(r.get("status") == "pending" and _gold() == 1000.0 and _orders().is_empty(), "pending: 대기 — 지급 없음")
	var gcount := [0]
	var gcb := func(_i: String, _g: float, _o: String) -> void: gcount[0] += 1
	billing.granted.connect(gcb)
	billing.set_scenario("success")
	await _restore()
	await _restore()
	billing.granted.disconnect(gcb)
	_check(_gold() == 4000.0 and gcount[0] == 1 and _orders().size() == 1, "pending → 승인 뒤 다시 처리에서 +3000 한 번 (granted 신호 %d번)" % gcount[0])
	# net_fail → 다시
	_fresh(1000.0)
	billing.set_scenario("net_fail")
	r = await _buy_wait("gold_500")
	var unfin := 0
	for o: Dictionary in _ledger()["orders"].values():
		if not bool(o["finished"]):
			unfin += 1
	_check(r.get("status") == "verify_failed" and str(r.get("code")) == "network" and _gold() == 1000.0 and _orders().is_empty() and unfin == 1, "net_fail: 서버 확인 실패 → 지급 안 함, 가게에 미처리로 남음")
	billing.verifier.net_down = true
	await _restore()
	_check(_gold() == 1000.0 and _orders().is_empty(), "네트워크가 계속 안 되면 계속 미처리 (지급 0)")
	billing.verifier.net_down = false
	await _restore()
	await _restore()
	_check(_gold() == 1500.0 and _orders().size() == 1 and int(billing.stats["grants"]) == 1, "네트워크가 돌아오면 다시 처리에서 +500 한 번")
	# 서버 consume 만 실패 → granted 로 남았다가 다음에 done
	_fresh(1000.0)
	billing.set_scenario("success")
	billing.verifier.net_fail_left = 0
	var calls_before := int(billing.verifier.calls.get("/v1/purchases/consume", 0))
	# verify 는 되고 consume 만 실패하도록: verify 다음 요청부터 네트워크를 끊음
	var cut := func(_i: String, _g: float, _o: String) -> void: billing.verifier.net_down = true
	billing.granted.connect(cut, CONNECT_ONE_SHOT)
	r = await _buy_wait("gold_500")
	var st1 := str(_orders().values()[0]["st"]) if _orders().size() == 1 else "?"
	billing.verifier.net_down = false
	await _restore()
	var st2 := str(_orders().values()[0]["st"]) if _orders().size() == 1 else "?"
	_check(r.get("status") == "granted" and st1 == "granted" and st2 == "done" and _gold() == 1500.0 and int(billing.verifier.calls.get("/v1/purchases/consume", 0)) > calls_before + 1,
		"서버 consume 실패 → 기록 granted 로 남음 → 다음 처리에서 consume 하고 done (골드 한 번)")
	# refund (시나리오) — 지급 뒤 가게가 환불 → 회수
	_fresh(1000.0)
	billing.set_scenario("refund")
	var rv := [0.0]
	var rcb := func(_i: String, taken: float, _o: String) -> void: rv[0] += taken
	billing.revoked.connect(rcb)
	r = await _buy_wait("gold_1200")
	await _until(func() -> bool: return rv[0] > 0.0, 5.0)
	billing.revoked.disconnect(rcb)
	_check(r.get("status") == "granted" and rv[0] == 1200.0 and _gold() == 1000.0 and str(_orders().values()[0]["st"]) == "revoked", "refund: 지급 뒤 환불 목록 → 1200 회수")
	# 환불: 이미 써서 골드가 모자라면 0 까지만
	_fresh(1000.0)
	billing.set_scenario("success")
	r = await _buy_wait("gold_6500")
	store.call("set_json", "game_save", {"gold": 300.0, "cleared": [1, 2, 3]})
	billing.backend.refund(str(r["order_id"]))
	await _restore()
	_check(_gold() == 0.0 and float(_orders().values()[0]["taken"]) == 300.0, "환불 회수 0 바닥: 6500 주문, 남은 골드 300 → 0 (회수 300)")
	await _restore()
	_check(_gold() == 0.0 and int(billing.stats["revokes"]) == 1 and IapRules.refund_cursor(_ctx()) == "1", "환불 목록 다시 받아도 두 번 회수하지 않음 (커서 %s)" % IapRules.refund_cursor(_ctx()))
	# 같은 프레임 buy 두 번
	_fresh(1000.0)
	var a: bool = billing.buy("gold_500")
	var b: bool = billing.buy("gold_500")
	_check(a and not b and billing.busy(), "같은 프레임 Billing.buy 두 번 → 두 번째는 거절 (진행 중)")
	await _until(func() -> bool: return not billing.busy(), 5.0)
	_check((_ledger()["orders"] as Dictionary).size() == 1 and _gold() == 1500.0, "주문 1개 · +500 한 번")
	# 결제를 쓸 수 없는 판
	platform.call("override_os", "Windows")
	for st: String in ["steam", "stove", "google", "apple"]:
		platform.call("override_store", st)
		_check(not billing.buy("gold_500") and billing.is_supported() == (st != "steam") and not billing.is_available(), "%s: buy 거절 · 결제 길 %s · 지금은 못 씀" % [st, "있음" if st != "steam" else "없음"])
	platform.call("override_os", "macOS")
	platform.call("override_store", "stove")
	_check(not billing.is_supported(), "STOVE 맥 판: 결제 길 없음 (SDK 는 Windows DLL)")
	platform.call("override_os", "")
	platform.call("override_store", "dev")
	billing.set_scenario("success")
	billing.backend.delay = 0.05
	_stat("flow.billing_stats", billing.stats.duplicate())


func _disk(path: String) -> Dictionary:
	var raw := FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))
	var d: Variant = JsonX.parse(raw) if raw != "" else null
	return d if d is Dictionary else {}


# ═══════════ 5) 앱이 죽었을 때 ═══════════

func _t_crash() -> void:
	for sc: String in ["crash_before_grant", "crash_after_grant"]:
		_fresh(1000.0)
		store.call("use_path", "user://test_iap_other.json")
		for p: String in [CRASH_SAVE]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		var out: Array = []
		var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/aux_iap_crash.gd", "--", "--iap", sc, "--save", CRASH_SAVE, "--gold", "1000"]
		if _server_url != "":
			args += ["--iap-env", "local", "--iap-server", _server_url]
		var code := OS.execute(OS.get_executable_path(), args, out, true)
		var txt := "\n".join(out)
		var alive := txt.contains("AUX_IAP: ALIVE")
		_stat("crash.%s.exit" % sc, code)
		var disk := _disk(CRASH_SAVE)
		var dg: float = float((JsonX.parse(str(disk.get("game_save", "{}"))) as Dictionary).get("gold", -1))
		var drec: Variant = JsonX.parse(str(disk.get(IapRules.KEY, "{}")))
		var nrec := (drec["orders"] as Dictionary).size() if drec is Dictionary and drec.get("orders") is Dictionary else 0
		var L := _ledger()
		var lo: Array = (L["orders"] as Dictionary).values()
		var lfin := lo.size() == 1 and bool(lo[0]["finished"])
		if sc == "crash_before_grant":
			_check(not alive and code != 0 and dg == 1000.0 and nrec == 0 and lo.size() == 1 and not lfin, "%s: 다른 프로세스가 지급 직전에 죽음 → 디스크 골드 1000 · 기록 0 · 가게 미처리 (종료 %d)" % [sc, code])
		else:
			_check(not alive and code != 0 and dg == 2200.0 and nrec == 1 and lo.size() == 1 and not lfin, "%s: 지급·저장 뒤 finish 전에 죽음 → 디스크 골드 2200 · 기록 1 · 가게 미처리 (종료 %d)" % [sc, code])
		# 다시 켬 (이 프로세스가 그 세이브를 처음부터 읽음)
		store.call("use_path", CRASH_SAVE)
		billing.set_scenario("success")
		await _restore()
		await _restore()
		var fin := bool((_ledger()["orders"] as Dictionary).values()[0]["finished"]) if (_ledger()["orders"] as Dictionary).size() == 1 else false
		var g2 := float((JsonX.parse(str(_disk(CRASH_SAVE).get("game_save", "{}"))) as Dictionary).get("gold", -1))
		_check(_gold() == 2200.0 and g2 == 2200.0 and _orders().size() == 1 and fin and str(_orders().values()[0]["st"]) == "done",
			"%s → 다시 켜서 restore: 골드 2200 (한 번만) · 기록 done · 가게 finish" % sc)
	store.call("use_path", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_iap_other.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CRASH_SAVE))


# ═══════════ 6) 전투 중 미루기 ═══════════

const BATTLE_GOLDEN := "balanced_s05"


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


func _start_battle() -> Node:
	var cfg := _store_battle_cfg(BATTLE_GOLDEN)
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	BS.set("pending", cfg)
	var bt: Node = (load(BATTLE) as PackedScene).instantiate()
	root.add_child(bt)
	current_scene = bt
	await _until(func() -> bool: return bt.is_awaiting(), 20.0)
	return bt


func _drive(scene: Node, cmd: Dictionary) -> bool:
	var op: String = cmd["op"]
	match op:
		"move", "shove":
			return scene.ui_action(op) and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"attack", "heal":
			return scene.ui_action("attack") and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"skill":
			if not (scene.ui_action("skill") and scene.ui_pick_skill(int(cmd["idx"]))):
				return false
			if scene.mode == "target":
				return scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
			return true
		"wait", "defend", "overwatch":
			return scene.ui_action(op) and scene.ui_pick_face(int(cmd["dx"]), int(cmd["dy"]))
		"undo":
			return scene.ui_action("undo")
		"potion":
			return scene.ui_action("item") and scene.ui_pick_item("potion", int(cmd["idx"])) and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"siege", "climb":
			return scene.ui_action("item") and scene.ui_pick_item("siege", int(cmd["idx"])) and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
	return false


## 황금 기록 명령으로 끝까지 (이김 → 보상 골드를 game_save 에 씀 → _write_back) → 끝난 뒤 골드
func _win_battle(bt: Node) -> float:
	var g: Dictionary = JsonX.parse(FileAccess.get_file_as_string("res://tests/golden/%s.json" % BATTLE_GOLDEN))
	var cmds: Array = []
	for e: Dictionary in g["events"]:
		if e["ev"] == "cmd":
			cmds.append(e)
	var ci := 0
	var frames := 0
	while frames < 60000 and not bt.is_over():
		await process_frame
		frames += 1
		if not bt.is_awaiting() or ci >= cmds.size():
			continue
		if not _drive(bt, cmds[ci]):
			break
		ci += 1
	_stat("battle.win_cmds", "%d/%d %s" % [ci, cmds.size(), str(bt.result.get("result", "?"))])
	await _frames(3)
	var gold := _gold()
	bt.queue_free()
	current_scene = null
	await _frames(3)
	return gold


func _t_battle() -> void:
	Files.reset()
	billing.set_scenario("success")
	# 기준: 결제 없이 이긴 판의 골드
	var bt0 := await _start_battle()
	var base0 := _gold()
	var base_end := await _win_battle(bt0)
	_check(base_end > base0, "기준 판: 황금 기록(%s)으로 이김 → 보상 골드 %s → %s" % [BATTLE_GOLDEN, base0, base_end])
	# (가) 위험 재현: 전투 중에 Store 에 바로 골드를 더하면 전투 끝(_write_back)에 사라짐
	var bt := await _start_battle()
	var in_b: bool = billing.in_battle()
	IapRules.grant(_ctx(), "dev", "RISK.1", "gold_1200", 1.0)
	var g_mid := _gold()
	var g_end := await _win_battle(bt)
	var rec: Variant = IapRules.order(_ctx(), "dev", "RISK.1")
	_stat("battle.risk", {"start": base0, "mid": g_mid, "end": g_end, "baseline_end": base_end})
	_check(in_b and g_mid == base0 + 1200.0 and g_end == base_end and rec != null,
		"위험 재현: 전투 중 바로 지급(%s)한 1200 이 전투 끝에 사라짐 (끝 %s = 결제 없는 판과 같음, 기록만 남음) — battle_scene._write_back 이 game_save 를 덮어씀" % [g_mid, g_end])
	# (나) Billing: 전투 중 구매 확인 → 미룸 → 전투 뒤 지급
	Files.reset()
	var bt2 := await _start_battle()
	var gs := _gold()
	var r := await _buy_wait("gold_1200")
	var unfin := 0
	for o: Dictionary in _ledger()["orders"].values():
		if not bool(o["finished"]):
			unfin += 1
	_check(r.get("status") == "deferred" and _gold() == gs and _orders().is_empty() and unfin == 1, "전투 중 구매 확인 → 미룸 (deferred) · 골드 그대로 · 가게 미처리로 남음")
	await _restore()
	_check(_orders().is_empty() and _gold() == gs, "전투 중 restore(앱 복귀 등)도 미룸")
	var ge := await _win_battle(bt2)
	await _until(func() -> bool: return _orders().size() == 1 and str(_orders().values()[0]["st"]) == "done", 5.0)
	_stat("battle.deferred", {"start": gs, "end_before_grant": ge, "after": _gold(), "baseline_end": base_end})
	_check(ge == base_end and _gold() == base_end + 1200.0 and _orders().size() == 1, "전투가 끝나고 장면이 사라지면 저절로 지급: 전투 결과 %s + 1200 = %s (골드 남음)" % [ge, _gold()])
	var disk := _disk(SAVE)
	_check(float((JsonX.parse(str(disk.get("game_save", "{}"))) as Dictionary).get("gold", -1)) == base_end + 1200.0, "디스크에도 전투 결과 + 1200")
	# 전투 중 환불도 미룸 (회수도 game_save 를 바꾸므로)
	var oid := str((_ledger()["orders"] as Dictionary).keys()[0])
	var keep_iap: Variant = store.call("get_json", IapRules.KEY)
	var bt3 := await _start_battle()
	store.call("set_json", IapRules.KEY, keep_iap)   # (전투 설정이 세이브를 기준 판으로 바꿨으므로 결제 기록을 되돌려 둠)
	billing.backend.refund(oid)
	var before_rv := _gold()
	var rv0 := int(billing.stats["revokes"])
	await _restore()
	_check(_gold() == before_rv and int(billing.stats["revokes"]) == rv0 and str(_orders()["dev:" + oid]["st"]) == "done", "전투 중에는 환불 회수도 미룸")
	var ge3 := await _win_battle(bt3)
	await _until(func() -> bool: return str(_orders()["dev:" + oid]["st"]) == "revoked", 5.0)
	_check(str(_orders()["dev:" + oid]["st"]) == "revoked" and _gold() == ge3 - 1200.0, "전투가 끝나면 환불 회수 (%s → %s)" % [ge3, _gold()])
	store.call("clear")


# ═══════════ 5b) 쓰기 금지 ═══════════

func _chmod(mode: String, dir: String) -> void:
	OS.execute("chmod", [mode, ProjectSettings.globalize_path(dir)])


func _disk_gold(path: String) -> float:
	var d := _disk(path)
	return float((JsonX.parse(str(d.get("game_save", "{}"))) as Dictionary).get("gold", -1))


func _t_durable() -> void:
	var dir := "user://iap_ro/"
	var path := dir + "save.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	store.call("use_path", path)
	_fresh(1000.0)
	billing.set_scenario("success")
	_chmod("555", dir)
	store.call("set_json", "probe", 1)
	var f1: bool = store.call("flush")
	var f2: bool = store.call("flush")
	_check(not f1 and not f2, "쓰기 금지: flush 실패가 다음 flush 에서 거짓 성공(true)으로 바뀌지 않음")
	var r := await _buy_wait("gold_1200")
	var oid := str((_ledger()["orders"] as Dictionary).keys()[0]) if (_ledger()["orders"] as Dictionary).size() == 1 else ""
	var srv := str(_server()["orders"].get("dev:" + oid, {}).get("st", ""))
	_check(r.get("status") == "save_failed" and _disk_gold(path) == 1000.0 and srv == "verified" and not bool(_ledger()["orders"][oid]["finished"]),
		"저장 실패 → save_failed · 디스크 골드 1000 · 서버 consume 안 함 · 가게 finish 안 함")
	await _restore()
	await _restore()
	srv = str(_server()["orders"]["dev:" + oid]["st"])
	_check(_disk_gold(path) == 1000.0 and srv == "verified" and not bool(_ledger()["orders"][oid]["finished"]) and int(billing.stats["grants"]) == 1,
		"여전히 못 쓰면 restore 도 consume·finish 를 하지 않음 (메모리에만 있는 지급은 '이미 받은 주문'이 아님)")
	_chmod("755", dir)
	await _restore()
	srv = str(_server()["orders"]["dev:" + oid]["st"])
	var rec: Variant = (JsonX.parse(str(_disk(path).get(IapRules.KEY, "{}"))) as Dictionary).get("orders", {}).get("dev:" + oid)
	_check(_disk_gold(path) == 2200.0 and rec is Dictionary and str(rec["st"]) == "done" and srv == "consumed" and bool(_ledger()["orders"][oid]["finished"]) and int(billing.stats["grants"]) == 1,
		"쓸 수 있게 되면 저장 → 디스크 골드 2200 · 기록 done · 그다음에야 consume·finish (지급 1번)")
	store.call("use_path", SAVE)
	_chmod("755", dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# X1: 메모리와 디스크가 어긋남 (flush 는 성공이라는데 실제로 쓰이지 않음 — 시험 훅) → 디스크 재확인이 잡아야 함
	_fresh(1000.0)
	store.set("debug_fake_write_ok", true)
	var rx := await _buy_wait("gold_500")
	var ox := str((_ledger()["orders"] as Dictionary).keys()[0]) if (_ledger()["orders"] as Dictionary).size() == 1 else ""
	var sx := str(_server()["orders"].get("dev:" + ox, {}).get("st", ""))
	_check(rx.get("status") == "save_failed" and _disk_gold(SAVE) == 1000.0 and sx == "verified" and not bool(_ledger()["orders"][ox]["finished"]),
		"flush 가 거짓으로 성공해도(디스크에 없음) consume·finish 안 함 — save_failed (디스크 재확인)")
	store.set("debug_fake_write_ok", false)
	await _restore()
	sx = str(_server()["orders"]["dev:" + ox]["st"])
	_check(_disk_gold(SAVE) == 1500.0 and sx == "consumed" and bool(_ledger()["orders"][ox]["finished"]) and int(billing.stats["grants"]) == 1, "디스크가 돌아오면 메모리를 다시 써서 저장 → 그 뒤 consume·finish (지급 1번)")
	# 재검수 7: 내용이 잘린 기록에서 '지급했지만 consume 전(granted)' 주문 — 서버는 verified
	_fresh(1000.0)
	var rg := await _buy_wait("gold_1200")
	var og := str(rg.get("order_id", ""))
	var Lg := _ledger()
	Lg["orders"][og]["finished"] = false
	Files.write(Files.STORE_FILE, Lg)
	var Sg := _server()
	Sg["orders"]["dev:" + og]["st"] = "verified"
	Files.write(Files.SERVER_FILE, Sg)
	var gi: Dictionary = store.call("get_json", IapRules.KEY)
	gi["orders"]["dev:" + og]["st"] = "granted"
	var keep_iid := str(gi["iid"])
	# (가) iid 는 남고 그 주문 내용이 잘림
	var raw := JsonX.stringify({"v": 1, "iid": keep_iid, "orders": gi["orders"]})
	var cut := raw.substr(0, raw.find("dev:" + og) + ("dev:" + og).length() + 12)
	store.call("set_str", IapRules.KEY, cut)
	SaveSanitize.sanitize(_ctx())
	var lost: Variant = _orders().get("dev:" + og)
	await _restore()
	_check(lost is Dictionary and bool(lost.get("lost", false)) and _gold() == 2200.0 and str(_server()["orders"]["dev:" + og]["st"]) == "consumed" and bool(_ledger()["orders"][og]["finished"]),
		"잘린 기록의 granted 주문(서버 verified, iid 남음): 주문 번호로 '끝남' 표시 → 다시 지급하지 않음 (골드 2200) · consume·finish 만")
	# (나) iid 까지 잘림 — 새 iid 라 서버는 order_claimed: 다시 지급하지 않음(중복 0), 주문은 미소모로 남음 (api.md 3.6 — iid 바깥 보존으로 해결할 일)
	var Lg2 := _ledger()
	Lg2["orders"][og]["finished"] = false
	Files.write(Files.STORE_FILE, Lg2)
	var Sg2 := _server()
	Sg2["orders"]["dev:" + og]["st"] = "verified"
	Files.write(Files.SERVER_FILE, Sg2)
	var raw2 := JsonX.stringify({"v": 1, "orders": gi["orders"], "iid": keep_iid})
	store.call("set_str", IapRules.KEY, raw2.substr(0, raw2.find("dev:" + og) + ("dev:" + og).length() + 12))
	SaveSanitize.sanitize(_ctx())
	await _restore()
	_check(_gold() == 2200.0 and str(_server()["orders"]["dev:" + og]["st"]) == "verified", "iid 까지 잘리면: 다시 지급하지 않음 (골드 2200) · 서버 주문은 verified 로 남음 (문서화된 남은 경우)")
	# 일부러 만든 쓰기 실패 오류는 'Godot 오류 0' 에서 뺌 (따로 셈)
	var mine := _counter.errors.filter(func(e: String) -> bool: return e.contains("iap_ro/save.json.tmp"))
	_counter.errors = _counter.errors.filter(func(e: String) -> bool: return not e.contains("iap_ro/save.json.tmp"))
	_stat("durable.expected_write_errors", mine.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


# ═══════════ 6b) 출격 직전 같은 프레임 ═══════════

## 이길 때까지 (장면은 두고) → Router 로 로비 → 로비가 뜰 때까지
func _play_to_lobby(bt: Node) -> float:
	var g: Dictionary = JsonX.parse(FileAccess.get_file_as_string("res://tests/golden/%s.json" % BATTLE_GOLDEN))
	var cmds: Array = []
	for e: Dictionary in g["events"]:
		if e["ev"] == "cmd":
			cmds.append(e)
	var ci := 0
	var frames := 0
	while frames < 60000 and not bt.is_over():
		await process_frame
		frames += 1
		if bt.is_awaiting() and ci < cmds.size():
			if not _drive(bt, cmds[ci]):
				break
			ci += 1
	await _frames(3)
	var gold := _gold()
	router.call("go", "lobby")
	await _until(func() -> bool: return _screen_is("ui/lobby.gd"), 8.0)
	await _frames(3)
	return gold


func _battle_now() -> Node:
	var s := current_scene
	if s != null and s.get_script() != null and str((s.get_script() as Script).resource_path).ends_with("battle_scene.gd") and s.is_node_ready():
		return s
	return null


func _t_sortie() -> void:
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	router.call("go", "lobby")
	await _until(func() -> bool: return _screen_is("ui/lobby.gd"), 8.0)
	_check(not billing.in_battle(), "로비: 전투 아님")
	BS.set("pending", {"x": 1})
	var p1: bool = billing.in_battle()
	BS.set("pending", {})
	router.set("current", "battle")
	var p2: bool = billing.in_battle()
	router.set("current", "lobby")
	_check(p1 and p2 and not billing.in_battle(), "전투 판정: BattleScene.pending 이 있거나 Router.current == battle 이면 전투 중")
	# 기준: 결제 없이 이긴 판
	var bt0 := await _start_battle()
	var base0 := _gold()
	var base_end := await _win_battle(bt0)
	# 같은 프레임: 서버 확인 응답이 돌아오는 그 프레임에 출격 (store_save 사본 → pending → 장면은 프레임 끝에 붙음) → 그 뒤 지급 시도
	Files.reset()
	_store_battle_cfg(BATTLE_GOLDEN)
	billing.set_scenario("success")
	var launched := [false, false]
	billing.verifier.debug_hook = func(path: String) -> void:
		if path.ends_with("/purchases/verify") and not launched[0]:
			launched[0] = true
			var cfg := _store_battle_cfg_keep()
			router.call("launch_battle", cfg)
			launched[1] = billing.in_battle()
	var r := await _buy_wait("gold_1200")
	billing.verifier.debug_hook = Callable()
	_check(launched[0] and launched[1] and r.get("status") == "deferred" and _orders().is_empty() and _gold() == base0, "출격과 같은 프레임의 지급 → 미룸 (사본을 만든 직후에도 전투 중으로 봄)")
	_check(await _until(func() -> bool: return _battle_now() != null and _battle_now().is_awaiting(), 20.0), "전투 장면이 뜸")
	var g_end := await _play_to_lobby(_battle_now())
	await _until(func() -> bool: return _orders().size() == 1 and str(_orders().values()[0]["st"]) == "done", 6.0)
	_check(g_end == base_end and _gold() == base_end + 1200.0, "전투 결과 %s 를 덮어쓰지 않고 로비에서 +1200 = %s" % [g_end, _gold()])
	# 환불 경로 (M9): 환불 목록 응답이 오는 그 프레임에 출격 → 회수 미룸 → 전투 뒤 회수
	var oid := str((_ledger()["orders"] as Dictionary).keys()[0])
	billing.backend.refund(oid)
	launched = [false, false]
	billing.verifier.debug_hook = func(path: String) -> void:
		if path.ends_with("/refunds") and not launched[0]:
			launched[0] = true
			router.call("launch_battle", _store_battle_cfg_keep())
	await _until(func() -> bool: return not bool(billing.get("_restoring")), 10.0)
	await billing.restore(true)
	billing.verifier.debug_hook = Callable()
	var mid := _gold()
	_check(launched[0] and str(_orders()["dev:" + oid]["st"]) == "done", "환불 목록 응답과 같은 프레임에 출격 → 회수 미룸 (기록 그대로 done)")
	_check(await _until(func() -> bool: return _battle_now() != null and _battle_now().is_awaiting(), 20.0), "전투 장면이 뜸 (2)")
	var g_end2 := await _play_to_lobby(_battle_now())
	await _until(func() -> bool: return str(_orders()["dev:" + oid]["st"]) == "revoked", 6.0)
	_check(str(_orders()["dev:" + oid]["st"]) == "revoked" and _gold() == g_end2 - 1200.0, "전투가 끝난 뒤 회수 (전투 결과를 덮어쓰지 않음) (%s → %s)" % [g_end2, _gold()])
	store.call("clear")


## 지금 Store 그대로 전투 설정 (출격처럼 store_save 사본)
func _store_battle_cfg_keep() -> Dictionary:
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	var cfg: Dictionary = BS.call("golden_cfg", BATTLE_GOLDEN)
	cfg["save"] = BS.call("store_save", store)
	cfg["source"] = "store"
	cfg["speed"] = 0.0
	cfg["story"] = "off"
	cfg["loading"] = false
	return cfg


# ═══════════ 6c) 재claim · 보안 ═══════════

func _t_claim() -> void:
	_fresh(1000.0)
	billing.set_scenario("success")
	var fake = billing.verifier.fake if _server_url == "" else Remote.new(_server_url)
	var r := await _buy_wait("gold_1200")
	var oid := str(r.get("order_id", ""))
	var iid_a := str((store.call("get_json", IapRules.KEY) as Dictionary)["iid"])
	var acct_a := str(_ledger()["orders"][oid].get("acct", ""))
	_check(acct_a == billing.account_token(iid_a) and acct_a == iid_a.sha256_text().substr(0, 32), "구매에 넣은 계정 토큰 = SHA-256(iid) 앞 32자")
	# A 가 지급만 하고 consume 전에 사라졌다고 침: 서버 verified · 가게 미처리 · A 기록 granted
	var S := _server()
	S["orders"]["dev:" + oid]["st"] = "verified"
	Files.write(Files.SERVER_FILE, S)
	var L := _ledger()
	L["orders"][oid]["finished"] = false
	Files.write(Files.STORE_FILE, L)
	var a_iap: Dictionary = store.call("get_json", IapRules.KEY)
	a_iap["orders"]["dev:" + oid]["st"] = "granted"
	# B: 재설치 (새 iid, 기록 없음)
	store.call("clear")
	store.call("set_json", "game_save", {"gold": 1000.0, "cleared": [1]})
	fake.clock_offset_ms = 23.0 * 3600000.0
	await _restore()
	var iid_b := str((store.call("get_json", IapRules.KEY) as Dictionary).get("iid", ""))
	_check(iid_b != iid_a and _gold() == 1000.0 and _orders().is_empty(), "재설치(새 iid) 23시간 뒤: order_claimed → 지급 안 함 (24시간 안)")
	fake.clock_offset_ms = 25.0 * 3600000.0
	await _restore()
	S = _server()
	_check(_gold() == 2200.0 and str(_orders().values()[0]["st"]) == "done" and str(S["orders"]["dev:" + oid]["install_id"]) == iid_b and str(S["orders"]["dev:" + oid]["st"]) == "consumed",
		"25시간 뒤: 진짜 결제 · 미소모 주문을 새 iid 가 다시 claim → 지급 · consume (주인 B) · 서버 로그 reclaimed_from=A")
	_check(str(S["orders"]["dev:" + oid].get("reclaimed_from", "")) == iid_a and int(S["orders"]["dev:" + oid].get("reclaims", 0)) == 1, "재claim 이 서버 기록에 남음 (reclaimed_from · reclaimed_at · reclaims)")
	var b_save: Dictionary = {"game_save": store.call("get_json", "game_save"), IapRules.KEY: store.call("get_json", IapRules.KEY)}
	# A 가 돌아옴: consume → order_claimed → A 의 지급 회수 (한 주문은 한 설치만)
	store.call("clear")
	store.call("set_json", "game_save", {"gold": 2200.0, "cleared": [1]})
	store.call("set_json", IapRules.KEY, a_iap)
	# 전투로 들어가는 중이면 A 의 회수도 미룸
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	billing.verifier.debug_hook = func(path: String) -> void:
		if path.ends_with("/purchases/consume"):
			BS.set("pending", {"x": 1})
	await _restore()
	billing.verifier.debug_hook = Callable()
	_check(_gold() == 2200.0 and str(_orders()["dev:" + oid]["st"]) == "granted", "consume 응답 때 전투로 들어가는 중 → 주인을 잃은 회수도 미룸")
	BS.set("pending", {})
	await _restore()
	_check(_gold() == 1000.0 and str(_orders()["dev:" + oid]["st"]) == "revoked", "주인을 잃은 A: consume 이 order_claimed → A 의 1200 회수 (B 만 가짐)")
	# 다른 설치 C 가 더 늦게 와도 consumed 는 consumed
	store.call("clear")
	store.call("set_json", "game_save", {"gold": 500.0, "cleared": [1]})
	L = _ledger()
	L["orders"][oid]["finished"] = false
	Files.write(Files.STORE_FILE, L)
	fake.clock_offset_ms = 50.0 * 3600000.0
	await _restore()
	_check(_gold() == 500.0 and _orders().is_empty(), "consumed 주문은 시간이 지나도 다른 설치에 다시 주지 않음 (consumed > claim)")
	# 보안: 공격자 iid + 피해자 account_id
	var atk := "abababababababababababababababab"
	billing.backend.refund(oid)
	var hd := {"X-D15-Install": atk}
	var rf: Dictionary = fake.handle("GET", "/v1/refunds", {"cursor": "", "env": "dev", "account_id": acct_a}, hd, {})
	var cs: Dictionary = fake.handle("POST", "/v1/purchases/consume", {}, hd, {"store": "dev", "order_id": oid, "env": "dev", "account_id": acct_a})
	var hb := {"X-D15-Install": iid_b}
	var rf_b: Dictionary = fake.handle("GET", "/v1/refunds", {"cursor": "", "env": "dev"}, hb, {})
	_check((rf["body"]["orders"] as Array).is_empty() and int(cs["status"]) == 403 and (rf_b["body"]["orders"] as Array).size() == 1,
		"공격자 iid + 피해자 account_id: 환불 목록 0개 · consume 403 (주인 B 의 iid 로만 보임)")
	# 새 주문을 피해자가 확인받은 직후, 공격자가 같은 영수증 + 피해자 account_id 로 verify → 403
	fake.clock_offset_ms = 0.0
	_fresh(1000.0)
	var r2 := await _buy_wait("gold_500")
	var oid2 := str(r2.get("order_id", ""))
	var L2 := _ledger()
	var o2: Dictionary = L2["orders"][oid2]
	o2["finished"] = false
	Files.write(Files.STORE_FILE, L2)
	var tx2: Dictionary = billing.backend._tx(oid2, o2, "purchased")
	S = _server()
	S["orders"]["dev:" + oid2]["st"] = "verified"
	Files.write(Files.SERVER_FILE, S)
	var vb := {"store": "dev", "product_id": "gold_500", "store_product_id": "gold_500", "order_id": oid2, "receipt": tx2["receipt"], "env": "dev", "account_id": str(o2["acct"])}
	var v1: Dictionary = fake.handle("POST", "/v1/purchases/verify", {}, hd, vb)
	_check(int(v1["status"]) == 403 and str(v1["body"]["error"]["code"]) == "order_claimed", "공격자가 피해자 영수증 + 피해자 account_id(본문) → 403 (본문 계정 값은 믿지 않음)")
	var vb2 := vb.duplicate()
	vb2["receipt"] = JSON.stringify({"oid": oid2, "spid": "gold_500", "acct": "x", "sig": JSON.parse_string(str(tx2["receipt"]))["sig"]})
	_check(int(fake.handle("POST", "/v1/purchases/verify", {}, hd, vb2)["status"]) == 422, "영수증의 계정 값을 바꾸면 서명이 깨져 422")
	var ve := vb.duplicate()
	ve["env"] = "prod"
	_check(str(fake.handle("POST", "/v1/purchases/verify", {}, hd, ve)["body"]["error"]["code"]) == "env_mismatch" and str(fake.handle("GET", "/v1/refunds", {"cursor": ""}, hd, {})["body"]["error"]["code"]) == "env_mismatch",
		"env 가 다르거나 없으면 env_mismatch (verify · refunds)")
	# 재claim 은 주문당 1번 · 가게에서 소모된(Google consumptionState=1) 주문은 재claim 거절
	fake.clock_offset_ms = 0.0
	_fresh(1000.0)
	var rx := await _buy_wait("gold_500")
	var ox := str(rx.get("order_id", ""))
	var Lx := _ledger()
	Lx["orders"][ox]["finished"] = false
	Files.write(Files.STORE_FILE, Lx)
	var Sx := _server()
	Sx["orders"]["dev:" + ox]["st"] = "verified"
	Files.write(Files.SERVER_FILE, Sx)
	var txx: Dictionary = billing.backend._tx(ox, _ledger()["orders"][ox], "purchased")
	var vbx := {"store": "dev", "product_id": "gold_500", "store_product_id": "gold_500", "order_id": ox, "receipt": txx["receipt"], "env": "dev"}
	fake.clock_offset_ms = 24.0 * 3600000.0 - 60000.0
	var e0 := int(fake.handle("POST", "/v1/purchases/verify", {}, {"X-D15-Install": "11111111111111111111111111111111"}, vbx)["status"])
	fake.clock_offset_ms = 24.0 * 3600000.0 + 60000.0
	var e1: Dictionary = fake.handle("POST", "/v1/purchases/verify", {}, {"X-D15-Install": "11111111111111111111111111111111"}, vbx)
	fake.clock_offset_ms = 60.0 * 3600000.0
	var e2: Dictionary = fake.handle("POST", "/v1/purchases/verify", {}, {"X-D15-Install": "22222222222222222222222222222222"}, vbx)
	_check(e0 == 403 and int(e1["status"]) == 200 and bool(e1["body"].get("reclaimed", false)) and int(e2["status"]) == 403 and str(e2["body"]["error"]["code"]) == "reclaim_limit",
		"24시간 경계: 1분 전 403 · 1분 뒤 재claim · 두 번째 재claim(다른 설치, 그 뒤 24시간 넘어도) 403 reclaim_limit")
	Lx = _ledger()
	Lx["orders"][ox]["finished"] = true   # 가게 쪽 소모 (Google consumptionState=1)
	Files.write(Files.STORE_FILE, Lx)
	Sx = _server()
	Sx["orders"]["dev:" + ox]["reclaims"] = 0
	Files.write(Files.SERVER_FILE, Sx)
	var e3: Dictionary = fake.handle("POST", "/v1/purchases/verify", {}, {"X-D15-Install": "33333333333333333333333333333333"}, vbx)
	_check(int(e3["status"]) == 403 and str(e3["body"]["error"]["code"]) == "already_delivered", "가게에서 이미 소모된 주문(Google consumptionState=1)은 재claim 거절 403 already_delivered")
	fake.clock_offset_ms = 0.0
	fake.clock_offset_ms = 0.0
	_stat("claim.b_save_gold", b_save["game_save"])


# ═══════════ 6e) 서버 429 · 501 ═══════════

## 가짜 서버 또는 (-- --server) 로컬 Worker 의 시험 훅
func _srv() -> Variant:
	return billing.verifier.fake if _server_url == "" else Remote.new(_server_url)


func _t_errors() -> void:
	# 429 rate_limited: 구매 확인이 요청 과다로 거절 → 지급 없음 · 가게에 미처리로 남음 → 다음 restore 에서 한 번 지급
	_fresh(1000.0)
	billing.set_scenario("success")
	var srv = _srv()
	srv.force_429 = 1
	var r := await _buy_wait("gold_500")
	var unfin := 0
	for o: Dictionary in _ledger()["orders"].values():
		if not bool(o["finished"]):
			unfin += 1
	_check(r.get("status") == "verify_failed" and str(r.get("code")) == "rate_limited" and _gold() == 1000.0 and _orders().is_empty() and unfin == 1,
		"429 rate_limited → verify_failed (다시 시도) · 지급 0 · 가게 미처리 (%s)" % str(r))
	await _restore()
	_check(_gold() == 1500.0 and _orders().size() == 1 and str(_orders().values()[0]["st"]) == "done" and int(billing.stats["grants"]) == 1, "제한이 풀린 뒤 restore → +500 한 번 · done")
	# 429 가 consume 에서 나면: 기록 granted 로 남았다가 다음에 done (골드 한 번)
	_fresh(1000.0)
	var cut := func(_i: String, _g: float, _o: String) -> void: _srv().force_429 = 1
	billing.granted.connect(cut, CONNECT_ONE_SHOT)
	r = await _buy_wait("gold_500")
	var st1 := str(_orders().values()[0]["st"]) if _orders().size() == 1 else "?"
	await _restore()
	var st2 := str(_orders().values()[0]["st"]) if _orders().size() == 1 else "?"
	_check(r.get("status") == "granted" and st1 == "granted" and st2 == "done" and _gold() == 1500.0, "consume 이 429 → granted 로 남음 → 다음 restore 에서 done (골드 한 번)")
	# 501 not_implemented (STOVE 확인 미구현): 5xx 라 '다시 시도' — 지급하지 않음
	var iid := str((store.call("get_json", IapRules.KEY) as Dictionary)["iid"])
	var v: Dictionary = await billing.verifier.verify({"store": "stove", "pid": "gold_500", "spid": "gold_500", "order_id": "T123", "receipt": "T123"}, iid)
	_check(str(v.get("status")) == "error" and str(v.get("code")) == "not_implemented", "STOVE verify → 501 not_implemented → status error (다시 시도, 지급 없음) %s" % str(v))
	var c: Dictionary = await billing.verifier.consume({"store": "stove", "order_id": "T123"}, iid)
	_check(not bool(c.get("ok", true)) and str(c.get("code")) == "unknown_order", "verify 를 못 받은 STOVE 주문 consume → 404 unknown_order (기록 없음)")


# ═══════════ 6d) 그 밖 ═══════════

func _t_misc() -> void:
	# iid = Crypto 16바이트
	_fresh(0.0)
	var i1: String = billing._iid(_ctx())
	store.call("clear")
	var i2: String = billing._iid(_ctx())
	_check(IapRules.is_iid(i1) and IapRules.is_iid(i2) and i1 != i2 and FileAccess.get_file_as_string("res://scripts/core/billing.gd").contains("Crypto.new().generate_random_bytes(16)"), "설치 식별자 = Crypto 16바이트 (32자 16진수)")
	# iid 바깥 저장소 확장 지점 (Block Store · Keychain · STOVE 클라우드 — 모바일·STOVE 작업에서 연결)
	store.call("clear")
	var saved := [""]
	billing.set_iid_store(func() -> String: return "cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd", func(v: String) -> void: saved[0] = v)
	var i3: String = billing._iid(_ctx())
	store.call("clear")
	billing.set_iid_store(func() -> String: return "", func(v: String) -> void: saved[0] = v)
	var i4: String = billing._iid(_ctx())
	billing.set_iid_store(Callable(), Callable())
	_check(i3 == "cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd" and IapRules.is_iid(i4) and saved[0] == i4, "set_iid_store: 세이브에 iid 가 없으면 바깥 저장소 값을 쓰고, 새로 만든 값은 바깥 저장소로 넘김")
	# 모든 데이터 초기화: game_iap 는 보존
	_fresh(1000.0)
	var r := await _buy_wait("gold_500")
	IapRules.bak_push(_ctx(), "t", "x", 1.0)
	var before: String = store.call("get_str", IapRules.KEY)
	var bak0: String = store.call("get_str", IapRules.BAK_KEY)
	router.call("go", "settings")
	await _until(func() -> bool: return _screen_is("ui/settings_screen.gd"), 5.0)
	router.set("dry_run", true)
	current_scene.call("reset_all")
	router.set("dry_run", false)
	_check(r.get("status") == "granted" and store.call("get_str", IapRules.KEY) == before and store.call("get_str", IapRules.BAK_KEY) == bak0 and not store.call("has", "game_save"),
		"'모든 데이터 초기화': 게임 진행은 지우고 game_iap(iid · 주문 · 환불 커서)와 bak 은 그대로")
	_check(str(_disk(SAVE).get(IapRules.KEY, "")) == before, "초기화 뒤 디스크에도 game_iap")
	current_scene.set("_resetting", false)
	router.call("go", "lobby")
	await _until(func() -> bool: return _screen_is("ui/lobby.gd"), 8.0)
	# 진행 중 창 탈출구
	_fresh(1000.0)
	billing.set_scenario("success")
	billing.backend.delay = 1.5
	var sh := await _open_shop("gold")
	sh.progress_escape_secs = 0.3
	sh.set("_act_frame", -1)
	sh.buy_iap("gold_3000")
	await _frames(2)
	(sh.find_child("Layer", true, false).find_child("IapConfirmModal", true, false).find_child("Yes", true, false) as Button).pressed.emit()
	await create_timer(0.1).timeout
	var no_btn: bool = sh.find_child("EscapeClose", true, false) == null
	await create_timer(0.4).timeout
	var esc: Button = sh.find_child("EscapeClose", true, false)
	var note: Label = sh.find_child("EscapeNote", true, false)
	_check(no_btn and esc != null and note != null and note.text == i18n.call("t", "gd.iap.escape_note"), "진행 중 창: 정해진 시간 뒤 안내 + '닫기' (그 전엔 없음)")
	esc.pressed.emit()
	await _frames(2)
	sh.call("render")
	await _frames(2)
	var b3k: Button = sh.find_child("Iap_gold_3000", true, false).find_child("Buy", true, false)
	var b5k: Button = sh.find_child("Iap_gold_500", true, false).find_child("Buy", true, false)
	_check(_modals(sh, "IapProgress") == 0 and str(sh.get("_paying")) == "" and not billing.busy() and billing.purchase_pending("gold_3000")
		and b3k.disabled and b3k.text == i18n.call("t", "gd.iap.processing_short") and not b5k.disabled and not billing.buy("gold_3000"),
		"닫기 → 창 닫힘 · busy 풀림 · 그 상품 카드만 '처리 중'(막힘), 다른 카드는 살 수 있음")
	var r5 := await _buy_wait("gold_500")
	await _until(func() -> bool: return not billing.purchase_pending("gold_3000"), 5.0)
	await _frames(3)
	_check(r5.get("status") == "granted" and _gold() == 4500.0 and sh.find_child("Toast", true, false) != null, "다른 상품(500)도 사고, 닫았던 3000 도 나중에 지급 + 알림 띠 (합계 4500)")
	# 진행 중인 구매를 restore 가 먼저 처리 → 사는 사람에게는 '지급 완료'
	billing.backend.delay = 0.05
	var tx: Dictionary = await billing.backend.purchase("gold_500", "gold_500", {"account_token": billing.account_token(billing._iid(_ctx()))})
	var g0 := _gold()
	billing.restore(true)
	await _frames(2)
	var box := {"r": null}
	var cb := func(_i: String, rr: Dictionary) -> void: box["r"] = rr
	billing.purchase_finished.connect(cb)
	billing.set("_busy", true)
	await billing._finish_buy("gold_500", tx)
	billing.purchase_finished.disconnect(cb)
	_check(box["r"] != null and str(box["r"]["status"]) == "granted" and _gold() == g0 + 500.0, "restore 가 먼저 지급한 진행 중 구매 → 결과는 '지급 완료' (dup 아님), +500 한 번")
	await _frames(3)
	# 저장 실패 문구
	_check(i18n.call("t", "gd.iap.save_failed") != i18n.call("t", "gd.iap.retry_later") and str(i18n.call("t", "gd.iap.save_failed")).contains("저장"), "save_failed 전용 문구")
	# 카드 그림: 양마다 다름
	sh.switch_tab("gold")
	await _frames(2)
	var texs: Array = []
	for id: String in ["gold_500", "gold_1200", "gold_3000", "gold_6500"]:
		texs.append((sh.find_child("Iap_" + id, true, false).find_child("IapIcon", true, false) as TextureRect).texture)
	var uniq := {}
	for tx3: Variant in texs:
		uniq[tx3] = true
	_check(uniq.size() == 4 and not texs.has(null), "결제 카드 그림 4개가 모두 다름 (기존 그림)")
	router.call("go", "lobby")
	await _frames(4)
	# 기준 덧붙이기 허용 목록 · 이어하기 해시에서 iap 제외
	_check(DataDBT.OVERLAY_MODULES == ["iap"] and ResumeRules.HASH_EXCLUDE == ["iap"], "기준 덧붙이기 허용 목록 = [iap] · 이어하기 데이터 해시에서 iap 제외")
	db.call("use_dir", "res://data/")
	var src: Dictionary = (db.get("manifest") as Dictionary)["sources"].duplicate()
	var with_iap := JsonX.stringify(src).md5_text()
	src.erase("iap")
	var st: Dictionary = ResumeRules.current_stamp()
	_check(str(st["dataHash"]) == JsonX.stringify(src).md5_text() and str(st["dataHash"]) != with_iap, "지금 데이터의 이어하기 해시 = iap 를 뺀 sources (iap.json 을 고쳐도 저장 전투는 그대로)")
	BaselineData.apply(self)


# ═══════════ 7) 상점 화면 · 같은 프레임 연타 ═══════════

func _open_shop(tab: String) -> Node:
	router.call("go", "shop", {"tab": tab})
	await _until(func() -> bool: return _screen_is("ui/shop.gd"), 5.0)
	await _frames(4)
	return current_scene


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


func _modals(scr: Node, nm: String) -> int:
	var n := 0
	for ch: Node in scr.find_child("Layer", true, false).get_children():
		if str(ch.name).begins_with(nm) and not ch.is_queued_for_deletion():
			n += 1
	return n


func _t_tap() -> void:
	_fresh(1000.0)
	billing.set_scenario("success")
	billing.backend.delay = 0.3
	var sh := await _open_shop("gold")
	var grid: Node = sh.find_child("IapGrid", true, false)
	_check(grid != null and grid.get_child_count() == 4 and sh.find_child("Unavailable", true, false) == null, "dev 상점 골드 탭: 결제 카드 4개 (켜짐)")
	var prices: Array = []
	for card: Node in grid.get_children():
		prices.append((card.find_child("Price", true, false) as Label).text)
	_check(prices == ["₩1,200", "₩2,500", "₩6,500", "₩12,000"], "카드 가격 = Billing.products() 가격 글 %s" % str(prices))
	var src := FileAccess.get_file_as_string("res://scripts/ui/shop.gd")
	_check(not src.contains("gold_iap_coming"), "'추후 오픈 예정' 표시 지움")
	var buy: Button = sh.find_child("Iap_gold_500", true, false).find_child("Buy", true, false)
	await _double_click(buy)
	_check(_modals(sh, "IapConfirmModal") == 1, "구매 단추 같은 프레임 두 번(push_input) → 확인 창 1개")
	var cm: Node = sh.find_child("Layer", true, false).find_child("IapConfirmModal", true, false)
	var notice := []
	for k: String in ["notice_withdraw", "notice_refund_store", "notice_vat", "notice_minor"]:
		var l: Label = cm.find_child(k, true, false)
		notice.append(l != null and l.text.contains(i18n.call("t", "gd.iap." + k)))
	var ShopT: GDScript = load("res://scripts/ui/shop.gd")
	_check(notice == [true, true, true, true] and cm.find_child("notice_refund_policy", true, false) == null and (cm.find_child("Price", true, false) as Label).text == "₩1,200",
		"확인 창(ko): 상품 · 가격 · 7일 청약철회(사용한 재화 제한) · 스토어 고객센터 · 부가세 포함 · 미성년자")
	var other_ok := true
	for lg: String in ["en", "es", "ja", "zh-CN", "zh-TW"]:
		var ks: Array = ShopT.call("notice_keys", lg)
		other_ok = other_ok and ks == ["gd.iap.notice_refund_policy", "gd.iap.notice_price_store", "gd.iap.notice_minor"]
	_check(other_ok and (ShopT.call("notice_keys", "ko") as Array).has("gd.iap.notice_withdraw"), "그 밖의 언어: 7일 문구 대신 '스토어 환불 정책' · '가격·세금은 스토어 기준' · 미성년자")
	var yes: Button = cm.find_child("Yes", true, false)
	await _double_click(yes)
	_check(billing.busy() and _modals(sh, "IapProgress") == 1, "'구매' 같은 프레임 두 번 → 진행 중 창 1개 · 결제 1번 시작")
	# 진행 중에는 다른 카드도 막힘
	var b2: Button = sh.find_child("Iap_gold_1200", true, false).find_child("Buy", true, false)
	_check(b2.disabled, "진행 중에는 다른 결제 카드 단추 꺼짐")
	_check(not bool(billing.buy("gold_3000")), "진행 중 Billing.buy 거절")
	await _until(func() -> bool: return not billing.busy(), 5.0)
	await _frames(3)
	var alerts := _modals(sh, "Alert")
	var al: Node = sh.find_child("Layer", true, false).find_child("Alert", true, false)
	_check(_modals(sh, "IapProgress") == 0 and alerts == 1 and al != null and str(al.get_meta("iap_status", "")) == "granted", "끝나면 진행 창 닫고 결과 창 1개 (granted)")
	_check(_gold() == 1500.0 and (_ledger()["orders"] as Dictionary).size() == 1 and sh.gold_lbl.text == "1,500 G", "주문 1개 · +500 · 골드 배지 1,500 G")
	sh.close_all_modals()
	await _frames(2)
	# 코드로 같은 프레임 두 번
	sh.set("_act_frame", -1)
	sh.buy_iap("gold_500")
	sh.buy_iap("gold_500")
	await _frames(2)
	_check(_modals(sh, "IapConfirmModal") == 1, "buy_iap 같은 프레임 두 번 → 확인 창 1개 (act_once)")
	sh.close_all_modals()
	await _frames(2)
	# 취소 시나리오: 결과 창 '취소'
	billing.set_scenario("cancel")
	sh.set("_act_frame", -1)
	sh.buy_iap("gold_3000")
	await _frames(2)
	(sh.find_child("Layer", true, false).find_child("IapConfirmModal", true, false).find_child("Yes", true, false) as Button).pressed.emit()
	await _until(func() -> bool: return not billing.busy() and sh.get("_paying") == "", 5.0)
	await _frames(2)
	var al2: Node = sh.find_child("Layer", true, false).find_child("Alert", true, false)
	_check(al2 != null and str(al2.get_meta("iap_status", "")) == "cancelled" and _gold() == 1500.0, "취소 → 결과 창 '취소', 골드 그대로")
	sh.close_all_modals()
	await _frames(2)
	# 판별 카드: steam 숨김 · stove 꺼짐
	platform.call("override_os", "Windows")
	for st: String in ["steam", "stove", "stove_mac"]:
		platform.call("override_store", st.trim_suffix("_mac"))
		if st == "stove_mac":
			platform.call("override_os", "macOS")
		sh.call("render")
		await _frames(2)
		var g2: Node = sh.find_child("IapGrid", true, false)
		if st != "stove":
			_check(g2 == null, "%s: 결제 카드 숨김 (결제 백엔드 없음)" % st)
		else:
			var b3: Button = g2.find_child("Buy", true, false) if g2 != null else null
			_check(g2 != null and g2.get_child_count() == 4 and b3 != null and b3.disabled and sh.find_child("Unavailable", true, false) != null, "stove: 결제 카드 4개 · SDK 를 붙이기 전이라 꺼짐 ('지금은 구매할 수 없음')")
	platform.call("override_store", "dev")
	platform.call("override_os", "")
	billing.set_scenario("success")
	billing.backend.delay = 0.05
	# 상점에 들어오면 미처리 거래를 다시 처리 (대기 → 승인)
	router.call("go", "lobby")
	await _frames(4)
	billing.set_scenario("pending")
	var rp := await _buy_wait("gold_500")
	billing.set_scenario("success")
	billing.set("_last_refund_ms", -Billing_GAP())
	var g_before := _gold()
	sh = await _open_shop("gold")
	await _until(func() -> bool: return _gold() == g_before + 500.0, 5.0)
	await _frames(2)
	var toast: Node = sh.find_child("Toast", true, false)
	_check(rp.get("status") == "pending" and _gold() == g_before + 500.0 and toast != null, "상점 진입 → 대기였던 결제 지급 + 알림 띠")
	router.call("go", "lobby")
	await _frames(4)


# ═══════════ 8) 광고 ═══════════

func _t_ads() -> void:
	var c := _mem_ctx({"game_save": {"gold": 0.0}})
	var d1 := "2026-10-18"
	_check(AdRules.left(c, d1) == 3, "처음: 오늘 3회")
	var ok := true
	for i in 3:
		ok = ok and AdRules.grant(c, d1).get("ok", false)
	_check(ok and AdRules.left(c, d1) == 0 and _mgold(c) == 300.0 and AdRules.grant(c, d1).get("err") == "limit" and _mgold(c) == 300.0, "하루 3회 · 100G 씩 · 4번째는 limit")
	_check(AdRules.left(c, "2026-10-19") == 3, "날짜가 바뀌면 다시 3회")
	AdRules.grant(c, "2026-10-19")
	_check(AdRules.left(c, "2026-10-19") == 2 and AdRules.used(c, "2026-10-18") == 3, "새 날에 1회 → 남은 2회 (다녀간 18일은 그날 횟수 3 그대로)")
	_check(AdRules.left(c, "2026-10-17") == 2 and AdRules.grant(c, "2026-10-17").get("ok", false) and str(c.store.get_json(AdRules.KEY)["day"]) == "2026-10-19" and AdRules.left(c, "2026-10-19") == 1,
		"시계 되돌림(10-17): 새 날로 보지 않음 — 저장된 날(10-19)의 횟수를 그대로 씀")
	c.store.set_json(AdRules.KEY, {"v": 1, "day": "2026-10-21", "n": 3})
	_check(AdRules.left(c, "2026-10-19") == 0 and AdRules.left(c, "2026-10-22") == 3, "시계를 이틀 앞으로 돌려 받고 되돌리면 그 날짜가 지날 때까지 기다림 (2일 이하)")
	c.store.set_json(AdRules.KEY, {"v": 1, "day": "2026-10-22", "n": 3})
	_check(AdRules.left(c, "2026-10-19") == 0 and AdRules.grant(c, "2026-10-19").get("err") == "limit" and str(c.store.get_json(AdRules.KEY)["day"]) == "2026-10-19" and AdRules.left(c, "2026-10-20") == 3,
		"저장된 날이 2일 넘게 앞섬(3일) → 시계를 고친 것으로 보고 기기 날짜로 다시 맞춤 — 그날은 다 쓴 것(3), 다음 날부터 정상")
	# 시계 앞뒤 반복 (18일 ↔ 21일 3번) — 실제 이틀치(6회)를 넘지 않음
	var c2 := _mem_ctx({"game_save": {"gold": 0.0}})
	var got := 0
	for rnd in 3:
		for dd: String in ["2026-10-18", "2026-10-21"]:
			for k in 5:
				if AdRules.grant(c2, dd).get("ok", false):
					got += 1
	_check(got <= 6 and got == 6, "시계를 18일↔21일로 3번 오가며 받아도 합계 %d회 (6 이하 — 날마다 3회)" % got)
	var got2 := 0
	for dd2: String in ["2026-10-18", "2026-10-25", "2026-10-18", "2026-10-25", "2026-10-19"]:
		for k2 in 5:
			if AdRules.grant(c2, dd2).get("ok", false):
				got2 += 1
	_check(got2 == 3, "다녀간 날은 다시 새로 받지 못함 · 시계를 고친 날(19일)도 0 — 새로 받은 것은 처음 가 본 25일 3회뿐 (%d)" % got2)
	_check(AdRules.day_str({"year": 2026, "month": 1, "day": 5}) == "2026-01-05", "날짜 글 YYYY-MM-DD (기기 로컬)")
	# Ads 노드 (가짜 광고)
	_fresh(1000.0)
	ads.today_override = "2026-10-18"
	var ev := {"rw": 0, "cl": 0, "fl": []}
	var on_rw := func(_p: String, _g: float) -> void: ev["rw"] += 1
	var on_cl := func(_p: String) -> void: ev["cl"] += 1
	var on_fl := func(_p: String, code: String) -> void: (ev["fl"] as Array).append(code)
	ads.rewarded.connect(on_rw)
	ads.closed.connect(on_cl)
	ads.failed.connect(on_fl)
	_check(ads.is_supported() and ads.is_available() and ads.left_today() == 3, "dev 디버그: 가짜 광고 · 오늘 3회")
	_check(ads.show_rewarded("t") and ads.showing() and ads.find_child("FakeAd", true, false) != null, "가짜 광고 화면이 뜸")
	_check(not ads.show_rewarded("t") and (ev["fl"] as Array).has("busy"), "광고가 떠 있을 때 또 부르면 거절")
	var cb: Button = ads.find_child("AdClose", true, false)
	cb.pressed.emit()
	await _frames(2)
	_check(int(ev["cl"]) == 1 and int(ev["rw"]) == 0 and _gold() == 1000.0 and ads.left_today() == 3, "끝까지 안 보고 닫기 → 보상 없음, 횟수 그대로")
	for i in 3:
		ads.show_rewarded("t")
		var btn: Button = ads.find_child("AdClose", true, false)
		await _until(func() -> bool: return btn.text == i18n.call("t", "gd.ads.close_reward"), 3.0)
		btn.pressed.emit()
		await _frames(2)
	_check(int(ev["rw"]) == 3 and _gold() == 1300.0 and ads.left_today() == 0, "끝까지 보고 닫기 3번 → +300 · 남은 0")
	_check(float((JsonX.parse(str(_disk(SAVE).get("game_save", "{}"))) as Dictionary).get("gold", -1)) == 1300.0, "광고 보상도 바로 디스크에")
	_check(not ads.show_rewarded("t") and (ev["fl"] as Array).has("limit"), "4번째 → limit")
	ads.today_override = "2026-10-19"
	_check(ads.left_today() == 3, "다음 날 → 3회")
	# 상점 광고 카드 (탭마다 · 하루 합계)
	var sh := await _open_shop("mercenary")
	var cards := 0
	var same := true
	for tab: String in ShopRules.TABS:
		sh.switch_tab(tab)
		await _frames(2)
		var card: Node = sh.find_child("AdCard", true, false)
		if card != null:
			cards += 1
			same = same and (card.find_child("AdText", true, false) as Label).text == i18n.call("t", "gd.ads.card", {"gold": 100, "max": 3})
	_check(cards == 6 and same, "dev 판: 6개 탭마다 광고 카드 (웹 배치) — 보상 글은 모두 같은 골드")
	sh.switch_tab("skill")
	await _frames(2)
	var w: Button = sh.find_child("AdBtn", true, false)
	_check(w.name == "AdBtn" and not w.disabled and (sh.find_child("AdLeft", true, false) as Label).text == i18n.call("t", "gd.ads.left", {"n": 3, "max": 3}), "광고 단추 켜짐 · 오늘 3/3")
	w.pressed.emit()
	await _frames(1)
	var btn2: Button = ads.find_child("AdClose", true, false)
	await _until(func() -> bool: return btn2.text == i18n.call("t", "gd.ads.close_reward"), 3.0)
	btn2.pressed.emit()
	await _frames(3)
	sh.switch_tab("scroll")
	await _frames(2)
	_check(_gold() == 1400.0 and (sh.find_child("AdLeft", true, false) as Label).text == i18n.call("t", "gd.ads.left", {"n": 2, "max": 3}) and sh.gold_lbl.text == "1,400 G",
		"스킬 탭에서 본 광고 → 전직서 탭 카드도 2/3 (하루 합계)")
	sh.close_all_modals()
	for st: String in ["stove", "steam", "google"]:
		platform.call("override_store", st)
		var n_card := 0
		for tab: String in ShopRules.TABS:
			sh.switch_tab(tab)
			await _frames(1)
			if sh.find_child("AdCard", true, false) != null:
				n_card += 1
		if st == "google":
			var gb: Button = sh.find_child("AdBtn", true, false)
			_check(n_card == 6 and gb.disabled and gb.text == i18n.call("t", "common.coming_soon") and not ads.is_available(), "google: 광고 카드는 보이되 SDK 전이라 꺼짐")
		else:
			_check(n_card == 0 and not ads.is_supported() and not ads.show_rewarded("x") and (ev["fl"] as Array).has("unsupported"), "%s(PC): 광고 카드 0 · 광고 없음" % st)
	platform.call("override_store", "dev")
	ads.rewarded.disconnect(on_rw)
	ads.closed.disconnect(on_cl)
	ads.failed.disconnect(on_fl)
	router.call("go", "lobby")
	await _frames(4)
	ads.today_override = ""


# ═══════════ 9) 확률표 ═══════════

func _t_odds() -> void:
	var c := Ctx.new(Ctx.globals_from_db(db), 12345)
	var GR: Dictionary = c.D["GACHA_RATE"]
	var raw := 0.0
	for v: Variant in GR.values():
		raw += float(v)
	_check(absf(raw - 1.0) < 1e-9, "장비 뽑기 등급 확률 합 = 100%% (데이터 %s)" % str(raw))
	var tfn := func(k: String, p: Dictionary) -> String: return str(i18n.call("t", k, p))
	var secs := OddsRules.sections(c, tfn)
	var g: Dictionary = secs[0]
	var ok := true
	var RAR: Dictionary = c.D["RARITY"]
	var rare_t := float(RAR["rare"]["tier"])
	var hi := 0.0
	for r: String in GR.keys():
		if float(RAR[r]["tier"]) >= rare_t:
			hi += float(GR[r])
	var i := 0
	for r: String in GR.keys():
		var row: Array = g["rows"][i]
		var exp_last := OddsRules.pct(float(GR[r]) / hi) if float(RAR[r]["tier"]) >= rare_t else "-"
		ok = ok and row[0] == tfn.call("equip.rarity." + r, {}) and row[1] == OddsRules.pct(float(GR[r]) / raw) and row[2] == exp_last
		i += 1
	ok = ok and (g["rows"] as Array).back()[1] == "100%" and (g["rows"] as Array).back()[2] == "100%"
	_check(ok, "장비 뽑기 표 = GACHA_RATE / 합 · 10+1 마지막 = 희귀 이상만 다시 나눔 · 합계 100%")
	_check(str(g["notes"][0]).contains(str(int(c.D["GACHA_PITY_MAX"]))) and str(g["notes"][1]).contains(str(int(c.D["GACHA_MULTI_COUNT"]))), "천장 %d회 · 10+1 = %d개 (데이터의 수)" % [int(c.D["GACHA_PITY_MAX"]), int(c.D["GACHA_MULTI_COUNT"])])
	var ru: Dictionary = secs[1]
	var nk := (c.D["ENCHANTS"] as Dictionary).size()
	var rok := (ru["rows"] as Array).size() == nk + 1
	for j in nk:
		rok = rok and ru["rows"][j][1] == OddsRules.pct(1.0 / float(nk))
	_check(rok and (ru["rows"] as Array).back()[1] == "100%", "룬 뽑기 표: %d종 균등 (%s)" % [nk, OddsRules.pct(1.0 / float(nk))])
	var en: Dictionary = secs[2]
	var rates: Array = c.D["ENHANCE_RATES"]
	var eok := (en["rows"] as Array).size() == int(c.D["ENHANCE_MAX_LV"])
	for lv in (en["rows"] as Array).size():
		var row2: Array = en["rows"][lv]
		var rr := float(rates[lv])
		eok = eok and row2[1] == OddsRules.pct(rr) and row2[2] == OddsRules.pct(1.0 - rr) and row2[4] == OddsRules.pct((1.0 - rr) * float(c.D["ENHANCE_BREAK_CHANCE"])) \
			and row2[3] == tfn.call("gd.odds.drop" if lv >= int(c.D["ENHANCE_SAFE_BELOW"]) else "gd.odds.keep", {})
	_check(eok, "강화 표: 성공 = ENHANCE_RATES · 파손 = 실패 × ENHANCE_BREAK_CHANCE · +%d 부터 하락" % int(c.D["ENHANCE_SAFE_BELOW"]))
	# 규칙 함수로 직접 뽑아 본 빈도 (표의 식이 규칙 코드와 같은지)
	var N := 200000
	var cnt: Dictionary = {}
	for k in N:
		var rr2 := Gear.roll_rarity(c, null)
		cnt[rr2] = int(cnt.get(rr2, 0)) + 1
	var mc_ok := true
	var mc: Dictionary = {}
	for r: String in GR.keys():
		var p := float(GR[r]) / raw
		var f := float(cnt.get(r, 0)) / float(N)
		var sd := sqrt(p * (1.0 - p) / float(N))
		mc[r] = snappedf(f * 100.0, 0.001)
		mc_ok = mc_ok and absf(f - p) <= 5.0 * sd + 1e-6
	_stat("odds.mc_rarity_pct", mc)
	var cnt2: Dictionary = {}
	for k in 50000:
		var rr3 := Gear.roll_rarity(c, "rare")
		cnt2[rr3] = int(cnt2.get(rr3, 0)) + 1
	var mc2 := not cnt2.has("common") and not cnt2.has("uncommon") and absf(float(cnt2.get("rare", 0)) / 50000.0 - float(GR["rare"]) / hi) < 0.01
	var cnt3: Dictionary = {}
	for k in 60000:
		var rk := Gear.rune_random(c)
		cnt3[rk] = int(cnt3.get(rk, 0)) + 1
	var mc3 := cnt3.size() == nk
	for kk: String in cnt3.keys():
		mc3 = mc3 and absf(float(cnt3[kk]) / 60000.0 - 1.0 / float(nk)) < 0.01
	_check(mc_ok and mc2 and mc3, "규칙 함수(roll_rarity · 희귀 이상 · rune_random)로 뽑은 빈도가 표와 맞음 (%d번)" % N)
	# 창의 글 = 표 (상점 장비 탭 · 강화 탭)
	_fresh(1000.0)
	var sh := await _open_shop("equip")
	var ob: Button = sh.find_child("OddsBtn", true, false)
	_check(ob.visible, "상점 장비 탭에 '확률 정보' 단추")
	ob.pressed.emit()
	await _frames(3)
	_check(_odds_matches(sh, secs), "상점 '확률 정보' 창의 글 = 표 (3개 구역 · 머리·칸 모두)")
	sh.close_all_modals()
	sh.switch_tab("consumable")
	await _frames(2)
	_check((sh.find_child("OddsBtn", true, false) as Button).visible, "소모품 탭(룬 뽑기)에도 단추")
	sh.switch_tab("mercenary")
	await _frames(2)
	_check(not (sh.find_child("OddsBtn", true, false) as Button).visible, "용병 탭에는 없음")
	router.call("go", "party_select")
	await _until(func() -> bool: return _screen_is("ui/party_select.gd"), 5.0)
	await _frames(3)
	var ps := current_scene
	ps.switch_page_tab("enhance")
	await _frames(3)
	var ob2: Button = ps.find_child("OddsBtn", true, false)
	_check(ob2 != null and ob2.is_visible_in_tree(), "편성 강화 탭에 '확률 정보' 단추")
	ob2.pressed.emit()
	await _frames(3)
	_check(_odds_matches(ps, secs), "강화 탭 '확률 정보' 창의 글 = 표")
	ps.close_all_modals()
	router.call("go", "lobby")
	await _frames(4)
	# docs/store 6개 파일이 지금 데이터의 표와 같은지 (지금 데이터로 — 기준 데이터가 아님)
	db.call("use_dir", "res://data/")
	i18n.call("reload")
	var cl := Ctx.new(Ctx.globals_from_db(db), 1)
	var stale: Array = []
	for lang: String in OddsExport.LANGS:
		var md := OddsExport.render_md(cl, i18n, lang)
		var p := OddsExport.out_path(lang)
		if not FileAccess.file_exists(p) or FileAccess.get_file_as_string(p) != md or not md.contains("| " + OddsRules.pct(float(cl.D["GACHA_RATE"]["legendary"]) / raw) + " |"):
			stale.append(lang)
	_check(stale.is_empty(), "docs/store/probabilities.{ko,en,ja,zh-CN,zh-TW,es}.md = 지금 데이터의 표 (낡은 것 %s)" % str(stale))
	BaselineData.apply(self)
	i18n.call("_apply", "ko")


func _odds_matches(scr: Node, secs: Array) -> bool:
	var m: Node = scr.find_child("Layer", true, false).find_child("OddsModal", true, false)
	if m == null:
		return false
	for sec: Dictionary in secs:
		var gd: GridContainer = m.find_child("Grid_" + str(sec["id"]), true, false)
		if gd == null:
			return false
		var want: Array = (sec["head"] as Array).duplicate()
		for row: Array in sec["rows"]:
			want.append_array(row)
		var got: Array = []
		for ch: Node in gd.get_children():
			got.append((ch as Label).text)
		if got != want:
			print("    표 다름 %s: %s ≠ %s" % [sec["id"], str(got.slice(0, 6)), str(want.slice(0, 6))])
			return false
	return true


# ═══════════ 10) 6개 언어 ═══════════

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
		if txt != "":
			n += 1
			for i in txt.length():
				var cp := txt.unicode_at(i)
				if cp < 32 or cp == 0x200B:
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


func _collect(all: Array, tag: String, a: Array) -> int:
	for o: String in a[0]:
		all.append("[%s] 넘침 %s" % [tag, o])
	for tf: String in a[1]:
		all.append("[%s] 두부 %s" % [tag, tf])
	return int(a[2])


func _t_lang() -> void:
	var all: Array = []
	var total := 0
	var states := 0
	billing.set_scenario("success")
	for res: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 576)]:
		root.size = res
		for lang: String in LANGS:
			_fresh(1234567.0)
			ads.today_override = "2026-10-18"
			i18n.call("_apply", lang)
			var tag := "%dx%d %s" % [res.x, res.y, lang]
			var sh := await _open_shop("gold")
			total += _collect(all, tag + " 골드 탭", _audit(sh, lang))
			states += 1
			sh.set("_act_frame", -1)
			sh.buy_iap("gold_6500")
			await _frames(4)
			total += _collect(all, tag + " 구매 확인 창", _audit(sh, lang))
			sh.close_all_modals()
			billing.backend.delay = 5.0
			billing.set_scenario("cancel")
			sh.progress_escape_secs = 0.05
			sh.call("_start_iap", "gold_6500")
			await _frames(4)
			await create_timer(0.15).timeout
			await _frames(2)
			if sh.find_child("EscapeClose", true, false) == null:
				all.append("[%s] 진행 중 창 '닫기' 없음" % tag)
			total += _collect(all, tag + " 진행 중 창(닫기 안내)", _audit(sh, lang))
			await _until(func() -> bool: return not billing.busy(), 8.0)
			billing.backend.delay = 0.05
			sh.close_all_modals()
			await _frames(2)
			for st: String in ["granted", "dup", "cancelled", "pending", "verify_failed", "deferred", "invalid", "failed", "save_failed"]:
				sh.set("_paying", "gold_6500")
				sh.call("_on_purchase_finished", "gold_6500", {"status": st, "gold": 6500.0, "code": "invalid_receipt"})
				await _frames(3)
				total += _collect(all, tag + " 결과 " + st, _audit(sh, lang))
				sh.close_all_modals()
			states += 12
			sh.call("_on_revoked", "gold_6500", 6500.0, "x")
			await _frames(2)
			total += _collect(all, tag + " 회수 알림", _audit(sh, lang))
			# 광고 카드 · 남은 0 · 가짜 광고 화면
			sh.switch_tab("mercenary")
			await _frames(2)
			total += _collect(all, tag + " 광고 카드", _audit(sh, lang))
			ads.show_rewarded("t")
			await _frames(3)
			total += _collect(all, tag + " 가짜 광고", _audit(ads.find_child("FakeAd", true, false), lang))
			var btn: Button = ads.find_child("AdClose", true, false)
			await _until(func() -> bool: return btn.text == i18n.call("t", "gd.ads.close_reward"), 3.0)
			total += _collect(all, tag + " 가짜 광고 끝", _audit(ads.find_child("FakeAd", true, false), lang))
			btn.pressed.emit()
			await _frames(2)
			total += _collect(all, tag + " 광고 보상 창", _audit(sh, lang))
			sh.close_all_modals()
			store.call("set_json", AdRules.KEY, {"v": 1, "day": "2026-10-18", "n": 3})
			sh.call("render")
			await _frames(2)
			total += _collect(all, tag + " 광고 0회", _audit(sh, lang))
			# 확률 창
			sh.switch_tab("equip")
			await _frames(2)
			total += _collect(all, tag + " 장비 탭(단추)", _audit(sh, lang))
			sh.set("_act_frame", -1)
			sh.open_odds()
			await _frames(4)
			total += _collect(all, tag + " 확률 창", _audit(sh, lang))
			sh.close_all_modals()
			# stove: 꺼진 결제 카드
			platform.call("override_store", "stove")
			sh.switch_tab("gold")
			await _frames(2)
			total += _collect(all, tag + " stove 골드 탭", _audit(sh, lang))
			platform.call("override_store", "google")
			sh.switch_tab("mercenary")
			await _frames(2)
			total += _collect(all, tag + " google 광고 카드", _audit(sh, lang))
			platform.call("override_store", "dev")
			states += 9
			# 편성 강화 탭 + 확률 창
			router.call("go", "party_select")
			await _until(func() -> bool: return _screen_is("ui/party_select.gd"), 5.0)
			await _frames(3)
			var ps := current_scene
			ps.switch_page_tab("enhance")
			await _frames(3)
			total += _collect(all, tag + " 강화 탭", _audit(ps, lang))
			(ps.find_child("OddsBtn", true, false) as Button).pressed.emit()
			await _frames(4)
			total += _collect(all, tag + " 강화 확률 창", _audit(ps, lang))
			ps.close_all_modals()
			states += 2
			router.call("go", "lobby")
			await _frames(3)
	root.size = Vector2i(1280, 720)
	i18n.call("_apply", "ko")
	ads.today_override = ""
	_stat("lang.labels", total)
	_stat("lang.states", states)
	for p: String in all.slice(0, 20):
		print("    " + p)
	_check(all.is_empty(), "6개 언어 × 2 크기: 결제·광고·확률 화면 %d가지 — 넘침 0 · 두부 0 (글 %d개, 문제 %d)" % [states, total, all.size()])
