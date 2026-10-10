// ═══════════════════════════════════════════
//  data/equip.js — Equipment Data, Gacha & Enhancement
//  (옵션·고유 효과·전설·직업 세트·전투 효과는 data/gear.js)
// ═══════════════════════════════════════════

var EQUIP_SLOTS = ['weapon','offhand','helmet','armor','boots','necklace','earring','ring'];
// 슬롯 종류 표시용 이모지 (이미지 아이콘 대신 — design policy)
var EQUIP_SLOT_ICONS = { weapon:'🗡️', offhand:'🛡️', helmet:'🪖', armor:'🥋', boots:'👢', necklace:'📿', earring:'✨', ring:'💍' };

var GACHA_COST_1 = 400;   // 골드는 항상 부족하게 (예전 300)
var GACHA_COST_10 = 3600;  // 11회 (예전 2700)
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

// 방어구 4종: 종류별로 입을 수 있는 직업 (판금 > 사슬 > 가죽 > 천)
var ARMOR_TYPE = {
  plate:   ['knight','warrior','lancer'],
  chain:   ['knight','warrior','lancer','sapper','priest','archer','novice'],
  leather: ['warrior','assassin','archer','brawler','sapper','novice'],
  cloth:   ['mage','summoner','shaman','priest']
};
// 직업 세트 장비가 쓰는 방어구 종류 (그 직업의 대표 방어구)
var CLASS_ARMOR = { warrior:'plate', knight:'plate', lancer:'plate', sapper:'chain', priest:'cloth', archer:'leather',
  novice:'leather', assassin:'leather', brawler:'leather', mage:'cloth', summoner:'cloth', shaman:'cloth' };

var ALL_CLASSES = ['warrior','knight','assassin','mage','archer','priest','novice','summoner','shaman','brawler','lancer','sapper'];

var EQUIP_DB = [
  // ── 직업 전용 무기 ──
  { baseId:'wpn_warrior',  slot:'weapon', hand:'2h', stats:{atk:[6,10]},          clsRestrict:['warrior'] },
  { baseId:'wpn_knight',   slot:'weapon', hand:'1h', stats:{atk:[3,6],hp:[6,14]},  clsRestrict:['knight'] },
  { baseId:'wpn_assassin', slot:'weapon', hand:'1h', stats:{atk:[5,9]},           clsRestrict:['assassin'] },
  { baseId:'wpn_mage',     slot:'weapon', hand:'2h', stats:{atk:[5,9]},           clsRestrict:['mage'] },
  { baseId:'wpn_archer',   slot:'weapon', hand:'2h', stats:{atk:[5,9]},           clsRestrict:['archer'] },
  { baseId:'wpn_priest',   slot:'weapon', hand:'1h', stats:{atk:[3,6],hp:[4,10]},  clsRestrict:['priest'] },
  { baseId:'wpn_novice',   slot:'weapon', hand:'1h', stats:{atk:[3,6],def:[1,2]},  clsRestrict:['novice'] },
  { baseId:'wpn_summoner', slot:'weapon', hand:'1h', stats:{atk:[5,8]},           clsRestrict:['summoner'] },
  { baseId:'wpn_shaman',   slot:'weapon', hand:'1h', stats:{atk:[4,8]},           clsRestrict:['shaman'] },
  { baseId:'wpn_brawler',  slot:'weapon', hand:'1h', stats:{atk:[5,8],def:[1,2]},  clsRestrict:['brawler'] },
  { baseId:'wpn_lancer',   slot:'weapon', hand:'2h', stats:{atk:[5,8],hp:[4,10]},  clsRestrict:['lancer'] },
  { baseId:'wpn_sapper',   slot:'weapon', hand:'1h', stats:{atk:[4,8],def:[1,3]},  clsRestrict:['sapper'] },
  // ── Offhand ──
  { baseId:'shield',  slot:'offhand', stats:{def:[2,5],hp:[5,15]}, clsRestrict:['warrior','knight','lancer','novice'] },
  { baseId:'tome',    slot:'offhand', stats:{atk:[1,3],hp:[3,8]}, clsRestrict:['mage','summoner','shaman','priest'] },
  { baseId:'buckler', slot:'offhand', stats:{def:[1,3]}, clsRestrict:['assassin','brawler','sapper','archer'] },
  // ── Helmet ──
  { baseId:'plate_helm',  slot:'helmet', armorType:'plate',   stats:{def:[2,4],hp:[5,10]} },
  { baseId:'chain_helm',  slot:'helmet', armorType:'chain',   stats:{def:[1,3],hp:[4,9]} },
  { baseId:'leather_cap', slot:'helmet', armorType:'leather', stats:{def:[1,2],hp:[3,8]} },
  { baseId:'cloth_hood',  slot:'helmet', armorType:'cloth',   stats:{atk:[1,3],hp:[3,8]} },
  // ── Armor ──
  { baseId:'plate_armor',   slot:'armor', armorType:'plate',   stats:{def:[4,8],hp:[10,25]} },
  { baseId:'chain_armor',   slot:'armor', armorType:'chain',   stats:{def:[3,6],hp:[8,20]} },
  { baseId:'leather_armor', slot:'armor', armorType:'leather', stats:{def:[2,4],hp:[5,15]} },
  { baseId:'cloth_robe',    slot:'armor', armorType:'cloth',   stats:{atk:[2,5],hp:[5,12]} },
  // ── Boots ──
  { baseId:'plate_boots',   slot:'boots', armorType:'plate',   stats:{def:[1,3],hp:[3,8]} },
  { baseId:'chain_boots',   slot:'boots', armorType:'chain',   stats:{def:[1,2],hp:[3,6]} },
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

// 예전 무기 → 직업 전용 무기 (기존 저장 전환용)
var LEGACY_WEAPON = { sword_1h:'wpn_knight', dagger:'wpn_assassin', mace:'wpn_priest', wand:'wpn_summoner', fists:'wpn_brawler',
  greatsword:'wpn_warrior', bow:'wpn_archer', staff:'wpn_mage', spear:'wpn_lancer' };

var EQUIP_SETS = {
  power: { 2: { atk: 5 }, 3: { atk: 10, hp: 15 } },
  guard: { 2: { def: 4, hp: 10 }, 3: { def: 8, hp: 25 } },
  swift: { 2: { move: 1 }, 3: { move: 1, atk: 5 } }
};

// ═══════════════════════════════════════════
// 장비 강화 시스템 (Enhancement System)
//  실패 = 단계 하락(+0~+2에서 시도하면 유지), 실패할 때마다 0.5% 확률로 파손 → 골드로 수리(강화 +0 초기화)
//  성공하면 새 단계에서 확률로 강화 옵션 (data/gear.js ENHANCE_OPT)
// ═══════════════════════════════════════════

var ENHANCE_MAX_LV = 10;
var ENHANCE_RATES = [1.00, 0.90, 0.80, 0.70, 0.55, 0.45, 0.35, 0.25, 0.15, 0.10];   // 현재 단계 → 다음 단계 성공률
var ENHANCE_SAFE_BELOW = 3;          // 이 단계 미만에서 시도한 실패는 단계 유지
var ENHANCE_BREAK_CHANCE = 0.005;    // 실패할 때마다 파손 확률
var ENHANCE_FAIL_BONUS = 3;          // 실패할 때마다 다음 성공률 +3%p
var ENHANCE_FAIL_BONUS_MAX = 15;
var ENHANCE_GOLD = { common: 40, uncommon: 70, rare: 120, epic: 250, legendary: 500 };   // × (현재 단계 + 1)
var ENHANCE_STONES = [1, 1, 1, 2, 2, 2, 4, 4, 4, 4];
var REPAIR_GOLD = { common: 100, uncommon: 200, rare: 500, epic: 1200, legendary: 3000 };
var ENHANCE_STAT_PCT = [0, 10, 20, 30, 40, 55, 70, 90, 110, 130, 160];   // 단계별 능력치 증가 %

// 분해 → 강화석 (+전설은 전설 조각 1개)
var DISMANTLE_STONES = { common: 1, uncommon: 2, rare: 4, epic: 8, legendary: 20 };

// ═══════════════════════════════════════════
// 장비 이모지 매핑 (Emoji Mapping)
// ═══════════════════════════════════════════

var EQUIP_EMOJI = {
  // 직업 무기
  'wpn_warrior': '⚔️', 'wpn_knight': '🗡️', 'wpn_assassin': '🔪', 'wpn_mage': '🪄', 'wpn_archer': '🏹', 'wpn_priest': '✝️',
  'wpn_novice': '🗡️', 'wpn_summoner': '🔮', 'wpn_shaman': '🪬', 'wpn_brawler': '👊', 'wpn_lancer': '🔱', 'wpn_sapper': '🔨',
  // Offhand
  'shield': '🛡️', // 방패
  'tome': '📖', // 마법서
  'buckler': '🎯', // 작은 방패
  // Helmets
  'plate_helm': '⛑️', 'chain_helm': '🪖', 'leather_cap': '👒', 'cloth_hood': '🧢',
  // Armor
  'plate_armor': '🏰', 'chain_armor': '⛓️', 'leather_armor': '🧥', 'cloth_robe': '👘',
  // Boots
  'plate_boots': '👢', 'chain_boots': '🥾', 'leather_boots': '🥾', 'cloth_shoes': '👟',
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
