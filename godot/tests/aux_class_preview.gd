extends SceneTree
## check_outer_4b2.gd 가 부르는 보조: 다른 프로세스에서 저장 파일을 읽어 전직 미리보기(gd_class_preview)를 꺼냄 — '게임을 다시 켜도 같은 값' 확인
##   Godot --headless --path godot --script res://tests/aux_class_preview.gd -- <저장 경로> <uid> <직업>  →  PV: <JSON>

const BaselineData := preload("res://tests/baseline_data.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")
const StoreCtx := preload("res://scripts/logic/store_ctx.gd")
const Acad := preload("res://scripts/logic/academy_rules.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const JsonX := preload("res://scripts/core/json_exact.gd")


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var a := OS.get_cmdline_user_args()
	BaselineData.apply(self)   # 부른 시험(check_outer_4b2)과 같은 데이터 — --live 도 그대로 넘겨받음
	var store: Node = root.get_node("Store")
	store.call("use_path", a[0])
	var c := Ctx.new(Ctx.globals_from_db(root.get_node("DataDB")), randi(), StoreCtx.new(store))
	var pv := Acad.preview_kept(c, Profile.get_char(c, int(a[1])), a[2])
	print("PV: " + JsonX.stringify(pv))
	quit(0)
