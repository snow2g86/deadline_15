// ═══════════════════════════════════════════
//  battle/rig.js — 2D 조각(컷아웃) 리그
//  캐릭터 PNG 한 장을 부위별 clip-path로 잘라 겹치고, 공격 시 부위를 따로 회전시킨다.
//  새 이미지 없이 원본 도트 그림 그대로 팔·무기를 움직이기 위한 방식.
//  좌표는 모두 원본 PNG 픽셀 기준이며, 원본 그림은 오른쪽을 바라본다.
//  리그가 없는 캐릭터(이미지)는 기존 motion.js의 통째 모션을 그대로 쓴다.
// ═══════════════════════════════════════════

const CUTOUT_RIGS = {
  // 전사(남): 등에 멘 대검을 머리 위로 넘겨 두 손으로 내려친다
  warrior_01: {
    w: 962, h: 1087,
    parts: {
      // 대검 날(머리 왼쪽 위) + 손잡이를 쥔 오른손. 회전 기준 = 손
      sword: { origin: [750, 520], clip: [
        'M0 40 L150 40 L345 175 L330 300 L280 300 L0 165 Z',
        'M590 320 L780 335 L820 430 L962 530 L962 630 L880 640 L780 650 L670 640 L600 560 L570 430 Z'] },
      // 앞쪽 팔(그림 왼쪽 아래 건틀릿). 회전 기준 = 어깨
      arm: { origin: [260, 600], clip: ['M160 600 L305 600 L315 700 L295 815 L190 820 L148 765 L152 640 Z'] },
    },
    order: ['body', 'sword', 'arm'],
    // 원본에서 머리에 가려 보이지 않던 검 가운데 부분 — 검을 들어 올린 동안만 보임 (sword 조각에 포함)
    fill: { part: 'sword', points: '330,180 680,352 630,452 282,282', color: '#b9c3cb' },
    // 검 궤적: 등 뒤(왼쪽 위) → 머리 위 → 앞쪽(오른쪽) 아래 시계 방향 호
    smear: 'M182,62 A650,650 0 0 1 1098,978',
    // 구간: 준비(.3) → 내려치기(.5) → 마무리(.72) → 복귀
    keys: {
      body: [{}, { o: .3, t: 'rotate(-5deg)' }, { o: .5, t: 'rotate(6deg) scale(1.02,.97)' }, { o: .72, t: 'rotate(4deg)' }, {}],
      sword: [{}, { o: .3, t: 'translate(20px,-30px) rotate(-18deg)' }, { o: .5, t: 'translate(-320px,140px) rotate(190deg)' },
        { o: .72, t: 'translate(-310px,146px) rotate(198deg)' }, {}],
      arm: [{}, { o: .3, t: 'rotate(-171deg)' }, { o: .5, t: 'rotate(-87deg)' }, { o: .72, t: 'rotate(-90deg)' }, {}],
      fill: [{ a: 0 }, { o: .36, a: 0 }, { o: .4, a: 1 }, { o: .9, a: 1 }, { o: .97, a: 0 }, { a: 0 }],
      smear: [{ a: 0 }, { o: .42, a: 0 }, { o: .47, a: .85 }, { o: .6, a: 0 }, { a: 0 }],
    },
  },
};


// ── 나머지 직업: 무기(또는 시전 도구)를 쥔 손을 한 조각으로 잘라 프리셋 동작으로 움직인다 ──
// w = 무기 조각 { clip, origin(손 또는 어깨) }, preset = _RIG_PRESETS 키
// holes = 조각이 빠지면 드러나는 몸통 구멍: 바로 옆 몸통 픽셀을 dx(px)만큼 밀어 와서 메움 (단색보다 자연스러움)
Object.assign(CUTOUT_RIGS, {
  // 전사(여): 남자 전사와 같은 구도 — 대검을 머리 위로 넘겨 두 손으로 내려침
  warrior_02: {
    w: 962, h: 1087,
    parts: {
      sword: { origin: [750, 520], clip: [
        'M0 40 L180 40 L400 180 L395 240 L300 310 L250 300 L0 150 Z',
        'M600 320 L780 335 L820 430 L962 530 L962 630 L880 640 L780 650 L670 640 L600 560 L580 430 Z'] },
      arm: { origin: [255, 610], clip: ['M185 605 L310 600 L325 700 L300 795 L200 805 L178 760 Z'] },
    },
    order: ['body', 'sword', 'arm'],
    fill: { part: 'sword', points: '360,200 690,352 640,452 300,290', color: '#b9c3cb' },
    smear: 'M182,62 A650,650 0 0 1 1098,978',
    keys: null, // warrior_01 키 재사용 (아래)
  },
  knight_01:   { preset: 'bash',  w: { origin: [700, 620], clip: ['M610 330 L700 300 L800 330 L945 268 L952 962 L800 952 L610 905 Z'] },
                 holes: [{ points: '600,300 712,300 712,905 600,905', dx: 110 }] },
  knight_02:   { preset: 'slash', w: { origin: [612, 700], clip: ['M560 655 L645 655 L705 715 L948 900 L942 962 L878 955 L640 805 L565 765 Z'] } },
  lancer_01:   { preset: 'thrust', w: { origin: [745, 650], clip: ['M688 15 L812 15 L812 1087 L718 1087 L700 712 L688 590 Z'] } },
  lancer_02:   { preset: 'thrust', w: { origin: [752, 650], clip: ['M690 15 L832 15 L822 1087 L728 1087 L700 712 L690 590 Z'] } },
  assassin_01: { preset: 'stab',  w: { origin: [482, 640], clip: ['M328 772 L458 642 L498 538 L542 545 L522 642 L482 702 L358 802 Z'] } },
  assassin_02: { preset: 'stab',  w: { origin: [450, 640], clip: ['M408 588 L472 588 L494 702 L428 712 Z'] } },
  novice_01:   { preset: 'bash',  w: { origin: [700, 640], clip: ['M618 468 L782 468 L852 558 L852 762 L762 832 L640 822 L606 700 Z'] },
                 holes: [{ points: '600,470 704,470 704,822 600,822', dx: 100 }] },
  novice_02:   { preset: 'stab',  w: { origin: [300, 520], clip: ['M158 540 L300 478 L342 560 L472 788 L442 822 L300 762 L168 652 Z'] } },
  brawler_01:  { preset: 'punch', w: { origin: [620, 460], clip: ['M598 418 L692 518 L738 640 L732 732 L640 748 L588 652 L572 518 Z'] } },
  brawler_02:  { preset: 'punch', w: { origin: [578, 500], clip: ['M558 468 L642 518 L702 640 L692 732 L610 738 L568 640 L543 540 Z'] } },
  archer_01:   { preset: 'bow',   w: { origin: [662, 742], clip: ['M560 560 L690 420 L800 398 L948 392 L948 432 L800 470 L760 600 L742 760 L700 822 L610 882 L560 870 Z'] } },
  archer_02:   { preset: 'bow',   w: { origin: [652, 742], clip: ['M560 600 L690 430 L800 398 L948 392 L948 432 L800 470 L760 600 L742 760 L700 822 L610 882 L560 870 Z'] } },
  mage_01:     { preset: 'staff', w: { origin: [745, 580], clip: ['M678 78 L852 78 L852 400 L802 642 L762 1002 L688 1002 L700 642 L678 518 Z'] } },
  mage_02:     { preset: 'orb',   w: { origin: [700, 560], clip: ['M628 308 L872 308 L872 612 L700 612 L628 522 Z'] } },
  priest_01:   { preset: 'staff', w: { origin: [750, 600], clip: ['M688 58 L872 58 L872 300 L802 520 L802 652 L722 982 L668 982 L700 652 L700 540 Z'] } },
  priest_02:   { preset: 'staff', w: { origin: [650, 590], clip: ['M588 38 L872 38 L872 300 L722 332 L692 520 L702 662 L602 992 L538 992 L600 662 L588 528 Z'] } },
  shaman_01:   { preset: 'orb',   w: { origin: [680, 620], clip: ['M638 368 L862 368 L862 672 L638 672 Z'] } },
  shaman_02:   { preset: 'orb',   w: { origin: [690, 580], clip: ['M638 268 L852 268 L852 622 L638 622 Z'] } },
  summoner_01: { preset: 'book',  w: { origin: [620, 700], clip: ['M418 378 L560 398 L760 328 L882 378 L802 562 L702 722 L600 742 L428 702 Z'] },
                 holes: [{ points: '418,380 882,380 802,562 702,722 428,702', dy: -170 }] },
  summoner_02: { preset: 'staff', w: { origin: [255, 600], clip: ['M138 138 L262 138 L302 400 L302 662 L292 1056 L228 1056 L214 662 L148 300 Z'] } },
  sapper_01:   { preset: 'smash', w: { origin: [740, 640], clip: ['M678 520 L758 368 L948 368 L948 522 L822 602 L802 702 L700 712 L668 622 Z'] } },
  sapper_02:   { preset: 'smash', w: { origin: [650, 640], clip: ['M608 538 L842 538 L842 712 L618 712 Z'] } },
});
CUTOUT_RIGS.warrior_02.keys = CUTOUT_RIGS.warrior_01.keys;

// 프리셋: h = 타격 시점(ATK_MOTIONS[cls].hit). 준비 → 타격(h) → 마무리 → 복귀
// 키 형식: { o: 진행률, t: transform } — w 조각은 손(어깨) 기준 회전, 원본 그림은 오른쪽을 바라봄(+x = 앞)
const _RIG_PRESETS = {
  // 한손검: 아래로 든 검을 뒤로 치켜들었다가 앞쪽 아래로 벰
  slash: h => [{}, { o: h * .6, t: 'rotate(-115deg)' }, { o: h, t: 'translate(30px,10px) rotate(22deg)' }, { o: Math.min(h + .2, .9), t: 'translate(24px,8px) rotate(28deg)' }, {}],
  // 창: 앞으로 눕혀 겨눈 뒤 길게 찌름
  thrust: h => [{}, { o: h * .65, t: 'translate(-40px,0) rotate(64deg)' }, { o: h, t: 'translate(170px,10px) rotate(82deg)' }, { o: Math.min(h + .2, .9), t: 'translate(130px,10px) rotate(82deg)' }, {}],
  // 방패 밀치기
  bash: h => [{}, { o: h * .6, t: 'translate(-30px,0) rotate(-4deg)' }, { o: h, t: 'translate(120px,-6px) rotate(7deg)' }, { o: Math.min(h + .2, .9), t: 'translate(80px,0) rotate(3deg)' }, {}],
  // 단검: 몸을 날리며 두 번 그음 (h = 첫 타격)
  stab: h => [{}, { o: h * .5, t: 'rotate(25deg)' }, { o: h, t: 'translate(70px,-20px) rotate(-105deg)' }, { o: h + .16, t: 'translate(50px,-6px) rotate(-55deg)' },
    { o: h + .32, t: 'translate(70px,-20px) rotate(-105deg)' }, {}],
  // 주먹 연타: 잽 · 잽 · 스트레이트 (어깨 기준으로 팔을 앞으로 뻗음)
  punch: () => [{}, { o: .12, t: 'rotate(-85deg)' }, { o: .24, t: 'rotate(-25deg)' }, { o: .38, t: 'rotate(-85deg)' },
    { o: .5, t: 'rotate(-25deg)' }, { o: .66, t: 'translate(40px,-10px) rotate(-95deg)' }, {}],
  // 활: 활을 들어 겨누고 시위를 당겼다 놓으며 반동
  bow: h => [{}, { o: h * .7, t: 'translate(-12px,-6px) rotate(-14deg)' }, { o: h, t: 'translate(-26px,-6px) rotate(-14deg)' }, { o: Math.min(h + .1, .9), t: 'translate(12px,-4px) rotate(-8deg)' }, {}],
  // 지팡이: 치켜들었다가 적을 향해 앞으로 기울임
  staff: h => [{}, { o: h * .7, t: 'translate(0,-50px) rotate(-12deg)' }, { o: h, t: 'translate(40px,-20px) rotate(28deg)' }, { o: Math.min(h + .2, .9), t: 'translate(30px,-10px) rotate(20deg)' }, {}],
  // 구슬·부적: 끌어당겼다가 앞으로 내밂
  orb: h => [{}, { o: h * .7, t: 'translate(-24px,-40px) scale(.95)' }, { o: h, t: 'translate(80px,-30px) scale(1.14)' }, { o: Math.min(h + .2, .9), t: 'translate(56px,-20px) scale(1.06)' }, {}],
  // 마도서: 들어 올려 펼쳐 보임
  book: h => [{}, { o: h * .7, t: 'translate(0,-40px) rotate(-6deg)' }, { o: h, t: 'translate(50px,-30px) rotate(6deg) scale(1.06)' }, { o: Math.min(h + .2, .9), t: 'translate(36px,-20px) rotate(4deg)' }, {}],
  // 렌치: 뒤로 치켜들었다가 앞으로 내려찍음
  smash: h => [{}, { o: h * .6, t: 'rotate(-75deg)' }, { o: h, t: 'translate(30px,20px) rotate(48deg)' }, { o: Math.min(h + .16, .9), t: 'translate(26px,18px) rotate(42deg)' }, {}],
};
// 프리셋 리그 공통: 몸통은 준비 때 살짝 뒤로, 타격 때 앞으로 기울임
const _RIG_BODY = h => [{}, { o: h * .6, t: 'rotate(-3deg)' }, { o: h, t: 'rotate(3deg)' }, {}];


// ── 캐릭터 몸 높이 맞춤 ──
// 원본 PNG마다 그림 속 캐릭터 크기가 달라서, 무기를 뺀 몸(머리 끝~발끝) 세로 범위를 재 두고
// 화면에서 몸 높이가 모두 FIG_H(px)가 되게 확대/축소한다 (가로 폭은 달라져도 됨). 발끝은 같은 선에 맞춘다.
// 값 = [머리 끝 y, 발끝 y] (원본 962x1087 기준, 무기 조각 영역 제외하고 측정)
const CHAR_FIG = {
  commander_01: [130, 1030], commander_02: [130, 1030],
    archer_01: [69, 1024], archer_02: [70, 1020], assassin_01: [124, 963], assassin_02: [123, 962],
  brawler_01: [122, 967], brawler_02: [125, 965], knight_01: [90, 994], knight_02: [124, 965],
  lancer_01: [167, 1074], lancer_02: [117, 1074], mage_01: [77, 1015], mage_02: [37, 1041],
  novice_01: [58, 1026], novice_02: [85, 1003], priest_01: [111, 1039], priest_02: [37, 1049],
  sapper_01: [82, 1007], sapper_02: [55, 1032], shaman_01: [54, 1033], shaman_02: [24, 1067],
  summoner_01: [62, 1026], summoner_02: [19, 1047], warrior_01: [162, 1029], warrior_02: [182, 1043],
};
const FIG_H = 50, FIG_FOOT = 3; // 화면 몸 높이(px), 아이콘 아래 가장자리~발끝 간격(px)


// ── 스프라이트 시트 애니메이션 (영상 생성 → tools/video-to-sheet.py) ──
// 동작: idle(대기)·combat(전투대기)·run(달리기)은 반복, attack(공격)·hit(피격)은 1회. 시트가 없는 동작은 정지 그림/리그를 쓴다.
// 서 있는 자세(0번 프레임)는 원본 그림과 같다.
// w/h = 한 칸 크기, body = 0번 프레임의 몸 [위, 아래] y, cx = 0번 프레임 몸 중심 x, icx = 원본 PNG의 몸 중심 x
// hit = 타격 프레임 번호 (피해 숫자·피격 이펙트가 이 프레임에 뜸), dur = 전체 재생 시간(ms)
const SPRITE_SHEETS = {
  // 기사(남): 몸을 비틀어 검을 치켜든 뒤 한 번 크게 벰 — 베고 내딛는 순간에서 끝 (로컬 MiniMax H3, seed 19)
  knight_01: {
    attack: { src: 'image/character/anim/knight_01_attack.png', frames: 14, w: 219, h: 160, body: [51, 148], cx: 111.0, icx: 480.5, dur: 840, hit: 8 },
    idle: { src: 'image/character/anim/knight_01_idle.png', frames: 12, w: 167, h: 160, body: [3, 156], cx: 84.0, icx: 480.5, dur: 2400 },
    combat: { src: 'image/character/anim/knight_01_combat.png', frames: 12, w: 167, h: 160, body: [3, 156], cx: 82.0, icx: 480.5, dur: 1600 },
    run: { src: 'image/character/anim/knight_01_run.png', frames: 14, w: 168, h: 160, body: [8, 154], cx: 95.5, icx: 480.5, dur: 1500 },
    hit: { src: 'image/character/anim/knight_01_hit.png', frames: 9, w: 174, h: 160, body: [8, 156], cx: 93.5, icx: 480.5, dur: 520, hit: 3 },
  },
  archer_01: {
    attack: { src: 'image/character/anim/archer_01_attack.png', frames: 14, w: 200, h: 160, body: [14, 156], cx: 73.0, icx: 479.5, dur: 840, hit: 4 },
    combat: { src: 'image/character/anim/archer_01_combat.png', frames: 12, w: 158, h: 160, body: [4, 156], cx: 76.5, icx: 479.5, dur: 1600 },
    hit: { src: 'image/character/anim/archer_01_hit.png', frames: 9, w: 206, h: 160, body: [3, 156], cx: 127.5, icx: 479.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/archer_01_idle.png', frames: 12, w: 157, h: 160, body: [4, 156], cx: 78.5, icx: 479.5, dur: 2400 },
    run: { src: 'image/character/anim/archer_01_run.png', frames: 14, w: 151, h: 160, body: [7, 156], cx: 71.5, icx: 479.5, dur: 1500 },
  },
  archer_02: {
    attack: { src: 'image/character/anim/archer_02_attack.png', frames: 14, w: 209, h: 160, body: [15, 157], cx: 74.0, icx: 483.0, dur: 840, hit: 4 },
    combat: { src: 'image/character/anim/archer_02_combat.png', frames: 12, w: 158, h: 160, body: [4, 157], cx: 77.5, icx: 483.0, dur: 1600 },
    hit: { src: 'image/character/anim/archer_02_hit.png', frames: 9, w: 184, h: 160, body: [3, 131], cx: 117.5, icx: 483.0, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/archer_02_idle.png', frames: 12, w: 158, h: 160, body: [4, 157], cx: 79.0, icx: 483.0, dur: 2400 },
    run: { src: 'image/character/anim/archer_02_run.png', frames: 14, w: 144, h: 160, body: [7, 156], cx: 71.5, icx: 483.0, dur: 1500 },
  },
  assassin_01: {
    attack: { src: 'image/character/anim/assassin_01_attack.png', frames: 14, w: 292, h: 160, body: [6, 155], cx: 97.5, icx: 481.0, dur: 840, hit: 11 },
    combat: { src: 'image/character/anim/assassin_01_combat.png', frames: 12, w: 120, h: 160, body: [4, 157], cx: 59.0, icx: 481.0, dur: 1600 },
    hit: { src: 'image/character/anim/assassin_01_hit.png', frames: 9, w: 158, h: 160, body: [82, 159], cx: 58.0, icx: 481.0, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/assassin_01_idle.png', frames: 12, w: 109, h: 160, body: [4, 155], cx: 55.0, icx: 481.0, dur: 2400 },
    run: { src: 'image/character/anim/assassin_01_run.png', frames: 14, w: 127, h: 160, body: [7, 155], cx: 63.5, icx: 481.0, dur: 1500 },
  },
  assassin_02: {
    attack: { src: 'image/character/anim/assassin_02_attack.png', frames: 14, w: 258, h: 160, body: [3, 155], cx: 89.5, icx: 483.5, dur: 840, hit: 10 },
    combat: { src: 'image/character/anim/assassin_02_combat.png', frames: 12, w: 107, h: 160, body: [3, 155], cx: 49.0, icx: 483.5, dur: 1600 },
    hit: { src: 'image/character/anim/assassin_02_hit.png', frames: 9, w: 142, h: 160, body: [81, 153], cx: 50.5, icx: 483.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/assassin_02_idle.png', frames: 12, w: 107, h: 160, body: [3, 157], cx: 52.0, icx: 483.5, dur: 2400 },
    run: { src: 'image/character/anim/assassin_02_run.png', frames: 14, w: 111, h: 160, body: [6, 152], cx: 57.5, icx: 483.5, dur: 1500 },
  },
  brawler_01: {
    attack: { src: 'image/character/anim/brawler_01_attack.png', frames: 14, w: 170, h: 160, body: [4, 156], cx: 57.5, icx: 480.5, dur: 840, hit: 8 },
    combat: { src: 'image/character/anim/brawler_01_combat.png', frames: 12, w: 122, h: 160, body: [3, 156], cx: 59.0, icx: 480.5, dur: 1600 },
    hit: { src: 'image/character/anim/brawler_01_hit.png', frames: 9, w: 152, h: 160, body: [5, 150], cx: 104.0, icx: 480.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/brawler_01_idle.png', frames: 12, w: 106, h: 160, body: [3, 156], cx: 51.0, icx: 480.5, dur: 2400 },
    run: { src: 'image/character/anim/brawler_01_run.png', frames: 14, w: 127, h: 160, body: [8, 153], cx: 64.0, icx: 480.5, dur: 1500 },
  },
  brawler_02: {
    attack: { src: 'image/character/anim/brawler_02_attack.png', frames: 14, w: 217, h: 160, body: [4, 156], cx: 49.0, icx: 480.0, dur: 840, hit: 9 },
    combat: { src: 'image/character/anim/brawler_02_combat.png', frames: 12, w: 103, h: 160, body: [4, 156], cx: 45.0, icx: 480.0, dur: 1600 },
    hit: { src: 'image/character/anim/brawler_02_hit.png', frames: 9, w: 140, h: 160, body: [0, 157], cx: 91.5, icx: 480.0, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/brawler_02_idle.png', frames: 12, w: 91, h: 160, body: [4, 155], cx: 44.5, icx: 480.0, dur: 2400 },
    run: { src: 'image/character/anim/brawler_02_run.png', frames: 14, w: 104, h: 160, body: [6, 155], cx: 54.5, icx: 480.0, dur: 1500 },
  },
  knight_02: {
    attack: { src: 'image/character/anim/knight_02_attack.png', frames: 14, w: 225, h: 160, body: [29, 157], cx: 101.5, icx: 480.0, dur: 840, hit: 10 },
    combat: { src: 'image/character/anim/knight_02_combat.png', frames: 12, w: 193, h: 160, body: [4, 156], cx: 90.5, icx: 480.0, dur: 1600 },
    hit: { src: 'image/character/anim/knight_02_hit.png', frames: 9, w: 191, h: 160, body: [25, 156], cx: 106.5, icx: 480.0, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/knight_02_idle.png', frames: 12, w: 175, h: 160, body: [3, 156], cx: 87.5, icx: 480.0, dur: 2400 },
    run: { src: 'image/character/anim/knight_02_run.png', frames: 14, w: 185, h: 160, body: [6, 150], cx: 90.0, icx: 480.0, dur: 1500 },
  },
  lancer_01: {
    attack: { src: 'image/character/anim/lancer_01_attack.png', frames: 14, w: 262, h: 160, body: [4, 156], cx: 82.5, icx: 482.5, dur: 840, hit: 11 },
    combat: { src: 'image/character/anim/lancer_01_combat.png', frames: 12, w: 127, h: 160, body: [4, 156], cx: 59.0, icx: 482.5, dur: 1600 },
    hit: { src: 'image/character/anim/lancer_01_hit.png', frames: 9, w: 262, h: 160, body: [21, 157], cx: 81.5, icx: 482.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/lancer_01_idle.png', frames: 12, w: 114, h: 160, body: [4, 156], cx: 55.5, icx: 482.5, dur: 2400 },
    run: { src: 'image/character/anim/lancer_01_run.png', frames: 14, w: 110, h: 160, body: [7, 156], cx: 56.0, icx: 482.5, dur: 1500 },
  },
  lancer_02: {
    attack: { src: 'image/character/anim/lancer_02_attack.png', frames: 14, w: 283, h: 160, body: [1, 156], cx: 83.5, icx: 481.5, dur: 840, hit: 9 },
    combat: { src: 'image/character/anim/lancer_02_combat.png', frames: 12, w: 126, h: 160, body: [4, 156], cx: 60.5, icx: 481.5, dur: 1600 },
    hit: { src: 'image/character/anim/lancer_02_hit.png', frames: 9, w: 203, h: 160, body: [52, 158], cx: 77.0, icx: 481.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/lancer_02_idle.png', frames: 12, w: 119, h: 160, body: [4, 156], cx: 54.5, icx: 481.5, dur: 2400 },
    run: { src: 'image/character/anim/lancer_02_run.png', frames: 14, w: 129, h: 160, body: [7, 155], cx: 72.5, icx: 481.5, dur: 1500 },
  },
  mage_01: {
    attack: { src: 'image/character/anim/mage_01_attack.png', frames: 14, w: 210, h: 160, body: [43, 158], cx: 70.0, icx: 483.0, dur: 840, hit: 7 },
    combat: { src: 'image/character/anim/mage_01_combat.png', frames: 12, w: 153, h: 160, body: [4, 155], cx: 73.0, icx: 483.0, dur: 1600 },
    hit: { src: 'image/character/anim/mage_01_hit.png', frames: 9, w: 192, h: 160, body: [69, 159], cx: 74.5, icx: 483.0, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/mage_01_idle.png', frames: 12, w: 143, h: 160, body: [4, 157], cx: 69.5, icx: 483.0, dur: 2400 },
    run: { src: 'image/character/anim/mage_01_run.png', frames: 14, w: 137, h: 160, body: [5, 155], cx: 75.0, icx: 483.0, dur: 1500 },
  },
  mage_02: {
    attack: { src: 'image/character/anim/mage_02_attack.png', frames: 14, w: 246, h: 160, body: [18, 157], cx: 74.0, icx: 481.5, dur: 840, hit: 10 },
    combat: { src: 'image/character/anim/mage_02_combat.png', frames: 12, w: 129, h: 160, body: [3, 156], cx: 63.0, icx: 481.5, dur: 1600 },
    hit: { src: 'image/character/anim/mage_02_hit.png', frames: 9, w: 223, h: 160, body: [44, 151], cx: 81.5, icx: 481.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/mage_02_idle.png', frames: 12, w: 126, h: 160, body: [4, 156], cx: 63.5, icx: 481.5, dur: 2400 },
    run: { src: 'image/character/anim/mage_02_run.png', frames: 14, w: 131, h: 160, body: [7, 154], cx: 67.0, icx: 481.5, dur: 1500 },
  },
  novice_01: {
    attack: { src: 'image/character/anim/novice_01_attack.png', frames: 14, w: 281, h: 160, body: [4, 155], cx: 121.5, icx: 479.0, dur: 840, hit: 9 },
    combat: { src: 'image/character/anim/novice_01_combat.png', frames: 12, w: 121, h: 160, body: [13, 157], cx: 61.0, icx: 479.0, dur: 1600 },
    hit: { src: 'image/character/anim/novice_01_hit.png', frames: 9, w: 281, h: 160, body: [7, 135], cx: 110.0, icx: 479.0, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/novice_01_idle.png', frames: 12, w: 130, h: 160, body: [4, 157], cx: 64.5, icx: 479.0, dur: 2400 },
    run: { src: 'image/character/anim/novice_01_run.png', frames: 14, w: 122, h: 160, body: [6, 154], cx: 66.5, icx: 479.0, dur: 1500 },
  },
  novice_02: {
    attack: { src: 'image/character/anim/novice_02_attack.png', frames: 14, w: 258, h: 160, body: [4, 157], cx: 83.0, icx: 481.0, dur: 840, hit: 9 },
    combat: { src: 'image/character/anim/novice_02_combat.png', frames: 12, w: 124, h: 160, body: [6, 157], cx: 62.0, icx: 481.0, dur: 1600 },
    hit: { src: 'image/character/anim/novice_02_hit.png', frames: 9, w: 204, h: 160, body: [56, 159], cx: 69.0, icx: 481.0, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/novice_02_idle.png', frames: 12, w: 119, h: 160, body: [4, 155], cx: 57.5, icx: 481.0, dur: 2400 },
    run: { src: 'image/character/anim/novice_02_run.png', frames: 14, w: 115, h: 160, body: [8, 155], cx: 66.5, icx: 481.0, dur: 1500 },
  },
  priest_01: {
    attack: { src: 'image/character/anim/priest_01_attack.png', frames: 14, w: 225, h: 160, body: [26, 153], cx: 86.5, icx: 480.5, dur: 840, hit: 7 },
    combat: { src: 'image/character/anim/priest_01_combat.png', frames: 12, w: 145, h: 160, body: [5, 156], cx: 72.0, icx: 480.5, dur: 1600 },
    hit: { src: 'image/character/anim/priest_01_hit.png', frames: 9, w: 162, h: 160, body: [81, 159], cx: 62.5, icx: 480.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/priest_01_idle.png', frames: 12, w: 142, h: 160, body: [3, 156], cx: 72.5, icx: 480.5, dur: 2400 },
    run: { src: 'image/character/anim/priest_01_run.png', frames: 14, w: 130, h: 160, body: [13, 154], cx: 66.5, icx: 480.5, dur: 1500 },
  },
  priest_02: {
    attack: { src: 'image/character/anim/priest_02_attack.png', frames: 14, w: 171, h: 160, body: [43, 138], cx: 54.0, icx: 482.0, dur: 840, hit: 10 },
    combat: { src: 'image/character/anim/priest_02_combat.png', frames: 12, w: 117, h: 160, body: [4, 156], cx: 59.5, icx: 482.0, dur: 1600 },
    hit: { src: 'image/character/anim/priest_02_hit.png', frames: 9, w: 182, h: 160, body: [73, 159], cx: 71.0, icx: 482.0, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/priest_02_idle.png', frames: 12, w: 134, h: 160, body: [6, 156], cx: 59.0, icx: 482.0, dur: 2400 },
    run: { src: 'image/character/anim/priest_02_run.png', frames: 14, w: 132, h: 160, body: [8, 155], cx: 68.0, icx: 482.0, dur: 1500 },
  },
  sapper_01: {
    attack: { src: 'image/character/anim/sapper_01_attack.png', frames: 14, w: 184, h: 160, body: [41, 144], cx: 57.0, icx: 484.5, dur: 840, hit: 12 },
    combat: { src: 'image/character/anim/sapper_01_combat.png', frames: 12, w: 168, h: 160, body: [4, 155], cx: 84.5, icx: 484.5, dur: 1600 },
    hit: { src: 'image/character/anim/sapper_01_hit.png', frames: 9, w: 170, h: 160, body: [78, 148], cx: 81.0, icx: 484.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/sapper_01_idle.png', frames: 12, w: 172, h: 160, body: [3, 157], cx: 85.5, icx: 484.5, dur: 2400 },
    run: { src: 'image/character/anim/sapper_01_run.png', frames: 14, w: 152, h: 160, body: [8, 154], cx: 83.5, icx: 484.5, dur: 1500 },
  },
  sapper_02: {
    attack: { src: 'image/character/anim/sapper_02_attack.png', frames: 14, w: 162, h: 160, body: [27, 141], cx: 54.5, icx: 479.5, dur: 840, hit: 8 },
    combat: { src: 'image/character/anim/sapper_02_combat.png', frames: 12, w: 129, h: 160, body: [3, 155], cx: 64.0, icx: 479.5, dur: 1600 },
    hit: { src: 'image/character/anim/sapper_02_hit.png', frames: 9, w: 130, h: 160, body: [73, 149], cx: 75.5, icx: 479.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/sapper_02_idle.png', frames: 12, w: 124, h: 160, body: [3, 157], cx: 63.5, icx: 479.5, dur: 2400 },
    run: { src: 'image/character/anim/sapper_02_run.png', frames: 14, w: 123, h: 160, body: [5, 154], cx: 69.5, icx: 479.5, dur: 1500 },
  },
  shaman_01: {
    attack: { src: 'image/character/anim/shaman_01_attack.png', frames: 14, w: 207, h: 160, body: [11, 151], cx: 73.0, icx: 481.0, dur: 840, hit: 11 },
    combat: { src: 'image/character/anim/shaman_01_combat.png', frames: 12, w: 135, h: 160, body: [4, 157], cx: 71.5, icx: 481.0, dur: 1600 },
    hit: { src: 'image/character/anim/shaman_01_hit.png', frames: 9, w: 281, h: 160, body: [27, 155], cx: 110.0, icx: 481.0, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/shaman_01_idle.png', frames: 12, w: 126, h: 160, body: [7, 157], cx: 63.5, icx: 481.0, dur: 2400 },
    run: { src: 'image/character/anim/shaman_01_run.png', frames: 14, w: 126, h: 160, body: [9, 154], cx: 61.5, icx: 481.0, dur: 1500 },
  },
  shaman_02: {
    attack: { src: 'image/character/anim/shaman_02_attack.png', frames: 14, w: 235, h: 160, body: [23, 157], cx: 64.0, icx: 481.5, dur: 840, hit: 10 },
    combat: { src: 'image/character/anim/shaman_02_combat.png', frames: 12, w: 129, h: 160, body: [3, 156], cx: 61.5, icx: 481.5, dur: 1600 },
    hit: { src: 'image/character/anim/shaman_02_hit.png', frames: 9, w: 92, h: 160, body: [80, 143], cx: 49.5, icx: 481.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/shaman_02_idle.png', frames: 12, w: 119, h: 160, body: [4, 156], cx: 58.0, icx: 481.5, dur: 2400 },
    run: { src: 'image/character/anim/shaman_02_run.png', frames: 14, w: 126, h: 160, body: [8, 155], cx: 64.0, icx: 481.5, dur: 1500 },
  },
  summoner_01: {
    attack: { src: 'image/character/anim/summoner_01_attack.png', frames: 14, w: 177, h: 160, body: [51, 156], cx: 64.5, icx: 478.0, dur: 840, hit: 11 },
    combat: { src: 'image/character/anim/summoner_01_combat.png', frames: 12, w: 142, h: 160, body: [4, 156], cx: 68.5, icx: 478.0, dur: 1600 },
    hit: { src: 'image/character/anim/summoner_01_hit.png', frames: 9, w: 121, h: 160, body: [82, 148], cx: 52.5, icx: 478.0, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/summoner_01_idle.png', frames: 12, w: 135, h: 160, body: [4, 155], cx: 67.0, icx: 478.0, dur: 2400 },
    run: { src: 'image/character/anim/summoner_01_run.png', frames: 14, w: 134, h: 160, body: [7, 155], cx: 70.5, icx: 478.0, dur: 1500 },
  },
  summoner_02: {
    attack: { src: 'image/character/anim/summoner_02_attack.png', frames: 14, w: 211, h: 160, body: [45, 158], cx: 63.0, icx: 479.5, dur: 840, hit: 7 },
    combat: { src: 'image/character/anim/summoner_02_combat.png', frames: 12, w: 117, h: 160, body: [4, 157], cx: 54.5, icx: 479.5, dur: 1600 },
    hit: { src: 'image/character/anim/summoner_02_hit.png', frames: 9, w: 144, h: 160, body: [84, 160], cx: 52.5, icx: 479.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/summoner_02_idle.png', frames: 12, w: 109, h: 160, body: [3, 157], cx: 55.5, icx: 479.5, dur: 2400 },
    run: { src: 'image/character/anim/summoner_02_run.png', frames: 14, w: 136, h: 160, body: [7, 154], cx: 70.5, icx: 479.5, dur: 1500 },
  },
  warrior_01: {
    attack: { src: 'image/character/anim/warrior_01_attack.png', frames: 14, w: 209, h: 160, body: [34, 156], cx: 84.0, icx: 482.5, dur: 840, hit: 11 },
    combat: { src: 'image/character/anim/warrior_01_combat.png', frames: 12, w: 142, h: 160, body: [16, 156], cx: 71.0, icx: 482.5, dur: 1600 },
    hit: { src: 'image/character/anim/warrior_01_hit.png', frames: 9, w: 322, h: 160, body: [4, 157], cx: 117.5, icx: 482.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/warrior_01_idle.png', frames: 12, w: 143, h: 160, body: [16, 156], cx: 72.0, icx: 482.5, dur: 2400 },
    run: { src: 'image/character/anim/warrior_01_run.png', frames: 14, w: 141, h: 160, body: [9, 155], cx: 70.0, icx: 482.5, dur: 1500 },
  },
  warrior_02: {
    attack: { src: 'image/character/anim/warrior_02_attack.png', frames: 14, w: 189, h: 160, body: [38, 153], cx: 72.0, icx: 481.5, dur: 840, hit: 13 },
    combat: { src: 'image/character/anim/warrior_02_combat.png', frames: 12, w: 140, h: 160, body: [14, 156], cx: 70.0, icx: 481.5, dur: 1600 },
    hit: { src: 'image/character/anim/warrior_02_hit.png', frames: 9, w: 196, h: 160, body: [42, 145], cx: 88.0, icx: 481.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/warrior_02_idle.png', frames: 12, w: 155, h: 160, body: [6, 156], cx: 78.5, icx: 481.5, dur: 2400 },
    run: { src: 'image/character/anim/warrior_02_run.png', frames: 14, w: 140, h: 160, body: [12, 156], cx: 68.5, icx: 481.5, dur: 1500 },
  },
  commander_01: {
    attack: { src: 'image/character/anim/commander_01_attack.png', frames: 14, w: 196, h: 160, body: [32, 157], cx: 71.0, icx: 480.5, dur: 840, hit: 9 },
    combat: { src: 'image/character/anim/commander_01_combat.png', frames: 12, w: 128, h: 160, body: [4, 155], cx: 64.5, icx: 480.5, dur: 1600 },
    hit: { src: 'image/character/anim/commander_01_hit.png', frames: 9, w: 171, h: 160, body: [72, 159], cx: 60.5, icx: 480.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/commander_01_idle.png', frames: 12, w: 128, h: 160, body: [3, 155], cx: 66.0, icx: 480.5, dur: 2400 },
    run: { src: 'image/character/anim/commander_01_run.png', frames: 14, w: 130, h: 160, body: [5, 155], cx: 64.0, icx: 480.5, dur: 1500 },
  },
  commander_02: {
    attack: { src: 'image/character/anim/commander_02_attack.png', frames: 14, w: 166, h: 160, body: [33, 157], cx: 55.5, icx: 481.5, dur: 840, hit: 9 },
    combat: { src: 'image/character/anim/commander_02_combat.png', frames: 12, w: 121, h: 160, body: [4, 155], cx: 61.0, icx: 481.5, dur: 1600 },
    hit: { src: 'image/character/anim/commander_02_hit.png', frames: 9, w: 159, h: 160, body: [76, 158], cx: 55.5, icx: 481.5, dur: 520, hit: 3 },
    idle: { src: 'image/character/anim/commander_02_idle.png', frames: 12, w: 121, h: 160, body: [4, 156], cx: 61.0, icx: 481.5, dur: 2400 },
    run: { src: 'image/character/anim/commander_02_run.png', frames: 14, w: 122, h: 160, body: [5, 153], cx: 57.5, icx: 481.5, dur: 1500 },
  },
};

// 구간별 이징 (준비 감속 → 내려치기 가속 → 마무리 → 복귀). 전체 이징을 걸면 키프레임 시점이 밀린다
const _RIG_EASE = ['cubic-bezier(.2,.6,.3,1)', 'cubic-bezier(.6,0,1,.6)', 'ease-out', 'ease-in-out'];

const Rig = {
  base: '', // 이미지 경로 앞부분 (게임은 루트 기준, tools/ 미리보기는 '../')
  key(u) { return u.cls + '_' + ((u.gender || 'm') === 'f' ? '02' : '01'); },

  // 몸 높이 맞춤: { size: 아이콘 폭(px), mb: 아래 여백(px, 음수면 아래로 내림) } — 측정값 없는 캐릭터는 기본 크기
  fit(u, base) {
    const f = CHAR_FIG[this.key(u)]; if (!f) return { size: base, mb: 0 };
    const s = FIG_H / (f[1] - f[0]);
    return { size: Math.round(962 * s), mb: Math.round(FIG_FOOT - (1087 - f[1]) * s) };
  },
  has(u) { return !!CUTOUT_RIGS[this.key(u)]; },

  // .u-icon 안의 <img>를 리그로 교체. 가만히 있을 때는 원본 그림과 똑같이 보인다
  // 프리셋 리그를 공통 형식(parts/order/keys)으로 펼침 — 처음 한 번만
  _norm(def, cls) {
    if (def._ready) return def;
    def.w = def.w || 962; def.h = def.h || 1087;
    if (def.preset) {
      const h = (typeof ATK_MOTIONS !== 'undefined' && ATK_MOTIONS[cls] ? ATK_MOTIONS[cls].hit : .5);
      def.parts = { w: def.w_part || def.w };
      def.order = ['body', 'w'];
      def.keys = { body: _RIG_BODY(h), w: _RIG_PRESETS[def.preset](h) };
    }
    def._ready = true; return def;
  },

  attach(icon, u, size) {
    let def = CUTOUT_RIGS[this.key(u)]; if (!def) return false;
    if (def.preset && !def.w_part) { def.w_part = def.w; def.w = 962; }
    def = this._norm(def, u.cls);
    const src = this.base + 'image/character/' + this.key(u) + '.png';
    const z = size / def.w;
    const rig = document.createElement('div'); rig.className = 'rig';
    rig.style.cssText = `position:relative;width:${size}px;height:${Math.round(def.h * z)}px`;
    const inner = document.createElement('div');
    inner.style.cssText = `position:absolute;left:0;top:0;width:${def.w}px;height:${def.h}px;transform:scale(${z});transform-origin:0 0`;
    const layer = (clip, origin) => {
      const d = document.createElement('div');
      d.style.cssText = `position:absolute;left:0;top:0;width:${def.w}px;height:${def.h}px` + (origin ? `;transform-origin:${origin[0]}px ${origin[1]}px` : '');
      const im = document.createElement('img'); im.src = src; im.draggable = false;
      im.style.cssText = `position:absolute;left:0;top:0;width:${def.w}px;height:${def.h}px;image-rendering:pixelated` + (clip ? `;clip-path:${clip}` : '');
      d.appendChild(im); return d;
    };
    const cuts = Object.values(def.parts).map(p => p.clip.join(' ')).join(' ');
    const els = { body: layer(`path(evenodd,'M0 0 H${def.w} V${def.h} H0 Z ${cuts}')`, [def.w / 2, def.h * .92]) };
    for (const k in def.parts) els[k] = layer(`path('${def.parts[k].clip.join(' ')}')`, def.parts[k].origin);
    const NS = 'http://www.w3.org/2000/svg';
    const svg = (html) => { const s = document.createElementNS(NS, 'svg'); s.setAttribute('width', def.w); s.setAttribute('height', def.h);
      s.style.cssText = 'position:absolute;left:0;top:0;overflow:visible;pointer-events:none;opacity:0'; s.innerHTML = html; return s; };
    // 조각이 움직이면 드러나는 몸통 구멍: 옆의 몸통 픽셀을 dx/dy만큼 옮겨 와 구멍 모양으로 잘라 몸통 아래에 깔아 둠
    (def.holes || []).forEach(hl => {
      const pts = hl.points.split(' ').map(q => q.split(',')).map(([x, y]) => `${x}px ${y}px`).join(',');
      const wrap = document.createElement('div');
      wrap.style.cssText = `position:absolute;left:0;top:0;width:${def.w}px;height:${def.h}px;clip-path:polygon(${pts})`;
      const im = document.createElement('img'); im.src = src; im.draggable = false;
      im.style.cssText = `position:absolute;left:0;top:0;width:${def.w}px;height:${def.h}px;image-rendering:pixelated;transform:translate(${hl.dx || 0}px,${hl.dy || 0}px)`;
      wrap.appendChild(im); els.body.prepend(wrap);
    });
    if (def.fill) {
      els.fill = svg(`<polygon points="${def.fill.points}" fill="${def.fill.color}" stroke="#1d1a22" stroke-width="14" stroke-linejoin="round"/>`);
      els[def.fill.part].prepend(els.fill);
    }
    if (def.smear) els.smear = svg(`<path d="${def.smear}" fill="none" stroke="rgba(229,239,255,.75)" stroke-width="80" stroke-linecap="round"/>` +
      `<path d="${def.smear}" fill="none" stroke="#fff" stroke-width="24" stroke-linecap="round"/>`);
    def.order.forEach(k => inner.appendChild(els[k]));
    if (els.smear) inner.appendChild(els.smear);
    rig.appendChild(inner);
    icon.textContent = ''; icon.appendChild(rig);
    icon._rig = { def, els };
    return true;
  },

  sheet(u, kind) { const a = SPRITE_SHEETS[this.key(u)]; return a ? a[kind] || null : null; },
  sheetHitMs(sh) { return Math.round(sh.dur * sh.hit / sh.frames); },
  _base(icon) { return icon.querySelector(':scope > img, :scope > .rig'); },
  _flipped(icon) { const b = this._base(icon); return !!b && /scaleX\(-1\)/.test(b.style.transform); },

  // 시트 한 칸짜리 요소: 원본 그림과 같은 자리·같은 몸 높이·같은 방향
  _sheetEl(icon, u, sh, cls) {
    const f = CHAR_FIG[this.key(u)]; if (!f) return null;
    const s = FIG_H / (f[1] - f[0]), z = FIG_H / (sh.body[1] - sh.body[0]);
    const W = sh.w * z, H = sh.h * z, left = sh.icx * s - sh.cx * z, iconW = 962 * s;
    const el = document.createElement('div'); el.className = cls;
    el.style.cssText = `position:absolute;left:${left}px;bottom:${(1087 - f[1]) * s - (sh.h - sh.body[1]) * z}px;width:${W}px;height:${H}px;` +
      `background:url(${this.base + sh.src}) 0 0/${W * sh.frames}px ${H}px no-repeat;pointer-events:none;transform-origin:${iconW / 2 - left}px 50%;` +
      (this._flipped(icon) ? 'transform:scaleX(-1);' : '');
    el._W = W; if (getComputedStyle(icon).position === 'static') icon.style.position = 'relative';
    return el;
  },
  // 방향이 바뀌면(VFX._applyFace) 재생 중인 시트도 같이 뒤집음
  refreshFlip(icon) {
    const t = this._flipped(icon) ? 'scaleX(-1)' : '';
    [icon._loop, icon._sheetEl].forEach(el => { if (el) el.style.transform = t; });
  },
  // 보이는 것 정리: 1회 동작 > 반복 동작 > 정지 그림/리그
  _vis(icon) {
    const b = this._base(icon);
    if (b) b.style.visibility = (icon._loop || icon._sheetEl) ? 'hidden' : '';
    if (icon._loop) icon._loop.style.visibility = icon._sheetEl ? 'hidden' : '';
  },

  // 반복 동작(idle 대기 / combat 전투대기 / run 달리기). 해당 시트가 없으면 idle, 그것도 없으면 정지 그림
  setLoop(icon, u, kind) {
    if (!icon) return;
    const sh = this.sheet(u, kind) || this.sheet(u, 'idle');
    if (icon._loop && sh && icon._loop._src === sh.src) return;
    if (icon._loop) { icon._loop._anim.cancel(); icon._loop.remove(); icon._loop = null; }
    if (sh) {
      const el = this._sheetEl(icon, u, sh, 'sheet-loop');
      if (el) {
        el._src = sh.src; icon.appendChild(el); icon._loop = el;
        // 유닛마다 시작 위치를 달리해 여럿이 똑같이 움직이지 않게
        el._anim = el.animate([{ backgroundPositionX: '0px' }, { backgroundPositionX: -(el._W * sh.frames) + 'px' }],
          { duration: sh.dur, easing: `steps(${sh.frames})`, iterations: Infinity, delay: -Math.random() * sh.dur });
      }
    }
    this._vis(icon);
  },

  // 1회 동작(attack 공격 / hit 피격): 반복 동작을 잠시 가리고 재생한 뒤 되돌림. 반환: 타격 지연(ms)
  playOnce(icon, u, kind) {
    const sh = icon && this.sheet(u, kind); if (!sh) return 0;
    if (icon._sheetEl) icon._sheetEl._anim.cancel();
    const el = this._sheetEl(icon, u, sh, 'sheet-anim'); if (!el) return 0;
    icon.appendChild(el); icon._sheetEl = el; this._vis(icon);
    el._anim = el.animate([{ backgroundPositionX: '0px' }, { backgroundPositionX: -(el._W * sh.frames) + 'px' }],
      { duration: sh.dur, easing: `steps(${sh.frames})` });
    el._anim.onfinish = el._anim.oncancel = () => { el.remove(); if (icon._sheetEl === el) { icon._sheetEl = null; this._vis(icon); } };
    return sh.hit !== undefined ? this.sheetHitMs(sh) : 0;
  },
  playSheet(icon, u, sh) { return this.playOnce(icon, u, 'attack'); }, // 하위 호환

  // 공격: 부위별 키프레임 재생 (dur = 전체 모션 길이 ms)
  play(icon, dur) {
    const r = icon && icon._rig; if (!r) return;
    for (const k in r.def.keys) {
      const el = r.els[k]; if (!el) continue;
      if (el._anim) el._anim.cancel();
      const ks = r.def.keys[k];
      const frames = ks.map((q, i) => {
        const f = q.a !== undefined ? { opacity: q.a } : { transform: q.t || 'none' };
        if (q.o !== undefined) f.offset = q.o;
        if (q.a === undefined && i < _RIG_EASE.length) f.easing = _RIG_EASE[i];
        return f;
      });
      el._anim = el.animate(frames, { duration: dur });
    }
  },
};
