extends Node
## 결제 확인 서버 클라이언트 (결제층 A) — 약속은 docs/server/api.md
##  게임은 비밀 키를 갖지 않는다. 보내는 것: 설치 식별자(X-D15-Install) · 클라이언트 판(X-D15-Client) · 가게 영수증 원본.
##  영수증을 가게에 확인하는 일(Google 서비스 계정 키 · Apple App Store Server API 키 · STOVE 결제 확인 키)은 서버만 한다.
##
##  주소는 data/iap.json 의 IAP_SERVER[env].url — env 는 dev · stage · prod (Billing 이 정함: 디버그 빌드 dev, 출시 빌드 prod).
##   디버그 빌드는 local(로컬 wrangler dev, server/ — 요청의 env 는 IAP_SERVER.local.env = "dev")도 고를 수 있음.
##   "fake://…" 이면 가짜 서버(fake_server.gd, 같은 약속의 GDScript 흉내, 디버그 빌드만), "https://…" 이면 HTTPRequest, "" 이면 '설정 안 됨'(네트워크 오류처럼 다룸).
##
##  돌려주는 값 (Billing 이 읽음):
##   verify  → {status: "valid"|"pending"|"consumed"|"invalid"|"error", code, gold, first}
##             error = 네트워크·서버 오류·요청 과다 → 지급하지 않고 미처리로 남겨 다음 기회에 다시 (retry)
##             invalid = 영수증이 틀림·환불됨·다른 설치가 이미 받음 → 지급하지 않음
##   consume → {ok:bool, code}
##   refunds → {ok:bool, orders:[{store, order_id, product_id, gold, refunded_at}], cursor, more, code}

const FakeServer := preload("res://scripts/core/billing/fake_server.gd")
const API_VERSION := "v1"

var env := "dev"
var base_url := ""
var timeout := 10.0
var client_tag := ""
var fake: FakeServer = null

## (디버그) 가짜 서버의 네트워크 흉내: net_down 이면 늘 실패, net_fail_left 번만 실패
var net_down := false
var net_fail_left := 0
## 시험·보고용 세기
var calls: Dictionary = {}
## (디버그·시험) 가짜 서버 응답을 돌려주기 바로 전에 부름 (path) — 같은 프레임에 출격하는 경우 같은 경합을 시험이 만들 때
var debug_hook: Callable = Callable()


func configure(env_: String, cfg: Dictionary, products: Array, tag: String) -> void:
	env = str(cfg.get("env", env_))   # IAP_SERVER.local 은 dev 서버를 로컬에서 띄운 것이라 요청의 env 는 "dev" (api.md 1)
	base_url = str(cfg.get("url", ""))
	timeout = float(cfg.get("timeout", 10))
	client_tag = tag
	fake = FakeServer.new(products) if base_url.begins_with("fake://") and OS.is_debug_build() else null
	if base_url.begins_with("fake://") and fake == null:
		base_url = ""   # 출시 빌드는 가짜 서버를 쓰지 않음
	if base_url.begins_with("http://") and not OS.is_debug_build():
		base_url = ""   # 출시 빌드는 https 만 (로컬 서버 http://127.0.0.1 은 디버그 빌드만)


func _headers(iid: String) -> Dictionary:
	return {"Content-Type": "application/json", "X-D15-Install": iid, "X-D15-Client": client_tag}


## 요청 하나 → {net:bool, status:int, body:Dictionary}
func _call(method: String, path: String, query: Dictionary, body: Dictionary, iid: String) -> Dictionary:
	calls[path] = int(calls.get(path, 0)) + 1
	var hd := _headers(iid)
	if fake != null:
		await get_tree().process_frame   # 네트워크처럼 다음 프레임에
		if net_down or net_fail_left > 0:
			net_fail_left = maxi(0, net_fail_left - 1)
			return {"net": false, "status": 0, "body": {}, "code": "network"}
		var r := fake.handle(method, path, query, hd, body)
		if debug_hook.is_valid():
			debug_hook.call(path)
		# 진짜 서버와 같게: 응답은 JSON 글을 거쳐 읽음 (형이 같은지)
		var back: Variant = JSON.parse_string(JSON.stringify(r["body"]))
		return {"net": true, "status": int(r["status"]), "body": back if back is Dictionary else {}}
	if base_url == "":
		await get_tree().process_frame
		return {"net": false, "status": 0, "body": {}, "code": "not_configured"}
	if OS.is_debug_build() and (net_down or net_fail_left > 0):
		# (디버그) 진짜 서버를 붙여도 네트워크 실패 흉내는 같게 (check_iap -- --server)
		await get_tree().process_frame
		net_fail_left = maxi(0, net_fail_left - 1)
		return {"net": false, "status": 0, "body": {}, "code": "network"}
	var url := base_url.trim_suffix("/") + path
	if not query.is_empty():
		var parts: Array = []
		for k: String in query.keys():
			parts.append("%s=%s" % [k.uri_encode(), str(query[k]).uri_encode()])
		url += "?" + "&".join(parts)
	var hr := HTTPRequest.new()
	hr.timeout = timeout
	add_child(hr)
	var hl := PackedStringArray()
	for k: String in hd.keys():
		hl.append("%s: %s" % [k, hd[k]])
	var err := hr.request(url, hl, HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET, JSON.stringify(body) if method == "POST" else "")
	if err != OK:
		hr.queue_free()
		return {"net": false, "status": 0, "body": {}, "code": "network"}
	var res: Array = await hr.request_completed
	hr.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"net": false, "status": 0, "body": {}, "code": "network"}
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if OS.is_debug_build() and debug_hook.is_valid():
		debug_hook.call(path)
	return {"net": true, "status": int(res[1]), "body": parsed if parsed is Dictionary else {}}


static func _code(r: Dictionary) -> String:
	if not bool(r.get("net", false)):
		return str(r.get("code", "network"))
	var e: Variant = (r["body"] as Dictionary).get("error")
	return str(e.get("code", "http_%d" % int(r["status"]))) if e is Dictionary else "http_%d" % int(r["status"])


## 다시 해 볼 만한 실패인가 (네트워크 · 5xx · 429)
static func _retryable(r: Dictionary) -> bool:
	var st := int(r.get("status", 0))
	return not bool(r.get("net", false)) or st >= 500 or st == 429 or st == 0


## (검수 반영) 계정 값은 보내지 않음 — 서버는 가게 확인 결과의 계정 값만 씀 (api.md 2.1)
func verify(tx: Dictionary, iid: String) -> Dictionary:
	var body := {"store": str(tx.get("store", "")), "product_id": str(tx.get("pid", "")), "store_product_id": str(tx.get("spid", "")),
		"order_id": str(tx.get("order_id", "")), "receipt": str(tx.get("receipt", "")), "env": env}
	var r: Dictionary = await _call("POST", "/%s/purchases/verify" % API_VERSION, {}, body, iid)
	if _retryable(r):
		return {"status": "error", "code": _code(r)}
	var b: Dictionary = r["body"]
	if int(r["status"]) == 200 and bool(b.get("ok", false)):
		var st := str(b.get("status", ""))
		if not ["valid", "pending", "consumed"].has(st):
			return {"status": "error", "code": "bad_response"}
		# 서버가 다른 주문·상품을 말하면 믿지 않음
		if str(b.get("order_id", "")) != str(tx.get("order_id", "")) or (b.has("product_id") and str(b["product_id"]) != str(tx.get("pid", ""))):
			return {"status": "error", "code": "bad_response"}
		return {"status": st, "gold": float(b.get("gold", 0)), "first": bool(b.get("first", false))}
	return {"status": "invalid", "code": _code(r)}


func consume(tx: Dictionary, iid: String) -> Dictionary:
	var body := {"store": str(tx.get("store", "")), "order_id": str(tx.get("order_id", "")), "env": env}
	var r: Dictionary = await _call("POST", "/%s/purchases/consume" % API_VERSION, {}, body, iid)
	if bool(r.get("net", false)) and int(r["status"]) == 200 and bool((r["body"] as Dictionary).get("ok", false)):
		return {"ok": true}
	return {"ok": false, "code": _code(r), "retry": _retryable(r)}


func refunds(iid: String, cursor: String) -> Dictionary:
	var q := {"cursor": cursor, "limit": "100", "env": env}
	var r: Dictionary = await _call("GET", "/%s/refunds" % API_VERSION, q, {}, iid)
	if not (bool(r.get("net", false)) and int(r["status"]) == 200 and bool((r["body"] as Dictionary).get("ok", false))):
		return {"ok": false, "code": _code(r)}
	var b: Dictionary = r["body"]
	var rows: Array = []
	for o: Variant in (b.get("orders") if b.get("orders") is Array else []):
		if o is Dictionary and typeof(o.get("store")) == TYPE_STRING and typeof(o.get("order_id")) == TYPE_STRING:
			rows.append(o)
	return {"ok": true, "orders": rows, "cursor": str(b.get("cursor", cursor)), "more": bool(b.get("more", false))}
