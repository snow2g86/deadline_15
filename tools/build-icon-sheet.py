#!/usr/bin/env python3
"""개발용: image/icon/item/*.png (256px 일러스트) → 아이템 아이콘 시트 image/icon/item-sprite.webp + js 좌표표

사용: python3 tools/build-icon-sheet.py
- 64px 칸, 가로 8칸. 파일 이름(확장자 제외)이 아이콘 키 (예: siege_ladder, rune_fire, legend_blood_oath)
- 좌표표는 js/common/item-icons.js 의 ITEM_SPRITE 로 다시 씀 (itemIcon(key, size, 대체이모지)가 사용)
"""
import os, glob, math
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'image/icon/item')
OUT = os.path.join(ROOT, 'image/icon/item-sprite.webp')
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
sheet.save(OUT, quality=90, method=6)   # WebP: PNG의 약 1/4 용량, 화질 거의 그대로

entries = ','.join('%s:[%d,%d]' % (k, x, y) for k, (x, y) in pos.items())
js = """// ═══════════════════════════════════════════
//  common/item-icons.js — 아이템 일러스트 아이콘 (tools/build-icon-sheet.py 가 생성, 직접 고치지 말 것)
//  itemIcon(key, size, 대체이모지, 등급): 시트에 있으면 그림, 없으면 이모지
//  아이템은 두 겹: 바깥 = 등급 테두리(frame_uncommon 은장 · rare 금장 · epic 에메랄드 · legendary 루비, common은 평범한 바탕), 안쪽 = 아이템 그림
//  스킬·효과 아이콘(e_*)은 꾸밈 없이 그림만
//  등급을 안 주면 ICON_RARITY[key](js/common/emoji-icons.js) → 없으면 common
// ═══════════════════════════════════════════
var ITEM_SPRITE_COLS = %d, ITEM_SPRITE_ROWS = %d;
var ITEM_SPRITE = {%s};
function _iconTile(p, size) {
  return 'background:url(image/icon/item-sprite.webp) no-repeat;background-size:' + (ITEM_SPRITE_COLS * size) + 'px ' + (ITEM_SPRITE_ROWS * size) + 'px;' +
    'background-position:-' + (p[0] * size) + 'px -' + (p[1] * size) + 'px';
}
function itemIcon(key, size, fallback, rarity) {
  var p = ITEM_SPRITE[key];
  if (!p) return fallback || '';
  // 등급 테두리 그림, 스킬·효과 아이콘(e_*)은 테두리·바탕 없이 그림만
  if (/^(frame|e)_/.test(key)) return '<span class="item-icon" style="display:inline-block;vertical-align:middle;width:' + size + 'px;height:' + size + 'px;' + _iconTile(p, size) + '"></span>';
  rarity = rarity || (typeof ICON_RARITY !== 'undefined' && ICON_RARITY[key]) || 'common';
  var f = ITEM_SPRITE['frame_' + rarity], r = Math.round(size * 0.14);
  var outer = 'display:inline-block;vertical-align:middle;position:relative;width:' + size + 'px;height:' + size + 'px;border-radius:' + r + 'px;overflow:hidden;' +
    (f ? _iconTile(f, size) : 'background:radial-gradient(circle at 50%% 40%%,#3a3f4b,#1c2029);box-shadow:inset 0 0 0 1px rgba(255,255,255,.08)');
  var inner = Math.round(size * (f ? 0.78 : 0.88)), off = Math.round((size - inner) / 2);
  return '<span class="item-icon rar-' + rarity + '" style="' + outer + '"><span style="position:absolute;left:' + off + 'px;top:' + off + 'px;width:' + inner + 'px;height:' + inner + 'px;' + _iconTile(p, inner) + '"></span></span>';
}
""" % (COLS, rows, entries)
open(JS, 'w').write(js)
print('sheet', OUT, sheet.size, len(files), 'icons')
