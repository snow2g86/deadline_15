extends Node
## Ads — 보상형 광고 (결제층 A). 오토로드 이름 Ads (Billing 다음).
##
##  show_rewarded(placement) : 광고를 띄움 (못 띄우면 false + failed). 끝까지 보고 닫으면 골드 지급 후 rewarded, 중간에 닫으면 closed
##  신호: rewarded(placement, gold) · closed(placement) · failed(placement, code)   code: unsupported · unavailable · limit · busy · battle
##  is_supported() : 이 판에 광고가 있는가 — Platform.has_ads() (PC 가게판 stove·steam 은 광고 없음 → 상점 광고 카드 숨김)
##  is_available() : 지금 광고를 띄울 수 있는가 (dev 디버그 빌드 = 가짜 광고 화면 · google/apple = SDK 를 붙이기 전이라 아직 false)
##  left_today()   : 오늘 남은 횟수 (하루 합계 — AdRules, 기기 로컬 날짜 · 시계 되돌림 정책은 ad_rules.gd)
##
##  보상은 골드만 (data/iap.json AD_REWARD.gold, 하루 AD_REWARD.daily 번). 지급은 AdRules.grant → Store.flush.
##  전투 중에는 띄우지 않음 (Billing 과 같은 이유 — 전투가 끝날 때 game_save 를 덮어씀).
##  모바일 SDK(AdMob 등) 작업 때 채울 곳: _backend_kind() 의 google/apple, _show_real(). 서버 측 보상 확인(SSV)도 그때.

const Ctx := preload("res://scripts/logic/ctx.gd")
const StoreCtx := preload("res://scripts/logic/store_ctx.gd")
const AdRules := preload("res://scripts/logic/ad_rules.gd")
const OKit := preload("res://scripts/ui/outer_kit.gd")

signal rewarded(placement: String, gold: float)
signal closed(placement: String)
signal failed(placement: String, code: String)

## 가짜 광고 길이 (초) — 시험은 짧게
var fake_secs := 2.0
## 시험용: 오늘 날짜를 바꿔 끼움 ("" 이면 기기 로컬 날짜)
var today_override := ""
var stats: Dictionary = {"shown": 0, "rewarded": 0, "closed": 0, "failed": 0}

var _showing := false
var _overlay: CanvasLayer = null


func _D() -> Dictionary:
	var db: Node = get_node_or_null("/root/DataDB")
	return Ctx.globals_from_db(db) if db != null else {}


func _ctx() -> Object:
	return Ctx.new(_D(), 1, StoreCtx.new(get_node("/root/Store")))


func today() -> String:
	return today_override if today_override != "" else AdRules.day_str(Time.get_date_dict_from_system())


## "fake" · "none" · (다음 작업) "admob"
func _backend_kind() -> String:
	var pf: Node = get_node_or_null("/root/Platform")
	if pf == null or not bool(pf.call("has_ads")):
		return "none"
	match str(pf.call("store")):
		"dev":
			return "fake" if OS.is_debug_build() else "none"
		"google", "apple":
			return "sdk_pending"   # AdMob 등을 붙이기 전 — 카드는 보이되 꺼짐
	return "none"


func is_supported() -> bool:
	return _backend_kind() != "none"


func is_available() -> bool:
	return _backend_kind() == "fake"


func showing() -> bool:
	return _showing


func reward_gold() -> float:
	return AdRules.reward_gold(_ctx())


func daily_max() -> int:
	return AdRules.daily_max(_ctx())


func left_today() -> int:
	return AdRules.left(_ctx(), today())


func show_rewarded(placement: String) -> bool:
	var code := ""
	if not is_supported():
		code = "unsupported"
	elif not is_available():
		code = "unavailable"
	elif _showing:
		code = "busy"
	elif get_tree().get_node_count_in_group("battle_scene") > 0:
		code = "battle"
	elif left_today() <= 0:
		code = "limit"
	if code != "":
		stats["failed"] += 1
		failed.emit(placement, code)
		return false
	_showing = true
	stats["shown"] += 1
	_show_fake(placement)
	return true


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
