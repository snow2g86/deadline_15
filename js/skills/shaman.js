// ═══════════════════════════════════════════
//  skills/shaman.js — 주술사 스킬 핸들러
// ═══════════════════════════════════════════

// ── 쇠약의 저주 ─────────────────────────
registerSkill('shaman_curse', {
	target(u, sk, G) {
		const cr = sk.curseRange || 5;
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=cr).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0);
		if (!tgt) { _skillRefund(u, sk, G); return; }

		// 저주 적용: 이동 시마다 최대 체력 5% 피해, 5회 후 제거
		tgt._cursed = true;
		tgt._curseAtk = u.atk;
		tgt._curseDmgCount = 0; // 0/5

		G.sfxAtk(u.cls);
		G.floatT(tgt.x, tgt.y, t('messages.shaman_curse'), 'debuff');
		G.floatT(u.x, u.y, t('messages.shaman_curse'), 'heal');
		G.vfxFlash('rgba(147,51,234,.15)');
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:22,colors:['#9333ea','#581c87','#a855f7'],shape:'ring',speed:4,spread:16,decay:0.018,size:7});
		setTimeout(()=>G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:8,colors:['#9333ea','#a855f7'],shape:'star',speed:2,spread:10,decay:0.025,size:4,vy:-1}),80);

		G._grantExp(u, 'attack');
		_skillDone(u, G);
	}
});

// ── 고양 ────────────────────────────────
registerSkill('shaman_exalt', {
	target(u, sk, G) {
		const er = sk.exaltRange || 5;
		return G.units.filter(v => v.team==='ally' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=er && v.id!==u.id).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='ally' && v.hp>0);
		if (!tgt) { _skillRefund(u, sk, G); return; }

		// 2회 공격 한정 버프
		if (!tgt.buffs) tgt.buffs = [];
		tgt.buffs.push({ type: 'atk_up', duration: 999, value: 10, source: 'shaman_exalt', _attackCount: 2 });

		G.sfxHeal();
		G.floatT(tgt.x, tgt.y, t('messages.shaman_exalt'), 'buff');
		G.floatT(u.x, u.y, t('messages.shaman_exalt'), 'heal');
		G.vfxFlash('rgba(245,158,11,.15)');
		G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:22,colors:['#f59e0b','#fbbf24','#fff'],shape:'ring',speed:4,spread:16,decay:0.018,size:7});
		setTimeout(()=>G.vfxSpawn(G.uSX(tgt.x,tgt.y)+UCX, G.uSY(tgt.x,tgt.y)+UCY, {count:8,colors:['#f59e0b','#fbbf24'],shape:'diamond',speed:1.5,spread:10,decay:0.025,size:3,vy:-1.5}),80);

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

// ── 쇠약의 저주 틱: 저주받은 유닛이 이동할 때마다 최대 HP 5% (사망하지 않음, 5회 후 해제) ──
// 아군 이동은 ActionManager.doMv, 적 이동은 AI._moveUnit 에서 호출 (예전엔 적 이동에서 빠져 있어 적에게 효과가 없었음)
function curseMoveTick(u) {
	if (!u._cursed || !(u.mhp > 0) || u.hp <= 0) return;
	const dmg = Math.max(1, Math.round(u.mhp * 0.05));
	u.hp = Math.max(1, u.hp - dmg);
	u._curseDmgCount = (u._curseDmgCount || 0) + 1;
	G.floatT(u.x, u.y, '-' + dmg, 'damage');
	G.floatT(u.x, u.y, t('messages.curse_tick', { n: u._curseDmgCount }), 'debuff');
	if (u._curseDmgCount >= 5) {
		u._cursed = false; u._curseAtk = 0; u._curseDmgCount = 0;
		G.floatT(u.x, u.y, t('messages.curse_end'), 'heal');
	}
}

// ── 독안개 틱: 라운드가 끝날 때마다 안개(3×3) 안의 상대에게 시전자 ATK×0.3 (방어 무시, 사망하지 않음) ──
// turn.js _countTurn(라운드 종료)에서 호출. 예전엔 안개를 만들기만 하고 처리하는 곳이 없었음
function tickPoisonMists() {
	const S = GameStore;
	if (!S.poisonMists || !S.poisonMists.length) return;
	S.poisonMists.forEach(m => {
		const foe = m.team === 'ally' ? 'enemy' : 'ally';
		const dmg = Math.max(1, Math.round(m.atk * 0.3));
		S.units.filter(v => v.team === foe && v.hp > 0 && Math.abs(v.x - m.cx) <= 1 && Math.abs(v.y - m.cy) <= 1).forEach(v => {
			const d = Math.min(dmg, v.hp - 1);
			if (d <= 0) return;
			v.hp -= d;
			G.floatT(v.x, v.y, '☁️ -' + d, 'damage');
		});
		G.vfxSpawn(G.uSX(m.cx, m.cy) + UCX, G.uSY(m.cx, m.cy) + UCY, {count: 10, colors: ['#22c55e44', '#4ade8044'], shape: 'circle', speed: 1, spread: 16, decay: 0.012, size: 5, gravity: -0.02});
		m.turns--;
	});
	S.poisonMists = S.poisonMists.filter(m => m.turns > 0);
	G.rUnits();
}
