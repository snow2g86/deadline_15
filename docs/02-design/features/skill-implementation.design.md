# Design: Skill Implementation

**Plan Reference:** `docs/01-plan/features/skill-implementation.plan.md`

---

## 1. Data Schema (js/skills.js - LEARNABLE_SKILLS)

### 1-1. Brawler

```js
brawler_flurry: {
  id: 'brawler_flurry', name: '연타', icon: '👊',
  desc: '인접 적 1인에게 3회 ATK x 0.6 연속 공격',
  cost: 40, costType: 'energy',
  cls: 'brawler'
},
brawler_crush: {
  id: 'brawler_crush', name: '파쇄', icon: '💥',
  desc: '인접 적 1인의 방어력을 무시하고 ATK x 1.0 데미지',
  cost: 50, costType: 'energy',
  cls: 'brawler'
},
brawler_counter: {
  id: 'brawler_counter', name: '역습', icon: '🔁',
  desc: '피격 시 30% 확률로 ATK x 0.5 반격',
  passive: true,
  cls: 'brawler'
},
```

### 1-2. Lancer

```js
lancer_charge: {
  id: 'lancer_charge', name: '돌격', icon: '🐎',
  desc: '일직선 3칸 내 적에게 돌진 이동 후 ATK x 1.2 공격',
  cost: 3, costType: 'fury', chargeRange: 3,
  cls: 'lancer'
},
lancer_phalanx: {
  id: 'lancer_phalanx', name: '방진', icon: '🛡️',
  desc: '2턴간 인접 2칸 이내 아군 전원 DEF +5',
  cost: 4, costType: 'fury', phalanxRange: 2,
  cls: 'lancer'
},
lancer_spearwall: {
  id: 'lancer_spearwall', name: '창벽', icon: '🔱',
  desc: '적이 인접 칸으로 이동 시 ATK x 0.5 자동 공격 (턴당 1회)',
  passive: true,
  cls: 'lancer'
},
```

### 1-3. Summoner

```js
summoner_empower: {
  id: 'summoner_empower', name: '소환 강화', icon: '⬆️',
  desc: '자신의 소환수 1체를 3턴간 ATK x 1.5로 강화',
  cost: 40, costType: 'mana', empowerRange: 5,
  cls: 'summoner'
},
summoner_soulburst: {
  id: 'summoner_soulburst', name: '영혼 폭발', icon: '💫',
  desc: '자신의 소환수를 희생, 소환수 기준 3x3 범위 적에게 소환수 ATK x 3.0',
  cost: 60, costType: 'mana', burstRange: 5,
  cls: 'summoner'
},
summoner_soulbond: {
  id: 'summoner_soulbond', name: '영적 유대', icon: '🔗',
  desc: '소환수 소멸 시 마나 40 회복',
  passive: true,
  cls: 'summoner'
},
```

### 1-4. Shaman

```js
shaman_poisonmist: {
  id: 'shaman_poisonmist', name: '독안개', icon: '☁️',
  desc: '대상 중심 3x3 범위에 독안개 설치, 3턴간 매턴 ATK x 0.3 데미지',
  cost: 50, costType: 'mana', mistRange: 5,
  cls: 'shaman'
},
shaman_spiritsurge: {
  id: 'shaman_spiritsurge', name: '영혼 쇄도', icon: '👻',
  desc: '5칸 내 적 1인에게 ATK x 1.0 데미지 + 1턴 이동 불가',
  cost: 40, costType: 'mana', surgeRange: 5,
  cls: 'shaman'
},
shaman_medium: {
  id: 'shaman_medium', name: '영매', icon: '🔮',
  desc: '채널링 중 피격으로 채널링이 해제되지 않음',
  passive: true,
  cls: 'shaman'
},
```

### 1-5. Sapper

```js
sapper_detonate: {
  id: 'sapper_detonate', name: '폭파', icon: '🧨',
  desc: '5칸 내 아군 함정 1개를 즉시 폭발, 인접 적에게 함정 데미지 x 1.5',
  cost: 30, costType: 'energy', detonateRange: 5,
  cls: 'sapper'
},
sapper_enhancedtrap: {
  id: 'sapper_enhancedtrap', name: '강화 함정', icon: '⚙️',
  desc: '함정 데미지 30% 증가, 스턴 지속 +1턴',
  passive: true,
  cls: 'sapper'
},
```

### 1-6. Mage

```js
mage_manasurge: {
  id: 'mage_manasurge', name: '마나 쇄도', icon: '🌊',
  desc: '마나 80% 이상 시 마법 데미지 20% 증가',
  passive: true,
  cls: 'mage'
},
```

### 1-7. Priest

```js
priest_divinegrace: {
  id: 'priest_divinegrace', name: '신의 은총', icon: '🕊️',
  desc: '모든 회복량 20% 증가',
  passive: true,
  cls: 'priest'
},
```

---

## 2. Skill Handlers (js/skills/{class}.js)

### 2-1. brawler.js - 연타 (brawler_flurry)

```
target(u, sk, G):
  return G.units.filter(적, 인접 1칸, hp>0).map({x,y})

exec(u, tx, ty, sk, G):
  tgt = find enemy at (tx,ty)
  if !tgt → _skillRefund
  hits = 3
  totalDmg = 0
  for i in 0..hits-1:
    if tgt.hp <= 0 → break
    dmg = max(1, round(u.atk * 0.6 * G.skMul(u,'brawler_flurry')) - tgt.def)
    tgt.hp = max(0, tgt.hp - dmg)
    totalDmg += dmg
    vfxSpawn(tgt, orange spark)
  sfxAtk, shakeU(tgt)
  floatT(tgt, -totalDmg, 'damage')
  floatT(u, '연타!', 'heal')
  if tgt.hp<=0 → death sequence
  _grantExp(u, 'attack')
  _skillDone(u, G, {delay:500, rmDead:true, chkEnd:true})
```

### 2-2. brawler.js - 파쇄 (brawler_crush)

```
target(u, sk, G):
  return G.units.filter(적, 인접 1칸, hp>0).map({x,y})

exec(u, tx, ty, sk, G):
  tgt = find enemy at (tx,ty)
  if !tgt → _skillRefund
  dmg = max(1, round(u.atk * 1.0 * G.skMul(u,'brawler_crush')))
  // DEF 무시: tgt.def를 빼지 않음
  tgt.hp = max(0, tgt.hp - dmg)
  sfxAtk, shakeU(tgt)
  floatT(tgt, -dmg, 'damage')
  floatT(u, '파쇄!', 'heal')
  if tgt.hp<=0 → death sequence
  _grantExp(u, 'attack')
  _skillDone(u, G, {delay:500, rmDead:true, chkEnd:true})
```

### 2-3. lancer.js - 돌격 (lancer_charge)

```
target(u, sk, G):
  4방향(N,E,S,W) 일직선 탐색
  각 방향마다 1~3칸(chargeRange) 내 첫 번째 적 위치 반환
  return [{x,y}] (적이 있는 타일만)

exec(u, tx, ty, sk, G):
  tgt = find enemy at (tx,ty)
  if !tgt → _skillRefund
  // 적 인접 빈 칸으로 이동
  adj = G._findAdj(tgt.x, tgt.y, u)
  if !adj → _skillRefund + 메시지
  u.x=adj.x; u.y=adj.y; u.mo=true
  animU(u.id, adj.x, adj.y)
  setTimeout(300ms):
    dmg = max(1, round(u.atk * 1.2 * G.skMul(u,'lancer_charge')) - tgt.def)
    tgt.hp = max(0, tgt.hp - dmg)
    sfxAtk, shakeU(tgt)
    floatT(tgt, -dmg, 'damage')
    floatT(u, '돌격!', 'heal')
    procFury(u, tgt, G)
    if tgt.hp<=0 → death sequence
    _grantExp(u, 'attack')
    _skillDone(u, G, {delay:500, rmDead:true, chkEnd:true})
```

### 2-4. lancer.js - 방진 (lancer_phalanx)

```
target(u, sk, G): return 'instant'

exec(u, tx, ty, sk, G):
  range = sk.phalanxRange || 2
  allies = G.units.filter(ally, hp>0, id!=u.id, mh<=range)
  if !allies.length → _skillRefund
  allies.forEach(a):
    a._phalanxTurns = 2
    a._phalanxDef = 5
    vfxSpawn(a, blue ring)
  u._phalanxTurns = 2; u._phalanxDef = 5
  sfxHeal()
  floatT(u, '방진!', 'heal')
  procFury(u, u, G)
  _grantExp(u, 'attack')
  _skillDone(u, G)
```

### 2-5. summoner.js - 소환 강화 (summoner_empower)

```
target(u, sk, G):
  summons = G.units.filter(isSummon, summonerId===u.id, hp>0)
  if !summons.length → return null (메시지: 소환수 없음)
  return summons.map({x,y})

exec(u, tx, ty, sk, G):
  summon = find summon at (tx,ty) with summonerId===u.id
  if !summon → _skillRefund
  summon._empowerTurns = 3
  summon._empowerMul = 1.5
  sfxHeal()
  floatT(summon, '강화!', 'heal')
  vfxSpawn(summon, gold ring)
  _grantExp(u, 'attack')
  _skillDone(u, G)
```

### 2-6. summoner.js - 영혼 폭발 (summoner_soulburst)

```
target(u, sk, G):
  summons = G.units.filter(isSummon, summonerId===u.id, hp>0)
  if !summons.length → return null
  return summons.map({x,y})

exec(u, tx, ty, sk, G):
  summon = find summon at (tx,ty) with summonerId===u.id
  if !summon → _skillRefund
  burstAtk = summon.atk * 3
  // 3x3 AoE from summon position
  for dx=-1..1, dy=-1..1:
    tgt = find enemy at (summon.x+dx, summon.y+dy)
    if tgt:
      dmg = max(1, burstAtk - tgt.def)
      tgt.hp = max(0, tgt.hp - dmg)
      floatT(tgt, -dmg, 'damage'); shakeU(tgt)
      vfxSpawn(tgt, purple spark)
      if tgt.hp<=0 → death sequence
  // 소환수 제거
  floatT(summon, '영혼 폭발!', 'damage')
  vfxDeath(summon)
  units = units.filter(v => v.id !== summon.id)
  sfxAtk(u.cls)
  _grantExp(u, 'attack')
  _skillDone(u, G, {delay:500, rmDead:true, chkEnd:true})
```

### 2-7. shaman.js - 독안개 (shaman_poisonmist)

```
target(u, sk, G):
  range = sk.mistRange || 5
  cells = all cells within range
  return cells

exec(u, tx, ty, sk, G):
  if !G.poisonMists → G.poisonMists = []
  G.poisonMists.push({
    cx: tx, cy: ty,   // 중심 좌표
    atk: u.atk,       // 시전자 ATK (데미지 계산용)
    turns: 3,          // 지속 턴
    team: 'ally'       // 아군이 설치
  })
  sfxAtk(u.cls)
  floatT(tx, ty, '독안개!', 'heal')
  vfxSpawn(center, green ring)
  _grantExp(u, 'attack')
  _skillDone(u, G)
```

### 2-8. shaman.js - 영혼 쇄도 (shaman_spiritsurge)

```
target(u, sk, G):
  range = sk.surgeRange || 5
  return G.units.filter(적, mh<=range, hp>0).map({x,y})

exec(u, tx, ty, sk, G):
  tgt = find enemy at (tx,ty)
  if !tgt → _skillRefund
  dmg = max(1, round(u.atk * 1.0 * G.skMul(u,'shaman_spiritsurge')) - tgt.def)
  tgt.hp = max(0, tgt.hp - dmg)
  tgt._rootedTurns = 1  // 1턴 이동 불가
  sfxAtk(u.cls); shakeU(tgt)
  floatT(tgt, -dmg, 'damage')
  floatT(tgt, '이동 불가!', 'debuff')
  floatT(u, '영혼 쇄도!', 'heal')
  vfxSpawn(tgt, purple spark)
  if tgt.hp<=0 → death sequence
  _grantExp(u, 'attack')
  _skillDone(u, G, {delay:500, rmDead:true, chkEnd:true})
```

### 2-9. sapper.js - 폭파 (sapper_detonate)

```
target(u, sk, G):
  range = sk.detonateRange || 5
  allyTraps = G.traps.filter(tr => tr.team==='ally' && mh(u,tr)<=range)
  return allyTraps.map({x,y})

exec(u, tx, ty, sk, G):
  trap = G.traps.find(tr => tr.x===tx && tr.y===ty && tr.team==='ally')
  if !trap → _skillRefund
  // 함정 기준 인접 8칸 적에게 데미지
  burstDmg = round(trap.dmg * 1.5)
  dirs = 8방향 + 자기 칸
  dirs.forEach(d):
    tgt = find enemy at (trap.x+d.x, trap.y+d.y)
    if tgt:
      tgt.hp = max(0, tgt.hp - max(1, burstDmg - tgt.def))
      floatT, shakeU, vfx
      if tgt.hp<=0 → death sequence
  // 함정 제거
  G.traps = G.traps.filter(tr => tr !== trap)
  sfxAtk(u.cls)
  floatT(tx, ty, '폭파!', 'heal')
  _grantExp(u, 'attack')
  _skillDone(u, G, {delay:500, rmDead:true, chkEnd:true})
```

---

## 3. Passive Systems (_common.js / battle flow)

### 3-1. brawler_counter - 역습

**Trigger Point:** `js/battle/combat.js` - `doAtk()` 반격 로직 이후

```
현재 doAtk() 반격 조건 (line 81):
  if (tgt.hp>0 && a.hp>0 && mh(tgt,a)<=tgt.range && !stunned && !frozen)
    → 기존 반격 실행

추가 로직 (doAtk 내, 기존 반격 이후):
  if (tgt.hp>0 && a.hp>0 && tgt.cls==='brawler'
      && tgt.skillLv?.brawler_counter >= 1
      && Math.random() < 0.3):
    counterDmg = max(1, round(tgt.atk * 0.5) - a.def)
    a.hp = max(0, a.hp - counterDmg)
    floatT(a, -counterDmg, 'damage')
    floatT(tgt, '역습!', 'heal')
    vfxSpawn(a, orange spark)
    if a.hp<=0 → death
```

**Note:** 기존 반격 코드의 else 분기에 배치. 인접(range 1) + 스턴/빙결 아닌 경우에만 발동. 기존 반격은 "자신이 공격당했을 때" tgt가 반격하는 구조이므로, 동일한 위치에 brawler_counter 검사를 추가.

### 3-2. lancer_spearwall - 창벽

**Trigger Point:** `js/battle/ai.js` - 적 이동 완료 후 (`eMv` 내 `_mvU` 직후)

```
적 이동 시 (_mvU 후 chkTrap 전):
  adjacentLancers = G.alive('ally').filter(a =>
    a.cls==='lancer' && a.hp>0
    && a.skillLv?.lancer_spearwall >= 1
    && !a._spearwallUsed   // 턴당 1회
    && mh(a, u) <= 1       // 이동 후 적과 인접
  )
  adjacentLancers.forEach(lancer):
    dmg = max(1, round(lancer.atk * 0.5) - u.def)
    u.hp = max(0, u.hp - dmg)
    floatT(u, -dmg, 'damage')
    floatT(lancer, '창벽!', 'heal')
    vfxSpawn(u, blue spark)
    lancer._spearwallUsed = true
    if u.hp<=0 → death
```

**Reset:** 아군 턴 시작 시 (`js/battle/ai.js` line ~68 부근, `u.hm=false` 초기화 코드)

```
if (u.cls==='lancer') u._spearwallUsed = false;
```

### 3-3. lancer_ironphalanx - 철벽 (Fury Passive)

**Location:** `js/skills/_common.js` - `FURY_PASSIVES` 객체

```js
lancer: {
  name: '철벽', icon: '🏰',
  desc: '2턴간 방어력 2배',
  trigger(defender, attacker, G) {
    defender.defBuff = 2; defender.res = 0;
    G.floatT(defender.x, defender.y, t('passives.iron_phalanx_activated'), 'heal');
    G.vfxSpawn(G.uSX(defender.x, defender.y)+UCX, G.uSY(defender.x, defender.y)+UCY,
      {count:15, colors:['#60a5fa','#3b82f6','#fff'], shape:'ring', speed:3, spread:14, decay:0.02, size:6});
  }
}
```

**Note:** knight의 `철의 의지`와 동일 구조 (defBuff = 2). 기존 `calcDmg()`에서 `defBuff > 0`이면 DEF x 1.5 적용 → lancer도 자동 혜택.

### 3-4. lancer_phalanx - 방진 버프 틱

**Location:** `js/skills/_common.js` - `tickBuffs()` 에 추가

```js
if (unit._phalanxTurns > 0) {
  unit._phalanxTurns--;
  if (unit._phalanxTurns <= 0) { unit._phalanxDef = 0; }
}
```

**Location:** `js/skills/_common.js` - `calcDmg()` 에 추가

```js
if (target._phalanxDef > 0) def += target._phalanxDef;
```

### 3-5. summoner_soulbond - 영적 유대

**Trigger Point:** `js/battle/ai.js` - 소환수 소멸 시 (2곳)

1. **턴당 소멸** (line ~56-63): `u.summonTurns <= 0` 분기
2. **소환사 사망 시** (line ~382-388): `chkEnd()` 내 소환수 제거

```
소환수 소멸 시:
  summoner = G.units.find(v => v.id===u.summonerId && v.hp>0)
  if summoner && summoner.skillLv?.summoner_soulbond >= 1:
    summoner.res = min(summoner.maxRes, summoner.res + 40)
    floatT(summoner, '+40 MP', 'heal')
    vfxSpawn(summoner, purple ring)
```

### 3-6. summoner_empower - 소환 강화 버프 틱

**Location:** `js/skills/_common.js` - `tickBuffs()`

```js
if (unit._empowerTurns > 0) {
  unit._empowerTurns--;
  if (unit._empowerTurns <= 0) { unit._empowerMul = 0; }
}
```

**Location:** `js/skills/_common.js` - `calcDmg()`

```js
if (attacker.isSummon && attacker._empowerMul > 0) {
  atk = Math.round(atk * attacker._empowerMul);
}
```

### 3-7. shaman_medium - 영매

**Note:** 현재 코드에서 채널링은 사망 시에만 자동 해제됨 (별도 "피격 시 해제" 로직 없음). 따라서 영매 패시브는 **추후 채널링 방해 메커니즘이 추가될 때** 의미를 가짐. 현재는 데이터만 등록하고, 실질적 코드 변경 없이 **getSkillBuffs()에 아이콘만 추가**.

### 3-8. shaman_poisonmist - 독안개 영역 틱

**Trigger Point:** `js/battle/ai.js` - 아군 턴 시작 시 (tickBuffs 호출 부근)

```
if (G.poisonMists && G.poisonMists.length > 0):
  G.poisonMists.forEach(mist):
    for dx=-1..1, dy=-1..1:
      tgt = find enemy at (mist.cx+dx, mist.cy+dy)
      if tgt:
        dmg = max(1, round(mist.atk * 0.3))
        tgt.hp = max(0, tgt.hp - dmg)
        floatT(tgt, -dmg, 'damage')
        vfxSpawn(tgt, green spark)
        if tgt.hp<=0 → death
    mist.turns--
  G.poisonMists = G.poisonMists.filter(m => m.turns > 0)
```

### 3-9. shaman_spiritsurge - _rootedTurns 처리

**Location:** `js/skills/_common.js` - `tickBuffs()`

```js
if (unit._rootedTurns > 0) unit._rootedTurns--;
```

**Location:** `js/battle/ai.js` - 적 이동 함수 (`eMv`, `eMvC`)

```
적 이동 계산 시: if (u._rootedTurns > 0) return; // 이동 불가
```

### 3-10. sapper_enhancedtrap - 강화 함정

**Trigger Point:** `js/skills/sapper.js` - 함정 설치 핸들러 (`sapper_trap` exec)

```
기존: G.traps.push({x, y, dmg: u.atk*2, id, team:'ally'})
수정:
  let trapDmg = u.atk * 2;
  let trapStun = 2;
  if (u.skillLv?.sapper_enhancedtrap >= 1) {
    trapDmg = round(trapDmg * 1.3);
    trapStun = 3;
  }
  G.traps.push({x, y, dmg: trapDmg, stun: trapStun, id, team:'ally'})
```

**Note:** `chkTrap`에서 `stun` 값을 사용하도록 수정 필요 (현재 하드코딩 2턴).

### 3-11. mage_manasurge - 마나 쇄도

**Location:** `js/skills/_common.js` - `calcDmg()`

```js
if (attacker.cls === 'mage' && attacker.skillLv?.mage_manasurge >= 1
    && attacker.res >= attacker.maxRes * 0.8) {
  dmg = Math.round(dmg * 1.2);
}
```

### 3-12. priest_divinegrace - 신의 은총

**Trigger Points:** 모든 힐 로직에 적용

1. `js/battle/combat.js` - `doHeal()` (기본 힐)
2. `js/skills/priest.js` - `priest_massheal` exec (집단 치유)
3. `js/skills/priest.js` - `priest_sanctuary` exec (성역선포 healAmt 계산)

```
기존: const amt = Math.round(h.atk * 1.5)
수정:
  let amt = Math.round(h.atk * 1.5);
  if (h.skillLv?.priest_divinegrace >= 1) amt = Math.round(amt * 1.2);
```

---

## 4. UI Updates (js/battle/ui.js + _common.js)

### 4-1. getSkillBuffs() 추가 항목

```js
// _phalanx (방진 버프)
if (unit._phalanxTurns > 0)
  buffs.push({ icon: '🛡️', type: 'buff', turns: unit._phalanxTurns });

// _empowerMul (소환 강화)
if (unit.isSummon && unit._empowerTurns > 0)
  buffs.push({ icon: '⬆️', type: 'buff', turns: unit._empowerTurns });

// _rootedTurns (이동 불가)
if (unit._rootedTurns > 0)
  buffs.push({ icon: '🌿', type: 'debuff', turns: unit._rootedTurns });

// lancer_spearwall (패시브 표시)
if (unit.cls === 'lancer' && unit.skillLv?.lancer_spearwall >= 1)
  buffs.push({ icon: '🔱', type: 'buff', turns: 0 });

// brawler_counter (패시브 표시)
if (unit.cls === 'brawler' && unit.skillLv?.brawler_counter >= 1)
  buffs.push({ icon: '🔁', type: 'buff', turns: 0 });

// shaman_medium (패시브 표시)
if (unit.cls === 'shaman' && unit.skillLv?.shaman_medium >= 1 && unit.channeling)
  buffs.push({ icon: '🔮', type: 'buff', turns: 0 });

// sapper_enhancedtrap (패시브 표시)
if (unit.cls === 'sapper' && unit.skillLv?.sapper_enhancedtrap >= 1)
  buffs.push({ icon: '⚙️', type: 'buff', turns: 0 });

// mage_manasurge (조건부 표시)
if (unit.cls === 'mage' && unit.skillLv?.mage_manasurge >= 1
    && unit.res >= unit.maxRes * 0.8)
  buffs.push({ icon: '🌊', type: 'buff', turns: 0 });

// priest_divinegrace (패시브 표시)
if (unit.cls === 'priest' && unit.skillLv?.priest_divinegrace >= 1)
  buffs.push({ icon: '🕊️', type: 'buff', turns: 0 });
```

---

## 5. Battle Save/Load

`G.poisonMists` 배열을 전투 저장 데이터에 포함해야 함.

**Location:** `js/battle/core.js` - save/load 함수

```
save: data.poisonMists = G.poisonMists || []
load: G.poisonMists = data.poisonMists || []
```

유닛별 신규 필드는 기존 유닛 직렬화에 자동 포함 (JSON.stringify):
- `_phalanxTurns`, `_phalanxDef`
- `_empowerTurns`, `_empowerMul`
- `_rootedTurns`
- `_spearwallUsed`

---

## 6. Implementation Order

```
1. js/skills.js         — LEARNABLE_SKILLS 16개 데이터 추가
2. js/skills/_common.js — FURY_PASSIVES.lancer, tickBuffs, calcDmg, getSkillBuffs
3. js/skills/brawler.js — flurry, crush 핸들러
4. js/skills/lancer.js  — charge, phalanx 핸들러
5. js/skills/summoner.js — empower, soulburst 핸들러
6. js/skills/shaman.js  — poisonmist, spiritsurge 핸들러
7. js/skills/sapper.js  — detonate 핸들러 + enhancedtrap 로직
8. js/battle/combat.js  — brawler_counter 반격 로직
9. js/battle/ai.js      — lancer_spearwall 트리거 + soulbond 트리거 + poisonmist 틱 + rooted 이동 제한
10. js/skills/priest.js — divinegrace 힐 보정
11. js/battle/core.js   — poisonMists save/load
```

---

## 7. Verification Checklist

- [ ] 16개 LEARNABLE_SKILLS 데이터가 올바른 형식인가
- [ ] 모든 active 스킬의 target/exec가 registerSkill로 등록되었는가
- [ ] 모든 passive가 적절한 트리거 포인트에 연결되었는가
- [ ] tickBuffs()에 신규 버프 틱이 추가되었는가
- [ ] calcDmg()에 passive 보정이 추가되었는가
- [ ] getSkillBuffs()에 신규 버프 아이콘이 추가되었는가
- [ ] 독안개(poisonMists)가 전투 저장/로드에 포함되었는가
- [ ] 적 이동 시 _rootedTurns 확인이 추가되었는가
- [ ] 브라우저 콘솔 에러가 없는가
- [ ] 기존 스킬이 정상 동작하는가 (regression 없음)
