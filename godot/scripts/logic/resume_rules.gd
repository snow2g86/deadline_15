extends RefCounted
## 전투 이어하기 규칙 (4b-1 · 4b-2) — 화면 코드 없이 정적 함수, 첫 인자 c = ctx.gd
##
##  Godot 전투 저장은 웹 키(game_battle)가 아니라 Godot 전용 키 gd_battle 에 둔다.
##   - 웹 로비는 game_battle 에 stage 가 있으면 '전투 재개' 단추를 띄우고 웹 resumeBattle 형식(ter·units·eQ …)으로 읽는다.
##     Godot 엔진 저장(save_state: 유닛 표 + S + 난수 상태 + 저장소 사본 …)을 game_battle 에 쓰면 웹이 읽다가 깨지므로 따로 둔다.
##   - 웹은 gd_battle 을 모르니 무시한다 (웹 → Godot → 웹 왕복 안전).
##  gd_battle = JSON 문자열 {"format":2,"sum":"<md5>","cfg":{ stage, practice, party, seed, saveFormat, dataHash, gameVersion },"state":{ 엔진 save_state() }}
##   (4b-2) sum = '{"format":2,' + sum 뒤의 글 전체(cfg·state) 의 md5 — 고치거나 잘린 저장은 '깨진 저장'으로 보고 이어하지 않음
##   (4b-2) cfg 의 saveFormat(엔진 저장 형식)·dataHash(데이터 원본 sha 묶음)·gameVersion(project.godot config/version) 이 지금 게임과
##          하나라도 다르거나, format 이 2 가 아니거나(4b-1 저장 = format 1), state.format 이 엔진 SAVE_FORMAT 과 다르면 'old'
##          → '이전 버전의 전투라 이어할 수 없음' 안내 + 포기 (디렉터 결정: 데이터·규칙이 바뀐 뒤 옛 상태를 넣으면 같은 전투를 보장할 수 없음)
##  웹 game_battle (예전 웹 자동 저장, 2026-02 이후 웹은 더 쓰지 않음)은 Godot 엔진으로 이어갈 수 없어 '웹판에서 시작된 전투' 안내 + 포기만 (README 판단).

const Js := preload("res://scripts/logic/js.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")
const BattleEngine := preload("res://scripts/logic/battle/battle_engine.gd")

const KEY := "gd_battle"
const WEB_KEY := "game_battle"
const FORMAT := 2
const HEAD := "{\"format\":2,\"sum\":\""
## 엔진 save_state 에 꼭 있어야 하는 칸 (없으면 깨진 저장으로 봄)
const STATE_KEYS := ["format", "units", "S", "fsm", "rng", "store", "await", "known", "drawn", "init_ter", "seq"]
const STAMP_KEYS := ["saveFormat", "dataHash", "gameVersion"]
## DataDB 가 읽은 파일 sha1 이 manifest 와 다르면(data_tool --write 를 잊음) 데이터 해시를 믿을 수 없음 → 이 값. 이 판에서는 이어하기를 하지 않음 ('old')
const INVALID_HASH := "invalid:sha1-mismatch"

## (결제층 A) 데이터 해시에서 뺄 모듈 — 전투와 무관 (iap.json: 결제 상품·가격·서버 주소·광고 보상). 바꿔도 저장 전투를 '이전 버전'으로 보내지 않음
const HASH_EXCLUDE := ["iap"]

## 시험용: 지금 게임의 판(stamp)을 바꿔 '다른 버전' 을 흉내 (비어 있으면 진짜 값)
static var stamp_override: Dictionary = {}


## 지금 게임의 판: 엔진 저장 형식 · 데이터 원본 해시(manifest.sources 의 sha1 묶음 — 번역은 넣지 않음) · 게임 버전
static func current_stamp() -> Dictionary:
	if not stamp_override.is_empty():
		return stamp_override.duplicate()
	var man: Dictionary = {}
	var bad := false
	var ml := Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).root != null:
		var db: Node = (ml as SceneTree).root.get_node_or_null("DataDB")
		if db != null and db.get("manifest") is Dictionary:
			man = db.get("manifest")
			bad = bool(db.get("sha_mismatch"))
	var src: Dictionary = (man.get("sources", {}) as Dictionary).duplicate()
	for k: String in HASH_EXCLUDE:
		src.erase(k)
	return {"saveFormat": BattleEngine.SAVE_FORMAT, "dataHash": INVALID_HASH if bad else JsonExact.stringify(src).md5_text(),
		"gameVersion": str(ProjectSettings.get_setting("application/config/version", ""))}


## 로비에서 보일 상태: "gd"(Godot 전투 — 이어하기) · "old"(이전 버전 Godot 전투 — 이어할 수 없음) · "web"(웹이 만든 game_battle — 이어할 수 없음)
##  · "broken"(gd_battle 이 깨짐) · ""(없음)
static func status(c: Object) -> String:
	var raw: Variant = c.store.get_str(KEY)
	if raw != null and str(raw) != "":
		return str(check(c)[0])
	var bd: Variant = c.store.get_json(WEB_KEY)
	if bd is Dictionary and Js.truthy(bd.get("stage")):
		return "web"
	return ""


## gd_battle 읽기 → { cfg, state } 또는 null (이어할 수 없으면)
static func load_gd(c: Object) -> Variant:
	var r := check(c)
	return r[1] if r[0] == "gd" else null


## gd_battle 검사 → [상태("gd"·"old"·"broken"·""), 사전 또는 null]
static func check(c: Object) -> Array:
	var raw: Variant = c.store.get_str(KEY)
	if raw == null or str(raw) == "":
		return ["", null]
	var text := str(raw)
	var p: Array = JsonExact.parse_ex(text)
	if not p[0] or not (p[1] is Dictionary):
		return ["broken", null]
	var d: Dictionary = p[1]
	# 4b-1 저장(format 1)이나 모르는 형식 → 예전 판
	if not Js.same(d.get("format"), FORMAT):
		return ["old" if (typeof(d.get("format")) == TYPE_INT or typeof(d.get("format")) == TYPE_FLOAT) else "broken", null]
	# md5: 저장 글 전체(형식·cfg·state)
	if not text.begins_with(HEAD) or text.length() < HEAD.length() + 34 or text.substr(HEAD.length() + 32, 2) != "\",":
		return ["broken", null]
	var sum := text.substr(HEAD.length(), 32)
	var rest := text.substr(HEAD.length() + 34)
	if ("{\"format\":2," + rest).md5_text() != sum or str(d.get("sum", "")) != sum:
		return ["broken", null]
	if not (d.get("cfg") is Dictionary) or not (d.get("state") is Dictionary):
		return ["broken", null]
	var st: Dictionary = d["state"]
	for k: String in STATE_KEYS:
		if not st.has(k):
			return ["broken", null]
	if not (st["units"] is Array) or not (st["S"] is Dictionary) or not (st["store"] is Dictionary) or not (st["rng"] is Dictionary):
		return ["broken", null]
	if st["await"] == null:
		return ["broken", null]   # 입력 대기 때만 저장하므로 대기 유닛이 없으면 이어갈 곳이 없음
	var cfg: Dictionary = d["cfg"]
	if not (cfg.get("stage") is Dictionary):
		return ["broken", null]
	# 판 확인: 저장 형식 · 데이터 · 게임 버전이 하나라도 다르면 예전 판
	var now := current_stamp()
	if str(now["dataHash"]) == INVALID_HASH:
		return ["old", null]   # 이 실행의 데이터가 manifest 와 어긋남 — 이어하지 않음 (같은 실행에서 저장한 전투도)
	for k2: String in STAMP_KEYS:
		if typeof(cfg.get(k2)) != TYPE_STRING or str(cfg[k2]) != str(now[k2]):
			return ["old", null]
	if not Js.same(st.get("format"), now["saveFormat"]):
		return ["old", null]
	return ["gd", d]


## 저장 (엔진 save_text 결과를 그대로 state 로 — 실수 정확). cfg 에 지금 판(stamp)을 넣음
static func save_gd(c: Object, cfg: Dictionary, state_text: String) -> void:
	var g := {"stage": cfg.get("stage"), "practice": bool(cfg.get("practice", false)), "party": cfg.get("party"), "seed": int(cfg.get("seed", 1))}
	g.merge(current_stamp(), true)
	# state 는 이미 정확한 JSON 글 — 다시 읽고 쓰지 않고 이어 붙임
	var rest := "\"cfg\":" + JsonExact.stringify(g) + ",\"state\":" + state_text + "}"
	var sum := ("{\"format\":2," + rest).md5_text()
	c.store.set_str(KEY, HEAD + sum + "\"," + rest)


static func clear_gd(c: Object) -> void:
	c.store.remove(KEY)


## 전투 포기 (웹 game_battle · 깨진·예전 판 gd_battle · (4b-2) 정상 gd_battle 도) — 웹도 새 전투가 game_battle 을 덮어쓰거나 끝날 때 지우므로 같은 뜻.
##  전투 중 이미 저장소에 쓴 값(상자 골드·쓴 물약·쓰러진 클랜원 …)은 그대로 (웹도 바로 씀)
static func abandon(c: Object) -> void:
	c.store.remove(KEY)
	c.store.remove(WEB_KEY)


## 웹 game_battle 의 스테이지 (안내 글용)
static func web_stage(c: Object) -> Variant:
	var bd: Variant = c.store.get_json(WEB_KEY)
	return bd["stage"] if bd is Dictionary and bd.get("stage") is Dictionary else null


## 정상 gd_battle 의 스테이지 (포기 확인 글용)
static func gd_stage(c: Object) -> Variant:
	var r := check(c)
	if r[0] != "gd":
		return null
	var st: Variant = (r[1] as Dictionary)["cfg"].get("stage")
	return st if st is Dictionary else null


## (4b-2) 중단된 저장 전투(gd_battle)에 나가 있는 클랜원 uid — 성소 제물 후보에서 뺌 (포기·끝나면 저장이 지워져 다시 후보)
##  판이 다르거나(old) md5 가 틀려도 글을 읽을 수 있으면 셈 (포기하기 전까지는 그 전투의 클랜원). 읽을 수 없으면 빈 목록
static func battle_uids(c: Object) -> Array:
	var raw: Variant = c.store.get_str(KEY)
	if raw == null or str(raw) == "":
		return []
	var p: Array = JsonExact.parse_ex(str(raw))
	if not p[0] or not (p[1] is Dictionary):
		return []
	var d: Dictionary = p[1]
	var out: Array = []
	var add := func(u: Variant) -> void:
		if (typeof(u) == TYPE_INT or typeof(u) == TYPE_FLOAT) and Js.index_of(out, int(u)) < 0:
			out.append(int(u))
	var st: Variant = d.get("state")
	if st is Dictionary and st.get("units") is Array:
		for u: Variant in st["units"]:
			if u is Dictionary and u.get("team") == "ally" and not Js.truthy(u.get("isSummon")):
				add.call(u.get("uid"))
	var cfg: Variant = d.get("cfg")
	if cfg is Dictionary and cfg.get("party") is Array:
		for u2: Variant in cfg["party"]:
			add.call(u2)
	return out
