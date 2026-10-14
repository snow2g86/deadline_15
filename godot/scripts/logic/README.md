# 전투·성장 규칙 (GDScript) — 2b

웹판 전투 규칙을 화면·노드와 무관한 GDScript 로 옮긴 것입니다. 황금 기록 21개(`godot/tests/golden/`)를
**사건 하나·난수 호출 하나까지** 똑같이 재현합니다 (`tests/replay_golden.gd`).

- 모든 파일은 `RefCounted` 또는 정적 함수. 씬·노드·오토로드에 기대지 않습니다 (데이터는 `ctx.gd` 로 넘겨받음).
- 서로는 `preload` 상수로 찾습니다 (`class_name` 없음 — `--script` 로 도는 시험에서 전역 클래스 캐시 없이도 컴파일되게).
- 무작위는 전부 `rng.gd`(mulberry32) 하나. 실제 시간·프레임은 쓰지 않고, 웹의 `setTimeout` 은 가상 시계 대기열(`later`)입니다.

## 파일 지도 (웹 → GDScript)

| 웹 | GDScript | 내용 |
|---|---|---|
| (Math.round·toFixed·sort·참거짓) | `js.gd` | JS 의미 그대로 계산: `round_js`(.5 → +∞), `to_fixed_num`(정확한 10진 반올림·동점은 큰 쪽), `stable_sort`, `truthy`(빈 배열·사전도 참), `deep`(JSON 복사), `mh` |
| `tools/battle-sim/env.js` mulberry32 | `rng.gd` | `next(tag)` = Math.random(), `calls` = 호출 수, `log_enabled` 면 호출마다 태그 기록 |
| (전역 데이터·Math.random·localStorage·Date) | `ctx.gd` | 규칙 공통 환경: `D`(웹 전역 이름 → 값), `rng`, `store`, 가상 시계 `now_ms` |
| `js/common/store.js` (localStorage) | `save_store.gd` | 키 → JSON 값. 꺼낼 때·넣을 때 복사 (웹의 JSON 문자열 저장과 같은 의미), 숫자 키 규칙은 `core/json_norm.gd` |
| `js/common/storage.js` · `character.js` · `soul.js`, `equip.js` 인벤토리·Mats | `profile.gd` | 세이브·골드·별점·로스터(`get_roster` 보정 포함)·`gain_exp`·사망 표시·영혼석·재료 |
| `js/logic/gear.js` (Gear) · `js/logic/equip.js` · `hazards.js` Rune | `gear.gd` | 장비 생성(`generate_equip`·`gacha_pull`·`make_legend`·`make_set_piece`·`roll`), `calc_equip_bonus`, 룬 |
| `js/logic/hazards.js` Hazard | `hazards.gd` | 환경 디버프 적용·`dot_pct`·냉기 결계 배치(`place_safe`) |
| `js/logic/synergy.js` | `synergy.gd` | 조합 버프 (`SYNERGY_ROLE` 조건 함수는 `_role_test` 로 다시 씀) |
| `js/logic/stages.js` · `js/common/daily.js` | `stage_rules.gd` | `stage_level`(float), 적 레벨·스킬 레벨, 요일 던전 스테이지 |
| `js/battle/state.js` · `event.js` · `turn.js` · `boot.js`(initBattle) + 화면 모듈 속 규칙 | `battle/battle_engine.gd` | 엔진: GameStore(`S`)·FSM·EventBus(+구독 순서)·대기열·기록·TurnManager·BattleInit·입력 |
| `js/battle/grid.js` · `unit.js` · `constants.js`(toBattleStats) | `battle/grid_units.gd` | 지형 생성·길찾기(`mv_cells`·`e_mv_cells`·도움닫기)·사거리·함정·창벽·유닛 생성·엄호·투사체 차단·전술 보너스·회피·밀치기·지원 공격 |
| `js/battle/buff.js` · `js/skills/_common.js` · `hazards.js` EnchantFX·Chest · `shaman.js` 틱 | `battle/combat.gd` | BuffSystem·`calc_dmg`·`apply_dmg_to_ally`(희생·고통 분담·강인한)·분노 패시브·공격 마법부여·보물상자·저주/독안개 틱 |
| `js/logic/gear.js` GearFX | `battle/gear_fx.gd` | 장비 전투 효과 + EventBus 구독 |
| `js/battle/action.js` (+ battle-sim `policy.js` exec) | `battle/battle_action.gd` | ActionManager(`cell_ck` 상태 기계, 이동·공격·회복·스킬·물약·공성·밀치기·방향·이동 취소) + 명령 실행 `exec_cmd` |
| `js/battle/ai.js` | `battle/battle_ai.gd` | 적 AI (동기 함수로 — 아래 '시간 모델') |
| `js/skills/*.js` · `_registry.js` | `battle/battle_skills.gd` | 41개 능동 스킬 `target`/`exec`, `_skill_done`·`_skill_refund` |
| `js/battle/end.js` | `battle/battle_end.gd` | 전투 끝 보상·첫 클리어 신규 클랜원·영혼석·드랍·요일 던전 |

옮기지 않은 웹 파일: 화면(`render`·`vfx`·`rig`·`motion`·`audio`·`pixelfx`·`terrain-tex`·`props`·`story-battle`), 번역·모달. 그 안에 섞여 있던 규칙은 엔진에 들어 있습니다 (아래).

## 엔진 API (3단계 화면용)

```gdscript
const Ctx := preload("res://scripts/logic/ctx.gd")
const BattleEngine := preload("res://scripts/logic/battle/battle_engine.gd")

var eng := BattleEngine.new(Ctx.globals_from_db(DataDB), seed)   # seed: 전투 난수 시드 (int)
var setup := eng.start({
	"save": {"game_save": ..., "game_roster": ..., "game_parties": ..., "game_inventory": ...},   # Store 의 값 (JSON 해석된 것)
	"stage": {"id": 5},            # 또는 {"daily": {"cls": "mage", "tier": 1}}, 선택 "override": {…}
	"practice": false,
	"inject": [],                  # 시험용 상태 주입 ({unit:id, set:{…}} / {store:{GameStore 키: 값}})
	"maxRounds": 0,                # 0 = 상한 없음 (시뮬레이터는 120 → 넘으면 'stalled')
	# "party": [2,3,4,5,6]        # 없으면 활성 파티 슬롯
})
eng.begin()                        # 행동 예고 ① + 첫 TurnManager.nextAction
var st := eng.run()                # "input"(클랜원 입력 대기) | "stopped"(전투 끝·라운드 상한) | "idle" | "max_steps"
while st == "input":
	var u: Dictionary = eng.awaiting_unit()          # 지금 차례인 클랜원 (S.curUnit)
	eng.command({"op": "move", "x": 3, "y": 9})       # 명령 하나 → 다시 run()
	st = eng.run()
var result := eng.finish(st)       # { result, reason, rounds, rewards, saveAfter(저장소 전체) … } — 황금 기록 end 형식
eng.dispose()                      # 순환 참조 정리
```

- 명령 (`command`/`input_provider` 공통, 웹 화면 버튼과 같은 입구 — tests/golden/README.md '아군 명령'):
  `move{x,y}` · `attack{x,y}` · `heal{x,y}` · `shove{x,y}` · `skill{idx,x,y}`(idx = `get_unit_skills(u)` 순서, 즉시형은 x,y 무시) ·
  `wait|defend|overwatch{dx,dy}`(0,0 = 지금 방향) · `siege|climb{idx,x,y}`(idx = `S._siegeItems` 번호) · `potion{idx,x,y}` · `undo`.
  실패한 명령(`ok:false`)은 상태만 메뉴로 돌아가고 같은 클랜원이 계속 입력을 기다립니다. 이동·등반·이동 취소 뒤에도 같은 차례가 이어집니다.
- `input_provider: Callable(u) -> Dictionary|null` 를 주면 엔진이 차례마다 직접 묻습니다 (재생 시험·AI 대리 조작용). null 이면 `command()` 를 기다림.
- 화면이 미리 보여 줄 값(부작용 없음): `eng.gu.mv_cells(u)`, `eng.gu.atk_cells(u)`, `eng.am._set_targets(u)` 뒤 `S.atkT/healT/coverT/blockT`,
  `eng.gu.shove_targets(u)`·`shove_plan(a,t)`, `eng.gu.tactic_bonus(a,t)`, `eng.gu.cover_of`·`intercept_of`, `eng.get_unit_skills(u)`, `eng.sk.target(id,u,sk)`(*소환·소환 강화는 안내 글자 사건을 냄*), `eng.is_stealthed(u)`, `eng.cb.chest_at(x,y)`.
  ⚠ `eng.calc_dmg` 는 미리보기에 쓰지 마세요 — 난수(치명타)를 소모합니다 (웹도 같음).
- 상태: `eng.S` (웹 GameStore 와 같은 키: `units, ter, turn, actCount, eQ, eSpwn, gateHP, wallHP, traps, poisonMists, chests, safeZones, battleExp, _battlePotions, _siegeItems, curUnit, sel …`),
  `eng.fsm`(BattleState 문자열), `eng.magic_walls`(그랜드 월), 각 유닛의 `_intent`(적의 행동 예고 대상 id).
  유닛은 Dictionary (웹 객체와 같은 키, `id·uid·x·y·lv` 는 int, 나머지 숫자는 float).
- 신호:
  - `bus_event(name, data)` — 웹 EventBus 알림 그대로 (`turn_start`, `unit_moved{unit,from,to}`, `unit_attacked{attacker,target,damage,isCounter…}`, `unit_killed`, `unit_healed`, `buff_applied/removed`, `skill_used`, `wave_spawn`, `siege_used`, `gate_attacked`, `breach`, `battle_end{win,message}` …). 데이터의 유닛은 Dictionary 참조.
  - `fx_event(kind, data)` — 연출 힌트 (규칙 영향 없음): `float{x,y,text}`(웹 Fx.float — text 는 번역 키 또는 숫자 글자), `face{id,dx,dy}`, `move{id,x,y}`(순간 이동·밀치기 등 unit_moved 없는 이동), `attack{a,t}`, `chest_open`, `redraw_units`, `redraw_terrain`.
  - 웹은 `Fx.later`·공격 동작 시간만큼 기다리지만 엔진은 기다리지 않습니다. 화면은 신호를 줄 세워 재생하면 됩니다 (사건 순서는 웹과 같음).
- 기록: `eng.trace` (황금 기록 사건 형식). `eng.record_enabled = false` 로 끌 수 있음 (게임에서는 꺼도 규칙 결과는 같음).
- 저장: 전투 중 바뀐 저장값(골드·상자·경험치·로스터·영혼석 …)은 `eng.c.store` 에 있습니다. 끝나면 `eng.c.store.dump()` 를 오토로드 `Store` 로 되돌려 쓰세요.

## 시간 모델 (웹 async → 동기 + 대기열)

- 웹 `setTimeout(fn, ms)` → `later(ms, fn)`: 가상 시각·등록 순서로 하나씩 (battle-sim 의 가상 시계와 같은 규칙). 지연 값은 순서만 정합니다.
  (`nextAction` 의 선택 350ms·적 270ms·기절 500ms·웨이브 600ms, 공격의 지원 380·반격 420(+400)·정리 650/500(+450), 이동 취소 340ms, 회복 300ms, 장비 소환수 강화 0ms …)
- 적 AI 의 `await sl()` 은 동기 함수 안의 **멈춤 지점** `E._sl()` 로 옮겼습니다. 적 차례 동안 대기열에 다른 작업이 없으므로(엔진이 확인 — 어기면 경고) 순서가 같고,
  웹처럼 그 지점에서 전투가 이미 끝났으면(`battle_end` 뒤) 그 뒤 코드는 실행하지 않습니다 (`_aborted`).
  반대로 멈춤 지점 없이 이어지는 코드(예: 경계 사격으로 마지막 적이 쓰러진 뒤 `endUnitTurn`)는 웹처럼 실행됩니다.
- `Fx.later` 는 연출을 끈 웹과 같이 즉시 실행. 연출 시간(`atkHitDelay`) = 0.

## 일부러 그대로 둔 웹 특이점

황금 기록과 같아야 하므로 고치지 않았습니다 (tests/golden/README.md '2b 가 그대로 따라야 할 규칙 특이점' 전부 포함).

- 난수: 새 버프 id 1회(값 안 씀)·적 생성 3회(성별·공성 종류·공성 id)·`&&` 단락 평가·후보 칸마다 `_tacticScore` 1회·벽 이웃마다 등반 판정·장비 eid 1회.
- `Math.round` 는 `.5 → +∞`, `toFixed` 는 정확한 10진 값 기준. JS 나눗셈은 실수(`stage_level` 을 float 로 돌려줌 — `Hazard.dotPct` 의 `/100`).
- 안정 정렬 동점 처리(다음 유닛·대상 고르기·지원자·고통 분담 기사·`_findAdj`), BFS 큐 순서·중복 푸시, `vis` 삽입 순서(도움닫기), 스킬 칸 목록의 x 바깥·y 안쪽 순서.
- JS 객체의 정수 키는 오름차순 (`_turnActed` → 스냅샷 `acted`).
- 화면 모듈에 섞인 규칙: 이동 알림(`fx_move_unit`)·바라보는 방향(`fx_face_dir`, 정규화 안 함)·피격 시 방향·이동 시 보물상자 열기·처음 그릴 때 초기 방향(`fx_redraw_units`)·전투 끝 보상과 결과 화면의 첫 `getChar`(첫 클리어 신규 클랜원 `rollActionRec` 난수 1회)·쓰러진 클랜원 allyPos (99,99).
- 행동 예고(`plan_rule`): 전투 시작·`selU` 직후·`wave_spawn` 직후·상자 열린 직후·이동 취소 직후, AI_TURN/BATTLE_END 면 건너뜀, 적 차례 시작 때는 다시 계산 안 함.
  (현재 황금 기록으로는 ④상자·⑤이동 취소 시점의 재계산을 빼도 결과가 같습니다 — 명세대로 구현만 되어 있음)
- 돌파 패배는 `chk_end` 에서만. 적 공성 아이템 쿨다운 3 은 줄지 않음(적마다 1회). 우회로(detour)는 효과 없음. 사제 정화는 옛 필드만 봄. 처형은 강인한·장비 흡수를 거치지 않음.
- 전투 중 인벤토리 번호 보정은 2a 에서 고친 웹 기준 (`_inv_removed` 가 두 목록 모두 보정).
- `S.cleared`·`S.safeZones` 는 웹의 Set 대신 삽입 순서를 지키는 Array.

## 웹과 다른 점 (재현과 무관)

- 패시브 스킬(비용 없음)을 `skill` 명령으로 고르면 웹은 자원이 NaN 이 되지만 여기서는 비용 0 으로 처리합니다 (정상 플레이·기록에서는 일어나지 않음).
- 이름·성별 표시값: 유닛 `name` 은 직업 id(적·소환수)나 저장 이름. 번역은 화면 몫입니다.
- 순수 연출 호출(`Fx.burst/shake/sfx`, 메뉴 표시)은 없앴고, 규칙 결과를 알려 주는 것만 `fx_event` 로 냅니다.

## 아직 옮기지 않은 것 (영향)

- **이어하기**(`resumeBattle`·`saveBattle`/`loadBattle`): 전투 중 저장·복원. 화면 단계에서 `S` 직렬화로 붙일 예정 — 규칙 재현에는 영향 없음.
- **장비 구버전 전환**(`Gear.migrate`, `gv` 없는 장비): 인벤토리를 읽을 때 웹은 옛 장비를 새 구조로 바꾸며 난수를 씁니다. 지금 세이브는 모두 `gv:2` 라 생략 — 옛 웹 세이브를 들여올 때만 필요.
- 상점·강화·성소·뽑기 화면 규칙(`enhanceItem`·`repairItem`·`dismantleItem`·`Rune.apply` 등)은 전투 밖이라 아직 없음 (4단계 성장 화면 때).
- 스토리 대사(`story-battle.js`)는 연출 — 규칙 영향 없음.
- 황금 기록이 닿지 않는 경로(전설 장비 뽑기·보스 전설 드랍·스킬북 드랍·요일 던전 세트/지옥 전설·대부분의 GearFX 효과·적용 안 된 디버프 물약)는 웹 코드를 줄 단위로 옮겼지만 기록 비교로 확인되지는 않았습니다.

## 시험

```bash
# 2b 재생 시험 (21개, 약 4초) — 모두 같으면 RESULT: PASS (21/21), 종료 코드 0
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/replay_golden.gd
#  -- --only boss_s10,gear_s15   일부만
#  -- --external                 input_provider 없이 command() 입구로 재생 (3단계 API 시험)
#  -- --rng-log                  user://rng-log/<이름>.txt 에 '번호<TAB>웹 함수' → node tools/battle-sim.js --only <이름> --rng-log 와 나란히 비교
```

불일치가 나면 사건 번호·종류·난수 번호, 첫 차이의 경로(예: `events[197].dmg: 30 ≠ 31`), 바로 앞 사건 3개, 기대/실제 전체를 출력합니다.
웹 규칙을 바꿔 황금 기록을 다시 만들었다면(`node tools/battle-sim.js`) 이 시험이 바뀐 곳을 가리킵니다.
