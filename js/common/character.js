// js/common/character.js — 캐릭터 관련 유틸리티
// 캐릭터 조회, 경험치, 등급 계산 등을 중앙화합니다

// ── 캐릭터 조회 ────────────────────────────
function getChar(uid) {
  const roster = getRoster();
  return roster.chars.find(c => c.uid === uid);
}

// ── 경험치 관련 ────────────────────────────
function expForLevel(lv) {
  return 80 + 20 * lv + 5 * lv * lv;
}

function gainExp(uid, amount) {
  const roster = getRoster();
  const ch = roster.chars.find(c => c.uid === uid);
  if (!ch || ch.lv >= MAX_LEVEL) {
    return { leveled: 0, prevLv: ch ? ch.lv : 0 };
  }

  const prevLv = ch.lv;
  ch.exp = (ch.exp || 0) + amount;
  let leveled = 0;

  while (ch.lv < MAX_LEVEL) {
    const need = expForLevel(ch.lv);
    if (ch.exp < need) break;
    ch.exp -= need;
    ch.lv++;
    ch.hp = Math.round(ch.hp + ch.pot.hp);
    ch.atk = Math.round(ch.atk + ch.pot.atk);
    ch.def = Math.round(ch.def + ch.pot.def);
    leveled++;
  }

  if (ch.lv >= MAX_LEVEL) ch.exp = 0;
  saveRoster(roster);
  return { leveled, prevLv };
}

// ── 등급 관련 ────────────────────────────
function potGrade(ch) {
  const g = JAB[ch.cls].growth;
  const scores = ['hp', 'atk', 'def'].map(k => {
    const mn = g[k][0], mx = g[k][1], rng = mx - mn;
    return rng > 0 ? (ch.pot[k] - mn) / rng : 0.5;
  });
  const avg = scores.reduce((a, b) => a + b, 0) / scores.length;
  if (avg >= 0.85) return 'S';
  if (avg >= 0.65) return 'A';
  if (avg >= 0.35) return 'B';
  return 'C';
}

function gradeMultiplier(grade) {
  switch (grade) {
    case 'S': return 1.1;
    case 'A': return 1.0;
    case 'B': return 0.9;
    default: return 0.8;
  }
}

// ── 잠재력 롤 ────────────────────────────
function _rollPotential(cls) {
  const g = JAB[cls].growth;
  const roll = mm => +(mm[0] + Math.random() * (mm[1] - mm[0])).toFixed(1);
  const rollActionRec = () => +(0.05 + Math.random() * 0.15).toFixed(2);
  return { hp: roll(g.hp), atk: roll(g.atk), def: roll(g.def), actionRec: rollActionRec() };
}

function _rollPotentialWithGrade(cls, targetGrade) {
  const g = JAB[cls].growth;
  const targetMin = targetGrade === 'S' ? 0.85 : targetGrade === 'A' ? 0.65 : targetGrade === 'B' ? 0.35 : 0;
  const targetMax = targetGrade === 'S' ? 1.0 : targetGrade === 'A' ? 0.85 : targetGrade === 'B' ? 0.65 : 0.35;

  for (let attempt = 0; attempt < 100; attempt++) {
    const pot = _rollPotential(cls);
    const scores = ['hp', 'atk', 'def'].map(k => {
      const mn = g[k][0], mx = g[k][1], rng = mx - mn;
      return rng > 0 ? (pot[k] - mn) / rng : 0.5;
    });
    const avg = scores.reduce((a, b) => a + b, 0) / scores.length;
    if (avg >= targetMin && avg < targetMax) return pot;
  }

  // Fallback: 범위 중간값
  const mid = (targetMin + targetMax) / 2;
  return {
    hp: +(g.hp[0] + (g.hp[1] - g.hp[0]) * mid).toFixed(1),
    atk: +(g.atk[0] + (g.atk[1] - g.atk[0]) * mid).toFixed(1),
    def: +(g.def[0] + (g.def[1] - g.def[0]) * mid).toFixed(1),
    actionRec: +(0.05 + Math.random() * 0.15).toFixed(2)
  };
}

// ── 스킬 관련 ────────────────────────────
function getCharSkillLv(ch, skillId) {
  if (ch.skillLv && ch.skillLv[skillId]) return ch.skillLv[skillId];
  // 습득형 스킬은 0, 기본 스킬은 1
  if (typeof LEARNABLE_SKILLS !== 'undefined' && LEARNABLE_SKILLS[skillId]) return 0;
  return 1;
}

function getCharSkills(cls) {
  const sk = SKILLS[cls];
  if (!sk) return [];
  let arr = Array.isArray(sk) ? sk : [sk];

  // 습득형 스킬 추가
  if (typeof LEARNABLE_SKILLS !== 'undefined') {
    Object.keys(LEARNABLE_SKILLS).forEach(skId => {
      const lsk = LEARNABLE_SKILLS[skId];
      if (lsk.cls === cls) arr = arr.concat([lsk]);
    });
  }
  return arr;
}

// ── 캐릭터 추가 ────────────────────────────
function addChar(cls, nameId, pot, gender) {
  const d = JAB[cls];
  if (!d) return null;

  const roster = getRoster();
  const ch = {
    uid: roster.nextId++,
    cls: cls,
    nameId: nameId,
    lv: 1,
    exp: 0,
    dead: false,
    hp: d.base.hp,
    atk: d.base.atk,
    def: d.base.def,
    move: d.base.move,
    range: d.base.range,
    pot: pot,
    actionRec: d.actionRec + (pot.actionRec || 0),
    gender: gender || (Math.random() < 0.5 ? 'm' : 'f')
  };

  roster.chars.push(ch);
  saveRoster(roster);
  return ch;
}
