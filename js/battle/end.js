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
      const reward = 50 + (this.cStage ? this.cStage.id * 30 : 0);
      this.gold += reward;
      if (this.cStage) this.cleared.add(this.cStage.id);
      saveGold(this.gold, [...this.cleared]);
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
    this._deadAllyUids.forEach(uid => {
      markDead(uid);
    });
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
