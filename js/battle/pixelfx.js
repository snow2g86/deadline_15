// ═══════════════════════════════════════════
//  battle/pixelfx.js — 코드로 그리는 픽셀 투사체·임팩트 (원거리 직업 기본 공격)
//  2px 도트 격자(월드 해상도의 1/2 캔버스를 2배로 늘려 표시)에 고정 팔레트로만 그린다.
//  위치는 60Hz 고정 간격으로 계산, 임팩트 프레임은 15fps(4틱)로 끊음. 파티클은 미리 할당한 풀 재사용.
//  캐릭터 몸에는 아무것도 붙이지 않고 투사체 경로·대상 칸에만 표시 (확인 페이지: tools/pixel-vfx.html)
//  직업 추가: KINDS에 { fl(비행 ms), arc(포물선 높이 비율), wave(물결 진폭), draw, trail, impact, burst } 한 줄
// ═══════════════════════════════════════════
const PixelFX = (function () {
  const P = 2;                                        // 화면 px / 도트
  const COL = {
    w: '#ffffff', y0: '#fff6d5', y1: '#ffd75e', y2: '#f59e0b', y3: '#b45309', br: '#8a5a2b', bd: '#3b2a1a',
    sh0: '#d9ad6c', sh1: '#8a5a30', hd0: '#eef2fa', hd1: '#9aa3b8', fl0: '#f1ece0', fl1: '#c0392b',
    m0: '#ffffff', m1: '#c9f1ff', m2: '#6fd3ff', m3: '#3b82f6', m4: '#4338ca', m5: '#1e1b4b',
    v0: '#f5e8ff', v1: '#d8b4fe', v2: '#a855f7', v3: '#7e22ce', v4: '#3b0764',
    g0: '#ecfccb', g1: '#86efac', g2: '#22c55e', g3: '#15803d', pu: '#9333ea', pd: '#581c87',
    ol: '#1c1408',
  };
  const PALS = [
    [COL.y0, COL.y1, COL.y2, COL.y3, COL.bd],          // 0 불꽃
    [COL.sh0, COL.br, COL.br, COL.bd],                  // 1 나무 조각
    [COL.m0, COL.m1, COL.m2, COL.m3, COL.m4, COL.m5],   // 2 마력(푸른)
    [COL.y1, COL.y2, COL.y3],                            // 3 바람 꼬리
    [COL.w, COL.y0, COL.y1, COL.y2],                     // 4 금빛 반짝임(지휘관·사제)
    [COL.v0, COL.v1, COL.v2, COL.v3, COL.v4],           // 5 보랏빛(소환사)
    [COL.g0, COL.g1, COL.g2, COL.g3],                    // 6 독액(주술사)
    [COL.pu, COL.pd, COL.pd],                            // 7 보랏빛 연기(주술사)
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
  // 문자 격자 스프라이트 (가운데 기준). ol이면 바깥 1px 어두운 테두리 — 풀밭·물 위에서도 또렷하게
  function sprite(g, x, y, map, ol) {
    const h = g.length, w = g[0].length, ox = Math.round(x - w / 2), oy = Math.round(y - h / 2);
    if (ol) for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (g[j][i] !== '.') {
      ctx.fillStyle = COL.ol; ctx.fillRect(ox + i - 1, oy + j, 3, 1); ctx.fillRect(ox + i, oy + j - 1, 1, 3);
    }
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) { const c = g[j][i]; if (c !== '.') { ctx.fillStyle = map[c]; ctx.fillRect(ox + i, oy + j, 1, 1); } }
  }
  function ring(cx, cy, r, c, gap) {   // 미드포인트 원 (gap이면 띄엄띄엄)
    let x = r, y = 0, e = 1 - r, n = 0;
    while (x >= y) {
      if (!gap || (n++ % 2 === 0)) {
        px(cx + x, cy + y, c); px(cx + y, cy + x, c); px(cx - y, cy + x, c); px(cx - x, cy + y, c);
        px(cx - x, cy - y, c); px(cx - y, cy - x, c); px(cx + y, cy - x, c); px(cx + x, cy - y, c);
      }
      y++; if (e < 0) e += 2 * y + 1; else { x--; e += 2 * (y - x) + 1; }
    }
  }
  function diamond(cx, cy, r, c) { for (let i = 0; i <= r; i++) { px(cx + i, cy + r - i, c); px(cx - i, cy + r - i, c); px(cx + i, cy - r + i, c); px(cx - i, cy - r + i, c); } }
  function filled(cx, cy, r, c) { for (let j = -r; j <= r; j++) for (let i = -r; i <= r; i++) if (Math.abs(i) + Math.abs(j) <= r + (r > 1 ? 1 : 0)) px(cx + i, cy + j, c); }

  // ── 파티클 풀 ──
  const N = 320, pX = new Float32Array(N), pY = new Float32Array(N), pVX = new Float32Array(N), pVY = new Float32Array(N),
    pLife = new Float32Array(N), pMax = new Float32Array(N), pG = new Float32Array(N), pFloor = new Float32Array(N),
    pPal = new Uint8Array(N), pOn = new Uint8Array(N);
  function emit(x, y, vx, vy, life, pal, g, floor) {
    for (let i = 0; i < N; i++) if (!pOn[i]) {
      pOn[i] = 1; pX[i] = x; pY[i] = y; pVX[i] = vx; pVY[i] = vy; pLife[i] = pMax[i] = life; pPal[i] = pal; pG[i] = g || 0; pFloor[i] = floor || 1e9; return;
    }
  }
  const rnd = (a, b) => a + Math.random() * (b - a);

  // ── 진행 중인 투사체·임팩트 (작은 고정 배열 재사용) ──
  const SHOTS = Array.from({ length: 16 }, () => ({ on: 0, kind: '', fx: 0, fy: 0, tx: 0, ty: 0, x: 0, y: 0, ang: 0, t: 0, dur: 1, arc: 0, hist: new Float32Array(12), hn: 0 }));
  const HITS = Array.from({ length: 16 }, () => ({ on: 0, kind: '', x: 0, y: 0, t: 0 }));
  const free = arr => arr.find(o => !o.on);
  const SPOKES = [[1, 0], [-1, 0], [0, 1], [0, -1], [.7, .7], [-.7, .7], [.7, -.7], [-.7, -.7]];
  // 지난 위치를 이어 찍는 꼬리 (화살 바람 꼬리·영혼 불꽃 꼬리)
  function histTail(s, pal, back, len) {
    const tc = Math.cos(s.ang) * back, ts = Math.sin(s.ang) * back;
    for (let i = 1; i < Math.min(s.hn, len); i++) {
      const a = ((s.hn - 1 - i) % 6) * 2, b = ((s.hn - i) % 6) * 2, c = pal[Math.min(pal.length - 1, i >> 1)];
      for (let q = 0; q <= 4; q++) px(s.hist[a] + (s.hist[b] - s.hist[a]) * q / 4 - tc, s.hist[a + 1] + (s.hist[b + 1] - s.hist[a + 1]) * q / 4 - ts, c);
    }
  }

  // ═════ 직업별 ═════
  // 🏹 궁수: 화살
  function drawArrow(s) {
    histTail(s, PALS[3], 11, 6);
    const x = s.x, y = s.y, c = Math.cos(s.ang), sn = Math.sin(s.ang);
    for (let i = 0; i < 10; i++) px(x - c * i, y - sn * i, i % 3 ? COL.sh0 : COL.sh1);
    px(x + c, y + sn, COL.hd0); px(x + c * 2, y + sn * 2, COL.hd0);
    px(x - sn, y + c, COL.hd1); px(x + sn, y - c, COL.hd1);
    for (let i = 8; i < 11; i++) { const f = i === 9 ? COL.fl1 : COL.fl0; px(x - c * i - sn, y - sn * i + c, f); px(x - c * i + sn, y - sn * i - c, f); }
  }
  function archerImpact(cx, cy, f) {
    if (f === 0) { for (let d = -2; d <= 2; d++) { px(cx + d, cy, COL.w); px(cx, cy + d, COL.w); } px(cx + 1, cy + 1, COL.y0); px(cx - 1, cy - 1, COL.y0); }
    if (f === 1) { px(cx, cy, COL.w); SPOKES.forEach(([a, b], j) => { const L = j < 4 ? 4 : 3; for (let r = 2; r <= L; r++) px(cx + a * r, cy + b * r, r === L ? COL.y1 : COL.y0); }); }
    if (f === 2) SPOKES.forEach(([a, b], j) => { const L = j < 4 ? 7 : 5; for (let r = 4; r <= L; r++) px(cx + a * r, cy + b * r, r === L ? COL.y2 : COL.y1); });
    if (f === 3) SPOKES.forEach(([a, b], j) => { const L = j < 4 ? 8 : 6; px(cx + a * L, cy + b * L, COL.y2); px(cx + a * (L - 1), cy + b * (L - 1), COL.y3); });
    if (f === 4) SPOKES.forEach(([a, b], j) => { if (j < 4) px(cx + a * 9, cy + b * 9, COL.y3); });
  }
  const archerBurst = (x, y) => { for (let i = 0; i < 7; i++) emit(x, y, rnd(-1.2, 1.2), rnd(-2.6, -.4), rnd(26, 38), i < 4 ? 1 : 0, .14, y + 14); };

  // 🔮 마법사: 마탄
  const ORB = ['..bbb..', '.bcccb.', 'bcwwwcb', 'bcwwwcb', 'bcwwwcb', '.bcccb.', '..bbb..'],
        ORB2 = ['...b...', '.bbcbb.', '.ccwcc.', 'bcwwwcb', '.ccwcc.', '.bbcbb.', '...b...'];
  const ORBC = { w: COL.m0, c: COL.m1, b: COL.m3 };
  const drawOrb = s => sprite((s.t >> 2) % 2 ? ORB : ORB2, s.x, s.y, ORBC);
  const mageTrail = s => emit(s.x - 3 * Math.cos(s.ang), s.y + rnd(-1.5, 1.5), -Math.cos(s.ang) * rnd(.4, .8), rnd(-.2, .2), rnd(14, 22), 2);
  const MR = [2, 4, 7, 9, 11, 12, 13], MC = [COL.m0, COL.m1, COL.m2, COL.m3, COL.m4, COL.m5, COL.m5];
  function mageImpact(cx, cy, f) {
    if (f === 0) filled(cx, cy, 2, COL.m0);
    else if (f < 7) { ring(cx, cy, MR[f], MC[f]); if (f < 3) ring(cx, cy, MR[f] - 2, COL.m0); if (f === 1) px(cx, cy, COL.m0); }
  }
  const mageBurst = (x, y) => { for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2; emit(x, y, Math.cos(a) * 1.8, Math.sin(a) * 1.8, rnd(18, 28), 2); } };

  // 🎼 지휘관: 음표 — 물결치듯 날아가 금빛 파동 + 작은 음표가 흩어짐
  const NOTE = ['...wc.', '...wwc', '...w.c', '...w..', '.ggw..', 'gggg..', '.gg...'];
  const NOTE2 = ['...ww.', '...wcc', '...w.c', '...w.c', '.ggw..', 'gggg..', '.gg...'];
  const MINI = ['.wc', '.w.', 'gw.', 'gg.'];
  const NOTEC = { w: COL.y0, c: COL.y1, g: COL.y2 };
  const drawNote = s => sprite((s.t >> 3) % 2 ? NOTE : NOTE2, s.x, s.y, NOTEC, true);
  const noteTrail = s => { if (s.t % 3 === 0) emit(s.x - 3 * Math.cos(s.ang), s.y + rnd(-2, 2), rnd(-.3, .3), rnd(-.5, -.2), rnd(14, 20), 4); };
  function commanderImpact(cx, cy, f) {
    if (f === 0) { filled(cx, cy, 1, COL.w); px(cx + 2, cy, COL.y0); px(cx - 2, cy, COL.y0); px(cx, cy + 2, COL.y0); px(cx, cy - 2, COL.y0); }
    if (f >= 1 && f <= 5) {
      ring(cx, cy, 1 + f * 2, [COL.y0, COL.y1, COL.y1, COL.y2, COL.y3][f - 1], f > 3);
      if (f <= 2) ring(cx, cy, f * 2 - 1, COL.w);
      if (f <= 4) [-130, -90, -50].forEach((deg, i) => {   // 작은 음표 셋이 위로 퍼짐
        const a = deg * Math.PI / 180, r = 4 + f * 2.5 + i;
        sprite(MINI, cx + Math.cos(a) * r, cy + Math.sin(a) * r - f, NOTEC, true);
      });
    }
  }
  const commanderBurst = (x, y) => { for (let i = 0; i < 9; i++) emit(x + rnd(-4, 4), y + rnd(-3, 3), rnd(-.8, .8), rnd(-1.4, -.3), rnd(18, 28), 4, -.01); };

  // ✝️ 사제: 성광 구슬 — 빛 입자가 떠오르는 궤적, 십자 섬광
  const HOLY = ['..w..', '.wyw.', 'wyWyw', '.wyw.', '..w..'], HOLY2 = ['w...w', '.wyw.', '.yWy.', '.wyw.', 'w...w'];
  const HOLYC = { W: COL.w, w: COL.y0, y: COL.y1 };
  const drawHoly = s => sprite((s.t >> 2) % 2 ? HOLY : HOLY2, s.x, s.y, HOLYC, true);
  const holyTrail = s => { if (s.t % 2 === 0) emit(s.x + rnd(-2, 2), s.y + rnd(-1, 2), rnd(-.2, .2), rnd(-.7, -.3), rnd(16, 24), 4); };
  function priestImpact(cx, cy, f) {
    const arm = (L, c, from = 1) => { for (let r = from; r <= L; r++) { px(cx + r, cy, c); px(cx - r, cy, c); px(cx, cy + r, c); px(cx, cy - r - 1, c); } };
    if (f === 0) filled(cx, cy, 2, COL.w);
    if (f === 1) { arm(6, COL.y0); px(cx, cy, COL.w); diamond(cx, cy, 3, COL.y1); }
    if (f === 2) { arm(9, COL.y1, 4); diamond(cx, cy, 5, COL.y0); }
    if (f === 3) { arm(10, COL.y2, 8); diamond(cx, cy, 7, COL.y1); }
    if (f === 4) diamond(cx, cy, 8, COL.y2);
  }
  const priestBurst = (x, y) => { for (let i = 0; i < 12; i++) emit(x + rnd(-7, 7), y + rnd(-2, 6), rnd(-.15, .15), rnd(-1.1, -.4), rnd(26, 38), 4, -.01); };

  // 📖 소환사(+정령): 회전하는 마름모 룬 — 물결 궤적, 마름모 파동
  const RUNE = ['...a...', '..aba..', '.abcba.', 'abcwcba', '.abcba.', '..aba..', '...a...'];
  const RUNE2 = ['.aaaaa.', 'ab...ba', 'a.bcb.a', 'a.cwc.a', 'a.bcb.a', 'ab...ba', '.aaaaa.'];
  const RUNEC = { w: COL.v0, c: COL.v1, b: COL.v2, a: COL.v3 };
  const drawRune = s => sprite((s.t >> 2) % 2 ? RUNE : RUNE2, s.x, s.y, RUNEC, true);
  const runeTrail = s => emit(s.x - 3 * Math.cos(s.ang) + rnd(-1, 1), s.y + rnd(-1.5, 1.5), rnd(-.3, .3), rnd(-.3, .3), rnd(12, 20), 5);
  function summonerImpact(cx, cy, f) {
    const R = [2, 4, 6, 8, 10, 11, 12], C = [COL.v0, COL.v0, COL.v1, COL.v2, COL.v3, COL.v4, COL.v4];
    if (f === 0) { filled(cx, cy, 2, COL.v0); px(cx, cy, COL.w); }
    else if (f < 7) { diamond(cx, cy, R[f], C[f]); if (f < 3) diamond(cx, cy, R[f] - 2, COL.w); if (f === 2 || f === 3) { diamond(cx, cy, 1, COL.v1); } }
  }
  const summonerBurst = (x, y) => { for (let i = 0; i < 4; i++) for (let k = 1; k <= 2; k++) { const [a, b] = SPOKES[4 + i]; emit(x, y, a * 1.4 * k, b * 1.4 * k, rnd(16, 24), 5); } };

  // 🎭 주술사: 초록 영혼 불꽃 — 일렁이는 꼬리, 독액이 튀고 보랏빛 연기
  const WISP = ['.bbb.', 'bcccb', 'bcwcb', 'bcccb', '.bbb.'], WISP2 = ['..b..', '.bcb.', 'bcwcb', '.bcb.', '..b..'];
  const WISPC = { w: COL.g0, c: COL.g1, b: COL.g2 };
  function drawWisp(s) {
    // 짧은 불꽃 꼬리: 머리 뒤로 5칸, 뒤로 갈수록 어둡고 위아래로 크게 일렁임
    const c = Math.cos(s.ang), sn = Math.sin(s.ang), TAIL = [COL.g1, COL.g2, COL.g2, COL.g3, COL.pu];
    for (let i = 1; i <= 5; i++) {
      const d = 2 + i * 1.8, fl = Math.sin(s.t * .7 + i * .9) * i * .45;
      const x = s.x - c * d - sn * fl, y = s.y - sn * d + c * fl;
      px(x, y, TAIL[i - 1]); if (i <= 2) { px(x - sn, y + c, TAIL[i - 1]); px(x + sn, y - c, TAIL[i]); }
    }
    sprite((s.t >> 2) % 2 ? WISP : WISP2, s.x, s.y, WISPC, true);
  }
  function shamanImpact(cx, cy, f) {
    if (f === 0) filled(cx, cy, 2, COL.g1);
    if (f === 1) { filled(cx, cy, 2, COL.g2); ring(cx, cy, 4, COL.g1); px(cx, cy, COL.g0); }
    if (f === 2) { ring(cx, cy, 6, COL.g2, true); ring(cx, cy, 3, COL.g3, true); }
    if (f === 3) ring(cx, cy, 7, COL.g3, true);
    if (f === 4) ring(cx, cy, 8, COL.pu, true);
  }
  const shamanBurst = (x, y) => {
    for (let i = 0; i < 9; i++) emit(x, y, rnd(-1.6, 1.6), rnd(-2.2, -.6), rnd(24, 34), 6, .13, y + 12);   // 독액 방울
    for (let i = 0; i < 5; i++) emit(x + rnd(-4, 4), y + rnd(-2, 2), rnd(-.2, .2), rnd(-.5, -.25), rnd(30, 40), 7, -.004);   // 연기
  };

  const KINDS = {
    archer:   { fl: 220, arc: .14, draw: drawArrow, hist: true, impact: archerImpact, burst: archerBurst, up: 4 },
    mage:     { fl: 240, draw: drawOrb, trail: mageTrail, impact: mageImpact, burst: mageBurst, up: 10 },
    commander:{ fl: 260, wave: 3, draw: drawNote, trail: noteTrail, impact: commanderImpact, burst: commanderBurst, up: 8 },
    priest:   { fl: 230, draw: drawHoly, trail: holyTrail, impact: priestImpact, burst: priestBurst, up: 10 },
    summoner: { fl: 250, wave: 4, draw: drawRune, trail: runeTrail, impact: summonerImpact, burst: summonerBurst, up: 8 },
    shaman:   { fl: 260, arc: .08, draw: drawWisp, impact: shamanImpact, burst: shamanBurst, up: 6 },
  };
  KINDS.summon_spirit = KINDS.summoner;
  const FLIGHT = {}; for (const k in KINDS) FLIGHT[k] = KINDS[k].fl;

  // ── 진행 (60Hz) ──
  function update() {
    for (let i = 0; i < N; i++) if (pOn[i]) {
      pX[i] += pVX[i]; pY[i] += pVY[i]; pVY[i] += pG[i]; pVX[i] *= .94; pVY[i] *= .94;
      if (pY[i] > pFloor[i]) { pY[i] = pFloor[i]; pVY[i] *= -.3; pVX[i] *= .5; }
      if (--pLife[i] <= 0) pOn[i] = 0;
    }
    for (const s of SHOTS) if (s.on) {
      const K = KINDS[s.kind]; s.t++;
      const k = Math.min(1, s.t / s.dur), dx = s.tx - s.fx, dy = s.ty - s.fy, len = Math.hypot(dx, dy) || 1;
      const off = K.wave ? Math.sin(k * Math.PI * 2) * K.wave * Math.sin(k * Math.PI) : 0;   // 물결: 양 끝은 0
      const nx = s.x, ny = s.y;
      s.x = s.fx + dx * k - dy / len * off; s.y = s.fy + dy * k + dx / len * off - s.arc * 4 * k * (1 - k);
      if (s.t > 1) s.ang = Math.atan2(s.y - ny, s.x - nx);
      if (K.hist) { s.hist[(s.hn % 6) * 2] = s.x; s.hist[(s.hn % 6) * 2 + 1] = s.y; s.hn++; }
      if (K.trail) K.trail(s);
      if (s.t >= s.dur) s.on = 0;
    }
    for (const h of HITS) if (h.on && ++h.t > 40) h.on = 0;
  }
  function render() {
    ctx.clearRect(0, 0, cv.width, cv.height);
    for (const s of SHOTS) if (s.on) KINDS[s.kind].draw(s);
    for (const h of HITS) if (h.on) KINDS[h.kind].impact(h.x, h.y, h.t >> 2);
    for (let i = 0; i < N; i++) if (pOn[i]) {
      const pal = PALS[pPal[i]], k = Math.min(pal.length - 1, Math.floor((1 - pLife[i] / pMax[i]) * pal.length));
      px(pX[i], pY[i], pal[k]);
    }
  }
  const busy = () => SHOTS.some(s => s.on) || HITS.some(h => h.on) || pOn.some(v => v);
  function loop(now) {
    acc += Math.min(100, now - last) * api.timeScale; last = now;
    while (acc >= 1000 / 60) { update(); acc -= 1000 / 60; }
    render();
    if (busy()) raf = requestAnimationFrame(loop); else { raf = 0; ctx.clearRect(0, 0, cv.width, cv.height); }
  }
  function kick() { if (!raf) { last = performance.now(); acc = 0; raf = requestAnimationFrame(loop); } }

  const api = {
    timeScale: 1,                                     // 확인 페이지의 느리게 보기용
    FLIGHT,
    handles: cls => cls in KINDS,
    up: cls => (KINDS[cls] && KINDS[cls].up) || 0,     // 발사 높이 보정(px): 지팡이·책 끝은 몸통보다 위
    // 투사체 발사 (월드 px 좌표, 비행 ms)
    shoot(kind, fx, fy, tx, ty, ms) {
      if (!ensure() || !KINDS[kind]) return; const s = free(SHOTS); if (!s) return;
      const K = KINDS[kind];
      s.on = 1; s.kind = kind; s.fx = s.x = fx / P; s.fy = s.y = fy / P; s.tx = tx / P; s.ty = ty / P; s.t = 0; s.hn = 0;
      s.ang = Math.atan2(s.ty - s.fy, s.tx - s.fx);
      s.dur = Math.max(4, Math.round((ms || K.fl) / (1000 / 60)));
      s.arc = K.arc ? Math.min(14, Math.abs(s.tx - s.fx) * K.arc + 3) : 0;
      kick();
    },
    // 명중 임팩트 + 파편
    impact(kind, x, y) {
      if (!ensure() || !KINDS[kind]) return; const h = free(HITS); if (!h) return;
      x /= P; y /= P; h.on = 1; h.kind = kind; h.x = x; h.y = y; h.t = 0;
      KINDS[kind].burst(x, y);
      kick();
    },
  };
  return api;
})();
