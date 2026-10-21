extends Node
## 가짜 BillingClient (6b 시험) — 플러그인 GodotGooglePlayBilling 의 BillingClient 와 같은 신호·함수. 응답은 한두 프레임 뒤에 신호로 (진짜처럼 비동기).
##  시나리오는 속성으로: connect_mode · catalog(콘솔에 등록된 상품) · owned(소모하지 않은 구매) · purchase_mode · consume_mode · query_mode

signal connected
signal disconnected
signal connect_error(response_code: int, debug_message: String)
signal query_product_details_response(response: Dictionary)
signal query_purchases_response(response: Dictionary)
signal on_purchase_updated(response: Dictionary)
signal consume_purchase_response(response: Dictionary)
signal acknowledge_purchase_response(response: Dictionary)

## "ok" · "error" (connect_error 3) · "silent" (영영 답 없음)
var connect_mode := "ok"
var connect_code := 3
## 콘솔에 등록된 상품: spid → 가격 글
var catalog: Dictionary = {}
## 소모하지 않은 구매 (플러그인 Utils.purchaseToDictionary 모양)
var owned: Array = []
## "success" · "cancel" · "pending" · "owned"(ITEM_ALREADY_OWNED 를 launch 결과로) · "rc:<n>"(on_purchase_updated 의 오류) · "launch:<n>"(launch 결과가 오류) · "silent"
var purchase_mode := "success"
## "ok" · "error" · "not_owned" · "silent"
var consume_mode := "ok"
## "ok" · "error" · "silent"
var query_mode := "ok"
var _ready_flag := false
var obfuscated := ""
var calls: Dictionary = {}
var _seq := 0
var last_consumed: Array = []


func _hit(k: String) -> void:
	calls[k] = int(calls.get(k, 0)) + 1


func _later(f: Callable, frames: int = 2) -> void:
	_run.call_deferred(f, frames)


func _run(f: Callable, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	f.call()


func start_connection() -> void:
	_hit("start_connection")
	match connect_mode:
		"ok":
			_later(func() -> void:
				_ready_flag = true
				connected.emit())
		"error":
			_later(func() -> void: connect_error.emit(connect_code, "fake billing unavailable"))


func end_connection() -> void:
	_ready_flag = false


func is_ready() -> bool:
	return _ready_flag


func drop_connection() -> void:
	_ready_flag = false
	disconnected.emit()


func get_connection_state() -> int:
	return 2 if _ready_flag else 0


func query_product_details(product_list: PackedStringArray, _type: int) -> void:
	_hit("query_product_details")
	if query_mode == "silent":
		return
	if query_mode == "error":
		_later(func() -> void: query_product_details_response.emit({"response_code": 2, "debug_message": "fake"}))
		return
	var rows: Array = []
	for spid: String in product_list:
		if catalog.has(spid):
			rows.append({"product_id": spid, "title": spid, "name": spid, "description": "", "product_type": "inapp",
				"one_time_purchase_offer_details_list": [{"price_amount_micros": 1000000, "price_currency_code": "KRW", "formatted_price": str(catalog[spid]), "purchase_option_id": "legacy-base", "offer_id": null, "offer_token": "t"}],
				"subscription_offer_details": null})
	_later(func() -> void: query_product_details_response.emit({"response_code": 0, "debug_message": "", "product_details": rows, "unfetched_products": []}))


func query_purchases(_type: int) -> void:
	_hit("query_purchases")
	if query_mode == "silent":
		return
	if query_mode == "error":
		_later(func() -> void: query_purchases_response.emit({"response_code": 6, "debug_message": "fake"}))
		return
	var snap := owned.duplicate(true)
	_later(func() -> void: query_purchases_response.emit({"response_code": 0, "debug_message": "", "purchases": snap}))


func make_purchase(spid: String, state: int = 1, order_id: String = "") -> Dictionary:
	_seq += 1
	return {"order_id": order_id if order_id != "" else "GPA.0000-0000-0000-%05d" % _seq, "purchase_token": "tok_%s_%d" % [spid, _seq], "package_name": "xyz.show4you.deadline15",
		"purchase_state": state, "purchase_time": 1791936000000, "original_json": "{}", "is_acknowledged": false, "is_auto_renewing": false, "is_suspended": false,
		"quantity": 1, "signature": "sig", "product_ids": PackedStringArray([spid])}


func purchase(product_id: String, _option: String = "", _offer: String = "", _personalized: bool = false) -> Dictionary:
	_hit("purchase")
	if not catalog.has(product_id):
		return {"response_code": 5, "debug_message": "productId not found! You must query the product details and wait for the result before purchasing."}
	if purchase_mode.begins_with("launch:"):
		return {"response_code": int(purchase_mode.substr(7)), "debug_message": "fake"}
	if purchase_mode == "owned":
		return {"response_code": 7, "debug_message": "already owned"}
	match purchase_mode:
		"success":
			var p := make_purchase(product_id, 1)
			owned.append(p)
			_later(func() -> void: on_purchase_updated.emit({"response_code": 0, "debug_message": "", "purchases": [p]}))
		"pending":
			var p2 := make_purchase(product_id, 2)
			owned.append(p2)
			_later(func() -> void: on_purchase_updated.emit({"response_code": 0, "debug_message": "", "purchases": [p2]}))
		"cancel":
			_later(func() -> void: on_purchase_updated.emit({"response_code": 1, "debug_message": "user canceled"}))
		"silent":
			pass
		_:
			if purchase_mode.begins_with("rc:"):
				var rc := int(purchase_mode.substr(3))
				_later(func() -> void: on_purchase_updated.emit({"response_code": rc, "debug_message": "fake"}))
	return {"response_code": 0, "debug_message": ""}


func consume_purchase(token: String) -> void:
	_hit("consume_purchase")
	last_consumed.append(token)
	match consume_mode:
		"ok":
			for i in range(owned.size() - 1, -1, -1):
				if str(owned[i]["purchase_token"]) == token:
					owned.remove_at(i)
			_later(func() -> void: consume_purchase_response.emit({"response_code": 0, "debug_message": "", "token": token}))
		"not_owned":
			_later(func() -> void: consume_purchase_response.emit({"response_code": 8, "debug_message": "not owned", "token": token}))
		"error":
			_later(func() -> void: consume_purchase_response.emit({"response_code": 6, "debug_message": "fake", "token": token}))


func set_obfuscated_account_id(account_id: String) -> void:
	obfuscated = account_id


## 시험이 부름: 앱 밖에서 대기 결제가 승인됨 (owned 의 PENDING → PURCHASED) → 플러그인이 on_purchase_updated 를 보냄
func approve_pending() -> void:
	var ps: Array = []
	for p: Dictionary in owned:
		if int(p["purchase_state"]) == 2:
			p["purchase_state"] = 1
			ps.append(p)
	on_purchase_updated.emit({"response_code": 0, "debug_message": "", "purchases": ps})
