// ═══════════════════════════════════════════
//  tools/battle-sim/env.js — 웹 전투 규칙을 Node vm 안에서 머리 없이(화면 없이) 돌리는 실행 환경
//
//  - battle.html 의 <script> 순서대로 웹 파일을 vm 에 적재 (화면 전용 파일도 객체 모양 때문에 적재한 뒤 함수만 빈 함수로 바꿈)
//  - 무작위: Math.random → mulberry32(seed) (호출 수를 셈). Date / performance.now → 가상 시계
//  - 시간: setTimeout 은 가상 시계 위의 대기열 (실제로 기다리지 않음). 대기열을 (시각, 등록 순서) 순으로 하나씩 꺼내 실행
//  - 저장: Store.useBackend(메모리)
//  웹 파일은 고치지 않는다. 화면 모듈 안에 섞여 있던 규칙(이동·방향·상자 열기·초기 방향)은 rules-shim 에서 똑같이 흉내
// ═══════════════════════════════════════════
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.resolve(__dirname, '..', '..', '..');   // tools/legacy-web/battle-sim/ → 저장소 맨 위

// ── mulberry32: GDScript 와 똑같이 구현할 시드 난수 (README 의 명세와 같은 코드) ──
function mulberry32(seed) {
  let a = seed >>> 0;
  return function() {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1) >>> 0;
    t = (t ^ (t + Math.imul(t ^ (t >>> 7), t | 61))) >>> 0;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// 적재하지 않는 파일: 번역(t 는 키를 그대로 돌려주는 흉내로 대체), 모달·공용 그림·이모지 아이콘(화면), 스토리 대사(연출)
const SKIP_FILES = new Set([
  'js/common/i18n.js', 'js/common/modal.js', 'js/common/render.js', 'js/common/item-icons.js',
  'js/common/emoji-icons.js', 'js/common/story.js', 'js/battle/story-battle.js',
]);
// 객체 모양(G 프록시의 이름 찾기 순서)을 위해 적재는 하지만 함수는 전부 빈 함수로 바꾸는 화면 모듈
const PRESENTATION = ['Renderer', 'VFX', 'Audio', 'Rig', 'PixelFX', 'TerrainTex', 'Props'];

function battleScripts() {
  const html = fs.readFileSync(path.join(ROOT, 'battle.html'), 'utf8');
  const list = [];
  html.replace(/<script[^>]*\ssrc="([^"]+)"/g, (_, src) => { list.push(src.replace(/^\.\//, '')); return _; });
  return list;
}

// 맨 앞 칸 const/let → var (vm 전역 객체의 속성으로 보이게 — tools/export-godot-data.js 와 같은 방식)
function hoistTopLevel(src) { return src.replace(/^(const|let)(\s)/gm, 'var$2'); }

// ── 아무 일도 하지 않는 DOM 요소 흉내 (boot.js·grid.js 의 화면 코드가 만짐) ──
function fakeEl() {
  const noop = () => {};
  const el = {
    style: { setProperty: noop }, dataset: {}, textContent: '', innerHTML: '', className: '',
    clientWidth: 800, clientHeight: 600, width: 0, height: 0,
    classList: { add: noop, remove: noop, toggle: noop, contains: () => false },
    appendChild: noop, removeChild: noop, remove: noop, setAttribute: noop, addEventListener: noop, removeEventListener: noop,
    querySelectorAll: () => [], querySelector: () => fakeEl(), getContext: () => null, closest: () => null,
    getBoundingClientRect: () => ({ left: 0, top: 0, width: 0, height: 0 }), animate: () => ({ cancel: noop }),
  };
  return el;
}

// 스택에서 웹 파일 프레임만 골라 '함수@파일:줄' 을 안쪽부터 3개 (vm filename 은 저장소 기준 경로)
function webFrames(stack) {
  const out = [];
  for (const line of String(stack).split('\n').slice(1)) {
    const m = line.match(/at (?:async )?(?:(\S+) \()?((?:js|data)\/[^:)]+):(\d+):\d+\)?/);
    if (m) { out.push((m[1] || '?') + '@' + m[2] + ':' + m[3]); if (out.length >= 3) break; }
  }
  return out.join(' < ') || '(sim)';
}

class Env {
  constructor(seed) {
    this.seed = seed >>> 0;
    this.rngCalls = 0;
    this._battleRng = mulberry32(this.seed);
    this._rng = this._battleRng;
    this.now = 0;            // 가상 시각 (ms)
    this._seq = 0;
    this._q = [];            // 대기열 [{t, id, fn, args}]
    this.errors = [];
    this.mem = new Map();    // 저장소 (Store 백엔드)
    this._makeContext();
  }

  // 준비 단계(장비 생성 등)는 다른 시드 난수를 쓰고 세지 않는다 → 전투 난수 열은 전투 시작에서 0 부터
  useSetupRng(seed) { this._rng = mulberry32(seed >>> 0); this._counting = false; }
  useBattleRng() { this._rng = this._battleRng; this._counting = true; }

  _makeContext() {
    const env = this, noop = () => {};
    const M = Object.create(null);
    for (const k of Object.getOwnPropertyNames(Math)) M[k] = Math[k];
    M.random = function() {
      if (env._counting) {
        env.rngCalls++;
        if (env.rngLog) env.rngLog.push(env.rngCalls + '\t' + webFrames(new Error().stack));   // --rng-log: 호출 위치
      }
      return env._rng();
    };

    // 가상 시계 Date (2026-10-14T00:00:00Z 고정 + 가상 경과 시간). new Date(x) 는 그대로
    const BASE = Date.UTC(2026, 9, 14, 0, 0, 0);
    const RealDate = Date;
    function FakeDate(...a) { return a.length ? new RealDate(...a) : new RealDate(BASE + env.now); }
    FakeDate.now = () => BASE + env.now;
    FakeDate.UTC = RealDate.UTC; FakeDate.parse = RealDate.parse; FakeDate.prototype = RealDate.prototype;

    const sandbox = {
      console: {
        log: noop, info: noop, debug: noop, warn: noop,
        error: (...a) => env.errors.push('console.error: ' + a.map(x => (x && x.stack) || String(x)).join(' ')),
      },
      Math: M, Date: FakeDate, JSON, Object, Array, String, Number, Boolean, RegExp, Error, TypeError, Promise, Symbol, Map, Set, WeakMap,
      Proxy, Reflect, Infinity, NaN, parseInt, parseFloat, isNaN, isFinite, encodeURIComponent, decodeURIComponent,
      setTimeout: (fn, ms, ...args) => env._add(fn, ms, args),
      clearTimeout: (id) => { env._q = env._q.filter(e => e.id !== id); },
      setInterval: () => 0, clearInterval: noop,           // 로딩 화면 전용 (부르지 않음)
      requestAnimationFrame: () => 0, cancelAnimationFrame: noop,
      performance: { now: () => env.now },
      navigator: { language: 'ko', userAgent: 'battle-sim' },
      location: { search: '', href: 'battle.html', pathname: '/battle.html' },
      MutationObserver: function() { return { observe: noop, disconnect: noop }; },
      ResizeObserver: function() { return { observe: noop, disconnect: noop }; },
      matchMedia: () => ({ matches: false, addEventListener: noop, addListener: noop }),
      Image: function() { return { addEventListener: noop }; },
      AudioContext: undefined, webkitAudioContext: undefined,
      localStorage: undefined, fetch: () => Promise.reject(new Error('no fetch in sim')),
      document: {
        readyState: 'complete', body: Object.assign(fakeEl(), { dataset: { page: 'battle' } }), head: fakeEl(), documentElement: fakeEl(),
        addEventListener: noop, removeEventListener: noop,
        getElementById: () => fakeEl(), querySelector: () => fakeEl(), querySelectorAll: () => [], createElement: () => fakeEl(),
        createElementNS: () => fakeEl(), fonts: { ready: Promise.resolve() },
      },
      // 번역: 키를 그대로 (규칙은 번역문에 의존하지 않음. 이름 등 표시값은 기록하지 않음)
      t: (k) => k,
    };
    sandbox.window = sandbox; sandbox.self = sandbox; sandbox.globalThis = sandbox;
    sandbox.addEventListener = noop; sandbox.removeEventListener = noop;
    this.sandbox = sandbox;
    this.ctx = vm.createContext(sandbox);
  }

  // setTimeout: 지연을 숫자로 바꿔 (NaN·음수·Promise → 0, 브라우저와 같음) 가상 시각에 등록
  _add(fn, ms, args) {
    let d = Number(ms);
    if (!Number.isFinite(d) || d < 0) d = 0;
    const id = ++this._seq;
    this._q.push({ t: this.now + d, id, fn, args });
    return id;
  }
  _pop() {
    if (!this._q.length) return null;
    let bi = 0;
    for (let i = 1; i < this._q.length; i++) {
      const a = this._q[i], b = this._q[bi];
      if (a.t < b.t || (a.t === b.t && a.id < b.id)) bi = i;
    }
    return this._q.splice(bi, 1)[0];
  }
  pending() { return this._q.length; }
  // 가상 시각으로 ms 기다림 (Promise) — 정책(아군 조작)이 단계 사이에 씀
  sleep(ms) { return new Promise(r => this._add(r, ms, [])); }

  // 대기열이 빌 때까지(또는 stop() 이 참일 때까지) 실행. 콜백 하나마다 마이크로태스크(await)를 다 비운다
  async run(stop, maxSteps) {
    let steps = 0;
    for (;;) {
      await new Promise(r => setImmediate(r));
      if (this.errors.length) return 'error';
      if (stop()) return 'stopped';
      const e = this._pop();
      if (!e) return 'idle';
      this.now = e.t;
      try { e.fn(...e.args); } catch (err) { this.errors.push('timer: ' + (err && err.stack || err)); return 'error'; }
      if (++steps > maxSteps) return 'max_steps';
    }
  }

  load(rel) {
    const src = fs.readFileSync(path.join(ROOT, rel), 'utf8');
    vm.runInContext(hoistTopLevel(src), this.ctx, { filename: rel });
  }
  loadBattlePage() {
    const files = battleScripts().filter(f => !SKIP_FILES.has(f));
    for (const f of files) this.load(f);
    this.loaded = files;
    return files;
  }
  get g() { return this.sandbox; }
  eval(code) { return vm.runInContext(code, this.ctx); }
}

module.exports = { Env, mulberry32, PRESENTATION, SKIP_FILES, battleScripts, ROOT };
