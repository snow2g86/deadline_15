// ═══════════════════════════════════════════
//  data/equip.js — Equipment Data & Gacha
// ═══════════════════════════════════════════

var EQUIP_SLOTS = ['weapon','offhand','helmet','armor','boots','necklace','earring','ring'];

var GACHA_COST_1 = 300;
var GACHA_COST_10 = 2700;
var GACHA_MULTI_COUNT = 11;

var RARITY = {
  common:    { tier: 0, grade: 'D', color: '#9ca3af' },
  uncommon:  { tier: 1, grade: 'C', color: '#4ade80' },
  rare:      { tier: 2, grade: 'B', color: '#60a5fa' },
  epic:      { tier: 3, grade: 'A', color: '#a78bfa' },
  legendary: { tier: 4, grade: 'S', color: '#f0c040' }
};

var GACHA_RATE = { common: .60, uncommon: .35, rare: .045, epic: .0045, legendary: .0005 };
var GACHA_PITY_MAX = 100;
var RARITY_MULT = { common: 1.0, uncommon: 1.3, rare: 1.6, epic: 2.0, legendary: 2.5 };
var SELL_PRICE = { common: 30, uncommon: 60, rare: 120, epic: 250, legendary: 500 };
var RARITY_ORDER = ['common','uncommon','rare','epic','legendary'];

var ARMOR_TYPE = {
  cloth:   ['mage','summoner','shaman','priest'],
  leather: ['assassin','archer','sapper','brawler','novice'],
  plate:   ['warrior','knight','lancer']
};

var ALL_CLASSES = ['warrior','knight','assassin','mage','archer','priest','novice','summoner','shaman','brawler','lancer','sapper'];

var EQUIP_DB = [
  // ── Weapons ──
  { baseId:'sword_1h', slot:'weapon', hand:'1h', stats:{atk:[3,6]}, clsRestrict:['warrior','knight','assassin','novice'] },
  { baseId:'dagger',   slot:'weapon', hand:'1h', stats:{atk:[4,7]}, clsRestrict:['assassin','brawler','sapper'] },
  { baseId:'mace',     slot:'weapon', hand:'1h', stats:{atk:[2,5],def:[1,2]}, clsRestrict:['warrior','knight','priest','novice'] },
  { baseId:'wand',     slot:'weapon', hand:'1h', stats:{atk:[3,6]}, clsRestrict:['mage','summoner','shaman','priest'] },
  { baseId:'fists',    slot:'weapon', hand:'1h', stats:{atk:[4,7]}, clsRestrict:['brawler'] },
  { baseId:'greatsword', slot:'weapon', hand:'2h', stats:{atk:[6,10]}, clsRestrict:['warrior','knight','lancer'] },
  { baseId:'bow',      slot:'weapon', hand:'2h', stats:{atk:[5,9]}, clsRestrict:['archer'] },
  { baseId:'staff',    slot:'weapon', hand:'2h', stats:{atk:[5,9]}, clsRestrict:['mage','summoner','shaman'] },
  { baseId:'spear',    slot:'weapon', hand:'2h', stats:{atk:[5,8]}, clsRestrict:['lancer','warrior'] },
  // ── Offhand ──
  { baseId:'shield',  slot:'offhand', stats:{def:[2,5],hp:[5,15]}, clsRestrict:['warrior','knight','lancer','novice'] },
  { baseId:'tome',    slot:'offhand', stats:{atk:[1,3],hp:[3,8]}, clsRestrict:['mage','summoner','shaman','priest'] },
  { baseId:'buckler', slot:'offhand', stats:{def:[1,3]}, clsRestrict:['assassin','brawler','sapper','archer'] },
  // ── Helmet ──
  { baseId:'plate_helm',  slot:'helmet', armorType:'plate',   stats:{def:[2,4],hp:[5,10]} },
  { baseId:'leather_cap', slot:'helmet', armorType:'leather', stats:{def:[1,2],hp:[3,8]} },
  { baseId:'cloth_hood',  slot:'helmet', armorType:'cloth',   stats:{atk:[1,3],hp:[3,8]} },
  // ── Armor ──
  { baseId:'plate_armor',   slot:'armor', armorType:'plate',   stats:{def:[4,8],hp:[10,25]} },
  { baseId:'leather_armor', slot:'armor', armorType:'leather', stats:{def:[2,4],hp:[5,15]} },
  { baseId:'cloth_robe',    slot:'armor', armorType:'cloth',   stats:{atk:[2,5],hp:[5,12]} },
  // ── Boots ──
  { baseId:'plate_boots',   slot:'boots', armorType:'plate',   stats:{def:[1,3],hp:[3,8]} },
  { baseId:'leather_boots', slot:'boots', armorType:'leather', stats:{def:[1,2],hp:[2,5]} },
  { baseId:'cloth_shoes',   slot:'boots', armorType:'cloth',   stats:{atk:[1,2],hp:[2,5]} },
  // ── Necklace (set items) ──
  { baseId:'necklace_power', slot:'necklace', stats:{atk:[2,5]}, setId:'power' },
  { baseId:'necklace_guard', slot:'necklace', stats:{def:[2,4],hp:[3,8]}, setId:'guard' },
  { baseId:'necklace_swift', slot:'necklace', stats:{atk:[1,3]}, setId:'swift' },
  // ── Earring (set items) ──
  { baseId:'earring_power', slot:'earring', stats:{atk:[1,4]}, setId:'power' },
  { baseId:'earring_guard', slot:'earring', stats:{def:[1,3],hp:[2,6]}, setId:'guard' },
  { baseId:'earring_swift', slot:'earring', stats:{hp:[2,5]}, setId:'swift' },
  // ── Ring (set items) ──
  { baseId:'ring_power', slot:'ring', stats:{atk:[2,5]}, setId:'power' },
  { baseId:'ring_guard', slot:'ring', stats:{def:[2,4]}, setId:'guard' },
  { baseId:'ring_swift', slot:'ring', stats:{atk:[1,3]}, setId:'swift' }
];

var EQUIP_SETS = {
  power: { 2: { atk: 5 }, 3: { atk: 10, hp: 15 } },
  guard: { 2: { def: 4, hp: 10 }, 3: { def: 8, hp: 25 } },
  swift: { 2: { move: 1 }, 3: { move: 1, atk: 5 } }
};

var INV_KEY = 'game_inventory';

function loadInventory() {
  try {
    var raw = localStorage.getItem(INV_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}
  return [];
}

function saveInventory(inv) {
  try { localStorage.setItem(INV_KEY, JSON.stringify(inv)); } catch (_) {}
}

var _eidCounter = 0;
function genEid() {
  _eidCounter++;
  return 'eq_' + Date.now().toString(36) + '_' + _eidCounter.toString(36) + '_' + Math.random().toString(36).slice(2, 6);
}

function rollRarity(minRarity) {
  var minTier = minRarity ? RARITY[minRarity].tier : 0;
  var pool = {};
  var total = 0;
  for (var r in GACHA_RATE) {
    if (RARITY[r].tier >= minTier) {
      pool[r] = GACHA_RATE[r];
      total += GACHA_RATE[r];
    }
  }
  var roll = Math.random() * total;
  for (var r2 in pool) {
    roll -= pool[r2];
    if (roll <= 0) return r2;
  }
  return 'common';
}

function generateEquip(template, rarity) {
  var mult = RARITY_MULT[rarity];
  var rolled = {};
  for (var stat in template.stats) {
    var range = template.stats[stat];
    var base = range[0] + Math.random() * (range[1] - range[0]);
    rolled[stat] = Math.round(base * mult);
    if (rolled[stat] < 1) rolled[stat] = 1;
  }
  var cls = template.clsRestrict ? template.clsRestrict.slice() :
    (template.armorType ? ARMOR_TYPE[template.armorType].slice() : ALL_CLASSES.slice());
  return {
    type: 'equip',
    eid: genEid(),
    templateId: template.baseId,
    rarity: rarity,
    slot: template.slot,
    hand: template.hand || null,
    armorType: template.armorType || null,
    clsRestrict: cls,
    setId: template.setId || null,
    stats: rolled,
    equipped: null,
    enhanceLv: 0,
    enhanceAttempts: 0
  };
}

var PITY_KEY = 'game_gacha_pity';

function loadPity() {
  try { var v = parseInt(localStorage.getItem(PITY_KEY), 10); return isNaN(v) ? 0 : v; } catch (_) { return 0; }
}
function savePity(count) {
  try { localStorage.setItem(PITY_KEY, String(count)); } catch (_) {}
}

function gachaPull(minRarity, skipPity) {
  var pity = loadPity();
  var rarity;
  if (!skipPity && pity + 1 >= GACHA_PITY_MAX) {
    rarity = 'legendary';
  } else {
    rarity = rollRarity(minRarity || null);
  }
  if (!skipPity) {
    if (rarity === 'legendary') {
      savePity(0);
    } else {
      savePity(pity + 1);
    }
  }
  var tpl = EQUIP_DB[Math.floor(Math.random() * EQUIP_DB.length)];
  return generateEquip(tpl, rarity);
}

function calcEquipBonus(ch) {
  var bonus = { hp: 0, atk: 0, def: 0, move: 0, range: 0 };
  if (!ch || !ch.equip) return bonus;
  var inv = loadInventory();
  var invMap = {};
  for (var i = 0; i < inv.length; i++) {
    if (inv[i].type === 'equip') invMap[inv[i].eid] = inv[i];
  }
  var setCounts = {};
  for (var s = 0; s < EQUIP_SLOTS.length; s++) {
    var eid = ch.equip[EQUIP_SLOTS[s]];
    if (!eid) continue;
    var item = invMap[eid];
    if (!item) continue;
    var enhancedStats = getEnhancedStats(item);
    for (var stat in enhancedStats) {
      if (bonus[stat] !== undefined) bonus[stat] += enhancedStats[stat];
    }
    if (item.setId) {
      setCounts[item.setId] = (setCounts[item.setId] || 0) + 1;
    }
  }
  for (var setId in setCounts) {
    var count = setCounts[setId];
    var setDef = EQUIP_SETS[setId];
    if (!setDef) continue;
    var thresholds = [3, 2];
    for (var ti = 0; ti < thresholds.length; ti++) {
      if (count >= thresholds[ti] && setDef[thresholds[ti]]) {
        var sb = setDef[thresholds[ti]];
        for (var sk in sb) {
          if (bonus[sk] !== undefined) bonus[sk] += sb[sk];
        }
        break;
      }
    }
  }
  return bonus;
}

function ensureEquipSlots(ch) {
  if (!ch.equip) {
    ch.equip = { weapon: null, offhand: null, helmet: null, armor: null, boots: null, necklace: null, earring: null, ring: null };
  }
  return ch;
}

// ═══════════════════════════════════════════
// 장비 강화 시스템 (Enhancement System)
// ═══════════════════════════════════════════

var ENHANCE_MAX_LV = 10;
var ENHANCE_PITY_THRESHOLD = 3;

var ENHANCE_RATES = {
  0: 1.00,  // +0→+1: 100%
  1: 0.95,  // +1→+2: 95%
  2: 0.85,  // +2→+3: 85%
  3: 0.70,  // +3→+4: 70%
  4: 0.55,  // +4→+5: 55%
  5: 0.40,  // +5→+6: 40%
  6: 0.28,  // +6→+7: 28%
  7: 0.18,  // +7→+8: 18%
  8: 0.10,  // +8→+9: 10%
  9: 0.05   // +9→+10: 5%
};

var ENHANCE_BASE_COST = 50;
var ENHANCE_RARITY_COST = {
  common: 1.0,
  uncommon: 1.5,
  rare: 2.0,
  epic: 3.0,
  legendary: 5.0
};

var ENHANCE_STAT_MULT = 0.10;

// 강화 비용 계산
function calcEnhanceCost(item) {
  var base = ENHANCE_BASE_COST;
  var rarityMult = ENHANCE_RARITY_COST[item.rarity] || 1.0;
  return Math.round(base * (item.enhanceLv + 1) * rarityMult);
}

// 강화 레벨별 스탯 증가율
function getEnhanceMultiplier(lvl) {
  if (lvl <= 3) return 0.10;     // +0~+3: 10%
  if (lvl <= 6) return 0.15;     // +4~+6: 15%
  if (lvl <= 9) return 0.22;     // +7~+9: 22%
  return 0.30;                   // +10: 30%
}

// 강화된 스탯 반환 (강화 레벨 적용)
function getEnhancedStats(item) {
  if (!item || !item.enhanceLv) return item.stats;
  var mult = 1 + getEnhanceMultiplier(item.enhanceLv);
  var enhanced = {};
  for (var stat in item.stats) {
    enhanced[stat] = Math.round(item.stats[stat] * mult);
  }
  return enhanced;
}

// 강화 가능 여부 확인
function canEnhance(item) {
  return (item.enhanceLv || 0) < ENHANCE_MAX_LV;
}

// 성공률 계산 (pity 시스템 포함)
function calcEnhanceRate(item) {
  var baseRate = ENHANCE_RATES[item.enhanceLv || 0] || 0;
  if ((item.enhanceAttempts || 0) >= ENHANCE_PITY_THRESHOLD) {
    return 1.00; // Pity 발동: 100% 성공
  }
  return baseRate;
}

// ═══════════════════════════════════════════
// 장비 이모지 매핑 (Emoji Mapping)
// ═══════════════════════════════════════════
// TODO: 나중에 image/icon/64x64/*.png 아이콘으로 변경

var EQUIP_EMOJI = {
  // Weapons
  'sword_1h': '🗡️', // 기사검
  'dagger': '🔪', // 단검
  'mace': '🔨', // 메이스
  'wand': '✨', // 지팡이
  'fists': '👊', // 권투장갑
  'greatsword': '⚔️', // 대검
  'bow': '🏹', // 활
  'staff': '🪄', // 마법봉
  'spear': '🗣️', // 창
  // Offhand
  'shield': '🛡️', // 방패
  'tome': '📖', // 마법서
  'buckler': '🎯', // 작은 방패
  // Helmets
  'plate_helm': '⚡', // 판금 투구
  'leather_cap': '👒', // 가죽 모자
  'cloth_hood': '🧢', // 천 두건
  // Armor
  'plate_armor': '🏰', // 판금 갑옷
  'leather_armor': '🧵', // 가죽 갑옷
  'cloth_robe': '👗', // 천 로브
  // Boots
  'plate_boots': '👢', // 판금 부츠
  'leather_boots': '🥾', // 가죽 부츠
  'cloth_shoes': '👟', // 천 신발
  // Accessories
  'necklace_power': '💎', // 목걸이 - 힘
  'necklace_guard': '🔗', // 목걸이 - 방어
  'necklace_swift': '🌪️', // 목걸이 - 민첩
  'earring_power': '💫', // 귀걸이 - 힘
  'earring_guard': '⭐', // 귀걸이 - 방어
  'earring_swift': '✨', // 귀걸이 - 민첩
  'ring_power': '💠', // 반지 - 힘
  'ring_guard': '🔷', // 반지 - 방어
  'ring_swift': '🔹' // 반지 - 민첩
};

function getEquipEmoji(templateId) {
  return EQUIP_EMOJI[templateId] || '📦'; // 기본값: 박스
}

// ═══════════════════════════════════════════
// 공성 도구 (Siege Items)
// ═══════════════════════════════════════════

var SIEGE_ITEMS = [
  { id: 'siege_ladder', icon: '\u{1FA9C}', cost: 100, targetType: 'wall_rock', range: 1, effect: 'climb', weight: 40 },
  { id: 'siege_bomb',   icon: '\u{1F4A3}', cost: 200, targetType: 'wall_rock', range: 3, effect: 'destroy', weight: 35 },
  { id: 'siege_bridge', icon: '\u{1F309}', cost: 150, targetType: 'water', range: 3, effect: 'bridge', weight: 25 }
];

// ═══════════════════════════════════════════
// 전투 포션 시스템 (Combat Potions)
// ═══════════════════════════════════════════

var BATTLE_POTIONS = {
  // 회복 포션
  potion_heal: {
    id: 'potion_heal',
    icon: '💊',
    name: 'potion_heal',
    type: 'heal',
    value: 50,  // HP 50% 회복
    range: 1,   // 인근 아군/적군에게 사용 가능
    actionCost: 1  // 행동 1회 소비
  },
  // 스킬 재원 회복
  potion_resource: {
    id: 'potion_resource',
    icon: '⚡',
    name: 'potion_resource',
    type: 'resource',
    value: 30,  // 자원 30 회복
    range: 1,
    actionCost: 1
  },
  // 공격력 버프
  potion_atk_buff: {
    id: 'potion_atk_buff',
    icon: '🔥',
    name: 'potion_atk_buff',
    type: 'buff',
    stat: 'atk',
    value: 30,  // ATK +30%
    duration: 3,  // 3턴 지속
    range: 1,
    actionCost: 1
  },
  // 방어력 버프
  potion_def_buff: {
    id: 'potion_def_buff',
    icon: '🛡️',
    name: 'potion_def_buff',
    type: 'buff',
    stat: 'def',
    value: 30,  // DEF +30%
    duration: 3,
    range: 1,
    actionCost: 1
  },
  // 공격력 디버프
  potion_atk_debuff: {
    id: 'potion_atk_debuff',
    icon: '💢',
    name: 'potion_atk_debuff',
    type: 'debuff',
    stat: 'atk',
    value: -25,  // 대상 ATK -25%
    duration: 3,
    range: 2,
    actionCost: 1
  },
  // 방어력 디버프
  potion_def_debuff: {
    id: 'potion_def_debuff',
    icon: '❄️',
    name: 'potion_def_debuff',
    type: 'debuff',
    stat: 'def',
    value: -25,  // 대상 DEF -25%
    duration: 3,
    range: 2,
    actionCost: 1
  }
};
