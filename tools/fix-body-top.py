#!/usr/bin/env python3
"""개발용: 무기를 머리 위로 든 그림(뒷모습 등)의 몸 높이를 무기 빼고 다시 잼

게임은 '머리끝~발끝 = 같은 높이'로 캐릭터 크기를 맞춘다(rig.js CHAR_FIG, 시트 body). 칼끝이 머리보다 위에 있으면
칼끝까지를 머리로 잡아 캐릭터가 작아진다 → 가로 폭이 몸통 폭의 일정 비율보다 좁은 위쪽 줄(칼날·창대 등)은 건너뛴다.

사용: python3 tools/fix-body-top.py <키 예: knight_01_b>
  - js/battle/rig.js SPRITE_SHEETS[키] 의 동작마다 body 위쪽 값을 첫 프레임 기준으로 다시 계산
"""
import os, re, sys
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def body_top(im, frac=0.35):
    """불투명 폭이 (가장 넓은 줄 폭 × frac) 이상이 되는 첫 줄 = 머리끝 (칼날처럼 가는 것은 무시)"""
    a = im.split()[-1].point(lambda v: 255 if v > 40 else 0)
    w, h = a.size; px = a.load()
    widths = []
    for y in range(h):
        xs = [x for x in range(w) if px[x, y]]
        widths.append((xs[-1] - xs[0] + 1) if xs else 0)
    mx = max(widths) or 1
    # 머리는 몸통보다 좁으니 몸통(아래 절반)의 중간 폭 기준
    lower = sorted(v for v in widths[h // 2:] if v)
    ref = lower[len(lower) // 2] if lower else mx
    for y, v in enumerate(widths):
        if v >= ref * frac: return y
    return 0


if __name__ == '__main__':
    key = sys.argv[1]
    p = os.path.join(ROOT, 'js/battle/rig.js'); s = open(p).read()
    a = s.index('  ' + key + ': {'); b = s.index('\n  },', a)
    block = s[a:b]
    def fix(m):
        line = m.group(0)
        src = re.search(r"src: '([^']+)'", line).group(1)
        w = int(re.search(r'w: (\d+)', line).group(1)); hh = int(re.search(r'h: (\d+)', line).group(1))
        top = body_top(Image.open(os.path.join(ROOT, src)).convert('RGBA').crop((0, 0, w, hh)))
        old = re.search(r'body: \[(\d+), (\d+)\]', line)
        print(src.split('/')[-1], 'body top', old.group(1), '->', top)
        return line.replace(old.group(0), f'body: [{top}, {old.group(2)}]')
    block = re.sub(r"    \w+: \{ src: [^\n]*", fix, block)
    open(p, 'w').write(s[:a] + block + s[b:])
