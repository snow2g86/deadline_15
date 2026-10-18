extends RefCounted
## 가짜 가게·가짜 서버의 '바깥 세상' 상태 파일 (디버그 빌드 전용) — 게임 세이브와 따로 user://fake_iap/ 에 둔다.
##  진짜로는 가게(Google·Apple·STOVE)와 서버(D1)에 있는 것이라 게임 세이브를 지워도 남아야 하고, 앱이 죽었다 켜져도 남아야 한다.
##  매번 파일에서 읽고 바로 쓴다 (다른 프로세스가 이어받아 확인할 수 있게 — check_iap 의 앱 죽음 복구 시험).

const JsonExact := preload("res://scripts/core/json_exact.gd")
const DevRemote := preload("res://scripts/core/billing/dev_remote.gd")
const DIR := "user://fake_iap/"
const STORE_FILE := DIR + "store.json"
const SERVER_FILE := DIR + "server.json"

## (결제층 B) 로컬 결제 확인 서버 주소 — 비어 있지 않으면 (디버그 빌드 · dev 가게 · iap.json 의 local 처럼 http 주소일 때 Billing 이 넣음)
##  가게 장부(STORE_FILE)는 파일에 쓰고 서버의 /v1/dev/ledger 에도 비춤, 서버 상태(SERVER_FILE)는 파일 대신 서버의 /v1/dev/state 를 읽고 씀.
##  가짜 서버(fake_server.gd)를 쓰는 dev(fake://) 에서는 비어 있어 예전과 같음.
static var remote := ""


static func read(path: String, fallback: Dictionary) -> Dictionary:
	if remote != "" and path == SERVER_FILE:
		var rr := DevRemote.request(remote, "GET", "/v1/dev/state")
		if int(rr["status"]) != 200 or not ((rr["body"] as Dictionary).get("orders") is Dictionary):
			push_error("fake_files: local IAP server did not answer /v1/dev/state (%d)" % int(rr["status"]))
			return fallback.duplicate(true)
		return {"orders": rr["body"]["orders"]}
	if not FileAccess.file_exists(path):
		return fallback.duplicate(true)
	var r: Array = JsonExact.parse_ex(FileAccess.get_file_as_string(path))
	if not r[0] or not (r[1] is Dictionary):
		return fallback.duplicate(true)
	return r[1]


static func write(path: String, d: Dictionary) -> bool:
	if remote != "" and path == SERVER_FILE:
		return _push("PUT", "/v1/dev/state", {"orders": d.get("orders", {})})
	if remote != "" and path == STORE_FILE and not _push("PUT", "/v1/dev/ledger", {"orders": d.get("orders", {})}):
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JsonExact.stringify(d))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


## 시험용: 가짜 가게·서버 상태를 모두 지움
static func reset() -> void:
	if remote != "":
		_push("POST", "/v1/dev/reset", {})
	for p: String in [STORE_FILE, SERVER_FILE]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


static func sig(secret: String, oid: String, spid: String) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update((secret + "|" + oid + "|" + spid).to_utf8_buffer())
	return h.finish().hex_encode()


static func _push(method: String, path: String, body: Dictionary) -> bool:
	var r := DevRemote.request(remote, method, path, {}, body)
	if int(r["status"]) != 200:
		push_error("fake_files: local IAP server refused %s %s (%d)" % [method, path, int(r["status"])])
		return false
	return true
