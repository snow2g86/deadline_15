# 동결됨 — 이 폴더는 더 이상 원본이 아닙니다 (2026-10-18)

웹판(HTML/CSS/JS)은 **동결**되었고, 폐기 시점은 사용자가 정합니다. 그때까지 파일은 지우지 않고 그대로 둡니다.

- **수치·대본·번역의 원본은 `godot/data/`** 입니다 (`godot/data/*.json`, `godot/data/lang/<언어>.json`, `godot/data/story/<언어>.json`).
  고치는 법은 `godot/README.md` 의 '데이터 원본'.
- 여기(`data/*.js`, `data/language/**`, `data/story/*.js`)와 `js/logic/*.js` 안의 데이터를 고쳐도 **Godot 판에는 반영되지 않습니다.**
  반대로 Godot 쪽에서 고친 값도 여기에 돌아오지 않습니다 — 두 판은 2026-10-18 부터 갈라집니다.
- 옮긴 시점의 데이터는 `godot/tests/baseline/data/` 에 사본으로 고정되어 있고, 웹 코드로 만든 정답(황금 기록·웹 정답)이 이 사본과 짝입니다.
- 예전 변환기(`export-godot-data.js`)와 웹 정답 도구는 `tools/legacy-web/` 에 보관만 되어 있습니다 (godot/data 를 덮어쓰지 않음).
- 그림도 2026-10-18 `godot/assets/image/` 로 옮겼습니다 (`git mv`). 저장소 맨 위 `image` 는 그곳을 가리키는 심볼릭 링크라 웹판은 폐기 전까지 그대로 열립니다.
