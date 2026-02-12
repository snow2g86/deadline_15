// ═══════════════════════════════════════════
//  battle/render.js — Terrain, Units, Minimap rendering
// ═══════════════════════════════════════════

Object.assign(G, {
	_activeTexts: new Map(), // 위치별 활성 메시지 추적

	rTer() {
		const w = document.getElementById('iso-world');
		const existingBgTiles = new Map(), existingHlTiles = new Map();
		w.querySelectorAll('.iso-tile-bg').forEach(el => existingBgTiles.set(el.dataset.pos, el));
		w.querySelectorAll('.iso-tile-hl').forEach(el => existingHlTiles.set(el.dataset.pos, el));
		const tilesNeeded = new Set();
		const W = TW * 2;
		const _tc = this._tColors || {};

		for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
			const tp = this.ter[r][c], ti = TI[tp], clr = _tc[tp] || ti;
			const pos = `${c},${r}`; tilesNeeded.add(pos);
			let hl = '';
			if (this.sel) {
				if (this.mvT.some(m => m.x === c && m.y === r)) hl = 'move';
				else if (this.atkT.some(a => a.x === c && a.y === r)) hl = 'attack';
				else if (this.healT.some(h => h.x === c && h.y === r)) hl = 'heal';
				if (this.sel.x === c && this.sel.y === r) hl = 'selected';
			}
			const h = ti.z * ZH, H = TH * 2 + h + 2;
			const clip = h > 0
				? `polygon(${TW}px 1px,${W-1}px ${TH}px,${W-1}px ${TH+h}px,${TW}px ${TH*2-1+h}px,1px ${TH+h}px,1px ${TH}px)`
				: `polygon(${TW}px 1px,${W-1}px ${TH}px,${TW}px ${TH*2-1}px,1px ${TH}px)`;

			let bgTile = existingBgTiles.get(pos);
			if (!bgTile) { bgTile = document.createElement('div'); bgTile.className = 'iso-tile iso-tile-bg'; bgTile.dataset.pos = pos; w.appendChild(bgTile) }
			if (bgTile.innerHTML) bgTile.innerHTML = '';
			if (h > 0) {
				const cy = ((TH * 2 - 1) / H * 100).toFixed(1);
				const ang = Math.round(Math.atan2(TW - 1, TH - 1) * 180 / Math.PI);
				bgTile.style.background = `conic-gradient(from 0deg at 50% ${cy}%,${clr.tc} 0deg ${ang}deg,${clr.rc} ${ang}deg 180deg,${clr.lc} 180deg ${360-ang}deg,${clr.tc} ${360-ang}deg 360deg)`;
			} else if (tp === 'forest') {
				const fb = clr.tc, fl = clr.lc, fd = clr.rc;
				bgTile.style.background = [
					// 잎사귀 디테일 (작은 점 텍스처)
					`radial-gradient(circle 2px at 18% 18%,rgba(255,255,255,.10),transparent)`,
					`radial-gradient(circle 1.5px at 32% 14%,rgba(255,255,255,.08),transparent)`,
					`radial-gradient(circle 2px at 58% 12%,rgba(255,255,255,.09),transparent)`,
					`radial-gradient(circle 1.5px at 74% 22%,rgba(255,255,255,.07),transparent)`,
					`radial-gradient(circle 2px at 40% 36%,rgba(255,255,255,.08),transparent)`,
					`radial-gradient(circle 1.5px at 56% 30%,rgba(255,255,255,.07),transparent)`,
					// 수관 상단 햇빛 (따뜻한 톤)
					`radial-gradient(circle 8px at 28% 20%,rgba(160,210,80,.10),transparent)`,
					`radial-gradient(circle 7px at 66% 16%,rgba(160,210,80,.08),transparent)`,
					`radial-gradient(circle 6px at 48% 40%,rgba(160,210,80,.07),transparent)`,
					// 메인 수관 3그루 (크고 뚜렷한 원형)
					`radial-gradient(circle 18px at 26% 24%,${fb},${fl} 42%,transparent 72%)`,
					`radial-gradient(circle 20px at 68% 20%,${fb},${fl} 42%,transparent 72%)`,
					`radial-gradient(circle 22px at 48% 46%,${fb},${fl} 42%,transparent 72%)`,
					// 후방 수관 (작고 어두운)
					`radial-gradient(circle 14px at 12% 64%,${fl},${fd} 45%,transparent 75%)`,
					`radial-gradient(circle 13px at 82% 58%,${fl},${fd} 45%,transparent 75%)`,
					`radial-gradient(circle 10px at 38% 70%,${fl},${fd} 45%,transparent 75%)`,
					// 줄기 (가는 수직 그림자)
					`radial-gradient(ellipse 2.5px 11px at 26% 54%,${fd},transparent 90%)`,
					`radial-gradient(ellipse 2.5px 11px at 68% 48%,${fd},transparent 90%)`,
					`radial-gradient(ellipse 2.5px 13px at 48% 70%,${fd},transparent 90%)`,
					// 지면 그림자 (수관 아래 어둡게)
					`radial-gradient(ellipse 30px 6px at 38% 90%,rgba(0,0,0,.12),transparent)`,
					`radial-gradient(ellipse 26px 5px at 68% 86%,rgba(0,0,0,.10),transparent)`,
					// 지면 이끼 텍스처
					`radial-gradient(circle 3px at 22% 92%,${fl},transparent)`,
					`radial-gradient(circle 2.5px at 52% 94%,${fl},transparent)`,
					`radial-gradient(circle 3px at 78% 90%,${fl},transparent)`,
					// 바닥
					fd
				].join(',');
			} else if (tp === 'rock') {
				bgTile.style.background = `linear-gradient(135deg,${clr.tc} 25%,${clr.rc} 45%,${clr.tc} 55%,${clr.rc} 75%,${clr.tc})`;
			} else if (tp === 'water') {
				const wA = (this.cStage && this.cStage.mapType === 'volcano') ? 'rgba(140,40,20,.12)' : 'rgba(40,90,140,.12)';
				bgTile.style.background = `repeating-linear-gradient(0deg,transparent,transparent 5px,${wA} 5px,${wA} 6px),${clr.tc}`;
			} else { bgTile.style.background = clr.tc; }
			bgTile.style.clipPath = clip;

			let hlTile = existingHlTiles.get(pos);
			if (!hlTile) {
				hlTile = document.createElement('div'); hlTile.className = 'iso-tile iso-tile-hl'; hlTile.dataset.pos = pos; hlTile.style.cursor = 'pointer';
				hlTile.addEventListener('click', e => { e.stopPropagation(); const rect = w.getBoundingClientRect(); const px = e.clientX - rect.left, py = e.clientY - rect.top; const hit = G.isoHit(px, py); if (!hit) return; const { c, r } = hit; if (c < 0 || c >= COLS || r < 0 || r >= ROWS) return; if (G.awPM) { G.cellCk(c, r); return } const u = G.uAt(c, r); if (u && u.team === 'ally' && !G.sel) { G.selU(u); return } if (u && u.team === 'ally' && G.sel && u.id === G.sel.id) { G.clrSel(); return } G.cellCk(c, r) });
				w.appendChild(hlTile);
			}
			if (hlTile.innerHTML) hlTile.innerHTML = '';
			hlTile.style.clipPath = clip;

			const sx = this.tSX(c, r), sy = this.tSY(c, r, ti.z), zix = this.g2v(c, r);
			bgTile.style.left = sx + 'px'; bgTile.style.top = sy + 'px'; bgTile.style.width = W + 'px'; bgTile.style.height = H + 'px'; bgTile.style.zIndex = zix.vc + zix.vr;
			hlTile.style.left = sx + 'px'; hlTile.style.top = sy + 'px'; hlTile.style.width = W + 'px'; hlTile.style.height = H + 'px'; hlTile.style.zIndex = zix.vc + zix.vr + 1;

			hlTile.classList.remove('hl-move', 'hl-attack', 'hl-heal', 'hl-selected');
			if (hl === 'move') hlTile.classList.add('hl-move');
			else if (hl === 'attack') hlTile.classList.add('hl-attack');
			else if (hl === 'heal') hlTile.classList.add('hl-heal');
			else if (hl === 'selected') hlTile.classList.add('hl-selected');
		}

		existingBgTiles.forEach((el, pos) => { if (!tilesNeeded.has(pos)) el.remove() });
		existingHlTiles.forEach((el, pos) => { if (!tilesNeeded.has(pos)) el.remove() });
	},

	rUnits() {
		const w = document.getElementById('iso-world'), al = this.units.filter(u => u.hp > 0), ids = new Set();
		const resClr = u => u.resType === 'mana' ? '#4488ff' : u.resType === 'energy' ? '#f0c040' : '#ff6644';
		al.forEach(u => {
			ids.add('u-' + u.id); let el = document.getElementById('u-' + u.id);
			if (!el) {
				el = document.createElement('div'); el.id = 'u-' + u.id; el.className = `unit-sprite ${u.team} spawning`;
				if (u.team === 'ally') this.allyPos[u.id] = {x: u.x, y: u.y};
				setTimeout(() => el.classList.remove('spawning'), 450);
				el.innerHTML = `<div class="u-icon">${charSprite(u.cls, 36, u.gender)}</div><div class="u-shadow"></div><div class="hp-bg"><div class="hp-fill"></div></div><div class="mp-bg"><div class="mp-fill"></div></div>`;
				w.appendChild(el);
				if (u.team === 'enemy') { u._gdx = 0; u._gdy = 1; this._applyFace(u.id) }
			}
			el.style.width = UW + 'px'; el.style.height = UH + 'px'; el.style.left = this.uSX(u.x, u.y) + 'px'; el.style.top = this.uSY(u.x, u.y) + 'px';
			const v = this.g2v(u.x, u.y); el.style.zIndex = 100 + v.vc + v.vr;
			const hpFill = el.querySelector('.hp-fill');
			if (hpFill) hpFill.style.width = `${(u.hp / u.mhp) * 100}%`;
			const mpFill = el.querySelector('.mp-fill');
			if (mpFill) {
				mpFill.style.width = `${u.maxRes ? (u.res / u.maxRes) * 100 : 0}%`;
				mpFill.style.background = resClr(u);
			}
			const isSel = this.sel && this.sel.id === u.id;
			el.classList.toggle('acted', u.team === 'ally' && u.ha && !isSel); el.classList.remove('ally', 'enemy'); el.classList.add(u.team);
			el.classList.toggle('stealthed', isStealthed(u)); el.classList.toggle('stunned', u.stunned > 0 || u.frozen > 0);
			el.classList.toggle('potion-target', this.potionMode && this.potionTargets && this.potionTargets.some(pt => pt.id === u.id));
			let stunLabel = el.querySelector('.stun-label'); if (u.stunned > 0 || u.frozen > 0) { if (!stunLabel) { stunLabel = document.createElement('div'); stunLabel.className = 'stun-label'; el.appendChild(stunLabel) } stunLabel.textContent = u.frozen > 0 ? '❄️' + u.frozen : u.stunned } else if (stunLabel) stunLabel.remove();
			const fx = [];
			const tile = this.ter[u.y] ? this.ter[u.y][u.x] : null;
			if (tile && TI[tile] && TI[tile].buff) fx.push({ icon: TI[tile].buff.icon, cls: TI[tile].buff.type });
			if (u.furyBuff > 0) fx.push({ icon: '💢', cls: 'buff' });
			if (u.defBuff > 0) fx.push({ icon: '🛡️', cls: 'buff' });
			if (u.disarmed > 0) fx.push({ icon: '🤛', cls: 'debuff' });
			if (u.channeling) fx.push({ icon: u.channeling === 'shaman_curse' ? '☠️' : '🔺', cls: u.channeling === 'shaman_curse' ? 'debuff' : 'buff' });
			let badges = el.querySelector('.u-badges');
			if (fx.length) {
				if (!badges) { badges = document.createElement('div'); badges.className = 'u-badges'; el.appendChild(badges) }
				badges.innerHTML = fx.map(e => `<span class="u-badge ${e.cls}">${e.icon}</span>`).join('');
			} else if (badges) badges.remove();
			if (u.isSummon && u.summonTurns !== undefined) {
				let turnLabel = el.querySelector('.summon-turns');
				if (!turnLabel) {
					turnLabel = document.createElement('div');
					turnLabel.className = 'summon-turns';
					turnLabel.style.cssText = 'position:absolute;top:-8px;right:-8px;background:#8b5cf6;color:#fff;border-radius:50%;width:20px;height:20px;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:bold;border:2px solid #fff;z-index:10;';
					el.appendChild(turnLabel)
				}
				turnLabel.textContent = u.summonTurns
			} else {
				const turnLabel = el.querySelector('.summon-turns');
				if (turnLabel) turnLabel.remove()
			}
		});
		[...w.querySelectorAll('.unit-sprite')].forEach(el => { if (!ids.has(el.id)) el.remove() });
		this.units.filter(u => u.team === 'ally' && u.hp <= 0).forEach(u => {
			this.allyPos[u.id] = {x: 99, y: 99};
		});
		this.rMM(); this.rNav()
	},

	floatT(x, y, t, tp) {
		const w = document.getElementById('iso-world'), el = document.createElement('div');
		const posKey = `${x},${y}`;
		const count = (this._activeTexts.get(posKey) || 0) + 1;
		this._activeTexts.set(posKey, count);

		const yOffset = -8 - (count - 1) * 18; // 각 메시지마다 18px 위 오프셋
		el.className = `float-text ${tp}`;
		el.textContent = t;
		el.style.left = (this.uSX(x, y) + UCX / 2) + 'px';
		el.style.top = (this.uSY(x, y) + yOffset) + 'px';
		el.style.zIndex = 500;
		w.appendChild(el);
		setTimeout(() => {
			el.remove();
			const newCount = (this._activeTexts.get(posKey) || 1) - 1;
			if (newCount <= 0) this._activeTexts.delete(posKey);
			else this._activeTexts.set(posKey, newCount);
		}, 950)
	},
	showAM(u) {
		const m = document.getElementById('action-menu');
		m.style.left = (this.uSX(u.x, u.y) + UW + 2) + 'px';
		m.style.top = this.uSY(u.x, u.y) + 'px'; m.style.zIndex = 600;
		if (u.channeling) {
			this.hideAllMenuButtons();
			document.getElementById('btn-cancel').style.display = 'none';
			const btn = document.createElement('button'); btn.className = 'am-skill';
			btn.textContent = t('messages.unlock');
			btn.onclick = () => G.cancelChannel();
			const btnDash = document.getElementById('btn-dash');
			m.insertBefore(btn, btnDash);
			btnDash.style.display = 'none';
			m.classList.add('show'); return
		}
		if (this.skillMenuOpen) { this.showSkillSubMenu(u); return }
		if (this.itemMenuOpen) { this.showItemSubMenu(u); return }
		this.showMainMenu(u)
	},
	showMainMenu(u) {
		const m = document.getElementById('action-menu');
		m.querySelectorAll('.am-skill, .am-item').forEach(e => e.remove());
		document.getElementById('btn-move').style.display = (!u.hm && !u.mo) ? '' : 'none';
		const btnAttack = document.getElementById('btn-attack');
		if (u.role === 'healer') {
			btnAttack.textContent = t('battle.heal');
			btnAttack.style.display = (!u.ha && this.healT.length > 0) ? '' : 'none'
		}
		else {
			btnAttack.textContent = t('battle.attack');
			btnAttack.style.display = (!u.ha && this.atkT.length > 0) ? '' : 'none'
		}
		const skills = getUnitSkills(u);
		const hasUsableSkill = !u.ha && skills.some(sk => this.canUseSkill(u, sk));
		document.getElementById('btn-skill').style.display = hasUsableSkill ? '' : 'none';
		const hasPotion = this._battlePotions && this._battlePotions.length > 0;
		const hasSiege = this._siegeItems && this._siegeItems.length > 0;
		document.getElementById('btn-item').style.display = (!u.ha && (hasPotion || hasSiege)) ? '' : 'none';
		const btnDash = document.getElementById('btn-dash');
		btnDash.textContent = t('battle.wait');
		btnDash.style.display = '';
		const btnCancel = document.getElementById('btn-cancel');
		btnCancel.textContent = t('battle.cancel');
		btnCancel.style.display = this.preMv ? '' : 'none';
		btnCancel.onclick = () => G.actCancel();
		m.classList.add('show')
	},
	showSkillSubMenu(u) {
		const m = document.getElementById('action-menu');
		this.hideAllMenuButtons();
		m.querySelectorAll('.am-skill').forEach(e => e.remove());
		const skills = getUnitSkills(u);
		const btnDash = document.getElementById('btn-dash');
		skills.forEach((sk, idx) => {
			if (sk.passive) return;
			const btn = document.createElement('button'); btn.className = 'am-skill';
			btn.innerHTML = skillIcon(sk.id, 18) + ' ' + t('skills.' + sk.id);
			let enabled = this.canUseSkill(u, sk);
			btn.disabled = !enabled;
			btn.onclick = () => G.actSkill(idx);
			m.insertBefore(btn, btnDash)
		});
		btnDash.style.display = 'none';
		const btnCancel = document.getElementById('btn-cancel');
		btnCancel.textContent = '↩ ' + t('battle.cancel');
		btnCancel.style.display = '';
		btnCancel.onclick = () => G.hideSkillMenu();
		m.classList.add('show')
	},
	showItemSubMenu(u) {
		const m = document.getElementById('action-menu');
		this.hideAllMenuButtons();
		m.querySelectorAll('.am-skill,.am-item').forEach(e => e.remove());
		const btnDash = document.getElementById('btn-dash');
		// 포션 버튼
		const potionSeen = {};
		if (this._battlePotions) {
			this._battlePotions.forEach((pot, idx) => {
				const def = BATTLE_POTIONS[pot.potionId];
				if (!def) return;
				const key = pot.potionId;
				if (!potionSeen[key]) potionSeen[key] = { def, count: 0, firstIdx: idx };
				potionSeen[key].count += pot.quantity || 1;
			});
			Object.keys(potionSeen).forEach(key => {
				const { def, count, firstIdx } = potionSeen[key];
				const btn = document.createElement('button'); btn.className = 'am-item';
				btn.textContent = def.icon + ' ' + t('battle_potions.' + def.id) + ' x' + count;
				btn.onclick = () => G.actPotion(firstIdx);
				m.insertBefore(btn, btnDash);
			});
		}
		// 공성 아이템 버튼
		const siegeSeen = {};
		if (this._siegeItems) {
			this._siegeItems.forEach((si, idx) => {
				const def = SIEGE_ITEMS.find(d => d.id === si.siegeId);
				if (!def) return;
				const key = si.siegeId;
				if (!siegeSeen[key]) siegeSeen[key] = { def, count: 0, firstIdx: idx };
				siegeSeen[key].count += si.quantity || 1;
			});
			Object.keys(siegeSeen).forEach(key => {
				const { def, count, firstIdx } = siegeSeen[key];
				const btn = document.createElement('button'); btn.className = 'am-item';
				btn.textContent = def.icon + ' ' + t('shop.' + def.id) + (count > 1 ? ' x' + count : '');
				btn.onclick = () => G.actSiege(firstIdx);
				m.insertBefore(btn, btnDash);
			});
		}
		btnDash.style.display = 'none';
		const btnCancel = document.getElementById('btn-cancel');
		btnCancel.textContent = '\u21a9 ' + t('battle.cancel');
		btnCancel.style.display = '';
		btnCancel.onclick = () => G.hideItemMenu();
		m.classList.add('show');
	},
	hideAllMenuButtons() {
		['btn-move', 'btn-attack', 'btn-skill', 'btn-item', 'btn-dash', 'btn-cancel'].forEach(id => {
			document.getElementById(id).style.display = 'none'
		})
	},
	canUseSkill(u, sk) {
		if (sk.passive) return false;
		let enabled = u.res >= sk.cost && !u.ha;
		if (sk.id === 'assassin_assassinate') {
			const overlapping = isStealthed(u) && this.units.some(v =>
				v.x === u.x && v.y === u.y && v.team === 'enemy' && v.hp > 0);
			enabled = enabled && overlapping
		}
		if (sk.id === 'assassin_ambush') {
			if (!isStealthed(u)) enabled = false;
		}
		if (sk.id.startsWith('summoner_summon_')) {
			const maxSummons = 1;
			const currentSummons = this.units.filter(s => s.isSummon && s.summonerId === u.id);
			if (currentSummons.length >= maxSummons) { enabled = false }
		}
		if (sk.id === 'archer_snipe') {
			const sMin = sk.snipeMin || 5, sMax = sk.snipeMax || 10;
			const hasTarget = this.units.some(v => v.team === 'enemy' && v.hp > 0 && mh(u.x, u.y, v.x, v.y) >= sMin && mh(u.x, u.y, v.x, v.y) <= sMax);
			if (!hasTarget) enabled = false;
		}
		if (sk.id === 'sapper_excavate') {
			const er = sk.excavateRange || 1;
			const hasRock = G.ter.some((row, y) => row.some((tile, x) => tile === 'rock' && mh(u.x, u.y, x, y) <= er && mh(u.x, u.y, x, y) > 0));
			if (!hasRock) enabled = false;
		}
		return enabled
	},
	hideAM() { document.getElementById('action-menu').classList.remove('show') },
});
