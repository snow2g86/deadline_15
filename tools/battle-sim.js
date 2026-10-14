#!/usr/bin/env node
// ═══════════════════════════════════════════
//  tools/battle-sim.js — 웹 전투 규칙을 화면 없이 결정적으로 돌려 "황금 기록(golden trace)"을 만든다
//
//  Godot 이전 2b 단계(전투 규칙 GDScript 이식)가 똑같이 재현해야 하는 기준. 웹 파일은 고치지 않는다.
//   - 웹 전투 스크립트를 battle.html 순서대로 Node vm 에 적재 (tools/battle-sim/env.js)
//   - 화면 모듈은 끄고, 그 안에 섞인 규칙만 되살림 (tools/battle-sim/rules-shim.js)
//   - 무작위는 mulberry32(seed), 시간은 가상 시계 → 같은 시나리오는 항상 같은 결과
//   - 아군은 시험용 정책이 화면 버튼과 같은 입구로 조작하고 명령을 기록 (tools/battle-sim/policy.js)
//   - 적은 진짜 AI (js/battle/ai.js) — 2b 가 재현해야 하는 대상
//
//  사용: node tools/battle-sim.js               모든 시나리오 → godot/tests/golden/*.json + index.json
//        node tools/battle-sim.js --check       쓰지 않고 비교만 (바뀔 파일이 있으면 목록 출력 후 종료 코드 1)
//        node tools/battle-sim.js --only boss_s10 [--print]   한 시나리오만 (--print: 요약을 화면에)
//  npm 의존성 없음. 결과 형식은 godot/tests/golden/README.md
// ═══════════════════════════════════════════
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { Env, ROOT } = require('./battle-sim/env');
const shim = require('./battle-sim/rules-shim');
const { Policy } = require('./battle-sim/policy');
const SCENARIOS = require('./battle-sim/scenarios');

const OUT = path.join(ROOT, 'godot', 'tests', 'golden');
const FORMAT = 'deadline15-battle-trace/1';
const MAX_STEPS = 400000;      // 타이머 실행 횟수 상한 (무한 반복 방지)

// ═══════════ 저장 데이터 (시나리오 → 가짜 세이브) ═══════════
const EMPTY_EQUIP = () => ({ weapon: null, offhand: null, helmet: null, armor: null, boots: null, necklace: null, earring: null, ring: null });

// 클랜원: 잠재력은 성장 범위의 가운데(B 등급), 레벨업은 character.js gainExp 와 같은 방식(레벨마다 반올림 누적)
function makeChar(g, uid, spec) {
  const d = g.JAB[spec.cls], gr = d.growth, mid = k => +((gr[k][0] + gr[k][1]) / 2).toFixed(1);
  const pot = Object.assign({ hp: mid('hp'), atk: mid('atk'), def: mid('def'), actionRec: 0.1 }, spec.pot || {});
  const ch = {
    uid, cls: spec.cls, nameId: uid, lv: 1, exp: 0, dead: false,
    hp: d.base.hp, atk: d.base.atk, def: d.base.def, move: d.base.move, range: d.base.range,
    pot, actionRec: Math.round((d.actionRec + pot.actionRec) * 100) / 100, gender: 'm',
    skillLv: Object.assign({}, spec.skills || {}), equip: EMPTY_EQUIP(),
  };
  for (let l = 1; l < (spec.lv || 1); l++) {
    ch.lv++;
    ch.hp = Math.round(ch.hp + pot.hp); ch.atk = Math.round(ch.atk + pot.atk); ch.def = Math.round(ch.def + pot.def);
  }
  return ch;
}

// 장비: 게임의 생성 함수(Gear.makeLegend·makeSetPiece·generateEquip)를 준비용 난수로 불러 만든다 → 결과는 기록의 save 에 그대로
function makeItem(g, spec) {
  let it;
  if (spec.legend) it = g.Gear.makeLegend(spec.legend);
  else if (spec.set) it = g.Gear.makeSetPiece(spec.set, spec.slot || null, spec.rarity || 'rare');
  else it = g.generateEquip(g.equipTemplate(spec.tpl), spec.rarity || 'rare');
  if (spec.enchant) it.enchant = spec.enchant;
  if (spec.enchantAtk) it.enchantAtk = spec.enchantAtk;
  return it;
}

function buildSave(env, sc) {
  const g = env.g;
  env.useSetupRng((sc.seed ^ 0x5eed5eed) >>> 0);
  const commander = g._newCommander(1);
  const chars = [commander], inv = [], party = [];
  sc.party.forEach((spec, i) => {
    const ch = makeChar(g, 2 + i, spec);
    (spec.gear || []).forEach(gs => {
      const it = makeItem(g, gs);
      it.equipped = ch.uid; ch.equip[it.slot] = it.eid; inv.push(it);
    });
    chars.push(ch); party.push(ch.uid);
  });
  (sc.items || []).forEach(s => {
    if (s.siege) { const d = g.SIEGE_ITEMS.find(x => x.id === s.siege); inv.push({ type: 'siege', siegeId: d.id, icon: d.icon }); }
    else if (s.potion) inv.push({ type: 'battle_potion', potionId: s.potion, icon: g.BATTLE_POTIONS[s.potion].icon, quantity: s.qty || 1 });
  });
  const save = {
    game_save: { gold: sc.gold != null ? sc.gold : 1000, cleared: sc.cleared || [], stars: {} },
    game_roster: { chars, nextId: 2 + sc.party.length },
    game_parties: { parties: [1, 2, 3, 4, 5].map(id => ({ id, slots: id === 1 ? party.concat([null, null, null, null, null]).slice(0, 5) : [null, null, null, null, null] })), activePartyId: 1, nextPartyId: 6 },
    game_inventory: inv,
  };
  for (const k of Object.keys(save)) g.Store.set(k, JSON.stringify(save[k]));
  env.useBattleRng();
  return { save, party };
}

function buildStage(g, sc) {
  let st;
  if (sc.stage.daily) st = g.Daily.buildStage(sc.stage.daily.cls, sc.stage.daily.tier);
  else st = JSON.parse(JSON.stringify(g.STAGES.find(s => s.id === sc.stage.id)));
  Object.assign(st, sc.stage.override || {});
  return st;
}

// ═══════════ 기록 형식 도우미 ═══════════
const isUnit = v => v && typeof v === 'object' && typeof v.id === 'number' && typeof v.team === 'string';
const cleanBuff = b => ({ type: b.type, source: b.source || '', duration: b.duration, value: b.value || 0, stacks: b.stacks || 1, meta: b.meta || {}, ...(b._attackCount !== undefined ? { attackCount: b._attackCount } : {}) });

// 유닛 전체 정보 (등장·시작 때) — 키는 이름순. 표시용 이름(name)·버프 id(무작위 문자열)·공성 아이템 id(무작위 수)는 뺌
const FULL_SKIP = new Set(['name', 'gender']);
function unitFull(u) {
  const o = {};
  for (const k of Object.keys(u).sort()) {
    if (FULL_SKIP.has(k)) continue;
    const v = u[k];
    if (typeof v === 'function' || v === undefined) continue;
    if (k === 'buffs') o.buffs = v.map(cleanBuff);
    else if (k === 'siegeItems') o.siegeItems = v.map(s => ({ type: s.type, cooldown: s.cooldown }));
    else o[k] = JSON.parse(JSON.stringify(v));
  }
  return o;
}

// 상태 스냅샷의 유닛 한 줄 (자주 바뀌는 값 + 0 이 아닌 상태값만)
const ST_KEYS = ['stunned', 'frozen', 'disarmed', 'furyBuff', 'defBuff', '_defend', '_overwatch', '_cursed', '_curseDmgCount', '_rootedTurns',
  '_bleedTurns', '_bleedDmg', '_sanctuaryTurns', '_sanctuaryHeal', '_phalanxTurns', '_phalanxDef', '_empowerTurns', '_empowerMul', 'summonTurns',
  '_tenacityUsed', '_tenacityDef', '_sacrificeKnight', '_sacrificeDmgCount', 'stealthBroken', 'channeling', '_barrier', '_spearwallUsed',
  '_lastStandUsed', '_firstHit', '_focus', '_comboTgt', '_comboN', '_oath', '_movedDist'];
function unitSnap(u) {
  const st = {};
  for (const k of ST_KEYS) { const v = u[k]; if (v !== undefined && v !== null && v !== 0 && v !== false) st[k] = v; }
  const o = { id: u.id, team: u.team, cls: u.cls, x: u.x, y: u.y, hp: u.hp, mhp: u.mhp, atk: u.atk, def: u.def, move: u.move, range: u.range,
    res: u.res, ap: u.actionPow, face: [u._gdx === undefined ? null : u._gdx, u._gdy === undefined ? null : u._gdy] };
  if (Object.keys(st).length) o.st = st;
  if (u.buffs && u.buffs.length) o.buffs = u.buffs.map(b => [b.type, b.source || '', b.duration, b.value || 0]);
  if (u.siegeItems) o.siege = u.siegeItems.map(s => s.type + ':' + s.cooldown);
  return o;
}

// calcDmg 내역 (js/skills/_common.js calcDmg 를 그대로 따라 계산, 난수 부분(치명타)과 GearFX.mod 는 제외 — 디버깅용)
function calcParts(g, S, a, t) {
  let atk = a.atk;
  if (a.cls === 'warrior' && a.skillLv && a.skillLv['warrior_bloodthirst'] >= 1 && a.mhp > 0) atk = Math.round(atk * (1 + 0.5 * (1 - a.hp / a.mhp)));
  if (a.disarmed > 0) atk = Math.round(atk * 0.5);
  if (a.isSummon && a._empowerTurns > 0 && a._empowerMul > 0) atk = Math.round(atk * a._empowerMul);
  (a.buffs || []).forEach(b => { if (b.type === 'atk_up') atk = Math.round(atk * (1 + b.value / 100)); });
  (a.buffs || []).forEach(b => { if (b.type === 'atk_down') atk = Math.round(atk * (1 - b.value / 100)); });
  let def = t.def;
  if (t._tenacityDef) def += 10000;
  if (t.defBuff > 0) def = Math.round(def * 1.5);
  (t.buffs || []).forEach(b => { if (b.type === 'def_up') def = Math.round(def * (1 + b.value / 100)); });
  (t.buffs || []).forEach(b => { if (b.type === 'def_down') def = Math.round(def * (1 - b.value / 100)); });
  if (t._phalanxDef > 0) def += t._phalanxDef;
  if (t.cls === 'novice' && t.skillLv && t.skillLv['novice_grit'] >= 1 && t.mhp > 0 && t.hp <= t.mhp * 0.3) def = Math.round(def * 1.3);
  if (t._defend) def = Math.round(def * g.TACTICS_ACT.defendDef);
  const mods = [];
  if (a.furyBuff > 0) mods.push('fury1.5');
  if (S.units.some(u => u.team === a.team && u.hp > 0 && u.channeling === 'shaman_exalt')) mods.push('exalt1.25');
  if (a.cls === 'mage' && a.skillLv && a.skillLv['mage_manasurge'] >= 1 && a.res >= a.maxRes * 0.8) mods.push('manasurge1.2');
  const tb = g.UnitManager.tacticBonus(a, t);
  if (tb.tags.length) mods.push('tactic' + tb.mul);
  if (S.ter[t.y] && S.ter[t.y][t.x] === 'shallow') mods.push('shallow' + (1 + g.TACTIC.shallowVuln));
  if (a.gear) mods.push('gear');
  return { atk, def, base: Math.max(1, atk - def), mods };
}

// ═══════════ 시나리오 하나 실행 ═══════════
async function runScenario(sc, opts) {
  const env = new Env(sc.seed);
  if (opts && opts.rngLog) env.rngLog = [];
  env.turnEnds = 0; env.ended = false;
  env.loadBattlePage();
  const g = env.g;
  g.Store.useBackend({
    getItem: k => (env.mem.has(k) ? env.mem.get(k) : null), setItem: (k, v) => env.mem.set(k, String(v)),
    removeItem: k => env.mem.delete(k), keys: () => [...env.mem.keys()], clear: () => env.mem.clear(),
  });
  const S = g.GameStore, EB = g.EventBus, UM = g.UnitManager, TM = g.TurnManager, AM = g.ActionManager;

  // ── 행동 예고 규칙 (README '행동 예고 규칙'): 정해진 시점에 AI.planIntents() 를 동기로 1회, 단 AI_TURN·BATTLE_END 면 건너뜀 ──
  //  실제 게임: Renderer.rUnits → 다음 프레임 rIntent. 아래 시점은 그 뒤 첫 프레임까지 상태가 바뀌지 않는(플레이어 입력·연출 대기) 곳
  const planRule = (why) => {
    if (g.FSM.is(g.BattleState.AI_TURN) || g.FSM.is(g.BattleState.BATTLE_END)) return;
    g.AI.planIntents();
  };

  // ── 기록 ──
  const events = [];
  const known = new Map();       // 지금 S.units 에 있는 유닛 id → 유닛
  let initTer = null, end = null, rewards = null;
  const snapG = () => {
    const terDiff = [];
    if (initTer) for (let y = 0; y < g.ROWS; y++) for (let x = 0; x < g.COLS; x++) if (S.ter[y][x] !== initTer[y][x]) terDiff.push([x, y, S.ter[y][x]]);
    return {
      turn: S.turn, act: S.actCount, eSpwn: S.eSpwn, eQ: S.eQ.slice(), breached: S.breached,
      gate: Object.assign({}, S.gateHP), traps: (S.traps || []).map(t => [t.x, t.y, t.team, t.dmg, t.stun]),
      mists: (S.poisonMists || []).map(m => [m.cx, m.cy, m.atk, m.turns, m.team]), chests: (S.chests || []).map(c => [c.x, c.y]),
      safe: S.safeZones ? [...S.safeZones] : [], ter: terDiff, walls: (g.G.magicWalls || []).map(w => [w.x, w.y]),
      wallHP: Object.assign({}, S.wallHP), acted: Object.keys(S._turnActed || {}).map(Number), exp: Object.assign({}, S.battleExp),
      potions: (S._battlePotions || []).map(p => p.potionId), siege: (S._siegeItems || []).map(x => x.siegeId),
    };
  };
  const syncUnits = () => {
    const now = new Map(S.units.map(u => [u.id, u]));
    for (const [id] of known) if (!now.has(id)) { known.delete(id); push('gone', { u: id }); }
    for (const [id, u] of now) if (!known.has(id)) { known.set(id, u); push('spawn', { unit: unitFull(u) }); }
  };
  const push = (ev, data) => { const e = Object.assign({ ev, rng: env.rngCalls }, data); events.push(e); return e; };
  const rec = (ev, data) => { syncUnits(); return push(ev, data); };
  // 감싼 함수의 결과 사건: rng = 함수 시작 때 호출 수, rngEnd = 끝난 뒤 호출 수
  const recR = (ev, rng0, data) => { syncUnits(); const e = Object.assign({ ev, rng: rng0, rngEnd: env.rngCalls }, data); events.push(e); return e; };
  const snapshot = (why) => { syncUnits(); push('snap', { why, g: snapG(), units: S.units.map(unitSnap) }); };

  // EventBus 알림 → 기록 (유닛은 id 로)
  const SKIP_EV = new Set(['state_changed', 'camera_focus', 'wave_announce_end']);
  const serVal = (k, v) => {
    if (isUnit(v)) return v.id;
    if (k === 'buff' && v && typeof v === 'object') return cleanBuff(v);
    if (k === 'skill') return typeof v === 'object' && v ? v.id : v;
    if (k === 'trap' && v) return [v.x, v.y, v.team, v.dmg, v.stun];
    if (k === 'message') return undefined;
    if (v && typeof v === 'object') return JSON.parse(JSON.stringify(v));
    return v;
  };
  const origEmit = EB.emit.bind(EB);
  EB.emit = function(name, data) {
    if (!SKIP_EV.has(name)) {
      const o = {};
      if (data) for (const k of Object.keys(data)) { const v = serVal(k, data[k]); if (v !== undefined) o[k] = v; }
      if (name === 'turn_start') {
        o.r = S.turn; o.ap = data.unit.actionPow;
        if (data.unit.team === 'enemy') o.intent = data.unit._intent || null;   // 이 적이 이번 차례에 쓰는 예고 대상 (적 차례 시작 때는 다시 계산하지 않음)
      }
      rec(name, o);
    }
    const r = origEmit(name, data);
    if (name === 'turn_end') snapshot('turn_end');
    if (name === 'wave_spawn') planRule('wave');
    if (name === 'round_end') snapshot('round_end');
    if (name === 'battle_end') { end = { result: data.win ? 'win' : 'lose', reason: String(data.message || '').replace(/^messages\./, '') }; env.ended = true; }
    return r;
  };

  // 화면 모듈 끄기 + 섞인 규칙 되살리기
  shim.install(env, {
    onChest: (u, c, r) => { rec('chest_open', { u: u.id, x: c.x, y: c.y, kind: r.kind }); planRule('chest'); },
    onFloat: (x, y, text) => { if (typeof text === 'string' && text.indexOf('messages.') === 0 && text.indexOf('messages.select_') !== 0) rec('float', { x, y, key: text.slice(9) }); },
    onRewards: (win) => {
      rewards = {
        win, exp: (S._expResults || []).map(e => ({ uid: e.uid, exp: e.exp, actExp: e.actExp, killExp: e.killExp, leveled: e.leveled })),
        killPool: S._totalExp, kills: S._deadEnemyCount, gold: S.gold, baseReward: S._baseReward || 0, bonusReward: S._bonusReward || 0,
        stars: S._starResult || null, soul: S._soulReward || null, rune: S._runeDrop || null, book: S._droppedBook || null,
        newUnit: S._firstClearUnit ? S._firstClearUnit.cls : null, gearDrops: (S._gearDrops || []).length,
        deadAllies: S._deadAllyUids.slice(), autoRevived: S._autoRevivedCount || 0,
      };
    },
  });

  // ── 규칙 함수 감싸기 (결과 기록, 동작은 그대로) ──
  const wrap = (obj, name, after) => { const f = obj[name]; obj[name] = function(...a) { const r = f.apply(this, a); after(r, a, this); return r; }; };
  const origCalc = g.calcDmg;
  g.calcDmg = function(a, t) {
    const parts = calcParts(g, S, a, t), r0 = env.rngCalls;   // 내역은 난수·부작용 없이 미리 계산 (디버깅용)
    const dmg = origCalc(a, t);
    const tile = S.ter[t.y] && S.ter[t.y][t.x];
    const at = S.ter[a.y] && S.ter[a.y][a.x];
    recR('calc', r0, { a: a.id, t: t.id, dmg, tags: a._lastTactic ? a._lastTactic.tags.slice() : [], crit: !!a._lastCrit, shallow: tile === 'shallow',
      dist: Math.abs(a.x - t.x) + Math.abs(a.y - t.y), hill: at === 'hill' && a.range > 1, parts });
    return dmg;
  };
  // 감싸기 (시작 때 난수 수를 기억해 rng/rngEnd 로 기록)
  const wrapR = (obj, name, after) => { const f = obj[name]; obj[name] = function(...a) { const r0 = env.rngCalls; const r = f.apply(this, a); after(r, a, r0); return r; }; };
  wrapR(UM, 'rollEvade', (r, [t], r0) => { if (r) recR('evade', r0, { u: t.id, kind: r }); });
  wrapR(UM, 'resistKnock', (r, [t], r0) => recR('knock', r0, { u: t.id, resisted: r }));
  wrapR(UM, 'rollSupport', (r, [a, t], r0) => { if (r) recR('support', r0, { sp: r.sp.id, a: a.id, t: t.id, dmg: r.dmg, hit: r.actual.id }); });
  // 공격용 마법부여: 피해 보정(번개·파쇄)과 명중 뒤 효과(화상·독·서리·흡혈) — 마법부여가 있는 공격자만 기록
  const hasAtkEnch = a => (a && a.enchants || []).some(k => g.ENCHANTS[k] && g.ENCHANTS[k].cat === 'atk');
  wrapR(g.EnchantFX, 'modDamage', (r, [a, t, d], r0) => { if (hasAtkEnch(a)) recR('ench_dmg', r0, { a: a.id, t: t.id, before: d, after: r }); });
  const origAfter = g.EnchantFX.afterHit;
  g.EnchantFX.afterHit = function(a, t, dmg) {
    const r0 = env.rngCalls, ah = a ? a.hp : 0, nb = t && t.buffs ? t.buffs.length : 0;
    const r = origAfter.apply(this, arguments);
    if (hasAtkEnch(a)) recR('ench_hit', r0, { a: a.id, t: t.id, dmg, drain: a.hp - ah, newBuffs: (t.buffs || []).slice(nb).map(b => b.type) });
    return r;
  };
  const origTick = g.BuffSystem.tick, origEnd = TM.endUnitTurn;
  let endHp = null;
  TM.endUnitTurn = function(u) { env.turnEnds++; endHp = { id: u.id, hp: u.hp, rng: env.rngCalls }; return origEnd.call(this, u); };
  g.BuffSystem.tick = function(u) {
    if (endHp && endHp.id === u.id && u.hp < endHp.hp) recR('env_dmg', endHp.rng, { u: u.id, dmg: endHp.hp - u.hp, lava: UM.nearLava(u.x, u.y), safe: g.Hazard.inSafe(S, u) });
    endHp = null;
    return origTick.call(this, u);
  };
  // 스킬 효과: exec 시작 때 유닛 상태를 기억했다가 _skillDone(스킬 성공 처리) 때 바뀐 HP·위치를 기록 (환불되면 _skillDone 이 없음)
  let skillBefore = null;
  for (const id of Object.keys(g.SKILL_HANDLERS)) {
    const h = g.SKILL_HANDLERS[id], ex = h.exec;
    h.exec = function(u, tx, ty, sk) {
      skillBefore = { skill: sk.id, u: u.id, rng: env.rngCalls, units: S.units.map(v => [v, v.hp, v.x, v.y]) };
      return ex.apply(this, arguments);
    };
  }
  const origDone = g._skillDone;
  g._skillDone = function(u) {
    if (skillBefore) {
      const b = skillBefore; skillBefore = null;
      const hits = b.units.filter(([v, hp]) => v.hp !== hp).map(([v, hp]) => [v.id, hp, v.hp]);
      const moved = b.units.filter(([v, , x, y]) => v.x !== x || v.y !== y).map(([v]) => [v.id, v.x, v.y]);
      recR('skill_fx', b.rng, { skill: b.skill, u: b.u, hits, moved });
    }
    return origDone.apply(this, arguments);
  };
  const origMist = g.tickPoisonMists;
  g.tickPoisonMists = function() {
    const hp = new Map(S.units.map(u => [u.id, u.hp])), r0 = env.rngCalls;
    const n = (S.poisonMists || []).length;
    origMist();
    const hits = S.units.filter(u => hp.has(u.id) && u.hp < hp.get(u.id)).map(u => [u.id, hp.get(u.id) - u.hp]);
    if (n) recR('mist_tick', r0, { mists: n, hits });
  };
  const origCurse = g.curseMoveTick;
  g.curseMoveTick = function(u) { const h = u.hp, r0 = env.rngCalls; origCurse(u); if (u.hp !== h) recR('curse_tick', r0, { u: u.id, dmg: h - u.hp, n: u._curseDmgCount }); };
  wrapR(g.Hazard, 'placeSafe', (r, a, r0) => { if (S.safeZones && S.safeZones.size) recR('safe_zones', r0, { cells: [...S.safeZones] }); });
  const origClimb = g.AI.tryWallClimb;
  g.AI.tryWallClimb = async function(u) {
    const r0 = env.rngCalls, r = await origClimb.call(this, u);
    if (r) recR('wall_climb', r0, { u: u.id, x: u.x, y: u.y });
    return r;
  };
  const origOw = g.AI._overwatch;
  g.AI._overwatch = async function(e) {
    const before = S.units.filter(a => a._overwatch).map(a => a.id), r0 = env.rngCalls;
    const r = await origOw.call(this, e);
    const shooter = before.find(id => { const a = S.units.find(v => v.id === id); return !a || !a._overwatch; });
    if (shooter !== undefined) recR('overwatch', r0, { w: shooter, e: e.id });   // rngEnd 는 발동 뒤 대기(sl) 끝 시점
    return r;
  };

  // ── 아군 조작: 플레이어가 조작할 수 있게 되는 순간(selU) 정책 실행 ──
  const policy = new Policy(env, sc.policy, (cmd) => rec('cmd', cmd));
  let lastAct = -1;
  const origSelU = AM.selU;
  AM.selU = function(u) {
    origSelU.call(this, u);
    if (S.sel === u) planRule('selU');   // 클랜원 차례 시작·다시 선택 → Fx.redrawUnits → 다음 프레임에 예고 계산 (selU 가 막히면 다시 그리지 않음)
    if (u.team === 'ally' && S.curUnit === u && g.FSM.is(g.BattleState.UNIT_SELECTED) && !policy.busy && !env.ended && lastAct !== S.actCount) {
      lastAct = S.actCount;
      // 첫 명령은 100ms 뒤 (값은 임의 — 규칙 결과에 영향 없음. 행동 예고는 위 규칙으로만 계산됨)
      env._add(() => { policy.turn(u).catch(e => env.errors.push('policy: ' + (e && e.stack || e))); }, 100, []);
    }
  };
  const origCancel = AM.actCancel;
  AM.actCancel = function() { const had = !!S.preMv && !S._facePick && !S._shove && !S._skillMenuOpen && !S._itemMenuOpen && !S._curPotion && !S._curSiege; const r = origCancel.apply(this, arguments); if (had) planRule('undo'); return r; };
  const onRej = (e) => env.errors.push('unhandled: ' + (e && e.stack || e));
  process.on('unhandledRejection', onRej);

  // ── 전투 준비 (boot.js 의 DOMContentLoaded → _initBattlePage 와 같은 순서) ──
  const { save, party } = buildSave(env, sc);
  const gd = g.loadGoldData(); S.gold = gd.gold; S.cleared = gd.cleared;
  S.cStage = buildStage(g, sc); S.practiceMode = !!sc.practice; S.party = party.slice();
  const stageRec = JSON.parse(JSON.stringify(S.cStage));
  ['difficulty', 'recommendedLevel', 'enemyComposition', 'recommendedClasses', 'strategyTips', 'story', 'name'].forEach(k => delete stageRec[k]);
  g.BattleInit.initBattle();
  initTer = S.ter.map(r => r.slice());
  // 시험용 상태 주입 (일반 플레이로는 만들 수 없는 상태 — 예: 사제 '정화' 대상). 클랜원 순서(party 의 몇 번째) 기준
  //  { ally: 파티 순서 } · { enemy: 시작 적 순서 } · { enemyCls: 직업 (시작 적 전부) } · { store: { GameStore 키: 값 } }
  const inject = [];
  for (const j of sc.inject || []) {
    if (j.store) { for (const k of Object.keys(j.store)) S[k] = JSON.parse(JSON.stringify(j.store[k])); inject.push({ store: j.store }); continue; }
    const foes = S.units.filter(v => v.team === 'enemy');
    const us = j.ally !== undefined ? [S.units.find(v => v.team === 'ally' && v.uid === party[j.ally])]
      : j.enemy !== undefined ? [foes[j.enemy]] : foes.filter(v => v.cls === j.enemyCls);
    for (const u of us) { Object.assign(u, JSON.parse(JSON.stringify(j.set))); inject.push({ unit: u.id, set: j.set }); }
  }
  // initBattle 중의 알림(유닛 등장·첫 웨이브)은 setup 으로 옮기고 events 는 전투 시작부터
  const initEvents = events.splice(0);
  const setup = {
    stage: stageRec, practice: !!sc.practice, inject,
    ter: S.ter.map(r => r.slice()), gateHP: Object.assign({}, S.gateHP), wallHP: Object.assign({}, S.wallHP),
    eQ: S.eQ.slice(), safe: S.safeZones ? [...S.safeZones] : [], chests: (S.chests || []).map(c => [c.x, c.y]),
    synergies: (S._synergies || []).map(s => ({ id: s.id, eff: s.eff, to: s.to || null, resonance: !!s.resonance })),
    hazard: S._hazard ? S._hazard.id : null,
    potions: S._battlePotions.map(p => p.potionId), siege: S._siegeItems.map(s => s.siegeId),
    rngAfterInit: env.rngCalls,
    initEvents,
    units: S.units.map(unitFull),
  };

  // ── 실행 ──
  const maxRounds = sc.maxRounds || 120;
  planRule('start');   // 전투 시작 (실제 게임: 로딩 중 initBattle 의 rUnits → 프레임)
  g.TurnManager.nextAction();
  let status = await env.run(() => env.ended || S.turn > maxRounds, MAX_STEPS);
  process.removeListener('unhandledRejection', onRej);
  if (status === 'error') throw new Error(`[${sc.name}] 실행 오류:\n` + env.errors.join('\n'));
  if (!end) {
    if (S.turn > maxRounds) end = { result: 'stalled' };
    else end = { result: status === 'max_steps' ? 'max_steps' : 'stuck' };
  }
  snapshot('end');
  Object.assign(end, {
    rounds: S.turn, actCount: S.actCount, rngCalls: env.rngCalls, virtualMs: env.now,
    allies: S.units.filter(u => u.team === 'ally' && !u.isSummon).map(u => u.id),
    enemies: S.units.filter(u => u.team === 'enemy').map(u => u.id),
    kills: S._killCount, breached: S.breached, chestLog: S._chestLog || [],
    rewards,
    // 전투 뒤 저장소 전체 (보상·사망·결과 화면의 로스터 보정까지 반영). 키 이름순
    saveAfter: Object.fromEntries([...env.mem.keys()].sort().map(k => { const v = env.mem.get(k); try { return [k, JSON.parse(v)]; } catch (_) { return [k, v]; } })),
  });
  return { sc, save, setup, events, end, rngLog: env.rngLog || null };
}

// ═══════════ 출력 (키 순서 고정, 한 줄에 하나씩) ═══════════
function render(t) {
  const J = v => JSON.stringify(v);
  const lines = [];
  lines.push('{');
  lines.push('"format": ' + J(FORMAT) + ',');
  lines.push('"scenario": ' + J({ name: t.sc.name, seed: t.sc.seed, desc: t.sc.desc, stage: t.sc.stage, practice: !!t.sc.practice, maxRounds: t.sc.maxRounds || 120, policy: t.sc.policy || {} }) + ',');
  lines.push('"save": {');
  const sk = Object.keys(t.save);
  sk.forEach((k, i) => lines.push(J(k) + ': ' + J(t.save[k]) + (i < sk.length - 1 ? ',' : '')));
  lines.push('},');
  lines.push('"setup": {');
  const keys = Object.keys(t.setup);
  keys.forEach((k, i) => {
    const comma = i < keys.length - 1 ? ',' : '';
    if (k === 'ter' || k === 'units' || k === 'initEvents') {
      lines.push(J(k) + ': [');
      t.setup[k].forEach((r, j) => lines.push(J(r) + (j < t.setup[k].length - 1 ? ',' : '')));
      lines.push(']' + comma);
    } else lines.push(J(k) + ': ' + J(t.setup[k]) + comma);
  });
  lines.push('},');
  lines.push('"events": [');
  t.events.forEach((e, i) => lines.push(J(e) + (i < t.events.length - 1 ? ',' : '')));
  lines.push('],');
  lines.push('"end": ' + J(t.end));
  lines.push('}');
  return lines.join('\n') + '\n';
}

function sha1(s) { return crypto.createHash('sha1').update(s).digest('hex'); }

// ═══════════ CLI ═══════════
async function main() {
  const args = process.argv.slice(2);
  const CHECK = args.includes('--check'), PRINT = args.includes('--print');
  const oi = args.indexOf('--only'), only = oi >= 0 ? args[oi + 1].split(',') : null;
  // --rng-log [폴더]: 난수 호출마다 '번호<TAB>호출 위치(웹 파일 함수@파일:줄, 안쪽부터 3개)' 를 <폴더>/<시나리오>.txt 로 (기본 tools/_work/rng-log, git 제외)
  const li = args.indexOf('--rng-log');
  const rngDir = li < 0 ? null : (args[li + 1] && !args[li + 1].startsWith('--') ? path.resolve(args[li + 1]) : path.join(ROOT, 'tools', '_work', 'rng-log'));
  const list = SCENARIOS.filter(s => !only || only.includes(s.name));
  if (!list.length) { console.error('시나리오 없음'); process.exit(2); }
  const names = new Set(); SCENARIOS.forEach(s => { if (names.has(s.name)) throw new Error('중복 이름 ' + s.name); names.add(s.name); });

  const outputs = {}, index = [];
  for (const sc of list) {
    const t0 = Date.now();
    const tr = await runScenario(sc, { rngLog: !!rngDir });
    if (rngDir) { fs.mkdirSync(rngDir, { recursive: true }); fs.writeFileSync(path.join(rngDir, sc.name + '.txt'), tr.rngLog.join('\n') + '\n'); }
    const text = render(tr);
    outputs[sc.name + '.json'] = text;
    const rec = { name: sc.name, seed: sc.seed, stage: sc.stage.daily ? 'daily:' + sc.stage.daily.cls + ':' + sc.stage.daily.tier : sc.stage.id,
      result: tr.end.result, rounds: tr.end.rounds, actions: tr.end.actCount, events: tr.events.length, rngCalls: tr.end.rngCalls, sha1: sha1(text) };
    index.push(rec);
    console.log(`${sc.name.padEnd(22)} ${String(rec.result).padEnd(8)} 라운드 ${String(rec.rounds).padStart(3)}  행동 ${String(rec.actions).padStart(4)}  사건 ${String(rec.events).padStart(5)}  난수 ${String(rec.rngCalls).padStart(5)}  ${Date.now() - t0}ms`);
    if (PRINT) printSummary(tr);
  }
  // index.json: --only 일 때는 돌린 시나리오 줄만 바꾸고 나머지는 기존 값 (시나리오 표 순서)
  let oldIndex = [];
  try { oldIndex = JSON.parse(fs.readFileSync(path.join(OUT, 'index.json'), 'utf8')).scenarios || []; } catch (_) {}
  const rows = SCENARIOS.map(s => index.find(r => r.name === s.name) || (only ? oldIndex.find(r => r.name === s.name) : null)).filter(Boolean);
  outputs['index.json'] = '{\n"format": ' + JSON.stringify(FORMAT) + ',\n"generator": "tools/battle-sim.js",\n"scenarios": [\n' +
    rows.map(r => JSON.stringify(r)).join(',\n') + '\n]\n}\n';

  const changed = [];
  for (const [f, text] of Object.entries(outputs)) {
    const p = path.join(OUT, f);
    const old = fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : null;
    if (old !== text) changed.push(f);
    if (!CHECK && old !== text) { fs.mkdirSync(OUT, { recursive: true }); fs.writeFileSync(p, text); }
  }
  if (!only) {   // 시나리오 표에서 빠진 옛 기록 파일
    const want = new Set(Object.keys(outputs));
    if (fs.existsSync(OUT)) for (const f of fs.readdirSync(OUT)) if (f.endsWith('.json') && !want.has(f)) { changed.push(f + ' (삭제)'); if (!CHECK) fs.unlinkSync(path.join(OUT, f)); }
  }
  if (CHECK) {
    if (changed.length) { console.log('\n바뀔 파일 ' + changed.length + '개:\n  ' + changed.join('\n  ')); process.exit(1); }
    console.log('\n--check: 변경 없음 (' + Object.keys(outputs).length + '개)');
  } else console.log('\n기록 ' + changed.length + '개, 변경 없음 ' + (Object.keys(outputs).length - changed.length) + '개 → ' + path.relative(ROOT, OUT));
}

function printSummary(tr) {
  const c = {};
  tr.events.forEach(e => { c[e.ev] = (c[e.ev] || 0) + 1; });
  console.log('  사건 종류:', JSON.stringify(c));
  console.log('  끝:', JSON.stringify(tr.end));
}

if (require.main === module) main().catch(e => { console.error(e && e.stack || e); process.exit(1); });
module.exports = { runScenario, render };
