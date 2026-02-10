// index.js — 로비 페이지 전용 스크립트

var CLS_ICON = Object.fromEntries(
	Object.entries(JAB).map(function(e) { return [e[0], e[1].icon]; })
);

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
	// 캐릭터 결정
	var roster, party, chars = [];
	try { roster = JSON.parse(localStorage.getItem('game_roster')); } catch(_) {}
	try { party = JSON.parse(localStorage.getItem('game_party')); } catch(_) {}
	if (roster && roster.chars) {
		if (party && party.length) {
			chars = party.map(function(uid) {
				return roster.chars.find(function(c) { return c.uid === uid; });
			}).filter(function(c) { return c && !c.dead; });
		}
		if (!chars.length) {
			chars = roster.chars.filter(function(c) { return !c.dead; })
				.sort(function(a, b) { return b.lv - a.lv; }).slice(0, 10);
		}
	}
	if (!chars.length) return;
	var names = _resolve(_i18nData, 'character.names') || [];
	chars.forEach(function(ch) {
		var wrap = document.createElement('div');
		wrap.className = 'hideout-unit';
		// 4사분면 랜덤 배치 (중앙 원탁 회피)
		var cx, cy, q = Math.floor(Math.random() * 4);
		switch (q) {
			case 0: cx = 10 + Math.random() * 35; cy = 15 + Math.random() * 30; break;
			case 1: cx = 55 + Math.random() * 35; cy = 15 + Math.random() * 30; break;
			case 2: cx = 10 + Math.random() * 35; cy = 60 + Math.random() * 25; break;
			default: cx = 55 + Math.random() * 35; cy = 60 + Math.random() * 25;
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
	localStorage.setItem('game_save', JSON.stringify({ gold: 300 }));
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
	renderBottomNav();
	renderGold();
	renderHideout();

	setTimeout(function() {
		document.getElementById('splash').style.display = 'none';
	}, 1000);
};
