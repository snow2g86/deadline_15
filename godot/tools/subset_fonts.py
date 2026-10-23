#!/usr/bin/env python3
"""개발용: Noto Sans KR/JP/SC/TC 가변 글꼴 → 쓰는 글자만 남긴 부분 집합 글꼴 (배포 용량 줄이기, 2026-10-23)

  원본 전체 글꼴(OFL)   godot/assets/fonts/src/*.ttf   (git 제외 · .gdignore — Godot 이 읽지 않음, 내보내기에 안 들어감.
                          없으면 `git show ad48239:godot/assets/fonts/NotoSansKR-VariableFont_wght.ttf > godot/assets/fonts/src/NotoSansKR-VariableFont_wght.ttf` 처럼 꺼냄 (JP·SC·TC 도). 꺼낸 뒤 `touch godot/assets/fonts/src/.gdignore` 필수(없으면 Godot이 원본 47MB를 가져와 내보내기에 들어감) 또는 Google Fonts 에서 받음)
  부분 집합 결과        godot/assets/fonts/*.ttf        (같은 파일 이름 — scripts/core/fonts.gd · project.godot 은 그대로)

사용:
  python3 godot/tools/subset_fonts.py                 # 만들어서 assets/fonts/ 에 덮어씀
  python3 godot/tools/subset_fonts.py --report        # 글자 수·예상 크기만 (아무것도 쓰지 않음)
  python3 godot/tools/subset_fonts.py --out <폴더>    # 다른 폴더에 만듦 (시험용)
언제 다시 돌리나: 번역·대본·데이터(godot/data/**.json)나 코드 속 한글/한자 문구를 바꿔 새 글자가 생겼을 때.
  (돌리기 전에도 `Godot --headless --path godot --script res://tests/check_glyphs.gd` 가 빠진 글자(두부)를 알려 줍니다.)
필요: fonttools (brew install fonttools — pyftsubset 과 같은 파이썬을 씀). 다운로드 없음.

■ 어떤 글자를 남기나 — '언어마다 글꼴 사슬'(scripts/core/fonts.gd CHAINS)을 그대로 따라감
  언어 L 에 필요한 글자 = 공통(데이터·코드의 모든 글, 기본 라틴·기호) ∪ 그 언어 팩·대본 ∪ 이름 입력 허용 범위(NAME)
  그 글자는 L 의 사슬에서 '원본 글꼴에 그 글자가 있는 첫 글꼴'에 남김 — 원본일 때와 같은 글꼴·같은 글자 모양으로 그려짐.
■ 이름 입력(지휘관 이름·성소 이름 바꾸기·도감 검색) 때문에 데이터에 없는 글자도 넉넉히 남김
  · 한글 완성형 전부(11,172) + 호환 자모 · 히라가나·가타카나 전부 · 라틴(악센트 포함) · 전각/반각 · 문장부호 · 기호
  · 한자: ko/en/es = KS X 1001 한자 4,888 · ja = JIS X 0208 한자 6,355 · zh-CN = GB 2312 한자 6,763 · zh-TW = Big5 한자 13,053
    (파이썬 내장 코덱(euc_kr·shift_jis·gb2312·big5)에서 뽑음 — 다운로드 없음)
  · 이 밖의 글자(희귀 한자·키릴·이모지 등)는 '시스템 대체 글꼴'이 그림 (모든 글꼴 파일의 allow_system_fallback=true —
    macOS·Windows·Android·iOS 에 CJK 시스템 글꼴이 있어 두부가 아님). 이 글꼴들은 원본 전체 글꼴보다 글자 수만 적을 뿐 같은 굵기 축(wght)을 가짐.
"""
import argparse, glob, json, os, re, shutil, subprocess, sys, tempfile

try:
    from fontTools.ttLib import TTFont
except ImportError:   # pyftsubset 이 쓰는 파이썬으로 다시 실행
    exe = shutil.which('pyftsubset')
    if exe and not os.environ.get('SUBSET_FONTS_REEXEC'):
        py = open(exe).readline().strip()[2:].split()[0]
        os.environ['SUBSET_FONTS_REEXEC'] = '1'
        os.execv(py, [py] + sys.argv)
    sys.exit('fonttools 가 필요합니다 (brew install fonttools)')

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = os.path.join(ROOT, 'godot')
FONTS = os.path.join(GODOT, 'assets/fonts')
SRC = os.path.join(FONTS, 'src')
FILES = {'kr': 'NotoSansKR-VariableFont_wght.ttf', 'jp': 'NotoSansJP-VariableFont_wght.ttf',
         'sc': 'NotoSansSC-VariableFont_wght.ttf', 'tc': 'NotoSansTC-VariableFont_wght.ttf'}
# scripts/core/fonts.gd CHAINS 와 같아야 함 (check_glyphs 가 그림 결과로 확인)
CHAINS = {'ko': ['kr', 'jp', 'sc', 'tc'], 'en': ['kr', 'jp', 'sc', 'tc'], 'es': ['kr', 'jp', 'sc', 'tc'],
          'ja': ['jp', 'kr', 'sc'], 'zh-CN': ['sc', 'tc', 'kr'], 'zh-TW': ['tc', 'sc', 'kr']}


def rng(*pairs):
    s = set()
    for a, b in pairs:
        s.update(range(a, b + 1))
    return s


# 기본: 라틴(악센트·확장 A·B) · 일반 문장부호 · 통화 · 글자꼴 기호 · 화살표 · 수학 · 도형 · 기호 · 한중일 문장부호 · 가나 · 전각/반각
BASE = rng((0x20, 0x7E), (0xA0, 0x24F), (0x2C6, 0x2DD), (0x2000, 0x206F), (0x20A0, 0x20BF), (0x2100, 0x214F), (0x2190, 0x21FF),
           (0x2200, 0x22FF), (0x2460, 0x24FF), (0x2500, 0x25FF), (0x2600, 0x27BF), (0x2B00, 0x2BFF),
           (0x3000, 0x303F), (0x3040, 0x309F), (0x30A0, 0x30FF), (0x31F0, 0x31FF), (0xFE30, 0xFE4F), (0xFF00, 0xFFEF), (0x1E00, 0x1EFF))
HANGUL = rng((0xAC00, 0xD7A3), (0x3131, 0x318E))
BOPOMOFO = rng((0x3105, 0x312F))


def codec_han(codec, lead_lo, lead_hi, trail_lo=0x40, trail_hi=0xFE):
    """파이썬 코덱이 아는 한자(CJK 통합 한자 U+4E00~9FFF·3400~4DBF·F900~FAFF)만"""
    out = set()
    for a in range(lead_lo, lead_hi + 1):
        for b in range(trail_lo, trail_hi + 1):
            try:
                ch = bytes([a, b]).decode(codec)
            except UnicodeDecodeError:
                continue
            if len(ch) == 1 and (0x4E00 <= ord(ch) <= 0x9FFF or 0x3400 <= ord(ch) <= 0x4DBF or 0xF900 <= ord(ch) <= 0xFAFF):
                out.add(ord(ch))
    return out


def han_sets():
    return {
        'ko': set(),                                                # 한국어 한자(KS X 1001 4,888)는 남기지 않음 — 데이터에 한자가 없고 KR 이 +2.4MB. 한자 이름은 JP·SC·TC 가 남긴 상용 한자(일본 글자 모양)로, 없으면 시스템 글꼴
        'ja': codec_han('shift_jis', 0x88, 0x98),                   # JIS X 0208 제1수준 한자 2,965 (일상 한자)
        'zh-CN': codec_han('gb2312', 0xB0, 0xD7, 0xA1, 0xFE),       # GB 2312 일급 한자 3,755 (상용)
        'zh-TW': codec_han('big5', 0xA4, 0xC6),                     # Big5 상용 한자 5,401
    }


def name_set(lang, han):
    # 어느 언어 화면에서든 한글·가나·일본/간체/번체 상용 한자 이름이 두부 없이 나오도록 (tests/check_glyphs 의 섞인 이름) —
    # 같은 글자는 그 언어 사슬의 첫 글꼴에만 남으므로 합집합이라고 글꼴마다 다 커지지는 않음
    s = set(HANGUL) | set(BASE)
    if lang in ('ko', 'en', 'es'):
        return s       # 사슬에 JP·SC·TC 가 다 있어, 일본·중국 이름의 한자는 아래 세 언어가 남긴 글자로 그려짐
    s |= BOPOMOFO if lang == 'zh-TW' else set()
    for h in han.values():
        s |= h
    return s


def json_chars(path, out):
    def walk(v):
        if isinstance(v, str):
            out.update(ord(c) for c in v)
        elif isinstance(v, dict):
            for k, x in v.items():
                walk(k); walk(x)
        elif isinstance(v, list):
            for x in v:
                walk(x)
    walk(json.load(open(path, encoding='utf-8')))


def code_chars():
    """코드·장면의 문자열 글(따옴표 안)에 든 글자 — 주석은 제외"""
    out = set()
    pat = re.compile(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'')
    for ext in ('gd', 'tscn', 'tres', 'cfg'):
        for p in glob.glob(os.path.join(GODOT, '**', '*.' + ext), recursive=True):
            rel = os.path.relpath(p, GODOT)
            if rel.startswith(('tests', 'tools', 'build', 'android', '.godot', 'dev', 'assets/pilot', 'third_party', 'addons')):
                continue
            for line in open(p, encoding='utf-8', errors='ignore'):
                for m in pat.finditer(line):
                    if '#' in line[:m.start()] and line[:m.start()].count('"') % 2 == 0:
                        continue   # 주석 속 따옴표
                    out.update(ord(c) for c in m.group(0))
    return out


def lang_chars(lang):
    s = set()
    for sub in ('lang', 'story'):
        p = os.path.join(GODOT, 'data', sub, lang + '.json')
        if os.path.exists(p):
            json_chars(p, s)
    return s


def common_chars():
    s = set()
    for p in glob.glob(os.path.join(GODOT, 'data', '*.json')):
        json_chars(p, s)
    s |= code_chars()
    return s


def build():
    cmaps = {k: set(TTFont(os.path.join(SRC, f)).getBestCmap().keys()) for k, f in FILES.items()}
    han = han_sets()
    common = common_chars()
    need = {k: set() for k in FILES}
    per_lang = {}
    for lang, chain in CHAINS.items():
        want = common | lang_chars(lang) | name_set(lang, han)
        data_only = common | lang_chars(lang)
        miss = []
        for c in sorted(want):
            if c < 0x20:
                continue
            for k in chain:
                if c in cmaps[k]:
                    need[k].add(c)
                    break
            else:
                if c in data_only:
                    miss.append(c)
        per_lang[lang] = (len(want), miss)
    return need, per_lang


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--report', action='store_true')
    ap.add_argument('--out', default=FONTS)
    a = ap.parse_args()
    if not os.path.isdir(SRC):
        sys.exit('원본 글꼴 폴더가 없습니다: ' + SRC)
    need, per_lang = build()
    for lang, (n, miss) in per_lang.items():
        # 원본 글꼴 사슬에도 없는 글자 (그림 문자 등 — 화면이 아이콘으로 바꾸거나 지움)
        print('%-6s 필요한 글자 %6d종 · 사슬에 없는 데이터 글자 %d종 %s' % (lang, n, len(miss), ''.join(chr(c) for c in miss[:12])))
    tmp = tempfile.mkdtemp()
    total_src = total = 0
    for k, f in FILES.items():
        txt = os.path.join(tmp, k + '.txt')
        open(txt, 'w', encoding='utf-8').write(''.join(chr(c) for c in sorted(need[k])))
        out = os.path.join(tmp if a.report else a.out, f)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        subprocess.run(['pyftsubset', os.path.join(SRC, f), '--text-file=' + txt, '--output-file=' + out,
                        '--layout-features=kern,liga,clig,ccmp,locl,mark,mkmk,calt,rlig,vert,vrt2,palt,pwid,fwid,hwid,halt,ljmo,vjmo,tjmo', '--notdef-outline', '--name-IDs=*', '--name-legacy', '--name-languages=*',
                        '--no-hinting'], check=True)
        s0, s1 = os.path.getsize(os.path.join(SRC, f)), os.path.getsize(out)
        total_src += s0; total += s1
        print('%s: 글자 %6d종  %5.1f MB -> %5.1f MB' % (f, len(need[k]), s0 / 1048576, s1 / 1048576))
    print('합계 %.1f MB -> %.1f MB (-%.1f MB)' % (total_src / 1048576, total / 1048576, (total_src - total) / 1048576))
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
