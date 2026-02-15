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

function saveGold(gold) {
  try {
    const d = JSON.parse(localStorage.getItem(SAVE_KEY)) || {};
    d.gold = gold;
    localStorage.setItem(SAVE_KEY, JSON.stringify(d));
  } catch (_) {}
}

// ── Roster 데이터 ────────────────────────────
function getRoster() {
  try {
    const raw = localStorage.getItem(ROSTER_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}
  return { chars: [], nextId: 1 };
}

function saveRoster(data) {
  try {
    localStorage.setItem(ROSTER_KEY, JSON.stringify(data));
  } catch (_) {}
}

// ── Party 데이터 (레거시 - 마이그레이션용) ────────────────────────────
function loadParty() {
  try {
    const r = localStorage.getItem(PARTY_KEY);
    if (r) return JSON.parse(r);
  } catch (_) {}
  return [];
}

function saveParty(party) {
  try {
    localStorage.setItem(PARTY_KEY, JSON.stringify(party));
  } catch (_) {}
}

// ── Multi-Party 데이터 (신규) ────────────────────────────
function loadParties() {
  try {
    const raw = localStorage.getItem(PARTIES_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}

  // 첫 로드: 레거시 데이터 마이그레이션
  const oldParty = loadParty();
  const newData = {
    parties: [
      { id: 1, name: '파티 1', slots: oldParty && oldParty.length > 0 ? oldParty : [null, null, null, null, null] },
      { id: 2, name: '파티 2', slots: [null, null, null, null, null] }
    ],
    activePartyId: 1,
    nextPartyId: 3
  };

  // 마이그레이션 완료 후 레거시 키 삭제
  saveParties(newData);
  try {
    localStorage.removeItem(PARTY_KEY);
  } catch (_) {}

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
