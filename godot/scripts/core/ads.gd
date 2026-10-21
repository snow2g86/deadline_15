extends Node
## Ads — 보상형 광고. 오토로드 이름 Ads (Billing 다음). 결제층 A(가짜 광고) + 6b(진짜 AdMob).
##
##  show_rewarded(placement) : 광고를 띄움 (못 띄우면 false + failed). 끝까지 보고 닫으면 골드 지급 후 rewarded, 중간에 닫으면 closed
##  신호: rewarded(placement, gold) · closed(placement) · failed(placement, code) · availability_changed · privacy_changed
##   failed 코드: unsupported · unavailable(아직 광고 없음) · limit(오늘 다 받음) · busy · battle · show_failed(광고를 띄우다 실패)
##  is_supported() : 이 판에 광고가 있는가 — Platform.has_ads() (PC 가게판 stove·steam 은 광고 없음 → 상점 광고 카드 숨김) 이고
##                   dev 디버그 = 가짜 광고 화면 · google/apple = AdMob 플러그인이 올라와 있을 때(PC·편집기의 --store google 은 광고 없음 = 카드 숨김)
##  is_available() : 지금 광고를 띄울 수 있는가 (AdMob 은 광고를 불러와 둔 뒤에만 true)
##  status()       : 상점 카드가 보여 줄 상태 — "ready" · "loading" · "offline" · "failed" · "consent"(동의 필요) · "limit"(오늘 다 받음) · "showing" · "unconfigured"(출시 빌드인데 실제 광고 단위 ID 가 비어 있음 — 다시 해도 소용없으니 단추 없이 안내만) · "none"
##  recover()      : status 가 offline/failed/consent 일 때 카드 단추 — 다시 불러오기 · 동의 창 다시 띄우기
##  left_today()   : 오늘 남은 횟수 (하루 합계 — AdRules, 기기 로컬 날짜 · 시계 되돌림 정책은 ad_rules.gd)
##
##  보상은 골드만 (data/iap.json AD_REWARD.gold, 하루 AD_REWARD.daily 번). 지급은 AdRules.grant → Store.flush.
##  전투 중에는 띄우지 않음 (Billing 과 같은 이유 — 전투가 끝날 때 game_save 를 덮어씀).
##
##  AdMob (6b) 순서 — 첫 화면이 뜨면 start():
##   1) UMP 동의 정보 갱신 → 동의가 필요(required)하고 창이 있으면 동의 창 (iOS 는 Google 콘솔의 'IDFA 설명 메시지'를 켜 두면 이 흐름에서 ATT 추적 허용 창이 뜸 = 광고를 불러오기 전)
##   2) 동의 상태가 not_required/obtained 일 때만 SDK 초기화 (아동 대상 아님 · 미성년 동의 연령 미만 아님을 명시 — data ADMOB) → 광고 불러오기
##   3) 불러오기 실패는 지수 백오프로 다시 (15초 → 최대 5분), 앱 복귀·상점 진입(refresh)에서도 다시. 1시간 지난 광고는 버리고 새로 (AdMob 광고 수명)
##   4) 광고 단위: 디버그 빌드는 늘 구글 공개 시험 단위(ADMOB.test), 출시 빌드는 ADMOB.real (비어 있으면 광고 없음 = 'failed'). 실제 ID 는 사용자가 AdMob 에서 만들어 data/iap.json 에 넣음
##   5) 보상: SDK 가 '보상 획득'을 알리면 그 자리에서 AdRules.grant + 저장(앱이 죽어도 안 잃음), 사용자가 광고를 닫을 때 rewarded 신호. 닫기 전에 끝까지 안 봤으면 closed (보상 없음)
##   6) 설정 화면 '광고 개인정보 설정' 입구: privacy_options_available() 일 때만(UMP 가 필요하다고 한 지역) → show_privacy_options()
##  서버 측 보상 확인(SSV)은 하지 않음 (광고 보상이 골드 100 하루 3번뿐 — 남은 일).

const Ctx := preload("res://scripts/logic/ctx.gd")
const StoreCtx := preload("res://scripts/logic/store_ctx.gd")
const AdRules := preload("res://scripts/logic/ad_rules.gd")
const OKit := preload("res://scripts/ui/outer_kit.gd")
const AdmobBridge := preload("res://scripts/core/ads/admob_bridge.gd")

signal rewarded(placement: String, gold: float)
signal closed(placement: String)
signal failed(placement: String, code: String)
signal availability_changed
signal privacy_changed

## AdMob 광고 수명 (실제 1시간 — 여유를 두고 50분)
const AD_MAX_AGE_MS := 50 * 60 * 1000
## 불러오기 실패 뒤 다시 하기까지 (초): base × 2^(n-1), 최대 RETRY_MAX
const RETRY_MAX := 300.0
## AdMob 오류 번호 중 '네트워크' (안드로이드 ERROR_CODE_NETWORK_ERROR = iOS GADErrorNetworkError = 2)
const NETWORK_ERROR := 2

## 가짜 광고 길이 (초) — 시험은 짧게
var fake_secs := 2.0
## 시험용: 오늘 날짜를 바꿔 끼움 ("" 이면 기기 로컬 날짜)
var today_override := ""
var stats: Dictionary = {"shown": 0, "rewarded": 0, "closed": 0, "failed": 0}

## AdMob 다리 (admob_bridge.gd) 또는 시험이 끼운 가짜. 비어 있고 플러그인이 있으면 start() 가 만듦
var bridge: Node = null
## AdMob 상태: off · starting · consent · loading · ready · showing · idle(오늘 다 받아 쉬는 중) · no_consent · offline · failed
var state := "off"
var load_error := ""
## 불러오기 재시도 간격의 바탕 (초) — 시험은 짧게
var retry_base := 15.0
## (디버그) 동의 창을 EEA 로 흉내 -- --ump-eea
var debug_eea := false
## 광고 표시 감시 (초): SDK 가 닫힘·실패 콜백을 끝내 주지 않아도 이 시간이 지나면 강제로 풀어 다시 쓸 수 있게 (시험은 짧게)
var show_timeout := 90.0
## 디버그 빌드인가 (시험이 출시 빌드 쪽 광고 단위 규칙을 흉내 내려고 바꿈)
var debug_build := OS.is_debug_build()

var _showing := false
var _overlay: CanvasLayer = null
var _started := false
var _starting := false
var _inited := false
var _loading := false
var _ad: Variant = null
var _ad_ms := 0
var _fails := 0
var _retry_id := 0
var _privacy := false
var _privacy_busy := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args() if OS.is_debug_build() else PackedStringArray()
	debug_eea = args.has("--ump-eea")
	get_tree().scene_changed.connect(_on_scene_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _started:
			refresh()


## 첫 화면이 뜰 때 한 번 (부트 화면이 --save 로 저장 경로를 바꾼 뒤)
func _on_scene_changed() -> void:
	if _started:
		return
	var s: Node = get_tree().current_scene
	var boot := s != null and s.get_script() != null and str((s.get_script() as Script).resource_path).ends_with("ui/boot.gd")
	if boot:
		return
	start()


func _D() -> Dictionary:
	var db: Node = get_node_or_null("/root/DataDB")
	return Ctx.globals_from_db(db) if db != null else {}


func _ctx() -> Object:
	return Ctx.new(_D(), 1, StoreCtx.new(get_node("/root/Store")))


func today() -> String:
	return today_override if today_override != "" else AdRules.day_str(Time.get_date_dict_from_system())


## "fake" · "admob" · "none"
func _backend_kind() -> String:
	var pf: Node = get_node_or_null("/root/Platform")
	if pf == null or not bool(pf.call("has_ads")):
		return "none"
	match str(pf.call("store")):
		"dev":
			return "fake" if OS.is_debug_build() else "none"
		"google", "apple":
			return "admob" if (bridge != null or AdmobBridge.present()) else "none"
	return "none"


func is_supported() -> bool:
	return _backend_kind() != "none"


func is_available() -> bool:
	var k := _backend_kind()
	if k == "fake":
		return true
	return k == "admob" and status() == "ready"


func showing() -> bool:
	return _showing


func reward_gold() -> float:
	return AdRules.reward_gold(_ctx())


func daily_max() -> int:
	return AdRules.daily_max(_ctx())


func left_today() -> int:
	return AdRules.left(_ctx(), today())


# ── AdMob ──

func _plat() -> String:
	var pf: Node = get_node_or_null("/root/Platform")
	return "ios" if pf != null and str(pf.call("store")) == "apple" else "android"


## 쓸 광고 단위 ID: 디버그 빌드는 구글 공개 시험 단위만 (실제 단위로 개발 중에 누르면 계정 정지 위험), 출시 빌드는 ADMOB.real ("" 이면 광고 없음)
func ad_unit_id() -> String:
	return unit_for(_D().get("ADMOB"), debug_build, _plat())


## 광고 단위 고르기 (순수 — 시험이 출시 빌드 쪽도 확인): 디버그 → test, 출시 → real. 값이 없으면 ""
static func unit_for(admob: Variant, debug_build: bool, plat: String) -> String:
	if not (admob is Dictionary):
		return ""
	var cfg: Variant = (admob as Dictionary).get("test" if debug_build else "real")
	if not (cfg is Dictionary) or not ((cfg as Dictionary).get("rewarded") is Dictionary):
		return ""
	return str(((cfg as Dictionary)["rewarded"] as Dictionary).get(plat, ""))


func _cfg() -> Dictionary:
	var A: Variant = _D().get("ADMOB")
	var a: Dictionary = A if A is Dictionary else {}
	return {"child_directed": bool(a.get("child_directed", false)), "under_age": bool(a.get("under_age_of_consent", false)), "max_rating": str(a.get("max_ad_content_rating", ""))}


func _set_state(s: String) -> void:
	if state == s:
		return
	state = s
	availability_changed.emit()


func _ensure_bridge() -> bool:
	if bridge == null and AdmobBridge.present():
		bridge = AdmobBridge.new()
		bridge.name = "AdmobBridge"
	if bridge != null and bridge.get_parent() == null:
		add_child(bridge)
	return bridge != null


## 첫 화면에서 한 번 — AdMob 이면 동의 → 초기화 → 광고 불러오기 (가짜 광고·광고 없는 판은 할 일 없음)
func start() -> void:
	_started = true
	if _backend_kind() != "admob" or not _ensure_bridge():
		return
	_start_admob(false)


## 앱 복귀 · 상점 진입 때: 막혀 있던 것(오프라인·실패)을 다시, 오래된 광고를 새로, 오늘 다 받아 쉬던 것을 다음 날 다시
func refresh() -> void:
	if _backend_kind() != "admob" or bridge == null or _starting or _showing:
		return
	match state:
		"off":
			_start_admob(false)
		"offline", "failed":
			if load_error != "no_unit":
				_retry_now()
		"idle":
			if left_today() > 0:
				_load()
		"ready":
			if not _ad_fresh():
				_drop_ad()
				_load()


## 카드 단추 (status 가 offline · failed · consent 일 때)
func recover() -> void:
	if _backend_kind() != "admob" or bridge == null or _starting or _showing:
		return
	match state:
		"no_consent":
			_start_admob(true)
		"offline", "failed", "off":
			if load_error != "no_unit":
				_retry_now()


func _retry_now() -> void:
	_retry_id += 1   # 대기 중이던 자동 재시도는 취소
	if _inited:
		_load()
	else:
		_start_admob(false)


func _ad_fresh() -> bool:
	return _ad != null and Time.get_ticks_msec() - _ad_ms < AD_MAX_AGE_MS


func _drop_ad() -> void:
	if _ad != null and bridge != null:
		bridge.destroy(_ad)
	_ad = null


func _start_admob(force_form: bool) -> void:
	if _starting:
		return
	_starting = true
	_set_state("starting")
	# 1) 동의 정보 (오프라인이어도 이전에 받은 동의 상태가 SDK 에 남아 있으면 그것으로)
	var cu: Dictionary = await bridge.consent_update(debug_eea)
	var status_s: String = bridge.consent_status()
	if (status_s == "required" or (force_form and status_s != "obtained")) and bridge.consent_form_available():
		_set_state("consent")
		await bridge.show_consent_form()
		status_s = bridge.consent_status()
	_set_privacy(bridge.privacy_options_required())
	if status_s != "not_required" and status_s != "obtained":
		_starting = false
		if status_s == "required":
			load_error = "consent"
			_set_state("no_consent")   # 동의 거부/창을 닫음 — 광고 카드의 '동의하고 보기'로 다시
		else:
			load_error = "consent_unknown_%d" % int(cu.get("code", 0))
			_fails += 1
			_set_state("offline" if not bool(cu.get("ok", false)) else "failed")
			_schedule_retry()
		return
	# 2) SDK 초기화 (한 번)
	if not _inited:
		_inited = bool(await bridge.initialize(_cfg()))
		if not _inited:
			_starting = false
			load_error = "init"
			_fails += 1
			_set_state("failed")
			_schedule_retry()
			return
	_starting = false
	await _load()


func _load() -> void:
	if _loading or _showing:
		return
	if left_today() <= 0:
		_set_state("idle")   # 오늘은 다 받음 — 다음 날 refresh 가 다시
		return
	var unit := ad_unit_id()
	if unit == "":
		load_error = "no_unit"
		_set_state("failed")
		return   # 실제 광고 단위가 설정되지 않음 (출시 빌드 + ADMOB.real 비어 있음) — 다시 해도 소용없으니 재시도 안 함
	_loading = true
	_set_state("loading")
	var r: Dictionary = await bridge.load_rewarded(unit)
	_loading = false
	if bool(r.get("ok", false)) and r.get("ad") != null:
		_drop_ad()
		_ad = r["ad"]
		_ad_ms = Time.get_ticks_msec()
		_fails = 0
		load_error = ""
		_set_state("ready")
		return
	load_error = "load_%d" % int(r.get("code", -1))
	_fails += 1
	_set_state("offline" if int(r.get("code", -1)) == NETWORK_ERROR else "failed")
	_schedule_retry()


func _schedule_retry() -> void:
	_retry_id += 1
	var my := _retry_id
	var secs := minf(RETRY_MAX, retry_base * pow(2.0, float(maxi(0, _fails - 1))))
	get_tree().create_timer(secs).timeout.connect(func() -> void:
		if my != _retry_id or _showing or _starting:
			return
		if state == "offline" or state == "failed":
			_retry_now())


func _set_privacy(v: bool) -> void:
	if v != _privacy:
		_privacy = v
		privacy_changed.emit()


## 설정 화면에 '광고 개인정보 설정' 단추를 둘지 — AdMob 이 도는 판(모바일). 지역에 따라 UMP 가 필요하다고 해야(privacy_required) 실제 창이 뜸
func privacy_entry() -> bool:
	return _backend_kind() == "admob" and bridge != null


## UMP 가 '개인정보 옵션 입구를 보여야 한다'고 한 지역(EEA·영국 등)인가
func privacy_required() -> bool:
	return privacy_entry() and _privacy


## 개인정보 옵션 창 → "shown" · "not_required"(이 지역은 필요 없음 — 창을 띄우지 않음) · "busy"
func show_privacy_options() -> String:
	if not privacy_entry() or _privacy_busy or _showing:
		return "busy"
	if not _privacy:
		return "not_required"
	_privacy_busy = true
	await bridge.show_privacy_options()
	_privacy_busy = false
	_set_privacy(bridge.privacy_options_required())
	# 고른 내용이 바뀌었을 수 있음 — 광고를 새로 준비
	_drop_ad()
	if _inited and bridge.consent_status() in ["not_required", "obtained"]:
		_set_state("idle")
		_retry_now()
	else:
		_start_admob(false)
	return "shown"


## 카드가 보일 상태
func status() -> String:
	var k := _backend_kind()
	if k == "none":
		return "none"
	if k == "fake":
		return "ready"
	if _showing:
		return "showing"
	if left_today() <= 0:
		return "limit"
	match state:
		"ready":
			if _ad_fresh():
				return "ready"
			_drop_ad.call_deferred()
			_reload_deferred.call_deferred()
			return "loading"
		"no_consent":
			return "consent"
		"offline":
			return "offline"
		"failed":
			return "unconfigured" if load_error == "no_unit" else "failed"
	return "loading"


func _reload_deferred() -> void:
	if state == "ready" and not _ad_fresh() and not _showing:
		_set_state("idle")
		_load()


func show_rewarded(placement: String) -> bool:
	var code := ""
	var k := _backend_kind()
	if k == "none":
		code = "unsupported"
	elif _showing:
		code = "busy"
	elif get_tree().get_node_count_in_group("battle_scene") > 0:
		code = "battle"
	elif left_today() <= 0:
		code = "limit"
	elif not is_available():
		code = "unavailable"
	if code != "":
		stats["failed"] += 1
		failed.emit(placement, code)
		return false
	_showing = true
	stats["shown"] += 1
	if k == "fake":
		_show_fake(placement)
		return true
	var ad: Variant = _ad
	_ad = null
	_set_state("showing")
	var ctx := {"earned": false, "grant": {}, "dead": false}
	bridge.show_rewarded(ad, _on_ad_earned.bind(ctx), _on_ad_dismissed.bind(placement, ctx, ad), _on_ad_show_failed.bind(placement, ctx, ad))
	# 감시: SDK 가 닫힘·실패 콜백을 안 주면 _showing 이 영영 안 풀려 광고도 결제 지급도 막힘 → 제한 시간 뒤 강제로 풂.
	#  이미 보상을 받았으면 그 보상은 알리고, 그 뒤에 늦게 오는 콜백은 무시(ctx.dead) — 보상 중복 지급 없음
	get_tree().create_timer(maxf(0.05, show_timeout)).timeout.connect(_on_show_watchdog.bind(placement, ctx, ad))
	return true


func _on_show_watchdog(placement: String, ctx: Dictionary, ad: Variant) -> void:
	if bool(ctx["dead"]) or not _showing:
		return
	ctx["dead"] = true
	_end_show(ad)
	load_error = "show_timeout"
	if bool(ctx["earned"]):
		_report_show(placement, ctx)
	else:
		stats["failed"] += 1
		failed.emit(placement, "show_failed")
	_after_show()


## SDK 가 '보상 획득'을 알림 — 광고가 아직 화면에 있어도 지금 지급·저장 (앱이 죽어도 보상을 잃지 않음)
func _on_ad_earned(ctx: Dictionary) -> void:
	if bool(ctx["earned"]) or bool(ctx["dead"]):
		return
	ctx["earned"] = true
	ctx["grant"] = AdRules.grant(_ctx(), today())
	if bool((ctx["grant"] as Dictionary).get("ok", false)):
		get_node("/root/Store").call("flush")


## 사용자가 광고를 닫음 — 보상을 받았으면 rewarded, 아니면 closed
func _on_ad_dismissed(placement: String, ctx: Dictionary, ad: Variant) -> void:
	if bool(ctx["dead"]):
		return
	ctx["dead"] = true
	_end_show(ad)
	_report_show(placement, ctx)
	_after_show()


## 광고를 띄우다 실패 (SDK 오류) — 이미 보상을 받은 뒤라면 보상은 그대로 알림
func _on_ad_show_failed(code: int, _msg: String, placement: String, ctx: Dictionary, ad: Variant) -> void:
	if bool(ctx["dead"]):
		return
	ctx["dead"] = true
	_end_show(ad)
	load_error = "show_%d" % code
	if bool(ctx["earned"]):
		_report_show(placement, ctx)
	else:
		stats["failed"] += 1
		failed.emit(placement, "show_failed")
	_after_show()


func _report_show(placement: String, ctx: Dictionary) -> void:
	if not bool(ctx["earned"]):
		stats["closed"] += 1
		closed.emit(placement)
		return
	var g: Dictionary = ctx["grant"]
	if bool(g.get("ok", false)):
		stats["rewarded"] += 1
		rewarded.emit(placement, float(g["gold"]))
	else:
		stats["failed"] += 1
		failed.emit(placement, str(g.get("err", "limit")))


func _end_show(ad: Variant) -> void:
	_showing = false
	if ad != null and bridge != null:
		bridge.destroy(ad)


func _after_show() -> void:
	_ad = null
	_set_state("idle")
	if left_today() > 0:
		_load()


# ── 가짜 광고 (디버그 dev 판) ──

## 끝까지 봄 → 지급
func _finish(placement: String, watched: bool) -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_showing = false
	if not watched:
		stats["closed"] += 1
		closed.emit(placement)
		return
	var r := AdRules.grant(_ctx(), today())
	if not r.get("ok", false):
		stats["failed"] += 1
		failed.emit(placement, str(r.get("err", "limit")))
		return
	get_node("/root/Store").call("flush")
	stats["rewarded"] += 1
	rewarded.emit(placement, float(r["gold"]))


func _t(k: String, p: Dictionary = {}) -> String:
	var i18n: Node = get_node_or_null("/root/I18n")
	return str(i18n.call("t", k, p)) if i18n != null else k


## 가짜 광고 화면 (디버그 dev 판) — 모양만 광고처럼: 어두운 화면 · '광고' 표시 · 남은 초 · 다 보면 '보상 받고 닫기', 그 전에는 '닫기(보상 없음)'
func _show_fake(placement: String) -> void:
	var cl := CanvasLayer.new()
	cl.name = "FakeAd"
	cl.layer = 100
	add_child(cl)
	_overlay = cl
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	cl.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var v := OKit.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	var tag := OKit.label(12, Color("fbbf24"), 800)
	tag.text = _t("gd.ads.fake_tag")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	var title := OKit.label(24, Color.WHITE, 900)
	title.name = "AdTitle"
	title.text = _t("gd.ads.fake_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(420, 0)
	v.add_child(title)
	var cnt := OKit.label(14, OKit.DIM, 700)
	cnt.name = "AdCount"
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cnt)
	var bar := ProgressBar.new()
	bar.name = "AdBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(360, 8)
	bar.max_value = 1.0
	v.add_child(bar)
	var btn := OKit.ghost_button(_t("gd.ads.close_no_reward"), 13)
	btn.name = "AdClose"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(btn)
	var state := {"done": false, "t": 0.0}
	btn.pressed.connect(func() -> void:
		if _overlay != cl:
			return
		_finish(placement, bool(state["done"])))
	var total := maxf(0.05, fake_secs)
	cnt.text = _t("gd.ads.fake_wait", {"n": int(ceilf(total))})
	var timer := Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	cl.add_child(timer)
	timer.timeout.connect(func() -> void:
		if state["done"]:
			return
		state["t"] = float(state["t"]) + timer.wait_time
		bar.value = clampf(float(state["t"]) / total, 0.0, 1.0)
		if float(state["t"]) >= total:
			state["done"] = true
			cnt.text = _t("gd.ads.fake_done", {"gold": int(reward_gold())})
			btn.text = _t("gd.ads.close_reward")
		else:
			cnt.text = _t("gd.ads.fake_wait", {"n": int(ceilf(total - float(state["t"])))}))
