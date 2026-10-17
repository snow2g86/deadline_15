#!/usr/bin/env node
// ═══════════════════════════════════════════
//  tools/outer-4a-expect.js — Godot 4a(바깥 화면) 규칙 시험의 정답을 웹 코드로 만든다
//
//  웹 파일(js/common/*.js, js/stage-select.js, js/index.js, data/*.js)을 페이지와 같은 순서로 Node vm 안에서 그대로 실행하고,
//  여러 가짜 세이브에서 나온 결과를 godot/tests/fixtures/outer_4a_web.json 에 쓴다. 웹 파일은 고치지 않는다.
//   - 스테이지 선택: renderEpisodes · renderStages 가 만든 카드의 class(locked·done·current·cleared·next·boss) · 진행도 글 · 별
//   - 요일 던전: Daily.left · classes(요일별) · tierOpen · consume 뒤 저장값
//   - 출격: _launchStage (5명이면 battle.html, 아니면 party-select.html) 의 game_nav · ps_can_start · 이동 페이지
//   - 파티 저장: loadParties(마이그레이션) · saveParties(지휘관 빼기) · getActiveParty
//   - 저장값 점검: validateAndRepairGameData 뒤 저장소 (무작위가 없는 경우만)
//  화면(DOM)은 class·글만 기록하는 가짜. 번역 t() 는 키를 돌려줌.
//
//  사용: node tools/outer-4a-expect.js            (다시 만들기)
//        node tools/outer-4a-expect.js --check    (쓰지 않고 지금 파일과 같은지만 — 다르면 종료 코드 1)
// ═══════════════════════════════════════════
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.resolve(__dirname, '..');
const OUT = path.join(ROOT, 'godot', 'tests', 'fixtures', 'outer_4a_web.json');
const CHECK = process.argv.includes('--check');

const FILES = [
  'js/common/store.js', 'data/jab.js', 'js/common/constants.js', 'js/common/storage.js', 'js/common/character.js',
  'js/common/soul.js', 'js/common/daily.js', 'data/stages.js', 'js/logic/stages.js', 'js/stage-select.js', 'js/index.js',
  'js/battle/end.js',
];

function hoistTopLevel(src) { return src.replace(/^(const|let)(\s)/gm, 'var$2'); }

// ── 가짜 DOM (class · innerHTML · 자식만 기록) ──
function makeDoc() {
  const byId = {};
  function el(tag) {
    let html = '';
    const e = {
      tag, className: '', textContent: '', children: [], style: {}, dataset: {}, onclick: null, type: '',
      get innerHTML() { return html; }, set innerHTML(v) { html = String(v); if (html === '') this.children.length = 0; },
      classList: { add() {}, remove() {}, toggle() {}, contains() { return false; } },
      appendChild(c) { this.children.push(c); return c; }, insertBefore(c) { this.children.unshift(c); return c; },
      remove() {}, setAttribute() {}, addEventListener() {}, querySelector() { return null; }, querySelectorAll() { return []; },
    };
    return e;
  }
  const doc = {
    _byId: byId,
    getElementById(id) { if (!byId[id]) byId[id] = el('div'); return byId[id]; },
    querySelector(sel) { if (sel === '.stage-subtitle') return doc.getElementById('__subtitle'); return null; },
    querySelectorAll() { return []; },
    createElement(tag) { return el(tag); },
    addEventListener() {},
    body: el('body'),
    documentElement: { lang: 'ko' },
  };
  return doc;
}

// ── 한 세계: vm 하나에 웹 파일 적재 (날짜·난수 고정) ──
function makeWorld(date, seedStore) {
  const mem = {};
  for (const k of Object.keys(seedStore || {})) mem[k] = typeof seedStore[k] === 'string' ? seedStore[k] : JSON.stringify(seedStore[k]);
  const doc = makeDoc();
  const FIXED = date;   // [y, m(1~12), d]
  class FakeDate extends Date {
    constructor(...a) { if (a.length) super(...a); else super(FIXED[0], FIXED[1] - 1, FIXED[2], 12, 0, 0); }
    static now() { return new FakeDate().getTime(); }
  }
  let seed = 12345;
  const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
  const loc = { href: 'stage-select.html', search: '' };
  const sandbox = {
    console: { log() {}, warn() {}, error() {} }, document: doc, location: loc, navigator: { language: 'ko' },
    setTimeout() {}, clearTimeout() {}, setInterval() {}, clearInterval() {},
    Math: Object.create(Math, { random: { value: rnd } }), Date: FakeDate, JSON, Object, Array, Set, Map, Number, String, Boolean, parseInt, parseFloat, isNaN, Promise,
    t: (k, p) => k + (p ? JSON.stringify(p) : ''), _i18nData: {}, _resolve: () => undefined, showAlert() {}, showModal() {}, closeModal() {}, showConfirm() {},
    renderBottomNav() {}, hideSplash() {}, i18nInit: async () => {},
  };
  sandbox.window = sandbox;
  const ctx = vm.createContext(sandbox);
  for (const f of FILES) vm.runInContext(hoistTopLevel(fs.readFileSync(path.join(ROOT, f), 'utf8')), ctx, { filename: f });
  ctx.Store.useBackend({
    getItem: k => Object.prototype.hasOwnProperty.call(mem, k) ? mem[k] : null,
    setItem: (k, v) => { mem[k] = String(v); }, removeItem: k => { delete mem[k]; }, keys: () => Object.keys(mem), clear: () => { for (const k in mem) delete mem[k]; },
  });
  ctx.eval = code => vm.runInContext(code, ctx);
  return { ctx, mem, doc, loc };
}

function dumpStore(mem) {
  const o = {};
  for (const k of Object.keys(mem).sort()) { try { o[k] = JSON.parse(mem[k]); } catch (_) { o[k] = mem[k]; } }
  return o;
}

// ── 가짜 세이브 ──
function novice(uid, extra) {
  return Object.assign({ uid, cls: 'novice', nameId: uid, lv: 1, exp: 0, dead: false, hp: 85, atk: 22, def: 8, move: 3, range: 1,
    pot: { hp: 8, atk: 2.5, def: 1.5, actionRec: 0.1 }, actionRec: 1.1, gender: 'm' }, extra || {});
}
function commander(uid, extra) {
  return Object.assign({ uid, cls: 'commander', nameId: null, customName: '리안', lv: 1, exp: 0, dead: false, hp: 95, atk: 12, def: 6, move: 2, range: 2,
    pot: { hp: 8.4, atk: 1.6, def: 0.6, actionRec: 0.12 }, actionRec: 1.22, gender: 'm', buffer: 2 }, extra || {});
}
function roster(n, extra) {
  const chars = [commander(100)];
  for (let i = 1; i <= n; i++) chars.push(novice(i, (extra || {})[i]));
  return { chars, nextId: 101 };
}
function parties(slots0, active) {
  const ps = [{ id: 1, slots: slots0 }];
  for (let i = 2; i <= 5; i++) ps.push({ id: i, slots: [null, null, null, null, null] });
  return { parties: ps, activePartyId: active || 1, nextPartyId: 6 };
}
function range(a, b) { const r = []; for (let i = a; i <= b; i++) r.push(i); return r; }

const PROGRESS = [
  { name: 'new', save: { gold: 2000 } },
  { name: 'ep1_half', save: { gold: 500, cleared: [1, 2, 3, 4], stars: { 1: [1, 1, 1], 2: [1, 0, 1], 3: [1, 0, 0], 4: [1, 1, 0] } } },
  { name: 'ep1_done', save: { gold: 900, cleared: range(1, 10), stars: { 10: [1, 1, 1], 5: [1, 0, 0] } } },
  { name: 'ep1_gap', save: { gold: 900, cleared: [1, 2, 3, 5, 6, 7, 8, 9, 10] } },
  { name: 'ep3_mid', save: { gold: 4000, cleared: range(1, 24), stars: { 21: [1, 1, 1], 24: [1, 0, 1] } } },
  { name: 'late', save: { gold: 9999, cleared: range(1, 80).concat([95]) } },
  { name: 'all', save: { gold: 1, cleared: range(1, 100) } },
  { name: 'unordered', save: { gold: 3, cleared: [12, 11, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13] } },
];

function cardInfo(c) {
  // innerHTML 의 진행 글 'N/M' 과 별 'i class="on"' 개수만
  const h = c.innerHTML || '';
  const stars = (h.match(/<i class="on">/g) || []).length;
  const prog = (h.match(/ep-progress"><span class="ep-stars">★ (\d+)\/(\d+)<\/span> (\d+)\/(\d+)/) || []).slice(1).map(Number);
  return { cls: c.className, onclick: !!c.onclick, stars, prog };
}

function progressCases() {
  const out = [];
  for (const P of PROGRESS) {
    const w = makeWorld([2026, 10, 15], { game_save: P.save });
    const C = w.ctx;
    C.eval('_viewMode = "episodes"; render();');
    const list = w.doc.getElementById('stage-list');
    const sub = w.doc.getElementById('__subtitle').textContent;
    const eps = list.children.filter(c => /episode-card/.test(c.className)).map(cardInfo);
    const stages = {};
    for (const ep of C.EPISODES) {
      C.eval('_viewMode = "stages"; _selectedEp = ' + ep.id + '; render();');
      stages[ep.id] = w.doc.getElementById('stage-list').children.map(c => {
        const ci = cardInfo(c);
        return { cls: c.className, onclick: ci.onclick, stars: (c.innerHTML.match(/<i class="(on)?">★<\/i>/g) || []).map(s => /on/.test(s) ? 1 : 0) };
      });
    }
    out.push({ name: P.name, store: { game_save: P.save }, subtitle: sub, episodes: eps, stages });
  }
  return out;
}

function dailyCases() {
  const out = [];
  const dates = [[2026, 10, 11], [2026, 10, 12], [2026, 10, 13], [2026, 10, 14], [2026, 10, 15], [2026, 10, 16], [2026, 10, 17]];
  const saves = [
    { game_save: { gold: 1, cleared: [] } },
    { game_save: { gold: 1, cleared: range(1, 20) }, game_daily: { date: '2026-10-15', used: 2 } },
    { game_save: { gold: 1, cleared: range(1, 45) }, game_daily: { date: '2026-10-14', used: 3 } },
    { game_save: { gold: 1, cleared: [75, 3] }, game_daily: { date: '2026-10-15', used: 3 } },
  ];
  for (const d of dates) {
    for (const s of saves) {
      const w = makeWorld(d, s);
      const C = w.ctx;
      const r = { date: d, weekday: new Date(d[0], d[1] - 1, d[2]).getDay(), store: s, left: C.Daily.left(), classes: C.Daily.classes(),
        tierOpen: C.DAILY.tiers.map((_, i) => C.Daily.tierOpen(i)), best: C.Daily.bestCleared() };
      C.Daily.consume();
      r.afterConsume = JSON.parse(w.mem.game_daily);
      r.leftAfter = C.Daily.left();
      out.push(r);
    }
  }
  return out;
}

function launchCases() {
  const out = [];
  const R5 = roster(6);
  const RD = roster(6, { 2: { dead: true, diedAt: 5 } });
  const cases = [
    { name: 'full', store: { game_roster: R5, game_parties: parties([1, 2, 3, 4, 5]) }, stage: 3, practice: false },
    { name: 'practice', store: { game_roster: R5, game_parties: parties([1, 2, 3, 4, 5]) }, stage: 2, practice: true },
    { name: 'dead_member', store: { game_roster: RD, game_parties: parties([1, 2, 3, 4, 5]) }, stage: 1, practice: false },
    { name: 'four', store: { game_roster: R5, game_parties: parties([1, 2, null, 4, 5]) }, stage: 1, practice: false },
    { name: 'active2', store: { game_roster: R5, game_parties: parties([1, 2, 3, 4, 5], 2) }, stage: 1, practice: false },
    { name: 'commander_in_slot', store: { game_roster: R5, game_parties: parties([100, 1, 2, 3, 4]) }, stage: 1, practice: false },
  ];
  for (const cs of cases) {
    const w = makeWorld([2026, 10, 15], cs.store);
    const C = w.ctx;
    const st = C.STAGES.find(s => s.id === cs.stage);
    C._launchStage(st, cs.practice);
    const nav = JSON.parse(w.mem.game_nav);
    out.push({ name: cs.name, store: cs.store, stage: cs.stage, practice: cs.practice, to: w.loc.href, party: nav.party || null,
      practiceMode: nav.practiceMode, navStageId: nav.cStage.id, canStart: w.mem.ps_can_start === undefined ? null : w.mem.ps_can_start,
      parties: JSON.parse(w.mem.game_parties) });
  }
  return out;
}

// 다음 스테이지 (battle/end.js BattleEnd.goNextStage) — 출격 단추 상태 포함
function nextCases() {
  const out = [];
  const R5 = roster(6);
  const RD = roster(6, { 2: { dead: true, diedAt: 5 }, 3: { dead: true, diedAt: 9 } });
  const cases = [
    { name: 'next_full', store: { game_roster: R5, game_parties: parties([1, 2, 3, 4, 5]), ps_can_start: 'false' }, stage: 4 },
    { name: 'next_dead', store: { game_roster: RD, game_parties: parties([1, 2, 3, 4, 5]), ps_can_start: 'false' }, stage: 4 },
  ];
  for (const cs of cases) {
    const w = makeWorld([2026, 10, 15], cs.store);
    const C = w.ctx;
    C.BattleEnd.goNextStage(C.STAGES.find(s => s.id === cs.stage));
    const nav = JSON.parse(w.mem.game_nav);
    out.push({ name: cs.name, store: cs.store, stage: cs.stage, to: w.loc.href, party: nav.party || null, practiceMode: nav.practiceMode === undefined ? null : nav.practiceMode,
      navStageId: nav.cStage.id, canStart: w.mem.ps_can_start === undefined ? null : w.mem.ps_can_start });
  }
  return out;
}

function partyCases() {
  const out = [];
  const inputs = [
    { name: 'default', store: { game_roster: roster(5), game_parties: parties([1, 2, 3, 4, 5]) } },
    { name: 'bad_active', store: { game_roster: roster(5), game_parties: Object.assign(parties([1, 2, 3, 4, 5]), { activePartyId: 0 }) } },
    { name: 'old_single', store: { game_roster: roster(5), game_parties: { parties: [{ id: 1, slots: [1, 2, 3, 4, 5] }], activePartyId: 1 } } },
    { name: 'commander_first', store: { game_roster: roster(5), game_parties: parties([100, 1, 2, 3, 4]) } },
    { name: 'legacy_game_party', store: { game_roster: roster(5), game_party: [3, 1, 2] } },
    { name: 'none', store: { game_roster: roster(5) } },
    { name: 'empty_parties', store: { game_roster: roster(5), game_parties: { parties: [], activePartyId: 1 } } },
  ];
  for (const cs of inputs) {
    const w = makeWorld([2026, 10, 15], cs.store);
    const C = w.ctx;
    const loaded = C.loadParties();
    const active = C.getActiveParty();
    out.push({ name: cs.name, store: cs.store, loaded: JSON.parse(JSON.stringify(loaded)), active, after: dumpStore(w.mem) });
  }
  return out;
}

function validateCases() {
  const out = [];
  const R = roster(5);
  const inputs = [
    { name: 'clean', store: { game_roster: R, game_parties: parties([1, 2, 3, 4, 5]), game_save: { gold: 50 }, game_inventory: [] } },
    { name: 'dup_uid_and_fixes', store: { game_roster: { chars: [commander(100), novice(1), novice(1, { lv: 0 }), novice(2, { lv: 0, hp: -1, def: -2, pot: { hp: 'a', atk: 2, def: 1, actionRec: 0.1 }, gender: '', dead: 'x' }), novice(3, { cls: 'nope', exp: -5 }), novice(0), { uid: 'x' }], nextId: 101 },
      game_parties: parties([1, 2, 9, 3, null]), game_save: { gold: -5 } } },
    { name: 'no_next_id', store: { game_roster: { chars: [commander(7), novice(1), novice(4)] }, game_parties: { parties: [{ id: 'a', slots: [1, 4] }, { slots: 5 }], activePartyId: 9 } } },
    { name: 'inventory_mix', store: { game_roster: R, game_parties: parties([1, 2, 3, 4, 5]), game_save: { gold: 10, cleared: [1] },
      game_inventory: [{ type: 'equip', eid: 'e1' }, { type: 'junk' }, null, { id: 'warrior_x', cls: 'warrior', lv: 1 }, { id: 'nocls' }, { type: 'rune', kind: 'fire' }],
      game_cleared: [1, 0, 101, 'x', 50], game_battle_items: [{ id: 'a', count: 1 }, { id: 'b', count: -1 }, { count: 2 }, { id: 'c', count: '2' }] } },
    { name: 'battle_items_object', store: { game_roster: R, game_parties: parties([1, 2, 3, 4, 5]), game_battle_items: { potions: ['p1'], sieges: [] } } },
    { name: 'parties_empty_raw', store: { game_roster: R, game_parties: {} } },
    { name: 'dead_without_time', store: { game_roster: { chars: [commander(100), novice(1, { dead: true }), novice(2, { dead: true, diedAt: 77 })], nextId: 101 }, game_parties: parties([1, 2, null, null, null]) } },
  ];
  for (const cs of inputs) {
    const w = makeWorld([2026, 10, 15], cs.store);
    const ok = w.ctx.validateAndRepairGameData();
    out.push({ name: cs.name, store: cs.store, ok, after: dumpStore(w.mem) });
  }
  return out;
}

const result = {
  note: 'node tools/outer-4a-expect.js 가 웹 코드를 그대로 실행해 만든 정답 — 손으로 고치지 말 것 (godot/tests/check_outer_4a.gd 가 비교)',
  progress: progressCases(), daily: dailyCases(), launch: launchCases(), next: nextCases(), parties: partyCases(), validate: validateCases(),
};
const text = JSON.stringify(result, null, 1) + '\n';
if (CHECK) {
  const cur = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : '';
  if (cur !== text) { console.log('[outer-4a-expect] 정답 파일이 웹 코드와 다릅니다 — node tools/outer-4a-expect.js 로 다시 만드세요'); process.exit(1); }
  console.log('[outer-4a-expect] 같음');
} else {
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, text);
  console.log('[outer-4a-expect] 썼음: ' + path.relative(ROOT, OUT) + ' (진행 ' + result.progress.length + ' · 요일 ' + result.daily.length + ' · 출격 ' + result.launch.length +
    ' · 파티 ' + result.parties.length + ' · 점검 ' + result.validate.length + ')');
}
