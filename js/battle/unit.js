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
    for (let c = 2; c <= 7; c++) if (!this.uAt(c, 11) && frontLine.length < (knights.length + melee.length)) frontLine.push({ x: c, y: 11 });
    let idx = 0;
    knights.forEach(k => { if (idx < frontLine.length) form.push({ cls: k, pos: frontLine[idx++] }); });
    melee.forEach(m => { if (idx < frontLine.length) form.push({ cls: m, pos: frontLine[idx++] }); });
    const midLine = [];
    for (let c = 2; c <= 7; c++) if (!this.uAt(c, 12) && midLine.length < ranged.length + heal.length + sappers.length) midLine.push({ x: c, y: 12 });
    idx = 0;
    ranged.forEach(r => { if (idx < midLine.length) form.push({ cls: r, pos: midLine[idx++] }); });
    heal.forEach(h => { if (idx < midLine.length) form.push({ cls: h, pos: midLine[idx++] }); });
    sappers.forEach(s => { if (idx < midLine.length) form.push({ cls: s, pos: midLine[idx++] }); });
    if (boss) form.push({ cls: boss.cls, pos: { x: 5, y: 2 }, isBoss: true });
    return form;
  },

  // ── 하위 호환: stunned/frozen getter (BuffSystem 연동) ──
  isStunned(u) { return BuffSystem.has(u, BuffType.STUN) || u.stunned > 0; },
  isFrozen(u) { return BuffSystem.has(u, BuffType.FREEZE) || u.frozen > 0; },
  isCC(u) { return this.isStunned(u) || this.isFrozen(u); },
};
