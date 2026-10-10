// ═══════════════════════════════════════════
//  data/gear.js — 장비 옵션 · 고유 효과 · 전설 장비 · 직업 세트 · 강화 옵션 · 전투 효과(GearFX)
//  (장비 틀·뽑기·강화 규칙은 data/equip.js, 기획은 docs/ITEM_DESIGN.md)
// ═══════════════════════════════════════════

// ── 효과 사전: 값의 단위와 표시 방식 ──
//  pct: 값이 %, flag: 켜짐/꺼짐(값 무시), int: 정수 그대로, dec: 소수 둘째 자리
//  noScale: 강화 +5/+10 배율을 받지 않는 효과 (칸·횟수·면역 등)
var GEAR_FX = {
  hp_pct: { u: 'pct' }, atk_pct: { u: 'pct' }, def_pct: { u: 'pct' },
  speed: { u: 'dec' }, res_rec: { u: 'int' }, res_rec_pct: { u: 'pct' },
  move: { u: 'int', noScale: 1 }, range: { u: 'int', noScale: 1 },
  crit: { u: 'pct' }, knock_res: { u: 'pct' }, hazard_res: { u: 'pct' },
  kill_heal: { u: 'pct' }, kill_ap: { u: 'int', noScale: 1 }, desperate: { u: 'pct' }, first_crit: { u: 'pct' },
  start_shield: { u: 'pct' }, regen: { u: 'pct' }, counter_up: { u: 'pct' }, charge: { u: 'pct' },
  guard_aura: { u: 'pct' }, focus: { u: 'pct' }, knock_immune: { u: 'flag', noScale: 1 }, cleanse: { u: 'pct' },
  intercept_red: { u: 'pct' }, intercept_fury: { u: 'int', noScale: 1 }, fury_gain: { u: 'int', noScale: 1 },
  backstab: { u: 'pct' }, heal_pct: { u: 'pct' }, heal_cleanse: { u: 'pct' }, exp_pct: { u: 'pct' },
  summon_pct: { u: 'pct' }, summon_turns: { u: 'int', noScale: 1 }, debuff_pct: { u: 'pct' }, debuff_turns: { u: 'int', noScale: 1 },
  combo: { u: 'pct' }, blast: { u: 'pct' }, pierce_line: { u: 'pct' }, stack_atk: { u: 'pct' }, mana_free: { u: 'pct' },
  party_atk: { u: 'pct' }, last_stand: { u: 'pct' }, start_ap: { u: 'flag', noScale: 1 },
  immune_fire: { u: 'flag', noScale: 1 }, immune_heat: { u: 'flag', noScale: 1 }, dmg_red: { u: 'pct' }
};

// ── 추가 능력치 풀 (C 이상, 부위별) — 값은 B 등급 기준, 등급 배율(RARITY_MULT/1.6)을 곱함 ──
var SUB_RANGE = { hp_pct: [3, 6], atk_pct: [3, 6], def_pct: [3, 6], speed: [0.03, 0.06], res_rec: [1, 3],
  crit: [3, 6], knock_res: [8, 15], hazard_res: [15, 30] };
var SUB_POOL = {
  weapon: ['atk_pct', 'crit', 'speed', 'res_rec', 'hp_pct'],
  offhand: ['hp_pct', 'def_pct', 'res_rec', 'crit'],
  armor: ['hp_pct', 'def_pct', 'knock_res', 'hazard_res'],
  acc: ['hp_pct', 'atk_pct', 'def_pct', 'speed', 'res_rec', 'crit', 'knock_res', 'hazard_res']
};
var SUB_ARMOR_EXTRA = { leather: ['speed'], cloth: ['res_rec', 'atk_pct'], chain: ['atk_pct'], plate: [] };
var SUB_COUNT = { common: 0, uncommon: 1, rare: 2, epic: 2, legendary: 2 };

// ── 직업 전용 옵션 (B 이상): 그 직업이 착용할 때만 켜짐 ──
var CLASS_OPTS = {
  warrior:  [{ id: 'fury_gain', r: [1, 1] }, { id: 'desperate', r: [10, 20] }, { id: 'kill_heal', r: [5, 8] }],
  knight:   [{ id: 'intercept_red', r: [10, 20] }, { id: 'knock_res', r: [15, 25] }, { id: 'guard_aura', r: [5, 10] }],
  assassin: [{ id: 'backstab', r: [10, 20] }, { id: 'kill_ap', r: [1, 1] }, { id: 'crit', r: [5, 10] }],
  mage:     [{ id: 'res_rec', r: [2, 4] }, { id: 'crit', r: [5, 10] }, { id: 'atk_pct', r: [5, 10] }],
  archer:   [{ id: 'range', r: [1, 1], w: 0.25 }, { id: 'crit', r: [5, 10] }, { id: 'atk_pct', r: [5, 10] }],
  priest:   [{ id: 'heal_pct', r: [10, 20] }, { id: 'heal_cleanse', r: [20, 40] }, { id: 'regen', r: [2, 3] }],
  novice:   [{ id: 'exp_pct', r: [10, 20] }, { id: 'hp_pct', r: [5, 10] }, { id: 'def_pct', r: [5, 10] }],
  summoner: [{ id: 'summon_pct', r: [10, 20] }, { id: 'res_rec', r: [2, 4] }, { id: 'speed', r: [0.05, 0.1] }],
  shaman:   [{ id: 'debuff_pct', r: [10, 20] }, { id: 'res_rec', r: [2, 4] }, { id: 'cleanse', r: [20, 30] }],
  brawler:  [{ id: 'combo', r: [5, 10] }, { id: 'counter_up', r: [15, 25] }, { id: 'speed', r: [0.05, 0.1] }],
  lancer:   [{ id: 'charge', r: [10, 20] }, { id: 'hp_pct', r: [5, 10] }, { id: 'knock_res', r: [15, 25] }],
  sapper:   [{ id: 'blast', r: [10, 20] }, { id: 'def_pct', r: [5, 10] }, { id: 'crit', r: [5, 10] }]
};

// ── A 등급 고유 효과 풀 (무작위 1개) ──
var UNIQUE_POOL = [
  { id: 'kill_heal', r: [8, 12] }, { id: 'kill_ap', r: [1, 1] }, { id: 'desperate', r: [25, 35] }, { id: 'first_crit', r: [50, 50] },
  { id: 'start_shield', r: [12, 18] }, { id: 'regen', r: [3, 5] }, { id: 'counter_up', r: [30, 50] }, { id: 'charge', r: [15, 25] },
  { id: 'guard_aura', r: [8, 12] }, { id: 'focus', r: [25, 35] }, { id: 'knock_immune', r: [1, 1] }, { id: 'cleanse', r: [25, 35] }
];

// ── S 등급 전설 장비 (이름 고정) ──
var LEGENDS = {
  blood_oath:     { tpl: 'wpn_warrior',   fx: { stack_atk: 5, kill_heal: 10 } },
  unyielding:     { tpl: 'wpn_knight',    fx: { intercept_red: 40, intercept_fury: 1 } },
  shadow_fang:    { tpl: 'wpn_assassin',  fx: { backstab: 50, kill_ap: 2 } },
  starfall:       { tpl: 'wpn_mage',      fx: { mana_free: 30 } },
  whisper:        { tpl: 'wpn_archer',    fx: { range: 1, first_crit: 50 } },
  dawn:           { tpl: 'wpn_priest',    fx: { heal_pct: 30, heal_cleanse: 100 } },
  first_blade:    { tpl: 'wpn_novice',    fx: { exp_pct: 50, hp_pct: 10, atk_pct: 10, def_pct: 10 } },
  pact_orb:       { tpl: 'wpn_summoner',  fx: { summon_pct: 30, summon_turns: 1 } },
  dead_totem:     { tpl: 'wpn_shaman',    fx: { debuff_pct: 20, debuff_turns: 1 } },
  iron_fist:      { tpl: 'wpn_brawler',   fx: { combo: 20 } },
  piercing_lance: { tpl: 'wpn_lancer',    fx: { pierce_line: 50 } },
  demolisher:     { tpl: 'wpn_sapper',    fx: { blast: 30 } },
  dragon_scale:   { tpl: 'plate_armor',   fx: { immune_fire: 1, def_pct: 20 } },
  warden_chain:   { tpl: 'chain_armor',   fx: { guard_aura: 15 } },
  windwalk:       { tpl: 'leather_boots', fx: { move: 1, immune_heat: 1 } },
  sage_robe:      { tpl: 'cloth_robe',    fx: { res_rec_pct: 50 } },
  king_seal:      { tpl: 'ring_power',    fx: { party_atk: 5 } },
  saint_tear:     { tpl: 'necklace_guard', fx: { last_stand: 30 } },
  time_earring:   { tpl: 'earring_swift', fx: { start_ap: 1 } }
};
var LEGEND_SHARD_COST = 5;   // 전설 조각 5개 = 원하는 전설 1개

// ── 직업 세트 (투구·갑옷·장화, 그 직업 전용) ──
var CLASS_SETS = {
  warrior:  { 2: { atk_pct: 10 }, 3: { desperate: 25, kill_heal: 8 } },
  knight:   { 2: { def_pct: 15 }, 3: { knock_immune: 1, intercept_red: 20 } },
  assassin: { 2: { speed: 0.1 }, 3: { backstab: 25, kill_ap: 1 } },
  mage:     { 2: { res_rec: 4 }, 3: { crit: 15, atk_pct: 10 } },
  archer:   { 2: { crit: 10 }, 3: { range: 1, atk_pct: 5 } },
  priest:   { 2: { heal_pct: 15 }, 3: { heal_cleanse: 50, hp_pct: 10 } },
  novice:   { 2: { hp_pct: 10 }, 3: { exp_pct: 30, atk_pct: 8 } },
  summoner: { 2: { res_rec: 3 }, 3: { summon_pct: 25 } },
  shaman:   { 2: { res_rec: 3 }, 3: { debuff_pct: 20, cleanse: 30 } },
  brawler:  { 2: { speed: 0.1 }, 3: { combo: 10, counter_up: 30 } },
  lancer:   { 2: { hp_pct: 10 }, 3: { charge: 25, knock_res: 30 } },
  sapper:   { 2: { def_pct: 10 }, 3: { blast: 20 } }
};
var SET_SLOTS = ['helmet', 'armor', 'boots'];
var RESONANCE_MUL = 1.2;   // 파티 공명: 조합 버프의 강화분 ×1.2 (공격 ×2 → ×2.2)

// ── 강화 옵션: 새 단계에 도달하면 확률로 1개 (단계에 묶임) ──
var ENHANCE_OPT = [
  { upTo: 3, chance: 0.25, pool: { hp_pct: [2, 4], atk_pct: [2, 4], def_pct: [2, 4], res_rec: [1, 2] } },
  { upTo: 6, chance: 0.40, pool: { hp_pct: [3, 6], atk_pct: [3, 6], def_pct: [3, 6], res_rec: [2, 3], speed: [0.03, 0.05], crit: [3, 6], knock_res: [10, 20], hazard_res: [15, 30] } },
  { upTo: 9, chance: 0.60, pool: { hp_pct: [5, 10], atk_pct: [5, 10], def_pct: [5, 10], res_rec: [3, 5], speed: [0.05, 0.08], crit: [6, 10], knock_res: [20, 30],
      hazard_res: [30, 50], move: [1, 1, 0.3], range: [1, 1, 0.2], kill_heal: [5, 8], regen: [2, 3], counter_up: [15, 25] } },
  { upTo: 10, chance: 1.00, unique: true }   // +10: A 등급 고유 효과 중 1개 (이미 가진 효과 제외)
];

// ── 획득처 ──
var GEAR_DROP = {
  bossLegend: { first: 0.15, repeat: 0.05 },
  dailyLegendHell: 0.03,
  dailySet: { easy: 0, normal: 0.10, hard: 0.18, hell: 0.30 },
  dailyStones: { easy: 2, normal: 3, hard: 5, hell: 8 },
  setRarity: { normal: 'rare', hard: 'rare', hell: 'epic' }
};
var MATS_PRICE = { stone: 200, protect: 1500 };
