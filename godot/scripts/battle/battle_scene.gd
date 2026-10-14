extends Node2D
## 전투 장면 (3a 뼈대) — 화면만. 규칙은 전부 엔진(scripts/logic/battle/battle_engine.gd)이 정하고, 이 장면은
##  ① 엔진 신호(bus_event·fx_event)를 받아 대기열에 쌓았다가 시간에 맞춰 재생하고 (엔진은 기다리지 않음)
##  ② 재생이 끝나고 엔진이 클랜원 입력을 기다리면 메뉴를 띄워 플레이어 조작을 엔진 명령(command)으로 바꾼다.
##  화면 상태는 사건의 사본으로만 바꾸고, 입력을 받을 때(재생이 따라잡은 때)만 엔진 상태로 한 번 맞춘다.
##  시험용 입구(UI 수준): ui_action · ui_pick_skill · ui_pick_item · ui_click_cell · ui_pick_face · ui_cancel
##  (마우스·단축키·메뉴 단추도 모두 이 함수들을 거침 — tests/check_battle_scene.gd 가 황금 기록을 이 입구로 재생)
##  자세한 구조는 scripts/battle/README.md

signal input_ready(unit_id: int)
signal battle_over(result: Dictionary)

const Ctx := preload("res://scripts/logic/ctx.gd")
const BattleEngine := preload("res://scripts/logic/battle/battle_engine.gd")
const JsonExact := preload("res://scripts/core/json_exact.gd")
const Js := preload("res://scripts/logic/js.gd")
const Num := preload("res://scripts/core/num.gd")
const Iso := preload("res://scripts/battle/iso.gd")
const SpriteDB := preload("res://scripts/battle/sprite_db.gd")
const BattleMap := preload("res://scripts/battle/battle_map.gd")
const UnitView := preload("res://scripts/battle/unit_view.gd")
const FxLayer := preload("res://scripts/battle/fx_layer.gd")
const BattleUI := preload("res://scripts/battle/battle_ui.gd")

const BOOT_SCENE := "res://scenes/boot.tscn"
const GOLDEN := "res://tests/golden/"
## 디버그 기본 세이브 (Store 에 파티가 없을 때): 황금 기록의 가짜 세이브
const DEBUG_GOLDEN := "balanced_s05"
## 엔진 신호 중 그 순간의 전장 전체를 사본으로 남길 것 (재생 중 화면을 엔진의 그 시점과 맞추는 기준점)
const SNAP_BUS := ["turn_start", "turn_end", "unit_added", "wave_spawn", "round_end"]
const SNAP_FX := ["redraw_units", "redraw_terrain", "chest_open"]
const SPEEDS := [1.0, 2.0, 4.0]
## command() 실패 이유 → 안내 (3a 임시 문구 — 번역 키는 3b HUD 때)
const FAIL_TEXT := {"move_failed": "갈 수 없는 칸", "attack_failed": "대상이 아님", "no_resource": "자원 부족", "skill_failed": "스킬을 쓸 수 없음",
	"cannot_act": "행동할 수 없음", "item_failed": "아이템을 쓸 수 없음", "cannot_undo": "되돌릴 수 없음", "not_waiting": "입력 대기 아님",
	"bad_op": "잘못된 명령", "wrong_unit": "다른 유닛 차례", "bad_dir": "잘못된 방향", "bad_skill": "잘못된 스킬", "bad_item": "잘못된 아이템", "bad_cell": "잘못된 칸"}

## 런처(boot.gd)가 넣고 장면이 _ready 에서 꺼내 씀
##  { save, stage, practice, inject, maxRounds, seed, source("store"|"debug"|"test"), record, speed(0 = 연출 없이 즉시), autoplay(황금 이름) }
static var pending: Dictionary = {}

var cfg: Dictionary = {}
var D: Dictionary
var eng: BattleEngine
var iso: Iso
var sdb: SpriteDB
var map: BattleMap
var fx: FxLayer
var ui: BattleUI
var cam: Camera2D
var world: Node2D
var unit_layer: Node2D
var i18n: Node

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

## 화면 상태
var units: Dictionary = {}    # id → UnitView
var view_ter: Array = []
var view_chests: Array = []
var view_safe: Array = []
var view_turn := 1
var view_phase := "player"
var view_eq := 0
var cur_id := -1
var show_threat := false

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
	var db: Node = _svc("DataDB")
	if db == null:
		push_error("battle_scene: DataDB 오토로드가 없습니다")
		return
	D = Ctx.globals_from_db(db)
	cfg = pending.duplicate(true) if not pending.is_empty() else _cfg_from_cmdline()
	pending = {}
	speed = float(cfg.get("speed", 1.0))
	sdb = SpriteDB.new(D)
	eng = BattleEngine.new(D, int(cfg.get("seed", 1)))
	eng.record_enabled = bool(cfg.get("record", false))
	eng.bus_event.connect(_on_bus)
	eng.fx_event.connect(_on_fx)
	eng.start({"save": cfg.get("save", {}), "stage": cfg["stage"], "practice": bool(cfg.get("practice", false)),
		"inject": cfg.get("inject", []), "maxRounds": int(cfg.get("maxRounds", 0))})
	_listening = true
	_build_world()
	var autoplay := str(cfg.get("autoplay", ""))
	if autoplay != "":
		var g: Variant = _read_golden(autoplay)
		if typeof(g) == TYPE_DICTIONARY:
			for e: Dictionary in g["events"]:
				if e["ev"] == "cmd":
					_auto_cmds.append(e)
	if int(cfg.get("cam_dir", 0)) != 0:
		rotate_cam(int(cfg["cam_dir"]))
	eng.begin()
	_eng_status = eng.run()


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
	if auto:
		c["autoplay"] = name
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
	fx.speed = speed
	world.add_child(fx)
	view_chests = _chest_list()
	view_safe = (S["safeZones"] as Array).duplicate()
	map.chests = view_chests
	map.rebuild()
	map.set_safe(view_safe)
	for u: Dictionary in S["units"]:
		if float(u["hp"]) > 0.0:
			_add_unit(_unit_snap(u), false)
	cam = Camera2D.new()
	cam.name = "Camera"
	add_child(cam)
	cam.position = iso.world_size() / 2.0 + Vector2(0, -10)
	cam.make_current()
	ui = BattleUI.new()
	ui.name = "UI"
	add_child(ui)
	ui.setup(i18n)
	ui.action_pressed.connect(func(op: String) -> void: ui_action(op))
	ui.skill_pressed.connect(func(idx: int) -> void: ui_pick_skill(idx))
	ui.item_pressed.connect(func(k: String, idx: int) -> void: ui_pick_item(k, idx))
	ui.cancel_pressed.connect(func() -> void: ui_cancel())
	ui.rotate_pressed.connect(rotate_cam)
	ui.threat_pressed.connect(toggle_threat)
	ui.speed_pressed.connect(_cycle_speed)
	ui.back_pressed.connect(_go_back)
	ui.set_cam("%s %s" % [str(D["CARR"][iso.cam_dir]), str(D["CLAB"][iso.cam_dir])])
	ui.set_speed_label("%dx" % int(SPEEDS[_speed_i]))
	view_turn = int(S["turn"])
	view_eq = (S["eQ"] as Array).size()
	_update_top()
	_refresh_fog_view()
	_refresh_loops()
	_refresh_fade()


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


## 화면용 유닛 사본 = 엔진 unit_view + 그림·상태 표시에 필요한 몇 값 (읽기만)
func _unit_snap(u: Dictionary) -> Dictionary:
	var v: Dictionary = eng.unit_view(u)
	v["gender"] = str(u.get("gender", "m")) if u.get("gender") != null else "m"
	v["ha"] = Js.truthy(u.get("ha"))
	v["stunned"] = Js.num(u.get("stunned"))
	v["frozen"] = Js.num(u.get("frozen"))
	if u.has("summonTurns"):
		v["summonTurns"] = u["summonTurns"]
	return v


## 엔진의 지금 전장 전체 사본 (신호를 받은 그 순간 — 엔진은 아직 진행 중)
func _snap_engine() -> Dictionary:
	var us: Array = []
	for u: Dictionary in eng.S["units"]:
		if float(u["hp"]) > 0.0:
			us.append(_unit_snap(u))
	return {"units": us, "ter": Js.deep(eng.S["ter"]), "chests": _chest_list(), "safe": (eng.S["safeZones"] as Array).duplicate(),
		"turn": int(eng.S["turn"]), "eq": (eng.S["eQ"] as Array).size()}


func _add_unit(v: Dictionary, spawn: bool) -> UnitView:
	var uv := UnitView.new()
	uv.name = "U%d" % int(v["id"])
	unit_layer.add_child(uv)
	uv.setup(iso, sdb, v, speed)
	if spawn:
		uv.spawn_anim()
	units[int(v["id"])] = uv
	return uv


# ═══════════ 엔진 신호 → 대기열 ═══════════

func _on_bus(name: String, data: Dictionary) -> void:
	if not _listening:
		return
	_evq.append(["bus", name, data, _snap_engine() if SNAP_BUS.has(name) else null])


func _on_fx(kind: String, data: Dictionary) -> void:
	if not _listening:
		return
	_evq.append(["fx", kind, data, _snap_engine() if SNAP_FX.has(kind) else null])


# ═══════════ 재생 ═══════════

func _process(delta: float) -> void:
	if eng == null:
		return
	var instant := speed <= 0.0
	var dt := delta * (1.0 if instant else speed)
	_clock += dt
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
		while _qi < _evq.size():
			_play(_evq[_qi])
			_qi += 1
		_wait = 0.0
	else:
		_wait -= dt
		while _wait <= 0.0 and _qi < _evq.size():
			_wait += _play(_evq[_qi])
			_qi += 1
	if _qi >= _evq.size() and _qi > 0:
		_evq.clear()
		_qi = 0
	if mode == "busy" and _qi >= _evq.size() and _wait <= 0.0 and (_sched.is_empty() or instant):
		_on_drained()
	if not _auto_cmds.is_empty():
		_autoplay_tick(delta)


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
	match name:
		"turn_start":
			_apply_snap(sn)
			var u: Dictionary = d["unit"]
			_set_cur(int(u["id"]))
			view_phase = str(d.get("phase", "player"))
			_update_top()
			_refresh_loops()
			return 0.27 if view_phase == "enemy" else 0.1
		"turn_end", "round_end", "unit_added":
			_apply_snap(sn)
			return 0.0
		"wave_spawn":
			_apply_snap(sn)
			return 0.6
		"wave_announce":
			ui.show_banner(_t("messages.wave_info", {"count": d.get("remaining", 0)}))
			return 0.3
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
			fx.burst(_body(t), {"count": 14, "colors": ["#44ff88", "#88ffaa", "#aaffcc", "#ffffff"], "shape": "circle", "speed": 1.5, "spread": 14, "decay": 0.018, "size": 3, "vy": -1.5, "gravity": -0.02})
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
				fx.burst(_body(d["unit"]), {"count": 8, "colors": ["#22c55e", "#4ade80", "#ffffff"], "shape": "star", "speed": 1.5, "spread": 12, "decay": 0.025, "size": 2.5, "vy": -1})
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
			if str(d.get("type")) == "bomb" and typeof(d.get("target")) == TYPE_DICTIONARY:
				var tg: Dictionary = d["target"]
				fx.burst(iso.top_center(int(tg["x"]), int(tg["y"])), {"count": 30, "colors": ["#ff8844", "#ff6600", "#ffff44", "#ffffff"], "shape": "spark", "speed": 4, "spread": 16, "decay": 0.02, "size": 3.5})
			return 0.35
		"gate_attacked":
			fx.float_text(int(d["x"]), int(d["y"]), _t("messages.gate_hit"), "damage")
			fx.burst(iso.top_center(int(d["x"]), int(d["y"])), {"count": 12, "colors": ["#aa8844", "#ffcc66", "#ffffff"], "shape": "spark", "speed": 2, "spread": 12, "decay": 0.025, "size": 3})
			return 0.3
		"gate_destroyed":
			fx.float_text(int(d["x"]), int(d["y"]), _t("messages.gate_destroyed"), "damage")
			return 0.3
		"breach":
			var bu: Dictionary = d["unit"]
			fx.float_text(int(bu["x"]), int(bu["y"]), "%s %s/%s" % [_t("messages.breach"), _num(d.get("count", 0)), _num(d.get("limit", 0))], "damage")
			return 0.3
		"evasion", "fury_triggered", "retreat", "root_blocked", "shield_active":
			var eu: Dictionary = d["unit"]
			var key: String = {"evasion": "messages.evasion", "fury_triggered": "messages.fury_buff", "retreat": "messages.retreat", "root_blocked": "messages.rooted", "shield_active": "battle.defend"}[name]
			fx.float_text(int(eu["x"]), int(eu["y"]), _t(key), "debuff" if name == "root_blocked" else ("damage" if name == "retreat" else "heal"))
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
			if av != null and not av.dying:
				var h := av.play_once("attack")
				_motion[int(d["a"])] = _clock + h
			return 0.0
		"float":
			# 선택 안내(messages.select_*)는 아래 안내 줄로 보여 주므로 떠오르는 글자로는 안 띄움
			if not str(d["text"]).begins_with("messages.select_"):
				fx.float_text(int(d["x"]), int(d["y"]), _tr_float(str(d["text"])), "info")
			return 0.0
		"chest_open":
			_apply_snap(sn)
			fx.float_text(int(d["x"]), int(d["y"]), _t("chest." + str(d.get("kind", ""))), "heal")
			fx.burst(iso.foot(int(d["x"]), int(d["y"])) + Vector2(0, -24), {"count": 14, "colors": ["#fde68a", "#facc15", "#ffffff"], "shape": "star", "speed": 2.5, "spread": 10, "decay": 0.03, "size": 3})
			return 0.25
		"redraw_units", "redraw_terrain":
			_apply_snap(sn)
			return 0.0
	return 0.0


func _ev_moved(d: Dictionary) -> float:
	var u: Dictionary = d["unit"]
	var uv: UnitView = units.get(int(u["id"]))
	if uv == null:
		return 0.0
	var to: Dictionary = d["to"]
	if int(uv.d["x"]) != int(to["x"]) or int(uv.d["y"]) != int(to["y"]):
		uv.move_to(int(to["x"]), int(to["y"]))
		_schedule(0.34, _after_move)
	uv.apply_stats(u)
	return 0.36


func _after_move() -> void:
	_refresh_fog_view()
	_refresh_fade()
	_refresh_loops()


## 공격: 공격자 동작 → 타격 프레임에 대상 흔들림·피격 동작·피해 숫자 (웹 VFX unit_attacked 구독)
func _ev_attacked(d: Dictionary) -> float:
	var a: Dictionary = d["attacker"]
	var t: Dictionary = d["target"]
	var av: UnitView = units.get(int(a["id"]))
	var tid := int(t["id"])
	var hit_in := 0.1
	if av != null:
		av.apply_stats(a)
	if not Js.truthy(d.get("isSplash")):
		var aid := int(a["id"])
		if _motion.has(aid) and float(_motion[aid]) >= _clock - 0.05:
			hit_in = maxf(0.0, float(_motion[aid]) - _clock)
			_motion.erase(aid)
		elif av != null and not av.dying:
			hit_in = av.play_once("attack")
	_hit_at[tid] = _clock + hit_in
	var dmg := _num(d.get("damage", 0))
	_schedule(hit_in, func() -> void:
		var tv: UnitView = units.get(tid)
		if tv != null:
			tv.apply_stats(t)
			tv.shake()
			if float(t["hp"]) > 0.0:
				tv.play_once("hit")
		fx.float_text(int(t["x"]), int(t["y"]), "-" + dmg, "damage")
		fx.burst(_body(t), {"count": 8, "colors": ["#ffffff", "#ffcc44", "#ff8800"], "shape": "spark", "speed": 3, "spread": 8, "decay": 0.035, "size": 2.5}))
	if Js.truthy(d.get("counter")):
		fx.float_text(int(a["x"]), int(a["y"]), _t("messages.brawler_counter"), "heal")
	if Js.truthy(d.get("isSupport")):
		fx.float_text(int(a["x"]), int(a["y"]), _t("battle.support_hit"), "tactic")
	return hit_in + 0.3


func _ev_killed(d: Dictionary) -> float:
	var t: Dictionary = d["target"]
	var tid := int(t["id"])
	var tv: UnitView = units.get(tid)
	if tv == null:
		return 0.0
	tv.set_meta("doomed", true)
	var at := maxf(0.0, float(_hit_at.get(tid, 0.0)) - _clock) + 0.05
	_schedule(at, func() -> void:
		if is_instance_valid(tv):
			fx.burst(tv.position + Vector2(0, -24), {"count": 25, "colors": (["#3b82f6", "#60a5fa", "#93c5fd", "#bfdbfe"] if tv.d.get("team") == "ally" else ["#ef4444", "#f87171", "#fca5a5", "#fecaca"]), "shape": "diamond", "speed": 1.5, "spread": 16, "decay": 0.012, "size": 3, "gravity": 0.03, "vy": -0.5})
			tv.die()
		units.erase(tid)
		_refresh_fog_view()
		_refresh_loops()
		_update_top())
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
	if sn["chests"] != view_chests:
		view_chests = sn["chests"]
		map.set_chests(view_chests)
	if sn["safe"] != view_safe:
		view_safe = sn["safe"]
		map.set_safe(view_safe)
	view_turn = int(sn["turn"])
	view_eq = int(sn["eq"])
	_update_top()
	_refresh_fog_view()
	_refresh_fade()


func _stats(v: Variant) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		return
	var uv: UnitView = units.get(int(v["id"]))
	if uv != null and not uv.has_meta("doomed"):
		uv.apply_stats(v)


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


func _update_top() -> void:
	var n := view_eq
	for uv: UnitView in units.values():
		if uv.d.get("team") == "enemy" and not uv.has_meta("doomed"):
			n += 1
	ui.set_turn(view_turn, view_phase, n)


# ═══════════ 입력 대기 ═══════════

## 재생이 엔진을 따라잡음 → 입력 대기면 메뉴, 끝났으면 결과
func _on_drained() -> void:
	if _over:
		return
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
	_update_top()
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
	ui.show_hint(fail_hint)   # 방금 명령이 진짜 실패했으면 메뉴로 돌아와도 안내를 남김 (다음 조작 때 지움)
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


func _show_main_menu(u: Dictionary) -> void:
	var acts: Dictionary = {}
	for a: Dictionary in eng.q.actions(u):
		acts[a["op"]] = a
	var acted := Js.truthy(u.get("ha"))
	var items: Array = []
	if acts["move"]["ok"]:
		items.append({"op": "move", "icon": "»", "label": _t("battle.move"), "sub": _t("battle.am_move_sub", {"n": u["move"]}), "key": "M", "ac": "move"})
	var healer: bool = u.get("role") == "healer"
	var at: Dictionary = eng.q.attack_targets(u)
	var n_t: int = (at["attack"] as Array).size() + ((at["heal"] as Array).size() if healer else 0)
	if not acted and n_t > 0:
		items.append({"op": "attack", "icon": "✚" if healer else "⚔", "label": _t("battle.attack_heal" if healer else "battle.attack"), "sub": _t("battle.am_targets", {"n": n_t}), "key": "A", "ac": "attack"})
	var actives := 0
	var usable := 0
	for st: Dictionary in eng.q.skill_status(u):
		if not st["passive"]:
			actives += 1
			if st["usable"]:
				usable += 1
	if not acted and actives > 0:
		items.append({"op": "skill", "icon": "✦", "label": _t("battle.skill"), "sub": _t("battle.am_usable", {"n": usable, "total": actives}), "key": "S", "ac": "skill", "warn": usable == 0})
	var n_items := 0
	for p: Dictionary in eng.S["_battlePotions"]:
		n_items += int(Js.num(p.get("quantity", 1))) if p.get("quantity") != null else 1
	for s: Dictionary in eng.S["_siegeItems"]:
		n_items += int(Js.num(s.get("quantity", 1))) if s.get("quantity") != null else 1
	if not acted and n_items > 0:
		items.append({"op": "item", "icon": "◆", "label": _t("battle.item"), "sub": _t("battle.am_count", {"n": n_items}), "key": "I", "ac": "item"})
	if not acted:
		if acts["shove"]["ok"]:
			items.append({"op": "shove", "icon": "⇥", "label": _t("battle.shove"), "sub": _t("battle.am_shove_sub", {"n": eng.q.shove_cells(u).size()}), "key": "P", "ac": "wait"})
		items.append({"op": "defend", "icon": "▣", "label": _t("battle.defend"), "sub": _t("battle.am_defend_sub"), "key": "D", "ac": "wait"})
		items.append({"op": "overwatch", "icon": "◉", "label": _t("battle.overwatch"), "sub": _t("battle.am_overwatch_sub"), "key": "O", "ac": "wait"})
	items.append({"op": "wait", "icon": "Ⅱ", "label": _t("battle.wait"), "sub": _t("battle.am_wait_sub"), "key": "W", "ac": "wait"})
	if acts["undo"]["ok"]:
		items.append({"op": "undo", "icon": "↩", "label": _t("battle.undo_move"), "key": "Esc", "ac": "cancel"})
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
		items.append({"op": "skill_pick", "idx": int(st["idx"]), "icon": "✦", "label": _t("skills." + str(st["id"])), "sub": reason if reason != "" else cost,
			"warn": reason != "", "enabled": bool(st["usable"]), "key": str(n), "ac": "skill"})
	items.append({"op": "cancel", "icon": "↩", "label": _t("battle.cancel"), "key": "Esc", "ac": "cancel"})
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
			items.append({"op": "item_pick", "kind": grp[0], "idx": int(seen[id2]["idx"]), "icon": "◆", "label": _t(str(grp[3]) + id2), "sub": "×%d" % int(seen[id2]["count"]), "key": str(n), "ac": "item"})
	items.append({"op": "cancel", "icon": "↩", "label": _t("battle.cancel"), "key": "Esc", "ac": "cancel"})
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
			badges.append({"pos": uv.position + Vector2(22, -60), "n": cnt[id]})
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


## 공격 예상 (웹 rPreview): 공격 가능한 적 머리 위 피해·처치·보조 정보
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
		var p: Dictionary = eng.q.preview_attack(u, v)
		var pos := iso.foot(int(v["x"]), int(v["y"])) + Vector2(0, -62)
		if p["intercept"] != null:
			list.append({"pos": pos, "main": "-" + _num(p["intercept_dmg"]), "sub": _t("battle.preview_intercept"), "kind": "block"})
			continue
		var sub: Array = []
		if float(p["pct"]) != 0.0:
			var tags: Array = []
			for tg: String in p["tags"]:
				tags.append(_t("battle.tactic_" + tg))
			sub.append("%s +%s%%" % ["·".join(tags), _num(p["pct"])])
		if p["evade"]:
			sub.append(_t("battle.tactic_evade", {"n": p["evade"]}))
		if p["support"]:
			sub.append(_t("battle.preview_support", {"n": p["support"]}))
		if float(p["counter"]) > 0.0:
			sub.append(_t("battle.preview_counter", {"n": p["counter"]}))
		list.append({"pos": pos, "main": "-" + _num(p["dmg"]), "sub": "  ".join(sub), "kind": "kill" if p["kill"] else "dmg"})
	fx.previews = list
	fx.queue_redraw()


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
	var after_u: Variant = eng.awaiting_unit()
	var really_failed: bool = not last_result["ok"] and after_u != null and int(after_u["id"]) == int(u["id"]) and _act_state(after_u) == before
	_clear_target()
	_hide_intents()
	map.set_threat([])
	for uv: UnitView in units.values():
		uv.face_hidden = false
		uv.selected = false
	ui.hide_menu()
	fail_hint = str(FAIL_TEXT.get(str(last_result["reason"]), last_result["reason"])) if really_failed else ""
	ui.show_hint(fail_hint)
	mode = "busy"
	_eng_status = eng.run()


## 행동 여부를 가르는 값 (위치·행동·이동·자원)
func _act_state(u: Dictionary) -> Array:
	return [int(u["x"]), int(u["y"]), Js.truthy(u.get("ha")), Js.truthy(u.get("hm")), float(u.get("res", 0.0)), int(eng.S["actCount"])]


# ═══════════ 끝 ═══════════

func _finish() -> void:
	_over = true
	mode = "over"
	result = eng.finish(_eng_status)
	ui.hide_menu()
	_hide_intents()
	map.set_hl({})
	# 실제 세이브로 시작한 전투면 결과(골드·경험치·보상)를 Store 에 되돌려 씀
	if str(cfg.get("source", "")) == "store":
		var store: Node = _svc("Store")
		if store != null:
			for k: String in eng.c.store.keys():
				store.call("set_json", k, eng.c.store.get_json(k))
	var win: bool = result.get("result") == "win"
	var lines: Array = []
	lines.append("%s · %s" % [_t("battle.turn_n", {"n": result.get("rounds", 0)}), str(result.get("reason", result.get("result", "")))])
	var rw: Variant = result.get("rewards")
	if typeof(rw) == TYPE_DICTIONARY:
		lines.append("%s +%s" % [_t("common.gold"), _num(rw.get("gold", 0))])
		var ex: Array = rw.get("exp", [])
		if not ex.is_empty():
			var tot := 0.0
			for e: Dictionary in ex:
				tot += float(e.get("exp", 0))
			lines.append("%s +%s (%d)" % [_t("common.exp"), _num(tot), ex.size()])
	ui.show_result(win, lines)
	battle_over.emit(result)


func _go_back() -> void:
	get_tree().change_scene_to_file(BOOT_SCENE)


func _exit_tree() -> void:
	# 엔진 내부 순환 참조 정리 (결과·기록은 이미 꺼내 둠)
	if eng != null:
		if eng.bus_event.is_connected(_on_bus):
			eng.bus_event.disconnect(_on_bus)
		if eng.fx_event.is_connected(_on_fx):
			eng.fx_event.disconnect(_on_fx)
		eng.dispose()


# ═══════════ 카메라 ═══════════

func rotate_cam(d: int) -> void:
	var center := cam.get_screen_center_position()
	var g := iso.screen_to_grid_f(center)
	iso.cam_dir = ((iso.cam_dir + d) % 4 + 4) % 4
	map.rebuild()
	map.set_safe(view_safe)
	for uv: UnitView in units.values():
		uv.refresh_camera()
	cam.position = iso.grid_f_to_screen(g)
	cam.reset_smoothing()
	_refresh_fog_view()
	_refresh_fade()
	ui.set_cam("%s %s" % [str(D["CARR"][iso.cam_dir]), str(D["CLAB"][iso.cam_dir])])
	# 보이던 하이라이트·메뉴를 새 방향으로
	var hl := map.hl
	map.set_hl(hl)
	if show_threat and mode != "busy":
		map.set_threat(eng.q.threat_cells())
	match mode:
		"menu":
			_show_intents()
			_show_main_menu(eng.awaiting_unit())
		"face":
			_show_intents()
			_enter_face(face_op, eng.awaiting_unit())
		"target":
			_show_intents()
			if target_op == "attack":
				_show_previews(eng.awaiting_unit(), eng.q.attack_targets(eng.awaiting_unit()))
		"skills":
			_show_intents()
			_show_skill_menu(eng.awaiting_unit())
		"items":
			_show_intents()
			_show_item_menu(eng.awaiting_unit())


func toggle_threat() -> void:
	show_threat = not show_threat
	ui.set_threat(show_threat)
	if show_threat and mode != "busy" and mode != "over":
		map.set_threat(eng.q.threat_cells())
	else:
		map.set_threat([])


func _cycle_speed() -> void:
	_speed_i = (_speed_i + 1) % SPEEDS.size()
	speed = SPEEDS[_speed_i]
	fx.speed = speed
	for uv: UnitView in units.values():
		uv.speed = speed
	ui.set_speed_label("%dx" % int(speed))


func _focus(p: Vector2) -> void:
	if speed <= 0.0:
		return
	var vs := get_viewport().get_visible_rect().size / cam.zoom
	var c := cam.get_screen_center_position()
	if absf(p.x - c.x) > vs.x * 0.35 or absf(p.y - c.y) > vs.y * 0.35:
		var tw := create_tween()
		tw.tween_property(cam, "position", p, 0.35 / speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _clamp_cam() -> void:
	var ws := iso.world_size()
	cam.position = cam.position.clamp(Vector2(-100, -100), ws + Vector2(100, 100))


# ═══════════ 마우스·키보드 ═══════════

func _unhandled_input(ev: InputEvent) -> void:
	if eng == null:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
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
	elif ev is InputEventKey and ev.pressed and not ev.echo:
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
		KEY_ESCAPE:
			ui_cancel()
			return
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
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


# ═══════════ 자동 진행 (화면 확인용) ═══════════

## 황금 기록의 명령을 사람이 고르듯: 메뉴 0.5초 → 행동 고르기(하이라이트) 0.7초 → 칸·방향 누르기
func _autoplay_tick(delta: float) -> void:
	if mode == "busy" or mode == "over" or _auto_i >= _auto_cmds.size():
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
