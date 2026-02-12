// stage-select.js — 스테이지 선택 페이지 전용 스크립트
// G/ROSTER/CD 의존 없이 STAGES + localStorage 직접 조작

var MIN_P = 5;
var SAVE_KEY = 'game_save';
var ROSTER_KEY = 'game_roster';
var PARTY_KEY = 'game_party';
var NAV_KEY = 'game_nav';

// ── 뷰 상태 ────────────────────────────────
var _viewMode = 'episodes'; // 'episodes' | 'stages'
var _selectedEp = null;

// ── localStorage 조작 ────────────────────
function loadSave() {
  try {
    var d = JSON.parse(localStorage.getItem(SAVE_KEY));
    if (d) return d;
  } catch (_) {}
  return {};
}

function loadParty() {
  try {
    var r = localStorage.getItem(PARTY_KEY);
    if (r) return JSON.parse(r);
  } catch (_) {}
  return [];
}

function saveNav(data) {
  try { localStorage.setItem(NAV_KEY, JSON.stringify(data)); } catch (_) {}
}

function getRoster() {
  try {
    var raw = localStorage.getItem(ROSTER_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}
  return { chars: [], nextId: 1 };
}

// ── 뒤로가기 ──────────────────────────────
function goBack() {
  if (_viewMode === 'stages') {
    _viewMode = 'episodes';
    _selectedEp = null;
    render();
  } else {
    location.href = 'index.html';
  }
}

// ── 에피소드 목록 렌더링 ─────────────────
function renderEpisodes() {
  var l = document.getElementById('stage-list');
  l.innerHTML = '';
  var sub = document.querySelector('.stage-subtitle');
  if (sub) sub.textContent = t('stage.select_episode');

  var title = document.getElementById('nav-title');
  if (title) title.textContent = t('stage.select_episode');

  var save = loadSave();
  var cleared = new Set(save.cleared || []);

  EPISODES.forEach(function(ep) {
    // 해금 로직: EP.1 항상 해금, 이후 에피소드는 이전 에피소드 스테이지 전체 클리어 시 해금
    var unlocked = ep.id === 1;
    if (!unlocked && ep.id > 1) {
      var prevEp = EPISODES.find(function(e) { return e.id === ep.id - 1; });
      if (prevEp) {
        unlocked = prevEp.stages.every(function(sid) { return cleared.has(sid); });
      }
    }

    // 진행률 계산
    var clearCount = ep.stages.filter(function(sid) { return cleared.has(sid); }).length;

    var card = document.createElement('div');
    card.className = 'episode-card' + (unlocked ? '' : ' locked');
    card.innerHTML =
      '<div class="ep-header">' +
        '<div class="ep-num">EP.' + ep.id + '</div>' +
        '<div class="ep-progress">' + clearCount + '/' + ep.stages.length + '</div>' +
      '</div>' +
      '<div class="ep-name">' + t('episode.' + ep.id + '.name') + '</div>' +
      '<div class="ep-desc">' + t('episode.' + ep.id + '.desc') + '</div>' +
      '<div class="ep-progress-bar"><div class="ep-progress-fill" style="width:' + (clearCount / ep.stages.length * 100) + '%"></div></div>';

    if (unlocked) {
      card.onclick = (function(epId) {
        return function() {
          _selectedEp = epId;
          _viewMode = 'stages';
          render();
        };
      })(ep.id);
    }

    l.appendChild(card);
  });
}

// ── 스테이지 목록 렌더링 ────────────────
function renderStages() {
  var l = document.getElementById('stage-list');
  l.innerHTML = '';

  var ep = EPISODES.find(function(e) { return e.id === _selectedEp; });
  if (!ep) return;

  var sub = document.querySelector('.stage-subtitle');
  if (sub) sub.textContent = t('stage.subtitle');

  var title = document.getElementById('nav-title');
  if (title) title.textContent = 'EP.' + ep.id + ' ' + t('episode.' + ep.id + '.name');

  var save = loadSave();
  var cleared = new Set(save.cleared || []);

  var epStages = STAGES.filter(function(st) { return ep.stages.indexOf(st.id) !== -1; });

  // unlock된 스테이지만 (에피소드 내 첫 번째 + 클리어된 다음)
  var available = epStages.filter(function(st, i) { return i === 0 || cleared.has(epStages[i - 1].id); });

  available.forEach(function(st) {
    var cl = cleared.has(st.id);
    var b = document.createElement('div');
    b.className = 'stage-btn' + (cl ? ' cleared' : '');

    var diffColor = st.difficulty < 30 ? 'var(--green)' :
                    st.difficulty < 60 ? 'var(--gold)' :
                    '#ef4444';

    b.innerHTML =
      '<div class="sb-header">' +
        '<div class="sb-num">' + st.id + '</div>' +
        '<div class="sb-stars">' + (cl ? '\u2b50' : '\u2606') + '</div>' +
      '</div>' +
      '<div class="sb-name">' + t('stages.stage_' + st.id + '_name') + '</div>' +
      '<div class="sb-difficulty">' +
        '<div class="sb-diff-bar">' +
          '<div class="sb-diff-fill" style="width:' + st.difficulty + '%;background:' + diffColor + '"></div>' +
        '</div>' +
        '<div class="sb-diff-label">' + t('stage.recommended_level', {level: st.recommendedLevel}) + '</div>' +
      '</div>' +
      '<button class="sb-info-btn" onclick="event.stopPropagation(); showStageInfo(' + st.id + ')">' +
        '\u2139\ufe0f ' + t('stage.info') +
      '</button>' +
      '<button class="sb-practice-btn" onclick="event.stopPropagation(); startPracticeMode(' + st.id + ')">' +
        '\ud83c\udf93 ' + t('stage.practice') +
      '</button>';

    b.onclick = (function(stage) {
      return function() {
        showModeSelectionModal(stage);
      };
    })(st);

    l.appendChild(b);
  });
}

// ── 통합 렌더링 ─────────────────────────
function render() {
  if (_viewMode === 'episodes') {
    renderEpisodes();
  } else {
    renderStages();
  }
}

// ── 초기화 ───────────────────────────────
var init = async function() {
  await i18nInit();
  render();
  renderBottomNav();
  setTimeout(function() { document.getElementById('splash').style.display = 'none'; }, 300);
};

// ── 스테이지 정보 모달 ────────────────────────
function showStageInfo(stageId) {
  var st = STAGES.find(function(s) { return s.id === stageId; });
  if (!st) return;

  // 적 구성 HTML
  var compHTML = Object.entries(st.enemyComposition || {})
    .sort(function(a, b) { return b[1] - a[1]; })
    .map(function(entry) {
      var cls = entry[0], count = entry[1];
      return '<div class="si-enemy-row">' +
        '<span class="si-enemy-icon">' + (CD[cls] ? CD[cls].icon : '\u2753') + '</span>' +
        '<span class="si-enemy-name">' + t('classes.' + cls) + '</span>' +
        '<span class="si-enemy-count">\u00d7' + count + '</span>' +
      '</div>';
    }).join('');

  // 권장 클래스 HTML
  var recHTML = (st.recommendedClasses || [])
    .map(function(cls) {
      return '<div class="si-rec-class">' +
        '<span class="si-rec-icon">' + (CD[cls] ? CD[cls].icon : '\u2753') + '</span>' +
        '<span class="si-rec-name">' + t('classes.' + cls) + '</span>' +
      '</div>';
    }).join('');

  // 전략 팁 HTML
  var tipsHTML = (st.strategyTips || [])
    .map(function(key) { return '<li>' + t(key) + '</li>'; })
    .join('');

  // 보스 HTML
  var bossHTML = st.boss ?
    '<div class="si-boss">' +
      '<div class="si-boss-label">\ud83d\udc80 ' + t('stage.boss') + '</div>' +
      '<div class="si-boss-name">' + st.boss.name + '</div>' +
      '<div class="si-boss-class">' +
        (CD[st.boss.cls] ? CD[st.boss.cls].icon : '\u2753') + ' ' +
        t('classes.' + st.boss.cls) +
      '</div>' +
    '</div>' : '';

  var diffColor = st.difficulty < 30 ? 'var(--green)' :
                  st.difficulty < 60 ? 'var(--gold)' :
                  '#ef4444';

  var modalContent =
    '<div class="stage-info-modal">' +
      '<div class="si-header">' +
        '<div class="si-stage-num">' + t('stage.stage') + ' ' + st.id + '</div>' +
        '<div class="si-stage-name">' + t('stages.stage_' + st.id + '_name') + '</div>' +
      '</div>' +
      '<div class="si-section">' +
        '<div class="si-section-title">' + t('stage.difficulty_rating') + '</div>' +
        '<div class="si-diff-bar">' +
          '<div class="si-diff-fill" style="width:' + st.difficulty + '%;background:' + diffColor + '"></div>' +
        '</div>' +
        '<div class="si-rec-level">' + t('stage.recommended_level_full', {level: st.recommendedLevel}) + '</div>' +
      '</div>' +
      bossHTML +
      '<div class="si-section">' +
        '<div class="si-section-title">' + t('stage.enemy_composition') + '</div>' +
        '<div class="si-enemy-list">' + compHTML + '</div>' +
        '<div class="si-meta">' +
          t('stage.total_enemies', {count: st.tot}) + ' \u00b7 ' +
          t('stage.wave_count', {count: st.spw}) +
        '</div>' +
      '</div>' +
      '<div class="si-section">' +
        '<div class="si-section-title">' + t('stage.recommended_strategy') + '</div>' +
        '<div class="si-rec-classes">' + recHTML + '</div>' +
        '<ul class="si-tips">' + tipsHTML + '</ul>' +
      '</div>' +
    '</div>';

  showModal(t('stage.stage_info'), modalContent, [
    {text: t('common.close'), onClick: closeModal}
  ]);
}

// ── 모드 선택 모달 ──────────────────────────
function showModeSelectionModal(stage) {
  var modalContent =
    '<div class="mode-select-modal">' +
      '<div class="ms-title">' + t('stage.select_mode') + '</div>' +
      '<div class="ms-options">' +
        '<div class="ms-option ms-normal" onclick="startStage(' + stage.id + ', false)">' +
          '<div class="ms-opt-icon">\u2694\ufe0f</div>' +
          '<div class="ms-opt-title">' + t('stage.normal_mode') + '</div>' +
          '<div class="ms-opt-desc">' + t('stage.normal_mode_desc') + '</div>' +
          '<ul class="ms-opt-features">' +
            '<li>\u2713 ' + t('stage.full_rewards') + '</li>' +
            '<li>\u2713 ' + t('stage.clear_record') + '</li>' +
            '<li>\u2717 ' + t('stage.no_auto_revival') + '</li>' +
          '</ul>' +
        '</div>' +
        '<div class="ms-option ms-practice" onclick="startStage(' + stage.id + ', true)">' +
          '<div class="ms-opt-icon">\ud83c\udf93</div>' +
          '<div class="ms-opt-title">' + t('stage.practice_mode') + '</div>' +
          '<div class="ms-opt-desc">' + t('stage.practice_mode_desc') + '</div>' +
          '<ul class="ms-opt-features">' +
            '<li>\u26a0 ' + t('stage.reduced_rewards') + ' (70%)</li>' +
            '<li>\u2713 ' + t('stage.full_exp') + ' (100%)</li>' +
            '<li>\u2713 ' + t('stage.auto_revival') + '</li>' +
            '<li>\u26a0 ' + t('stage.no_clear_record') + '</li>' +
          '</ul>' +
        '</div>' +
      '</div>' +
    '</div>';

  showModal('', modalContent, [
    {text: t('common.cancel'), onClick: closeModal}
  ]);
}

// ── 스테이지 진입 (모드 선택) ──────────────
function startStage(stageId, practiceMode) {
  var stage = STAGES.find(function(s) { return s.id === stageId; });
  if (!stage) return;

  var party = loadParty();
  var roster = getRoster();

  party = party.filter(function(uid) {
    var ch = roster.chars.find(function(c) { return c.uid === uid; });
    return ch && !ch.dead;
  });

  if (party.length >= MIN_P) {
    saveNav({ cStage: stage, party: party, practiceMode: practiceMode });
    location.href = 'battle.html';
  } else {
    saveNav({ cStage: stage, practiceMode: practiceMode });
    location.href = 'party-select.html';
  }

  closeModal();
}

// ── 연습 모드 직접 진입 ──────────────────────
function startPracticeMode(stageId) {
  startStage(stageId, true);
}
