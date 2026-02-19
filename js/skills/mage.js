// ═══════════════════════════════════════════
//  skills/mage.js — 마법사 스킬 핸들러
// ═══════════════════════════════════════════

// ── 빙결 (습득형) ────────────────────────
registerSkill('mage_freeze', {
	target(u, sk, G) {
		const fr = sk.freezeRange || 5;
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=fr).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const dmg = Math.max(1, Math.round(u.atk*1.2*G.skMul(u,'mage_freeze')) - tgt.def);
		tgt.hp = Math.max(0, tgt.hp - dmg);
		tgt.frozen = Math.max(tgt.frozen || 0, 2);
		G.sfxAtk(u.cls); G.shakeU(tgt.id);
		G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
		G.floatT(tgt.x, tgt.y, t('messages.frozen'), 'debuff');
		G.floatT(u.x, u.y, t('messages.mage_freeze'), 'heal');
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:20,colors:['#88ccff','#aaddff','#fff'],shape:'star',speed:4,spread:16,decay:0.02,size:5});
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:5,colors:['#88ccff44'],shape:'ring',speed:0,spread:4,decay:0.015,size:16});
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:8,colors:['#aaddff','#fff'],shape:'diamond',speed:1.5,spread:12,decay:0.018,size:3,vy:-1.5});
		if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id);G._rmDead()}
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, chkEnd:true});
	}
});

// ── 그랜드 월 (습득형) ───────────────────
registerSkill('mage_grandwall', {
	target(u, sk, G) {
		const wr = sk.wallRange || 1;
		const cells = [];
		for (let x=0; x<COLS; x++) for (let y=0; y<ROWS; y++) {
			if (mh(u.x,u.y,x,y)<=wr && mh(u.x,u.y,x,y)>0) {
				const ti = TI[G.ter[y][x]]; if (!ti || !ti.pass) continue;
				if (G.uAt(x,y)) continue;
				if (G.traps.find(tr => tr.x===x && tr.y===y)) continue;
				cells.push({x,y});
			}
		}
		return cells;
	},
	exec(u, tx, ty, sk, G) {
		const ti = TI[G.ter[ty][tx]];
		if (!ti || !ti.pass || G.uAt(tx,ty) || G.traps.find(tr => tr.x===tx && tr.y===ty)) {
			_skillRefund(u, sk, G); return;
		}
		G.ter[ty][tx] = 'wall';
		if (!G.magicWalls) G.magicWalls = [];
		G.magicWalls.push({x:tx,y:ty});
		G.floatT(tx, ty, t('messages.mage_grandwall'), 'heal');
		G.vfxSpawn(G.uSX(tx,ty)+UCX, G.uSY(tx,ty)+UCY, {count:20,colors:['#88f','#aaf','#66f'],shape:'ring',speed:4,spread:16,decay:0.018,size:7});
		G.vfxSpawn(G.uSX(tx,ty)+UCX, G.uSY(tx,ty)+UCY, {count:6,colors:['#88f','#66f'],shape:'diamond',speed:1.5,spread:8,decay:0.025,size:3,vy:-1.5});
		G.sfxUIClick(); G._grantExp(u, 'attack');
		_skillDone(u, G, {rTer:true});
	}
});
