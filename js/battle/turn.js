// ═══════════════════════════════════════════
//  battle/turn.js — Turn flow, initiative, wave spawn, resource recovery
// ═══════════════════════════════════════════

const TurnManager = {
  // ── 행동력 기반 턴 진행 ──
  advanceTick() {
    const S = GameStore;
    const alive = S.units.filter(u => u.hp > 0);
    alive.forEach(u => { if (!u.actionRec) u.actionRec = 1.0; });
    const ready = alive.filter(u => u.actionPow >= 4.999);
    if (ready.length > 0) return this.getNextUnit();
    const minDelta = Math.min(...alive.map(u => (5 - u.actionPow) / u.actionRec));
    alive.forEach(u => { u.actionPow = Math.round((u.actionPow + u.actionRec * minDelta) * 1000) / 1000; });
    return this.getNextUnit();
  },

  getNextUnit() {
    const ready = GameStore.units.filter(u => u.hp > 0 && u.actionPow >= 4.999);
    if (ready.length === 0) return null;
    return ready.sort((a, b) => b.actionPow - a.actionPow || b.actionRec - a.actionRec)[0];
  },

  // ── 유닛 행동 종료 ──
  endUnitTurn(u) {
    const S = GameStore;
    u.actionPow = Math.max(0, (u.actionPow || 0) - 5);
    u.ha = false; u.hm = false; u.mo = false;

    // 자원 회복
    if (u.resType === 'mana') {
      u.res = Math.min(u.maxRes, u.res + u.resRec);
    } else if (u.resType === 'energy') {
      let rec = u.resRec;
      if (u.cls === 'assassin') {
        const tl = S.ter[u.y] ? S.ter[u.y][u.x] : null;
        if (tl === 'forest') rec *= 2;
      }
      u.res = Math.min(u.maxRes, u.res + rec);
    }

    // BuffSystem 틱
    BuffSystem.tick(u);

    // 하위 호환: 전용 필드 감소
    if (u.stunned > 0) u.stunned--;
    if (u.frozen > 0) u.frozen--;
    if (u.disarmed > 0) u.disarmed--;
    if (u.furyBuff > 0) u.furyBuff--;
    if (u.defBuff > 0) u.defBuff--;
    if (u._tenacityDef) u._tenacityDef = false;
    if (u._bleedTurns > 0 && u._bleedDmg > 0) {
      u.hp = Math.max(1, u.hp - u._bleedDmg);
      EventBus.emit('buff_tick_damage', { unit: u, buff: { type: 'bleed', icon: '🗡️' }, damage: u._bleedDmg });
      u._bleedTurns--;
      if (u._bleedTurns <= 0) u._bleedDmg = 0;
    }
    if (u._phalanxTurns > 0) { u._phalanxTurns--; if (u._phalanxTurns <= 0) u._phalanxDef = 0; }
    if (u._empowerTurns > 0) { u._empowerTurns--; if (u._empowerTurns <= 0) u._empowerMul = 0; }
    if (u._rootedTurns > 0) u._rootedTurns--;
    if (u._sanctuaryTurns > 0 && u._sanctuaryHeal > 0) {
      const heal = u._sanctuaryHeal;
      u.hp = Math.min(u.mhp, u.hp + heal);
      EventBus.emit('buff_tick_heal', { unit: u, buff: { type: 'sanctuary', icon: '✝️' }, heal });
      u._sanctuaryTurns--;
      if (u._sanctuaryTurns <= 0) u._sanctuaryHeal = 0;
    }
    // 구 buffs[] 틱 (포션 등)
    if (u.buffs) {
      for (let i = u.buffs.length - 1; i >= 0; i--) {
        if (u.buffs[i].duration > 0) {
          u.buffs[i].duration--;
          if (u.buffs[i].duration <= 0) u.buffs.splice(i, 1);
        }
      }
    }

    // 소환수 턴 감소
    if (u.isSummon && u.summonTurns !== undefined) {
      u.summonTurns--;
      if (u._empowerTurns > 0) u._empowerTurns--;
      if (u.summonTurns <= 0) {
        u.hp = 0;
        EventBus.emit('unit_killed', { killer: null, target: u, reason: 'unsummon' });
        UnitManager.rmDead();
      }
    }

    // 스피어월 리셋
    if (u._spearwallUsed) u._spearwallUsed = false;

    EventBus.emit('turn_end', { unit: u });
    S.actCount++;
    this.nextAction();
  },

  // ── 웨이브 스폰 ──
  spawnWave() {
    const S = GameStore;
    if (!S.cStage) return;
    const s = S.cStage, rem = s.tot - S.eSpwn;
    if (rem <= 0) return;

    const activeEnemies = S.units.filter(u => u.team === 'enemy' && u.hp > 0).length;
    const maxConcurrent = 20;
    if (activeEnemies >= maxConcurrent) return;

    const cnt = Math.min(s.spw, rem, S.eQ.length, maxConcurrent - activeEnemies);
    if (S.eSpwn === 0 && s.boss) {
      const bu = UnitManager.addUnit('enemy', s.boss.cls, 5, 2);
      if (bu) { bu.isBoss = true; bu.name = s.boss.name; bu.origSpawn = { x: 5, y: 2 }; }
      S.eSpwn++;
      const posL = [[2, 4], [3, 4], [4, 4], [5, 4], [6, 4], [7, 4], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3]];
      let pidx = 0;
      while (S.eSpwn < cnt && pidx < posL.length && S.eQ.length) {
        const c = S.eQ.shift(); if (!c) break;
        const p = posL[pidx++];
        if (!UnitManager.uAt(p[0], p[1])) { UnitManager.addUnit('enemy', c, p[0], p[1]); S.eSpwn++; }
      }
    } else {
      const op = [];
      const isOff = S.cStage && S.cStage.style === 'offense';
      const spawnRows = isOff ? [2, 3] : [0, 1];
      for (let c = 0; c < COLS; c++) if (!UnitManager.uAt(c, spawnRows[0])) op.push({ x: c, y: spawnRows[0] });
      if (op.length < cnt) for (let c = 0; c < COLS; c++) if (!UnitManager.uAt(c, spawnRows[1])) op.push({ x: c, y: spawnRows[1] });
      shuffle(op);
      for (let i = 0; i < Math.min(cnt, op.length); i++) {
        const c = S.eQ.shift(); if (!c) break;
        UnitManager.addUnit('enemy', c, op[i].x, op[i].y); S.eSpwn++;
      }
    }
    EventBus.emit('wave_spawn', { count: cnt });
  },

  // ── 다음 유닛 행동 처리 ──
  async nextAction() {
    const S = GameStore;
    if (FSM.is(BattleState.BATTLE_END)) return;

    const stage = S.cStage;
    // 웨이브 스폰 체크
    if (stage && S.eSpwn < stage.tot) {
      const interval = stage.si * 2;
      if (S.actCount > 0 && S.actCount % interval === 0) {
        FSM.transition(BattleState.WAVE_TRANSITION);
        EventBus.emit('wave_announce', { remaining: stage.tot - S.eSpwn });
        this.spawnWave();
        Renderer.rUnits();
        await sl(600);
        EventBus.emit('wave_announce_end');
      }
    }

    FSM.transition(BattleState.ADVANCING_TICK);
    const nextU = this.advanceTick();
    if (!nextU) return;

    S.curUnit = nextU;
    ActionManager.clrSel();
    Renderer.rTurnOrder();

    if (nextU.team === 'ally') {
      FSM.transition(BattleState.PLAYER_IDLE);
      EventBus.emit('turn_start', { unit: nextU, phase: 'player' });
      Renderer.uUI();

      if (nextU.stunned > 0 || BuffSystem.has(nextU, BuffType.STUN)) {
        setTimeout(() => this.endUnitTurn(nextU), 500);
      } else {
        setTimeout(() => ActionManager.selU(nextU), 350);
      }
    } else {
      FSM.transition(BattleState.AI_TURN);
      EventBus.emit('turn_start', { unit: nextU, phase: 'enemy' });
      Renderer.uUI();
      setTimeout(async () => {
        if (!FSM.is(BattleState.BATTLE_END)) await AI.eAI(nextU);
        this.endUnitTurn(nextU);
      }, 450);
    }
  },

  // ── 전투 종료 체크 ──
  chkEnd() {
    const S = GameStore;
    if (FSM.is(BattleState.BATTLE_END)) return;

    const al = UnitManager.alive('ally'), en = UnitManager.alive('enemy');

    // 소환사 사망 시 소환수 제거
    S.units.filter(u => u.cls === 'summoner' && u.hp <= 0).forEach(deadS => {
      const summons = S.units.filter(s => s.isSummon && s.summonerId === deadS.id);
      summons.forEach(s => { EventBus.emit('unit_killed', { killer: null, target: s, reason: 'unsummon' }); });
      S.units = S.units.filter(v => !(v.isSummon && v.summonerId === deadS.id));
    });

    if (!al.length && !this.hasAllyWall()) {
      FSM.transition(BattleState.BATTLE_END);
      EventBus.emit('battle_end', { win: false, message: t('messages.all_defeated') });
      return;
    }

    const s = S.cStage;
    if (s) {
      const limit = Math.ceil(s.tot / 4);
      if (S.breached >= limit) {
        FSM.transition(BattleState.BATTLE_END);
        EventBus.emit('battle_end', { win: false, message: t('messages.enemy_breached', { count: S.breached }) });
        return;
      }
    }

    // 은신 유닛만 남으면 강제 해제 (양쪽 동일 적용)
    [en, al].forEach(team => {
      if (team.length > 0 && team.every(u => isStealthed(u))) {
        team.forEach(u => { u.stealthBroken = true; });
        Renderer.rUnits();
      }
    });

    if (s && S.eSpwn >= s.tot && !en.length) {
      FSM.transition(BattleState.BATTLE_END);
      EventBus.emit('battle_end', { win: true, message: t('messages.stage_clear', { stage_id: s.id, turn: S.turn }) });
    }
  },

  hasAllyWall() {
    return Object.keys(GameStore.gateHP).some(k => k.endsWith(',14') && GameStore.gateHP[k] > 0);
  },
};
