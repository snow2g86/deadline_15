// ═══════════════════════════════════════════
//  common/item-icons.js — 아이템 일러스트 아이콘 (tools/build-icon-sheet.py 가 생성, 직접 고치지 말 것)
//  itemIcon(key, size, 대체이모지): 시트에 있으면 그림, 없으면 이모지
// ═══════════════════════════════════════════
var ITEM_SPRITE_COLS = 8, ITEM_SPRITE_ROWS = 1;
var ITEM_SPRITE = {e_smoke:[0,0],e_stealth:[1,0],siege_ladder:[2,0]};
function itemIcon(key, size, fallback) {
  var p = ITEM_SPRITE[key];
  if (!p) return fallback || '';
  var s = size / 64;
  return '<span class="item-icon" style="display:inline-block;vertical-align:middle;width:' + size + 'px;height:' + size + 'px;border-radius:' + Math.round(size * 0.12) + 'px;' +
    'background:url(image/icon/item-sprite.png) no-repeat;background-size:' + (ITEM_SPRITE_COLS * 64 * s) + 'px ' + (ITEM_SPRITE_ROWS * 64 * s) + 'px;' +
    'background-position:-' + (p[0] * 64 * s) + 'px -' + (p[1] * 64 * s) + 'px"></span>';
}
