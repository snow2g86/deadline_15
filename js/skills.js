// ═══════════════════════════════════════════
//  skills.js — 스킬 정의 & 패시브 트리거
//  새 스킬 추가 시 이 파일만 수정
// ═══════════════════════════════════════════

// ── 스킬 데이터 정의 ──────────────────────
// 향후 액티브 스킬 추가 시 여기에 등록
const SKILLS = {
  // warrior: { id:'warrior_rage', name:'강타', cost:10, costType:'fury', ... },
  // tanker:  { id:'tanker_taunt', name:'도발', cost:10, costType:'fury', ... },
  // assassin:{ id:'assassin_ambush', name:'암습', cost:60, costType:'energy', ... },
  // mage:    { id:'mage_fireball', name:'화염폭발', cost:60, costType:'mana', ... },
  // archer:  { id:'archer_pierce', name:'관통사격', cost:45, costType:'energy', ... },
  // priest:  { id:'priest_aoe_heal', name:'집단 치유', cost:50, costType:'mana', ... },
};

// ── 패시브: 분노 MAX 트리거 ───────────────
// 분노 10 도달 시 클래스별 자동 발동
const FURY_PASSIVES = {
  warrior: {
    name: '광폭',
    icon: '💢',
    desc: '2턴간 공격 데미지 1.5배',
    trigger(defender, attacker, G) {
      defender.furyBuff = 2;
      defender.res = 0;
      G.floatT(defender.x, defender.y, '광폭 발동!', 'heal');
      G.vfxSpawn(
        G.uSX(defender.x, defender.y) + 20,
        G.uSY(defender.x, defender.y) + 10,
        { count: 15, colors: ['#ff4400','#ff8800','#ffcc00'], shape: 'spark',
          speed: 4, spread: 14, decay: 0.025, size: 4 }
      );
    }
  },
  tanker: {
    name: '몸부림',
    icon: '🔥',
    desc: '인접 공격자에게 ATK×50% 반격',
    trigger(defender, attacker, G) {
      if (mh(attacker.x, attacker.y, defender.x, defender.y) > 1) return; // 인접만
      const cd = Math.max(1, Math.round(defender.atk * 0.5) - attacker.def);
      attacker.hp = Math.max(0, attacker.hp - cd);
      G.floatT(attacker.x, attacker.y, `-${cd}`, 'damage');
      G.shakeU(attacker.id);
      G.sfxAtk(defender.cls);
      G.vfxSpawn(
        G.uSX(attacker.x, attacker.y) + 20,
        G.uSY(attacker.x, attacker.y) + 10,
        { count: 10, colors: ['#ff8800','#ffcc44','#fff'], shape: 'spark',
          speed: 3, spread: 10, decay: 0.03, size: 3 }
      );
      defender.res = 0;
      G.floatT(defender.x, defender.y, '몸부림!', 'heal');
    }
  }
};

// ── 데미지 계산 ───────────────────────────
// 모든 공격 데미지는 이 함수를 통해 계산
function calcDmg(attacker, target) {
  let dmg = Math.max(1, attacker.atk - target.def);
  // 광폭 버프 적용
  if (attacker.furyBuff > 0) dmg = Math.max(1, Math.round(dmg * 1.5));
  return dmg;
}

// ── 분노 처리 (공격 후) ──────────────────
// 공격자/방어자 분노 증감 + MAX 트리거
function procFury(attacker, target, G) {
  // 공격자: 분노 +1
  if (attacker.resType === 'fury') {
    attacker.res = Math.min(attacker.maxRes, attacker.res + 1);
  }
  // 방어자: 분노 +2 (생존 시)
  if (target.hp > 0 && target.resType === 'fury') {
    target.res = Math.min(target.maxRes, target.res + 2);
    // MAX 도달 → 패시브 트리거
    if (target.res >= target.maxRes) {
      const passive = FURY_PASSIVES[target.cls];
      if (passive) passive.trigger(target, attacker, G);
    }
  }
}

// ── 턴 시작 버프 틱 ──────────────────────
// 매 턴 시작 시 호출: 버프 카운트다운
function tickBuffs(unit) {
  if (unit.furyBuff > 0) unit.furyBuff--;
  // 향후 추가 버프/디버프 틱은 여기에
}

// ── 버프 아이콘 목록 ─────────────────────
// getBuffs에서 호출: 스킬 관련 버프 아이콘 반환
function getSkillBuffs(unit) {
  const buffs = [];
  // 분노 MAX 표시
  if (unit.resType === 'fury' && unit.res >= unit.maxRes) {
    buffs.push({ icon: '🔥', type: 'buff', turns: 0 });
  }
  // 광폭 활성 표시
  if (unit.furyBuff > 0) {
    buffs.push({ icon: '💢', type: 'buff', turns: unit.furyBuff });
  }
  // 향후 추가 버프 아이콘은 여기에
  return buffs;
}
