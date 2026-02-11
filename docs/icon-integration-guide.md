# 상태 아이콘 통합 가이드

## 📦 생성 완료 파일

- ✅ **23개 PNG 아이콘** (`image/icon/status/*.png`)
- ✅ **디자인 철학 문서** (`docs/status-icons-philosophy.md`)
- ✅ **아이콘 매핑 README** (`image/icon/status/README.md`)
- ✅ **생성 스크립트** (`generate_status_icons.py`)

## 🎨 생성된 아이콘 스펙

| 속성 | 값 |
|------|-----|
| 해상도 | 64×64px |
| 형식 | PNG (RGBA) |
| 배경 | 투명 |
| 스타일 | 픽셀 아트 |
| 개수 | 23개 (버프 17 + 디버프 6) |

## 🔧 게임 코드 통합 (3단계)

### Step 1: js/skills/_common.js 수정

**현재 상태 (이모지):**
```javascript
// Line 169-201: getSkillBuffs() 함수
function getSkillBuffs(unit) {
    const buffs = [];
    if (unit.resType === 'fury' && unit.res >= unit.maxRes)
        buffs.push({ icon: '🔥', type: 'buff', turns: 0 });
    // ...
}
```

**변경 후 (아이콘 파일):**
```javascript
// Line 169-201: getSkillBuffs() 함수
function getSkillBuffs(unit) {
    const buffs = [];
    if (unit.resType === 'fury' && unit.res >= unit.maxRes)
        buffs.push({ icon: 'image/icon/status/fury-max.png', type: 'buff', turns: 0 });
    // ...
}
```

**전체 매핑 목록:**
```javascript
// ── 버프 아이콘 매핑 ──
const BUFF_ICONS = {
    'fury-max': 'image/icon/status/fury-max.png',          // 🔥
    'warrior-fury': 'image/icon/status/warrior-fury.png',  // 💢
    'shield-buff': 'image/icon/status/shield-buff.png',    // 🛡️
    'pain-share': 'image/icon/status/pain-share.png',      // 💔
    'tenacity': 'image/icon/status/tenacity.png',          // 💪
    'bloodthirst': 'image/icon/status/bloodthirst.png',    // 🩸
    'sanctuary': 'image/icon/status/sanctuary.png',        // ✝️
    'summon-duration': 'image/icon/status/summon-duration.png', // ⏳
    'exalt': 'image/icon/status/exalt.png',                // 🔺
    'spearwall': 'image/icon/status/spearwall.png',        // 🔱
    'counter': 'image/icon/status/counter.png',            // 🔁
    'medium': 'image/icon/status/medium.png',              // 🔮
    'enhanced-trap': 'image/icon/status/enhanced-trap.png',// ⚙️
    'mana-surge': 'image/icon/status/mana-surge.png',      // 🌊
    'divine-grace': 'image/icon/status/divine-grace.png',  // 🕊️
    'iron-phalanx': 'image/icon/status/iron-phalanx.png',  // 🏰
    'empower': 'image/icon/status/empower.png',            // ⬆️
};

// ── 디버프 아이콘 매핑 ──
const DEBUFF_ICONS = {
    'disarmed': 'image/icon/status/disarmed.png',          // 🤛
    'curse': 'image/icon/status/curse.png',                // ☠️
    'bleed': 'image/icon/status/bleed.png',                // 🗡️
    'stun': 'image/icon/status/stun.png',                  // ⚡
    'frozen': 'image/icon/status/frozen.png',              // ❄️
    'rooted': 'image/icon/status/rooted.png',              // 🌿
};
```

### Step 2: HTML/CSS에서 아이콘 표시

**CSS 추가:**
```css
/* icon-display.css 또는 main style에 추가 */

.buff-icon,
.debuff-icon {
    display: inline-block;
    width: 24px;
    height: 24px;
    margin: 0 2px;
    background-size: contain;
    background-repeat: no-repeat;
    background-position: center;
    image-rendering: pixelated;  /* 픽셀 아트 품질 유지 */
    -ms-interpolation-mode: nearest-neighbor;  /* IE/Edge */
}

.buff-icon { opacity: 0.9; }
.debuff-icon { opacity: 0.95; }
```

**HTML 마크업:**
```html
<!-- 버프 표시 예 -->
<div class="buff-icon" style="background-image: url('image/icon/status/fury-max.png')"
     title="분노 MAX"></div>

<!-- 또는 동적 생성 (JavaScript) -->
<img src="image/icon/status/fury-max.png" alt="분노 MAX" class="buff-icon">
```

### Step 3: JavaScript에서 동적 생성

```javascript
// 현재 유닛의 버프/디버프 렌더링 함수
function renderBuffDebuffIcons(unit) {
    const buffs = getSkillBuffs(unit);
    const container = document.getElementById('buff-container');
    container.innerHTML = '';

    buffs.forEach(buff => {
        if (!buff.icon.includes('.png')) return; // 이모지 skip

        const img = document.createElement('img');
        img.src = buff.icon;
        img.alt = buff.type;
        img.className = `${buff.type}-icon`;
        img.title = `${buff.type} (${buff.turns}턴)`;

        container.appendChild(img);
    });
}

// getSkillBuffs() 개선버전
function getSkillBuffs(unit) {
    const buffs = [];

    // 분노 MAX
    if (unit.resType === 'fury' && unit.res >= unit.maxRes)
        buffs.push({ icon: 'image/icon/status/fury-max.png', type: 'buff', turns: 0 });

    // 광폭 (전사)
    if (unit.furyBuff > 0)
        buffs.push({ icon: 'image/icon/status/warrior-fury.png', type: 'buff', turns: unit.furyBuff });

    // 방어력 버프
    if (unit.defBuff > 0)
        buffs.push({ icon: 'image/icon/status/shield-buff.png', type: 'buff', turns: unit.defBuff });

    // ... 나머지 상태들

    return buffs;
}
```

## 📊 마이그레이션 체크리스트

- [ ] `js/skills/_common.js` 의 `getSkillBuffs()` 함수 수정
- [ ] 모든 icon 문자열을 이미지 경로로 변경
- [ ] CSS에 `.buff-icon`, `.debuff-icon` 스타일 추가
- [ ] HTML에서 아이콘 렌더링 코드 추가
- [ ] 브라우저에서 테스트 (화면 UI 확인)
- [ ] 전투 화면에서 버프/디버프 표시 동작 확인

## 🎯 선택 가능한 적용 방식

### 방식 A: 완전 마이그레이션 (권장)
이모지 → 아이콘 파일로 완전히 변경
- 장점: 일관된 시각적 스타일, 고정 크기
- 단점: 코드 변경 필요, 이모지와 혼용 불가

### 방식 B: 하이브리드
이모지와 아이콘 파일 혼용
- 장점: 점진적 적용 가능
- 단점: 시각적 일관성 감소

### 방식 C: 이모지 유지 (현상 유지)
기존 이모지 시스템 유지
- 장점: 코드 변경 불필요
- 단점: 일관된 아이콘 UI 불가

## 🧪 테스트 계획

```javascript
// 테스트 케이스
const testUnit = {
    cls: 'warrior',
    furyBuff: 2,
    defBuff: 1,
    disarmed: 0,
    frozen: 0,
    stunned: 0
};

const buffs = getSkillBuffs(testUnit);
console.log('예상 결과:', ['warrior-fury', 'shield-buff']);
console.log('실제 결과:', buffs.map(b => b.icon));
```

## 📝 추가 참고사항

### 성능
- 아이콘 파일 크기: 평균 ~200bytes (매우 작음)
- 로딩 속도: 무시할 수 있는 수준
- 캐싱: 브라우저 자동 캐싱으로 반복 로드 최적화

### 확장성
향후 아이콘 개선 시:
1. `generate_status_icons.py` 수정
2. 스크립트 재실행 (`python3 generate_status_icons.py`)
3. 새 PNG 파일로 자동 교체

### 호환성
- 모든 최신 브라우저 지원 (PNG RGBA)
- Mobile 호환성 우수
- 다크 모드 호환 (투명 배경)

## 📞 질문 & 추가 요청

- 아이콘 스타일 변경 필요?
- 크기 조정 필요? (32px, 48px 등)
- 추가 상태 아이콘 필요?

각 요청에 따라 `generate_status_icons.py` 스크립트 수정으로 빠르게 대응 가능합니다.
