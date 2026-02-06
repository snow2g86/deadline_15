// ═══════════════════════════════════════════
//  roster.js — 보유 캐릭터 관리
//  유저의 캐릭터 데이터를 localStorage로 관리
// ═══════════════════════════════════════════

const ROSTER = {
  _key: 'game_roster',
  _data: null, // { chars:[], nextId:1 }

  // ── 로드/세이브 ─────────────────────────
  load() {
    try {
      const raw = localStorage.getItem(this._key);
      if (raw) {
        this._data = JSON.parse(raw);
        // 이름 없는 캐릭터에 랜덤 이름 부여 (마이그레이션)
        const used = new Set(this._data.chars.filter(c=>c.name).map(c=>c.name));
        this._data.chars.forEach(c=>{
          if(!c.name){
            let nm;
            do{nm=NAMES[Math.floor(Math.random()*NAMES.length)]}while(used.has(nm));
            used.add(nm);c.name=nm;
          }
        });
        this.save();
        return;
      }
    } catch(e) {}
    // 첫 실행: 기본 캐릭터 지급
    this._data = { chars: [], nextId: 1 };
    this.grantStarter();
    this.save();
  },
  save() {
    try { localStorage.setItem(this._key, JSON.stringify(this._data)); } catch(e) {}
  },

  // ── 첫 실행 기본 지급 ──────────────────
  grantStarter() {
    const TEST_MODE = false; // true: 모든 클래스 1명씩, false: 노비스 5명
    const used = new Set();

    if (TEST_MODE) {
      // 테스트 모드: 모든 12개 클래스 1명씩 지급
      const starters = ['novice','warrior','knight','assassin','archer','mage','priest','sapper','summoner','shaman','brawler','lancer'];
      starters.forEach(cls => {
        let name;
        do { name = NAMES[Math.floor(Math.random()*NAMES.length)]; } while(used.has(name));
        used.add(name);
        this.addChar(cls, name);
      });
    } else {
      // 실제 모드: 노비스 5명 지급
      for(let i = 0; i < 5; i++) {
        let name;
        do { name = NAMES[Math.floor(Math.random()*NAMES.length)]; } while(used.has(name));
        used.add(name);
        this.addChar('novice', name);
      }
    }
  },

  // ── 캐릭터 추가 (뽑기/보상) ─────────────
  addChar(cls, name) {
    const d = CD[cls];
    if (!d) return null;
    const pot = this._rollPotential(cls);
    // 기본 스탯에 ±20% 랜덤 변동 추가 (개성화)
    const vary = (val) => Math.round(val * (0.8 + Math.random() * 0.4));
    const ch = {
      uid: this._data.nextId++,
      cls,
      name: name || '',
      lv: 1,
      exp: 0,
      dead: false,
      hp:   vary(d.base.hp),
      atk:  vary(d.base.atk),
      def:  vary(d.base.def),
      move: d.base.move,
      range:d.base.range,
      pot
    };
    this._data.chars.push(ch);
    this.save();
    return ch;
  },

  // ── 잠재력 랜덤 결정 ──────────────────
  _rollPotential(cls) {
    const g = CD[cls].growth;
    const roll = ([min,max]) => min + Math.random() * (max - min);
    return {
      hp:   +roll(g.hp).toFixed(1),
      atk:  +roll(g.atk).toFixed(1),
      def:  +roll(g.def).toFixed(1)
    };
  },

  // ── 레벨업 ─────────────────────────────
  levelUp(uid) {
    const ch = this.getChar(uid);
    if (!ch) return null;
    ch.lv++;
    ch.hp  = Math.round(ch.hp  + ch.pot.hp);
    ch.atk = Math.round(ch.atk + ch.pot.atk);
    ch.def = Math.round(ch.def + ch.pot.def);
    this.save();
    return ch;
  },

  // ── 경험치 획득 (다중 레벨업) ──────────
  gainExp(uid, amount) {
    const ch = this.getChar(uid);
    if (!ch || ch.lv >= MAX_LEVEL) return { leveled: 0, prevLv: ch ? ch.lv : 0 };
    const prevLv = ch.lv;
    ch.exp = (ch.exp || 0) + amount;
    let leveled = 0;
    while (ch.lv < MAX_LEVEL) {
      const need = expForLevel(ch.lv);
      if (ch.exp < need) break;
      ch.exp -= need;
      this.levelUp(uid);
      leveled++;
    }
    if (ch.lv >= MAX_LEVEL) ch.exp = 0;
    this.save();
    return { leveled, prevLv };
  },

  // ── 조회 ───────────────────────────────
  getChar(uid) { return this._data.chars.find(c => c.uid === uid) },
  getAll()     { return this._data.chars },
  getAlive()   { return this._data.chars.filter(c => !c.dead) },
  getDead()    { return this._data.chars.filter(c => c.dead) },
  getByCls(cls){ return this._data.chars.filter(c => c.cls === cls) },

  markDead(uid) {
    const ch = this.getChar(uid);
    if (ch) { ch.dead = true; this.save(); }
  },
  revive(uid) {
    const ch = this.getChar(uid);
    if (ch) { ch.dead = false; this.save(); }
  },

  // ── 삭제 (합성/방출 등) ─────────────────
  removeChar(uid) {
    this._data.chars = this._data.chars.filter(c => c.uid !== uid);
    this.save();
  },

  // ── 전투용 스탯 계산 ──────────────────
  // 보유 캐릭터 → 전투 유닛 스탯 변환
  toBattleStats(uid) {
    const ch = this.getChar(uid);
    if (!ch) return null;
    const d = CD[ch.cls];
    return {
      uid:     ch.uid,
      cls:     ch.cls,
      lv:      ch.lv,
      hp:      ch.hp,
      mhp:     ch.hp,
      atk:     ch.atk,
      def:     ch.def,
      move:    ch.move,
      range:   ch.range,
      role:    d.role,
      res:     d.res === 'mana' ? d.maxRes : 0,
      maxRes:  d.maxRes,
      resType: d.res,
      resRec:  d.resRec,
    };
  },

  // ── 잠재력 등급 평가 ──────────────────
  // S/A/B/C 등급 (growth 범위 내 위치 기준)
  potGrade(uid) {
    const ch = this.getChar(uid);
    if (!ch) return null;
    const g = CD[ch.cls].growth;
    const scores = ['hp','atk','def'].map(k => {
      const [min,max] = g[k];
      const range = max - min;
      return range > 0 ? (ch.pot[k] - min) / range : 0.5;
    });
    const avg = scores.reduce((a,b) => a+b, 0) / scores.length;
    if (avg >= 0.85) return 'S';
    if (avg >= 0.65) return 'A';
    if (avg >= 0.35) return 'B';
    return 'C';
  },

  // ── Lv N 예상 스탯 미리보기 ────────────
  previewAt(uid, targetLv) {
    const ch = this.getChar(uid);
    if (!ch || targetLv <= ch.lv) return null;
    const lvGain = targetLv - 1; // Lv1부터의 총 상승
    const d = CD[ch.cls];
    return {
      hp:  Math.round(d.base.hp  + ch.pot.hp  * lvGain),
      atk: Math.round(d.base.atk + ch.pot.atk * lvGain),
      def: Math.round(d.base.def + ch.pot.def * lvGain)
    };
  },

  // ── 전직 관련 메서드 ────────────────────
  _rollPotentialWithGrade(cls, targetGrade) {
    const g = CD[cls].growth;
    const targetMin = targetGrade === 'S' ? 0.85 : targetGrade === 'A' ? 0.65 : targetGrade === 'B' ? 0.35 : 0;
    const targetMax = targetGrade === 'S' ? 1.0 : targetGrade === 'A' ? 0.85 : targetGrade === 'B' ? 0.65 : 0.35;

    for (let attempt = 0; attempt < 100; attempt++) {
      const pot = this._rollPotential(cls);
      const scores = ['hp', 'atk', 'def'].map(k => {
        const [min, max] = g[k];
        const range = max - min;
        return range > 0 ? (pot[k] - min) / range : 0.5;
      });
      const avg = scores.reduce((a, b) => a + b, 0) / scores.length;
      if (avg >= targetMin && avg < targetMax) return pot;
    }

    const mid = (targetMin + targetMax) / 2;
    return {
      hp: +(g.hp[0] + (g.hp[1] - g.hp[0]) * mid).toFixed(1),
      atk: +(g.atk[0] + (g.atk[1] - g.atk[0]) * mid).toFixed(1),
      def: +(g.def[0] + (g.def[1] - g.def[0]) * mid).toFixed(1)
    };
  },

  previewClassChange(uid, newCls) {
    const ch = this.getChar(uid);
    if (!ch || ch.cls !== 'novice') return null;

    const newD = CD[newCls];
    const grade = this.potGrade(uid);
    const newPot = this._rollPotentialWithGrade(newCls, grade);

    const gradeMultiplier = grade === 'S' ? 1.1 : grade === 'A' ? 1.0 : grade === 'B' ? 0.9 : 0.8;
    const baseHP = Math.round(newD.base.hp * gradeMultiplier);
    const baseATK = Math.round(newD.base.atk * gradeMultiplier);
    const baseDEF = Math.round(newD.base.def * gradeMultiplier);

    const lvGain = ch.lv - 1;

    return {
      hp: Math.round(baseHP + newPot.hp * lvGain),
      atk: Math.round(baseATK + newPot.atk * lvGain),
      def: Math.round(baseDEF + newPot.def * lvGain),
      move: newD.base.move,
      range: newD.base.range,
      pot: newPot
    };
  },

  changeClass(uid, newCls) {
    const ch = this.getChar(uid);
    if (!ch || ch.cls !== 'novice') return false;

    const preview = this.previewClassChange(uid, newCls);
    if (!preview) return false;

    ch.cls = newCls;
    ch.hp = preview.hp;
    ch.atk = preview.atk;
    ch.def = preview.def;
    ch.move = preview.move;
    ch.range = preview.range;
    ch.pot = preview.pot;

    this.save();
    return true;
  },

  // ── 디버그/리셋 ────────────────────────
  reset() {
    localStorage.removeItem(this._key);
    this._data = null;
    this.load();
  }
};
