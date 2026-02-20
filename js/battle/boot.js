// ═══════════════════════════════════════════
//  battle/boot.js — Init, G Proxy shim, loading screen
// ═══════════════════════════════════════════

// ── G 호환성 Proxy ──
// 기존 스킬 핸들러(28개)가 G.floatT(), G.vfxSpawn() 등을 직접 호출하므로
// 새 모듈 구조로 자동 위임하는 Proxy 제공
const _G_ALIASES = {
  layW:     function() { return Grid.layWorld(); },
  addU:     function(team, src, x, y) { return UnitManager.addUnit(team, src, x, y); },
  _rmDead:  function() { return UnitManager.rmDead(); },
  spawnW:   function() { return TurnManager.spawnWave(); },
  vfxInit:  function() { return VFX.init(); },
  atkC:     function(u) { return Grid.atkCells(u); },
  alive:    function(team) { return UnitManager.alive(team); },
  vfxSpawn: function(x, y, opts) { return VFX.spawn(x, y, opts); },
  get awPM() { return FSM.isPlayerTurn(); },
  get over() { return FSM.is(BattleState.BATTLE_END); },
};

const _G_MODULES = [
  GameStore, ActionManager, Renderer, VFX, Audio,
  Grid, UnitManager, TurnManager, BuffSystem, BattleEnd
];

window.G = new Proxy({}, {
  get(target, prop) {
    if (prop === Symbol.toPrimitive || prop === 'toJSON') return undefined;
    // 1. Explicit aliases (renamed methods / computed properties)
    if (prop in _G_ALIASES) {
      const v = Object.getOwnPropertyDescriptor(_G_ALIASES, prop);
      if (v && v.get) return v.get();
      return _G_ALIASES[prop];
    }
    // 2. Search modules in priority order
    for (const mod of _G_MODULES) {
      if (prop in mod) {
        const val = mod[prop];
        return typeof val === 'function' ? val.bind(mod) : val;
      }
    }
    // 3. Dynamic properties stored on target
    return target[prop];
  },
  set(target, prop, val) {
    if (prop in GameStore) { GameStore[prop] = val; return true; }
    target[prop] = val;
    return true;
  }
});

// ── BattleInit singleton ──
const BattleInit = {
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
        if (pct >= 100) { clearInterval(iv); setTimeout(() => { el.classList.add('hide'); setTimeout(resolve, 400); }, 200); }
      }, 90);
    });
  },

  _hideLoading() {
    const el = document.getElementById('battle-loading');
    if (el) el.classList.add('hide');
  },

  // ── 새 전투 초기화 ──
  initBattle() {
    const S = GameStore;
    // 상태 리셋
    S.reset();

    // 적 대기열 생성 (스테이지 en[] 배열에서)
    if (S.cStage && S.cStage.en) {
      S.eQ = [...S.cStage.en];
      shuffle(S.eQ);
    }

    // 지형 생성
    Grid.genT(); Grid._initTColors();

    // 인벤토리 아이템 로드 (물약, 공성)
    if (typeof loadInventory === 'function') {
      const inv = loadInventory();
      for (let i = 0; i < inv.length; i++) {
        if (inv[i].type === 'battle_potion') { S._battlePotions.push(inv[i]); S._battlePotionIndices.push(i); }
        else if (inv[i].type === 'siege') { S._siegeItems.push(inv[i]); S._siegeInvIndices.push(i); }
      }
    }

    // 카메라 방향 UI
    document.querySelector('#cam-dir .cd-arrow').textContent = CARR[0];
    document.querySelector('#cam-dir .cd-label').textContent = CLAB[0];

    // 이전 DOM 제거
    const w = document.getElementById('iso-world');
    w.querySelectorAll('.iso-tile,.iso-tile-bg,.iso-tile-hl,.unit-sprite,.float-text').forEach(e => e.remove());
    Renderer._bgReady = false; Renderer._hlTiles = new Map();

    // 파티 유닛 배치 (역할 기반)
    const meleeCols = [3, 4, 5, 6, 7], rangedCols = [3, 4, 5, 6, 7];
    let meleeIdx = 0, rangedIdx = 0;
    for (let i = 0; i < S.party.length; i++) {
      const uid = S.party[i], ch = getChar(uid); if (!ch) continue;
      const role = ROLE_MAP[ch.cls], isRanged = role === 'ranged' || role === 'healer';
      const cols = isRanged ? rangedCols : meleeCols;
      const idx = isRanged ? rangedIdx++ : meleeIdx++;
      if (idx < cols.length) { const x = cols[idx], y = isRanged ? 12 : 11; UnitManager.addUnit('ally', uid, x, y); }
    }

    // 첫 웨이브 스폰
    TurnManager.spawnWave();

    // 레이아웃, 모듈 초기화, 렌더링
    Grid.layWorld();
    VFX.init(); Renderer.init(); Audio.init();
    Renderer.rTerBg(); Renderer.rTer(); Renderer.rUnits();
    Renderer.uUI(); Renderer.defI(); Renderer.rMM();

    setTimeout(() => Renderer.scrollToAllies(), 50);
  },

  // ── 저장된 전투 복원 ──
  resumeBattle(bs) {
    const S = GameStore;
    S.cStage = bs.stage; S.party = bs.party; S.practiceMode = bs.practiceMode || false;
    S.ter = bs.ter; S.turn = bs.turn; S.eSpwn = bs.eSpwn; S.eQ = bs.eQ;
    S.breached = bs.breached; S.gateHP = bs.gateHP; S.wallHP = bs.wallHP; S.nid = bs.nid;
    S.battleExp = bs.battleExp || {};
    S.allyPos = bs.allyPos || {};
    S._killCount = bs._killCount || 0; S._killExpPool = bs._killExpPool || 0; S._deadAllyUids = bs._deadAllyUids || [];
    S.units = bs.units;
    S.units.forEach(u => {
      if (!u.actionRec) u.actionRec = JAB[u.cls]?.actionRec || 1.0;
      if (u.actionPow == null) u.actionPow = 0;
    });
    S.sel = null;
    S._siegeItems = bs._siegeItems || []; S._siegeInvIndices = bs._siegeInvIndices || [];
    S._battlePotions = bs._battlePotions || []; S._battlePotionIndices = bs._battlePotionIndices || [];

    // 카메라 방향 UI
    document.querySelector('#cam-dir .cd-arrow').textContent = CARR[0];
    document.querySelector('#cam-dir .cd-label').textContent = CLAB[0];

    // 이전 DOM 제거
    const w = document.getElementById('iso-world');
    w.querySelectorAll('.iso-tile,.iso-tile-bg,.iso-tile-hl,.unit-sprite,.float-text').forEach(e => e.remove());

    // 레이아웃, 모듈 초기화, 렌더링
    Grid.layWorld();
    VFX.init(); Renderer.init(); Audio.init();
    Renderer.rTerBg(); Renderer.rTer(); Renderer.rUnits();
    Renderer.uUI(); Renderer.defI(); Renderer.rMM();

    // 전투 시작 음악 재생
    GameStore._sett.bgmOn = true;
    Audio.bgmStart();
    this._hideLoading();

    setTimeout(() => { Renderer.scrollToAllies(); TurnManager.nextAction(); }, 50);
  },

  // ── 배틀 페이지 진입 ──
  _initBattlePage() {
    const nav = loadNav();
    clearNav();
    if (nav?.resume) {
      const bs = loadBattle();
      if (bs) this.resumeBattle(bs);
      else location.href = 'index.html';
    } else if (nav?.cStage) {
      GameStore.cStage = nav.cStage; GameStore.practiceMode = nav.practiceMode || false;
      if (nav.party) GameStore.party = nav.party; else GameStore.party = loadParty();
      if (!GameStore.party || GameStore.party.length < MIN_P) { location.href = 'index.html'; return; }
      this.initBattle();
      this._showLoading(GameStore.cStage.name).then(() => { GameStore._sett.bgmOn = true; Audio.bgmStart(); TurnManager.nextAction(); });
    } else {
      location.href = 'index.html';
    }
  },
};

// ── 키보드 이벤트 ──
document.addEventListener('keydown', e => {
  if (document.body.dataset.page !== 'battle') return;
  if (e.key === 'q' || e.key === 'Q') Renderer.rotCam(-1);
  if (e.key === 'e' || e.key === 'E') Renderer.rotCam(1);
  if (e.key === 'Escape') Renderer.closeSettings();
});

// ── 페이지 로드 ──
window.addEventListener('DOMContentLoaded', async () => {
  Renderer.loadSett();
  const goldData = loadGoldData();
  GameStore.gold = goldData.gold;
  GameStore.cleared = goldData.cleared;

  await i18nInit();

  loadTilesets().then(() => BattleInit._initBattlePage());
});

// ── 리사이즈 ──
window.addEventListener('resize', () => {
  if (GameStore.ter && GameStore.ter.length) Grid.layWorld();
});
