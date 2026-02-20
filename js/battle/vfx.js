// ═══════════════════════════════════════════
//  battle/vfx.js — Particles, animations, screen effects
// ═══════════════════════════════════════════
const MAX_PARTICLES = 80;
const VFX = {
  _parts: [], _raf: null,

  init() {
    const cv = document.getElementById('vfx-canvas');
    const w = document.getElementById('iso-world');
    cv.width = parseInt(w.style.width) || 2000; cv.height = parseInt(w.style.height) || 2000;
    this._subscribe();
  },

  _subscribe() {
    EventBus.on('unit_attacked', ({ attacker, target, damage, counter }) => {
      this.vfxAtk(attacker, target);
      this.shakeU(target.id);
      Renderer.floatT(target.x, target.y, `-${damage}`, 'damage');
      if (counter) Renderer.floatT(attacker.x, attacker.y, t('messages.brawler_counter'), 'heal');
    });
    EventBus.on('unit_killed', ({ killer, target }) => {
      this.screenShake(); this.vfxDeath(target); this.deathA(target.id);
    });
    EventBus.on('unit_healed', ({ healer, target, amount }) => {
      this.vfxHeal(target);
      Renderer.floatT(target.x, target.y, `+${amount}`, 'heal');
    });
    EventBus.on('unit_moved', ({ unit, from, to }) => {
      this.faceDir(unit.id, to.x - from.x, to.y - from.y);
      this.animU(unit.id, to.x, to.y);
    });
    EventBus.on('buff_applied', ({ unit }) => { this.vfxBuff(unit); });
    EventBus.on('buff_tick_damage', ({ unit, damage }) => { Renderer.floatT(unit.x, unit.y, `-${damage}`, 'damage'); });
    EventBus.on('buff_tick_heal', ({ unit, heal }) => { Renderer.floatT(unit.x, unit.y, `+${heal}`, 'heal'); });
    EventBus.on('siege_used', ({ unit, type, target }) => {
      if (type === 'bomb' && target) { this.vfxSiege('siege_bomb', target.x, target.y); this.screenShake(); }
      Renderer.floatT(unit.x, unit.y, type === 'bomb' ? '💣' : type === 'shield' ? '🛡️' : '⚡', 'heal');
    });
    EventBus.on('gate_attacked', ({ unit, x, y }) => {
      Renderer.floatT(x, y, t('messages.gate_hit'), 'damage');
      Audio.sfxAtk(unit.cls);
      this.spawn(Grid.uSX(x, y) + UCX, Grid.uSY(x, y) + UCY,
        { count: 12, colors: ['#aa8844', '#ffcc66', '#fff'], shape: 'spark', speed: 2, spread: 12, decay: 0.025, size: 3 });
    });
    EventBus.on('gate_destroyed', ({ x, y }) => {
      Renderer.floatT(x, y, t('messages.gate_destroyed'), 'damage');
      this.screenShake(); Audio.sfxKill();
    });
    EventBus.on('breach', ({ unit, count, limit }) => { Renderer.floatT(unit.x, unit.y, `${t('messages.breach')} ${count}/${limit}`, 'damage'); });
    EventBus.on('evasion', ({ unit }) => { Renderer.floatT(unit.x, unit.y, t('messages.evasion'), 'heal'); });
    EventBus.on('fury_triggered', ({ unit }) => { Renderer.floatT(unit.x, unit.y, t('messages.fury_buff'), 'heal'); });
    EventBus.on('retreat', ({ unit }) => { Renderer.floatT(unit.x, unit.y, t('messages.retreat'), 'damage'); });
    EventBus.on('root_blocked', ({ unit }) => { Renderer.floatT(unit.x, unit.y, t('messages.rooted'), 'debuff'); });
    EventBus.on('shield_active', ({ unit }) => { Renderer.floatT(unit.x, unit.y, '🛡️', 'heal'); });
    EventBus.on('camera_focus', ({ unit }) => { Renderer.scrollToUnit(unit); });
    EventBus.on('turn_start', ({ phase }) => { this.turnFlash(phase); });
    EventBus.on('wave_announce', ({ remaining }) => { Renderer.showWv(t('messages.wave_info', { count: remaining })); });
    EventBus.on('wave_announce_end', () => { Renderer.hideWv(); });
    EventBus.on('trap_triggered', ({ unit, damage }) => {
      Renderer.floatT(unit.x, unit.y, `-${damage}`, 'damage');
    });
    EventBus.on('soulbond_restore', ({ summoner, amount }) => { Renderer.floatT(summoner.x, summoner.y, `+${amount} MP`, 'heal'); });
    EventBus.on('skill_used', ({ caster, skill, target }) => {
      if (caster) {
        if (skill === 'mage_fireball') Renderer.floatT(caster.x, caster.y, t('messages.mage_fireball'), 'heal');
        else if (skill === 'brawler_disarm' && target) {
          Renderer.floatT(target.x, target.y, t('messages.brawler_disarm'), 'damage');
          Renderer.floatT(caster.x, caster.y, t('messages.brawler_disarm'), 'heal');
        }
        if (Audio && Audio.sfxAtk) Audio.sfxAtk(caster.cls);
      }
    });
  },

  // ── 파티클 시스템 ──
  spawn(x, y, opts) {
    const cnt = opts.count || 8;
    const room = MAX_PARTICLES - this._parts.filter(p => p.active).length;
    const actual = Math.min(cnt, room);
    for (let i = 0; i < actual; i++) {
      this._parts.push({
        x: x + (Math.random() - .5) * (opts.spread || 10),
        y: y + (Math.random() - .5) * (opts.spread || 10),
        vx: (Math.random() - .5) * (opts.speed || 2),
        vy: opts.vy !== undefined ? (opts.vy + (Math.random() - .5)) : (-Math.random() * (opts.speed || 2)),
        life: 1, decay: opts.decay || (0.015 + Math.random() * 0.02),
        size: (opts.size || (2 + Math.random() * 3)) * 1.2,
        color: opts.colors[Math.floor(Math.random() * opts.colors.length)],
        shape: opts.shape || 'circle', gravity: opts.gravity || 0,
        trail: opts.trail || false, rotation: Math.random() * Math.PI * 2,
        rotSpd: (Math.random() - .5) * 0.2, active: true
      });
    }
    if (!this._raf) this._loop();
  },

  _loop() {
    const cv = document.getElementById('vfx-canvas'); if (!cv) return;
    const ctx = cv.getContext('2d'); ctx.clearRect(0, 0, cv.width, cv.height);
    this._parts = this._parts.filter(p => p.active);
    for (let i = this._parts.length - 1; i >= 0; i--) {
      const p = this._parts[i];
      p.x += p.vx; p.y += p.vy; p.vy += p.gravity; p.life -= p.decay; p.rotation += p.rotSpd;
      if (p.life <= 0) { p.active = false; continue; }
      ctx.save(); ctx.globalAlpha = p.life; ctx.fillStyle = p.color;
      ctx.translate(p.x, p.y); ctx.rotate(p.rotation);
      if (p.shape === 'circle') { ctx.beginPath(); ctx.arc(0, 0, p.size * p.life, 0, Math.PI * 2); ctx.fill(); }
      else if (p.shape === 'star') { this._drawStar(ctx, 0, 0, p.size * p.life); }
      else if (p.shape === 'slash') {
        ctx.strokeStyle = p.color; ctx.lineWidth = p.size * p.life * 0.8; ctx.lineCap = 'round';
        ctx.beginPath(); ctx.moveTo(-p.size * 2.5, p.size * 2.5); ctx.lineTo(p.size * 2.5, -p.size * 2.5); ctx.stroke();
      } else if (p.shape === 'spark') {
        ctx.strokeStyle = p.color; ctx.lineWidth = 1.5; ctx.beginPath();
        ctx.moveTo(0, 0); ctx.lineTo(-p.vx * 4, -p.vy * 4); ctx.stroke();
        ctx.beginPath(); ctx.arc(0, 0, p.size * p.life * 0.6, 0, Math.PI * 2); ctx.fill();
      } else if (p.shape === 'ring') {
        ctx.strokeStyle = p.color; ctx.lineWidth = 2 * p.life;
        ctx.beginPath(); ctx.arc(0, 0, p.size * (1 - p.life) * 3.5 + 2, 0, Math.PI * 2); ctx.stroke();
      } else if (p.shape === 'arrow') {
        ctx.strokeStyle = p.color; ctx.lineWidth = 2 * p.life; ctx.lineCap = 'round';
        ctx.beginPath(); ctx.moveTo(0, p.size * 3); ctx.lineTo(0, -p.size * 3);
        ctx.moveTo(-p.size, -p.size); ctx.lineTo(0, -p.size * 3); ctx.lineTo(p.size, -p.size); ctx.stroke();
      } else if (p.shape === 'diamond') {
        ctx.beginPath(); const s = p.size * p.life;
        ctx.moveTo(0, -s); ctx.lineTo(s, 0); ctx.lineTo(0, s); ctx.lineTo(-s, 0); ctx.closePath(); ctx.fill();
      } else if (p.shape === 'cross') {
        ctx.strokeStyle = p.color; ctx.lineWidth = p.size * p.life * 0.5; ctx.lineCap = 'round';
        const s = p.size * 2; ctx.beginPath();
        ctx.moveTo(-s, 0); ctx.lineTo(s, 0); ctx.moveTo(0, -s); ctx.lineTo(0, s); ctx.stroke();
      }
      ctx.restore();
    }
    if (this._parts.some(p => p.active)) this._raf = requestAnimationFrame(() => this._loop());
    else { this._parts.length = 0; this._raf = null; ctx.clearRect(0, 0, cv.width, cv.height); }
  },

  _drawStar(ctx, x, y, r) {
    ctx.beginPath(); for (let i = 0; i < 5; i++) {
      ctx.lineTo(x + r * Math.cos(i * 1.256 - .785), y + r * Math.sin(i * 1.256 - .785));
      ctx.lineTo(x + r * .4 * Math.cos(i * 1.256 + .628 - .785), y + r * .4 * Math.sin(i * 1.256 + .628 - .785));
    } ctx.closePath(); ctx.fill();
  },

  // ── 공격 VFX ──
  vfxAtk(attacker, target) {
    this.faceDir(attacker.id, target.x - attacker.x, target.y - attacker.y);
    this.atkAnimU(attacker.id);
    const u = GameStore.units.find(v => v.id === attacker.id);
    if (u) this.showAttackAnim(u.id, u.gender, u.cls);
    const ax = Grid.uSX(attacker.x, attacker.y) + UCX, ay = Grid.uSY(attacker.x, attacker.y) + UCY;
    const tx = Grid.uSX(target.x, target.y) + UCX, ty = Grid.uSY(target.x, target.y) + UCY;
    const cls = attacker.cls;
    if (cls === 'warrior') {
      this.spawn(tx, ty, { count: 10, colors: ['#fff', '#aaddff', '#88bbff'], shape: 'slash', speed: 3, spread: 10, decay: 0.04, size: 4 });
      this.spawn(tx, ty, { count: 6, colors: ['#ffffff', '#aaddff'], shape: 'spark', speed: 4, spread: 8, decay: 0.03, size: 2.5 });
    } else if (cls === 'knight') {
      this.spawn(tx, ty, { count: 12, colors: ['#ffcc44', '#ff8800', '#ffffff'], shape: 'circle', speed: 2.5, spread: 8, decay: 0.025, size: 4, gravity: 0.08 });
      this.spawn(tx, ty, { count: 4, colors: ['#fff', '#ffcc44'], shape: 'spark', speed: 3, spread: 6, decay: 0.035, size: 2 });
    } else if (cls === 'assassin') {
      for (let i = 0; i < 3; i++) setTimeout(() => {
        this.spawn(tx + (Math.random() - .5) * 10, ty + (Math.random() - .5) * 10, { count: 5, colors: ['#cc44ff', '#ff44cc', '#ffffff'], shape: 'slash', speed: 4, spread: 8, decay: 0.045, size: 3.5 });
      }, i * 50);
      this.spawn(tx, ty, { count: 6, colors: ['#cc44ff66', '#8844ff66'], shape: 'diamond', speed: 2, spread: 12, decay: 0.03, size: 4 });
    } else if (cls === 'mage') {
      this.spawn(tx, ty, { count: 15, colors: ['#4488ff', '#88aaff', '#aaccff', '#ffffff'], shape: 'star', speed: 3, spread: 10, decay: 0.025, size: 3.5 });
      this.spawn(tx, ty, { count: 8, colors: ['#4488ff', '#ffffff'], shape: 'spark', speed: 5, spread: 6, decay: 0.025, size: 2.5 });
    } else if (cls === 'archer') {
      const dx = tx - ax, dy = ty - ay, dist = Math.sqrt(dx * dx + dy * dy);
      const steps = Math.max(4, Math.floor(dist / 14));
      for (let i = 0; i < steps; i++) {
        const tt = i / steps;
        setTimeout(() => this.spawn(ax + dx * tt, ay + dy * tt, { count: 2, colors: ['#ffdd88', '#ffffff'], shape: 'spark', speed: 1.5, spread: 3, decay: 0.06, size: 2 }), i * 20);
      }
      setTimeout(() => this.spawn(tx, ty, { count: 8, colors: ['#ffdd44', '#ff8844', '#ffffff'], shape: 'spark', speed: 3, spread: 6, decay: 0.03, size: 2.5 }), steps * 20);
    } else if (cls === 'priest') {
      this.spawn(tx, ty, { count: 10, colors: ['#ffffff', '#ffffaa', '#ffe066'], shape: 'star', speed: 2, spread: 10, decay: 0.025, size: 3.5 });
    } else if (cls === 'novice') {
      this.spawn(tx, ty, { count: 6, colors: ['#cccccc', '#ffffff', '#aaaaaa'], shape: 'spark', speed: 2.5, spread: 8, decay: 0.04, size: 2.5 });
    } else if (cls === 'brawler') {
      for (let i = 0; i < 3; i++) setTimeout(() => {
        this.spawn(tx + (Math.random() - .5) * 10, ty + (Math.random() - .5) * 10, { count: 5, colors: ['#f97316', '#fbbf24', '#ffffff'], shape: 'slash', speed: 4, spread: 6, decay: 0.045, size: 3.5 });
      }, i * 40);
      this.spawn(tx, ty, { count: 4, colors: ['#f97316', '#ff4400'], shape: 'spark', speed: 4, spread: 6, decay: 0.035, size: 2.5 });
    } else if (cls === 'lancer') {
      const dx = tx - ax, dy = ty - ay, dist = Math.sqrt(dx * dx + dy * dy) || 1;
      const nx = dx / dist, ny = dy / dist;
      for (let i = 0; i < 4; i++) {
        const px = tx - nx * i * 6, py = ty - ny * i * 6;
        setTimeout(() => this.spawn(px, py, { count: 3, colors: ['#60a5fa', '#3b82f6', '#ffffff'], shape: 'spark', speed: 5, spread: 4, decay: 0.045, size: 2.5 }), i * 25);
      }
      this.spawn(tx, ty, { count: 8, colors: ['#60a5fa', '#93c5fd', '#ffffff'], shape: 'spark', speed: 4, spread: 8, decay: 0.03, size: 3 });
    } else if (cls === 'sapper') {
      this.spawn(tx, ty, { count: 10, colors: ['#f97316', '#ff6600', '#ffcc00'], shape: 'spark', speed: 3, spread: 10, decay: 0.035, size: 3 });
      this.spawn(tx, ty, { count: 4, colors: ['#aaaaaa', '#888888'], shape: 'circle', speed: 1.5, spread: 6, decay: 0.025, size: 2.5, gravity: 0.08 });
    } else if (cls === 'summoner') {
      this.spawn(tx, ty, { count: 12, colors: ['#8b5cf6', '#c084fc', '#e9d5ff', '#ffffff'], shape: 'star', speed: 2.5, spread: 10, decay: 0.022, size: 3.5 });
      setTimeout(() => this.spawn(tx, ty, { count: 5, colors: ['#c084fc', '#fff'], shape: 'diamond', speed: 1.5, spread: 8, decay: 0.03, size: 2.5, vy: -1 }), 60);
    } else if (cls === 'shaman') {
      this.spawn(tx, ty, { count: 10, colors: ['#22c55e', '#4ade80', '#9333ea'], shape: 'diamond', speed: 2.5, spread: 10, decay: 0.025, size: 3.5 });
      this.spawn(tx, ty, { count: 6, colors: ['#22c55e', '#9333ea', '#fff'], shape: 'spark', speed: 3, spread: 8, decay: 0.03, size: 2.5 });
    }
  },

  vfxHeal(target) {
    const tx = Grid.uSX(target.x, target.y) + UCX, ty = Grid.uSY(target.x, target.y) + UCY;
    this.spawn(tx, ty, { count: 18, colors: ['#44ff88', '#88ffaa', '#aaffcc', '#ffffff'], shape: 'circle', speed: 1.5, spread: 14, decay: 0.018, size: 3, vy: -1.5, gravity: -0.02 });
    this.spawn(tx, ty, { count: 5, colors: ['#44ff8844'], shape: 'ring', speed: 0, spread: 3, decay: 0.015, size: 14 });
    this.spawn(tx, ty, { count: 8, colors: ['#aaffcc', '#ffffff'], shape: 'star', speed: 1, spread: 10, decay: 0.02, size: 2.5, vy: -2, gravity: -0.01 });
  },

  vfxDeath(unit) {
    const tx = Grid.uSX(unit.x, unit.y) + UCX, ty = Grid.uSY(unit.x, unit.y) + UCY;
    const bc = unit.team === 'ally' ? ['#3b82f6', '#60a5fa', '#93c5fd', '#bfdbfe'] : ['#ef4444', '#f87171', '#fca5a5', '#fecaca'];
    this.spawn(tx, ty, { count: 25, colors: [...bc, '#ffffff88'], shape: 'diamond', speed: 1.5, spread: 16, decay: 0.012, size: 3, gravity: 0.03, vy: -.5 });
    this.spawn(tx, ty, { count: 10, colors: ['#ffffff44'], shape: 'circle', speed: .8, spread: 12, decay: 0.01, size: 2, vy: -1, gravity: -0.01 });
  },

  vfxBuff(unit) {
    const el = document.getElementById('u-' + unit.id);
    if (el) { el.classList.add('buff-glow'); setTimeout(() => el.classList.remove('buff-glow'), 500); }
    const tx = Grid.uSX(unit.x, unit.y) + UCX, ty = Grid.uSY(unit.x, unit.y) + UCY;
    this.spawn(tx, ty, { count: 8, colors: ['#22c55e', '#4ade80', '#ffffff'], shape: 'star', speed: 1.5, spread: 12, decay: 0.025, size: 2.5, vy: -1 });
  },

  vfxSiege(itemId, tx, ty) {
    const sx = Grid.tSX(tx, ty) + TW, sy = Grid.tSY(tx, ty, 0) + TH;
    if (itemId === 'siege_ladder') {
      this.spawn(sx, sy, { count: 10, colors: ['#d4a574', '#b08050', '#fff8'], shape: 'spark', speed: 2, spread: 10, decay: 0.025, size: 2.5, vy: -2 });
    } else if (itemId === 'siege_bomb') {
      this.spawn(sx, sy, { count: 30, colors: ['#f84', '#f60', '#ff4', '#fff'], shape: 'spark', speed: 4, spread: 16, decay: 0.02, size: 3.5 });
      this.spawn(sx, sy, { count: 8, colors: ['#f8440088'], shape: 'ring', speed: 0, spread: 4, decay: 0.012, size: 18 });
      this.spawn(sx, sy, { count: 12, colors: ['#888', '#666', '#aaa'], shape: 'circle', speed: 2, spread: 14, decay: 0.015, size: 3, vy: -1.5, gravity: 0.06 });
    } else if (itemId === 'siege_bridge') {
      this.spawn(sx, sy, { count: 12, colors: ['#8B4513', '#A0522D', '#D2B48C'], shape: 'circle', speed: 1.5, spread: 12, decay: 0.02, size: 2.5, vy: -1 });
    }
  },

  vfxFlash(color) {
    const el = document.getElementById('turn-flash');
    el.style.background = `radial-gradient(ellipse, ${color}, transparent 70%)`;
    el.classList.remove('skill-flash'); void el.offsetWidth;
    el.classList.add('skill-flash');
    setTimeout(() => { el.classList.remove('skill-flash'); el.style.background = ''; }, 400);
  },

  // ── 화면 효과 ──
  screenShake(heavy) {
    const w = document.getElementById('iso-world');
    const cls = heavy ? 'screen-shake-heavy' : 'screen-shake';
    const dur = heavy ? 450 : 300;
    w.classList.remove('screen-shake', 'screen-shake-heavy'); void w.offsetWidth; w.classList.add(cls);
    setTimeout(() => w.classList.remove(cls), dur);
  },

  turnFlash(type) {
    const el = document.getElementById('turn-flash');
    el.classList.remove('player-flash', 'enemy-flash'); void el.offsetWidth;
    el.classList.add(type + '-flash'); setTimeout(() => el.classList.remove(type + '-flash'), 600);
  },

  // ── 유닛 위치 이동 ──
  _mvU(u, tx, ty) {
    const from = { x: u.x, y: u.y };
    u.x = tx; u.y = ty;
    if (u.team === 'ally') GameStore.allyPos[u.id] = { x: tx, y: ty };
    EventBus.emit('unit_moved', { unit: u, from, to: { x: tx, y: ty } });
  },

  // ── 유닛 애니메이션 ──
  _g2sx(gdx, gdy) {
    const d = gdx || 0, r = gdy || 0;
    switch (GameStore.camDir) { case 0: return d - r; case 1: return -r - d; case 2: return r - d; default: return r + d; }
  },

  faceDir(id, gdx, gdy) {
    if (!gdx && !gdy) return;
    const u = GameStore.units.find(v => v.id === id);
    if (u) { u._gdx = gdx; u._gdy = gdy; }
    this._applyFace(id);
  },

  _applyFace(id) {
    const el = document.getElementById('u-' + id); if (!el) return;
    const u = GameStore.units.find(v => v.id === id); if (!u) return;
    const sdx = this._g2sx(u._gdx, u._gdy);
    if (!sdx) return;
    const img = el.querySelector('.u-icon img');
    if (img) img.style.transform = sdx < 0 ? 'scaleX(-1)' : '';
  },

  animU(id, x, y) {
    const el = document.getElementById('u-' + id); if (!el) return;
    el.classList.add('moving'); setTimeout(() => el.classList.remove('moving'), 340);
    const u = GameStore.units.find(v => v.id === id);
    if (u && (u._gdx || u._gdy)) this._applyFace(id);
    el.style.transform = `translate(${Grid.uSX(x, y)}px,${Grid.uSY(x, y)}px)`;
    const v = Grid.g2v(x, y); el.style.zIndex = 100 + v.vc + v.vr;
  },

  shakeU(id) { const el = document.getElementById('u-' + id); if (el) { el.classList.add('shaking'); setTimeout(() => el.classList.remove('shaking'), 300); } },
  atkAnimU(id) { const el = document.getElementById('u-' + id); if (el) { el.classList.add('attacking'); setTimeout(() => el.classList.remove('attacking'), 380); } },
  deathA(id) { const el = document.getElementById('u-' + id); if (el) el.classList.add('dying'); },

  // ── 공격 스프라이트 시트 애니메이션 ──
  showAttackAnim(uId, gender, cls) {
    // 공격 애니메이션 이미지 파일이 없으면 무시
    try {
      const genderCode = gender === 'f' ? '02' : '01';
      const sheetPath = `image/character/${cls}_${genderCode}_attack.png`;
      const w = document.getElementById('iso-world'); if (!w) return;
      const el = document.getElementById('u-' + uId); if (!el) return;
      const rect = el.getBoundingClientRect();
      const wRect = w.getBoundingClientRect();
      const overlay = document.createElement('div');
      overlay.className = 'atk-anim-overlay';
      overlay.style.cssText = `position:absolute;width:400px;height:400px;z-index:2000;pointer-events:none;background-image:url('${sheetPath}');background-size:1600px 400px;background-position:0 0;`;
      overlay.style.left = (parseFloat(el.style.transform?.match(/translate\(([^,]+)/)?.[1]) || 0) - 176 + 'px';
      overlay.style.top = (parseFloat(el.style.transform?.match(/,\s*([^)]+)/)?.[1]) || 0) - 170 + 'px';
      w.appendChild(overlay);
      let frame = 0;
      const interval = setInterval(() => {
        frame++;
        if (frame >= 4) { clearInterval(interval); overlay.remove(); return; }
        overlay.style.backgroundPosition = `-${frame * 400}px 0`;
      }, 150);
    } catch(e) {
      // 공격 애니메이션 오류는 무시 (이미지 파일 없는 경우)
    }
  },
};
