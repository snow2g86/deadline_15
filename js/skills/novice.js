// ═══════════════════════════════════════════
//  skills/novice.js — 노비스 스킬 핸들러
// ═══════════════════════════════════════════

// ── 돌던지기 (기본 스킬) ────────────────────
registerSkill('novice_throw', {
	target(u, sk, G) {
		const rng = sk.throwRange || 4;
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=rng).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const rng = sk.throwRange || 4;
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=rng);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const dmg = Math.max(1, Math.round(u.atk*0.8*G.skMul(u,'novice_throw')) - tgt.def);
		tgt.hp = Math.max(0, tgt.hp - dmg);
		G.sfxAtk(u.cls); Fx.shake(tgt.id);
		Fx.float(tgt.x, tgt.y, '-' + dmg, 'damage');
		Fx.float(u.x, u.y, t('skills.novice_throw'), 'heal');
		Fx.burst(tgt.x, tgt.y, {count:8,colors:['#aaa','#888','#fff'],shape:'spark',speed:3,spread:8,decay:0.03,size:3});
		if (tgt.hp<=0) {Fx.screenShake();G.sfxKill();G.sfxDeath();Fx.death(tgt);G.deathA(tgt.id);G._rmDead()}
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:400, chkEnd:true});
	}
});

// ── 응급처치 (습득형): 자신 또는 인접 클랜원 최대 HP 15% 회복 ──
registerSkill('novice_firstaid', {
	target(u, sk, G) {
		const r = sk.aidRange || 1;
		// HP가 가득 찬 클랜원은 제외 (기력만 쓰고 +0 되는 것 방지), 대상이 없으면 사용 불가
		const cells = G.units.filter(v => v.team === 'ally' && v.hp > 0 && v.hp < v.mhp && !v.isSummon && mh(u.x, u.y, v.x, v.y) <= r).map(v => ({x: v.x, y: v.y}));
		return cells.length ? cells : null;
	},
	exec(u, tx, ty, sk, G) {
		const r = sk.aidRange || 1;
		const v = G.units.find(w => w.x === tx && w.y === ty && w.team === 'ally' && w.hp > 0 && mh(u.x, u.y, w.x, w.y) <= r);
		if (!v) { _skillRefund(u, sk, G); return; }
		const heal = Math.min(v.mhp - v.hp, Math.max(1, Math.round(v.mhp * (sk.aidPct || 15) / 100 * G.skMul(u, 'novice_firstaid'))));
		v.hp += heal;
		G.sfxHeal();
		Fx.float(v.x, v.y, '+' + heal, 'heal');
		Fx.float(u.x, u.y, t('messages.novice_firstaid'), 'heal');
		Fx.burst(v.x, v.y, {count: 10, colors: ['#4ade80', '#fff', '#fca5a5'], shape: 'cross', speed: 2, spread: 8, decay: 0.03, size: 4});
		G._grantExp(u, 'heal');
		_skillDone(u, G, {delay: 400});
	}
});

// ── 몸통 박치기 (습득형): 2칸 내 적 옆으로 달려들어 ATK×0.9 (습격·강습의 입문판 — 배율·사거리 모두 낮음) ──
registerSkill('novice_tackle', {
	target(u, sk, G) {
		const r = sk.tackleRange || 2;
		return G.units.filter(v => v.team === 'enemy' && v.hp > 0 && mh(u.x, u.y, v.x, v.y) <= r).map(v => ({x: v.x, y: v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const r = sk.tackleRange || 2;
		const tgt = G.units.find(v => v.x === tx && v.y === ty && v.team === 'enemy' && v.hp > 0 && mh(u.x, u.y, v.x, v.y) <= r);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		// 이미 붙어 있으면 제자리, 아니면 대상 옆 빈 칸으로 이동
		if (mh(u.x, u.y, tgt.x, tgt.y) > 1) {
			const adj = G._findAdj(tgt.x, tgt.y, u);
			if (!adj) { _skillRefund(u, sk, G); Fx.float(u.x, u.y, t('messages.no_empty_tile'), 'damage'); return; }
			G._mvU(u, adj.x, adj.y); u.mo = true;
		}
		Fx.later(() => {
			const dmg = Math.max(1, Math.round(u.atk * 0.9 * G.skMul(u, 'novice_tackle')) - tgt.def);
			tgt.hp = Math.max(0, tgt.hp - dmg);
			G.sfxAtk(u.cls); Fx.shake(tgt.id); Fx.screenShake();
			Fx.float(tgt.x, tgt.y, '-' + dmg, 'damage');
			Fx.float(u.x, u.y, t('messages.novice_tackle'), 'heal');
			Fx.burst(tgt.x, tgt.y, {count: 12, colors: ['#fbbf24', '#fff', '#a3a3a3'], shape: 'spark', speed: 4, spread: 10, decay: 0.025, size: 4});
			if (tgt.hp <= 0) { Fx.screenShake(); G.sfxKill(); G.sfxDeath(); Fx.death(tgt); G.deathA(tgt.id); G._rmDead(); }
			G._grantExp(u, 'attack');
			_skillDone(u, G, {delay: 450, chkEnd: true});
		}, 340);
	}
});
