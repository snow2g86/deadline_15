extends Node
## 가짜 AppleIap 어댑터 (6b 시험) — scripts/core/billing/apple_iap.gd 의 약속과 같은 모양.
##  시나리오: connect_ok · catalog · pending(끝내지 않은 거래 목록) · purchase_mode

signal purchase_updated(p: Dictionary)
signal purchase_error(e: Dictionary)

var connect_ok := true
var catalog: Dictionary = {}
## 끝내지 않은 거래들 (어댑터 p 모양)
var unfinished: Array = []
## "success" · "cancel" · "deferred" · "pending_state" · "error:<code>" · "badjws" · "silent"
var purchase_mode := "success"
var finish_ok := true
var calls: Dictionary = {}
var last_uuid := ""
var finished_ids: Array = []
var _seq := 0
const JWS := "eyJhbGciOiJFUzI1NiJ9.eyJ0cmFuc2FjdGlvbklkIjoiMSJ9.c2ln"


func _hit(k: String) -> void:
	calls[k] = int(calls.get(k, 0)) + 1


func make_p(spid: String, state: String = "purchased", jws: String = JWS) -> Dictionary:
	_seq += 1
	var tid := "20000000%05d" % _seq
	return {"transaction_id": tid, "product_id": spid, "jws": jws, "state": state, "revoked": false, "raw": {"id": tid, "productId": spid, "transactionId": tid, "purchaseToken": jws}}


func init_connection() -> bool:
	_hit("init_connection")
	await get_tree().process_frame
	return connect_ok


func fetch_products(spids: Array) -> Array:
	_hit("fetch_products")
	await get_tree().process_frame
	var out: Array = []
	for s: Variant in spids:
		if catalog.has(str(s)):
			out.append({"spid": str(s), "price": str(catalog[str(s)]), "currency": "KRW"})
	return out


func request_purchase(spid: String, account_uuid: String) -> bool:
	_hit("request_purchase")
	last_uuid = account_uuid
	await get_tree().process_frame
	_fire.call_deferred(spid)
	return true


func _fire(spid: String) -> void:
	await get_tree().process_frame
	match purchase_mode:
		"success":
			var p := make_p(spid)
			unfinished.append(p)
			purchase_updated.emit(p)
		"badjws":
			var pb := make_p(spid, "purchased", "99999")
			unfinished.append(pb)
			purchase_updated.emit(pb)
		"pending_state":
			purchase_updated.emit(make_p(spid, "pending"))
		"cancel":
			purchase_error.emit({"code": "usercancelled", "message": "cancelled", "product_id": spid})
		"deferred":
			purchase_error.emit({"code": "deferredpayment", "message": "ask to buy", "product_id": spid})
		"silent":
			pass
		_:
			if purchase_mode.begins_with("error:"):
				purchase_error.emit({"code": purchase_mode.substr(6), "message": "fake", "product_id": spid})


func pending_transactions() -> Array:
	_hit("pending_transactions")
	await get_tree().process_frame
	return unfinished.duplicate(true)


func finish(raw: Dictionary) -> bool:
	_hit("finish")
	await get_tree().process_frame
	if not finish_ok:
		return false
	var tid := str(raw.get("transactionId", ""))
	finished_ids.append(tid)
	for i in range(unfinished.size() - 1, -1, -1):
		if str(unfinished[i]["transaction_id"]) == tid:
			unfinished.remove_at(i)
	return true
