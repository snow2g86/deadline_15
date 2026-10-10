// ═══════════════════════════════════════════
//  skills/knight.js — 기사 스킬 핸들러
// ═══════════════════════════════════════════

// ── 스위치 (기본 스킬) ──────────────────
registerSkill('knight_switch', {
	target(u, sk, G) {
		const sr = sk.switchRange || 2;
		return G.units.filter(v => v.team==='ally' && v.hp>0 && v.id!==u.id && mh(u.x,u.y,v.x,v.y)<=sr).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const sr = sk.switchRange || 2;
		const ally = G.units.find(v => v.x===tx && v.y===ty && v.team==='ally' && v.hp>0 && v.id!==u.id && mh(u.x,u.y,v.x,v.y)<=sr);
		if (!ally) { _skillRefund(u, sk, G); return; }
		const ox = u.x, oy = u.y;
		u.x = ally.x; u.y = ally.y;
		ally.x = ox; ally.y = oy;
		Fx.animU(u.id, u.x, u.y);
		Fx.animU(ally.id, ally.x, ally.y);
		Fx.float(u.x, u.y, t('messages.knight_switch'), 'heal');
		Fx.burst(u.x, u.y, {count:12,colors:['#60a5fa','#93c5fd','#fff'],shape:'ring',speed:3,spread:12,decay:0.025,size:5});
		Fx.burst(ally.x, ally.y, {count:12,colors:['#60a5fa','#93c5fd','#fff'],shape:'ring',speed:3,spread:12,decay:0.025,size:5});
		G.sfxMove(); procFury(u, u, G);
		_skillDone(u, G, {delay:340});
	}
});

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
		Fx.attack(u, tgt); G.sfxAtk(u.cls); Fx.shake(tgt.id); Fx.screenShake();
		Fx.float(tgt.x, tgt.y, `-${dmg}`, 'damage');
		Fx.float(tgt.x, tgt.y, t('messages.stunned'), 'debuff');
		procFury(u, tgt, G);
		Fx.float(u.x, u.y, t('messages.knight_charge'), 'heal');
		Fx.flash('rgba(96,165,250,.2)');
		Fx.burst(tgt.x, tgt.y, {count:20,colors:['#60a5fa','#3b82f6','#fff'],shape:'spark',speed:5,spread:16,decay:0.02,size:5});
		Fx.burst(tgt.x, tgt.y, {count:4,colors:['#60a5fa44'],shape:'ring',speed:0,spread:4,decay:0.015,size:14});
		if (tgt.hp<=0) {Fx.screenShake();G.sfxKill();G.sfxDeath();Fx.death(tgt);G.deathA(tgt.id);G._rmDead()}
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
		Fx.float(u.x, u.y, t('messages.knight_sacrifice'), 'heal');
		Fx.float(ally.x, ally.y, t('messages.knight_sacrifice_protect'), 'heal');
		Fx.burst(u.x, u.y, {count:15,colors:['#60a5fa','#3b82f6','#fff'],shape:'ring',speed:3,spread:14,decay:0.02,size:6});
		Fx.burst(ally.x, ally.y, {count:10,colors:['#60a5fa','#93c5fd','#fff'],shape:'ring',speed:2,spread:10,decay:0.025,size:5});
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
		if (!adj) { _skillRefund(u, sk, G); Fx.float(u.x,u.y,t('messages.no_empty_tile'),'damage'); return; }
		// 넉백 저항 (기사 70%): 끌려오지 않음 — 기력은 소모
		if (UnitManager.resistKnock(enemy)) { Fx.float(enemy.x, enemy.y, t('messages.knock_resist'), 'heal'); _skillDone(u, G, { delay: 400 }); return; }
		enemy.x = adj.x; enemy.y = adj.y;
		Fx.animU(enemy.id, adj.x, adj.y);
		Fx.float(u.x, u.y, t('messages.knight_capture'), 'heal');
		Fx.float(enemy.x, enemy.y, t('messages.knight_captured'), 'damage');
		Fx.burst(u.x, u.y, {count:16,colors:['#f97316','#fbbf24','#fff'],shape:'spark',speed:5,spread:14,decay:0.02,size:5});
		Fx.burst(u.x, u.y, {count:4,colors:['#f9731644'],shape:'ring',speed:0,spread:3,decay:0.015,size:12});
		Fx.burst(enemy.x, enemy.y, {count:14,colors:['#ef4444','#f97316','#fff'],shape:'spark',speed:4,spread:12,decay:0.02,size:5});
		Fx.screenShake();
		G.sfxAtk(u.cls); procFury(u, u, G); G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:340});
	}
});
