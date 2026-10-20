extends RefCounted
## 한국어 조사 고르기 — 번역 글의 '이(가) · 은(는) · 을(를) · 와(과) · (으)로' 를 앞 말의 받침에 맞춰 하나로 (6a QA).
##  I18n.t 가 현재 언어가 ko 일 때만 부름 (다른 언어는 손대지 않음). 값이 들어간 뒤의 글에 적용하므로 {name} 이 무엇이든 맞음.
##   받침 있음 → 이 · 은 · 을 · 과 · 으로,  없음 → 가 · 는 · 를 · 와 · 로.  (으)로 는 받침이 ㄹ 이어도 '로'
##  앞 말은 조사 바로 앞의 글자들 — 공백·괄호·따옴표는 건너뛰고, ')' 로 끝나면 괄호 안 마지막 말 (예: '{name}({cls})이(가)' → cls 기준)
##
##  규칙 (단순하게 — 완벽하지 않음, README '6a 검수·QA 수정' 에 같은 표):
##   · 한글: 마지막 글자의 받침 그대로 (없음 / 있음 / ㄹ)
##   · 숫자: 읽는 소리의 마지막 — 0 영(있음) · 1 일(ㄹ) · 2 이 · 3 삼(있음) · 4 사 · 5 오 · 6 육(있음) · 7 칠(ㄹ) · 8 팔(ㄹ) · 9 구.
##     두 자리 이상은 끝자리가 정함 (11 십일 → ㄹ · 21 이십일 → ㄹ · 12 십이 → 없음),
##     끝이 0 이면 십(ㅂ) · 백(ㄱ) · 천(ㄴ) · 만(ㄴ) 이라 받침 있음 (ㄹ 아님). 쉼표(1,000)는 건너뜀
##   · 영문 한 글자(앞이 글자가 아님): 글자 이름 — L 엘 · R 알 → ㄹ,  M 엠 · N 엔 → 있음,  나머지 없음 (A 에이 · B 비 · S 에스 · F 에프 …)
##   · 영문 낱말(두 글자 이상): 마지막 글자 — l r → ㄹ,  m n b k p d t g → 있음 (Tom 톰 · Lian 리안 · Book 북 · Brad 브래드(드, 있음으로 봄)),
##     그 밖(모음 · s z x f v c j h w y q) → 없음 (Eris 에리스 · Max 맥스 · Jane 제인은 'e' 가 소리 안 나서 틀림 — 한계)
##   · 그 밖(한자·가나·기호): 없음

const PAIRS := [["이(가)", "이", "가"], ["은(는)", "은", "는"], ["을(를)", "을", "를"], ["와(과)", "과", "와"]]
const RO := "(으)로"
## 읽는 소리의 받침 (숫자): 2 = ㄹ, 1 = 그 밖의 받침, 0 = 없음
const DIGIT := {"0": 1, "1": 2, "2": 0, "3": 1, "4": 0, "5": 0, "6": 1, "7": 2, "8": 2, "9": 0}
const LETTER_NAME := {"l": 2, "r": 2, "m": 1, "n": 1}
const WORD_END := {"l": 2, "r": 2, "m": 1, "n": 1, "b": 1, "k": 1, "p": 1, "d": 1, "t": 1, "g": 1}


## 한글 한 글자의 받침: 0 = 없음, 1 = 있음, 2 = ㄹ 받침
static func hangul_batchim(c: int) -> int:
	var j := (c - 0xAC00) % 28
	if j == 0:
		return 0
	return 2 if j == 8 else 1


static func _is_latin(ch: String) -> bool:
	if ch == "":
		return false
	var c := ch.unicode_at(0)
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122)


static func _is_digit(ch: String) -> bool:
	return ch != "" and ch.unicode_at(0) >= 48 and ch.unicode_at(0) <= 57


## text[i] 앞의 말의 받침 (0 없음 · 1 있음 · 2 ㄹ)
static func batchim_before(text: String, i: int) -> int:
	var k := i - 1
	while k >= 0 and " ()「」『』'\"[]{}".contains(text.substr(k, 1)):
		k -= 1
	if k < 0:
		return 0
	var ch := text.substr(k, 1)
	var c := ch.unicode_at(0)
	if c >= 0xAC00 and c <= 0xD7A3:
		return hangul_batchim(c)
	if _is_digit(ch):
		# 숫자 덩어리 (쉼표 포함)의 끝자리
		if ch == "0":
			return 1   # 십 · 백 · 천 · 만 · 영
		return int(DIGIT[ch])
	if _is_latin(ch):
		var s := k
		while s > 0 and _is_latin(text.substr(s - 1, 1)):
			s -= 1
		var low := ch.to_lower()
		if k - s + 1 == 1:
			return int(LETTER_NAME.get(low, 0))
		return int(WORD_END.get(low, 0))
	return 0


static func fix(text: String) -> String:
	if not (text.contains("(가)") or text.contains("(는)") or text.contains("(를)") or text.contains("(과)") or text.contains(RO)):
		return text
	var out := text
	for pr: Array in PAIRS:
		var pat: String = pr[0]
		var at := out.find(pat)
		while at >= 0:
			var b := batchim_before(out, at)
			out = out.substr(0, at) + (pr[1] if b > 0 else pr[2]) + out.substr(at + pat.length())
			at = out.find(pat, at)
	var at2 := out.find(RO)
	while at2 >= 0:
		var b2 := batchim_before(out, at2)
		out = out.substr(0, at2) + ("으로" if b2 == 1 else "로") + out.substr(at2 + RO.length())
		at2 = out.find(RO, at2)
	return out
