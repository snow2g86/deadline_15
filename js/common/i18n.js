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
const _I18N_VERSION = 9; // bump when language data changes
const _LANG_PARTS = ['common','battle','stages','classes','skills','items','ui','character'];

// 다중 파일 병렬 로드
async function _loadLang(lang) {
  await Promise.all(_LANG_PARTS.map(p => _loadScript(`./data/language/${lang}/${p}.js`)));
  return window['_LANG_' + lang];
}

// 언어 감지 및 데이터 로드
async function loadI18n() {
  // 1. 언어 감지
  let lang = null;
  try {
    const settings = JSON.parse(localStorage.getItem('game_settings'));
    if (settings && settings.language) lang = settings.language;
  } catch (_) {}
  if (!lang) {
    const nav = (navigator.language || '').toLowerCase();
    if (nav.startsWith('es')) lang = 'es';
    else if (nav.startsWith('en')) lang = 'en';
    else lang = 'ko';
  }

  // 2. localStorage 캐시 확인 (버전 일치 시만)
  const cachedLang = localStorage.getItem(_I18N_LANG_KEY);
  const cachedVer = parseInt(localStorage.getItem(_I18N_VER_KEY), 10);
  if (cachedLang === lang && cachedVer === _I18N_VERSION) {
    try {
      _i18nData = JSON.parse(localStorage.getItem(_I18N_CACHE_KEY));
    } catch (_) {}
  }

  // 3. 캐시 미스 → 8개 파일 병렬 로드 후 캐싱
  if (!_i18nData) {
    try {
      _i18nData = await _loadLang(lang);
      localStorage.setItem(_I18N_CACHE_KEY, JSON.stringify(_i18nData));
      localStorage.setItem(_I18N_LANG_KEY, lang);
      localStorage.setItem(_I18N_VER_KEY, _I18N_VERSION);
    } catch (e) {
      console.warn('[i18n] load failed, fallback ko', e);
      try {
        _i18nData = await _loadLang('ko');
        localStorage.setItem(_I18N_CACHE_KEY, JSON.stringify(_i18nData));
        localStorage.setItem(_I18N_LANG_KEY, 'ko');
        localStorage.setItem(_I18N_VER_KEY, _I18N_VERSION);
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
