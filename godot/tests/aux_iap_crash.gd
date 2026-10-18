extends SceneTree
## check_iap 보조 — 다른 프로세스에서 구매를 시작하고 가짜 시나리오대로 '앱이 죽게' 한다 (OS.kill — 저장 정리 없이 바로 끝남)
##   Godot --headless --path godot --script res://tests/aux_iap_crash.gd -- --iap crash_before_grant|crash_after_grant --save user://x.json [--gold 1000]
##  죽지 않으면 AUX_IAP: ALIVE <결과> 를 찍고 종료 코드 3 (시나리오가 먹지 않음 = 시험 실패)

func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var si := args.find("--save")
	var store: Node = root.get_node("Store")
	store.call("use_path", args[si + 1] if si >= 0 else "user://test_iap_aux.json")
	var gi := args.find("--gold")
	if gi >= 0:
		store.call("set_json", "game_save", {"gold": float(args[gi + 1]), "cleared": [1]})
		store.call("flush")
	var billing: Node = root.get_node("Billing")
	var out := {"r": {}}
	billing.connect("purchase_finished", func(_id: String, r: Dictionary) -> void: out["r"] = r)
	if not bool(billing.call("buy", "gold_1200")):
		print("AUX_IAP: BUY_REFUSED")
		quit(4)
		return
	var t0 := Time.get_ticks_msec()
	while (out["r"] as Dictionary).is_empty() and Time.get_ticks_msec() - t0 < 10000:
		await process_frame
	print("AUX_IAP: ALIVE %s" % str(out["r"]))
	quit(3)
