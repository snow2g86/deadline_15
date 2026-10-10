// ═══════════════════════════════════════════
//  skills/sapper.js — 공병 스킬 핸들러
// ═══════════════════════════════════════════

// ── 함정 설치 (기본 스킬) ────────────────
registerSkill('sapper_trap', {
	target(u, sk, G) {
		const tr = sk.trapRange || 1;
		const cells = [];
		for (let x = 0; x < COLS; x++) for (let y = 0; y < ROWS; y++) {
			if (mh(u.x, u.y, x, y) > 0 && mh(u.x, u.y, x, y) <= tr) {
				const ti = TI[G.ter[y][x]]; if (!ti || !ti.pass) continue;
				if (G.uAt(x, y)) continue;
				if (G.traps.find(t2 => t2.x === x && t2.y === y)) continue;
				cells.push({x, y});
			}
		}
		return cells;
	},
	exec(u, tx, ty, sk, G) {
		const ti = TI[G.ter[ty][tx]];
		if (!ti || !ti.pass || G.uAt(tx, ty) || G.traps.find(t2 => t2.x === tx && t2.y === ty)) {
			_skillRefund(u, sk, G); return;
		}
		const trapDmg = Math.round(u.atk * 2);
		const enhanced = u.skillLv && u.skillLv['sapper_enhancedtrap'] >= 1;
		G.traps.push({
			x: tx, y: ty, team: u.team,
			dmg: enhanced ? Math.round(trapDmg * 1.3) : trapDmg,
			stun: enhanced ? 3 : 2
		});
		G.sfxUIClick();
		Fx.float(tx, ty, t('messages.trap_installed'), 'heal');
		Fx.burst(tx, ty, {count: 12, colors: ['#f59e0b', '#fbbf24', '#fff'], shape: 'ring', speed: 3, spread: 10, decay: 0.025, size: 5});
		G._grantExp(u, 'attack');
		_skillDone(u, G, {rTer: true});
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
		Fx.float(tx, ty, t('messages.sapper_excavate'), 'heal');
		Fx.burst(tx, ty, {count:15,colors:['#a88','#ccc','#fff'],shape:'spark',speed:4,spread:14,decay:0.025,size:4});
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
				Fx.float(tgt.x, tgt.y, `-${dmg}`, 'damage'); Fx.shake(tgt.id);
				Fx.burst(tgt.x, tgt.y, {count:8,colors:['#f80','#ff4','#fff'],shape:'spark',speed:4,spread:10,decay:0.025,size:4});
				if (tgt.hp<=0) {Fx.screenShake();G.sfxKill();G.sfxDeath();Fx.death(tgt);G.deathA(tgt.id)}
			}
		});
		G.traps = G.traps.filter(tr => tr !== trap);
		G.sfxAtk(u.cls); G.sfxExplosion(); Fx.screenShake(true);
		Fx.float(tx, ty, t('messages.sapper_detonate'), 'heal');
		Fx.flash('rgba(255,136,0,.25)');
		Fx.burst(tx, ty, {count:35,colors:['#f80','#ff4','#fa0','#fff'],shape:'spark',speed:7,spread:24,decay:0.015,size:7});
		Fx.burst(tx, ty, {count:6,colors:['#ff880044'],shape:'ring',speed:0,spread:5,decay:0.01,size:20});
		Fx.later(()=>Fx.burst(tx, ty, {count:12,colors:['#f80','#ff4'],shape:'star',speed:3,spread:16,decay:0.02,size:5}),80);
		Fx.burst(tx, ty, {count:8,colors:['#ff8800','#ffcc00'],shape:'circle',speed:2,spread:18,decay:0.012,size:4,gravity:0.06});
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, rmDead:true, chkEnd:true});
	}
});
