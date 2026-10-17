extends "res://scripts/ui/codex_screen.gd"
## 가이드 — 웹 guide.html (4b-2). 탭 7개(시작 · 성장 · 장비 · 전투 · 맵 환경 · 구간 공략 · 스토리)
##  문장은 번역 키(codex.g.* · codex.c.*), 표는 게임 데이터 (scripts/logic/codex_rules.gd guide_panel). 장비 탭의 '도감 장비 탭' 글은 누르면 도감 장비 탭으로.


func page_id() -> String:
	return "guide"


func title_text() -> String:
	return rules.tt("nav.guide", rules.T("g.title")) if rules != null else ""


func emblem() -> String:
	return "📚"


func hero_title() -> String:
	return rules.T("g.title")


func hero_sub() -> String:
	return rules.T("g.sub")


func hero_stats() -> Array:
	return [[100, rules.T("c.st_stages")], [5, rules.T("c.st_party")], [12, rules.T("c.st_classes")]]


func tabs() -> Array:
	return CodexRules.GUIDE_TABS


func tab_text(k: String) -> String:
	return rules.T("g.tab_" + k)


func foot() -> String:
	return rules.T("g.foot")


func panel(k: String) -> Array:
	return rules.guide_panel(k)
