// party-select.js — 파티 편성 + 장비 관리 통합 페이지
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
var _activePageTab = 'party';

// ── 장비 상태 ──────────────────────────
var _selUid = null;
var _invFilter = 'all';
var _gold = 0;

// ── 골드 UI ─────────────────────────────
function updatePageGold() {
  var el = document.getElementById('ps-gold-val');
  if (el) el.textContent = loadGold().toLocaleString();
}

// ── 탭 전환 ─────────────────────────────
function switchPageTab(tab) {
  _activePageTab = tab;
  var tabs = document.querySelectorAll('.ps-page-tabs .ps-page-tab');
  tabs.forEach(function(btn) {
    btn.classList.toggle('active', btn.getAttribute('data-ptab') === tab);
  });
  document.getElementById('section-party').style.display = tab === 'party' ? '' : 'none';
  document.getElementById('section-equip').style.display = tab === 'equip' ? '' : 'none';
  if (tab === 'equip') {
    _gold = loadGold();
    eqRenderAll();
  }
  updatePageGold();
}


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
  var charName = ch.customName || names[ch.nameId] || d.icon;
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
      updatePageGold();
      renderParty();
    }
  );
}

// ── 이름 변경 ─────────────────────────────
function renameChar(uid) {
  uid = +uid;
  var ch = getChar(uid);
  if (!ch) return;
  var names = t('character.names');
  var curName = ch.customName || names[ch.nameId] || '';
  showPrompt(t('party.rename_prompt'), curName, function(val) {
    var roster = getRoster();
    var target = roster.chars.find(function(c) { return c.uid === uid; });
    if (!target) return;
    if (val && val !== names[target.nameId]) {
      target.customName = val;
    } else {
      delete target.customName;
    }
    saveRoster(roster);
    renderParty();
  });
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
    var aName = a.customName || names[a.nameId] || '';
    var bName = b.customName || names[b.nameId] || '';
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
    var charName = ch.customName || names[ch.nameId] || d.icon;
    if (!ch.equip) ch.equip = { weapon:null,offhand:null,helmet:null,armor:null,boots:null,necklace:null,earring:null,ring:null };
    var eqB = typeof calcEquipBonus === 'function' ? calcEquipBonus(ch) : {hp:0,atk:0,def:0,move:0,range:0};
    var eqHp = eqB.hp ? '<span style="color:#4ade80">+' + eqB.hp + '</span>' : '';
    var eqAtk = eqB.atk ? '<span style="color:#4ade80">+' + eqB.atk + '</span>' : '';
    var eqDef = eqB.def ? '<span style="color:#4ade80">+' + eqB.def + '</span>' : '';
    row.innerHTML =
      '<div class="rl-icon">' + charSprite(ch.cls, 30, ch.gender) + '</div>' +
      '<div class="rl-info">' +
      '<div class="rl-top"><span class="rl-name">' + charName + '</span><button class="rl-rename" onclick="event.stopPropagation();renameChar(' + ch.uid + ')">&#9998;</button><span class="rl-lv">Lv.' + ch.lv + '</span>' +
      '<span class="rl-grade" style="color:' + gClr + '">' + grade + '</span></div>' +
      '<div class="rl-stats">HP <b>' + ch.hp + '</b>' + eqHp + ' ATK <b>' + ch.atk + '</b>' + eqAtk + ' DEF <b>' + ch.def + '</b>' + eqDef + ' MOV <b>' + ch.move + '</b> RNG <b>' + ch.range + '</b></div>' +
      '<div class="rl-pot">' + t('party.potential_stats', { hp: ch.pot.hp, atk: ch.pot.atk, def: ch.pot.def }) + '</div>' +
      '<div class="rl-exp"><div class="rl-exp-fill" style="width:' + expPct + '%"></div></div>' +
      '</div>' +
      '<div class="rl-actions">' +
      '<div class="rl-btn ' + (sel ? 'chk' : 'add') + '">' + (sel ? '\u2713' : '+') + '</div>' +
      (sel ? '' : '<button class="rl-release" onclick="event.stopPropagation();releaseChar(' + ch.uid + ')">' + t('party.release') + '</button>') +
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
          charSprite(pch.cls, 20, pch.gender) +
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

// ══════════════════════════════════════════════
// ── 장비 관리 (equip.js 병합) ────────────────
// ══════════════════════════════════════════════


// ── Character scroll bar ──
function renderChars() {
  var el = document.getElementById('eq-chars');
  if (!el) return;
  el.innerHTML = '';
  var roster = getRoster();
  var alive = roster.chars.filter(function(c) { return !c.dead && !c.cls.startsWith('summon_'); });
  var names = t('character.names');
  alive.forEach(function(ch) {
    var d = JAB[ch.cls];
    var charName = ch.customName || names[ch.nameId] || d.icon;
    var btn = document.createElement('div');
    btn.className = 'eq-char-btn' + (_selUid === ch.uid ? ' active' : '');
    btn.innerHTML =
      charSprite(ch.cls, 22, ch.gender) +
      '<span class="eq-char-name">' + charName + '</span>' +
      '<span class="eq-char-lv">Lv.' + ch.lv + '</span>';
    btn.onclick = function() { _selUid = ch.uid; eqRenderAll(); };
    el.appendChild(btn);
  });
}

// ── Main body ──
function renderBody() {
  var body = document.getElementById('eq-body');
  if (!body) return;
  if (!_selUid) {
    body.innerHTML = '<div class="eq-placeholder">' + t('equip.select_char') + '</div>';
    return;
  }
  var roster = getRoster();
  var ch = roster.chars.find(function(c) { return c.uid === _selUid; });
  if (!ch) { body.innerHTML = ''; return; }
  ensureEquipSlots(ch);
  var inv = loadInventory();
  var invMap = {};
  for (var i = 0; i < inv.length; i++) { if (inv[i].type === 'equip') invMap[inv[i].eid] = inv[i]; }

  var html = '';
  // ── Slots grid ──
  html += '<div class="eq-slots-title">' + t('equip.slots_title') + '</div>';
  html += '<div class="eq-slots">';
  for (var s = 0; s < EQUIP_SLOTS.length; s++) {
    var slot = EQUIP_SLOTS[s];
    var eid = ch.equip[slot];
    var item = eid ? invMap[eid] : null;
    var locked = false;
    if (slot === 'offhand') {
      var wEid = ch.equip.weapon;
      var wItem = wEid ? invMap[wEid] : null;
      if (wItem && wItem.hand === '2h') locked = true;
    }
    html += '<div class="eq-slot' + (item ? ' filled' : '') + (locked ? ' locked' : '') + '" data-slot="' + slot + '">';
    html += '<div class="eq-slot-label">' + t('equip.slot.' + slot) + '</div>';
    if (locked) {
      html += '<div class="eq-slot-locked">&#128274;</div>';
    } else if (item) {
      html += '<div class="eq-slot-item" style="border-color:' + RARITY[item.rarity].color + '">';
      html += '<span class="eq-slot-rarity" style="color:' + RARITY[item.rarity].color + '">' + t('equip.rarity.' + item.rarity).charAt(0).toUpperCase() + '</span>';
      html += '<span class="eq-slot-name">' + t('equip.item.' + item.templateId) + '</span>';
      html += '</div>';
    } else {
      html += '<div class="eq-slot-empty">-</div>';
    }
    html += '</div>';
  }
  html += '</div>';

  // ── Stats summary ──
  var bonus = calcEquipBonus(ch);
  html += '<div class="eq-stats">';
  var statKeys = ['hp', 'atk', 'def', 'move', 'range'];
  for (var si = 0; si < statKeys.length; si++) {
    var sk = statKeys[si];
    var base = ch[sk] || 0;
    var bon = bonus[sk] || 0;
    html += '<div class="eq-stat">';
    html += '<span class="eq-stat-label">' + t('common.' + sk) + '</span>';
    html += '<span class="eq-stat-val">' + base + (bon > 0 ? '<span class="eq-stat-bonus">+' + bon + '</span>' : '') + '</span>';
    html += '</div>';
  }
  html += '</div>';

  // ── Set bonuses ──
  var setCounts = {};
  for (var ss = 0; ss < EQUIP_SLOTS.length; ss++) {
    var sEid = ch.equip[EQUIP_SLOTS[ss]];
    if (!sEid) continue;
    var sItem = invMap[sEid];
    if (sItem && sItem.setId) setCounts[sItem.setId] = (setCounts[sItem.setId] || 0) + 1;
  }
  var hasSet = false;
  for (var sid in setCounts) { hasSet = true; break; }
  if (hasSet) {
    html += '<div class="eq-set-info">';
    for (var setId in setCounts) {
      var cnt = setCounts[setId];
      var setDef = EQUIP_SETS[setId];
      html += '<div class="eq-set-row">';
      html += '<span class="eq-set-name">' + t('equip.set.' + setId) + '</span>';
      for (var th in setDef) {
        var active = cnt >= parseInt(th);
        var bonusStr = [];
        for (var bk in setDef[th]) bonusStr.push(t('common.' + bk) + '+' + setDef[th][bk]);
        html += '<span class="eq-set-bonus' + (active ? ' active' : '') + '">(' + th + ') ' + bonusStr.join(' ') + '</span>';
      }
      html += '</div>';
    }
    html += '</div>';
  }

  // ── Inventory filter + list ──
  html += '<div class="eq-inv-title">' + t('equip.inventory') + '</div>';
  html += '<div class="eq-inv-tabs">';
  var filters = [
    { key: 'all', label: t('party.filter_all') },
    { key: 'weapon', label: t('equip.slot.weapon') },
    { key: 'armor', label: t('equip.filter_armor') },
    { key: 'accessory', label: t('equip.filter_accessory') }
  ];
  for (var fi = 0; fi < filters.length; fi++) {
    html += '<button class="eq-inv-tab' + (_invFilter === filters[fi].key ? ' active' : '') + '" data-filter="' + filters[fi].key + '">' + filters[fi].label + '</button>';
  }
  html += '</div>';
  html += '<div class="eq-inv-list" id="eq-inv-list"></div>';

  body.innerHTML = html;

  // ── Bind slot click (unequip) ──
  body.querySelectorAll('.eq-slot.filled').forEach(function(el) {
    el.onclick = function() {
      var sl = el.dataset.slot;
      unequipItem(_selUid, sl);
    };
  });

  // ── Bind filter tabs ──
  body.querySelectorAll('.eq-inv-tab').forEach(function(btn) {
    btn.onclick = function() {
      _invFilter = btn.dataset.filter;
      eqRenderAll();
    };
  });

  // ── Render inventory list ──
  renderInventory(ch, invMap);
}

function renderInventory(ch, invMap) {
  var list = document.getElementById('eq-inv-list');
  if (!list) return;
  list.innerHTML = '';
  var inv = loadInventory();
  var equips = inv.filter(function(it) { return it.type === 'equip'; });

  // Filter
  if (_invFilter === 'weapon') {
    equips = equips.filter(function(it) { return it.slot === 'weapon' || it.slot === 'offhand'; });
  } else if (_invFilter === 'armor') {
    equips = equips.filter(function(it) { return it.slot === 'helmet' || it.slot === 'armor' || it.slot === 'boots'; });
  } else if (_invFilter === 'accessory') {
    equips = equips.filter(function(it) { return it.slot === 'necklace' || it.slot === 'earring' || it.slot === 'ring'; });
  }

  // Sort: rarity desc, then slot
  equips.sort(function(a, b) {
    var ra = RARITY[a.rarity].tier, rb = RARITY[b.rarity].tier;
    if (rb !== ra) return rb - ra;
    return EQUIP_SLOTS.indexOf(a.slot) - EQUIP_SLOTS.indexOf(b.slot);
  });

  if (!equips.length) {
    list.innerHTML = '<div class="eq-inv-empty">' + t('equip.no_items') + '</div>';
    return;
  }

  equips.forEach(function(item) {
    var rc = RARITY[item.rarity].color;
    var canEquipThis = canEquip(ch, item);
    var isEquipped = item.equipped !== null;
    var isEquippedHere = false;
    for (var s = 0; s < EQUIP_SLOTS.length; s++) {
      if (ch.equip[EQUIP_SLOTS[s]] === item.eid) { isEquippedHere = true; break; }
    }
    var statsArr = [];
    for (var st in item.stats) statsArr.push(t('common.' + st) + '+' + item.stats[st]);

    var row = document.createElement('div');
    row.className = 'eq-inv-row' + (isEquippedHere ? ' equipped-here' : isEquipped ? ' equipped-other' : '');
    row.innerHTML =
      '<div class="eq-inv-info">' +
      '<span class="eq-inv-rarity" style="color:' + rc + '">' + t('equip.rarity.' + item.rarity) + '</span>' +
      '<span class="eq-inv-name">' + t('equip.item.' + item.templateId) + '</span>' +
      '<span class="eq-inv-stats">' + statsArr.join(' ') + '</span>' +
      (item.setId ? '<span class="eq-inv-set" style="color:#f0c040">' + t('equip.set.' + item.setId) + '</span>' : '') +
      '</div>' +
      '<div class="eq-inv-actions">' +
      (isEquippedHere ? '<span class="eq-inv-equipped">' + t('equip.equipped') + '</span>' :
        (canEquipThis && !isEquipped ? '<button class="eq-inv-btn eq-equip-btn">' + t('equip.equip_btn') + '</button>' : '') +
        (!isEquipped ? '<button class="eq-inv-btn eq-sell-btn">' + t('equip.sell_btn', { gold: SELL_PRICE[item.rarity] }) + '</button>' : '')
      ) +
      '</div>';

    var equipBtn = row.querySelector('.eq-equip-btn');
    if (equipBtn) {
      equipBtn.onclick = function() { equipItem(_selUid, item.eid); };
    }
    var sellBtn = row.querySelector('.eq-sell-btn');
    if (sellBtn) {
      sellBtn.onclick = function() { sellEquip(item.eid); };
    }
    list.appendChild(row);
  });
}

// ── Core equip functions ──
function canEquip(ch, item) {
  if (!ch || !item) return false;
  if (item.clsRestrict && item.clsRestrict.indexOf(ch.cls) === -1) return false;
  if (item.slot === 'offhand') {
    ensureEquipSlots(ch);
    var inv = loadInventory();
    var wEid = ch.equip.weapon;
    if (wEid) {
      var wItem = inv.find(function(x) { return x.eid === wEid; });
      if (wItem && wItem.hand === '2h') return false;
    }
  }
  return true;
}

function equipItem(uid, eid) {
  var roster = getRoster();
  var ch = roster.chars.find(function(c) { return c.uid === uid; });
  if (!ch) return;
  ensureEquipSlots(ch);
  var inv = loadInventory();
  var item = inv.find(function(x) { return x.eid === eid; });
  if (!item) return;

  // Unequip from other character if needed
  if (item.equipped !== null && item.equipped !== uid) {
    var other = roster.chars.find(function(c) { return c.uid === item.equipped; });
    if (other) {
      ensureEquipSlots(other);
      for (var s = 0; s < EQUIP_SLOTS.length; s++) {
        if (other.equip[EQUIP_SLOTS[s]] === eid) { other.equip[EQUIP_SLOTS[s]] = null; break; }
      }
    }
  }

  // Unequip current item in slot
  var oldEid = ch.equip[item.slot];
  if (oldEid) {
    var oldItem = inv.find(function(x) { return x.eid === oldEid; });
    if (oldItem) oldItem.equipped = null;
  }

  // 2h weapon: also unequip offhand
  if (item.slot === 'weapon' && item.hand === '2h') {
    var ohEid = ch.equip.offhand;
    if (ohEid) {
      var ohItem = inv.find(function(x) { return x.eid === ohEid; });
      if (ohItem) ohItem.equipped = null;
    }
    ch.equip.offhand = null;
  }

  ch.equip[item.slot] = eid;
  item.equipped = uid;
  saveRoster(roster);
  saveInventory(inv);
  eqRenderAll();
}

function unequipItem(uid, slot) {
  var roster = getRoster();
  var ch = roster.chars.find(function(c) { return c.uid === uid; });
  if (!ch) return;
  ensureEquipSlots(ch);
  var eid = ch.equip[slot];
  if (!eid) return;
  var inv = loadInventory();
  var item = inv.find(function(x) { return x.eid === eid; });
  if (item) item.equipped = null;
  ch.equip[slot] = null;
  saveRoster(roster);
  saveInventory(inv);
  eqRenderAll();
}

function sellEquip(eid) {
  var inv = loadInventory();
  var item = inv.find(function(x) { return x.eid === eid; });
  if (!item || item.equipped !== null) return;
  var price = SELL_PRICE[item.rarity] || 30;
  showConfirm(
    t('equip.sell_confirm', { name: t('equip.item.' + item.templateId), gold: price }),
    function() {
      var inv2 = loadInventory();
      inv2 = inv2.filter(function(x) { return x.eid !== eid; });
      saveInventory(inv2);
      _gold += price;
      saveGold(_gold);
      updatePageGold();
      eqRenderAll();
    }
  );
}

function eqRenderAll() {
  renderChars();
  renderBody();
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

  // 페이지 탭 바인딩
  document.querySelectorAll('.ps-page-tabs .ps-page-tab').forEach(function(btn) {
    btn.onclick = function() { switchPageTab(btn.getAttribute('data-ptab')); };
  });

  updatePageGold();
  renderParty();
  renderBottomNav();
  setTimeout(function() { document.getElementById('splash').style.display = 'none'; }, 300);
};
