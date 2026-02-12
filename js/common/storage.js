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

// ── Party 데이터 ────────────────────────────
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
