# DEADLINE 15 — Godot 4 판

웹판(HTML/CSS/JS)을 Godot 4.5 로 옮긴 판입니다. 1~4단계(기초 · 전투 규칙 · 전투 화면 · 바깥 화면)와 5단계(PC 출시 준비: 소리 · 화면 모드 · 내보내기 · 플랫폼 구분) · 결제층 A·B · 6a(모바일 화면·터치·내보내기) 완료. 다음은 6b(결제·광고 플러그인).

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
  icon.png             앱 아이콘 1024×1024 — 방패 엠블럼 '15' (2026-10 디렉터 확정, 코드로 그림. docs/store/graphics/make_icon_shield.py → tools/make_mobile_icons.py, 아래 '앱 아이콘')
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
  scripts/core/mobile.gd  (6a) 오토로드 Mobile — 모바일 배율 · 안전 영역 · 뒤로 단추 · 길게 누르기 · 목록 끌기 (아래 '6a')
  assets/app_icon/     (6a) 모바일 아이콘·시작 화면 (tools/make_mobile_icons.py 가 방패 엠블럼 레이어로 만듦 — 아래 '앱 아이콘')
  android/             (6a, git 제외) Gradle 빌드 틀 + 디버그 키스토어 — tools/android_build_template.sh 로 만듦
  tests/check_mobile6a.gd  (6a) 모바일 흉내 시험 (배치 4기기×6언어 · 터치 · 뒤로 · 백그라운드 · 설정 · 프리셋)
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
  assets/image/        그림 원본 (git 에 올림 · *.import 포함). icon/src · character/story/src · character/art_src 는 일러스트 원본(git 제외 · .gdignore 로 Godot 도 안 읽음),
                       icon/item_src · icon/skill_src 는 아이콘 시트를 만드는 256px 개별 그림(git 에 올림 · .gdignore — 내보내기에 안 들어감). 정면·스토리 일러스트는 .webp (아래 '용량 줄이기')
  assets/fonts/        Noto Sans KR·JP·SC·TC **부분 집합**(쓰는 글자만 남김, 가변 굵기, 합계 17.5MB — OFL.txt 하나가 넷 모두의 라이선스). 원본 전체 글꼴(49.7MB)은 fonts/src/(git 제외 · .gdignore — ad48239 의 git 기록에서 복구).
                       project.godot 기본 글꼴은 KR, 실행 중에는 scripts/core/fonts.gd 가 언어별 사슬로 바꿈 (아래 '글꼴')
  tests/check_foundation.gd   머리 없는 시험 (6개 언어: 팩·대본·gd.* 키 맞춤 · 데이터 원본 모양·manifest·기준 잠금, 언어 감지, 글꼴 사슬)
  tests/check_glyphs.gd        6개 언어 데이터의 모든 글자가 글꼴 사슬에 있는지 + 한자·가나가 그 언어 글꼴로 그려지는지 (두부 0)
  tests/check_back_view.gd     뒷모습 삭제 뒤: `_b` 그림 0개 · back 요청 = 앞모습 대신 · UnitView 켜기/끄기 오류 0 (아래 '용량 줄이기 6')
  tests/shots_lang6.gd         ja·zh-CN·zh-TW 전투 HUD·설정·대사 화면 사진 (창 모드 → tests/screens/lang6_godot_*.png)
  tests/golden/        전투 황금 기록 (웹 코드로 만든 고정 기준 — 보관: tools/legacy-web/battle-sim.js, tests/golden/README.md)
  tests/baseline/      기준 데이터 data/ (2026-10-18 옮긴 시점 godot/data 사본 — 기준 시험이 읽음) · LOCK.json (golden·fixtures·baseline sha1 잠금)
  tests/baseline_data.gd  기준 시험이 기준 데이터를 읽게 (-- --live 면 지금 데이터)
  tests/replay_golden.gd   2b 시험: 황금 기록 22개를 GDScript 규칙으로 재생해 사건·난수까지 비교
  tests/check_battle_api.gd  엔진 조회 API 순수성·command 결과 시험,  tests/fixtures/js_numbers.json  JS 실수 표기 정답 (node 로 만든 것)
  tests/check_battle_scene.gd  3a·3b: 전투 장면을 머리 없이 띄워 황금 기록을 화면 입구(UI 수준)로 재생 (HUD·연출·스토리 켬) → 결과가 같은지
  tests/check_battle_ui.gd     3b: UI 연기 시험 (모든 패널·팝업·툴팁·결과·스토리·언어 바꾸기, Godot 오류 0)
  tests/check_battle_ui_adopt.gd  전투 UI 도입 1~4 + 왼쪽 클랜원 패널: 이동 취소(상태 되돌리기) 동일성 · 순서 바↔맵 강조 · 턴 종료 확인 · 접힘 패널 = battle_query · 적 범위 · pixel8 터치 (scripts/battle/README.md '전투 UI 도입')
  tests/shots_adopt.gd         도입 화면 사진 (창 모드, -- --tag after --lang ko --dev pixel8 --phase all --out <폴더>)
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
- 일러스트 원본 `assets/image/icon/src/`(199개 · 약 161MB) · `assets/image/character/story/src/`(23개 · 약 16MB) · `assets/image/character/art_src/`(정면·스토리 무손실 PNG 49개)는 git 에 넣지 않고(.gitignore),
  각 폴더의 `.gdignore` 로 Godot 도 가져오지 않습니다. **디스크에만 있으므로 따로 백업**하세요 (art_src 는 변환 직전 커밋 ad48239 의 git 기록에도 있음).
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
확률형 아이템 표시 시험 (게임산업법 · Google Play · App Store): `... --script res://tests/check_odds_disclosure.gd` — 상점 인라인 확률 = 확률 창 = 데이터(합계 100%) · 구매 카드 근처 '확률 보기' · 골드 안내 · 설정 진입점 · 새 구역(천장·종류별·전설별·강화 옵션·고유 효과·능력치 범위)을 규칙 코드로 뽑은 빈도와 비교 · 6개 언어 키·자리표시자.
화면 사진: `HOME=<임시> Godot --path godot --resolution 1280x720 --script res://tests/shots_odds.gd -- --lang ko [--dev pixel8] --out <폴더>` (창 모드).
확률 문구의 숫자는 번역에 적지 말고 `{p}` 같은 자리표시자로 두고 `scripts/logic/odds_rules.gd` 의 `pct()` 로 채웁니다. 확률표를 바꾸면 `tools/odds_export.gd` 로 `docs/store/probabilities.*.md` 도 다시 만드세요.

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
- 비용 (M3 Max 실측): 파일 4개 **17.5MB**(KR 4.6 · JP 4.5 · SC 4.5 · TC 3.9 — 부분 집합, 원본 49.7MB. 아래 '용량 줄이기 2'). **시작할 때 4개를 모두 읽음**, 약 30ms.
  정적 메모리는 약 **+28MB**(KR 8 · JP 8 · SC 8 · TC 4 — 원래 +80MB).
- 남은 과제(모바일): ko·en·es 데이터 글자는 KR 하나로 다 그려지므로, 모바일에서 메모리가 문제면 현재 언어에 필요 없는 대체 글꼴(JP·SC·TC)을
  필요할 때(예: 그 언어로 바꿀 때·이름 입력 화면) 늦게 읽도록 바꿀 것. 아직 코드에는 없음.

## 용량 줄이기 (2026-10-23) — 규칙·데이터 수치 불변

결과 (Windows pck 기준, `--export-pack` 으로 단계마다 잼, MB = 10^6 바이트): **107.4MB → 43.4MB (-64.0MB)**. 항목별:

| 항목 | pck 전 → 후 | 내용 |
|---|---|---|
| 6 뒷모습 삭제 | -10.5MB | `character/**/*_b*.png` 120개(정지 24 + 동작 시트 96) 삭제 — 아래 '뒷모습' |
| 1 도구용 원본 제외 | -13.6MB | `icon/item` 197+1 · `icon/skill` 51 개별 PNG → `icon/item_src` · `icon/skill_src`(.gdignore). 게임이 쓰는 `chest.png` 는 `map/chest.png` 로 |
| 5 정면·스토리 일러스트 WebP | -16.0MB (26.1 → 10.1) | 정면 26 + 스토리 23 → 손실 WebP q85 (저장소 파일은 PNG 28.2MB → WebP 3.3MB) |
| 2 글꼴 부분 집합 | -23.7MB (35.8 → 12.2) | 글꼴 파일 49.7MB → 17.5MB |
| 3 안드로이드 arm64 만 | AAB 100.2 → 74.6MB (-25.6MB, 위 항목들로 164.0 → 100.2) | 아래 |
| 4 macOS arm64 전용 | zip 106.6 → 73.3MB (-33.3MB, 위 항목들로 170.2 → 106.6) | 아래 |

**1. 도구용 원본 제외.** 아이콘 시트(`item-sprite.webp` · `skill-sprite.png`)만 게임이 읽고, 개별 256px 그림은 시트를 만드는 도구(`tools/build-icon-sheet.py` · `import-icons.py` · `icon-catalog.py`)의 입력.
`.gdignore` 가 있는 폴더는 Godot 이 가져오지도(.import 없음) 내보내지도 않음 — 기존 `icon/src` · `story/src` 와 같은 방식이라 프리셋 exclude 는 따로 안 씀. 폴더 이름만 `item` → `item_src`, `skill` → `skill_src`.
`battle_map.gd` 의 보물상자 그림은 `map/chest.png`(복사본 — 상자 그림을 바꾸면 `item_src/chest.png` 와 둘 다).

**2. 글꼴 부분 집합.** `python3 godot/tools/subset_fonts.py` (`--report` 는 크기만, `--out` 은 다른 폴더). 원본은 `assets/fonts/src/*.ttf`(git 제외 · .gdignore, 같은 OFL — 없으면 `git show ad48239:godot/assets/fonts/<파일>` 로 꺼냄), 결과는 같은 이름으로 `assets/fonts/`.
- 남기는 글자: 언어별 사슬(`fonts.gd CHAINS`)을 따라 — 공통(`data/*.json` · 코드·장면의 문자열 글) ∪ 그 언어 팩·대본 ∪ **이름 입력 허용 범위**(한글 완성형 11,172 · 히라가나·가타카나 · 라틴 악센트 · 전각/반각 · 문장부호·기호 ·
  한자는 일본 JIS 제1수준 2,965 · 간체 GB2312 일급 3,755 · 번체 Big5 상용 5,401 — 파이썬 코덱에서 뽑음, 다운로드 없음) 를 '사슬에서 원본에 그 글자가 있는 첫 글꼴'에 남김 → 원본일 때와 같은 글꼴·글자 모양.
  GSUB/GPOS 기능은 kern·liga·locl·ccmp·mark·vert 등만 남김. 굵기 축(wght)은 그대로.
- **이름 입력 두부 대책**: ① 범위 안(위)은 번들 글꼴이 그림 ② 범위 밖(희귀 한자·키릴·그리스·이모지 등)은 **시스템 대체 글꼴** — 4개 파일 모두 `allow_system_fallback=true`(원래 기본값)라 macOS·Windows·Android·iOS 의 CJK 시스템 글꼴이 그림
  (실제 창에서 `𠮷野家 鑫 龘 Ñandú ¿¡` 확인 — 두부 아님, 글자 모양만 시스템 것). ③ 한국어 한자(KS X 1001)는 남기지 않음(데이터에 한자 없음, +2.4MB) → 한자 이름은 일본·중국 상용 한자 글꼴로 나옴.
  입력 글자 제한은 하지 않음(기존 동작 그대로). 시험: `check_glyphs` — 데이터 글자 · 한글 11,172 · 가나 · 라틴-1 · 섞인 이름 · 한자 이름(直骨李王金) 이 6개 언어 사슬에 모두 있음 + 견본 문장 글리프가 전부 우리 사슬에서 옴.
- **다시 만들기**: 번역·대본·데이터·코드 문구가 바뀌어 새 글자가 생기면(`check_glyphs` 가 두부를 알려 줌) `python3 godot/tools/subset_fonts.py` → `Godot --headless --path godot --editor --quit` → `check_glyphs`. 필요: `fonttools`(`brew install fonttools`, pyftsubset 과 같은 파이썬). OFL: 수정본이며 예약 글꼴 이름('Source')을 쓰지 않음.
- 모바일 메모리: 글꼴 4개 정적 메모리 약 +80MB → 약 +28MB(KR 8 · JP 8 · SC 8 · TC 4, check_glyphs 출력) — '늦게 읽기' 과제는 많이 줄었음.

**3. 안드로이드.** 두 프리셋 모두 `architectures/armeabi-v7a=false` (arm64-v8a 만). x86 · x86_64 는 원래 꺼져 있었고 **켜지 않음**: Play 는 64비트 ARM 이 필수이고, 애플 실리콘 맥의 에뮬레이터(`Pixel_8_API_35` arm64)도 arm64,
x86_64 는 인텔 에뮬레이터·일부 크롬북 전용이라 AAB 에 libgodot 을 하나 더(약 +70MB) 넣을 값어치가 없음 (필요하면 프리셋 한 줄). 참고: Play 는 기기에 맞는 ABI 만 내려 주므로 **arm64 기기의 다운로드 크기는 원래도 AAB 전체가 아니었음** —
armeabi-v7a 제외는 AAB 업로드 크기를 줄이고 **32비트 전용 구형 폰이 설치 불가**가 되는 쪽의 결정 (2026 Play 64비트 필수·minSdk 24 와 맞음). 시험: `check_mobile6a`(두 프리셋 arm64-v8a 만).

**4. macOS arm64 전용.** `binary_format/architecture="arm64"` + 맞춤 템플릿(위 5단계 — `bash godot/tools/macos_arm64_template.sh`). **인텔 맥에서는 실행되지 않음.** 시험: `check_pc5`.

**5. 정면·스토리 WebP.** `character/<직업>_01|02.webp`(26) · `character/story/*.webp`(23): 손실 q85(`-sharp_yuv`, 알파는 무손실 `-alpha_q 100`). 가져오기 설정은 '손실 0.85'(`*.webp.import` — 기본 무손실이면 Godot 이 풀어서 다시 무손실로 넣어 커짐).
화질: 가져온 결과를 원본 PNG 와 비교해 PSNR 33~38dB, 알파가 8 넘게 다른 픽셀 0 (가장자리 깨짐 없음, 비교 그림은 보고서 참고). 참조 갱신: `story_battle.gd` · `sprite_db.gd` · `icons.gd char_tex` · `lobby.gd` · `codex_view.gd` 의 `.png` → `.webp`.
`portrait/`(512px 초상화)와 `anim/` 동작 시트는 그대로 PNG(칸 경계가 있는 시트는 무손실 유지).
- **원본·재생성**: 무손실 PNG 는 `assets/image/character/art_src/{front,story}/`(git 제외 · .gdignore)로 옮겨 두고 변환 직전 커밋 `ad48239` 의 git 기록에도 있음. `python3 godot/tools/webp_art.py`(새 PNG 변환) · `--rebuild`(art_src 로 전부 다시) · `--check`(PSNR 점검).
  새 스토리 그림은 `tools/make-portrait.py` → `webp_art.py`. 필요: `cwebp`(`brew install webp`).
- 도구가 앞모습 PNG 를 읽을 때는 `art_src/front/<키>.png` (gen-props · video-to-sheet 의 기본값 갱신).
- **스토리 새 그림(허리 위 반신) 적용 절차 (2026-10-24 17장, 2026-10-25 나머지 6장 — boss_60 · boss_90 · boss_93 · boss_100 · kasha · commander_f — 적용, 23장 모두 완료):**
  1. 새 그림은 962x1087 RGBA PNG (그림은 위쪽 약 2/3 에 있고 아래 1/3 은 투명 — 허리에서 서서히 사라짐). 작업 폴더(git 밖) 예: `<scratchpad>/portrait/story/final/<키>.png` 와 적용 스크립트 `apply_story.sh`.
  2. `bash apply_story.sh <키> <키> ...` — 기존 `art_src/story/<키>.png` 를 `backup_old/` 로 보관, 새 PNG 를 `art_src/story/<키>.png` 로 복사(무손실 원본, git 제외),
     `cwebp -q 85 -m 6 -sharp_yuv -alpha_q 100` 으로 `assets/image/character/story/<키>.webp` 생성 — 옵션은 `tools/webp_art.py` 와 같음. `.webp.import` 는 이미 있으므로 그대로 둠(없으면 `webp_art.IMPORT_TEMPLATE` 로 만듦).
     (apply_story.sh 없이 하려면: 새 PNG 를 `assets/image/character/story/<키>.png` 에 놓고 `python3 godot/tools/webp_art.py` — PNG 는 art_src 로 옮겨 가고 .webp 가 생김)
  3. 다시 가져오기: `HOME=<임시> Godot --headless --path godot --editor --quit` (한 번이면 됨, `.godot/imported` 캐시만 바뀌고 `.import` 옆파일은 그대로). 임시 HOME 이 없으면 그냥 `Godot --headless --path godot --editor --quit`.
  3-1. 생성 그림의 후처리(스티커 흰 테두리 · 크로마키 초록 찌꺼기 · 상단 여백)는 PNG 단계에서(PIL/numpy) 한 뒤 2번을 다시 실행. 원본 PNG 는 작업 폴더 `backup_clean/`. `apply_story.sh` 는 `set -e` 라 이미 보관본이 있으면 `cp -n` 이 실패해 조용히 멈추므로 `|| true` 가 필요함(고쳐 둠).
  4. 확인: `git status` 가 `story/*.webp` (+ 코드 수정이 있었다면 그것) 만 보이고, `python3 godot/tools/webp_art.py --check` 로 PSNR, 도감 '스토리' 탭(`guide` 화면, 인물·보스 카드) · 스토리 대사창 · 전투 중 보스 등장을 1280x720·pixel8 으로 눈으로 확인.
  - 반신 그림의 배치: 대사창(`story_view.gd`)은 위쪽만 보이는 틀(그림 칸 210x230 · 전투 중 150x160 + 아래쪽 흐림 마스크)이라 그대로 맞음(얼굴·어깨가 대사 상자 위로 솟음). 도감 인물 카드(64x72)는 투명 여백이 커서 `codex_view.gd _story_thumb()` 가 그림이 있는 부분(`Image.get_used_rect`)만 잘라 128x144 안에 통째로 들어가게 Lanczos 로 줄인 `ImageTexture` 로 보여 줌(가운데 정렬, 계단 없음) — 전신·반신 모두 자동.
  - 크기(17장 적용 전 → 후): Windows pck 43,349,204 → 42,992,468 B (-0.36MB) · macOS zip 73.31 → 72.94MB · AAB 74.57 → 74.20MB · 디버그 APK 130.71 → 130.34MB. 나머지 6장: story webp 6개 합계 448K → 212K.

**6. 뒷모습.** `_b` 그림 120개 삭제 (3D 로 교체할 예정, 사용자 지시 2026-10-23 — git 기록에서 복구: `git checkout ad48239 -- godot/assets/image/character` 처럼 필요한 것만). 웹판도 꺼 두었던(`Rig.BACK_VIEW=false`) 그림이라 화면에는 원래 안 쓰임.
**뒷모습을 읽는 자리** (3D 로 다시 연결할 때 여기만):
- `scripts/battle/sprite_db.gd` — `sheet(cls, gender, kind, back)` · `still(cls, gender, back)`: back=true 면 `data/sprites.json SPRITE_SHEETS["<키>_b"]` 시트 / `character/<키>_b.webp` 를 찾고, **데이터에 없거나 파일이 없으면 앞모습으로 대신**.
- `scripts/battle/unit_view.gd` — `facing_back` · `set_facing_back(on)`: 유닛 하나를 뒷모습으로 (지금은 아무도 안 부름, 기본 false). 카메라 방향(`iso.cam_dir`)에 따라 켜는 코드는 아직 없음 — 3D 전환 때 이 한 줄.
- `data/sprites.json` 의 `*_b` 시트 24개 항목은 **그대로 남김**(기준 잠금·수치 불변 — 가리키는 파일이 없으면 위 대체 규칙으로 무시됨). 3D 로 바꿀 때 데이터 정리 때 지움.
- 시험: `tests/check_back_view.gd` — `_b` 파일 0개 · 13직업×남녀×4동작 back 요청 = 앞모습 · UnitView 켜기/끄기 · 소환수 포함 오류 0.

## 죽은 코드 정리 (2026-10-24) — 규칙·수치 불변 (replay_golden 22/22)

참조를 전수 검색(코드·tscn·json·tools·tests·"문자열" 조립 조각)해 어디서도 안 쓰임을 확인한 것만 지움. 목록·근거: 작업 폴더의 `deadcode/CANDIDATES.md`.
- **지휘관 전투 코드**: 패배 판정(`chk_end` · `_commanderFallen`) · 일반 공격 1% ×10 · 상자 소울 조각의 지휘관 예외 · `commander_msg.fallen` · 음표 투사체/임팩트(`pixel_fx.gd` 의 commander·note). 지휘관은 파티 배치(`battle_engine` 의 `COMMANDER_CLS` 건너뜀)와 `party_rules` 로 전투에 못 나감. 지휘관 `JAB`·그림·스토리는 그대로.
- **데이터**: `stages.json` 상수 6개(`ENEMY_HP_EXP`·`ENEMY_ATK_EXP`·`STAGE_TOT_CAP_BASE`·`STAGE_TOT_CAP_PER`·`STAGE_COMP_HP`·`STAGE_COMP_ATK` — 웹 시절 생성식 상수, 결과는 `sm`·`tot` 에 구워짐). 기준 사본 `tests/baseline/data` 는 고치지 않음(LOCK 그대로, 'last 대사' 때와 같은 방식) → `data_tool --write` 로 manifest 갱신.
- **번역 키**: 6개 언어 동일하게 약 118개(웹 시절 인벤토리·강화·전직 창·상점 광고·`stage.*` 등 참조 0).
- **상점 광고 대체 카드**(Ads 오토로드가 없을 때만 나오던 꺼진 '추후 개발' 단추) · 안 쓰는 함수·상수·신호(`input_ready`·`battle_over`·`line_shown`·`back_pressed`).
- **남긴 것(코드에만 남은 것)**: `jab.json` 의 `summon_spirit`·`summon_golem`(세이브 점검이 `JAB.has(직업)` 로 읽음 — 지우면 변조 세이브 결과가 달라짐), `STAGE_MAX_WAVES`(시험이 읽음), 동적 접두어로 조립되는 번역 그룹(codex·stages·skills·messages 등 — 키별 증명 불가), 미사용 이미지 `assets/image/character/commander_02.prev.png`·`assets/image/icon/src/jab_commander.jpg`(이미지는 건드리지 않음).

## 앱 아이콘 (방패 엠블럼 '15')

디렉터 확정 시안 `docs/store/graphics/icon_shield_1024.png` 를 **코드로만** 그린 것(AI 이미지 생성·외부 서비스 없음) — 원본 스크립트 `docs/store/graphics/make_icon_shield.py`(`render_layers()`)가 레이어를 만들고,
`godot/tools/make_mobile_icons.py` 가 그 레이어를 아래 파일에 저장합니다. 같은 이름·크기·형식이라 `export_presets.cfg`·`project.godot` 은 그대로입니다.

```bash
python3 docs/store/graphics/make_icon_shield.py      # 확정 시안 icon_shield_1024.png / _512.png 만 (같은 그림, 픽셀 동일)
python3 godot/tools/make_mobile_icons.py             # godot/icon.png + godot/assets/app_icon/*.png 전부
HOME=<임시 HOME> Godot --headless --path godot --editor --quit    # 바뀐 그림 다시 가져오기 (.import 는 그대로, .godot 캐시만)
```

| 파일 | 크기·형식 | 내용 |
|---|---|---|
| `icon.png` | 1024 RGBA(전부 불투명) | 전체 합성 — Windows(.exe) · macOS(.icns) · 프로젝트 아이콘 |
| `assets/app_icon/ios_1024.png` | 1024 RGB(알파 없음) | 전체 합성, 모서리 직각 (iOS 가 둥글게 자름) |
| `android_192.png` | 192 RGB | 전체 합성을 줄인 기본(레거시) 아이콘 |
| `android_bg_432.png` | 432 RGB | 적응형 배경 — 남색 바탕 + 후광 + 광선 + 불씨 (방패·숫자 없음) |
| `android_fg_432.png` | 432 RGBA | 적응형 전경 — 방패 + 숫자 + 작은 그림자만. 방패(그림자 포함)가 가운데 지름 280px 원 안(안전 영역 66% = 285px 안) |
| `android_mono_432.png` | 432 RGBA | 테마 아이콘 — 방패 테두리 띠 + 방패 면 흰색 단색, 숫자는 뚫음. 전경과 같은 크기·자리 |
| `launch_400.png` · `launch_600.png` | 400·600 RGBA | iOS 시작 화면 그림 — 투명 바탕에 방패(+그림자), 바탕색은 프리셋의 #0a0e1a |

- 적응형 전경에는 방패 바깥 금빛 번짐을 넣지 않음(번짐이 안전 영역을 넘고, `check_mobile6a` 의 '테마 아이콘 윤곽 = 전경 윤곽' 조건도 지킴). 번짐은 전체 합성(icon.png·iOS·192)에만 있음.
- 시안을 고치려면 `make_icon_shield.py` 만 고치고 위 명령 두 줄을 다시 돌리면 모든 아이콘이 같이 바뀜.

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
- 좁은 창(480×900 등 휴대폰 폭) 모바일 배치 → 6a (아래 '6a' — 가로 고정, 배율·안전 영역).

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
  - (삭제됨 2026-10-24) 상점 광고 카드의 꺼진 '추후 개발' 단추(`common.coming_soon`) — Ads 오토로드가 항상 있어 나올 수 없는 경로라 지움
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
- `is_pc()`(기능 태그 pc) · `is_mobile()` · `has_ads()` · `has_iap()`.
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
| macOS (STOVE) | `build/macos/DEADLINE 15.zip` (안에 `DEADLINE 15.app`) | **arm64(애플 실리콘) 전용**(2026-10-23, 인텔 맥은 못 돌림 — 맞춤 템플릿 `build/templates/macos_arm64.zip`, `tools/macos_arm64_template.sh`), 번들 ID `xyz.show4you.deadline15`, 버전 빈칸 = `config/version`, 분류 Games, 서명 = 내장 ad-hoc(로컬 실행만), 공증 안 함 |

```bash
HOME=<임시 HOME — export_templates 를 그 안에 연결> /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --export-release "macOS (STOVE)" "build/macos/DEADLINE 15.zip"
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --export-release "Windows (STOVE)" "build/windows/DEADLINE 15.exe"
```

- 거르기: 넣기 `data/*, data/lang/*, data/story/*, assets/fonts/*.txt`(OFL), 빼기 `tests/*, tools/*, build/*, *.md, *.prev.png`(작업 중 미리보기). 그림 원본 src 는 `.gdignore` 라 Godot 이 모름.
  check_pc5 는 build/ 의 pck(맥은 zip 안)가 **소스보다 오래되었으면 실패** (scripts·scenes·data·assets·project.godot·export_presets.cfg 의 수정 시각 비교 — build/ 가 없으면 건너뜀).
  확인(2026-10-18, 검수 뒤 마지막 내보내기): 두 pck 모두 파일 5,877개, `tests/`·`tools/`·`tests/baseline`·src·`*.prev.png` 없음, `data/*`·`OFL.txt`·소리 있음 (check_pc5 '9) export' 가 build/ 의 pck 를 직접 읽어 확인).
  (pck 안에 `res://tests/...` 글자가 보이는 것은 uid 캐시의 경로 문자열일 뿐 파일은 없음)
- 크기(2026-10-23, 용량 줄이기 뒤): pck 43.4MB (글꼴 12.2MB · 그림 · 소리 2.7MB), Windows exe 97MB, macOS zip 73MB (이전 pck 107MB · macOS 170MB — 아래 '용량 줄이기').
- macOS arm64 전용은 공식 템플릿(universal 실행 파일 하나뿐)으로는 '`godot_macos_release.arm64` 를 찾을 수 없음' 으로 실패하므로, 처음 한 번(Godot 버전을 올릴 때도) `bash godot/tools/macos_arm64_template.sh` 로 lipo 로 얇게 만든 템플릿을 `build/templates/` 에 만들어 둠 (프리셋 `custom_template/*` 가 가리킴).
- `rendering/textures/vram_compression/import_etc2_astc=true` — macOS universal·arm64 내보내기의 필수 조건 (정면·스토리 일러스트 49장은 손실 WebP q85, 나머지 그림은 무손실).
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

- Windows 빌드는 이 맥에서 실행해 보지 못함 (wine 없음) — Windows PC 에서 실행·세이브 위치·Alt+Enter·배율 125/150% 확인 필요.
- 전체 화면: play_pc5 가 실제 창에서 확인(pc5_03_fullscreen.png). 단, 시험 창이 앞에 없으면 macOS 가 전체 화면으로 바꾸지 않아 '되돌림' 길로 가고 경고를 남김.
- 서명·공증 (위 절차), 스토브 결제 SDK·광고(모바일), 스팀 프리셋 (사용자가 말할 때).
- 언어별 창 제목·macOS 메뉴 이름 현지화 (지금은 DEADLINE 15 그대로).

## 결제층 A — 게임 쪽 공통 결제·광고 층 (2026-10-18, 가짜 가게·가짜 서버)

실제 스토어 SDK(STOVE·Google·Apple)와 서버(Cloudflare Workers + D1)는 다음 작업. 이번에는 같은 약속을 따르는 가짜로 끝까지 동작·시험.

| 파일 | 하는 일 |
|---|---|
| `data/iap.json` | `IAP_PRODUCTS` (gold_500/1200/3000/6500 · 원화 1,200/2,500/6,500/12,000 · Google = STOVE = 게임 id · Apple `xyz.show4you.deadline15.gold_<양>`) · `AD_REWARD {gold:100, daily:3}` · `IAP_SERVER {dev, stage, prod}` |
| `scripts/logic/iap_rules.gd` | 지급 기록 `game_iap = {v, iid(설치 식별자), orders{"<store>:<order>": {pid, gold, at, st}}, rf(환불 커서)}` · `grant`(중복 {dup}) · `revoke`(0 바닥) · sanitize |
| `scripts/logic/ad_rules.gd` | 광고 하루 횟수 `game_ads = {v, day, n}` — 기기 로컬 날짜, 날짜는 앞으로만 (시계 되돌림은 새 날로 보지 않음) |
| `scripts/logic/odds_rules.gd` | 확률표 (장비 뽑기 · 룬 뽑기 · 강화) — 데이터에서 계산 |
| `scripts/core/billing.gd` (오토로드 `Billing`) | `products()` · `buy(id)` · `restore()` · `busy()` · `is_supported()` · `is_available()` · 신호 `purchase_finished` · `granted` · `revoked` · `products_updated` — **지급 순서는 파일 머리말** |
| `scripts/core/billing/` | `backend_base` · `backend_none`(steam) · `backend_fake`(dev 디버그) · `backend_stove/google/apple`(빈 틀) · `verifier.gd`(서버 클라이언트) · `fake_server.gd`(같은 약속의 가짜 서버) · `fake_files.gd` |
| `scripts/core/ads.gd` (오토로드 `Ads`) | `show_rewarded(placement)` · 신호 `rewarded` · `closed` · `failed` · 가짜 광고 화면 (dev 디버그) |
| `scripts/ui/odds_view.gd` | '확률 정보' 창 (상점 장비·소모품 탭, 편성 강화 탭) |
| `tools/odds_export.gd` | 같은 표를 `docs/store/probabilities.{ko,en,ja,zh-CN,zh-TW,es}.md` 로 (`-- --check` 는 낡았는지만) |
| `docs/server/api.md` | 게임 ↔ 서버 API 약속 (엔드포인트 · JSON · 오류 코드 · 인증 · 가게별 영수증 · D1 표) |

- 가짜 시나리오 (디버그 빌드만, 출시 빌드는 무시): `-- --iap success|cancel|pending|fail|net_fail|crash_before_grant|crash_after_grant|refund`, 서버 환경 `-- --iap-env dev|stage|prod`.
- 기준 데이터 시험: `iap` 모듈은 기준 뒤에 생겨 `DataDB.use_dir(기준, overlay)` 가 지금 데이터에서 덧붙임 (`_overlay_new_modules` — 번역 덧붙임과 같은 원칙). 기준 사본·잠금은 그대로.
- 전투 중 지급·회수는 미룸: `battle_scene._write_back` 이 전투가 끝날 때 `game_save` 를 덮어써 전투 중에 더한 골드가 사라지는 것을 `check_iap '6) battle'` 이 재현·확인. 전투 장면은 `battle_scene` 무리에 들어감.
- 시험: `tests/check_iap.gd` (머리 없는) · `tests/play_iap.gd` (실제 창, `caffeinate -d Godot --path godot --resolution 1280x720 --script res://tests/play_iap.gd` → `tests/screens/iapA_*.png`) · 보조 `tests/aux_iap_crash.gd`.

### 결제층 A 검수 반영 (2026-10-18)

- **저장 확인**: `Store.flush()` 는 쓰기에 실패하면 다시 '쓸 것 있음'으로 둠 (다음 flush 의 거짓 성공 없음). Billing 은 서버 consume·가게 finish 전에 **저장 파일을 다시 읽어**
  주문 기록이 디스크에 있는지 확인 (`Store.disk_get_json`). 메모리에만 있는 지급은 '이미 받은 주문'으로 치지 않음 — `check_iap '5b) durable'`(저장 폴더 chmod 555).
- **전투 판정** `Billing.in_battle()`: battle_scene 무리 · `BattleScene.pending` 이 비어 있지 않음(출격·이어하기·다시 하기/다음 스테이지·개발 실행기가 store_save 사본을 만든 직후) ·
  `Router.current == "battle"` 중 하나. 지급과 환불 회수 둘 다 — `check_iap '6b) sortie'` (서버 응답 프레임에 출격).
- **재설치 복구**: 서버의 재claim 규칙 (재검수 뒤 24시간·1번) (api.md 3.2 판단 순서 consumed > refunded > claim > valid). 주인을 잃은 설치는 consume 이 `order_claimed` → 자기 지급 회수.
  '모든 데이터 초기화'는 `game_iap`·`game_iap_bak` 을 지우지 않음. sanitize 는 깨진 기록에서 iid·주문을 건지고, 뺀 원본은 `game_iap_bak`(최근 20개)에 쌓음.
- **계정 값**: 서버는 클라이언트 account_id 를 믿지 않음 (가게 확인 결과만, 권한은 iid↔주문 연결로만). Google·Apple 구매 토큰 = SHA-256(iid) 앞 32자.
- **STOVE 맥 판**은 결제 길이 없어 카드를 숨김 (SDK 가 Windows DLL). 시험은 `Platform.override_os("Windows")` · 명령줄 `-- --os Windows` (디버그만).
- 이어하기 데이터 해시는 `iap` 모듈을 뺌 (`ResumeRules.HASH_EXCLUDE`). 기준 덧붙이기는 허용 목록 `DataDB.OVERLAY_MODULES = ["iap"]`.
- 광고 시계: 저장된 날이 기기 날짜보다 2일 넘게 앞서면 기기 날짜로 다시 맞춤.
- **법무 확인 대상**: 구매 확인 창의 법정 안내 — 재검수 뒤 게임 언어별로 나눔 (아래 '재검수 반영').

### 결제층 A 재검수 반영 (2026-10-18)

- 재claim: **24시간 · 주문당 1번 · 가게에서 이미 소모(Google consumptionState/acknowledgementState=1)면 거절**, 재claim 은 서버 기록(`reclaimed_from`·`reclaimed_at`·`reclaims`)에 남김 (api.md 3.2).
  주인을 잃었을 때의 회수(`_lost_claim`)도 전투 중이면 미룸.
- 광고 시계: 시계를 고친 것으로 보고 날짜를 다시 맞출 때 그날은 **다 쓴 것(3회)**. 다녀간 날의 횟수는 `game_ads.seen`(최근 14일)에 남겨, 시계를 앞뒤로 오가도 같은 날을 두 번 새로 받지 못함.
- 진행 중 창 '닫기' → `Billing.release_busy()` (다른 상품은 살 수 있음), 그 상품 카드는 '처리 중'으로 막힘 (`Billing.purchase_pending`).
- 디스크 재확인: flush 는 성공인데 디스크에 기록이 없으면 메모리를 한 번 더 씀(`Store.touch`). 시험 훅 `Store.debug_fake_write_ok` (디버그만).
- 잘린 `game_iap`: 번호만 남은 주문은 `{st:"done", lost:true}` 로 남겨 다시 지급하지 않음 (api.md 3.6).
- **법정 문구는 게임 언어로 나눔** (`shop.gd notice_keys`) — 법무 확인 대상:
  - ko: 7일 이내 청약철회(사용한 재화 등 제한) · 청약철회·환불은 구매한 스토어 고객센터 · 부가세 포함 · 미성년자 법정대리인
  - 그 밖(en·es·ja·zh-CN·zh-TW): 환불은 구매한 스토어의 환불 정책 · 가격·세금은 스토어 표시 기준 · 미성년자 법정대리인
  - 언어 ≠ 거주 국가 (한국 사용자가 영어로 두면 7일 문구가 안 보임) — 스토어 지역으로 나눌지 법무 확인.

## 결제층 B — 결제 확인 서버 (Cloudflare Workers + D1, 2026-10-18 — 배포 전)

서버는 저장소의 `server/` (설명 · 배포 절차 · 비용 · 운영 점검은 `server/README.md`). 게임 쪽은 약속(`docs/server/api.md`)을 바꾸지 않고 연결만 더함.

| 파일 | 바뀐 것 |
|---|---|
| `data/iap.json` | `IAP_SERVER.local = {url: "http://127.0.0.1:8951", timeout: 10, env: "dev"}` — 로컬 `wrangler dev` (서버 env 가 dev 라 요청의 env 도 dev) |
| `scripts/core/billing.gd` | 디버그 빌드 `-- --iap-env local` · `-- --iap-server <주소>`(`server_override`). 가짜 가게 + http 주소면 `fake_files.remote` 를 켬 |
| `scripts/core/billing/verifier.gd` | `IAP_SERVER[env].env` 가 있으면 그 이름을 보냄 · 출시 빌드는 `http://` 를 쓰지 않음(https 만) · 디버그의 네트워크 실패 흉내(`net_down`·`net_fail_left`)와 `debug_hook` 이 진짜 HTTP 길에서도 같게 |
| `scripts/core/billing/fake_files.gd` | `remote` 가 있으면 가게 장부를 서버 `/v1/dev/ledger` 에도 비추고, 서버 상태는 파일 대신 `/v1/dev/state` · 초기화는 `/v1/dev/reset` |
| `scripts/core/billing/dev_remote.gd` | (새 파일) 그 일을 하는 작은 동기 HTTP (디버그 · dev 가게 전용) |
| `scripts/core/billing/fake_server.gd` | 진짜 서버와 같게: consume 은 가게 장부가 환불이면 `409 refunded` · 길이 상한(400 `… too long`) · 같은 주문을 다른 상품으로 다시 보내면 `422 product_mismatch` · 영수증 필드는 글만(acct 는 없으면 "") · 장부 상품 ≠ 영수증 상품 422 · 5년보다 오래된 구매 422 · 커서·limit 은 15자리까지 · dev 서버가 받는 가게 dev·stove(STOVE 501) · 시험 훅 `force_429` |
| `tests/check_iap.gd` | `-- --server http://127.0.0.1:8951` 이면 모든 시나리오를 진짜 로컬 Worker 로 (재claim 시계는 `/v1/dev/clock`, 앱 죽음 보조 프로세스에도 같은 서버). `6e) errors`: 429(verify · consume) · 501(STOVE) → 지급 없이 다시 시도 |
| `tests/iap_remote.gd` · `tests/check_iap_parity.gd` | (새 파일) 가짜 서버와 같은 모양으로 Worker 를 부르는 보조 · 가짜 ↔ 진짜 응답 비교 (요청 59개 — 429 · 501 · 길이 상한 · 상품 대조 포함) |

```bash
cd server && npm ci && npm run migrate:local && npm run dev     # 127.0.0.1:8951 (계정 필요 없음)
HOME=<임시> Godot --headless --path godot --script res://tests/check_iap.gd -- --server http://127.0.0.1:8951
HOME=<임시> Godot --headless --path godot --script res://tests/check_iap_parity.gd -- --server http://127.0.0.1:8951
Godot --path godot -- --iap-env local                                                   # 디버그 빌드 게임을 로컬 서버로
```

- 배포하면 `IAP_SERVER.stage/prod.url` 에 `https://…` 를 넣고 `data_tool --write` → 시험 → 다시 내보내기.
- STOVE 확인은 서버가 아직 `501 not_implemented` (게임은 5xx → 지급 없이 미처리로 남김).

### 모바일·STOVE 작업에서 할 일 (결제층 A 에서 넘김)

- **iid 를 앱 밖에 보존**: Android Block Store · iOS Keychain · STOVE 클라우드 세이브 → `Billing.set_iid_store(load_fn, save_fn)` 에 연결.
- STOVE 요청자 확인(로그인 토큰으로 '요청자 = 구매자' 증명) — **확인 필요**.
- 백엔드 채우기(backend_stove/google/apple), 서버 재시도 지수 백오프, AdMob 서버 측 보상 확인.

## 6a — 모바일(안드로이드·iOS) 화면·터치·내보내기 (2026-10-18)

가로 고정(양쪽 가로 = `sensor_landscape`, 안드로이드 `userLandscape`), PC 배치를 그대로 쓰고 휴대폰에서만 크게. 결제·광고 플러그인은 6b.

### 판정 (`Platform`)

- `is_mobile()` = 기능 태그 `mobile` · `google` · `apple` 또는 OS 이름 `Android`·`iOS` 중 하나 (+ 흉내). 가게를 `-- --store dev` 로 바꿔도 실제 휴대폰이면 모바일.
  `is_pc()` 는 흉내 중 거짓 (설정 화면의 PC 항목이 숨음). `is_touch()` = 모바일 또는 터치 화면.
- **개발용 흉내** (디버그 빌드만): `Godot --path godot -- --mobile [pixel8|iphone|ipad|low]` — 창을 그 기기 비율로 열고(모니터의 85% 안),
  그 기기의 dpi·노치 여백으로 배율·안전 영역을 계산. PC 창 저장값(`gd_display`)은 읽지도 쓰지도 않음. 시험은 `Platform.emulate_mobile(true, 기기)`.
  기기 표: `Mobile.DEVICES` (2400×1080 420dpi 왼쪽 여백 136px · 2778×1284 458dpi 좌우 141px + 아래 63px · 2732×2048 264dpi 아래 40px · 1600×720 270dpi 왼쪽 80px).

### 배율 (`scripts/core/mobile.gd`, 오토로드 `Mobile`)

- 늘이기는 PC 와 같은 `canvas_items` + `expand`. 모바일에서만 `root.content_scale_factor` 를 키워 **논리 1단위 = 실제 0.136mm** 가 되게:
  `f = clamp(0.136mm ÷ (25.4/dpi × min(가로/1280, 세로/720)), 1, min(1.6, 논리 화면이 1024×480 아래로 안 가는 값))`.
  → 글자 14 ≈ 1.9mm(12pt), 단추 51 ≈ 6.9mm(44pt). 결과: 2400×1080 → 1.50(논리 1067×480) · 2778×1284 → 1.375(1133×524) · 1600×720 → 1.45(1106×498) · 2732×2048 태블릿 → 1.0(1280×960).
  dpi 를 모르면 400 으로 봄. 작은 16:9 폰(1334×750)은 논리 폭 1024 를 지키려고 1.25 에서 멈춤 (조금 작게).
- **글자·단추 최소 크기** (모바일만, 화면 부품 — 맵 Node2D 아래 글자는 빼고): 트리에 들어올 때와 크기가 바뀔 때 글자(Label·Button·LineEdit·RichText) < 12pt 면 키우고,
  누르는 것(BaseButton·LineEdit·Slider)의 최소 크기를 44pt 로 (`Mobile.min_font()` · `min_target()`). `OKit.set_content` 단추도 이 바닥을 지킴. PC 는 손대지 않음.
- 그 때문에 좁아진 화면은 크기·간격만 맞춤 (모바일에서만): 로비(아지트를 본문 높이에 맞추고 도감·출격·가이드를 오른쪽에 세로로), 편성(본문 전체 스크롤),
  장비 창(왼쪽 칸 300·인벤토리 한 줄), 도감 칸 열 수(칸 최소 폭 ×1.6), 전투 윗줄(양쪽 최소 폭 해제·칩 줄 가로 스크롤), 전투 설정 창(내용 스크롤),
  창 폭은 안전 영역 − 16 까지, 장비 거르기 단추 말줄임, 이름 입력 칸은 창이 열려도 키보드를 바로 띄우지 않음.
- PC 와 같은 동작인데 고친 것 (모바일과 상관없이 PC 에도 적용 — 화면은 같음): 전투 대사 상자는 최소 크기를 먼저 정함(앞 장면의 큰 최소 크기에 막히던 것) · 대사가 길면 위로 자람 ·
  속도 단추 글자·클랜원 카드는 내용이 커지면 위로 자람 (PC 크기에서는 변화 없음).

### 안전 영역 (노치·홈 바)

- `DisplayServer.get_display_safe_area()` → 논리 여백 `Mobile.safe_margins()`. 바깥 화면은 윗줄·본문·아래 탭(`Frame`)과 창 가운데 상자를, 전투는 HUD 층(`ui.root`)을,
  스토리 창은 제목·건너뛰기·대사 상자를 그 안에. 바탕·맵은 화면 끝까지. 툴팁·적 정보·결과 창·설정 창도 안전 영역 좌표로 자리 잡음.
- 안드로이드(에뮬레이터 Pixel 8 API 35)는 Godot 창이 펀치홀 쪽까지 그려지고 안전 영역이 왼쪽 132px 로 옴 — 확인함.

### 터치

| 조작 | 동작 |
|---|---|
| 전투 맵 한 손가락 끌기 | 카메라 이동 (PC 마우스 끌기와 같음). 문턱: **실제 2mm** (`Mobile.TOUCH_SLOP_MM` — Pixel 기준 논리 14.7), PC 마우스는 그대로 6 |
| 전투 맵 탭 | 칸·유닛 고르기 (문턱 아래 흔들림은 탭) |
| 두 손가락 벌리기·오므리기 | 확대·축소 (휠과 같은 0.6~3.0), 두 손가락 가운데를 옮기면 화면 이동. 손을 다 뗄 때까지 탭으로 치지 않음 |
| 전투 맵 길게 누르기 (0.5초) | 그 유닛·칸 정보 툴팁 (PC 마우스 올려 두기와 같은 내용). 떼어도 탭이 아님, 다음 누르기에 지움 |
| 단추 길게 누르기 | 그 단추의 툴팁(`tooltip_text`)을 손가락 위에 3초 — 떼어도 단추는 안 눌림 (PC 호버 툴팁 대신) |
| 목록 위 끌기 | ScrollContainer 안 단추·글 칸 위에서 시작해도 목록이 밀림 (Godot 기본은 단추가 누르기를 가져가 안 밀림). 끌면 누르던 단추는 안 눌림 |
| 마우스 오른쪽(취소) | 행동 메뉴의 '이동 되돌리기'·'취소' 줄, 대상 밖 탭(PC 와 같음), 안드로이드 뒤로 단추 |

- `input_devices/pointing/emulate_mouse_from_touch` = 기본 켬(터치가 마우스로도 옴), `emulate_touch_from_mouse` = 기본 끔 — **PC 마우스 동작은 그대로**.
  손가락에서 온 마우스 사건은 `device == DEVICE_ID_EMULATION` 으로 가림.

### 뒤로 가기 (안드로이드)

- `application/config/quit_on_go_back=false` → `NOTIFICATION_WM_GO_BACK_REQUEST` → `Mobile.system_back()` → `Router.request_back(true)`.
- 바깥 화면: Esc 와 같음(창 먼저 닫고 → 이전 화면), 스토리 재생 중이면 넘기기. **로비**(돌아갈 곳 없음): '게임을 종료할까요?' 확인(`gd.mobile.quit_confirm`) → 확인이면 저장 후 종료.
  PC 의 Esc 는 로비에서 그대로 아무것도 안 함.
- 전투(`battle_scene.on_system_back`): 스토리 넘기기 → 설정 창 닫기 → 적 정보 닫기 → 고르던 것 취소/이동 되돌리기(Esc 와 같음) → 취소할 것이 없으면 전투 설정 창(나가기·항복). 결과·로딩 중엔 무시.

### 앱 생명주기

- 백그라운드(`NOTIFICATION_APPLICATION_PAUSED`): Store 디스크에 씀(원래 있던 것) · 실제 세이브 전투면 이어하기 저장 + 디스크(`battle_scene.save_on_close` — PC 창 닫기와 같은 길) ·
  소리 바로 끔. 모바일은 초점을 잃어도(알림창 등) 끔 — 설정 '창이 뒤에 있을 때 소리'는 PC 만.
- 돌아옴(`RESUMED`·`FOCUS_IN`): 소리 원래대로, Billing 의 미처리 확인(`restore`, 원래 있던 것).
- 에뮬레이터 확인: 전투 중 홈 → 프로세스 죽임(`am kill`) → 다시 켜면 로비 '전투 재개' → 같은 자리(이동한 클랜원)에서 이어짐.

### 설정 화면

모바일(흉내 포함)에서는 화면 모드·창 크기·'창이 뒤에 있을 때 소리'가 없음 (바깥 설정·전투 설정 창 모두 — 원래 `is_pc()` 조건, 흉내도 is_pc 거짓).

### 내보내기 (`export_presets.cfg`)

| 프리셋 | 결과물 | 내용 |
|---|---|---|
| Android (Google Play) | `build/android/DEADLINE15.aab` | **Gradle 빌드**, 형식 AAB, 기능 태그 `google`, 패키지 `xyz.show4you.deadline15`, minSdk 24 · **targetSdk 36**(2026 Play 요구), arm64-v8a + armeabi-v7a, 프리셋 권한은 인터넷만 (6b 이후 병합 매니페스트에는 결제·광고 SDK 권한이 더해짐 — 아래 6b), 적응형 아이콘, 몰입 모드, 백업 끔 |
| Android (Google Play) APK | `build/android/DEADLINE15.apk` | 위와 같고 형식만 APK (Godot 은 한 프리셋에 형식 하나 — 시험이 두 프리셋이 같은지 확인) |
| iOS (App Store) | `build/ios/` Xcode 프로젝트 (`export_project_only`) | 번들 ID 같음, 기능 태그 `apple`, iOS 15.0+, iPhone·iPad, 버전 빈칸 = config/version, **팀 ID 비움**, 아이콘 1024 · 시작 화면 그림 |

- 거르기는 PC 와 같음 (+ `android/*`). 버전: versionName 빈칸 = `config/version`, **versionCode = 주×10000 + 부×100 + 수** (0.4.2 → 402) — 버전을 올리면 프리셋 두 개의 `version/code` 도 올릴 것 (check_mobile6a 가 확인).
- **Gradle 빌드를 쓰는 이유**: AAB 는 Gradle 빌드에서만 나오고, targetSdk 36 과 6b 의 결제·광고 플러그인(aar)도 Gradle 빌드가 필요.
  Godot 4.5.1 원본 틀(Gradle 8.11.1 · AGP 8.6.1 · NDK 28.1 …)은 이 맥에 없어 다운로드가 필요하므로, **`tools/android_build_template.sh` 가 이 맥의 `~/.gradle` 캐시에 있는 판으로 고쳐 설치**
  (Gradle 8.14.3 · AGP 8.11.0 · compile/target 36 · build-tools 36 · NDK 27.1 · fragment 1.8.9 · splashscreen 1.2.0 · core-ktx 1.16.0, 다운로드 0).
  다운로드가 허용되면 `PATCH=0 bash godot/tools/android_build_template.sh` 로 원본 틀을 써도 됨. `godot/android/` 는 git 제외 (aar 200MB).
- 내보내기 명령 (임시 HOME 이면 `GRADLE_USER_HOME=~/.gradle` 와 `ANDROID_HOME`·`JAVA_HOME`(JDK 17) 을 넘길 것):
  ```bash
  bash godot/tools/android_build_template.sh          # 처음 한 번 (godot/android/ 만듦 + 디버그 키스토어)
  python3 godot/tools/make_mobile_icons.py            # 아이콘을 다시 만들 때만 (방패 엠블럼 — 아래 '앱 아이콘')
  Godot --headless --path godot --export-debug   "Android (Google Play) APK" build/android/DEADLINE15-debug.apk
  Godot --headless --path godot --export-release "Android (Google Play)"     build/android/DEADLINE15.aab     # 출시 키스토어 필요 (아래)
  Godot --headless --path godot --export-debug   "iOS (App Store)"           build/ios/DEADLINE15.ipa         # 팀 ID 필요 (아래)
  ```
- 크기: (2026-10-23, armeabi-v7a 제외 · 용량 줄이기 뒤) **디버그 APK 131MB**(arm64-v8a 만, 디버그 템플릿 — 내보내기 폴더의 `DEADLINE15-debug.apk`) · **출시 AAB 74.6MB**(출시 템플릿, 디버그 키로 서명해 시험한 것) — libgodot 70MB(arm64) + pck 43MB. 이전: APK 269MB · AAB 157MB.
  ABI 는 프리셋 `architectures/*` 가 Godot → Gradle(`export_enabled_abis` → `abiFilters`)로 넘어가므로 gradle 파일을 따로 고칠 것이 없음. **arm64-v8a 만**(armeabi-v7a · x86 · x86_64 끔) — 이유는 아래 '용량 줄이기 3'.

### 서명 — 사용자가 할 일

- **안드로이드 업로드 키** (만들지 않았음): `keytool -genkeypair -v -keystore deadline15-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000` →
  안전한 곳에 보관(분실하면 Play 고객센터에 키 재설정 요청) → 프리셋 `keystore/release`·`release_user`·`release_password` 에 넣거나(git 에 비밀번호를 올리지 말 것)
  환경 변수 `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` · `_USER` · `_PASSWORD` 로 넘김. **Play 앱 서명**(Google 이 앱 서명 키를 보관)을 켜고 업로드 키로 서명한 AAB 를 올림.
- 디버그 키스토어는 `godot/android/keystore/debug.keystore` (android / androiddebugkey / android, git 제외, 스크립트가 만듦).
- **iOS**: Apple Developer Program → 프리셋 `application/app_store_team_id` 에 팀 ID → 내보낸 Xcode 프로젝트를 Xcode 에서 열어 Signing(자동 서명) → Archive → App Store Connect.
  시험할 때는 임시 팀 ID 로 내보낸 뒤 `DEVELOPMENT_TEAM = ""` 로 되돌려 `xcodebuild ... -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO` 로 빌드함 (시뮬레이터용 빌드 성공).

### 실행 확인 (2026-10-18)

- 안드로이드 에뮬레이터(Pixel_8_API_35, 2400×1080 420dpi, arm64 디버그 APK, `--esa command_line_params "--,--store,dev"` 로 가짜 가게):
  지휘관 설정(목록 끌기) → 로비 → 뒤로 단추(종료 확인) → 스테이지 → 스토리(뒤로 = 넘기기) → 전투(메뉴 · 이동 탭 · 맵 끌기 · 길게 누르기 정보) → 홈 → 프로세스 죽임 → 다시 켜기 → 전투 재개 →
  설정 창 스크롤 → 항복 → 결과 → 로비 → 상점 골드 → 가짜 결제 확인 → 500 골드 지급. 사진 `tests/screens/m6a_emu_*.png`. 두 손가락 확대는 adb 로 넣을 수 없어 머리 없는 시험으로만 확인.
- iOS: Xcode 프로젝트 내보내기 · 시뮬레이터용 빌드 성공. **실행은 못 함** — Godot 4.5.1 공식 iOS 템플릿의 시뮬레이터 라이브러리가 x86_64 뿐이라 Apple Silicon 시뮬레이터에서 돌리려면 Rosetta 가 필요(이 맥에 없음, 설치 = 다운로드).
  iOS 26 시뮬레이터는 x86_64 앱을 아예 받지 않음.

### 6a 남은 일

- iOS 실제 실행 (Rosetta 설치 후 iOS 18 시뮬레이터, 또는 실제 기기·arm64 시뮬레이터 템플릿) · ⚑ ↩ 기호가 iOS 시스템 글꼴로 그려지는지.
- 전투 화면은 휴대폰 논리 높이 480 에서 윗줄 58 + 카드 약 158 이라 맵이 좁음 — 카드 줄 접기 같은 장치는 사용자 결정 후.
- 단추가 아닌 누르는 부품(전투 카드·행동 순서 줄 등 PanelContainer + gui_input)은 44pt 검사 대상이 아님 (카드는 충분히 큼, 순서 줄 높이 약 40 → 5.4mm).
- 손가락으로 누른 단추가 호버 모양으로 남는 것(마우스 흉내의 성질), 지휘관 이름 칸 위에서 끌기를 시작하면 키보드가 뜰 수 있음.
- 모바일 메모리: 글꼴 4개(약 80MB)를 시작할 때 모두 읽음 (README '글꼴' 남은 과제 그대로).

### 6a 검수·QA 수정 (2026-10-20)

- **안전 영역 감시**: 가로 ↔ 역가로(180° 회전)는 창 크기가 같아 `size_changed` 가 안 오므로, `Mobile` 이 0.5초마다 (안전 영역 · `screen_get_orientation` · 창 크기) 서명을 비교해 달라졌을 때만 `apply()` (돌아올 때·창 크기 알림에서도 바로 확인). 시험: `Mobile.inset_override` 로 여백을 주입 (check_qa6a '4) safe').
- **프리셋**: Android `package/app_category` 0(접근성) → **2(게임)**, 적응형 전경은 안전 영역(가운데 66%) 안에 들어가게 **60%** 로 줄이고 테마 아이콘(monochrome)은 같은 그림의 윤곽(흰색)으로,
  5개 프리셋 모두 `exclude_filter` 에 **`dev/*` · `assets/pilot/*`** (다른 작업의 시범 파일이 빌드에 안 들어감 — check_mobile6a 가 확인, 내보낸 APK·pck 목록으로도 확인).
- **iOS Info.plist 의 빈 사용 설명 키** (카메라·사진·마이크): Godot 4.5.1 은 프리셋이 비어 있어도 키를 늘 써 넣음(프리셋 옵션으로는 못 지움) →
  내보낸 뒤 **`bash godot/tools/ios_fix_plist.sh godot/build/ios`** 로 지움 (내보낼 때마다, Xcode 에서 열기 전에).
- **앱 크기 안내** → 2026-10-23 에 둘 다 적용함 (`armeabi-v7a` 제외 · 글꼴 부분 집합) — 아래 '용량 줄이기'.
- **QA 에서 나온 것 (PC·모바일 공통)**: 소환사 `{name}` 소환 글자(엔진 `fx_float` 에 `params` — 기록(golden)에는 안 들어가고 화면 글자에만, 같은 꼴이던 저주 `{n}`·연속 사격 `{hits}`도) ·
  결과 창 골드 줄을 기본 / 새 별 / 첫 클리어 / 합계로 나눔 (합계 = 줄 합 — 상자 골드는 전투 중에 따로 더해짐) · 한국어 조사(`scripts/core/josa.gd`, `I18n.t` 가 ko 일 때만) ·
  처치 EXP 글(`gd.result.battle_detail` — '총 N EXP' 가 아니라 '처치 EXP N (M명이 나눠 받음)') · 결과가 뜨면 윗줄 턴 표시 숨김 · 별 '이번 판 ✓/✕' 와 '기존 기록 ★' 구분 ·
  로비 알림이 아래 단추 줄을 안 덮음 · 장비 창 왼쪽 고정 + 목록만 스크롤 · 능력치 이름 통일(`gd.stat.*`) · `messages.buff_end` 번역(`gd.fx.buff_end`).
- 시험: `tests/check_qa6a.gd` (조사 · 글자 자리표시자 · 결과 창 · 안전 영역 감시 · 겹침 · 장비 창 · 능력치 이름).

### 6a 재검수 반영 (2026-10-20)

- **✕ 포기 단추 (모바일)**: 이어하기 단추가 본문 맨 위라 '위쪽 바깥'에 두면 윗줄 밑으로 잘렸음 → 모바일은 **이어하기 단추 오른쪽 옆 같은 줄**(`ResumeRow`), PC 는 그대로(단추 위쪽 바깥). 열이 넓어지면 아이폰·태블릿 등에서 오른쪽 안전 영역을 넘던 것도 `popups.minimum_size_changed` 로 다시 맞춤.
  시험(check_qa6a '5) layout')은 '화면 안'만이 아니라 **다른 부품(윗줄·창)에 가려지는지**(그 자리에서 가장 위의 부품이 이 단추인가) · 안전 영역 밖 · 부모 잘림 영역 밖까지 봄 — PC + 모바일 4기기 × 6개 언어.
- **한국어 조사 규칙** (`scripts/core/josa.gd` 머리말과 같은 표 — 단순한 규칙, 완벽하지 않음):
  | 앞 말 | 받침 판정 |
  |---|---|
  | 한글 | 마지막 글자 그대로 (없음 / 있음 / ㄹ) |
  | 숫자 | 읽는 소리 0 영·1 일(ㄹ)·2 이·3 삼·4 사·5 오·6 육·7 칠(ㄹ)·8 팔(ㄹ)·9 구. 두 자리 이상은 끝자리 (11·21 → 일 → ㄹ, 12 → 이). 끝이 0 이면 십·백·천·만 → 받침(ㄹ 아님) |
  | 영문 한 글자 | 글자 이름: L 엘 · R 알 → ㄹ, M 엠 · N 엔 → 받침, 나머지 없음 |
  | 영문 낱말 | 마지막 글자: l r → ㄹ, m n b k p d t g → 받침, 나머지(모음 · s z x f v c j h w y q) → 없음. 'Jane'(제인)처럼 소리 안 나는 e 는 틀림(한계) |
  ㄹ 받침은 이(가)·은(는)·을(를)·와(과) 에서는 '받침 있음', (으)로 에서만 '로'. 시험은 `I18n` 에 심은 합성 문구로 ko 에만 적용되고 en·es·ja·zh 에는 적용되지 않음을 확인.
- **결과 창 합계**: 보물상자에서 얻은 골드(`S._chestGold` — `chest_open` 이 더함, 전투 중 바로 저장되므로 패배·항복에서도)를 '보물상자' 줄로 넣고 합계에 포함 →
  **보상 줄 합 = 실제 골드 증가**가 모든 경우(첫 클리어 · 다시 클리어 · 새 별 · 연습 · 패배, 상자를 연 판 balanced_s05·boss_s10 포함)에서 같음 (시험이 같아야 통과).
- 시험 보강: float 시험이 실제 전투(legion5_s09 소환 · swamp_s21 저주 · boss_s10 연속 사격)를 끝까지 몰아 엔진의 `p` 와 화면에 실제로 뜬 글자(`float_log`)를 확인 — `d["p"] = params` 를 지우면 실패.

## 6b — 모바일 결제·광고 실제 연결 (2026-10-21)

Google Play 결제 · App Store(StoreKit 2) 결제 · AdMob 보상형 광고(골드 100 × 하루 3회)를 붙임. STOVE·Steam 은 이번 범위 아님. 패키지·번들 ID `xyz.show4you.deadline15`.
받은 플러그인의 이름·버전·sha256·라이선스·출처·넣고 뺀 것은 **`addons/SOURCES.md`**. 서버 약속은 `docs/server/api.md` (2.1 계정 토큰 · 8장 모바일 클라이언트).

### 구조

| 파일 | 하는 일 |
|---|---|
| `scripts/core/billing/backend_google.gd` | 플러그인 `BillingClient` 를 감쌈 — 연결 · 가격 · 구매 · 소모 · 미처리 조회. `obfuscatedAccountId = SHA-256(iid) 앞 32자`. 플러그인이 없으면 `is_supported` 거짓 |
| `scripts/core/billing/backend_apple.gd` + `apple_iap.gd` | godot-iap 래퍼를 감싼 어댑터(플러그인 타입·신호를 아는 곳은 어댑터뿐) — `appAccountToken = Billing.account_uuid(iid)`, 영수증 = JWS, 환불된 미처리는 finish 로 치움 |
| `scripts/core/billing/sig_wait.gd` | '신호 하나를 제한 시간 두고 기다림' — SDK 응답이 영영 안 와도 멈추지 않음 |
| `billing.gd` (추가) | `unfinished_changed`(백엔드가 알리는 새 거래 → restore) · `prepare()`(연결 기다림) · `account_uuid` · `inject_backend`(시험) · `--iap-server emulator` · `IAP_SERVER.local.android_url` |
| `scripts/core/ads.gd` | 보상형 광고 상태 기계: 동의(UMP) → SDK 초기화 → 불러오기 → ready → 보여 주기 → 보상 획득 때 바로 지급·저장 → 닫으면 `rewarded`/`closed`. 하루 3회·시계 규칙(`ad_rules.gd`)은 그대로 |
| `scripts/core/ads/admob_bridge.gd` | Poing AdMob 플러그인 API 를 단순한 모양으로 (시험은 같은 모양의 가짜를 끼움) |
| `shop.gd` · `settings_screen.gd` · `licenses.gd` | 광고 카드 상태별 단추 · 설정 '광고 개인정보 설정' 단추(모바일) · 라이선스 화면의 플러그인·SDK 고지 |
| `tools/ios_export.sh` · `ios_post_export.py` · `ios_privacy_strings.json` | iOS 내보내기 (아래) |

- **결제 순서**는 변함없음 (서버 verify → 전투 중이면 미룸 → 지급 → 디스크 확정 → consume/finish). PENDING·Ask to Buy 는 지급 없이 안내, 승인되면 저절로 지급. ITEM_ALREADY_OWNED 는 소모하지 않은 그 구매를 찾아 지급 길로.
- **광고**: 디버그 빌드는 늘 구글 공개 시험 광고 단위(`data/iap.json ADMOB.test`), 출시 빌드는 `ADMOB.real`(실제 광고 단위 채워짐; 비면 광고 'unconfigured'=이용 불가, 시험 단위로 대신하지 않음).
  아동 대상 아님(`tag_for_child_directed_treatment` FALSE)·미성년 동의 연령 미만 아님을 SDK 초기화 때 명시. 카드 단추: 준비됨 '광고 보기' · 불러오는 중 · 오프라인/실패 '다시 불러오기' · 동의 필요 '동의하고 광고 보기' · 오늘 다 받음.
  오프라인·실패는 15초에서 시작해 최대 5분까지 늘리는 재시도 + 앱 복귀·상점 진입 때 다시. 1시간 지난 광고는 버림.
  PC 가게(stove·steam)와 광고 SDK 가 없는 환경(PC·편집기의 `--store google`)에서는 광고 카드 숨김.
- **동의/ATT**: 시작할 때 UMP 정보 갱신 → 필요하면 동의 창 → 동의 상태가 not_required/obtained 일 때만 SDK 초기화·광고 요청. 플러그인(5.1.0)은 ATT 추적 허용 창을 직접 부르는 API 가 없음 →
  iOS 는 Google AdMob 콘솔 '개인정보 및 메시지'의 **IDFA 설명 메시지**를 켜 두면 UMP 흐름에서 ATT 창이 뜸(= 광고 불러오기 전). 문구 `NSUserTrackingUsageDescription` 은 6개 언어(`tools/ios_privacy_strings.json`) — 기본(en)은 프리셋 `additional_plist_content`, 나머지는 `<언어>.lproj/InfoPlist.strings`(ios_post_export.py).
  디버그: `-- --ump-eea` 로 동의 지역을 EEA 로 흉내.
- **서버 연결 (개발용)**: 안드로이드 에뮬레이터 → 호스트 맥의 `wrangler dev`: 디버그 빌드에 `-- --store dev --iap-env local` (주소 `http://10.0.2.2:8951`, `IAP_SERVER.local.android_url`) 또는 `-- --iap-server emulator`.
  출시 빌드는 `https://` 주소만 (http·fake:// ·인자는 무시, `verifier.gd`).

### 안드로이드 내보내기

- 플러그인: `addons/GodotGooglePlayBilling`(Play Billing Library 9.1.0, `billing-ktx`) · `addons/admob`(GMA Next-Gen SDK `ads-mobile-sdk` 1.4.0). 편집기 플러그인 둘 다 켬(`project.godot`). 네이티브 라이브러리 정렬: 플러그인에 `.so` 없음, `zipalign -c -P 16` 통과.
- **Gradle 의존성**: 이 맥 캐시에 없던 Maven 의존성(플러그인이 선언한 `billing-ktx` · `ads-mobile-sdk` 와 그 하위 67개 파일, 약 16.7MB)이 첫 내보내기 때 내려와짐 — `gradle.properties` 의 `org.gradle.offline=true` 만으로는 막히지 않았음.
  그 뒤로는 `tools/android_build_template.sh`(기본 OFFLINE=1)가 `gradlew` 를 `--offline` 이 붙는 감싸개로 바꿔 더는 받지 않음 (캐시에 없으면 실패하며 없는 목록을 보임). 새 PC 에서는 처음에 한 번 `OFFLINE=0` 으로 설치해 캐시를 채울 것. 받은 파일 67개의 좌표·sha256 은 `addons/SOURCES.md` 에 기록.
- 매니페스트(병합 결과)에 광고 앱 ID(`com.google.android.gms.ads.APPLICATION_ID` — 실제 앱 ID, `project.godot` 의 `admob/general/android/app_id` 와 `data/iap.json ADMOB.real.app_id` 가 일치해야 하며 시험이 확인. UMP 동의 메시지·app-ads.txt·스토어 연결은 아직 남음) · `com.android.vending.BILLING` · targetSdk 36 · minSdk 24.
  권한은 SDK 가 요구하는 것: `INTERNET`(프리셋) · `AD_ID`(`android.permission.AD_ID`·`com.google.android.gms.permission.AD_ID`, 광고 ID — Play Console '광고 ID' 선언 필요) · `ACCESS_NETWORK_STATE` · `READ_BASIC_PHONE_STATE`(GMA SDK) ·
  `BILLING` · `WAKE_LOCK` · `FOREGROUND_SERVICE`(androidx.work, 광고 SDK 가 끌어옴) · `RECEIVE_BOOT_COMPLETED`(GMA SDK 작업 예약) · `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`(androidx, 앱 안에서만). 위치·연락처·저장소 같은 권한은 없음.
- 크기: 출시 AAB 157.45MB → **164.43MB (+6.98MB, +4.4%)**, 디버그 APK 약 269MB → 277.6MB. 내보낸 pck: Windows +0.36MB.

### iOS 내보내기

- 플러그인: AdMob(Google Mobile Ads 13.9.0 · UMP 3.1.0 SPM 패키지 + `poing-godot-admob-ads` xcframework) · godot-iap 4.0.3 (iOS **17.0+** 필요 — SwiftGodot 확장이라 프리셋 최소 iOS 15.0 → 17.0).
- `bash godot/tools/ios_export.sh` — godot-iap 의 GDExtension 을 `third_party/godot-iap-ios` 에서 `addons/godot-iap/bin` 으로 **내보내는 동안만** 복사(평소에 있으면 데스크톱 편집기가 'No GDExtension library found' 오류), 임시 팀 ID 로 Xcode 프로젝트를 내보낸 뒤 `ios_post_export.py` 로 손질:
  빈 사용 설명 키 지움 · `CFBundleLocalizations` + 6개 언어 `InfoPlist.strings` · godot-iap 프레임워크 2개를 'Embed Frameworks(서명하며 복사)'로(+ Info.plist) · AdMob SPM 연결(플러그인 자신의 연결은 헤드리스 내보내기 중에 실행되지 못함) · `SystemCapabilities com.apple.InAppPurchase` · 임시 팀 ID 비움.
  (내보내는 중 Godot 이 맥 호스트에서 `godot_iap.gdextension` 의 'No GDExtension library found' 오류를 내는 것은 정상 — iOS 라이브러리만 있기 때문.)
- Info.plist 에 `GADApplicationIdentifier`(지금 시험 앱 ID) · `SKAdNetworkItems` · `NSUserTrackingUsageDescription` 들어감. 서명 없이 시뮬레이터용 빌드: `xcodebuild -project godot/build/ios/DEADLINE15.xcodeproj -scheme DEADLINE15 -sdk iphonesimulator -arch x86_64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build`
  (Godot 4.5.1 공식 iOS 템플릿의 시뮬레이터 라이브러리가 x86_64 뿐 — 6a 와 같음). godot-iap 의 네이티브는 기기(arm64)용이라 **시뮬레이터에서는 결제가 동작하지 않음**(래퍼가 '네이티브 없음'으로 처리, 앱은 정상).

### 시험 · 확인한 것

- `tests/check_mobile6b.gd` — 가짜 `BillingClient`(`tests/fake_play_client.gd`) · 가짜 어댑터(`fake_apple_iap.gd`) · 가짜 AdMob 다리(`fake_admob_bridge.gd`) · 대본형 서버(`fake_store_server.gd`)로 모든 경로 + 진짜 `admob_bridge.gd` 를 플러그인의 편집기용 mock 으로 돌림.
- 안드로이드 에뮬레이터(Pixel_8_API_35, Google Play 이미지, 디버그 APK): 플러그인 포함 앱이 정상 실행, 결제 연결 실패(`BillingClient: Reconnection failed with result: 3`)는 앱을 죽이지 않고 결제 카드만 꺼짐,
  시험 광고 단위로 **실제 광고가 떠서 끝까지 보고 닫으면 '100 골드를 받았습니다' · 골드 +100 · 오늘 2/3** 확인.
  못 한 것: 실제 결제(Play Console 상품·라이선스 테스터·서명된 빌드 필요), 서버 확인(서버 배포 전·가짜 서버는 google 영수증을 받지 않음), UMP 동의 창(에뮬레이터 지역이 EEA 가 아님 — `--ump-eea` 로는 시험하지 않음), 에뮬레이터에서의 iOS.
