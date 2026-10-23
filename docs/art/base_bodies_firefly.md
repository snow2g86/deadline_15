# 기본 바디 원화 20종 — 파이어플라이 프롬프트 팩

목적: 체형 20종(남 10, 여 10)을 T포즈 기본 바디로 만들고, 정면·측면·후면 3면 원화를 3D 모델링 기준으로 쓴다.
이후 무기·갑옷·머리·얼굴은 이 바디 위에 얹는다.

## 규칙(공통)
- SD 4등신(머리:키 = 1:4) 고정. 체형 차이는 "키 비율 / 어깨 너비 / 허리·엉덩이 / 팔다리 굵기 / 근육·지방"으로만 낸다.
- T포즈: 두 팔을 수평으로 펴고 손바닥은 아래, **손가락 5개가 서로 벌어져 모두 보이게**, 다리는 어깨너비로 벌림, 정면 응시, 무표정.
- 바디 표현: 매끈한 마네킹 같은 무채색 기본 바디. 체형 파악용 단색 회색 속옷 레이어(남: 짧은 팬츠 / 여: 짧은 팬츠+스포츠 탑)만 입힌다.
  (완전 나체는 파이어플라이가 생성을 막고, 게임용 기본 메시도 해부학 묘사가 필요 없어 이 방식이 표준이다.)
- 배경 단색 회색, 그림자 최소, 장비·장신구·글자 없음, 한 장에 한 캐릭터.
- 3면(정면/측면/후면)은 **같은 캐릭터**여야 한다: 정면을 먼저 만들고 파이어플라이의 '참조 이미지(구조/스타일)'로 측면·후면을 만든다.

## 공통 프롬프트 틀 (영문)
```
Game character base body reference sheet, chibi proportions (4 heads tall), strict T-pose, arms extended horizontally,
palms facing down, all five fingers clearly separated and visible on both hands, legs shoulder-width apart,
neutral expression, plain mannequin-like smooth gray base body wearing plain gray base-layer shorts{ + sports top for female},
solid light gray background, flat even lighting, full body, orthographic {FRONT|SIDE|BACK} view,
body type: {체형 설명}, clean 3D-modeling reference, no clothing details, no accessories, no text
```
측면: `orthographic SIDE view, arms still extended in T-pose` / 후면: `orthographic BACK view`.

## 체형 목록

### 남성 (M01~M10)
| ID | 체형 | {체형 설명} |
|---|---|---|
| M01 | 표준 | average build, balanced shoulders and waist |
| M02 | 근육질 | muscular athletic build, broad shoulders, thick arms and chest |
| M03 | 거구 | very large heavy-set warrior build, huge shoulders, thick neck and thighs |
| M04 | 마른 | thin lanky build, narrow shoulders, long thin limbs |
| M05 | 작고 단단 | short stocky build, compact, strong short legs |
| M06 | 길쭉 날렵 | tall slim agile build, long legs, narrow waist |
| M07 | 통통 | round chubby build, soft belly, thick arms |
| M08 | 역삼각 | V-shaped torso, very wide shoulders, narrow waist |
| M09 | 소년 | boyish slim youth build, small frame, slightly shorter |
| M10 | 중년 | middle-aged sturdy build, broad torso, slightly thick waist |

### 여성 (F01~F10)
| ID | 체형 | {체형 설명} |
|---|---|---|
| F01 | 표준 | average build, balanced proportions |
| F02 | 슬림 | slim slender build, narrow shoulders and hips |
| F03 | 운동선수 | athletic toned build, defined arms and legs, strong shoulders |
| F04 | 근육질 | muscular strong build, broad shoulders, thick arms and thighs |
| F05 | 곡선형 | curvy build, wider hips, defined waist |
| F06 | 작은 체구 | petite small frame, short, slim limbs |
| F07 | 키 큰 | tall long-limbed build, long legs, elegant posture |
| F08 | 통통 | soft plump build, round arms and thighs |
| F09 | 소녀 | girlish slim youth build, small frame |
| F10 | 중년 | mature sturdy build, broad shoulders, solid waist |

## 작업 순서(제안)
1. 정면 20장 먼저 → 체형이 서로 충분히 달라 보이는지 확인.
2. 통과한 체형만 측면·후면 생성(정면을 참조로).
3. 확정한 체형부터 Blender로 기본 바디 메시(공용 뼈대) 제작 → 갑옷·무기는 공용 뼈대에 얹는 구조.
