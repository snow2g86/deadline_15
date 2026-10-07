// ═══════════════════════════════════════════
//  battle/terrain-tex.js — 절차적 지형 텍스처 (Canvas, 이미지 에셋 없음)
//  타일 종류·테마 색·변형 번호마다 한 번 그려 dataURL로 캐시하고
//  render.js rTerBg()가 각 타일 div의 배경으로 사용한다.
// ═══════════════════════════════════════════
const TerrainTex = {
  _cache: new Map(),
  VARIANTS: 3,
  SCALE: 2, // 고해상도 화면에서도 선명하도록 2배로 그림

  // tp: 지형 종류, clr: {tc,lc,rc}, v: 변형 번호, h: 옆면 높이(px)
  get(tp, clr, v, h) {
    const key = [tp, clr.tc, clr.lc, clr.rc, v, h].join('|');
    let url = this._cache.get(key);
    if (!url) { url = this._draw(tp, clr, v, h); this._cache.set(key, url); }
    return url;
  },

  // 타일 좌표로 변형 번호 고정 (렌더할 때마다 바뀌지 않게)
  variantOf(c, r) { return (((c * 73856093) ^ (r * 19349663)) >>> 0) % this.VARIANTS; },

  // ── 색 유틸 ──
  _rgb(hex) { const n = parseInt(hex.slice(1), 16); return [n >> 16 & 255, n >> 8 & 255, n & 255]; },
  _mix(hex, to, k) { const a = this._rgb(hex), b = this._rgb(to); return `rgb(${a.map((v, i) => Math.round(v + (b[i] - v) * k)).join(',')})`; },
  _lit(hex, k) { return this._mix(hex, '#ffffff', k); },
  _dk(hex, k) { return this._mix(hex, '#000000', k); },
  _rand(seed) { let s = seed >>> 0 || 1; return () => (s = (s * 1664525 + 1013904223) >>> 0) / 4294967296; },

  _draw(tp, clr, v, h) {
    const TWp = TW, THp = TH, W = TW * 2, H = TH * 2 + h + 2, K = this.SCALE;
    const cv = document.createElement('canvas'); cv.width = W * K; cv.height = H * K;
    const ctx = cv.getContext('2d'); ctx.scale(K, K);
    const rnd = this._rand((tp.length * 7919 + v * 104729 + h * 31) ^ this._rgb(clr.tc).reduce((a, b) => a * 31 + b, 7));
    const top = () => { ctx.beginPath(); ctx.moveTo(TWp, 0.5); ctx.lineTo(W - 0.5, THp); ctx.lineTo(TWp, THp * 2 - 0.5); ctx.lineTo(0.5, THp); ctx.closePath(); };
    const left = () => { ctx.beginPath(); ctx.moveTo(0.5, THp); ctx.lineTo(TWp, THp * 2); ctx.lineTo(TWp, THp * 2 + h); ctx.lineTo(0.5, THp + h); ctx.closePath(); };
    const right = () => { ctx.beginPath(); ctx.moveTo(TWp, THp * 2); ctx.lineTo(W - 0.5, THp); ctx.lineTo(W - 0.5, THp + h); ctx.lineTo(TWp, THp * 2 + h); ctx.closePath(); };
    // 다이아몬드 내부 랜덤 점 (마름모 안쪽으로 제한)
    const pt = (m = 0.85) => { for (;;) { const x = rnd() * W, y = rnd() * THp * 2; if (Math.abs(x - TWp) / TWp + Math.abs(y - THp) / THp <= m) return [x, y]; } };

    // ── 옆면 (높이가 있는 타일) ──
    if (h > 0) {
      // 옆면 위 가장자리를 따라 기울어진 선: 왼쪽 면은 (0,TH)→(TW,2TH), 오른쪽 면은 (TW,2TH)→(W,TH)
      const sideTex = (path, base, shade, isLeft) => {
        path(); ctx.save(); ctx.clip();
        const g = ctx.createLinearGradient(0, THp, 0, THp * 2 + h);
        g.addColorStop(0, this._lit(base, 0.06)); g.addColorStop(1, this._dk(base, 0.35));
        ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
        ctx.strokeStyle = this._dk(base, 0.3 + shade); ctx.lineWidth = 0.6;
        const seg = (k) => { ctx.beginPath(); if (isLeft) { ctx.moveTo(0, THp + k); ctx.lineTo(TWp, THp * 2 + k); } else { ctx.moveTo(TWp, THp * 2 + k); ctx.lineTo(W, THp + k); } ctx.stroke(); };
        if (tp === 'wall') {                       // 벽돌: 기울어진 가로 줄눈 + 엇갈린 세로 줄눈
          let row = 0;
          for (let k = 5; k < h; k += 5, row++) {
            seg(k);
            for (let x = (row % 2) * 6 + 3; x < TWp; x += 12) {
              const bx = isLeft ? x : TWp + x, by = isLeft ? THp + x / 2 + k : THp * 2 - x / 2 + k;
              ctx.beginPath(); ctx.moveTo(bx, by - 5); ctx.lineTo(bx, by); ctx.stroke();
            }
          }
        } else {                                   // 지층
          for (let i = 0; i < 3; i++) seg(h * (0.3 + i * 0.25) + (rnd() - 0.5) * 2);
        }
        ctx.restore();
      };
      sideTex(left, clr.lc, 0, true); sideTex(right, clr.rc, 0.1, false);
    }

    // ── 윗면 바탕: 위쪽이 밝은 조명 그라디언트 ──
    top(); ctx.save(); ctx.clip();
    const g = ctx.createLinearGradient(TWp * 0.6, 0, TWp * 1.3, THp * 2);
    g.addColorStop(0, this._lit(clr.tc, 0.10)); g.addColorStop(1, this._dk(clr.tc, 0.12));
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, THp * 2);
    // 미세 노이즈
    for (let i = 0; i < 70; i++) {
      const [x, y] = pt(1); ctx.fillStyle = rnd() < 0.5 ? this._lit(clr.tc, 0.08 + rnd() * 0.08) : this._dk(clr.tc, 0.08 + rnd() * 0.1);
      ctx.fillRect(x, y, 1, 1);
    }

    if (tp === 'plain' || tp === 'gate') {
      if (tp === 'gate') {                         // 나무 판자
        ctx.strokeStyle = this._dk(clr.tc, 0.35); ctx.lineWidth = 0.8;
        for (let x = -THp; x < W; x += 9) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x + THp * 2, THp * 2); ctx.stroke(); }
      } else {
        // 풀 무더기
        const blade = this._lit(clr.tc, 0.22), bladeD = this._dk(clr.tc, 0.2);
        for (let i = 0; i < 9 + v * 2; i++) {
          const [x, y] = pt(0.8);
          for (let j = 0; j < 3; j++) {
            ctx.strokeStyle = j === 1 ? blade : bladeD; ctx.lineWidth = 0.8;
            ctx.beginPath(); ctx.moveTo(x + j * 1.2, y); ctx.lineTo(x + j * 1.2 + (j - 1) * 1.2, y - 2.5 - rnd() * 1.5); ctx.stroke();
          }
        }
        // 작은 꽃·자갈 (변형마다 다르게)
        for (let i = 0; i < v + 1; i++) {
          const [x, y] = pt(0.7);
          ctx.fillStyle = v === 2 ? 'rgba(250,230,140,.75)' : v === 1 ? 'rgba(255,255,255,.55)' : this._lit(clr.tc, 0.3);
          ctx.beginPath(); ctx.arc(x, y, 0.9, 0, 6.3); ctx.fill();
        }
      }
    } else if (tp === 'forest') {
      // 나무 2~3그루: 그림자 → 줄기 → 수관(3겹)
      const n = 3 + (v % 2), spots = [[0.5, 0.3], [0.28, 0.5], [0.72, 0.5], [0.5, 0.74]];
      const leaf = this._lit(clr.tc, 0.08), leafL = this._lit(clr.tc, 0.4), leafD = this._dk(clr.tc, 0.35);
      for (let i = 0; i < n; i++) {
        const [fx, fy] = spots[(i + v) % spots.length];
        const x = W * fx + (rnd() - 0.5) * 6, y = THp * 2 * fy + (rnd() - 0.5) * 3, R = 10 + rnd() * 3;
        ctx.fillStyle = 'rgba(0,0,0,.28)'; ctx.beginPath(); ctx.ellipse(x + 2, y + 4, R, R * 0.45, 0, 0, 6.3); ctx.fill();
        ctx.fillStyle = this._dk(clr.lc, 0.4); ctx.fillRect(x - 1, y - 2, 2, 6);
        const cg = ctx.createRadialGradient(x - R * 0.35, y - R * 0.9, 1, x, y - R * 0.5, R * 1.1);
        cg.addColorStop(0, leafL); cg.addColorStop(0.55, leaf); cg.addColorStop(1, leafD);
        ctx.fillStyle = cg;
        [[0, -R * 0.55, R], [-R * 0.55, -R * 0.2, R * 0.7], [R * 0.55, -R * 0.25, R * 0.7]].forEach(([ox, oy, r]) => {
          ctx.beginPath(); ctx.arc(x + ox, y + oy, r * 0.75, 0, 6.3); ctx.fill();
        });
      }
    } else if (tp === 'hill') {
      // 등고선 + 자갈
      ctx.strokeStyle = this._lit(clr.tc, 0.22); ctx.lineWidth = 0.7;
      for (let i = 1; i <= 2; i++) { ctx.beginPath(); ctx.ellipse(TWp, THp, TWp * (0.25 * i + 0.1), THp * (0.25 * i + 0.1), 0, 3.4, 6.0); ctx.stroke(); }
      for (let i = 0; i < 4; i++) { const [x, y] = pt(0.75); ctx.fillStyle = this._dk(clr.tc, 0.3); ctx.beginPath(); ctx.ellipse(x, y, 1.6, 1, 0, 0, 6.3); ctx.fill(); }
    } else if (tp === 'rock') {
      // 각진 바위 덩어리 (밝은 면/어두운 면)
      // 작은 돌 몇 개
      for (let i = 0; i < 3; i++) { const [x, y] = pt(0.8); ctx.fillStyle = this._lit(clr.tc, 0.15); ctx.beginPath(); ctx.ellipse(x, y, 2.2, 1.4, 0, 0, 6.3); ctx.fill(); }
      const cx = TWp + (rnd() - 0.5) * 6, cy = THp - 1, R = 20 + v * 2;
      const pts = Array.from({ length: 7 }, (_, i) => { const a = i / 7 * 6.283 + rnd() * 0.4; return [cx + Math.cos(a) * R * (0.8 + rnd() * 0.3), cy + Math.sin(a) * R * 0.55 * (0.8 + rnd() * 0.3)]; });
      ctx.fillStyle = 'rgba(0,0,0,.3)'; ctx.beginPath(); ctx.ellipse(cx + 2, cy + 5, R, R * 0.4, 0, 0, 6.3); ctx.fill();
      ctx.beginPath(); pts.forEach(([x, y], i) => i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)); ctx.closePath();
      const rg = ctx.createLinearGradient(cx - R, cy - R, cx + R, cy + R);
      rg.addColorStop(0, this._lit(clr.tc, 0.3)); rg.addColorStop(1, this._dk(clr.tc, 0.25));
      ctx.fillStyle = rg; ctx.fill();
      ctx.strokeStyle = this._dk(clr.tc, 0.45); ctx.lineWidth = 0.7; ctx.stroke();
      // 불규칙한 균열 2줄 + 윗면 하이라이트
      for (let k = 0; k < 2; k++) {
        let x = cx + (rnd() - 0.5) * R, y = cy - R * 0.35 + rnd() * 3;
        ctx.beginPath(); ctx.moveTo(x, y);
        for (let i = 0; i < 3; i++) { x += (rnd() - 0.3) * R * 0.3; y += R * 0.12 + rnd() * 2; ctx.lineTo(x, y); }
        ctx.stroke();
      }
      ctx.fillStyle = 'rgba(255,255,255,.10)'; ctx.beginPath(); ctx.ellipse(cx - R * 0.25, cy - R * 0.25, R * 0.35, R * 0.15, -0.3, 0, 6.3); ctx.fill();
    } else if (tp === 'water') {
      // 깊이 그라디언트 + 물결
      const wg = ctx.createRadialGradient(TWp, THp, 2, TWp, THp, TWp);
      wg.addColorStop(0, this._dk(clr.tc, 0.15)); wg.addColorStop(1, this._lit(clr.tc, 0.12));
      ctx.fillStyle = wg; ctx.fillRect(0, 0, W, THp * 2);
      ctx.strokeStyle = 'rgba(255,255,255,.22)'; ctx.lineWidth = 0.8; ctx.lineCap = 'round';
      for (let i = 0; i < 4; i++) {
        const [x, y] = pt(0.7), L = 6 + rnd() * 6;
        ctx.beginPath(); ctx.moveTo(x - L, y); ctx.quadraticCurveTo(x - L / 2, y - 1.6, x, y); ctx.quadraticCurveTo(x + L / 2, y + 1.6, x + L, y); ctx.stroke();
      }
    } else if (tp === 'shallow') {
      // 여울: 밝은 얕은 물 + 바닥 자갈이 비침 + 잔물결
      const sg = ctx.createRadialGradient(TWp, THp, 2, TWp, THp, TWp);
      sg.addColorStop(0, this._lit(clr.tc, 0.12)); sg.addColorStop(1, this._dk(clr.tc, 0.08));
      ctx.fillStyle = sg; ctx.fillRect(0, 0, W, THp * 2);
      for (let i = 0; i < 7; i++) {
        const [x, y] = pt(0.75);
        ctx.fillStyle = `rgba(0,0,0,${0.12 + rnd() * 0.1})`;
        ctx.beginPath(); ctx.ellipse(x, y, 1.5 + rnd() * 2, 0.8 + rnd(), 0, 0, 6.3); ctx.fill();
      }
      ctx.strokeStyle = 'rgba(255,255,255,.30)'; ctx.lineWidth = 0.7; ctx.lineCap = 'round';
      for (let i = 0; i < 3; i++) {
        const [x, y] = pt(0.6), L = 4 + rnd() * 4;
        ctx.beginPath(); ctx.moveTo(x - L, y); ctx.quadraticCurveTo(x, y - 1.4, x + L, y); ctx.stroke();
      }
    } else if (tp === 'wall') {
      // 윗면 석판
      ctx.strokeStyle = this._dk(clr.tc, 0.35); ctx.lineWidth = 0.7;
      for (let i = 1; i <= 2; i++) {             // 석판 줄눈 (마름모를 3등분)
        const k = i / 3;
        ctx.beginPath(); ctx.moveTo(TWp * k, THp - THp * k); ctx.lineTo(TWp + TWp * k, THp * 2 - THp * k); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(TWp * k, THp + THp * k); ctx.lineTo(TWp + TWp * k, THp * k); ctx.stroke();
      }
    }
    ctx.restore();

    // ── 가장자리: 위쪽 두 변은 밝게, 아래 두 변은 어둡게 → 격자 구분 ──
    ctx.lineWidth = 1;
    ctx.strokeStyle = (tp === 'water' || tp === 'shallow') ? 'rgba(160,210,255,.18)' : 'rgba(255,255,255,.10)';
    ctx.beginPath(); ctx.moveTo(0.5, THp); ctx.lineTo(TWp, 0.5); ctx.lineTo(W - 0.5, THp); ctx.stroke();
    ctx.strokeStyle = 'rgba(0,0,0,.28)';
    ctx.beginPath(); ctx.moveTo(0.5, THp); ctx.lineTo(TWp, THp * 2 - 0.5); ctx.lineTo(W - 0.5, THp); ctx.stroke();

    return cv.toDataURL('image/png');
  },
};
