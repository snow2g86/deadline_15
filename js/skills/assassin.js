// ═══════════════════════════════════════════
//  skills/assassin.js — 암살자 스킬 핸들러
// ═══════════════════════════════════════════

// ── 암살 (기본) ──────────────────────────
registerSkill('assassin_assassinate', {
	target(u, sk, G) { return 'instant'; },
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===u.x && v.y===u.y && v.team==='enemy' && v.hp>0);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const dmg = Math.max(1, u.atk*5 - tgt.def);
		tgt.hp = Math.max(0, tgt.hp - dmg);
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:20,colors:['#7c3aed','#a855f7','#4c1d95'],shape:'spark',speed:5,spread:16,decay:0.02,size:5});
		G.screenShake(); G.sfxAtk(u.cls); G.shakeU(tgt.id);
		G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
		G.floatT(u.x, u.y, t('messages.assassin_assassinate'), 'heal');
		if (tgt.hp<=0) {G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id);G._rmDead()}
		G._grantExp(u, 'attack');
		const esc = G._findAdj(u.x, u.y, null);
		if (esc) { G._mvU(u, esc.x, esc.y); u.mo = true; }
		_skillDone(u, G, {delay:500, chkEnd:true});
	}
});

// ── 습격 (습득형) ────────────────────────
registerSkill('assassin_ambush', {
	target(u, sk, G) {
		if (!isStealthed(u)) return null;
		const range = sk.ambushRange || 2;
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=range).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		if (!isStealthed(u)) { _skillRefund(u, sk, G); return; }
		const range = sk.ambushRange || 2;
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=range);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const adj = G._findAdj(tgt.x, tgt.y, u);
		if (!adj) { _skillRefund(u, sk, G); G.floatT(u.x,u.y,t('messages.no_empty_tile'),'damage'); return; }
		G._mvU(u, adj.x, adj.y); u.mo = true;
		setTimeout(() => {
			const dmg = Math.max(1, u.atk*2 - tgt.def);
			tgt.hp = Math.max(0, tgt.hp - dmg);
			G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:12,colors:['#a855f7','#fff','#c4b5fd'],shape:'spark',speed:4,spread:12,decay:0.025,size:4});
			G.sfxAtk(u.cls); G.shakeU(tgt.id);
			G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
			G.floatT(u.x, u.y, t('messages.assassin_raid'), 'heal');
			if (tgt.hp<=0) {
				u.res = Math.min(u.maxRes, u.res+20);
				G.floatT(u.x, u.y, '+20 EP', 'exp');
				G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id);G._rmDead();
			}
			G._grantExp(u, 'attack');
			_skillDone(u, G, {delay:500, chkEnd:true});
		}, 360);
	}
});
