# 캐릭터 외형 커스터마이징 시범 (기사) — 메모

## 실행
- 장면: `Godot --path godot res://dev/customize_pilot/pilot.tscn` (키: 1~3 머리, Q/W/E 옷, R 랜덤, Space 공격, Tab 앞뒤)
- 사진·측정: `HOME=<임시폴더> Godot --path godot --resolution 1280x720 --script res://dev/customize_pilot/shoot.gd` → `godot/tests/screens/cust_*.png`
- 조각 그림 다시 그리기: `python3 tools/pilot/make_parts.py [--preview 확인.png]` (0.3초)

## 구조
- 조각 그림: `godot/assets/pilot/knight/<f|b>/<조각>.png` (기준 칸 1칸 = 4픽셀), 자리·관절: `rig.json`
- 계층: bob → leg_f · leg_n · torso_g(엉덩이) → arm_f(+방패) · 몸통 · neck(머리 4겹) · arm_n(+칼). 조각 하나 = Sprite2D 하나, 관절 = Node2D
- 동작: 코드 자세표(`pilot_char.gd` 의 ATTACK·HIT 키프레임, idle·move 는 사인 곡선). 회전·이동만 쓰므로 그림을 새로 그릴 필요 없음
- 조각 구성: 직업 고정(다리·칼·방패) / 옷 3종(몸통·팔 2) / 머리 3종(뒤 겹·앞 겹) / 얼굴 2종(앞만) / 피부색 3종(색 곱하기, 그림 0장)

## 저장 형식 제안 (`dev/customize_pilot/look.gd`)
`"look": {"v": 1, "h": 머리, "f": 얼굴, "o": 옷, "t": 피부}` — 번호는 고정(새 조각은 뒤에만 덧붙임), 없으면 클랜원 id 시드로 같은 값을 만들어 채움, 미지의 번호는 0으로.

## 내보내기 주의
`godot/dev/` 와 `godot/assets/pilot/` 는 내보내기 제외가 필요함. 지금 `export_presets.cfg` 의 exclude_filter 는 `tests/*, tools/*, build/*, *.md, *.prev.png` 뿐이라 `dev/*, assets/pilot/*` 를 더해야 함 (이번 작업에서는 파일을 건드리지 않음).
