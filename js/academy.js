// academy.js — 아카데미 페이지 전용 스크립트
// 공통 모듈에서 공유 함수 로드 (MAX_SKILL_LV는 constants.js에서 로드)

var _currentTab = 'classchange';

// ── 골드 관리 ─────────────────────────────
var _gold = 0;

function updateGoldUI() {
  updatePageGold('acad-gold-val');
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
  toggleTabButtons(tab);
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
function getScrollsFromInventory() {
  var inv = loadInventory();
  var scrolls = [];
  for (var i = 0; i < inv.length; i++) {
    if (inv[i].type === 'scroll') scrolls.push({ idx: i, item: inv[i] });
  }
  return scrolls;
}

function renderAcademy() {
  var list = document.getElementById('academy-list');
  var roster = getRoster();
  var novices = roster.chars.filter(function(c) { return !c.dead && c.cls === 'novice' && !c.cls.startsWith('summon_'); });
  list.innerHTML = '';

  if (!novices.length) {
    list.innerHTML = '<div style="color:var(--dim);font-size:12px;text-align:center;padding:20px">' + t('academy.no_novice') + '</div>';
    return;
  }

  var scrolls = getScrollsFromInventory();
  var hasScroll = scrolls.length > 0;
  var names = t('character.names');

  novices.forEach(function(ch) {
    var d = JAB[ch.cls];
    var grade = potGrade(ch);
    var gClr = grade === 'S' ? '#f0c040' : grade === 'A' ? '#60a5fa' : grade === 'B' ? '#4ade80' : '#9ca3af';
    var charName = ch.customName || names[ch.nameId] || d.icon;
    var el = document.createElement('div');
    el.className = 'game-card';
    var btnText = hasScroll ? t('academy.class_change_btn') : t('academy.class_change_btn_noscroll');
    var potStr = (ch.pot && ch.pot.hp) ? '+' + ch.pot.hp + '/+' + ch.pot.atk + '/+' + ch.pot.def + (ch.pot.actionRec ? '/+' + ch.pot.actionRec.toFixed(2) : '') : '−';
    var arStr = (ch.pot && ch.pot.actionRec) ? '+' + ch.pot.actionRec.toFixed(2) : '−';
    el.innerHTML =
      '<div class="game-card-icon">' + clsIcon(ch.cls, 28) + '</div>' +
      '<div class="game-card-info">' +
        '<div class="game-card-name">' + charName + ' <span style="color:#64748b;font-size:10px">Lv.' + ch.lv + '</span> <span style="color:' + gClr + ';font-size:10px;font-weight:900">' + grade + '</span></div>' +
        '<div class="game-card-sub">HP ' + ch.hp + ' · ATK ' + ch.atk + ' · DEF ' + ch.def + ' · AR ' + arStr + '</div>' +
        '<div class="game-card-pot" style="font-size:9px;color:#a78bfa;margin-top:3px">잠재력: <b>' + potStr + '</b> <span style="color:#64748b;font-size:8px">(HP/ATK/DEF/AR)</span></div>' +
      '</div>' +
      '<button class="game-btn game-btn--purple' + (hasScroll ? '' : ' disabled') + '" ' + (hasScroll ? '' : 'disabled') + '>' + btnText + '</button>';
    el.querySelector('.game-btn').onclick = (function(uid) {
      return function() {
        showScrollSelectModal(uid);
      };
    })(ch.uid);
    list.appendChild(el);
  });
}

// ── 전직 모달: 전직서 선택 (전직서 = 직업) ───
function showScrollSelectModal(uid) {
  var ch = getChar(uid);
  if (!ch) return;
  var scrolls = getScrollsFromInventory();

  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = t('academy.select_scroll');
  document.getElementById('modal-title').className = '';

  if (!scrolls.length) {
    document.getElementById('modal-sub').innerHTML =
      '<div style="color:var(--dim);font-size:12px;text-align:center;padding:20px">' + t('academy.no_scroll') + '</div>';
    var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
    var cb = document.createElement('button');
    cb.className = 'modal-btn secondary';
    cb.textContent = t('common.close');
    cb.onclick = function() { ov.classList.remove('show'); };
    bt.appendChild(cb);
    ov.classList.add('show');
    return;
  }

  var names = t('character.names');
  var charName = ch.customName || names[ch.nameId] || '???';
  var h = clsIcon(ch.cls, 24) + ' <b>' + charName + '</b> (Lv.' + ch.lv + ')<br>' +
    '<span style="color:var(--dim);font-size:10px">' + t('class_change.warning_irreversible') + '</span><br><br>';
  h += '<div class="scroll-select-list">';
  scrolls.forEach(function(s) {
    var cls = s.item.scrollCls;
    var d = JAB[cls];
    if (!d) return;
    h += '<div class="scroll-select-btn" data-idx="' + s.idx + '" data-cls="' + cls + '">' +
      '<span class="scroll-select-icon">' + clsIcon(cls, 28) + '</span>' +
      '<div class="scroll-select-info">' +
        '<div class="scroll-select-name">' + t('shop.scroll_prefix') + ' ' + t('classes.' + cls) + '</div>' +
        '<div class="scroll-select-desc">' + t('class_desc.' + cls) + '</div>' +
      '</div>' +
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

  document.querySelectorAll('.scroll-select-btn').forEach(function(btn) {
    btn.onclick = function() {
      var idx = parseInt(btn.dataset.idx);
      var cls = btn.dataset.cls;
      ov.classList.remove('show');
      confirmClassChange(uid, cls, idx);
    };
  });
}

// ── 전직 모달: 최종 확인 ─────────────────
function confirmClassChange(uid, newCls, scrollIdx) {
  var ch = getChar(uid);
  if (!ch) return;
  var oldD = JAB[ch.cls];
  var newD = JAB[newCls];
  var grade = potGrade(ch);
  var preview = previewClassChange(ch, newCls);
  var names = t('character.names');
  var charName = ch.customName || names[ch.nameId] || '???';
  var origClass = ch.cls;

  var scrollName = t('shop.scroll_prefix') + ' ' + t('classes.' + newCls);

  showConfirm(
    oldD.icon + ' ' + charName + ' (Lv.' + ch.lv + ' ' + grade + t('class_change.grade_suffix') + ')\n' +
    t('classes.' + ch.cls) + ' \u2192 ' + newD.icon + ' ' + t('classes.' + newCls) + '\n\n' +
    t('class_change.stats_preview') + '\n' +
    'HP ' + preview.hp + ' / ATK ' + preview.atk + ' / DEF ' + preview.def + '\n' +
    'MOV ' + preview.move + ' / RNG ' + preview.range + '\n\n' +
    scrollName + '\n' +
    t('class_change.warning_parenthetical'),
    function() {
      // 전직서 소비
      var inv2 = loadInventory();
      inv2.splice(scrollIdx, 1);
      saveInventory(inv2);

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

  var hasBooks = false;
  inv.forEach(function(book, idx) {
    // 스킬북만 필터 (type 없고 id+cls+lv 있는 항목)
    if (book.type || !book.id || !book.cls || book.lv === undefined) return;
    var d = JAB[book.cls];
    if (!d) return;
    hasBooks = true;
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
      '<button class="game-btn game-btn--blue' + (hasTarget ? '' : ' disabled') + '" ' + (hasTarget ? '' : 'disabled') + '>' + t('academy.skillbook_use') + '</button>';

    if (hasTarget) {
      el.querySelector('.game-btn').onclick = (function(i) {
        return function() { showSkillBookTargets(i); };
      })(idx);
    }
    list.appendChild(el);
  });
  if (!hasBooks) {
    list.innerHTML = '<div style="color:var(--dim);font-size:12px;text-align:center;padding:20px">' + t('academy.no_skillbooks') + '</div>';
  }
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
  hideSplash();
};
