extends RefCounted
## 설정 값 규칙 — 전투 설정 창(scripts/battle/hud_settings.gd)과 바깥 설정 화면(scripts/ui/settings_screen.gd)이 같이 쓴다.
##  저장: Store game_settings (웹 settings.html · render.js saveSett 와 같은 키)
##   - 웹과 같은 키: bgmOn · bgmVol · sfxOn · sfxVol · language
##   - Godot 전용: playSpeed(연출 재생 배율 1·2·4) · reduceMotion
##   - 웹 설정 화면만 쓰는 speed(0.5~2.0 늘이기 배율)는 바꾸지 않음. playSpeed 가 없는 웹 세이브만 처음 한 번 speed 로 playSpeed 를 정함 (migrate_web_speed)
##  language 는 여기서 쓰지 않는다: 사용자가 언어를 직접 고를 때만 I18n.set_language 가 저장 (그 전에는 OS 언어 감지 — scripts/core/i18n.gd)
##  저장은 웹 saveSett 처럼 다른 화면이 쓴 값(language·speed 등)은 그대로 두고 이 표의 값만 덮어씀

const KEY := "game_settings"
const SPEEDS := [1, 2, 4]
## 기본값 (웹 settings.html loadSettings 의 bgm·sfx 기본값 + Godot 전용)
const DEFAULTS := {"bgmOn": true, "bgmVol": 0.5, "sfxOn": true, "sfxVol": 0.7, "playSpeed": 1, "reduceMotion": false}


static func defaults() -> Dictionary:
	return DEFAULTS.duplicate(true)


## 웹 세이브 옮기기 (디렉터 결정): playSpeed 가 없고 웹 speed(늘이기 배율)가 있으면 처음 읽을 때 한 번 정해 저장
##  speed ≤ 0.5 (웹에서 가장 빠름) → 2x, 그 밖은 1x. 웹 speed 값은 그대로 둠 → 바뀌었으면 true
static func migrate_web_speed(store: Object) -> bool:
	if store == null:
		return false
	var d: Variant = store.call("get_json", KEY, null)
	if not (d is Dictionary) or (d as Dictionary).has("playSpeed") or not (d as Dictionary).has("speed"):
		return false
	var sp: Variant = d["speed"]
	if typeof(sp) != TYPE_INT and typeof(sp) != TYPE_FLOAT:
		return false
	d["playSpeed"] = 2 if float(sp) <= 0.5 else 1
	store.call("set_json", KEY, d)
	return true


## 저장값을 s 에 덮어씀 (같은 종류의 값만 — 숫자는 int·float 서로 허용). playSpeed 가 1·2·4 가 아니면 1
static func load_into(store: Object, s: Dictionary) -> void:
	if store == null:
		return
	migrate_web_speed(store)
	var d: Variant = store.call("get_json", KEY, {})
	if d is Dictionary:
		for k: String in s.keys():
			if not (d as Dictionary).has(k):
				continue
			var v: Variant = d[k]
			var num_v := typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT
			var num_s := typeof(s[k]) == TYPE_FLOAT or typeof(s[k]) == TYPE_INT
			if typeof(v) == typeof(s[k]) or (num_v and num_s):
				s[k] = v
	if s.has("playSpeed") and not SPEEDS.has(int(s["playSpeed"])):
		s["playSpeed"] = 1


static func load_settings(store: Object) -> Dictionary:
	var s := defaults()
	load_into(store, s)
	return s


## s 의 값만 game_settings 에 덮어씀 (다른 키는 그대로)
static func save_from(store: Object, s: Dictionary) -> void:
	if store == null:
		return
	var cur: Variant = store.call("get_json", KEY, {})
	var d: Dictionary = cur if cur is Dictionary else {}
	for k: String in s.keys():
		d[k] = s[k]
	store.call("set_json", KEY, d)
