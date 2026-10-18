#!/usr/bin/env node
// ═══════════════════════════════════════════
//  tools/outer-4b1-expect.js — Godot 4b-1(편성 화면의 장비·소모품·강화 탭, 상점) 규칙 시험의 정답을 웹 코드로 만든다
//
//  웹 파일(shop.html · party-select.html 과 같은 순서의 js/common/*, data/*, js/logic/*, js/skills.js, js/shop.js, js/party-select.js)을
//  Node vm 안에서 그대로 실행하고, 가짜 세이브에서 나온 결과를 godot/tests/fixtures/outer_4b1_web.json 에 쓴다. 웹 파일은 고치지 않는다.
//   - Math.random 은 mulberry32(씨앗) — Godot rng.gd 와 비트까지 같음, Date.now 는 고정 시각 → Godot 도 같은 씨앗·시각으로 돌려 저장값을 비교
//   - 상점: genShop · loadShop(1시간 지남/안 지남) · 각 카드 단추의 onclick(확인 창은 '확인'으로) 차례대로 → 저장소 전체
//   - 장비: equipItem · unequipItem · sellEquip, 장비 창 목록(renderInventoryInModal)·카드(renderChars)의 순서·단추·옵션 줄
//   - 강화: renderEnhanceList 순서·숫자, 강화 확인 창 숫자, enhanceItem 여러 번(보호 주문서 포함)·수리·분해 → 결과·저장소
//   - 아이템 탭: renderItemTab 묶음, 물약 사용 대상·사용 결과
//  화면(DOM)은 class·innerHTML 만 기록하는 가짜. 그림 함수는 표식 글(<eid:…>)을 돌려줘 카드가 어느 장비인지 알 수 있게 함.
//  번역 t() 는 키 + JSON(자리표시자), character.names 만 한국어 팩의 실제 배열.
//
//  사용: node tools/legacy-web/outer-4b1-expect.js            (다시 만들기)
//        node tools/legacy-web/outer-4b1-expect.js --check    (쓰지 않고 지금 파일과 같은지만 — 다르면 종료 코드 1)
// ═══════════════════════════════════════════
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.resolve(__dirname, '..', '..');   // tools/legacy-web/ → 저장소 맨 위
// (2026-10-18 보관) 정답은 고정된 기준 — --check 는 고정 파일과 비교만, 다시 만들면 tools/_work/legacy-web/ 에 씀 (godot 쪽 기준은 덮어쓰지 않음)
const FROZEN = path.join(ROOT, 'godot', 'tests', 'fixtures', 'outer_4b1_web.json');
const OUT = process.argv.includes('--check') ? FROZEN : path.join(ROOT, 'tools', '_work', 'legacy-web', 'fixtures', 'outer_4b1_web.json');
const CHECK = process.argv.includes('--check');
const NOW = 1791990000000;   // 고정 시각 (Godot 시험도 같은 값)
const NAMES = JSON.parse(fs.readFileSync(path.join(ROOT, 'godot', 'tests', 'baseline', 'data', 'lang', 'ko.json'), 'utf8')).character.names;

const COMMON = ['js/common/store.js', 'data/jab.js', 'js/common/constants.js', 'js/common/storage.js', 'js/common/character.js',
  'js/common/soul.js', 'js/common/daily.js', 'data/hazards.js', 'js/logic/hazards.js', 'js/common/render.js', 'data/equip.js', 'js/logic/equip.js',
  'data/gear.js', 'js/logic/gear.js', 'js/skills.js'];

function hoistTopLevel(src) { return src.replace(/^(const|let)(\s)/gm, 'var$2'); }

function mulberry(seed) {
  let a = seed >>> 0;
  const f = () => { a = (a + 0x6D2B79F5) | 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  const g = () => { g.calls++; return f(); };
  g.calls = 0;
  return g;
}

// ── 가짜 DOM ──
function makeDoc() {
  const byId = {};
  function el(tag) {
    let html = '';
    const sel = {};
    const e = {
      tag, className: '', textContent: '', children: [], style: {}, dataset: {}, onclick: null, type: '', title: '',
      get innerHTML() { return html; }, set innerHTML(v) { html = String(v); if (html === '') this.children.length = 0; for (const k in sel) delete sel[k]; },
      classList: { add() {}, remove() {}, toggle() {}, contains() { return false; } },
      appendChild(c) { this.children.push(c); return c; }, insertBefore(c) { this.children.unshift(c); return c; },
      remove() {}, setAttribute() {}, getAttribute() { return null; }, addEventListener() {}, insertAdjacentHTML() {},
      querySelector(s) { if (!sel[s]) sel[s] = el('stub'); return sel[s]; },
      querySelectorAll(s) {
        if (!sel['all:' + s]) {
          const out = [];
          if (s === '.legend-btn') { const re = /data-id="([^"]+)"/g; let m; while ((m = re.exec(html))) { const b = el('button'); b.dataset.id = m[1]; out.push(b); } }
          sel['all:' + s] = out;
        }
        return sel['all:' + s];
      },
    };
    return e;
  }
  const ptBtns = [];
  const doc = {
    _byId: byId, ptBtns,
    getElementById(id) { if (!byId[id]) byId[id] = el('div'); return byId[id]; },
    querySelector() { return null; },
    querySelectorAll(s) {
      if (s === '.pt-btn') {
        ptBtns.length = 0;
        const re = /data-uid="(\d+)"/g; let m; const h = doc.getElementById('modal-sub').innerHTML;
        while ((m = re.exec(h))) { const b = el('div'); b.dataset.uid = m[1]; ptBtns.push(b); }
        return ptBtns;
      }
      return [];
    },
    createElement(tag) { return el(tag); },
    createTextNode(t) { const e = el('#text'); e.textContent = String(t); return e; },
    addEventListener() {},
    body: el('body'),
    documentElement: { lang: 'ko' },
  };
  return doc;
}

function makeWorld(page, seed, seedStore) {
  const mem = {};
  for (const k of Object.keys(seedStore || {})) mem[k] = typeof seedStore[k] === 'string' ? seedStore[k] : JSON.stringify(seedStore[k]);
  const doc = makeDoc();
  class FakeDate extends Date {
    constructor(...a) { if (a.length) super(...a); else super(NOW); }
    static now() { return NOW; }
  }
  const rnd = mulberry(seed);
  const log = { alerts: [], confirms: [] };
  const t = (k, p) => (k === 'character.names' ? NAMES : k + (p ? JSON.stringify(p) : ''));
  const sandbox = {
    console: { log() {}, warn() {}, error() {} }, document: doc, location: { href: page, search: '' }, navigator: { language: 'ko' },
    setTimeout(fn) { fn(); }, clearTimeout() {}, setInterval() {}, clearInterval() {}, URLSearchParams,
    Math: Object.create(Math, { random: { value: rnd } }), Date: FakeDate, JSON, Object, Array, Set, Map, Number, String, Boolean, parseInt, parseFloat, isNaN, Promise,
    t, _i18nData: {}, _resolve: () => undefined,
    showAlert(m) { log.alerts.push(m); }, showModal() {}, closeModal() {},
    showConfirm(m, yes) { log.confirms.push(m); if (yes) yes(); },
    renderBottomNav() {}, hideSplash() {}, i18nInit: async () => {},
  };
  sandbox.window = sandbox;
  const ctx = vm.createContext(sandbox);
  const files = COMMON.concat(page === 'shop' ? ['js/shop.js'] : page === 'lobby' ? ['data/stages.js', 'js/logic/stages.js', 'js/index.js'] : ['js/party-select.js']);
  for (const f of files) vm.runInContext(hoistTopLevel(fs.readFileSync(path.join(ROOT, f), 'utf8')), ctx, { filename: f });
  // 그림 함수 → 표식 (카드가 어느 장비인지)
  vm.runInContext("equipIcon = function(it){ return '<eid:' + it.eid + '>'; }; clsIcon = function(){ return ''; }; charSprite = function(){ return ''; };" +
    "skillIcon = function(){ return ''; }; iconOr = function(){ return ''; }; itemIcon = function(){ return ''; }; runeIcon = function(){ return ''; };", ctx);
  ctx.Store.useBackend({
    getItem: k => Object.prototype.hasOwnProperty.call(mem, k) ? mem[k] : null,
    setItem: (k, v) => { mem[k] = String(v); }, removeItem: k => { delete mem[k]; }, keys: () => Object.keys(mem), clear: () => { for (const k in mem) delete mem[k]; },
  });
  ctx.eval = code => vm.runInContext(code, ctx);
  return { ctx, mem, doc, log, rnd };
}

function dumpStore(mem) {
  const o = {};
  for (const k of Object.keys(mem).sort()) { try { o[k] = JSON.parse(mem[k]); } catch (_) { o[k] = mem[k]; } }
  return o;
}

// ── 가짜 세이브 ──
function mkChar(uid, cls, lv, extra) {
  const J = { warrior: [100, 26, 9, 3, 1], knight: [120, 18, 14, 3, 1], archer: [70, 24, 5, 3, 4], mage: [65, 28, 4, 3, 3], priest: [75, 14, 6, 3, 2], novice: [85, 22, 8, 3, 1], assassin: [70, 26, 5, 4, 1] }[cls];
  return Object.assign({ uid, cls, nameId: uid, customName: 'C' + uid, lv, exp: 0, dead: false, hp: J[0], atk: J[1], def: J[2], move: J[3], range: J[4],
    pot: { hp: 8, atk: 2.5, def: 1.5, actionRec: 0.1 }, actionRec: 1.1, gender: uid % 2 ? 'm' : 'f' }, extra || {});
}
function baseRoster() {
  return { chars: [
    { uid: 100, cls: 'commander', nameId: null, customName: '리안', lv: 1, exp: 0, dead: false, hp: 95, atk: 12, def: 6, move: 2, range: 2,
      pot: { hp: 8.4, atk: 1.6, def: 0.6, actionRec: 0.12 }, actionRec: 1.22, gender: 'm', buffer: 2, setup: true },
    mkChar(1, 'warrior', 7), mkChar(2, 'knight', 5), mkChar(3, 'archer', 9), mkChar(4, 'mage', 3), mkChar(5, 'priest', 4), mkChar(6, 'novice', 14),
    mkChar(7, 'assassin', 2, { dead: true, diedAt: 5 }), mkChar(8, 'novice', 15) ], nextId: 101 };
}
function parties(slots0) {
  const ps = [{ id: 1, slots: slots0 }];
  for (let i = 2; i <= 5; i++) ps.push({ id: i, slots: [null, null, null, null, null] });
  return { parties: ps, activePartyId: 1, nextPartyId: 6 };
}

// 장비 인벤토리: 웹 생성 함수로 (씨앗 고정) — 정답 파일의 시작 세이브에 그대로 들어가므로 Godot 은 만들지 않고 읽기만
function makeInventory() {
  const w = makeWorld('party', 777, {});
  const C = w.ctx;
  const tpl = id => C.equipTemplate(id);
  const items = [
    C.generateEquip(tpl('wpn_warrior'), 'rare'), C.generateEquip(tpl('wpn_warrior'), 'epic'), C.generateEquip(tpl('shield'), 'uncommon'),
    C.generateEquip(tpl('plate_helm'), 'common'), C.generateEquip(tpl('plate_helm'), 'rare'), C.generateEquip(tpl('plate_armor'), 'legendary'),
    C.generateEquip(tpl('wpn_knight'), 'uncommon'), C.generateEquip(tpl('wpn_archer'), 'common'), C.generateEquip(tpl('leather_cap'), 'epic'),
    C.generateEquip(tpl('ring_power'), 'rare'), C.generateEquip(tpl('necklace_power'), 'common'), C.generateEquip(tpl('earring_power'), 'uncommon'),
    C.generateEquip(tpl('buckler'), 'common'), C.generateEquip(tpl('tome'), 'rare'), C.generateEquip(tpl('wpn_mage'), 'epic'),
    C.Gear.makeLegend('blood_oath'), C.Gear.makeSetPiece('knight', 'armor', 'rare'), C.Gear.makeSetPiece('knight', 'boots', 'epic'),
    C.generateEquip(tpl('chain_boots'), 'rare'),
  ];
  items[4].enhanceLv = 6; items[4].eOpts = { 1: { id: 'hp_pct', v: 3 } }; items[9].enhanceLv = 3; items[13].enhanceLv = 9; items[13].enhanceBonus = 6;
  items[14].enhanceLv = 10; items[18].broken = true; items[18].enhanceLv = 4; items[8].enhanceLv = 2;
  // 장착: 전사(1) ← 희귀 전사 무기 · 일반 판금 투구 · 힘 목걸이 / 기사(2) ← 기사 무기 · 방패 · 세트 갑옷 / 마법사(4) ← 마법서
  const eq = { 1: { weapon: 0, helmet: 3, necklace: 10 }, 2: { weapon: 6, offhand: 2, armor: 16 }, 4: { offhand: 13 } };
  return { items, eq };
}

function equipSave() {
  const { items, eq } = makeInventory();
  const r = baseRoster();
  for (const uid of Object.keys(eq)) {
    const ch = r.chars.find(c => c.uid === +uid);
    ch.equip = { weapon: null, offhand: null, helmet: null, armor: null, boots: null, necklace: null, earring: null, ring: null };
    for (const s of Object.keys(eq[uid])) { const it = items[eq[uid][s]]; ch.equip[s] = it.eid; it.equipped = +uid; }
  }
  const inv = items.slice();
  inv.push({ type: 'potion', pid: 'pot_a', potionId: 'exp_m', exp: 150, icon: '⚗️', quantity: 1 }, { type: 'potion', pid: 'pot_b', potionId: 'exp_s', exp: 50, icon: '🧪', quantity: 1 },
    { type: 'siege', sid: 's1', siegeId: 'siege_bomb', icon: '💣', quantity: 1 }, { type: 'potion', pid: 'pot_c', potionId: 'exp_m', exp: 150, icon: '⚗️', quantity: 1 },
    { type: 'battle_potion', pid: 'bp1', potionId: 'potion_heal', icon: '💊', quantity: 1 }, { type: 'siege', sid: 's2', siegeId: 'siege_ladder', icon: '🪜', quantity: 1 },
    { type: 'potion', pid: 'pot_d', potionId: 'exp_l', exp: 400, icon: '🏐', quantity: 1 }, { type: 'siege', sid: 's3', siegeId: 'siege_bomb', icon: '💣', quantity: 1 },
    { type: 'rune', enchant: 'fire', rid: 1 }, { id: 'warrior_cleave', cls: 'warrior', lv: 1 });
  return { game_roster: r, game_inventory: inv, game_parties: parties([1, 2, 3, 4, 5]), game_save: { gold: 3000, cleared: [1, 2, 3] },
    game_mats: { stone: 12, protect: 1, shard: 2 } };
}

// ── 카드 읽기 ──
function eidOf(h) { const m = /<eid:([^>]+)>/.exec(h || ''); return m ? m[1] : null; }
function btns(h) { const out = []; const re = /class="eq-inv-btn (eq-[a-z]+-btn)"/g; let m; while ((m = re.exec(h))) out.push(m[1].replace(/^eq-|-btn$/g, '')); return out; }
function gearLines(h) { const out = []; const re = /<div class="gear-line gl-([a-z]+)">([\s\S]*?)<\/div>/g; let m; while ((m = re.exec(h))) out.push([m[1], m[2]]); return out; }
function between(h, a, b) { const i = h.indexOf(a); if (i < 0) return null; const j = h.indexOf(b, i + a.length); return h.slice(i + a.length, j); }

// ═══ 상점 ═══
function shopCases() {
  const out = [];
  const roster = baseRoster();
  // 1) 새 상점 · 2) 1시간 지나 갱신 · 3) 안 지남
  const w1 = makeWorld('shop', 101, { game_roster: roster, game_save: { gold: 100000 } });
  w1.ctx.loadShop();
  const fresh = JSON.parse(w1.mem.game_shop);
  out.push({ name: 'fresh', seed: 101, store: { game_roster: roster, game_save: { gold: 100000 } }, after: dumpStore(w1.mem), calls: w1.rnd.calls });
  const old = JSON.parse(JSON.stringify(fresh)); old.ts = NOW - 3600001; old.items[0].sold = true; old.items[old.items.length - 1].sold = true;
  for (const [name, shop] of [['refresh', old], ['no_refresh', Object.assign({}, fresh, { ts: NOW - 1000 })], ['ts_string', Object.assign({}, fresh, { ts: 'x' })]]) {
    const st = { game_roster: roster, game_save: { gold: 5 }, game_shop: shop };
    const w = makeWorld('shop', 202, st);
    w.ctx.loadShop();
    w.ctx._currentTab = 'mercenary';
    out.push({ name, seed: 202, store: st, after: dumpStore(w.mem), shopData: JSON.parse(JSON.stringify(w.ctx._shopData)), calls: w.rnd.calls, timer: (w.ctx.renderShop(), w.doc.getElementById('shop-timer').innerHTML) });
  }
  // 4) 차례로 사기 (각 카드 단추의 onclick, 확인 창은 '확인')
  const st4 = { game_roster: roster, game_save: { gold: 30000, cleared: [1] }, game_shop: fresh, game_mats: { shard: 6 }, game_gacha_pity: '98', game_soul: { stones: { mage: 1 }, frags: {} } };
  const w4 = makeWorld('shop', 303, st4);
  const C = w4.ctx;
  C._gold = C.loadGold(); C.loadShop();
  const steps = [];
  const click = (fn, arg) => { const list = C.document.createElement('div'); C[fn](arg, list); const el = list.children[list.children.length - 1]; const b = el.querySelector('.shop-btn'); if (b.onclick) b.onclick(); };
  const idxOf = (ty, k) => C._shopData.items.findIndex(it => (it.type || 'char') === ty && !it.sold && (k == null || it.potionId === k || it.siegeId === k));
  const doStep = (label, idx, fn) => { steps.push({ label, idx }); if (idx >= 0) click(fn, C._shopData.items[idx]); };
  doStep('char', idxOf('char'), 'renderCharCard');
  doStep('potion_m', idxOf('potion', 'exp_m'), 'renderPotionCard');
  doStep('potion_m2', idxOf('potion', 'exp_m'), 'renderPotionCard');
  doStep('battle_heal', idxOf('battle_potion', 'potion_heal'), 'renderBattlePotionCard');
  doStep('siege_bomb', idxOf('siege', 'siege_bomb'), 'renderSiegeCard');
  doStep('skillbook', idxOf('skillbook'), 'renderSkillBookCard');
  doStep('soul', idxOf('soulstone'), 'renderSoulCard');
  const sc = idxOf('scroll'); steps.push({ label: 'scroll', idx: sc });
  { const list = C.document.createElement('div'); C.renderScrollShop(list); const order = C._shopData.items.map((it, i) => [it, i]).filter(p => p[0].type === 'scroll');
    const el = list.children[1 + order.findIndex(p => p[1] === sc)]; el.querySelector('.shop-btn').onclick(); }
  steps.push({ label: 'rune' }); { const list = C.document.createElement('div'); C.renderRuneGacha(list); list.children[0].querySelector('.shop-btn').onclick(); }
  const gacha = (label, child) => { steps.push({ label }); const list = C.document.createElement('div'); C.renderGacha(list); const b = list.children[child].querySelector('.gacha-btn'); if (b.onclick) b.onclick(); };
  gacha('gacha1_pity', 3);   // 천장 99 → 전설
  gacha('gacha10', 4);
  gacha('stone', 6);
  gacha('protect', 7);
  steps.push({ label: 'legend', id: 'dawn' });
  { const list = C.document.createElement('div'); C.renderGacha(list); const ex = list.children[8]; const b = ex.querySelectorAll('.legend-btn').find(x => x.dataset.id === 'dawn'); b.onclick(); }
  doStep('char2', idxOf('char'), 'renderCharCard');
  out.push({ name: 'buy_all', seed: 303, store: st4, steps, after: dumpStore(w4.mem), calls: w4.rnd.calls, alerts: w4.log.alerts.length });
  // 5) 골드 부족 · 이미 산 것 · 조각 부족
  const st5 = { game_roster: roster, game_save: { gold: 350 }, game_shop: fresh, game_mats: { shard: 2 } };
  const w5 = makeWorld('shop', 404, st5);
  const C5 = w5.ctx; C5._gold = C5.loadGold(); C5.loadShop();
  const s5 = [];
  const click5 = (fn, idx) => { s5.push({ fn, idx }); const list = C5.document.createElement('div'); C5[fn](C5._shopData.items[idx], list); const b = list.children[0].querySelector('.shop-btn'); if (b.onclick) b.onclick(); };
  click5('renderCharCard', C5._shopData.items.findIndex(it => it.type === 'char'));
  click5('renderPotionCard', C5._shopData.items.findIndex(it => it.type === 'potion' && it.potionId === 'exp_s'));
  click5('renderSiegeCard', C5._shopData.items.findIndex(it => it.type === 'siege' && it.siegeId === 'siege_ladder'));
  click5('renderSiegeCard', C5._shopData.items.findIndex(it => it.type === 'siege' && it.siegeId === 'siege_bridge'));
  { s5.push({ fn: 'gacha1' }); const list = C5.document.createElement('div'); C5.renderGacha(list); const b = list.children[3].querySelector('.gacha-btn'); if (b.onclick) b.onclick(); }
  { s5.push({ fn: 'legend' }); const list = C5.document.createElement('div'); C5.renderGacha(list); const b = list.children[8].querySelectorAll('.legend-btn')[0]; b.onclick(); }
  out.push({ name: 'poor', seed: 404, store: st5, steps: s5, after: dumpStore(w5.mem), calls: w5.rnd.calls });
  return out;
}

// ═══ 장비 · 강화 · 아이템 ═══
function equipModel(w, uids) {
  const C = w.ctx;
  const res = { modal: {}, cards: [], bonus: {} };
  for (const uid of uids) {
    for (const f of ['all', 'weapon', 'armor', 'accessory']) {
      C._invFilter = f; C._selUid = uid;
      const ch = C.getRoster().chars.find(c => c.uid === uid); C.ensureEquipSlots(ch);
      C.renderInventoryInModal(ch);
      res.modal[uid + ':' + f] = w.doc.getElementById('eq-inv-list').children.map(card => ({ eid: eidOf(card.innerHTML), cls: card.className, btns: btns(card.innerHTML),
        stats: between(card.innerHTML, '<span class="eq-inv-stats">', '</span>'), lines: gearLines(card.innerHTML) }));
    }
    res.bonus[uid] = JSON.parse(JSON.stringify(C.calcEquipBonus(C.getRoster().chars.find(c => c.uid === uid))));
  }
  for (const f of ['all', 'group_melee', 'group_ranged', 'group_support', 'group_beginner']) {
    C._eqFilter = f; C._selUid = null; C.renderChars();
    res.cards.push({ filter: f, cards: w.doc.getElementById('eq-chars').children.map(card => ({ name: between(card.innerHTML, '<div class="unit-card-name">', '</div>'),
      party: /party-member/.test(card.className), slots: (card.innerHTML.match(/class="unit-card-equip-slot[^"]*"/g) || []).map(s => s.slice(7, -1)) })) });
  }
  return res;
}

function equipCases() {
  const out = [];
  const base = equipSave();
  const eid = i => base.game_inventory[i].eid;
  // 장착·해제·판매 차례
  const w = makeWorld('party', 505, base);
  const C = w.ctx;
  C.init && 0;
  C._gold = C.loadGold();   // switchPageTab('equip') 와 같음
  const before = equipModel(w, [1, 2, 3, 4, 6]);
  const ops = [
    ['equip', 1, eid(1)],         // 더 좋은 전사 무기로 교체 (두손)
    ['equip', 2, eid(4)],         // 기사 ← 희귀 판금 투구
    ['equip', 1, eid(5)],         // 전사 ← 전설 판금 갑옷
    ['unequip', 2, 'offhand'],
    ['equip', 4, eid(14)],        // 마법사 ← 두손 지팡이 → 마법서 빠짐
    ['equip', 3, eid(18)],        // 파손 장비 (웹 equipItem 자체는 막지 않음 — 화면 단추가 없음)
    ['sell', null, eid(7)],       // 궁수 무기 판매
    ['sell', null, eid(0)],       // 판 적 없는 장착 해제된 장비 (교체로 빠진 것)
    ['sell', null, eid(16)],      // 장착 중 → 못 팜
    ['unequip', 1, 'boots'],      // 빈 칸
    ['equip', 6, eid(12)],        // 노비스 ← 버클러 (직업 제한 — 웹 equipItem 은 검사 안 함)
  ];
  for (const op of ops) {
    if (op[0] === 'equip') C.equipItem(op[1], op[2]);
    else if (op[0] === 'unequip') C.unequipItem(op[1], op[2]);
    else C.sellEquip(op[2]);
  }
  const after = equipModel(w, [1, 2, 3, 4, 6]);
  const canEq = [];
  const inv = C.loadInventory();
  for (const uid of [1, 2, 3, 4, 5, 6]) {
    const ch = C.getRoster().chars.find(c => c.uid === uid);
    canEq.push(inv.filter(x => x.type === 'equip').map(x => C.canEquip(ch, x) ? 1 : 0));
  }
  out.push({ name: 'equip_ops', seed: 505, store: base, ops, before, after, canEquip: canEq, afterStore: dumpStore(w.mem), confirms: w.log.confirms.length, calls: w.rnd.calls });
  return out;
}

function enhanceListModel(w) {
  w.ctx.renderEnhanceList();
  const h = w.doc.getElementById('enhance-list').innerHTML;
  const cut = h.indexOf('enh-broken-title');
  const read = s => { const out = []; const re = /<div class="enhance-card[^"]*"[\s\S]*?(?=<div class="enhance-card|<div class="enh-broken-title|$)/g; let m;
    while ((m = re.exec(s))) { const c = m[0]; out.push({ eid: eidOf(c), level: between(c, '<div class="enhance-level">', '</div>'),
      rc: (/enhance-rate-cost [a-z-]+">([^<]*)</.exec(c) || [])[1] || null, who: between(c, '<div class="enhance-stats-current">', '</div>') }); }
    return out; };
  return { ok: read(cut < 0 ? h : h.slice(0, cut)), broken: cut < 0 ? [] : read(h.slice(cut)), mats: between(h, '<div class="enh-mats">', '</div>') };
}

function enhanceCases() {
  const out = [];
  const base = equipSave();
  const w = makeWorld('party', 606, base);
  const C = w.ctx;
  const list0 = enhanceListModel(w);
  // 확인 창 숫자
  const previews = {};
  for (const it of base.game_inventory.filter(x => x.type === 'equip')) {
    C._enhProtect = false; w.doc.getElementById('enhance-modal-overlay').innerHTML = ''; C.showEnhanceConfirmModal(it.eid);
    const h = w.doc.getElementById('enhance-modal-overlay').innerHTML;
    previews[it.eid] = { title: between(h, '<div class="enhance-confirm-value" style="color:', '</div>'), gain: between(h, 'font-weight:700;">', '</div>'),
      band: (/gear\.enh_opt_chance\{"p":(\d+)\}/.exec(h) || [])[1] || null, milestone: (/gear\.enh_milestone_(\d+)/.exec(h) || [])[1] || null,
      fail: between(h, 'gear.enh_on_fail: ', '</div>'), rate: (/font-size:13px">(\d+)%/.exec(h) || [])[1] || null, cost: between(h, 'gear.enh_cost</div><div class="enhance-confirm-value">', '</div>'),
      bonus: (/gear\.enh_bonus\{"n":(\d+)\}/.exec(h) || [])[1] || null, alerts: w.log.alerts.length };
    w.log.alerts.length = 0;
  }
  // 강화 여러 번: (eid 번호, 보호) — 성공·실패·하락·파손·보호·오류
  const plan = [[3, false], [3, false], [3, false], [9, false], [9, true], [9, false], [13, false], [13, true], [13, false], [14, false], [18, false],
    [4, false], [4, false], [4, false], [4, true], [4, false], [4, false], [8, false], [8, false], [8, false], [8, false]];
  const results = [];
  for (const [i, p] of plan) { results.push(JSON.parse(JSON.stringify(C.enhanceItem(base.game_inventory[i].eid, p)))); }
  // 파손 장비가 생길 때까지 (보호 없이 같은 장비를 계속 — 파손 0.5% 라 많이)
  let n = 0;
  w.mem.game_save = JSON.stringify({ gold: 99999999 }); w.mem.game_mats = JSON.stringify({ stone: 99999, protect: 0, shard: 0 });
  while (n < 3000) { n++; const r = C.enhanceItem(base.game_inventory[10].eid, false); if (r.broken) { results.push(JSON.parse(JSON.stringify(r))); break; } }
  const toBreak = n;
  // 돈·강화석 부족
  w.mem.game_save = JSON.stringify({ gold: 1 }); results.push(C.enhanceItem(base.game_inventory[11].eid, false));
  w.mem.game_save = JSON.stringify({ gold: 99999 }); w.mem.game_mats = JSON.stringify({ stone: 0 }); results.push(C.enhanceItem(base.game_inventory[11].eid, false));
  // 수리 · 분해
  const repair = [C.repairItem(base.game_inventory[18].eid), C.repairItem(base.game_inventory[10].eid), C.repairItem(base.game_inventory[11].eid)];
  const dis = [C.dismantleItem(base.game_inventory[15].eid), C.dismantleItem(base.game_inventory[16].eid), C.dismantleItem('nope')];
  const list1 = enhanceListModel(w);
  out.push({ name: 'enhance', seed: 606, store: base, list0, previews, plan, results, toBreak, repair, dis, list1, after: dumpStore(w.mem), calls: w.rnd.calls });
  return out;
}

function itemCases() {
  const out = [];
  const base = equipSave();
  const w = makeWorld('party', 707, base);
  const C = w.ctx;
  C.renderItemTab();
  const tab = w.doc.getElementById('item-list').children.map(sec => sec.innerHTML + sec.children.map(c => '|' + c.innerHTML).join(''));
  const uses = [];
  for (const [pid, uid] of [['exp_l', 1], ['exp_m', 6], ['exp_m', 8], ['exp_s', 3], ['exp_s', 3]]) {
    w.log.alerts.length = 0; w.doc.ptBtns.length = 0;
    C.showPotionUseModal(pid);
    const targets = w.doc.ptBtns.map(b => +b.dataset.uid);
    const b = w.doc.ptBtns.find(x => +x.dataset.uid === uid);
    if (b) b.onclick();
    uses.push({ pid, uid, targets, alerts: w.log.alerts.slice() });
  }
  // 빈 인벤토리
  const w2 = makeWorld('party', 708, { game_roster: base.game_roster, game_inventory: [] });
  w2.ctx.renderItemTab();
  out.push({ name: 'items', seed: 707, store: base, tab, uses, after: dumpStore(w.mem), empty: w2.doc.getElementById('item-list').innerHTML });
  return out;
}

function constants() {
  const w = makeWorld('shop', 1, {});
  const p = makeWorld('party', 1, {});
  return { EXP_POTIONS: w.ctx.EXP_POTIONS, BATTLE_POTION_LIST: w.ctx.BATTLE_POTION_LIST, SCROLL_CLASSES: w.ctx.SCROLL_CLASSES,
    SHOP_REFRESH_INTERVAL: w.ctx.SHOP_REFRESH_INTERVAL, POTION_INFO: p.ctx.POTION_INFO, rates: w.ctx.gachaRatesHtml() };
}

// ── 왕복 확인: Godot 이 쓴 세이브(키 → 문자열)를 웹 코드로 읽고 화면 함수를 모두 돌려 오류가 없는지 (godot/tests/check_outer_4b1.gd 가 부름) ──
function roundtrip(file) {
  const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
  const errs = [];
  let n = 0;
  const run = (what, fn) => { n++; try { fn(); } catch (e) { errs.push(what + ': ' + (e && e.message)); } };
  const ws = makeWorld('shop', 9, raw);
  run('shop.load', () => { ws.ctx._gold = ws.ctx.loadGold(); ws.ctx.loadShop(); });
  for (const tab of ['mercenary', 'consumable', 'equip', 'skill', 'scroll', 'gold']) run('shop.' + tab, () => { ws.ctx._currentTab = tab; ws.ctx.renderShop(); });
  const wp = makeWorld('party', 9, raw);
  const P = wp.ctx;
  run('party.parties', () => { P._parties = P.loadParties(); P._currentPartyId = P._parties.activePartyId; P.renderPartyTabs(); P.renderPartySlots(); });
  run('party.chars', () => { P._gold = P.loadGold(); P.renderEquipFilterTabs(); P.renderChars(); });
  for (const ch of P.getRoster().chars) {
    if (!ch || ch.dead || ch.cls === 'commander') continue;
    for (const f of ['all', 'weapon', 'armor', 'accessory']) run('party.modal.' + ch.uid + '.' + f, () => { P._selUid = ch.uid; P._invFilter = f; P.renderModalBody(); });
  }
  run('party.enhance', () => P.renderEnhanceList());
  run('party.items', () => P.renderItemTab());
  for (const it of P.loadInventory().filter(x => x && x.type === 'equip')) run('party.enhance_modal.' + it.eid, () => P.showEnhanceConfirmModal(it.eid));
  const wl = makeWorld('lobby', 9, raw);
  let ok = null;
  run('lobby.validate', () => { ok = wl.ctx.validateAndRepairGameData(); });
  if (ok === false) errs.push('lobby.validate: 웹 점검이 세이브를 잘못된 것으로 봄');
  console.log(JSON.stringify({ ok: errs.length === 0, checks: n, errors: errs }));
}
if (process.argv.includes('--roundtrip')) { roundtrip(process.argv[process.argv.indexOf('--roundtrip') + 1]); process.exit(0); }

const result = {
  note: 'node tools/outer-4b1-expect.js 가 웹 코드를 그대로 실행해 만든 정답 — 손으로 고치지 말 것 (godot/tests/check_outer_4b1.gd 가 비교)',
  now: NOW, constants: constants(), shop: shopCases(), equip: equipCases(), enhance: enhanceCases(), items: itemCases(),
};
const text = JSON.stringify(result, null, 1) + '\n';
if (CHECK) {
  const cur = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : '';
  if (cur !== text) { console.log('[outer-4b1-expect] 정답 파일이 웹 코드와 다릅니다 — node tools/outer-4b1-expect.js 로 다시 만드세요'); process.exit(1); }
  console.log('[outer-4b1-expect] 같음');
} else {
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, text);
  console.log('[outer-4b1-expect] 썼음: ' + path.relative(ROOT, OUT) + ' (상점 ' + result.shop.length + ' · 장비 ' + result.equip.length + ' · 강화 ' + result.enhance.length + ' · 아이템 ' + result.items.length + ')');
}
