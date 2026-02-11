# Plan: Skill Implementation

## Overview

12개 클래스 중 스킬이 부족한 7개 직군에 총 16개 신규 스킬(Active 11 + Passive 5)을 추가하여
클래스 간 밸런스를 맞추고 전투 다양성을 확보한다.

**Reference:** `docs/skill-balance-analysis.md`

## Background

### Current State

| Class | Current Skills | Gap |
| --- | --- | --- |
| Warrior | 6 (1 base + 3 active + 2 passive) | None |
| Knight | 7 (1 base + 3 active + 3 passive) | None |
| Archer | 5 (1 base + 3 active + 1 passive) | None |
| Assassin | 4 (1 base + 1 active + 2 passive) | None |
| Mage | 3 (1 base + 2 active) | Passive 0 |
| Priest | 3 (1 base + 2 active) | Passive 0 |
| Sapper | 2 (1 base + 1 active) | Active/Passive 부족 |
| Summoner | 2 (2 base) | Learnable 0 |
| Shaman | 2 (2 base, channeling) | Learnable 0 |
| Brawler | 1 (1 base) | Critical |
| Lancer | 1 (1 base) | Critical |

### Problem

- Brawler/Lancer: 기본 스킬 1개뿐. 스킬북 시스템의 혜택을 받지 못함
- Summoner/Shaman: 습득형 스킬이 0개. 성장 경로 없음
- Mage/Priest/Sapper: Passive 없이 Active만 보유. 전투 깊이 부족

## Goals

1. 모든 클래스가 최소 3개 이상의 스킬(기본 + 습득형)을 보유
2. 모든 전투 참여 클래스에 최소 1개 passive 부여
3. 기존 시스템(LEARNABLE_SKILLS, registerSkill, _common.js)과 완전 호환
4. 클래스 간 역할 차별화 유지

## Scope

### In Scope

**Phase 1 - Critical (Brawler, Lancer): 7 skills**

- Brawler: 연타(Active), 파쇄(Active), 역습(Passive)
- Lancer: 창벽(Passive), 돌격(Active), 방진(Active), 철벽(Fury Passive)

**Phase 2 - High (Summoner, Shaman): 6 skills**

- Summoner: 소환 강화(Active), 영혼 폭발(Active), 영적 유대(Passive)
- Shaman: 독안개(Active), 영혼 쇄도(Active), 영매(Passive)

**Phase 3 - Medium/Low (Sapper, Mage, Priest): 3 skills**

- Sapper: 폭파(Active), 강화 함정(Passive)
- Mage: 마나 쇄도(Passive)
- Priest: 신의 은총(Passive)

### Out of Scope

- Novice 스킬 추가 (전직 대상 클래스, 약함이 설계 의도)
- 기존 스킬 수정/리밸런스
- 새로운 상태이상 시스템 추가 (기존 것만 활용)
- i18n 번역 (별도 작업으로 분리)

## Implementation Plan

### Phase 1: Brawler + Lancer (Priority: Urgent)

#### 1-1. Brawler Skills

**연타 (Flurry)** - `brawler_flurry`

- Type: Active, EP 40
- Effect: 인접 적 1인에게 3회 ATK x 0.6 연속 공격
- Files: `js/skills.js` (LEARNABLE_SKILLS), `js/skills/brawler.js` (handler)

**파쇄 (Crush)** - `brawler_crush`

- Type: Active, EP 50
- Effect: 인접 적 1인, DEF 무시 ATK x 1.0 데미지
- Files: `js/skills.js`, `js/skills/brawler.js`

**역습 (Counter)** - `brawler_counter`

- Type: Passive
- Effect: 피격 시 30% 확률로 ATK x 0.5 반격
- Files: `js/skills.js`, `js/skills/_common.js` (applyDmgToAlly/calcDmg 연동)

#### 1-2. Lancer Skills

**창벽 (Spear Wall)** - `lancer_spearwall`

- Type: Passive
- Effect: 적이 인접으로 이동 시 ATK x 0.5 자동 공격 (턴당 1회)
- Files: `js/skills.js`, `js/battle/ai.js` (적 이동 시 트리거)

**돌격 (Lance Charge)** - `lancer_charge`

- Type: Active, Fury 3
- Effect: 일직선 3칸 내 적에게 돌진 이동 + ATK x 1.2 공격
- Files: `js/skills.js`, `js/skills/lancer.js`

**방진 (Phalanx)** - `lancer_phalanx`

- Type: Active, Fury 4
- Effect: 2턴간 인접 2칸 이내 아군 DEF +5
- Files: `js/skills.js`, `js/skills/lancer.js`, `js/skills/_common.js` (tickBuffs)

**철벽 (Iron Phalanx)** - `lancer_ironphalanx`

- Type: Fury Passive (분노 MAX 트리거)
- Effect: 2턴간 DEF x 2
- Files: `js/skills/_common.js` (FURY_PASSIVES.lancer)

### Phase 2: Summoner + Shaman (Priority: High)

#### 2-1. Summoner Skills

**소환 강화 (Empower Summon)** - `summoner_empower`

- Type: Active, MP 40
- Effect: 자신의 소환수 1체 지정, 3턴간 ATK x 1.5
- Files: `js/skills.js`, `js/skills/summoner.js`

**영혼 폭발 (Soul Burst)** - `summoner_soulburst`

- Type: Active, MP 60
- Effect: 자신의 소환수 희생, 소환수 기준 3x3 범위 적에게 소환수 ATK x 3.0
- Files: `js/skills.js`, `js/skills/summoner.js`

**영적 유대 (Soul Bond)** - `summoner_soulbond`

- Type: Passive
- Effect: 소환수 소멸/처치 시 마나 40 회복
- Files: `js/skills.js`, `js/skills/summoner.js` 또는 전투 로직

#### 2-2. Shaman Skills

**독안개 (Poison Mist)** - `shaman_poisonmist`

- Type: Active, MP 50
- Effect: 대상 중심 3x3 독안개 설치, 3턴간 매턴 범위 내 적 ATK x 0.3 데미지
- Files: `js/skills.js`, `js/skills/shaman.js`

**영혼 쇄도 (Spirit Surge)** - `shaman_spiritsurge`

- Type: Active, MP 40
- Effect: 5칸 내 적 1인, ATK x 1.0 + 1턴 이동 불가
- Files: `js/skills.js`, `js/skills/shaman.js`

**영매 (Medium)** - `shaman_medium`

- Type: Passive
- Effect: 채널링 중 피격 시 채널링 유지 (사망만 해제)
- Files: `js/skills.js`, `js/skills/_common.js`

### Phase 3: Sapper + Mage + Priest (Priority: Medium/Low)

**폭파 (Detonate)** - `sapper_detonate`

- Type: Active, EP 30
- Effect: 5칸 내 아군 함정 즉시 폭발, 인접 적에게 함정 데미지 x 1.5
- Files: `js/skills.js`, `js/skills/sapper.js`

**강화 함정 (Enhanced Trap)** - `sapper_enhancedtrap`

- Type: Passive
- Effect: 함정 데미지 30% 증가, 스턴 +1턴
- Files: `js/skills.js`, `js/skills/sapper.js` (함정 설치 로직 수정)

**마나 쇄도 (Mana Surge)** - `mage_manasurge`

- Type: Passive
- Effect: 마나 80% 이상 시 마법 데미지 20% 증가
- Files: `js/skills.js`, `js/skills/_common.js` (calcDmg 수정)

**신의 은총 (Divine Grace)** - `priest_divinegrace`

- Type: Passive
- Effect: 모든 회복량 20% 증가
- Files: `js/skills.js`, heal 관련 로직

## Affected Files

| File | Changes |
| --- | --- |
| `js/skills.js` | LEARNABLE_SKILLS에 16개 스킬 데이터 추가 |
| `js/skills/brawler.js` | 연타, 파쇄 핸들러 + 역습 로직 |
| `js/skills/lancer.js` | 돌격, 방진 핸들러 |
| `js/skills/summoner.js` | 소환 강화, 영혼 폭발 핸들러 |
| `js/skills/shaman.js` | 독안개, 영혼 쇄도 핸들러 |
| `js/skills/sapper.js` | 폭파 핸들러 + 강화 함정 로직 |
| `js/skills/_common.js` | FURY_PASSIVES.lancer, calcDmg 수정, 패시브 트리거 |
| `js/battle/ai.js` | 창벽 트리거 (적 이동 시) |
| `js/battle/core.js` | 독안개 영역 틱 처리 |
| `js/battle/ui.js` | 신규 버프/디버프 아이콘 표시 |

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Passive 간 상호작용 복잡도 | Medium | 각 passive를 독립적으로 구현, 기존 패턴(calcDmg, tickBuffs) 준수 |
| 독안개 등 지속 효과 성능 | Low | 기존 함정/성역선포 패턴 재사용 |
| Lancer fury 경제 (max 5) | Medium | 비용 3-4로 설정하여 1-2회만 사용 가능하게 제한 |
| AI가 신규 스킬 활용 | Low | AI_PROFILES의 skillUseProbability로 자동 적용 |

## Success Criteria

- 모든 전투 클래스가 최소 3개 이상 스킬 보유
- 모든 전투 클래스가 최소 1개 passive 보유
- 기존 스킬북 시스템(아카데미)과 호환
- 브라우저 콘솔 에러 없음
- 기존 스킬 동작에 regression 없음
