# Skill Balance Analysis Report

## 1. Current Skill Inventory

| Class | Base Skill | Learnable Active | Passive | Total | Assessment |
|-------|-----------|-----------------|---------|-------|-----------|
| Warrior | 1 (강타) | 3 (휘두르기, 강습, 치명적인 일격) | 2 (광폭, 피의 갈망) | **6** | Excellent |
| Knight | 1 (스위치) | 3 (차징, 희생, 포획) | 3 (철의 의지, 고통 분담, 강인한) | **7** | Excellent |
| Archer | 1 (도약) | 3 (저격, 연속사격, 강철비) | 1 (약점포착) | **5** | Good |
| Assassin | 1 (암살) | 1 (습격) | 2 (은신, 함정감지) | **4** | Good |
| Mage | 1 (화염폭발) | 2 (빙결, 그랜드 월) | 0 | **3** | Passive 부족 |
| Priest | 1 (집단 치유) | 2 (정화, 성역선포) | 0 | **3** | Passive 부족 |
| Sapper | 1 (함정 설치) | 1 (굴착) | 0 | **2** | Lacking |
| Summoner | 2 (정령/골램 소환) | 0 | 0 | **2** | Lacking |
| Shaman | 2 (저주/고양) | 0 | 0 | **2** | Lacking |
| Brawler | 1 (무장해제) | 0 | 0 | **1** | Critical |
| Lancer | 1 (관통) | 0 | 0 | **1** | Critical |
| Novice | 1 (돌던지기) | 0 | 0 | **1** | Intentional |

---

## 2. Skill Gap Summary

### Tier A - Well Covered (4+ skills)
- **Warrior**: 6 skills (1 base + 3 active + 2 passive)
- **Knight**: 7 skills (1 base + 3 active + 3 passive)
- **Archer**: 5 skills (1 base + 3 active + 1 passive)
- **Assassin**: 4 skills (1 base + 1 active + 2 passive)

### Tier B - Moderate (2-3 skills, passive 없음)
- **Mage**: 3 active skills, 0 passive
- **Priest**: 3 active skills, 0 passive
- **Sapper**: 2 active skills, 0 passive
- **Summoner**: 2 base skills, 0 learnable
- **Shaman**: 2 base skills (채널링), 0 learnable

### Tier C - Critical (1 skill only)
- **Brawler**: 1 base skill, 0 learnable, 0 passive
- **Lancer**: 1 base skill, 0 learnable, 0 passive

### Tier D - Intentional
- **Novice**: 전직 대상 클래스. 약함이 설계 의도.

---

## 3. Recommended New Skills

---

### 3-1. Brawler (무투가) - Priority: HIGH

**Resource:** Energy (100, regen 12)
**Role:** Melee DPS / Debuffer
**Identity:** 맨손 격투, 연속 공격, 근접 제압

| # | Skill Name | Type | Cost | Description |
|---|-----------|------|------|-------------|
| 1 | **연타 (Flurry)** | Active | EP 40 | 인접 적 1인에게 3회 ATK x 0.6 연속 공격. 각 타격마다 데미지 독립 계산 |
| 2 | **파쇄 (Crush)** | Active | EP 50 | 인접 적 1인의 방어력을 무시하고 ATK x 1.0 데미지 (DEF 관통) |
| 3 | **역습 (Counter)** | Passive | - | 피격 시 30% 확률로 ATK x 0.5 반격 데미지 |

**Design Notes:**
- 연타: brawler의 핵심 아이덴티티. 고ATK(32) + 다단히트로 단일 대상 DPS 극대화
- 파쇄: 고DEF 적(기사 등) 상대 시 유효. DEF 무시로 중장갑 적 카운터
- 역습: 근접 클래스의 생존성 보완. 전투 중 자동 발동으로 DPS 간접 상승

---

### 3-2. Lancer (창술사) - Priority: HIGH

**Resource:** Fury (5, no regen)
**Role:** Melee Tank-DPS Hybrid
**Identity:** 창 진형, 방어적 근접, 진형 유지

| # | Skill Name | Type | Cost | Description |
|---|-----------|------|------|-------------|
| 1 | **창벽 (Spear Wall)** | Passive | - | 적이 인접 칸으로 이동해 올 때 자동으로 ATK x 0.5 공격 (턴당 1회) |
| 2 | **돌격 (Lance Charge)** | Active | Fury 3 | 일직선 3칸 내 적에게 돌진 이동 후 ATK x 1.2 공격 |
| 3 | **방진 (Phalanx)** | Active | Fury 4 | 2턴간 인접 2칸 이내 아군 전원 DEF +5 버프 |

**Design Notes:**
- 창벽: lancer의 방어적 아이덴티티 강화. 진입 억제(zone denial) 역할
- 돌격: Fury 5 중 3을 소모하는 고비용 이동기. 관통과 차별화 (이동 + 단타 vs 제자리 + 관통)
- 방진: 유일한 AoE 방어 버프. Knight의 개인 보호(희생/고통 분담)와 차별화

**Fury Passive 추가 제안:**

| # | Skill Name | Type | Description |
|---|-----------|------|-------------|
| 4 | **철벽 (Iron Phalanx)** | Fury Passive | 분노 MAX 시 2턴간 DEF x 2 (knight의 철의 의지와 동일 구조) |

---

### 3-3. Summoner (소환사) - Priority: HIGH

**Resource:** Mana (110, regen 11)
**Role:** Ranged / Summon Controller
**Identity:** 소환수 운용, 간접 전투

| # | Skill Name | Type | Cost | Description |
|---|-----------|------|------|-------------|
| 1 | **소환 강화 (Empower Summon)** | Active | MP 40 | 필드 위 자신의 소환수 1체 지정. 3턴간 ATK x 1.5 강화 |
| 2 | **영혼 폭발 (Soul Burst)** | Active | MP 60 | 필드 위 자신의 소환수를 희생. 소환수 기준 3x3 범위 적에게 소환수 ATK x 3.0 데미지 |
| 3 | **영적 유대 (Soul Bond)** | Passive | - | 소환수 자연 소멸(턴 만료) 또는 처치 시 마나 40 회복 |

**Design Notes:**
- 소환 강화: 기존 소환수의 가치를 높이는 버프. 정령(원거리) + 강화로 높은 DPS
- 영혼 폭발: 소환수를 자폭시키는 전략적 선택. 골램(HP 120%) 소환 후 적진 돌진 → 자폭 콤보
- 영적 유대: 마나 순환 패시브. 소환(80) → 소멸 시 회수(40)으로 지속성 확보

---

### 3-4. Shaman (주술사) - Priority: HIGH

**Resource:** Mana (100, regen 10)
**Role:** Ranged / Buffer-Debuffer
**Identity:** 주술, 채널링, 전장 지배
**Note:** 기존 저주/고양은 채널링(이동/행동 불가). 비채널링 스킬 필요.

| # | Skill Name | Type | Cost | Description |
|---|-----------|------|------|-------------|
| 1 | **독안개 (Poison Mist)** | Active | MP 50 | 대상 중심 3x3 범위에 독안개 설치. 3턴간 매턴 범위 내 적에게 ATK x 0.3 데미지 |
| 2 | **영혼 쇄도 (Spirit Surge)** | Active | MP 40 | 5칸 내 적 1인에게 ATK x 1.0 + 1턴 이동 불가 |
| 3 | **영매 (Medium)** | Passive | - | 채널링 중 피격 시 채널링이 해제되지 않고 유지 (일반적으로 사망만 해제) |

**Design Notes:**
- 독안개: 비채널링 AoE 지속 데미지. 채널링 없이도 전장에 기여 가능
- 영혼 쇄도: 단일 대상 CC + 데미지. 채널링 시작 전 적 진입 지연용
- 영매: 채널링 특화 패시브. 주술사가 "채널링 전문가"임을 강조

---

### 3-5. Sapper (공병) - Priority: MEDIUM

**Resource:** Energy (100, regen 8)
**Role:** Melee / Trap-Utility
**Identity:** 함정, 지형 조작, 전장 통제

| # | Skill Name | Type | Cost | Description |
|---|-----------|------|------|-------------|
| 1 | **폭파 (Detonate)** | Active | EP 30 | 5칸 내 아군 함정 1개를 즉시 폭발. 함정 기준 인접 적에게 함정 데미지 x 1.5 |
| 2 | **강화 함정 (Enhanced Trap)** | Passive | - | 함정 데미지 30% 증가, 스턴 지속 +1턴 (2턴 → 3턴) |

**Design Notes:**
- 폭파: 함정의 활용도를 높이는 능동 스킬. 적이 밟기를 기다리지 않고 원격 기폭
- 강화 함정: 기존 함정 설치의 가치를 높이는 패시브. sapper의 전문성 강화

---

### 3-6. Mage (마법사) - Priority: LOW

**Resource:** Mana (120, regen 12)
**Role:** Ranged / AoE DPS

| # | Skill Name | Type | Description |
|---|-----------|------|-------------|
| 1 | **마나 쇄도 (Mana Surge)** | Passive | 마나가 최대치의 80% 이상일 때 마법 데미지 20% 증가 |

**Design Notes:**
- 이미 3개 active skill 보유. passive 1개만 추가하여 밸런스 보완
- 마나 관리의 전략적 판단 추가 (스킬 아끼기 vs 쏟아붓기)

---

### 3-7. Priest (사제) - Priority: LOW

**Resource:** Mana (100, regen 10)
**Role:** Healer / Support

| # | Skill Name | Type | Description |
|---|-----------|------|-------------|
| 1 | **신의 은총 (Divine Grace)** | Passive | 모든 회복량(힐, 성역선포 등) 20% 증가 |

**Design Notes:**
- 이미 3개 active skill 보유. passive 1개만 추가
- 회복 전문가로서의 아이덴티티 강화

---

## 4. Implementation Priority

| Priority | Class | Recommended Skills | Reason |
|----------|------|--------------------|--------|
| **1 (Urgent)** | Brawler | 연타, 파쇄, 역습 | 1 skill only, no identity |
| **2 (Urgent)** | Lancer | 창벽, 돌격, 방진, 철벽 | 1 skill only, fury passive 없음 |
| **3 (High)** | Summoner | 소환 강화, 영혼 폭발, 영적 유대 | 0 learnable skills |
| **4 (High)** | Shaman | 독안개, 영혼 쇄도, 영매 | 0 learnable, 채널링만 있음 |
| **5 (Medium)** | Sapper | 폭파, 강화 함정 | 기존 함정 시스템 확장 |
| **6 (Low)** | Mage | 마나 쇄도 | passive 1개만 추가 |
| **7 (Low)** | Priest | 신의 은총 | passive 1개만 추가 |

---

## 5. Balance Considerations

### Resource Economy
- **Fury 클래스** (warrior, knight, lancer): 분노는 피격/공격으로 축적. 스킬 비용 낮지만 축적이 느림
  - Lancer fury max=5 (warrior/knight는 10) → 비용을 3-4로 설정하여 균형
- **Energy 클래스** (assassin, archer, brawler, sapper, novice): 턴당 자동 회복. 중간 비용
  - Brawler regen=12 → 3~4턴마다 스킬 1회 사용 가능
- **Mana 클래스** (mage, priest, summoner, shaman): 턴당 자동 회복. 높은 비용
  - Summoner regen=11 → 소환(80) 후 회복에 7턴 필요 → 영적 유대로 보완

### Class Differentiation
- **Brawler vs Warrior**: 전사는 범위(휘두르기) + 돌진(강습), 무투가는 단일 대상 연타 + DEF 관통
- **Lancer vs Knight**: 기사는 보호(희생, 고통 분담), 창술사는 진형(방진) + 진입 억제(창벽)
- **Summoner vs Mage**: 마법사는 직접 공격, 소환사는 소환수를 통한 간접 전투 + 자폭 전략
- **Shaman vs Priest**: 사제는 순수 회복, 주술사는 디버프 + 버프 + 지속 데미지

### Passive Power Level
- 모든 passive는 기존 패시브(광폭 ATK x 1.5, 약점포착 30% crit)와 비슷한 영향력 유지
- passive는 "항상 적용" vs "조건부"로 구분하여 밸런스 조절
