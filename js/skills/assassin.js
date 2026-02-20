// ═══════════════════════════════════════════
//  skills/assassin.js — 암살자 스킬 핸들러
// ═══════════════════════════════════════════

// ── 암살 (기본 스킬) ────────────────────
registerSkill('assassin_assassinate', {
	target(u, sk, G) {
		if (!isStealthed(u)) return null;
		const enemy = G.units.find(v => v.team === 'enemy' && v.hp > 0 && v.x === u.x && v.y === u.y);
		if (!enemy) return null;
		return 'instant';
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.team === 'enemy' && v.hp > 0 && v.x === u.x && v.y === u.y);
		if (!tgt || !isStealthed(u)) { _skillRefund(u, sk, G); return; }
		const dmg = Math.max(1, Math.round(u.atk * 5 * G.skMul(u, 'assassin_assassinate')) - tgt.def);
		tgt.hp = Math.max(0, tgt.hp - dmg);
		G.sfxAtk(u.cls); G.shakeU(tgt.id); G.screenShake(true);
		G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
		G.floatT(u.x, u.y, t('messages.assassin_assassinate'), 'heal');
		G.vfxFlash('rgba(168,85,247,.2)');
		G.vfxSpawn(G.uSX(tgt.x, tgt.y) + UCX, G.uSY(tgt.x, tgt.y) + UCY,
			{count: 24, colors: ['#a855f7', '#7c3aed', '#fff'], shape: 'spark', speed: 6, spread: 18, decay: 0.018, size: 6});
		G.vfxSpawn(G.uSX(tgt.x, tgt.y) + UCX, G.uSY(tgt.x, tgt.y) + UCY,
			{count: 6, colors: ['#a855f7', '#7c3aed'], shape: 'slash', speed: 4, spread: 10, decay: 0.025, size: 5});
		const adj = G._findAdj(u.x, u.y, u);
		if (adj) { G._mvU(u, adj.x, adj.y); }
		if (tgt.hp <= 0) { G.screenShake(true); G.sfxKill(); G.sfxDeath(); G.vfxDeath(tgt); G.deathA(tgt.id); }
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay: 500, rmDead: true, chkEnd: true});
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
			G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:16,colors:['#a855f7','#fff','#c4b5fd'],shape:'spark',speed:5,spread:14,decay:0.02,size:5});
			G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:4,colors:['#a855f7','#7c3aed'],shape:'slash',speed:3,spread:8,decay:0.03,size:4});
			G.sfxAtk(u.cls); G.shakeU(tgt.id); G.screenShake();
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
