extends SceneTree
## 글자 시험 — 6개 언어의 모든 글자가 그 언어 글꼴 사슬(scripts/core/fonts.gd)에 있는지 (두부 □ 없음)
##   Godot --headless --path godot --script res://tests/check_glyphs.gd
##  1) 언어 팩(data/lang — 화면 글 gd.* 포함) + 대본(data/story)의 모든 문자열 글자 → Font.has_char (사슬 어딘가에)
##     그림 문자(이모지·기호 U+2190~2BFF·U+1F000~1FAFF·변형 선택자·ZWJ)는 빼고 셈 — 화면은 이모지를 아이콘 그림으로 바꾸거나 지움
##  2) 한자·가나는 사슬 맨 앞(그 언어) 글꼴에 있어야 함 → 통합 한자 글자 모양이 그 언어 것 (ja 直·骨 / zh-CN 简体 / zh-TW 繁體)
##  3) 견본 문장(대본·UI)을 실제로 모양 잡기(TextLine)해서 모든 글리프가 우리 사슬의 글꼴에서 왔는지(시스템 대체 글꼴·빈 글리프 0)
##  4) 플레이어가 입력할 수 있는 섞인 이름(한글·가나·간체·번체·라틴 악센트)이 6개 언어 사슬 모두에서 두부 없이 나오는지
##  끝에 글꼴 파일 크기·읽는 시간·메모리 증가를 출력 (보고용)

const Fonts := preload("res://scripts/core/fonts.gd")
const LANGS: PackedStringArray = ["ko", "en", "es", "ja", "zh-CN", "zh-TW"]
const MIXED_NAMES := ["리안 브람 세라", "リアン・ブラム", "里安 布拉姆 塞拉", "萊恩 布拉姆 賽拉", "Ñandú Àlex Çelik Ölüm", "김철수ガオン里安萊恩", "ㄱㄴ ㅏㅑ 가힣 ぁゖ ァヺ 々〆"]

var _pass := 0
var _fail := 0
var _failures: PackedStringArray = []
var _started := false


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	print("── 글자 시험 (6개 언어 글꼴 사슬) ──")
	# 비용 측정: I18n 오토로드가 이미 읽어 두었으므로, 캐시를 건너뛰고 새로 읽어 시간·메모리를 잼 (보고용 — 판정 안 함)
	var cost := []
	var keep := []
	for key: String in ["kr", "jp", "sc", "tc"]:
		var t0 := Time.get_ticks_usec()
		var m0 := OS.get_static_memory_usage()
		var ff: FontFile = ResourceLoader.load(Fonts.DIR + String(Fonts.FILES[key]), "", ResourceLoader.CACHE_MODE_IGNORE)
		ff.has_char(0x4E00)   # 글꼴 열기까지
		keep.append(ff)
		cost.append("%s %.0fms +%.1fMB" % [key, (Time.get_ticks_usec() - t0) / 1000.0, (OS.get_static_memory_usage() - m0) / 1048576.0])
	keep.clear()
	var ts := TextServerManager.get_primary_interface()

	for lang: String in LANGS:
		print("[%s] 사슬 %s" % [lang, Fonts.chain_keys(lang)])
		var chars := {}
		var texts: Array[String] = []
		for path: String in ["res://data/lang/%s.json" % lang, "res://data/story/%s.json" % lang]:
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			_check(d is Dictionary, "%s 읽음" % path)
			if d is Dictionary and (d as Dictionary).has("settings"):
				# 언어 이름 라벨(日本語·简体中文·繁體中文)은 화면 언어와 상관없이 그 언어 글꼴(Fonts.for_lang)로 그림 → 따로 검사
				for c3: String in LANGS:
					(d["settings"] as Dictionary).erase("language_" + c3)
			_collect(d, chars, texts)
		var missing := []
		var skipped := 0
		var primary: FontFile = Fonts.chain_files(lang)[0]
		var not_primary := []
		var n_cjk := 0
		for c: int in chars.keys():
			if _is_pictograph(c) or c < 0x20:
				skipped += 1
				continue
			if not Fonts.chain_has_char(lang, c):
				missing.append("%s U+%X" % [String.chr(c), c])
			if _is_han_or_kana(c):
				n_cjk += 1
				if not primary.has_char(c):
					not_primary.append(String.chr(c))
		_check(missing.is_empty(), "%s: 글자 %d종 모두 사슬에 있음 (그림 문자 %d종 제외) %s" % [lang, chars.size() - skipped, skipped, str(missing.slice(0, 10))])
		_check(not_primary.is_empty(), "%s: 한자·가나 %d종이 모두 맨 앞 글꼴(%s)에 있음 → 그 언어 글자 모양 %s" % [lang, n_cjk, Fonts.chain_keys(lang)[0], "".join(not_primary.slice(0, 20))])
		# 견본 문장 모양 잡기: 대본 앞쪽 + UI 문자열 몇 개 + 긴 것 몇 개
		var font: Font = Fonts.for_lang(lang, 400)
		var rids := {}
		for r: RID in font.get_rids():
			rids[r] = true
		var samples: Array[String] = []
		for i in range(0, texts.size(), maxi(1, texts.size() / 60)):
			samples.append(texts[i])
		var bad_glyphs := []
		var han_from_primary := 0
		var han_total := 0
		var primary_rid: RID = font.get_rids()[0]
		for s: String in samples:
			var tl := TextLine.new()
			tl.add_string(s, font, 16)
			for g: Dictionary in ts.shaped_text_get_glyphs(tl.get_rid()):
				var st := int(g.get("start", 0))
				var c: int = s.unicode_at(st) if st < s.length() else 0
				if _is_pictograph(c) or c < 0x20 or c == 0x20:
					continue
				if int(g.get("index", 0)) == 0 or not rids.has(g.get("font_rid")):
					bad_glyphs.append("%s(U+%X)" % [String.chr(c), c])
				elif _is_han_or_kana(c):
					han_total += 1
					if g.get("font_rid") == primary_rid:
						han_from_primary += 1
		_check(bad_glyphs.is_empty(), "%s: 견본 %d문장 모양 잡기 — 모든 글리프가 우리 사슬에서 옴 (빈·시스템 글리프 0) %s" % [lang, samples.size(), str(bad_glyphs.slice(0, 10))])
		_check(han_total == han_from_primary, "%s: 견본 속 한자·가나 %d자 모두 맨 앞 글꼴로 그림 (%d)" % [lang, han_total, han_from_primary])
		# 플레이어가 입력한 섞인 이름
		var tofu := []
		for nm: String in MIXED_NAMES:
			for i in nm.length():
				var c2 := nm.unicode_at(i)
				if c2 != 0x20 and not Fonts.chain_has_char(lang, c2):
					tofu.append(String.chr(c2))
		_check(tofu.is_empty(), "%s: 섞인 이름(한글·가나·간체·번체·악센트) 두부 없음 %s" % [lang, str(tofu)])

	# 같은 한자가 언어마다 다른 글꼴(글자 모양)로: 直 은 ja→JP, zh-CN→SC, zh-TW→TC, ko→KR
	# (ko 는 뺌: 한국어 한자(KS X 1001)는 부분 집합 글꼴에 남기지 않음 — 데이터에 한자가 없고 용량이 큼. 한자 이름은 사슬 뒤 글꼴(일본·중국 상용 한자)로 두부 없이 나옴, 아래 '한자 이름')
	var want := {"ja": 0, "zh-CN": 0, "zh-TW": 0}
	var ok_var := true
	for lang: String in want.keys():
		var f: Font = Fonts.for_lang(lang, 400)
		var tl2 := TextLine.new()
		tl2.add_string("直骨", f, 16)
		for g: Dictionary in ts.shaped_text_get_glyphs(tl2.get_rid()):
			if g.get("font_rid") != f.get_rids()[0]:
				ok_var = false
	_check(ok_var, "直骨 이 ja·zh-CN·zh-TW 각자 맨 앞 글꼴(JP·SC·TC)로 그려짐")
	# 이름 입력 허용 범위: 한글 완성형 11,172자 전부 · 히라가나·가타카나 전부 · 라틴 악센트 — 6개 언어 사슬 모두에 (부분 집합 글꼴이 이 범위를 남김)
	var rng_miss := []
	for lang2: String in LANGS:
		var n_miss := 0
		for ch2: int in range(0xAC00, 0xD7A4):
			if not Fonts.chain_has_char(lang2, ch2):
				n_miss += 1
		for ch3: int in range(0x3041, 0x30FB):   # 원본 Noto 에도 없는 빈 코드(3097·3098)는 뺌
			if ch3 != 0x3097 and ch3 != 0x3098 and not Fonts.chain_has_char(lang2, ch3):
				n_miss += 1
		for ch4: int in range(0x20, 0x100):       # 기본 라틴 + 라틴-1 (악센트·¿¡ñ). 라틴 확장-A 는 원본 Noto CJK 에도 없음
			if ch4 >= 0x7F and ch4 < 0xA0:
				continue
			if not Fonts.chain_has_char(lang2, ch4):
				n_miss += 1
		if n_miss > 0:
			rng_miss.append("%s:%d" % [lang2, n_miss])
	_check(rng_miss.is_empty(), "이름 입력 범위(한글 11,172 · 가나 · 라틴-1)가 6개 언어 사슬 모두에 있음 %s" % str(rng_miss))
	var han_miss := []
	for lang: String in LANGS:
		for ch: String in "直骨李王金":   # 흔한 한자 이름 글자 — 어느 언어 화면에서도 사슬 안에 있어야 함 (없으면 시스템 글꼴 몫)
			if not Fonts.chain_has_char(lang, ch.unicode_at(0)):
				han_miss.append("%s:%s" % [lang, ch])
	_check(han_miss.is_empty(), "한자 이름(直骨李王金)이 6개 언어 사슬 모두에 있음 %s" % str(han_miss))
	# 언어 이름 라벨: 각자 자기 언어 사슬 맨 앞 글꼴에 다 있음 (설정 창 단추)
	var lbl_bad := []
	var ko_pack: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/lang/ko.json"))
	for lang: String in LANGS:
		var label: String = str(((ko_pack as Dictionary)["settings"] as Dictionary)["language_" + lang])
		var prim: FontFile = Fonts.chain_files(lang)[0]
		for i in label.length():
			if not prim.has_char(label.unicode_at(i)):
				lbl_bad.append("%s:%s" % [lang, String.chr(label.unicode_at(i))])
	_check(lbl_bad.is_empty(), "언어 이름 라벨 6개가 각자 언어 글꼴에 모두 있음 %s" % str(lbl_bad))

	var total := Fonts.files_size()
	print("[글꼴] 파일 4개 %.1f MB · 파일별 읽기 시간·정적 메모리: %s (지금 읽힌 파일 %s)" % [total / 1048576.0, ", ".join(cost), Fonts.loaded_files()])
	_finish()


func _collect(v: Variant, chars: Dictionary, texts: Array[String]) -> void:
	if v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			_collect(v[k], chars, texts)
	elif v is Array:
		for x: Variant in v:
			_collect(x, chars, texts)
	elif v is String:
		var s: String = v
		if s.is_empty():
			return
		texts.append(s)
		for i in s.length():
			chars[s.unicode_at(i)] = true


## 그림 문자 (이모지·딩뱃·화살표·기호 블록, 변형 선택자, ZWJ, 국기 문자) — 화면은 아이콘 그림으로 바꾸거나 지움
static func _is_pictograph(c: int) -> bool:
	return (c >= 0x2190 and c <= 0x2BFF and not (c >= 0x2460 and c <= 0x24FF)) or (c >= 0x1F000 and c <= 0x1FAFF) \
		or c == 0xFE0F or c == 0xFE0E or c == 0x200D or (c >= 0xE0000 and c <= 0xE007F)


static func _is_han_or_kana(c: int) -> bool:
	return (c >= 0x4E00 and c <= 0x9FFF) or (c >= 0x3400 and c <= 0x4DBF) or (c >= 0x3040 and c <= 0x30FF) or (c >= 0xF900 and c <= 0xFAFF)


func _check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  " + label)
	else:
		_fail += 1
		_failures.append(label)
		print("  FAIL  " + label)


func _finish() -> void:
	print("──────────────────────────────")
	if _fail == 0:
		print("RESULT: PASS (%d개 통과)" % _pass)
	else:
		print("RESULT: FAIL (%d개 실패 / %d개 통과)" % [_fail, _pass])
		for f: String in _failures:
			print("  - " + f)
	quit(0 if _fail == 0 else 1)
