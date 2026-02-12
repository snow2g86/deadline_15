// ═══════════════════════════════════════════
//  skills/shaman.js — 주술사 스킬 핸들러
// ═══════════════════════════════════════════

// ── 쇠약의 저주 ─────────────────────────
registerSkill('shaman_curse', {
	target(u, sk, G) { return 'instant'; },
	exec(u, tx, ty, sk, G) {
		u.channeling = 'shaman_curse';
		G.floatT(u.x, u.y, t('messages.shaman_curse'), 'heal');
		G.vfxFlash('rgba(147,51,234,.15)');
		G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:22,colors:['#9333ea','#581c87','#a855f7'],shape:'ring',speed:4,spread:16,decay:0.018,size:7});
		setTimeout(()=>G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:8,colors:['#9333ea','#a855f7'],shape:'star',speed:2,spread:10,decay:0.025,size:4,vy:-1}),80);
		G.sfxAtk(u.cls); G._grantExp(u, 'attack');
		_skillDone(u, G);
	}
});

// ── 고양 ────────────────────────────────
registerSkill('shaman_exalt', {
	target(u, sk, G) { return 'instant'; },
	exec(u, tx, ty, sk, G) {
		u.channeling = 'shaman_exalt';
		G.floatT(u.x, u.y, t('messages.shaman_exalt'), 'heal');
		G.vfxFlash('rgba(245,158,11,.15)');
		G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:22,colors:['#f59e0b','#fbbf24','#fff'],shape:'ring',speed:4,spread:16,decay:0.018,size:7});
		setTimeout(()=>G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:8,colors:['#f59e0b','#fbbf24'],shape:'diamond',speed:1.5,spread:10,decay:0.025,size:3,vy:-1.5}),80);
		G.sfxHeal();
		G.alive('ally').forEach(a => {
			if (a.id !== u.id) G.vfxSpawn(G.uSX(a.x,a.y)+UCX, G.uSY(a.x,a.y)+UCY, {count:6,colors:['#f59e0b','#fbbf24'],shape:'spark',speed:2,spread:6,decay:0.03,size:3});
		});
		G._grantExp(u, 'heal');
		_skillDone(u, G);
	}
});

// ── 독안개 (습득형) ────────────────────
registerSkill('shaman_poisonmist', {
	target(u, sk, G) {
		const mr = sk.mistRange || 5;
		const cells = [];
		for (let x=0; x<COLS; x++) for (let y=0; y<ROWS; y++) {
			if (mh(u.x,u.y,x,y)<=mr && mh(u.x,u.y,x,y)>0) cells.push({x,y});
		}
		return cells;
	},
	exec(u, tx, ty, sk, G) {
		if (!G.poisonMists) G.poisonMists = [];
		G.poisonMists.push({ cx:tx, cy:ty, atk:u.atk, turns:3, team:'ally' });
		G.sfxAtk(u.cls); G.screenShake();
		G.floatT(tx, ty, t('messages.shaman_poisonmist'), 'heal');
		G.vfxFlash('rgba(34,197,94,.15)');
		G.vfxSpawn(G.uSX(tx,ty)+UCX, G.uSY(tx,ty)+UCY, {count:30,colors:['#22c55e','#4ade80','#86efac'],shape:'ring',speed:5,spread:22,decay:0.012,size:12});
		G.vfxSpawn(G.uSX(tx,ty)+UCX, G.uSY(tx,ty)+UCY, {count:12,colors:['#22c55e44','#4ade8044'],shape:'circle',speed:1.5,spread:18,decay:0.01,size:5,gravity:-0.02});
		setTimeout(()=>G.vfxSpawn(G.uSX(tx,ty)+UCX, G.uSY(tx,ty)+UCY, {count:8,colors:['#22c55e','#4ade80'],shape:'star',speed:2,spread:14,decay:0.02,size:4,vy:-1}),100);
		G._grantExp(u, 'attack');
		_skillDone(u, G);
	}
});

// ── 영혼 쇄도 (습득형) ────────────────────
registerSkill('shaman_spiritsurge', {
	target(u, sk, G) {
		const sr = sk.surgeRange || 5;
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=sr).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const dmg = Math.max(1, Math.round(u.atk * 1.0 * G.skMul(u, 'shaman_spiritsurge')) - tgt.def);
		tgt.hp = Math.max(0, tgt.hp - dmg);
		tgt._rootedTurns = 1;
		G.sfxAtk(u.cls); G.shakeU(tgt.id);
		G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
		G.floatT(tgt.x, tgt.y, t('messages.rooted'), 'debuff');
		G.floatT(u.x, u.y, t('messages.shaman_spiritsurge'), 'heal');
		G.vfxFlash('rgba(147,51,234,.18)');
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:20,colors:['#9333ea','#a855f7','#fff'],shape:'spark',speed:5,spread:16,decay:0.02,size:6});
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:4,colors:['#9333ea44'],shape:'ring',speed:0,spread:4,decay:0.015,size:14});
		setTimeout(()=>G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:6,colors:['#9333ea','#a855f7'],shape:'cross',speed:2,spread:8,decay:0.03,size:4}),60);
		if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id)}
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, rmDead:true, chkEnd:true});
	}
});
