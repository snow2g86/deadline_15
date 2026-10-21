extends Node
## App Store (StoreKit 2) 어댑터 (6b) — godot-iap 4.0.3 (OpenIAP, addons/godot-iap 의 GodotIapWrapper + iOS GDExtension)를 backend_apple.gd 가 쓰기 쉬운
##  단순한 모양으로 바꿈. 플러그인의 큰 타입(types.gd)·신호 모양을 아는 곳은 이 파일뿐이고, 시험은 같은 모양의 가짜(tests/fake_apple_iap.gd)를 끼움.
##
##  이 어댑터의 약속 (백엔드가 의지하는 것):
##   신호 purchase_updated(p)  p = {transaction_id, product_id, jws, state: "purchased"|"pending", revoked: bool, raw: 플러그인 원본 사전}
##   신호 purchase_error(e)    e = {code: 정규화한 오류 이름(소문자·기호 없음 예 "usercancelled"), message, product_id}
##   init_connection() -> bool                         (await)
##   fetch_products(spids: Array) -> [{spid, price, currency}]   (await)
##   request_purchase(spid, account_uuid) -> bool      결과는 신호로 (StoreKit 은 구매 결과를 Transaction.updates 로도 줌)
##   pending_transactions() -> [p]                     끝내지 않은 거래 (await) — Transaction.unfinished
##   finish(raw: Dictionary) -> bool                   (await) transaction.finish() — 원본 사전을 그대로 돌려주어야 함
##  영수증: iOS 의 purchaseToken 이 JWS(signedTransaction) — 플러그인은 JWS 가 없으면 transactionId 로 채우므로 모양(점 2개)을 확인해 아니면 jws 를 비움.

const WRAPPER := "res://addons/godot-iap/godot_iap.gd"
const TYPES := "res://addons/godot-iap/types.gd"

signal purchase_updated(p: Dictionary)
signal purchase_error(e: Dictionary)

var _w: Node = null


## 이 판에서 쓸 수 있는가: iOS + GDExtension(GodotIap)이 올라와 있음 (PC · 편집기 · 안드로이드는 거짓)
static func available() -> bool:
	return OS.get_name() == "iOS" and ClassDB.class_exists("GodotIap") and ClassDB.can_instantiate("GodotIap") and ResourceLoader.exists(WRAPPER)


func _ready() -> void:
	var scr: Variant = load(WRAPPER)
	if not (scr is GDScript):
		return
	_w = (scr as GDScript).new()
	add_child(_w)   # 들어오면 래퍼가 네이티브 플러그인을 붙임
	_w.connect("purchase_updated", _on_updated)
	_w.connect("purchase_error", _on_error)


static func is_jws(s: String) -> bool:
	var parts := s.split(".")
	return parts.size() == 3 and not parts[0].is_empty() and not parts[1].is_empty() and not parts[2].is_empty()


static func norm_code(c: Variant) -> String:
	return str(c).to_lower().replace("-", "").replace("_", "").replace(" ", "")


## 플러그인의 구매 사전(OpenIAP Purchase JSON) → 이 어댑터의 모양
static func to_p(d: Dictionary) -> Dictionary:
	var tid := str(d.get("transactionId", d.get("id", "")))
	var tok := str(d.get("purchaseToken", ""))
	var st := str(d.get("purchaseState", "purchased")).to_lower()
	var state := "pending" if (st == "pending" or st == "0") else "purchased"
	var rev: Variant = d.get("revocationDateIOS")
	return {"transaction_id": tid, "product_id": str(d.get("productId", "")), "jws": tok if is_jws(tok) else "",
		"state": state, "revoked": rev != null and str(rev) != "" and float(rev if (rev is float or rev is int) else 1) != 0.0, "raw": d}


func _on_updated(d: Dictionary) -> void:
	purchase_updated.emit(to_p(d))


func _on_error(e: Dictionary) -> void:
	purchase_error.emit({"code": norm_code(e.get("code", "")), "message": str(e.get("message", e.get("error", ""))), "product_id": str(e.get("productId", ""))})


func init_connection() -> bool:
	if _w == null:
		return false
	return bool(await _w.call("init_connection"))


func fetch_products(spids: Array) -> Array:
	if _w == null:
		return []
	var T: GDScript = load(TYPES)
	var req: Variant = T.get("ProductRequest").new()
	var skus: Array[String] = []
	for s: Variant in spids:
		skus.append(str(s))
	req.set("skus", skus)
	req.set("type", T.get("ProductQueryType")["IN_APP"])
	var rows: Array = await _w.call("fetch_products", req)
	var out: Array = []
	for r: Variant in rows:
		if r is Object:
			var price := str(r.get("display_price"))
			if price != "":
				out.append({"spid": str(r.get("id")), "price": price, "currency": str(r.get("currency"))})
	return out


func request_purchase(spid: String, account_uuid: String) -> bool:
	if _w == null:
		return false
	var apple := {"sku": spid, "quantity": 1}
	if account_uuid != "":
		apple["appAccountToken"] = account_uuid
	# 결과는 purchase_updated / purchase_error 신호로 옴 (래퍼는 Apple 에서 'pending' 만 돌려줌)
	await _w.call("request_purchase", {"requestPurchase": {"apple": apple}, "type": "in-app"})
	return true


func pending_transactions() -> Array:
	if _w == null:
		return []
	var out: Array = []
	for p: Variant in await _w.call("get_pending_transactions_ios"):
		if p is Object and p.has_method("to_dict"):
			out.append(to_p(p.to_dict()))
	return out


func finish(raw: Dictionary) -> bool:
	if _w == null:
		return false
	var r: Variant = await _w.call("finish_transaction_dict", raw, true)
	return r is Object and bool(r.get("success"))
