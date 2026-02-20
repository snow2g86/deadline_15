// ═══════════════════════════════════════════
//  battle/action.js — Player actions (FSM-based cellCk, move, attack, heal, skill, item)
// ═══════════════════════════════════════════

const ActionManager = {
  // ── 유닛 선택 ──
  selU(u) {
    const S = GameStore;
    if (S.curUnit && u.id !== S.curUnit.id && u.team === 'ally') return;
    if (!FSM.isPlayerTurn() || FSM.is(BattleState.BATTLE_END)) return;
    if (u.team === 'ally' && u.ha) return;

    S.sel = u;
    FSM.transition(BattleState.UNIT_SELECTED);
    if (u.team === 'ally' && !u.ha) {
      S.mvT = [];  // 이동 범위는 Move 버튼 클릭 시에만 표시
      if (u.channeling) { S.atkT = []; S.healT = []; }
      else { this._setTargets(u); }  // atkT/healT는 버튼 표시 조건용
    } else {
      S.mvT = []; S.atkT = []; S.healT = [];
    }
    Renderer.rTer(); Renderer.rUnits(); Renderer.showAM(u); Renderer.showUI(u);
    Renderer.rTurnOrder(); Renderer.scrollToUnit(u); Audio.sfxSelect();
  },

  clrSel() {
    const S = GameStore;
    S.sel = null; S.mvT = []; S.atkT = []; S.healT = [];
    S._curSkill = null; S.preMv = null;
    if (FSM.isPlayerTurn()) FSM.transition(BattleState.PLAYER_IDLE);
    Renderer.hideAM(); Renderer.hideEnemyPopup();
    Renderer.rTer(); Renderer.rUnits(); Renderer.defI(); Renderer.rTurnOrder();
  },

  _setTargets(u) {
    const S = GameStore;
    const a = Grid.atkCells(u);
    S.atkT = a.filter(c => { const v = UnitManager.uAt(c.x, c.y); return v && v.team === 'enemy' && !isStealthed(v); });
    S.healT = u.role === 'healer' ? a.filter(c => { const v = UnitManager.uAt(c.x, c.y); return v && v.team === 'ally' && v.hp < v.mhp && v.id !== u.id; }) : [];
  },

  // ── FSM 기반 cellCk (Tactics Ogre 스타일: 모드별 독립 처리) ──
  cellCk(x, y) {
    const S = GameStore;
    if (FSM.is(BattleState.BATTLE_END, BattleState.AI_TURN, BattleState.ANIMATING)) return;
    if (!FSM.acceptsCellClick()) return;

    const cl = UnitManager.uAt(x, y), s = S.sel;

    // 스킬 타겟 모드
    if (FSM.is(BattleState.SKILL_TARGET)) {
      if (S.atkT.some(c => c.x === x && c.y === y)) { this.doSkill(s, x, y); return; }
      S.atkT = []; S.healT = []; this._setTargets(s);
      FSM.transition(BattleState.UNIT_SELECTED);
      Renderer.rTer(); Renderer.showAM(s); return;
    }

    // 아이템 타겟 모드
    if (FSM.is(BattleState.ITEM_TARGET)) {
      if (S._curPotion && S.potionTargets) {
        const pt = S.potionTargets.find(t2 => t2.x === x && t2.y === y);
        if (pt) { this.doPotion(pt); return; }
        S._curPotion = null; S.potionTargets = [];
        FSM.transition(BattleState.UNIT_SELECTED);
        Renderer.rTer(); Renderer.showAM(s); return;
      }
      if (S._curSiege) {
        if (S.atkT.some(c => c.x === x && c.y === y)) { this.doSiege(s, x, y); return; }
        S._curSiege = null; S.atkT = [];
        FSM.transition(BattleState.UNIT_SELECTED);
        Renderer.rTer(); Renderer.showAM(s); return;
      }
      return;
    }

    // MOVE_MODE: 이동 범위만 처리
    if (FSM.is(BattleState.MOVE_MODE) && s) {
      const isValidMove = S.mvT.some(c => c.x === x && c.y === y);
      // 암살자 숲 이동 (적 위에 겹침)
      if (cl && cl.team === 'enemy' && s.cls === 'assassin' && s.team === 'ally' && !s.ha && S.ter[y] && S.ter[y][x] === 'forest' && isValidMove) { this.doMv(s, x, y); return; }
      if (!cl && isValidMove) { this.doMv(s, x, y); return; }
      // 범위 밖 → 메뉴 복원
      S.mvT = []; this._setTargets(s);
      FSM.transition(BattleState.UNIT_SELECTED);
      Renderer.rTer(); Renderer.showAM(s); return;
    }

    // ATTACK_MODE: 공격 범위만 처리
    if (FSM.is(BattleState.ATTACK_MODE) && s) {
      if (cl && cl.team === 'enemy' && S.atkT.some(c => c.x === x && c.y === y)) { this.doAtk(s, cl); return; }
      // 범위 밖 → 메뉴 복원
      S.atkT = []; this._setTargets(s);
      FSM.transition(BattleState.UNIT_SELECTED);
      Renderer.rTer(); Renderer.showAM(s); return;
    }

    // HEAL_MODE: 힐 범위만 처리
    if (FSM.is(BattleState.HEAL_MODE) && s) {
      if (cl && cl.team === 'ally' && cl.id !== s.id && S.healT.some(c => c.x === x && c.y === y)) { this.doHeal(s, cl); return; }
      // 범위 밖 → 메뉴 복원
      S.healT = []; this._setTargets(s);
      FSM.transition(BattleState.UNIT_SELECTED);
      Renderer.rTer(); Renderer.showAM(s); return;
    }

    // ATTACK_HEAL_MODE: 힐러 전용 — atkT(적) + healT(아군) 동시
    if (FSM.is(BattleState.ATTACK_HEAL_MODE) && s) {
      if (cl && cl.team === 'enemy' && S.atkT.some(c => c.x === x && c.y === y)) { this.doAtk(s, cl); return; }
      if (cl && cl.team === 'ally' && cl.id !== s.id && S.healT.some(c => c.x === x && c.y === y)) { this.doHeal(s, cl); return; }
      // 범위 밖 → 메뉴 복원
      S.atkT = []; S.healT = []; this._setTargets(s);
      FSM.transition(BattleState.UNIT_SELECTED);
      Renderer.rTer(); Renderer.showAM(s); return;
    }

    // UNIT_SELECTED: 메뉴 표시 상태 (범위 미표시) → 적 클릭=팝업만
    if (FSM.is(BattleState.UNIT_SELECTED)) {
      if (cl && cl.team === 'enemy') { Renderer.showEnemyPopup(cl); return; }
      if (cl && cl.team === 'ally' && (!S.curUnit || cl.id === S.curUnit.id)) { this.selU(cl); return; }
      return;
    }

    // PLAYER_IDLE
    if (FSM.is(BattleState.PLAYER_IDLE)) {
      if (cl && cl.team === 'ally' && (!S.curUnit || cl.id === S.curUnit.id)) { this.selU(cl); return; }
      if (cl && cl.team === 'enemy') { Renderer.showEnemyPopup(cl); return; }
    }

    if (s && cl && cl.team === 'ally') {
      if (!S.curUnit || cl.id === S.curUnit.id) this.selU(cl);
      return;
    }

    this.clrSel();
  },

  // ── 액션 버튼 ──
  actMove() {
    const S = GameStore;
    if (!S.sel) return;
    Renderer.hideAM();
    const u = S.sel;
    S.mvT = (u.hm || u.mo) ? [] : Grid.mvCells(u);
    FSM.transition(BattleState.MOVE_MODE);
    Renderer.rTer();
    Renderer.floatT(u.x, u.y, t('messages.select_move_target'), 'heal');
  },

  actAttack() {
    const S = GameStore;
    if (!S.sel) return;
    Renderer.hideAM();
    if (S.sel.role === 'healer') {
      // 힐러: atkT(빨강) + healT(초록) 동시 표시
      FSM.transition(BattleState.ATTACK_HEAL_MODE);
    } else {
      // 비힐러: atkT(빨강)만 표시
      S.healT = [];
      FSM.transition(BattleState.ATTACK_MODE);
    }
    Renderer.rTer();
    Renderer.floatT(S.sel.x, S.sel.y, t('messages.select_attack_target'), 'heal');
  },

  actHeal() {
    if (!GameStore.sel) return;
    Renderer.hideAM(); GameStore.atkT = [];
    FSM.transition(BattleState.HEAL_MODE);
    Renderer.rTer();
    Renderer.floatT(GameStore.sel.x, GameStore.sel.y, t('messages.select_heal_target'), 'heal');
  },

  actWait() {
    const S = GameStore;
    if (!S.sel) return;
    const u = S.sel;
    u.ha = true;
    if (u.team === 'ally') S.allyPos[u.id] = { x: u.x, y: u.y };
    Renderer.hideAM(); Audio.sfxWait();
    Renderer.rUnits(); this.clrSel(); TurnManager.endUnitTurn(u);
  },

  actCancel() {
    const S = GameStore;
    if (!S.sel) return;

    if (S._skillMenuOpen) { this.hideSkillMenu(); return; }
    if (S._itemMenuOpen) { this.hideItemMenu(); return; }
    if (S._curPotion) {
      S._curPotion = null; S.potionTargets = [];
      FSM.transition(BattleState.UNIT_SELECTED);
      Renderer.rUnits(); Renderer.showAM(S.sel); return;
    }
    if (S._curSiege) {
      S._curSiege = null; S.atkT = [];
      FSM.transition(BattleState.UNIT_SELECTED);
      Renderer.rTer(); Renderer.showAM(S.sel); return;
    }

    if (!S.preMv) return;
    const u = S.sel;
    const _gdx = u._gdx, _gdy = u._gdy;
    if (S.preMv.exp && u.uid) { S.battleExp[u.uid] = (S.battleExp[u.uid] || 0) - S.preMv.exp; }
    u.x = S.preMv.x; u.y = S.preMv.y; u.hm = false; u.mo = false;
    VFX.animU(u.id, u.x, u.y); u._gdx = _gdx; u._gdy = _gdy; VFX._applyFace(u.id);
    S.preMv = null; S._curSkill = null;
    Renderer.hideAM(); Audio.sfxUIClick();
    FSM.transition(BattleState.PLAYER_IDLE);
    setTimeout(() => { Renderer.rTer(); this.clrSel(); }, 340);
  },

  // ── 경험치 부여 ──
  _grantExp(u, action) {
    const S = GameStore;
    if (u.team === 'ally' && u.uid) {
      const e = actExp(S.cStage ? S.cStage.id : 1, action);
      if (e > 0) { S.battleExp[u.uid] = (S.battleExp[u.uid] || 0) + e; Renderer.floatT(u.x, u.y, '+' + e + ' EXP', 'exp'); }
      return e;
    }
    return 0;
  },

  skMul(u, skId) { const lv = Math.min((u.skillLv && u.skillLv[skId]) || 1, 10); return 1 + 0.1 * (lv - 1); },

  // ── 이동 ──
  doMv(u, tx, ty) {
    const S = GameStore;
    const _mxp = this._grantExp(u, 'move');
    S.preMv = { x: u.x, y: u.y, exp: _mxp };
    VFX._mvU(u, tx, ty); u.hm = true; u.mo = true;
    FSM.transition(BattleState.UNIT_SELECTED);
    Audio.sfxMove();

    if (u._cursed && u.mhp > 0) {
      const curseDmg = Math.max(1, Math.round(u.mhp * 0.05));
      u.hp = Math.max(1, u.hp - curseDmg);
      u._curseDmgCount = (u._curseDmgCount || 0) + 1;
      Renderer.floatT(u.x, u.y, '-' + curseDmg, 'damage');
      Renderer.floatT(u.x, u.y, '\u2620\uFE0F \uC800\uC8FC (' + u._curseDmgCount + '/5)', 'debuff');
      if (u._curseDmgCount >= 5) {
        u._cursed = false; u._curseAtk = 0; u._curseDmgCount = 0;
        Renderer.floatT(u.x, u.y, t('messages.curse_end') || '\u2620\uFE0F \uC800\uC8FC \uD574\uC81C', 'heal');
      }
    }

    Grid.chkTrap(u); chkTrapDetect(u);

    const a = Grid.atkCells(u);
    if (u.role === 'healer') {
      S.atkT = a.filter(c => { const v = UnitManager.uAt(c.x, c.y); return v && v.team === 'enemy' && !isStealthed(v); });
      S.healT = a.filter(c => { const v = UnitManager.uAt(c.x, c.y); return v && v.team === 'ally' && v.hp < v.mhp && v.id !== u.id; });
    } else {
      S.atkT = a.filter(c => { const v = UnitManager.uAt(c.x, c.y); return v && v.team === 'enemy' && !isStealthed(v); });
      S.healT = [];
    }
    S.mvT = [];
    setTimeout(() => {
      Renderer.scrollToUnit(u); Renderer.rTer(); Renderer.showAM(u); Renderer.showUI(u);
    }, 340);
  },

  // ── 공격 ──
  doAtk(a, tgt) {
    // 고양 버프 카운터
    if (a.buffs) {
      for (let i = a.buffs.length - 1; i >= 0; i--) {
        const b = a.buffs[i];
        if (b.source === 'shaman_exalt' && b._attackCount > 0) {
          b._attackCount--;
          if (b._attackCount <= 0) { a.buffs.splice(i, 1); Renderer.floatT(a.x, a.y, t('messages.buff_end') || '\uBC84\uD504 \uD574\uC81C', 'debuff'); }
        }
      }
    }

    if (tgt._siegeEvasion > 0 && Math.random() < 0.3) {
      tgt._siegeEvasion--;
      Renderer.floatT(tgt.x, tgt.y, t('messages.evasion'), 'heal');
      a.ha = true; a.hm = true;
      Renderer.hideAM(); Renderer.rUnits(); this.clrSel(); TurnManager.endUnitTurn(a); return;
    }

    const bCounter = tgt.skillLv && tgt.skillLv['brawler_counter'] >= 1 && !(tgt.stunned > 0) && !(tgt.frozen > 0) && mh(tgt.x, tgt.y, a.x, a.y) <= tgt.range && Math.random() < 0.3;
    if (bCounter) {
      setTimeout(() => {
        const cdmg = Math.max(1, Math.round(tgt.atk * 0.5) - a.def);
        a.hp = Math.max(0, a.hp - cdmg);
        this._grantExp(tgt, 'attack');
        EventBus.emit('unit_attacked', { attacker: tgt, target: a, damage: cdmg, isCounter: true });
      }, 420);
    } else {
      let dmg = calcDmg(a, tgt);
      this._grantExp(a, 'attack');
      if (tgt._siegeShield > 0) { dmg = Math.max(1, Math.round(dmg * 0.5)); Renderer.floatT(tgt.x, tgt.y, '\uD83D\uDEE1\uFE0F', 'heal'); }
      tgt.hp = Math.max(0, tgt.hp - dmg);
      EventBus.emit('unit_attacked', { attacker: a, target: tgt, damage: dmg });
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
      if (a._lastCrit) { Renderer.floatT(a.x, a.y, t('messages.critical_hit'), 'heal'); VFX.screenShake(); }
      if (a.furyBuff > 0) Renderer.floatT(a.x, a.y, t('messages.fury_buff'), 'heal');
      procFury(a, tgt, G);
      if (tgt.hp > 0 && a.hp > 0 && mh(tgt.x, tgt.y, a.x, a.y) <= tgt.range && !(tgt.stunned > 0) && !(tgt.frozen > 0)) {
        setTimeout(() => {
          this._grantExp(tgt, 'attack');
          const cdmg = calcDmg(tgt, a);
          const da = applyDmgToAlly(a, cdmg, G);
          EventBus.emit('unit_attacked', { attacker: tgt, target: da, damage: cdmg, isCounter: true });
          procFury(tgt, a, G);
        }, 420);
      }
    }

    a.ha = true; a.hm = true;
    Renderer.hideAM();

    if (tgt.hp <= 0) {
      EventBus.emit('unit_killed', { killer: a, target: tgt });
      setTimeout(() => { UnitManager.rmDead(); Renderer.rUnits(); TurnManager.chkEnd(); this.clrSel(); TurnManager.endUnitTurn(a); }, 650);
    } else if (a.hp <= 0) {
      EventBus.emit('unit_killed', { killer: tgt, target: a });
      setTimeout(() => { UnitManager.rmDead(); Renderer.rUnits(); TurnManager.chkEnd(); this.clrSel(); TurnManager.endUnitTurn(a); }, 650);
    } else {
      const canCounter = tgt.hp > 0 && a.hp > 0 && mh(tgt.x, tgt.y, a.x, a.y) <= tgt.range && !(tgt.stunned > 0) && !(tgt.frozen > 0);
      if (canCounter) {
        setTimeout(() => { Renderer.rUnits(); this.clrSel(); TurnManager.endUnitTurn(a); }, 650);
      } else {
        setTimeout(() => { Renderer.rUnits(); this.clrSel(); TurnManager.endUnitTurn(a); }, 500);
      }
    }
  },

  // ── 힐 ──
  doHeal(h, tgt) {
    let amt = Math.round(h.atk * 1.5);
    if (h.skillLv && h.skillLv['priest_divinegrace'] >= 1) amt = Math.round(amt * 1.2);
    this._grantExp(h, 'heal');
    tgt.hp = Math.min(tgt.mhp, tgt.hp + amt);
    EventBus.emit('unit_healed', { healer: h, target: tgt, amount: amt });
    h.ha = true; h.hm = true;
    Renderer.hideAM();
    setTimeout(() => { Renderer.rUnits(); this.clrSel(); TurnManager.endUnitTurn(h); }, 300);
  },

  // ── 스킬 ──
  showSkillMenu() { const S = GameStore; if (!S.sel) return; S._skillMenuOpen = true; Renderer.showAM(S.sel); },
  hideSkillMenu() { const S = GameStore; if (!S.sel) return; S._skillMenuOpen = false; Renderer.showAM(S.sel); },

  actSkill(idx) {
    const S = GameStore;
    if (!S.sel) return;
    const u = S.sel;
    const skills = getUnitSkills(u);
    const sk = skills[idx || 0];
    if (!sk || u.res < sk.cost) return;
    S._skillMenuOpen = false;
    S._curSkill = sk;
    FSM.transition(BattleState.SKILL_TARGET);

    const handler = SKILL_HANDLERS[sk.id];
    if (handler) {
      const result = handler.target(u, sk, G);
      if (result === null) {
        FSM.transition(BattleState.UNIT_SELECTED); S._curSkill = null;
        S._skillFailedMsg = true; Renderer.showAM(u); Renderer.rTer();
        setTimeout(() => { S._skillFailedMsg = false; }, 100);
        return;
      }
      if (result === 'instant') {
        FSM.transition(BattleState.UNIT_SELECTED); S._curSkill = null;
        this.doSkill(u, u.x, u.y); Renderer.rUnits(); return;
      }
      S.atkT = result; S.healT = [];
    } else {
      const dirs = [{ x: 0, y: -1 }, { x: 1, y: 0 }, { x: 0, y: 1 }, { x: -1, y: 0 }];
      S.atkT = dirs.map(d => ({ x: u.x + d.x, y: u.y + d.y })).filter(p => p.x >= 0 && p.x < COLS && p.y >= 0 && p.y < ROWS);
      S.healT = [];
    }
    Renderer.hideAM(); Renderer.rTer();
  },

  doSkill(u, tx, ty) {
    const S = GameStore;
    const sk = S._curSkill || SKILLS[u.cls];
    if (!sk) return;
    const skObj = Array.isArray(sk) ? sk[0] : sk;
    if (u.res < skObj.cost) return;
    u.res -= skObj.cost;
    EventBus.emit('skill_used', { unit: u, skill: skObj, tx, ty });

    const handler = SKILL_HANDLERS[skObj.id];
    if (handler) { handler.exec(u, tx, ty, skObj, G); return; }
    u.res += skObj.cost;
  },

  _findAdj(x, y, u) {
    const S = GameStore;
    const dirs = [{ x: 0, y: -1 }, { x: 1, y: 0 }, { x: 0, y: 1 }, { x: -1, y: 0 }];
    const cands = [];
    for (const d of dirs) {
      const nx = x + d.x, ny = y + d.y;
      if (nx < 0 || nx >= COLS || ny < 0 || ny >= ROWS) continue;
      const ti = TI[S.ter[ny][nx]]; if (!ti.pass) continue;
      if (!UnitManager.uAt(nx, ny)) cands.push({ x: nx, y: ny });
    }
    if (!cands.length) return null;
    if (u) cands.sort((a2, b) => mh(a2.x, a2.y, u.x, u.y) - mh(b.x, b.y, u.x, u.y));
    return cands[0];
  },

  cancelChannel() {
    const S = GameStore;
    if (!S.sel || !S.sel.channeling) return;
    const u = S.sel;
    Renderer.floatT(u.x, u.y, t('messages.channel_cancel'), 'damage');
    u.channeling = null;
    u.ha = true; u.hm = true; S._curSkill = null;
    Renderer.hideAM(); Audio.sfxUIClick(); Renderer.rUnits();
    this.clrSel(); TurnManager.endUnitTurn(u);
  },

  // ── 아이템 ──
  actItem() {
    const S = GameStore;
    if (!S.sel) return;
    const hasPotion = S._battlePotions && S._battlePotions.length > 0;
    const hasSiege = S._siegeItems && S._siegeItems.length > 0;
    if (!hasPotion && !hasSiege) return;
    S._itemMenuOpen = true; Renderer.showAM(S.sel);
  },
  hideItemMenu() { const S = GameStore; if (!S.sel) return; S._itemMenuOpen = false; Renderer.showAM(S.sel); },

  actPotion(idx) {
    const S = GameStore;
    if (!S.sel) return;
    const pot = S._battlePotions[idx]; if (!pot) return;
    const def = BATTLE_POTIONS[pot.potionId]; if (!def) return;
    S._itemMenuOpen = false;
    S._curPotion = { idx, def, pot };
    FSM.transition(BattleState.ITEM_TARGET);
    const u = S.sel;
    const targets = [];
    const isDebuff = def.type === 'debuff';
    for (let i = 0; i < S.units.length; i++) {
      const tu = S.units[i]; if (tu.hp <= 0) continue;
      if (mh(u.x, u.y, tu.x, tu.y) > def.range) continue;
      if (isDebuff) { if (tu.team === 'enemy') targets.push(tu); }
      else { if (tu.team === 'ally') targets.push(tu); }
    }
    if (targets.length === 0) {
      S._curPotion = null; FSM.transition(BattleState.UNIT_SELECTED);
      Renderer.floatT(u.x, u.y, t('messages.potion_no_target'), 'damage');
      Renderer.showAM(u); return;
    }
    S.potionTargets = targets;
    Renderer.hideAM(); Renderer.floatT(u.x, u.y, t('messages.select_potion_target'), 'heal'); Renderer.rUnits();
  },

  doPotion(targetU) {
    const S = GameStore;
    const potion = S._curPotion; if (!potion) return;
    const def = potion.def, u = S.sel;

    if (def.type === 'heal') {
      const heal = Math.round(targetU.mhp * def.value / 100);
      targetU.hp = Math.min(targetU.mhp, targetU.hp + heal);
      EventBus.emit('unit_healed', { healer: u, target: targetU, amount: heal, isPotion: true });
    } else if (def.type === 'resource') {
      targetU.res = Math.min(targetU.maxRes, targetU.res + def.value);
      EventBus.emit('unit_healed', { healer: u, target: targetU, amount: def.value, isPotion: true });
    } else if (def.type === 'buff') {
      if (!targetU.buffs) targetU.buffs = [];
      targetU.buffs.push({ type: def.stat + '_up', duration: def.duration, value: def.value, source: 'potion' });
      EventBus.emit('buff_applied', { unit: targetU, buff: targetU.buffs[targetU.buffs.length - 1] });
    } else if (def.type === 'debuff') {
      if (!targetU.buffs) targetU.buffs = [];
      targetU.buffs.push({ type: def.stat + '_down', duration: def.duration, value: Math.abs(def.value), source: 'potion' });
      EventBus.emit('buff_applied', { unit: targetU, buff: targetU.buffs[targetU.buffs.length - 1] });
    }

    if (typeof loadInventory === 'function' && typeof saveInventory === 'function') {
      const inv = loadInventory();
      const invIdx = S._battlePotionIndices[potion.idx];
      if (invIdx >= 0 && inv[invIdx]) {
        inv[invIdx].quantity = (inv[invIdx].quantity || 1) - 1;
        if (inv[invIdx].quantity <= 0) {
          inv.splice(invIdx, 1);
          S._battlePotions.splice(potion.idx, 1);
          S._battlePotionIndices.splice(potion.idx, 1);
          for (let i = 0; i < S._battlePotionIndices.length; i++) {
            if (S._battlePotionIndices[i] > invIdx) S._battlePotionIndices[i]--;
          }
        }
        saveInventory(inv);
      }
    }

    S._curPotion = null; S.potionTargets = [];
    u.ha = true;
    Renderer.hideAM(); Renderer.rUnits(); this.clrSel(); TurnManager.endUnitTurn(u);
  },

  actSiege(idx) {
    const S = GameStore;
    if (!S.sel) return;
    const si = S._siegeItems[idx]; if (!si) return;
    const def = SIEGE_ITEMS.find(d => d.id === si.siegeId); if (!def) return;
    S._itemMenuOpen = false;
    S._curSiege = { idx, def, si };
    FSM.transition(BattleState.ITEM_TARGET);
    const u = S.sel;
    const targets = [];
    for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
      if (mh(u.x, u.y, c, r) > def.range) continue;
      const tile = S.ter[r][c];
      if (def.targetType === 'wall' && (tile === 'wall' || tile === 'gate')) targets.push({ x: c, y: r });
      else if (def.targetType === 'wall_rock' && (tile === 'wall' || tile === 'gate' || tile === 'rock')) targets.push({ x: c, y: r });
      else if (def.targetType === 'water' && tile === 'water') targets.push({ x: c, y: r });
    }
    if (targets.length === 0) {
      S._curSiege = null; FSM.transition(BattleState.UNIT_SELECTED);
      Renderer.floatT(u.x, u.y, t('messages.siege_no_target'), 'damage');
      Renderer.showAM(u); return;
    }
    S.atkT = targets; S.healT = []; S.mvT = [];
    Renderer.hideAM(); Renderer.rTer();
    Renderer.floatT(u.x, u.y, t('messages.select_siege_target'), 'heal');
  },

  doSiege(u, tx, ty) {
    const S = GameStore;
    const siege = S._curSiege; if (!siege) return;
    const def = siege.def;

    if (def.effect === 'climb') {
      const dx = tx - u.x, dy = ty - u.y;
      let found = false, landX, landY;
      for (let step = 1; step <= 3; step++) {
        const lx = tx + dx * step, ly = ty + dy * step;
        if (lx < 0 || lx >= COLS || ly < 0 || ly >= ROWS) break;
        const lt = S.ter[ly][lx];
        if (TI[lt] && TI[lt].pass && !UnitManager.uAt(lx, ly)) { landX = lx; landY = ly; found = true; break; }
      }
      if (!found) {
        Renderer.floatT(u.x, u.y, t('messages.siege_no_target'), 'damage');
        S._curSiege = null; FSM.transition(BattleState.UNIT_SELECTED);
        Renderer.showAM(u); return;
      }
      VFX._mvU(u, landX, landY); u.hm = true; u.mo = true;
      EventBus.emit('siege_used', { unit: u, type: 'climb', tx, ty });
    } else if (def.effect === 'destroy') {
      S.ter[ty][tx] = 'plain';
      const wk = tx + ',' + ty;
      if (S.wallHP[wk]) S.wallHP[wk] = 0;
      if (S.gateHP[wk]) S.gateHP[wk] = 0;
      EventBus.emit('siege_used', { unit: u, type: 'destroy', tx, ty });
    } else if (def.effect === 'bridge') {
      S.ter[ty][tx] = 'plain';
      EventBus.emit('siege_used', { unit: u, type: 'bridge', tx, ty });
    }

    const invIdx = S._siegeInvIndices[siege.idx];
    if (typeof loadInventory === 'function' && typeof saveInventory === 'function') {
      const inv = loadInventory();
      if (invIdx >= 0 && invIdx < inv.length) { inv.splice(invIdx, 1); saveInventory(inv); }
    }
    S._siegeItems.splice(siege.idx, 1); S._siegeInvIndices.splice(siege.idx, 1);
    for (let i = 0; i < S._siegeInvIndices.length; i++) {
      if (S._siegeInvIndices[i] > invIdx) S._siegeInvIndices[i]--;
    }

    if (def.effect !== 'climb') u.ha = true;
    S._curSiege = null;
    Renderer.rTer(); Renderer.rUnits();
    if (def.effect === 'climb') {
      FSM.transition(BattleState.UNIT_SELECTED);
      setTimeout(() => { Renderer.scrollToUnit(u); Renderer.showAM(u); Renderer.showUI(u); }, 340);
    } else {
      this.clrSel(); TurnManager.endUnitTurn(u);
    }
  },
};
