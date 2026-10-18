#!/usr/bin/env python3
"""개발용: video-to-sheet.py로 만든 시트를 게임에 등록 (이미지 복사 + godot/data/sprites.json SPRITE_SHEETS 항목 추가/교체)
(2026-10-18~ 데이터 원본은 godot/data — 예전에는 웹 js/battle/rig.js 를 고쳤음. 웹판은 동결이라 더 고치지 않음)
등록 뒤: Godot --headless --path godot --script res://tools/data_tool.gd -- --write (모양 맞춤 + manifest)

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
dst = f'image/character/anim/{key}_{motion}.png'   # 데이터에 적는 경로 (SPRITE_SHEETS.src — 그림 파일은 godot/assets/ 아래)
os.makedirs(os.path.join(ROOT, 'godot/assets/image/character/anim'), exist_ok=True)
shutil.copy(sheet, os.path.join(ROOT, 'godot/assets', dst))
bb = Image.open(os.path.join(ROOT, 'godot/assets/image/character', key + '.png')).getbbox()
icx = (bb[0] + bb[2]) / 2
entry = {'src': dst, 'frames': meta['frames'], 'w': meta['w'], 'h': meta['h'], 'body': [meta['body'][0], meta['body'][1]],
         'cx': meta['cx'], 'icx': icx, 'dur': dur}
if hit:
    entry['hit'] = int(hit)

p = os.path.join(ROOT, 'godot/data/sprites.json')
data = json.load(open(p, encoding='utf-8'))
data['SPRITE_SHEETS'].setdefault(key, {})[motion] = entry
with open(p, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write('\n')
print('applied', key, motion, dst, '→ 이제 data_tool -- --write')
