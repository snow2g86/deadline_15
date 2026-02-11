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

  _initBattlePage() {
    const nav = loadNav();
    clearNav();
    if (nav?.resume) {
      const bs = loadBattle();
      if (bs) {
        this._initBattleListeners();
        this.cStage = bs.stage; this.party = bs.party;
        this.ter = bs.ter; this.turn = bs.turn; this.eSpwn = bs.eSpwn; this.eQ = bs.eQ;
        this.breached = bs.breached; this.gateHP = bs.gateHP; this.wallHP = bs.wallHP; this.nid = bs.nid;
        this.battleExp = bs.battleExp || {};
        this.allyPos = bs.allyPos || {};
        this._killCount = bs._killCount || 0; this._killExpPool = bs._killExpPool || 0; this._deadAllyUids = bs._deadAllyUids || [];
        this.units = bs.units; this.phase = 'player'; this.sel = null; this.over = false;
        this.awPM = false; this.anim = false; this.camDir = 0;
        document.querySelector('#cam-dir .cd-arrow').textContent = CARR[0];
        document.querySelector('#cam-dir .cd-label').textContent = CLAB[0];
        const w = document.getElementById('iso-world');
        w.querySelectorAll('.iso-tile,.unit-sprite,.float-text').forEach(e => e.remove());
        this.layW(); this.vfxInit(); this.rTer(); this.rUnits(); this.uUI(); this.defI(); this.rMM();
        this.bgmStart();
        setTimeout(() => this.scrollToAllies(), 50);
      } else { location.href = 'index.html' }
    } else if (nav?.cStage) {
      this.cStage = nav.cStage;
      if (nav.party) { this.party = nav.party } else { this.party = loadParty() }
      if (!this.party || this.party.length < MIN_P) { location.href = 'index.html'; return }
      this._initBattleListeners();
      this.eSpwn = 0; this.eQ = [...this.cStage.en];
      this.init();
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
