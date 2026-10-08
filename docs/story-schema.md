# 스토리 대본 데이터 형식 (작가 ↔ 연출 공통 약속)

대본 파일: `data/story/story.ko.js` (한국어 원문). 영어·스페인어는 같은 형식으로 `story.en.js`, `story.es.js`를 두며, 없으면 한국어로 대체한다.

```js
window.STORY_KO = {
  // 등장인물. 대사의 who 값이 이 키를 가리킨다
  cast: {
    commander: { name: '리안', portrait: 'commander', role: '주인공 · 클랜 지휘관' },  // 지휘관(플레이어). name은 기본값(COMMANDER_DEFAULT_NAME)이며 플레이어가 바꾼 이름이 우선. 전투에는 나가지 않는다
    narrator:  { name: '', portrait: null },                                          // 내레이션 (초상화 없음, 가운데 정렬)
    // 그 밖의 인물: portrait는 아래 '초상화 키' 중 하나
    // mira: { name: '미라', portrait: 'priest_02', role: '클랜 치유사' },
  },

  // 에피소드 시작·끝 장면 (1~10)
  episodes: {
    1: { title: '영웅의 시작', prologue: [ /* 대사 */ ], epilogue: [ /* 대사 */ ] },
  },

  // 스테이지별 (1~100). 없는 항목은 생략 가능
  stages: {
    1: {
      pre:  [ /* 전투 시작 전 대화 (스테이지 선택 후 출전 직전) */ ],
      post: [ /* 승리 후 대화 (결과 화면 직전) */ ],
      battle: {                     // 전투 중 짧은 대사 (각 1~2줄 권장, 화면을 오래 가리지 않게)
        start:  [ /* 첫 차례 시작 시 */ ],
        wave:   [ /* 두 번째 증원(웨이브) 등장 시, 한 번만 */ ],
        boss:   [ /* 보스가 처음 보일 때 (보스 스테이지) */ ],
        danger: [ /* 클랜원(소환수 제외) 누군가가 그 전투에서 처음으로 HP 30% 아래로 떨어졌을 때 1회. {ally} 사용 가능 */ ],
        last:   [ /* 남은 적이 마지막 1명일 때 */ ],
      },
    },
  },
};
```

## 대사(line) 한 줄
```js
{ who: 'commander', text: '모두 진형을 유지해!' }
{ who: 'narrator', text: '북쪽 산맥에서 차가운 바람이 내려왔다.' }
{ who: 'boss', text: '하찮은 자경단 따위가!' }          // 그 스테이지 보스 (STAGES[i].boss.name, 초상화는 보스 직업 그림 + 붉은 기운)
{ who: 'mira', text: '{commander}, 부상자가 많아요.', mood: 'worried' }   // mood: 선택 (normal|angry|worried|happy|sad|shout)
```

- `{commander}` 는 지휘관 이름으로 바뀐다. 지휘관 성별은 플레이어가 고를 수 있으므로 **지휘관을 가리키는 성별 대명사(그/그녀)는 쓰지 않는다.**
- `{ally}` 는 위기(danger) 대사에서 HP 30% 아래로 떨어진 클랜원 이름으로 바뀐다. 이름을 알 수 없을 때(다시 보기 등)는 `story.ally`("클랜원"). `{commander}`·`{ally}` 뒤에는 받침에 따라 바뀌는 조사를 붙이지 않는다.
- 지휘관은 전투에 나가지 않는다: 전투 중 대사에서 지휘관은 후방에서 명령하는 목소리로만 쓴다(부상·노출·돌격 묘사 금지). 지휘관 스킬은 없으므로 스킬 이름을 쓰지 않는다. 지휘봉은 명령·신호의 상징이며 음악 은유로 쓰지 않는다.
- 한 줄은 최대 37자 정도(모바일 대화창 2줄). 길면 여러 줄로 나눈다.
- 스테이지 pre/post는 각 2~6줄, 에피소드 prologue/epilogue는 6~14줄 권장.

## 초상화 키
- `commander` — 지휘관 (image/character/commander_01.png 남 / commander_02.png 여, 플레이어 지휘관 성별을 따름)
- 직업 그림: `<직업>_01`(남) `<직업>_02`(여), 직업 = warrior, knight, assassin, mage, archer, priest, novice, summoner, shaman, brawler, lancer, sapper
- `null` — 초상화 없음

## 진행 기록 (연출 쪽 구현)
- 이미 본 장면은 localStorage `game_story_seen` 에 `{ "ep1_pro": true, "s1_pre": true, ... }` 로 저장해 다시 보여주지 않는다 (설정·도감에서 다시 보기 가능하면 좋음).
- 모든 장면에 "건너뛰기" 제공.
