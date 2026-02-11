// ═══════════════════════════════════════════
//  skills.js — 스킬 데이터 정의 & 헬퍼
//  전투 함수는 js/skills/_common.js로 이동
//  스킬 핸들러는 js/skills/{class}.js로 이동
// ═══════════════════════════════════════════

// ── 스킬 데이터 정의 ──────────────────────
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
	},
	knight_charge: {
		id: 'knight_charge', name: '차징', icon: '🐎',
		desc: '적에게 ATK×0.8 데미지 및 1턴 스턴 부여', cost: 5, costType: 'fury', chargeRange: 1,
		cls: 'knight'
	},
	knight_painshare: {
		id: 'knight_painshare', name: '고통 분담', icon: '💔',
		desc: '5칸 내 아군 피해의 1/3을 대신 받음', passive: true,
		cls: 'knight'
	},
	knight_sacrifice: {
		id: 'knight_sacrifice', name: '희생', icon: '🛡️',
		desc: '2턴간 지정 아군 피해를 100% 대신 받음', cost: 5, costType: 'fury', sacrificeRange: 5,
		cls: 'knight'
	},
	knight_capture: {
		id: 'knight_capture', name: '포획', icon: '🪝',
		desc: '5칸 내 적을 기사 인근으로 끌어옴', cost: 3, costType: 'fury', captureRange: 5,
		cls: 'knight'
	},
	knight_tenacity: {
		id: 'knight_tenacity', name: '강인한', icon: '💪',
		desc: 'HP 0 방지 + DEF 대폭 증가 (스테이지 1회)', passive: true,
		cls: 'knight'
	},
	warrior_cleave: {
		id: 'warrior_cleave', name: '휘두르기', icon: '🌀',
		desc: '인접 모든 적에게 ATK×1.2 데미지', cost: 3, costType: 'fury',
		cls: 'warrior'
	},
	warrior_assault: {
		id: 'warrior_assault', name: '강습', icon: '🦅',
		desc: '5칸 내 적에게 돌진, 인근 적에게 ATK×0.8 데미지', cost: 2, costType: 'fury', assaultRange: 5,
		cls: 'warrior'
	},
	warrior_bloodthirst: {
		id: 'warrior_bloodthirst', name: '피의 갈망', icon: '🩸',
		desc: 'HP 감소에 따라 ATK 최대 1.5배, 매턴 분노 +1', passive: true,
		cls: 'warrior'
	},
	warrior_criticalstrike: {
		id: 'warrior_criticalstrike', name: '치명적인 일격', icon: '🗡️',
		desc: '기본 공격 + 출혈 (3턴, ATK×0.2)', cost: 3, costType: 'fury',
		cls: 'warrior'
	},
	assassin_trapdetect: {
		id: 'assassin_trapdetect', name: '함정감지', icon: '👁️',
		desc: '2칸 내 함정 발견 및 해체', passive: true,
		cls: 'assassin'
	},
	sapper_excavate: {
		id: 'sapper_excavate', name: '굴착', icon: '⛏️',
		desc: '1칸 내 바위 파괴', cost: 50, costType: 'energy', excavateRange: 1,
		cls: 'sapper'
	},
	mage_freeze: {
		id: 'mage_freeze', name: '빙결', icon: '❄️',
		desc: '5칸 내 적 1인, ATK×1.2 + 2턴 빙결', cost: 50, costType: 'mana', freezeRange: 5,
		cls: 'mage'
	},
	mage_grandwall: {
		id: 'mage_grandwall', name: '그랜드 월', icon: '🧱',
		desc: '빈 타일에 불가통행 벽 설치', cost: 50, costType: 'mana', wallRange: 1,
		cls: 'mage'
	},
	archer_snipe: {
		id: 'archer_snipe', name: '저격', icon: '🎯',
		desc: '5~10칸 적 1인, ATK×1.5', cost: 100, costType: 'energy', snipeMin: 5, snipeMax: 10,
		cls: 'archer'
	},
	archer_rapidfire: {
		id: 'archer_rapidfire', name: '연속사격', icon: '🏹',
		desc: '5칸 내 적, 레벨에 따라 2~4회 ATK×0.8', cost: 50, costType: 'energy', rapidRange: 5,
		cls: 'archer'
	},
	archer_steelrain: {
		id: 'archer_steelrain', name: '강철비', icon: '🌧️',
		desc: '3×3 AoE, ATK×1.0', cost: 50, costType: 'energy',
		cls: 'archer'
	},
	archer_weakspot: {
		id: 'archer_weakspot', name: '약점포착', icon: '💢',
		desc: '치명타율 +30% (데미지 1.5배)', passive: true,
		cls: 'archer'
	},
	priest_purify: {
		id: 'priest_purify', name: '정화', icon: '💧',
		desc: '5칸 내 아군 1인 상태이상 해제', cost: 30, costType: 'mana', purifyRange: 5,
		cls: 'priest'
	},
	priest_sanctuary: {
		id: 'priest_sanctuary', name: '성역선포', icon: '✝️',
		desc: '6칸 내 아군 모두 4턴간 턴당 ATK×0.5 회복', cost: 80, costType: 'mana', sanctuaryRange: 6,
		cls: 'priest'
	},
	// ── Brawler 습득형 ──────────────────────
	brawler_flurry: {
		id: 'brawler_flurry', name: '연타', icon: '👊',
		desc: '인접 적 1인에게 3회 ATK×0.6 연속 공격', cost: 40, costType: 'energy',
		cls: 'brawler'
	},
	brawler_crush: {
		id: 'brawler_crush', name: '파쇄', icon: '💥',
		desc: '인접 적 1인의 방어력을 무시하고 ATK×1.0 데미지', cost: 50, costType: 'energy',
		cls: 'brawler'
	},
	brawler_counter: {
		id: 'brawler_counter', name: '역습', icon: '🔁',
		desc: '피격 시 30% 확률로 ATK×0.5 반격', passive: true,
		cls: 'brawler'
	},
	// ── Lancer 습득형 ──────────────────────
	lancer_charge: {
		id: 'lancer_charge', name: '돌격', icon: '🐎',
		desc: '일직선 3칸 내 적에게 돌진 이동 후 ATK×1.2 공격', cost: 3, costType: 'fury', chargeRange: 3,
		cls: 'lancer'
	},
	lancer_phalanx: {
		id: 'lancer_phalanx', name: '방진', icon: '🛡️',
		desc: '2턴간 인접 2칸 이내 아군 전원 DEF +5', cost: 4, costType: 'fury', phalanxRange: 2,
		cls: 'lancer'
	},
	lancer_spearwall: {
		id: 'lancer_spearwall', name: '창벽', icon: '🔱',
		desc: '적이 인접 칸으로 이동 시 ATK×0.5 자동 공격 (턴당 1회)', passive: true,
		cls: 'lancer'
	},
	// ── Summoner 습득형 ────────────────────
	summoner_empower: {
		id: 'summoner_empower', name: '소환 강화', icon: '⬆️',
		desc: '자신의 소환수 1체를 3턴간 ATK×1.5로 강화', cost: 40, costType: 'mana', empowerRange: 5,
		cls: 'summoner'
	},
	summoner_soulburst: {
		id: 'summoner_soulburst', name: '영혼 폭발', icon: '💫',
		desc: '자신의 소환수를 희생, 소환수 기준 3×3 범위 적에게 소환수 ATK×3.0', cost: 60, costType: 'mana', burstRange: 5,
		cls: 'summoner'
	},
	summoner_soulbond: {
		id: 'summoner_soulbond', name: '영적 유대', icon: '🔗',
		desc: '소환수 소멸 시 마나 40 회복', passive: true,
		cls: 'summoner'
	},
	// ── Shaman 습득형 ──────────────────────
	shaman_poisonmist: {
		id: 'shaman_poisonmist', name: '독안개', icon: '☁️',
		desc: '대상 중심 3×3 범위에 독안개 설치, 3턴간 매턴 ATK×0.3 데미지', cost: 50, costType: 'mana', mistRange: 5,
		cls: 'shaman'
	},
	shaman_spiritsurge: {
		id: 'shaman_spiritsurge', name: '영혼 쇄도', icon: '👻',
		desc: '5칸 내 적 1인에게 ATK×1.0 데미지 + 1턴 이동 불가', cost: 40, costType: 'mana', surgeRange: 5,
		cls: 'shaman'
	},
	shaman_medium: {
		id: 'shaman_medium', name: '영매', icon: '🔮',
		desc: '채널링 중 피격으로 채널링이 해제되지 않음', passive: true,
		cls: 'shaman'
	},
	// ── Sapper 습득형 ──────────────────────
	sapper_detonate: {
		id: 'sapper_detonate', name: '폭파', icon: '🧨',
		desc: '5칸 내 아군 함정 1개를 즉시 폭발, 인접 적에게 함정 데미지×1.5', cost: 30, costType: 'energy', detonateRange: 5,
		cls: 'sapper'
	},
	sapper_enhancedtrap: {
		id: 'sapper_enhancedtrap', name: '강화 함정', icon: '⚙️',
		desc: '함정 데미지 30% 증가, 스턴 지속 +1턴', passive: true,
		cls: 'sapper'
	},
	// ── Mage 습득형 ────────────────────────
	mage_manasurge: {
		id: 'mage_manasurge', name: '마나 쇄도', icon: '🌊',
		desc: '마나 80% 이상 시 마법 데미지 20% 증가', passive: true,
		cls: 'mage'
	},
	// ── Priest 습득형 ──────────────────────
	priest_divinegrace: {
		id: 'priest_divinegrace', name: '신의 은총', icon: '🕊️',
		desc: '모든 회복량 20% 증가', passive: true,
		cls: 'priest'
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
