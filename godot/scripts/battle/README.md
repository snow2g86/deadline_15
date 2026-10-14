# 전투 화면 (Godot) — 3a 뼈대

`scenes/battle/battle.tscn` (스크립트 `battle_scene.gd`). **화면만** 맡습니다. 규칙은 전부 엔진(`scripts/logic/battle/battle_engine.gd`, `scripts/logic/README.md`)이 정하고,
화면은 엔진 신호를 받아 재생하고 플레이어 조작을 엔진 명령으로 바꿀 뿐입니다. 규칙 코드는 이 단계에서 바꾸지 않았고,
화면에 필요한 것은 **순수 조회**로만 더했습니다 (`battle_query.gd`: `shove_cells` · `potion_targets` · `siege_targets` — `tests/check_battle_api.gd` 의 순수성 시험에 포함).

## 장면 구조

```
Battle (Node2D, battle_scene.gd)          엔진 소유 · 신호 대기열 · 재생 · 입력 · 카메라 · UI 수준 입구
├─ Background (CanvasLayer -10)           웹 #map-container 배경 (#0a0e1a + 위쪽 푸른 빛)
├─ World (Node2D)
│  ├─ Map (battle_map.gd)                 바닥 — 아래 'z 순서'
│  │   TilesK · GroundDiag · WaterDiag · HlDiag (대각선 k 마다), TreeNode (숲 칸마다), ChestNode
│  ├─ Units (Node2D)  → U<id> (unit_view.gd) × 유닛 수
│  └─ Fx (fx_layer.gd, z 500)             떠오르는 글자 · 입자 · 행동 예고 화살표 · 공격 예상 · 방향 고르기
├─ Camera (Camera2D)                      끌기·휠·화살표 이동, Q/E 회전
└─ UI (CanvasLayer 10, battle_ui.gd)      윗줄(턴·카메라·위협·속도) · 행동 메뉴 · 안내 줄 · 웨이브 알림 · 결과 판
```

| 파일 | 웹 원본 | 내용 |
|---|---|---|
| `iso.gd` | `grid.js` g2v·v2g·isoX·isoY·tSX·tSY·depth·isoHit, `vfx.js` _g2screen·_g2sx·faceTri | 아이소 좌표 (TW 48·TH 24·ZH 10), 카메라 방향 0~3 |
| `terrain_tex.gd` | `terrain-tex.js` _draw | 절차적 타일 그림 (윗면 그라디언트·노이즈·풀·꽃·등고선·바위·물결·여울·석판·벽돌 옆면·지층·성문 판자·성가퀴). **같은 LCG·같은 난수 순서** 라 웹과 같은 자리에 같은 모양 |
| `battle_map.gd` | `render.js` rTerBg·rTer, `props.js`, `data/props.js` | 타일·하이라이트·안개·냉기 결계·위협·숲 나무·평지 풀돌·보물상자 |
| `unit_view.gd` | `render.js` rUnits, `rig.js` Rig.fit·sheet·_sheetEl·setLoop·playOnce, `vfx.js` animU·shakeU·_faceMark | 유닛 그림·막대·발밑 방향 삼각형·동작 |
| `sprite_db.gd` | `rig.js` CHAR_FIG·SPRITE_SHEETS, `sprites.js` _svgSprite | 그림 불러오기·몸 높이 맞춤·소환수 도트 그림·CSS filter → 색 행렬 |
| `fx_layer.gd` | `render.js` floatT·rIntent·rPreview·showFacePicker, `vfx.js` spawn | 연출 층 (3a 는 기본만) |
| `battle_ui.gd` | `render.js` showAM·showMainMenu·showSkillSubMenu·showItemSubMenu, 결과 | 기본 UI (3b 에서 HUD 로 확장) |
| `shaders/unit.gdshader` | `.u-icon` filter | 바닥 그림자(drop-shadow) · 적 붉은빛 · 현재 차례 금빛 · 기절 회색 · 피격 번쩍임 · 숲 반투명 |
| `shaders/prop.gdshader` | `PROP_THEME_FILTER` | 테마 색 보정 (sepia·saturate·brightness·hue-rotate 를 3x3 행렬로) |
| `shaders/water.gdshader` | `.t-water::after` · `.t-lava::after` | 물·용암 반짝임 띠 |

### z 순서 (웹 z-index 규칙 그대로)

- 대각선 k = vc + vr (화면 기준 칸 번호 합). 타일 노드 z = 2k, 같은 z 로 바닥 장식·물 반짝임, 하이라이트 z = 2k+1 → 앞쪽 높은 타일(언덕·바위·성벽)의 옆면이 뒤 칸 하이라이트를 가림.
- 맵 오브젝트·유닛은 `Grid.depth(c, r, layer) = 100 + 3k + layer` — 보물상자 0 < 나무 1 < 유닛 2. 유닛은 **도착 칸 기준** (웹과 같음).
- 연출 층 z 500 (방향 고르기 단추 포함).

### 타일 그림 굽기

`terrain_tex.gd` 의 벡터 명령은 타일 한 장에 수백 개라, 매 프레임 다시 제출하면 CPU 가 무거워집니다 (실측 12 ms/프레임).
그래서 웹처럼 **(종류·테마·변형·높이·성가퀴) 마다 한 번** SubViewport 에 3배 크기로 그려 `ImageTexture`(밉맵)로 캐시하고, 타일마다 그 그림 한 장을 붙입니다 (3.3 ms/프레임).
굽기 전 첫 프레임과 화면 없는 실행(`--headless`)은 같은 벡터 명령으로 바로 그립니다.

## 엔진 사건 → 화면 (재생 모델)

1. `eng.command()` / `eng.run()` 은 기다리지 않고 끝까지 진행합니다 (적 차례 전부 포함). 그 사이 엔진은 `bus_event`·`fx_event` 를 **동기**로 냅니다.
2. 장면은 신호를 받는 즉시 대기열 `_evq` 에 `[종류, 이름, 자료, 전장 사본]` 으로 쌓습니다.
   - `bus_event` 자료의 유닛은 엔진이 만든 **그 순간의 사본**(`unit_view`) 입니다.
   - `turn_start · turn_end · unit_added · wave_spawn · round_end` 와 fx `redraw_units · redraw_terrain · chest_open` 때는 **전장 전체 사본**(유닛·지형·상자·결계·턴)을 같이 떠 둡니다.
     (신호 처리기 안에서 엔진 상태를 읽기만 함 — `unit_view`·`is_stealthed` 는 순수)
3. `_process` 가 대기열을 시간에 맞춰 재생: 항목 하나 처리 → 반환된 초만큼 기다림 (속도 1x/2x/4x 반영, 0 = 즉시).
   | 사건 | 화면 | 기다림 |
   |---|---|---|
   | `turn_start` | 현재 차례 금빛, 윗줄 갱신, 전장 사본 반영 | 적 0.27s / 아군 0.1s |
   | `unit_moved` · fx `move` | 달리기 시트로 0.32s 이동, 끝나면 시야·나무 가림·대기 동작 갱신 | 0.36s |
   | fx `attack` → `unit_attacked` | 공격자 attack 시트 → **타격 프레임**(`dur·hit/frames`)에 대상 흔들림·hit 시트·피해 숫자·HP | 타격까지 + 0.3s |
   | `unit_killed` | 타격 뒤 쓰러짐(0.6s 사라짐) + 입자 | 0.35s |
   | `unit_healed` · `buff_tick_*` · `trap_triggered` | 숫자·입자·HP | 0.2~0.3s |
   | `skill_used` | 스킬 이름 글자 | 0.35s |
   | `wave_spawn` · `wave_announce` | 새 유닛 등장(0.4s), 웨이브 알림 | 0.6s |
   | fx `float` | 엔진 안내 글자 (번역 키면 번역, `messages.select_*` 는 아래 안내 줄로) | 0 |
   | fx `face` | 발밑 삼각형·좌우 뒤집기 | 0 |
   | `camera_focus` | 화면 밖이면 카메라를 그 유닛으로 | 0 |
4. 대기열이 비고(재생이 엔진을 따라잡음) 엔진이 입력을 기다리면(`run()` 이 `"input"`): **엔진 상태로 화면을 한 번 맞춘 뒤**(`_sync_from_engine`) 메뉴를 띄웁니다.
   안개·행동 예고·위협 범위·공격 예상은 이때 엔진 조회(`eng.q`)로 계산합니다. 재생 중 안개는 화면 사본으로 같은 식(이동력+1)을 씁니다.
5. 엔진이 멈추면(`"stopped"` 등) `eng.finish()` 결과로 결과 판. Store 세이브로 시작한 전투면 `eng.c.store` 를 Store 에 되돌려 씁니다 (디버그 세이브·시험은 쓰지 않음).

## 조작 (UI 수준 입구)

마우스·단축키·메뉴 단추가 모두 아래 함수를 거칩니다. 시험도 같은 함수로 조작합니다.

| 함수 | 뜻 | 엔진 명령 |
|---|---|---|
| `ui_action(op)` | 메뉴 단추 move · attack · shove · skill · item · wait · defend · overwatch · undo | undo 는 바로 `{op:"undo"}` |
| `ui_pick_skill(idx)` | 스킬 고르기 — 즉시형이면 바로 명령, 대상형이면 칸 고르기 | `{op:"skill", idx[, x, y]}` |
| `ui_pick_item(kind, idx)` | potion · siege (사다리 effect `climb` 은 `climb`) | `{op, idx, x, y}` |
| `ui_click_cell(x, y)` | 칸 고르기 중 칸 누르기 (치유 대상 칸이면 heal) | move · attack · heal · shove · skill · potion · siege · climb |
| `ui_pick_face(dx, dy)` | 방향 고르기 (0,0 = 지금 방향) | `{op: wait·defend·overwatch, dx, dy}` |
| `ui_cancel()` | 칸·방향·하위 메뉴 → 메뉴, 메뉴에서는 이동 취소 | (undo) |

- 단추를 보일지(가능한지)는 메뉴가 정하고, 입구 함수는 막지 않습니다. 마우스는 하이라이트 밖 칸을 누르면 취소로 걸러 냅니다.
  그래서 황금 기록의 **실패한 명령**(ok:false)도 같은 입구로 그대로 재현됩니다 (엔진이 웹처럼 기록·거절).
- 마우스: 왼쪽 누르기 = 고르기, 끌기 = 카메라 이동, 휠 = 확대(0.6~3배), 오른쪽 = 취소. 가운데 끌기도 이동.
- 키: M 이동 · A 공격 · S 스킬 · I 아이템 · P 밀치기 · D 방어 · O 경계 · W 대기 · 1~9 하위 메뉴 · Esc 취소/되돌리기 · Q/E 회전 · T 위협 범위 · 화살표 카메라.
  방향 고르는 중 Enter·Space·W·D·O = 지금 방향 그대로 (웹과 같음).
- 시험용 상태: `is_awaiting()`, `is_over()`, `awaiting_unit_id()`, `last_result`(마지막 command 결과), `result`(finish), 신호 `input_ready(id)`·`battle_over(result)`.

## 실행 · 디버그

- 편집기 F5 → 시작 화면 아래 **전투 시험 (3a 디버그 실행기)**: 스테이지·시드·파티를 고르고 '전투 시작'.
  파티는 Store 에 활성 파티가 있으면 '저장된 파티', 없으면 황금 기록의 가짜 세이브(디버그 세이브).
  '황금 기록 그대로 자동 재생' 을 켜면 그 기록의 스테이지·시드·명령을 사람이 누르듯 천천히 재생합니다.
- 장면 직접 실행 (명령줄):
  ```bash
  Godot --path godot res://scenes/battle/battle.tscn -- --golden legion5_s09 [--autoplay] [--speed 2] [--rotate 1]
  ```
- 화면 사진 (Movie Maker, 창 모드): `Godot --path godot --resolution 1280x720 --write-movie /tmp/f.png --fixed-fps 8 --quit-after 200 res://scenes/battle/battle.tscn -- --golden boss_s10 --autoplay`
  → 고른 사진은 `godot/tests/screens/` (git 제외).

## 시험

```bash
# 화면 입구로 황금 기록 22개 재생 → end(보상·saveAfter 포함)·사건 기록이 황금 기록과 같은지 (연출 없이, 약 20초)
Godot --headless --path godot --script res://tests/check_battle_scene.gd
#   끝에 회귀 시험 rotate:boss_s10 (8x 연출로 재생하며 유닛이 움직일 때마다 카메라 회전 → 멈춘 유닛이 늘 자기 칸에 있는지)
#   -- --only boss_s10,gear_s15    일부만      -- --speed 4    실제 연출 시간으로 (느림, 타이머 경로 확인)
#   -- --smoke                     황금 기록 대신 테마·진형이 다른 20개 스테이지를 '방어 태세'만으로 돌려 화면 코드 오류 확인
# 성능 (창 모드 — 실제로 그림): 밀림 지도 + 유닛 40 · 맵 오브젝트 343, 수직 동기 끔
Godot --path godot --script res://tests/perf_battle_scene.gd
```
cmd 사건은 `u·op·ok·idx·rng` 만 비교합니다 (시험 정책이 붙인 참고 키 `target·skill·item` 과 즉시형 스킬의 x·y 는 화면이 보내지 않음 — 엔진 결과에는 영향 없음).

## 웹과 다른 점 (3a)

- **글꼴**: 웹 제목 글꼴 Cinzel 이 없어 떠오르는 숫자·제목도 Noto Sans KR(굵게)로 씀 (`assets/fonts/`, OFL). 이모지는 시스템 대체 글꼴에 맡김.
- **필터 흉내**: CSS `drop-shadow`·글로 는 셰이더로 근사 (8방향×2겹 표본). 웹보다 약간 단단한 테두리.
- **스프라이트 확대**: 웹 `image-rendering: pixelated` 와 같게 최근접(nearest) 표본. 타일 그림은 3배로 구워 선형+밉맵.
- **행동 메뉴 아이콘**: 웹 이모지 대신 글자 기호 (디자인 정책: 이모지는 그림 아이콘으로 바꾸는 중 — 3b 에서 아이콘 그림).
- **스킬 이름 글자**: 스킬을 쓰면 시전자 위에 스킬 이름을 띄움 (웹은 HUD 기록에만). 3b HUD 가 생기면 정리.
- **안내 줄**: 웹 Fx.float 의 `messages.select_*` 는 떠오르는 글자 대신 화면 아래 안내 줄. 명령 실패 이유는 임시 한국어 문구(번역 키는 3b).
  실패 안내는 명령 뒤에도 같은 클랜원이 같은 상태(위치·행동·이동·자원·행동 수)로 입력을 기다릴 때만 띄움 — 엔진 `ok` 는 행동 직후 `ha` 기준이라 공격이 회피되면 false 가 되기 때문 (엔진은 그대로).
- **안개 전환**: 웹 CSS transition(.2s)·물 반짝임 위상 등 작은 시간 연출은 생략하거나 근사.
- **안개 속 나무 가림**: 안개 속에 숨은 적 앞의 나무는 반투명으로 만들지 않음 (웹은 숨은 적 앞 나무도 반투명이 되어 적 위치가 드러나는 문제가 있음). 보이는 유닛만 가림 판정에 씀.
- 이동은 웹처럼 출발 → 도착 직선 0.32s (경로를 따라 걷지 않음). 도움닫기 도약 연출 없음.

## 3b 로 넘길 것

- HUD: 아래 클랜원 카드(HP·자원·능력치·장비), 오른쪽 행동 순서, 윗줄 스테이지 정보·돌파·환경·조합 버프 칩, 미니맵, 설정(음량·속도)·항복.
- 미리보기 다듬기: 칸 위에 마우스를 올렸을 때 정보, 적 정보 팝업, 스킬·아이템 설명, 상태 배지(버프·기절 수·소환 턴·은신).
- VFX: 직업별 타격 효과·픽셀 투사체(`pixelfx.js`)·화면 흔들림·차례 번쩍임·버프 빛·도움닫기 도약, 소리(`audio.js`).
- 결과 화면(경험치 막대·레벨업·드랍·별점), 이어하기(엔진 `save_text`/`load_state` 는 준비됨), 로딩 화면.
- 스토리 대사(`story-battle.js`), 뒷모습 시트(웹도 꺼 둠), 컷아웃 리그(시트가 없는 그림용).
