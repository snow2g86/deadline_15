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
        await slE(200);
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
        await slE(300);
        UnitManager.rmDead();
        Renderer.rUnits();
        return true;
      }
    }

    return false;
  },

  // ── 전술 이동 점수 ──
  // 후보 칸 m에서: 공격 가능한(엄호 안 된) 아군이 있으면 가점 + 그 공격의 전술 보너스만큼 추가,
  // 상대 기사 제압 구역에 들어가면 감점, 숲(회피)·언덕(원거리)은 가점.
  // AI_MISTAKE_CHANCE 확률로 전술 판단을 약하게 해 항상 완벽하지는 않게 한다.
  _tacticScore(u, m, al) {
    const S = GameStore;
    const tile = S.ter[m.y] && S.ter[m.y][m.x];
    const me = { id: u.id, team: u.team, cls: u.cls, x: m.x, y: m.y };
    const rng = u.range + (tile === 'hill' && u.range > 1 ? TACTIC.highRange : 0);
    let best = -1;
    for (const a of al) {
      if (a.hp <= 0 || isStealthed(a) || mh(m.x, m.y, a.x, a.y) > rng) continue;
      if (UnitManager.coverOf(me, a) || UnitManager.interceptOf(me, a)) continue;
      const tb = UnitManager.tacticBonus(me, a);
      const killable = a.hp <= Math.max(1, Math.round((u.atk - a.def) * tb.mul));
      best = Math.max(best, (tb.mul - 1) * 100 + (killable ? 25 : 0));
    }
    let s = best >= 0 ? 40 + best : 0;
    if (UnitManager.inZoc(u, m.x, m.y) && best < 0) s -= 15;  // 공격도 못 하면서 발만 묶이는 칸
    if (tile === 'forest') s += 5;
    if (tile === 'hill' && u.range > 1) s += 8;
    if (tile === 'shallow') s -= 8;                       // 여울: 피해 증가
    // 상대가 경계 중이면 그 사거리 안 칸은 피함 (공격할 수 없는 칸일 때만)
    if (best < 0 && GameStore.units.some(a => a.hp > 0 && a._overwatch && a.team !== u.team && mh(a.x, a.y, m.x, m.y) <= a.range)) s -= 20;
    if (UnitManager.nearLava(m.x, m.y)) s -= 10;          // 용암 옆: 화상
    // 예고한 대상을 칠 수 있는 칸 우선
    if (u._intent) {
      const it = al.find(a => a.id === u._intent);
      if (it && it.hp > 0 && mh(m.x, m.y, it.x, it.y) <= rng && !UnitManager.coverOf(me, it) && !UnitManager.interceptOf(me, it)) s += 30;
    }
    return Math.random() < AI_MISTAKE_CHANCE ? s * 0.3 : s;
  },

  // ── 행동 예고 ──
  // 각 적이 "지금 행동한다면" 노릴 클랜원을 예측해 e._intent에 기록한다 (무작위 요소 없이 결정적).
  // 이동 가능 칸(진격 제한 포함)에서 엄호되지 않은 클랜원을 칠 수 있으면 처치 가능 > 전술 보너스 > 낮은 HP 순.
  // 실제 AI도 _tryAttack/_tacticScore에서 이 대상을 우선하므로 예고가 대체로 맞는다.
  planIntents() {
    const S = GameStore;
    const al = UnitManager.alive('ally').filter(a => !isStealthed(a));
    S.units.forEach(e => {
      if (e.team !== 'enemy') return;
      e._intent = null;
      if (e.hp <= 0 || !al.length || UnitManager.isCC(e)) return;
      const profile = AI_PROFILES[e.cls] || AI_PROFILES.novice;
      if (profile.targetPriority === 'never' || (profile.avoidCombat && e.hp > e.mhp * 0.7)) return;
      const o = e.origSpawn || { x: e.x, y: e.y };
      let lim = S.cStage && S.cStage.style === 'defense' ? 15 : 5;
      if (profile.style === 'defensive') lim = S.cStage && S.cStage.style === 'defense' ? 12 : 3;
      if (profile.style === 'support') lim = S.cStage && S.cStage.style === 'defense' ? 10 : 2;
      const canMove = !BuffSystem.has(e, BuffType.ROOT) && !(e._rootedTurns > 0) && (e.isBoss || mh(e.x, e.y, o.x, o.y) < lim);
      const spots = [{ x: e.x, y: e.y }].concat(canMove
        ? Grid.eMvCells(e).filter(m => e.isBoss || mh(m.x, m.y, o.x, o.y) <= lim) : []);
      let best = null, bs = -Infinity;
      for (const p of spots) {
        const tile = S.ter[p.y] && S.ter[p.y][p.x];
        const rng = e.range + (tile === 'hill' && e.range > 1 ? TACTIC.highRange : 0);
        const me = { id: e.id, team: e.team, cls: e.cls, x: p.x, y: p.y };
        for (const a of al) {
          if (mh(p.x, p.y, a.x, a.y) > rng || UnitManager.coverOf(me, a) || UnitManager.interceptOf(me, a)) continue;
          const tb = UnitManager.tacticBonus(me, a);
          const dmg = Math.max(1, Math.round((e.atk - a.def) * tb.mul));
          const sc = (a.hp <= dmg ? 1000 : 0) + (tb.mul - 1) * 100 - a.hp / a.mhp * 50 - (p.x === e.x && p.y === e.y ? 0 : 1);
          if (sc > bs) { bs = sc; best = a; }
        }
      }
      e._intent = best ? best.id : null;
    });
  },

  // ── 사거리 내 아군(적 입장) 탐색 ──
  _visibleAllies(u) {
    const all = Grid.atkCells(u).filter(c => {
      const v = UnitManager.uAt(c.x, c.y);
      return v && v.team === 'ally' && !isStealthed(v) && !UnitManager.coverOf(u, v); // 엄호된 아군은 노릴 수 없음
    }).map(c => UnitManager.uAt(c.x, c.y));
    // 원거리: 기사에게 막히지 않는 대상이 있으면 그쪽만 (없으면 막히더라도 쏨 → 기사가 대신 맞음)
    const clear = all.filter(v => !UnitManager.interceptOf(u, v));
    return clear.length ? clear : all;
  },

  // ── 공격 시도 ──
  async _tryAttack(u, targets, profile) {
    if (!targets.length || profile.targetPriority === 'never') return false;
    if (await this.tryUseSkill(u, profile)) return true;
    // 처치 가능하거나 전술 보너스가 큰 대상이 있으면 우선 (실수 확률만큼은 평소 우선순위대로)
    let target = null;
    // 예고한 대상을 칠 수 있으면 그대로 (플레이어가 예고를 보고 대응할 수 있게)
    if (u._intent) target = targets.find(a => a.id === u._intent) || null;
    if (!target && Math.random() >= AI_MISTAKE_CHANCE) {
      let bs = 29;
      for (const a of targets) {
        const tb = UnitManager.tacticBonus(u, a);
        const sc = (tb.mul - 1) * 100 + (a.hp <= Math.max(1, Math.round((u.atk - a.def) * tb.mul)) ? 100 : 0);
        if (sc > bs) { bs = sc; target = a; }
      }
    }
    target = target || this.selectTarget(u, targets, profile);
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

    if (this.tryGateAtk(u)) { await slE(250); return; }
    if (await this.tryWallClimb(u)) return;

    await this.eMv(u, al);
    if (FSM.is(BattleState.BATTLE_END) || u.hp <= 0) return; // 이동 중 함정·경계에 쓰러짐
    if (profile.avoidCombat && u.hp > u.mhp * 0.7) return;

    // 이동 후 공격 시도
    await slE(200);
    if (await this._tryAttack(u, this._visibleAllies(u), profile)) return;

    // 이동 후에도 공격 불가 시 공성아이템 시도
    if (await this.trySiegeItemUse(u)) return;
    if (this.tryGateAtk(u)) return;
    // 방어형(기사·창병)은 칠 대상이 없으면 방어 태세
    if (profile.style === 'defensive') { u._defend = true; Renderer.floatT(u.x, u.y, t('messages.defend_on'), 'heal'); }
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
      await slE(340);
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
    await slE(250);
    await this.eAtk(a, tgt);
    await slE(tgt.hp <= 0 ? 500 : 300);
  },

  // ── 적 공격 실행 ──
  async eAtk(a, tgt) {
    // 투사체 차단: 지나가는 길에 클랜원 기사가 있으면 기사가 대신 맞음
    const blk = UnitManager.interceptOf(a, tgt);
    if (blk) { tgt = blk; Renderer.floatT(blk.x, blk.y, t('messages.intercepted'), 'tactic'); }
    // 회피 체크 (공격받는 쪽 기준: 공성아이템 회피 / 숲 지형)
    if (UnitManager.rollEvade(tgt)) {
      VFX.faceDir(a.id, tgt.x - a.x, tgt.y - a.y); VFX.playAtkMotion(a, tgt); // 휘두르지만 빗나감
      EventBus.emit('evasion', { unit: tgt });
      return;
    }

    // 브로울러 카운터 체크
    const bCounter = tgt.skillLv && tgt.skillLv['brawler_counter'] >= 1
      && !UnitManager.isCC(tgt) && mh(tgt.x, tgt.y, a.x, a.y) <= tgt.range && Math.random() < 0.3;
    let supKiller = null;
    // 후속 연출(지원·반격·사망 처리)은 공격이 실제로 맞는 순간(시트 타격 프레임 + 투사체 비행) 뒤로
    const hd = VFX.atkHitDelay(a.cls, a), t0 = performance.now();

    if (bCounter) {
      await slE(420);
      const cdmg = Math.max(1, Math.round(tgt.atk * 0.5) - a.def);
      a.hp = Math.max(0, a.hp - cdmg);
      EventBus.emit('unit_attacked', { attacker: tgt, target: a, damage: cdmg, counter: true });
    } else {
      let dmg = calcDmg(a, tgt);
      if (blk) dmg = GearFX.intercept(blk, Math.max(1, Math.round(dmg * TACTICS_ACT.interceptMul)));
      // 방어막: 공격받는 쪽 피해 50%
      if (UnitManager.shieldMul(tgt) < 1) {
        dmg = Math.max(1, Math.round(dmg * UnitManager.shieldMul(tgt)));
        EventBus.emit('shield_active', { unit: tgt });
      }
      const actual = tgt.team === 'ally' ? applyDmgToAlly(tgt, dmg, G) : (tgt.hp = Math.max(0, tgt.hp - dmg), tgt);
      EventBus.emit('unit_attacked', { attacker: a, target: actual, damage: dmg, counter: false });
      if (a.cls === 'mage' && !blk) {
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
      procFury(a, tgt, G);

      // 지원 공격 (대상 옆의 같은 편이 확률로 추가 타격)
      const sup = UnitManager.rollSupport(a, tgt);
      if (sup) { await sl(Math.max(380, hd + 140)); UnitManager.emitSupport(sup); if (tgt.hp <= 0) supKiller = sup.sp; }

      // 반격
      if (tgt.hp > 0 && a.hp > 0 && mh(tgt.x, tgt.y, a.x, a.y) <= tgt.range && !UnitManager.isCC(tgt)) {
        await sl(Math.max(420, hd + 180 - (performance.now() - t0)));
        const cdmg = Math.max(1, Math.round(EnchantFX.modDamage(tgt, a, calcDmg(tgt, a)) * GearFX.counterMul(tgt)));   // 클랜원 반격에도 공격용 마법부여·장비 반격 강화
        a.hp = Math.max(0, a.hp - cdmg);
        EventBus.emit('unit_attacked', { attacker: tgt, target: a, damage: cdmg, counter: true });
        EnchantFX.afterHit(tgt, a, cdmg);
        procFury(tgt, a, G);
      }
    }

    // 사망 처리 — 투사체가 아직 날아가는 중이면 맞을 때까지 기다렸다가 정리
    const left = hd + 120 - (performance.now() - t0);
    if (tgt.hp <= 0 && left > 0) await sl(left);
    if (tgt.hp <= 0) {
      EventBus.emit('unit_killed', { killer: supKiller || a, target: tgt });
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
    await slE(340);
    if (u._cursed && typeof curseMoveTick === 'function') curseMoveTick(u); // 쇠약의 저주: 적도 이동할 때마다 피해
    Grid.chkTrap(u);
    Grid.chkSpearwall(u);
    await this._overwatch(u);
    if (u.hp <= 0) {
      EventBus.emit('unit_killed', { killer: null, target: u, reason: 'trap_or_spearwall' });
      UnitManager.rmDead();
      Renderer.rUnits();
    }
  },

  // ── 경계 발동: 이동을 마친 e가 경계 중인 상대의 사거리 안이면 선제 공격 (한 번만) ──
  async _overwatch(e) {
    if (e.hp <= 0 || isStealthed(e)) return;
    const w = GameStore.units.find(a => a.hp > 0 && a._overwatch && a.team !== e.team && !UnitManager.isCC(a) &&
      Grid.atkCells(a).some(c => c.x === e.x && c.y === e.y) && !UnitManager.coverOf(a, e));
    if (!w) return;
    w._overwatch = false;
    Renderer.floatT(w.x, w.y, t('messages.overwatch_fire'), 'tactic');
    VFX.faceDir(w.id, e.x - w.x, e.y - w.y);
    const blk = UnitManager.interceptOf(w, e), hit = blk || e;   // 투사체 차단: 길목의 기사가 대신 맞음
    if (blk) Renderer.floatT(blk.x, blk.y, t('messages.intercepted'), 'tactic');
    const dmg = Math.max(1, Math.round(EnchantFX.modDamage(w, hit, calcDmg(w, hit)) * TACTICS_ACT.overwatchMul * (blk ? TACTICS_ACT.interceptMul : 1) * UnitManager.shieldMul(hit)));
    hit.hp = Math.max(0, hit.hp - dmg);
    EventBus.emit('unit_attacked', { attacker: w, target: hit, damage: dmg });
    EnchantFX.afterHit(w, hit, dmg);
    await sl(Math.max(550, VFX.atkHitDelay(w.cls, w) + 150));
    if (hit.hp <= 0) { EventBus.emit('unit_killed', { killer: w, target: hit }); UnitManager.rmDead(); Renderer.rUnits(); TurnManager.chkEnd(); }
  },

  // ── 돌파 체크 ──
  _checkBreach(u, ny) {
    if (ny === 14) { this.onBreach(u); return true; }
    return false;
  },

  // ── 적 이동 ──
  async eMv(u, al) {
    const S = GameStore;
    if (BuffSystem.has(u, BuffType.ROOT) || u._rootedTurns > 0) { // 영혼 쇄도는 _rootedTurns 필드로 속박
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
        score += this._tacticScore(u, m, al);
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
      s += this._tacticScore(u, c, al);
      if (s > bs) { bs = s; bc = c; }
    }
    if (bc) {
      await this._moveUnit(u, bc.x, bc.y);
      if (u.hp <= 0) return;
      this._checkBreach(u, bc.y);
    }
  },
};
