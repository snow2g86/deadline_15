// ═══════════════════════════════════════════
//  battle/buff.js — 통합 버프/디버프 시스템
// ═══════════════════════════════════════════

const BuffType = {
  // 공격/방어 증감
  ATK_UP: 'atk_up', ATK_DOWN: 'atk_down',
  DEF_UP: 'def_up', DEF_DOWN: 'def_down',
  // fury 패시브
  FURY_BUFF: 'fury_buff',    // warrior: 데미지 1.5배
  IRON_WILL: 'iron_will',    // knight: 방어 1.5배
  IRON_PHALANX: 'iron_phalanx', // lancer: 방어 2배
  // CC
  STUN: 'stun', FREEZE: 'freeze', ROOT: 'root', DISARM: 'disarm',
  // DoT / HoT
  BLEED: 'bleed', POISON: 'poison', REGEN: 'regen', SANCTUARY: 'sanctuary',
  // 특수
  SHIELD: 'shield',          // 공성 방어막
  EVASION: 'evasion',        // 공성 회피
  STEALTH: 'stealth',        // 은신
  PHALANX_DEF: 'phalanx_def', // 팔랑크스 추가방어
  TENACITY: 'tenacity',      // 기사 근성
  SACRIFICE: 'sacrifice',    // 기사 희생
  CURSE: 'curse',            // 주술사 저주
  EMPOWER: 'empower',        // 소환수 강화
  CHANNEL_CURSE: 'channel_curse',
  CHANNEL_EXALT: 'channel_exalt',
};

const BuffSystem = {
  apply(unit, buffDef) {
    if (!unit.buffs) unit.buffs = [];
    // 동일 타입+소스 버프가 있으면 갱신
    const existing = unit.buffs.find(b => b.type === buffDef.type && b.source === buffDef.source);
    if (existing) {
      if (buffDef.duration !== undefined) existing.duration = Math.max(existing.duration, buffDef.duration);
      if (buffDef.value !== undefined) existing.value = buffDef.value;
      if (buffDef.stacks !== undefined) existing.stacks = (existing.stacks || 0) + buffDef.stacks;
      if (buffDef.meta) Object.assign(existing.meta || (existing.meta = {}), buffDef.meta);
      return existing;
    }
    const buff = {
      id: buffDef.id || (buffDef.type + '_' + Math.random().toString(36).slice(2, 6)),
      type: buffDef.type,
      duration: buffDef.duration !== undefined ? buffDef.duration : 1,
      value: buffDef.value || 0,
      stacks: buffDef.stacks || 1,
      source: buffDef.source || '',
      icon: buffDef.icon || '',
      meta: buffDef.meta || {},
    };
    unit.buffs.push(buff);
    EventBus.emit('buff_applied', { unit, buff });
    return buff;
  },

  remove(unit, type, source) {
    if (!unit.buffs) return;
    const idx = unit.buffs.findIndex(b => b.type === type && (!source || b.source === source));
    if (idx >= 0) {
      const removed = unit.buffs.splice(idx, 1)[0];
      EventBus.emit('buff_removed', { unit, buff: removed });
      return removed;
    }
  },

  removeAll(unit, type) {
    if (!unit.buffs) return;
    unit.buffs = unit.buffs.filter(b => {
      if (b.type === type) {
        EventBus.emit('buff_removed', { unit, buff: b });
        return false;
      }
      return true;
    });
  },

  tick(unit) {
    if (!unit.buffs) return;
    for (let i = unit.buffs.length - 1; i >= 0; i--) {
      const b = unit.buffs[i];
      // DoT 처리
      if (b.type === BuffType.BLEED && b.value > 0) {
        unit.hp = Math.max(1, unit.hp - b.value);
        EventBus.emit('buff_tick_damage', { unit, buff: b, damage: b.value });
      }
      if (b.type === BuffType.POISON && b.value > 0) {
        unit.hp = Math.max(1, unit.hp - b.value);
        EventBus.emit('buff_tick_damage', { unit, buff: b, damage: b.value });
      }
      // HoT 처리
      if (b.type === BuffType.REGEN && b.value > 0) {
        const heal = b.value;
        unit.hp = Math.min(unit.mhp, unit.hp + heal);
        EventBus.emit('buff_tick_heal', { unit, buff: b, heal });
      }
      if (b.type === BuffType.SANCTUARY && b.value > 0) {
        const heal = b.value;
        unit.hp = Math.min(unit.mhp, unit.hp + heal);
        EventBus.emit('buff_tick_heal', { unit, buff: b, heal });
      }
      // 영구 버프(-1)는 자동 만료 안함
      if (b.duration === -1) continue;
      b.duration--;
      if (b.duration <= 0) {
        unit.buffs.splice(i, 1);
        EventBus.emit('buff_removed', { unit, buff: b });
      }
    }
  },

  has(unit, type) {
    return unit.buffs ? unit.buffs.some(b => b.type === type && b.duration !== 0) : false;
  },

  get(unit, type) {
    return unit.buffs ? unit.buffs.find(b => b.type === type) : null;
  },

  getValue(unit, type) {
    if (!unit.buffs) return 0;
    return unit.buffs.filter(b => b.type === type).reduce((sum, b) => sum + (b.value || 0), 0);
  },

  getStacks(unit, type) {
    if (!unit.buffs) return 0;
    const b = unit.buffs.find(b2 => b2.type === type);
    return b ? (b.stacks || 1) : 0;
  },

  getIcons(unit) {
    if (!unit.buffs) return [];
    return unit.buffs.map(b => ({
      icon: b.icon || _defaultIcon(b.type),
      type: _isDebuff(b.type) ? 'debuff' : 'buff',
      turns: b.duration === -1 ? 0 : b.duration,
    }));
  },

  clearAll(unit) {
    if (unit.buffs) unit.buffs.length = 0;
  },

  // 구버전 전용 필드 → BuffSystem으로 마이그레이션
  migrateUnit(unit) {
    if (!unit.buffs) unit.buffs = [];
    if (unit.furyBuff > 0) {
      this.apply(unit, { type: BuffType.FURY_BUFF, duration: unit.furyBuff, value: 1.5, icon: '💢', source: 'fury' });
      unit.furyBuff = 0;
    }
    if (unit.defBuff > 0) {
      this.apply(unit, { type: BuffType.IRON_WILL, duration: unit.defBuff, value: 1.5, icon: '🛡️', source: 'iron_will' });
      unit.defBuff = 0;
    }
    if (unit.stunned > 0) {
      this.apply(unit, { type: BuffType.STUN, duration: unit.stunned, icon: '⚡', source: 'stun' });
      unit.stunned = 0;
    }
    if (unit.frozen > 0) {
      this.apply(unit, { type: BuffType.FREEZE, duration: unit.frozen, icon: '❄️', source: 'freeze' });
      unit.frozen = 0;
    }
    if (unit.disarmed > 0) {
      this.apply(unit, { type: BuffType.DISARM, duration: unit.disarmed, icon: '🤛', source: 'disarm' });
      unit.disarmed = 0;
    }
    if (unit._bleedTurns > 0) {
      this.apply(unit, { type: BuffType.BLEED, duration: unit._bleedTurns, value: unit._bleedDmg || 0, icon: '🗡️', source: 'bleed' });
      unit._bleedTurns = 0; unit._bleedDmg = 0;
    }
    if (unit._cursed) {
      this.apply(unit, { type: BuffType.CURSE, duration: -1, icon: '☠️', source: 'curse', meta: { dmgCount: unit._curseDmgCount || 0, atkMod: unit._curseAtk || 0 } });
      unit._cursed = false; unit._curseDmgCount = 0; unit._curseAtk = 0;
    }
    if (unit._siegeShield > 0) {
      this.apply(unit, { type: BuffType.SHIELD, duration: unit._siegeShield, value: 0.5, icon: '🛡️', source: 'siege' });
      unit._siegeShield = 0;
    }
    if (unit._siegeEvasion > 0) {
      this.apply(unit, { type: BuffType.EVASION, duration: unit._siegeEvasion, value: 0.3, icon: '⚡', source: 'siege' });
      unit._siegeEvasion = 0;
    }
    if (unit._phalanxTurns > 0) {
      this.apply(unit, { type: BuffType.PHALANX_DEF, duration: unit._phalanxTurns, value: unit._phalanxDef || 0, icon: '🛡️', source: 'phalanx' });
      unit._phalanxTurns = 0; unit._phalanxDef = 0;
    }
    if (unit._rootedTurns > 0) {
      this.apply(unit, { type: BuffType.ROOT, duration: unit._rootedTurns, icon: '🌿', source: 'root' });
      unit._rootedTurns = 0;
    }
    if (unit._sanctuaryTurns > 0) {
      this.apply(unit, { type: BuffType.SANCTUARY, duration: unit._sanctuaryTurns, value: unit._sanctuaryHeal || 0, icon: '✝️', source: 'sanctuary' });
      unit._sanctuaryTurns = 0; unit._sanctuaryHeal = 0;
    }
  }
};

function _isDebuff(type) {
  return [BuffType.ATK_DOWN, BuffType.DEF_DOWN, BuffType.STUN, BuffType.FREEZE,
    BuffType.ROOT, BuffType.DISARM, BuffType.BLEED, BuffType.POISON, BuffType.CURSE].includes(type);
}

function _defaultIcon(type) {
  const map = {
    [BuffType.ATK_UP]: '🔥', [BuffType.ATK_DOWN]: '💢',
    [BuffType.DEF_UP]: '🛡️', [BuffType.DEF_DOWN]: '❄️',
    [BuffType.FURY_BUFF]: '💢', [BuffType.IRON_WILL]: '🛡️', [BuffType.IRON_PHALANX]: '🏰',
    [BuffType.STUN]: '⚡', [BuffType.FREEZE]: '❄️', [BuffType.ROOT]: '🌿', [BuffType.DISARM]: '🤛',
    [BuffType.BLEED]: '🗡️', [BuffType.POISON]: '☠️', [BuffType.REGEN]: '💚', [BuffType.SANCTUARY]: '✝️',
    [BuffType.SHIELD]: '🛡️', [BuffType.EVASION]: '⚡', [BuffType.STEALTH]: '🌙',
    [BuffType.PHALANX_DEF]: '🛡️', [BuffType.TENACITY]: '💪', [BuffType.SACRIFICE]: '🛡️',
    [BuffType.CURSE]: '☠️', [BuffType.EMPOWER]: '⬆️',
    [BuffType.CHANNEL_CURSE]: '☠️', [BuffType.CHANNEL_EXALT]: '🔺',
  };
  return map[type] || '✨';
}
