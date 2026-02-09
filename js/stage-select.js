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
    b.innerHTML =
      '<div class="sb-num">' + st.id + '</div>' +
      '<div class="sb-name">' + t('stages.stage_' + st.id + '_name') + '</div>' +
      '<div class="sb-info">' + t('stage.enemies', { count: st.tot }) + '</div>' +
      '<div class="sb-stars">' + (cl ? '\u2b50' : '\u2606') + '</div>';
    b.onclick = (function(stage) {
      return function() {
        var party = loadParty();
        var roster = getRoster();
        // 죽은 유닛 제거
        party = party.filter(function(uid) {
          var ch = roster.chars.find(function(c) { return c.uid === uid; });
          return ch && !ch.dead;
        });
        if (party.length >= MIN_P) {
          saveNav({ cStage: stage, party: party });
          location.href = 'battle.html';
        } else {
          saveNav({ cStage: stage });
          location.href = 'party-select.html';
        }
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
