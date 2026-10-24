# 08. 빌드·출시

> 기준 날짜 2026-10-23 · 게임 버전 0.4.2 (`godot/project.godot` `config/version`)
> 근거 파일:
> - `godot/export_presets.cfg`
> - `godot/project.godot`
> - `godot/README.md (5단계, 결제층 A/B, 6a, 6b)`
> - `godot/addons/SOURCES.md`
> - `godot/data/iap.json`
> - `godot/build/ (파일 크기 실측 2026-10-23)`
> - `server/README.md`
> - `server/wrangler.jsonc (존재만 확인)`
> - `docs/server/api.md (존재만 확인)`
> - `docs/store/checklist_user_tasks.md`
> - `docs/store/age_rating_notes.md`
> - `docs/store/listing.ko.md`
> - `docs/store/odds_disclosure_review.md`
> - `프로젝트 메모리 노트 (monetization.md, release-plan.md, character-customization.md)`
>
> `[확인 필요]` = 코드·데이터·문서에서 확정하지 못한 것. 추측하지 않고 표시만 해 두었습니다.
>
> 이 문서의 "사용자가 해야 할 일"은 `docs/store/checklist_user_tasks.md`를 요약한 것입니다. 스토어 콘솔의 메뉴 이름·정책은 자주 바뀌므로 해당 파일의 [확인 필요]를 그대로 따릅니다.

## 1. 내보내기(Export) 설정 5개

`godot/export_presets.cfg`. 결과물은 `godot/build/`(git 제외). 판 구분은 프리셋의 **기능 태그**(`custom_features`)로 합니다 (`Platform.store()`).

| 프리셋 | 기능 태그 | 결과물 | 주요 설정 | 현재 상태 |
|---|---|---|---|---|
| Windows (STOVE) | `stove` | `build/windows/DEADLINE 15.exe` (+ pck) | x86_64, 회사 show4you, 아이콘 icon.png, **코드 서명 안 함** | 이 맥에서 실행해 보지 못함 (Windows PC 필요) |
| macOS (STOVE) | `stove` | `build/macos/DEADLINE 15.zip` (.app 안에) | **arm64 전용**(인텔 맥 불가, 맞춤 템플릿 `tools/macos_arm64_template.sh`), 번들 ID `xyz.show4you.deadline15`, ad-hoc 서명, **공증 안 함** | 이 맥에서만 바로 실행됨. 배포하려면 Developer ID 서명+공증 필요 |
| Android (Google Play) | `google` | `build/android/DEADLINE15.aab` | Gradle 빌드, minSdk 24, targetSdk 36, **arm64-v8a 만**(armeabi-v7a 제외), 적응형 아이콘, 몰입 모드, versionCode 402 | **출시용 업로드 키 없음**(디버그 키로만 시험 서명) |
| Android (Google Play) APK | `google` | `build/android/DEADLINE15.apk` | 위와 같고 형식만 APK (시험용) | 에뮬레이터(Pixel 8)에서 실행 확인 |
| iOS (App Store) | `apple` | `build/ios/` Xcode 프로젝트 | 번들 ID 같음, iOS **17.0+**, iPhone·iPad, **팀 ID 비어 있음** | 시뮬레이터용 빌드 성공, **실행은 못 해 봄** (Rosetta 필요) |

- **Steam 프리셋은 없습니다.** 사용자 지시로 스팀은 "최후순위 — 아직 진행하지 말 것" (2026-10-18). 만들 때는 프리셋을 복사해 `custom_features="steam"`으로.
- 거르기: `tests/*`, `tools/*`, `build/*`, `dev/*`, `assets/pilot/*`, `*.md`, `*.prev.png`, 안드로이드는 `android/*` 제외. `data/*`(하위 포함)와 `assets/fonts/*.txt`(라이선스)는 반드시 포함 — 빠지면 게임이 데이터를 못 읽습니다.
- **버전**: `project.godot`의 `config/version`(지금 **0.4.2**) 하나만 올리면 윈도/맥 버전이 따라갑니다. 안드로이드 `versionCode`는 `주×10000 + 부×100 + 수`(0.4.2 → 402)이며 두 안드로이드 프리셋의 `version/code`도 함께 올려야 합니다 (`check_mobile6a`가 확인). 버전이 바뀌면 저장된 전투 이어하기는 "이전 버전"이 됩니다.
- iOS 내보내기는 `bash godot/tools/ios_export.sh`(임시 팀 ID로 내보낸 뒤 결제 확장 복사·번역 문구·정리), 그 뒤 Xcode에서 실제 팀 ID로 서명·Archive.
- 안드로이드 Gradle 빌드 틀은 `bash godot/tools/android_build_template.sh`로 만듭니다 (`godot/android/`, git 제외).

## 2. 스토어 계획과 우선순위

사용자 결정(2026-10-18, `monetization` 메모): **스토어마다 그 스토어의 실제 결제 시스템**을 붙입니다.

| 순서 | 판매처 | 대상 | 결제 | 광고 | 현재 |
|---|---|---|---|---|---|
| 1 | **스토브(STOVE)** 인디 | PC (Windows; 맥 지원 여부 [확인 필요]) | STOVE 결제 SDK (Windows 전용 DLL) | 없음 | 결제 연동 **미구현**(빈 틀), Windows PC·STOVE 계정 필요 |
| 2 | **Google Play** | Android | Play Billing | AdMob 보상형 | 코드 연결 완료(가짜 SDK로 시험), 에뮬레이터에서 광고 확인, **실제 결제는 시험 못 함** |
| 3 | **App Store** | iOS | StoreKit 2 (godot-iap) | AdMob 보상형 | 코드 연결 완료, iOS 실행 확인 못 함 |
| 4 (나중) | **Steam** | PC | 해당 없음 (지금은 결제 길 없음) | 없음 | 프리셋 없음, 진행 보류 |

- 등급: PC는 스토브 등급, 모바일은 각 스토어 자체 등급 설문(IARC 등)을 쓰고 게임물관리위원회 별도 절차는 하지 않음(사용자 결정). 등급 신청용 정리: `docs/store/age_rating_notes.md`.
- 대상 연령: 권장 초안 **13세 이상, 아동 대상 아님** (`child_directed=false`) — 사용자 결정 대기.
- 앱 이름 초안: `DEADLINE 15 - 턴제 방어 RPG`. 6개 언어 등록 문구와 개인정보처리방침 초안이 `docs/store/`에 있습니다 (`listing.{ko,en,es,ja,zh-CN,zh-TW}.md`, `privacy_policy_draft.{ko,en}.md`, 확률표 `probabilities.<언어>.md`).
- 패키지/번들 ID: **`xyz.show4you.deadline15`** (구글 패키지·iOS 번들 ID 공통). 같은 구글 계정 조직 `show4you`.
- 새로 등록해야 하는 것: 4개 스토어(스토브·Play·App Store·AdMob) 모두 **DEADLINE 15는 아직 앱/프로젝트가 없음**(2026-10-18 확인). App Store Connect에 있는 "용병단 매니저"는 다른 게임입니다.

## 3. 결제·광고 구조 (개념도)

```
 [게임: Billing 오토로드]  ──▶ 스토어 백엔드 (판마다 하나)
        │                     ├ stove  : 빈 틀 (미구현)
        │                     ├ google : Play Billing 플러그인
        │                     ├ apple  : godot-iap (StoreKit 2)
        │                     ├ none   : steam (결제 없음)
        │                     └ fake   : 개발용 가짜 가게
        ▼
 [결제 확인 서버: Cloudflare Workers + D1]  ◀── 영수증 확인 / 소모 처리 / 환불 목록
        │  (스토어마다 확인기: google ✔ 코드 완성, apple ✔ 코드 완성, stove ✘ 501 미구현)
        ▼
 게임이 서버 확인 뒤 골드 지급 → 디스크 기록 확인 → 스토어에 소모(finish)
```

- 설치 식별자(iid)로 계정 없이 주문을 구분합니다. 재설치 복구: 같은 주문은 24시간·1번 재요청 허용 등 규칙은 `docs/server/api.md`. **iid를 앱 밖(Block Store/Keychain/STOVE 클라우드)에 보존하는 일은 아직 남음.**
- 전투 중 결제는 전투 끝까지 지급을 미룹니다 (전투가 끝날 때 골드를 덮어써 사라지는 문제 방지).
- 환불: 알 수 있으면 골드 회수(0까지만).
- 광고(AdMob 보상형): `Ads` 오토로드, 골드 100·하루 3회. 개발/시험 빌드는 구글 공개 시험 광고, 출시 빌드는 `ADMOB.real`(실제 앱 ID·보상형 단위 채워짐, 2026-10-24) 사용. 남은 일: UMP 동의 메시지 게시, `app-ads.txt`, 스토어 게시 후 앱 연결('검토 필요' 해소). 동의(UMP)·iOS 추적 허용(ATT) 문구 6개 언어 준비됨.
- 플러그인 3종 (출처·해시·라이선스는 `addons/SOURCES.md`): Godot Google Play Billing 3.3.0, Poing AdMob 5.1.0, godot-iap 4.0.3. 모두 GitHub 공식 릴리스, 사용자 허락 하에 받음.

## 4. 서버 (Cloudflare) 상태

| 항목 | 상태 |
|---|---|
| 코드 | `server/` — Workers + D1, 엔드포인트 `GET /v1/health`, `POST /v1/purchases/verify`, `POST /v1/purchases/consume`, `GET /v1/refunds`, `POST /v1/webhooks/apple`; 30분마다 Cron(Google 환불 수집) |
| 시험 | 서버 단독 `npm test` (계정 불필요), 게임과 로컬 연결 시험 (`check_iap --server http://127.0.0.1:8951`, `check_iap_parity`) |
| **배포** | **아직 안 함.** `data/iap.json`의 `IAP_SERVER.stage.url`/`prod.url`이 비어 있음 (현재 dev=가짜, local=127.0.0.1:8951) |
| Google Play 확인 | 코드 완성, HTTP 흉내 시험만 — 실제 키로는 미시험 |
| App Store 확인 | 코드 완성, 시험용 인증서 사슬로만 시험 |
| STOVE 확인 | **미구현** (`501 not_implemented`) — 인디 계정으로 공식 문서(단건 확인·환불 API)를 봐야 확정 가능 |
| 계정 | Cloudflare 계정은 snow2g86@gmail.com (결정). wrangler는 `server/` 안에만 로컬 설치. 배포는 사용자 로그인 후 따로 확인받고 실행 |
| 비용 권장 | Workers Paid 월 5달러 + 사용자 도메인 + WAF 요청 제한 (무료 판은 하루 10만 요청) — 사용자 결정 대기 |

## 5. 사용자가 해야 할 출시 선행 작업 (요약)

원문 `docs/store/checklist_user_tasks.md`(A~G 영역 + 알려 줄 값 목록). 비밀값(키·JSON)은 개발 쪽에 보내지 않는 것이 원칙입니다.

| 영역 | 핵심 일 |
|---|---|
| 0. 공통 | 개발자(판매자) 이름·유형 결정, 지원 이메일, **개인정보처리방침 URL 게시**, **확률표 URL 게시**, 개발자 웹사이트, 대상 연령 결정, 스토어 그래픽 준비 (Play 아이콘 512×512, 대표 이미지 1024×500, 스크린샷) |
| A. Google Play | 개발자 계정(25달러, 신원 확인 1~7일; 개인 계정은 비공개 테스트 12명·14일 요건 가능 [확인 필요]), 결제 프로필, 앱 만들기, **업로드 키 생성·보관**, 첫 AAB 업로드, 인앱 상품 4개 등록, 라이선스 테스터, 서비스 계정 권한, 개인정보·광고·광고 ID·데이터 보안·콘텐츠 등급·타겟층 선언, 스토어 등록정보 |
| B. App Store | Apple Developer Program(연 99달러), 번들 ID 등록, 앱 만들기, **유료 앱 계약·세금·은행(가장 오래 걸림)**, 인앱 상품 4개, 샌드박스 테스터, App Privacy, 연령 등급, ATT 문구 확인, 수출 규정 질문, 서명·업로드, 서버 알림 URL |
| C. AdMob | (완료) 계정, Android/iOS 앱 2개, 보상형 광고 단위 2개, 발급 ID 반영 · (남음) GDPR 동의 메시지·IDFA 메시지, `app-ads.txt`, 스토어 게시 후 앱 연결('검토 필요' 해소) |
| D. Cloudflare | 로그인, D1 데이터베이스 2개(stage/prod), 마이그레이션, 비밀값 등록, `wrangler deploy`, 서버 주소 전달, Google 서비스 계정, Apple 키·웹훅 |
| E. STOVE | 인디 개발자 가입, 프로젝트·상품 4개 등록, 정산 정보(사업자/통장 등), **결제 확인 API 문서 확인**, STOVE SDK 연동, **Windows PC에서 실행·결제 시험**, macOS 지원 여부 |
| 서명 | macOS Developer ID 서명+공증, Windows 코드 서명(권장), 안드로이드 업로드 키 |
| 직접 확인 | 전체 화면, Windows 실행, iOS 실제 기기/시뮬레이터 실행 |
| 결정 | 확률 표시 법규 전문가 확인, prod의 Apple Sandbox 영수증 허용 여부, 환불 시 골드 정책, 정식 앱 아이콘 |

권장 진행 순서(체크리스트 F): ① 공통 결정 → 병렬로 계정 가입(A1·B1·B4·C1·E1) → ② 앱 껍데기·첫 빌드 → ③ AdMob ID 전달(완료) → ④ Cloudflare stage 배포 → ⑤ 상품 등록·테스터로 실제 결제·광고 시험 → ⑥ 선언·등급 → ⑦ prod 배포 후 심사 제출. PC(STOVE)는 결제 API 정보가 풀려야 별도 일정.

## 6. 용량 현황과 축소 계획

**내려받는 크기 — 용량 줄이기 전 → 후 (2026-10-23 `godot/build/` 실측, MB = 10^6 바이트)**

| 결과물 | 전 | 후 |
|---|---|---|
| Windows `DEADLINE 15.exe` + `.pck` | 96.8 + 107.4 = 204.1MB | 96.8 + 43.4 = 140.2MB |
| macOS `DEADLINE 15.zip` | 170.2MB (universal) | 73.3MB (arm64 전용) |
| Android 출시용 AAB `DEADLINE15-release-debugkey.aab` (디버그 키 서명 시험본) | 164.0MB | 74.6MB (arm64-v8a 만) |
| Android 디버그 APK | 278.0MB | 130.7MB |
| iOS `DEADLINE15.pck` (Xcode 프로젝트 안) | 107.4MB | 43.4MB |

항목별 (pck 기준): 뒷모습 `_b` 그림 삭제 -10.5MB · 아이콘 개별 원본(`icon/item`·`icon/skill`) 내보내기 제외 -13.6MB · 정면·스토리 일러스트 손실 WebP(q85) -16.0MB · 글꼴 부분 집합 -23.7MB (글꼴 파일 49.7 → 17.5MB) ·
안드로이드 armeabi-v7a 제외 AAB -25.6MB · macOS arm64 전용 zip -33.3MB. **방법·재생성 절차: `godot/README.md` '용량 줄이기'.**
주의: macOS 는 **인텔 맥에서 실행 안 됨**, 안드로이드는 **32비트 전용 구형 폰 설치 불가**(2026 Play 는 64비트 필수 — Play 는 기기에 맞는 ABI 만 내려 주므로 arm64 폰의 다운로드 크기는 원래 AAB 전체가 아니었음).
글꼴 부분 집합은 이름 입력 범위(한글 전부·가나·라틴·일본/간체/번체 상용 한자)만 번들하고 나머지 글자는 OS 시스템 글꼴이 그림.

**원본 저장소 용량 (git에 올라간 `godot/` 파일 기준 — 아래 표는 용량 줄이기 전 값 약 159MB. 줄인 뒤: 글꼴 17.5MB · 캐릭터 그림 약 15MB 로 약 -65MB, 아이콘 개별 원본은 `item_src`·`skill_src`로 이름만 바뀌어 그대로)**

| 항목 | 용량 | 비고 |
|---|---|---|
| 글꼴 (`assets/fonts`) | 약 49.7MB | Noto Sans KR/JP/SC/TC 가변 글꼴 4개 — 가장 큰 단일 항목 |
| 캐릭터 그림 (`assets/image/character`) | 약 46.8MB | 전신 24+, 뒷모습, 초상화 26, 스토리 초상화 23, 동작 시트 |
| 플러그인 (`addons`) | 약 12.1MB | |
| 소리 (`assets/audio`) | 약 11.0MB | |
| 시험 자료 (`tests`) | 약 9.7MB | 내보내기에서 제외됨 |
| 아이콘 (`assets/image/icon`) | 약 17.7MB | |
| 앱 아이콘 | 약 2.4MB | |

- 디스크에만 있고 git에 안 올리는 **그림·글꼴 원본**: `icon/src` 약 161MB, `character/story/src` 약 16MB, `character/art_src`(정면·스토리 무손실 PNG) 약 28MB, `fonts/src`(전체 글꼴) 약 50MB — **따로 백업 필요**(`.gdignore`로 Godot은 읽지 않음. art_src·fonts/src 는 변환 직전 커밋 `ad48239`의 git 기록에도 있음).
- 지금까지 한 축소: 미사용 개별 이미지(`icon/64x64`) 2,191장+시트 삭제(커밋 457e9f1), 이동 중 달리기(run) 모션 시트 100장 삭제로 약 3.7MB 감소(커밋 fc5af8c).
- **적용 완료(2026-10-23)**: `armeabi-v7a` 제외 · 글꼴 부분 집합 · 그림 WebP · 뒷모습 삭제 · macOS arm64 — 위 표. 남은 후보: 글꼴 4개를 모두 읽는 메모리(이제 약 +28MB) 늦게 읽기, 소리 wav 압축(2.7MB), 초상화·동작 시트 WebP.
- 메모리 참고: 글꼴 4개를 시작할 때 모두 읽음 — 부분 집합으로 정적 메모리 약 +80MB → +28MB.
