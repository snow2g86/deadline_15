// ═══════════════════════════════════════════
//  skills/sapper.js — 공병 스킬 핸들러
// ═══════════════════════════════════════════

// ── 함정 설치 (기본) ─────────────────────
registerSkill('sapper_trap', {
	target(u, sk, G) {
		const tr = sk.trapRange || 3;
		const cells = [];
		for (let x=0; x<COLS; x++) for (let y=0; y<ROWS; y++) {
			if (mh(u.x,u.y,x,y)<=tr && mh(u.x,u.y,x,y)>0) {
				const ti = TI[G.ter[y][x]]; if (!ti.pass) continue;
				if (G.uAt(x,y)) continue;
				if (G.traps.find(t => t.x===x && t.y===y)) continue;
				cells.push({x,y});
			}
		}
		return cells;
	},
	exec(u, tx, ty, sk, G) {
		if (G.uAt(tx,ty) || G.traps.find(tr => tr.x===tx && tr.y===ty)) { _skillRefund(u, sk, G); return; }
		let trapDmg = u.atk*2, trapStun = 2;
		if (u.skillLv && u.skillLv['sapper_enhancedtrap'] >= 1) { trapDmg = Math.round(trapDmg * 1.3); trapStun = 3; }
		G.traps.push({x:tx, y:ty, dmg:trapDmg, stun:trapStun, id:G.traps.length, team:'ally'});
		G.floatT(tx, ty, t('messages.trap_installed'), 'heal');
		G.vfxSpawn(G.uSX(tx,ty)+UCX, G.uSY(tx,ty)+UCY, {count:10,colors:['#f80','#ff4','#fa0'],shape:'spark',speed:2,spread:10,decay:0.025,size:3});
		G.sfxUIClick(); G._grantExp(u, 'attack');
		_skillDone(u, G);
	}
});

// ── 굴착 (습득형) ────────────────────────
registerSkill('sapper_excavate', {
	target(u, sk, G) {
		const er = sk.excavateRange || 1;
		const cells = [];
		for (let x=0; x<COLS; x++) for (let y=0; y<ROWS; y++) {
			if (mh(u.x,u.y,x,y)<=er && mh(u.x,u.y,x,y)>0 && G.ter[y] && G.ter[y][x]==='rock') {
				cells.push({x,y});
			}
		}
		return cells;
	},
	exec(u, tx, ty, sk, G) {
		if (!G.ter[ty] || G.ter[ty][tx]!=='rock') { _skillRefund(u, sk, G); return; }
		G.ter[ty][tx] = 'plain';
		G.floatT(tx, ty, t('messages.sapper_excavate'), 'heal');
		G.vfxSpawn(G.uSX(tx,ty)+UCX, G.uSY(tx,ty)+UCY, {count:15,colors:['#a88','#ccc','#fff'],shape:'spark',speed:4,spread:14,decay:0.025,size:4});
		G.sfxAtk(u.cls); G._grantExp(u, 'attack');
		_skillDone(u, G, {rTer:true});
	}
});

// ── 폭파 (습득형) ──────────────────────
registerSkill('sapper_detonate', {
	target(u, sk, G) {
		const dr = sk.detonateRange || 5;
		const allyTraps = G.traps.filter(tr => tr.team==='ally' && mh(u.x,u.y,tr.x,tr.y)<=dr);
		return allyTraps.map(tr => ({x:tr.x, y:tr.y}));
	},
	exec(u, tx, ty, sk, G) {
		const trap = G.traps.find(tr => tr.x===tx && tr.y===ty && tr.team==='ally');
		if (!trap) { _skillRefund(u, sk, G); return; }
		const burstDmg = Math.round(trap.dmg * 1.5);
		const dirs = [{x:-1,y:-1},{x:0,y:-1},{x:1,y:-1},{x:-1,y:0},{x:0,y:0},{x:1,y:0},{x:-1,y:1},{x:0,y:1},{x:1,y:1}];
		dirs.forEach(d => {
			const px = trap.x+d.x, py = trap.y+d.y;
			if (px<0||px>=COLS||py<0||py>=ROWS) return;
			const tgt = G.units.find(v => v.hp>0 && v.x===px && v.y===py && v.team==='enemy');
			if (tgt) {
				const dmg = Math.max(1, burstDmg - tgt.def);
				tgt.hp = Math.max(0, tgt.hp - dmg);
				G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage'); G.shakeU(tgt.id);
				G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:8,colors:['#f80','#ff4','#fff'],shape:'spark',speed:4,spread:10,decay:0.025,size:4});
				if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id)}
			}
		});
		G.traps = G.traps.filter(tr => tr !== trap);
		G.sfxAtk(u.cls);
		G.floatT(tx, ty, t('messages.sapper_detonate'), 'heal');
		G.vfxSpawn(G.uSX(tx,ty)+UCX, G.uSY(tx,ty)+UCY, {count:20,colors:['#f80','#ff4','#fa0','#fff'],shape:'spark',speed:5,spread:18,decay:0.02,size:6});
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, rmDead:true, chkEnd:true});
	}
});
