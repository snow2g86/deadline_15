extends Node
## Store — 저장소 한 곳 (웹 js/common/store.js 와 같은 역할)
##
## 게임의 모든 저장 읽기·쓰기는 Store 를 거친다. 웹 localStorage 처럼 "키 → 문자열" 사전 하나이며,
## 키 이름도 웹과 같다 (game_save, game_roster, game_inventory, game_parties, game_soul, game_settings …).
## 그래서 웹 저장을 가져올 때는 localStorage 내용을 그대로 이 사전에 옮기면 된다 (import_web_dump 참고).
##
## 디스크: user://save.json = { "<키>": "<문자열>", ... } 한 파일.
##  - 지연 저장: 바꾸면 표시만 해 두고 프레임 끝에 한 번만 쓴다 (한 프레임에 여러 키를 바꿔도 쓰기 1회).
##    창 닫기·앱 일시정지·노드 제거·경로 변경 때는 남은 것을 반드시 쓴다. 바로 써야 하면 flush().
##  - 원자적 쓰기: save.json.tmp 에 쓴 뒤 rename 한 번으로 덮어쓴다 (지우고 바꾸는 사이에 꺼져도 저장이 사라지지 않게).
##  - 읽을 때 save.json 이 없고 .tmp 만 있으면(바꿔치기 직전에 꺼짐) .tmp 로 복구한다.
##
## 웹 API 대응 (Object.get/set 은 Godot 내장 메서드라 이름을 바꿈)
##   Store.get(k)          → get_str(k)            (없으면 null)
##   Store.set(k, v)       → set_str(k, v)         (성공 여부 bool)
##   Store.getJSON(k, fb)  → get_json(k, fb)
##   Store.setJSON(k, o)   → set_json(k, o)
##   Store.remove(k)       → remove(k)
##   Store.keys()          → keys()
##   Store.clear()         → clear()

signal changed(key: String)

const DEFAULT_PATH := "user://save.json"

## 저장 파일 경로 (시험에서는 다른 파일로 바꿔 진짜 저장을 건드리지 않는다)
var save_path: String = DEFAULT_PATH

const JsonNorm := preload("res://scripts/core/json_norm.gd")
const NumT := preload("res://scripts/core/num.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")

var _data: Dictionary = {}   # String → String
var _loaded_path: String = ""
var _dirty := false
var _flush_queued := false


func _ready() -> void:
	_ensure_loaded()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, \
		NOTIFICATION_EXIT_TREE, NOTIFICATION_PREDELETE:
			flush()


## 남은 변경을 지금 디스크에 쓴다 (없으면 아무것도 안 함). 성공 여부 반환
func flush() -> bool:
	_flush_queued = false
	if not _dirty or _loaded_path == "":
		return true
	_dirty = false
	return _write(_loaded_path)


## 저장 파일을 다른 경로로 바꾸고 그 파일을 다시 읽는다 (이전 경로에 남은 변경은 먼저 쓴다)
func use_path(path: String) -> void:
	flush()
	save_path = path
	_loaded_path = ""
	_ensure_loaded()


## 문자열 그대로 (없으면 null) — 웹 Store.get
func get_str(key: String) -> Variant:
	_ensure_loaded()
	return _data.get(key, null)


func has(key: String) -> bool:
	_ensure_loaded()
	return _data.has(key)


## 문자열로 저장 — 웹 Store.set. 디스크 쓰기는 프레임 끝 (실패는 push_error, 바로 확인하려면 flush())
func set_str(key: String, value: Variant) -> bool:
	_ensure_loaded()
	_data[key] = _js_string(value)
	_mark_dirty()
	changed.emit(key)
	return true


## JSON 으로 읽기 (없거나 깨졌으면 fallback) — 웹 Store.getJSON. 숫자는 float, 번호 성격 키(uid, lv …)만 int (json_norm.gd)
func get_json(key: String, fallback: Variant = null) -> Variant:
	var raw: Variant = get_str(key)
	if raw == null:
		return fallback
	var r := JsonExact.parse_ex(String(raw))   # 실수를 정확히 (Godot JSON 은 17자리 실수를 잘못 읽음)
	if not r[0]:
		return fallback
	return JsonNorm.normalize_store(key, r[1])


## JSON 으로 저장 — 웹 Store.setJSON
func set_json(key: String, value: Variant) -> bool:
	return set_str(key, JsonExact.stringify(value))


func remove(key: String) -> void:
	_ensure_loaded()
	if _data.erase(key):
		_mark_dirty()
		changed.emit(key)


func keys() -> PackedStringArray:
	_ensure_loaded()
	return PackedStringArray(_data.keys())


func clear() -> void:
	_ensure_loaded()
	_data.clear()
	_mark_dirty()
	changed.emit("")


## 웹 localStorage 덤프(JSON.stringify(localStorage) 결과 사전)를 그대로 가져온다.
## 옛 장비(gv 없음) 전환은 여기서 하지 않는다 — 웹처럼 규칙이 인벤토리를 처음 읽을 때(scripts/logic/profile.gd load_inventory) 난수를 써서 전환·저장.
## overwrite=false 면 이미 있는 키는 건드리지 않음. 가져온 키 개수 반환
func import_web_dump(dump: Dictionary, overwrite: bool = true) -> int:
	_ensure_loaded()
	var n := 0
	for k: Variant in dump.keys():
		var key := String(k)
		if not overwrite and _data.has(key):
			continue
		_data[key] = _js_string(dump[k])
		n += 1
	_mark_dirty()
	changed.emit("")
	return n


# ── 내부 ──

func _ensure_loaded() -> void:
	if _loaded_path == save_path:
		return
	_loaded_path = save_path
	_data = {}
	_dirty = false
	var tmp := save_path + ".tmp"
	if not FileAccess.file_exists(save_path):
		if not FileAccess.file_exists(tmp):
			return
		# 바꿔치기 직전에 꺼진 경우: .tmp 가 온전하면 그것으로 복구
		var tj := JsonExact.parse_ex(FileAccess.get_file_as_string(tmp))
		if tj[0] and typeof(tj[1]) == TYPE_DICTIONARY:
			push_warning("Store: %s 가 없어 %s 로 복구" % [save_path, tmp])
			DirAccess.rename_absolute(tmp, save_path)
		else:
			return
	var text := FileAccess.get_file_as_string(save_path)
	var pr := JsonExact.parse_ex(text)
	if not pr[0] or typeof(pr[1]) != TYPE_DICTIONARY:
		# 깨진 저장은 지우지 않고 옆에 남겨 둔다 (복구용)
		push_error("Store: %s 를 읽지 못했습니다 (%s) — .broken 으로 보관하고 빈 저장으로 시작" % [save_path, pr[2]])
		DirAccess.rename_absolute(save_path, save_path + ".broken")
		return
	var d: Dictionary = pr[1]
	for k: Variant in d.keys():
		_data[String(k)] = _js_string(d[k])


func _mark_dirty() -> void:
	_dirty = true
	if not _flush_queued:
		_flush_queued = true
		flush.call_deferred()


func _write(path: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Store: %s 에 쓸 수 없습니다 (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JsonExact.stringify(_data, "", true))
	f.flush()   # (4b-2) 이름 바꾸기 전에 디스크로 (Godot FileAccess 가 할 수 있는 만큼 — fsync 는 OS 몫)
	f.close()
	# rename 한 번으로 덮어쓰기 (먼저 지우지 않음 — 그 사이에 꺼지면 저장이 없어지므로)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("Store: %s 로 바꾸지 못했습니다 (%s)" % [path, error_string(err)])
		return false
	return true


## 웹 String(value) 와 같은 문자열화 (정수 값 실수는 "3" 처럼 소수점 없이, null 은 "null")
static func _js_string(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			return String(value)
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_FLOAT, TYPE_INT:
			return NumT.fmt(value)
		TYPE_DICTIONARY, TYPE_ARRAY:
			return JsonExact.stringify(value)
		_:
			return str(value)
