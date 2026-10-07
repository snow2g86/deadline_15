#!/usr/bin/env python3
"""개발용: video-to-sheet.py로 만든 시트를 게임에 등록 (이미지 복사 + js/battle/rig.js SPRITE_SHEETS 항목 추가/교체)

사용: python3 tools/apply-sheet.py <key> <motion> <시트.png> <dur ms> [hit 프레임]
  key = knight_01 등, motion = idle|combat|run|hit|attack
  시트 옆의 <시트.png>.json(frames, w, h, body, cx)을 읽고, 원본 PNG의 몸 중심(icx)을 계산해 넣는다.
"""
import json, os, re, shutil, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
key, motion, sheet, dur = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
hit = sys.argv[5] if len(sys.argv) > 5 else None
meta = json.load(open(sheet + '.json'))
dst = f'image/character/anim/{key}_{motion}.png'
os.makedirs(os.path.join(ROOT, 'image/character/anim'), exist_ok=True)
shutil.copy(sheet, os.path.join(ROOT, dst))
bb = Image.open(os.path.join(ROOT, 'image/character', key + '.png')).getbbox()
icx = (bb[0] + bb[2]) / 2
line = (f"    {motion}: {{ src: '{dst}', frames: {meta['frames']}, w: {meta['w']}, h: {meta['h']}, "
        f"body: [{meta['body'][0]}, {meta['body'][1]}], cx: {meta['cx']}, icx: {icx}, dur: {dur}" + (f", hit: {hit}" if hit else '') + " },")

p = os.path.join(ROOT, 'js/battle/rig.js'); s = open(p).read()
a = s.index('const SPRITE_SHEETS = {'); b = s.index('\n};', a)
block = s[a:b]
m = re.search(r'\n  ' + key + r': \{\n(.*?)\n  \},', block, re.S)
if m:
    body = m.group(1)
    body, n = re.subn(r'    ' + motion + r': \{[^\n]*', line, body)
    if not n: body += '\n' + line
    block = block[:m.start(1)] + body + block[m.end(1):]
else:
    block += f'\n  {key}: {{\n{line}\n  }},'
s = s[:a] + block + s[b:]
open(p, 'w').write(s)
print('applied', key, motion, dst)
