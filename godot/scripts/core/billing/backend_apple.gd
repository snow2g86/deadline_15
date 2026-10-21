extends "res://scripts/core/billing/backend_base.gd"
## App Store 결제 (6b) — StoreKit 2. iOS 플러그인 godot-iap 4.0.3 (OpenIAP, MIT) 를 apple_iap.gd(어댑터)로 감쌈. 상품 id 는 xyz.show4you.deadline15.gold_<양> (data/iap.json 의 apple).
##
##  흐름
##   연결   : init_connection (Transaction.updates 리스너를 붙임 → 앱이 꺼진 사이의 거래·다른 기기 구매가 purchase_updated 로 들어옴)
##   가격   : fetch_products → displayPrice (현지 통화 글)
##   구매   : appAccountToken = UUID 모양으로 바꾼 SHA-256(iid) 앞 32자 (Billing.account_uuid — 규칙은 docs/server/api.md 3.6) → 결과는 신호
##            purchase_updated(purchased) → state purchased (order_id = transactionId, receipt = JWS signedTransaction)
##            purchase_updated(pending) / 오류 deferred-payment (Ask to Buy) → state pending (지급하지 않음 — 승인되면 Transaction.updates 로 purchased 가 와서 unfinished_changed)
##            오류 user-cancelled → cancelled · already-owned → 끝내지 않은 그 거래를 돌려줌 · 그 밖 → failed + 코드
##   미처리 : pending_transactions (Transaction.unfinished). 환불·철회된(revocationDate) 거래는 지급하지 않고 finish 만 해서 치움
##   끝냄   : transaction.finish() — 소모형. 원본 거래 사전(tx.raw)을 그대로 돌려줌
##  영수증 JWS 가 비어 있거나 모양이 틀리면 지급 길로 보내지 않고 failed(no_receipt) — 거래는 끝내지 않으므로 다음 restore 때 다시 시도.
##  플러그인이 없는 환경(PC · 편집기 · 안드로이드)에서는 is_supported() 거짓.

const SigWait := preload("res://scripts/core/billing/sig_wait.gd")
const AppleIap := preload("res://scripts/core/billing/apple_iap.gd")

## 기다리는 시간 (초) — 시험은 짧게 바꿈
var timeouts: Dictionary = {"connect": 30.0, "query": 30.0, "finish": 30.0, "purchase": 900.0}
## 어댑터 (AppleIap) 또는 시험이 끼운 가짜. 비어 있으면 _ready 에서 플러그인으로 만듦
var iap: Node = null

var _connected := false
var _connecting := false
var _buying := ""
var _products: Array = []
var _pid_by_spid: Dictionary = {}


func _init() -> void:
	store_name = "apple"


func _ready() -> void:
	if iap == null and AppleIap.available():
		iap = AppleIap.new()
		add_child(iap)
	if iap != null:
		if iap.get_parent() == null:
			add_child(iap)
		iap.connect("purchase_updated", _on_updated)
		_connect_async.call_deferred()


func is_supported() -> bool:
	return iap != null or AppleIap.available()


func is_available() -> bool:
	return iap != null and _connected


func set_products(products: Array) -> void:
	_products = products
	_pid_by_spid.clear()
	for p: Variant in products:
		if p is Dictionary:
			_pid_by_spid[str(p.get("apple", p.get("id", "")))] = str(p.get("id", ""))


func _connect_async() -> void:
	await prepare()


func prepare() -> bool:
	if iap == null:
		return false
	if _connected:
		return true
	if _connecting:
		while _connecting:
			await get_tree().process_frame
		return _connected
	_connecting = true
	# 어댑터 호출은 코루틴 — 제한 시간은 어댑터(래퍼)가 가짐. 여기서는 결과만 받음
	_connected = bool(await iap.init_connection())
	_connecting = false
	return _connected


## 구매 창 흐름이 기다리지 않는 소식 (대기 → 승인 · 다른 기기 구매 · 앱이 꺼진 사이의 거래) → Billing 이 restore
func _on_updated(p: Dictionary) -> void:
	if _buying != "" and str(p.get("product_id", "")) == _buying:
		return
	if str(p.get("state", "")) == "purchased" and not bool(p.get("revoked", false)):
		unfinished_changed.emit()


func query_products(products: Array) -> Array:
	set_products(products)
	if not await prepare():
		return []
	var rows: Array = await iap.fetch_products(_pid_by_spid.keys())
	var out: Array = []
	for r: Variant in rows:
		if r is Dictionary and _pid_by_spid.has(str(r.get("spid", ""))) and str(r.get("price", "")) != "":
			out.append({"pid": _pid_by_spid[str(r["spid"])], "price": str(r["price"]), "currency": str(r.get("currency", ""))})
	return out


func purchase(pid: String, spid: String, opts: Dictionary) -> Dictionary:
	if iap == null or not await prepare():
		return _failed(pid, spid, "unavailable")
	if _buying != "":
		return _failed(pid, spid, "busy")
	_buying = spid
	var accept := func(_i: int, args: Array) -> bool:
		var d: Variant = args[0]
		var pidv := str(d.get("product_id", "")) if d is Dictionary else ""
		return pidv == "" or pidv == spid   # 다른 상품의 소식은 흘려보냄 (그쪽은 _on_updated 가 restore 로)
	var w: RefCounted = SigWait.arm(self, [iap.purchase_updated, iap.purchase_error], float(timeouts["purchase"]), accept)
	var sent := bool(await iap.request_purchase(spid, str(opts.get("account_uuid", ""))))
	var tx: Dictionary
	if not sent:
		w.cancel()
		tx = _failed(pid, spid, "unavailable")
	else:
		var r: Dictionary = await w.join()
		match int(r["i"]):
			0:
				tx = _from_p(pid, spid, (r["args"] as Array)[0])
			1:
				tx = await _from_error(pid, spid, (r["args"] as Array)[0])
			_:
				tx = _failed(pid, spid, "timeout")   # 결제는 뒤에서 끝났을 수 있음 — Transaction.updates 가 알려 줌
	_buying = ""
	return tx


func _from_p(pid: String, spid: String, p: Dictionary) -> Dictionary:
	if str(p.get("state", "")) == "pending":
		return {"state": "pending", "store": store_name, "pid": pid, "spid": spid, "order_id": str(p.get("transaction_id", ""))}
	if bool(p.get("revoked", false)):
		return _failed(pid, spid, "revoked")
	return _tx_of(pid, spid, p)


func _tx_of(pid: String, spid: String, p: Dictionary) -> Dictionary:
	var jws := str(p.get("jws", ""))
	var tid := str(p.get("transaction_id", ""))
	if tid == "" or not AppleIap.is_jws(jws):
		return _failed(pid, spid, "no_receipt")
	return {"state": "purchased", "store": store_name, "pid": pid, "spid": spid, "order_id": tid, "receipt": jws, "raw": p.get("raw", {})}


func _from_error(pid: String, spid: String, e: Dictionary) -> Dictionary:
	var code := str(e.get("code", ""))
	match code:
		"usercancelled":
			return {"state": "cancelled", "store": store_name, "pid": pid}
		"deferredpayment", "pending":
			return {"state": "pending", "store": store_name, "pid": pid, "spid": spid, "order_id": ""}
		"alreadyowned":
			for tx: Variant in await query_unfinished():
				if tx is Dictionary and str(tx.get("spid", "")) == spid:
					return tx
			return _failed(pid, spid, "already_owned")
		"networkerror":
			return _failed(pid, spid, "network")
		"itemunavailable", "skunotfound":
			return _failed(pid, spid, "item_unavailable")
	return _failed(pid, spid, code if code != "" else "error")


func _failed(pid: String, spid: String, code: String) -> Dictionary:
	return {"state": "failed", "store": store_name, "pid": pid, "spid": spid, "error": code}


func query_unfinished() -> Array:
	if iap == null or not await prepare():
		return []
	var out: Array = []
	for p: Variant in await iap.pending_transactions():
		if not (p is Dictionary):
			continue
		var spid := str(p.get("product_id", ""))
		if not _pid_by_spid.has(spid) or str(p.get("state", "")) != "purchased":
			continue
		if bool(p.get("revoked", false)):
			# 환불·철회된 거래는 지급하지 않음 — 목록에서 사라지게 끝내기만
			await iap.finish(p.get("raw", {}))
			continue
		var tx := _tx_of(str(_pid_by_spid[spid]), spid, p)
		if str(tx.get("state")) == "purchased":
			out.append(tx)
	return out


func finish(tx: Dictionary) -> bool:
	var raw: Variant = tx.get("raw")
	if iap == null or not (raw is Dictionary) or (raw as Dictionary).is_empty() or not await prepare():
		return false
	return bool(await iap.finish(raw))
