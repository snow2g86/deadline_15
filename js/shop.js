// shop.js — 상점 페이지 전용 스크립트
// G/ROSTER/CD 의존 없이 JAB + localStorage 직접 조작

// ── 상수 ──────────────────────────────────
var MAX_LEVEL = 15;
var SHOP_KEY = 'game_shop';
var SAVE_KEY = 'game_save';
var ROSTER_KEY = 'game_roster';

function expForLevel(lv) { return 80 + 20 * lv + 5 * lv * lv; }

var EXP_POTIONS = [
  { id: 'exp_s', name: '\uc18c\ud615 \uacbd\ud5d8\uce58 \ubb3c\uc57d', icon: '\ud83e\uddea', exp: 50, cost: 400, weight: 50 },
  { id: 'exp_m', name: '\uc911\ud615 \uacbd\ud5d8\uce58 \ubb3c\uc57d', icon: '\u2697\ufe0f', exp: 150, cost: 1000, weight: 35 },
  { id: 'exp_l', name: '\ub300\ud615 \uacbd\ud5d8\uce58 \ubb3c\uc57d', icon: '\ud83c\udfd0', exp: 400, cost: 2400, weight: 15 }
];

var CLS_ICON = Object.fromEntries(
  Object.entries(JAB).map(function(e) { return [e[0], e[1].icon]; })
);

// ── 골드 관리 ─────────────────────────────
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

function updateGoldUI() {
  var el = document.getElementById('shop-gold-val');
  if (el) el.textContent = _gold.toLocaleString();
}

// 현재 골드 (페이지 내 캐시)
var _gold = 0;

// ── 로스터 직접 조작 ─────────────────────
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

function addChar(cls, nameId, pot) {
  var d = JAB[cls];
  if (!d) return null;
  var roster = getRoster();
  var ch = {
    uid: roster.nextId++,
    cls: cls,
    nameId: nameId,
    lv: 1, exp: 0, dead: false,
    hp: d.base.hp, atk: d.base.atk, def: d.base.def,
    move: d.base.move, range: d.base.range,
    pot: pot
  };
  roster.chars.push(ch);
  saveRoster(roster);
  return ch;
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

function _rollPotential(cls) {
  var g = JAB[cls].growth;
  function roll(mm) { return +(mm[0] + Math.random() * (mm[1] - mm[0])).toFixed(1); }
  return { hp: roll(g.hp), atk: roll(g.atk), def: roll(g.def) };
}

function _rollPotentialWithGrade(cls, targetGrade) {
  var g = JAB[cls].growth;
  var targetMin = targetGrade === 'S' ? 0.85 : targetGrade === 'A' ? 0.65 : targetGrade === 'B' ? 0.35 : 0;
  var targetMax = targetGrade === 'S' ? 1.0 : targetGrade === 'A' ? 0.85 : targetGrade === 'B' ? 0.65 : 0.35;

  for (var attempt = 0; attempt < 100; attempt++) {
    var pot = _rollPotential(cls);
    var scores = ['hp', 'atk', 'def'].map(function(k) {
      var mn = g[k][0], mx = g[k][1], rng = mx - mn;
      return rng > 0 ? (pot[k] - mn) / rng : 0.5;
    });
    var avg = scores.reduce(function(a, b) { return a + b; }, 0) / scores.length;
    if (avg >= targetMin && avg < targetMax) return pot;
  }

  var mid = (targetMin + targetMax) / 2;
  return {
    hp: +(g.hp[0] + (g.hp[1] - g.hp[0]) * mid).toFixed(1),
    atk: +(g.atk[0] + (g.atk[1] - g.atk[0]) * mid).toFixed(1),
    def: +(g.def[0] + (g.def[1] - g.def[0]) * mid).toFixed(1)
  };
}

function gainExp(uid, amount) {
  var roster = getRoster();
  var ch = roster.chars.find(function(c) { return c.uid === uid; });
  if (!ch || ch.lv >= MAX_LEVEL) return { leveled: 0, prevLv: ch ? ch.lv : 0 };
  var prevLv = ch.lv;
  ch.exp = (ch.exp || 0) + amount;
  var leveled = 0;
  while (ch.lv < MAX_LEVEL) {
    var need = expForLevel(ch.lv);
    if (ch.exp < need) break;
    ch.exp -= need;
    ch.lv++;
    ch.hp = Math.round(ch.hp + ch.pot.hp);
    ch.atk = Math.round(ch.atk + ch.pot.atk);
    ch.def = Math.round(ch.def + ch.pot.def);
    leveled++;
  }
  if (ch.lv >= MAX_LEVEL) ch.exp = 0;
  saveRoster(roster);
  return { leveled: leveled, prevLv: prevLv };
}

function previewClassChange(ch, newCls) {
  if (!ch || ch.cls !== 'novice') return null;
  var newD = JAB[newCls];
  var grade = potGrade(ch);
  var newPot = _rollPotentialWithGrade(newCls, grade);
  var gradeMultiplier = grade === 'S' ? 1.1 : grade === 'A' ? 1.0 : grade === 'B' ? 0.9 : 0.8;
  var baseHP = Math.round(newD.base.hp * gradeMultiplier);
  var baseATK = Math.round(newD.base.atk * gradeMultiplier);
  var baseDEF = Math.round(newD.base.def * gradeMultiplier);
  var lvGain = ch.lv - 1;
  return {
    hp: Math.round(baseHP + newPot.hp * lvGain),
    atk: Math.round(baseATK + newPot.atk * lvGain),
    def: Math.round(baseDEF + newPot.def * lvGain),
    move: newD.base.move,
    range: newD.base.range,
    pot: newPot
  };
}

function changeClass(uid, newCls) {
  var roster = getRoster();
  var ch = roster.chars.find(function(c) { return c.uid === uid; });
  if (!ch || ch.cls !== 'novice') return false;
  var preview = previewClassChange(ch, newCls);
  if (!preview) return false;
  ch.cls = newCls;
  ch.hp = preview.hp;
  ch.atk = preview.atk;
  ch.def = preview.def;
  ch.move = preview.move;
  ch.range = preview.range;
  ch.pot = preview.pot;
  saveRoster(roster);
  return true;
}

// ── 상점 데이터 ──────────────────────────
var _shopData = null;
var _currentTab = 'mercenary';
var _shopTimerInterval = null;

function loadShop() {
  try {
    var raw = localStorage.getItem(SHOP_KEY);
    if (raw) {
      var d = JSON.parse(raw);
      if (Date.now() - d.ts < 6 * 3600 * 1000) {
        _shopData = d;
        refreshClassChangeScrolls();
        return;
      }
    }
  } catch (_) {}
  genShop();
}

function refreshClassChangeScrolls() {
  _shopData.items = _shopData.items.filter(function(item) { return item.type !== 'class_change'; });
  var allClasses = Object.keys(JAB).filter(function(c) { return c !== 'novice' && !c.startsWith('summon_'); });
  for (var i = 0; i < allClasses.length; i++) {
    var cls = allClasses[i];
    var d = JAB[cls];
    _shopData.items.push({
      type: 'class_change',
      scrollId: 'cc_' + cls,
      name: t('classes.' + cls) + ' ' + t('shop.class_change_suffix'),
      i18nNameKey: 'classes.' + cls,
      i18nSuffixKey: 'shop.class_change_suffix',
      icon: d.icon,
      desc: t('shop.class_change_desc', { class: t('classes.' + cls) }),
      classes: [cls],
      cost: 500,
      sold: false
    });
  }
}

function genShop() {
  var classes = Object.keys(JAB).filter(function(c) { return !c.startsWith('summon'); });
  var items = [];
  var charNames = t('character.names');
  // 캐릭터 6개
  for (var i = 0; i < 6; i++) {
    var cls = classes[Math.floor(Math.random() * classes.length)];
    var d = JAB[cls];
    var pot = {
      hp: +(d.growth.hp[0] + Math.random() * (d.growth.hp[1] - d.growth.hp[0])).toFixed(1),
      atk: +(d.growth.atk[0] + Math.random() * (d.growth.atk[1] - d.growth.atk[0])).toFixed(1),
      def: +(d.growth.def[0] + Math.random() * (d.growth.def[1] - d.growth.def[0])).toFixed(1)
    };
    var name = charNames[Math.floor(Math.random() * charNames.length)];
    var g = d.growth;
    var scores = ['hp', 'atk', 'def'].map(function(k) {
      var mn = g[k][0], mx = g[k][1], rng = mx - mn;
      return rng > 0 ? (pot[k] - mn) / rng : 0.5;
    });
    var avg = scores.reduce(function(a, b) { return a + b; }, 0) / 3;
    var grade = avg >= 0.85 ? 'S' : avg >= 0.65 ? 'A' : avg >= 0.35 ? 'B' : 'C';
    var baseCost = { 'S': 900, 'A': 700, 'B': 550, 'C': 450 };
    var cost = Math.round(baseCost[grade] * (0.9 + avg * 0.2));
    items.push({ type: 'char', cls: cls, name: name, pot: pot, cost: cost, sold: false });
  }
  // 물약 5개
  var potionKeys = { 'exp_s': 'potion_small', 'exp_m': 'potion_medium', 'exp_l': 'potion_large' };
  for (var j = 0; j < 5; j++) {
    var totalW = EXP_POTIONS.reduce(function(s, p) { return s + p.weight; }, 0);
    var r = Math.random() * totalW, potObj = EXP_POTIONS[0];
    for (var k = 0; k < EXP_POTIONS.length; k++) {
      r -= EXP_POTIONS[k].weight;
      if (r <= 0) { potObj = EXP_POTIONS[k]; break; }
    }
    items.push({
      type: 'potion', potionId: potObj.id, name: potObj.name,
      i18nNameKey: 'shop.' + potionKeys[potObj.id],
      icon: potObj.icon, exp: potObj.exp, cost: potObj.cost, sold: false
    });
  }
  _shopData = { ts: Date.now(), items: items };
  refreshClassChangeScrolls();
  saveShop();
}

function saveShop() {
  try { localStorage.setItem(SHOP_KEY, JSON.stringify(_shopData)); } catch (_) {}
}

// ── 탭 전환 ──────────────────────────────
function switchTab(tab) {
  _currentTab = tab;
  var btns = document.querySelectorAll('.shop-tab-btn');
  btns.forEach(function(b) { b.classList.toggle('active', b.dataset.tab === tab); });
  renderShop();
}

// ── 렌더링 ───────────────────────────────
function renderShop() {
  var list = document.getElementById('shop-list'); list.innerHTML = '';
  var timeEl = document.getElementById('shop-timer');
  var titleEl = document.getElementById('shop-info-title');
  var remain = Math.max(0, 6 * 3600 * 1000 - (Date.now() - _shopData.ts));
  var h = Math.floor(remain / 3600000);
  var m = Math.floor((remain % 3600000) / 60000);
  var s = Math.floor((remain % 60000) / 1000);
  var showTimer = _currentTab === 'mercenary' || _currentTab === 'item';
  timeEl.style.display = showTimer ? 'block' : 'none';
  if (showTimer) {
    var hh = String(h).padStart(2, '0'), mm = String(m).padStart(2, '0'), ss = String(s).padStart(2, '0');
    timeEl.querySelector('span').textContent = t('shop.refresh_timer', { hours: hh, minutes: mm, seconds: ss });
  }
  var tabTitles = {
    'mercenary': t('shop.subtitle_mercenary'),
    'item': t('shop.subtitle_item'),
    'job': t('shop.subtitle_job'),
    'gold': t('shop.subtitle_gold')
  };
  titleEl.textContent = tabTitles[_currentTab] || t('shop.title');

  var tabTypeMap = { 'mercenary': 'char', 'item': 'potion', 'job': 'class_change', 'gold': null };
  var filterType = tabTypeMap[_currentTab];
  var filteredItems = _shopData.items.filter(function(item) {
    var iType = item.type || 'char';
    if (_currentTab === 'gold') return false;
    return iType === filterType;
  });

  filteredItems.forEach(function(item) {
    var iType = item.type || 'char';
    if (iType === 'char') renderCharCard(item, list);
    else if (iType === 'potion') renderPotionCard(item, list);
    else if (iType === 'class_change') renderClassChangeCard(item, list);
  });

  startShopTimer();
}

function renderCharCard(item, list) {
  var d = JAB[item.cls];
  var canAfford = _gold >= item.cost && !item.sold;
  var g = d.growth;
  var scores = ['hp', 'atk', 'def'].map(function(k) {
    var mn = g[k][0], mx = g[k][1], rng = mx - mn;
    return rng > 0 ? (item.pot[k] - mn) / rng : 0.5;
  });
  var avg = scores.reduce(function(a, b) { return a + b; }, 0) / 3;
  var grade = avg >= 0.85 ? 'S' : avg >= 0.65 ? 'A' : avg >= 0.35 ? 'B' : 'C';
  var gClr = grade === 'S' ? '#f0c040' : grade === 'A' ? '#60a5fa' : grade === 'B' ? '#4ade80' : '#9ca3af';
  var el = document.createElement('div');
  el.className = 'shop-card' + (item.sold ? ' sold' : '');
  var recruitBtn = item.sold ? t('shop.recruit_complete') : t('shop.recruit', { gold: item.cost });
  el.innerHTML =
    '<div class="shop-grade" style="color:' + gClr + '">' + grade + '</div>' +
    '<div class="shop-icon"><span class="cls-icon" style="font-size:28px">' + d.icon + '</span></div>' +
    '<div class="shop-name">' + item.name + '</div>' +
    '<div class="shop-cls">' + t('classes.' + item.cls) + ' \xb7 ' + t('class_desc.' + item.cls) + '</div>' +
    '<div class="shop-stats">' + t('common.hp') + ' ' + d.base.hp + ' ' + t('common.atk') + ' ' + d.base.atk + ' ' + t('common.def') + ' ' + d.base.def + '</div>' +
    '<div class="shop-pot">' + t('common.potential') + ' ' + t('common.hp') + '+' + item.pot.hp + ' ' + t('common.atk') + '+' + item.pot.atk + ' ' + t('common.def') + '+' + item.pot.def + '</div>' +
    '<button class="shop-btn' + (item.sold ? ' sold-btn' : '') + (canAfford ? '' : ' disabled') + '" ' + (canAfford && !item.sold ? '' : 'disabled') + '>' + recruitBtn + '</button>';
  if (!item.sold) {
    el.querySelector('.shop-btn').onclick = function() {
      if (_gold < item.cost) return;
      _gold -= item.cost;
      saveGold(_gold);
      updateGoldUI();
      var names = t('character.names');
      var nameIdx = names.indexOf(item.name);
      if (nameIdx < 0) nameIdx = Math.floor(Math.random() * names.length);
      addChar(item.cls, nameIdx, item.pot);
      item.sold = true;
      saveShop();
      renderShop();
    };
  }
  list.appendChild(el);
}

function renderPotionCard(item, list) {
  var canAfford = _gold >= item.cost && !item.sold;
  var el = document.createElement('div');
  el.className = 'shop-card potion-card' + (item.sold ? ' sold' : '');
  var buyBtn = item.sold ? t('shop.buy_complete') : t('shop.buy', { gold: item.cost });
  var potionName = item.i18nNameKey ? t(item.i18nNameKey) : item.name;
  el.innerHTML =
    '<div class="shop-icon">' + item.icon + '</div>' +
    '<div class="shop-name">' + potionName + '</div>' +
    '<div class="shop-cls">' + t('common.exp') + ' +' + item.exp + '</div>' +
    '<button class="shop-btn potion-btn' + (item.sold ? ' sold-btn' : '') + (canAfford ? '' : ' disabled') + '" ' + (canAfford && !item.sold ? '' : 'disabled') + '>' + buyBtn + '</button>';
  if (!item.sold) {
    el.querySelector('.shop-btn').onclick = function() {
      if (_gold < item.cost) return;
      showPotionModal(item);
    };
  }
  list.appendChild(el);
}

function renderClassChangeCard(item, list) {
  var canAfford = _gold >= item.cost && !item.sold;
  var el = document.createElement('div');
  el.className = 'shop-card cc-card' + (item.sold ? ' sold' : '');
  var ccBtn = item.sold ? t('shop.buy_complete') : t('shop.buy', { gold: item.cost });
  var cls = item.classes[0];
  var ccName = t('classes.' + cls) + ' ' + t('shop.class_change_suffix');
  var ccDesc = t('shop.class_change_desc', { class: t('classes.' + cls) });
  el.innerHTML =
    '<div class="shop-icon">' + item.icon + '</div>' +
    '<div class="shop-name">' + ccName + '</div>' +
    '<div class="shop-cls">' + ccDesc + '</div>' +
    '<button class="shop-btn cc-btn' + (item.sold ? ' sold-btn' : '') + (canAfford ? '' : ' disabled') + '" ' + (canAfford && !item.sold ? '' : 'disabled') + '>' + ccBtn + '</button>';
  if (!item.sold) {
    el.querySelector('.shop-btn').onclick = function() {
      if (_gold < item.cost) return;
      showClassChangeModal(item);
    };
  }
  list.appendChild(el);
}

// ── 갱신 타이머 ──────────────────────────
function startShopTimer() {
  if (_shopTimerInterval) clearInterval(_shopTimerInterval);
  _shopTimerInterval = setInterval(function() {
    var timeEl = document.getElementById('shop-timer');
    if (!timeEl) return;
    var remain = Math.max(0, 6 * 3600 * 1000 - (Date.now() - _shopData.ts));
    var h = Math.floor(remain / 3600000);
    var m = Math.floor((remain % 3600000) / 60000);
    var s = Math.floor((remain % 60000) / 1000);
    var showTimer = _currentTab === 'mercenary' || _currentTab === 'item';
    timeEl.style.display = showTimer ? 'block' : 'none';
    if (showTimer) {
      var hh = String(h).padStart(2, '0'), mm = String(m).padStart(2, '0'), ss = String(s).padStart(2, '0');
      timeEl.querySelector('span').textContent = t('shop.refresh_timer', { hours: hh, minutes: mm, seconds: ss });
    }
    if (remain <= 0) {
      genShop();
      renderShop();
    }
  }, 1000);
}

// ── 물약 사용 모달 ───────────────────────
function showPotionModal(item) {
  var roster = getRoster();
  var alive = roster.chars.filter(function(c) { return !c.dead && !c.cls.startsWith('summon_'); });
  if (!alive.length) return;
  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = t('shop.select_character');
  document.getElementById('modal-title').className = '';
  var h = '<div class="potion-target-list">';
  var names = t('character.names');
  alive.forEach(function(ch) {
    var d = JAB[ch.cls];
    var charName = names[ch.nameId] || d.icon;
    var atMax = ch.lv >= MAX_LEVEL;
    var expNeed = atMax ? 0 : expForLevel(ch.lv);
    var expPct = atMax ? 100 : Math.min(100, Math.round((ch.exp || 0) / expNeed * 100));
    h += '<div class="pt-btn' + (atMax ? ' pt-max' : '') + '" data-uid="' + ch.uid + '">' +
      '<span class="pt-icon"><span class="cls-icon" style="font-size:20px">' + d.icon + '</span></span>' +
      '<span class="pt-info">' + charName + ' Lv.' + ch.lv + '</span>' +
      '<span class="pt-exp">' + (atMax ? t('common.max') : ((ch.exp || 0) + '/' + expNeed)) + '</span>' +
      '</div>';
  });
  h += '</div>';
  var potionName = item.i18nNameKey ? t(item.i18nNameKey) : item.name;
  document.getElementById('modal-sub').innerHTML = item.icon + ' ' + potionName + ' (EXP +' + item.exp + ')<br><br>' + h;
  var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
  var cb = document.createElement('button');
  cb.className = 'modal-btn secondary';
  cb.textContent = t('common.cancel');
  cb.onclick = function() { ov.classList.remove('show'); };
  bt.appendChild(cb);
  ov.classList.add('show');
  document.querySelectorAll('.pt-btn:not(.pt-max)').forEach(function(b) {
    b.onclick = function() {
      var uid = +b.dataset.uid;
      _gold -= item.cost;
      saveGold(_gold);
      updateGoldUI();
      var r = gainExp(uid, item.exp);
      item.sold = true;
      saveShop();
      ov.classList.remove('show');
      renderShop();
      if (r.leveled > 0) {
        var ch = getChar(uid);
        var d = JAB[ch.cls];
        var charName = names[ch.nameId] || d.icon;
        setTimeout(function() {
          showAlert(
            d.icon + ' ' + charName + '\nLv.' + r.prevLv + ' \u2192 Lv.' + ch.lv +
            (r.leveled > 1 ? ' (' + r.leveled + '\ub2e8\uacc4 \ub808\ubca8\uc5c5!)' : '')
          );
        }, 100);
      }
    };
  });
}

// ── 전직서 사용 모달 (노비스 선택) ───────
function showClassChangeModal(item) {
  var roster = getRoster();
  var novices = roster.chars.filter(function(c) { return !c.dead && c.cls === 'novice'; });
  if (!novices.length) {
    showAlert(t('class_change.no_novice'));
    return;
  }
  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = t('class_change.select_novice');
  document.getElementById('modal-title').className = '';
  var h = '<div class="potion-target-list">';
  var names = t('character.names');
  novices.forEach(function(ch) {
    var grade = potGrade(ch);
    var gClr = grade === 'S' ? '#f0c040' : grade === 'A' ? '#60a5fa' : grade === 'B' ? '#4ade80' : '#9ca3af';
    var charName = names[ch.nameId] || '???';
    h += '<div class="pt-btn" data-uid="' + ch.uid + '">' +
      '<span class="pt-icon"><span class="cls-icon" style="font-size:20px">' + JAB[ch.cls].icon + '</span></span>' +
      '<span class="pt-info">' + charName + ' Lv.' + ch.lv + '</span>' +
      '<span class="pt-exp" style="color:' + gClr + '">' + grade + t('class_change.grade_suffix') + '</span>' +
      '</div>';
  });
  h += '</div>';
  var ccName = item.i18nNameKey ? (t(item.i18nNameKey) + ' ' + t(item.i18nSuffixKey)) : item.name;
  document.getElementById('modal-sub').innerHTML = item.icon + ' ' + ccName + '<br>' + item.desc + '<br><br>' + h;
  var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
  var cb = document.createElement('button');
  cb.className = 'modal-btn secondary';
  cb.textContent = t('common.cancel');
  cb.onclick = function() { ov.classList.remove('show'); };
  bt.appendChild(cb);
  ov.classList.add('show');
  document.querySelectorAll('.pt-btn').forEach(function(b) {
    b.onclick = function() {
      var uid = +b.dataset.uid;
      ov.classList.remove('show');
      showClassSelectModal(uid, item);
    };
  });
}

// ── 전직서 사용 모달 (직업 선택) ─────────
function showClassSelectModal(uid, item) {
  var ch = getChar(uid);
  if (!ch) return;
  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = t('class_change.select_class');
  document.getElementById('modal-title').className = '';
  var h = '<div class="class-select-grid">';
  item.classes.forEach(function(cls) {
    var d = JAB[cls];
    h += '<div class="cs-card" data-cls="' + cls + '">' +
      '<div class="cs-icon">' + d.icon + '</div>' +
      '<div class="cs-name">' + t('classes.' + cls) + '</div>' +
      '<div class="cs-stats">HP ' + d.base.hp + ' ATK ' + d.base.atk + ' DEF ' + d.base.def + '</div>' +
      '<div class="cs-role">' + t('class_desc.' + cls) + '</div>' +
      '</div>';
  });
  h += '</div>';
  var names = t('character.names');
  var charName = names[ch.nameId] || '???';
  document.getElementById('modal-sub').innerHTML =
    '<span class="cls-icon" style="font-size:24px">' + JAB[ch.cls].icon + '</span> <b>' + charName + '</b> (Lv.' + ch.lv + ')<br>' +
    '<span style="color:var(--dim);font-size:10px">' + t('class_change.warning_irreversible') + '</span><br><br>' + h;
  var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
  var cb = document.createElement('button');
  cb.className = 'modal-btn secondary';
  cb.textContent = t('common.cancel');
  cb.onclick = function() { ov.classList.remove('show'); };
  bt.appendChild(cb);
  ov.classList.add('show');
  document.querySelectorAll('.cs-card').forEach(function(card) {
    card.onclick = function() {
      var newCls = card.dataset.cls;
      ov.classList.remove('show');
      confirmClassChange(uid, newCls, item);
    };
  });
}

// ── 전직서 사용 모달 (최종 확인) ─────────
function confirmClassChange(uid, newCls, item) {
  var ch = getChar(uid);
  if (!ch) return;
  var oldD = JAB[ch.cls];
  var newD = JAB[newCls];
  var grade = potGrade(ch);
  var preview = previewClassChange(ch, newCls);
  var names = t('character.names');
  var charName = names[ch.nameId] || '???';
  var origClass = ch.cls;
  showConfirm(
    oldD.icon + ' ' + charName + ' (Lv.' + ch.lv + ' ' + grade + t('class_change.grade_suffix') + ')\n' +
    t('classes.' + ch.cls) + ' \u2192 ' + newD.icon + ' ' + t('classes.' + newCls) + '\n\n' +
    t('class_change.stats_preview') + '\n' +
    'HP ' + preview.hp + ' / ATK ' + preview.atk + ' / DEF ' + preview.def + '\n' +
    'MOV ' + preview.move + ' / RNG ' + preview.range + '\n\n' +
    t('class_change.confirm_cost', { cost: item.cost }) + '\n' +
    t('class_change.warning_parenthetical'),
    function() {
      _gold -= item.cost;
      saveGold(_gold);
      updateGoldUI();
      changeClass(uid, newCls);
      item.sold = true;
      saveShop();
      renderShop();
      setTimeout(function() {
        var updCh = getChar(uid);
        var updCharName = names[updCh.nameId] || '???';
        showAlert(
          newD.icon + ' ' + updCharName + '\n' +
          t('class_change.success', { oldClass: t('classes.' + origClass), newClass: t('classes.' + newCls) }) + '\n\n' +
          'HP ' + updCh.hp + ' / ATK ' + updCh.atk + ' / DEF ' + updCh.def + '\n' +
          'MOV ' + updCh.move + ' / RNG ' + updCh.range
        );
      }, 100);
    }
  );
}

// ── 초기화 ───────────────────────────────
var init = async function() {
  await i18nInit();
  _gold = loadGold();
  updateGoldUI();
  loadShop();
  renderShop();
  renderBottomNav();
  setTimeout(function() { document.getElementById('splash').style.display = 'none'; }, 300);
};
