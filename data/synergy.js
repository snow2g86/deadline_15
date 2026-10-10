// ═══════════════════════════════════════════
//  data/synergy.js — 클래스 조합 버프 (파티 광역 버프)
//  출전 파티 5명의 직업 구성으로 정해지고, 전투 시작 때 해당하는 클랜원 전원에게 적용된다.
//  - 단일 직업 5인: 강한 특화 버프 + 뚜렷한 약점 (예: 전사 5 = 광전사, 공격 ×2 · 방어 ×0.5)
//  - 같은 직업 3~4인: 그 직업의 작은 특화 버프
//  - 역할 조합: 균형 진형 / 만능 부대 / 포격진 / 돌격대 / 철옹성
//  효과 eff: hp·atk·def = 배율, move·range = 더하기, heal = 회복량 배율. to: 'ranged'|'melee'|'healer'면 그 역할만
//  이름은 t('synergy.<id>'), 효과 설명은 수치로 자동 생성 (Synergy.describe)
// ═══════════════════════════════════════════
var SYNERGY_MONO = {
  warrior:  { icon: '🔥', eff: { atk: 2.0, def: 0.5 } },                   // 광전사: 초반을 쓸어버리지만 맞으면 녹는다
  knight:   { icon: '🏰', eff: { def: 2.0, hp: 1.3, atk: 0.6 } },          // 철벽 기사단
  archer:   { icon: '🎯', eff: { range: 1, atk: 1.4, hp: 0.75 } },         // 명사수대
  mage:     { icon: '🌌', eff: { atk: 1.6, hp: 0.75, def: 0.7 } },         // 마도 연합
  priest:   { icon: '🕊️', eff: { heal: 1.8, hp: 1.3, atk: 0.6 } },         // 성가대
  assassin: { icon: '🌑', eff: { atk: 1.5, move: 1, hp: 0.7 } },           // 그림자단
  brawler:  { icon: '🥊', eff: { hp: 1.4, atk: 1.3, def: 0.7 } },          // 투기장
  lancer:   { icon: '🛡️', eff: { def: 1.5, atk: 1.25, move: -1 } },        // 장창 방진
  sapper:   { icon: '🧨', eff: { atk: 1.35, hp: 1.2, def: 0.8 } },         // 공병대
  shaman:   { icon: '🪬', eff: { atk: 1.45, hp: 0.85 } },                  // 주술 의식
  summoner: { icon: '📜', eff: { atk: 1.45, hp: 0.8 } },                   // 소환 군단
  novice:   { icon: '🌱', eff: { hp: 1.15, atk: 1.15, def: 1.15 } },       // 견습 동기
};
var SYNERGY_TRIO = {   // 같은 직업 3~4인
  warrior:  { atk: 1.2, def: 0.9 },  knight:  { def: 1.25 },             archer:  { atk: 1.15 },
  mage:     { atk: 1.2, hp: 0.9 },   priest:  { heal: 1.3 },             assassin: { atk: 1.2, hp: 0.9 },
  brawler:  { hp: 1.15, atk: 1.1 },  lancer:  { def: 1.15, atk: 1.05 },  sapper:  { atk: 1.15 },
  shaman:   { atk: 1.15 },           summoner: { atk: 1.15 },            novice:  { hp: 1.1, atk: 1.05 },
};
