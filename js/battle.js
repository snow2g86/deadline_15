// ═══════════════════════════════════════════
//  battle.js — Standalone battle module
//  Consolidates: core, combat, skills, render,
//  ui, vfx, audio, ai, and battle-related lobby/boot
// ═══════════════════════════════════════════

// ════════════════════════════════════════════
//  Section 1: Constants & Utilities
// ════════════════════════════════════════════

const COLS = 10, ROWS = 15, TW = 48, TH = 24;
const ZH = 10, UW = 48, UH = 60, UCX = 24, UCY = 12;
const MIN_P = 5, MAX_P = 5;
const DEPLOY = [{ x: 4, y: 12 }, { x: 5, y: 12 }, { x: 3, y: 12 }, { x: 6, y: 12 }, { x: 4, y: 11 }, { x: 5, y: 11 }, { x: 3, y: 11 }, { x: 6, y: 11 }, { x: 7, y: 12 }, { x: 7, y: 11 }];
const CLAB = ['N', 'E', 'S', 'W'], CARR = ['▲', '▶', '▼', '◀'];

function mh(a, b, c, d) { return Math.abs(a - c) + Math.abs(b - d) }
function shuffle(a) { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1));[a[i], a[j]] = [a[j], a[i]] } }
function sl(ms) { return new Promise(r => setTimeout(r, ms * G._sett.speed)) }

const MAX_LEVEL = 15;
function expForLevel(lv) { return 80 + 20 * lv + 5 * lv * lv }
function killExp(stageId, enemyCls) {
    const base = 10 + stageId * 5;
    const bonus = { knight: 1.3, mage: 1.2, summoner: 1.2, shaman: 1.2, assassin: 1.1, priest: 1.1, brawler: 1.1, lancer: 1.1, sapper: 1.1, novice: 1, warrior: 1, archer: 1 };
    return Math.floor(base * (bonus[enemyCls] || 1));
}
function actExp(stageId, action) {
    const base = { move: 2, attack: 5, heal: 6 };
    return Math.floor((base[action] || 0) * (1 + stageId * 0.2));
}

function clsIcon(cls, size) {
    const d = JAB[cls]; if (!d) return '';
    return `<span class="cls-icon" style="font-size:${size}px">${d.icon}</span>`;
}

const ROLE_MAP = {
  warrior:'melee', knight:'melee', assassin:'melee', brawler:'melee', lancer:'melee', sapper:'melee', novice:'melee',
  archer:'ranged', mage:'ranged', summoner:'ranged', shaman:'ranged',
  priest:'healer',
  summon_spirit:'ranged', summon_golem:'melee'
};

// ════════════════════════════════════════════
//  Section 2: localStorage access functions
// ════════════════════════════════════════════

function loadNav() { try { return JSON.parse(localStorage.getItem('game_nav')) } catch(e) { return null } }
function clearNav() { try { localStorage.removeItem('game_nav') } catch(e) {} }
function loadParty() { try { const r = localStorage.getItem('game_party'); return r ? JSON.parse(r) : [] } catch(e) { return [] } }
function loadGoldData() {
  try {
    const d = JSON.parse(localStorage.getItem('game_save'));
    if(d) return { gold: d.gold||0, cleared: new Set(d.cleared||[]) };
    return { gold: 2000, cleared: new Set() };
  } catch(e) { return { gold: 2000, cleared: new Set() } }
}
function saveGold(gold, clearedArr) {
  try { localStorage.setItem('game_save', JSON.stringify({ gold, cleared: clearedArr })) } catch(e) {}
}
function getRoster() {
  try { const d = JSON.parse(localStorage.getItem('game_roster')); return d ? d.chars : [] } catch(e) { return [] }
}
function saveRoster(chars, nextId) {
  try { localStorage.setItem('game_roster', JSON.stringify({ chars, nextId })) } catch(e) {}
}
function getChar(uid) { return getRoster().find(c => c.uid === uid) }
function markDead(uid) {
  try {
    const d = JSON.parse(localStorage.getItem('game_roster'));
    if(!d) return;
    const ch = d.chars.find(c => c.uid === uid);
    if(ch) { ch.dead = true; localStorage.setItem('game_roster', JSON.stringify(d)) }
  } catch(e) {}
}
function gainExp(uid, amount) {
  try {
    const d = JSON.parse(localStorage.getItem('game_roster'));
    if(!d) return { leveled:0, prevLv:1 };
    const ch = d.chars.find(c => c.uid === uid);
    if(!ch || ch.lv >= MAX_LEVEL) return { leveled:0, prevLv: ch ? ch.lv : 1 };
    const prevLv = ch.lv;
    ch.exp = (ch.exp||0) + amount;
    let leveled = 0;
    while(ch.lv < MAX_LEVEL) {
      const need = expForLevel(ch.lv);
      if(ch.exp < need) break;
      ch.exp -= need;
      ch.lv++;
      ch.hp = Math.round(ch.hp + ch.pot.hp);
      ch.atk = Math.round(ch.atk + ch.pot.atk);
      ch.def = Math.round(ch.def + ch.pot.def);
      leveled++;
    }
    if(ch.lv >= MAX_LEVEL) ch.exp = 0;
    localStorage.setItem('game_roster', JSON.stringify(d));
    return { leveled, prevLv };
  } catch(e) { return { leveled:0, prevLv:1 } }
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
function saveBattle(data) { try { localStorage.setItem('game_battle', JSON.stringify(data)) } catch(e) {} }
function loadBattle() { try { const r = localStorage.getItem('game_battle'); return r ? JSON.parse(r) : null } catch(e) { return null } }
function clearBattle() { try { localStorage.removeItem('game_battle') } catch(e) {} }

// ════════════════════════════════════════════
//  Section 4: AI Profiles (from ai.js)
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

// ════════════════════════════════════════════
//  Section 5: G Object (core.js)
// ════════════════════════════════════════════

const G = {
    ter: [], units: [], nid: 1, turn: 1, phase: 'player',
    sel: null, mvT: [], atkT: [], healT: [],
    awPM: false, skillMode: false, preMv: null, over: false, anim: false,
    cStage: null, eSpwn: 0, eQ: [], cleared: new Set(),
    party: [], camDir: 0, battleExp: {}, traps: [], eFormPos: [],

    g2v(c, r) {
        switch (this.camDir) {
            case 0: return { vc: c, vr: r }; case 1: return { vc: ROWS - 1 - r, vr: c };
            case 2: return { vc: COLS - 1 - c, vr: ROWS - 1 - r }; case 3: return { vc: r, vr: COLS - 1 - c }
        }
    },
    v2g(vc, vr) {
        switch (this.camDir) {
            case 0: return { c: vc, r: vr }; case 1: return { c: vr, r: ROWS - 1 - vc };
            case 2: return { c: COLS - 1 - vc, r: ROWS - 1 - vr }; case 3: return { c: COLS - 1 - vr, r: vc }
        }
    },
    vDim() { return this.camDir % 2 === 0 ? { c: COLS, r: ROWS } : { c: ROWS, r: COLS } },
    isoX(vc, vr) { return (vc - vr) * TW + this.vDim().r * TW },
    isoY(vc, vr, z) { return (vc + vr) * TH - (z || 0) * ZH },
    isoHit(px, py) {
        const d = this.vDim(), oX = d.r * TW;
        const fvc = ((px - oX) / TW + (py) / TH) / 2;
        const fvr = ((py) / TH - (px - oX) / TW) / 2;
        let best = null, bestD = Infinity;
        for (let dvc = -1; dvc <= 1; dvc++)for (let dvr = -1; dvr <= 1; dvr++) {
            const vc = Math.floor(fvc) + dvc, vr = Math.floor(fvr) + dvr;
            if (vc < 0 || vr < 0 || vc >= d.c || vr >= d.r) continue;
            const cx = this.isoX(vc, vr) + TW, cy = this.isoY(vc, vr, 0) + TH;
            const dx = Math.abs(px - cx) / TW, dy = Math.abs(py - cy) / TH;
            if (dx + dy <= 1) {
                const dist = dx + dy;
                if (dist < bestD) { bestD = dist; const g = this.v2g(vc, vr); best = { c: g.c, r: g.r } }
            }
        }
        return best;
    },
    tSX(c, r) { const v = this.g2v(c, r); return this.isoX(v.vc, v.vr) },
    tSY(c, r, z) { const v = this.g2v(c, r); return this.isoY(v.vc, v.vr, z) },
    uSX(c, r) { return this.tSX(c, r) + TW - UCX },
    uSY(c, r) { const t = this.ter[r] ? this.ter[r][c] : null; return this.tSY(c, r, t ? TI[t].z : 0) - 22 },

    rotCam(d) {
        this.camDir = ((this.camDir + d) % 4 + 4) % 4;
        document.querySelector('#cam-dir .cd-arrow').textContent = CARR[this.camDir];
        document.querySelector('#cam-dir .cd-label').textContent = CLAB[this.camDir];
        document.querySelectorAll('.unit-sprite').forEach(el => el.style.transition = 'none');
        this.layW(); this.rTer(); this.rUnits();
        this.units.forEach(u => { if (u._gdx || u._gdy) this._applyFace(u.id) });
        this.rMM();
        requestAnimationFrame(() => requestAnimationFrame(() => {
            document.querySelectorAll('.unit-sprite').forEach(el => el.style.transition = '');
        }));
        if (this.awPM && this.sel) this.showAM(this.sel);
    },
    layW() {
        const d = this.vDim(), wW = (d.c + d.r) * TW + 4, wH = (d.c + d.r) * TH + 80;
        const w = document.getElementById('iso-world'); w.style.width = wW + 'px'; w.style.height = wH + 'px';
        const ct = document.getElementById('map-container'), cW = ct.clientWidth, cH = ct.clientHeight;
        w.style.left = Math.max(0, (cW - wW) / 2) + 'px'; w.style.top = Math.max(0, (cH - wH) / 2) + 'px';
        const cv = document.getElementById('vfx-canvas'); if (cv) { cv.width = wW; cv.height = wH }
    },

    init() {
        this.genT(); this._initTColors(); this.units = []; this.nid = 1; this.turn = 1; this.phase = 'player';
        this.sel = null; this.over = false; this.awPM = false; this.skillMode = false; this.skillMenuOpen = false; this.anim = false; this.camDir = 0;
        this.breached = 0; this.battleExp = {}; this.allyPos = {}; this.traps = []; this.eFormPos = [];
        document.querySelector('#cam-dir .cd-arrow').textContent = CARR[0];
        document.querySelector('#cam-dir .cd-label').textContent = CLAB[0];
        const w = document.getElementById('iso-world');
        w.querySelectorAll('.iso-tile,.unit-sprite,.float-text').forEach(e => e.remove());
        const meleeCols = [3, 4, 5, 6, 7], rangedCols = [3, 4, 5, 6, 7]; let meleeIdx = 0, rangedIdx = 0;
        for (let i = 0; i < this.party.length; i++) {
            const uid = this.party[i], ch = getChar(uid); if (!ch) continue;
            const role = ROLE_MAP[ch.cls], isRanged = role === 'ranged' || role === 'healer', cols = isRanged ? rangedCols : meleeCols, idx = isRanged ? rangedIdx++ : meleeIdx++;
            if (idx < cols.length) { const x = cols[idx], y = isRanged ? 12 : 11; this.addU('ally', uid, x, y) }
        }
        this.spawnW(); this.layW(); this.vfxInit(); this.rTer(); this.rUnits(); this.uUI(); this.defI(); this.rMM();
        this.bgmStart();
        setTimeout(() => this.scrollToAllies(), 50)
    },
    scrollToAllies() {
        const al = this.alive('ally'); if (!al.length) return;
        let sx = 0, sy = 0; al.forEach(u => { sx += this.uSX(u.x, u.y); sy += this.uSY(u.x, u.y) });
        sx /= al.length; sy /= al.length;
        const ct = document.getElementById('map-container');
        const w = document.getElementById('iso-world');
        const oL = parseFloat(w.style.left || 0), oT = parseFloat(w.style.top || 0);
        ct.scrollLeft = oL + sx - ct.clientWidth / 2 + UCX;
        ct.scrollTop = oT + sy - ct.clientHeight / 2 + UCX;
    },
    scrollToUnit(u) {
        const ct = document.getElementById('map-container');
        const w = document.getElementById('iso-world');
        const oL = parseFloat(w.style.left || 0), oT = parseFloat(w.style.top || 0);
        const ux = this.uSX(u.x, u.y) + UCX, uy = this.uSY(u.x, u.y) + UCY * 2;
        const tX = oL + ux - ct.clientWidth / 2, tY = oT + uy - ct.clientHeight / 2;
        ct.scrollTo({ left: tX, top: tY, behavior: 'smooth' });
    },
    eFormation(enemies, boss) {
        const form = [];
        let knights = [], melee = [], ranged = [], heal = [], sappers = [];
        enemies.forEach(cls => {
            const role = ROLE_MAP[cls];
            if (cls === 'knight') knights.push(cls);
            else if (role === 'melee') melee.push(cls);
            else if (role === 'ranged') ranged.push(cls);
            else if (role === 'healer') heal.push(cls);
            if (cls === 'sapper') sappers.push(cls)
        });
        const frontLine = [];
        for (let c = 2; c <= 7; c++) { if (!this.uAt(c, 11) && frontLine.length < (knights.length + melee.length)) frontLine.push({ x: c, y: 11 }) }
        let idx = 0;
        knights.forEach(k => { if (idx < frontLine.length) form.push({ cls: k, pos: frontLine[idx++] }) });
        melee.forEach(m => { if (idx < frontLine.length) form.push({ cls: m, pos: frontLine[idx++] }) });
        const midLine = [];
        for (let c = 2; c <= 7; c++) { if (!this.uAt(c, 12) && midLine.length < ranged.length + heal.length + sappers.length) midLine.push({ x: c, y: 12 }) }
        idx = 0;
        ranged.forEach(r => { if (idx < midLine.length) form.push({ cls: r, pos: midLine[idx++] }) });
        heal.forEach(h => { if (idx < midLine.length) form.push({ cls: h, pos: midLine[idx++] }) });
        sappers.forEach(s => { if (idx < midLine.length) form.push({ cls: s, pos: midLine[idx++] }) });
        if (boss) { form.push({ cls: boss.cls, pos: { x: 5, y: 2 }, isBoss: true }) }
        return form
    },
    genT() {
        this.ter = []; this.gateHP = {}; this.wallHP = {}; this.breached = 0;
        const wallRow = (row) => {
            const r = []; for (let c = 0; c < COLS; c++) {
                if (c >= 2 && c <= 3 || c >= 6 && c <= 7) { r.push('wall'); this.wallHP[c + ',' + row] = 200 }
                else if (c >= 4 && c <= 5) { r.push('gate'); this.gateHP[c + ',' + row] = 2 }
                else r.push('water')
            } return r
        };
        const moatRow = () => {
            const r = []; for (let c = 0; c < COLS; c++) {
                if (c >= 4 && c <= 5) r.push('plain'); else r.push('water')
            } return r
        };
        for (let r = 0; r < ROWS; r++) {
            if (r === 14) { this.ter[r] = wallRow(r) }
            else if (r === 13) { this.ter[r] = moatRow() }
            else if (r <= 1 || r >= 11) {
                this.ter[r] = []; for (let c = 0; c < COLS; c++)this.ter[r][c] = 'plain'
            }
            else {
                const theme = MAP_THEMES[(this.cStage && this.cStage.mapType) || 'plains'];
                const d = theme.dist;
                this.ter[r] = []; for (let c = 0; c < COLS; c++) {
                    const rn = Math.random(); let acc = 0;
                    this.ter[r][c] = (acc+=d.rock,rn<acc)?'rock':(acc+=d.hill,rn<acc)?'hill':(acc+=d.forest,rn<acc)?'forest':(acc+=(d.water||0),rn<acc)?'water':'plain'
                }
            }
        }
    },
    _initTColors() {
        const theme = MAP_THEMES[(this.cStage && this.cStage.mapType) || 'plains'];
        this._tColors = {};
        for (const tp in TI) {
            this._tColors[tp] = theme.colors[tp]
                ? { tc: theme.colors[tp].tc, lc: theme.colors[tp].lc, rc: theme.colors[tp].rc }
                : { tc: TI[tp].tc, lc: TI[tp].lc, rc: TI[tp].rc };
        }
    },
    addU(team, src, x, y) {
        let cls, hp, mhp, atk, def, mv, rng, role, resType, maxRes, resRec, initRes, uid = 0, lv = 1, name = '', gender = 'm';
        if (team === 'ally' && typeof src === 'number') {
            const bs = toBattleStats(src);
            if (!bs) return null;
            cls = bs.cls; hp = bs.hp; mhp = bs.mhp; atk = bs.atk; def = bs.def; mv = bs.move; rng = bs.range;
            role = bs.role; resType = bs.resType; maxRes = bs.maxRes; resRec = bs.resRec; initRes = bs.res; uid = bs.uid; lv = bs.lv; name = bs.name; gender = bs.gender || 'm';
        } else {
            cls = src; const d = JAB[cls], s = this.cStage;
            hp = d.base.hp; atk = d.base.atk; def = d.base.def; mv = d.base.move; rng = d.base.range;
            role = ROLE_MAP[cls]; resType = d.res; maxRes = d.maxRes; resRec = d.resRec;
            if (team === 'enemy' && s) { hp = Math.round(hp * s.sm.hp); atk = Math.round(atk * s.sm.atk) }
            mhp = hp; initRes = d.res === 'mana' ? maxRes : 0; name = t('classes.' + cls);
            gender = Math.random() < 0.5 ? 'm' : 'f';
        }
        const u = {
            id: this.nid++, uid, team, cls, lv, x, y, hp, mhp, atk, def, move: mv, range: rng, role, name, gender,
            res: initRes, maxRes, resType, resRec,
            hm: false, ha: false, waited: false, mo: false, furyBuff: 0, defBuff: 0, stunned: 0
        };
        if (team === 'enemy') { u.origSpawn = { x, y } }
        this.units.push(u); return u
    },
    uAt(x, y) {
        const all = this.units.filter(u => u.x === x && u.y === y && u.hp > 0);
        if (all.length <= 1) return all[0] || null;
        return all.find(u => u.team === 'enemy') || all[0]
    },
    alive(t) { return this.units.filter(u => u.team === t && u.hp > 0) },
    chkTrap(u) {
        const enemy = u.team === 'ally' ? 'enemy' : 'ally';
        const trap = this.traps.find(t => t.x === u.x && t.y === u.y && t.team === enemy);
        if (trap) {
            u.hp = Math.max(0, u.hp - trap.dmg); u.stunned = Math.max(u.stunned, 2);
            this.traps = this.traps.filter(t => t !== trap);
            this.floatT(u.x, u.y, `함정! -${trap.dmg}`, 'damage'); this.floatT(u.x, u.y, '2턴 이동불가', 'damage');
            this.vfxSpawn(this.uSX(u.x, u.y) + UCX, this.uSY(u.x, u.y) + UCY, { count: 8, colors: ['#f84', '#f80', '#ff4'], shape: 'spark', speed: 3, spread: 8, decay: 0.03, size: 2 });
            return true
        }
        return false
    },

    spawnW() {
        if (!this.cStage) return; const s = this.cStage, rem = s.tot - this.eSpwn; if (rem <= 0) return;
        const cnt = Math.min(s.spw, rem, this.eQ.length);
        if (this.eSpwn === 0 && s.boss) {
            const bu = this.addU('enemy', s.boss.cls, 5, 2);
            if (bu) { bu.isBoss = true; bu.name = s.boss.name; bu.origSpawn = { x: 5, y: 2 }; } this.eSpwn++;
            const posL = [[2, 4], [3, 4], [4, 4], [5, 4], [6, 4], [7, 4], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3]];
            let pidx = 0;
            while (this.eSpwn < cnt && pidx < posL.length && this.eQ.length) {
                const c = this.eQ.shift(); if (!c) break;
                const p = posL[pidx++];
                if (!this.uAt(p[0], p[1])) { this.addU('enemy', c, p[0], p[1]); this.eSpwn++ }
            }
        } else {
            const op = [];
            for (let c = 0; c < COLS; c++)if (!this.uAt(c, 0)) op.push({ x: c, y: 0 });
            if (op.length < cnt) for (let c = 0; c < COLS; c++)if (!this.uAt(c, 1)) op.push({ x: c, y: 1 });
            shuffle(op);
            for (let i = 0; i < Math.min(cnt, op.length); i++) {
                const c = this.eQ.shift(); if (!c) break;
                this.addU('enemy', c, op[i].x, op[i].y); this.eSpwn++
            }
        }
    },

    mvC(u) {
        if (u.stunned > 0) return []; const res = [], vis = new Map(), q = [{ x: u.x, y: u.y, c: 0 }], K = (a, b) => a + ',' + b;
        const isStealth = u.cls === 'assassin' && u.team === 'ally' && this.ter[u.y] && this.ter[u.y][u.x] === 'forest';
        vis.set(K(u.x, u.y), 0);
        while (q.length) {
            const { x, y, c } = q.shift();
            const occ = this.uAt(x, y);
            if (c > 0 && !occ) res.push({ x, y });
            if (c > 0 && occ && occ.team !== u.team && isStealth && this.ter[y] && this.ter[y][x] === 'forest') res.push({ x, y });
            for (const [dx, dy] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) {
                const nx = x + dx, ny = y + dy;
                if (nx < 0 || nx >= COLS || ny < 0 || ny >= ROWS) continue; const ti = TI[this.ter[ny][nx]]; if (!ti.pass) continue;
                const o = this.uAt(nx, ny);
                if (o && o.team !== u.team) {
                    if (isStealth && this.ter[ny][nx] === 'forest') {
                        const nc = c + ti.cost; if (nc <= u.move) { const k = K(nx, ny); if (!vis.has(k) || vis.get(k) > nc) { vis.set(k, nc) } }
                    }
                    continue
                }
                const nc = c + ti.cost; if (nc > u.move) continue;
                const k = K(nx, ny); if (!vis.has(k) || vis.get(k) > nc) { vis.set(k, nc); q.push({ x: nx, y: ny, c: nc }) }
            }
        } return res
    },
    atkC(u) { const c = []; for (let r = 0; r < ROWS; r++)for (let x = 0; x < COLS; x++)if (mh(u.x, u.y, x, r) <= u.range && !(x === u.x && r === u.y)) c.push({ x, y: r }); return c },
    eMvC(u) {
        const res = [], vis = new Map(), q = [{ x: u.x, y: u.y, c: 0 }], K = (a, b) => a + ',' + b; vis.set(K(u.x, u.y), 0);
        while (q.length) {
            const { x, y, c } = q.shift();
            const occ = this.uAt(x, y); if (c > 0 && !occ) res.push({ x, y });
            for (const [dx, dy] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) {
                const nx = x + dx, ny = y + dy;
                if (nx < 0 || nx >= COLS || ny < 0 || ny >= ROWS) continue; const ti = TI[this.ter[ny][nx]]; if (!ti.pass) continue;
                const o = this.uAt(nx, ny); if (o && o.team !== u.team) continue;
                const nc = c + ti.cost; if (nc > u.move) continue;
                const k = K(nx, ny); if (!vis.has(k) || vis.get(k) > nc) { vis.set(k, nc); q.push({ x: nx, y: ny, c: nc }) }
            }
        } return res
    },

};

// ════════════════════════════════════════════
//  Section 5a: Combat (from combat.js)
// ════════════════════════════════════════════

Object.assign(G, {
	selU(u) {
		if (this.phase !== 'player' || this.over || this.anim || this.awPM) return;
		if (u.team === 'ally' && u.ha && !u.waited) return;
		if (u.team === 'ally' && u.waited) {
			u.ha = false; u.waited = false;
			this.sel = u; this.awPM = true; this.mvT = [];
			if (u.channeling) { this.atkT = []; this.healT = [] }
			else {
				const a = this.atkC(u);
				if (u.role === 'healer') { this.atkT = []; this.healT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'ally' && v.hp < v.mhp && v.id !== u.id }) }
				else { this.atkT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'enemy' }); this.healT = [] }
			}
			this.rTer(); this.rUnits(); this.showAM(u); this.showUI(u); this.rNav(); this.scrollToUnit(u); this.sfxSelect(); return
		}
		this.sel = u; this.awPM = true;
		if (u.team === 'ally' && !u.ha) {
			this.mvT = []; const a = this.atkC(u);
			if (u.role === 'healer') { this.atkT = []; this.healT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'ally' && v.hp < v.mhp && v.id !== u.id }) }
			else { this.atkT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'enemy' }); this.healT = [] }
		}
		else { this.mvT = []; this.atkT = []; this.healT = [] } this.rTer(); this.rUnits(); this.showAM(u); this.showUI(u); this.rNav(); this.scrollToUnit(u); this.sfxSelect()
	},
	clrSel() { this.sel = null; this.mvT = []; this.atkT = []; this.healT = []; this.awPM = false; this.skillMode = false; this.skillMenuOpen = false; this._curSkill = null; this.preMv = null; this.hideAM(); this.rTer(); this.rUnits(); this.defI(); this.rNav() },
	cellCk(x, y) {
		if (this.phase !== 'player' || this.over || this.anim) return; const cl = this.uAt(x, y), s = this.sel;
		if (this.awPM && s) {
			if (this.skillMode) {
				if (this.atkT.some(c => c.x === x && c.y === y)) { this.doSkill(s, x, y); return }
				this.skillMode = false; const a = this.atkC(s);
				if (s.role === 'healer') { this.atkT = []; this.healT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'ally' && v.hp < v.mhp && v.id !== s.id }) }
				else { this.atkT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'enemy' }); this.healT = [] }
				this.rTer(); this.showAM(s); return
			}
			if (cl && cl.team === 'enemy' && s.cls === 'assassin' && s.team === 'ally' && !s.ha && this.ter[y] && this.ter[y][x] === 'forest' && this.mvT.some(c => c.x === x && c.y === y)) { this.doMv(s, x, y); return }
			if (cl && cl.team === 'enemy' && s.team === 'ally' && !s.ha && this.atkT.some(c => c.x === x && c.y === y)) { this.doAtk(s, cl); return }
			if (cl && cl.team === 'ally' && s.role === 'healer' && !s.ha && cl.id !== s.id && this.healT.some(c => c.x === x && c.y === y)) { this.doHeal(s, cl); return }
			if (!cl && this.mvT.some(c => c.x === x && c.y === y)) { this.doMv(s, x, y); return }
			if (!cl && (this.mvT.length > 0 || this.atkT.length > 0 || this.healT.length > 0) && !this.mvT.some(c => c.x === x && c.y === y) && !this.atkT.some(c => c.x === x && c.y === y) && !this.healT.some(c => c.x === x && c.y === y)) {
				this.mvT = []; this.atkT = []; this.healT = []; this.rTer(); this.showAM(s); return;
			}
			const hasRange = this.mvT.length > 0 || this.atkT.length > 0 || this.healT.length > 0;
			if (!hasRange && !cl) { this.clrSel(); return }
			s.ha = true; s.waited = true; this.awPM = false; this.hideAM(); this.clrSel();
			if (cl && cl.team !== 'enemy') { const nu = this.uAt(x, y); if (nu) this.selU(nu) }
			this.chkAutoEnd(); return
		}
		if (!s) { if (cl && cl.team === 'ally') this.selU(cl); return }
		if (cl && cl.team === 'enemy' && s.cls === 'assassin' && s.team === 'ally' && !s.ha && this.ter[y] && this.ter[y][x] === 'forest' && this.mvT.some(c => c.x === x && c.y === y)) { this.doMv(s, x, y); return }
		if (cl && cl.team === 'enemy' && s.team === 'ally' && !s.ha && this.atkT.some(c => c.x === x && c.y === y)) { this.doAtk(s, cl); return }
		if (cl && cl.team === 'ally' && s.role === 'healer' && !s.ha && cl.id !== s.id && this.healT.some(c => c.x === x && c.y === y)) { this.doHeal(s, cl); return }
		if (!cl && this.mvT.some(c => c.x === x && c.y === y)) { this.doMv(s, x, y); return }
		if (cl && cl.team === 'ally') { this.selU(cl); return } this.clrSel()
	},
	actMove() { if (!this.sel) return; this.hideAM(); const u = this.sel; this.mvT = (u.hm || u.mo) ? [] : this.mvC(u); this.rTer(); this.floatT(u.x, u.y, t('messages.select_move_target'), 'heal') },
	actAttack() { if (!this.sel) return; this.hideAM(); const msg = this.sel.role === 'healer' ? t('messages.select_heal_target') : t('messages.select_attack_target'); this.floatT(this.sel.x, this.sel.y, msg, 'heal') },
	showSkillMenu() { if (!this.sel || !this.awPM) return; this.skillMenuOpen = true; this.showAM(this.sel) },
	hideSkillMenu() { if (!this.sel) return; this.skillMenuOpen = false; this.showAM(this.sel) },
	actItem() { if (!this.sel) return; this.floatT(this.sel.x, this.sel.y, t('messages.item_system_preparing'), 'damage') },

	_grantExp(u, action) { if (u.team === 'ally' && u.uid) { const e = actExp(this.cStage ? this.cStage.id : 1, action); if (e > 0) { this.battleExp[u.uid] = (this.battleExp[u.uid] || 0) + e; this.floatT(u.x, u.y, `+${e} EXP`, 'exp'); } return e } return 0 },
	doMv(u, tx, ty) {
		const _mxp = this._grantExp(u, 'move'); this.preMv = { x: u.x, y: u.y, exp: _mxp }; this._mvU(u, tx, ty); u.hm = true; u.mo = true; this.awPM = true; this.sfxMove();
		this.chkTrap(u);
		const a = this.atkC(u); if (u.role === 'healer') { this.atkT = []; this.healT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'ally' && v.hp < v.mhp && v.id !== u.id }) }
		else { this.atkT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'enemy' }); this.healT = [] }
		this.mvT = []; setTimeout(() => { this.scrollToUnit(u); this.rTer(); this.showAM(u); this.showUI(u) }, 340)
	},
	doAtk(a, tgt) {
		const dmg = calcDmg(a, tgt); this._grantExp(a, 'attack');
		tgt.hp = Math.max(0, tgt.hp - dmg); this.vfxAtk(a, tgt); this.sfxAtk(a.cls); this.shakeU(tgt.id);
		this.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
		if (a.furyBuff > 0) this.floatT(a.x, a.y, t('messages.fury_buff'), 'heal');
		procFury(a, tgt, this);
		if (tgt.hp > 0 && a.hp > 0 && mh(tgt.x, tgt.y, a.x, a.y) <= tgt.range && !(tgt.stunned > 0)) {
			const cdmg = calcDmg(tgt, a); a.hp = Math.max(0, a.hp - cdmg); this.vfxAtk(tgt, a); this.sfxAtk(tgt.cls); this.shakeU(a.id); this.floatT(a.x, a.y, `-${cdmg}`, 'damage'); procFury(tgt, a, this);
		}
		a.ha = true; a.hm = true; this.awPM = false; this.hideAM();
		if (tgt.hp <= 0) {
			this.screenShake(); this.sfxKill(); this.sfxDeath(); this.vfxDeath(tgt); this.deathA(tgt.id); setTimeout(() => { this.units = this.units.filter(u => u.hp > 0); this.rUnits(); this.chkEnd(); this.clrSel(); this.chkAutoEnd() }, 500)
		}
		else if (a.hp <= 0) { this.screenShake(); this.sfxDeath(); this.vfxDeath(a); this.deathA(a.id); setTimeout(() => { this.units = this.units.filter(u => u.hp > 0); this.rUnits(); this.chkEnd(); this.clrSel(); this.chkAutoEnd() }, 500) }
		else { this.rUnits(); this.clrSel(); this.chkAutoEnd() }
	},
	doHeal(h, tgt) {
		const amt = Math.round(h.atk * 1.5); this._grantExp(h, 'heal'); tgt.hp = Math.min(tgt.mhp, tgt.hp + amt); this.vfxHeal(tgt); this.vfxBuff(tgt); this.sfxHeal(); this.floatT(tgt.x, tgt.y, `+${amt}`, 'heal');
		h.ha = true; h.hm = true; this.awPM = false; this.hideAM(); this.rUnits(); this.clrSel(); this.chkAutoEnd()
	},
	actWait() { if (!this.sel) return; this.sel.ha = true; this.sel.waited = true; if (this.sel.team === 'ally') this.allyPos[this.sel.id] = { x: this.sel.x, y: this.sel.y }; this.awPM = false; this.hideAM(); this.sfxWait(); this.rUnits(); this.clrSel(); this.chkAutoEnd() },
	actCancel() {
		if (!this.sel) return;
		if (this.skillMenuOpen) { this.hideSkillMenu(); return }
		if (!this.preMv) return; const u = this.sel; const _gdx = u._gdx, _gdy = u._gdy;
		if (this.preMv.exp && u.uid) { this.battleExp[u.uid] = (this.battleExp[u.uid] || 0) - this.preMv.exp }
		u.x = this.preMv.x; u.y = this.preMv.y; u.hm = false; u.mo = false;
		this.animU(u.id, u.x, u.y); u._gdx = _gdx; u._gdy = _gdy; this._applyFace(u.id);
		this.awPM = false; this.preMv = null; this.skillMode = false; this.skillMenuOpen = false; this.hideAM(); this.sfxUIClick(); setTimeout(() => { this.rTer(); this.clrSel() }, 340)
	},
	actSkill(idx) {
		if (!this.sel || !this.awPM) return; const u = this.sel;
		const skills = getUnitSkills(u); const sk = skills[idx || 0];
		if (!sk || u.res < sk.cost) return;
		this.skillMenuOpen = false;
		this._curSkill = sk; this.skillMode = true;
		if (sk.id === 'knight_switch') {
			const range = sk.switchRange || 2;
			this.atkT = this.units.filter(v => v.team === 'ally' && v.hp > 0 && v.id !== u.id && mh(u.x, u.y, v.x, v.y) <= range).map(v => ({ x: v.x, y: v.y }));
			this.healT = []
		} else if (sk.id === 'archer_dash') {
			this.atkT = []; for (let x = 0; x < COLS; x++)for (let y = 0; y < ROWS; y++) {
				if (mh(u.x, u.y, x, y) <= sk.dashRange && mh(u.x, u.y, x, y) > 0 && !this.uAt(x, y)) { this.atkT.push({ x, y }) }
			}
			this.healT = []
		} else if (sk.id === 'assassin_ambush') {
			if (!isStealthed(u)) { return }
			const range = sk.ambushRange || 2;
			this.atkT = this.units.filter(v => v.team === 'enemy' && v.hp > 0 && mh(u.x, u.y, v.x, v.y) <= range).map(v => ({ x: v.x, y: v.y }));
			this.healT = []
		} else if (sk.id === 'assassin_assassinate') {
			this.skillMode = false; this.doSkill(u, u.x, u.y); return
		} else if (sk.id === 'priest_massheal') {
			this.skillMode = false; this.doSkill(u, u.x, u.y); return
		} else if (sk.id === 'sapper_trap') {
			this.atkT = []; const tr = sk.trapRange || 3;
			for (let x = 0; x < COLS; x++)for (let y = 0; y < ROWS; y++) {
				if (mh(u.x, u.y, x, y) <= tr && mh(u.x, u.y, x, y) > 0) {
					const ti = TI[this.ter[y][x]]; if (!ti.pass) continue;
					if (this.uAt(x, y)) continue;
					if (this.traps.find(t => t.x === x && t.y === y)) continue;
					this.atkT.push({ x, y })
				}
			}
			this.healT = []
		} else if (sk.id === 'mage_fireburst') {
			this.atkT = [];
			for (let x = 0; x < COLS; x++)for (let y = 0; y < ROWS; y++) {
				if (mh(u.x, u.y, x, y) <= u.range && mh(u.x, u.y, x, y) > 0) this.atkT.push({ x, y })
			}
			this.healT = []
		} else if (sk.id === 'novice_throw') {
			this.atkT = this.units.filter(v => v.team === 'enemy' && v.hp > 0 && mh(u.x, u.y, v.x, v.y) <= sk.throwRange).map(v => ({ x: v.x, y: v.y }));
			this.healT = []
		} else if (sk.id === 'brawler_disarm') {
			const dr = sk.disarmRange || 1;
			this.atkT = this.units.filter(v => v.team === 'enemy' && v.hp > 0 && mh(u.x, u.y, v.x, v.y) <= dr).map(v => ({ x: v.x, y: v.y }));
			this.healT = []
		} else if (sk.id === 'shaman_curse' || sk.id === 'shaman_exalt') {
			this.skillMode = false; this.doSkill(u, u.x, u.y); return
		} else if (sk.id.startsWith('summoner_summon_')) {
			const maxSummons = 1;
			const currentSummons = this.units.filter(s => s.isSummon && s.summonerId === u.id);
			if (currentSummons.length >= maxSummons) {
				u.res += sk.cost; this.floatT(u.x, u.y, t('messages.summoner_limit'), 'damage'); return
			}
			const summonRange = sk.summonRange || 3;
			this.atkT = [];
			for (let x = 0; x < COLS; x++)for (let y = 0; y < ROWS; y++) {
				if (mh(u.x, u.y, x, y) <= summonRange && mh(u.x, u.y, x, y) > 0) {
					const ti = TI[this.ter[y][x]]; if (!ti || !ti.pass) continue;
					if (this.uAt(x, y)) continue;
					this.atkT.push({ x, y })
				}
			}
			this.healT = []
		} else {
			const dirs = [{ x: 0, y: -1 }, { x: 1, y: 0 }, { x: 0, y: 1 }, { x: -1, y: 0 }];
			this.atkT = dirs.map(d => ({ x: u.x + d.x, y: u.y + d.y })).filter(p => p.x >= 0 && p.x < COLS && p.y >= 0 && p.y < ROWS);
			this.healT = []
		}
		this.hideAM(); this.rTer()
	},
	_findAdj(x, y, u) {
		const dirs = [{ x: 0, y: -1 }, { x: 1, y: 0 }, { x: 0, y: 1 }, { x: -1, y: 0 }];
		const cands = [];
		for (const d of dirs) {
			const nx = x + d.x, ny = y + d.y;
			if (nx < 0 || nx >= COLS || ny < 0 || ny >= ROWS) continue;
			const ti = TI[this.ter[ny][nx]]; if (!ti.pass) continue;
			if (!this.uAt(nx, ny)) cands.push({ x: nx, y: ny });
		}
		if (!cands.length) return null;
		if (u) { cands.sort((a, b) => mh(a.x, a.y, u.x, u.y) - mh(b.x, b.y, u.x, u.y)) }
		return cands[0];
	},
	doSkill(u, tx, ty) {
		const sk = this._curSkill || SKILLS[u.cls]; if (!sk) return;
		const skObj = Array.isArray(sk) ? sk[0] : sk;
		if (u.res < skObj.cost) return; u.res -= skObj.cost;
		if (skObj.id === 'assassin_ambush') {
			if (!isStealthed(u)) { u.res += skObj.cost; return }
			const range = skObj.ambushRange || 2;
			const tgt = this.units.find(v => v.x === tx && v.y === ty && v.team === 'enemy' && v.hp > 0 && mh(u.x, u.y, v.x, v.y) <= range);
			if (!tgt) { u.res += skObj.cost; u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM(); this.rUnits(); return }
			const adj = this._findAdj(tgt.x, tgt.y, u);
			if (!adj) { u.res += skObj.cost; this.floatT(u.x, u.y, t('messages.no_empty_tile'), 'damage'); u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM(); this.rUnits(); return }
			this._mvU(u, adj.x, adj.y); u.mo = true;
			setTimeout(() => {
				const dmg = Math.max(1, u.atk * 2 - tgt.def);
				tgt.hp = Math.max(0, tgt.hp - dmg);
				this.vfxSpawn(this.uSX(tgt.x, tgt.y) + UCX, this.uSY(tgt.x, tgt.y) + UCY, { count: 12, colors: ['#a855f7', '#fff', '#c4b5fd'], shape: 'spark', speed: 4, spread: 12, decay: 0.025, size: 4 });
				this.sfxAtk(u.cls); this.shakeU(tgt.id);
				this.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
				this.floatT(u.x, u.y, t('messages.assassin_raid'), 'heal');
				if (tgt.hp <= 0) {
					u.res = Math.min(u.maxRes, u.res + 20);
					this.floatT(u.x, u.y, '+20 EP', 'exp');
					this.screenShake(); this.sfxKill(); this.sfxDeath(); this.vfxDeath(tgt); this.deathA(tgt.id);
					this.units = this.units.filter(v => v.hp > 0);
				}
				this._grantExp(u, 'attack');
				u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
				setTimeout(() => { this.rUnits(); this.chkEnd(); this.clrSel(); this.chkAutoEnd() }, 500);
			}, 360); return
		}
		if (skObj.id === 'assassin_assassinate') {
			const tgt = this.units.find(v => v.x === u.x && v.y === u.y && v.team === 'enemy' && v.hp > 0);
			if (!tgt) { u.res += skObj.cost; u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM(); this.rUnits(); return }
			const dmg = Math.max(1, u.atk * 5 - tgt.def);
			tgt.hp = Math.max(0, tgt.hp - dmg);
			this.vfxSpawn(this.uSX(tgt.x, tgt.y) + UCX, this.uSY(tgt.x, tgt.y) + UCY, { count: 20, colors: ['#7c3aed', '#a855f7', '#4c1d95'], shape: 'spark', speed: 5, spread: 16, decay: 0.02, size: 5 });
			this.screenShake(); this.sfxAtk(u.cls); this.shakeU(tgt.id);
			this.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
			this.floatT(u.x, u.y, t('messages.assassin_assassinate'), 'heal');
			if (tgt.hp <= 0) { this.sfxKill(); this.sfxDeath(); this.vfxDeath(tgt); this.deathA(tgt.id); this.units = this.units.filter(v => v.hp > 0) }
			this._grantExp(u, 'attack');
			const esc = this._findAdj(u.x, u.y, null);
			if (esc) { this._mvU(u, esc.x, esc.y); u.mo = true }
			u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
			setTimeout(() => { this.rUnits(); this.chkEnd(); this.clrSel(); this.chkAutoEnd() }, 500); return
		}
		if (skObj.id === 'priest_massheal') {
			const hr = skObj.healRange || 6;
			const targets = this.units.filter(v => v.team === 'ally' && v.hp > 0 && v.hp < v.mhp && mh(u.x, u.y, v.x, v.y) <= hr);
			if (!targets.length) { u.res += skObj.cost; this.floatT(u.x, u.y, t('messages.select_heal_target'), 'damage'); u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM(); this.rUnits(); return }
			const amt = u.atk;
			targets.forEach(tgt => {
				tgt.hp = Math.min(tgt.mhp, tgt.hp + amt);
				this.floatT(tgt.x, tgt.y, `+${amt}`, 'heal');
				this.vfxSpawn(this.uSX(tgt.x, tgt.y) + UCX, this.uSY(tgt.x, tgt.y) + UCY, { count: 8, colors: ['#4f4', '#8f8', '#fff'], shape: 'ring', speed: 2, spread: 8, decay: 0.025, size: 6 });
			});
			this.sfxHeal(); this.floatT(u.x, u.y, t('messages.priest_mass_heal'), 'heal');
			this.vfxSpawn(this.uSX(u.x, u.y) + UCX, this.uSY(u.x, u.y) + UCY, { count: 15, colors: ['#4f4', '#ff8', '#fff'], shape: 'ring', speed: 3, spread: 14, decay: 0.02, size: 8 });
			this._grantExp(u, 'heal');
			u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
			this.rUnits(); this.clrSel(); this.chkAutoEnd(); return
		}
		if (skObj.id === 'sapper_trap') {
			if (this.uAt(tx, ty) || this.traps.find(tr => tr.x === tx && tr.y === ty)) { u.res += skObj.cost; u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM(); this.rUnits(); return }
			this.traps.push({ x: tx, y: ty, dmg: u.atk * 2, id: this.traps.length, team: 'ally' });
			this.floatT(tx, ty, t('messages.trap_installed'), 'heal');
			this.vfxSpawn(this.uSX(tx, ty) + UCX, this.uSY(tx, ty) + UCY, { count: 10, colors: ['#f80', '#ff4', '#fa0'], shape: 'spark', speed: 2, spread: 10, decay: 0.025, size: 3 });
			this.sfxUIClick(); this._grantExp(u, 'attack');
			u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
			this.rUnits(); this.clrSel(); this.chkAutoEnd(); return
		}
		if (skObj.id === 'mage_fireburst') {
			let hitAny = false;
			for (let dx = -1; dx <= 1; dx++)for (let dy = -1; dy <= 1; dy++) {
				const px = tx + dx, py = ty + dy;
				if (px < 0 || px >= COLS || py < 0 || py >= ROWS) continue;
				const tgt = this.units.find(v => v.hp > 0 && v.x === px && v.y === py && v.team === 'enemy');
				if (tgt) {
					const dmg = Math.max(1, u.atk - tgt.def); tgt.hp = Math.max(0, tgt.hp - dmg);
					this.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage'); this.shakeU(tgt.id);
					this.vfxSpawn(this.uSX(tgt.x, tgt.y) + UCX, this.uSY(tgt.x, tgt.y) + UCY, { count: 8, colors: ['#f44', '#f80', '#ff4'], shape: 'spark', speed: 3, spread: 8, decay: 0.03, size: 3 });
					if (tgt.hp <= 0) { this.screenShake(); this.sfxKill(); this.sfxDeath(); this.vfxDeath(tgt); this.deathA(tgt.id); this.units = this.units.filter(v => v.hp > 0) }
					hitAny = true
				}
			}
			this.sfxAtk(u.cls); this._grantExp(u, 'attack');
			this.floatT(u.x, u.y, t('messages.mage_fireball'), 'heal');
			this.vfxSpawn(this.uSX(tx, ty) + UCX, this.uSY(tx, ty) + UCY, { count: 20, colors: ['#f44', '#f80', '#ff4', '#fff'], shape: 'spark', speed: 5, spread: 18, decay: 0.02, size: 5 });
			u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
			setTimeout(() => { this.rUnits(); this.chkEnd(); this.clrSel(); this.chkAutoEnd() }, 500); return
		}
		if (skObj.id === 'novice_throw') {
			const tgt = this.units.find(v => v.x === tx && v.y === ty && v.team === 'enemy' && v.hp > 0);
			if (!tgt) { u.res += skObj.cost; u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM(); this.rUnits(); return }
			const dmg = Math.max(1, Math.round(u.atk * 0.5) - tgt.def);
			tgt.hp = Math.max(0, tgt.hp - dmg);
			this.sfxAtk(u.cls); this.shakeU(tgt.id);
			this.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
			this.floatT(u.x, u.y, t('messages.stone_throw'), 'heal');
			this.vfxSpawn(this.uSX(tgt.x, tgt.y) + UCX, this.uSY(tgt.x, tgt.y) + UCY, { count: 8, colors: ['#a88', '#ccc', '#fff'], shape: 'spark', speed: 3, spread: 8, decay: 0.03, size: 3 });
			if (tgt.hp <= 0) { this.screenShake(); this.sfxKill(); this.sfxDeath(); this.vfxDeath(tgt); this.deathA(tgt.id) }
			this._grantExp(u, 'attack');
			u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
			setTimeout(() => { this.units = this.units.filter(v => v.hp > 0); this.rUnits(); this.chkEnd(); this.clrSel(); this.chkAutoEnd() }, 500); return
		}
		if (skObj.id === 'shaman_curse') {
			u.channeling = 'shaman_curse';
			this.floatT(u.x, u.y, t('messages.shaman_curse'), 'heal');
			this.vfxSpawn(this.uSX(u.x, u.y) + UCX, this.uSY(u.x, u.y) + UCY, { count: 15, colors: ['#9333ea', '#581c87', '#a855f7'], shape: 'ring', speed: 3, spread: 14, decay: 0.02, size: 6 });
			this.sfxAtk(u.cls); this._grantExp(u, 'attack');
			u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
			this.rUnits(); this.clrSel(); this.chkAutoEnd(); return
		}
		if (skObj.id === 'shaman_exalt') {
			u.channeling = 'shaman_exalt';
			this.floatT(u.x, u.y, t('messages.shaman_exalt'), 'heal');
			this.vfxSpawn(this.uSX(u.x, u.y) + UCX, this.uSY(u.x, u.y) + UCY, { count: 15, colors: ['#f59e0b', '#fbbf24', '#fff'], shape: 'ring', speed: 3, spread: 14, decay: 0.02, size: 6 });
			this.sfxHeal();
			this.alive('ally').forEach(a => {
				if (a.id !== u.id) this.vfxSpawn(this.uSX(a.x, a.y) + UCX, this.uSY(a.x, a.y) + UCY, { count: 6, colors: ['#f59e0b', '#fbbf24'], shape: 'spark', speed: 2, spread: 6, decay: 0.03, size: 3 });
			});
			this._grantExp(u, 'heal');
			u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
			this.rUnits(); this.clrSel(); this.chkAutoEnd(); return
		}
		if (skObj.id === 'summoner_summon_spirit' || skObj.id === 'summoner_summon_golem') {
			const target = this.units.find(v => v.x === tx && v.y === ty);
			if (target || !TI[this.ter[ty][tx]].pass) {
				u.res += skObj.cost; this.floatT(u.x, u.y, t('messages.summoner_no_spawn'), 'damage'); u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM(); this.rUnits(); return
			}
			const isSpirit = skObj.id === 'summoner_summon_spirit';
			const summonCls = skObj.summonType;
			let hp, atk, def, move, range, role;
			if (isSpirit) {
				hp = Math.round(u.mhp * 0.5); atk = Math.round(u.atk * 0.5); def = 0; move = 3; range = 3; role = 'ranged'
			} else {
				hp = Math.round(u.mhp * 1.2); atk = Math.round(u.atk * 0.5); def = Math.round(u.def * 1.2); move = 2; range = 1; role = 'melee'
			}
			const summonName = isSpirit ? '정령' : '골램';
			const summon = {
				id: this.nid++, uid: 0, team: 'ally', cls: summonCls,
				isSummon: true, summonerId: u.id,
				x: tx, y: ty, hp, mhp: hp, atk, def,
				move, range, role,
				res: 0, maxRes: 0, resType: 'none', resRec: 0,
				summonTurns: 5,
				hm: false, ha: false, waited: false, mo: false,
				furyBuff: 0, defBuff: 0, stunned: 0
			};
			this.units.push(summon);
			this.floatT(tx, ty, t('messages.sapper_summon', { name: summonName }), 'heal');
			const colors = isSpirit ? ['#8b5cf6', '#c084fc', '#fff'] : ['#78716c', '#a8a29e', '#fff'];
			this.vfxSpawn(this.uSX(tx, ty) + UCX, this.uSY(tx, ty) + UCY, { count: 25, colors, shape: 'ring', speed: 5, spread: 20, decay: 0.02, size: 8 });
			this.sfxHeal();
			this._grantExp(u, 'attack');
			u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
			this.rUnits(); this.clrSel(); this.chkAutoEnd(); return
		}
		if (skObj.id === 'brawler_disarm') {
			const tgt = this.units.find(v => v.x === tx && v.y === ty && v.team === 'enemy' && v.hp > 0);
			if (!tgt) { u.res += skObj.cost; u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM(); this.rUnits(); return }
			tgt.disarmed = 3;
			this.sfxAtk(u.cls); this.shakeU(tgt.id);
			this.floatT(tgt.x, tgt.y, t('messages.atk_reduced'), 'damage');
			this.floatT(u.x, u.y, t('messages.brawler_disarm'), 'heal');
			this.vfxSpawn(this.uSX(tgt.x, tgt.y) + UCX, this.uSY(tgt.x, tgt.y) + UCY, { count: 12, colors: ['#f97316', '#fbbf24', '#fff'], shape: 'ring', speed: 3, spread: 12, decay: 0.025, size: 5 });
			this._grantExp(u, 'attack');
			u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
			this.rUnits(); this.clrSel(); this.chkAutoEnd(); return
		}
		if (skObj.id === 'knight_switch') {
			const range = skObj.switchRange || 2;
			const tgt = this.units.find(v => v.x === tx && v.y === ty && v.team === 'ally' && v.hp > 0 && v.id !== u.id && mh(u.x, u.y, v.x, v.y) <= range);
			if (!tgt) { u.res += skObj.cost; u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM(); this.rUnits(); return }
			const _ux = u.x, _uy = u.y;
			u._gdx = tgt.x - u.x; u._gdy = tgt.y - u.y; tgt._gdx = u.x - tgt.x; tgt._gdy = u.y - tgt.y;
			[u.x, u.y, tgt.x, tgt.y] = [tgt.x, tgt.y, _ux, _uy];
			this.animU(u.id, u.x, u.y); this.animU(tgt.id, tgt.x, tgt.y);
			this.floatT(u.x, u.y, t('messages.knight_switch'), 'heal');
			this.vfxSpawn(this.uSX(u.x, u.y) + UCX, this.uSY(u.x, u.y) + UCY, { count: 10, colors: ['#4f4', '#4ff', '#fff'], shape: 'ring', speed: 2, spread: 8, decay: 0.02, size: 8 });
			this.vfxSpawn(this.uSX(tgt.x, tgt.y) + UCX, this.uSY(tgt.x, tgt.y) + UCY, { count: 10, colors: ['#4f4', '#4ff', '#fff'], shape: 'ring', speed: 2, spread: 8, decay: 0.02, size: 8 });
			this._grantExp(u, 'move');
			this.sfxMove(); u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
			setTimeout(() => { this.rUnits(); this.clrSel(); this.chkAutoEnd() }, 340); return
		}
		if (skObj.id === 'archer_dash') {
			if (this.uAt(tx, ty)) { u.res += skObj.cost; u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM(); this.rUnits(); return }
			const startX = u.x, startY = u.y;
			u._gdx = tx - u.x; u._gdy = ty - u.y; u.x = tx; u.y = ty; u.mo = true;
			this.vfxSpawn(this.uSX(startX, startY) + UCX, this.uSY(startY, startY) + UCY, { count: 12, colors: ['#ccf', '#99f', '#66f'], shape: 'spark', speed: 3, spread: 10, decay: 0.02, size: 2 });
			this.animU(u.id, tx, ty);
			this.floatT(u.x, u.y, t('messages.archer_leap'), 'heal');
			this.vfxSpawn(this.uSX(u.x, u.y) + UCX, this.uSY(u.x, u.y) + UCY, { count: 15, colors: ['#ff8', '#ff0', '#fff'], shape: 'spark', speed: 5, spread: 15, decay: 0.02, size: 3 });
			this.allyPos[u.id] = { x: u.x, y: u.y };
			this._grantExp(u, 'move');
			this.sfxMove(); u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
			setTimeout(() => { this.rUnits(); this.clrSel(); this.chkAutoEnd() }, 340); return
		}
		if (skObj.id === 'warrior_powersmash') {
			const tgt = this.units.find(v => v.x === tx && v.y === ty && v.hp > 0 && v.team !== u.team);
			if (!tgt) { u.res += skObj.cost; u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM(); this.rUnits(); return }
			const dmg = Math.max(1, Math.round(u.atk * 1.5 - tgt.def));
			tgt.hp = Math.max(0, tgt.hp - dmg);
			this.vfxAtk(u, tgt); this.sfxAtk(u.cls); this.shakeU(tgt.id);
			this.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
			procFury(u, tgt, this);
			this.floatT(u.x, u.y, t('messages.warrior_strike'), 'heal');
			this._grantExp(u, 'attack');
			if (tgt.hp <= 0) { this.screenShake(); this.sfxKill(); this.sfxDeath(); this.vfxDeath(tgt); this.deathA(tgt.id); this.units = this.units.filter(v => v.hp > 0); }
			u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
			setTimeout(() => { this.rUnits(); this.chkEnd(); this.clrSel(); this.chkAutoEnd() }, 500); return
		}
		const dx = tx - u.x, dy = ty - u.y;
		for (let i = 1; i <= skObj.pierceLen; i++) {
			const px = u.x + dx * i, py = u.y + dy * i;
			if (px < 0 || px >= COLS || py < 0 || py >= ROWS) continue;
			const tgt = this.units.find(v => v.hp > 0 && v.x === px && v.y === py && v.team !== u.team);
			if (tgt) {
				const dmg = Math.max(1, u.atk - tgt.def); tgt.hp = Math.max(0, tgt.hp - dmg);
				this.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage'); this.shakeU(tgt.id);
				this.vfxSpawn(this.uSX(tgt.x, tgt.y) + UCX, this.uSY(tgt.x, tgt.y) + UCY, { count: 8, colors: ['#6af', '#48f', '#fff'], shape: 'spark', speed: 3, spread: 8, decay: 0.03, size: 3 });
				if (tgt.hp <= 0) { this.screenShake(); this.sfxKill(); this.sfxDeath(); this.vfxDeath(tgt); this.deathA(tgt.id) }
			}
		}
		this.sfxAtk(u.cls); this._grantExp(u, 'attack');
		this.floatT(u.x, u.y, t('messages.lancer_pierce'), 'heal');
		this.vfxSpawn(this.uSX(u.x, u.y) + UCX, this.uSY(u.x, u.y) + UCY, { count: 12, colors: ['#6af', '#48f', '#aaf'], shape: 'spark', speed: 4, spread: 12, decay: 0.025, size: 4 });
		u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
		setTimeout(() => { this.units = this.units.filter(v => v.hp > 0); this.rUnits(); this.chkEnd(); this.clrSel(); this.chkAutoEnd() }, 500)
	},

	cancelChannel() {
		if (!this.sel || !this.sel.channeling) return;
		const u = this.sel;
		this.floatT(u.x, u.y, t('messages.channel_cancel'), 'damage');
		u.channeling = null;
		u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
		this.sfxUIClick(); this.rUnits(); this.clrSel(); this.chkAutoEnd()
	},

});

// ════════════════════════════════════════════
//  Section 5b: Render (from render.js)
// ════════════════════════════════════════════

Object.assign(G, {
	rTer() {
		const w = document.getElementById('iso-world');
		const existingBgTiles = new Map(), existingHlTiles = new Map();
		w.querySelectorAll('.iso-tile-bg').forEach(el => existingBgTiles.set(el.dataset.pos, el));
		w.querySelectorAll('.iso-tile-hl').forEach(el => existingHlTiles.set(el.dataset.pos, el));
		const tilesNeeded = new Set();
		const W = TW * 2;
		const _tc = this._tColors || {};

		for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
			const tp = this.ter[r][c], ti = TI[tp], clr = _tc[tp] || ti;
			const pos = `${c},${r}`; tilesNeeded.add(pos);
			let hl = '';
			if (this.sel) {
				if (this.mvT.some(m => m.x === c && m.y === r)) hl = 'move';
				else if (this.atkT.some(a => a.x === c && a.y === r)) hl = 'attack';
				else if (this.healT.some(h => h.x === c && h.y === r)) hl = 'heal';
				if (this.sel.x === c && this.sel.y === r) hl = 'selected';
			}
			const h = ti.z * ZH, H = TH * 2 + h + 2;
			const clip = h > 0
				? `polygon(${TW}px 1px,${W-1}px ${TH}px,${W-1}px ${TH+h}px,${TW}px ${TH*2-1+h}px,1px ${TH+h}px,1px ${TH}px)`
				: `polygon(${TW}px 1px,${W-1}px ${TH}px,${TW}px ${TH*2-1}px,1px ${TH}px)`;

			let bgTile = existingBgTiles.get(pos);
			if (!bgTile) { bgTile = document.createElement('div'); bgTile.className = 'iso-tile iso-tile-bg'; bgTile.dataset.pos = pos; w.appendChild(bgTile) }
			if (bgTile.innerHTML) bgTile.innerHTML = '';
			if (h > 0) {
				const cy = ((TH * 2 - 1) / H * 100).toFixed(1);
				const ang = Math.round(Math.atan2(TW - 1, TH - 1) * 180 / Math.PI);
				bgTile.style.background = `conic-gradient(from 0deg at 50% ${cy}%,${clr.tc} 0deg ${ang}deg,${clr.rc} ${ang}deg 180deg,${clr.lc} 180deg ${360-ang}deg,${clr.tc} ${360-ang}deg 360deg)`;
			} else if (tp === 'forest') {
				const fb = clr.tc, fl = clr.lc, fd = clr.rc;
				bgTile.style.background = `radial-gradient(ellipse 14px 10px at 25% 25%,${fb},${fl} 60%,transparent 100%),radial-gradient(ellipse 16px 11px at 70% 20%,${fb},${fl} 60%,transparent 100%),radial-gradient(ellipse 18px 12px at 50% 50%,${fb},${fl} 60%,transparent 100%),radial-gradient(ellipse 13px 9px at 20% 70%,${fl},${fd} 60%,transparent 100%),radial-gradient(ellipse 15px 10px at 78% 65%,${fb},${fl} 60%,transparent 100%),radial-gradient(ellipse 10px 7px at 45% 85%,${fl},${fd} 60%,transparent 100%),${fd}`;
			} else if (tp === 'rock') {
				bgTile.style.background = `linear-gradient(135deg,${clr.tc} 25%,${clr.rc} 45%,${clr.tc} 55%,${clr.rc} 75%,${clr.tc})`;
			} else if (tp === 'water') {
				const wA = (this.cStage && this.cStage.mapType === 'volcano') ? 'rgba(140,40,20,.12)' : 'rgba(40,90,140,.12)';
				bgTile.style.background = `repeating-linear-gradient(0deg,transparent,transparent 5px,${wA} 5px,${wA} 6px),${clr.tc}`;
			} else { bgTile.style.background = clr.tc; }
			bgTile.style.clipPath = clip;

			let hlTile = existingHlTiles.get(pos);
			if (!hlTile) {
				hlTile = document.createElement('div'); hlTile.className = 'iso-tile iso-tile-hl'; hlTile.dataset.pos = pos; hlTile.style.cursor = 'pointer';
				hlTile.addEventListener('click', e => { e.stopPropagation(); const rect = w.getBoundingClientRect(); const px = e.clientX - rect.left, py = e.clientY - rect.top; const hit = G.isoHit(px, py); if (!hit) return; const { c, r } = hit; if (c < 0 || c >= COLS || r < 0 || r >= ROWS) return; if (G.awPM) { G.cellCk(c, r); return } const u = G.uAt(c, r); if (u && u.team === 'ally' && !G.sel) { G.selU(u); return } if (u && u.team === 'ally' && G.sel && u.id === G.sel.id) { G.clrSel(); return } G.cellCk(c, r) });
				w.appendChild(hlTile);
			}
			if (hlTile.innerHTML) hlTile.innerHTML = '';
			hlTile.style.clipPath = clip;

			const sx = this.tSX(c, r), sy = this.tSY(c, r, ti.z), zix = this.g2v(c, r);
			bgTile.style.left = sx + 'px'; bgTile.style.top = sy + 'px'; bgTile.style.width = W + 'px'; bgTile.style.height = H + 'px'; bgTile.style.zIndex = zix.vc + zix.vr;
			hlTile.style.left = sx + 'px'; hlTile.style.top = sy + 'px'; hlTile.style.width = W + 'px'; hlTile.style.height = H + 'px'; hlTile.style.zIndex = zix.vc + zix.vr + 1;

			hlTile.classList.remove('hl-move', 'hl-attack', 'hl-heal', 'hl-selected');
			if (hl === 'move') hlTile.classList.add('hl-move');
			else if (hl === 'attack') hlTile.classList.add('hl-attack');
			else if (hl === 'heal') hlTile.classList.add('hl-heal');
			else if (hl === 'selected') hlTile.classList.add('hl-selected');
		}

		existingBgTiles.forEach((el, pos) => { if (!tilesNeeded.has(pos)) el.remove() });
		existingHlTiles.forEach((el, pos) => { if (!tilesNeeded.has(pos)) el.remove() });
	},

	rUnits() {
		const w = document.getElementById('iso-world'), al = this.units.filter(u => u.hp > 0), ids = new Set();
		const resClr = u => u.resType === 'mana' ? '#4488ff' : u.resType === 'energy' ? '#f0c040' : '#ff6644';
		al.forEach(u => {
			ids.add('u-' + u.id); let el = document.getElementById('u-' + u.id);
			if (!el) {
				el = document.createElement('div'); el.id = 'u-' + u.id; el.className = `unit-sprite ${u.team} spawning`;
				if (u.team === 'ally') this.allyPos[u.id] = {x: u.x, y: u.y};
				setTimeout(() => el.classList.remove('spawning'), 450);
				el.innerHTML = `<div class="u-icon">${charSprite(u.cls, 36, u.gender)}</div><div class="u-shadow"></div><div class="hp-bg"><div class="hp-fill"></div></div><div class="mp-bg"><div class="mp-fill"></div></div>`;
				w.appendChild(el);
				if (u.team === 'enemy') { u._gdx = 0; u._gdy = 1; this._applyFace(u.id) }
			}
			el.style.width = UW + 'px'; el.style.height = UH + 'px'; el.style.left = this.uSX(u.x, u.y) + 'px'; el.style.top = this.uSY(u.x, u.y) + 'px';
			const v = this.g2v(u.x, u.y); el.style.zIndex = 100 + v.vc + v.vr;
			el.querySelector('.hp-fill').style.width = `${(u.hp / u.mhp) * 100}%`;
			const mpFill = el.querySelector('.mp-fill');
			mpFill.style.width = `${u.maxRes ? (u.res / u.maxRes) * 100 : 0}%`;
			mpFill.style.background = resClr(u);
			const isSel = this.sel && this.sel.id === u.id;
			el.classList.toggle('acted', u.team === 'ally' && u.ha && !isSel); el.classList.remove('ally', 'enemy'); el.classList.add(u.team);
			el.classList.toggle('stealthed', isStealthed(u)); el.classList.toggle('stunned', u.stunned > 0);
			let stunLabel = el.querySelector('.stun-label'); if (u.stunned > 0) { if (!stunLabel) { stunLabel = document.createElement('div'); stunLabel.className = 'stun-label'; el.appendChild(stunLabel) } stunLabel.textContent = u.stunned } else if (stunLabel) stunLabel.remove();
			// Buff/debuff badges on unit sprite
			const fx = [];
			if (u.furyBuff > 0) fx.push({ icon: '💢', cls: 'buff' });
			if (u.defBuff > 0) fx.push({ icon: '🛡️', cls: 'buff' });
			if (u.disarmed > 0) fx.push({ icon: '🤛', cls: 'debuff' });
			if (u.channeling) fx.push({ icon: u.channeling === 'shaman_curse' ? '☠️' : '🔺', cls: u.channeling === 'shaman_curse' ? 'debuff' : 'buff' });
			let badges = el.querySelector('.u-badges');
			if (fx.length) {
				if (!badges) { badges = document.createElement('div'); badges.className = 'u-badges'; el.appendChild(badges) }
				badges.innerHTML = fx.map(e => `<span class="u-badge ${e.cls}">${e.icon}</span>`).join('');
			} else if (badges) badges.remove();
			if (u.isSummon && u.summonTurns !== undefined) {
				let turnLabel = el.querySelector('.summon-turns');
				if (!turnLabel) {
					turnLabel = document.createElement('div');
					turnLabel.className = 'summon-turns';
					turnLabel.style.cssText = 'position:absolute;top:-8px;right:-8px;background:#8b5cf6;color:#fff;border-radius:50%;width:20px;height:20px;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:bold;border:2px solid #fff;z-index:10;';
					el.appendChild(turnLabel)
				}
				turnLabel.textContent = u.summonTurns
			} else {
				const turnLabel = el.querySelector('.summon-turns');
				if (turnLabel) turnLabel.remove()
			}
		});
		[...w.querySelectorAll('.unit-sprite')].forEach(el => { if (!ids.has(el.id)) el.remove() });
		this.units.filter(u => u.team === 'ally' && u.hp <= 0).forEach(u => {
			this.allyPos[u.id] = {x: 99, y: 99};
		});
		this.rMM(); this.rNav()
	},

	floatT(x, y, t, tp) {
		const w = document.getElementById('iso-world'), el = document.createElement('div');
		el.className = `float-text ${tp}`; el.textContent = t; el.style.left = (this.uSX(x, y) + UCX / 2) + 'px'; el.style.top = (this.uSY(x, y) - 8) + 'px'; el.style.zIndex = 500;
		w.appendChild(el); setTimeout(() => el.remove(), 950)
	},
	showAM(u) {
		const m = document.getElementById('action-menu');
		m.style.left = (this.uSX(u.x, u.y) + UW + 2) + 'px';
		m.style.top = this.uSY(u.x, u.y) + 'px'; m.style.zIndex = 600;
		if (u.channeling) {
			this.hideAllMenuButtons();
			document.getElementById('btn-cancel').style.display = 'none';
			const btn = document.createElement('button'); btn.className = 'am-skill';
			btn.textContent = t('messages.unlock');
			btn.onclick = () => G.cancelChannel();
			const btnDash = document.getElementById('btn-dash');
			m.insertBefore(btn, btnDash);
			btnDash.style.display = 'none';
			m.classList.add('show'); return
		}
		if (this.skillMenuOpen) { this.showSkillSubMenu(u); return }
		this.showMainMenu(u)
	},
	showMainMenu(u) {
		const m = document.getElementById('action-menu');
		m.querySelectorAll('.am-skill').forEach(e => e.remove());
		document.getElementById('btn-move').style.display = (!u.hm && !u.mo) ? '' : 'none';
		const btnAttack = document.getElementById('btn-attack');
		if (u.role === 'healer') {
			btnAttack.textContent = t('battle.heal');
			btnAttack.style.display = (!u.ha && this.healT.length > 0) ? '' : 'none'
		}
		else {
			btnAttack.textContent = t('battle.attack');
			btnAttack.style.display = (!u.ha && this.atkT.length > 0) ? '' : 'none'
		}
		const skills = getUnitSkills(u);
		const hasUsableSkill = !u.ha && skills.some(sk => this.canUseSkill(u, sk));
		document.getElementById('btn-skill').style.display = hasUsableSkill ? '' : 'none';
		document.getElementById('btn-item').style.display = 'none';
		const btnDash = document.getElementById('btn-dash');
		btnDash.textContent = t('battle.wait');
		btnDash.style.display = '';
		const btnCancel = document.getElementById('btn-cancel');
		btnCancel.textContent = t('battle.cancel');
		btnCancel.style.display = this.preMv ? '' : 'none';
		btnCancel.onclick = () => G.actCancel();
		m.classList.add('show')
	},
	showSkillSubMenu(u) {
		const m = document.getElementById('action-menu');
		this.hideAllMenuButtons();
		m.querySelectorAll('.am-skill').forEach(e => e.remove());
		const skills = getUnitSkills(u);
		const btnDash = document.getElementById('btn-dash');
		skills.forEach((sk, idx) => {
			const btn = document.createElement('button'); btn.className = 'am-skill';
			btn.textContent = sk.icon + ' ' + t('skills.' + sk.id);
			let enabled = this.canUseSkill(u, sk);
			btn.disabled = !enabled;
			btn.onclick = () => G.actSkill(idx);
			m.insertBefore(btn, btnDash)
		});
		btnDash.style.display = 'none';
		const btnCancel = document.getElementById('btn-cancel');
		btnCancel.textContent = '↩ ' + t('battle.cancel');
		btnCancel.style.display = '';
		btnCancel.onclick = () => G.hideSkillMenu();
		m.classList.add('show')
	},
	hideAllMenuButtons() {
		['btn-move', 'btn-attack', 'btn-skill', 'btn-item', 'btn-dash', 'btn-cancel'].forEach(id => {
			document.getElementById(id).style.display = 'none'
		})
	},
	canUseSkill(u, sk) {
		let enabled = u.res >= sk.cost && !u.ha;
		if (sk.id === 'assassin_assassinate') {
			const overlapping = isStealthed(u) && this.units.some(v =>
				v.x === u.x && v.y === u.y && v.team === 'enemy' && v.hp > 0);
			enabled = enabled && overlapping
		}
		if (sk.id.startsWith('summoner_summon_')) {
			const maxSummons = 1;
			const currentSummons = this.units.filter(s => s.isSummon && s.summonerId === u.id);
			if (currentSummons.length >= maxSummons) { enabled = false }
		}
		return enabled
	},
	hideAM() { document.getElementById('action-menu').classList.remove('show') },
});

// ════════════════════════════════════════════
//  Section 5c: UI (from ui.js)
// ════════════════════════════════════════════

Object.assign(G, {
  getBuffs(u){
    const buffs=[];
    const t=this.ter[u.y]?this.ter[u.y][u.x]:null;
    if(t&&TI[t].buff){const b=TI[t].buff;buffs.push({icon:b.icon,type:b.type,turns:0})}
    getSkillBuffs(u).forEach(b=>buffs.push(b));
    if(u.cls==='assassin'&&t==='forest')buffs.push({icon:'🌙',type:'buff',turns:0});
    if(u.ha)buffs.push({icon:'✓',type:'debuff',turns:0});
    else if(u.waited)buffs.push({icon:'⏸',type:'neutral',turns:0});
    if(u.mo&&!u.ha)buffs.push({icon:'👣',type:'neutral',turns:0});
    return buffs;
  },
  rNav(){
    const nav=document.getElementById('ally-nav');
    const allAllies=this.units.filter(u=>u.team==='ally');
    nav.innerHTML='';
    allAllies.forEach(u=>{
      const dead=u.hp<=0;
      const isSel=this.sel&&this.sel.id===u.id;
      const d=JAB[u.cls];
      const pct=dead?0:Math.round(u.hp/u.mhp*100);
      const hpColor=pct>60?'#22c55e':pct>30?'#eab308':'#ef4444';
      const buffs=dead?[]:this.getBuffs(u);

      const el=document.createElement('div');
      el.className='an-unit'+(dead?' dead':'')+(isSel?' selected':'')+(u.ha&&!dead?' acted-nav':'');

      let bh='';
      buffs.forEach(b=>{
        const tl=b.turns>0?`<span class="bf-turn">${b.turns}</span>`:'';
        bh+=`<span class="an-buff ${b.type}">${b.icon}${tl}</span>`;
      });

      const resColor=u.resType==='mana'?'#4488ff':u.resType==='energy'?'#f0c040':'#ff6644';
      const resPct=dead?0:(u.maxRes?Math.round(u.res/u.maxRes*100):0);

      const buffsDiv=bh?`<div class="an-buffs">${bh}</div>`:'';
      el.innerHTML=`${buffsDiv}<div class="an-vres"><div class="an-vres-fill" style="height:${resPct}%;background:${resColor}"></div></div><div class="an-vhp"><div class="an-vhp-fill" style="height:${pct}%;background:${hpColor}"></div></div><div class="an-icon">${clsIcon(u.cls,18)}</div>`;

      if(!dead)el.onclick=()=>{if(this.awPM)return;this.selU(u)};
      nav.appendChild(el);
    });
  },

  rMM(){
    const d=this.vDim();
    const wW=(d.c+d.r)*TW+4;
    const wH=(d.c+d.r)*TH+80;
    const mmMaxW=80;
    const sc=mmMaxW/wW;
    const mW=Math.ceil(wW*sc);
    const mH=Math.ceil(wH*sc);

    const cv=document.getElementById('mm-cv');
    cv.width=mW;cv.height=mH;
    const mm=document.getElementById('minimap');
    mm.style.width=mW+'px';mm.style.height=mH+'px';
    const ctx=cv.getContext('2d');
    ctx.clearRect(0,0,mW,mH);

    for(let r=0;r<ROWS;r++)for(let c=0;c<COLS;c++){
      const v=this.g2v(c,r);
      const ix=this.isoX(v.vc,v.vr);
      const iy=this.isoY(v.vc,v.vr,0);
      const sx=ix*sc, sy=iy*sc;
      const tw=TW*sc, th=TH*sc;
      ctx.fillStyle=TI[this.ter[r][c]].tc;
      ctx.beginPath();
      ctx.moveTo(sx+tw,sy);
      ctx.lineTo(sx+tw*2,sy+th);
      ctx.lineTo(sx+tw,sy+th*2);
      ctx.lineTo(sx,sy+th);
      ctx.closePath();ctx.fill();
      ctx.strokeStyle='rgba(255,255,255,.08)';ctx.lineWidth=0.3;ctx.stroke();
    }
    this.units.filter(u=>u.hp>0).forEach(u=>{
      const v=this.g2v(u.x,u.y);
      const ix=this.isoX(v.vc,v.vr)+TW;
      const iy=this.isoY(v.vc,v.vr,0)+TH;
      const sx=ix*sc, sy=iy*sc;
      ctx.fillStyle=u.team==='ally'?'#3b82f6':'#ef4444';
      ctx.beginPath();ctx.arc(sx,sy,Math.max(2,TW*sc*0.35),0,Math.PI*2);ctx.fill();
    });
    this._mmSc=sc;
    this.rMMvp();
  },
  rMMvp(){
    const ct=document.getElementById('map-container');
    const w=document.getElementById('iso-world');
    const wW=parseFloat(w.style.width),wH=parseFloat(w.style.height);
    if(!wW||!wH||!this._mmSc)return;
    const sc=this._mmSc;
    const vp=document.getElementById('mm-vp');
    const oL=parseFloat(w.style.left||0),oT=parseFloat(w.style.top||0);
    const vx=ct.scrollLeft-oL, vy=ct.scrollTop-oT;
    vp.style.left=Math.max(0,vx*sc)+'px';
    vp.style.top=Math.max(0,vy*sc)+'px';
    vp.style.width=Math.min(ct.clientWidth*sc, wW*sc)+'px';
    vp.style.height=Math.min(ct.clientHeight*sc, wH*sc)+'px';
  },
  mmClick(e){
    const cv=document.getElementById('mm-cv');
    const rect=cv.getBoundingClientRect();
    if(!this._mmSc)return;
    const sc=this._mmSc;
    const wx=(e.clientX-rect.left)/sc;
    const wy=(e.clientY-rect.top)/sc;
    const ct=document.getElementById('map-container');
    const w=document.getElementById('iso-world');
    const oL=parseFloat(w.style.left||0),oT=parseFloat(w.style.top||0);
    ct.scrollLeft=oL+wx-ct.clientWidth/2;
    ct.scrollTop=oT+wy-ct.clientHeight/2;
  },

  uUI(){const ti=document.getElementById('turn-indicator');ti.textContent=this.phase==='player'?'PLAYER':'ENEMY';ti.className=this.phase;
    const s=this.cStage,en=this.alive('enemy').length;
    const br=s?this.breached:0,blim=s?Math.ceil(s.tot/4):0;
    document.getElementById('stage-info').innerHTML=`STAGE ${s?s.id:1} <span style="color:var(--dim);font-size:9px">${s?t('stages.stage_'+s.id+'_name'):''}</span>
      <div class="si-turn">TURN ${this.turn} · ${t('battle.summon')} ${this.eSpwn}/${s?s.tot:'?'} · ${t('battle.remaining')} ${en}체 · <span style="color:${br>0?'#ef4444':'var(--dim)'}">
${t('battle.breach')} ${br}/${blim}</span></div>`;
    document.getElementById('btn-end-turn').disabled=this.phase!=='player'},
  showUI(u){const p=document.getElementById('info-panel'),tc=u.team==='ally'?'ally-card':'enemy-card';
    let h=this.iCard(u,tc,true);if(u.team==='ally'){(u.role==='healer'?this.healT:this.atkT).forEach(t=>{
      const tu=this.uAt(t.x,t.y);if(tu)h+=this.iCard(tu,tu.team==='ally'?'ally-card':'enemy-card',false)})}p.innerHTML=h},
  iCard(u,cc,m){const p=Math.round(u.hp/u.mhp*100);
    const rl={'mana':'MP','energy':'EP','fury':'FP'};
    const rc={'mana':'#4488ff','energy':'#f0c040','fury':'#ff6644'};
    const rn=rl[u.resType]||'',rpct=u.maxRes?Math.round(u.res/u.maxRes*100):0;
    return`<div class="info-card ${cc}" ${m?'style="border-width:2px"':''}>
      <div class="ic-top"><span class="ic-icon">${clsIcon(u.cls,18)}</span><span class="ic-name">${u.name}</span><span class="ic-class">${t('classes.' + u.cls)}</span></div>
      <div class="ic-stats"><span>HP <b>${u.hp}/${u.mhp}</b></span><span style="color:${rc[u.resType]}">${rn} <b>${u.res}/${u.maxRes}</b></span><span>ATK <b>${u.atk}</b></span><span>DEF <b>${u.def}</b></span><span>RNG <b>${u.range}</b></span></div></div>`},
  defI(){const a=this.alive('ally').length,e=this.alive('enemy').length;
    document.getElementById('info-panel').innerHTML=`<div style="display:flex;gap:12px;align-items:center;font-size:11px"><span style="color:var(--blue)">${t('battle.allies', {count: a})}</span><span style="color:var(--red)">${t('battle.enemies', {count: e})}</span><span style="color:var(--dim)">${t('battle.select_unit_touch')}</span></div>`},
  showWv(t){const b=document.getElementById('wave-banner');b.textContent=t;b.classList.add('show')},
  hideWv(){document.getElementById('wave-banner').classList.remove('show')},
  showRes(win,msg){const ov=document.getElementById('modal-overlay');
    this.onBattleEnd(win);
    const reward=win?(50+(this.cStage?this.cStage.id*30:0)):0;
    document.getElementById('modal-title').textContent=win?t('messages.victory'):t('messages.defeat');
    document.getElementById('modal-title').className=win?'win':'lose';
    const deadAllies=this.units.filter(u=>u.team==='ally'&&u.hp<=0);
    let sub=msg;
    if(win&&reward)sub+=`\n🏅 보상: ${reward} Gold`;
    if(win&&this._droppedBook){sub+=`\n📕 ${t('academy.skillbook_drop', {skill: t('skills.'+this._droppedBook)})}`;this._droppedBook=null}
    if(deadAllies.length)sub+=`\n💀 전사자: ${deadAllies.length}명 (성소에서 부활 가능)`;
    if(this._expResults&&this._expResults.length){
      sub+=`\n\n${t('results.battle_detail', {kills: this._deadEnemyCount||0, exp: this._totalExp||0, survivors: this._expResults.length})}`;
      this._expResults.forEach(r=>{
        const ch=getChar(r.uid);if(!ch)return;
        const d=JAB[ch.cls];
        const charName = ch.customName || t('character.names')[ch.nameId] || d.icon;
        let line=`\n${d.icon} ${charName}: +${r.exp} EXP`;
        if(r.leveled>0)line+=` ⬆ Lv.${r.prevLv}→${ch.lv}`;
        sub+=line;
      });
    }
    document.getElementById('modal-sub').innerHTML=sub.replace(/\n/g,'<br>');
    if(win)this.sfxVictory();else this.sfxDefeat();
    this.bgmStop();
    const bt=document.getElementById('modal-buttons');bt.innerHTML='';
    const lb=document.createElement('button');lb.className='modal-btn';lb.textContent=t('results.return_to_lobby');
    lb.onclick=()=>{ov.classList.remove('show');this.returnToLobby()};bt.appendChild(lb);
    if(win){const s=this.cStage,ns=STAGES.find(v=>v.id===s.id+1);
      if(ns){const b=document.createElement('button');b.className='modal-btn secondary';b.textContent=t('results.next_stage');
        b.onclick=()=>{ov.classList.remove('show');this.goNextStage(ns)};bt.appendChild(b)}}
    ov.classList.add('show')},

  _sett:{bgmVol:0.6,sfxVol:0.8,bgmOn:true,sfxOn:true,speed:1,language:null},
  _sfxGainNode:null,
  loadSett(){try{const d=JSON.parse(localStorage.getItem('game_setting'));
    if(d){if(typeof d.bgmVol==='number')this._sett.bgmVol=d.bgmVol;
      if(typeof d.sfxVol==='number')this._sett.sfxVol=d.sfxVol;
      if(typeof d.bgmOn==='boolean')this._sett.bgmOn=d.bgmOn;
      if(typeof d.sfxOn==='boolean')this._sett.sfxOn=d.sfxOn;
      if(typeof d.speed==='number')this._sett.speed=d.speed;
      if(typeof d.language==='string')this._sett.language=d.language;
    }}catch(e){}},
  saveSett(){try{localStorage.setItem('game_setting',JSON.stringify(this._sett))}catch(e){}},
  toggleSettings(){const p=document.getElementById('settings-panel');if(!p)return;
    const b=document.getElementById('settings-backdrop');
    const opening=!p.classList.contains('show');
    p.classList.toggle('show');b.classList.toggle('show');
    if(opening)this.syncSettingsUI()},
  closeSettings(){const p=document.getElementById('settings-panel');if(p)p.classList.remove('show');
    const b=document.getElementById('settings-backdrop');if(b)b.classList.remove('show')},
  syncSettingsUI(){
    document.getElementById('sp-bgm-on').checked=this._sett.bgmOn;
    document.getElementById('sp-bgm').value=Math.round(this._sett.bgmVol*100);
    document.getElementById('sp-bgm-val').textContent=Math.round(this._sett.bgmVol*100);
    document.getElementById('sp-sfx-on').checked=this._sett.sfxOn;
    document.getElementById('sp-sfx').value=Math.round(this._sett.sfxVol*100);
    document.getElementById('sp-sfx-val').textContent=Math.round(this._sett.sfxVol*100);
    document.getElementById('sp-speed').value=Math.round(1/this._sett.speed*100);
    document.getElementById('sp-speed-val').textContent=this._sett.speed.toFixed(1)+'x';
  },
  setBGMOn(v){this._sett.bgmOn=v;
    if(v){if(!this._bgm&&!this.over)this.bgmStart()}
    else{this.bgmStop()}this.saveSett()},
  setSFXOn(v){this._sett.sfxOn=v;
    if(this._sfxGainNode)this._sfxGainNode.gain.setValueAtTime(v?this._sett.sfxVol:0,this.sfxCtx().currentTime);this.saveSett()},
  setBGMVol(v){this._sett.bgmVol=v/100;document.getElementById('sp-bgm-val').textContent=v;
    if(this._bgm&&this._bgm.master){this._bgm.master.gain.setValueAtTime(0.12*(v/100),this.sfxCtx().currentTime)}this.saveSett()},
  setSFXVol(v){this._sett.sfxVol=v/100;document.getElementById('sp-sfx-val').textContent=v;
    if(this._sfxGainNode&&this._sett.sfxOn)this._sfxGainNode.gain.setValueAtTime(v/100,this.sfxCtx().currentTime);this.saveSett()},
  setSpeed(v){const spd=100/v;this._sett.speed=spd;
    document.getElementById('sp-speed-val').textContent=spd.toFixed(1)+'x';this.saveSett()},
  surrender(){if(this.over)return;
    this.closeSettings();
    this.over=true;this.showRes(false,t('messages.surrender'))}
});

// ════════════════════════════════════════════
//  Section 5d: VFX (from vfx.js)
// ════════════════════════════════════════════
Object.assign(G, {
    vfxParts: [], vfxRaf: null,
    vfxInit() {
        const cv = document.getElementById('vfx-canvas');
        const w = document.getElementById('iso-world');
        cv.width = parseInt(w.style.width) || 2000; cv.height = parseInt(w.style.height) || 2000;
    },
    vfxSpawn(x, y, opts) {
        const cnt = opts.count || 8;
        for (let i = 0; i < cnt; i++) {
            this.vfxParts.push({
                x: x + (Math.random() - .5) * (opts.spread || 10),
                y: y + (Math.random() - .5) * (opts.spread || 10),
                vx: (Math.random() - .5) * (opts.speed || 2),
                vy: opts.vy !== undefined ? (opts.vy + (Math.random() - .5)) : (-Math.random() * (opts.speed || 2)),
                life: 1, decay: opts.decay || (0.015 + Math.random() * 0.02),
                size: opts.size || (2 + Math.random() * 3),
                color: opts.colors[Math.floor(Math.random() * opts.colors.length)],
                shape: opts.shape || 'circle',
                gravity: opts.gravity || 0,
                trail: opts.trail || false,
                rotation: Math.random() * Math.PI * 2,
                rotSpd: (Math.random() - .5) * 0.2
            });
        }
        if (!this.vfxRaf) this.vfxLoop();
    },
    vfxLoop() {
        const cv = document.getElementById('vfx-canvas'); if (!cv) return;
        const ctx = cv.getContext('2d'); ctx.clearRect(0, 0, cv.width, cv.height);
        for (let i = this.vfxParts.length - 1; i >= 0; i--) {
            const p = this.vfxParts[i];
            p.x += p.vx; p.y += p.vy; p.vy += p.gravity; p.life -= p.decay; p.rotation += p.rotSpd;
            if (p.life <= 0) { this.vfxParts.splice(i, 1); continue }
            ctx.save(); ctx.globalAlpha = p.life; ctx.fillStyle = p.color;
            ctx.translate(p.x, p.y); ctx.rotate(p.rotation);
            if (p.shape === 'circle') { ctx.beginPath(); ctx.arc(0, 0, p.size * p.life, 0, Math.PI * 2); ctx.fill() }
            else if (p.shape === 'star') { this.drawStar(ctx, 0, 0, p.size * p.life) }
            else if (p.shape === 'slash') {
                ctx.strokeStyle = p.color; ctx.lineWidth = p.size * p.life * 0.6; ctx.lineCap = 'round';
                ctx.beginPath(); ctx.moveTo(-p.size * 2, p.size * 2); ctx.lineTo(p.size * 2, -p.size * 2); ctx.stroke()
            }
            else if (p.shape === 'spark') {
                ctx.strokeStyle = p.color; ctx.lineWidth = 1; ctx.beginPath();
                ctx.moveTo(0, 0); ctx.lineTo(-p.vx * 3, -p.vy * 3); ctx.stroke();
                ctx.beginPath(); ctx.arc(0, 0, p.size * p.life * 0.5, 0, Math.PI * 2); ctx.fill()
            }
            else if (p.shape === 'ring') {
                ctx.strokeStyle = p.color; ctx.lineWidth = 1.5 * p.life;
                ctx.beginPath(); ctx.arc(0, 0, p.size * (1 - p.life) * 3 + 2, 0, Math.PI * 2); ctx.stroke()
            }
            else if (p.shape === 'arrow') {
                ctx.strokeStyle = p.color; ctx.lineWidth = 1.5 * p.life; ctx.lineCap = 'round';
                ctx.beginPath(); ctx.moveTo(0, p.size * 3); ctx.lineTo(0, -p.size * 3);
                ctx.moveTo(-p.size, -p.size); ctx.lineTo(0, -p.size * 3); ctx.lineTo(p.size, -p.size); ctx.stroke()
            }
            else if (p.shape === 'diamond') {
                ctx.beginPath(); const s = p.size * p.life;
                ctx.moveTo(0, -s); ctx.lineTo(s, 0); ctx.lineTo(0, s); ctx.lineTo(-s, 0); ctx.closePath(); ctx.fill()
            }
            ctx.restore();
        }
        if (this.vfxParts.length) this.vfxRaf = requestAnimationFrame(() => this.vfxLoop());
        else { this.vfxRaf = null; ctx.clearRect(0, 0, cv.width, cv.height) }
    },
    drawStar(ctx, x, y, r) {
        ctx.beginPath(); for (let i = 0; i < 5; i++) {
            ctx.lineTo(x + r * Math.cos(i * 1.256 - .785), y + r * Math.sin(i * 1.256 - .785));
            ctx.lineTo(x + r * .4 * Math.cos(i * 1.256 + .628 - .785), y + r * .4 * Math.sin(i * 1.256 + .628 - .785))
        } ctx.closePath(); ctx.fill()
    },

    // Class-specific attack VFX
    vfxAtk(attacker, target) {
        this.faceDir(attacker.id, target.x - attacker.x, target.y - attacker.y);
        this.atkAnimU(attacker.id);
        const ax = this.uSX(attacker.x, attacker.y) + UCX, ay = this.uSY(attacker.x, attacker.y) + UCY;
        const tx = this.uSX(target.x, target.y) + UCX, ty = this.uSY(target.x, target.y) + UCY;
        const cls = attacker.cls;
        if (cls === 'warrior') {
            this.vfxSpawn(tx, ty, { count: 12, colors: ['#fff', '#aaddff', '#88bbff'], shape: 'slash', speed: 3, spread: 12, decay: 0.04, size: 4 });
            this.vfxSpawn(tx, ty, { count: 6, colors: ['#ffffffcc', '#aaddffcc'], shape: 'spark', speed: 4, spread: 8, decay: 0.03, size: 2 });
        } else if (cls === 'knight') {
            this.vfxSpawn(tx, ty, { count: 15, colors: ['#ffcc44', '#ff8800', '#ffffff'], shape: 'circle', speed: 2, spread: 6, decay: 0.02, size: 4, gravity: 0.1 });
            this.vfxSpawn(tx, ty, { count: 3, colors: ['#ffffff88'], shape: 'ring', speed: 0, spread: 2, decay: 0.02, size: 12 });
        } else if (cls === 'assassin') {
            for (let i = 0; i < 3; i++)setTimeout(() => {
                this.vfxSpawn(tx + (Math.random() - 0.5) * 10, ty + (Math.random() - 0.5) * 10, { count: 6, colors: ['#cc44ff', '#ff44cc', '#ffffff'], shape: 'slash', speed: 4, spread: 8, decay: 0.05, size: 3 })
            }, i * 60);
            this.vfxSpawn(ax, ay, { count: 8, colors: ['#cc44ff44', '#8844ff44'], shape: 'diamond', speed: 1.5, spread: 15, decay: 0.03, size: 5 });
        } else if (cls === 'mage') {
            this.vfxSpawn(tx, ty, { count: 4, colors: ['#4488ff55'], shape: 'ring', speed: 0, spread: 4, decay: 0.012, size: 16 });
            this.vfxSpawn(tx, ty, { count: 20, colors: ['#4488ff', '#88aaff', '#aaccff', '#ffffff'], shape: 'star', speed: 3, spread: 8, decay: 0.025, size: 3 });
            this.vfxSpawn(tx, ty, { count: 8, colors: ['#4488ff', '#ffffff'], shape: 'spark', speed: 5, spread: 4, decay: 0.02, size: 2 });
        } else if (cls === 'archer') {
            const dx = tx - ax, dy = ty - ay, dist = Math.sqrt(dx * dx + dy * dy);
            const steps = Math.max(5, Math.floor(dist / 12));
            for (let i = 0; i < steps; i++) {
                const tt = i / steps;
                setTimeout(() => this.vfxSpawn(ax + dx * tt, ay + dy * tt, { count: 2, colors: ['#ffdd88', '#ffffff88'], shape: 'spark', speed: 1, spread: 3, decay: 0.06, size: 1.5 }), i * 20)
            }
            setTimeout(() => this.vfxSpawn(tx, ty, { count: 8, colors: ['#ffdd44', '#ff8844', '#ffffff'], shape: 'spark', speed: 3, spread: 6, decay: 0.03, size: 2 }), steps * 20);
        } else if (cls === 'priest') {
            this.vfxSpawn(tx, ty, { count: 10, colors: ['#ffffff', '#ffffaa'], shape: 'star', speed: 2, spread: 10, decay: 0.025, size: 3 });
        }
    },

    vfxHeal(target) {
        const tx = this.uSX(target.x, target.y) + UCX, ty = this.uSY(target.x, target.y) + UCY;
        this.vfxSpawn(tx, ty, {
            count: 18, colors: ['#44ff88', '#88ffaa', '#aaffcc', '#ffffff'], shape: 'circle',
            speed: 1.5, spread: 14, decay: 0.018, size: 3, vy: -1.5, gravity: -0.02
        });
        this.vfxSpawn(tx, ty, { count: 5, colors: ['#44ff8844'], shape: 'ring', speed: 0, spread: 3, decay: 0.015, size: 14 });
        this.vfxSpawn(tx, ty, { count: 8, colors: ['#aaffcc', '#ffffff'], shape: 'star', speed: 1, spread: 10, decay: 0.02, size: 2.5, vy: -2, gravity: -0.01 });
    },

    vfxDeath(unit) {
        const tx = this.uSX(unit.x, unit.y) + UCX, ty = this.uSY(unit.x, unit.y) + UCY;
        const baseColor = unit.team === 'ally' ? ['#3b82f6', '#60a5fa', '#93c5fd', '#bfdbfe'] : ['#ef4444', '#f87171', '#fca5a5', '#fecaca'];
        this.vfxSpawn(tx, ty, { count: 25, colors: [...baseColor, '#ffffff88'], shape: 'diamond', speed: 1.5, spread: 16, decay: 0.012, size: 3, gravity: 0.03, vy: -.5 });
        this.vfxSpawn(tx, ty, { count: 10, colors: ['#ffffff44'], shape: 'circle', speed: .8, spread: 12, decay: 0.01, size: 2, vy: -1, gravity: -0.01 });
    },

    vfxBuff(unit) {
        const el = document.getElementById('u-' + unit.id);
        if (el) { el.classList.add('buff-glow'); setTimeout(() => el.classList.remove('buff-glow'), 500) }
        const tx = this.uSX(unit.x, unit.y) + UCX, ty = this.uSY(unit.x, unit.y) + UCY;
        this.vfxSpawn(tx, ty, { count: 8, colors: ['#22c55e', '#4ade80', '#ffffff'], shape: 'star', speed: 1.5, spread: 12, decay: 0.025, size: 2.5, vy: -1 });
    },

    screenShake() {
        const w = document.getElementById('iso-world');
        w.classList.remove('screen-shake'); void w.offsetWidth; w.classList.add('screen-shake');
        setTimeout(() => w.classList.remove('screen-shake'), 300);
    },

    turnFlash(type) {
        const el = document.getElementById('turn-flash');
        el.classList.remove('player-flash', 'enemy-flash'); void el.offsetWidth;
        el.classList.add(type + '-flash'); setTimeout(() => el.classList.remove(type + '-flash'), 600);
    },

    // Game-space direction → screen flip conversion
    // isoX = (vc-vr)*TW, so screen_dx ∝ (dvc-dvr)
    // camDir 0: dvc=dc,dvr=dr → sdx=dc-dr   camDir 1: dvc=-dr,dvr=dc → sdx=-dr-dc
    // camDir 2: dvc=-dc,dvr=-dr → sdx=dr-dc  camDir 3: dvc=dr,dvr=-dc → sdx=dr+dc
    _g2sx(gdx, gdy) { const d=gdx||0,r=gdy||0; switch(this.camDir){case 0:return d-r;case 1:return -r-d;case 2:return r-d;default:return r+d} },
    faceDir(id, gdx, gdy) {
        if (!gdx && !gdy) return;
        const u = this.units.find(v => v.id === id);
        if (u) { u._gdx = gdx; u._gdy = gdy }
        this._applyFace(id);
    },
    _applyFace(id) {
        const el = document.getElementById('u-' + id); if (!el) return;
        const u = this.units.find(v => v.id === id); if (!u) return;
        const sdx = this._g2sx(u._gdx, u._gdy);
        if (!sdx) return;
        const img = el.querySelector('.u-icon img');
        if (img) img.style.transform = sdx < 0 ? 'scaleX(-1)' : '';
    },
    _mvU(u, nx, ny) { u._gdx = nx - u.x; u._gdy = ny - u.y; u.x = nx; u.y = ny; this.animU(u.id, nx, ny) },
    animU(id, x, y) {
        const el = document.getElementById('u-' + id); if (el) {
            el.classList.add('moving'); setTimeout(() => el.classList.remove('moving'), 340);
            const u = this.units.find(v => v.id === id);
            if (u && (u._gdx || u._gdy)) this._applyFace(id);
            el.style.left = this.uSX(x, y) + 'px'; el.style.top = this.uSY(x, y) + 'px';
            const v = this.g2v(x, y); el.style.zIndex = 100 + v.vc + v.vr
        }
    },
    shakeU(id) { const el = document.getElementById('u-' + id); if (el) { el.classList.add('shaking'); setTimeout(() => el.classList.remove('shaking'), 300) } },
    atkAnimU(id) { const el = document.getElementById('u-' + id); if (el) { el.classList.add('attacking'); setTimeout(() => el.classList.remove('attacking'), 380) } },
    deathA(id) { const el = document.getElementById('u-' + id); if (el) el.classList.add('dying') },
});

// ════════════════════════════════════════════
//  Section 5e: Audio / SFX / BGM (from audio.js)
// ════════════════════════════════════════════
Object.assign(G, {
  _actx:null,
  sfxCtx(){if(!this._actx)this._actx=new(window.AudioContext||window.webkitAudioContext)();
    if(this._actx.state==='suspended')this._actx.resume();
    if(!this._sfxGainNode){this._sfxGainNode=this._actx.createGain();this._sfxGainNode.gain.setValueAtTime(this._sett.sfxVol,this._actx.currentTime);this._sfxGainNode.connect(this._actx.destination)}
    return this._actx},
  sfxDest(){return this._sfxGainNode||this.sfxCtx().destination},
  sfxGain(ctx,v,t){const g=ctx.createGain();g.gain.setValueAtTime(v,t||ctx.currentTime);return g},
  sfxOsc(ctx,type,freq,start,dur,gainN,detune){
    if(!this._sett.sfxOn)return{o:null,g:null};
    const o=ctx.createOscillator(),g=this.sfxGain(ctx,gainN,start);
    o.type=type;o.frequency.setValueAtTime(freq,start);if(detune)o.detune.setValueAtTime(detune,start);
    o.connect(g);g.connect(this.sfxDest());o.start(start);o.stop(start+dur);
    g.gain.exponentialRampToValueAtTime(0.001,start+dur);return{o,g}},
  sfxNoise(ctx,start,dur,gainN,filter){
    if(!this._sett.sfxOn)return;
    const buf=ctx.createBuffer(1,ctx.sampleRate*dur,ctx.sampleRate),d=buf.getChannelData(0);
    for(let i=0;i<d.length;i++)d[i]=(Math.random()*2-1);
    const src=ctx.createBufferSource();src.buffer=buf;
    const g=this.sfxGain(ctx,gainN,start);
    if(filter){const f=ctx.createBiquadFilter();f.type=filter.type||'highpass';f.frequency.setValueAtTime(filter.freq||1000,start);
      if(filter.Q)f.Q.setValueAtTime(filter.Q,start);src.connect(f);f.connect(g)}
    else src.connect(g);
    g.connect(this.sfxDest());g.gain.exponentialRampToValueAtTime(0.001,start+dur);
    src.start(start);src.stop(start+dur)},

  // UI sounds
  sfxSelect(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',880,t,0.06,0.12);this.sfxOsc(c,'sine',1320,t+0.04,0.08,0.08)},
  sfxMove(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',440,t,0.05,0.08);this.sfxOsc(c,'sine',550,t+0.03,0.06,0.06)},
  sfxUIClick(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',660,t,0.04,0.1)},
  sfxWait(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',440,t,0.1,0.08);this.sfxOsc(c,'sine',330,t+0.06,0.12,0.06)},

  // Attack sounds by class
  sfxAtkWarrior(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxNoise(c,t,0.12,0.25,{type:'bandpass',freq:2000,Q:2});
    this.sfxOsc(c,'sawtooth',200,t,0.08,0.12);
    this.sfxNoise(c,t+0.03,0.08,0.15,{type:'highpass',freq:3000})},
  sfxAtkKnight(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxNoise(c,t,0.18,0.3,{type:'lowpass',freq:600,Q:3});
    this.sfxOsc(c,'sine',80,t,0.15,0.2);this.sfxOsc(c,'sine',60,t+0.05,0.12,0.15);
    this.sfxNoise(c,t+0.04,0.1,0.12,{type:'bandpass',freq:400,Q:1})},
  sfxAtkAssassin(){const c=this.sfxCtx(),t=c.currentTime;
    for(let i=0;i<3;i++){const d=i*0.06;
      this.sfxNoise(c,t+d,0.04,0.18,{type:'highpass',freq:4000+i*500});
      this.sfxOsc(c,'sawtooth',600+i*200,t+d,0.04,0.06)}},
  sfxAtkMage(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',300,t,0.3,0.1);
    const o=c.createOscillator(),g=this.sfxGain(c,0.12,t);
    o.type='sine';o.frequency.setValueAtTime(300,t);o.frequency.exponentialRampToValueAtTime(1200,t+0.25);
    o.connect(g);g.connect(c.destination);o.start(t);o.stop(t+0.3);
    g.gain.exponentialRampToValueAtTime(0.001,t+0.3);
    this.sfxNoise(c,t+0.1,0.15,0.08,{type:'bandpass',freq:2000,Q:5});
    this.sfxOsc(c,'triangle',800,t+0.15,0.12,0.06)},
  sfxAtkArcher(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxNoise(c,t,0.06,0.15,{type:'highpass',freq:5000});
    const o=c.createOscillator(),g=this.sfxGain(c,0.08,t);
    o.type='sine';o.frequency.setValueAtTime(1200,t);o.frequency.exponentialRampToValueAtTime(400,t+0.15);
    o.connect(g);g.connect(c.destination);o.start(t);o.stop(t+0.18);
    g.gain.exponentialRampToValueAtTime(0.001,t+0.18);
    this.sfxNoise(c,t+0.12,0.06,0.2,{type:'bandpass',freq:1500,Q:3})},
  sfxAtkPriest(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',600,t,0.15,0.08);this.sfxOsc(c,'sine',900,t+0.05,0.12,0.06)},

  sfxAtk(cls){
    const m={warrior:'sfxAtkWarrior',knight:'sfxAtkKnight',assassin:'sfxAtkAssassin',
      mage:'sfxAtkMage',archer:'sfxAtkArcher',priest:'sfxAtkPriest'};
    if(m[cls])this[m[cls]]()},

  sfxHeal(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',523,t,0.15,0.1);this.sfxOsc(c,'sine',659,t+0.08,0.15,0.08);
    this.sfxOsc(c,'sine',784,t+0.16,0.2,0.07);this.sfxOsc(c,'triangle',1047,t+0.24,0.25,0.05)},

  sfxDeath(){const c=this.sfxCtx(),t=c.currentTime;
    const o=c.createOscillator(),g=this.sfxGain(c,0.12,t);
    o.type='sine';o.frequency.setValueAtTime(500,t);o.frequency.exponentialRampToValueAtTime(80,t+0.5);
    o.connect(g);g.connect(c.destination);o.start(t);o.stop(t+0.5);
    g.gain.exponentialRampToValueAtTime(0.001,t+0.5);
    this.sfxNoise(c,t+0.1,0.35,0.06,{type:'lowpass',freq:800})},

  sfxTurnPlayer(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',523,t,0.1,0.1);this.sfxOsc(c,'sine',659,t+0.08,0.1,0.09);
    this.sfxOsc(c,'sine',784,t+0.16,0.15,0.08)},
  sfxTurnEnemy(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sawtooth',220,t,0.15,0.08);this.sfxOsc(c,'sawtooth',165,t+0.1,0.2,0.07)},

  sfxWave(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'square',440,t,0.1,0.07);this.sfxOsc(c,'square',440,t+0.15,0.1,0.07);
    this.sfxOsc(c,'square',660,t+0.3,0.15,0.09)},

  sfxVictory(){const c=this.sfxCtx(),t=c.currentTime;
    const notes=[523,659,784,1047];
    notes.forEach((f,i)=>{this.sfxOsc(c,'sine',f,t+i*0.12,0.25,0.1);this.sfxOsc(c,'triangle',f,t+i*0.12,0.25,0.04)})},
  sfxDefeat(){const c=this.sfxCtx(),t=c.currentTime;
    const notes=[392,349,330,262];
    notes.forEach((f,i)=>{this.sfxOsc(c,'sine',f,t+i*0.2,0.35,0.1);this.sfxOsc(c,'sawtooth',f/2,t+i*0.2,0.35,0.03)})},

  // BGM - Tense Battle (One-shot Sequencer)
  _bgm:null,
  bgmStart(){
    this.bgmStop();
    if(!this._sett.bgmOn)return;
    const ctx=this.sfxCtx();
    const vol=0.12*this._sett.bgmVol;
    const master=ctx.createGain();master.gain.setValueAtTime(vol,ctx.currentTime);
    master.connect(ctx.destination);
    const comp=ctx.createDynamicsCompressor();
    comp.threshold.setValueAtTime(-18,ctx.currentTime);comp.ratio.setValueAtTime(4,ctx.currentTime);
    comp.connect(master);

    const BPM=128, eighth=60/BPM/2;
    const chords=[[147,175,220],[117,147,175],[98,117,147],[110,139,165]];
    const bassN=[73.5,58.5,49,55];
    const riffs=[
      [587,523,440,523,587,698,587,523],
      [466,440,349,440,466,523,466,349],
      [392,349,294,349,392,466,392,294],
      [440,349,330,349,440,523,440,330]];

    let beatIdx=0;
    const startT=ctx.currentTime+0.05;

    const note=(type,freq,time,dur,vol,det)=>{
      const o=ctx.createOscillator(),g=ctx.createGain();
      o.type=type;o.frequency.setValueAtTime(freq,time);
      if(det)o.detune.setValueAtTime(det,time);
      g.gain.setValueAtTime(vol,time);
      g.gain.exponentialRampToValueAtTime(0.001,time+dur);
      o.connect(g);g.connect(comp);o.start(time);o.stop(time+dur+0.01);
    };
    const noise=(time,dur,vol,hpFreq)=>{
      const len=Math.max(0.01,dur);
      const buf=ctx.createBuffer(1,ctx.sampleRate*len,ctx.sampleRate);
      const d=buf.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=Math.random()*2-1;
      const src=ctx.createBufferSource();src.buffer=buf;
      const f=ctx.createBiquadFilter();f.type='highpass';f.frequency.setValueAtTime(hpFreq,time);
      const g=ctx.createGain();g.gain.setValueAtTime(vol,time);
      g.gain.exponentialRampToValueAtTime(0.001,time+len);
      src.connect(f);f.connect(g);g.connect(comp);
      src.start(time);src.stop(time+len+0.01);
    };

    const LOOK=0.25, INT=100;
    const schedule=()=>{
      if(!this._bgm)return;
      const now=ctx.currentTime;
      while(startT+beatIdx*eighth < now+LOOK){
        const t=startT+beatIdx*eighth;
        const ci=Math.floor((beatIdx/8)%4);
        const b=beatIdx%8;

        if(b===0){
          const ch=chords[ci];
          note('sawtooth',ch[0],t,eighth*7.8,0.06,-3);
          note('triangle',ch[1],t,eighth*7.8,0.05,0);
          note('triangle',ch[2],t,eighth*7.8,0.05,3);
        }
        const bF=b%2===0?bassN[ci]:bassN[ci]*2;
        note('sawtooth',bF,t,eighth*0.8,b%2===0?0.18:0.12,0);

        const mF=riffs[ci][b];
        note('square',mF,t,eighth*0.7,b%2===0?0.08:0.04,0);
        note('triangle',mF*1.002,t,eighth*0.7,b%2===0?0.04:0.02,0);

        if(b===0||b===4){
          const ko=ctx.createOscillator(),kg=ctx.createGain();
          ko.type='sine';ko.frequency.setValueAtTime(100,t);
          ko.frequency.exponentialRampToValueAtTime(30,t+0.12);
          kg.gain.setValueAtTime(0.25,t);kg.gain.exponentialRampToValueAtTime(0.001,t+0.12);
          ko.connect(kg);kg.connect(comp);ko.start(t);ko.stop(t+0.13);
        }
        if(b===2||b===6){
          noise(t,0.08,0.15,2000);
          note('triangle',180,t,0.06,0.06,0);
        }
        noise(t,0.03,b%2===0?0.05:0.025,9000);

        beatIdx++;
      }
      this._bgm.timer=setTimeout(schedule,INT);
    };
    this._bgm={master,comp,timer:null};
    schedule();
  },
  bgmStop(){
    if(!this._bgm)return;
    if(this._bgm.timer){clearTimeout(this._bgm.timer);this._bgm.timer=null}
    const m=this._bgm.master,ctx=this.sfxCtx(),t=ctx.currentTime;
    m.gain.linearRampToValueAtTime(0,t+0.6);
    setTimeout(()=>{try{m.disconnect()}catch(e){}},700);
    this._bgm=null;
  },

  sfxKill(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxNoise(c,t,0.2,0.3,{type:'lowpass',freq:500,Q:2});
    this.sfxOsc(c,'sine',100,t,0.2,0.15);this.sfxOsc(c,'sine',60,t+0.05,0.18,0.1)},
});

// ════════════════════════════════════════════
//  Section 5f: AI Turns & Movement (from ai.js)
// ════════════════════════════════════════════
Object.assign(G, {
  // Turns
  endTurn(){if(this.phase!=='player'||this.over||this.awPM||this.anim)return;
    document.getElementById('turn-confirm').classList.remove('show');
    this.clrSel();this.phase='enemy';this.uUI();this.turnFlash('enemy');this.sfxTurnEnemy();
    document.getElementById('enemy-banner').classList.add('show');setTimeout(()=>this.doET(),800)},
  chkAutoEnd(){if(this.phase!=='player'||this.over||this.anim||this.awPM)return;
    const al=this.alive('ally');if(!al.length||!al.every(u=>u.ha))return;
    if(this.autoEndSkip){setTimeout(()=>this.endTurn(),350);return}
    document.getElementById('turn-confirm').classList.add('show')},
  confirmEndTurn(yes){
    document.getElementById('turn-confirm').classList.remove('show');
    if(yes)setTimeout(()=>this.endTurn(),100)},
  autoEndSkip:false,
  setAutoEnd(v){this.autoEndSkip=v},
  async doET(){const s=this.cStage;
    if(s&&this.turn%s.si===0&&this.eSpwn<s.tot){this.showWv(t('messages.wave_info',{count:s.tot-this.eSpwn}));this.sfxWave();this.spawnW();this.rUnits();await sl(600);this.hideWv()}
    // Enemy resource recovery
    this.alive('enemy').forEach(u=>{
      if(u.stunned>0)u.stunned--;
      tickBuffs(u);
      if(u.resType==='mana'){u.res=Math.min(u.maxRes,u.res+u.resRec)}
      else if(u.resType==='energy'){
        let rec=u.resRec;
        if(u.cls==='assassin'){const tl=this.ter[u.y]?this.ter[u.y][u.x]:null;if(tl==='forest')rec*=2}
        u.res=Math.min(u.maxRes,u.res+rec);
        if(u.cls==='sapper'&&u.res>=20&&!this.traps.find(tr=>tr.x===u.x&&tr.y===u.y)){
          u.res-=20;
          this.traps.push({x:u.x,y:u.y,dmg:u.atk*2,id:this.traps.length,team:'enemy'});
          this.floatT(u.x,u.y,t('messages.trap_placed'),'heal');
        }
      }
    });this.rUnits();
    this.anim=true;for(const e of[...this.alive('enemy')]){if(this.over)break;await this.eAI(e);await sl(500)}
    this.anim=false;document.getElementById('enemy-banner').classList.remove('show');this.chkEnd();
    if(!this.over){this.turn++;this.phase='player';this.turnFlash('player');this.sfxTurnPlayer();
      // 채널링 효과 처리 (쇠약의 저주: 적 1명에게 최대HP% 피해)
      this.alive('ally').filter(u=>u.channeling==='shaman_curse').forEach(u=>{
        const enemies=this.alive('enemy');
        if(enemies.length){
          const tgt=enemies[Math.floor(Math.random()*enemies.length)];
          const pct=tgt.isBoss?0.002:0.005;
          const dmg=Math.max(1,Math.round(tgt.mhp*pct));
          tgt.hp=Math.max(0,tgt.hp-dmg);
          this.floatT(tgt.x,tgt.y,`-${dmg}`,'damage');
          this.floatT(tgt.x,tgt.y,t('messages.curse'),'damage');
          this.vfxSpawn(this.uSX(tgt.x,tgt.y)+UCX,this.uSY(tgt.x,tgt.y)+UCY,{count:6,colors:['#9333ea','#581c87','#a855f7'],shape:'spark',speed:2,spread:8,decay:0.03,size:3});
          if(tgt.hp<=0){this.sfxDeath();this.vfxDeath(tgt);this.deathA(tgt.id);this.units=this.units.filter(v=>v.hp>0);
            setTimeout(()=>{this.rUnits();this.chkEnd()},500)}
        }
      });
      this.alive('ally').forEach(u=>{
        // 소환수 턴 관리
        if(u.isSummon&&u.summonTurns!==undefined){
          u.summonTurns--;
          if(u.summonTurns<=0){
            this.floatT(u.x,u.y,t('messages.unsummoned'),'damage');
            this.vfxDeath(u);
            setTimeout(()=>{
              this.units=this.units.filter(v=>v.id!==u.id);
              this.rUnits();
            },500);
            return}
        }
        // 채널링 유닛: 이동/행동 불가, 자원 회복 없음
        if(u.channeling){
          u.hm=true;u.ha=true;u.waited=true;u.mo=false;
          return}
        u.hm=false;u.ha=false;u.waited=false;u.mo=false;
        // Stunned recovery
        if(u.stunned>0)u.stunned--;
        tickBuffs(u);
        // Resource recovery
        if(u.resType==='mana'){u.res=Math.min(u.maxRes,u.res+u.resRec)}
        else if(u.resType==='energy'){
          let rec=u.resRec;
          if(u.cls==='assassin'){const tl=this.ter[u.y]?this.ter[u.y][u.x]:null;if(tl==='forest')rec*=2}
          u.res=Math.min(u.maxRes,u.res+rec)}
        // fury: no auto recovery
      });
      this.uUI();this.clrSel();this.rMM()}},
  // Target selection (class-based priority)
  selectTarget(u,inRange,profile){
    if(!inRange.length)return null;
    if(Math.random()<AI_MISTAKE_CHANCE){
      return inRange[Math.floor(Math.random()*inRange.length)]
    }
    const p=profile.targetPriority;
    if(p==='low_hp'){
      const kl=inRange.filter(a=>a.hp<=Math.max(1,u.atk-a.def));
      if(kl.length)return kl.sort((a,b)=>a.hp-b.hp)[0];
      return inRange.sort((a,b)=>a.hp-b.hp)[0]
    }
    if(p==='nearest'){
      return inRange.sort((a,b)=>mh(u.x,u.y,a.x,a.y)-mh(u.x,u.y,b.x,b.y))[0]
    }
    if(p==='nearest_threat'){
      const o=u.origSpawn||{x:u.x,y:u.y};
      return inRange.sort((a,b)=>mh(o.x,o.y,a.x,a.y)-mh(o.x,o.y,b.x,b.y))[0]
    }
    if(p==='random_weak'){
      const s=[...inRange].sort((a,b)=>a.hp-b.hp);
      const w=s.slice(0,Math.ceil(s.length/2));
      return w[Math.floor(Math.random()*w.length)]
    }
    if(p==='cluster'){
      let bt=null,bn=0;
      for(const tgt of inRange){
        const n=this.alive('ally').filter(a=>a.id!==tgt.id&&mh(tgt.x,tgt.y,a.x,a.y)<=2).length;
        if(n>bn){bn=n;bt=tgt}
      }
      return bt||inRange[0]
    }
    return inRange[Math.floor(Math.random()*inRange.length)]
  },
  // Skill auto-use
  async tryUseSkill(u, profile) {
    if (!profile.skillUseProbability || Math.random() > profile.skillUseProbability) return false;
    const al = this.alive('ally');
    if (!al.length) return false;

    // Warrior 강타
    if (u.cls === 'warrior' && u.res >= 3) {
      const inR = this.atkC(u)
        .filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'ally' && !isStealthed(v); })
        .map(c => this.uAt(c.x, c.y));
      for (const tgt of inR) {
        const dmg = Math.max(1, Math.round(u.atk * 1.5 - tgt.def));
        if (tgt.hp <= dmg) {
          u.res -= 3;
          tgt.hp = 0;
          this.floatT(u.x, u.y, t('messages.warrior_strike'), 'heal');
          this.screenShake(); this.sfxKill(); this.sfxDeath(); this.vfxDeath(tgt); this.deathA(tgt.id);
          this.units = this.units.filter(v => v.hp > 0);
          u.ha = true;
          setTimeout(() => { this.rUnits(); }, 500);
          return true;
        }
      }
    }

    // Brawler 무장해제
    if (u.cls === 'brawler' && u.res >= 30) {
      const inR = al.filter(v => mh(u.x, u.y, v.x, v.y) <= 1);
      const highAtk = inR.filter(v => v.atk >= 25 && !v.disarmed);
      if (highAtk.length) {
        const tgt = highAtk[0];
        u.res -= 30;
        tgt.disarmed = 3;
        this.floatT(tgt.x, tgt.y, t('messages.brawler_disarm'), 'damage');
        this.floatT(u.x, u.y, t('messages.brawler_disarm'), 'heal');
        this.sfxAtk(u.cls);
        u.ha = true;
        await sl(200);
        return true;
      }
    }

    // Mage 화염폭발
    if (u.cls === 'mage' && u.res >= 40) {
      let targetCell = null, maxCluster = 0;
      for (let y = u.y - 1; y <= u.y + 1; y++) {
        for (let x = u.x - 1; x <= u.x + 1; x++) {
          if (x === u.x && y === u.y) continue;
          const cnt = al.filter(a => !isStealthed(a) && Math.abs(a.x - x) <= 1 && Math.abs(a.y - y) <= 1).length;
          if (cnt >= 2 && cnt > maxCluster) { maxCluster = cnt; targetCell = { x, y }; }
        }
      }
      if (targetCell) {
        u.res -= 40;
        for (let y = targetCell.y - 1; y <= targetCell.y + 1; y++) {
          for (let x = targetCell.x - 1; x <= targetCell.x + 1; x++) {
            const tgt = this.uAt(x, y);
            if (tgt && tgt.team === 'ally' && !isStealthed(tgt)) {
              const dmg = calcDmg(u, tgt);
              tgt.hp = Math.max(0, tgt.hp - dmg);
              this.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
              this.vfxSpawn(this.uSX(tgt.x, tgt.y) + UCX, this.uSY(tgt.x, tgt.y) + UCY,
                { count: 8, colors: ['#ff6600', '#ffaa00', '#ffff00'], shape: 'spark',
                  speed: 3, spread: 10, decay: 0.03, size: 4 });
              if (tgt.hp <= 0) { this.screenShake(); this.sfxDeath(); this.vfxDeath(tgt); this.deathA(tgt.id); this.units = this.units.filter(v => v.hp > 0); }
            }
          }
        }
        this.floatT(u.x, u.y, t('messages.mage_fireball'), 'heal');
        this.sfxAtk(u.cls);
        u.ha = true;
        await sl(300);
        this.units = this.units.filter(v => v.hp > 0);
        this.rUnits();
        return true;
      }
    }

    return false;
  },
  async eAI(u){const al=this.alive('ally');if(!al.length&&!this.hasAllyWall())return;
    const profile=AI_PROFILES[u.cls]||AI_PROFILES.novice;
    if(profile.avoidCombat&&u.hp>u.mhp*0.7){
      await this.eMv(u,al);return
    }
    const inR=this.atkC(u).filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&!isStealthed(v)}).map(c=>this.uAt(c.x,c.y));
    if(inR.length&&profile.targetPriority!=='never'){
      if(await this.tryUseSkill(u,profile)){return}
      const target=this.selectTarget(u,inR,profile);
      if(target){await this.eAtkAsync(u,target);return}
    }
    const gAtk=this.tryGateAtk(u);
    if(gAtk){await sl(250);return}
    const wClimb=await this.tryWallClimb(u);
    if(wClimb)return;
    await this.eMv(u,al);
    if(this.over)return;
    if(profile.avoidCombat&&u.hp>u.mhp*0.7)return;
    await sl(200);
    const postR=this.atkC(u).filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&!isStealthed(v)}).map(c=>this.uAt(c.x,c.y));
    if(postR.length&&profile.targetPriority!=='never'){
      if(await this.tryUseSkill(u,profile)){return}
      const target=this.selectTarget(u,postR,profile);
      if(target){await this.eAtkAsync(u,target);return}
    }
    this.tryGateAtk(u);
    },
  hasAllyWall(){return Object.keys(this.gateHP).some(k=>k.endsWith(',14')&&this.gateHP[k]>0)},
  tryGateAtk(u){
    for(const[dx,dy]of[[0,1],[0,-1],[-1,0],[1,0]]){
      const nx=u.x+dx,ny=u.y+dy;if(ny!==14||nx<0||nx>=COLS)continue;
      const tr=this.ter[ny][nx];if(tr!=='gate')continue;
      const k=nx+','+ny;if(!this.gateHP[k]||this.gateHP[k]<=0)continue;
      this.gateHP[k]--;
      this.floatT(nx,ny,t('messages.gate_hit'),'damage');this.sfxAtk(u.cls);
      this.vfxSpawn(this.uSX(nx,ny)+UCX,this.uSY(nx,ny)+UCY,{count:12,colors:['#aa8844','#ffcc66','#fff'],shape:'spark',speed:2,spread:12,decay:0.025,size:3});
      if(this.gateHP[k]<=0){
        this.ter[ny][nx]='plain';
        this.floatT(nx,ny,t('messages.gate_destroyed'),'damage');this.screenShake();this.sfxKill();
        this.rTer()}
      else this.rTer();
      return true}return false},
  async tryWallClimb(u){
    for(const[dx,dy]of[[0,1],[0,-1],[-1,0],[1,0]]){
      const nx=u.x+dx,ny=u.y+dy;if(ny!==14||nx<0||nx>=COLS)continue;
      const tr=this.ter[ny][nx];if(tr!=='wall')continue;
      if(Math.random()>0.3)continue;
      this._mvU(u,nx,ny);
      this.floatT(nx,ny,t('messages.ladder'),'heal');this.sfxMove();
      await sl(340);
      this.onBreach(u);
      return true}return false},
  onBreach(u){
    this.breached++;
    const s=this.cStage;if(!s)return;
    const limit=Math.ceil(s.tot/4);
    this.floatT(u.x,u.y,t('messages.breach')+` ${this.breached}/${limit}`,'damage');
    if(this.breached>=limit){this.over=true;this.showRes(false,t('messages.enemy_breached',{count:this.breached}))}},
  async eAtkAsync(a,tgt){
    if(tgt.team==='ally')this.scrollToUnit(tgt);
    await sl(250);
    this.eAtk(a,tgt);
    await sl(tgt.hp<=0?500:300)},
  eAtk(a,tgt){
    const dmg=calcDmg(a,tgt);
    tgt.hp=Math.max(0,tgt.hp-dmg);this.vfxAtk(a,tgt);this.sfxAtk(a.cls);this.shakeU(tgt.id);this.floatT(tgt.x,tgt.y,`-${dmg}`,'damage');
    if(a.furyBuff>0)this.floatT(a.x,a.y,t('messages.fury_buff'),'heal');
    procFury(a,tgt,this);
    if(tgt.hp>0&&a.hp>0&&mh(tgt.x,tgt.y,a.x,a.y)<=tgt.range&&!(tgt.stunned>0)){
      const cdmg=calcDmg(tgt,a);a.hp=Math.max(0,a.hp-cdmg);this.vfxAtk(tgt,a);this.sfxAtk(tgt.cls);this.shakeU(a.id);this.floatT(a.x,a.y,`-${cdmg}`,'damage');procFury(tgt,a,this);
    }
    if(tgt.hp<=0){this.screenShake();this.sfxKill();this.sfxDeath();this.vfxDeath(tgt);this.deathA(tgt.id);this.units=this.units.filter(u=>u.hp>0);setTimeout(()=>{this.rUnits()},500)}
    else if(a.hp<=0){this.screenShake();this.sfxDeath();this.vfxDeath(a);this.deathA(a.id);this.units=this.units.filter(u=>u.hp>0);setTimeout(()=>{this.rUnits()},500)}
    else this.rUnits()},
  async eMv(u,al){
    const origPos=u.origSpawn||{x:u.x,y:u.y};
    const profile=AI_PROFILES[u.cls]||AI_PROFILES.novice;
    const hpPct=u.hp/u.mhp;
    const shouldRetreat=hpPct<profile.retreatThreshold&&Math.random()<0.3;
    if(shouldRetreat&&!u.isBoss){
      const mc=this.eMvC(u);if(!mc.length)return;
      let bestMove=null,bestDist=Infinity;
      for(const m of mc){const d=mh(m.x,m.y,origPos.x,origPos.y);if(d<bestDist){bestDist=d;bestMove=m}}
      if(bestMove&&mh(bestMove.x,bestMove.y,origPos.x,origPos.y)<mh(u.x,u.y,origPos.x,origPos.y)){
        this._mvU(u,bestMove.x,bestMove.y);
        this.floatT(u.x,u.y,t('messages.retreat'),'damage');await sl(340);
        this.chkTrap(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);this.units=this.units.filter(v=>v.hp>0);setTimeout(()=>{this.rUnits()},500)}
        return
      }
    }
    let advLimit = this.cStage?.style === 'defense' ? 15 : 5;
    if(profile.style==='defensive') advLimit = this.cStage?.style === 'defense' ? 12 : 3;
    if(profile.style==='support') advLimit = this.cStage?.style === 'defense' ? 10 : 2;
    const advDist=mh(u.x,u.y,origPos.x,origPos.y);

    if(this.cStage?.style === 'defense' && !u.isBoss) {
      const allies = this.alive('enemy').filter(e => e.id !== u.id && !e.isBoss);
      if(allies.length > 0) {
        const nearestAllyDist = Math.min(...allies.map(a => mh(u.x, u.y, a.x, a.y)));
        const avgAllyY = allies.reduce((sum, a) => sum + a.y, 0) / allies.length;
        if(u.y > avgAllyY + 3) {
          return;
        }
        if(nearestAllyDist > 5) {
          advLimit = Math.min(advLimit, advDist + 2);
        }
      }
    }

    if(advDist>=advLimit&&!u.isBoss){return}

    const mc=this.eMvC(u);if(!mc.length)return;
    const validMoves=mc.filter(m=>mh(m.x,m.y,origPos.x,origPos.y)<=advLimit||u.isBoss);
    if(!validMoves.length)return;

    let bt=null,bd=Infinity;
    for(const a of al){if(isStealthed(a))continue;const d=mh(u.x,u.y,a.x,a.y);if(d<bd){bd=d;bt=a}}

    if(u.cls==='assassin'){
      let bestMove=null,bestScore=-Infinity;
      for(const m of validMoves){
        const tr=this.ter[m.y]?this.ter[m.y][m.x]:null;
        let score=0;
        if(tr==='forest')score+=50;
        if(bt)score+=(mh(u.x,u.y,bt.x,bt.y)-mh(m.x,m.y,bt.x,bt.y))*10;
        score+=(m.y-u.y)*3;
        if(score>bestScore){bestScore=score;bestMove=m}
      }
      if(bestMove){this._mvU(u,bestMove.x,bestMove.y);await sl(340);
        this.chkTrap(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits()},500);return}
        if(bestMove.y===14){this.onBreach(u)};return}
    }

    if(profile.guardMode&&!u.isBoss){
      const allies=this.alive('enemy').filter(e=>e.id!==u.id);
      if(allies.length){
        let bestMove=null,bestScore=-Infinity;
        for(const m of validMoves){
          let score=0;
          const avgAllyDist=allies.reduce((sum,a)=>sum+mh(m.x,m.y,a.x,a.y),0)/allies.length;
          score-=avgAllyDist*5;
          score-=mh(m.x,m.y,origPos.x,origPos.y)*profile.advanceBonus;
          if(score>bestScore){bestScore=score;bestMove=m}
        }
        if(bestMove){this._mvU(u,bestMove.x,bestMove.y);await sl(340);
          this.chkTrap(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits()},500);return}
          return
        }
      }
    }

    let cbt=null,cbd=Infinity;
    for(const a of al){if(isStealthed(a))continue;const d=mh(u.x,u.y,a.x,a.y);if(d<cbd){cbd=d;cbt=a}}
    if(profile.keepDistance&&cbt&&mh(u.x,u.y,cbt.x,cbt.y)<=2){
      let bestMove=null,bestDist=0;
      for(const m of validMoves){
        const dist=mh(m.x,m.y,cbt.x,cbt.y);
        if(dist>bestDist&&dist<=u.range){bestDist=dist;bestMove=m}
      }
      if(bestMove&&bestDist>mh(u.x,u.y,cbt.x,cbt.y)){
        this._mvU(u,bestMove.x,bestMove.y);await sl(340);
        this.chkTrap(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits()},500);return}
        return
      }
    }

    if(!bt||bd>8){const gateTarget={x:u.x<=4?4:5,y:13};
      let bc2=null,bs2=-Infinity;
      for(const c of validMoves){
        let s=-(mh(c.x,c.y,gateTarget.x,gateTarget.y))*10+(c.y-u.y)*(5+profile.advanceBonus);
        if(s>bs2){bs2=s;bc2=c}
      }
      if(bc2){this._mvU(u,bc2.x,bc2.y);await sl(340);
        this.chkTrap(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits()},500);return}
        return}
    }

    let bc=null,bs=-Infinity;
    for(const c of validMoves){
      let s=0;if(bt)s+=(mh(u.x,u.y,bt.x,bt.y)-mh(c.x,c.y,bt.x,bt.y))*10;
      s+=(c.y-u.y)*(3+profile.advanceBonus*0.3);if(s>bs){bs=s;bc=c}
    }

    if(bc){this._mvU(u,bc.x,bc.y);await sl(340);
      this.chkTrap(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits()},500);return}
      if(bc.y===14){this.onBreach(u)}
    }
  },

  chkEnd(){if(this.over)return;const al=this.alive('ally'),en=this.alive('enemy');
    this.units.filter(u=>u.cls==='summoner'&&u.hp<=0).forEach(deadSummoner=>{
      const summons=this.units.filter(s=>s.isSummon&&s.summonerId===deadSummoner.id);
      summons.forEach(s=>{
        this.floatT(s.x,s.y,t('messages.unsummoned'),'damage');
        this.vfxDeath(s);
      });
      this.units=this.units.filter(v=>!(v.isSummon&&v.summonerId===deadSummoner.id));
    });
    if(!al.length&&!this.hasAllyWall()){this.over=true;this.showRes(false,t('messages.all_defeated'));return}
    const s=this.cStage;if(s){const limit=Math.ceil(s.tot/4);
      if(this.breached>=limit){this.over=true;this.showRes(false,t('messages.enemy_breached',{count:this.breached}));return}}
    if(s&&this.eSpwn>=s.tot&&!en.length){this.over=true;this.cleared.add(s.id);this.showRes(true,t('messages.stage_clear',{stage_id:s.id,turn:this.turn}))}},
});

// ════════════════════════════════════════════
//  Section 5g: Battle-end & Navigation (from lobby.js)
// ════════════════════════════════════════════
Object.assign(G, {
  onBattleEnd(win) {
    // 처치한 적 기반 총 경험치 -> 생존 아군 균등 분배
    const deadEnemies = this.units.filter(u => u.team === 'enemy' && u.hp <= 0);
    const killPool = deadEnemies.reduce((s, u) => s + killExp(this.cStage ? this.cStage.id : 1, u.cls), 0);
    const survivors = this.units.filter(u => u.team === 'ally' && u.hp > 0 && u.uid);
    const killEach = survivors.length ? Math.floor(killPool / survivors.length) : 0;
    this._expResults = [];
    survivors.forEach(u => {
      const actE = (this.battleExp && this.battleExp[u.uid]) || 0;
      const total = actE + killEach;
      if (!total) return;
      const r = gainExp(u.uid, total);
      this._expResults.push({ uid: u.uid, exp: total, actExp: actE, killExp: killEach, leveled: r.leveled, prevLv: r.prevLv });
    });
    this._totalExp = killPool;
    this._deadEnemyCount = deadEnemies.length;
    if (win) {
      const reward = 50 + (this.cStage ? this.cStage.id * 30 : 0);
      this.gold += reward;
      if (this.cStage) this.cleared.add(this.cStage.id);
      saveGold(this.gold, [...this.cleared]);
    }
    this.units.filter(u => u.team === 'ally' && u.hp <= 0 && u.uid).forEach(u => {
      markDead(u.uid);
    });
    clearBattle();
  },

  returnToLobby() { location.href = 'index.html' },

  goNextStage(stage) {
    const party = loadParty();
    const filteredParty = party.filter(uid => { const ch = getChar(uid); return ch && !ch.dead });
    if (filteredParty.length >= MIN_P) {
      localStorage.setItem('game_nav', JSON.stringify({ cStage: stage, party: filteredParty }));
      location.href = 'battle.html';
    } else {
      localStorage.setItem('game_nav', JSON.stringify({ cStage: stage }));
      location.href = 'party-select.html';
    }
  },
});

// ════════════════════════════════════════════
//  Section 6: Init & Event Listeners (from boot.js)
// ════════════════════════════════════════════
window.G = G;

Object.assign(G, {
  _battleListenersInit: false,
  _initBattleListeners() {
    if (this._battleListenersInit) return;
    this._battleListenersInit = true;
    document.getElementById('minimap').addEventListener('click', e => G.mmClick(e));
    document.getElementById('map-container').addEventListener('scroll', () => G.rMMvp());
    document.getElementById('iso-world').addEventListener('click', e => {
      const w = document.getElementById('iso-world');
      const rect = w.getBoundingClientRect();
      const px = e.clientX - rect.left, py = e.clientY - rect.top;
      const hit = G.isoHit(px, py);
      if (!hit) return;
      const { c, r } = hit;
      if (c < 0 || c >= COLS || r < 0 || r >= ROWS) return;
      if (G.awPM) { G.cellCk(c, r); return }
      const u = G.uAt(c, r);
      if (u && u.team === 'ally' && !G.sel) { G.selU(u); return }
      if (u && u.team === 'ally' && G.sel && u.id === G.sel.id) { G.clrSel(); return }
      G.cellCk(c, r);
    });
  },

  _initBattlePage() {
    const nav = loadNav();
    clearNav();
    if (nav?.resume) {
      const bs = loadBattle();
      if (bs) {
        this._initBattleListeners();
        this.cStage = bs.stage; this.party = bs.party;
        this.ter = bs.ter; this.turn = bs.turn; this.eSpwn = bs.eSpwn; this.eQ = bs.eQ;
        this.breached = bs.breached; this.gateHP = bs.gateHP; this.wallHP = bs.wallHP; this.nid = bs.nid;
        this.battleExp = bs.battleExp || {};
        this.allyPos = bs.allyPos || {};
        this.units = bs.units; this.phase = 'player'; this.sel = null; this.over = false;
        this.awPM = false; this.anim = false; this.camDir = 0;
        document.querySelector('#cam-dir .cd-arrow').textContent = CARR[0];
        document.querySelector('#cam-dir .cd-label').textContent = CLAB[0];
        const w = document.getElementById('iso-world');
        w.querySelectorAll('.iso-tile,.unit-sprite,.float-text').forEach(e => e.remove());
        this.layW(); this.vfxInit(); this.rTer(); this.rUnits(); this.uUI(); this.defI(); this.rMM();
        this.bgmStart();
        setTimeout(() => this.scrollToAllies(), 50);
      } else { location.href = 'index.html' }
    } else if (nav?.cStage) {
      this.cStage = nav.cStage;
      if (nav.party) { this.party = nav.party } else { this.party = loadParty() }
      if (!this.party || this.party.length < MIN_P) { location.href = 'index.html'; return }
      this._initBattleListeners();
      this.eSpwn = 0; this.eQ = [...this.cStage.en];
      this.init();
    } else { location.href = 'index.html' }
  },
});

document.addEventListener('keydown', e => {
  if (document.body.dataset.page !== 'battle') return;
  if (e.key === 'q' || e.key === 'Q') G.rotCam(-1);
  if (e.key === 'e' || e.key === 'E') G.rotCam(1);
  if (e.key === 'Escape') { G.closeSettings() }
});

window.addEventListener('DOMContentLoaded', async () => {
  G.loadSett();
  const goldData = loadGoldData();
  G.gold = goldData.gold;
  G.cleared = goldData.cleared;

  await i18nInit();

  loadTilesets().then(() => G._initBattlePage());
});

window.addEventListener('resize', () => { if (G.ter && G.ter.length) { G.layW() } });
