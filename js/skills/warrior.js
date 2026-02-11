// ═══════════════════════════════════════════
//  skills/warrior.js — 전사 스킬 핸들러
// ═══════════════════════════════════════════

// ── 강타 (기본) ──────────────────────────
registerSkill('warrior_powersmash', {
	target(u, sk, G) {
		const dirs = [{x:0,y:-1},{x:1,y:0},{x:0,y:1},{x:-1,y:0}];
		return dirs.map(d => ({x:u.x+d.x,y:u.y+d.y})).filter(p => p.x>=0 && p.x<COLS && p.y>=0 && p.y<ROWS);
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.hp>0 && v.team!==u.team);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const dmg = Math.max(1, Math.round(u.atk*1.5 - tgt.def));
		tgt.hp = Math.max(0, tgt.hp - dmg);
		G.vfxAtk(u, tgt); G.sfxAtk(u.cls); G.shakeU(tgt.id);
		G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
		procFury(u, tgt, G);
		G.floatT(u.x, u.y, t('messages.warrior_strike'), 'heal');
		G._grantExp(u, 'attack');
		if (tgt.hp<=0) { G.screenShake(); G.sfxKill(); G.sfxDeath(); G.vfxDeath(tgt); G.deathA(tgt.id); G._rmDead(); }
		_skillDone(u, G, {delay:500, chkEnd:true});
	}
});

// ── 휘두르기 (습득형) ────────────────────
registerSkill('warrior_cleave', {
	target(u, sk, G) { return 'instant'; },
	exec(u, tx, ty, sk, G) {
		const dirs = [{x:-1,y:-1},{x:0,y:-1},{x:1,y:-1},{x:-1,y:0},{x:1,y:0},{x:-1,y:1},{x:0,y:1},{x:1,y:1}];
		dirs.forEach(d => {
			const px=u.x+d.x, py=u.y+d.y;
			if (px<0||px>=COLS||py<0||py>=ROWS) return;
			const tgt = G.units.find(v => v.hp>0 && v.x===px && v.y===py && v.team==='enemy');
			if (tgt) {
				const dmg = Math.max(1, Math.round(u.atk*1.2*G.skMul(u,'warrior_cleave')) - tgt.def);
				tgt.hp = Math.max(0, tgt.hp - dmg);
				G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage'); G.shakeU(tgt.id);
				G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:6,colors:['#f44','#f80','#fff'],shape:'spark',speed:3,spread:8,decay:0.03,size:3});
				if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id);G._rmDead()}
			}
		});
		G.sfxAtk(u.cls); G._grantExp(u, 'attack');
		G.floatT(u.x, u.y, t('messages.warrior_cleave'), 'heal');
		G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:15,colors:['#ff4400','#ff8800','#ffcc00'],shape:'ring',speed:4,spread:16,decay:0.02,size:6});
		procFury(u, u, G);
		_skillDone(u, G, {delay:500, chkEnd:true});
	}
});

// ── 강습 (습득형) ────────────────────────
registerSkill('warrior_assault', {
	target(u, sk, G) {
		const ar = sk.assaultRange || 5;
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=ar).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const ar = sk.assaultRange || 5;
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=ar);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const adj = G._findAdj(tgt.x, tgt.y, u);
		if (!adj) { _skillRefund(u, sk, G); G.floatT(u.x,u.y,t('messages.no_empty_tile'),'damage'); return; }
		u.x=adj.x; u.y=adj.y; u.mo=true;
		G.animU(u.id, adj.x, adj.y);
		setTimeout(()=>{
			const dirs=[{x:-1,y:-1},{x:0,y:-1},{x:1,y:-1},{x:-1,y:0},{x:1,y:0},{x:-1,y:1},{x:0,y:1},{x:1,y:1}];
			dirs.forEach(d => {
				const px=u.x+d.x, py=u.y+d.y;
				if(px<0||px>=COLS||py<0||py>=ROWS) return;
				const e=G.units.find(v=>v.hp>0&&v.x===px&&v.y===py&&v.team==='enemy');
				if(e){
					const dmg=Math.max(1,Math.round(u.atk*0.8*G.skMul(u,'warrior_assault'))-e.def);
					e.hp=Math.max(0,e.hp-dmg);
					G.floatT(e.x,e.y,`-${dmg}`,'damage');G.shakeU(e.id);
					G.vfxSpawn(G.uSX(e.x,e.y)+UCX,G.uSY(e.x,e.y)+UCY,{count:6,colors:['#f44','#f80','#fff'],shape:'spark',speed:3,spread:8,decay:0.03,size:3});
					if(e.hp<=0){G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(e);G.deathA(e.id);G._rmDead()}
				}
			});
			G.sfxAtk(u.cls); G._grantExp(u,'attack');
			G.floatT(u.x,u.y,t('messages.warrior_assault'),'heal');
			G.vfxSpawn(G.uSX(u.x,u.y)+UCX,G.uSY(u.x,u.y)+UCY,{count:20,colors:['#ff4400','#ff8800','#ffcc00'],shape:'spark',speed:5,spread:18,decay:0.02,size:5});
			procFury(u,u,G);
			_skillDone(u, G, {delay:500, chkEnd:true});
		},360);
	}
});

// ── 치명적인 일격 (습득형) ────────────────
registerSkill('warrior_criticalstrike', {
	target(u, sk, G) {
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=u.range).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=u.range);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const dmg = Math.max(1, Math.round(u.atk*G.skMul(u,'warrior_criticalstrike')) - tgt.def);
		tgt.hp = Math.max(0, tgt.hp - dmg);
		tgt._bleedTurns = 3; tgt._bleedDmg = Math.max(1, Math.round(u.atk*0.2));
		G.vfxAtk(u, tgt); G.sfxAtk(u.cls); G.shakeU(tgt.id);
		G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
		G.floatT(tgt.x, tgt.y, t('messages.warrior_bleed'), 'debuff');
		G.floatT(u.x, u.y, t('messages.warrior_criticalstrike'), 'heal');
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:12,colors:['#dc2626','#ef4444','#fff'],shape:'spark',speed:4,spread:12,decay:0.025,size:4});
		procFury(u, tgt, G);
		if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id);G._rmDead()}
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, chkEnd:true});
	}
});
