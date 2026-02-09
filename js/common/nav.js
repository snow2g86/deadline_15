// bottom-nav 공통 렌더링
const NAV_TABS = [
  { tab: 'stage', icon: '⚔', i18n: 'nav.stage', fallback: '스테이지', href: 'stage-select.html', pages: ['stage-select'] },
  { tab: 'party', icon: '👥', i18n: 'nav.party', fallback: '파티', href: 'party-select.html', pages: ['party-select'] },
  { tab: 'sanctuary', icon: '⛪', i18n: 'nav.sanctuary', fallback: '성소', href: 'sanctuary.html', pages: ['sanctuary'] },
  { tab: 'shop', icon: '🏪', i18n: 'nav.shop', fallback: '상점', href: 'shop.html', pages: ['shop'] }
];

function renderBottomNav() {
  var nav = document.getElementById('bottom-nav');
  if (!nav) return;
  var page = document.body.getAttribute('data-page') || '';
  var html = '';
  for (var i = 0; i < NAV_TABS.length; i++) {
    var t = NAV_TABS[i];
    var active = t.pages.indexOf(page) !== -1 ? ' active' : '';
    var label = window.t ? window.t(t.i18n) : t.fallback;
    if (label === t.i18n) label = t.fallback;
    html += '<button class="bnav-tab' + active + '" data-tab="' + t.tab + '">'
      + '<span class="bnav-icon">' + t.icon + '</span>'
      + '<span class="bnav-label">' + label + '</span>'
      + '</button>';
  }
  nav.innerHTML = html;
  nav.addEventListener('click', function(e) {
    var btn = e.target.closest('.bnav-tab');
    if (btn) {
      var tab = NAV_TABS.find(function(x) { return x.tab === btn.getAttribute('data-tab'); });
      if (tab && tab.href) location.href = tab.href;
    }
  });
}
