// js/common/render.js — UI 렌더링 유틸리티
// 아이콘, 스프라이트 등 공통 렌더링 함수를 중앙화합니다

// ── 아이콘 렌더링 ────────────────────────────
function clsIcon(cls, size) {
  const d = JAB[cls];
  if (!d) return '';
  if (d.isSummon) return '<span style="font-size:' + size + 'px;line-height:1">' + (d.icon || '') + '</span>';
  return '<img class="cls-icon" src="image/icon/jab/' + cls + '.png" alt="' + cls + '" style="width:' + size + 'px;height:' + size + 'px">';
}

// fallback: SKILL_ICONS 미정의 시 대신 표시할 값 (예: 스킬 데이터의 이모지). 생략 시 '❓'
function skillIcon(skillId, size, fallback) {
  if (typeof SKILL_ICONS !== 'undefined' && SKILL_ICONS[skillId]) {
    const iconPath = SKILL_ICONS[skillId];
    return '<img class="skill-icon" src="' + iconPath + '" alt="' + skillId + '" style="width:' + size + 'px;height:' + size + 'px;image-rendering:pixelated">';
  }
  return fallback || '❓';
}

// ── 캐릭터 초상화 (얼굴 원형 크롭) ────────────────────────────
// 전투 화면 Renderer.portrait와 같은 방식. 목록 카드에서 같은 직업끼리도 구분되도록 사용
function charPortrait(ch, size) {
  size = size || 32;
  var d = typeof JAB !== 'undefined' ? JAB[ch.cls] : null;
  if (ch.cls.indexOf('summon_') === 0 || (d && d.isSummon)) return clsIcon(ch.cls, size);
  var suffix = (ch.gender || 'm') === 'f' ? '02' : '01';
  return '<span class="char-portrait" style="width:' + size + 'px;height:' + size + 'px;background-image:url(image/character/' +
    ch.cls + '_' + suffix + '.png)"></span>';
}

// ── 캐릭터 스프라이트 ────────────────────────────
function charSprite(cls, size, gender) {
  if (typeof _charSprite === 'function') {
    return _charSprite(cls, size, gender);
  }
  // 소환수는 이미지 없음 → 이모지 표시
  var d = typeof JAB !== 'undefined' ? JAB[cls] : null;
  if (d && d.isSummon) return '<span style="font-size:' + size + 'px;line-height:1">' + (d.icon || '') + '</span>';
  var suffix = (gender || 'm') === 'f' ? '02' : '01';
  return '<img src="image/character/' + cls + '_' + suffix + '.png" width="' + size + '" style="image-rendering:pixelated">';
}

// ── 스플래시 숨김 ────────────────────────────
function hideSplash(delay) {
  setTimeout(function() { var el = document.getElementById('splash'); if (el) el.style.display = 'none'; }, delay || 300);
}

// ── 탭 전환 유틸 ────────────────────────────
function toggleTabButtons(tab) {
  document.querySelectorAll('.game-tab').forEach(function(btn) {
    btn.classList.toggle('active', btn.dataset.tab === tab);
  });
}

// ── Gold UI 업데이트 ────────────────────────────
function updatePageGold(elementId) {
  var el = document.getElementById(elementId);
  if (el) el.textContent = (_gold || 0).toLocaleString();
}
