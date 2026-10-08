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

function _rnd(r, dec) { var v = r[0] + Math.random() * (r[1] - r[0]); return dec ? Math.round(v * 100) / 100 : Math.round(v); }
function _isDec(id) { return GEAR_FX[id] && GEAR_FX[id].u === 'dec'; }
function _pickW(list) {
  var tot = list.reduce(function(s, o) { return s + (o.w || 1); }, 0), r = Math.random() * tot;
  for (var i = 0; i < list.length; i++) { r -= (list[i].w || 1); if (r <= 0) return list[i]; }
  return list[list.length - 1];
}

var Gear = {
  // ── 생성: 등급에 맞게 옵션 붙이기 ──
  roll: function(it) {
    var tier = RARITY[it.rarity] ? RARITY[it.rarity].tier : 0, mul = (RARITY_MULT[it.rarity] || 1) / 1.6;
    it.subs = []; it.cOpt = null; it.fx = null;
    var pool = this._subPool(it), n = SUB_COUNT[it.rarity] || 0;
    for (var i = 0; i < n && pool.length; i++) {
      var id = pool.splice(Math.floor(Math.random() * pool.length), 1)[0];
      var v = _rnd(SUB_RANGE[id], _isDec(id)) * mul;
      it.subs.push({ id: id, v: _isDec(id) ? Math.round(v * 100) / 100 : Math.max(1, Math.round(v)) });
    }
    if (tier >= 2) it.cOpt = this._rollClassOpt(it, mul);
    if (tier >= 3 && !it.legend) {
      var u = UNIQUE_POOL[Math.floor(Math.random() * UNIQUE_POOL.length)];
      it.fx = { id: u.id, v: Math.round(_rnd(u.r) * (tier >= 4 ? 1.25 : 1)) };
    }
    return it;
  },
  _subPool: function(it) {
    if (it.slot === 'weapon') return SUB_POOL.weapon.slice();
    if (it.slot === 'offhand') return SUB_POOL.offhand.slice();
    if (SET_SLOTS.indexOf(it.slot) >= 0) {
      var p = SUB_POOL.armor.slice();
      (SUB_ARMOR_EXTRA[it.armorType] || []).forEach(function(k) { if (p.indexOf(k) < 0) p.push(k); });
      return p;
    }
    return SUB_POOL.acc.slice();
  },
  _rollClassOpt: function(it, mul) {
    var classes = (it.clsRestrict || []).filter(function(c) { return CLASS_OPTS[c]; });
    if (!classes.length) classes = Object.keys(CLASS_OPTS);
    var cls = classes[Math.floor(Math.random() * classes.length)], o = _pickW(CLASS_OPTS[cls]);
    var v = _rnd(o.r, _isDec(o.id));
    if (GEAR_FX[o.id] && !GEAR_FX[o.id].noScale) v = _isDec(o.id) ? Math.round(v * mul * 100) / 100 : Math.max(1, Math.round(v * mul));
    return { cls: cls, id: o.id, v: v };
  },

  // ── 전설 장비 만들기: 아직 없는 전설 우선, id를 주면 그 전설 ──
  makeLegend: function(id) {
    if (!id) {
      var owned = {};
      try { (JSON.parse(localStorage.getItem('game_inventory')) || []).forEach(function(x) { if (x && x.legend) owned[x.legend] = 1; }); } catch (_) {}
      var ids = Object.keys(LEGENDS), fresh = ids.filter(function(k) { return !owned[k]; });
      var pool = fresh.length ? fresh : ids;
      id = pool[Math.floor(Math.random() * pool.length)];
    }
    var L = LEGENDS[id], tpl = equipTemplate(L.tpl);
    var it = generateEquip(tpl, 'legendary', { maxRoll: true, bare: true });
    it.legend = id; it.setId = null;
    this.roll(it);
    return it;
  },

  // ── 직업 세트 장비 한 부위 ──
  makeSetPiece: function(cls, slot, rarity) {
    slot = slot || SET_SLOTS[Math.floor(Math.random() * SET_SLOTS.length)];
    var type = CLASS_ARMOR[cls] || 'leather';
    var base = EQUIP_DB.find(function(d) { return d.slot === slot && d.armorType === type; });
    var it = generateEquip(base, rarity || 'rare', { bare: true });
    it.clsRestrict = [cls]; it.setId = 'cls_' + cls; it.setCls = cls;
    this.roll(it);
    if (it.cOpt) it.cOpt.cls = cls;   // 세트는 그 직업 전용이라 전용 옵션도 그 직업 것
    return it;
  },

  // ── 강화 옵션 굴리기 (도달 단계 lv) ──
  rollEnhanceOpt: function(it, lv) {
    var band = ENHANCE_OPT.find(function(b) { return lv <= b.upTo; });
    if (!band || Math.random() >= band.chance) return null;
    var have = {};
    if (it.fx) have[it.fx.id] = 1;
    if (it.legend) Object.keys(LEGENDS[it.legend].fx).forEach(function(k) { have[k] = 1; });
    Object.keys(it.eOpts || {}).forEach(function(k) { var o = it.eOpts[k]; if (o) have[o.id] = (have[o.id] || 0) + 1; });
    if (band.unique) {
      var pool = UNIQUE_POOL.filter(function(u) { return !have[u.id]; });
      if (!pool.length) pool = UNIQUE_POOL;
      var u = pool[Math.floor(Math.random() * pool.length)];
      return { id: u.id, v: _rnd(u.r), uq: 1 };
    }
    var list = Object.keys(band.pool).filter(function(k) { return !((k === 'move' || k === 'range') && have[k]); })
      .map(function(k) { var r = band.pool[k]; return { id: k, r: [r[0], r[1]], w: r[2] || 1 }; });
    var o = _pickW(list);
    return { id: o.id, v: _rnd(o.r, _isDec(o.id)) };
  },

  // ── 효과 목록: 이 장비가 cls에게 주는 효과 [{id, v}] (기본 능력치 제외) ──
  effects: function(it, cls) {
    if (!it || it.broken) return [];
    var out = [], lv = it.enhanceLv || 0, sMul = 1 + getEnhanceMultiplier(lv);
    var fxMul = lv >= 10 ? 1.5 : lv >= 5 ? 1.25 : 1;
    var push = function(id, v, m) {
      var d = GEAR_FX[id] || {};
      if (m && !d.noScale) v = _isDec(id) ? Math.round(v * m * 100) / 100 : Math.round(v * m);
      out.push({ id: id, v: v });
    };
    (it.subs || []).forEach(function(s) { push(s.id, s.v, sMul); });
    if (it.cOpt && (!cls || it.cOpt.cls === cls)) push(it.cOpt.id, it.cOpt.v, lv >= 10 ? 2 : 1);
    if (it.fx) push(it.fx.id, it.fx.v, fxMul);
    if (it.legend && LEGENDS[it.legend]) { var f = LEGENDS[it.legend].fx; Object.keys(f).forEach(function(k) { push(k, f[k], fxMul); }); }
    var eo = it.eOpts || {};
    Object.keys(eo).forEach(function(k) { if (eo[k]) push(eo[k].id, eo[k].v, eo[k].uq ? fxMul : 1); });
    return out;
  },
  setEffects: function(cls, count) {
    var s = CLASS_SETS[cls], out = [];
    if (!s) return out;
    [2, 3].forEach(function(n) { if (count >= n && s[n]) Object.keys(s[n]).forEach(function(k) { out.push({ id: k, v: s[n][k] }); }); });
    return out;
  },

  // ── 기존 저장 전환 ──
  migrate: function(it) {
    var nw = LEGACY_WEAPON[it.templateId];
    if (nw) { var tpl = equipTemplate(nw); it.templateId = nw; it.hand = tpl.hand; it.clsRestrict = tpl.clsRestrict.slice(); }
    else if (it.armorType && ARMOR_TYPE[it.armorType] && !it.setCls) it.clsRestrict = ARMOR_TYPE[it.armorType].slice();
    delete it.enhanceAttempts;
    it.enhanceBonus = 0; it.eOpts = {}; it.broken = false; it.legend = it.legend || null;
    this.roll(it);
    for (var lv = 1; lv <= (it.enhanceLv || 0); lv++) { var o = this.rollEnhanceOpt(it, lv); if (o) it.eOpts[lv] = o; }
    it.gv = 2;
  },

  // ── 표시 ──
  name: function(it) {
    if (!it) return '';
    if (it.legend) return t('gear.legend.' + it.legend);
    if (it.setCls) return t('gear.set_piece', { set: t('gear.set.' + it.setCls), slot: t('equip.slot.' + it.slot) });
    var k = 'gear.item.' + it.templateId, v = t(k);
    return v && v !== k ? v : t('equip.item.' + it.templateId);
  },
  fmt: function(id, v) {
    var d = GEAR_FX[id] || {};
    var val = d.u === 'dec' ? (+v).toFixed(2) : String(v);
    return t('gear.fx.' + id, { v: val });
  },
  // 툴팁·카드용 옵션 줄 [{cls:'sub|copt|fx|legend|eopt|off', text}]
  lines: function(it, cls) {
    if (!it) return [];
    var L = [], self = this, lv = it.enhanceLv || 0, sMul = 1 + getEnhanceMultiplier(lv), fxMul = lv >= 10 ? 1.5 : lv >= 5 ? 1.25 : 1;
    var sc = function(id, v, m) { var d = GEAR_FX[id] || {}; if (!m || d.noScale) return v; return _isDec(id) ? Math.round(v * m * 100) / 100 : Math.round(v * m); };
    if (it.legend) { var f = LEGENDS[it.legend].fx; Object.keys(f).forEach(function(k) { L.push({ c: 'legend', text: '★ ' + self.fmt(k, sc(k, f[k], fxMul)) }); }); }
    if (it.fx) L.push({ c: 'fx', text: '◆ ' + self.fmt(it.fx.id, sc(it.fx.id, it.fx.v, fxMul)) });
    (it.subs || []).forEach(function(s) { L.push({ c: 'sub', text: '+ ' + self.fmt(s.id, sc(s.id, s.v, sMul)) }); });
    if (it.cOpt) {
      var on = !cls || it.cOpt.cls === cls;
      L.push({ c: on ? 'copt' : 'off', text: '[' + t('classes.' + it.cOpt.cls) + '] ' + self.fmt(it.cOpt.id, sc(it.cOpt.id, it.cOpt.v, lv >= 10 ? 2 : 1)) });
    }
    var eo = it.eOpts || {};
    Object.keys(eo).sort(function(a, b) { return a - b; }).forEach(function(k) {
      if (eo[k]) L.push({ c: 'eopt', text: '+' + k + ' ' + self.fmt(eo[k].id, eo[k].uq ? sc(eo[k].id, eo[k].v, fxMul) : eo[k].v) });
    });
    if (it.setCls) {
      var s = CLASS_SETS[it.setCls];
      [2, 3].forEach(function(n) { L.push({ c: 'set', text: t('gear.set_bonus', { n: n }) + ' ' + Object.keys(s[n]).map(function(k) { return self.fmt(k, s[n][k]); }).join(' · ') }); });
    }
    return L;
  },
  linesHtml: function(it, cls) {
    return this.lines(it, cls).map(function(l) { return '<div class="gear-line gl-' + l.c + '">' + l.text + '</div>'; }).join('');
  },

  // ── 획득 ──
  give: function(item) { var inv = loadInventory(); inv.push(item); saveInventory(inv); return item; },
  // 전설 조각으로 원하는 전설 교환
  exchangeLegend: function(id) {
    if (!LEGENDS[id] || Mats.get('shard') < LEGEND_SHARD_COST) return null;
    Mats.add('shard', -LEGEND_SHARD_COST);
    return this.give(this.makeLegend(id));
  }
};

// ═══════════════════════════════════════════
//  GearFX — 전투 효과 (calcDmg·EnchantFX.afterHit·applyDmgToAlly·EventBus에 연결)
// ═══════════════════════════════════════════
var GearFX = {
  g: function(u, k) { return (u && u.gear && u.gear[k]) || 0; },
  _bound: false,

  // 전투 시작: 보호막·회복량·선공·파티 공격·공명 (새 전투에서만)
  init: function(S) {
    var allies = S.units.filter(function(u) { return u.team === 'ally' && !u.isSummon; }), self = this;
    var partyAtk = 0;
    allies.forEach(function(u) {
      if (self.g(u, 'start_shield')) u._barrier = Math.round(u.mhp * self.g(u, 'start_shield') / 100);
      if (self.g(u, 'heal_pct')) u._healMul = (u._healMul || 1) * (1 + self.g(u, 'heal_pct') / 100);
      if (self.g(u, 'start_ap')) u.actionPow = 5;
      partyAtk = Math.max(partyAtk, self.g(u, 'party_atk'));
    });
    if (partyAtk) allies.forEach(function(u) { u.atk = Math.round(u.atk * (1 + partyAtk / 100)); });
    this.bind();
  },
  // 파티 공명: 같은 직업 세트를 다 갖춘 클랜원 2명 이상 → 그 직업 조합 버프 강화
  resonance: function(S) {
    var n = {};
    S.units.forEach(function(u) { if (u.team === 'ally' && u._fullSet) n[u._fullSet] = (n[u._fullSet] || 0) + 1; });
    (S._synergies || []).forEach(function(s) {
      if (!s.cls || (n[s.cls] || 0) < 2) return;
      var e = {}; Object.keys(s.eff).forEach(function(k) {
        var v = s.eff[k];
        e[k] = (typeof v === 'number' && ['atk', 'def', 'hp', 'heal'].indexOf(k) >= 0 && v > 1) ? Math.round((1 + (v - 1) * RESONANCE_MUL) * 100) / 100 : v;
      });
      s.eff = e; s.resonance = true;
    });
  },

  // 이벤트 연결 (저장된 전투 이어하기에서도 호출)
  bind: function() {
    if (this._bound || typeof EventBus === 'undefined') return;
    this._bound = true;
    var self = this;
    EventBus.on('unit_killed', function(d) {
      var k = d && d.killer; if (!k || k.hp <= 0 || !k.gear) return;
      var kh = self.g(k, 'kill_heal');
      if (kh) { var h = Math.min(k.mhp - k.hp, Math.round(k.mhp * kh / 100)); if (h > 0) { k.hp += h; self._float(k, '+' + h, 'heal'); } }
      var ap = self.g(k, 'kill_ap');
      if (ap) { k.actionPow = (k.actionPow || 0) + ap; self._float(k, '⚡+' + ap, 'heal'); }
    });
    EventBus.on('turn_end', function(d) {
      var u = d && d.unit; if (!u) return;
      u._movedDist = 0;
      if (!u.gear || u.hp <= 0) return;
      var rg = self.g(u, 'regen');
      if (rg && u.hp < u.mhp) { var h = Math.min(u.mhp - u.hp, Math.max(1, Math.round(u.mhp * rg / 100))); u.hp += h; self._float(u, '+' + h, 'heal'); }
      var cl = self.g(u, 'cleanse');
      if (cl && Math.random() < cl / 100 && self.cleanse(u, 1)) self._float(u, '✨', 'heal');
    });
    EventBus.on('unit_moved', function(d) {
      if (!d || !d.unit || !d.from || !d.to) return;
      d.unit._movedDist = (d.unit._movedDist || 0) + Math.abs(d.from.x - d.to.x) + Math.abs(d.from.y - d.to.y);
    });
    EventBus.on('skill_used', function(d) {
      var u = d && (d.unit || d.caster); if (!u || !u.gear) return;
      if (self.g(u, 'focus')) u._focus = true;
      var sk = d.skill && typeof d.skill === 'object' ? d.skill : null;
      var mf = self.g(u, 'mana_free');
      if (mf && sk && sk.cost && Math.random() < mf / 100) { u.res = Math.min(u.maxRes, u.res + sk.cost); self._float(u, '🌟', 'heal'); }
      // 소환수 강화: 스킬 처리 직후 새로 생긴 소환수에 적용
      if (self.g(u, 'summon_pct') || self.g(u, 'summon_turns')) setTimeout(function() {
        GameStore.units.forEach(function(s) {
          if (!s.isSummon || s.summonerId !== u.id || s._gearBuffed) return;
          s._gearBuffed = true;
          var m = 1 + self.g(u, 'summon_pct') / 100;
          s.mhp = Math.round(s.mhp * m); s.hp = Math.round(s.hp * m); s.atk = Math.round(s.atk * m); s.def = Math.round(s.def * m);
          if (s.summonTurns !== undefined) s.summonTurns += self.g(u, 'summon_turns');
        });
      }, 0);
    });
    EventBus.on('unit_healed', function(d) {
      if (!d || !d.healer || !d.target || d.isPotion) return;
      var hc = self.g(d.healer, 'heal_cleanse');
      if (hc && Math.random() < hc / 100 && self.cleanse(d.target, hc >= 100 ? 99 : 1)) self._float(d.target, '✨', 'heal');
    });
    EventBus.on('buff_applied', function(d) {
      var b = d && d.buff, tgt = d && d.unit;
      if (!b || !tgt || tgt.team !== 'enemy' || String(b.source || '').indexOf('shaman') !== 0 || b._gearMod) return;
      if (typeof _isDebuff === 'function' && !_isDebuff(b.type)) return;
      var sh = GameStore.units.filter(function(u) { return u.team === 'ally' && u.hp > 0 && u.gear && (u.gear.debuff_pct || u.gear.debuff_turns); })
        .sort(function(a, c) { return (c.gear.debuff_pct || 0) - (a.gear.debuff_pct || 0); })[0];
      if (!sh) return;
      b._gearMod = true;
      if (b.value) b.value = Math.round(b.value * (1 + self.g(sh, 'debuff_pct') / 100));
      b.duration = (b.duration || 1) + self.g(sh, 'debuff_turns');
    });
  },

  // 디버프 해제 (n개, 99 = 전부) → 해제했으면 true
  cleanse: function(u, n) {
    var done = 0;
    if (u.buffs && typeof _isDebuff === 'function') {
      for (var i = u.buffs.length - 1; i >= 0 && done < n; i--) if (_isDebuff(u.buffs[i].type)) { u.buffs.splice(i, 1); done++; }
    }
    ['stunned', 'frozen', 'disarmed', '_rootedTurns', '_bleedTurns'].forEach(function(k) { if (done < n && u[k] > 0) { u[k] = 0; done++; } });
    return done > 0;
  },

  // 피해 보정 (calcDmg 끝에서): 공격자 효과 + 대상 쪽 감소. 미리보기에서도 불리므로 상태를 바꾸지 않음 (치명타 판정만 무작위)
  mod: function(a, t, dmg) {
    if (!a || !t) return dmg;
    var m = 1, g = this.g.bind(this);
    if (a.gear) {
      var cr = g(a, 'crit');
      if (cr && Math.random() < cr / 100) { m *= 1.5; a._lastCrit = true; }
      if (g(a, 'first_crit') && !a._firstHit) { m *= 1 + g(a, 'first_crit') / 100; a._lastCrit = true; }
      if (g(a, 'desperate') && a.hp <= a.mhp * 0.3) m *= 1 + g(a, 'desperate') / 100;
      if (g(a, 'charge') && (a._movedDist || 0) >= 2) m *= 1 + g(a, 'charge') / 100;
      if (g(a, 'focus') && a._focus) m *= 1 + g(a, 'focus') / 100;
      if (g(a, 'backstab') && a._lastTactic && a._lastTactic.tags && a._lastTactic.tags.indexOf('back') >= 0) m *= 1 + g(a, 'backstab') / 100;
      if (g(a, 'combo') && a._comboTgt === t.id) m *= 1 + g(a, 'combo') / 100 * Math.min(5, a._comboN || 0);
      if (g(a, 'stack_atk')) m *= 1 + g(a, 'stack_atk') / 100 * Math.min(5, a._oath || 0);
    }
    if (t.gear && g(t, 'dmg_red')) m *= 1 - Math.min(80, g(t, 'dmg_red')) / 100;
    // 수호 오라: 대상 옆(대상 자신 제외)의 같은 편 중 가장 큰 값
    if (typeof GameStore !== 'undefined' && GameStore.units) {
      var aura = 0;
      GameStore.units.forEach(function(v) {
        if (v.hp > 0 && v.id !== t.id && v.team === t.team && v.gear && v.gear.guard_aura && Math.abs(v.x - t.x) + Math.abs(v.y - t.y) === 1) aura = Math.max(aura, v.gear.guard_aura);
      });
      if (aura) m *= 1 - Math.min(50, aura) / 100;
    }
    return m === 1 ? dmg : Math.max(1, Math.round(dmg * m));
  },

  // 명중 뒤 (EnchantFX.afterHit에서 호출): 누적·연타·분노·폭발·관통
  afterHit: function(a, t, dmg) {
    if (!a || !a.gear || !t) return;
    a._firstHit = true; a._focus = false;
    if (this.g(a, 'combo')) { if (a._comboTgt === t.id) a._comboN = (a._comboN || 0) + 1; else { a._comboTgt = t.id; a._comboN = 1; } }
    if (this.g(a, 'stack_atk')) a._oath = Math.min(5, (a._oath || 0) + 1);
    if (this.g(a, 'fury_gain') && a.resType === 'fury') a.res = Math.min(a.maxRes, a.res + this.g(a, 'fury_gain'));
    var self = this, hitAt = function(x, y, pct) {
      var v = UnitManager.uAt(x, y);
      if (!v || v.hp <= 0 || v.team !== t.team || v.id === t.id) return;
      var d2 = Math.max(1, Math.round(dmg * pct / 100));
      v.hp = Math.max(0, v.hp - d2);
      EventBus.emit('unit_attacked', { attacker: a, target: v, damage: d2, isSplash: true });
      if (v.hp <= 0) EventBus.emit('unit_killed', { killer: a, target: v });
    };
    var bl = this.g(a, 'blast');
    if (bl) [[0, -1], [0, 1], [-1, 0], [1, 0]].forEach(function(d) { hitAt(t.x + d[0], t.y + d[1], bl); });
    var pl = this.g(a, 'pierce_line');
    if (pl) {
      var dx = t.x - a.x, dy = t.y - a.y;
      if (Math.abs(dx) >= Math.abs(dy)) { dx = Math.sign(dx); dy = 0; } else { dy = Math.sign(dy); dx = 0; }
      if (dx || dy) hitAt(t.x + dx, t.y + dy, pl);
    }
  },

  // 클랜원이 받는 피해 흡수 (applyDmgToAlly): 보호막 → 성자의 눈물(1회 버팀). 남은 피해를 돌려줌
  absorb: function(u, dmg) {
    if (!u || dmg <= 0) return dmg;
    if (u._barrier > 0) {
      var a = Math.min(u._barrier, dmg); u._barrier -= a; dmg -= a;
      this._float(u, '🛡️-' + a, 'heal');
    }
    if (dmg >= u.hp && this.g(u, 'last_stand') && !u._lastStandUsed) {
      u._lastStandUsed = true;
      u.hp = Math.max(1, Math.round(u.mhp * this.g(u, 'last_stand') / 100));
      this._float(u, '💧 ' + t('gear.fx_last_stand_proc'), 'heal');
      return 0;
    }
    return dmg;
  },

  // 대신 맞기(투사체 차단·엄호) 피해 보정과 분노
  intercept: function(blk, dmg) {
    if (!blk || !blk.gear) return dmg;
    var r = this.g(blk, 'intercept_red');
    if (r) dmg = Math.max(1, Math.round(dmg * (1 - Math.min(80, r) / 100)));
    if (this.g(blk, 'intercept_fury') && blk.resType === 'fury') blk.res = Math.min(blk.maxRes, blk.res + this.g(blk, 'intercept_fury'));
    return dmg;
  },
  counterMul: function(u) { return 1 + this.g(u, 'counter_up') / 100; },
  knockResist: function(u) { if (this.g(u, 'knock_immune')) return 1; return this.g(u, 'knock_res') / 100; },
  hazardMul: function(u) { return 1 - Math.min(90, this.g(u, 'hazard_res')) / 100; },

  _float: function(u, txt, kind) { try { if (typeof Renderer !== 'undefined') Renderer.floatT(u.x, u.y, txt, kind); } catch (_) {} }
};
