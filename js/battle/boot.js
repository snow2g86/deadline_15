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
    const meleeCols = FORM_COLS, rangedCols = FORM_COLS;   // 가운데부터 바깥으로
    let meleeIdx = 0, rangedIdx = 0;
    for (let i = 0; i < S.party.length; i++) {
      const uid = S.party[i], ch = getChar(uid); if (!ch || ch.cls === COMMANDER_CLS) continue;   // 지휘관은 스토리 전용 (전투 불참)
      const role = ROLE_MAP[ch.cls], isRanged = role === 'ranged' || role === 'healer';
      const cols = isRanged ? rangedCols : meleeCols;
      const idx = isRanged ? rangedIdx++ : meleeIdx++;
      if (idx < cols.length) { const x = cols[idx], y = isRanged ? 12 : 11; UnitManager.addUnit('ally', uid, x, y); }
    }

    // 클래스 조합 버프 (파티 광역): 출전한 클랜원 직업 구성으로 정해져 전투 내내 유지
    S._synergies = Synergy.compute(S.units.filter(u => u.team === 'ally').map(u => u.cls));
    Synergy.apply(S.units, S._synergies);
    // 맵 환경 디버프 (마법부여로 막은 클랜원 제외) + 보물상자
    S._hazard = Hazard.apply(S.units, S.cStage);
    Chest.place(S);

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
    S.ter = bs.ter; S.turn = bs.turn || 1; S._turnActed = bs._turnActed || {}; S.eSpwn = bs.eSpwn; S.eQ = bs.eQ;
    S.breached = bs.breached; S.gateHP = bs.gateHP; S.wallHP = bs.wallHP; S.nid = bs.nid;
    S.battleExp = bs.battleExp || {};
    S.allyPos = bs.allyPos || {};
    S._killCount = bs._killCount || 0; S._killExpPool = bs._killExpPool || 0; S._deadAllyUids = bs._deadAllyUids || [];
    S.units = bs.units; S._synergies = bs._synergies || []; S._hazard = Hazard.forStage(bs.stage); S.chests = bs.chests || [];   // 조합 버프는 저장된 유닛 스탯에 이미 반영됨
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

    // 전투 시작 음악 재생 (설정에서 꺼져 있으면 bgmStart가 무시)
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
      // 맵 크기가 바뀌기 전에 저장된 전투는 이어 할 수 없음 → 같은 스테이지·파티로 새로 시작
      if (bs && bs.ter && bs.ter[0] && bs.ter[0].length !== COLS) {
        clearBattle(); GameStore.cStage = bs.stage; GameStore.practiceMode = bs.practiceMode || false;
        GameStore.party = bs.party || loadParty(); this.initBattle();
        this._showLoading(GameStore.cStage.name).then(() => { Audio.bgmStart(); TurnManager.nextAction(); });
      } else if (bs) this.resumeBattle(bs);
      else location.href = 'index.html';
    } else if (nav?.cStage) {
      GameStore.cStage = nav.cStage; GameStore.practiceMode = nav.practiceMode || false;
      if (nav.party) GameStore.party = nav.party; else GameStore.party = loadParty();
      if (!GameStore.party || GameStore.party.length < MIN_P) { location.href = 'index.html'; return; }
      this.initBattle();
      this._showLoading(GameStore.cStage.name).then(() => { Audio.bgmStart(); TurnManager.nextAction(); });
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
  if ((e.key === 't' || e.key === 'T') && !e.ctrlKey && !e.metaKey && !(e.target.closest && e.target.closest('input,textarea,select'))) Renderer.toggleThreat();
  // 행동 메뉴 단축키: 메뉴에 표시된 data-key 버튼을 그대로 클릭 (M/A/S/I/W, 서브메뉴 1~9, Esc/Backspace 취소)
  const m = document.getElementById('action-menu');
  if (!m || !m.classList.contains('show') || e.repeat || e.ctrlKey || e.metaKey || e.altKey) return;
  if (e.target.closest && e.target.closest('input,textarea,select')) return;
  const k = (e.key === 'Escape' || e.key === 'Backspace') ? 'esc' : e.key === ' ' ? 'w' : e.key.toLowerCase();
  const btn = [...m.querySelectorAll('button[data-key]')].find(b => b.dataset.key === k && b.style.display !== 'none' && !b.disabled);
  if (btn) { e.preventDefault(); btn.click(); }
});

// ── 페이지 로드 ──
window.addEventListener('DOMContentLoaded', async () => {
  Renderer.loadSett();
  const goldData = loadGoldData();
  GameStore.gold = goldData.gold;
  GameStore.cleared = goldData.cleared;

  await i18nInit();
  const threatBtn = document.getElementById('threat-btn');
  if (threatBtn) threatBtn.title = t('battle.threat_title');

  loadTilesets().then(() => BattleInit._initBattlePage());
});

// ── 리사이즈 ──
window.addEventListener('resize', () => {
  if (GameStore.ter && GameStore.ter.length) Grid.layWorld();
});

// ── 마우스 드래그로 맵 이동 (터치는 기본 스크롤 사용) ──
window.addEventListener('DOMContentLoaded', () => {
  const ct = document.getElementById('map-container'); if (!ct) return;
  let drag = null;
  ct.addEventListener('pointerdown', e => {
    if (e.pointerType !== 'mouse' || e.button !== 0) return;
    drag = { x: e.clientX, y: e.clientY, sl: ct.scrollLeft, st: ct.scrollTop, moved: false };
  });
  window.addEventListener('pointermove', e => {
    if (!drag) return;
    const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
    if (!drag.moved && Math.hypot(dx, dy) < 6) return; // 작은 흔들림은 클릭으로 취급
    drag.moved = true; ct.classList.add('panning');
    ct.scrollLeft = drag.sl - dx; ct.scrollTop = drag.st - dy;
  });
  window.addEventListener('pointerup', () => {
    if (drag && drag.moved) {
      // 드래그 직후의 click은 타일 선택으로 처리되지 않도록 한 번 막는다
      ct.addEventListener('click', ev => { ev.stopPropagation(); ev.preventDefault(); }, { capture: true, once: true });
      setTimeout(() => ct.classList.remove('panning'), 0);
    }
    drag = null;
  });
});
