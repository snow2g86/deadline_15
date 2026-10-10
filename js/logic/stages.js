// ═══════════════════════════════════════════
//  logic/stages.js — 스테이지 계산 (적 강함 배율·총원 상한 적용, 난이도·추천, 적 레벨, 보스 이름)
//  수치·표는 data/stages.js (순수 데이터), 여기는 그 데이터를 쓰는 계산. 페이지에서 data/stages.js 바로 뒤에 불러온다
//  불러올 때 STAGES 에 적 배율(sm)·총원 상한·난이도 정보를 채운다
// ═══════════════════════════════════════════

// ═══ 난이도 계산 및 데이터 확장 로직 ═══
function calculateDifficulty(stage) {
  return Math.min(100, Math.round(
    stage.id * 0.8 +
    stage.tot * 0.1 +
    (stage.sm.hp * 5) +
    (stage.sm.atk * 5) +
    stage.spw * 2 +
    (stage.boss ? 15 : 0)
  ));
}

function getEnemyComposition(enemies) {
  return enemies.reduce(function(acc, cls) {
    acc[cls] = (acc[cls] || 0) + 1;
    return acc;
  }, {});
}

function recommendCounters(composition) {
  var sorted = Object.entries(composition).sort(function(a, b) { return b[1] - a[1]; });
  var dominant = sorted.slice(0, 2).map(function(e) { return e[0]; });

  var counters = {
    warrior: ['mage', 'archer'],
    knight: ['mage', 'brawler'],
    mage: ['assassin', 'archer'],
    summoner: ['assassin', 'warrior'],
    assassin: ['knight', 'brawler'],
    archer: ['knight', 'warrior'],
    priest: ['assassin', 'warrior'],
    brawler: ['mage', 'archer'],
    lancer: ['mage', 'assassin'],
    sapper: ['archer', 'mage'],
    shaman: ['warrior', 'knight'],
    novice: []
  };

  var recommended = new Set();
  dominant.forEach(function(cls) {
    (counters[cls] || []).forEach(function(c) { recommended.add(c); });
  });

  return Array.from(recommended).slice(0, 3);
}

function generateStrategyTips(stage) {
  var tips = [];

  if (stage.style === 'defense') {
    tips.push('strategy_tips.defend_gate');
    tips.push('strategy_tips.use_terrain');
  } else if (stage.style === 'offense') {
    tips.push('strategy_tips.offense_quick');
    tips.push('strategy_tips.use_range');
  } else {
    tips.push('strategy_tips.mixed_balance');
  }

  if (stage.boss) {
    tips.push('strategy_tips.focus_boss');
  }

  var comp = getEnemyComposition(stage.en);
  if (comp.mage && comp.mage > 3) tips.push('strategy_tips.use_assassin');
  if (comp.warrior && comp.warrior > 5) tips.push('strategy_tips.use_tank');
  if (comp.knight && comp.knight > 3) tips.push('strategy_tips.use_aoe');

  return tips.slice(0, 2);
}
function stageSm(id) { return Math.round(ENEMY_SM_BASE * Math.pow(ENEMY_SM_GROWTH, id - 1) * 100) / 100; }
function stageEnemyLv(id) { return 1 + Math.floor((id - 1) * ENEMY_LV_PER_STAGE); }
function stageEnemySkillLv(id) { return Math.min(10, 1 + Math.floor(id / ENEMY_SKILL_EVERY)); }
STAGES.forEach(function(s) {
  var k = stageSm(s.id);
  s.sm = k < 1 ? { hp: k, atk: k } : { hp: Math.round(Math.pow(k, ENEMY_HP_EXP) * 100) / 100, atk: Math.round(Math.pow(k, ENEMY_ATK_EXP) * 100) / 100 };
  // 총원(tot)이 실제로 나올 수 있는 수(출현 목록 + 보스)보다 크면 마지막 적이 영원히 나오지 않아 클리어 불가 → 맞춤
  // (39·49·74~79·81~89·91·96 스테이지 등이 이 상태였음)
  var spawnable = s.en.length + (s.boss ? 1 : 0);
  if (s.tot > spawnable) s.tot = spawnable;
});
STAGES.forEach(function(s) {
  var cap = Math.min(STAGE_TOT_CAP_MAX, Math.round(STAGE_TOT_CAP_BASE + STAGE_TOT_CAP_PER * s.id));
  if (s.boss) cap = Math.min(cap, STAGE_TOT_CAP_BOSS);
  if (s.tot > cap) {
    var ratio = s.tot / cap;
    s.sm = { hp: Math.round(s.sm.hp * Math.pow(ratio, STAGE_COMP_HP) * 100) / 100, atk: Math.round(s.sm.atk * Math.pow(ratio, STAGE_COMP_ATK) * 100) / 100 };
    var need = cap - (s.boss ? 1 : 0), src = s.en, out = [];
    for (var i = 0; i < need; i++) out.push(src[Math.floor(i * src.length / need)]);
    s.en = out; s.tot = cap;
  }
  s.spw = Math.max(s.spw, Math.ceil(s.tot / STAGE_MAX_WAVES));
});

// 보스 이름: 언어 파일 stages.boss_<스테이지>, 없으면 데이터의 한국어 이름
function bossName(st) {
  if (!st || !st.boss) return '';
  var k = 'stages.boss_' + st.id, v = typeof t === 'function' ? t(k) : null;
  return v && v !== k ? v : st.boss.name;
}

// STAGES 배열 데이터 확장
STAGES = STAGES.map(function(stage) {
  var composition = getEnemyComposition(stage.en);
  return Object.assign({}, stage, {
    difficulty: calculateDifficulty(stage),
    recommendedLevel: Math.ceil(stage.id * 0.15),
    enemyComposition: composition,
    recommendedClasses: recommendCounters(composition),
    strategyTips: generateStrategyTips(stage)
  });
});
