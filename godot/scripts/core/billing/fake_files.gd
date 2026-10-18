extends RefCounted
## 가짜 가게·가짜 서버의 '바깥 세상' 상태 파일 (디버그 빌드 전용) — 게임 세이브와 따로 user://fake_iap/ 에 둔다.
##  진짜로는 가게(Google·Apple·STOVE)와 서버(D1)에 있는 것이라 게임 세이브를 지워도 남아야 하고, 앱이 죽었다 켜져도 남아야 한다.
##  매번 파일에서 읽고 바로 쓴다 (다른 프로세스가 이어받아 확인할 수 있게 — check_iap 의 앱 죽음 복구 시험).

const JsonExact := preload("res://scripts/core/json_exact.gd")
const DIR := "user://fake_iap/"
const STORE_FILE := DIR + "store.json"
const SERVER_FILE := DIR + "server.json"


static func read(path: String, fallback: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fallback.duplicate(true)
	var r: Array = JsonExact.parse_ex(FileAccess.get_file_as_string(path))
	if not r[0] or not (r[1] is Dictionary):
		return fallback.duplicate(true)
	return r[1]


static func write(path: String, d: Dictionary) -> bool:
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
	for p: String in [STORE_FILE, SERVER_FILE]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


static func sig(secret: String, oid: String, spid: String) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update((secret + "|" + oid + "|" + spid).to_utf8_buffer())
	return h.finish().hex_encode()
