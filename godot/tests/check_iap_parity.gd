extends SceneTree
## 결제층 B — 가짜 서버(fake_server.gd)와 진짜 로컬 Worker(server/, wrangler dev)가 같은 요청에 같은 응답을 주는지 비교
##   (server/ 에서 npm run dev 를 띄운 뒤) Godot --headless --path godot --script res://tests/check_iap_parity.gd -- --server http://127.0.0.1:8951
##  같은 가게 장부 · 같은 시계 밀기로 요청 순서를 두 쪽에 똑같이 보내고 HTTP 상태와 JSON 본문(health 의 time 만 빼고)이 같아야 통과.

const Files := preload("res://scripts/core/billing/fake_files.gd")
const FakeServer := preload("res://scripts/core/billing/fake_server.gd")
const FakeBackend := preload("res://scripts/core/billing/backend_fake.gd")
const Remote := preload("res://tests/iap_remote.gd")

const A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const B := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const C := "cccccccccccccccccccccccccccccccc"
const H := 3600000.0

var url := ""
var fake: FakeServer
var remote: Remote
var ledger: Dictionary = {"seq": 0, "rseq": 0, "orders": {}}
var _n := 0
var _fails: Array = []


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--server")
	url = args[i + 1] if i >= 0 and i + 1 < args.size() else "http://127.0.0.1:8951"
	var db: Node = root.get_node("DataDB")
	var products: Array = db.call("global", "IAP_PRODUCTS")
	fake = FakeServer.new(products)
	remote = Remote.new(url)
	if int(remote.handle("GET", "/v1/health", {}, {}, {})["status"]) != 200:
		print("RESULT: FAIL (로컬 서버 %s 가 답하지 않음)" % url)
		quit(1)
		return
	Files.remote = ""
	Files.reset()
	Files.remote = url
	Files.reset()
	Files.remote = ""
	_clock(0.0)
	_run()
	Files.remote = url
	Files.reset()
	Files.remote = ""
	Files.reset()
	if _fails.is_empty():
		print("RESULT: PASS (%d개 요청이 같음)" % _n)
		quit(0)
	else:
		print("RESULT: FAIL (%d개 중 %d개 다름)" % [_n, _fails.size()])
		quit(1)


func _clock(ms: float) -> void:
	fake.clock_offset_ms = ms
	remote.clock_offset_ms = ms


## 가게 장부를 두 쪽에 (가짜 서버는 파일, Worker 는 /v1/dev/ledger)
func _ledger_put(oid: String, pid: String, acct: String, state := "purchased", finished := false) -> void:
	ledger["orders"][oid] = {"pid": pid, "spid": pid, "acct": acct, "state": state, "finished": finished, "at": 0}
	_ledger_write()


func _ledger_refund(oid: String) -> void:
	ledger["rseq"] = int(ledger["rseq"]) + 1
	var o: Dictionary = ledger["orders"][oid]
	o["refunded"] = true
	o["refund_seq"] = ledger["rseq"]
	o["refunded_at"] = 1792300000000.0 + float(ledger["rseq"])
	_ledger_write()


func _ledger_write() -> void:
	Files.remote = url
	Files.write(Files.STORE_FILE, ledger)   # 파일 + Worker
	Files.remote = ""


func _receipt(oid: String, spid: String, acct: String, signer := FakeBackend.FAKE_SIGNER) -> String:
	return JSON.stringify({"oid": oid, "spid": spid, "acct": acct, "sig": Files.sig(signer, oid, spid + "|" + acct)})


func _vb(oid: String, pid: String, acct: String) -> Dictionary:
	return {"store": "dev", "product_id": pid, "store_product_id": pid, "order_id": oid, "receipt": _receipt(oid, pid, acct), "env": "dev"}


static func _norm(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v))


func _same(what: String, method: String, path: String, query: Dictionary, iid: String, body: Dictionary) -> void:
	_n += 1
	var hd := {} if iid == "" else {"X-D15-Install": iid}
	var f := fake.handle(method, path, query, hd, body)
	var r := remote.handle(method, path, query, hd, body)
	var fb: Dictionary = _norm(f["body"])
	var rb: Dictionary = _norm(r["body"])
	if path == "/v1/health":
		fb.erase("time")
		rb.erase("time")
	var ok := int(f["status"]) == int(r["status"]) and JSON.stringify(fb, "", true) == JSON.stringify(rb, "", true)
	print("  %s %-44s %d %s" % ["ok  " if ok else "FAIL", what, int(r["status"]), JSON.stringify(rb) if not ok or int(r["status"]) != 200 else str(rb.get("status", ""))])
	if not ok:
		print("        가짜 %d %s" % [int(f["status"]), JSON.stringify(fb)])
		_fails.append(what)


func _v(what: String, iid: String, b: Dictionary) -> void:
	_same(what, "POST", "/v1/purchases/verify", {}, iid, b)


func _c(what: String, iid: String, oid: String, extra := {}) -> void:
	var b := {"store": "dev", "order_id": oid, "env": "dev"}
	b.merge(extra, true)
	_same(what, "POST", "/v1/purchases/consume", {}, iid, b)


func _r(what: String, iid: String, q := {}) -> void:
	var qq := {"cursor": "", "env": "dev"}
	qq.merge(q, true)
	_same(what, "GET", "/v1/refunds", qq, iid, {})


func _run() -> void:
	print("── 가짜 서버 ↔ 로컬 Worker (%s) ──" % url)
	_same("health", "GET", "/v1/health", {}, "", {})
	_ledger_put("P1", "gold_1200", "acct-a")
	_ledger_put("P2", "gold_3000", "acct-a", "pending")
	_ledger_put("P3", "gold_500", "acct-a")
	_ledger_refund("P3")
	_ledger_put("P4", "gold_6500", "acct-a")
	_v("verify 처음 → valid first", A, _vb("P1", "gold_1200", "acct-a"))
	_v("verify 다시 → valid (멱등)", A, _vb("P1", "gold_1200", "acct-a"))
	var with_acct := _vb("P1", "gold_1200", "acct-a")
	with_acct["account_id"] = "acct-a"
	_v("다른 설치 + 본문 account_id → 403 order_claimed", B, with_acct)
	_v("pending", A, _vb("P2", "gold_3000", "acct-a"))
	_v("verify 전에 환불 → 422 refunded", A, _vb("P3", "gold_500", "acct-a"))
	_v("P4 valid", A, _vb("P4", "gold_6500", "acct-a"))
	var miss := _vb("P1", "gold_1200", "acct-a")
	miss.erase("receipt")
	_v("빠진 필드 → 400 bad_request", A, miss)
	var envx := _vb("P1", "gold_1200", "acct-a")
	envx["env"] = "prod"
	_v("env 다름 → 400 env_mismatch", A, envx)
	var st := _vb("P1", "gold_1200", "acct-a")
	st["store"] = "google"
	_v("다른 가게 → 400 bad_store", A, st)
	var up := _vb("P1", "gold_1200", "acct-a")
	up["product_id"] = "gold_1"
	_v("모르는 상품 → 422 unknown_product", A, up)
	var pm := _vb("P1", "gold_1200", "acct-a")
	pm["store_product_id"] = "gold_500"
	_v("상품 id 다름 → 422 product_mismatch", A, pm)
	var bad := _vb("P1", "gold_1200", "acct-a")
	bad["receipt"] = _receipt("P1", "gold_1200", "acct-b", FakeBackend.FAKE_SIGNER).replace("acct-b", "acct-a").replace("\"sig\":\"", "\"sig\":\"0")
	_v("서명 틀림 → 422 invalid_receipt", A, bad)
	_v("장부에 없는 주문 → 422 invalid_receipt", A, _vb("NOPE", "gold_500", "acct-a"))
	_v("iid 없음 → 401", "", _vb("P1", "gold_1200", "acct-a"))
	_same("모르는 경로 → 404", "GET", "/v1/nope", {}, A, {})
	_c("consume 모르는 주문 → 404", A, "P9")
	_c("consume 다른 설치 → 403", B, "P1", {"account_id": "acct-a"})
	_c("consume 주인 → consumed", A, "P1")
	_c("consume 다시 → consumed (멱등)", A, "P1")
	_c("consume env 다름 → 400", A, "P1", {"env": "stage"})
	_v("consumed 는 누가 물어도 consumed", B, _vb("P1", "gold_1200", "acct-a"))
	_r("환불 목록 (없음)", A)
	# 재claim
	_ledger_put("P5", "gold_500", "acct-a")
	_v("P5 A valid", A, _vb("P5", "gold_500", "acct-a"))
	_clock(23.0 * H)
	_v("23시간: B → 403 order_claimed", B, _vb("P5", "gold_500", "acct-a"))
	_clock(24.0 * H - 1000.0)
	_v("24시간-1초: B → 403", B, _vb("P5", "gold_500", "acct-a"))
	_clock(24.0 * H + 1000.0)
	_v("24시간+1초: B → 재claim (reclaimed)", B, _vb("P5", "gold_500", "acct-a"))
	_v("재claim 뒤 B 다시 → valid", B, _vb("P5", "gold_500", "acct-a"))
	_clock(60.0 * H)
	_v("두 번째 재claim(C) → 403 reclaim_limit", C, _vb("P5", "gold_500", "acct-a"))
	_c("옛 주인 A consume → 403 order_claimed", A, "P5")
	_c("새 주인 B consume → consumed", B, "P5")
	_ledger_put("P4", "gold_6500", "acct-a", "purchased", true)
	_v("가게에서 소모(finish)된 P4 → B 403 already_delivered", B, _vb("P4", "gold_6500", "acct-a"))
	_clock(0.0)
	# 환불
	_ledger_refund("P1")
	_ledger_refund("P4")
	_r("A 의 환불 목록 (P1 · P4)", A)
	_r("A limit=1 → more", A, {"limit": "1"})
	_r("A cursor 뒤", A, {"cursor": "2"})
	_r("B 의 환불 목록 (주인 아님 → 없음)", B, {"account_id": "acct-a"})
	_r("이상한 cursor · limit", A, {"cursor": "x", "limit": "0"})
	_same("환불 목록 env 없음 → 400", "GET", "/v1/refunds", {"cursor": ""}, A, {})
	_c("환불된 P4 consume → 409 refunded", A, "P4")
	_c("consume 뒤 환불된 P1 consume → 409 refunded", A, "P1")
	_v("consume 뒤 환불된 P1 verify → consumed", C, _vb("P1", "gold_1200", "acct-a"))
	_v("consume 전 환불된 P4 verify → 422 refunded", A, _vb("P4", "gold_6500", "acct-a"))
	# 검수 반영: 길이 상한 · 다른 상품 영수증 · acct 형 · 커서 자릿수 · 장부 상품 대조 · 오래된 영수증 · 429 · 501
	var lng := _vb("P6", "gold_500", "acct-a")
	lng["order_id"] = "x".repeat(513)
	_v("order_id 513자 → 400 too long", A, lng)
	var lr := _vb("P6", "gold_500", "acct-a")
	lr["receipt"] = "r".repeat(12289)
	_v("receipt 12289자 → 400 too long", A, lr)
	_c("consume order_id 513자 → 400", A, "y".repeat(513))
	_ledger_put("P6", "gold_500", "acct-a")
	_v("장부는 gold_500 · 영수증은 gold_1200 → 422", A, _vb("P6", "gold_1200", "acct-a"))
	_v("P6 valid", A, _vb("P6", "gold_500", "acct-a"))
	_ledger_put("P6", "gold_3000", "acct-a")
	_v("같은 주문을 다른 상품 영수증으로 다시 → 422 product_mismatch", A, _vb("P6", "gold_3000", "acct-a"))
	_ledger_put("P7", "gold_500", "5")
	var num_acct := _vb("P7", "gold_500", "5")
	var rc: Dictionary = JSON.parse_string(str(num_acct["receipt"]))
	rc["acct"] = 5
	num_acct["receipt"] = JSON.stringify(rc)
	_v("acct 가 숫자 → 422 invalid_receipt", A, num_acct)
	rc.erase("acct")
	var no_acct := _vb("P7", "gold_500", "")
	no_acct["receipt"] = JSON.stringify({"oid": "P7", "spid": "gold_500", "sig": Files.sig(FakeBackend.FAKE_SIGNER, "P7", "gold_500|")})
	_v("acct 없음 = \"\" → valid", A, no_acct)
	_r("커서 16자리 → 처음부터", A, {"cursor": "1234567890123456"})
	_r("커서 15자리 → 그 뒤", A, {"cursor": "123456789012345"})
	_r("limit 16자리 → 기본값", A, {"limit": "1000000000000000"})
	ledger["orders"]["P8"] = {"pid": "gold_500", "spid": "gold_500", "acct": "", "state": "purchased", "finished": false, "at": 1792300000000.0 - 6.0 * 365.0 * 86400000.0}
	_ledger_write()
	_v("구매가 5년보다 오래된 영수증 → 422", A, _vb("P8", "gold_500", ""))
	var sv := {"store": "stove", "product_id": "gold_500", "store_product_id": "gold_500", "order_id": "T1", "receipt": "T1", "env": "dev"}
	_v("STOVE → 501 not_implemented", A, sv)
	sv["store_product_id"] = "x"
	_v("STOVE 상품 id 다름 → 422 (확인 전 형 검사)", A, sv)
	fake.force_429 = 2
	remote.force_429 = 2
	_v("요청 과다 → 429 rate_limited", A, _vb("P1", "gold_1200", "acct-a"))
	_same("요청 과다는 iid 검사보다 먼저 → 429", "POST", "/v1/purchases/verify", {}, "", {})
	_r("제한이 풀리면 다시 200", A)
