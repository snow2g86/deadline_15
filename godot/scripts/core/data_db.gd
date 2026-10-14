extends Node
## DataDB — 웹 data/*.js 에서 변환한 게임 데이터 (res://data/*.json) 창구
##
## JSON 은 tools/export-godot-data.js 가 만든다 (웹 data/*.js 가 원본 — 여기 JSON 을 직접 고치지 말 것).
## 읽을 때 manifest.json 의 전역별 개수와 맞춰 보고, 어긋나면 push_error 로 알린다.
##
## 사용 예
##   DataDB.global("STAGES")             → Array (100개)
##   DataDB.module("hazards")["HAZARDS"] → Dictionary
##   DataDB.lang("en")                   → 번역 사전 (I18n 이 씀)
##   DataDB.story("ko")                  → 스토리 대본
##
## 숫자: JS 처럼 기본은 float (1 + exp_pct / 100 == 1.5 가 웹과 같게). 식별자·번호 성격의 키(id, uid, lv, x, y …)만
##  json_norm.gd 의 INT_KEYS 화이트리스트로 int 로 바꾼다 (stage.id 는 int 56). 화면 표시는 Num.fmt().
## Infinity 같은 특수값은 manifest.special_values 를 보고 INF / -INF / NAN 으로 되돌려 둔다 (예: TI.rock.cost == INF).

const DATA_DIR := "res://data/"
const MANIFEST_FILE := "manifest.json"
const JsonNorm := preload("res://scripts/core/json_norm.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")

var manifest: Dictionary = {}
## 검증 중 생긴 오류 (비어 있으면 정상)
var errors: PackedStringArray = PackedStringArray()

var _modules: Dictionary = {}       # 모듈 이름 → { 전역 이름 → 값 }
var _global_index: Dictionary = {}  # 전역 이름 → 모듈 이름
var _langs: Dictionary = {}         # 언어 코드 → 사전
var _stories: Dictionary = {}       # ko/en/es/sample → 사전
var _loaded := false


func _ready() -> void:
	load_all()


## 모든 JSON 을 읽고 검증한다 (여러 번 불러도 한 번만 읽음). 성공 여부 반환
func load_all() -> bool:
	if _loaded:
		return errors.is_empty()
	_loaded = true
	errors.clear()
	var m: Variant = _read_json(MANIFEST_FILE)
	if typeof(m) != TYPE_DICTIONARY:
		_fail("manifest.json 을 읽지 못했습니다 — node tools/export-godot-data.js 를 먼저 실행하세요")
		return false
	manifest = m
	_load_modules()
	_load_langs()
	_load_stories()
	_check_unlisted_files()
	return errors.is_empty()


func is_ok() -> bool:
	return _loaded and errors.is_empty()


func module_names() -> PackedStringArray:
	return PackedStringArray(_modules.keys())


func has_module(name: String) -> bool:
	return _modules.has(name)


## 모듈 하나 (stages, tiles …) — { 전역 이름 → 값 }
func module(name: String) -> Dictionary:
	if not _modules.has(name):
		push_error("DataDB: 모듈 '%s' 가 없습니다" % name)
		return {}
	return _modules[name]


func has_global(name: String) -> bool:
	return _global_index.has(name)


## 웹 전역 이름 그대로 (STAGES, HAZARDS, SAFE_ZONE …)
func global(name: String) -> Variant:
	if not _global_index.has(name):
		push_error("DataDB: 전역 '%s' 가 없습니다" % name)
		return null
	return _modules[_global_index[name]][name]


func global_names() -> PackedStringArray:
	return PackedStringArray(_global_index.keys())


func lang_codes() -> PackedStringArray:
	return PackedStringArray(_langs.keys())


func lang(code: String) -> Dictionary:
	return _langs.get(code, {})


func story(code: String) -> Dictionary:
	return _stories.get(code, {})


## 화면 표시·시험용 요약: 모듈 이름 → 전역 개수
func summary() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _modules.keys():
		out[name] = (_modules[name] as Dictionary).size()
	return out


# ── 읽기 ──

func _load_modules() -> void:
	var mods: Dictionary = manifest.get("modules", {})
	var specials: Array = manifest.get("special_values", [])
	for mod_name: String in mods.keys():
		var info: Dictionary = mods[mod_name]
		var file: String = info.get("file", mod_name + ".json")
		var data: Variant = _read_json(file)
		if typeof(data) != TYPE_DICTIONARY:
			_fail("%s 를 읽지 못했습니다" % file)
			continue
		var dict: Dictionary = data
		_restore_specials(file, dict, specials)
		var globals: Dictionary = info.get("globals", {})
		for g: String in globals.keys():
			if not dict.has(g):
				_fail("%s: manifest 에 있는 전역 %s 가 파일에 없습니다" % [file, g])
				continue
			_verify(file + ":" + g, dict[g], globals[g])
			if _global_index.has(g):
				_fail("전역 이름 %s 가 %s 와 %s 에 중복" % [g, _global_index[g], mod_name])
			_global_index[g] = mod_name
		for g: String in dict.keys():
			if not globals.has(g):
				_fail("%s: 전역 %s 가 manifest 에 없습니다 (변환을 다시 하세요)" % [file, g])
		_modules[mod_name] = dict


func _load_langs() -> void:
	var langs: Dictionary = manifest.get("lang", {}).get("langs", {})
	if langs.is_empty():
		_fail("manifest 에 언어 팩 정보가 없습니다")
	for code: String in langs.keys():
		var info: Dictionary = langs[code]
		var data: Variant = _read_json(String(info.get("file", "lang/%s.json" % code)))
		if typeof(data) != TYPE_DICTIONARY:
			_fail("언어 팩 %s 를 읽지 못했습니다" % code)
			continue
		_verify("lang/" + code, data, info)
		_langs[code] = data


func _load_stories() -> void:
	var stories: Dictionary = manifest.get("story", {})
	for code: String in stories.keys():
		var info: Dictionary = stories[code]
		var data: Variant = _read_json(String(info.get("file", "story/%s.json" % code)))
		if typeof(data) != TYPE_DICTIONARY:
			_fail("스토리 %s 를 읽지 못했습니다" % code)
			continue
		_verify("story/" + code, data, info)
		var eps: Dictionary = (data as Dictionary).get("episodes", {})
		if eps.size() != int(info.get("episodes", 0)):
			_fail("story/%s: 에피소드 %d개 (manifest %d개)" % [code, eps.size(), int(info.get("episodes", 0))])
		_stories[code] = data


## data 폴더에 manifest 에 없는 JSON 이 남아 있으면(옛 변환 결과 등) 알린다
func _check_unlisted_files() -> void:
	var listed: Dictionary = {MANIFEST_FILE: true}
	for mod_name: String in manifest.get("modules", {}).keys():
		listed[String(manifest["modules"][mod_name].get("file", ""))] = true
	for code: String in manifest.get("lang", {}).get("langs", {}).keys():
		listed[String(manifest["lang"]["langs"][code].get("file", ""))] = true
	for code: String in manifest.get("story", {}).keys():
		listed[String(manifest["story"][code].get("file", ""))] = true
	for rel: String in _list_json(""):
		# lang_extra/ 는 변환기 결과가 아니라 Godot 전용 번역 키 (I18n 이 직접 읽음)
		if not listed.has(rel) and not rel.begins_with("lang_extra/"):
			_fail("manifest 에 없는 데이터 파일: %s" % rel)


func _list_json(sub: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(DATA_DIR + sub)
	if dir == null:
		return out
	for f: String in dir.get_files():
		if f.get_extension() == "json":
			out.append(sub + f)
	for d: String in dir.get_directories():
		out.append_array(_list_json(sub + d + "/"))
	return out


# ── 검증 ──

func _verify(label: String, value: Variant, info: Dictionary) -> void:
	var want_type: String = info.get("type", "")
	var got_type := _type_name(value)
	if want_type != "" and want_type != got_type:
		_fail("%s: 종류 %s (manifest %s)" % [label, got_type, want_type])
		return
	var want_count: Variant = info.get("count", null)
	if want_count != null:
		var got := _size_of(value)
		if got != int(want_count):
			_fail("%s: 개수 %d (manifest %d)" % [label, got, int(want_count)])
	if info.has("leaves"):
		var leaves := _count_leaves(value)
		if leaves != int(info["leaves"]):
			_fail("%s: 값 %d개 (manifest %d개)" % [label, leaves, int(info["leaves"])])


static func _type_name(v: Variant) -> String:
	match typeof(v):
		TYPE_ARRAY:
			return "array"
		TYPE_DICTIONARY:
			return "object"
		TYPE_STRING:
			return "string"
		TYPE_FLOAT, TYPE_INT:
			return "number"
		TYPE_BOOL:
			return "boolean"
		TYPE_NIL:
			return "null"
	return "unknown"


static func _size_of(v: Variant) -> int:
	if v is Array:
		return (v as Array).size()
	if v is Dictionary:
		return (v as Dictionary).size()
	return -1


static func _count_leaves(v: Variant) -> int:
	if v is Array:
		var n := 0
		for x: Variant in v:
			n += _count_leaves(x)
		return n
	if v is Dictionary:
		var n := 0
		for x: Variant in (v as Dictionary).values():
			n += _count_leaves(x)
		return n
	return 1


## manifest.special_values: [{ module, path: [전역, 키 또는 번호…], value: "Infinity" }]
func _restore_specials(file: String, dict: Dictionary, specials: Array) -> void:
	for s: Variant in specials:
		var sv: Dictionary = s
		if String(sv.get("module", "")) != file:
			continue
		var p: Array = sv.get("path", [])
		var real: float
		match String(sv.get("value", "")):
			"Infinity":
				real = INF
			"-Infinity":
				real = -INF
			"NaN":
				real = NAN
			_:
				_fail("%s: 모르는 특수값 %s" % [file, sv.get("value")])
				continue
		var node: Variant = dict
		for i in range(p.size() - 1):
			node = _step(node, p[i])
		var last: Variant = p[p.size() - 1]
		if node is Dictionary and (node as Dictionary).has(String(last)):
			(node as Dictionary)[String(last)] = real
		elif node is Array and (typeof(last) == TYPE_INT or typeof(last) == TYPE_FLOAT) and int(last) < (node as Array).size():
			(node as Array)[int(last)] = real
		else:
			_fail("%s: 특수값 경로 %s 를 찾지 못함" % [file, str(p)])


static func _step(node: Variant, key: Variant) -> Variant:
	if node is Dictionary:
		return (node as Dictionary).get(String(key))
	if node is Array and (typeof(key) == TYPE_INT or typeof(key) == TYPE_FLOAT):
		var arr: Array = node
		var i := int(key)
		return arr[i] if i < arr.size() else null
	return null


func _read_json(rel: String) -> Variant:
	var path := DATA_DIR + rel
	if not FileAccess.file_exists(path):
		_fail("파일 없음: %s" % path)
		return null
	var r := JsonExact.parse_ex(FileAccess.get_file_as_string(path))   # 실수를 정확히 (json_exact.gd)
	if not r[0]:
		_fail("%s JSON 오류 %s" % [path, r[2]])
		return null
	return JsonNorm.normalize(r[1])


func _fail(msg: String) -> void:
	errors.append(msg)
	push_error("DataDB: " + msg)
