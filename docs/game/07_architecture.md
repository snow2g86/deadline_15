# 07. 구조 (폴더·데이터·저장·시험)

> 기준 날짜 2026-10-23 · 게임 버전 0.4.2 (`godot/project.godot` `config/version`)
> 근거 파일:
> - `godot/README.md`
> - `godot/project.godot`
> - `godot/scripts/logic/README.md`
> - `godot/scripts/battle/README.md`
> - `godot/scripts/core/{store,data_db,i18n,router,platform,billing,ads,sound,display,mobile}.gd (머리말)`
> - `godot/data/manifest.json`
> - `godot/tests/baseline/LOCK.json`
> - `godot/addons/SOURCES.md`
> - `프로젝트 메모리 노트 (architecture.md, godot-port.md 등)`
>
> `[확인 필요]` = 코드·데이터·문서에서 확정하지 못한 것. 추측하지 않고 표시만 해 두었습니다.
>
> 엔진: Godot 4.5(.1), 언어: GDScript. 렌더러 `gl_compatibility`, 기준 화면 1280×720.

## 1. 폴더 구조 (godot/)

```
godot/
  project.godot           프로젝트 설정 (이름·버전·오토로드·화면)
  export_presets.cfg      내보내기 설정 5개 (Windows, macOS, Android AAB/APK, iOS)
  data/                   ★ 게임 수치·대본·번역의 원본 (JSON)
    *.json                모듈별 수치 표 (아래 3절)
    lang/{ko,en,es,ja,zh-CN,zh-TW}.json   번역 (화면 글 + 도감·가이드 글 + Godot 화면 글 "gd")
    story/{ko,en,es,ja,zh-CN,zh-TW,sample}.json   스토리 대본
    manifest.json         자동 생성 (파일 개수·sha1 검증용) — 직접 고치지 말 것
  scenes/                 장면 파일 (boot, outer/ 11개 바깥 화면, battle/)
  scripts/
    core/                 오토로드와 공통 도구 (저장, 데이터, 번역, 화면 전환, 결제, 광고, 소리 …)
    logic/                ★ 게임 규칙 (화면 코드 없음) — 전투·성장·상점·성소 등
      battle/             전투 엔진 (battle_engine, battle_action, battle_ai, battle_skills, combat, grid_units, gear_fx, battle_end, battle_query)
    battle/               전투 "화면" (지형 그리기, 유닛 그림, HUD, 연출, 결과, 스토리 창)
    ui/                   바깥 "화면" (로비, 스테이지 선택, 편성, 상점, 성소 …)
  assets/
    image/                그림 원본 (character, icon, map)
    audio/                효과음 23개 + 전투 배경음 1개 (wav)
    fonts/                Noto Sans KR/JP/SC/TC (약 50MB)
    app_icon/             모바일 아이콘·시작 화면 그림
  addons/                 받아 온 플러그인 (Google Play 결제, AdMob, iOS 결제 스크립트) — 출처 addons/SOURCES.md
  third_party/            iOS 결제 네이티브 (내보낼 때만 복사)
  tests/                  시험 (아래 5절)    tools/  데이터 도구·내보내기 보조 스크립트
  build/                  내보낸 결과물 (git 제외)    android/  안드로이드 빌드 틀 (git 제외)
```

저장소 전체 구조(`godot/` 밖): `server/`(결제 확인 서버), `docs/`(문서), 웹판(`index.html`, `js/`, `data/` 등 — **동결**), `tools/`(그림·번역 도구).

> **웹판은 2026-10-18부터 동결**되었습니다. 수치·대본·번역의 원본은 `godot/data/`이며, 웹 쪽 파일을 고쳐도 Godot 판에 반영되지 않습니다. 웹판 폐기 시점은 사용자가 정합니다.

## 2. 오토로드 (게임이 켜질 때 항상 떠 있는 부품 10개)

`project.godot [autoload]` 순서대로입니다.

| 이름 | 파일 | 하는 일 |
|---|---|---|
| `Store` | `core/store.gd` | **저장소 한 곳.** 모든 읽기·쓰기가 여기를 지남. 키→글자 사전 하나를 `user://save.json`에 씀 (지연 저장·임시 파일에 쓴 뒤 바꿔치기·꺼졌을 때 복구) |
| `DataDB` | `core/data_db.gd` | `data/*.json`을 읽어 주는 창구. 읽을 때 manifest의 개수·sha1과 맞춰 보고 어긋나면 오류 |
| `I18n` | `core/i18n.gd` | 번역 `t("키")`, 언어 바꾸기·감지, 글꼴 사슬 |
| `Router` | `core/router.gd` | 화면 전환 한 곳 (`go`, `back`, `launch_battle`) |
| `Platform` | `core/platform.gd` | 어느 판인지 (`stove` / `steam` / `google` / `apple` / `dev`), PC/모바일/터치 판정 — 내보내기 설정의 "기능 태그"로 결정 |
| `Billing` | `core/billing.gd` (+ `billing/` 백엔드들) | 인앱 결제 공통 층 |
| `Ads` | `core/ads.gd` (+ `ads/admob_bridge.gd`) | 보상형 광고 |
| `Sound` | `core/sound.gd` | 배경음·효과음 |
| `Display` | `core/display.gd` | PC 창 모드·크기·전체 화면 |
| `Mobile` | `core/mobile.gd` | 모바일 배율·안전 영역·뒤로 단추·길게 누르기 |

## 3. 데이터 주도 구조

게임 수치와 글은 **코드에 박지 않고 `godot/data/`의 JSON에 둡니다.** 지금 모듈 파일은 17개 입니다.

| 파일 | 내용 |
| `battle_constants.json` | 전투판 크기(8×15), 적 AI 프로필, 전술 보너스 비율, 기사 설정 |
| `constants.json` | 골드·경험치 경제값, 최대 레벨, 등급 상한, 직업 역할·직업군 |
| `daily.json` | 요일 던전 표 (요일별 직업, 4단계 난이도, 동행 직업) |
| `equip.json` | 장비 종류, 뽑기 비용·확률·천장, 강화 확률·비용, 공성 아이템, 전투 물약 |
| `gear.json` | 장비 옵션 풀, 직업 세트, 전설 장비 19종, 드롭 확률, 강화 옵션 |
| `hazards.json` | 맵 환경 효과, 냉기 결계, 룬(마법부여) 종류, 룬 뽑기 가격, 보물상자 확률 |
| `iap.json` | 인앱 결제 상품 4종(가격·스토어 ID), 광고 보상, 서버 주소, AdMob 시험 ID |
| `icons.json` | 아이템·이모지 아이콘 그림 표 |
| `jab.json` | 12직업(+지휘관·소환수) 기본 능력치·성장·자원 |
| `props.json` | 맵 오브젝트(나무·풀) 설정 |
| `skills.json` | 스킬 54개(기본 14 + 책 40) 이름·비용·사거리, 분노 패시브 |
| `soul.json` | 영혼석 저장 키만 |
| `sprites.json` | 캐릭터 그림 표, 동작 시트, 공격 모션 키프레임 (용량이 가장 큼) |
| `stages.json` | 100스테이지, 에피소드, 적 스케일링 상수 |
| `synergy.json` | 클래스 조합 버프 표 |
| `tiles.json` | 지형 종류·이동 비용·높이, 맵 10종 지형 비율/색 |
| `ui.json` | 아래 탭 5개 |

**고치는 순서** (밸런스 조정 예: 뽑기 확률, 가격, 스테이지 적 배율)

1. 해당 JSON을 편집기로 고칩니다. (번역·대본이면 `lang/`, `story/`.)
2. `Godot --headless --path godot --script res://tools/data_tool.gd -- --write` — 모양을 정해진 대로 맞추고 `manifest.json`을 다시 만듭니다. 이걸 잊으면 게임이 켜질 때 "manifest의 sha1과 다릅니다" 오류를 내고, 디버그 빌드 로비에 붉은 `[DEV] 데이터 오류` 띠가 뜹니다.
3. 점검만 하려면 같은 명령에서 `-- --write`를 뺍니다 (끝줄 `DATA_TOOL: OK`).
4. 시험을 돌립니다 (5절). 규칙 시험은 "고정된 기준 데이터 사본"을 읽으므로 **데이터만 고쳐서는 규칙 시험이 깨지지 않습니다.**

> 영향: 모듈 JSON을 고치면 이미 저장된 **전투 이어하기는 "이전 버전" 처리**되어 이어할 수 없고 포기 안내가 나옵니다. 번역·대본만 고치면 이어하기가 유지됩니다.

**코드 안에 있어서 데이터로는 못 바꾸는 수치** (바꾸려면 개발자 필요)

| 무엇 | 위치 |
|---|---|
| 등급 능력치 배율 1.1/1.0/0.9/0.8, 승급 제물 점수 규칙, 부활 무료 쿨다운 30분, 이름 최대 10자 | `sanctuary_rules.gd` |
| 광폭 ×1.5, 고양 ×1.25, 마나 쇄도 ×1.2, 방어막 ×0.5, 회피 30%, 마법사 스플래시 50%, 치명타 확률·배율 | `combat.gd`, `grid_units.gd`, `battle_action.gd` |
| 소환수 능력치 비율(50%/120%), 소환 지속 5턴 | `battle_skills.gd` |
| 처치·행동 경험치 보정, 보물상자 골드 식, 별 3개 턴 한도 식, 스킬북 5% 드롭 | `battle_engine.gd`, `combat.gd`, `profile.gd`, `battle_end.gd` |
| 스킬북 기본가 800/300(×bookMul), 경험치 물약·전투 물약 구성과 가격, 1시간 갱신 | `shop_rules.gd` |
| 적 공성 아이템 확률 40/30/20/10, 쿨다운 3 | `grid_units.gd`, `battle_ai.gd` |
| 광고 쿨/횟수 규칙(시계 보정) 등 | `ad_rules.gd` |

## 4. 로직(logic)과 화면(scripts/battle, ui)의 분리

- **`scripts/logic/` = 규칙.** 노드·장면·오토로드에 기대지 않는 순수 코드 (`RefCounted`/정적 함수). 데이터와 저장소는 `ctx.gd`로 받습니다. 그래서 화면 없이 **머리 없는(headless) 시험**으로 전투를 끝까지 돌릴 수 있습니다. (메모리의 "데이터·로직을 화면 코드와 분리 유지" 방침입니다.)
- **전투 엔진**(`logic/battle/battle_engine.gd`)은 "명령 → 상태 변화 → 신호(사건)"입니다. 화면(`scripts/battle/`)은 그 신호를 받아 그림·소리·연출로 바꾸기만 하고 **규칙을 바꾸지 않습니다.** 최근 UI 개선(왼쪽 패널, 이동 취소, 계산 내역 등)도 "규칙·데이터 불변, 정답 기록 22/22 일치"로 확인되었습니다.
- 화면은 순수 조회(`eng.q` = `battle_query.gd`)로 "이 공격의 예상 피해는?"을 물을 수 있고, 이 조회는 난수·상태를 건드리지 않습니다.
- 난수는 `rng.gd` 하나(씨앗 고정 가능)라 같은 씨앗·같은 명령이면 항상 같은 전투가 됩니다. 이것이 "재생 시험"의 기초입니다.
- 바깥 화면도 `scripts/logic/*_rules.gd`(규칙) ↔ `scripts/ui/*.gd`(화면)로 나뉩니다.

## 5. 저장 형식

- 파일: `user://save.json` — `{ "키": "글자(JSON)" }` 한 개 파일. 임시 파일에 쓴 뒤 바꿔치기, 꺼졌으면 임시 파일로 복구.
- 위치: 개발 실행은 `~/Library/Application Support/Godot/app_userdata/DEADLINE 15/`, **출시(내보낸) 빌드는 별도 폴더** (맥 `~/Library/Application Support/DEADLINE 15/`, 윈도우 `%APPDATA%\DEADLINE 15\`). 즉 개발 세이브와 출시 빌드 세이브는 서로 다른 파일입니다.
- 주요 키 (코드에서 확인한 것):

| 키 | 내용 |
|---|---|
| `game_save` | 골드, 클리어한 스테이지 목록, 별 기록 |
| `game_roster` | 클랜원 전부 (직업, 이름 번호, 레벨, 경험치, 잠재력, 능력치, 스킬 레벨, 장비 장착, 죽음 표시 …) + 지휘관 |
| `game_parties` | 파티 5개 × 5칸, 활성 파티 |
| `game_inventory` | 장비, 룬, 전투 물약, 공성 아이템, 스킬북, 전직서, 경험치 물약 |
| `game_mats`, `game_gacha_pity` | 강화석·보호 주문서·전설 조각, 뽑기 천장 카운터 |
| `game_soul` | 영혼석·조각 |
| `game_shop` | 상점 진열(갱신 시각 포함) |
| `game_daily` | 요일 던전 하루 입장 횟수 |
| `game_settings` | 언어, 소리, 게임 속도(`playSpeed`), 움직임 줄이기, 창이 뒤에 있을 때 소리 |
| `game_story_seen` | 본 스토리 장면 기록 |
| `gd_battle` | 전투 이어하기 저장 (형식 2: 형식·데이터 해시·게임 버전·상태 + md5) |
| `gd_display` | PC 창 모드·크기·위치 |
| `gd_class_preview` | 전직 미리보기(굴린 잠재력 보관) |
| `game_iap`, `game_iap_bak` | 결제 지급 기록(설치 식별자·주문), 깨진 기록 백업 |
| `game_ads`, `game_sanc_ad_cooldown` | 광고 하루 횟수, 무료 부활 쿨다운 |
| `game_nav`, `ps_can_start`, `ps_active_tab` | 출격 정보, 편성 화면 상태 |

- **이상한 값이 든 세이브**: 바깥 화면에 들어올 때마다 `save_sanitize.gd`가 잘못된 항목만 걸러내거나 기본값으로 바꿉니다 (오류 없이). 파티를 통째로 초기화하지 않습니다.
- 숫자는 JS와 같은 방식으로 기본 실수(float)입니다. 번호 성격의 키만 정수로 읽습니다 (`json_norm.gd`).
- **웹판 세이브 가져오기 기능은 만들지 않기로 결정**했습니다.

## 6. 시험 체계

시험은 `godot/tests/`에 있고, 화면 없이(`--headless`) 돌립니다. 모든 시험은 `RESULT: PASS`로 끝나야 합니다.

### 핵심 개념: "황금 기록(golden)"과 "기준(baseline)"

- **황금 기록 22개** (`tests/golden/*.json`): 웹판 코드로 22개 전투 시나리오(보스전, 연습 모드, 공성 아이템, 장비 전설, 요일 던전, 패배 …)를 돌려 **모든 사건과 난수 호출**을 저장한 "정답지"입니다. Godot 규칙이 사건 하나, 난수 하나까지 같게 재현하는지 `replay_golden.gd`가 비교합니다.
- **기준 데이터 사본** (`tests/baseline/data/`): 정답지를 만든 때(2026-10-18)의 데이터 복사본. 시험은 이것을 읽으므로, 디렉터가 밸런스를 바꿔도 시험은 깨지지 않고 "규칙 코드가 바뀌었는지"만 봅니다. `-- --live` 옵션은 지금 데이터로 돌려 "기준과 얼마나 달라졌는지" 영향 보고를 봅니다 (실패해도 이상한 게 아님).
- **잠금** (`tests/baseline/LOCK.json`): 기준 파일들의 sha1 — 몰래 바뀌는 것을 막습니다. 규칙을 일부러 바꿔 정답을 다시 쓸 때는 `--record` → 사람이 diff 검토 → `data_tool --relock "이유"` 순서 (`godot/README.md` "기준을 다시 만들 때").
- 바깥 화면 규칙(상점·성소·아카데미 …)은 웹 코드가 낸 "웹 정답"(`tests/fixtures/outer_4a/4b1/4b2_web.json`)과 비교합니다.

### 시험 목록과 실행

모든 명령은 저장소 맨 위에서 실행합니다. 진짜 세이브를 보호하려면 **임시 HOME**으로 실행하세요 (메모리 규칙). Godot 위치: `/Applications/Godot.app/Contents/MacOS/Godot`.

```
G=/Applications/Godot.app/Contents/MacOS/Godot
HOME=<임시 폴더> $G --headless --path godot --script res://tests/<파일>.gd
```

| 시험 | 확인하는 것 |
|---|---|
| `check_foundation` | 6개 언어 팩·대본 키 맞춤, 데이터 모양·manifest·기준 잠금, 언어 감지, 글꼴 사슬 |
| `check_glyphs` | 6개 언어의 모든 글자가 글꼴에 있는지 (두부 0) |
| `replay_golden` | **황금 기록 22개 재생** (규칙 일치). `-- --resume`: 모든 입력 대기마다 저장·복원해도 같은지 |
| `check_battle_api` | 엔진 조회가 순수한지, 명령 결과, 신호, 숫자 리터럴 |
| `check_battle_scene` | 전투 "장면"을 띄워 황금 기록을 화면 입구로 재생 |
| `check_battle_ui`, `check_battle_ui_adopt`, `check_hill_slope` | 전투 UI(패널·순서 바·이동 취소 동일성 80회·계산 내역·적 범위), 언덕 경사 클릭/높이 |
| `check_outer_4a`, `check_outer_4b1`, `check_outer_4b2` | 바깥 화면 규칙(로비·편성·상점·성소·아카데미·도감·가이드) 웹 정답 비교, 6개 언어 넘침, 연타, 이상한 세이브 |
| `check_pc5` | 소리·화면 설정·플랫폼·내보내기 설정과 pck 내용 |
| `check_mobile6a`, `check_qa6a`, `check_mobile6b` | 모바일 흉내(배치·터치·뒤로·백그라운드), QA 수정, 구글 결제·애플 결제·AdMob 경로 (가짜 SDK) |
| `check_iap`, `check_iap_parity` | 결제 층 전 시나리오, 가짜 서버 ↔ 진짜 로컬 서버 응답 비교 |
| `play_*`, `shots_*`, `perf_battle_scene` | 실제 창에서 사람처럼 한 판, 화면 사진, 성능 측정 (창 필요) |
| 서버 | `cd server && npm test` (vitest), `npm run typecheck` |

- 시험을 돌리면 Godot이 스크립트마다 `*.gd.uid` 파일을 만듭니다 — 지우지 말고 커밋에 넣는 것이 규칙입니다.
- 이 문서를 쓰는 동안(2026-10-23) 시험을 **새로 실행하지는 않았습니다.** 지금 시점의 전체 통과 여부는 [확인 필요]. 가장 최근 커밋 107be0d의 설명은 "규칙·데이터 불변 (replay_golden 22/22)"입니다.
