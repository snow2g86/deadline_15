# 전투 화면 (Godot) — 3b 완성판

`scenes/battle/battle.tscn` (스크립트 `battle_scene.gd`). **화면만** 맡습니다. 규칙은 전부 엔진(`scripts/logic/battle/battle_engine.gd`, `scripts/logic/README.md`)이 정하고,
화면은 엔진 신호를 받아 재생하고 플레이어 조작을 엔진 명령으로 바꿀 뿐입니다. 규칙 코드는 바꾸지 않았고,
화면에 필요한 것은 **순수 조회**로만 더했습니다 (`battle_query.gd`: `shove_cells` · `potion_targets` · `siege_targets` · (3b) `preview_attack(a, t, as_exec)` — `tests/check_battle_api.gd` 의 순수성 시험에 포함).

3a(뼈대) → 3b 에서 더한 것: HUD 전부(윗줄·행동 순서·클랜원 카드·미니맵·카메라 방향·설정), 칸·유닛 툴팁, 적 정보 팝업, 머리 위 상태 배지, 다듬은 공격 예상,
직업별 타격 효과·픽셀 투사체·화면 흔들림·번쩍임·도약·버프 빛·소환 등장, 결과 화면, 로딩 화면·스테이지 소개, 스토리 대사, Godot 전용 번역 키, 회전 끊김 제거.

## 장면 구조

```
Battle (Node2D, battle_scene.gd)          엔진 소유 · 신호 대기열 · 재생 · 입력 · 카메라(흔들림) · UI 수준 입구 · HUD 모델 · 스토리 진행
├─ Background (CanvasLayer -10)           웹 #map-container 배경 (#0a0e1a + 위쪽 푸른 빛)
├─ World (Node2D)
│  ├─ Map (battle_map.gd)                 바닥 — 카메라 방향마다 노드 묶음 Dir0~3 (아래 '회전')
│  │   DirN: TilesK · GroundDiag · WaterDiag · HlDiag (대각선 k 마다), TreeNode (숲 칸마다)   + ChestNode
│  ├─ Units (Node2D)  → U<id> (unit_view.gd: Body · Bars · Top(배지))
│  ├─ Fx (fx_layer.gd, z 500)             떠오르는 글자 · 입자 · 무기 궤적 · 행동 예고 · 공격 예상 · 방향 고르기
│  └─ PixelFx (pixel_fx.gd, z 501)        원거리 픽셀 투사체·임팩트
├─ Camera (Camera2D)                      끌기·휠·화살표 이동, Q/E 회전, offset = 화면 흔들림
└─ UI (CanvasLayer 10, battle_ui.gd)
   ├─ TurnFlash                            차례 번쩍임·큰 번쩍임 (셰이더 원형 빛)
   ├─ TopBar (hud_top.gd)                  차례 표시 · 스테이지 제목·턴 · 칩 · 위협/회전/속도 단추
   ├─ Minimap (hud_minimap.gd) · TurnOrder (hud_order.gd) · ClanCards (hud_cards.gd, 왼쪽 세로 패널) · CamDir · CalcPanel · EndTurnConfirm
   ├─ WaveBanner · StageBanner · ActionMenu · Hint
   ├─ Info (hud_info.gd)                   툴팁 · 적 정보 팝업
   ├─ Settings (hud_settings.gd)           톱니 단추 · 설정 창 · 항복 확인
   ├─ Result (result_view.gd) · Story (story_view.gd) · Loading (loading_view.gd)
```

| 파일 | 웹 원본 | 내용 |
|---|---|---|
| `iso.gd` | `grid.js` g2v·v2g·isoX·isoY·tSX·tSY·depth·isoHit, `vfx.js` _g2screen·_g2sx·faceTri | 아이소 좌표 (TW 48·TH 24·ZH 10), 카메라 방향 0~3 |
| `terrain_tex.gd` | `terrain-tex.js` _draw | 절차적 타일 그림 (같은 LCG·같은 난수 순서) |
| `battle_map.gd` | `render.js` rTerBg·rTer, `props.js`, `data/props.js` | 타일·하이라이트·안개·냉기 결계·위협·숲 나무·평지 풀돌·보물상자, 방향별 노드 묶음 |
| `unit_view.gd` | `render.js` rUnits(배지·기절 수·소환 턴), `rig.js` 시트, `vfx.js` animU·shakeU·vaultHop·buff-glow, `motion.js` playAtkMotion | 유닛 그림·막대·발밑 방향·동작·키프레임 공격(시트 없는 소환수) |
| `sprite_db.gd` | `rig.js` CHAR_FIG·SPRITE_SHEETS, `sprites.js` _svgSprite | 그림 불러오기·몸 높이 맞춤·소환수 도트 그림·CSS filter → 색 행렬 |
| `fx_layer.gd` | `render.js` floatT·rIntent·rPreview·showFacePicker, `vfx.js` spawn·_vfxHit·vfxHeal·vfxDeath·vfxBuff·vfxSiege, `motion.js` _atkTrail·_fx·_projectile | 연출 층 |
| `pixel_fx.gd` | `pixelfx.js` 전부 (KINDS·스프라이트·고리·마름모·파편 풀) | 궁수 화살·마법사 마탄·사제 성광·소환사 룬·주술사 영혼 불꽃·지휘관 음표 |
| `battle_ui.gd` | `battle.html` 화면 부품, `render.js` showAM·_amBtn·_placeAM·showWv, `vfx.js` turnFlash·vfxFlash | UI 층 (부품 배치·행동 메뉴·띠·번쩍임) |
| `hud_top.gd` | `render.js` uUI, `css/battle.css` #top-bar·.si-chip·.cam-btn | 윗줄 |
| `hud_order.gd` | `render.js` rTurnOrder | 행동 순서 (다음 행동까지 틱 = (5 − 행동력) / 회복 속도) |
| `hud_cards.gd` | `render.js` rInfoPanel | 클랜원 카드 (왼쪽 세로 패널) |
| `hud_minimap.gd` | `render.js` rMM·rMMvp·mmClick | 미니맵 |
| `hud_info.gd` | `render.js` showEnemyPopup (+ Godot 툴팁) | 툴팁·적 팝업 |
| `hud_settings.gd` | `render.js` toggleSettings·syncSettingsUI·saveSett·surrender, `battle.html` #settings-panel | 설정 |
| `result_view.gd` | `render.js` showRes | 결과 화면 |
| `loading_view.gd` | `boot.js` #battle-loading | 로딩 화면 |
| `story_view.gd` | `js/common/story.js` Story.play·_next·_advance·_skip, `css/story.css` | 대사 창 |
| `story_battle.gd` | `js/battle/story-battle.js` StoryBattle, `story.js` linesOf·_speaker·beforeStage·afterStage | 대사 시점·대본 조회·화자 |
| `unit_info.gd` | `render.js` getBuffs·unitName, `_common.js` getSkillBuffs, `hazards.js` Hazard.name/describe, `synergy.js` name/describe, `stages.js` bossName | 버프 목록·배지·이름·환경·조합 버프 글 |
| `icons.gd` | `item-icons.js` itemIcon, `emoji-icons.js` EmojiIcons, `skills.js` skillIcon, `render.js` portrait | 그림 아이콘 창구 (아래) |
| `ui_kit.gd` | `css/battle.css` 색·모양 | 글꼴·상자·Portrait·IconRect·Bar·VecIcon |
| `shaders/unit.gdshader` · `prop.gdshader` · `water.gdshader` · `portrait.gdshader` | `.u-icon` filter · `PROP_THEME_FILTER` · 물 반짝임 · `.st-pt` | |

### 그림 아이콘 (디자인 정책)

UI 에는 이모지 대신 일러스트 시트를 씁니다 (`icons.gd`).
- `icons.item(key)` — `image/icon/item-sprite.webp` (8×25 칸, `ITEM_SPRITE`), `icons.rarity_frame(key)` — 등급 테두리(`frame_*`, `ICON_RARITY`)
- `icons.skill(id, 대체 이모지)` — `image/icon/skill-sprite.png` (`SKILL_SPRITE`), 없으면 그 이모지의 그림
- `icons.emoji(e)` — 웹 `EmojiIcons` 와 같은 표 `EMOJI_ICON` → 그림. `icons.split(text)` / `fill_rich` 은 글 속 이모지를 그림으로,
  시트에 그림이 없는 이모지(그림 문자)는 지움. ⚑ ⚔ ⚠ ✓ ★ ▲ 같은 **글자 기호는 글자로** 둡니다.
- 버튼 그림(위협·회전·톱니·소리…)은 웹 SVG 를 선으로 다시 그린 `Kit.VecIcon`.
- 초상화는 캐릭터 그림의 얼굴 크롭 (웹 `.an-portrait`: background-size 210%, position 50% 12%) 을 원 안에 (`Kit.Portrait`).

### z 순서 (웹 z-index 규칙 그대로)

- 대각선 k = vc + vr. 타일 노드 z = 2k, 같은 z 로 바닥 장식·물 반짝임, 하이라이트 z = 2k+1.
- 맵 오브젝트·유닛은 `Grid.depth(c, r, layer) = 100 + 3k + layer` — 보물상자 0 < 나무 1 < 유닛 2 (유닛 배지는 유닛 안에서 +1).
- 연출 층 z 500, 픽셀 투사체 z 501. HUD 는 CanvasLayer 10.

### 타일 그림 굽기 · 회전 (3b)

- 타일 그림은 (종류·테마·변형·높이·성가퀴) 마다 한 번 SubViewport 에 3배로 그려 `ImageTexture`(밉맵) 캐시 — 3a 와 같음.
- **카메라 방향마다 노드 묶음**(`Dir0~3`)을 따로 만들고, 회전은 `switch_dir()` 로 묶음의 보이기만 바꿉니다 (3a 는 회전마다 노드 전부를 다시 만듦).
  로딩 화면이 떠 있는 동안 `prebuild_step()` 이 나머지 세 방향 묶음을 프레임마다 하나씩 만들고 (로딩 화면이 덮고 있으니 보이게 두어 한 번 그려 둠 → 나중에 `_draw` 다시 안 함),
  그 방향 타일 그림도 굽습니다. 지형이 바뀌면(`rebuild`) 묶음을 모두 버리고 다시.
- 회전 때 시야는 그대로라 다시 계산하지 않고, 행동 메뉴는 다시 만들지 않고 자리만 옮깁니다. 미니맵 지형은 삼각형 배열 한 번으로 그립니다.
- 매 프레임 할당 줄이기: 깜빡이는 하이라이트 여부는 상태가 바뀔 때만 계산(`HlDiag.animated`), 냉기 결계 그림은 칸마다 점 배열·밝기 16단계 색 배열을 한 번 만들어 재사용,
  유닛 시트는 직업·성별·동작마다 한 번 찾아 두고(`_sheet_cache`) 프레임 번호가 바뀔 때만 다시 그림, 숲 여부는 칸이 바뀔 때만, 셰이더 값은 바뀐 것만,
  연출 층 상자 모양(StyleBoxFlat)은 한 번 만들어 재사용.

## 엔진 사건 → 화면 (재생 모델)

1. `eng.command()` / `eng.run()` 은 기다리지 않고 끝까지 진행합니다. 그 사이 엔진은 `bus_event`·`fx_event` 를 **동기**로 냅니다.
2. 장면은 신호를 받는 즉시 대기열 `_evq` 에 `[종류, 이름, 자료, 전장 사본]` 으로 쌓습니다.
   - 전장 사본(`_snap_engine`)에는 유닛마다 `unit_view` + 배지·카드용 값(`SNAP_EXTRA`: lv·name·actionRec·furyBuff·channeling·skillLv …)과 eSpwn·actCount·breached.
   - `unit_attacked` 에는 그 순간의 전술 보너스(`_tactic`: 후방·측면·협공·고지 +%)를 순수 조회로 붙여 둡니다 (아래 '웹과 다른 점').
3. `_process` 가 대기열을 시간에 맞춰 재생 (속도 1x/2x/4x, 0 = 즉시). **`_hold` 가 0 이 아니면(로딩·스토리 대사) 대기열을 멈춤** — 엔진 진행·결과는 그대로.
   | 사건 | 화면 | 기다림 |
   |---|---|---|
   | `turn_start` | 현재 차례 금빛, 차례 번쩍임(아군 파랑·적 빨강), HUD 갱신, **쌓인 스토리 대사 재생** | 적 0.27s / 아군 0.1s |
   | `unit_moved` · fx `move` | 자세는 그대로 두고 0.32s 미끄러지듯 이동, 도움닫기면 포물선 도약 + '도움닫기!' | 0.36s |
   | fx `attack` → `unit_attacked` | 공격 동작(시트, 없으면 키프레임 + 무기 궤적) → 타격 프레임에: 원거리는 픽셀 투사체 발사 → 비행 뒤 임팩트, 근접은 직업별 타격 효과 → 대상 흔들림·피격 동작·피해 숫자·전술 보너스 글자 | 타격+비행 + 0.3s |
   | `unit_killed` | 맞는 순간 죽음 입자 + 화면 흔들림(보스는 크게 + 붉은 번쩍임) + 사라짐 | 0.35s |
   | `unit_healed` · `buff_applied` | 회복 입자·고리·별 / 버프 별 + 유닛 초록 빛 | 0.3s / 0 |
   | fx `float` `messages.critical_hit` | 큰 금빛 글자 + 큰 흔들림 + 금빛 번쩍임 | 0 |
   | `siege_used`(폭탄) · `gate_destroyed` | 폭발 입자 + 흔들림 | 0.35s / 0.3s |
   | `wave_announce` / `wave_announce_end` | 붉은 웨이브 띠 펼침 / 접음 | 0.3s |
   | 새 유닛 (사본) | 등장 동작, 소환수는 보랏빛 고리·별 | 0.6s (wave) |
4. 대기열이 비고 엔진이 입력을 기다리면: 엔진 상태로 화면을 맞춘 뒤(`_sync_from_engine`) 메뉴. 끝났으면 결과 (이겼으면 승리 뒤 대사 먼저).
5. Store 세이브로 시작한 전투는 시작할 때 **Store 의 모든 키**를 넘기고(`BattleScene.store_save` — 시작 화면·다시 하기가 같이 씀),
   끝나면 `eng.c.store` 에서 **넘긴 값과 달라진 키·새 키만** Store 에 쓰고 엔진이 지운 키는 지움 (`_write_back`). 그래서 game_soul·game_mats 등을 덮어쓰지 않음.
   본 스토리 기록 `game_story_seen` 은 전투 중에 바로 Store 에 쓰므로 되돌려 쓰기에서 뺌.

## 스토리 대사 (`story_battle.gd` + `story_view.gd`)

웹 `story-battle.js` 와 같은 시점입니다. 규칙은 동기로 끝나 있으므로 대사는 **재생·입력만** 멈춥니다 (`_hold`).
- 로딩이 끝나면 출전 전 장면 (에피소드 프롤로그 `ep{n}_pro` → `s{id}_pre`, 본 것은 건너뜀) 후 `start` 를 쌓음.
- `turn_start` 재생 때 조건 확인(scan) 후 쌓인 대사 재생 — 웹은 아군 `turn_start` 와 적 행동 직전(`AI.eAI`)에서 flush (둘 다 그 차례 시작).
- `wave_spawn` (첫 배치 뒤) → `wave`, 맞을 때·쓰러질 때 → scan (`boss`: 보스 생존, `danger`: 30% 이상이던 클랜원이 처음 30% 아래, `last`: 증원 끝 + 적 1명). 우선순위 start < boss < wave < danger < last.
- 승리 뒤 결과 화면 전: `s{id}_post` → 에피소드 마지막 스테이지면 에필로그.
- 장면마다 재생할 때 지금 언어의 대본을 다시 고름 (전투 중 언어를 바꿔도).
- 대사 창: 화자 초상화(`image/character/story/`, 없으면 직업 그림), 지휘관은 로스터의 이름·성별, 보스는 전용 그림(없으면 직업 그림을 붉게), 환영은 보랏빛.
  한 글자씩 28ms, 누르기·Space·Enter·→ = 다음(출력 중이면 즉시 완성), Esc·'건너뛰기' = 장면 끝. 끝까지 보거나 건너뛰면 본 것으로 기록.
- 본 장면 기록 `game_story_seen`: Store 세이브 전투만 진짜 Store 에, 디버그·시험은 이번 실행 안에서만 (세이브에 있으면 그 값에서 시작).
- 설정: `cfg.story` = `on`(기본, 속도 0 이면 off) · `off` · `auto`(시험: 프레임마다 저절로 넘김) · `autoplay`(자동 재생 화면 확인: 1.4초마다 넘김). `game_story_dev = sample` 이면 샘플 대본.

## HUD · 정보

- 윗줄: 차례 표시(점이 깜빡임), `STAGE n` + 이름 + 턴, 칩 — 증원 진행 막대(끝나면 초록) · 남은 적 · 돌파(한도 1 전부터 경고) · 환경(툴팁 = `Hazard.describe`) · 조합 버프(툴팁 = `Synergy.describe`) · 연습 모드.
- 이름: 클랜원은 로스터(uid)의 customName → character.names[nameId] → 직업 이름 (결과 화면과 같음, `unit_info.unit_name`).
- 행동 순서: 숨은 적 제외, 다음 행동까지 틱 순서 (현재 = '행동 중', 준비 = ✓). 클랜원 줄을 누르면 카메라 이동, 마우스를 올리면 맵의 그 유닛이 하얗게 빛남. 화면 높이에 맞춰 줄 수 제한.
- 클랜원 카드: (왼쪽 세로 패널로 옮김 — 아래 '왼쪽 클랜원 패널') 초상화 · 이름 · Lv·직업 · HP/자원 막대 · 선택된 카드만 값·ATK/DEF/RNG · 버프 아이콘. 지금 차례 금빛, 행동 끝 흐림. 누르면 맵 링 강조.
- 미니맵: 누르거나 끌면 그 자리로 카메라. 카메라 방향(▲ N)은 오른쪽 아래.
- 툴팁(0.25초 머물면): 유닛 = 이름·Lv·직업·HP·자원·ATK/DEF/RNG/MOV·버프(남은 턴)·지형·노리는 대상 / 칸 = 지형·이동 비용·높이·지형 효과·보물상자·냉기 결계·용암·위협·안개.
- 적 정보 팝업(적을 누르면, 다음 누르기에 닫힘 — HUD 위 누르기 포함): 툴팁 내용 + 스킬 목록(그림·비용) + AI 성향(`AI_PROFILES` style·targetPriority) + 노리는 대상.
- 머리 위 배지: 지형 효과·용암 옆·엄호·방어 태세·경계·광폭·방어 강화·무장해제·정신 집중, 기절/빙결 수(발밑), 소환 남은 턴.
- 공격 예상: 대상 머리 위 상자 — 처치면 💀 그림·금빛, 기사가 대신 맞으면 🛡️·파랑, 아래 줄에 전술(후방·측면·협공·고지 +%)·방어막 ½·숲 회피·여울·연계·반격.
- 설정(왼쪽 아래 톱니): 배경음·효과음 켜기/음량(5단계: Sound 오토로드가 Store 변경을 받아 바로 반영 — godot/README.md '5단계'), 게임 속도 1x·2x·4x, 움직임 줄이기, 언어(6개 — 한국어·English·Español·日本語·简体中文·繁體中文 단추, 단추마다 그 언어 글꼴, 바로 바뀜), 닫기, 항복(확인 창).
  값은 Store `game_settings` 에 웹과 같은 키(`bgmOn`·`bgmVol`·`sfxOn`·`sfxVol`·`language`) + Godot 전용 `playSpeed`·`reduceMotion`.
- 결과: VICTORY/DEFEAT, 결과 글, 연습 모드 안내, 별 3개(새 별 강조 + 조건), 보상(별 보상·골드·첫 클리어·새 클랜원·스킬북·룬·영혼석·장비 — 아이템 그림 + 등급 테두리),
  전사자, 클랜원마다 +EXP·다음 레벨까지 막대·레벨 업. 내용만 스크롤되고 단추 줄은 늘 보임. 장비 이름·등급은 순수 조회 `eng.q.gear_drop_items(전투 시작 eid)`. 단추: 로비로(지금은 시작 화면) · 다시 도전 · 다음 스테이지. 언어를 바꾸면 다시 그림.
- 로딩: 스테이지 이름 · 금빛 막대 · 팁(`battle.loading_tips` 중 하나, 화면 난수). 끝나면 스테이지 소개(EP.x-y + 이름) 잠깐.

## 번역 (Godot 화면 글 gd.*)

(2026-10-18~) 언어 팩 `data/lang/{ko,en,es,ja,zh-CN,zh-TW}.json` 이 원본이고, Godot 화면 글은 그 안의 `"gd"` 아래 `gd.*` 키입니다
(예전 `data/lang_extra/` 를 합침 — 6개 언어 같은 키, `check_foundation` 이 검사). 고친 뒤 `tools/data_tool.gd -- --write` (godot/README.md '데이터 원본').
`gd.fail.*`(명령 실패 안내) · `gd.buff.*`(버프 이름) · `gd.tip.*`(툴팁) · `gd.ai.*`(AI 성향) · `gd.settings.*` · `gd.result.retry`.
언어가 바뀌면(`I18n.language_changed`) 윗줄·행동 순서·카드·메뉴·공격 예상·방향 고르기·팝업·설정·결과를 바로 다시 그립니다.

## 조작 (UI 수준 입구)

마우스·단축키·메뉴 단추가 모두 아래 함수를 거칩니다. 시험도 같은 함수로 조작합니다.

| 함수 | 뜻 | 엔진 명령 |
|---|---|---|
| `ui_action(op)` | 메뉴 단추 move · attack · shove · skill · item · wait · defend · overwatch · undo | undo 는 바로 `{op:"undo"}` |
| `ui_pick_skill(idx)` | 스킬 고르기 — 즉시형이면 바로 명령, 대상형이면 칸 고르기 | `{op:"skill", idx[, x, y]}` |
| `ui_pick_item(kind, idx)` | potion · siege (사다리 effect `climb` 은 `climb`) | `{op, idx, x, y}` |
| `ui_click_cell(x, y)` | 칸 고르기 중 칸 누르기 (치유 대상 칸이면 heal) | move · attack · heal · shove · skill · potion · siege · climb |
| `ui_pick_face(dx, dy)` | 방향 고르기 (0,0 = 지금 방향) | `{op: wait·defend·overwatch, dx, dy}` |
| `ui_cancel()` | (팝업 닫고) 칸·방향·하위 메뉴 → 메뉴, 메뉴에서는 이동 취소 | (undo) |
| `surrender()` | 항복 — 웹 `Renderer.surrender` 처럼 엔진 공개 함수 `transition(BATTLE_END)` + `emit("battle_end", {win:false})`. **입력 대기 중에만** — 연출(적 차례·대사·로딩) 중이면 끝나고 입력을 기다릴 때 항복 (아직 안 보인 결과가 반영되지 않게) | — |

- 마우스: 왼쪽 누르기 = 고르기(메뉴 중 적을 누르면 정보 팝업), 끌기 = 카메라 이동, 휠 = 확대(0.6~3배), 오른쪽 = 취소. 가운데 끌기도 이동. 칸·유닛 위에 머물면 툴팁.
- 키: M 이동 · A 공격 · S 스킬 · I 아이템 · P 밀치기 · D 방어 · O 경계 · W·Space 대기 · 1~9 하위 메뉴 · Esc·Backspace 취소/되돌리기(설정 창이면 닫기) · Q/E 회전 · T 위협 범위 · 화살표 카메라.
- 적 정보 팝업은 다음 누르기에 닫히고 그 누르기도 그대로 처리됨 — 맵이든 HUD(단추·미니맵·설정)든 (`battle_scene._input`, 웹 pointerdown capture 처럼 GUI 보다 먼저 보고 먹지 않음. 팝업·툴팁 안 부품은 마우스를 받지 않음). 툴팁은 다른 칸·유닛으로 옮기면 바로 숨고, 행동 메뉴와 겹치지 않는 자리에.
  로딩·대사·결과 화면 중에는 맵 단축키를 받지 않습니다 (대사 창은 Space·Enter·→·Esc 를 먼저 받음).
- 시험용 상태: `is_awaiting()`, `is_over()`, `awaiting_unit_id()`, `last_result`, `result`, `story_log`(재생한 장면 키), `is_story_playing()`, 신호 `input_ready(id)`·`battle_over(result)`.

## 움직임 줄이기 · 속도

- 속도 1x/2x/4x: 대기열 기다림·동작·입자·투사체·트윈이 모두 같은 배율로 빨라짐 (스토리 글자 속도는 그대로). 0 = 즉시(시험).
- 움직임 줄이기(설정 `reduceMotion` 또는 macOS 손쉬운 사용 '동작 줄이기'): 화면 흔들림·번쩍임·도약·공격 동작(시트·키프레임)·흔들림 이동·메뉴 펼침·결과 등장 동작을 끔. 타이밍(타격 시점)은 그대로 —
  웹 `_reduceMotion()` 처럼 시트 대신 `ATK_MOTIONS` 의 dur×hit 를 씀.

## 실행 · 디버그

- 편집기 F5 → 시작 화면 아래 **전투 시험 (3b 디버그 실행기)**: 스테이지·시드·파티를 고르고 '전투 시작'. 연출 속도는 설정값(`playSpeed`).
- 장면 직접 실행: `Godot --path godot res://scenes/battle/battle.tscn -- --golden legion5_s09 [--autoplay] [--speed 2] [--rotate 1] [--stage 10] [--no-story]`
- 화면 사진: `Godot --path godot --resolution 1280x720 --script res://tests/shots_3b.gd` → `godot/tests/screens/3b_*.png` (git 제외)
  (HUD 전체 · 적 팝업+툴팁 · 공격 예상 · 처치 순간 연출 · 결과 · 전투 전 대사 · 전투 중 대사)
- 새 언어 화면 사진: `Godot --path godot --resolution 1280x720 --script res://tests/shots_lang6.gd` → `godot/tests/screens/lang6_godot_{ja,zh-CN,zh-TW}_{hud,settings,story,story_battle}.png`

## 시험

```bash
# 화면 입구로 황금 기록 22개 재생 — HUD·연출·스토리(auto)를 모두 켠 채 → end(보상·saveAfter)·사건 기록이 황금 기록과 같은지 + 결과 화면 + 재생한 대사 수
Godot --headless --path godot --script res://tests/check_battle_scene.gd
#   끝에 회귀 시험 rotate:boss_s10 (8x 연출·로딩 포함, 유닛이 움직일 때마다 카메라 회전 → 멈춘 유닛이 늘 자기 칸에 있는지)
#   -- --only boss_s10,gear_s15    일부만      -- --speed 4    실제 연출 시간으로      -- --smoke   여러 지도 연기 시험
# UI 연기 시험: 모든 패널·팝업·툴팁·메뉴·연출·대사·결과를 열고 언어를 en→es→ja→zh-CN→zh-TW→ko 로 바꿈(대사·결과 화면도) — Godot 오류(Logger 로 셈) 0 이어야 통과
#   + 진짜 마우스 누르기로 항복(1280×720·1024×600·1920×1080 × ko·es, 1024×600 은 ja·zh-TW 도), 단축키, 팝업 다음 누르기(맵·HUD), 연출 중 항복 미루기, es 메뉴 폭,
#     실제 세이브 전투 뒤 Store 의 다른 키(game_soul·game_mats) 보존·보상 더하기
Godot --headless --path godot --script res://tests/check_battle_ui.gd
# 성능 (창 모드): 유닛 40 · 맵 오브젝트 343 · HUD 전부 + 30프레임마다 연출 + 회전 4번 → 평균·95%·최대·회전 프레임 최대·그리기 CPU
Godot --path godot --script res://tests/perf_battle_scene.gd   [-- --no-hud --no-fx --no-prebuild --hide map,units,fx,pfx --no-rotate]
```
cmd 사건은 `u·op·ok·idx·rng` 만 비교합니다.

## 웹과 다른 점

- **글꼴**: 웹 제목 글꼴 Cinzel 이 없어 숫자·제목도 본문 글꼴(굵게). 본문 글꼴은 언어별 사슬 (`scripts/core/fonts.gd` — ko·en·es KR→JP→SC→TC, ja JP→KR→SC, zh-CN SC→TC→KR, zh-TW TC→SC→KR).
- **필터 흉내**: CSS `drop-shadow`·글로 는 셰이더로 근사. 스토리 초상화의 붉은 물들임·유령 효과도 셰이더 근사 (drop-shadow 빛은 생략).
- **아이콘**: 웹은 이모지를 화면에서 그림으로 바꾸는데(EmojiIcons), 여기서는 그릴 때 바로 그림을 씀. 그림이 없는 이모지는 지움 (예: 행동 메뉴 글자의 ⏸️·↩️). 결과의 📈 은 표(`EMOJI_ICON`)대로 `e_level_up` 그림.
  웹과 같은 표를 쓰므로 웹과 같은 그림이 나옴 (스킬 단추 🔱 → 장창 그림, 별 보상 ⭐ → 웹 표 그대로).
- **전술 보너스 글자**: 웹은 공격자의 `_lastTactic` 을 읽는데, 엔진은 알림 전에 이 값을 지웁니다(규칙 그대로). 그래서 알림을 받는 순간 같은 엔진 상태로
  `tactic_bonus` 를 다시 계산(순수)합니다. 같은 값이지만, 공식 피해 중 일부(적 전사의 처형 일격)는 웹에서는 글자가 없는데 여기서는 뜰 수 있습니다
  (스킬 범위·창벽·스플래시·격투가 반격은 웹처럼 뺌).
- **공격 예상 — 주술사 고양**: 고양(shaman_exalt atk_up)은 공격 횟수가 남은 마지막 공격에서 **피해 계산 전에** 사라지는데, 웹 미리보기는 버프를 넣고 계산해
  실제보다 크게 보여 줍니다. Godot 화면은 `eng.q.preview_attack(a, t, true)` 로 실제처럼 계산합니다 (기본값 false 는 웹과 같은 값 — API 시험).
- **치명타**: 웹은 `messages.critical_hit` 를 평범한 글자로만 띄움 — 여기서는 크게 + 흔들림 + 금빛 번쩍임.
- **소환 등장·보스 처치**: 보랏빛 고리·별 / 큰 흔들림·붉은 번쩍임을 더함 (웹은 spawnPop·보통 흔들림만).
- **항복 확인 창**: 웹은 바로 항복 — 실수 방지로 확인 창을 더함.
- **적 정보 팝업**: 웹 내용에 스킬·AI 성향·노리는 대상을 더함. 툴팁은 Godot 에만 있음 (웹은 title 속성 정도).
- **스테이지 소개**: 로딩 뒤 'EP.x-y + 이름' 띠 (웹은 로딩 화면 제목뿐).
- **속도**: 웹 설정은 늘이기 배율(0.5~2.0) — 여기는 연출 재생 배율 1·2·4 (`playSpeed`, 웹 `speed` 키와 따로).
- **결과 단추**: (4a) 실제 세이브 전투는 '로비로' → Router 로비, 요일 던전은 스테이지 선택 + 요일 던전 창, '다음 스테이지' → 웹 goNextStage (5명이면 바로 전투, 아니면 편성). 시험·디버그 전투는 예전처럼 시작 화면·장면 다시. '다시 도전' 은 Godot 에만 (실제 세이브 요일 던전에서는 입장 횟수 때문에 뺌).
- **행동 순서 줄 수**: 화면 높이에 들어가는 만큼만 (웹은 스크롤).
- **안개 속 나무 가림**·**이동 경로**: 3a 와 같음 (숨은 적 앞 나무는 반투명 안 함, 직선 0.32s 이동).
- **스킬 이름 글자**: 스킬을 쓰면 시전자 위에 스킬 이름 (웹은 기록에만) — 3a 와 같음.

## 아직 없는 것

- 소리(배경음·효과음) — 5단계에서 완료 (godot/README.md "5단계 — PC 출시 준비").
- 성장 화면(상점·성소·학원 등) — 4b.
- 뒷모습 시트(웹도 꺼 둠), 컷아웃 리그(모든 직업이 시트가 있어 안 씀 — 시트가 없는 소환수는 `ATK_MOTIONS` 키프레임).
- 전투 이어하기 화면 (엔진 `save_text`/`load_state` 는 준비됨).


## 지형 높이 표현 (언덕 경사 · 바위 절벽, 화면 전용)

- **언덕 경사**: 이웃이 언덕이 아닌 변은 윗면(고원)이 `HILL_A`(0.2칸) 물러나고 평지 높이까지 비스듬한 경사면으로 내려옴. 이웃도 언덕인 변은 능선처럼 평평하게 이어지고,
  이웃 경사와 높이가 어긋나는 모서리에는 삼각 옆벽을 세움 (`TerrainTex.hill_flags` 비트 → 타일 그림 캐시 키에 포함). 하이라이트·위협 줄무늬·클릭 모양은 경사까지 포함한 `hill_shape` 을 씀.
- **높이 보정**: 유닛 발은 처음부터 칸 높이를 반영(`Iso.foot`). 이동 트윈은 바닥 위치는 직선, 높이는 칸 경계에서 경사 폭 동안만 바뀜(`Iso.slope_h`).
  클릭은 `Iso.iso_hit` 이 높이 있는 칸의 실제 모양(`cell_shape`, 캐시)으로 판정하고 겹치면 앞쪽 칸.
- **바위 절벽**: 화면 높이만 1.3배(`Iso.ROCK_K`, 규칙·데이터 z 는 그대로). 옆면 지층 띠·선·세로 균열·접지 그림자, 윗면은 불투명 밑판 위에 들쭉날쭉한 능선·밝은 마루선·이끼·자갈. 이웃 바위와 맞닿은 변은 매끈하게 이어짐.
  바위 타일·하이라이트 노드는 깊이 `100+3k` 로 그려 뒤쪽 나무·유닛이 윗면 위에 비치지 않음.
- 시험: `tests/check_hill_slope.gd` (클릭 판정·발 위치·경사 비트·이동 높이).


## 왼쪽 클랜원 패널 (레이아웃 개편)

- 아래 가로 카드줄(130px)을 없애고 **왼쪽 세로 패널**로: 맨 위 미니맵 → 그 아래 카드 세로 스택(넘치면 세로 스크롤) → 맨 아래 설정 톱니. 아래 여백은 안내 줄 + 톱니용 64px 뿐 (`BOTTOM_PAD`).
- 일반(PC·태블릿): 너비 158px 카드 — 초상 · 이름 · Lv·직업 · HP/자원 막대 · 버프. **선택된 카드만** 값(HP 129/129)·ATK/DEF/RNG 를 펼침.
- 얇은 모드: 논리 높이 < 600 또는 너비 < 900(= 모바일 가로 pixel8·iphone·low)이면 너비 56px 아이콘형 — 초상 + 막대만 (이름·값은 탭하면 맵 링 + 순서 바 + 툴팁).
- 행동 메뉴(`place_menu`)는 아래 카드 높이 대신 12px 만 비우고, 왼쪽은 패널 오른쪽 끝 + 6px 안으로 (`cards.offset_right`). 윗줄·왼쪽 패널·오른쪽 순서 바 사이 가운데가 맵 영역이고, 카메라는 `_view_off()` 로 그 가운데가 화면 가운데에 오게 보정.
- 터치 높이: 카드·순서 줄·'+N명' 칩은 `Kit.touch_min()` (PC 44, 모바일은 실제 44pt = `Mobile.min_target()`).

## 전투 UI 도입 1~4 (규칙·데이터·엔진 결과는 그대로 — replay_golden 22/22)

유사 게임 UI 조사에서 승인된 네 가지. 다른 게임의 아이콘·연출·이름은 쓰지 않고 우리 UI 키트(`Kit`)로만 그렸음.

1. **행동 순서 바 강화** (`hud_order.gd`, `battle_ui.gd`, `unit_view.gd`)
   - 줄을 탭(마우스 올리면 하이라이트 · 누르면 고정)하면 `set_focus(id)` — 맵 유닛 발밑에 하이라이트 링(아군 파랑·적 빨강, 안쪽 흰 선), 순서 바 그 줄 흰 테두리, 카드 흰 테두리가 한꺼번에. 반대로 맵에서 유닛(아군·적)을 탭해도 같은 `focus_id`. 빈 칸을 탭하면 해제.
   - 카메라: 그 유닛이 화면 가운데 영역 안이면 **안 움직임**(링만), 화면 밖일 때만 부드럽게 이동 (`_ensure_visible`).
   - 팀 테두리: 아군 파랑·적 빨강(현재 차례 금빛), 줄마다 HP·행동력 막대(기존).
   - **턴 구분선 ('다음 턴')**: 엔진의 턴(=라운드) 정의 그대로 — 살아 있는 클랜원(소환수 제외) 전원이 한 번씩 차례를 끝내면 1턴 (`battle_engine._count_turn`, `S.turn`·`S._turnActed`). 이번 턴에 아직 차례를 끝내지 않은 클랜원 중 순서 바에서 가장 뒤 줄(`battle_scene.turn_boundary_index`) 바로 뒤에 선을 그음 = 그 줄 뒤는 다음 턴의 첫 행동 (화면 전용 계산, 엔진 규칙 불변; 이전 정의 '지금 차례 유닛이 다시 돌아오는 시각 뒤'는 엔진 턴과 어긋날 수 있어 교체). 윗줄 'N턴' 은 `S.turn`(진행 중인 턴 번호).
   - 표시 한도(화면 높이)를 넘으면 '+N명' 칩(탭하면 전부 펼침/접기). 강조된 유닛이 숨은 줄이면 칩이 흰 테두리.
2. **이동 취소 + 턴 종료 확인** (`battle_ui.gd`, `battle_scene.gd`)
   - '이동 취소' 단추: 이동 직후(공격·스킬·대기 전) 행동 메뉴 **맨 아래**. 누르면 **이동 직전 엔진 저장(`save_state`)을 `load_state` 로 되돌림** → 위치·방향(`_gdx/_gdy`)·이동 거리(`_movedDist`)·경험치·**난수 상태**·저장소가 이동 전과 완전히 같음.
     (엔진의 기존 `undo` 명령은 웹 그대로라 방향·이동 거리를 이동 전으로 못 돌리고 골든 `firstclear_s02` 가 쓰므로 **고치지 않음**; `ui_action("undo")` 는 저장이 없거나 기록을 켠 시험에서만 그쪽으로 감.)
   - **취소 불가 규칙**: ① 이동 뒤 행동하면 엔진이 이미 불가 ② 이동으로 이전에 안 보이던 적이 시야에 들어오면 `reveal` ③ HP·상태·상자 수가 바뀌면(함정 등) `event` — 단추는 꺼지고 이유 글, Esc 도 안 됨.
   - **차례 종료 확인**: 이 게임은 틱 방식이라 '턴 끝내기' 명령이 없고, 대기·방어 태세·경계(+공격 등)가 그 클랜원의 차례를 끝냄 (이동만으로는 안 끝남). 사람이 단추·W·D·O·Space 로 **이동도 행동도 안 한 채 대기·방어 태세·경계** 를 고르면 확인 창 — '이번 턴에 아직 행동하지 않은 클랜원: N명 (이 클랜원 포함) / 선택한 행동: ○○ — 이동도 공격도 없이 이 클랜원의 차례를 마칩니다.' (N = 이 클랜원 + `S._turnActed` 에 없는 다른 살아 있는 클랜원, `unacted_allies()`). '예' 단추는 고른 행동 이름(`_end_op` 를 기억했다가 그 행동으로 진행), '돌아가기' 는 메뉴로. 한 번 더 눌러야 방향 고르기로. '다시 묻지 않기' 없음. `ui_action(op)` (시험·자동 재생)는 확인 없음.
3. **상성·피해 예측 근거** (`fx_layer.gd`, `battle_scene.gd`, `battle_ui.gd`, `battle_query.gd`)
   - 이 게임 데이터에는 직업 상성·속성·약점 표가 **없음** — 만들지 않고 실제 계산 요소만: 전술 보정(등 뒤·옆·협공·고지, 상한), 여울 취약, 방어막(×0.5), 숲 회피, 회피 상태.
   - 예상 상자 기본 = 숫자 하나 + **▲유리 / －보통 / ▼불리** 마크. 유리 = 전술 보정(+%)·여울, 불리 = 방어막·회피, 둘 다 있거나 없으면 보통. **약점**(여울에 서 있거나 등 뒤)이면 대상 체력바가 번쩍임.
   - 아래 가운데 **접힘 패널**(`▸ 계산 내역`, 44pt 단추): 펼치면 대상마다 공격력 · 방어력 · 기본 피해 · 격노/고양/마나 쇄도 · 전술 보정 · 고지 사거리 · 지형 · 여울 · 방어막 · 숲 회피 · 지원 사격 · 반격 · 예상 피해. 펼치면 예상 상자에도 계산 한 줄. 값은 `preview_attack`(기존) + `preview_parts`(새 순수 조회 — `combat._calc_parts`·`tactic_bonus` 를 읽기만)로 **식은 안 바뀜**.
4. **적별 범위** (`battle_map.gd`, `battle_scene.gd`, `battle_query.enemy_range`)
   - 적을 탭하면 그 적의 이동 가능 칸(파랑)과 이동 뒤 공격 가능 칸(빨강, 이동·공격 둘 다는 파랑 + 빨간 테두리) — `threat_cells` 와 같은 규칙을 한 명에게만(합집합 = 전체 위협, API 시험). 같은 적을 다시 탭하면 해제, 다른 적을 탭하면 교체(한 번에 한 명), 켤 때만 정보 팝업.
   - **우선순위**: ① 아군이 이동·공격·방향을 고르는 중(target·face)에는 그리지 않음(선택은 유지, 메뉴로 돌아오면 다시) ② 전체 위협('위협' 단추)은 별도 층 — 둘 다 켤 수 있고 개별 범위가 위에 더 진하게 ③ 명령을 내리면(상태 변화) 해제 ④ 기절·빙결은 '지금 행동할 수 없음', 공격 안 하는 유닛은 '공격하지 않음' 안내.
- 시험: `tests/check_battle_ui_adopt.gd` (엔진 이동 취소 동일성 80회 · 상호 강조 · +N명 · 구분선 · 확인 흐름 · 취소 불가 · 접힘 패널 값 = query · 적 범위 · 우선순위 · pixel8 터치), `tests/check_battle_api.gd` (새 조회 순수성·일치). 화면 사진: `tests/shots_adopt.gd`.
