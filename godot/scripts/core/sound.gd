extends Node
## Sound — 배경음·효과음 한 곳 (웹 js/battle/audio.js 의 Audio). 오토로드 이름 Sound.
##
##  소리 파일: res://assets/audio/ (웹 audio.js 를 Chrome WebAudio 로 미리 구운 것 — tools/legacy-web/audio-bake/README.md)
##   - bgm_battle.wav : 전투 배경음 한 주기 (130 BPM 8분음표 512개 = 118.15초, 끝 → 처음이 이어지게 앞 주기 꼬리 포함, 가져오기에서 반복)
##   - sfx_<이름>.wav : 효과음 23개 (웹 sfxSelect … sfxKill, 직업별 공격 12개)
##  버스: Master ─┬ BGM (배경음)   ─ 음량 = bgmVol / BAKE_BGM_VOL
##               └ SFX (효과음)   ─ 음량 = sfxVol / BAKE_SFX_VOL, sfxOn 이 꺼지면 음소거
##        Master 는 창이 뒤로 갔을 때(bgAudio) 줄이기·끄기에만 씀.
##
##  장면 규칙 (웹과 같음 — 웹판에서 소리가 나는 곳은 전투 페이지뿐):
##   - 바깥 화면(로비·상점·설정 …): 소리 없음
##   - 전투: 로딩이 끝나면(이어하기는 바로) 전투 배경음 시작 (battle_scene 이 play_bgm("battle"))
##           보스 등장·웨이브에도 곡은 그대로 (웹에 보스 곡 없음)
##   - 전투 끝: 승리 → sfx victory, 패배·항복 → sfx defeat, 배경음은 0.6초 동안 줄어들며 멈춤 (웹 bgmStop)
##   - 화면을 떠나면(웹의 페이지 이동) 배경음·효과음 바로 끊음 (Router.screen_changed)
##   - 설정에서 배경음을 끄면 0.6초 줄어들며 멈춤, 다시 켜면(전투 중이고 끝나지 않았으면) 처음부터 (웹 setBGMOn)
##
##  설정 (Store game_settings): bgmOn · bgmVol · sfxOn · sfxVol (웹과 같은 키), bgAudio (Godot PC 전용: "play"·"lower"·"mute")
##   이상한 값은 sanitize() 가 기본값으로 (웹 기본 bgmVol 0.5 · sfxVol 0.7). Store 의 game_settings 가 바뀌면 바로 반영.

signal bgm_changed(id: String, playing: bool)

const DIR := "res://assets/audio/"
const SFX_NAMES := ["select", "move", "uiclick", "wait", "heal", "death", "explosion", "wave", "victory", "defeat", "kill",
	"atk_warrior", "atk_knight", "atk_assassin", "atk_mage", "atk_archer", "atk_priest", "atk_novice", "atk_brawler",
	"atk_lancer", "atk_sapper", "atk_summoner", "atk_shaman"]
## 웹 Audio.sfxAtk(cls) 의 표 — 표에 없는 직업(지휘관·적 전용 등)은 소리 없음 (웹과 같음)
const ATK_CLASSES := ["warrior", "knight", "assassin", "mage", "archer", "priest", "novice", "brawler", "lancer", "sapper", "summoner", "shaman"]
const BGM := {"battle": "bgm_battle.wav"}
## 구울 때의 음량: 효과음은 웹 기본 sfxVol 0.7 (웹에서 효과음 음량을 거치지 않는 소리도 웹 기본값과 똑같게), 배경음은 bgmVol 1 (웹 master 0.16 포함)
const BAKE_SFX_VOL := 0.7
const BAKE_BGM_VOL := 1.0
const FADE_OUT := 0.6
## 창이 뒤에 있을 때 '줄이기' 배율, 바뀌는 시간
const BG_LOWER := 0.25
const BG_FADE := 0.25
const BG_MODES := ["play", "lower", "mute"]
const SETTINGS_KEY := "game_settings"
const DEFAULTS := {"bgmOn": true, "bgmVol": 0.5, "sfxOn": true, "sfxVol": 0.7, "bgAudio": "lower"}
const POLYPHONY := 8

var settings: Dictionary = DEFAULTS.duplicate()
var _sfx: Dictionary = {}          # 이름 → AudioStreamPlayer
var _bgm: AudioStreamPlayer        # 지금 곡
var _bgm_id := ""                   # 지금 곡 이름 (멈췄으면 "")
var _want := ""                     # 지금 장면이 바라는 곡 ("" = 없음)
var _focused := true
var _master_tw: Tween
var _store: Node
## 시험·확인용: 최근 효과음 [ms, 이름] (최대 200개)과 이름별 횟수
var played: Array = []
var counts: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	for n: String in SFX_NAMES:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx_" + n
		p.bus = &"SFX"
		p.max_polyphony = POLYPHONY
		p.stream = load(DIR + "sfx_%s.wav" % n)
		add_child(p)
		_sfx[n] = p
	_store = get_node_or_null("/root/Store")
	if _store != null:
		_store.connect("changed", _on_store_changed)
	var router := get_node_or_null("/root/Router")
	if router != null and router.has_signal("screen_changed"):
		router.connect("screen_changed", _on_screen_changed)
	reload_settings()
	# 창이 처음부터 뒤에 떠 있으면(초점 없음) 알림이 오지 않으므로 실제 초점을 한 번 읽음
	if DisplayServer.get_name() != "headless":
		_sync_focus.call_deferred()


func _sync_focus() -> void:
	set_focused(DisplayServer.window_is_focused())


## BGM·SFX 버스가 없으면 만듦 (default_bus_layout.tres 가 있으면 이미 있음)
static func ensure_buses() -> void:
	for bn: String in ["BGM", "SFX"]:
		if AudioServer.get_bus_index(bn) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bn)
			AudioServer.set_bus_send(i, &"Master")


# ═══════════ 설정 ═══════════

## 이상한 값 → 기본값 (bool 이 아니면 기본, 숫자가 아니거나 NaN 이면 기본, 0~1 로 자름, bgAudio 는 세 값 중 하나)
static func sanitize(d: Variant) -> Dictionary:
	var s := DEFAULTS.duplicate()
	if not (d is Dictionary):
		return s
	for k: String in ["bgmOn", "sfxOn"]:
		if typeof(d.get(k)) == TYPE_BOOL:
			s[k] = d[k]
	for k2: String in ["bgmVol", "sfxVol"]:
		var v: Variant = d.get(k2)
		if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and not is_nan(float(v)):
			s[k2] = clampf(float(v), 0.0, 1.0)
	var bg: Variant = d.get("bgAudio")
	if typeof(bg) == TYPE_STRING and BG_MODES.has(bg):
		s["bgAudio"] = bg
	return s


func reload_settings() -> void:
	var raw: Variant = _store.call("get_json", SETTINGS_KEY, {}) if _store != null else {}
	apply_settings(sanitize(raw))


func _on_store_changed(key: String) -> void:
	if key == SETTINGS_KEY or key == "":
		reload_settings()


## 설정을 버스·곡에 반영 (웹 setBGMOn · setSFXOn · setBGMVol · setSFXVol)
func apply_settings(s: Dictionary) -> void:
	var was_on := bool(settings.get("bgmOn", true))
	settings = s.duplicate()
	_set_bus("BGM", float(s["bgmVol"]) / BAKE_BGM_VOL, false)
	_set_bus("SFX", float(s["sfxVol"]) / BAKE_SFX_VOL, not bool(s["sfxOn"]))
	if was_on and not bool(s["bgmOn"]):
		_stop_player(true)
	elif not was_on and bool(s["bgmOn"]) and _want != "" and _bgm_id == "":
		_start(_want)
	_apply_focus(false)


static func bus_linear(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	if i < 0 or AudioServer.is_bus_mute(i):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(i))


func _set_bus(bus: String, lin: float, mute: bool) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, mute or lin <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lin, 0.00001)))


# ═══════════ 창 초점 (PC) ═══════════

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			set_focused(false)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			set_focused(true)


func set_focused(on: bool) -> void:
	if _focused == on:
		return
	_focused = on
	_apply_focus(true)


## 창이 뒤에 있을 때 Master 배율 (play 1 · lower 0.25 · mute 0)
func focus_gain() -> float:
	if _focused:
		return 1.0
	match str(settings.get("bgAudio", "lower")):
		"play":
			return 1.0
		"mute":
			return 0.0
	return BG_LOWER


func _apply_focus(fade: bool) -> void:
	var g := focus_gain()
	var i := AudioServer.get_bus_index("Master")
	if _master_tw != null and _master_tw.is_valid():
		_master_tw.kill()
	if not fade or not is_inside_tree():
		_set_master(g)
		return
	var from := db_to_linear(AudioServer.get_bus_volume_db(i)) if not AudioServer.is_bus_mute(i) else 0.0
	_master_tw = create_tween()
	_master_tw.tween_method(_set_master, from, g, BG_FADE)


func _set_master(g: float) -> void:
	var i := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(i, g <= 0.0001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(g, 0.00001)))


# ═══════════ 배경음 ═══════════

## 곡 시작 (웹 bgmStart: 지금 곡은 줄이며 멈추고 처음부터 새로). 배경음이 꺼져 있으면 바라는 곡만 기억
func play_bgm(id: String) -> void:
	if not BGM.has(id):
		push_warning("Sound: 모르는 곡 %s" % id)
		return
	_want = id
	_stop_player(true)
	if bool(settings["bgmOn"]):
		_start(id)


## 곡 멈춤 (fade = 웹 bgmStop 의 0.6초 줄이기, false = 페이지 이동처럼 바로)
func stop_bgm(fade: bool = true) -> void:
	_want = ""
	_stop_player(fade)


func bgm_id() -> String:
	return _bgm_id


func bgm_wanted() -> String:
	return _want


func bgm_playing() -> bool:
	return _bgm != null and _bgm.playing


func bgm_position() -> float:
	return _bgm.get_playback_position() if bgm_playing() else 0.0


func _start(id: String) -> void:
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "Bgm_" + id
	_bgm.bus = &"BGM"
	_bgm.stream = load(DIR + str(BGM[id]))
	add_child(_bgm)
	_bgm.play()
	_bgm_id = id
	bgm_changed.emit(id, true)


func _stop_player(fade: bool) -> void:
	if _bgm == null:
		return
	var p := _bgm
	var id := _bgm_id
	_bgm = null
	_bgm_id = ""
	p.name = "Fading_" + id
	if not fade or not p.playing or not is_inside_tree():
		p.stop()
		p.queue_free()
	else:
		# 재생기에 묶은 Tween (재생기를 먼저 지우면 같이 멈춤). 웹 bgmStop: master gain 을 0.6초 동안 0 으로 (선형)
		var tw := p.create_tween()
		tw.tween_property(p, "volume_linear", 0.0, FADE_OUT).from(1.0)
		tw.tween_callback(p.stop)
		tw.tween_callback(p.queue_free)
	bgm_changed.emit(id, false)


func _on_screen_changed(name: String) -> void:
	# 웹: 페이지 이동이면 소리가 바로 끊김. 전투 장면은 들어가서 로딩 뒤에 곡을 엶
	stop_bgm(false)
	stop_all_sfx()
	for ch: Node in get_children():
		if str(ch.name).begins_with("Fading_"):
			(ch as AudioStreamPlayer).stop()
			ch.name = "Freed_" + str(ch.get_instance_id())
			ch.queue_free()


# ═══════════ 효과음 ═══════════

## 웹 Audio.sfx<이름>() — 이름은 SFX_NAMES (예: "select", "kill", "victory")
func sfx(name: String) -> void:
	var p: AudioStreamPlayer = _sfx.get(name)
	if p == null:
		push_warning("Sound: 모르는 효과음 %s" % name)
		return
	played.append([Time.get_ticks_msec(), name])
	if played.size() > 200:
		played.pop_front()
	counts[name] = int(counts.get(name, 0)) + 1
	if not bool(settings["sfxOn"]) or p.stream == null:
		return
	p.play()


## 웹 Audio.sfxAtk(cls) — 표에 없는 직업은 소리 없음
func sfx_atk(cls: String) -> void:
	if ATK_CLASSES.has(cls):
		sfx("atk_" + cls)


func stop_all_sfx() -> void:
	for p: AudioStreamPlayer in _sfx.values():
		p.stop()


## 시험용: 기록 지우기
func clear_log() -> void:
	played.clear()
	counts.clear()
