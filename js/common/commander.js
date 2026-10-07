// ═══════════════════════════════════════════
//  common/commander.js — 지휘관(고유 주인공) 설정 화면: 남·여 선택 + 이름
//  처음 로비에 들어오면 한 번 자동으로 열리고(ch.setup 없을 때), 로비의 "지휘관 설정" 버튼으로 다시 열 수 있다.
// ═══════════════════════════════════════════
var CommanderSetup = (function () {
  function getCmd() {
    var r = getRoster();
    return { roster: r, ch: r.chars.find(function (c) { return c && c.cls === COMMANDER_CLS; }) };
  }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }

  function open(onDone) {
    var x = getCmd(); if (!x.ch) return;
    var gender = x.ch.gender || 'm';
    var ov = document.createElement('div'); ov.className = 'cmd-setup';
    ov.innerHTML =
      '<div class="cmd-box" role="dialog" aria-modal="true">' +
        '<div class="cmd-title">' + t('commander_setup.title') + '</div>' +
        '<div class="cmd-sub">' + t('commander_setup.sub') + '</div>' +
        '<div class="cmd-pick">' +
          ['m', 'f'].map(function (g) {
            return '<button class="cmd-card' + (g === gender ? ' on' : '') + '" data-g="' + g + '">' +
              '<img src="image/character/commander_0' + (g === 'm' ? 1 : 2) + '.png" alt="">' +
              '<span>' + t('commander_setup.' + (g === 'm' ? 'male' : 'female')) + '</span></button>';
          }).join('') +
        '</div>' +
        '<label class="cmd-name"><span>' + t('commander_setup.name') + '</span>' +
          '<input maxlength="10" value="' + esc(x.ch.customName || COMMANDER_DEFAULT_NAME) + '" placeholder="' + esc(t('commander_setup.name_ph')) + '"></label>' +
        '<button class="cmd-ok">' + t('commander_setup.confirm') + '</button>' +
      '</div>';
    document.body.appendChild(ov);
    ov.querySelectorAll('.cmd-card').forEach(function (b) {
      b.onclick = function () { gender = b.dataset.g; ov.querySelectorAll('.cmd-card').forEach(function (o) { o.classList.toggle('on', o === b); }); };
    });
    var input = ov.querySelector('input');
    var done = function () {
      var name = input.value.trim().slice(0, 10) || COMMANDER_DEFAULT_NAME;
      var y = getCmd(); if (!y.ch) return;
      y.ch.gender = gender; y.ch.customName = name; y.ch.setup = true;
      saveRoster(y.roster);
      ov.remove();
      if (onDone) onDone(y.ch);
    };
    ov.querySelector('.cmd-ok').onclick = done;
    input.onkeydown = function (e) { if (e.key === 'Enter') done(); };
    setTimeout(function () { input.focus(); input.select(); }, 50);
  }

  return {
    open: open,
    // 아직 설정하지 않았으면 열기
    ensure: function (onDone) { var x = getCmd(); if (x.ch && !x.ch.setup) open(onDone); },
  };
})();
