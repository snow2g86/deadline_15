extends "res://scripts/core/billing/backend_base.gd"
## Google Play 결제 (6b) — 플러그인 GodotGooglePlayBilling 3.3.0 (addons/GodotGooglePlayBilling, Play Billing Library 9.1.0) 의 BillingClient 를 감쌈.
##
##  흐름 (Billing 의 공통 지급 순서 안에서 이 파일이 하는 일)
##   연결     : start_connection → connected / connect_error. 못 연결하면(구글 플레이가 없는 기기 · 오프라인) is_available 거짓 — 앱은 그대로, 결제 카드만 꺼짐.
##   가격     : query_product_details(INAPP) → formatted_price (현지 통화 글)
##   구매     : set_obfuscated_account_id(SHA-256(iid) 앞 32자 — api.md 3.6) → purchase(상품) → on_purchase_updated
##              PURCHASED → state purchased (order_id = orderId, 없으면 purchaseToken / receipt = purchaseToken)
##              PENDING   → state pending (지급하지 않음 — 승인되면 query_unfinished 에 PURCHASED 로 나타남)
##              USER_CANCELED → cancelled · ITEM_ALREADY_OWNED → 소모하지 않은 그 구매를 찾아 purchased 로 (산 돈이 사라지지 않게) · 그 밖 → failed + 코드
##   미처리   : query_purchases(INAPP) — 소모하지 않은 것 전부 (앱 시작·복귀·상점 진입·구매 창 뒤). PENDING 은 건너뜀
##   끝냄     : consume_purchase(token) (소모형: 소모가 acknowledge 를 겸함. 3일 안에 안 하면 Google 이 자동 환불). 이미 소모됨(ITEM_NOT_OWNED)도 성공
##  지급(골드)은 하지 않음 — Billing 이 서버 확인 → 전투 중이면 미룸 → 지급 → 디스크 확정 뒤에 finish() 를 부름.
##
##  플러그인이 없는 환경(PC · 편집기)에서는 is_supported() 가 거짓이라 Billing 이 결제 카드를 숨기고 아무 오류도 내지 않음.
##  시험은 client 에 BillingClient 와 같은 신호·함수를 가진 가짜를 끼움 (tests/fake_play_client.gd).

const SigWait := preload("res://scripts/core/billing/sig_wait.gd")

const SINGLETON := "GodotGooglePlayBilling"
const CLIENT_SCRIPT := "res://addons/GodotGooglePlayBilling/BillingClient.gd"

## BillingClient.BillingResponseCode (플러그인 enum 과 같은 값 — 플러그인 없이 시험하려고 복사)
const RC_OK := 0
const RC_USER_CANCELED := 1
const RC_SERVICE_UNAVAILABLE := 2
const RC_BILLING_UNAVAILABLE := 3
const RC_ITEM_UNAVAILABLE := 4
const RC_DEVELOPER_ERROR := 5
const RC_ERROR := 6
const RC_ITEM_ALREADY_OWNED := 7
const RC_ITEM_NOT_OWNED := 8
const RC_NETWORK_ERROR := 12
const RC_SERVICE_DISCONNECTED := -1
const RC_FEATURE_NOT_SUPPORTED := -2
const RC_SERVICE_TIMEOUT := -3
## BillingClient.PurchaseState
const PS_PURCHASED := 1
const PS_PENDING := 2
## BillingClient.ProductType.INAPP
const PT_INAPP := 0

## 기다리는 시간 (초) — 시험은 짧게 바꿈. purchase 는 사용자가 결제 창에 머무는 시간
var timeouts: Dictionary = {"connect": 15.0, "query": 20.0, "consume": 20.0, "purchase": 900.0}
## BillingClient (플러그인) 또는 시험이 끼운 가짜. 비어 있으면 _ready 에서 플러그인으로 만듦
var client: Node = null
var last_connect_code := 0

var _connecting := false
var _op_busy := false
var _buying := ""
var _products: Array = []
var _pid_by_spid: Dictionary = {}
var _price: Dictionary = {}   # spid → {price, currency}


func _init() -> void:
	store_name = "google"


func _ready() -> void:
	if client == null and Engine.has_singleton(SINGLETON):
		var scr: Variant = load(CLIENT_SCRIPT)
		if scr is GDScript:
			client = (scr as GDScript).new()
			add_child(client)
	if client != null:
		if client.get_parent() == null:
			add_child(client)   # 시험이 끼운 가짜도 트리 안에서 (신호·타이머)
		_hook()
		_connect_async.call_deferred()


func _hook() -> void:
	if client.has_signal("on_purchase_updated"):
		client.connect("on_purchase_updated", _on_purchase_updated)
	if client.has_signal("disconnected"):
		client.connect("disconnected", _on_disconnected)


## 이 판에 결제 길이 있는가 — 플러그인(싱글턴)이 있을 때만. PC · 편집기에서는 거짓 (카드를 숨김)
func is_supported() -> bool:
	return client != null or Engine.has_singleton(SINGLETON)


func is_available() -> bool:
	return client != null and bool(client.call("is_ready"))


func set_products(products: Array) -> void:
	_products = products
	_pid_by_spid.clear()
	for p: Variant in products:
		if p is Dictionary:
			_pid_by_spid[str(p.get("google", p.get("id", "")))] = str(p.get("id", ""))


func _connect_async() -> void:
	await prepare()


## 연결을 기다림 (이미 연결됐으면 바로). 연결이 진행 중이면 그 결과를 같이 기다림
func prepare() -> bool:
	if client == null:
		return false
	if is_available():
		return true
	if _connecting:
		while _connecting:
			await get_tree().process_frame
		return is_available()
	_connecting = true
	var w: RefCounted = SigWait.arm(self, [client.connected, client.connect_error], float(timeouts["connect"]))
	client.call("start_connection")
	var r: Dictionary = await w.join()
	_connecting = false
	if int(r["i"]) == 1:
		last_connect_code = int((r["args"] as Array)[0])
	elif int(r["i"]) < 0:
		last_connect_code = RC_SERVICE_TIMEOUT
	else:
		last_connect_code = RC_OK
	return int(r["i"]) == 0 and is_available()


func _on_disconnected() -> void:
	# 플러그인이 알아서 다시 연결함 (enableAutoServiceReconnection) — 다음 prepare() 가 is_ready 로 확인
	pass


## 구매 창 흐름이 기다리지 않는 구매 소식 (대기 → 승인 · 프로모션 코드 · 다른 기기) → Billing 이 restore
func _on_purchase_updated(resp: Dictionary) -> void:
	if _buying != "":
		return
	if int(resp.get("response_code", -1)) == RC_OK and not (resp.get("purchases", []) as Array).is_empty():
		unfinished_changed.emit()


func _lock() -> void:
	while _op_busy:
		await get_tree().process_frame
	_op_busy = true


func _unlock() -> void:
	_op_busy = false


# ── 가격 ──

func query_products(products: Array) -> Array:
	set_products(products)
	if not await prepare():
		return []
	var ids := PackedStringArray()
	for spid: String in _pid_by_spid.keys():
		ids.append(spid)
	await _lock()
	var w: RefCounted = SigWait.arm(self, [client.query_product_details_response], float(timeouts["query"]))
	client.call("query_product_details", ids, PT_INAPP)
	var r: Dictionary = await w.join()
	_unlock()
	if int(r["i"]) != 0:
		return []
	var resp: Dictionary = (r["args"] as Array)[0]
	if int(resp.get("response_code", -1)) != RC_OK:
		return []
	var out: Array = []
	for d: Variant in (resp.get("product_details", []) as Array):
		if not (d is Dictionary):
			continue
		var spid := str(d.get("product_id", ""))
		var offers: Variant = d.get("one_time_purchase_offer_details_list")
		if not (offers is Array) or (offers as Array).is_empty() or not ((offers as Array)[0] is Dictionary):
			continue
		var o: Dictionary = (offers as Array)[0]
		var fp := str(o.get("formatted_price", ""))
		if fp == "" or not _pid_by_spid.has(spid):
			continue
		_price[spid] = {"price": fp, "currency": str(o.get("price_currency_code", ""))}
		out.append({"pid": _pid_by_spid[spid], "price": fp, "currency": str(o.get("price_currency_code", ""))})
	return out


# ── 구매 ──

func purchase(pid: String, spid: String, opts: Dictionary) -> Dictionary:
	if client == null or not await prepare():
		return _failed(pid, spid, "unavailable")
	if not _price.has(spid):
		# 플러그인은 가격 조회를 한 상품만 살 수 있음 (조회 없이 구매하면 DEVELOPER_ERROR)
		await query_products(_products)
		if not _price.has(spid):
			return _failed(pid, spid, "item_unavailable")
	if _buying != "":
		return _failed(pid, spid, "busy")
	_buying = spid
	client.call("set_obfuscated_account_id", str(opts.get("account_token", "")))
	var w: RefCounted = SigWait.arm(self, [client.on_purchase_updated], float(timeouts["purchase"]))
	var launch: Variant = client.call("purchase", spid)
	var lrc: int = int((launch as Dictionary).get("response_code", RC_ERROR)) if launch is Dictionary else RC_ERROR
	var tx: Dictionary
	if lrc != RC_OK:
		w.cancel()
		tx = await _from_code(pid, spid, lrc)
	else:
		var r: Dictionary = await w.join()
		if int(r["i"]) != 0:
			tx = _failed(pid, spid, "timeout")   # 결제는 뒤에서 끝났을 수 있음 — 다음 restore 가 찾음
		else:
			tx = await _from_update(pid, spid, (r["args"] as Array)[0])
	_buying = ""
	return tx


func _from_update(pid: String, spid: String, resp: Dictionary) -> Dictionary:
	var rc := int(resp.get("response_code", RC_ERROR))
	if rc != RC_OK:
		return await _from_code(pid, spid, rc)
	for p: Variant in (resp.get("purchases", []) as Array):
		if p is Dictionary and _has_product(p, spid):
			match int(p.get("purchase_state", 0)):
				PS_PURCHASED:
					return _tx("purchased", pid, spid, p)
				PS_PENDING:
					return _tx("pending", pid, spid, p)
				_:
					return _failed(pid, spid, "unspecified_state")
	return _failed(pid, spid, "no_purchase")


func _from_code(pid: String, spid: String, rc: int) -> Dictionary:
	match rc:
		RC_USER_CANCELED:
			return {"state": "cancelled", "store": store_name, "pid": pid}
		RC_ITEM_ALREADY_OWNED:
			# 산 적이 있는데 아직 소모하지 않음 (앞 거래가 미처리) — 그 거래를 돌려주어 지급·소모로 이어지게 함
			for tx: Variant in await query_unfinished():
				if tx is Dictionary and str(tx.get("spid", "")) == spid:
					return tx
			return _failed(pid, spid, "already_owned")
	return _failed(pid, spid, error_name(rc))


static func error_name(rc: int) -> String:
	match rc:
		RC_SERVICE_UNAVAILABLE:
			return "service_unavailable"
		RC_BILLING_UNAVAILABLE:
			return "billing_unavailable"
		RC_ITEM_UNAVAILABLE:
			return "item_unavailable"
		RC_DEVELOPER_ERROR:
			return "developer_error"
		RC_ITEM_ALREADY_OWNED:
			return "already_owned"
		RC_ITEM_NOT_OWNED:
			return "not_owned"
		RC_NETWORK_ERROR:
			return "network"
		RC_SERVICE_DISCONNECTED:
			return "service_disconnected"
		RC_FEATURE_NOT_SUPPORTED:
			return "feature_not_supported"
		RC_SERVICE_TIMEOUT:
			return "timeout"
	return "error"


func _failed(pid: String, spid: String, code: String) -> Dictionary:
	return {"state": "failed", "store": store_name, "pid": pid, "spid": spid, "error": code}


static func _has_product(p: Dictionary, spid: String) -> bool:
	var ids: Variant = p.get("product_ids", [])
	return (ids is Array or ids is PackedStringArray) and ids.has(spid)


func _tx(state: String, pid: String, spid: String, p: Dictionary) -> Dictionary:
	var token := str(p.get("purchase_token", ""))
	var oid := str(p.get("order_id", ""))
	return {"state": state, "store": store_name, "pid": pid, "spid": spid, "order_id": oid if oid != "" else token, "receipt": token}


# ── 미처리 · 끝냄 ──

func query_unfinished() -> Array:
	if client == null or not await prepare():
		return []
	await _lock()
	var w: RefCounted = SigWait.arm(self, [client.query_purchases_response], float(timeouts["query"]))
	client.call("query_purchases", PT_INAPP)
	var r: Dictionary = await w.join()
	_unlock()
	if int(r["i"]) != 0:
		return []
	var resp: Dictionary = (r["args"] as Array)[0]
	if int(resp.get("response_code", -1)) != RC_OK:
		return []
	var out: Array = []
	for p: Variant in (resp.get("purchases", []) as Array):
		if not (p is Dictionary) or int(p.get("purchase_state", 0)) != PS_PURCHASED:
			continue   # 대기(PENDING) 는 승인될 때까지 지급하지 않음
		for spid: String in _pid_by_spid.keys():
			if _has_product(p, spid):
				out.append(_tx("purchased", str(_pid_by_spid[spid]), spid, p))
				break
	return out


func finish(tx: Dictionary) -> bool:
	var token := str(tx.get("receipt", ""))
	if token == "" or client == null or not await prepare():
		return false
	await _lock()
	var accept := func(_i: int, args: Array) -> bool:
		var d: Variant = args[0]
		return not (d is Dictionary) or str(d.get("token", token)) == token
	var w: RefCounted = SigWait.arm(self, [client.consume_purchase_response], float(timeouts["consume"]), accept)
	client.call("consume_purchase", token)
	var r: Dictionary = await w.join()
	_unlock()
	if int(r["i"]) != 0:
		return false
	var rc := int(((r["args"] as Array)[0] as Dictionary).get("response_code", RC_ERROR))
	return rc == RC_OK or rc == RC_ITEM_NOT_OWNED
