// party-select.js — 파티 편성 페이지 전용 스크립트
// G/ROSTER/CD 의존 없이 JAB + localStorage 직접 조작

// ── 상수 ──────────────────────────────────
var MIN_P = 5, MAX_P = 5;
var MAX_LEVEL = 15;
var ROSTER_KEY = 'game_roster';
var PARTY_KEY = 'game_party';
var NAV_KEY = 'game_nav';
var SAVE_KEY = 'game_save';

function expForLevel(lv) { return 80 + 20 * lv + 5 * lv * lv; }

// 역할 매핑 (JAB에 role 필드가 없으므로 직접 정의)
var ROLE_MAP = {
  warrior: 'melee', knight: 'melee', assassin: 'melee',
  novice: 'melee', brawler: 'melee', lancer: 'melee', sapper: 'melee',
  mage: 'ranged', archer: 'ranged', summoner: 'ranged', shaman: 'ranged',
  priest: 'healer'
};

var ROLE_I18N = { melee: 'roles.melee', ranged: 'roles.ranged', healer: 'roles.healer' };

// ── localStorage 조작 ────────────────────
function getRoster() {
  try {
    var raw = localStorage.getItem(ROSTER_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}
  return { chars: [], nextId: 1 };
}

function saveRoster(data) {
  try { localStorage.setItem(ROSTER_KEY, JSON.stringify(data)); } catch (_) {}
}

function loadParty() {
  try {
    var r = localStorage.getItem(PARTY_KEY);
    if (r) return JSON.parse(r);
  } catch (_) {}
  return [];
}

function saveParty(party) {
  try { localStorage.setItem(PARTY_KEY, JSON.stringify(party)); } catch (_) {}
}

function loadNav() {
  try { return JSON.parse(localStorage.getItem(NAV_KEY)); } catch (_) { return null; }
}

function saveNav(data) {
  try { localStorage.setItem(NAV_KEY, JSON.stringify(data)); } catch (_) {}
}

function loadGold() {
  try {
    var d = JSON.parse(localStorage.getItem(SAVE_KEY));
    if (d) return d.gold || 0;
  } catch (_) {}
  return 0;
}

function saveGold(gold) {
  try {
    var d = JSON.parse(localStorage.getItem(SAVE_KEY)) || {};
    d.gold = gold;
    localStorage.setItem(SAVE_KEY, JSON.stringify(d));
  } catch (_) {}
}

function getChar(uid) {
  var roster = getRoster();
  return roster.chars.find(function(c) { return c.uid === uid; });
}

function potGrade(ch) {
  var g = JAB[ch.cls].growth;
  var scores = ['hp', 'atk', 'def'].map(function(k) {
    var mn = g[k][0], mx = g[k][1], rng = mx - mn;
    return rng > 0 ? (ch.pot[k] - mn) / rng : 0.5;
  });
  var avg = scores.reduce(function(a, b) { return a + b; }, 0) / scores.length;
  if (avg >= 0.85) return 'S';
  if (avg >= 0.65) return 'A';
  if (avg >= 0.35) return 'B';
  return 'C';
}

// ── 페이지 상태 ──────────────────────────
var _party = [];
var _cStage = null;
var _pFilter = 'all';

// ── 뒤로가기 ────────────────────────────
function partyBack() {
  if (_cStage) location.href = 'stage-select.html';
  else location.href = 'index.html';
}

// ── 출격 확인 ────────────────────────────
function confirmP() {
  if (_party.length < MIN_P) return;
  saveNav({ cStage: _cStage, party: _party });
  location.href = 'battle.html';
}

// ── 파티 슬롯 제거 ──────────────────────
function pRemAt(i) {
  _party.splice(i, 1);
  renderParty();
}

// ── 캐릭터 방출 ─────────────────────────
function releaseChar(uid) {
  uid = +uid;
  var ch = getChar(uid);
  if (!ch) return;
  var roster = getRoster();
  var alive = roster.chars.filter(function(c) { return !c.dead; });
  if (alive.length <= 5) {
    showAlert(t('messages.minimum_characters'));
    return;
  }
  if (_party.indexOf(uid) !== -1) {
    showAlert(t('messages.cannot_release_party'));
    return;
  }
  var price = 30 + ch.lv * 5;
  var grade = potGrade(ch);
  var d = JAB[ch.cls];
  var names = t('character.names');
  var charName = names[ch.nameId] || d.icon;
  showConfirm(
    d.icon + ' ' + charName + ' (Lv.' + ch.lv + ' ' + grade + t('class_change.grade_suffix') + ')\n\n' +
    t('messages.confirm_release', { gold: price }),
    function() {
      var roster = getRoster();
      roster.chars = roster.chars.filter(function(c) { return c.uid !== uid; });
      saveRoster(roster);
      var gold = loadGold();
      gold += price;
      saveGold(gold);
      renderParty();
    }
  );
}

// ── 필터 변경 ────────────────────────────
function filterBy(key) {
  _pFilter = key;
  renderParty();
}

// ── 파티 렌더링 (lobby.js rP() 대체) ────
function renderParty() {
  var roster = getRoster();
  var inParty = {};
  _party.forEach(function(uid) { inParty[uid] = true; });
  var alive = roster.chars.filter(function(c) { return !c.dead && !c.cls.startsWith('summon_'); });

  // ── 탭 렌더링 ──
  var tabEl = document.getElementById('ps-tabs');
  if (tabEl) {
    var ownedRoles = {};
    var ownedClasses = {};
    alive.forEach(function(c) {
      var role = ROLE_MAP[c.cls];
      if (role) ownedRoles[role] = true;
      ownedClasses[c.cls] = true;
    });
    tabEl.innerHTML = '';
    // 전체 탭
    var allBtn = document.createElement('button');
    allBtn.className = 'ps-tab' + (_pFilter === 'all' ? ' active' : '');
    allBtn.textContent = t('party.filter_all');
    allBtn.onclick = function() { filterBy('all'); };
    tabEl.appendChild(allBtn);
    // 역할 탭
    ['melee', 'ranged', 'healer'].forEach(function(r) {
      if (!ownedRoles[r]) return;
      var btn = document.createElement('button');
      btn.className = 'ps-tab' + (_pFilter === 'role_' + r ? ' active' : '');
      btn.textContent = t(ROLE_I18N[r]);
      btn.onclick = function() { filterBy('role_' + r); };
      tabEl.appendChild(btn);
    });
    // 클래스 탭
    Object.keys(JAB).forEach(function(cls) {
      if (!ownedClasses[cls] || cls.startsWith('summon_')) return;
      var btn = document.createElement('button');
      btn.className = 'ps-tab' + (_pFilter === 'cls_' + cls ? ' active' : '');
      btn.textContent = t('classes.' + cls);
      btn.onclick = function() { filterBy('cls_' + cls); };
      tabEl.appendChild(btn);
    });
  }

  // ── 필터링 ──
  var filtered = alive;
  if (_pFilter.startsWith('role_')) {
    var role = _pFilter.slice(5);
    filtered = alive.filter(function(c) { return ROLE_MAP[c.cls] === role; });
  } else if (_pFilter.startsWith('cls_')) {
    var cls = _pFilter.slice(4);
    filtered = alive.filter(function(c) { return c.cls === cls; });
  }

  // ── 정렬: 클래스별 → 레벨 내림차순 → 이름순 ──
  var clsOrder = Object.keys(JAB);
  var names = t('character.names');
  filtered.sort(function(a, b) {
    var ci = clsOrder.indexOf(a.cls) - clsOrder.indexOf(b.cls);
    if (ci !== 0) return ci;
    if (b.lv !== a.lv) return b.lv - a.lv;
    var aName = names[a.nameId] || '';
    var bName = names[b.nameId] || '';
    return aName.localeCompare(bName);
  });

  // ── 로스터 리스트 렌더링 ──
  var ro = document.getElementById('ps-roster'); ro.innerHTML = '';
  filtered.forEach(function(ch) {
    var sel = !!inParty[ch.uid];
    var d = JAB[ch.cls];
    var grade = potGrade(ch);
    var gClr = grade === 'S' ? '#f0c040' : grade === 'A' ? '#60a5fa' : grade === 'B' ? '#4ade80' : '#9ca3af';
    var atMax = ch.lv >= MAX_LEVEL;
    var expNeed = atMax ? 1 : expForLevel(ch.lv);
    var expPct = atMax ? 100 : Math.min(100, Math.round(((ch.exp || 0) / expNeed) * 100));
    var row = document.createElement('div');
    row.className = 'rl-row' + (sel ? ' selected' : '');
    var charName = names[ch.nameId] || d.icon;
    row.innerHTML =
      '<div class="rl-icon"><span class="cls-icon" style="font-size:30px">' + d.icon + '</span></div>' +
      '<div class="rl-info">' +
      '<div class="rl-top"><span class="rl-name">' + charName + '</span><span class="rl-lv">Lv.' + ch.lv + '</span>' +
      '<span class="rl-grade" style="color:' + gClr + '">' + grade + '</span></div>' +
      '<div class="rl-stats">HP <b>' + ch.hp + '</b> ATK <b>' + ch.atk + '</b> DEF <b>' + ch.def + '</b> MOV <b>' + ch.move + '</b> RNG <b>' + ch.range + '</b></div>' +
      '<div class="rl-pot">' + t('party.potential_stats', { hp: ch.pot.hp, atk: ch.pot.atk, def: ch.pot.def }) + '</div>' +
      '<div class="rl-exp"><div class="rl-exp-fill" style="width:' + expPct + '%"></div></div>' +
      '</div>' +
      '<div class="rl-actions">' +
      '<div class="rl-btn ' + (sel ? 'chk' : 'add') + '">' + (sel ? '\u2713' : '+') + '</div>' +
      '<button class="rl-release" onclick="event.stopPropagation();releaseChar(' + ch.uid + ')">' + t('party.release') + '</button>' +
      '</div>';
    row.onclick = (function(chUid, wasSel) {
      return function() {
        if (wasSel) {
          _party = _party.filter(function(u) { return u !== chUid; });
        } else if (_party.length < MAX_P) {
          _party.push(chUid);
        }
        renderParty();
      };
    })(ch.uid, sel);
    ro.appendChild(row);
  });

  // ── 파티 슬롯 (좌측) ──
  var pp = document.getElementById('ps-party'); pp.innerHTML = '';
  for (var i = 0; i < MAX_P; i++) {
    var s = document.createElement('div');
    s.className = 'party-slot';
    s.innerHTML = '<span class="ps-num">' + (i + 1) + '</span>';
    if (i < _party.length) {
      var pch = getChar(_party[i]);
      if (pch) {
        var pd = JAB[pch.cls];
        s.classList.add('filled');
        s.innerHTML = '<span class="ps-num">' + (i + 1) + '</span>' +
          '<span class="cls-icon" style="font-size:20px">' + pd.icon + '</span>' +
          '<span class="ps-lv">Lv' + pch.lv + '</span><span class="ps-x">\u2715</span>';
        s.onclick = (function(idx) { return function() { pRemAt(idx); }; })(i);
      }
    }
    pp.appendChild(s);
  }

  // ── 카운터 & 출격 버튼 ──
  var n = _party.length;
  document.getElementById('ps-counter').textContent = n + ' / ' + MAX_P;
  document.getElementById('ps-counter').style.color = n >= MIN_P ? 'var(--green)' : 'var(--blue)';
  var startBtn = document.getElementById('ps-start');
  if (_cStage) {
    startBtn.textContent = t('party.start_battle');
    startBtn.disabled = n < MIN_P;
    startBtn.style.display = '';
  } else {
    startBtn.style.display = 'none';
  }

  // 로스터 & 파티 저장
  saveParty(_party);
}

// ── 초기화 ───────────────────────────────
var init = async function() {
  await i18nInit();
  var nav = loadNav();
  _cStage = (nav && nav.cStage) ? nav.cStage : null;
  _party = loadParty();
  // 죽은 유닛 제거
  var roster = getRoster();
  _party = _party.filter(function(uid) {
    var ch = roster.chars.find(function(c) { return c.uid === uid; });
    return ch && !ch.dead;
  });
  renderParty();
  renderBottomNav();
  setTimeout(function() { document.getElementById('splash').style.display = 'none'; }, 300);
};
