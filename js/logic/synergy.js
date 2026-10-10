// ═══════════════════════════════════════════
//  logic/synergy.js — 클래스 조합 버프 계산
//  수치·표는 data/synergy.js (순수 데이터), 여기는 그 데이터를 쓰는 계산. 페이지에서 data/synergy.js 바로 뒤에 불러온다
// ═══════════════════════════════════════════

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
    var res = s.resonance ? ' ✦' + t('gear.resonance') : '';   // 직업 세트 공명 (data/gear.js)
    if (s.id.indexOf('mono_') === 0) return t('synergy.mono_' + s.cls) + res;
    if (s.id.indexOf('trio_') === 0) return t('synergy.trio', { cls: t('classes.' + s.cls) }) + res;
    return t('synergy.' + s.id) + res;
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
