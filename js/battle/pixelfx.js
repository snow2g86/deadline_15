// ═══════════════════════════════════════════
//  battle/pixelfx.js — 코드로 그리는 픽셀 투사체·임팩트 (궁수 화살 / 마법사 마탄)
//  2px 도트 격자(월드 해상도의 1/2 캔버스를 2배로 늘려 표시)에 고정 팔레트로만 그린다.
//  위치는 60Hz 고정 간격으로 계산, 임팩트 프레임은 15fps(4틱)로 끊음. 파티클은 미리 할당한 풀 재사용.
//  캐릭터 몸에는 아무것도 붙이지 않고 투사체 경로·대상 칸에만 표시 (샘플: tools/pixel-vfx.html)
// ═══════════════════════════════════════════
const PixelFX = (function () {
  const P = 2;                                        // 화면 px / 도트
  const FLIGHT = { archer: 220, mage: 240 };          // 비행 시간(ms) — 발사 프레임 뒤 이만큼 지나 명중
  const COL = {
    w: '#ffffff', y0: '#fff6d5', y1: '#ffd75e', y2: '#f59e0b', y3: '#b45309', br: '#8a5a2b', bd: '#3b2a1a',
    sh0: '#d9ad6c', sh1: '#8a5a30', hd0: '#eef2fa', hd1: '#9aa3b8', fl0: '#f1ece0', fl1: '#c0392b',
    m0: '#ffffff', m1: '#c9f1ff', m2: '#6fd3ff', m3: '#3b82f6', m4: '#4338ca', m5: '#1e1b4b',
  };
  const PALS = [
    [COL.y0, COL.y1, COL.y2, COL.y3, COL.bd],          // 0 불꽃(궁수)
    [COL.sh0, COL.br, COL.br, COL.bd],                  // 1 나무 조각
    [COL.m0, COL.m1, COL.m2, COL.m3, COL.m4, COL.m5],   // 2 마력
    [COL.y1, COL.y2, COL.y3],                            // 3 바람 꼬리
  ];
  let cv = null, ctx = null, raf = 0, acc = 0, last = 0;

  // ── 캔버스: vfx-canvas 옆에 절반 해상도로 만들고 같은 크기로 늘림 ──
  function ensure() {
    const base = document.getElementById('vfx-canvas'); if (!base) return false;
    if (!cv) {
      cv = document.createElement('canvas'); cv.id = 'pfx-canvas';
      cv.style.cssText = 'position:absolute;top:0;left:0;pointer-events:none;z-index:351;image-rendering:pixelated';
      base.parentNode.insertBefore(cv, base.nextSibling); ctx = cv.getContext('2d');
    }
    const w = Math.ceil(base.width / P), h = Math.ceil(base.height / P);
    if (cv.width !== w || cv.height !== h) { cv.width = w; cv.height = h; cv.style.width = w * P + 'px'; cv.style.height = h * P + 'px'; }
    return true;
  }
  const px = (x, y, c) => { ctx.fillStyle = c; ctx.fillRect(Math.round(x), Math.round(y), 1, 1); };

  // ── 파티클 풀 ──
  const N = 256, pX = new Float32Array(N), pY = new Float32Array(N), pVX = new Float32Array(N), pVY = new Float32Array(N),
    pLife = new Float32Array(N), pMax = new Float32Array(N), pG = new Float32Array(N), pFloor = new Float32Array(N),
    pPal = new Uint8Array(N), pOn = new Uint8Array(N);
  function emit(x, y, vx, vy, life, pal, g, floor) {
    for (let i = 0; i < N; i++) if (!pOn[i]) {
      pOn[i] = 1; pX[i] = x; pY[i] = y; pVX[i] = vx; pVY[i] = vy; pLife[i] = pMax[i] = life; pPal[i] = pal; pG[i] = g || 0; pFloor[i] = floor || 1e9; return;
    }
  }

  // ── 진행 중인 투사체·임팩트 (작은 고정 배열 재사용) ──
  const SHOTS = Array.from({ length: 16 }, () => ({ on: 0, kind: '', fx: 0, fy: 0, tx: 0, ty: 0, t: 0, dur: 1, arc: 0, hist: new Float32Array(12), hn: 0 }));
  const HITS = Array.from({ length: 16 }, () => ({ on: 0, kind: '', x: 0, y: 0, t: 0 }));
  const free = arr => arr.find(o => !o.on);

  // ── 그리기: 화살 (각도에 맞춰 픽셀을 찍음 → 회전해도 또렷) ──
  function drawArrow(x, y, ang) {
    const c = Math.cos(ang), s = Math.sin(ang);
    for (let i = 0; i < 10; i++) px(x - c * i, y - s * i, i % 3 ? COL.sh0 : COL.sh1);
    px(x + c, y + s, COL.hd0); px(x + c * 2, y + s * 2, COL.hd0);
    px(x - s, y + c, COL.hd1); px(x + s, y - c, COL.hd1);
    for (let i = 8; i < 11; i++) { const f = i === 9 ? COL.fl1 : COL.fl0; px(x - c * i - s, y - s * i + c, f); px(x - c * i + s, y - s * i - c, f); }
  }
  const ORB = ['..bbb..', '.bcccb.', 'bcwwwcb', 'bcwwwcb', 'bcwwwcb', '.bcccb.', '..bbb..'],
        ORB2 = ['...b...', '.bbcbb.', '.ccwcc.', 'bcwwwcb', '.ccwcc.', '.bbcbb.', '...b...'];
  const ORBC = { w: COL.m0, c: COL.m1, b: COL.m3 };
  function drawOrb(x, y, t) {
    const g = (t >> 2) % 2 ? ORB : ORB2;
    for (let j = 0; j < 7; j++) for (let i = 0; i < 7; i++) { const ch = g[j][i]; if (ch !== '.') px(x - 3 + i, y - 3 + j, ORBC[ch]); }
  }
  const SPOKES = [[1, 0], [-1, 0], [0, 1], [0, -1], [.7, .7], [-.7, .7], [.7, -.7], [-.7, -.7]];
  // 궁수 임팩트 5프레임: 섬광 → 방사 불꽃 → 끝만 남음 → 사라짐
  function archerImpact(cx, cy, f) {
    if (f === 0) { for (let d = -2; d <= 2; d++) { px(cx + d, cy, COL.w); px(cx, cy + d, COL.w); } px(cx + 1, cy + 1, COL.y0); px(cx - 1, cy - 1, COL.y0); }
    if (f === 1) { px(cx, cy, COL.w); SPOKES.forEach(([a, b], j) => { const L = j < 4 ? 4 : 3; for (let r = 2; r <= L; r++) px(cx + a * r, cy + b * r, r === L ? COL.y1 : COL.y0); }); }
    if (f === 2) SPOKES.forEach(([a, b], j) => { const L = j < 4 ? 7 : 5; for (let r = 4; r <= L; r++) px(cx + a * r, cy + b * r, r === L ? COL.y2 : COL.y1); });
    if (f === 3) SPOKES.forEach(([a, b], j) => { const L = j < 4 ? 8 : 6; px(cx + a * L, cy + b * L, COL.y2); px(cx + a * (L - 1), cy + b * (L - 1), COL.y3); });
    if (f === 4) SPOKES.forEach(([a, b], j) => { if (j < 4) px(cx + a * 9, cy + b * 9, COL.y3); });
  }
  function ring(cx, cy, r, c) {
    let x = r, y = 0, e = 1 - r;
    while (x >= y) {
      px(cx + x, cy + y, c); px(cx + y, cy + x, c); px(cx - y, cy + x, c); px(cx - x, cy + y, c);
      px(cx - x, cy - y, c); px(cx - y, cy - x, c); px(cx + y, cy - x, c); px(cx + x, cy - y, c);
      y++; if (e < 0) e += 2 * y + 1; else { x--; e += 2 * (y - x) + 1; }
    }
  }
  // 마법사 임팩트 7프레임: 흰 섬광 → 충격파 원이 커지며 색이 식음
  const MR = [2, 4, 7, 9, 11, 12, 13], MC = [COL.m0, COL.m1, COL.m2, COL.m3, COL.m4, COL.m5, COL.m5];
  function mageImpact(cx, cy, f) {
    if (f === 0) { for (let j = -2; j <= 2; j++) for (let i = -2; i <= 2; i++) if (Math.abs(i) + Math.abs(j) <= 3) px(cx + i, cy + j, COL.m0); }
    else if (f < 7) { ring(cx, cy, MR[f], MC[f]); if (f < 3) ring(cx, cy, MR[f] - 2, COL.m0); if (f === 1) px(cx, cy, COL.m0); }
  }

  // ── 진행 (60Hz) ──
  function update() {
    for (let i = 0; i < N; i++) if (pOn[i]) {
      pX[i] += pVX[i]; pY[i] += pVY[i]; pVY[i] += pG[i]; pVX[i] *= .94; pVY[i] *= .94;
      if (pY[i] > pFloor[i]) { pY[i] = pFloor[i]; pVY[i] *= -.3; pVX[i] *= .5; }
      if (--pLife[i] <= 0) pOn[i] = 0;
    }
    for (const s of SHOTS) if (s.on) {
      s.t++;
      const k = Math.min(1, s.t / s.dur);
      s.x = s.fx + (s.tx - s.fx) * k; s.y = s.fy + (s.ty - s.fy) * k - s.arc * 4 * k * (1 - k);
      if (s.kind === 'mage') emit(s.x - 3, s.y + (Math.random() - .5) * 3, -Math.sign(s.tx - s.fx || 1) * (.4 + Math.random() * .4), (Math.random() - .5) * .4, 14 + Math.random() * 8, 2);
      else { s.hist[(s.hn % 6) * 2] = s.x; s.hist[(s.hn % 6) * 2 + 1] = s.y; s.hn++; }
      if (s.t >= s.dur) s.on = 0;
    }
    for (const h of HITS) if (h.on && ++h.t > 40) h.on = 0;
  }
  function render() {
    ctx.clearRect(0, 0, cv.width, cv.height);
    for (const s of SHOTS) if (s.on) {
      if (s.kind === 'archer') {
        const k = s.t / s.dur, dk = 1 / s.dur;
        const vx = (s.tx - s.fx) * dk, vy = (s.ty - s.fy) * dk - s.arc * 4 * (1 - 2 * k) * dk, ang = Math.atan2(vy, vx);
        const tc = Math.cos(ang) * 11, ts = Math.sin(ang) * 11;   // 바람 꼬리: 깃 뒤로 지난 위치를 이어 찍음
        for (let i = 1; i < Math.min(s.hn, 6); i++) {
          const a = ((s.hn - 1 - i) % 6) * 2, b = ((s.hn - i) % 6) * 2, c = PALS[3][Math.min(2, i >> 1)];
          for (let q = 0; q <= 4; q++) px(s.hist[a] + (s.hist[b] - s.hist[a]) * q / 4 - tc, s.hist[a + 1] + (s.hist[b + 1] - s.hist[a + 1]) * q / 4 - ts, c);
        }
        drawArrow(s.x, s.y, ang);
      } else drawOrb(s.x, s.y, s.t);
    }
    for (const h of HITS) if (h.on) (h.kind === 'archer' ? archerImpact : mageImpact)(h.x, h.y, h.t >> 2);
    for (let i = 0; i < N; i++) if (pOn[i]) {
      const pal = PALS[pPal[i]], k = Math.min(pal.length - 1, Math.floor((1 - pLife[i] / pMax[i]) * pal.length));
      px(pX[i], pY[i], pal[k]);
    }
  }
  const busy = () => SHOTS.some(s => s.on) || HITS.some(h => h.on) || pOn.some(v => v);
  function loop(now) {
    acc += Math.min(100, now - last); last = now;
    while (acc >= 1000 / 60) { update(); acc -= 1000 / 60; }
    render();
    if (busy()) raf = requestAnimationFrame(loop); else { raf = 0; ctx.clearRect(0, 0, cv.width, cv.height); }
  }
  function kick() { if (!raf) { last = performance.now(); acc = 0; raf = requestAnimationFrame(loop); } }

  return {
    FLIGHT,
    handles: cls => cls in FLIGHT,
    // 투사체 발사 (월드 px 좌표, 비행 ms)
    shoot(kind, fx, fy, tx, ty, ms) {
      if (!ensure()) return; const s = free(SHOTS); if (!s) return;
      s.on = 1; s.kind = kind; s.fx = fx / P; s.fy = fy / P; s.tx = tx / P; s.ty = ty / P; s.t = 0; s.hn = 0;
      s.dur = Math.max(4, Math.round((ms || FLIGHT[kind]) / (1000 / 60)));
      s.arc = kind === 'archer' ? Math.min(14, Math.abs(s.tx - s.fx) * .14 + 3) : 0;
      kick();
    },
    // 명중 임팩트 + 파편
    impact(kind, x, y) {
      if (!ensure()) return; const h = free(HITS); if (!h) return;
      x /= P; y /= P; h.on = 1; h.kind = kind; h.x = x; h.y = y; h.t = 0;
      if (kind === 'archer') for (let i = 0; i < 7; i++) emit(x, y, (Math.random() - .5) * 2.4, -Math.random() * 2.2 - .4, 26 + Math.random() * 12, i < 4 ? 1 : 0, .14, y + 14);
      else for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2; emit(x, y, Math.cos(a) * 1.8, Math.sin(a) * 1.8, 18 + Math.random() * 10, 2); }
      kick();
    },
  };
})();
