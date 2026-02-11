// ═══════════════════════════════════════════
//  skills/novice.js — 노비스 스킬 핸들러
// ═══════════════════════════════════════════

// ── 돌던지기 (기본) ──────────────────────
registerSkill('novice_throw', {
	target(u, sk, G) {
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=sk.throwRange).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const dmg = Math.max(1, Math.round(u.atk*0.5) - tgt.def);
		tgt.hp = Math.max(0, tgt.hp - dmg);
		G.sfxAtk(u.cls); G.shakeU(tgt.id);
		G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
		G.floatT(u.x, u.y, t('messages.stone_throw'), 'heal');
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:8,colors:['#a88','#ccc','#fff'],shape:'spark',speed:3,spread:8,decay:0.03,size:3});
		if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id)}
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, rmDead:true, chkEnd:true});
	}
});
