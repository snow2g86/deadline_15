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
		return { hp: roll(g.hp), atk: roll(g.atk), def: roll(g.def) };
	}
	for (var i = 0; i < 5; i++) {
		var nameId;
		do { nameId = Math.floor(Math.random() * totalNames); } while (used[nameId]);
		used[nameId] = true;
		chars.push({
			uid: nextId++, cls: 'novice', nameId: nameId, lv: 1, exp: 0, dead: false,
			hp: nov.base.hp, atk: nov.base.atk, def: nov.base.def,
			move: nov.base.move, range: nov.base.range, pot: rollPot(nov.growth),
			gender: Math.random() < 0.5 ? 'm' : 'f'
		});
	}
	localStorage.setItem('game_roster', JSON.stringify({ chars: chars, nextId: nextId }));
	localStorage.setItem('game_party', JSON.stringify(chars.map(function(c) { return c.uid; })));
	localStorage.setItem('game_save', JSON.stringify({ gold: 2000 }));
}

function renderGold() {
	try {
		var d = JSON.parse(localStorage.getItem('game_save'));
		if (d) document.getElementById('lobby-gold').textContent = d.gold || 0;
	} catch(_) {}
}

var init = async function() {
	await i18nInit();
	ensureRoster();
	// Migrate: add gender to existing characters without one
	try {
		var raw = localStorage.getItem('game_roster');
		if (raw) {
			var rd = JSON.parse(raw), changed = false;
			rd.chars.forEach(function(c) {
				if (!c.gender) { c.gender = Math.random() < 0.5 ? 'm' : 'f'; changed = true; }
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

	setTimeout(function() {
		document.getElementById('splash').style.display = 'none';
	}, 1000);
};
