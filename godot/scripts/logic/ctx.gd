extends RefCounted
## 규칙 계산의 공통 환경: 데이터(D) · 난수(rng) · 저장소(store) · 가상 시계
##  웹은 이것들이 전역(STAGES, Math.random, localStorage, Date.now)이라, 이식에서는 이 객체 하나를 넘겨 쓴다.
##  D 는 웹 전역 이름 → 값 (DataDB 의 모든 전역을 한 사전으로). 숫자 규칙은 godot/README.md (기본 float, id·x·y 등만 int)

const Rng := preload("res://scripts/logic/rng.gd")
const SaveStore := preload("res://scripts/logic/save_store.gd")

## 웹 전역 이름 → 값 (JAB, STAGES, TI, HAZARDS …)
var D: Dictionary = {}
var rng: Rng
var store: SaveStore
## 가상 시각(ms) — Date.now() = DATE_BASE + now_ms (장비 eid·룬 rid 같은 저장 값에만 쓰임, 규칙 결과와 무관)
var now_ms: float = 0.0
const DATE_BASE := 1791936000000.0   # 2026-10-14T00:00:00Z (battle-sim 과 같은 기준)
var eid_counter: int = 0


## DataDB(오토로드 또는 같은 스크립트로 만든 노드)에서 모든 전역을 모음
static func globals_from_db(db: Object) -> Dictionary:
	var out: Dictionary = {}
	for name: String in db.call("global_names"):
		out[name] = db.call("global", name)
	return out


func _init(data: Dictionary, seed: int, save: SaveStore = null) -> void:
	D = data
	rng = Rng.new(seed)
	store = save if save != null else SaveStore.new()


## Math.random()
func rand(tag: String = "") -> float:
	return rng.next(tag)


func date_now() -> float:
	return DATE_BASE + now_ms
