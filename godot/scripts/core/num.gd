class_name Num
extends RefCounted

## 표시용 숫자 — 웹 JS 의 String(number) 와 같은 표기 (ECMAScript Number::toString 규칙)
##  - 가장 짧은 왕복 표기: float(s) == f 가 되는 가장 적은 유효 숫자(1~17자리)
##  - 소수점 위치 n(10^(n-1) <= |f| < 10^n)이 -6 < n <= 21 이면 보통 표기 (56.0 → "56", 1e20 → "100000000000000000000", 0.000001)
##  - 그 밖(|f| >= 1e21 또는 0 < |f| < 1e-6)은 JS식 지수 표기 (1e+21, 1e-7, 1.7976931348623157e+308)
##  - -0 → "0", NaN → "NaN", ±INF → "Infinity" / "-Infinity"
##  (Godot str(56.0) 은 "56.0", str(0.1+0.2) 는 "0.3" 이라 화면 숫자에는 이것을 쓴다)

const NumParse := preload("res://scripts/core/num_parse.gd")


static func fmt(v: Variant) -> String:
	match typeof(v):
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return _fmt_float(v)
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
	return str(v)


static func _fmt_float(f: float) -> String:
	if is_nan(f):
		return "NaN"
	if is_inf(f):
		return "Infinity" if f > 0.0 else "-Infinity"
	if f == 0.0:
		return "0"
	var neg := f < 0.0
	# 가장 짧은 왕복 유효 숫자와 지수 얻기
	var digits_exp := _shortest(absf(f))
	var d: String = digits_exp[0]   # 유효 숫자 (앞뒤 0 없음)
	var n: int = digits_exp[1]      # 소수점 위치: 값 = 0.d × 10^n
	var k := d.length()
	var out: String
	if k <= n and n <= 21:
		out = d + "0".repeat(n - k)
	elif 0 < n and n <= 21:
		out = d.substr(0, n) + "." + d.substr(n)
	elif -6 < n and n <= 0:
		out = "0." + "0".repeat(-n) + d
	else:
		var e := n - 1
		var sign := "+" if e >= 0 else "-"
		out = (d if k == 1 else d.substr(0, 1) + "." + d.substr(1)) + "e" + sign + str(absi(e))
	return ("-" if neg else "") + out


## |f| > 0 의 가장 짧은 왕복 표기 → [유효 숫자 문자열, 소수점 위치 n]
## Godot 의 String.num_scientific 은 가장 짧은 왕복 유효 숫자(1~17자리)를 C 식 표기("1e-07", "0.035")로 낸다.
## 그 숫자·지수만 풀어서 JS 규칙으로 다시 배치한다.
## 단 num_scientific 은 16자리면 되는 값을 17자리로 쓰기도 해서(5091.9000000000005 ← JS 5091.900000000001),
## 15자리 이하로 정확히 왕복할 때만 그대로 쓰고 아니면 num_parse.gd 가 정확한 10진 전개로 가장 짧은 표기를 고른다.
## (왕복 확인에 String.to_float 를 쓰지 않는다 — Godot 의 문자열→실수 변환은 1.79e308·5e-324 같은 끝값에서
##  정확히 반올림되지 않아(1.7900000000000004e308, 0) 확인용으로 믿을 수 없다)
static func _shortest(a: float) -> Array:
	return NumParse.shortest(a, _parse_sci(String.num_scientific(a)))


## "1.2345e+17" / "0.035" / "1e-07" → [유효 숫자, n]
static func _parse_sci(s: String) -> Array:
	var mant := s
	var exp := 0
	var epos := s.findn("e")
	if epos >= 0:
		mant = s.substr(0, epos)
		exp = s.substr(epos + 1).to_int()
	var dot := mant.find(".")
	var int_part := mant if dot < 0 else mant.substr(0, dot)
	var frac := "" if dot < 0 else mant.substr(dot + 1)
	var all := int_part + frac
	var n := int_part.length() + exp
	# 앞의 0 제거 (0.035 → "35", n 조정)
	var lead := 0
	while lead < all.length() - 1 and all[lead] == "0":
		lead += 1
	all = all.substr(lead)
	n -= lead
	# 뒤의 0 제거
	var end := all.length()
	while end > 1 and all[end - 1] == "0":
		end -= 1
	return [all.substr(0, end), n]
