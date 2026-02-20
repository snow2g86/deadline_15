// sanctuary.js — 성소 페이지 전용 스크립트
// 공통 모듈에서 공유 함수 로드 (MAX_SKILL_LV, GRADE_ORDER, GRADE_COLORS는 constants.js에서 로드)

var _currentTab = 'resurrect';

// ── 골드 관리 ─────────────────────────────
var _gold = 0;

function updateGoldUI() {
  updatePageGold('sanc-gold-val');
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

// ── 등급 유틸 ────────────────────────────
var REQUIRED_POINTS = 4;

function nextGrade(grade) {
  var i = GRADE_ORDER.indexOf(grade);
  return i < GRADE_ORDER.length - 1 ? GRADE_ORDER[i + 1] : null;
}

// gradeMultiplier: common/character.js에서 로드

// 제물 포인트 계산: 윗등급=4, 같은등급=2, 한단계아래=1
function sacrificePoints(sacGrade, targetGrade) {
  var si = GRADE_ORDER.indexOf(sacGrade);
  var ti = GRADE_ORDER.indexOf(targetGrade);
  if (si > ti) return 4;  // 윗등급
  if (si === ti) return 2; // 같은등급
  if (si === ti - 1) return 1; // 한단계 아래
  return 0; // 2단계+ 아래 — 불가
}


// getCharSkills: common/character.js에서 로드

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
  toggleTabButtons(tab);
  var sub = document.getElementById('sanc-subtitle');
  if (sub) {
    if (tab === 'resurrect') sub.textContent = t('sanctuary.subtitle');
    else if (tab === 'promote') sub.textContent = t('sanctuary.promote_subtitle');
    else if (tab === 'rename') sub.textContent = t('sanctuary.rename_subtitle');
  }
  if (tab === 'resurrect') renderResurrect();
  else if (tab === 'promote') renderPromote();
  else if (tab === 'rename') renderRename();
}

// ── 부활 비용 ────────────────────────────
function reviveCost(ch) { return 20 + ch.lv * 10; }

// ── 광고 부활 ────────────────────────────
var SANC_AD_KEY = 'game_sanc_ad_cooldown';
var SANC_AD_COOLDOWN_MS = 30 * 60 * 1000;

function getSancAdCooldown() {
  try { var v = +localStorage.getItem(SANC_AD_KEY); return v || 0; } catch(_) { return 0; }
}

function setSancAdCooldown() {
  try { localStorage.setItem(SANC_AD_KEY, Date.now()); } catch(_) {}
}

// ── 부활 렌더링 ─────────────────────────
function renderResurrect() {
  var list = document.getElementById('sanc-list');
  var roster = getRoster();
  var dead = roster.chars.filter(function(c) { return c.dead && !c.cls.startsWith('summon_'); });
  dead.sort(function(a, b) { return (b.diedAt || 0) - (a.diedAt || 0); });
  list.innerHTML = '';

  if (!dead.length) {
    list.innerHTML = '<div style="color:var(--dim);font-size:12px;text-align:center;padding:20px">' + t('sanctuary.no_dead_units') + '</div>';
    return;
  }

  // 광고 무료 부활 카드
  var adRemain = Math.max(0, SANC_AD_COOLDOWN_MS - (Date.now() - getSancAdCooldown()));
  var adReady = adRemain <= 0;
  var adCard = document.createElement('div');
  adCard.className = 'sanc-ad-card';
  var adBtnText = adReady ? t('sanctuary.ad_btn') : t('sanctuary.ad_cooldown', { minutes: Math.ceil(adRemain / 60000) });
  adCard.innerHTML =
    '<div class="sanc-ad-icon">&#127916;</div>' +
    '<div class="sanc-ad-info">' +
      '<div class="sanc-ad-title">' + t('sanctuary.ad_title') + '</div>' +
      '<div class="sanc-ad-desc">' + t('sanctuary.ad_desc') + '</div>' +
    '</div>' +
    '<button class="sanc-ad-btn' + (adReady ? '' : ' disabled') + '" ' + (adReady ? '' : 'disabled') + '>' + adBtnText + '</button>';
  if (adReady) {
    adCard.querySelector('.sanc-ad-btn').onclick = function() { showAdReviveModal(dead); };
  }
  list.appendChild(adCard);

  var names = t('character.names');

  dead.forEach(function(ch) {
    var d = JAB[ch.cls];
    var cost = reviveCost(ch);
    var canAfford = _gold >= cost;
    var el = document.createElement('div');
    el.className = 'game-card';
    var charName = ch.customName || names[ch.nameId] || d.icon;
    el.innerHTML =
      '<div class="game-card-icon">' + clsIcon(ch.cls, 28) + '</div>' +
      '<div class="game-card-info"><div class="game-card-name">' + charName + ' <span style="color:#64748b;font-size:10px">Lv.' + ch.lv + '</span></div>' +
      '<div class="game-card-sub">HP ' + ch.hp + ' · ATK ' + ch.atk + ' · DEF ' + ch.def + ' · AR ' + (ch.actionRec ? ch.actionRec.toFixed(2) : '−') + '</div></div>' +
      '<button class="game-btn game-btn--purple' + (canAfford ? '' : ' disabled') + '" ' + (canAfford ? '' : 'disabled') + '>' + t('sanctuary.resurrect_button', { cost: cost }) + '</button>';
    el.querySelector('.game-btn').onclick = (function(uid, cost) {
      return function() {
        if (_gold < cost) return;
        _gold -= cost;
        saveGold(_gold);
        updateGoldUI();
        var roster = getRoster();
        var ch = roster.chars.find(function(c) { return c.uid === uid; });
        if (ch) { ch.dead = false; delete ch.diedAt; saveRoster(roster); }
        renderResurrect();
      };
    })(ch.uid, cost);
    list.appendChild(el);
  });
}

// ── 광고 부활 모달 ──────────────────────
function showAdReviveModal(dead) {
  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = t('sanctuary.ad_select');
  document.getElementById('modal-title').className = '';
  var names = t('character.names');
  var h = '<div class="potion-target-list">';
  dead.forEach(function(ch) {
    var d = JAB[ch.cls];
    var charName = ch.customName || names[ch.nameId] || d.icon;
    h += '<div class="pt-btn" data-uid="' + ch.uid + '">' +
      '<span class="pt-icon">' + clsIcon(ch.cls, 20) + '</span>' +
      '<span class="pt-info">' + charName + ' Lv.' + ch.lv + '</span>' +
      '<span class="pt-exp">HP ' + ch.hp + '</span>' +
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
  document.querySelectorAll('.pt-btn').forEach(function(b) {
    b.onclick = function() {
      var uid = +b.dataset.uid;
      setSancAdCooldown();
      var roster = getRoster();
      var ch = roster.chars.find(function(c) { return c.uid === uid; });
      if (ch) { ch.dead = false; delete ch.diedAt; saveRoster(roster); }
      ov.classList.remove('show');
      renderResurrect();
      var d = JAB[ch.cls];
      var charName = ch.customName || names[ch.nameId] || d.icon;
      setTimeout(function() {
        showAlert(t('sanctuary.ad_success', { name: charName }));
      }, 100);
    };
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
    var potStr = (ch.pot && ch.pot.hp) ? '+' + ch.pot.hp + '/+' + ch.pot.atk + '/+' + ch.pot.def + (ch.pot.actionRec ? '/+' + ch.pot.actionRec.toFixed(2) : '') : '−';

    var el = document.createElement('div');
    el.className = 'promote-card';
    el.innerHTML =
      '<div class="game-card-icon">' + clsIcon(ch.cls, 28) + '</div>' +
      '<div class="game-card-info">' +
        '<div class="game-card-name">' + charName +
          ' <span style="color:#64748b;font-size:10px">Lv.' + ch.lv + '</span>' +
          ' <span class="promote-grade" style="color:' + gClr + '">' + grade + '</span>' +
        '</div>' +
        '<div class="game-card-sub">HP ' + ch.hp + ' · ATK ' + ch.atk + ' · DEF ' + ch.def + ' · AR ' + ((ch.actionRec || JAB[ch.cls].actionRec || 1.0)).toFixed(2) + '</div>' +
        '<div class="game-card-pot" style="font-size:9px;color:#a78bfa;margin-top:3px">잠재력: <b>' + potStr + '</b> <span style="color:#64748b;font-size:8px">(HP/ATK/DEF/AR)</span></div>' +
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
    clsIcon(target.cls, 24) + ' <b>' + targetName + '</b> (Lv.' + target.lv +
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
      clsIcon(ch.cls, 22) +
      '<div class="sac-info">' +
        '<div>' + charName + ' <span style="color:#64748b;font-size:10px">Lv.' + ch.lv + '</span>' +
        ' <span style="color:' + gClr + ';font-weight:900;font-size:10px">' + grade + '</span></div>' +
        '<div style="color:var(--dim);font-size:9px">HP ' + ch.hp + ' \xb7 ATK ' + ch.atk + ' \xb7 DEF ' + ch.def + '</div>' +
      '</div>' +
      '<span class="sac-pts-badge">+' + pts + 'pt</span>' +
    '</div>';
  });
  h += '</div>';

  h += '<div id="sac-status-msg" style="text-align:center;font-size:11px;color:var(--dim);margin-top:8px;margin-bottom:4px;min-height:14px">' +
    (t('sanctuary.sacrifice_select_more') || 'Select more sacrifices') +
    '</div>';

  document.getElementById('modal-sub').innerHTML = h;

  var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
  var confirmBtn = document.createElement('button');
  confirmBtn.className = 'modal-btn primary disabled';
  confirmBtn.id = 'sac-confirm-btn';
  confirmBtn.textContent = t('sanctuary.promote_btn');
  confirmBtn.disabled = true;
  confirmBtn.type = 'button';
  confirmBtn.title = t('sanctuary.promote_btn_help') || 'require ' + REQUIRED_POINTS + ' points';
  confirmBtn.onclick = function(e) {
    e.preventDefault();
    e.stopPropagation();
    if (_sacSelected.length === 0) {
      console.warn('[Sanctuary] _sacSelected is empty, confirm button should be disabled');
      return;
    }
    ov.classList.remove('show');
    confirmPromote(_sacTargetUid, _sacSelected);
  };
  var cb = document.createElement('button');
  cb.className = 'modal-btn secondary';
  cb.type = 'button';
  cb.textContent = t('common.cancel');
  cb.onclick = function(e) {
    e.preventDefault();
    e.stopPropagation();
    ov.classList.remove('show');
  };
  bt.appendChild(cb);
  bt.appendChild(confirmBtn);
  ov.classList.add('show');

  // 클릭 이벤트 바인딩
  document.querySelectorAll('#sac-list-inner .sac-btn').forEach(function(btn) {
    btn.onclick = function(e) {
      e.stopPropagation();
      var uidStr = btn.getAttribute('data-uid');
      if (!uidStr) return;
      var uid = parseInt(uidStr, 10);
      if (isNaN(uid)) return;

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
  var statusMsg = document.getElementById('sac-status-msg');

  if (fill) fill.style.width = pct + '%';
  if (txt) txt.textContent = totalPts + ' / ' + REQUIRED_POINTS + ' pt';

  if (totalPts >= REQUIRED_POINTS) {
    if (fill) fill.style.background = 'linear-gradient(90deg,#a855f7,#c084fc)';
    if (btn) { btn.disabled = false; btn.classList.remove('disabled'); }
    if (statusMsg) statusMsg.textContent = '';  // 준비 완료 시 메시지 제거
  } else {
    if (fill) fill.style.background = 'linear-gradient(90deg,#6b21a8,#7c3aed)';
    if (btn) { btn.disabled = true; btn.classList.add('disabled'); }
    var needed = REQUIRED_POINTS - totalPts;
    if (statusMsg) {
      statusMsg.textContent = (needed > 0 ? '⚠️ ' : '') + needed + ' ' + (t('sanctuary.more_points') || 'more points needed');
    }
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

// ── 개명 렌더링 ─────────────────────────
function renderRename() {
  var list = document.getElementById('sanc-list');
  var roster = getRoster();
  var names = t('character.names');
  var candidates = roster.chars.filter(function(c) {
    return !c.dead && !c.cls.startsWith('summon_');
  });
  list.innerHTML = '';

  if (!candidates.length) {
    list.innerHTML = '<div style="color:var(--dim);font-size:12px;text-align:center;padding:20px">' + t('sanctuary.no_rename_units') + '</div>';
    return;
  }

  candidates.forEach(function(ch) {
    var d = JAB[ch.cls];
    var charName = ch.customName || names[ch.nameId] || d.icon;

    var el = document.createElement('div');
    el.className = 'game-card';
    el.innerHTML =
      '<div class="game-card-icon">' + clsIcon(ch.cls, 28) + '</div>' +
      '<div class="game-card-info"><div class="game-card-name">' + charName + ' <span style="color:#64748b;font-size:10px">Lv.' + ch.lv + '</span></div>' +
      '<div class="game-card-sub">HP ' + ch.hp + ' · ATK ' + ch.atk + ' · DEF ' + ch.def + ' · AR ' + (ch.actionRec ? ch.actionRec.toFixed(2) : '−') + '</div></div>' +
      '<button class="game-btn game-btn--blue">' + t('sanctuary.rename_button') + '</button>';
    el.querySelector('.game-btn').onclick = (function(uid) {
      return function() {
        showRenameModal(uid);
      };
    })(ch.uid);
    list.appendChild(el);
  });
}

// ── 개명 모달 표시 ─────────────────────
function showRenameModal(uid) {
  var roster = getRoster();
  var ch = roster.chars.find(function(c) { return c.uid === uid; });
  if (!ch) return;

  var d = JAB[ch.cls];
  var names = t('character.names');
  var currentName = ch.customName || names[ch.nameId] || d.icon;

  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = t('sanctuary.rename_title');
  document.getElementById('modal-title').className = '';

  document.getElementById('modal-sub').innerHTML =
    '<div class="rename-char-info">' +
      clsIcon(ch.cls, 24) + ' <span>' + currentName + ' (Lv.' + ch.lv + ')</span>' +
    '</div>' +
    '<input type="text" id="rename-input" class="rename-input" ' +
      'placeholder="' + currentName + '" maxlength="10" />';

  var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';

  var confirmBtn = document.createElement('button');
  confirmBtn.className = 'modal-btn primary';
  confirmBtn.textContent = t('common.confirm');
  confirmBtn.onclick = function() {
    var newName = document.getElementById('rename-input').value.trim();
    ov.classList.remove('show');
    executeRename(uid, newName);
  };

  var cb = document.createElement('button');
  cb.className = 'modal-btn secondary';
  cb.textContent = t('common.cancel');
  cb.onclick = function() { ov.classList.remove('show'); };

  bt.appendChild(cb);
  bt.appendChild(confirmBtn);
  ov.classList.add('show');

  // 자동 포커스
  setTimeout(function() {
    var inp = document.getElementById('rename-input');
    if (inp) inp.focus();
  }, 100);
}

// ── 개명 실행 ────────────────────────────
function executeRename(uid, newName) {
  var roster = getRoster();
  var ch = roster.chars.find(function(c) { return c.uid === uid; });
  if (!ch) return;

  var d = JAB[ch.cls];
  var names = t('character.names');

  // 공백만 있는 이름 차단
  if (newName.length === 0) {
    delete ch.customName;
  } else {
    ch.customName = newName;
  }

  saveRoster(roster);
  renderRename();

  var displayName = ch.customName || names[ch.nameId] || d.icon;
  setTimeout(function() {
    showAlert(t('sanctuary.rename_success', { name: displayName }));
  }, 100);
}

// ── 기존 renderSanctuary 래퍼 ────────────
function renderSanctuary() {
  if (_currentTab === 'resurrect') renderResurrect();
  else if (_currentTab === 'promote') renderPromote();
  else if (_currentTab === 'rename') renderRename();
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
