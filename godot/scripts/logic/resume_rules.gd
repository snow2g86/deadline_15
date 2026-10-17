extends RefCounted
## 전투 이어하기 규칙 (4b-1) — 화면 코드 없이 정적 함수, 첫 인자 c = ctx.gd
##
##  Godot 전투 저장은 웹 키(game_battle)가 아니라 Godot 전용 키 gd_battle 에 둔다.
##   - 웹 로비는 game_battle 에 stage 가 있으면 '전투 재개' 단추를 띄우고 웹 resumeBattle 형식(ter·units·eQ …)으로 읽는다.
##     Godot 엔진 저장(save_state: 유닛 표 + S + 난수 상태 + 저장소 사본 …)을 game_battle 에 쓰면 웹이 읽다가 깨지므로 따로 둔다.
##   - 웹은 gd_battle 을 모르니 무시한다 (웹 → Godot → 웹 왕복 안전).
##  gd_battle = JSON 문자열 { format: 1, cfg: { stage, practice, party, seed }, sum: state 글의 md5, state: 엔진 save_state() }
##   sum 이 맞지 않으면(손으로 고치거나 잘린 저장) 깨진 저장으로 보고 이어하지 않음 — 엔진에 이상한 상태를 넣어 스크립트 오류가 나지 않게
##  웹 game_battle (예전 웹 자동 저장, 2026-02 이후 웹은 더 쓰지 않음)은 Godot 엔진으로 이어갈 수 없어 '웹판에서 시작된 전투' 안내 + 포기만 (README 판단).

const Js := preload("res://scripts/logic/js.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")

const KEY := "gd_battle"
const WEB_KEY := "game_battle"
const FORMAT := 1
## 엔진 save_state 에 꼭 있어야 하는 칸 (없으면 깨진 저장으로 봄)
const STATE_KEYS := ["format", "units", "S", "fsm", "rng", "store", "await", "known", "drawn", "init_ter", "seq"]


## 로비에서 보일 상태: "gd"(Godot 전투 — 이어하기) · "web"(웹이 만든 game_battle — 이어할 수 없음) · "broken"(gd_battle 이 깨짐) · ""(없음)
static func status(c: Object) -> String:
	var raw: Variant = c.store.get_str(KEY)
	if raw != null and str(raw) != "":
		return "gd" if load_gd(c) != null else "broken"
	var bd: Variant = c.store.get_json(WEB_KEY)
	if bd is Dictionary and Js.truthy(bd.get("stage")):
		return "web"
	return ""


## gd_battle 읽기 → { cfg, state } 또는 null (형식이 맞지 않으면)
static func load_gd(c: Object) -> Variant:
	var raw: Variant = c.store.get_str(KEY)
	if raw == null or str(raw) == "":
		return null
	var text := str(raw)
	var at := text.find(",\"state\":")
	if at < 0 or not text.ends_with("}"):
		return null
	var state_text := text.substr(at + 9, text.length() - at - 10)
	var p: Array = JsonExact.parse_ex(text)
	if not p[0] or not (p[1] is Dictionary):
		return null
	var d: Dictionary = p[1]
	if not Js.same(d.get("format"), FORMAT) or not (d.get("cfg") is Dictionary) or not (d.get("state") is Dictionary):
		return null
	if str(d.get("sum", "")) != state_text.md5_text():
		return null
	var st: Dictionary = d["state"]
	for k: String in STATE_KEYS:
		if not st.has(k):
			return null
	if not (st["units"] is Array) or not (st["S"] is Dictionary) or not (st["store"] is Dictionary) or not (st["rng"] is Dictionary):
		return null
	if st["await"] == null:
		return null   # 입력 대기 때만 저장하므로 대기 유닛이 없으면 이어갈 곳이 없음
	var cfg: Dictionary = d["cfg"]
	if not (cfg.get("stage") is Dictionary):
		return null
	return d


## 저장 (엔진 save_text 결과를 그대로 state 로 — 실수 정확)
static func save_gd(c: Object, cfg: Dictionary, state_text: String) -> void:
	var head := {"format": FORMAT, "cfg": {"stage": cfg.get("stage"), "practice": bool(cfg.get("practice", false)), "party": cfg.get("party"), "seed": int(cfg.get("seed", 1))},
		"sum": state_text.md5_text()}
	var h := JsonExact.stringify(head)
	# state 는 이미 정확한 JSON 글 — 다시 읽고 쓰지 않고 이어 붙임
	c.store.set_str(KEY, h.substr(0, h.length() - 1) + ",\"state\":" + state_text + "}")


static func clear_gd(c: Object) -> void:
	c.store.remove(KEY)


## 이어할 수 없는 전투 포기 (웹 game_battle · 깨진 gd_battle) — 웹도 새 전투가 game_battle 을 덮어쓰거나 끝날 때 지우므로 같은 뜻
static func abandon(c: Object) -> void:
	c.store.remove(KEY)
	c.store.remove(WEB_KEY)


## 웹 game_battle 의 스테이지 (안내 글용)
static func web_stage(c: Object) -> Variant:
	var bd: Variant = c.store.get_json(WEB_KEY)
	return bd["stage"] if bd is Dictionary and bd.get("stage") is Dictionary else null
