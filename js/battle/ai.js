// ═══════════════════════════════════════════
//  battle/ai.js — AI decision making, enemy combat & movement
// ═══════════════════════════════════════════

const AI = {
  // ── 타겟 선택 ──
  selectTarget(u, inRange, profile) {
    if (!inRange.length) return null;
    if (Math.random() < AI_MISTAKE_CHANCE) {
      return inRange[Math.floor(Math.random() * inRange.length)];
    }
    const p = profile.targetPriority;
    if (p === 'low_hp') {
      const kl = inRange.filter(a => a.hp <= Math.max(1, u.atk - a.def));
      if (kl.length) return kl.sort((a, b) => a.hp - b.hp)[0];
      return inRange.sort((a, b) => a.hp - b.hp)[0];
    }
    if (p === 'nearest') {
      return inRange.sort((a, b) => mh(u.x, u.y, a.x, a.y) - mh(u.x, u.y, b.x, b.y))[0];
    }
    if (p === 'nearest_threat') {
      const o = u.origSpawn || { x: u.x, y: u.y };
      return inRange.sort((a, b) => mh(o.x, o.y, a.x, a.y) - mh(o.x, o.y, b.x, b.y))[0];
    }
    if (p === 'random_weak') {
      const s = [...inRange].sort((a, b) => a.hp - b.hp);
      const w = s.slice(0, Math.ceil(s.length / 2));
      return w[Math.floor(Math.random() * w.length)];
    }
    if (p === 'cluster') {
      let bt = null, bn = 0;
      for (const tgt of inRange) {
        const n = UnitManager.alive('ally').filter(a => a.id !== tgt.id && mh(tgt.x, tgt.y, a.x, a.y) <= 2).length;
        if (n > bn) { bn = n; bt = tgt; }
      }
      return bt || inRange[0];
    }
    return inRange[Math.floor(Math.random() * inRange.length)];
  },

  // ── 스킬 사용 시도 ──
  async tryUseSkill(u, profile) {
    if (!profile.skillUseProbability || Math.random() > profile.skillUseProbability) return false;
    const al = UnitManager.alive('ally');
    if (!al.length) return false;

    // Warrior 강타
    if (u.cls === 'warrior' && u.res >= 3) {
      const inR = Grid.atkCells(u)
        .filter(c => { const v = UnitManager.uAt(c.x, c.y); return v && v.team === 'ally' && !isStealthed(v); })
        .map(c => UnitManager.uAt(c.x, c.y));
      for (const tgt of inR) {
        const dmg = Math.max(1, Math.round(u.atk * 1.5 - tgt.def));
        if (tgt.hp <= dmg) {
          u.res -= 3;
          tgt.hp = 0;
          EventBus.emit('unit_attacked', { attacker: u, target: tgt, damage: dmg, counter: false });
          EventBus.emit('unit_killed', { killer: u, target: tgt });
          UnitManager.rmDead();
          u.ha = true;
          Renderer.rUnits();
          return true;
        }
      }
    }

    // Brawler 무장해제
    if (u.cls === 'brawler' && u.res >= 30) {
      const inR = al.filter(v => mh(u.x, u.y, v.x, v.y) <= 1);
      const highAtk = inR.filter(v => v.atk >= 25 && !BuffSystem.has(v, BuffType.DISARM));
      if (highAtk.length) {
        const tgt = highAtk[0];
        u.res -= 30;
        BuffSystem.apply(tgt, { type: BuffType.DISARM, duration: 3, icon: '🤛', source: 'brawler_disarm' });
        EventBus.emit('skill_used', { caster: u, skill: 'brawler_disarm', target: tgt });
        u.ha = true;
        await sl(200);
        return true;
      }
    }

    // Mage 화염폭발
    if (u.cls === 'mage' && u.res >= 40) {
      let targetCell = null, maxCluster = 0;
      for (let y = u.y - 1; y <= u.y + 1; y++) {
        for (let x = u.x - 1; x <= u.x + 1; x++) {
          if (x === u.x && y === u.y) continue;
          const cnt = al.filter(a => !isStealthed(a) && Math.abs(a.x - x) <= 1 && Math.abs(a.y - y) <= 1).length;
          if (cnt >= 2 && cnt > maxCluster) { maxCluster = cnt; targetCell = { x, y }; }
        }
      }
      if (targetCell) {
        u.res -= 40;
        for (let y = targetCell.y - 1; y <= targetCell.y + 1; y++) {
          for (let x = targetCell.x - 1; x <= targetCell.x + 1; x++) {
            const tgt = UnitManager.uAt(x, y);
            if (tgt && tgt.team === 'ally' && !isStealthed(tgt)) {
              const dmg = calcDmg(u, tgt);
              tgt.hp = Math.max(0, tgt.hp - dmg);
              EventBus.emit('unit_attacked', { attacker: u, target: tgt, damage: dmg, counter: false, isAoE: true });
              if (tgt.hp <= 0) EventBus.emit('unit_killed', { killer: u, target: tgt });
            }
          }
        }
        EventBus.emit('skill_used', { caster: u, skill: 'mage_fireball', targetCell });
        u.ha = true;
        await sl(300);
        UnitManager.rmDead();
        Renderer.rUnits();
        return true;
      }
    }

    return false;
  },

  // ── 사거리 내 아군(적 입장) 탐색 ──
  _visibleAllies(u) {
    return Grid.atkCells(u).filter(c => {
      const v = UnitManager.uAt(c.x, c.y);
      return v && v.team === 'ally' && !isStealthed(v);
    }).map(c => UnitManager.uAt(c.x, c.y));
  },

  // ── 공격 시도 ──
  async _tryAttack(u, targets, profile) {
    if (!targets.length || profile.targetPriority === 'never') return false;
    if (await this.tryUseSkill(u, profile)) return true;
    const target = this.selectTarget(u, targets, profile);
    if (target) { await this.eAtkAsync(u, target); return true; }
    return false;
  },

  // ── 메인 AI 진입점 ──
  async eAI(u) {
    const al = UnitManager.alive('ally');
    if (!al.length && !TurnManager.hasAllyWall()) return;
    const profile = AI_PROFILES[u.cls] || AI_PROFILES.novice;

    if (profile.avoidCombat && u.hp > u.mhp * 0.7) { await this.eMv(u, al); return; }

    // 이동 전 공격 시도
    if (await this._tryAttack(u, this._visibleAllies(u), profile)) return;

    if (this.tryGateAtk(u)) { await sl(250); return; }
    if (await this.tryWallClimb(u)) return;

    await this.eMv(u, al);
    if (FSM.is(BattleState.BATTLE_END)) return;
    if (profile.avoidCombat && u.hp > u.mhp * 0.7) return;

    // 이동 후 공격 시도
    await sl(200);
    if (await this._tryAttack(u, this._visibleAllies(u), profile)) return;

    // 이동 후에도 공격 불가 시 공성아이템 시도
    if (await this.trySiegeItemUse(u)) return;
    this.tryGateAtk(u);
  },

  // ── 상황 분석 ──
  analyzeSituation(u) {
    const al = UnitManager.alive('ally');
    const hpPct = u.hp / u.mhp;
    const nearbyAllies = al.filter(a => !isStealthed(a) && mh(u.x, u.y, a.x, a.y) <= 2).length;
    const moveOptions = Grid.eMvCells(u).length;
    let nearbyTerrain = 0;
    for (const [dx, dy] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) {
      const nx = u.x + dx, ny = u.y + dy;
      if (nx >= 0 && nx < COLS && ny >= 0 && ny < ROWS) {
        const tile = GameStore.ter[ny][nx];
        if (tile === 'wall' || tile === 'gate' || tile === 'rock') nearbyTerrain++;
      }
    }
    let situationType = 'safe';
    if (hpPct < 0.3) situationType = 'weakened';
    else if (nearbyAllies >= 3) situationType = 'surrounded';
    else if (moveOptions === 0) situationType = 'blocked';
    else if (nearbyAllies > 0) situationType = 'distant';
    const severity = (1 - hpPct) * 0.4 + (nearbyAllies / 5) * 0.4 + (1 - moveOptions / 4) * 0.2;
    return { type: situationType, severity: Math.max(0, Math.min(1, severity)), blockCount: 4 - moveOptions, nearbyAllies, hpPercent: hpPct, nearbyTerrain };
  },

  // ── 공성아이템 선택 ──
  selectSiegeItem(u, situation) {
    if (!u.siegeItems || !u.siegeItems.length) return null;
    const available = u.siegeItems.filter(i => i.cooldown === 0);
    if (!available.length) return null;
    const priorityMap = {
      blocked: { bomb: 90, ladder: 70, detour: 80 },
      distant: { detour: 80, bomb: 60, ladder: 50 },
      weakened: { shield: 100, evasion: 80 },
      surrounded: { evasion: 90, bomb: 70, detour: 60 },
      safe: {},
    };
    const priors = priorityMap[situation.type] || {};
    let best = null, bestScore = -1;
    for (const item of available) {
      const score = (priors[item.type] || 0) + Math.random() * 10;
      if (score > bestScore) { bestScore = score; best = item; }
    }
    return best;
  },

  // ── 폭탄 사용 ──
  _siegeBomb(u) {
    const S = GameStore;
    let best = null, bestD = Infinity;
    for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
      const d = mh(u.x, u.y, c, r);
      if (d < 1 || d > 3) continue;
      const tile = S.ter[r][c];
      if (tile === 'wall' || tile === 'gate' || tile === 'rock') {
        if (d < bestD) { bestD = d; best = { x: c, y: r }; }
      }
    }
    if (!best) return false;
    S.ter[best.y][best.x] = 'plain';
    const wk = best.x + ',' + best.y;
    if (S.wallHP[wk]) S.wallHP[wk] = 0;
    if (S.gateHP[wk]) S.gateHP[wk] = 0;
    EventBus.emit('siege_used', { unit: u, type: 'bomb', target: best });
    Renderer.rTer();
    return true;
  },

  // ── 공성아이템 사용 ──
  async useSiegeItem(u, item) {
    try {
      const actions = {
        bomb: () => this._siegeBomb(u),
        shield: () => {
          BuffSystem.apply(u, { type: BuffType.SHIELD, duration: 3, value: 0.5, icon: '🛡️', source: 'siege' });
          EventBus.emit('siege_used', { unit: u, type: 'shield' });
          return true;
        },
        evasion: () => {
          BuffSystem.apply(u, { type: BuffType.EVASION, duration: 1, value: 0.3, icon: '⚡', source: 'siege' });
          EventBus.emit('siege_used', { unit: u, type: 'evasion' });
          return true;
        },
      };
      const fn = actions[item.type];
      if (fn) {
        const success = await fn();
        if (success) { item.cooldown = 3; return true; }
      }
    } catch (e) {}
    return false;
  },

  // ── 공성아이템 사용 시도 ──
  async trySiegeItemUse(u) {
    if (!u.siegeItems || !u.siegeItems.length) return false;
    const situation = this.analyzeSituation(u);
    if (situation.type === 'blocked') {
      const item = this.selectSiegeItem(u, situation);
      if (!item) return false;
      return await this.useSiegeItem(u, item);
    }
    if (situation.severity < 0.3) return false;
    const item = this.selectSiegeItem(u, situation);
    if (!item) return false;
    return await this.useSiegeItem(u, item);
  },

  // ── 게이트 공격 ──
  tryGateAtk(u) {
    const S = GameStore;
    for (const [dx, dy] of [[0, 1], [0, -1], [-1, 0], [1, 0]]) {
      const nx = u.x + dx, ny = u.y + dy;
      if (ny !== 14 || nx < 0 || nx >= COLS) continue;
      const tr = S.ter[ny][nx];
      if (tr !== 'gate') continue;
      const k = nx + ',' + ny;
      if (!S.gateHP[k] || S.gateHP[k] <= 0) continue;
      S.gateHP[k]--;
      EventBus.emit('gate_attacked', { unit: u, x: nx, y: ny, hp: S.gateHP[k] });
      if (S.gateHP[k] <= 0) {
        S.ter[ny][nx] = 'plain';
        EventBus.emit('gate_destroyed', { unit: u, x: nx, y: ny });
      }
      Renderer.rTer();
      return true;
    }
    return false;
  },

  // ── 벽 등반 ──
  async tryWallClimb(u) {
    for (const [dx, dy] of [[0, 1], [0, -1], [-1, 0], [1, 0]]) {
      const nx = u.x + dx, ny = u.y + dy;
      if (ny !== 14 || nx < 0 || nx >= COLS) continue;
      const tr = GameStore.ter[ny][nx];
      if (tr !== 'wall') continue;
      if (Math.random() > 0.3) continue;
      const ox = u.x, oy = u.y;
      u.x = nx; u.y = ny;
      EventBus.emit('unit_moved', { unit: u, from: { x: ox, y: oy }, to: { x: nx, y: ny } });
      await sl(340);
      this.onBreach(u);
      return true;
    }
    return false;
  },

  // ── 돌파 ──
  onBreach(u) {
    const S = GameStore;
    S.breached++;
    const s = S.cStage;
    if (!s) return;
    const limit = Math.ceil(s.tot / 4);
    EventBus.emit('breach', { unit: u, count: S.breached, limit });
  },

  // ── 적 공격 (비동기 래퍼) ──
  async eAtkAsync(a, tgt) {
    EventBus.emit('camera_focus', { unit: tgt });
    await sl(250);
    await this.eAtk(a, tgt);
    await sl(tgt.hp <= 0 ? 500 : 300);
  },

  // ── 적 공격 실행 ──
  async eAtk(a, tgt) {
    // 회피 체크 (공성 아이템)
    if (BuffSystem.has(a, BuffType.EVASION) && Math.random() < 0.3) {
      BuffSystem.remove(a, BuffType.EVASION, 'siege');
      EventBus.emit('evasion', { unit: a });
      return;
    }

    // 브로울러 카운터 체크
    const bCounter = tgt.skillLv && tgt.skillLv['brawler_counter'] >= 1
      && !UnitManager.isCC(tgt) && mh(tgt.x, tgt.y, a.x, a.y) <= tgt.range && Math.random() < 0.3;

    if (bCounter) {
      await sl(420);
      const cdmg = Math.max(1, Math.round(tgt.atk * 0.5) - a.def);
      a.hp = Math.max(0, a.hp - cdmg);
      EventBus.emit('unit_attacked', { attacker: tgt, target: a, damage: cdmg, counter: true });
    } else {
      let dmg = calcDmg(a, tgt);
      // 방어막 감소
      if (BuffSystem.has(a, BuffType.SHIELD)) {
        dmg = Math.max(1, Math.round(dmg * 0.5));
        EventBus.emit('shield_active', { unit: a });
      }
      const actual = tgt.team === 'ally' ? applyDmgToAlly(tgt, dmg, G) : (tgt.hp = Math.max(0, tgt.hp - dmg), tgt);
      EventBus.emit('unit_attacked', { attacker: a, target: actual, damage: dmg, counter: false });
      if (a.cls === 'mage') {
        const splDmg = Math.max(1, Math.round(dmg * 0.5));
        for (const [dx, dy] of [[0,-1],[0,1],[-1,0],[1,0]]) {
          const su = UnitManager.uAt(tgt.x + dx, tgt.y + dy);
          if (su && su.hp > 0 && su.team === tgt.team && su.id !== tgt.id) {
            su.hp = Math.max(0, su.hp - splDmg);
            EventBus.emit('unit_attacked', { attacker: a, target: su, damage: splDmg, isSplash: true });
            if (su.hp <= 0) EventBus.emit('unit_killed', { killer: a, target: su });
          }
        }
      }
      if (BuffSystem.has(a, BuffType.FURY_BUFF)) {
        EventBus.emit('fury_triggered', { unit: a });
      }
      procFury(a, tgt);

      // 반격
      if (tgt.hp > 0 && a.hp > 0 && mh(tgt.x, tgt.y, a.x, a.y) <= tgt.range && !UnitManager.isCC(tgt)) {
        await sl(420);
        const cdmg = calcDmg(tgt, a);
        a.hp = Math.max(0, a.hp - cdmg);
        EventBus.emit('unit_attacked', { attacker: tgt, target: a, damage: cdmg, counter: true });
        procFury(tgt, a);
      }
    }

    // 사망 처리
    if (tgt.hp <= 0) {
      EventBus.emit('unit_killed', { killer: a, target: tgt });
      UnitManager.rmDead();
      Renderer.rUnits();
      TurnManager.chkEnd();
    } else if (a.hp <= 0) {
      EventBus.emit('unit_killed', { killer: tgt, target: a });
      UnitManager.rmDead();
      Renderer.rUnits();
      TurnManager.chkEnd();
    } else {
      Renderer.rUnits();
    }
  },

  // ── 유닛 이동 + 함정/스피어월 체크 ──
  async _moveUnit(u, nx, ny) {
    const ox = u.x, oy = u.y;
    u.x = nx; u.y = ny;
    EventBus.emit('unit_moved', { unit: u, from: { x: ox, y: oy }, to: { x: nx, y: ny } });
    await sl(340);
    Grid.chkTrap(u);
    Grid.chkSpearwall(u);
    if (u.hp <= 0) {
      EventBus.emit('unit_killed', { killer: null, target: u, reason: 'trap_or_spearwall' });
      UnitManager.rmDead();
      Renderer.rUnits();
    }
  },

  // ── 돌파 체크 ──
  _checkBreach(u, ny) {
    if (ny === 14) { this.onBreach(u); return true; }
    return false;
  },

  // ── 적 이동 ──
  async eMv(u, al) {
    const S = GameStore;
    if (BuffSystem.has(u, BuffType.ROOT)) {
      EventBus.emit('root_blocked', { unit: u });
      return;
    }
    const origPos = u.origSpawn || { x: u.x, y: u.y };
    const profile = AI_PROFILES[u.cls] || AI_PROFILES.novice;
    const hpPct = u.hp / u.mhp;

    // 후퇴
    const shouldRetreat = hpPct < profile.retreatThreshold && Math.random() < 0.3;
    if (shouldRetreat && !u.isBoss) {
      const mc = Grid.eMvCells(u); if (!mc.length) return;
      let bestMove = null, bestDist = Infinity;
      for (const m of mc) {
        const d = mh(m.x, m.y, origPos.x, origPos.y);
        if (d < bestDist) { bestDist = d; bestMove = m; }
      }
      if (bestMove && mh(bestMove.x, bestMove.y, origPos.x, origPos.y) < mh(u.x, u.y, origPos.x, origPos.y)) {
        await this._moveUnit(u, bestMove.x, bestMove.y);
        EventBus.emit('retreat', { unit: u });
        return;
      }
    }

    // 진격 제한
    let advLimit = S.cStage?.style === 'defense' ? 15 : 5;
    if (profile.style === 'defensive') advLimit = S.cStage?.style === 'defense' ? 12 : 3;
    if (profile.style === 'support') advLimit = S.cStage?.style === 'defense' ? 10 : 2;
    const advDist = mh(u.x, u.y, origPos.x, origPos.y);

    // 방어 스테이지에서 집단 행동
    if (S.cStage?.style === 'defense' && !u.isBoss) {
      const allies = UnitManager.alive('enemy').filter(e => e.id !== u.id && !e.isBoss);
      if (allies.length > 0) {
        const avgAllyY = allies.reduce((sum, a) => sum + a.y, 0) / allies.length;
        if (u.y > avgAllyY + 3) return;
        const nearestAllyDist = Math.min(...allies.map(a => mh(u.x, u.y, a.x, a.y)));
        if (nearestAllyDist > 5) advLimit = Math.min(advLimit, advDist + 2);
      }
    }

    if (advDist >= advLimit && !u.isBoss) return;

    const mc = Grid.eMvCells(u); if (!mc.length) return;
    const validMoves = mc.filter(m => mh(m.x, m.y, origPos.x, origPos.y) <= advLimit || u.isBoss);
    if (!validMoves.length) return;

    // 가장 가까운 아군(적 시점) 찾기
    let bt = null, bd = Infinity;
    for (const a of al) {
      if (isStealthed(a)) continue;
      const d = mh(u.x, u.y, a.x, a.y);
      if (d < bd) { bd = d; bt = a; }
    }

    // 암살자 특수 이동
    if (u.cls === 'assassin') {
      let bestMove = null, bestScore = -Infinity;
      for (const m of validMoves) {
        const tr = S.ter[m.y] ? S.ter[m.y][m.x] : null;
        let score = 0;
        if (tr === 'forest') score += 50;
        if (bt) score += (mh(u.x, u.y, bt.x, bt.y) - mh(m.x, m.y, bt.x, bt.y)) * 10;
        score += (m.y - u.y) * 3;
        if (score > bestScore) { bestScore = score; bestMove = m; }
      }
      if (bestMove) {
        await this._moveUnit(u, bestMove.x, bestMove.y);
        if (u.hp <= 0) return;
        this._checkBreach(u, bestMove.y);
        return;
      }
    }

    // 가드 모드
    if (profile.guardMode && !u.isBoss) {
      const allies = UnitManager.alive('enemy').filter(e => e.id !== u.id);
      if (allies.length) {
        let bestMove = null, bestScore = -Infinity;
        for (const m of validMoves) {
          let score = 0;
          const avgAllyDist = allies.reduce((sum, a) => sum + mh(m.x, m.y, a.x, a.y), 0) / allies.length;
          score -= avgAllyDist * 5;
          score -= mh(m.x, m.y, origPos.x, origPos.y) * profile.advanceBonus;
          if (score > bestScore) { bestScore = score; bestMove = m; }
        }
        if (bestMove) {
          await this._moveUnit(u, bestMove.x, bestMove.y);
          return;
        }
      }
    }

    // 거리 유지 (원거리 유닛)
    let cbt = null, cbd = Infinity;
    for (const a of al) {
      if (isStealthed(a)) continue;
      const d = mh(u.x, u.y, a.x, a.y);
      if (d < cbd) { cbd = d; cbt = a; }
    }
    if (profile.keepDistance && cbt && mh(u.x, u.y, cbt.x, cbt.y) <= 2) {
      let bestMove = null, bestDist = 0;
      for (const m of validMoves) {
        const dist = mh(m.x, m.y, cbt.x, cbt.y);
        if (dist > bestDist && dist <= u.range) { bestDist = dist; bestMove = m; }
      }
      if (bestMove && bestDist > mh(u.x, u.y, cbt.x, cbt.y)) {
        await this._moveUnit(u, bestMove.x, bestMove.y);
        return;
      }
    }

    // 게이트 접근 (대상 없거나 먼 경우)
    if (!bt || bd > 8) {
      const gateTarget = { x: u.x <= 4 ? 4 : 5, y: 13 };
      let bc2 = null, bs2 = -Infinity;
      for (const c of validMoves) {
        let s = -(mh(c.x, c.y, gateTarget.x, gateTarget.y)) * 10 + (c.y - u.y) * (5 + profile.advanceBonus);
        if (s > bs2) { bs2 = s; bc2 = c; }
      }
      if (bc2) {
        await this._moveUnit(u, bc2.x, bc2.y);
        return;
      }
    }

    // 기본: 가장 가까운 적(아군 시점) 접근
    let bc = null, bs = -Infinity;
    for (const c of validMoves) {
      let s = 0;
      if (bt) s += (mh(u.x, u.y, bt.x, bt.y) - mh(c.x, c.y, bt.x, bt.y)) * 10;
      s += (c.y - u.y) * (3 + profile.advanceBonus * 0.3);
      if (s > bs) { bs = s; bc = c; }
    }
    if (bc) {
      await this._moveUnit(u, bc.x, bc.y);
      if (u.hp <= 0) return;
      this._checkBreach(u, bc.y);
    }
  },
};
