extends SceneTree
## 확률표 내보내기 (결제층 A) — 게임 안 '확률 정보' 창과 같은 표를 스토어 설명에 붙일 글로.
##   Godot --headless --path godot --script res://tools/odds_export.gd            → docs/store/probabilities.<언어>.md 6개를 씀
##   Godot --headless --path godot --script res://tools/odds_export.gd -- --check → 쓰지 않고 지금 파일과 같은지만 (다르면 종료 코드 1)
##  숫자는 scripts/logic/odds_rules.gd 가 godot/data 에서 계산 (손으로 적은 숫자 없음). 데이터를 고친 뒤 다시 돌릴 것 — check_iap 이 낡은 파일을 잡음.
##  언어: ko · en · ja · zh-CN · zh-TW · es (I18n 과 같은 번역 gd.odds.*)

const OddsRules := preload("res://scripts/logic/odds_rules.gd")
const Ctx := preload("res://scripts/logic/ctx.gd")

const LANGS := ["ko", "en", "ja", "zh-CN", "zh-TW", "es"]


static func out_path(lang: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("../docs/store/probabilities.%s.md" % lang).simplify_path()


## 한 언어의 글 (I18n 노드로 번역 — 시험도 이 함수를 부름)
static func render_md(c: Object, i18n: Node, lang: String) -> String:
	i18n.call("_apply", lang)
	var tfn := func(k: String, p: Dictionary) -> String: return str(i18n.call("t", k, p))
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	var s := "# %s\n\n" % tfn.call("gd.odds.doc_title", {})
	s += "%s\n\n" % tfn.call("gd.odds.doc_note", {"ver": ver})
	s += "%s\n" % tfn.call("gd.odds.source", {})
	for sec: Dictionary in OddsRules.sections(c, tfn):
		s += "\n## %s\n\n" % str(sec["title"])
		var head: Array = sec["head"]
		s += "| " + " | ".join(head.map(func(x: Variant) -> String: return _cell(str(x)))) + " |\n"
		s += "|" + "|".join(head.map(func(_x: Variant) -> String: return "---")) + "|\n"
		for row: Array in sec["rows"]:
			s += "| " + " | ".join(row.map(func(x: Variant) -> String: return _cell(str(x)))) + " |\n"
		s += "\n"
		for n: Variant in sec["notes"]:
			s += "- %s\n" % str(n)
	return s


static func _cell(x: String) -> String:
	return x.replace("|", "\\|").replace("\n", " ")


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var check := OS.get_cmdline_user_args().has("--check")
	var db: Node = root.get_node("DataDB")
	var i18n: Node = root.get_node("I18n")
	var c := Ctx.new(Ctx.globals_from_db(db), 1)
	var bad: Array = []
	for lang: String in LANGS:
		var md := render_md(c, i18n, lang)
		var p := out_path(lang)
		var cur := FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""
		if check:
			if cur != md:
				bad.append(p)
			continue
		DirAccess.make_dir_recursive_absolute(p.get_base_dir())
		if cur == md:
			print("[odds_export] 같음 %s" % p)
			continue
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string(md)
		f.close()
		print("[odds_export] 씀 %s" % p)
	if check and not bad.is_empty():
		print("ODDS_EXPORT: STALE %s — tools/odds_export.gd 를 돌리세요" % str(bad))
		quit(1)
		return
	print("ODDS_EXPORT: OK")
	quit(0)
