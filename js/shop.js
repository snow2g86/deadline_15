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

function clsIcon(cls, size) {
  var d = JAB[cls]; if (!d) return '';
  return '<img class="cls-icon" src="image/icon/jab/' + cls + '.png" alt="' + cls + '" style="width:' + size + 'px;height:' + size + 'px">';
}

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

function addChar(cls, nameId, pot, gender) {
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
    pot: pot,
    gender: gender || (Math.random() < 0.5 ? 'm' : 'f')
  };
  roster.chars.push(ch);
  saveRoster(roster);
  return ch;
}

function getChar(uid) {
  var roster = getRoster();
  return roster.chars.find(function(c) { return c.uid === uid; });
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
        return;
      }
    }
  } catch (_) {}
  genShop();
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
    items.push({ type: 'char', cls: cls, name: name, pot: pot, cost: cost, sold: false, gender: Math.random() < 0.5 ? 'm' : 'f' });
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
  // 스킬북 2개
  if (typeof LEARNABLE_SKILLS !== 'undefined') {
    var lsKeys = Object.keys(LEARNABLE_SKILLS);
    for (var sb = 0; sb < 2; sb++) {
      var sk = LEARNABLE_SKILLS[lsKeys[Math.floor(Math.random() * lsKeys.length)]];
      items.push({
        type: 'skillbook', skillId: sk.id, cls: sk.cls, cost: 800, sold: false
      });
    }
  }
  _shopData = { ts: Date.now(), items: items };
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
  list.style.display = ''; list.style.flexDirection = ''; list.style.alignItems = ''; list.style.gap = ''; list.style.gridTemplateColumns = '';
  var timeEl = document.getElementById('shop-timer');
  var titleEl = document.getElementById('shop-info-title');
  var remain = Math.max(0, 6 * 3600 * 1000 - (Date.now() - _shopData.ts));
  var h = Math.floor(remain / 3600000);
  var m = Math.floor((remain % 3600000) / 60000);
  var s = Math.floor((remain % 60000) / 1000);
  var showTimer = _currentTab === 'mercenary' || _currentTab === 'consumable' || _currentTab === 'skill';
  timeEl.style.display = showTimer ? 'block' : 'none';
  if (showTimer) {
    var hh = String(h).padStart(2, '0'), mm = String(m).padStart(2, '0'), ss = String(s).padStart(2, '0');
    timeEl.querySelector('span').textContent = t('shop.refresh_timer', { hours: hh, minutes: mm, seconds: ss });
  }
  var tabTitles = {
    'mercenary': t('shop.subtitle_mercenary'),
    'consumable': t('shop.subtitle_consumable'),
    'equip': t('shop.subtitle_equip'),
    'skill': t('shop.subtitle_skill'),
    'gold': t('shop.subtitle_gold')
  };
  titleEl.textContent = tabTitles[_currentTab] || t('shop.title');

  if (_currentTab === 'equip') {
    renderGacha(list);
    return;
  }

  if (_currentTab === 'gold') {
    renderGoldShop(list);
    return;
  }

  // 광고 보상 카드
  var tabAdMap = {
    'mercenary':  { type: 'merc',  descKey: 'shop.ad_merc_desc',  fn: doGachaAdMerc },
    'consumable': { type: 'item',  descKey: 'shop.ad_item_desc',  fn: doGachaAdItem },
    'skill':      { type: 'skill', descKey: 'shop.ad_skill_desc', fn: doGachaAdSkill }
  };
  var adCfg = tabAdMap[_currentTab];
  if (adCfg) list.appendChild(buildTabAdCard(adCfg.type, adCfg.descKey, adCfg.fn));

  var tabTypeMap = { 'mercenary': 'char', 'consumable': 'potion', 'skill': 'skillbook' };
  var filterTypes = tabTypeMap[_currentTab];
  var filteredItems = _shopData.items.filter(function(item) {
    var iType = item.type || 'char';
    return iType === filterTypes;
  });

  filteredItems.forEach(function(item) {
    var iType = item.type || 'char';
    if (iType === 'char') renderCharCard(item, list);
    else if (iType === 'potion') renderPotionCard(item, list);
    else if (iType === 'skillbook') renderSkillBookCard(item, list);
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
    '<div class="shop-icon">' + clsIcon(item.cls, 36) + '</div>' +
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
      addChar(item.cls, nameIdx, item.pot, item.gender);
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


function renderSkillBookCard(item, list) {
  var canAfford = _gold >= item.cost && !item.sold;
  var sk = typeof LEARNABLE_SKILLS !== 'undefined' ? LEARNABLE_SKILLS[item.skillId] : null;
  if (!sk) return;
  var skillName = t('skills.' + item.skillId);
  var clsName = t('classes.' + item.cls);
  var el = document.createElement('div');
  el.className = 'shop-card skillbook-card' + (item.sold ? ' sold' : '');
  var buyBtn = item.sold ? t('shop.buy_complete') : t('shop.buy', { gold: item.cost });
  el.innerHTML =
    '<div class="shop-icon">' + clsIcon(item.cls, 36) + '</div>' +
    '<div class="shop-name">' + skillIcon(item.skillId, 18) + ' ' + skillName + '</div>' +
    '<div class="shop-cls">' + clsName + ' ' + t('shop.skillbook_only') + '</div>' +
    '<div class="shop-stats">' + sk.desc + '</div>' +
    '<button class="shop-btn' + (item.sold ? ' sold-btn' : '') + (canAfford ? '' : ' disabled') + '" ' + (canAfford && !item.sold ? '' : 'disabled') + '>' + buyBtn + '</button>';
  if (!item.sold) {
    el.querySelector('.shop-btn').onclick = function() {
      if (_gold < item.cost) return;
      showConfirm(t('shop.skillbook_buy_confirm', { skill: skillName, gold: item.cost }), function() {
        _gold -= item.cost;
        saveGold(_gold);
        updateGoldUI();
        var inv = loadInventory();
        inv.push({ id: item.skillId, cls: item.cls, lv: 1 });
        saveInventory(inv);
        item.sold = true;
        saveShop();
        renderShop();
        showAlert(t('academy.skillbook_drop', { skill: skillName }));
      });
    };
  }
  list.appendChild(el);
}

// ── 골드 상점 ───────────────────────────
var AD_COOLDOWN_KEY = 'game_ad_cooldown';
var AD_COOLDOWN_MS = 10 * 60 * 1000; // 10분
var AD_REWARD = 500;

// ── 가챠 광고 보상 ──────────────────────
var GACHA_AD_KEYS = {
  equip: 'game_gacha_ad_equip',
  item:  'game_gacha_ad_item',
  merc:  'game_gacha_ad_merc',
  skill: 'game_gacha_ad_skill'
};
var GACHA_AD_COOLDOWN_MS = 30 * 60 * 1000;

function getGachaAdCooldown(type) {
  try { var v = +localStorage.getItem(GACHA_AD_KEYS[type]); return v || 0; } catch(_) { return 0; }
}

function setGachaAdCooldown(type) {
  try { localStorage.setItem(GACHA_AD_KEYS[type], Date.now()); } catch(_) {}
}

function doGachaAdEquip() {
  setGachaAdCooldown('equip');
  var item = gachaPull(null);
  var inv = loadInventory();
  inv.push(item);
  saveInventory(inv);
  showGachaResults([item]);
}

function doGachaAdItem() {
  setGachaAdCooldown('item');
  var totalW = EXP_POTIONS.reduce(function(s, p) { return s + p.weight; }, 0);
  var r = Math.random() * totalW, potObj = EXP_POTIONS[0];
  for (var k = 0; k < EXP_POTIONS.length; k++) {
    r -= EXP_POTIONS[k].weight;
    if (r <= 0) { potObj = EXP_POTIONS[k]; break; }
  }
  var pKeys = { 'exp_s': 'potion_small', 'exp_m': 'potion_medium', 'exp_l': 'potion_large' };
  var freeItem = {
    type: 'potion', potionId: potObj.id, name: potObj.name,
    i18nNameKey: 'shop.' + pKeys[potObj.id],
    icon: potObj.icon, exp: potObj.exp, cost: 0, sold: false
  };
  showFreePotionModal(freeItem);
}

function doGachaAdMerc() {
  setGachaAdCooldown('merc');
  var classes = Object.keys(JAB).filter(function(c) { return !c.startsWith('summon'); });
  var cls = classes[Math.floor(Math.random() * classes.length)];
  var d = JAB[cls];
  var pot = {
    hp: +(d.growth.hp[0] + Math.random() * (d.growth.hp[1] - d.growth.hp[0])).toFixed(1),
    atk: +(d.growth.atk[0] + Math.random() * (d.growth.atk[1] - d.growth.atk[0])).toFixed(1),
    def: +(d.growth.def[0] + Math.random() * (d.growth.def[1] - d.growth.def[0])).toFixed(1)
  };
  var names = t('character.names');
  var nameIdx = Math.floor(Math.random() * names.length);
  addChar(cls, nameIdx, pot);
  var charName = names[nameIdx] || d.icon;
  showAlert(t('shop.gacha_ad_merc_success', { name: charName, cls: t('classes.' + cls) }));
  renderShop();
}

function doGachaAdSkill() {
  setGachaAdCooldown('skill');
  if (typeof LEARNABLE_SKILLS === 'undefined') return;
  var lsKeys = Object.keys(LEARNABLE_SKILLS);
  if (!lsKeys.length) return;
  var sk = LEARNABLE_SKILLS[lsKeys[Math.floor(Math.random() * lsKeys.length)]];
  var inv = loadInventory();
  inv.push({ id: sk.id, cls: sk.cls, lv: 1 });
  saveInventory(inv);
  showAlert(t('shop.gacha_ad_skill_success', { skill: t('skills.' + sk.id) }));
  renderShop();
}

function buildTabAdCard(type, descKey, fn) {
  var remain = Math.max(0, GACHA_AD_COOLDOWN_MS - (Date.now() - getGachaAdCooldown(type)));
  var canWatch = remain <= 0;
  var card = document.createElement('div');
  card.className = 'gold-ad-card shop-tab-ad';
  var btnText = canWatch ? t('shop.gacha_ad_btn') : t('shop.gacha_ad_cooldown', { minutes: Math.ceil(remain / 60000) });
  card.innerHTML =
    '<div class="gold-ad-icon">&#127916;</div>' +
    '<div class="gold-ad-info">' +
      '<div class="gold-ad-name">' + t(descKey) + '</div>' +
    '</div>' +
    '<button class="gold-ad-btn' + (canWatch ? '' : ' disabled') + '" ' + (canWatch ? '' : 'disabled') + '>' + btnText + '</button>';
  if (canWatch) {
    card.querySelector('.gold-ad-btn').onclick = fn;
  }
  return card;
}

function showFreePotionModal(item) {
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
    var charName = ch.customName || names[ch.nameId] || d.icon;
    var atMax = ch.lv >= MAX_LEVEL;
    var expNeed = atMax ? 0 : expForLevel(ch.lv);
    h += '<div class="pt-btn' + (atMax ? ' pt-max' : '') + '" data-uid="' + ch.uid + '">' +
      '<span class="pt-icon">' + clsIcon(ch.cls, 20) + '</span>' +
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
      var r = gainExp(uid, item.exp);
      ov.classList.remove('show');
      renderShop();
      if (r.leveled > 0) {
        var ch = getChar(uid);
        var d = JAB[ch.cls];
        var charName = ch.customName || names[ch.nameId] || d.icon;
        setTimeout(function() {
          showAlert(
            d.icon + ' ' + charName + '\nLv.' + r.prevLv + ' \u2192 Lv.' + ch.lv +
            (r.leveled > 1 ? ' (' + r.leveled + t('shop.gacha_ad_levelup') + ')' : '')
          );
        }, 100);
      }
    };
  });
}

function getAdCooldown() {
  try { var v = +localStorage.getItem(AD_COOLDOWN_KEY); return v || 0; } catch(_) { return 0; }
}

function setAdCooldown() {
  try { localStorage.setItem(AD_COOLDOWN_KEY, Date.now()); } catch(_) {}
}

function renderGoldShop(list) {
  list.style.display = 'flex';
  list.style.flexDirection = 'column';
  list.style.alignItems = 'center';
  list.style.gap = '10px';

  // 광고 섹션
  var adSection = document.createElement('div');
  adSection.className = 'gold-section';
  var adTitle = document.createElement('div');
  adTitle.className = 'gold-section-title';
  adTitle.textContent = t('shop.gold_ad_title');
  adSection.appendChild(adTitle);

  var adCard = document.createElement('div');
  adCard.className = 'gold-ad-card';
  var lastAd = getAdCooldown();
  var remain = Math.max(0, AD_COOLDOWN_MS - (Date.now() - lastAd));
  var canWatch = remain <= 0;
  var adBtnText = canWatch ? t('shop.gold_ad_btn') : t('shop.gold_ad_cooldown', { minutes: Math.ceil(remain / 60000) });
  adCard.innerHTML =
    '<div class="gold-ad-icon">&#127916;</div>' +
    '<div class="gold-ad-info">' +
      '<div class="gold-ad-name">' + t('shop.gold_ad_desc') + '</div>' +
    '</div>' +
    '<button class="gold-ad-btn' + (canWatch ? '' : ' disabled') + '" ' + (canWatch ? '' : 'disabled') + '>' + adBtnText + '</button>';
  if (canWatch) {
    adCard.querySelector('.gold-ad-btn').onclick = function() {
      setAdCooldown();
      _gold += AD_REWARD;
      saveGold(_gold);
      updateGoldUI();
      showAlert(t('shop.gold_ad_success'));
      renderShop();
    };
  }
  adSection.appendChild(adCard);
  list.appendChild(adSection);

  // IAP 패키지 섹션
  var iapSection = document.createElement('div');
  iapSection.className = 'gold-section';
  var iapTitle = document.createElement('div');
  iapTitle.className = 'gold-section-title';
  iapTitle.textContent = t('shop.gold_iap_title');
  iapSection.appendChild(iapTitle);

  var packages = [
    { gold: 500, price: '$0.99', key: 'gold_iap_500' },
    { gold: 1200, price: '$1.99', key: 'gold_iap_1200' },
    { gold: 3000, price: '$4.99', key: 'gold_iap_3000' },
    { gold: 6500, price: '$9.99', key: 'gold_iap_6500' }
  ];

  var iapGrid = document.createElement('div');
  iapGrid.className = 'gold-iap-grid';
  packages.forEach(function(pkg) {
    var card = document.createElement('div');
    card.className = 'gold-iap-card disabled';
    card.innerHTML =
      '<div class="gold-iap-icon">' + goldIcon(pkg.gold) + '</div>' +
      '<div class="gold-iap-amount">' + t('shop.' + pkg.key) + '</div>' +
      '<div class="gold-iap-price">' + pkg.price + '</div>' +
      '<div class="gold-iap-badge">' + t('shop.gold_iap_coming') + '</div>';
    iapGrid.appendChild(card);
  });
  iapSection.appendChild(iapGrid);
  list.appendChild(iapSection);
}

function goldIcon(amount) {
  if (amount >= 6500) return '&#x1F4B0;';
  if (amount >= 3000) return '&#x1F3C6;';
  if (amount >= 1200) return '&#x1F48E;';
  return '&#x1FA99;';
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
    var charName = ch.customName || names[ch.nameId] || d.icon;
    var atMax = ch.lv >= MAX_LEVEL;
    var expNeed = atMax ? 0 : expForLevel(ch.lv);
    h += '<div class="pt-btn' + (atMax ? ' pt-max' : '') + '" data-uid="' + ch.uid + '">' +
      '<span class="pt-icon">' + clsIcon(ch.cls, 20) + '</span>' +
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
        var charName = ch.customName || names[ch.nameId] || d.icon;
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


// ── 가챠 렌더링 ─────────────────────────
function renderGacha(list) {
  list.style.display = 'grid';
  list.style.gridTemplateColumns = 'repeat(2,1fr)';
  list.style.gap = '10px';

  // 천장 카운터 (2칸 차지)
  var pity = loadPity();
  var pityPct = Math.round(pity / GACHA_PITY_MAX * 100);
  var pityEl = document.createElement('div');
  pityEl.className = 'gacha-pity';
  pityEl.innerHTML =
    '<div class="gacha-pity-label">' + t('shop.gacha_pity', { current: pity, max: GACHA_PITY_MAX }) + '</div>' +
    '<div class="gacha-pity-bar"><div class="gacha-pity-fill" style="width:' + pityPct + '%"></div></div>';
  list.appendChild(pityEl);

  // 1회 뽑기 카드
  var c1 = document.createElement('div');
  c1.className = 'gacha-card';
  var canAfford1 = _gold >= GACHA_COST_1;
  c1.innerHTML =
    '<div class="gacha-icon">&#127922;</div>' +
    '<div class="gacha-title">' + t('shop.gacha_single') + '</div>' +
    '<div class="gacha-desc">' + t('shop.gacha_single_desc') + '</div>' +
    '<button class="gacha-btn' + (canAfford1 ? '' : ' disabled') + '" ' + (canAfford1 ? '' : 'disabled') + '>' + t('shop.gacha_pull_1', { gold: GACHA_COST_1 }) + '</button>';
  if (canAfford1) c1.querySelector('.gacha-btn').onclick = function() { doGacha(1); };
  list.appendChild(c1);

  // 10+1 뽑기 카드
  var c10 = document.createElement('div');
  c10.className = 'gacha-card gacha-multi';
  var canAfford10 = _gold >= GACHA_COST_10;
  c10.innerHTML =
    '<div class="gacha-icon">&#127921;</div>' +
    '<div class="gacha-title">' + t('shop.gacha_multi') + '</div>' +
    '<div class="gacha-desc">' + t('shop.gacha_multi_desc') + '</div>' +
    '<button class="gacha-btn gacha-btn-multi' + (canAfford10 ? '' : ' disabled') + '" ' + (canAfford10 ? '' : 'disabled') + '>' + t('shop.gacha_pull_10', { gold: GACHA_COST_10 }) + '</button>';
  if (canAfford10) c10.querySelector('.gacha-btn').onclick = function() { doGacha(10); };
  list.appendChild(c10);

  // 광고 보상 카드 (2칸 차지)
  list.appendChild(buildTabAdCard('equip', 'shop.ad_equip_desc', doGachaAdEquip));

  // 확률표 (2칸 차지)
  var rateEl = document.createElement('div');
  rateEl.className = 'gacha-rates-full';
  rateEl.innerHTML = gachaRatesHtml();
  list.appendChild(rateEl);
}

function gachaRatesHtml() {
  var html = '<div class="gacha-rate-row">';
  var names = { common: t('equip.rarity.common'), uncommon: t('equip.rarity.uncommon'), rare: t('equip.rarity.rare'), epic: t('equip.rarity.epic'), legendary: t('equip.rarity.legendary') };
  for (var r in GACHA_RATE) {
    var pct = GACHA_RATE[r] * 100;
    var pctStr = pct >= 1 ? pct.toFixed(0) : pct.toFixed(pct >= 0.1 ? 1 : 2);
    html += '<span style="color:' + RARITY[r].color + '">' + names[r] + ' ' + pctStr + '%</span> ';
  }
  return html + '</div>';
}

function doGacha(count) {
  var cost = count === 1 ? GACHA_COST_1 : GACHA_COST_10;
  var pullCount = count === 1 ? 1 : GACHA_MULTI_COUNT;
  if (_gold < cost) return;
  _gold -= cost;
  saveGold(_gold);
  updateGoldUI();

  var results = [];
  for (var i = 0; i < pullCount; i++) {
    var minRarity = null;
    if (count === 10 && i === pullCount - 1) minRarity = 'rare';
    results.push(gachaPull(minRarity));
  }
  var inv = loadInventory();
  for (var j = 0; j < results.length; j++) inv.push(results[j]);
  saveInventory(inv);
  showGachaResults(results);
}

function showGachaResults(results) {
  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = t('shop.gacha_results');
  document.getElementById('modal-title').className = '';
  var h = '<div class="gacha-results">';
  for (var i = 0; i < results.length; i++) {
    var item = results[i];
    var rc = RARITY[item.rarity].color;
    var statsArr = [];
    for (var s in item.stats) {
      statsArr.push(t('common.' + s) + '+' + item.stats[s]);
    }
    h += '<div class="gacha-result-card" style="border-color:' + rc + '">' +
      '<div class="gr-rarity" style="color:' + rc + '">' + t('equip.rarity.' + item.rarity) + '</div>' +
      '<div class="gr-name">' + t('equip.item.' + item.templateId) + '</div>' +
      '<div class="gr-slot">' + t('equip.slot.' + item.slot) + '</div>' +
      '<div class="gr-stats">' + statsArr.join(' ') + '</div>' +
      (item.setId ? '<div class="gr-set" style="color:#f0c040">' + t('equip.set.' + item.setId) + '</div>' : '') +
      '</div>';
  }
  h += '</div>';
  document.getElementById('modal-sub').innerHTML = h;
  var bt = document.getElementById('modal-buttons');
  bt.innerHTML = '';
  var cb = document.createElement('button');
  cb.className = 'modal-btn';
  cb.textContent = t('common.confirm');
  cb.onclick = function() { ov.classList.remove('show'); renderShop(); };
  bt.appendChild(cb);
  ov.classList.add('show');
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
