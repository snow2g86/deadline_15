// ═══════════════════════════════════════════
//  data/hazards.js — 맵 환경 디버프 · 장비 마법부여 · 보물상자
//  ① 환경: 맵 종류(stage.mapType)마다 클랜원에게 제약. 그 디버프에 맞는 마법부여 장비를 하나라도 장착한 클랜원은 무효
//     (적 총원을 줄인 대신 난이도를 맵 특성으로 보충 — data/stages.js 전투 길이 조정 참고)
//  ② 마법부여: 성소 '마법부여' 탭에서 가진 장비에 마법부여 룬 1개 + 100G로 저항 하나를 새김 (item.enchant).
//     장비 하나에 마법부여는 하나뿐 — 다른 룬으로 부여하면 덮어씀(같은 종류는 불가), 쓴 룬은 사라짐. 룬은 전투 승리 드랍·상점 룬 뽑기·보물상자로 얻음
//  ③ 보물상자: 전투 시작 때 맵 가운데 구역에 무작위로 놓이고, 클랜원이 밟으면 열림 (골드·전투 물약·장비·영혼석 조각·룬)
// ═══════════════════════════════════════════
// dot: 클랜원 차례가 끝날 때 최대 HP 비율 피해 (사망하지는 않음, 후반일수록 커짐) · move/range: 더하기 · def/heal: 배율
var HAZARDS = {
  volcano: { id: 'burn',     icon: '🔥', enchant: 'fire',   dot: 0.05 },
  abyss:   { id: 'hellfire', icon: '☄️', enchant: 'fire',   dot: 0.04 },   // 7% → 4% (후반 지옥 맵 소모전·판 길이 완화)
  desert:  { id: 'heat',     icon: '☀️', enchant: 'heat',   move: -1 },
  canyon:  { id: 'gale',     icon: '🌪️', enchant: 'wind',   range: -1 },
  jungle:  { id: 'venom',    icon: '🦟', enchant: 'poison', dot: 0.03 },
  swamp:   { id: 'miasma',   icon: '☠️', enchant: 'poison', dot: 0.04 },
  frozen:  { id: 'frost',    icon: '❄️', enchant: 'cold',   def: 0.75 },
  ruins:   { id: 'curse',    icon: '🕯️', enchant: 'curse',  heal: 0.5 },
  // plains · fortress: 환경 디버프 없음
};
// cat: 'def' = 환경 저항(item.enchant), 'atk' = 공격 효과(item.enchantAtk). 한 장비에 방어·공격 하나씩 함께 새길 수 있음
var ENCHANTS = {
  fire:   { icon: '🔥', cat: 'def' }, heat: { icon: '☀️', cat: 'def' }, wind: { icon: '🌪️', cat: 'def' },
  poison: { icon: '🧪', cat: 'def' }, cold: { icon: '❄️', cat: 'def' }, curse: { icon: '✨', cat: 'def' },
  // 공격용: 장착한 클랜원의 일반 공격(반격·경계 사격 포함)에 붙는 효과
  flame:  { icon: '🔥', cat: 'atk', burn: 0.15, turns: 2 },   // 화상: 턴당 공격력 15%
  frost:  { icon: '🧊', cat: 'atk', freeze: 0.20 },           // 20% 확률 1턴 빙결
  venom:  { icon: '🐍', cat: 'atk', poison: 0.10, turns: 3 }, // 독: 턴당 공격력 10%
  thunder:{ icon: '⚡', cat: 'atk', dmg: 0.15 },              // 피해 +15%
  vamp:   { icon: '🩸', cat: 'atk', drain: 0.15 },            // 준 피해의 15% 회복
  sunder: { icon: '🔨', cat: 'atk', pierce: 0.30 },           // 방어력 30% 무시
};
var ENCHANT_FIELD = { def: 'enchant', atk: 'enchantAtk' };
var ENCHANT_FEE = 100;        // 마법부여 1회 비용 (고정)
var RUNE_GACHA_COST = 300;    // 상점 룬 뽑기 1회 (무작위 룬 1개)
var RUNE_DROP_CHANCE = 0.2;   // 전투 승리 시 룬 드랍 확률

// ── 보물상자 ──
// 전투당 1~2개, 3~9행의 빈 평지·숲·언덕에 놓임. 보상 확률: 골드 32% · 전투 물약 17% · 마법부여 룬 15% · 장비 13% · 강화석 11% · 보호 주문서 2% · 영혼석 조각 10%
var CHEST = { min: 1, max: 2, rows: [3, 9], odds: { gold: 0.32, potion: 0.17, rune: 0.15, equip: 0.13, stone: 0.11, protect: 0.02, soul: 0.10 } };
