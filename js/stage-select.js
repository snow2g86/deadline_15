// stage-select.js — 스테이지 선택 페이지 전용 스크립트
// 스테이지 선택 및 파티 검증 로직

// ── 뷰 상태 ────────────────────────────────
var _viewMode = 'episodes'; // 'episodes' | 'stages'
var _selectedEp = null;

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
  var available = epStages.filter(function(_, i) { return i === 0 || cleared.has(epStages[i - 1].id); });

  available.forEach(function(st, index) {
    var stageIndex = index + 1;
    var cl = cleared.has(st.id);
    var b = document.createElement('div');
    b.className = 'stage-btn' + (cl ? ' cleared' : '');

    b.innerHTML =
      '<div class="sb-header">' +
        '<div class="sb-num">EP.' + ep.id + '-' + stageIndex + '</div>' +
        '<div class="sb-rec-level">' + t('stage.recommended_level', {level: st.recommendedLevel}) + '</div>' +
      '</div>' +
      '<div class="sb-name">' + t('stages.stage_' + st.id + '_name') + '</div>' +
      '<button class="sb-info-btn" onclick="event.stopPropagation(); showStageInfo(' + st.id + ')">' +
        'ℹ️ ' + t('stage.info') +
      '</button>';

    b.onclick = (function(stage) {
      return function() {
        startStage(stage.id, false);
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
  hideSplash();
};

// ── 클래스 아이콘 반환 ──────────────────────
function getClassIcon(cls) {
  if (!JAB[cls]) return '❓';
  return '<img class="cls-icon" src="image/icon/jab/' + cls + '.png" alt="' + cls + '" style="width:20px;height:20px">';
}

// ── 스테이지 정보 모달 ────────────────────────
function showStageInfo(stageId) {
  var st = STAGES.find(function(s) { return s.id === stageId; });
  if (!st) return;

  // EP.x-y 형식으로 표시
  var ep = Math.floor((st.id - 1) / 10) + 1;
  var stageIndex = ((st.id - 1) % 10) + 1;

  // 적 구성 HTML
  var compHTML = Object.entries(st.enemyComposition || {})
    .sort(function(a, b) { return b[1] - a[1]; })
    .map(function(entry) {
      var cls = entry[0], count = entry[1];
      return '<div class="si-enemy-row">' +
        '<span class="si-enemy-icon">' + getClassIcon(cls) + '</span>' +
        '<span class="si-enemy-name">' + t('classes.' + cls) + '</span>' +
        '<span class="si-enemy-count">×' + count + '</span>' +
      '</div>';
    }).join('');

  // 전략 팁 HTML
  var tipsHTML = (st.strategyTips || [])
    .map(function(key) { return '<li>' + t(key) + '</li>'; })
    .join('');

  // 보스 HTML
  var bossHTML = st.boss ?
    '<div class="si-boss">' +
      '<div class="si-boss-label">💀 ' + t('stage.boss') + '</div>' +
      '<div class="si-boss-name">' + st.boss.name + '</div>' +
      '<div class="si-boss-class">' +
        getClassIcon(st.boss.cls) + ' ' +
        t('classes.' + st.boss.cls) +
      '</div>' +
    '</div>' : '';

  var modalContent =
    '<div class="stage-info-modal">' +
      '<div class="si-header">' +
        '<div class="si-header-top">' +
          '<div class="si-stage-num">EP.' + ep + '-' + stageIndex + '</div>' +
          '<div class="si-rec-level">' + t('stage.recommended_level_full', {level: st.recommendedLevel}) + '</div>' +
        '</div>' +
        '<div class="si-stage-name">' + t('stages.stage_' + st.id + '_name') + '</div>' +
      '</div>' +
      bossHTML +
      '<div class="si-section">' +
        '<div class="si-section-header">' +
          '<div class="si-section-title">' + t('stage.enemy_composition') + '</div>' +
          '<div class="si-meta">' +
            '[' + t('stage.total_enemies', {count: st.tot}) + ' / ' +
            t('stage.wave_count', {count: st.spw}) + ']' +
          '</div>' +
        '</div>' +
        '<div class="si-enemy-list">' + compHTML + '</div>' +
      '</div>' +
      '<div class="si-section">' +
        '<div class="si-section-title">' + t('stage.recommended_strategy') + '</div>' +
        '<ul class="si-tips">' + tipsHTML + '</ul>' +
      '</div>' +
    '</div>';

  showModal('', modalContent, [
    {text: t('common.close'), onClick: closeModal}
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
    // 출격 버튼 활성화
    localStorage.setItem('ps_can_start', 'true');
    location.href = 'party-select.html';
  }

  closeModal();
}

