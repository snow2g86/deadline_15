extends SceneTree
## 6a 시험 — 모바일(안드로이드·iOS) 화면·터치·생명주기를 PC 에서 흉내(Platform.emulate_mobile = 명령줄 -- --mobile 과 같음)로
##   Godot --headless --path godot --script res://tests/check_mobile6a.gd   [-- --only platform,export,layout,touch,back,background,settings]
##                                                                          [--devices pixel8,iphone,ipad,low] [--langs ko,en]
##  1) platform  : Platform.is_mobile — 기능 태그·OS 이름(Android·iOS)·가게(google·apple)·흉내, 흉내 중 is_pc 거짓, 배율 계산(4개 기기)
##  2) export    : 프리셋 (Android AAB·APK 둘이 같은 설정 · 기능 태그 · 패키지 · SDK · 가로 · 권한 · 거르기 · 아이콘), versionCode = config/version
##  3) layout    : 기기 4개(2400×1080 · 2778×1284 · 2732×2048 · 1600×720) × 6개 언어 × 모든 화면·창 —
##                 넘침 0 · 두부 0 · 단추가 안전 영역(노치·홈 바) 안 · 터치 대상 ≥ 44pt(6.85mm) · 글자 ≥ 12pt(1.85mm)
##  4) touch     : 전투 맵 — 탭(칸 고르기) · 끌기(카메라, 탭으로 안 셈) · 문턱 아래 흔들림은 탭 · 두 손가락 확대(0.6~3.0) · 길게 누르기(정보, 떼도 탭 아님)
##                 GUI — 길게 누르기 툴팁 (단추는 눌리지 않음) · 짧은 탭은 그대로 눌림
##  5) back      : 안드로이드 뒤로 = Esc (창 닫기 → 화면 뒤로), 로비 → 종료 확인, 전투 → 취소 / 설정 창, 스토리 넘기기
##  6) background: 앱 멈춤(PAUSED) → Store 디스크에 씀 · 전투 이어하기 저장 · 소리 끔 → 돌아옴(RESUMED) → 소리 원래대로 · Billing 복귀 확인
##  7) settings  : 모바일 설정 화면·전투 설정 창에 창 모드·창 크기·'창이 뒤에 있을 때 소리' 없음 (PC 는 있음)
##  Godot 오류 0 이어야 통과. 저장은 user://test_mobile6a_save.json (진짜 세이브는 건드리지 않음). 지금 데이터(godot/data)를 씀

const JsonX := preload("res://scripts/core/json_exact.gd")
const FontsT := preload("res://scripts/core/fonts.gd")
const Js := preload("res://scripts/logic/js.gd")
const MobileT := preload("res://scripts/core/mobile.gd")
const PlatformT := preload("res://scripts/core/platform.gd")
const ShopRules := preload("res://scripts/logic/shop_rules.gd")
const ResumeRules := preload("res://scripts/logic/resume_rules.gd")
const CodexRules := preload("res://scripts/logic/codex_rules.gd")
const Acad := preload("res://scripts/logic/academy_rules.gd")
const SAVE := "user://test_mobile6a_save.json"
const LANGS := ["ko", "en", "es", "ja", "zh-CN", "zh-TW"]
const DEVICES := ["pixel8", "iphone", "ipad", "low"]
const BATTLE := "res://scenes/battle/battle.tscn"
## 시험 쪽에 고정한 최소값 (Mobile 의 상수를 낮춰도 시험이 같이 내려가지 않게): 터치 대상 44pt · 글자 12pt (1pt = 1/163 inch)
const T_MIN_TARGET_MM := 44.0 / 163.0 * 25.4
const T_MIN_TEXT_MM := 12.0 / 163.0 * 25.4
## 게임 글꼴(Noto CJK)에 없고 OS 글꼴 대체로 그리는 UI 기호 (PC 와 같음): ⚑ U+2691(웨이브 칩) · ↩ U+21A9(취소·되돌리기 메뉴)
##  안드로이드 에뮬레이터(API 35)에서 그려지는 것을 사진으로 확인 (tests/screens/m6a_emu_06·09). iOS 는 실제 기기 확인 필요 (README '6a 남은 일')
const SYSTEM_GLYPHS := [0x2691, 0x21A9]
const SC := {"lobby": "res://scenes/outer/lobby.tscn", "stage_select": "res://scenes/outer/stage_select.tscn",
	"party_select": "res://scenes/outer/party_select.tscn", "settings": "res://scenes/outer/settings.tscn", "shop": "res://scenes/outer/shop.tscn",
	"sanctuary": "res://scenes/outer/sanctuary.tscn", "academy": "res://scenes/outer/academy.tscn", "compendium": "res://scenes/outer/compendium.tscn",
	"guide": "res://scenes/outer/guide.tscn", "credits": "res://scenes/outer/credits.tscn", "licenses": "res://scenes/outer/licenses.tscn"}

var _fails: Array = []
var _passes := 0
var _counter: ErrCounter
var store: Node
var i18n: Node
var router: Node
var platform: Node
var mobile: Node
var _only: Array = []
var _devices: Array = DEVICES.duplicate()
var _langs: Array = LANGS.duplicate()
var _stats: Dictionary = {}
## -- --shots (창 모드에서): 검사하는 화면마다 사진 tests/screens/m6a_<기기>_<언어>_<화면>.png
var _shots := false
var fx1: Dictionary
var fx2: Dictionary


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


func _want(n: String) -> bool:
	return _only.is_empty() or _only.has(n)


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var oi := args.find("--only")
	if oi >= 0 and oi + 1 < args.size():
		_only = Array(args[oi + 1].split(","))
	var di := args.find("--devices")
	if di >= 0 and di + 1 < args.size():
		_devices = Array(args[di + 1].split(","))
	var li := args.find("--langs")
	if li >= 0 and li + 1 < args.size():
		_langs = Array(args[li + 1].split(","))
	_shots = args.has("--shots") and DisplayServer.get_name() != "headless"
	store = root.get_node("Store")
	i18n = root.get_node("I18n")
	router = root.get_node("Router")
	platform = root.get_node("Platform")
	mobile = root.get_node("Mobile")
	store.call("use_path", SAVE)
	store.call("clear")
	i18n.call("reload")
	fx1 = JsonX.parse(FileAccess.get_file_as_string("res://tests/fixtures/outer_4b1_web.json"))
	fx2 = JsonX.parse(FileAccess.get_file_as_string("res://tests/fixtures/outer_4b2_web.json"))
	if _want("platform"):
		print("── 1) 플랫폼 판정 · 배율 계산 ──")
		_platform()
	if _want("export"):
		print("── 2) 내보내기 프리셋 ──")
		_export()
	if _want("settings"):
		print("── 7) 설정 항목 숨김 ──")
		await _settings()
	if _want("back"):
		print("── 5) 뒤로 가기 ──")
		await _back()
	if _want("background"):
		print("── 6) 백그라운드 ──")
		await _background()
	if _want("touch"):
		print("── 4) 터치 ──")
		await _touch()
	if _want("layout"):
		print("── 3) 화면 배치 (기기 %d × 언어 %d) ──" % [_devices.size(), _langs.size()])
		await _layout()
	_emu(false)
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	for e: String in _counter.errors.slice(0, 30):
		print("  ERR " + e)
	_check(_counter.errors.is_empty(), "Godot 오류 0 (%d)" % _counter.errors.size())
	print("  수치: %s" % JsonX.stringify(_stats))
	if _fails.is_empty():
		print("RESULT: PASS (%d개 통과)" % _passes)
		quit(0)
	else:
		print("RESULT: FAIL (%d개 실패, %d개 통과)" % [_fails.size(), _passes])
		for f: String in _fails.slice(0, 60):
			print("  - " + f)
		quit(1)


## 흉내 켜기 + 그 기기 화면 크기 (끄면 PC 1280×720)
var _dev := "pixel8"


## 논리 1단위의 실제 길이(mm) — 시험이 따로 계산 (흉내 중이 아니면 0)
func _unit_mm() -> float:
	if not bool(platform.call("is_mobile")):
		return 0.0
	var d: Dictionary = MobileT.DEVICES[_dev]
	var px := Vector2(d["size"])
	return 25.4 / float(d["dpi"]) * minf(px.x / 1280.0, px.y / 720.0) * root.content_scale_factor


func _emu(on: bool, dev: String = "pixel8") -> void:
	_dev = dev
	platform.call("emulate_mobile", on, dev)
	root.size = (MobileT.DEVICES[dev]["size"] as Vector2i) if on else Vector2i(1280, 720)
	if _shots:
		# 창 모드: 창 크기 = 기기 픽셀의 절반 (논리 배치는 같음 — 비율·dpi 로 정해짐)
		root.size = (MobileT.DEVICES[dev]["size"] as Vector2i) / 2 if on else Vector2i(1280, 720)
	mobile.call("apply")


# ═══════════ 1) 플랫폼 ═══════════

func _platform() -> void:
	_check(PlatformT.detect_mobile("Android") and PlatformT.detect_mobile("iOS"), "실제 OS Android·iOS → 모바일")
	_check(not PlatformT.detect_mobile("macOS") and not PlatformT.detect_mobile("Windows"), "macOS·Windows → 모바일 아님 (기능 태그 없을 때)")
	_check(not bool(platform.call("is_mobile")) and bool(platform.call("is_pc")) == OS.has_feature("pc"), "흉내 끔: PC 그대로")
	for s: String in ["google", "apple"]:
		platform.call("override_store", s)
		_check(bool(platform.call("is_mobile")) and not bool(platform.call("is_pc")), "가게 %s → 모바일" % s)
	platform.call("override_store", "stove")
	_check(not bool(platform.call("is_mobile")), "가게 stove → 모바일 아님")
	platform.call("override_store", "")
	_emu(true, "pixel8")
	_check(bool(platform.call("is_mobile")) and not bool(platform.call("is_pc")) and bool(platform.call("is_touch")), "흉내 → is_mobile · is_touch, is_pc 거짓")
	_check(str(platform.call("store")) == "dev", "흉내는 가게를 바꾸지 않음 (dev)")
	_emu(false)
	_check(is_equal_approx(root.content_scale_factor, 1.0) and (mobile.call("safe_margins") as Dictionary).values().max() == 0.0, "흉내 끔 → 배율 1 · 여백 0 (PC 그대로)")
	var want := {"pixel8": [1.5, Vector2(1067, 480)], "iphone": [1.375, Vector2(1133, 524)], "ipad": [1.0, Vector2(1280, 960)], "low": [1.447, Vector2(1106, 498)]}
	for d: String in DEVICES:
		_emu(true, d)
		var f: float = mobile.get("factor")
		var vs := root.get_visible_rect().size
		var u := float(mobile.call("unit_mm"))
		_check(absf(f - float(want[d][0])) < 0.01 and vs.distance_to(want[d][1]) < 2.0, "%s 배율 %.3f · 논리 %s (기대 %s %s)" % [d, f, str(vs), str(want[d][0]), str(want[d][1])])
		_check(vs.x >= MobileT.MIN_LOGICAL.x - 1.0 and vs.y >= MobileT.MIN_LOGICAL.y - 1.0, "%s 논리 화면 ≥ 1024×480" % d)
		_check(d == "ipad" or absf(u - MobileT.TARGET_UNIT_MM) < 0.002, "%s 논리 1단위 = %.4fmm" % [d, u])
		_stat("factor." + d, snappedf(f, 0.001))
		_stat("logical." + d, "%dx%d" % [roundi(vs.x), roundi(vs.y)])
	# 작은 16:9 휴대폰(1334×750 326dpi)은 논리 1024 아래로 줄이지 않음
	var f_se := MobileT.compute_factor(Vector2(1334, 750), 326.0)
	_check(absf(f_se - 1.25) < 0.01, "작은 휴대폰 배율 상한 (논리 폭 1024) %.3f" % f_se)
	_check(is_equal_approx(MobileT.compute_factor(Vector2(2400, 1080), 0.0), MobileT.compute_factor(Vector2(2400, 1080), MobileT.FALLBACK_DPI)), "dpi 모름 → 400dpi 로 봄")
	_emu(false)


# ═══════════ 2) 내보내기 프리셋 ═══════════

func _export() -> void:
	var cf := ConfigFile.new()
	_check(cf.load("res://export_presets.cfg") == OK, "export_presets.cfg 읽음")
	var by_name := {}
	for sec: String in cf.get_sections():
		if sec.begins_with("preset.") and not sec.ends_with(".options"):
			by_name[str(cf.get_value(sec, "name"))] = sec
	for n: String in ["Windows (STOVE)", "macOS (STOVE)", "Android (Google Play)", "Android (Google Play) APK", "iOS (App Store)"]:
		_check(by_name.has(n), "프리셋 '%s'" % n)
	if not (by_name.has("Android (Google Play)") and by_name.has("Android (Google Play) APK") and by_name.has("iOS (App Store)")):
		return
	var a: String = by_name["Android (Google Play)"]
	var b: String = by_name["Android (Google Play) APK"]
	var io: String = by_name["iOS (App Store)"]
	var ao := a + ".options"
	var bo := b + ".options"
	var diff: Array = []
	for k: String in cf.get_section_keys(ao):
		if k != "gradle_build/export_format" and str(cf.get_value(ao, k)) != str(cf.get_value(bo, k, null)):
			diff.append(k)
	for k2: String in cf.get_section_keys(a):
		if not ["name", "export_path"].has(k2) and str(cf.get_value(a, k2)) != str(cf.get_value(b, k2, null)):
			diff.append(k2)
	_check(diff.is_empty(), "Android AAB·APK 프리셋은 형식·이름·경로 말고 같음 %s" % str(diff))
	_check(int(cf.get_value(ao, "gradle_build/export_format")) == 1 and int(cf.get_value(bo, "gradle_build/export_format")) == 0, "형식 AAB(1) · APK(0)")
	_check(str(cf.get_value(a, "export_path")).ends_with(".aab") and str(cf.get_value(b, "export_path")).ends_with(".apk"), "경로 .aab · .apk (build/android)")
	_check(str(cf.get_value(a, "custom_features")) == "google" and str(cf.get_value(io, "custom_features")) == "apple", "기능 태그 google · apple")
	_check(str(cf.get_value(ao, "package/unique_name")) == "xyz.show4you.deadline15" and str(cf.get_value(io + ".options", "application/bundle_identifier")) == "xyz.show4you.deadline15", "패키지·번들 ID xyz.show4you.deadline15")
	_check(bool(cf.get_value(ao, "gradle_build/use_gradle_build")) and str(cf.get_value(ao, "gradle_build/target_sdk")) == "36" and int(str(cf.get_value(ao, "gradle_build/min_sdk"))) >= 24, "Gradle 빌드 · targetSdk 36 · minSdk ≥ 24")
	_check(bool(cf.get_value(ao, "architectures/arm64-v8a")) and not bool(cf.get_value(ao, "architectures/x86_64")), "arm64-v8a (+ armeabi-v7a)")
	var perms: Array = []
	for k3: String in cf.get_section_keys(ao):
		if k3.begins_with("permissions/") and k3 != "permissions/custom_permissions" and bool(cf.get_value(ao, k3)):
			perms.append(k3)
	_check(perms == ["permissions/internet"] and (cf.get_value(ao, "permissions/custom_permissions") as PackedStringArray).is_empty(), "권한은 인터넷만 %s" % str(perms))
	var ver := str(ProjectSettings.get_setting("application/config/version"))
	var p := ver.split(".")
	var code := int(p[0]) * 10000 + int(p[1]) * 100 + int(p[2]) if p.size() == 3 else -1
	_check(int(cf.get_value(ao, "version/code")) == code and str(cf.get_value(ao, "version/name")) == "", "versionCode %d = config/version %s (주.부.수 → 주×10000+부×100+수), versionName 빈칸 = config/version" % [int(cf.get_value(ao, "version/code")), ver])
	_check(str(cf.get_value(io + ".options", "application/short_version")) == "" and str(cf.get_value(io + ".options", "application/app_store_team_id")) == "", "iOS 버전 빈칸(= config/version) · 팀 ID 비움")
	_check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == DisplayServer.SCREEN_SENSOR_LANDSCAPE, "가로 고정 (양쪽 가로)")
	_check(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back")), "뒤로 가기로 바로 끝나지 않음 (quit_on_go_back = false)")
	_check(bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")) and not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse")), "터치 → 마우스 흉내 켬 · 마우스 → 터치 끔 (PC 마우스 그대로)")
	for sec2: String in [a, b, io]:
		var ex := str(cf.get_value(sec2, "exclude_filter"))
		_check(ex.contains("tests/*") and ex.contains("tools/*") and ex.contains("*.prev.png") and ex.contains("build/*"), "%s 거르기 (tests·tools·build·*.prev.png 뺌)" % cf.get_value(sec2, "name"))
		_check(ex.contains("dev/*") and ex.contains("assets/pilot/*"), "%s 거르기에 dev/* · assets/pilot/* (다른 작업 파일이 빌드에 안 들어감)" % cf.get_value(sec2, "name"))
		_check(str(cf.get_value(sec2, "include_filter")) == str(cf.get_value(by_name["Windows (STOVE)"], "include_filter")), "%s 넣기 = PC 와 같음 (data/*·OFL)" % cf.get_value(sec2, "name"))
	for k4: String in ["launcher_icons/main_192x192", "launcher_icons/adaptive_foreground_432x432", "launcher_icons/adaptive_background_432x432"]:
		var ip := str(cf.get_value(ao, k4))
		var img := Image.new()
		img.load_png_from_buffer(FileAccess.get_file_as_bytes(ip))
		var sz := int(k4.get_slice("_", k4.get_slice_count("_") - 1).get_slice("x", 0))
		_check(img != null and img.get_width() == sz and img.get_height() == sz, "%s %d×%d" % [k4, sz, sz])
	var ic := Image.new()
	ic.load_png_from_buffer(FileAccess.get_file_as_bytes(str(cf.get_value(io + ".options", "icons/icon_1024x1024"))))
	_check(ic != null and ic.get_width() == 1024 and not ic.detect_alpha(), "iOS 아이콘 1024 · 투명 없음 (App Store)")
	_check(str(cf.get_value(ao, "keystore/release")) == "", "출시 키스토어는 비움 (사용자가 만듦 — README)")
	for sec3: String in ["preset.0", "preset.1"]:
		var ex3 := str(cf.get_value(sec3, "exclude_filter"))
		_check(ex3.contains("dev/*") and ex3.contains("assets/pilot/*"), "%s(PC) 거르기에 dev/* · assets/pilot/*" % cf.get_value(sec3, "name"))
	_check(int(cf.get_value(ao, "package/app_category")) == 2 and int(cf.get_value(bo, "package/app_category")) == 2, "Android 앱 분류 = 게임(2)")
	var mono := Image.new()
	mono.load_png_from_buffer(FileAccess.get_file_as_bytes(str(cf.get_value(ao, "launcher_icons/adaptive_monochrome_432x432"))))
	_check(mono.get_width() == 432 and mono.detect_alpha(), "테마 아이콘(monochrome) 432 · 투명 있음")
	# 적응형 전경: 그림이 안전 영역(가운데 66%) 안 — 투명이 아닌 곳이 가운데 66% 밖에 없음
	var fg := Image.new()
	fg.load_png_from_buffer(FileAccess.get_file_as_bytes(str(cf.get_value(ao, "launcher_icons/adaptive_foreground_432x432"))))
	var ub := fg.get_used_rect()
	var safe_lo := 432.0 * 0.17
	var safe_hi := 432.0 * 0.83
	_check(float(ub.position.x) >= safe_lo - 1.0 and float(ub.end.x) <= safe_hi + 1.0 and float(ub.position.y) >= safe_lo - 1.0 and float(ub.end.y) <= safe_hi + 1.0, "적응형 전경 그림이 안전 영역(66%%) 안 %s" % str(ub))
	var mu := mono.get_used_rect()
	_check(ub.grow(2.0).encloses(mu) and mu.size.x > ub.size.x * 0.9, "테마 아이콘 윤곽 = 전경 윤곽 %s / %s" % [str(mu), str(ub)])


# ═══════════ 공통: 화면 띄우기 · 검사 ═══════════

func _rich_save() -> void:
	store.call("clear")
	var st: Dictionary = fx2["sanctuary"][0]["store"]
	for k: String in st.keys():
		store.call("set_json", k, Js.deep(st[k]))
	var r: Dictionary = store.call("get_json", "game_roster")
	for ch: Dictionary in r["chars"]:
		if int(ch["uid"]) == 12:
			ch["customName"] = "가나다라마바사아자차"
		if int(ch["uid"]) == 11:
			ch["customName"] = "WWWWWWWWWW"
	store.call("set_json", "game_roster", r)
	store.call("set_json", "game_save", {"gold": 1234567, "cleared": range(1, 46), "stars": {"1": [1, 1, 1], "10": [1, 0, 1]}})
	store.call("set_json", "game_shop", fx1["shop"][0]["after"]["game_shop"])
	store.call("set_json", "game_mats", {"stone": 99, "protect": 9, "shard": 12})
	store.call("set_json", "game_soul", {"stones": {"warrior": 12, "knight": 3, "mage": 99}, "frags": {"mage": 123, "knight": 9, "priest": 15, "archer": 30, "assassin": 2}})
	store.call("set_json", "game_story_seen", {"ep1_pro": true, "s1_pre": true, "s1_start": true, "ep1_epi": true})
	store.call("set_json", "game_settings", {"language": "ko", "playSpeed": 4})
	var inv: Array = store.call("get_json", "game_inventory", [])
	for it: Dictionary in (fx1["equip"][0]["store"]["game_inventory"] as Array):
		inv.append(Js.deep(it))
	store.call("set_json", "game_inventory", inv)


## 화면 안의 부품 검사 → {overflow, tofu, safe, small_target, small_text, n}
func _audit(scr: Node, lang: String) -> Dictionary:
	var res := {"overflow": [], "tofu": [], "safe": [], "target": [], "text": [], "n": 0, "buttons": 0}
	var vr := root.get_visible_rect()
	var safe: Rect2 = mobile.call("safe_rect")
	var u := _unit_mm()   # Mobile.unit_mm() 을 믿지 않고 기기 표(dpi · 화면)와 실제 content_scale_factor 로 따로 계산
	var stack: Array = [scr]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is CanvasItem and not (nd as CanvasItem).is_visible_in_tree():
			continue
		if nd.is_queued_for_deletion() or str(nd.name) == "Hideout":
			continue
		stack.append_array(nd.get_children())
		if not (nd is Control):
			continue
		var ctl := nd as Control
		if _in_world(ctl):
			continue
		var vis := _visible_rect(ctl)
		if vis.size.x < 1.0 or vis.size.y < 1.0:
			continue
		var txt := ""
		var fs := 0
		if ctl is Label:
			txt = (ctl as Label).text
			fs = ctl.get_theme_font_size("font_size")
		elif ctl is Button:
			txt = (ctl as Button).text
			fs = ctl.get_theme_font_size("font_size")
		elif ctl is RichTextLabel:
			txt = (ctl as RichTextLabel).get_parsed_text()
			fs = ctl.get_theme_font_size("normal_font_size")
		elif ctl is LineEdit:
			txt = (ctl as LineEdit).text + (ctl as LineEdit).placeholder_text
			fs = ctl.get_theme_font_size("font_size")
		if txt.strip_edges() != "":
			res["n"] += 1
			for i in txt.length():
				var cp := txt.unicode_at(i)
				if cp < 32 or cp == 0x200B:
					continue
				if not FontsT.chain_has_char(lang, cp) and not SYSTEM_GLYPHS.has(cp):
					res["tofu"].append("%s '%s' U+%04X" % [_p(ctl), txt.substr(0, 20), cp])
					break
			if u > 0.0 and fs > 0 and fs * u < T_MIN_TEXT_MM and not ctl.get_meta("small_ok", false):
				res["text"].append("%s %dpx=%.2fmm '%s'" % [_p(ctl), fs, fs * u, txt.substr(0, 16)])
		if ctl is Label:
			var l := ctl as Label
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF and not l.clip_text and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
				if l.get_minimum_size().x > l.size.x + 1.0:
					res["overflow"].append("%s 좁음 %.0f>%.0f '%s'" % [_p(ctl), l.get_minimum_size().x, l.size.x, l.text.substr(0, 24)])
		var par := ctl.get_parent() as Control
		# 부모 밖: 디자인상 솟는 것(overflow_ok)·잘라내는 부모(clip_contents) 안은 빼고
		var exempt: bool = ctl.get_meta("overflow_ok", false) or (par != null and (par.get_meta("overflow_ok", false) or par.clip_contents))
		if par != null and not exempt and not (par is ScrollContainer) and ctl.size.x > 0.0 and not (ctl is ScrollContainer and par.name == "Box") and not _in_world(par):
			var pr := par.get_global_rect().grow(3.0)
			var r := ctl.get_global_rect()
			if not pr.encloses(r) and r.size.x > 0.0 and not par.get_meta("overflow_ok", false):
				res["overflow"].append("%s 부모 밖 %s ⊄ %s '%s'" % [_p(ctl), str(r), str(pr), txt.substr(0, 20)])
		if txt != "" and not _clipped_by_scroll(ctl) and not vr.grow(1.0).encloses(ctl.get_global_rect()):
			res["overflow"].append("%s 화면 밖 %s '%s'" % [_p(ctl), str(ctl.get_global_rect()), txt.substr(0, 20)])
		# 누를 수 있는 것: 안전 영역 안 · 크기
		if _tappable(ctl):
			res["buttons"] += 1
			if not safe.grow(1.0).encloses(vis):
				res["safe"].append("%s %s ⊄ 안전 %s" % [_p(ctl), str(vis), str(safe)])
			var full := ctl.get_global_rect()
			if u > 0.0 and minf(full.size.x, full.size.y) * u < T_MIN_TARGET_MM and not ctl.get_meta("small_ok", false):
				res["target"].append("%s %.0f×%.0f=%.1f×%.1fmm" % [_p(ctl), full.size.x, full.size.y, full.size.x * u, full.size.y * u])
	return res


func _p(c: Node) -> String:
	var s := str(c.get_path())
	var i := s.find("/", 6)
	return s.substr(i) if i >= 0 else s


## 맵(Node2D) 안의 글자는 화면 부품이 아님 (확대·축소를 따라감)
func _in_world(c: Node) -> bool:
	var a: Node = c.get_parent()
	while a != null:
		if a is Node2D:
			return true
		if a is CanvasLayer or a == root:
			return false
		a = a.get_parent()
	return false


func _tappable(c: Control) -> bool:
	if c is BaseButton:
		return not (c as BaseButton).disabled or true
	return c is LineEdit or c is Slider


## 스크롤·잘라내기 조상에 잘린 뒤 보이는 부분 (전역 좌표)
func _visible_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var a: Node = c.get_parent()
	while a != null and a is Control:
		var ac := a as Control
		if ac is ScrollContainer or ac.clip_contents:
			r = r.intersection(ac.get_global_rect())
		a = a.get_parent()
	return r.intersection(root.get_visible_rect())


func _clipped_by_scroll(c: Control) -> bool:
	var a: Node = c.get_parent()
	while a != null and a is Control:
		if a is ScrollContainer or (a as Control).clip_contents:
			return true
		a = a.get_parent()
	return false


var _all: Dictionary = {}   # 종류 → [문제]
var _n_text := 0
var _n_btn := 0


func _collect(scr: Node, tag: String, lang: String) -> void:
	if _shots:
		await _frames(4)
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var fn := "m6a_" + tag.replace(" ", "_").replace(".", "_") + ".png"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screens/"))
		img.save_png(ProjectSettings.globalize_path("res://tests/screens/" + fn))
	var a := _audit(scr, lang)
	_n_text += int(a["n"])
	_n_btn += int(a["buttons"])
	for k: String in ["overflow", "tofu", "safe", "target", "text"]:
		for s: String in a[k]:
			if not _all.has(k):
				_all[k] = []
			_all[k].append("[%s] %s" % [tag, s])


func _open(key: String, params: Dictionary = {}) -> Node:
	router.set("params", params)
	var scr: Node = (load(SC[key]) as PackedScene).instantiate()
	root.add_child(scr)
	await _frames(4)
	return scr


func _close(scr: Node) -> void:
	scr.queue_free()
	await _frames(2)


# ═══════════ 3) 화면 배치 ═══════════

func _layout() -> void:
	if current_scene != null:
		current_scene.queue_free()
		await _frames(3)
	router.set("dry_run", true)
	_all = {}
	_n_text = 0
	_n_btn = 0
	for dev: String in _devices:
		for lang: String in _langs:
			_emu(true, dev)
			_rich_save()
			i18n.call("_apply", lang)
			await _screens("%s %s" % [dev, lang], lang)
	_emu(false)
	i18n.call("_apply", "ko")
	router.set("dry_run", false)
	for k: String in ["overflow", "tofu", "safe", "target", "text"]:
		var arr: Array = _all.get(k, [])
		for s: String in arr.slice(0, 25):
			print("    %s %s" % [k, s])
		_stat("layout." + k, arr.size())
	_stat("layout.text_controls", _n_text)
	_stat("layout.buttons", _n_btn)
	var names := {"overflow": "넘침", "tofu": "두부", "safe": "안전 영역 밖 단추", "target": "작은 터치 대상(< 44pt)", "text": "작은 글자(< 12pt)"}
	for k2: String in names.keys():
		_check((_all.get(k2, []) as Array).is_empty(), "기기 %d × 언어 %d: %s 0 (글자 %d · 단추 %d 검사, 문제 %d)" % [_devices.size(), _langs.size(), names[k2], _n_text, _n_btn, (_all.get(k2, []) as Array).size()])


func _screens(tag: String, lang: String) -> void:
	# 로비 · 지휘관 설정 · 종료 확인 · 전투 재개 안내
	var lb: Node = await _open("lobby")
	await _collect(lb, tag + " lobby", lang)
	lb.open_commander_setup(false)
	await _frames(3)
	await _collect(lb, tag + " lobby.commander", lang)
	lb.close_all_modals()
	lb.root_back()
	await _frames(3)
	await _collect(lb, tag + " lobby.quit", lang)
	await _close(lb)
	# 스테이지 선택
	var ss: Node = await _open("stage_select")
	for stt: String in ["base", "stages", "info", "info_boss", "daily", "replay", "story"]:
		ss.close_all_modals()
		match stt:
			"story":
				ss._story_prepare(null)
				ss.play_scenes([{"key": "s1_pre", "lines": ss.story.call("lines_of", "s1_pre"), "title": "EP.1"}], false, Callable())
			"stages":
				ss.open_episode(1)
			"info":
				ss.show_stage_info(10)
			"info_boss":
				ss.show_stage_info(45)
			"daily":
				ss.open_daily()
			"replay":
				ss.open_replay()
		await _frames(3)
		await _collect(ss, tag + " stage." + stt, lang)
	ss.story_view.call("skip")
	await _frames(2)
	await _close(ss)
	# 편성 (장비·소모품·강화 탭과 창)
	var ps: Node = await _open("party_select")
	await _collect(ps, tag + " party.base", lang)
	ps.open_unit_modal(0)
	await _frames(3)
	await _collect(ps, tag + " party.unit_modal", lang)
	var inv: Array = store.call("get_json", "game_inventory", [])
	var eid := ""
	for it: Dictionary in inv:
		if it.has("eid"):
			eid = str(it["eid"])
			break
	for stt2: String in ["equip", "modal1", "item", "potion", "enhance", "enh_modal", "odds"]:
		ps.close_all_modals()
		match stt2:
			"equip", "item", "enhance":
				ps.switch_page_tab(stt2)
			"modal1":
				ps.switch_page_tab("equip")
				await _frames(2)
				ps.gear.open_equip_modal(11)
			"potion":
				ps.switch_page_tab("item")
				await _frames(2)
				ps.gear.open_potion_use("exp_m")
			"enh_modal":
				ps.switch_page_tab("enhance")
				await _frames(2)
				if eid != "":
					ps.gear.open_enhance(eid)
			"odds":
				ps.switch_page_tab("enhance")
				await _frames(2)
				var ob: Node = ps.find_child("OddsBtn", true, false)
				if ob != null:
					(ob as BaseButton).pressed.emit()
		await _frames(4)
		await _collect(ps, tag + " party." + stt2, lang)
	await _close(ps)
	# 상점: 탭 6개 · 뽑기 결과 · 사기 확인 · 결제 확인 · 확률표
	for tab: String in ShopRules.TABS:
		var sh: Node = await _open("shop", {"tab": tab})
		await _collect(sh, tag + " shop." + tab, lang)
		if tab == "equip":
			sh.show_gacha_results(ShopRules.gacha(_ctx(), 10))
			await _frames(3)
			await _collect(sh, tag + " shop.gacha", lang)
			sh.close_all_modals()
			sh.open_odds()
			await _frames(3)
			await _collect(sh, tag + " shop.odds", lang)
		elif tab == "consumable":
			sh._act_frame = -1
			sh.buy_item(0)
			await _frames(3)
			await _collect(sh, tag + " shop.confirm", lang)
		elif tab == "gold":
			sh._act_frame = -1
			sh.buy_iap("gold_500")
			await _frames(3)
			await _collect(sh, tag + " shop.iap_confirm", lang)
		await _close(sh)
	# 성소
	var sa: Node = await _open("sanctuary")
	for stt3: String in ["resurrect", "ad", "promote", "sac", "rename", "rename_modal", "enchant"]:
		sa.close_all_modals()
		match stt3:
			"resurrect", "promote", "rename", "enchant":
				sa.switch_tab(stt3)
			"ad":
				sa.open_ad_revive()
			"sac":
				sa.switch_tab("promote")
				sa.open_sacrifice(12)
			"rename_modal":
				sa.open_rename(12)
		await _frames(3)
		await _collect(sa, tag + " sanctuary." + stt3, lang)
	await _close(sa)
	# 아카데미
	var ac: Node = await _open("academy")
	for stt4: String in ["classchange", "scrolls", "skillbook", "targets"]:
		ac.close_all_modals()
		match stt4:
			"classchange", "skillbook":
				ac.switch_tab(stt4)
			"scrolls":
				ac.open_scrolls(6)
			"targets":
				var bk: Array = Acad.books(_ctx())
				if not bk.is_empty():
					ac.open_book(int(bk[0]["idx"]), bk[0]["item"])
		await _frames(3)
		await _collect(ac, tag + " academy." + stt4, lang)
	await _close(ac)
	# 도감 · 가이드
	var cp: Node = await _open("compendium")
	for stt5: String in ["cls", "gear", "cons", "stage", "sheet"]:
		cp.close_all_modals()
		if stt5 == "sheet":
			cp.open_class("mage")
		else:
			cp.switch_tab(stt5)
		await _frames(3)
		await _collect(cp, tag + " compendium." + stt5, lang)
	await _close(cp)
	var gd: Node = await _open("guide")
	for gt: String in CodexRules.GUIDE_TABS:
		gd.switch_tab(gt)
		await _frames(3)
		await _collect(gd, tag + " guide." + gt, lang)
	await _close(gd)
	# 설정 · 크레딧 · 라이선스
	var se: Node = await _open("settings")
	await _collect(se, tag + " settings", lang)
	se.ask_reset()
	await _frames(3)
	await _collect(se, tag + " settings.confirm", lang)
	await _close(se)
	for k: String in ["credits", "licenses"]:
		var nd: Node = await _open(k)
		await _collect(nd, tag + " " + k, lang)
		await _close(nd)
	# 전투: HUD · 행동 메뉴 · 적 정보 · 칸 정보 · 설정 창 · 나가기 확인 · 스토리 · 전투 대사 · 결과
	var bt: Node = await _battle()
	if bt != null:
		await _collect(bt.ui, tag + " battle.hud", lang)
		var enemy := -1
		for uv: Node in bt.units.values():
			if uv.d["team"] == "enemy" and uv.visible:
				enemy = uv.id
				break
		if enemy >= 0:
			bt.show_enemy_popup(enemy)
			await _frames(3)
			await _collect(bt.ui, tag + " battle.popup", lang)
			bt.ui.info.hide_popup()
		bt._hover_key = "c:3,4"
		bt._hover_pos = Vector2(400, 300)
		bt._hover_t = 1.0
		bt._update_hover(0.1)
		await _frames(2)
		await _collect(bt.ui, tag + " battle.tip", lang)
		bt._hover_key = ""
		bt.ui.info.hide_tip()
		bt.ui_action("skill")
		await _frames(3)
		await _collect(bt.ui, tag + " battle.skills", lang)
		bt.ui_cancel()
		bt.ui.settings.open()
		await _frames(4)
		await _collect(bt.ui, tag + " battle.settings", lang)
		bt.ui.settings.ask_confirm("leave")
		await _frames(3)
		await _collect(bt.ui, tag + " battle.leave", lang)
		bt.ui.settings.close()
		await _frames(2)
		var lines: Variant = bt.story.lines_of("s9_pre")
		bt.ui.story.auto = false
		bt._story_play([{"key": "m6a_scene", "lines": lines, "title": "EP.1-9", "battle": false}])
		await _frames(4)
		await _collect(bt.ui, tag + " battle.story", lang)
		bt.ui.story.skip()
		await _until(func() -> bool: return bt._hold == 0)
		var bl: Variant = bt.story.lines_of("s9_start")
		bt._story_play([{"key": "m6a_battle", "lines": bl, "title": "", "battle": true}])
		await _frames(4)
		await _collect(bt.ui, tag + " battle.story_battle", lang)
		bt.ui.story.skip()
		await _until(func() -> bool: return bt._hold == 0)
		bt.ui.settings.open()
		await _frames(2)
		bt.ui.settings.ask_confirm("surrender")
		await _frames(2)
		var yes: Node = bt.ui.settings.confirm.find_child("Yes", true, false)
		if yes != null:
			(yes as BaseButton).pressed.emit()
		await _until(func() -> bool: return bt.ui.result_view.visible, 3.0)
		await create_timer(0.6).timeout   # 튀어 오르는 연출(0.35초)이 끝난 크기로
		await _collect(bt.ui, tag + " battle.result", lang)
		bt.queue_free()
		await _frames(3)


func _ctx() -> Object:
	const Ctx := preload("res://scripts/logic/ctx.gd")
	const StoreCtx := preload("res://scripts/logic/store_ctx.gd")
	var D := Ctx.globals_from_db(root.get_node("DataDB"))
	return Ctx.new(D, 4242, StoreCtx.new(store))


## 실제 세이브 전투 (편성 5명) 를 띄워 입력 대기까지
func _battle() -> Node:
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	var cfg: Dictionary = BS.call("golden_cfg", "legion5_s09")
	cfg["speed"] = 0.0
	cfg["source"] = "test"
	cfg["story"] = "off"
	cfg["loading"] = false
	BS.set("pending", cfg)
	var bt: Node = (load(BATTLE) as PackedScene).instantiate()
	root.add_child(bt)
	if not await _until(func() -> bool: return bt.is_awaiting(), 10.0):
		_check(false, "전투가 입력 대기까지 옴")
		return null
	await _frames(3)
	return bt


# ═══════════ 4) 터치 ═══════════

## 논리 좌표 → 창(픽셀) 좌표 (Input 에 넣는 터치는 창 좌표 — 늘이기·배율을 거쳐 논리 좌표가 됨)
func _win(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _touch_ev(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = _win(pos)
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag_ev(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = _win(pos)
	e.relative = root.get_final_transform().basis_xform(rel)
	Input.parse_input_event(e)


func _touch() -> void:
	# 앞 시험(뒤로 가기·백그라운드)이 띄운 진짜 장면이 위를 덮지 않게 치움
	if current_scene != null:
		current_scene.queue_free()
		await _frames(3)
	_emu(true, "pixel8")
	_rich_save()
	i18n.call("_apply", "ko")
	var bt: Node = await _battle()
	if bt == null:
		return
	var u := float(mobile.call("unit_mm"))
	var slop := float(mobile.call("slop_for", InputEventScreenTouch.new()))
	_check(absf(slop * u - MobileT.TOUCH_SLOP_MM) < 0.05 and slop > MobileT.MOUSE_SLOP, "터치 끌기 문턱 = 실제 %.1fmm (논리 %.1f, 마우스는 6)" % [slop * u, slop])
	var me := InputEventMouseButton.new()
	_check(float(mobile.call("slop_for", me)) == MobileT.MOUSE_SLOP, "PC 마우스 문턱은 그대로 6")
	# 이동 칸 고르기: 이동 → 이동할 수 있는 칸을 손가락 탭
	bt.ui_action("move")
	await _frames(2)
	var cell := ""
	for k: String in bt.target_cells.keys():
		if bt.target_cells[k] != "cover":
			cell = k
			break
	_check(bt.mode == "target" and cell != "", "이동 칸 고르기 상태")
	var xy := cell.split(",")
	var wp := Vector2(bt.iso.tsx(int(xy[0]), int(xy[1])) + bt.iso.TW, bt.iso.tsy(int(xy[0]), int(xy[1]), 0.0) + bt.iso.TH)
	var sp: Vector2 = bt.get_viewport().get_canvas_transform() * wp
	# (1) 끌기: 문턱보다 크게 움직이면 카메라만 움직이고 칸은 안 눌림
	var cam0: Vector2 = bt.cam.position
	_touch_ev(0, sp, true)
	await _frames(1)
	for i in 6:
		_drag_ev(0, sp + Vector2(10.0 * (i + 1), 0), Vector2(10, 0))
		await _frames(1)
	_touch_ev(0, sp + Vector2(60, 0), false)
	await _frames(3)
	_check(bt.mode == "target" and bt.cam.position.distance_to(cam0) > 20.0, "끌기 → 카메라 이동 · 칸 고르기 그대로 (탭으로 안 셈) cam %s→%s" % [str(cam0), str(bt.cam.position)])
	bt.cam.position = cam0
	bt.cam.force_update_scroll()
	await _frames(2)
	sp = bt.get_viewport().get_canvas_transform() * wp
	# (2) 문턱 아래 흔들림(1mm)은 탭 → 그 칸으로 이동
	var jit := Vector2(1.0 / u, 0)
	var cam1: Vector2 = bt.cam.position
	_touch_ev(0, sp, true)
	await _frames(1)
	_drag_ev(0, sp + jit, jit)
	await _frames(1)
	_touch_ev(0, sp + jit, false)
	await _frames(4)

	_check(bt.mode != "target" and bt.cam.position.distance_to(cam1) < 1.0, "1mm 흔들린 탭 → 칸이 눌림 (이동) · 카메라 그대로 (mode %s)" % bt.mode)
	await _until(func() -> bool: return bt.is_awaiting(), 5.0)
	await _frames(3)
	# (3) 두 손가락 확대·축소
	var z0: float = bt.cam.zoom.x
	var c := _free_spot(bt)
	_touch_ev(0, c - Vector2(60, 0), true)
	await _frames(1)
	_touch_ev(1, c + Vector2(60, 0), true)
	await _frames(1)
	for i2 in 5:
		var d := 60.0 + 12.0 * (i2 + 1)
		_drag_ev(0, c - Vector2(d, 0), Vector2(-12, 0))
		_drag_ev(1, c + Vector2(d, 0), Vector2(12, 0))
		await _frames(1)
	var z1: float = bt.cam.zoom.x
	_check(z1 > z0 * 1.4 and z1 <= 3.0, "벌리기 → 확대 %.2f → %.2f" % [z0, z1])
	for i3 in 20:
		var d2 := 120.0 - 5.5 * (i3 + 1)
		_drag_ev(0, c - Vector2(d2, 0), Vector2(5.5, 0))
		_drag_ev(1, c + Vector2(d2, 0), Vector2(-5.5, 0))
		await _frames(1)
	var z2: float = bt.cam.zoom.x
	_check(z2 < z1 and z2 >= 0.6, "오므리기 → 축소 %.2f (최소 0.6)" % z2)
	var mode_before: String = bt.mode
	_touch_ev(1, c + Vector2(10, 0), false)
	await _frames(1)
	_touch_ev(0, c - Vector2(10, 0), false)
	await _frames(3)
	_check(bt.mode == mode_before and int(bt.pinches) >= 1 and not bt._pinch, "두 손가락을 떼도 칸이 눌리지 않음 (mode %s)" % bt.mode)
	# (4) 길게 누르기 → 유닛 정보 툴팁, 떼도 탭이 아님
	var ally: Node = null
	for uv: Node in bt.units.values():
		if uv.d["team"] == "ally" and uv.visible:
			ally = uv
			break
	var up: Vector2 = bt.get_viewport().get_canvas_transform() * (ally.position + Vector2(0, -20))
	var lp0: int = bt.long_presses
	var mode0: String = bt.mode
	_touch_ev(0, up, true)
	await _frames(1)
	await create_timer(0.7).timeout
	await _frames(3)
	_check(int(bt.long_presses) == lp0 + 1 and bt.ui.info.tip.visible, "길게 누르기 → 유닛 정보 툴팁")
	_touch_ev(0, up, false)
	await _frames(3)
	_check(bt.mode == mode0 and bt.ui.info.tip.visible, "떼도 탭이 아님 (메뉴 그대로) · 툴팁은 남음")
	_touch_ev(0, c, true)
	await _frames(2)
	_check(not bt.ui.info.tip.visible, "다음 누르기 → 툴팁 지움")
	_touch_ev(0, c, false)
	await _frames(3)
	bt.queue_free()
	await _frames(3)
	# (5) GUI 길게 누르기 툴팁 · 단추는 안 눌림 / 짧은 탭은 눌림
	router.set("dry_run", true)
	var lb: Node = await _open("lobby")
	if lb.get("setup_dialog") != null:
		lb.commander_setup_done()
		await _frames(2)
	lb.close_all_modals()
	await _frames(2)
	var gear: Button = lb.gear_btn
	var pressed := [0]
	gear.pressed.connect(func() -> void: pressed[0] += 1)
	var gp := gear.get_global_rect().get_center()
	var lpc: int = mobile.get("long_press_count")
	_touch_ev(0, gp, true)
	await _frames(1)
	await create_timer(0.7).timeout
	await _frames(2)
	_check(bool(mobile.call("tip_visible")) and str(mobile.call("tip_text")) == gear.tooltip_text and int(mobile.get("long_press_count")) == lpc + 1, "단추 길게 누르기 → 툴팁 '%s'" % str(mobile.call("tip_text")))
	var tipc: Control = mobile.get("_tip")
	var tr: Rect2 = tipc.get_global_rect() if tipc != null else Rect2()
	_check(tr.size.y > 0.0 and tr.size.y < 60.0 and (mobile.call("safe_rect") as Rect2).grow(1.0).encloses(tr), "짧은 툴팁은 한 줄 크기 · 안전 영역 안 %s" % str(tr))
	_touch_ev(0, gp, false)
	await _frames(3)
	_check(pressed[0] == 0, "툴팁을 본 뒤 떼면 단추가 눌리지 않음")
	_touch_ev(0, gp, true)
	await _frames(2)
	_check(not bool(mobile.call("tip_visible")), "다시 누르면 툴팁 숨김")
	_touch_ev(0, gp, false)
	await _frames(3)
	_check(pressed[0] == 1, "짧은 탭은 단추가 눌림")
	await _close(lb)
	# (6) 목록 밀기: 스크롤 안의 단추 위에서 시작한 끌기 → 목록이 밀리고 단추는 안 눌림 / 짧은 탭은 눌림
	var cp: Node = await _open("compendium")
	await _frames(3)
	var tile: Control = null
	var tiles := cp.find_children("Tile_*", "Button", true, false)
	if not tiles.is_empty():
		(cp.page_scroll as ScrollContainer).ensure_control_visible(tiles[0])
		await _frames(3)
	for t2: Node in tiles:
		if (t2 as Control).is_visible_in_tree() and _visible_rect(t2 as Control).size.y > 40.0:
			tile = t2
			break
	_check(tile != null, "도감 직업 칸 보임")
	if tile != null:
		var sc: ScrollContainer = cp.page_scroll
		var v0 := sc.scroll_vertical
		var tp := _visible_rect(tile).get_center()
		var ds0: int = mobile.get("drag_scrolls")
		_touch_ev(0, tp, true)
		await _frames(1)
		for i4 in 8:
			_drag_ev(0, tp - Vector2(0, 15.0 * (i4 + 1)), Vector2(0, -15))
			await _frames(1)
		_touch_ev(0, tp - Vector2(0, 120), false)
		await _frames(3)
		_check(sc.scroll_vertical > v0 + 60 and not cp.modal_open() and int(mobile.get("drag_scrolls")) == ds0 + 1, "단추 위에서 끌기 → 목록 밀림 %d→%d · 단추 안 눌림" % [v0, sc.scroll_vertical])
		var tp2 := _visible_rect(tile).get_center()
		_touch_ev(0, tp2, true)
		await _frames(2)
		_touch_ev(0, tp2, false)
		await _frames(4)
		_check(cp.modal_open(), "짧은 탭 → 직업 창 열림")
	await _close(cp)
	router.set("dry_run", false)
	_emu(false)


## HUD·메뉴가 없는 맵 자리 (좌우 130 까지 비어 있는 곳)
func _free_spot(bt: Node) -> Vector2:
	var vs := root.get_visible_rect().size
	var mr: Rect2 = bt.ui.menu.get_global_rect().grow(20.0) if bt.ui.menu.visible else Rect2()
	for yy in range(4, 9):
		for xx in range(2, 9):
			var p := Vector2(vs.x * xx / 10.0, vs.y * yy / 12.0)
			var ok := true
			for dx: float in [-130.0, 0.0, 130.0]:
				var q := p + Vector2(dx, 0)
				if bt.ui.over_hud(q) or mr.has_point(q):
					ok = false
			if ok:
				return p
	return vs * 0.5


# ═══════════ 5) 뒤로 가기 ═══════════

func _back() -> void:
	_emu(true, "pixel8")
	_rich_save()
	i18n.call("_apply", "ko")
	router.set("dry_run", false)
	router.call("go", "lobby")
	await _until(func() -> bool: return current_scene != null and str(current_scene.get_script().resource_path).ends_with("lobby.gd"), 5.0)
	await _frames(3)
	var lb: Node = current_scene
	if lb.get("setup_dialog") != null:
		lb.commander_setup_done()
		await _frames(2)
	lb.close_all_modals()
	var qa: int = lb.quit_asked
	mobile.call("system_back")
	await _frames(3)
	_check(int(lb.quit_asked) == qa + 1 and lb.modal_open() and lb.layer.find_child("Confirm", true, false) != null, "로비에서 뒤로 → 종료 확인 창")
	mobile.call("system_back")
	await _frames(3)
	_check(not lb.modal_open(), "다시 뒤로 → 확인 창 닫힘 (종료 안 함)")
	# PC Esc 는 로비에서 아무것도 안 함 (종료 확인 없음)
	router.call("request_back")
	await _frames(2)
	_check(not lb.modal_open() and int(lb.quit_asked) == qa + 1, "Esc(시스템 뒤로 아님)는 로비에서 종료 확인을 띄우지 않음")
	router.call("go", "shop")
	await _until(func() -> bool: return str(current_scene.get_script().resource_path).ends_with("shop.gd"), 5.0)
	await _frames(3)
	var sh: Node = current_scene
	sh.open_odds()
	await _frames(3)
	_check(sh.modal_open(), "상점 확률표 창")
	mobile.call("system_back")
	await _frames(3)
	_check(not sh.modal_open() and str(current_scene.get_script().resource_path).ends_with("shop.gd"), "뒤로 → 창 먼저 닫힘")
	mobile.call("system_back")
	await _until(func() -> bool: return str(current_scene.get_script().resource_path).ends_with("lobby.gd"), 5.0)
	_check(str(current_scene.get_script().resource_path).ends_with("lobby.gd"), "뒤로 → 이전 화면 (로비)")
	# 바깥 화면 스토리 재생 중 뒤로 → 넘기기
	router.call("go", "stage_select")
	await _until(func() -> bool: return str(current_scene.get_script().resource_path).ends_with("stage_select.gd"), 5.0)
	await _frames(3)
	var ssn: Node = current_scene
	ssn._story_prepare(null)
	ssn.play_scenes([{"key": "s1_pre", "lines": ssn.story.call("lines_of", "s1_pre"), "title": "EP.1"}], false, Callable())
	await _frames(3)
	_check(ssn.busy(), "스테이지 화면 스토리 재생 중")
	mobile.call("system_back")
	await _frames(20)
	_check(not ssn.busy() and str(current_scene.get_script().resource_path).ends_with("stage_select.gd"), "스토리 중 뒤로 → 넘기기 (화면은 그대로)")
	router.call("go", "lobby")
	await _until(func() -> bool: return str(current_scene.get_script().resource_path).ends_with("lobby.gd"), 5.0)
	await _frames(2)
	# 전투
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	var cfg: Dictionary = BS.call("golden_cfg", "legion5_s09")
	cfg["speed"] = 0.0
	cfg["source"] = "test"
	cfg["story"] = "off"
	cfg["loading"] = false
	router.call("launch_battle", cfg)
	await _until(func() -> bool: return current_scene != null and current_scene.has_method("is_awaiting") and current_scene.is_awaiting(), 10.0)
	await _frames(3)
	var bt: Node = current_scene
	bt.ui_action("move")
	await _frames(2)
	_check(bt.mode == "target", "전투: 이동 고르기")
	mobile.call("system_back")
	await _frames(2)
	_check(bt.mode == "menu" and not bt.ui.settings.is_open(), "전투 뒤로 → 고르기 취소 (Esc 와 같음)")
	mobile.call("system_back")
	await _frames(2)
	_check(bt.ui.settings.is_open(), "취소할 것이 없으면 → 전투 설정 창 (나가기·항복)")
	mobile.call("system_back")
	await _frames(2)
	_check(not bt.ui.settings.is_open(), "뒤로 → 설정 창 닫힘")
	var lines: Variant = bt.story.lines_of("s9_pre")
	bt.ui.story.auto = false
	bt._story_play([{"key": "m6a_back", "lines": lines, "title": "", "battle": false}])
	await _frames(3)
	mobile.call("system_back")
	await _until(func() -> bool: return bt._hold == 0, 3.0)
	_check(not bt.ui.story.active, "스토리 중 뒤로 → 넘기기")
	router.call("go", "lobby")
	await _until(func() -> bool: return str(current_scene.get_script().resource_path).ends_with("lobby.gd"), 5.0)
	await _frames(2)
	_emu(false)


# ═══════════ 6) 백그라운드 ═══════════

func _disk() -> Dictionary:
	var raw := FileAccess.get_file_as_string(SAVE)
	var d: Variant = JsonX.parse(raw) if raw != "" else {}
	return d if d is Dictionary else {}


func _background() -> void:
	_emu(true, "pixel8")
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	var cfg: Dictionary = BS.call("golden_cfg", "balanced_s05")
	store.call("clear")
	for k: String in (cfg["save"] as Dictionary).keys():
		store.call("set_json", k, cfg["save"][k])
	cfg["save"] = BS.call("store_save", store)
	cfg["source"] = "store"
	cfg["speed"] = 0.0
	cfg["story"] = "off"
	cfg["loading"] = false
	store.call("flush")
	router.call("launch_battle", cfg)
	await _until(func() -> bool: return current_scene != null and current_scene.has_method("is_awaiting") and current_scene.is_awaiting(), 10.0)
	await _frames(3)
	var bt: Node = current_scene
	store.call("remove", ResumeRules.KEY)
	store.call("flush")
	store.call("set_json", "m6a_dirty", {"v": 1})   # 아직 디스크에 없는 값
	_check(not _disk().has("m6a_dirty") and not _disk().has(ResumeRules.KEY), "멈추기 전: 디스크에 바뀐 값·전투 저장 없음")
	var sound: Node = root.get_node("Sound")
	var bs0: int = bt.bg_saves
	# 실제 기기 순서: 초점 잃음 → 멈춤 (안드로이드는 홈으로 갈 때 창 크기도 잠깐 바뀜)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	root.size = Vector2i(2400, 1017)
	await _frames(2)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await _frames(2)
	root.size = MobileT.DEVICES["pixel8"]["size"]
	var d := _disk()
	_check(d.has("m6a_dirty"), "앱 멈춤 → Store 디스크에 씀")
	_check(d.has(ResumeRules.KEY) and int(bt.bg_saves) == bs0 + 1, "앱 멈춤 → 전투 이어하기 저장(gd_battle)이 디스크에")
	_check(sound.call("focus_gain") == 0.0 and AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "앱 멈춤 → 소리 끔 (설정 '창이 뒤에' 와 상관없이)")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(20)
	_check(sound.call("focus_gain") == 1.0 and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "돌아옴 → 소리 원래대로")
	# Billing: 돌아오면 미처리 확인 (기존 처리)
	var billing: Node = root.get_node("Billing")
	_check(billing.has_method("restore") and billing.get("_started") != null, "Billing 복귀 처리 있음 (RESUMED → restore)")
	# PC 에서는 FOCUS_OUT 이 '줄이기'(0.25) 그대로
	_emu(false)
	sound.call("set_focused", false)
	_check(absf(float(sound.call("focus_gain")) - 0.25) < 0.001, "PC 창이 뒤로 → 줄이기 0.25 그대로")
	sound.call("set_focused", true)
	router.call("go", "lobby")
	await _until(func() -> bool: return str(current_scene.get_script().resource_path).ends_with("lobby.gd"), 5.0)
	await _frames(2)
	store.call("remove", ResumeRules.KEY)


# ═══════════ 7) 설정 항목 숨김 ═══════════

func _settings() -> void:
	router.set("dry_run", true)
	_rich_save()
	i18n.call("_apply", "ko")
	for on: bool in [false, true]:
		_emu(on, "pixel8")
		var se: Node = await _open("settings")
		var disp := se.find_child("DisplayBox", true, false)
		var bg := se.find_child("BgAudio_lower", true, false)
		if on:
			_check(disp == null and bg == null, "모바일 설정: 창 모드·창 크기·'창이 뒤에 있을 때 소리' 없음")
		else:
			_check(disp != null and bg != null, "PC 설정: 창 모드·창 크기·뒤 소리 있음")
		await _close(se)
	_emu(true, "pixel8")
	var bt: Node = await _battle()
	if bt != null:
		bt.ui.settings.open()
		await _frames(3)
		var txt := ""
		var stack: Array = [bt.ui.settings.panel]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is Label:
				txt += (n as Label).text + "|"
		_check(not txt.contains(i18n.call("t", "gd.settings.window_mode")) and not txt.contains(i18n.call("t", "gd.settings.bg_audio")), "전투 설정 창에도 PC 전용 항목 없음")
		bt.queue_free()
		await _frames(3)
	_emu(false)
	router.set("dry_run", false)
