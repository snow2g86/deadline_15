# 전투 황금 기록 (golden battle traces)

**고정된 기준입니다 (2026-10-18~).** 웹판 전투 규칙을 화면 없이·결정적으로 돌려 남긴 마지막 정답 22개이고,
Godot 전투 엔진(`scripts/logic/battle/`)은 같은 세이브·같은 시드·같은 아군 명령으로 이 기록을 **사건 하나, 난수 호출 하나까지** 똑같이 재현해야 합니다.

- **데이터**: 기록은 그때 데이터에서만 맞으므로 늘 **기준 데이터 `godot/tests/baseline/data/`** 로 재생합니다 (`tests/baseline_data.gd`). `godot/data` 를 고쳐도 이 기록은 그대로입니다.
- **잠금**: 파일마다 sha1 이 `godot/tests/baseline/LOCK.json` 에 있고 `tools/data_tool.gd`·`check_foundation` 이 확인합니다 (이 README 는 잠그지 않음).
- **이 기록을 쓰는 시험**: `replay_golden`(규칙 · `--resume` 저장·복원) · `check_battle_api` · `check_battle_scene`(화면 입구) · `check_battle_ui` · `check_outer_4b1/4b2`(명령 재생) · 장면 직접 실행 `--golden 이름`.
- **만든 도구(보관)**: `tools/legacy-web/battle-sim.js` (+ `battle-sim/` 의 `env.js` · `rules-shim.js` · `policy.js` · `scenarios.js` · `coverage.js`) — 웹 파일을 Node vm 에 그대로 적재해 만들었습니다.
  기록 중 찾은 웹 버그 하나(전투 중 인벤토리 번호 어긋남)는 `js/battle/action.js` 에서 고친 뒤 만들었습니다 (아래 '고친 웹 버그').
  웹판 파일이 남아 있는 동안은 `node tools/legacy-web/battle-sim.js --check` 로 웹 코드가 아직 같은 기록을 내는지, `--only 이름 --rng-log` 로 난수 위치를 볼 수 있습니다 (godot 쪽 기록은 덮어쓰지 않음).

## 실행 (Godot)

```bash
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path godot --script res://tests/replay_golden.gd                          # 22개 비교 (기준 데이터)
$G --headless --path godot --script res://tests/replay_golden.gd -- --resume              # 모든 입력 대기마다 저장·복원하며
$G --headless --path godot --script res://tests/replay_golden.gd -- --only boss_s10 --rng-log   # 난수 호출마다 '번호<TAB>태그' → user://rng-log/
$G --headless --path godot --script res://tests/replay_golden.gd -- --live                # 영향 보고: 지금 godot/data 로 (실패해도 이상한 게 아님)
$G --headless --path godot --script res://tests/replay_golden.gd -- --record [--only 이름]   # Godot 엔진으로 기록 다시 쓰기 (아래)
```

## 기록을 바꿔야 할 때

- **데이터만 바꿈**: 기록은 그대로 (기준 데이터로 재생하므로). 영향이 궁금하면 `--live`.
- **Godot 전투 규칙을 일부러 바꿈** (버그 고침 등): `--record` → Godot 엔진이 기록된 세이브·시드·주입·명령으로 다시 돌려 같은 모양(한 줄에 사건 하나)으로 씁니다.
  지금 기록과 같은 항목은 글자 그대로 두므로(비교에서 빼는 가상 시각·시계 기반 id 포함) 바뀐 사건만 diff 에 나옵니다. 아무것도 안 바꾸고 돌리면 22개 모두 '같음'.
  → `git diff godot/tests/golden` 사람이 검토 → `tools/data_tool.gd -- --relock "이유"` → 커밋.
- **기준 데이터를 지금 데이터로 옮김**: `tools/data_tool.gd -- --rebase "이유"` (복사 → `--record` → 잠금, 실패하면 되돌림). `--record --live` 는 기록과 기준 데이터가 어긋나므로 거부됩니다.
- 기록된 명령이 더는 맞지 않으면(전투 흐름이 달라져 다른 유닛이 입력을 기다림) 그 시나리오는 쓰지 않고 실패 — 시나리오를 새로 짜야 합니다.
  아군 시험 정책의 Godot 판은 아직 없으므로 `tools/legacy-web/battle-sim/policy.js`·`scenarios.js` 를 본보기로.

아래 '시나리오'부터 끝까지는 **기록의 명세와 만든 과정**입니다 (기록이 기대는 웹 함수·실행 모델·형식). 도구 경로는 `tools/legacy-web/` 아래로 옮겨졌습니다.

## 파일

| 파일 | 내용 |
|---|---|
| `<시나리오>.json` | 기록 하나 (아래 형식) |
| `index.json` | 시나리오 목록: `name, seed, stage, result, rounds, actions(행동 수), events(사건 수), rngCalls(난수 호출 수), sha1(파일)` |

## 시나리오 (tools/legacy-web/battle-sim/scenarios.js)

| 이름 | 스테이지 | 결과 | 확인하려는 것 |
|---|---|---|---|
| balanced_s05 | 5 밀림 방어전 | 승 | 균형 진형+만능 부대, 독 지속 피해, 숲 회피, 여울, 성문. 사제 정화 대상 주입(기사 `disarmed: 3`) |
| legion5_s09 | 9 화산 공격전 | 승 | 외인부대 5인, 용암 화상, 화상 피해, 냉기 결계, 소환·저주·함정·창벽 |
| assassins_s06 | 6 밀림 공격전 | 승 | 암살자 셋(직업 셋 조합), 은신 겹침 암살·습격·연막 |
| mono_warrior_s03 | 3 협곡 방어전 | 승 | 전사 단일 조합(공격×2·방어×0.5)+돌격대, 돌풍(사거리 -1) |
| knights_s11 | 11 얼음 방어전 | 승 | 기사 셋+철옹성, 밀치기(정책 2차례마다)·포획 vs 적 기사(넉백 저항 70%), 투사체 차단, 경계 사격 |
| boss_s10 | 10 화산 (보스) | 승 | 보스 스테이지, 보스 호위 배치, 결계 |
| daily_mage_normal | 요일 던전 마법사·보통 | 승 | `Daily.buildStage('mage', 1)`, 조각 보상 |
| abyss_s19 | 19 지옥 공격전 | 승 | 지옥불, 냉기 결계 3라운드마다 이동(2회), 소환 둘·영혼 폭발·영적 유대 |
| loss_s30 | 30 | **패** | 1레벨 노비스 단일 조합 전멸 |
| stall_passive_s02 | 2 | **stalled** | 방어 태세만 하는 정책 + 라운드 상한 6 → 교착 끝 |
| siege_items_s13 | 13 요새 공격전 | 승 | 아군 공성 아이템(다리·폭탄·사다리)·전투 물약(회복·자원·공격 강화), 공병 셋(굴착·함정·폭파), 함정 밟힘 |
| gear_s15 | 15 폐허 | 승 | 전설 장비·직업 세트(공명), 저주 마법부여 면역. 공격 마법부여 6종(화염·서리·독·흡혈·번개·파쇄)을 일반 공격만 하는(`attackOnly`) 기사 하나에 모아 실제 발동(화상·독 지속 피해, 빙결 2회, 흡혈, 피해 보정) |
| practice_s04 | 4 협곡 | 승 | 연습 모드(골드 60%), 포격진, 경계 위주 정책 |
| mono_archer_s07 | 7 사막 | 승 | 궁수 단일 조합(사거리 +1)+포격진, 열기(이동 -1), 언덕 사거리 |
| firstclear_s02 | 2 평지 방어전 | 승 | 첫 클리어 보상(신규 클랜원·별점 → 결과 화면 로스터 보정 난수), 독안개, 창벽, **이동 취소**(`undoEvery: 2`) |
| swamp_s21 | 21 늪 방어전 | 승 | 소환사 둘·주술사 둘, 저주 틱, 영적 유대 |
| loss_boss_s45 | 45 지옥 (보스) | **패** | 보스전 패배 |
| drill_s35 | 35 요새 | 승 | 비싼 스킬 돌려 쓰기 (무투가·공병 시작 자원 100 주입) |
| drill_s28 | 28 지옥 | 승 | 같은 목적 (응급처치·희생·치명적인 일격·폭파) |
| gate_breach_s01 | 1 평지 방어전 | **패**(돌파) | 암살자 5명 은신 버프 주입 + 해자 함정 주입, 제자리 정책(`hold: 'breach'`) → 함정 밟힘·성문 공격·파괴·성벽 오르기·돌파 패배 |
| edge_inject_s11 | 11 얼음 방어전 | 승 | 주입으로만 닿는 규칙: 기사 강인한(HP 1 주입 → HP 0 방지 1회), 방어막 버프(`shield_active`), FURY_BUFF 버프(`fury_triggered`), 적 전사 처형(ai.js tryUseSkill) |
| legacy_gear_s08 | 8 | 승 | 장비 개편 전 세이브(`gv` 없는 장비, 옛 무기 이름, +2·+3·+4·+7·+9·+10): 전투 준비의 첫 `loadInventory` 가 `Gear.migrate`·`rollEnhanceOpt` 로 옵션을 **전투 난수로** 다시 굴림 (시나리오 `legacy` 명세) |

상태 주입(`inject`)은 일반 플레이로 만들 수 없거나 너무 드문 상태를 시험하려고 쓴 것이며 모두 `setup.inject` 에 남습니다 (balanced_s05·drill_s35·drill_s28·gate_breach_s01·edge_inject_s11).

`node tools/legacy-web/battle-sim/coverage.js` 로 시나리오마다 실제로 일어난 일을 셀 수 있습니다. 12직업의 **모든 능동 스킬(기본 14 + 습득형 27 = 41개)을 아군이 한 번 이상 사용**합니다.

## 실행 모델 (2b 가 똑같이 따라야 하는 것)

### 적재

`battle.html` 의 `<script>` 순서대로 Node `vm` 에 적재 (맨 앞 칸 `const/let` → `var`, `tools/export-godot-data.js` 와 같은 방식).
빼는 파일: `js/common/i18n.js`(번역 — `t(key)` 는 키를 그대로 돌려주는 흉내), `modal.js`, `js/common/render.js`, `item-icons.js`, `emoji-icons.js`, `js/common/story.js`, `js/battle/story-battle.js` (모두 화면·대사, 규칙 없음).
화면 모듈(`Renderer, VFX, Audio, Rig, PixelFX, TerrainTex, Props`)은 객체 모양(boot.js `G` 프록시의 이름 찾기 순서)을 위해 적재한 뒤 **함수를 전부 빈 함수로** 바꿉니다. 예외는 아래 '화면 모듈에 섞인 규칙'.
`Fx.enabled = false` → `Fx.later(fn)` 은 **즉시 실행**, `Fx.atkHitDelay()` 는 **0**, `Fx.playAtkMotion()` 은 `Promise.resolve()`(→ setTimeout 지연 NaN → 0).

### 시간

- `setTimeout` 은 가상 시계 대기열: `(실행 시각, 등록 순서)` 가 작은 것부터 하나씩. 지연이 숫자가 아니거나 음수면 0 (브라우저와 같음). 콜백 하나를 실행할 때마다 마이크로태스크(`await`)를 모두 비운 뒤 다음 콜백.
- `performance.now()` = 가상 시각, `Date` = 2026-10-14T00:00:00Z + 가상 시각 (규칙 결과에는 영향 없음 — 장비 eid·룬 rid 같은 저장 값에만 쓰임).
- `requestAnimationFrame` 은 쓰지 않음 (화면 전용). 행동 예고는 아래 '행동 예고 규칙'으로 정함.
- `GameStore._sett.speed = 1` (sl(ms) 는 ms 그대로).
- 기록의 `virtualMs` 는 참고값입니다 (2b 가 맞출 필요 없음). 맞춰야 하는 것은 **사건 순서**입니다.
- 실제 게임(연출 켬)에서는 `Fx.later`·`atkHitDelay` 가 수백 ms 지연되지만, 한 유닛의 처리 안에서 일어나는 일의 **순서**는 같습니다. 그 지연 동안 규칙에 영향을 주는 것은 화면 프레임에서 도는 행동 예고 계산뿐이며, 그 시점은 아래 '행동 예고 규칙'이 실제 게임의 프레임 동작을 따라 정합니다 (검수자가 브라우저 재생으로 확인한 규칙).

### 화면 모듈에 섞인 규칙 (`tools/legacy-web/battle-sim/rules-shim.js`) ★

연출을 끄면 함께 사라지는 규칙이 화면 모듈 안에 있습니다. 실제 게임과 같도록 시뮬레이터가 되살리며, **2b 는 이것들을 규칙으로 구현해야 합니다.**

1. `Fx.moveUnit(u,x,y)` → `VFX._mvU`: `u.x,u.y` 변경, 아군이면 `allyPos[u.id]`, `'unit_moved' {unit, from, to}` 알림. (스킬은 `G._mvU` 로 직접 부름 → 진짜 `VFX._mvU` 를 그대로 둠)
2. `Fx.faceDir(id,dx,dy)` → `VFX.faceDir`: `dx,dy` 가 둘 다 0 이 아니면 `_gdx=dx, _gdy=dy` (길이 정규화 안 함 — 원거리면 (0,-3) 처럼 큰 값이 그대로 들어감).
3. `Fx.attack(a,t)` → `VFX.vfxAtk` 의 첫 줄: `faceDir(a, t.x-a.x, t.y-a.y)`.
4. `'unit_attacked'` 구독: `isSplash` 가 아니면 `faceDir(attacker → target)`. 그리고 `attacker._lastTactic = null`.
5. `'unit_moved'` 구독 (GearFX 구독 **다음**에 등록됨): `faceDir(unit, to-from)`; 이어서 `unit` 이 클랜원이고 소환수가 아니며 `Chest.at(S,to.x,to.y)` 가 있으면 `Chest.open(S, c, unit)` (난수 사용), `S._chestLog` 에 종류 추가. (그 250ms 뒤의 `Renderer.rUnits()` 는 새 유닛이 없어 규칙 영향 없음)
6. `Renderer.rUnits` (= `Fx.redrawUnits`, `G.rUnits`): 살아 있는 유닛 중 **처음 그려지는** 유닛에 대해 아군이면 `allyPos[id]={x,y}`, 그리고 `_gdx,_gdy` 가 둘 다 `undefined` 면 초기 방향 적 `(0,1)` / 아군 `(0,-1)`.
   → 시작 유닛은 `initBattle` 끝의 `Renderer.rUnits()`, 증원은 `nextAction` 의 `Fx.redrawUnits()`, 소환수는 `_skillDone` 의 `Fx.redrawUnits()` 때 방향이 생깁니다.
7. `'battle_end'` 구독 (Renderer.init 에서 등록) → `Renderer.showRes` → `BattleEnd.onBattleEnd(win)` (보상·경험치·별점·드랍, 난수 사용).
   이어서 결과 화면이 경험치 목록(`S._expResults` 가 있으면)을 그리며 `getChar` → `getRoster` 를 부르는데, `getRoster` 의 보정이 **첫 클리어 신규 클랜원**(end.js 가 `pot.actionRec`·`actionRec` 없이 만듦)에 `rollActionRec()` **난수 1회** + `actionRec` 계산 + 저장을 합니다. 시뮬레이터는 첫 `getChar` 한 번으로 재현 (boss_s10·firstclear_s02·assassins_s06 에서 `battle_end` 뒤 난수 +1). 전투 뒤 저장소 전체는 `end.saveAfter`.
8. `Renderer.rUnits` 의 쓰러진 클랜원 `allyPos[id] = {x:99, y:99}` (render.js 344-346, 이어하기 저장용 — 규칙 결과에는 영향 없음).

### 행동 예고 규칙 (`AI.planIntents`) ★

AI 는 적마다 `_intent`(노릴 클랜원)를 `_tryAttack` 의 공격 대상 우선과 `_tacticScore` 의 +30 에 씁니다. 실제 게임은 이것을 화면에서 계산합니다: `Renderer.rUnits()` 가 불리면 다음 프레임(`requestAnimationFrame` → `rIntent`, render.js 329·356)에 그때 `FSM` 이 `AI_TURN`·`BATTLE_END` 가 아니면 `AI.planIntents()`.
그래서 실제로 계산이 일어나는 것은 "다시 그린 뒤 다음 프레임까지 상태가 그대로 머무는" 곳뿐입니다 — 플레이어 입력 대기·연출 대기. 클랜원이 행동한 뒤 차례가 끝나면 `endUnitTurn` → `nextAction` 이 같은 콜백 안에서 곧바로 `AI_TURN` 으로 넘어가므로 다음 프레임에는 계산하지 않고, 적 차례 동안에도 계산하지 않습니다. 즉 **적은 클랜원이 행동하기 전 상태로 계산된 예고를 씁니다.**

> **규칙: 아래 시점에 `AI.planIntents()` 를 동기로 1회 부른다. 단 그때 `FSM` 이 `AI_TURN` 또는 `BATTLE_END` 면 건너뛴다. 적 차례 시작 때는 다시 계산하지 않는다.**
> ① 전투 시작 (`initBattle`·주입 뒤, 첫 `nextAction` 전 — 실제 게임은 로딩 화면 동안의 프레임)
> ② `ActionManager.selU(u)` 직후 (클랜원 차례 시작·다시 선택 포함 — selU 가 막혀 아무것도 안 했으면 제외)
> ③ `'wave_spawn'` 알림 직후 (`nextAction` 의 증원 → 600ms 웨이브 연출 동안)
> ④ 보물상자가 열린 직후 (상자 연출 250ms 뒤 다시 그림)
> ⑤ 이동 취소(`actCancel` 의 `preMv` 되돌리기) 직후

기록: 적의 `turn_start` 사건에 `intent`(그 적이 이번 차례에 쓰는 값, 없으면 null). `_intent` 는 스냅샷에서 뺐고 별도 사건도 없습니다 (2b 는 위 규칙으로 계산해 `turn_start.intent` 와 비교).

### 스토리 대사 (`story-battle.js`) 를 뺀 의미

실제 게임은 보스 등장·위기·마지막 적·증원 때 대사를 띄우고, 클랜원 차례에는 플레이어 입력 전에 재생합니다. 대사 동안 진행이 멈출 뿐 규칙은 바뀌지 않습니다. 대사는 클랜원 차례 시작(입력 대기)이나 적 차례 앞에서 재생되는데, 그동안 상태는 바뀌지 않으므로 행동 예고 결과도 위 규칙(②·③ 시점의 상태)과 같습니다. 가짜 세이브에는 본 대사 기록이 없어 실제 게임이라면 대사가 모두 나옵니다 — 기록에는 영향 없음.

### 아군 조작 타이밍 (재생 규칙)

`ActionManager.selU(u)` (= `nextAction` 의 `setTimeout(selU, 350)`) 로 클랜원 차례가 시작되면 **100ms 뒤**(값은 임의 — 행동 예고를 위 규칙으로 정했으므로 결과에 영향 없음) 그 차례의 첫 명령을 실행합니다.
`move`·`climb`·`undo` 다음 명령은 **400ms 뒤**, 그 밖의 명령은 실패(`ok:false`)했을 때 바로 다음 명령을 실행합니다.
기절한 클랜원(`stunned>0` 또는 STUN 버프)은 `nextAction` 이 500ms 뒤 차례를 넘기므로 명령이 없습니다.

## 난수: mulberry32

`Math.random` 을 전투 시드(`scenario.seed`)의 mulberry32 로 바꿉니다. **`initBattle` 직전부터** 호출 수를 셉니다 (`events[i].rng`·`rngEnd` — 아래 '사건의 rng 의미', `setup.rngAfterInit`, `end.rngCalls`).
가짜 세이브의 장비는 다른 시드(`seed ^ 0x5eed5eed`)로 만들고 세지 않습니다 — 결과가 `save` 에 그대로 있으니 2b 는 다시 만들 필요 없음.

JS (tools/legacy-web/battle-sim/env.js):

```js
function mulberry32(seed) {
  let a = seed >>> 0;
  return function() {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1) >>> 0;
    t = (t ^ (t + Math.imul(t ^ (t >>> 7), t | 61))) >>> 0;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
```

GDScript (64비트 int 로 32비트 연산 흉내 — Godot 4.5 에서 JS 와 시드 0·1·42·1005·4294967295 각 2000개가 정수까지 같음을 확인):

```gdscript
const M32 := 0xFFFFFFFF
var _a := 0   # = seed & M32

static func _imul(a: int, b: int) -> int:   # Math.imul 의 하위 32비트 (부호 없는 값으로)
	var al := a & 0xFFFF
	var ah := (a >> 16) & 0xFFFF
	var bl := b & 0xFFFF
	var bh := (b >> 16) & 0xFFFF
	return ((((ah * bl + al * bh) & 0xFFFF) << 16) + al * bl) & M32

func next_float() -> float:
	_a = (_a + 0x6D2B79F5) & M32
	var t := _a
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & M32)) & M32
	return float((t ^ (t >> 14)) & M32) / 4294967296.0
```

첫 값 확인용: `mulberry32(1)` → `0.6270739405881613, 0.002735721180215478, 0.5274470399599522`.

### 난수를 쓰는 곳 (호출 순서·개수까지 맞춰야 함)

값이 기록에 안 보여도 **호출 자체가 열을 밀어내는** 곳이 많습니다. `&&` / `||` 의 단락 평가 때문에 "조건이 거짓이면 난수를 안 뽑는" 곳도 그대로 따라야 합니다.

- 전투 준비 (`BattleInit.initBattle`): `shuffle(S.eQ)` → `Grid.genT`(가운데 행 칸마다 1회, 길이 없으면 `_ensurePath`) → `Hazard.placeSafe`(결계 맵) → `Chest.place` → 첫 `spawnWave`(`shuffle(op)` + 적 생성).
- `shuffle(a)`: 끝에서부터 `j = floor(r*(i+1))` (Fisher–Yates, `i = len-1 .. 1`).
- 적 `UnitManager.addUnit`: `randomGender()` 1 → `_selectRandomSiegeType()` 1 → `_createSiegeItem` 의 `id: Math.random()` 1 = **적 하나에 3회** (보스도 같음). 아군·소환수는 0회.
- `BuffSystem.apply`: **새 버프를 만들 때** `id` 를 위해 1회 (`Math.random().toString(36)`, 값은 안 씀). 같은 타입+출처 버프 갱신이면 0회. `buffDef.id` 를 주면 0회.
- `calcDmg`: 지휘관 1%(전투 불참이라 없음), 궁수 `archer_weakspot` 있으면 1회, `GearFX.mod` 의 `crit` 장비 있으면 1회. (`calc` 사건이 calcDmg 한 번)
- `UnitManager.rollEvade`: 회피 버프가 있으면 1회, (그 다음) 숲이면 1회. `resistKnock`: 저항률 > 0 일 때만 1회. `rollSupport`: 지원할 유닛이 있을 때만 1회.
- 무투가 반격(`brawler_counter`): 앞 조건이 모두 참일 때만 1회 (ally `doAtk` 와 AI `eAtk` 모두).
- `EnchantFX.afterHit`: 서리(frost) 마법부여일 때 대상이 살아 있으면 1회. `GearFX`: `cleanse`(turn_end), `mana_free`(skill_used, 비용 있는 스킬), `heal_cleanse`(unit_healed, 물약 제외).
- AI: `selectTarget` 실수 판정 1회(+고르면 1회), `random_weak`·기타 무작위 고르기, `_tryAttack` 의 `!target && Math.random() >= 0.3`(예고 대상이 사거리에 있으면 0회), `tryUseSkill` 의 `!p || Math.random() > p`(확률 0 이면 0회), `_tacticScore` **후보 칸마다 1회**, `eMv` 후퇴 판정(`hpPct < 기준` 일 때만), `tryWallClimb`(성벽 이웃마다), `selectSiegeItem`(쓸 수 있는 아이템마다).
- 보물상자 `Chest.open`: 종류 1회 + 종류별 추가 (골드 1, 물약 1, 룬 `Rune.random` 1 + `Rune.add` 의 rid 1, **장비는 `gachaPull` 전체 생성 과정**, 강화석 1, 조각 0). 장비 생성(`rollRarity`·`generateEquip`·`genEid`·`Gear.roll`)까지 같은 순서로 옮겨야 이후가 어긋나지 않습니다.
- 전투 끝 `BattleEnd.onBattleEnd`: 신규 클랜원(직업·잠재력·이름·성별), 보스 영혼석 직업, 전설 장비 확률(+생성), 룬 확률(+종류·rid), 스킬북 5%(+종류), 요일 던전 세트 장비·전설.
- 정책(아군 조작)은 난수를 **쓰지 않습니다** (calcDmg 도 부르지 않음).

### 순서가 키·정렬에 달린 곳

- **정렬은 안정 정렬이어야 합니다** (JS `Array.prototype.sort` 는 안정. GDScript `sort_custom` 은 아님 → 원래 순서 index 로 동점 처리). 동점이 실제로 나는 곳: `TurnManager.getNextUnit`(행동력·회복 속도 같으면 `S.units` 순서), `AI.selectTarget`(low_hp/nearest/nearest_threat/random_weak), `UnitManager.supporterOf`(공격력), `applyDmgToAlly` 고통 분담 기사(거리), `ActionManager._findAdj`(거리, 방향 순서 위·오른·아래·왼), `GearFX` 디버프 장비 주인.
- 무작위로 고를 때 배열 순서가 결과를 정함: `Grid.atkCells` 는 행(y) 바깥·열(x) 안쪽 순서, `_visibleAllies` 도 그 순서. `Object.keys(BATTLE_POTIONS)`, `Rune.kinds()`(ENCHANTS 키 순서), `for..in GACHA_RATE`, `Object.keys(LEGENDS)`, `Object.keys(JAB)`, `Object.keys(LEARNABLE_SKILLS)` (→ `getUnitSkills` 순서 = 스킬 메뉴 idx) — 모두 원본 선언 순서 (Godot JSON Dictionary 도 순서 유지).
- `Grid.mvCells/eMvCells`: BFS 큐 순서(방향 `[0,-1],[0,1],[-1,0],[1,0]`), 같은 칸을 더 싸게 다시 찾으면 `vis` 값만 바꾸고 큐에 또 넣음. `_addVault` 는 `vis`(Map) **삽입 순서**로 돈다 (값을 바꿔도 위치 유지). AI 는 `>` 로 첫 최고점을 고르므로 후보 순서가 곧 동점 처리.
- `Hazard.placeSafe`: 행(y)·열(x) 순서로 후보 → `splice(floor(r*len))`, 이웃은 구역 칸 순서×방향 `[1,0],[-1,0],[0,1],[0,-1]`. `S.safeZones` 는 Set 삽입 순서 (`setup.safe`·`safe_zones` 사건도 그 순서).
- `Chest.place`: 3~9행 스캔 순서, `spawnWave`: 열 스캔 순서로 `op` 를 만든 뒤 shuffle.

## 2b 가 그대로 따라야 할 규칙 특이점

- **Math.round** 는 .5 를 +∞ 쪽으로 (`Math.round(-2.5) = -2`). GDScript `round()` 는 0 에서 먼 쪽 → `floor(x + 0.5)` 로 구현.
- **JS 나눗셈은 항상 실수**. GDScript `int/int` 는 정수 나눗셈이므로 float 로 바꿔서: `Hazard.dotPct` 의 `stageLevel/100`, `Math.ceil(s.tot / 4)`(돌파 한도), `(g.hp[0]+g.hp[1])/2`(성장 평균, .5 가능), `(5 - actionPow) / actionRec`, `Math.floor(dmg / 3)`(고통 분담), `killPool / 생존자 수`, 평균 y(`avgAllyY`), `Math.ceil(s.length / 2)`(random_weak), `Synergy.frags` 의 `Math.ceil(n*m)`.
- 행동력: `advanceTick` 은 `Math.round((ap + rec*minDelta)*1000)/1000`, 준비 기준 `>= 4.999`, 차례 끝 `max(0, ap-5)`. `Math.min(...[])` 같은 빈 배열은 생기지 않음.
- 피해 계산 순서와 반올림 위치는 `calcDmg` 를 한 줄씩 그대로 (atk 버프 곱→반올림, def 버프, 방어 태세 ×1.5 반올림, `max(1, atk-def)`, 광폭 ×1.5, 고양 ×1.25, 마나 쇄도 ×1.2, 전술 배율(합산 상한 +40%), 여울 ×1.2, 치명타, GearFX.mod). 스킬은 각자 공식 (`Math.round(atk*배율*skMul) - def` 처럼 **빼기 전에 반올림**인 것과 `Math.max(1, atk*2 - def)`(습격, 반올림 없음) 이 섞여 있음).
- `skMul = 1 + 0.1*(min(lv,10)-1)` 실수.
- 전술 판정 `tacticBonus`: 대상 방향 `(_gdx,_gdy)` 와 공격 방향의 cos (< -0.5 후방, ≤ 0.5 측면), 대상이 `_defend` 면 후방·측면 없음. 방향 벡터는 정규화 안 된 정수 (위 2).
- `uAt(x,y)` 는 같은 칸에 여럿이면 **적을 먼저** (암살자 겹침).
- 아군 차례 건너뛰기는 `stunned>0 || STUN 버프` 만 본다 (**빙결 아군은 행동함**, 이동만 `mvCells` 에서 FREEZE 버프로 막힘). 적은 `isCC`(기절·빙결, 옛 필드+버프) 면 건너뜀.
- 차례 끝 처리 순서(`endUnitTurn`): 행동력 -5 → 자원 회복(암살자 숲 2배) → 용암 화상 → 환경 지속 피해(결계 칸 제외) → `BuffSystem.tick`(지속 감소·DoT/HoT) → 옛 필드 감소(stunned·frozen·disarmed·furyBuff·defBuff·출혈·방진·강화·속박·성역) → 소환수 남은 턴 → 창벽 리셋 → `'turn_end'`(GearFX 재생·정화) → 라운드 집계(독안개 틱 → 결계 이동) → `nextAction`.
- 라운드(`S.turn`) = 살아 있는 클랜원(소환수 제외)이 모두 한 번씩 행동. 결계 이동은 `(S.turn-1) % 3 === 0` 일 때.
- `_skillDone` 은 `Fx.later` 로 차례를 끝냅니다 (실제 게임 300~500ms 뒤, 기록은 즉시 — 그 사이 다시 그리기가 없으면 행동 예고도 계산되지 않음. 위 '행동 예고 규칙' 참고). 장비 소환수 강화(GearFX `skill_used` 의 `setTimeout(0)`)는 실제 게임에서는 소환사 `endUnitTurn` **전**, 기록에서는 **후**에 적용되지만 **순서와 무관**합니다: 강화는 소환수의 mhp·hp·atk·def·summonTurns 만 바꾸고, 소환사의 `endUnitTurn`·`nextAction`(행동력 진행·웨이브)은 이 값들을 읽지 않으며, 다음 차례(350ms·270ms 타이머) 전에 반드시 적용됩니다.
- **돌파 패배는 `TurnManager.chkEnd` 에서만 판정**합니다. 적이 성문·성벽을 넘어도(`breach`) 이동 경로에서는 chkEnd 가 불리지 않아, 다음 처치·스킬 끝 등 chkEnd 가 불릴 때까지 전투가 계속됩니다 (gate_breach_s01 이 일부러 그때 공격).
- 전투 중 인벤토리 번호: 아래 '고친 웹 버그' 참고 (고친 뒤 기준으로 기록).
- `BuffType.FURY_BUFF` 버프는 `BuffSystem.migrateUnit`(쓰이지 않음)에서만 생깁니다 (광폭 패시브는 옛 필드 `furyBuff`). 그래서 `'fury_triggered'` 는 일반 플레이에서 나오지 않습니다 (edge_inject_s11 은 주입).
- `'shield_active'` 는 AI `eAtk` 에서 대상(클랜원)에게 SHIELD 버프가 있을 때만 나오는데, SHIELD 버프는 적 공성 아이템으로만 생겨 클랜원은 가질 수 없습니다 (edge_inject_s11 은 주입).
- 적 전사 처형(ai.js `tryUseSkill`)은 분노 3 이상 + 사거리 안 클랜원 HP ≤ `round(atk*1.5 - def)` 일 때 HP 를 바로 0 으로 (강인한·고통 분담·장비 흡수를 거치지 않음, `calc` 없음).
- 스킬 환불(`_skillRefund`)이어도 `doSkill` 이 먼저 `'skill_used'` 를 알리므로 GearFX(`focus`·`mana_free` 난수)가 반응합니다.
- 적 공성 아이템 `cooldown` 은 3 으로 바뀐 뒤 줄어들지 않음 → 적마다 최대 1번 사용.
- 사제 `priest_purify` 의 대상 조건은 옛 필드(`stunned/frozen/disarmed/_bleedTurns/_rootedTurns`)만 봅니다. 일반 플레이에서 클랜원에게 이 필드가 생기지 않아 **주입 없이는 쓸 수 없음** (balanced_s05 는 `disarmed: 3` 주입).
- AI 프로필의 `trapPlacement`(공병)는 쓰이지 않음 → 적 함정이 생기지 않아 `assassin_trapdetect` 는 일반 플레이에서 발동하지 않습니다.
- 안 쓰이는 코드(옮길 필요 없음): `tickBuffs`(_common.js), `UnitManager.eFormation`, `BuffSystem.migrateUnit`.
- `toFixed` 반올림(신규 클랜원 잠재력 `+x.toFixed(1)`)은 2진 실수의 정확한 10진 전개 기준 — GDScript `snapped()` 와 경계값이 다를 수 있음.
- `G` 프록시에 쓰기: `GameStore` 에 없는 이름(`G.magicWalls`, `G.awPM`, `G.skillMode`)은 프록시 대상 객체에 저장됨 (`magicWalls` 는 기록의 `g.walls`).

## 기록 형식 (`deadline15-battle-trace/1`)

맨 위 키 순서는 고정: `format, scenario, save, setup, events, end`. 사건·유닛은 한 줄에 하나. 숫자는 JSON 숫자 (JS double 그대로 — 정수는 정확, 행동력 같은 실수는 같은 연산 순서면 비트까지 같음). 유닛은 모두 `id`(전투 안 번호, `GameStore.nid`)로 가리킵니다 (`uid` 는 세이브의 클랜원 번호).

### scenario
`{ name, seed, desc, stage, practice, maxRounds, policy }` — 시나리오 표의 값 그대로.

### save
가짜 세이브 (Store 키별 JSON): `game_save`(gold·cleared·stars), `game_roster`(chars: uid 1 = 지휘관, 2~ = 파티 순서, nextId), `game_parties`(활성 파티 1), `game_inventory`(장비·공성·물약).
2b 는 이 값을 저장소에 넣고 `loadGoldData()` → `GameStore.gold/cleared`, `cStage = setup.stage`, `practiceMode`, `party = 파티 1 의 uid` 로 `initBattle` 을 부르면 됩니다.

### setup (initBattle 직후)
| 키 | 내용 |
|---|---|
| `stage` | 전투에 쓴 스테이지 객체 (`logic/stages.js` 가공 후 `sm`·`tot`·`spw` 포함, 화면용 키 제거). 요일 던전은 `daily` 포함 |
| `practice` | 연습 모드 |
| `inject` | 시험용 상태 주입 — initBattle **뒤**, 첫 `nextAction` **앞**에 순서대로: `{unit, set}` = `Object.assign(유닛, set)` (값은 깊은 복사), `{store: {키: 값}}` = `GameStore[키] = 값` (예: `traps`). 주입한 버프는 `id` 가 있어 난수를 쓰지 않음. `setup.units` 는 주입 **뒤** 상태 |
| `ter` | 지형 15행 × 8열 (`ter[y][x]`) |
| `gateHP`, `wallHP` | 성문·성벽 ("x,y" 키) |
| `eQ` | 첫 웨이브 뒤 남은 적 대기열 |
| `safe` | 냉기 결계 칸 ("x,y", Set 순서) |
| `chests` | 보물상자 `[x,y]` |
| `synergies` | 조합 버프 `{id, eff, to, resonance}` (공명 반영 후) |
| `hazard` | 맵 환경 id (`HAZARDS[mapType].id`) 또는 null |
| `potions`, `siege` | 전투에 가져간 물약 id·공성 아이템 id |
| `rngAfterInit` | initBattle 이 쓴 난수 호출 수 |
| `initEvents` | initBattle 중의 사건 (아래 사건 형식: 유닛 등장, 결계 배치, 첫 웨이브) |
| `units` | 모든 유닛 전체 정보 (키 이름순; 조합 버프·환경·장비·선공 반영 후, 초기 방향 포함). `name`·`gender`(표시용), 버프 `id`, 공성 아이템 `id` 는 뺌 |

### events
모든 사건: `{ "ev": 종류, "rng": …, ...필드 }`. 유닛 필드는 id.

**사건의 rng 의미**
- EventBus 알림·`cmd`·`spawn`/`gone`·`chest_open`·`float`·`snap`: `rng` = 기록하는 순간(알림은 구독자 실행 **전**, cmd 는 실행 **전**)까지의 호출 수.
- 감싼 함수의 결과 사건(`calc, evade, knock, support, env_dmg, mist_tick, curse_tick, safe_zones, overwatch, wall_climb, skill_fx, ench_dmg, ench_hit`): `rng` = 그 함수가 **시작할 때**, `rngEnd` = **끝난 뒤**(사건을 기록한 순간)의 호출 수. 그 사이의 난수는 그 함수(와 그 안에서 불린 것)가 쓴 것. 이 사건들은 함수가 끝난 뒤에 기록되므로, 함수 안에서 난 알림(예: overwatch 안의 unit_attacked)이 기록상 **앞에** 옵니다.

**EventBus 알림** (웹 코드가 보낸 데이터 그대로, 유닛→id, `message` 는 뺌. `state_changed`·`camera_focus`·`wave_announce_end` 는 기록 안 함):

| ev | 필드 |
|---|---|
| `turn_start` | `unit, phase('player'|'enemy'), r(라운드), ap(행동력)` + 적이면 `intent`(이번 차례에 쓰는 행동 예고 — 위 규칙) |
| `turn_end` | `unit` (바로 뒤에 `snap`) |
| `round_end` | `turn`(새 라운드 번호) (바로 뒤에 `snap`) |
| `unit_added` | `unit` (적 생성. 바로 앞에 `spawn`) |
| `unit_moved` | `unit, from{x,y}, to{x,y}` |
| `unit_attacked` | `attacker, target, damage` + `counter`(AI 쪽 공격·반격), `isCounter`(아군 공격의 반격), `isSplash`, `isSupport`, `isSpearwall`, `isAoE` |
| `unit_killed` | `killer`(없으면 null), `target`, `reason`('unsummon'·'trap_or_spearwall') |
| `unit_healed` | `healer, target, amount, isPotion` |
| `buff_applied` / `buff_removed` | `unit, buff{type, source, duration, value, stacks, meta, attackCount?}` |
| `buff_tick_damage` / `buff_tick_heal` | `unit, buff, damage` / `heal` |
| `skill_used` | 아군: `unit, skill, tx, ty` · AI: `caster, skill, target` 또는 `targetCell` |
| `trap_triggered` | `unit, trap[x,y,team,dmg,stun], damage, stun` |
| `wave_announce` / `wave_spawn` | `remaining` / `count` |
| `siege_used` | `unit, type, tx, ty` 또는 `target{x,y}` |
| `gate_attacked` / `gate_destroyed` / `breach` | `unit, x, y, hp` / `unit, x, y` / `unit, count, limit` |
| `evasion`, `fury_triggered`, `retreat`, `root_blocked`, `shield_active` | `unit` |
| `soulbond_restore` | `summoner, amount` |
| `battle_end` | `win` |

**시뮬레이터가 덧붙인 사건** (규칙 함수를 감싸 결과만 기록, 동작은 그대로):

| ev | 언제 | 필드 |
|---|---|---|
| `spawn` | 유닛이 `S.units` 에 새로 보일 때 (적 생성·소환수) | `unit` = 전체 정보 (setup.units 와 같은 형식) |
| `gone` | 유닛이 `S.units` 에서 빠질 때 (`rmDead`·소환 해제·영혼 폭발) | `u` |
| `calc` | `calcDmg(a,t)` 한 번 | `a, t, dmg, tags(['back','side','pincer','high'] 중), crit, shallow(대상이 여울), dist, hill(공격자가 언덕 위 원거리), parts` — `parts{atk, def, base, mods}` 는 디버깅용 내역 (calcDmg 를 그대로 따라 계산한 버프 반영 공격·방어, `max(1,atk-def)`, 곱해진 배율 이름 `fury1.5·exalt1.25·manasurge1.2·tactic<배율>·shallow1.2·gear`; 치명타·GearFX.mod 결과는 `dmg`·`crit` 로) |
| `evade` | `rollEvade` 성공 | `u, kind('siege'|'forest')` |
| `knock` | `resistKnock` (밀치기·포획) | `u, resisted` |
| `support` | `rollSupport` 발동 | `sp(지원자), a, t, dmg, hit(실제 맞은 유닛)` |
| `env_dmg` | `endUnitTurn` 의 용암 화상 + 환경 지속 피해 (합계) | `u, dmg, lava(용암 옆), safe` |
| `mist_tick` | 독안개 라운드 틱 | `mists(개수), hits[[id, 피해]]` |
| `curse_tick` | 쇠약의 저주 이동 틱 | `u, dmg, n(누적 횟수)` |
| `safe_zones` | `Hazard.placeSafe` (시작·이동) | `cells["x,y"…]` |
| `overwatch` | 경계 사격 발동 | `w(쏜 유닛), e(이동한 적)` |
| `wall_climb` | 적이 성벽을 오름 (`AI.tryWallClimb` 성공, 곧바로 `breach`) | `u, x, y` |
| `ench_dmg` | 공격용 마법부여가 있는 공격자의 `EnchantFX.modDamage` | `a, t, before, after` (번개·파쇄 보정) |
| `ench_hit` | 같은 공격자의 `EnchantFX.afterHit` | `a, t, dmg, drain(흡혈로 회복한 HP), newBuffs(대상에 새로 붙은 버프 type — bleed·poison·freeze)` |
| `skill_fx` | 스킬 성공 처리(`_skillDone`) 순간 | `skill, u, hits[[id, 전 HP, 후 HP]], moved[[id, x, y]]` (exec 시작부터의 변화) |
| `chest_open` | 보물상자 열림 (shim 5) | `u, x, y, kind` |
| `float` | `Fx.float` 의 `messages.*` 글자 (선택 안내 제외) — 막힘(intercepted)·버팀(knock_resist)·밀림(shoved)·충돌(shove_crash)·기절 넘김(cc_skip) 등 | `x, y, key` |
| `cmd` | 아군 명령 (아래) — **효과보다 먼저** 기록 | |
| `snap` | 상태 스냅샷: `turn_end`·`round_end` 직후와 끝 | `why, g, units` |

`snap.g`: `turn, act(actCount), eSpwn, eQ, breached, gate, traps[[x,y,team,dmg,stun]], mists[[cx,cy,atk,turns,team]], chests[[x,y]], safe, ter(시작 지형과 다른 칸 [[x,y,tile]]), walls(그랜드 월 [[x,y]]), wallHP, acted(이번 라운드에 행동을 마친 클랜원 id = _turnActed), exp(battleExp {uid: 경험치}), potions(남은 전투 물약 id), siege(남은 공성 아이템 id)`.
`snap.units[]`: `id, team, cls, x, y, hp, mhp, atk, def, move, range, res, ap(actionPow), face[_gdx,_gdy](없으면 null)` + `st`(0·false 가 아닌 상태값만: `stunned frozen disarmed furyBuff defBuff _defend _overwatch _cursed _curseDmgCount _rootedTurns _bleedTurns _bleedDmg _sanctuaryTurns _sanctuaryHeal _phalanxTurns _phalanxDef _empowerTurns _empowerMul summonTurns _tenacityUsed _tenacityDef _sacrificeKnight _sacrificeDmgCount stealthBroken channeling _barrier _spearwallUsed _lastStandUsed _firstHit _focus _comboTgt _comboN _oath _movedDist`) + `buffs[[type, source, duration, value]]` + `siege["type:cooldown"]`(적).

### 아군 명령 (`cmd`)

`{ ev:'cmd', rng, u(유닛 id), op, ...인자, ok }`. 실행 입구는 화면 버튼과 같음 (`S.sel !== u` 면 먼저 `ActionManager.selU(u)`):

| op | 인자 | 실행 |
|---|---|---|
| `move` | `x, y` | `actMove()` → `cellCk(x,y)` (→ `doMv`) |
| `attack` | `x, y, target` | `actAttack()` → `cellCk(x,y)` (→ `doAtk`; 사제는 공격·회복 모드) |
| `heal` | `x, y, target` | `actAttack()` → `cellCk(x,y)` (사제, → `doHeal`) |
| `shove` | `x, y, target` | `actShove()` → `cellCk(x,y)` (→ `doShove`) |
| `skill` | `skill, idx, x, y` | `actSkill(idx)` (idx = `getUnitSkills(u)` 순서), 상태가 `SKILL_TARGET` 이면 `cellCk(x,y)`. 실패 후에도 `SKILL_TARGET` 이면 `cellCk(-1,-1)`(취소) |
| `wait` / `defend` / `overwatch` | `dx, dy` | `askFace(op)` → `faceDone(dx,dy)` (0,0 = 지금 방향 그대로) |
| `siege` / `climb` | `idx, item, x, y` | `actSiege(idx)` → (ITEM_TARGET 이면) `cellCk(x,y)`. 실패면 `actCancel()` |
| `potion` | `idx, item, x, y` | `actPotion(idx)` → (ITEM_TARGET 이면) `cellCk(x,y)`. 실패면 `actCancel()` |
| `undo` | (없음) | 이동 취소 `actCancel()` (→ 원래 칸, 이동 경험치 회수, `hm/mo` 해제, 340ms 뒤 `clrSel`). 다음 명령은 400ms 뒤 (`selU` 부터 다시) |

`ok` = 의도대로 됐는지 (이동: 좌표가 바뀜 / 공격·회복·밀치기: `u.ha` / undo: `hm` 해제 / 나머지: 차례가 끝남 / climb: 위치가 바뀜). **`ok:false` 명령도 순서대로 재생하세요** — 스킬 환불처럼 `skill_used` 알림(→ GearFX 난수)이 나가는 경우가 있습니다.
2b 재생: 클랜원 차례가 시작될 때마다(`selU` 순간) 그 유닛의 다음 `cmd` 들을 위 타이밍(100ms / move 뒤 400ms)으로 차례가 끝날 때까지 실행. 정책(`policy.js`)은 옮길 필요 없음.

### end
`result('win'|'lose'|'stalled'|'stuck'|'max_steps'), reason(win/lose 의 메시지 키: stage_clear·all_defeated·enemy_breached), rounds(S.turn), actCount, rngCalls, virtualMs, allies[id], enemies[id], kills, breached, chestLog, rewards`.
`end` 에는 끝으로 `saveAfter` 가 붙습니다. `rewards`(onBattleEnd 결과): `win, exp[{uid, exp, actExp, killExp, leveled}], killPool, kills, gold(전투 끝 소지금), baseReward, bonusReward, stars{flags, merged, newly, limit, turn, bonus}, soul, rune, book, newUnit(직업), gearDrops(개수), deadAllies[uid], autoRevived`.
`saveAfter` = 전투 뒤 저장소 전체 (Store 키 이름순, 값은 JSON 해석) — 경험치·레벨업, 골드·별점·클리어, 신규 클랜원(로스터 보정 후), 사망 표시, 상자·드랍 아이템, 영혼석.
`stalled` = 라운드가 `maxRounds` 를 넘음 (기본 120; 자동 플레이 `tools/autoplay.js` 의 250라운드 항복과 같은 역할). 전투가 끝나면(`battle_end`) 남은 타이머는 실행하지 않고 멈춥니다 (보상은 이미 계산됨).

## 기록이 기대는 웹 함수·훅

- 적재·전역: `battle.html` 스크립트 목록, `Store.useBackend`, `loadGoldData`, `_newCommander`, `Daily.buildStage`, `STAGES`, `JAB`, `SIEGE_ITEMS`, `BATTLE_POTIONS`, `Gear.makeLegend/makeSetPiece`, `generateEquip`, `equipTemplate`.
- 진행: `BattleInit.initBattle`, `TurnManager.nextAction`(시작), `GameStore`, `FSM`/`BattleState`.
- 감싸기(결과 기록만): `EventBus.emit`(+ wave_spawn 뒤 행동 예고), `ActionManager.actCancel`(이동 취소 뒤 행동 예고), 전역 `calcDmg`, `UnitManager.rollEvade/resistKnock/rollSupport`, `EnchantFX.modDamage/afterHit`, `TurnManager.endUnitTurn`, `BuffSystem.tick`, 전역 `tickPoisonMists`, 전역 `curseMoveTick`, `Hazard.placeSafe`, `AI._overwatch`, `AI.tryWallClimb`, `AI.planIntents`(규칙 시점에 직접 부름), `SKILL_HANDLERS[*].exec`, 전역 `_skillDone`, `ActionManager.selU`(정책 시작점), `Fx.float`.
- 바꿔 끼움(규칙 되살림, 위 shim 1~8): `Fx.enabled/moveUnit/faceDir/attack/redrawUnits/float`, `VFX.init/_mvU(진짜)/faceDir(진짜)`, `Renderer.init/rUnits/showRes`(+ `getChar`), 나머지 화면 함수는 빈 함수.
- 정책이 부르는 입구: `ActionManager.selU/actMove/actAttack/actShove/actSkill/askFace/faceDone/actSiege/actPotion/actCancel/cellCk/faceOptions`, 조회용 `Grid.mvCells/atkCells`, `UnitManager.uAt/coverOf/interceptOf/tacticBonus/shoveTargets/shovePlan/nearLava`, `getUnitSkills`, `SKILL_HANDLERS[id].target`(부작용 없는 것만), `isStealthed`, `Chest.at`.

## 고친 웹 버그 (js/battle/action.js, 디렉터 승인)

전투 중 인벤토리에서 항목을 지울 때 물약 번호 목록(`_battlePotionIndices`)과 공성 아이템 번호 목록(`_siegeInvIndices`) 중 **지운 쪽만** 뒤 번호를 당겨, 다른 쪽 번호가 한 칸씩 어긋났습니다 → 공성 아이템을 쓴 뒤 물약이 줄지 않거나(엉뚱한 칸의 수량을 깎음), 물약을 다 쓴 뒤 공성 아이템을 쓰면 다른 아이템(장비 등)이 지워질 수 있었음.
수정: `ActionManager._invRemoved(invIdx)` 가 지운 뒤 **두 목록 모두** 보정 (`doPotion` 소진·`doSiege` 사용에서 부름). 화면 동작은 그대로.
확인 (siege_items_s13): 수정 전 공격 강화 물약 1개를 11번 사용·끝 인벤토리에 그 물약 그대로 → 수정 후 1번 사용, 자원 물약 2개 소모, 회복 물약 2개는 그대로.

## 찾은 비결정성과 처리

| 출처 | 처리 |
|---|---|
| `Math.random` (규칙 전체) | mulberry32(seed) 로 교체, 호출 수 기록 |
| `Date.now()` (장비 eid·룬 rid·물약 pid·사망 시각) | 가상 시계 (저장 값에만 영향) |
| `performance.now()` (AI 대기 시간 계산) | 가상 시계 |
| `setTimeout` 지연·연출 시간 (`atkHitDelay` 등) | 가상 시계 + `Fx.enabled=false` 고정값 |
| `requestAnimationFrame`·연출 시간·로딩·대사에 묶인 행동 예고 (`planIntents`) | '행동 예고 규칙'으로 고정, `_intent` 는 엄격 비교에서 뺌 (적 `turn_start.intent` 만) |
| 사람의 생각 시간 | 정책 첫 명령 100ms 고정 (결과 무관) |
| 객체 키·Set·Map 순서 | JS 규칙상 삽입 순서로 결정적 — 위 '순서가 키·정렬에 달린 곳' 참고 |
| `crypto`, `Intl`, 번역문 | 규칙 경로에 없음 (`t()` 는 키 그대로) |

## 도달하지 못한 것 (알려진 한계)

- `assassin_trapdetect` — 적 함정이 생기지 않아 일반 플레이에서 발동 불가 (위 특이점). 주입으로도 만들지 않음 (적 함정이 없는 게임에서 의미 없음).
- 주입으로만 닿는 것: 사제 `priest_purify`(balanced_s05), `shield_active`·`fury_triggered`(edge_inject_s11), 성문까지 오는 적(gate_breach_s01 의 은신 주입), 함정 밟힘(gate_breach_s01 주입 함정 — siege_items_s13 은 일반 플레이로 1회).
- 아군 `potion_def_buff` 와 적에게 쓰는 디버프 물약(`type: 'debuff'`)은 정책이 쓰지 않음.
- 강인한(`knight_tenacity`)은 일반 플레이로 loss_boss_s45 에서 1회, edge_inject_s11 에서 HP 1 주입 뒤 1회. 고통 분담(`knight_painshare`)은 결과가 `G.floatT`(화면)로만 보여 사건이 없음 — 스냅샷 HP 로만 확인.
- 엄호(`coverOf`)로 막힌 공격은 AI 후보에서 빠질 뿐 사건이 없음 → `calc`·`turn_start.intent` 차이로만 드러남.
- 스토리 대사(`story-battle.js`)는 연출이라 적재하지 않음.
