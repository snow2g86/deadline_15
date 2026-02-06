// i18n.js - 다국어 번역 시스템

const I18N = {
  // 현재 언어
  currentLang: 'ko',

  // 번역 데이터 캐시
  translations: {},

  // 지원 언어 목록
  supportedLangs: ['ko', 'en', 'es'],

  // 폴백 언어
  fallbackLang: 'en',

  // 초기화 함수
  async init() {
    // 1. localStorage에서 언어 설정 로드
    const savedLang = G._sett.language;

    // 2. 저장된 언어가 없으면 navigator.language에서 감지
    if (!savedLang) {
      this.currentLang = this.detectLanguage();
      G._sett.language = this.currentLang;
      G.saveSett();
    } else {
      this.currentLang = savedLang;
    }

    // 3. 언어 파일 로드
    const loaded = await this.loadLanguage(this.currentLang);
    if (!loaded) {
      console.error('Failed to load any language file');
    }
  },

  // 브라우저 언어 자동 감지
  detectLanguage() {
    const nav = navigator.language || navigator.userLanguage;
    const langCode = nav.split('-')[0].toLowerCase();

    // ko, es만 직접 지원, 나머지는 en
    if (langCode === 'ko') return 'ko';
    if (langCode === 'es') return 'es';
    return 'en';
  },

  // 언어 파일 로드 (비동기) - fetch 대신 i18n-data.js의 데이터 사용
  async loadLanguage(lang) {
    try {
      // I18N_DATA 객체에서 언어 데이터 직접 로드
      if (I18N_DATA && I18N_DATA[lang]) {
        this.translations = I18N_DATA[lang];
        console.log(`[i18n] Language loaded: ${lang}`);
        return true;
      } else {
        throw new Error('Language data not found');
      }
    } catch (error) {
      console.error(`[i18n] Failed to load language: ${lang}`, error);
      // 폴백 언어 시도
      if (lang !== this.fallbackLang) {
        console.log(`[i18n] Falling back to: ${this.fallbackLang}`);
        return await this.loadLanguage(this.fallbackLang);
      }
      return false;
    }
  },

  // 번역 함수 (핵심 함수)
  t(key, params = {}) {
    // 키를 dot notation으로 파싱 (예: "battle.move" → translations.battle.move)
    const keys = key.split('.');
    let value = this.translations;

    for (const k of keys) {
      if (value && typeof value === 'object' && k in value) {
        value = value[k];
      } else {
        // 키를 찾지 못한 경우 키 자체를 반환 (디버깅용)
        console.warn(`[i18n] Translation key not found: ${key}`);
        return `[${key}]`;
      }
    }

    // 파라미터 치환 ({gold}, {level} 등)
    if (typeof value === 'string' && Object.keys(params).length > 0) {
      return value.replace(/\{(\w+)\}/g, (match, paramKey) => {
        return params[paramKey] !== undefined ? params[paramKey] : match;
      });
    }

    return value;
  },

  // 언어 변경
  async setLanguage(lang) {
    if (!this.supportedLangs.includes(lang)) {
      console.warn(`[i18n] Unsupported language: ${lang}`);
      return false;
    }

    this.currentLang = lang;
    G._sett.language = lang;
    G.saveSett();

    const loaded = await this.loadLanguage(lang);
    if (loaded) {
      // 페이지 새로고침으로 모든 텍스트 갱신
      location.reload();
    }
    return loaded;
  },

  // HTML 요소 자동 번역 (data-i18n)
  translatePage() {
    document.querySelectorAll('[data-i18n]').forEach(el => {
      const key = el.getAttribute('data-i18n');
      const params = {};

      // data-i18n-param-* 속성에서 파라미터 추출
      Array.from(el.attributes).forEach(attr => {
        if (attr.name.startsWith('data-i18n-param-')) {
          const paramName = attr.name.replace('data-i18n-param-', '');
          params[paramName] = attr.value;
        }
      });

      const translated = this.t(key, params);

      // data-i18n-target 속성으로 대상 지정 (기본: textContent)
      const target = el.getAttribute('data-i18n-target') || 'textContent';

      if (target === 'innerHTML') {
        el.innerHTML = translated;
      } else if (target === 'placeholder') {
        el.placeholder = translated;
      } else if (target === 'title') {
        el.title = translated;
      } else {
        el.textContent = translated;
      }
    });
  }
};

// 전역 접근용 단축 함수
window.t = (key, params) => I18N.t(key, params);
