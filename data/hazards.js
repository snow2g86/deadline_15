// ═══════════════════════════════════════════
//  data/hazards.js — 맵 환경 디버프 · 장비 마법부여 · 보물상자
//  ① 환경: 맵 종류(stage.mapType)마다 클랜원에게 제약. 그 디버프에 맞는 마법부여 장비를 하나라도 장착한 클랜원은 무효
//     (적 총원을 줄인 대신 난이도를 맵 특성으로 보충 — data/stages.js 전투 길이 조정 참고)
//  ② 마법부여: 성소 '마법부여' 탭에서 가진 장비에 마법부여 룬 1개 + 100G로 저항 하나를 새김 (item.enchant).
//     장비 하나에 마법부여는 하나뿐 — 다른 룬으로 부여하면 덮어씀(같은 종류는 불가), 쓴 룬은 사라짐. 룬은 전투 승리 드랍·상점 룬 뽑기·보물상자로 얻음
//  ③ 보물상자: 전투 시작 때 맵 가운데 구역에 무작위로 놓이고, 클랜원이 밟으면 열림 (골드·전투 물약·장비·영혼석 조각·룬)
// ═══════════════════════════════════════════
// dot: 클랜원 차례가 끝날 때 최대 HP 비율 피해 (사망하지는 않음, 후반일수록 커짐) · move/range: 더하기 · def/heal: 배율
var HAZARDS = {
  volcano: { id: 'burn',     icon: '🔥', enchant: 'fire',   dot: 0.05 },
  abyss:   { id: 'hellfire', icon: '☄️', enchant: 'fire',   dot: 0.07 },
  desert:  { id: 'heat',     icon: '☀️', enchant: 'heat',   move: -1 },
  canyon:  { id: 'gale',     icon: '🌪️', enchant: 'wind',   range: -1 },
  jungle:  { id: 'venom',    icon: '🦟', enchant: 'poison', dot: 0.03 },
  swamp:   { id: 'miasma',   icon: '☠️', enchant: 'poison', dot: 0.04 },
  frozen:  { id: 'frost',    icon: '❄️', enchant: 'cold',   def: 0.75 },
  ruins:   { id: 'curse',    icon: '🕯️', enchant: 'curse',  heal: 0.5 },
  // plains · fortress: 환경 디버프 없음
};
// cat: 'def' = 환경 저항(item.enchant), 'atk' = 공격 효과(item.enchantAtk). 한 장비에 방어·공격 하나씩 함께 새길 수 있음
var ENCHANTS = {
  fire:   { icon: '🔥', cat: 'def' }, heat: { icon: '☀️', cat: 'def' }, wind: { icon: '🌪️', cat: 'def' },
  poison: { icon: '🧪', cat: 'def' }, cold: { icon: '❄️', cat: 'def' }, curse: { icon: '✨', cat: 'def' },
  // 공격용: 장착한 클랜원의 일반 공격(반격·경계 사격 포함)에 붙는 효과
  flame:  { icon: '🔥', cat: 'atk', burn: 0.15, turns: 2 },   // 화상: 턴당 공격력 15%
  frost:  { icon: '🧊', cat: 'atk', freeze: 0.20 },           // 20% 확률 1턴 빙결
  venom:  { icon: '🐍', cat: 'atk', poison: 0.10, turns: 3 }, // 독: 턴당 공격력 10%
  thunder:{ icon: '⚡', cat: 'atk', dmg: 0.15 },              // 피해 +15%
  vamp:   { icon: '🩸', cat: 'atk', drain: 0.15 },            // 준 피해의 15% 회복
  sunder: { icon: '🔨', cat: 'atk', pierce: 0.30 },           // 방어력 30% 무시
};
var ENCHANT_FIELD = { def: 'enchant', atk: 'enchantAtk' };
var ENCHANT_FEE = 100;        // 마법부여 1회 비용 (고정)
var RUNE_GACHA_COST = 300;    // 상점 룬 뽑기 1회 (무작위 룬 1개)
var RUNE_DROP_CHANCE = 0.2;   // 전투 승리 시 룬 드랍 확률

// ── 마법부여 룬 (인벤토리 { type: 'rune', enchant }) ──
var Rune = {
  kinds: function(cat) { return Object.keys(ENCHANTS).filter(function(k) { return !cat || ENCHANTS[k].cat === cat; }); },
  random: function() { var k = this.kinds(); return k[Math.floor(Math.random() * k.length)]; },
  add: function(kind) { var inv = loadInventory(); inv.push({ type: 'rune', enchant: kind, rid: Date.now() + Math.random() }); saveInventory(inv); return kind; },
  count: function(kind) { return loadInventory().filter(function(i) { return i.type === 'rune' && (!kind || i.enchant === kind); }).length; },
  // 장비 eid에 kind 룬으로 마법부여: 룬 1개·ENCHANT_FEE 소모. 같은 분류(방어/공격)의 기존 마법부여는 덮어씀, 같은 종류면 불가 → true/사유 문자열
  apply: function(eid, kind) {
    var inv = loadInventory(), it = inv.find(function(x) { return x.eid === eid && x.type === 'equip'; });
    if (!it) return 'no_item';
    var field = ENCHANT_FIELD[ENCHANTS[kind].cat];
    if (it[field] === kind) return 'already';
    var ri = inv.findIndex(function(x) { return x.type === 'rune' && x.enchant === kind; });
    if (ri < 0) return 'no_rune';
    var gold = loadGold(); if (gold < ENCHANT_FEE) return 'no_gold';
    inv.splice(ri, 1); it[field] = kind;
    saveInventory(inv); saveGold(gold - ENCHANT_FEE);
    return true;
  },
};

var Hazard = {
  forStage: function(stage) { return stage && HAZARDS[stage.mapType] || null; },
  // 후반일수록 지속 피해가 커짐: 1 + 스테이지 레벨/100 배
  dotPct: function(h, stage) { return h && h.dot ? h.dot * (1 + (typeof stageLevel === 'function' ? stageLevel(stage) : stage.id) / 100) : 0; },
  // 이 캐릭터가 장착한 장비의 마법부여 목록
  enchantsOf: function(ch) {
    if (!ch || !ch.equip || typeof loadInventory !== 'function') return [];
    var inv = loadInventory(), out = [];
    Object.keys(ch.equip).forEach(function(slot) {
      var eid = ch.equip[slot]; if (!eid) return;
      var it = inv.find(function(x) { return x.eid === eid; });
      if (!it) return;
      [it.enchant, it.enchantAtk].forEach(function(k) { if (k && out.indexOf(k) === -1) out.push(k); });
    });
    return out;
  },
  protects: function(u, h) { return !!(h && u.enchants && u.enchants.indexOf(h.enchant) !== -1); },
  // 전투 시작 때 클랜원에 적용 (마법부여로 막은 클랜원 제외)
  apply: function(units, stage) {
    var h = this.forStage(stage); if (!h) return null;
    units.forEach(function(u) {
      if (u.team !== 'ally' || u.isSummon) return;
      if (Hazard.protects(u, h)) { u._hazardSafe = true; return; }
      if (h.move) u.move = Math.max(1, u.move + h.move);
      if (h.range && u.range > 1) u.range = Math.max(2, u.range + h.range);
      if (h.def) u.def = Math.round(u.def * h.def);
      if (h.heal) u._healMul = (u._healMul || 1) * h.heal;
      if (h.dot) u._hazardDot = true;
    });
    return h;
  },
  name: function(h) { return t('hazard.' + h.id); },
  describe: function(h, stage) {
    var p = [];
    if (h.dot) p.push(t('hazard.fx_dot', { n: Math.round(Hazard.dotPct(h, stage) * 100) }));
    if (h.move) p.push(t('hazard.fx_move', { n: h.move }));
    if (h.range) p.push(t('hazard.fx_range', { n: h.range }));
    if (h.def) p.push(t('hazard.fx_def', { n: Math.round((1 - h.def) * 100) }));
    if (h.heal) p.push(t('hazard.fx_heal', { n: Math.round((1 - h.heal) * 100) }));
    return p.join(' · ') + ' — ' + t('hazard.counter', { e: ENCHANTS[h.enchant].icon + ' ' + t('enchant.' + h.enchant) });
  },
};

// ── 공격용 마법부여 효과 (전투) ──
var EnchantFX = {
  _atk: function(u) { return (u && u.enchants || []).filter(function(k) { return ENCHANTS[k] && ENCHANTS[k].cat === 'atk'; }); },
  // 피해 계산 보정: 번개(+%), 파쇄(방어 일부 무시 → 그만큼 피해 추가)
  modDamage: function(a, t, dmg) {
    this._atk(a).forEach(function(k) {
      var e = ENCHANTS[k];
      if (e.dmg) dmg = Math.round(dmg * (1 + e.dmg));
      if (e.pierce) dmg += Math.round((t.def || 0) * e.pierce);
    });
    return Math.max(1, dmg);
  },
  // 명중 후: 화상·독(지속 피해), 빙결(확률), 흡혈(회복). 표시는 공격자/대상 위 작은 글자
  afterHit: function(a, t, dmg) {
    if (!a || !t || dmg <= 0) return;
    this._atk(a).forEach(function(k) {
      var e = ENCHANTS[k];
      if (t.hp > 0 && e.burn) BuffSystem.apply(t, { type: BuffType.BLEED, duration: e.turns, value: Math.max(1, Math.round(a.atk * e.burn)), icon: e.icon, source: 'enchant_flame' });
      if (t.hp > 0 && e.poison) BuffSystem.apply(t, { type: BuffType.POISON, duration: e.turns, value: Math.max(1, Math.round(a.atk * e.poison)), icon: e.icon, source: 'enchant_venom' });
      if (t.hp > 0 && e.freeze && Math.random() < e.freeze) { BuffSystem.apply(t, { type: BuffType.FREEZE, duration: 1, icon: e.icon, source: 'enchant_frost' }); Renderer.floatT(t.x, t.y, e.icon + ' ' + t_('enchant.frozen'), 'debuff'); }
      if (e.drain && a.hp > 0) { var h = Math.min(a.mhp - a.hp, Math.max(1, Math.round(dmg * e.drain))); if (h > 0) { a.hp += h; Renderer.floatT(a.x, a.y, e.icon + ' +' + h, 'heal'); } }
    });
    if (typeof GearFX !== 'undefined') GearFX.afterHit(a, t, dmg);   // 장비 효과 (연타·누적·폭발·관통)
  },
};
function t_(k) { return typeof t === 'function' ? t(k) : k; }

// ── 보물상자 ──
// 전투당 1~2개, 3~9행의 빈 평지·숲·언덕에 놓임. 보상 확률: 골드 32% · 전투 물약 17% · 마법부여 룬 15% · 장비 13% · 강화석 11% · 보호 주문서 2% · 영혼석 조각 10%
var CHEST = { min: 1, max: 2, rows: [3, 9], odds: { gold: 0.32, potion: 0.17, rune: 0.15, equip: 0.13, stone: 0.11, protect: 0.02, soul: 0.10 } };
var Chest = {
  place: function(S) {
    var n = CHEST.min + Math.floor(Math.random() * (CHEST.max - CHEST.min + 1)), cells = [];
    for (var y = CHEST.rows[0]; y <= CHEST.rows[1]; y++) for (var x = 0; x < COLS; x++) {
      var tile = S.ter[y][x];
      if (TI[tile] && TI[tile].pass && tile !== 'shallow' && !UnitManager.uAt(x, y)) cells.push({ x: x, y: y });
    }
    S.chests = [];
    for (var i = 0; i < n && cells.length; i++) S.chests.push(cells.splice(Math.floor(Math.random() * cells.length), 1)[0]);
  },
  at: function(S, x, y) { return (S.chests || []).find(function(c) { return c.x === x && c.y === y; }); },
  // 열기: 보상을 바로 저장 (전투에서 져도 얻은 것은 유지) → { kind, text }
  open: function(S, c, opener) {
    S.chests = S.chests.filter(function(k) { return k !== c; });
    var r = Math.random(), o = CHEST.odds, lv = typeof stageLevel === 'function' ? stageLevel(S.cStage) : 1;
    if (r < o.gold) {
      var g = Math.round((40 + lv * 8) * (0.8 + Math.random() * 0.4));
      S.gold += g; saveGold(S.gold);
      return { kind: 'gold', text: '🪙 +' + g + 'G' };
    }
    if (r < o.gold + o.potion) {
      var keys = Object.keys(BATTLE_POTIONS), pid = keys[Math.floor(Math.random() * keys.length)], def = BATTLE_POTIONS[pid];
      var inv = loadInventory(); inv.push({ type: 'battle_potion', pid: Date.now(), potionId: pid, icon: def.icon, quantity: 1 }); saveInventory(inv);
      if (S._battlePotions) { S._battlePotions.push(inv[inv.length - 1]); S._battlePotionIndices.push(inv.length - 1); }   // 이번 전투에서 바로 사용 가능
      return { kind: 'potion', text: def.icon + ' ' + t('battle_potions.' + pid) };
    }
    if (r < o.gold + o.potion + o.rune) {
      var rk = Rune.add(Rune.random());
      return { kind: 'rune', text: ENCHANTS[rk].icon + ' ' + t('enchant.rune_name', { e: t('enchant.' + rk) }) };
    }
    if (r < o.gold + o.potion + o.rune + o.equip) {
      var it = gachaPull(null, true); var inv2 = loadInventory(); inv2.push(it); saveInventory(inv2);
      return { kind: 'equip', text: getEquipEmoji(it.templateId) + ' ' + Gear.name(it) };
    }
    if (r < o.gold + o.potion + o.rune + o.equip + o.stone) {
      var ns = 1 + Math.floor(Math.random() * 3); Mats.add('stone', ns);
      return { kind: 'stone', text: '🔩 ' + t('gear.stone') + ' +' + ns };
    }
    if (r < o.gold + o.potion + o.rune + o.equip + o.stone + o.protect) {
      Mats.add('protect', 1);
      return { kind: 'protect', text: '📜 ' + t('gear.protect') + ' +1' };
    }
    var cls = opener && opener.cls !== 'commander' ? opener.cls : 'novice';
    if (typeof Soul !== 'undefined') Soul.add('frag', cls, 2);
    return { kind: 'soul', text: '💠 ' + t('soul.reward_frag', { cls: t('classes.' + cls) }) + ' +2' };
  },
};
