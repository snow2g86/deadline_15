extends Node2D
## 전투 장면 (3b) — 화면만. 규칙은 전부 엔진(scripts/logic/battle/battle_engine.gd)이 정하고, 이 장면은
##  ① 엔진 신호(bus_event·fx_event)를 받아 대기열에 쌓았다가 시간에 맞춰 재생하고 (엔진은 기다리지 않음)
##  ② 재생이 끝나고 엔진이 클랜원 입력을 기다리면 메뉴를 띄워 플레이어 조작을 엔진 명령(command)으로 바꾼다.
##  화면 상태는 사건의 사본으로만 바꾸고, 입력을 받을 때(재생이 따라잡은 때)만 엔진 상태로 한 번 맞춘다.
##  (3b) HUD(윗줄·행동 순서·카드·미니맵·설정)·툴팁·적 팝업·직업별 연출·픽셀 투사체·화면 흔들림·결과·로딩·스토리 대사.
##  로딩·스토리 대사는 재생 대기열을 붙잡을 뿐(_hold) — 엔진 진행·결과는 그대로.
##  시험용 입구(UI 수준): ui_action · ui_pick_skill · ui_pick_item · ui_click_cell · ui_pick_face · ui_cancel
##  (마우스·단축키·메뉴 단추도 모두 이 함수들을 거침 — tests/check_battle_scene.gd 가 황금 기록을 이 입구로 재생)
##  자세한 구조는 scripts/battle/README.md

signal input_ready(unit_id: int)
signal battle_over(result: Dictionary)

const Ctx := preload("res://scripts/logic/ctx.gd")
const BattleEngine := preload("res://scripts/logic/battle/battle_engine.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")
const Js := preload("res://scripts/logic/js.gd")
const StageRules := preload("res://scripts/logic/stage_rules.gd")
const Num := preload("res://scripts/core/num.gd")
const Iso := preload("res://scripts/battle/iso.gd")
const SpriteDB := preload("res://scripts/battle/sprite_db.gd")
const BattleMap := preload("res://scripts/battle/battle_map.gd")
const UnitView := preload("res://scripts/battle/unit_view.gd")
const FxLayer := preload("res://scripts/battle/fx_layer.gd")
const PixelFx := preload("res://scripts/battle/pixel_fx.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")
const Icons := preload("res://scripts/battle/icons.gd")
const UnitInfo := preload("res://scripts/battle/unit_info.gd")
const StoryBattle := preload("res://scripts/battle/story_battle.gd")
const Kit := preload("res://scripts/battle/ui_kit.gd")
const ResumeRules := preload("res://scripts/logic/resume_rules.gd")
const StoreCtx := preload("res://scripts/logic/store_ctx.gd")
const SaveStore := preload("res://scripts/logic/save_store.gd")

const BOOT_SCENE := "res://scenes/boot.tscn"
const GOLDEN := "res://tests/golden/"
## 디버그 기본 세이브 (Store 에 파티가 없을 때): 황금 기록의 가짜 세이브
const DEBUG_GOLDEN := "balanced_s05"
## 엔진 신호 중 그 순간의 전장 전체를 사본으로 남길 것 (재생 중 화면을 엔진의 그 시점과 맞추는 기준점)
const SNAP_BUS := ["turn_start", "turn_end", "unit_added", "wave_spawn", "round_end"]
const SNAP_FX := ["redraw_units", "redraw_terrain", "chest_open"]
const SPEEDS := [1.0, 2.0, 4.0]
## 화면 사본에 덧붙이는 엔진 유닛 값 (배지·카드·툴팁 — 읽기만)
const SNAP_EXTRA := ["lv", "name", "role", "actionRec", "furyBuff", "defBuff", "disarmed", "channeling", "_rootedTurns", "_bleedTurns",
	"_sanctuaryTurns", "_phalanxTurns", "_empowerTurns", "_cursed", "_sacrificeKnight", "_sacrificeDmgCount", "_tenacityDef", "skillLv", "summonerId"]
## 로딩 화면 최소 시간 (초)
const LOADING_MIN := 0.7

## 런처(boot.gd)가 넣고 장면이 _ready 에서 꺼내 씀
##  { save, stage, practice, inject, maxRounds, seed, source("store"|"debug"|"test"), record, speed(0 = 연출 없이 즉시, 없으면 설정값), autoplay(황금 이름),
##    story("on"|"off"|"auto" — auto 는 시험: 대사를 저절로 넘김), loading(bool),
##    resume(4b-1: 엔진 save_state 사전 — 있으면 새로 시작하지 않고 이어하기. save 는 지금 Store 값) }
static var pending: Dictionary = {}

var cfg: Dictionary = {}
var D: Dictionary
var eng: BattleEngine
var iso: Iso
var sdb: SpriteDB
var map: BattleMap
var fx: FxLayer
var pfx: PixelFx
var ui: BattleUI
var cam: Camera2D
var world: Node2D
var unit_layer: Node2D
var i18n: Node
var store: Node
var icons: Icons
var info: UnitInfo
var story: StoryBattle

## 재생
var speed := 1.0
var _speed_i := 0
var _evq: Array = []          # [종류("bus"|"fx"), 이름, 자료, 전장 사본|null]
var _qi := 0                  # 대기열 읽은 위치
var _wait := 0.0
var _clock := 0.0             # 재생 시계 (속도 반영 초)
var _sched: Array = []        # [남은 초, Callable] — 타격 시점 등
var _motion: Dictionary = {}  # 공격자 id → 타격 시각 (fx attack 에서 동작을 이미 시작한 경우)
var _hit_at: Dictionary = {}  # 대상 id → 피해가 들어가는 시각
var _eng_status := ""
var _listening := false
var result: Dictionary = {}
var _over := false
## 재생을 붙잡는 이유 수 (로딩·스토리 대사) — 0 이 아니면 대기열을 진행하지 않음
var _hold := 0
var _loading_t := 0.0
var _loading_on := false
var reduce_motion := false
## 항복을 연출이 끝난 뒤로 미룸 (적 차례 연출 중 항복하면 아직 안 보인 결과까지 반영되지 않게)
var _surrender_pending := false
var _leaving := false
## (4b-1) 저장하고 로비로 — 연출 중이면 입력을 기다릴 때로 미룸 (항복과 같은 방식)
var _leave_pending := false
## 이어하기로 시작한 전투인가 · 자동 저장 횟수 (시험·확인용)
var resumed := false
var autosaves := 0
var _rc: Object = null   # ResumeRules 용 ctx (진짜 Store)
## 전투 시작 때 넘긴 세이브 (끝나고 Store 에 바뀐 키만 되돌려 씀) · 인벤토리 eid (장비 보상 짝짓기 기준)
var _save_in: Dictionary = {}
var _inv_eids0: Dictionary = {}
var _db: Node
## (5단계) 소리 — Sound 오토로드 (없으면 소리 없이). 아군 차례가 시작되면 메뉴가 뜰 때 'select' (웹 selU)
var sound: Node
var _select_sfx := false
var _end_sfx := false
## 창 닫기 때 저장한 횟수 (시험용)
var close_saves := 0
## 시험용 (cfg.log_events): 엔진이 낸 사건 [종류, 이름, 자료, 그때 actCount] — tests/check_pc5.gd 가 소리 규칙을 맞춰 봄
var ev_log: Array = []

## 화면 상태
var units: Dictionary = {}    # id → UnitView
var view_ter: Array = []
var view_chests: Array = []
var view_safe: Array = []
var view_turn := 1
var view_phase := "player"
var view_eq := 0
var view_espwn := 0
var view_actcount := 0
var view_breached := 0
var cur_id := -1
var show_threat := false
var _hud_dirty := true
var _badges_dirty := true
var _shake_t := 9.0
var _shake_dur := 0.3
var _shake_amp := 4.0

## 조작
var mode := "busy"            # busy · menu · skills · items · target · face · over
var target_op := ""           # move · attack · shove · skill · potion · siege · climb
var target_idx := -1
var target_cells: Dictionary = {}   # "x,y" → 하이라이트 종류
var heal_cells: Dictionary = {}
var face_op := ""
var face_opts: Array = []
var last_result: Dictionary = {}
## 진짜 실패한 명령의 안내 (메뉴로 돌아와도 보이고, 다음 조작 때 지움)
var fail_hint := ""
var _drag_from := Vector2.ZERO
var _dragging := false
var _press := false
var _cam_from := Vector2.ZERO
## 마우스 툴팁: 대상 ("u:id" | "c:x,y" | "") · 머문 시간
var _hover_key := ""
var _hover_t := 0.0
var _hover_pos := Vector2.ZERO
var _nav_hover := -1

## 자동 진행 (Movie Maker 화면 확인용: 황금 기록 명령을 사람이 누르듯 천천히)
var _auto_cmds: Array = []
var _auto_i := 0
var _auto_t := 0.0
var _auto_step := 0


# ═══════════ 준비 ═══════════

func _svc(n: String) -> Node:
	return get_node_or_null("/root/" + n)


func _ready() -> void:
	i18n = _svc("I18n")
	store = _svc("Store")
	sound = _svc("Sound")
	var db: Node = _svc("DataDB")
	if db == null:
		push_error("battle_scene: DataDB 오토로드가 없습니다")
		return
	D = Ctx.globals_from_db(db)
	cfg = pending.duplicate(true) if not pending.is_empty() else _cfg_from_cmdline()
	pending = {}
	var sett: Dictionary = _settings()
	# 움직임 줄이기: 저장한 설정 또는 OS 설정(macOS 손쉬운 사용 '동작 줄이기')
	reduce_motion = bool(sett.get("reduceMotion", false)) or _os_reduce_motion()
	if cfg.has("speed"):
		speed = float(cfg["speed"])
	else:
		var ps: Variant = sett.get("playSpeed", 1)
		speed = float(ps) if (typeof(ps) == TYPE_INT or typeof(ps) == TYPE_FLOAT) and [1.0, 2.0, 4.0].has(float(ps)) else 1.0
	_speed_i = maxi(0, SPEEDS.find(speed))
	sdb = SpriteDB.new(D)
	icons = Icons.get_for(D)
	info = UnitInfo.new(D, i18n)
	eng = BattleEngine.new(D, int(cfg.get("seed", 1)))
	eng.record_enabled = bool(cfg.get("record", false))
	eng.bus_event.connect(_on_bus)
	eng.fx_event.connect(_on_fx)
	if store != null:
		_rc = Ctx.new(D, 1, StoreCtx.new(store))
	resumed = cfg.get("resume") is Dictionary
	if resumed:
		# (4b-1) 이어하기: 저장한 엔진 상태 그대로 + 저장소는 지금 Store 값 (나가 있는 동안 바뀐 골드·인벤토리 반영 — 웹은 저장소가 하나라 늘 그 값)
		if not eng.load_state(cfg["resume"]):
			# (4b-2) 이전 판 저장 — 로비가 먼저 막지만, 혹시 들어와도 새로 시작하지 않고 저장을 지우고 로비로 (안내는 로비가)
			push_warning("battle_scene: 이전 판 전투 저장이라 이어할 수 없음")
			if _rc != null:
				ResumeRules.clear_gd(_rc)
			eng.dispose()
			eng = null
			if _svc("Router") != null:
				_svc("Router").call_deferred("go", "lobby")
			return
		_resume_sync_store(cfg.get("save", {}))
	else:
		eng.start({"save": cfg.get("save", {}), "stage": cfg["stage"], "practice": bool(cfg.get("practice", false)),
			"inject": cfg.get("inject", []), "maxRounds": int(cfg.get("maxRounds", 0))})
		# 새 전투가 예전 저장 전투를 덮어씀 (웹도 전투 저장은 하나)
		if _is_store() and _rc != null:
			ResumeRules.clear_gd(_rc)
	_listening = true
	_db = db
	_save_in = (cfg.get("save", {}) as Dictionary).duplicate(true)
	_inv_eids0 = eng.q.inventory_eids()
	info.set_roster(eng.c.store.get_json("game_roster"))
	_build_world()
	_setup_story(db)
	var autoplay := str(cfg.get("autoplay", ""))
	if autoplay != "":
		var g: Variant = _read_golden(autoplay)
		if typeof(g) == TYPE_DICTIONARY:
			for e: Dictionary in g["events"]:
				if e["ev"] == "cmd":
					_auto_cmds.append(e)
	if int(cfg.get("cam_dir", 0)) != 0:
		rotate_cam(int(cfg["cam_dir"]))
	if not resumed:
		eng.begin()
	_eng_status = eng.run()
	if i18n != null and i18n.has_signal("language_changed"):
		i18n.connect("language_changed", _on_language)
	# (5단계) 배경음: 이어하기는 웹 resumeBattle 처럼 바로, 새 전투는 로딩이 끝난 뒤 (_after_loading — 웹 _showLoading().then(bgmStart))
	if resumed:
		_bgm_start()
	_start_loading()


## OS 의 '동작 줄이기' (macOS 만 — defaults 로 읽음, 화면 없는 실행·다른 OS 는 false)
static func _os_reduce_motion() -> bool:
	if OS.get_name() != "macOS" or DisplayServer.get_name() == "headless":
		return false
	var out: Array = []
	if OS.execute("defaults", ["read", "com.apple.universalaccess", "reduceMotion"], out, false) != 0:
		return false
	return not out.is_empty() and str(out[0]).strip_edges() == "1"


## Store 세이브로 전투 설정 (시작 화면·다시 하기가 같이 씀): Store 의 모든 키를 넘김 —
##  엔진이 전투 끝에 쓰는 값(game_soul·game_mats·인벤토리 …)이 처음부터 진짜 값이어야 되돌려 쓸 때 덮어쓰지 않음
static func store_save(store_node: Node) -> Dictionary:
	var save: Dictionary = {}
	for k: String in store_node.call("keys"):
		if k == ResumeRules.KEY:
			continue   # 저장 전투 자체는 전투 저장소에 넣지 않음 (넣으면 저장할 때마다 겹겹이 커짐)
		var v: Variant = store_node.call("get_json", k)
		if v != null:
			save[k] = v
	return save


func _settings() -> Dictionary:
	if store != null:
		(load("res://scripts/logic/settings_rules.gd") as GDScript).call("migrate_web_speed", store)
	var v: Variant = store.call("get_json", "game_settings", {}) if store != null else {}
	return v if v is Dictionary else {}


## 직접 실행(F6·명령줄)할 때: -- --golden 이름 [--autoplay] [--speed n] 또는 기본 디버그 세이브
func _cfg_from_cmdline() -> Dictionary:
	var args := OS.get_cmdline_user_args()
	var name := DEBUG_GOLDEN
	var auto := false
	var sp := 1.0
	for i in args.size():
		if args[i] == "--golden" and i + 1 < args.size():
			name = args[i + 1]
		elif args[i] == "--autoplay":
			auto = true
		elif args[i] == "--speed" and i + 1 < args.size():
			sp = args[i + 1].to_float()
	var c := golden_cfg(name)
	c["speed"] = sp
	for j in args.size():
		if args[j] == "--rotate" and j + 1 < args.size():
			c["cam_dir"] = args[j + 1].to_int()
		elif args[j] == "--stage" and j + 1 < args.size():
			c["stage"] = {"id": args[j + 1].to_int()}
			c["inject"] = []
		elif args[j] == "--no-story":
			c["story"] = "off"
	if auto:
		c["autoplay"] = name
		c["story"] = c.get("story", "autoplay")
	return c


static func _read_golden(name: String) -> Variant:
	var path := GOLDEN + name + ".json"
	if not FileAccess.file_exists(path):
		return null
	return JsonExact.parse(FileAccess.get_file_as_string(path))


## 황금 기록 하나로 전투 설정 (세이브·스테이지·시드·주입·라운드 상한)
static func golden_cfg(name: String) -> Dictionary:
	var g: Variant = _read_golden(name)
	if typeof(g) != TYPE_DICTIONARY:
		return {}
	var sc: Dictionary = g["scenario"]
	return {"save": g["save"], "stage": sc["stage"], "practice": sc["practice"], "inject": g["setup"]["inject"],
		"maxRounds": int(sc["maxRounds"]), "seed": int(sc["seed"]), "source": "debug", "golden": name}


func _build_world() -> void:
	var S: Dictionary = eng.S
	iso = Iso.new(int(D["COLS"]), int(D["ROWS"]), D["TI"])
	view_ter = Js.deep(S["ter"])
	iso.ter = view_ter
	_add_background()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	map = BattleMap.new()
	map.name = "Map"
	var stage: Dictionary = S["cStage"] if typeof(S["cStage"]) == TYPE_DICTIONARY else {}
	var mt := str(stage.get("mapType", "plains"))
	map.setup(iso, D, mt, sdb, mt == "volcano")
	world.add_child(map)
	unit_layer = Node2D.new()
	unit_layer.name = "Units"
	world.add_child(unit_layer)
	fx = FxLayer.new()
	fx.name = "Fx"
	fx.iso = iso
	fx.icons = icons
	fx.speed = speed
	world.add_child(fx)
	pfx = PixelFx.new()
	pfx.name = "PixelFx"
	pfx.time_scale = speed
	world.add_child(pfx)
	view_chests = _chest_list()
	view_safe = (S["safeZones"] as Array).duplicate()
	map.chests = view_chests
	map.rebuild()
	map.set_safe(view_safe)
	var snaps: Array = []
	for u: Dictionary in S["units"]:
		if float(u["hp"]) > 0.0:
			snaps.append(_unit_snap(u))
	for v: Dictionary in snaps:
		_add_unit(v, false)
	cam = Camera2D.new()
	cam.name = "Camera"
	add_child(cam)
	cam.position = iso.world_size() / 2.0 + Vector2(0, 10)
	cam.make_current()
	ui = BattleUI.new()
	ui.name = "UI"
	ui.reduce_motion = reduce_motion
	add_child(ui)
	ui.setup(i18n, icons, store)
	ui.action_pressed.connect(func(op: String) -> void: ui_action(op))
	ui.skill_pressed.connect(func(idx: int) -> void: ui_pick_skill(idx))
	ui.item_pressed.connect(func(k: String, idx: int) -> void: ui_pick_item(k, idx))
	ui.cancel_pressed.connect(func() -> void: ui_cancel())
	ui.rotate_pressed.connect(rotate_cam)
	ui.threat_pressed.connect(toggle_threat)
	ui.speed_pressed.connect(_cycle_speed)
	ui.back_pressed.connect(_go_back)
	ui.order.unit_clicked.connect(_on_unit_nav_click)
	ui.order.unit_hover.connect(_on_nav_hover)
	ui.cards.unit_clicked.connect(_on_unit_nav_click)
	ui.cards.unit_hover.connect(_on_nav_hover)
	ui.minimap.setup(iso, D["TI"])
	ui.minimap.pan_to.connect(func(p: Vector2) -> void:
		cam.position = p
		_clamp_cam())
	ui.settings.surrender_confirmed.connect(surrender)
	ui.settings.leave_confirmed.connect(leave_battle)
	ui.settings.allow_leave = _is_store() and _svc("Router") != null
	ui.settings.speed_chosen.connect(set_speed_index)
	ui.settings.reduce_motion_changed.connect(set_reduce_motion)
	ui.result_view.button_pressed.connect(_on_result_button)
	ui.story.closed.connect(_on_story_closed)
	_update_cam_label()
	ui.set_speed_label("%dx" % int(SPEEDS[_speed_i]))
	view_turn = int(S["turn"])
	view_eq = (S["eQ"] as Array).size()
	view_espwn = int(S["eSpwn"])
	view_actcount = int(S["actCount"])
	view_breached = int(S["breached"])
	_refresh_fog_view()
	_refresh_loops()
	_refresh_fade()
	ui.minimap.rebuild(_minimap_units())
	_refresh_hud()


## 배경 (웹 #map-container: --bg #0a0e1a + 위쪽 가운데 푸른 빛 radial-gradient(ellipse at 50% 30%, rgba(20,40,80,.4), transparent 70%))
func _add_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	layer.name = "Background"
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("0a0e1a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	var g := Gradient.new()
	g.set_color(0, Color(20 / 255.0, 40 / 255.0, 80 / 255.0, 0.4))
	g.set_color(1, Color(20 / 255.0, 40 / 255.0, 80 / 255.0, 0.0))
	g.set_offset(1, 0.7)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.3)
	gt.fill_to = Vector2(1.2, 0.3)
	gt.width = 256
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tr)


func _chest_list() -> Array:
	var out: Array = []
	for ch: Dictionary in eng.S["chests"]:
		out.append([int(ch["x"]), int(ch["y"])])
	return out


## 화면용 유닛 사본 = 엔진 unit_view + 그림·배지·카드에 필요한 몇 값 (읽기만)
func _unit_snap(u: Dictionary) -> Dictionary:
	var v: Dictionary = eng.unit_view(u)
	v["gender"] = str(u.get("gender", "m")) if u.get("gender") != null else "m"
	v["ha"] = Js.truthy(u.get("ha"))
	v["stunned"] = Js.num(u.get("stunned"))
	v["frozen"] = Js.num(u.get("frozen"))
	if u.has("summonTurns"):
		v["summonTurns"] = u["summonTurns"]
	for k: String in SNAP_EXTRA:
		if u.has(k):
			var x: Variant = u[k]
			v[k] = Js.deep(x) if (typeof(x) == TYPE_DICTIONARY or typeof(x) == TYPE_ARRAY) else x
	return v


## 엔진의 지금 전장 전체 사본 (신호를 받은 그 순간 — 엔진은 아직 진행 중)
func _snap_engine() -> Dictionary:
	var us: Array = []
	for u: Dictionary in eng.S["units"]:
		if float(u["hp"]) > 0.0:
			us.append(_unit_snap(u))
	return {"units": us, "ter": Js.deep(eng.S["ter"]), "chests": _chest_list(), "safe": (eng.S["safeZones"] as Array).duplicate(),
		"turn": int(eng.S["turn"]), "eq": (eng.S["eQ"] as Array).size(), "espwn": int(eng.S["eSpwn"]), "act": int(eng.S["actCount"]),
		"breached": int(eng.S["breached"])}


func _add_unit(v: Dictionary, spawn: bool) -> UnitView:
	var uv := UnitView.new()
	uv.name = "U%d" % int(v["id"])
	uv.reduce_motion = reduce_motion
	unit_layer.add_child(uv)
	uv.setup(iso, sdb, v, speed, icons)
	if spawn:
		uv.spawn_anim()
		if bool(v.get("isSummon", false)):
			fx.summon_fx(uv.position + Vector2(0, -20))
	units[int(v["id"])] = uv
	_badges_dirty = true
	_hud_dirty = true
	return uv


# ═══════════ 로딩 · 스토리 ═══════════

func _start_loading() -> void:
	var st: Variant = eng.S["cStage"]
	var title: Array = info.stage_title(st)
	if speed <= 0.0 or not bool(cfg.get("loading", true)):
		_after_loading()
		return
	var tips: Variant = i18n.t_raw("battle.loading_tips") if i18n != null else null
	var tip := ""
	if tips is Array and not (tips as Array).is_empty():
		tip = str(tips[randi() % (tips as Array).size()])   # 화면 난수 (엔진 난수와 무관)
	ui.loading.show_for(("%s · %s" % [title[0], title[1]]) if str(title[1]) != "" else str(title[0]), tip)
	_hold += 1
	_loading_on = true
	_loading_t = 0.0


## 로딩 중 프레임마다: 다른 카메라 방향 묶음을 하나씩 미리 만들고, 타일 그림 굽기를 기다림
func _loading_tick(delta: float) -> void:
	_loading_t += delta
	var more := map.prebuild_step()
	var f := clampf(_loading_t / LOADING_MIN, 0.0, 1.0)
	ui.loading.progress(f * (0.6 if more else 1.0))
	if not more and _loading_t >= LOADING_MIN and not map._baking:
		_loading_on = false
		map.finish_prebuild()
		ui.loading.finish()
		_hold -= 1
		_after_loading()


func _after_loading() -> void:
	if not resumed:
		_bgm_start()
	var st: Variant = eng.S["cStage"]
	if speed > 0.0 and st != null:
		var title: Array = info.stage_title(st)
		var sub := story.stage_label(int(st["id"])).split(" ")[0] if not Js.truthy(st.get("daily")) else str(title[0])
		ui.show_stage_banner(sub, str(title[1]) if str(title[1]) != "" else str(title[0]))
	# 출전 전 대사 (프롤로그·전투 전) → 'start' 는 첫 turn_start 재생 때. 이어하기는 이미 시작한 전투라 건너뜀
	if not resumed:
		_story_play(story.intro())


func _setup_story(db: Node) -> void:
	story = StoryBattle.new(D, i18n, icons)
	var mode_s := str(cfg.get("story", "on" if speed > 0.0 else "off"))
	story.enabled = mode_s != "off"
	ui.story.auto = mode_s == "auto" or mode_s == "autoplay"
	ui.story.set("auto_delay", 1.4 if mode_s == "autoplay" else 0.0)
	story.stage = eng.S["cStage"]
	var dev: Variant = store.call("get_str", "game_story_dev") if store != null else null
	story.load_data(db, str(i18n.get("current_lang")) if i18n != null else "ko", dev)
	story.roster = eng.c.store.get_json("game_roster")
	if str(cfg.get("source", "")) == "store" and store != null:
		var sv: Variant = store.call("get_json", StoryBattle.SEEN_KEY, {})
		story.seen = sv if sv is Dictionary else {}
		story.store = store
	else:
		var sv2: Variant = (cfg.get("save", {}) as Dictionary).get(StoryBattle.SEEN_KEY)
		story.seen = (sv2 as Dictionary).duplicate() if sv2 is Dictionary else {}


var _story_scenes: Array = []
## 재생한 장면 키 (시험·확인용)
var story_log: Array = []
var _story_cur: Dictionary = {}
var _story_after: Callable = Callable()


## 장면 묶음 재생 (재생 대기열·입력을 붙잡음) — done 은 다 끝난 뒤 부를 것
func _story_play(scenes: Array, done: Callable = Callable()) -> void:
	if scenes.is_empty():
		if done.is_valid():
			done.call()
		return
	if _story_scenes.is_empty() and _story_cur.is_empty():
		_hold += 1
	_story_scenes.append_array(scenes)
	if done.is_valid():
		_story_after = done
	if _story_cur.is_empty():
		_story_next()


func _story_next() -> void:
	if _story_scenes.is_empty():
		_story_cur = {}
		_hold -= 1
		if _story_after.is_valid():
			var f := _story_after
			_story_after = Callable()
			f.call()
		return
	_story_cur = _story_scenes.pop_front()
	ui.hide_menu()
	ui.info.hide_tip()
	ui.info.hide_popup()
	# 재생할 때마다 지금 언어의 대본으로 (전투 중에 언어를 바꿔도)
	story.load_data(_db, str(i18n.get("current_lang")) if i18n != null else "ko", store.call("get_str", "game_story_dev") if store != null else null)
	var src: Variant = story.lines_of(str(_story_cur["key"]))
	var lines := story.resolve_lines(src if src is Array and not (src as Array).is_empty() else _story_cur["lines"])
	if lines.is_empty():
		_story_next()
		return
	ui.story.play(lines, {"title": _story_cur.get("title", ""), "battle": _story_cur.get("battle", false), "skip_text": _t("story.skip")})


func _on_story_closed() -> void:
	if _story_cur.is_empty():
		return
	story.mark_seen(str(_story_cur["key"]))
	story_log.append(str(_story_cur["key"]))
	_story_next()


## 웹 StoryBattle.allyName: 글자가 있는 이름만 (아이콘뿐인 이름은 비워 대본 기본값 '클랜원')
static var _name_re := RegEx.create_from_string("[A-Za-z0-9\\x{3131}-\\x{D79D}\\x{00C0}-\\x{024F}]")


## 지금 화면 상태 (스토리 조건 확인용)
func _story_view() -> Dictionary:
	var us: Array = []
	var names: Dictionary = {}
	for uv: UnitView in units.values():
		if uv.has_meta("doomed"):
			continue
		us.append(uv.d)
		var nm := str(uv.d.get("name", ""))
		names[uv.d["id"]] = info.unit_name(uv.d) if _name_re.search(nm) != null else ""
	return {"units": us, "espwn": view_espwn, "ended": _over, "name_of": names}


func is_story_playing() -> bool:
	return not _story_cur.is_empty()


# ═══════════ 엔진 신호 → 대기열 ═══════════

func _on_bus(name: String, data: Dictionary) -> void:
	if not _listening:
		return
	if name == "unit_attacked":
		data["_tactic"] = _tactic_of(data)
	if bool(cfg.get("log_events", false)):
		ev_log.append(["bus", name, data, int(eng.S.get("actCount", 0))])
	_evq.append(["bus", name, data, _snap_engine() if SNAP_BUS.has(name) else null])


func _on_fx(kind: String, data: Dictionary) -> void:
	if not _listening:
		return
	if bool(cfg.get("log_events", false)):
		ev_log.append(["fx", kind, data, int(eng.S.get("actCount", 0))])
	_evq.append(["fx", kind, data, _snap_engine() if SNAP_FX.has(kind) else null])


## 맞는 순간의 전술 보너스 (웹 VFX: attacker._lastTactic 을 떠오르는 글자로) — 엔진은 알림 전에 이 값을 지우므로
##  같은 순간 엔진 상태로 다시 계산 (순수 조회: 위치·방향·지형만 읽음). 공식 피해(스킬 범위·창벽·격투가 반격)는 웹처럼 표시 안 함
func _tactic_of(data: Dictionary) -> Variant:
	if Js.truthy(data.get("isSplash")) or Js.truthy(data.get("isAoE")) or Js.truthy(data.get("isSpearwall")):
		return null
	var a: Variant = eng.unit_by_id(data["attacker"]["id"])
	var t: Variant = eng.unit_by_id(data["target"]["id"])
	if a == null or t == null:
		return null
	if (Js.truthy(data.get("isCounter")) or Js.truthy(data.get("counter"))) and a["cls"] == "brawler" and Js.num((a.get("skillLv", {}) as Dictionary).get("brawler_counter")) >= 1:
		return null
	var tb: Dictionary = eng.gu.tactic_bonus(a, t)
	if (tb["tags"] as Array).is_empty():
		return null
	return {"tags": (tb["tags"] as Array).duplicate(), "pct": Js.round_js((float(tb["mul"]) - 1.0) * 100.0)}


# ═══════════ 재생 ═══════════

func _process(delta: float) -> void:
	if eng == null:
		return
	var instant := speed <= 0.0
	var dt := delta * (1.0 if instant else speed)
	_clock += dt
	if _loading_on:
		_loading_tick(delta)
	# 예약된 연출 (타격 시점 등)
	var i := 0
	while i < _sched.size():
		var s: Array = _sched[i]
		s[0] -= dt
		if s[0] <= 0.0 or instant:
			_sched.remove_at(i)
			(s[1] as Callable).call()
		else:
			i += 1
	if instant:
		while _qi < _evq.size() and _hold == 0:
			_play(_evq[_qi])
			_qi += 1
		_wait = 0.0
	elif _hold == 0:
		_wait -= dt
		while _wait <= 0.0 and _qi < _evq.size() and _hold == 0:
			_wait += _play(_evq[_qi])
			_qi += 1
	if _qi >= _evq.size() and _qi > 0:
		_evq.clear()
		_qi = 0
	if mode == "busy" and _hold == 0 and _qi >= _evq.size() and _wait <= 0.0 and (_sched.is_empty() or instant):
		_on_drained()
	if not _auto_cmds.is_empty():
		_autoplay_tick(delta)
	if _badges_dirty:
		_badges_dirty = false
		_refresh_badges()
	if _hud_dirty:
		_hud_dirty = false
		_refresh_hud()
	_update_shake(delta)
	_update_hover(delta)
	if ui != null and cam != null:
		var vs := get_viewport().get_visible_rect().size / cam.zoom
		ui.minimap.set_view(Rect2(cam.get_screen_center_position() - vs / 2.0, vs))


func _schedule(secs: float, fn: Callable) -> void:
	if speed <= 0.0 or secs <= 0.0:
		fn.call()
	else:
		_sched.append([secs, fn])


## 대기열 항목 하나 재생 → 다음 항목까지 기다릴 초 (속도 1 기준)
func _play(item: Array) -> float:
	var kind: String = item[0]
	var name: String = item[1]
	var d: Dictionary = item[2]
	var sn: Variant = item[3]
	if kind == "fx":
		return _play_fx(name, d, sn)
	_play_sound(name, d, sn)
	match name:
		"turn_start":
			_apply_snap(sn)
			var u: Dictionary = d["unit"]
			_set_cur(int(u["id"]))
			view_phase = str(d.get("phase", "player"))
			_hud_dirty = true
			_refresh_loops()
			ui.turn_flash(view_phase)
			# 스토리 (웹: 아군 turn_start 와 적 행동 직전에 쌓인 대사 재생)
			if story.enabled and not _over:
				_story_play(story.flush(_story_view()))
			return 0.27 if view_phase == "enemy" else 0.1
		"turn_end", "round_end", "unit_added":
			_apply_snap(sn)
			return 0.0
		"wave_spawn":
			_apply_snap(sn)
			if story.enabled:
				if typeof(sn) == TYPE_DICTIONARY and int(sn["act"]) > 0:
					story.enqueue("wave")
				story.scan(_story_view())
			return 0.6
		"wave_announce":
			ui.show_banner(_t("messages.wave_info", {"count": d.get("remaining", 0)}), 3.0, true)
			return 0.3
		"wave_announce_end":
			ui.hide_banner()
			return 0.0
		"unit_moved":
			return _ev_moved(d)
		"unit_attacked":
			return _ev_attacked(d)
		"unit_killed":
			return _ev_killed(d)
		"unit_healed":
			var t: Dictionary = d["target"]
			_stats(t)
			fx.float_text(int(t["x"]), int(t["y"]), "+" + _num(d.get("amount", 0)), "heal")
			fx.heal_fx(_body(t))
			return 0.3
		"buff_tick_damage", "trap_triggered":
			var u2: Dictionary = d["unit"]
			_stats(u2)
			_shake(u2)
			fx.float_text(int(u2["x"]), int(u2["y"]), "-" + _num(d.get("damage", 0)), "damage")
			return 0.25
		"buff_tick_heal":
			var u3: Dictionary = d["unit"]
			_stats(u3)
			fx.float_text(int(u3["x"]), int(u3["y"]), "+" + _num(d.get("heal", 0)), "heal")
			return 0.2
		"buff_applied", "buff_removed":
			if d.has("unit"):
				_stats(d["unit"])
			if name == "buff_applied" and d.has("unit"):
				fx.buff_fx(_body(d["unit"]))
				var gv: UnitView = units.get(int(d["unit"]["id"]))
				if gv != null:
					gv.glow()
			return 0.0
		"skill_used":
			var cu: Variant = d.get("unit", d.get("caster"))
			var sk: Variant = d.get("skill")
			var sid := str(sk.get("id", "")) if typeof(sk) == TYPE_DICTIONARY else str(sk)
			if typeof(cu) == TYPE_DICTIONARY:
				_stats(cu)
				fx.float_text(int(cu["x"]), int(cu["y"]), _t("skills." + sid), "tactic")
				if sid == "mage_fireball":
					fx.float_text(int(cu["x"]), int(cu["y"]), _t("messages.mage_fireball"), "heal")
			if sid == "brawler_disarm" and typeof(d.get("target")) == TYPE_DICTIONARY:
				fx.float_text(int(d["target"]["x"]), int(d["target"]["y"]), _t("messages.brawler_disarm"), "damage")
			return 0.35
		"siege_used":
			var su: Dictionary = d["unit"]
			_stats(su)
			var tp := str(d.get("type"))
			fx.float_text(int(su["x"]), int(su["y"]), "💣" if tp == "bomb" else ("🛡️" if tp == "shield" else "⚡"), "heal")
			if tp == "bomb" and typeof(d.get("target")) == TYPE_DICTIONARY:
				var tg: Dictionary = d["target"]
				fx.siege_fx("siege_bomb", iso.top_center(int(tg["x"]), int(tg["y"])))
				screen_shake(false)
			return 0.35
		"gate_attacked":
			fx.float_text(int(d["x"]), int(d["y"]), _t("messages.gate_hit"), "damage")
			fx.burst(iso.top_center(int(d["x"]), int(d["y"])), {"count": 12, "colors": ["#aa8844", "#ffcc66", "#ffffff"], "shape": "spark", "speed": 2, "spread": 12, "decay": 0.025, "size": 3})
			return 0.3
		"gate_destroyed":
			fx.float_text(int(d["x"]), int(d["y"]), _t("messages.gate_destroyed"), "damage")
			screen_shake(true)
			return 0.3
		"breach":
			var bu: Dictionary = d["unit"]
			fx.float_text(int(bu["x"]), int(bu["y"]), "%s %s/%s" % [_t("messages.breach"), _num(d.get("count", 0)), _num(d.get("limit", 0))], "damage")
			view_breached = int(Js.num(d.get("count", view_breached)))
			_hud_dirty = true
			return 0.3
		"evasion", "fury_triggered", "retreat", "root_blocked", "shield_active":
			var eu: Dictionary = d["unit"]
			var key: String = {"evasion": "messages.evasion", "fury_triggered": "messages.fury_buff", "retreat": "messages.retreat", "root_blocked": "messages.rooted", "shield_active": "🛡️"}[name]
			fx.float_text(int(eu["x"]), int(eu["y"]), _t(key) if key.contains(".") else key, "debuff" if name == "root_blocked" else ("damage" if name == "retreat" else "heal"))
			return 0.2
		"soulbond_restore":
			var sm: Dictionary = d["summoner"]
			_stats(sm)
			fx.float_text(int(sm["x"]), int(sm["y"]), "+%s MP" % _num(d.get("amount", 0)), "heal")
			return 0.1
		"camera_focus":
			if typeof(d.get("unit")) == TYPE_DICTIONARY:
				_focus(iso.foot(int(d["unit"]["x"]), int(d["unit"]["y"])))
			return 0.0
	return 0.0


func _play_fx(kind: String, d: Dictionary, sn: Variant) -> float:
	match kind:
		"sfx":
			# (5단계) 규칙 코드 안의 웹 Audio 호출 자리 (스킬의 G.sfxAtk/sfxKill/sfxDeath/sfxHeal/sfxMove/sfxUIClick/sfxExplosion)
			if str(d["n"]) == "atk":
				_sfx_atk(str(d.get("cls", "")))
			else:
				_sfx(str(d["n"]))
			return 0.0
		"face":
			var uv: UnitView = units.get(int(d["id"]))
			if uv != null:
				uv.set_face(int(d["dx"]), int(d["dy"]))
			return 0.0
		"move":
			var uv2: UnitView = units.get(int(d["id"]))
			if uv2 != null and (int(uv2.d["x"]) != int(d["x"]) or int(uv2.d["y"]) != int(d["y"])):
				uv2.move_to(int(d["x"]), int(d["y"]))
				_schedule(0.34, _after_move)
				# 바로 뒤가 같은 유닛의 unit_moved 면 그쪽이 기다림
				if _qi + 1 < _evq.size() and _evq[_qi + 1][1] == "unit_moved" and int(_evq[_qi + 1][2]["unit"]["id"]) == int(d["id"]):
					return 0.0
				return 0.25
			return 0.0
		"attack":
			var av: UnitView = units.get(int(d["a"]))
			var tv: UnitView = units.get(int(d["t"]))
			if av != null and not av.dying:
				_motion[int(d["a"])] = _clock + _start_attack(av, tv)
			return 0.0
		"float":
			# 선택 안내(messages.select_*)는 아래 안내 줄로 보여 주므로 떠오르는 글자로는 안 띄움
			var tx := str(d["text"])
			if not tx.begins_with("messages.select_"):
				var crit := tx == "messages.critical_hit"
				fx.float_text(int(d["x"]), int(d["y"]), _tr_float(tx), "crit" if crit else "info")
				if crit:
					screen_shake(true)
					ui.big_flash(Color(250 / 255.0, 204 / 255.0, 21 / 255.0, 0.22), 0.4)
			return 0.0
		"chest_open":
			_apply_snap(sn)
			_sfx("heal")   # 웹 VFX unit_moved: 상자 열림 글자와 함께 Audio.sfxHeal
			fx.float_text(int(d["x"]), int(d["y"]), "🎁 " + _t("chest." + str(d.get("kind", ""))), "heal")
			fx.burst(iso.foot(int(d["x"]), int(d["y"])) + Vector2(0, -24), {"count": 14, "colors": ["#fde68a", "#facc15", "#ffffff"], "shape": "star", "speed": 2.5, "spread": 10, "decay": 0.03, "size": 3})
			return 0.25
		"redraw_units", "redraw_terrain":
			_apply_snap(sn)
			return 0.0
	return 0.0


## 공격 동작 시작 → 타격 시점까지 초 (웹 vfxAtk: 시트가 있으면 시트, 없으면 키프레임·무기 궤적. 움직임 줄이기면 동작 없이 타이밍만)
func _start_attack(av: UnitView, tv: UnitView) -> float:
	var cls := str(av.d["cls"])
	var m: Dictionary = _atk_motion(cls)
	if av.has_sheet("attack"):
		if reduce_motion:
			return float(m.get("dur", 400)) * float(m.get("hit", 0.5)) / 1000.0
		return av.play_once("attack")
	var dir := Vector2.RIGHT
	if tv != null:
		dir = (tv.position - av.position).normalized() if tv.position != av.position else Vector2.RIGHT
	var hit := av.play_motion(m, dir)
	if tv != null and not PixelFx.handles(cls) and not reduce_motion:
		fx.atk_trail(m, av.position + Vector2(0, -Iso.UCY + 8.0), tv.position + Vector2(0, -Iso.UCY + 8.0), hit)
	return hit


func _atk_motion(cls: String) -> Dictionary:
	var M: Dictionary = D.get("ATK_MOTIONS", {})
	return M.get(cls, M.get("_default", {"dur": 360, "hit": 0.5}))


func _ev_moved(d: Dictionary) -> float:
	var u: Dictionary = d["unit"]
	var uv: UnitView = units.get(int(u["id"]))
	if uv == null:
		return 0.0
	var to: Dictionary = d["to"]
	var from: Dictionary = d.get("from", {"x": uv.d["x"], "y": uv.d["y"]})
	var vault := _is_vault(uv, int(from["x"]), int(from["y"]), int(to["x"]), int(to["y"]))
	if int(uv.d["x"]) != int(to["x"]) or int(uv.d["y"]) != int(to["y"]):
		uv.move_to(int(to["x"]), int(to["y"]))
		_schedule(0.34, _after_move)
	uv.apply_stats(u)
	if vault:
		uv.hop()
		fx.float_text(int(to["x"]), int(to["y"]), _t("battle.vault"), "tactic")
	_hud_dirty = true
	return 0.36


## 도움닫기 판정 (웹 VFX._isVault, 연출용): 궁수·도적이 일직선 2~3칸을 가는데 바로 앞 칸에 같은 편이 있음
func _is_vault(uv: UnitView, fx0: int, fy0: int, tx: int, ty: int) -> bool:
	if not (D.get("VAULT_CLASSES", []) as Array).has(uv.d.get("cls")):
		return false
	var dx := signi(tx - fx0)
	var dy := signi(ty - fy0)
	var dist := absi(tx - fx0) + absi(ty - fy0)
	if (dx != 0 and dy != 0) or dist < 2 or dist > int(Js.num(D.get("VAULT_DIST", 2))) + 1:
		return false
	for o: UnitView in units.values():
		if o != uv and not o.has_meta("doomed") and int(o.d["x"]) == fx0 + dx and int(o.d["y"]) == fy0 + dy:
			return o.d.get("team") == uv.d.get("team")
	return false


func _after_move() -> void:
	_refresh_fog_view()
	_refresh_fade()
	_refresh_loops()
	_badges_dirty = true
	_hud_dirty = true


## 공격: 공격자 동작 → 타격 프레임에 대상 흔들림·피격 동작·피해 숫자·직업별 효과 (웹 VFX unit_attacked 구독)
##  원거리(궁수·마법사·사제·소환사·주술사·지휘관)는 타격 프레임에 픽셀 투사체를 쏘고 비행 뒤 명중
func _ev_attacked(d: Dictionary) -> float:
	var a: Dictionary = d["attacker"]
	var t: Dictionary = d["target"]
	var av: UnitView = units.get(int(a["id"]))
	var tid := int(t["id"])
	var hit_in := 0.1
	var cls := str(a.get("cls", ""))
	var splash := Js.truthy(d.get("isSplash"))
	if av != null:
		av.apply_stats(a)
	if not splash:
		var aid := int(a["id"])
		if _motion.has(aid) and float(_motion[aid]) >= _clock - 0.05:
			hit_in = maxf(0.0, float(_motion[aid]) - _clock)
			_motion.erase(aid)
		elif av != null and not av.dying:
			hit_in = _start_attack(av, units.get(tid))
	var ranged := PixelFx.handles(cls) and not splash
	var fl := PixelFx.flight(cls) if ranged else 0.0
	var ap := _body(a)
	var tp := _body(t)
	if ranged and speed > 0.0:
		var dir := (tp - ap).normalized() if tp != ap else Vector2.RIGHT
		var up := PixelFx.up_of(cls)
		_schedule(hit_in, func() -> void: pfx.shoot(cls, ap.x + dir.x * 18.0, ap.y + dir.y * 18.0 - up, tp.x - dir.x * 8.0, tp.y - dir.y * 8.0, fl * 1000.0))
	var land := hit_in + fl
	_hit_at[tid] = _clock + land
	if not splash and not Js.truthy(d.get("_sfx_done")):
		_peek_same_hit(d, land)
	var dmg := _num(d.get("damage", 0))
	var tac: Variant = d.get("_tactic")
	_schedule(land, func() -> void:
		var tv: UnitView = units.get(tid)
		if tv != null:
			tv.apply_stats(t)
			tv.shake()
			if float(t["hp"]) > 0.0 and not reduce_motion:
				tv.play_once("hit")
		fx.float_text(int(t["x"]), int(t["y"]), "-" + dmg, "damage")
		if typeof(tac) == TYPE_DICTIONARY:
			var tags: Array = []
			for tg: String in tac["tags"]:
				tags.append(_t("battle.tactic_" + tg))
			fx.float_text(int(t["x"]), int(t["y"]), "%s +%s%%" % ["·".join(tags), _num(tac["pct"])], "tactic")
		if ranged:
			if speed > 0.0:
				var dd := (tp - ap).normalized() if tp != ap else Vector2.RIGHT
				pfx.impact(cls, tp.x - dd.x * 8.0, tp.y - dd.y * 8.0)
		elif not splash:
			fx.hit_fx(cls, ap, tp)
		else:
			fx.burst(tp, {"count": 8, "colors": ["#ffffff", "#ffcc44", "#ff8800"], "shape": "spark", "speed": 3, "spread": 8, "decay": 0.035, "size": 2.5})
		_hud_dirty = true
		_badges_dirty = true
		if story.enabled:
			story.scan(_story_view()))
	if Js.truthy(d.get("counter")) or Js.truthy(d.get("isCounter")):
		fx.float_text(int(a["x"]), int(a["y"]), _t("messages.brawler_counter"), "heal")
	if Js.truthy(d.get("isSupport")):
		fx.float_text(int(a["x"]), int(a["y"]), _t("battle.support_hit"), "tactic")
	return land + 0.3


func _ev_killed(d: Dictionary) -> float:
	var t: Dictionary = d["target"]
	var tid := int(t["id"])
	var tv: UnitView = units.get(tid)
	if tv == null:
		return 0.0
	tv.set_meta("doomed", true)
	var at := maxf(0.0, float(_hit_at.get(tid, 0.0)) - _clock) + 0.05
	var boss := bool(tv.d.get("isBoss", false))
	_schedule(at, func() -> void:
		if is_instance_valid(tv):
			fx.death_fx(tv.position + Vector2(0, -24), tv.d.get("team") == "ally")
			tv.die()
		screen_shake(boss)
		if boss:
			ui.big_flash(Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.25), 0.5)
		units.erase(tid)
		_refresh_fog_view()
		_refresh_loops()
		_hud_dirty = true
		_badges_dirty = true
		if story.enabled:
			story.scan(_story_view()))
	return 0.35


## 전장 사본을 화면에 반영 (새 유닛 등장·사라진 유닛·지형·상자·결계)
func _apply_snap(sn: Variant) -> void:
	if typeof(sn) != TYPE_DICTIONARY:
		return
	var seen: Dictionary = {}
	for v: Dictionary in sn["units"]:
		var id := int(v["id"])
		seen[id] = true
		var uv: UnitView = units.get(id)
		if uv == null:
			_add_unit(v, true)
			continue
		if uv.has_meta("doomed"):
			continue
		uv.apply_stats(v)
		_fix_pos(uv, int(v["x"]), int(v["y"]))
	for id2: int in units.keys():
		if not seen.has(id2):
			var gone: UnitView = units[id2]
			if not gone.has_meta("doomed"):
				gone.set_meta("doomed", true)
				gone.die()
				units.erase(id2)
	var ter: Array = sn["ter"]
	if ter != view_ter:
		view_ter = ter
		iso.ter = view_ter
		map.rebuild()
		map.set_safe(view_safe)
		for uv2: UnitView in units.values():
			uv2.refresh_camera()
		ui.minimap.rebuild(_minimap_units())
	if sn["chests"] != view_chests:
		view_chests = sn["chests"]
		map.set_chests(view_chests)
	if sn["safe"] != view_safe:
		view_safe = sn["safe"]
		map.set_safe(view_safe)
	view_turn = int(sn["turn"])
	view_eq = int(sn["eq"])
	view_espwn = int(sn.get("espwn", view_espwn))
	view_actcount = int(sn.get("act", view_actcount))
	view_breached = int(sn.get("breached", view_breached))
	_hud_dirty = true
	_badges_dirty = true
	_refresh_fog_view()
	_refresh_fade()


func _stats(v: Variant) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		return
	var uv: UnitView = units.get(int(v["id"]))
	if uv != null and not uv.has_meta("doomed"):
		uv.apply_stats(v)
		_hud_dirty = true
		_badges_dirty = true


func _shake(v: Dictionary) -> void:
	var uv: UnitView = units.get(int(v["id"]))
	if uv != null:
		uv.shake()


func _body(v: Dictionary) -> Vector2:
	return iso.foot(int(v["x"]), int(v["y"])) + Vector2(0, -24)


func _set_cur(id: int) -> void:
	cur_id = id
	for uv: UnitView in units.values():
		uv.cur_turn = int(uv.id) == id
	_hud_dirty = true


# ── 화면 흔들림 (웹 #iso-world.screen-shake .3s / heavy .45s) ──

func screen_shake(heavy: bool = false) -> void:
	if speed <= 0.0 or reduce_motion:
		return
	_shake_t = 0.0
	_shake_dur = 0.45 if heavy else 0.3
	_shake_amp = 8.0 if heavy else 4.0


func _update_shake(delta: float) -> void:
	if cam == null:
		return
	if _shake_t < _shake_dur:
		_shake_t += delta * maxf(speed, 1.0)
		var k := clampf(_shake_t / _shake_dur, 0.0, 1.0)
		var a := _shake_amp * (1.0 - k)
		cam.offset = Vector2(sin(k * 31.0) * a, cos(k * 23.0) * a * 0.75)
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO


# ── 화면 상태 계산 (재생 중에는 화면 사본으로) ──

## 시야 (웹 Grid.calcFOW: 클랜원마다 이동력+1 칸) — 엔진 q.fog_visible 과 같은 식을 화면 사본으로
func _refresh_fog_view() -> void:
	var vis: Dictionary = {}
	var cols := iso.cols
	var rows := iso.rows
	for uv: UnitView in units.values():
		if uv.d.get("team") != "ally" or uv.has_meta("doomed") or float(uv.d["hp"]) <= 0.0:
			continue
		var vision := int(Js.num(uv.d.get("move"))) + 1
		var ux := int(uv.d["x"])
		var uy := int(uv.d["y"])
		for r in range(maxi(0, uy - vision), mini(rows, uy + vision + 1)):
			for c in range(maxi(0, ux - vision), mini(cols, ux + vision + 1)):
				if absi(c - ux) + absi(r - uy) <= vision:
					vis["%d,%d" % [c, r]] = true
	map.set_fog(vis)
	for uv2: UnitView in units.values():
		var key := "%d,%d" % [int(uv2.d["x"]), int(uv2.d["y"])]
		var hidden: bool = uv2.d.get("team") == "enemy" and (not vis.has(key) or bool(uv2.d.get("stealthed", false)))
		uv2.visible = not hidden
	_hud_dirty = true


func _refresh_fade() -> void:
	var list: Array = []
	for uv: UnitView in units.values():
		if uv.visible:
			list.append({"p": iso.top_center(int(uv.d["x"]), int(uv.d["y"])), "d": iso.depth(int(uv.d["x"]), int(uv.d["y"]), 2)})
	map.update_fade(list)


## 반복 동작: 자기 차례거나 상대가 3칸 안이면 전투대기, 아니면 대기 (웹 Renderer.loopKind)
func _refresh_loops() -> void:
	for uv: UnitView in units.values():
		if uv.moving:
			continue
		var k := "idle"
		if uv.id == cur_id:
			k = "combat"
		else:
			for o: UnitView in units.values():
				if o.d.get("team") != uv.d.get("team") and not o.has_meta("doomed") and not bool(o.d.get("stealthed", false)) \
						and absi(int(o.d["x"]) - int(uv.d["x"])) + absi(int(o.d["y"]) - int(uv.d["y"])) <= 3:
					k = "combat"
					break
		uv.set_loop(k)


## 머리 위 배지 (웹 rUnits .u-badges) — 화면 사본으로 (엄호·용암 옆은 이웃 유닛·지형으로 계산)
func _refresh_badges() -> void:
	var list: Array = []
	for uv: UnitView in units.values():
		if not uv.has_meta("doomed"):
			list.append(uv.d)
	var lava := map.lava
	for uv2: UnitView in units.values():
		if uv2.has_meta("doomed"):
			continue
		uv2.d["badges"] = info.badges(uv2.d, view_ter, list, lava)
		uv2._update_top()


# ═══════════ HUD 모델 ═══════════

func _visible_units() -> Array:
	var out: Array = []
	for uv: UnitView in units.values():
		if uv.has_meta("doomed") or float(uv.d["hp"]) <= 0.0 or not uv.visible:
			continue
		out.append(uv)
	return out


func _minimap_units() -> Array:
	var out: Array = []
	for uv: UnitView in _visible_units():
		out.append({"x": uv.d["x"], "y": uv.d["y"], "team": uv.d["team"]})
	return out


func _refresh_hud() -> void:
	if ui == null:
		return
	var S: Dictionary = eng.S
	var st: Variant = S["cStage"]
	var title: Array = info.stage_title(st)
	var tot := int(Js.num(st.get("tot"))) if st != null else 0
	var enemies := 0
	for uv: UnitView in units.values():
		if uv.d.get("team") == "enemy" and not uv.has_meta("doomed") and float(uv.d["hp"]) > 0.0:
			enemies += 1
	var m := {"phase": view_phase, "phase_text": _t("battle.player_phase" if view_phase == "player" else "battle.enemy_phase"),
		"no": title[0], "name": title[1], "turn_text": _t("battle.turn_n", {"n": view_turn}),
		"wave": {"done": view_espwn >= tot, "ratio": float(view_espwn) / float(tot) if tot > 0 else 0.0, "text": "%d/%d" % [view_espwn, tot],
			"tip": "%s %d/%d" % [_t("battle.summon"), view_espwn, tot]},
		"foe": {"text": _t("battle.enemy_left", {"n": enemies}), "tip": _t("battle.remaining")}, "breach": null, "hazard": null, "synergies": [], "practice": ""}
	var blim := int(ceilf(float(tot) / 4.0)) if st != null else 0
	if blim > 0:
		m["breach"] = {"text": "%s %d/%d" % [_t("battle.breach"), view_breached, blim], "tip": _t("battle.breach_tip", {"n": blim}),
			"hit": view_breached > 0, "danger": view_breached >= blim - 1 and view_breached > 0}
	var hz: Variant = S.get("_hazard")
	if typeof(hz) == TYPE_DICTIONARY:
		m["hazard"] = {"icon": str(hz["icon"]), "name": info.hazard_name(hz), "tip": info.hazard_name(hz) + " — " + icons.strip(info.hazard_describe(hz, st))}
	for sy: Dictionary in S.get("_synergies", []):
		(m["synergies"] as Array).append({"icon": str(sy.get("icon", "")), "name": info.synergy_name(sy), "tip": info.synergy_name(sy) + " — " + info.synergy_describe(sy)})
	if Js.truthy(S.get("practiceMode")):
		m["practice"] = _t("stage.practice")
	ui.update_top(m)
	# 행동 순서 (웹 rTurnOrder: 숨은 적 제외, 다음 행동까지 틱 = (5 - 행동력) / 회복 속도)
	var rows: Array = []
	for uv2: UnitView in _visible_units():
		var ap := Js.num(uv2.d.get("ap"))
		var rec := Js.num(uv2.d.get("actionRec"))
		if rec <= 0.0:
			rec = 1.0
		rows.append({"uv": uv2, "ticks": 0.0 if ap >= 4.999 else (5.0 - ap) / rec, "ap": ap, "rec": rec})
	rows = Js.stable_sort(rows, func(p: Dictionary, q: Dictionary) -> float: return float(p["ticks"]) - float(q["ticks"]))
	var order_rows: Array = []
	var stage_v: Variant = st
	for r: Dictionary in rows:
		var u: UnitView = r["uv"]
		var cur := u.id == cur_id
		var ready := float(r["ap"]) >= 4.999
		var nm := info.unit_name(u.d, stage_v)
		order_rows.append({"id": u.id, "team": u.d["team"], "boss": bool(u.d.get("isBoss", false)), "cur": cur, "name": nm,
			"tip": "%s · HP %s/%s · AP %.1f/5 (%.1fx)" % [nm, _num(u.d["hp"]), _num(u.d["mhp"]), float(r["ap"]), float(r["rec"])],
			"hp_ratio": maxf(0.0, float(u.d["hp"]) / maxf(1.0, float(u.d["mhp"]))), "ap_ratio": minf(1.0, float(r["ap"]) / 5.0),
			"eta": _t("battle.acting") if cur else ("✓" if ready else "%.1f" % float(r["ticks"])), "ready": ready,
			"tex": icons.char_tex(str(u.d["cls"]), str(u.d.get("gender", "m")), sdb), "summon": str(u.d["cls"]).begins_with("summon_")})
	ui.order.update(order_rows)
	# 클랜원 카드 (웹 rInfoPanel)
	var cards: Array = []
	var RL: Dictionary = D.get("RES_LABEL", {})
	for uv3: UnitView in units.values():
		var dd: Dictionary = uv3.d
		if dd.get("team") != "ally" or uv3.has_meta("doomed") or float(dd["hp"]) <= 0.0:
			continue
		var rt := str(dd.get("resType", ""))
		var bl: Array = info.buffs(dd, view_ter, _units_d())
		for b: Dictionary in bl:
			b["turns_text"] = _t("gd.tip.turns", {"n": b["turns"]})
		cards.append({"id": uv3.id, "name": info.unit_name(dd, stage_v), "cls": "Lv.%s %s" % [_num(dd.get("lv", 1)), info.class_name_of(str(dd["cls"]))],
			"hp": dd["hp"], "mhp": dd["mhp"], "hp_text": _num(dd["hp"]), "mhp_text": _num(dd["mhp"]),
			"res": Js.num(dd.get("res")), "maxres": Js.num(dd.get("maxRes")), "res_text": _num(Js.num(dd.get("res"))), "maxres_text": _num(Js.num(dd.get("maxRes"))),
			"res_label": str(RL.get(rt, "")), "res_color": Kit.RES_COLOR.get(rt, Color.WHITE),
			"atk": _num(dd.get("atk", 0)), "def": _num(dd.get("def", 0)), "rng": _num(dd.get("range", 0)), "buffs": bl,
			"sel": uv3.id == cur_id and view_phase == "player", "cur": uv3.id == cur_id, "done": bool(dd.get("ha", false)),
			"tex": icons.char_tex(str(dd["cls"]), str(dd.get("gender", "m")), sdb), "summon": str(dd["cls"]).begins_with("summon_")})
	ui.cards.update(cards)
	ui.minimap.set_units(_minimap_units())


func _units_d() -> Array:
	var out: Array = []
	for uv: UnitView in units.values():
		if not uv.has_meta("doomed"):
			out.append(uv.d)
	return out


# ═══════════ 툴팁 · 적 팝업 ═══════════

## 유닛 정보 모델 (툴팁·팝업 공통). 입력 대기 중이면 엔진 유닛(정확), 재생 중이면 화면 사본
func _unit_model(uv: UnitView, full: bool) -> Dictionary:
	var dd: Dictionary = uv.d
	var team := str(dd.get("team"))
	var boss := bool(dd.get("isBoss", false))
	var st: Variant = eng.S["cStage"]
	var m := {"title_icon": icons.emoji("💀") if boss else null, "title": info.unit_name(dd, st), "title_color": Color("fbbf24") if boss else (Color("f87171") if team == "enemy" else Color("93c5fd")),
		"sub": "Lv.%s %s" % [_num(dd.get("lv", 1)), info.class_name_of(str(dd["cls"]))],
		"portrait": {"tex": icons.char_tex(str(dd["cls"]), str(dd.get("gender", "m")), sdb), "summon": str(dd["cls"]).begins_with("summon_"),
			"ring": Color("ef4444") if team == "enemy" else Color("3b82f6")},
		"border": Color(239 / 255.0, 68 / 255.0, 68 / 255.0, 0.4) if team == "enemy" else Color(59 / 255.0, 130 / 255.0, 246 / 255.0, 0.4)}
	var hp := float(dd["hp"])
	var mhp := maxf(1.0, float(dd["mhp"]))
	var low := hp / mhp <= 0.25
	var bars: Array = [{"label": "HP", "ratio": hp / mhp, "text": "%s/%s" % [_num(dd["hp"]), _num(dd["mhp"])],
		"c0": Color("ef4444") if low else Color("22c55e"), "c1": Color("ef4444") if low else Color("22c55e")}]
	var rt := str(dd.get("resType", ""))
	var RL: Dictionary = D.get("RES_LABEL", {})
	if RL.has(rt) and Js.num(dd.get("maxRes")) > 0.0:
		var rc: Color = Kit.RES_COLOR.get(rt, Color.WHITE)
		bars.append({"label": RL[rt], "label_color": rc, "ratio": Js.num(dd.get("res")) / maxf(1.0, Js.num(dd.get("maxRes"))),
			"text": "%s/%s" % [_num(Js.num(dd.get("res"))), _num(Js.num(dd.get("maxRes")))], "c0": rc, "c1": rc})
	m["bars"] = bars
	m["stats"] = "ATK %s   DEF %s   RNG %s   MOV %s" % [_num(dd.get("atk", 0)), _num(dd.get("def", 0)), _num(dd.get("range", 0)), _num(dd.get("move", 0))]
	var bl: Array = info.buffs(dd, view_ter, _units_d())
	for b: Dictionary in bl:
		b["turns_text"] = _t("gd.tip.turns", {"n": b["turns"]})
	m["buffs"] = bl
	var tile := info._tile(view_ter, int(dd["x"]), int(dd["y"]))
	m["lines"] = [_t("gd.tip.on_terrain", {"t": _t("terrain." + tile)})] if tile != "" else []
	if team == "enemy" and dd.get("intent") != null:
		var tgt: UnitView = units.get(int(dd["intent"]))
		if tgt != null:
			m["intent"] = _t("gd.tip.intent", {"name": info.unit_name(tgt.d, st)})
	if full:
		var eu: Variant = eng.unit_by_id(uv.id)
		var skills: Array = []
		if eu != null:
			for sk: Dictionary in eng.get_unit_skills(eu):
				var sid := str(sk.get("id", ""))
				var sub := _t("gd.tip.passive") if Js.truthy(sk.get("passive")) else ("%s %s" % [_num(sk.get("cost", 0)), _t("resources." + str(sk.get("costType", dd.get("resType", ""))))] if Js.num(sk.get("cost")) > 0.0 else "")
				skills.append({"tex": icons.skill(sid, str(sk.get("icon", ""))), "name": _t("skills." + sid), "sub": sub})
		m["skills"] = skills
		if team == "enemy":
			var prof: Variant = (D.get("AI_PROFILES", {}) as Dictionary).get(dd["cls"])
			if typeof(prof) == TYPE_DICTIONARY:
				m["ai"] = _t("gd.ai.label", {"style": _t("gd.ai.style_" + str(prof["style"])), "target": _t("gd.ai.target_" + str(prof["targetPriority"]))})
	return m


## 칸 정보 모델 (지형 효과·상자·결계·위협·안개)
func _cell_model(c: int, r: int) -> Dictionary:
	var tile := iso.tile_type(c, r)
	var TI: Dictionary = D["TI"]
	var m := {"title": _t("terrain." + tile), "title_color": Color("e5e7eb"), "lines": info.terrain_lines(tile), "border": Color(1, 1, 1, 0.18)}
	if TI.has(tile) and TI[tile].get("buff") != null:
		m["icon"] = icons.emoji(str(TI[tile]["buff"]["icon"]))
	var key := "%d,%d" % [c, r]
	var lines: Array = m["lines"]
	if view_chests.has([c, r]):
		lines.append(_t("chest.tip"))
	if view_safe.has(key):
		lines.append(_t("gd.tip.safe_zone"))
	if map.lava and tile == "water":
		lines.append(_t("gd.tip.lava"))
	if show_threat and map.threat.has(key):
		lines.append(_t("gd.tip.threat"))
	if map.fog_on and not map.fog_vis.has(key):
		lines.append(_t("gd.tip.fog"))
	m["sub"] = "(%d, %d)" % [c, r]
	return m


## 마우스 아래 유닛 (몸통 상자) → 없으면 칸
func _hover_target(world_p: Vector2) -> String:
	var best: UnitView = null
	for uv: UnitView in _visible_units():
		var p := uv.position
		if absf(world_p.x - p.x) <= 18.0 and world_p.y <= p.y + 6.0 and world_p.y >= p.y - 56.0:
			if best == null or uv.z_index > best.z_index:
				best = uv
	if best != null:
		return "u:%d" % best.id
	var c := iso.iso_hit(world_p)
	if c.x >= 0:
		return "c:%d,%d" % [c.x, c.y]
	return ""


func _update_hover(delta: float) -> void:
	if ui == null:
		return
	if _hover_key == "" or _dragging or _hold > 0 or _over or ui.settings.is_open() or ui.over_hud(_hover_pos):
		ui.info.hide_tip()
		return
	_hover_t += delta
	if _hover_t < 0.25:
		return
	var m: Dictionary = {}
	if _hover_key.begins_with("u:"):
		var uv: UnitView = units.get(_hover_key.substr(2).to_int())
		if uv == null or not uv.visible:
			ui.info.hide_tip()
			return
		if ui.info.popup.visible and ui.info.popup_unit == uv.id:
			ui.info.hide_tip()
			return
		m = _unit_model(uv, false)
	else:
		var xy := _hover_key.substr(2).split(",")
		m = _cell_model(int(xy[0]), int(xy[1]))
	ui.info.show_tip(m, _hover_pos, ui.menu.get_global_rect() if ui.menu.visible else Rect2())


## 적 정보 팝업 (웹 showEnemyPopup) — 다음 누르기에 닫힘
func show_enemy_popup(id: int) -> void:
	var uv: UnitView = units.get(id)
	if uv == null:
		return
	ui.info.hide_tip()
	ui.info.show_popup(id, _unit_model(uv, true), _unit_screen(id) + Vector2(0, -28))


# ═══════════ 입력 대기 ═══════════

## 재생이 엔진을 따라잡음 → 입력 대기면 메뉴, 끝났으면 결과
func _on_drained() -> void:
	if _over:
		return
	if _surrender_pending and _eng_status == "input" and eng.awaiting_unit() != null:
		_surrender_pending = false
		_do_surrender()
		return
	if _leave_pending and _eng_status == "input" and eng.awaiting_unit() != null:
		_leave_pending = false
		_enter_menu()
		leave_battle()
		return
	_surrender_pending = false
	if _eng_status == "input" and eng.awaiting_unit() != null:
		_enter_menu()
	else:
		_finish()


## 엔진의 지금 상태로 화면을 한 번 맞춤 (재생 중 놓친 값이 있어도 입력 전에는 정확히)
func _sync_from_engine() -> void:
	_apply_snap(_snap_engine())
	for uv: UnitView in units.values():
		var u: Variant = eng.unit_by_id(uv.id)
		if u != null:
			_fix_pos(uv, int(u["x"]), int(u["y"]))
	map.set_fog(eng.q.fog_visible())


## 화면 유닛의 목적지(d.x·y)가 기준 위치와 다르면 맞춤 — 움직이는 중이면 그쪽으로 다시 이동, 아니면 바로
func _fix_pos(uv: UnitView, x: int, y: int) -> void:
	if int(uv.d["x"]) == x and int(uv.d["y"]) == y:
		return
	if uv.moving:
		uv.move_to(x, y)
	else:
		uv.d["x"] = x
		uv.d["y"] = y
		uv.place_now()


func _enter_menu() -> void:
	_sync_from_engine()
	var u: Dictionary = eng.awaiting_unit()
	_set_cur(int(u["id"]))
	view_phase = "player"
	_hud_dirty = true
	_refresh_loops()
	for uv: UnitView in units.values():
		uv.selected = uv.id == int(u["id"])
		uv.face_hidden = false
	_clear_target()
	_show_intents()
	if show_threat:
		map.set_threat(eng.q.threat_cells())
	mode = "menu"
	_show_main_menu(u)
	if _select_sfx:
		_select_sfx = false
		_sfx("select")   # 웹 ActionManager.selU 끝의 Fx.sfx('Select')
	ui.show_hint(fail_hint)   # 방금 명령이 진짜 실패했으면 메뉴로 돌아와도 안내를 남김 (다음 조작 때 지움)
	_autosave()
	input_ready.emit(int(u["id"]))


## 지금 아래 안내 줄 글 (시험용)
func current_hint() -> String:
	return ui.hint.text


func is_awaiting() -> bool:
	return mode == "menu"


func is_over() -> bool:
	return _over


func awaiting_unit_id() -> int:
	var u: Variant = eng.awaiting_unit() if eng != null else null
	return int(u["id"]) if u != null and mode != "busy" else -1


func _unit_screen(id: int) -> Vector2:
	var uv: UnitView = units.get(id)
	if uv == null:
		return get_viewport().get_visible_rect().size / 2.0
	return get_viewport().get_canvas_transform() * (uv.position + Vector2(0, -30))


func _e(emoji: String) -> Texture2D:
	return icons.emoji(emoji)


func _show_main_menu(u: Dictionary) -> void:
	var acts: Dictionary = {}
	for a: Dictionary in eng.q.actions(u):
		acts[a["op"]] = a
	var acted := Js.truthy(u.get("ha"))
	var items: Array = []
	if acts["move"]["ok"]:
		items.append({"op": "move", "tex": _e("👣"), "glyph": "»", "label": _t("battle.move"), "sub": _t("battle.am_move_sub", {"n": u["move"]}), "key": "M", "ac": "move"})
	var healer: bool = u.get("role") == "healer"
	var at: Dictionary = eng.q.attack_targets(u)
	var n_t: int = (at["attack"] as Array).size() + ((at["heal"] as Array).size() if healer else 0)
	if not acted and n_t > 0:
		items.append({"op": "attack", "tex": null if healer else _e("⚔️"), "glyph": "✚" if healer else "⚔", "label": _t("battle.attack_heal" if healer else "battle.attack"), "sub": _t("battle.am_targets", {"n": n_t}), "key": "A", "ac": "attack"})
	var actives := 0
	var usable := 0
	for st: Dictionary in eng.q.skill_status(u):
		if not st["passive"]:
			actives += 1
			if st["usable"]:
				usable += 1
	if not acted and actives > 0:
		items.append({"op": "skill", "tex": _e("🔱"), "glyph": "✦", "label": _t("battle.skill"), "sub": _t("battle.am_usable", {"n": usable, "total": actives}), "key": "S", "ac": "skill", "warn": usable == 0})
	var n_items := 0
	for p: Dictionary in eng.S["_battlePotions"]:
		n_items += int(Js.num(p.get("quantity", 1))) if p.get("quantity") != null else 1
	for s: Dictionary in eng.S["_siegeItems"]:
		n_items += int(Js.num(s.get("quantity", 1))) if s.get("quantity") != null else 1
	if not acted and n_items > 0:
		items.append({"op": "item", "tex": _e("🎒"), "glyph": "◆", "label": _t("battle.item"), "sub": _t("battle.am_count", {"n": n_items}), "key": "I", "ac": "item"})
	if not acted:
		if acts["shove"]["ok"]:
			items.append({"op": "shove", "tex": _e("🫸"), "glyph": "⇥", "label": _t("battle.shove"), "sub": _t("battle.am_shove_sub", {"n": eng.q.shove_cells(u).size()}), "key": "P", "ac": "wait"})
		items.append({"op": "defend", "tex": _e("🛡️"), "glyph": "▣", "label": _t("battle.defend"), "sub": _t("battle.am_defend_sub"), "key": "D", "ac": "wait"})
		items.append({"op": "overwatch", "tex": _e("👁"), "glyph": "◉", "label": _t("battle.overwatch"), "sub": _t("battle.am_overwatch_sub"), "key": "O", "ac": "wait"})
	items.append({"op": "wait", "glyph": "Ⅱ", "label": _t("battle.wait"), "sub": _t("battle.am_wait_sub"), "key": "W", "ac": "wait"})
	if acts["undo"]["ok"]:
		items.append({"op": "undo", "glyph": "↩", "label": _t("battle.undo_move"), "key": "Esc", "ac": "cancel"})
	ui.show_menu("", items, _unit_screen(int(u["id"])))
	map.set_hl({"%d,%d" % [int(u["x"]), int(u["y"])]: "selected"})


func _show_skill_menu(u: Dictionary) -> void:
	var items: Array = []
	var skills: Array = eng.get_unit_skills(u)
	var n := 0
	for st: Dictionary in eng.q.skill_status(u):
		if st["passive"]:
			continue
		n += 1
		var skd: Dictionary = skills[int(st["idx"])]
		var cost := ""
		if Js.num(skd.get("cost")) > 0.0:
			cost = "%s %s" % [_num(skd["cost"]), _t("resources." + str(skd.get("costType", u.get("resType", ""))))]
		var reason := ""
		match str(st["reason"]):
			"acted":
				reason = _t("battle.reason_acted")
			"no_resource":
				reason = _t("battle.reason_no_res", {"cost": cost})
			"no_target":
				reason = _t("battle.reason_no_target")
		var sid := str(st["id"])
		var desc_k := "skills_desc." + sid
		items.append({"op": "skill_pick", "idx": int(st["idx"]), "tex": icons.skill(sid, str(skd.get("icon", ""))), "glyph": "✦", "label": _t("skills." + sid), "sub": reason if reason != "" else cost,
			"warn": reason != "", "enabled": bool(st["usable"]), "key": str(n), "ac": "skill", "tip": icons.strip(_t(desc_k)) if i18n.has_key(desc_k) else ""})
	items.append({"op": "cancel", "glyph": "↩", "label": _t("battle.cancel"), "key": "Esc", "ac": "cancel"})
	ui.show_menu(_t("battle.skill"), items, _unit_screen(int(u["id"])))


func _show_item_menu(u: Dictionary) -> void:
	var items: Array = []
	var n := 0
	for grp: Array in [["potion", eng.S["_battlePotions"], "potionId", "battle_potions."], ["siege", eng.S["_siegeItems"], "siegeId", "shop."]]:
		var seen: Dictionary = {}
		var order: Array = []
		var list: Array = grp[1]
		for i in list.size():
			var it: Dictionary = list[i]
			var id := str(it[grp[2]])
			if not seen.has(id):
				seen[id] = {"idx": i, "count": 0}
				order.append(id)
			seen[id]["count"] += int(Js.num(it.get("quantity"))) if it.get("quantity") != null else 1
		for id2: String in order:
			n += 1
			var tip_k := str(grp[3]) + id2 + "_desc"
			items.append({"op": "item_pick", "kind": grp[0], "idx": int(seen[id2]["idx"]), "tex": icons.item(id2), "frame": icons.rarity_frame(id2), "framed": true,
				"glyph": "◆", "label": _t(str(grp[3]) + id2), "sub": "×%d" % int(seen[id2]["count"]), "key": str(n), "ac": "item", "tip": _t(tip_k) if i18n.has_key(tip_k) else ""})
	items.append({"op": "cancel", "glyph": "↩", "label": _t("battle.cancel"), "key": "Esc", "ac": "cancel"})
	ui.show_menu(_t("battle.item"), items, _unit_screen(int(u["id"])))


## 적 행동 예고 (웹 rIntent): 보이는 적 → 노리는 클랜원 점선 화살표 + 노려지는 수
func _show_intents() -> void:
	var pairs: Array = []
	var cnt: Dictionary = {}
	var vis: Dictionary = map.fog_vis
	for e: Dictionary in eng.S["units"]:
		if e["team"] != "enemy" or float(e["hp"]) <= 0.0 or e.get("_intent") == null or eng.is_stealthed(e) or not vis.has("%d,%d" % [int(e["x"]), int(e["y"])]):
			continue
		var a: Variant = eng.unit_by_id(e["_intent"])
		if a == null or float(a["hp"]) <= 0.0:
			continue
		cnt[int(a["id"])] = int(cnt.get(int(a["id"]), 0)) + 1
		pairs.append([iso.foot(int(e["x"]), int(e["y"])) + Vector2(0, -22), iso.foot(int(a["x"]), int(a["y"])) + Vector2(0, -22)])
	fx.intents = pairs
	var badges: Array = []
	for id: int in cnt.keys():
		var uv: UnitView = units.get(id)
		if uv != null:
			badges.append({"pos": uv.position + Vector2(24, -62), "n": cnt[id]})
	fx.intent_badges = badges
	fx.queue_redraw()


func _hide_intents() -> void:
	fx.intents = []
	fx.intent_badges = []
	fx.previews = []
	fx.queue_redraw()


# ═══════════ UI 수준 입구 (마우스·단축키·메뉴·시험이 모두 여기로) ═══════════

## 메뉴 단추 (move · attack · shove · skill · item · wait · defend · overwatch · undo)
##  단추를 보일지(가능한 행동인지)는 메뉴가 정함 — 여기서는 막지 않음 (실패한 명령도 엔진이 웹처럼 기록·거절)
func ui_action(op: String) -> bool:
	fail_hint = ""
	if mode == "busy" or mode == "over":
		return false
	var u: Variant = eng.awaiting_unit()
	if u == null:
		return false
	ui.info.hide_popup()
	if mode != "menu":
		_back_to_menu(false)
	match op:
		"move":
			var cells: Dictionary = {}
			for c: Dictionary in eng.q.move_cells(u):
				cells["%d,%d" % [int(c["x"]), int(c["y"])]] = "vault" if Js.truthy(c.get("vault")) else "move"
			_enter_target("move", -1, cells, {}, _t("messages.select_move_target"))
		"attack":
			var at: Dictionary = eng.q.attack_targets(u)
			var cells2: Dictionary = {}
			var heals: Dictionary = {}
			for c2: Dictionary in at["cover"]:
				cells2["%d,%d" % [int(c2["x"]), int(c2["y"])]] = "cover"
			for c3: Dictionary in at["attack"]:
				cells2["%d,%d" % [int(c3["x"]), int(c3["y"])]] = "attack"
			for c4: Dictionary in at["block"]:
				cells2["%d,%d" % [int(c4["x"]), int(c4["y"])]] = "block"
			for c5: Dictionary in at["heal"]:
				var k5 := "%d,%d" % [int(c5["x"]), int(c5["y"])]
				cells2[k5] = "heal"
				heals[k5] = true
			_enter_target("attack", -1, cells2, heals, _t("messages.select_attack_target"))
			_show_previews(u, at)
		"shove":
			var cells3: Dictionary = {}
			for c6: Dictionary in eng.q.shove_cells(u):
				cells3["%d,%d" % [int(c6["x"]), int(c6["y"])]] = "attack"
			_enter_target("shove", -1, cells3, {}, _t("messages.select_shove_target"))
		"skill":
			mode = "skills"
			_show_skill_menu(u)
		"item":
			mode = "items"
			_show_item_menu(u)
		"wait", "defend", "overwatch":
			_enter_face(op, u)
		"undo":
			_send({"op": "undo"})
		_:
			return false
	return true


## 스킬 고르기 — 즉시형은 바로 명령, 대상형은 칸 고르기
func ui_pick_skill(idx: int) -> bool:
	fail_hint = ""
	if mode == "busy" or mode == "over":
		return false
	var u: Variant = eng.awaiting_unit()
	if u == null:
		return false
	var st: Dictionary = eng.q.skill_targets(u, idx)
	if st["instant"]:
		_send({"op": "skill", "idx": idx})
		return true
	var cells: Dictionary = {}
	for c: Dictionary in st["cells"]:
		cells["%d,%d" % [int(c["x"]), int(c["y"])]] = "skill"
	_enter_target("skill", idx, cells, {}, _t("skills." + str(eng.get_unit_skills(u)[idx]["id"])))
	return true


## 아이템 고르기 (kind: potion · siege, idx: S._battlePotions / S._siegeItems 번호) → 칸 고르기
func ui_pick_item(kind: String, idx: int) -> bool:
	fail_hint = ""
	if mode == "busy" or mode == "over":
		return false
	var u: Variant = eng.awaiting_unit()
	if u == null:
		return false
	var cells: Dictionary = {}
	if kind == "potion":
		var pt: Dictionary = eng.q.potion_targets(u, idx)
		for c: Dictionary in pt["cells"]:
			cells["%d,%d" % [int(c["x"]), int(c["y"])]] = "attack" if pt["debuff"] else "heal"
		_enter_target("potion", idx, cells, {}, _t("messages.select_potion_target"))
	else:
		var sg: Dictionary = eng.q.siege_targets(u, idx)
		for c2: Dictionary in sg["cells"]:
			cells["%d,%d" % [int(c2["x"]), int(c2["y"])]] = "attack"
		_enter_target("climb" if sg["effect"] == "climb" else "siege", idx, cells, {}, _t("messages.select_siege_target"))
	return true


## 칸 누르기 (칸 고르기 중) → 명령. 하이라이트 밖 칸도 그대로 엔진에 넘김 (마우스는 밖을 누르면 취소로 걸러 냄)
func ui_click_cell(x: int, y: int) -> bool:
	if mode != "target":
		return false
	var cmd: Dictionary = {}
	match target_op:
		"move":
			cmd = {"op": "move", "x": x, "y": y}
		"attack":
			cmd = {"op": "heal" if heal_cells.has("%d,%d" % [x, y]) else "attack", "x": x, "y": y}
		"shove":
			cmd = {"op": "shove", "x": x, "y": y}
		"skill":
			cmd = {"op": "skill", "idx": target_idx, "x": x, "y": y}
		"potion", "siege", "climb":
			cmd = {"op": target_op, "idx": target_idx, "x": x, "y": y}
	_send(cmd)
	return true


## 방향 고르기 (dx, dy: -1·0·1, 0,0 = 지금 방향 그대로)
func ui_pick_face(dx: int, dy: int) -> bool:
	if mode != "face":
		return false
	_send({"op": face_op, "dx": dx, "dy": dy})
	return true


## 취소: 칸·방향·하위 메뉴 → 행동 메뉴, 행동 메뉴에서는 이동 취소(가능할 때)
func ui_cancel() -> bool:
	fail_hint = ""
	if ui.info.popup.visible:
		ui.info.hide_popup()
	match mode:
		"target", "face", "skills", "items":
			_back_to_menu(true)
			return true
		"menu":
			if eng.q.can_undo():
				_send({"op": "undo"})
				return true
	return false


func _back_to_menu(show: bool) -> void:
	_clear_target()
	for uv: UnitView in units.values():
		uv.face_hidden = false
	mode = "menu"
	ui.show_hint("")
	if show:
		_show_intents()
		_show_main_menu(eng.awaiting_unit())


func _enter_target(op: String, idx: int, cells: Dictionary, heals: Dictionary, hint: String) -> void:
	mode = "target"
	target_op = op
	target_idx = idx
	target_cells = cells
	heal_cells = heals
	var u: Dictionary = eng.awaiting_unit()
	var hl := cells.duplicate()
	hl["%d,%d" % [int(u["x"]), int(u["y"])]] = "selected"
	map.set_hl(hl)
	ui.hide_menu()
	ui.show_hint(hint)


func _clear_target() -> void:
	target_op = ""
	target_idx = -1
	target_cells = {}
	heal_cells = {}
	face_op = ""
	fx.picker = {}
	fx.previews = []
	fx.queue_redraw()
	var u: Variant = eng.awaiting_unit()
	if u != null:
		map.set_hl({"%d,%d" % [int(u["x"]), int(u["y"])]: "selected"})
	else:
		map.set_hl({})


## 공격 예상 (웹 rPreview): 공격 가능한 적 머리 위 피해(처치면 💀)·전술 보정·방어막·숲 회피·여울·연계·반격
##  Godot: 실제 공격처럼 계산(as_exec) — 주술사 고양 마지막 공격 차이를 바로잡음 (scripts/logic/battle/battle_query.gd)
func _show_previews(u: Dictionary, at: Dictionary) -> void:
	var list: Array = []
	for c: Dictionary in at["attack"]:
		var v: Variant = null
		for w: Dictionary in eng.S["units"]:
			if float(w["hp"]) > 0.0 and int(w["x"]) == int(c["x"]) and int(w["y"]) == int(c["y"]):
				v = w
				break
		if v == null or v["team"] == u["team"]:
			continue
		var p: Dictionary = eng.q.preview_attack(u, v, true)
		var pos := iso.foot(int(v["x"]), int(v["y"])) + Vector2(0, -64)
		if p["intercept"] != null:
			list.append({"pos": pos, "main": "-" + _num(p["intercept_dmg"]), "sub": _t("battle.preview_intercept"), "kind": "block", "icon": _e("🛡️")})
			continue
		var sub: Array = []
		if float(p["pct"]) != 0.0:
			var tags: Array = []
			for tg: String in p["tags"]:
				tags.append(_t("battle.tactic_" + tg))
			sub.append("%s +%s%%" % ["·".join(tags), _num(p["pct"])])
		if p["shield"]:
			sub.append(_t("gd.tip.shield_half"))
		if p["evade"]:
			sub.append(_t("battle.tactic_evade", {"n": p["evade"]}))
		if p["shallow"]:
			sub.append(_t("battle.tactic_shallow", {"n": Js.round_js(float(D["TACTIC"]["shallowVuln"]) * 100.0)}))
		if p["support"]:
			sub.append(_t("battle.preview_support", {"n": p["support"]}))
		if float(p["counter"]) > 0.0:
			sub.append(_t("battle.preview_counter", {"n": p["counter"]}))
		list.append({"pos": pos, "main": "-" + _num(p["dmg"]), "sub": "  ".join(sub), "kind": "kill" if p["kill"] else "dmg", "icon": _e("💀") if p["kill"] else null})
	fx.set_previews(list)


## 방향 고르기 (웹 showFacePicker: 유닛 둘레 네 칸 + 그 방향일 때 등 뒤·옆 적 수)
func _enter_face(op: String, u: Dictionary) -> void:
	mode = "face"
	face_op = op
	face_opts = eng.q.face_options(u)
	var uv: UnitView = units.get(int(u["id"]))
	if uv != null:
		uv.face_hidden = true
		uv.queue_redraw()
	var ctr := iso.top_center(int(u["x"]), int(u["y"]))
	var opts: Array = []
	for o: Dictionary in face_opts:
		var lab := _t("battle.face_back", {"n": o["back"]}) if int(o["back"]) > 0 else (_t("battle.face_side", {"n": o["side"]}) if int(o["side"]) > 0 else _t("battle.face_safe"))
		opts.append({"dx": o["dx"], "dy": o["dy"], "back": o["back"], "side": o["side"], "cur": o["cur"], "best": o["best"], "pos": ctr + iso.g2screen(float(o["dx"]), float(o["dy"])), "label": lab})
	fx.picker = {"opts": opts, "tip": _t("battle.face_tip"), "tip_pos": ctr + Vector2(0, -Iso.UH - 18.0 + 30.0)}
	fx.queue_redraw()
	ui.hide_menu()
	ui.show_hint(_t("battle." + op))


## 엔진에 명령 하나 → 바로 진행 (적 차례까지 엔진은 끝까지 돌고, 화면은 대기열을 재생)
func _send(cmd: Dictionary) -> void:
	var u: Variant = eng.awaiting_unit()
	if u == null:
		return
	# 명령 전 상태 — 실패 안내는 명령 뒤에도 같은 클랜원이 같은 상태로 입력을 기다릴 때만
	#  (엔진 cmd.ok 는 행동 직후 ha 기준이라, 공격이 회피되면 실제로는 행동했어도 ok=false 가 됨 — 엔진은 그대로 둠)
	var before := _act_state(u)
	last_result = eng.command(cmd)
	if bool(last_result.get("ok", false)):
		match str(cmd.get("op", "")):
			"move":
				_sfx("move")      # 웹 doMv: Fx.sfx('Move')
			"wait", "defend", "overwatch":
				_sfx("wait")      # 웹 actWait (방어 태세·경계도 actWait 로 끝남): Fx.sfx('Wait')
			"undo":
				_sfx("uiclick")   # 웹 actCancel 이동 되돌리기: Fx.sfx('UIClick')
				_select_sfx = true   # 웹은 되돌린 뒤 클랜원을 다시 눌러 고름(selU → Select) — Godot 은 메뉴가 바로 다시 뜨므로 그때
	var after_u: Variant = eng.awaiting_unit()
	var really_failed: bool = not last_result["ok"] and after_u != null and int(after_u["id"]) == int(u["id"]) and _act_state(after_u) == before
	_clear_target()
	_hide_intents()
	map.set_threat([])
	for uv: UnitView in units.values():
		uv.face_hidden = false
		uv.selected = false
	ui.hide_menu()
	ui.info.hide_popup()
	fail_hint = _fail_text(str(last_result["reason"])) if really_failed else ""
	ui.show_hint(fail_hint)
	mode = "busy"
	_eng_status = eng.run()


## command() 실패 이유 → 안내 (gd.fail.* — Godot 전용 번역 키)
func _fail_text(reason: String) -> String:
	var k := "gd.fail." + reason
	return _t(k) if i18n != null and i18n.has_key(k) else reason


## 행동 여부를 가르는 값 (위치·행동·이동·자원)
func _act_state(u: Dictionary) -> Array:
	return [int(u["x"]), int(u["y"]), Js.truthy(u.get("ha")), Js.truthy(u.get("hm")), float(u.get("res", 0.0)), int(eng.S["actCount"])]


# ═══════════ 이어하기 (4b-1) ═══════════

func _is_store() -> bool:
	return str(cfg.get("source", "")) == "store" and store != null


## 입력을 기다릴 때마다 저장 (실제 세이브 전투만): 지금까지 바뀐 저장값을 Store 에 쓰고(웹은 늘 바로 씀) → 엔진 상태를 gd_battle 에
##  창을 닫거나 앱이 꺼져도 로비의 '전투 재개'로 이 차례부터 이어 함
func _autosave() -> void:
	if not _is_store() or _over or _rc == null or not eng.can_save():
		return
	_write_back()
	ResumeRules.save_gd(_rc, cfg, eng.save_text())
	autosaves += 1


## 저장하고 로비로 (설정 창 '나가기') — 연출 중이면 입력을 기다릴 때 나감
func leave_battle() -> void:
	if _over or _leaving:
		return
	if not _is_store() or _svc("Router") == null:
		_leaving = true
		_go_back()
		return
	if mode == "busy" or _hold > 0 or _eng_status != "input" or eng.awaiting_unit() == null:
		_leave_pending = true
		ui.show_hint(_t("gd.settings.leave_pending"))
		return
	_autosave()
	_leaving = true
	_svc("Router").call("go", "lobby")


## 이어하기: 엔진 저장소를 지금 Store 값으로 바꾸고, 전투 물약·공성 아이템의 인벤토리 번호를 물건(pid·sid)으로 다시 찾음
##  (나가 있는 동안 상점에서 사거나 판 물건 때문에 번호가 밀려도 같은 물건을 쓰게. 없어진 물건은 전투 목록에서 뺌)
func _resume_sync_store(save: Dictionary) -> void:
	var ss := SaveStore.new()
	ss.load_from(save)
	eng.c.store = ss
	# 웹 전투 페이지도 들어올 때마다(이어하기 포함) GameStore.gold·cleared 를 저장값에서 다시 읽음 (boot.js DOMContentLoaded loadGoldData)
	var gdat := Profile.load_gold_data(eng.c)
	eng.S["gold"] = gdat["gold"]
	eng.S["cleared"] = gdat["cleared"]
	var inv: Variant = ss.get_json(Profile.INVENTORY_KEY)
	var inv_a: Array = inv if inv is Array else []
	var used: Dictionary = {}
	for pair: Array in [["_battlePotions", "_battlePotionIndices", "pid", "potionId"], ["_siegeItems", "_siegeInvIndices", "sid", "siegeId"]]:
		var items: Array = eng.S.get(pair[0], [])
		var idxs: Array = eng.S.get(pair[1], [])
		var keep_i: Array = []
		var keep_x: Array = []
		for i in items.size():
			var it: Variant = items[i]
			if not (it is Dictionary) or i >= idxs.size():
				continue
			var at := _match_inv(inv_a, it, int(idxs[i]), str(pair[2]), str(pair[3]), used)
			if at < 0:
				continue
			used[at] = true
			keep_x.append(it)
			keep_i.append(at)
		eng.S[pair[0]] = keep_x
		eng.S[pair[1]] = keep_i


static func _same_item(a: Variant, b: Dictionary, id_key: String, kind_key: String) -> bool:
	if not (a is Dictionary) or not Js.same(a.get("type"), b.get("type")):
		return false
	if b.get(id_key) != null:
		return Js.same(a.get(id_key), b.get(id_key))
	return Js.same(a.get(kind_key), b.get(kind_key))


static func _match_inv(inv: Array, it: Dictionary, old: int, id_key: String, kind_key: String, used: Dictionary) -> int:
	if old >= 0 and old < inv.size() and not used.has(old) and _same_item(inv[old], it, id_key, kind_key):
		return old
	for j in inv.size():
		if not used.has(j) and _same_item(inv[j], it, id_key, kind_key):
			return j
	return -1


# ═══════════ 항복 · 끝 ═══════════

## 항복 (웹 Renderer.surrender: FSM → BATTLE_END + battle_end{win:false} — 엔진의 공개 함수 transition·emit 을 웹과 같은 순서로 부름)
func surrender() -> void:
	if _over or eng.fsm == BattleEngine.BATTLE_END:
		return
	# 입력 대기 중에만 — 연출 중(적 차례·대사·로딩)이면 연출이 끝나 입력을 기다릴 때 항복
	if mode == "busy" or _hold > 0 or _eng_status != "input":
		_surrender_pending = true
		ui.show_hint(_t("gd.settings.surrender_pending"))
		return
	_do_surrender()


func _do_surrender() -> void:
	eng.transition(BattleEngine.BATTLE_END)
	eng.emit("battle_end", {"win": false, "message": "messages.surrender"})
	_eng_status = eng.run()
	# 남은 연출은 건너뜀 — 엔진 상태로 맞추고 바로 결과
	_evq.clear()
	_qi = 0
	_wait = 0.0
	_clear_target()
	_hide_intents()
	ui.hide_menu()
	_sync_from_engine()
	_finish()


func _finish() -> void:
	if _over:
		return
	_over = true
	mode = "over"
	result = eng.finish(_eng_status)
	# 항복은 남은 연출(battle_end 포함)을 건너뛰므로 여기서 (웹 render.js surrender → battle_end 알림 → 패배 효과음)
	if eng.ended:
		_end_sound(result.get("result") == "win")
	ui.hide_menu()
	ui.info.hide_tip()
	ui.info.hide_popup()
	_hide_intents()
	map.set_hl({})
	# 실제 세이브로 시작한 전투면 결과(골드·경험치·보상)를 Store 에 되돌려 씀 (본 스토리 기록은 이번 전투에서 늘었을 수 있어 합쳐서)
	if str(cfg.get("source", "")) == "store" and store != null:
		_write_back()
		if _rc != null:
			ResumeRules.clear_gd(_rc)   # 끝난 전투는 이어할 것이 없음
	battle_over.emit(result)
	if result.get("result") == "win" and story.enabled:
		_story_play(story.outro(), _show_result)
	else:
		_show_result()


## 엔진 저장소 → Store: 전투가 바꾼 키만 (넘긴 값과 다른 키·새 키), 엔진이 지운 키는 지움. 본 스토리 기록은 따로 (이미 Store 에 씀)
func _write_back() -> void:
	var now: Dictionary = {}
	for k: String in eng.c.store.keys():
		now[k] = true
		if k == StoryBattle.SEEN_KEY:
			continue
		var v: Variant = eng.c.store.get_json(k)
		if not _save_in.has(k) or JsonExact.stringify(_save_in[k]) != JsonExact.stringify(v):
			store.call("set_json", k, v)
			_save_in[k] = Js.deep(v)   # (4b-1) 전투 중 자동 저장에서도 부름 → 다음엔 그 뒤에 바뀐 것만
	for k2: String in _save_in.keys():
		if not now.has(k2) and k2 != StoryBattle.SEEN_KEY:
			store.call("remove", k2)
			_save_in.erase(k2)


func _show_result() -> void:
	ui.show_result(_result_model())


## 결과 화면 모델 (웹 showRes 와 같은 순서·같은 글) — 엔진 S 의 보상 값을 읽기만
func _result_model() -> Dictionary:
	var S: Dictionary = eng.S
	var win: bool = result.get("result") == "win"
	var st: Variant = S["cStage"]
	var reason := str(result.get("reason", result.get("result", "")))
	var mkey := reason if reason.contains(".") else "messages." + reason
	var msg := _t(mkey, {"stage_id": st["id"] if st != null else 0, "turn": S["turn"], "count": S["breached"]}) if i18n.has_key(mkey) else reason
	var m := {"win": win, "title": _t("messages.victory" if win else "messages.defeat"), "msg": icons.strip(msg), "notes": [], "rewards": [], "exp": [], "buttons": []}
	var EC: Dictionary = D["ECON"]
	if Js.truthy(S.get("practiceMode")):
		var notes: Array = [_t("stage.practice_mode_active"), "%s (%d%%)" % [_t("stage.reduced_gold"), int(Js.round_js(float(EC["practiceMul"]) * 100.0))], _t("stage.full_exp") + " (100%)"]
		var ar := int(Js.num(S.get("_autoRevivedCount")))
		if ar > 0:
			notes.append(_t("stage.auto_revived", {"count": ar}))
		notes.append(_t("stage.no_clear_recorded"))
		m["notes"] = notes
	var sr: Variant = S.get("_starResult")
	if win and typeof(sr) == TYPE_DICTIONARY:
		m["stars"] = {"merged": sr["merged"], "newly": sr["newly"], "flags": sr["flags"],
			"conds": [_t("stars.cond_clear"), _t("stars.cond_nodeath"), "%s (%s)" % [_t("stars.cond_turns", {"n": sr["limit"]}), _t("battle.turn_n", {"n": sr["turn"]})]]}
	var rw: Array = m["rewards"]
	if win:
		if typeof(sr) == TYPE_DICTIONARY and Js.num(sr.get("bonus")) > 0.0:
			rw.append({"tex": _e("⭐"), "label": _t("stars.bonus"), "value": "+%s G" % _num(sr["bonus"])})
		var actual := Js.num(S.get("_baseReward")) + Js.num(S.get("_bonusReward"))
		if actual > 0.0:
			rw.append({"tex": icons.item("gold"), "label": _t("messages.reward"), "value": "+%s G" % _num(actual)})
		if Js.num(S.get("_firstClearBonus")) > 0.0:
			rw.append({"tex": _e("🎉"), "label": _t("messages.first_clear_bonus"), "value": "+%s G" % _num(S["_firstClearBonus"])})
		var fcu: Variant = S.get("_firstClearUnit")
		if typeof(fcu) == TYPE_DICTIONARY:
			rw.append({"tex": icons.char_tex(str(fcu["cls"]), str(fcu.get("gender", "m")), sdb), "portrait": true, "label": _t("messages.first_clear_unit", {"cls": _t("classes." + str(fcu["cls"]))}), "value": ""})
		if Js.truthy(S.get("_droppedBook")):
			rw.append({"tex": icons.item("skillbook"), "frame": icons.rarity_frame("skillbook"), "label": _t("academy.skillbook_drop", {"skill": _t("skills." + str(S["_droppedBook"]))}), "value": ""})
		if Js.truthy(S.get("_runeDrop")):
			var rk := str(S["_runeDrop"])
			rw.append({"tex": icons.item("rune_" + rk) if icons.item("rune_" + rk) != null else _e(str(D["ENCHANTS"][rk]["icon"])), "label": _t("enchant.rune_name", {"e": _t("enchant." + rk)}), "value": "+1"})
		var so: Variant = S.get("_soulReward")
		if typeof(so) == TYPE_DICTIONARY:
			rw.append({"tex": icons.item("soul_stone"), "label": _t("soul.reward_stone" if so["kind"] == "stone" else "soul.reward_frag", {"cls": _t("classes." + str(so["cls"]))}), "value": "+%s" % _num(so["n"])})
		for g: Dictionary in _gear_drop_items():
			rw.append(g)
	var dead := (S.get("_deadAllyUids", []) as Array).size()
	if dead > 0:
		m["fallen"] = _t("results.fallen", {"n": dead})
	var er: Array = S.get("_expResults", []) if typeof(S.get("_expResults")) == TYPE_ARRAY else []
	if not er.is_empty():
		m["detail"] = _t("results.battle_detail", {"kills": Js.num(S.get("_deadEnemyCount")), "exp": Js.num(S.get("_totalExp")), "survivors": er.size()})
		var roster: Variant = eng.c.store.get_json("game_roster")
		var chars: Array = roster.get("chars", []) if typeof(roster) == TYPE_DICTIONARY else []
		for r: Dictionary in er:
			var ch: Variant = null
			for c: Variant in chars:
				if typeof(c) == TYPE_DICTIONARY and Js.same(c.get("uid"), r["uid"]):
					ch = c
					break
			if ch == null:
				continue
			var nm := info.char_name(ch)
			var lv := float(ch.get("lv", 1))
			var need := 0.0 if lv >= Profile.max_level_of(eng.c, ch) else Profile.exp_for_level(eng.c, lv)
			var leveled := Js.num(r.get("leveled")) > 0.0
			(m["exp"] as Array).append({"tex": icons.char_tex(str(ch["cls"]), str(ch.get("gender", "m")), sdb), "summon": false, "name": nm,
				"ratio": minf(1.0, Js.num(ch.get("exp")) / need) if need > 0.0 else 1.0, "exp_text": "+%s EXP" % _num(r["exp"]),
				"lv_text": ("LV %s → %s" % [_num(r.get("prevLv", lv)), _num(lv)]) if leveled else "Lv.%s" % _num(lv), "lvup": leveled})
	var btns: Array = m["buttons"]
	var daily: bool = st != null and Js.truthy(st.get("daily"))
	btns.append({"id": "back", "text": _t("daily.back") if daily else _t("results.return_to_lobby"), "primary": not win})
	# 다시 도전(Godot 전용)은 실제 세이브의 요일 던전에서는 뺌 — 입장 횟수를 쓰지 않고 다시 들어가게 되므로
	if not (daily and str(cfg.get("source", "")) == "store"):
		btns.append({"id": "retry", "text": _t("gd.result.retry")})
	if win and not daily and st != null:
		for s2: Dictionary in D["STAGES"]:
			if int(s2["id"]) == int(st["id"]) + 1:
				btns.append({"id": "next", "text": _t("results.next_stage"), "primary": true})
				break
	return m


## 장비 보상 — 엔진 순수 조회 gear_drop_items(전투 시작 때 eid 기준)로 실제 물건의 이름·등급
func _gear_drop_items() -> Array:
	var out: Array = []
	for g: Dictionary in eng.q.gear_drop_items(_inv_eids0):
		if g.has("stone"):
			out.append({"tex": icons.item("mat_stone"), "label": "%s +%s" % [_t("gear.stone"), _num(g["stone"])], "value": ""})
			continue
		var it: Variant = g.get("item")
		var tid := str(g["templateId"])
		var legend: bool = g.get("legend", false)
		var key := tid
		var name := ""
		var rar := "common"
		if typeof(it) == TYPE_DICTIONARY:
			rar = str(it.get("rarity", "common"))
			if Js.truthy(it.get("legend")):
				key = "legend_" + str(it["legend"])
				name = _t("gear.legend." + str(it["legend"]))
			elif Js.truthy(it.get("setCls")):
				name = _t("gear.set_piece", {"set": _t("gear.set." + str(it["setCls"])), "slot": _t("equip.slot." + str(it.get("slot", "")))})
		if name == "":
			name = _t("gear.item." + tid) if i18n.has_key("gear.item." + tid) else _t("equip.item." + tid)
		var tex: Texture2D = icons.item(key) if icons.item(key) != null else icons.item(tid)
		out.append({"tex": tex, "frame": icons.rarity_frame(key, "legendary" if legend else rar), "label": ("★ " if legend else "") + name, "value": "", "legend": legend})
	return out


func _on_result_button(id: String) -> void:
	# 결과 단추는 한 번만 (같은 프레임 연타로 두 번 이동·두 번 출격하지 않게)
	if _leaving:
		return
	_leaving = true
	match id:
		"back":
			_go_back()
		"retry":
			_restart(0)
		"next":
			if _router_flow():
				_next_stage_flow()
			else:
				_restart(1)


## 실제 세이브 전투이고 Router 가 있으면 바깥 화면 흐름으로 (로비·스테이지 선택·편성). 시험·디버그 전투는 예전처럼
func _router_flow() -> bool:
	return str(cfg.get("source", "")) == "store" and _svc("Router") != null and store != null


## 웹 BattleEnd.goNextStage: 활성 파티의 산 클랜원이 5명이면 바로 다음 스테이지 전투, 아니면 편성 화면 (scripts/logic/party_rules.gd next_stage)
func _next_stage_flow() -> void:
	var PartyRules: GDScript = load("res://scripts/logic/party_rules.gd")
	var Flow: GDScript = load("res://scripts/ui/flow.gd")
	var StoreCtx: GDScript = load("res://scripts/logic/store_ctx.gd")
	var c2 := Ctx.new(D, randi() & 0x7fffffff, StoreCtx.new(store))
	var st: Variant = eng.S["cStage"]
	var ns: Variant = StageRules.find_stage(D, int(st["id"]) + 1)
	if ns == null:
		_go_back()
		return
	Flow.call("follow", _svc("Router"), store, c2, PartyRules.call("next_stage", c2, ns))


## 다시 하기·다음 스테이지: 같은 설정(세이브 출처·시드·파티)으로 장면을 다시 — Store 세이브면 지금 Store 값을 다시 읽음
func _restart(stage_add: int) -> void:
	var c := cfg.duplicate(true)
	if str(c.get("source", "")) == "store" and store != null:
		c["save"] = store_save(store)
	if stage_add != 0:
		var st: Variant = eng.S["cStage"]
		c["stage"] = {"id": int(st["id"]) + stage_add}
		c["inject"] = []
	c.erase("autoplay")
	pending = c
	get_tree().reload_current_scene()


## 로비로 (요일 던전이면 스테이지 선택의 요일 던전 창으로 — 웹 render.js showRes). Router 가 없거나 시험·디버그 전투면 시작 화면
func _go_back() -> void:
	if _router_flow():
		var st: Variant = eng.S["cStage"] if eng != null else null
		if st != null and Js.truthy(st.get("daily")):
			_svc("Router").call("go", "stage_select", {"daily": true}, false)
		else:
			_svc("Router").call("go", "lobby")
		return
	get_tree().change_scene_to_file(BOOT_SCENE)


func _exit_tree() -> void:
	# (5단계) 장면을 떠나면 배경음을 바로 끊음 (웹의 페이지 이동 — Router 를 거치지 않는 시험·다시 하기 대비)
	if sound != null and sound.call("bgm_wanted") == "battle":
		sound.call("stop_bgm", false)
	# 엔진 내부 순환 참조 정리 (결과·기록은 이미 꺼내 둠)
	if eng != null:
		if eng.bus_event.is_connected(_on_bus):
			eng.bus_event.disconnect(_on_bus)
		if eng.fx_event.is_connected(_on_fx):
			eng.fx_event.disconnect(_on_fx)
		eng.dispose()
	if i18n != null and i18n.is_connected("language_changed", _on_language):
		i18n.disconnect("language_changed", _on_language)


# ═══════════ 설정 · 언어 ═══════════

func _on_language(_lang: String) -> void:
	ui.relabel()
	_hud_dirty = true
	_badges_dirty = true
	ui.info.hide_tip()
	if ui.info.popup.visible:
		show_enemy_popup(ui.info.popup_unit)
	match mode:
		"menu":
			_show_main_menu(eng.awaiting_unit())
			ui.show_hint(fail_hint)
		"skills":
			_show_skill_menu(eng.awaiting_unit())
		"items":
			_show_item_menu(eng.awaiting_unit())
		"target":
			if target_op == "attack":
				_show_previews(eng.awaiting_unit(), eng.q.attack_targets(eng.awaiting_unit()))
		"face":
			_enter_face(face_op, eng.awaiting_unit())
	if ui.result_view.visible:
		_show_result()
	_update_cam_label()


func set_speed_index(i: int) -> void:
	_speed_i = clampi(i, 0, SPEEDS.size() - 1)
	speed = SPEEDS[_speed_i]
	fx.speed = speed
	pfx.time_scale = speed
	for uv: UnitView in units.values():
		uv.speed = speed
	ui.set_speed_label("%dx" % int(speed))


func set_reduce_motion(on: bool) -> void:
	reduce_motion = on
	ui.reduce_motion = on
	for uv: UnitView in units.values():
		uv.reduce_motion = on


# ═══════════ 카메라 ═══════════

func _update_cam_label() -> void:
	ui.set_cam(str(D["CARR"][iso.cam_dir]), str(D["CLAB"][iso.cam_dir]))


## 카메라 회전 (3b): 맵은 방향별 묶음을 바꿔 보이기만 하고(battle_map.switch_dir), 시야는 그대로라 다시 계산하지 않음.
##  메뉴는 다시 만들지 않고 자리만 옮김 — 한 프레임 끊김을 줄임 (3a: 맵 전체 다시 만들기 + 메뉴 다시 만들기 ~35ms)
func rotate_cam(d: int) -> void:
	var center := cam.get_screen_center_position() - cam.offset
	var g := iso.screen_to_grid_f(center)
	iso.cam_dir = ((iso.cam_dir + d) % 4 + 4) % 4
	map.switch_dir()
	map.set_safe(view_safe)
	for uv: UnitView in units.values():
		uv.refresh_camera()
	cam.position = iso.grid_f_to_screen(g)
	cam.reset_smoothing()
	_refresh_fade()
	_update_cam_label()
	ui.minimap.rebuild(_minimap_units())
	if show_threat and mode != "busy":
		map.set_threat(eng.q.threat_cells())
	ui.info.hide_popup()
	ui.info.hide_tip()
	match mode:
		"menu", "skills", "items":
			_show_intents()
			ui.place_menu(_unit_screen(awaiting_unit_id()))
		"face":
			_show_intents()
			_enter_face(face_op, eng.awaiting_unit())
		"target":
			_show_intents()
			if target_op == "attack":
				_show_previews(eng.awaiting_unit(), eng.q.attack_targets(eng.awaiting_unit()))


func toggle_threat() -> void:
	show_threat = not show_threat
	ui.set_threat(show_threat)
	if show_threat and mode != "busy" and mode != "over":
		map.set_threat(eng.q.threat_cells())
	else:
		map.set_threat([])


func _cycle_speed() -> void:
	set_speed_index((_speed_i + 1) % SPEEDS.size())
	ui.settings.s["playSpeed"] = int(speed)
	if str(cfg.get("source", "")) != "test":
		ui.settings.save_settings()


func _focus(p: Vector2) -> void:
	if speed <= 0.0:
		return
	var vs := get_viewport().get_visible_rect().size / cam.zoom
	var c := cam.get_screen_center_position()
	if absf(p.x - c.x) > vs.x * 0.35 or absf(p.y - c.y) > vs.y * 0.35:
		var tw := create_tween()
		tw.tween_property(cam, "position", p, 0.35 / speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 행동 순서·카드 누르기 (웹: 지금 차례 클랜원이면 선택, 아니면 그 유닛으로 화면 이동)
func _on_unit_nav_click(id: int) -> void:
	var uv: UnitView = units.get(id)
	if uv == null:
		return
	var tw := create_tween()
	tw.tween_property(cam, "position", uv.position + Vector2(0, -20), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if mode == "menu" and id == awaiting_unit_id():
		_show_main_menu(eng.awaiting_unit())
		_sfx("select")   # 웹 render.js 카드 누르기 → ActionManager.selU


func _on_nav_hover(id: int) -> void:
	if _nav_hover >= 0 and units.has(_nav_hover):
		(units[_nav_hover] as UnitView).hover = false
	_nav_hover = id
	if id >= 0 and units.has(id):
		(units[id] as UnitView).hover = true


func _clamp_cam() -> void:
	var ws := iso.world_size()
	cam.position = cam.position.clamp(Vector2(-100, -100), ws + Vector2(100, 100))


# ═══════════ 마우스·키보드 ═══════════

## 적 정보 팝업은 화면 어디를 누르든(맵·HUD 단추·미니맵 포함) 닫히고, 그 누르기는 먹지 않고 그대로 GUI·맵으로 감
##  (웹 pointerdown capture 와 같음 — _input 은 GUI 보다 먼저 옴. 휠은 누르기가 아니라 뺌)
func _input(ev: InputEvent) -> void:
	if ui == null or not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] and ui.info.popup.visible:
		ui.info.hide_popup()


func _unhandled_input(ev: InputEvent) -> void:
	if eng == null or ui == null:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if _hold > 0 or ui.result_view.visible:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var before := _to_world(mb.position)
				var z := clampf(cam.zoom.x * (1.1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1), 0.6, 3.0)
				cam.zoom = Vector2(z, z)
				cam.force_update_scroll()
				cam.position += before - _to_world(mb.position)
				_clamp_cam()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = true
				_dragging = false
				_drag_from = mb.position
				_cam_from = cam.position
			else:
				if _press and not _dragging:
					_click(_to_world(mb.position))
				_press = false
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			ui_cancel()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _press and (mm.position - _drag_from).length() > 6.0:
			_dragging = true
		if _dragging or (mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
			if mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE and not _press:
				cam.position -= mm.relative / cam.zoom
			else:
				cam.position = _cam_from - (mm.position - _drag_from) / cam.zoom
			_clamp_cam()
		if mode == "face":
			var h := fx.picker_hit(_to_world(mm.position))
			if h != fx.picker_hover:
				fx.picker_hover = h
				fx.queue_redraw()
		var hk := _hover_target(_to_world(mm.position)) if not _dragging else ""
		if hk != _hover_key:
			_hover_key = hk
			_hover_t = 0.0
			ui.info.hide_tip()   # 다른 칸·유닛으로 옮기면 바로 숨기고 다시 기다림
		_hover_pos = mm.position
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if _hold > 0 or ui.result_view.visible:
			return
		if ui.settings.is_open():
			if (ev as InputEventKey).keycode == KEY_ESCAPE:
				ui.settings.close()
			return
		_key((ev as InputEventKey).keycode)


## 화면(뷰포트) 좌표 → 전장 좌표 (카메라 이동·확대 반영)
func _to_world(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * p


func _key(k: Key) -> void:
	# 방향 고르는 중: W·D·O 도 지금 방향 그대로 (웹과 같음)
	if mode == "face" and (k == KEY_W or k == KEY_D or k == KEY_O):
		ui_pick_face(0, 0)
		return
	match k:
		KEY_Q:
			rotate_cam(-1)
			return
		KEY_E:
			rotate_cam(1)
			return
		KEY_T:
			toggle_threat()
			return
		KEY_ESCAPE, KEY_BACKSPACE:
			ui_cancel()
			return
		KEY_SPACE:
			# 웹: Space = 대기 (방향 고르는 중이면 지금 방향 그대로)
			if mode == "face":
				ui_pick_face(0, 0)
			elif mode == "menu":
				ui_action("wait")
			return
		KEY_ENTER, KEY_KP_ENTER:
			if mode == "face":
				ui_pick_face(0, 0)
			return
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			var v := {KEY_LEFT: Vector2(-60, 0), KEY_RIGHT: Vector2(60, 0), KEY_UP: Vector2(0, -60), KEY_DOWN: Vector2(0, 60)}
			cam.position += v[k] / cam.zoom
			_clamp_cam()
			return
	var s := OS.get_keycode_string(k).to_lower()
	ui.press_key(s)


func _click(p: Vector2) -> void:
	match mode:
		"face":
			var h := fx.picker_hit(p)
			if h >= 0:
				var o: Dictionary = fx.picker["opts"][h]
				ui_pick_face(int(o["dx"]), int(o["dy"]))
			else:
				ui_cancel()
		"target":
			var c := iso.iso_hit(p)
			var key := "%d,%d" % [c.x, c.y]
			if c.x >= 0 and target_cells.has(key) and target_cells[key] != "cover":
				ui_click_cell(c.x, c.y)
			else:
				ui_cancel()
				if _hover_target(p) == "u:%d" % awaiting_unit_id():
					_sfx("select")   # 웹 action.js:159 대상 고르는 중 자기 클랜원 누르기 → selU
		_:
			# 적을 누르면 정보 팝업 (웹 showEnemyPopup)
			var hk := _hover_target(p)
			if mode == "menu" and hk == "u:%d" % awaiting_unit_id():
				_show_main_menu(eng.awaiting_unit())
				_sfx("select")   # 웹 action.js:148·154 메뉴 상태에서 자기 클랜원 다시 누르기 → selU
				return
			if hk.begins_with("u:"):
				var uv: UnitView = units.get(hk.substr(2).to_int())
				if uv != null and uv.d.get("team") == "enemy":
					show_enemy_popup(uv.id)


# ═══════════ 자동 진행 (화면 확인용) ═══════════

## 황금 기록의 명령을 사람이 고르듯: 메뉴 0.5초 → 행동 고르기(하이라이트) 0.7초 → 칸·방향 누르기
func _autoplay_tick(delta: float) -> void:
	if mode == "busy" or mode == "over" or _auto_i >= _auto_cmds.size() or _hold > 0:
		return
	_auto_t += delta
	var cmd: Dictionary = _auto_cmds[_auto_i]
	var op: String = cmd["op"]
	if _auto_step == 0 and _auto_t > 0.5:
		_auto_t = 0.0
		_auto_step = 1
		match op:
			"move", "shove", "skill", "wait", "defend", "overwatch", "undo":
				ui_action(op)
			"attack", "heal":
				ui_action("attack")
			"potion", "siege", "climb":
				ui_action("item")
		if op == "undo":
			_auto_next()
	elif _auto_step == 1 and _auto_t > 0.4:
		_auto_t = 0.0
		_auto_step = 2
		if op == "skill":
			ui_pick_skill(int(cmd["idx"]))
			if mode == "busy":
				_auto_next()
		elif op == "potion":
			ui_pick_item("potion", int(cmd["idx"]))
		elif op == "siege" or op == "climb":
			ui_pick_item("siege", int(cmd["idx"]))
	elif _auto_step == 2 and _auto_t > 0.7:
		if op == "wait" or op == "defend" or op == "overwatch":
			ui_pick_face(int(cmd["dx"]), int(cmd["dy"]))
		else:
			ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		_auto_next()


func _auto_next() -> void:
	_auto_i += 1
	_auto_step = 0
	_auto_t = 0.0


# ═══════════ 글자 ═══════════

func _t(key: String, p: Dictionary = {}) -> String:
	return i18n.t(key, p) if i18n != null else key


## 엔진 Fx.float 글자: 번역 키면 번역, 숫자 등은 그대로
func _tr_float(s: String) -> String:
	if i18n != null and s.contains(".") and not s.contains(" ") and i18n.has_key(s):
		return i18n.t(s)
	return s


func _num(v: Variant) -> String:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return Num.fmt(float(v))
	return str(v)


# ═══════════ 소리 (5단계) ═══════════
#  웹 js/battle/audio.js 의 구독(Audio._subscribe) + VFX 구독 안의 Audio 호출 + 행동 코드의 Fx.sfx 를 재생 시점에 맞춰 냄.
#  웹은 사건이 나는 순간 소리를 내므로(타격 연출보다 먼저), 일반 공격에서 같은 순간 웹이 함께 내던 소리(튀김 피해·처치)는
#  본 공격 소리와 함께 냄 (_peek_same_hit). 그 밖의 소리는 Godot 재생 대기열에서 그 사건을 재생할 때.

func _sfx(n: String) -> void:
	if sound != null:
		sound.call("sfx", n)


func _sfx_atk(cls: String) -> void:
	if sound != null:
		sound.call("sfx_atk", cls)


## 전투 끝 (웹 Audio battle_end 구독: 승리·패배 효과음 + bgmStop) — 한 번만
func _end_sound(win: bool) -> void:
	if _end_sfx:
		return
	_end_sfx = true
	_sfx("victory" if win else "defeat")
	if sound != null:
		sound.call("stop_bgm", true)


func _bgm_start() -> void:
	if sound != null and not _over and speed > 0.0:
		sound.call("play_bgm", "battle")


## bus 사건 재생 때 소리 (웹 Audio._subscribe · VFX 구독)
func _play_sound(name: String, d: Dictionary, sn: Variant) -> void:
	if Js.truthy(d.get("_sfx_done")):
		return
	match name:
		"unit_attacked":
			var a: Dictionary = d["attacker"]
			_sfx_atk(str(a.get("cls", "")))
			# 같은 순간의 튀김·처치 소리는 _ev_attacked 가 타격 시점을 안 뒤 (_peek_same_hit)
		"unit_killed":
			_sfx("kill")
		"unit_healed":
			_sfx("heal")
		"wave_spawn":
			# 웹: 첫 배치(initBattle 의 spawnWave)는 Audio.init 전이라 소리 없음
			if typeof(sn) == TYPE_DICTIONARY and int(sn.get("act", 0)) > 0:
				_sfx("wave")
		"battle_end":
			_end_sound(bool(d.get("win", false)))
		"skill_used":
			# 웹 VFX: caster 가 있는 알림(적 AI 의 무장해제·화염구)만 Audio.sfxAtk(caster.cls)
			if typeof(d.get("caster")) == TYPE_DICTIONARY:
				_sfx_atk(str(d["caster"].get("cls", "")))
		"gate_attacked":
			if typeof(d.get("unit")) == TYPE_DICTIONARY:
				_sfx_atk(str(d["unit"].get("cls", "")))
		"gate_destroyed":
			_sfx("kill")
		"turn_start":
			var u: Variant = d.get("unit")
			if typeof(u) == TYPE_DICTIONARY and u.get("team") == "ally" and str(d.get("phase", "player")) == "player":
				_select_sfx = true


## 공격과 같은 묶음의 튀김 피해·처치 소리 (웹이 그 알림을 내는 시점대로):
##  - 튀김 피해(마법사)와 그 처치: 본 공격과 같은 순간 (웹 action.js·ai.js 모두 동기로 알림)
##  - 본 대상 처치: 아군 행동(웹 action.js attack)은 휘두를 때 함께 / 적 AI 공격(ai.js — camera_focus 뒤의 공격)은 맞는 순간 + 0.12초
##    (`left = hd + 120`) / 경계 사격(ai.js _overwatch — 지금 차례가 아닌 유닛의 공격)은 max(0.55, 맞는 순간 + 0.15)초
##  - 반격·지원·창벽·범위(isAoE)·전사 강타의 처치: 같은 순간 (웹도 동기)
##  다음 본 공격·이동·차례 전까지만 봄. 그 밖(지원 공격 뒤의 처치 등)은 대기열에서 그 사건을 재생할 때.
func _peek_same_hit(d: Dictionary, land: float) -> void:
	var aid := int(d["attacker"]["id"])
	var tid := int(d["target"]["id"])
	var delay := 0.0
	var plain := not (Js.truthy(d.get("isCounter")) or Js.truthy(d.get("counter")) or Js.truthy(d.get("isSupport"))
		or Js.truthy(d.get("isSpearwall")) or Js.truthy(d.get("isAoE")))
	if plain:
		if aid != cur_id:
			delay = maxf(0.55, land + 0.15)
		elif view_phase == "enemy" and _ai_focused(tid):
			delay = land + 0.12
	var i := _qi + 1
	while i < _evq.size():
		var it: Array = _evq[i]
		var nm: String = it[1]
		var dd: Dictionary = it[2]
		if it[0] == "fx" and (nm == "attack" or nm == "move"):
			break
		if it[0] == "bus":
			if nm == "turn_start" or nm == "turn_end" or nm == "unit_moved" or nm == "battle_end":
				break
			if nm == "unit_attacked":
				if not Js.truthy(dd.get("isSplash")) or int(dd["attacker"]["id"]) != aid:
					break
				_sfx_atk(str(dd["attacker"].get("cls", "")))
				dd["_sfx_done"] = true
			elif nm == "unit_killed":
				var k: Variant = dd.get("killer")
				if typeof(k) == TYPE_DICTIONARY and int(k["id"]) == aid:
					dd["_sfx_done"] = true
					if delay > 0.0 and int(dd["target"]["id"]) == tid:
						_schedule(delay, func() -> void: _sfx("kill"))
					else:
						_sfx("kill")
		i += 1


## 적 AI 의 일반 공격인가 (웹 AI 공격 함수는 공격 전에 camera_focus 를 냄 — 전사 강타는 내지 않음)
func _ai_focused(tid: int) -> bool:
	var i := _qi - 1
	while i >= 0:
		var it: Array = _evq[i]
		if it[0] == "bus":
			if it[1] == "turn_start":
				return false
			if it[1] == "camera_focus" and typeof(it[2].get("unit")) == TYPE_DICTIONARY and int(it[2]["unit"]["id"]) == tid:
				return true
		i -= 1
	return false


## (5단계 PC) 창 닫기: 실제 세이브 전투면 지금 엔진 상태(입력 대기)를 이어하기로 저장하고 바로 디스크에 씀
##  (입력을 기다릴 때마다 자동 저장하지만, 적 차례 연출 중에 닫으면 그 뒤 진행이 빠지므로 — 엔진은 이미 다음 입력 대기까지 진행해 있음)
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_on_close()


func save_on_close() -> bool:
	if eng == null or not _is_store() or _over or _rc == null or eng.ended or not eng.can_save():
		return false
	_autosave()
	close_saves += 1
	if store != null:
		store.call("flush")
	return true
