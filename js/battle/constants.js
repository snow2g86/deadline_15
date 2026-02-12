// ═══════════════════════════════════════════
//  battle/constants.js — Constants, Utilities, localStorage, AI Profiles
// ═══════════════════════════════════════════

// ════════════════════════════════════════════
//  Section 1: Constants & Utilities
// ════════════════════════════════════════════

const COLS = 10, ROWS = 15, TW = 48, TH = 24;
const ZH = 10, UW = 48, UH = 60, UCX = 24, UCY = 12;
const DEPLOY = [{ x: 4, y: 12 }, { x: 5, y: 12 }, { x: 3, y: 12 }, { x: 6, y: 12 }, { x: 4, y: 11 }, { x: 5, y: 11 }, { x: 3, y: 11 }, { x: 6, y: 11 }, { x: 7, y: 12 }, { x: 7, y: 11 }];
const CLAB = ['N', 'E', 'S', 'W'], CARR = ['▲', '▶', '▼', '◀'];

function mh(a, b, c, d) { return Math.abs(a - c) + Math.abs(b - d) }
function shuffle(a) { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1));[a[i], a[j]] = [a[j], a[i]] } }
function sl(ms) { return new Promise(r => setTimeout(r, ms * G._sett.speed)) }

// ════════════════════════════════════════════
//  Section 2: Storage & Battle-specific functions
//  (Common utilities loaded from js/common/*.js)
// ════════════════════════════════════════════

function killExp(stageId, enemyCls) {
    const base = 10 + stageId * 5;
    const bonus = { knight: 1.3, mage: 1.2, summoner: 1.2, shaman: 1.2, assassin: 1.1, priest: 1.1, brawler: 1.1, lancer: 1.1, sapper: 1.1, novice: 1, warrior: 1, archer: 1 };
    return Math.floor(base * (bonus[enemyCls] || 1));
}
function actExp(stageId, action) {
    const base = { move: 2, attack: 5, heal: 6 };
    return Math.floor((base[action] || 0) * (1 + stageId * 0.2));
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
    skillLv: ch.skillLv || {},
    gender: ch.gender || 'm'
  };
}

// Battle-specific: Mark character as dead
function markDead(uid) {
  try {
    const roster = getRoster();
    const ch = roster.find(c => c.uid === uid);
    if(ch) {
      ch.dead = true;
      ch.diedAt = Date.now();
      saveRoster({ chars: roster, nextId: Math.max(...roster.map(c=>c.uid||0))+1 });
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
