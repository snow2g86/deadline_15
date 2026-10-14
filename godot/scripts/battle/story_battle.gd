extends RefCounted
## 전투 중 스토리 대사 — 웹 js/battle/story-battle.js (StoryBattle) + js/common/story.js 의 대본 조회·화자·본 장면 기록
##  규칙은 동기로 끝까지 진행하므로, 대사는 **화면 재생·입력만** 멈춘다 (장면이 재생 대기열을 붙잡고 StoryView 로 보여 줌).
##  웹과 같은 시점:
##   - 첫 차례 전: 출전 전 장면(에피소드 프롤로그 → s{id}_pre, 본 것은 건너뜀) → 'start'
##   - turn_start (아군·적군 — 웹은 아군 turn_start 와 적 행동 직전 AI.eAI 에서 flush): scan 후 쌓인 대사 재생
##   - wave_spawn: 첫 배치(actCount 0) 뒤 증원이면 'wave' + scan,  unit_attacked·unit_killed: scan
##   - 승리 뒤 결과 화면 전: s{id}_post → 에피소드 마지막 스테이지면 에필로그
##  본 장면은 game_story_seen 에 기록 (Store 세이브로 시작한 전투만 진짜 Store 에 — 디버그·시험은 이번 실행 안에서만)

const Js := preload("res://scripts/logic/js.gd")
const Num := preload("res://scripts/core/num.gd")

const SEEN_KEY := "game_story_seen"
const BATTLE_KINDS := ["start", "wave", "boss", "danger", "last"]
const PRIORITY := {"start": 0, "boss": 1, "wave": 2, "danger": 3, "last": 4}
## 전용 보스 초상화가 있는 스테이지 (image/character/story/boss_<id>.png)
const BOSS_ART := [10, 20, 30, 40, 45, 50, 60, 70, 80, 90, 92, 93, 94, 95, 99, 100]

var D: Dictionary
var data: Dictionary = {}       # 지금 언어 대본 (없으면 ko)
var stage: Variant = null
var seen: Dictionary = {}
var store: Node = null          # 진짜 Store (기록할 때만)
var roster: Variant = null      # 지휘관 이름·성별 (전투 세이브의 game_roster)
var i18n: Node
var icons: Object
var enabled := true

var _queue: Array = []
var _queued: Dictionary = {}
var _healthy: Dictionary = {}
var vars: Dictionary = {}
var intro_done := false


func _init(p_D: Dictionary, p_i18n: Node, p_icons: Object) -> void:
	D = p_D
	i18n = p_i18n
	icons = p_icons


func t(k: String, p: Dictionary = {}) -> String:
	return i18n.t(k, p) if i18n != null else k


func tr_or(k: String, fallback: String, p: Dictionary = {}) -> String:
	if i18n != null and i18n.has_key(k):
		return i18n.t(k, p)
	return fallback


## 대본 고르기 (웹 Story.data: 지금 언어 → 없으면 한국어, game_story_dev = sample 이면 샘플)
func load_data(db: Node, lang: String, dev: Variant) -> void:
	data = {}
	if db == null:
		return
	if str(dev) == "sample":
		data = db.call("story", "sample")
	if data.is_empty():
		data = db.call("story", lang)
	if data.is_empty():
		data = db.call("story", "ko")


# ── 본 장면 ──

func is_seen(key: String) -> bool:
	return Js.truthy(seen.get(key))


func mark_seen(key: String) -> void:
	seen[key] = true
	if store != null:
		var cur: Variant = store.call("get_json", SEEN_KEY, {})
		var d: Dictionary = cur if cur is Dictionary else {}
		d[key] = true
		store.call("set_json", SEEN_KEY, d)


# ── 대본 조회 (Story.linesOf) ──

func lines_of(key: String) -> Variant:
	if data.is_empty():
		return null
	var re := RegEx.create_from_string("^ep(\\d+)_(pro|epi)$")
	var m := re.search(key)
	if m != null:
		var ep: Variant = (data.get("episodes", {}) as Dictionary).get(m.get_string(1))
		return ep.get("prologue" if m.get_string(2) == "pro" else "epilogue") if typeof(ep) == TYPE_DICTIONARY else null
	var re2 := RegEx.create_from_string("^s(\\d+)_(\\w+)$")
	var m2 := re2.search(key)
	if m2 != null:
		var st: Variant = (data.get("stages", {}) as Dictionary).get(m2.get_string(1))
		if typeof(st) != TYPE_DICTIONARY:
			return null
		var part := m2.get_string(2)
		if part == "pre" or part == "post":
			return st.get(part)
		if typeof(st.get("battle")) != TYPE_DICTIONARY:
			return null
		return st["battle"].get(part)
	return null


func _has_lines(key: String) -> bool:
	var l: Variant = lines_of(key)
	return l is Array and not (l as Array).is_empty()


func ep_of(stage_id: int) -> int:
	for e: Dictionary in D.get("EPISODES", []):
		if (e["stages"] as Array).has(stage_id) or (e["stages"] as Array).has(float(stage_id)):
			return int(e["id"])
	return floori(float(stage_id - 1) / 10.0) + 1


func ep_stages(ep: int) -> Array:
	for e: Dictionary in D.get("EPISODES", []):
		if int(e["id"]) == ep:
			return e["stages"]
	var a: Array = []
	for i in range(1, 11):
		a.append((ep - 1) * 10 + i)
	return a


func stage_label(stage_id: int) -> String:
	var ep := ep_of(stage_id)
	var idx := 0
	var sts := ep_stages(ep)
	for i in sts.size():
		if int(sts[i]) == stage_id:
			idx = i + 1
	var nm := tr_or("stages.stage_%d_name" % stage_id, "")
	return "EP.%d-%d%s" % [ep, idx if idx > 0 else stage_id, (" " + nm) if nm != "" else ""]


func title_of(key: String) -> String:
	var re := RegEx.create_from_string("^ep(\\d+)_(pro|epi)$")
	var m := re.search(key)
	if m != null:
		var ep: Variant = (data.get("episodes", {}) as Dictionary).get(m.get_string(1))
		var ep_name := str(ep.get("title", "")) if typeof(ep) == TYPE_DICTIONARY else ""
		if ep_name == "":
			ep_name = tr_or("episode.%s.name" % m.get_string(1), "")
		return "EP.%s %s%s" % [m.get_string(1), tr_or("story.prologue" if m.get_string(2) == "pro" else "story.epilogue", ""), (" · " + ep_name) if ep_name != "" else ""]
	return ""


# ── 장면 묶음 (재생할 [{key, lines, title, battle}]) ──

## 출전 전 (Story.beforeStage) + 'start' 를 쌓기 (StoryBattle: 첫 nextAction 앞)
func intro() -> Array:
	intro_done = true
	var out: Array = []
	if stage == null or data.is_empty() or not enabled:
		return out
	var sid := int(stage["id"])
	var ep := ep_of(sid)
	_scene(out, "ep%d_pro" % ep, title_of("ep%d_pro" % ep), false)
	_scene(out, "s%d_pre" % sid, stage_label(sid), false)
	enqueue("start")
	return out


func _scene(out: Array, key: String, title: String, battle: bool) -> void:
	if not _has_lines(key) or is_seen(key):
		return
	out.append({"key": key, "lines": lines_of(key), "title": title, "battle": battle})


func enqueue(kind: String) -> void:
	if stage == null or not enabled or _queued.has(kind):
		return
	var key := "s%d_%s" % [int(stage["id"]), kind]
	if is_seen(key):
		_queued[kind] = true
		return
	if not _has_lines(key):
		return
	_queued[kind] = true
	_queue.append(kind)
	_queue.sort_custom(func(a: String, b: String) -> bool: return int(PRIORITY[a]) < int(PRIORITY[b]))


## 지금 화면 상태로 조건 확인 (StoryBattle.scan) — view: {units:[{team,hp,mhp,isBoss,isSummon,cls,name,id}], espwn, tot, ended}
func scan(view: Dictionary) -> void:
	if stage == null or not enabled or bool(view.get("ended", false)):
		return
	var units: Array = view["units"]
	for u: Dictionary in units:
		if Js.truthy(u.get("isBoss")) and u.get("team") == "enemy" and float(u["hp"]) > 0.0:
			enqueue("boss")
			break
	if not _queued.has("danger"):
		for u2: Dictionary in units:
			if u2.get("team") != "ally" or Js.truthy(u2.get("isSummon")) or str(u2.get("cls", "")).begins_with("summon_") or float(u2["hp"]) <= 0.0:
				continue
			if float(u2["hp"]) >= float(u2["mhp"]) * 0.3:
				_healthy[u2["id"]] = true
				continue
			if _healthy.has(u2["id"]):
				vars["ally"] = str(view.get("name_of", {}).get(u2["id"], ""))
				enqueue("danger")
				break
	if float(view.get("espwn", 0)) >= float(stage.get("tot", 0)):
		var n := 0
		for u3: Dictionary in units:
			if u3.get("team") == "enemy" and float(u3["hp"]) > 0.0 and not Js.truthy(u3.get("isSummon")):
				n += 1
		if n == 1:
			enqueue("last")


## 쌓인 전투 대사 → 재생할 장면 목록 (StoryBattle.flush)
func flush(view: Dictionary) -> Array:
	scan(view)
	var out: Array = []
	if bool(view.get("ended", false)):
		_queue = []
		return out
	while not _queue.is_empty():
		var kind: String = _queue.pop_front()
		_scene(out, "s%d_%s" % [int(stage["id"]), kind], "", true)
	return out


## 승리 뒤 (Story.afterStage)
func outro() -> Array:
	_queue = []
	var out: Array = []
	if stage == null or data.is_empty() or not enabled:
		return out
	var sid := int(stage["id"])
	_scene(out, "s%d_post" % sid, stage_label(sid), false)
	var ep := ep_of(sid)
	var sts := ep_stages(ep)
	if not sts.is_empty() and int(sts[sts.size() - 1]) == sid:
		_scene(out, "ep%d_epi" % ep, title_of("ep%d_epi" % ep), false)
	return out


# ── 화자 (Story._speaker) → StoryView 줄 ──

func resolve_lines(lines: Array) -> Array:
	var out: Array = []
	for ln: Variant in lines:
		if typeof(ln) != TYPE_DICTIONARY or not Js.truthy(ln.get("text")):
			continue
		var sp := _speaker(ln)
		sp["mood"] = str(ln.get("mood", "normal"))
		sp["text"] = _fmt(str(ln["text"]))
		out.append(sp)
	return out


func _speaker(line: Dictionary) -> Dictionary:
	var cast: Dictionary = data.get("cast", {})
	var who := str(line.get("who", "narrator"))
	if who == "boss":
		var bi := _boss_img()
		var bn := ""
		if stage != null and Js.truthy(stage.get("boss")):
			var k := "stages.boss_%d" % int(stage["id"])
			bn = tr_or(k, str(stage["boss"].get("name", "")))
		return {"narr": false, "key": "boss", "name": bn if bn != "" else "???", "tex": bi["tex"], "art": bi["art"], "side": "right", "boss": true}
	var c: Variant = cast.get(who)
	if who == "narrator" or (typeof(c) == TYPE_DICTIONARY and not Js.truthy(c.get("name")) and not Js.truthy(c.get("portrait")) and who != "commander"):
		return {"narr": true}
	if typeof(c) != TYPE_DICTIONARY:
		c = {"name": who, "portrait": null}
	var sp := {"narr": false, "key": who, "name": str(c.get("name", "")), "tex": null,
		"side": "left" if (who == "commander" or c.get("side") == "left") else "right", "boss": false, "art": false, "ghost": false}
	if who == "commander":
		sp["name"] = commander_name()
	if c.get("portrait") == "commander" or (who == "commander" and c.get("portrait") != null):
		sp["tex"] = _commander_img()
	elif c.get("portrait") == "boss":
		var bb := _boss_img()
		if bb["tex"] != null:
			sp["tex"] = bb["tex"]
			sp["art"] = bb["art"]
			sp["boss"] = true
	elif Js.truthy(c.get("portrait")):
		var tx: Texture2D = icons.call("image", "character/" + str(c["portrait"]) + ".png")
		if tx == null and Js.truthy(c.get("fallback")):
			tx = icons.call("image", "character/" + str(c["fallback"]) + ".png")
		sp["tex"] = tx
		sp["ghost"] = Js.truthy(c.get("ghost"))
	return sp


func _boss_img() -> Dictionary:
	if stage == null or not Js.truthy(stage.get("boss")):
		return {"tex": null, "art": false}
	var cls_img := "character/" + str(stage["boss"]["cls"]) + "_01.png"
	if BOSS_ART.has(int(stage["id"])):
		var t2: Texture2D = icons.call("image", "character/story/boss_%d.png" % int(stage["id"]))
		if t2 != null:
			return {"tex": t2, "art": true}
	return {"tex": icons.call("image", cls_img), "art": false}


func _commander() -> Variant:
	if typeof(roster) != TYPE_DICTIONARY or typeof(roster.get("chars")) != TYPE_ARRAY:
		return null
	for ch: Variant in roster["chars"]:
		if typeof(ch) == TYPE_DICTIONARY and ch.get("cls") == "commander":
			return ch
	return null


func commander_name() -> String:
	var ch: Variant = _commander()
	# 웹 story.js 와 같게: 지휘관 설정(setup) 전의 customName 은 로스터 생성 때 넣은 한국어 기본값 → 그 언어 대본의 이름
	if ch != null and Js.truthy(ch.get("setup")):
		if Js.truthy(ch.get("customName")):
			return str(ch["customName"])
		if Js.truthy(ch.get("name")):
			return str(ch["name"])
		var names: Variant = i18n.t_raw("character.names") if i18n != null else null
		if names is Array and ch.get("nameId") != null and int(ch["nameId"]) < (names as Array).size():
			return str(names[int(ch["nameId"])])
	var cast: Dictionary = data.get("cast", {})
	if typeof(cast.get("commander")) == TYPE_DICTIONARY and Js.truthy(cast["commander"].get("name")):
		return str(cast["commander"]["name"])
	return tr_or("story.commander", "")


func _commander_img() -> Texture2D:
	var ch: Variant = _commander()
	var f: bool = ch != null and ch.get("gender") == "f"
	if ch == null:
		return icons.call("image", "character/novice_%s.png" % ("02" if f else "01"))
	var t1: Texture2D = icons.call("image", "character/story/commander_%s.png" % ("f" if f else "m"))
	return t1 if t1 != null else icons.call("image", "character/commander_%s.png" % ("02" if f else "01"))


func _fmt(text: String) -> String:
	var ally := str(vars.get("ally", ""))
	if ally == "":
		ally = tr_or("story.ally", "")
	return text.replace("{commander}", commander_name()).replace("{ally}", ally)
