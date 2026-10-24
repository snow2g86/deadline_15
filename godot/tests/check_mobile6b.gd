extends SceneTree
## 6b 시험 — 모바일 결제(Google Play · App Store)와 광고(AdMob)를 가짜 SDK 객체로 모든 길을 시험
##   Godot --headless --path godot --script res://tests/check_mobile6b.gd   [-- --only google,apple,ads,ui,config,bridge,lang]
##  1) config  : data/iap.json 의 ADMOB(구글 공개 시험 ID · 실제 ID 자리는 비어 있음 · 아동 대상 아님) · 광고 단위 고르기(디버그=시험, 출시=real) · project.godot 앱 ID 일치 ·
##               출시 빌드는 https 만(http·fake:// 거절) · 에뮬레이터 주소 · appAccountToken UUID 규칙
##  2) google  : BackendGoogle 단독(연결 성공·실패·무응답, 가격, 구매 성공·취소·대기·오류·이미 소유, 미처리 조회, 소모, 직렬화, 플러그인 없음) +
##               Billing 전체 순서(서버 verify → 전투 중 미룸 → 지급 → 디스크 확정 → consume): 앱이 죽었다 다시 켜짐 2곳 · 서버 5xx·429·거절 · 소모 실패 · 서버가 이미 소모
##  3) apple   : BackendApple + 가짜 어댑터 (JWS 영수증 · appAccountToken · Ask to Buy · 환불된 미처리 · finish 실패) + 진짜 어댑터를 PC 에서 끼워 본 연기 시험
##  4) ads     : Ads 상태 기계(동의 → 초기화 → 불러오기 → 보여 주기 → 보상) — 불러오기 실패(네트워크·광고 없음) 재시도 · 보상 · 하루 3회 · 날짜·시계 · 동의 거부·재시도 · 닫기(보상 없음) · 띄우기 실패 · 개인정보 입구
##  5) ui      : 상점 광고 카드 상태별 단추(준비·불러오는 중·오프라인·동의·오늘 다 받음) · PC(stove·steam)에서 광고 카드 숨김 · 설정 '광고 개인정보 설정' 단추(모바일만)
##  6) bridge  : 진짜 admob_bridge.gd 를 플러그인의 편집기용 가짜(mock)로 돌려 API 이름·인자 오류와 무응답 처리를 확인
##  7) lang    : 6개 언어 × 1280×720 · 1024×576 — 광고 카드 상태 6가지 · 설정 단추 넘침 0 · 두부 0
##  Godot 오류(Logger 로 셈) 0 이어야 통과. 저장은 user://test_mobile6b_save.json, 가짜 가게·서버는 user://fake_iap/ (끝나면 지움)

const BaselineData := preload("res://tests/baseline_data.gd")
const JsonX := preload("res://scripts/core/json_exact.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")
const StoreCtx := preload("res://scripts/logic/store_ctx.gd")
const IapRules := preload("res://scripts/logic/iap_rules.gd")
const AdRules := preload("res://scripts/logic/ad_rules.gd")
const ShopRules := preload("res://scripts/logic/shop_rules.gd")
const Files := preload("res://scripts/core/billing/fake_files.gd")
const FontsT := preload("res://scripts/core/fonts.gd")
const BillingT := preload("res://scripts/core/billing.gd")
const AdsT := preload("res://scripts/core/ads.gd")
const BackendGoogle := preload("res://scripts/core/billing/backend_google.gd")
const BackendApple := preload("res://scripts/core/billing/backend_apple.gd")
const AppleIap := preload("res://scripts/core/billing/apple_iap.gd")
const AdmobBridge := preload("res://scripts/core/ads/admob_bridge.gd")
const VerifierT := preload("res://scripts/core/billing/verifier.gd")
const Pc5 := preload("res://tests/check_pc5.gd")
const FakePlay := preload("res://tests/fake_play_client.gd")
const FakeApple := preload("res://tests/fake_apple_iap.gd")
const FakeBridge := preload("res://tests/fake_admob_bridge.gd")
const FakeStoreServer := preload("res://tests/fake_store_server.gd")

const SAVE := "user://test_mobile6b_save.json"
const LANGS := ["ko", "en", "es", "ja", "zh-CN", "zh-TW"]
const TODAY := "2026-10-21"

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
	BaselineData.apply(self)
	store = root.get_node("Store")
	i18n = root.get_node("I18n")
	router = root.get_node("Router")
	platform = root.get_node("Platform")
	billing = root.get_node("Billing")
	ads = root.get_node("Ads")
	db = root.get_node("DataDB")
	store.call("use_path", SAVE)
	store.call("clear")
	platform.call("override_store", "dev")
	billing.call("_ensure_backend")
	Files.reset()
	i18n.call("_apply", "ko")
	root.size = Vector2i(1280, 720)
	billing.set("_started", true)   # 첫 화면 알림을 이미 받은 것으로 (백엔드의 unfinished_changed → restore 시험)
	for sec: Array in [["config", "1) 설정·규칙"], ["google", "2) Google Play"], ["apple", "3) App Store"], ["ads", "4) AdMob 상태 기계"],
			["ui", "5) 상점 카드·설정 단추"], ["bridge", "6) 진짜 다리 + 플러그인 mock"], ["export", "7) 내보내기 설정·플러그인 파일·라이선스 화면"], ["lang", "8) 6개 언어 넘침·두부"]]:
		if not _want(sec[0]):
			continue
		print("── %s ──" % sec[1])
		await call("_t_" + str(sec[0]))
	platform.call("override_store", "")
	platform.call("emulate_mobile", false)
	ads.today_override = ""
	ads.bridge = null
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


# ── 공통 ──

func _ctx() -> Object:
	return Ctx.new(Ctx.globals_from_db(db), 7, StoreCtx.new(store))


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
	billing.set("_last_refund_ms", -60000)
	billing.set("_want_check", false)
	billing.set("_session_granted", {})
	for k: String in billing.stats.keys():
		billing.stats[k] = 0


func _orders() -> Dictionary:
	return IapRules.load_iap(_ctx())["orders"]


func _iid() -> String:
	return str(IapRules.load_iap(_ctx()).get("iid", ""))


func _disk_orders() -> Dictionary:
	var raw := FileAccess.get_file_as_string(ProjectSettings.globalize_path(SAVE))
	var d: Variant = JsonX.parse(raw) if raw != "" else null
	if not (d is Dictionary) or not (d.get("game_iap") is String):
		return {}
	var g: Variant = JsonX.parse(str(d["game_iap"]))
	return (g.get("orders") as Dictionary) if g is Dictionary and g.get("orders") is Dictionary else {}


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


func _settle() -> void:
	await _until(func() -> bool: return not billing.get("_restoring") and not billing.busy(), 8.0)
	await _frames(2)


# ═══════════ 1) 설정·규칙 ═══════════

func _t_config() -> void:
	var D := Ctx.globals_from_db(db)
	var A: Dictionary = D["ADMOB"]
	_check(A["test"]["app_id"] == {"android": "ca-app-pub-3940256099942544~3347511713", "ios": "ca-app-pub-3940256099942544~1458002511"}, "ADMOB.test.app_id = 구글 공개 시험 앱 ID (안드로이드·iOS)")
	_check(A["test"]["rewarded"] == {"android": "ca-app-pub-3940256099942544/5224354917", "ios": "ca-app-pub-3940256099942544/1712485313"}, "ADMOB.test.rewarded = 구글 공개 시험 보상형 단위")
	_check(A["real"]["app_id"] == {"android": "", "ios": ""} and A["real"]["rewarded"] == {"android": "", "ios": ""}, "ADMOB.real 은 비어 있음 (사용자가 AdMob 에서 만든 뒤 채움 — 추측해서 넣지 않음)")
	_check(A["child_directed"] == false and A["under_age_of_consent"] == false and A["max_ad_content_rating"] == "", "아동 대상 앱 아님(false) 명시 · 미성년 동의 연령 미만 아님 · 콘텐츠 등급 제한 없음")
	_check(AdsT.unit_for(A, true, "android") == A["test"]["rewarded"]["android"] and AdsT.unit_for(A, true, "ios") == A["test"]["rewarded"]["ios"], "디버그 빌드 → 시험 광고 단위 (안드로이드·iOS)")
	_check(AdsT.unit_for(A, false, "android") == "" and AdsT.unit_for(A, false, "ios") == "", "출시 빌드 + real 비어 있음 → 광고 단위 없음 (시험 단위로 대신하지 않음)")
	var A2: Dictionary = A.duplicate(true)
	A2["real"]["rewarded"]["android"] = "ca-app-pub-1/2"
	_check(AdsT.unit_for(A2, false, "android") == "ca-app-pub-1/2" and AdsT.unit_for(A2, true, "android") == A["test"]["rewarded"]["android"], "real 을 채우면 출시 빌드만 그것을 씀 (디버그는 여전히 시험 단위)")
	_check(AdsT.unit_for(null, true, "android") == "" and AdsT.unit_for({}, true, "android") == "", "ADMOB 이 없어도 오류 없음")
	# project.godot 앱 ID (플러그인이 AndroidManifest · Info.plist 에 넣음) = 데이터
	var want_a: String = A["real"]["app_id"]["android"] if A["real"]["app_id"]["android"] != "" else A["test"]["app_id"]["android"]
	var want_i: String = A["real"]["app_id"]["ios"] if A["real"]["app_id"]["ios"] != "" else A["test"]["app_id"]["ios"]
	_check(str(ProjectSettings.get_setting("admob/general/android/app_id", "")) == want_a and str(ProjectSettings.get_setting("admob/general/ios/app_id", "")) == want_i,
		"project.godot 의 admob 앱 ID = data/iap.json (real 이 비어 있으면 시험 ID)")
	_check(bool(ProjectSettings.get_setting("admob/general/android/enabled", false)) and bool(ProjectSettings.get_setting("admob/general/ios/enabled", false)), "admob 안드로이드·iOS 켜짐")
	var mediation_on: Array = []
	for lib: String in ["applovin", "bidmachine", "chartboost", "dtexchange", "imobile", "inmobi", "ironsource", "line", "maio", "meta", "mintegral", "moloco", "mytarget", "pangle", "pubmatic", "unity_ads", "vungle"]:
		if bool(ProjectSettings.get_setting("admob/mediation/" + lib, false)):
			mediation_on.append(lib)
	_check(mediation_on.is_empty(), "중개(mediation) 어댑터 모두 꺼짐 — 광고 SDK 는 구글 것만")
	# 서버 주소 규칙
	var v: Node = VerifierT.new()
	root.add_child(v)
	var prods := IapRules.products(_ctx())
	var cases := [["http://10.0.2.2:8951", false, ""], ["http://10.0.2.2:8951", true, "http://10.0.2.2:8951"], ["http://127.0.0.1:8951", false, ""], ["fake://local", false, ""], ["fake://local", true, "fake://local"],
		["https://iap.example.com", false, "https://iap.example.com"], ["", false, ""], ["HTTP://10.0.2.2", false, ""], ["ftp://x", false, ""]]
	var bad: Array = []
	for cs: Array in cases:
		v.configure("prod", {"url": cs[0]}, prods, "t", bool(cs[1]))
		if str(v.base_url) != str(cs[2]):
			bad.append("%s(debug=%s) → '%s'" % [cs[0], str(cs[1]), v.base_url])
	_check(bad.is_empty(), "출시 빌드는 https 만 (http·에뮬레이터 10.0.2.2·fake:// 모두 거절) %s" % str(bad))
	v.queue_free()
	var cfg: Dictionary = D["IAP_SERVER"]["local"]
	_check(str(cfg["url"]) == "http://127.0.0.1:8951" and str(cfg["android_url"]) == "http://10.0.2.2:8951" and BillingT.EMULATOR_SERVER == "http://10.0.2.2:8951", "개발용 로컬 서버 주소: 맥 127.0.0.1 · 안드로이드 에뮬레이터 10.0.2.2:8951 (IAP_SERVER.local.android_url)")
	_check(str(D["IAP_SERVER"]["prod"]["url"]) == "" and str(D["IAP_SERVER"]["stage"]["url"]).begins_with("https://"), "prod 서버 주소는 아직 비어 있고(배포 전), stage 는 https 주소 (2026-10-24 배포)")
	# appAccountToken (Apple) · obfuscatedAccountId (Google)
	var iid := "0123456789abcdef0123456789abcdef"
	var tok := BillingT.account_token(iid)
	var uu := BillingT.account_uuid(iid)
	var rx := RegEx.new()
	rx.compile("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
	_check(tok == iid.sha256_text().substr(0, 32) and uu.replace("-", "") == tok and rx.search(uu) != null, "계정 토큰 = SHA-256(iid) 앞 32자 · Apple UUID = 같은 값을 8-4-4-4-12 로 (%s)" % uu)
	_check(BillingT.account_uuid(iid) == BillingT.account_uuid(iid) and BillingT.account_uuid("f".repeat(32)) != uu, "UUID 는 iid 마다 정해진 값")


# ═══════════ 2) Google Play ═══════════

func _google(catalog: Dictionary = {"gold_500": "₩1,200", "gold_1200": "₩2,500", "gold_3000": "₩6,500", "gold_6500": "₩12,000"}) -> Array:
	var cl: Node = FakePlay.new()
	cl.catalog = catalog
	var be: Node = BackendGoogle.new()
	be.client = cl
	be.timeouts = {"connect": 0.4, "query": 0.4, "consume": 0.4, "purchase": 0.8}
	return [be, cl]


## 새 가짜 클라이언트를 단 Google 백엔드를 Billing 에 끼움 + 대본형 서버
func _inject_google(catalog: Dictionary = {"gold_500": "₩1,200", "gold_1200": "₩2,500", "gold_3000": "₩6,500", "gold_6500": "₩12,000"}) -> Array:
	platform.call("override_store", "google")
	var pair := _google(catalog)
	billing.inject_backend(pair[0], "dev")
	var srv: RefCounted = FakeStoreServer.new(IapRules.products(_ctx()))
	billing.verifier.fake = srv
	billing.verifier.net_down = false
	return [pair[0], pair[1], srv]


func _t_google() -> void:
	var prods := IapRules.products(_ctx())
	# 플러그인이 없는 환경 (PC · 편집기)
	_fresh(1000.0)
	var none: Node = BackendGoogle.new()
	root.add_child(none)
	await _frames(2)
	var tx0: Dictionary = await none.purchase("gold_500", "gold_500", {})
	_check(not none.is_supported() and not none.is_available() and (await none.query_products(prods)).is_empty() and (await none.query_unfinished()).is_empty()
		and str(tx0.get("state")) == "failed" and str(tx0.get("error")) == "unavailable" and not (await none.finish({"receipt": "x"})) and not await none.prepare(),
		"플러그인 없음: is_supported·is_available 거짓, 모든 호출이 오류 없이 빈 결과·'unavailable'")
	none.queue_free()
	platform.call("override_store", "google")
	billing.set("_store_name", "")
	billing.set("backend", null)
	_check(not billing.is_supported() and not billing.is_available() and not billing.buy("gold_500") and billing.products().size() == 4, "Billing: PC 에서 --store google → 결제 길 없음 · buy 거절 · 상품 표는 그대로")
	billing.restore()
	await _settle()
	billing.refresh_products()
	await _frames(3)
	_check(_gold() == 1000.0, "플러그인 없는 판에서 restore·refresh 는 아무 일도 안 함")
	platform.call("override_store", "dev")
	billing.set("_store_name", "")
	billing.set("backend", null)
	billing.call("_ensure_backend")
	# 연결
	var p := _google()
	var be: Node = p[0]
	var cl: Node = p[1]
	root.add_child(be)
	await _frames(4)
	_check(be.is_supported() and be.is_available() and int(cl.calls.get("start_connection", 0)) == 1, "연결 성공 → 사용 가능 (시작할 때 한 번만 연결)")
	_check(await be.prepare() and int(cl.calls.get("start_connection", 0)) == 1, "연결된 뒤 prepare 는 다시 연결하지 않음")
	cl.drop_connection()
	_check(not be.is_available() and await be.prepare() and be.is_available() and int(cl.calls["start_connection"]) == 2, "연결이 끊기면 다음 prepare 가 다시 연결")
	be.queue_free()
	var pe := _google()
	pe[1].connect_mode = "error"
	root.add_child(pe[0])
	await _frames(4)
	_check(pe[0].is_supported() and not pe[0].is_available() and pe[0].last_connect_code == 3, "연결 실패(BILLING_UNAVAILABLE 3): 앱은 그대로, 사용 불가로만 (구글 플레이가 없는 기기)")
	var txe: Dictionary = await pe[0].purchase("gold_500", "gold_500", {})
	_check(str(txe.get("state")) == "failed" and str(txe.get("error")) == "unavailable" and (await pe[0].query_unfinished()).is_empty(), "연결 못 한 채 구매 → failed unavailable, 미처리 조회는 빈 목록")
	pe[1].connect_mode = "ok"
	_check(await pe[0].prepare() and pe[0].is_available(), "나중에 연결되면 회복")
	pe[0].queue_free()
	var ps := _google()
	ps[1].connect_mode = "silent"
	root.add_child(ps[0])
	var t0 := Time.get_ticks_msec()
	var okc: bool = await ps[0].prepare()
	_check(not okc and ps[0].last_connect_code == BackendGoogle.RC_SERVICE_TIMEOUT and Time.get_ticks_msec() - t0 < 2500, "연결 응답이 없으면 제한 시간 뒤 실패 (영영 기다리지 않음)")
	ps[0].queue_free()
	# 가격
	var p2 := _google({"gold_500": "$0.99", "gold_1200": "$1.99"})
	var b2: Node = p2[0]
	root.add_child(b2)
	await _frames(4)
	var rows: Array = await b2.query_products(prods)
	var got := {}
	for r: Dictionary in rows:
		got[r["pid"]] = r["price"]
	_check(got == {"gold_500": "$0.99", "gold_1200": "$1.99"}, "가격: 가게가 준 현지 가격 글 (등록 안 된 상품은 빠짐) %s" % str(got))
	p2[1].query_mode = "error"
	_check((await b2.query_products(prods)).is_empty(), "가격 조회 오류 → 빈 목록 (화면은 fallback 가격)")
	p2[1].query_mode = "silent"
	t0 = Time.get_ticks_msec()
	_check((await b2.query_products(prods)).is_empty() and Time.get_ticks_msec() - t0 < 2500, "가격 조회 무응답 → 제한 시간 뒤 빈 목록")
	b2.queue_free()
	# 구매 (백엔드 단독)
	var p3 := _google()
	var b3: Node = p3[0]
	var c3: Node = p3[1]
	root.add_child(b3)
	await _frames(4)
	b3.set_products(prods)
	var tx: Dictionary = await b3.purchase("gold_500", "gold_500", {"account_token": "abc123"})
	var pur: Dictionary = c3.owned[0]
	_check(str(tx["state"]) == "purchased" and tx["store"] == "google" and tx["pid"] == "gold_500" and tx["spid"] == "gold_500" and tx["order_id"] == pur["order_id"] and tx["receipt"] == pur["purchase_token"] and c3.obfuscated == "abc123",
		"구매 성공: order_id = orderId · receipt = purchaseToken · obfuscatedAccountId 설정")
	_check(int(c3.calls.get("query_product_details", 0)) == 1, "가격 조회를 안 한 상품은 구매 직전에 조회 (플러그인 요구)")
	c3.owned.clear()
	var pur_empty: Dictionary = c3.make_purchase("gold_500", 1, "")
	pur_empty["order_id"] = ""
	c3.owned = [pur_empty]
	var uf: Array = await b3.query_unfinished()
	_check(uf.size() == 1 and uf[0]["order_id"] == pur_empty["purchase_token"] and uf[0]["receipt"] == pur_empty["purchase_token"], "orderId 가 없으면(시험 결제) purchaseToken 이 order_id")
	c3.owned.clear()
	c3.purchase_mode = "cancel"
	_check(str((await b3.purchase("gold_500", "gold_500", {}))["state"]) == "cancelled", "사용자 취소 → cancelled")
	c3.purchase_mode = "pending"
	var txp: Dictionary = await b3.purchase("gold_500", "gold_500", {})
	_check(str(txp["state"]) == "pending" and (await b3.query_unfinished()).is_empty(), "대기(PENDING) → pending, 미처리 조회에서도 지급 대상 아님")
	c3.owned.clear()
	var codes := {"rc:3": "billing_unavailable", "rc:2": "service_unavailable", "rc:12": "network", "rc:6": "error", "rc:-1": "service_disconnected", "rc:-2": "feature_not_supported", "launch:5": "developer_error", "launch:3": "billing_unavailable"}
	var wrong: Array = []
	for m: String in codes.keys():
		c3.purchase_mode = m
		var te: Dictionary = await b3.purchase("gold_500", "gold_500", {})
		if str(te["state"]) != "failed" or str(te["error"]) != str(codes[m]):
			wrong.append("%s → %s/%s" % [m, te.get("state"), te.get("error")])
	_check(wrong.is_empty(), "오류 코드 → failed + 이름 (%d가지) %s" % [codes.size(), str(wrong)])
	var b3x := BackendGoogle.error_name(99)
	_check(b3x == "error", "모르는 오류 번호 → 'error'")
	c3.purchase_mode = "silent"
	t0 = Time.get_ticks_msec()
	var tt: Dictionary = await b3.purchase("gold_500", "gold_500", {})
	_check(str(tt["state"]) == "failed" and str(tt["error"]) == "timeout" and Time.get_ticks_msec() - t0 < 3000, "결제 창 응답이 없으면 제한 시간 뒤 failed timeout (뒤에서 끝난 결제는 restore 가 찾음)")
	c3.purchase_mode = "owned"
	var ow: Dictionary = c3.make_purchase("gold_500", 1)
	c3.owned = [ow]
	var txo: Dictionary = await b3.purchase("gold_500", "gold_500", {})
	_check(str(txo["state"]) == "purchased" and txo["receipt"] == ow["purchase_token"], "이미 소유(ITEM_ALREADY_OWNED): 소모하지 않은 그 구매를 찾아 돌려줌 (산 돈이 사라지지 않음)")
	c3.owned.clear()
	var txo2: Dictionary = await b3.purchase("gold_500", "gold_500", {})
	_check(str(txo2["state"]) == "failed" and str(txo2["error"]) == "already_owned", "이미 소유인데 찾을 구매가 없으면 failed already_owned")
	# 미처리 조회 · 소모
	c3.purchase_mode = "success"
	c3.owned = [c3.make_purchase("gold_500", 1), c3.make_purchase("gold_1200", 2), c3.make_purchase("gold_unknown", 1), c3.make_purchase("gold_3000", 1)]
	var un: Array = await b3.query_unfinished()
	var ids: Array = []
	for u: Dictionary in un:
		ids.append(u["spid"])
	_check(ids == ["gold_500", "gold_3000"], "미처리: PURCHASED 만 · PENDING 과 모르는 상품은 건너뜀 %s" % str(ids))
	var tk := str(c3.owned[0]["purchase_token"])
	_check(await b3.finish(un[0]) and not (c3.owned as Array).any(func(o: Dictionary) -> bool: return o["purchase_token"] == tk), "finish = consume_purchase → 소유 목록에서 사라짐")
	c3.consume_mode = "not_owned"
	_check(await b3.finish(un[1]), "이미 소모됨(ITEM_NOT_OWNED)도 성공으로")
	c3.consume_mode = "error"
	_check(not await b3.finish(un[1]), "소모 오류 → false (다음 restore 때 다시)")
	c3.consume_mode = "silent"
	t0 = Time.get_ticks_msec()
	_check(not await b3.finish(un[1]) and Time.get_ticks_msec() - t0 < 2500, "소모 무응답 → 제한 시간 뒤 false")
	_check(not await b3.finish({"receipt": ""}), "영수증 없는 거래는 finish 안 함")
	c3.consume_mode = "ok"
	# 직렬화: 동시에 조회 두 번 → 각자 자기 답
	c3.owned = [c3.make_purchase("gold_500", 1)]
	var r1: Array = []
	var r2: Array = []
	var f1 := func() -> void: r1.append_array(await b3.query_unfinished())
	var f2 := func() -> void: r2.append_array(await b3.query_unfinished())
	f1.call()
	f2.call()
	await _until(func() -> bool: return r1.size() == 1 and r2.size() == 1, 3.0)
	_check(r1.size() == 1 and r2.size() == 1 and int(c3.calls["query_purchases"]) >= 2, "동시에 미처리 조회 두 번 → 둘 다 정상 (요청 번호가 없는 신호를 순서대로 처리)")
	# 구매 창 밖의 소식 → unfinished_changed
	var evn := {"n": 0}
	var on_un := func() -> void: evn["n"] += 1
	b3.unfinished_changed.connect(on_un)
	c3.owned = [c3.make_purchase("gold_500", 2)]
	c3.approve_pending()
	await _frames(2)
	_check(int(evn["n"]) == 1, "구매 창 밖에서 승인된 대기 결제 → unfinished_changed 한 번")
	c3.purchase_mode = "success"
	c3.owned.clear()
	var buy_task: Array = []
	var bf := func() -> void: buy_task.append(await b3.purchase("gold_500", "gold_500", {}))
	bf.call()
	await _until(func() -> bool: return not buy_task.is_empty(), 3.0)
	_check(int(evn["n"]) == 1, "구매 창 흐름이 기다리는 결과는 unfinished_changed 를 내지 않음")
	b3.unfinished_changed.disconnect(on_un)
	b3.queue_free()
	await _t_google_flow()
	await _t_google_guarded()


func _t_google_flow() -> void:
	# 정상 구매 전체 순서
	_fresh(1000.0)
	var s: Array = _inject_google()
	var be: Node = s[0]
	var cl: Node = s[1]
	var srv: RefCounted = s[2]
	await _frames(4)
	billing.refresh_products()
	await _until(func() -> bool: return billing.products()[0]["price"] == "₩1,200", 3.0)
	var pr: Array = billing.products()
	_check(billing.is_supported() and billing.is_available() and pr[0]["price"] == "₩1,200" and pr[3]["price"] == "₩12,000", "Billing 이 Google 백엔드로: 가격 글 반영 (₩1,200 … ₩12,000)")
	var r: Dictionary = await _buy_wait("gold_500")
	var iid := _iid()
	var order := _orders()
	var oid := str(order.keys()[0]).substr("google:".length()) if not order.is_empty() else ""
	var vb: Dictionary = srv.verify_calls[0]["body"] if not srv.verify_calls.is_empty() else {}
	_check(str(r.get("status")) == "granted" and _gold() == 1500.0 and order.size() == 1 and str(order["google:" + oid]["st"]) == "done", "구매 성공: 지급 +500 · 기록 done")
	_check(vb.get("store") == "google" and vb.get("product_id") == "gold_500" and vb.get("store_product_id") == "gold_500" and vb.get("order_id") == oid and vb.get("receipt") == cl.last_consumed[0] and vb.get("env") == "dev",
		"서버 verify 요청: store·상품·order_id·receipt = purchaseToken · env")
	_check(srv.verify_calls[0]["iid"] == iid and cl.obfuscated == BillingT.account_token(iid), "설치 식별자 헤더 · obfuscatedAccountId = SHA-256(iid) 앞 32자 (api.md 3.6)")
	_check(cl.last_consumed.size() == 1 and cl.owned.is_empty() and srv.consume_calls.size() == 1 and srv.consume_calls[0].get("store") == "google" and srv.consume_calls[0].get("order_id") == oid, "서버 consume 1번 · Google consume 1번 · 소유 목록 비어 있음")
	_check(_disk_orders().has("google:" + oid) and str(_disk_orders()["google:" + oid]["st"]) == "done", "기록이 디스크에도 (consume 은 디스크 확정 뒤)")
	# 취소
	_fresh(1000.0)
	cl.purchase_mode = "cancel"
	srv.verify_calls.clear()
	var rc: Dictionary = await _buy_wait("gold_500")
	_check(str(rc.get("status")) == "cancelled" and _gold() == 1000.0 and srv.verify_calls.is_empty() and not billing.busy(), "취소: 지급 없음 · 서버 호출 없음 · 진행 중 해제")
	# 오류
	cl.purchase_mode = "rc:3"
	var re: Dictionary = await _buy_wait("gold_500")
	_check(str(re.get("status")) == "failed" and str(re.get("code")) == "billing_unavailable" and _gold() == 1000.0, "가게 오류 → failed + 코드 (지급 없음)")
	# 대기 → 승인
	cl.purchase_mode = "pending"
	var rp: Dictionary = await _buy_wait("gold_500")
	_check(str(rp.get("status")) == "pending" and _gold() == 1000.0 and srv.verify_calls.is_empty() and cl.owned.size() == 1, "대기: 지급·서버 호출 없음, 가게에는 대기 구매가 남음")
	var gev := {"n": 0, "gold": 0.0}
	var on_gr := func(_id: String, g: float, _o: String) -> void:
		gev["n"] += 1
		gev["gold"] = g
	billing.granted.connect(on_gr)
	cl.approve_pending()   # 승인 → on_purchase_updated → unfinished_changed → Billing.restore
	await _until(func() -> bool: return int(gev["n"]) == 1, 5.0)
	await _settle()
	_check(int(gev["n"]) == 1 and float(gev["gold"]) == 500.0 and _gold() == 1500.0 and cl.owned.is_empty() and (_orders().values()[0] as Dictionary)["st"] == "done", "대기가 승인되면 저절로 지급 +500 (한 번) → consume → done")
	billing.granted.disconnect(on_gr)
	# 이미 소유 복구
	_fresh(1000.0)
	srv.verify_calls.clear()
	srv.consumed.clear()
	var owned_p: Dictionary = cl.make_purchase("gold_1200", 1)
	cl.owned = [owned_p]
	cl.purchase_mode = "owned"
	var ro: Dictionary = await _buy_wait("gold_1200")
	_check(str(ro.get("status")) == "granted" and _gold() == 2200.0 and cl.owned.is_empty() and srv.verify_calls.size() == 1, "이미 소유: 앞서 못 받은 구매를 지급 (+1200 한 번) 하고 소모")
	cl.purchase_mode = "success"
	# 앱이 죽었다 다시 켜짐 ① 구매됨 → 지급 전에 죽음: 다음 실행의 restore
	_fresh(1000.0)
	srv.verify_calls.clear()
	srv.consume_calls.clear()
	srv.consumed.clear()
	cl.owned = [cl.make_purchase("gold_500", 1, "GPA.1111-2222-3333-44444")]
	billing.restore()
	await _settle()
	_check(_gold() == 1500.0 and cl.owned.is_empty() and str(_orders()["google:GPA.1111-2222-3333-44444"]["st"]) == "done" and srv.verify_calls.size() == 1, "죽음①(지급 전): 다음 실행 restore → 지급 +500 · 소모 · done")
	billing.restore()
	await _settle()
	_check(_gold() == 1500.0 and srv.verify_calls.size() == 1, "restore 를 또 불러도 중복 지급 0, 서버도 다시 묻지 않음")
	# ② 지급·저장 뒤 consume 전에 죽음: 기록은 granted, 가게에는 소유가 남음
	_fresh(1000.0)
	srv.verify_calls.clear()
	srv.consume_calls.clear()
	srv.consumed.clear()
	cl.owned = [cl.make_purchase("gold_500", 1, "GPA.5555-6666-7777-88888")]
	IapRules.grant(_ctx(), "google", "GPA.5555-6666-7777-88888", "gold_500", Time.get_unix_time_from_system() * 1000.0)
	store.call("flush")
	_check(_gold() == 1500.0 and str(_orders()["google:GPA.5555-6666-7777-88888"]["st"]) == "granted", "(준비) 지급·저장은 됐고 consume 전")
	billing.restore()
	await _settle()
	_check(_gold() == 1500.0 and cl.owned.is_empty() and str(_orders()["google:GPA.5555-6666-7777-88888"]["st"]) == "done" and srv.verify_calls.is_empty() and srv.consume_calls.size() == 1,
		"죽음②(지급 뒤): 골드는 그대로 1500 · 서버 verify 없이 consume 만 다시 · 소모 · done")
	# 서버 5xx · 429 → 지급 없이 미처리로, 나중에 처리
	for sc: Array in [[503, "store_unavailable"], [500, "internal"], [429, "rate_limited"]]:
		_fresh(1000.0)
		srv.verify_calls.clear()
		srv.consume_calls.clear()
		srv.consumed.clear()
		srv.verify_script = [{"status": sc[0], "code": sc[1]}]
		var rv: Dictionary = await _buy_wait("gold_500")
		_check(str(rv.get("status")) == "verify_failed" and _gold() == 1000.0 and _orders().is_empty() and cl.owned.size() == 1 and srv.consume_calls.is_empty(),
			"서버 %d %s: 지급·consume 없음, 가게에 미처리로 남음 (status verify_failed)" % [sc[0], sc[1]])
		billing.restore()
		await _settle()
		_check(_gold() == 1500.0 and cl.owned.is_empty() and _orders().size() == 1, "  → 다음 restore 에서 지급 +500 (한 번)")
	# 서버가 거절
	_fresh(1000.0)
	cl.owned.clear()
	srv.verify_calls.clear()
	srv.consume_calls.clear()
	srv.verify_script = [{"status": 422, "code": "invalid_receipt"}]
	var rin: Dictionary = await _buy_wait("gold_500")
	_check(str(rin.get("status")) == "invalid" and str(rin.get("code")) == "invalid_receipt" and _gold() == 1000.0 and srv.consume_calls.is_empty() and _orders().is_empty(), "서버가 거절(invalid_receipt): 지급·consume 없음")
	cl.owned.clear()
	# 서버가 이미 소모했다고 함
	_fresh(1000.0)
	srv.verify_calls.clear()
	srv.consume_calls.clear()
	srv.verify_script = [{"status": 200, "st": "consumed"}]
	var rcn: Dictionary = await _buy_wait("gold_500")
	_check(str(rcn.get("status")) == "dup" and _gold() == 1000.0 and cl.owned.is_empty(), "서버가 이미 consumed: 지급 없이 가게 소모만 (dup)")
	# 가게 소모 실패 → 기록 granted, 다음 restore 에서 소모만
	_fresh(1000.0)
	srv.verify_calls.clear()
	srv.consume_calls.clear()
	srv.consumed.clear()
	cl.consume_mode = "error"
	var rcf: Dictionary = await _buy_wait("gold_500")
	_check(str(rcf.get("status")) == "granted" and _gold() == 1500.0 and cl.owned.size() == 1 and str((_orders().values()[0] as Dictionary)["st"]) == "granted", "Google 소모 실패: 지급은 됨 · 기록 granted · 소유 남음")
	cl.consume_mode = "ok"
	billing.restore()
	await _settle()
	_check(_gold() == 1500.0 and cl.owned.is_empty() and str((_orders().values()[0] as Dictionary)["st"]) == "done", "다음 restore: 골드는 그대로, 소모만 다시 → done")
	# 서버 consume 실패
	_fresh(1000.0)
	srv.consume_script = [{"status": 503, "code": "internal"}]
	srv.consumed.clear()
	var rsc: Dictionary = await _buy_wait("gold_500")
	_check(str(rsc.get("status")) == "granted" and _gold() == 1500.0 and str((_orders().values()[0] as Dictionary)["st"]) == "granted", "서버 consume 실패: 지급은 됨 · 기록 granted")
	billing.restore()
	await _settle()
	_check(_gold() == 1500.0 and str((_orders().values()[0] as Dictionary)["st"]) == "done" and cl.owned.is_empty(), "다음 restore: 서버 consume 다시 → done (골드 한 번)")
	# 저장 실패(디스크에 안 써짐 — 시험 훅): 지급은 메모리에만 → Google consume·서버 consume 안 함, 복구되면 저장 뒤에 소모 (지급 한 번)
	_fresh(1000.0)
	srv.verify_calls.clear()
	srv.consume_calls.clear()
	srv.consumed.clear()
	cl.owned.clear()
	cl.last_consumed.clear()
	store.set("debug_fake_write_ok", true)
	var rsf: Dictionary = await _buy_wait("gold_500")
	_check(str(rsf.get("status")) == "save_failed" and cl.last_consumed.is_empty() and srv.consume_calls.is_empty() and cl.owned.size() == 1 and _disk_orders().is_empty(),
		"저장 실패(save_failed): 디스크에 기록이 없으면 서버 consume·Google consume 모두 안 함 (가게에 미처리로 남음)")
	billing.restore()
	await _settle()
	_check(cl.last_consumed.is_empty() and srv.consume_calls.is_empty() and cl.owned.size() == 1, "여전히 못 쓰면 restore 도 소모하지 않음")
	store.set("debug_fake_write_ok", false)
	billing.restore()
	await _settle()
	_check(_gold() == 1500.0 and cl.owned.is_empty() and _disk_orders().size() == 1 and str((_disk_orders().values()[0] as Dictionary)["st"]) == "done" and srv.consume_calls.size() == 1 and int(billing.stats["grants"]) == 1,
		"디스크가 돌아오면 저장 → 그 뒤에 소모 → done (지급 1번, 골드 1500)")
	# 전투 중 미룸
	_fresh(1000.0)
	srv.verify_calls.clear()
	srv.consumed.clear()
	var fake_battle := Node.new()
	fake_battle.add_to_group("battle_scene")
	root.add_child(fake_battle)
	var rb: Dictionary = await _buy_wait("gold_500")
	_check(str(rb.get("status")) == "deferred" and _gold() == 1000.0 and cl.owned.size() == 1 and _orders().is_empty(), "전투 중 구매: 서버 확인은 하되 지급 미룸 (가게에 미처리로 남음)")
	fake_battle.queue_free()
	await _frames(3)
	billing.restore()
	await _settle()
	_check(_gold() == 1500.0 and cl.owned.is_empty() and _orders().size() == 1, "전투가 끝나면 restore 가 지급 +500 (한 번)")
	billing.set("_want_check", false)
	_stat("google.billing_stats", billing.stats.duplicate())
	platform.call("override_store", "dev")
	billing.set("_store_name", "")
	billing.set("backend", null)
	billing.call("_ensure_backend")
	billing.verifier.net_down = false


func _t_google_guarded() -> void:
	# 같은 상품 연타: 두 번째는 거절
	_fresh(1000.0)
	var s: Array = _inject_google()
	var cl: Node = s[1]
	await _frames(4)
	var a: bool = billing.buy("gold_500")
	var b: bool = billing.buy("gold_500")
	_check(a and not b, "같은 프레임 buy 두 번 → 두 번째 거절")
	await _until(func() -> bool: return not billing.busy(), 6.0)
	await _settle()
	_check(_gold() == 1500.0 and cl.calls.get("purchase", 0) == 1, "연타해도 결제 창 한 번 · +500 한 번")
	# 연결이 안 되는 기기: 결제 카드는 꺼짐, 오류 없음
	_fresh(1000.0)
	platform.call("override_store", "google")
	var pair := _google()
	pair[1].connect_mode = "error"
	billing.inject_backend(pair[0], "dev")
	await _frames(5)
	_check(billing.is_supported() and not billing.is_available() and not billing.buy("gold_500"), "구글 플레이 연결 실패: 결제 길은 있으나 사용 불가 (buy 거절, 앱은 정상)")
	billing.restore()
	await _settle()
	billing.refresh_products()
	await _frames(4)
	_check(_gold() == 1000.0, "연결 실패 중 restore·refresh 도 조용히")
	platform.call("override_store", "dev")
	billing.set("_store_name", "")
	billing.set("backend", null)
	billing.call("_ensure_backend")


# ═══════════ 3) App Store ═══════════

const SPID_PREFIX := "xyz.show4you.deadline15."


func _apple() -> Array:
	var ia: Node = FakeApple.new()
	ia.catalog = {SPID_PREFIX + "gold_500": "₩1,200", SPID_PREFIX + "gold_1200": "₩2,500", SPID_PREFIX + "gold_3000": "₩6,500", SPID_PREFIX + "gold_6500": "₩12,000"}
	var be: Node = BackendApple.new()
	be.iap = ia
	be.timeouts = {"connect": 0.4, "query": 0.4, "finish": 0.4, "purchase": 0.8}
	return [be, ia]


func _inject_apple() -> Array:
	platform.call("override_store", "apple")
	var pair := _apple()
	billing.inject_backend(pair[0], "dev")
	var srv: RefCounted = FakeStoreServer.new(IapRules.products(_ctx()))
	billing.verifier.fake = srv
	return [pair[0], pair[1], srv]


func _t_apple() -> void:
	var prods := IapRules.products(_ctx())
	var none: Node = BackendApple.new()
	root.add_child(none)
	await _frames(2)
	var tx0: Dictionary = await none.purchase("gold_500", SPID_PREFIX + "gold_500", {})
	_check(not none.is_supported() and not none.is_available() and (await none.query_products(prods)).is_empty() and (await none.query_unfinished()).is_empty()
		and str(tx0.get("error")) == "unavailable" and not (await none.finish({"raw": {"a": 1}})) and not AppleIap.available(), "어댑터 없음(PC): is_supported·is_available 거짓, 모든 호출이 오류 없이 빈 결과")
	none.queue_free()
	# 어댑터 규칙 (순수)
	_check(AppleIap.is_jws("a.b.c") and not AppleIap.is_jws("a.b") and not AppleIap.is_jws("1234567") and not AppleIap.is_jws("a..c") and not AppleIap.is_jws(""), "JWS 모양: 점 2개 · 빈 부분 없음 (플러그인이 JWS 없을 때 transactionId 로 채우는 경우를 걸러냄)")
	var pd := AppleIap.to_p({"id": "7", "transactionId": "7", "productId": "x", "purchaseToken": FakeApple.JWS, "purchaseState": "purchased"})
	_check(pd["transaction_id"] == "7" and pd["jws"] == FakeApple.JWS and pd["state"] == "purchased" and pd["revoked"] == false, "플러그인 구매 사전 → 어댑터 모양")
	_check(AppleIap.to_p({"transactionId": "7", "productId": "x", "purchaseToken": "7", "purchaseState": "pending"}) ["jws"] == "" and AppleIap.to_p({"transactionId": "7", "productId": "x", "purchaseState": 0})["state"] == "pending", "JWS 아니면 jws 비움 · pending 은 문자열·숫자 모두")
	_check(AppleIap.to_p({"transactionId": "7", "productId": "x", "revocationDateIOS": 1791936000000.0})["revoked"] == true and AppleIap.to_p({"transactionId": "7", "productId": "x", "revocationDateIOS": null})["revoked"] == false, "환불·철회(revocationDate) 표시")
	_check(AppleIap.norm_code("user-cancelled") == "usercancelled" and AppleIap.norm_code("USER_CANCELLED") == "usercancelled" and AppleIap.norm_code("UserCancelled") == "usercancelled" and AppleIap.norm_code("deferred-payment") == "deferredpayment", "오류 이름 정규화 (user-cancelled · USER_CANCELLED · UserCancelled)")
	# 백엔드 단독
	var p := _apple()
	var be: Node = p[0]
	var ia: Node = p[1]
	root.add_child(be)
	await _frames(4)
	be.set_products(prods)
	_check(be.is_supported() and be.is_available() and int(ia.calls.get("init_connection", 0)) == 1, "연결 성공 → 사용 가능")
	var rows: Array = await be.query_products(prods)
	_check(rows.size() == 4 and rows[0]["pid"] == "gold_500" and rows[0]["price"] == "₩1,200", "가격: displayPrice")
	var tx: Dictionary = await be.purchase("gold_500", SPID_PREFIX + "gold_500", {"account_uuid": "11111111-2222-3333-4444-555555555555"})
	_check(str(tx["state"]) == "purchased" and tx["store"] == "apple" and tx["spid"] == SPID_PREFIX + "gold_500" and str(tx["order_id"]).begins_with("2000") and tx["receipt"] == FakeApple.JWS and (tx["raw"] as Dictionary).has("transactionId")
		and ia.last_uuid == "11111111-2222-3333-4444-555555555555", "구매 성공: order_id = transactionId · receipt = JWS · appAccountToken(UUID) 전달 · 원본 거래 보관")
	ia.purchase_mode = "cancel"
	_check(str((await be.purchase("gold_500", SPID_PREFIX + "gold_500", {}))["state"]) == "cancelled", "취소 → cancelled")
	ia.purchase_mode = "deferred"
	_check(str((await be.purchase("gold_500", SPID_PREFIX + "gold_500", {}))["state"]) == "pending", "Ask to Buy(deferred-payment) → pending")
	ia.purchase_mode = "pending_state"
	_check(str((await be.purchase("gold_500", SPID_PREFIX + "gold_500", {}))["state"]) == "pending", "구매 신호가 pending 상태여도 → pending")
	ia.unfinished.clear()
	ia.purchase_mode = "badjws"
	var tb: Dictionary = await be.purchase("gold_500", SPID_PREFIX + "gold_500", {})
	_check(str(tb["state"]) == "failed" and str(tb["error"]) == "no_receipt", "JWS 가 없는/틀린 거래 → failed no_receipt (지급 길로 보내지 않음)")
	_check((await be.query_unfinished()).is_empty(), "  … 미처리 조회에서도 같은 거래는 지급 대상이 아님")
	ia.unfinished.clear()
	var codes := {"error:networkerror": "network", "error:itemunavailable": "item_unavailable", "error:servicederror": "servicederror", "error:": "error"}
	var wrong: Array = []
	for m: String in codes.keys():
		ia.purchase_mode = m
		var te: Dictionary = await be.purchase("gold_500", SPID_PREFIX + "gold_500", {})
		if str(te["state"]) != "failed" or str(te["error"]) != str(codes[m]):
			wrong.append("%s → %s/%s" % [m, te.get("state"), te.get("error")])
	_check(wrong.is_empty(), "오류 이름 → failed + 코드 %s" % str(wrong))
	ia.purchase_mode = "silent"
	var t0 := Time.get_ticks_msec()
	var tt: Dictionary = await be.purchase("gold_500", SPID_PREFIX + "gold_500", {})
	_check(str(tt["error"]) == "timeout" and Time.get_ticks_msec() - t0 < 3000, "결제 응답 무응답 → 제한 시간 뒤 timeout")
	ia.purchase_mode = "error:alreadyowned"
	var pend: Dictionary = ia.make_p(SPID_PREFIX + "gold_500")
	ia.unfinished = [pend]
	var ao: Dictionary = await be.purchase("gold_500", SPID_PREFIX + "gold_500", {})
	_check(str(ao["state"]) == "purchased" and ao["order_id"] == pend["transaction_id"], "already-owned: 끝내지 않은 그 거래를 돌려줌")
	ia.unfinished.clear()
	ao = await be.purchase("gold_500", SPID_PREFIX + "gold_500", {})
	_check(str(ao["state"]) == "failed" and str(ao["error"]) == "already_owned", "already-owned 인데 찾을 거래가 없으면 failed")
	# 미처리: 환불된 것은 finish 만, 모르는 상품은 건너뜀
	var rev: Dictionary = ia.make_p(SPID_PREFIX + "gold_1200")
	rev["revoked"] = true
	ia.unfinished = [ia.make_p(SPID_PREFIX + "gold_500"), rev, ia.make_p("other.product")]
	var un: Array = await be.query_unfinished()
	_check(un.size() == 1 and un[0]["spid"] == SPID_PREFIX + "gold_500" and ia.finished_ids.has(str(rev["raw"]["transactionId"])), "미처리: 정상 1개만 · 환불·철회된 거래는 지급하지 않고 finish 로 치움 · 모르는 상품은 건너뜀")
	_check(await be.finish(un[0]), "finish → transaction.finish() (원본 거래 사전 그대로)")
	ia.finish_ok = false
	_check(not await be.finish(un[0]), "finish 실패 시 false")
	ia.finish_ok = true
	_check(not await be.finish({"receipt": FakeApple.JWS}), "원본 거래가 없는 거래는 finish 안 함")
	# 구매 창 밖의 소식
	var evn := {"n": 0}
	var on_un := func() -> void: evn["n"] += 1
	be.unfinished_changed.connect(on_un)
	ia.purchase_updated.emit(ia.make_p(SPID_PREFIX + "gold_500"))
	await _frames(1)
	var rv2: Dictionary = ia.make_p(SPID_PREFIX + "gold_500")
	rv2["revoked"] = true
	ia.purchase_updated.emit(rv2)
	ia.purchase_updated.emit(ia.make_p(SPID_PREFIX + "gold_500", "pending"))
	await _frames(1)
	_check(int(evn["n"]) == 1, "Transaction.updates: 정상 거래만 unfinished_changed (환불·대기는 아님)")
	be.unfinished_changed.disconnect(on_un)
	be.queue_free()
	await _t_apple_flow()


func _t_apple_flow() -> void:
	_fresh(1000.0)
	var s: Array = _inject_apple()
	var ia: Node = s[1]
	var srv: RefCounted = s[2]
	await _frames(4)
	billing.refresh_products()
	await _until(func() -> bool: return billing.products()[0]["price"] == "₩1,200", 3.0)
	_check(billing.is_supported() and billing.is_available() and billing.products()[1]["price"] == "₩2,500", "Billing 이 App Store 백엔드로: 가격 글 반영")
	var r: Dictionary = await _buy_wait("gold_500")
	var iid := _iid()
	var order := _orders()
	var oid := str(order.keys()[0]).substr("apple:".length()) if not order.is_empty() else ""
	var vb: Dictionary = srv.verify_calls[0]["body"] if not srv.verify_calls.is_empty() else {}
	_check(str(r.get("status")) == "granted" and _gold() == 1500.0 and str(order["apple:" + oid]["st"]) == "done" and ia.unfinished.is_empty() and ia.finished_ids == [oid], "구매 성공: 지급 +500 · finish · 기록 done")
	_check(vb.get("store") == "apple" and vb.get("store_product_id") == SPID_PREFIX + "gold_500" and vb.get("product_id") == "gold_500" and vb.get("order_id") == oid and vb.get("receipt") == FakeApple.JWS, "서버 verify 요청: store apple · store_product_id(번들 접두) · order_id = transactionId · receipt = JWS")
	_check(ia.last_uuid == BillingT.account_uuid(iid) and srv.consume_calls.size() == 1, "appAccountToken = Billing.account_uuid(iid) · 서버 consume 1번")
	# 취소 · 대기(Ask to Buy) → 승인
	_fresh(1000.0)
	srv.verify_calls.clear()
	ia.purchase_mode = "cancel"
	var rc: Dictionary = await _buy_wait("gold_500")
	ia.purchase_mode = "deferred"
	var rp: Dictionary = await _buy_wait("gold_500")
	_check(str(rc.get("status")) == "cancelled" and str(rp.get("status")) == "pending" and _gold() == 1000.0 and srv.verify_calls.is_empty(), "취소 · Ask to Buy 대기: 지급·서버 호출 없음")
	var gev := {"n": 0}
	var on_gr := func(_id: String, _g: float, _o: String) -> void: gev["n"] += 1
	billing.granted.connect(on_gr)
	var approved: Dictionary = ia.make_p(SPID_PREFIX + "gold_500")
	ia.unfinished.append(approved)
	ia.purchase_updated.emit(approved)   # 부모가 승인 → Transaction.updates
	await _until(func() -> bool: return int(gev["n"]) == 1, 5.0)
	await _settle()
	_check(int(gev["n"]) == 1 and _gold() == 1500.0 and ia.unfinished.is_empty(), "승인되면 저절로 지급 +500 (한 번) → finish")
	billing.granted.disconnect(on_gr)
	ia.purchase_mode = "success"
	# 앱이 죽었다 다시 켜짐: 끝내지 않은 거래
	_fresh(1000.0)
	srv.verify_calls.clear()
	srv.consume_calls.clear()
	srv.consumed.clear()
	ia.finished_ids.clear()
	var pend: Dictionary = ia.make_p(SPID_PREFIX + "gold_1200")
	ia.unfinished = [pend]
	billing.restore()
	await _settle()
	billing.restore()
	await _settle()
	_check(_gold() == 2200.0 and ia.unfinished.is_empty() and srv.verify_calls.size() == 1, "죽음(지급 전): 다음 실행 restore → +1200 한 번 (restore 두 번이어도)")
	# 지급 뒤 finish 전에 죽음
	_fresh(1000.0)
	srv.verify_calls.clear()
	srv.consume_calls.clear()
	var pend2: Dictionary = ia.make_p(SPID_PREFIX + "gold_500")
	ia.unfinished = [pend2]
	IapRules.grant(_ctx(), "apple", str(pend2["transaction_id"]), "gold_500", Time.get_unix_time_from_system() * 1000.0)
	store.call("flush")
	billing.restore()
	await _settle()
	_check(_gold() == 1500.0 and ia.unfinished.is_empty() and srv.verify_calls.is_empty() and srv.consume_calls.size() == 1, "죽음(지급 뒤): 골드는 그대로 · verify 없이 서버 consume 과 finish 만")
	# finish 실패 → 다음에 finish 만
	_fresh(1000.0)
	srv.consume_calls.clear()
	srv.consumed.clear()
	ia.finish_ok = false
	var rf: Dictionary = await _buy_wait("gold_500")
	_check(str(rf.get("status")) == "granted" and _gold() == 1500.0 and str((_orders().values()[0] as Dictionary)["st"]) == "granted" and ia.unfinished.size() == 1, "finish 실패: 지급은 됨 · 기록 granted · 거래 남음")
	ia.finish_ok = true
	billing.restore()
	await _settle()
	_check(_gold() == 1500.0 and ia.unfinished.is_empty() and str((_orders().values()[0] as Dictionary)["st"]) == "done", "다음 restore: finish 만 다시 → done (골드 한 번)")
	# 서버 5xx → 미처리
	_fresh(1000.0)
	srv.verify_script = [{"status": 503, "code": "store_unavailable"}]
	var rv: Dictionary = await _buy_wait("gold_500")
	_check(str(rv.get("status")) == "verify_failed" and _gold() == 1000.0 and ia.unfinished.size() == 1, "서버 503: 지급 없음, 거래는 끝내지 않음")
	billing.restore()
	await _settle()
	_check(_gold() == 1500.0 and ia.unfinished.is_empty(), "  → 다음 restore 에서 지급")
	# JWS 없는 거래: 끝내지도 지급하지도 않음
	_fresh(1000.0)
	srv.verify_calls.clear()
	ia.finished_ids.clear()
	ia.purchase_mode = "badjws"
	var rj: Dictionary = await _buy_wait("gold_500")
	_check(str(rj.get("status")) == "failed" and str(rj.get("code")) == "no_receipt" and _gold() == 1000.0 and srv.verify_calls.is_empty() and ia.finished_ids.is_empty() and ia.unfinished.size() == 1, "JWS 없음: 지급·서버 호출·finish 모두 없음 (거래는 다음 restore 용으로 남음)")
	ia.unfinished.clear()
	ia.purchase_mode = "success"
	# 진짜 어댑터(래퍼)를 PC 에서 끼워 본 연기 시험: 네이티브가 없어도 오류 없이 실패로 끝남
	_fresh(1000.0)
	platform.call("override_store", "apple")
	var real_be: Node = BackendApple.new()
	var real_ia: Node = AppleIap.new()
	real_be.iap = real_ia
	real_be.timeouts = {"connect": 0.4, "query": 0.4, "finish": 0.4, "purchase": 0.8}
	billing.inject_backend(real_be, "dev")
	await _frames(4)
	var rtx: Dictionary = await real_be.purchase("gold_500", SPID_PREFIX + "gold_500", {"account_uuid": BillingT.account_uuid(_iid())})
	_check(not real_be.is_available() and str(rtx["state"]) == "failed" and str(rtx["error"]) == "unavailable" and (await real_be.query_unfinished()).is_empty() and (await real_ia.fetch_products([SPID_PREFIX + "gold_500"])).is_empty(),
		"진짜 어댑터 + godot-iap 래퍼를 PC 에서: 네이티브 없음 → 연결 실패 → 사용 불가, 오류 없이 빈 결과")
	var perr := {"n": 0}
	real_ia.purchase_error.connect(func(e: Dictionary) -> void: perr["n"] += 1)
	real_be._connected = true   # 연결됐다고 치고 구매 길만 (래퍼가 not-prepared 오류를 신호로 냄)
	var rtx2: Dictionary = await real_be.purchase("gold_500", SPID_PREFIX + "gold_500", {})
	_check(str(rtx2["state"]) == "failed" and int(perr["n"]) == 1 and _gold() == 1000.0, "래퍼의 purchase_error(not-prepared) 신호가 어댑터를 거쳐 failed 로 (%s)" % str(rtx2.get("error")))
	_stat("apple.billing_stats", billing.stats.duplicate())
	platform.call("override_store", "dev")
	billing.set("_store_name", "")
	billing.set("backend", null)
	billing.call("_ensure_backend")


# ═══════════ 4) AdMob 상태 기계 ═══════════

func _ads_setup(b: Node, gold: float = 1000.0) -> void:
	store.call("clear")
	store.call("set_json", "game_save", {"gold": gold, "cleared": [1, 2, 3]})
	store.call("flush")
	platform.call("override_store", "google")
	if ads.bridge != null and ads.bridge != b and is_instance_valid(ads.bridge):
		ads.bridge.queue_free()
	ads.bridge = b
	if b.get_parent() == null:
		ads.add_child(b)
	for k: String in ["_inited", "_starting", "_loading", "_showing", "_privacy", "_privacy_busy"]:
		ads.set(k, false)
	ads.set("_ad", null)
	ads.set("_fails", 0)
	ads.set("state", "off")
	ads.set("load_error", "")
	ads.today_override = TODAY
	ads.retry_base = 0.15
	for k2: String in ads.stats.keys():
		ads.stats[k2] = 0


func _ads_events() -> Dictionary:
	var ev := {"rw": 0, "cl": 0, "fl": [], "gold": 0.0, "av": 0}
	ads.rewarded.connect(func(_p: String, g: float) -> void:
		ev["rw"] += 1
		ev["gold"] = g)
	ads.closed.connect(func(_p: String) -> void: ev["cl"] += 1)
	ads.failed.connect(func(_p: String, c: String) -> void: (ev["fl"] as Array).append(c))
	ads.availability_changed.connect(func() -> void: ev["av"] += 1)
	return ev


func _ads_disconnect_all() -> void:
	for sg: String in ["rewarded", "closed", "failed", "availability_changed", "privacy_changed"]:
		for c: Dictionary in ads.get_signal_connection_list(sg):
			if (c["callable"] as Callable).is_custom():
				ads.disconnect(sg, c["callable"])


func _t_ads() -> void:
	var fb: Node = FakeBridge.new()
	_ads_setup(fb)
	var ev := _ads_events()
	# 플러그인 없는 google/apple (PC·편집기): 광고 없음
	ads.bridge = null
	for st: String in ["google", "apple"]:
		platform.call("override_store", st)
		_check(not ads.is_supported() and not ads.is_available() and ads.status() == "none" and not ads.show_rewarded("x"), "%s + 광고 SDK 없음(PC·편집기) → 광고 없음 (카드 숨김)" % st)
	ads.bridge = fb
	for st2: String in ["stove", "steam"]:
		platform.call("override_store", st2)
		_check(not ads.is_supported() and ads.status() == "none", "%s(PC 가게) → 광고 없음 — 다리가 있어도" % st2)
	platform.call("override_store", "google")
	# 정상: 동의 불필요 → 초기화 → 불러오기 → 준비
	ads.start()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	_check(ads.status() == "ready" and ads.is_available() and fb.calls.get("consent_update", 0) == 1 and fb.calls.get("initialize", 0) == 1 and fb.calls.get("load_rewarded", 0) == 1, "시작 → 동의 정보 갱신 → 초기화 → 불러오기 → ready (각 한 번)")
	_check(fb.init_cfg == {"child_directed": false, "under_age": false, "max_rating": ""}, "SDK 초기화 설정: 아동 대상 아님(false) · 미성년 동의 연령 미만 아님(false) %s" % str(fb.init_cfg))
	_check(fb.units == [AdsT.unit_for(Ctx.globals_from_db(db)["ADMOB"], true, "android")] and fb.units[0] == "ca-app-pub-3940256099942544/5224354917", "광고 단위 = 구글 공개 시험 단위 (안드로이드)")
	platform.call("override_store", "apple")
	_check(ads.ad_unit_id() == "ca-app-pub-3940256099942544/1712485313", "광고 단위 = 구글 공개 시험 단위 (iOS)")
	platform.call("override_store", "google")
	_check(ads.left_today() == 3 and ads.reward_gold() == 100.0 and ads.daily_max() == 3, "하루 3번 × 100 골드")
	# 보상: 끝까지 → earned → 닫음
	fb.show_mode = "earn"
	_check(ads.show_rewarded("shop_gold") and ads.showing() and ads.status() == "showing", "광고 띄우기 → showing")
	_check(not ads.show_rewarded("x") and (ev["fl"] as Array).has("busy"), "떠 있는 동안 또 부르면 busy")
	await _until(func() -> bool: return int(ev["rw"]) == 1, 3.0)
	_check(int(ev["rw"]) == 1 and float(ev["gold"]) == 100.0 and _gold() == 1100.0 and ads.left_today() == 2 and not ads.showing(), "끝까지 보고 닫음 → +100 · 남은 2")
	_check(float((JsonX.parse(str(JsonX.parse(FileAccess.get_file_as_string(ProjectSettings.globalize_path(SAVE))).get("game_save", "{}"))) as Dictionary).get("gold", -1)) == 1100.0, "보상은 보상 획득 때 바로 디스크에 (닫기 전에 앱이 죽어도 안 잃음)")
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	_check(ads.status() == "ready" and fb.calls.get("load_rewarded", 0) == 2 and fb.destroyed == 1, "다 보고 나면 다음 광고를 바로 불러옴 · 쓴 광고는 정리")
	# 닫기(보상 없음)
	fb.show_mode = "close"
	ads.show_rewarded("shop_gold")
	await _until(func() -> bool: return int(ev["cl"]) == 1, 3.0)
	_check(int(ev["cl"]) == 1 and int(ev["rw"]) == 1 and _gold() == 1100.0 and ads.left_today() == 2, "끝까지 안 보고 닫기 → closed · 보상 없음 · 횟수 그대로")
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	# 띄우기 실패
	fb.show_mode = "fail"
	ads.show_rewarded("shop_gold")
	await _until(func() -> bool: return (ev["fl"] as Array).has("show_failed"), 3.0)
	_check((ev["fl"] as Array).has("show_failed") and _gold() == 1100.0 and ads.left_today() == 2 and not ads.showing(), "광고를 띄우다 실패 → failed show_failed · 보상 없음")
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	# 보상 뒤 띄우기 오류: 이미 받은 보상은 알림
	fb.show_mode = "earn_fail_show"
	ads.show_rewarded("shop_gold")
	await _until(func() -> bool: return int(ev["rw"]) == 2, 3.0)
	_check(int(ev["rw"]) == 2 and _gold() == 1200.0 and ads.left_today() == 1, "보상을 받은 뒤 SDK 오류 → 받은 보상은 그대로 알림 (+100)")
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	# 마지막 1회 → 오늘 다 받음
	fb.show_mode = "earn"
	ads.show_rewarded("shop_gold")
	await _until(func() -> bool: return int(ev["rw"]) == 3, 3.0)
	await _frames(3)
	var loads := int(fb.calls.get("load_rewarded", 0))
	await _frames(12)
	_check(_gold() == 1300.0 and ads.left_today() == 0 and ads.status() == "limit" and not ads.is_available() and loads == int(fb.calls.get("load_rewarded", 0)), "3번째 → 남은 0 · status limit · 더 불러오지 않음 (%d)" % loads)
	_check(not ads.show_rewarded("x") and (ev["fl"] as Array).has("limit"), "4번째 → limit")
	# 날짜 바뀜 → 새로 받음, 시계 되돌림은 새 날로 보지 않음
	ads.today_override = "2026-10-20"   # 시계를 하루 되돌림
	_check(ads.left_today() == 0 and ads.status() == "limit", "시계를 하루 되돌려도 오늘 몫은 그대로 0 (시계 조작 방어 유지)")
	ads.today_override = "2026-10-22"
	_check(ads.left_today() == 3, "다음 날 → 3회")
	ads.refresh()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	_check(ads.status() == "ready", "다음 날 refresh → 쉬던 광고 불러오기를 다시 시작")
	ads.today_override = TODAY
	_check(ads.left_today() == 0 and ads.status() == "limit", "다시 오늘로 → 0 (다녀간 날의 횟수를 기억)")
	ads.today_override = "2026-10-22"
	# 수동: 닫기 전에 두 번 earned → 한 번만
	fb.show_mode = "manual"
	_check(ads.show_rewarded("x"), "(수동) 광고 띄움")
	fb.emit_earned()
	fb.emit_earned()
	fb.emit_closed()
	await _frames(2)
	_check(ads.left_today() == 2 and _gold() == 1400.0 and int(ev["rw"]) == 4, "보상 획득 신호가 두 번 와도 한 번만 지급")
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	# 한도에 막힌 뒤 보상 획득 → limit 실패 (동시 접근)
	ads.show_rewarded("x")
	AdRules.grant(_ctx(), "2026-10-22")
	AdRules.grant(_ctx(), "2026-10-22")   # 다른 길로 남은 2번을 다 씀
	var before: float = _gold()
	fb.emit_earned()
	fb.emit_closed()
	await _frames(2)
	_check(_gold() == before and (ev["fl"] as Array).has("limit") and ads.left_today() == 0, "보상 획득 때 이미 한도 → 지급 없이 failed limit")
	fb.show_mode = "earn"
	_ads_disconnect_all()
	# 불러오기 실패: 네트워크(2) → offline, 광고 없음(3) → failed, 재시도
	var fb2: Node = FakeBridge.new()
	_ads_setup(fb2)
	var ev2 := _ads_events()
	fb2.load_results = [{"ok": false, "code": 2}, {"ok": false, "code": 3}, {"ok": true}]
	ads.start()
	await _until(func() -> bool: return ads.status() == "offline", 3.0)
	_check(ads.status() == "offline" and ads.load_error == "load_2" and not ads.is_available(), "불러오기 실패(네트워크 2) → offline")
	await _until(func() -> bool: return ads.status() == "failed", 3.0)
	_check(ads.status() == "failed" and ads.load_error == "load_3", "자동 재시도(지수 백오프) → 이번엔 광고 없음(3) → failed")
	await _until(func() -> bool: return ads.status() == "ready", 5.0)
	_check(ads.status() == "ready" and int(fb2.calls["load_rewarded"]) == 3 and fb2.calls.get("initialize", 0) == 1 and fb2.calls.get("consent_update", 0) == 1, "세 번째에 성공 → ready (초기화·동의는 다시 하지 않음)")
	_ads_disconnect_all()
	# 수동 다시 불러오기 (recover) · 앱 복귀(refresh)
	var fb3: Node = FakeBridge.new()
	_ads_setup(fb3)
	ads.retry_base = 60.0
	fb3.load_results = [{"ok": false, "code": 2}]
	ads.start()
	await _until(func() -> bool: return ads.status() == "offline", 3.0)
	ads.recover()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	_check(ads.status() == "ready", "오프라인 → 카드 단추(recover) → 다시 불러와 ready")
	fb3.load_results = [{"ok": false, "code": 2}]
	ads.set("_ad", null)
	ads.set("state", "idle")
	ads.refresh()
	await _until(func() -> bool: return ads.status() == "offline", 3.0)
	ads.refresh()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	_check(ads.status() == "ready", "앱 복귀/상점 진입(refresh) 도 막힌 불러오기를 다시")
	# 오래된 광고(1시간)는 버리고 새로
	var n0: int = fb3.calls["load_rewarded"]
	ads.set("_ad_ms", Time.get_ticks_msec() - AdsT.AD_MAX_AGE_MS - 1000)
	_check(ads.status() == "loading" and not ads.is_available(), "50분 넘은 광고는 쓰지 않음 (status loading)")
	await _until(func() -> bool: return ads.status() == "ready" and int(fb3.calls["load_rewarded"]) == n0 + 1, 3.0)
	_check(ads.status() == "ready" and int(fb3.calls["load_rewarded"]) == n0 + 1, "  … 새로 불러옴")
	# 초기화 실패
	var fb4: Node = FakeBridge.new()
	_ads_setup(fb4)
	fb4.init_ok = false
	ads.retry_base = 60.0
	ads.start()
	await _until(func() -> bool: return ads.status() == "failed", 3.0)
	_check(ads.status() == "failed" and ads.load_error == "init" and int(fb4.calls.get("load_rewarded", 0)) == 0, "SDK 초기화 실패 → failed (광고 요청은 안 함)")
	fb4.init_ok = true
	ads.recover()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	_check(ads.status() == "ready", "  … 카드 단추로 회복")
	# 동의 (UMP)
	var fb5: Node = FakeBridge.new()
	_ads_setup(fb5)
	fb5.status = "required"
	fb5.form_available = true
	fb5.form_result = "obtained"
	ads.start()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	_check(ads.status() == "ready" and fb5.form_shown == 1 and int(fb5.calls["initialize"]) == 1 and fb5.calls["consent_update"] == 1, "동의 필요(required) → 동의 창 → 동의함 → 그 뒤에 SDK 초기화·광고 (광고는 동의 뒤에만)")
	var fb6: Node = FakeBridge.new()
	_ads_setup(fb6)
	ev = _ads_events()
	fb6.status = "required"
	fb6.form_available = true
	fb6.form_result = ""   # 창을 닫음 (선택 안 함)
	ads.start()
	await _until(func() -> bool: return ads.status() == "consent", 3.0)
	_check(ads.status() == "consent" and fb6.form_shown == 1 and int(fb6.calls.get("initialize", 0)) == 0 and int(fb6.calls.get("load_rewarded", 0)) == 0 and not ads.is_available(), "동의 거부/창 닫음: SDK 초기화·광고 요청 안 함, status consent")
	_check(not ads.show_rewarded("x") and (ev["fl"] as Array).has("unavailable"), "  … 광고 띄우기는 unavailable")
	fb6.form_result = "obtained"
	ads.recover()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	_check(ads.status() == "ready" and fb6.form_shown == 2, "  … 카드 단추(recover) → 동의 창 다시 → 동의하면 광고 불러옴")
	# 동의 정보 갱신 실패 (오프라인) + 이전 동의 상태 없음 → offline, 나중에 회복
	var fb7: Node = FakeBridge.new()
	_ads_setup(fb7)
	ads.retry_base = 60.0
	fb7.consent_ok = false
	fb7.status = "unknown"
	ads.start()
	await _until(func() -> bool: return ads.status() == "offline", 3.0)
	_check(ads.status() == "offline" and int(fb7.calls.get("initialize", 0)) == 0, "동의 정보를 못 받고 상태도 모름(오프라인) → offline, 광고 요청 안 함")
	fb7.consent_ok = true
	fb7.status = "not_required"
	ads.refresh()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	_check(ads.status() == "ready", "  … 연결되면 회복")
	# 동의 갱신은 실패했지만 SDK 가 이전 동의를 기억 (obtained) → 계속
	var fb8: Node = FakeBridge.new()
	_ads_setup(fb8)
	fb8.consent_ok = false
	fb8.status = "obtained"
	ads.start()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	_check(ads.status() == "ready", "갱신은 실패해도 이전에 받은 동의(obtained)가 있으면 계속")
	_check(not fb8.debug_eea_seen, "시험 동의 지역 흉내(--ump-eea) 기본 꺼짐")
	# 개인정보 옵션 입구
	var fb9: Node = FakeBridge.new()
	_ads_setup(fb9)
	fb9.privacy_required = true
	ads.start()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	_check(ads.privacy_entry() and ads.privacy_required(), "UMP 가 개인정보 옵션을 요구하는 지역: 입구 + 요구")
	var nl: int = fb9.calls["load_rewarded"]
	var res: String = await ads.show_privacy_options()
	await _until(func() -> bool: return ads.status() == "ready" and int(fb9.calls["load_rewarded"]) == nl + 1, 3.0)
	_check(res == "shown" and fb9.privacy_shown == 1 and ads.status() == "ready" and int(fb9.calls["load_rewarded"]) == nl + 1, "개인정보 옵션 창 → 끝나면 광고를 새로 준비")
	fb9.privacy_required = false
	ads.set("_privacy", false)
	var res2: String = await ads.show_privacy_options()
	_check(res2 == "not_required" and fb9.privacy_shown == 1 and ads.privacy_entry() and not ads.privacy_required(), "필요 없는 지역: 입구는 있되 창 대신 'not_required' 안내")
	platform.call("override_store", "dev")
	_check(not ads.privacy_entry() and ads.is_supported() and ads.status() == "ready", "dev(가짜 광고)에는 개인정보 입구 없음, 가짜 광고는 늘 ready")
	platform.call("override_store", "google")
	# 동의 지역 흉내(디버그 인자)
	ads.debug_eea = true
	var fb10: Node = FakeBridge.new()
	_ads_setup(fb10)
	ads.start()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	_check(fb10.debug_eea_seen, "-- --ump-eea → 동의 정보 갱신에 EEA 지역 흉내를 넘김")
	ads.debug_eea = false
	# 보상 신호 직후(닫기 전) 디스크 확인 · 표시 감시(SDK 가 닫힘 콜백을 안 줌) · 늦은 콜백 무시
	var fb11: Node = FakeBridge.new()
	_ads_setup(fb11)
	ads.show_timeout = 0.4
	var ev11 := _ads_events()
	ads.start()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	fb11.show_mode = "manual"
	ads.show_rewarded("w")
	var old_cb: Dictionary = fb11._manual.duplicate()
	(old_cb["earned"] as Callable).call()
	var disk_mid := float((JsonX.parse(str(JsonX.parse(FileAccess.get_file_as_string(ProjectSettings.globalize_path(SAVE))).get("game_save", "{}"))) as Dictionary).get("gold", -1))
	var disk_ads: Variant = JsonX.parse(str(JsonX.parse(FileAccess.get_file_as_string(ProjectSettings.globalize_path(SAVE))).get("game_ads", "{}")))
	_check(disk_mid == 1100.0 and disk_ads is Dictionary and int(disk_ads.get("n", 0)) == 1 and ads.showing() and int(ev11["rw"]) == 0,
		"보상 신호 직후(광고를 닫기 전)에 이미 디스크에 골드 +100 · 횟수 1 — 아직 rewarded 신호는 아님 (앱이 여기서 죽어도 보상을 잃지 않음)")
	await _until(func() -> bool: return not ads.showing(), 3.0)
	_check(not ads.showing() and int(ev11["rw"]) == 1 and float(ev11["gold"]) == 100.0 and _gold() == 1100.0, "SDK 가 닫힘 콜백을 안 줘도 감시가 풀어 줌 — 받은 보상은 한 번 알림")
	(old_cb["closed"] as Callable).call()
	(old_cb["earned"] as Callable).call()
	await _frames(3)
	_check(int(ev11["rw"]) == 1 and _gold() == 1100.0 and ads.left_today() == 2, "풀린 뒤 늦게 오는 닫힘·보상 콜백은 무시 — 보상 중복 지급 없음")
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	_check(ads.status() == "ready" and ads.show_rewarded("w2"), "풀린 뒤 광고를 다시 쓸 수 있음")
	var ev11_fl: int = (ev11["fl"] as Array).size()
	await _until(func() -> bool: return not ads.showing(), 3.0)
	_check((ev11["fl"] as Array).size() == ev11_fl + 1 and (ev11["fl"] as Array).back() == "show_failed" and _gold() == 1100.0 and ads.load_error == "show_timeout",
		"보상 없이 콜백이 영영 없으면 감시가 failed show_failed 로 풂 (보상 없음)")
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	ads.show_timeout = 90.0
	# 출시 빌드(ADMOB.real 이 비어 있음): 다시 해도 소용없으니 '이용 불가' 안내만
	var fb12: Node = FakeBridge.new()
	_ads_setup(fb12)
	ads.debug_build = false
	ads.start()
	await _until(func() -> bool: return ads.status() == "unconfigured", 3.0)
	var n_load: int = int(fb12.calls.get("load_rewarded", 0))
	ads.recover()
	ads.refresh()
	await _frames(6)
	_check(ads.status() == "unconfigured" and n_load == 0 and int(fb12.calls.get("load_rewarded", 0)) == 0 and not ads.is_available() and ads.load_error == "no_unit", "출시 빌드 + 광고 단위 비어 있음: unconfigured — 광고 요청도 재시도도 하지 않음")
	var shu := await _open_shop("mercenary")
	var ub: Button = shu.find_child("AdBtn", true, false)
	_check(ub != null and ub.disabled and ub.text == i18n.call("t", "gd.ads.preparing") and str(ub.get_meta("ad_status", "")) == "unconfigured" and (shu.find_child("AdStatus", true, false) as Label).text == i18n.call("t", "gd.ads.st_unconfigured")
		and shu.find_child("AdRetry", true, false) == null, "카드: '다시 불러오기' 대신 꺼진 단추 + '지금은 광고를 이용할 수 없습니다' 안내")
	ads.debug_build = true
	# 출시 빌드에서 광고 단위가 비어 있으면 failed (시험 단위로 대신하지 않음)
	_check(AdsT.unit_for(Ctx.globals_from_db(db)["ADMOB"], false, "android") == "", "출시 빌드 + real 비어 있음 → 광고 단위 '' (불러오기 안 함)")
	_ads_disconnect_all()
	_stat("ads.stats", ads.stats.duplicate())
	ads.bridge = null
	ads.set("state", "off")
	platform.call("override_store", "dev")


# ═══════════ 5) 상점 카드 · 설정 단추 ═══════════

func _open_shop(tab: String) -> Node:
	router.call("go", "shop", {"tab": tab})
	await _until(func() -> bool: return _screen_is("ui/shop.gd"), 5.0)
	await _frames(4)
	return current_scene


func _t_ui() -> void:
	var fb: Node = FakeBridge.new()
	_ads_setup(fb)
	ads.fake_secs = 0.15
	fb.load_results = [{"ok": false, "code": 2}, {"ok": false, "code": 2}]   # 상점에 들어갈 때의 자동 재시도(refresh)도 실패
	ads.retry_base = 600.0
	ads.start()
	await _until(func() -> bool: return ads.status() == "offline", 3.0)
	var sh := await _open_shop("mercenary")
	await _until(func() -> bool: return int(fb.calls.get("load_rewarded", 0)) >= 2, 3.0)
	await _frames(3)
	var card: Node = sh.find_child("AdCard", true, false)
	var btn: Button = sh.find_child("AdBtn", true, false)
	_check(card != null and btn != null and btn.name == "AdBtn" and str(btn.get_meta("ad_status", "")) == "offline" and btn.text == i18n.call("t", "gd.ads.retry") and (sh.find_child("AdStatus", true, false) as Label).text == i18n.call("t", "gd.ads.st_offline")
		and (sh.find_child("AdLeft", true, false) as Label).text == i18n.call("t", "gd.ads.left", {"n": 3, "max": 3}), "오프라인: 카드에 '다시 불러오기' 단추 + 오프라인 안내 + 오늘 3/3")
	# 눌러 다시 불러오기 → 준비
	btn.pressed.emit()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	await _frames(3)
	var w: Button = sh.find_child("AdBtn", true, false)
	_check(w != null and str(w.get_meta("ad_status", "")) == "ready" and not w.disabled and w.text == i18n.call("t", "gd.ads.btn", {"gold": 100}) and sh.find_child("AdStatus", true, false) == null,
		"다시 불러오면 카드가 저절로 '광고 보기 (+100G)' 로 (availability_changed)")
	# 광고 보기 → 보상 → 남은 횟수
	(sh.find_child("AdBtn", true, false) as Button).pressed.emit()
	await _until(func() -> bool: return ads.left_today() == 2, 3.0)
	await _frames(4)
	_check(_gold() == 1100.0 and (sh.find_child("AdLeft", true, false) as Label).text == i18n.call("t", "gd.ads.left", {"n": 2, "max": 3}) and sh.gold_lbl.text == "1,100 G", "광고 보기 → +100 · 카드 2/3 · 골드 표시")
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	for i in 2:
		await _until(func() -> bool: return ads.status() == "ready", 3.0)
		ads.show_rewarded("shop_mercenary")
		await _until(func() -> bool: return ads.left_today() == 1 - i, 3.0)
	await _frames(4)
	var nb: Button = sh.find_child("AdBtn", true, false)
	_check(ads.left_today() == 0 and nb.disabled and nb.text == i18n.call("t", "gd.ads.none_left") and str(nb.get_meta("ad_status", "")) == "limit", "한도 소진: 단추 비활성 '오늘은 모두 받음'")
	# 동의 필요
	ads.today_override = "2026-10-25"
	var fc: Node = FakeBridge.new()
	_ads_setup(fc)
	ads.today_override = "2026-10-25"
	fc.status = "required"
	fc.form_available = true
	fc.form_result = ""
	ads.start()
	await _until(func() -> bool: return ads.status() == "consent", 3.0)
	await _frames(3)
	var cb0: Button = sh.find_child("AdBtn", true, false)
	_check(str(cb0.get_meta("ad_status", "")) == "consent" and cb0.text == i18n.call("t", "gd.ads.consent_btn") and (sh.find_child("AdStatus", true, false) as Label).text == i18n.call("t", "gd.ads.st_consent"), "동의 필요: 카드에 '동의하고 광고 보기' 단추 + 안내")
	fc.form_result = "obtained"
	cb0.pressed.emit()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	await _frames(3)
	_check(str((sh.find_child("AdBtn", true, false) as Button).get_meta("ad_status", "")) == "ready" and fc.form_shown == 2, "단추를 누르면 동의 창 → 동의 → 광고 준비")
	# 준비 중
	ads.set("state", "loading")
	ads.availability_changed.emit()
	await _frames(3)
	var lb: Button = sh.find_child("AdBtn", true, false)
	_check(lb.disabled and lb.text == i18n.call("t", "gd.ads.preparing") and (sh.find_child("AdStatus", true, false) as Label).text == i18n.call("t", "gd.ads.st_loading"), "불러오는 중: 단추 비활성 '광고 준비 중' + 안내")
	# 6개 탭 모두 + 하루 합계
	ads.set("state", "ready")
	ads.set("_ad", {"id": 99})
	ads.set("_ad_ms", Time.get_ticks_msec())
	var cards := 0
	for tab: String in ShopRules.TABS:
		sh.switch_tab(tab)
		await _frames(2)
		if sh.find_child("AdCard", true, false) != null:
			cards += 1
	_check(cards == 6, "모바일(google) 6개 탭마다 광고 카드")
	# PC 가게 · 광고 SDK 없음
	for st: String in ["stove", "steam"]:
		platform.call("override_store", st)
		var n := 0
		for tab2: String in ShopRules.TABS:
			sh.switch_tab(tab2)
			await _frames(1)
			if sh.find_child("AdCard", true, false) != null:
				n += 1
		_check(n == 0 and not ads.is_supported(), "%s(PC): 광고 카드 0 (계속 숨김)" % st)
	platform.call("override_store", "google")
	ads.bridge = null
	var n2 := 0
	for tab3: String in ShopRules.TABS:
		sh.switch_tab(tab3)
		await _frames(1)
		if sh.find_child("AdCard", true, false) != null:
			n2 += 1
	_check(n2 == 0, "google 인데 광고 SDK 가 없는 판(PC·편집기): 광고 카드 숨김")
	ads.bridge = fc
	sh.close_all_modals()
	# 설정 화면 '광고 개인정보 설정' — 모바일에서만
	var fs: Node = FakeBridge.new()
	_ads_setup(fs)
	fs.privacy_required = true
	ads.start()
	await _until(func() -> bool: return ads.status() == "ready", 3.0)
	platform.call("emulate_mobile", true, "pixel8")
	await _frames(3)
	router.call("go", "settings")
	await _until(func() -> bool: return _screen_is("ui/settings_screen.gd"), 5.0)
	await _frames(4)
	var ap: Button = current_scene.find_child("AdPrivacy", true, false)
	_check(ap != null and ap.text == i18n.call("t", "gd.settings.ad_privacy"), "모바일(google, 지역이 요구): 설정에 '광고 개인정보 설정' 단추")
	ap.pressed.emit()
	await _until(func() -> bool: return fs.privacy_shown == 1, 3.0)
	await _frames(3)
	_check(fs.privacy_shown == 1, "단추 → UMP 개인정보 옵션 창")
	fs.privacy_required = false
	ads.set("_privacy", false)
	ap.pressed.emit()
	await _frames(4)
	var modal_text := ""
	for lb2: Node in current_scene.find_children("*", "Label", true, false):
		if (lb2 as Label).text == i18n.call("t", "gd.settings.ad_privacy_none"):
			modal_text = (lb2 as Label).text
	_check(fs.privacy_shown == 1 and modal_text != "", "필요 없는 지역: 창 대신 안내 문구")
	current_scene.close_all_modals()
	platform.call("override_store", "dev")
	await _frames(2)
	router.call("go", "settings")
	await _frames(4)
	_check(current_scene.find_child("AdPrivacy", true, false) == null, "dev(가짜 광고)는 모바일이어도 단추 없음")
	platform.call("emulate_mobile", false)
	platform.call("override_store", "google")
	router.call("go", "settings")
	await _frames(4)
	_check(current_scene.find_child("AdPrivacy", true, false) != null, "가게 google 은 모바일 흉내 없이도 모바일 → 단추 있음")
	platform.call("override_store", "stove")
	router.call("go", "settings")
	await _frames(4)
	_check(current_scene.find_child("AdPrivacy", true, false) == null, "PC(stove): 단추 없음")
	platform.call("override_store", "dev")
	_ads_disconnect_all()
	ads.bridge = null
	ads.set("state", "off")
	router.call("go", "lobby")
	await _frames(4)


# ═══════════ 6) 진짜 다리 + 플러그인 mock ═══════════

func _t_bridge() -> void:
	var br: Node = AdmobBridge.new()
	br.time_scale = 0.06
	root.add_child(br)
	_check(not AdmobBridge.present(), "PC·편집기에서 AdMob 싱글턴 없음 (present 거짓)")
	await _frames(2)
	var cu: Dictionary = await br.consent_update(false)
	_check(cu.has("ok") and cu.has("code") and cu.has("message") and not bool(cu["ok"]), "consent_update: 플러그인(mock)에 동의 SDK 가 없어 무응답 → 제한 시간 뒤 {ok:false} (영영 기다리지 않음)")
	_check(br.consent_status() == "unknown" and not br.consent_form_available() and not br.privacy_options_required(), "동의 상태·창·입구 조회는 오류 없이 기본값")
	var sf: Dictionary = await br.show_consent_form()
	_check(not bool(sf["ok"]), "동의 창 불러오기 무응답 → {ok:false}")
	var po: Dictionary = await br.show_privacy_options()
	_check(not bool(po["ok"]), "개인정보 옵션 무응답 → {ok:false}")
	var ok: bool = await br.initialize({"child_directed": false, "under_age": false, "max_rating": ""})
	_check(ok, "initialize: 아동 대상 아님 설정 + MobileAds.initialize (mock 이 응답)")
	var lr: Dictionary = await br.load_rewarded("ca-app-pub-3940256099942544/5224354917")
	_check(lr.has("ok") and lr.has("code"), "load_rewarded: 응답 모양 {ok, ad|code} (ok=%s)" % str(lr.get("ok")))
	if bool(lr.get("ok", false)):
		_check(lr["ad"] is RewardedAd, "불러온 광고는 플러그인 RewardedAd")
		br.destroy(lr["ad"])
	br.destroy(null)
	br.queue_free()


# ═══════════ 7) 내보내기 · 플러그인 파일 · 라이선스 ═══════════

func _t_export() -> void:
	var cf := ConfigFile.new()
	_check(cf.load("res://export_presets.cfg") == OK, "export_presets.cfg 읽기")
	var secs: Array = []
	for sec: String in cf.get_sections():
		if sec.begins_with("preset.") and not sec.ends_with(".options"):
			secs.append(sec)
	var need := ["addons/admob/assets/*", "addons/admob/internal/editor/*", "addons/admob/internal/exporters/*", "addons/admob/internal/mock/*", "addons/admob/android/*", "addons/admob/ios/*", "addons/GodotGooglePlayBilling/bin/*", "third_party/*"]
	var miss: Array = []
	for sec2: String in secs:
		var ex := str(cf.get_value(sec2, "exclude_filter"))
		for n: String in need:
			if not ex.contains(n):
				miss.append("%s: %s" % [cf.get_value(sec2, "name"), n])
		# 런타임에 필요한 것은 빼지 않음 (광고 API 스크립트 · 버전 · 결제 클라이언트 · godot-iap 래퍼)
		for keep: String in ["addons/admob/gdscript", "addons/admob/internal/version", "addons/GodotGooglePlayBilling/BillingClient", "addons/godot-iap"]:
			if ex.contains(keep):
				miss.append("%s: 빼면 안 되는 %s" % [cf.get_value(sec2, "name"), keep])
	_check(secs.size() == 5 and miss.is_empty(), "프리셋 5개 모두 플러그인 편집기 파일·네이티브 바이너리·third_party 를 빼고, 런타임 스크립트는 남김 %s" % str(miss))
	var io := ""
	for sec3: String in secs:
		if str(cf.get_value(sec3, "platform")) == "iOS":
			io = sec3 + ".options"
	var strings: Variant = JsonX.parse(FileAccess.get_file_as_string("res://tools/ios_privacy_strings.json"))
	var langs_ok: bool = strings is Dictionary
	if langs_ok:
		for l: String in ["en", "ko", "ja", "zh-Hans", "zh-Hant", "es"]:
			langs_ok = langs_ok and typeof(strings.get(l)) == TYPE_STRING and str(strings[l]).length() > 20
	_check(langs_ok, "ATT 문구(NSUserTrackingUsageDescription) 6개 언어가 tools/ios_privacy_strings.json 에 있음")
	_check(langs_ok and str(cf.get_value(io, "application/additional_plist_content")).contains("<key>NSUserTrackingUsageDescription</key><string>%s</string>" % str(strings["en"])), "iOS 프리셋 기본 문구(영어) = ios_privacy_strings.json 의 en")
	_check(str(cf.get_value(io, "application/min_ios_version")) == "17.0" and int(cf.get_value(io, "application/targeted_device_family")) == 2 and str(cf.get_value(io, "application/bundle_identifier")) == "xyz.show4you.deadline15" and str(cf.get_value(io, "application/app_store_team_id")) == "",
		"iOS: 최소 17.0 (godot-iap Swift 확장) · iPhone·iPad · 번들 ID xyz.show4you.deadline15 · 팀 ID 비움 (서명 안 함)")
	var ep: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	_check(ep.has("res://addons/GodotGooglePlayBilling/plugin.cfg") and ep.has("res://addons/admob/plugin.cfg") and not ep.has("res://addons/godot-iap/plugin.cfg"), "편집기 플러그인: Google Billing · AdMob 켬, godot-iap 은 안 켬 (자동 로드·안드로이드 aar 안 씀)")
	_check(not FileAccess.file_exists("res://addons/godot-iap/bin/godot_iap.gdextension") and FileAccess.file_exists("res://third_party/godot-iap-ios/bin/godot_iap.gdextension") and FileAccess.file_exists("res://third_party/.gdignore")
		and not ProjectSettings.has_setting("autoload/GodotIapPlugin"), "godot-iap 네이티브는 평소에 프로젝트에 없음 (third_party 에 보관 · iOS 내보낼 때만 복사) — 데스크톱 편집기 오류 방지")
	var lic_ok := true
	for f: String in ["res://addons/GodotGooglePlayBilling/LICENSE", "res://addons/admob/LICENSE", "res://addons/godot-iap/LICENSE", "res://addons/SOURCES.md"]:
		lic_ok = lic_ok and FileAccess.file_exists(f)
	_check(lic_ok, "플러그인 3종 LICENSE · 출처 문서 SOURCES.md")
	var src := FileAccess.get_file_as_string("res://addons/SOURCES.md")
	_check(src.contains("20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568") and src.contains("8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f") and src.contains("3d94f9d6daae82e9479690a8c4da955714d436c1e6dce4854b82dd925ed1ab9a"), "SOURCES.md 에 받은 압축 3종의 sha256")
	# 내보낸 pck (있으면)
	var pck := ProjectSettings.globalize_path("res://build/windows/DEADLINE 15.pck")
	if FileAccess.file_exists(pck):
		var lst: Variant = Pc5.pck_paths(pck)
		var paths: Array = lst if lst is Array else []
		var has := func(needle: String) -> bool:
			for pth: Variant in paths:
				if str(pth).contains(needle):
					return true
			return false
		_check(not paths.is_empty() and bool(has.call("addons/admob/gdscript/src/api/MobileAds")) and bool(has.call("addons/GodotGooglePlayBilling/BillingClient")) and bool(has.call("addons/godot-iap/godot_iap")) and bool(has.call("scripts/core/billing/backend_google")),
			"내보낸 pck 에 런타임 스크립트 (AdMob API · BillingClient · godot-iap 래퍼 · 백엔드)")
		_check(not bool(has.call("addons/admob/assets")) and not bool(has.call("addons/admob/internal/editor")) and not bool(has.call("third_party/")) and not bool(has.call("addons/GodotGooglePlayBilling/bin")) and not bool(has.call("godot_iap.gdextension")) and not bool(has.call("addons/admob/android")),
			"내보낸 pck 에 편집기 파일·네이티브 바이너리·third_party·gdextension 없음")
		_stat("pck.files", paths.size())
	# 라이선스 화면
	for lang: String in LANGS:
		i18n.call("_apply", lang)
		router.call("go", "licenses")
		await _until(func() -> bool: return _screen_is("ui/licenses.gd"), 5.0)
		await _frames(3)
		var sc := current_scene
		var names: Array = []
		for i in 4:
			var row: Node = sc.find_child("MobileMit%d" % i, true, false)
			names.append(row != null)
		var godot_t := sc.find_child("MobileGoogle", true, false)
		var note := false
		for lb0: Node in sc.find_children("*", "Label", true, false):
			if (lb0 as Label).text == i18n.call("t", "gd.licenses.mobile_note"):
				note = true
		if lang == "ko":
			var all_txt := ""
			for lb: Node in sc.find_children("*", "Label", true, false):
				all_txt += (lb as Label).text + "\n"
			_check(names == [true, true, true, true] and godot_t != null and all_txt.contains("Copyright (c) 2020 Godot Engine contributors") and all_txt.contains("Copyright (c) 2020-present Poing Studios") and all_txt.contains("Copyright (c) 2025 hyo.dev")
				and all_txt.contains("Copyright (c) 2020-2024 Miguel de Icaza") and all_txt.contains("© Google LLC") and all_txt.contains("Apache License, Version 2.0"), "라이선스 화면: 플러그인 3종 + SwiftGodot(MIT 본문·저작권) · Google SDK · AndroidX/Kotlin(Apache 2.0)")
		_check(note, "[%s] 라이선스 화면의 모바일 안내 문구" % lang)
	i18n.call("_apply", "ko")
	router.call("go", "lobby")
	await _frames(3)


# ═══════════ 8) 6개 언어 ═══════════

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


func _t_lang() -> void:
	var all: Array = []
	var total := 0
	var states := 0
	var fb: Node = FakeBridge.new()
	_ads_setup(fb)
	ads.set("state", "ready")
	for res: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 576)]:
		root.size = res
		for lang: String in LANGS:
			i18n.call("_apply", lang)
			var tag := "%dx%d %s" % [res.x, res.y, lang]
			ads.today_override = TODAY
			var sh := await _open_shop("mercenary")
			for st: Array in [["ready", {}], ["loading", {}], ["offline", {}], ["failed", {}], ["no_consent", {}], ["unconfigured", {}]]:
				ads.set("_ad", {"id": 1} if st[0] == "ready" else null)
				ads.set("_ad_ms", Time.get_ticks_msec())
				ads.set("state", "failed" if st[0] == "unconfigured" else st[0])
				ads.set("load_error", "no_unit" if st[0] == "unconfigured" else "")
				ads.availability_changed.emit()
				await _frames(3)
				total += _collect(all, "%s 광고 카드 %s" % [tag, st[0]], _audit(sh, lang))
				states += 1
			ads.today_override = "2026-10-30"
			store.call("set_json", "game_ads", {"v": 1, "day": "2026-10-30", "n": 3.0, "seen": {}})
			ads.set("state", "ready")
			ads.availability_changed.emit()
			await _frames(3)
			total += _collect(all, tag + " 광고 카드 한도", _audit(sh, lang))
			store.call("clear")
			store.call("set_json", "game_save", {"gold": 1000.0})
			states += 1
			platform.call("emulate_mobile", true, "pixel8")
			await _frames(2)
			router.call("go", "settings")
			await _until(func() -> bool: return _screen_is("ui/settings_screen.gd"), 5.0)
			await _frames(4)
			var prow: Node = current_scene.find_child("AdPrivacyRow", true, false)
			_check(prow != null, "[%s] 설정에 광고 개인정보 단추 줄" % tag)
			if prow != null:
				total += _collect(all, tag + " 설정(모바일, 광고 개인정보 단추)", _audit(prow, lang))
			states += 1
			platform.call("emulate_mobile", false)
			router.call("go", "licenses")
			await _until(func() -> bool: return _screen_is("ui/licenses.gd"), 5.0)
			await _frames(4)
			var mob: Node = current_scene.find_child("Mobile", true, false)
			if mob != null:
				total += _collect(all, tag + " 라이선스 모바일 구역", _audit(mob, lang))
				states += 1
	var bad := all.slice(0, 15)
	_check(all.is_empty(), "광고 카드 6가지 상태 + 설정 단추 × 6개 언어 × 2크기: 넘침·두부 0 (%d개 글, 화면 %d) %s" % [total, states, str(bad)])
	root.size = Vector2i(1280, 720)
	i18n.call("_apply", "ko")
	_ads_disconnect_all()
	ads.bridge = null
	ads.set("state", "off")
	ads.today_override = ""
	platform.call("override_store", "dev")
	router.call("go", "lobby")
	await _frames(4)


func _collect(all: Array, tag: String, a: Array) -> int:
	for o: String in a[0]:
		all.append("[%s] 넘침 %s" % [tag, o])
	for tf: String in a[1]:
		all.append("[%s] 두부 %s" % [tag, tf])
	return int(a[2])
