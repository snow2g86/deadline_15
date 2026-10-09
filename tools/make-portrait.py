#!/usr/bin/env python3
"""개발용: 스토리 초상화 원본 → image/character/story/<키>.png (962×1087, 투명 배경)

사용: python3 tools/make-portrait.py
- image/character/story/src/<키>.jpg|png 의 크로마키 바탕을 tools/make-icon.py 로 지우고
- 다른 캐릭터 그림과 같은 자리에 맞춤: 인물 높이 900px, 가운데, 발끝 y=1030 (지휘관 그림과 같음)
- 발밑에 남은 바탕색 그림자는 지우고, 왼쪽을 보는 원본(FLIP)은 뒤집음
- 원본이 더 새로울 때만 다시 만듦
"""
import os, glob, subprocess, sys, tempfile
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC, DST = os.path.join(ROOT, 'image/character/story/src'), os.path.join(ROOT, 'image/character/story')
W, H, FIG_H, FOOT = 962, 1087, 900, 1030
# 원본이 왼쪽을 보는 그림은 뒤집어서 오른쪽을 보게 (게임 그림은 모두 오른쪽을 봄)
FLIP = {'commander_m', 'bram', 'sera', 'kasha', 'ordin', 'boss_10', 'boss_20', 'boss_80'}


def drop_ground_shadow(im):
    # 발밑 아래쪽 15% 에 남은 어두운 초록·청록 그림자(바탕색이 어둡게 묻은 것)를 지움
    import colorsys
    px = im.load(); w, h = im.size
    for y in range(int(h * 0.85), h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if not a: continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 75 / 360 <= hh <= 200 / 360 and ss >= 0.2: px[x, y] = (0, 0, 0, 0)
    return im
os.makedirs(SRC, exist_ok=True)
n = 0
for f in sorted(glob.glob(os.path.join(SRC, '*'))):
    key, ext = os.path.splitext(os.path.basename(f))
    if ext.lower() not in ('.png', '.jpg', '.jpeg', '.webp'): continue
    out = os.path.join(DST, key + '.png')
    if os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(f): continue
    tmp = os.path.join(tempfile.gettempdir(), 'portrait_' + key + '.png')
    subprocess.run([sys.executable, os.path.join(ROOT, 'tools/make-icon.py'), f, tmp, '1024', '1024'], check=True, capture_output=True)
    im = drop_ground_shadow(Image.open(tmp).convert('RGBA'))
    im = im.crop(im.getbbox())
    if key in FLIP: im = im.transpose(Image.FLIP_LEFT_RIGHT)
    s = min(FIG_H / im.height, (W - 20) / im.width)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    can = Image.new('RGBA', (W, H))
    can.paste(im, ((W - im.width) // 2, FOOT - im.height), im)
    can.save(out, optimize=True)
    n += 1
    print(out, im.size)
print('converted', n)
