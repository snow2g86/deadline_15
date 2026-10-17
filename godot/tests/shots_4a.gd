extends SceneTree
## 4a 화면 사진 (창 모드) → tests/screens/4a_*.png (git 제외)
##   Godot --path godot --resolution 1280x720 --script res://tests/shots_4a.gd   [-- --lang ja] [-- --size 1920x1080]
##  저장은 user://test_shots_4a_save.json (진짜 세이브는 건드리지 않음)

const PartyRules := preload("res://scripts/logic/party_rules.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")
const SaveStore := preload("res://scripts/logic/save_store.gd")
const Gear := preload("res://scripts/logic/gear.gd")
const OUT := "res://tests/screens/"
const SAVE := "user://test_shots_4a_save.json"

var store: Node
var i18n: Node
var D: Dictionary
var tag := ""


func _initialize() -> void:
	_main.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path := ProjectSettings.globalize_path(OUT + "4a_" + name + tag + ".png")
	img.save_png(path)
	print("  사진: " + path)


func _open(path: String) -> Node:
	var scr: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scr)
	await _frames(4)
	return scr


func _save_mid() -> void:
	store.call("clear")
	var c := Ctx.new(D, 7, SaveStore.new())
	var chars: Array = [{"uid": 100, "cls": "commander", "nameId": null, "customName": "하늘", "setup": true, "lv": 1, "exp": 0, "dead": false, "hp": 95, "atk": 12, "def": 6, "move": 2, "range": 2,
		"pot": {"hp": 8.4, "atk": 1.6, "def": 0.6, "actionRec": 0.12}, "actionRec": 1.22, "gender": "f", "buffer": 2}]
	var classes := ["warrior", "archer", "priest", "knight", "mage", "assassin", "novice", "lancer", "shaman"]
	for i in range(1, 10):
		var cls: String = classes[i - 1]
		var b: Dictionary = D["JAB"][cls]["base"]
		chars.append({"uid": i, "cls": cls, "nameId": i * 7, "lv": 12 - i, "exp": 0, "dead": false, "hp": b["hp"] + 40, "atk": b["atk"] + 9, "def": b["def"] + 4, "move": b["move"], "range": b["range"],
			"pot": {"hp": 8.3, "atk": 2.7, "def": 1.7, "actionRec": 0.16}, "actionRec": 1.16, "gender": "f" if i % 2 == 0 else "m"})
	var w1 := Gear.generate_equip(c, Gear.equip_template(c, "wpn_warrior"), "epic")
	var h1 := Gear.generate_equip(c, Gear.equip_template(c, "plate_helm"), "rare")
	w1["enhanceLv"] = 5
	w1["equipped"] = 1
	h1["equipped"] = 1
	chars[1]["equip"] = {"weapon": w1["eid"], "helmet": h1["eid"]}
	store.call("set_json", "game_roster", {"chars": chars, "nextId": 101})
	store.call("set_json", "game_parties", PartyRules.create_default_parties([1, 2, 3, 4, 5]))
	var cl: Array = range(1, 14)
	store.call("set_json", "game_save", {"gold": 4820.0, "cleared": cl, "stars": {"1": [1, 1, 1], "2": [1, 0, 1], "3": [1, 1, 0], "11": [1, 1, 1]}})
	store.call("set_json", "game_inventory", [w1, h1])
	store.call("set_json", "game_story_seen", {"ep1_pro": true, "s1_pre": true, "ep1_epi": true, "s10_post": true})
	store.call("set_json", "game_soul", {"stones": {"warrior": 2}, "frags": {"warrior": 6}})


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	store = root.get_node("Store")
	i18n = root.get_node("I18n")
	var db: Node = root.get_node("DataDB")
	D = Ctx.globals_from_db(db)
	store.call("use_path", SAVE)
	var li := args.find("--lang")
	var lang := args[li + 1] if li >= 0 and li + 1 < args.size() else "ko"
	var si := args.find("--size")
	if si >= 0 and si + 1 < args.size():
		var p := args[si + 1].split("x")
		root.size = Vector2i(p[0].to_int(), p[1].to_int())
		tag = "_" + args[si + 1]
	if lang != "ko":
		tag += "_" + lang
	await _frames(3)
	# 첫 실행 로비 (지휘관 설정)
	store.call("clear")
	i18n.call("_apply", lang)
	var lobby := await _open("res://scenes/outer/lobby.tscn")
	await _shot("lobby_first")
	lobby.queue_free()
	_save_mid()
	i18n.call("_apply", lang)
	lobby = await _open("res://scenes/outer/lobby.tscn")
	await _frames(40)
	await _shot("lobby")
	lobby.queue_free()
	var ss := await _open("res://scenes/outer/stage_select.tscn")
	await _shot("stage_episodes")
	ss.open_episode(1)
	await _shot("stage_list")
	ss.show_stage_info(10)
	await _shot("stage_info")
	ss.close_all_modals()
	ss.open_daily()
	await _shot("daily")
	ss.close_all_modals()
	ss.open_replay()
	await _shot("replay")
	ss.close_all_modals()
	# 출전 전 스토리 (2-1: 에피소드 2 프롤로그)
	ss.open_episode(2)
	await _frames(2)
	ss._story_prepare(ss.ProgressRules.find_stage(ss.c, 11))
	var scenes: Array = ss.story.call("intro")
	ss.play_scenes(scenes, false, func() -> void: pass)
	await _frames(90)
	ss.story_view.call("advance")
	await _frames(10)
	await _shot("story")
	ss.story_view.call("skip")
	await _frames(20)
	ss.queue_free()
	store.call("set_str", "ps_can_start", "true")
	store.call("set_json", "game_nav", {"cStage": {"id": 14}})
	var ps := await _open("res://scenes/outer/party_select.tscn")
	await _shot("party")
	ps.open_unit_modal(0)
	await _shot("unit_modal")
	ps.queue_free()
	var st := await _open("res://scenes/outer/settings.tscn")
	await _shot("settings")
	st.queue_free()
	await _frames(3)
	store.call("clear")
	store.call("flush")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0)
