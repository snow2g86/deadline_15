// ═══════════════════════════════════════════
//  skills/brawler.js — 무투가 스킬 핸들러
// ═══════════════════════════════════════════

// ── 무장해제 (기본 스킬) ────────────────
registerSkill('brawler_disarm', {
	target(u, sk, G) {
		const dr = sk.disarmRange || 1;
		return G.units.filter(v => v.team === 'enemy' && v.hp > 0 && mh(u.x, u.y, v.x, v.y) <= dr).map(v => ({x: v.x, y: v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x === tx && v.y === ty && v.team === 'enemy' && v.hp > 0);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		tgt.disarmed = 3;
		G.sfxAtk(u.cls); Fx.shake(tgt.id);
		Fx.float(tgt.x, tgt.y, t('messages.brawler_disarm'), 'debuff');
		Fx.float(tgt.x, tgt.y, t('messages.atk_reduced'), 'damage');
		Fx.burst(tgt.x, tgt.y, {count: 14, colors: ['#f97316', '#fbbf24', '#fff'], shape: 'spark', speed: 4, spread: 12, decay: 0.025, size: 4});
		Fx.burst(tgt.x, tgt.y, {count: 4, colors: ['#f9731644'], shape: 'ring', speed: 0, spread: 3, decay: 0.015, size: 10});
		G._grantExp(u, 'attack');
		_skillDone(u, G);
	}
});

// ── 연타 (습득형) ──────────────────────
registerSkill('brawler_flurry', {
	target(u, sk, G) {
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=1).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const hits = 3; let totalDmg = 0;
		for (let i = 0; i < hits; i++) {
			if (tgt.hp <= 0) break;
			const dmg = Math.max(1, Math.round(u.atk * 0.6 * G.skMul(u, 'brawler_flurry')) - tgt.def);
			tgt.hp = Math.max(0, tgt.hp - dmg);
			totalDmg += dmg;
			Fx.burst(tgt.x, tgt.y, {count:8,colors:['#f97316','#fbbf24','#fff'],shape:'spark',speed:4,spread:8,decay:0.025,size:3});
		}
		G.sfxAtk(u.cls); Fx.shake(tgt.id); Fx.screenShake();
		Fx.float(tgt.x, tgt.y, `-${totalDmg}`, 'damage');
		Fx.float(u.x, u.y, t('messages.brawler_flurry'), 'heal');
		Fx.burst(tgt.x, tgt.y, {count:5,colors:['#f9731644'],shape:'ring',speed:0,spread:3,decay:0.015,size:10});
		if (tgt.hp<=0) {Fx.screenShake();G.sfxKill();G.sfxDeath();Fx.death(tgt);G.deathA(tgt.id)}
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, rmDead:true, chkEnd:true});
	}
});

// ── 파쇄 (습득형) ──────────────────────
registerSkill('brawler_crush', {
	target(u, sk, G) {
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=1).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const dmg = Math.max(1, Math.round(u.atk * 1.0 * G.skMul(u, 'brawler_crush')));
		tgt.hp = Math.max(0, tgt.hp - dmg);
		G.sfxAtk(u.cls); Fx.screenShake(true); Fx.shake(tgt.id); Fx.flash('rgba(239,68,68,.2)');
		Fx.float(tgt.x, tgt.y, `-${dmg}`, 'damage');
		Fx.float(u.x, u.y, t('messages.brawler_crush'), 'heal');
		Fx.burst(tgt.x, tgt.y, {count:24,colors:['#ef4444','#f97316','#fff'],shape:'spark',speed:6,spread:18,decay:0.018,size:6});
		Fx.burst(tgt.x, tgt.y, {count:5,colors:['#ef444444'],shape:'ring',speed:0,spread:4,decay:0.012,size:16});
		Fx.later(()=>Fx.burst(tgt.x, tgt.y, {count:8,colors:['#ef4444','#f97316'],shape:'cross',speed:3,spread:10,decay:0.025,size:4}),70);
		if (tgt.hp<=0) {Fx.screenShake(true);G.sfxKill();G.sfxDeath();Fx.death(tgt);G.deathA(tgt.id)}
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, rmDead:true, chkEnd:true});
	}
});
