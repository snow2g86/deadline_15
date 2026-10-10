// ═══════════════════════════════════════════
//  logic/equip.js — 장비 계산 (인벤토리 저장, 뽑기, 장착 보너스, 강화·수리·분해, 재료)
//  수치·표는 data/equip.js (순수 데이터), 여기는 그 데이터를 쓰는 계산. 페이지에서 data/equip.js 바로 뒤에 불러온다
// ═══════════════════════════════════════════


function equipTemplate(baseId) {
  for (var i = 0; i < EQUIP_DB.length; i++) if (EQUIP_DB[i].baseId === baseId) return EQUIP_DB[i];
  return null;
}

var INV_KEY = 'game_inventory';

function loadInventory() {
  try {
    var raw = Store.get(INV_KEY);
    if (raw) {
      var inv = JSON.parse(raw);
      // 장비 개편 전 저장 → 새 구조로 한 번 전환 (옵션 부여, 예전 무기 → 직업 무기)
      if (typeof Gear !== 'undefined' && inv.some(function(it) { return it && it.type === 'equip' && !it.gv; })) {
        inv.forEach(function(it) { if (it && it.type === 'equip' && !it.gv) Gear.migrate(it); });
        saveInventory(inv);
      }
      return inv;
    }
  } catch (_) {}
  return [];
}

function saveInventory(inv) {
  try { Store.set(INV_KEY, JSON.stringify(inv)); } catch (_) {}
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

// 기본 능력치만 굴린 장비 (옵션은 Gear.roll이 등급에 맞게 붙임)
function generateEquip(template, rarity, opts) {
  opts = opts || {};
  var mult = RARITY_MULT[rarity];
  var rolled = {};
  for (var stat in template.stats) {
    var range = template.stats[stat];
    var base = opts.maxRoll ? range[1] : range[0] + Math.random() * (range[1] - range[0]);
    rolled[stat] = Math.round(base * mult);
    if (rolled[stat] < 1) rolled[stat] = 1;
  }
  var cls = template.clsRestrict ? template.clsRestrict.slice() :
    (template.armorType ? ARMOR_TYPE[template.armorType].slice() : ALL_CLASSES.slice());
  var item = {
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
    enhanceBonus: 0,     // 연속 실패 보정 (%p)
    subs: [], cOpt: null, fx: null, legend: null, eOpts: {}, broken: false,
    gv: 2
  };
  if (!opts.bare && typeof Gear !== 'undefined') Gear.roll(item);
  return item;
}

var PITY_KEY = 'game_gacha_pity';

function loadPity() {
  try { var v = parseInt(Store.get(PITY_KEY), 10); return isNaN(v) ? 0 : v; } catch (_) { return 0; }
}
function savePity(count) {
  try { Store.set(PITY_KEY, String(count)); } catch (_) {}
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
  // S 등급은 이름 있는 전설 장비 (아직 없는 전설 우선)
  if (rarity === 'legendary' && typeof Gear !== 'undefined') return Gear.makeLegend();
  var tpl = EQUIP_DB[Math.floor(Math.random() * EQUIP_DB.length)];
  return generateEquip(tpl, rarity);
}

// 캐릭터의 장비 보너스: 기본·강화 능력치 + 추가 능력치·전용 옵션·고유/전설 효과·세트
// 반환: { hp, atk, def, move, range, gear: {효과id: 값}, fullSet: 직업|null } — 퍼센트 능력치는 hp/atk/def에 합쳐서 돌려줌
function calcEquipBonus(ch) {
  var bonus = { hp: 0, atk: 0, def: 0, move: 0, range: 0, gear: {}, fullSet: null };
  if (!ch || !ch.equip) return bonus;
  var inv = loadInventory();
  var invMap = {};
  for (var i = 0; i < inv.length; i++) {
    if (inv[i].type === 'equip') invMap[inv[i].eid] = inv[i];
  }
  var setCounts = {}, pct = { hp: 0, atk: 0, def: 0 };
  var add = function(k, v) {
    if (k === 'hp_pct' || k === 'atk_pct' || k === 'def_pct') pct[k.slice(0, -4)] += v;
    else if (k === 'move' || k === 'range') bonus[k] += v;
    else bonus.gear[k] = (bonus.gear[k] || 0) + v;
  };
  for (var s = 0; s < EQUIP_SLOTS.length; s++) {
    var eid = ch.equip[EQUIP_SLOTS[s]];
    if (!eid) continue;
    var item = invMap[eid];
    if (!item || item.broken) continue;
    var enhancedStats = getEnhancedStats(item);
    for (var stat in enhancedStats) {
      if (bonus[stat] !== undefined) bonus[stat] += enhancedStats[stat];
    }
    if (typeof Gear !== 'undefined') Gear.effects(item, ch.cls).forEach(function(e) { add(e.id, e.v); });
    if (item.setId) {
      setCounts[item.setId] = (setCounts[item.setId] || 0) + 1;
    }
  }
  for (var setId in setCounts) {
    var count = setCounts[setId];
    if (setId.indexOf('cls_') === 0 && typeof Gear !== 'undefined') {   // 직업 세트
      var cls = setId.slice(4);
      if (cls !== ch.cls) continue;
      Gear.setEffects(cls, count).forEach(function(e) { add(e.id, e.v); });
      if (count >= 3) bonus.fullSet = cls;
      continue;
    }
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
  // 퍼센트 능력치는 (캐릭터 기본 + 장비) 기준으로 계산해 더함
  ['hp', 'atk', 'def'].forEach(function(k) {
    if (pct[k]) bonus[k] += Math.round(((ch[k] || 0) + bonus[k]) * pct[k] / 100);
  });
  return bonus;
}

function ensureEquipSlots(ch) {
  if (!ch.equip) {
    ch.equip = { weapon: null, offhand: null, helmet: null, armor: null, boots: null, necklace: null, earring: null, ring: null };
  }
  return ch;
}

function calcEnhanceCost(item) {
  return (ENHANCE_GOLD[item.rarity] || 40) * ((item.enhanceLv || 0) + 1);
}
function calcEnhanceStones(item) {
  return ENHANCE_STONES[item.enhanceLv || 0] || 4;
}

// 강화 레벨별 스탯 증가율 (0.1 = +10%)
function getEnhanceMultiplier(lvl) {
  return (ENHANCE_STAT_PCT[Math.max(0, Math.min(ENHANCE_MAX_LV, lvl || 0))] || 0) / 100;
}

// 강화된 기본 능력치
function getEnhancedStats(item) {
  if (!item || !item.enhanceLv) return item.stats;
  var mult = 1 + getEnhanceMultiplier(item.enhanceLv);
  var enhanced = {};
  for (var stat in item.stats) {
    enhanced[stat] = Math.round(item.stats[stat] * mult);
  }
  return enhanced;
}

function canEnhance(item) {
  return !item.broken && (item.enhanceLv || 0) < ENHANCE_MAX_LV;
}

// 성공률 (연속 실패 보정 포함)
function calcEnhanceRate(item) {
  var base = ENHANCE_RATES[item.enhanceLv || 0] || 0;
  return Math.min(1, base + (item.enhanceBonus || 0) / 100);
}

// 인벤토리 장비를 모든 캐릭터에게서 장착 해제
function unequipEverywhere(item) {
  if (!item) return;
  try {
    if (typeof getRoster === 'function') {
      var roster = getRoster(), changed = false;
      roster.chars.forEach(function(c) {
        if (!c.equip) return;
        for (var k in c.equip) if (c.equip[k] === item.eid) { c.equip[k] = null; changed = true; }
      });
      if (changed) saveRoster(roster);
    }
  } catch (_) {}
  item.equipped = null;
}

// 강화 시도 → { ok, lv, opt, dropped, broken, err }
function enhanceItem(eid, useProtect) {
  var inv = loadInventory();
  var it = inv.find(function(x) { return x.eid === eid; });
  if (!it || it.type !== 'equip') return { err: 'invalid' };
  if (!canEnhance(it)) return { err: it.broken ? 'broken' : 'max' };
  var gold = loadGold(), cost = calcEnhanceCost(it), stones = calcEnhanceStones(it);
  if (gold < cost) return { err: 'gold' };
  if (Mats.get('stone') < stones) return { err: 'stone' };
  var protect = !!useProtect && Mats.get('protect') > 0;
  saveGold(gold - cost);
  Mats.add('stone', -stones);
  if (protect) Mats.add('protect', -1);
  var res = { from: it.enhanceLv || 0 };
  if (Math.random() < calcEnhanceRate(it)) {
    it.enhanceLv = (it.enhanceLv || 0) + 1;
    it.enhanceBonus = 0;
    var opt = Gear.rollEnhanceOpt(it, it.enhanceLv);
    if (opt) { it.eOpts = it.eOpts || {}; it.eOpts[it.enhanceLv] = opt; }
    res.ok = true; res.opt = opt;
  } else {
    it.enhanceBonus = Math.min(ENHANCE_FAIL_BONUS_MAX, (it.enhanceBonus || 0) + ENHANCE_FAIL_BONUS);
    if (!protect && Math.random() < ENHANCE_BREAK_CHANCE) {
      it.broken = true; res.broken = true;
      unequipEverywhere(it);
    } else if ((it.enhanceLv || 0) >= ENHANCE_SAFE_BELOW) {
      if (it.eOpts) delete it.eOpts[it.enhanceLv];   // 잃은 단계의 강화 옵션도 사라짐
      it.enhanceLv--; res.dropped = true;
    }
    res.protected = protect;
  }
  res.lv = it.enhanceLv;
  saveInventory(inv);
  return res;
}

// 파손 장비 수리: 등급별 골드, 강화는 +0으로 초기화 (강화 옵션 소멸)
function repairCost(item) { return REPAIR_GOLD[item.rarity] || 100; }
function repairItem(eid) {
  var inv = loadInventory();
  var it = inv.find(function(x) { return x.eid === eid; });
  if (!it || !it.broken) return { err: 'invalid' };
  var cost = repairCost(it), gold = loadGold();
  if (gold < cost) return { err: 'gold' };
  saveGold(gold - cost);
  it.broken = false; it.enhanceLv = 0; it.eOpts = {}; it.enhanceBonus = 0;
  saveInventory(inv);
  return { ok: true, cost: cost };
}
function dismantleYield(item) {
  return (DISMANTLE_STONES[item.rarity] || 1) + (item.broken ? 0 : Math.floor((item.enhanceLv || 0) / 2));
}
function dismantleItem(eid) {
  var inv = loadInventory();
  var it = inv.find(function(x) { return x.eid === eid; });
  if (!it || it.type !== 'equip') return { err: 'invalid' };
  if (it.equipped) unequipEverywhere(it);
  var n = dismantleYield(it), shard = it.legend ? 1 : 0;
  Mats.add('stone', n);
  if (shard) Mats.add('shard', shard);
  saveInventory(inv.filter(function(x) { return x.eid !== eid; }));
  return { ok: true, stones: n, shard: shard };
}

// ── 강화 재료 저장소 (강화석·보호 주문서·전설 조각) ──
var MATS_KEY = 'game_mats';
var Mats = {
  _get: function() { try { return JSON.parse(Store.get(MATS_KEY)) || {}; } catch (_) { return {}; } },
  get: function(k) { return this._get()[k] || 0; },
  add: function(k, n) { var m = this._get(); m[k] = Math.max(0, (m[k] || 0) + n); try { Store.set(MATS_KEY, JSON.stringify(m)); } catch (_) {} return m[k]; }
};

function getEquipEmoji(templateId) {
  return EQUIP_EMOJI[templateId] || '📦'; // 기본값: 박스
}
