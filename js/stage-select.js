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
  var title = document.getElementById('nav-title');
  if (title) title.textContent = t('stage.select_episode');

  var save = loadSave();
  var cleared = new Set(save.cleared || []);

  // 부제: 제목과 중복되던 문구 대신 전체 진행도
  var sub = document.querySelector('.stage-subtitle');
  var totalStages = EPISODES.reduce(function(a, e) { return a + e.stages.length; }, 0);
  var totalCleared = EPISODES.reduce(function(a, e) { return a + e.stages.filter(function(s) { return cleared.has(s); }).length; }, 0);
  if (sub) sub.textContent = t('stage.total_progress', { n: totalCleared, total: totalStages });

  // 요일 던전 입구
  if (typeof Daily !== 'undefined') {
    var db = document.createElement('button');
    db.type = 'button';
    db.className = 'daily-entry';
    db.innerHTML = '<span class="de-ic">💠</span><span class="de-tx"><b>' + t('daily.title') + '</b><small>' +
      t('daily.today', { classes: Daily.classes().length > 6 ? t('daily.all_classes') : Daily.classes().map(function(c) { return t('classes.' + c); }).join('·') }) +
      '</small></span><span class="de-left">' + t('daily.left', { n: Daily.left(), max: DAILY.perDay }) + '</span>';
    db.onclick = function() { openDaily(); };
    l.appendChild(db);
  }

  // 스토리 다시 보기 (본 장면이 있을 때만)
  if (typeof Story !== 'undefined') {
    var seen = {};
    try { seen = JSON.parse(Store.get('game_story_seen')) || {}; } catch (_) {}
    if (Object.keys(seen).length) {
      var rb = document.createElement('button');
      rb.type = 'button';
      rb.className = 'story-replay-btn';
      rb.textContent = '\uD83D\uDCDC ' + t('story.replay');
      rb.onclick = function() { Story.openReplay(); };
      l.appendChild(rb);
    }
  }

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
    var epStars = ep.stages.reduce(function(a, sid) { return a + stageStars(sid); }, 0);

    var done = clearCount === ep.stages.length;
    var card = document.createElement('div');
    card.className = 'episode-card' + (unlocked ? '' : ' locked') + (done ? ' done' : unlocked ? ' current' : '');
    // 상태 태그: 잠김(해금 조건) / 진행 중 / 완료
    var tag = !unlocked ? '<span class="ep-tag lock">\uD83D\uDD12 ' + t('stage.unlock_after', { ep: ep.id - 1 }) + '</span>'
      : done ? '<span class="ep-tag done">\u2713 ' + t('stage.ep_done') + '</span>'
      : '<span class="ep-tag cur">\u25B6 ' + t('stage.ep_current') + '</span>';
    card.innerHTML =
      '<div class="ep-header">' +
        '<div class="ep-num">EP.' + ep.id + '</div>' +
        tag +
        '<div class="ep-progress"><span class="ep-stars">\u2605 ' + epStars + '/' + (ep.stages.length * 3) + '</span> ' + clearCount + '/' + ep.stages.length + '</div>' +
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

  // 모든 스테이지 렌더링 (unlock 여부는 UI에만 반영)
  epStages.forEach(function(st, index) {
    var stageIndex = index + 1;
    var cl = cleared.has(st.id);
    // unlock 조건: 첫 번째 스테이지 또는 이전 스테이지 클리어
    var unlocked = index === 0 || cleared.has(epStages[index - 1].id);

    var isNext = unlocked && !cl;
    var b = document.createElement('div');
    b.className = 'stage-btn' + (cl ? ' cleared' : '') + (unlocked ? '' : ' locked') + (isNext ? ' next' : '') + (st.boss ? ' boss' : '');

    // 상태 배지: 클리어 ✓ / 다음 도전 / 잠김
    var badge = cl ? '<span class="sb-badge clear">\u2713 CLEAR</span>'
      : isNext ? '<span class="sb-badge next">NEXT</span>'
      : !unlocked ? '<span class="sb-badge lock">\uD83D\uDD12</span>' : '';
    var bossTag = st.boss && st.boss.name ? '<div class="sb-boss">\uD83D\uDC80 ' + bossName(st) + '</div>' : '';
    var starArr = loadStars()[st.id] || [0, 0, 0];
    var starHtml = cl ? '<span class="sb-stars">' + starArr.map(function(v) { return '<i class="' + (v ? 'on' : '') + '">\u2605</i>'; }).join('') + '</span>' : '';
    b.innerHTML =
      '<div class="sb-header">' +
        '<div class="sb-num">EP.' + ep.id + '-' + stageIndex + '</div>' + starHtml + badge +
        '<div class="sb-rec-level">' + t('stage.recommended_level', {level: st.recommendedLevel}) + '</div>' +
      '</div>' +
      '<div class="sb-name">' + t('stages.stage_' + st.id + '_name') + '</div>' + bossTag +
      '<button class="sb-info-btn" onclick="event.stopPropagation(); showStageInfo(' + st.id + ')">' +
        'ℹ️ ' + t('stage.info') +
      '</button>';

    if (unlocked) {
      b.onclick = (function(stage) {
        return function() {
          startStage(stage.id, false);
        };
      })(st);
    }

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
  if (/[?&]daily=1/.test(location.search)) openDaily();   // 요일 던전 전투를 마치고 돌아옴
};

// ── 요일 던전 창: 오늘의 직업 선택 → 난이도 선택 → 출전 (하루 DAILY.perDay회) ──
var _dailyCls = null;
function openDaily() {
  var ov = document.getElementById('modal-overlay');
  var classes = Daily.classes(), left = Daily.left();
  if (!_dailyCls || classes.indexOf(_dailyCls) === -1) _dailyCls = classes[0];
  document.getElementById('modal-title').textContent = '💠 ' + t('daily.title');
  document.getElementById('modal-title').className = '';
  var h = '<div class="daily-help">' + t('daily.help', { n: SOUL.fragsPerStone }) + '</div>' +
    '<div class="daily-left">' + t('daily.left', { n: left, max: DAILY.perDay }) + '</div>' +
    '<div class="daily-cls">';
  classes.forEach(function(c) {
    h += '<button class="dc-btn' + (c === _dailyCls ? ' on' : '') + '" data-cls="' + c + '">' + getClassIcon(c) +
      '<span>' + t('classes.' + c) + '</span><small>💠' + Soul.stones(c) + ' · ' + Soul.frags(c) + '/' + SOUL.fragsPerStone + '</small></button>';
  });
  h += '</div><div class="daily-tiers">';
  DAILY.tiers.forEach(function(T, i) {
    var open = Daily.tierOpen(i), can = open && left > 0;
    h += '<button class="dt-btn' + (can ? '' : ' locked') + '" data-tier="' + i + '"' + (can ? '' : ' disabled') + '>' +
      '<b>' + t('daily.tier_' + T.key) + '</b>' +
      '<span>' + (open ? t('daily.tier_info', { eq: T.eq, n: T.frags }) : t('daily.tier_lock', { n: T.unlock })) + '</span></button>';
  });
  h += '</div>';
  document.getElementById('modal-sub').innerHTML = h;
  var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
  var cb = document.createElement('button'); cb.className = 'modal-btn secondary'; cb.textContent = t('common.close');
  cb.onclick = function() { ov.classList.remove('show'); }; bt.appendChild(cb);
  ov.classList.add('show');
  document.querySelectorAll('.dc-btn').forEach(function(b) { b.onclick = function() { _dailyCls = b.dataset.cls; openDaily(); }; });
  document.querySelectorAll('.dt-btn:not(.locked)').forEach(function(b) {
    b.onclick = function() {
      if (Daily.left() <= 0) return;
      Daily.consume();   // 시도하면 입장 횟수 소모 (패배해도 돌려주지 않음)
      ov.classList.remove('show');
      _launchStage(Daily.buildStage(_dailyCls, +b.dataset.tier), false);
    };
  });
}

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
  // 스테이지 데이터 팁 + 적 구성에 따른 전술 팁 (적 기사 → 엄호·제압 구역 / 암살자 → 엄호 무시 주의)
  var tipKeys = (st.strategyTips || []).slice();
  var enemyCls = (st.en || []).concat(st.boss ? [st.boss.cls] : []);
  if (enemyCls.indexOf('knight') !== -1) tipKeys.push('stage.tip_enemy_knight');
  if (enemyCls.indexOf('assassin') !== -1) tipKeys.push('stage.tip_enemy_assassin');
  var tipsHTML = tipKeys
    .map(function(key) { return '<li>' + t(key) + '</li>'; })
    .join('');

  // 보스 HTML
  var bossHTML = st.boss ?
    '<div class="si-boss">' +
      '<div class="si-boss-label">💀 ' + t('stage.boss') + '</div>' +
      '<div class="si-boss-name">' + bossName(st) + '</div>' +
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
      // 별 조건
      '<div class="si-section"><div class="si-section-title">\u2B50 ' + t('stars.title') + '</div><ul class="si-stars">' +
        [t('stars.cond_clear'), t('stars.cond_nodeath'), t('stars.cond_turns', { n: starTurnLimit(st) })].map(function(c, i) {
          var got = (loadStars()[st.id] || [0, 0, 0])[i];
          return '<li class="' + (got ? 'on' : '') + '"><i>\u2605</i>' + c + '</li>';
        }).join('') + '</ul></div>' +
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
      (Hazard.forStage(st) ? '<div class="si-section si-hazard">' +
        '<div class="si-section-title">' + Hazard.forStage(st).icon + ' ' + Hazard.name(Hazard.forStage(st)) + '</div>' +
        '<div class="si-meta">' + Hazard.describe(Hazard.forStage(st), st) + '</div></div>' : '') +
      '<div class="si-section">' +
        '<div class="si-section-title">' + t('stage.recommended_strategy') + '</div>' +
        '<ul class="si-tips">' + tipsHTML + '</ul>' +
      '</div>' +
    '</div>';

  // 클리어한 스테이지는 연습 모드로 반복 가능 (전사자 없음 · 골드 ECON.practiceMul · 클리어·별 기록 없음)
  var btns = [{text: t('common.close'), onClick: closeModal}];
  if ((loadSave().cleared || []).indexOf(st.id) !== -1) {
    btns.unshift({text: t('stage.practice_mode') + ' (' + Math.round(ECON.practiceMul * 100) + '% G)', onClick: function() { closeModal(); startStage(st.id, true); }});
  }
  showModal('', modalContent, btns);
}


// ── 스테이지 진입 (모드 선택) ──────────────
// 출전 전 스토리(에피소드 첫 진입 프롤로그 → 스테이지 pre)를 먼저 보여준 뒤 기존 출전 흐름으로 이동
var _startingStage = false;
function startStage(stageId, practiceMode) {
  var stage = STAGES.find(function(s) { return s.id === stageId; });
  if (!stage || _startingStage) return;
  if (typeof Story === 'undefined') { _launchStage(stage, practiceMode); return; }
  _startingStage = true;
  closeModal();
  Story.beforeStage(stage).then(function() {
    _startingStage = false;
    _launchStage(stage, practiceMode);
  });
}

function _launchStage(stage, practiceMode) {
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
    Store.set('ps_can_start', 'true');
    location.href = 'party-select.html';
  }

  closeModal();
}

