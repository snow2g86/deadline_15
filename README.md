# 🎮 DEADLINE 15

> 턴 기반 방어 전략 RPG | Turn-based Defense Strategy RPG

[![Live Demo](https://img.shields.io/badge/Live%20Demo-Visit-blue?style=flat-square)](https://deadline-15.pages.dev/)
[![GitHub](https://img.shields.io/badge/GitHub-snow2g86-black?style=flat-square&logo=github)](https://github.com/snow2g86/deadline_15)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

---

## 📖 개요

**DEADLINE 15**는 순수 HTML/CSS/JavaScript로 만든 턴 기반 방어 RPG입니다.
클랜원(캐릭터)을 모으고, 강화하며, 전략적으로 배치하여 10개의 도전 스테이지를 클리어하세요!

- **배포 완료**: [https://deadline-15.pages.dev/](https://deadline-15.pages.dev/)
- **완전 클라이언트 사이드**: 백엔드 불필요, localStorage 기반 세이브
- **모바일 최적화**: 모바일/태블릿에서 원활하게 플레이 가능
- **다국어 지원**: 한국어, 영어, 스페인어

---

## ✨ 주요 기능

### 🎭 다양한 클래스 (12개)
| 카테고리 | 클래스 | 능력 |
|---------|--------|------|
| **근접 전사** | Warrior | 🔥 분노(Fury) - 강력한 공격 |
| | Knight | 🛡️ 몸부림(Parry) - 반격 기능 |
| | Assassin | 🌲 은신 + 암살 |
| | Brawler | 💪 격투술 |
| | Lancer | 🗡️ 창술 |
| | Sapper | ⚡ 함정 설치 |
| **원거리 공격수** | Archer | 🏹 원거리 공격 |
| | Mage | 🔥 화염폭발(Fire Blast) |
| | Summoner | 👻 소환수 |
| | Shaman | ✨ 주술 |
| **힐러** | Priest | 💜 집단 치유 |
| **초보자** | Novice | 🎓 모든 직업으로 전직 가능 |

### 📊 캐릭터 육성 시스템
- **레벨업**: 최대 15 레벨 (경험치 기반)
- **잠재력 등급**: S/A/B/C 등급으로 성장률 결정
- **전직 시스템**: 노비스를 11개 직업으로 변경 (스탯 자동 재계산)
- **스킬 습득**: 클래스별 고유 액티브 스킬 + 패시브 능력
- **경험치 물약**: 상점에서 구매하여 즉시 경험치 획득

### ⚔️ 전투 시스템
- **10개 스테이지**: 방어(Defense) / 공략(Offense) / 혼합(Mixed) 모드
- **난이도 곡선**:
  - 1-2단계: 초급 (노비스만)
  - 3-4단계: 중급 (다양 클래스)
  - 5-6단계: 중상급 (성채 방어)
  - 7-8단계: 상급 (강도단 본거지)
  - 9-10단계: 극상급 (마계 침공 + 보스)

### 🎮 게임플레이 메커닉
```
턴 시스템
├─ 플레이어 턴
│  ├─ 캐릭터 선택
│  ├─ 이동 (3-4칸 제한)
│  ├─ 공격 또는 스킬 사용
│  └─ 행동 완료
└─ 적 턴
   ├─ 적 AI 이동/공격
   └─ 함정 트리거 체크
```

- **리소스 시스템**:
  - 🔥 **Fury** (분노): Warrior 자원, 턴마다 증가 → 강공 사용
  - ⚡ **Energy** (에너지): 전사/공병 자원, 함정 설치
  - 💜 **Mana** (마나): 법사/사제 자원, 스킬 시전

- **특수 기능**:
  - 🌲 **은신**: Assassin이 숲 타일에서 자동 은신 → 적 겹침 이동 가능
  - 💣 **함정**: Sapper가 설치 (ATK×2 데미지 + 2턴 기절)
  - 🛡️ **성벽**: 방어 스테이지의 파괴 가능한 벽 (경험치 획득)
  - 💀 **보스**: 각 스테이지 마지막 웨이브에 강력한 보스 출현

### 💾 저장 및 로드
- **자동 저장**: localStorage에 게임 상태 자동 저장
- **중단 및 재개**: 게임 종료 후 재진입 시 이전 진행 상황 복구
- **전투 저장**: 전투 중 나가도 다시 진입 가능
- **캐릭터 보유**: 획득한 캐릭터/경험치 영구 보관

### 🌍 다국어 (i18n)
- **한국어** (기본)
- **English** (영어)
- **Español** (스페인어)

설정에서 언어 변경 시 모든 UI 자동 번역

### 📚 도감 시스템
- **직업 도감**: 12개 클래스 정보 + 기본 스탯 + 스킬
- **스테이지 도감**: 10개 스테이지 정보 + 난이도 + 적 구성 + 보스
- **아이템 도감**: 경험치 물약 3종 + 가격 + 효율

---

## 🚀 시작하기

### 빠른 시작
1. **라이브 플레이**: https://deadline-15.pages.dev/
2. **브라우저 열기**: Chrome, Firefox, Safari, Edge 모두 지원
3. **클릭해서 시작!**

### 로컬 개발 (선택사항)

```bash
# 저장소 클론
git clone https://github.com/snow2g86/deadline_15.git
cd deadline_15

# 로컬 서버 실행 (Python)
python -m http.server 8000

# 또는 Node.js
npx http-server

# 브라우저에서 열기
# http://localhost:8000
```

---

## 📁 프로젝트 구조

```
deadline_15/
├── index.html                 # 로비 (메인 화면)
├── stage-select.html          # 스테이지 선택
├── party-select.html          # 파티 구성
├── battle.html                # 전투 화면
├── shop.html                  # 상점 (캐릭터/물약 구매)
├── sanctuary.html             # 성소 (캐릭터 강화)
├── academy.html               # 학원 (스킬 학습)
├── settings.html              # 설정 (언어/음량)
├── compendium-*.html          # 도감 페이지
│
├── css/
│   ├── style.css              # 메인 스타일
│   ├── lobby.css              # 로비 스타일
│   ├── battle.css             # 전투 스타일
│   └── ...
│
├── js/
│   ├── index.js               # 로비 로직
│   ├── core.js                # 게임 엔진 (맵/유닛/카메라)
│   ├── combat.js              # 전투 시스템 (이동/공격)
│   ├── skills.js              # 스킬/패시브 정의 + 데미지 계산
│   ├── ui.js                  # UI 렌더링 (네비/미니맵)
│   ├── lobby.js               # 로비 로직 (상점/파티/결과)
│   ├── party-select.js        # 파티 선택 로직
│   ├── common/
│   │   ├── i18n.js            # 다국어 엔진
│   │   ├── modal.js           # 모달 시스템
│   │   └── nav.js             # 네비게이션
│   └── sprites.js             # 스프라이트 렌더링
│
├── data/
│   ├── jab.js                 # 상수/클래스 정의 (CD 객체)
│   ├── tiles.js               # 타일 맵 + SVG
│   ├── stages.js              # 10개 스테이지 정의
│   └── language/
│       ├── ko.js              # 한국어 번역
│       ├── en.js              # 영어 번역
│       └── es.js              # 스페인어 번역
│
└── image/
    ├── tileset/               # 타일 PNG (5개)
    ├── icon/                  # 캐릭터/아이템 아이콘
    └── ...
```

---

## 🔧 기술 스택

| 분류 | 기술 |
|-----|------|
| **Frontend** | HTML5, CSS3, Vanilla JavaScript (프레임워크 없음) |
| **Architecture** | Multi-Page Application (MPA) |
| **Storage** | localStorage (클라이언트 사이드) |
| **Rendering** | CSS Grid + Canvas (타일/유닛) |
| **Deployment** | Cloudflare Pages |
| **i18n** | Custom 다국어 엔진 (dot notation 경로) |

---

## 🎯 게임 흐름

### 1️⃣ 로비 (Lobby)
- 현재 클랜원 목록 확인
- 총 자산(Gold) 확인
- 도감/상점/성소/학원 접근

### 2️⃣ 상점 (Shop)
- 📦 **캐릭터 구매**: 노비스/직업 캐릭터 랜덤 생성 (150-200G)
- 🧪 **경험치 물약**: 3종류 (50/100/150 EXP, 50-100G)
- 📜 **전직서**: 클래스별 전직서 구매 (120-200G)

### 3️⃣ 성소 (Sanctuary)
- 레벨/경험치/잠재력 확인
- 경험치 물약 사용 → 즉시 경험치 획득
- 레벨업 알림

### 4️⃣ 학원 (Academy)
- 클래스 정보 학습
- 스킬/패시브 설명 확인

### 5️⃣ 스테이지 선택 (Stage Select)
- 10개 스테이지 중 선택
- 난이도/적 구성/보스 정보 확인

### 6️⃣ 파티 구성 (Party Select)
- 5명 클랜원 선택
- 각 클랜원의 레벨/클래스/스탯 확인
- 조합 최적화

### 7️⃣ 전투 (Battle)
```
턴 기반 그리드 전투
├─ 캐릭터 선택 (클릭)
├─ 이동 (범위 내 타일 클릭)
├─ 공격 (적 클릭) 또는 스킬 사용
├─ 행동 완료 → 적 턴
└─ 반복: 모든 적 처치 또는 캐릭터 전멸
```

**전투 중 가능한 작업:**
- 📍 이동: 3-4칸 범위 내
- ⚔️ 공격: 인접 또는 원거리
- 💡 스킬: 자원 충분 시 사용 (EP/Mana/Fury)
- 🎨 미니맵: 전체 맵 확인

### 8️⃣ 결과 (Results)
- 🎉 클리어 또는 패배 표시
- 📊 경험치 획득 (적 처치 + 벽 파괴)
- 💰 Gold 보상
- 📈 레벨업 알림

### 9️⃣ 반복
- 로비로 돌아가기
- 추가 클랜원 구매
- 다음 스테이지 도전

---

## 🎮 플레이 팁

### 💡 초급자 팁
1. **처음엔 노비스로 시작** - 5명의 Novice 무료 제공
2. **상점에서 물약 구매** - 경험치 빠르게 획득
3. **균형 잡힌 파티** - 근접 2 + 원거리 2 + 힐러 1
4. **도감 확인** - 클래스/스테이지 정보로 전략 수립

### ⚖️ 난이도별 공략
| 난이도 | 권장 레벨 | 팀 구성 | 전략 |
|-------|---------|--------|------|
| 1-2단계 | 1-3 | 노비스 5명 | 기초 학습 |
| 3-4단계 | 5-7 | 노비스 + 전사 | 전사 강화 |
| 5-6단계 | 8-10 | 다양 클래스 | 클래스 활용 |
| 7-8단계 | 11-13 | 고급 조합 | 스킬 최적화 |
| 9-10단계 | 14-15 | 풀 레벨 팀 | 보스 전략 |

### 🎯 클래스 조합 추천

**균형 조합** (입문자)
```
Warrior (근접) + Knight (방어) + Archer (원거리) + Mage (원거리) + Priest (힐)
```

**공격 중심** (공략 플레이)
```
Warrior + Lancer + Archer + Mage + Priest
```

**방어 중심** (방어 스테이지)
```
Knight + Brawler + Sapper (함정) + Mage + Priest
```

**독 특화** (고급)
```
Assassin (암살) + Archer + Mage + Priest + Summoner
```

---

## 🐛 알려진 문제 및 해결책

### Q: 게임이 느려요
**A**:
- 브라우저 개발자 도구에서 캐시 비우기
- 다른 탭 닫기
- 새로고침 (Cmd/Ctrl + Shift + R)

### Q: 저장 데이터가 초기화되었어요
**A**:
- localStorage는 브라우저 데이터 삭제 시 소실
- 중요한 진행 상황은 메모해두기

### Q: 모바일에서 터치 반응이 느려요
**A**:
- Settings에서 음수 감소 및 VFX 끄기
- 캐시 비우기 후 재시작

---

## 🤝 기여 방법

### 버그 리포트
1. GitHub Issues에서 "Bug Report" 템플릿 선택
2. 상세한 버그 설명 및 재현 방법 작성
3. 스크린샷 첨부

### 기능 제안
1. GitHub Issues에서 "Feature Request" 템플릿 선택
2. 기능 설명 및 사용 사례 작성
3. 관심 있는 사람들의 반응 확인

### 코드 기여
1. Fork 이후 새 브랜치 생성: `git checkout -b feature/기능명`
2. 코드 수정 및 테스트
3. Pull Request 생성
4. 코드 리뷰 후 merge

---

## 📝 라이선스

이 프로젝트는 **MIT 라이선스** 하에 배포됩니다.
자유롭게 사용, 수정, 배포하세요!

---

## 📞 연락처

- **GitHub Issues**: [이슈 리포트](https://github.com/snow2g86/deadline_15/issues)
- **라이브 데모**: https://deadline-15.pages.dev/

---

## 🙏 감사의 말

- 모든 플레이어들의 피드백
- 오픈소스 커뮤니티
- 게임 개발 가이드 공유자들

---

**재미있게 즐겨주세요! Happy Gaming! 🎮**

마지막 업데이트: 2026년 2월 10일
