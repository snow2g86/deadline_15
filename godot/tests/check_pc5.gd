extends SceneTree
## 5단계 시험 — PC 출시 준비 (소리 · 화면 모드 · 플랫폼 구분 · 창 닫기 저장 · 내보내기 설정)
##   Godot --headless --path godot --script res://tests/check_pc5.gd   [-- --only files,audio,bgm,sfx,display,platform,close,lang,export]
##  1) files    : 소리 파일 24개 (효과음 23 · 배경음 1) — 형식·길이·배경음 반복(앞으로 반복, 한 주기 118.15초) · 버스 Master/BGM/SFX
##  2) audio    : 설정 저장·복원 (bgmOn·bgmVol·sfxOn·sfxVol·bgAudio) → 버스 음량 (BGM = bgmVol, SFX = sfxVol/0.7, 끄기 = 음소거),
##                창 초점(초점 잃음 알림 → 실제 Master 음량 1·0.25·0), 이상한 값 sanitize, 설정 화면 단추·밀대로 바꾸면 바로 반영
##  3) bgm      : 장면별 배경음 규칙 — 바깥 화면 11개는 없음 · 새 전투는 로딩 뒤 시작 · 이어하기는 바로 · 배경음 끄기/켜기 ·
##                항복(패배) → defeat + 0.6초 줄이며 멈춤 · 로비로 가면 없음
##  4) sfx      : 황금 기록 전투 6판(화면 입구) — 효과음 수가 웹 코드로 센 고정 표(tests/pc5_fixtures/sfx_web.json, tools/legacy-web/audio-bake/sfx-count.js)와 같음,
##                스킬 코드의 효과음 자리 수 = 웹 js/skills 의 G.sfx* 자리 수 (스킬마다)
##  5) display  : 화면 설정 gd_display 저장·복원 · sanitize · 창 크기 목록·처음 크기·최소 크기(1024×576)·모니터에 맞추기
##  6) platform : Platform.store() (기능 태그 → dev) · stove/steam/google/apple · PC 판 상점 광고 카드 숨김, 결제 카드 4개 그대로
##  7) close    : 전투 중 창 닫기 → 지금 엔진 상태로 이어하기 저장(gd_battle)이 디스크에 씀 → 다시 읽으면 '전투 재개'
##  8) lang     : 6개 언어 × 설정 화면(새 PC 항목 포함) · PC 판 상점 6개 탭 — 넘침 0 · 두부 0
##  9) export   : export_presets.cfg (Windows·macOS, stove 태그, 이름·회사·번들 ID·버전 연결, 거르기) · 사용자 폴더 설정 ·
##                build/ 에 내보낸 pck 가 있으면 그 안에 tests/·tools/·기준 데이터가 없고 data/·OFL.txt·소리가 있는지
##  Godot 오류(Logger 로 셈) 0 이어야 통과. 저장은 user://test_pc5_save.json (진짜 세이브는 건드리지 않음)

const BaselineData := preload("res://tests/baseline_data.gd")
const JsonX := preload("res://scripts/core/json_exact.gd")
const SettingsRules := preload("res://scripts/logic/settings_rules.gd")
const ResumeRules := preload("res://scripts/logic/resume_rules.gd")
const Flow := preload("res://scripts/ui/flow.gd")
const SoundT := preload("res://scripts/core/sound.gd")
const DisplayT := preload("res://scripts/core/display.gd")
const PlatformT := preload("res://scripts/core/platform.gd")
const FontsT := preload("res://scripts/core/fonts.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")
const StoreCtx := preload("res://scripts/logic/store_ctx.gd")

const SAVE := "user://test_pc5_save.json"
const BATTLE := "res://scenes/battle/battle.tscn"
const LANGS := ["ko", "en", "es", "ja", "zh-CN", "zh-TW"]
const OUTER := ["lobby", "stage_select", "party_select", "settings", "shop", "sanctuary", "academy", "compendium", "guide", "credits", "licenses"]
## 웹 js/skills/*.js 의 스킬마다 효과음 자리 (G.sfxAtk·sfxHeal·sfxMove·sfxUIClick·sfxExplosion 은 하나씩, 처치(sfxKill+sfxDeath)는 '처치 검사' 한 자리)
##  [소리 자리 수, 처치 검사 자리 수] — 범위 스킬은 대상 반복 안의 처치 검사 1자리
const WEB_SKILL_SFX := {
	"_x_warrior_powersmash": [1, 1], "_x_warrior_cleave": [1, 1], "_x_warrior_assault": [2, 1], "_x_warrior_criticalstrike": [1, 1],
	"_x_knight_switch": [1, 0], "_x_knight_charge": [1, 1], "_x_knight_sacrifice": [1, 0], "_x_knight_capture": [1, 0],
	"_x_assassin_assassinate": [1, 1], "_x_assassin_ambush": [1, 1], "_x_assassin_smoke": [1, 0],
	"_x_mage_fireburst": [1, 1], "_x_mage_freeze": [1, 1], "_x_mage_grandwall": [1, 0],
	"_x_archer_dash": [1, 0], "_x_archer_snipe": [1, 1], "_x_archer_rapidfire": [1, 1], "_x_archer_steelrain": [1, 1],
	"_x_priest_massheal": [1, 0], "_x_priest_purify": [1, 0], "_x_priest_sanctuary": [1, 0],
	"_x_novice_throw": [1, 1], "_x_novice_firstaid": [1, 0], "_x_novice_tackle": [1, 1],
	"_summon": [1, 0], "_x_summoner_empower": [1, 0], "_x_summoner_soulburst": [2, 1],
	"_x_shaman_curse": [1, 0], "_x_shaman_exalt": [1, 0], "_x_shaman_poisonmist": [1, 0], "_x_shaman_spiritsurge": [1, 1],
	"_x_brawler_disarm": [1, 0], "_x_brawler_flurry": [1, 1], "_x_brawler_crush": [1, 1],
	"_x_lancer_pierce": [1, 1], "_x_lancer_charge": [1, 1], "_x_lancer_phalanx": [1, 0],
	"_x_sapper_trap": [1, 0], "_x_sapper_excavate": [1, 0], "_x_sapper_detonate": [2, 1],
}

var _fails: Array = []
var _passes := 0
var _counter: ErrCounter
var store: Node
var i18n: Node
var router: Node
var sound: Node
var display: Node
var platform: Node
var _only: Array = []
var _stats: Dictionary = {}


class ErrCounter extends Logger:
	var errors: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	_counter = ErrCounter.new()
	OS.add_logger(_counter)
	_main.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
	else:
		_fails.append(what)
		print("  FAIL " + what)


func _stat(k: String, v: Variant) -> void:
	_stats[k] = v


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, secs: float = 3.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await process_frame
	return cond.call()


func _want(name: String) -> bool:
	return _only.is_empty() or _only.has(name)


func _near(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var oi := args.find("--only")
	if oi >= 0 and oi + 1 < args.size():
		_only = Array(args[oi + 1].split(","))
	BaselineData.apply(self)   # 황금 기록 명령이 맞도록 기준 데이터 (번역은 지금 데이터의 새 키를 더해 읽음)
	store = root.get_node("Store")
	i18n = root.get_node("I18n")
	router = root.get_node("Router")
	sound = root.get_node("Sound")
	display = root.get_node("Display")
	platform = root.get_node("Platform")
	store.call("use_path", SAVE)
	store.call("clear")
	i18n.call("reload")
	root.size = Vector2i(1280, 720)
	if _want("files"):
		print("── 1) 소리 파일 · 버스 ──")
		_files()
	if _want("audio"):
		print("── 2) 소리 설정 → 버스 ──")
		await _audio()
	if _want("bgm"):
		print("── 3) 장면별 배경음 규칙 ──")
		await _bgm()
	if _want("sfx"):
		print("── 4) 효과음 규칙 (엔진 사건 → 소리) ──")
		await _sfx()
	if _want("display"):
		print("── 5) 화면 설정 ──")
		_display()
	if _want("platform"):
		print("── 6) 플랫폼 구분 ──")
		await _platform()
	if _want("close"):
		print("── 7) 전투 중 창 닫기 → 이어하기 저장 ──")
		await _close()
	if _want("lang"):
		print("── 8) 6개 언어 넘침·두부 ──")
		await _langs()
	if _want("export"):
		print("── 9) 내보내기 설정 ──")
		_export()
	platform.call("override_store", "")
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	await _frames(2)
	_check(_counter.errors.is_empty(), "Godot 오류 0 (%d)" % _counter.errors.size())
	for e: String in _counter.errors.slice(0, 12):
		print("    " + e)
	var keys := _stats.keys()
	keys.sort()
	for k: String in keys:
		print("  STAT %s = %s" % [k, str(_stats[k])])
	if _fails.is_empty():
		print("RESULT: PASS (%d개 통과)" % _passes)
		quit(0)
	else:
		print("RESULT: FAIL (%d개 통과, %d개 실패)" % [_passes, _fails.size()])
		for f: String in _fails:
			print("  - " + f)
		quit(1)


# ═══════════ 1) 소리 파일 · 버스 ═══════════

func _files() -> void:
	var bad: Array = []
	var lens: Dictionary = {}
	for n: String in SoundT.SFX_NAMES:
		var st: Variant = load(SoundT.DIR + "sfx_%s.wav" % n)
		if not (st is AudioStreamWAV):
			bad.append(n)
			continue
		var w := st as AudioStreamWAV
		var L := w.get_length()
		lens[n] = snappedf(L, 0.001)
		if w.mix_rate != 44100 or w.format != AudioStreamWAV.FORMAT_16_BITS or w.stereo or L < 0.03 or L > 1.0 or w.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			bad.append("%s(%d Hz, 형식 %d, %.3fs, 반복 %d)" % [n, w.mix_rate, w.format, L, w.loop_mode])
	_check(bad.is_empty(), "효과음 23개: 44.1kHz 16비트 PCM 모노 · 0.03~1초 · 반복 없음 %s" % str(bad))
	_stat("files.sfx_len", lens)
	var bgm: Variant = load(SoundT.DIR + "bgm_battle.wav")
	var ok := bgm is AudioStreamWAV
	if ok:
		var b := bgm as AudioStreamWAV
		var T := 512.0 * 60.0 / 130.0 / 2.0
		_check(b.loop_mode == AudioStreamWAV.LOOP_FORWARD, "배경음 반복 = 앞으로 (가져오기 edit/loop_mode=2)")
		_check(absf(b.get_length() - T) < 0.001, "배경음 한 주기 = 130 BPM 8분음표 512개 %.4f초 (파일 %.4f초)" % [T, b.get_length()])
		_check(b.format == AudioStreamWAV.FORMAT_QOA and b.mix_rate == 44100, "배경음 QOA 압축 · 44.1kHz (가져오기 compress/mode=2)")
		_stat("files.bgm_len", snappedf(b.get_length(), 0.0001))
	_check(ok, "배경음 파일 bgm_battle.wav")
	var buses: Array = []
	for i in AudioServer.bus_count:
		buses.append(AudioServer.get_bus_name(i))
	_check(buses.slice(0, 3) == ["Master", "BGM", "SFX"], "버스 Master · BGM · SFX (default_bus_layout.tres) %s" % str(buses))
	_check(AudioServer.get_bus_send(1) == &"Master" and AudioServer.get_bus_send(2) == &"Master", "BGM·SFX → Master")
	_check(ProjectSettings.get_setting("audio/buses/default_bus_layout") == "res://default_bus_layout.tres", "project.godot 버스 배치")


# ═══════════ 2) 소리 설정 → 버스 ═══════════

func _bus(n: String) -> float:
	return SoundT.bus_linear(n)


func _audio() -> void:
	store.call("remove", "game_settings")
	await _frames(1)
	_check(_near(_bus("BGM"), 0.5) and _near(_bus("SFX"), 1.0) and _near(_bus("Master"), 1.0), "기본값: BGM 0.5 (웹 bgmVol 0.5) · SFX 1.0 (= sfxVol 0.7 / 구운 음량 0.7) · Master 1 (%.3f %.3f %.3f)" % [_bus("BGM"), _bus("SFX"), _bus("Master")])
	var s := SettingsRules.load_settings(store)
	s["bgmVol"] = 0.3
	s["sfxVol"] = 0.35
	SettingsRules.save_from(store, s)
	_check(_near(_bus("BGM"), 0.3) and _near(_bus("SFX"), 0.5), "음량 저장 → 버스 BGM 0.3 · SFX 0.35/0.7=0.5 (%.3f %.3f)" % [_bus("BGM"), _bus("SFX")])
	s["sfxOn"] = false
	SettingsRules.save_from(store, s)
	_check(_bus("SFX") == 0.0, "효과음 끄기 → SFX 음소거")
	s["sfxOn"] = true
	s["bgmVol"] = 0.0
	SettingsRules.save_from(store, s)
	_check(_bus("BGM") == 0.0 and _near(_bus("SFX"), 0.5), "배경음 음량 0 → BGM 음소거, 효과음 다시 켬")
	# 저장 → 디스크 → 다시 읽기 (게임을 다시 켠 것처럼)
	s["bgmVol"] = 0.8
	s["sfxVol"] = 0.7
	SettingsRules.save_from(store, s)
	SettingsRules.set_bg_audio(store, "mute")
	store.call("flush")
	store.call("use_path", "user://test_pc5_other.json")
	store.call("use_path", SAVE)
	sound.call("reload_settings")
	var ss: Dictionary = sound.get("settings")
	_check(_near(float(ss["bgmVol"]), 0.8) and _near(float(ss["sfxVol"]), 0.7) and ss["bgmOn"] == true and ss["sfxOn"] == true and ss["bgAudio"] == "mute",
		"저장 → 다시 읽기: 소리 설정 복원 %s" % str(ss))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_pc5_other.json"))
	var keys: Array = (store.call("get_json", "game_settings", {}) as Dictionary).keys()
	keys.sort()
	_check(keys == ["bgAudio", "bgmOn", "bgmVol", "playSpeed", "reduceMotion", "sfxOn", "sfxVol"], "game_settings 키: 웹·4a 키 + bgAudio(고를 때만) %s" % str(keys))
	# 창 초점: 진짜 알림(APPLICATION_FOCUS_OUT/IN)을 보내고 0.25초 바뀜이 끝난 뒤 Master 버스 음량을 잼 (기대값은 사양의 숫자)
	var want := {"play": 1.0, "lower": 0.25, "mute": 0.0}
	var focus_ok := true
	var seen: Dictionary = {}
	for m: String in want.keys():
		SettingsRules.set_bg_audio(store, m)
		sound.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await create_timer(0.4).timeout
		var g := _bus("Master")
		seen[m] = snappedf(g, 0.001)
		if not _near(g, float(want[m]), 0.01):
			focus_ok = false
		sound.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		await create_timer(0.4).timeout
		if not _near(_bus("Master"), 1.0, 0.01):
			focus_ok = false
			seen[m + "_back"] = _bus("Master")
	_check(focus_ok, "창이 뒤로(초점 잃음 알림) → Master 실제 음량 그대로 1 · 줄이기 0.25 · 끄기 0, 앞으로 오면 1 %s" % str(seen))
	SettingsRules.set_bg_audio(store, "lower")
	# 이상한 값
	var cases := [
		[{"bgmVol": "loud", "sfxVol": -2, "bgmOn": "x", "sfxOn": 1, "bgAudio": 5}, {"bgmVol": 0.5, "sfxVol": 0.0, "bgmOn": true, "sfxOn": true, "bgAudio": "lower"}],
		[{"bgmVol": 7, "sfxVol": 0.25, "bgAudio": "MUTE"}, {"bgmVol": 1.0, "sfxVol": 0.25, "bgmOn": true, "sfxOn": true, "bgAudio": "lower"}],
		[[1, 2], SoundT.DEFAULTS],
		["{bad", SoundT.DEFAULTS],
	]
	var weird_ok := true
	for c: Array in cases:
		var got: Dictionary = SoundT.sanitize(c[0])
		for k: String in (c[1] as Dictionary).keys():
			if str(got[k]) != str(c[1][k]):
				weird_ok = false
				print("    sanitize %s → %s" % [str(c[0]), str(got)])
				break
	_check(weird_ok, "이상한 소리 설정 → sanitize (문자열 음량·범위 밖·bool 아님·모르는 bgAudio·배열)")
	store.call("set_str", "game_settings", "{bad json")
	await _frames(1)
	_check(_near(_bus("BGM"), 0.5) and _near(_bus("SFX"), 1.0), "깨진 game_settings → 기본값 버스")
	SettingsRules.set_bg_audio(store, "bogus")
	_check(SettingsRules.bg_audio(store) == "lower", "set_bg_audio 모르는 값은 무시")
	store.call("remove", "game_settings")
	# 설정 화면: 단추·밀대로 바꾸면 바로 반영
	router.call("go", "settings")
	await _until(func() -> bool: return current_scene != null and str(current_scene.get_script().resource_path).ends_with("settings_screen.gd") and current_scene.is_node_ready(), 5.0)
	await _frames(3)
	var scr: Node = current_scene
	var b_mute: Button = scr.find_child("BgAudio_mute", true, false)
	var sl: HSlider = scr.find_child("Slider_bgmVol", true, false)
	var tg: CheckButton = scr.find_child("Toggle_sfxOn", true, false)
	_check(b_mute != null and sl != null and tg != null, "설정 화면: 창이 뒤에 있을 때 소리 단추 · 배경음 밀대 · 효과음 켜기")
	if b_mute != null and sl != null and tg != null:
		b_mute.pressed.emit()
		await _frames(2)
		sl = current_scene.find_child("Slider_bgmVol", true, false)
		sl.value = 20
		await _frames(1)
		tg = current_scene.find_child("Toggle_sfxOn", true, false)
		tg.button_pressed = false
		await _frames(2)
		_check(SettingsRules.bg_audio(store) == "mute" and _near(_bus("BGM"), 0.2) and _bus("SFX") == 0.0, "설정 화면 조작 → 저장 + 버스 바로 반영 (BGM %.3f SFX %.3f)" % [_bus("BGM"), _bus("SFX")])
		var b_mute2: Button = current_scene.find_child("BgAudio_mute", true, false)
		_check(b_mute2 != null and b_mute2.get_theme_stylebox("normal") != null and b_mute2.has_theme_stylebox_override("normal"), "고른 단추 강조")
	store.call("remove", "game_settings")
	router.call("go", "lobby")
	await _frames(4)


# ═══════════ 3) 장면별 배경음 규칙 ═══════════

func _golden_cmds(name: String) -> Array:
	var g: Dictionary = JsonX.parse(FileAccess.get_file_as_string("res://tests/golden/" + name + ".json"))
	var cmds: Array = []
	for e: Dictionary in g["events"]:
		if e["ev"] == "cmd":
			cmds.append(e)
	return cmds


## 황금 기록 하나를 실제 세이브 전투(source store)로
func _store_battle_cfg(name: String, speed: float) -> Dictionary:
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	var cfg: Dictionary = BS.call("golden_cfg", name)
	var keep_settings: Variant = store.call("get_json", "game_settings")
	store.call("clear")
	for k: String in (cfg["save"] as Dictionary).keys():
		store.call("set_json", k, cfg["save"][k])
	if keep_settings != null:
		store.call("set_json", "game_settings", keep_settings)
	cfg["save"] = BS.call("store_save", store)
	cfg["source"] = "store"
	cfg["speed"] = speed
	cfg["story"] = "off"
	cfg["loading"] = speed > 0.0
	return cfg


func _battle_scene() -> Node:
	var s := current_scene
	if s != null and s.get_script() != null and str((s.get_script() as Script).resource_path).ends_with("battle_scene.gd") and s.is_node_ready():
		return s
	return null


func _screen_is(tail: String) -> bool:
	var s := current_scene
	return s != null and s.get_script() != null and str((s.get_script() as Script).resource_path).ends_with(tail) and s.is_node_ready()


func _bgm() -> void:
	store.call("clear")
	sound.call("stop_bgm", false)
	# 바깥 화면: 소리 없음 (웹: 전투 페이지만 소리)
	var quiet := true
	for scr: String in OUTER:
		router.call("go", scr)
		await _frames(6)
		if str(sound.call("bgm_id")) != "" or str(sound.call("bgm_wanted")) != "":
			quiet = false
			print("    %s: 배경음 %s" % [scr, sound.call("bgm_id")])
	_check(quiet, "바깥 화면 %d개: 배경음 없음" % OUTER.size())
	# 새 전투: 로딩이 끝난 뒤 시작
	sound.call("clear_log")
	router.call("launch_battle", _store_battle_cfg("boss_s10", 4.0))
	await _until(func() -> bool: return _battle_scene() != null, 5.0)
	var bt := _battle_scene()
	_check(bt != null, "전투 장면 열림")
	if bt == null:
		return
	_check(bool(bt.get("_loading_on")) and str(sound.call("bgm_id")) == "", "로딩 중에는 배경음 없음 (웹: 로딩이 끝난 뒤 bgmStart)")
	await _until(func() -> bool: return not bool(bt.get("_loading_on")), 15.0)
	await _frames(2)
	_check(str(sound.call("bgm_id")) == "battle" and bool(sound.call("bgm_playing")), "로딩이 끝나면 전투 배경음")
	var p: AudioStreamPlayer = sound.get("_bgm")
	_check(p != null and p.bus == &"BGM" and (p.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "배경음은 BGM 버스 · 반복")
	# 웨이브·보스에도 같은 곡 (웹에 보스 곡 없음): 몇 차례 진행해도 같은 재생기
	var cmds := _golden_cmds("boss_s10")
	var ci := 0
	var p0: Variant = sound.get("_bgm")
	var frames := 0
	while ci < 6 and frames < 3000:
		await process_frame
		frames += 1
		if bt.is_awaiting() and bt.awaiting_unit_id() == int(cmds[ci]["u"]):
			if not _drive(bt, cmds[ci]):
				break
			ci += 1
	_check(ci >= 6 and sound.get("_bgm") == p0 and str(sound.call("bgm_id")) == "battle", "전투 진행(명령 %d개) 중 곡이 바뀌거나 다시 시작하지 않음" % ci)
	# 배경음 끄기 → 줄이며 멈춤, 켜기 → 처음부터 (웹 setBGMOn)
	var s := SettingsRules.load_settings(store)
	s["bgmOn"] = false
	SettingsRules.save_from(store, s)
	await _frames(1)
	_check(str(sound.call("bgm_id")) == "" and str(sound.call("bgm_wanted")) == "battle", "배경음 끄기 → 멈춤 (전투는 곡을 바람)")
	var fading := sound.find_child("Fading_battle", false, false)
	_check(fading != null, "끌 때 0.6초 줄이기 (웹 bgmStop linearRamp 0.6s)")
	s["bgmOn"] = true
	SettingsRules.save_from(store, s)
	await _frames(2)
	_check(str(sound.call("bgm_id")) == "battle" and float(sound.call("bgm_position")) < 1.0, "배경음 켜기 → 처음부터 다시")
	await create_timer(0.8).timeout
	_check(sound.find_child("Fading_battle", false, false) == null, "줄이기 끝나면 재생기 지움")
	# 항복 → 패배 효과음 + 배경음 줄이며 멈춤
	await _until(func() -> bool: return bt.is_awaiting(), 10.0)
	var d0 := int((sound.get("counts") as Dictionary).get("defeat", 0))
	bt.call("_do_surrender")
	await _until(func() -> bool: return bt.is_over(), 10.0)
	await _frames(2)
	_check(int((sound.get("counts") as Dictionary).get("defeat", 0)) == d0 + 1 and int((sound.get("counts") as Dictionary).get("victory", 0)) == 0, "항복 → defeat 효과음 1번")
	_check(str(sound.call("bgm_id")) == "" and str(sound.call("bgm_wanted")) == "" and sound.find_child("Fading_battle", false, false) != null, "전투 끝 → 배경음 0.6초 줄이며 멈춤")
	router.call("go", "lobby")
	await _until(func() -> bool: return _screen_is("ui/lobby.gd"), 5.0)
	await _frames(2)
	_check(str(sound.call("bgm_id")) == "" and sound.find_child("Fading_battle", false, false) == null, "로비로 → 배경음 없음 (줄이던 것도 바로 끊음 — 웹 페이지 이동)")
	# 이어하기: 들어오자마자 (웹 resumeBattle)
	router.call("launch_battle", _store_battle_cfg("boss_s10", 4.0))
	await _until(func() -> bool: return _battle_scene() != null, 5.0)
	bt = _battle_scene()
	await _until(func() -> bool: return bt.is_awaiting(), 20.0)
	bt.call("leave_battle")
	await _until(func() -> bool: return _screen_is("ui/lobby.gd"), 5.0)
	await _frames(2)
	_check(str(sound.call("bgm_id")) == "" and store.call("has", ResumeRules.KEY), "나가기 → 로비, 배경음 없음, 저장 전투 있음")
	var rc := Ctx.new(Ctx.globals_from_db(root.get_node("DataDB")), 1, StoreCtx.new(store))
	var gd: Variant = ResumeRules.load_gd(rc)
	if gd is Dictionary:
		router.call("launch_battle", Flow.resume_cfg(store, gd))
		await _until(func() -> bool: return _battle_scene() != null, 5.0)
		bt = _battle_scene()
		_check(bt != null and bool(bt.get("resumed")) and bool(bt.get("_loading_on")) and str(sound.call("bgm_id")) == "battle", "이어하기 → 로딩 중에 바로 배경음 (웹 resumeBattle)")
		router.call("go", "lobby")
		await _until(func() -> bool: return _screen_is("ui/lobby.gd"), 5.0)
	else:
		_check(false, "저장 전투 읽기")
	_check(str(sound.call("bgm_id")) == "", "로비 → 배경음 없음")
	# 속도 0(시험·즉시 재생)에서는 배경음을 켜지 않음
	store.call("clear")


# ═══════════ 4) 효과음 규칙 ═══════════

func _drive(scene: Node, cmd: Dictionary) -> bool:
	var op: String = cmd["op"]
	match op:
		"move", "shove":
			return scene.ui_action(op) and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"attack", "heal":
			return scene.ui_action("attack") and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"skill":
			if not (scene.ui_action("skill") and scene.ui_pick_skill(int(cmd["idx"]))):
				return false
			if scene.mode == "target":
				return scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
			return true
		"wait", "defend", "overwatch":
			return scene.ui_action(op) and scene.ui_pick_face(int(cmd["dx"]), int(cmd["dy"]))
		"undo":
			return scene.ui_action("undo")
		"potion":
			return scene.ui_action("item") and scene.ui_pick_item("potion", int(cmd["idx"])) and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"siege", "climb":
			return scene.ui_action("item") and scene.ui_pick_item("siege", int(cmd["idx"])) and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
	return false


func _sfx() -> void:
	# 스킬 코드의 효과음 자리 = 웹 스킬의 G.sfx* 자리
	var src := FileAccess.get_file_as_string("res://scripts/logic/battle/battle_skills.gd")
	var bad: Array = []
	for fn: String in WEB_SKILL_SFX.keys():
		var i := src.find("func %s(" % fn)
		if i < 0:
			bad.append(fn + " 없음")
			continue
		var j := src.find("\nfunc ", i + 5)
		var body := src.substr(i, (j if j > 0 else src.length()) - i)
		var n_sfx := body.count("_sfx(\"")
		var n_kill := body.count("_sfx_kill(")
		var want: Array = WEB_SKILL_SFX[fn]
		if n_sfx != int(want[0]) or n_kill != int(want[1]):
			bad.append("%s 소리 %d/%d 처치 %d/%d" % [fn, n_sfx, want[0], n_kill, want[1]])
	_check(bad.is_empty(), "스킬 %d개: 효과음 자리 = 웹 G.sfx* 자리 %s" % [WEB_SKILL_SFX.size(), str(bad)])
	var combat := FileAccess.get_file_as_string("res://scripts/logic/battle/combat.gd")
	_check(combat.contains("E.sfx(\"death\")"), "대신 맞은 클랜원 쓰러짐 → death (웹 _common.js applyDmg ctx.sfxDeath)")
	# 황금 기록 전투를 화면 입구로 (속도 0 = 즉시 재생) → 소리 수 비교
	var web_fx: Dictionary = JsonX.parse(FileAccess.get_file_as_string("res://tests/pc5_fixtures/sfx_web.json"))
	_check(web_fx.size() == 6, "웹 코드로 센 효과음 표 (tools/legacy-web/audio-bake/sfx-count.js) 시나리오 6개")
	var total := 0
	var names_all: Dictionary = {}
	for gname: String in ["boss_s10", "knights_s11", "mono_archer_s07", "assassins_s06", "siege_items_s13", "loss_s30"]:
		var cfg := _store_battle_cfg(gname, 0.0)
		cfg["log_events"] = true
		var cmds := _golden_cmds(gname)
		sound.call("clear_log")
		var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
		BS.set("pending", cfg)
		var bt: Node = (load(BATTLE) as PackedScene).instantiate()
		root.add_child(bt)
		var ci := 0
		var frames := 0
		var sent: Dictionary = {}
		var ally_turns := 0
		while frames < 60000:
			await process_frame
			frames += 1
			if bt.is_over():
				break
			if not bt.is_awaiting() or ci >= cmds.size():
				continue
			if bt.awaiting_unit_id() != int(cmds[ci]["u"]):
				break
			var before: Dictionary = bt.eng.awaiting_unit().duplicate()
			if not _drive(bt, cmds[ci]):
				break
			if bool(bt.last_result.get("ok", false)):
				var op := str(cmds[ci]["op"])
				var key: String = {"move": "move", "wait": "wait", "defend": "wait", "overwatch": "wait", "undo": "uiclick"}.get(op, "")
				if key != "":
					sent[key] = int(sent.get(key, 0)) + 1
			ci += 1
		await _until(func() -> bool: return bt.is_over(), 5.0)
		for it: Array in bt.ev_log:
			if it[0] == "bus" and it[1] == "turn_start" and it[2]["unit"].get("team") == "ally" and str(it[2].get("phase", "player")) == "player":
				ally_turns += 1
		var want: Dictionary = (web_fx.get(gname, {}) as Dictionary).duplicate()
		var sel_web := int(want.get("select", 0))
		want.erase("select")
		var got: Dictionary = (sound.get("counts") as Dictionary).duplicate()
		var sel := int(got.get("select", 0))
		got.erase("select")
		var diff: Array = []
		for k: String in want.keys():
			if int(got.get(k, 0)) != int(want[k]):
				diff.append("%s 웹 %d ≠ %d" % [k, want[k], got.get(k, 0)])
		for k2: String in got.keys():
			if not want.has(k2):
				diff.append("%s 나옴 %d (웹 0)" % [k2, got[k2]])
		_check(not want.is_empty() and diff.is_empty() and bt.is_over(), "%s: 명령 %d/%d · 효과음 %d번 = 웹 코드로 센 표(tests/pc5_fixtures/sfx_web.json) %s" % [gname, ci, cmds.size(), _sum(got), str(diff)])
		# select 는 웹 시험 정책이 클랜원을 누르는 횟수(selU)에 달려 표와 같을 수 없음 — 차례마다 1번 이상, 웹 수 이하
		_check(sel >= 1 and sel <= ally_turns + int(sent.get("uiclick", 0)) and sel <= sel_web, "%s: select %d번 (아군 차례 %d · 이동 취소 %d, 웹 시험 %d)" % [gname, sel, ally_turns, int(sent.get("uiclick", 0)), sel_web])
		total += _sum(got) + sel
		for k3: String in got.keys():
			names_all[k3] = int(names_all.get(k3, 0)) + int(got[k3])
		bt.queue_free()
		await _frames(2)
	_stat("sfx.total", total)
	_stat("sfx.by_name", names_all)
	var used: Array = names_all.keys()
	_check(used.size() >= 12, "여러 효과음이 실제로 쓰임 (%d가지)" % used.size())
	store.call("clear")


func _sum(d: Dictionary) -> int:
	var n := 0
	for v: Variant in d.values():
		n += int(v)
	return n


# ═══════════ 5) 화면 설정 ═══════════

func _display() -> void:
	# sanitize
	var cases := [
		[{"mode": "fullscreen", "w": 1600, "h": 900, "x": 10, "y": -20}, {"mode": "fullscreen", "w": 1600, "h": 900, "x": 10, "y": -20}],
		[{"mode": "exclusive", "w": 500, "h": 300}, {"mode": "windowed", "w": 1024, "h": 576}],
		[{"mode": 3, "w": "big", "h": 900, "x": 1.5, "y": 2}, {"mode": "windowed"}],
		[{"w": 99999, "h": 1e9}, {"mode": "windowed"}],
		[{"w": 99999, "h": 40000}, {"mode": "windowed", "w": 16384, "h": 16384}],
		[[1, 2], {"mode": "windowed"}],
		["x", {"mode": "windowed"}],
	]
	var bad: Array = []
	for c: Array in cases:
		var got: Dictionary = DisplayT.sanitize(c[0])
		if JsonX.stringify(got) != JsonX.stringify(c[1]):
			bad.append("%s → %s" % [str(c[0]), str(got)])
	_check(bad.is_empty(), "gd_display sanitize (모드·크기 최소/최대·정수 아님·위치 반쪽) %s" % str(bad))
	# 크기 목록 · 처음 크기 · 맞추기
	_check(DisplayT.sizes_fitting(Vector2i(1366, 728)) == [Vector2i(1024, 576), Vector2i(1280, 720)], "1366×768 노트북(작업 영역 1366×728): 1024×576 · 1280×720")
	_check(DisplayT.sizes_fitting(Vector2i(1728, 1084)).size() == 4, "맥북 레티나(1728×1084 포인트): 4가지 (1600×900 까지)")
	_check(DisplayT.sizes_fitting(Vector2i(800, 500)) == [Vector2i(1024, 576)], "작업 영역이 최소보다 작아도 최소 하나")
	_check(DisplayT.default_size(Vector2i(1366, 728)) == Vector2i(1024, 576) and DisplayT.default_size(Vector2i(1920, 1040)) == Vector2i(1366, 768)
		and DisplayT.default_size(Vector2i(1728, 1084)) == Vector2i(1366, 768) and DisplayT.default_size(Vector2i(3840, 2100)) == Vector2i(2560, 1440),
		"처음 크기 = 작업 영역 80% 안의 가장 큰 크기 (1366→1024×576, 1080p→1366×768, 레티나 1728×1084→1366×768, 4K→2560×1440)")
	_check(DisplayT.fit_size(Vector2i(2560, 1440), Vector2i(1920, 1040)) == Vector2i(1848, 1040), "모니터보다 큰 저장 크기 → 비율 유지하며 줄임")
	_check(DisplayT.fit_size(Vector2i(1024, 576), Vector2i(800, 500)) == Vector2i(1024, 576), "최소 1024×576 보다 작게 줄이지 않음")
	_check(DisplayT.MIN_LOGICAL == Vector2i(1024, 576), "최소 창 크기 1024×576 (논리)")
	# 다른 배율 모니터 (값 주입): 레티나(배율 2) + 외부 1080p(배율 1). macOS 의 Godot 은 두 모니터 모두 '포인트 × 가장 큰 배율 2' 단위로 알려 줌
	#  → 외부 1080p 작업 영역 1920×1050 포인트 = Godot 3840×2100 단위. 논리(포인트) = 단위 ÷ 2 여야 함 (모니터별 배율 1 로 나누면 3840×2100 → 크기 단추가 2560×1440 까지 나오던 버그)
	var mac_sc := DisplayT.units_scale("macOS", 2.0)
	var ext := DisplayT.logical_of(Vector2i(3840, 2100), mac_sc)
	var ret := DisplayT.logical_of(Vector2i(3456, 2168), mac_sc)
	_check(mac_sc == 2.0 and ext == Vector2i(1920, 1050) and ret == Vector2i(1728, 1084), "macOS 레티나+외부 1080p: 두 모니터 모두 ÷2 → 외부 %s · 레티나 %s 포인트" % [str(ext), str(ret)])
	_check(DisplayT.sizes_fitting(ext).back() == Vector2i(1600, 900) and DisplayT.sizes_fitting(ext).size() == 4, "외부 1080p 의 가장 큰 크기 단추 1600×900 (2560×1440 아님)")
	_check(Vector2i(Vector2(1280, 720) * mac_sc) == Vector2i(2560, 1440) and Vector2i(Vector2(DisplayT.MIN_LOGICAL) * mac_sc) == Vector2i(2048, 1152),
		"외부 1080p 에서도 '1280×720' = Godot 2560×1440 단위 = 실제 1280×720 포인트, 최소 2048×1152 단위 (절반이 아님)")
	_check(DisplayT.units_scale("macOS", 1.0) == 1.0 and DisplayT.units_scale("Windows", 2.0) == 1.0 and DisplayT.units_scale("Linux", 1.5) == 1.0,
		"배율 없는 맥(1) · Windows·Linux 는 픽셀 그대로(1)")
	# 전체 화면 판정 (창이 화면을 덮는지를 프레임마다 주입, 1/60초)
	var run_fs := func(seq: Array) -> String:
		var st := {"left": DisplayT.FS_CHECK, "stable": 0.0}
		var i := 0
		while true:
			var full: bool = seq[i] if i < seq.size() else seq.back()
			var v := DisplayT.fs_step(st, full, 1.0 / 60.0)
			if v != "":
				return "%s@%.2f" % [v, (i + 1) / 60.0]
			i += 1
		return ""
	var one_frame := [false, true]
	for k in 300:
		one_frame.append(false)
	var r1: String = run_fs.call(one_frame)
	var anim: Array = []
	for k in 40:
		anim.append(false)   # macOS 전체 화면 애니메이션 약 0.7초
	anim.append(true)
	var r2: String = run_fs.call(anim)
	var flicker: Array = []
	for k in 300:
		flicker.append(k % 20 < 18)   # 0.3초마다 한 번씩 작아짐 → 0.5초 연속이 안 됨
	var r3: String = run_fs.call(flicker)
	_check(r1.begins_with("revert@4.0"), "전체 화면 판정: 요청 직후 한 프레임만 큰 경우 → 4초 뒤 되돌림 (%s)" % r1)
	_check(r2.begins_with("keep@1.1") or r2.begins_with("keep@1.2"), "전체 화면 판정: 0.7초 뒤부터 계속 큰 경우 → 0.5초 연속 뒤 유지 (%s)" % r2)
	_check(r3.begins_with("revert"), "전체 화면 판정: 0.5초를 못 넘기고 계속 작아지는 경우 → 되돌림 (%s)" % r3)
	# 저장 → 다시 읽기 (머리 없는 실행: 창은 건드리지 않고 값만)
	store.call("remove", DisplayT.KEY)
	display.set("cfg", DisplayT.sanitize({}))
	display.call("set_window_size", Vector2i(1600, 900))
	display.call("set_mode", "fullscreen")
	store.call("flush")
	store.call("use_path", "user://test_pc5_other.json")
	store.call("use_path", SAVE)
	var back: Dictionary = DisplayT.sanitize(store.call("get_json", DisplayT.KEY, {}))
	_check(back.get("mode") == "fullscreen" and int(back.get("w", 0)) == 1600 and int(back.get("h", 0)) == 900, "화면 모드·창 크기 저장 → 다시 읽기 %s" % str(back))
	display.call("set_mode", "windowed")
	display.call("set_window_size", Vector2i(800, 450))
	var c2: Dictionary = display.get("cfg")
	_check(int(c2["w"]) == 1024 and int(c2["h"]) == 576 and display.call("window_logical_size") == Vector2i(1024, 576), "최소보다 작은 크기 요청 → 1024×576")
	display.call("set_mode", "bogus")
	_check(str(display.call("mode")) == "windowed", "모르는 모드는 무시")
	store.call("set_json", DisplayT.KEY, {"mode": ["x"], "w": "1"})
	_check(DisplayT.sanitize(store.call("get_json", DisplayT.KEY, {})) == {"mode": "windowed"}, "이상한 gd_display → 기본")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_pc5_other.json"))
	store.call("remove", DisplayT.KEY)
	_check(not bool(display.get("active")) and not bool(display.get("managed")), "머리 없는 실행: Display 는 창을 건드리지 않음")


# ═══════════ 6) 플랫폼 ═══════════

func _platform() -> void:
	_check(PlatformT.detect_store() == "dev" and str(platform.call("store")) == "dev", "기능 태그 없음(편집기·명령줄) → dev")
	_check(bool(platform.call("is_pc")) == OS.has_feature("pc"), "is_pc = 기능 태그 pc")
	var want := {"stove": [true, false, false], "steam": [true, false, false], "google": [false, true, true], "apple": [false, true, true], "dev": [OS.has_feature("pc"), false, true]}
	var bad: Array = []
	for st: String in want.keys():
		platform.call("override_store", st)
		var got := [bool(platform.call("is_pc")), bool(platform.call("is_mobile")), bool(platform.call("has_ads"))]
		if str(platform.call("store")) != st or got != want[st] or not bool(platform.call("has_iap")):
			bad.append("%s %s" % [st, str(got)])
	platform.call("override_store", "nintendo")
	if str(platform.call("store")) != "dev":
		bad.append("모르는 이름")
	_check(bad.is_empty(), "가게 5가지: PC(stove·steam) 광고 없음 · 모바일(google·apple) 광고 · dev 는 웹 화면 그대로 %s" % str(bad))
	_check(PlatformT.STORES == ["stove", "steam", "google", "apple", "dev"], "가게 이름 목록")
	# 상점: PC 판은 광고 카드 없음, 결제 카드 4개 그대로
	store.call("clear")
	store.call("set_json", "game_save", {"gold": 50000.0, "cleared": [1, 2, 3]})
	for st2: String in ["stove", "dev"]:
		platform.call("override_store", st2)
		platform.call("override_os", "Windows")   # (결제층 A) 결제 카드는 STOVE Windows 판 기준 (맥 판은 결제 길이 없어 숨김 — check_iap)
		router.call("go", "shop")
		await _until(func() -> bool: return _screen_is("ui/shop.gd"), 5.0)
		await _frames(3)
		var shop: Node = current_scene
		var ads := 0
		var tabs := 0
		for tab: String in ["mercenary", "consumable", "equip", "skill", "scroll", "gold"]:
			shop.call("switch_tab", tab)
			await _frames(2)
			tabs += 1
			if shop.find_child("AdCard", true, false) != null:
				ads += 1
		var iap: Node = shop.find_child("IapGrid", true, false)
		var n_iap := iap.get_child_count() if iap != null else 0
		if st2 == "stove":
			_check(ads == 0 and n_iap == 4, "PC 판(stove) 상점: 광고 카드 0 (탭 %d개) · 결제 카드 %d개 그대로" % [tabs, n_iap])
		else:
			_check(ads == 6 and n_iap == 4, "dev 판 상점: 광고 카드 탭마다 (%d/6) — 웹 화면 그대로 · 결제 카드 %d개" % [ads, n_iap])
		router.call("go", "lobby")
		await _frames(4)
	platform.call("override_store", "")
	platform.call("override_os", "")
	store.call("clear")


# ═══════════ 7) 창 닫기 → 이어하기 저장 ═══════════

func _saved_on_disk() -> Dictionary:
	var raw := FileAccess.get_file_as_string(ProjectSettings.globalize_path(SAVE))
	var d: Variant = JsonX.parse(raw) if raw != "" else null
	return d if d is Dictionary else {}


func _close() -> void:
	var cfg := _store_battle_cfg("boss_s10", 1.0)
	cfg["loading"] = false
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	BS.set("pending", cfg)
	var bt: Node = (load(BATTLE) as PackedScene).instantiate()
	root.add_child(bt)
	current_scene = bt
	var cmds := _golden_cmds("boss_s10")
	await _until(func() -> bool: return bt.is_awaiting(), 20.0)
	var ok: bool = bt.is_awaiting()
	# 첫 입력 대기에 자동 저장됨 (4b-1)
	store.call("flush")
	var a0 := int(bt.get("autosaves"))
	var gd0: Variant = _saved_on_disk().get(ResumeRules.KEY)
	_check(ok and a0 >= 1 and gd0 != null, "입력 대기 → 자동 저장 (디스크에 gd_battle)")
	# 명령을 넣고 연출이 끝나기 전(엔진은 이미 다음 입력 대기) 창 닫기
	var sent := 0
	var closed_ok := false
	for i in 4:
		await _until(func() -> bool: return bt.is_awaiting(), 20.0)
		if not bt.is_awaiting() or bt.awaiting_unit_id() != int(cmds[sent]["u"]):
			break
		if not _drive(bt, cmds[sent]):
			break
		sent += 1
	# 마지막 명령 직후 — 연출 대기열이 남아 있고 엔진은 입력 대기
	var act_engine := int(bt.eng.S["actCount"])
	var busy := str(bt.get("mode")) == "busy"
	auto_accept_quit = false
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await _frames(1)
	var disk := _saved_on_disk()
	var gd_raw: Variant = disk.get(ResumeRules.KEY)
	if gd_raw != null:
		var gd: Variant = JsonX.parse(str(gd_raw))
		if gd is Dictionary:
			var st: Dictionary = gd["state"]
			var s_act := int(st.get("S", {}).get("actCount", -1)) if st.get("S") is Dictionary else -1
			closed_ok = int(bt.get("close_saves")) == 1 and (s_act == act_engine or s_act == -1)
			_stat("close.state_act", s_act)
	_stat("close.engine_act", act_engine)
	_check(sent >= 2 and busy and closed_ok, "명령 %d개 뒤 연출 중(%s) 창 닫기 → 지금 엔진 상태(actCount %d)를 디스크에 저장" % [sent, str(busy), act_engine])
	# 다시 켠 것처럼 → 로비 '전투 재개'
	store.call("use_path", "user://test_pc5_other.json")
	store.call("use_path", SAVE)
	var rc := Ctx.new(Ctx.globals_from_db(root.get_node("DataDB")), 1, StoreCtx.new(store))
	_check(ResumeRules.status(rc) == "gd", "다시 읽기 → 로비 '전투 재개' (ResumeRules.status gd)")
	# 끝난 전투는 저장하지 않음
	bt.set("_over", true)
	_check(not bool(bt.call("save_on_close")), "끝난 전투는 창 닫기 저장 안 함")
	bt.set("_over", false)
	bt.queue_free()
	current_scene = null
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_pc5_other.json"))
	store.call("clear")


# ═══════════ 8) 6개 언어 ═══════════

func _audit(scr: Node, lang: String) -> Array:
	var overflow: Array = []
	var tofu: Array = []
	var n := 0
	var vr := root.get_visible_rect()
	var stack: Array = [scr]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is Control and not (nd as Control).is_visible_in_tree():
			continue
		if nd.get_meta("overflow_ok", false):
			continue
		stack.append_array(nd.get_children())
		if not (nd is Control):
			continue
		var ctl := nd as Control
		var txt := ""
		if ctl is Label:
			txt = (ctl as Label).text
		elif ctl is Button:
			txt = (ctl as Button).text
		elif ctl is RichTextLabel:
			txt = (ctl as RichTextLabel).get_parsed_text()
		if txt != "":
			n += 1
			for i in txt.length():
				var cp := txt.unicode_at(i)
				if cp < 32 or cp == 0x200B:
					continue
				if not FontsT.chain_has_char(lang, cp):
					tofu.append("%s '%s' U+%04X" % [ctl.get_path(), txt.substr(0, 20), cp])
					break
		if ctl is Label:
			var l := ctl as Label
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF and not l.clip_text and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
				if l.get_minimum_size().x > l.size.x + 1.0:
					overflow.append("%s 좁음 '%s'" % [ctl.get_path(), l.text.substr(0, 24)])
		var par := ctl.get_parent() as Control
		if par != null and not (par is ScrollContainer) and ctl.size.x > 0.0:
			var pr := par.get_global_rect().grow(3.0)
			var r := ctl.get_global_rect()
			if not pr.encloses(r) and r.size.x > 0.0:
				overflow.append("%s 부모 밖 '%s'" % [ctl.get_path(), txt.substr(0, 20)])
		if txt != "":
			var r2 := ctl.get_global_rect()
			var in_scroll := false
			var a: Node = ctl.get_parent()
			while a != null:
				if a is ScrollContainer:
					in_scroll = true
					var sr := (a as Control).get_global_rect().grow(2.0)
					if r2.position.x < sr.position.x or r2.end.x > sr.end.x:
						overflow.append("%s 스크롤 가로 밖 '%s'" % [ctl.get_path(), txt.substr(0, 20)])
					break
				a = a.get_parent()
			if not in_scroll and not vr.grow(1.0).encloses(r2):
				overflow.append("%s 화면 밖 '%s'" % [ctl.get_path(), txt.substr(0, 20)])
	return [overflow, tofu, n]


func _langs() -> void:
	var problems: Array = []
	var total := 0
	store.call("clear")
	store.call("set_json", "game_save", {"gold": 1234567.0, "cleared": range(1, 46)})
	platform.call("override_store", "stove")
	for lang: String in LANGS:
		i18n.call("_apply", lang)
		for w: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 576)]:
			root.size = w
			router.call("go", "settings")
			await _until(func() -> bool: return _screen_is("ui/settings_screen.gd"), 5.0)
			await _frames(4)
			var has_pc := current_scene.find_child("ModeRow", true, false) != null and current_scene.find_child("BgAudioRow", true, false) != null and current_scene.find_child("SizeGrid", true, false) != null
			if not has_pc:
				problems.append("[%s settings] PC 항목 없음" % lang)
			var r: Array = _audit(current_scene, lang)
			total += int(r[2])
			for o: String in r[0]:
				problems.append("[%s %dx%d settings] 넘침 %s" % [lang, w.x, w.y, o])
			for tf: String in r[1]:
				problems.append("[%s settings] 두부 %s" % [lang, tf])
		root.size = Vector2i(1280, 720)
		router.call("go", "shop")
		await _until(func() -> bool: return _screen_is("ui/shop.gd"), 5.0)
		await _frames(3)
		for tab: String in ["mercenary", "consumable", "equip", "skill", "scroll", "gold"]:
			current_scene.call("switch_tab", tab)
			await _frames(3)
			var r2: Array = _audit(current_scene, lang)
			total += int(r2[2])
			for o2: String in r2[0]:
				problems.append("[%s shop %s] 넘침 %s" % [lang, tab, o2])
			for tf2: String in r2[1]:
				problems.append("[%s shop %s] 두부 %s" % [lang, tab, tf2])
		router.call("go", "lobby")
		await _frames(3)
	for p: String in problems.slice(0, 30):
		print("    " + p)
	_check(problems.is_empty(), "6개 언어 × 설정(1280×720·1024×576, PC 항목 포함) · PC 판 상점 6개 탭: 넘침 0 · 두부 0 (글자 부품 %d개, 문제 %d)" % [total, problems.size()])
	_stat("lang.text_controls", total)
	platform.call("override_store", "")
	i18n.call("_apply", "ko")
	root.size = Vector2i(1280, 720)
	store.call("clear")


# ═══════════ 9) 내보내기 설정 ═══════════

## Godot 4 PCK(형식 3) 안 파일 경로 목록 (없거나 읽지 못하면 null). macOS 는 zip 안의 .app 에서 꺼내 읽음
static func pck_paths(path: String) -> Variant:
	var buf := PackedByteArray()
	if path.ends_with(".zip"):
		var z := ZIPReader.new()
		if z.open(path) != OK:
			return null
		for f2: String in z.get_files():
			if f2.ends_with(".pck"):
				buf = z.read_file(f2)
				break
		z.close()
	elif FileAccess.file_exists(path):
		buf = FileAccess.get_file_as_bytes(path)
	if buf.size() < 128:
		return null
	var sp := StreamPeerBuffer.new()
	sp.data_array = buf
	if sp.get_u32() != 0x43504447:   # "GDPC"
		return null
	var ver := sp.get_u32()
	for i in 3:
		sp.get_u32()
	sp.get_u32()   # flags
	sp.get_u64()   # file base
	if ver < 3:
		return null
	var diro := sp.get_u64()
	sp.seek(diro)
	var n := sp.get_u32()
	var out: Array = []
	for i in n:
		var l := sp.get_u32()
		var raw: Array = sp.get_data(l)
		out.append((raw[1] as PackedByteArray).get_string_from_utf8())
		sp.get_u64()
		sp.get_u64()
		sp.get_data(16)
		sp.get_u32()
	return out


## 빌드에 들어가는 소스 중 t(초) 보다 나중에 고친 파일 (res:// 기준 경로)
func _newer_sources(t: int) -> Array:
	var out: Array = []
	for f: String in ["project.godot", "export_presets.cfg", "default_bus_layout.tres", "icon.png"]:
		if FileAccess.get_modified_time("res://" + f) > t:
			out.append(f)
	var stack: Array = ["res://scripts", "res://scenes", "res://data", "res://assets", "res://addons"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		var da := DirAccess.open(d)
		if da == null or FileAccess.file_exists(d + "/.gdignore"):
			continue
		for sub: String in da.get_directories():
			stack.append(d + "/" + sub)
		for f2: String in da.get_files():
			if f2.ends_with(".prev.png") or f2.ends_with(".md") or f2.ends_with(".uid"):
				continue
			if FileAccess.get_modified_time(d + "/" + f2) > t:
				out.append((d + "/" + f2).trim_prefix("res://"))
	return out


func _export() -> void:
	var cf := ConfigFile.new()
	_check(cf.load("res://export_presets.cfg") == OK, "export_presets.cfg 읽기")
	var presets: Dictionary = {}
	for sec: String in cf.get_sections():
		# PC 프리셋만 (6a 의 Android·iOS 프리셋은 tests/check_mobile6a.gd 가 봄)
		if sec.begins_with("preset.") and not sec.ends_with(".options") and ["Windows Desktop", "macOS"].has(str(cf.get_value(sec, "platform"))):
			presets[str(cf.get_value(sec, "platform"))] = sec
	_check(presets.has("Windows Desktop") and presets.has("macOS"), "프리셋: Windows Desktop · macOS %s" % str(presets.keys()))
	for plat: String in presets.keys():
		var sec: String = presets[plat]
		var opt := sec + ".options"
		var inc := str(cf.get_value(sec, "include_filter", ""))
		var exc := str(cf.get_value(sec, "exclude_filter", ""))
		_check(str(cf.get_value(sec, "custom_features")).split(",").has("stove"), "%s: 기능 태그 stove" % plat)
		_check(inc.contains("data/*") and inc.contains("data/lang/*") and inc.contains("data/story/*") and inc.contains("assets/fonts/*.txt"), "%s: 넣기 data/* · assets/fonts/*.txt (OFL)" % plat)
		_check(exc.contains("tests/*") and exc.contains("tools/*") and exc.contains("build/*"), "%s: 빼기 tests/* · tools/* · build/*" % plat)
		_check(str(cf.get_value(sec, "export_path")).begins_with("build/"), "%s: 결과물은 build/" % plat)
		if plat == "macOS":
			_check(str(cf.get_value(opt, "binary_format/architecture")) == "universal" and str(cf.get_value(opt, "application/bundle_identifier")) == "xyz.show4you.deadline15"
				and str(cf.get_value(opt, "application/short_version")) == "" and str(cf.get_value(opt, "application/version")) == "" and int(cf.get_value(opt, "notarization/notarization")) == 0,
				"macOS: universal · 번들 ID xyz.show4you.deadline15 · 버전 = project config/version (빈칸) · 공증 안 함")
		else:
			_check(str(cf.get_value(opt, "binary_format/architecture")) == "x86_64" and str(cf.get_value(opt, "application/company_name")) == "show4you"
				and str(cf.get_value(opt, "application/product_name")) == "DEADLINE 15" and str(cf.get_value(opt, "application/file_version")) == ""
				and str(cf.get_value(opt, "application/product_version")) == "" and not bool(cf.get_value(opt, "codesign/enable")),
				"Windows: x86_64 · 회사 show4you · 제품 DEADLINE 15 · 버전 = project config/version (빈칸) · 서명 안 함")
	_check(str(ProjectSettings.get_setting("application/config/name")) == "DEADLINE 15" and str(ProjectSettings.get_setting("application/config/version")) != "", "게임 이름·버전 (project.godot)")
	var pg := ConfigFile.new()
	pg.load("res://project.godot")
	_check(pg.get_value("application", "config/use_custom_user_dir.template", false) == true and pg.get_value("application", "config/use_custom_user_dir", true) == false
		and str(pg.get_value("application", "config/custom_user_dir_name", "")) == "DEADLINE 15",
		"사용자 폴더: 내보낸 빌드(template)만 'DEADLINE 15' 전용 폴더, 개발 실행은 예전 그대로")
	_check(not OS.has_feature("template") and OS.get_user_data_dir().ends_with("app_userdata/DEADLINE 15"), "개발 실행의 user:// = Godot/app_userdata/DEADLINE 15 (%s)" % OS.get_user_data_dir().get_file())
	var bt_dir := ProjectSettings.globalize_path("res://build/")
	_check(FileAccess.file_exists(bt_dir + ".gdignore"), "build/.gdignore (내보낸 결과물을 Godot 이 가져오지 않음)")
	var pcks: Array = []
	for pth: String in [bt_dir + "windows/DEADLINE 15.pck", bt_dir + "macos/DEADLINE 15.zip"]:
		var lst: Variant = pck_paths(pth)
		if lst == null:
			continue
		pcks.append(pth.get_file())
		# 오래된 빌드: 내보낸 뒤 바뀐 소스가 있으면 실패 (수정 시각 비교)
		var built := FileAccess.get_modified_time(pth)
		var newer := _newer_sources(built)
		_check(newer.is_empty(), "%s: 소스보다 새 빌드 (내보낸 뒤 바뀐 파일 %d개 %s — 다시 내보내기)" % [pth.get_file(), newer.size(), str(newer.slice(0, 5))])
		var bad: Array = []
		var need := {"data/manifest.json": false, "data/lang/ko.json": false, "data/story/ko.json": false, "assets/fonts/OFL.txt": false, "assets/audio/bgm_battle.wav.import": false}
		for p: String in lst:
			var q := p.trim_prefix("res://")
			if q.begins_with("tests/") or q.begins_with("tools/") or q.begins_with("build/") or q.begins_with("dev/") or q.begins_with("assets/pilot/") or q.begins_with("android/") or q.contains("baseline") or q.ends_with(".md") or (q.contains("/src/") and q.begins_with("assets/")) or q.begins_with("third_party/") or q.begins_with("addons/admob/assets/") or q.begins_with("addons/admob/internal/editor/") or q.begins_with("addons/admob/internal/exporters/") or q.begins_with("addons/admob/android/") or q.begins_with("addons/admob/ios/"):   # (6b) 이미지 원본 src 는 assets/ 아래만 — 플러그인 API 폴더 gdscript/src 는 런타임에 필요
				bad.append(q)
			if need.has(q):
				need[q] = true
		var miss: Array = []
		for k: String in need.keys():
			if not need[k]:
				miss.append(k)
		_check(bad.is_empty() and miss.is_empty(), "%s: 파일 %d개 — tests/·tools/·기준 데이터·src 없음, data/·OFL.txt·소리 있음 (빠짐 %s, 섞임 %s)" % [pth.get_file(), lst.size(), str(miss), str(bad.slice(0, 5))])
		_stat("export.pck_files." + pth.get_base_dir().get_file(), lst.size())
	if pcks.is_empty():
		print("  (build/ 에 내보낸 pck 없음 — pck 내용 검사는 건너뜀)")
