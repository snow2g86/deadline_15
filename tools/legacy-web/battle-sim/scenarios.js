// ═══════════════════════════════════════════
//  tools/battle-sim/scenarios.js — 황금 기록 시나리오 표
//
//  name   파일 이름 (godot/tests/golden/<name>.json)
//  seed   전투 난수 시드 (mulberry32). 준비(장비 생성)는 seed ^ 0x5eed5eed 로 따로 굴림
//  stage  { id } = STAGES 의 스테이지 / { daily: { cls, tier } } = Daily.buildStage. override 로 일부 값 바꿈
//  party  클랜원 [{ cls, lv, skills: { 스킬id: 레벨 }, gear: [장비 명세] }]  (uid 는 2 부터 순서대로, 1 은 지휘관)
//  items  인벤토리 [{ siege: id } | { potion: id, qty }]
//  policy 아군 정책 설정 (tools/battle-sim/policy.js OPTS_DEFAULT)
//  maxRounds 라운드 상한 (넘으면 'stalled' 로 끝냄, 기본 120)
//  ※ 시나리오를 바꾸면 기록이 바뀐다 — 바꾼 뒤 node tools/legacy-web/battle-sim.js 로 다시 만들고 2b 시험도 다시 확인
// ═══════════════════════════════════════════
'use strict';

// 직업별 습득형 스킬 전부 (js/skills.js LEARNABLE_SKILLS)
const LEARN = {
  warrior: ['warrior_cleave', 'warrior_assault', 'warrior_bloodthirst', 'warrior_criticalstrike'],
  knight: ['knight_charge', 'knight_painshare', 'knight_sacrifice', 'knight_capture', 'knight_tenacity'],
  assassin: ['assassin_trapdetect', 'assassin_smoke', 'assassin_ambush'],
  novice: ['novice_firstaid', 'novice_tackle', 'novice_grit'],
  sapper: ['sapper_excavate', 'sapper_detonate', 'sapper_enhancedtrap'],
  mage: ['mage_freeze', 'mage_grandwall', 'mage_manasurge'],
  archer: ['archer_snipe', 'archer_rapidfire', 'archer_steelrain', 'archer_weakspot'],
  priest: ['priest_purify', 'priest_sanctuary', 'priest_divinegrace'],
  brawler: ['brawler_flurry', 'brawler_crush', 'brawler_counter'],
  lancer: ['lancer_charge', 'lancer_phalanx', 'lancer_spearwall'],
  summoner: ['summoner_empower', 'summoner_soulburst', 'summoner_soulbond'],
  shaman: ['shaman_poisonmist', 'shaman_spiritsurge', 'shaman_medium'],
};
// 클랜원 명세: 모든 습득형 스킬을 lvSk 레벨로
const full = (cls, lv, lvSk, extra) => Object.assign({ cls, lv, skills: Object.fromEntries(LEARN[cls].map(k => [k, lvSk || 1])) }, extra || {});
const bare = (cls, lv, extra) => Object.assign({ cls, lv }, extra || {});
// 주입용 버프 (id 를 주면 BuffSystem 처럼 난수를 쓰지 않음)
const buff = (type, source, duration, value) => ({ id: 'inj_' + type, type, duration, value: value || 0, stacks: 1, source, icon: '', meta: {} });

module.exports = [
  // 균형 진형 + 만능 부대: 기사·사제·궁수·전사·마법사 (모든 습득 스킬). 밀림 방어전 — 독 환경 피해, 숲 회피, 물·여울, 성문·성벽
  { name: 'balanced_s05', seed: 1005, desc: '균형 진형+만능 부대, 밀림 방어전(독 피해·숲·여울·성문), 정화 대상 주입(기사 무장해제)',
    stage: { id: 5 }, inject: [{ ally: 0, set: { disarmed: 3 } }], party: [full('knight', 3), full('priest', 3), full('archer', 3), full('warrior', 3), full('mage', 3)] },

  // 외인부대 5인(창술사·주술사·소환사·공병·무투가) + 만능 부대: 화산 공격전 — 용암 화상, 화상 지속 피해, 냉기 결계(3라운드마다 이동)
  { name: 'legion5_s09', seed: 2009, desc: '외인부대 5인, 화산(용암·화상·냉기 결계 이동), 소환·독안개·함정',
    stage: { id: 9 }, party: [full('lancer', 5), full('shaman', 5), full('summoner', 5), full('sapper', 5), full('brawler', 5)] },

  // 암살자 3인(직업 셋 조합) + 무투가·사제: 숲 많은 밀림 공격전 — 은신 겹침 암살, 연막, 습격
  { name: 'assassins_s06', seed: 3006, desc: '암살자 3인 조합, 밀림 공격전(은신·암살·습격·연막)',
    stage: { id: 6 }, party: [full('assassin', 4), full('assassin', 4), full('assassin', 4), full('brawler', 4), full('priest', 4)] },

  // 전사 5인(단일 직업 조합 + 돌격대): 협곡 방어전 — 언덕 사거리, 돌풍(사거리 -1)
  { name: 'mono_warrior_s03', seed: 4003, desc: '전사 단일 조합(공격 ×2·방어 ×0.5)+돌격대, 협곡(언덕·돌풍)',
    stage: { id: 3 }, party: [full('warrior', 2), full('warrior', 2), full('warrior', 2), full('warrior', 2), full('warrior', 2)] },

  // 기사 셋 + 창술사(철옹성) + 궁수: 얼음 방어전 — 적 기사 밀치기·포획(넉백 저항 70%), 투사체 차단, 엄호
  { name: 'knights_s11', seed: 5011, desc: '기사 셋+철옹성, 얼음 방어전(넉백 저항·투사체 차단·엄호·밀치기)',
    stage: { id: 11 }, policy: { shoveEvery: 2 },
    party: [full('knight', 8), full('knight', 8), full('knight', 8), full('lancer', 8), full('archer', 8)] },

  // 보스 스테이지 10 (화산 공격전, 도적 우두머리)
  { name: 'boss_s10', seed: 6010, desc: '보스 스테이지(도적 우두머리), 화산 공격전',
    stage: { id: 10 }, party: [full('knight', 9), full('priest', 9), full('mage', 9), full('warrior', 9), full('archer', 9)] },

  // 요일 던전 (마법사, 보통: 밀림, 적 강함 = 스테이지 30)
  { name: 'daily_mage_normal', seed: 7001, desc: '요일 던전 마법사·보통(밀림, 강함 30), 조각 보상',
    stage: { daily: { cls: 'mage', tier: 1 } }, party: [full('knight', 12), full('priest', 12), full('archer', 12), full('assassin', 12), full('mage', 12)] },

  // 지옥 맵 (스테이지 19 공격전, 지옥불 + 냉기 결계)
  { name: 'abyss_s19', seed: 8019, desc: '지옥(지옥불 지속 피해·냉기 결계 3라운드마다 이동), 공격전',
    stage: { id: 19 }, party: [full('knight', 12, 2), full('priest', 12, 2), full('mage', 12, 2), full('lancer', 12, 2), full('summoner', 12, 2)] },

  // 패배: 1레벨 노비스 5명(노비스 단일 조합) vs 스테이지 30
  { name: 'loss_s30', seed: 9030, desc: '패배 사례: 1레벨 노비스 단일 조합 vs 스테이지 30',
    stage: { id: 30 }, party: [full('novice', 1), full('novice', 1), full('novice', 1), full('novice', 1), full('novice', 1)] },

  // 교착: 방어 태세만 하는 정책, 라운드 상한 6 → 'stalled' (자동 플레이 tools/autoplay.js 의 250라운드 항복과 같은 역할)
  { name: 'stall_passive_s02', seed: 1102, desc: '교착 상한: 방어 태세만(정책 passive), 6라운드를 넘으면 stalled',
    stage: { id: 2 }, maxRounds: 6, policy: { passive: true },
    party: [bare('knight', 10), bare('knight', 10), bare('lancer', 10), bare('knight', 10), bare('lancer', 10)] },

  // 공성 아이템(다리·폭탄·사다리)·전투 물약, 요새 공격전 (성벽은 위쪽 0행). 공병 셋(직업 셋 조합) — 굴착·폭파
  { name: 'siege_items_s13', seed: 1213, desc: '아군 공성 아이템·물약, 요새 공격전, 공병 셋(굴착·함정·폭파)',
    stage: { id: 13 }, items: [{ siege: 'siege_bridge' }, { siege: 'siege_bomb' }, { siege: 'siege_ladder' }, { potion: 'potion_heal', qty: 2 }, { potion: 'potion_atk_buff' }, { potion: 'potion_resource', qty: 2 }],
    party: [full('sapper', 10), full('sapper', 10), full('sapper', 10), full('knight', 10), full('priest', 10)] },

  // 장비 효과: 전설(왕의 인장 파티 공격·성자의 눈물·시간의 귀걸이 선공·용비늘 화염 면역), 기사 세트 공명, 공격 마법부여
  { name: 'gear_s15', seed: 1329, desc: '장비 효과(전설·직업 세트 공명·공격 마법부여 6종), 폐허(회복 감소·저주 마법부여). 기사는 일반 공격만',
    stage: { id: 15 }, policy: { attackOnly: ['knight'] },
    party: [
      full('knight', 12, 1, { gear: [{ set: 'knight', slot: 'helmet', rarity: 'epic', enchant: 'curse' }, { set: 'knight', slot: 'armor', rarity: 'epic' }, { set: 'knight', slot: 'boots', rarity: 'epic' }, { legend: 'saint_tear' }] }),
      full('knight', 12, 1, { gear: [{ set: 'knight', slot: 'helmet', rarity: 'rare', enchantAtk: 'thunder' }, { set: 'knight', slot: 'armor', rarity: 'rare' }, { set: 'knight', slot: 'boots', rarity: 'rare' }, { legend: 'unyielding', enchantAtk: 'sunder' }] }),
      // 공격 마법부여 6종을 모두 이 기사에게 (일반 공격만 하므로 매번 발동)
      full('knight', 12, 1, { gear: [{ legend: 'time_earring' }, { legend: 'king_seal', enchant: 'curse', enchantAtk: 'sunder' }, { tpl: 'wpn_knight', rarity: 'epic', enchantAtk: 'flame' },
        { tpl: 'necklace_power', rarity: 'rare', enchantAtk: 'thunder' }, { tpl: 'leather_cap', rarity: 'rare', enchantAtk: 'vamp' }, { tpl: 'leather_boots', rarity: 'rare', enchantAtk: 'venom' },
        { tpl: 'leather_armor', rarity: 'rare', enchantAtk: 'frost' }] }),
      full('archer', 12, 1, { gear: [{ legend: 'whisper', enchantAtk: 'frost' }, { set: 'archer', slot: 'helmet', rarity: 'epic', enchantAtk: 'venom' }, { set: 'archer', slot: 'armor', rarity: 'epic', enchantAtk: 'vamp' }] }),
      full('mage', 12, 1, { gear: [{ legend: 'starfall' }, { legend: 'sage_robe', enchant: 'curse' }, { tpl: 'ring_power', rarity: 'epic' }] }),
    ] },

  // 연습 모드 (골드 60%, 전사자 자동 부활): 협곡 방어전, 포격진(원거리 3) — 궁수·마법사·주술사
  { name: 'practice_s04', seed: 1404, desc: '연습 모드, 포격진(원거리 3), 협곡 방어전',
    stage: { id: 4 }, practice: true, policy: { stance: 'overwatch' },
    party: [full('archer', 3), full('mage', 3), full('shaman', 3), full('knight', 3), full('novice', 3)] },

  // 궁수 5인(명사수대: 사거리 +1) 사막 공격전 — 열기(이동 -1), 언덕 많음
  { name: 'mono_archer_s07', seed: 1507, desc: '궁수 단일 조합(사거리 +1), 사막(이동 -1·언덕)',
    stage: { id: 7 }, party: [full('archer', 5), full('archer', 5), full('archer', 5), full('archer', 5), full('archer', 5)] },

  // 첫 클리어 보상(신규 클랜원) + 대기 정책: 평지 방어전 스테이지 2
  { name: 'firstclear_s02', seed: 1602, desc: '첫 클리어 보상(신규 클랜원)·별점, 대기 위주 정책, 이동 취소(2차례마다), 평지 방어전',
    stage: { id: 2 }, policy: { stance: 'wait', shoveEvery: 3, undoEvery: 2 },
    party: [full('novice', 1), full('warrior', 1), full('brawler', 1), full('lancer', 1), full('shaman', 1)] },

  // 늪(독기) 방어전 스테이지 21 — 소환사 둘·주술사 둘·사제 (소환 강화·영혼 폭발·영적 유대)
  { name: 'swamp_s21', seed: 1721, desc: '늪 방어전(독기 4%), 소환사·주술사 둘씩, 영혼 폭발·영적 유대',
    stage: { id: 21 }, party: [full('summoner', 13, 3), full('summoner', 13, 3), full('shaman', 13, 3), full('shaman', 13, 3), full('priest', 13, 3)] },

  // 패배 (보스): 레벨 20 전사·기사·노비스·무투가·공병 vs 지옥 혼합전 스테이지 45 (보스 심연의 기사)
  { name: 'loss_boss_s45', seed: 1845, desc: '패배 사례(보스 심연의 기사, 지옥 혼합전)',
    stage: { id: 45 }, party: [full('warrior', 20, 3), full('knight', 20, 3), full('novice', 20, 3), full('brawler', 20, 3), full('sapper', 20, 3)] },

  // 긴 전투 훈련 1·2: 비싼 스킬(무투가 파쇄·연타, 공병 폭파, 노비스 응급처치, 기사 희생·스위치, 전사 치명적인 일격)까지 돌려 쓰도록
  //  무투가·공병은 시작 자원 100 주입 (일반 전투는 짧아 비싼 스킬까지 자원이 모이지 않음)
  { name: 'drill_s35', seed: 7, desc: '스킬 훈련: 요새 혼합전 35, 무투가·공병 시작 자원 100 주입',
    stage: { id: 35 }, inject: [{ ally: 3, set: { res: 100 } }, { ally: 4, set: { res: 100 } }],
    party: [full('warrior', 20, 3), full('knight', 20, 3), full('novice', 20, 3), full('brawler', 20, 3), full('sapper', 20, 3)] },
  { name: 'drill_s28', seed: 2, desc: '스킬 훈련: 스테이지 28, 무투가·공병 시작 자원 100 주입 (응급처치)',
    stage: { id: 28 }, inject: [{ ally: 3, set: { res: 100 } }, { ally: 4, set: { res: 100 } }],
    party: [full('warrior', 15, 3), full('knight', 15, 3), full('novice', 15, 3), full('brawler', 15, 3), full('sapper', 15, 3)] },

  // 성문 돌파 패배: 암살자 5명에게 은신(연막) 버프를 주입하고 제자리(hold) → 적이 클랜원을 못 보고 성문으로 감
  //  돌파 패배 판정은 chkEnd 에서만 하므로(이동만으로는 판정 안 됨) 돌파 한도를 넘긴 뒤 옆의 적을 쳐서 chkEnd 가 불리게 함
  //  (eMv '대상 없으면 성문 접근' → 해자 함정 → 성문 공격·파괴 → 돌파·성벽 오르기). 해자(3,13)·(4,13)에 클랜원 함정 주입
  { name: 'gate_breach_s01', seed: 1901, desc: '성문 공격·파괴·돌파 패배, 함정 밟힘 (은신 버프·함정 주입, 제자리 정책)',
    stage: { id: 1 }, policy: { hold: 'breach' }, maxRounds: 40,
    inject: [0, 1, 2, 3, 4].map(i => ({ ally: i, set: { buffs: [buff('stealth', 'assassin_smoke', 999)] } }))
      .concat([{ store: { traps: [{ x: 3, y: 13, team: 'ally', dmg: 20, stun: 2 }, { x: 4, y: 13, team: 'ally', dmg: 20, stun: 2 }] } }]),
    party: [bare('assassin', 3), bare('assassin', 3), bare('assassin', 3), bare('assassin', 3), bare('assassin', 3)] },

  // 드문 규칙 주입: 기사 HP 12(적 전사 처형 대상)·1(방어막 없이 — 어떤 피해든 강인한 발동), 나머지 클랜원 방어막 버프(적 공격 시 shield_active),
  //  시작 적 하나 FURY_BUFF 버프(fury_triggered), 시작 적 전사 분노 10 (ai.js tryUseSkill 처형)
  { name: 'edge_inject_s11', seed: 5111, desc: '주입으로만 닿는 규칙: 강인한·방어막(shield_active)·FURY_BUFF(fury_triggered)·적 전사 처형',
    stage: { id: 11 },
    inject: [{ ally: 0, set: { hp: 12 } }, { ally: 1, set: { hp: 1 } }].concat([0, 2, 3, 4].map(i => ({ ally: i, set: { buffs: [buff('shield', 'siege', 99, 0.5)] } })))
      .concat([{ enemy: 0, set: { buffs: [buff('fury_buff', 'fury', 99, 1.5)] } }, { enemyCls: 'warrior', set: { res: 10 } }]),
    party: [full('knight', 8), full('knight', 8), full('knight', 8), full('lancer', 8), full('archer', 8)] },

  // 장비 개편 전 세이브(gv 없음): 전투 준비의 첫 loadInventory 가 Gear.migrate 로 옵션·강화 옵션을 전투 난수로 다시 굴림
  //  (옛 무기 이름 → 직업 무기, 방어구 직업 제한, +10 고유 옵션 칸, 이미 가진 효과 제외). legacy: 옛 templateId 또는 true(그대로)
  { name: 'legacy_gear_s08', seed: 2108, desc: '옛 장비(gv 없음) 전환: Gear.migrate·rollEnhanceOpt 가 전투 준비 중 난수 사용 (+10·+7·+4·+2)',
    stage: { id: 8 },
    party: [
      full('knight', 6, 1, { gear: [{ tpl: 'wpn_knight', rarity: 'epic', legacy: 'sword_1h', enhanceLv: 10 }, { tpl: 'plate_helm', rarity: 'rare', legacy: true, enhanceLv: 4 }] }),
      full('warrior', 6, 1, { gear: [{ tpl: 'wpn_warrior', rarity: 'rare', legacy: 'greatsword', enhanceLv: 7 }, { tpl: 'plate_armor', rarity: 'epic', legacy: true, enhanceLv: 2 }] }),
      full('archer', 6, 1, { gear: [{ tpl: 'wpn_archer', rarity: 'rare', legacy: 'bow', enhanceLv: 3 }, { tpl: 'ring_power', rarity: 'uncommon', legacy: true }] }),
      full('priest', 6, 1, { gear: [{ tpl: 'wpn_priest', rarity: 'uncommon', legacy: 'mace' }] }),
      full('mage', 6, 1, { gear: [{ tpl: 'wpn_mage', rarity: 'rare', legacy: 'staff', enhanceLv: 9 }, { tpl: 'cloth_robe', rarity: 'rare', enchant: 'fire' }] }),
    ] },
];
