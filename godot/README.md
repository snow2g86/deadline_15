# DEADLINE 15 — Godot 4 판 (이전 작업 중)

웹판(HTML/CSS/JS)을 Godot 4.5 로 옮기는 프로젝트입니다. 지금은 **1단계(기초)**: 데이터 변환, 그림 복사, 저장·번역·데이터 창구, 시작 화면, 시험까지.

## 원칙

- **수치·대본·번역의 원본은 웹 `data/*.js`** 입니다. Godot 은 변환기가 만든 `godot/data/*.json` 만 읽습니다.
  JSON 을 직접 고치지 말고, 웹 파일을 고친 뒤 변환기를 다시 돌리세요.
- **그림은 git 에 두 벌 올리지 않습니다.** 웹 `image/` 를 `godot/assets/image/` 로 복사해 쓰고, 이 폴더는 `.gitignore` 대상입니다.
  (Godot 이 만드는 `*.import` 옆파일도 사본 쪽에만 생겨 웹 `image/` 는 깨끗하게 유지됩니다.)
- 데이터·규칙(`scripts/core`, `scripts/logic`)과 화면(`scripts/ui`, `scenes`)을 나눕니다. 전투 규칙은 다음 단계에서 화면과 무관한 GDScript 로 옮깁니다.

## 폴더

```
godot/
  project.godot        렌더러 gl_compatibility, 1280×720 · 창 크기 조절 · canvas_items 늘이기
  icon.png             임시 앱 아이콘 (웹 image/icon/jab/knight.png 사본)
  scenes/boot.tscn     시작 화면 (메인 씬) — 잠깐 제목을 보여 주고 로비로 (Router). 개발용: -- --dev (예전 시작 화면 + 전투 시험 실행기), -- --screen <이름>, -- --save <경로>
  scenes/outer/        4a 바깥 화면: lobby · stage_select · party_select · settings, 4b-1: shop, 4b-2: sanctuary · academy · compendium · guide · credits · licenses (scripts/ui/*.gd)
  scenes/battle/battle.tscn   전투 장면 (3b: HUD·연출·결과·스토리 — scripts/battle/README.md)
  scripts/core/        오토로드: store.gd(Store) · data_db.gd(DataDB) · i18n.gd(I18n), json_norm.gd(번호 키 int) · num.gd(Num.fmt 표시) · fonts.gd(언어별 글꼴 사슬)
  scripts/logic/       전투·성장 규칙 — 화면 코드 없이 (2b: 웹 전투 규칙 이식, scripts/logic/README.md)
  scripts/logic/battle/  전투 엔진 (battle_engine.gd: 명령 입력·진행·신호)
  scripts/battle/      전투 화면 (3a: 지형·유닛·카메라·조작·엔진 사건 재생, 3b: HUD·툴팁·연출·결과·로딩·스토리 대사 — scripts/battle/README.md)
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
  data/                변환된 JSON (git 에 올림)
    *.json             모듈별 전역 (stages.json 의 STAGES 등)
                       화면 쪽 표: icons.json(ITEM_SPRITE·EMOJI_ICON·ICON_RARITY) · sprites.json(CHAR_SPRITES·CUTOUT_RIGS·
                       CHAR_FIG·SPRITE_SHEETS·ATK_MOTIONS) · ui.json(NAV_TABS) · soul.json(SOUL_KEY)
    lang/{ko,en,es,ja,zh-CN,zh-TW}.json   언어 팩 (언어 목록 = 웹 js/common/i18n.js _I18N_LANGS)
    lang_extra/<언어>.json   Godot 전용 번역 키 (gd.* — 손으로 관리, 6개 언어 같은 키. 웹 팩에 없는 키만 I18n 이 더함, 변환기·DataDB 검사는 건너뜀.
                       ja·zh 는 docs/i18n/glossary.*.md 용어)
    story/{ko,en,es,ja,zh-CN,zh-TW,sample}.json   스토리 대본
    manifest.json      전역별 개수·원본 sha1·경고·특수값 위치 (DataDB 가 검증에 사용)
  assets/image/        웹 image/ 사본 (git 제외)
  assets/fonts/        Noto Sans KR·JP·SC·TC (가변 굵기, OFL — OFL.txt 하나가 넷 모두의 라이선스, 같은 글). git 에 올림 (약 50MB).
                       project.godot 기본 글꼴은 KR, 실행 중에는 scripts/core/fonts.gd 가 언어별 사슬로 바꿈 (아래 '글꼴')
  tests/check_foundation.gd   머리 없는 시험 (6개 언어: 팩·대본·lang_extra 키 맞춤, 언어 감지, 글꼴 사슬)
  tests/check_glyphs.gd        6개 언어 데이터의 모든 글자가 글꼴 사슬에 있는지 + 한자·가나가 그 언어 글꼴로 그려지는지 (두부 0)
  tests/shots_lang6.gd         ja·zh-CN·zh-TW 전투 HUD·설정·대사 화면 사진 (창 모드 → tests/screens/lang6_godot_*.png)
  tests/golden/        전투 황금 기록 (node tools/battle-sim.js 로 생성 — 2b 규칙 이식의 기준, tests/golden/README.md)
  tests/replay_golden.gd   2b 시험: 황금 기록 22개를 GDScript 규칙으로 재생해 사건·난수까지 비교
  tests/check_battle_api.gd  엔진 조회 API 순수성·command 결과 시험,  tests/fixtures/js_numbers.json  JS 실수 표기 정답 (node 로 만든 것)
  tests/check_battle_scene.gd  3a·3b: 전투 장면을 머리 없이 띄워 황금 기록을 화면 입구(UI 수준)로 재생 (HUD·연출·스토리 켬) → 결과가 같은지
  tests/check_battle_ui.gd     3b: UI 연기 시험 (모든 패널·팝업·툴팁·결과·스토리·언어 바꾸기, Godot 오류 0)
  tests/perf_battle_scene.gd   창 모드 성능 측정 (유닛 40·맵 오브젝트 ~340·HUD·연출·회전)
  tests/check_outer_4a.gd      4a: 규칙을 웹 정답(tests/fixtures/outer_4a_web.json ← node tools/outer-4a-expect.js)과 비교 · 편성 저장 · 설정 키 ·
                               진짜 장면 흐름 · 6개 언어 넘침·두부 · 창 크기
  tests/play_4a.gd · shots_4a.gd  4a 실제 창 한 판(진짜 입력, '대상 고르기' 멈춤을 세어 PLAY_RESULT) · 화면 사진 (tests/screens/4a_*.png)
  tests/check_outer_4b1.gd     4b-1: 상점·장비·강화·아이템 규칙을 웹 정답(tests/fixtures/outer_4b1_web.json ← node tools/outer-4b1-expect.js, 같은 씨앗·시각)과 비교 ·
                               이어하기(끊고 이어도 같은 결과) · 진짜 장면 · 같은 프레임 연타 · 이상한 세이브 · 6개 언어 넘침·두부 · 웹 왕복(--roundtrip)
  tests/play_4b1.gd            4b-1 실제 창: 로비 → 상점 → 편성(장비·강화) → 전투 → 나가기 → 전투 재개 → 끝 (tests/screens/4b1_*.png, -- --size 1920x1080)
  tests/check_outer_4b2.gd     4b-2: 성소·아카데미 규칙을 웹 정답(tests/fixtures/outer_4b2_web.json ← node tools/outer-4b2-expect.js)과 비교 · 도감·가이드 글 조각 = 웹 HTML ·
                               V8 정렬(64개 이상) · 이어하기 판 확인·포기 · 진짜 장면 · 같은 프레임 연타 · 이상한 세이브 · 웹 왕복 · 6개 언어 넘침·두부 · '준비 중' 없음
  tests/play_kit.gd            실제 창 시험 공용 (논리 화면 기준 칸 보이기 · HUD 피하기 · 그리기 기다림 시간 제한)
  tests/aux_class_preview.gd   check_outer_4b2 보조 (다른 프로세스에서 전직 미리보기 보관값 읽기)
  tests/play_4b2.gd            4b-2 실제 창: 로비 → 성소 → 아카데미 → 도감 → 가이드 → 설정 → 크레딧 → 라이선스 → 로비 → 전투 한 판 (tests/screens/4b2_*.png, -- --size 1920x1080)
  tests/shots_3b.gd            3b 화면 사진 (창 모드 → tests/screens/3b_*.png, git 제외)
```

## 처음 한 번 / 웹 데이터가 바뀔 때마다

저장소 맨 위 폴더에서:

```bash
# 1) 웹 데이터 → JSON (Node 만 있으면 됨, npm 설치 없음)
node tools/export-godot-data.js

# 2) 그림 복사 (rsync; 원본·작업 폴더 */src/, *.prev.png 제외, 지운 그림은 사본에서도 지움)
bash tools/sync-godot-assets.sh            # --dry-run 으로 미리보기 가능

# 3) Godot 첫 가져오기 (그림 .import 생성, 약 10~20초)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --import
```

변환기는 같은 원본이면 같은 결과를 내고, 내용이 같으면 파일을 다시 쓰지 않습니다 (`기록 0개, 변경 없음 24개`).

**커밋 전 점검**: 웹 `data/*.js` 등을 고치고 변환을 잊지 않았는지 확인합니다. 파일은 쓰지 않고, 바뀔 파일이 있으면 목록을 출력하고 종료 코드 1.

```bash
node tools/export-godot-data.js --check
```
끝에 출력되는 **경고**는 JSON 으로 옮길 수 없는 값(데이터 안의 함수)이며, 그 부분은 GDScript 로 다시 구현해야 합니다.

### 변환 방식

- 각 페이지의 `<script>` 순서를 읽어(기준 `battle.html`, 거기 없는 `js/common/nav.js` 등은 다른 페이지 순서로 끼워 넣음), 데이터 파일과 바로 뒤의 `js/logic/*.js` 를 그 순서대로 Node `vm` 안에서 실행합니다.
  그래서 `js/logic/stages.js` 가 적재 때 덧붙이는 `sm`·`difficulty`·`recommendedClasses` 같은 **가공 후 값**이 그대로 들어갑니다.
- 모듈 목록은 `tools/export-godot-data.js` 의 `MODULES` 입니다. 새 `data/*.js` 를 만들면 여기에 추가하세요 (빠지면 경고가 뜹니다).
  로직이 섞인 화면 파일(`js/sprites.js`, `js/battle/rig.js`, `js/battle/motion.js`, `js/common/nav.js`)은 `pick` 으로 표 이름만 꺼내고,
  적재에 필요한 화면 전역(`VFX`)은 `stub` 으로 빈 객체를 넣어 둡니다. `MutationObserver` 같은 브라우저 기능도 빈 흉내입니다.
- 언어 팩은 `js/common/i18n.js` 의 `_LANG_PARTS` 순서로 합칩니다 (웹과 같은 결과).
- `Infinity` (예: `TI.rock.cost`) 는 JSON 에 없어 문자열로 쓰고 `manifest.special_values` 에 남기며, DataDB 가 읽을 때 `INF` 로 되돌립니다.
- 함수만 모인 계산용 객체(`Gear`, `Hazard`, `Synergy` …)는 데이터가 아니라서 `manifest.skipped_logic` 에 이름만 남깁니다.

## 내보내기(export) 설정

`data/*.json` 은 Godot 리소스가 아니라 `FileAccess` 로 읽는 일반 파일입니다. 내보내기 프리셋을 만들 때
**Resources → Filters to export non-resource files (include_filter) 에 `data/*` 를 꼭 넣으세요** (`data/*, data/lang/*, data/lang_extra/*, data/story/*` 처럼 하위 폴더 포함).
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
I18n.t("gd.fail.move_failed")     # Godot 전용 키 (data/lang_extra — 웹 팩에 없는 키만 더해짐)

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
- (4b-2 에서 성소·아카데미·도감·가이드·라이선스·Credits 완료 — 아래 '4b-2') 소리는 5단계.
- 좁은 창(480×900 등 휴대폰 폭) 모바일 배치는 PC 출시 뒤로 미룸. 지금은 canvas_items·expand 늘이기라 논리 폭이 늘 1280 이상이어서 깨지지 않지만 작게 보임.

## 4b-1 — 편성 화면의 장비·소모품·강화 탭 · 상점 · 전투 이어하기

규칙은 `scripts/logic/equip_rules.gd` · `shop_rules.gd` · `resume_rules.gd`, 화면은 `scripts/ui/party_gear_tabs.gd` · `shop.gd`.
웹 정답 비교: `node tools/outer-4b1-expect.js` → `tests/fixtures/outer_4b1_web.json` → `tests/check_outer_4b1.gd` (같은 mulberry32 씨앗·같은 시각으로 웹 코드와 저장값·난수 호출 수까지).

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
웹 정답 비교: `node tools/outer-4b2-expect.js` → `tests/fixtures/outer_4b2_web.json` → `tests/check_outer_4b2.gd`
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
    - 키 `gd_class_preview` (Godot 전용, 웹은 무시) = `{ "<uid>": { "fp": { "lv": 레벨, "pot": 잠재력 }, "cls": { "<직업>": { "hp", "atk", "def", "move", "range", "pot", "grade", "cls" } } } }`
    - 무효 규칙 (`academy_rules.gd` 가 읽을 때 정리): uid 가 없거나 · 죽었거나 · 노비스가 아니면 항목 지움 / 레벨이나 잠재력(fp)이 바뀌면(레벨 업·승급) 그 클랜원 미리보기 모두 버리고 새로 굴림 /
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
