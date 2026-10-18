# tools/legacy-web — 웹판 시절 도구 보관 (2026-10-18)

웹판이 동결되고 데이터 원본이 `godot/data/` 로 옮겨지면서 쓰지 않게 된 도구입니다. **지우지 않고 남긴 이유:**

1. **기준의 출처 기록** — `godot/tests/golden/*.json`(황금 기록 22개)과 `godot/tests/fixtures/outer_*_web.json`(웹 정답 3개)은 이 도구들이
   웹 코드를 그대로 돌려 만든 것입니다. 기준이 어떻게 만들어졌는지(시나리오·시험 정책·가짜 세이브·씨앗) 읽어 볼 수 있어야 합니다.
2. **이식 버그 추적** — Godot 규칙이 기준과 어긋날 때, 웹판 파일이 남아 있는 동안은 `--rng-log`(난수 호출 위치)·`--only` 로 웹 쪽을 다시 돌려
   어디서 갈라지는지 볼 수 있습니다 (`godot/tests/replay_golden.gd -- --rng-log` 와 나란히).
3. **시나리오 설계 참고** — 황금 기록을 새로 짜야 할 때(데이터·규칙이 크게 바뀌어 기록된 명령이 맞지 않을 때) `battle-sim/scenarios.js`·`policy.js` 가 본보기입니다.

웹판 파일(`js/`, `data/`, `*.html`)을 지우면 이 도구들은 더 돌지 않습니다. 그때는 이 폴더도 지워도 됩니다 (기준 파일은 godot 쪽에 남음).

## 바뀐 점 (보관하면서)

- 모두 저장소 맨 위 기준 경로를 `tools/legacy-web/` 에 맞춤.
- **godot 쪽 기준·데이터를 덮어쓰지 않습니다.**
  - `--check`: 웹 코드를 다시 돌려 **고정된 기준 파일과 같은지 비교만** (쓰지 않음).
  - 다시 만들기(인자 없이): `tools/_work/legacy-web/` 아래에만 씀 (git 제외).
  - `export-godot-data.js`: 늘 `tools/_work/legacy-web/data/` 에 씀 (godot/data 는 이제 손으로 고치는 원본).
- `outer-4b1/4b2-expect.js` 는 이름 목록·JAB 을 `godot/tests/baseline/data/` (옮긴 시점 사본)에서 읽음.

| 파일 | 예전 역할 | 지금 대신하는 것 |
|---|---|---|
| `export-godot-data.js` | 웹 `data/*.js` → `godot/data/*.json` 변환, `--check` | `godot/tools/data_tool.gd` (모양 맞춤·manifest·`--check`) |
| `battle-sim.js` + `battle-sim/` | 웹 전투 코드로 황금 기록 만들기, `--check` | `godot/tests/replay_golden.gd` (기준과 비교) · `-- --record` (Godot 엔진으로 다시 쓰기) |
| `outer-4a/4b1/4b2-expect.js` | 웹 바깥 화면 코드로 정답 만들기, `--check`, `--roundtrip` | `godot/tests/check_outer_*.gd` (고정된 정답과 비교). 웹 왕복(`--roundtrip`)은 웹 세이브 가져오기를 만들지 않기로 해서 시험에서 뺌 |

```bash
node tools/legacy-web/battle-sim.js --check          # 웹 코드가 아직 고정된 황금 기록과 같은 결과를 내는지 (웹 파일이 있는 동안만)
node tools/legacy-web/battle-sim.js --only boss_s10 --rng-log
node tools/legacy-web/outer-4b2-expect.js --check
```

## audio-bake (2026-10-18, 5단계)

웹 `js/battle/audio.js` 를 Chrome WebAudio 로 그대로 돌려 Godot 소리 파일(`godot/assets/audio/`)을 굽고, 웹 실시간 출력과 Godot 출력을 녹음해 비교하는 도구 — `audio-bake/README.md`.
