// js/common/constants.js — 전역 상수 정의
// 모든 페이지에서 공유하는 상수를 중앙화합니다

// ── localStorage 키 ────────────────────────────
const SAVE_KEY = 'game_save';
const ROSTER_KEY = 'game_roster';
const PARTY_KEY = 'game_party'; // 레거시 (마이그레이션용)
const PARTIES_KEY = 'game_parties'; // 다중 파티 (신규)
const NAV_KEY = 'game_nav';
const INVENTORY_KEY = 'game_inventory';
const SHOP_KEY = 'game_shop';

// ── 게임 설정 ────────────────────────────────
const MIN_P = 5;
const MAX_P = 5;
const MAX_LEVEL = 15;
const MAX_SKILL_LV = 10;

// ── 등급 관련 ────────────────────────────────
const GRADE_ORDER = ['C', 'B', 'A', 'S'];
const GRADE_COLORS = {
  S: '#f0c040',
  A: '#60a5fa',
  B: '#4ade80',
  C: '#9ca3af'
};

// ── 역할 매핑 ────────────────────────────────
const ROLE_MAP = {
  warrior: 'melee',
  knight: 'melee',
  assassin: 'melee',
  novice: 'melee',
  brawler: 'melee',
  lancer: 'melee',
  sapper: 'melee',
  mage: 'ranged',
  archer: 'ranged',
  summoner: 'ranged',
  shaman: 'ranged',
  priest: 'healer'
};

// ── 직업군 매핑 (UI 필터용) ────────────────────
const CLASS_GROUP_MAP = {
  'novice': 'beginner',      // 전제
  'warrior': 'melee',        // 근접
  'knight': 'melee',
  'assassin': 'melee',
  'brawler': 'melee',
  'lancer': 'melee',
  'archer': 'ranged',        // 원거리
  'mage': 'ranged',
  'summoner': 'ranged',
  'shaman': 'ranged',
  'priest': 'support',       // 서포트
  'sapper': 'support'
};

// 직업군 정보 (필터 UI용)
const CLASS_GROUPS = {
  'beginner': { key: 'beginner', label: 'group.beginner', icon: '🎓' },
  'melee': { key: 'melee', label: 'group.melee', icon: '⚔️' },
  'ranged': { key: 'ranged', label: 'group.ranged', icon: '🏹' },
  'support': { key: 'support', label: 'group.support', icon: '✨' }
};
