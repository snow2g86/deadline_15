// ═══════════════════════════════════════════
//  skills/commander.js — 지휘관 스킬 핸들러
// ═══════════════════════════════════════════

// ── 돌격 명령: 주변 클랜원 공격력 버프 (자기 칸을 눌러 사용) ──
registerSkill('commander_rally', {
	target(u, sk, G) { return [{ x: u.x, y: u.y }]; },
	exec(u, tx, ty, sk, G) {
		const r = sk.rallyRange || 3, pct = Math.round((sk.rallyPct || 20) * G.skMul(u, 'commander_rally'));
		const allies = G.units.filter(v => v.team === 'ally' && v.hp > 0 && mh(u.x, u.y, v.x, v.y) <= r);
		allies.forEach(v => {
			v.buffs = (v.buffs || []).filter(b => b.source !== 'commander_rally');
			v.buffs.push({ type: 'atk_up', value: pct, duration: sk.rallyTurns || 2, source: 'commander_rally' });
			G.vfxSpawn(G.uSX(v.x, v.y) + UCX, G.uSY(v.x, v.y) + UCY, { count: 10, colors: ['#f59e0b', '#fde68a', '#fff'], shape: 'spark', speed: 3, spread: 12, decay: 0.025, size: 4 });
			G.floatT(v.x, v.y, t('commander_msg.rally_buff', { n: pct }), 'heal');
		});
		G.floatT(u.x, u.y, t('commander_msg.rally'), 'heal');
		G.vfxFlash('rgba(245,158,11,.15)'); G.sfxAtk(u.cls);
		_skillDone(u, G, { delay: 450 });
	}
});

// ── 지휘: 클랜원 한 명의 행동력을 가득 채워 바로 다음 차례로 ──
registerSkill('commander_order', {
	target(u, sk, G) {
		const r = sk.orderRange || 4;
		return G.units.filter(v => v.team === 'ally' && v.hp > 0 && v.id !== u.id && !v.isSummon && mh(u.x, u.y, v.x, v.y) <= r).map(v => ({ x: v.x, y: v.y }));
	},
	exec(u, tx, ty, sk, G) {
		const v = G.units.find(w => w.x === tx && w.y === ty && w.team === 'ally' && w.hp > 0 && w.id !== u.id);
		if (!v) { _skillRefund(u, sk, G); return; }
		v.actionPow = Math.max(v.actionPow || 0, 4.999 + 0.5); // 지휘관 차례가 끝나면 이 클랜원이 바로 움직임
		G.floatT(v.x, v.y, t('commander_msg.order'), 'heal');
		G.vfxSpawn(G.uSX(v.x, v.y) + UCX, G.uSY(v.x, v.y) + UCY, { count: 14, colors: ['#60a5fa', '#f59e0b', '#fff'], shape: 'ring', speed: 3, spread: 12, decay: 0.022, size: 5 });
		_skillDone(u, G, { delay: 400 });
	}
});
