#!/usr/bin/env python3
"""개발용: 뒷모습 후보(tools/_work/back/<키>_<시드>_last.png) → image/character/<키>_b.png
앞모습 그림(image/character/<키>.png)과 같은 크기·몸 높이·발끝 위치·가운데로 맞춘다 (전투 리그·시트가 같은 자리에 오게)

사용: python3 tools/make-back.py <키> <시드>
"""
import os, subprocess, sys, tempfile, importlib.util
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
key, seed = sys.argv[1], sys.argv[2]
src = os.path.join(ROOT, 'tools/_work/back', f'{key}_{seed}_last.png')
tmp = os.path.join(tempfile.gettempdir(), f'back_{key}.png')
subprocess.run([sys.executable, os.path.join(ROOT, 'tools/make-icon.py'), src, tmp, '1024', '1024'], check=True, capture_output=True)
front = Image.open(os.path.join(ROOT, 'image/character', key + '.png')).convert('RGBA')
fb = front.getbbox()
# 몸 높이는 머리끝~발끝으로 맞춤 (머리 위로 든 칼끝은 빼고 — tools/fix-body-top.py)
spec = importlib.util.spec_from_file_location('fbt', os.path.join(ROOT, 'tools/fix-body-top.py')); fbt = importlib.util.module_from_spec(spec); spec.loader.exec_module(fbt)
im = Image.open(tmp).convert('RGBA'); im = im.crop(im.getbbox())
target = fb[3] - fb[1]            # 앞모습: 머리끝(투구 꼭대기)~발끝
k = target / (im.height - fbt.body_top(im))
w, h = round(im.width * k), round(im.height * k)
im = im.resize((w, h), Image.NEAREST)
can = Image.new('RGBA', front.size)
cx = (fb[0] + fb[2]) // 2
can.paste(im, (cx - w // 2, fb[3] - h), im)
out = os.path.join(ROOT, 'image/character', key + '_b.png'); can.save(out, optimize=True)
print(out, (w, h))
