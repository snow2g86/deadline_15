// ═══════════════════════════════════════════
//  common/soul.js — 영혼석 (직업별 영혼석 · 조각)
//  등급 승급 B→A, A→S에 대상 직업의 영혼석을 소모한다 (SOUL.promote).
//  얻는 곳: 요일 던전(조각) · 보스 스테이지 클리어 · 상점(비쌈). 조각 SOUL.fragsPerStone개 → 영혼석 1개
//  저장: localStorage game_soul = { stones: {cls: n}, frags: {cls: n} }
// ═══════════════════════════════════════════
const SOUL_KEY = 'game_soul';
const Soul = {
  _get() {
    try { const d = JSON.parse(localStorage.getItem(SOUL_KEY)); if (d && d.stones && d.frags) return d; } catch (_) {}
    return { stones: {}, frags: {} };
  },
  _set(d) { try { localStorage.setItem(SOUL_KEY, JSON.stringify(d)); } catch (_) {} },
  stones(cls) { return this._get().stones[cls] || 0; },
  frags(cls) { return this._get().frags[cls] || 0; },
  add(kind, cls, n) {
    if (!cls || !n) return;
    const d = this._get(), b = kind === 'stone' ? d.stones : d.frags;
    b[cls] = (b[cls] || 0) + n; this._set(d);
  },
  spend(cls, n) {
    if (!n) return true;
    const d = this._get(); if ((d.stones[cls] || 0) < n) return false;
    d.stones[cls] -= n; this._set(d); return true;
  },
  // 모인 조각을 영혼석으로 합침 → 새로 만든 개수
  combine(cls) {
    const d = this._get(), f = d.frags[cls] || 0, k = Math.floor(f / SOUL.fragsPerStone);
    if (!k) return 0;
    d.frags[cls] = f - k * SOUL.fragsPerStone; d.stones[cls] = (d.stones[cls] || 0) + k; this._set(d); return k;
  },
  // 이 등급에서 다음 등급으로 올릴 때 필요한 영혼석 (C는 0)
  need(grade) { return SOUL.promote[grade] || 0; },
  // 영혼석·조각을 하나라도 가진 직업 목록
  owned() { const d = this._get(); return Object.keys(Object.assign({}, d.stones, d.frags)).filter(c => (d.stones[c] || 0) + (d.frags[c] || 0) > 0); },
};
