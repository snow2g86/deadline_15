#!/usr/bin/env node
// ═══════════════════════════════════════════
//  tools/outer-4b2-expect.js — Godot 4b-2(성소 · 아카데미 · 도감 · 가이드) 시험의 정답을 웹 코드로 만든다
//
//  웹 파일(sanctuary.html · academy.html 과 같은 순서의 js/common/*, data/*, js/logic/*, js/skills.js, js/sanctuary.js, js/academy.js,
//  compendium.html · guide.html 의 인라인 <script>)을 Node vm 안에서 그대로 실행하고 결과를 godot/tests/fixtures/outer_4b2_web.json 에 쓴다.
//  웹 파일은 고치지 않는다.
//   - 성소·아카데미: Math.random = mulberry32(씨앗), Date.now = 고정 시각. 화면 단추의 onclick 을 차례로 눌러(확인 창은 '확인') 저장소 전체·난수 호출 수
//     번역 t() 는 키 + JSON(자리표시자), character.names 만 한국어 팩
//   - 도감·가이드: 진짜 언어 팩(godot/data/lang/ko.json · en.json, 웹 t() 와 같은 규칙)으로 HTML 을 만들고 태그를 걷어낸 글 조각 (Godot 은 같은 조각을 블록에서 뽑아 비교)
//     그림 함수(iconOr · clsIcon · skillIcon …)는 빈 글
//   - V8 정렬: 64 ~ 700개 배열을 난수 비교 함수(mulberry32)·일관된 비교 함수로 정렬한 결과와 비교 호출 수 (Godot Js.v8_sort 와 비교)
//
//  사용: node tools/outer-4b2-expect.js            (다시 만들기)
//        node tools/outer-4b2-expect.js --check    (쓰지 않고 지금 파일과 같은지만 — 다르면 종료 코드 1)
//        node tools/outer-4b2-expect.js --roundtrip <Godot 세이브 덤프.json>   (Godot 이 쓴 세이브를 웹 성소·아카데미·로비가 오류 없이 읽는지)
// ═══════════════════════════════════════════
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.resolve(__dirname, '..');
const OUT = path.join(ROOT, 'godot', 'tests', 'fixtures', 'outer_4b2_web.json');
const CHECK = process.argv.includes('--check');
const NOW = 1791990000000;   // 고정 시각 (Godot 시험도 같은 값)
const PACK = l => JSON.parse(fs.readFileSync(path.join(ROOT, 'godot', 'data', 'lang', l + '.json'), 'utf8'));
const NAMES = PACK('ko').character.names;

const COMMON = ['js/common/store.js', 'data/jab.js', 'js/common/constants.js', 'js/common/storage.js', 'js/common/character.js',
  'js/common/soul.js', 'js/common/daily.js', 'js/common/render.js', 'js/skills.js', 'data/equip.js', 'js/logic/equip.js',
  'data/gear.js', 'js/logic/gear.js', 'data/hazards.js', 'js/logic/hazards.js'];
const CODEX = ['js/common/store.js', 'data/jab.js', 'js/common/constants.js', 'js/common/render.js', 'js/skills.js', 'data/stages.js', 'js/logic/stages.js',
  'js/common/daily.js', 'data/synergy.js', 'js/logic/synergy.js', 'data/equip.js', 'js/logic/equip.js', 'data/gear.js', 'js/logic/gear.js',
  'data/hazards.js', 'js/logic/hazards.js'];

function hoistTopLevel(src) { return src.replace(/^(const|let)(\s)/gm, 'var$2'); }

function mulberry(seed) {
  let a = seed >>> 0;
  const f = () => { a = (a + 0x6D2B79F5) | 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  const g = () => { g.calls++; return f(); };
  g.calls = 0;
  return g;
}

// ── 가짜 DOM (class·innerHTML 만 기록) ──
function parseBtns(html, re, mk) { const out = []; let m; while ((m = re.exec(html))) out.push(mk(m)); return out; }
function makeDoc() {
  const byId = {};
  function el(tag) {
    let html = '';
    const sel = {};
    const e = {
      tag, className: '', textContent: '', children: [], style: {}, dataset: {}, onclick: null, type: '', title: '', value: '', disabled: false, id: '',
      get innerHTML() { return html; }, set innerHTML(v) { html = String(v); if (html === '') this.children.length = 0; for (const k in sel) delete sel[k]; },
      classList: { add() {}, remove() {}, toggle() {}, contains() { return false; } },
      appendChild(c) { this.children.push(c); return c; }, insertBefore(c) { this.children.unshift(c); return c; },
      remove() {}, setAttribute() {}, getAttribute(a) { return a === 'data-uid' ? (this.dataset.uid || null) : null; }, addEventListener() {},
      insertAdjacentHTML(_w, h) { const c = el('div'); c.innerHTML = h; this.children.push(c); },
      focus() {},
      querySelector(s) { if (!sel[s]) sel[s] = el('stub'); return sel[s]; },
      querySelectorAll(s) {
        if (!sel['all:' + s]) {
          let out = [];
          if (s === '.enc-opt:not([disabled])') out = parseBtns(html, /<button class="enc-opt[^"]*" data-k="([^"]+)"( disabled)?/g, m => { if (m[2]) return null; const b = el('button'); b.dataset.k = m[1]; return b; }).filter(Boolean);
          if (s === '.soul-combine') out = parseBtns(html, /class="soul-combine" data-cls="([^"]+)"/g, m => { const b = el('button'); b.dataset.cls = m[1]; return b; });
          sel['all:' + s] = out;
        }
        return sel['all:' + s];
      },
    };
    return e;
  }
  const modalSub = () => doc.getElementById('modal-sub').innerHTML;
  const cache = {};
  const doc = {
    _byId: byId,
    getElementById(id) { if (!byId[id]) byId[id] = el('div'); return byId[id]; },
    querySelector() { return null; },
    querySelectorAll(s) {
      const h = modalSub();
      const key = s + '|' + h;
      if (cache[key]) return cache[key];
      let out = [];
      if (s === '.pt-btn') out = parseBtns(h, /class="pt-btn" data-uid="(\d+)"/g, m => { const b = el('div'); b.dataset.uid = m[1]; return b; });
      else if (s === '#sac-list-inner .sac-btn') out = parseBtns(h, /class="sac-btn" data-uid="(\d+)"/g, m => { const b = el('div'); b.dataset.uid = m[1]; return b; });
      else if (s === '.scroll-select-btn') out = parseBtns(h, /class="scroll-select-btn" data-idx="(\d+)" data-cls="([^"]+)"/g, m => { const b = el('div'); b.dataset.idx = m[1]; b.dataset.cls = m[2]; return b; });
      else if (s === '.sb-target-btn') out = parseBtns(h, /class="sb-target-btn" data-uid="(\d+)"/g, m => { const b = el('div'); b.dataset.uid = m[1]; return b; });
      cache[key] = out;
      return out;
    },
    createElement(tag) { return el(tag); },
    createTextNode(t) { const e = el('#text'); e.textContent = String(t); return e; },
    addEventListener() {},
    body: el('body'),
    documentElement: { lang: 'ko' },
  };
  return doc;
}

function realT(pack) {
  const res = (o, p) => p.split('.').reduce((a, k) => a && a[k], o);
  return (key, params) => {
    const v = res(pack, key);
    if (v === undefined) return key;
    if (!params || typeof v !== 'string') return v;
    return v.replace(/\{(\w+)\}/g, (_, k) => params[k] !== undefined ? params[k] : `{${k}}`);
  };
}

function makeWorld(files, seed, seedStore, tfn) {
  const mem = {};
  for (const k of Object.keys(seedStore || {})) mem[k] = typeof seedStore[k] === 'string' ? seedStore[k] : JSON.stringify(seedStore[k]);
  const doc = makeDoc();
  class FakeDate extends Date {
    constructor(...a) { if (a.length) super(...a); else super(NOW); }
    static now() { return NOW; }
  }
  const rnd = mulberry(seed);
  const log = { alerts: [], confirms: [], hrefs: [] };
  const t = tfn || ((k, p) => (k === 'character.names' ? NAMES : k + (p ? JSON.stringify(p) : '')));
  const loc = { search: '' };
  Object.defineProperty(loc, 'href', { get() { return 'page'; }, set(v) { log.hrefs.push(v); } });
  const sandbox = {
    console: { log() {}, warn() {}, error() {} }, document: doc, location: loc, navigator: { language: 'ko' }, history: { back() {} },
    setTimeout(fn) { fn(); }, clearTimeout() {}, setInterval() {}, clearInterval() {}, URLSearchParams, Proxy,
    Math: Object.create(Math, { random: { value: rnd } }), Date: FakeDate, JSON, Object, Array, Set, Map, Number, String, Boolean, parseInt, parseFloat, isNaN, Promise, RegExp,
    t, _i18nData: {}, _resolve: () => undefined,
    showAlert(m) { log.alerts.push(m); }, showModal() {}, closeModal() {},
    showConfirm(m, yes) { log.confirms.push(m); if (yes) yes(); },
    renderBottomNav() {}, hideSplash() {}, i18nInit: async () => {},
  };
  sandbox.window = sandbox;
  const ctx = vm.createContext(sandbox);
  for (const f of files) {
    if (f.startsWith('<inline:')) vm.runInContext(hoistTopLevel(f.slice(8)), ctx, { filename: 'inline' });
    else vm.runInContext(hoistTopLevel(fs.readFileSync(path.join(ROOT, f), 'utf8')), ctx, { filename: f });
    if (f === 'js/common/render.js' || f.startsWith('<inline:') === false) {
      vm.runInContext("clsIcon = function(){ return ''; }; charPortrait = function(){ return ''; }; charSprite = function(){ return ''; }; skillIcon = function(){ return ''; };" +
        "iconOr = function(){ return ''; }; itemIcon = function(){ return ''; }; runeIcon = function(){ return ''; }; equipIcon = function(it){ return '<eid:' + it.eid + '>'; }; getEquipEmoji = function(){ return ''; };", ctx);
    }
  }
  if (ctx.Store && ctx.Store.useBackend) {
    ctx.Store.useBackend({
      getItem: k => Object.prototype.hasOwnProperty.call(mem, k) ? mem[k] : null,
      setItem: (k, v) => { mem[k] = String(v); }, removeItem: k => { delete mem[k]; }, keys: () => Object.keys(mem), clear: () => { for (const k in mem) delete mem[k]; },
    });
  }
  return { ctx, mem, doc, log, rnd };
}

function dumpStore(mem) {
  const o = {};
  for (const k of Object.keys(mem).sort()) { try { o[k] = JSON.parse(mem[k]); } catch (_) { o[k] = mem[k]; } }
  return o;
}
const clone = v => JSON.parse(JSON.stringify(v));

// ── 가짜 세이브 ──
const JAB = JSON.parse(fs.readFileSync(path.join(ROOT, 'godot', 'data', 'jab.json'), 'utf8')).JAB;
const GF = { C: 0.2, B: 0.5, A: 0.75, S: 0.92 };
function pot(cls, g) { const gr = JAB[cls].growth, f = GF[g]; const r = k => +(gr[k][0] + (gr[k][1] - gr[k][0]) * f).toFixed(2); return { hp: r('hp'), atk: r('atk'), def: r('def'), actionRec: 0.1 }; }
function mkChar(uid, cls, lv, g, extra) {
  const b = JAB[cls].base;
  return Object.assign({ uid, cls, nameId: uid, customName: 'C' + uid, lv, exp: 0, dead: false, hp: b.hp + lv * 3, atk: b.atk + lv, def: b.def, move: b.move, range: b.range,
    pot: pot(cls, g), actionRec: (JAB[cls].actionRec || 1) + 0.1, gender: uid % 2 ? 'm' : 'f' }, extra || {});
}
function parties(slots0) {
  const ps = [{ id: 1, slots: slots0 }];
  for (let i = 2; i <= 5; i++) ps.push({ id: i, slots: i === 2 ? [21, null, null, null, null] : [null, null, null, null, null] });
  return { parties: ps, activePartyId: 1, nextPartyId: 6 };
}
function sancSave() {
  const chars = [
    { uid: 100, cls: 'commander', nameId: null, customName: '리안', lv: 1, exp: 0, dead: false, hp: 95, atk: 12, def: 6, move: 2, range: 2,
      pot: { hp: 8.4, atk: 1.6, def: 0.6, actionRec: 0.12 }, actionRec: 1.22, gender: 'm', buffer: 2, setup: true },
    mkChar(1, 'warrior', 7, 'B'), mkChar(2, 'knight', 5, 'C'), mkChar(4, 'mage', 6, 'A'), mkChar(6, 'novice', 14, 'B'), mkChar(8, 'novice', 15, 'S'),
    mkChar(11, 'warrior', 3, 'C', { skillLv: { warrior_cleave: 2 } }), mkChar(12, 'warrior', 4, 'B', { skillLv: { warrior_powersmash: 3 } }),
    mkChar(13, 'warrior', 5, 'A', { skillLv: { warrior_powersmash: 10, warrior_cleave: 1 } }), mkChar(14, 'warrior', 8, 'S'),
    mkChar(15, 'warrior', 9, 'B', { dead: true, diedAt: 50 }), mkChar(21, 'knight', 2, 'C'), mkChar(22, 'knight', 6, 'B'),
    mkChar(41, 'mage', 4, 'A', { skillLv: { mage_freeze: 2 } }), mkChar(42, 'mage', 3, 'B'), mkChar(31, 'archer', 6, 'C', { dead: true, diedAt: 100 }),
    mkChar(7, 'assassin', 2, 'B', { dead: true, diedAt: 5 }), mkChar(9, 'summon_golem', 1, 'C', { dead: true, diedAt: 300 }),
  ];
  // 죽은 소환수(9)는 부활·승급 목록에서 빠져야 함
  return { game_roster: { chars, nextId: 101 }, game_parties: parties([1, 2, 4, 6, null]), game_save: { gold: 5000, cleared: [1, 2, 3] },
    game_soul: { stones: { warrior: 1, knight: 0 }, frags: { mage: 23, knight: 9 } } };
}

function makeInventory() {
  const w = makeWorld(COMMON, 777, {});
  const C = w.ctx;
  const tpl = id => C.equipTemplate(id);
  const items = [C.generateEquip(tpl('wpn_warrior'), 'rare'), C.generateEquip(tpl('plate_helm'), 'epic'), C.generateEquip(tpl('ring_power'), 'common'),
    C.generateEquip(tpl('wpn_mage'), 'legendary'), C.generateEquip(tpl('leather_cap'), 'uncommon'), C.generateEquip(tpl('chain_boots'), 'rare')];
  items[1].enchant = 'heat';
  items[3].enchantAtk = 'frost';
  return items;
}
function fullSave() {
  const s = sancSave();
  const items = makeInventory();
  const r = s.game_roster;
  const eq = { 1: { weapon: 0, helmet: 1 }, 4: { weapon: 3 }, 11: { ring: 2 } };
  for (const uid of Object.keys(eq)) {
    const ch = r.chars.find(c => c.uid === +uid);
    ch.equip = { weapon: null, offhand: null, helmet: null, armor: null, boots: null, necklace: null, earring: null, ring: null };
    for (const sl of Object.keys(eq[uid])) { const it = items[eq[uid][sl]]; ch.equip[sl] = it.eid; it.equipped = +uid; }
  }
  const inv = items.slice();
  inv.push({ type: 'rune', enchant: 'fire', rid: 1 }, { type: 'rune', enchant: 'fire', rid: 2 }, { type: 'rune', enchant: 'flame', rid: 3 },
    { type: 'rune', enchant: 'frost', rid: 4 }, { type: 'scroll', scrollCls: 'archer' }, { type: 'scroll', scrollCls: 'mage' },
    { type: 'scroll', scrollCls: 'nope' }, { id: 'mage_freeze', cls: 'mage', lv: 1 }, { id: 'warrior_powersmash', cls: 'warrior', lv: 1 },
    { id: 'knight_charge', cls: 'knight', lv: 1 }, { id: 'priest_purify', cls: 'priest', lv: 1 }, { type: 'potion', pid: 'pa', potionId: 'exp_s', exp: 50, icon: '🧪', quantity: 1 });
  s.game_inventory = inv;
  return s;
}

// ═══ 성소 ═══
function sancModel(w) {
  const C = w.ctx;
  const m = {};
  C._gold = C.loadGold();
  C.renderResurrect();
  const list = w.doc.getElementById('sanc-list');
  m.resurrect = { html: list.innerHTML, cards: list.children.map(el => ({ cls: el.className, html: el.innerHTML })) };
  C.renderPromote();
  m.promote = list.children.map(el => ({ cls: el.className, html: el.innerHTML }));
  m.sacrifices = {};
  for (const ch of C.getRoster().chars.filter(c => !c.dead && !c.cls.startsWith('summon_') && c.cls !== 'commander' && C.potGrade(c) !== 'S')) {
    const g = C.potGrade(ch);
    m.sacrifices[ch.uid] = C.getRoster().chars.filter(c => !c.dead && !c.cls.startsWith('summon_') && c.cls !== 'commander' && c.uid !== ch.uid && c.cls === ch.cls &&
      !C.isInParty(c.uid) && C.sacrificePoints(C.potGrade(c), g) > 0).map(c => [c.uid, C.sacrificePoints(C.potGrade(c), g)]);
  }
  C.renderRename();
  m.rename = list.children.map(el => /C(\d+)|리안/.exec(el.innerHTML) ? el.innerHTML : el.innerHTML);
  C.renderEnchant();
  m.enchant = list.children.map(el => ({ cls: el.className, eid: (/<eid:([^>]+)>/.exec(el.innerHTML) || [])[1] || null, html: el.innerHTML }));
  m.grades = {};
  for (const ch of C.getRoster().chars) if (JAB[ch.cls]) m.grades[ch.uid] = C.potGrade(ch);
  m.owned = C.Soul.owned();
  return m;
}

function sanctuaryCases() {
  const out = [];
  const base = fullSave();
  // 1) 목록만 (난수·저장 변화 없음)
  {
    const w = makeWorld(COMMON.concat(['js/sanctuary.js']), 801, base);
    out.push({ name: 'lists', seed: 801, store: base, model: sancModel(w), after: dumpStore(w.mem), calls: w.rnd.calls });
  }
  // 2) 차례로: 부활 · 무료 부활 · 영혼석 합치기 · 승급 2번 · 마법부여 · 개명
  {
    const w = makeWorld(COMMON.concat(['js/sanctuary.js']), 811, base);
    const C = w.ctx;
    const steps = [];
    const list = w.doc.getElementById('sanc-list');
    C._gold = C.loadGold();
    // 부활 (카드 단추 — 목록 순서: 죽은 시각 최근 순, 첫 칸은 무료 부활 카드)
    C.renderResurrect();
    const order = C.getRoster().chars.filter(c => c.dead && !c.cls.startsWith('summon_') && c.cls !== 'commander').sort((a, b) => (b.diedAt || 0) - (a.diedAt || 0)).map(c => c.uid);
    steps.push({ op: 'revive', uid: order[0], order: order.slice() });
    list.children[1].querySelector('.game-btn').onclick();
    // 무료 부활 → 고르기 창 → 7
    C.renderResurrect();
    const adBtn = list.children[0].querySelector('.sanc-ad-btn');
    steps.push({ op: 'ad', uid: 7, ready: !!adBtn.onclick });
    adBtn.onclick();
    w.doc.querySelectorAll('.pt-btn').find(b => +b.dataset.uid === 7).onclick();
    // 다시: 대기 중 → 단추 없음
    C.renderResurrect();
    steps.push({ op: 'ad_again', ready: !!list.children[0].querySelector('.sanc-ad-btn').onclick, html: list.children[0].innerHTML });
    // 영혼석 합치기 (마법사 조각 23 → 영혼석 2 + 조각 3)
    C.renderPromote();
    const box = list.children[0];
    steps.push({ op: 'combine', cls: 'mage' });
    box.querySelectorAll('.soul-combine').find(b => b.dataset.cls === 'mage').onclick();
    // 승급: 전사 12 (B→A, 영혼석 1) ← 제물 11(C, 1점) + 13(A, 4점)
    const promote = (target, sac) => {
      steps.push({ op: 'promote', target, sac, confirmsBefore: w.log.confirms.length, callsBefore: w.rnd.calls });
      C.showSacrificeModal(target);
      for (const u of sac) w.doc.querySelectorAll('#sac-list-inner .sac-btn').find(b => +b.dataset.uid === u).onclick({ stopPropagation() {} });
      const bt = w.doc.getElementById('modal-buttons');
      bt.children[1].onclick({ preventDefault() {}, stopPropagation() {} });
      steps[steps.length - 1].callsAfter = w.rnd.calls;
      steps[steps.length - 1].alert = w.log.alerts[w.log.alerts.length - 1];
    };
    promote(12, [11, 13]);
    // 마법사 42 (B→A, 영혼석 1) ← 41 (A 4점, 습득 스킬 mage_freeze 2)
    promote(42, [41]);
    // 기사 22 (B→A, 영혼석 1 필요 · 0 보유) → 영혼석 부족 (화면 단추가 꺼져 있어 바로 executePromote)
    steps.push({ op: 'promote_nosoul', target: 22, sac: [21] });
    C.executePromote(22, [21]);
    // 마법부여: 장비 0(전사 무기) ← 불 룬 (확인 창) · 같은 종류 · 룬 없음 · 다른 종류로 덮어쓰기 · 골드 부족
    C.renderEnchant();
    const encCard = eid => list.children.find(el => el.innerHTML.indexOf('<eid:' + eid + '>') >= 0);
    const inv0 = base.game_inventory;
    const clickRune = (eid, k) => { C.renderEnchant(); const el = encCard(eid); const b = el && el.querySelectorAll('.enc-opt:not([disabled])').find(x => x.dataset.k === k); steps.push({ op: 'enchant', eid, k, clickable: !!b }); if (b) b.onclick(); };
    clickRune(inv0[0].eid, 'fire');
    clickRune(inv0[0].eid, 'fire');       // 이미 같은 종류 → 단추 꺼짐
    clickRune(inv0[1].eid, 'fire');       // 투구(열기) ← 불 (덮어쓰기)
    clickRune(inv0[1].eid, 'fire');       // 룬 없음 → 꺼짐
    clickRune(inv0[3].eid, 'flame');      // 지팡이(공격 냉기) ← 화염 (공격 칸 덮어쓰기)
    steps.push({ op: 'apply_codes', codes: [C.Rune.apply('nope', 'fire'), C.Rune.apply(inv0[4].eid, 'frost')] });
    // 개명
    const rename = (uid, v) => { steps.push({ op: 'rename', uid, v }); C.showRenameModal(uid); w.doc.getElementById('rename-input').value = v; w.doc.getElementById('modal-buttons').children[1].onclick(); };
    rename(1, '  새 이름  ');
    rename(2, '   ');
    rename(4, 'Ab　');
    out.push({ name: 'ops', seed: 811, store: base, steps, after: dumpStore(w.mem), calls: w.rnd.calls, alerts: w.log.alerts, confirms: w.log.confirms.length, model: sancModel(w) });
  }
  // 3) 골드 부족 부활 · 마법부여 골드 부족 · 무료 부활 대기 중(저장된 시각)
  {
    const st = clone(base);
    st.game_save.gold = 40;
    st.game_sanc_ad_cooldown = String(NOW - 10 * 60 * 1000);
    const w = makeWorld(COMMON.concat(['js/sanctuary.js']), 821, st);
    const C = w.ctx;
    const list = w.doc.getElementById('sanc-list');
    C._gold = C.loadGold();
    C.renderResurrect();
    const card1 = list.children[1].innerHTML;
    const ad = list.children[0].innerHTML;
    const can = !!list.children[1].querySelector('.game-btn').onclick;
    list.children[1].querySelector('.game-btn').onclick();
    C.renderEnchant();
    const el = list.children.find(x => x.innerHTML.indexOf('<eid:' + base.game_inventory[2].eid + '>') >= 0);
    const b = el.querySelectorAll('.enc-opt:not([disabled])').find(x => x.dataset.k === 'fire');
    if (b) b.onclick();
    out.push({ name: 'poor', seed: 821, store: st, card1, ad, can, after: dumpStore(w.mem), calls: w.rnd.calls, alerts: w.log.alerts, confirms: w.log.confirms.length });
  }
  return out;
}

// ═══ 아카데미 ═══
function academyCases() {
  const out = [];
  const base = fullSave();
  {
    const w = makeWorld(COMMON.concat(['js/sprites.js', 'js/academy.js']), 901, base);
    const C = w.ctx;
    // 미리보기 기록 (웹은 확인 창에서 한 번, 실행에서 한 번 더 굴림)
    const previews = [];
    const orig = C.previewClassChange;
    C.previewClassChange = function (ch, cls) { const r = orig(ch, cls); previews.push({ r: clone(r), calls: w.rnd.calls }); return r; };
    C.renderAcademy();
    const list = w.doc.getElementById('academy-list');
    const cards = list.children.map(el => el.innerHTML);
    // 노비스 6 → 전직서(궁수)
    list.children[0].querySelector('.game-btn').onclick();
    const modal = w.doc.getElementById('modal-sub').innerHTML;
    const pick = w.doc.querySelectorAll('.scroll-select-btn').find(b => b.dataset.cls === 'archer');
    pick.onclick();
    const after1 = dumpStore(w.mem);
    // 스킬북: 목록 → 마법사 스킬북 → 대상 고르기 → 4 (mage_freeze 0 → 습득)
    C.renderSkillBooks();
    const sbl = w.doc.getElementById('skillbook-list');
    const books = sbl.children.map(el => el.innerHTML);
    const useBook = (bookId, uid) => {
      C.renderSkillBooks();
      const inv = C.loadInventory();
      const idxs = []; inv.forEach((b, i) => { if (!b.type && b.id && b.cls && b.lv !== undefined && JAB[b.cls]) idxs.push(i); });
      const at = idxs.findIndex(i => inv[i].id === bookId);
      sbl.children[at].querySelector('.game-btn').onclick();
      const targets = w.doc.querySelectorAll('.sb-target-btn').map(b => +b.dataset.uid);
      const b = w.doc.querySelectorAll('.sb-target-btn').find(x => +x.dataset.uid === uid);
      if (b) b.onclick();
      return targets;
    };
    const t1 = useBook('mage_freeze', 4);
    const t2 = useBook('warrior_powersmash', 1);
    out.push({ name: 'academy', seed: 901, store: base, cards, modal, previews, after1, books, targets: [t1, t2], after: dumpStore(w.mem), calls: w.rnd.calls, alerts: w.log.alerts, hrefs: w.log.hrefs });
  }
  {
    // 전직서 없음 → 상점 전직서 탭으로
    const st = clone(base);
    st.game_inventory = st.game_inventory.filter(x => x.type !== 'scroll');
    const w = makeWorld(COMMON.concat(['js/sprites.js', 'js/academy.js']), 902, st);
    w.ctx.renderAcademy();
    const list = w.doc.getElementById('academy-list');
    const card = list.children[0].innerHTML;
    list.children[0].querySelector('.game-btn').onclick();
    out.push({ name: 'noscroll', seed: 902, store: st, card, hrefs: w.log.hrefs, after: dumpStore(w.mem) });
  }
  return out;
}

// ═══ 도감·가이드: 글 조각 ═══
function tokens(html) {
  const out = [];
  const push = s => { const x = s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&').trim(); if (x) out.push(x); };
  let pos = 0;
  const re = /<[^>]*>/g; let m;
  while ((m = re.exec(html))) { push(html.slice(pos, m.index)); pos = m.index + m[0].length; }
  push(html.slice(pos));
  return out;
}
function inlineScript(file) {
  const h = fs.readFileSync(path.join(ROOT, file), 'utf8');
  const m = h.match(/<script>\n([\s\S]*?)<\/script>/);
  return m[1].replace(/document\.addEventListener\('DOMContentLoaded'[\s\S]*$/, '');
}
function codexCases() {
  const out = {};
  for (const lang of ['ko', 'en']) {
    const pack = PACK(lang);
    const T = realT(pack);
    const asked = [];
    const tfn = (k, p) => { asked.push(k); return T(k, p); };
    const r = {};
    // 도감
    {
      const w = makeWorld(CODEX.concat(['<inline:' + inlineScript('compendium.html')]), 1, {}, tfn);
      const C = w.ctx;
      const $ = id => w.doc.getElementById(id).innerHTML;
      C.renderClasses(); C.renderCons(); C.renderStages();
      const TT = k => T('codex.' + k);
      r.comp = {
        hero: [TT('c.title'), TT('c.sub')].concat(...[[12, TT('c.st_classes')], [C.EQUIP_DB.length, TT('c.st_gear')], [Object.keys(C.LEGENDS).length, TT('c.st_legend')], [C.STAGES.length, TT('c.st_stages')]].map(a => [String(a[0]), a[1]])),
        cls: [TT('c.s_cls'), '12 classes'].concat(tokens(TT('c.cls_p')), tokens($('cls-grid')), [TT('c.s_res'), 'resources'], tokens($('res-cards'))),
        cons: tokens($('cons-body')), stage: tokens($('stage-body')), gear: {}, sheets: {},
        foot: tokens(TT('c.foot')), tabs: ['cls', 'gear', 'cons', 'stage'].map(k => TT('c.tab_' + k)), search: TT('c.search'),
        title: (v => v && v !== 'nav.compendium' ? v : TT('c.title'))(T('nav.compendium')),
      };
      for (const f of C.GEAR_FILTERS) { C.gearFilter = f; vm.runInContext('gearFilter = ' + JSON.stringify(f), C); C.renderGear(); r.comp.gear[f] = tokens($('gear-filter')).concat(tokens($('gear-body'))); }
      for (const cls of C.PLAYER_CLASSES) { C.openClass(cls); r.comp.sheets[cls] = tokens($('sheet-body')); }
    }
    // 가이드
    {
      const w = makeWorld(CODEX.concat(['<inline:' + inlineScript('guide.html')]), 1, {}, tfn);
      const C = w.ctx;
      C.build();
      const body = w.doc.getElementById('cx-body').innerHTML;
      const parts = body.split(/(?=<div class="cx-panel)/);
      r.guide = { panels: {}, foot: null };
      for (const p of parts) {
        const m = /id="p-([a-z]+)"/.exec(p);
        let h = p;
        const fi = h.indexOf('<div class="cx-foot">');
        if (fi >= 0) { r.guide.foot = tokens(h.slice(fi)); h = h.slice(0, fi); }
        r.guide.panels[m[1]] = tokens(h);
      }
      const TT = k => T('codex.' + k);
      r.guide.hero = [TT('g.title'), TT('g.sub'), '100', TT('c.st_stages'), '5', TT('c.st_party'), '12', TT('c.st_classes')];
      r.guide.tabs = ['start', 'grow', 'gear', 'battle', 'map', 'route', 'story'].map(k => TT('g.tab_' + k));
      r.guide.title = (v => v && v !== 'nav.guide' ? v : TT('g.title'))(T('nav.guide'));
    }
    // 웹이 조회한 키 중 없는 키 (Godot 은 0 이어야 함 — 같은 화면 글을 있는 키만으로)
    const res = (o, p) => p.split('.').reduce((a, k) => a && a[k], o);
    r.missing = [...new Set(asked.filter(k => typeof res(pack, k) !== 'string' && !Array.isArray(res(pack, k))))].sort();
    out[lang] = r;
  }
  return out;
}

// ═══ V8 정렬 ═══
function v8Cases() {
  const out = [];
  for (const n of [64, 65, 100, 128, 200, 257, 513, 700]) {
    for (const kind of ['rand', 'asc', 'desc', 'mixed', 'dup']) {
      const r = mulberry(n * 31 + kind.length); let calls = 0;
      const arr = [...Array(n).keys()];
      let cmp;
      if (kind === 'rand') cmp = () => { calls++; return r() - 0.5; };
      else if (kind === 'asc') { for (let i = 0; i < n; i++) arr[i] = Math.floor(r() * 1000); cmp = (a, b) => { calls++; return a - b; }; }
      else if (kind === 'desc') cmp = (a, b) => { calls++; return b - a; };
      else if (kind === 'mixed') { for (let i = 0; i < n; i++) arr[i] = (i % 37 < 20) ? i : n - i; cmp = (a, b) => { calls++; return a - b; }; }
      else { for (let i = 0; i < n; i++) arr[i] = Math.floor(r() * 5); cmp = (a, b) => { calls++; return a - b; }; }
      const input = arr.slice();
      const res = arr.sort(cmp);
      out.push({ n, kind, seed: n * 31 + kind.length, input, out: res, calls });
    }
  }
  return out;
}

// ── 왕복: Godot 이 쓴 세이브를 웹 성소·아카데미 화면과 로비 점검이 오류 없이 읽는지 ──
function roundtrip(file) {
  const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
  const errs = [];
  let n = 0;
  const run = (what, fn) => { n++; try { fn(); } catch (e) { errs.push(what + ': ' + (e && e.message)); } };
  const ws = makeWorld(COMMON.concat(['js/sanctuary.js']), 9, raw);
  run('sanctuary.gold', () => { ws.ctx._gold = ws.ctx.loadGold(); });
  for (const tab of ['resurrect', 'promote', 'rename', 'enchant']) run('sanctuary.' + tab, () => ws.ctx.switchTab(tab));
  for (const ch of ws.ctx.getRoster().chars) {
    if (!ch || ch.dead || ch.cls === 'commander' || String(ch.cls).startsWith('summon_')) continue;
    run('sanctuary.sacrifice.' + ch.uid, () => ws.ctx.showSacrificeModal(ch.uid));
    run('sanctuary.rename.' + ch.uid, () => ws.ctx.showRenameModal(ch.uid));
  }
  const wa = makeWorld(COMMON.concat(['js/sprites.js', 'js/academy.js']), 9, raw);
  for (const tab of ['classchange', 'skillbook']) run('academy.' + tab, () => wa.ctx.switchTab(tab));
  for (const ch of wa.ctx.getRoster().chars.filter(c => c && !c.dead && c.cls === 'novice')) run('academy.scroll.' + ch.uid, () => wa.ctx.showScrollSelectModal(ch.uid));
  wa.ctx.loadInventory().forEach((b, i) => { if (b && !b.type && b.id && b.cls) run('academy.book.' + i, () => wa.ctx.showSkillBookTargets(i)); });
  const wl = makeWorld(COMMON.concat(['data/stages.js', 'js/logic/stages.js', 'js/index.js']), 9, raw);
  let ok = null;
  run('lobby.validate', () => { ok = wl.ctx.validateAndRepairGameData(); });
  if (ok === false) errs.push('lobby.validate: 웹 점검이 세이브를 잘못된 것으로 봄');
  console.log(JSON.stringify({ ok: errs.length === 0, checks: n, errors: errs }));
}
if (process.argv.includes('--roundtrip')) { roundtrip(process.argv[process.argv.indexOf('--roundtrip') + 1]); process.exit(0); }

const result = {
  note: 'node tools/outer-4b2-expect.js 가 웹 코드를 그대로 실행해 만든 정답 — 손으로 고치지 말 것 (godot/tests/check_outer_4b2.gd 가 비교)',
  now: NOW, sanctuary: sanctuaryCases(), academy: academyCases(), codex: codexCases(), v8: v8Cases(),
};
const text = JSON.stringify(result, null, 1) + '\n';
if (CHECK) {
  const cur = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : '';
  if (cur !== text) { console.log('[outer-4b2-expect] 정답 파일이 웹 코드와 다릅니다 — node tools/outer-4b2-expect.js 로 다시 만드세요'); process.exit(1); }
  console.log('[outer-4b2-expect] 같음');
} else {
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, text);
  console.log('[outer-4b2-expect] 썼음: ' + path.relative(ROOT, OUT) + ' (성소 ' + result.sanctuary.length + ' · 아카데미 ' + result.academy.length + ' · 도감·가이드 ' + Object.keys(result.codex).length + '개 언어 · V8 정렬 ' + result.v8.length + ')');
}
