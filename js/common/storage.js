// js/common/storage.js — localStorage 접근 함수
// 모든 localStorage 읽기/쓰기 함수를 중앙화합니다

// ── Save 데이터 ────────────────────────────
function loadSave() {
  try {
    const d = JSON.parse(localStorage.getItem(SAVE_KEY));
    if (d) return d;
  } catch (_) {}
  return {};
}

function saveSave(data) {
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify(data));
  } catch (_) {}
}

function loadGold() {
  try {
    const d = JSON.parse(localStorage.getItem(SAVE_KEY));
    if (d) return d.gold || 0;
  } catch (_) {}
  return 0;
}

function saveGold(gold, cleared) {
  try {
    const d = JSON.parse(localStorage.getItem(SAVE_KEY)) || {};
    d.gold = gold;
    if (cleared) d.cleared = cleared;
    localStorage.setItem(SAVE_KEY, JSON.stringify(d));
  } catch (_) {}
}

// ── 스테이지 별점 ────────────────────────────
// game_save.stars = { [stageId]: [클리어, 전사자 없음, N턴 이내] } (0/1). 조건별로 따로 누적
function starTurnLimit(stage) {
  if (!stage) return 0;
  return stage.starTurns || Math.ceil((stage.tot || 6) * 0.75) + 4;
}

function loadStars() { return loadSave().stars || {}; }

function stageStars(stageId) { return (loadStars()[stageId] || [0, 0, 0]).reduce((a, b) => a + (b ? 1 : 0), 0); }

// 이번 판 결과(flags)를 합쳐 저장하고, 새로 얻은 별 인덱스를 반환
function saveStageStars(stageId, flags) {
  const d = loadSave();
  d.stars = d.stars || {};
  const prev = d.stars[stageId] || [0, 0, 0];
  const merged = prev.map((v, i) => (v || flags[i]) ? 1 : 0);
  const newly = merged.map((v, i) => v && !prev[i] ? i : -1).filter(i => i >= 0);
  d.stars[stageId] = merged;
  saveSave(d);
  return { merged, newly };
}

// ── Roster 데이터 ────────────────────────────
function getRoster() {
  try {
    const raw = localStorage.getItem(ROSTER_KEY);
    if (raw) {
      const roster = JSON.parse(raw);
      // 마이그레이션: pot 및 actionRec 필드 추가
      let needsSave = false;
      if (roster.chars && Array.isArray(roster.chars)) {
        for (const ch of roster.chars) {
          if (ch && typeof ch === 'object') {
            // pot 필드 없으면 생성 (잠재력이 없는 구 캐릭터)
            if (!ch.pot) {
              const g = JAB[ch.cls] && JAB[ch.cls].growth;
              if (g) {
                ch.pot = {
                  hp: +(g.hp[0] + (g.hp[1] - g.hp[0]) * 0.5).toFixed(1),
                  atk: +(g.atk[0] + (g.atk[1] - g.atk[0]) * 0.5).toFixed(1),
                  def: +(g.def[0] + (g.def[1] - g.def[0]) * 0.5).toFixed(1),
                  actionRec: rollActionRec()
                };
                needsSave = true;
              }
            }
            // pot.actionRec 필드 없으면 추가 (기존 pot 객체)
            if (ch.pot && !ch.pot.actionRec) {
              ch.pot.actionRec = rollActionRec();
              needsSave = true;
            }
            // actionRec 필드 없으면 생성
            if (!ch.actionRec) {
              const baseRec = (JAB[ch.cls] && JAB[ch.cls].actionRec) || 1.0;
              ch.actionRec = baseRec + (ch.pot && ch.pot.actionRec || 0);
              needsSave = true;
            }
          }
        }
      }
      // 지휘관이 버퍼(마에스트로)로 바뀌기 전 세이브: 능력치를 새 기준(기본값 + 레벨별 잠재력 성장)으로 다시 계산
      if (roster.chars && typeof JAB !== 'undefined' && JAB[COMMANDER_CLS]) {
        roster.chars.forEach(c => {
          if (!c || c.cls !== COMMANDER_CLS || c.buffer === 2) return;
          const d = JAB[COMMANDER_CLS], lv = (c.lv || 1) - 1, p = c.pot || {};
          c.hp = Math.round(d.base.hp + lv * (p.hp || 8)); c.atk = Math.round(d.base.atk + lv * (p.atk || 1.5));
          c.def = Math.round(d.base.def + lv * (p.def || 0.6)); c.move = d.base.move; c.range = d.base.range;
          c.buffer = 2; needsSave = true;
        });
      }
      // 지휘관(고유 주인공)이 없으면 추가 — 기존 세이브 포함 1명만
      if (roster.chars && roster.chars.length && typeof JAB !== 'undefined' && JAB[COMMANDER_CLS] &&
          !roster.chars.some(c => c && c.cls === COMMANDER_CLS)) {
        roster.chars.unshift(_newCommander(roster.nextId++));
        needsSave = true;
      }
      if (needsSave) {
        try { localStorage.setItem(ROSTER_KEY, JSON.stringify(roster)); } catch (_) {}
      }
      return roster;
    }
  } catch (_) {}
  return { chars: [], nextId: 1 };
}

// 지휘관 캐릭터 생성 (잠재력은 성장 범위의 중간, 성별 기본 남 — 파티 화면에서 바꿀 수 있음)
function _newCommander(uid) {
  const d = JAB[COMMANDER_CLS], g = d.growth, mid = mm => +(mm[0] + (mm[1] - mm[0]) * 0.6).toFixed(1);
  const pot = { hp: mid(g.hp), atk: mid(g.atk), def: mid(g.def), actionRec: 0.12 };
  return { uid, cls: COMMANDER_CLS, nameId: null, customName: COMMANDER_DEFAULT_NAME, lv: 1, exp: 0, dead: false,
    hp: d.base.hp, atk: d.base.atk, def: d.base.def, move: d.base.move, range: d.base.range,
    pot, actionRec: d.actionRec + pot.actionRec, gender: 'm', buffer: 2 };
}
// 지휘관 uid (없으면 null)
function commanderUid() {
  const c = getRoster().chars.find(ch => ch && ch.cls === COMMANDER_CLS);
  return c ? c.uid : null;
}

function saveRoster(data) {
  try {
    localStorage.setItem(ROSTER_KEY, JSON.stringify(data));
  } catch (_) {}
}

// ── Party 데이터 ────────────────────────────
// 파티 저장소는 game_parties(다중 파티) 하나뿐. game_party(단일 목록)는 예전 세이브 마이그레이션용으로만 읽는다.
// 기본 구조: 파티 5개(id 1~5), 5슬롯 고정. 표시 이름은 화면에서 t('party.party_n')로 만든다.
function createDefaultParties(firstSlots) {
  const slots = (firstSlots || []).slice(0, 5);
  while (slots.length < 5) slots.push(null);
  const parties = [{ id: 1, slots: slots }];
  for (let i = 2; i <= 5; i++) parties.push({ id: i, slots: [null, null, null, null, null] });
  return { parties: parties, activePartyId: 1, nextPartyId: 6 };
}

function _loadLegacyParty() {
  try {
    const r = localStorage.getItem(PARTY_KEY);
    if (r) { const p = JSON.parse(r); if (Array.isArray(p)) return p; }
  } catch (_) {}
  return [];
}

// 하위 호환 API: 활성 파티의 UID 배열 (빈 슬롯 제외)
function loadParty() { return getActiveParty(); }

// 하위 호환 API: 활성 파티의 슬롯을 주어진 UID 배열로 교체
function saveParty(party) {
  const data = loadParties();
  const active = data.parties.find(p => p.id === data.activePartyId) || data.parties[0];
  const slots = (party || []).slice(0, 5);
  while (slots.length < 5) slots.push(null);
  active.slots = slots;
  saveParties(data);
}

// ── Multi-Party 데이터 ────────────────────────────
function loadParties() {
  try {
    const raw = localStorage.getItem(PARTIES_KEY);
    if (raw) {
      const d = JSON.parse(raw);
      if (d && Array.isArray(d.parties) && d.parties.length) {
        // 활성 파티 id가 실제로 없으면(예: 예전 세이브의 id 0) 첫 파티로 맞춤
        if (!d.parties.some(p => p.id === d.activePartyId)) d.activePartyId = d.parties[0].id;
        if (_dropCommander(d)) saveParties(d);
        if (typeof d.nextPartyId !== 'number') {
          // 예전 첫 실행 세이브(파티 1개, nextPartyId 없음) → 새 게임과 같은 5파티 구조로 채움
          let next = Math.max(...d.parties.map(p => +p.id || 0)) + 1;
          while (d.parties.length < 5) d.parties.push({ id: next++, slots: [null, null, null, null, null] });
          d.nextPartyId = next;
          saveParties(d);
        }
        return d;
      }
    }
  } catch (_) {}

  // 첫 로드: 예전 단일 파티(game_party) 마이그레이션 후 레거시 키 삭제
  const newData = createDefaultParties(_loadLegacyParty());
  saveParties(newData);
  try { localStorage.removeItem(PARTY_KEY); } catch (_) {}
  return newData;
}

// 지휘관은 스토리에만 등장하고 전투에는 나가지 않음 → 모든 파티에서 빼고 빈 칸은 뒤로
// (예전 세이브는 지휘관이 첫 칸에 고정돼 있었음)
function _dropCommander(data) {
  const cu = commanderUid(); if (cu == null || !data || !data.parties) return false;
  let changed = false;
  data.parties.forEach(p => {
    if (!p.slots || p.slots.indexOf(cu) === -1) return;
    p.slots = p.slots.filter(s => s !== cu);
    while (p.slots.length < 5) p.slots.push(null);
    changed = true;
  });
  return changed;
}

function saveParties(data) {
  _dropCommander(data);
  try {
    localStorage.setItem(PARTIES_KEY, JSON.stringify(data));
  } catch (_) {}
}

function getActiveParty() {
  // 전투 시스템용: 활성 파티의 UID 배열 반환 (레거시 호환)
  const parties = loadParties();
  const activePartyId = parties.activePartyId;
  const activeParty = parties.parties.find(p => p.id === activePartyId);
  return (activeParty && activeParty.slots) ? activeParty.slots.filter(uid => uid !== null) : [];
}

// ── Nav 데이터 ────────────────────────────
function loadNav() {
  try {
    return JSON.parse(localStorage.getItem(NAV_KEY));
  } catch (_) {
    return null;
  }
}

function saveNav(data) {
  try {
    localStorage.setItem(NAV_KEY, JSON.stringify(data));
  } catch (_) {}
}

function clearNav() {
  try {
    localStorage.removeItem(NAV_KEY);
  } catch (_) {}
}

// ── Inventory 데이터 ────────────────────────────
function loadInventory() {
  try {
    const raw = localStorage.getItem(INVENTORY_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}
  return [];
}

function saveInventory(inv) {
  try {
    localStorage.setItem(INVENTORY_KEY, JSON.stringify(inv));
  } catch (_) {}
}
