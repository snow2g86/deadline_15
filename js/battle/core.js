// ═══════════════════════════════════════════
//  battle/core.js — G Object (core definition)
// ═══════════════════════════════════════════

const G = {
    ter: [], units: [], nid: 1, turn: 1, phase: 'player',
    sel: null, mvT: [], atkT: [], healT: [],
    awPM: false, skillMode: false, preMv: null, over: false, anim: false,
    cStage: null, eSpwn: 0, eQ: [], cleared: new Set(),
    party: [], camDir: 0, battleExp: {}, traps: [], poisonMists: [], eFormPos: [],
    _killCount: 0, _killExpPool: 0, _deadAllyUids: [],

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

    _selectRandomSiegeType() {
        const types = [
            { type: 'bomb', weight: 40 },
            { type: 'shield', weight: 30 },
            { type: 'evasion', weight: 20 },
            { type: 'detour', weight: 10 }
        ];
        const total = types.reduce((s, t) => s + t.weight, 0);
        let rand = Math.random() * total;
        for (const t of types) {
            if (rand < t.weight) return t.type;
            rand -= t.weight;
        }
        return 'bomb';
    },
    _createSiegeItem(type) {
        const itemDefs = {
            'bomb': { type: 'bomb', name: '💣 폭탄', description: '폭발로 주변 피해', targetType: 'self' },
            'shield': { type: 'shield', name: '🛡️ 방어막', description: '일시적 방어 증가', targetType: 'self' },
            'evasion': { type: 'evasion', name: '⚡ 회피', description: '다음 공격 회피', targetType: 'self' },
            'detour': { type: 'detour', name: '🛣️ 우회로', description: '이동 경로 개선', targetType: 'self' }
        };
        const def = itemDefs[type] || itemDefs['bomb'];
        return {
            id: Math.random(),
            type: def.type,
            name: def.name,
            description: def.description,
            targetType: def.targetType,
            cooldown: 0
        };
    },
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
        this._killCount = 0; this._killExpPool = 0; this._deadAllyUids = [];
        this.siegeMode = false; this._curSiege = null; this.itemMenuOpen = false;
        this._battlePotions = []; this._battlePotionIndices = [];
        this._siegeItems = []; this._siegeInvIndices = [];
        if (typeof loadInventory === 'function') {
            const inv = loadInventory();
            for (let i = 0; i < inv.length; i++) {
                if (inv[i].type === 'battle_potion') {
                    this._battlePotions.push(inv[i]);
                    this._battlePotionIndices.push(i);
                } else if (inv[i].type === 'siege') {
                    this._siegeItems.push(inv[i]);
                    this._siegeInvIndices.push(i);
                }
            }
        }
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
        setTimeout(() => this.scrollToAllies(), 50)
    },
    _rmDead() {
        this.units.forEach(u => {
            if (u.hp <= 0) {
                if (u.isSummon && u.summonerId) {
                    const summoner = this.units.find(s => s.id === u.summonerId && s.hp > 0 && s.skillLv && s.skillLv['summoner_soulbond'] >= 1);
                    if (summoner) { summoner.res = Math.min(summoner.maxRes, summoner.res + 40); this.floatT(summoner.x, summoner.y, t('messages.soulbond_restore'), 'heal') }
                }
                if (u.team === 'enemy' && !u._counted) {
                    u._counted = true;
                    this._killCount++;
                    this._killExpPool += killExp(this.cStage ? this.cStage.id : 1, u.cls);
                }
                if (u.team === 'ally' && u.uid && !u._counted) {
                    u._counted = true;
                    this._deadAllyUids.push(u.uid);
                }
            }
        });
        this.units = this.units.filter(u => u.hp > 0);
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
        const isOffense = this.cStage && this.cStage.style === 'offense';
        for (let r = 0; r < ROWS; r++) {
            if (!isOffense && r === 14) { this.ter[r] = wallRow(r) }
            else if (!isOffense && r === 13) { this.ter[r] = moatRow() }
            else if (isOffense && r === 0) { this.ter[r] = wallRow(r) }
            else if (isOffense && r === 1) { this.ter[r] = moatRow() }
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
        if (team === 'enemy') {
            u.origSpawn = { x, y };
            u.siegeItems = [this._createSiegeItem(this._selectRandomSiegeType())];
        }
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
            const trapStun = trap.stun || 2;
            u.hp = Math.max(0, u.hp - trap.dmg); u.stunned = Math.max(u.stunned, trapStun);
            this.traps = this.traps.filter(t => t !== trap);
            this.floatT(u.x, u.y, t('messages.trap_triggered', {dmg: trap.dmg}), 'damage'); this.floatT(u.x, u.y, t('messages.trap_stun', {turns: trapStun}), 'damage');
            this.vfxSpawn(this.uSX(u.x, u.y) + UCX, this.uSY(u.x, u.y) + UCY, { count: 8, colors: ['#f84', '#f80', '#ff4'], shape: 'spark', speed: 3, spread: 8, decay: 0.03, size: 2 });
            return true
        }
        return false
    },
    _chkSpearwall(enemy) {
        if (enemy.team !== 'enemy' || enemy.hp <= 0) return;
        const lancers = this.units.filter(u => u.team === 'ally' && u.hp > 0 && u.skillLv && u.skillLv['lancer_spearwall'] >= 1 && !u._spearwallUsed && !(u.stunned > 0) && !(u.frozen > 0) && mh(u.x, u.y, enemy.x, enemy.y) <= u.range);
        if (lancers.length) {
            const l = lancers[0]; l._spearwallUsed = true;
            const dmg = Math.max(1, Math.round(l.atk * 0.5) - enemy.def); enemy.hp = Math.max(0, enemy.hp - dmg);
            this.vfxAtk(l, enemy); this.sfxAtk(l.cls); this.shakeU(enemy.id);
            this.floatT(enemy.x, enemy.y, `-${dmg}`, 'damage'); this.floatT(l.x, l.y, t('messages.lancer_spearwall'), 'heal');
            if (enemy.hp <= 0) { this.sfxDeath(); this.vfxDeath(enemy); this.deathA(enemy.id) }
        }
    },

    spawnW() {
        if (!this.cStage) return; const s = this.cStage, rem = s.tot - this.eSpwn; if (rem <= 0) return;

        // 동시 적군 수 체크: 20명 이상이면 스폰 미루기
        const activeEnemies = this.units.filter(u => u.team === 'enemy' && u.hp > 0).length;
        const maxConcurrent = 20;
        if (activeEnemies >= maxConcurrent) return;

        const cnt = Math.min(s.spw, rem, this.eQ.length, maxConcurrent - activeEnemies);
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
            const isOff = this.cStage && this.cStage.style === 'offense';
            const spawnRows = isOff ? [2, 3] : [0, 1];
            for (let c = 0; c < COLS; c++)if (!this.uAt(c, spawnRows[0])) op.push({ x: c, y: spawnRows[0] });
            if (op.length < cnt) for (let c = 0; c < COLS; c++)if (!this.uAt(c, spawnRows[1])) op.push({ x: c, y: spawnRows[1] });
            shuffle(op);
            for (let i = 0; i < Math.min(cnt, op.length); i++) {
                const c = this.eQ.shift(); if (!c) break;
                this.addU('enemy', c, op[i].x, op[i].y); this.eSpwn++
            }
        }
    },

    mvC(u) {
        if (u.stunned > 0 || u.frozen > 0) return []; const res = [], vis = new Map(), q = [{ x: u.x, y: u.y, c: 0 }], K = (a, b) => a + ',' + b;
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
