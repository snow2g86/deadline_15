extends SceneTree
## 뒷모습 삭제(2026-10-23, 3D 교체 예정) 뒤 시험 — 뒷모습 그림이 없어도 앞모습으로 대신 보이고 오류·빈 화면이 없는지
##   Godot --headless --path godot --script res://tests/check_back_view.gd
##  1) character/ 아래에 `_b` 그림(정지·시트)이 하나도 없음 (map/tree_b 는 나무 그림이라 다른 것)
##  2) SpriteDB.sheet/still 의 back 인자: 파일이 없으면 앞모습과 똑같은 시트·그림을 돌려줌 (13직업 × 남녀 × 4동작)
##  3) UnitView.set_facing_back(true) → 앞모습 시트로 그려짐 (몸 그림 있음), 켰다 껐다 해도 오류 0, 소환수도 오류 0
##  (뒷모습을 읽는 자리: scripts/battle/sprite_db.gd · unit_view.gd — godot/README.md '뒷모습')

const Iso := preload("res://scripts/battle/iso.gd")
const SpriteDB := preload("res://scripts/battle/sprite_db.gd")
const UnitView := preload("res://scripts/battle/unit_view.gd")

var _pass := 0
var _fail := 0
var _errs: Array = []


class ErrCounter extends Logger:
	var errors: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	_main.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		_pass += 1
		print("  PASS  " + what)
	else:
		_fail += 1
		print("  FAIL  " + what)


func _find_back(dir: String, out: Array) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if (f.ends_with(".png") or f.ends_with(".webp")) and (f.contains("_b.") or f.contains("_b_")):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_find_back(dir.path_join(d), out)


func _main() -> void:
	var ec := ErrCounter.new()
	OS.add_logger(ec)
	print("── 뒷모습 삭제 시험 ──")
	var found: Array = []
	_find_back("res://assets/image/character", found)
	_check(found.is_empty(), "character/ 아래 뒷모습(_b) 그림 0개 %s" % str(found.slice(0, 3)))

	var sp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sprites.json"))
	var sdb := SpriteDB.new(sp)
	var classes := ["archer", "assassin", "brawler", "commander", "knight", "lancer", "mage", "novice", "priest", "sapper", "shaman", "summoner", "warrior"]
	var n_same := 0
	var n_all := 0
	var n_still := 0
	for cls: String in classes:
		for g: String in ["m", "f"]:
			for kind: String in ["idle", "combat", "hit", "attack"]:
				var f: Variant = sdb.sheet(cls, g, kind)
				var b: Variant = sdb.sheet(cls, g, kind, true)
				n_all += 1
				if f == b:
					n_same += 1
			var st_f: Variant = sdb.still(cls, g)
			var st_b: Variant = sdb.still(cls, g, true)
			if st_f != null and st_b != null and st_f["tex"] == st_b["tex"]:
				n_still += 1
	_check(n_same == n_all, "back 시트 요청 → 파일이 없어 앞모습 시트 그대로 (%d/%d)" % [n_same, n_all])
	_check(n_still == classes.size() * 2, "back 정지 그림 요청 → 앞모습 그림 그대로 (%d/%d)" % [n_still, classes.size() * 2])
	_check(sdb.sheet("knight", "m", "idle", true) != null, "back 요청이 null 이 아님 (빈 화면 방지)")

	# UnitView
	var iso := Iso.new(8, 9, JSON.parse_string(FileAccess.get_file_as_string("res://data/tiles.json"))["TI"])
	var ter: Array = []
	for r in 9:
		var row: Array = []
		for c in 8:
			row.append("plain")
		ter.append(row)
	iso.ter = ter
	var views: Array = []
	for i in classes.size():
		var uv := UnitView.new()
		var d := {"id": i + 1, "team": "ally", "cls": classes[i], "gender": "f" if i % 2 == 1 else "m", "x": i % 8, "y": 2, "hp": 10.0, "mhp": 10.0, "res": 0.0, "maxRes": 0.0, "resType": "", "face": [1, 0], "buffs": []}
		root.add_child(uv)
		uv.setup(iso, sdb, d, 1.0)
		views.append(uv)
	var summon := UnitView.new()
	root.add_child(summon)
	summon.setup(iso, sdb, {"id": 99, "team": "ally", "cls": "summon_golem", "gender": "m", "x": 1, "y": 4, "hp": 5.0, "mhp": 5.0, "res": 0.0, "maxRes": 0.0, "resType": "", "face": [1, 0], "buffs": []}, 1.0)
	views.append(summon)
	for i in 3:
		await process_frame
	var base_tex: Array = []
	for uv: UnitView in views:
		base_tex.append(uv.body.tex)
	for uv: UnitView in views:
		uv.set_facing_back(true)
	for i in 4:
		await process_frame
	var same_tex := 0
	var has_body := 0
	for i in views.size():
		var uv: UnitView = views[i]
		if uv.body.tex != null:
			has_body += 1
		if uv.body.tex == base_tex[i]:
			same_tex += 1
	_check(has_body == views.size(), "뒷모습을 켜도 모든 유닛 몸 그림 있음 (%d/%d, 소환수 포함)" % [has_body, views.size()])
	_check(same_tex == views.size(), "뒷모습을 켜면 앞모습과 같은 그림 (%d/%d)" % [same_tex, views.size()])
	for uv: UnitView in views:
		uv.play_once("attack")
		uv.set_facing_back(false)
	for i in 3:
		await process_frame
	_check(views.all(func(u: UnitView) -> bool: return u.body.tex != null), "껐다 켜도 몸 그림 유지")
	_check(ec.errors.is_empty(), "Godot 오류 0 %s" % str(ec.errors.slice(0, 3)))
	print("──────────────────────────────")
	print("RESULT: %s (%d개 통과 / %d개 실패)" % ["PASS" if _fail == 0 else "FAIL", _pass, _fail])
	quit(0 if _fail == 0 else 1)
