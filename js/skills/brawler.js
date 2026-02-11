// ═══════════════════════════════════════════
//  skills/brawler.js — 무투가 스킬 핸들러
// ═══════════════════════════════════════════

// ── 무장해제 (기본) ──────────────────────
registerSkill('brawler_disarm', {
	target(u, sk, G) {
		const dr = sk.disarmRange || 1;
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=dr).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		tgt.disarmed = 3;
		G.sfxAtk(u.cls); G.shakeU(tgt.id);
		G.floatT(tgt.x, tgt.y, t('messages.atk_reduced'), 'damage');
		G.floatT(u.x, u.y, t('messages.brawler_disarm'), 'heal');
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:12,colors:['#f97316','#fbbf24','#fff'],shape:'ring',speed:3,spread:12,decay:0.025,size:5});
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
			G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:6,colors:['#f97316','#fbbf24','#fff'],shape:'spark',speed:3,spread:6,decay:0.03,size:2});
		}
		G.sfxAtk(u.cls); G.shakeU(tgt.id);
		G.floatT(tgt.x, tgt.y, `-${totalDmg}`, 'damage');
		G.floatT(u.x, u.y, t('messages.brawler_flurry'), 'heal');
		if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id)}
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
		G.sfxAtk(u.cls); G.shakeU(tgt.id);
		G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
		G.floatT(u.x, u.y, t('messages.brawler_crush'), 'heal');
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:15,colors:['#ef4444','#f97316','#fff'],shape:'spark',speed:4,spread:14,decay:0.025,size:5});
		if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id)}
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, rmDead:true, chkEnd:true});
	}
});
