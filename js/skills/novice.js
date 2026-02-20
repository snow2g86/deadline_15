// ═══════════════════════════════════════════
//  skills/novice.js — 노비스 스킬 핸들러
// ═══════════════════════════════════════════

// ── 돌던지기 (기본 스킬) ────────────────────
registerSkill('novice_throw', {
	target(u, sk, G) {
		const rng = sk.throwRange || 4;
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=rng).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const rng = sk.throwRange || 4;
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=rng);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const dmg = Math.max(1, Math.round(u.atk*0.5*G.skMul(u,'novice_throw')) - tgt.def);
		tgt.hp = Math.max(0, tgt.hp - dmg);
		G.sfxAtk(u.cls); G.shakeU(tgt.id);
		G.floatT(tgt.x, tgt.y, '-' + dmg, 'damage');
		G.floatT(u.x, u.y, t('skills.novice_throw'), 'heal');
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:8,colors:['#aaa','#888','#fff'],shape:'spark',speed:3,spread:8,decay:0.03,size:3});
		if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id);G._rmDead()}
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:400, chkEnd:true});
	}
});
