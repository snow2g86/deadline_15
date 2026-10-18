# DEADLINE 15 — Godot 4 판

웹판(HTML/CSS/JS)을 Godot 4.5 로 옮긴 판입니다. 1~4단계(기초 · 전투 규칙 · 전투 화면 · 바깥 화면)와 5단계(PC 출시 준비: 소리 · 화면 모드 · 내보내기 · 플랫폼 구분) 완료. 다음은 결제(스토브 SDK) · 6단계(모바일).

> **웹판은 동결되었습니다 (2026-10-18).** 수치·대본·번역의 원본은 **`godot/data/`** 입니다. 웹 `data/*.js`·`js/*` 는 더 읽지 않으며
> 거기를 고쳐도 이 판에는 반영되지 않습니다 (`data/FROZEN.md`). 웹 파일의 폐기 시점은 사용자가 정합니다. 웹 세이브 가져오기는 만들지 않습니다.

## 원칙

- **수치·대본·번역의 원본은 `godot/data/**/*.json`** (손으로 고침 — 아래 '데이터 원본'). 고친 뒤 `tools/data_tool.gd -- --write` 로 모양을 맞추고 manifest 를 다시 만듭니다.
- **기준(황금 기록·웹 정답)은 고정**되어 있고, 그때 데이터의 사본(`tests/baseline/data/`)으로 비교합니다 (아래 '기준').
- **그림 원본은 `godot/assets/image/`** (git 에 올림, `*.import` 옆파일 포함 — 2026-10-18 웹 `image/` 를 `git mv` 로 옮김). 저장소 맨 위 `image` 는 웹판용 심볼릭 링크 (아래 '그림').
- 데이터·규칙(`scripts/core`, `scripts/logic`)과 화면(`scripts/ui`, `scenes`)을 나눕니다.

## 폴더

```
godot/
  project.godot        렌더러 gl_compatibility, 1280×720 · 창 크기 조절 · canvas_items 늘이기
  icon.png             앱 아이콘 1024×1024 (5단계: assets/image/character/story/commander_m.png 지휘관 상반신을 잘라 키움 — 새 그림 아님, 전용 아이콘은 남은 일)
  export_presets.cfg   내보내기 프리셋 Windows (STOVE) · macOS (STOVE) — 아래 '5단계' · 결과물은 build/ (git 제외, .gdignore)
  default_bus_layout.tres  오디오 버스 Master · BGM · SFX
  assets/audio/        소리 (5단계: 웹 합성 소리를 구운 wav — tools/legacy-web/audio-bake/README.md)
  scenes/boot.tscn     시작 화면 (메인 씬) — 잠깐 제목을 보여 주고 로비로 (Router). 개발용: -- --dev (예전 시작 화면 + 전투 시험 실행기), -- --screen <이름>, -- --save <경로>
  scenes/outer/        4a 바깥 화면: lobby · stage_select · party_select · settings, 4b-1: shop, 4b-2: sanctuary · academy · compendium · guide · credits · licenses (scripts/ui/*.gd)
  scenes/battle/battle.tscn   전투 장면 (3b: HUD·연출·결과·스토리 — scripts/battle/README.md)
  scripts/core/        오토로드: store.gd(Store) · data_db.gd(DataDB) · i18n.gd(I18n), json_norm.gd(번호 키 int) · num.gd(Num.fmt 표시) · fonts.gd(언어별 글꼴 사슬)
  scripts/logic/       전투·성장 규칙 — 화면 코드 없이 (2b: 웹 전투 규칙 이식, scripts/logic/README.md)
  scripts/logic/battle/  전투 엔진 (battle_engine.gd: 명령 입력·진행·신호)
  scripts/battle/      전투 화면 (3a: 지형·유닛·카메라·조작·엔진 사건 재생, 3b: HUD·툴팁·연출·결과·로딩·스토리 대사 — scripts/battle/README.md)
  scripts/core/sound.gd · display.gd · platform.gd  (5단계) 오토로드 Sound(배경음·효과음·버스) · Display(창 모드·크기) · Platform(가게·기기 구분)
  scripts/core/router.gd  오토로드 Router — 화면 전환 한 곳 (go · back · launch_battle), Esc·마우스 뒤로 단추 → 화면의 on_back()
  scripts/ui/          바깥 화면 (4a): screen_base.gd(윗줄·아래 탭·창·알림 공통) · outer_kit.gd(부품) · lobby · stage_select · party_select ·
                       settings_screen · flow.gd(game_nav → 전투 설정, 이어하기 설정) · boot.gd · dev_launcher.gd
                       4b-1: shop.gd(상점) · party_gear_tabs.gd(편성 화면의 장비·소모품·강화 탭) · item_view.gd(아이템 그림·옵션 줄)
                       4b-2: tabbed_list_screen.gd(골드·탭·카드 목록 공통) · sanctuary.gd(성소) · academy.gd(아카데미) ·
                             codex_screen.gd(도감·가이드 공통 틀) · codex_view.gd(블록 그리기) · compendium.gd(도감) · guide.gd(가이드) ·
                             info_page.gd(크레딧·라이선스 공통) · credits.gd · licenses.gd
  scripts/logic/*_rules.gd  4a 규칙 (화면 코드 없이): lobby_rules(첫 실행·저장값 점검·자동 부활·지휘관) · party_rules(파티 저장·편성·출격 판단) ·
                       progress_rules(해금·별·요일 던전) · settings_rules(설정 키, 전투 설정 창과 공용) · store_ctx.gd(진짜 Store 를 규칙 저장소 모양으로)
                       4b-1: equip_rules(장비·강화·수리·분해·아이템 탭·Gear 표시) · shop_rules(상점 생성·갱신·사기·뽑기) · resume_rules(전투 이어하기 저장 gd_battle)
                       4b-2: sanctuary_rules(부활·무료 부활·영혼석·승급·개명·마법부여) · academy_rules(전직·스킬북) · codex_rules(도감·가이드 내용 블록)
  data/                **데이터 원본** (git 에 올림, 손으로 고침 — '데이터 원본')
    *.json             모듈별 전역 (stages.json 의 STAGES 등 — 웹 전역 이름 그대로)
                       화면 쪽 표: icons.json(ITEM_SPRITE·EMOJI_ICON·ICON_RARITY) · sprites.json(CHAR_SPRITES·CUTOUT_RIGS·
                       CHAR_FIG·SPRITE_SHEETS·ATK_MOTIONS) · ui.json(NAV_TABS) · soul.json(SOUL_KEY)
    lang/{ko,en,es,ja,zh-CN,zh-TW}.json   언어 팩 — Godot 화면 글 gd.* 도 이 안의 "gd" 아래 (예전 lang_extra 를 합침).
                       6개 언어 같은 키 (check_foundation). ja·zh 는 docs/i18n/glossary.*.md 용어
    story/{ko,en,es,ja,zh-CN,zh-TW,sample}.json   스토리 대본
    manifest.json      자동 생성 (data_tool) — 파일별 전역 개수·값 개수·sha1·특수값 위치 (DataDB 가 읽을 때 검증)
  tools/data_tool.gd   데이터 도구 CLI: 점검(--check) · 모양 맞춤 + manifest(--write) · 기준 잠금(--relock). 규칙은 tools/data_format.gd
  assets/image/        그림 원본 (git 에 올림 · *.import 포함). icon/src · character/story/src 는 일러스트 원본(git 제외 · .gdignore 로 Godot 도 안 읽음)
  assets/fonts/        Noto Sans KR·JP·SC·TC (가변 굵기, OFL — OFL.txt 하나가 넷 모두의 라이선스, 같은 글). git 에 올림 (약 50MB).
                       project.godot 기본 글꼴은 KR, 실행 중에는 scripts/core/fonts.gd 가 언어별 사슬로 바꿈 (아래 '글꼴')
  tests/check_foundation.gd   머리 없는 시험 (6개 언어: 팩·대본·gd.* 키 맞춤 · 데이터 원본 모양·manifest·기준 잠금, 언어 감지, 글꼴 사슬)
  tests/check_glyphs.gd        6개 언어 데이터의 모든 글자가 글꼴 사슬에 있는지 + 한자·가나가 그 언어 글꼴로 그려지는지 (두부 0)
  tests/shots_lang6.gd         ja·zh-CN·zh-TW 전투 HUD·설정·대사 화면 사진 (창 모드 → tests/screens/lang6_godot_*.png)
  tests/golden/        전투 황금 기록 (웹 코드로 만든 고정 기준 — 보관: tools/legacy-web/battle-sim.js, tests/golden/README.md)
  tests/baseline/      기준 데이터 data/ (2026-10-18 옮긴 시점 godot/data 사본 — 기준 시험이 읽음) · LOCK.json (golden·fixtures·baseline sha1 잠금)
  tests/baseline_data.gd  기준 시험이 기준 데이터를 읽게 (-- --live 면 지금 데이터)
  tests/replay_golden.gd   2b 시험: 황금 기록 22개를 GDScript 규칙으로 재생해 사건·난수까지 비교
  tests/check_battle_api.gd  엔진 조회 API 순수성·command 결과 시험,  tests/fixtures/js_numbers.json  JS 실수 표기 정답 (node 로 만든 것)
  tests/check_battle_scene.gd  3a·3b: 전투 장면을 머리 없이 띄워 황금 기록을 화면 입구(UI 수준)로 재생 (HUD·연출·스토리 켬) → 결과가 같은지
  tests/check_battle_ui.gd     3b: UI 연기 시험 (모든 패널·팝업·툴팁·결과·스토리·언어 바꾸기, Godot 오류 0)
  tests/perf_battle_scene.gd   창 모드 성능 측정 (유닛 40·맵 오브젝트 ~340·HUD·연출·회전)
  tests/check_outer_4a.gd      4a: 규칙을 웹 정답(tests/fixtures/outer_4a_web.json — 고정 기준, 보관: tools/legacy-web/outer-4a-expect.js)과 비교 · 편성 저장 · 설정 키 ·
                               진짜 장면 흐름 · 6개 언어 넘침·두부 · 창 크기
  tests/play_4a.gd · shots_4a.gd  4a 실제 창 한 판(진짜 입력, '대상 고르기' 멈춤을 세어 PLAY_RESULT) · 화면 사진 (tests/screens/4a_*.png)
  tests/check_outer_4b1.gd     4b-1: 상점·장비·강화·아이템 규칙을 웹 정답(tests/fixtures/outer_4b1_web.json — 고정 기준, 같은 씨앗·시각)과 비교 ·
                               이어하기(끊고 이어도 같은 결과) · 진짜 장면 · 같은 프레임 연타 · 이상한 세이브 · 6개 언어 넘침·두부
  tests/play_4b1.gd            4b-1 실제 창: 로비 → 상점 → 편성(장비·강화) → 전투 → 나가기 → 전투 재개 → 끝 (tests/screens/4b1_*.png, -- --size 1920x1080)
  tests/check_outer_4b2.gd     4b-2: 성소·아카데미 규칙을 웹 정답(tests/fixtures/outer_4b2_web.json — 고정 기준)과 비교 · 도감·가이드 글 조각 = 웹 HTML ·
                               V8 정렬(64개 이상) · 이어하기 판 확인·포기 · 진짜 장면 · 같은 프레임 연타 · 이상한 세이브 · 6개 언어 넘침·두부 · '준비 중' 없음
  tests/play_kit.gd            실제 창 시험 공용 (논리 화면 기준 칸 보이기 · HUD 피하기 · 그리기 기다림 시간 제한)
  tests/aux_class_preview.gd   check_outer_4b2 보조 (다른 프로세스에서 전직 미리보기 보관값 읽기)
  tests/play_4b2.gd            4b-2 실제 창: 로비 → 성소 → 아카데미 → 도감 → 가이드 → 설정 → 크레딧 → 라이선스 → 로비 → 전투 한 판 (tests/screens/4b2_*.png, -- --size 1920x1080)
  tests/check_pc5.gd           5단계: 소리 파일·버스·설정 저장/복원·장면별 배경음·효과음 규칙(엔진 사건 → 소리 수)·화면 설정·플랫폼·창 닫기 저장·6개 언어 넘침·내보내기 설정/pck
  tests/play_pc5.gd            5단계 실제 창: 창 크기 단추·최소 크기·Alt+Enter·Cmd+Ctrl+F·다른 배율 모니터·다음 실행 복원(-- --verify) (tests/screens/pc5_*.png)
  tests/shots_3b.gd            3b 화면 사진 (창 모드 → tests/screens/3b_*.png, git 제외)
```

## 데이터 원본 (2026-10-18~)

`godot/data/` 의 JSON 이 원본입니다. 웹 `data/*.js` → JSON 변환기는 없어졌습니다 (`tools/legacy-web/` 에 보관만, godot/data 를 덮어쓰지 않음).

| 파일 | 내용 | 맨 위 키 |
|---|---|---|
| `data/<모듈>.json` (16개) | 수치 표 — 웹 전역 이름 그대로 (`stages.json` → `EPISODES`·`STAGES`·…, `jab.json` → `JAB`, `tiles.json` → `TI` …) | 전역 이름 |
| `data/lang/<언어>.json` (6개) | 번역. 점 키 `battle.surrender` = `{"battle": {"surrender": …}}`. Godot 화면 글은 `"gd"` 아래 | 영역 이름 |
| `data/story/<언어>.json` (+ `sample`) | 대본 `cast` · `episodes` · `stages.<번호>.{pre,post,battle.{start,wave,boss,danger}}` | `cast`·`episodes`·`stages` |
| `data/manifest.json` | **자동 생성** — 고치지 말 것 | |

**고치는 법**

1. JSON 을 편집기로 고칩니다 (키 순서는 파일 순서 그대로 쓰임 — 정렬하지 않음). 새 모듈은 `data/` 에 새 `*.json`, 새 언어는 `lang/`·`story/` 에.
2. 저장소 맨 위에서:
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tools/data_tool.gd -- --write
   ```
   모양을 정해진 대로 맞추고(아래) `manifest.json` 을 다시 만듭니다. 1초 안팎.
3. 커밋 전 점검 (= 예전 `export-godot-data.js --check`) — 쓰지 않고, 다르면 파일 목록 + 종료 코드 1:
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tools/data_tool.gd
   ```
   끝 줄 `DATA_TOOL: OK`. `check_foundation` 도 같은 점검을 합니다.

- **잊으면**: DataDB 가 읽을 때 파일 sha1 이 manifest 와 다르면 오류를 냅니다 (`... manifest 의 sha1 과 다릅니다 — data_tool --write`).
  값만 고치고 개수가 그대로여도 잡힙니다. 그 실행에서는 전투 이어하기의 데이터 해시를 무효로 해 저장 전투를 '이전 버전'으로 보내고(이어하지 않음),
  디버그 빌드 로비 위쪽에 빨간 `[DEV] 데이터 오류` 띠가 뜹니다.
- **안 받는 입력** (점검·`--write` 모두 오류, 종료 코드 1, **오류가 하나라도 있으면 어떤 파일도 쓰지 않음**): JSON 문법 오류 · 같은 사전에 같은 키 두 번
  (Godot JSON 은 앞 값을 조용히 버리므로 — DataDB 도 오류) · `1e999` 처럼 읽으면 무한이 되는 숫자 · 맨 위가 사전이 아닌 파일 · 전역 이름이 두 모듈에 겹침.
- **정해진 모양** (`tools/data_format.gd`): 들여쓰기 2칸, 배열·사전을 한 줄로 썼을 때 100자 이하면 한 줄(`", "` · `": "`), 넘으면 칸마다 한 줄.
  파일 끝 줄바꿈 하나. 같은 내용이면 늘 같은 글 → diff 에는 고친 줄만 나옵니다 (대사 한 줄 = 한 줄, 그림 행 한 줄 = 한 줄).
- **숫자**: JS 와 같은 가장 짧은 왕복 표기로 씁니다 (`56`, `0.30000000000000004`). 읽기는 `JsonExact`(정확한 10진 → double)라
  모양을 바꿔도 값은 비트 단위로 같습니다. 정수·실수 구분은 파일이 아니라 `json_norm.gd` 의 `INT_KEYS` 가 정합니다 (아래 '주의').
  17자리 실수도 그대로 쓰면 됩니다 (`1.2200000000000002`).
- **특수값**: `Infinity`·`-Infinity`·`NaN` 은 모듈 JSON 에 **문자열** `"Infinity"` 로 씁니다 (예: `TI.rock.cost`). data_tool 이 찾아 manifest.special_values 에 적고 DataDB 가 INF 로 되돌립니다.
  (그래서 모듈 데이터에서 글자 그대로의 "Infinity" 문자열은 쓸 수 없습니다. 번역·대본은 해당 없음.)
- **lang 과 lang_extra 를 합친 이유**: 웹 팩이 원본이 아니게 되어 '웹 키 우선, 없는 키만 더함' 규칙이 의미가 없어짐 · 번역하는 사람이 언어마다 파일 하나만 보면 됨 ·
  DataDB 의 개수·sha1 검증과 check_glyphs 가 화면 글까지 한 번에 덮음. 겹치는 키는 없었고(웹 팩에 `gd` 없음) 합친 뒤 I18n 결과가 같음을 확인.

## 기준 (golden · fixtures) — 고정

황금 기록(`tests/golden/` 22개)과 웹 정답(`tests/fixtures/outer_4a/4b1/4b2_web.json`)은 **웹판 코드로 만든 마지막 정답**이라 이제 다시 만들 수 없습니다.
이 정답은 그때 데이터에서만 맞으므로, 기준과 비교하는 시험은 **그때 데이터의 사본 `tests/baseline/data/`** 를 읽습니다 (`tests/baseline_data.gd`).

- 기준 데이터 시험: `replay_golden` · `check_battle_api` · `check_battle_scene` · `check_battle_ui` · `check_outer_4a/4b1/4b2` (+ 보조 `aux_class_preview`).
  번역은 기준 사본 위에 **지금 데이터에만 있는 키**를 더해 읽습니다 (기준 뒤에 생긴 gd.* 화면 글이 키 그대로 보이지 않게). 대본은 기준 그대로.
- 지금 데이터 시험: `check_foundation` · `check_glyphs` · `perf_battle_scene` · `shots_*` · `play_*` (실제 창), 게임 자체.
- 그래서 **godot/data 를 고쳐도(밸런스·대사·번역) 기준 시험은 깨지지 않고, 규칙 코드가 바뀌었는지만** 계속 확인합니다.
- `-- --live`: 기준 시험을 지금 데이터로 돌림 — 데이터를 바꾼 뒤 기준과 얼마나 달라졌는지 보는 **영향 보고**용 (실패해도 이상한 게 아님).
- **잠금**: `tests/baseline/LOCK.json` 에 golden·fixtures·baseline/data 파일마다 sha1. `data_tool`(과 check_foundation)이 지금 파일과 같은지 확인 — 기준이 몰래 바뀌지 않게.
  (README.md 같은 설명 글은 잠그지 않음)
- 옮긴 시점 확인: 보관된 웹 도구의 `--check` 4개가 웹 코드로 다시 돌려 golden·fixtures 와 같음, 웹 변환기의 결과 = `tests/baseline/data` (29개 파일, 값·키 순서).

## 기준을 다시 만들 때 (절차)

| 바꾼 것 | 기준 | 할 일 |
|---|---|---|
| **데이터만** (godot/data — 밸런스·대사·번역) | 그대로 | `data_tool --write` → 시험. 영향이 궁금하면 `replay_golden.gd -- --live` (기준 사본은 건드리지 않음) |
| **전투 규칙 GDScript** 를 일부러 바꿈 (버그 고침 등) → `replay_golden` 이 어긋남 | 황금 기록 | 아래 1~5 |
| **바깥 화면 규칙** 을 일부러 바꿈 → `check_outer_*` 의 웹 정답 항목이 어긋남 | 웹 정답 | 그 항목의 기대값을 손으로 고치거나 시험에서 '웹과 다른 점'으로 바꿈 (정답을 만든 웹 코드는 없음) → 4~5 |
| **데이터 모양**(키 이름·구조)을 바꿔 기준 사본을 새 코드가 못 읽음 | 기준 데이터 | 같은 변환을 `tests/baseline/data` 에도 적용 (값은 그대로) → `data_tool --write` 대신 손으로 모양 확인 → `replay_golden` 전부 PASS 확인 → 4~5 |
| **기준 데이터를 지금 데이터로 옮김** (큰 밸런스 개편 뒤 영향 보고 대신 새 기준으로 삼기로 함) | 기준 데이터 + 황금 기록 | 아래 '기준 데이터 옮기기' |

황금 기록 다시 쓰기:

1. `Godot --headless --path godot --script res://tests/replay_golden.gd -- --record [--only 이름,이름]`
   — Godot 엔진이 기록된 세이브·시드·주입·아군 명령으로 다시 돌려 같은 모양(한 줄에 사건 하나)으로 씀. 같은 항목은 글자 그대로 두어 **바뀐 곳만** diff 에 나옴
   (아무것도 안 바꾸고 돌리면 22개 모두 '같음', 파일 변화 0 — 확인함). 늘 기준 데이터로 돌립니다 — `--record --live` 는 거부
   (지금 데이터로 기록하면 golden 과 tests/baseline/data 가 서로 어긋나므로. 지금 데이터를 기준으로 삼으려면 아래 '기준 데이터 옮기기').
2. 기록된 명령이 더는 맞지 않으면(데이터·규칙 때문에 전투 흐름이 달라져 다른 유닛이 입력을 기다림) 그 시나리오는 쓰지 않고 실패 —
   시나리오를 새로 짜야 합니다 (`tools/legacy-web/battle-sim/scenarios.js`·`policy.js` 참고. 시험 정책의 Godot 판은 아직 없음).
3. `git diff --stat godot/tests/golden` · `git diff godot/tests/golden/<이름>.json` 으로 **사람이 검토** (바뀐 사건·결과·보상이 의도와 맞는지).
4. `Godot --headless --path godot --script res://tools/data_tool.gd -- --relock "이유"` — LOCK.json 다시 씀 (이유가 LOCK.json 에 남음).
5. 시험 전부 → 커밋 (커밋 글에 이유).

기준 데이터 옮기기 (지금 `godot/data` 를 새 기준으로):

| 차례 | 하는 일 | 명령 |
|---|---|---|
| 0 | 지금 데이터가 정해진 모양 · 오류 0 | `data_tool` (OK 여야 함) |
| 1 | `godot/data` → `tests/baseline/data` 복사 (지움 + 복사) | ┐ |
| 2 | 황금 기록을 새 기준 데이터로 다시 씀 (`replay_golden -- --record`) — 실패하면 1·2 를 모두 되돌리고 멈춤 | ├ `data_tool -- --rebase "이유"` 한 번에 |
| 3 | 잠금 다시 씀 (이유: `rebase: …`) | ┘ |
| 4 | `git diff --stat godot/tests` · 바뀐 황금 기록 검토 | 사람 |
| 5 | `check_outer_4a/4b1/4b2` — 웹 정답은 다시 계산할 수 없으므로, 새 데이터 때문에 바뀐 항목은 기대값을 손으로 고치고 이유를 시험 글에 남김 → `--relock "이유"` | 사람 |
| 6 | 시험 전부 → 커밋 | |

## 전투 이어하기와 데이터 해시

`gd_battle.cfg.dataHash` = manifest.sources(모듈 JSON 파일마다 sha1) 의 md5 — 번역·대본은 넣지 않음 (`resume_rules.gd`).
- 이전 전에는 sources 가 웹 `data/*.js` 의 sha1 이었고, 이제는 `godot/data/<모듈>.json` 의 sha1 입니다. 그래서 **이전 전에 저장된 Godot 전투는 값이 같아도 '이전 버전'** 으로 보여 이어하지 못하고 포기 안내가 나옵니다 (한 번만).
  출시 전이라 괜찮다고 판단 (디렉터 결정 '버전이 다르면 포기 안내'와 같은 길, 오류 없음 — 시험 check_outer_4b2 '이어하기 판 확인').
- 앞으로는 모듈 JSON 을 고치면(`data_tool --write` 로 sha1 이 바뀌면) 저장 전투가 '이전 버전'이 됩니다. 번역·대본만 고치면 그대로 이어집니다. 모양만 다시 맞추는 것은 글이 같아 해시도 같습니다.

## 그림

**원본은 `godot/assets/image/`** 입니다 (2026-10-18 `git mv image godot/assets/image` — 이력 그대로, 그림 2,791개 약 70MB + Godot `*.import` 2,790개).
- 저장소 맨 위 `image` 는 `godot/assets/image` 를 가리키는 **상대 경로 심볼릭 링크** — 웹판(동결)이 폐기 전까지 그대로 열리게. 웹을 지울 때 함께 지우면 됩니다.
- 예전 `tools/sync-godot-assets.sh`(웹 image/ → 사본 복사)는 지웠습니다. 소리 등 다른 자원 폴더는 웹판에 없었습니다 (배경음은 합성).
- 일러스트 원본 `assets/image/icon/src/`(199개 · 약 161MB) · `assets/image/character/story/src/`(23개 · 약 16MB)는 git 에 넣지 않고(.gitignore),
  각 폴더의 `.gdignore` 로 Godot 도 가져오지 않습니다. **디스크에만 있으므로 따로 백업**하세요.
- 작업 중 미리보기 `*.prev.png` 는 Godot 이 가져오며 옆파일을 만들지만 그 `.import` 는 올리지 않습니다 (.gitignore).
- 그림 도구(`tools/import-icons.py` · `make-portrait.py` · `make-back.py` · `make-props.py` · `build-icon-sheet.py` …)도 새 경로를 씁니다.
- 새 그림을 넣거나 처음 받은 저장소: `Godot --headless --path godot --editor --quit` 로 가져오기 (`.godot/` 없이 처음부터 약 13초 · 5,592개 · 113MB 캐시,
  M3 Max 측정. 처음 열 때 글꼴을 아직 못 읽었다는 오류 4줄은 가져오기 전이라 나오는 것 — 한 번 뒤로는 없음). 바뀐 것만 다시 가져오기는 `--import` (약 5초).

## 내보내기(export) 설정

(5단계) 프리셋은 `export_presets.cfg` 에 있습니다 — 아래 '5단계 — 내보내기'. 아래는 그 프리셋이 지키는 조건입니다.

`data/*.json` 은 Godot 리소스가 아니라 `FileAccess` 로 읽는 일반 파일입니다. 내보내기 프리셋을 만들 때
**Resources → Filters to export non-resource files (include_filter) 에 `data/*` 를 꼭 넣으세요** (`data/*, data/lang/*, data/story/*` 처럼 하위 폴더 포함).
**`tests/*`·`tools/*` 는 Exclude filter 에** 넣으세요 (기준 데이터·황금 기록 약 13MB — 게임에는 필요 없음).
빠지면 내보낸 게임에서 DataDB 가 "manifest.json 을 읽지 못했습니다" 오류를 냅니다.
(4b-2) 라이선스 화면이 글꼴 라이선스 전문을 읽으므로 **`assets/fonts/OFL.txt` 도 같은 칸에 넣으세요** (빠지면 OFL 전문 펼치기 단추가 나오지 않음).
게임 버전은 `project.godot` 의 `application/config/version` — 전투 이어하기 저장이 이 값을 기록하므로 출시 때마다 올리세요 (다르면 예전 저장 전투는 '이전 버전' 안내 + 포기).

## 열기 · 실행

- 편집기: Godot 4.5 에서 `godot/project.godot` 열기 → F5 (시작 화면: 제목, 데이터 모듈 개수, 6개 언어 버튼)
- 명령줄: `/Applications/Godot.app/Contents/MacOS/Godot --path godot`

## 시험

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/check_foundation.gd
```

마지막 줄이 `RESULT: PASS (n개 통과)` 이면 성공(종료 코드 0), 실패면 `RESULT: FAIL` 과 실패 항목 목록(종료 코드 1).
글자 시험(6개 언어 × 모든 글자, 끝에 글꼴 읽기 시간·메모리 출력): `... --script res://tests/check_glyphs.gd`

전투 규칙(2b) 시험 — 황금 기록 21개 재생 (`--only 이름`, `--external`, `--rng-log` 는 scripts/logic/README.md):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/replay_golden.gd            # 22개 (-- --resume: 모든 입력 대기마다 저장·복원)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/check_battle_api.gd         # 엔진 조회 API·command·사본·plan_rule
```
전투 장면(3a·3b) 시험 — 화면 입구로 황금 기록 22개 재생 (`-- --smoke` 는 여러 지도 연기 시험), UI 연기 시험 (scripts/battle/README.md):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/check_battle_scene.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/check_battle_ui.gd
```
시험은 `user://test_foundation_save.json` 을 쓰고 지우므로 진짜 저장(`user://save.json`)은 건드리지 않습니다.

## 글꼴 (6개 언어)

한·중·일 통합 한자는 같은 코드라도 언어마다 글자 모양이 달라서(例: 直·骨), 언어마다 맨 앞 글꼴을 바꿉니다 (웹 `css/common.css` 의 `:lang()` 과 같은 순서).

| 언어 | 사슬 (맨 앞 → 대체) |
|---|---|
| ko · en · es | KR → JP → SC → TC |
| ja | JP → KR → SC |
| zh-CN | SC → TC → KR |
| zh-TW | TC → SC → KR |

- 어느 사슬이든 한글·가나·간체·번체가 다 있어, 플레이어가 입력한 이름이 두부(□)로 나오지 않습니다 (`tests/check_glyphs.gd`).
- `Kit.font()`·`Kit.bold(w)` 는 `Fonts.weight(w)` — 굵기마다 **같은 객체**이고, 언어가 바뀌면 그 안의 `base_font`·`fallbacks` 만 바꿔 `changed` 를 보내므로
  `add_theme_font_override` 로 붙인 글꼴도 바로 다시 그려집니다. 대체 글꼴도 같은 굵기(wght)로 만듭니다. 루트 창 테마 기본 글꼴도 같이 바뀌어 테마 없는 화면(시작 화면)도 언어 글꼴.
- 화면 언어와 상관없이 특정 언어 글자 모양이 필요하면 `Fonts.for_lang("ja", 700)` (설정 창의 언어 이름 단추).
- 비용 (M3 Max 실측): 파일 4개 47MB(KR 10 · JP 9 · SC 17 · TC 12). **시작할 때 4개를 모두 읽음**, 약 83ms.
  정적 메모리는 약 **+80MB**(KR 16 · JP 16 · SC 32 · TC 16 — 파일 크기보다 큼).
- 남은 과제(모바일): ko·en·es 데이터 글자는 KR 하나로 다 그려지므로, 모바일에서 메모리가 문제면 현재 언어에 필요 없는 대체 글꼴(JP·SC·TC)을
  필요할 때(예: 그 언어로 바꿀 때·이름 입력 화면) 늦게 읽도록 바꿀 것. 아직 코드에는 없음.

## 오토로드 사용법

```gdscript
# 데이터 (웹 전역 이름 그대로)
var stages: Array = DataDB.global("STAGES")
var hz: Dictionary = DataDB.module("hazards")["HAZARDS"]

# 번역 (웹 t() 와 같은 점 키 · {이름} 자리표시자)
I18n.t("hazard.safe_zone", {"i": "❄️", "r": 3})   # 항상 String (값이 배열·사전이면 키 그대로)
I18n.t_raw("battle.loading_tips")                 # 웹 t() 와 똑같이: 배열·사전 값은 그대로 (Variant)
I18n.set_language("ja")          # game_settings.language 에 저장 + 글꼴 사슬 바꿈 + language_changed 신호 (I18n.LANGS 6개)
# 언어 고르기(웹 i18n.js 와 같음): 저장된 game_settings.language → 없으면 OS 언어 감지(I18n.detect_lang).
#   ko·en·es·ja·zh(Hans/CN/SG→zh-CN, Hant/TW/HK/MO→zh-TW) 외의 언어(fr·de·pt 등)나 빈 값은 en
I18n.t("gd.fail.move_failed")     # Godot 화면 글 (data/lang/<언어>.json 의 "gd" 아래)

# 저장 (웹 Store 와 같은 키 이름, 값은 문자열)
Store.set_json("game_settings", {"language": "ko"})
Store.get_json("game_roster", {})
```

| 웹 `Store` | Godot `Store` |
|---|---|
| `get(k)` | `get_str(k)` (없으면 `null`) |
| `set(k, v)` | `set_str(k, v)` |
| `getJSON(k, fb)` / `setJSON(k, o)` | `get_json(k, fb)` / `set_json(k, o)` |
| `remove` / `keys` / `clear` | 같은 이름 |

`get`/`set` 은 Godot `Object` 의 내장 메서드라 이름을 바꿨습니다.
쓰기는 **지연 저장**입니다: 바꾸면 프레임 끝에 한 번만 파일에 쓰고, 창 닫기·앱 일시정지·종료 때 남은 것을 씁니다. 바로 써야 하면 `Store.flush()`.
파일은 `.tmp` 에 쓴 뒤 rename 한 번으로 덮어쓰고, `save.json` 이 없고 `.tmp` 만 있으면 그것으로 복구합니다. 저장 파일 `user://save.json` 은 `{ "localStorage 키": "문자열" }` 한 사전이라,
웹 저장을 옮길 때는 `JSON.stringify(localStorage)` 결과를 `Store.import_web_dump(dict)` 로 그대로 넣으면 됩니다.

### 주의

- **숫자는 JS 와 같은 모델로 기본 `float`** 입니다 (JS 는 모든 숫자가 실수). 그래서 `1 + exp_pct / 100 == 1.5`,
  `pity / GACHA_PITY_MAX * 100 == 30` 처럼 데이터끼리 나눠도 웹과 결과가 같습니다.
  예외로 **식별자·번호 성격의 키만 `int`** 로 바꿉니다 (`scripts/core/json_norm.gd` 의 `INT_KEYS`).
  - 데이터: `id, phase, episode, stage, stages, spw, si, tier, x, y`
  - 저장(웹 실제 키): `uid, nextId, nameId, lv, level, slots(null 섞임), activePartyId, nextPartyId, party, equipped, enhanceLv, templateId, eid, cleared`
  - 키 없이 배열만 저장되는 `game_cleared`, `game_party`(레거시)는 `INT_ARRAY_STORE_KEYS` 로 배열 전체를 int 로.
  DataDB 와 `Store.get_json` 이 같은 규칙을 씁니다. 그래서 `stage.id` 는 `int 56` 이라 `[id].has(56)`, `match`, `"%s" % id == "56"`,
  `slots.has(uid)`, `cleared.has(2)` 가 웹처럼 됩니다.
- **이식 주의 — int 값을 나누는 곳**: 위 목록의 값을 나눌 때는 `float()` 를 씌우세요 (`int / int` 는 정수 나눗셈).
  - `js/logic/hazards.js:31` `h.dot * (1 + stageLevel(stage) / 100)` — `stageLevel` 이 int 스테이지 번호를 돌려주면 `56 / 100 == 0` 이 되어
    환경 피해가 웹과 달라집니다. 2b 에서 `scripts/logic/stage_rules.gd` 의 `stage_level()` 은 **float 를 돌려주도록** 했습니다.
  - `js/logic/stages.js` `Math.floor(id / ENEMY_SKILL_EVERY)` — 양수라 정수 나눗셈과 결과가 같지만 명시적으로 `floori(float(id) / …)` 권장.
  - 웹에서 데이터끼리 나누는 값(`tot`, `frames`, `hit`, `exp`, `gold` …)은 일부러 목록에서 뺐습니다. INT_KEYS 에 키를 더할 때는 웹 코드에서 그 값을 나누는 곳이 없는지 먼저 확인하세요.
  - 목록 밖의 정수 값(예: `ITEM_SPRITE` 시트 좌표, `JAB.*.base.hp`)은 float 이므로 배열 번호·`match` 에 쓸 때는 `int()` 로 바꾸세요.
- **화면에 숫자를 낼 때는 `Num.fmt(v)`** (`scripts/core/num.gd`): 웹 `String(number)` 와 같은 표기 — 가장 짧은 왕복 유효 숫자,
  `|f| >= 1e21` 이나 `0 < |f| < 1e-6` 은 JS 식 지수 표기 (`56.0 → "56"`, `0.1+0.2 → "0.30000000000000004"`, `1e21 → "1e+21"`, `1e-7 → "1e-7"`).
  `str(56.0)` 은 `"56.0"`, `str(0.1+0.2)` 는 `"0.3"` 이 됩니다.
- **실수 정밀도**: Godot 의 `JSON.parse_string`·`String.to_float`·`str_to_var` 는 17자리 실수를 정확히 읽지 못합니다
  (`"1.3599999999999999"` → 1.36, 무작위 실수의 약 24%가 1ulp 어긋남), `JSON.stringify`·`num_scientific` 도 가장 짧은 표기가 아닙니다.
  그래서 **Store·DataDB·시험·전투 저장은 모두 `scripts/core/json_exact.gd`** 로 읽고 씁니다 (`num_parse.gd` 가 10진 ↔ double 을 정확히, `num.gd` 는 JS 와 같은 가장 짧은 표기).
  새 코드에서 JSON 을 다룰 때도 `JsonExact.parse/stringify` 를 쓰세요. GDScript 소스의 실수 리터럴도 같은 변환을 거치니 17자리 리터럴은 피하세요.
- 번역 자리표시자 값이 `null` 이면 웹처럼 `"null"`, 정수 값 실수는 `"3"` 처럼 표시됩니다.
- JSON 객체의 숫자 키는 문자열이 됩니다 (스토리 `episodes["1"]`, `DAILY.schedule["0"]`).
- `--script` 로 돌리는 시험에서는 오토로드 이름(`Store` 등)을 컴파일 때 쓸 수 없어, core 스크립트끼리는 `preload` 형식 + `/root/...` 경로로 서로를 찾습니다.

## 바깥 화면 (4a) — 웹판과 다른 점

흐름: 시작 화면 → 로비(첫 실행이면 클랜원 만들기·지휘관 설정) → 스테이지 선택 → (출전 전 스토리) → 5명이면 전투, 아니면 편성 → 전투 → 결과 → 로비 / 다음 스테이지.
화면 전환은 오토로드 `Router` 한 곳 (`scripts/core/router.gd`). 규칙은 `scripts/logic/*_rules.gd`, 웹 정답 비교는 `tests/check_outer_4a.gd`.

- **이상한 값이 든 세이브 (디렉터 결정: 웹보다 관대하게, 절대 오류 없이)**: 바깥 화면에 들어올 때마다 `scripts/logic/save_sanitize.gd` 가
  잘못된 항목만 걸러내거나 기본값으로 바꿉니다. 웹처럼 파티를 통째로 초기화하지 않습니다. 올바른 세이브는 손대지 않습니다.
  - 파티: 목록의 null·숫자 항목은 뺌, 글자 id·nextPartyId("2")는 숫자로(JS `+p.id`), 숫자가 아닌 id 는 겹치지 않는 새 번호, 칸은 5칸(정수 uid 또는 null — 숫자 글자는 숫자로)
  - 클리어 기록: 숫자 글자("50")는 숫자로, 숫자가 아닌 것은 버림. stars 가 사전이 아니면(배열 등) 지움, 칸 길이·형이 이상하면 3칸으로
  - `game_daily.used`: 글자 숫자는 숫자로, 소수는 올림, 없거나 숫자가 아니면 0
  - `game_save` 가 숫자·배열이면 `{gold: 2000}`. 빈 문자열 원본("")은 웹 `!raw` 처럼 없는 것으로
  - 로스터: 사전이 아닌 항목·정수가 아닌 uid 는 뺌, 직업이 글자가 아니거나 모르는 직업이면 novice, 잠재력이 `[]`·숫자면 새로 (profile.gd 도 형 검사), 숫자 칸·성별·이름·장비·스킬 레벨은 형이 맞지 않으면 기본값·지움
  - 인벤토리: 사전이 아닌 항목·쓸 수 없는 장비(부위·등급·능력치가 잘못됨)는 뺌. 설정·출격 정보·영혼석·본 장면은 형이 틀린 부분만 지움
  - 그 결과 지휘관은 어떤 세이브에서도 파티에 들어가지 않습니다.
- **연타 막기**: 요일 던전 입장·출격·다음 스테이지·결과 단추·지휘관 확정·초기화·창 단추는 같은 프레임에 여러 번 눌러도 한 번만. Router 도 장면을 바꾸는 중에는 다른 이동을 받지 않음.
- **전투 재개 단추**: (4b-1) 저장 전투가 있으면 로비 맨 앞에 — 아래 '4b-1' 의 이어하기.
- **게임 속도**: 웹 설정 화면의 늘이기 배율 `speed` 대신 전투 설정 창과 같은 1x·2x·4x (`playSpeed`). `playSpeed` 가 없는 웹 세이브는 처음 읽을 때
  speed ≤ 0.5 → 2x, 그 밖 → 1x 로 정해 저장 (디렉터 결정). 웹 `speed` 값은 그대로 둠.
- **언어**: 웹의 드롭다운 대신 전투 설정 창과 같은 6개 단추, 바로 바뀜 (웹은 새로고침). 고를 때만 저장.
- **설정 화면의 뒤로**: 연 화면으로 돌아감 (웹은 늘 로비). 스테이지 목록에서 고른 에피소드는 기록에 남아 유지, 요일 던전 창 열기 같은 한 번만 쓰는 값은 남기지 않음.
- **Esc · 마우스 뒤로 단추**: 웹에 없음. 열린 창을 먼저 닫고, 없으면 화면의 뒤로 단추와 같은 곳.
- **지휘관 설정 창**: 웹 commander.js 는 처음이든 다시 열었든 닫는 길이 없음(확인으로만). Godot 은 첫 설정은 웹처럼 닫을 수 없고, 로비 단추로 다시 열었을 때만 Esc·바깥 누르기로 닫힘.
  이름은 웹과 같게 JS `trim` 공백(전각 공백·NBSP·BOM 등)을 지우고 UTF-16 단위로 10자 (반쪽 글자는 뺌 — Godot 문자열은 반쪽 글자를 담지 못함).
- **다시 도전(Godot 전용)**: 실제 세이브의 요일 던전 결과에서는 뺌 (입장 횟수를 쓰지 않고 다시 들어가게 되므로).
- **다음 스테이지 막다른 길**: 살아 있는 클랜원이 5명 미만이면 편성 화면으로 가는데 출격 단추가 켜지지 않던 웹 버그 — 웹 `js/battle/end.js goNextStage` 와 Godot 을 같이 고침 (`ps_can_start = 'true'`).
- **아이콘**: 시트에 그림이 없는 🔒·ℹ️ 는 선 그림.

### 남은 일
- (4b-2 에서 성소·아카데미·도감·가이드·라이선스·Credits 완료 — 아래 '4b-2') 소리는 5단계에서 완료 (아래 '5단계').
- 좁은 창(480×900 등 휴대폰 폭) 모바일 배치는 PC 출시 뒤로 미룸. 지금은 canvas_items·expand 늘이기라 논리 폭이 늘 1280 이상이어서 깨지지 않지만 작게 보임.

## 4b-1 — 편성 화면의 장비·소모품·강화 탭 · 상점 · 전투 이어하기

규칙은 `scripts/logic/equip_rules.gd` · `shop_rules.gd` · `resume_rules.gd`, 화면은 `scripts/ui/party_gear_tabs.gd` · `shop.gd`.
웹 정답 비교 (고정 기준, 보관: `tools/legacy-web/outer-4b1-expect.js`): `tests/fixtures/outer_4b1_web.json` → `tests/check_outer_4b1.gd` (같은 mulberry32 씨앗·같은 시각으로 웹 코드와 저장값·난수 호출 수까지).

- **무작위 (상점·뽑기·강화)**: 웹과 같은 씨앗·같은 순서. `Math.random` 호출 순서를 줄 단위로 맞췄고, 웹의 `.sort(() => Math.random() - 0.5)` 는
  V8 정렬(TimSort: 64개 미만은 run 세기 + 이진 삽입)의 비교 호출 순서까지 `Js.v8_sort` 로, id 꼬리 `Math.random().toString(36).slice(2, 6)` 은
  V8 `DoubleToRadixCString` 그대로 `Js.rand36_4` 로 재현 (장비 eid 꼬리도 이것으로 바꿈 — 예전 근사는 앞자리 0 을 빼먹을 수 있었음).
- **바깥 화면의 시계**: 상점 갱신 시각(ts)·물약 id 는 진짜 `Date.now()` 가 필요해 `ctx.clock` 을 둠 (screen_base 가 실제 시각, 전투·시험은 가상 시계).
- **웹 버그 (웹은 고치지 않음, Godot 은 바르게)**:
  - 상점 1시간 갱신(`refreshRotatingItems`)이 `_shopData` 를 넣기 전에 `saveShop()` → `game_shop` 에 `"null"` 이 저장됨 (다음에 열면 새 상점 — 갱신된 진열이 저장되지 않음).
    Godot 은 갱신한 상점을 저장. 시험이 웹의 이 버그를 확인하고, 웹이 메모리에 든 상점과 같은지 비교.
  - `ts` 가 숫자가 아닌 상점이면 웹 타이머가 'NaN:aN:aN' — Godot 은 다듬기에서 ts 를 0(→ 갱신)으로, 타이머는 숨김.
  - 웹 소모품 물약은 사도 단추 상태(골드 부족 흐림)를 다시 그리지 않음 — Godot 은 사면 목록을 다시 그림.
  - 스킬북 카드 설명이 웹은 한국어 고정(`LEARNABLE_SKILLS.desc`) — Godot 은 번역 키 `skills_desc.*` 가 있으면 그것.
  - 웹 상점 룬 뽑기 카드의 룬 수가 세로로 흩어져 보임 — Godot 은 그림 + 수를 줄 맞춤 (같은 정보).
- **아이템(소모품) 탭**: 웹과 같이 경험치 물약(exp_s·m·l)과 공성 아이템만 보임 (전투 물약·룬·스킬북·전직서는 웹 탭에도 없음).
- **비교 표시**: 웹과 같은 것 — 장비 탭 카드 장비 칸의 ↑(같은 부위에 더 높은 등급의 안 낀 장비), 장비 창 목록의 '장착 중(이 클랜원 / 다른 클랜원)'.
- **연타 막기**: 자원이 오가는 단추는 화면마다 한 프레임에 한 번 (`screen_base.act_once`). 창의 바깥(어두운 곳) 누르기는 연 뒤 0.3초 동안 무시 —
  창을 연 단추를 두 번 누르면 두 번째가 바로 창을 닫던 것.
- **이상한 세이브**: `save_sanitize.gd` 가 `game_shop`(형이 틀린 물건만 뺌)·`game_mats`·`game_gacha_pity`·`ps_active_tab`·인벤토리 장비 옵션 형까지 다듬음. 정상 세이브는 그대로.
- **전투 이어하기**:
  - Godot 은 입력을 기다릴 때마다(그리고 설정 창 '나가기'에서) 엔진 상태를 **Godot 전용 키 `gd_battle`** 에 저장하고, 그때까지 바뀐 저장값(상자 골드·쓴 물약 …)을 Store 에 씀 (웹은 늘 바로 씀).
    웹 키 `game_battle` 을 쓰지 않는 이유: 웹 로비가 그 키를 보고 웹 형식으로 이어하려다 깨지므로. 웹은 `gd_battle` 을 무시 (왕복 안전 — 시험이 웹 코드로 확인).
  - 저장에 상태 글의 md5 를 넣어, 고치거나 잘린 저장은 '깨진 저장'으로 보고 이어하지 않음 (엔진에 이상한 상태를 넣지 않게).
  - 이어할 때 저장소는 **지금 Store 값**(나가 있는 동안 상점에서 쓴 골드·산 물건 반영 — 웹은 저장소가 하나라 늘 그 값),
    전투 물약·공성 아이템의 인벤토리 번호는 물건 id(pid·sid)로 다시 찾음. 골드·클리어 기록도 웹 전투 페이지처럼 들어올 때 다시 읽음. 출전 전 대사는 다시 보이지 않음.
  - 새 전투를 시작하면 예전 저장 전투는 지워짐 (웹도 전투 저장은 하나), 전투가 끝나면 지움.
  - **웹이 만든 `game_battle`**: 2026-02 이후 웹은 전투 중 저장을 하지 않아(`saveBattle` 을 부르는 곳이 없음) 예전 세이브에만 남음.
    형식이 웹 GameStore 사본(ter·units·eQ …)이라 난수 상태·행동 대기열·엔진 내부 상태가 없고, 유닛 필드도 예전 구조여서 Godot 엔진으로 옮기면
    '같은 전투'를 보장할 수 없음 → 로비 '전투 재개'에서 '웹판에서 시작된 전투라 이어할 수 없음' 안내 + 포기(game_battle 지움)만.
- **전투 설정 창 '나가기'**: 실제 세이브 전투에만 (웹에는 없음 — 웹은 창을 닫으면 전투가 사라짐). 연출 중이면 입력을 기다릴 때 나감.
- **로딩 화면**: 흐려지는 0.4초 동안 누르기를 막지 않도록 고침 (그 사이 첫 행동 메뉴가 뜨면 칸 누르기를 먹어 '대상 고르기'에서 멈춘 것처럼 보였음 — play_4a 멈춤 원인).

## 4b-2 — 성소 · 아카데미 · 도감 · 가이드 · 크레딧 · 라이선스 · 4b-1 검수 남은 것

규칙은 `scripts/logic/sanctuary_rules.gd` · `academy_rules.gd` · `codex_rules.gd`, 화면은 `scripts/ui/sanctuary.gd` · `academy.gd` · `compendium.gd` · `guide.gd` · `credits.gd` · `licenses.gd`.
웹 정답 비교 (고정 기준, 보관: `tools/legacy-web/outer-4b2-expect.js`): `tests/fixtures/outer_4b2_web.json` → `tests/check_outer_4b2.gd`
(성소·아카데미: 같은 mulberry32 씨앗·시각으로 화면 단추 차례대로 → 저장소 전체·난수 호출 수, 도감·가이드: 진짜 언어 팩 ko·en 으로 웹 HTML 을 만들어 태그를 걷어낸 글 조각 6천여 개를 순서까지).

- **'준비 중' 없음**: 로비 도감·가이드, 아래 탭 성소·아카데미, 설정 라이선스·Credits 가 모두 진짜 화면. `gd.outer.coming_soon` 키와 `coming_soon()` 을 지움.
  일부러 남긴 것 (웹 js/shop.js 와 같은 화면, Godot '준비 중' 알림이 아님 — 출시 전에 숨길지는 사용자 결정):
  - 상점 각 탭 맨 위 광고 카드의 꺼진 '추후 개발'(`common.coming_soon`) 단추 (광고 기능 자체가 웹에도 없음)
  - 상점 골드 탭의 결제 꾸러미 카드 4개 — 가격 아래 '추후 오픈 예정'(`shop.gold_iap_coming`), 흐리게 표시되고 누를 수 없음
- **웹판과 다른 점 (웹 버그 — 웹은 고치지 않음)**:
  - 승급 제물 후보의 '파티 편성 제외'를 웹은 옛 키 `game_party`(마이그레이션 때 지워진 레거시)로 봐서 늘 비어 있음 → Godot 은 **지금 활성 파티**(game_parties)의 클랜원과
    (디렉터 결정) **중단된 저장 전투(`gd_battle`)에 나가 있는 클랜원**(state 의 아군 유닛 uid + cfg.party)을 뺌. 그 전투를 포기하거나 끝내면(저장이 지워짐) 다시 후보.
  - 승급 제물이 끼고 있던 장비를 웹은 그대로 둬 '없는 클랜원이 낀 장비'가 남음 → Godot 은 그 장비의 `equipped` 를 비움.
  - 부활: 웹은 페이지를 연 때의 골드(`_gold`)로 계산하고 없는 클랜원이어도 골드를 씀 → Godot 은 누를 때의 저장 골드, 없는 클랜원이면 쓰지 않음.
  - 아카데미 전직: 웹 확인 창은 열 때마다 잠재력을 굴려 '전직 후 예상 스탯'을 보이고 실행 때 또 굴려 실제 능력치가 달라짐(창을 닫았다 열어 '다시 뽑기' 가능) →
    Godot 은 (디렉터 결정) **클랜원 + 대상 직업마다 한 번만 굴려 Store 에 보관**하고 그 값 그대로 전직 (예상 = 결과, 창을 다시 열거나 게임을 다시 켜도 같은 값).
    - 키 `gd_class_preview` (Godot 전용, 웹은 무시) = `{ "<uid>": { "cls": { "<직업>": { "pot": 굴린 잠재력, "grade": 굴린 때 등급, "cls" } } } }` (2026-10-18: 굴린 잠재력만 보관 — 능력치는 볼 때·실행할 때 **지금 레벨**로 다시 계산. 4b-2 판의 fp·능력치 칸이 든 값도 그대로 읽음)
    - 무효 규칙 (2026-10-18 디렉터 결정, `academy_rules.gd` 가 읽을 때 정리): **잠재력 등급이 굴린 때와 다를 때(승급)만** 그 직업 미리보기를 새로 굴림 — 잠재력 굴림은 등급에만 달리고 레벨과 무관하므로 레벨 업·죽음·부활로는 다시 굴리지 않음 (예전 fp 규칙은 레벨 업으로, 다른 노비스 창을 열 때의 정리는 죽은 클랜원 항목을 지워 부활 뒤 다시 굴리는 길이 있었음) /
      uid 가 로스터에 없거나(승급 제물 — uid 는 다시 쓰지 않음) 노비스가 아니면 항목 지움, **죽은 클랜원 항목은 남김** / 전직을 실행하면 그 클랜원 항목 지움 / 키가 비면 키 지움 (시험: 레벨 업·죽음·부활 전후 같은 잠재력·등급, 실행 때 레벨로 다시 계산, 등급이 바뀌면 새로 굴림)
      전직을 실행하면 그 클랜원 항목 지움 / 키가 비면 키 지움
    - 이상한 값: `save_sanitize.gd` 가 사전이 아니면 지우고, 모양이 틀린 항목·직업(숫자 칸·잠재력·등급·모르는 직업)만 뺌. 정상 값은 그대로
    승급 확인 창은 웹처럼 '~' 예상치(실행 때 다시 굴림)를 그대로 둠 — 글에 '~' 가 있어 예상치임이 드러나 있으므로.
  - 전직서·스킬북: 웹은 창을 연 때의 인벤토리 번호로 지움 → Godot 은 그 번호의 물건이 맞는지 보고, 다르면 같은 물건을 다시 찾음.
  - 도감: 웹이 `gear.item.*`(21개)·`maps.*`(8개) 없는 키를 조회해 키를 돌려받던 것 → Godot 은 있는 키만 조회 (화면 글은 같음 — 시험이 '없는 키 조회 0' 확인). `maps.*` 는 어느 언어 팩에도 없어 검색 글에 맵 id 를 씀(웹 대체값과 같음).
  - 도감 직업 상세: 웹의 아래에서 올라오는 시트 대신 가운데 창(✕ · Esc · 바깥 누르기로 닫힘). 탭은 웹처럼 스크롤하면 위에 붙음, 누르면 머리 그림 아래로.
  - 무료 부활(웹 '광고 보기'): 웹처럼 광고 없이 30분마다 1명 (`game_sanc_ad_cooldown`). 실제 광고 연동은 출시 단계 일.
- **크레딧·라이선스**: 뒤로 = 연 화면(설정). 크레딧 글은 웹처럼 영어 그대로. 라이선스: Noto Sans KR·JP·SC·TC(OFL 1.1, `assets/fonts/OFL.txt` 전문) · Godot Engine(MIT 전문 `Engine.get_license_text()`) ·
  엔진의 제3자 구성 요소(`Engine.get_copyright_info()` 95개 · 라이선스 전문 17종 `get_license_info()`). 웹의 Cinzel 은 Godot 판이 쓰지 않아 뺌. 라이선스 원문은 번역하지 않음.
- **전투 이어하기 판 확인 (디렉터 결정)**: `gd_battle` = `{"format":2,"sum":…,"cfg":{…, saveFormat, dataHash, gameVersion},"state":…}`.
  저장 형식(엔진 `SAVE_FORMAT`) · 데이터 해시(manifest.sources 의 sha1 묶음 md5 — 번역은 넣지 않음) · 게임 버전(`application/config/version`) 중 하나라도 지금과 다르거나,
  4b-1 저장(format 1)이거나, `state.format` 이 다르면 로비 '전투 재개' → **'이전 버전의 전투라 이어할 수 없음' 안내 + 포기**. md5 는 저장 글 전체(형식·cfg·state)를 덮음.
  `battle_engine.load_state` 도 형식이 다르면 아무것도 바꾸지 않고 false, 전투 장면은 그때 새로 시작하지 않고 저장을 지우고 로비로.
- **포기 (디렉터 결정)**: 정상 저장 전투도 로비 '전투 재개' 단추 오른쪽 위 ✕ → 확인 창 → 포기 (같은 프레임 연타 막음). 전투 중 이미 저장소에 쓴 것(상자 골드·쓴 물약·쓰러진 클랜원)은 웹처럼 그대로.
- **이어할 때의 저장값 (확정)**: 나가 있는 동안 바뀐 골드·인벤토리(상점에서 산 물건·쓴 골드)는 이어한 전투에 반영(4b-1 방식 그대로). 
  **장비를 바꾸거나 레벨·전직·승급으로 능력치가 바뀌어도 이미 시작한 전투 안의 클랜원 능력치에는 반영하지 않음** (전투 시작 때 정해진 유닛 그대로 — 끝난 뒤 저장소의 로스터에만 반영).
- **V8 정렬**: `Js.v8_sort` 가 V8 TimSort 전체(64개 이상의 최소 run · run 쌓기 · 질주 병합)를 옮김 — node 가 낸 정답과 64~700개 40가지(비교 호출 수까지) 같음. 일관되지 않은 비교 함수(난수)에도 오류 없이 결정적.
- **전투 버프 id**: `combat.gd` 의 새 버프 id 꼬리를 장비 eid 와 같은 `Js.rand36_4`(웹 `Math.random().toString(36).slice(2, 6)` V8 표기)로. 난수 1회는 그대로라 replay_golden 22/22 · --resume 22/22 같음
  (황금 기록에는 버프 id 가 들어 있지 않아 글자 자체의 비교는 없음).
- **로비 골드**: 상점·성소·아카데미와 같이 천 단위 쉼표 (`5,000 G`, 웹 로비는 쉼표 없음). 아지트는 아래 단추 줄(출격) 위에서 끝나고 이름표가 아지트 밖으로 나가지 않음 (10자 이름이 출격 단추와 겹치던 것).
- **전직 확인 창 등급**: 웹은 '등급 + 접미사'를 붙여 써서 영어·스페인어가 'BGrade'·'BGrado' → 접미사가 한중일 글자가 아니면 띄어 씀 (웹 번역 원본은 그대로).
- **저장 파일**: `.tmp` 에 쓰고 `flush()` 한 뒤 이름 바꾸기 (fsync 는 OS 몫 — Godot FileAccess 로 할 수 있는 만큼).
- **V8 라이선스**: `js.gd` 의 `v8_sort`(V8 builtins/array-sort.tq)·`frac_to_base36`/`rand36_4`(V8 DoubleToRadixCString) 이식 → 라이선스 화면에 V8 저작권 표시와 BSD-3-Clause 전문, 함수 위에 출처 주석.
- **play 시험의 누르기**: 누르기·떼기를 같은 프레임에 넣음 (창이 OS 초점을 잃으면 Viewport 가 누르는 중인 단추를 버려 첫 누르기가 가끔 먹히지 않던 것 — 창 크기 문제가 아님). 실패하면 바로 끝냄.
  공용 `tests/play_kit.gd`: 칸이 보이는지를 **논리 화면**(`root.get_visible_rect()`)으로 재고 HUD(`ui.over_hud`) 위의 칸은 카메라를 옮긴 뒤 누름
  (예전엔 물리 크기 `root.size` 로 재서 1920 창에서 HUD 밑 칸을 눌러 '대상 고르기'가 풀리지 않는 일이 있었음), 화면 사진(frame_post_draw)·전투 로딩 뒤 첫 입력 대기에 시간 제한(넘으면 실패로 끝냄).

## 2026-10-18 — 데이터 원본 이전 · 4b-2 검수 남은 것

- 데이터 원본 이전 · 기준 고정 · 웹 도구 보관: 위 '데이터 원본' · '기준' · '기준을 다시 만들 때' · `tools/legacy-web/README.md`. 웹 왕복 시험(check_outer_4b1·4b2 의 `--roundtrip`)은 웹 세이브 가져오기를 만들지 않기로 해서 뺌.
- **전직 미리보기**: 위 4b-2 의 `gd_class_preview` (무효는 등급 변화만, 능력치는 실행 때 레벨로).
- **성소 승급 탭 성능**: 카드마다 로스터·활성 파티·gd_battle(큰 JSON)을 다시 읽던 것 → `Sanc.promote_ctx(c)` 한 번 읽어 모든 카드에 (`promote_state(c, ch, pc)`).
  시험 `check_outer_4b2 -- --only perf`: 클랜원 60명 + 실제 저장 전투로 승급 탭 그리기 시간 (목표 150ms 이하).
- **'last' 대사**: 발동을 지운 '마지막 적 하나' 대사를 6개 언어 대본 + sample 에서 지움 (각 88개, sample 1개), `story_battle.gd` BATTLE_KINDS·PRIORITY 에서도 뺌.
  기준 데이터의 대본에는 남아 있음 (기준은 고치지 않음 — 코드가 'last' 를 모르므로 쓰이지 않음).
- **play 시험 결과**: `PlayKit.verdict` — HUD 에 가려 칸을 못 누르고 Esc 로 넘긴 횟수(hud_blocked)가 0 이 아니면 `PLAY_WARN` + `PLAY_RESULT: WARN (HUD 가림 n번)`, 종료 코드 2 (실패는 1, 통과 0).

## 5단계 — PC 출시 준비 (2026-10-18)

PC 판은 **스토브(STOVE) 인디**로 먼저 냅니다. 스팀 설정은 아직 없습니다. 결제(스토브 SDK)·광고는 다음 단계입니다.

### 소리 (`scripts/core/sound.gd`, 오토로드 Sound)

- **방식: 미리 구운 파일** (`assets/audio/` — 효과음 23개 + 전투 배경음 1개). 웹 `js/battle/audio.js` 를 Chrome WebAudio(OfflineAudioContext) 로 그대로 돌려 구웠습니다.
  실시간 합성(AudioStreamGenerator)을 쓰지 않은 이유: 웹 배경음은 Chrome 의 압축기(DynamicsCompressor)·필터를 거치므로 같은 엔진으로 구워야 소리가 같고,
  배경음 한 주기에 발음 약 1만 개라 GDScript 로 매 샘플 합성하면 CPU 를 많이 씀 (모바일 6단계도 고려). 굽기·비교 방법과 결과: `tools/legacy-web/audio-bake/README.md`.
- 배경음은 130 BPM 8분음표 512개 = 118.15초가 한 주기, 가져오기에서 앞으로 반복(`edit/loop_mode=2`, QOA 압축). 끝 → 처음이 이어지게 둘째 주기를 잘라 씀.
- **버스**: Master ─ BGM(배경음) · SFX(효과음). BGM 음량 = `bgmVol`(구울 때 웹 master 0.16 포함), SFX 음량 = `sfxVol / 0.7`(웹 기본값으로 구움), 끄면 음소거.
  Master 는 창이 뒤로 갔을 때만 씀.
- **장면 규칙 (웹 그대로)** — 웹에서 소리가 나는 곳은 전투 페이지뿐입니다.
  | 때 | 소리 |
  |---|---|
  | 바깥 화면 11개 (로비·상점·설정 …) | 없음 (웹도 없음 — 로비 곡·보스 곡은 웹에 없음) |
  | 새 전투 | 로딩이 끝나면 전투 배경음 (웹 `_showLoading().then(bgmStart)`) |
  | 이어하기 | 들어오자마자 (웹 `resumeBattle` 은 로딩을 닫기 전에 `bgmStart`) |
  | 웨이브·보스 | 곡은 그대로 (웨이브 효과음만) |
  | 전투 끝 | 승리 `victory` / 패배·항복 `defeat` + 배경음 0.6초 줄이며 멈춤 (웹 `bgmStop`) |
  | 화면을 떠남 | 배경음·효과음 바로 끊음 (웹 페이지 이동) |
  | 설정에서 배경음 끄기 / 켜기 | 0.6초 줄이며 멈춤 / 전투 중이면 처음부터 (웹 `setBGMOn`) |
- **효과음 시점 (웹 그대로)**: 웹 `Audio` 구독(공격 = 공격자 직업 소리 · 처치 · 회복 · 웨이브(첫 배치 제외) · 끝) + VFX 구독(보물상자 → 회복, 성문 공격/파괴, 적 AI 스킬)
  + 행동 코드의 `Fx.sfx`(아군 차례 메뉴 `select` · 이동 `move` · 대기/방어/경계 `wait` · 이동 취소 `uiclick`)
  + **스킬 코드 안의 `G.sfx*`** — 엔진이 그 자리에서 소리 힌트 `fx_event "sfx"` 를 냄(`battle_engine.sfx()`, `battle_skills._sfx/_sfx_kill`, `combat.gd` 대신 맞은 클랜원 쓰러짐).
  힌트는 소리만 — 기록(rec)·순수 조회·규칙에 들어가지 않아 황금 기록은 그대로입니다.
  웹은 사건이 나는 순간 소리를 내므로 처치 소리를 웹이 알림을 내는 시점에 맞춥니다 (`_peek_same_hit`):
  아군 일반 공격은 휘두를 때 함께(웹 action.js 는 동기로 알림), 적 AI 공격은 맞는 순간 + 0.12초(ai.js `hd + 120`), 경계 사격은 max(0.55, 맞는 순간 + 0.15)초(ai.js `_overwatch`),
  튀김 피해·반격·지원·창벽·범위 공격·전사 강타는 같은 순간. 그 밖에는 Godot 재생 대기열에서 그 사건을 재생할 때.
  - 남은 차이: 적 AI 공격인지는 그 앞의 `camera_focus` 알림으로 가립니다 (엔진 알림에 표시를 더하면 황금 기록이 바뀌므로). 지원 공격이 끼거나 반격으로 공격자가 쓰러진 처치는
    대기열 재생 시점 — 웹과 최대 수백 ms 다를 수 있음. 웹 아군 공격의 '반격으로 공격자 쓰러짐' 처치음은 웹이 휘두를 때(반격 전에) 내는데 Godot 은 반격 뒤.
  - `select`: 웹은 차례가 오면·자기 클랜원을 다시 누르면(action.js 148·154·159, 카드 누르기) 냄 → Godot 도 같은 자리 + 이동 취소 뒤 메뉴가 다시 뜰 때
    (웹은 취소하면 메뉴가 닫혀 다시 눌러야 하므로 그때 Select — Godot 은 메뉴가 바로 뜸).
- **효과음 수 시험**: `tools/legacy-web/audio-bake/sfx-count.js` 가 황금 기록 시나리오 6개를 웹 전투 코드로 다시 돌리며 웹 코드의 소리 자리(audio.js 구독·sfxAtk 표, vfx.js 의 Audio 호출,
  Fx.sfx, 스킬의 G.sfx*)를 그대로 살려 센 표 `tests/pc5_fixtures/sfx_web.json` 과 Godot 이 실제로 낸 소리 수를 비교 (check_pc5 '4) sfx'). select 는 웹 시험 정책의 누르기 횟수에 달려 범위로만 봄.
- 웹과 다른 점 (웹 버그): 웹은 일부 소리(마법사·궁수 공격의 휘는 음, 쓰러짐)가 효과음 음량·끄기를 거치지 않고, 전투 중 배경음 밀대를 움직이면 배율이 0.16 → 0.12 로 바뀜.
  Godot 은 모두 버스를 거침 (기본 음량에서는 웹과 같은 소리).
- **창 초점 (PC)**: 창이 뒤로 가면 `bgAudio` 대로 — 그대로(1) · **줄이기(0.25, 기본)** · 끄기(0), 0.25초에 걸쳐. 설정 화면 '창이 뒤에 있을 때 소리'.

### 화면 (`scripts/core/display.gd`, 오토로드 Display)

- 설정 화면(PC 만): **화면 모드** 창 모드 / 전체 화면, **창 크기**(창 모드일 때) — 그 모니터 작업 영역에 들어가는 1024×576 · 1280×720 · 1366×768 · 1600×900 · 1920×1080 · 2560×1440 · 3200×1800 · 3840×2160.
  창 가장자리를 끌어 바꾼 크기도 저장. 전체 화면 = `Window.MODE_FULLSCREEN` (Windows: 테두리 없는 전체 화면 창, macOS: 시스템 전체 화면 공간).
- 단축키: **Alt+Enter** (모든 OS), macOS **Cmd+Ctrl+F** (시스템 메뉴가 먼저 받으면 macOS 가 바꾸고 Display 는 모드만 따라감). 초록 단추로 바꿔도 따라감.
- **크기는 논리 단위** = macOS 포인트 / Windows 픽셀 (`Display.scale_of`).
  - macOS 의 Godot 은 **모든 모니터**의 좌표·크기와 창 크기를 '포인트 × 가장 큰 배율(`screen_get_max_scale`)' 단위로 다룹니다
    (`platform/macos/display_server_macos.mm`). 그래서 모니터별 배율(`screen_get_scale`)이 아니라 max_scale 로 나눕니다.
    예: 맥북 레티나(2) + 외부 1080p(1) → 두 모니터 모두 ÷2 (외부 1080p 의 1920×1080 포인트가 Godot 에서는 3840×2160).
    (5단계 검수에서 고침: 처음에는 모니터별 배율을 써서 외부 1080p 에서 크기 단추가 2560×1440 까지 보이고 '1280×720' 이 실제 640×360, 최소 크기도 절반이었음)
  - Windows·Linux(X11): Godot 단위 = 실제 픽셀, `screen_get_scale` 은 1 (Godot 문서: macOS·Wayland·모바일·웹만 구현) → 논리 = 픽셀.
    Windows 의 125·150% 배율은 반영하지 않음 (픽셀 기준 — 보통의 PC 게임과 같음, Windows 에서 확인 필요). Linux 는 출시 대상이 아님.
  - 레티나에서 '1280×720' 은 Godot 2560×1440 단위 창 = 일반 모니터의 1280×720 과 같은 실제 크기 (예전에는 레티나에서 640×360 포인트로 작게 떴음).
- **최소 창 크기 1024×576** (논리, `Window.min_size` = × scale_of). macOS 는 모니터 사이를 옮겨도 단위가 같아 창의 포인트 크기가 그대로입니다.
  모니터를 꽂거나 빼 max_scale 이 바뀌면 최소 크기를 다시 계산하고 논리 크기를 지킴.
  확인(play_pc5): 창의 실제 크기를 Godot 계산과 따로 — macOS 가 알려 주는 모니터 포인트(NSScreen, osascript) × 창이 모니터에서 차지하는 비율로 재서
  레티나·외부 1080p 모두 1600×900·1280×720·최소 1024×576 포인트, 외부 1080p 의 가장 큰 크기 단추 1600×900 (작업 영역 1920×1080 포인트 안).
- **전체 화면 요청이 무시되면** 창 모드로 되돌리고 저장값도 windowed 로 (`Display.fs_step` · `really_fullscreen`): 요청 뒤 4초 안에 창이 그 모니터 작업 영역을
  **0.5초 연속** 덮으면 유지, 아니면 되돌림. macOS 는 앞에 없는 창의 요청 직후 한 프레임만 작업 영역 크기를 알려 주고 원래 크기로 돌아올 수 있어
  '한 프레임이라도 참'으로 끝내지 않음 (재검수에서 고침). Alt+Enter · Cmd+Ctrl+F · 설정 단추 · 저장값 복원 · macOS 초록 단추/시스템 메뉴(크기 바뀜 알림) 모두 같은 판정.
  시험: check_pc5 가 프레임 순서를 넣어 '한 프레임만 큼 → 4초 뒤 되돌림', '0.7초 뒤부터 계속 큼 → 유지', '자꾸 작아짐 → 되돌림'을 확인,
  play_pc5 가 Finder 를 앞으로 보낸(open -a) 창과 앞에 있는 창 모두에서 판정 시간이 지난 뒤 저장값 = 실제인지 확인. 노치 맥북의 전체 화면은 메뉴 막대 줄을 뺀 영역이라 '작업 영역 이상'으로 판단.
- **처음 실행**: 그 모니터 작업 영역의 80% 안에 드는 가장 큰 목록 크기 (1366×768 노트북 → 1024×576, 1080p → 1366×768, 맥북 레티나 → 1366×768, 4K → 2560×1440), 가운데.
- **다음 실행 복원**: 크기·위치·모드. 저장한 위치가 지금 어느 모니터에도 걸치지 않으면(모니터를 뺐음) 창이 뜬 모니터 가운데로, 모니터보다 크면 비율을 지켜 줄임.
- 늘이기는 그대로 `canvas_items` + `expand` (논리 화면 1280×720 기준 — 모바일 배치는 6단계).
- 개발용 명령줄(`--dev` · `--save` · `--screen` · `--lang`, Platform 의 `--store`)은 **디버그 빌드에서만** 받습니다 (출시 빌드는 무시).
- `--script` 로 도는 시험(play_4a 등)은 창을 시험이 정하므로 Display 가 저장값을 읽지도 쓰지도 않습니다(`managed = false`). Display 를 시험할 때는 `manage()` (play_pc5).
  머리 없는 실행은 창을 건드리지 않음 (계산 함수만).
- 창 제목 `DEADLINE 15`. 시작할 때 Godot 로고 대신 게임 바탕색(#0a0e1a) 빈 화면(`boot_splash/show_image=false`, 기본 지우기 색도 같음) → 제목 화면 0.6초 → 로비.

### 새 설정 키 (Store)

| 키 | 형식 | 이상한 값 |
|---|---|---|
| `game_settings.bgAudio` | `"play"` · `"lower"`(기본) · `"mute"` — 고를 때만 저장 (`SettingsRules.bg_audio/set_bg_audio`) | 모르는 값·글자가 아님 → `"lower"` |
| `gd_display` (Godot 전용, 웹 없음) | `{"mode": "windowed"\|"fullscreen", "w": 1600, "h": 900, "x": 3840, "y": 122}` — w·h 는 창 모드 논리 크기, x·y 는 Godot 화면 좌표(픽셀) | `Display.sanitize`: 모드는 둘 중 하나가 아니면 windowed, 크기는 정수만 · 1024×576 ~ 16384, 위치는 둘 다 정수일 때만 |
| 소리 키 (`bgmOn`·`bgmVol`·`sfxOn`·`sfxVol`, 웹과 같음) | 그대로 | `Sound.sanitize`: bool 이 아니면 기본, 숫자가 아니면 기본(0.5·0.7), 0~1 로 자름 |

'모든 데이터 초기화'는 두 키도 지웁니다 (지금 창은 그대로, 다음 실행은 처음 크기).

### 플랫폼 구분 (`scripts/core/platform.gd`, 오토로드 Platform)

- `Platform.store()` = `"stove"` · `"steam"` · `"google"` · `"apple"` · `"dev"` — **내보내기 프리셋의 기능 태그**(custom_features)로 정함. 태그가 없으면(편집기·명령줄·시험) `"dev"`.
  디버그 실행에서는 `-- --store stove` 로 바꿔 볼 수 있음 (시험: `override_store()`).
- `is_pc()`(기능 태그 pc) · `is_mobile()` · `has_ads()` · `has_iap()` · `is_release_build()`(template).
- **상점 광고 카드**(`shop.gd _ad_card`): `has_ads()` 가 거짓이면(stove·steam) 6개 탭 모두에서 숨김. dev 는 웹 화면 그대로 보임(기존 시험·사진과 같게).
  **결제 카드 4개는 그대로**('추후 오픈 예정' — 결제 연동은 다음 단계). 성소의 무료 부활(웹 '광고 보기' 자리)은 광고 없이 30분마다라 그대로.
- 스팀 판을 만들 때: 프리셋을 복사해 `custom_features="steam"` 으로 (사용자가 말할 때까지 만들지 않음).

### 전투 중 창 닫기

입력을 기다릴 때마다 자동 저장(4b-1)에 더해, **창을 닫으면(WM_CLOSE_REQUEST)** 실제 세이브 전투는 그 순간 엔진 상태(엔진은 연출과 상관없이 이미 다음 입력 대기까지 진행해 있음)를
`gd_battle` 로 저장하고 바로 디스크에 씀 (`battle_scene.save_on_close`). 다음 실행 로비의 '전투 재개'로 이어 함. 끝난 전투는 저장하지 않음.
Store 는 오토로드 순서상 닫기 알림을 먼저 받아 쓰므로, 뒤에 쓰는 쪽(전투·Display)이 `Store.flush()` 를 한 번 더 부름.

### 세이브 위치 (`user://`)

| 실행 | 위치 |
|---|---|
| 편집기·명령줄(`Godot --path godot`) — **지금 개발 세이브** | macOS `~/Library/Application Support/Godot/app_userdata/DEADLINE 15/` (바뀌지 않음) |
| 내보낸 빌드 macOS | `~/Library/Application Support/DEADLINE 15/` |
| 내보낸 빌드 Windows | `%APPDATA%\DEADLINE 15\` (`C:\Users\<이름>\AppData\Roaming\DEADLINE 15\`) |

- `project.godot`: `config/use_custom_user_dir=false` + `config/use_custom_user_dir.template=true` + `config/custom_user_dir_name="DEADLINE 15"` —
  기능 태그 template(내보낸 빌드)에서만 게임 전용 폴더. 그래서 **개발 세이브와 출시 빌드 세이브는 서로 다른 파일**이고, 출시 빌드를 처음 켜면 새 게임입니다
  (개발 세이브를 옮기려면 `save.json` 을 위 폴더로 복사). 내보낸 빌드는 같은 폴더의 `logs/godot.log` 에 기록을 남김.
- 확인: 임시 HOME 으로 내보낸 macOS 앱을 실행 → `$HOME/Library/Application Support/DEADLINE 15/save.json` 생성 (2026-10-18).

- 시험을 돌리면 Godot 이 스크립트마다 `*.gd.uid` 를 만듭니다 — 지우지 말고 커밋에 넣으세요 (5단계 검수 결정).

### 5단계 — 내보내기

| 프리셋 | 결과물 | 내용 |
|---|---|---|
| Windows (STOVE) | `build/windows/DEADLINE 15.exe` + `.pck` | x86_64, 기능 태그 stove, 회사 show4you · 제품 DEADLINE 15 · 파일/제품 버전 빈칸 = `config/version`, 아이콘 icon.png, 서명 안 함 |
| macOS (STOVE) | `build/macos/DEADLINE 15.zip` (안에 `DEADLINE 15.app`) | universal(x86_64 + arm64), 번들 ID `xyz.show4you.deadline15`, 버전 빈칸 = `config/version`, 분류 Games, 서명 = 내장 ad-hoc(로컬 실행만), 공증 안 함 |

```bash
HOME=<임시 HOME — export_templates 를 그 안에 연결> /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --export-release "macOS (STOVE)" "build/macos/DEADLINE 15.zip"
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --export-release "Windows (STOVE)" "build/windows/DEADLINE 15.exe"
```

- 거르기: 넣기 `data/*, data/lang/*, data/story/*, assets/fonts/*.txt`(OFL), 빼기 `tests/*, tools/*, build/*, *.md, *.prev.png`(작업 중 미리보기). 그림 원본 src 는 `.gdignore` 라 Godot 이 모름.
  check_pc5 는 build/ 의 pck(맥은 zip 안)가 **소스보다 오래되었으면 실패** (scripts·scenes·data·assets·project.godot·export_presets.cfg 의 수정 시각 비교 — build/ 가 없으면 건너뜀).
  확인(2026-10-18, 검수 뒤 마지막 내보내기): 두 pck 모두 파일 5,877개, `tests/`·`tools/`·`tests/baseline`·src·`*.prev.png` 없음, `data/*`·`OFL.txt`·소리 있음 (check_pc5 '9) export' 가 build/ 의 pck 를 직접 읽어 확인).
  (pck 안에 `res://tests/...` 글자가 보이는 것은 uid 캐시의 경로 문자열일 뿐 파일은 없음)
- 크기: pck 106MB (글꼴 47MB · 그림 · 소리 2.6MB), Windows exe 97MB, macOS zip 167MB.
- `rendering/textures/vram_compression/import_etc2_astc=true` — macOS universal·arm64 내보내기의 필수 조건 (그림은 모두 무손실이라 다시 가져온 것 없음).
- 버전 올리기: `project.godot` 의 `application/config/version` 하나만 (두 프리셋이 빈칸이라 이 값을 씀). 전투 이어하기 저장도 이 값을 봄.

**코드 서명 · 공증 (사용자 계정·인증서가 필요해 하지 않음 — 절차만)**

- macOS (배포용):
  1. Apple Developer Program 가입 → Xcode/키체인에서 **Developer ID Application** 인증서 만들기 (+ 앱 전용 암호 또는 App Store Connect API 키).
  2. 프리셋 macOS: `codesign/codesign=3`(Xcode codesign) 또는 `2`(rcodesign), `codesign/identity="Developer ID Application: … (TEAMID)"`, `codesign/apple_team_id`.
     Hardened Runtime 은 Godot 기본으로 켜짐. 필요한 entitlement 없음(마이크·카메라 안 씀).
  3. `notarization/notarization=1`(notarytool) + Apple ID·앱 전용 암호(또는 API 키) → 내보내기가 공증 요청. 끝나면 `xcrun stapler staple "DEADLINE 15.app"`.
  4. 확인: `spctl -a -vv "DEADLINE 15.app"` → `source=Notarized Developer ID`.
  지금의 ad-hoc 서명은 이 맥에서만 바로 열림 — 다른 맥에서 받은 zip 은 Gatekeeper 가 막음(오른쪽 클릭 → 열기 필요).
- Windows:
  1. 코드 서명 인증서(OV 또는 EV — EV 는 SmartScreen 평판이 바로 쌓임) 구입, Windows SDK 의 `signtool` 준비 (맥에서는 `osslsigncode`).
  2. 프리셋 Windows: `codesign/enable=true`, `codesign/identity_type`·`codesign/identity`(인증서 파일 또는 지문)·`codesign/password`, 타임스탬프 서버 그대로.
     또는 내보낸 뒤 `signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /f cert.pfx "DEADLINE 15.exe"`.
  3. 서명하지 않으면 SmartScreen '알 수 없는 게시자' 경고가 뜸. 스토브 런처로 받으면 덜하지만 서명을 권장.
- 스토브: 빌드 업로드·런처 연동·결제 SDK 는 다음 단계 (스토브 인디 개발자 계정 필요).

### 남은 일 (5단계 뒤)

- 전용 앱 아이콘 (지금은 지휘관 그림을 잘라 키운 것 — 작은 크기(16·32px)에서는 얼굴만 보임).
- Windows 빌드는 이 맥에서 실행해 보지 못함 (wine 없음) — Windows PC 에서 실행·세이브 위치·Alt+Enter·배율 125/150% 확인 필요.
- 전체 화면: play_pc5 가 실제 창에서 확인(pc5_03_fullscreen.png). 단, 시험 창이 앞에 없으면 macOS 가 전체 화면으로 바꾸지 않아 '되돌림' 길로 가고 경고를 남김.
- 서명·공증 (위 절차), 스토브 결제 SDK·광고(모바일), 스팀 프리셋 (사용자가 말할 때).
- 언어별 창 제목·macOS 메뉴 이름 현지화 (지금은 DEADLINE 15 그대로).
