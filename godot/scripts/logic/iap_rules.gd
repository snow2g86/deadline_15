extends RefCounted
## 결제 지급 규칙 (결제층 A) — 화면 코드 없이 정적 함수, 첫 인자 c = ctx.gd (D · store)
##
##  상품: data/iap.json 의 IAP_PRODUCTS [{id, gold, label, krw, fallback_price, google, apple, stove_item}]
##   게임 안 id(gold_500 …) = Google 상품 id = STOVE 아이템 id, Apple 은 xyz.show4you.deadline15.gold_<양>.
##   양이나 가격이 바뀌면 새 id 를 만든다 (옛 id 는 지우지 않고 남겨 둬야 옛 주문의 환불·재처리가 됨).
##
##  저장 키 game_iap = {v:1, iid:"설치 식별자", orders:{"<store>:<order_id>": {pid, gold, at, st}}, rf:환불 조회 커서(서버가 준 글)}
##   st: "granted"(골드 지급·저장 끝, 가게/서버에 '처리 끝' 알림 전) → "done"(알림 끝) · "revoked"(환불 회수)
##   기록은 지우지 않는다 — 같은 주문이 다시 와도(앱이 죽었다 켜짐, 가게가 다시 알림) 두 번 주지 않는 근거이기 때문.
##   STOVE 는 소모(consume) API 가 없어 이 기록이 재지급 방지의 본체 → STOVE 클라우드 세이브에 game_iap 를 함께 올린다 (다음 작업).
##
##  grant  : 골드와 기록을 한 번에 (같은 Store 사전 → 같은 save.json 한 번의 쓰기). 이미 있는 주문이면 {dup:true}
##  revoke : 환불 회수 — 골드는 0 까지만 빼고 st='revoked'. 이미 회수했으면 무시. 모르는 주문이면 gold 0 으로 'revoked' 기록을 남겨
##           나중에 같은 주문이 '구매됨'으로 와도 지급하지 않음 (환불이 지급보다 먼저 알려진 경우)

const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")

const KEY := "game_iap"
const VERSION := 1
const STORES := ["stove", "steam", "google", "apple", "dev"]
const STATES := ["granted", "done", "revoked"]


static func products(c: Object) -> Array:
	var P: Variant = c.D.get("IAP_PRODUCTS")
	return P if P is Array else []


static func product(c: Object, pid: String) -> Variant:
	for p: Variant in products(c):
		if p is Dictionary and str(p.get("id")) == pid:
			return p
	return null


## 가게 쪽 상품 id (google·dev·stove = 게임 안 id, apple = 번들 접두사)
static func store_product_id(p: Dictionary, store: String) -> String:
	match store:
		"apple":
			return str(p.get("apple", p["id"]))
		"google":
			return str(p.get("google", p["id"]))
		"stove":
			return str(p.get("stove_item", p["id"]))
	return str(p["id"])


## 가게 쪽 상품 id → 게임 안 id (모르면 "")
static func pid_from_store(c: Object, store: String, spid: String) -> String:
	for p: Variant in products(c):
		if p is Dictionary and store_product_id(p, store) == spid:
			return str(p["id"])
	return ""


static func order_key(store: String, oid: String) -> String:
	return store + ":" + oid


static func empty() -> Dictionary:
	return {"v": VERSION, "orders": {}}


## 읽기 (없거나 이상하면 빈 것 — 이상한 값의 정리는 save_sanitize 가 먼저 함)
static func load_iap(c: Object) -> Dictionary:
	var d: Variant = c.store.get_json(KEY)
	if not (d is Dictionary) or not (d.get("orders") is Dictionary):
		return empty()
	return d


static func save_iap(c: Object, d: Dictionary) -> void:
	c.store.set_json(KEY, d)


static func order(c: Object, store: String, oid: String) -> Variant:
	return load_iap(c)["orders"].get(order_key(store, oid))


static func has_order(c: Object, store: String, oid: String) -> bool:
	return order(c, store, oid) != null


## 지급 (골드 + 기록 한 번에) → {ok:true, gold, total} | {dup:true, st} | {err:"product"|"order"}
static func grant(c: Object, store: String, oid: String, pid: String, now: float) -> Dictionary:
	if oid == "" or not STORES.has(store):
		return {"err": "order"}
	var p: Variant = product(c, pid)
	if p == null:
		return {"err": "product"}
	var d := load_iap(c)
	var k := order_key(store, oid)
	if (d["orders"] as Dictionary).has(k):
		return {"dup": true, "st": str(d["orders"][k].get("st", ""))}
	var gold := float(p["gold"])
	d["orders"][k] = {"pid": pid, "gold": gold, "at": now, "st": "granted"}
	if not d.has("v"):
		d["v"] = VERSION
	var total := Js.num(Profile.load_save(c).get("gold")) + gold   # 상점 골드 표시와 같은 읽기 (EquipRules.load_gold)
	Profile.save_gold(c, total)
	save_iap(c, d)
	return {"ok": true, "gold": gold, "total": total}


## 가게·서버에 '처리 끝'을 알린 뒤 (granted → done)
static func mark_done(c: Object, store: String, oid: String) -> bool:
	var d := load_iap(c)
	var k := order_key(store, oid)
	var o: Variant = d["orders"].get(k)
	if not (o is Dictionary) or str(o.get("st")) != "granted":
		return false
	o["st"] = "done"
	save_iap(c, d)
	return true


## 지급했지만 '처리 끝' 알림이 아직인 주문 [{store, oid, pid}]
static func unfinished(c: Object) -> Array:
	var out: Array = []
	var orders: Dictionary = load_iap(c)["orders"]
	for k: String in orders.keys():
		var o: Variant = orders[k]
		if o is Dictionary and str(o.get("st")) == "granted":
			var i := k.find(":")
			out.append({"store": k.substr(0, i), "oid": k.substr(i + 1), "pid": str(o.get("pid", ""))})
	return out


## 환불 회수 → {ok:true, taken, gold} | {ignored:"already"} | {ok:true, taken:0, unknown:true}
static func revoke(c: Object, store: String, oid: String, now: float, pid: String = "") -> Dictionary:
	if oid == "":
		return {"ignored": "order"}
	var d := load_iap(c)
	var k := order_key(store, oid)
	var o: Variant = d["orders"].get(k)
	if o is Dictionary and str(o.get("st")) == "revoked":
		return {"ignored": "already"}
	if not (o is Dictionary):
		# 모르는 주문 (지급 전에 환불이 먼저 알려짐) — 나중에 지급되지 않도록 기록만
		d["orders"][k] = {"pid": pid, "gold": 0.0, "at": now, "st": "revoked", "taken": 0.0, "rv": now}
		save_iap(c, d)
		return {"ok": true, "taken": 0.0, "unknown": true}
	var cur := Js.num(Profile.load_save(c).get("gold"))
	var take := minf(maxf(cur, 0.0), Js.num(o.get("gold")))
	Profile.save_gold(c, cur - take)
	o["st"] = "revoked"
	o["taken"] = take
	o["rv"] = now
	save_iap(c, d)
	return {"ok": true, "taken": take, "gold": cur - take}


## 설치 식별자 (처음 부를 때 만듦 — 서버에 보내는 무작위 값, 개인 정보 아님). gen: () -> 32자 16진수 (Billing 은 Crypto 16바이트)
static func install_id(c: Object, gen: Callable) -> String:
	var d := load_iap(c)
	var iid: Variant = d.get("iid")
	if is_iid(iid):
		return iid
	var s := str(gen.call()).to_lower()
	d["iid"] = s
	save_iap(c, d)
	return s


static func is_iid(v: Variant) -> bool:
	if typeof(v) != TYPE_STRING or (v as String).length() != 32:
		return false
	for ch: String in (v as String):
		if not "0123456789abcdef".contains(ch):
			return false
	return true


static func refund_cursor(c: Object) -> String:
	var v: Variant = load_iap(c).get("rf")
	return v if typeof(v) == TYPE_STRING else ""


static func set_refund_cursor(c: Object, cursor: String) -> void:
	var d := load_iap(c)
	if str(d.get("rf", "")) == cursor:
		return
	d["rf"] = cursor
	save_iap(c, d)


## 보관함 game_iap_bak = [{at, why, raw}] — 지우거나 고친 원본을 쌓아 둠 (덮어쓰지 않음, 최근 BAK_MAX 개)
const BAK_KEY := "game_iap_bak"
const BAK_MAX := 20


static func bak_list(c: Object) -> Array:
	var raw: Variant = c.store.get_str(BAK_KEY)
	if raw == null:
		return []
	var r: Array = JsonExact.parse_ex(str(raw))
	if r[0] and r[1] is Array:
		return r[1]
	return [{"at": 0.0, "why": "old_bak", "raw": str(raw)}]   # 예전 모양(글 하나)도 버리지 않고 첫 항목으로


static func bak_push(c: Object, why: String, raw: String, now: float) -> void:
	var L := bak_list(c)
	L.append({"at": now, "why": why, "raw": raw})
	while L.size() > BAK_MAX:
		L.pop_front()
	c.store.set_json(BAK_KEY, L)


## 깨진 글에서 읽을 수 있는 것만 건짐: iid · 환불 커서 · 주문 하나하나 ({…} 한 덩어리씩 읽어 형이 맞는 것만)
static func salvage(raw: String) -> Dictionary:
	var d := empty()
	var re := RegEx.new()
	re.compile("\"iid\"\\s*:\\s*\"([0-9a-f]{32})\"")
	var m := re.search(raw)
	if m != null:
		d["iid"] = m.get_string(1)
	re.compile("\"rf\"\\s*:\\s*\"([^\"\\\\]*)\"")
	m = re.search(raw)
	if m != null:
		d["rf"] = m.get_string(1)
	re.compile("\"([a-z]+:[^\"\\\\]+)\"\\s*:\\s*(\\{[^{}]*\\})")
	for mm: RegExMatch in re.search_all(raw):
		var r: Array = JsonExact.parse_ex(mm.get_string(2))
		if r[0] and r[1] is Dictionary and _order_ok(r[1]):
			d["orders"][mm.get_string(1)] = r[1]
	# 주문 번호는 보이는데 내용이 잘린 주문 — 이미 지급했던 주문이므로(기록이 있었음) '끝남' 표시로 남겨 다시 지급하지 않음 (재검수 7).
	#  가게가 미처리로 다시 주면 '이미 받은 주문' 길로 서버 consume · 가게 finish 만 함
	re.compile("\"([a-z]+:[^\"\\\\]+)\"\\s*:\\s*\\{")
	for mk: RegExMatch in re.search_all(raw):
		var key := mk.get_string(1)
		if not (d["orders"] as Dictionary).has(key):
			d["orders"][key] = {"pid": "", "gold": 0.0, "at": 0.0, "st": "done", "lost": true}
	return d


static func _order_ok(o: Dictionary) -> bool:
	return typeof(o.get("pid")) == TYPE_STRING and _is_num(o.get("gold")) and STATES.has(o.get("st"))


## 세이브 다듬기 (save_sanitize 가 부름) → 바꿨는지. 형이 틀린 항목만 빼고 기록 전체는 지우지 않음 — 뺀 것·깨진 원본은 game_iap_bak 에 쌓음.
##  정상 기록은 손대지 않음 (바이트 그대로)
static func sanitize_store(c: Object, now: float) -> bool:
	var raw: Variant = c.store.get_str(KEY)
	if raw == null:
		return false
	var pr: Array = JsonExact.parse_ex(str(raw))
	if not pr[0]:
		bak_push(c, "broken", str(raw), now)
		c.store.set_json(KEY, salvage(str(raw)))
		return true
	var v: Variant = c.store.get_json(KEY)
	if not (v is Dictionary):
		bak_push(c, "not_object", str(raw), now)
		c.store.set_json(KEY, empty())
		return true
	var d: Dictionary = v
	var removed := {}
	if not (d.get("orders") is Dictionary):
		removed["orders"] = d.get("orders")
		d["orders"] = {}
	if not d.has("v") or not _is_num(d["v"]):
		d["v"] = VERSION
	if d.has("iid") and not is_iid(d["iid"]):
		removed["iid"] = d["iid"]
		d.erase("iid")
	if d.has("rf") and typeof(d["rf"]) != TYPE_STRING:
		removed["rf"] = d["rf"]
		d.erase("rf")
	var orders: Dictionary = d["orders"]
	var bad_orders := {}
	for k: Variant in orders.keys():
		var o: Variant = orders[k]
		var ks := str(k)
		var i := ks.find(":")
		if typeof(k) != TYPE_STRING or i <= 0 or i >= ks.length() - 1 or not (o is Dictionary) or not _order_ok(o):
			bad_orders[ks] = o
			orders.erase(k)
			continue
		if o.has("at") and not _is_num(o["at"]):
			o["at"] = 0.0
	if not bad_orders.is_empty():
		removed["orders_removed"] = bad_orders
	var before := str(raw)
	var after := JsonExact.stringify(d)
	if after == before or JsonExact.stringify(c.store.get_json(KEY)) == after:
		return false
	if not removed.is_empty():
		bak_push(c, "bad_items", JsonExact.stringify(removed), now)
	c.store.set_json(KEY, d)
	return true


static func _is_num(v: Variant) -> bool:
	return (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and is_finite(float(v))
