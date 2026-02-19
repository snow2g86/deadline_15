// index.js — 로비 페이지 전용 스크립트

function renderHideout() {
	var ct = document.getElementById('clan-hideout');
	if (!ct) return;
	ct.innerHTML = '';
	// 횃불 6개
	[
		{ cls: 'hideout-torch t-left', delay: '0s' },
		{ cls: 'hideout-torch t-right', delay: '0.7s' },
		{ cls: 'hideout-torch t-top-left', delay: '0.3s' },
		{ cls: 'hideout-torch t-top-right', delay: '0.5s' },
		{ cls: 'hideout-torch t-bottom-left', delay: '0.4s' },
		{ cls: 'hideout-torch t-bottom-right', delay: '0.6s' }
	].forEach(function(tc) {
		var torch = document.createElement('div');
		torch.className = tc.cls;
		torch.style.animationDelay = tc.delay;
		ct.appendChild(torch);
	});
	// 원탁
	var table = document.createElement('div');
	table.className = 'hideout-table';
	ct.appendChild(table);
	// 캐릭터 결정 (최대 10명, 레벨 높은 순)
	var roster, chars = [];
	try { roster = JSON.parse(localStorage.getItem('game_roster')); } catch(_) {}
	if (roster && roster.chars) {
		// 살아있는 모든 캐릭터를 레벨 높은 순으로 정렬해서 최대 10명 표시
		chars = roster.chars.filter(function(c) { return !c.dead && !c.cls.startsWith('summon_'); })
			.sort(function(a, b) { return b.lv - a.lv; })
			.slice(0, 10);
	}
	if (!chars.length) return;
	var names = _resolve(_i18nData, 'character.names') || [];
	chars.forEach(function(ch) {
		var wrap = document.createElement('div');
		wrap.className = 'hideout-unit';
		// 4사분면 랜덤 배치 (중앙 원탁 회피 - 안전 거리 확보)
		var cx, cy, q = Math.floor(Math.random() * 4);
		switch (q) {
			case 0: cx = 5 + Math.random() * 30; cy = 10 + Math.random() * 28; break;      // 좌상
			case 1: cx = 65 + Math.random() * 30; cy = 10 + Math.random() * 28; break;    // 우상
			case 2: cx = 5 + Math.random() * 30; cy = 62 + Math.random() * 28; break;     // 좌하
			default: cx = 65 + Math.random() * 30; cy = 62 + Math.random() * 28;          // 우하
		}
		wrap.style.left = cx + '%';
		wrap.style.top = cy + '%';
		wrap.style.transform = 'translate(-50%,-50%)';
		// 캐릭터 이미지
		var icon = document.createElement('div');
		var suffix = (ch.gender || 'm') === 'f' ? '02' : '01';
		icon.innerHTML = '<img src="image/character/' + ch.cls + '_' + suffix + '.png" width="40" style="image-rendering:pixelated">';
		wrap.appendChild(icon);
		// 그림자
		var sh = document.createElement('div');
		sh.className = 'hu-shadow';
		wrap.appendChild(sh);
		// 이름
		var nm = document.createElement('div');
		nm.className = 'hu-name';
		var charName = ch.customName || names[ch.nameId] || '???';
		nm.textContent = 'Lv.' + ch.lv + ' ' + charName;
		wrap.appendChild(nm);
		ct.appendChild(wrap);
	});
}

function ensureRoster() {
	var raw = localStorage.getItem('game_roster');
	if (raw) try { var d = JSON.parse(raw); if (d && d.chars && d.chars.length) return; } catch(_) {}
	// 첫 실행: 노비스 5명 생성
	var nov = JAB.novice;
	if (!nov) return;
	var names = _resolve(_i18nData, 'character.names') || [];
	var totalNames = names.length || 300;
	var used = {}, chars = [], nextId = 1;
	function rollPot(g) {
		var roll = function(mm) { return +(mm[0] + Math.random() * (mm[1] - mm[0])).toFixed(1); };
		return { hp: roll(g.hp), atk: roll(g.atk), def: roll(g.def), actionRec: rollActionRec() };
	}
	for (var i = 0; i < 5; i++) {
		var nameId;
		do { nameId = Math.floor(Math.random() * totalNames); } while (used[nameId]);
		used[nameId] = true;
		var p = rollPot(nov.growth);
		chars.push({
			uid: nextId++, cls: 'novice', nameId: nameId, lv: 1, exp: 0, dead: false,
			hp: nov.base.hp, atk: nov.base.atk, def: nov.base.def,
			move: nov.base.move, range: nov.base.range, pot: p,
			actionRec: nov.actionRec + p.actionRec,
			gender: randomGender()
		});
	}
	localStorage.setItem('game_roster', JSON.stringify({ chars: chars, nextId: nextId }));
	localStorage.setItem('game_party', JSON.stringify(chars.map(function(c) { return c.uid; })));
	var uids = chars.map(function(c) { return c.uid; });
	while (uids.length < 5) uids.push(null);
	localStorage.setItem('game_parties', JSON.stringify({
		parties: [{ id: 0, slots: uids.slice(0, 5) }],
		activePartyId: 0
	}));
	localStorage.setItem('game_save', JSON.stringify({ gold: 2000 }));
}

function renderGold() {
	try {
		var d = JSON.parse(localStorage.getItem('game_save'));
		if (d) document.getElementById('lobby-gold').textContent = d.gold || 0;
	} catch(_) {}
}

// ═══════════════════════════════════════════════════════════
// 게임 데이터 검증 및 복구 시스템
// ═══════════════════════════════════════════════════════════
function validateAndRepairGameData() {
	var repaired = false;
	var errors = [];

	// 1. ROSTER 검증
	try {
		var raw = localStorage.getItem('game_roster');
		if (!raw || raw === '{}' || raw === '[]') {
			errors.push('roster_empty');
			throw new Error('Invalid roster');
		}
		var roster = JSON.parse(raw);
		if (!roster.chars || !Array.isArray(roster.chars)) {
			errors.push('roster_structure');
			throw new Error('Invalid roster structure');
		}

		// 각 캐릭터 필드 검증 및 복구
		var usedUids = new Set();
		roster.chars = roster.chars.filter(function(c) {
			if (!c || typeof c !== 'object') return false;
			if (!c.uid || typeof c.uid !== 'number') return false;
			if (usedUids.has(c.uid)) { errors.push('duplicate_uid_' + c.uid); return false; }
			usedUids.add(c.uid);

			// 필수 필드 검증 및 기본값 설정
			if (!c.cls) c.cls = 'novice';
			if (!JAB[c.cls]) c.cls = 'novice';
			if (typeof c.lv !== 'number' || c.lv < 1) c.lv = 1;
			if (typeof c.exp !== 'number' || c.exp < 0) c.exp = 0;
			if (typeof c.hp !== 'number' || c.hp <= 0) c.hp = JAB[c.cls].base.hp || 10;
			if (typeof c.atk !== 'number' || c.atk <= 0) c.atk = JAB[c.cls].base.atk || 1;
			if (typeof c.def !== 'number' || c.def < 0) c.def = JAB[c.cls].base.def || 0;
			if (!c.pot || typeof c.pot !== 'object') c.pot = { hp: 0.5, atk: 0.5, def: 0.5 };
			if (typeof c.pot.hp !== 'number') c.pot.hp = 0.5;
			if (typeof c.pot.atk !== 'number') c.pot.atk = 0.5;
			if (typeof c.pot.def !== 'number') c.pot.def = 0.5;
			if (typeof c.move !== 'number') c.move = JAB[c.cls].base.move || 3;
			if (typeof c.range !== 'number') c.range = JAB[c.cls].base.range || 1;
			if (typeof c.dead !== 'boolean') c.dead = false;
			if (!c.gender) c.gender = 'm';
			if (c.dead && typeof c.diedAt !== 'number') delete c.diedAt;

			return true;
		});

		if (!roster.nextId || typeof roster.nextId !== 'number') {
			roster.nextId = Math.max(...roster.chars.map(c => c.uid || 0)) + 1;
			repaired = true;
		}

		if (repaired || errors.length > 0) {
			localStorage.setItem('game_roster', JSON.stringify(roster));
			if (errors.length > 0) console.warn('[GameData] Roster repaired:', errors);
		}
	} catch(e) {
		console.error('[GameData] Roster validation failed:', e.message, errors);
		ensureRoster();
		repaired = true;
	}

	// 2. PARTIES 검증
	try {
		var raw = localStorage.getItem('game_parties');
		if (!raw || raw === '{}' || raw === '[]') throw new Error('Invalid parties');
		var parties = JSON.parse(raw);
		if (!parties.parties || !Array.isArray(parties.parties)) throw new Error('Invalid parties structure');

		var roster = JSON.parse(localStorage.getItem('game_roster')) || { chars: [] };
		var validUids = new Set(roster.chars.map(c => c.uid));

		// 각 파티의 슬롯 검증 및 정규화 (5슬롯 유지)
		parties.parties.forEach(function(party, idx) {
			if (!party.slots || !Array.isArray(party.slots)) party.slots = [];

			// 1. 유효한 uid만 필터링
			party.slots = party.slots.map(function(uid) {
				if (!uid) return null;
				return validUids.has(uid) ? uid : null;
			});

			// 2. 슬롯 개수를 5개로 정규화 (부족하면 null 추가, 초과하면 제거)
			while (party.slots.length < 5) party.slots.push(null);
			party.slots = party.slots.slice(0, 5);

			// 3. 파티 ID 검증
			if (typeof party.id !== 'number') party.id = idx;
		});

		if (!parties.activePartyId || typeof parties.activePartyId !== 'number') {
			parties.activePartyId = 0;
		}

		localStorage.setItem('game_parties', JSON.stringify(parties));
		if (errors.length > 0) console.warn('[GameData] Parties repaired:', errors);
	} catch(e) {
		console.error('[GameData] Parties validation failed:', e.message);
		// 파티 초기화 (5슬롯 고정)
		var roster = JSON.parse(localStorage.getItem('game_roster')) || { chars: [] };
		var initialSlots = [
			roster.chars[0]?.uid || null,
			roster.chars[1]?.uid || null,
			roster.chars[2]?.uid || null,
			roster.chars[3]?.uid || null,
			roster.chars[4]?.uid || null
		];
		localStorage.setItem('game_parties', JSON.stringify({
			parties: [{ id: 0, slots: initialSlots }],
			activePartyId: 0
		}));
		repaired = true;
	}

	// 3. INVENTORY 검증
	try {
		var raw = localStorage.getItem('game_inventory');
		var inv = raw ? JSON.parse(raw) : [];
		if (!Array.isArray(inv)) throw new Error('Invalid inventory structure');

		inv = inv.filter(function(item) {
			return item && item.id && (item.type === 'skill' || item.type === 'equip' || item.type === 'potion');
		});

		localStorage.setItem('game_inventory', JSON.stringify(inv));
	} catch(e) {
		console.error('[GameData] Inventory validation failed:', e.message);
		localStorage.setItem('game_inventory', JSON.stringify([]));
		repaired = true;
	}

	// 4. GOLD 검증
	try {
		var raw = localStorage.getItem('game_save');
		var save = raw ? JSON.parse(raw) : {};
		if (typeof save.gold !== 'number' || save.gold < 0) save.gold = 2000;
		localStorage.setItem('game_save', JSON.stringify(save));
	} catch(e) {
		console.error('[GameData] Gold validation failed:', e.message);
		localStorage.setItem('game_save', JSON.stringify({ gold: 2000 }));
		repaired = true;
	}

	// 5. CLEARED 검증
	try {
		var raw = localStorage.getItem('game_cleared');
		var cleared = raw ? JSON.parse(raw) : [];
		if (!Array.isArray(cleared)) cleared = [];
		cleared = cleared.filter(id => typeof id === 'number' && id > 0 && id <= 100);
		localStorage.setItem('game_cleared', JSON.stringify(cleared));
	} catch(e) {
		console.error('[GameData] Cleared validation failed:', e.message);
		localStorage.setItem('game_cleared', JSON.stringify([]));
		repaired = true;
	}

	// 6. BATTLE_ITEMS 검증
	try {
		var raw = localStorage.getItem('game_battle_items');
		var items = raw ? JSON.parse(raw) : [];
		if (!Array.isArray(items)) items = [];
		items = items.filter(item => item && item.id && typeof item.count === 'number' && item.count >= 0);
		localStorage.setItem('game_battle_items', JSON.stringify(items));
	} catch(e) {
		console.error('[GameData] Battle items validation failed:', e.message);
		localStorage.setItem('game_battle_items', JSON.stringify([]));
		repaired = true;
	}

	// UI에 검증 결과 표시
	setTimeout(function() {
		var statusDiv = document.createElement('div');
		statusDiv.id = 'gamedata-status';
		statusDiv.style.cssText = 'position:fixed;top:10px;right:10px;z-index:9999;padding:12px 16px;border-radius:6px;font-size:13px;font-weight:bold;color:#fff;box-shadow:0 2px 8px rgba(0,0,0,0.3);';
		if (repaired) {
			statusDiv.style.backgroundColor = '#f97316';
			statusDiv.textContent = '⚠️ 데이터 복구됨';
		} else {
			statusDiv.style.backgroundColor = '#22c55e';
			statusDiv.textContent = '✅ 데이터 정상';
		}
		document.body.appendChild(statusDiv);
		setTimeout(function() {
			statusDiv.style.opacity = '0.5';
		}, 3000);
	}, 500);

	return !repaired;
}

var init = async function() {
	await i18nInit();
	ensureRoster();
	var dataValid = validateAndRepairGameData();

	// 파티 슬롯 검증
	try {
		var parties = JSON.parse(localStorage.getItem('game_parties'));
		var partySlots = parties?.parties?.[0]?.slots?.length || 0;
		// 슬롯 수 검증 (5개 아니면 에러)
	} catch(e) {
		console.error('[PartySlots] 파티 검증 실패:', e.message);
	}
	// Migrate: add gender to existing characters without one
	try {
		var raw = localStorage.getItem('game_roster');
		if (raw) {
			var rd = JSON.parse(raw), changed = false;
			rd.chars.forEach(function(c) {
				if (!c.gender) { c.gender = randomGender(); changed = true; }
			});
			if (changed) localStorage.setItem('game_roster', JSON.stringify(rd));
		}
	} catch(_) {}
	// Auto-revive: 생존 클랜원이 5명 미만이면 5명이 될 때까지 자동 부활
	try {
		var rr = JSON.parse(localStorage.getItem('game_roster'));
		if (rr && rr.chars) {
			var alive = rr.chars.filter(function(c) { return !c.dead && !c.cls.startsWith('summon_'); });
			if (alive.length < 5) {
				var dead = rr.chars.filter(function(c) { return c.dead && !c.cls.startsWith('summon_'); });
				if (dead.length) {
					dead.sort(function(a, b) { return (b.diedAt || 0) - (a.diedAt || 0); });
					var need = Math.min(5 - alive.length, dead.length);
					var revivedNames = [];
					var names = _resolve(_i18nData, 'character.names') || [];
					for (var ri = 0; ri < need; ri++) {
						dead[ri].dead = false;
						delete dead[ri].diedAt;
						dead[ri].hp = JAB[dead[ri].cls] ? JAB[dead[ri].cls].base.hp : 1;
						revivedNames.push(dead[ri].customName || names[dead[ri].nameId] || '???');
					}
					localStorage.setItem('game_roster', JSON.stringify(rr));
					setTimeout(function() {
						showAlert(t('messages.auto_revive', {name: revivedNames.join(', ')}));
					}, 1200);
				}
			}
		}
	} catch(_) {}
	renderBottomNav();
	renderGold();
	renderHideout();
	// 저장된 전투가 있으면 재개 버튼 표시
	try {
		var bs = localStorage.getItem('game_battle');
		if (bs) {
			var bd = JSON.parse(bs);
			if (bd && bd.stage) {
				var resumeBtn = document.createElement('button');
				resumeBtn.className = 'popup-btn resume-btn';
				resumeBtn.title = t('messages.resume_battle') || '전투 재개';
				resumeBtn.innerHTML = '<span class="popup-icon">⚔️</span><span class="popup-label">' + (t('messages.resume_battle') || '전투 재개') + '</span>';
				resumeBtn.onclick = function() {
					localStorage.setItem('game_nav', JSON.stringify({ resume: true }));
					location.href = 'battle.html';
				};
				var popups = document.querySelector('.lobby-popups');
				if (popups) popups.insertBefore(resumeBtn, popups.firstChild);
			}
		}
	} catch(_) {}

	hideSplash(1000);
};
