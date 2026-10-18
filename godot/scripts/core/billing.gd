extends Node
## Billing — 게임 쪽 공통 결제 층 (결제층 A). 오토로드 이름 Billing (Platform 다음).
##
##  화면이 쓰는 것
##   products()      : [{id, gold, key, price, krw}] — price 는 가게가 준 현지 가격 글(가짜 가게는 ₩1,200), 못 받았으면 data 의 fallback_price
##   buy(id)         : 구매 시작 (이미 진행 중이거나 결제를 쓸 수 없으면 false). 끝나면 purchase_finished(id, result)
##   restore()       : 미처리 거래 다시 처리 + 환불 조회 (앱 시작·앱 복귀·상점 진입 때 저절로도 부름)
##   busy()          : 구매 진행 중
##   is_supported()  : 이 판에 결제 길이 있는가 (없으면 상점 결제 카드를 숨김 — steam · 출시 빌드의 dev)
##   is_available()  : 지금 결제할 수 있는가 (길은 있는데 SDK 가 아직이면 카드는 보이되 꺼짐 — 지금의 stove·google·apple 빈 틀)
##  신호: products_updated · purchase_finished(id, result) · granted(id, gold, order_id) · revoked(id, gold_taken, order_id) · busy_changed(b)
##   result.status: granted · dup(이미 받은 주문) · cancelled · pending · failed · verify_failed(네트워크 — 나중에 다시) · invalid · deferred(전투 중) · save_failed · busy
##
##  지급 순서 (이 순서를 바꾸지 말 것)
##   1) 백엔드가 'purchased' 를 알림 (구매 직후 · 또는 query_unfinished 로 다시)
##   2) 이미 game_iap 에 있는 주문이면 지급하지 않고 7) 로 (앱이 지급 뒤 finish 전에 죽음 · 가게가 다시 알림)
##   3) 서버 확인 (Verifier) — 'valid' 일 때만 지급. 네트워크 실패면 아무것도 하지 않음(미처리로 남음 → 다음 기회에 다시)
##   4) 전투 중이면 미룸 (battle_scene._write_back 이 전투가 끝날 때 game_save 를 전투 시작 때 값+보상으로 덮어써 골드가 사라지므로).
##      미룬 거래는 가게에 '미처리'로 남아 있으므로 전투가 끝나면 restore 가 다시 처리 (메모리 대기열 없음 — 앱이 죽어도 같음)
##   5) IapRules.grant — 골드와 주문 기록을 같은 Store 에 한 번에
##   6) Store.flush() 가 true 일 때만 다음으로 (디스크에 남기 전에는 가게에 '끝'을 알리지 않음)
##   7) 서버 consume → 백엔드 finish(tx) → 둘 다 되면 기록 st 를 done 으로 (안 되면 granted 로 남아 다음 restore 때 다시)
##  환불: 서버 환불 목록(GET /v1/refunds)에 나온 주문은 IapRules.revoke (골드 0 바닥). 전투 중에는 하지 않음 (같은 덮어쓰기 위험).
##
##  디버그 빌드만: 명령줄 -- --iap <시나리오> (backend_fake.gd 의 SCENARIOS) · -- --iap-env dev|stage|prod. 출시 빌드는 무시하고 가짜 가게를 만들지 않음.

const Ctx := preload("res://scripts/logic/ctx.gd")
const StoreCtx := preload("res://scripts/logic/store_ctx.gd")
const IapRules := preload("res://scripts/logic/iap_rules.gd")
const Verifier := preload("res://scripts/core/billing/verifier.gd")
const BackendNone := preload("res://scripts/core/billing/backend_none.gd")
const BackendFake := preload("res://scripts/core/billing/backend_fake.gd")
const BackendStove := preload("res://scripts/core/billing/backend_stove.gd")
const BackendGoogle := preload("res://scripts/core/billing/backend_google.gd")
const BackendApple := preload("res://scripts/core/billing/backend_apple.gd")

signal products_updated
signal purchase_finished(id: String, result: Dictionary)
signal granted(id: String, gold: float, order_id: String)
signal revoked(id: String, gold_taken: float, order_id: String)
signal busy_changed(b: bool)

## 전투 장면이 들어가는 무리 (battle_scene.gd _ready)
const BATTLE_GROUP := "battle_scene"
## 환불 조회 사이 최소 간격 (ms, force 가 아니면)
const REFUND_GAP_MS := 60000

var backend: Node = null
var verifier: Verifier
var env := "dev"
var scenario := ""
## 시험용 세기
var stats: Dictionary = {"grants": 0, "dups": 0, "deferred": 0, "verify_fail": 0, "revokes": 0, "finished": 0}

var _store_name := ""
var _busy := false
var _prices: Dictionary = {}   # pid → 가게 가격 글
var _restoring := false
var _restore_again := false
var _want_check := false       # 전투가 끝나면 restore
var _inflight: Dictionary = {}
var _last_refund_ms := -REFUND_GAP_MS
var _poll_t := 0.0
var _started := false
var _restoring_now := false
## 이번 실행에서 지급한 주문 (order_key → 골드) — 진행 중인 구매를 restore 가 먼저 처리했을 때 '지급 완료'로 알리려고
var _session_granted: Dictionary = {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args() if OS.is_debug_build() else PackedStringArray()
	var i := args.find("--iap")
	if i >= 0 and i + 1 < args.size():
		scenario = args[i + 1]
	env = "dev" if OS.is_debug_build() else "prod"
	var e := args.find("--iap-env")
	if e >= 0 and e + 1 < args.size() and ["dev", "stage", "prod"].has(args[e + 1]):
		env = args[e + 1]
	verifier = Verifier.new()
	verifier.name = "Verifier"
	add_child(verifier)
	get_tree().scene_changed.connect(_on_scene_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _started:
			restore()


## 첫 화면이 뜰 때 한 번 (부트 화면이 --save 로 저장 경로를 바꾼 뒤) + 화면이 바뀔 때마다 미룬 일
func _on_scene_changed() -> void:
	var s: Node = get_tree().current_scene
	var boot := s != null and s.get_script() != null and str((s.get_script() as Script).resource_path).ends_with("ui/boot.gd")
	if boot:
		return
	if not _started:
		_started = true
		restore()
	elif _want_check and not in_battle():
		restore()


func _process(delta: float) -> void:
	if not _want_check:
		return
	_poll_t += delta
	if _poll_t < 0.5:
		return
	_poll_t = 0.0
	if not in_battle():
		restore()


# ── 백엔드 ──

func _ensure_backend() -> void:
	var pf: Node = get_node_or_null("/root/Platform")
	var s := str(pf.call("store")) if pf != null else "dev"
	if s == _store_name and backend != null:
		return
	_store_name = s
	if backend != null:
		backend.queue_free()
	match s:
		"dev":
			backend = BackendFake.new() if OS.is_debug_build() else BackendNone.new("dev")
		"stove":
			backend = BackendStove.new()
		"google":
			backend = BackendGoogle.new()
		"apple":
			backend = BackendApple.new()
		_:
			backend = BackendNone.new(s)   # steam (맨 뒤로 미룸)
	backend.name = "Backend"
	add_child(backend)
	if backend is BackendFake and scenario != "":
		set_scenario(scenario)
	_prices = {}
	var cfgs: Variant = _D().get("IAP_SERVER")
	var cfg: Dictionary = cfgs.get(env, {}) if cfgs is Dictionary else {}
	var ver := str(ProjectSettings.get_setting("application/config/version", "0"))
	verifier.configure(env, cfg, IapRules.products(_ctx()), "deadline15/%s (%s; %s)" % [ver, s, OS.get_name()])


## (디버그) 가짜 가게 시나리오 바꾸기 — 출시 빌드에서는 아무것도 안 함
func set_scenario(s: String) -> bool:
	if not OS.is_debug_build():
		return false
	_ensure_backend()
	if not (backend is BackendFake) or not BackendFake.SCENARIOS.has(s):
		return false
	scenario = s
	(backend as BackendFake).scenario = s
	verifier.net_fail_left = 1 if s == "net_fail" else 0
	return true


func _D() -> Dictionary:
	var db: Node = get_node_or_null("/root/DataDB")
	return Ctx.globals_from_db(db) if db != null else {}


func _ctx() -> Object:
	var c := Ctx.new(_D(), randi() & 0x7fffffff, StoreCtx.new(get_node("/root/Store")))
	c.clock = func() -> float: return Ctx.real_now()
	return c


func store_name() -> String:
	_ensure_backend()
	return _store_name


func is_supported() -> bool:
	_ensure_backend()
	return bool(backend.call("is_supported"))


func is_available() -> bool:
	_ensure_backend()
	return bool(backend.call("is_supported")) and bool(backend.call("is_available"))


func busy() -> bool:
	return _busy


## 전투 중(또는 전투로 들어가는 중)인가 — 셋 중 하나라도 참이면 지급·회수를 미룸 (결제층 A 검수):
##  1) 전투 장면이 battle_scene 무리에 있음
##  2) BattleScene.pending 이 비어 있지 않음 — 출격·이어하기(flow.gd)·다시 하기/다음 스테이지(battle_scene._restart)·개발 실행기가
##     store_save 사본을 만들고 pending 에 넣은 뒤, 장면은 그 프레임 끝에 붙음. 그 사이의 지급은 사본 기준 _write_back 에 덮어써지므로
##  3) Router.current == "battle" (launch_battle 이 바꾼 뒤 장면이 붙기 전 · 결과 화면)
func in_battle() -> bool:
	if get_tree().get_node_count_in_group(BATTLE_GROUP) > 0:
		return true
	var bs: GDScript = load("res://scripts/battle/battle_scene.gd")
	if not (bs.get("pending") as Dictionary).is_empty():
		return true
	var rt: Node = get_node_or_null("/root/Router")
	return rt != null and str(rt.get("current")) == "battle"


## 상품 [{id, gold, key, price, krw}] (data/iap.json 순서)
func products() -> Array:
	_ensure_backend()
	var out: Array = []
	for p: Variant in IapRules.products(_ctx()):
		if not (p is Dictionary):
			continue
		var id := str(p["id"])
		out.append({"id": id, "gold": float(p["gold"]), "key": str(p["label"]), "price": str(_prices.get(id, p.get("fallback_price", ""))), "krw": float(p.get("krw", 0))})
	return out


## 가게 가격 받기 (상점 진입 때)
func refresh_products() -> void:
	_ensure_backend()
	if not is_available():
		return
	var rows: Array = await backend.query_products(IapRules.products(_ctx()))
	for r: Variant in rows:
		if r is Dictionary and str(r.get("price", "")) != "":
			_prices[str(r["pid"])] = str(r["price"])
	products_updated.emit()


## 설치 식별자 (없으면 Crypto 로 16바이트 무작위) — 새로 만들면 바로 디스크에 (서버가 주문을 이 값으로 묶음)
func _iid(c: Object) -> String:
	var had := IapRules.is_iid(IapRules.load_iap(c).get("iid"))
	var iid := IapRules.install_id(c, func() -> String:
		# 세이브에 없으면 바깥 저장소(있으면)의 값을 먼저 — 재설치에도 같은 iid (모바일·STOVE 작업에서 연결)
		var ext: Variant = _iid_load.call() if _iid_load.is_valid() else null
		return str(ext) if IapRules.is_iid(ext) else Crypto.new().generate_random_bytes(16).hex_encode())
	_flush()
	if not had and _iid_save.is_valid():
		_iid_save.call(iid)
	return iid


var _iid_load: Callable = Callable()
var _iid_save: Callable = Callable()


## 확장 지점: iid 를 앱 밖(Android Block Store · iOS Keychain · STOVE 클라우드 세이브)에 두고 읽어 올 때.
##  load_fn: () -> String (없으면 "") · save_fn: (iid: String) -> void. 세이브에 iid 가 없을 때만 load_fn 을 부르고, 새로 정한 iid 는 save_fn 으로 넘김
func set_iid_store(load_fn: Callable, save_fn: Callable) -> void:
	_iid_load = load_fn
	_iid_save = save_fn


## 가게 구매에 넣는 계정 토큰 (Google obfuscatedAccountId · Apple appAccountToken 의 재료) = SHA-256(iid) 앞 32자.
##  재설치하면 바뀌는 값 — 그 경우는 서버의 '24시간 재claim' 규칙으로 복구 (docs/server/api.md 3.2)
static func account_token(iid: String) -> String:
	return iid.sha256_text().substr(0, 32)


func is_restoring() -> bool:
	return _restoring_now


# ── 구매 ──

## 이 상품의 구매가 아직 진행 중인가 (진행 중 창을 닫은 뒤에도 — 그 카드는 '처리 중')
func purchase_pending(id: String) -> bool:
	return _pending_pids.has(id)


## 진행 중 창을 사용자가 닫음: 다른 상품은 살 수 있게 busy 를 풂 (그 구매는 뒤에서 계속, 끝나면 purchase_finished)
func release_busy() -> void:
	if _busy:
		_busy = false
		busy_changed.emit(false)


var _pending_pids: Dictionary = {}


func buy(id: String) -> bool:
	_ensure_backend()
	if _busy or _pending_pids.has(id) or not is_available() or IapRules.product(_ctx(), id) == null:
		return false
	_pending_pids[id] = true
	_busy = true
	busy_changed.emit(true)
	_buy.call_deferred(id)
	return true


func _buy(id: String) -> void:
	var c := _ctx()
	var p: Dictionary = IapRules.product(c, id)
	var tx: Dictionary = await backend.purchase(id, IapRules.store_product_id(p, _store_name), {"account_token": account_token(_iid(c))})
	await _finish_buy(id, tx)


## 가게가 돌려준 거래를 처리하고 결과를 알림 (구매 길)
func _finish_buy(id: String, tx: Dictionary) -> void:
	var r := await _handle(tx)
	# 같은 주문을 restore 가 먼저 지급했으면(이번 실행) 사는 사람에게는 정상 '지급 완료'
	var k := IapRules.order_key(str(tx.get("store", "")), str(tx.get("order_id", "")))
	if ["dup", "busy"].has(str(r.get("status"))) and _session_granted.has(k):
		r = {"status": "granted", "gold": float(_session_granted[k]), "order_id": str(tx.get("order_id", "")), "via": "restore"}
	_pending_pids.erase(id)
	if _busy and _pending_pids.is_empty():
		_busy = false
		busy_changed.emit(false)
	purchase_finished.emit(id, r)
	if r.get("status") == "granted" and scenario == "refund" and backend is BackendFake:
		(backend as BackendFake).refund(str(tx.get("order_id", "")))
		_last_refund_ms = -REFUND_GAP_MS
		restore()


func _handle(tx: Dictionary) -> Dictionary:
	match str(tx.get("state", "")):
		"cancelled":
			return {"status": "cancelled"}
		"pending":
			return {"status": "pending"}
		"purchased":
			pass
		_:
			return {"status": "failed", "code": str(tx.get("error", ""))}
	var k := IapRules.order_key(str(tx.get("store", "")), str(tx.get("order_id", "")))
	if _inflight.has(k):
		# 같은 주문을 다른 길(restore · 구매)이 처리 중 — 끝날 때까지 기다렸다가 결과만 봄 (두 번 처리하지 않음)
		var t0 := Time.get_ticks_msec()
		while _inflight.has(k) and Time.get_ticks_msec() - t0 < 60000:
			await get_tree().process_frame
		return {"status": "busy"}
	_inflight[k] = true
	var r: Dictionary = await _deliver(tx)
	_inflight.erase(k)
	return r


## 기록이 **디스크에** 실제로 있는가 (메모리 값이 아니라 save.json 을 다시 읽음). 이것이 참이기 전에는 서버 consume · 가게 finish 를 하지 않음
func _durable(store: String, oid: String) -> bool:
	if not _flush():
		return false
	if _on_disk(store, oid):
		return true
	# flush 는 성공이라는데 디스크에 없음 (메모리·디스크 어긋남) — 메모리 전체를 한 번 더 써 보고 다시 확인
	get_node("/root/Store").call("touch")
	return _flush() and _on_disk(store, oid)


func _on_disk(store: String, oid: String) -> bool:
	var d: Variant = get_node("/root/Store").call("disk_get_json", IapRules.KEY)
	return d is Dictionary and d.get("orders") is Dictionary and (d["orders"] as Dictionary).has(IapRules.order_key(store, oid))


func _deliver(tx: Dictionary) -> Dictionary:
	var c := _ctx()
	var store := str(tx["store"])
	var oid := str(tx.get("order_id", ""))
	var pid := str(tx.get("pid", ""))
	var have: Variant = IapRules.order(c, store, oid)
	if have != null:
		# 2) 이미 기록된 주문 (지급 뒤 finish 전에 앱이 죽음 · 가게가 다시 알림)
		stats["dups"] += 1
		if str(have.get("st", "")) == "revoked":
			return {"status": "dup", "st": "revoked"}   # 환불·회수한 주문 — 서버·가게에 아무것도 하지 않음
		if not _durable(store, oid):
			return {"status": "save_failed"}
		await _complete(c, tx)
		return {"status": "dup", "st": str(have.get("st", ""))}
	var iid := _iid(c)
	var v: Dictionary = await verifier.verify(tx, iid)
	match str(v.get("status")):
		"error":
			stats["verify_fail"] += 1
			return {"status": "verify_failed", "code": str(v.get("code", ""))}
		"pending":
			return {"status": "pending"}
		"invalid":
			push_warning("Billing: 서버가 거절한 주문 %s (%s) — 지급하지 않음" % [oid, v.get("code")])
			return {"status": "invalid", "code": str(v.get("code", ""))}
		"consumed":
			# 서버는 이미 소모 처리 — 지급 기록이 없는 저장(세이브를 지움 등)이어도 다시 주지 않음
			await backend.finish(tx)
			stats["dups"] += 1
			return {"status": "dup", "st": "consumed"}
	if in_battle():
		# 4) 전투 중(또는 출격 직전 같은 프레임) — 미처리로 남겨 두고 전투가 끝나면 restore
		stats["deferred"] += 1
		_want_check = true
		return {"status": "deferred"}
	if scenario == "crash_before_grant" and OS.is_debug_build():
		_crash("crash_before_grant")
	c = _ctx()
	var g := IapRules.grant(c, store, oid, pid, Ctx.real_now())
	if g.has("err"):
		push_error("Billing: 지급 실패 %s %s" % [oid, g["err"]])
		return {"status": "failed", "code": str(g["err"])}
	if g.get("dup", false):
		return {"status": "dup"}
	stats["grants"] += 1
	_session_granted[IapRules.order_key(store, oid)] = float(g["gold"])
	granted.emit(pid, float(g["gold"]), oid)
	if not _durable(store, oid):
		# 메모리에는 지급됨 — 디스크에 남을 때까지 가게·서버에는 '끝'을 알리지 않음 (다음 restore 가 저장을 다시 시도)
		return {"status": "save_failed"}
	if scenario == "crash_after_grant" and OS.is_debug_build():
		_crash("crash_after_grant")
	await _complete(c, tx)
	return {"status": "granted", "gold": float(g["gold"]), "order_id": oid}


## 7) 서버 consume → 가게 finish → 기록 done. 서버가 order_claimed(다른 설치가 24시간 재claim 으로 다시 가져감)면 이 설치의 지급을 회수
func _complete(c: Object, tx: Dictionary) -> void:
	var store := str(tx["store"])
	var oid := str(tx.get("order_id", ""))
	var sv: Dictionary = await verifier.consume(tx, _iid(c))
	if str(sv.get("code", "")) == "order_claimed":
		_lost_claim(store, oid, str(tx.get("pid", "")))
		return
	var fin := bool(await backend.finish(tx))
	if fin:
		stats["finished"] += 1
	if fin and bool(sv.get("ok", false)):
		if IapRules.mark_done(_ctx(), store, oid):
			_flush()


## 서버가 이 주문의 주인을 다른 설치로 바꿈(24시간 재claim 규칙 — 재설치한 쪽이 받아 감) → 이 설치의 지급을 회수 (한 주문은 한 설치만 갖게)
func _lost_claim(store: String, oid: String, pid: String) -> void:
	if in_battle():
		# 회수도 game_save 를 바꾸므로 전투 중에는 미룸 — 기록은 granted 그대로, 전투 뒤 restore 가 consume 을 다시 해 같은 길로 옴
		_want_check = true
		stats["deferred"] += 1
		return
	var rv := IapRules.revoke(_ctx(), store, oid, Ctx.real_now(), pid)
	if rv.get("ok", false):
		stats["revokes"] += 1
		_flush()
		revoked.emit(pid, float(rv.get("taken", 0)), oid)


func _flush() -> bool:
	return bool(get_node("/root/Store").call("flush"))


func _crash(where: String) -> void:
	printerr("Billing: (가짜) 앱이 여기서 죽음 — " + where)
	OS.kill(OS.get_process_id())


# ── 다시 처리 · 환불 ──

## 미처리 거래 다시 처리 + 지급만 하고 '끝'을 못 알린 주문 마무리 + 환불 조회. force 면 환불 조회 간격 무시
func restore(force_refunds: bool = false) -> void:
	if force_refunds:
		_last_refund_ms = -REFUND_GAP_MS
	if _restoring:
		_restore_again = true
		return
	_restoring = true
	await _restore_once()
	while _restore_again:
		_restore_again = false
		await _restore_once()
	_restoring = false


func _restore_once() -> void:
	_ensure_backend()
	if in_battle():
		_want_check = true
		return
	_want_check = false
	if not bool(backend.call("is_supported")) or not bool(backend.call("is_available")):
		return
	_restoring_now = true
	var txs: Array = await backend.query_unfinished()
	for tx: Variant in txs:
		if tx is Dictionary:
			await _handle(tx)
	# 지급·저장은 했지만 서버 consume 이 안 된 주문 (가게 쪽은 끝남) — 디스크에 있는지 확인한 뒤 consume 만 다시
	var c := _ctx()
	for u: Dictionary in IapRules.unfinished(c):
		if u["store"] != _store_name:
			continue
		var still := false
		for tx2: Variant in txs:
			if tx2 is Dictionary and str(tx2.get("order_id", "")) == u["oid"]:
				still = true
		if still or not _durable(u["store"], u["oid"]):
			continue
		var sv: Dictionary = await verifier.consume({"store": u["store"], "order_id": u["oid"]}, _iid(c))
		if str(sv.get("code", "")) == "order_claimed":
			_lost_claim(u["store"], u["oid"], u["pid"])
		elif bool(sv.get("ok", false)) and IapRules.mark_done(_ctx(), u["store"], u["oid"]):
			_flush()
	await _poll_refunds()
	_restoring_now = false


func _poll_refunds() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_refund_ms < REFUND_GAP_MS:
		return
	var c := _ctx()
	if (IapRules.load_iap(c)["orders"] as Dictionary).is_empty():
		return   # 산 적이 없으면 물어볼 것도 없음 (세이브에 아무것도 쓰지 않음)
	_last_refund_ms = now
	var iid := _iid(c)
	var guard := 0
	while guard < 20:
		guard += 1
		var r: Dictionary = await verifier.refunds(iid, IapRules.refund_cursor(_ctx()))
		if not bool(r.get("ok", false)):
			_last_refund_ms = -REFUND_GAP_MS   # 실패면 다음 기회에 다시
			return
		if in_battle():
			# 응답을 기다리는 사이 전투로 들어감 — 회수도 game_save 를 바꾸므로 미룸 (커서도 그대로)
			_want_check = true
			_last_refund_ms = -REFUND_GAP_MS
			return
		for o: Dictionary in r["orders"]:
			var rv := IapRules.revoke(_ctx(), str(o["store"]), str(o["order_id"]), Ctx.real_now(), str(o.get("product_id", "")))
			if rv.get("ok", false):
				stats["revokes"] += 1
				revoked.emit(str(o.get("product_id", "")), float(rv.get("taken", 0)), str(o["order_id"]))
		IapRules.set_refund_cursor(_ctx(), str(r["cursor"]))
		_flush()
		if not bool(r.get("more", false)):
			return
