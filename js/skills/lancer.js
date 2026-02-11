// ═══════════════════════════════════════════
//  skills/lancer.js — 창술사 스킬 핸들러
// ═══════════════════════════════════════════

// ── 관통 (기본) ──────────────────────────
registerSkill('lancer_pierce', {
	target(u, sk, G) {
		const dirs = [{x:0,y:-1},{x:1,y:0},{x:0,y:1},{x:-1,y:0}];
		return dirs.map(d => ({x:u.x+d.x,y:u.y+d.y})).filter(p => p.x>=0 && p.x<COLS && p.y>=0 && p.y<ROWS);
	},
	exec(u, tx, ty, sk, G) {
		const dx = tx-u.x, dy = ty-u.y;
		for (let i=1; i<=sk.pierceLen; i++) {
			const px = u.x+dx*i, py = u.y+dy*i;
			if (px<0||px>=COLS||py<0||py>=ROWS) continue;
			const tgt = G.units.find(v => v.hp>0 && v.x===px && v.y===py && v.team!==u.team);
			if (tgt) {
				const dmg = Math.max(1, u.atk - tgt.def); tgt.hp = Math.max(0, tgt.hp - dmg);
				G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage'); G.shakeU(tgt.id);
				G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:8,colors:['#6af','#48f','#fff'],shape:'spark',speed:3,spread:8,decay:0.03,size:3});
				if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id)}
			}
		}
		G.sfxAtk(u.cls); G._grantExp(u, 'attack');
		G.floatT(u.x, u.y, t('messages.lancer_pierce'), 'heal');
		G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:12,colors:['#6af','#48f','#aaf'],shape:'spark',speed:4,spread:12,decay:0.025,size:4});
		_skillDone(u, G, {delay:500, rmDead:true, chkEnd:true});
	}
});

// ── 돌격 (습득형) ──────────────────────
registerSkill('lancer_charge', {
	target(u, sk, G) {
		const cr = sk.chargeRange || 3;
		const dirs = [{x:0,y:-1},{x:1,y:0},{x:0,y:1},{x:-1,y:0}];
		const targets = [];
		dirs.forEach(d => {
			for (let i = 1; i <= cr; i++) {
				const px = u.x + d.x * i, py = u.y + d.y * i;
				if (px<0||px>=COLS||py<0||py>=ROWS) break;
				const e = G.units.find(v => v.hp>0 && v.x===px && v.y===py && v.team==='enemy');
				if (e) { targets.push({x:px,y:py}); break; }
				if (!TI[G.ter[py][px]].pass) break;
				if (G.uAt(px,py)) break;
			}
		});
		return targets;
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const adj = G._findAdj(tgt.x, tgt.y, u);
		if (!adj) { _skillRefund(u, sk, G); G.floatT(u.x,u.y,t('messages.no_empty_tile'),'damage'); return; }
		u.x = adj.x; u.y = adj.y; u.mo = true;
		G.animU(u.id, adj.x, adj.y);
		setTimeout(() => {
			const dmg = Math.max(1, Math.round(u.atk * 1.2 * G.skMul(u, 'lancer_charge')) - tgt.def);
			tgt.hp = Math.max(0, tgt.hp - dmg);
			G.sfxAtk(u.cls); G.shakeU(tgt.id);
			G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
			G.floatT(u.x, u.y, t('messages.lancer_charge'), 'heal');
			G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:12,colors:['#6af','#48f','#fff'],shape:'spark',speed:4,spread:12,decay:0.025,size:4});
			procFury(u, tgt, G);
			if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id)}
			G._grantExp(u, 'attack');
			_skillDone(u, G, {delay:500, rmDead:true, chkEnd:true});
		}, 300);
	}
});

// ── 방진 (습득형) ──────────────────────
registerSkill('lancer_phalanx', {
	target(u, sk, G) { return 'instant'; },
	exec(u, tx, ty, sk, G) {
		const range = sk.phalanxRange || 2;
		const allies = G.units.filter(v => v.team==='ally' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=range);
		if (!allies.length) { _skillRefund(u, sk, G); return; }
		allies.forEach(a => {
			a._phalanxTurns = 2; a._phalanxDef = 5;
			G.vfxSpawn(G.uSX(a.x,a.y)+UCX, G.uSY(a.x,a.y)+UCY, {count:8,colors:['#60a5fa','#93c5fd','#fff'],shape:'ring',speed:2,spread:8,decay:0.025,size:5});
		});
		G.sfxHeal();
		G.floatT(u.x, u.y, t('messages.lancer_phalanx'), 'heal');
		G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:15,colors:['#60a5fa','#3b82f6','#fff'],shape:'ring',speed:3,spread:14,decay:0.02,size:6});
		procFury(u, u, G); G._grantExp(u, 'attack');
		_skillDone(u, G);
	}
});
