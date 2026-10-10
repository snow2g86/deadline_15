// ═══════════════════════════════════════════
//  battle/fx.js — 전투 연출 창구
//  규칙 코드(스킬·행동·AI·턴)는 화면 모듈(Renderer·VFX·Audio)을 직접 부르지 않고 Fx 만 부른다.
//  → 다른 엔진(Godot 등)으로 옮길 때는 규칙은 그대로 두고 Fx 의 연결만 새로 만들면 된다.
//  Fx.enabled = false 면 연출 없이 규칙만 돈다 (기다림도 건너뜀 — 헤드리스 시뮬레이션·이식 시험용).
//  호출 시점에 화면 모듈을 찾으므로 어떤 순서로 불러와도 된다.
// ═══════════════════════════════════════════
const Fx = (function() {
  const on = () => Fx.enabled;
  // 화면 모듈은 전역 const 라 window 속성이 아님 (window.Audio 는 브라우저 기본 Audio) → 이름으로 직접 찾음
  const MODS = {
    Renderer: () => (typeof Renderer !== 'undefined' ? Renderer : null),
    VFX: () => (typeof VFX !== 'undefined' ? VFX : null),
    Audio: () => (typeof Audio !== 'undefined' && Audio.sfxMove ? Audio : null),
  };
  // 화면 모듈의 함수를 그대로 넘겨주는 통로 (연출을 끄면 아무것도 안 함, off 값을 돌려줌)
  const pass = (mod, fn, off) => function() {
    if (!on()) return off;
    const m = MODS[mod]();
    if (!m || typeof m[fn] !== 'function') return off;
    return m[fn].apply(m, arguments);
  };

  return {
    enabled: true,

    // ── 효과 ──
    // 칸 좌표(x, y)의 유닛 가운데에서 입자 효과
    burst(x, y, opts) {
      if (!on() || typeof G === 'undefined') return;
      return G.vfxSpawn(G.uSX(x, y) + UCX, G.uSY(x, y) + UCY, opts);
    },
    // 화면 픽셀 좌표에서 입자 효과
    burstPx(px, py, opts) { if (on() && typeof G !== 'undefined') return G.vfxSpawn(px, py, opts); },
    float: pass('Renderer', 'floatT'),           // 떠오르는 글자 (x, y, 글, 종류)
    shake: pass('VFX', 'shakeU'),                // 유닛 흔들기 (id)
    screenShake: pass('VFX', 'screenShake'),     // 화면 흔들기 (세게?)
    death: pass('VFX', 'vfxDeath'),              // 쓰러짐 효과 (unit)
    flash: pass('VFX', 'vfxFlash'),              // 화면 번쩍 (색)
    attack: pass('VFX', 'vfxAtk'),               // 공격 효과 (공격자, 대상)
    buff: pass('VFX', 'vfxBuff'),
    animU: pass('VFX', 'animU'),
    faceDir: pass('VFX', 'faceDir'),
    applyFace: pass('VFX', '_applyFace'),       // 바라보는 방향 반영 (id)
    moveUnit: pass('VFX', '_mvU'),               // 이동 연출 (unit, x, y)
    atkHitDelay: pass('VFX', 'atkHitDelay', 0),  // 공격 동작이 맞는 순간까지 걸리는 시간(ms)
    playAtkMotion: pass('VFX', 'playAtkMotion', Promise.resolve()),

    // ── 화면 갱신 ──
    redrawUnits: pass('Renderer', 'rUnits'),
    redrawTerrain: pass('Renderer', 'rTer'),
    updateUI: pass('Renderer', 'uUI'),
    showUI: pass('Renderer', 'showUI'),
    turnOrder: pass('Renderer', 'rTurnOrder'),
    scrollToUnit: pass('Renderer', 'scrollToUnit'),
    showActionMenu: pass('Renderer', 'showAM'),
    hideActionMenu: pass('Renderer', 'hideAM'),
    showEnemyPopup: pass('Renderer', 'showEnemyPopup'),
    hideEnemyPopup: pass('Renderer', 'hideEnemyPopup'),
    defIcon: pass('Renderer', 'defI'),

    // ── 소리 ──
    sfx(name) { const a = on() && MODS.Audio(); if (a && typeof a['sfx' + name] === 'function') return a['sfx' + name](); },

    // ── 시간 ──
    // 연출 타이밍에 맞춰 나중에 실행. 안에 규칙(피해 계산 등)이 들어 있을 수 있으므로 연출을 꺼도 반드시 실행한다
    later(fn, ms) {
      if (!on()) { fn(); return 0; }
      return setTimeout(fn, ms);
    },
  };
})();
