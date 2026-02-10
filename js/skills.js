// ═══════════════════════════════════════════
//  skills.js — 스킬 정의 & 패시브 트리거
//  새 스킬 추가 시 이 파일만 수정
// ═══════════════════════════════════════════

// ── 스킬 데이터 정의 ──────────────────────
// 향후 액티브 스킬 추가 시 여기에 등록
const SKILLS = {
  warrior: {
    id: 'warrior_powersmash', name: '강타', icon: '⚡',
    desc: '공격력 1.5배의 데미지로 공격', cost: 3, costType: 'fury'
  },
  knight: {
    id: 'knight_switch', name: '스위치', icon: '🔄',
    desc: '이동 범위 내 아군과 위치 교환', cost: 1, costType: 'fury', switchRange: 2
  },
  archer: {
    id: 'archer_dash', name: '도약', icon: '💨',
    desc: '이동 범위의 1.5배를 즉각 이동', cost: 20, costType: 'energy', dashRange: 4
  },
  lancer: {
    id: 'lancer_pierce', name: '관통', icon: '🔱',
    desc: '일직선 3칸 관통 데미지', cost: 5, costType: 'fury', pierceLen: 3
  },
  assassin: {
    id: 'assassin_assassinate', name: '암살', icon: '💀',
    desc: '은신 겹침 상태에서 ATK×5 즉사급 공격', cost: 60, costType: 'energy'
  },
  priest: {
    id: 'priest_massheal', name: '집단 치유', icon: '✨',
    desc: '6칸 내 모든 아군 체력 회복', cost: 50, costType: 'mana', healRange: 6
  },
  sapper: {
    id: 'sapper_trap', name: '함정 설치', icon: '⚠',
    desc: 'ATK×2 피해 + 2턴 이동불가 함정 설치', cost: 20, costType: 'energy', trapRange: 1
  },
  mage: {
    id: 'mage_fireburst', name: '화염폭발', icon: '🔥',
    desc: '대상 중심 3×3 범위 적 전체에 공격', cost: 40, costType: 'mana'
  },
  novice: {
    id: 'novice_throw', name: '돌던지기', icon: '🪨',
    desc: '4칸 내 적에게 ATK×0.5 데미지', cost: 15, costType: 'energy', throwRange: 4
  },
  brawler: {
    id: 'brawler_disarm', name: '무장해제', icon: '🤛',
    desc: '1칸 내 적 공격력 3턴간 50% 감소', cost: 30, costType: 'energy', disarmRange: 1
  },
  shaman: [
    { id: 'shaman_curse', name: '쇠약의 저주', icon: '☠️',
      desc: '매턴 적 1명에게 최대HP 0.5% 피해(보스 0.2%). 해제까지 이동/행동 불가', cost: 100, costType: 'mana' },
    { id: 'shaman_exalt', name: '고양', icon: '🔺',
      desc: '전체 아군 데미지 25% 증가. 해제까지 이동/행동 불가', cost: 50, costType: 'mana' }
  ],
  // ═════ 소환사 스킬 (2가지 소환 타입) ═════
  summoner: [
    { id: 'summoner_summon_spirit', name: '정령소환', icon: '✨',
      desc: '원거리 마법 공격 정령 소환 (5턴, 공격력 50%)', cost: 80, costType: 'mana', summonRange: 3, summonType: 'summon_spirit' },
    { id: 'summoner_summon_golem', name: '골램소환', icon: '🗿',
      desc: '근접 공격 골램 소환 (5턴, HP/DEF 120%, 공격력 50%)', cost: 80, costType: 'mana', summonRange: 3, summonType: 'summon_golem' }
  ]
};

// ── 습득형 스킬 (스킬북으로만 습득 가능) ────
const LEARNABLE_SKILLS = {
  assassin_ambush: {
    id: 'assassin_ambush', name: '습격', icon: '⚡',
    desc: '2칸 범위 적 대상, 인접 이동 후 ATK×2 공격', cost: 40, costType: 'energy', ambushRange: 2,
    cls: 'assassin'
  }
};

// ── 다중 스킬 헬퍼 ────────────────────────
function getSkills(cls) {
  const sk = SKILLS[cls];
  return !sk ? [] : Array.isArray(sk) ? sk : [sk];
}

// ── 유닛 전체 스킬 (기본 + 습득형) ─────────
function getUnitSkills(u) {
  var skills = getSkills(u.cls).slice();
  Object.keys(LEARNABLE_SKILLS).forEach(function(skId) {
    var lsk = LEARNABLE_SKILLS[skId];
    if (lsk.cls === u.cls && u.skillLv && u.skillLv[skId] >= 1) {
      skills.push(lsk);
    }
  });
  return skills;
}

// ── 은신 판정 ──────────────────────────────
function isStealthed(u) {
  return u.cls === 'assassin' && G.ter[u.y] && G.ter[u.y][u.x] === 'forest';
}

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
      G.floatT(defender.x, defender.y, t('passives.fury_activated'), 'heal');
      G.vfxSpawn(
        G.uSX(defender.x, defender.y) + UCX,
        G.uSY(defender.x, defender.y) + UCY,
        { count: 15, colors: ['#ff4400','#ff8800','#ffcc00'], shape: 'spark',
          speed: 4, spread: 14, decay: 0.025, size: 4 }
      );
    }
  },
  knight: {
    name: '철의 의지',
    icon: '🛡️',
    desc: '2턴간 방어력 1.5배',
    trigger(defender, attacker, G) {
      defender.defBuff = 2;
      defender.res = 0;
      G.floatT(defender.x, defender.y, t('passives.iron_will_activated'), 'heal');
      G.vfxSpawn(
        G.uSX(defender.x, defender.y) + UCX,
        G.uSY(defender.x, defender.y) + UCY,
        { count: 15, colors: ['#4488ff','#88bbff','#ffffff'], shape: 'spark',
          speed: 3, spread: 12, decay: 0.025, size: 4 }
      );
    }
  }
};

// ── 데미지 계산 ───────────────────────────
// 모든 공격 데미지는 이 함수를 통해 계산
function calcDmg(attacker, target) {
  let atk = attacker.atk;
  // 무장해제 디버프: ATK 50% 감소
  if (attacker.disarmed > 0) atk = Math.round(atk * 0.5);
  let def = target.def;
  // 철의 의지 버프: DEF 1.5배
  if (target.defBuff > 0) def = Math.round(def * 1.5);
  let dmg = Math.max(1, atk - def);
  // 광폭 버프 적용
  if (attacker.furyBuff > 0) dmg = Math.max(1, Math.round(dmg * 1.5));
  // 고양 버프: 같은 팀 주술사가 고양 채널링 중이면 +25%
  if (G.units.some(u => u.team === attacker.team && u.hp > 0 && u.channeling === 'shaman_exalt')) {
    dmg = Math.max(1, Math.round(dmg * 1.25));
  }
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
  if (unit.defBuff > 0) unit.defBuff--;
  if (unit.disarmed > 0) unit.disarmed--;
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
  // 철의 의지 활성 표시
  if (unit.defBuff > 0) {
    buffs.push({ icon: '🛡️', type: 'buff', turns: unit.defBuff });
  }
  // 무장해제 디버프 표시
  if (unit.disarmed > 0) {
    buffs.push({ icon: '🤛', type: 'debuff', turns: unit.disarmed });
  }
  // 채널링 표시
  if (unit.channeling === 'shaman_curse') {
    buffs.push({ icon: '☠️', type: 'debuff', turns: 0 });
  }
  if (unit.channeling === 'shaman_exalt') {
    buffs.push({ icon: '🔺', type: 'buff', turns: 0 });
  }
  // 고양 버프 수혜 표시 (채널링 주술사 본인 제외)
  if (!unit.channeling && G.units.some(u => u.team === unit.team && u.hp > 0 && u.channeling === 'shaman_exalt')) {
    buffs.push({ icon: '🔺', type: 'buff', turns: 0 });
  }
  // 소환수 지속 시간 표시
  if (unit.isSummon && unit.summonTurns !== undefined) {
    buffs.push({ icon: '⏳', type: 'buff', turns: unit.summonTurns });
  }
  return buffs;
}
