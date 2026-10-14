extends RefCounted
## 숫자를 정확히 다루는 JSON — Godot 내장 JSON 은 실수를 정확히 읽고 쓰지 못한다
##   JSON.parse_string("1.3599999999999999") → 1.36 (String.to_float·str_to_var 도 같음, 무작위 실수 약 14% 왕복 실패)
##   JSON.stringify(x) 도 기본 정밀도라 자리수를 잃음
##  → 쓰기: 실수는 Num.fmt (JS String(number) 와 같은 가장 짧은 왕복 표기), 읽기: 10진 문자열 → 가장 가까운 double 을 정확히.
##  웹(JS)이 쓴 JSON 과 비트 단위로 같은 값을 주고받는다. Store·DataDB·시험·전투 저장이 모두 이것을 쓴다.
##
##  parse(text)        → Variant (실패하면 null) — 숫자는 float (Godot JSON 과 같은 모델), 정확히 반올림
##  parse_ex(text)     → [ok: bool, value, 오류 메시지]
##  stringify(v, indent = "", sort_keys = false) → String
##  parse_number(s)    → float (JSON 숫자 문자열 하나)

const Num := preload("res://scripts/core/num.gd")
const NumParse := preload("res://scripts/core/num_parse.gd")

const MARK := "\u0001"   # 숫자를 잠시 문자열로 바꿔 둘 때의 표시 (JSON 문자열 안에 원래 나올 수 없는 제어 문자)

static var _re: RegEx = null


static func _init_static() -> void:
	if _re != null:
		return
	_re = RegEx.new()
	# 문자열 토큰(건너뜀) 또는 숫자 토큰
	_re.compile("\"(?:[^\"\\\\]|\\\\.)*\"|-?(?:0|[1-9][0-9]*)(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?")


# ═══════════ 읽기 ═══════════

static func parse(text: String) -> Variant:
	var r := parse_ex(text)
	return r[1] if r[0] else null


static func parse_ex(text: String) -> Array:
	_init_static()
	# Godot 파서가 정확히 읽지 못하는 숫자(소수점·지수가 있거나 15자리 넘는 정수)를 표시 문자열로 바꿔 두고, 다 읽은 뒤 정확히 변환
	var parts := PackedStringArray()
	var last := 0
	var changed := false
	for m: RegExMatch in _re.search_all(text):
		var tok := m.get_string()
		if tok.unicode_at(0) == 34:   # '"'
			continue
		if not _needs_exact(tok):
			continue
		parts.append(text.substr(last, m.get_start() - last))
		parts.append("\"\\u0001" + tok + "\"")
		last = m.get_end()
		changed = true
	var src := text
	if changed:
		parts.append(text.substr(last))
		src = "".join(parts)
	var json := JSON.new()
	if json.parse(src) != OK:
		return [false, null, "%d행: %s" % [json.get_error_line(), json.get_error_message()]]
	var v: Variant = json.data
	if changed:
		v = _restore(v)
	return [true, v, ""]


static func _needs_exact(tok: String) -> bool:
	if tok.contains(".") or tok.contains("e") or tok.contains("E"):
		return true
	var digits := tok.length() - (1 if tok.begins_with("-") else 0)
	return digits > 15


static func _restore(v: Variant) -> Variant:
	match typeof(v):
		TYPE_STRING:
			var s: String = v
			if s.length() > 0 and s.unicode_at(0) == 1:
				return parse_number(s.substr(1))
			return s
		TYPE_ARRAY:
			var a: Array = v
			for i in a.size():
				var t := typeof(a[i])
				if t == TYPE_STRING or t == TYPE_ARRAY or t == TYPE_DICTIONARY:
					a[i] = _restore(a[i])
			return a
		TYPE_DICTIONARY:
			var d: Dictionary = v
			for k: Variant in d.keys():
				var t2 := typeof(d[k])
				if t2 == TYPE_STRING or t2 == TYPE_ARRAY or t2 == TYPE_DICTIONARY:
					d[k] = _restore(d[k])
			return d
	return v


## 10진 숫자 문자열 → 가장 가까운 double (num_parse.gd)
static func parse_number(s: String) -> float:
	return NumParse.parse_number(s)


# ═══════════ 쓰기 ═══════════

## JSON.stringify 와 같은 결과 (실수는 JS 처럼 가장 짧은 왕복 표기, NaN·INF → null, 사전은 삽입 순서)
static func stringify(v: Variant, indent: String = "", sort_keys: bool = false) -> String:
	var out := PackedStringArray()
	_write(v, out, indent, sort_keys, "")
	return "".join(out)


static func _write(v: Variant, out: PackedStringArray, indent: String, sort_keys: bool, cur: String) -> void:
	match typeof(v):
		TYPE_NIL:
			out.append("null")
		TYPE_BOOL:
			out.append("true" if v else "false")
		TYPE_INT:
			out.append(str(v))
		TYPE_FLOAT:
			var f: float = v
			out.append("null" if (is_nan(f) or is_inf(f)) else Num.fmt(f))
		TYPE_STRING, TYPE_STRING_NAME:
			out.append(quote(String(v)))
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var a: Array = Array(v)
			if a.is_empty():
				out.append("[]")
				return
			var nxt := cur + indent
			out.append("[")
			for i in a.size():
				if i > 0:
					out.append(",")
				if indent != "":
					out.append("\n" + nxt)
				_write(a[i], out, indent, sort_keys, nxt)
			if indent != "":
				out.append("\n" + cur)
			out.append("]")
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if d.is_empty():
				out.append("{}")
				return
			var keys: Array = d.keys()
			if sort_keys:
				keys.sort_custom(func(x: Variant, y: Variant) -> bool: return str(x) < str(y))
			var nxt2 := cur + indent
			out.append("{")
			var first := true
			for k: Variant in keys:
				if not first:
					out.append(",")
				first = false
				if indent != "":
					out.append("\n" + nxt2)
				out.append(quote(str(k)))
				out.append(":" if indent == "" else ": ")
				_write(d[k], out, indent, sort_keys, nxt2)
			if indent != "":
				out.append("\n" + cur)
			out.append("}")
		_:
			out.append(quote(str(v)))


## JSON 문자열 따옴표 (JS JSON.stringify 와 같은 이스케이프)
static func quote(s: String) -> String:
	var needs := false
	for i in s.length():
		var c := s.unicode_at(i)
		if c < 32 or c == 34 or c == 92:
			needs = true
			break
	if not needs:
		return "\"" + s + "\""
	var out := PackedStringArray(["\""])
	for i2 in s.length():
		var c2 := s.unicode_at(i2)
		match c2:
			34:
				out.append("\\\"")
			92:
				out.append("\\\\")
			8:
				out.append("\\b")
			12:
				out.append("\\f")
			10:
				out.append("\\n")
			13:
				out.append("\\r")
			9:
				out.append("\\t")
			_:
				if c2 < 32:
					out.append("\\u%04x" % c2)
				else:
					out.append(s[i2])
	out.append("\"")
	return "".join(out)
