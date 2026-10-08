// ═══════════════════════════════════════════
//  battle/end.js — Battle-end, rewards & navigation
// ═══════════════════════════════════════════

const BattleEnd = {
  onBattleEnd(win) {
    const S = GameStore;
    const killPool = S._killExpPool;
    const survivors = S.units.filter(u => u.team === 'ally' && u.hp > 0 && u.uid);
    const killEach = survivors.length ? Math.floor(killPool / survivors.length) : 0;
    S._expResults = [];
    survivors.forEach(u => {
      const actE = (S.battleExp && S.battleExp[u.uid]) || 0;
      const expMul = 1 + ((u.gear && u.gear.exp_pct) || 0) / 100;   // 장비: 받는 경험치 증가
      const total = Math.round((actE + killEach) * expMul);
      if (!total) return;
      const r = gainExp(u.uid, total);
      S._expResults.push({ uid: u.uid, exp: total, actExp: actE, killExp: killEach, leveled: r.leveled, prevLv: r.prevLv });
    });
    S._totalExp = killPool;
    S._deadEnemyCount = S._killCount;

    S._gearDrops = [];
    // 요일 던전: 영혼석 조각 + 강화석 + 그 직업 세트 장비(확률) (골드·클리어 기록·별·신규 유닛·스킬북 없음)
    if (S.cStage && S.cStage.daily) {
      S._soulReward = null;
      if (win) { Soul.add('frag', S.cStage.daily.cls, S.cStage.daily.frags); S._soulReward = { kind: 'frag', cls: S.cStage.daily.cls, n: S.cStage.daily.frags };
        S._runeDrop = Math.random() < RUNE_DROP_CHANCE ? Rune.add(Rune.random()) : null;
        this._dailyGear(S); }
      S._deadAllyUids.forEach(uid => markDead(uid));
      clearBattle();
      return;
    }

    if (win) {
      const sid = S.cStage ? S.cStage.id : 0;
      let reward = ECON.win[0] + ECON.win[1] * sid;
      let firstClearBonus = 0;

      if (S.practiceMode) {
        reward = Math.floor(reward * ECON.practiceMul);
        S._practiceMode = true;
        S._baseReward = reward;
      } else {
        const isFirstClear = S.cStage && !S.cleared.has(S.cStage.id);
        if (isFirstClear) { firstClearBonus = ECON.firstClear[0] + ECON.firstClear[1] * sid; S._firstClearBonus = firstClearBonus; }
        if (S.cStage) S.cleared.add(S.cStage.id);
        S._baseReward = reward;
        S._bonusReward = firstClearBonus;
      }

      // 별점: ★1 클리어 / ★2 전사자 없음 / ★3 N턴 이내. 처음 얻은 ★2·★3마다 골드 보너스 (연습 모드 제외)
      S._starResult = null;
      if (!S.practiceMode && S.cStage) {
        const limit = starTurnLimit(S.cStage);
        const flags = [1, S._deadAllyUids.length === 0 ? 1 : 0, (S.turn || 1) <= limit ? 1 : 0];
        const r = saveStageStars(S.cStage.id, flags);
        const each = ECON.star[0] + ECON.star[1] * S.cStage.id;
        const bonus = r.newly.filter(i => i > 0).length * each;
        S._starResult = { flags, merged: r.merged, newly: r.newly, limit, turn: S.turn || 1, bonus };
        S.gold += bonus;
      }

      S.gold += reward + firstClearBonus;
      saveGold(S.gold, [...S.cleared]);

      if (!S.practiceMode) {
        const isFC = S.cStage && S._firstClearBonus;
        if (isFC) {
          // 신규 클랜원: Ep1의 몇 스테이지와 보스 스테이지 첫 클리어만 (제물이 넘치면 성장이 너무 쉬움)
          const stageId = S.cStage.id;
          const shouldGiveUnit = ECON.freeUnitStages.indexOf(stageId) !== -1 || !!S.cStage.boss;

          if (shouldGiveUnit) {
            const NON_NOVICE = Object.keys(JAB).filter(k => k !== 'novice' && !k.startsWith('summon_') && !JAB[k].unique);
            const rCls = NON_NOVICE[Math.floor(Math.random() * NON_NOVICE.length)];
            const d = JAB[rCls];
            if (d) {
              try {
                const rd = JSON.parse(localStorage.getItem('game_roster'));
                if (rd) {
                  const g = d.growth;
                  const roll = mm => +(mm[0] + Math.random() * (mm[1] - mm[0])).toFixed(1);
                  const names = Object.keys(rd.chars.reduce((m, c) => { m[c.nameId] = 1; return m; }, {}));
                  let nameId; do { nameId = Math.floor(Math.random() * 300); } while (names.indexOf(String(nameId)) !== -1);
                  const ch = {
                    uid: rd.nextId++, cls: rCls, nameId, lv: 1, exp: 0, dead: false,
                    hp: d.base.hp, atk: d.base.atk, def: d.base.def,
                    move: d.base.move, range: d.base.range,
                    pot: { hp: roll(g.hp), atk: roll(g.atk), def: roll(g.def) },
                    gender: randomGender()
                  };
                  rd.chars.push(ch);
                  localStorage.setItem('game_roster', JSON.stringify(rd));
                  S._firstClearUnit = ch;
                }
              } catch (_) {}
            }
          }
        }

        // 스토리 보상: Ep5 최종(50스테이지) 첫 클리어 시 지휘관이 다 카포를 깨우침 (상점 스킬북으로도 습득 가능)
        if (isFC && S.cStage.id === STORY_SKILL_STAGE) {
          try {
            const rd = getRoster(); const cm = rd.chars.find(c => c.cls === COMMANDER_CLS);
            if (cm) {
              cm.skillLv = cm.skillLv || {};
              if (!cm.skillLv.commander_dacapo) { cm.skillLv.commander_dacapo = 1; saveRoster(rd); S._storySkill = 'commander_dacapo'; }
            }
          } catch (_) {}
        }

        // 보스 스테이지: 첫 클리어 → 파티 직업 중 하나의 영혼석, 반복 → 그 직업 조각
        S._soulReward = null;
        if (S.cStage.boss) {
          const pcls = S.units.filter(u => u.team === 'ally' && u.uid && !u.isSummon).map(u => u.cls);
          const cls = pcls.length ? pcls[Math.floor(Math.random() * pcls.length)] : S.cStage.boss.cls;
          if (isFC) { Soul.add('stone', cls, SOUL.bossFirstStone); S._soulReward = { kind: 'stone', cls, n: SOUL.bossFirstStone }; }
          else { Soul.add('frag', cls, SOUL.bossRepeatFrags); S._soulReward = { kind: 'frag', cls, n: SOUL.bossRepeatFrags }; }
        }

        // 보스 스테이지: 확률로 전설 장비 (첫 클리어 15% · 반복 5%)
        if (S.cStage.boss && Math.random() < (isFC ? GEAR_DROP.bossLegend.first : GEAR_DROP.bossLegend.repeat)) {
          const it = Gear.give(Gear.makeLegend());
          S._gearDrops.push({ icon: getEquipEmoji(it.templateId), text: Gear.name(it), legend: true });
        }

        // 마법부여 룬 드랍
        S._runeDrop = Math.random() < RUNE_DROP_CHANCE ? Rune.add(Rune.random()) : null;

        if (typeof LEARNABLE_SKILLS !== 'undefined' && Math.random() < 0.05) {
          const lsKeys = Object.keys(LEARNABLE_SKILLS);
          if (lsKeys.length) {
            const sk = LEARNABLE_SKILLS[lsKeys[Math.floor(Math.random() * lsKeys.length)]];
            try {
              const inv = JSON.parse(localStorage.getItem('game_inventory')) || [];
              inv.push({ id: sk.id, cls: sk.cls, lv: 1 });
              localStorage.setItem('game_inventory', JSON.stringify(inv));
              S._droppedBook = sk.id;
            } catch (_) {}
          }
        }
      }
    }

    if (S.practiceMode) {
      S._autoRevivedCount = S._deadAllyUids.length;
      S._deadAllyUids = [];
    } else {
      S._deadAllyUids.forEach(uid => markDead(uid));
    }

    clearBattle();
  },

  // 요일 던전 장비 보상: 강화석(난이도별) · 그 직업 세트 한 부위(확률) · 지옥은 전설(3%)
  _dailyGear(S) {
    const dl = S.cStage.daily, tier = dl.tier;
    const st = GEAR_DROP.dailyStones[tier] || 2;
    Mats.add('stone', st); S._gearDrops.push({ icon: '🔩', text: t('gear.stone') + ' +' + st });
    if (Math.random() < (GEAR_DROP.dailySet[tier] || 0)) {
      const it = Gear.give(Gear.makeSetPiece(dl.cls, null, GEAR_DROP.setRarity[tier] || 'rare'));
      S._gearDrops.push({ icon: getEquipEmoji(it.templateId), text: Gear.name(it) });
    }
    if (tier === 'hell' && Math.random() < GEAR_DROP.dailyLegendHell) {
      const it = Gear.give(Gear.makeLegend());
      S._gearDrops.push({ icon: getEquipEmoji(it.templateId), text: Gear.name(it), legend: true });
    }
  },

  returnToLobby() { location.href = 'index.html'; },

  goNextStage(stage) {
    const party = loadParty();
    const filteredParty = party.filter(uid => { const ch = getChar(uid); return ch && !ch.dead; });
    if (filteredParty.length >= MIN_P) {
      localStorage.setItem('game_nav', JSON.stringify({ cStage: stage, party: filteredParty }));
      location.href = 'battle.html';
    } else {
      localStorage.setItem('game_nav', JSON.stringify({ cStage: stage }));
      location.href = 'party-select.html';
    }
  },
};
