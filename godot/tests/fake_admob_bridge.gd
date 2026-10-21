extends Node
## 가짜 AdMob 다리 (6b 시험) — scripts/core/ads/admob_bridge.gd 의 약속과 같은 모양. 응답은 한 프레임 뒤.
##  시나리오 속성: consent_ok(갱신 성공) · status(동의 상태) · form_available · form_result(창을 보여 준 뒤 바뀔 상태) · privacy_required ·
##                 init_ok · load_results(앞에서부터 한 번씩) · show_mode

var consent_ok := true
var status := "not_required"
var form_available := false
## 동의 창을 보여 준 뒤 status 가 이 값으로 ("" 이면 그대로 = 창을 닫음)
var form_result := "obtained"
var privacy_required := false
var init_ok := true
## 불러오기 결과를 앞에서부터 하나씩 (비면 성공). 항목: {ok, code}
var load_results: Array = []
## "earn" (보상 → 닫음) · "close" (보상 없이 닫음) · "fail" (띄우기 실패) · "earn_fail_show" (보상 뒤 띄우기 오류) · "manual" (시험이 emit_* 로)
var show_mode := "earn"
var calls: Dictionary = {}
var init_cfg: Dictionary = {}
var units: Array = []
var destroyed := 0
var form_shown := 0
var privacy_shown := 0
var debug_eea_seen := false
var _ads := 0
var _manual: Dictionary = {}


func _hit(k: String) -> void:
	calls[k] = int(calls.get(k, 0)) + 1


func consent_update(debug_eea: bool) -> Dictionary:
	_hit("consent_update")
	debug_eea_seen = debug_eea
	await get_tree().process_frame
	return {"ok": consent_ok, "code": 0 if consent_ok else 2, "message": ""}


func consent_status() -> String:
	return status


func consent_form_available() -> bool:
	return form_available


func show_consent_form() -> Dictionary:
	_hit("show_consent_form")
	form_shown += 1
	await get_tree().process_frame
	if form_result != "":
		status = form_result
	return {"ok": true, "code": 0, "message": ""}


func privacy_options_required() -> bool:
	return privacy_required


func show_privacy_options() -> Dictionary:
	_hit("show_privacy_options")
	privacy_shown += 1
	await get_tree().process_frame
	return {"ok": true, "code": 0, "message": ""}


func initialize(cfg: Dictionary) -> bool:
	_hit("initialize")
	init_cfg = cfg
	await get_tree().process_frame
	return init_ok


func load_rewarded(unit_id: String) -> Dictionary:
	_hit("load_rewarded")
	units.append(unit_id)
	await get_tree().process_frame
	var r: Dictionary = load_results.pop_front() if not load_results.is_empty() else {"ok": true}
	if bool(r.get("ok", true)):
		_ads += 1
		return {"ok": true, "ad": {"id": _ads}, "code": 0, "message": ""}
	return {"ok": false, "code": int(r.get("code", 3)), "message": "fake"}


func show_rewarded(ad: Variant, on_earned: Callable, on_closed: Callable, on_failed: Callable) -> void:
	_hit("show_rewarded")
	_manual = {"ad": ad, "earned": on_earned, "closed": on_closed, "failed": on_failed}
	if show_mode == "manual":
		return
	_play.call_deferred(on_earned, on_closed, on_failed)


func _play(on_earned: Callable, on_closed: Callable, on_failed: Callable) -> void:
	await get_tree().process_frame
	match show_mode:
		"earn":
			on_earned.call()
			await get_tree().process_frame
			on_closed.call()
		"close":
			on_closed.call()
		"fail":
			on_failed.call(0, "fake show error")
		"earn_fail_show":
			on_earned.call()
			on_failed.call(0, "fake show error")


func emit_earned() -> void:
	(_manual["earned"] as Callable).call()


func emit_closed() -> void:
	(_manual["closed"] as Callable).call()


func destroy(_ad: Variant) -> void:
	destroyed += 1
