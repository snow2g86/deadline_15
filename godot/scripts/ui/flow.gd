extends RefCounted
## 출격 흐름 — game_nav(웹과 같은 모양) → 전투 장면 설정 → Router.launch_battle
##  웹은 game_nav 를 저장하고 battle.html 로 이동, 전투 페이지가 읽고 지움(boot.js _initBattlePage → clearNav).
##  여기서는 같은 game_nav 를 쓰고, 전투로 넘어갈 때 지운 뒤 Store 의 모든 키를 전투 세이브로 넘긴다 (battle_scene.gd store_save).

const BattleScene := preload("res://scripts/battle/battle_scene.gd")
const PartyRules := preload("res://scripts/logic/party_rules.gd")


## nav = { cStage, party?, practiceMode? } → 전투 설정 (source "store": 끝나면 결과를 Store 에 되돌려 씀)
static func battle_cfg(store_node: Node, c: Object, nav: Dictionary) -> Dictionary:
	PartyRules.clear_nav(c)
	var cfg := {"save": BattleScene.store_save(store_node), "stage": PartyRules.stage_spec(c, nav.get("cStage")),
		"practice": bool(nav.get("practiceMode", false)), "seed": randi() & 0x7fffffff, "source": "store"}
	if nav.get("party") is Array:
		cfg["party"] = (nav["party"] as Array).duplicate()
	return cfg


static func start_battle(router: Node, store_node: Node, c: Object, nav: Dictionary) -> void:
	router.call("launch_battle", battle_cfg(store_node, c, nav))


## launch_stage / next_stage 결과 { to, nav } 대로 전투 또는 편성 화면
static func follow(router: Node, store_node: Node, c: Object, res: Dictionary) -> void:
	if res.get("to") == "battle":
		start_battle(router, store_node, c, res["nav"])
	else:
		router.call("go", "party_select")


## (4b-1) 이어하기 설정: 저장 전투(gd_battle 의 {cfg, state}) + 지금 Store 값
static func resume_cfg(store_node: Node, gd: Dictionary) -> Dictionary:
	var g: Dictionary = gd["cfg"]
	var cfg := {"save": BattleScene.store_save(store_node), "stage": g["stage"], "practice": bool(g.get("practice", false)),
		"seed": int(g.get("seed", 1)), "source": "store", "resume": gd["state"]}
	if g.get("party") is Array:
		cfg["party"] = (g["party"] as Array).duplicate()
	return cfg
