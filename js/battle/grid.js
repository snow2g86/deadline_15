// ═══════════════════════════════════════════
//  battle/grid.js — Map, coordinates, pathfinding, traps
// ═══════════════════════════════════════════

const Grid = {
  // ── 좌표 변환 ──
  g2v(c, r) {
    switch (GameStore.camDir) {
      case 0: return { vc: c, vr: r };
      case 1: return { vc: ROWS - 1 - r, vr: c };
      case 2: return { vc: COLS - 1 - c, vr: ROWS - 1 - r };
      case 3: return { vc: r, vr: COLS - 1 - c };
    }
  },
  v2g(vc, vr) {
    switch (GameStore.camDir) {
      case 0: return { c: vc, r: vr };
      case 1: return { c: vr, r: ROWS - 1 - vc };
      case 2: return { c: COLS - 1 - vc, r: ROWS - 1 - vr };
      case 3: return { c: COLS - 1 - vr, r: vc };
    }
  },
  vDim() { return GameStore.camDir % 2 === 0 ? { c: COLS, r: ROWS } : { c: ROWS, r: COLS }; },

  isoX(vc, vr) { return (vc - vr) * TW + this.vDim().r * TW; },
  isoY(vc, vr, z) { return (vc + vr) * TH - (z || 0) * ZH; },

  isoHit(px, py) {
    const d = this.vDim(), oX = d.r * TW;
    const fvc = ((px - oX) / TW + py / TH) / 2;
    const fvr = (py / TH - (px - oX) / TW) / 2;
    let best = null, bestD = Infinity;
    for (let dvc = -1; dvc <= 1; dvc++) for (let dvr = -1; dvr <= 1; dvr++) {
      const vc = Math.floor(fvc) + dvc, vr = Math.floor(fvr) + dvr;
      if (vc < 0 || vr < 0 || vc >= d.c || vr >= d.r) continue;
      const cx = this.isoX(vc, vr) + TW, cy = this.isoY(vc, vr, 0) + TH;
      const dx = Math.abs(px - cx) / TW, dy = Math.abs(py - cy) / TH;
      if (dx + dy <= 1) {
        const dist = dx + dy;
        if (dist < bestD) { bestD = dist; const g = this.v2g(vc, vr); best = { c: g.c, r: g.r }; }
      }
    }
    return best;
  },

  // ── 타일 → 스크린 좌표 ──
  tSX(c, r) { const v = this.g2v(c, r); return this.isoX(v.vc, v.vr); },
  tSY(c, r, z) { const v = this.g2v(c, r); return this.isoY(v.vc, v.vr, z); },
  uSX(c, r) { return this.tSX(c, r) + TW - UCX; },
  uSY(c, r) { const t = GameStore.ter[r] ? GameStore.ter[r][c] : null; return this.tSY(c, r, t ? TI[t].z : 0) - UOY; },

  // ── 지형 생성 ──
  genT() {
    const S = GameStore;
    S.ter = []; S.gateHP = {}; S.wallHP = {}; S.breached = 0;
    const wallRow = (row) => {
      const r = [];
      for (let c = 0; c < COLS; c++) {
        // 가운데 두 칸 성문, 그 양옆 두 칸씩 성벽, 나머지 물 (가로 8: 물·벽벽·문문·벽벽·물)
        if (c >= MID_C - 3 && c <= MID_C - 2 || c >= MID_C + 1 && c <= MID_C + 2) { r.push('wall'); S.wallHP[c + ',' + row] = 200; }
        else if (c >= MID_C - 1 && c <= MID_C) { r.push('gate'); S.gateHP[c + ',' + row] = 2; }
        else r.push('water');
      }
      return r;
    };
    const moatRow = () => {
      const r = [];
      for (let c = 0; c < COLS; c++) {
        if (c >= MID_C - 1 && c <= MID_C) r.push('plain'); else r.push('water');
      }
      return r;
    };
    const isOffense = S.cStage && S.cStage.style === 'offense';
    for (let r = 0; r < ROWS; r++) {
      if (!isOffense && r === 14) S.ter[r] = wallRow(r);
      else if (!isOffense && r === 13) S.ter[r] = moatRow();
      else if (isOffense && r === 0) S.ter[r] = wallRow(r);
      else if (isOffense && r === 1) S.ter[r] = moatRow();
      else if (r <= 1 || r >= 11) {
        S.ter[r] = [];
        for (let c = 0; c < COLS; c++) S.ter[r][c] = 'plain';
      } else {
        const theme = MAP_THEMES[(S.cStage && S.cStage.mapType) || 'plains'];
        const d = theme.dist;
        S.ter[r] = [];
        for (let c = 0; c < COLS; c++) {
          const rn = Math.random(); let acc = 0;
          S.ter[r][c] = (acc += d.rock, rn < acc) ? 'rock' : (acc += d.hill, rn < acc) ? 'hill' : (acc += d.forest, rn < acc) ? 'forest' : (acc += (d.water || 0), rn < acc) ? 'water' : (acc += (d.shallow || 0), rn < acc) ? 'shallow' : 'plain';
        }
      }
    }
  },

  _initTColors() {
    const theme = MAP_THEMES[(GameStore.cStage && GameStore.cStage.mapType) || 'plains'];
    this._tColors = {};
    for (const tp in TI) {
      this._tColors[tp] = theme.colors[tp]
        ? { tc: theme.colors[tp].tc, lc: theme.colors[tp].lc, rc: theme.colors[tp].rc }
        : { tc: TI[tp].tc, lc: TI[tp].lc, rc: TI[tp].rc };
    }
  },

  // ── 지형 비용 패스파인딩 ──
  terrainCost(tile) {
    const ti = TI[tile];
    if (!ti || !ti.pass) return Infinity;
    // 지형별 이동 비용 차등
    if (tile === 'forest') return 1.5;
    if (tile === 'hill') return 2;
    return ti.cost || 1;
  },

  // ── 아군 이동 범위 (스텔스 포함) ──
  mvCells(u) {
    const S = GameStore;
    if (BuffSystem.has(u, BuffType.STUN) || BuffSystem.has(u, BuffType.FREEZE)) return [];
    const res = [], vis = new Map(), q = [{ x: u.x, y: u.y, c: 0 }];
    const K = (a, b) => a + ',' + b;
    const isStealth = u.cls === 'assassin' && u.team === 'ally' && S.ter[u.y] && S.ter[u.y][u.x] === 'forest';
    vis.set(K(u.x, u.y), 0);
    while (q.length) {
      const { x, y, c } = q.shift();
      const occ = UnitManager.uAt(x, y);
      const occHidden = occ && occ.team !== u.team && isStealthed(occ);
      if (c > 0 && (!occ || occHidden)) res.push({ x, y });
      if (c > 0 && occ && occ.team !== u.team && !occHidden && isStealth && S.ter[y] && S.ter[y][x] === 'forest') res.push({ x, y });
      if (c > 0 && UnitManager.inZoc(u, x, y)) continue; // 제압 구역: 들어가면 더 못 감
      for (const [dx, dy] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || nx >= COLS || ny < 0 || ny >= ROWS) continue;
        const ti = TI[S.ter[ny][nx]]; if (!ti.pass) continue;
        const o = UnitManager.uAt(nx, ny);
        const oHidden = o && o.team !== u.team && isStealthed(o);
        if (o && o.team !== u.team && !oHidden) {
          if (isStealth && S.ter[ny][nx] === 'forest') {
            const nc = c + ti.cost;
            if (nc <= u.move) { const k = K(nx, ny); if (!vis.has(k) || vis.get(k) > nc) vis.set(k, nc); }
          }
          continue;
        }
        if (o && o.team === u.team) {
          const nc = c + ti.cost; if (nc > u.move) continue;
          const k = K(nx, ny);
          if (!vis.has(k) || vis.get(k) > nc) { vis.set(k, nc); q.push({ x: nx, y: ny, c: nc }); }
          continue;
        }
        const nc = c + ti.cost; if (nc > u.move) continue;
        const k = K(nx, ny);
        if (!vis.has(k) || vis.get(k) > nc) { vis.set(k, nc); q.push({ x: nx, y: ny, c: nc }); }
      }
    }
    this._addVault(u, vis, res);
    return res;
  },

  // ── 도움닫기 (궁수·도적) ──
  // 갈 수 있는 칸(출발 칸 포함, 같은 편이 서 있어 지나가기만 하는 칸도 포함)에서 바로 앞 칸에 같은 편이 있으면
  // 그 동료를 넘어 같은 방향으로 1~VAULT_DIST칸 더 갈 수 있다. 착지 칸은 비어 있어야 하고, 넘는 길의 적·동료는 뛰어넘을 수 있음
  // (거리 안이면 적 뒤로 착지). 막힌 지형(바위·물·성벽)을 만나면 거기서 멈춤.
  // 제압 구역(ZOC) 안에서는 도약 불가(출발 칸 제외). 추가된 칸은 vault: true 표시
  _addVault(u, vis, res) {
    if (!VAULT_CLASSES.includes(u.cls)) return;
    const S = GameStore, has = new Set(res.map(m => m.x + ',' + m.y));
    for (const [key] of vis) {
      const [x, y] = key.split(',').map(Number);
      const start = x === u.x && y === u.y;
      if (!start && UnitManager.inZoc(u, x, y)) continue;
      const here = UnitManager.uAt(x, y);
      if (!start && here && here.team !== u.team) continue;
      for (const [dx, dy] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) {
        const mate = UnitManager.uAt(x + dx, y + dy);
        if (!mate || mate.id === u.id || mate.team !== u.team || mate.hp <= 0) continue;
        for (let i = 1; i <= VAULT_DIST; i++) {
          const lx = x + dx * (1 + i), ly = y + dy * (1 + i);
          if (lx < 0 || lx >= COLS || ly < 0 || ly >= ROWS || !TI[S.ter[ly][lx]].pass) break;
          const o = UnitManager.uAt(lx, ly);
          if (o && !(o.team !== u.team && isStealthed(o))) continue;   // 사람이 선 칸(같은 편·적 모두)에는 못 내리지만 넘어서 그 뒤에 착지 가능
          const k = lx + ',' + ly;
          if (!has.has(k) && !(lx === u.x && ly === u.y)) { has.add(k); res.push({ x: lx, y: ly, vault: true }); }
        }
      }
    }
  },

  // ── 적 이동 범위 (지형 비용 적용) ──
  eMvCells(u) {
    const S = GameStore;
    const res = [], vis = new Map(), q = [{ x: u.x, y: u.y, c: 0 }];
    const K = (a, b) => a + ',' + b;
    vis.set(K(u.x, u.y), 0);
    while (q.length) {
      const { x, y, c } = q.shift();
      const occ = UnitManager.uAt(x, y);
      const occStealth = occ && isStealthed(occ);
      if (c > 0 && (!occ || occStealth)) res.push({ x, y });
      if (c > 0 && UnitManager.inZoc(u, x, y)) continue; // 제압 구역: 들어가면 더 못 감
      for (const [dx, dy] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || nx >= COLS || ny < 0 || ny >= ROWS) continue;
        const tile = S.ter[ny][nx];
        const ti = TI[tile]; if (!ti.pass) continue;
        const o = UnitManager.uAt(nx, ny);
        if (o && o.team !== u.team && !isStealthed(o)) continue;
        const cost = this.terrainCost(tile);
        const nc = c + cost; if (nc > u.move) continue;
        const k = K(nx, ny);
        if (!vis.has(k) || vis.get(k) > nc) { vis.set(k, nc); q.push({ x: nx, y: ny, c: nc }); }
      }
    }
    this._addVault(u, vis, res);
    return res;
  },

  // ── 공격/힐 범위 ──
  atkCells(u) {
    const cells = [];
    // 고지대: 언덕 위 원거리 유닛은 사거리 +1
    const onHill = GameStore.ter[u.y] && GameStore.ter[u.y][u.x] === 'hill';
    const rng = u.range + (onHill && u.range > 1 ? TACTIC.highRange : 0);
    for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++)
      if (mh(u.x, u.y, c, r) <= rng && !(c === u.x && r === u.y)) cells.push({ x: c, y: r });
    return cells;
  },

  // ── 함정 체크 ──
  chkTrap(u) {
    const S = GameStore;
    const enemy = u.team === 'ally' ? 'enemy' : 'ally';
    const trap = S.traps.find(tr => tr.x === u.x && tr.y === u.y && tr.team === enemy);
    if (trap) {
      const trapStun = trap.stun || 2;
      u.hp = Math.max(0, u.hp - trap.dmg);
      BuffSystem.apply(u, { type: BuffType.STUN, duration: trapStun, icon: '⚡', source: 'trap' });
      S.traps = S.traps.filter(tr2 => tr2 !== trap);
      EventBus.emit('trap_triggered', { unit: u, trap, damage: trap.dmg, stun: trapStun });
      return true;
    }
    return false;
  },

  // ── 스피어월 체크 ──
  chkSpearwall(enemy) {
    if (enemy.team !== 'enemy' || enemy.hp <= 0) return;
    const lancers = GameStore.units.filter(u =>
      u.team === 'ally' && u.hp > 0 && u.skillLv && u.skillLv['lancer_spearwall'] >= 1 &&
      !u._spearwallUsed && !BuffSystem.has(u, BuffType.STUN) && !BuffSystem.has(u, BuffType.FREEZE) &&
      mh(u.x, u.y, enemy.x, enemy.y) <= u.range
    );
    if (lancers.length) {
      const l = lancers[0]; l._spearwallUsed = true;
      const dmg = Math.max(1, Math.round(l.atk * 0.5) - enemy.def);
      enemy.hp = Math.max(0, enemy.hp - dmg);
      EventBus.emit('unit_attacked', { attacker: l, target: enemy, damage: dmg, isSpearwall: true });
      if (enemy.hp <= 0) EventBus.emit('unit_killed', { killer: l, target: enemy });
    }
  },

  // ── 전장 안개 시야 계산 ──
  calcFOW() {
    const S = GameStore;
    S.fogVisible.clear();
    UnitManager.alive('ally').forEach(u => {
      const vision = u.move + 1;
      for (let r = 0; r < ROWS; r++)
        for (let c = 0; c < COLS; c++)
          if (mh(u.x, u.y, c, r) <= vision) S.fogVisible.add(c + ',' + r);
    });
  },

  // ── 레이아웃 ──
  layWorld() {
    const d = this.vDim(), wW = (d.c + d.r) * TW + 4, wH = (d.c + d.r) * TH + 80;
    const w = document.getElementById('iso-world');
    w.style.width = wW + 'px'; w.style.height = wH + 'px';
    const ct = document.getElementById('map-container'), cW = ct.clientWidth, cH = ct.clientHeight;
    w.style.left = Math.max(0, (cW - wW) / 2) + 'px'; w.style.top = Math.max(0, (cH - wH) / 2) + 'px';
    const cv = document.getElementById('vfx-canvas');
    if (cv) { cv.width = wW; cv.height = wH; }
  },
};
