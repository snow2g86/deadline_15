// ═══════════════════════════════════════════
//  skills/summoner.js — 소환사 스킬 핸들러
// ═══════════════════════════════════════════

function _summonerTarget(u, sk, G) {
	const maxSummons = 1;
	const currentSummons = G.units.filter(s => s.isSummon && s.summonerId === u.id);
	if (currentSummons.length >= maxSummons) {
		G.floatT(u.x, u.y, t('messages.summoner_limit'), 'damage');
		return null;
	}
	const summonRange = sk.summonRange || 3;
	const cells = [];
	for (let x=0; x<COLS; x++) for (let y=0; y<ROWS; y++) {
		if (mh(u.x,u.y,x,y)<=summonRange && mh(u.x,u.y,x,y)>0) {
			const ti = TI[G.ter[y][x]]; if (!ti || !ti.pass) continue;
			if (G.uAt(x,y)) continue;
			cells.push({x,y});
		}
	}
	return cells;
}

function _summonerExec(u, tx, ty, sk, G) {
	const target = G.units.find(v => v.x===tx && v.y===ty);
	if (target || !TI[G.ter[ty][tx]].pass) {
		_skillRefund(u, sk, G); G.floatT(u.x,u.y,t('messages.summoner_no_spawn'),'damage'); return;
	}
	const isSpirit = sk.id === 'summoner_summon_spirit';
	const summonCls = sk.summonType;
	let hp, atk, def, move, range, role;
	if (isSpirit) {
		hp = Math.round(u.mhp*0.5); atk = Math.round(u.atk*0.5); def = 0; move = 3; range = 3; role = 'ranged';
	} else {
		hp = Math.round(u.mhp*1.2); atk = Math.round(u.atk*0.5); def = Math.round(u.def*1.2); move = 2; range = 1; role = 'melee';
	}
	const summonName = isSpirit ? '정령' : '골램';
	const summon = {
		id: G.nid++, uid: 0, team: 'ally', cls: summonCls,
		isSummon: true, summonerId: u.id,
		x: tx, y: ty, hp, mhp: hp, atk, def,
		move, range, role,
		res: 0, maxRes: 0, resType: 'none', resRec: 0,
		summonTurns: 5,
		hm: false, ha: false, waited: false, mo: false,
		furyBuff: 0, defBuff: 0, stunned: 0
	};
	G.units.push(summon);
	G.floatT(tx, ty, t('messages.sapper_summon', {name:summonName}), 'heal');
	const colors = isSpirit ? ['#8b5cf6','#c084fc','#fff'] : ['#78716c','#a8a29e','#fff'];
	G.vfxSpawn(G.uSX(tx,ty)+UCX, G.uSY(tx,ty)+UCY, {count:25,colors,shape:'ring',speed:5,spread:20,decay:0.02,size:8});
	G.sfxHeal(); G._grantExp(u, 'attack');
	_skillDone(u, G);
}

// ── 정령소환 ─────────────────────────────
registerSkill('summoner_summon_spirit', {
	target: _summonerTarget,
	exec: _summonerExec
});

// ── 골램소환 ─────────────────────────────
registerSkill('summoner_summon_golem', {
	target: _summonerTarget,
	exec: _summonerExec
});

// ── 소환 강화 (습득형) ────────────────────
registerSkill('summoner_empower', {
	target(u, sk, G) {
		const summons = G.units.filter(s => s.isSummon && s.summonerId === u.id && s.hp > 0);
		if (!summons.length) { G.floatT(u.x, u.y, t('messages.summoner_no_summon'), 'damage'); return null; }
		return summons.map(s => ({x:s.x, y:s.y}));
	},
	exec(u, tx, ty, sk, G) {
		const summon = G.units.find(s => s.x===tx && s.y===ty && s.isSummon && s.summonerId===u.id && s.hp>0);
		if (!summon) { _skillRefund(u, sk, G); return; }
		summon._empowerTurns = 3; summon._empowerMul = 1.5;
		G.sfxHeal();
		G.floatT(summon.x, summon.y, t('messages.summoner_empower'), 'heal');
		G.vfxSpawn(G.uSX(summon.x,summon.y)+UCX, G.uSY(summon.x,summon.y)+UCY, {count:20,colors:['#fbbf24','#f59e0b','#fff'],shape:'ring',speed:4,spread:16,decay:0.018,size:7});
		G.vfxSpawn(G.uSX(summon.x,summon.y)+UCX, G.uSY(summon.x,summon.y)+UCY, {count:6,colors:['#fbbf24','#f59e0b'],shape:'star',speed:2,spread:10,decay:0.025,size:3,vy:-1});
		G._grantExp(u, 'attack');
		_skillDone(u, G);
	}
});

// ── 영혼 폭발 (습득형) ────────────────────
registerSkill('summoner_soulburst', {
	target(u, sk, G) {
		const summons = G.units.filter(s => s.isSummon && s.summonerId === u.id && s.hp > 0);
		if (!summons.length) { G.floatT(u.x, u.y, t('messages.summoner_no_summon'), 'damage'); return null; }
		return summons.map(s => ({x:s.x, y:s.y}));
	},
	exec(u, tx, ty, sk, G) {
		const summon = G.units.find(s => s.x===tx && s.y===ty && s.isSummon && s.summonerId===u.id && s.hp>0);
		if (!summon) { _skillRefund(u, sk, G); return; }
		const burstAtk = summon.atk * 3;
		for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) {
			const px = summon.x+dx, py = summon.y+dy;
			if (px<0||px>=COLS||py<0||py>=ROWS) continue;
			const tgt = G.units.find(v => v.hp>0 && v.x===px && v.y===py && v.team==='enemy');
			if (tgt) {
				const dmg = Math.max(1, burstAtk - tgt.def);
				tgt.hp = Math.max(0, tgt.hp - dmg);
				G.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage'); G.shakeU(tgt.id);
				G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:10,colors:['#8b5cf6','#c084fc','#fff'],shape:'spark',speed:4,spread:10,decay:0.025,size:4});
				if (tgt.hp<=0) {G.screenShake();G.sfxKill();G.sfxDeath();G.vfxDeath(tgt);G.deathA(tgt.id)}
			}
		}
		G.floatT(summon.x, summon.y, t('messages.summoner_soulburst'), 'damage');
		G.vfxDeath(summon);
		G.vfxFlash('rgba(139,92,246,.25)');
		G.vfxSpawn(G.uSX(summon.x,summon.y)+UCX, G.uSY(summon.x,summon.y)+UCY, {count:28,colors:['#8b5cf6','#c084fc','#fff'],shape:'spark',speed:7,spread:22,decay:0.015,size:6});
		G.vfxSpawn(G.uSX(summon.x,summon.y)+UCX, G.uSY(summon.x,summon.y)+UCY, {count:6,colors:['#8b5cf644'],shape:'ring',speed:0,spread:5,decay:0.01,size:18});
		setTimeout(()=>G.vfxSpawn(G.uSX(summon.x,summon.y)+UCX, G.uSY(summon.x,summon.y)+UCY, {count:10,colors:['#8b5cf6','#c084fc'],shape:'star',speed:3,spread:14,decay:0.025,size:4}),80);
		G.units = G.units.filter(v => v.id !== summon.id);
		G.sfxAtk(u.cls); G.sfxExplosion(); G.screenShake(true); G._grantExp(u, 'attack');
		_skillDone(u, G, {delay:500, rmDead:true, chkEnd:true});
	}
});
