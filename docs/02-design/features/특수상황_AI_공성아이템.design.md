# Design: 특수상황 AI + 공성아이템 활용

## 설계 개요
AI가 특수 상황을 감지하고 공성아이템을 전략적으로 사용하는 시스템을 구현합니다.

## 데이터 구조

### 1. 유닛 확장 (enemy units)
```javascript
// 적군 유닛에 추가되는 필드
u.siegeItems = [
  {
    id: 고유번호,
    type: 'bomb' | 'ladder' | 'detour' | 'shield' | 'evasion',
    name: 아이템명,
    description: 설명,
    effectRange: 숫자,
    targetType: 'self' | 'tile' | 'unit',
    cooldown: 0
  }
];
```

### 2. 상황 분석 결과
```javascript
const situation = {
  type: 'blocked' | 'distant' | 'weakened' | 'surrounded' | 'safe',
  severity: 0.0 ~ 1.0,  // 0 = 안전, 1 = 극도로 위험
  blockCount: 숫자,      // 막힌 경로 수
  nearbyAllies: 숫자,    // 주변 아군 수
  hpPercent: 0.0 ~ 1.0  // 현재 체력 비율
};
```

## 알고리즘 설계

### Phase 1: 상황 분석 (analyzeSituation)

```
입력: enemy unit u
출력: situation 객체

1. 체력 계산
   hpPercent = u.hp / u.mhp

2. 주변 아군 계산
   nearbyAllies = 거리 2칸 이내 아군 수

3. 경로 분석
   moveOptions = u의 이동 가능한 경로 수

4. 상황 판정
   IF hpPercent < 0.3 → 'weakened'
   ELSE IF nearbyAllies >= 3 → 'surrounded'
   ELSE IF moveOptions == 0 → 'blocked'
   ELSE IF 인접 거리 아군 있음 → 'distant'
   ELSE → 'safe'

5. Severity 계산
   severity = (1 - hpPercent) * 0.4 + (nearbyAllies / 5) * 0.4 + (1 - moveOptions/4) * 0.2
```

### Phase 2: 아이템 선택 (selectSiegeItem)

```
입력: unit u, situation
출력: siegeItem 또는 null

1. 사용 가능 아이템 필터링
   available = u.siegeItems.filter(item => item.cooldown == 0)
   IF available.length == 0 → return null

2. 상황별 우선순위 계산
   FOR each item in available:
     priority = calculatePriority(item, situation)

3. 가장 높은 우선순위 아이템 선택
   best = max(available, by priority)
   return best

Priority 계산 로직:
┌─────────────────┬─────────────────────────┐
│ 상황 / 아이템   │ 우선순위                │
├─────────────────┼─────────────────────────┤
│ blocked         │ bomb: 90, ladder: 70    │
│ distant         │ detour: 80, bomb: 60    │
│ weakened        │ shield: 100, evasion: 80│
│ surrounded      │ evasion: 90, bomb: 70   │
│ safe            │ 아이템 사용 안 함        │
└─────────────────┴─────────────────────────┘
```

### Phase 3: 아이템 사용 (useSiegeItem)

```
입력: unit u, siegeItem item
출력: boolean (성공 여부)

1. 아이템 타입별 처리
   SWITCH item.type:
     CASE 'bomb':
       → 앞 2칸 범위 폭발 (데미지 30-50%)
       → 벽/장애물 파괴

     CASE 'ladder':
       → 현재 위치 또는 인접 높은 지형으로 이동
       → 후방 벽 우회

     CASE 'detour':
       → 이동 불가 상태 해제
       → 한 번의 추가 이동 허용

     CASE 'shield':
       → 1턴 동안 받는 데미지 50% 감소
       → 방어력 +5

     CASE 'evasion':
       → 다음 공격 30% 확률로 회피
       → 명중률 감소 30%

2. 효과 적용
   → 해당 효과 활성화
   → cooldown 설정 (3턴)
   → u.siegeItems에서 제거 또는 cooldown 증가

3. 반환
   return true (사용 성공)
```

## AI 의사결정 통합

### 현재 eAI() 흐름 (js/battle/ai.js)
```javascript
async eAI(u) {
  1. 스킬 사용 시도 (tryUseSkill)
  2. 근거리 공격 (atkC에 적 있으면)
  3. 게이트 공격 (tryGateAtk)
  4. 벽 오르기 (tryWallClimb)
  5. 이동 (eMv)
  6. 이동 후 공격 (재확인)
  7. 게이트 공격 (재확인)
}
```

### 개선된 eAI() 흐름
```javascript
async eAI(u) {
  1. 스킬 사용 시도 (tryUseSkill)

  2. 공성아이템 사용 시도 ← NEW
     IF trySiegeItemUse(u) return;

  3. 근거리 공격 (atkC에 적 있으면)
  4. 게이트 공격 (tryGateAtk)
  5. 벽 오르기 (tryWallClimb)
  6. 이동 (eMv)
  7. 이동 후 공격 (재확인)
  8. 게이트 공격 (재확인)
}
```

## 함수 시그니처

### analyzeSituation(u)
```javascript
/**
 * @param {Object} u - enemy unit
 * @returns {Object} situation 객체
 * {
 *   type: string,
 *   severity: number (0-1),
 *   blockCount: number,
 *   nearbyAllies: number,
 *   hpPercent: number (0-1)
 * }
 */
```

### selectSiegeItem(u, situation)
```javascript
/**
 * @param {Object} u - enemy unit with siegeItems
 * @param {Object} situation - analyzed situation
 * @returns {Object|null} selected siegeItem or null
 */
```

### useSiegeItem(u, item)
```javascript
/**
 * @param {Object} u - enemy unit
 * @param {Object} item - siegeItem to use
 * @returns {Promise<boolean>} success status
 */
```

### trySiegeItemUse(u)
```javascript
/**
 * Main entry point for siege item usage attempt
 * @param {Object} u - enemy unit
 * @returns {Promise<boolean>} true if item was used
 */
```

## 실장 파일별 상세 설계

### 1. js/battle/boot.js
**위치**: 적군 유닛 초기화 함수

**변경 내용**:
```javascript
// spawnW() 또는 유닛 생성 시점에서
function initEnemyUnit(u) {
  // 기존 초기화 코드...

  // NEW: 공성아이템 초기화
  u.siegeItems = [];

  // 기본 1개 지급 (난이도별 다르게 가능)
  const itemPool = [
    { type: 'bomb', weight: 40 },
    { type: 'ladder', weight: 30 },
    { type: 'detour', weight: 20 },
    { type: 'shield', weight: 10 }
  ];
  const selected = weightedRandomSelect(itemPool);
  u.siegeItems.push(createSiegeItem(selected.type));
}
```

### 2. js/battle/ai.js
**추가될 함수들**:

```javascript
analyzeSituation(u) {
  // 상황 분석 로직
}

selectSiegeItem(u, situation) {
  // 아이템 선택 로직
}

async useSiegeItem(u, item) {
  // 아이템 사용 로직
}

async trySiegeItemUse(u) {
  // 공성아이템 사용 시도 (eAI에서 호출)
  if (!u.siegeItems?.length) return false;
  const situation = this.analyzeSituation(u);
  if (situation.severity < 0.2) return false;
  const item = this.selectSiegeItem(u, situation);
  if (!item) return false;
  return await this.useSiegeItem(u, item);
}
```

**eAI() 수정 위치**:
- 스킬 사용 후, 근거리 공격 전에 `await this.trySiegeItemUse(u)` 호출 추가

### 3. js/battle/combat.js
**필요시 추가**:
- 공성아이템 효과 적용 함수 (이미 존재하면 활용)
- damage reduction, buff 적용 등

## 특수 고려사항

### 1. 보존 규칙 (보스 제외)
```javascript
// isBoss=true인 경우는 AI 회피 행동 제외
if (u.isBoss && situation.type === 'blocked') {
  // 보스는 무조건 진행하려 함
  return false;
}
```

### 2. 난이도 스케일링
```javascript
const difficultyModifier = {
  easy: 0.6,      // 공성아이템 사용 30% 확률 감소
  normal: 1.0,    // 기본 로직
  hard: 1.3       // 공성아이템 사용 30% 확률 증가
};
```

### 3. Cooldown 관리
```javascript
// 아이템 사용 후 cooldown 설정
item.cooldown = 3;  // 3턴 후 재사용 가능

// 턴 시작 시 cooldown 감소
u.siegeItems.forEach(item => {
  if (item.cooldown > 0) item.cooldown--;
});
```

## 성능 최적화

### 캐싱
- `analyzeSituation()` 결과는 한 턴에 1회만 계산
- 상황이 변하면 재계산

### 계산 복잡도
- O(n) where n = nearby units (보통 3-5개)
- 턴당 추가 시간: ~10ms

## 검증 전략

### 단위 테스트 (수동)
1. 적이 막혔을 때 폭탄 사용 확인
2. 체력 낮을 때 방어막 사용 확인
3. 아군 많을 때 회피 사용 확인

### 통합 테스트
1. 모든 스테이지에서 게임 진행 확인
2. 적 AI가 이전 방식으로도 작동하는지 확인 (후퇴 등)
3. 난이도 밸런스 확인

## 롤백 계획
- 공성아이템 기능 비활성화 플래그 추가
  ```javascript
  ENABLE_SIEGE_AI = true; // false로 설정하면 비활성화
  ```
