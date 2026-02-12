// js/common/render.js — UI 렌더링 유틸리티
// 아이콘, 스프라이트 등 공통 렌더링 함수를 중앙화합니다

// ── 아이콘 렌더링 ────────────────────────────
function clsIcon(cls, size) {
  const d = JAB[cls];
  if (!d) return '';
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
  // Fallback
  const suffix = (gender || 'm') === 'f' ? '02' : '01';
  return '<img src="image/character/' + cls + '_' + suffix + '.png" width="' + size + '" style="image-rendering:pixelated">';
}
