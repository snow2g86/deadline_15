extends Control
## 시작 화면 (메인 씬) — 웹 #splash (제목 DEADLINE 15 + loading…) 를 잠깐 보여 준 뒤 로비로 (Router).
##  지휘관 첫 설정은 로비가 엽니다 (웹 index.js 와 같음). 프롤로그(에피소드 1 시작 장면)는 웹처럼 첫 출격 직전에 나옵니다.
##
##  개발용 명령줄 (Godot --path godot -- <인자>):
##   --dev                  예전 시작 화면 + 전투 시험 실행기 (scripts/ui/dev_launcher.gd)
##   --screen <이름>        바로 그 화면으로 (lobby · stage_select · party_select · settings)
##   --save <경로>          다른 저장 파일 사용 (예: user://dev_save.json — 진짜 세이브를 건드리지 않고 시험)
##   --lang <코드>          이번 실행만 언어 (저장하지 않음)
##  (5단계) 출시 빌드(디버그가 아닌 빌드)에서는 --dev · --save · --screen 을 받지 않음 (Platform 의 --store 와 같은 정책)

const DevLauncher := preload("res://scripts/ui/dev_launcher.gd")
const OKit := preload("res://scripts/ui/outer_kit.gd")
const SPLASH_SECS := 0.6

var _title: Label
var _loading: Label
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var args := OS.get_cmdline_user_args() if OS.is_debug_build() else PackedStringArray()
	var i18n: Node = get_node_or_null("/root/I18n")
	var store: Node = get_node_or_null("/root/Store")
	var save_i := args.find("--save")
	if save_i >= 0 and save_i + 1 < args.size() and store != null:
		store.call("use_path", args[save_i + 1])
		if i18n != null:
			i18n.call("reload")
	var lang_i := args.find("--lang")
	if lang_i >= 0 and lang_i + 1 < args.size() and i18n != null:
		i18n.call("_apply", args[lang_i + 1])
	if args.has("--dev"):
		var dl: Control = DevLauncher.new()
		dl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dl)
		return
	var bg := ColorRect.new()
	bg.color = OKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := OKit.vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	_title = OKit.label(36, OKit.GOLD, 900)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text = i18n.call("t", "common.game_title") if i18n != null else "DEADLINE 15"
	v.add_child(_title)
	_loading = OKit.label(14, OKit.DIM, 600)
	_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.text = i18n.call("t", "common.loading") if i18n != null else "loading..."
	v.add_child(_loading)
	var screen := "lobby"
	var si := args.find("--screen")
	if si >= 0 and si + 1 < args.size():
		screen = args[si + 1]
	var router: Node = get_node_or_null("/root/Router")
	get_tree().create_timer(SPLASH_SECS).timeout.connect(func() -> void:
		if router != null:
			router.call("go", screen, {}, false))


func _process(delta: float) -> void:
	_t += delta
	if _loading != null:
		_loading.modulate.a = 0.55 + 0.45 * absf(sin(_t * 2.2))
