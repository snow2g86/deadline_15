// ═══════════════════════════════════════════
//  data/equip.js — Equipment Data & Gacha
// ═══════════════════════════════════════════

var EQUIP_SLOTS = ['weapon','offhand','helmet','armor','boots','necklace','earring','ring'];

var GACHA_COST_1 = 300;
var GACHA_COST_10 = 2700;
var GACHA_MULTI_COUNT = 11;

var RARITY = {
  common:    { tier: 0, color: '#9ca3af' },
  uncommon:  { tier: 1, color: '#4ade80' },
  rare:      { tier: 2, color: '#60a5fa' },
  epic:      { tier: 3, color: '#a78bfa' },
  legendary: { tier: 4, color: '#f0c040' }
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
  1: 1.00,  // +1→+2: 100%
  2: 0.80,  // +2→+3: 80%
  3: 0.80,  // +3→+4: 80%
  4: 0.60,  // +4→+5: 60%
  5: 0.60,  // +5→+6: 60%
  6: 0.40,  // +6→+7: 40%
  7: 0.40,  // +7→+8: 40%
  8: 0.20,  // +8→+9: 20%
  9: 0.20   // +9→+10: 20%
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

// 강화된 스탯 반환 (강화 레벨 적용)
function getEnhancedStats(item) {
  if (!item || !item.enhanceLv) return item.stats;
  var mult = 1 + (item.enhanceLv * ENHANCE_STAT_MULT);
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
