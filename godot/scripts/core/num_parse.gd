extends RefCounted
## 실수 ↔ 10진 문자열을 정확하게 (다른 스크립트에 기대지 않음 — num.gd·json_exact.gd 가 씀)
##  parse_number(s): 10진 문자열 → 가장 가까운 double (동점은 짝수, JS Number() 와 같음). Godot String.to_float 는 이게 안 됨
##  exact_digits(x): 양수 double 의 정확한 10진 전개 → [유효 숫자 전부, n] (값 = 0.숫자 × 10^n)

static var _p10: Array = []   # 10^0 … 10^22 (모두 double 로 정확)


static func _init_static() -> void:
	if not _p10.is_empty():
		return
	_p10 = [1.0]
	for i in 22:
		_p10.append(_p10[i] * 10.0)


## 10진 숫자 문자열 → 가장 가까운 double (동점이면 짝수 쪽 — IEEE 기본, JS Number() 와 같음)
static func parse_number(s: String) -> float:
	_init_static()
	var i := 0
	var n := s.length()
	var neg := false
	if i < n and (s[i] == "-" or s[i] == "+"):
		neg = s[i] == "-"
		i += 1
	var digits := ""
	var frac_n := 0
	var seen_dot := false
	while i < n:
		var ch := s[i]
		if ch == ".":
			seen_dot = true
		elif ch >= "0" and ch <= "9":
			digits += ch
			if seen_dot:
				frac_n += 1
		else:
			break
		i += 1
	var exp10 := 0
	if i < n and (s[i] == "e" or s[i] == "E"):
		exp10 = s.substr(i + 1).to_int()
	exp10 -= frac_n
	# 앞뒤 0 정리
	var lead := 0
	while lead < digits.length() - 1 and digits[lead] == "0":
		lead += 1
	digits = digits.substr(lead)
	var tail := digits.length()
	while tail > 1 and digits[tail - 1] == "0":
		tail -= 1
	exp10 += digits.length() - tail
	digits = digits.substr(0, tail)
	if digits == "0" or digits == "":
		if neg:
			return _from_bits(-9223372036854775807 - 1)   # -0 (GDScript 의 -0.0 리터럴은 +0 이 되어 비트로 만듦)
		return 0.0
	var r: float
	# 빠른 길 (Clinger): 15자리 이하 정수 × 10^(±22 이내) 는 한 번의 곱셈·나눗셈이라 정확히 반올림됨
	if digits.length() <= 15 and exp10 >= -22 and exp10 <= 22:
		var m := float(digits.to_int())
		r = m * _p10[exp10] if exp10 >= 0 else m / _p10[-exp10]
	else:
		r = _slow(digits, exp10)
	return -r if neg else r


# ── 느린 길: 근사값에서 시작해 정수 크기 비교로 이웃 double 중 가장 가까운 것을 고름 ──
static func _slow(digits: String, exp10: int) -> float:
	if digits.length() + exp10 > 310:
		return INF
	if digits.length() + exp10 < -330:
		return 0.0
	# 근사값: 앞 18자리 정수 × 10^지수 (pow 로, 아주 작은 값은 두 번에 나눠 곱함 — 몇 ulp 안쪽)
	var head := digits.substr(0, 18)
	var e_adj := exp10 + digits.length() - head.length()
	var mf := float(head.to_int())
	var d: float
	if e_adj >= -290:
		d = mf * pow(10.0, float(e_adj))
	else:
		d = (mf * pow(10.0, float(e_adj + 290))) * pow(10.0, -290.0)
	if is_inf(d) or d > 1.7976931348623157e308:
		d = _from_bits(0x7FEFFFFFFFFFFFFF)
	if d <= 0.0:
		d = _from_bits(1)
	var M := _big_from_dec(digits)
	for _guard in 4096:
		var mb := _decompose(d)   # [m, e]: d = m × 2^e
		var m: int = mb[0]
		var e: int = mb[1]
		# 위쪽 중간점 (2m+1)·2^(e-1): 넘으면 위로, 같으면 짝수 쪽
		var cu := _cmp_dec_bin(M, exp10, 2 * m + 1, e - 1)
		if cu > 0:
			d = _next_up(d)
			if is_inf(d):
				return INF
			continue
		if cu == 0:
			return _next_up(d) if (m & 1) == 1 else d
		# 아래쪽 중간점 (2의 거듭제곱 경계면 아래 간격이 절반)
		var pow2 := m == (1 << 52) and e > -1074
		var cl: int = _cmp_dec_bin(M, exp10, 4 * m - 1, e - 2) if pow2 else _cmp_dec_bin(M, exp10, 2 * m - 1, e - 1)
		if cl < 0:
			var dn := _next_down(d)
			if dn <= 0.0:
				return 0.0
			d = dn
			continue
		if cl == 0:
			return _next_down(d) if (m & 1) == 1 else d
		return d
	return d


static func _bits(x: float) -> int:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	return b.decode_s64(0)


static func _from_bits(bits: int) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_s64(0, bits)
	return b.decode_double(0)


static func _next_up(x: float) -> float:
	return _from_bits(_bits(x) + 1)


static func _next_down(x: float) -> float:
	return _from_bits(_bits(x) - 1)


## 양수 x → [m, e] (x = m·2^e, 정규수면 m 은 53비트)
static func _decompose(x: float) -> Array:
	var bits := _bits(x)
	var eb := (bits >> 52) & 0x7FF
	var mant := bits & 0xFFFFFFFFFFFFF
	if eb == 0:
		return [mant, -1074]
	return [mant | (1 << 52), eb - 1075]


## sign(M·10^E − H·2^F)
static func _cmp_dec_bin(M: Array, E: int, H: int, F: int) -> int:
	var left := M.duplicate()
	var right := _big_from_int(H)
	if E >= 0:
		_big_mul_pow(left, 10, E)
	else:
		_big_mul_pow(right, 10, -E)
	if F >= 0:
		_big_mul_pow(right, 2, F)
	else:
		_big_mul_pow(left, 2, -F)
	return _big_cmp(left, right)


# ── 아주 작은 큰 정수 (2^24 진법 리틀 엔디언, 곱하기·비교만) ──
const LIMB := 16777216   # 2^24

static func _big_from_int(v: int) -> Array:
	var a: Array = []
	while v > 0:
		a.append(v % LIMB)
		v = v / LIMB
	if a.is_empty():
		a.append(0)
	return a


static func _big_from_dec(digits: String) -> Array:
	var a: Array = [0]
	var i := 0
	while i < digits.length():
		var chunk := digits.substr(i, 6)
		var mul := 1
		for _k in chunk.length():
			mul *= 10
		_big_mul_small(a, mul)
		_big_add_small(a, chunk.to_int())
		i += 6
	return a


static func _big_mul_small(a: Array, m: int) -> void:
	var carry := 0
	for i in a.size():
		var v: int = a[i] * m + carry
		a[i] = v % LIMB
		carry = v / LIMB
	while carry > 0:
		a.append(carry % LIMB)
		carry = carry / LIMB


static func _big_add_small(a: Array, v: int) -> void:
	var i := 0
	var carry := v
	while carry > 0:
		if i >= a.size():
			a.append(0)
		var s: int = a[i] + carry
		a[i] = s % LIMB
		carry = s / LIMB
		i += 1


static func _big_mul_pow(a: Array, base: int, e: int) -> void:
	if base == 2:
		var limbs := e / 24
		var rest := e % 24
		if limbs > 0:
			var pad: Array = []
			pad.resize(limbs)
			pad.fill(0)
			pad.append_array(a)
			a.clear()
			a.append_array(pad)
		if rest > 0:
			_big_mul_small(a, 1 << rest)
		return
	while e >= 7:
		_big_mul_small(a, 10000000)
		e -= 7
	var m := 1
	for _i in e:
		m *= 10
	if m > 1:
		_big_mul_small(a, m)


static func _big_cmp(a: Array, b: Array) -> int:
	var na := a.size()
	var nb := b.size()
	while na > 1 and a[na - 1] == 0:
		na -= 1
	while nb > 1 and b[nb - 1] == 0:
		nb -= 1
	if na != nb:
		return 1 if na > nb else -1
	for i in range(na - 1, -1, -1):
		if a[i] != b[i]:
			return 1 if a[i] > b[i] else -1
	return 0




static func _big_divmod_small(a: Array, dv: int) -> int:
	var rem := 0
	for i in range(a.size() - 1, -1, -1):
		var cur: int = rem * LIMB + a[i]
		a[i] = cur / dv
		rem = cur % dv
	while a.size() > 1 and a[a.size() - 1] == 0:
		a.pop_back()
	return rem


static func _big_is_zero(a: Array) -> bool:
	for v: int in a:
		if v != 0:
			return false
	return true


static func _big_to_dec(a: Array) -> String:
	var b := a.duplicate()
	var chunks := PackedStringArray()
	while not _big_is_zero(b):
		chunks.append("%06d" % _big_divmod_small(b, 1000000))
	if chunks.is_empty():
		return "0"
	chunks.reverse()
	var s := "".join(chunks)
	var i := 0
	while i < s.length() - 1 and s[i] == "0":
		i += 1
	return s.substr(i)


## 양수 double 의 정확한 10진 전개 → [유효 숫자(앞뒤 0 없음), n] (x = 0.숫자 × 10^n)
static func exact_digits(x: float) -> Array:
	var md := _decompose(x)
	var m: int = md[0]
	var e: int = md[1]
	var big := _big_from_int(m)
	var dec_shift := 0
	if e >= 0:
		_big_mul_pow(big, 2, e)
	else:
		# m / 2^k = m·5^k / 10^k
		var k := -e
		for _i in k / 12:
			_big_mul_small(big, 244140625)   # 5^12
		var r := 1
		for _j in k % 12:
			r *= 5
		if r > 1:
			_big_mul_small(big, r)
		dec_shift = -k
	var s := _big_to_dec(big)
	var n := s.length() + dec_shift
	var t := s.length()
	while t > 1 and s[t - 1] == "0":
		t -= 1
	return [s.substr(0, t), n]


## 가장 짧은 왕복 10진 표기 (ECMAScript Number::toString 의 숫자 고르기) → [유효 숫자, n]
##  hint: 빠른 후보 [숫자, n] (Godot num_scientific — 왕복은 하지만 가장 짧지 않거나 가장 가깝지 않을 수 있음)
##  1) 힌트가 정확히 왕복하면 한 자리씩 줄여 봄: 더 짧게 왕복하는 값은 힌트를 그 자릿수로 내림/올림한 둘 중 하나
##     (둘 다 x 의 반 ulp 안이라 힌트와의 차이가 그 자리 간격보다 훨씬 작음). 둘 다 되면 x 에 더 가까운 것(동점은 짝수)
##  2) 마지막 자릿수에서 반대편 이웃이 더 가까우면서 왕복하면 그쪽 (JS: 가장 가까운 것)
##  힌트가 왕복하지 않으면 정확한 10진 전개(exact_digits)로 1자리부터 찾음
static func shortest(x: float, hint: Array = []) -> Array:
	var md := _decompose(x)
	var cur: Array
	if not hint.is_empty() and parse_number(_sci(hint[0], hint[1])) == x:
		cur = [String(hint[0]), int(hint[1])]
	else:
		cur = _shortest_exact(x, md)
	while true:
		var D: String = cur[0]
		var n: int = cur[1]
		var L := D.length()
		if L <= 1:
			break
		var down := _strip(D.substr(0, L - 1))
		var up_n := [n]
		var up := _strip(_inc_digits(D.substr(0, L - 1), up_n))
		var ok_d := parse_number(_sci(down, n)) == x
		var ok_u := parse_number(_sci(up, up_n[0])) == x
		if not ok_d and not ok_u:
			break
		if ok_d and ok_u:
			cur = _closer(md, [down, n], [up, up_n[0]], D.substr(0, L - 1), n)
		else:
			cur = [down, n] if ok_d else [up, up_n[0]]
	# 같은 자릿수의 반대편 이웃 (15자리 이하는 자리 간격이 ulp 보다 커서 왕복하는 값이 하나뿐)
	var D2: String = cur[0]
	var n2: int = cur[1]
	if D2.length() <= 15:
		return cur
	var side := _cmp_dec_bin(_big_from_dec(D2), n2 - D2.length(), md[0], md[1])   # cur - x 의 부호
	if side == 0:
		return cur
	var alt: Array
	if side > 0:
		alt = _dec_digits(D2, n2)
		if alt.is_empty():
			return cur
	else:
		var an := [n2]
		alt = [_strip(_inc_digits(D2, an)), an[0]]
	if parse_number(_sci(alt[0], alt[1])) != x:
		return cur
	var lo: Array = alt if side > 0 else cur
	var hi: Array = cur if side > 0 else alt
	return _closer(md, lo, hi, _pad(lo[0], lo[1], D2.length(), n2), n2)


## lo < hi 인 같은 자릿수 이웃 둘 중 x 에 가까운 것 (동점은 마지막 숫자가 짝수인 쪽). lo_full = lo 를 그 자릿수로 쓴 숫자열
static func _closer(md: Array, lo: Array, hi: Array, lo_full: String, n: int) -> Array:
	var mid := lo_full + "5"
	var c := _cmp_dec_bin(_big_from_dec(mid), n - mid.length(), md[0], md[1])   # mid - x
	if c > 0:
		return lo
	if c < 0:
		return hi
	return lo if (int(lo_full[lo_full.length() - 1]) % 2) == 0 else hi


static func _strip(d: String) -> String:
	var t := d.length()
	while t > 1 and d[t - 1] == "0":
		t -= 1
	return d.substr(0, t)


## 숫자열 d(소수점 위치 n)를 len 자리(소수점 위치 n2)로 0 채움
static func _pad(d: String, n: int, ln: int, n2: int) -> String:
	var s := d
	if n < n2:
		s = "0".repeat(n2 - n) + s
	while s.length() < ln:
		s += "0"
	return s


## 숫자열 - 1 (마지막 자리) → [숫자, n] (0 이 되면 [])
static func _dec_digits(d: String, n: int) -> Array:
	var arr := d.to_utf8_buffer()
	var i := arr.size() - 1
	while i >= 0:
		if arr[i] == 48:
			arr[i] = 57
			i -= 1
		else:
			arr[i] -= 1
			break
	var s := arr.get_string_from_utf8()
	var lead := 0
	while lead < s.length() - 1 and s[lead] == "0":
		lead += 1
	if s.substr(lead) == "0":
		return []
	return [_strip(s.substr(lead)), n - lead]


static func _shortest_exact(x: float, md: Array) -> Array:
	var ex := exact_digits(x)
	var D: String = ex[0]
	var n: int = ex[1]
	for k in range(1, 18):
		if D.length() <= k:
			return [D, n]
		var down := D.substr(0, k)
		var up_n := [n]
		var up := _inc_digits(down, up_n)
		for cd: Array in [[_strip(down), n], [_strip(up), up_n[0]]]:
			if parse_number(_sci(cd[0], cd[1])) == x:
				return cd
	return [D, n]


static func _sci(digits: String, n: int) -> String:
	return "0." + digits + "e" + str(n)


## 10진 숫자 문자열 + 1 (999 → 1000 이면 자리 하나 늘고 n+1)
static func _inc_digits(d: String, n_ref: Array) -> String:
	var arr := d.to_utf8_buffer()
	var i := arr.size() - 1
	while i >= 0:
		if arr[i] == 57:
			arr[i] = 48
			i -= 1
		else:
			arr[i] += 1
			return arr.get_string_from_utf8()
	n_ref[0] = int(n_ref[0]) + 1
	return "1" + arr.get_string_from_utf8()
