// ═══════════════════════════════════════════
//  skills/assassin.js — 암살자 스킬 핸들러
// ═══════════════════════════════════════════

// ── 암살 (기본 스킬) ────────────────────
registerSkill('assassin_assassinate', {
	target(u, sk, G) {
		if (!isStealthed(u)) return null;
		const enemy = G.units.find(v => v.team === 'enemy' && v.hp > 0 && v.x === u.x && v.y === u.y);
		if (!enemy) return null;
		return 'instant';
	},
	exec(u, tx, ty, sk, G) {
		const tgt = G.units.find(v => v.team === 'enemy' && v.hp > 0 && v.x === u.x && v.y === u.y);
		if (!tgt || !isStealthed(u)) { _skillRefund(u, sk, G); return; }
		const dmg = Math.max(1, Math.round(u.atk * 5 * G.skMul(u, 'assassin_assassinate')) - tgt.def);
		tgt.hp = Math.max(0, tgt.hp - dmg);
		G.sfxAtk(u.cls); Fx.shake(tgt.id); Fx.screenShake(true);
		Fx.float(tgt.x, tgt.y, `-${dmg}`, 'damage');
		Fx.float(u.x, u.y, t('messages.assassin_assassinate'), 'heal');
		Fx.flash('rgba(168,85,247,.2)');
		Fx.burst(tgt.x, tgt.y, {count: 24, colors: ['#a855f7', '#7c3aed', '#fff'], shape: 'spark', speed: 6, spread: 18, decay: 0.018, size: 6});
		Fx.burst(tgt.x, tgt.y, {count: 6, colors: ['#a855f7', '#7c3aed'], shape: 'slash', speed: 4, spread: 10, decay: 0.025, size: 5});
		const adj = G._findAdj(u.x, u.y, u);
		if (adj) { G._mvU(u, adj.x, adj.y); }
		if (tgt.hp <= 0) { Fx.screenShake(true); G.sfxKill(); G.sfxDeath(); Fx.death(tgt); G.deathA(tgt.id); }
		G._grantExp(u, 'attack');
		_skillDone(u, G, {delay: 500, rmDead: true, chkEnd: true});
	}
});

// ── 습격 (습득형) ────────────────────────
registerSkill('assassin_ambush', {
	target(u, sk, G) {
		if (!isStealthed(u)) return null;
		const range = sk.ambushRange || 2;
		return G.units.filter(v => v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=range).map(v => ({x:v.x,y:v.y}));
	},
	exec(u, tx, ty, sk, G) {
		if (!isStealthed(u)) { _skillRefund(u, sk, G); return; }
		const range = sk.ambushRange || 2;
		const tgt = G.units.find(v => v.x===tx && v.y===ty && v.team==='enemy' && v.hp>0 && mh(u.x,u.y,v.x,v.y)<=range);
		if (!tgt) { _skillRefund(u, sk, G); return; }
		const adj = G._findAdj(tgt.x, tgt.y, u);
		if (!adj) { _skillRefund(u, sk, G); Fx.float(u.x,u.y,t('messages.no_empty_tile'),'damage'); return; }
		G._mvU(u, adj.x, adj.y); u.mo = true;
		Fx.later(() => {
			const dmg = Math.max(1, u.atk*2 - tgt.def);
			tgt.hp = Math.max(0, tgt.hp - dmg);
			Fx.burst(tgt.x, tgt.y, {count:16,colors:['#a855f7','#fff','#c4b5fd'],shape:'spark',speed:5,spread:14,decay:0.02,size:5});
			Fx.burst(tgt.x, tgt.y, {count:4,colors:['#a855f7','#7c3aed'],shape:'slash',speed:3,spread:8,decay:0.03,size:4});
			G.sfxAtk(u.cls); Fx.shake(tgt.id); Fx.screenShake();
			Fx.float(tgt.x, tgt.y, `-${dmg}`, 'damage');
			Fx.float(u.x, u.y, t('messages.assassin_raid'), 'heal');
			if (tgt.hp<=0) {
				u.res = Math.min(u.maxRes, u.res+20);
				Fx.float(u.x, u.y, '+20 EP', 'exp');
				Fx.screenShake();G.sfxKill();G.sfxDeath();Fx.death(tgt);G.deathA(tgt.id);G._rmDead();
			}
			G._grantExp(u, 'attack');
			_skillDone(u, G, {delay:500, chkEnd:true});
		}, 360);
	}
});

// ── 연막 (습득형): 숲 밖에서도 은신 — 다음 자기 차례가 끝날 때까지 (BuffSystem STEALTH, isStealthed가 확인) ──
// 직접 피해 없음. 은신 중에는 적 AI의 표적에서 빠지고 습격을 쓸 수 있다
registerSkill('assassin_smoke', {
	target(u, sk, G) { return 'instant'; },
	exec(u, tx, ty, sk, G) {
		// 지속 2: 이번 차례 종료 틱 1회 + 다음 자기 차례 종료 틱 1회 → 적 차례 동안과 다음 자기 차례에 은신
		BuffSystem.apply(u, { type: BuffType.STEALTH, duration: sk.smokeTurns || 2, icon: '🌫️', source: 'assassin_smoke' });
		u.stealthBroken = false;
		Fx.float(u.x, u.y, t('messages.assassin_smoke'), 'heal');
		Fx.burst(u.x, u.y, {count: 22, colors: ['#9ca3af', '#d1d5db', '#6b7280'], shape: 'circle', speed: 2, spread: 18, decay: 0.012, size: 6, gravity: -0.02});
		G.sfxMove();
		_skillDone(u, G, {delay: 400});
	}
});
