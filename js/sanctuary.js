// sanctuary.js — 성소 페이지 전용 스크립트
// G/ROSTER/CD 의존 없이 JAB + localStorage 직접 조작

var SAVE_KEY = 'game_save';
var ROSTER_KEY = 'game_roster';

// ── 골드 관리 ─────────────────────────────
var _gold = 0;

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
  var el = document.getElementById('sanc-gold-val');
  if (el) el.textContent = _gold.toLocaleString();
}

// ── 로스터 조작 ──────────────────────────
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

// ── 부활 비용 ────────────────────────────
function reviveCost(ch) { return 20 + ch.lv * 10; }

// ── 성소 렌더링 ─────────────────────────
function renderSanctuary() {
  var list = document.getElementById('sanc-list');
  var roster = getRoster();
  var dead = roster.chars.filter(function(c) { return c.dead && !c.cls.startsWith('summon_'); });
  list.innerHTML = '';

  if (!dead.length) {
    list.innerHTML = '<div style="color:var(--dim);font-size:12px;text-align:center;padding:20px">' + t('sanctuary.no_dead_units') + '</div>';
    return;
  }

  var names = t('character.names');

  dead.forEach(function(ch) {
    var d = JAB[ch.cls];
    var cost = reviveCost(ch);
    var canAfford = _gold >= cost;
    var el = document.createElement('div');
    el.className = 'sanc-card';
    var charName = names[ch.nameId] || d.icon;
    el.innerHTML =
      '<div class="sanc-icon"><span class="cls-icon" style="font-size:28px">' + d.icon + '</span></div>' +
      '<div class="sanc-info"><div class="sanc-name">' + charName + ' <span style="color:#64748b;font-size:10px">Lv.' + ch.lv + '</span></div>' +
      '<div class="sanc-stats">HP ' + ch.hp + ' \xb7 ATK ' + ch.atk + ' \xb7 DEF ' + ch.def + '</div></div>' +
      '<button class="sanc-btn' + (canAfford ? '' : ' disabled') + '" ' + (canAfford ? '' : 'disabled') + '>' + t('sanctuary.resurrect_button', { cost: cost }) + '</button>';
    el.querySelector('.sanc-btn').onclick = (function(uid, cost) {
      return function() {
        if (_gold < cost) return;
        _gold -= cost;
        saveGold(_gold);
        updateGoldUI();
        // 부활 처리
        var roster = getRoster();
        var ch = roster.chars.find(function(c) { return c.uid === uid; });
        if (ch) { ch.dead = false; saveRoster(roster); }
        renderSanctuary();
      };
    })(ch.uid, cost);
    list.appendChild(el);
  });
}

// ── 초기화 ───────────────────────────────
var init = async function() {
  await i18nInit();
  _gold = loadGold();
  updateGoldUI();
  renderSanctuary();
  renderBottomNav();
  setTimeout(function() { document.getElementById('splash').style.display = 'none'; }, 300);
};
