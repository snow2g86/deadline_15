#!/usr/bin/env python3
"""개발용: image/icon/item/*.png (256px 일러스트) → 아이템 아이콘 시트 image/icon/item-sprite.png + js 좌표표

사용: python3 tools/build-icon-sheet.py
- 64px 칸, 가로 8칸. 파일 이름(확장자 제외)이 아이콘 키 (예: siege_ladder, rune_fire, legend_blood_oath)
- 좌표표는 js/common/item-icons.js 의 ITEM_SPRITE 로 다시 씀 (itemIcon(key, size, 대체이모지)가 사용)
"""
import os, glob, math
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'image/icon/item')
OUT = os.path.join(ROOT, 'image/icon/item-sprite.png')
JS = os.path.join(ROOT, 'js/common/item-icons.js')
CELL, COLS = 64, 8

files = sorted(glob.glob(os.path.join(SRC, '*.png')))
rows = max(1, math.ceil(len(files) / COLS))
sheet = Image.new('RGBA', (CELL * COLS, CELL * rows), (0, 0, 0, 0))
pos = {}
for i, f in enumerate(files):
    key = os.path.splitext(os.path.basename(f))[0]
    x, y = i % COLS, i // COLS
    sheet.paste(Image.open(f).convert('RGBA').resize((CELL, CELL), Image.LANCZOS), (x * CELL, y * CELL))
    pos[key] = (x, y)
sheet.save(OUT, optimize=True)

entries = ','.join('%s:[%d,%d]' % (k, x, y) for k, (x, y) in pos.items())
js = """// ═══════════════════════════════════════════
//  common/item-icons.js — 아이템 일러스트 아이콘 (tools/build-icon-sheet.py 가 생성, 직접 고치지 말 것)
//  itemIcon(key, size, 대체이모지): 시트에 있으면 그림, 없으면 이모지
// ═══════════════════════════════════════════
var ITEM_SPRITE_COLS = %d, ITEM_SPRITE_ROWS = %d;
var ITEM_SPRITE = {%s};
function itemIcon(key, size, fallback) {
  var p = ITEM_SPRITE[key];
  if (!p) return fallback || '';
  var s = size / 64;
  return '<span class="item-icon" style="display:inline-block;vertical-align:middle;width:' + size + 'px;height:' + size + 'px;border-radius:' + Math.round(size * 0.12) + 'px;' +
    'background:url(image/icon/item-sprite.png) no-repeat;background-size:' + (ITEM_SPRITE_COLS * 64 * s) + 'px ' + (ITEM_SPRITE_ROWS * 64 * s) + 'px;' +
    'background-position:-' + (p[0] * 64 * s) + 'px -' + (p[1] * 64 * s) + 'px"></span>';
}
""" % (COLS, rows, entries)
open(JS, 'w').write(js)
print('sheet', OUT, sheet.size, len(files), 'icons')
