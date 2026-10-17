extends Node
## Router — 화면 전환 한 곳 (웹의 location.href / 페이지 이동 대신). 오토로드 이름 Router.
##
##  go(name, params)  : 화면으로 (지금 화면을 기록에 쌓음). lobby 로 가면 기록을 비움 (로비 = 뿌리)
##  back()            : 기록에서 하나 꺼내 돌아감 (없으면 로비)
##  launch_battle(cfg): 전투 장면으로 (battle_scene.gd 의 pending 에 설정을 넣고 장면 바꿈)
##  params            : 지금 화면에 넘긴 값 (예: stage_select {daily: true})
##
##  뒤로 가기 입력: Esc(처리되지 않은 키) · 마우스 뒤로 가기 단추(XBUTTON1) → 지금 화면의 on_back() 을 부름.
##   화면은 열린 창(모달)을 먼저 닫고, 없으면 웹의 '뒤로' 단추와 같은 곳으로 간다. on_back 이 없는 화면(전투)은 무시 —
##   전투의 Esc 는 전투 장면이 따로 씀.

signal screen_changed(name: String)

const SCREENS := {
	"boot": "res://scenes/boot.tscn",
	"lobby": "res://scenes/outer/lobby.tscn",
	"stage_select": "res://scenes/outer/stage_select.tscn",
	"party_select": "res://scenes/outer/party_select.tscn",
	"settings": "res://scenes/outer/settings.tscn",
	"shop": "res://scenes/outer/shop.tscn",
	"battle": "res://scenes/battle/battle.tscn",
}
const NO_HISTORY := ["boot", "battle"]
const MAX_HISTORY := 16

var current := ""
var params: Dictionary = {}
var history: Array = []   # [{name, params}]
## 시험용: 실제로 장면을 바꾸지 않고 기록만 (go 를 부르면 last_request 에 남음)
var dry_run := false
var last_request: Dictionary = {}


## 한 번만 쓰는 값 (기록에 남기지 않음 — 예: stage_select {daily: true} = 요일 던전 창 바로 열기)
const ONE_SHOT := ["daily", "tab"]
## 장면을 바꾸는 중 (바뀐 장면이 들어올 때까지 다른 이동을 받지 않음 — 같은 프레임 연타로 두 번 이동하지 않게)
var _changing := false


func _ready() -> void:
	get_tree().scene_changed.connect(func() -> void: _changing = false)


func is_changing() -> bool:
	return _changing


## 한 번만 쓰는 값 꺼내기 (꺼내면 지움)
func consume(key: String) -> Variant:
	var v: Variant = params.get(key)
	params.erase(key)
	return v


## 기록에 남길 지금 화면 상태: 화면에 history_state() 가 있으면 그 값 (예: 고른 에피소드), 없으면 params 에서 한 번만 쓰는 값을 뺀 것
func _state_for_history() -> Dictionary:
	var s: Node = get_tree().current_scene if get_tree() != null else null
	if s != null and s.has_method("history_state"):
		return (s.call("history_state") as Dictionary).duplicate(true)
	var p := params.duplicate(true)
	for k: String in ONE_SHOT:
		p.erase(k)
	return p


func go(name: String, p: Dictionary = {}, push: bool = true) -> void:
	if not SCREENS.has(name):
		push_error("Router: 모르는 화면 %s" % name)
		return
	if _changing:
		return
	if push and current != "" and not NO_HISTORY.has(current) and current != name:
		history.append({"name": current, "params": _state_for_history()})
		if history.size() > MAX_HISTORY:
			history.pop_front()
	if name == "lobby":
		history.clear()
	current = name
	params = p.duplicate(true)
	last_request = {"name": name, "params": params.duplicate(true)}
	screen_changed.emit(name)
	if dry_run:
		return
	_changing = true
	_change.call_deferred(SCREENS[name])


## 기록에서 하나 돌아가기 (없으면 로비)
func back() -> void:
	if history.is_empty():
		go("lobby", {}, false)
		return
	var h: Dictionary = history.pop_back()
	go(str(h["name"]), h["params"], false)


## 전투 시작 — cfg 는 battle_scene.gd pending 형식 ({save, stage, practice, party, seed, source …})
func launch_battle(cfg: Dictionary) -> void:
	var bs: GDScript = load("res://scripts/battle/battle_scene.gd")
	bs.set("pending", cfg)
	go("battle", {}, false)


## 지금 화면에 뒤로 가기를 요청 (Esc · 마우스 뒤로 단추 · 시험)
func request_back() -> bool:
	var s: Node = get_tree().current_scene
	if s != null and s.has_method("on_back"):
		s.call("on_back")
		return true
	return false


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev as InputEventKey).keycode == KEY_ESCAPE:
		if request_back():
			get_viewport().set_input_as_handled()


## 마우스 뒤로 가기 단추는 단추 위에서 눌러도 받도록 GUI 보다 먼저 (단추·목록이 먹지 않게)
func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_XBUTTON1:
		if request_back():
			get_viewport().set_input_as_handled()


# 장면 바꾸기가 실패하면 scene_changed 가 오지 않으므로 여기서 잠금을 푼다
func _change(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Router: 장면 전환 실패 %s (%d)" % [path, err])
		_changing = false
