extends "res://scripts/core/billing/backend_base.gd"
## 가짜 가게 (디버그 빌드의 dev 판 전용 — 출시 빌드에서는 Billing 이 만들지 않음)
##  진짜 가게처럼 '주문 장부'(user://fake_iap/store.json)를 따로 들고, 끝내지(finish) 않은 거래는 앱을 다시 켜도 query_unfinished 로 다시 준다.
##  시나리오 (명령줄 -- --iap <이름>, 또는 시험이 scenario 를 바꿈):
##   success           : 구매됨
##   cancel            : 사용자가 결제 창을 닫음
##   pending           : 대기 (보호자 승인·편의점 결제 등) → 다음 query_unfinished 때 '구매됨'으로 바뀜
##   fail              : 가게 오류
##   net_fail          : 구매됨 — 서버 확인이 네트워크 오류로 1번 실패 (Verifier 가 맡음) → 다음 기회에 다시
##   crash_before_grant: 구매됨 — 서버 확인 뒤, 지급 직전에 앱이 죽음 (Billing 이 맡음)
##   crash_after_grant : 구매됨 — 지급·저장 뒤, finish 전에 앱이 죽음 (Billing 이 맡음)
##   refund            : 구매됨 — 지급이 끝나면 가게가 환불 처리 (서버의 환불 목록에 나타남)
##  영수증(receipt)은 가짜 서명이 든 JSON 글 — 가짜 서버(fake_server.gd)만 확인한다. 진짜 비밀 키가 아님.

const Files := preload("res://scripts/core/billing/fake_files.gd")
## 가짜 가게 서명 글 (진짜 가게에서는 Google·Apple·STOVE 의 서명 — 게임은 모름. 가짜 서버와 짝)
const FAKE_SIGNER := "dev-fake-store"
const SCENARIOS := ["success", "cancel", "pending", "fail", "net_fail", "crash_before_grant", "crash_after_grant", "refund"]

var scenario := "success"
## 가짜 결제 창이 떠 있는 시간 (초)
var delay := 0.4
var _krw: Dictionary = {}   # pid → 원화


func _init() -> void:
	store_name = "dev"


func is_supported() -> bool:
	return true


func is_available() -> bool:
	return true


func query_products(products: Array) -> Array:
	await get_tree().process_frame
	var out: Array = []
	for p: Dictionary in products:
		_krw[str(p["id"])] = float(p.get("krw", 0))
		out.append({"pid": str(p["id"]), "price": "₩" + _grouped(float(p.get("krw", 0))), "currency": "KRW"})
	return out


static func _grouped(v: float) -> String:
	var s := str(int(roundf(v)))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _ledger() -> Dictionary:
	return Files.read(Files.STORE_FILE, {"seq": 0, "orders": {}})


## 영수증 = 가짜 가게가 서명한 {oid, spid, acct} — acct 는 구매 때 넣은 계정 토큰 (Google obfuscatedAccountId · Apple appAccountToken 흉내).
##  서버는 클라이언트가 보낸 계정 값이 아니라 이 확인된 값만 씀
func _tx(oid: String, o: Dictionary, state: String) -> Dictionary:
	var spid := str(o["spid"])
	var acct := str(o.get("acct", ""))
	var receipt := JSON.stringify({"oid": oid, "spid": spid, "acct": acct, "sig": Files.sig(FAKE_SIGNER, oid, spid + "|" + acct)})
	return {"state": state, "store": store_name, "pid": str(o["pid"]), "spid": spid, "order_id": oid, "receipt": receipt}


func purchase(pid: String, spid: String, opts: Dictionary) -> Dictionary:
	await get_tree().create_timer(delay).timeout
	match scenario:
		"cancel":
			return {"state": "cancelled", "store": store_name, "pid": pid}
		"fail":
			return {"state": "failed", "store": store_name, "pid": pid, "error": "store_error"}
	var L := _ledger()
	L["seq"] = int(L.get("seq", 0)) + 1
	var oid := "FAKE.%d.%d" % [int(Time.get_unix_time_from_system()), int(L["seq"])]
	var st := "pending" if scenario == "pending" else "purchased"
	var o := {"pid": pid, "spid": spid, "acct": str(opts.get("account_token", "")), "state": st, "finished": false, "at": floorf(Time.get_unix_time_from_system() * 1000.0)}
	L["orders"][oid] = o
	Files.write(Files.STORE_FILE, L)
	return _tx(oid, o, st)


func query_unfinished() -> Array:
	await get_tree().process_frame
	var L := _ledger()
	var out: Array = []
	var changed := false
	for oid: String in (L["orders"] as Dictionary).keys():
		var o: Dictionary = L["orders"][oid]
		if bool(o.get("finished", false)) or bool(o.get("refunded", false)):
			continue   # 끝냈거나 환불된 거래는 가게가 다시 주지 않음
		if str(o.get("state")) == "pending":
			# 대기 중이던 결제가 승인됨 (보호자 승인 등) — 다음 조회 때
			o["state"] = "purchased"
			changed = true
		out.append(_tx(oid, o, "purchased"))
	if changed:
		Files.write(Files.STORE_FILE, L)
	return out


func finish(tx: Dictionary) -> bool:
	await get_tree().process_frame
	var L := _ledger()
	var o: Variant = (L["orders"] as Dictionary).get(str(tx.get("order_id", "")))
	if not (o is Dictionary):
		return false
	o["finished"] = true
	return Files.write(Files.STORE_FILE, L)


## 가게가 환불 처리 (시험·refund 시나리오) — 서버 쪽 환불 목록(Google Voided Purchases · Apple REFUND 알림 · STOVE 환불 내역)에 나타남
func refund(oid: String) -> bool:
	var L := _ledger()
	var o: Variant = (L["orders"] as Dictionary).get(oid)
	if not (o is Dictionary):
		return false
	if bool(o.get("refunded", false)):
		return true
	L["rseq"] = int(L.get("rseq", 0)) + 1
	o["refunded"] = true
	o["refund_seq"] = L["rseq"]
	o["refunded_at"] = floorf(Time.get_unix_time_from_system() * 1000.0)
	return Files.write(Files.STORE_FILE, L)
