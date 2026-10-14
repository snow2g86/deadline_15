extends RefCounted
## 전투 난수: mulberry32 (tools/battle-sim/env.js 와 비트까지 같음 — tests/golden/README.md 의 명세)
##  웹의 Math.random() 자리를 모두 이것으로 바꾼다. calls = 지금까지 부른 횟수 (황금 기록의 rng/rngEnd 와 비교)
##  log_enabled 면 호출마다 '번호<TAB>태그' 를 남긴다 (node tools/battle-sim.js --rng-log 와 맞춰 보며 어긋난 곳 찾기)

const M32 := 0xFFFFFFFF

var _a: int = 0
var calls: int = 0
var counting: bool = true
var log_enabled: bool = false
var log: PackedStringArray = PackedStringArray()


func _init(seed: int = 0) -> void:
	_a = seed & M32


static func _imul(a: int, b: int) -> int:   # Math.imul 의 하위 32비트 (부호 없는 값으로)
	var al := a & 0xFFFF
	var ah := (a >> 16) & 0xFFFF
	var bl := b & 0xFFFF
	var bh := (b >> 16) & 0xFFFF
	return ((((ah * bl + al * bh) & 0xFFFF) << 16) + al * bl) & M32


## Math.random() — tag 는 기록용 (웹 함수 이름)
func next(tag: String = "") -> float:
	_a = (_a + 0x6D2B79F5) & M32
	var t := _a
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & M32)) & M32
	var v := float((t ^ (t >> 14)) & M32) / 4294967296.0
	if counting:
		calls += 1
		if log_enabled:
			log.append("%d\t%s" % [calls, tag])
	return v
