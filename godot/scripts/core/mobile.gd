extends Node
## Mobile — (6a) 휴대폰·태블릿: 화면 배율 · 안전 영역(노치·홈 바) · 뒤로 가기 단추 · 길게 누르기(툴팁) · 터치 문턱. 오토로드 이름 Mobile.
##  PC 에서는 아무것도 하지 않음 (배율 1 · 여백 0 · 알림 무시) — Platform.is_mobile() 이 거짓이면 늘 그대로.
##
##  배율 (content_scale_factor)
##   늘이기는 PC 와 같은 canvas_items + expand (기준 1280×720). 휴대폰은 화면이 작아(가로로 든 높이 약 65~72mm) 기준 그대로면
##   글자 14 가 약 1.3mm 가 되므로, 논리 1단위가 실제 TARGET_UNIT_MM(0.136mm)가 되도록 root.content_scale_factor 를 키움:
##     기본 단위(mm) = 25.4 / dpi × min(화면 가로/1280, 화면 세로/720)     (배율 1 일 때 논리 1단위의 실제 길이)
##     f = clamp(TARGET_UNIT_MM / 기본 단위, 1, min(MAX_FACTOR, 기본 논리 세로/MIN_LOGICAL.y, 기본 논리 가로/MIN_LOGICAL.x))
##   → 글자 14 ≈ 1.9mm (12pt 상당), 단추 51 ≈ 6.9mm (44pt). 논리 화면은 1024×480 보다 작아지지 않음 (작은 휴대폰은 그만큼 덜 키움).
##   예: 2400×1080 420dpi → 1.50 (논리 1067×480) · 2778×1284 458dpi → 1.375 (1133×524) · 1600×720 270dpi → 1.45 (1106×498) ·
##       2732×2048 264dpi 태블릿 → 1.0 (1280×960 — 이미 충분히 큼)
##  안전 영역: DisplayServer.get_display_safe_area() (화면 픽셀) → 논리 단위 여백 safe_margins() = {left, top, right, bottom}.
##   바깥 화면(screen_base)은 윗줄·본문·아래 탭을, 전투는 HUD 를, 창(모달)은 가운데 상자를 이 여백 안에 둠 (바탕색·맵은 화면 끝까지).
##  뒤로 가기 (안드로이드 단추·제스처 = NOTIFICATION_WM_GO_BACK_REQUEST, project.godot quit_on_go_back=false):
##   system_back() → Router.request_back(true) — 바깥 화면은 Esc 와 같은 on_back(), 로비(뒤로 갈 곳 없음)는 종료 확인,
##   전투는 battle_scene.on_system_back() (Esc 와 같은 취소 → 취소할 것이 없으면 전투 설정 창).
##  길게 누르기: 단추 등 GUI 부품을 LONG_PRESS 초 누르고 있으면 그 부품의 tooltip_text 를 손가락 옆에 보이고(호버 툴팁 대신),
##   손을 떼도 그 단추는 눌리지 않음. 전투 맵은 battle_scene 이 따로 (칸·유닛 정보).
##  백그라운드: 저장(Store) · 전투 이어하기 저장(battle_scene) · 소리 끄기(Sound) 는 각자 NOTIFICATION_APPLICATION_PAUSED 에서.
##  개발용 흉내: Platform.emulate_mobile(true, 기기) 또는 명령줄 -- --mobile [pixel8|iphone|ipad|low] (디버그만) → DEVICES 의 dpi·안전 영역을 씀.

signal layout_changed

const BASE := Vector2(1280, 720)
const TARGET_UNIT_MM := 0.136
const MAX_FACTOR := 1.6
const MIN_LOGICAL := Vector2(1024, 480)
## dpi 를 모를 때 (0 이하) 휴대폰으로 봄
const FALLBACK_DPI := 400.0
## 터치 문턱 (실제 mm): 이만큼 움직이면 탭이 아니라 끌기 · 길게 누르기 취소
const TOUCH_SLOP_MM := 2.0
## 마우스 끌기 문턱 (논리 px — PC 그대로)
const MOUSE_SLOP := 6.0
const LONG_PRESS := 0.5
## 터치 대상 최소 (44pt ≈ 6.9mm) · 본문 글자 최소 (12pt ≈ 1.87mm) — 시험 기준
const MIN_TARGET_MM := 44.0 / 163.0 * 25.4   # 44pt (iOS 1pt = 1/163in) ≈ 6.86mm
const MIN_TEXT_MM := 12.0 / 163.0 * 25.4   # 12pt ≈ 1.87mm
## 흉내 기기: 화면 픽셀(가로로 든 것) · dpi · 안전 영역 여백(픽셀, 가로로 들었을 때 왼·위·오·아래)
const DEVICES := {
	"pixel8": {"size": Vector2i(2400, 1080), "dpi": 420.0, "inset": [136, 0, 0, 0], "name": "Pixel 8 (20:9)"},
	"iphone": {"size": Vector2i(2778, 1284), "dpi": 458.0, "inset": [141, 0, 141, 63], "name": "iPhone Pro Max (19.5:9)"},
	"ipad": {"size": Vector2i(2732, 2048), "dpi": 264.0, "inset": [0, 0, 0, 40], "name": "iPad Pro 12.9 (4:3)"},
	"low": {"size": Vector2i(1600, 720), "dpi": 270.0, "inset": [80, 0, 0, 0], "name": "1600×720 (20:9)"},
}

var factor := 1.0
## (6a QA) 안전 영역·화면 방향 감시: 가로 ↔ 역가로(180° 회전)는 창 크기가 같아 size_changed 가 오지 않으므로 POLL_SEC 마다 비교, 달라졌을 때만 apply()
const POLL_SEC := 0.5
var _poll_t := 0.0
var _poll_sig := ""
## 시험: 안전 영역 여백(화면 픽셀 [왼, 위, 오, 아래])을 직접 주입 (비어 있으면 기기·OS 값). 흉내에서도 이 값이 앞섬
var inset_override: Array = []
var polls := 0   # 시험·확인: 다시 계산한 횟수 (apply 가 바뀐 값을 발견한 횟수)
var _margins := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
var _pf: Node
## 시험·확인: 받은 뒤로 가기 수 · 길게 누르기 툴팁 수
var back_count := 0
var long_press_count := 0
## 길게 누르기
var _lp := {}            # {pos, t, fired, ctl}
var _tip_layer: CanvasLayer
var _tip: PanelContainer
var _tip_lbl: Label
var _tip_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pf = get_node_or_null("/root/Platform")
	get_tree().root.size_changed.connect(apply)
	get_tree().node_added.connect(_on_node_added)
	apply.call_deferred()
	# 개발용 흉내 실행(창 있음, --script 시험이 아님): 창을 그 기기 비율로 (모니터 작업 영역의 85% 안)
	if _pf != null and str(_pf.get("mobile_emu")) != "" and DisplayServer.get_name() != "headless" and get_tree().get_script() == null:
		_emu_window.call_deferred()


func _emu_window() -> void:
	var dv := _device()
	var px := Vector2(dv["size"])
	var scr := DisplayServer.window_get_current_screen()
	var usable := Vector2(DisplayServer.screen_get_usable_rect(scr).size) * 0.85
	var k := minf(1.0, minf(usable.x / px.x, usable.y / px.y))
	var w := get_window()
	w.mode = Window.MODE_WINDOWED
	w.min_size = Vector2i.ZERO
	w.size = Vector2i(px * k)
	w.move_to_center()
	w.title = "DEADLINE 15 — mobile: %s" % str(dv["name"])


func _mobile() -> bool:
	return _pf != null and bool(_pf.call("is_mobile"))


func _device() -> Dictionary:
	var name := str(_pf.get("mobile_emu")) if _pf != null else ""
	return DEVICES.get(name, DEVICES["pixel8"]) if name != "" else {}


# ═══════════ 배율 ═══════════

## 배율 계산 (순수 — 시험): 화면 픽셀·dpi → content_scale_factor
static func compute_factor(px: Vector2, dpi: float) -> float:
	if px.x <= 0.0 or px.y <= 0.0:
		return 1.0
	if dpi <= 0.0:
		dpi = FALLBACK_DPI
	var s0 := minf(px.x / BASE.x, px.y / BASE.y)
	var unit_mm := 25.4 / dpi * s0
	var logical0 := px / s0
	var hi := minf(MAX_FACTOR, minf(logical0.y / MIN_LOGICAL.y, logical0.x / MIN_LOGICAL.x))
	return clampf(TARGET_UNIT_MM / unit_mm, 1.0, maxf(1.0, hi))


## 논리 1단위의 실제 길이 (mm) — 지금 화면·배율 (모바일이 아니면 0)
func unit_mm() -> float:
	var sp := _screen_px_dpi()
	if sp.is_empty():
		return 0.0
	var px: Vector2 = sp["px"]
	var s0 := minf(px.x / BASE.x, px.y / BASE.y)
	return 25.4 / float(sp["dpi"]) * s0 * factor


## {px: 화면 픽셀, dpi, inset: [l,t,r,b] 픽셀} — 흉내면 기기 값, 진짜 모바일이면 창·OS 값
func _screen_px_dpi() -> Dictionary:
	if not _mobile():
		return {}
	var dv := _device()
	if not dv.is_empty():
		return {"px": Vector2(dv["size"]), "dpi": float(dv["dpi"]), "inset": inset_override if not inset_override.is_empty() else dv["inset"]}
	var win := get_tree().root
	var px := Vector2(win.size)
	var dpi := float(DisplayServer.screen_get_dpi())
	var inset := [0, 0, 0, 0]
	if DisplayServer.get_name() != "headless":
		var sa := DisplayServer.get_display_safe_area()
		if sa.size.x > 0 and sa.size.y > 0:
			inset = [maxi(0, sa.position.x), maxi(0, sa.position.y), maxi(0, int(px.x) - sa.end.x), maxi(0, int(px.y) - sa.end.y)]
	if not inset_override.is_empty():
		inset = inset_override
	return {"px": px, "dpi": dpi, "inset": inset}


## 감시 값: 안전 영역(여백) + 화면 방향 + 창 크기
func _signature() -> String:
	var sp := _screen_px_dpi()
	if sp.is_empty():
		return ""
	var ori := DisplayServer.screen_get_orientation() if DisplayServer.get_name() != "headless" else -1
	return "%s|%s|%s|%s" % [str(sp["inset"]), str(ori), str(sp["px"]), str(get_tree().root.size)]


## 안전 영역·방향이 바뀌었는지 보고 바뀌었으면 다시 계산 (시험도 부름). 다시 계산했으면 true
func poll_now() -> bool:
	if not _mobile():
		return false
	var sg := _signature()
	if sg == _poll_sig:
		return false
	polls += 1
	apply()
	return true


## 배율·여백을 다시 계산해 적용 (창 크기가 바뀌면 · 흉내를 켜고 끌 때 · 시험)
func apply() -> void:
	var root := get_tree().root
	var sp := _screen_px_dpi()
	var f := 1.0
	var m := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if not sp.is_empty():
		var px: Vector2 = sp["px"]
		f = compute_factor(px, float(sp["dpi"]))
		var total := minf(px.x / BASE.x, px.y / BASE.y) * f   # 화면 픽셀 / 논리 단위
		var ins: Array = sp["inset"]
		m = {"left": float(ins[0]) / total, "top": float(ins[1]) / total, "right": float(ins[2]) / total, "bottom": float(ins[3]) / total}
	var changed := not is_equal_approx(f, factor) or m != _margins
	_poll_sig = _signature()
	factor = f
	_margins = m
	if not is_equal_approx(root.content_scale_factor, f):
		root.content_scale_factor = f
	if changed:
		if OS.is_debug_build() and not sp.is_empty():
			print("[Mobile] 화면 %s · dpi %s · 안전 여백(px) %s → 배율 %.3f · 논리 %s" % [str(sp["px"]), str(sp["dpi"]), str(sp["inset"]), f, str(root.get_visible_rect().size)])
		layout_changed.emit()


## 안전 영역 여백 (논리 단위) {left, top, right, bottom}
func safe_margins() -> Dictionary:
	return _margins.duplicate()


## 논리 화면 안의 안전 영역
func safe_rect() -> Rect2:
	var vs := get_tree().root.get_visible_rect().size
	return Rect2(Vector2(_margins["left"], _margins["top"]), vs - Vector2(_margins["left"] + _margins["right"], _margins["top"] + _margins["bottom"]))


## 화면 전체를 덮는 부품(앵커 0~1)을 안전 영역 안으로 (PC 는 여백 0 — 그대로). extra 는 위·아래 등에 더할 여백
func fit_safe(ctl: Control, sides: String = "ltrb") -> void:
	if ctl == null:
		return
	ctl.offset_left = _margins["left"] if sides.contains("l") else 0.0
	ctl.offset_top = _margins["top"] if sides.contains("t") else 0.0
	ctl.offset_right = -_margins["right"] if sides.contains("r") else 0.0
	ctl.offset_bottom = -_margins["bottom"] if sides.contains("b") else 0.0


## 끌기 문턱 (논리 px): 터치(흉내 마우스 포함)면 실제 TOUCH_SLOP_MM, 마우스면 PC 그대로 6
func slop_for(ev: InputEvent) -> float:
	if is_touch_event(ev):
		var u := unit_mm()
		if u > 0.0:
			return maxf(MOUSE_SLOP, TOUCH_SLOP_MM / u)
		return maxf(MOUSE_SLOP, 12.0)
	return MOUSE_SLOP


## 손가락에서 온 사건인가 (터치 · 터치가 흉내 낸 마우스 — device = DEVICE_ID_EMULATION)
static func is_touch_event(ev: InputEvent) -> bool:
	return ev is InputEventScreenTouch or ev is InputEventScreenDrag or ev.device == InputEvent.DEVICE_ID_EMULATION


# ═══════════ 글자·단추 최소 크기 (모바일만) ═══════════
##  화면 부품(맵 Node2D 아래가 아닌 Control)이 트리에 들어올 때와 글자 크기·최소 크기가 바뀔 때:
##   글자(Label·Button·LineEdit·RichTextLabel) < min_font() 이면 min_font() 로, 누르는 것(BaseButton·LineEdit·Slider) 의 최소 크기를 min_target() 이상으로.
##   PC 는 손대지 않음. 이미 큰 것은 그대로 — 디자인은 같고 작은 것만 키움 (작아서 안 되는 곳은 화면 코드에서 자리를 맞춤)
var floors := 0   # 시험·확인: 키운 부품 수


## 글자 최소 (논리 px) — 실제 MIN_TEXT_MM (12pt) 이상
func min_font() -> int:
	var u := unit_mm()
	return int(ceil(MIN_TEXT_MM / u)) if u > 0.0 else 0


## 터치 대상 최소 (논리 px) — 실제 MIN_TARGET_MM (44pt) 이상
func min_target() -> float:
	var u := unit_mm()
	return ceilf(MIN_TARGET_MM / u) if u > 0.0 else 0.0


func _on_node_added(n: Node) -> void:
	if n is Control and _mobile():
		_fix_control(n as Control)   # 바로 (부모가 이어서 최소 크기를 재는 코드가 늘어난 값을 보게)


static func in_world(c: Node) -> bool:
	var a: Node = c.get_parent()
	while a != null:
		if a is Node2D:
			return true
		if a is CanvasLayer or a is Viewport:
			return false
		a = a.get_parent()
	return false


func _fix_control(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree() or not _mobile() or c.has_meta("m6a_skip") or in_world(c):
		return
	var text := c is Label or c is Button or c is LineEdit or c is RichTextLabel
	var tap := c is BaseButton or c is LineEdit or c is Slider
	if not text and not tap:
		return
	if not c.has_meta("m6a"):
		c.set_meta("m6a", true)
		c.theme_changed.connect(_fix_control.bind(c))
		c.minimum_size_changed.connect(_fix_control.bind(c))
	if text:
		var mf := min_font()
		if c is RichTextLabel:
			for k: String in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
				if c.get_theme_font_size(k) < mf:
					c.add_theme_font_size_override(k, mf)
					floors += 1
		elif c.get_theme_font_size("font_size") < mf:
			c.add_theme_font_size_override("font_size", mf)
			floors += 1
	if tap:
		var mt := min_target()
		c.set_meta("m6a_floor", mt)
		var cm := c.custom_minimum_size
		if cm.x < mt or cm.y < mt:
			c.custom_minimum_size = Vector2(maxf(cm.x, mt), maxf(cm.y, mt))
			floors += 1
		# 컨테이너 밖(직접 자리 잡은 단추)은 크기도 최소까지
		if not (c.get_parent() is Container) and (c.size.x < mt or c.size.y < mt):
			c.size = c.size.max(Vector2(mt, mt))


# ═══════════ 뒤로 가기 ═══════════

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		system_back()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_SIZE_CHANGED:
		poll_now.call_deferred()   # 돌아오면(회전했을 수 있음) 바로 확인


## 안드로이드 뒤로 가기 (시험도 부름)
func system_back() -> void:
	back_count += 1
	hide_tip()
	var router := get_node_or_null("/root/Router")
	if router != null:
		router.call("request_back", true)


# ═══════════ 길게 누르기 → 툴팁 ═══════════

func _input(ev: InputEvent) -> void:
	if not _mobile():
		return
	if ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.index != 0:
			_lp = {}
			_drag = {}
			return
		if st.pressed:
			hide_tip()
			_lp = {"pos": st.position, "t": 0.0, "fired": false}
			_drag_begin(st.position)
		else:
			_lp = {}
			if bool(_drag.get("active", false)):
				drag_scrolls += 1
			_drag = {}
	elif ev is InputEventScreenDrag and (ev as InputEventScreenDrag).index == 0:
		var sd := ev as InputEventScreenDrag
		if not _lp.is_empty() and (sd.position - Vector2(_lp["pos"])).length() > slop_for(ev):
			_lp = {}
		if _drag_move(sd.position):
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion and ev.device == InputEvent.DEVICE_ID_EMULATION and bool(_drag.get("active", false)) and not _pushing:
		get_viewport().set_input_as_handled()   # 끄는 동안 손가락이 흉내 낸 마우스 움직임은 단추·맵에 주지 않음


# ═══════════ 손가락으로 목록 밀기 ═══════════
##  ScrollContainer 안의 단추·글 칸 위에서 시작한 끌기도 목록을 밂 (Godot 기본은 단추가 누르기를 가져가 목록이 안 움직임).
##  문턱(TOUCH_SLOP_MM)을 넘으면 그때부터 끌기 — 누르던 단추는 떼어도 눌리지 않음. 문턱 아래면 보통 탭.
var _drag := {}
var _pushing := false
var drag_scrolls := 0   # 시험·확인: 끌어서 민 횟수


func _drag_begin(pos: Vector2) -> void:
	_drag = {}
	var c: Node = _control_at(get_tree().root, pos)
	while c != null:
		if c is ScrollContainer:
			var sc := c as ScrollContainer
			var ch: Control = sc.get_child(0) as Control if sc.get_child_count() > 0 else null
			if ch != null:
				var can_v := sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and ch.size.y > sc.size.y + 1.0
				var can_h := sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and ch.size.x > sc.size.x + 1.0
				if can_v or can_h:
					_drag = {"focus0": get_viewport().gui_get_focus_owner(), "start": pos, "sc": sc, "v0": sc.scroll_vertical, "h0": sc.scroll_horizontal, "v": can_v, "h": can_h, "active": false}
					return
		c = c.get_parent()


func _drag_move(pos: Vector2) -> bool:
	if _drag.is_empty() or not is_instance_valid(_drag["sc"]):
		return false
	var d := pos - Vector2(_drag["start"])
	if not bool(_drag["active"]):
		var along := (absf(d.y) if bool(_drag["v"]) else 0.0) + (absf(d.x) if bool(_drag["h"]) else 0.0)
		if along <= slop_for(InputEventScreenDrag.new()):
			return false
		_drag["active"] = true
		_cancel_press(pos)
		# 끌기를 글 칸 위에서 시작했으면 그 칸이 받은 초점(키보드)을 돌려놓음
		var fo := get_viewport().gui_get_focus_owner()
		if fo is LineEdit and fo != _drag.get("focus0"):
			fo.release_focus()
	var sc: ScrollContainer = _drag["sc"]
	if bool(_drag["v"]):
		sc.scroll_vertical = int(float(_drag["v0"]) - d.y)
	if bool(_drag["h"]):
		sc.scroll_horizontal = int(float(_drag["h0"]) - d.x)
	return true


func _process(delta: float) -> void:
	_poll_t += delta
	if _poll_t >= POLL_SEC:
		_poll_t = 0.0
		poll_now()
	if _tip != null and _tip.visible:
		_tip_t -= delta
		if _tip_t <= 0.0:
			hide_tip()
	if _lp.is_empty() or bool(_lp["fired"]):
		return
	_lp["t"] = float(_lp["t"]) + delta
	if float(_lp["t"]) >= LONG_PRESS:
		_lp["fired"] = true
		long_press_at(_lp["pos"])


## 그 자리(논리 좌표)의 GUI 부품이 툴팁을 가졌으면 보이고, 누르고 있던 단추는 떼도 눌리지 않게 함. 보였으면 true
func long_press_at(pos: Vector2) -> bool:
	var vp := get_viewport()
	var ctl := vp.gui_get_hovered_control() if vp.has_method("gui_get_hovered_control") else null
	if ctl == null:
		ctl = _control_at(get_tree().root, pos)
	var tip := ""
	var c: Control = ctl
	while c != null:
		tip = c.get_tooltip(c.get_global_transform().affine_inverse() * pos)
		if tip != "":
			break
		var p := c.get_parent()
		c = p as Control
	if tip == "":
		return false
	_cancel_press(pos)
	show_tip(tip, pos)
	long_press_count += 1
	return true


## 누르고 있는 단추가 손을 뗄 때 눌리지 않게: 단추 밖으로 손가락이 나간 것처럼 (BaseButton 은 떼는 순간 '안에서 누름' 이어야 pressed)
func _cancel_press(_pos: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.device = InputEvent.DEVICE_ID_EMULATION
	mm.position = Vector2(-100000, -100000)
	mm.global_position = mm.position
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	_pushing = true
	get_viewport().push_input(mm, true)
	_pushing = false


## 맨 위에 보이는 부품 중 pos 를 덮는 것 (gui_get_hovered_control 이 없을 때)
func _control_at(n: Node, pos: Vector2) -> Control:
	for i in range(n.get_child_count() - 1, -1, -1):
		var ch := n.get_child(i)
		if ch is CanvasItem and not (ch as CanvasItem).visible:
			continue
		var hit := _control_at(ch, pos)
		if hit != null:
			return hit
	if n is Control and (n as Control).is_visible_in_tree() and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE and (n as Control).get_global_rect().has_point(pos):
		return n
	return null


func show_tip(text: String, pos: Vector2) -> void:
	if _tip == null:
		_tip_layer = CanvasLayer.new()
		_tip_layer.layer = 120
		_tip_layer.name = "MobileTip"
		add_child(_tip_layer)
		_tip = PanelContainer.new()
		_tip.name = "Tip"
		_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(10 / 255.0, 14 / 255.0, 26 / 255.0, 0.96)
		sb.border_color = Color(1, 1, 1, 0.18)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		_tip.add_theme_stylebox_override("panel", sb)
		_tip_lbl = Label.new()
		_tip_lbl.name = "Text"
		_tip_lbl.set_meta("m6a_skip", true)
		_tip_lbl.add_theme_color_override("font_color", Color("e5e7eb"))
		_tip.add_child(_tip_lbl)
		_tip_layer.add_child(_tip)
	_tip_lbl.text = text
	var vs := get_tree().root.get_visible_rect().size
	var fs := maxi(14, min_font())
	_tip_lbl.add_theme_font_size_override("font_size", fs)
	var tw := _tip_lbl.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 4.0
	# 짧은 글은 한 줄, 긴 글만 360 폭에서 줄바꿈 (줄바꿈 글자는 폭을 정해 줘야 높이가 맞음)
	if tw <= 360.0 and not text.contains("\n"):
		_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_tip_lbl.custom_minimum_size = Vector2.ZERO
	else:
		_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tip_lbl.custom_minimum_size = Vector2(360.0, 0)
	_tip.visible = true
	_place_tip(pos)
	_place_tip.call_deferred(pos)   # 글자 최소 크기는 다음 처리에서 정해지므로 한 번 더
	_tip_t = 3.0


func _place_tip(pos: Vector2) -> void:
	if _tip == null or not _tip.visible:
		return
	var vs := get_tree().root.get_visible_rect().size
	_tip.size = Vector2.ZERO
	var sz := _tip.get_combined_minimum_size()
	_tip.size = sz
	# 손가락에 가리지 않게 위쪽에 (안 되면 아래), 안전 영역 안으로
	var sr := safe_rect()
	var p := pos + Vector2(-sz.x * 0.5, -sz.y - 28.0)
	if p.y < sr.position.y:
		p.y = pos.y + 28.0
	p.x = clampf(p.x, sr.position.x + 4.0, maxf(sr.position.x + 4.0, sr.end.x - sz.x - 4.0))
	p.y = clampf(p.y, sr.position.y + 4.0, maxf(sr.position.y + 4.0, vs.y - sz.y - 4.0))
	_tip.position = p


func hide_tip() -> void:
	if _tip != null:
		_tip.visible = false


func tip_visible() -> bool:
	return _tip != null and _tip.visible


func tip_text() -> String:
	return _tip_lbl.text if _tip_lbl != null else ""
