// ═══════════════════════════════════════════
//  skills/_common.js — 전투 전용 공통 시스템
//  (calcDmg, procFury, tickBuffs, getSkillBuffs 등)
// ═══════════════════════════════════════════

// ── 패시브: 분노 MAX 트리거 ───────────────
const FURY_PASSIVES = {
	warrior: {
		name: '광폭', icon: '💢', desc: '2턴간 공격 데미지 1.5배',
		trigger(defender, attacker, G) {
			defender.furyBuff = 2; defender.res = 0;
			G.floatT(defender.x, defender.y, t('passives.fury_activated'), 'heal');
			G.vfxSpawn(G.uSX(defender.x, defender.y) + UCX, G.uSY(defender.x, defender.y) + UCY,
				{ count: 15, colors: ['#ff4400','#ff8800','#ffcc00'], shape: 'spark', speed: 4, spread: 14, decay: 0.025, size: 4 });
		}
	},
	knight: {
		name: '철의 의지', icon: '🛡️', desc: '2턴간 방어력 1.5배',
		trigger(defender, attacker, G) {
			defender.defBuff = 2; defender.res = 0;
			G.floatT(defender.x, defender.y, t('passives.iron_will_activated'), 'heal');
			G.vfxSpawn(G.uSX(defender.x, defender.y) + UCX, G.uSY(defender.x, defender.y) + UCY,
				{ count: 15, colors: ['#4488ff','#88bbff','#ffffff'], shape: 'spark', speed: 3, spread: 12, decay: 0.025, size: 4 });
		}
	},
	lancer: {
		name: '철벽', icon: '🏰', desc: '2턴간 방어력 2배',
		trigger(defender, attacker, G) {
			defender.defBuff = 2; defender.res = 0;
			G.floatT(defender.x, defender.y, t('passives.iron_phalanx_activated'), 'heal');
			G.vfxSpawn(G.uSX(defender.x, defender.y) + UCX, G.uSY(defender.x, defender.y) + UCY,
				{ count: 15, colors: ['#60a5fa','#3b82f6','#fff'], shape: 'ring', speed: 3, spread: 14, decay: 0.02, size: 6 });
		}
	}
};

// ── 아군 피해 적용 래퍼 ────────────────────
function applyDmgToAlly(tgt, dmg, ctx) {
	let actual = tgt;
	if (tgt._sacrificeKnight) {
		const knight = ctx.units.find(v => v.id === tgt._sacrificeKnight && v.hp > 0);
		if (knight && knight._sacrificeDmgCount > 0) {
			actual = knight;
			knight._sacrificeDmgCount--;
			if (knight._sacrificeDmgCount <= 0) {
				delete tgt._sacrificeKnight;
				delete knight._sacrificeTarget;
				ctx.floatT(knight.x, knight.y, t('messages.knight_sacrifice_end'), 'heal');
			}
		}
	}
	if (actual === tgt) {
		const psKnight = ctx.units.filter(v =>
			v.team === 'ally' && v.hp > 0 && v.id !== tgt.id && v.cls === 'knight' &&
			v.skillLv && v.skillLv['knight_painshare'] >= 1 &&
			mh(v.x, v.y, tgt.x, tgt.y) <= 5
		).sort((a, b) => mh(a.x, a.y, tgt.x, tgt.y) - mh(b.x, b.y, tgt.x, tgt.y))[0];
		if (psKnight) {
			const shared = Math.floor(dmg / 3);
			const remain = dmg - shared;
			psKnight.hp = Math.max(1, psKnight.hp - shared);
			ctx.floatT(psKnight.x, psKnight.y, `-${shared}`, 'damage');
			ctx.floatT(psKnight.x, psKnight.y, t('messages.knight_painshare'), 'heal');
			ctx.vfxSpawn(ctx.uSX(psKnight.x, psKnight.y) + UCX, ctx.uSY(psKnight.x, psKnight.y) + UCY,
				{ count: 8, colors: ['#60a5fa', '#93c5fd', '#fff'], shape: 'ring', speed: 2, spread: 8, decay: 0.03, size: 4 });
			tgt.hp = Math.max(0, tgt.hp - remain);
			if (tgt.hp <= 0 && tgt.cls === 'knight' && tgt.skillLv && tgt.skillLv['knight_tenacity'] >= 1 && !tgt._tenacityUsed) {
				tgt.hp = 1; tgt._tenacityUsed = true; tgt._tenacityDef = true;
				ctx.floatT(tgt.x, tgt.y, t('messages.knight_tenacity'), 'heal');
				ctx.vfxSpawn(ctx.uSX(tgt.x, tgt.y) + UCX, ctx.uSY(tgt.x, tgt.y) + UCY,
					{ count: 12, colors: ['#fbbf24', '#f59e0b', '#fff'], shape: 'spark', speed: 3, spread: 12, decay: 0.02, size: 5 });
			}
			return tgt;
		}
	}
	actual.hp = Math.max(0, actual.hp - dmg);
	if (actual.hp <= 0 && actual.cls === 'knight' && actual.skillLv && actual.skillLv['knight_tenacity'] >= 1 && !actual._tenacityUsed) {
		actual.hp = 1; actual._tenacityUsed = true; actual._tenacityDef = true;
		ctx.floatT(actual.x, actual.y, t('messages.knight_tenacity'), 'heal');
		ctx.vfxSpawn(ctx.uSX(actual.x, actual.y) + UCX, ctx.uSY(actual.x, actual.y) + UCY,
			{ count: 12, colors: ['#fbbf24', '#f59e0b', '#fff'], shape: 'spark', speed: 3, spread: 12, decay: 0.02, size: 5 });
	}
	if (actual !== tgt && actual.hp <= 0) {
		ctx.screenShake(); ctx.sfxDeath(); ctx.vfxDeath(actual); ctx.deathA(actual.id); ctx._rmDead();
		setTimeout(() => { ctx.rUnits() }, 500);
	}
	return actual;
}

// ── 함정 감지 패시브 (어세신) ────────────
function chkTrapDetect(u) {
	if (u.cls !== 'assassin' || !u.skillLv || u.skillLv['assassin_trapdetect'] < 1) return;
	const enemy = u.team === 'ally' ? 'enemy' : 'ally';
	const detected = G.traps.filter(tr => tr.team === enemy && mh(u.x, u.y, tr.x, tr.y) <= 2);
	detected.forEach(tr => {
		G.traps = G.traps.filter(t => t !== tr);
		G.floatT(tr.x, tr.y, t('messages.trap_detected'), 'heal');
		G.vfxSpawn(G.uSX(tr.x, tr.y) + UCX, G.uSY(tr.x, tr.y) + UCY,
			{ count: 8, colors: ['#4f4', '#ff8', '#fff'], shape: 'ring', speed: 2, spread: 8, decay: 0.03, size: 3 });
	});
}

// ── 데미지 계산 ───────────────────────────
function calcDmg(attacker, target) {
	let atk = attacker.atk;
	if (attacker.cls === 'warrior' && attacker.skillLv && attacker.skillLv['warrior_bloodthirst'] >= 1 && attacker.mhp > 0) {
		const hpRatio = 1 - (attacker.hp / attacker.mhp);
		atk = Math.round(atk * (1 + 0.5 * hpRatio));
	}
	if (attacker.disarmed > 0) atk = Math.round(atk * 0.5);
	if (attacker.isSummon && attacker._empowerTurns > 0 && attacker._empowerMul > 0) atk = Math.round(atk * attacker._empowerMul);
	if (attacker.buffs) attacker.buffs.forEach(b => { if (b.type === 'atk_up') atk = Math.round(atk * (1 + b.value / 100)) });
	if (attacker.buffs) attacker.buffs.forEach(b => { if (b.type === 'atk_down') atk = Math.round(atk * (1 - b.value / 100)) });
	let def = target.def;
	if (target._tenacityDef) def += 10000;
	if (target.defBuff > 0) def = Math.round(def * 1.5);
	if (target.buffs) target.buffs.forEach(b => { if (b.type === 'def_up') def = Math.round(def * (1 + b.value / 100)) });
	if (target.buffs) target.buffs.forEach(b => { if (b.type === 'def_down') def = Math.round(def * (1 - b.value / 100)) });
	if (target._phalanxDef > 0) def += target._phalanxDef;
	let dmg = Math.max(1, atk - def);
	if (attacker.furyBuff > 0) dmg = Math.max(1, Math.round(dmg * 1.5));
	if (G.units.some(u => u.team === attacker.team && u.hp > 0 && u.channeling === 'shaman_exalt')) {
		dmg = Math.max(1, Math.round(dmg * 1.25));
	}
	if (attacker.cls === 'mage' && attacker.skillLv && attacker.skillLv['mage_manasurge'] >= 1 && attacker.res >= attacker.maxRes * 0.8) {
		dmg = Math.max(1, Math.round(dmg * 1.2));
	}
	attacker._lastCrit = false;
	if (attacker.cls === 'archer' && attacker.skillLv && attacker.skillLv['archer_weakspot'] >= 1) {
		if (Math.random() < 0.3) { dmg = Math.max(1, Math.round(dmg * 1.5)); attacker._lastCrit = true; }
	}
	return dmg;
}

// ── 분노 처리 (공격 후) ──────────────────
function procFury(attacker, target, G) {
	if (attacker.resType === 'fury') {
		attacker.res = Math.min(attacker.maxRes, attacker.res + 1);
	}
	if (target.hp > 0 && target.resType === 'fury') {
		target.res = Math.min(target.maxRes, target.res + 2);
		if (target.res >= target.maxRes) {
			const passive = FURY_PASSIVES[target.cls];
			if (passive) passive.trigger(target, attacker, G);
		}
	}
}

// ── 턴 시작 버프 틱 ──────────────────────
function tickBuffs(unit) {
	if (unit.furyBuff > 0) unit.furyBuff--;
	if (unit.defBuff > 0) unit.defBuff--;
	if (unit.disarmed > 0) unit.disarmed--;
	if (unit._tenacityDef) unit._tenacityDef = false;
	if (unit._bleedTurns > 0 && unit._bleedDmg > 0) {
		unit.hp = Math.max(1, unit.hp - unit._bleedDmg);
		G.floatT(unit.x, unit.y, `-${unit._bleedDmg}`, 'damage');
		G.floatT(unit.x, unit.y, t('messages.warrior_bleed_tick'), 'debuff');
		unit._bleedTurns--;
		if (unit._bleedTurns <= 0) { unit._bleedDmg = 0; }
	}
	if (unit.frozen > 0) {
		unit.frozen--;
		if (unit.frozen <= 0) { G.floatT(unit.x, unit.y, t('messages.frozen_end'), 'heal'); }
	}
	if (unit._phalanxTurns > 0) { unit._phalanxTurns--; if (unit._phalanxTurns <= 0) unit._phalanxDef = 0; }
	if (unit._empowerTurns > 0) { unit._empowerTurns--; if (unit._empowerTurns <= 0) unit._empowerMul = 0; }
	if (unit._rootedTurns > 0) unit._rootedTurns--;
	if (unit._sanctuaryTurns > 0 && unit._sanctuaryHeal > 0) {
		const heal = unit._sanctuaryHeal;
		unit.hp = Math.min(unit.mhp, unit.hp + heal);
		G.floatT(unit.x, unit.y, `+${heal}`, 'heal');
		G.vfxSpawn(G.uSX(unit.x, unit.y) + UCX, G.uSY(unit.x, unit.y) + UCY,
			{ count: 6, colors: ['#fbbf24', '#fff', '#4f4'], shape: 'ring', speed: 2, spread: 6, decay: 0.03, size: 4 });
		unit._sanctuaryTurns--;
		if (unit._sanctuaryTurns <= 0) { unit._sanctuaryHeal = 0; }
	}
	if (unit._curseTurns > 0 && unit._curseAtk > 0) {
		const curseDmg = Math.max(1, Math.round(unit.mhp * 0.01));
		unit.hp = Math.max(1, unit.hp - curseDmg);
		G.floatT(unit.x, unit.y, `-${curseDmg}`, 'damage');
		G.floatT(unit.x, unit.y, t('messages.shaman_curse_tick') || '☠️ 저주', 'debuff');
		unit._curseTurns--;
		if (unit._curseTurns <= 0) { unit._curseAtk = 0; }
	}
	if (unit.buffs) {
		for (let i = unit.buffs.length - 1; i >= 0; i--) {
			unit.buffs[i].duration--;
			if (unit.buffs[i].duration <= 0) unit.buffs.splice(i, 1);
		}
	}
}

// ── 버프 아이콘 목록 ─────────────────────
function getSkillBuffs(unit) {
	const buffs = [];
	if (unit.resType === 'fury' && unit.res >= unit.maxRes) buffs.push({ icon: '🔥', type: 'buff', turns: 0 });
	if (unit.furyBuff > 0) buffs.push({ icon: '💢', type: 'buff', turns: unit.furyBuff });
	if (unit.defBuff > 0) buffs.push({ icon: '🛡️', type: 'buff', turns: unit.defBuff });
	if (unit.disarmed > 0) buffs.push({ icon: '🤛', type: 'debuff', turns: unit.disarmed });
	if (unit.channeling === 'shaman_curse') buffs.push({ icon: '☠️', type: 'debuff', turns: 0 });
	if (unit.channeling === 'shaman_exalt') buffs.push({ icon: '🔺', type: 'buff', turns: 0 });
	if (!unit.channeling && G.units.some(u => u.team === unit.team && u.hp > 0 && u.channeling === 'shaman_exalt'))
		buffs.push({ icon: '🔺', type: 'buff', turns: 0 });
	if (unit.cls === 'knight' && unit.skillLv && unit.skillLv['knight_painshare'] >= 1)
		buffs.push({ icon: '💔', type: 'buff', turns: 0 });
	if (unit._sacrificeKnight) buffs.push({ icon: '🛡️', type: 'buff', turns: 0 });
	if (unit._sacrificeDmgCount > 0) buffs.push({ icon: '🛡️', type: 'buff', turns: unit._sacrificeDmgCount });
	if (unit._tenacityDef) buffs.push({ icon: '💪', type: 'buff', turns: 1 });
	if (unit.cls === 'warrior' && unit.skillLv && unit.skillLv['warrior_bloodthirst'] >= 1)
		buffs.push({ icon: '🩸', type: 'buff', turns: 0 });
	if (unit._bleedTurns > 0) buffs.push({ icon: '🗡️', type: 'debuff', turns: unit._bleedTurns });
	if (unit.stunned > 0) buffs.push({ icon: '⚡', type: 'debuff', turns: unit.stunned });
	if (unit.frozen > 0) buffs.push({ icon: '❄️', type: 'debuff', turns: unit.frozen });
	if (unit._sanctuaryTurns > 0) buffs.push({ icon: '✝️', type: 'buff', turns: unit._sanctuaryTurns });
	if (unit.isSummon && unit.summonTurns !== undefined) buffs.push({ icon: '⏳', type: 'buff', turns: unit.summonTurns });
	if (unit._phalanxTurns > 0) buffs.push({ icon: '🛡️', type: 'buff', turns: unit._phalanxTurns });
	if (unit.isSummon && unit._empowerTurns > 0) buffs.push({ icon: '⬆️', type: 'buff', turns: unit._empowerTurns });
	if (unit._rootedTurns > 0) buffs.push({ icon: '🌿', type: 'debuff', turns: unit._rootedTurns });
	if (unit._curseTurns > 0) buffs.push({ icon: '☠️', type: 'debuff', turns: unit._curseTurns });
	if (unit.cls === 'lancer' && unit.skillLv && unit.skillLv['lancer_spearwall'] >= 1) buffs.push({ icon: '🔱', type: 'buff', turns: 0 });
	if (unit.cls === 'brawler' && unit.skillLv && unit.skillLv['brawler_counter'] >= 1) buffs.push({ icon: '🔁', type: 'buff', turns: 0 });
	if (unit.cls === 'shaman' && unit.skillLv && unit.skillLv['shaman_medium'] >= 1 && unit.channeling) buffs.push({ icon: '🔮', type: 'buff', turns: 0 });
	if (unit.cls === 'sapper' && unit.skillLv && unit.skillLv['sapper_enhancedtrap'] >= 1) buffs.push({ icon: '⚙️', type: 'buff', turns: 0 });
	if (unit.cls === 'mage' && unit.skillLv && unit.skillLv['mage_manasurge'] >= 1 && unit.res >= unit.maxRes * 0.8) buffs.push({ icon: '🌊', type: 'buff', turns: 0 });
	if (unit.cls === 'priest' && unit.skillLv && unit.skillLv['priest_divinegrace'] >= 1) buffs.push({ icon: '🕊️', type: 'buff', turns: 0 });
	if (unit.buffs) unit.buffs.forEach(b => {
		const icon = b.type === 'atk_up' ? '🔥' : b.type === 'def_up' ? '🛡️' : b.type === 'atk_down' ? '💢' : '❄️';
		buffs.push({ icon, type: b.type.includes('down') ? 'debuff' : 'buff', turns: b.duration });
	});
	return buffs;
}
