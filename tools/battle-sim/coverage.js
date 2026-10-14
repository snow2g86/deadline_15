#!/usr/bin/env node
// ═══════════════════════════════════════════
//  tools/battle-sim/coverage.js — 황금 기록이 실제로 무엇을 건드렸는지 세기 (의도가 아니라 기록에서 셈)
//  사용: node tools/battle-sim/coverage.js   (godot/tests/golden/*.json 을 읽음)
// ═══════════════════════════════════════════
'use strict';
const fs = require('fs');
const path = require('path');
const DIR = path.join(__dirname, '..', '..', 'godot', 'tests', 'golden');

function load(f) { return JSON.parse(fs.readFileSync(path.join(DIR, f), 'utf8')); }
const idx = load('index.json');
const allSkills = new Map();   // skill → [scenario]
const totals = {};
const rows = [];
for (const s of idx.scenarios) {
  const tr = load(s.name + '.json');
  const unit = new Map();
  tr.setup.units.forEach(u => unit.set(u.id, u));
  const m = {}; const inc = (k, n) => { m[k] = (m[k] || 0) + (n === undefined ? 1 : n); };
  const skills = new Set(), classes = new Set();
  tr.setup.units.filter(u => u.team === 'ally').forEach(u => classes.add(u.cls));
  let prev = null; const tenSeen = new Set();
  for (const e of tr.events) {
    if (e.ev === 'spawn') { unit.set(e.unit.id, e.unit); if (e.unit.isSummon) inc('summon:' + e.unit.cls); if (e.unit.isBoss) inc('boss'); }
    const U = id => unit.get(id) || {};
    switch (e.ev) {
      case 'skill_used': if (U(e.unit).team === 'ally') { skills.add(e.skill); } else inc('enemySkill:' + e.skill); break;
      case 'cmd': inc('cmd:' + e.op + (e.ok ? '' : ':fail')); if (e.op === 'potion' && e.ok) inc('potion:' + e.item); if ((e.op === 'wait' || e.op === 'defend' || e.op === 'overwatch') && (e.dx || e.dy)) inc('faceChosen'); break;
      case 'calc':
        e.tags.forEach(t => inc('tag:' + t)); if (e.shallow) inc('shallowHit'); if (e.crit) inc('crit');
        if (e.hill && e.dist > (U(e.a).range || 0)) inc('hillRangeHit');
        break;
      case 'unit_attacked':
        if (e.isSpearwall) inc('spearwall'); if (e.isSupport) inc('supportHit'); if (e.isSplash) inc('splash');
        if (e.counter === false && !(prev && prev.ev === 'calc') && U(e.attacker).cls === 'warrior' && U(e.attacker).team === 'enemy') inc('aiWarriorExecute');
        if ((e.counter || e.isCounter) && !(prev && prev.ev === 'calc' && prev.a === e.attacker)) inc('brawlerCounter');
        else if (e.counter || e.isCounter) inc('counter');
        break;
      case 'evade': inc('evade:' + e.kind); break;
      case 'knock': inc(e.resisted ? 'knockResisted' : 'knockMoved'); break;
      case 'float': if (['intercepted', 'knock_resist', 'shoved', 'shove_crash', 'knight_tenacity', 'trap_detected', 'cc_skip', 'curse_end', 'overwatch_fire'].includes(e.key)) inc('msg:' + e.key); break;
      case 'overwatch': inc('overwatchFire'); break;
      case 'ench_dmg': if (e.after !== e.before) inc('enchDmgMod'); break;
      case 'ench_hit': if (e.drain > 0) inc('enchDrain'); e.newBuffs.forEach(b => inc('enchBuff:' + b)); break;
      case 'buff_tick_damage': inc('buffTickDmg:' + e.buff.type); break;
      case 'buff_tick_heal': inc('buffTickHeal'); break;
      case 'shield_active': inc('shieldActive'); break;
      case 'gate_destroyed': inc('gateDestroyed'); break;
      case 'wall_climb': inc('wallClimb'); break;
      case 'turn_start': if (e.intent) inc('enemyTurnWithIntent'); break;
      case 'snap':
        e.units.forEach(v => { if (v.st && v.st._tenacityUsed && !tenSeen.has(v.id)) { tenSeen.add(v.id); inc('knightTenacity'); } });
        if (e.why === 'turn_end' && tr.setup.hazard && e.g.safe.length) {
          const prevTurn = [...tr.events.slice(0, tr.events.indexOf(e))].reverse().find(x => x.ev === 'turn_end');
          const u = prevTurn && e.units.find(v => v.id === prevTurn.unit);
          if (u && u.team === 'ally' && e.g.safe.includes(u.x + ',' + u.y)) inc('endTurnInSafeZone');
        }
        break;
      case 'env_dmg': inc(e.lava ? 'lavaBurn' : 'hazardDot'); break;
      case 'safe_zones': inc('safeZonePlace'); break;
      case 'mist_tick': if (e.hits.length) inc('mistHit', e.hits.length); break;
      case 'curse_tick': inc('curseTick'); break;
      case 'chest_open': inc('chest:' + e.kind); break;
      case 'trap_triggered': inc('trapTriggered'); break;
      case 'siege_used': inc('siege:' + (U(e.unit).team || '?') + ':' + e.type); break;
      case 'wave_spawn': inc('wave'); break;
      case 'unit_healed': inc(e.isPotion ? 'potion' : 'heal'); break;
      case 'gate_attacked': inc('gateHit'); break;
      case 'breach': inc('breach'); break;
      case 'soulbond_restore': inc('soulbond'); break;
      case 'fury_triggered': inc('fury'); break;
      case 'buff_applied': inc('buff:' + e.buff.type); break;
      case 'retreat': inc('retreat'); break;
      case 'unit_killed': inc('kill'); break;
    }
    prev = e;
  }
  skills.forEach(k => { if (!allSkills.has(k)) allSkills.set(k, []); allSkills.get(k).push(s.name); });
  for (const k in m) totals[k] = (totals[k] || 0) + m[k];
  rows.push({ name: s.name, result: s.result, rounds: s.rounds, classes: [...classes].sort().join(','), synergies: tr.setup.synergies.map(x => x.id).join(','),
    hazard: tr.setup.hazard || '-', skills: [...skills].sort(), m });
}
if (process.argv.includes('--json')) { console.log(JSON.stringify({ rows, totals, skills: Object.fromEntries(allSkills) }, null, 1)); process.exit(0); }
for (const r of rows) {
  console.log(`\n■ ${r.name}  ${r.result} ${r.rounds}R  [${r.classes}]  조합: ${r.synergies || '-'}  환경: ${r.hazard}`);
  console.log('  스킬: ' + r.skills.join(' '));
  console.log('  ' + Object.keys(r.m).sort().map(k => k + '=' + r.m[k]).join(' '));
}
console.log('\n■ 합계: ' + Object.keys(totals).sort().map(k => k + '=' + totals[k]).join(' '));
// 모든 습득·기본 스킬 중 아군이 한 번도 안 쓴 것
const { LEARN } = (() => { const src = fs.readFileSync(path.join(__dirname, 'scenarios.js'), 'utf8'); const m = src.match(/const LEARN = (\{[\s\S]*?\n\});/); return { LEARN: eval('(' + m[1] + ')') }; })();
const BASE = { warrior: ['warrior_powersmash'], knight: ['knight_switch'], archer: ['archer_dash'], lancer: ['lancer_pierce'], assassin: ['assassin_assassinate'], priest: ['priest_massheal'],
  sapper: ['sapper_trap'], mage: ['mage_fireburst'], novice: ['novice_throw'], brawler: ['brawler_disarm'], shaman: ['shaman_curse', 'shaman_exalt'], summoner: ['summoner_summon_spirit', 'summoner_summon_golem'] };
const PASSIVE = new Set(['warrior_bloodthirst', 'knight_painshare', 'knight_tenacity', 'assassin_trapdetect', 'novice_grit', 'sapper_enhancedtrap', 'mage_manasurge', 'archer_weakspot', 'priest_divinegrace', 'brawler_counter', 'lancer_spearwall', 'summoner_soulbond', 'shaman_medium']);
const missing = [];
for (const cls in BASE) for (const k of BASE[cls].concat(LEARN[cls])) if (!PASSIVE.has(k) && !allSkills.has(k)) missing.push(k);
console.log('\n■ 아군이 한 번도 쓰지 않은 능동 스킬: ' + (missing.join(' ') || '없음'));
