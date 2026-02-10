// equip.js — Equipment management page
var ROSTER_KEY = 'game_roster';
var SAVE_KEY = 'game_save';

var _gold = 0;
var _selUid = null;
var _invFilter = 'all';

function loadGold() {
  try { var d = JSON.parse(localStorage.getItem(SAVE_KEY)); return d ? d.gold || 0 : 0; } catch (_) { return 0; }
}
function saveGold(gold) {
  try { var d = JSON.parse(localStorage.getItem(SAVE_KEY)) || {}; d.gold = gold; localStorage.setItem(SAVE_KEY, JSON.stringify(d)); } catch (_) {}
}
function updateGoldUI() {
  var el = document.getElementById('eq-gold-val');
  if (el) el.textContent = _gold.toLocaleString();
}
function getRoster() {
  try { var raw = localStorage.getItem(ROSTER_KEY); if (raw) return JSON.parse(raw); } catch (_) {}
  return { chars: [], nextId: 1 };
}
function saveRoster(data) {
  try { localStorage.setItem(ROSTER_KEY, JSON.stringify(data)); } catch (_) {}
}

// ── Character scroll bar ──
function renderChars() {
  var el = document.getElementById('eq-chars');
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
      '<span class="cls-icon" style="font-size:22px">' + d.icon + '</span>' +
      '<span class="eq-char-name">' + charName + '</span>' +
      '<span class="eq-char-lv">Lv.' + ch.lv + '</span>';
    btn.onclick = function() { _selUid = ch.uid; renderAll(); };
    el.appendChild(btn);
  });
}

// ── Main body ──
function renderBody() {
  var body = document.getElementById('eq-body');
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
      renderAll();
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

// ── Core functions ──
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
  renderAll();
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
  renderAll();
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
      updateGoldUI();
      renderAll();
    }
  );
}

function renderAll() {
  renderChars();
  renderBody();
}

// ── Init ──
var init = async function() {
  await i18nInit();
  _gold = loadGold();
  updateGoldUI();
  renderAll();
  renderBottomNav();
  setTimeout(function() { document.getElementById('splash').style.display = 'none'; }, 300);
};
