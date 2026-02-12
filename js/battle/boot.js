// ═══════════════════════════════════════════
//  battle/boot.js — Init & Event Listeners
// ═══════════════════════════════════════════
window.G = G;

Object.assign(G, {
  _battleListenersInit: false,
  _initBattleListeners() {
    if (this._battleListenersInit) return;
    this._battleListenersInit = true;
    document.getElementById('minimap').addEventListener('click', e => G.mmClick(e));
    document.getElementById('map-container').addEventListener('scroll', () => G.rMMvp());
    document.getElementById('iso-world').addEventListener('click', e => {
      const w = document.getElementById('iso-world');
      const rect = w.getBoundingClientRect();
      const px = e.clientX - rect.left, py = e.clientY - rect.top;
      const hit = G.isoHit(px, py);
      if (!hit) return;
      const { c, r } = hit;
      if (c < 0 || c >= COLS || r < 0 || r >= ROWS) return;
      if (G.awPM) { G.cellCk(c, r); return }
      const u = G.uAt(c, r);
      if (u && u.team === 'ally' && !G.sel) { G.selU(u); return }
      if (u && u.team === 'ally' && G.sel && u.id === G.sel.id) { G.clrSel(); return }
      G.cellCk(c, r);
    });
  },

  // 1) 로딩 바 표시 (2초)
  _showLoading(stageName) {
    const el = document.getElementById('battle-loading');
    if (!el) return Promise.resolve();
    const nameEl = document.getElementById('bl-stage-name');
    const fillEl = document.getElementById('bl-fill');
    const tipEl = document.getElementById('bl-tip');
    if (nameEl) nameEl.textContent = stageName || t('battle.loading_title');
    const tips = t('battle.loading_tips');
    if (tipEl && Array.isArray(tips) && tips.length) tipEl.textContent = tips[Math.floor(Math.random() * tips.length)];
    el.classList.remove('hide');
    return new Promise(resolve => {
      let pct = 0;
      const iv = setInterval(() => {
        pct += 5;
        if (fillEl) fillEl.style.width = Math.min(pct, 100) + '%';
        if (pct >= 100) { clearInterval(iv); setTimeout(() => { el.classList.add('hide'); setTimeout(resolve, 400) }, 200) }
      }, 90);
    });
  },

  _hideLoading() {
    const el = document.getElementById('battle-loading');
    if (el) { el.classList.add('hide') }
  },


  _initBattlePage() {
    const nav = loadNav();
    clearNav();
    if (nav?.resume) {
      const bs = loadBattle();
      if (bs) {
        this._initBattleListeners();
        this.cStage = bs.stage; this.party = bs.party; this.practiceMode = bs.practiceMode || false;
        this.ter = bs.ter; this.turn = bs.turn; this.eSpwn = bs.eSpwn; this.eQ = bs.eQ;
        this.breached = bs.breached; this.gateHP = bs.gateHP; this.wallHP = bs.wallHP; this.nid = bs.nid;
        this.battleExp = bs.battleExp || {};
        this.allyPos = bs.allyPos || {};
        this._killCount = bs._killCount || 0; this._killExpPool = bs._killExpPool || 0; this._deadAllyUids = bs._deadAllyUids || [];
        this.units = bs.units; this.phase = 'player'; this.sel = null; this.over = false;
        this.awPM = false; this.anim = false; this.camDir = 0;
        this.siegeMode = false; this._curSiege = null; this.potionMode = false; this._curPotion = null; this.potionTargets = []; this.itemMenuOpen = false;
        this._siegeItems = bs._siegeItems || []; this._siegeInvIndices = bs._siegeInvIndices || [];
        this._battlePotions = bs._battlePotions || []; this._battlePotionIndices = bs._battlePotionIndices || [];
        document.querySelector('#cam-dir .cd-arrow').textContent = CARR[0];
        document.querySelector('#cam-dir .cd-label').textContent = CLAB[0];
        const w = document.getElementById('iso-world');
        w.querySelectorAll('.iso-tile,.unit-sprite,.float-text').forEach(e => e.remove());
        this.layW(); this.vfxInit(); this.rTer(); this.rUnits(); this.uUI(); this.defI(); this.rMM();
        this.bgmStart();
        this._hideLoading();
        setTimeout(() => this.scrollToAllies(), 50);
      } else { location.href = 'index.html' }
    } else if (nav?.cStage) {
      this.cStage = nav.cStage; this.practiceMode = nav.practiceMode || false;
      if (nav.party) { this.party = nav.party } else { this.party = loadParty() }
      if (!this.party || this.party.length < MIN_P) { location.href = 'index.html'; return }
      this._initBattleListeners();
      this.eSpwn = 0; this.eQ = [...this.cStage.en];
      this.init();
      this._showLoading(this.cStage.name).then(() => this.bgmStart());
    } else { location.href = 'index.html' }
  },
});

document.addEventListener('keydown', e => {
  if (document.body.dataset.page !== 'battle') return;
  if (e.key === 'q' || e.key === 'Q') G.rotCam(-1);
  if (e.key === 'e' || e.key === 'E') G.rotCam(1);
  if (e.key === 'Escape') { G.closeSettings() }
});

window.addEventListener('DOMContentLoaded', async () => {
  G.loadSett();
  const goldData = loadGoldData();
  G.gold = goldData.gold;
  G.cleared = goldData.cleared;

  await i18nInit();

  loadTilesets().then(() => G._initBattlePage());
});

window.addEventListener('resize', () => { if (G.ter && G.ter.length) { G.layW() } });
