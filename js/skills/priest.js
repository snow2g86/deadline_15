// ═══════════════════════════════════════════
//  skills/priest.js — 사제 스킬 핸들러
// ═══════════════════════════════════════════

// ── 집단 치유 (기본) ─────────────────────
registerSkill('priest_massheal', {
	target(u, sk, G) { return 'instant'; },
	exec(u, tx, ty, sk, G) {
		const hr = sk.healRange || 6;
		const targets = G.units.filter(v => v.team==='ally' && v.hp>0 && v.hp<v.mhp && mh(u.x,u.y,v.x,v.y)<=hr);
		if (!targets.length) { _skillRefund(u, sk, G); G.floatT(u.x,u.y,t('messages.select_heal_target'),'damage'); return; }
		let amt = u.atk;
		if (u.skillLv && u.skillLv['priest_divinegrace'] >= 1) amt = Math.round(amt * 1.2);
		targets.forEach(tgt => {
			tgt.hp = Math.min(tgt.mhp, tgt.hp+amt);
			G.floatT(tgt.x, tgt.y, `+${amt}`, 'heal');
			G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:12,colors:['#4f4','#8f8','#fff'],shape:'ring',speed:3,spread:10,decay:0.02,size:7});
			G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:4,colors:['#4f4','#fff'],shape:'diamond',speed:1.5,spread:6,decay:0.025,size:3,vy:-1.5});
		});
		G.sfxHeal(); G.floatT(u.x, u.y, t('messages.priest_mass_heal'), 'heal');
		G.vfxFlash('rgba(68,255,68,.15)');
		G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:22,colors:['#4f4','#ff8','#fff'],shape:'ring',speed:4,spread:18,decay:0.015,size:9});
		setTimeout(()=>G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:8,colors:['#4f4','#8f8'],shape:'star',speed:2,spread:12,decay:0.02,size:4,vy:-1}),80);
		G._grantExp(u, 'heal');
		_skillDone(u, G);
	}
});

// ── 정화 (습득형) ────────────────────────
registerSkill('priest_purify', {
	target(u, sk, G) {
		const pr = sk.purifyRange || 5;
		return G.units.filter(v => v.team==='ally' && v.hp>0 && v.id!==u.id && mh(u.x,u.y,v.x,v.y)<=pr &&
			(v.stunned>0 || v.frozen>0 || v.disarmed>0 || v._bleedTurns>0 || v._rootedTurns>0)
		).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='ally' && v.hp>0 && v.id!==u.id);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		tgt.stunned = 0; tgt.frozen = 0; tgt.disarmed = 0; tgt._bleedTurns = 0; tgt._bleedDmg = 0; tgt._rootedTurns = 0;
		G.sfxHeal();
		G.floatT(tgt.x, tgt.y, t('messages.priest_purify'), 'heal');
		G.floatT(u.x, u.y, t('messages.priest_purify_cast'), 'heal');
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:20,colors:['#88f','#aaf','#fff'],shape:'ring',speed:4,spread:16,decay:0.018,size:7});
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:6,colors:['#88f','#fff'],shape:'diamond',speed:2,spread:10,decay:0.025,size:3,vy:-2});
		G._grantExp(u, 'heal');
		_skillDone(u, G);
	}
});

// ── 성역선포 (습득형) ────────────────────
registerSkill('priest_sanctuary', {
	target(u, sk, G) { return 'instant'; },
	exec(u, tx, ty, sk, G) {
		const sr = sk.sanctuaryRange || 6;
		const targets = G.units.filter(v => v.team==='ally' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=sr);
		if (!targets.length) { _skillRefund(u, sk, G); return; }
		let healAmt = Math.max(1, Math.round(u.atk*0.5));
		if (u.skillLv && u.skillLv['priest_divinegrace'] >= 1) healAmt = Math.round(healAmt * 1.2);
		targets.forEach(tgt => {
			tgt._sanctuaryTurns = 4; tgt._sanctuaryHeal = healAmt;
			G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:8,colors:['#fbbf24','#fff','#4f4'],shape:'ring',speed:2,spread:8,decay:0.025,size:5});
		});
		G.sfxHeal();
		G.floatT(u.x, u.y, t('messages.priest_sanctuary'), 'heal');
		G.vfxFlash('rgba(251,191,36,.15)');
		G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:28,colors:['#fbbf24','#ff8','#fff'],shape:'ring',speed:5,spread:20,decay:0.015,size:10});
		setTimeout(()=>G.vfxSpawn(G.uSX(u.x,u.y)+UCX, G.uSY(u.x,u.y)+UCY, {count:10,colors:['#fbbf24','#ff8'],shape:'star',speed:2,spread:14,decay:0.02,size:4,vy:-1}),80);
		G._grantExp(u, 'heal');
		_skillDone(u, G);
	}
});
