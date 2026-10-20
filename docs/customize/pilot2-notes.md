# 캐릭터 외형 커스터마이징 시범 2차 (기사, 라그나로크식) — 메모

## 방식
- 몸 = 지금의 영상 동작 시트 그대로 (knight_02, 앞모습 5동작). 머리·머리카락·옷·색은 그 위에서 바꿈.
- 머리: 프레임마다 머리 기준점(위치·크기·기울기) 표 → 그 자리에 다른 캐릭터 그림에서 잘라 온 머리 조각을 얹고, 원래 투구·깃털은 마스크로 지움.
- 색·무늬: 영역 마스크(갑옷·천·피부·가죽, 시트와 같은 크기) + 셰이더 (명도를 보존하며 곱함).
- 의상: (1) 영역 재색칠+무늬(전 프레임), (2) 몸통 겹침 조각(다른 캐릭터 옷을 잘라 가져옴; 몸통 기준점이 믿을 만한 프레임에서만).

## 실행
- 장면: `Godot --path godot res://dev/customize_pilot2/pilot2.tscn` (키 1~9 머리, R 랜덤, Space 공격)
- 사진·측정: `HOME=<임시폴더> Godot --path godot --resolution 1280x720 --script res://dev/customize_pilot2/shoot2.gd` → `godot/tests/screens/cust2_*.png`
- 에셋 다시 만들기: `P2_WORK=<임시폴더> python3 tools/pilot/p2_build.py` (약 30초; 기준점 표·마스크·머리·의상 조각)
- 기준점 정확도 합성 시험: `P2_WORK=<임시폴더> python3 tools/pilot/p2_anchor_test.py`
- 기준점 상자 사진: `python3 tools/pilot/p2_boxes.py godot/assets/pilot/knight2/anchors.json <출력폴더> cust2_anchor_boxes_`

## 파일
- `godot/assets/pilot/knight2/`: anchors.json(머리·몸통 기준점), mask_<동작>.png(R=영역×40·G=머리 지움·B=몸통 덮기), head_*.png(+_m), hat_*.png, cos_*.png, parts.json
- `godot/dev/customize_pilot2/`: pilot2.gd(장면), pilot2_char.gd(캐릭터), body/head.gdshader, palettes.gd(저장 형식·목록), kdata.gd, shoot2.gd
- `tools/pilot/`: p2_common·p2_anchors(머리 추적)·p2_torso·p2_heads·p2_build·p2_boxes·p2_maskprev·p2_anchor_test

## 저장 형식 제안
`"look": {"v": 2, "h": 머리, "d": 머리 장식, "c": 갑옷·천 팔레트, "k": 피부색, "r": 머리카락색, "o": 의상, "p": 무늬}` — 모두 0 = 원래 모습, 번호 고정(뒤에만 덧붙임), 미지의 번호는 0.

## 내보내기 주의
`godot/dev/`, `godot/assets/pilot/`, `godot/tests/` 는 내보내기 제외 필요 (이번 작업에서는 export_presets.cfg 를 건드리지 않음).
