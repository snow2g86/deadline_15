// ═══════════════════════════════════════════
//  skills/knight.js — 기사 스킬 핸들러
// ═══════════════════════════════════════════

// ── 차징 (습득형) ────────────────────────
registerSkill('knight_charge', {
	target(u, sk, G) {
		const cr = sk.chargeRange || 1;
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=cr).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const cr = sk.chargeRange || 1;
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=cr);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const dmg = Math.max(1, Math.round(u.atk*0.8*G.skMul(u,'knight_charge')) - tgt.def);
		tgt.hp = Math.max(0, tgt.hp - dmg);
		tgt.stunned = Math.max(tgt.stunned || 0, 1);
		G.vfxAtk(u, tgt); G.sfxAtk(u.cls); G.shakeU(tgt.id); G.screenShake();
		G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
		G.floatT(tgt.x, tgt.y, t('messages.stunned'), 'debuff');
		procFury(u, tgt, G);
		G.floatT(u.x, u.y, t('messages.knight_charge'), 'heal');
		G.vfxFlash('rgba(96,165,250,.2)');
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:20,colors:['#60a5fa','#3b82f6','#fff'],shape:'spark',speed:5,spread:16,decay:0.02,size:5});
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:4,colors:['#60a5fa44'],shape:'ring',speed:0,spread:4,decay:0.015,size:14});
		if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id);G._rmDead()}
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, chkEnd:true});
	}
});

// ── 희생 (습득형) ────────────────────────
registerSkill('knight_sacrifice', {
	target(u, sk, G) {
		const sr = sk.sacrificeRange || 5;
		return G.units.filter(v => v.team==='ally' && v.hp>0 && v.id!==u.id && mh(u.x,u.y,v.x,v.y)<=sr).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const sr = sk.sacrificeRange || 5;
		const ally = G.units.find(v => v.x===tx && v.y===ty && v.team==='ally' && v.hp>0 && v.id!==u.id && mh(u.x,u.y,v.x,v.y)<=sr);
		if (!ally) { _skillRefund(u, sk, G); return; }
		ally._sacrificeKnight = u.id;
		u._sacrificeDmgCount = 2; u._sacrificeTarget = ally.id;
		G.floatT(u.x, u.y, t('messages.knight_sacrifice'), 'heal');
		G.floatT(ally.x, ally.y, t('messages.knight_sacrifice_protect'), 'heal');
		G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:15,colors:['#60a5fa','#3b82f6','#fff'],shape:'ring',speed:3,spread:14,decay:0.02,size:6});
		G.vfxSpawn(G.uSX(ally.x,ally.y)+UCX, G.uSY(ally.x,ally.y)+UCY, {count:10,colors:['#60a5fa','#93c5fd','#fff'],shape:'ring',speed:2,spread:10,decay:0.025,size:5});
		G.sfxHeal(); procFury(u, u, G);
		_skillDone(u, G);
	}
});

// ── 포획 (습득형) ────────────────────────
registerSkill('knight_capture', {
	target(u, sk, G) {
		const cr = sk.captureRange || 5;
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=cr).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const cr = sk.captureRange || 5;
		const enemy = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=cr);
		if (!enemy) { _skillRefund(u, sk, G); return; }
		const adj = G._findAdj(u.x, u.y, enemy);
		if (!adj) { _skillRefund(u, sk, G); G.floatT(u.x,u.y,t('messages.no_empty_tile'),'damage'); return; }
		enemy.x = adj.x; enemy.y = adj.y;
		G.animU(enemy.id, adj.x, adj.y);
		G.floatT(u.x, u.y, t('messages.knight_capture'), 'heal');
		G.floatT(enemy.x, enemy.y, t('messages.knight_captured'), 'damage');
		G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:16,colors:['#f97316','#fbbf24','#fff'],shape:'spark',speed:5,spread:14,decay:0.02,size:5});
		G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:4,colors:['#f9731644'],shape:'ring',speed:0,spread:3,decay:0.015,size:12});
		G.vfxSpawn(G.uSX(enemy.x,enemy.y)+UCX, G.uSY(enemy.x,enemy.y)+UCY, {count:14,colors:['#ef4444','#f97316','#fff'],shape:'spark',speed:4,spread:12,decay:0.02,size:5});
		G.screenShake();
		G.sfxAtk(u.cls); procFury(u, u, G); G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:340});
	}
});
