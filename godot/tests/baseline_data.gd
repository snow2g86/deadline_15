extends RefCounted
## 기준 시험이 읽는 데이터 고르기 (2026-10-18 데이터 원본 이전)
##
##  황금 기록(tests/golden)과 웹 정답(tests/fixtures/outer_*_web.json)은 웹판 코드로 만든 **고정된 기준**이라 다시 만들 수 없다.
##  이 기준은 그때의 데이터로만 맞으므로, 기준과 비교하는 시험은 그때 데이터의 사본 tests/baseline/data/ 를 읽는다
##  (godot/data 를 고쳐도 — 밸런스 조정·대사 고침 — 기준 시험이 깨지지 않고, 규칙 코드가 바뀌었는지만 계속 확인).
##  번역은 기준 사본 위에 지금 데이터에만 있는 키를 더함 (기준 뒤에 생긴 화면 글 gd.* 가 키 그대로 보이지 않게).
##
##  -- --live : 기준 사본 대신 지금 데이터(godot/data)로 — 데이터를 바꾼 뒤 기준과 얼마나 달라졌는지 보는 '영향 보고'용 (실패해도 이상한 게 아님)
##  apply(tree) 는 시험 맨 처음(장면을 띄우기 전)에 부를 것 → "baseline" 또는 "live"

const DIR := "res://tests/baseline/data/"


static func wants_live() -> bool:
	return OS.get_cmdline_user_args().has("--live")


static func apply(tree: SceneTree) -> String:
	if wants_live():
		print("  (데이터: 지금 godot/data — --live, 기준과 다를 수 있음)")
		return "live"
	var db: Node = tree.root.get_node_or_null("DataDB")
	if db != null:
		apply_db(db)
	var i18n: Node = tree.root.get_node_or_null("I18n")
	if i18n != null:
		i18n.call("reload")
	return "baseline"


## DataDB 하나를 기준 데이터로 (오토로드가 없는 시험이 직접 만든 DataDB 에도)
static func apply_db(db: Object) -> bool:
	if wants_live():
		return bool(db.call("load_all"))
	return bool(db.call("use_dir", DIR, true))
