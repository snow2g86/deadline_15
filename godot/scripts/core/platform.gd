extends Node
## Platform — 어느 판(가게·기기)으로 도는지 한 곳에서 정함. 오토로드 이름 Platform.
##
##  store()  : "stove" · "steam" · "google" · "apple" · "dev" 중 하나
##             내보내기 프리셋의 기능 태그(custom_features)로 정함 — export_presets.cfg 의 "Windows (STOVE)" · "macOS (STOVE)" 는 stove.
##             태그가 없으면(편집기·명령줄·시험) "dev".
##  is_pc()  : 데스크톱(Windows·macOS·Linux) — Godot 기본 기능 태그 "pc"
##  is_mobile(): Android·iOS — 기본 기능 태그 "mobile", 가게 태그 google·apple, 실제 OS 이름 Android·iOS 중 하나라도 (6a)
##             + 개발용 모바일 흉내 (`-- --mobile`, 디버그만 — 아래)
##  is_touch(): 손가락으로 조작하는가 (모바일 또는 터치 화면) — 터치 문턱·길게 누르기 판단에
##  (6a) 개발용 모바일 흉내: `-- --mobile [기기]` (디버그 실행만) — 기기 pixel8(기본, 2400×1080 420dpi) · iphone(2778×1284 458) ·
##       ipad(2732×2048 264) · low(1600×720 270). 화면 배율·안전 영역·설정 숨김·뒤로 가기·길게 누르기가 그 기기처럼 (scripts/core/mobile.gd)
##       시험: emulate_mobile(true, "pixel8")
##  has_ads(): 광고 카드(상점 '광고 보고 받기')를 보일지. PC 가게판(stove·steam)은 광고가 없으므로 false.
##             dev 는 웹판과 같은 화면을 시험하도록 true (기존 시험·화면 사진이 웹 화면과 같게)
##  has_iap(): (예전 뜻 그대로 true — 5단계 시험이 고정) 결제 카드를 실제로 보일지·누를 수 있을지는 Billing.is_supported() · is_available()
##             (결제층 A: steam·출시 빌드 dev 는 결제 길이 없어 카드 숨김, stove·google·apple 은 SDK 를 붙이기 전이라 꺼진 카드)
##
##  시험·개발: 명령줄 `-- --store stove` (디버그 실행에서만) 또는 override_store("stove") 로 바꿀 수 있음.

const STORES := ["stove", "steam", "google", "apple", "dev"]
## PC 가게 (광고 없음)
const PC_STORES := ["stove", "steam"]

var _override := ""
var _os_override := ""
## (6a) 모바일 흉내 (디버그 · 시험) — "" 이면 끔, 아니면 기기 이름 (Mobile.DEVICES)
var mobile_emu := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--store")
	if i >= 0 and i + 1 < args.size() and OS.is_debug_build():
		override_store(args[i + 1])
	var j := args.find("--os")
	if j >= 0 and j + 1 < args.size() and OS.is_debug_build():
		override_os(args[j + 1])
	var m := args.find("--mobile")
	if m >= 0 and OS.is_debug_build():
		var dev := args[m + 1] if m + 1 < args.size() and not args[m + 1].begins_with("--") else "pixel8"
		emulate_mobile(true, dev)


## 기능 태그로 가게 이름 (여러 개면 STORES 순서의 앞 것)
static func detect_store() -> String:
	for s: String in STORES:
		if s != "dev" and OS.has_feature(s):
			return s
	return "dev"


func store() -> String:
	return _override if _override != "" else detect_store()


## 시험용 (모르는 이름이면 지움 → 기능 태그)
func override_store(name: String) -> void:
	_override = name if STORES.has(name) else ""


func is_pc() -> bool:
	if mobile_emu != "":
		return false
	if _override != "":
		return PC_STORES.has(_override) or (_override == "dev" and OS.has_feature("pc"))
	return OS.has_feature("pc")


func is_mobile() -> bool:
	if mobile_emu != "":
		return true
	if _override != "":
		# 가게를 바꿔 봐도(-- --store dev) 실제 휴대폰이면 모바일 (PC 가게 stove·steam 으로 바꾼 것만 아님)
		return _override == "google" or _override == "apple" or (_override == "dev" and detect_mobile(OS.get_name()))
	return detect_mobile(OS.get_name())


## (6a) 기능 태그 mobile · google · apple 또는 실제 OS 이름 (순수 판정 — 시험이 OS 이름을 넣어 봄)
static func detect_mobile(os_name: String) -> bool:
	return OS.has_feature("mobile") or OS.has_feature("google") or OS.has_feature("apple") or os_name == "Android" or os_name == "iOS"


## (6a) 손가락 조작 (모바일 · 흉내 · 터치 화면)
func is_touch() -> bool:
	return is_mobile() or DisplayServer.is_touchscreen_available()


## (6a) 모바일 흉내 켜기·끄기 (디버그 · 시험). 모르는 기기 이름이면 pixel8
func emulate_mobile(on: bool, device: String = "pixel8") -> void:
	if not OS.is_debug_build():
		on = false
	mobile_emu = (device if device != "" else "pixel8") if on else ""


static func store_has_ads(s: String) -> bool:
	return not PC_STORES.has(s)


func has_ads() -> bool:
	return store_has_ads(store())


func has_iap() -> bool:
	return true




## (결제층 A) 운영체제 이름 (OS.get_name — "Windows" · "macOS" …). 시험·개발은 override_os("Windows") 또는 -- --os Windows (디버그만)
##  STOVE 결제 SDK 는 Windows 64비트 DLL 이라 STOVE 맥 판에는 결제 길이 없음 (backend_stove.is_supported)
func os_name() -> String:
	return _os_override if _os_override != "" else OS.get_name()


func override_os(name: String) -> void:
	_os_override = name if OS.is_debug_build() else ""
