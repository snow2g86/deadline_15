// ═══════════════════════════════════════════
//  tools/battle-sim/rules-shim.js — 화면 모듈을 끄고, 그 안에 섞여 있던 "규칙"만 똑같이 되살림
//
//  웹판은 Fx.enabled = false 로 규칙만 돌릴 수 있게 되어 있지만, 아래 규칙은 화면 모듈(VFX·Renderer) 안에 있어
//  연출을 끄면 같이 사라진다. 실제 게임(연출 켬)과 같은 결과가 나오도록 여기서 그대로 다시 연결한다.
//  ★ 2b(GDScript 규칙 이식)는 이 목록을 "규칙"으로 구현해야 한다 (README 의 '화면 모듈에 섞인 규칙' 참고).
//
//   1) Fx.moveUnit(u,x,y)  → VFX._mvU: 좌표 이동 + allyPos + 'unit_moved' 알림   (스킬은 G._mvU 로 직접 부름 → 진짜 VFX._mvU 유지)
//   2) Fx.faceDir(id,dx,dy) → VFX.faceDir: 바라보는 방향(_gdx,_gdy) 바꿈 (0,0 이면 그대로)
//   3) Fx.attack(a,t)       → VFX.vfxAtk 첫 줄: 공격자가 대상을 바라봄
//   4) 'unit_attacked' 구독 (VFX._subscribe): 스플래시가 아니면 공격자가 대상을 바라봄, attacker._lastTactic = null
//   5) 'unit_moved' 구독 (VFX._subscribe): 이동 방향을 바라봄 + 클랜원(소환수 제외)이 보물상자 칸에 서면 Chest.open
//   6) Renderer.rUnits: 처음 그려지는 유닛의 초기 방향 (적 (0,1) / 아군 (0,-1)) + 아군 allyPos, 쓰러진 클랜원 allyPos = (99,99)
//      → Fx.redrawUnits / G.rUnits
//   7) Renderer.showRes ('battle_end' 구독): BattleEnd.onBattleEnd(win) — 보상 계산. 이어서 결과 화면이 경험치 줄마다 getChar 를 부르며
//      getRoster 의 보정(첫 클리어 신규 클랜원은 actionRec 없이 생성 → rollActionRec() 난수 1회 + 저장)이 일어남 → 첫 getChar 1회 재현
//   8) Renderer.rUnits → requestAnimationFrame → AI.planIntents() (적 행동 예고 _intent) 는 화면 프레임 타이밍에 묶여 있어
//      실제 게임과 비트까지 맞출 수 없다 → 여기서는 빼고, tools/battle-sim.js 의 '행동 예고 규칙'(시작·selU·웨이브·상자·이동 취소 직후, AI_TURN·BATTLE_END 면 건너뜀)으로 정함
// ═══════════════════════════════════════════
'use strict';

const { PRESENTATION } = require('./env');

// 진짜 함수로 남기는 화면 모듈 함수 (규칙 그 자체)
const KEEP = { VFX: ['_mvU', 'faceDir'] };

function install(env, hooks) {
  const g = env.g, noop = function() {};

  // 화면 모듈: 함수는 전부 빈 함수로 (이름 목록은 그대로 → boot.js G 프록시의 이름 찾기 순서가 웹과 같음)
  for (const name of PRESENTATION) {
    const obj = env.eval('typeof ' + name + " !== 'undefined' ? " + name + ' : null');
    if (!obj) continue;
    const keep = KEEP[name] || [];
    for (const k of Object.keys(obj)) if (typeof obj[k] === 'function' && keep.indexOf(k) < 0) obj[k] = noop;
  }
  const S = g.GameStore, VFX = g.VFX, Renderer = g.Renderer, EventBus = g.EventBus;

  // 6) 초기 방향
  const drawn = new Set();
  Renderer.rUnits = function() {
    S.units.filter(u => u.hp > 0).forEach(u => {
      if (drawn.has(u.id)) return;
      drawn.add(u.id);
      if (u.team === 'ally') S.allyPos[u.id] = { x: u.x, y: u.y };
      if (u._gdx === undefined && u._gdy === undefined) { u._gdx = 0; u._gdy = u.team === 'enemy' ? 1 : -1; }
    });
    S.units.filter(u => u.team === 'ally' && u.hp <= 0).forEach(u => { S.allyPos[u.id] = { x: 99, y: 99 }; });   // render.js 344-346 (이어하기 저장용)
  };
  // 7) 전투 끝 → 보상
  Renderer.showRes = function(win) {
    g.BattleEnd.onBattleEnd(win);
    if (S._expResults && S._expResults.length) g.getChar(S._expResults[0].uid);   // 결과 화면 경험치 목록의 첫 getChar (render.js showRes)
    hooks.onRewards(win);
  };
  Renderer.init = function() { EventBus.on('battle_end', ({ win, message }) => Renderer.showRes(win, message)); };
  // 4)·5) VFX._subscribe 의 규칙 부분
  VFX.init = function() {
    EventBus.on('unit_attacked', ({ attacker, target, isSplash }) => {
      if (!isSplash) VFX.faceDir(attacker.id, target.x - attacker.x, target.y - attacker.y);
      attacker._lastTactic = null;
    });
    EventBus.on('unit_moved', ({ unit, from, to }) => {
      VFX.faceDir(unit.id, to.x - from.x, to.y - from.y);
      const c = unit.team === 'ally' && !unit.isSummon && g.Chest.at(S, to.x, to.y);
      if (c) {
        const r = g.Chest.open(S, c, unit);
        hooks.onChest(unit, c, r);
        S._chestLog = (S._chestLog || []).concat(r.kind);
      }
    });
  };

  // Fx: 연출 끔 (Fx.later 는 즉시 실행) + 1)~3)
  const Fx = g.Fx;
  Fx.enabled = false;
  Fx.moveUnit = (u, x, y) => VFX._mvU(u, x, y);
  Fx.faceDir = (id, dx, dy) => VFX.faceDir(id, dx, dy);
  Fx.attack = (a, t) => VFX.faceDir(a.id, t.x - a.x, t.y - a.y);
  Fx.redrawUnits = () => Renderer.rUnits();
  // 떠오르는 글자: 연출이지만 규칙 결과를 알려 주는 'messages.*' 키는 기록 (막힘·버팀·회피 등)
  Fx.float = (x, y, text, kind) => hooks.onFloat(x, y, text, kind);
}

module.exports = { install };
