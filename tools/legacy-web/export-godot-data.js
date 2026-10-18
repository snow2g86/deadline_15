#!/usr/bin/env node
// ═══════════════════════════════════════════
//  tools/export-godot-data.js — 웹 data/*.js → Godot 용 JSON 변환기
//
//  웹 게임의 data/*.js (와 바로 뒤에 불러오는 js/logic/*.js 의 적재 시 가공)가 수치·대본·번역의 원본이다.
//  이 도구는 그 파일들을 페이지와 같은 순서로 Node vm 안에서 실행한 뒤, 최종(가공 후) 전역 값을
//  godot/data/*.json 으로 내보낸다. Godot 은 이 JSON 만 읽는다 (웹 파일은 손대지 않음).
//
//  사용: node tools/legacy-web/export-godot-data.js          (npm 의존성 없음)
//        node tools/legacy-web/export-godot-data.js --check  (쓰지 않고 점검만: 바뀔 파일이 있으면 목록 출력 후 종료 코드 1 — 커밋 전 점검용)
//  결과: godot/data/<모듈>.json, godot/data/lang/<언어>.json, godot/data/story/{<언어>,sample}.json  (언어 = js/common/i18n.js _I18N_LANGS),
//        godot/data/manifest.json (전역별 개수·경고·특수값 위치 — Godot DataDB 가 검증에 사용)
//
//  규칙
//   - 같은 원본이면 같은 결과 (시각·난수 없음, 키 순서는 원본 선언 순서 그대로). 내용이 같으면 파일을 다시 쓰지 않는다.
//   - 데이터 안의 함수는 JSON 으로 옮길 수 없어 빼되, 반드시 manifest.warnings 에 경로를 남긴다.
//   - 함수만 모인 계산용 객체(Gear, Hazard, Synergy 등)는 데이터가 아니므로 manifest.skipped_logic 에 이름만 기록.
//   - Infinity / -Infinity / NaN 은 JSON 에 없으므로 문자열 "Infinity" 등으로 쓰고 manifest.special_values 에 경로를 남긴다
//     (Godot DataDB 가 읽을 때 INF / -INF / NAN 으로 되돌림).
// ═══════════════════════════════════════════
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');
const crypto = require('crypto');

const ROOT = path.resolve(__dirname, '..', '..');   // tools/legacy-web/ → 저장소 맨 위
// (2026-10-18 보관) 데이터 원본은 이제 godot/data — 이 변환기는 godot/data 를 덮어쓰지 않고 tools/_work/legacy-web/data/ 에만 씀
//  (모양은 예전 JSON.stringify(…, null, 1) 그대로라 godot/data 와 바이트로는 다름. 값 비교가 필요하면 JSON.parse 해서 비교)
const OUT = path.join(ROOT, 'tools', '_work', 'legacy-web', 'data');
// 언어 목록은 웹 js/common/i18n.js 의 _I18N_LANGS (설정 화면 순서) — 한 곳에서만 관리
const LANGS = (() => {
  const m = fs.readFileSync(path.join(ROOT, 'js/common/i18n.js'), 'utf8').match(/_I18N_LANGS\s*=\s*\[([^\]]*)\]/);
  if (!m) throw new Error('js/common/i18n.js 에서 _I18N_LANGS 를 찾지 못함');
  return m[1].split(',').map(s => s.trim().replace(/^['"]|['"]$/g, '')).filter(Boolean);
})();
const CHECK = process.argv.includes('--check');

// ── 데이터 모듈: 출력 파일 이름 → 원본 파일 (battle.html 의 <script> 순서대로 실행됨) ──
//  battle.html 에 없는 data 파일은 없음 (전 페이지 <script> 목록 확인: battle.html 이 모든 data/*.js 를 포함).
//  js/common/constants.js · js/common/daily.js · js/skills.js · js/skills/_common.js · js/battle/constants.js 는
//  js 폴더에 있지만 순수 수치 표(ECON, SOUL, DAILY, SKILLS, AI_PROFILES, TACTIC …)를 담고 있어 함께 내보낸다.
const MODULES = [
  { name: 'jab',              files: ['data/jab.js'] },
  { name: 'constants',        files: ['js/common/constants.js'] },
  { name: 'daily',            files: ['js/common/daily.js'] },
  { name: 'stages',           files: ['data/stages.js', 'js/logic/stages.js'] },
  { name: 'synergy',          files: ['data/synergy.js', 'js/logic/synergy.js'] },
  { name: 'hazards',          files: ['data/hazards.js', 'js/logic/hazards.js'] },
  { name: 'tiles',            files: ['data/tiles.js', 'js/logic/tiles.js'] },
  { name: 'props',            files: ['data/props.js'] },
  { name: 'equip',            files: ['data/equip.js', 'js/logic/equip.js'] },
  { name: 'gear',             files: ['data/gear.js', 'js/logic/gear.js'] },
  { name: 'skills',           files: ['js/skills.js', 'js/skills/_common.js'] },
  { name: 'battle_constants', files: ['js/battle/constants.js'] },
  { name: 'soul',             files: ['js/common/soul.js'], pick: ['SOUL_KEY'] },
  // 화면 쪽 표 (아이콘 시트 좌표·이모지→아이콘·캐릭터 그림·리그·공격 모션·하단 탭)
  { name: 'icons',            files: ['js/common/item-icons.js', 'js/common/emoji-icons.js'] },
  // 로직이 섞인 파일은 pick 으로 표 이름만 골라 꺼낸다 (나머지 전역은 notes 에 기록)
  { name: 'sprites',          files: ['js/sprites.js', 'js/battle/rig.js', 'js/battle/motion.js'],
    pick: ['CHAR_SPRITES', 'CUTOUT_RIGS', 'CHAR_FIG', 'FIG_H', 'FIG_FOOT', 'SPRITE_SHEETS', 'ATK_MOTIONS'],
    // motion.js 가 적재 때 Object.assign(VFX, {...}) 를 해서, vfx.js(화면 전용) 대신 빈 객체로 흉내
    stub: ['VFX'] },
  { name: 'ui',               files: ['js/common/nav.js'], pick: ['NAV_TABS'] },
];
// 실행에는 필요하지만 내보내지 않는 파일 (저장 창구 — 적재 중 다른 파일이 Store 를 참조할 수 있음)
const CONTEXT_ONLY = ['js/common/store.js'];

// 페이지들의 실제 <script> 순서를 읽어, 위 파일들을 그 순서로 정렬한다 (페이지 순서가 바뀌어도 따라감)
//  기준은 battle.html. battle.html 에 없는 파일(js/common/nav.js 등)은 다른 페이지에서 바로 앞에 오는 파일 뒤에 끼워 넣는다.
const PAGES = ['battle.html', 'index.html', 'stage-select.html', 'party-select.html', 'shop.html', 'sanctuary.html', 'academy.html',
  'guide.html', 'compendium.html', 'settings.html', 'credits.html', 'licenses.html', 'class-balance-report.html'];
function scriptsOf(page) {
  const html = fs.readFileSync(path.join(ROOT, page), 'utf8');
  const list = [];
  html.replace(/<script[^>]*\ssrc="([^"]+)"/g, (_, src) => { list.push(src.replace(/^\.\//, '')); return _; });
  return list;
}
function pageOrder() {
  const order = [];
  for (const page of PAGES) {
    if (!fs.existsSync(path.join(ROOT, page))) continue;
    const list = scriptsOf(page);
    list.forEach((f, i) => {
      if (order.indexOf(f) !== -1) return;
      let at = order.length, j = i - 1;
      while (j >= 0 && order.indexOf(list[j]) === -1) j--;
      if (j >= 0) at = order.indexOf(list[j]) + 1;
      order.splice(at, 0, f);
    });
  }
  return order;
}

const warnings = [];
const specialValues = [];
const skippedLogic = [];
const notes = [];

function read(rel) { return fs.readFileSync(path.join(ROOT, rel), 'utf8'); }
function sha1(s) { return crypto.createHash('sha1').update(s).digest('hex'); }

// 맨 앞 칸(들여쓰기 없음)의 const/let 은 스크립트 최상위 선언 → var 로 바꿔 실행해야 vm 전역 객체의 속성으로 보인다.
// (값·순서는 그대로, 재대입만 허용될 뿐이라 결과에 영향 없음)
function hoistTopLevel(src) { return src.replace(/^(const|let)(\s)/gm, 'var$2'); }

// ── vm 실행 환경: 브라우저 전역 중 적재 단계에 필요한 것만 흉내 ──
function makeContext(label) {
  const noop = () => {};
  const tCalls = [];
  const sandbox = {
    console: { log: noop, info: noop, debug: noop, warn: (...a) => notes.push(`[${label}] console.warn: ${a.join(' ')}`), error: (...a) => warnings.push(`[${label}] console.error: ${a.join(' ')}`) },
    Math, JSON, Date, Object, Array, String, Number, Boolean, RegExp, Error, Promise, Symbol, Map, Set, parseInt, parseFloat, isNaN, isFinite,
    setTimeout: noop, clearTimeout: noop, setInterval: noop, clearInterval: noop, requestAnimationFrame: noop,
    navigator: { language: 'ko' },
    location: { search: '', href: '', pathname: '' },
    // 화면 코드가 적재 때 만지는 브라우저 기능은 빈 흉내 (emoji-icons.js 의 MutationObserver 등)
    MutationObserver: function() { return { observe: noop, disconnect: noop }; },
    ResizeObserver: function() { return { observe: noop, disconnect: noop }; },
    matchMedia: () => ({ matches: false, addEventListener: noop, addListener: noop }),
    Image: function() { return {}; },
    localStorage: undefined,
    document: {
      readyState: 'loading',
      addEventListener: noop, removeEventListener: noop,
      querySelector: () => null, querySelectorAll: () => [], getElementById: () => null,
      createElement: () => ({ style: {}, setAttribute: noop, appendChild: noop }),
      head: { appendChild: noop }, body: { appendChild: noop },
    },
    // 적재 중 번역 함수가 불리면(데이터에 번역문이 박히면) 결과가 언어마다 달라지므로 경고로 남긴다
    t: (k) => { tCalls.push(k); return k; },
  };
  sandbox.window = sandbox;
  sandbox.self = sandbox;
  sandbox.globalThis = sandbox;
  sandbox.addEventListener = noop;
  sandbox.removeEventListener = noop;
  const ctx = vm.createContext(sandbox);
  return { ctx, sandbox, tCalls };
}

function runFile(env, rel) {
  const before = new Set(Object.keys(env.sandbox));
  try {
    vm.runInContext(hoistTopLevel(read(rel)), env.ctx, { filename: rel });
  } catch (e) {
    throw new Error(`${rel} 실행 실패: ${e && e.stack || e}`);
  }
  return Object.keys(env.sandbox).filter(k => !before.has(k));
}

// ── JS 값 → JSON 값 (경로 추적, 함수·특수값 보고) ──
function toJSONValue(v, where, pathArr, seen) {
  const p = () => pathArr.map(x => typeof x === 'number' ? `[${x}]` : `.${x}`).join('').replace(/^\./, '');
  if (v === null) return null;
  const tp = typeof v;
  if (tp === 'string' || tp === 'boolean') return v;
  if (tp === 'number') {
    if (Number.isFinite(v)) return v;
    const s = Number.isNaN(v) ? 'NaN' : (v > 0 ? 'Infinity' : '-Infinity');
    specialValues.push({ module: where, path: pathArr.slice(), value: s });
    return s;
  }
  if (tp === 'function') {
    warnings.push(`${where}: ${p()} 는 함수라 JSON 에서 뺐음 (GDScript 로 다시 구현 필요)`);
    return undefined;
  }
  if (tp === 'undefined') {
    warnings.push(`${where}: ${p()} 값이 undefined 라 뺐음`);
    return undefined;
  }
  if (tp === 'bigint' || tp === 'symbol') {
    warnings.push(`${where}: ${p()} 는 ${tp} 라 뺐음`);
    return undefined;
  }
  // 객체
  if (seen.has(v)) throw new Error(`${where}: ${p()} 순환 참조`);
  if (v instanceof Map || v instanceof Set || v instanceof Date || v instanceof RegExp) {
    warnings.push(`${where}: ${p()} 는 ${v.constructor.name} 라 뺐음`);
    return undefined;
  }
  seen.add(v);
  let out;
  if (Array.isArray(v)) {
    out = v.map((x, i) => {
      const r = toJSONValue(x, where, pathArr.concat(i), seen);
      return r === undefined ? null : r;   // 배열은 길이를 지키려고 null 로 (경고는 위에서 남김)
    });
  } else {
    out = {};
    for (const k of Object.keys(v)) {
      const r = toJSONValue(v[k], where, pathArr.concat(k), seen);
      if (r !== undefined) out[k] = r;
    }
  }
  seen.delete(v);
  return out;
}

// 함수만 모인(또는 대부분 함수인) 계산용 객체인지 — 데이터가 아니라 로직
function isLogicNamespace(v) {
  if (!v || typeof v !== 'object' || Array.isArray(v)) return false;
  const ks = Object.keys(v);
  if (!ks.length) return false;
  const fnCount = ks.filter(k => typeof v[k] === 'function').length;
  return fnCount > 0 && fnCount * 2 >= ks.length;
}

function describe(v) {
  if (Array.isArray(v)) return { type: 'array', count: v.length };
  if (v && typeof v === 'object') return { type: 'object', count: Object.keys(v).length };
  return { type: v === null ? 'null' : typeof v, count: null };
}

function countLeaves(v) {
  if (Array.isArray(v)) return v.reduce((n, x) => n + countLeaves(x), 0);
  if (v && typeof v === 'object') return Object.keys(v).reduce((n, k) => n + countLeaves(v[k]), 0);
  return 1;
}

// 내용이 바뀐 때만 쓴다 (idempotent)
const written = [];
const produced = new Set();
// godot/data 안에서 이번 변환이 만들지 않은 JSON (지워진 모듈의 옛 결과 등)
function staleFiles() {
  const out = [];
  const walk = (sub) => {
    const dir = path.join(OUT, sub);
    if (!fs.existsSync(dir)) return;
    for (const f of fs.readdirSync(dir)) {
      const rel = sub ? sub + '/' + f : f;
      if (rel === 'lang_extra') continue;   // Godot 전용 번역 키 (손으로 관리, godot/scripts/core/i18n.gd 가 합침)
      if (fs.statSync(path.join(dir, f)).isDirectory()) walk(rel);
      else if (f.endsWith('.json') && !produced.has(rel)) out.push(rel);
    }
  };
  walk('');
  return out;
}
const unchanged = [];
function writeJSON(rel, obj) {
  const file = path.join(OUT, rel);
  const text = JSON.stringify(obj, null, 1) + '\n';
  if (!CHECK) fs.mkdirSync(path.dirname(file), { recursive: true });
  produced.add(rel);
  if (fs.existsSync(file) && fs.readFileSync(file, 'utf8') === text) { unchanged.push(rel); return text; }
  if (!CHECK) fs.writeFileSync(file, text);
  written.push(rel);
  return text;
}

// ═══ 1. 게임 데이터 ═══
function exportData(manifest) {
  const order = pageOrder();
  const fileToModule = {};
  MODULES.forEach(m => m.files.forEach(f => { fileToModule[f] = m.name; }));
  const wanted = new Set(CONTEXT_ONLY.concat(Object.keys(fileToModule)));
  const missing = [...wanted].filter(f => order.indexOf(f) === -1);
  if (missing.length) throw new Error(`어느 페이지에도 없는 파일: ${missing.join(', ')} — MODULES 를 고쳐 주세요`);
  // 데이터 폴더의 새 파일이 MODULES 에 빠지지 않았는지 확인
  fs.readdirSync(path.join(ROOT, 'data')).filter(f => f.endsWith('.js')).forEach(f => {
    if (!fileToModule['data/' + f]) warnings.push(`data/${f} 가 MODULES 에 없어 내보내지 않았음`);
  });

  const env = makeContext('data');
  const seq = order.filter(f => wanted.has(f));
  for (const m of MODULES) for (const g of m.stub || []) {
    env.sandbox[g] = {};
    notes.push(`${m.name}: 적재용 빈 흉내 전역 ${g} (내보내지 않음)`);
  }
  const declared = {};   // 모듈 → 그 모듈 파일들이 새로 만든 전역 이름 (선언 순서)
  for (const f of seq) {
    const names = runFile(env, f);
    const mod = fileToModule[f];
    if (!mod) continue;
    (declared[mod] = declared[mod] || []);
    names.forEach(n => { if (declared[mod].indexOf(n) === -1) declared[mod].push(n); });
  }
  if (env.tCalls.length) warnings.push(`적재 중 t() 호출됨 (번역 키가 데이터에 고정됨): ${[...new Set(env.tCalls)].join(', ')}`);

  manifest.sources = {};
  manifest.modules = {};
  for (const m of MODULES) {
    const out = {};
    const info = {};
    const names = declared[m.name] || [];
    if (m.pick) {
      const lost = m.pick.filter(n => names.indexOf(n) === -1);
      if (lost.length) throw new Error(`${m.name}: pick 한 전역이 없음: ${lost.join(', ')}`);
      const rest = names.filter(n => m.pick.indexOf(n) === -1 && typeof env.sandbox[n] !== 'function');
      if (rest.length) notes.push(`${m.name}: pick 에 없어 내보내지 않은 전역 — ${rest.join(', ')}`);
    }
    for (const name of m.pick || names) {
      const v = env.sandbox[name];
      if (typeof v === 'function') continue;                       // 함수 선언은 로직
      if (name.charAt(0) === '_') { notes.push(`${m.name}: ${name} 는 '_' 로 시작하는 내부 상태라 제외`); continue; }
      if (isLogicNamespace(v)) { skippedLogic.push(`${m.name}.${name}`); continue; }
      const j = toJSONValue(v, `${m.name}.json`, [name], new Set());
      if (j === undefined) continue;
      out[name] = j;
      info[name] = describe(j);
    }
    writeJSON(`${m.name}.json`, out);
    manifest.modules[m.name] = { file: `${m.name}.json`, globals: info };
    manifest.sources[m.name] = m.files.map(f => ({ file: f, sha1: sha1(read(f)) }));
  }
}

// ═══ 2. 언어 팩 ═══
function exportLang(manifest) {
  const i18nSrc = read('js/common/i18n.js');
  const mm = i18nSrc.match(/_LANG_PARTS\s*=\s*\[([^\]]*)\]/);
  if (!mm) throw new Error('js/common/i18n.js 에서 _LANG_PARTS 를 찾지 못함');
  const parts = mm[1].split(',').map(s => s.trim().replace(/^['"]|['"]$/g, '')).filter(Boolean);
  manifest.lang = { parts, langs: {} };
  for (const lang of LANGS) {
    const dir = `data/language/${lang}`;
    const onDisk = fs.readdirSync(path.join(ROOT, dir)).filter(f => f.endsWith('.js')).map(f => f.slice(0, -3));
    onDisk.filter(p => parts.indexOf(p) === -1).forEach(p => warnings.push(`${dir}/${p}.js 가 _LANG_PARTS 에 없어 웹에서도 안 읽힘 — 내보내지 않음`));
    const env = makeContext('lang.' + lang);
    for (const p of parts) runFile(env, `${dir}/${p}.js`);
    const v = env.sandbox['_LANG_' + lang];
    if (!v) throw new Error(`window._LANG_${lang} 이 만들어지지 않음`);
    const j = toJSONValue(v, `lang/${lang}.json`, [], new Set());
    writeJSON(`lang/${lang}.json`, j);
    manifest.lang.langs[lang] = { file: `lang/${lang}.json`, type: 'object', count: Object.keys(j).length, leaves: countLeaves(j),
      sources: parts.map(p => ({ file: `${dir}/${p}.js`, sha1: sha1(read(`${dir}/${p}.js`)) })) };
  }
}

// ═══ 3. 스토리 대본 ═══
function exportStory(manifest) {
  manifest.story = {};
  const files = {};
  for (const lang of LANGS) files[lang] = `data/story/story.${lang}.js`;
  files.sample = 'data/story/story.sample.js';
  for (const key of Object.keys(files)) {
    const env = makeContext('story.' + key);
    const names = runFile(env, files[key]);
    const g = names.find(n => /^STORY_[A-Z]+(-[A-Z]+)?$/.test(n));   // STORY_KO · STORY_ZH-CN
    if (!g) throw new Error(`${files[key]} 에서 STORY_* 전역을 찾지 못함`);
    const j = toJSONValue(env.sandbox[g], `story/${key}.json`, [], new Set());
    writeJSON(`story/${key}.json`, j);
    manifest.story[key] = { file: `story/${key}.json`, global: g, type: 'object', count: Object.keys(j).length,
      episodes: j.episodes ? Object.keys(j.episodes).length : 0, leaves: countLeaves(j), sha1: sha1(read(files[key])) };
  }
}

function main() {
  const manifest = { format: 1, generator: 'tools/export-godot-data.js', note: '자동 생성 파일 — 직접 고치지 말고 웹 data/*.js 를 고친 뒤 다시 변환' };
  exportData(manifest);
  exportLang(manifest);
  exportStory(manifest);
  manifest.special_values = specialValues;
  manifest.skipped_logic = skippedLogic;
  manifest.warnings = warnings;
  manifest.notes = notes;
  writeJSON('manifest.json', manifest);
  const stale = staleFiles();

  if (CHECK) {
    if (!written.length && !stale.length) { console.log(`[export-godot-data --check] 최신 상태 (${unchanged.length}개 파일 일치)`); return; }
    console.log(`[export-godot-data --check] godot/data 가 웹 데이터와 다릅니다 — node tools/export-godot-data.js 를 실행하세요`);
    written.forEach(f => console.log('  바뀔 파일: ' + f));
    stale.forEach(f => console.log('  남은 옛 파일: ' + f));
    process.exitCode = 1;
    return;
  }
  stale.forEach(f => console.log('  ! 이번 변환에 없는 옛 파일 (지워도 됨): godot/data/' + f));
  console.log(`[export-godot-data] 기록 ${written.length}개, 변경 없음 ${unchanged.length}개 → ${path.relative(ROOT, OUT)}/`);
  written.forEach(f => console.log('  + ' + f));
  for (const m of Object.keys(manifest.modules)) {
    const g = manifest.modules[m].globals;
    console.log(`  ${m}.json: ${Object.keys(g).map(k => g[k].count == null ? k : `${k}(${g[k].count})`).join(', ')}`);
  }
  if (specialValues.length) console.log(`  특수값 ${specialValues.length}개 (Infinity 등 → 문자열, manifest.special_values)`);
  if (skippedLogic.length) console.log(`  제외(계산용 객체): ${skippedLogic.join(', ')}`);
  if (warnings.length) { console.log(`  경고 ${warnings.length}개:`); warnings.forEach(w => console.log('   ! ' + w)); }
}

main();
