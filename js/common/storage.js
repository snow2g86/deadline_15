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
      if (needsSave) {
        try { localStorage.setItem(ROSTER_KEY, JSON.stringify(roster)); } catch (_) {}
      }
      return roster;
    }
  } catch (_) {}
  return { chars: [], nextId: 1 };
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

function saveParties(data) {
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
