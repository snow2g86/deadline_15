// sanctuary.js — 성소 페이지 전용 스크립트
// G/ROSTER/CD 의존 없이 JAB + localStorage 직접 조작

var SAVE_KEY = 'game_save';
var ROSTER_KEY = 'game_roster';
var PARTY_KEY = 'game_party';
var INVENTORY_KEY = 'game_inventory';
var MAX_SKILL_LV = 10;
var _currentTab = 'resurrect';

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

// ── 파티 체크 ────────────────────────────
function getParty() {
  try {
    var raw = localStorage.getItem(PARTY_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}
  return [];
}

function isInParty(uid) {
  var party = getParty();
  return party.indexOf(uid) !== -1;
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

// ── 등급 유틸 ────────────────────────────
var GRADE_ORDER = ['C', 'B', 'A', 'S'];
var GRADE_COLORS = { S: '#f0c040', A: '#60a5fa', B: '#4ade80', C: '#9ca3af' };
var REQUIRED_POINTS = 4;

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

function nextGrade(grade) {
  var i = GRADE_ORDER.indexOf(grade);
  return i < GRADE_ORDER.length - 1 ? GRADE_ORDER[i + 1] : null;
}

function gradeMultiplier(grade) {
  return grade === 'S' ? 1.1 : grade === 'A' ? 1.0 : grade === 'B' ? 0.9 : 0.8;
}

// 제물 포인트 계산: 윗등급=4, 같은등급=2, 한단계아래=1
function sacrificePoints(sacGrade, targetGrade) {
  var si = GRADE_ORDER.indexOf(sacGrade);
  var ti = GRADE_ORDER.indexOf(targetGrade);
  if (si > ti) return 4;  // 윗등급
  if (si === ti) return 2; // 같은등급
  if (si === ti - 1) return 1; // 한단계 아래
  return 0; // 2단계+ 아래 — 불가
}

// 스킬 레벨 헬퍼
function getCharSkillLv(ch, skillId) {
  if (ch.skillLv && ch.skillLv[skillId]) return ch.skillLv[skillId];
  return 1;
}

function getCharSkills(cls) {
  var sk = SKILLS[cls];
  if (!sk) return [];
  var arr = Array.isArray(sk) ? sk.slice() : [sk];
  if (typeof LEARNABLE_SKILLS !== 'undefined') {
    Object.keys(LEARNABLE_SKILLS).forEach(function(skId) {
      var lsk = LEARNABLE_SKILLS[skId];
      if (lsk.cls === cls) arr.push(lsk);
    });
  }
  return arr;
}

function formatSkillLvs(ch) {
  var skills = getCharSkills(ch.cls);
  if (!skills.length) return '';
  var parts = [];
  skills.forEach(function(sk) {
    var lv = getCharSkillLv(ch, sk.id);
    if (lv > 1) parts.push(t('skills.' + sk.id) + ' Lv.' + lv);
  });
  return parts.length ? parts.join(', ') : '';
}

// ── 탭 전환 ──────────────────────────────
function switchTab(tab) {
  _currentTab = tab;
  document.querySelectorAll('.sanc-tab-btn').forEach(function(btn) {
    btn.classList.toggle('active', btn.dataset.tab === tab);
  });
  var sub = document.getElementById('sanc-subtitle');
  if (sub) {
    sub.textContent = tab === 'resurrect' ? t('sanctuary.subtitle') : t('sanctuary.promote_subtitle');
  }
  if (tab === 'resurrect') renderResurrect();
  else renderPromote();
}

// ── 부활 비용 ────────────────────────────
function reviveCost(ch) { return 20 + ch.lv * 10; }

// ── 부활 렌더링 ─────────────────────────
function renderResurrect() {
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
    var charName = ch.customName || names[ch.nameId] || d.icon;
    el.innerHTML =
      '<div class="sanc-icon">' + charSprite(ch.cls, 28, ch.gender) + '</div>' +
      '<div class="sanc-info"><div class="sanc-name">' + charName + ' <span style="color:#64748b;font-size:10px">Lv.' + ch.lv + '</span></div>' +
      '<div class="sanc-stats">HP ' + ch.hp + ' \xb7 ATK ' + ch.atk + ' \xb7 DEF ' + ch.def + '</div></div>' +
      '<button class="sanc-btn' + (canAfford ? '' : ' disabled') + '" ' + (canAfford ? '' : 'disabled') + '>' + t('sanctuary.resurrect_button', { cost: cost }) + '</button>';
    el.querySelector('.sanc-btn').onclick = (function(uid, cost) {
      return function() {
        if (_gold < cost) return;
        _gold -= cost;
        saveGold(_gold);
        updateGoldUI();
        var roster = getRoster();
        var ch = roster.chars.find(function(c) { return c.uid === uid; });
        if (ch) { ch.dead = false; saveRoster(roster); }
        renderResurrect();
      };
    })(ch.uid, cost);
    list.appendChild(el);
  });
}

// ── 승급 렌더링 ─────────────────────────
function renderPromote() {
  var list = document.getElementById('sanc-list');
  var roster = getRoster();
  var names = t('character.names');
  var candidates = roster.chars.filter(function(c) {
    return !c.dead && !c.cls.startsWith('summon_');
  });
  list.innerHTML = '';

  var promotable = candidates.filter(function(c) {
    return potGrade(c) !== 'S';
  });

  if (!promotable.length) {
    list.innerHTML = '<div style="color:var(--dim);font-size:12px;text-align:center;padding:20px">' + t('sanctuary.no_promotable') + '</div>';
    return;
  }

  promotable.forEach(function(ch) {
    var d = JAB[ch.cls];
    var grade = potGrade(ch);
    var gClr = GRADE_COLORS[grade];
    var charName = ch.customName || names[ch.nameId] || d.icon;

    // 제물 가능한 후보: 같은 클래스, 자신 제외, 파티 미편성, 포인트 > 0
    var sacrifices = candidates.filter(function(c) {
      return c.uid !== ch.uid && c.cls === ch.cls && !isInParty(c.uid) &&
        sacrificePoints(potGrade(c), grade) > 0;
    });

    var hasSacrifice = sacrifices.length > 0;
    var skillInfo = formatSkillLvs(ch);

    var el = document.createElement('div');
    el.className = 'promote-card';
    el.innerHTML =
      '<div class="sanc-icon">' + charSprite(ch.cls, 28, ch.gender) + '</div>' +
      '<div class="sanc-info">' +
        '<div class="sanc-name">' + charName +
          ' <span style="color:#64748b;font-size:10px">Lv.' + ch.lv + '</span>' +
          ' <span class="promote-grade" style="color:' + gClr + '">' + grade + '</span>' +
        '</div>' +
        '<div class="sanc-stats">HP ' + ch.hp + ' \xb7 ATK ' + ch.atk + ' \xb7 DEF ' + ch.def + '</div>' +
        (skillInfo ? '<div class="sanc-skill-info">' + skillInfo + '</div>' : '') +
      '</div>' +
      '<button class="promote-btn' + (hasSacrifice ? '' : ' disabled') + '" ' + (hasSacrifice ? '' : 'disabled') + '>' +
        t('sanctuary.promote_btn') +
      '</button>';

    if (hasSacrifice) {
      el.querySelector('.promote-btn').onclick = (function(uid) {
        return function() { showSacrificeModal(uid); };
      })(ch.uid);
    }
    list.appendChild(el);
  });
}

// ── 제물 선택 모달 (다중 선택) ───────────
var _sacSelected = []; // 선택된 제물 uid 배열
var _sacTargetUid = 0;

function showSacrificeModal(targetUid) {
  var roster = getRoster();
  var target = roster.chars.find(function(c) { return c.uid === targetUid; });
  if (!target) return;

  _sacTargetUid = targetUid;
  _sacSelected = [];

  var targetGrade = potGrade(target);
  var names = t('character.names');
  var candidates = roster.chars.filter(function(c) {
    return !c.dead && !c.cls.startsWith('summon_');
  });
  var sacrifices = candidates.filter(function(c) {
    return c.uid !== targetUid && c.cls === target.cls && !isInParty(c.uid) &&
      sacrificePoints(potGrade(c), targetGrade) > 0;
  });

  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = t('sanctuary.promote_select_sacrifice');
  document.getElementById('modal-title').className = '';

  var td = JAB[target.cls];
  var targetName = target.customName || names[target.nameId] || td.icon;

  // 모달 내용 빌드
  var h = '<div class="sac-target-info">' +
    charSprite(target.cls, 24, target.gender) + ' <b>' + targetName + '</b> (Lv.' + target.lv +
    ' <span style="color:' + GRADE_COLORS[targetGrade] + '">' + targetGrade + '</span>)' +
    '</div>' +
    '<div class="sac-progress" id="sac-progress">' +
      '<div class="sac-progress-bar"><div class="sac-progress-fill" id="sac-fill" style="width:0%"></div></div>' +
      '<div class="sac-progress-text" id="sac-pts-text">0 / ' + REQUIRED_POINTS + ' pt</div>' +
    '</div>' +
    '<div class="sacrifice-list" id="sac-list-inner">';

  sacrifices.forEach(function(ch) {
    var d = JAB[ch.cls];
    var grade = potGrade(ch);
    var gClr = GRADE_COLORS[grade];
    var pts = sacrificePoints(grade, targetGrade);
    var charName = ch.customName || names[ch.nameId] || d.icon;
    h += '<div class="sac-btn" data-uid="' + ch.uid + '" data-pts="' + pts + '">' +
      '<div class="sac-check" id="sac-chk-' + ch.uid + '"></div>' +
      charSprite(ch.cls, 22, ch.gender) +
      '<div class="sac-info">' +
        '<div>' + charName + ' <span style="color:#64748b;font-size:10px">Lv.' + ch.lv + '</span>' +
        ' <span style="color:' + gClr + ';font-weight:900;font-size:10px">' + grade + '</span></div>' +
        '<div style="color:var(--dim);font-size:9px">HP ' + ch.hp + ' \xb7 ATK ' + ch.atk + ' \xb7 DEF ' + ch.def + '</div>' +
      '</div>' +
      '<span class="sac-pts-badge">+' + pts + 'pt</span>' +
    '</div>';
  });
  h += '</div>';

  document.getElementById('modal-sub').innerHTML = h;

  var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
  var confirmBtn = document.createElement('button');
  confirmBtn.className = 'modal-btn primary disabled';
  confirmBtn.id = 'sac-confirm-btn';
  confirmBtn.textContent = t('sanctuary.promote_btn');
  confirmBtn.disabled = true;
  confirmBtn.onclick = function() {
    if (_sacSelected.length === 0) return;
    ov.classList.remove('show');
    confirmPromote(_sacTargetUid, _sacSelected);
  };
  var cb = document.createElement('button');
  cb.className = 'modal-btn secondary';
  cb.textContent = t('common.cancel');
  cb.onclick = function() { ov.classList.remove('show'); };
  bt.appendChild(cb);
  bt.appendChild(confirmBtn);
  ov.classList.add('show');

  // 클릭 이벤트 바인딩
  document.querySelectorAll('#sac-list-inner .sac-btn').forEach(function(btn) {
    btn.onclick = function() {
      var uid = parseInt(btn.dataset.uid);
      var idx = _sacSelected.indexOf(uid);
      if (idx !== -1) {
        _sacSelected.splice(idx, 1);
        btn.classList.remove('selected');
      } else {
        _sacSelected.push(uid);
        btn.classList.add('selected');
      }
      updateSacProgress(targetGrade, sacrifices);
    };
  });
}

function updateSacProgress(targetGrade, allSacrifices) {
  var totalPts = 0;
  _sacSelected.forEach(function(uid) {
    var ch = allSacrifices.find(function(c) { return c.uid === uid; });
    if (ch) totalPts += sacrificePoints(potGrade(ch), targetGrade);
  });

  var pct = Math.min(100, Math.round(totalPts / REQUIRED_POINTS * 100));
  var fill = document.getElementById('sac-fill');
  var txt = document.getElementById('sac-pts-text');
  var btn = document.getElementById('sac-confirm-btn');

  if (fill) fill.style.width = pct + '%';
  if (txt) txt.textContent = totalPts + ' / ' + REQUIRED_POINTS + ' pt';

  if (totalPts >= REQUIRED_POINTS) {
    if (fill) fill.style.background = 'linear-gradient(90deg,#a855f7,#c084fc)';
    if (btn) { btn.disabled = false; btn.classList.remove('disabled'); }
  } else {
    if (fill) fill.style.background = 'linear-gradient(90deg,#6b21a8,#7c3aed)';
    if (btn) { btn.disabled = true; btn.classList.add('disabled'); }
  }

  // 체크 표시 업데이트
  allSacrifices.forEach(function(ch) {
    var chk = document.getElementById('sac-chk-' + ch.uid);
    if (chk) chk.textContent = _sacSelected.indexOf(ch.uid) !== -1 ? '\u2713' : '';
  });
}

// ── 승급 확인 모달 ───────────────────────
function confirmPromote(targetUid, sacrificeUids) {
  var roster = getRoster();
  var target = roster.chars.find(function(c) { return c.uid === targetUid; });
  if (!target) return;

  var names = t('character.names');
  var d = JAB[target.cls];
  var curGrade = potGrade(target);
  var newGrade = nextGrade(curGrade);
  if (!newGrade) return;

  var targetName = target.customName || names[target.nameId] || d.icon;

  // 제물 이름 목록
  var sacNames = sacrificeUids.map(function(uid) {
    var ch = roster.chars.find(function(c) { return c.uid === uid; });
    if (!ch) return '???';
    return ch.customName || names[ch.nameId] || JAB[ch.cls].icon;
  });

  // 예상 스탯 미리보기
  var newPot = _rollPotentialWithGrade(target.cls, newGrade);
  var gm = gradeMultiplier(newGrade);
  var base = d.base;
  var lvGain = target.lv - 1;
  var previewHP = Math.round(base.hp * gm + newPot.hp * lvGain);
  var previewATK = Math.round(base.atk * gm + newPot.atk * lvGain);
  var previewDEF = Math.round(base.def * gm + newPot.def * lvGain);

  // 스킬 레벨 미리보기
  var skills = getCharSkills(target.cls);
  var skillPreview = '';
  var hasOverflow = false;
  if (skills.length) {
    var parts = [];
    skills.forEach(function(sk) {
      var curLv = getCharSkillLv(target, sk.id);
      var newLv = Math.min(curLv + sacrificeUids.length, MAX_SKILL_LV);
      if (curLv >= MAX_SKILL_LV) hasOverflow = true;
      parts.push(t('skills.' + sk.id) + ' Lv.' + curLv + '\u2192' + newLv);
    });
    skillPreview = '\n' + t('sanctuary.skill_inherit') + ': ' + parts.join(', ');
    if (hasOverflow) skillPreview += '\n' + t('sanctuary.skill_overflow');
  }

  var msg = d.icon + ' ' + targetName + ' (Lv.' + target.lv + ')\n' +
    curGrade + ' \u2192 ' + newGrade + '\n\n' +
    'HP ' + target.hp + ' \u2192 ~' + previewHP + '\n' +
    'ATK ' + target.atk + ' \u2192 ~' + previewATK + '\n' +
    'DEF ' + target.def + ' \u2192 ~' + previewDEF +
    skillPreview + '\n\n' +
    t('sanctuary.promote_confirm_multi', { count: sacrificeUids.length, target: targetName, from: curGrade, to: newGrade }) + '\n' +
    t('sanctuary.promote_warning');

  showConfirm(msg, function() {
    executePromote(targetUid, sacrificeUids);
  });
}

// ── 승급 실행 ────────────────────────────
function executePromote(targetUid, sacrificeUids) {
  var roster = getRoster();
  var target = roster.chars.find(function(c) { return c.uid === targetUid; });
  if (!target) return;

  var curGrade = potGrade(target);
  var newGrade = nextGrade(curGrade);
  if (!newGrade) return;

  // 스킬 계승: 각 제물의 스킬 레벨 +1 (최대 레벨이면 스킬북 생성)
  var skills = getCharSkills(target.cls);
  if (!target.skillLv) target.skillLv = {};
  var inv = loadInventory();
  var gainedBooks = [];
  sacrificeUids.forEach(function(sacUid) {
    var sacChar = roster.chars.find(function(c) { return c.uid === sacUid; });
    skills.forEach(function(sk) {
      var isLearnable = typeof LEARNABLE_SKILLS !== 'undefined' && LEARNABLE_SKILLS[sk.id];
      if (isLearnable) {
        // 습득형 스킬: 제물이 보유해야 흡수 가능
        var sacHas = sacChar && sacChar.skillLv && sacChar.skillLv[sk.id] >= 1;
        if (!sacHas) return;
        if (!target.skillLv[sk.id]) target.skillLv[sk.id] = 0;
        if (target.skillLv[sk.id] >= MAX_SKILL_LV) {
          // 대상 최대레벨 → 100% 스킬북 드랍
          inv.push({ id: sk.id, cls: target.cls, lv: 1 });
          gainedBooks.push(sk.id);
        } else {
          // 흡수: 대상 스킬 +1 (미습득이면 습득)
          target.skillLv[sk.id]++;
        }
        return;
      }
      if (!target.skillLv[sk.id]) target.skillLv[sk.id] = 1;
      if (target.skillLv[sk.id] >= MAX_SKILL_LV) {
        // 최대 레벨 → 스킬북 생성
        inv.push({ id: sk.id, cls: target.cls, lv: 1 });
        gainedBooks.push(sk.id);
      } else {
        target.skillLv[sk.id]++;
      }
    });
  });
  if (gainedBooks.length) saveInventory(inv);

  // 제물 삭제 (뒤에서부터 삭제하여 인덱스 안정성 보장)
  var sacSet = {};
  sacrificeUids.forEach(function(uid) { sacSet[uid] = true; });
  roster.chars = roster.chars.filter(function(c) { return !sacSet[c.uid]; });

  // 잠재력 재롤 + 스탯 재계산
  var d = JAB[target.cls];
  var newPot = _rollPotentialWithGrade(target.cls, newGrade);
  var gm = gradeMultiplier(newGrade);
  var lvGain = target.lv - 1;

  target.pot = newPot;
  target.hp = Math.round(d.base.hp * gm + newPot.hp * lvGain);
  target.atk = Math.round(d.base.atk * gm + newPot.atk * lvGain);
  target.def = Math.round(d.base.def * gm + newPot.def * lvGain);

  saveRoster(roster);
  renderPromote();

  var names = t('character.names');
  var targetName = target.customName || names[target.nameId] || d.icon;

  // 스킬 레벨 결과
  var skillResult = formatSkillLvs(target);

  // 스킬북 획득 메시지
  var bookMsg = '';
  if (gainedBooks.length) {
    var bookParts = gainedBooks.map(function(skId) {
      return t('sanctuary.skillbook_gained', { skill: t('skills.' + skId) });
    });
    bookMsg = '\n' + bookParts.join('\n');
  }

  setTimeout(function() {
    showAlert(
      d.icon + ' ' + targetName + '\n' +
      t('sanctuary.promote_success', { name: targetName, grade: newGrade }) + '\n\n' +
      'HP ' + target.hp + ' / ATK ' + target.atk + ' / DEF ' + target.def +
      (skillResult ? '\n' + skillResult : '') +
      bookMsg
    );
  }, 100);
}

// ── 기존 renderSanctuary 래퍼 ────────────
function renderSanctuary() {
  if (_currentTab === 'resurrect') renderResurrect();
  else renderPromote();
}

// ── 초기화 ───────────────────────────────
var init = async function() {
  await i18nInit();
  _gold = loadGold();
  updateGoldUI();
  switchTab('resurrect');
  renderBottomNav();
  setTimeout(function() { document.getElementById('splash').style.display = 'none'; }, 300);
};
