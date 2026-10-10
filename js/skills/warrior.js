// ═══════════════════════════════════════════
//  skills/warrior.js — 전사 스킬 핸들러
// ═══════════════════════════════════════════

// ── 강타 (기본 스킬) ────────────────────
registerSkill('warrior_powersmash', {
	target(u, sk, G) {
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=u.range).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=u.range);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const mul = G.skMul(u,'warrior_powersmash');
		const dmg = Math.max(1, Math.round(u.atk*1.5*mul) - tgt.def);
		tgt.hp = Math.max(0, tgt.hp - dmg);
		Fx.attack(u, tgt); G.sfxAtk(u.cls); Fx.shake(tgt.id); Fx.screenShake();
		Fx.float(tgt.x, tgt.y, '-' + dmg, 'damage');
		Fx.float(u.x, u.y, t('skills.warrior_powersmash'), 'heal');
		Fx.flash('rgba(255,100,0,.15)');
		Fx.burst(tgt.x, tgt.y, {count:16,colors:['#ff4400','#ff8800','#fff'],shape:'spark',speed:5,spread:14,decay:0.02,size:5});
		Fx.burst(tgt.x, tgt.y, {count:4,colors:['#ff440044'],shape:'ring',speed:0,spread:4,decay:0.015,size:12});
		procFury(u, tgt, G);
		if (tgt.hp<=0) {Fx.screenShake();G.sfxKill();G.sfxDeath();Fx.death(tgt);G.deathA(tgt.id);G._rmDead()}
		G._grantExp(u, 'attack');
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
				Fx.float(tgt.x, tgt.y, `-${dmg}`, 'damage'); Fx.shake(tgt.id);
				Fx.burst(tgt.x, tgt.y, {count:10,colors:['#f44','#f80','#fff'],shape:'spark',speed:4,spread:10,decay:0.025,size:4});
				Fx.burst(tgt.x, tgt.y, {count:4,colors:['#ff4400','#ffcc00'],shape:'cross',speed:2,spread:6,decay:0.03,size:3});
				if (tgt.hp<=0) {Fx.screenShake();G.sfxKill();G.sfxDeath();Fx.death(tgt);G.deathA(tgt.id);G._rmDead()}
			}
		});
		G.sfxAtk(u.cls); Fx.screenShake(true); Fx.flash('rgba(255,100,0,.2)'); G._grantExp(u, 'attack');
		Fx.float(u.x, u.y, t('messages.warrior_cleave'), 'heal');
		Fx.burst(u.x, u.y, {count:28,colors:['#ff4400','#ff8800','#ffcc00'],shape:'ring',speed:5,spread:20,decay:0.015,size:8});
		Fx.burst(u.x, u.y, {count:12,colors:['#fff','#ffcc00'],shape:'slash',speed:5,spread:16,decay:0.03,size:5});
		Fx.later(()=>Fx.burst(u.x, u.y, {count:10,colors:['#ff4400','#ff8800'],shape:'star',speed:3,spread:14,decay:0.025,size:4}),80);
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
		if (!adj) { _skillRefund(u, sk, G); Fx.float(u.x,u.y,t('messages.no_empty_tile'),'damage'); return; }
		u.x=adj.x; u.y=adj.y; u.mo=true;
		Fx.animU(u.id, adj.x, adj.y);
		Fx.later(()=>{
			const dirs=[{x:-1,y:-1},{x:0,y:-1},{x:1,y:-1},{x:-1,y:0},{x:1,y:0},{x:-1,y:1},{x:0,y:1},{x:1,y:1}];
			dirs.forEach(d => {
				const px=u.x+d.x, py=u.y+d.y;
				if(px<0||px>=COLS||py<0||py>=ROWS) return;
				const e=G.units.find(v=>v.hp>0&&v.x===px&&v.y===py&&v.team==='enemy');
				if(e){
					const dmg=Math.max(1,Math.round(u.atk*0.8*G.skMul(u,'warrior_assault'))-e.def);
					e.hp=Math.max(0,e.hp-dmg);
					Fx.float(e.x,e.y,`-${dmg}`,'damage');Fx.shake(e.id);
					Fx.burst(e.x, e.y, {count:10,colors:['#f44','#f80','#fff'],shape:'spark',speed:4,spread:10,decay:0.025,size:4});
					Fx.burst(e.x, e.y, {count:3,colors:['#ff4400','#ffcc00'],shape:'cross',speed:2,spread:5,decay:0.03,size:3});
					if(e.hp<=0){Fx.screenShake();G.sfxKill();G.sfxDeath();Fx.death(e);G.deathA(e.id);G._rmDead()}
				}
			});
			G.sfxAtk(u.cls); G.sfxExplosion(); Fx.screenShake(true); Fx.flash('rgba(255,80,0,.25)'); G._grantExp(u,'attack');
			Fx.float(u.x,u.y,t('messages.warrior_assault'),'heal');
			Fx.burst(u.x, u.y, {count:30,colors:['#ff4400','#ff8800','#ffcc00'],shape:'spark',speed:7,spread:22,decay:0.015,size:7});
			Fx.burst(u.x, u.y, {count:6,colors:['#ff440044'],shape:'ring',speed:0,spread:5,decay:0.01,size:18});
			Fx.later(()=>Fx.burst(u.x, u.y, {count:12,colors:['#ff4400','#ff8800'],shape:'star',speed:4,spread:16,decay:0.02,size:5}),100);
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
		Fx.attack(u, tgt); G.sfxAtk(u.cls); Fx.shake(tgt.id); Fx.screenShake();
		Fx.float(tgt.x, tgt.y, `-${dmg}`, 'damage');
		Fx.float(tgt.x, tgt.y, t('messages.warrior_bleed'), 'debuff');
		Fx.float(u.x, u.y, t('messages.warrior_criticalstrike'), 'heal');
		Fx.flash('rgba(220,38,38,.2)');
		Fx.burst(tgt.x, tgt.y, {count:18,colors:['#dc2626','#ef4444','#fff'],shape:'spark',speed:5,spread:14,decay:0.02,size:5});
		Fx.burst(tgt.x, tgt.y, {count:4,colors:['#dc262644'],shape:'ring',speed:0,spread:4,decay:0.015,size:14});
		Fx.later(()=>Fx.burst(tgt.x, tgt.y, {count:6,colors:['#dc2626','#ef4444'],shape:'cross',speed:2,spread:8,decay:0.03,size:4}),60);
		procFury(u, tgt, G);
		if (tgt.hp<=0) {Fx.screenShake();G.sfxKill();G.sfxDeath();Fx.death(tgt);G.deathA(tgt.id);G._rmDead()}
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, chkEnd:true});
	}
});
