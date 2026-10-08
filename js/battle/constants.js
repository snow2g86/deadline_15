// ═══════════════════════════════════════════
//  battle/constants.js — Constants, Utilities, localStorage, AI Profiles
// ═══════════════════════════════════════════

// ════════════════════════════════════════════
//  Section 1: Constants & Utilities
// ════════════════════════════════════════════

// 맵: 가로 8 × 세로 15. 세로 양 끝에 서로의 진형 (아래 11~12행 클랜원, 위 0~1행 적; 방어전은 13행 해자·14행 성벽)
const COLS = 8, ROWS = 15, TW = 48, TH = 24;
const MID_C = COLS / 2;   // 가운데 두 열은 MID_C-1, MID_C
// 유닛: UI=캐릭터 아이콘 폭, UW/UH=유닛 컨테이너, UCX/UCY=이펙트 기준점(몸통 중심), UOY=타일 기준 컨테이너 상단 오프셋
const ZH = 10, UI = 52, UW = 64, UH = 78, UCX = 32, UCY = 30, UOY = 40;
const DEPLOY = [{ x: 3, y: 12 }, { x: 4, y: 12 }, { x: 2, y: 12 }, { x: 5, y: 12 }, { x: 3, y: 11 }, { x: 4, y: 11 }, { x: 2, y: 11 }, { x: 5, y: 11 }, { x: 1, y: 12 }, { x: 6, y: 12 }];
// 진형 열 순서: 가운데부터 바깥으로 (가로 8칸 기준 3,4,2,5,1,6)
const FORM_COLS = [MID_C - 1, MID_C, MID_C - 2, MID_C + 1, MID_C - 3, MID_C + 2];
const CLAB = ['N', 'E', 'S', 'W'], CARR = ['▲', '▶', '▼', '◀'];

function mh(a, b, c, d) { return Math.abs(a - c) + Math.abs(b - d) }
function shuffle(a) { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1));[a[i], a[j]] = [a[j], a[i]] } }
function sl(ms) { return new Promise(r => setTimeout(r, ms * (GameStore._sett.speed || 1))) }
// 적 차례 연출 대기 배율 — 적이 많은 후반에 적 턴이 늘어지지 않게 (명중 시점과 맞물린 대기에는 쓰지 않음)
const ENEMY_TURN_PACE = 0.6;
function slE(ms) { return sl(ms * ENEMY_TURN_PACE); }

// ════════════════════════════════════════════
//  Section 2: Storage & Battle-specific functions
//  (Common utilities loaded from js/common/*.js)
// ════════════════════════════════════════════

function killExp(stageId, enemyCls) {
    const base = KILL_EXP[0] + stageId * KILL_EXP[1];   // js/common/constants.js
    const bonus = { knight: 1.3, mage: 1.2, summoner: 1.2, shaman: 1.2, assassin: 1.1, priest: 1.1, brawler: 1.1, lancer: 1.1, sapper: 1.1, novice: 1, warrior: 1, archer: 1 };
    return Math.floor(base * (bonus[enemyCls] || 1));
}
function actExp(stageId, action) {
    const base = { move: 2, attack: 5, heal: 6 };
    return Math.floor((base[action] || 0) * (1 + stageId * 0.1));
}

function loadGoldData() {
  try {
    const d = JSON.parse(localStorage.getItem(SAVE_KEY));
    if(d) return { gold: d.gold||0, cleared: new Set(d.cleared||[]) };
    return { gold: 2000, cleared: new Set() };
  } catch(e) { return { gold: 2000, cleared: new Set() } }
}
function toBattleStats(uid) {
  const ch = getChar(uid);
  if(!ch) return null;
  const d = JAB[ch.cls];
  const names = t('character.names');
  if(!ch.equip) ch.equip={weapon:null,offhand:null,helmet:null,armor:null,boots:null,necklace:null,earring:null,ring:null};
  const eq = typeof calcEquipBonus==='function' ? calcEquipBonus(ch) : {hp:0,atk:0,def:0,move:0,range:0};
  return {
    uid: ch.uid, cls: ch.cls, lv: ch.lv,
    name: ch.customName || (names && names[ch.nameId]) || d.icon,
    hp: ch.hp+eq.hp, mhp: ch.hp+eq.hp, atk: ch.atk+eq.atk, def: ch.def+eq.def,
    move: Math.min(ch.move+eq.move,6), range: Math.min(ch.range+eq.range,5),
    role: ROLE_MAP[ch.cls],
    res: d.res === 'mana' ? d.maxRes : 0,
    maxRes: d.maxRes, resType: d.res, resRec: d.resRec,
    actionRec: ch.actionRec || d.actionRec || 1.0,
    skillLv: ch.skillLv || {},
    gender: ch.gender || 'm',
    enchants: typeof Hazard !== 'undefined' ? Hazard.enchantsOf(ch) : [],   // 장비 마법부여 (환경 디버프 저항)
  };
}

// Battle-specific: Mark character as dead
function markDead(uid) {
  try {
    const roster = getRoster();
    const ch = roster.chars.find(c => c.uid === uid);
    if (ch && ch.cls === COMMANDER_CLS) return; // 지휘관은 패배로 끝나므로 사망 처리하지 않음
    if(ch) {
      ch.dead = true;
      ch.diedAt = Date.now();
      saveRoster(roster);
    }
  } catch(e) {}
}
function saveBattle(data) { try { localStorage.setItem('game_battle', JSON.stringify(data)) } catch(e) {} }
function loadBattle() { try { const r = localStorage.getItem('game_battle'); return r ? JSON.parse(r) : null } catch(e) { return null } }
function clearBattle() { try { localStorage.removeItem('game_battle') } catch(e) {} }

// ════════════════════════════════════════════
//  Section 4: AI Profiles
// ════════════════════════════════════════════

const AI_PROFILES = {
  warrior: { style: 'aggressive', targetPriority: 'low_hp', advanceBonus: 10, retreatThreshold: 0.2, skillUseProbability: 0.7 },
  assassin: { style: 'aggressive', targetPriority: 'low_hp', advanceBonus: 15, retreatThreshold: 0.25, skillUseProbability: 0.8 },
  brawler: { style: 'aggressive', targetPriority: 'random_weak', advanceBonus: 12, retreatThreshold: 0.15, skillUseProbability: 0.6 },
  mage: { style: 'aggressive', targetPriority: 'cluster', advanceBonus: 5, retreatThreshold: 0.4, skillUseProbability: 0.75, keepDistance: true },
  sapper: { style: 'aggressive', targetPriority: 'nearest', advanceBonus: 8, retreatThreshold: 0.3, skillUseProbability: 0.9, trapPlacement: true },
  knight: { style: 'defensive', targetPriority: 'nearest_threat', advanceBonus: -5, retreatThreshold: 0.1, skillUseProbability: 0.5, guardMode: true },
  lancer: { style: 'defensive', targetPriority: 'nearest_threat', advanceBonus: -3, retreatThreshold: 0.15, skillUseProbability: 0.65, guardMode: true },
  priest: { style: 'support', targetPriority: 'never', advanceBonus: -10, retreatThreshold: 0.5, skillUseProbability: 0.0, keepDistance: true, avoidCombat: true },
  shaman: { style: 'support', targetPriority: 'random', advanceBonus: -8, retreatThreshold: 0.45, skillUseProbability: 0.0, keepDistance: true, avoidCombat: true },
  novice: { style: 'balanced', targetPriority: 'nearest', advanceBonus: 0, retreatThreshold: 0.3, skillUseProbability: 0.4 },
  archer: { style: 'balanced', targetPriority: 'low_hp', advanceBonus: 2, retreatThreshold: 0.35, skillUseProbability: 0.5, keepDistance: true },
  summoner: { style: 'balanced', targetPriority: 'random', advanceBonus: 0, retreatThreshold: 0.4, skillUseProbability: 0.0, keepDistance: true }
};

const AI_MISTAKE_CHANCE = 0.3;

// ── 엄호(Cover): 탱커가 아군 앞을 막으면 뒤의 아군은 일반 공격 대상이 될 수 없다 ──
const GUARD_CLASSES = ['knight'];          // 엄호를 제공하는 직업
const COVER_IGNORE_CLASSES = ['assassin']; // 엄호·제압 구역을 무시하는 직업
// ── 투사체 차단: 원거리(투사체) 공격은 엄호 대신, 지나가는 길에 선 대상 편 기사가 피해 일부로 대신 맞는다 ──
const PROJECTILE_CLASSES = ['archer', 'mage', 'commander', 'priest', 'summoner', 'shaman', 'summon_spirit'];
// ── 도움닫기: 궁수·도적(암살자)은 같은 편 바로 뒤에서 그 동료를 딛고 넘어 일직선으로 최대 VAULT_DIST칸 더 이동 (이동력과 별도) ──
const VAULT_CLASSES = ['archer', 'assassin'], VAULT_DIST = 2;

// ── 전술 보너스 (데미지 배율 가산) ──
const TACTIC = {
  back: 0.30,      // 대상의 등 뒤에서 공격
  side: 0.15,      // 대상의 옆에서 공격
  pincer: 0.20,    // 대상 반대편에 같은 편이 붙어 있음 (협공)
  high: 0.15,      // 언덕에서 언덕 아닌 곳을 공격 (고지대)
  highRange: 1,    // 언덕 위 원거리 유닛 사거리 보너스
  forestEvade: 0.15, // 숲 위 유닛의 일반 공격 회피 확률
  cap: 0.40,       // 후방·측면·협공·고지대 합산 상한 (+40%)
  shallowVuln: 0.20, // 여울(얕은 물)에 선 유닛이 받는 피해 증가 (상한과 별도)
  lavaBurn: 0.06,  // 용암 옆에서 행동을 마치면 최대 HP 비율 화상 피해 (사망하지 않음)
};

// ── 전술 행동 ──
// 밀치기: 인접한 적을 1칸 밀어냄. 막히면 충돌 피해(공격력 비율), 유닛과 부딪히면 둘 다 피해
// 방어 태세: 다음 자기 차례까지 방어력 배율 + 후방·측면 보너스 무효
// 경계: 다음 자기 차례까지, 사거리 안으로 처음 들어온 적을 선제 공격 (피해 배율)
const TACTICS_ACT = { shoveCollide: 0.5, shoveUnit: 0.3, defendDef: 1.5, overwatchMul: 0.8, interceptMul: 0.5 };  // interceptMul: 투사체를 대신 맞은 기사가 받는 피해 배율

// ── 넉백 저항: 밀치기·끌어오기 같은 강제 이동을 이 확률로 버팀 (버티면 이동·충돌 피해 없음) ──
const KNOCK_RESIST = { knight: 0.70 };

// ── 지원 공격(연계): 일반 공격 후 대상 바로 옆의 같은 편이 추가 타격 ──
const SUPPORT = { chance: 0.40, mul: 0.50 };

// ── 리소스 UI 상수 ──
const RES_LABEL = { mana: 'MP', energy: 'EP', fury: 'FP' };
const RES_COLOR = { mana: '#4488ff', energy: '#f0c040', fury: '#ff6644' };
