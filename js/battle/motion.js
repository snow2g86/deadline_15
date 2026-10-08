// ═══════════════════════════════════════════
//  battle/motion.js — 직업별 공격 모션 (코드 기반, 이미지 에셋 없음)
//  기존 캐릭터 스프라이트(.u-icon)를 Web Animations API로 움직이고
//  무기 궤적은 vfx-canvas에 그린다.
// ═══════════════════════════════════════════

// 키프레임 필드: o=진행률(0~1), f=공격 방향 전진(px), u=위로 뜸(px),
//   r=전방 기울기(deg, +가 앞으로), sx/sy=스케일, g=발광(0~1), a=투명도
// hit = 타격 프레임(진행률) — 이 시점에 타격 이펙트/데미지 숫자가 뜬다
const ATK_MOTIONS = {
  // rigKeys: 컷아웃 리그(rig.js)가 있는 캐릭터용 몸 전체 이동 — 기울기는 리그 부위가 담당
  warrior: { dur: 560, hit: .5, glow: '#cfe3ff', trail: 'arc', color: '#e5efff', keys: [
    { o: 0 }, { o: .3, f: -5, u: 3, r: -18, sx: .96, sy: 1.06 },
    { o: .5, f: 12, u: -1, r: 22, sx: 1.08, sy: .92 }, { o: .72, f: 9, r: 14, sx: 1.03, sy: .97 }, { o: 1 }],
    rigKeys: [{ o: 0 }, { o: .3, f: -4, u: 1 }, { o: .5, f: 10, sx: 1.03, sy: .97 }, { o: .72, f: 8 }, { o: 1 }] },
  knight: { dur: 400, hit: .45, glow: '#ffd76a', trail: 'bash', color: '#ffcc44', keys: [
    { o: 0 }, { o: .3, f: -4, r: -6, sx: .94, sy: 1.04 },
    { o: .45, f: 10, r: 4, sx: 1.1, sy: .94 }, { o: .65, f: 6, r: 2 }, { o: 1 }] },
  assassin: { dur: 420, hit: .32, glow: '#cc44ff', trail: 'dash', color: '#e879f9', keys: [
    { o: 0 }, { o: .15, f: -3, u: -1, sy: .92 }, { o: .3, f: 18, r: 10, sx: 1.12, sy: .9, a: .55 },
    { o: .48, f: 16, r: -10, a: .85 }, { o: .64, f: 17, r: 12 }, { o: 1 }] },
  brawler: { dur: 420, hit: .12, glow: '#f97316', trail: 'jab', color: '#fbbf24', keys: [
    { o: 0 }, { o: .12, f: 6, r: 6 }, { o: .24, f: 0 }, { o: .38, f: 8, r: 8, sx: 1.06 },
    { o: .5, f: 0 }, { o: .66, f: 11, u: 2, r: -6, sx: 1.1, sy: .94 }, { o: 1 }] },
  lancer: { dur: 440, hit: .5, glow: '#60a5fa', trail: 'thrust', color: '#93c5fd', keys: [
    { o: 0 }, { o: .35, f: -8, sx: .92, sy: 1.04 }, { o: .5, f: 16, sx: 1.14, sy: .92 },
    { o: .7, f: 14, sx: 1.05 }, { o: 1 }] },
  sapper: { dur: 420, hit: .5, glow: '#f97316', trail: 'lob', color: '#ffcc00', keys: [
    { o: 0 }, { o: .3, f: -4, r: -12, sy: .94 }, { o: .45, f: 4, u: 6, r: 12 },
    { o: .6, f: 2, u: 2 }, { o: 1 }] },
  novice: { dur: 360, hit: .5, glow: '#ffffff', trail: 'arc', color: '#d4d4d4', keys: [
    { o: 0 }, { o: .3, f: -3, r: -8 }, { o: .5, f: 7, r: 10, sx: 1.04 }, { o: 1 }] },
  archer: { dur: 440, hit: .55, glow: '#ffdd88', trail: 'muzzle', color: '#ffdd88', keys: [
    { o: 0 }, { o: .4, f: -5, r: -4, sx: 1.06, sy: .97 }, { o: .5, f: -7, r: -6 },
    { o: .58, f: -2, r: 2 }, { o: 1 }] },
  mage: { dur: 460, hit: .55, glow: '#4488ff', trail: 'bolt', color: '#88aaff', keys: [
    { o: 0 }, { o: .4, u: 5, sx: .96, sy: 1.05, g: .7 }, { o: .55, f: 4, u: 3, sx: 1.06, sy: .96, g: 1 }, { o: 1 }] },
  priest: { dur: 440, hit: .55, glow: '#ffe066', trail: 'bolt', color: '#fff7c2', keys: [
    { o: 0 }, { o: .4, u: 4, g: .8 }, { o: .55, f: 2, u: 3, g: 1 }, { o: 1 }] },
  summoner: { dur: 460, hit: .55, glow: '#a855f7', trail: 'bolt', color: '#c084fc', keys: [
    { o: 0 }, { o: .4, u: 6, r: -5, g: .7 }, { o: .55, f: 4, u: 4, r: 5, g: 1 }, { o: 1 }] },
  shaman: { dur: 440, hit: .55, glow: '#22c55e', trail: 'bolt', color: '#4ade80', keys: [
    { o: 0 }, { o: .2, f: -2, r: -8 }, { o: .4, r: 8, g: .7 }, { o: .55, f: 5, r: -4, sx: 1.05, g: 1 }, { o: 1 }] },
};
ATK_MOTIONS._default = ATK_MOTIONS.novice;

const _MS = UI / 36; // 키프레임 px는 36px 아이콘 기준 → 현재 아이콘 크기에 맞춰 확대
const _BASE_SHADOW = 'drop-shadow(0 2px 4px rgba(0,0,0,.8))';
const _reduceMotion = () => window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

Object.assign(VFX, {
  atkMotion(cls) { return ATK_MOTIONS[cls] || ATK_MOTIONS._default; },

  // 타격 프레임까지의 지연(ms) — 모션 없이 이펙트 타이밍만 맞출 때 사용
  // u를 넘기면 그 유닛의 스프라이트 시트 타격 시점을 우선 사용
  atkHitDelay(cls, u) {
    const fl = (typeof PixelFX !== 'undefined' && PixelFX.FLIGHT[cls]) || 0;   // 픽셀 투사체 비행 시간만큼 명중이 늦음
    const sh = u && Rig.sheet(u, 'attack'); if (sh) return Rig.sheetHitMs(sh) + fl;
    const m = this.atkMotion(cls); return Math.round(m.dur * m.hit) + fl;
  },

  // 공격자 화면 좌표 기준 방향 벡터 (정규화)
  _atkDir(attacker, target) {
    const dx = Grid.uSX(target.x, target.y) - Grid.uSX(attacker.x, attacker.y);
    const dy = Grid.uSY(target.x, target.y) - Grid.uSY(attacker.x, attacker.y);
    const len = Math.hypot(dx, dy);
    if (len) return { x: dx / len, y: dy / len };
    const img = document.querySelector('#u-' + attacker.id + ' .u-icon > img, #u-' + attacker.id + ' .u-icon > .rig');
    return { x: img && img.style.transform.includes('-1') ? -1 : 1, y: 0 };
  },

  // 공격 모션 재생 → 타격 지연(ms) 반환
  playAtkMotion(attacker, target) {
    const m = this.atkMotion(attacker.cls);
    const icon = document.querySelector('#u-' + attacker.id + ' .u-icon');
    // 스프라이트 시트가 있으면 시트 재생 (자체 타격 섬광이 있어 무기 궤적 생략)
    const sh = icon && !_reduceMotion() && Rig.sheet(attacker, 'attack');
    if (sh) return Rig.playOnce(icon, attacker, 'attack');
    const hitMs = Math.round(m.dur * m.hit);
    const dir = this._atkDir(attacker, target);
    const face = dir.x < 0 ? -1 : 1;
    if (icon && icon.animate && !_reduceMotion()) {
      if (icon._atkAnim) icon._atkAnim.cancel();
      // 컷아웃 리그: 부위는 Rig.play가 움직이고, 몸 전체는 rigKeys(없으면 기울기를 줄인 기본 키)로 이동
      const rigged = !!icon._rig;
      if (rigged) Rig.play(icon, m.dur);
      const keys = !rigged ? m.keys : (m.rigKeys || m.keys.map(k => Object.assign({}, k, { r: (k.r || 0) * .3 })));
      const frames = keys.map(k => {
        const f = (k.f || 0) * _MS, u = (k.u || 0) * _MS, g = k.g || 0;
        return {
          // easing은 구간별 적용 → 타격 프레임(hit)이 실제 시간과 일치
          offset: k.o, easing: 'cubic-bezier(.3,.7,.4,1)',
          transform: `translate(${(dir.x * f).toFixed(1)}px,${(dir.y * f - u).toFixed(1)}px) rotate(${(k.r || 0) * face}deg) scale(${k.sx || 1},${k.sy || 1})`,
          opacity: k.a !== undefined ? k.a : 1,
          filter: g ? `${_BASE_SHADOW} drop-shadow(0 0 ${Math.round(4 + g * 8)}px ${m.glow}) brightness(${(1 + g * .35).toFixed(2)})` : _BASE_SHADOW,
        };
      });
      icon.style.transformOrigin = '50% 100%';
      const anim = icon.animate(frames, { duration: m.dur });
      anim.onfinish = anim.oncancel = () => { if (icon._atkAnim === anim) icon._atkAnim = null; };
      icon._atkAnim = anim;
    }
    // 자체 무기 궤적(smear)이 있는 리그는 canvas 궤적 생략 — 투사체(마법·화살 등)는 그대로
    // 픽셀 투사체 직업(궁수·마법사)은 vfxAtk에서 PixelFX가 쏨
    if (!(icon && icon._rig && icon._rig.def.smear) && !PixelFX.handles(attacker.cls)) this._atkTrail(m, attacker, target, dir, face, hitMs);
    return hitMs;
  },

  // ── 무기 궤적 (canvas) ──
  _atkTrail(m, attacker, target, dir, face, hitMs) {
    const ax = Grid.uSX(attacker.x, attacker.y) + UCX, ay = Grid.uSY(attacker.x, attacker.y) + UCY;
    const tx = Grid.uSX(target.x, target.y) + UCX, ty = Grid.uSY(target.x, target.y) + UCY;
    const ang = Math.atan2(dir.y, dir.x);
    const fx = ax + dir.x * 16, fy = ay + dir.y * 16;
    const at = (ms, fn) => setTimeout(fn, ms);
    const charge = Math.round(m.dur * .4);
    switch (m.trail) {
      case 'arc':
        at(hitMs - 40, () => {
          this._fx(fx, fy, 'arcSlash', m.color, 18, ang - .9 * face, { rotSpd: .16 * face, decay: .09 });
          this._fx(fx, fy, 'arcSlash', '#ffffff', 14, ang - .9 * face, { rotSpd: .16 * face, decay: .12 });
        });
        break;
      case 'bash':
        at(hitMs, () => this._fx(fx, fy, 'ring', m.color, 6, 0, { decay: .07 }));
        break;
      case 'dash':
        at(hitMs - 60, () => this._fx(ax + dir.x * 6, ay + dir.y * 6, 'streak', m.color, 30, ang, { decay: .1 }));
        at(hitMs + 40, () => this._fx(fx, fy, 'arcSlash', m.color, 14, ang + .9 * face, { rotSpd: -.2 * face, decay: .12 }));
        break;
      case 'jab':
        [0, 1, 2].forEach(i => at(Math.round(m.dur * [.12, .38, .66][i]), () =>
          this._fx(fx, fy, 'streak', m.color, 12 + i * 4, ang, { decay: .14 })));
        break;
      case 'thrust':
        at(hitMs - 30, () => {
          this._fx(fx + dir.x * 18, fy + dir.y * 18, 'streak', m.color, 34, ang, { decay: .09 });
          this._fx(fx + dir.x * 18, fy + dir.y * 18, 'streak', '#ffffff', 22, ang, { decay: .13 });
        });
        break;
      case 'lob':
        at(hitMs - 60, () => this._projectile(fx, fy - 6, tx, ty, ['#ffcc00', '#f97316'], 6));
        break;
      case 'muzzle':
        at(Math.round(m.dur * .38), () => this._fx(fx, fy, 'implode', m.color, 10, 0, { decay: .1 }));
        break;
      case 'bolt':
        at(80, () => this._fx(ax, ay - 4, 'implode', m.glow, 16, 0, { decay: .05 }));
        at(charge, () => this._projectile(fx, fy - 4, tx, ty, [m.glow, m.color, '#ffffff'], 4));
        break;
    }
  },

  // 직선 투사체 궤적 (점점이 이어지는 스파크)
  _projectile(ax, ay, tx, ty, colors, steps) {
    for (let i = 0; i <= steps; i++) {
      const k = i / steps;
      setTimeout(() => this.spawn(ax + (tx - ax) * k, ay + (ty - ay) * k,
        { count: 2, colors, shape: 'spark', speed: 1.2, spread: 3, decay: .07, size: 2.4 }), i * 18);
    }
  },

  // 단일 궤적 파티클 (랜덤 퍼짐 없음, MAX_PARTICLES 제외)
  _fx(x, y, shape, color, size, rotation, o = {}) {
    this._parts.push({ x, y, vx: 0, vy: 0, life: 1, decay: o.decay || .08, size, color, shape,
      gravity: 0, rotation, rotSpd: o.rotSpd || 0, active: true });
    if (!this._raf) this._loop();
  },
});
