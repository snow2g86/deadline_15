extends "res://scripts/core/billing/fake_server.gd"
## 시험용 결제 확인 서버 (6b) — google/apple 영수증도 받아 주는 대본형 서버. api.md 의 응답 모양 그대로.
##  verify_script: 앞에서부터 한 번씩 쓰는 응답 {status, code} (200 이면 body 의 status 를 'st' 로) — 비면 기본(valid, 이미 consume 한 주문은 consumed)

var verify_script: Array = []
var verify_calls: Array = []
var consume_calls: Array = []
var refund_calls := 0
var consumed: Dictionary = {}
var consume_script: Array = []


func handle(method: String, path: String, _query: Dictionary, headers: Dictionary, body: Dictionary) -> Dictionary:
	if path == "/v1/health":
		return _ok({"time": 1, "env": "dev"})
	if method == "POST" and path == "/v1/purchases/verify":
		verify_calls.append({"body": body.duplicate(true), "iid": str(headers.get("X-D15-Install", ""))})
		var key := "%s:%s" % [body.get("store"), body.get("order_id")]
		if not verify_script.is_empty():
			var o: Dictionary = verify_script.pop_front()
			var st := int(o.get("status", 200))
			if st != 200:
				return _err(st, str(o.get("code", "internal")), "scripted")
			return _ok({"status": str(o.get("st", "valid")), "order_id": str(body["order_id"]), "product_id": str(body["product_id"]), "gold": 0, "first": true})
		if consumed.has(key):
			return _ok({"status": "consumed", "order_id": str(body["order_id"]), "product_id": str(body["product_id"]), "gold": 0, "first": false})
		var p: Variant = _product(str(body["product_id"]))
		return _ok({"status": "valid", "order_id": str(body["order_id"]), "product_id": str(body["product_id"]), "gold": int(p["gold"]) if p != null else 0, "first": true})
	if method == "POST" and path == "/v1/purchases/consume":
		consume_calls.append(body.duplicate(true))
		if not consume_script.is_empty():
			var o2: Dictionary = consume_script.pop_front()
			return _err(int(o2.get("status", 500)), str(o2.get("code", "internal")), "scripted")
		consumed["%s:%s" % [body.get("store"), body.get("order_id")]] = true
		return _ok({"status": "consumed", "order_id": str(body["order_id"])})
	if method == "GET" and path == "/v1/refunds":
		refund_calls += 1
		return _ok({"orders": [], "cursor": "", "more": false})
	return _err(404, "not_found", "x")
