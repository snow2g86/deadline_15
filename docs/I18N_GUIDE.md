# i18n (다국어) 시스템 가이드

## 🎯 개요

게임의 모든 스킬과 직업은 `skills.js`와 `classes.js`에서 관리됩니다.
이 데이터는 스크립트를 통해 자동으로 `i18n-data.js`로 동기화됩니다.

## 📋 워크플로우

### 1️⃣ 새 스킬/직업 추가

**step 1: 게임 데이터 수정**
```javascript
// js/skills.js 또는 js/classes.js에 추가
const SKILLS = {
  new_class: {
    id: 'new_class_skill',
    name: '새 스킬',  // ← 한국어 기본값
    icon: '🔥',
    // ...
  }
};
```

**step 2: i18n 자동 생성**
```bash
npm run generate-i18n
```

**step 3: 번역 추가**
`i18n-data.js`에서 영어/스페인어 `[TODO]` 항목을 번역합니다:
```javascript
"en": {
  "skills": {
    "new_class_skill": "New Skill"  // ← 번역 추가
  }
}
```

**step 4: 커밋**
```bash
git add .
git commit -m "Add new skill and update i18n"
```

---

## 🔄 자동 생성 스크립트 상세

### 스크립트: `scripts/generate-i18n.js`

**실행 방법:**
```bash
npm run generate-i18n
node scripts/generate-i18n.js  # 또는 직접 실행
```

**동작 원리:**
1. `js/skills.js`에서 모든 스킬 추출
2. `js/classes.js`에서 모든 직업 추출
3. `i18n-data.js` 업데이트:
   - **한국어 (ko)**: 게임 데이터의 name을 그대로 사용 (기존 번역 보존)
   - **영어 (en)**: 기존 번역 유지, 새 항목은 `[TODO: Translate]` 표시
   - **스페인어 (es)**: 기존 번역 유지, 새 항목은 `[TODO: Traducir]` 표시

### 예시

**게임 데이터 (skills.js)**
```javascript
const SKILLS = {
  warrior: {
    id: 'warrior_powersmash',
    name: '강타',  // ← 한국어 기본값
    // ...
  }
};
```

**생성된 i18n-data.js**
```javascript
"ko": {
  "skills": {
    "warrior_powersmash": "강타"  // 자동 동기화
  }
},
"en": {
  "skills": {
    "warrior_powersmash": "Power Smash"  // 기존 번역 유지
  }
},
"es": {
  "skills": {
    "warrior_powersmash": "Golpe Poderoso"  // 기존 번역 유지
  }
}
```

---

## 📝 번역 관리

### 영어/스페인어 번역이 필요한 경우

1. `i18n-data.js`에서 `[TODO]` 항목 찾기
2. 번역 추가
3. 커밋

```bash
# 예: 모든 TODO 찾기
grep -r "\[TODO" js/i18n-data.js
```

### 번역 템플릿

| 항목 | 한국어 | 영어 | 스페인어 |
|------|--------|------|----------|
| 스킬 이름 | '강타' | 'Power Smash' | 'Golpe Poderoso' |
| 직업 이름 | '전사' | 'Warrior' | 'Guerrero' |
| 메시지 | '습격!' | 'Raid!' | '¡Asalto!' |

---

## ⚠️ 주의사항

### ❌ 하지 말 것

```javascript
// ❌ 스킬/직업 이름을 i18n-data.js에만 추가하고 게임 데이터에는 안 함
// → 다음 스크립트 실행 시 덮어씌워집니다
```

### ✅ 올바른 방법

```javascript
// ✅ 게임 데이터에 먼저 추가하고 스크립트 실행
// 1. js/skills.js 또는 js/classes.js 수정
// 2. npm run generate-i18n 실행
// 3. i18n-data.js가 자동 업데이트됨
```

---

## 🔍 스크립트 실행 결과 예시

```bash
$ npm run generate-i18n

🔄 i18n-data.js 생성 중...

✅ 추출된 스킬: 15개
✅ 추출된 직업: 12개

✅ i18n-data.js 업데이트 완료!

📝 다음 단계:
   1. 영어/스페인어 [TODO] 항목을 번역하세요
   2. 변경사항을 커밋하세요
   3. 새 스킬/직업 추가 시 다시 스크립트를 실행하세요
```

---

## 🎮 게임에서의 사용

### 클래스 이름 출력
```javascript
// ui.js에서
const className = t('classes.' + u.cls);  // 자동으로 다국어 표시
```

### 스킬 이름 출력
```javascript
// render.js에서
btn.textContent = t('skills.' + sk.id);  // 자동으로 다국어 표시
```

### 메시지 출력
```javascript
// combat.js에서
this.floatT(u.x, u.y, t('messages.fury_buff'), 'heal');  // 자동으로 다국어 표시
```

---

## 📚 파일 구조

```
game/deadline_15/
├── js/
│   ├── skills.js              ← 스킬 정의 (게임 데이터)
│   ├── classes.js             ← 직업 정의 (게임 데이터)
│   └── i18n-data.js           ← 번역 데이터 (자동 생성)
├── scripts/
│   └── generate-i18n.js       ← 생성 스크립트
├── docs/
│   └── I18N_GUIDE.md          ← 이 파일
└── package.json               ← NPM 스크립트
```

---

## ❓ FAQ

**Q: 스크립트를 실행하면 뭐가 바뀌나요?**
A: `i18n-data.js`의 skills와 classes 섹션만 자동으로 업데이트됩니다. 다른 번역(메시지, UI 등)은 변경되지 않습니다.

**Q: 한국어 번역이 게임 데이터와 다르면 어쩌나요?**
A: 스크립트 실행 시 게임 데이터의 한국어 이름으로 덮어씌워집니다. 필요하면 게임 데이터에서 수정하세요.

**Q: 영어/스페인어는 어디서 번역하나요?**
A: `i18n-data.js`의 "en", "es" 섹션에서 직접 수정하세요. `[TODO]` 항목을 번역하면 됩니다.

**Q: 신규 메시지(스킬 발동 시 메시지 등)는 자동으로 생성되나요?**
A: 아니요, skills.js에 정의된 스킬의 id와 name만 자동 생성됩니다. 메시지는 수동으로 `i18n-data.js`에 추가해야 합니다.

---

## 🚀 베스트 프랙티스

1. **매번 스크립트 실행**: 새 스킬/직업 추가 후 항상 `npm run generate-i18n` 실행
2. **게임 데이터 먼저**: i18n-data.js가 아닌 skills.js/classes.js를 먼저 수정
3. **한국어를 기본값으로**: 게임 개발 시 한국어 이름을 명확하게 정의
4. **번역은 별도로**: 영어/스페인어 번역은 스크립트 실행 후 추가
5. **커밋 분리**: 게임 데이터 수정과 i18n 업데이트를 따로 커밋 (선택사항)

---

## 📞 문제 해결

**스크립트가 실행되지 않음:**
```bash
# Node.js 설치 확인
node --version

# 절대 경로에서 실행
node /Users/2z/Desktop/workspace/game/deadline_15/scripts/generate-i18n.js
```

**i18n-data.js가 제대로 업데이트되지 않음:**
1. skills.js/classes.js의 형식 확인 (작은따옴표 사용)
2. i18n-data.js 백업 후 스크립트 재실행
3. 콘솔 출력에서 "추출된 스킬/직업" 개수 확인

**기존 번역이 손실됨:**
1. git으로 복구
2. 스크립트는 기존 한국어 번역을 보존하므로, 영어/스페인어 번역만 수동 추가
