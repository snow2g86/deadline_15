extends SceneTree
## 4b-1 시험 — 편성 화면의 장비·소모품·강화 탭, 상점, 전투 이어하기
##   Godot --headless --path godot --script res://tests/check_outer_4b1.gd   [-- --only rules,resume,screens,clicks,weird,lang]
##  1) rules   : 상점(새로 만들기·1시간 갱신·사기 전부·골드 부족)·장비(끼우기·빼기·판매·목록 순서·단추·옵션 줄·더 좋은 장비 표시)·
##               강화(목록·확인 창 숫자·강화 여러 번·파손·수리·분해)·아이템 탭(묶음·물약 사용)을 웹 코드의 정답과 비교
##               (tests/fixtures/outer_4b1_web.json — 웹 코드로 만든 고정 기준, 기준 데이터 tests/baseline/data 로 비교. 같은 씨앗·같은 시각 → 저장값·난수 호출 수까지)
##  2) resume  : 전투 이어하기 — 저장 → 새 장면에서 불러오기 → 끝까지가 끊지 않은 것과 같은 결과(저장소·결과), 나가기·재개 단추, 웹 game_battle 안내·포기
##  3) screens : 진짜 장면 — 상점 사기·편성 장비 끼우기·강화·물약·판매가 저장에 반영, 아래 탭 상점, 키보드
##  4) clicks  : 같은 프레임 연타 (진짜 입력 push_input) — 사기·강화·끼우기·판매·분해·수리·물약·뽑기·재개가 한 번만
##  5) weird   : 이상한 값이 든 세이브 (상점·재료·인벤토리·전투 저장) → 모든 새 화면·창에서 스크립트 오류 0, 정상 세이브는 바이트 그대로
##  6) lang    : 6개 언어 × 새 화면·창 (1280×720 · 1920×1080) — 넘침 0 · 두부 0
##  Godot 오류(Logger 로 셈) 0 이어야 통과. 저장은 user://test_outer_4b1_save.json (진짜 세이브는 건드리지 않음)

const BaselineData := preload("res://tests/baseline_data.gd")
const JsonX := preload("res://scripts/core/json_exact.gd")
const JsonNorm := preload("res://scripts/core/json_norm.gd")
const FontsT := preload("res://scripts/core/fonts.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")
const SaveStore := preload("res://scripts/logic/save_store.gd")
const Js := preload("res://scripts/logic/js.gd")
const Profile := preload("res://scripts/logic/profile.gd")
const Gear := preload("res://scripts/logic/gear.gd")
const EquipRules := preload("res://scripts/logic/equip_rules.gd")
const ShopRules := preload("res://scripts/logic/shop_rules.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")
const ResumeRules := preload("res://scripts/logic/resume_rules.gd")
const SaveSanitize := preload("res://scripts/logic/save_sanitize.gd")
const StoreCtx := preload("res://scripts/logic/store_ctx.gd")
const SAVE := "user://test_outer_4b1_save.json"
const LANGS := ["ko", "en", "es", "ja", "zh-CN", "zh-TW"]

var _fails: Array = []
var _passes := 0
var _counter: ErrCounter
var store: Node
var i18n: Node
var router: Node
var D: Dictionary
var _only: Array = []
var _stats: Dictionary = {}
var fx: Dictionary
var NOW := 0.0
var names_ko: Array = []


class ErrCounter extends Logger:
	var errors: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	_counter = ErrCounter.new()
	OS.add_logger(_counter)
	_main.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
	else:
		_fails.append(what)
		print("  FAIL " + what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, secs: float = 3.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await process_frame
	return cond.call()


func _want(name: String) -> bool:
	return _only.is_empty() or _only.has(name)


func _stat(k: String, n: int = 1) -> void:
	_stats[k] = int(_stats.get(k, 0)) + n


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var oi := args.find("--only")
	if oi >= 0 and oi + 1 < args.size():
		_only = Array(args[oi + 1].split(","))
	BaselineData.apply(self)   # 웹 정답 = 기준 데이터로 (tests/baseline_data.gd, -- --live 면 지금 데이터)
	store = root.get_node("Store")
	i18n = root.get_node("I18n")
	router = root.get_node("Router")
	D = Ctx.globals_from_db(root.get_node("DataDB"))
	store.call("use_path", SAVE)
	store.call("clear")
	i18n.call("reload")
	root.size = Vector2i(1280, 720)
	var raw := FileAccess.get_file_as_string("res://tests/fixtures/outer_4b1_web.json")
	var p: Variant = JsonX.parse(raw)
	_check(p is Dictionary, "웹 정답 파일 읽음")
	if not (p is Dictionary):
		quit(1)
		return
	fx = p
	NOW = float(fx["now"])
	var ko: Variant = root.get_node("DataDB").call("lang", "ko")   # 기준 데이터의 이름 목록 (웹 정답과 같은 때)
	names_ko = ko["character"]["names"]
	if _want("rules"):
		print("── 1) 규칙 ↔ 웹 정답 ──")
		_rules()
	if _want("resume"):
		print("── 2) 전투 이어하기 ──")
		await _resume()
	if _want("screens"):
		print("── 3) 진짜 장면 ──")
		await _screens()
	if _want("clicks"):
		print("── 4) 같은 프레임 연타 ──")
		await _clicks()
	if _want("weird"):
		print("── 5) 이상한 세이브 ──")
		await _weird()
	if _want("lang"):
		print("── 6) 6개 언어 넘침·두부 ──")
		await _langs()
	if current_scene != null:
		change_scene_to_file("res://scenes/boot.tscn")
		await _frames(3)
		current_scene.queue_free()
		await _frames(3)
	# 그림 아이콘 창구(정적 캐시)를 비워 끝날 때 '자원 사용 중' 경고가 나지 않게
	(load("res://scripts/battle/icons.gd") as GDScript).set("_inst", null)
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	for e: String in _counter.errors:
		print("  ERR " + e)
	_check(_counter.errors.is_empty(), "Godot 오류 0 (%d)" % _counter.errors.size())
	print("  수치: %s" % JsonX.stringify(_stats))
	if _fails.is_empty():
		print("RESULT: PASS (%d개 통과)" % _passes)
		quit(0)
	else:
		print("RESULT: FAIL (%d개 실패, %d개 통과)" % [_fails.size(), _passes])
		for f: String in _fails:
			print("  - " + f)
		quit(1)


# ═══════════ 공용 ═══════════

func _mem_ctx(seed_store: Dictionary, seed: int = 4242) -> Object:
	var ss := SaveStore.new()
	for k: String in seed_store.keys():
		var v: Variant = seed_store[k]
		if typeof(v) == TYPE_STRING:
			ss.set_str(k, v)
		else:
			ss.set_json(k, JsonNorm.normalize_store(k, Js.deep(v)))
	var c := Ctx.new(D, seed, ss)
	var now := NOW
	c.clock = func() -> float: return now
	return c


## 웹 정답 쪽 가짜 t (키 + JSON(자리표시자))
func _tw(k: String, p: Dictionary = {}) -> String:
	return k + (JsonX.stringify(p) if not p.is_empty() else "")


func _dump(c: Object) -> Dictionary:
	var o: Dictionary = {}
	for k: String in c.store.keys():
		var v: Variant = c.store.get_json(k)
		o[k] = v
	return o


func _same(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return float(a) == float(b)
	if ta != tb:
		return false
	if ta == TYPE_DICTIONARY:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k: Variant in (a as Dictionary).keys():
			if not (b as Dictionary).has(k) or not _same(a[k], b[k]):
				return false
		return true
	if ta == TYPE_ARRAY:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _same(a[i], b[i]):
				return false
		return true
	return a == b


## 다른 곳 하나 찾기 (경로)
func _diff(a: Variant, b: Variant, p: String = "") -> String:
	if _same(a, b):
		return ""
	if a is Dictionary and b is Dictionary:
		for k: Variant in (a as Dictionary).keys():
			if not (b as Dictionary).has(k):
				return "%s.%s: godot 에만" % [p, k]
			var d := _diff(a[k], b[k], "%s.%s" % [p, k])
			if d != "":
				return d
		for k2: Variant in (b as Dictionary).keys():
			if not (a as Dictionary).has(k2):
				return "%s.%s: 웹에만 (%s)" % [p, k2, JsonX.stringify(b[k2]).substr(0, 80)]
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return "%s: 길이 %d ≠ %d" % [p, (a as Array).size(), (b as Array).size()]
		for i in (a as Array).size():
			var d2 := _diff(a[i], b[i], "%s[%d]" % [p, i])
			if d2 != "":
				return d2
	return "%s: %s ≠ 웹 %s" % [p, JsonX.stringify(a).substr(0, 160), JsonX.stringify(b).substr(0, 160)]


func _cmp(what: String, mine: Variant, web: Variant) -> bool:
	var d := _diff(mine, web)
	if d != "":
		print("    [%s] %s" % [what, d])
	return d == ""


# ═══════════ 1) 규칙 ═══════════

func _rules() -> void:
	var K: Dictionary = fx["constants"]
	_check(_cmp("EXP_POTIONS", ShopRules.EXP_POTIONS, K["EXP_POTIONS"]) and _cmp("BATTLE_POTION_LIST", ShopRules.BATTLE_POTION_LIST, K["BATTLE_POTION_LIST"])
		and _cmp("SCROLL_CLASSES", ShopRules.SCROLL_CLASSES, K["SCROLL_CLASSES"]) and float(K["SHOP_REFRESH_INTERVAL"]) == ShopRules.SHOP_REFRESH_INTERVAL
		and _cmp("POTION_INFO", EquipRules.POTION_INFO, K["POTION_INFO"]), "웹 화면 파일 상수 (경험치 물약·전투 물약·전직서·갱신 간격·물약 이름) = 웹")
	var rates := ""
	for r: Array in ShopRules.gacha_rates(_mem_ctx({})):
		rates += "<span style=\"color:%s\">equip.rarity.%s %s</span> " % [D["RARITY"][r[0]]["color"], r[0], r[1]]
	# 웹 표시는 4.5% → 5%, 0.45% → 0.4% 로 잘못 반올림했음 (합계 99.45%) — Godot 판은 데이터의 실제 확률을 그대로 보임 (의도된 차이, check_odds_disclosure 가 따로 검증)
	var web_rates := str(K["rates"]).replace("equip.rarity.rare 5%</span>", "equip.rarity.rare 4.5%</span>").replace("equip.rarity.epic 0.4%</span>", "equip.rarity.epic 0.45%</span>")
	_check(str(K["rates"]).contains("equip.rarity.rare 5%</span>") and web_rates == "<div class=\"gacha-rate-row\">" + rates + "</div>", "뽑기 확률표 숫자 = 웹 (웹의 5%% · 0.4%% 반올림 오류만 4.5%% · 0.45%% 로 바로잡음) (%s)" % rates.substr(0, 60))
	_rules_shop()
	_rules_equip()
	_rules_enhance()
	_rules_items()


func _rules_shop() -> void:
	var tw := func(k: String, p: Dictionary) -> String: return _tw(k, p)
	for S: Dictionary in fx["shop"]:
		var c := _mem_ctx(S["store"], int(S["seed"]))
		var name := str(S["name"])
		var ok := true
		match name:
			"fresh", "refresh", "no_refresh", "ts_string":
				var data := ShopRules.load_shop(c, names_ko)
				if S.has("timer"):
					# ts 가 숫자가 아니면 웹은 'NaN:aN:aN' 을 보임 — Godot 은 타이머를 숨김 (이상한 세이브 관대 처리)
					var want: String = "" if name == "ts_string" else str(S["timer"])
					ok = _cmp(name + " 타이머", ShopRules.timer_text(c, data, "mercenary", tw), want) and ok
			"buy_all":
				var data2 := ShopRules.load_shop(c, names_ko)
				for st: Dictionary in S["steps"]:
					match str(st["label"]):
						"rune":
							ShopRules.rune_gacha(c)
						"gacha1_pity":
							ShopRules.gacha(c, 1)
						"gacha10":
							ShopRules.gacha(c, 10)
						"stone", "protect":
							ShopRules.buy_mat(c, str(st["label"]))
						"legend":
							ShopRules.exchange_legend(c, str(st["id"]))
						_:
							if int(st["idx"]) >= 0:
								ShopRules.buy(c, data2, int(st["idx"]), names_ko)
			"poor":
				var data3 := ShopRules.load_shop(c, names_ko)
				for st2: Dictionary in S["steps"]:
					match str(st2["fn"]):
						"gacha1":
							ShopRules.gacha(c, 1)
						"legend":
							ShopRules.exchange_legend(c, (D["LEGENDS"] as Dictionary).keys()[0])
						_:
							ShopRules.buy(c, data3, int(st2["idx"]), names_ko)
		var web_after: Dictionary = Js.deep(S["after"])
		if name == "refresh":
			# 웹 버그: refreshRotatingItems 가 _shopData 를 넣기 전에 saveShop() → game_shop 에 "null" 이 저장됨 (다음에 열면 새 상점).
			#  Godot 은 갱신한 상점을 그대로 저장 — 웹이 메모리에 들고 있는 상점(_shopData)과 같아야 함
			_check(web_after.get("game_shop") == null, "웹 갱신 버그 확인 (game_shop = null)")
			web_after["game_shop"] = S["shopData"]
		ok = _cmp(name + " 저장소", _dump(c), web_after) and ok
		if S.get("calls") != null:
			ok = ok and c.rng.calls == int(S["calls"])
			if c.rng.calls != int(S["calls"]):
				print("    [%s] 난수 호출 %d ≠ 웹 %d" % [name, c.rng.calls, int(S["calls"])])
		_check(ok, "상점 [%s] 저장값·난수 = 웹" % name)
	_stat("rules.shop", (fx["shop"] as Array).size())


func _card_cls(m: Dictionary) -> String:
	var it: Dictionary = m["item"]
	return "eq-inv-card" + (" equipped-here" if m["here"] else (" equipped-other" if m["other"] else "")) + (" broken" if Js.truthy(it.get("broken")) else "") + (" legend" if Js.truthy(it.get("legend")) else "")


func _equip_model(c: Object, uids: Array) -> Dictionary:
	var tw := func(k: String, p: Dictionary) -> String: return _tw(k, p)
	var res := {"modal": {}, "cards": [], "bonus": {}}
	for uid: int in uids:
		for f: String in EquipRules.INV_FILTERS:
			var ch: Dictionary = Profile.get_char(c, uid)
			var inv := Profile.load_inventory(c)
			var rows: Array = []
			for m: Dictionary in EquipRules.modal_inventory(c, ch, f, inv):
				var st := EquipRules.stats_text(c, m["item"], tw)
				var ls: Array = []
				for l: Dictionary in EquipRules.lines(c, m["item"], ch["cls"], tw):
					ls.append([l["c"], l["text"]])
				rows.append({"eid": m["item"]["eid"], "cls": _card_cls(m), "btns": m["actions"], "stats": st if st != "" else null, "lines": ls})
			res["modal"]["%d:%s" % [uid, f]] = rows
		var b := Gear.calc_equip_bonus(c, Profile.get_char(c, uid))
		res["bonus"][str(uid)] = b
	for f2: String in ["all", "group_melee", "group_ranged", "group_support", "group_beginner"]:
		var cards: Array = []
		var inv2 := Profile.load_inventory(c)
		for ch2: Dictionary in EquipRules.equip_chars(c, f2):
			var slots: Array = []
			for s: Dictionary in EquipRules.card_slots(c, ch2, inv2):
				slots.append("unit-card-equip-slot" + (" filled" if s["item"] != null else "") + (" upgrade" if s["upgrade"] else ""))
			cards.append({"name": ch2["customName"], "party": EquipRules.in_active_party(c, ch2["uid"]), "slots": slots})
		res["cards"].append({"filter": f2, "cards": cards})
	return res


func _rules_equip() -> void:
	for E: Dictionary in fx["equip"]:
		var c := _mem_ctx(E["store"], int(E["seed"]))
		var uids := [1, 2, 3, 4, 6]
		var ok := _cmp("장비 전", _equip_model(c, uids), E["before"])
		for op: Array in E["ops"]:
			match str(op[0]):
				"equip":
					EquipRules.equip_item(c, int(op[1]), op[2])
				"unequip":
					EquipRules.unequip_item(c, int(op[1]), str(op[2]))
				"sell":
					EquipRules.sell_equip(c, op[2])
		ok = _cmp("장비 후", _equip_model(c, uids), E["after"]) and ok
		var ce: Array = []
		var inv := Profile.load_inventory(c)
		for uid: int in [1, 2, 3, 4, 5, 6]:
			var row: Array = []
			for it: Variant in inv:
				if it is Dictionary and it.get("type") == "equip":
					row.append(1 if EquipRules.can_equip(c, Profile.get_char(c, uid), it, inv) else 0)
			ce.append(row)
		ok = _cmp("끼울 수 있나", ce, E["canEquip"]) and ok
		ok = _cmp("장비 저장소", _dump(c), E["afterStore"]) and ok
		ok = ok and c.rng.calls == int(E["calls"])
		_check(ok, "장비 끼우기·빼기·판매·목록·단추·옵션 줄·더 좋은 장비 표시·보너스 = 웹 (%s)" % E["name"])
	_stat("rules.equip", (fx["equip"] as Array).size())


func _enh_list(c: Object) -> Dictionary:
	var tw := func(k: String, p: Dictionary) -> String: return _tw(k, p)
	var L := EquipRules.enhance_list(c)
	var ok: Array = []
	for it: Dictionary in L["ok"]:
		var lv := EquipRules.enhance_lv(it)
		var mx := lv >= float(D["ENHANCE_MAX_LV"])
		var who := ""
		if Js.truthy(it.get("equipped")):
			var ch: Variant = Profile.get_char(c, it["equipped"])
			if ch != null:
				who = "👤 " + _tw("gear.equipped_by", {"name": ch.get("customName")})
		var rp := Js.round_js(EquipRules.calc_enhance_rate(c, it) * 100.0)
		ok.append({"eid": it["eid"], "level": ("+%s MAX" % Num_fmt(lv)) if mx else ("+%d → +%d" % [int(lv), int(lv) + 1]),
			"rc": null if mx else "%d%% • %dG • 🔩%d" % [int(rp), int(EquipRules.calc_enhance_cost(c, it)), int(EquipRules.calc_enhance_stones(c, it))], "who": who})
	var br: Array = []
	for it2: Dictionary in L["broken"]:
		br.append({"eid": it2["eid"], "level": "💥 gear.broken", "rc": null, "who": null})
	var mats := "🔩 " + _tw("gear.mats", {"stone": EquipRules.mats_get(c, "stone"), "protect": EquipRules.mats_get(c, "protect"), "shard": EquipRules.mats_get(c, "shard")})
	return {"ok": ok, "broken": br, "mats": mats}


func _rules_enhance() -> void:
	for E: Dictionary in fx["enhance"]:
		var c := _mem_ctx(E["store"], int(E["seed"]))
		var ok := _cmp("강화 목록 전", _enh_list(c), E["list0"])
		# 확인 창 숫자
		var bad := 0
		for eid: String in (E["previews"] as Dictionary).keys():
			var W: Dictionary = E["previews"][eid]
			var it: Dictionary = EquipRules.find_item(Profile.load_inventory(c), eid)
			if Js.truthy(it.get("broken")) or EquipRules.enhance_lv(it) >= float(D["ENHANCE_MAX_LV"]):
				# 웹: 파손이면 창을 열지 않고, 최대 단계면 알림만 (창 없음)
				if W["gain"] != null or W["rate"] != null or int(W["alerts"]) != (0 if Js.truthy(it.get("broken")) else 1):
					bad += 1
					print("    확인 창 %s: 열리면 안 됨 (%s)" % [eid, str(W)])
				continue
			var pv := EquipRules.enhance_preview(c, it)
			var gain: Array = []
			for g: Array in pv["gain"]:
				gain.append("common.%s %s→%s" % [g[0], Num_fmt(g[1]), Num_fmt(g[2])])
			var mine := {"gain": " · ".join(gain), "band": str(int(pv["band_pct"])) if pv["band_pct"] >= 0.0 else null, "milestone": str(pv["milestone"]) if pv["milestone"] > 0 else null,
				"fail": "gear.enh_fail_keep" if pv["fail_keep"] else _tw("gear.enh_fail_drop", {"lv": pv["lv"] - 1.0}), "rate": str(int(pv["rp"])),
				"cost": "%s G · 🔩 %s" % [Num_fmt(pv["cost"]), _tw("gear.enh_stones", {"need": pv["stones"], "have": pv["have_stone"]})],
				"bonus": str(int(pv["bonus"])) if pv["bonus"] > 0.0 else null}
			for k: String in mine.keys():
				if not _same(mine[k], W[k]):
					bad += 1
					print("    확인 창 %s.%s: %s ≠ 웹 %s" % [eid, k, str(mine[k]), str(W[k])])
		ok = ok and bad == 0
		var res: Array = []
		for pl: Array in E["plan"]:
			res.append(EquipRules.enhance_item(c, E["store"]["game_inventory"][int(pl[0])]["eid"], bool(pl[1])))
		c.store.set_json("game_save", {"gold": 99999999})
		c.store.set_json("game_mats", {"stone": 99999, "protect": 0, "shard": 0})
		var n := 0
		while n < 3000:
			n += 1
			var r := EquipRules.enhance_item(c, E["store"]["game_inventory"][10]["eid"], false)
			if r.get("broken", false):
				res.append(r)
				break
		c.store.set_json("game_save", {"gold": 1})
		res.append(EquipRules.enhance_item(c, E["store"]["game_inventory"][11]["eid"], false))
		c.store.set_json("game_save", {"gold": 99999})
		c.store.set_json("game_mats", {"stone": 0})
		res.append(EquipRules.enhance_item(c, E["store"]["game_inventory"][11]["eid"], false))
		ok = _cmp("강화 결과", res, E["results"]) and ok
		if n != int(E["toBreak"]):
			print("    파손까지 %d번 ≠ 웹 %d" % [n, int(E["toBreak"])])
			ok = false
		var inv0: Array = E["store"]["game_inventory"]
		var rep := [EquipRules.repair_item(c, inv0[18]["eid"]), EquipRules.repair_item(c, inv0[10]["eid"]), EquipRules.repair_item(c, inv0[11]["eid"])]
		ok = _cmp("수리", rep, E["repair"]) and ok
		var dis := [EquipRules.dismantle_item(c, inv0[15]["eid"]), EquipRules.dismantle_item(c, inv0[16]["eid"]), EquipRules.dismantle_item(c, "nope")]
		ok = _cmp("분해", dis, E["dis"]) and ok
		ok = _cmp("강화 목록 후", _enh_list(c), E["list1"]) and ok
		ok = _cmp("강화 저장소", _dump(c), E["after"]) and ok
		if c.rng.calls != int(E["calls"]):
			print("    강화 난수 호출 %d ≠ 웹 %d" % [c.rng.calls, int(E["calls"])])
			ok = false
		_check(ok, "강화 목록·확인 창 숫자·강화 %d번(파손까지 %d번)·수리·분해 = 웹 (난수 %d회)" % [(E["plan"] as Array).size(), n, c.rng.calls])
		_stat("rules.enhance_attempts", (E["plan"] as Array).size() + n + 2)


func Num_fmt(v: Variant) -> String:
	return (load("res://scripts/core/num.gd") as GDScript).call("fmt", v)


func _rules_items() -> void:
	for I: Dictionary in fx["items"]:
		var c := _mem_ctx(I["store"], int(I["seed"]))
		var tab := EquipRules.item_tab(c)
		var web: String = "".join(I["tab"])
		var ok := true
		var pos := 0
		for g: Dictionary in tab["potions"]:
			var key: String = EquipRules.POTION_INFO[g["potionId"]]["nameKey"]
			var mark := "<div class=\"item-name\">%s</div><div class=\"item-exp\">EXP +%s</div></div><div class=\"item-count\">%s</div>" % [key, Num_fmt(g["exp"]), _tw("party.potion_count", {"count": g["count"]})]
			var at := web.find(mark, pos)
			if at < 0:
				ok = false
				print("    아이템 탭 물약 %s ×%d 없음" % [g["potionId"], g["count"]])
			pos = maxi(pos, at)
		for s: Dictionary in tab["sieges"]:
			var mark2 := "<div class=\"item-name\">shop.%s</div></div><div class=\"item-count\">%s</div>" % [s["siegeId"], _tw("party.potion_count", {"count": s["count"]})]
			var at2 := web.find(mark2, pos)
			if at2 < 0:
				ok = false
				print("    아이템 탭 공성 %s ×%d 없음" % [s["siegeId"], s["count"]])
			pos = maxi(pos, at2)
		for u: Dictionary in I["uses"]:
			var targets: Array = []
			var has := false
			for it: Variant in Profile.load_inventory(c):
				if it is Dictionary and it.get("type") == "potion" and it.get("potionId") == u["pid"]:
					has = true
			if has:
				for ch: Dictionary in EquipRules.potion_targets(c):
					targets.append(ch["uid"])
			var alerts: Array = []
			if has:
				var r := EquipRules.use_potion(c, str(u["pid"]), int(u["uid"]))
				var ch2: Dictionary = Profile.get_char(c, int(u["uid"]))
				if int(r["leveled"]) > 0:
					alerts.append("%s\nLv.%s → Lv.%s%s" % [ch2["customName"], Num_fmt(r["prevLv"]), Num_fmt(r["lv"]), (" (%d%s)" % [r["leveled"], "party.potion_levelup_multi"]) if int(r["leveled"]) > 1 else ""])
				else:
					alerts.append("%s %s" % [ch2["customName"], _tw("party.potion_use_success", {"exp": r["exp"]})])
			ok = _same(targets, u["targets"]) and _same(alerts, u["alerts"]) and ok
			if not (_same(targets, u["targets"]) and _same(alerts, u["alerts"])):
				print("    물약 %s → %s: %s %s ≠ 웹 %s %s" % [u["pid"], u["uid"], str(targets), str(alerts), str(u["targets"]), str(u["alerts"])])
		ok = _cmp("아이템 저장소", _dump(c), I["after"]) and ok
		var c2 := _mem_ctx({"game_roster": I["store"]["game_roster"], "game_inventory": []})
		ok = ok and not EquipRules.item_tab(c2)["has_any"] and str(I["empty"]).contains("party.no_items")
		_check(ok, "아이템 탭 묶음·물약 사용 대상·레벨업 알림·저장값 = 웹")


# ═══════════ 2) 전투 이어하기 ═══════════

const BATTLE := "res://scenes/battle/battle.tscn"


func _golden_cmds(name: String) -> Array:
	var g: Dictionary = JsonX.parse(FileAccess.get_file_as_string("res://tests/golden/" + name + ".json"))
	var cmds: Array = []
	for e: Dictionary in g["events"]:
		if e["ev"] == "cmd":
			cmds.append(e)
	return cmds


## 황금 기록 하나를 실제 세이브 전투(source store)로 — Store 에 그 세이브를 넣고 장면 설정
func _store_battle_cfg(name: String) -> Dictionary:
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	var cfg: Dictionary = BS.call("golden_cfg", name)
	store.call("clear")
	for k: String in (cfg["save"] as Dictionary).keys():
		store.call("set_json", k, cfg["save"][k])
	cfg["save"] = BS.call("store_save", store)
	cfg["source"] = "store"
	cfg["speed"] = 0.0
	cfg["story"] = "off"
	cfg["loading"] = false
	return cfg


func _drive(scene: Node, cmd: Dictionary) -> bool:
	var op: String = cmd["op"]
	match op:
		"move", "shove":
			return scene.ui_action(op) and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"attack", "heal":
			return scene.ui_action("attack") and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"skill":
			if not (scene.ui_action("skill") and scene.ui_pick_skill(int(cmd["idx"]))):
				return false
			if scene.mode == "target":
				return scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
			return true
		"wait", "defend", "overwatch":
			return scene.ui_action(op) and scene.ui_pick_face(int(cmd["dx"]), int(cmd["dy"]))
		"undo":
			return scene.ui_action("undo")
		"potion":
			return scene.ui_action("item") and scene.ui_pick_item("potion", int(cmd["idx"])) and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
		"siege", "climb":
			return scene.ui_action("item") and scene.ui_pick_item("siege", int(cmd["idx"])) and scene.ui_click_cell(int(cmd["x"]), int(cmd["y"]))
	return false


## 장면 하나로 명령 [from, to) 를 넣음 → [다음 번호, 장면]. to 에 닿으면 멈춤 (끝까지면 결과 화면까지)
func _play(cfg: Dictionary, cmds: Array, from: int, to: int) -> Array:
	var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
	BS.set("pending", cfg)
	var scene: Node = (load(BATTLE) as PackedScene).instantiate()
	root.add_child(scene)
	var ci := from
	var frames := 0
	while frames < 60000:
		await process_frame
		frames += 1
		if scene.is_over():
			break
		if not scene.is_awaiting():
			continue
		if ci >= to:
			break
		if scene.awaiting_unit_id() != int(cmds[ci]["u"]):
			print("    입력 대기 유닛 %d ≠ 명령 유닛 %d (명령 %d)" % [scene.awaiting_unit_id(), int(cmds[ci]["u"]), ci])
			break
		if not _drive(scene, cmds[ci]):
			print("    화면 조작 실패 %s" % JsonX.stringify(cmds[ci]))
			break
		ci += 1
	return [ci, scene]


func _store_dump() -> Dictionary:
	var o: Dictionary = {}
	for k: String in store.call("keys"):
		if k == ResumeRules.KEY:
			continue
		o[k] = store.call("get_json", k)
	return o


func _rc() -> Object:
	return Ctx.new(D, 1, StoreCtx.new(store))


func _resume() -> void:
	var router_dry: bool = router.get("dry_run")
	router.set("dry_run", true)
	var Flow: GDScript = load("res://scripts/ui/flow.gd")
	for spec: Array in [["siege_items_s13", [12, 30, 45], true], ["firstclear_s02", [10, 25], false], ["gear_s15", [20, 50, 70], false], ["loss_s30", [15], false]]:
		var name: String = spec[0]
		var cmds := _golden_cmds(name)
		# A: 끊지 않고 끝까지
		var cfg_a := _store_battle_cfg(name)
		var ra: Array = await _play(cfg_a, cmds, 0, cmds.size())
		var sa: Node = ra[1]
		var res_a: Dictionary = sa.result.duplicate(true)
		var dump_a := _store_dump()
		var gd_left_a: bool = store.call("has", ResumeRules.KEY)
		var autos_a: int = sa.autosaves
		sa.queue_free()
		await process_frame
		# B: 정한 곳마다 '나가기' → 로비 '전투 재개'와 같은 설정으로 새 장면 → 이어서
		var cfg_b := _store_battle_cfg(name)
		var ci := 0
		var cuts := 0
		var ok := true
		var scene: Node = null
		var cut_at: Array = spec[1]
		var bonus_gold := 0.0
		for k in cut_at.size() + 1:
			var to: int = cut_at[k] if k < cut_at.size() else cmds.size()
			var cfg: Dictionary = cfg_b
			if k > 0:
				var gd: Variant = ResumeRules.load_gd(_rc())
				if gd == null or ResumeRules.status(_rc()) != "gd":
					ok = false
					print("    [%s] %d번째 나가기 뒤 저장 전투 없음" % [name, k])
					break
				if spec[2] and k == 1:
					# 나가 있는 동안 상점에서 산 것처럼: 인벤토리 맨 앞에 물건 + 골드 → 이어하기가 물약·공성 번호를 물건으로 다시 찾아야 함
					var inv: Array = store.call("get_json", "game_inventory", [])
					inv.push_front({"type": "potion", "pid": "pot_test", "potionId": "exp_s", "exp": 50, "icon": "🧪", "quantity": 1})
					store.call("set_json", "game_inventory", inv)
					var sv: Dictionary = store.call("get_json", "game_save", {})
					sv["gold"] = Js.num(sv.get("gold")) + 1000.0
					bonus_gold = 1000.0
					store.call("set_json", "game_save", sv)
				cfg = Flow.call("resume_cfg", store, gd)
				cfg["speed"] = 0.0
				cfg["story"] = "off"
				cfg["loading"] = false
			var r: Array = await _play(cfg, cmds, ci, to)
			scene = r[1]
			if k > 0 and not scene.resumed:
				ok = false
			ci = r[0]
			if k < cut_at.size():
				if ci != to or scene.is_over():
					ok = false
					print("    [%s] 끊을 곳 %d 에 못 감 (%d)" % [name, to, ci])
					break
				scene.leave_battle()
				var lr: Dictionary = router.get("last_request")
				if lr.get("name") != "lobby" or not store.call("has", ResumeRules.KEY):
					ok = false
					print("    [%s] 나가기 → 로비·저장 안 됨 %s" % [name, str(lr)])
				cuts += 1
				scene.queue_free()
				await process_frame
		if scene != null and is_instance_valid(scene):
			ok = ok and scene.is_over()
			var res_b: Dictionary = scene.result.duplicate(true)
			var dump_b := _store_dump()
			if bonus_gold > 0.0:
				dump_b["game_save"]["gold"] = Js.num(dump_b["game_save"]["gold"]) - bonus_gold
				var inv_b: Array = dump_b["game_inventory"]
				ok = ok and inv_b.size() > 0 and inv_b[0].get("pid") == "pot_test"
				inv_b.remove_at(0)
				# 엔진 결과의 저장 사본(saveAfter)도 같은 보정
				for rr: Dictionary in [res_b]:
					if rr.get("saveAfter") is Dictionary:
						rr["saveAfter"].erase("game_inventory")
						rr["saveAfter"].erase("game_save")
				if res_b.get("rewards") is Dictionary:
					res_b["rewards"]["gold"] = Js.num(res_b["rewards"].get("gold")) - bonus_gold   # 결과의 골드 = 전투 끝 보유 골드
				res_a["saveAfter"].erase("game_inventory")
				res_a["saveAfter"].erase("game_save")
			for rr2: Dictionary in [res_a, res_b]:
				if rr2.get("saveAfter") is Dictionary:
					rr2["saveAfter"].erase(ResumeRules.KEY)
			ok = _cmp(name + " 결과", res_b, res_a) and ok
			ok = _cmp(name + " 저장소", dump_b, dump_a) and ok
			ok = ok and not store.call("has", ResumeRules.KEY) and not gd_left_a
			scene.queue_free()
			await process_frame
		_check(ok and cuts == cut_at.size() and autos_a > 0, "이어하기 [%s]: %d번 끊고 이어도 결과·저장값이 끊지 않은 것과 같음%s (자동 저장 %d번)" % [name, cuts, " · 나가 있는 동안 인벤토리·골드가 바뀌어도" if spec[2] else "", autos_a])
		_stat("resume.cuts", cuts)
	# 깨진·웹 저장 판정
	store.call("clear")
	var rc := _rc()
	_check(ResumeRules.status(rc) == "", "저장 전투 없음 → 단추 없음")
	store.call("set_json", "game_battle", {"stage": {"id": 7, "name": "x"}, "party": [1, 2, 3, 4, 5], "ter": [[]], "units": [], "turn": 3})
	_check(ResumeRules.status(rc) == "web", "웹 game_battle → 'web' (이어할 수 없음)")
	store.call("set_json", "game_battle", {"party": [1]})
	_check(ResumeRules.status(rc) == "", "웹 game_battle 에 stage 가 없으면 웹도 단추 없음")
	for bad: String in ["", "{bad", "{\"format\":1}", "{\"format\":1,\"cfg\":{\"stage\":{\"id\":1}},\"sum\":\"x\",\"state\":{}}", "5", "null"]:
		store.call("set_str", ResumeRules.KEY, bad)
		var st := ResumeRules.status(rc)
		# (4b-2) format 1 (4b-1 저장 형식)은 '이전 판' → "old" (안내 + 포기는 같음)
		var want := "" if bad == "" else ("old" if bad.begins_with("{\"format\":1") else "broken")
		_check(st == want, "깨진 gd_battle '%s' → %s" % [bad.substr(0, 30), st])
	router.set("dry_run", router_dry)
	store.call("clear")


# ═══════════ 3) 진짜 장면 ═══════════

func _scene() -> Node:
	return current_scene


func _wait_scene(tail: String, secs: float = 6.0) -> bool:
	return await _until(func() -> bool:
		var sc := current_scene
		return sc != null and sc.get_script() != null and str((sc.get_script() as Script).resource_path).ends_with(tail) and sc.is_node_ready(), secs)


func _press(b: Variant) -> bool:
	if b is BaseButton and not (b as BaseButton).disabled and (b as Control).is_visible_in_tree():
		(b as BaseButton).pressed.emit()
		return true
	return false


func _modal_btn(scr: Node, nm: String) -> Node:
	var l: Node = scr.find_child("Layer", true, false)
	return l.find_child(nm, true, false) if l != null else null


func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	root.push_input(ev)
	await process_frame
	var up := InputEventKey.new()
	up.keycode = k
	up.pressed = false
	root.push_input(up)
	await process_frame


## 기본 세이브: 웹 정답 파일의 장비 세이브 (클랜원 8 · 장비 19 · 물약 · 공성) + 골드
func _base_save(gold: float = 100000.0) -> void:
	store.call("clear")
	var st: Dictionary = fx["equip"][0]["store"]
	for k: String in st.keys():
		store.call("set_json", k, Js.deep(st[k]))
	store.call("set_json", "game_save", {"gold": gold, "cleared": [1, 2, 3]})
	store.call("set_json", "game_settings", {"language": "ko", "playSpeed": 4})
	i18n.call("_apply", "ko")


func _gold() -> float:
	return Js.num((store.call("get_json", "game_save", {}) as Dictionary).get("gold"))


func _inv() -> Array:
	return store.call("get_json", "game_inventory", [])


func _screens() -> void:
	_base_save()
	router.set("dry_run", false)
	router.set("history", [])
	router.call("go", "lobby")
	_check(await _wait_scene("ui/lobby.gd"), "로비")
	await _frames(3)
	# 아래 탭 상점
	_press(_scene().find_child("Tab_shop", true, false))
	_check(await _wait_scene("ui/shop.gd"), "아래 탭 상점 → 상점 화면")
	var sh: Node = _scene()
	await _frames(3)
	_check(store.call("has", "game_shop") and sh.title_lbl.text == i18n.call("t", "shop.title"), "상점: 처음 열면 상점을 만들어 저장 (game_shop)")
	var items: Array = (store.call("get_json", "game_shop") as Dictionary)["items"]
	_check(items.size() == 33, "판매 목록: 고정 12 + 용병 6 · 스킬북 6 · 영혼석 3 · 전직서 6 = 33 (%d)" % items.size())
	_check(sh.timer_lbl.visible and sh.timer_lbl.text.begins_with(i18n.call("t", "shop.refresh_timer", {"hours": 0, "minutes": "", "seconds": ""}).substr(0, 2)), "용병 탭: 갱신 타이머 (%s)" % sh.timer_lbl.text)
	# 용병 모집 (확인 없음)
	var g0 := _gold()
	var nchars: int = (store.call("get_json", "game_roster") as Dictionary)["chars"].size()
	var merc: Node = sh.list.find_child("Item12", true, false)
	_press(merc.find_child("Buy", true, false) if merc != null else null)
	await _frames(2)
	var nchars2: int = (store.call("get_json", "game_roster") as Dictionary)["chars"].size()
	_check(nchars2 == nchars + 1 and _gold() == g0 - Js.num(items[12]["cost"]), "용병 모집 → 클랜원 +1 · 골드 -%s" % str(items[12]["cost"]))
	_check(sh.list.find_child("Item12", true, false).find_child("Buy", true, false).disabled, "모집한 용병 단추는 '모집 완료'로 막힘")
	# 소모품 탭: 타이머 숨김 · 경험치 물약 사기 (확인 창)
	_press(sh.find_child("Tab_consumable", true, false))
	await _frames(2)
	_check(not sh.timer_lbl.visible and sh.info_title.text == i18n.call("t", "shop.subtitle_consumable"), "소모품 탭: 제목 · 타이머 숨김")
	var n_inv := _inv().size()
	g0 = _gold()
	_press(sh.list.find_child("Item1", true, false).find_child("Buy", true, false))
	await _frames(2)
	_check(sh.modal_open(), "물약 사기 → 확인 창")
	_press(_modal_btn(sh, "Yes"))
	await _frames(2)
	var last: Dictionary = _inv().back()
	_check(_inv().size() == n_inv + 1 and last.get("type") == "potion" and last.get("potionId") == "exp_m" and str(last.get("pid", "")).begins_with("pot_") and _gold() == g0 - 1000.0, "확인 → 인벤토리에 물약(pid) · 골드 -1000")
	sh.close_all_modals()
	# 룬 뽑기 (바로)
	g0 = _gold()
	_press(sh.list.find_child("RuneCard", true, false).find_child("Buy", true, false))
	await _frames(2)
	_check(_inv().back().get("type") == "rune" and _gold() == g0 - float(D["RUNE_GACHA_COST"]), "룬 뽑기 → 룬 +1 · 골드 -%s" % str(D["RUNE_GACHA_COST"]))
	sh.close_all_modals()
	# 장비 탭: 1회 뽑기 → 결과 창
	_press(sh.find_child("Tab_equip", true, false))
	await _frames(2)
	n_inv = _inv().size()
	var pity0 := Profile.load_pity(_rc())
	_press(sh.list.find_child("Gacha1", true, false).find_child("Buy", true, false))
	await _frames(3)
	_check(_inv().size() == n_inv + 1 and sh.find_child("GachaResults", true, false) != null and Profile.load_pity(_rc()) == pity0 + 1, "1회 뽑기 → 장비 +1 · 결과 창 · 천장 +1")
	sh.close_all_modals()
	_press(sh.list.find_child("Mat_stone", true, false).find_child("Buy", true, false))
	await _frames(2)
	_check(EquipRules.mats_get(_rc(), "stone") == 13.0, "강화석 사기 → 강화석 12 → 13")
	sh.close_all_modals()
	# 키보드: 탭 단추에 포커스 → Enter
	(sh.find_child("Tab_scroll", true, false) as Control).grab_focus()
	await _frames(1)
	await _key(KEY_ENTER)
	await _frames(2)
	_check(sh.cur_tab == "scroll", "키보드 Enter 로 탭 바꾸기 (전직서)")
	# 아래 탭 편성 → 장비 탭
	_press(sh.find_child("Tab_party", true, false))
	_check(await _wait_scene("ui/party_select.gd"), "아래 탭 편성")
	var ps: Node = _scene()
	await _frames(3)
	_press(ps.find_child("PageTab_equip", true, false))
	await _frames(3)
	_check(ps.gear.sections["equip"].visible and ps.find_child("EqUnit_1", true, false) != null, "장비 탭: 클랜원 카드")
	var up_shown: bool = ps.find_child("EqUnit_1", true, false).find_child("Upgrade", true, false) != null
	_check(up_shown, "더 좋은 장비 표시(↑) — 전사 무기 칸")
	_press(ps.find_child("EqUnit_1", true, false))
	await _frames(3)
	_check(ps.gear.equip_modal != null, "카드 → 장비 창")
	var inv0: Array = fx["equip"][0]["store"]["game_inventory"]
	var better: String = inv0[1]["eid"]
	var card: Node = ps.find_child("Inv_" + better, true, false)
	_press(card.find_child("Act_equip", true, false) if card != null else null)
	await _frames(3)
	var ch1: Dictionary = Profile.get_char(_rc(), 1)
	_check(ch1["equip"]["weapon"] == better and EquipRules.find_item(_inv(), better)["equipped"] == 1 and EquipRules.find_item(_inv(), inv0[0]["eid"])["equipped"] == null, "끼우기 → 저장 (새 무기 장착 · 예전 무기 풀림)")
	_press(ps.find_child("Slot_weapon", true, false))
	await _frames(3)
	_check(Profile.get_char(_rc(), 1)["equip"]["weapon"] == null, "왼쪽 칸 누르기 → 빼기")
	# 판매 (확인)
	g0 = _gold()
	var sell_eid: String = inv0[7]["eid"]
	_press(ps.find_child("Inv_" + sell_eid, true, false).find_child("Act_sell", true, false))
	await _frames(2)
	_press(_modal_btn(ps, "Yes"))
	await _frames(3)
	_check(EquipRules.find_item(_inv(), sell_eid) == null and _gold() == g0 + 30.0, "판매 → 인벤토리에서 빠지고 골드 +30")
	ps.close_all_modals()
	await _frames(2)
	# 강화 탭: 강화 (확인 창 → 강화)
	_press(ps.find_child("PageTab_enhance", true, false))
	await _frames(3)
	var target: String = inv0[3]["eid"]
	var lv0 := EquipRules.enhance_lv(EquipRules.find_item(_inv(), target))
	var st0 := EquipRules.mats_get(_rc(), "stone")
	_press(ps.find_child("Enh_" + target, true, false).find_child("EnhanceBtn", true, false))
	await _frames(3)
	_check(ps.gear.enh_modal != null and ps.find_child("Rate", true, false) != null, "강화 단추 → 확인 창 (성공률)")
	_press(_modal_btn(ps, "Enhance"))
	await _frames(3)
	var it_after: Dictionary = EquipRules.find_item(_inv(), target)
	_check(EquipRules.mats_get(_rc(), "stone") == st0 - 1.0 and EquipRules.enhance_lv(it_after) == lv0 + 1.0 and ps.find_child("Alert", true, false) != null, "강화(+0 → +1, 100%) → 저장 · 강화석 -1 · 결과 알림")
	ps.close_all_modals()
	# 소모품 탭: 물약 쓰기
	_press(ps.find_child("PageTab_item", true, false))
	await _frames(3)
	var exp_m0 := 0
	for it: Variant in _inv():
		if it is Dictionary and it.get("potionId") == "exp_m":
			exp_m0 += 1
	_press(ps.find_child("Potion_exp_m", true, false).find_child("Use", true, false))
	await _frames(3)
	_press(ps.find_child("Target_3", true, false))
	await _frames(3)
	var exp_m1 := 0
	for it2: Variant in _inv():
		if it2 is Dictionary and it2.get("potionId") == "exp_m":
			exp_m1 += 1
	_check(exp_m1 == exp_m0 - 1 and Js.num(Profile.get_char(_rc(), 3).get("exp")) == 150.0, "물약 쓰기 → 물약 -1 · 클랜원 경험치 +150")
	ps.close_all_modals()
	_check(store.call("get_str", "ps_active_tab") == "item", "마지막 탭 기억 (ps_active_tab)")
	# 로비 전투 재개: 웹 game_battle → 안내 + 포기
	store.call("set_json", "game_battle", {"stage": {"id": 7, "name": "숲"}, "party": [1, 2, 3, 4, 5], "ter": [[]]})
	router.call("go", "lobby")
	await _wait_scene("ui/lobby.gd")
	await _frames(3)
	var rb: Node = _scene().find_child("Resume", true, false)
	_check(rb != null and _scene().popups.get_child(0) == rb, "웹 game_battle → 전투 재개 단추 (맨 앞)")
	_press(rb)
	await _frames(2)
	_check(_scene().find_child("ResumeNotice", true, false) != null, "→ '웹판에서 시작된 전투' 안내")
	_press(_modal_btn(_scene(), "Abandon"))
	await _frames(2)
	_check(not store.call("has", "game_battle") and _scene().resume_btn == null, "포기 → game_battle 지움 · 단추 사라짐")
	# 로비 전투 재개: Godot 저장 전투 → 이어하기
	var cfg := _store_battle_cfg("balanced_s05")
	store.call("set_json", "game_settings", {"language": "ko", "playSpeed": 4})
	var cmds := _golden_cmds("balanced_s05")
	router.set("dry_run", true)
	var r: Array = await _play(cfg, cmds, 0, 6)
	(r[1] as Node).leave_battle()
	(r[1] as Node).queue_free()
	await _frames(2)
	router.set("dry_run", false)
	router.call("go", "lobby")
	await _wait_scene("ui/lobby.gd")
	await _frames(3)
	rb = _scene().find_child("Resume", true, false)
	_check(rb != null and _scene().resume_status == "gd", "Godot 저장 전투 → 전투 재개 단추")
	_press(rb)
	_check(await _wait_scene("battle/battle_scene.gd", 10.0), "전투 재개 → 전투 장면")
	var bt: Node = _scene()
	await _until(func() -> bool: return bt.is_awaiting() or bt.is_story_playing(), 10.0)
	_check(not bt.is_story_playing(), "이어하기는 출전 전 대사를 다시 보이지 않음")
	await _until(func() -> bool: return bt.is_awaiting(), 10.0)
	_check(bt.resumed and bt.awaiting_unit_id() == int(cmds[6]["u"]) and int(bt.eng.S["turn"]) >= 1, "이어하기: 나간 차례의 클랜원이 입력을 기다림 (uid %d)" % bt.awaiting_unit_id())
	_check(bt.ui.settings.allow_leave, "실제 세이브 전투는 설정 창에 '나가기'")
	bt.surrender()
	await _until(func() -> bool: return bt.is_over(), 5.0)
	_check(not store.call("has", ResumeRules.KEY), "전투가 끝나면 저장 전투 지움")
	await _until(func() -> bool: return bt.ui.result_view.visible and bt.ui.result_view.buttons.has("back"), 8.0)
	await create_timer(1.0).timeout
	_press(bt.ui.result_view.buttons["back"])
	await _wait_scene("ui/lobby.gd")
	await _frames(2)
	_check(_scene().find_child("Resume", true, false) == null, "끝난 뒤 로비에 전투 재개 단추 없음")
	_stat("screens.checks", 30)


## (2026-10-18) 웹 → Godot → 웹 왕복 시험(node 로 웹 코드를 돌림)은 뺐음 — 웹판 폐기 · 웹 세이브 가져오기 안 만듦 (사용자 결정).
##  보관된 도구: tools/legacy-web/outer-4b1-expect.js --roundtrip <세이브 덤프>

# ═══════════ 4) 같은 프레임 연타 (진짜 입력) ═══════════

## 같은 프레임에 누름·뗌 두 쌍 (push_input)
func _double_click(ctl: Control) -> void:
	var p := ctl.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = p
	root.push_input(mv)
	await process_frame
	for i in 2:
		for pressed: bool in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = p
			root.push_input(ev)
	await _frames(3)


## 화면에 보이게 스크롤
func _reveal(ctl: Control) -> void:
	var a: Node = ctl.get_parent()
	while a != null:
		if a is ScrollContainer:
			(a as ScrollContainer).ensure_control_visible(ctl)
			break
		a = a.get_parent()
	await _frames(2)


func _clicks() -> void:
	router.set("dry_run", false)
	var n := 0
	var bad: Array = []
	# 상점: 룬 · 1회 뽑기 · 10회 뽑기 · 강화석 · 용병 (바로 사는 단추)
	_base_save()
	router.call("go", "shop", {"tab": "consumable"})
	await _wait_scene("ui/shop.gd")
	var sh: Node = _scene()
	await _frames(3)
	var g0 := _gold()
	var b: Control = sh.list.find_child("RuneCard", true, false).find_child("Buy", true, false)
	await _reveal(b)
	await _double_click(b)
	n += 1
	if _gold() != g0 - float(D["RUNE_GACHA_COST"]):
		bad.append("룬 %s" % str(g0 - _gold()))
	sh.close_all_modals()
	await _frames(2)
	sh.switch_tab("equip")
	await _frames(3)
	for spec: Array in [["Gacha1", float(D["GACHA_COST_1"])], ["Gacha10", float(D["GACHA_COST_10"])], ["Mat_stone", float(D["MATS_PRICE"]["stone"])], ["Mat_protect", float(D["MATS_PRICE"]["protect"])]]:
		g0 = _gold()
		var bb: Control = sh.list.find_child(str(spec[0]), true, false).find_child("Buy", true, false)
		await _reveal(bb)
		await _double_click(bb)
		n += 1
		if _gold() != g0 - float(spec[1]):
			bad.append("%s %s" % [spec[0], str(g0 - _gold())])
		sh.close_all_modals()
		await _frames(2)
	sh.switch_tab("mercenary")
	await _frames(3)
	var ids: Array = ShopRules.tab_items(sh.data, "mercenary")
	var nch: int = (store.call("get_json", "game_roster") as Dictionary)["chars"].size()
	var mb: Control = sh.list.find_child("Item%d" % ids[1], true, false).find_child("Buy", true, false)
	await _reveal(mb)
	await _double_click(mb)
	n += 1
	if (store.call("get_json", "game_roster") as Dictionary)["chars"].size() != nch + 1:
		bad.append("용병")
	# 확인 창의 '확인' 두 번 (물약)
	sh.switch_tab("consumable")
	await _frames(3)
	var pb: Control = sh.list.find_child("Item0", true, false).find_child("Buy", true, false)
	await _reveal(pb)
	await _double_click(pb)   # 사기 단추 두 번 → 확인 창 하나 (두 번째 누르기가 창을 닫지 않음)
	await _frames(2)
	var confirms := 0
	for ch0: Node in sh.find_child("Layer", true, false).get_children():
		if str(ch0.name).begins_with("Confirm") and not ch0.is_queued_for_deletion():
			confirms += 1
	if confirms != 1:
		bad.append("확인 창 %d개" % confirms)
	var inv_n := _inv().size()
	g0 = _gold()
	var yes: Control = _modal_btn(sh, "Yes")
	if yes != null:
		await _double_click(yes)
	n += 1
	if _inv().size() != inv_n + 1 or _gold() != g0 - 400.0:
		bad.append("물약 확인 %d %s" % [_inv().size() - inv_n, str(g0 - _gold())])
	sh.close_all_modals()
	# 편성: 끼우기 · 빼기 · 강화 · 물약 · 판매 확인 · 분해 확인
	_base_save()
	store.call("set_str", "ps_active_tab", "equip")
	router.call("go", "party_select")
	await _wait_scene("ui/party_select.gd")
	var ps: Node = _scene()
	await _frames(3)
	ps.gear.open_equip_modal(1)
	await _frames(4)
	var inv0: Array = fx["equip"][0]["store"]["game_inventory"]
	var eb: Control = ps.find_child("Inv_" + str(inv0[5]["eid"]), true, false).find_child("Act_equip", true, false)
	await _reveal(eb)
	await _double_click(eb)
	n += 1
	if Profile.get_char(_rc(), 1)["equip"].get("armor") != inv0[5]["eid"]:
		bad.append("끼우기")
	var sl: Control = ps.find_child("Slot_armor", true, false)
	await _reveal(sl)
	var hb := (Profile.get_char(_rc(), 1)["equip"] as Dictionary).duplicate()
	await _double_click(sl)
	n += 1
	var ha: Dictionary = Profile.get_char(_rc(), 1)["equip"]
	if ha.get("armor") != null or ha.get("weapon") != hb.get("weapon") or ha.get("helmet") != hb.get("helmet"):
		bad.append("빼기 %s" % JsonX.stringify(ha))
	ps.close_all_modals()
	await _frames(2)
	# 판매 확인 두 번
	ps.gear.open_equip_modal(3)
	await _frames(4)
	g0 = _gold()
	var sb: Control = ps.find_child("Inv_" + str(inv0[7]["eid"]), true, false).find_child("Act_sell", true, false)
	await _reveal(sb)
	await _double_click(sb)
	await _frames(2)
	var y2: Control = _modal_btn(ps, "Yes")
	if y2 != null:
		await _double_click(y2)
	n += 1
	if _gold() != g0 + 30.0:
		bad.append("판매 %s" % str(_gold() - g0))
	ps.close_all_modals()
	await _frames(2)
	# 강화 두 번 (창의 강화 단추 — 창은 결과 뒤 닫힘)
	ps.switch_page_tab("enhance")
	await _frames(3)
	var tgt: String = inv0[3]["eid"]
	var st0 := EquipRules.mats_get(_rc(), "stone")
	ps.gear.open_enhance(tgt)
	await _frames(3)
	var en: Control = _modal_btn(ps, "Enhance")
	await _double_click(en)
	n += 1
	if EquipRules.mats_get(_rc(), "stone") != st0 - 1.0:
		bad.append("강화 강화석 %s" % str(st0 - EquipRules.mats_get(_rc(), "stone")))
	ps.close_all_modals()
	await _frames(2)
	# 물약 대상 두 번
	ps.switch_page_tab("item")
	await _frames(3)
	var before_n := _inv().size()
	ps.gear.open_potion_use("exp_l")
	await _frames(3)
	await _double_click(ps.find_child("Target_2", true, false))
	n += 1
	if _inv().size() != before_n - 1:
		bad.append("물약 %d" % (before_n - _inv().size()))
	ps.close_all_modals()
	# 로비 전투 재개 두 번 → 장면 하나
	_base_save()
	store.call("set_json", "game_battle", {"stage": {"id": 3}})
	router.call("go", "lobby")
	await _wait_scene("ui/lobby.gd")
	await _frames(3)
	await _double_click(_scene().find_child("Resume", true, false))
	n += 1
	var notices := 0
	for ch: Node in _scene().find_child("Layer", true, false).get_children():
		if str(ch.name).begins_with("ResumeNotice") and not ch.is_queued_for_deletion():
			notices += 1
	if notices != 1:
		bad.append("전투 재개 안내 %d개" % notices)
	_scene().close_all_modals()
	for x: String in bad:
		print("    " + x)
	_check(bad.is_empty(), "같은 프레임 두 번 누르기(진짜 입력 push_input) %d가지 → 모두 한 번만 (사기·뽑기·재료·모집·확인·끼우기·빼기·판매·강화·물약·재개)" % n)
	_stat("clicks.cases", n)


# ═══════════ 5) 이상한 세이브 ═══════════

var _rng := RandomNumberGenerator.new()


func _junk(depth: int = 0) -> Variant:
	var pool: Array = [null, 0, -1, 1, 1.5, 3, 99999, -0.5, "", "x", "50", "exp_s", "siege_bomb", "potion_heal", "fire", "warrior", "weapon", "rare", true, false]
	var r := _rng.randi() % 10
	if depth < 2 and r == 0:
		var a: Array = []
		for i in _rng.randi() % 4:
			a.append(_junk(depth + 1))
		return a
	if depth < 2 and r == 1:
		var d: Dictionary = {}
		for i in _rng.randi() % 3:
			d[["id", "v", "cls", "type", "1"][_rng.randi() % 5]] = _junk(depth + 1)
		return d
	return pool[_rng.randi() % pool.size()]


func _maybe(v: Variant, p: float = 0.3) -> Variant:
	return _junk() if _rng.randf() < p else v


## 정상 세이브(장비·물약·상점)에 이상한 값을 섞음
func _fuzz_4b1() -> Dictionary:
	var st: Dictionary = Js.deep(fx["equip"][0]["store"])
	var inv: Array = []
	for it: Variant in st["game_inventory"]:
		var x: Variant = Js.deep(it)
		if x is Dictionary and _rng.randf() < 0.4:
			var keys: Array = (x as Dictionary).keys()
			x[keys[_rng.randi() % keys.size()]] = _junk()
		inv.append(_maybe(x, 0.08))
	for i in _rng.randi() % 4:
		inv.append({"type": _maybe(["equip", "potion", "battle_potion", "siege", "rune", "scroll"][_rng.randi() % 6], 0.3), "eid": _maybe("e%d" % i), "potionId": _junk(),
			"siegeId": _junk(), "enchant": _junk(), "scrollCls": _junk(), "slot": _maybe("weapon"), "rarity": _maybe("rare"), "stats": _maybe({"atk": 3}), "templateId": _maybe("wpn_warrior"),
			"subs": _junk(), "eOpts": _junk(), "fx": _junk(), "cOpt": _junk(), "clsRestrict": _junk(), "equipped": _junk(), "legend": _junk(), "setCls": _junk(), "enhanceLv": _junk(), "quantity": _junk()})
	st["game_inventory"] = inv
	var shop: Variant = Js.deep(fx["shop"][0]["after"]["game_shop"])
	if shop is Dictionary:
		for it2: Variant in shop["items"]:
			if it2 is Dictionary and _rng.randf() < 0.3:
				var k2: Array = (it2 as Dictionary).keys()
				it2[k2[_rng.randi() % k2.size()]] = _junk()
		if _rng.randf() < 0.2:
			shop["ts"] = _junk()
		if _rng.randf() < 0.1:
			shop["items"] = _junk()
	st["game_shop"] = _maybe(shop, 0.1)
	st["game_mats"] = _maybe({"stone": _maybe(5), "protect": _maybe(1), "shard": _maybe(6)}, 0.2)
	st["game_gacha_pity"] = _maybe(98, 0.3)
	st["game_soul"] = _maybe({"stones": _maybe({"mage": 1}), "frags": _junk()}, 0.3)
	st["game_save"] = _maybe({"gold": _maybe(50000.0, 0.2), "cleared": _maybe([1, 2])}, 0.1)
	var raw: Dictionary = {}
	for k: String in st.keys():
		var r := _rng.randf()
		if r < 0.05:
			continue
		elif r < 0.08:
			raw[k] = ""
		elif r < 0.1:
			raw[k] = "{bad"
		else:
			raw[k] = JsonX.stringify(st[k])
	raw["ps_active_tab"] = ["equip", "item", "enhance", "party", "zz"][_rng.randi() % 5]
	if _rng.randf() < 0.3:
		raw["gd_battle"] = ["{bad", "{\"format\":1,\"cfg\":{},\"state\":{}}", "5", JsonX.stringify({"format": 1, "cfg": {"stage": {"id": 1}}, "sum": "x", "state": {"units": 1}})][_rng.randi() % 4]
	if _rng.randf() < 0.3:
		raw["game_battle"] = JsonX.stringify({"stage": _junk(), "ter": _junk()})
	return raw


## 세이브 하나로 새 화면·창 모두 → [오류 수, 진입 실패]
func _try_4b1(raw: Dictionary) -> Array:
	store.call("clear")
	for k: String in raw.keys():
		store.call("set_str", k, raw[k])
	i18n.call("reload")
	var e0 := _counter.errors.size()
	var fails: Array = []
	router.set("params", {})
	# 상점: 모든 탭 · 사기 단추 모두
	var sh: Node = (load("res://scenes/outer/shop.tscn") as PackedScene).instantiate()
	root.add_child(sh)
	await process_frame
	if not sh.is_node_ready():
		fails.append("shop")
	for tab: String in ShopRules.TABS:
		sh.switch_tab(tab)
		for idx: int in ShopRules.tab_items(sh.data, tab):
			sh._act_frame = -1
			sh.buy_item(idx)
			var y: Node = _modal_btn(sh, "Yes")
			if y != null:
				(y as Button).pressed.emit()
			sh.close_all_modals()
	for f: Callable in [sh.buy_rune, func() -> void: sh.do_gacha(1), func() -> void: sh.buy_mat("stone"), func() -> void: sh.exchange_legend("dawn")]:
		sh._act_frame = -1
		f.call()
		var y2: Node = _modal_btn(sh, "Yes")
		if y2 != null:
			(y2 as Button).pressed.emit()
		sh.close_all_modals()
	await process_frame
	sh.queue_free()
	await process_frame
	# 편성: 저장된 탭으로 열고 모든 탭 · 장비 창(모든 클랜원 · 모든 필터 · 단추) · 강화 창 · 물약 창
	var ps: Node = (load("res://scenes/outer/party_select.tscn") as PackedScene).instantiate()
	root.add_child(ps)
	await process_frame
	if not ps.is_node_ready():
		fails.append("party_select")
	for tab2: String in ["equip", "item", "enhance", "party"]:
		ps.switch_page_tab(tab2)
	for ch: Dictionary in EquipRules.equip_chars(_rc(), "all"):
		ps.gear.open_equip_modal(ch["uid"])
		for f2: String in EquipRules.INV_FILTERS:
			ps.gear.inv_filter = f2
			ps.gear.render_equip_modal()
		for m: Dictionary in EquipRules.modal_inventory(_rc(), ch, "all", Profile.load_inventory(_rc())).slice(0, 4):
			ps._act_frame = -1
			if (m["actions"] as Array).has("equip"):
				ps.gear.do_equip(m["item"].get("eid"))
		ps.close_all_modals()
	var L := EquipRules.enhance_list(_rc())
	for it: Dictionary in (L["ok"] as Array).slice(0, 4) + (L["broken"] as Array).slice(0, 2):
		ps.gear.open_enhance(it.get("eid"))
		ps._act_frame = -1
		ps.gear.execute_enhance(it.get("eid"))
		ps.close_all_modals()
		ps._act_frame = -1
		ps.gear.ask_repair(it.get("eid"))
		var y3: Node = _modal_btn(ps, "Yes")
		if y3 != null:
			(y3 as Button).pressed.emit()
		ps.close_all_modals()
	for pid: String in ["exp_s", "exp_m", "exp_l"]:
		ps.gear.open_potion_use(pid)
		var tg: Array = EquipRules.potion_targets(_rc())
		if not tg.is_empty():
			ps._act_frame = -1
			ps.gear.use_potion(pid, tg[0]["uid"])
		ps.close_all_modals()
	await process_frame
	ps.queue_free()
	await process_frame
	# 로비: 전투 재개
	var lb: Node = (load("res://scenes/outer/lobby.tscn") as PackedScene).instantiate()
	root.add_child(lb)
	await process_frame
	if lb.get("setup_dialog") != null:
		lb.commander_setup_done()
	if lb.resume_btn != null and lb.resume_status != "gd":
		lb.press_resume()
		var ab: Node = _modal_btn(lb, "Abandon")
		if ab != null:
			(ab as Button).pressed.emit()
	await process_frame
	lb.queue_free()
	await process_frame
	return [_counter.errors.size() - e0, fails]


func _weird() -> void:
	root.size = Vector2i(1280, 720)
	var router_dry: bool = router.get("dry_run")
	router.set("dry_run", true)
	# 정상 세이브는 한 바이트도 바뀌지 않음 (다듬기)
	store.call("clear")
	var good: Dictionary = fx["shop"][4]["after"]
	var raw0: Dictionary = {}
	for k: String in good.keys():
		raw0[k] = JsonX.stringify(good[k]) if typeof(good[k]) != TYPE_STRING else good[k]
	raw0["ps_active_tab"] = "enhance"
	for k2: String in raw0.keys():
		store.call("set_str", k2, raw0[k2])
	var eq: Dictionary = fx["equip"][0]["afterStore"]
	for k3: String in eq.keys():
		store.call("set_str", k3, JsonX.stringify(eq[k3]))
		raw0[k3] = JsonX.stringify(eq[k3])
	var ch := SaveSanitize.sanitize(_rc())
	var same := true
	for k4: String in raw0.keys():
		if str(store.call("get_str", k4)) != str(raw0[k4]):
			same = false
			print("    정상 세이브가 바뀜: %s" % k4)
	_check(same and ch.is_empty(), "정상 세이브(상점·장비·재료·천장·편성 탭)는 다듬기에서 한 바이트도 안 바뀜 (%s)" % str(ch))
	# 손으로 만든 이상한 값
	var cases: Array = [
		{"game_shop": "5"}, {"game_shop": "[1,2]"}, {"game_shop": JsonX.stringify({"ts": "x", "items": "y"})},
		{"game_shop": JsonX.stringify({"ts": 1, "items": [null, 3, {"type": "char", "cls": "nope", "pot": 1, "cost": 5}, {"type": "skillbook", "skillId": 3, "cost": "x"}, {"type": "zz", "cost": 1}, {"type": "siege", "siegeId": 5, "cost": 1}]})},
		{"game_mats": "[1]"}, {"game_mats": JsonX.stringify({"stone": "x", "protect": null, "shard": [1]})}, {"game_gacha_pity": "abc"}, {"game_gacha_pity": "{}"},
		{"game_inventory": JsonX.stringify([{"type": "equip", "eid": "a", "slot": "weapon", "rarity": "rare", "stats": {"atk": 5}, "templateId": "wpn_warrior", "subs": "x", "eOpts": [1], "fx": 5, "cOpt": {"id": 1},
			"clsRestrict": "warrior", "equipped": "x", "legend": 7, "setCls": 4, "setId": 3, "hand": 2, "enhanceLv": -3, "enhanceBonus": "x", "broken": "yes"},
			{"type": "potion", "potionId": 4, "exp": "x"}, {"type": "potion", "potionId": "exp_s", "exp": "x"}, {"type": "battle_potion", "potionId": "zz"}, {"type": "siege", "siegeId": 1},
			{"type": "rune", "enchant": []}, {"type": "scroll"}, {"type": "equip", "eid": "b", "slot": "ring", "rarity": "epic", "stats": {}, "templateId": "nope", "enhanceLv": 99}])},
		{"ps_active_tab": "zz"}, {"gd_battle": "{bad"}, {"game_battle": JsonX.stringify({"stage": "x"})},
	]
	var bad: Array = []
	for i in cases.size():
		var raw: Dictionary = {}
		var base: Dictionary = fx["equip"][0]["store"]
		for k5: String in base.keys():
			raw[k5] = JsonX.stringify(base[k5])
		raw.merge(cases[i], true)
		var r: Array = await _try_4b1(raw)
		if int(r[0]) > 0 or not (r[1] as Array).is_empty():
			bad.append("[손 %d] 오류 %d · 진입 실패 %s" % [i, r[0], str(r[1])])
	_check(bad.is_empty(), "손으로 만든 이상한 세이브 %d개: 새 화면·창·단추 모두 오류 0" % cases.size())
	var n := 60
	var fbad: Array = []
	for j in n:
		_rng.seed = 5000 + j
		var r2: Array = await _try_4b1(_fuzz_4b1())
		if int(r2[0]) > 0 or not (r2[1] as Array).is_empty():
			fbad.append("[시드 %d] 오류 %d · 진입 실패 %s" % [5000 + j, r2[0], str(r2[1])])
	for b: String in (bad + fbad).slice(0, 20):
		print("    " + b)
	_check(fbad.is_empty(), "무작위로 망가뜨린 세이브 %d개: 오류 0 (문제 %d)" % [n, fbad.size()])
	_stat("weird.manual", cases.size())
	_stat("weird.fuzz", n)
	router.set("dry_run", router_dry)
	store.call("clear")


# ═══════════ 6) 6개 언어 넘침·두부 ═══════════

## 화면 안 글자 부품 검사 (4a 와 같은 규칙) → [넘침, 두부, 수]
func _audit(scr: Node, lang: String) -> Array:
	var overflow: Array = []
	var tofu: Array = []
	var n := 0
	var vr := root.get_visible_rect()
	var stack: Array = [scr]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is Control and not (nd as Control).is_visible_in_tree():
			continue
		if nd.get_meta("overflow_ok", false) or nd.is_queued_for_deletion() or str(nd.name) == "Hideout":
			continue
		stack.append_array(nd.get_children())
		if not (nd is Control):
			continue
		var ctl := nd as Control
		var txt := ""
		if ctl is Label:
			txt = (ctl as Label).text
		elif ctl is Button:
			txt = (ctl as Button).text
		if txt != "":
			n += 1
			for i in txt.length():
				var cp := txt.unicode_at(i)
				if cp < 32 or cp == 0x200B:
					continue
				if not FontsT.chain_has_char(lang, cp):
					tofu.append("%s '%s' U+%04X" % [ctl.get_path(), txt.substr(0, 20), cp])
					break
		if ctl is Label:
			var l := ctl as Label
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF and not l.clip_text and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
				if l.get_minimum_size().x > l.size.x + 1.0:
					overflow.append("%s 좁음 %.0f>%.0f '%s'" % [ctl.get_path(), l.get_minimum_size().x, l.size.x, l.text.substr(0, 24)])
		var par := ctl.get_parent() as Control
		if par != null and not (par is ScrollContainer) and ctl.size.x > 0.0 and not (ctl is ScrollContainer and par.name == "Box"):
			var pr := par.get_global_rect().grow(3.0)
			var r := ctl.get_global_rect()
			if not pr.encloses(r) and r.size.x > 0.0:
				overflow.append("%s 부모 밖 %s ⊄ %s '%s'" % [ctl.get_path(), str(r), str(pr), txt.substr(0, 20)])
		if txt != "":
			var r2 := ctl.get_global_rect()
			var in_scroll := false
			var a: Node = ctl.get_parent()
			while a != null:
				if a is ScrollContainer:
					in_scroll = true
					var sr := (a as Control).get_global_rect().grow(2.0)
					if r2.position.x < sr.position.x or r2.end.x > sr.end.x:
						overflow.append("%s 스크롤 가로 밖 '%s'" % [ctl.get_path(), txt.substr(0, 20)])
					break
				a = a.get_parent()
			if not in_scroll and not vr.grow(1.0).encloses(r2):
				overflow.append("%s 화면 밖 %s '%s'" % [ctl.get_path(), str(r2), txt.substr(0, 20)])
	return [overflow, tofu, n]


## 넘침이 잘 드러나는 세이브: 긴 이름 · 장비 많이 · 파손 · 강화 · 상점 · 재료 · 웹 전투 저장
func _rich_save() -> void:
	_base_save(1234567.0)
	var r: Dictionary = store.call("get_json", "game_roster")
	r["chars"][1]["customName"] = "가나다라마바사아자차"
	r["chars"][2]["customName"] = "WWWWWWWWWW"
	store.call("set_json", "game_roster", r)
	store.call("set_json", "game_shop", fx["shop"][0]["after"]["game_shop"])
	store.call("set_json", "game_mats", {"stone": 99, "protect": 9, "shard": 12})
	store.call("set_json", "game_soul", {"stones": {"mage": 12}, "frags": {"mage": 7}})
	store.call("set_json", "game_battle", {"stage": {"id": 3, "name": "x"}})


func _langs() -> void:
	var all: Array = []
	var total := 0
	router.set("dry_run", true)
	for res: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = res
		for lang: String in LANGS:
			_rich_save()
			i18n.call("_apply", lang)
			# 상점: 탭 6개 · 뽑기 결과 창 · 확인 창
			for tab: String in ShopRules.TABS:
				router.set("params", {"tab": tab})
				var sh: Node = (load("res://scenes/outer/shop.tscn") as PackedScene).instantiate()
				root.add_child(sh)
				await _frames(4)
				var states: Array = ["base"]
				if tab == "equip":
					states.append("gacha")
				if tab == "consumable":
					states.append("confirm")
				for stt: String in states:
					if stt == "gacha":
						sh.show_gacha_results(ShopRules.gacha(_mem_ctx({"game_save": {"gold": 99999}, "game_gacha_pity": 98}, 7), 10))
					elif stt == "confirm":
						sh._act_frame = -1
						sh.buy_item(ShopRules.tab_items(sh.data, "consumable")[0])
					await _frames(3)
					var a: Array = _audit(sh, lang)
					total += int(a[2])
					for o: String in a[0]:
						all.append("[%dx%d %s shop.%s %s] 넘침 %s" % [res.x, res.y, lang, tab, stt, o])
					for tf: String in a[1]:
						all.append("[%dx%d %s shop.%s %s] 두부 %s" % [res.x, res.y, lang, tab, stt, tf])
				sh.queue_free()
				await _frames(2)
			# 편성: 장비 탭 · 장비 창(클랜원 둘) · 소모품 탭 · 물약 창 · 강화 탭 · 강화 창
			var ps: Node = (load("res://scenes/outer/party_select.tscn") as PackedScene).instantiate()
			root.add_child(ps)
			await _frames(3)
			for stt2: String in ["equip", "modal1", "modal2", "modal_armor", "item", "potion", "enhance", "enh_modal", "enh_modal2"]:
				ps.close_all_modals()
				match stt2:
					"equip", "item", "enhance":
						ps.switch_page_tab(stt2)
					"modal1":
						ps.switch_page_tab("equip")
						ps.gear.open_equip_modal(1)
					"modal2":
						ps.gear.open_equip_modal(2)
					"modal_armor":
						ps.gear.open_equip_modal(2)
						ps.gear.inv_filter = "armor"
						ps.gear.render_equip_modal()
					"potion":
						ps.switch_page_tab("item")
						ps.gear.open_potion_use("exp_m")
					"enh_modal":
						ps.switch_page_tab("enhance")
						ps.gear.open_enhance(fx["equip"][0]["store"]["game_inventory"][5]["eid"])
					"enh_modal2":
						ps.gear.open_enhance(fx["equip"][0]["store"]["game_inventory"][13]["eid"])
				await _frames(4)
				var a2: Array = _audit(ps, lang)
				total += int(a2[2])
				for o2: String in a2[0]:
					all.append("[%dx%d %s party.%s] 넘침 %s" % [res.x, res.y, lang, stt2, o2])
				for tf2: String in a2[1]:
					all.append("[%dx%d %s party.%s] 두부 %s" % [res.x, res.y, lang, stt2, tf2])
			ps.queue_free()
			await _frames(2)
			# 로비 전투 재개 안내 · 전투 설정 창(나가기 단추 · 나가기 확인)
			var lb: Node = (load("res://scenes/outer/lobby.tscn") as PackedScene).instantiate()
			root.add_child(lb)
			await _frames(3)
			lb.press_resume()
			await _frames(3)
			var a3: Array = _audit(lb, lang)
			total += int(a3[2])
			for o3: String in a3[0]:
				all.append("[%dx%d %s lobby.resume] 넘침 %s" % [res.x, res.y, lang, o3])
			for tf3: String in a3[1]:
				all.append("[%dx%d %s lobby.resume] 두부 %s" % [res.x, res.y, lang, tf3])
			lb.queue_free()
			await _frames(2)
			var cfg := _store_battle_cfg("balanced_s05")
			var BS: GDScript = load("res://scripts/battle/battle_scene.gd")
			BS.set("pending", cfg)
			var bt: Node = (load(BATTLE) as PackedScene).instantiate()
			root.add_child(bt)
			await _frames(3)
			for stt3: String in ["panel", "leave"]:
				if stt3 == "panel":
					bt.ui.settings.open()
				else:
					bt.ui.settings.ask_confirm("leave")
				await _frames(3)
				var a4: Array = _audit(bt.ui.settings, lang)
				total += int(a4[2])
				for o4: String in a4[0]:
					all.append("[%dx%d %s battle.%s] 넘침 %s" % [res.x, res.y, lang, stt3, o4])
				for tf4: String in a4[1]:
					all.append("[%dx%d %s battle.%s] 두부 %s" % [res.x, res.y, lang, stt3, tf4])
			bt.queue_free()
			await _frames(2)
	for p: String in all.slice(0, 40):
		print("    " + p)
	var ovf := 0
	var tf5 := 0
	for p2: String in all:
		if p2.contains("] 두부"):
			tf5 += 1
		else:
			ovf += 1
	_check(ovf == 0, "6개 언어 × 1280×720·1920×1080 넘침 0 (글자 부품 %d개 검사, 넘침 %d)" % [total, ovf])
	_check(tf5 == 0, "6개 언어 두부 0 (두부 %d)" % tf5)
	_stat("lang.text_controls", total)
	_stat("lang.overflow", ovf)
	root.size = Vector2i(1280, 720)
	i18n.call("_apply", "ko")
	router.set("dry_run", false)
