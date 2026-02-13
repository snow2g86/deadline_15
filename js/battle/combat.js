// ═══════════════════════════════════════════
//  battle/combat.js — Combat system (selU, cellCk, doAtk, doSkill, etc.)
// ═══════════════════════════════════════════

Object.assign(G, {
	selU(u) {
		if (this.phase !== 'player' || this.over || this.anim || this.awPM) return;
		if (u.team === 'ally' && u.ha && !u.waited) return;
		if (u.team === 'ally' && u.waited) {
			u.ha = false; u.waited = false;
			this.sel = u; this.awPM = true; this.mvT = [];
			if (u.channeling) { this.atkT = []; this.healT = [] }
			else {
				const a = this.atkC(u);
				if (u.role === 'healer') { this.atkT = []; this.healT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'ally' && v.hp < v.mhp && v.id !== u.id }) }
				else { this.atkT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'enemy' }); this.healT = [] }
			}
			this.rTer(); this.rUnits(); this.showAM(u); this.showUI(u); this.rNav(); this.scrollToUnit(u); this.sfxSelect(); return
		}
		this.sel = u; this.awPM = true;
		if (u.team === 'ally' && !u.ha) {
			this.mvT = []; const a = this.atkC(u);
			if (u.role === 'healer') { this.atkT = []; this.healT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'ally' && v.hp < v.mhp && v.id !== u.id }) }
			else { this.atkT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'enemy' }); this.healT = [] }
		}
		else { this.mvT = []; this.atkT = []; this.healT = [] } this.rTer(); this.rUnits(); this.showAM(u); this.showUI(u); this.rNav(); this.scrollToUnit(u); this.sfxSelect()
	},
	clrSel() { this.sel = null; this.mvT = []; this.atkT = []; this.healT = []; this.awPM = false; this.skillMode = false; this.skillMenuOpen = false; this._curSkill = null; this.siegeMode = false; this._curSiege = null; this.potionMode = false; this._curPotion = null; this.potionTargets = []; this.itemMenuOpen = false; this.preMv = null; this.hideAM(); this.rTer(); this.rUnits(); this.defI(); this.rNav() },
	cellCk(x, y) {
		if (this.phase !== 'player' || this.over || this.anim) return; const cl = this.uAt(x, y), s = this.sel;
		if (this.awPM && s) {
			if (this.potionMode) {
				const potTarget = this.potionTargets.find(t => t.x === x && t.y === y);
				if (potTarget) { this.doPotion(potTarget); return }
				this.potionMode = false; this._curPotion = null;
				this.potionTargets = []; this.rTer(); this.showAM(s); return;
			}
			if (this.siegeMode) {
				if (this.atkT.some(c => c.x === x && c.y === y)) { this.doSiege(s, x, y); return }
				this.siegeMode = false; this._curSiege = null;
				this.atkT = []; this.rTer(); this.showAM(s); return;
			}
			if (this.skillMode) {
				if (this.atkT.some(c => c.x === x && c.y === y)) { this.doSkill(s, x, y); return }
				this.skillMode = false; const a = this.atkC(s);
				if (s.role === 'healer') { this.atkT = []; this.healT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'ally' && v.hp < v.mhp && v.id !== s.id }) }
				else { this.atkT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'enemy' }); this.healT = [] }
				this.rTer(); this.showAM(s); return
			}
			if (cl && cl.team === 'enemy' && s.cls === 'assassin' && s.team === 'ally' && !s.ha && this.ter[y] && this.ter[y][x] === 'forest' && this.mvT.some(c => c.x === x && c.y === y)) { this.doMv(s, x, y); return }
			if (cl && cl.team === 'enemy' && s.team === 'ally' && !s.ha && this.atkT.some(c => c.x === x && c.y === y)) { this.doAtk(s, cl); return }
			if (cl && cl.team === 'ally' && s.role === 'healer' && !s.ha && cl.id !== s.id && this.healT.some(c => c.x === x && c.y === y)) { this.doHeal(s, cl); return }
			if (!cl && this.mvT.some(c => c.x === x && c.y === y)) { this.doMv(s, x, y); return }
			if (!cl && (this.mvT.length > 0 || this.atkT.length > 0 || this.healT.length > 0) && !this.mvT.some(c => c.x === x && c.y === y) && !this.atkT.some(c => c.x === x && c.y === y) && !this.healT.some(c => c.x === x && c.y === y)) {
				this.mvT = []; this.atkT = []; this.healT = []; this.rTer(); this.showAM(s); return;
			}
			const hasRange = this.mvT.length > 0 || this.atkT.length > 0 || this.healT.length > 0;
			if (!hasRange && !cl) { this.clrSel(); return }
			s.ha = true; s.waited = true; this.awPM = false; this.hideAM(); this.clrSel();
			if (cl && cl.team !== 'enemy') { const nu = this.uAt(x, y); if (nu) this.selU(nu) }
			this.chkAutoEnd(); return
		}
		if (!s) { if (cl && cl.team === 'ally') this.selU(cl); return }
		if (cl && cl.team === 'enemy' && s.cls === 'assassin' && s.team === 'ally' && !s.ha && this.ter[y] && this.ter[y][x] === 'forest' && this.mvT.some(c => c.x === x && c.y === y)) { this.doMv(s, x, y); return }
		if (cl && cl.team === 'enemy' && s.team === 'ally' && !s.ha && this.atkT.some(c => c.x === x && c.y === y)) { this.doAtk(s, cl); return }
		if (cl && cl.team === 'ally' && s.role === 'healer' && !s.ha && cl.id !== s.id && this.healT.some(c => c.x === x && c.y === y)) { this.doHeal(s, cl); return }
		if (!cl && this.mvT.some(c => c.x === x && c.y === y)) { this.doMv(s, x, y); return }
		if (cl && cl.team === 'ally') { this.selU(cl); return } this.clrSel()
	},
	actMove() { if (!this.sel) return; this.hideAM(); const u = this.sel; this.mvT = (u.hm || u.mo) ? [] : this.mvC(u); this.rTer(); this.floatT(u.x, u.y, t('messages.select_move_target'), 'heal') },
	actAttack() { if (!this.sel) return; this.hideAM(); const msg = this.sel.role === 'healer' ? t('messages.select_heal_target') : t('messages.select_attack_target'); this.floatT(this.sel.x, this.sel.y, msg, 'heal') },
	showSkillMenu() { if (!this.sel || !this.awPM) return; this.skillMenuOpen = true; this.showAM(this.sel) },
	hideSkillMenu() { if (!this.sel) return; this.skillMenuOpen = false; this.showAM(this.sel) },
	actItem() {
		if (!this.sel || !this.awPM) return;
		const hasPotion = this._battlePotions && this._battlePotions.length > 0;
		const hasSiege = this._siegeItems && this._siegeItems.length > 0;
		if (!hasPotion && !hasSiege) return;
		this.itemMenuOpen = true; this.showAM(this.sel);
	},
	hideItemMenu() { if (!this.sel) return; this.itemMenuOpen = false; this.showAM(this.sel) },
	actPotion(idx) {
		if (!this.sel || !this.awPM) return;
		const pot = this._battlePotions[idx]; if (!pot) return;
		const def = BATTLE_POTIONS[pot.potionId]; if (!def) return;
		this.itemMenuOpen = false; this._curPotion = { idx, def, pot };
		this.potionMode = true;
		const u = this.sel;
		const targets = [];
		const isDebuff = def.type === 'debuff';
		for (let i = 0; i < this.units.length; i++) {
			const tu = this.units[i];
			if (tu.hp <= 0) continue;
			if (mh(u.x, u.y, tu.x, tu.y) > def.range) continue;
			if (isDebuff) { if (tu.team === 'enemy') targets.push(tu) }
			else { if (tu.team === 'ally') targets.push(tu) }
		}
		if (targets.length === 0) {
			this.potionMode = false; this._curPotion = null;
			this.floatT(u.x, u.y, t('messages.potion_no_target'), 'damage');
			this.showAM(u); return;
		}
		this.potionTargets = targets;
		this.hideAM();
		this.floatT(u.x, u.y, t('messages.select_potion_target'), 'heal');
		this.rUnits();
	},
	doPotion(targetU) {
		const potion = this._curPotion; if (!potion) return;
		const def = potion.def;
		const u = this.sel;
		if (def.type === 'heal') {
			const heal = Math.round(targetU.mhp * def.value / 100);
			targetU.hp = Math.min(targetU.mhp, targetU.hp + heal);
			this.floatT(targetU.x, targetU.y, '+' + heal + ' HP', 'heal');
			this.vfxHeal(targetU); this.sfxHeal();
		} else if (def.type === 'resource') {
			const restore = def.value;
			targetU.res = Math.min(targetU.maxRes, targetU.res + restore);
			this.floatT(targetU.x, targetU.y, '+' + restore, 'heal');
			this.vfxBuff(targetU); this.sfxHeal();
		} else if (def.type === 'buff') {
			if (!targetU.buffs) targetU.buffs = [];
			targetU.buffs.push({ type: def.stat + '_up', duration: def.duration, value: def.value, source: 'potion' });
			this.floatT(targetU.x, targetU.y, t('battle_potions.' + def.id), 'heal');
			this.vfxBuff(targetU); this.sfxHeal();
		} else if (def.type === 'debuff') {
			if (!targetU.buffs) targetU.buffs = [];
			targetU.buffs.push({ type: def.stat + '_down', duration: def.duration, value: Math.abs(def.value), source: 'potion' });
			this.floatT(targetU.x, targetU.y, t('battle_potions.' + def.id), 'damage');
			this.sfxAtk(u.cls);
		}
		// 인벤토리에서 수량 차감
		if (typeof loadInventory === 'function' && typeof saveInventory === 'function') {
			const inv = loadInventory();
			const invIdx = this._battlePotionIndices[potion.idx];
			if (invIdx >= 0 && inv[invIdx]) {
				inv[invIdx].quantity = (inv[invIdx].quantity || 1) - 1;
				if (inv[invIdx].quantity <= 0) {
					inv.splice(invIdx, 1);
					this._battlePotions.splice(potion.idx, 1);
					this._battlePotionIndices.splice(potion.idx, 1);
					for (let i = 0; i < this._battlePotionIndices.length; i++) {
						if (this._battlePotionIndices[i] > invIdx) this._battlePotionIndices[i]--;
					}
				}
				saveInventory(inv);
			}
		}
		this.potionMode = false; this._curPotion = null; this.potionTargets = [];
		u.ha = true; this.awPM = false; this.hideAM();
		this.rUnits(); this.clrSel(); this.chkAutoEnd();
	},
	actSiege(idx) {
		if (!this.sel || !this.awPM) return;
		const si = this._siegeItems[idx]; if (!si) return;
		const def = SIEGE_ITEMS.find(d => d.id === si.siegeId); if (!def) return;
		this.itemMenuOpen = false; this._curSiege = { idx, def, si };
		this.siegeMode = true;
		const u = this.sel;
		const targets = [];
		for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
			if (mh(u.x, u.y, c, r) > def.range) continue;
			const tile = this.ter[r][c];
			if (def.targetType === 'wall' && (tile === 'wall' || tile === 'gate')) targets.push({ x: c, y: r });
			else if (def.targetType === 'wall_rock' && (tile === 'wall' || tile === 'gate' || tile === 'rock')) targets.push({ x: c, y: r });
			else if (def.targetType === 'water' && tile === 'water') targets.push({ x: c, y: r });
		}
		if (targets.length === 0) {
			this.siegeMode = false; this._curSiege = null;
			this.floatT(u.x, u.y, t('messages.siege_no_target'), 'damage');
			this.showAM(u); return;
		}
		this.atkT = targets; this.healT = []; this.mvT = [];
		this.hideAM(); this.rTer();
		this.floatT(u.x, u.y, t('messages.select_siege_target'), 'heal');
	},
	doSiege(u, tx, ty) {
		const siege = this._curSiege; if (!siege) return;
		const def = siege.def;
		if (def.effect === 'climb') {
			// 사다리: 벽 너머 반대편으로 이동
			const dx = tx - u.x, dy = ty - u.y;
			let landX = tx + (dx !== 0 ? dx : 0), landY = ty + (dy !== 0 ? dy : 0);
			// 범위 체크 및 빈 칸 확인, 못 찾으면 연장
			let found = false;
			for (let step = 1; step <= 3; step++) {
				const lx = tx + dx * step, ly = ty + dy * step;
				if (lx < 0 || lx >= COLS || ly < 0 || ly >= ROWS) break;
				const lt = this.ter[ly][lx];
				if (TI[lt] && TI[lt].pass && !this.uAt(lx, ly)) { landX = lx; landY = ly; found = true; break; }
			}
			if (!found) {
				this.floatT(u.x, u.y, t('messages.siege_no_target'), 'damage');
				this.siegeMode = false; this._curSiege = null;
				this.showAM(u); return;
			}
			this._mvU(u, landX, landY);
			u.hm = true; u.mo = true;
			this.floatT(landX, landY, t('messages.climbed_wall'), 'heal');
			this.vfxSiege('siege_ladder', tx, ty);
			this.sfxUIClick();
		} else if (def.effect === 'destroy') {
			// 폭탄: 벽 파괴 → 평지
			this.ter[ty][tx] = 'plain';
			const wk = tx + ',' + ty;
			if (this.wallHP[wk]) this.wallHP[wk] = 0;
			if (this.gateHP[wk]) this.gateHP[wk] = 0;
			this.floatT(tx, ty, t('messages.wall_destroyed'), 'damage');
			this.vfxSiege('siege_bomb', tx, ty);
			this.sfxAtk('warrior');
			this.screenShake();
		} else if (def.effect === 'bridge') {
			// 다리: 물 → 평지
			this.ter[ty][tx] = 'plain';
			this.floatT(tx, ty, t('messages.bridge_placed'), 'heal');
			this.vfxSiege('siege_bridge', tx, ty);
			this.sfxUIClick();
		}
		// 인벤토리에서 아이템 제거
		const invIdx = this._siegeInvIndices[siege.idx];
		if (typeof loadInventory === 'function' && typeof saveInventory === 'function') {
			const inv = loadInventory();
			if (invIdx >= 0 && invIdx < inv.length) {
				inv.splice(invIdx, 1);
				saveInventory(inv);
			}
		}
		this._siegeItems.splice(siege.idx, 1);
		this._siegeInvIndices.splice(siege.idx, 1);
		// 인덱스 재조정 (삭제된 위치 이후의 인덱스 -1)
		for (let i = 0; i < this._siegeInvIndices.length; i++) {
			if (this._siegeInvIndices[i] > invIdx) this._siegeInvIndices[i]--;
		}
		// 사다리가 아닌 경우 행동 완료
		if (def.effect !== 'climb') {
			u.ha = true;
		}
		this.siegeMode = false; this._curSiege = null; this.awPM = def.effect === 'climb';
		this.rTer(); this.rUnits();
		if (def.effect === 'climb') {
			setTimeout(() => { this.scrollToUnit(u); this.showAM(u); this.showUI(u) }, 340);
		} else {
			this.clrSel(); this.chkAutoEnd();
		}
	},

	_grantExp(u, action) { if (u.team === 'ally' && u.uid) { const e = actExp(this.cStage ? this.cStage.id : 1, action); if (e > 0) { this.battleExp[u.uid] = (this.battleExp[u.uid] || 0) + e; this.floatT(u.x, u.y, `+${e} EXP`, 'exp'); } return e } return 0 },
	skMul(u, skId) { const lv = Math.min((u.skillLv && u.skillLv[skId]) || 1, 10); return 1 + 0.1 * (lv - 1) },
	doMv(u, tx, ty) {
		const _mxp = this._grantExp(u, 'move'); this.preMv = { x: u.x, y: u.y, exp: _mxp }; this._mvU(u, tx, ty); u.hm = true; u.mo = true; this.awPM = true; this.sfxMove();
		this.chkTrap(u); chkTrapDetect(u);
		const a = this.atkC(u); if (u.role === 'healer') { this.atkT = []; this.healT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'ally' && v.hp < v.mhp && v.id !== u.id }) }
		else { this.atkT = a.filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'enemy' }); this.healT = [] }
		this.mvT = []; setTimeout(() => { this.scrollToUnit(u); this.rTer(); this.showAM(u); this.showUI(u) }, 340)
	},

	doAtk(a, tgt) {
		if(tgt._siegeEvasion>0&&Math.random()<0.3){tgt._siegeEvasion--;this.floatT(tgt.x,tgt.y,t('messages.evasion'),'heal');a.ha=true;a.hm=true;this.awPM=false;this.hideAM();this.rUnits();this.clrSel();this.chkAutoEnd();return}
		const bCounter = tgt.skillLv && tgt.skillLv['brawler_counter'] >= 1 && !(tgt.stunned > 0) && !(tgt.frozen > 0) && mh(tgt.x,tgt.y,a.x,a.y) <= tgt.range && Math.random() < 0.3;
		if (bCounter) {
			// 공격 애니메이션 후 약간의 텀 후에 반격(격투가 카운터) 시작 (약 420ms 지연)
			setTimeout(() => {
				const cdmg = Math.max(1, Math.round(tgt.atk * 0.5) - a.def); a.hp = Math.max(0, a.hp - cdmg);
				this._grantExp(tgt, 'attack'); // 반격 경험치 획득
				this.vfxAtk(tgt, a); this.sfxAtk(tgt.cls); this.shakeU(a.id); this.floatT(a.x, a.y, `-${cdmg}`, 'damage'); this.floatT(tgt.x, tgt.y, t('messages.brawler_counter'), 'heal');
			}, 420);
		} else {
			let dmg = calcDmg(a, tgt); this._grantExp(a, 'attack');
			if(tgt._siegeShield>0){dmg=Math.max(1,Math.round(dmg*0.5));this.floatT(tgt.x,tgt.y,'🛡️','heal')}
			tgt.hp = Math.max(0, tgt.hp - dmg); this.vfxAtk(a, tgt); this.sfxAtk(a.cls); this.shakeU(tgt.id);
			this.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
			if (a._lastCrit) { this.floatT(a.x, a.y, t('messages.critical_hit'), 'heal'); this.screenShake(); }
			if (a.furyBuff > 0) this.floatT(a.x, a.y, t('messages.fury_buff'), 'heal');
			procFury(a, tgt, this);
			if (tgt.hp > 0 && a.hp > 0 && mh(tgt.x, tgt.y, a.x, a.y) <= tgt.range && !(tgt.stunned > 0) && !(tgt.frozen > 0)) {
				// 공격 애니메이션 후 약간의 텀 후에 반격 시작 (약 420ms 지연)
				setTimeout(() => {
					this._grantExp(tgt, 'attack'); // 반격 경험치 획득
					const cdmg = calcDmg(tgt, a); const da = applyDmgToAlly(a, cdmg, this); this.vfxAtk(tgt, a); this.sfxAtk(tgt.cls); this.shakeU(da.id); this.floatT(da.x, da.y, `-${cdmg}`, 'damage'); procFury(tgt, a, this);
				}, 420);
			}
		}
		a.ha = true; a.hm = true; this.awPM = false; this.hideAM();
		if (tgt.hp <= 0) {
			this.screenShake(); this.sfxKill(); this.sfxDeath(); this.vfxDeath(tgt); this.deathA(tgt.id); setTimeout(() => { this._rmDead(); this.rUnits(); this.chkEnd(); this.clrSel(); this.chkAutoEnd() }, 500)
		}
		else if (a.hp <= 0) { this.screenShake(); this.sfxDeath(); this.vfxDeath(a); this.deathA(a.id); setTimeout(() => { this._rmDead(); this.rUnits(); this.chkEnd(); this.clrSel(); this.chkAutoEnd() }, 500) }
		else { this.rUnits(); this.clrSel(); this.chkAutoEnd() }
	},
	doHeal(h, tgt) {
		let amt = Math.round(h.atk * 1.5);
		if (h.skillLv && h.skillLv['priest_divinegrace'] >= 1) amt = Math.round(amt * 1.2);
		this._grantExp(h, 'heal'); tgt.hp = Math.min(tgt.mhp, tgt.hp + amt); this.vfxHeal(tgt); this.vfxBuff(tgt); this.sfxHeal(); this.floatT(tgt.x, tgt.y, `+${amt}`, 'heal');
		h.ha = true; h.hm = true; this.awPM = false; this.hideAM(); this.rUnits(); this.clrSel(); this.chkAutoEnd()
	},
	actWait() { if (!this.sel) return; this.sel.ha = true; this.sel.waited = true; if (this.sel.team === 'ally') this.allyPos[this.sel.id] = { x: this.sel.x, y: this.sel.y }; this.awPM = false; this.hideAM(); this.sfxWait(); this.rUnits(); this.clrSel(); this.chkAutoEnd() },
	actCancel() {
		if (!this.sel) return;
		if (this.skillMenuOpen) { this.hideSkillMenu(); return }
		if (this.itemMenuOpen) { this.hideItemMenu(); return }
		if (this.potionMode) { this.potionMode = false; this._curPotion = null; this.potionTargets = []; this.rUnits(); this.showAM(this.sel); return }
		if (this.siegeMode) { this.siegeMode = false; this._curSiege = null; this.atkT = []; this.rTer(); this.showAM(this.sel); return }
		if (!this.preMv) return; const u = this.sel; const _gdx = u._gdx, _gdy = u._gdy;
		if (this.preMv.exp && u.uid) { this.battleExp[u.uid] = (this.battleExp[u.uid] || 0) - this.preMv.exp }
		u.x = this.preMv.x; u.y = this.preMv.y; u.hm = false; u.mo = false;
		this.animU(u.id, u.x, u.y); u._gdx = _gdx; u._gdy = _gdy; this._applyFace(u.id);
		this.awPM = false; this.preMv = null; this.skillMode = false; this.skillMenuOpen = false; this.hideAM(); this.sfxUIClick(); setTimeout(() => { this.rTer(); this.clrSel() }, 340)
	},

	// ── 스킬 타겟팅 (디스패처) ────────────
	actSkill(idx) {
		if (!this.sel || !this.awPM) return;
		const u = this.sel;
		const skills = getUnitSkills(u);
		const sk = skills[idx || 0];
		if (!sk || u.res < sk.cost) return;
		this.skillMenuOpen = false;
		this._curSkill = sk; this.skillMode = true;

		const handler = SKILL_HANDLERS[sk.id];
		if (handler) {
			const result = handler.target(u, sk, this);
			if (result === null) {
				this.skillMode = false; this._curSkill = null;
				return;
			}
			if (result === 'instant') {
				this.skillMode = false;
				this.doSkill(u, u.x, u.y);
				return;
			}
			this.atkT = result;
			this.healT = [];
		} else {
			const dirs = [{x:0,y:-1},{x:1,y:0},{x:0,y:1},{x:-1,y:0}];
			this.atkT = dirs.map(d => ({x:u.x+d.x,y:u.y+d.y})).filter(p => p.x>=0 && p.x<COLS && p.y>=0 && p.y<ROWS);
			this.healT = [];
		}
		this.hideAM(); this.rTer();
	},

	_findAdj(x, y, u) {
		const dirs = [{x:0,y:-1},{x:1,y:0},{x:0,y:1},{x:-1,y:0}];
		const cands = [];
		for (const d of dirs) {
			const nx = x+d.x, ny = y+d.y;
			if (nx<0 || nx>=COLS || ny<0 || ny>=ROWS) continue;
			const ti = TI[this.ter[ny][nx]]; if (!ti.pass) continue;
			if (!this.uAt(nx, ny)) cands.push({x:nx, y:ny});
		}
		if (!cands.length) return null;
		if (u) { cands.sort((a,b) => mh(a.x,a.y,u.x,u.y) - mh(b.x,b.y,u.x,u.y)) }
		return cands[0];
	},

	// ── 스킬 실행 (디스패처) ──────────────
	doSkill(u, tx, ty) {
		const sk = this._curSkill || SKILLS[u.cls];
		if (!sk) return;
		const skObj = Array.isArray(sk) ? sk[0] : sk;
		if (u.res < skObj.cost) return;
		u.res -= skObj.cost;

		const handler = SKILL_HANDLERS[skObj.id];
		if (handler) {
			handler.exec(u, tx, ty, skObj, this);
			return;
		}
		// fallback: 핸들러 미등록 시 비용 환불
		u.res += skObj.cost;
	},

	cancelChannel() {
		if (!this.sel || !this.sel.channeling) return;
		const u = this.sel;
		this.floatT(u.x, u.y, t('messages.channel_cancel'), 'damage');
		u.channeling = null;
		u.ha = true; u.hm = true; this.awPM = false; this.skillMode = false; this._curSkill = null; this.hideAM();
		this.sfxUIClick(); this.rUnits(); this.clrSel(); this.chkAutoEnd()
	},

});
