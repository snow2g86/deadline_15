// data/story/story.sample.js — 연출 개발·검증용 작은 샘플 대본 (실제 대본은 story.ko.js)
// 사용: Store.set('game_story_dev', 'sample') 후 새로고침. 해제: Store.remove('game_story_dev')
window.STORY_KO = {
  cast: {
    commander: { name: '레온', portrait: 'commander', role: '클랜 지휘관' },
    narrator:  { name: '', portrait: null },
    mira:      { name: '미라', portrait: 'priest_02', role: '클랜 치유사' },
    bran:      { name: '브란', portrait: 'warrior_01', role: '마을 대장장이' },
  },
  episodes: {
    1: {
      title: '영웅의 시작',
      prologue: [
        { who: 'narrator', text: '[샘플] 국경 마을 하젤에 산적의 그림자가 드리웠다.' },
        { who: 'bran', text: '{commander}, 놈들이 또 창고를 털어 갔소!', mood: 'angry' },
        { who: 'commander', text: '더는 두고 볼 수 없어. 자경단을 모으자.' },
        { who: 'mira', text: '다치는 사람은 제가 돌볼게요.', mood: 'worried' },
      ],
      epilogue: [
        { who: 'narrator', text: '[샘플] 산적단은 무너졌지만, 북쪽 하늘은 차갑게 식어 가고 있었다.' },
        { who: 'commander', text: '이걸로 끝이 아닌 것 같아.' },
      ],
    },
  },
  stages: {
    1: {
      pre: [
        { who: 'mira', text: '[샘플] 마을 입구에 산적 척후병이 보여요.' },
        { who: 'commander', text: '모두 진형을 유지해! 문을 지킨다.', mood: 'shout' },
      ],
      post: [
        { who: 'bran', text: '[샘플] 해냈군! 오늘 밤은 내가 한잔 사지.', mood: 'happy' },
        { who: 'commander', text: '아직 시작일 뿐이야.' },
      ],
      battle: {
        start:  [{ who: 'commander', text: '[샘플] 전원, 전투 준비!' }],
        wave:   [{ who: 'mira', text: '[샘플] 증원이에요! 숲 쪽에서 더 와요!', mood: 'worried' }],
        danger: [{ who: 'mira', text: '[샘플] {ally}, 물러나세요!', mood: 'shout' }],
        last:   [{ who: 'commander', text: '[샘플] 하나 남았다. 끝내자!' }],
      },
    },
    10: {
      battle: {
        boss: [{ who: 'boss', text: '[샘플] 하찮은 자경단 따위가!', mood: 'angry' }],
      },
    },
  },
};
