// ═══════════════════════════════════════════
//  common/daily.js — 요일 던전
//  요일마다 정해진 직업의 영혼석 조각을 얻는 전투. 하루 DAILY.perDay회 입장(시도하면 소모).
//  난이도는 최고 클리어 스테이지로 해금되고, 높을수록 적이 강하고 조각을 많이 준다.
//  전투는 일반 전투 엔진을 그대로 쓰며 cStage.daily = { cls, tier, frags, eq } 로 구분 (보상: 조각만, 골드·클리어 기록 없음)
//  저장: localStorage game_daily = { date: 'YYYY-MM-DD', used: n }
// ═══════════════════════════════════════════
const DAILY_KEY = 'game_daily';
const DAILY = {
  perDay: 3,
  // 0=일 … 6=토. 일요일은 모든 직업 중 선택
  schedule: { 0: 'all', 1: ['warrior', 'knight'], 2: ['archer', 'lancer'], 3: ['mage', 'shaman'], 4: ['priest', 'summoner'], 5: ['assassin', 'brawler'], 6: ['sapper', 'novice'] },
  // unlock: 최고 클리어 스테이지 조건 · eq: 적 강함(같은 강함의 스테이지 번호) · frags: 승리 시 조각
  tiers: [
    { key: 'easy',   unlock: 0,  eq: 8,  frags: 3,  tot: 8,  map: 'plains' },
    { key: 'normal', unlock: 20, eq: 30, frags: 5,  tot: 12, map: 'jungle' },
    { key: 'hard',   unlock: 45, eq: 55, frags: 8,  tot: 16, map: 'canyon' },
    { key: 'hell',   unlock: 75, eq: 85, frags: 12, tot: 20, map: 'abyss' },
  ],
  // 그 직업과 함께 나오는 호위 (직업 성향에 맞춰 섞음)
  escort: { warrior: 'knight', knight: 'priest', archer: 'lancer', lancer: 'archer', mage: 'knight', shaman: 'warrior', priest: 'warrior', summoner: 'knight',
    assassin: 'brawler', brawler: 'assassin', sapper: 'lancer', novice: 'warrior' },
  CLASSES: ['warrior', 'knight', 'archer', 'lancer', 'mage', 'shaman', 'priest', 'summoner', 'assassin', 'brawler', 'sapper', 'novice'],
};
const Daily = {
  today(d) { d = d || new Date(); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); },
  _get() {
    try { const s = JSON.parse(localStorage.getItem(DAILY_KEY)); if (s && s.date === this.today()) return s; } catch (_) {}
    return { date: this.today(), used: 0 };
  },
  left() { return Math.max(0, DAILY.perDay - this._get().used); },
  consume() { const s = this._get(); s.used++; try { localStorage.setItem(DAILY_KEY, JSON.stringify(s)); } catch (_) {} },
  // 오늘 열린 직업
  classes(d) { const s = DAILY.schedule[(d || new Date()).getDay()]; return s === 'all' ? DAILY.CLASSES.slice() : s.slice(); },
  bestCleared() { try { const c = loadSave().cleared || []; return c.length ? Math.max.apply(null, c) : 0; } catch (_) { return 0; } },
  tierOpen(i) { return this.bestCleared() >= DAILY.tiers[i].unlock; },
  // 전투용 스테이지 객체 (id는 900번대: 일반 스테이지·스토리와 겹치지 않게)
  buildStage(cls, tierIdx) {
    const T = DAILY.tiers[tierIdx], k = stageSm(T.eq), esc = DAILY.escort[cls] || 'warrior';
    const main = cls, en = [];
    for (let i = 0; i < T.tot; i++) en.push(i % 3 === 2 ? esc : main);
    return {
      id: 901 + tierIdx, phase: 0, style: 'mixed', mapType: T.map, tot: T.tot, spw: Math.ceil(T.tot / 2), si: 2, boss: null,
      en, sm: { hp: k, atk: k }, daily: { cls, tier: T.key, frags: T.frags, eq: T.eq },
    };
  },
};
// 경험치 계산 등에서 쓰는 스테이지 레벨 (요일 던전은 같은 강함의 스테이지 번호)
function stageLevel(st) { return st ? (st.daily ? st.daily.eq : st.id) : 1; }
