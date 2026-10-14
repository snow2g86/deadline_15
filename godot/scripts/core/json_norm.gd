extends RefCounted
## JSON 숫자 정리 — 숫자는 기본 float 로 둔다 (JS 와 같은 모델: 모든 숫자가 실수)
##
##  정수 값을 전부 int 로 바꾸면 데이터끼리 나눌 때 int / int 정수 나눗셈이 되어 웹과 결과가 달라진다
##  (예: 1 + exp_pct / 100 → 1, JS 는 1.5). 그래서 **식별자·번호 성격의 키만** 화이트리스트로 int 로 바꾼다.
##  이 값들은 주로 비교(===)·indexOf/has·사전 키·배열 번호로 쓰인다. 웹에서 데이터끼리 나누는 대표 값
##  (tot, frames, hit, exp, gold …)은 일부러 넣지 않았다.
##
##  주의 — 목록 안의 값도 웹에서 나누는 곳이 있다. 이식할 때 float() 를 씌울 것:
##   - js/logic/stages.js  stageEnemySkillLv: Math.floor(id / ENEMY_SKILL_EVERY) — 양수라 정수 나눗셈과 결과 같음
##   - js/logic/hazards.js:31  h.dot * (1 + stageLevel(stage) / 100) — stageLevel 이 int id 를 돌려주면 정수 나눗셈이 되어
##     결과가 달라진다 (2단계에서 stage_level() 은 float 를 돌려주도록 정할 예정)
##  DataDB(모든 데이터 JSON)와 Store.get_json 이 같은 규칙을 쓴다.
##
##  규칙: 사전의 키가 INT_KEYS 에 있으면 그 값이 숫자면 int, 숫자 배열이면 원소를 int 로 (정수 값일 때만, null 은 그대로).
##  키 없이 배열만 저장되는 Store 키(game_cleared, game_party)는 INT_ARRAY_STORE_KEYS 로 배열 전체를 int 로.

const INT_KEYS := {
	# ── 게임 데이터 ──
	"id": true,             # 스테이지·에피소드·파티 번호
	"phase": true,          # STAGES[].phase (에피소드 번호)
	"episode": true,
	"stage": true,
	"stages": true,         # EPISODES[].stages = 스테이지 번호 배열
	"spw": true,            # 웨이브당 출현 수
	"si": true,             # 출현 간격(라운드)
	"tier": true,
	"x": true,              # 칸 좌표 (배열 번호로 씀: G.ter[y][x])
	"y": true,
	# ── 저장 데이터 (js/common/storage.js · character.js · js/logic/equip.js · js/index.js) ──
	"uid": true,            # 클랜원 번호 (game_roster.chars[].uid)
	"nextId": true,         # 다음 클랜원 번호 (game_roster.nextId — 웹 실제 키)
	"nameId": true,         # 이름 목록 번호 (character.names[nameId])
	"lv": true,             # 레벨
	"level": true,
	"slots": true,          # game_parties.parties[].slots = 클랜원 uid 배열 (null 섞임)
	"activePartyId": true,  # game_parties.activePartyId
	"nextPartyId": true,    # game_parties.nextPartyId
	"party": true,          # game_nav.party = 출전 uid 배열
	"equipped": true,       # 장비를 낀 클랜원 uid (없으면 null)
	"enhanceLv": true,      # 장비 강화 단계 (ENHANCE_RATES[enhanceLv] 번호)
	"templateId": true,     # 장비 템플릿 (지금은 문자열 — 숫자일 때만 int)
	"eid": true,            # 장비 개체 번호 (지금은 문자열 'eq_…' — 숫자일 때만 int)
	"cleared": true,        # game_save.cleared = 클리어한 스테이지 번호 배열
}

## 값이 번호 배열 하나뿐인 Store 키 (사전 키가 없어 INT_KEYS 로 못 잡음)
const INT_ARRAY_STORE_KEYS := {
	"game_cleared": true,   # [1, 2, 3] 클리어한 스테이지 (js/index.js)
	"game_party": true,     # 레거시 파티 uid 배열 (js/common/storage.js PARTY_KEY)
}

const MAX_SAFE := 9007199254740992.0   # 2^53


## 배열·사전을 재귀로 돌며 INT_KEYS 아래 숫자만 int 로 (원본 컨테이너를 제자리에서 바꾸고 돌려줌)
static func normalize(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			var a: Array = v
			for i in a.size():
				a[i] = normalize(a[i])
		TYPE_DICTIONARY:
			var d: Dictionary = v
			for k: Variant in d.keys():
				var val: Variant = d[k]
				if INT_KEYS.has(k):
					d[k] = _to_int(val)
				else:
					d[k] = normalize(val)
	return v


## Store 키 하나의 JSON 값 정리 (Store.get_json 이 씀)
static func normalize_store(store_key: String, v: Variant) -> Variant:
	if INT_ARRAY_STORE_KEYS.has(store_key) and typeof(v) == TYPE_ARRAY:
		return _to_int(v)
	return normalize(v)


static func _to_int(v: Variant) -> Variant:
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		if is_finite(f) and f == floorf(f) and absf(f) < MAX_SAFE:
			return int(f)
		return f
	if typeof(v) == TYPE_ARRAY:
		var a: Array = v
		for i in a.size():
			a[i] = _to_int(a[i]) if typeof(a[i]) == TYPE_FLOAT else normalize(a[i])
		return a
	return normalize(v)
