// ═══════════════════════════════════════════
//  battle/unit.js — Unit CRUD, queries, passive init
// ═══════════════════════════════════════════

const UnitManager = {
  // ── 공성 아이템 헬퍼 ──
  _selectRandomSiegeType() {
    const types = [
      { type: 'bomb', weight: 40 }, { type: 'shield', weight: 30 },
      { type: 'evasion', weight: 20 }, { type: 'detour', weight: 10 }
    ];
    const total = types.reduce((s, t) => s + t.weight, 0);
    let rand = Math.random() * total;
    for (const t of types) { if (rand < t.weight) return t.type; rand -= t.weight; }
    return 'bomb';
  },

  _createSiegeItem(type) {
    const defs = {
      bomb: { name: '💣 폭탄', description: '폭발로 주변 피해', targetType: 'self' },
      shield: { name: '🛡️ 방어막', description: '일시적 방어 증가', targetType: 'self' },
      evasion: { name: '⚡ 회피', description: '다음 공격 회피', targetType: 'self' },
      detour: { name: '🛣️ 우회로', description: '이동 경로 개선', targetType: 'self' },
    };
    const def = defs[type] || defs.bomb;
    return { id: Math.random(), type, name: def.name, description: def.description, targetType: def.targetType, cooldown: 0 };
  },

  // ── 유닛 추가 ──
  addUnit(team, src, x, y) {
    const S = GameStore;
    let cls, hp, mhp, atk, def, mv, rng, role, resType, maxRes, resRec, initRes;
    let uid = 0, lv = 1, name = '', gender = 'm', actionRec = 1.0, skillLv;

    if (team === 'ally' && typeof src === 'number') {
      const bs = toBattleStats(src);
      if (!bs) return null;
      cls = bs.cls; hp = bs.hp; mhp = bs.mhp; atk = bs.atk; def = bs.def; mv = bs.move; rng = bs.range;
      role = bs.role; resType = bs.resType; maxRes = bs.maxRes; resRec = bs.resRec; initRes = bs.res;
      uid = bs.uid; lv = bs.lv; name = bs.name; gender = bs.gender || 'm'; actionRec = bs.actionRec;
      skillLv = bs.skillLv;
    } else {
      cls = src;
      const d = JAB[cls], s = S.cStage;
      hp = d.base.hp; atk = d.base.atk; def = d.base.def; mv = d.base.move; rng = d.base.range;
      role = ROLE_MAP[cls]; resType = d.res; maxRes = d.maxRes; resRec = d.resRec;
      if (team === 'enemy' && s) { hp = Math.round(hp * s.sm.hp); atk = Math.round(atk * s.sm.atk); }
      mhp = hp; initRes = d.res === 'mana' ? maxRes : 0; name = t('classes.' + cls);
      gender = randomGender(); actionRec = d.actionRec || 1.0;
    }

    const u = {
      id: S.nid++, uid, team, cls, lv, x, y, hp, mhp, atk, def, move: mv, range: rng, role, name, gender,
      res: initRes, maxRes, resType, resRec,
      actionPow: 0, actionRec,
      hm: false, ha: false, waited: false, mo: false,
      // 하위 호환용 (스킬 핸들러에서 직접 접근)
      furyBuff: 0, defBuff: 0, stunned: 0, frozen: 0, disarmed: 0,
      channeling: null,
      buffs: [],
      skillLv: skillLv || {},
    };

    if (team === 'enemy') {
      u.origSpawn = { x, y };
      u.siegeItems = [this._createSiegeItem(this._selectRandomSiegeType())];
    }

    S.units.push(u);
    EventBus.emit('unit_added', { unit: u });
    return u;
  },

  // ── 유닛 쿼리 ──
  uAt(x, y) {
    const all = GameStore.units.filter(u => u.x === x && u.y === y && u.hp > 0);
    if (all.length <= 1) return all[0] || null;
    return all.find(u => u.team === 'enemy') || all[0];
  },

  alive(team) {
    return GameStore.units.filter(u => u.team === team && u.hp > 0);
  },

  // ── 사망 유닛 제거 ──
  rmDead() {
    const S = GameStore;
    S.units.forEach(u => {
      if (u.hp <= 0) {
        // 소환수 소울본드
        if (u.isSummon && u.summonerId) {
          const summoner = S.units.find(s => s.id === u.summonerId && s.hp > 0 && s.skillLv && s.skillLv['summoner_soulbond'] >= 1);
          if (summoner) {
            summoner.res = Math.min(summoner.maxRes, summoner.res + 40);
            EventBus.emit('soulbond_restore', { summoner, amount: 40 });
          }
        }
        if (u.team === 'enemy' && !u._counted) {
          u._counted = true;
          S._killCount++;
          S._killExpPool += killExp(S.cStage ? S.cStage.id : 1, u.cls);
        }
        if (u.team === 'ally' && u.uid && !u._counted) {
          u._counted = true;
          S._deadAllyUids.push(u.uid);
          if (u.cls === COMMANDER_CLS) S._commanderFallen = true; // chkEnd에서 패배 처리
        }
      }
    });
    S.units = S.units.filter(u => u.hp > 0);
  },

  // ── 적 진형 배치 ──
  eFormation(enemies, boss) {
    const form = [];
    let knights = [], melee = [], ranged = [], heal = [], sappers = [];
    enemies.forEach(cls => {
      const role = ROLE_MAP[cls];
      if (cls === 'knight') knights.push(cls);
      else if (role === 'melee') melee.push(cls);
      else if (role === 'ranged') ranged.push(cls);
      else if (role === 'healer') heal.push(cls);
      if (cls === 'sapper') sappers.push(cls);
    });
    const frontLine = [];
    for (const c of FORM_COLS) if (!this.uAt(c, 11) && frontLine.length < (knights.length + melee.length)) frontLine.push({ x: c, y: 11 });
    let idx = 0;
    knights.forEach(k => { if (idx < frontLine.length) form.push({ cls: k, pos: frontLine[idx++] }); });
    melee.forEach(m => { if (idx < frontLine.length) form.push({ cls: m, pos: frontLine[idx++] }); });
    const midLine = [];
    for (const c of FORM_COLS) if (!this.uAt(c, 12) && midLine.length < ranged.length + heal.length + sappers.length) midLine.push({ x: c, y: 12 });
    idx = 0;
    ranged.forEach(r => { if (idx < midLine.length) form.push({ cls: r, pos: midLine[idx++] }); });
    heal.forEach(h => { if (idx < midLine.length) form.push({ cls: h, pos: midLine[idx++] }); });
    sappers.forEach(s => { if (idx < midLine.length) form.push({ cls: s, pos: midLine[idx++] }); });
    if (boss) form.push({ cls: boss.cls, pos: { x: MID_C, y: 2 }, isBoss: true });
    return form;
  },

  // ── 하위 호환: stunned/frozen getter (BuffSystem 연동) ──
  isStunned(u) { return BuffSystem.has(u, BuffType.STUN) || u.stunned > 0; },
  isFrozen(u) { return BuffSystem.has(u, BuffType.FREEZE) || u.frozen > 0; },
  isCC(u) { return this.isStunned(u) || this.isFrozen(u); },

  // ── 엄호 ──
  // target 바로 옆(1칸)에 같은 편 탱커가 있고, 그 탱커가 attacker에게 더 가까우면(=앞을 막고 있으면)
  // 엄호해 주는 탱커를 반환. 일반 단일 공격만 막는다 (스킬·광역·반격은 적용 안 함)
  coverOf(attacker, target) {
    if (!attacker || !target || COVER_IGNORE_CLASSES.includes(attacker.cls)) return null;
    if (PROJECTILE_CLASSES.includes(attacker.cls)) return null;   // 원거리는 엄호 대신 투사체 차단(interceptOf)
    const dT = mh(attacker.x, attacker.y, target.x, target.y);
    return GameStore.units.find(g => g.hp > 0 && g.id !== target.id && g.team === target.team &&
      GUARD_CLASSES.includes(g.cls) && !this.isCC(g) &&
      mh(g.x, g.y, target.x, target.y) === 1 && mh(attacker.x, attacker.y, g.x, g.y) < dT) || null;
  },

  // ── 투사체 차단 ──
  // 원거리(투사체) 공격이 지나가는 칸(양 끝 제외)에 대상 편 기사가 서 있으면 공격자에게 가장 가까운 그 기사를 반환.
  // 그 기사가 TACTICS_ACT.interceptMul 배율로 대신 맞는다 (기절·빙결이어도 몸으로 막음). 자기 편 유닛은 넘어 쏜다
  interceptOf(attacker, target) {
    if (!attacker || !target || !PROJECTILE_CLASSES.includes(attacker.cls)) return null;
    for (const c of this.lineCells(attacker.x, attacker.y, target.x, target.y)) {
      const g = this.uAt(c.x, c.y);
      if (g && g.hp > 0 && g.id !== target.id && g.team === target.team && GUARD_CLASSES.includes(g.cls)) return g;
    }
    return null;
  },
  // 두 칸 사이 직선이 지나가는 칸들 (공격자 쪽부터, 양 끝 제외).
  // 칸 경계선을 따라 지나면 양쪽 칸 모두 포함, 칸 꼭짓점만 스치는 칸(정대각선 옆)은 제외
  lineCells(x0, y0, x1, y1) {
    const out = [], seen = new Set([x0 + ',' + y0, x1 + ',' + y1]);
    const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0)) * 4;
    const add = (x, y) => { const k = x + ',' + y; if (!seen.has(k)) { seen.add(k); out.push({ x, y }); } };
    for (let i = 1; i < n; i++) {
      const fx = x0 + (x1 - x0) * i / n, fy = y0 + (y1 - y0) * i / n;
      const hx = Math.abs(fx - Math.floor(fx) - .5) < 1e-9, hy = Math.abs(fy - Math.floor(fy) - .5) < 1e-9;
      if (hx && hy) continue;                                        // 꼭짓점: 스치기만 함
      const rx = Math.round(fx), ry = Math.round(fy);
      if (hx) { add(Math.floor(fx), ry); add(Math.ceil(fx), ry); }   // 세로 경계선 위: 양쪽 칸
      else if (hy) { add(rx, Math.floor(fy)); add(rx, Math.ceil(fy)); }
      else add(rx, ry);
    }
    return out;
  },

  // ── 전술 보너스 ──
  // 반환: { mul: 배율, tags: ['back'|'side'|'pincer'|'high'] }
  tacticBonus(a, t) {
    const S = GameStore, tags = [];
    let add = 0;
    // 후방/측면: 대상이 바라보는 방향(_gdx,_gdy)과 공격 방향의 각도
    const fx = t._gdx || 0, fy = t._gdy || 0;
    const dx = a.x - t.x, dy = a.y - t.y;
    if ((fx || fy) && (dx || dy) && !t._defend) { // 방어 태세는 후방·측면 보너스를 받지 않음
      const cos = (dx * fx + dy * fy) / (Math.hypot(dx, dy) * Math.hypot(fx, fy));
      if (cos < -0.5) { add += TACTIC.back; tags.push('back'); }
      else if (cos <= 0.5) { add += TACTIC.side; tags.push('side'); }
    }
    // 협공: 공격자 반대편(내적 < 0)에 공격자 편 유닛이 대상과 붙어 있음
    if (S.units.some(p => p.hp > 0 && p.id !== a.id && p.team === a.team && mh(p.x, p.y, t.x, t.y) === 1 &&
        (p.x - t.x) * dx + (p.y - t.y) * dy < 0)) { add += TACTIC.pincer; tags.push('pincer'); }
    // 고지대
    const ta = S.ter[a.y] && S.ter[a.y][a.x], tt = S.ter[t.y] && S.ter[t.y][t.x];
    if (ta === 'hill' && tt !== 'hill') { add += TACTIC.high; tags.push('high'); }
    return { mul: 1 + Math.min(add, TACTIC.cap), tags, capped: add > TACTIC.cap };
  },

  // ── 일반 공격 회피 판정 (공격받는 쪽 기준) ──
  // 공성아이템 회피 버프(30%, 발동 시 소모) → 숲 지형(TACTIC.forestEvade). 반환: 'siege' | 'forest' | null
  rollEvade(tgt) {
    if (BuffSystem.has(tgt, BuffType.EVASION) && Math.random() < 0.3) {
      BuffSystem.remove(tgt, BuffType.EVASION, 'siege');
      return 'siege';
    }
    const tile = GameStore.ter[tgt.y] && GameStore.ter[tgt.y][tgt.x];
    if (tile === 'forest' && Math.random() < TACTIC.forestEvade) return 'forest';
    return null;
  },

  // 공성아이템 방어막: 받는 피해 50%
  shieldMul(tgt) { return BuffSystem.has(tgt, BuffType.SHIELD) ? 0.5 : 1; },

  // ── 제압 구역(ZOC): 이 칸이 상대 편 탱커의 바로 옆인가 ──
  inZoc(u, x, y) {
    if (COVER_IGNORE_CLASSES.includes(u.cls)) return false;
    return GameStore.units.some(g => g.hp > 0 && g.team !== u.team && GUARD_CLASSES.includes(g.cls) &&
      !this.isCC(g) && mh(g.x, g.y, x, y) === 1);
  },

  // ── 밀치기 ──
  // a가 인접한 t를 a→t 방향으로 1칸 밀 때의 결과 (부작용 없음)
  // 반환: { ok, to:{x,y} | null, hit: 'wall'|'unit'|null, other: 부딪힌 유닛 }
  shovePlan(a, t) {
    const dx = Math.sign(t.x - a.x), dy = Math.sign(t.y - a.y);
    if (mh(a.x, a.y, t.x, t.y) !== 1 || t.isBoss) return { ok: false };
    const nx = t.x + dx, ny = t.y + dy;
    const tile = this.tileAt(nx, ny);
    if (nx < 0 || ny < 0 || nx >= COLS || ny >= ROWS || !tile || !TI[tile].pass) return { ok: true, to: null, hit: 'wall' };
    const o = this.uAt(nx, ny);
    if (o && o.hp > 0) return { ok: true, to: null, hit: 'unit', other: o };
    return { ok: true, to: { x: nx, y: ny }, hit: null };
  },
  // 밀칠 수 있는 인접 적 목록
  shoveTargets(a) {
    return GameStore.units.filter(v => v.hp > 0 && v.team !== a.team && !isStealthed(v) && mh(a.x, a.y, v.x, v.y) === 1 && this.shovePlan(a, v).ok);
  },

  // ── 지원 공격 ──
  // 공격자 a와 같은 편이며 대상 바로 옆(1칸)에 있고 행동 가능한 유닛 중 공격력이 가장 높은 하나
  // (힐러·소환수·무장해제·은신 중인 유닛 제외)
  supporterOf(a, tgt) {
    return GameStore.units.filter(p => p.hp > 0 && p.id !== a.id && p.team === a.team && !p.isSummon &&
      p.role !== 'healer' && !this.isCC(p) && !(p.disarmed > 0) && !BuffSystem.has(p, BuffType.DISARM) &&
      !isStealthed(p) && mh(p.x, p.y, tgt.x, tgt.y) === 1)
      .sort((x, y) => y.atk - x.atk)[0] || null;
  },

  // 지원 공격 판정 + 피해 적용 (연출은 호출한 쪽에서 지연 후 emitSupport)
  // 반환: { sp, dmg } | null
  rollSupport(a, tgt) {
    if (tgt.hp <= 0) return null;
    const sp = this.supporterOf(a, tgt);
    if (!sp || Math.random() >= SUPPORT.chance) return null;
    let dmg = Math.max(1, Math.round(calcDmg(sp, tgt) * SUPPORT.mul * this.shieldMul(tgt)));
    sp._lastTactic = null; // 지원 타격에는 전술 표시 생략
    const actual = tgt.team === 'ally' ? applyDmgToAlly(tgt, dmg, G) : (tgt.hp = Math.max(0, tgt.hp - dmg), tgt);
    return { sp, dmg, actual };
  },

  emitSupport(r) {
    VFX.faceDir(r.sp.id, r.actual.x - r.sp.x, r.actual.y - r.sp.y);
    EventBus.emit('unit_attacked', { attacker: r.sp, target: r.actual, damage: r.dmg, isSupport: true });
    procFury(r.sp, r.actual, G);
  },

  // ── 지형 ──
  tileAt(x, y) { return GameStore.ter[y] ? GameStore.ter[y][x] : null; },
  isLavaMap() { return !!GameStore.cStage && GameStore.cStage.mapType === 'volcano'; },
  // 용암(화산 맵의 물 타일)과 상하좌우로 붙어 있는가
  nearLava(x, y) {
    if (!this.isLavaMap()) return false;
    return [[0, -1], [0, 1], [-1, 0], [1, 0]].some(([dx, dy]) => this.tileAt(x + dx, y + dy) === 'water');
  },

  // 표시용: 옆에 엄호해 줄 수 있는 탱커가 있는가 (방향 무관)
  hasGuard(u) {
    return !GUARD_CLASSES.includes(u.cls) && GameStore.units.some(g => g.hp > 0 && g.id !== u.id && g.team === u.team &&
      GUARD_CLASSES.includes(g.cls) && !this.isCC(g) && mh(g.x, g.y, u.x, u.y) === 1);
  },
};
