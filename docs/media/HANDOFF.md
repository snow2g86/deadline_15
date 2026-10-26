# 미디어(그림·3D) 작업 인계 문서

> 작성 2026-10-25 · 게임 0.4.2 · 다른 세션이 이어서 작업할 수 있게 현재 상태, 결정, 도구, 절차, 남은 일을 한 곳에 정리했습니다.
> 사용자는 비개발자 디렉터입니다. **모든 답변은 한국어**로 하고, 큰 작업은 계획 → 구현 에이전트 → 독립 검수 → 수정 → 커밋·푸시 순서로 진행합니다. (메모리: `~/.claude/projects/-Users-2z-Desktop-workspace-game-deadline-15/memory/`)

미디어 작업 규칙을 모은 에이전트 지침: `.claude/agents/media-producer.md` (git 제외, 이 PC에만 있음).

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

스토리 초상화 23장 모두 치비 애니풍 반신으로 적용 완료 (17장 `d155d4a` 2026-10-24, 나머지 6장 2026-10-25).

## 2. 스토리 초상화 23장 (완료, 다시 만들 때 참고)

### 2-1. 나머지 6장 결과 (2026-10-25~26)

| 이름 | 적용본 | 메모 |
|---|---|---|
| boss_60 | v12 시드 91 (`gen_b60d.py`, 어두운 강철 투구) | 위 여백 맞추려고 0.894배 축소(아래 끝 722 유지) |
| boss_90 | 이전 합격본 | 몸과 떨어진 창끝 조각 제거 |
| boss_93 | **v13 시드 112** (`gen_chibi13.py`) | CAST대로 악마 마술사: 은발·검은 뿔·뾰족 귀·금테 외눈 안경·보라 숫자 고리. v11본(둥근 안경·초록 넥타이)은 해리 포터 연상으로 검수 탈락 |
| boss_100 | 이전 합격본 | 0.95배 축소로 위 여백 맞춤. 어깨 위 구도 |
| kasha | **v13 시드 113** | 검은 깃털 망토·붉은 줄 한 가닥·쌍단검·비웃음 (v11본은 흰 털 깃·리본·장검이라 탈락) |
| commander_f | **v13 시드 112** (사용자 선택) | 은색 지휘봉. 머리 윤곽 밝은 선·흰 조각·초록 번짐 손 정리 |

- 머리 위 여백 기준: 기존 17장 맨 위 불투명 픽셀 중앙값 107px, 아래 끝 약 722. 새 그림은 아래 끝을 고정하고 축소해 맞춤.
- v13 은 12장 중 10장이 전신으로 나와 허리 위로 자름(1.3~1.4배 확대). `post_story.py`·`clean_v13.py` 는 높이 기준을 옛 도트 그림(`backup_old/`)에서 읽게 고침 — `art_src/story/` 는 이제 새 그림이라 기준이 틀어짐.
- 비교 시트 `compare/v11_*`·`v13_*`, 이전 final 은 `backup_old/final_prev{,2,3}/`, 옛 도트 원본 `backup_old/<키>.png`.
- 검수: 1차 '수정 필요'(위 탈락 사유 + boss_90 조각 + 여백) → 수정 후 재검수 '통과'. 시험 19개·내보내기 5개·check_pc5 105 통과.

재생성 방법(v11): 이미 승인된 치비 결과(raw, `out_selected/`)를 **스타일 참조**로 이식합니다. `gen_chibi.py <이름> <시드>` → `out/v11/<이름>_<시드>_raw.png`.
- **v8(아주 흐린 도트 참조)과 v10(전투 초상화 참조)은 쓰지 말 것** — v8은 더 픽셀화, v10은 현실 비율이 나옴.
- 프롬프트에 `chibi, 2 to 2.5 head-tall proportions, big head, large glossy anime eyes, thick clean outlines, waist-up bust composition` 를 넣고 `realistic proportions, tall slim body, full body` 는 배제.
- 다른 프로젝트(chrono_elemental·deck_tactics)의 영상 배치가 MLX-Serve 에 요청 중이면 메모리 다툼이 나므로 끝날 때까지 기다림. 끝났는지는 **프로세스가 살아 있는지**(`pgrep -fl run_video_batch\|b3_runner`)로 볼 것 — deck_tactics `queue.txt` 는 처리 뒤에도 줄이 지워지지 않아 '비었는지'로 판단하면 영원히 기다림(2026-10-25 밤 16시간 헛대기).

### 2-2. 생성 도구와 명령 (요약)

**작업 폴더: `docs/art/story_portraits/`** (2026-10-25 스크립트 경로를 이 폴더로 고침, 출력 `out/<버전>/`·후처리 `out/<버전>_final/`) (git 제외 대상으로 두거나 커밋하지 말 것, 약 27MB)

| 파일 | 역할 |
|---|---|
| `scripts/gen_story.py` | 캐릭터별 영문 묘사 `DESC`와 mflux 호출. `python3 gen_story.py <이름…> --seed N --v vN` → `out/<v>/<이름>_<시드>_raw.png` (크로마키 배경: 녹색, boss_30/boss_95는 자홍) |
| `scripts/gen_chibi.py` | 승인된 치비 raw를 스타일 참조로 이식 (v11) |
| `scripts/gen_style.py`, `gen_fix.py`, `gen_b60*.py` | boss_60·kasha 등 재시도용 변형 (v9, v10, v12) |
| `scripts/post_story.py`, `post_fix.py` | 크로마키 제거 + 962x1087 RGBA 로 맞춤 → `final/` |
| `scripts/sheet_story.py` | 기존 그림 / 새 그림 나란히 보는 비교 시트 → `compare/` |
| `scripts/run_all.sh` | 순차 배치 (대기 루프 없음. 최대 개수만큼만) |
| `scripts/apply_story.sh` | **게임에 적용**: 크기 검사(962x1087) → `art_src/story/` 원본 보관 → `cwebp -q 85 -m 6 -sharp_yuv -alpha_q 100` → `.webp.import` 확인 |
| `final/` | 게임에 들어간 23장의 후처리본 |
| `scripts/check_clean.py`, `sheet_v11.py` | 흰 테두리·초록 번짐 점검·정리 / 번호 붙인 비교 시트 |
| `out_selected/` | 스타일 참조로 쓰는 승인된 치비 raw 7장 |
| `compare/` | 비교 시트 |
| `backup_old/` | 적용 전 옛 원본 |

mflux 핵심 인자 (gen_story.py 에서): `mflux-generate-qwen-edit --model qwen-image-edit -q 8 --lora Qwen-Image-Edit-2509-Lightning-8steps-V1.0-bf16.safetensors 1.0 --image-paths <참조> --prompt <…> --width 768 --height <16배수> --steps 8 --guidance 1.0 --seed N`. 실행 파일 `~/.local/bin/mflux-generate-qwen-edit`, LoRA 는 `~/.cache/huggingface/hub/models--lightx2v--Qwen-Image-Lightning/...`.
참조 이미지는 기존 도트 그림(`art_src/story/<이름>.png` 의 상단 66%)을 흰 배경에 얹고 강하게 흐려서(`SMOOTH_D=8`, `SMOOTH_B=3`) 질감 전달을 막습니다. 원본 무손실 PNG 는 `godot/assets/image/character/art_src/story/` 에서 읽습니다.

### 2-3. 적용 절차 (사용자 승인 후)

1. `docs/art/story_portraits/final/<이름>.png` 가 962x1087 RGBA 인지 확인.
2. **후처리 점검**: 어두운 배경에 합성해 확대하고 (a) 가장자리 흰 테두리 (b) 초록 번짐(불투명 픽셀 중 G>max(R,B)+60 이고 G>140) (c) 상단이 맨 위에 닿는지를 봅니다. 이전 17장에서 bram·commander_m 흰 테두리, sera·boss_80 등 초록 번짐이 있어 `story_apply/clean.py` 로 정리했습니다(작업 폴더 `story_apply/` 는 휘발성 — 필요하면 다시 작성). 의도된 초록(boss_30 이끼, boss_95 갑옷 장식, boss_94 불꽃)은 보존.
3. `apply_story.sh 이름…` 실행 → `Godot --headless --editor --quit` 로 다시 가져오기(임시 HOME 사용).
4. 대사창·도감·전투 중 보스 등장을 1280x720·pixel8 로 확인 (`godot/tests/shots_*` 참고). 도감 카드는 `codex_view.gd` 의 `_story_thumb()` 가 반신/전신을 맞춥니다.
5. 전체 시험 + 내보내기 + `check_pc5`, 독립 검수 후 커밋·푸시. 절차 문서: `godot/README.md` '용량 줄이기 5. 정면·스토리 WebP'.

## 3. 그 밖의 남은 미디어 작업

| 순서 | 항목 | 상태 | 메모 |
|---|---|---|---|
| 1 | (완료) 스토리 초상화 23장 | 완료 | 위 2번 |
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
