extends Node
## Display — 창 모드 · 창 크기 · 위치 (PC). 오토로드 이름 Display.
##
##  저장: Store 키 gd_display (Godot 전용 — 웹에 없음)
##   { "mode": "windowed" | "fullscreen",
##     "w": 1280, "h": 720,      창 모드의 크기 — **논리 크기**(macOS 포인트 = Godot 단위 ÷ max_scale, Windows 는 픽셀 — scale_of 참고)
##     "x": 4928, "y": 790 }     창 모드의 위치 (Godot 화면 좌표, 픽셀) — 없으면 그 모니터 가운데
##   이상한 값은 sanitize(): mode 가 둘 중 하나가 아니면 windowed, 크기는 최소(1024×576)~16384 정수, 위치는 정수가 아니면 지움.
##  전체 화면 = Window.MODE_FULLSCREEN (Windows: 테두리 없는 전체 화면 창, macOS: 시스템 전체 화면 공간).
##  단축키: Alt+Enter (모든 OS) · macOS Cmd+Ctrl+F (시스템 메뉴가 먼저 받으면 macOS 가 바꾸고 여기서는 모드만 맞춤)
##  최소 창 크기: 논리 1024×576 (scale_of 를 곱해 Window.min_size) — 모니터 구성이 바뀌어 단위가 바뀌면 다시 계산
##  여러 모니터: 저장한 위치가 지금 어느 모니터에도 걸치지 않으면(모니터를 뺐음) 창이 있는 모니터 가운데로. 크기가 그 모니터보다 크면 맞는 것으로 줄임
##  처음 실행: 그 모니터 작업 영역의 80% 안에 들어가는 가장 큰 16:9 크기 (최소 1024×576)
##  늘이기는 project.godot 의 canvas_items + expand 그대로 (논리 화면 1280×720 기준)
##  머리 없는 실행(시험)·모바일에서는 창을 건드리지 않음 (active = false) — 계산 함수는 그대로 씀
##  --script 로 도는 시험(play_4a 등 SceneTree 스크립트)은 창을 시험이 정하므로 저장값을 읽지도 쓰지도 않음 (managed = false).
##   그런 시험에서 이 기능 자체를 시험할 때는 manage() 를 부름 (tests/play_pc5.gd)

signal changed

const KEY := "gd_display"
const TITLE := "DEADLINE 15"
const MODES := ["windowed", "fullscreen"]
const MIN_LOGICAL := Vector2i(1024, 576)
const MAX_SIDE := 16384
## 창 모드에서 고를 수 있는 크기 (논리) — 그 모니터 작업 영역에 들어가는 것만 보임
const PRESETS := [Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3200, 1800), Vector2i(3840, 2160)]
const DEFAULT_FILL := 0.8
const SAVE_DELAY := 0.4
## 머리 없는 실행에서 쓰는 가상 모니터 (설정 화면 목록이 늘 같게)
const VIRTUAL_USABLE := Vector2i(1920, 1040)

var active := false
## 저장값 복원·자동 저장·최소 크기를 맡음 (게임 실행 = true, --script 시험 = false 이고 manage() 로 켬)
var managed := false
var cfg: Dictionary = {"mode": "windowed"}
var _store: Node
var _save_t := -1.0
var _applying := 0
var _last_scale := 1.0
## 전체 화면 요청 뒤 확인까지 남은 초 (-1 = 확인 안 함)
## 전체 화면 확인 (fs_step): 요청 뒤 FS_CHECK 초 안에 FS_STABLE 초 동안 '계속' 전체 화면이면 유지, 아니면 창 모드로 되돌림.
##  (macOS 는 앞에 없는 창의 요청 직후 한 프레임만 작업 영역 크기를 알려 주고 원래 크기로 돌아올 수 있음 — 한 프레임 참으로 끝내면 안 됨)
var _fs: Dictionary = {}
const FS_CHECK := 4.0
const FS_STABLE := 0.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_store = get_node_or_null("/root/Store")
	active = DisplayServer.get_name() != "headless" and OS.has_feature("pc") and not OS.has_feature("web")
	cfg = sanitize(_store.call("get_json", KEY, {}) if _store != null else {})
	if not active:
		return
	var w := get_window()
	DisplayServer.window_set_title(TITLE)
	w.title = TITLE
	w.size_changed.connect(_on_size_changed)
	if w.has_signal("dpi_changed"):
		w.dpi_changed.connect(_on_dpi_changed)
	if get_tree().get_script() == null:
		manage()


## 저장값 복원 + 최소 크기 + 바뀌면 저장 (게임 실행은 시작할 때 저절로)
func manage() -> void:
	if not active:
		return
	managed = true
	cfg = sanitize(_store.call("get_json", KEY, {}) if _store != null else {})
	apply_saved()


# ═══════════ 값 ═══════════

static func _int_or(v: Variant, dflt: Variant) -> Variant:
	if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and not is_nan(float(v)) and not is_inf(float(v)) and float(v) == floorf(float(v)) and absf(float(v)) < 1e7:
		return int(v)
	return dflt


static func sanitize(d: Variant) -> Dictionary:
	var o := {"mode": "windowed"}
	if not (d is Dictionary):
		return o
	if typeof(d.get("mode")) == TYPE_STRING and MODES.has(d["mode"]):
		o["mode"] = d["mode"]
	var w: Variant = _int_or(d.get("w"), null)
	var h: Variant = _int_or(d.get("h"), null)
	if w != null and h != null:
		o["w"] = clampi(int(w), MIN_LOGICAL.x, MAX_SIDE)
		o["h"] = clampi(int(h), MIN_LOGICAL.y, MAX_SIDE)
	var x: Variant = _int_or(d.get("x"), null)
	var y: Variant = _int_or(d.get("y"), null)
	if x != null and y != null:
		o["x"] = int(x)
		o["y"] = int(y)
	return o


func mode() -> String:
	return str(cfg["mode"])


func is_fullscreen() -> bool:
	return mode() == "fullscreen"


func _save() -> void:
	if _store != null:
		_store.call("set_json", KEY, cfg.duplicate())
	changed.emit()


# ═══════════ 모니터 ═══════════

func screen_of_window() -> int:
	return DisplayServer.window_get_current_screen() if active else 0


## 논리 크기 1 = Godot 화면 단위 몇 개인가 (모니터와 상관없이 같음 — screen 인자는 호출 모양을 맞추려고 둠)
##  macOS: Godot 은 모든 모니터의 좌표·크기와 창 크기를 '포인트 × 가장 큰 배율(screen_get_max_scale)' 단위로 다룸
##   (platform/macos/display_server_macos.mm — screen_get_size·window_get_size 가 모두 get_screen_max_scale() 을 곱함).
##   그래서 모니터별 배율(screen_get_scale)이 아니라 max_scale 로 나눠야 포인트가 나옴. 예: 레티나(2) + 외부 1080p(1) →
##   두 모니터 모두 2 로 나눔 (외부 1080p 의 1920×1080 포인트가 Godot 에서는 3840×2160).
##  Windows · Linux(X11): Godot 단위 = 실제 픽셀이고 screen_get_scale 은 1 (문서: macOS·Wayland·모바일·웹만 구현) → 논리 = 픽셀.
##   Windows 의 125·150% 배율은 반영하지 않음 (픽셀 기준 — 일반적인 PC 게임과 같음). Linux 는 출시 대상이 아님.
func scale_of(_screen: int) -> float:
	if not active:
		return 1.0
	return units_scale(OS.get_name(), DisplayServer.screen_get_max_scale())


## scale_of 의 계산 (순수 — 시험이 OS 이름·가장 큰 배율을 넣어 봄)
static func units_scale(os_name: String, max_scale: float) -> float:
	return maxf(1.0, max_scale) if os_name == "macOS" else 1.0


## Godot 단위 작업 영역 → 논리 크기 (순수)
static func logical_of(units: Vector2i, scale: float) -> Vector2i:
	return Vector2i(int(units.x / scale), int(units.y / scale))


## 그 모니터 작업 영역 (논리 크기)
func usable_logical(screen: int) -> Vector2i:
	if not active:
		return VIRTUAL_USABLE
	return logical_of(DisplayServer.screen_get_usable_rect(screen).size, scale_of(screen))


## 작업 영역 안에 들어가는 크기 목록 (논리)
static func sizes_fitting(usable: Vector2i) -> Array:
	var out: Array = []
	for p: Vector2i in PRESETS:
		if p.x <= usable.x and p.y <= usable.y:
			out.append(p)
	if out.is_empty():
		out.append(PRESETS[0])
	return out


func available_sizes() -> Array:
	return sizes_fitting(usable_logical(screen_of_window()))


## 처음 실행 크기: 작업 영역의 80% 안에 드는 가장 큰 목록 크기
static func default_size(usable: Vector2i) -> Vector2i:
	var best: Vector2i = PRESETS[0]
	for p: Vector2i in PRESETS:
		if p.x <= usable.x * DEFAULT_FILL and p.y <= usable.y * DEFAULT_FILL:
			best = p
	return best


## 크기를 작업 영역에 맞춤 (넘치면 같은 비율로 줄이고 최소보다 작아지지 않게)
static func fit_size(want: Vector2i, usable: Vector2i) -> Vector2i:
	var s := Vector2(want)
	var k := minf(1.0, minf(float(usable.x) / s.x, float(usable.y) / s.y))
	s *= k
	return Vector2i(maxi(MIN_LOGICAL.x, int(s.x)), maxi(MIN_LOGICAL.y, int(s.y)))


## 저장한 위치 (픽셀) 의 창 윗부분이 어느 모니터 작업 영역에 걸치는지 → 그 모니터 번호, 없으면 -1
func screen_at(pos: Vector2i, size_px: Vector2i) -> int:
	if not active:
		return -1
	var bar := Rect2i(pos + Vector2i(0, 0), Vector2i(size_px.x, 40))
	for s in DisplayServer.get_screen_count():
		var u := DisplayServer.screen_get_usable_rect(s)
		var hit := u.intersection(bar)
		if hit.size.x >= mini(120, size_px.x) and hit.size.y >= 8:
			return s
	return -1


# ═══════════ 적용 ═══════════

func apply_saved() -> void:
	if not active:
		return
	_applying += 1
	var w := get_window()
	var scr := screen_of_window()
	var has_pos := cfg.has("x")
	var want_logical := Vector2i(int(cfg["w"]), int(cfg["h"])) if cfg.has("w") else Vector2i.ZERO
	if has_pos:
		var guess_scale := scale_of(scr)
		var s2 := screen_at(Vector2i(int(cfg["x"]), int(cfg["y"])), Vector2i(Vector2(maxi(want_logical.x, MIN_LOGICAL.x), 40) * guess_scale))
		if s2 >= 0:
			scr = s2
		else:
			has_pos = false   # 그 모니터가 없어짐 → 가운데로
	var usable := usable_logical(scr)
	var logical := fit_size(want_logical, usable) if want_logical != Vector2i.ZERO else default_size(usable)
	var sc := scale_of(scr)
	_last_scale = sc
	if w.mode != Window.MODE_WINDOWED:
		w.mode = Window.MODE_WINDOWED
	_update_min_size(sc, usable)
	var px := Vector2i(Vector2(logical) * sc)
	w.size = px
	if has_pos:
		w.position = _clamp_pos(Vector2i(int(cfg["x"]), int(cfg["y"])), px, scr)
	else:
		w.position = _center_pos(px, scr)
	if is_fullscreen():
		w.mode = Window.MODE_FULLSCREEN
		_start_fs_check()
	_applying -= 1


func _update_min_size(sc: float, usable: Vector2i) -> void:
	var m := Vector2i(mini(MIN_LOGICAL.x, usable.x), mini(MIN_LOGICAL.y, usable.y))
	get_window().min_size = Vector2i(Vector2(m) * sc)


func _center_pos(px: Vector2i, scr: int) -> Vector2i:
	var u := DisplayServer.screen_get_usable_rect(scr)
	return u.position + (u.size - px) / 2


func _clamp_pos(pos: Vector2i, px: Vector2i, scr: int) -> Vector2i:
	var u := DisplayServer.screen_get_usable_rect(scr)
	var x := clampi(pos.x, u.position.x, maxi(u.position.x, u.end.x - px.x))
	var y := clampi(pos.y, u.position.y, maxi(u.position.y, u.end.y - px.y))
	return Vector2i(x, y)


## 창 모드 / 전체 화면
func set_mode(m: String) -> void:
	if not MODES.has(m):
		return
	cfg["mode"] = m
	if active:
		_applying += 1
		var w := get_window()
		if m == "fullscreen":
			_remember_window()
			w.mode = Window.MODE_FULLSCREEN
			_start_fs_check()
		else:
			_fs = {}
			w.mode = Window.MODE_WINDOWED
			_restore_window_rect()
		_applying -= 1
	_save()


func toggle_fullscreen() -> void:
	set_mode("windowed" if is_fullscreen() else "fullscreen")


## 창 크기 (논리) — 창 모드일 때만 바로 바뀜 (전체 화면이면 저장만 해 두고 창 모드로 돌아갈 때 씀)
func set_window_size(logical: Vector2i) -> void:
	var usable := usable_logical(screen_of_window())
	var l := fit_size(logical, usable)
	cfg["w"] = l.x
	cfg["h"] = l.y
	if active and not is_fullscreen():
		_applying += 1
		var w := get_window()
		var sc := scale_of(screen_of_window())
		var px := Vector2i(Vector2(l) * sc)
		var center := w.position + w.size / 2
		w.size = px
		w.position = _clamp_pos(center - px / 2, px, screen_of_window())
		_remember_window()
		_applying -= 1
	_save()


## 지금 창 크기 (논리)
func window_logical_size() -> Vector2i:
	if not active:
		return Vector2i(int(cfg.get("w", 1280)), int(cfg.get("h", 720)))
	var w := get_window()
	var sc := scale_of(screen_of_window())
	return Vector2i(roundi(w.size.x / sc), roundi(w.size.y / sc))


func _remember_window() -> void:
	if not active:
		return
	var w := get_window()
	if w.mode != Window.MODE_WINDOWED:
		return
	var l := window_logical_size()
	cfg["w"] = maxi(l.x, MIN_LOGICAL.x)
	cfg["h"] = maxi(l.y, MIN_LOGICAL.y)
	cfg["x"] = w.position.x
	cfg["y"] = w.position.y


func _restore_window_rect() -> void:
	if not cfg.has("w"):
		return
	var w := get_window()
	var scr := screen_of_window()
	var l := fit_size(Vector2i(int(cfg["w"]), int(cfg["h"])), usable_logical(scr))
	var px := Vector2i(Vector2(l) * scale_of(scr))
	w.size = px
	if cfg.has("x"):
		w.position = _clamp_pos(Vector2i(int(cfg["x"]), int(cfg["y"])), px, scr)


func _on_size_changed() -> void:
	if _applying > 0 or not managed:
		return
	# OS 가 바꾼 모드(macOS 초록 단추·Cmd+Ctrl+F 메뉴)를 따라감
	var w := get_window()
	var now := "fullscreen" if (w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN) else "windowed"
	if now != mode():
		cfg["mode"] = now
		_save()
		if now == "fullscreen":
			_start_fs_check()   # 초록 단추·시스템 메뉴로 들어간 전체 화면도 같은 판정
	_save_t = SAVE_DELAY


## 논리 1 당 단위(scale_of)가 바뀜 — macOS 에서 모니터를 꽂거나 빼 가장 큰 배율이 바뀐 때: 최소 크기를 다시 계산하고, 창 모드면 논리 크기를 그대로.
##  (macOS 는 모니터 사이를 옮겨도 단위가 같아 여기 오지 않음 — 창의 포인트 크기는 macOS 가 그대로 둠)
func _on_dpi_changed() -> void:
	if not managed:
		return
	var scr := screen_of_window()
	var sc := scale_of(scr)
	if sc == _last_scale:
		return
	var w := get_window()
	var logical := Vector2i(roundi(w.size.x / _last_scale), roundi(w.size.y / _last_scale))
	_last_scale = sc
	var usable := usable_logical(scr)
	_update_min_size(sc, usable)
	if w.mode == Window.MODE_WINDOWED and not is_fullscreen():
		_applying += 1
		var px := Vector2i(Vector2(fit_size(logical, usable)) * sc)
		var center := w.position + w.size / 2
		w.size = px
		w.position = _clamp_pos(center - px / 2, px, scr)
		_applying -= 1
		_save_t = SAVE_DELAY


## 정말 전체 화면인가 (모드만이 아니라 창이 그 모니터를 덮음 — macOS 는 앞에 없는 창의 전체 화면 요청을 모드만 바꾸고 하지 않을 수 있음)
func really_fullscreen() -> bool:
	if not active:
		return is_fullscreen()
	var w := get_window()
	if w.mode != Window.MODE_FULLSCREEN and w.mode != Window.MODE_EXCLUSIVE_FULLSCREEN:
		return false
	# macOS 노치 모니터의 전체 화면은 메뉴 막대 줄을 뺀 영역 → 작업 영역 이상이면 전체 화면으로 봄
	var u := DisplayServer.screen_get_usable_rect(screen_of_window()).size
	return w.size.x >= u.x - 2 and w.size.y >= u.y - 2


func _start_fs_check() -> void:
	_fs = {"left": FS_CHECK, "stable": 0.0}


## 전체 화면 판정 한 걸음 (순수 — 시험이 프레임마다 '창이 화면을 덮나'를 넣어 봄): → "keep" · "revert" · "" (아직)
static func fs_step(st: Dictionary, full: bool, delta: float) -> String:
	st["left"] = float(st["left"]) - delta
	st["stable"] = (float(st["stable"]) + delta) if full else 0.0
	if float(st["stable"]) >= FS_STABLE:
		return "keep"
	if float(st["left"]) <= 0.0:
		return "revert"
	return ""


func _process(delta: float) -> void:
	if active and not _fs.is_empty():
		var v := fs_step(_fs, really_fullscreen(), delta)
		if v == "keep" or not is_fullscreen():
			_fs = {}
		elif v == "revert":
			_fs = {}
			# 전체 화면 요청이 무시됨 → 저장값을 실제(창 모드)로 되돌림
			push_warning("Display: 전체 화면으로 바뀌지 않아 창 모드로 되돌림")
			_applying += 1
			get_window().mode = Window.MODE_WINDOWED
			_restore_window_rect()
			_applying -= 1
			cfg["mode"] = "windowed"
			_save()
	if not managed:
		return
	# 모니터 구성이 바뀌어 단위가 바뀜 (dpi_changed 가 없는 OS 대비)
	if scale_of(screen_of_window()) != _last_scale:
		_on_dpi_changed()
	if _save_t >= 0.0:
		_save_t -= delta
		if _save_t < 0.0:
			if get_window().mode == Window.MODE_WINDOWED and not is_fullscreen():
				_remember_window()
			_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and managed:
		if get_window().mode == Window.MODE_WINDOWED and not is_fullscreen():
			_remember_window()
			_save()
		if _store != null:
			_store.call("flush")   # Store 는 오토로드 순서상 먼저 닫기 알림을 받아 이미 썼으므로 한 번 더


func _input(ev: InputEvent) -> void:
	if not active or not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	var k := ev as InputEventKey
	var alt_enter := k.alt_pressed and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER)
	var mac_f := OS.get_name() == "macOS" and k.keycode == KEY_F and k.meta_pressed and k.ctrl_pressed
	if alt_enter or mac_f:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
