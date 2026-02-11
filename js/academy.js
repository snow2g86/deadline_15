// academy.js — 아카데미 페이지 전용 스크립트
// G/ROSTER/CD 의존 없이 JAB + localStorage 직접 조작

var SAVE_KEY = 'game_save';
var ROSTER_KEY = 'game_roster';
function clsIcon(cls, size) {
  var d = JAB[cls]; if (!d) return '';
  return '<img class="cls-icon" src="image/icon/jab/' + cls + '.png" alt="' + cls + '" style="width:' + size + 'px;height:' + size + 'px">';
}
var INVENTORY_KEY = 'game_inventory';
var CLASS_CHANGE_COST = 500;
var MAX_SKILL_LV = 10;
var _currentTab = 'classchange';

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
  var el = document.getElementById('acad-gold-val');
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

function getChar(uid) {
  var roster = getRoster();
  return roster.chars.find(function(c) { return c.uid === uid; });
}

// ── 인벤토리 관리 ─────────────────────────
function loadInventory() {
  try {
    var raw = localStorage.getItem(INVENTORY_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}
  return [];
}

function saveInventory(inv) {
  try { localStorage.setItem(INVENTORY_KEY, JSON.stringify(inv)); } catch (_) {}
}

// ── 스킬 유틸 ─────────────────────────────
function getCharSkillLv(ch, skillId) {
  // 습득형 스킬: skillLv에 없으면 0 (미습득)
  if (typeof LEARNABLE_SKILLS !== 'undefined' && LEARNABLE_SKILLS[skillId]) {
    return (ch.skillLv && ch.skillLv[skillId]) || 0;
  }
  // 기본 스킬: skillLv에 없으면 1
  if (ch.skillLv && ch.skillLv[skillId]) return ch.skillLv[skillId];
  return 1;
}

function getCharSkills(cls) {
  var sk = SKILLS[cls];
  if (!sk) return [];
  var arr = Array.isArray(sk) ? sk : [sk];
  // 습득형 스킬도 포함 (스킬북 대상 필터링용)
  if (typeof LEARNABLE_SKILLS !== 'undefined') {
    Object.keys(LEARNABLE_SKILLS).forEach(function(skId) {
      var lsk = LEARNABLE_SKILLS[skId];
      if (lsk.cls === cls) arr = arr.concat([lsk]);
    });
  }
  return arr;
}

// ── 전직 유틸 ─────────────────────────────
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

// ── 탭 전환 ──────────────────────────────
function switchTab(tab) {
  _currentTab = tab;
  document.querySelectorAll('.acad-tab-btn').forEach(function(btn) {
    btn.classList.toggle('active', btn.dataset.tab === tab);
  });
  var sub = document.getElementById('acad-subtitle');
  if (sub) {
    sub.textContent = tab === 'classchange' ? t('academy.subtitle') : t('academy.skillbook_subtitle');
  }
  var ccList = document.getElementById('academy-list');
  var sbList = document.getElementById('skillbook-list');
  if (tab === 'classchange') {
    ccList.classList.remove('hidden'); sbList.classList.add('hidden');
    renderAcademy();
  } else {
    ccList.classList.add('hidden'); sbList.classList.remove('hidden');
    renderSkillBooks();
  }
}

// ── 전직 탭: 아카데미 렌더링 ─────────────
function renderAcademy() {
  var list = document.getElementById('academy-list');
  var roster = getRoster();
  var novices = roster.chars.filter(function(c) { return !c.dead && c.cls === 'novice' && !c.cls.startsWith('summon_'); });
  list.innerHTML = '';

  if (!novices.length) {
    list.innerHTML = '<div style="color:var(--dim);font-size:12px;text-align:center;padding:20px">' + t('academy.no_novice') + '</div>';
    return;
  }

  var names = t('character.names');

  novices.forEach(function(ch) {
    var d = JAB[ch.cls];
    var grade = potGrade(ch);
    var gClr = grade === 'S' ? '#f0c040' : grade === 'A' ? '#60a5fa' : grade === 'B' ? '#4ade80' : '#9ca3af';
    var canAfford = _gold >= CLASS_CHANGE_COST;
    var charName = ch.customName || names[ch.nameId] || d.icon;
    var el = document.createElement('div');
    el.className = 'acad-card';
    el.innerHTML =
      '<div class="acad-icon">' + clsIcon(ch.cls, 28) + '</div>' +
      '<div class="acad-info">' +
        '<div class="acad-name">' + charName + ' <span style="color:#64748b;font-size:10px">Lv.' + ch.lv + '</span> <span style="color:' + gClr + ';font-size:10px;font-weight:900">' + grade + '</span></div>' +
        '<div class="acad-stats">HP ' + ch.hp + ' \xb7 ATK ' + ch.atk + ' \xb7 DEF ' + ch.def + '</div>' +
      '</div>' +
      '<button class="acad-btn' + (canAfford ? '' : ' disabled') + '" ' + (canAfford ? '' : 'disabled') + '>' + t('academy.class_change_btn', { cost: CLASS_CHANGE_COST }) + '</button>';
    el.querySelector('.acad-btn').onclick = (function(uid) {
      return function() {
        if (_gold < CLASS_CHANGE_COST) return;
        showClassSelectModal(uid);
      };
    })(ch.uid);
    list.appendChild(el);
  });
}

// ── 전직 모달: 직업 선택 ─────────────────
function showClassSelectModal(uid) {
  var ch = getChar(uid);
  if (!ch) return;
  var allClasses = Object.keys(JAB).filter(function(c) { return c !== 'novice' && !c.startsWith('summon_'); });
  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = t('class_change.select_class');
  document.getElementById('modal-title').className = '';
  var h = '<div class="class-select-grid">';
  allClasses.forEach(function(cls) {
    var d = JAB[cls];
    h += '<div class="cs-card" data-cls="' + cls + '">' +
      '<div class="cs-icon">' + clsIcon(cls, 28) + '</div>' +
      '<div class="cs-name">' + t('classes.' + cls) + '</div>' +
      '<div class="cs-stats">HP ' + d.base.hp + ' ATK ' + d.base.atk + ' DEF ' + d.base.def + '</div>' +
      '<div class="cs-role">' + t('class_desc.' + cls) + '</div>' +
      '</div>';
  });
  h += '</div>';
  var names = t('character.names');
  var charName = ch.customName || names[ch.nameId] || '???';
  document.getElementById('modal-sub').innerHTML =
    clsIcon(ch.cls, 24) + ' <b>' + charName + '</b> (Lv.' + ch.lv + ')<br>' +
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
      confirmClassChange(uid, newCls);
    };
  });
}

// ── 전직 모달: 최종 확인 ─────────────────
function confirmClassChange(uid, newCls) {
  var ch = getChar(uid);
  if (!ch) return;
  var oldD = JAB[ch.cls];
  var newD = JAB[newCls];
  var grade = potGrade(ch);
  var preview = previewClassChange(ch, newCls);
  var names = t('character.names');
  var charName = ch.customName || names[ch.nameId] || '???';
  var origClass = ch.cls;
  showConfirm(
    oldD.icon + ' ' + charName + ' (Lv.' + ch.lv + ' ' + grade + t('class_change.grade_suffix') + ')\n' +
    t('classes.' + ch.cls) + ' \u2192 ' + newD.icon + ' ' + t('classes.' + newCls) + '\n\n' +
    t('class_change.stats_preview') + '\n' +
    'HP ' + preview.hp + ' / ATK ' + preview.atk + ' / DEF ' + preview.def + '\n' +
    'MOV ' + preview.move + ' / RNG ' + preview.range + '\n\n' +
    t('academy.cost_label', { cost: CLASS_CHANGE_COST }) + '\n' +
    t('class_change.warning_parenthetical'),
    function() {
      _gold -= CLASS_CHANGE_COST;
      saveGold(_gold);
      updateGoldUI();
      changeClass(uid, newCls);
      renderAcademy();
      setTimeout(function() {
        var updCh = getChar(uid);
        var updCharName = updCh.customName || names[updCh.nameId] || '???';
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

// ── 스킬북 탭: 렌더링 ───────────────────
function renderSkillBooks() {
  var list = document.getElementById('skillbook-list');
  var inv = loadInventory();
  list.innerHTML = '';

  if (!inv.length) {
    list.innerHTML = '<div style="color:var(--dim);font-size:12px;text-align:center;padding:20px">' + t('academy.no_skillbooks') + '</div>';
    return;
  }

  inv.forEach(function(book, idx) {
    var d = JAB[book.cls];
    if (!d) return;
    var skillName = t('skills.' + book.id);
    var clsName = t('classes.' + book.cls);

    // 사용 가능한 대상이 있는지 체크
    var roster = getRoster();
    var hasTarget = roster.chars.some(function(c) {
      return !c.dead && c.cls === book.cls && !c.cls.startsWith('summon_') && getCharSkillLv(c, book.id) < MAX_SKILL_LV;
    });

    var el = document.createElement('div');
    el.className = 'sb-card';
    el.innerHTML =
      '<div class="sb-icon">' + clsIcon(book.cls, 22) + '</div>' +
      '<div class="sb-info">' +
        '<div class="sb-name">' + skillName + ' <span class="sb-cls-tag">' + clsName + '</span></div>' +
        '<div class="sb-meta">Lv.1 Skill Book</div>' +
      '</div>' +
      '<button class="sb-btn' + (hasTarget ? '' : ' disabled') + '" ' + (hasTarget ? '' : 'disabled') + '>' + t('academy.skillbook_use') + '</button>';

    if (hasTarget) {
      el.querySelector('.sb-btn').onclick = (function(i) {
        return function() { showSkillBookTargets(i); };
      })(idx);
    }
    list.appendChild(el);
  });
}

// ── 스킬북: 대상 선택 모달 ──────────────
function showSkillBookTargets(idx) {
  var inv = loadInventory();
  var book = inv[idx];
  if (!book) return;

  var roster = getRoster();
  var names = t('character.names');
  var skillName = t('skills.' + book.id);

  // 같은 클래스 + 살아있는 + 해당 스킬 Lv < MAX_SKILL_LV
  var targets = roster.chars.filter(function(c) {
    return !c.dead && c.cls === book.cls && !c.cls.startsWith('summon_') && getCharSkillLv(c, book.id) < MAX_SKILL_LV;
  });

  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = t('academy.skillbook_select_target');
  document.getElementById('modal-title').className = '';

  if (!targets.length) {
    document.getElementById('modal-sub').innerHTML =
      '<div style="color:var(--dim);font-size:12px;text-align:center;padding:20px">' + t('academy.skillbook_no_target') + '</div>';
    var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
    var cb = document.createElement('button');
    cb.className = 'modal-btn secondary';
    cb.textContent = t('common.close');
    cb.onclick = function() { ov.classList.remove('show'); };
    bt.appendChild(cb);
    ov.classList.add('show');
    return;
  }

  var h = '<div style="text-align:center;margin-bottom:8px">' +
    skillIcon(book.id, 20) + ' <b>' + skillName + '</b> Lv.1' +
    '</div>' +
    '<div class="sb-target-list">';

  targets.forEach(function(ch) {
    var d = JAB[ch.cls];
    var charName = ch.customName || names[ch.nameId] || d.icon;
    var curLv = getCharSkillLv(ch, book.id);
    var lvText = curLv === 0
      ? '<span style="color:#4ade80">NEW \u2192 Lv.1</span>'
      : skillName + ' Lv.' + curLv + ' \u2192 ' + (curLv + 1);
    var lvBadge = curLv === 0 ? 'NEW' : 'Lv.' + curLv;
    h += '<div class="sb-target-btn" data-uid="' + ch.uid + '">' +
      clsIcon(ch.cls, 22) +
      '<div class="sb-target-info">' +
        '<div>' + charName + ' <span style="color:#64748b;font-size:10px">Lv.' + ch.lv + '</span></div>' +
        '<div style="color:var(--dim);font-size:9px">' + lvText + '</div>' +
      '</div>' +
      '<span class="sb-target-lv">' + lvBadge + '</span>' +
    '</div>';
  });
  h += '</div>';

  document.getElementById('modal-sub').innerHTML = h;
  var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
  var cb = document.createElement('button');
  cb.className = 'modal-btn secondary';
  cb.textContent = t('common.cancel');
  cb.onclick = function() { ov.classList.remove('show'); };
  bt.appendChild(cb);
  ov.classList.add('show');

  document.querySelectorAll('.sb-target-btn').forEach(function(btn) {
    btn.onclick = function() {
      var uid = parseInt(btn.dataset.uid);
      ov.classList.remove('show');
      useSkillBook(idx, uid);
    };
  });
}

// ── 스킬북: 사용 확인 모달 ──────────────
function useSkillBook(idx, uid) {
  var inv = loadInventory();
  var book = inv[idx];
  if (!book) return;

  var ch = getChar(uid);
  if (!ch) return;

  var names = t('character.names');
  var d = JAB[ch.cls];
  var charName = ch.customName || names[ch.nameId] || d.icon;
  var skillName = t('skills.' + book.id);
  var curLv = getCharSkillLv(ch, book.id);
  var newLv = curLv + 1;

  var msg = d.icon + ' ' + charName + '\n\n' +
    (curLv === 0
      ? t('academy.skillbook_learn_confirm', { skill: skillName, name: charName })
      : t('academy.skillbook_confirm', { skill: skillName, name: charName }) + '\n' +
        t('academy.skillbook_preview', { from: curLv, to: newLv }));

  showConfirm(msg, function() {
    executeUseSkillBook(idx, uid);
  });
}

// ── 스킬북: 실행 ────────────────────────
function executeUseSkillBook(idx, uid) {
  var inv = loadInventory();
  var book = inv[idx];
  if (!book) return;

  var roster = getRoster();
  var ch = roster.chars.find(function(c) { return c.uid === uid; });
  if (!ch) return;

  var skillName = t('skills.' + book.id);
  if (!ch.skillLv) ch.skillLv = {};
  var isLearnable = typeof LEARNABLE_SKILLS !== 'undefined' && LEARNABLE_SKILLS[book.id];
  var isNewLearn = isLearnable && !ch.skillLv[book.id];
  if (!ch.skillLv[book.id]) ch.skillLv[book.id] = isLearnable ? 0 : 1;
  ch.skillLv[book.id]++;
  var newLv = ch.skillLv[book.id];

  // 인벤토리에서 해당 스킬북 제거
  inv.splice(idx, 1);

  saveRoster(roster);
  saveInventory(inv);
  renderSkillBooks();

  var names = t('character.names');
  var d = JAB[ch.cls];
  var charName = ch.customName || names[ch.nameId] || d.icon;

  setTimeout(function() {
    var msg = isNewLearn
      ? d.icon + ' ' + t('academy.skillbook_learn_success', { name: charName, skill: skillName })
      : d.icon + ' ' + t('academy.skillbook_success', { name: charName, skill: skillName, lv: newLv });
    showAlert(msg);
  }, 100);
}

// ── 초기화 ───────────────────────────────
var init = async function() {
  await i18nInit();
  _gold = loadGold();
  updateGoldUI();
  switchTab('classchange');
  renderBottomNav();
  setTimeout(function() { document.getElementById('splash').style.display = 'none'; }, 300);
};
