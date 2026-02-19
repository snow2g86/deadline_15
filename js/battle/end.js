// ═══════════════════════════════════════════
//  battle/end.js — Battle-end & Navigation
// ═══════════════════════════════════════════
Object.assign(G, {
  onBattleEnd(win) {
    const killPool = this._killExpPool;
    const survivors = this.units.filter(u => u.team === 'ally' && u.hp > 0 && u.uid);
    const killEach = survivors.length ? Math.floor(killPool / survivors.length) : 0;
    this._expResults = [];
    survivors.forEach(u => {
      const actE = (this.battleExp && this.battleExp[u.uid]) || 0;
      const total = actE + killEach;
      if (!total) return;
      const r = gainExp(u.uid, total);
      this._expResults.push({ uid: u.uid, exp: total, actExp: actE, killExp: killEach, leveled: r.leveled, prevLv: r.prevLv });
    });
    this._totalExp = killPool;
    this._deadEnemyCount = this._killCount;
    if (win) {
      let reward = 50 + (this.cStage ? this.cStage.id * 30 : 0);
      let firstClearBonus = 0;

      // 연습 모드: 보상 70%, 클리어 기록 없음, 보너스 없음
      if (this.practiceMode) {
        reward = Math.floor(reward * 0.7);
        this._practiceMode = true;
        this._baseReward = reward;
      } else {
        // 일반 모드: 정상 보상 및 클리어 기록
        const isFirstClear = this.cStage && !this.cleared.has(this.cStage.id);
        if (isFirstClear) {
          firstClearBonus = 1000;
          this._firstClearBonus = firstClearBonus;
        }
        if (this.cStage) {
          this.cleared.add(this.cStage.id);
        }
        this._baseReward = reward;
        this._bonusReward = firstClearBonus;
      }

      this.gold += reward + firstClearBonus;
      saveGold(this.gold, [...this.cleared]);

      // 일반 모드에서만 첫 클리어 유닛 & 책 지급
      if (!this.practiceMode) {
        const isFirstClear = this.cStage && this._firstClearBonus;
        if (isFirstClear) {
          // 에피소드 1: 매 스테이지마다 지급, 에피소드 2+: 5스테이지마다 지급
          let shouldGiveUnit = false;
          const stageId = this.cStage.id;
          const episode = Math.floor((stageId - 1) / 10) + 1;
          if (episode === 1) {
            shouldGiveUnit = true;
          } else {
            shouldGiveUnit = (stageId % 5 === 0);
          }

          if (shouldGiveUnit) {
            const NON_NOVICE = Object.keys(JAB).filter(k => k !== 'novice' && !k.startsWith('summon_'));
            const rCls = NON_NOVICE[Math.floor(Math.random() * NON_NOVICE.length)];
            const d = JAB[rCls];
            if (d) {
              try {
                const rd = JSON.parse(localStorage.getItem('game_roster'));
                if (rd) {
                  const g = d.growth;
                  const roll = mm => +(mm[0] + Math.random() * (mm[1] - mm[0])).toFixed(1);
                  const names = Object.keys(rd.chars.reduce((m,c) => { m[c.nameId]=1; return m }, {}));
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
                  this._firstClearUnit = ch;
                }
              } catch(_) {}
            }
          }
        }
        if (typeof LEARNABLE_SKILLS !== 'undefined' && Math.random() < 0.05) {
          const lsKeys = Object.keys(LEARNABLE_SKILLS);
          if (lsKeys.length) {
            const sk = LEARNABLE_SKILLS[lsKeys[Math.floor(Math.random() * lsKeys.length)]];
            try {
              const inv = JSON.parse(localStorage.getItem('game_inventory')) || [];
              inv.push({ id: sk.id, cls: sk.cls, lv: 1 });
              localStorage.setItem('game_inventory', JSON.stringify(inv));
              this._droppedBook = sk.id;
            } catch(_) {}
          }
        }
      }
    }

    // 연습 모드: 자동 부활 (사망 처리 없음)
    if (this.practiceMode) {
      this._autoRevivedCount = this._deadAllyUids.length;
      this._deadAllyUids = [];
    } else {
      // 일반 모드: 정상 사망 처리
      this._deadAllyUids.forEach(uid => {
        markDead(uid);
      });
    }

    clearBattle();
  },

  returnToLobby() { location.href = 'index.html' },

  goNextStage(stage) {
    const party = loadParty();
    const filteredParty = party.filter(uid => { const ch = getChar(uid); return ch && !ch.dead });
    if (filteredParty.length >= MIN_P) {
      localStorage.setItem('game_nav', JSON.stringify({ cStage: stage, party: filteredParty }));
      location.href = 'battle.html';
    } else {
      localStorage.setItem('game_nav', JSON.stringify({ cStage: stage }));
      location.href = 'party-select.html';
    }
  },
});
