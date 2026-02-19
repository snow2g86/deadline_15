// js/common/render.js — UI 렌더링 유틸리티
// 아이콘, 스프라이트 등 공통 렌더링 함수를 중앙화합니다

// ── 아이콘 렌더링 ────────────────────────────
function clsIcon(cls, size) {
  const d = JAB[cls];
  if (!d) return '';
  if (d.isSummon) return '<span style="font-size:' + size + 'px;line-height:1">' + (d.icon || '') + '</span>';
  return '<img class="cls-icon" src="image/icon/jab/' + cls + '.png" alt="' + cls + '" style="width:' + size + 'px;height:' + size + 'px">';
}

function skillIcon(skillId, size) {
  if (typeof SKILL_ICONS !== 'undefined' && SKILL_ICONS[skillId]) {
    const iconPath = SKILL_ICONS[skillId];
    return '<img class="skill-icon" src="' + iconPath + '" alt="' + skillId + '" style="width:' + size + 'px;height:' + size + 'px;image-rendering:pixelated">';
  }
  return '❓';
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
