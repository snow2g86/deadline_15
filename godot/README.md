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
  scenes/boot.tscn     시작 화면 (메인 씬)
  scripts/core/        오토로드: store.gd(Store) · data_db.gd(DataDB) · i18n.gd(I18n), json_norm.gd(번호 키 int) · num.gd(Num.fmt 표시)
  scripts/logic/       전투·성장 규칙 — 화면 코드 없이 (2b: 웹 전투 규칙 이식, scripts/logic/README.md)
  scripts/logic/battle/  전투 엔진 (battle_engine.gd: 명령 입력·진행·신호)
  scripts/battle/      (2단계~) 전투 화면
  scripts/ui/          화면 스크립트 (boot.gd)
  data/                변환된 JSON (git 에 올림)
    *.json             모듈별 전역 (stages.json 의 STAGES 등)
                       화면 쪽 표: icons.json(ITEM_SPRITE·EMOJI_ICON·ICON_RARITY) · sprites.json(CHAR_SPRITES·CUTOUT_RIGS·
                       CHAR_FIG·SPRITE_SHEETS·ATK_MOTIONS) · ui.json(NAV_TABS) · soul.json(SOUL_KEY)
    lang/{ko,en,es}.json   언어 팩
    story/{ko,en,es,sample}.json   스토리 대본
    manifest.json      전역별 개수·원본 sha1·경고·특수값 위치 (DataDB 가 검증에 사용)
  assets/image/        웹 image/ 사본 (git 제외)
  tests/check_foundation.gd   머리 없는 시험
  tests/golden/        전투 황금 기록 (node tools/battle-sim.js 로 생성 — 2b 규칙 이식의 기준, tests/golden/README.md)
  tests/replay_golden.gd   2b 시험: 황금 기록 22개를 GDScript 규칙으로 재생해 사건·난수까지 비교
  tests/check_battle_api.gd  엔진 조회 API 순수성·command 결과 시험,  tests/fixtures/js_numbers.json  JS 실수 표기 정답 (node 로 만든 것)
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
**Resources → Filters to export non-resource files (include_filter) 에 `data/*` 를 꼭 넣으세요** (`data/*, data/lang/*, data/story/*` 처럼 하위 폴더 포함).
빠지면 내보낸 게임에서 DataDB 가 "manifest.json 을 읽지 못했습니다" 오류를 냅니다.

## 열기 · 실행

- 편집기: Godot 4.5 에서 `godot/project.godot` 열기 → F5 (시작 화면: 제목, 데이터 모듈 개수, ko/en/es 버튼)
- 명령줄: `/Applications/Godot.app/Contents/MacOS/Godot --path godot`

## 시험

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/check_foundation.gd
```

마지막 줄이 `RESULT: PASS (n개 통과)` 이면 성공(종료 코드 0), 실패면 `RESULT: FAIL` 과 실패 항목 목록(종료 코드 1).

전투 규칙(2b) 시험 — 황금 기록 21개 재생 (`--only 이름`, `--external`, `--rng-log` 는 scripts/logic/README.md):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/replay_golden.gd            # 22개 (-- --resume: 모든 입력 대기마다 저장·복원)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/check_battle_api.gd         # 엔진 조회 API·command·사본·plan_rule
```
시험은 `user://test_foundation_save.json` 을 쓰고 지우므로 진짜 저장(`user://save.json`)은 건드리지 않습니다.

## 오토로드 사용법

```gdscript
# 데이터 (웹 전역 이름 그대로)
var stages: Array = DataDB.global("STAGES")
var hz: Dictionary = DataDB.module("hazards")["HAZARDS"]

# 번역 (웹 t() 와 같은 점 키 · {이름} 자리표시자)
I18n.t("hazard.safe_zone", {"i": "❄️", "r": 3})   # 항상 String (값이 배열·사전이면 키 그대로)
I18n.t_raw("battle.loading_tips")                 # 웹 t() 와 똑같이: 배열·사전 값은 그대로 (Variant)
I18n.set_language("en")          # game_settings.language 에 저장 + language_changed 신호

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
