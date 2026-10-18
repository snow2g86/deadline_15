extends RefCounted
## 데이터 원본(godot/data/**/*.json)의 정해진 모양(canonical) + manifest.json 만들기 + 기준(baseline) 잠금 — 화면 없는 정적 함수
##  CLI 는 tools/data_tool.gd, 시험(check_foundation)도 이 파일을 그대로 씀.
##
##  정해진 모양 (사람이 고치기 쉽고 diff 가 깔끔하게):
##   - 들여쓰기 2칸, 키 순서는 파일에 적힌 순서 그대로 (정렬하지 않음 — 원본 선언 순서 유지), 파일 끝 줄바꿈 하나
##   - 배열·사전을 한 줄로 썼을 때 (들여쓰기 + 키 + 값 + 쉼표) 가 WIDTH(100)자 이하면 한 줄, 넘으면 한 칸에 한 줄씩
##     한 줄 모양은 ", " · ": " 로 띄어 씀. 빈 배열·사전은 [] · {}
##   - 숫자는 JS String(number) 와 같은 가장 짧은 왕복 표기 (Num.fmt — 56.0 → 56, 0.1+0.2 → 0.30000000000000004)
##     읽기는 JsonExact(10진 → double 정확히) 라서 모양을 바꿔도 값은 비트 단위로 같음
##   - 문자열은 JS JSON.stringify 와 같은 이스케이프 (", \, 제어 문자만 — 한글·이모지는 그대로)
##  manifest.json: 파일별 전역 개수·값 개수·sha1, 특수값("Infinity" 문자열) 위치 — DataDB 가 읽을 때 검증에 씀 (손으로 고치지 말 것)

const JsonExact := preload("res://scripts/core/json_exact.gd")
const Num := preload("res://scripts/core/num.gd")

const WIDTH := 100
const IND := "  "
const MANIFEST := "manifest.json"
const DATA_DIR := "res://data/"
const BASELINE_DIR := "res://tests/baseline/data/"
const LOCK_FILE := "res://tests/baseline/LOCK.json"
## 잠그는 기준 파일 (golden · fixtures · 기준 데이터) — res:// 아래 폴더
const LOCK_DIRS := ["tests/golden/", "tests/fixtures/", "tests/baseline/data/"]
## 모듈 JSON 안에서 이 문자열 값은 특수 실수 (DataDB 가 INF·-INF·NAN 으로 되돌림)
const SPECIAL := ["Infinity", "-Infinity", "NaN"]


# ═══════════ 정해진 모양 ═══════════

## 정해진 모양 글. 쓸 수 없는 값(NaN·±무한 실수 — 예: 1e999 를 읽은 값)이 있으면 errors 에 경로를 더하고 그 자리에 null 을 씀
##  (errors 를 넘기지 않으면 버림 — 호출한 쪽이 errors 가 비었는지 꼭 확인할 것. run() 은 오류가 하나라도 있으면 아무 파일도 쓰지 않음)
static func canon(v: Variant, errors: Array = []) -> String:
	_errs = errors
	_path = []
	var out := _fmt(v, "", 0) + "\n"
	_errs = []
	return out


static var _errs: Array = []
static var _path: Array = []


static func _fmt(v: Variant, ind: String, prefix: int) -> String:
	var is_arr := v is Array
	var is_dict := v is Dictionary
	if not (is_arr or is_dict):
		return _scalar(v)
	if is_arr and (v as Array).is_empty():
		return "[]"
	if is_dict and (v as Dictionary).is_empty():
		return "{}"
	var budget := WIDTH - ind.length() - prefix - 1
	var one := _inline(v, budget)
	if one != "":
		return one
	var nxt := ind + IND
	var parts := PackedStringArray()
	if is_arr:
		for i in (v as Array).size():
			_path.append(i)
			parts.append(nxt + _fmt(v[i], nxt, 0))
			_path.pop_back()
		return "[\n" + ",\n".join(parts) + "\n" + ind + "]"
	for k: Variant in (v as Dictionary).keys():
		var key := JsonExact.quote(str(k)) + ": "
		_path.append(k)
		parts.append(nxt + key + _fmt(v[k], nxt, key.length()))
		_path.pop_back()
	return "{\n" + ",\n".join(parts) + "\n" + ind + "}"


## 한 줄 모양 (budget 자를 넘으면 "")
static func _inline(v: Variant, budget: int) -> String:
	if budget <= 0:
		return ""
	if v is Array:
		if (v as Array).is_empty():
			return "[]"
		var s := "["
		var first := true
		for x: Variant in v:
			var part := _inline(x, budget - s.length() - 1)
			if part == "":
				return ""
			s += ("" if first else ", ") + part
			first = false
			if s.length() > budget:
				return ""
		s += "]"
		return s if s.length() <= budget else ""
	if v is Dictionary:
		if (v as Dictionary).is_empty():
			return "{}"
		var s2 := "{"
		var first2 := true
		for k: Variant in (v as Dictionary).keys():
			var head := ("" if first2 else ", ") + JsonExact.quote(str(k)) + ": "
			var part2 := _inline(v[k], budget - s2.length() - head.length() - 1)
			if part2 == "":
				return ""
			s2 += head + part2
			first2 = false
			if s2.length() > budget:
				return ""
		s2 += "}"
		return s2 if s2.length() <= budget else ""
	if typeof(v) == TYPE_FLOAT and not is_finite(float(v)):
		return ""   # 한 줄로 쓰지 않고 _fmt 가 내려가 경로와 함께 오류를 남기게
	var sc := _scalar(v)
	return sc if sc.length() <= budget else ""


static func _path_str() -> String:
	var s := ""
	for p: Variant in _path:
		s += ("[%d]" % p) if typeof(p) == TYPE_INT else ("." + str(p))
	return s.trim_prefix(".") if s != "" else "(맨 위)"


static func _scalar(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			var f: float = v
			if not is_finite(f):
				_errs.append("%s: 쓸 수 없는 숫자 %s (JSON 에 없음 — 1e999 같은 너무 큰 값? 무한은 문자열 \"Infinity\" 로)" % [_path_str(), str(f)])
				return "null"
			return Num.fmt(f)
		TYPE_STRING, TYPE_STRING_NAME:
			return JsonExact.quote(String(v))
	return JsonExact.quote(str(v))


# ═══════════ 파일 ═══════════

## data 폴더의 JSON 목록 (manifest.json 빼고) → { "modules": [이름…], "lang": [코드…], "story": [코드…], "other": [경로…] }
static func list_files(dir: String) -> Dictionary:
	var out := {"modules": [], "lang": [], "story": [], "other": []}
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f == MANIFEST:
			continue
		if f.get_extension() == "json":
			out["modules"].append(f.get_basename())
		elif not f.ends_with(".md"):
			out["other"].append(f)
	for sub: String in d.get_directories():
		if sub != "lang" and sub != "story":
			out["other"].append(sub + "/")
			continue
		var sd := DirAccess.open(dir + sub)
		for f2: String in sd.get_files():
			if f2.get_extension() == "json":
				out[sub].append(f2.get_basename())
			else:
				out["other"].append(sub + "/" + f2)
		for sub2: String in sd.get_directories():
			out["other"].append(sub + "/" + sub2 + "/")
	for k: String in ["modules", "lang", "story"]:
		(out[k] as Array).sort()
	return out


static func read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


static func sha1_file(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA1)
	h.update(bytes)
	return h.finish().hex_encode()


static func sha1_text(text: String) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA1)
	h.update(text.to_utf8_buffer())
	return h.finish().hex_encode()


# ═══════════ 점검 · 다시 쓰기 ═══════════

## dir 의 모든 데이터 파일을 정해진 모양과 비교 (write 면 고쳐 씀) + manifest 다시 만들기
##  → { ok, errors: [..], changed: [바뀔(바뀐) 파일], files: n }
static func run(dir: String, write: bool) -> Dictionary:
	var res := {"ok": true, "errors": [], "changed": [], "files": 0}
	var files := list_files(dir)
	for o: String in files["other"]:
		res["errors"].append("모르는 파일·폴더: %s%s (data 에는 *.json · lang/*.json · story/*.json 만)" % [dir, o])
	var old_man: Variant = JsonExact.parse(read_text(dir + MANIFEST)) if FileAccess.file_exists(dir + MANIFEST) else null
	if not (old_man is Dictionary):
		old_man = {}
	var parsed := {}   # 상대 경로 → 값
	var texts := {}    # 상대 경로 → 정해진 모양 글
	var rels: Array = []
	for m: String in files["modules"]:
		rels.append(m + ".json")
	for l: String in files["lang"]:
		rels.append("lang/" + l + ".json")
	for s: String in files["story"]:
		rels.append("story/" + s + ".json")
	for rel: String in rels:
		var raw := read_text(dir + rel)
		var p: Array = JsonExact.parse_ex(raw)
		if not p[0]:
			res["errors"].append("%s: JSON 오류 %s" % [rel, p[2]])
			continue
		if not (p[1] is Dictionary):
			res["errors"].append("%s: 맨 위가 사전({})이 아님" % rel)
			continue
		if int(p[3]) != JsonExact.count_keys(p[1]):
			res["errors"].append("%s: 같은 사전에 같은 키가 두 번 (%s) — 뒤 값만 남고 앞 값이 사라지므로 하나로 정리하세요" % [rel, JsonExact.dup_key(raw)])
			continue
		parsed[rel] = p[1]
		var errs: Array = []
		var text := canon(p[1], errs)
		for e: String in errs:
			res["errors"].append("%s: %s" % [rel, e])
		texts[rel] = text
		res["files"] = int(res["files"]) + 1
		if text != raw:
			res["changed"].append(rel)
	# 오류가 하나라도 있으면 아무 파일도 쓰지 않음 (반쯤 고쳐 쓴 데이터가 남지 않게)
	if not (res["errors"] as Array).is_empty():
		res["ok"] = false
		res["changed"] = []
		return res
	var man := build_manifest(old_man, files, parsed, texts, res["errors"])
	if not (res["errors"] as Array).is_empty():
		res["ok"] = false
		res["changed"] = []
		return res
	if write:
		for rel2: String in res["changed"]:
			_write(dir + rel2, texts[rel2])
	var man_text := canon(man)
	var old_text := read_text(dir + MANIFEST) if FileAccess.file_exists(dir + MANIFEST) else ""
	if man_text != old_text:
		res["changed"].append(MANIFEST)
		if write:
			_write(dir + MANIFEST, man_text)
	res["ok"] = (res["errors"] as Array).is_empty() and (write or (res["changed"] as Array).is_empty())
	return res


static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## 순서: 예전 manifest 에 있던 순서를 지키고 새 이름은 뒤에 (가나다순)
static func _ordered(old_keys: Array, now: Array) -> Array:
	var out: Array = []
	for k: Variant in old_keys:
		if now.has(str(k)):
			out.append(str(k))
	for k2: Variant in now:
		if not out.has(k2):
			out.append(k2)
	return out


static func build_manifest(old_man: Dictionary, files: Dictionary, parsed: Dictionary, texts: Dictionary, errors: Array) -> Dictionary:
	var man := {
		"format": 2,
		"generator": "godot/tools/data_tool.gd",
		"note": "자동 생성 — 직접 고치지 말 것. 원본은 이 폴더의 *.json (고친 뒤 data_tool --write 로 모양 맞춤 + 이 파일 다시 만듦, README '데이터 원본')",
		"sources": {},
		"modules": {},
		"lang": {"langs": {}},
		"story": {},
		"special_values": [],
	}
	var specials: Array = []
	var gseen := {}
	for m: String in _ordered((old_man.get("modules", {}) as Dictionary).keys(), files["modules"]):
		var rel: String = m + ".json"
		var d: Dictionary = parsed[rel]
		var globals := {}
		for g: Variant in d.keys():
			globals[g] = _describe(d[g])
			if gseen.has(g):
				errors.append("전역 이름 %s 가 %s 와 %s 에 중복" % [g, gseen[g], rel])
			gseen[g] = rel
			_find_specials(d[g], rel, [g], specials)
		man["modules"][m] = {"file": rel, "globals": globals}
		man["sources"][m] = [{"file": rel, "sha1": sha1_text(texts[rel])}]
	var old_langs: Dictionary = (old_man.get("lang", {}) as Dictionary).get("langs", {})
	for l: String in _ordered(old_langs.keys(), files["lang"]):
		var rel2: String = "lang/" + l + ".json"
		var v: Dictionary = parsed[rel2]
		man["lang"]["langs"][l] = {"file": rel2, "type": "object", "count": v.size(), "leaves": _leaves(v), "sha1": sha1_text(texts[rel2])}
	for s: String in _ordered((old_man.get("story", {}) as Dictionary).keys(), files["story"]):
		var rel3: String = "story/" + s + ".json"
		var v3: Dictionary = parsed[rel3]
		var eps: Variant = v3.get("episodes", {})
		man["story"][s] = {"file": rel3, "type": "object", "count": v3.size(), "episodes": (eps as Dictionary).size() if eps is Dictionary else 0,
			"leaves": _leaves(v3), "sha1": sha1_text(texts[rel3])}
	man["special_values"] = specials
	return man


static func _describe(v: Variant) -> Dictionary:
	if v is Array:
		return {"type": "array", "count": (v as Array).size()}
	if v is Dictionary:
		return {"type": "object", "count": (v as Dictionary).size()}
	var t := "null"
	match typeof(v):
		TYPE_STRING:
			t = "string"
		TYPE_FLOAT, TYPE_INT:
			t = "number"
		TYPE_BOOL:
			t = "boolean"
	return {"type": t, "count": null}


static func _leaves(v: Variant) -> int:
	if v is Array:
		var n := 0
		for x: Variant in v:
			n += _leaves(x)
		return n
	if v is Dictionary:
		var n2 := 0
		for x2: Variant in (v as Dictionary).values():
			n2 += _leaves(x2)
		return n2
	return 1


static func _find_specials(v: Variant, rel: String, path: Array, out: Array) -> void:
	if v is Array:
		for i in (v as Array).size():
			_find_specials(v[i], rel, path + [i], out)
	elif v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			_find_specials(v[k], rel, path + [k], out)
	elif typeof(v) == TYPE_STRING and SPECIAL.has(v):
		out.append({"module": rel, "path": path, "value": v})


# ═══════════ 기준(baseline) 잠금 ═══════════
##  tests/golden · tests/fixtures · tests/baseline/data 는 2026-10-18 웹판에서 옮긴 시점의 정답으로 고정 (README '기준').
##  LOCK.json 에 파일마다 sha1 — 바꾸려면 절차(README)대로 다시 만들고 사람이 검토한 뒤 --relock.

static func lock_scan() -> Dictionary:
	var out := {}
	for sub: String in LOCK_DIRS:
		_scan("res://" + sub, sub, out)
	var keys := out.keys()
	keys.sort()
	var sorted := {}
	for k: String in keys:
		sorted[k] = out[k]
	return sorted


static func _scan(abs_dir: String, rel: String, out: Dictionary) -> void:
	var d := DirAccess.open(abs_dir)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".import") or f.ends_with(".uid") or f.ends_with(".md") or f == ".DS_Store":
			continue
		out[rel + f] = sha1_file(abs_dir + f)
	for sub: String in d.get_directories():
		_scan(abs_dir + sub + "/", rel + sub + "/", out)


## → { ok, errors: [..] }
static func lock_check() -> Dictionary:
	var res := {"ok": true, "errors": []}
	if not FileAccess.file_exists(LOCK_FILE):
		res["ok"] = false
		res["errors"].append("LOCK.json 없음 (%s)" % LOCK_FILE)
		return res
	var lk: Variant = JsonExact.parse(read_text(LOCK_FILE))
	var want: Dictionary = lk.get("files", {}) if lk is Dictionary else {}
	var now := lock_scan()
	for k: String in want.keys():
		if not now.has(k):
			res["errors"].append("기준 파일이 없어짐: %s" % k)
		elif str(now[k]) != str(want[k]):
			res["errors"].append("기준 파일이 바뀜: %s" % k)
	for k2: String in now.keys():
		if not want.has(k2):
			res["errors"].append("잠금에 없는 새 기준 파일: %s" % k2)
	res["ok"] = (res["errors"] as Array).is_empty()
	return res


static func lock_write(reason: String) -> void:
	var lk := {
		"note": "기준(golden · fixtures · baseline/data) 잠금 — 직접 고치지 말 것. 기준을 바꾸는 절차는 godot/README.md '기준을 다시 만들 때'. 바꾼 뒤 data_tool --relock \"이유\"",
		"reason": reason,
		"files": lock_scan(),
	}
	_write(LOCK_FILE, canon(lk))
