extends RefCounted
## JS 의미 그대로 계산하는 도우미 (웹 규칙 이식용) — 반올림·나눗셈·정렬·참거짓·깊은 복사를 한곳에 모음
##
##  - Math.round: .5 는 +∞ 쪽 (Math.round(-2.5) == -2). GDScript round() 는 0 에서 먼 쪽이라 쓰지 않는다
##  - Number.prototype.toFixed: 2진 실수의 정확한 10진 값 기준, 딱 절반이면 큰 쪽 (printf 의 짝수 반올림과 다름)
##  - Array.prototype.sort: 안정 정렬 (GDScript sort_custom 은 안정이 아님 → 원래 순서로 동점 처리)
##  - 참거짓: JS 는 [] · {} 가 참, Godot 은 빈 배열·사전이 거짓 → truthy() 로 판정
##  - 숫자는 JS 처럼 float 로 계산한다. 칸 좌표·유닛 번호(id·uid)만 int (README 참고)


## Math.round — floor(x + 0.5) 를 정확하게 (x - floor(x) 는 2^52 아래에서 정확)
static func round_js(x: float) -> float:
	if is_nan(x) or is_inf(x):
		return x
	var f := floorf(x)
	if x - f >= 0.5:
		f += 1.0
	return f


## Math.round 결과를 int 로 (좌표 등)
static func round_i(x: float) -> int:
	return int(round_js(x))


## Math.sign
static func sign_js(x: float) -> int:
	if x > 0.0:
		return 1
	if x < 0.0:
		return -1
	return 0


## +x.toFixed(f) (0 <= f <= 3) — 정확한 10진 값으로 반올림, 동점이면 큰 쪽 (ECMAScript 규정)
static func to_fixed_num(x: float, f: int) -> float:
	if is_nan(x) or is_inf(x):
		return x
	if x == 0.0:
		return 0.0
	var neg := x < 0.0
	var ax := absf(x)
	if ax >= 1e21:
		return x
	var p10 := 1
	for _i in f:
		p10 *= 10
	# ax = m × 2^e (m 은 53비트 정수)
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, ax)
	var bits := bytes.decode_s64(0)
	var exp_bits := (bits >> 52) & 0x7FF
	var mant := bits & 0xFFFFFFFFFFFFF
	var e: int
	if exp_bits == 0:
		e = -1074
	else:
		mant = mant | (1 << 52)
		e = exp_bits - 1075
	var n: int
	if e >= 0:
		return x   # 2^52 이상: 이미 정수
	else:
		var sh := -e
		var big := mant * p10            # < 2^53 × 1000 < 2^63
		if sh >= 63:
			n = 0
			# 반 이상인지: big × 2^-sh >= 0.5 ⇔ big >= 2^(sh-1) — sh-1 >= 62 면 big(< 2^63)과 비교
			if sh - 1 <= 62 and big >= (1 << (sh - 1)):
				n = 1
		else:
			n = big >> sh
			var rem := big - (n << sh)
			var half := 1 << (sh - 1)
			if rem >= half:
				n += 1
	var r := float(n) / float(p10)
	return -r if neg else r


## JS 참거짓 (undefined/null/false/0/NaN/"" 만 거짓, 배열·사전은 비어 있어도 참)
static func truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT:
			return v != 0
		TYPE_FLOAT:
			return v != 0.0 and not is_nan(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return String(v) != ""
	return true


## 숫자로 (undefined/null → 0) — JS 의 (v || 0) 과 같은 용도
static func num(v: Variant) -> float:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			var f: float = v
			return 0.0 if is_nan(f) else f
		TYPE_BOOL:
			return 1.0 if v else 0.0
	return 0.0


## 안정 정렬 (JS Array.prototype.sort 와 같은 결과). cmp(a, b) 는 JS 비교 함수처럼 음수/0/양수
static func stable_sort(arr: Array, cmp: Callable) -> Array:
	var idx: Array = []
	for i in arr.size():
		idx.append([arr[i], i])
	idx.sort_custom(func(p: Array, q: Array) -> bool:
		var c: float = cmp.call(p[0], q[0])
		if c != 0.0:
			return c < 0.0
		return int(p[1]) < int(q[1]))
	var out: Array = []
	for p: Array in idx:
		out.append(p[0])
	return out


## JSON.parse(JSON.stringify(v)) 와 같은 깊은 복사 (저장소 값 복사용)
static func deep(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var o: Dictionary = {}
			for k: Variant in d.keys():
				o[k] = deep(d[k])
			return o
		TYPE_ARRAY:
			var a: Array = v
			var o2: Array = []
			for x: Variant in a:
				o2.append(deep(x))
			return o2
	return v


## a == b 를 JS === 처럼 (숫자는 int/float 상관없이 값으로)
static func same(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return float(a) == float(b)
	if ta != tb:
		return false
	return a == b


## 배열에서 값 찾기 (JS indexOf, 숫자는 값으로)
static func index_of(arr: Array, v: Variant) -> int:
	for i in arr.size():
		if same(arr[i], v):
			return i
	return -1


## 칸 거리 (constants.js mh)
static func mh(a: int, b: int, c: int, d: int) -> int:
	return absi(a - c) + absi(b - d)


## Math.hypot(x, y)
static func hypot(x: float, y: float) -> float:
	return sqrt(x * x + y * y)


## 소수 n자리를 36진수로 흉내 (Math.random().toString(36) 의 값은 규칙에 안 쓰임 — 모양만)
static func base36(n: int) -> String:
	if n <= 0:
		return "0"
	var digits := "0123456789abcdefghijklmnopqrstuvwxyz"
	var s := ""
	while n > 0:
		s = digits[n % 36] + s
		n = n / 36
	return s
