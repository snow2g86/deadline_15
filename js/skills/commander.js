// ═══════════════════════════════════════════
//  skills/commander.js — 지휘관 스킬 핸들러
// ═══════════════════════════════════════════

// ── 포르티시모: 광역 사기 버프 — 주변 클랜원 공격력·방어력 상승 (자기 칸을 눌러 사용) ──
registerSkill('commander_rally', {
	target(u, sk, G) { return [{ x: u.x, y: u.y }]; },
	exec(u, tx, ty, sk, G) {
		const r = sk.rallyRange || 4, pct = Math.round((sk.rallyPct || 20) * G.skMul(u, 'commander_rally'));
		const allies = G.units.filter(v => v.team === 'ally' && v.hp > 0 && mh(u.x, u.y, v.x, v.y) <= r);
		allies.forEach(v => {
			v.buffs = (v.buffs || []).filter(b => b.source !== 'commander_rally');
			v.buffs.push({ type: 'atk_up', value: pct, duration: sk.rallyTurns || 2, source: 'commander_rally' });
			v.buffs.push({ type: 'def_up', value: pct, duration: sk.rallyTurns || 2, source: 'commander_rally' });
			G.vfxSpawn(G.uSX(v.x, v.y) + UCX, G.uSY(v.x, v.y) + UCY, { count: 10, colors: ['#f59e0b', '#fde68a', '#fff'], shape: 'spark', speed: 3, spread: 12, decay: 0.025, size: 4 });
			G.floatT(v.x, v.y, t('commander_msg.rally_buff', { n: pct }), 'heal');
		});
		G.floatT(u.x, u.y, t('commander_msg.rally'), 'heal');
		G.vfxFlash('rgba(245,158,11,.15)'); G.sfxAtk(u.cls);
		_skillDone(u, G, { delay: 450 });
	}
});

// ── 하모니: 주변 클랜원 HP 회복 + 상태이상 해제 (자기 칸을 눌러 사용) ──
registerSkill('commander_harmony', {
	target(u, sk, G) { return [{ x: u.x, y: u.y }]; },
	exec(u, tx, ty, sk, G) {
		const r = sk.harmonyRange || 3, pct = (sk.harmonyPct || 15) * G.skMul(u, 'commander_harmony') / 100;
		G.units.filter(v => v.team === 'ally' && v.hp > 0 && mh(u.x, u.y, v.x, v.y) <= r).forEach(v => {
			const heal = Math.max(1, Math.round(v.mhp * pct));
			v.hp = Math.min(v.mhp, v.hp + heal);
			// 상태이상 해제: 버프 시스템의 디버프 + 예전 방식 필드
			let cleansed = false;
			(v.buffs || []).filter(b => _isDebuff(b.type) || b.type === 'atk_down' || b.type === 'def_down').slice().forEach(b => { BuffSystem.remove(v, b.type, b.source); cleansed = true; });
			if (v.stunned > 0 || v.frozen > 0 || v.disarmed > 0 || v._bleedTurns > 0 || v._cursed || v._rootedTurns > 0) cleansed = true;
			v.stunned = 0; v.frozen = 0; v.disarmed = 0; v._bleedTurns = 0; v._bleedDmg = 0; v._rootedTurns = 0;
			if (v._cursed) { v._cursed = false; v._curseAtk = 0; v._curseDmgCount = 0; }
			G.floatT(v.x, v.y, '+' + heal, 'heal');
			if (cleansed) G.floatT(v.x, v.y, t('commander_msg.harmony_cleanse'), 'heal');
			G.vfxSpawn(G.uSX(v.x, v.y) + UCX, G.uSY(v.x, v.y) + UCY, { count: 10, colors: ['#86efac', '#fde68a', '#fff'], shape: 'spark', speed: 2, spread: 12, decay: 0.025, size: 4 });
		});
		G.floatT(u.x, u.y, t('commander_msg.harmony'), 'heal');
		G.sfxAtk(u.cls);
		_skillDone(u, G, { delay: 450 });
	}
});

// ── 다 카포: 클랜원 한 명이 즉시 한 번 더 행동 — 원래 차례(행동력)는 그대로 남는다 ──
registerSkill('commander_dacapo', {
	target(u, sk, G) {
		const r = sk.dacapoRange || 4;
		return G.units.filter(v => v.team === 'ally' && v.hp > 0 && v.id !== u.id && !v.isSummon && mh(u.x, u.y, v.x, v.y) <= r).map(v => ({ x: v.x, y: v.y }));
	},
	exec(u, tx, ty, sk, G) {
		const v = G.units.find(w => w.x === tx && w.y === ty && w.team === 'ally' && w.hp > 0 && w.id !== u.id);
		if (!v) { _skillRefund(u, sk, G); return; }
		// 보너스 행동: 지금 행동력을 기억해 두고 가득 채움 → 보너스 차례가 끝나면 기억한 값으로 되돌림 (turn.js endUnitTurn)
		if (v._daCapoPow == null) v._daCapoPow = v.actionPow || 0;
		v.actionPow = 5.6;
		G.floatT(v.x, v.y, t('commander_msg.dacapo'), 'heal');
		G.vfxSpawn(G.uSX(v.x, v.y) + UCX, G.uSY(v.x, v.y) + UCY, { count: 16, colors: ['#f59e0b', '#fde68a', '#fff'], shape: 'ring', speed: 3, spread: 14, decay: 0.022, size: 6 });
		_skillDone(u, G, { delay: 400 });
	}
});

// ── 피아니시모 (습득형): 반경 안 클랜원이 N턴간 일반 공격을 확률 회피 (UnitManager.rollEvade의 EVASION 버프) ──
// 포르티시모(공·방%)와 겹치지 않도록 '맞지 않게' 하는 축. 확률·지속은 공성 회피 아이템과 같은 30% 판정을 공유
registerSkill('commander_pianissimo', {
	target(u, sk, G) { return [{ x: u.x, y: u.y }]; },
	exec(u, tx, ty, sk, G) {
		const r = sk.pianoRange || 3, turns = sk.pianoTurns || 2;
		G.units.filter(v => v.team === 'ally' && v.hp > 0 && mh(u.x, u.y, v.x, v.y) <= r).forEach(v => {
			BuffSystem.apply(v, { type: BuffType.EVASION, duration: turns, value: 0.3, icon: '🎵', source: 'commander_pianissimo' });
			G.floatT(v.x, v.y, t('commander_msg.pianissimo_buff'), 'heal');
			G.vfxSpawn(G.uSX(v.x, v.y) + UCX, G.uSY(v.x, v.y) + UCY, { count: 10, colors: ['#a5b4fc', '#e0e7ff', '#fff'], shape: 'ring', speed: 2, spread: 12, decay: 0.025, size: 4 });
		});
		G.floatT(u.x, u.y, t('commander_msg.pianissimo'), 'heal');
		G.vfxFlash('rgba(165,180,252,.12)'); G.sfxAtk(u.cls);
		_skillDone(u, G, { delay: 450 });
	}
});
