extends RefCounted
## 가짜 결제 확인 서버 (디버그 빌드 전용) — docs/server/api.md 의 약속을 그대로 흉내 낸 GDScript.
##  진짜 서버(Cloudflare Workers + D1, 다음 작업)와 같은 요청 → 같은 응답 JSON·HTTP 상태를 돌려준다. Verifier 는 둘을 구별하지 않고
##  같은 코드로 응답을 해석한다 (주소가 fake:// 이면 이 파일, https:// 이면 HTTPRequest).
##  상태(D1 의 orders·refunds 표 대신)는 user://fake_iap/server.json, 가게 쪽 확인(가게 API 대신)은 가짜 가게 장부 store.json 을 읽음.
##
##  엔드포인트: POST /v1/purchases/verify · POST /v1/purchases/consume · GET /v1/refunds · GET /v1/health

const Files := preload("res://scripts/core/billing/fake_files.gd")
const FakeBackend := preload("res://scripts/core/billing/backend_fake.gd")

var products: Array = []   # data/iap.json 의 IAP_PRODUCTS (진짜 서버는 같은 표를 D1/설정에 둠)


func _init(prod: Array) -> void:
	products = prod


func _state() -> Dictionary:
	return Files.read(Files.SERVER_FILE, {"orders": {}})


static func _err(status: int, code: String, msg: String) -> Dictionary:
	return {"status": status, "body": {"ok": false, "error": {"code": code, "message": msg}}}


static func _ok(body: Dictionary) -> Dictionary:
	var b := body.duplicate(true)
	b["ok"] = true
	return {"status": 200, "body": b}


static func _is_iid(v: Variant) -> bool:
	if typeof(v) != TYPE_STRING or (v as String).length() != 32:
		return false
	for ch: String in (v as String):
		if not "0123456789abcdef".contains(ch):
			return false
	return true


func _product(pid: String) -> Variant:
	for p: Variant in products:
		if p is Dictionary and str(p["id"]) == pid:
			return p
	return null


## 요청 하나 → {status:int, body:Dictionary}
func handle(method: String, path: String, query: Dictionary, headers: Dictionary, body: Dictionary) -> Dictionary:
	if path == "/v1/health" and method == "GET":
		return _ok({"time": floorf(Time.get_unix_time_from_system() * 1000.0), "env": "dev"})
	if not _is_iid(headers.get("X-D15-Install", "")):
		return _err(401, "no_install_id", "X-D15-Install header missing or malformed")
	match [method, path]:
		["POST", "/v1/purchases/verify"]:
			return _verify(headers, body)
		["POST", "/v1/purchases/consume"]:
			return _consume(headers, body)
		["GET", "/v1/refunds"]:
			return _refunds(headers, query)
	return _err(404, "not_found", "unknown endpoint")


## 주인을 다른 설치가 다시 가져갈 수 있기까지 (재설치 복구) — docs/server/api.md 3.2 (재검수 디렉터 결정: 24시간, 주문당 1번)
const RECLAIM_MS := 86400000.0
const RECLAIM_MAX := 1
## 시험용 시계 밀기 (ms)
var clock_offset_ms := 0.0


func _now() -> float:
	return floorf(Time.get_unix_time_from_system() * 1000.0) + clock_offset_ms


func _env_ok(b: Dictionary) -> bool:
	return str(b.get("env", "")) == "dev"


## 판단 순서: (형·영수증 확인) → consumed > refunded > (재claim: 가게 소모 · 1번 · 24시간) > valid
func _verify(headers: Dictionary, b: Dictionary) -> Dictionary:
	var iid := str(headers["X-D15-Install"])
	for k: String in ["store", "product_id", "store_product_id", "order_id", "receipt"]:
		if typeof(b.get(k)) != TYPE_STRING or str(b[k]) == "":
			return _err(400, "bad_request", "missing " + k)
	if not _env_ok(b):
		return _err(400, "env_mismatch", "this server is the dev environment")
	if str(b["store"]) != "dev":
		return _err(400, "bad_store", "this server only accepts the fake store")
	var p: Variant = _product(str(b["product_id"]))
	if p == null:
		return _err(422, "unknown_product", "unknown product_id")
	if str(p["id"]) != str(b["store_product_id"]):   # dev 가게 상품 id = 게임 안 id
		return _err(422, "product_mismatch", "store_product_id does not match product_id")
	# 가게에 영수증 확인 (진짜: STOVE 결제 조회 · Google purchases.products.get · Apple JWS — 비밀 키는 서버에만).
	#  계정 값은 **확인된 영수증의 것만** (클라이언트가 보낸 account_id 는 읽지 않음)
	var r: Variant = JSON.parse_string(str(b["receipt"]))
	var oid := str(b["order_id"])
	var spid := str(b["store_product_id"])
	if not (r is Dictionary) or str(r.get("oid", "")) != oid or str(r.get("spid", "")) != spid \
			or str(r.get("sig", "")) != Files.sig(FakeBackend.FAKE_SIGNER, oid, spid + "|" + str(r.get("acct", ""))):
		return _err(422, "invalid_receipt", "receipt signature check failed")
	var acct := str(r.get("acct", ""))
	var L := Files.read(Files.STORE_FILE, {"orders": {}})
	var so: Variant = (L["orders"] as Dictionary).get(oid)
	if not (so is Dictionary):
		return _err(422, "invalid_receipt", "the store does not know this order")
	var S := _state()
	var key := "dev:" + oid
	var have: Variant = (S["orders"] as Dictionary).get(key)
	var out := {"order_id": oid, "product_id": str(p["id"]), "gold": float(p["gold"])}
	# 1) consumed — 누가 물어도 consumed (다시 주지 않음)
	if have is Dictionary and str(have["st"]) == "consumed":
		out["status"] = "consumed"
		out["first"] = false
		return _ok(out)
	# 2) refunded
	if bool(so.get("refunded", false)) or (have is Dictionary and str(have["st"]) == "refunded"):
		return _err(422, "refunded", "this order was refunded")
	if str(so.get("state")) == "pending":
		out["status"] = "pending"
		return _ok(out)
	# 3) claim — 처음 확인받은 설치가 주인. 다른 설치는 아래를 모두 만족할 때만 넘겨받음 (재설치 복구):
	#   - 가게 쪽에서 아직 소모되지 않음 (Google consumptionState=1 · acknowledgementState=1 이면 원래 주인이 이미 받음 → 403 already_delivered)
	#     가짜 가게는 장부의 finished(가게 finish = Google consume)가 그 표시
	#   - 이 주문의 재claim 이 처음 (주문당 RECLAIM_MAX 번 → 넘으면 403 reclaim_limit)
	#   - 주인이 claim 한 지 24시간이 지남 (안이면 403 order_claimed)
	#  영수증의 계정 값은 영수증을 가진 사람이면 누구나 같으므로 '같은 계정이면 바로'는 하지 않음 (요청자 신원 확인 수단이 없음 — api.md)
	if have is Dictionary and str(have["install_id"]) != iid:
		if bool(so.get("finished", false)):
			return _err(403, "already_delivered", "the store says this purchase was already consumed")
		if int(have.get("reclaims", 0)) >= RECLAIM_MAX:
			return _err(403, "reclaim_limit", "this order was already reclaimed once")
		if _now() - float(have.get("claimed_at", 0)) < RECLAIM_MS:
			return _err(403, "order_claimed", "order already claimed by another install")
		have["reclaimed_from"] = str(have["install_id"])
		have["reclaimed_at"] = _now()
		have["reclaims"] = int(have.get("reclaims", 0)) + 1
		have["install_id"] = iid
		have["account_id"] = acct
		have["claimed_at"] = _now()
		Files.write(Files.SERVER_FILE, S)
		out["status"] = "valid"
		out["first"] = false
		out["reclaimed"] = true
		return _ok(out)
	# 4) valid
	if have is Dictionary:
		out["status"] = "valid"
		out["first"] = false
		return _ok(out)
	S["orders"][key] = {"product_id": str(p["id"]), "gold": float(p["gold"]), "install_id": iid, "account_id": acct, "st": "verified",
		"verified_at": _now(), "claimed_at": _now()}
	Files.write(Files.SERVER_FILE, S)
	out["status"] = "valid"
	out["first"] = true
	return _ok(out)


## 소모: verify 때 서버가 기록한 주인(iid)만. 원자적 (UPDATE … WHERE st='verified' AND install_id=?) — 한 주문은 한 설치만 소모
func _consume(headers: Dictionary, b: Dictionary) -> Dictionary:
	var iid := str(headers["X-D15-Install"])
	if typeof(b.get("store")) != TYPE_STRING or typeof(b.get("order_id")) != TYPE_STRING:
		return _err(400, "bad_request", "store and order_id are required")
	if not _env_ok(b):
		return _err(400, "env_mismatch", "this server is the dev environment")
	var S := _state()
	var key := str(b["store"]) + ":" + str(b["order_id"])
	var have: Variant = (S["orders"] as Dictionary).get(key)
	if not (have is Dictionary):
		return _err(404, "unknown_order", "verify first")
	if str(have["install_id"]) != iid:
		return _err(403, "order_claimed", "order belongs to another install")
	if str(have["st"]) == "refunded":
		return _err(409, "refunded", "refunded order cannot be consumed")
	if str(have["st"]) != "consumed":
		have["st"] = "consumed"
		have["consumed_at"] = _now()
		Files.write(Files.SERVER_FILE, S)
	return _ok({"status": "consumed", "order_id": str(b["order_id"])})


## 환불 목록: verify 때 기록한 iid↔주문 연결로만 (쿼리의 account_id 는 무시)
func _refunds(headers: Dictionary, q: Dictionary) -> Dictionary:
	var iid := str(headers["X-D15-Install"])
	if str(q.get("env", "")) != "dev":
		return _err(400, "env_mismatch", "this server is the dev environment")
	var since := int(str(q.get("cursor", "0"))) if str(q.get("cursor", "")).is_valid_int() else 0
	var limit := clampi(int(str(q.get("limit", "100"))) if str(q.get("limit", "")).is_valid_int() else 100, 1, 100)
	var S := _state()
	var L := Files.read(Files.STORE_FILE, {"orders": {}})
	var rows: Array = []
	for oid: String in (L["orders"] as Dictionary).keys():
		var o: Dictionary = L["orders"][oid]
		if not bool(o.get("refunded", false)) or int(o.get("refund_seq", 0)) <= since:
			continue
		var have: Variant = (S["orders"] as Dictionary).get("dev:" + oid)
		if not (have is Dictionary) or str(have["install_id"]) != iid:
			continue
		rows.append({"store": "dev", "order_id": oid, "product_id": str(o["pid"]), "gold": float(have["gold"]), "refunded_at": float(o.get("refunded_at", 0)), "seq": int(o["refund_seq"])})
	rows.sort_custom(func(a: Dictionary, b2: Dictionary) -> bool: return int(a["seq"]) < int(b2["seq"]))
	var more := rows.size() > limit
	rows = rows.slice(0, limit)
	var next := since
	for r: Dictionary in rows:
		next = maxi(next, int(r["seq"]))
		r.erase("seq")
	return _ok({"orders": rows, "cursor": str(next), "more": more})
