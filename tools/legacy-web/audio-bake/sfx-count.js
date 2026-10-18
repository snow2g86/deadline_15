#!/usr/bin/env node
// ═══════════════════════════════════════════
//  tools/legacy-web/audio-bake/sfx-count.js — 웹 전투 코드가 내는 효과음 수를 세어 고정 표로 (5단계 소리 시험의 정답)
//
//  황금 기록과 같은 시나리오를 웹 전투 코드로 다시 돌리며(tools/legacy-web/battle-sim.js runScenario — 연출은 끔),
//  웹이 소리를 내는 자리를 **웹 코드 그대로** 살려 횟수만 셈 (소리는 내지 않음):
//   - js/battle/audio.js Audio._subscribe (16-22행: unit_attacked → sfxAtk(attacker.cls), unit_killed → sfxKill,
//     unit_healed → sfxHeal, wave_spawn → sfxWave, battle_end → sfxVictory/sfxDefeat) — 웹처럼 Audio.init() 때 구독
//     (js/battle/boot.js 143행: 첫 웨이브(spawnWave)가 Audio.init 보다 먼저라 첫 배치에는 소리 없음)
//   - js/battle/audio.js sfxAtk(cls) 표 (171-177행) — 원래 함수 그대로
//   - js/battle/vfx.js VFX._subscribe 안의 Audio 호출: 45행 보물상자 → sfxHeal, 60행 gate_attacked → sfxAtk(unit.cls),
//     66행 gate_destroyed → sfxKill, 89행 skill_used(caster 가 있을 때) → sfxAtk(caster.cls)
//   - js/battle/fx.js 65행 Fx.sfx(name) → Audio['sfx' + name] (action.js 23 Select · 207 Wait · 330/556 UIClick · 355 Move)
//     — 연출을 끈 시뮬레이터는 Fx.sfx 가 바로 돌아오므로 세는 함수로 바꿈
//   - js/skills/*.js 의 G.sfxAtk/sfxKill/sfxDeath/sfxHeal/sfxMove/sfxUIClick/sfxExplosion, js/skills/_common.js 87행 ctx.sfxDeath
//     — G 프록시가 Audio 의 함수를 찾으므로 Audio 의 sfx* 를 세는 함수로 바꾸면 그대로 셈
//  결과: godot/tests/pc5_fixtures/sfx_web.json  { "<시나리오>": { "<Godot 효과음 이름>": 횟수 } }
//  사용: node tools/legacy-web/audio-bake/sfx-count.js [--check]   (웹 js/ 가 있어야 함)
// ═══════════════════════════════════════════
'use strict';
const fs = require('fs');
const path = require('path');
const shim = require('../battle-sim/rules-shim');
const SCENARIOS = require('../battle-sim/scenarios');
const { runScenario } = require('../battle-sim');

const ROOT = path.resolve(__dirname, '..', '..', '..');
const OUT = path.join(ROOT, 'godot', 'tests', 'pc5_fixtures', 'sfx_web.json');
const NAMES = ['boss_s10', 'knights_s11', 'mono_archer_s07', 'assassins_s06', 'siege_items_s13', 'loss_s30'];
// 웹 함수 이름 → Godot 효과음 이름 (godot/scripts/core/sound.gd SFX_NAMES)
const toGodot = (fn) => fn.replace(/^sfx/, '').replace(/^Atk/, 'Atk_').replace(/([a-z])([A-Z])/g, '$1_$2').toLowerCase();

let counts = null;
const origInstall = shim.install;
shim.install = function(env, hooks) {
  const Audio = env.eval('Audio'), VFX = env.eval('VFX'), EB = env.g.EventBus;
  const realSfxAtk = Audio.sfxAtk, realSubscribe = Audio._subscribe;
  origInstall(env, hooks);   // 화면 모듈(Audio 포함) 함수를 빈 함수로
  counts = {};
  for (const k of Object.keys(Audio)) {
    if (/^sfx[A-Z]/.test(k) && k !== 'sfxAtk' && k !== 'sfxCtx' && k !== 'sfxDest' && k !== 'sfxGain' && k !== 'sfxOsc' && k !== 'sfxNoise') {
      const n = toGodot(k);
      Audio[k] = function() { counts[n] = (counts[n] || 0) + 1; };
    }
  }
  Audio.sfxAtk = realSfxAtk;            // audio.js 171-177 표 그대로
  Audio.init = function() { realSubscribe.call(Audio); };   // boot.js: Audio.init() 이 구독
  // fx.js 65: Fx.sfx(name)
  env.g.Fx.sfx = function(name) { if (typeof Audio['sfx' + name] === 'function') Audio['sfx' + name](); };
  // vfx.js 45: 보물상자 (shim 의 unit_moved 구독이 Chest.open 을 부름)
  const open = env.g.Chest.open;
  env.g.Chest.open = function() { const r = open.apply(this, arguments); Audio.sfxHeal(); return r; };
  // vfx.js 60·66·89 — VFX.init 때 구독 (shim 이 VFX.init 을 바꿨으므로 감쌈)
  const vInit = VFX.init;
  VFX.init = function() {
    vInit.apply(this, arguments);
    EB.on('gate_attacked', ({ unit }) => { Audio.sfxAtk(unit.cls); });
    EB.on('gate_destroyed', () => { Audio.sfxKill(); });
    EB.on('skill_used', ({ caster }) => { if (caster) Audio.sfxAtk(caster.cls); });
  };
};

(async () => {
  const out = {};
  for (const name of NAMES) {
    const sc = SCENARIOS.find(s => s.name === name);
    await runScenario(sc, {});
    const c = {};
    for (const k of Object.keys(counts).sort()) c[k] = counts[k];
    out[name] = c;
    console.log(name.padEnd(18), JSON.stringify(c));
  }
  const text = '{\n' + NAMES.map(n => JSON.stringify(n) + ': ' + JSON.stringify(out[n])).join(',\n') + '\n}\n';
  if (process.argv.includes('--check')) {
    const old = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : '';
    if (old !== text) { console.log('다름: ' + OUT); process.exit(1); }
    console.log('--check: 같음');
  } else { fs.writeFileSync(OUT, text); console.log('→ ' + path.relative(ROOT, OUT)); }
})().catch(e => { console.error(e && e.stack || e); process.exit(1); });
