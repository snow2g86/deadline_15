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
      const total = actE + killEach;
      if (!total) return;
      const r = gainExp(u.uid, total);
      S._expResults.push({ uid: u.uid, exp: total, actExp: actE, killExp: killEach, leveled: r.leveled, prevLv: r.prevLv });
    });
    S._totalExp = killPool;
    S._deadEnemyCount = S._killCount;

    if (win) {
      let reward = 50 + (S.cStage ? S.cStage.id * 30 : 0);
      let firstClearBonus = 0;

      if (S.practiceMode) {
        reward = Math.floor(reward * 0.7);
        S._practiceMode = true;
        S._baseReward = reward;
      } else {
        const isFirstClear = S.cStage && !S.cleared.has(S.cStage.id);
        if (isFirstClear) { firstClearBonus = 1000; S._firstClearBonus = firstClearBonus; }
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
        const each = 100 + S.cStage.id * 10;
        const bonus = r.newly.filter(i => i > 0).length * each;
        S._starResult = { flags, merged: r.merged, newly: r.newly, limit, turn: S.turn || 1, bonus };
        S.gold += bonus;
      }

      S.gold += reward + firstClearBonus;
      saveGold(S.gold, [...S.cleared]);

      if (!S.practiceMode) {
        const isFC = S.cStage && S._firstClearBonus;
        if (isFC) {
          let shouldGiveUnit = false;
          const stageId = S.cStage.id;
          const episode = Math.floor((stageId - 1) / 10) + 1;
          if (episode === 1) shouldGiveUnit = true;
          else shouldGiveUnit = (stageId % 5 === 0);

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
