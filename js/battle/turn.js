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

    // 용암 옆에서 행동을 마치면 화상 (사망하지는 않음)
    if (u.hp > 1 && UnitManager.nearLava(u.x, u.y)) {
      const burn = Math.min(u.hp - 1, Math.max(1, Math.round(u.mhp * TACTIC.lavaBurn)));
      u.hp -= burn;
      Fx.float(u.x, u.y, '\uD83D\uDD25 -' + burn, 'damage');
      Fx.redrawUnits();
    }

    // 맵 환경 지속 피해 (화상·독 등, 사망하지는 않음) — 마법부여 장비가 있으면 면역
    if (u.team === 'ally' && u._hazardDot && u.hp > 1 && S._hazard) {
      const dmg = Math.min(u.hp - 1, Math.max(1, Math.round(u.mhp * Hazard.dotPct(S._hazard, S.cStage) * GearFX.hazardMul(u))));
      u.hp -= dmg;
      Fx.float(u.x, u.y, S._hazard.icon + ' -' + dmg, 'damage');
      Fx.redrawUnits();
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
    // (예전에는 여기서 buffs[]를 한 번 더 깎아 모든 버프 지속이 절반이 되었음 — BuffSystem.tick 한 번으로 통일)

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
    this._countTurn(u);
    this.nextAction();
  },

  // 턴 = 살아있는 아군(소환수 제외) 전원이 한 번씩 행동을 마친 주기
  _countTurn(u) {
    const S = GameStore;
    if (u.team !== 'ally' || u.isSummon) return;
    S._turnActed = S._turnActed || {};
    S._turnActed[u.id] = true;
    const allies = S.units.filter(v => v.team === 'ally' && !v.isSummon && v.hp > 0);
    if (allies.length && allies.every(v => S._turnActed[v.id])) {
      S.turn = (S.turn || 1) + 1;
      S._turnActed = {};
      if (typeof tickPoisonMists === 'function') tickPoisonMists(); // 주술사 독안개 (라운드마다 1회)
      EventBus.emit('round_end', { turn: S.turn });
      Fx.updateUI();
    }
  },

  // ── 웨이브 스폰 ──
  spawnWave() {
    const S = GameStore;
    if (!S.cStage) return;
    const s = S.cStage, rem = s.tot - S.eSpwn;
    if (rem <= 0) return;

    const activeEnemies = S.units.filter(u => u.team === 'enemy' && u.hp > 0).length;
    const maxConcurrent = MAX_ENEMIES_ON_FIELD;   // 동시에 전장에 있는 적 상한 (data/stages.js)
    if (activeEnemies >= maxConcurrent) return;

    const cnt = Math.min(s.spw, rem, S.eQ.length, maxConcurrent - activeEnemies);
    if (S.eSpwn === 0 && s.boss) {
      const bu = UnitManager.addUnit('enemy', s.boss.cls, MID_C, 2);
      if (bu) {
        bu.isBoss = true; bu.name = bossName(s); bu.origSpawn = { x: MID_C, y: 2 };
        // 보스: 레벨 +ENEMY_BOSS_LV 만큼 더 성장한 능력치
        const g = JAB[bu.cls].growth, m = ENEMY_BOSS_LV;
        bu.lv += m; bu.mhp = bu.hp = Math.round(bu.mhp + (g.hp[0] + g.hp[1]) / 2 * m * s.sm.hp);
        bu.atk = Math.round(bu.atk + (g.atk[0] + g.atk[1]) / 2 * m * s.sm.atk); bu.def = Math.round(bu.def + (g.def[0] + g.def[1]) / 2 * m);
      }
      S.eSpwn++;
      const posL = [4, 3].flatMap(y => FORM_COLS.map(x => [x, y]));   // 보스 호위: 가운데부터 바깥으로
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
    // 클랜원 전멸 확인 (마지막 클랜원이 반격·지원 공격·지속 피해 등 chkEnd를 거치지 않는 경로로 쓰러져도 여기서 패배 처리)
    if (!S.units.some(u => u.team === 'ally' && u.hp > 0 && !u.isSummon)) { this.chkEnd(); return; }

    const stage = S.cStage;
    // 웨이브 스폰 체크
    if (stage && S.eSpwn < stage.tot) {
      const interval = stage.si * 2;
      if (S.actCount > 0 && S.actCount % interval === 0) {
        FSM.transition(BattleState.WAVE_TRANSITION);
        EventBus.emit('wave_announce', { remaining: stage.tot - S.eSpwn });
        this.spawnWave();
        Fx.redrawUnits();
        await sl(600);
        EventBus.emit('wave_announce_end');
      }
    }

    FSM.transition(BattleState.ADVANCING_TICK);
    const nextU = this.advanceTick();
    if (!nextU) return;

    S.curUnit = nextU;
    nextU._defend = false; nextU._overwatch = false; // 방어 태세·경계는 다음 자기 차례에 풀림
    ActionManager.clrSel();
    Fx.turnOrder();

    if (nextU.team === 'ally') {
      FSM.transition(BattleState.PLAYER_IDLE);
      EventBus.emit('turn_start', { unit: nextU, phase: 'player' });
      Fx.updateUI();

      if (nextU.stunned > 0 || BuffSystem.has(nextU, BuffType.STUN)) {
        setTimeout(() => this.endUnitTurn(nextU), 500);
      } else {
        setTimeout(() => ActionManager.selU(nextU), 350);
      }
    } else {
      FSM.transition(BattleState.AI_TURN);
      EventBus.emit('turn_start', { unit: nextU, phase: 'enemy' });
      Fx.updateUI();
      // 기절·빙결된 적은 행동하지 못하고 차례를 넘김 (아군과 같은 규칙)
      if (UnitManager.isCC(nextU)) {
        Fx.float(nextU.x, nextU.y, t('messages.cc_skip'), 'debuff');
        setTimeout(() => this.endUnitTurn(nextU), 500);
        return;
      }
      setTimeout(async () => {
        if (!FSM.is(BattleState.BATTLE_END)) await AI.eAI(nextU);
        this.endUnitTurn(nextU);
      }, 450 * ENEMY_TURN_PACE);
    }
  },

  // ── 전투 종료 체크 ──
  chkEnd() {
    const S = GameStore;
    if (FSM.is(BattleState.BATTLE_END)) return;

    const al = UnitManager.alive('ally'), en = UnitManager.alive('enemy');

    // 지휘관(고유 주인공)이 쓰러지면 즉시 패배
    if (S._commanderFallen || S.units.some(u => u.team === 'ally' && u.cls === COMMANDER_CLS && u.hp <= 0)) {
      FSM.transition(BattleState.BATTLE_END);
      EventBus.emit('battle_end', { win: false, message: t('commander_msg.fallen') });
      return;
    }

    // 소환사 사망 시 소환수 제거
    S.units.filter(u => u.cls === 'summoner' && u.hp <= 0).forEach(deadS => {
      const summons = S.units.filter(s => s.isSummon && s.summonerId === deadS.id);
      summons.forEach(s => { EventBus.emit('unit_killed', { killer: null, target: s, reason: 'unsummon' }); });
      S.units = S.units.filter(v => !(v.isSummon && v.summonerId === deadS.id));
    });

    // 클랜원(소환수 제외)이 모두 쓰러지면 패배. 예전엔 아군 성벽이 남아 있으면 계속돼, 행동할 클랜원 없이 적 차례만 끝없이 반복됐음
    if (!al.some(u => !u.isSummon)) {
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
        Fx.redrawUnits();
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
