// ═══════════════════════════════════════════
//  tools/battle-sim/policy.js — 시험용 아군(클랜원) 자동 조작 (결정적, 난수 안 씀)
//
//  게임 화면의 버튼과 같은 입구(ActionManager.actMove/actAttack/actSkill/askFace/faceDone/actShove/actSiege/actPotion + cellCk)를
//  그대로 부르고, 내린 명령을 모두 기록한다 → 2b 는 이 정책을 옮길 필요 없이 기록된 명령을 다시 재생하면 된다.
//  ※ 정책은 Math.random 을 절대 부르지 않는다 (부르면 전투 난수 열이 바뀜). calcDmg 도 부르지 않는다 (치명타 판정이 난수를 씀).
// ═══════════════════════════════════════════
'use strict';

const OPTS_DEFAULT = {
  passive: false,        // true: 공격·이동·스킬 없이 방어 태세만 (교착 시험용)
  stance: 'auto',        // 할 일이 없을 때: 'auto' | 'wait' | 'defend' | 'overwatch'
  shoveEvery: 4,         // 밀치기로 충돌 피해를 줄 수 있으면 그 유닛의 n번째 차례마다 밀치기 (0 = 안 함)
  useItems: true,        // 물약·공성 아이템 사용
  skills: true,          // 스킬 사용
  chestBonus: 15,        // 이동 칸 점수: 보물상자 칸 가점
  attackOnly: [],        // 이 직업들은 스킬을 쓰지 않음 (일반 공격의 마법부여 효과 시험용)
  hold: false,           // true: 제자리 — 이동·스킬·밀치기 없이, 칠 수 있으면 일반 공격, 아니면 방어 태세
                         // 'breach': 제자리 + 적이 돌파 한도(ceil(tot/4))만큼 넘어온 뒤에만 공격 (돌파 패배 시험용)
  undoEvery: 0,          // 그 유닛의 n번째 차례마다 첫 이동을 한 번 취소(actCancel)했다가 다시 고름 (0 = 안 함)
};

class Policy {
  constructor(env, opts, record) {
    this.env = env; this.g = env.g;
    this.o = Object.assign({}, OPTS_DEFAULT, opts || {});
    this.record = record;                // (cmd) => void
    this.turnN = {};                     // 유닛별 차례 수
    this.skillUse = {};                  // `${unitId}:${skillId}` → 사용 횟수 (돌려 가며 쓰기)
    this.busy = false;
  }

  // ── 상태 조회 (모두 부작용·난수 없음) ──
  get S() { return this.g.GameStore; }
  foes(u) { return this.S.units.filter(v => v.hp > 0 && v.team !== u.team && !this.g.isStealthed(v)); }
  friends(u) { return this.S.units.filter(v => v.hp > 0 && v.team === u.team && v.id !== u.id); }
  tile(x, y) { return this.S.ter[y] ? this.S.ter[y][x] : null; }
  mh(a, b, c, d) { return Math.abs(a - c) + Math.abs(b - d); }
  rangeAt(u, x, y) { return u.range + (this.tile(x, y) === 'hill' && u.range > 1 ? this.g.TACTIC.highRange : 0); }
  // u 가 (x,y)에 서 있다고 칠 때 일반 공격으로 칠 수 있는(엄호되지 않은) 적
  hittableFrom(u, x, y) {
    const UM = this.g.UnitManager, me = { id: u.id, team: u.team, cls: u.cls, x, y };
    const rng = this.rangeAt(u, x, y);
    return this.foes(u).filter(v => this.mh(x, y, v.x, v.y) <= rng && !(x === v.x && y === v.y) && !UM.coverOf(me, v));
  }
  // 공격 점수: 처치 예상 > 전술 보너스 > 낮은 HP (calcDmg 대신 단순 추정: 공격력 - 방어력)
  atkScore(u, x, y, v) {
    const me = { id: u.id, team: u.team, cls: u.cls, x, y };
    const tb = this.g.UnitManager.tacticBonus(me, v);
    const est = Math.max(1, Math.round((u.atk - v.def) * tb.mul));
    return (est >= v.hp ? 1000 : 0) + (tb.mul - 1) * 100 - v.hp / v.mhp * 50 - (this.g.UnitManager.interceptOf(me, v) ? 60 : 0);
  }
  bestTarget(u, list) {
    let best = null, bs = -Infinity;
    for (const v of list) { const s = this.atkScore(u, u.x, u.y, v); if (s > bs || (s === bs && v.id < best.id)) { bs = s; best = v; } }
    return best;
  }
  nearestFoeDist(u, x, y) {
    let d = Infinity; for (const v of this.foes(u)) d = Math.min(d, this.mh(x, y, v.x, v.y)); return d;
  }
  injured(u, range, pct) {
    return this.S.units.filter(v => v.team === u.team && v.hp > 0 && v.hp < v.mhp * pct && this.mh(u.x, u.y, v.x, v.y) <= range)
      .sort((a, b) => a.hp / a.mhp - b.hp / b.mhp || a.id - b.id);
  }

  // ── 차례 시작 (ActionManager.selU 뒤에 불림) ──
  async turn(u) {
    if (this.busy) return;
    this.busy = true;
    try { await this._turn(u); } finally { this.busy = false; }
  }
  async _turn(u) {
    const env = this.env, start = env.turnEnds;
    this.turnN[u.id] = (this.turnN[u.id] || 0) + 1;
    const failed = new Set();
    let moved = false;
    for (let guard = 0; guard < 8; guard++) {
      if (env.turnEnds !== start || env.ended) return;
      const step = this.decide(u, moved, failed);
      const ok = this.exec(u, step);
      if (!ok) { failed.add(step.key || step.op); continue; }
      if (step.op === 'move' || step.op === 'climb') { moved = true; await env.sleep(400); continue; }
      if (step.op === 'undo') { moved = false; failed.add('undo'); await env.sleep(400); continue; }
      // 공격·회복·밀치기는 연출 시간 뒤(타이머)에 차례가 끝남. 나머지는 바로 끝나야 정상 — 안 끝났으면(스킬 환불 등) 다른 수
      if (step.op === 'attack' || step.op === 'heal' || step.op === 'shove') return;
      if (env.turnEnds === start) { failed.add(step.key || step.op); continue; }
      return;
    }
    if (env.turnEnds === start && !env.ended) this.exec(u, { op: 'wait', dx: 0, dy: 0 });
  }

  // ── 할 일 고르기 ──
  decide(u, moved, failed) {
    const S = this.S;
    if (this.o.passive) return this.stance(u, 'defend', failed);
    if (this.o.hold) {
      const wait = this.o.hold === 'breach' && S.breached < Math.ceil(S.cStage.tot / 4);
      const list = failed.has('attack') || wait ? [] : this.hittableFrom(u, u.x, u.y);
      if (list.length) { const v = this.bestTarget(u, list); return { op: 'attack', key: 'attack', x: v.x, y: v.y, target: v.id }; }
      return this.stance(u, 'defend', failed);
    }
    // 0) 이동 취소 시험: 정해진 차례에 방금 한 이동을 되돌림
    if (moved && this.o.undoEvery && !failed.has('undo') && this.turnN[u.id] % this.o.undoEvery === 0 && S.preMv) return { op: 'undo', key: 'undo' };
    // 1) 물약: 위급하면 회복, 자원이 바닥이면 자원, 적이 가까우면 공격 강화 (자기 자신에게)
    if (this.o.useItems && !failed.has('potion')) {
      const pots = S._battlePotions || [], find = id => pots.findIndex(p => p.potionId === id);
      let id = null;
      if (u.hp < u.mhp * 0.35 && find('potion_heal') >= 0) id = 'potion_heal';
      else if ((u.resType === 'mana' || u.resType === 'energy') && u.res < u.maxRes * 0.2 && find('potion_resource') >= 0) id = 'potion_resource';
      else if (find('potion_atk_buff') >= 0 && this.nearestFoeDist(u, u.x, u.y) <= 3 && !(u.buffs || []).some(b => b.type === 'atk_up')) id = 'potion_atk_buff';
      if (id) return { op: 'potion', key: 'potion', idx: find(id), potion: id, x: u.x, y: u.y };
    }
    // 2) 공성 아이템 (다리·폭파·사다리) — 쓸 곳이 있으면 한 번씩
    if (this.o.useItems && !failed.has('siege') && (S._siegeItems || []).length) {
      const st = this.siegeStep(u, moved);
      if (st) return st;
    }
    // 3) 스킬 (적게 쓴 스킬부터 돌려 가며)
    if (this.o.skills && !u.channeling && this.o.attackOnly.indexOf(u.cls) < 0) {
      const st = this.skillStep(u, failed);
      if (st) return st;
    }
    // 4) 사제: 다친 클랜원 회복
    if (u.role === 'healer' && !failed.has('heal')) {
      const cand = this.g.Grid.atkCells(u).map(c => this.g.UnitManager.uAt(c.x, c.y))
        .filter(v => v && v.team === 'ally' && v.id !== u.id && v.hp < v.mhp * 0.8)
        .sort((a, b) => a.hp / a.mhp - b.hp / b.mhp || a.id - b.id);
      if (cand.length) return { op: 'heal', key: 'heal', x: cand[0].x, y: cand[0].y, target: cand[0].id };
    }
    // 5) 밀치기 (충돌 피해를 줄 수 있을 때, 정해진 주기로)
    if (this.o.shoveEvery && !failed.has('shove') && this.turnN[u.id] % this.o.shoveEvery === 0) {
      const ts = this.g.UnitManager.shoveTargets(u).filter(v => { const p = this.g.UnitManager.shovePlan(u, v); return p.ok && !p.to; });
      if (ts.length) return { op: 'shove', key: 'shove', x: ts[0].x, y: ts[0].y, target: ts[0].id };
    }
    // 6) 일반 공격
    if (!failed.has('attack')) {
      const list = this.hittableFrom(u, u.x, u.y);
      if (list.length) { const v = this.bestTarget(u, list); return { op: 'attack', key: 'attack', x: v.x, y: v.y, target: v.id }; }
    }
    // 7) 이동
    if (!moved && !failed.has('move') && !u.hm) {
      const m = this.moveStep(u);
      if (m) return m;
    }
    // 8) 마무리 자세
    return this.stance(u, this.o.stance, failed);
  }

  // 할 일이 없을 때: 원거리는 경계, 다쳤거나 탱커면 방어 태세, 아니면 대기. 방향은 게임의 추천(faceOptions best)
  stance(u, mode, failed) {
    const opts = this.g.ActionManager.faceOptions(u), best = opts.find(o => o.best) || opts[0];
    let kind = mode;
    if (kind === 'auto') {
      const d = this.nearestFoeDist(u, u.x, u.y);
      if (u.range > 1 && d <= u.range + 3) kind = 'overwatch';
      else if (u.hp < u.mhp * 0.5 || u.cls === 'knight' || u.cls === 'lancer') kind = 'defend';
      else kind = 'wait';
    }
    if (kind !== 'wait' && (u.ha || failed.has(kind))) kind = 'wait';
    return { op: kind, key: kind, dx: best.dx, dy: best.dy };
  }

  // ── 이동 칸 고르기 ──
  cellScore(u, x, y) {
    const g = this.g, S = this.S, tile = this.tile(x, y);
    let s = 0;
    if (u.role === 'healer') {
      const hurt = this.S.units.filter(v => v.team === 'ally' && v.hp > 0 && v.id !== u.id && v.hp < v.mhp * 0.8);
      const dHurt = hurt.length ? Math.min(...hurt.map(v => this.mh(x, y, v.x, v.y))) : 0;
      const dAlly = Math.min(99, ...this.friends(u).map(v => this.mh(x, y, v.x, v.y)));
      const dFoe = this.nearestFoeDist(u, x, y);
      s -= Math.max(0, dHurt - u.range) * 10 + Math.max(0, dAlly - 2) * 4 + (dFoe < 3 ? (3 - dFoe) * 15 : 0);
    } else {
      const hit = this.hittableFrom(u, x, y);
      if (hit.length) {
        let best = -Infinity; for (const v of hit) best = Math.max(best, this.atkScore(u, x, y, v));
        s += 200 + best;
        if (u.range > 1) s += this.mh(x, y, ...this.nearest(u, x, y)) * 3;   // 원거리: 떨어져서 쏘기
      } else s -= this.nearestFoeDist(u, x, y) * 10;
    }
    if (tile === 'forest') s += 3;
    if (tile === 'hill' && u.range > 1) s += 6;
    if (tile === 'shallow') s -= 5;
    if (g.UnitManager.nearLava(x, y)) s -= 10;
    if (S._hazard && S._hazard.dot && u._hazardDot && S.safeZones && S.safeZones.has(x + ',' + y)) s += 25;
    if (u.team === 'ally' && !u.isSummon && g.Chest.at(S, x, y)) s += this.o.chestBonus;
    // 숲 속 암살자: 적과 겹치면(은신 겹침) 암살 준비
    if (u.cls === 'assassin' && tile === 'forest') { const o = g.UnitManager.uAt(x, y); s += (o && o.team !== u.team) ? 400 : 20; }
    return s;
  }
  nearest(u, x, y) { let b = null, d = Infinity; for (const v of this.foes(u)) { const k = this.mh(x, y, v.x, v.y); if (k < d) { d = k; b = v; } } return b ? [b.x, b.y] : [x, y]; }
  moveStep(u) {
    const cells = this.g.Grid.mvCells(u);
    if (!cells.length) return null;
    let best = null, bs = this.cellScore(u, u.x, u.y);
    for (const c of cells) {
      const s = this.cellScore(u, c.x, c.y);
      if (s > bs || (best && s === bs && (c.y < best.y || (c.y === best.y && c.x < best.x)))) { bs = s; best = c; }
    }
    return best ? { op: 'move', key: 'move', x: best.x, y: best.y, vault: !!best.vault } : null;
  }

  // ── 공성 아이템 ──
  siegeStep(u, moved) {
    const S = this.S, g = this.g;
    for (let i = 0; i < S._siegeItems.length; i++) {
      const si = S._siegeItems[i], def = g.SIEGE_ITEMS.find(d => d.id === si.siegeId); if (!def) continue;
      if (def.effect === 'climb' && moved) continue;
      const cells = [];
      for (let r = 0; r < g.ROWS; r++) for (let c = 0; c < g.COLS; c++) {
        if (this.mh(u.x, u.y, c, r) > def.range) continue;
        const t = S.ter[r][c];
        if ((def.targetType === 'wall_rock' && (t === 'wall' || t === 'gate' || t === 'rock')) || (def.targetType === 'wall' && (t === 'wall' || t === 'gate')) || (def.targetType === 'water' && t === 'water')) cells.push({ x: c, y: r });
      }
      // 적 쪽(위)으로 가장 가까운 칸
      cells.sort((a, b) => this.mh(u.x, u.y, a.x, a.y) - this.mh(u.x, u.y, b.x, b.y) || a.y - b.y || a.x - b.x);
      const c = cells.find(p => def.effect !== 'climb' || (p.y < u.y && p.x === u.x));
      if (c) return { op: def.effect === 'climb' ? 'climb' : 'siege', key: 'siege', idx: i, siege: def.id, x: c.x, y: c.y };
    }
    return null;
  }

  // ── 스킬: 습득한 스킬을 적게 쓴 순으로 시도 ──
  skillStep(u, failed) {
    const g = this.g, skills = g.getUnitSkills(u);
    const used = sk => this.skillUse[u.id + ':' + sk.id] || 0;
    // 아직 한 번도 안 쓴 스킬이 자원 부족이면, 이미 쓴 스킬에 자원을 쓰지 않고 모아 둔다 (모든 스킬을 한 번씩은 쓰게)
    const unusedCosts = skills.filter(sk => !sk.passive && sk.cost !== undefined && !used(sk)).map(sk => sk.cost);
    const saving = unusedCosts.length && u.res < Math.min(...unusedCosts);
    const order = skills.map((sk, idx) => ({ sk, idx })).filter(o => !o.sk.passive && o.sk.cost !== undefined && u.res >= o.sk.cost && !failed.has('skill:' + o.sk.id) && !(saving && used(o.sk)))
      .sort((a, b) => (this.skillUse[u.id + ':' + a.sk.id] || 0) - (this.skillUse[u.id + ':' + b.sk.id] || 0) || a.idx - b.idx);
    for (const { sk, idx } of order) {
      const h = g.SKILL_HANDLERS[sk.id]; if (!h) continue;
      const cell = this.skillTarget(u, sk, h);
      if (cell) return { op: 'skill', key: 'skill:' + sk.id, id: sk.id, idx, x: cell.x, y: cell.y };
    }
    return null;
  }
  // 그 스킬을 지금 쓸 만한지 + 대상 칸. handler.target 은 부작용 없는 것만 부름 (소환사·소환 강화의 "실패" 글자 띄우기는 연출)
  skillTarget(u, sk, h) {
    const g = this.g, S = this.S, UM = g.UnitManager, id = sk.id;
    const foeAt = (c) => { const v = UM.uAt(c.x, c.y); return v && v.team !== u.team && v.hp > 0 ? v : null; };
    const count3 = (cx, cy) => this.foes(u).filter(v => Math.abs(v.x - cx) <= 1 && Math.abs(v.y - cy) <= 1).length;
    const lowest = (cells) => { let b = null; for (const c of cells) { const v = foeAt(c); if (v && (!b || v.hp < b.v.hp || (v.hp === b.v.hp && v.id < b.v.id))) b = { c, v }; } return b ? b.c : null; };
    const self = { x: u.x, y: u.y };
    const T = () => { const r = h.target(u, sk, g.G); return Array.isArray(r) ? r : r; };
    switch (id) {
      case 'warrior_cleave': return this.foes(u).some(v => Math.abs(v.x - u.x) <= 1 && Math.abs(v.y - u.y) <= 1) ? self : null;
      case 'priest_massheal': return this.injured(u, sk.healRange || 6, 0.75).length >= 1 ? self : null;
      case 'priest_sanctuary': return this.injured(u, sk.sanctuaryRange || 6, 0.85).length >= 2 ? self : null;
      case 'lancer_phalanx': return this.friends(u).filter(v => this.mh(u.x, u.y, v.x, v.y) <= 2).length >= 1 && this.nearestFoeDist(u, u.x, u.y) <= 4 ? self : null;
      case 'assassin_smoke': return !g.isStealthed(u) && this.nearestFoeDist(u, u.x, u.y) <= 5 ? self : null;
      case 'assassin_assassinate': { const r = T(); return r === 'instant' ? self : null; }
      case 'knight_switch': {
        if (u.hp < u.mhp * 0.6) return null;
        const r = T(); if (!Array.isArray(r)) return null;
        const v = r.map(c => UM.uAt(c.x, c.y)).filter(v => v && v.hp < v.mhp * 0.45 && !v.isSummon).sort((a, b) => a.hp - b.hp)[0];
        return v ? { x: v.x, y: v.y } : null;
      }
      case 'knight_sacrifice': {
        const r = T(); if (!Array.isArray(r)) return null;
        const v = r.map(c => UM.uAt(c.x, c.y)).filter(v => v && v.hp < v.mhp * 0.6 && !v._sacrificeKnight).sort((a, b) => a.hp - b.hp)[0];
        return v ? { x: v.x, y: v.y } : null;
      }
      case 'shaman_exalt': {
        const r = T(); if (!Array.isArray(r)) return null;
        const v = r.map(c => UM.uAt(c.x, c.y)).filter(v => v && !v.isSummon && !(v.buffs || []).some(b => b.source === 'shaman_exalt') && this.nearestFoeDist(v, v.x, v.y) <= 5)
          .sort((a, b) => b.atk - a.atk || a.id - b.id)[0];
        return v ? { x: v.x, y: v.y } : null;
      }
      case 'priest_purify': { const r = T(); return Array.isArray(r) && r.length ? r[0] : null; }
      case 'novice_firstaid': {
        const r = T(); if (!Array.isArray(r)) return null;
        const v = r.map(c => UM.uAt(c.x, c.y)).filter(v => v && v.hp < v.mhp * 0.7).sort((a, b) => a.hp / a.mhp - b.hp / b.mhp)[0];
        return v ? { x: v.x, y: v.y } : null;
      }
      case 'summoner_summon_spirit': case 'summoner_summon_golem': {
        if (S.units.some(s => s.isSummon && s.summonerId === u.id)) return null;   // target() 가 '한도' 글자를 띄우기 전에 거름
        const r = T(); if (!Array.isArray(r) || !r.length) return null;
        let b = null, bd = Infinity; for (const c of r) { const d = this.nearestFoeDist(u, c.x, c.y); if (d < bd || (d === bd && (c.y < b.y || (c.y === b.y && c.x < b.x)))) { bd = d; b = c; } }
        return bd <= 8 ? b : null;
      }
      case 'summoner_empower': {
        const s = S.units.find(v => v.isSummon && v.summonerId === u.id && v.hp > 0 && !(v._empowerTurns > 0));
        return s && this.nearestFoeDist(s, s.x, s.y) <= 4 ? { x: s.x, y: s.y } : null;
      }
      case 'summoner_soulburst': {
        const s = S.units.find(v => v.isSummon && v.summonerId === u.id && v.hp > 0);
        return s && count3(s.x, s.y) >= 1 && (s.summonTurns <= 2 || count3(s.x, s.y) >= 2) ? { x: s.x, y: s.y } : null;
      }
      case 'archer_dash': {
        if (this.hittableFrom(u, u.x, u.y).length) return null;
        const r = T(); if (!Array.isArray(r)) return null;
        let b = null, bs = -Infinity; for (const c of r) { const hit = this.hittableFrom(u, c.x, c.y).length; const s = (hit ? 100 : 0) - this.nearestFoeDist(u, c.x, c.y); if (s > bs) { bs = s; b = c; } }
        return b && bs > -6 ? b : null;
      }
      case 'sapper_trap': {
        if (this.nearestFoeDist(u, u.x, u.y) > 5) return null;
        const r = T(); if (!Array.isArray(r) || !r.length) return null;
        return r.slice().sort((a, b) => this.nearestFoeDist(u, a.x, a.y) - this.nearestFoeDist(u, b.x, b.y) || a.y - b.y || a.x - b.x)[0];
      }
      case 'sapper_excavate': { const r = T(); return Array.isArray(r) && r.length ? r[0] : null; }
      case 'sapper_detonate': {
        const r = T(); if (!Array.isArray(r)) return null;
        return r.find(c => count3(c.x, c.y) >= 1) || null;
      }
      case 'mage_grandwall': {
        if (this.skillUse[u.id + ':' + id]) return null;   // 한 번만 (지형을 막아 버리지 않게)
        if (this.nearestFoeDist(u, u.x, u.y) > 5) return null;
        const r = T(); if (!Array.isArray(r) || !r.length) return null;
        return r.slice().sort((a, b) => this.nearestFoeDist(u, a.x, a.y) - this.nearestFoeDist(u, b.x, b.y) || a.y - b.y || a.x - b.x)[0];
      }
      case 'mage_fireburst': case 'archer_steelrain': case 'shaman_poisonmist': {
        const r = T(); if (!Array.isArray(r)) return null;
        let b = null, bn = 0; for (const c of r) { const n = count3(c.x, c.y); if (n > bn) { bn = n; b = c; } }
        return b && (bn >= 2 || id !== 'shaman_poisonmist') ? b : null;
      }
      case 'lancer_pierce': {
        const r = T(); if (!Array.isArray(r) || !r.length) return null;
        let b = null, bn = 0;
        for (const c of r) { const dx = Math.sign(c.x - u.x), dy = Math.sign(c.y - u.y); let n = 0; for (let i = 1; i <= (sk.pierceLen || 3); i++) { if (foeAt({ x: u.x + dx * i, y: u.y + dy * i })) n++; } if (n > bn) { bn = n; b = c; } }
        return b;
      }
      case 'brawler_disarm': {
        const r = T(); if (!Array.isArray(r)) return null;
        const v = r.map(foeAt).filter(v => v && !(v.disarmed > 0)).sort((a, b) => b.atk - a.atk || a.id - b.id)[0];
        return v ? { x: v.x, y: v.y } : null;
      }
      case 'shaman_curse': {
        const r = T(); if (!Array.isArray(r)) return null;
        const v = r.map(foeAt).filter(v => v && !v._cursed).sort((a, b) => b.mhp - a.mhp || a.id - b.id)[0];
        return v ? { x: v.x, y: v.y } : null;
      }
      case 'knight_capture': {
        const r = T(); if (!Array.isArray(r)) return null;
        const v = r.map(foeAt).filter(v => v && this.mh(u.x, u.y, v.x, v.y) >= 2 && v.range > 1).sort((a, b) => a.hp - b.hp)[0]
          || r.map(foeAt).filter(v => v && this.mh(u.x, u.y, v.x, v.y) >= 2 && v.cls === 'knight')[0];
        return v ? { x: v.x, y: v.y } : null;
      }
      default: {
        // 적 하나를 고르는 스킬 (강타·치명타·강습·차징·빙결·저격·연속사격·돌던지기·박치기·연타·파쇄·돌격·영혼 쇄도·습격 등)
        const r = T(); if (!Array.isArray(r) || !r.length) return null;
        return lowest(r);
      }
    }
  }

  // ── 명령 실행: 화면 버튼과 같은 입구. 명령은 실행 "전에" 기록하고(재생 순서 = 효과 순서), 실행 뒤 ok 를 채움 ──
  exec(u, st) {
    const g = this.g, AM = g.ActionManager, S = this.S, FSM = g.FSM, BS = g.BattleState;
    const cmd = { u: u.id, op: st.op };
    if (st.op === 'skill') Object.assign(cmd, { skill: st.id, idx: st.idx, x: st.x, y: st.y });
    else if (st.op === 'siege' || st.op === 'climb' || st.op === 'potion') Object.assign(cmd, { idx: st.idx, item: st.siege || st.potion, x: st.x, y: st.y });
    else if (st.op === 'wait' || st.op === 'defend' || st.op === 'overwatch') Object.assign(cmd, { dx: st.dx, dy: st.dy });
    else if (st.op === 'undo') { /* 인자 없음 */ }
    else Object.assign(cmd, { x: st.x, y: st.y });
    if (st.target !== undefined) cmd.target = st.target;
    const logged = this.record(cmd) || cmd;   // 기록된 사건 객체 (ok 를 나중에 채움)
    if (S.sel !== u) AM.selU(u);
    const before = { x: u.x, y: u.y, ends: this.env.turnEnds };
    let ok = true;
    switch (st.op) {
      case 'undo':   // 이동 취소: 원래 칸으로, 이동 경험치 회수, 340ms 뒤 선택 해제
        AM.actCancel();
        ok = !u.hm && !S.preMv;
        break;
      case 'move':
        AM.actMove(); AM.cellCk(st.x, st.y);
        ok = u.x === st.x && u.y === st.y;
        break;
      case 'attack': case 'heal':
        AM.actAttack(); AM.cellCk(st.x, st.y);
        ok = !!u.ha;
        break;
      case 'shove':
        AM.actShove(); AM.cellCk(st.x, st.y);
        ok = !!u.ha;
        break;
      case 'skill':
        AM.actSkill(st.idx);
        if (FSM.is(BS.SKILL_TARGET)) AM.cellCk(st.x, st.y);
        ok = this.env.turnEnds !== before.ends;
        if (ok) this.skillUse[u.id + ':' + st.id] = (this.skillUse[u.id + ':' + st.id] || 0) + 1;
        else if (FSM.is(BS.SKILL_TARGET)) AM.cellCk(-1, -1);   // 범위 밖 클릭 = 메뉴로 (스킬 환불 뒤)
        break;
      case 'wait': case 'defend': case 'overwatch':
        AM.askFace(st.op); AM.faceDone(st.dx, st.dy);
        ok = this.env.turnEnds !== before.ends;
        break;
      case 'siege': case 'climb':
        AM.actSiege(st.idx);
        if (FSM.is(BS.ITEM_TARGET)) AM.cellCk(st.x, st.y);
        ok = st.op === 'climb' ? (u.x !== before.x || u.y !== before.y) : this.env.turnEnds !== before.ends;
        if (!ok && FSM.is(BS.ITEM_TARGET)) AM.actCancel();
        break;
      case 'potion':
        AM.actPotion(st.idx);
        if (FSM.is(BS.ITEM_TARGET)) AM.cellCk(st.x, st.y);
        ok = this.env.turnEnds !== before.ends;
        if (!ok && FSM.is(BS.ITEM_TARGET)) AM.actCancel();
        break;
      default: throw new Error('unknown op ' + st.op);
    }
    logged.ok = ok;
    return ok;
  }
}

module.exports = { Policy, OPTS_DEFAULT };
