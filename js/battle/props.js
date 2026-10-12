// ═══════════════════════════════════════════
//  battle/props.js — 맵 오브젝트 그리기 (데이터: data/props.js)
//  숲 나무는 타일 위에 서 있는 그림으로 세워 캐릭터와 앞뒤로 겹침 (Grid.depth 같은 규칙)
//  오브젝트 뒤에 유닛이 가려지면 반투명 (fade), 바닥 장식(ground)은 항상 유닛 아래
// ═══════════════════════════════════════════
const Props = {
  // 칸 좌표로 고정되는 0~1 난수 (다시 그려도 같은 결과)
  _rnd(c, r, k) { return ((((c + 1) * 73856093) ^ ((r + 1) * 19349663) ^ (k * 83492791)) >>> 0) % 10000 / 10000; },

  render() {
    const S = GameStore, w = document.getElementById('iso-world'); if (!w) return;
    const theme = (S.cStage && S.cStage.mapType) || 'plains', filter = PROP_THEME_FILTER[theme] || '';
    const keep = new Set();
    for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
      const tp = S.ter[r][c], def = TILE_PROPS[tp]; if (!def) continue;
      if (def.chance != null && this._rnd(c, r, 1) >= def.chance) continue;
      // 한 칸에 여러 개(spots): 화면 기준 자리 목록 중 count 개, 뒤쪽(화면 위)부터 붙여 앞뒤가 맞게 겹침
      let spots = [def.at];
      if (def.spots) {   // 자리 목록을 칸마다 다른 곳에서 시작해 count 개 (칸마다 다른 자리 조합)
        const n = def.count[0] + Math.floor(this._rnd(c, r, 6) * (def.count[1] - def.count[0] + 1)), s0 = Math.floor(this._rnd(c, r, 7) * def.spots.length);
        spots = Array.from({ length: Math.min(n, def.spots.length) }, (_, i) => def.spots[(s0 + i) % def.spots.length]);
      }
      spots.sort((p, q) => p[1] - q[1]).forEach((at, i) => {
        const k = 10 + i * 7;   // 자리마다 다른 난수
        const name = def.art[Math.floor(this._rnd(c, r, k) * def.art.length)], art = PROP_ART[name];
        const id = 'prop-' + c + '-' + r + '-' + i; keep.add(id);
        let el = document.getElementById(id);
        if (!el) { el = document.createElement('img'); el.id = id; el.alt = ''; el.draggable = false; el.onerror = () => { el.style.visibility = 'hidden'; }; w.appendChild(el); }
        el.className = 'map-prop' + (def.ground ? ' ground' : '');
        if (el.dataset.name !== name) { el.src = 'image/map/' + name + '.png'; el.dataset.name = name; }
        const sc = def.scale ? def.scale[0] + this._rnd(c, r, k + 1) * (def.scale[1] - def.scale[0]) : 1;
        el.style.height = Math.round(art.h * sc) + 'px';
        if (filter) el.style.setProperty('--tf', filter); else el.style.removeProperty('--tf');   // 테마 색 보정 (css 에서 안개와 합침)
        el.dataset.pos = c + ',' + r;
        // 발 위치: 타일 윗면 가운데 + 자리 (화면 기준, 타일 반폭·반높이 비율) + 흩뿌림, 좌우 뒤집기도 무작위
        const sp = def.spread || 0;
        const fx = Grid.tSX(c, r) + TW + (at[0] + (this._rnd(c, r, k + 2) - 0.5) * sp) * TW;
        const fy = Grid.tSY(c, r, TI[tp].z) + TH + (at[1] + (this._rnd(c, r, k + 3) - 0.5) * sp) * TH;
        el.dataset.fx = fx; el.dataset.fy = fy;
        el.style.left = fx + 'px'; el.style.top = fy + 'px';
        el.style.transform = 'translate(-50%,-100%)' + (this._rnd(c, r, k + 4) < 0.5 ? ' scaleX(-1)' : '');
        el.style.zIndex = def.ground ? Grid.g2v(c, r).vc + Grid.g2v(c, r).vr : Grid.depth(c, r, 1);
      });
    }
    w.querySelectorAll('.map-prop').forEach(el => { if (!keep.has(el.id)) el.remove(); });
    this.fog();
    this.fade();
  },

  // 시야 밖(안개) 칸의 오브젝트는 어둡게 — 타일의 fow-dark 와 같이 (Renderer.rTer 에서 시야 계산 뒤 호출)
  fog() {
    const vis = GameStore.fogVisible; if (!vis) return;
    document.querySelectorAll('#iso-world .map-prop').forEach(el => el.classList.toggle('fow', !vis.has(el.dataset.pos)));
  },

  // 오브젝트가 뒤쪽 유닛을 가리면 반투명
  fade() {
    const S = GameStore, w = document.getElementById('iso-world'); if (!w) return;
    const us = S.units.filter(u => u.hp > 0 && u.x >= 0 && u.x < COLS && u.y >= 0 && u.y < ROWS)
      .map(u => ({ x: Grid.uSX(u.x, u.y) + UCX, y: Grid.uSY(u.x, u.y) + UOY + TH, d: Grid.depth(u.x, u.y, 2) }));
    w.querySelectorAll('.map-prop:not(.ground)').forEach(el => {
      const fx = +el.dataset.fx, fy = +el.dataset.fy, z = +el.style.zIndex, hw = (el.width || 60) / 2, h = el.height || 80;
      el.classList.toggle('fade', us.some(u => u.d < z && Math.abs(u.x - fx) < hw + 14 && u.y < fy && u.y > fy - h - UH * 0.6));
    });
  },
};
