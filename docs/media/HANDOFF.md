# 미디어(그림·3D) 작업 인계 문서

> 작성 2026-10-25 · 게임 0.4.2 · 다른 세션이 이어서 작업할 수 있게 현재 상태, 결정, 도구, 절차, 남은 일을 한 곳에 정리했습니다.
> 사용자는 비개발자 디렉터입니다. **모든 답변은 한국어**로 하고, 큰 작업은 계획 → 구현 에이전트 → 독립 검수 → 수정 → 커밋·푸시 순서로 진행합니다. (메모리: `~/.claude/projects/-Users-2z-Desktop-workspace-game-deadline-15/memory/`)

## 0. 먼저 알아 둘 것 (규칙)

| 규칙 | 내용 |
|---|---|
| 원화 제작 | **로컬 이미지 생성만** 사용 (mflux + Qwen-Image-Edit). Firefly·Higgsfield 등 유료 외부 서비스는 사용자가 따로 허락할 때만. 허락 없이 크레딧을 쓰지 말 것 |
| 동시 실행 | mflux는 **한 번에 1개** (메모리 62GB). 한 장 약 3~9분 |
| 배터리 | 작업 전·중에 `pmset -g batt`. **전원 미연결 + 30% 미만이면 중단**. 전원 연결 상태에서는 진행 가능 |
| 반복 루프 | 배치 스크립트를 만들면 **최대 반복·종료 조건**을 두고, 끝나면 `pgrep -fl "mflux|gen_story|batch_story|run_all"` 로 남은 프로세스 확인. 부모 루프를 먼저 죽여야 자식이 다시 살아나지 않음. `pgrep -f` 가 대기 스크립트 자기 자신을 잡는 문제가 있었음 |
| 다른 프로젝트 | 이 PC에서 `deck_tactics` 프로젝트의 Godot가 돌 수 있음. `pkill` 로 Godot를 함부로 죽이지 말 것 |
| 이미지 크기 | 게임 용량이 중요(출시 AAB 약 74MB). 그림은 **손실 WebP q85**로 게임에 넣고 무손실 원본은 `godot/assets/image/character/art_src/` (git 제외, `.gdignore`)에 보관 |
| 스타일 | **일본 애니메이션풍**, 치비 체형(머리 큼, 2~2.5등신), 큰 눈, 굵은 윤곽선, 허리 위 반신. 도트(픽셀) 질감·현실 비율은 불합격 |
| 승인 | 새 그림은 **비교 시트로 사용자에게 보여 주고 승인받은 뒤** 게임에 적용 |

## 1. 지금까지 끝난 미디어 작업

| 항목 | 상태 | 커밋/위치 |
|---|---|---|
| 전투·편성용 초상화 26장 (애니풍) | 적용 완료 | `godot/assets/image/character/portrait/{id}.png`, `Icons.portrait_tex` |
| 임시 앱 아이콘 (지휘관 시계 후광 엠블럼) | 적용 완료, **정식 디자인은 나중에 교체** (사용자가 도형·일러스트 엠블럼 모두 "촌스럽다"고 함) | `godot/icon.png`, `assets/app_icon/` |
| 전투 걷기(run) 모션 제거 | 완료 (공격·피격·죽음만 사용) | 100개 `*_run.png` 삭제 |
| 뒷모습(`_b`) 스프라이트 삭제 | 완료 (3D 교체 예정). 없으면 앞모습으로 대신 보임 | `SpriteDB.sheet/still(…, back)`, `UnitView.set_facing_back()`, README '용량 줄이기 6' |
| 스토리 초상화 17장 교체 | **적용·커밋 완료** (`d155d4a`) | `godot/assets/image/character/story/*.webp` |
| 용량 절감 | 완료: pck 107→43MB, AAB 164→75MB | `godot/README.md` '용량 줄이기' |

적용된 스토리 17장: bark, boss_10, boss_20, boss_30, boss_40, boss_45, boss_50, boss_70, boss_80, boss_92, boss_94, boss_95, boss_99, bram, commander_m, ordin, sera.

## 2. 진행 중이던 작업: 스토리 초상화 나머지 6장

### 2-1. 상태 (사용자가 "이미지 생성 잠시 중단"을 지시해 중단됨)

사용자 결정: **모든 스토리 초상화를 같은 그림체(치비)로 통일**. 현재 6장은 아직 **옛 도트 그림이 게임에 들어 있음** (새 그림과 섞여 나옴, 위치는 일관됨).

| 이름 | 현재 final/ 상태 | 할 일 |
|---|---|---|
| boss_90 | 합격 (투구 안 어둡고 붉은 눈, 붉은 스카프, 도끼) | 적용 가능. 후처리 점검 |
| boss_100 | 합격 (뿔 사이 가시 왕관, 붉은 눈) | 적용 가능. 몸이 어깨 위까지만 보임 |
| boss_60 | 깨끗한 애니풍이나 **투구가 원래보다 밝은 은색**. 치비 질감은 맞음 | 어두운 강철 투구 후보(v12, 시드 91·92) 생성·비교 후 선택. 불발이면 현재 것 적용 |
| boss_93 | 현실 비율 전신(작게 나옴). **불합격(체형 불일치)** | 치비로 재생성 |
| commander_f | 현실 비율, 포니테일·입 벌림·흰 허리띠. **불합격** | 치비로 재생성 (풀어 내린 긴 머리) |
| kasha | 현실 비율, 검 안 보임. **불합격** | 치비로 재생성 (붉은 리본 포니테일, 허리춤 검자루) |

재생성 방법(v11, 중단 직전 설계): 이미 승인된 치비 결과(raw)를 **스타일 참조**로 이식합니다. `gen_chibi.py <이름> <시드>` → `out/v11/<이름>_<시드>_raw.png`.
- boss_93 참조: boss_94, boss_20, boss_80 / commander_f 참조: commander_m, sera / kasha 참조: boss_94, bram, boss_95
- 시드 101~104, 캐릭터당 최대 4개. **v8(아주 흐린 도트 참조)과 v10(전투 초상화 참조)은 쓰지 말 것** — v8은 더 픽셀화, v10은 현실 비율이 나옴.
- 프롬프트에 `chibi, 2 to 2.5 head-tall proportions, big head, large glossy anime eyes, thick clean outlines, waist-up bust composition` 를 넣고 `realistic proportions, tall slim body, full body` 는 배제.

### 2-2. 생성 도구와 명령 (요약)

작업 폴더(원본, 휘발성): `/private/tmp/claude-501/-Users-2z-Desktop-workspace-game-deadline-15/ce3e70d8-eb69-421f-8fca-6ab19ac5743e/scratchpad/portrait/story/`
**영구 사본: `docs/art/story_portraits/`** (git 제외 대상으로 두거나 커밋하지 말 것, 약 27MB)

| 파일 | 역할 |
|---|---|
| `scripts/gen_story.py` | 캐릭터별 영문 묘사 `DESC`와 mflux 호출. `python3 gen_story.py <이름…> --seed N --v vN` → `out/<v>/<이름>_<시드>_raw.png` (크로마키 배경: 녹색, boss_30/boss_95는 자홍) |
| `scripts/gen_chibi.py` | 승인된 치비 raw를 스타일 참조로 이식 (v11) |
| `scripts/gen_style.py`, `gen_fix.py`, `gen_b60*.py` | boss_60·kasha 등 재시도용 변형 (v9, v10, v12) |
| `scripts/post_story.py`, `post_fix.py` | 크로마키 제거 + 962x1087 RGBA 로 맞춤 → `final/` |
| `scripts/sheet_story.py` | 기존 그림 / 새 그림 나란히 보는 비교 시트 → `compare/` |
| `scripts/run_all.sh` | 순차 배치 (대기 루프 없음. 최대 개수만큼만) |
| `scripts/apply_story.sh` | **게임에 적용**: 크기 검사(962x1087) → `art_src/story/` 원본 보관 → `cwebp -q 85 -m 6 -sharp_yuv -alpha_q 100` → `.webp.import` 확인 |
| `final/` | 현재 최종 후보 23장 (17장은 이미 적용된 후처리본, 6장은 위 표 상태) |
| `out_selected/` | 스타일 참조로 쓰는 승인된 치비 raw 7장 |
| `compare/` | 비교 시트 |
| `backup_old/` | 적용 전 옛 원본 |

mflux 핵심 인자 (gen_story.py 에서): `mflux-generate-qwen-edit --model qwen-image-edit -q 8 --lora Qwen-Image-Edit-2509-Lightning-8steps-V1.0-bf16.safetensors 1.0 --image-paths <참조> --prompt <…> --width 768 --height <16배수> --steps 8 --guidance 1.0 --seed N`. 실행 파일 `~/.local/bin/mflux-generate-qwen-edit`, LoRA 는 `~/.cache/huggingface/hub/models--lightx2v--Qwen-Image-Lightning/...`.
참조 이미지는 기존 도트 그림(`art_src/story/<이름>.png` 의 상단 66%)을 흰 배경에 얹고 강하게 흐려서(`SMOOTH_D=8`, `SMOOTH_B=3`) 질감 전달을 막습니다. **스크립트의 `D` 경로는 `godot/assets/image/character/story/` 로 되어 있어 옛 PNG 를 읽던 시절 값입니다. 지금은 원본 무손실 PNG가 `art_src/story/` 에 있으니 경로를 확인하고 쓰세요.**

### 2-3. 적용 절차 (사용자 승인 후)

1. `docs/art/story_portraits/final/<이름>.png` 가 962x1087 RGBA 인지 확인.
2. **후처리 점검**: 어두운 배경에 합성해 확대하고 (a) 가장자리 흰 테두리 (b) 초록 번짐(불투명 픽셀 중 G>max(R,B)+60 이고 G>140) (c) 상단이 맨 위에 닿는지를 봅니다. 이전 17장에서 bram·commander_m 흰 테두리, sera·boss_80 등 초록 번짐이 있어 `story_apply/clean.py` 로 정리했습니다(작업 폴더 `story_apply/` 는 휘발성 — 필요하면 다시 작성). 의도된 초록(boss_30 이끼, boss_95 갑옷 장식, boss_94 불꽃)은 보존.
3. `apply_story.sh 이름…` 실행 → `Godot --headless --editor --quit` 로 다시 가져오기(임시 HOME 사용).
4. 대사창·도감·전투 중 보스 등장을 1280x720·pixel8 로 확인 (`godot/tests/shots_*` 참고). 도감 카드는 `codex_view.gd` 의 `_story_thumb()` 가 반신/전신을 맞춥니다.
5. 전체 시험 + 내보내기 + `check_pc5`, 독립 검수 후 커밋·푸시. 절차 문서: `godot/README.md` '용량 줄이기 5. 정면·스토리 WebP'.

## 3. 그 밖의 남은 미디어 작업

| 순서 | 항목 | 상태 | 메모 |
|---|---|---|---|
| 1 | 스토리 초상화 6장 마무리 | 위 2번 | 사용자: "이미지 생성 잠시 중단" 후 재개 대기. "이미지 생성 다시 진행해" 가 오면 시작 |
| 2 | 500골드 코인 아이콘 | **화풍 불일치** (다른 골드 패키지 아이콘과 그림체가 다름) | 새 그림 필요. `godot/assets/image/icon/` 상점 골드 카드 4종과 나란히 비교 |
| 3 | 정식 앱 아이콘 | 임시 아이콘 사용 중 | 사용자가 도형·일러스트 엠블럼 모두 불만족. 시안 방향을 먼저 사용자와 다시 정할 것 (참고 이미지: 채색풍 원형 엠블럼). `godot/tools/make_mobile_icons.py` 로 플랫폼별 아이콘 생성 |
| 4 | 스토어 그래픽 (Google Play) | **미준비** | 아이콘 512x512, 대표 이미지 1024x500, 스크린샷 최소 2장(권장 휴대폰 가로/세로). 스크린샷은 게임을 실행해 직접 찍을 수 있음(`godot/tests/shots_*.gd`) |
| 5 | 전투 초상화 미세 수정 | 낮은 우선순위 | 일부 캐릭터의 손·소품 미세 차이 |
| 6 | 3D 캐릭터 (출시 후 업데이트) | **출시 뒤로 확정** | 아래 4번 참고 |

## 4. 3D 캐릭터 파이프라인 (출시 후)

사용자 결정: **게임 먼저 출시, 3D 외형 시스템은 출시 후 업데이트.** 상세 기록은 메모리 `character-customization.md`, 시범 코드는 git 브랜치 `archive/customize-pilots`.
- 방향: 체형별 기본 바디(남10·여10, T포즈·손바닥 정면·손가락 5개·속옷) → 3D → 갑옷·무기 부품 조합 → 게임 각도(방위 45°/고도 30° 직교) 렌더. 프롬프트 팩: `docs/art/base_bodies_firefly.md`.
- 검증된 경로: Firefly(GPT Image 2.5 Flare, 1장 5크레딧, 전사 c4 원화를 참조로 넣으면 화풍이 가장 잘 나옴) → Higgsfield MCP `tripo_h3_1_multiview_to_3d`(정면·측면·후면 3장, 9크레딧, 약 10분, GLB 3MB) → Blender 헤드리스 (표준 뼈대 58개 + 거리 기반 웨이트, 갑옷은 텍스처 색으로 분류·평면 절단 후 Data Transfer).
- 알려진 한계: AI 손은 손가락 6개로 나옴(뼈를 메시 끝 기준 재배치로 해결), 판금 갑옷은 슬롯 교체 불가(세트 통째만) → 슬롯 교체를 원하면 갑옷을 따로 생성하는 방식을 시험해야 함.
- Meshy·Tripo 사이트는 GLB 내려받기가 유료(구독). 상업 이용 조건 약관 미확인(출시 전 확인).
- 시안 파일 `docs/art/wip/` (M01, A01 등)은 **커밋하지 말 것** (GLB 대용량).

## 5. 환경과 도구 상태 (2026-10-25 기준)

- 게임 저장소: `/Users/2z/Desktop/workspace/game/deadline_15` (main, 마지막 푸시 확인됨). Godot: `/Applications/Godot.app/Contents/MacOS/Godot` (4.5.1), 시험은 **임시 HOME**에서 실행.
- 안드로이드 내보내기는 편집기 설정에 Java SDK 경로가 필요 (임시 HOME 설정에 JDK 17 경로를 넣어 사용).
- Chrome 확장(Claude in Chrome): 구글 플레이 콘솔·AdMob·Cloudflare 로그인 상태로 사용 중. 비밀번호·결제·약관 동의는 사용자가 직접.
- 웹 사이트 저장소: `/Users/2z/Desktop/workspace/show4you` (정적 사이트, 푸시하면 배포). 다른 프로젝트의 미커밋 변경이 섞여 있으므로 **내 파일만 골라서 커밋**.

## 6. 이 문서를 읽은 세션이 첫 5분에 할 일

1. `git log --oneline | head -10` 와 `git status --short` 로 상태 확인.
2. `pmset -g batt`, `pgrep -fl "mflux|gen_story|batch_story|run_all"` 로 배터리·남은 프로세스 확인.
3. 사용자에게 지금 무엇부터 할지 확인 (위 3번 표의 순서가 기본 제안).
4. 이미지 작업 전에 `docs/art/story_portraits/scripts/progress.log` 의 마지막 줄과 `final/` 상태를 보고 이어서 진행.
