// ═══════════════════════════════════════════
//  skills/archer.js — 궁수 스킬 핸들러
// ═══════════════════════════════════════════

// ── 도약 (기본) ──────────────────────────
registerSkill('archer_dash', {
	target(u, sk, G) {
		const cells = [];
		for (let x=0; x<COLS; x++) for (let y=0; y<ROWS; y++) {
			if (mh(u.x,u.y,x,y)<=sk.dashRange && mh(u.x,u.y,x,y)>0 && !G.uAt(x,y)) cells.push({x,y});
		}
		return cells;
	},
	exec(u, tx, ty, sk, G) {
		if (G.uAt(tx,ty)) { _skillRefund(u, sk, G); return; }
		const startX = u.x, startY = u.y;
		u._gdx = tx-u.x; u._gdy = ty-u.y; u.x = tx; u.y = ty; u.mo = true;
		G.vfxSpawn(G.uSX(startX,startY)+UCX, G.uSY(startY,startY)+UCY, {count:12,colors:['#ccf','#99f','#66f'],shape:'spark',speed:3,spread:10,decay:0.02,size:2});
		G.animU(u.id, tx, ty);
		G.floatT(u.x, u.y, t('messages.archer_leap'), 'heal');
		G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:15,colors:['#ff8','#ff0','#fff'],shape:'spark',speed:5,spread:15,decay:0.02,size:3});
		G.allyPos[u.id] = {x:u.x,y:u.y};
		G._grantExp(u, 'move'); G.sfxMove();
		_skillDone(u, G, {delay:340});
	}
});

// ── 저격 (습득형) ────────────────────────
registerSkill('archer_snipe', {
	target(u, sk, G) {
		const sMin = sk.snipeMin || 5, sMax = sk.snipeMax || 10;
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)>=sMin && mh(u.x,u.y,v.x,v.y)<=sMax).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const sMin = sk.snipeMin || 5, sMax = sk.snipeMax || 10;
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)>=sMin && mh(u.x,u.y,v.x,v.y)<=sMax);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const dmg = Math.max(1, Math.round(u.atk*1.5*G.skMul(u,'archer_snipe')) - tgt.def);
		tgt.hp = Math.max(0, tgt.hp - dmg);
		G.sfxAtk(u.cls); G.shakeU(tgt.id);
		G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
		G.floatT(u.x, u.y, t('messages.archer_snipe'), 'heal');
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:12,colors:['#f44','#ff8','#fff'],shape:'spark',speed:5,spread:14,decay:0.02,size:4});
		if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id);G._rmDead()}
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, chkEnd:true});
	}
});

// ── 연속사격 (습득형) ────────────────────
registerSkill('archer_rapidfire', {
	target(u, sk, G) {
		const rr = sk.rapidRange || 5;
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=rr).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const skLv = Math.min((u.skillLv && u.skillLv['archer_rapidfire']) || 1, 3);
		const hits = skLv + 1;
		let totalDmg = 0;
		for (let i=0; i<hits; i++) {
			if (tgt.hp<=0) break;
			const dmg = Math.max(1, Math.round(u.atk*0.8*G.skMul(u,'archer_rapidfire')) - tgt.def);
			tgt.hp = Math.max(0, tgt.hp - dmg);
			totalDmg += dmg;
			G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:6,colors:['#ff8','#f80','#fff'],shape:'spark',speed:3,spread:6,decay:0.03,size:2});
		}
		G.sfxAtk(u.cls); G.shakeU(tgt.id);
		G.floatT(tgt.x, tgt.y, `-${totalDmg}`, 'damage');
		G.floatT(u.x, u.y, t('messages.archer_rapidfire', {hits}), 'heal');
		if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id);G._rmDead()}
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, chkEnd:true});
	}
});

// ── 강철비 (습득형) ──────────────────────
registerSkill('archer_steelrain', {
	target(u, sk, G) {
		const cells = [];
		for (let x=0; x<COLS; x++) for (let y=0; y<ROWS; y++) {
			if (mh(u.x,u.y,x,y)<=u.range && mh(u.x,u.y,x,y)>0) cells.push({x,y});
		}
		return cells;
	},
	exec(u, tx, ty, sk, G) {
		for (let dx=-1; dx<=1; dx++) for (let dy=-1; dy<=1; dy++) {
			const px=tx+dx, py=ty+dy;
			if (px<0||px>=COLS||py<0||py>=ROWS) continue;
			const tgt = G.units.find(v => v.hp>0 && v.x===px && v.y===py && v.team==='enemy');
			if (tgt) {
				const dmg = Math.max(1, Math.round(u.atk*1.0*G.skMul(u,'archer_steelrain')) - tgt.def);
				tgt.hp = Math.max(0, tgt.hp - dmg);
				G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage'); G.shakeU(tgt.id);
				G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:6,colors:['#888','#aaa','#fff'],shape:'spark',speed:3,spread:8,decay:0.03,size:3});
				if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id);G._rmDead()}
			}
		}
		G.sfxAtk(u.cls); G._grantExp(u, 'attack');
		G.floatT(u.x, u.y, t('messages.archer_steelrain'), 'heal');
		G.vfxSpawn(G.uSX(tx,ty)+UCX, G.uSY(tx,ty)+UCY, {count:20,colors:['#888','#aaa','#ccc','#fff'],shape:'spark',speed:5,spread:18,decay:0.02,size:4});
		_skillDone(u, G, {delay:500, chkEnd:true});
	}
});
