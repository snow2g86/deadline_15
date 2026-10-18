extends Node
## Platform — 어느 판(가게·기기)으로 도는지 한 곳에서 정함. 오토로드 이름 Platform.
##
##  store()  : "stove" · "steam" · "google" · "apple" · "dev" 중 하나
##             내보내기 프리셋의 기능 태그(custom_features)로 정함 — export_presets.cfg 의 "Windows (STOVE)" · "macOS (STOVE)" 는 stove.
##             태그가 없으면(편집기·명령줄·시험) "dev".
##  is_pc()  : 데스크톱(Windows·macOS·Linux) — Godot 기본 기능 태그 "pc"
##  is_mobile(): Android·iOS — 기본 기능 태그 "mobile"
##  has_ads(): 광고 카드(상점 '광고 보고 받기')를 보일지. PC 가게판(stove·steam)은 광고가 없으므로 false.
##             dev 는 웹판과 같은 화면을 시험하도록 true (기존 시험·화면 사진이 웹 화면과 같게)
##  has_iap(): 결제 카드 — 지금은 모든 판에서 보임 (결제 연동은 다음 단계, 카드는 '추후 오픈 예정' 그대로)
##
##  시험·개발: 명령줄 `-- --store stove` (디버그 실행에서만) 또는 override_store("stove") 로 바꿀 수 있음.

const STORES := ["stove", "steam", "google", "apple", "dev"]
## PC 가게 (광고 없음)
const PC_STORES := ["stove", "steam"]

var _override := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--store")
	if i >= 0 and i + 1 < args.size() and OS.is_debug_build():
		override_store(args[i + 1])


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
	if _override != "":
		return PC_STORES.has(_override) or (_override == "dev" and OS.has_feature("pc"))
	return OS.has_feature("pc")


func is_mobile() -> bool:
	if _override != "":
		return _override == "google" or _override == "apple"
	return OS.has_feature("mobile")


static func store_has_ads(s: String) -> bool:
	return not PC_STORES.has(s)


func has_ads() -> bool:
	return store_has_ads(store())


func has_iap() -> bool:
	return true


## 내보낸 빌드인가 (편집기·명령줄 실행이 아님)
func is_release_build() -> bool:
	return OS.has_feature("template")
