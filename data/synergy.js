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
var SYNERGY_ROLE = [
  // 균형 진형: 탱커(기사·창기사) + 치유(사제) + 원거리 + 근접 딜러가 모두 있음
  { id: 'balanced', icon: '⚖️', eff: { hp: 1.1, def: 1.1 },
    test: function(c) { return (c.knight || c.lancer) && c.priest && (c.archer || c.mage || c.shaman || c.summoner) && (c.warrior || c.assassin || c.brawler || c.sapper || c.novice); } },
  // 만능 부대: 5명 모두 다른 직업
  { id: 'diverse', icon: '🌈', eff: { atk: 1.1, move: 1 }, test: function(c, n) { return n.distinct >= 5; } },
  // 포격진: 원거리 3명 이상 → 원거리만 공격 +15%
  { id: 'artillery', icon: '💥', eff: { atk: 1.15 }, to: 'ranged', test: function(c, n) { return n.ranged >= 3; } },
  // 돌격대: 근접 4명 이상 → 근접만 이동 +1
  { id: 'vanguard', icon: '🐎', eff: { move: 1 }, to: 'melee', test: function(c, n) { return n.melee >= 4; } },
  // 철옹성: 기사·창기사 합쳐 2명 이상 → 전원 방어 +10%
  { id: 'bulwark', icon: '🧱', eff: { def: 1.1 }, test: function(c) { return (c.knight || 0) + (c.lancer || 0) >= 2; } },
];

var Synergy = {
  // 직업 목록 → 활성 조합 버프 [{ id, icon, eff, to }]
  compute: function(classes) {
    var c = {}, n = { ranged: 0, melee: 0, distinct: 0 };
    classes.forEach(function(k) {
      if (!k || k === 'commander' || k.indexOf('summon_') === 0) return;
      c[k] = (c[k] || 0) + 1;
      var role = typeof ROLE_MAP !== 'undefined' ? ROLE_MAP[k] : null;
      if (role === 'ranged') n.ranged++; else if (role === 'melee') n.melee++;
    });
    n.distinct = Object.keys(c).length;
    var out = [];
    Object.keys(c).forEach(function(k) {
      if (c[k] >= 5 && SYNERGY_MONO[k]) out.push({ id: 'mono_' + k, cls: k, icon: SYNERGY_MONO[k].icon, eff: SYNERGY_MONO[k].eff });
      else if (c[k] >= 3 && SYNERGY_TRIO[k]) out.push({ id: 'trio_' + k, cls: k, icon: '✦', eff: SYNERGY_TRIO[k] });
    });
    SYNERGY_ROLE.forEach(function(r) { if (r.test(c, n)) out.push({ id: r.id, icon: r.icon, eff: r.eff, to: r.to || null }); });
    return out;
  },
  name: function(s) {
    if (s.id.indexOf('mono_') === 0) return t('synergy.mono_' + s.cls);
    if (s.id.indexOf('trio_') === 0) return t('synergy.trio', { cls: t('classes.' + s.cls) });
    return t('synergy.' + s.id);
  },
  // 효과를 '공격 ×2 · 방어 ×0.5' 같은 문구로
  describe: function(s) {
    var e = s.eff, parts = [];
    ['atk', 'def', 'hp', 'heal'].forEach(function(k) { if (e[k] && e[k] !== 1) parts.push(t('synergy.stat_' + k) + ' ×' + (+e[k].toFixed(2))); });
    ['move', 'range'].forEach(function(k) { if (e[k]) parts.push(t('synergy.stat_' + k) + ' ' + (e[k] > 0 ? '+' : '') + e[k]); });
    var txt = parts.join(' · ');
    if (s.to) txt = t('synergy.only_' + s.to) + ' ' + txt;
    return txt;
  },
  // 전투 시작 때 클랜원 유닛에 적용 (소환수 제외). 같은 스탯 배율은 곱해짐
  apply: function(units, list) {
    units.forEach(function(u) {
      if (u.team !== 'ally' || u.isSummon) return;
      list.forEach(function(s) {
        if (s.to && (typeof ROLE_MAP === 'undefined' || ROLE_MAP[u.cls] !== s.to)) return;
        var e = s.eff;
        if (e.hp) { u.mhp = Math.max(1, Math.round(u.mhp * e.hp)); u.hp = Math.min(u.mhp, Math.round(u.hp * e.hp)); }
        if (e.atk) u.atk = Math.max(1, Math.round(u.atk * e.atk));
        if (e.def) u.def = Math.max(0, Math.round(u.def * e.def));
        if (e.move) u.move = Math.max(1, Math.min(6, u.move + e.move));
        if (e.range && u.range > 1) u.range = Math.min(6, u.range + e.range);   // 사거리 보너스는 원거리만
        if (e.heal) u._healMul = (u._healMul || 1) * e.heal;
      });
    });
  },
};
