// shop.js — 상점 페이지 전용 스크립트
// G/ROSTER/CD 의존 없이 JAB + localStorage 직접 조작

// ── 상수 ──────────────────────────────────
var EXP_POTIONS = [
  { id: 'exp_s', name: '\uc18c\ud615 \uacbd\ud5d8\uce58 \ubb3c\uc57d', icon: '\ud83e\uddea', exp: 50, cost: 400, weight: 50 },
  { id: 'exp_m', name: '\uc911\ud615 \uacbd\ud5d8\uce58 \ubb3c\uc57d', icon: '\u2697\ufe0f', exp: 150, cost: 1000, weight: 35 },
  { id: 'exp_l', name: '\ub300\ud615 \uacbd\ud5d8\uce58 \ubb3c\uc57d', icon: '\ud83c\udfd0', exp: 400, cost: 2400, weight: 15 }
];

// 전투 포션 (BATTLE_POTIONS는 data/equip.js에서 정의)
var BATTLE_POTION_LIST = [
  { potionId: 'potion_heal', weight: 40 },
  { potionId: 'potion_resource', weight: 30 },
  { potionId: 'potion_atk_buff', weight: 20 },
  { potionId: 'potion_def_buff', weight: 20 },
  { potionId: 'potion_atk_debuff', weight: 15 },
  { potionId: 'potion_def_debuff', weight: 15 }
];

function genPotionId() {
  return 'pot_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 6);
}

function genSiegeId() {
  return 'siege_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 6);
}

var SCROLL_CLASSES = ['warrior','knight','assassin','brawler','lancer','sapper','archer','mage','summoner','shaman','priest'];
var SCROLL_COST = 400;

// ── 골드 관리 ─────────────────────────────

function updateGoldUI() {
  updatePageGold('shop-gold-val');
}

// 현재 골드 (페이지 내 캐시)
var _gold = 0;

// ── 로스터 직접 조작 ─────────────────────

// Character functions moved to js/common/character.js


// ── 상점 데이터 ──────────────────────────
var _shopData = null;
var _currentTab = 'mercenary';

function loadShop() {
  try {
    var raw = localStorage.getItem(SHOP_KEY);
    if (raw) {
      var data = JSON.parse(raw);
      // 1시간 이상 지났으면 갱신 아이템만 새로 생성
      if (Date.now() - data.ts >= SHOP_REFRESH_INTERVAL) {
        refreshRotatingItems(data);
      }
      _shopData = data;
      return;
    }
  } catch (_) {}
  genShop();
}


function genRotatingItems() {
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
  // 스킬북 6개 (중복 없음)
  if (typeof LEARNABLE_SKILLS !== 'undefined') {
    var lsKeys = Object.keys(LEARNABLE_SKILLS).sort(function() { return Math.random() - 0.5; });
    var sbCount = Math.min(6, lsKeys.length);
    for (var sb = 0; sb < sbCount; sb++) {
      var sk = LEARNABLE_SKILLS[lsKeys[sb]];
      items.push({
        type: 'skillbook', skillId: sk.id, cls: sk.cls, cost: 800, sold: false
      });
    }
  }
  // 전직서 6개 (랜덤 직업)
  var shuffled = SCROLL_CLASSES.slice().sort(function() { return Math.random() - 0.5; });
  for (var si = 0; si < 6; si++) {
    items.push({
      type: 'scroll', scrollCls: shuffled[si], cost: SCROLL_COST, sold: false
    });
  }
  return items;
}

function genFixedItems() {
  var items = [];
  var potionKeys = { 'exp_s': 'potion_small', 'exp_m': 'potion_medium', 'exp_l': 'potion_large' };
  for (var j = 0; j < EXP_POTIONS.length; j++) {
    var potObj = EXP_POTIONS[j];
    items.push({
      type: 'potion', potionId: potObj.id, name: potObj.name,
      i18nNameKey: 'shop.' + potionKeys[potObj.id],
      icon: potObj.icon, exp: potObj.exp, cost: potObj.cost, sold: false, quantity: 1
    });
  }
  // 전투 포션 6가지 (각 1개씩, 중복 없음)
  if (typeof BATTLE_POTIONS !== 'undefined' && BATTLE_POTION_LIST) {
    for (var bp = 0; bp < BATTLE_POTION_LIST.length; bp++) {
      var bpDef = BATTLE_POTIONS[BATTLE_POTION_LIST[bp].potionId];
      if (bpDef) {
        items.push({
          type: 'battle_potion', potionId: BATTLE_POTION_LIST[bp].potionId,
          name: bpDef.name, icon: bpDef.icon,
          cost: 150, sold: false, quantity: 1
        });
      }
    }
  }
  // 공성 아이템 전체 (각 1개씩, 중복 없음)
  if (typeof SIEGE_ITEMS !== 'undefined') {
    for (var si2 = 0; si2 < SIEGE_ITEMS.length; si2++) {
      items.push({
        type: 'siege', siegeId: SIEGE_ITEMS[si2].id, icon: SIEGE_ITEMS[si2].icon,
        cost: SIEGE_ITEMS[si2].cost, sold: false, quantity: 1
      });
    }
  }
  return items;
}

function refreshRotatingItems(data) {
  var rotatingItems = genRotatingItems();
  var newItems = [];
  // 고정 아이템 유지
  for (var i = 0; i < data.items.length; i++) {
    var item = data.items[i];
    if (['potion', 'battle_potion', 'siege'].indexOf(item.type) >= 0) {
      newItems.push(item);
    }
  }
  // 갱신 아이템 추가
  newItems = newItems.concat(rotatingItems);
  data.items = newItems;
  data.ts = Date.now();
  saveShop();
}

function genShop() {
  var items = [];
  items = items.concat(genFixedItems());
  items = items.concat(genRotatingItems());
  _shopData = { ts: Date.now(), items: items };
  saveShop();
}

function saveShop() {
  try { localStorage.setItem(SHOP_KEY, JSON.stringify(_shopData)); } catch (_) {}
}

// ── 상점 갱신 시간 ───────────────────────
var SHOP_REFRESH_INTERVAL = 60 * 60 * 1000; // 1시간

function getShopRefreshTime() {
  if (!_shopData || !_shopData.ts) return null;
  var elapsed = Date.now() - _shopData.ts;
  var remaining = SHOP_REFRESH_INTERVAL - (elapsed % SHOP_REFRESH_INTERVAL);
  var totalSeconds = Math.floor(remaining / 1000);
  var hours = Math.floor(totalSeconds / 3600);
  var minutes = Math.floor((totalSeconds % 3600) / 60);
  var seconds = totalSeconds % 60;
  return { hours: hours, minutes: minutes, seconds: seconds };
}

function updateShopTimer() {
  var timerEl = document.getElementById('shop-timer');
  if (!timerEl) return;
  // 소모품, 골드 탭은 타이머 숨김
  var timerHiddenTabs = ['consumable', 'gold'];
  if (timerHiddenTabs.indexOf(_currentTab) >= 0) {
    timerEl.style.display = 'none';
    return;
  }
  timerEl.style.display = '';
  var time = getShopRefreshTime();
  if (!time) { timerEl.style.display = 'none'; return; }
  timerEl.innerHTML = t('shop.refresh_timer', { hours: time.hours, minutes: ('0' + time.minutes).slice(-2), seconds: ('0' + time.seconds).slice(-2) });
}

// ── 탭 전환 ──────────────────────────────
function switchTab(tab) {
  _currentTab = tab;
  toggleTabButtons(tab);
  renderShop();
}

// ── 렌더링 ───────────────────────────────
function renderShop() {
  var list = document.getElementById('shop-list'); list.innerHTML = '';
  list.style.display = ''; list.style.flexDirection = ''; list.style.alignItems = ''; list.style.gap = ''; list.style.gridTemplateColumns = '';
  var titleEl = document.getElementById('shop-info-title');
  var tabTitles = {
    'mercenary': t('shop.subtitle_mercenary'),
    'consumable': t('shop.subtitle_consumable'),
    'equip': t('shop.subtitle_equip'),
    'skill': t('shop.subtitle_skill'),
    'scroll': t('shop.subtitle_scroll'),
    'gold': t('shop.subtitle_gold')
  };
  titleEl.textContent = tabTitles[_currentTab] || t('shop.title');
  updateShopTimer();

  if (_currentTab === 'equip') {
    renderGacha(list);
    return;
  }

  if (_currentTab === 'scroll') {
    renderScrollShop(list);
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

  var tabTypeMap = { 'mercenary': ['char'], 'consumable': ['potion', 'battle_potion', 'siege'], 'skill': ['skillbook'] };
  var filterTypes = tabTypeMap[_currentTab] || [];
  var filteredItems = _shopData.items.filter(function(item) {
    var iType = item.type || 'char';
    return filterTypes.indexOf(iType) >= 0;
  });

  filteredItems.forEach(function(item) {
    var iType = item.type || 'char';
    if (iType === 'char') renderCharCard(item, list);
    else if (iType === 'potion') renderPotionCard(item, list);
    else if (iType === 'battle_potion') renderBattlePotionCard(item, list);
    else if (iType === 'siege') renderSiegeCard(item, list);
    else if (iType === 'skillbook') renderSkillBookCard(item, list);
  });

  // 마지막에 spacer 추가
  var spacer = document.createElement('div');
  spacer.className = 'shop-list-spacer';
  list.appendChild(spacer);
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
  var canAfford = _gold >= item.cost;
  var el = document.createElement('div');
  el.className = 'shop-card potion-card';
  var buyBtn = t('shop.buy', { gold: item.cost });
  var potionName = item.i18nNameKey ? t(item.i18nNameKey) : item.name;
  el.innerHTML =
    '<div class="shop-icon">' + item.icon + '</div>' +
    '<div class="shop-name">' + potionName + '</div>' +
    (item.exp ? '<div class="shop-cls">' + t('common.exp') + ' +' + item.exp + '</div>' : '') +
    '<button class="shop-btn potion-btn' + (canAfford ? '' : ' disabled') + '" ' + (canAfford ? '' : 'disabled') + '>' + buyBtn + '</button>';
  el.querySelector('.shop-btn').onclick = function() {
    if (_gold < item.cost) return;
    var potionName = item.i18nNameKey ? t(item.i18nNameKey) : item.name;
    showConfirm(t('shop.potion_buy_confirm', { potion: potionName, gold: item.cost }), function() {
      _gold -= item.cost;
      saveGold(_gold);
      updateGoldUI();
      var inv = loadInventory();
      var potItem = {
        type: 'potion',
        pid: genPotionId(),
        potionId: item.potionId,
        exp: item.exp,
        icon: item.icon,
        quantity: item.quantity || 1
      };
      inv.push(potItem);
      saveInventory(inv);
      showAlert(potionName + ' ' + t('shop.potion_stored'));
    });
  };
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
    '<div class="shop-icon">' + skillIcon(item.skillId, 36) + '</div>' +
    '<div class="shop-name">' + skillName + ' <span class="sb-cls-label">' + clsName + '</span></div>' +
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

function renderBattlePotionCard(item, list) {
  var canAfford = _gold >= item.cost && !item.sold;
  var potDef = BATTLE_POTIONS[item.potionId];
  if (!potDef) return;
  var el = document.createElement('div');
  el.className = 'shop-card potion-card';
  var buyBtn = t('shop.buy', { gold: item.cost });
  el.innerHTML =
    '<div class="shop-icon">' + potDef.icon + '</div>' +
    '<div class="shop-name">' + t('battle_potions.' + item.potionId) + '</div>' +
    '<div class="shop-cls">' + t('battle_potions.' + item.potionId + '_desc') + '</div>' +
    '<button class="shop-btn potion-btn' + (canAfford ? '' : ' disabled') + '" ' + (canAfford ? '' : 'disabled') + '>' + buyBtn + '</button>';
  el.querySelector('.shop-btn').onclick = function() {
    if (_gold < item.cost) return;
    var potName = t('battle_potions.' + item.potionId);
    showConfirm(t('shop.battle_potion_buy_confirm', { name: potName, gold: item.cost }), function() {
      _gold -= item.cost;
      saveGold(_gold);
      updateGoldUI();
      var inv = loadInventory();
      inv.push({
        type: 'battle_potion',
        pid: genPotionId(),
        potionId: item.potionId,
        icon: potDef.icon,
        quantity: item.quantity || 1
      });
      saveInventory(inv);
      showAlert(t('shop.battle_potion_stored', { name: potName }));
    });
  };
  list.appendChild(el);
}

function renderSiegeCard(item, list) {
  var canAfford = _gold >= item.cost;
  var siegeName = t('shop.' + item.siegeId);
  var siegeDesc = t('shop.' + item.siegeId + '_desc');
  var el = document.createElement('div');
  el.className = 'shop-card potion-card';
  var buyBtn = t('shop.buy', { gold: item.cost });
  el.innerHTML =
    '<div class="shop-icon">' + item.icon + '</div>' +
    '<div class="shop-name">' + siegeName + '</div>' +
    '<div class="shop-cls">' + siegeDesc + '</div>' +
    '<button class="shop-btn potion-btn' + (canAfford ? '' : ' disabled') + '" ' + (canAfford ? '' : 'disabled') + '>' + buyBtn + '</button>';
  el.querySelector('.shop-btn').onclick = function() {
    if (_gold < item.cost) return;
    showConfirm(t('shop.siege_buy_confirm', { item: siegeName, gold: item.cost }), function() {
      _gold -= item.cost;
      saveGold(_gold);
      updateGoldUI();
      var inv = loadInventory();
      inv.push({
        type: 'siege',
        sid: genSiegeId(),
        siegeId: item.siegeId,
        icon: item.icon,
        quantity: item.quantity || 1
      });
      saveInventory(inv);
      showAlert(siegeName + ' ' + t('shop.siege_stored'));
    });
  };
  list.appendChild(el);
}

// ── 골드 상점 ───────────────────────────
var AD_COOLDOWN_KEY = 'game_ad_cooldown';
var AD_COOLDOWN_MS = 10 * 60 * 1000; // 10분
var AD_REWARD = 500;

// ── 가챠 광고 보상 ──────────────────────
var GACHA_AD_KEYS = {
  equip:  'game_gacha_ad_equip',
  item:   'game_gacha_ad_item',
  merc:   'game_gacha_ad_merc',
  skill:  'game_gacha_ad_skill',
  scroll: 'game_gacha_ad_scroll'
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
  var item = gachaPull(null, true);
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
  var inv = loadInventory();
  inv.push({ type: 'potion', potionId: potObj.id, exp: potObj.exp, icon: potObj.icon });
  saveInventory(inv);
  var pKeys = { 'exp_s': 'potion_small', 'exp_m': 'potion_medium', 'exp_l': 'potion_large' };
  var potionName = t('shop.' + pKeys[potObj.id]);
  showAlert(potionName + ' ' + t('shop.potion_stored'));
  renderShop();
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

function doGachaAdScroll() {
  setGachaAdCooldown('scroll');
  var cls = SCROLL_CLASSES[Math.floor(Math.random() * SCROLL_CLASSES.length)];
  var inv = loadInventory();
  inv.push({ type: 'scroll', scrollCls: cls });
  saveInventory(inv);
  var scrollName = t('shop.scroll_prefix') + ' ' + t('classes.' + cls);
  showAlert(scrollName + ' ' + t('shop.scroll_stored'));
  renderShop();
}

function buildTabAdCard(type, descKey, fn) {
  var card = document.createElement('div');
  card.className = 'gold-ad-card shop-tab-ad';
  card.innerHTML =
    '<div class="gold-ad-icon">&#127916;</div>' +
    '<div class="gold-ad-info">' +
      '<div class="gold-ad-name">' + t(descKey) + '</div>' +
    '</div>' +
    '<button class="gold-ad-btn disabled" disabled>📋 추후 개발</button>';
  return card;
}


function getAdCooldown() {
  try { var v = +localStorage.getItem(AD_COOLDOWN_KEY); return v || 0; } catch(_) { return 0; }
}

function setAdCooldown() {
  try { localStorage.setItem(AD_COOLDOWN_KEY, Date.now()); } catch(_) {}
}

function renderGoldShop(list) {
  list.style.display = 'block';
  list.style.gridTemplateColumns = '';
  list.style.flexDirection = '';
  list.style.alignItems = '';
  list.style.gap = '';

  // 광고 섹션
  var adSection = document.createElement('div');
  adSection.className = 'gold-section';

  var adCard = document.createElement('div');
  adCard.className = 'gold-ad-card';
  adCard.innerHTML =
    '<div class="gold-ad-icon">&#127916;</div>' +
    '<div class="gold-ad-info"><div class="gold-ad-name">' + t('shop.gold_ad_title') + ' ' + t('shop.gold_ad_desc') + '</div></div>' +
    '<button class="gold-ad-btn disabled" disabled>📋 추후 개발</button>';
  adSection.appendChild(adCard);
  list.appendChild(adSection);

  // IAP 패키지 섹션
  var iapSection = document.createElement('div');
  iapSection.className = 'gold-section';

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

// ── 전직서 렌더링 ─────────────────────────
function renderScrollShop(list) {
  list.style.display = 'grid';
  list.style.gridTemplateColumns = 'repeat(2,1fr)';
  list.style.gap = '10px';

  // 광고 보상 카드
  list.appendChild(buildTabAdCard('scroll', 'shop.ad_scroll_desc', doGachaAdScroll));

  var scrollItems = _shopData.items.filter(function(item) { return item.type === 'scroll'; });

  scrollItems.forEach(function(item) {
    var cls = item.scrollCls;
    var d = JAB[cls];
    if (!d) return;
    var canAfford = _gold >= item.cost && !item.sold;
    var scrollName = t('shop.scroll_prefix') + ' ' + t('classes.' + cls);
    var el = document.createElement('div');
    el.className = 'shop-card scroll-card' + (item.sold ? ' sold' : '');
    var buyBtn = item.sold ? t('shop.buy_complete') : t('shop.buy', { gold: item.cost });
    el.innerHTML =
      '<div class="shop-icon">' + clsIcon(cls, 36) + '</div>' +
      '<div class="shop-name">' + scrollName + '</div>' +
      '<div class="shop-cls">' + t('class_desc.' + cls) + '</div>' +
      '<button class="shop-btn scroll-btn' + (item.sold ? ' sold-btn' : '') + (canAfford ? '' : ' disabled') + '" ' + (canAfford && !item.sold ? '' : 'disabled') + '>' + buyBtn + '</button>';
    if (!item.sold) {
      el.querySelector('.shop-btn').onclick = (function(itm, sName) {
        return function() {
          if (_gold < itm.cost) return;
          showConfirm(t('shop.scroll_buy_confirm', { scroll: sName, gold: itm.cost }), function() {
            _gold -= itm.cost;
            saveGold(_gold);
            updateGoldUI();
            var inv = loadInventory();
            inv.push({ type: 'scroll', scrollCls: itm.scrollCls });
            saveInventory(inv);
            itm.sold = true;
            saveShop();
            renderShop();
            showAlert(sName + ' ' + t('shop.scroll_stored'));
          });
        };
      })(item, scrollName);
    }
    list.appendChild(el);
  });

  // 마지막에 spacer 추가
  var spacer = document.createElement('div');
  spacer.className = 'shop-list-spacer';
  list.appendChild(spacer);
}

function goldIcon(amount) {
  if (amount >= 6500) return '&#x1F4B0;';
  if (amount >= 3000) return '&#x1F3C6;';
  if (amount >= 1200) return '&#x1F48E;';
  return '&#x1FA99;';
}


// ── 가챠 렌더링 ─────────────────────────
function renderGacha(list) {
  list.style.display = 'grid';
  list.style.gridTemplateColumns = 'repeat(2,1fr)';
  list.style.gap = '10px';

  // 광고 보상 카드 (최상단, 2칸 차지)
  list.appendChild(buildTabAdCard('equip', 'shop.ad_equip_desc', doGachaAdEquip));

  // 천장 카운터 (2칸 차지)
  var pity = loadPity();
  var pityPct = Math.round(pity / GACHA_PITY_MAX * 100);
  var pityEl = document.createElement('div');
  pityEl.className = 'gacha-pity';
  pityEl.innerHTML =
    '<div class="gacha-pity-label">' + t('shop.gacha_pity', { current: pity, max: GACHA_PITY_MAX }) + '</div>' +
    '<div class="gacha-pity-bar"><div class="gacha-pity-fill" style="width:' + pityPct + '%"></div></div>';
  list.appendChild(pityEl);

  // 확률표 (2칸 차지)
  var rateEl = document.createElement('div');
  rateEl.className = 'gacha-rates-full';
  rateEl.innerHTML = gachaRatesHtml();
  list.appendChild(rateEl);

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

  // 마지막에 spacer 추가
  var spacer = document.createElement('div');
  spacer.className = 'shop-list-spacer';
  list.appendChild(spacer);
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
  // 타이머를 1초마다 업데이트
  setInterval(updateShopTimer, 1000);
  setTimeout(function() { document.getElementById('splash').style.display = 'none'; }, 300);
};
