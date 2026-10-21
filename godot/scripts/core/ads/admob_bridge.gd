extends Node
## 실제 AdMob 다리 (6b) — Poing Studios AdMob 플러그인 5.1.0 (addons/admob: Google 모바일 광고 SDK + UMP 동의 SDK)을 ads.gd 가 쓰기 쉬운
##  단순한 모양으로 바꿈. 플러그인의 클래스(MobileAds · RewardedAdLoader · UserMessagingPlatform …)를 아는 곳은 이 파일뿐이고,
##  시험은 같은 모양의 가짜(tests/fake_admob_bridge.gd)를 끼움. 플러그인 쪽 호출이 영영 답하지 않는 경우(네이티브 오류)를 위해 모든 기다림에 제한 시간이 있음.
##
##  이 다리의 약속 (ads.gd 가 의지하는 것) — await 가 붙은 것은 코루틴:
##   consent_update(debug_eea) -> {ok, code, message}      UMP 동의 정보 갱신 (오프라인이면 ok=false)
##   consent_status() -> "unknown" | "not_required" | "required" | "obtained"
##   consent_form_available() -> bool
##   show_consent_form() -> {ok, code, message}            동의 창을 불러와 보여 주고 닫힐 때까지 (iOS 는 Google 콘솔의 'IDFA 설명 메시지'가 켜져 있으면 이 흐름에서 ATT 창도 뜸)
##   privacy_options_required() -> bool                   '개인정보 옵션' 입구를 보여야 하는가 (EEA 등)
##   show_privacy_options() -> {ok, code, message}         개인정보 옵션 창 (동의를 다시 고름)
##   initialize(cfg) -> bool                               cfg {child_directed, under_age, max_rating}. 아동 대상 아님(false)을 명시해서 넘김
##   load_rewarded(unit_id) -> {ok, ad, code, message}     code = AdMob 오류 번호 (2 = 네트워크 오류, 3 = 광고 없음)
##   show_rewarded(ad, on_earned, on_closed, on_failed)    on_earned() · on_closed() · on_failed(code, message) — 보상은 on_earned 때, 닫힘은 그 뒤
##   destroy(ad)

const T_CONSENT := 15.0
const T_FORM_LOAD := 15.0
const T_FORM_SHOW := 900.0
const T_INIT := 25.0
const T_LOAD := 30.0

const SINGLETON := "PoingGodotAdMob"

## 제한 시간 시험용 배수 (시험이 줄임)
var time_scale := 1.0


class W extends RefCounted:
	signal done
	var finished := false
	var value: Variant = null

	func fire(v: Variant) -> void:
		if finished:
			return
		finished = true
		value = v
		done.emit()


## 이 기기에 플러그인이 올라와 있는가 (안드로이드/iOS 에서만 참)
static func present() -> bool:
	return Engine.has_singleton(SINGLETON)


func _arm(secs: float, timeout_value: Variant) -> W:
	var w := W.new()
	if is_inside_tree():
		get_tree().create_timer(maxf(0.01, secs * time_scale)).timeout.connect(func() -> void: w.fire(timeout_value))
	return w


static func _res(ok: bool, code: int = 0, msg: String = "") -> Dictionary:
	return {"ok": ok, "code": code, "message": msg}


# ── 동의 (UMP) ──

func consent_update(debug_eea: bool) -> Dictionary:
	var params := ConsentRequestParameters.new()
	params.tag_for_under_age_of_consent = false
	if debug_eea:
		var ds := ConsentDebugSettings.new()
		ds.debug_geography = DebugGeography.Values.EEA
		params.consent_debug_settings = ds
	var w := _arm(T_CONSENT, _res(false, -1, "timeout"))
	UserMessagingPlatform.consent_information.update(params,
		func() -> void: w.fire(_res(true)),
		func(e: FormError) -> void: w.fire(_res(false, e.error_code if e != null else -1, e.message if e != null else "")))
	if not w.finished:
		await w.done
	return w.value


func consent_status() -> String:
	match int(UserMessagingPlatform.consent_information.get_consent_status()):
		ConsentInformation.ConsentStatus.NOT_REQUIRED:
			return "not_required"
		ConsentInformation.ConsentStatus.REQUIRED:
			return "required"
		ConsentInformation.ConsentStatus.OBTAINED:
			return "obtained"
	return "unknown"


func consent_form_available() -> bool:
	return UserMessagingPlatform.consent_information.get_is_consent_form_available()


func show_consent_form() -> Dictionary:
	var wl := _arm(T_FORM_LOAD, _res(false, -1, "timeout"))
	var holder: Array = []
	UserMessagingPlatform.load_consent_form(
		func(form: ConsentForm) -> void:
			holder.append(form)
			wl.fire(_res(true)),
		func(e: FormError) -> void: wl.fire(_res(false, e.error_code if e != null else -1, e.message if e != null else "")))
	if not wl.finished:
		await wl.done
	if not bool((wl.value as Dictionary).get("ok", false)) or holder.is_empty():
		return wl.value
	var ws := _arm(T_FORM_SHOW, _res(false, -1, "timeout"))
	(holder[0] as ConsentForm).show(func(e: FormError) -> void: ws.fire(_res(e == null, e.error_code if e != null else 0, e.message if e != null else "")))
	if not ws.finished:
		await ws.done
	return ws.value


func privacy_options_required() -> bool:
	return int(UserMessagingPlatform.consent_information.get_privacy_options_requirement_status()) == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options() -> Dictionary:
	var w := _arm(T_FORM_SHOW, _res(false, -1, "timeout"))
	UserMessagingPlatform.show_privacy_options_form(func(e: FormError) -> void: w.fire(_res(e == null, e.error_code if e != null else 0, e.message if e != null else "")))
	if not w.finished:
		await w.done
	return w.value


# ── SDK ──

func initialize(cfg: Dictionary) -> bool:
	var rc := RequestConfiguration.new()
	rc.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.TRUE if bool(cfg.get("child_directed", false)) else RequestConfiguration.TagForChildDirectedTreatment.FALSE
	rc.tag_for_under_age_of_consent = RequestConfiguration.TagForUnderAgeOfConsent.TRUE if bool(cfg.get("under_age", false)) else RequestConfiguration.TagForUnderAgeOfConsent.FALSE
	rc.max_ad_content_rating = str(cfg.get("max_rating", ""))
	MobileAds.set_request_configuration(rc)
	MobileAds.set_ios_app_pause_on_background(true)
	var w := _arm(T_INIT, false)
	var l := OnInitializationCompleteListener.new()
	l.on_initialization_complete = func(_s: InitializationStatus) -> void: w.fire(true)
	MobileAds.initialize(l)
	if not w.finished:
		await w.done
	return bool(w.value)


# ── 보상형 광고 ──

func load_rewarded(unit_id: String) -> Dictionary:
	var w := _arm(T_LOAD, _res(false, -1, "timeout"))
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		var r := _res(true)
		r["ad"] = ad
		w.fire(r)
	cb.on_ad_failed_to_load = func(e: LoadAdError) -> void: w.fire(_res(false, e.code if e != null else -1, e.message if e != null else ""))
	var loader := RewardedAdLoader.new()
	loader.load(unit_id, AdRequest.new(), cb)
	if not w.finished:
		await w.done
	return w.value


func show_rewarded(ad: Variant, on_earned: Callable, on_closed: Callable, on_failed: Callable) -> void:
	var rad: RewardedAd = ad
	var cb := FullScreenContentCallback.new()
	cb.on_ad_dismissed_full_screen_content = func() -> void: on_closed.call()
	cb.on_ad_failed_to_show_full_screen_content = func(e: AdError) -> void: on_failed.call(e.code if e != null else -1, e.message if e != null else "")
	rad.full_screen_content_callback = cb
	var l := OnUserEarnedRewardListener.new()
	l.on_user_earned_reward = func(_item: RewardedItem) -> void: on_earned.call()
	rad.show(l)


func destroy(ad: Variant) -> void:
	if ad is RewardedAd:
		(ad as RewardedAd).destroy()
