// ═══════════════════════════════════════════
//  tools/autoplay.js — 개발용 자동 플레이 연구소 (autoplay.html)
//  1) 전투: battle.html을 iframe으로 띄우고 setTimeout을 배속으로 줄여 빨리 감는다. 클랜원 차례는 봇이 둔다.
//  2) 전투 사이: 전략 프로필(managed/naive)이 부활·상점·성소 합성(영혼석)·스킬북·장비·파티 편성을 처리한다.
//     캠페인 전투 dayEvery번마다 하루가 지난 것으로 보고 요일 던전(하루 3회)을 돈다.
//  3) 스테이지마다 결과를 ap_log(localStorage)에 남긴다 → 공략·밸런스 연구 자료
//  게임의 lexical 전역(const GameStore 등)은 iframe의 window 속성이 아니라서 W.eval로 참조한다.
// ═══════════════════════════════════════════
'use strict';

const $ = id => document.getElementById(id);
const sleep = ms => new Promise(r => setTimeout(r, ms));
const AP = { running: false, stopReq: false, log: [], shop: null, shopAt: -99 };
const cfg = () => ({
  profile: $('profile').value, combo: $('combo').value.split(','),
  from: +$('from').value, to: +$('to').value, retries: +$('retries').value, grind: +$('grind').value,
  warp: Math.max(1, +$('warp').value), shopEvery: Math.max(1, +$('shopEvery').value), dayEvery: Math.max(1, +$('dayEvery').value),
});
function out(msg, cls) {
  const el = $('log'), line = document.createElement('div');
  if (cls) line.className = cls;
  line.textContent = msg; el.appendChild(line); el.scrollTop = el.scrollHeight;
}
function saveLog() { try { localStorage.setItem('ap_log', JSON.stringify(AP.log)); } catch (e) {} report(false); }

// ── 결과 요약 + 연구 서버로 보고 (tools/autoplay-server.py가 받아 파일로 저장 → 헤드리스 실행 중에도 진행 확인) ──
function summarize(log) {
  const main = log.filter(r => !r.daily && !r.grind && typeof r.stage === 'number' && r.stage < 900), wins = main.filter(r => r.win);
  const best = Math.max(0, ...wins.map(r => r.stage));
  const at = s => { const r = wins.find(x => x.stage === s); return r ? r.party : null; };
  const by10 = (f) => { const o = {}; main.forEach(r => { const e = Math.ceil(r.stage / 10); o[e] = (o[e] || 0) + f(r); }); return o; };
  const turns = {}; wins.forEach(r => { const e = Math.ceil(r.stage / 10); (turns[e] = turns[e] || []).push(r.turn); });
  const avgTurn = {}; for (const k in turns) avgTurn[k] = Math.round(turns[k].reduce((a, b) => a + b, 0) / turns[k].length);
  const firstWipe = main.find(r => (r.dead || 0) >= 5);
  const mins = {}; wins.forEach(r => { if (r.estMin == null) return; const e = Math.ceil(r.stage / 10); (mins[e] = mins[e] || []).push(r.estMin); });
  const minBy10 = {}; for (const k in mins) minBy10[k] = { avg: Math.round(mins[k].reduce((a, b) => a + b, 0) / mins[k].length * 10) / 10, max: Math.max(...mins[k]) };
  const over10 = wins.filter(r => r.estMin > 10).map(r => r.stage + ':' + r.estMin);
  const chests = {}; log.forEach(r => (r.chests || '').split(',').filter(Boolean).forEach(k => { chests[k] = (chests[k] || 0) + 1; }));
  const hz = {}; main.forEach(r => { if (!r.hazard) return; const h = hz[r.hazard] = hz[r.hazard] || { n: 0, win: 0, dead: 0 }; h.n++; if (r.win) h.win++; h.dead += r.dead || 0; });
  return { minBy10, over10, chests, hazards: hz,
    best, battles: log.length, main: main.length, grinds: log.filter(r => r.grind).length, dailies: log.filter(r => r.daily).length,
    deathsBy10: by10(r => r.dead || 0), avgTurnBy10: avgTurn, firstWipe: firstWipe ? firstWipe.stage : null,
    party: { 20: at(20), 40: at(40), 60: at(60), 70: at(70), 80: at(80), 90: at(90), 100: at(100) }, gold: loadGold() };
}
let _repAt = 0;
function report(final) {
  if (!final && Date.now() - _repAt < 5000) return; _repAt = Date.now();
  try {
    const C = cfg();
    fetch('/ap_report', { method: 'POST', body: JSON.stringify({ port: location.port, profile: C.profile, combo: C.combo.join(','), running: AP.running, final: !!final,
      summary: summarize(AP.log), tail: [...$('log').children].slice(-12).map(d => d.textContent), at: new Date().toISOString() }) }).catch(() => {});
  } catch (e) {}
}
try { AP.log = JSON.parse(localStorage.getItem('ap_log')) || []; } catch (e) {}

// ═════ 육성: 등급·합성·스킬북·장비 (sanctuary.js / academy.js / party-select.js 로직과 동일) ═════
const GR = ['C', 'B', 'A', 'S'];
const nextGrade = g => GR[GR.indexOf(g) + 1] || null;
function sacPoints(sacG, tgtG) { const d = GR.indexOf(sacG) - GR.indexOf(tgtG); return d >= 1 ? 4 : d === 0 ? 2 : d === -1 ? 1 : 0; }
function power(ch) { const eq = typeof calcEquipBonus === 'function' ? calcEquipBonus(ch) : { hp: 0, atk: 0, def: 0 }; return (ch.hp + eq.hp) + (ch.atk + eq.atk) * 6 + (ch.def + eq.def) * 4; }

function promote(targetUid, sacUids) {
  const roster = getRoster(), target = roster.chars.find(c => c.uid === targetUid); if (!target) return false;
  const ng = nextGrade(potGrade(target)); if (!ng) return false;
  const skills = getCharSkills(target.cls); if (!target.skillLv) target.skillLv = {};
  const inv = loadInventory();
  sacUids.forEach(su => {
    const sac = roster.chars.find(c => c.uid === su);
    skills.forEach(sk => {
      if (LEARNABLE_SKILLS[sk.id]) {
        if (!(sac && sac.skillLv && sac.skillLv[sk.id] >= 1)) return;
        if (!target.skillLv[sk.id]) target.skillLv[sk.id] = 0;
        if (target.skillLv[sk.id] >= MAX_SKILL_LV) inv.push({ id: sk.id, cls: target.cls, lv: 1 }); else target.skillLv[sk.id]++;
        return;
      }
      if (!target.skillLv[sk.id]) target.skillLv[sk.id] = 1;
      if (target.skillLv[sk.id] >= MAX_SKILL_LV) inv.push({ id: sk.id, cls: target.cls, lv: 1 }); else target.skillLv[sk.id]++;
    });
  });
  // 제물 장비 해제 + 로스터·파티에서 제거
  const sacSet = new Set(sacUids);
  inv.forEach(it => { if (it.type === 'equip' && sacSet.has(it.equipped)) it.equipped = null; });
  saveInventory(inv);
  roster.chars = roster.chars.filter(c => !sacSet.has(c.uid));
  const d = JAB[target.cls], pot = _rollPotentialWithGrade(target.cls, ng), gm = gradeMultiplier(ng), lg = target.lv - 1;
  target.pot = pot;
  target.hp = Math.round(d.base.hp * gm + pot.hp * lg); target.atk = Math.round(d.base.atk * gm + pot.atk * lg); target.def = Math.round(d.base.def * gm + pot.def * lg);
  saveRoster(roster);
  const pd = loadParties(); pd.parties.forEach(p => { p.slots = p.slots.map(s => sacSet.has(s) ? null : s); }); saveParties(pd);
  return ng;
}
function useBook(invIdx, uid) {
  const inv = loadInventory(), book = inv[invIdx]; if (!book || !book.id || book.type) return false;
  const roster = getRoster(), ch = roster.chars.find(c => c.uid === uid); if (!ch || ch.cls !== book.cls) return false;
  if (!ch.skillLv) ch.skillLv = {};
  const learn = !!LEARNABLE_SKILLS[book.id], cur = ch.skillLv[book.id] || (learn ? 0 : 1);
  if (cur >= MAX_SKILL_LV) return false;
  ch.skillLv[book.id] = cur + 1; inv.splice(invIdx, 1);
  saveRoster(roster); saveInventory(inv); return true;
}
function changeClassTo(uid, newCls) {
  const roster = getRoster(), ch = roster.chars.find(c => c.uid === uid); if (!ch || ch.cls !== 'novice') return false;
  const nd = JAB[newCls], g = potGrade(ch), pot = _rollPotentialWithGrade(newCls, g), gm = gradeMultiplier(g), lg = ch.lv - 1;
  Object.assign(ch, { cls: newCls, pot, move: nd.base.move, range: nd.base.range,
    hp: Math.round(Math.round(nd.base.hp * gm) + pot.hp * lg), atk: Math.round(Math.round(nd.base.atk * gm) + pot.atk * lg), def: Math.round(Math.round(nd.base.def * gm) + pot.def * lg) });
  saveRoster(roster); return true;
}
// 장비: 슬롯마다 가장 좋은 것을 핵심 클랜원에게 (공격 6, 방어 4, 체력 1 가중)
// 장비 점수: 기본·강화 능력치 + 등급(옵션 개수) + 전설·강화 단계 + 그 직업 전용 옵션이면 가산, 파손은 제외
const eqScore = (it, cls) => { if (it.broken) return -1e9; const s = getEnhancedStats(it);
  return (s.hp || 0) + (s.atk || 0) * 6 + (s.def || 0) * 4 + RARITY[it.rarity].tier * 15 + (it.legend ? 120 : 0) + (it.enhanceLv || 0) * 8
    + (cls && it.cOpt && it.cOpt.cls === cls ? 20 : 0) + (cls && it.setCls === cls ? 25 : 0); };
function autoEquip(uids) {
  const roster = getRoster(), inv = loadInventory();
  inv.forEach(it => { if (it.type === 'equip') it.equipped = null; });
  roster.chars.forEach(c => { if (c.equip) for (const k in c.equip) c.equip[k] = null; });
  const free = inv.filter(it => it.type === 'equip' && !it.broken);
  for (const uid of uids) {
    const ch = roster.chars.find(c => c.uid === uid); if (!ch) continue;
    ch.equip = ch.equip || {}; EQUIP_SLOTS.forEach(s => { if (!(s in ch.equip)) ch.equip[s] = null; });
    for (const it of free.slice().sort((a, b) => eqScore(b, ch.cls) - eqScore(a, ch.cls))) {
      if (it.equipped !== null || ch.equip[it.slot]) continue;
      if (it.clsRestrict && it.clsRestrict.length && it.clsRestrict.indexOf(ch.cls) === -1) continue;
      if (it.slot === 'offhand') { const w = inv.find(x => x.eid === ch.equip.weapon); if (w && w.hand === '2h') continue; }
      if (it.slot === 'weapon' && it.hand === '2h' && ch.equip.offhand) continue;
      ch.equip[it.slot] = it.eid; it.equipped = uid;
    }
  }
  saveRoster(roster); saveInventory(inv);
}
function sellJunk(keep) {   // 장착 안 한 장비 중 각 슬롯 상위 keep개만 남기고 분해 (강화석이 판매 골드보다 가치 있음)
  const inv = loadInventory(); let n = 0, stones = 0;
  const bySlot = {}; inv.forEach(it => { if (it.type === 'equip' && it.equipped === null && !it.broken) (bySlot[it.slot] = bySlot[it.slot] || []).push(it); });
  const drop = [];
  for (const k in bySlot) bySlot[k].sort((a, b) => eqScore(b) - eqScore(a)).slice(keep).forEach(it => { if (!it.legend) drop.push(it.eid); });
  drop.forEach(eid => { const r = dismantleItem(eid); if (r.ok) { n++; stones += r.stones; } });
  return n ? n + '개 → 강화석 ' + stones : 0;
}
// 강화: 장착 장비(무기 → 갑옷 → 나머지) 를 목표 단계까지. 골드는 reserve만큼 남김, +6 이상 시도는 보호 주문서 있으면 사용
//  파손 장비는 골드 여유가 있으면 수리, 아니면 분해
const ENH = { target: 7, reserve: 600 };
function autoEnhance(p, notes) {
  let tries = 0, ups = 0, downs = 0, breaks = 0;
  const order = ['weapon', 'armor', 'helmet', 'boots', 'offhand', 'necklace', 'ring', 'earring'];
  for (let guard = 0; guard < 60; guard++) {
    const inv = loadInventory();
    const cand = inv.filter(x => x.type === 'equip' && !x.broken && p.includes(x.equipped) && (x.enhanceLv || 0) < ENH.target)
      .sort((a, b) => (a.enhanceLv || 0) - (b.enhanceLv || 0) || order.indexOf(a.slot) - order.indexOf(b.slot));
    const it = cand[0]; if (!it) break;
    if (loadGold() < calcEnhanceCost(it) + ENH.reserve || Mats.get('stone') < calcEnhanceStones(it)) break;
    const r = enhanceItem(it.eid, (it.enhanceLv || 0) >= 6); tries++;
    if (r.ok) ups++; else if (r.broken) breaks++; else if (r.dropped) downs++;
  }
  loadInventory().filter(x => x.type === 'equip' && x.broken).forEach(x => {
    if (loadGold() > repairCost(x) + ENH.reserve) { repairItem(x.eid); notes.push('수리 ' + x.rarity); } else dismantleItem(x.eid);
  });
  if (tries) notes.push('강화 ' + tries + '회 (성공 ' + ups + ', 하락 ' + downs + (breaks ? ', 파손 ' + breaks : '') + ') 강화석 ' + Mats.get('stone') +
    ' 평균 +' + (p.length ? (loadInventory().filter(x => x.type === 'equip' && p.includes(x.equipped)).reduce((a, x) => a + (x.enhanceLv || 0), 0) / Math.max(1, loadInventory().filter(x => x.type === 'equip' && p.includes(x.equipped)).length)).toFixed(1) : 0));
}

// ── 상점 (shop.js genRotatingItems와 같은 규칙, 갱신 주기는 cfg.shopEvery 스테이지로 모사) ──
const SCROLLS = ['warrior','knight','assassin','brawler','lancer','sapper','archer','mage','summoner','shaman','priest'];
function genShop() {
  const classes = Object.keys(JAB).filter(c => !c.startsWith('summon') && !JAB[c].unique), items = [];
  for (let i = 0; i < 6; i++) {
    const cls = classes[Math.floor(Math.random() * classes.length)], g = JAB[cls].growth;
    const pot = { hp: +(g.hp[0] + Math.random() * (g.hp[1] - g.hp[0])).toFixed(1), atk: +(g.atk[0] + Math.random() * (g.atk[1] - g.atk[0])).toFixed(1),
      def: +(g.def[0] + Math.random() * (g.def[1] - g.def[0])).toFixed(1), actionRec: rollActionRec() };
    const avg = ['hp', 'atk', 'def'].reduce((s, k) => s + (g[k][1] > g[k][0] ? (pot[k] - g[k][0]) / (g[k][1] - g[k][0]) : .5), 0) / 3;
    const grade = avg >= .85 ? 'S' : avg >= .65 ? 'A' : avg >= .35 ? 'B' : 'C';
    items.push({ type: 'char', cls, pot, grade, cost: Math.round(ECON.merc[grade] * (.9 + avg * .2)), sold: false });
  }
  Object.keys(LEARNABLE_SKILLS).sort(() => Math.random() - .5).slice(0, 6).forEach(id => {
    const sk = LEARNABLE_SKILLS[id]; items.push({ type: 'skillbook', skillId: id, cls: sk.cls, cost: Math.round((sk.bookCost || (sk.cls === 'commander' ? 1500 : 800)) * ECON.bookMul), sold: false });
  });
  SCROLLS.slice().sort(() => Math.random() - .5).slice(0, 6).forEach(c => items.push({ type: 'scroll', scrollCls: c, cost: ECON.scroll, sold: false }));
  DAILY.CLASSES.slice().sort(() => Math.random() - .5).slice(0, 3).forEach(c => items.push({ type: 'soulstone', cls: c, cost: ECON.soulStone, sold: false }));
  return items;
}
const spend = n => { const g = loadGold(); if (g < n) return false; saveGold(g - n); return true; };
// 스킬북 우선순위(직업별): 실제 전투에서 쓰는 피해·생존기 위주
const BOOK_PRI = {
  knight: ['knight_tenacity', 'knight_charge', 'knight_painshare'], warrior: ['warrior_cleave', 'warrior_bloodthirst', 'warrior_criticalstrike', 'warrior_assault'],
  archer: ['archer_rapidfire', 'archer_weakspot', 'archer_steelrain', 'archer_snipe'], mage: ['mage_freeze', 'mage_manasurge'],
  priest: ['priest_divinegrace', 'priest_sanctuary'], assassin: ['assassin_ambush', 'assassin_smoke'], brawler: ['brawler_flurry', 'brawler_counter', 'brawler_crush'],
  lancer: ['lancer_charge', 'lancer_spearwall', 'lancer_phalanx'], shaman: ['shaman_spiritsurge', 'shaman_poisonmist'], summoner: ['summoner_empower', 'summoner_soulbond'],
  sapper: ['sapper_enhancedtrap'], novice: ['novice_grit', 'novice_tackle'],
};

// ═════ 전투 사이 관리 ═════
function manage(stageId, C) {
  const notes = [];
  let roster = getRoster();
  const cmd = roster.chars.find(c => c.cls === COMMANDER_CLS); if (cmd && !cmd.setup) { cmd.setup = true; cmd.gender = 'f'; saveRoster(roster); }
  // 부활 (성소): 먼저 출전 인원 5명을 채우도록 싼 순서로, 그다음 강한 순서로
  const revCost = c => ECON.revive[0] + ECON.revive[1] * c.lv;
  const revive = c => { if (!spend(revCost(c))) return false; const r = getRoster(), x = r.chars.find(y => y.uid === c.uid); x.dead = false; delete x.diedAt; saveRoster(r); notes.push('부활 ' + c.cls + c.lv); return true; };
  const field = () => getRoster().chars.filter(c => c.cls !== COMMANDER_CLS);
  field().filter(c => c.dead).sort((a, b) => revCost(a) - revCost(b)).forEach(c => { if (field().filter(x => !x.dead).length < MAX_P) revive(c); });
  field().filter(c => c.dead).sort((a, b) => power(b) - power(a)).forEach(c => revive(c));
  AP.needRevive = 0;
  if (C.profile === 'naive') { setParty(C, notes); return notes; }

  if (!AP.shop || stageId - AP.shopAt >= C.shopEvery) { AP.shop = genShop(); AP.shopAt = stageId; }
  const shop = AP.shop;
  const alive = () => getRoster().chars.filter(c => !c.dead && c.cls !== COMMANDER_CLS);
  // 1) 조합에 필요한 직업 확보: 노비스 전직(전직서) → 없으면 용병(좋은 등급 우선)
  const core = [];
  for (const cls of C.combo) {
    const pool = alive().filter(c => c.cls === cls && !core.includes(c.uid)).sort((a, b) => power(b) - power(a));
    // 그 직업의 주력이 죽어 있으면(살아 있는 같은 직업보다 강하면) 새로 사지 말고 부활을 기다림 → 연습 모드로 골드 모으기
    const deadBest = getRoster().chars.filter(c => c.dead && c.cls === cls && !core.includes(c.uid)).sort((a, b) => power(b) - power(a))[0];
    if (deadBest && (!pool.length || power(deadBest) > power(pool[0]) * 1.3)) { AP.needRevive++; if (pool.length) core.push(pool[0].uid); continue; }
    if (pool.length) { core.push(pool[0].uid); continue; }
    const nov = alive().filter(c => c.cls === 'novice' && !core.includes(c.uid)).sort((a, b) => power(b) - power(a))[0];
    const scroll = shop.find(i => i.type === 'scroll' && !i.sold && i.scrollCls === cls);
    if (nov && scroll && spend(scroll.cost)) { scroll.sold = true; changeClassTo(nov.uid, cls); core.push(nov.uid); notes.push('전직 ' + cls); continue; }
    const merc = shop.filter(i => i.type === 'char' && !i.sold && i.cls === cls).sort((a, b) => GR.indexOf(b.grade) - GR.indexOf(a.grade))[0];
    if (merc && spend(merc.cost)) { merc.sold = true; const ch = addChar(cls, Math.floor(Math.random() * 300), merc.pot, randomGender()); core.push(ch.uid); notes.push('고용 ' + cls + merc.grade); }
  }
  // 2) 합성: 같은 직업의 남는 유닛을 제물로 (4점 이상). B→A·A→S는 영혼석도 필요
  for (const uid of core) {
    for (let guard = 0; guard < 3; guard++) {
      const t = getRoster().chars.find(c => c.uid === uid); if (!t) break;
      const tg = potGrade(t); if (tg === 'S') break;
      // 영혼석: 조각 합치기 → 부족하면 (여유 있을 때) 상점 영혼석 구매 → 그래도 없으면 승급 보류
      Soul.combine(t.cls);
      const sn = Soul.need(tg);
      if (Soul.stones(t.cls) < sn) {
        const ss = shop.find(i => i.type === 'soulstone' && !i.sold && i.cls === t.cls);
        if (ss && Soul.stones(t.cls) + 1 >= sn && loadGold() > ss.cost + 800 && spend(ss.cost)) { ss.sold = true; Soul.add('stone', t.cls, 1); notes.push('영혼석 구매 ' + t.cls); }
        if (Soul.stones(t.cls) < sn) break;
      }
      const sacs = alive().filter(c => c.cls === t.cls && c.uid !== uid && !core.includes(c.uid)).map(c => ({ c, p: sacPoints(potGrade(c), tg) })).filter(x => x.p > 0).sort((a, b) => b.p - a.p);
      let pts = 0; const pick = [];
      for (const s of sacs) { if (pts >= 4) break; pick.push(s.c.uid); pts += s.p; }
      if (pts >= 4) { Soul.spend(t.cls, sn); const ng = promote(uid, pick); notes.push('합성 ' + t.cls + ' ' + tg + '→' + ng + (sn ? ' (영혼석 ' + sn + ')' : '')); continue; }
      // 상점 제물 구매: 가장 싼 같은 직업 용병 (점수 > 0인 것만), 골드 여유 있을 때
      const m = shop.filter(i => i.type === 'char' && !i.sold && i.cls === t.cls && sacPoints(i.grade, tg) > 0).sort((a, b) => a.cost - b.cost)[0];
      if (m && loadGold() > m.cost + 600 && spend(m.cost)) { m.sold = true; addChar(t.cls, Math.floor(Math.random() * 300), m.pot, randomGender()); notes.push('제물 구매 ' + t.cls + m.grade); continue; }
      break;
    }
  }
  // 3) 스킬북: 핵심 클랜원 직업 책을 사서 바로 사용 (지휘관은 전투 불참)
  const coreAll = core.slice();
  for (const uid of coreAll) {
    const ch = getRoster().chars.find(c => c.uid === uid); if (!ch) continue;
    for (const id of (BOOK_PRI[ch.cls] || [])) {
      const it = shop.find(i => i.type === 'skillbook' && !i.sold && i.skillId === id);
      const lv = (ch.skillLv && ch.skillLv[id]) || 0;
      if (!it || lv >= MAX_SKILL_LV || loadGold() < it.cost + 300) continue;
      if (!spend(it.cost)) continue;
      it.sold = true; const inv = loadInventory(); inv.push({ id, cls: ch.cls, lv: 1 }); saveInventory(inv);
      notes.push('스킬북 ' + id);
    }
  }
  // 가지고 있는 책(드랍·합성 잉여) 사용
  { const inv = loadInventory();
    for (let i = inv.length - 1; i >= 0; i--) { const b = inv[i]; if (!b.id || b.type) continue;
      const tgt = coreAll.map(u => getRoster().chars.find(c => c.uid === u)).filter(c => c && c.cls === b.cls)[0];
      if (tgt && useBook(i, tgt.uid)) notes.push('책 사용 ' + b.id); } }
  // 4) 회복 물약 비축 (최대 4개)
  const heals = loadInventory().filter(i => i.type === 'battle_potion' && i.potionId === 'potion_heal').length;
  for (let i = heals; i < 4 && loadGold() > 900; i++) {
    if (!spend(ECON.battlePotion)) break; const inv = loadInventory(); inv.push({ type: 'battle_potion', pid: Date.now() + i, potionId: 'potion_heal', icon: '💊', quantity: 1 }); saveInventory(inv);
  }
  // 5) 장비 뽑기: 여유 골드로 10+1회
  while (loadGold() >= GACHA_COST_10 + 1500) {
    spend(GACHA_COST_10); const inv = loadInventory();
    for (let i = 0; i < GACHA_MULTI_COUNT; i++) inv.push(gachaPull(i === GACHA_MULTI_COUNT - 1 ? 'rare' : null));
    saveInventory(inv); notes.push('장비 뽑기 11회');
  }
  setParty(C, notes, core);
  const p = getActiveParty(); autoEquip(p);
  // 6) 마법부여: 이번 스테이지 맵 디버프를 막도록, 장착 장비에 맞는 룬을 씀 (룬 1개 + 100G, 다른 마법부여는 덮어씀)
  //    맞는 룬이 없으면 여유 있을 때 룬 뽑기 1회, 장비가 없으면 장비 뽑기 1회
  const st = STAGES.find(s => s.id === stageId), hz = st && Hazard.forStage(st);
  if (hz) {
    for (const uid of p) {
      const ch = getRoster().chars.find(c => c.uid === uid); if (!ch) continue;
      if (Hazard.enchantsOf(ch).includes(hz.enchant)) continue;
      let it = loadInventory().find(x => x.type === 'equip' && x.equipped === uid && x.enchant !== hz.enchant);
      if (!it && loadGold() > GACHA_COST_1 + ENCHANT_FEE + 500) { spend(GACHA_COST_1); const inv = loadInventory(); inv.push(gachaPull(null)); saveInventory(inv); autoEquip(p); it = loadInventory().find(x => x.type === 'equip' && x.equipped === uid && x.enchant !== hz.enchant); notes.push('장비 뽑기 1회'); }
      if (!it) continue;
      if (!Rune.count(hz.enchant) && loadGold() > RUNE_GACHA_COST + ENCHANT_FEE + 500) { spend(RUNE_GACHA_COST); notes.push('룬 뽑기 ' + Rune.add(Rune.random())); }
      if (Rune.count(hz.enchant) && Rune.apply(it.eid, hz.enchant) === true) notes.push('마법부여 ' + hz.enchant + '→' + ch.cls);
    }
  }
  // 7) 공격용 마법부여: 공격 마법부여가 없는 장착 장비(무기 우선)에 가진 공격 룬을 우선순위대로
  const ATK_PRI = ['vamp', 'thunder', 'sunder', 'flame', 'venom', 'frost'];
  for (const uid of p) {
    const k = ATK_PRI.find(x => Rune.count(x)); if (!k || loadGold() < ENCHANT_FEE + 300) break;
    const mine = loadInventory().filter(x => x.type === 'equip' && x.equipped === uid);
    if (mine.some(x => x.enchantAtk)) continue;
    const it = mine.find(x => x.slot === 'weapon') || mine[0];
    if (it && Rune.apply(it.eid, k) === true) notes.push('공격 마법부여 ' + k);
  }
  const sold = sellJunk(1); if (sold) notes.push('장비 분해 ' + sold);
  autoEnhance(p, notes); autoEquip(p);
  return notes;
}
// 파티 5명: 조합 핵심 → 나머지는 전투력 순 (지휘관은 스토리 전용이라 제외)
function setParty(C, notes, core) {
  const r = getRoster();
  const alive = r.chars.filter(c => !c.dead && c.cls !== COMMANDER_CLS);
  let pick = (core || []).filter(u => alive.some(c => c.uid === u));
  alive.sort((a, b) => power(b) - power(a)).forEach(c => { if (pick.length < MAX_P && !pick.includes(c.uid)) pick.push(c.uid); });
  saveParty(pick.slice(0, MAX_P));
}

// ═════ 전투 봇 ═════
// 스킬 판단표: t=종류, m=공격력 배율(추정), r=범위(체비셰프), cc=제어 가치
const SK = {
  warrior_powersmash: { t: 'dmg', m: 1.5 }, warrior_criticalstrike: { t: 'dmg', m: 1.3 }, warrior_assault: { t: 'dmg', m: .8 }, warrior_cleave: { t: 'adj', m: 1.2, min: 2 },
  knight_charge: { t: 'dmg', m: .8, cc: 1 },
  archer_snipe: { t: 'dmg', m: 1.5 }, archer_rapidfire: { t: 'dmg', m: 2.2 }, archer_steelrain: { t: 'aoe', m: 1, r: 1 },
  lancer_pierce: { t: 'dmg', m: 1.1 }, lancer_charge: { t: 'dmg', m: 1.2 }, lancer_phalanx: { t: 'guard' },
  assassin_ambush: { t: 'dmg', m: 2 }, assassin_smoke: { t: 'smoke' },
  priest_massheal: { t: 'mheal', k: 1 }, priest_sanctuary: { t: 'mheal', k: .7 },
  sapper_trap: { t: 'dmg', m: 2 }, mage_fireburst: { t: 'aoe', m: 1, r: 1 }, mage_freeze: { t: 'dmg', m: 1.2, cc: 1 },
  novice_throw: { t: 'dmg', m: .8 }, novice_tackle: { t: 'dmg', m: .9 }, novice_firstaid: { t: 'heal1', p: .15 },
  brawler_disarm: { t: 'debuff' }, brawler_flurry: { t: 'dmg', m: 1.8 }, brawler_crush: { t: 'dmg', m: 1, nodef: 1 },
  shaman_spiritsurge: { t: 'dmg', m: 1, cc: .5 }, shaman_poisonmist: { t: 'aoe', m: .9, r: 1 },
  summoner_summon_spirit: { t: 'summon' }, summoner_summon_golem: { t: 'summon' },
};
const ROLE_W = { commander: 3, priest: 1.4, mage: 1.2, archer: 1.2, shaman: 1.1, summoner: 1.1, sapper: .9, assassin: .8, novice: .8, warrior: .6, brawler: .6, lancer: .5, knight: .25 };

function G(W) {   // iframe 게임 전역 묶음
  if (!W.__ap) W.__ap = W.eval('({S:GameStore, Grid, U:UnitManager, A:ActionManager, R:Renderer, FSM, BS:BattleState, SH:SKILL_HANDLERS, getUnitSkills, isStealthed, mh, TI, COLS, ROWS, BE:BattleEnd, BP:BATTLE_POTIONS, SI:SIEGE_ITEMS, GX:G, TACTIC, EventBus, Chest})');
  return W.__ap;
}
function enemiesOf(g) { return g.S.units.filter(v => v.team === 'enemy' && v.hp > 0); }
function alliesOf(g) { return g.S.units.filter(v => v.team === 'ally' && v.hp > 0); }
function at(u, x, y, fn) { const ox = u.x, oy = u.y; u.x = x; u.y = y; try { return fn(); } finally { u.x = ox; u.y = oy; } }

function atkValue(g, a, t) {
  const p = g.R.previewAttack(a, t);
  let v = p.dmg + (p.kill ? 25 + t.atk * 2 : 0) - (p.counter || 0) * (a.cls === COMMANDER_CLS ? 2 : .6);
  if (t.isBoss) v += 8;
  if (g.S.cStage && g.S.cStage.style === 'defense') v += t.y * 1.2;
  if (g.U.interceptOf && g.U.interceptOf(a, t)) v *= .45;
  return { v, p };
}
function bestAttack(g, a) {
  const onHill = g.S.ter[a.y] && g.S.ter[a.y][a.x] === 'hill';
  const rng = a.range + (onHill && a.range > 1 ? g.TACTIC.highRange : 0);
  let best = null;
  for (const e of enemiesOf(g)) {
    if (g.isStealthed(e)) continue;
    const d = g.mh(a.x, a.y, e.x, e.y); if (!d || d > rng) continue;
    if (g.U.coverOf(a, e)) continue;
    const r = atkValue(g, a, e); if (!best || r.v > best.v) best = { e, v: r.v, kill: r.p.kill };
  }
  return best;
}
function bestHeal(g, h) {
  if (h.role !== 'healer') return null;
  let best = null;
  for (const v of alliesOf(g)) {
    if (v.id === h.id || v.hp >= v.mhp * .8) continue;
    if (g.mh(h.x, h.y, v.x, v.y) > h.range) continue;
    const val = (v.mhp - v.hp) * .5 * (v.cls === COMMANDER_CLS ? 1.6 : 1) + (v.hp < v.mhp * .35 ? 25 : 0);
    if (!best || val > best.v) best = { t: v, v: val };
  }
  return best;
}
function skMul(u, id) { const lv = Math.min((u.skillLv && u.skillLv[id]) || 1, 10); return 1 + .1 * (lv - 1); }
function bestSkill(g, u) {
  let best = null;
  const skills = g.getUnitSkills(u), en = enemiesOf(g), al = alliesOf(g);
  skills.forEach((sk, idx) => {
    if (sk.passive || u.res < sk.cost) return;
    const ai = SK[sk.id]; if (!ai) return;
    const h = g.SH[sk.id]; if (!h) return;
    let tg; try { tg = h.target(u, sk, g.GX); } catch (e) { return; }
    if (tg === null || tg === undefined) return;
    const cells = tg === 'instant' ? [{ x: u.x, y: u.y }] : tg;
    if (!cells.length) return;
    const est = (e, m) => Math.max(1, Math.round(u.atk * m * skMul(u, sk.id)) - (ai.nodef ? 0 : e.def));
    for (const c of cells) {
      let v = 0;
      const eAt = en.find(e => e.x === c.x && e.y === c.y), aAt = al.find(a => a.x === c.x && a.y === c.y);
      if (ai.t === 'dmg') { if (!eAt) continue; const d = est(eAt, ai.m); v = d + (d >= eAt.hp ? 25 + eAt.atk * 2 : (ai.cc || 0) * eAt.atk * .8); }
      else if (ai.t === 'aoe') { for (const e of en) if (Math.max(Math.abs(e.x - c.x), Math.abs(e.y - c.y)) <= ai.r) { const d = est(e, ai.m); v += d + (d >= e.hp ? 20 : 0); } }
      else if (ai.t === 'adj') { const adj = en.filter(e => g.mh(u.x, u.y, e.x, e.y) === 1); if (adj.length < ai.min) continue; adj.forEach(e => { v += est(e, ai.m); }); }
      else if (ai.t === 'mheal') { const hurt = al.filter(a => g.mh(u.x, u.y, a.x, a.y) <= 6 && a.hp < a.mhp * .7); if (hurt.length < 2 && !hurt.some(a => a.hp < a.mhp * .4)) continue; v = hurt.reduce((s, a) => s + (a.mhp - a.hp), 0) * .45 * ai.k; }
      else if (ai.t === 'heal1') { if (!aAt || aAt.hp > aAt.mhp * .6) continue; v = Math.min(aAt.mhp - aAt.hp, aAt.mhp * ai.p) * .8; }
      else if (ai.t === 'rally') { const n = al.filter(a => g.mh(u.x, u.y, a.x, a.y) <= 4).length, near = en.some(e => g.mh(u.x, u.y, e.x, e.y) <= 7); if (n < 3 || !near) continue; v = n * 9; }
      else if (ai.t === 'harmony') { const hurt = al.filter(a => g.mh(u.x, u.y, a.x, a.y) <= 3); const miss = hurt.reduce((s, a) => s + Math.min(a.mhp * .15, a.mhp - a.hp), 0); if (miss < 25) continue; v = miss * .9; }
      else if (ai.t === 'piano') { const n = al.filter(a => g.mh(u.x, u.y, a.x, a.y) <= 3).length; if (n < 3 || !en.some(e => g.mh(u.x, u.y, e.x, e.y) <= 6)) continue; v = n * 7; }
      else if (ai.t === 'dacapo') { if (!aAt || !aAt.ha || aAt.id === u.id) continue; if (!en.some(e => g.mh(aAt.x, aAt.y, e.x, e.y) <= aAt.move + aAt.range)) continue; v = aAt.atk * 1.4; }
      else if (ai.t === 'summon') { if (al.some(a => a.isSummon && a.summonerId === u.id)) continue; v = u.atk * 1.5; }
      else if (ai.t === 'smoke') { if (u.hp > u.mhp * .5 || !en.some(e => g.mh(u.x, u.y, e.x, e.y) <= 3)) continue; v = 15; }
      else if (ai.t === 'guard') { const n = al.filter(a => g.mh(u.x, u.y, a.x, a.y) <= 2).length; if (n < 3 || !en.some(e => g.mh(u.x, u.y, e.x, e.y) <= 3)) continue; v = n * 4; }
      else if (ai.t === 'debuff') { if (!eAt) continue; v = eAt.atk * .7; }
      if (v > 0 && (!best || v > best.v)) best = { idx, sk, cell: c, v, instant: tg === 'instant' };
    }
  });
  return best;
}
function danger(g, u, x, y) {
  let d = 0;
  for (const e of enemiesOf(g)) {
    const dist = g.mh(e.x, e.y, x, y);
    if (dist <= e.move + e.range) d += Math.max(1, e.atk - u.def) * (dist <= e.range ? 1.2 : 1);
  }
  return d;
}
// 적까지의 실제 걸음 거리 지도 (바위·물·성벽을 돌아가는 거리, 유닛은 무시). 못 가는 칸은 직선거리+20
function buildField(g) {
  const S = g.S, F = S.ter.map(r => r.map(() => Infinity)), q = [];
  enemiesOf(g).forEach(e => { F[e.y][e.x] = 0; q.push([e.x, e.y]); });
  while (q.length) {
    const [x, y] = q.shift();
    for (const [dx, dy] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) {
      const nx = x + dx, ny = y + dy;
      if (ny < 0 || ny >= g.ROWS || nx < 0 || nx >= g.COLS || F[ny][nx] <= F[y][x] + 1) continue;
      const ti = g.TI[S.ter[ny][nx]]; if (!ti || !ti.pass) continue;
      F[ny][nx] = F[y][x] + 1; q.push([nx, ny]);
    }
  }
  return F;
}
// 칸 평가: 그 자리에서 할 수 있는 최선의 행동 가치 − 위험 + 전진
function cellScore(g, u, x, y) {
  return at(u, x, y, () => {
    const atk = bestAttack(g, u), heal = bestHeal(g, u), sk = bestSkill(g, u);
    const act = Math.max(atk ? atk.v : 0, heal ? heal.v : 0, sk ? sk.v * .95 : 0);
    const dg = danger(g, u, x, y), w = ROLE_W[u.cls] || .7;
    // 교착 방지: 우리 편 공격이 없던 라운드가 이어질수록 위험 회피를 줄이고 전진 (지휘관은 예외)
    const idle = Math.max(0, g.S.turn - (g.lastAtk || 0) - 1), cmdr = u.cls === COMMANDER_CLS;
    const calm = cmdr ? 1 : Math.max(.15, 1 - idle * .2);
    let s = act - dg * w * .12 * calm;
    if (dg >= u.hp) s -= 40 * w * calm;   // 다음 적 차례에 죽을 수 있는 칸
    // 전진/대형: 할 게 없으면 가까운 적 쪽으로 (탱커·근접은 앞으로, 원거리·지휘관은 동료 뒤)
    const en = enemiesOf(g);
    if (en.length) {
      const md = Math.min(...en.map(e => g.mh(x, y, e.x, e.y)));
      const fd = g.field && g.field[y] ? g.field[y][x] : Infinity;
      const nd = Number.isFinite(fd) ? fd : md + 20;
      const want = u.cls === 'knight' || u.role === 'melee' ? 1 : cmdr ? Math.max(3, u.range + 1) : Math.max(2, u.range);
      if (!act) s -= Math.abs(nd - want) * 1.6 * (1 + (cmdr ? 0 : idle * .5));
      if (cmdr && nd <= 2) s -= 20;
    }
    if (g.S.ter[y] && g.S.ter[y][x] === 'forest') s += 1;
    if (g.Chest && g.Chest.at(g.S, x, y) && dg < u.hp * .6) s += 12;   // 보물상자 (안전할 때만 주우러 감)
    if (g.S.ter[y] && g.S.ter[y][x] === 'hill' && u.range > 1) s += 2;
    return { s, atk, heal, sk };
  });
}

async function waitTurnDone(g, u, ms = 8000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { if (g.S.curUnit !== u || !g.FSM.is(g.BS.UNIT_SELECTED) || u.hp <= 0) return; await sleep(15); }
}
async function botTurn(W, u) {
  const g = G(W), A = g.A, S = g.S;
  // 비상: 체력이 낮으면 회복 물약 (지휘관은 50%, 나머지 35%)
  if (u.hp < u.mhp * (u.cls === COMMANDER_CLS ? .5 : .35) && S._battlePotions && S._battlePotions.length) {
    const pi = S._battlePotions.findIndex(p => g.BP[p.potionId] && g.BP[p.potionId].type === 'heal');
    if (pi >= 0) { A.actPotion(pi); if (S.potionTargets && S.potionTargets.includes(u)) { A.doPotion(u); await waitTurnDone(g, u); return 'potion'; } A.actCancel && A.actCancel(); }
  }
  g.field = buildField(g);
  // 이동 후보: 제자리 + 이동 가능 칸
  const cells = [{ x: u.x, y: u.y }].concat(u.hm ? [] : g.Grid.mvCells(u));
  let best = null;
  for (const c of cells) { const r = cellScore(g, u, c.x, c.y); if (!best || r.s > best.s) best = Object.assign({ x: c.x, y: c.y }, r); }
  if (best && (best.x !== u.x || best.y !== u.y)) { A.doMv(u, best.x, best.y); await sleep(30); }
  if (u.hp <= 0 || S.curUnit !== u) return 'moved';
  // 현재 자리에서 실제 행동
  const atk = bestAttack(g, u), heal = bestHeal(g, u), sk = bestSkill(g, u);
  const av = atk ? atk.v : 0, hv = heal ? heal.v : 0, sv = sk ? sk.v : 0;
  if (sk && sv > av * 1.1 && sv >= hv) {
    A.actSkill(sk.idx);
    if (g.FSM.is(g.BS.SKILL_TARGET)) A.cellCk(sk.cell.x, sk.cell.y);
    await waitTurnDone(g, u); if (S.curUnit !== u || u.ha) return 'skill:' + sk.sk.id;
  }
  if (heal && hv >= av) { A.doHeal(u, heal.t); await waitTurnDone(g, u); return 'heal'; }
  if (atk) { A.doAtk(u, atk.e); await waitTurnDone(g, u); return 'atk'; }
  // 공성: 공격할 수 없고 성벽·성문이 앞을 막으면 폭탄
  if (S._siegeItems && S._siegeItems.length) {
    const bi = S._siegeItems.findIndex(s => s.siegeId === 'siege_bomb');
    const wall = [[0, -1], [0, 1], [-1, 0], [1, 0]].map(([dx, dy]) => ({ x: u.x + dx, y: u.y + dy })).find(p => S.ter[p.y] && /wall|gate/.test(S.ter[p.y][p.x]));
    if (bi >= 0 && wall) { A.actSiege(bi); if (g.FSM.is(g.BS.ITEM_TARGET)) A.cellCk(wall.x, wall.y); await sleep(30); if (S.curUnit !== u) return 'siege'; }
  }
  if (S.curUnit === u && g.FSM.is(g.BS.UNIT_SELECTED)) {
    const near = enemiesOf(g).some(e => g.mh(u.x, u.y, e.x, e.y) <= e.move + e.range);
    if (near && (u.cls === 'knight' || u.role === 'melee')) A.actStance('defend');
    else if (u.range > 1 && near) A.actStance('overwatch');
    else A.actWait();
    await waitTurnDone(g, u);
  }
  return 'wait';
}

// ═════ 전투 진행 ═════
function loadFrame(src) {   // 20초 안에 onload가 없으면 그대로 진행 (호출 쪽에서 실패 확인 후 재시도)
  return new Promise(res => { const f = $('game'); const tm = setTimeout(() => res(f.contentWindow), 20000); f.onload = () => { clearTimeout(tm); res(f.contentWindow); }; f.src = src; });
}
function installWarp(W, warp) {
  const st = W.setTimeout.bind(W), si = W.setInterval.bind(W);
  W.setTimeout = (fn, ms, ...a) => st(fn, Math.max(0, (ms || 0) / warp), ...a);
  W.setInterval = (fn, ms, ...a) => si(fn, Math.max(4, (ms || 0) / warp), ...a);
}
// stageId: 스테이지 번호 또는 스테이지 객체(요일 던전)
async function runBattle(stageId, C, practice) {
  const stage = typeof stageId === 'object' ? stageId : STAGES.find(s => s.id === stageId);
  if (typeof stageId === 'object') stageId = stage.id;
  const party = getActiveParty();
  localStorage.setItem('game_nav', JSON.stringify({ cStage: stage, party, practiceMode: !!practice }));
  const gold0 = loadGold(), t0 = Date.now();
  // 전투 화면 로드 (서버가 바빠 스크립트가 빠지면 다시 시도)
  let W = null, g = null;
  for (let tries = 0; tries < 4 && !g; tries++) {
    localStorage.setItem('game_nav', JSON.stringify({ cStage: stage, party, practiceMode: !!practice }));
    W = await loadFrame('../battle.html?ap=' + Date.now());
    await sleep(80);
    // 스크립트가 하나라도 빠지면 초기화가 중간에 멈춤 → 모듈과 배치된 클랜원까지 확인
    try { g = G(W); if (!g.S || !g.TI || !g.BE || !W.eval("typeof Synergy === 'object' && typeof Soul === 'object'") || !g.S.units.some(u => u.team === 'ally')) { g = null; W.__ap = null; } } catch (e) { g = null; }
    if (!g) { out('전투 화면 로드 실패 → 다시 시도', 'l'); await sleep(1000); }
  }
  if (!g) return { stage: stageId, win: false, turn: 0, dead: 0, gold: 0, sec: 0, acts: {}, timeout: true, loadFail: true };
  installWarp(W, C.warp);
  let done = null;
  g.lastAtk = 0;
  g.EventBus.on('unit_attacked', d => { if (d.attacker && d.attacker.team === 'ally') g.lastAtk = g.S.turn; });
  // 사람 기준 예상 플레이 시간: 클랜원 차례 6초(생각+조작+연출), 적 차례 1.3초(연출)
  const turns = { player: 0, enemy: 0 };
  g.EventBus.on('turn_start', d => { if (d && d.phase in turns) turns[d.phase]++; });
  // 전투 종료 훅 (보상·사망 기록은 게임 코드가 그대로 처리)
  const orig = g.BE.onBattleEnd.bind(g.BE);
  g.BE.onBattleEnd = function (win) { const r = orig(win); done = { win, turn: g.S.turn }; return r; };
  const acts = {};
  const deadline = Date.now() + 15 * 60 * 1000;
  // 감시: 턴·행동 유닛·생존 HP 합이 40초 동안 그대로면 멈춘 것으로 보고 항복 처리
  let sig = '', sigAt = Date.now(), stuck = false;
  while (!done && !AP.stopReq && Date.now() < deadline) {
    const ns = g.S.turn + '|' + (g.S.curUnit && g.S.curUnit.id) + '|' + g.S.units.reduce((t, v) => t + Math.max(0, v.hp), 0) + '|' + g.FSM.state;
    if (ns !== sig) { sig = ns; sigAt = Date.now(); }
    else if (Date.now() - sigAt > 40000) { stuck = true; out('진행 멈춤 감지 → 항복 (' + ns + ')', 'l'); try { g.R.surrender(); } catch (e) {} sigAt = Date.now() + 1e9; }
    W.document.querySelectorAll('button').forEach(b => { if (/건너뛰기|Skip|Saltar/.test(b.textContent) && b.offsetParent) b.click(); });
    const u = g.S.curUnit;
    if (u && u.team === 'ally' && g.FSM.is(g.BS.UNIT_SELECTED) && g.S.sel === u && !u.ha && !u.isSummon) {
      let r; try { r = await botTurn(W, u); } catch (e) { r = 'err'; out('봇 오류: ' + e.message, 'l'); try { g.A.actWait(); } catch (_) {} }
      acts[r] = (acts[r] || 0) + 1;
    } else if (u && u.team === 'ally' && u.isSummon && g.FSM.is(g.BS.UNIT_SELECTED) && g.S.sel === u && !u.ha) {
      try { const b = bestAttack(g, u); if (b) g.A.doAtk(u, b.e); else g.A.actWait(); } catch (e) {}
      await waitTurnDone(g, u);
    }
    if (g.S.turn > 250 && !done) { out('턴 제한 초과(250) → 항복', 'l'); try { g.R.surrender(); } catch (e) {} }
    await sleep(12);
  }
  await sleep(120);
  return {
    stage: stageId, win: !!(done && done.win), turn: done ? done.turn : g.S.turn, practice: !!practice,
    dead: (g.S._deadAllyUids || []).length, gold: loadGold() - gold0, sec: Math.round((Date.now() - t0) / 1000),
    acts, timeout: !done, stuck, allyTurns: turns.player, enemyTurns: turns.enemy, chests: (g.S._chestLog || []).join(','),
    hazard: g.S._hazard ? g.S._hazard.id : null,
    estMin: Math.round((turns.player * 6 + turns.enemy * 1.3) / 60 * 10) / 10,
  };
}
function partySummary() {
  const r = getRoster(), cs = getActiveParty().map(u => r.chars.find(x => x.uid === u)).filter(Boolean);
  const syn = typeof Synergy !== 'undefined' ? Synergy.compute(cs.map(c => c.cls)).map(s => s.id).join('+') : '';
  return cs.map(c => `${c.cls}${c.lv}${potGrade(c)}`).join(' ') + (syn ? ' [' + syn + ']' : '');
}

// 요일 던전 하루치: 핵심 클랜원 중 영혼석이 필요한 직업 우선, 열린 가장 높은 난이도부터 (지면 한 단계 낮춤)
async function dailyRun(C, day) {
  const wd = day % 7, sch = DAILY.schedule[wd];
  const open = sch === 'all' ? DAILY.CLASSES.slice() : sch.slice();
  const party = getActiveParty().map(u => getRoster().chars.find(c => c.uid === u)).filter(Boolean);
  const want = party.filter(c => potGrade(c) !== 'S' && Soul.need(potGrade(c)) > 0).map(c => c.cls)
    .concat(party.filter(c => potGrade(c) !== 'S').map(c => c.cls)).filter(c => open.includes(c));
  const cls = want[0] || open.find(c => party.some(p => p.cls === c));
  if (!cls) return;
  let tier = DAILY.tiers.reduce((b, T, i) => (Daily.bestCleared() >= T.unlock ? i : b), 0);
  for (let k = 0; k < DAILY.perDay && !AP.stopReq; k++) {
    manage(Daily.bestCleared(), C);
    const r = await runBattle(Daily.buildStage(cls, tier), C, false);
    r.daily = true; r.dailyCls = cls; r.tier = tier; r.day = day; r.profile = C.profile; r.party = partySummary(); r.goldNow = loadGold();
    AP.log.push(r); saveLog();
    out(`  ${r.win ? '✔' : '✘'} 요일던전(${day}일차 ${'일월화수목금토'[wd]}) ${cls} ${DAILY.tiers[tier].key} → 조각 ${Soul.frags(cls)} 영혼석 ${Soul.stones(cls)}`, r.win ? 'w' : 'l');
    if (!r.win && tier > 0) tier--;
  }
}

async function campaign(fresh) {
  if (AP.running) return; AP.running = true; AP.stopReq = false;
  const C = cfg();
  if (fresh) newGame();
  out(`── 시작: ${C.profile} / ${C.combo.join('·')} / ${C.from}~${C.to} / 배속 ${C.warp} / 하루=${C.dayEvery}전투`);
  let stageId = C.from, battles = 0, day = 0;
  while (stageId <= C.to && !AP.stopReq) {
    // 하루가 지남: 캠페인 전투 dayEvery번마다 요일 던전 (무육성 프로필은 승급을 안 하므로 건너뜀)
    if (battles >= C.dayEvery * (day + 1)) { day++; if (C.profile !== 'naive') await dailyRun(C, day); }
    let cleared = false;
    // 주력이 죽었는데 부활 골드가 없으면: 연습 모드(사망 없음)로 낮은 스테이지를 돌아 골드를 모음 — 매 시도 전에 확인 (최대 10회)
    // (전멸 직후 약해진 파티로 바로 재도전하면 사망·부활 비용이 쌓여 무너짐)
    const reviveGrind = async () => {
      if (C.profile === 'naive' || stageId <= 3) return;
      let gs = Math.max(1, stageId - 3);   // 지면 10스테이지씩 낮춰 확실히 이기는 곳에서 번다
      for (let k = 0; k < 12 && !AP.stopReq; k++) {
        manage(stageId, C);
        if (!AP.needRevive && getActiveParty().length >= MAX_P) return;
        if (battles >= C.dayEvery * (day + 1)) { day++; await dailyRun(C, day); }
        const r = await runBattle(gs, C, true); battles++;
        if (!r.win) gs = Math.max(1, gs - 10);
        r.grind = true; r.reviveGrind = true; r.profile = C.profile; r.combo = C.combo.join(','); r.party = partySummary(); r.goldNow = loadGold();
        AP.log.push(r); saveLog();
        out(`  ${r.win ? '✔' : '✘'} 부활 자금 연습 파밍 S${gs} +${r.gold}G (보유 ${r.goldNow}) | ${r.party}`, r.win ? 'w' : 'l');
      }
    };
    for (let attempt = 0; attempt <= C.retries && !AP.stopReq; attempt++) {
      await reviveGrind();
      const notes = manage(stageId, C);
      if (notes.length) out(`  관리: ${notes.join(', ')}`);
      const r = await runBattle(stageId, C, false); battles++;
      r.attempt = attempt; r.profile = C.profile; r.combo = C.combo.join(','); r.party = partySummary(); r.goldNow = loadGold();
      AP.log.push(r); saveLog();
      out(`${r.win ? '✔' : '✘'} S${stageId} 시도${attempt + 1} 턴${r.turn} 사람기준 ${r.estMin}분 사망${r.dead} +${r.gold}G (보유 ${r.goldNow}) ${r.sec}s | ${r.party}`, r.win ? 'w' : 'l');
      $('stat').textContent = `S${stageId} ${r.win ? '클리어' : '실패'} · 보유 ${r.goldNow}G`;
      if (r.win) { cleared = true; break; }
    }
    if (cleared) { stageId++; continue; }
    // 막힘: 이전 스테이지를 파밍한 뒤 다시
    if (C.grind > 0 && stageId > 1) {
      // 막힘: 연습 모드 파밍을 C.grind회씩 최대 4라운드 (그동안 날짜가 지나 요일 던전·상점 갱신도 진행) → 매 라운드 후 재도전
      let won = false;
      for (let round = 0; round < 4 && !won && !AP.stopReq; round++) {
      out(`  막힘 → S${stageId - 1} 연습 모드 파밍 ${C.grind}회 (라운드 ${round + 1}/4)`);
      for (let k = 0; k < C.grind && !AP.stopReq; k++) {
        if (battles >= C.dayEvery * (day + 1)) { day++; if (C.profile !== 'naive') await dailyRun(C, day); }
        manage(stageId - 1, C);
        const r = await runBattle(stageId - 1, C, true); battles++;
        r.grind = true; r.profile = C.profile; r.combo = C.combo.join(','); r.party = partySummary(); r.goldNow = loadGold();
        AP.log.push(r); saveLog();
        out(`  ${r.win ? '✔' : '✘'} 파밍 S${stageId - 1} +${r.gold}G | ${r.party}`, r.win ? 'w' : 'l');
      }
      // 파밍 후 마지막 도전
      await reviveGrind();
      manage(stageId, C);
      const r = await runBattle(stageId, C, false); battles++;
      r.attempt = 99; r.profile = C.profile; r.combo = C.combo.join(','); r.party = partySummary(); r.goldNow = loadGold();
      AP.log.push(r); saveLog();
      out(`${r.win ? '✔' : '✘'} S${stageId} 파밍 후 재도전 턴${r.turn} | ${r.party}`, r.win ? 'w' : 'l');
      won = r.win;
      }
      if (won) { stageId++; continue; }
    }
    out(`■ S${stageId}에서 진행 불가 — 중단`, 'l'); AP.stuck = stageId; break;
  }
  out(`── 종료 (도달 S${stageId}, ${day}일차)`);
  AP.running = false; AP.lastReached = stageId; report(true);
}
function newGame() {
  Object.keys(localStorage).filter(k => k.startsWith('game_') || k === 'ps_can_start').forEach(k => localStorage.removeItem(k));
  AP.log = []; saveLog(); AP.shop = null; AP.shopAt = -99;
  const nov = JAB.novice, chars = [];
  for (let i = 0; i < 5; i++) {
    const r = mm => +(mm[0] + Math.random() * (mm[1] - mm[0])).toFixed(1), p = { hp: r(nov.growth.hp), atk: r(nov.growth.atk), def: r(nov.growth.def), actionRec: rollActionRec() };
    chars.push({ uid: i + 1, cls: 'novice', nameId: i * 7, lv: 1, exp: 0, dead: false, hp: nov.base.hp, atk: nov.base.atk, def: nov.base.def,
      move: nov.base.move, range: nov.base.range, pot: p, actionRec: nov.actionRec + p.actionRec, gender: randomGender() });
  }
  localStorage.setItem('game_roster', JSON.stringify({ chars, nextId: 6 }));
  const r = getRoster(); const c = r.chars.find(x => x.cls === COMMANDER_CLS); c.setup = true; c.gender = 'f'; saveRoster(r);
  saveParties(createDefaultParties(chars.map(c => c.uid)));
  localStorage.setItem('game_save', JSON.stringify({ gold: 2000 }));
  // 스토리 장면은 모두 본 것으로 (전투 흐름만 연구)
  const seen = {}; for (let i = 1; i <= 100; i++) ['pre', 'post', 'start', 'wave', 'boss', 'danger', 'last'].forEach(k => { seen['s' + i + '_' + k] = true; });
  for (let e = 1; e <= 10; e++) { seen['ep' + e + '_pro'] = seen['ep' + e + '_epi'] = true; }
  localStorage.setItem('game_story_seen', JSON.stringify(seen));
}

$('new').onclick = () => campaign(true);
$('cont').onclick = () => campaign(false);
$('stop').onclick = () => { AP.stopReq = true; out('정지 요청'); };
$('export').onclick = () => { const a = document.createElement('a'); a.download = 'ap_log.json'; a.href = URL.createObjectURL(new Blob([JSON.stringify(AP.log, null, 1)])); a.click(); };
if (location.hostname === 'localhost') out('⚠ localhost로 열면 실제 플레이 저장을 덮어씁니다. 127.0.0.1로 여세요.', 'l');
out('준비됨');
// 헤드리스 자동 실행: ?auto=1&profile=managed&combo=knight,priest,mage,mage,mage&from=1&to=100&fresh=1&warp=25
{ const Q = new URLSearchParams(location.search);
  if (Q.get('auto') === '1') {
    ['profile', 'from', 'to', 'retries', 'grind', 'warp', 'shopEvery', 'dayEvery'].forEach(k => { if (Q.get(k)) $(k).value = Q.get(k); });
    if (Q.get('combo')) { const c = Q.get('combo'); if (![...$('combo').options].some(o => o.value === c)) { const o = document.createElement('option'); o.value = o.textContent = c; $('combo').appendChild(o); } $('combo').value = c; }
    setTimeout(() => campaign(Q.get('fresh') !== '0'), 500);
  } }
window.AP = AP; window.campaign = campaign; window.manage = manage; window.runBattle = runBattle; window.cfg = cfg; window.dailyRun = dailyRun;
