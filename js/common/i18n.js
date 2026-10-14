// i18n 데이터 캐시
let _i18nData = null;

// dot notation 키로 중첩 객체에서 값 조회
function _resolve(obj, path) {
  return path.split('.').reduce((o, k) => o && o[k], obj);
}

// 파라미터 치환: {gold}, {count} 등
function _interpolate(str, params) {
  if (!params || typeof str !== 'string') return str;
  return str.replace(/\{(\w+)\}/g, (_, k) => params[k] !== undefined ? params[k] : `{${k}}`);
}

// 전역 번역 함수
window.t = function(key, params) {
  if (!_i18nData) return key;
  const val = _resolve(_i18nData, key);
  if (val === undefined) return key;
  return _interpolate(val, params);
};

// script 태그로 JS 파일 로드
function _loadScript(src) {
  return new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = src;
    s.onload = resolve;
    s.onerror = reject;
    document.head.appendChild(s);
  });
}

// localStorage 캐시 키
const _I18N_CACHE_KEY = 'game_i18n_cache';
const _I18N_LANG_KEY = 'game_i18n_lang';
const _I18N_VER_KEY = 'game_i18n_ver';
const _I18N_VERSION = 62; // bump when language data changes
// 지원 언어 (설정 화면 select·Godot I18n.LANGS 와 같은 순서). 새 언어는 data/language/<코드>/ 와 story.js STORY_LANGS 도 함께
const _I18N_LANGS = ['ko', 'en', 'es', 'ja', 'zh-CN', 'zh-TW'];
const _LANG_PARTS = ['common','battle','stages','classes','skills','items','ui','character','gear','codex'];

// 다중 파일 병렬 로드
async function _loadLang(lang) {
  await Promise.all(_LANG_PARTS.map(p => _loadScript(`./data/language/${lang}/${p}.js`)));
  return window['_LANG_' + lang];
}

// 브라우저 언어 → 지원 언어 (ko → ko, ja → ja, zh-TW·zh-HK·zh-MO·zh-Hant → zh-TW, 그 밖의 zh → zh-CN,
// 지원하지 않는 언어(fr·de·pt 등)나 빈 값 → en). Godot I18n.detect_lang 과 같은 규칙
const _I18N_DETECT_FALLBACK = 'en';
function _detectLang(navLang) {
  const nav = String(navLang !== undefined ? navLang : (navigator.language || '')).toLowerCase().replace(/_/g, '-');
  if (nav === 'ko' || nav.startsWith('ko-')) return 'ko';
  if (nav.startsWith('es')) return 'es';
  if (nav.startsWith('en')) return 'en';
  if (nav.startsWith('ja')) return 'ja';
  if (nav === 'zh' || nav.startsWith('zh-')) {
    const parts = nav.split('-');
    if (parts.indexOf('hans') !== -1) return 'zh-CN';
    if (parts.indexOf('hant') !== -1 || parts.indexOf('tw') !== -1 || parts.indexOf('hk') !== -1 || parts.indexOf('mo') !== -1) return 'zh-TW';
    return 'zh-CN';
  }
  return _I18N_DETECT_FALLBACK;
}

// 쓸 언어: 사용자가 설정에서 고른 언어(game_settings.language) → 없거나 모르는 값이면 브라우저 언어
function _pickLang() {
  let lang = null;
  try {
    const settings = JSON.parse(Store.get('game_settings'));
    if (settings && settings.language) lang = settings.language;
  } catch (_) {}
  if (_I18N_LANGS.indexOf(lang) === -1) lang = _detectLang();
  return lang;
}

// Google Fonts: 현재 언어에 필요한 글꼴만 받음 (KR·Cinzel 은 늘, ja → +JP, zh-CN → +SC, zh-TW → +TC).
// 받지 않은 글꼴은 --font-text 사슬에서 건너뛰므로 fallback 사슬(:lang() CSS)은 그대로 동작.
const _FONT_EXTRA = { 'ja': 'Noto+Sans+JP', 'zh-CN': 'Noto+Sans+SC', 'zh-TW': 'Noto+Sans+TC' };
function _loadFonts(lang) {
  if (document.getElementById('i18n-fonts')) return;
  const fams = ['Noto+Sans+KR:wght@400;700;900'];
  if (_FONT_EXTRA[lang]) fams.push(_FONT_EXTRA[lang] + ':wght@400;700;900');
  fams.push('Cinzel:wght@700;900');
  const head = document.head || document.getElementsByTagName('head')[0];
  [['https://fonts.googleapis.com', false], ['https://fonts.gstatic.com', true]].forEach(([href, cors]) => {
    const pc = document.createElement('link');
    pc.rel = 'preconnect'; pc.href = href;
    if (cors) pc.crossOrigin = 'anonymous';
    head.appendChild(pc);
  });
  const l = document.createElement('link');
  l.id = 'i18n-fonts';
  l.rel = 'stylesheet';
  l.href = 'https://fonts.googleapis.com/css2?' + fams.map(f => 'family=' + f).join('&') + '&display=swap';
  head.appendChild(l);
}

// 스크립트를 읽는 즉시(<head> 안) 문서 언어·글꼴을 정함 → 데이터 로드를 기다리지 않고 글꼴 요청이 일찍 나감
(function() {
  try {
    const lang = _pickLang();
    document.documentElement.lang = lang;
    _loadFonts(lang);
  } catch (_) {}
})();

// 언어 감지 및 데이터 로드
async function loadI18n() {
  // 1. 언어 감지
  const lang = _pickLang();
  // 한자 글꼴 변형(:lang() CSS)·접근성을 위해 문서 언어를 바로 맞춤 (불러오기 실패 시 아래에서 ko 로 다시 맞춤)
  document.documentElement.lang = lang;
  _loadFonts(lang);

  // 2. localStorage 캐시 확인 (버전 일치 시만)
  const cachedLang = Store.get(_I18N_LANG_KEY);
  const cachedVer = parseInt(Store.get(_I18N_VER_KEY), 10);
  if (cachedLang === lang && cachedVer === _I18N_VERSION) {
    try {
      _i18nData = JSON.parse(Store.get(_I18N_CACHE_KEY));
    } catch (_) {}
  }

  // 3. 캐시 미스 → 8개 파일 병렬 로드 후 캐싱
  if (!_i18nData) {
    try {
      _i18nData = await _loadLang(lang);
      Store.set(_I18N_CACHE_KEY, JSON.stringify(_i18nData));
      Store.set(_I18N_LANG_KEY, lang);
      Store.set(_I18N_VER_KEY, _I18N_VERSION);
    } catch (e) {
      console.warn('[i18n] load failed, fallback ko', e);
      try {
        _i18nData = await _loadLang('ko');
        Store.set(_I18N_CACHE_KEY, JSON.stringify(_i18nData));
        Store.set(_I18N_LANG_KEY, 'ko');
        Store.set(_I18N_VER_KEY, _I18N_VERSION);
        document.documentElement.lang = 'ko';
      } catch (_) {}
    }
  }

  // 4. data-i18n 속성 번역
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    const val = _resolve(_i18nData, key);
    if (val === undefined) return;
    if (el.getAttribute('data-i18n-target') === 'innerHTML') el.innerHTML = val;
    else el.textContent = val;
  });
}

// 페이지 초기 진입시 실행
const i18nInit = async () => {
  await loadI18n();
};
