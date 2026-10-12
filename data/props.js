// ═══════════════════════════════════════════
//  props.js — 맵 오브젝트(숲 나무·평지 장식) 데이터 (값만, 그리기는 js/battle/props.js)
//  언덕·바위는 원래 블록 유지 (2026-10-13 둔덕·바위 그림으로 대체해 봤지만 사용자가 별로라 함)
//  그림: image/map/<이름>.png (tools/gen-props.py → tools/make-props.py), 발 위치 = 그림 아래 가운데
// ═══════════════════════════════════════════

// 화면 표시 높이(CSS px) — tools/make-props.py HEIGHT 와 같게
const PROP_ART = {
  tree_a: { h: 41 }, tree_b: { h: 58 }, pine: { h: 48 },   // 한 그루 나무는 2026-10-13 사용자 요청으로 다시 2/3 (62→41, 72→48)
  grass: { h: 16 }, stones: { h: 12 },
};

// 지형별로 세울 오브젝트
//  art: 후보(칸마다 고정 무작위), at: 칸 안 발 위치 [가로, 세로] (타일 반폭·반높이 비율, 화면 기준 — 음수 세로 = 화면 안쪽)
//  spots/count: 한 칸에 여러 개 — 자리 목록 중 count[0]~count[1] 개, scale: 크기 배율 범위, spread: 자리 흩뿌림
//  chance: 세울 확률(없으면 항상), ground: 바닥 장식(항상 유닛 아래, 가리지 않음)
const TILE_PROPS = {
  // 숲: 한 칸에 4~5그루 빽빽하게 (2026-10-13 사용자 요청) — 뒤·좌·우·가운데·앞 자리, 크기 0.8~1.1배
  forest: { art: ['tree_a', 'tree_a', 'pine'], spots: [[0, -0.55], [-0.5, -0.05], [0.5, -0.05], [0, 0.1], [-0.15, 0.5]], count: [4, 5],
            spread: 0.25, scale: [0.8, 1.1] },
  // 평지: 풀·돌멩이를 한 칸에 5~8개 모아 풍성하게 (2026-10-13 사용자 요청 두 번: 3~5개·40% → 더 많이), 60% 칸에
  plain:  { art: ['grass', 'grass', 'grass', 'stones'],
            spots: [[-0.45, 0], [0.45, 0], [0, -0.45], [0, 0.45], [-0.2, -0.2], [0.25, 0.2], [0, 0], [0.22, -0.25], [-0.25, 0.22], [0.5, 0.3]],
            count: [5, 8], spread: 0.3, scale: [0.7, 1.15], chance: 0.6, ground: true },
};

// 맵 테마별 색 보정 (CSS filter) — 없으면 그대로
const PROP_THEME_FILTER = {
  desert:   'sepia(.55) saturate(.8) brightness(1.05)',
  volcano:  'sepia(.7) saturate(.5) brightness(.75)',
  frozen:   'saturate(.35) brightness(1.2) hue-rotate(150deg)',
  swamp:    'saturate(.7) brightness(.8)',
  ruins:    'saturate(.75) brightness(.9)',
  abyss:    'saturate(.4) brightness(.65) hue-rotate(220deg)',
};
