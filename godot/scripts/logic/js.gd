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


## 출처: V8 (https://chromium.googlesource.com/v8/v8) third_party/v8/builtins/array-sort.tq — Copyright 2018 the V8 project authors.
##  BSD-3-Clause 라이선스 (전문은 라이선스 화면 scripts/ui/licenses.gd V8_LICENSE). 이 함수와 _V8Sort 는 그 코드를 GDScript 로 옮긴 것.
## (4b-1·4b-2) V8 Array.prototype.sort 와 같은 비교 호출 순서·결과 — V8 third_party/v8/builtins/array-sort.tq 의 TimSort 를 줄 단위로 옮김
##  (run 세기 + 이진 삽입, 64개 이상은 최소 run 길이 · run 쌓기 · MergeCollapse · 질주(gallop)하는 MergeLow/MergeHigh · MergeForceCollapse).
##  웹의 `.sort(function() { return Math.random() - 0.5; })` 처럼 비교 함수가 난수를 쓰는 곳을 같은 씨앗으로 같은 순서로 재현할 때 씀.
##  비교 함수가 일관되지 않아도(난수) V8 처럼 '길이 0' 경우를 따로 처리해 배열 밖을 읽지 않고, 늘 같은 입력·같은 난수면 같은 결과.
##  비교 결과 NaN 은 0 (V8 ToNumber 후 비교와 같음). tests/check_outer_4b2.gd 가 node(V8)가 낸 정답과 64~700개로 비교.
static func v8_sort(arr: Array, cmp: Callable) -> Array:
	var st := _V8Sort.new()
	st.w = arr.duplicate()
	st.cmp = cmp
	st.run()
	return st.w


class _V8Sort:
	const MIN_GALLOP := 7
	var w: Array
	var cmp: Callable
	var min_gallop := MIN_GALLOP
	var runs: Array = []   # [[base, len], …]

	func _c(a: Variant, b: Variant) -> float:
		var o: Variant = cmp.call(a, b)
		var f := float(o) if (typeof(o) == TYPE_FLOAT or typeof(o) == TYPE_INT) else 0.0
		return 0.0 if is_nan(f) else f

	static func min_run_length(n0: int) -> int:
		var n := n0
		var r := 0
		while n >= 64:
			r |= n & 1
			n >>= 1
		return n + r

	func run() -> void:
		var length := w.size()
		if length < 2:
			return
		var remaining := length
		var low := 0
		var min_run := min_run_length(remaining)
		while remaining != 0:
			var cur := count_and_make_run(low, low + remaining)
			if cur < min_run:
				var forced := mini(min_run, remaining)
				binary_insertion_sort(low, low + cur, low + forced)
				cur = forced
			runs.append([low, cur])
			merge_collapse()
			low += cur
			remaining -= cur
		merge_force_collapse()

	func count_and_make_run(lo: int, hi: int) -> int:
		var low := lo + 1
		if low == hi:
			return 1
		var run_len := 2
		var el_low: Variant = w[low]
		var el_low_pre: Variant = w[low - 1]
		var order := _c(el_low, el_low_pre)
		var desc := order < 0.0
		var prev: Variant = el_low
		for idx in range(low + 1, hi):
			var cur: Variant = w[idx]
			order = _c(cur, prev)
			if desc:
				if order >= 0.0:
					break
			elif order < 0.0:
				break
			prev = cur
			run_len += 1
		if desc:
			var l := lo
			var h := lo + run_len - 1
			while l < h:
				var t: Variant = w[l]
				w[l] = w[h]
				w[h] = t
				l += 1
				h -= 1
		return run_len

	func binary_insertion_sort(lo: int, start0: int, hi: int) -> void:
		var start := start0
		if lo == start:
			start += 1
		while start < hi:
			var left := lo
			var right := start
			var pivot: Variant = w[start]
			while left < right:
				var mid := left + ((right - left) >> 1)
				if _c(pivot, w[mid]) < 0.0:
					right = mid
				else:
					left = mid + 1
			var p := start
			while p > left:
				w[p] = w[p - 1]
				p -= 1
			w[left] = pivot
			start += 1

	func _len(i: int) -> int:
		return int(runs[i][1])

	func _invariant(n: int) -> bool:
		if n < 2:
			return true
		return _len(n - 2) > _len(n - 1) + _len(n)

	func merge_collapse() -> void:
		while runs.size() > 1:
			var n := runs.size() - 2
			if not _invariant(n + 1) or not _invariant(n):
				if _len(n - 1) < _len(n + 1):
					n -= 1
				merge_at(n)
			elif _len(n) <= _len(n + 1):
				merge_at(n)
			else:
				break

	func merge_force_collapse() -> void:
		while runs.size() > 1:
			var n := runs.size() - 2
			if n > 0 and _len(n - 1) < _len(n + 1):
				n -= 1
			merge_at(n)

	func merge_at(i: int) -> void:
		var base_a := int(runs[i][0])
		var len_a := int(runs[i][1])
		var base_b := int(runs[i + 1][0])
		var len_b := int(runs[i + 1][1])
		runs[i] = [base_a, len_a + len_b]
		runs.remove_at(i + 1)
		var key_right: Variant = w[base_b]
		var k := gallop_right(w, key_right, base_a, len_a, 0)
		base_a += k
		len_a -= k
		if len_a == 0:
			return
		var key_left: Variant = w[base_a + len_a - 1]
		len_b = gallop_left(w, key_left, base_b, len_b, len_b - 1)
		if len_b == 0:
			return
		if len_a <= len_b:
			merge_low(base_a, len_a, base_b, len_b)
		else:
			merge_high(base_a, len_a, base_b, len_b)

	func gallop_left(a: Array, key: Variant, base: int, length: int, hint: int) -> int:
		var last_ofs := 0
		var offset := 1
		var order := _c(a[base + hint], key)
		if order < 0.0:
			var max_ofs := length - hint
			while offset < max_ofs:
				order = _c(a[base + hint + offset], key)
				if order >= 0.0:
					break
				last_ofs = offset
				offset = (offset << 1) + 1
				if offset <= 0:
					offset = max_ofs
			if offset > max_ofs:
				offset = max_ofs
			last_ofs += hint
			offset += hint
		else:
			var max_ofs2 := hint + 1
			while offset < max_ofs2:
				order = _c(a[base + hint - offset], key)
				if order < 0.0:
					break
				last_ofs = offset
				offset = (offset << 1) + 1
				if offset <= 0:
					offset = max_ofs2
			if offset > max_ofs2:
				offset = max_ofs2
			var tmp := last_ofs
			last_ofs = hint - offset
			offset = hint - tmp
		last_ofs += 1
		while last_ofs < offset:
			var m := last_ofs + ((offset - last_ofs) >> 1)
			if _c(a[base + m], key) < 0.0:
				last_ofs = m + 1
			else:
				offset = m
		return offset

	func gallop_right(a: Array, key: Variant, base: int, length: int, hint: int) -> int:
		var last_ofs := 0
		var offset := 1
		var order := _c(key, a[base + hint])
		if order < 0.0:
			var max_ofs := hint + 1
			while offset < max_ofs:
				order = _c(key, a[base + hint - offset])
				if order >= 0.0:
					break
				last_ofs = offset
				offset = (offset << 1) + 1
				if offset <= 0:
					offset = max_ofs
			if offset > max_ofs:
				offset = max_ofs
			var tmp := last_ofs
			last_ofs = hint - offset
			offset = hint - tmp
		else:
			var max_ofs2 := length - hint
			while offset < max_ofs2:
				order = _c(key, a[base + hint + offset])
				if order < 0.0:
					break
				last_ofs = offset
				offset = (offset << 1) + 1
				if offset <= 0:
					offset = max_ofs2
			if offset > max_ofs2:
				offset = max_ofs2
			last_ofs += hint
			offset += hint
		last_ofs += 1
		while last_ofs < offset:
			var m := last_ofs + ((offset - last_ofs) >> 1)
			if _c(key, a[base + m]) < 0.0:
				offset = m
			else:
				last_ofs = m + 1
		return offset

	## 겹치는 구간도 안전하게 (V8 Copy: 원본이 앞이면 뒤에서부터)
	static func copy(src: Array, src_pos: int, dst: Array, dst_pos: int, n: int) -> void:
		if is_same(src, dst) and src_pos < dst_pos:
			var i := n - 1
			while i >= 0:
				dst[dst_pos + i] = src[src_pos + i]
				i -= 1
		else:
			for i2 in n:
				dst[dst_pos + i2] = src[src_pos + i2]

	func merge_low(base_a: int, len_a0: int, base_b: int, len_b0: int) -> void:
		var len_a := len_a0
		var len_b := len_b0
		var tmp: Array = w.slice(base_a, base_a + len_a)
		var dest := base_a
		var ct := 0
		var cb := base_b
		w[dest] = w[cb]
		dest += 1
		cb += 1
		var mode := 0   # 0 계속 · 1 Succeed · 2 CopyB
		len_b -= 1
		if len_b == 0:
			mode = 1
		elif len_a == 1:
			mode = 2
		var mg := min_gallop
		while mode == 0:
			var wins_a := 0
			var wins_b := 0
			while true:
				if _c(w[cb], tmp[ct]) < 0.0:
					w[dest] = w[cb]
					dest += 1
					cb += 1
					wins_b += 1
					len_b -= 1
					wins_a = 0
					if len_b == 0:
						mode = 1
						break
					if wins_b >= mg:
						break
				else:
					w[dest] = tmp[ct]
					dest += 1
					ct += 1
					wins_a += 1
					len_a -= 1
					wins_b = 0
					if len_a == 1:
						mode = 2
						break
					if wins_a >= mg:
						break
			if mode != 0:
				break
			mg += 1
			var first := true
			while wins_a >= MIN_GALLOP or wins_b >= MIN_GALLOP or first:
				first = false
				mg = maxi(1, mg - 1)
				min_gallop = mg
				wins_a = gallop_right(tmp, w[cb], ct, len_a, 0)
				if wins_a > 0:
					copy(tmp, ct, w, dest, wins_a)
					dest += wins_a
					ct += wins_a
					len_a -= wins_a
					if len_a == 1:
						mode = 2
						break
					if len_a == 0:
						mode = 1
						break
				w[dest] = w[cb]
				dest += 1
				cb += 1
				len_b -= 1
				if len_b == 0:
					mode = 1
					break
				wins_b = gallop_left(w, tmp[ct], cb, len_b, 0)
				if wins_b > 0:
					copy(w, cb, w, dest, wins_b)
					dest += wins_b
					cb += wins_b
					len_b -= wins_b
					if len_b == 0:
						mode = 1
						break
				w[dest] = tmp[ct]
				dest += 1
				ct += 1
				len_a -= 1
				if len_a == 1:
					mode = 2
					break
			if mode != 0:
				break
			mg += 1
			min_gallop = mg
		if mode == 1:
			if len_a > 0:
				copy(tmp, ct, w, dest, len_a)
		else:
			copy(w, cb, w, dest, len_b)
			w[dest + len_b] = tmp[ct]

	func merge_high(base_a: int, len_a0: int, base_b: int, len_b0: int) -> void:
		var len_a := len_a0
		var len_b := len_b0
		var tmp: Array = w.slice(base_b, base_b + len_b)
		var dest := base_b + len_b - 1
		var ct := len_b - 1
		var ca := base_a + len_a - 1
		w[dest] = w[ca]
		dest -= 1
		ca -= 1
		var mode := 0   # 0 계속 · 1 Succeed · 2 CopyA
		len_a -= 1
		if len_a == 0:
			mode = 1
		elif len_b == 1:
			mode = 2
		var mg := min_gallop
		while mode == 0:
			var wins_a := 0
			var wins_b := 0
			while true:
				if _c(tmp[ct], w[ca]) < 0.0:
					w[dest] = w[ca]
					dest -= 1
					ca -= 1
					wins_a += 1
					len_a -= 1
					wins_b = 0
					if len_a == 0:
						mode = 1
						break
					if wins_a >= mg:
						break
				else:
					w[dest] = tmp[ct]
					dest -= 1
					ct -= 1
					wins_b += 1
					len_b -= 1
					wins_a = 0
					if len_b == 1:
						mode = 2
						break
					if wins_b >= mg:
						break
			if mode != 0:
				break
			mg += 1
			var first := true
			while wins_a >= MIN_GALLOP or wins_b >= MIN_GALLOP or first:
				first = false
				mg = maxi(1, mg - 1)
				min_gallop = mg
				var k := gallop_right(w, tmp[ct], base_a, len_a, len_a - 1)
				wins_a = len_a - k
				if wins_a > 0:
					dest -= wins_a
					ca -= wins_a
					copy(w, ca + 1, w, dest + 1, wins_a)
					len_a -= wins_a
					if len_a == 0:
						mode = 1
						break
				w[dest] = tmp[ct]
				dest -= 1
				ct -= 1
				len_b -= 1
				if len_b == 1:
					mode = 2
					break
				k = gallop_left(tmp, w[ca], 0, len_b, len_b - 1)
				wins_b = len_b - k
				if wins_b > 0:
					dest -= wins_b
					ct -= wins_b
					copy(tmp, ct + 1, w, dest + 1, wins_b)
					len_b -= wins_b
					if len_b == 1:
						mode = 2
						break
					if len_b == 0:
						mode = 1
						break
				w[dest] = w[ca]
				dest -= 1
				ca -= 1
				len_a -= 1
				if len_a == 0:
					mode = 1
					break
			if mode != 0:
				break
			mg += 1
			min_gallop = mg
		if mode == 1:
			if len_b > 0:
				copy(tmp, 0, w, dest - (len_b - 1), len_b)
		else:
			dest -= len_a
			ca -= len_a
			copy(w, ca + 1, w, dest + 1, len_a)
			w[dest] = tmp[ct]


static func _next_up(x: float) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	b.encode_s64(0, b.decode_s64(0) + 1)
	return b.decode_double(0)


## (4b-1) 0 ≤ v < 1 의 Number.prototype.toString(36) 와 같은 글 (V8 DoubleToRadixCString — 마지막 자리 반올림까지)
##  웹 `Math.random().toString(36).slice(2, 6)` (물약·공성 아이템 id, 장비 eid 꼬리)를 같은 씨앗으로 같게
## 출처: V8 src/numbers/conversions.cc DoubleToRadixCString — Copyright the V8 project authors. BSD-3-Clause (라이선스 화면 V8_LICENSE).
##  frac_to_base36 · rand36_4 는 그 알고리즘을 GDScript 로 옮긴 것.
static func frac_to_base36(value: float) -> String:
	var chars := "0123456789abcdefghijklmnopqrstuvwxyz"
	var fraction := value
	var delta := maxf(_next_up(0.0), 0.5 * (_next_up(value) - value))
	var digits: Array = []
	var integer := 0
	if fraction >= delta:
		while true:
			fraction *= 36.0
			delta *= 36.0
			var digit := int(floorf(fraction))
			digits.append(digit)
			fraction -= float(digit)
			if fraction > 0.5 or (fraction == 0.5 and (digit & 1) == 1):
				if fraction + delta > 1.0:
					while true:
						if digits.is_empty():
							integer += 1
							break
						var d: int = digits.pop_back()
						if d + 1 < 36:
							digits.append(d + 1)
							break
					break
			if not (fraction >= delta):
				break
	var s := "1" if integer > 0 else "0"
	if not digits.is_empty():
		s += "."
		for d2: int in digits:
			s += chars[d2]
	return s


## 웹 Math.random().toString(36).slice(2, 6)
static func rand36_4(r: float) -> String:
	return frac_to_base36(r).substr(2, 4)
