// bottom-nav 공통 렌더링
var NAV_SVG = {
  stage: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
    + '<path d="M4 20L20 4"/><path d="M15 4h5v5"/>'
    + '<path d="M20 20L4 4"/><path d="M4 4v5h5"/>'
    + '<line x1="5" y1="15" x2="9" y2="19"/><line x1="15" y1="19" x2="19" y2="15"/></svg>',
  party: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
    + '<path d="M12 22s-8-4-8-11V5l8-3 8 3v6c0 7-8 11-8 11z"/>'
    + '<path d="M12 8v5M10 11h4"/></svg>',
  sanctuary: '<svg viewBox="0 0 24 24" fill="currentColor">'
    + '<path d="M12 1C9.5 6 7 8 7 12.5a5 5 0 0010 0C17 8 14.5 6 12 1z"/></svg>',
  academy: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
    + '<path d="M2 3h6a4 4 0 014 4v14a3 3 0 00-3-3H2z"/>'
    + '<path d="M22 3h-6a4 4 0 00-4 4v14a3 3 0 013-3h7z"/></svg>',
  equip: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
    + '<path d="M14.7 6.3a1 1 0 000 1.4l1.6 1.6a1 1 0 001.4 0l3.77-3.77a6 6 0 01-7.94 7.94l-6.91 6.91a2.12 2.12 0 01-3-3l6.91-6.91a6 6 0 017.94-7.94l-3.76 3.76z"/></svg>',
  shop: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
    + '<path d="M10 2h4v5l4 8v3H6v-3l4-8V2z"/>'
    + '<line x1="7" y1="15" x2="17" y2="15"/></svg>'
};

const NAV_TABS = [
  { tab: 'stage', i18n: 'nav.stage', fallback: '스테이지', href: 'stage-select.html', pages: ['stage-select'] },
  { tab: 'party', i18n: 'nav.party', fallback: '파티', href: 'party-select.html', pages: ['party-select'] },
  { tab: 'sanctuary', i18n: 'nav.sanctuary', fallback: '성소', href: 'sanctuary.html', pages: ['sanctuary'] },
  { tab: 'academy', i18n: 'nav.academy', fallback: '아카데미', href: 'academy.html', pages: ['academy'] },
  { tab: 'shop', i18n: 'nav.shop', fallback: '상점', href: 'shop.html', pages: ['shop'] }
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
      + '<span class="bnav-icon">' + NAV_SVG[t.tab] + '</span>'
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
