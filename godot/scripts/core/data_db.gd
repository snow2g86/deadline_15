extends Node
## DataDB — 게임 데이터 (res://data/*.json) 창구
##
## (2026-10-18~) **res://data/**/*.json 이 수치·대본·번역의 원본**입니다 (웹 data/*.js 는 동결 — 더 읽지 않음).
##  손으로 고친 뒤 `Godot --headless --path godot --script res://tools/data_tool.gd -- --write` 로 모양을 맞추고 manifest.json 을 다시 만드세요.
## 읽을 때 manifest.json 의 전역별 개수·값 개수·sha1 과 맞춰 보고, 어긋나면 push_error 로 알린다
##  (sha1 이 다르면 = JSON 을 고치고 data_tool --write 를 잊음 → 전투 이어하기의 데이터 해시도 믿을 수 없으므로 오류).
## 시험은 use_dir() 로 고정된 기준 데이터(res://tests/baseline/data/)를 읽을 수 있다 (tests/baseline_data.gd).
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

## 지금 읽은 폴더 (기본 res://data/, 시험의 기준 데이터면 res://tests/baseline/data/)
var data_dir := DATA_DIR
## use_dir 로 기준 데이터를 읽었는지
var is_baseline := false
## 파일 sha1 이 manifest 와 다름(JSON 을 고치고 data_tool --write 를 잊음) — 이 실행에서는 전투 이어하기의 데이터 해시를 믿을 수 없으므로
##  resume_rules 가 저장 전투를 '이전 버전'으로 보냄. 디버그 빌드 로비는 경고를 띄움 (2026-10-18 검수)
var sha_mismatch := false
var manifest: Dictionary = {}
## 검증 중 생긴 오류 (비어 있으면 정상)
var errors: PackedStringArray = PackedStringArray()

var _modules: Dictionary = {}       # 모듈 이름 → { 전역 이름 → 값 }
var _global_index: Dictionary = {}  # 전역 이름 → 모듈 이름
var _langs: Dictionary = {}         # 언어 코드 → 사전
var _stories: Dictionary = {}       # ko/en/es/sample → 사전
var _loaded := false


func _ready() -> void:
	# 데이터 도구(tools/data_tool.gd)는 manifest 가 오래된 상태에서 돌기도 하므로 미리 읽지 않음 (오류 소리 없게)
	if OS.get_cmdline_args().has("res://tools/data_tool.gd"):
		return
	load_all()


## 다른 폴더의 데이터로 바꿔 다시 읽음 (시험용: 기준 데이터). overlay_lang 이면 그 폴더에 없는 번역 키만 지금 데이터(res://data/lang)에서 더함
##  — 기준 이후에 생긴 화면 글(gd.* 등)이 키 그대로 보이지 않게. 대본(story)은 기준 그대로.
func use_dir(dir: String, overlay_lang: bool = false) -> bool:
	data_dir = dir
	is_baseline = dir != DATA_DIR
	_loaded = false
	_modules = {}
	_global_index = {}
	_langs = {}
	_stories = {}
	manifest = {}
	var ok := load_all()
	if overlay_lang and dir != DATA_DIR:
		ok = _overlay_new_modules() and ok
		for code: String in _langs.keys():
			var p := DATA_DIR + "lang/%s.json" % code
			if FileAccess.file_exists(p):
				var live: Variant = JsonExact.parse(FileAccess.get_file_as_string(p))
				if live is Dictionary:
					_merge_missing(_langs[code], JsonNorm.normalize(live))
	return ok


## (결제층 A) 기준 뒤에 생긴 모듈(기준 manifest 에 없는 것 — 예: iap.json 의 IAP_PRODUCTS·AD_REWARD)은 지금 데이터에서 더함.
##  번역 덮어 읽기와 같은 원칙: 기준에 있는 것은 그대로, 기준에 없고 OVERLAY_MODULES 에 있는 것만 지금 데이터 (지금 manifest 의 sha1·개수로 검증).
##  기준 manifest(이어하기 데이터 해시의 재료)는 바꾸지 않음. 전역 이름이 기준 것과 겹치면 오류
## 덧붙여도 되는 모듈 (허용 목록 — 전투 규칙에 쓰이지 않는 것만)
const OVERLAY_MODULES := ["iap"]


func _overlay_new_modules() -> bool:
	var keep_dir := data_dir
	var keep_base := is_baseline
	var live_m: Variant = null
	data_dir = DATA_DIR
	is_baseline = false
	live_m = _read_json(MANIFEST_FILE)
	var ok := true
	if live_m is Dictionary:
		var mods: Dictionary = (live_m as Dictionary).get("modules", {})
		var specials: Array = (live_m as Dictionary).get("special_values", [])
		for mod_name: String in mods.keys():
			if _modules.has(mod_name) or not OVERLAY_MODULES.has(mod_name):
				continue
			var info: Dictionary = mods[mod_name]
			var file: String = info.get("file", mod_name + ".json")
			var srcs: Array = ((live_m as Dictionary).get("sources", {}) as Dictionary).get(mod_name, [])
			var data: Variant = _read_json(file, str((srcs[0] as Dictionary).get("sha1", "")) if not srcs.is_empty() and srcs[0] is Dictionary else "")
			if typeof(data) != TYPE_DICTIONARY:
				ok = false
				continue
			var dict: Dictionary = data
			_restore_specials(file, dict, specials)
			var globals: Dictionary = info.get("globals", {})
			for g: String in globals.keys():
				if not dict.has(g) or _global_index.has(g):
					_fail("%s: 덧붙일 전역 %s 가 없거나 기준과 겹칩니다" % [file, g])
					ok = false
					continue
				_verify(file + ":" + g, dict[g], globals[g])
				_global_index[g] = mod_name
			_modules[mod_name] = dict
	data_dir = keep_dir
	is_baseline = keep_base
	return ok


static func _merge_missing(dst: Dictionary, src: Dictionary) -> void:
	for k: Variant in src.keys():
		if not dst.has(k):
			dst[k] = src[k]
		elif dst[k] is Dictionary and src[k] is Dictionary:
			_merge_missing(dst[k], src[k])


## 모든 JSON 을 읽고 검증한다 (여러 번 불러도 한 번만 읽음). 성공 여부 반환
func load_all() -> bool:
	if _loaded:
		return errors.is_empty()
	_loaded = true
	errors.clear()
	sha_mismatch = false
	var m: Variant = _read_json(MANIFEST_FILE)
	if typeof(m) != TYPE_DICTIONARY:
		_fail("manifest.json 을 읽지 못했습니다 (%s) — tools/data_tool.gd -- --write 로 만드세요" % data_dir)
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
		var srcs: Array = (manifest.get("sources", {}) as Dictionary).get(mod_name, [])
		var data: Variant = _read_json(file, str((srcs[0] as Dictionary).get("sha1", "")) if not srcs.is_empty() and srcs[0] is Dictionary else "")
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
				_fail("%s: 전역 %s 가 manifest 에 없습니다 (data_tool --write 를 돌리세요)" % [file, g])
		_modules[mod_name] = dict


func _load_langs() -> void:
	var langs: Dictionary = manifest.get("lang", {}).get("langs", {})
	if langs.is_empty():
		_fail("manifest 에 언어 팩 정보가 없습니다")
	for code: String in langs.keys():
		var info: Dictionary = langs[code]
		var data: Variant = _read_json(String(info.get("file", "lang/%s.json" % code)), str(info.get("sha1", "")))
		if typeof(data) != TYPE_DICTIONARY:
			_fail("언어 팩 %s 를 읽지 못했습니다" % code)
			continue
		_verify("lang/" + code, data, info)
		_langs[code] = data


func _load_stories() -> void:
	var stories: Dictionary = manifest.get("story", {})
	for code: String in stories.keys():
		var info: Dictionary = stories[code]
		var data: Variant = _read_json(String(info.get("file", "story/%s.json" % code)), str(info.get("sha1", "")))
		if typeof(data) != TYPE_DICTIONARY:
			_fail("스토리 %s 를 읽지 못했습니다" % code)
			continue
		_verify("story/" + code, data, info)
		var eps: Dictionary = (data as Dictionary).get("episodes", {})
		if eps.size() != int(info.get("episodes", 0)):
			_fail("story/%s: 에피소드 %d개 (manifest %d개)" % [code, eps.size(), int(info.get("episodes", 0))])
		_stories[code] = data


## data 폴더에 manifest 에 없는 JSON 이 있으면 (새 파일을 넣고 data_tool --write 를 잊음 등) 알린다
func _check_unlisted_files() -> void:
	var listed: Dictionary = {MANIFEST_FILE: true}
	for mod_name: String in manifest.get("modules", {}).keys():
		listed[String(manifest["modules"][mod_name].get("file", ""))] = true
	for code: String in manifest.get("lang", {}).get("langs", {}).keys():
		listed[String(manifest["lang"]["langs"][code].get("file", ""))] = true
	for code: String in manifest.get("story", {}).keys():
		listed[String(manifest["story"][code].get("file", ""))] = true
	for rel: String in _list_json(""):
		if not listed.has(rel):
			_fail("manifest 에 없는 데이터 파일: %s" % rel)


func _list_json(sub: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(data_dir + sub)
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


func _read_json(rel: String, want_sha1: String = "") -> Variant:
	var path := data_dir + rel
	if not FileAccess.file_exists(path):
		_fail("파일 없음: %s" % path)
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if want_sha1 != "":
		var h := HashingContext.new()
		h.start(HashingContext.HASH_SHA1)
		h.update(bytes)
		if h.finish().hex_encode() != want_sha1:
			sha_mismatch = true
			if is_baseline:
				_fail("%s 가 기준 manifest 의 sha1 과 다릅니다 — 기준 데이터는 손으로 고치지 않습니다. git 으로 되돌리거나, 기준을 일부러 옮기려면 tools/data_tool.gd -- --rebase \"이유\" (godot/README.md '기준을 다시 만들 때')" % path)
			else:
				_fail("%s 가 manifest 의 sha1 과 다릅니다 — 고친 뒤 tools/data_tool.gd -- --write 를 돌리세요" % path)
	var text := bytes.get_string_from_utf8()
	var r := JsonExact.parse_ex(text)   # 실수를 정확히 (json_exact.gd)
	if not r[0]:
		_fail("%s JSON 오류 %s" % [path, r[2]])
		return null
	if int(r[3]) != JsonExact.count_keys(r[1]):
		_fail("%s: 같은 사전에 같은 키가 두 번 (%s) — 앞 값이 사라집니다. 하나로 정리한 뒤 data_tool --write" % [path, JsonExact.dup_key(text)])
	return JsonNorm.normalize(r[1])


func _fail(msg: String) -> void:
	errors.append(msg)
	push_error("DataDB: " + msg)
