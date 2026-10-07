/* DEADLINE 15 — 스토리 대본 (한국어 원문)
 * 형식: docs/story-schema.md
 * 서사 설정: docs/STORY.md
 * {commander} 는 플레이어 지휘관 이름으로 치환된다. 지휘관에게 성별 대명사를 쓰지 않는다.
 */
window.STORY_KO = {
  cast: {
    commander: { name: '리안', portrait: 'commander', role: '주인공 · 클랜 지휘관' },
    narrator:  { name: '', portrait: null },
    bram:  { name: '브람',   portrait: 'knight_01',   role: '노기사 · 자경단 교관, 지휘관의 스승' },
    sera:  { name: '세라',   portrait: 'priest_02',   role: '클랜 치유사 · 지휘관의 소꿉친구' },
    bark:  { name: '바크',   portrait: 'brawler_01',  role: '전직 산적 · 클랜 돌격대장' },
    kasha: { name: '카샤',   portrait: 'assassin_02', role: '용병단 「검은 깃」 단장 · 라이벌' },
    ordin: { name: '오르딘', portrait: 'summoner_01', role: '왕실 대마도사 · 클랜의 후원자' },
  },

  episodes: {
    1: { title: '영웅의 시작',
      prologue: [
        { who: 'narrator', text: '15년 전, 하늘이 갈라진 밤이 있었다.' },
        { who: 'narrator', text: '보랏빛 틈이 열렸다가, 새벽이 오기 전 닫혔다.' },
        { who: 'narrator', text: '그 밤의 잔해 속에서 한 아이가 발견되었다.' },
        { who: 'narrator', text: '손바닥에 갈라진 별 모양의 흉터를 지닌 채로.' },
        { who: 'narrator', text: '그리고 지금, 변경의 솔빛 마을.' },
        { who: 'bram', text: '자경단장이 산적 화살에 쓰러졌다. 새 지휘관이 필요해.' },
        { who: 'commander', text: '왜 저입니까? 저보다 오래된 단원도 많은데요.' },
        { who: 'bram', text: '넌 싸우기 전에 주변부터 살피지. 그게 지휘관의 눈이다.' },
        { who: 'sera', text: '{commander}, 나도 같이 갈게. 다치면 내가 고쳐 줄게.' },
        { who: 'commander', text: '……알겠습니다. 한 사람도 잃지 않겠습니다.' },
        { who: 'bram', text: '좋은 각오다, 꼬맹이. 그 말, 끝까지 지켜 봐라.' },
      ],
      epilogue: [
        { who: 'narrator', text: '산적단이 무너지고, 솔빛 마을에 종소리가 울렸다.' },
        { who: 'narrator', text: '사흘 뒤, 왕도의 깃발을 단 마차가 마을에 들어섰다.' },
        { who: 'ordin', text: '왕실 대마도사 오르딘이오. 그대가 그 지휘관이군.' },
        { who: 'ordin', text: '북방이 얼어붙고 있소. 왕실은 그대의 클랜이 필요하오.' },
        { who: 'commander', text: '저희는 마을 자경단일 뿐입니다.' },
        { who: 'ordin', text: '산적 백 명을 꺾은 자경단이라면 충분하지.' },
        { who: 'ordin', text: '……그 손의 흉터, 언제부터 있었소?' },
        { who: 'commander', text: '기억이 날 때부터요. 그게 왜요?' },
        { who: 'ordin', text: '아니오. 그저 흥미로워서.' },
        { who: 'bram', text: '(저 눈빛… 15년 전에도 본 적이 있다.)' },
        { who: 'narrator', text: '클랜은 왕실 위임장을 받고 북쪽으로 길을 떠났다.' },
      ] },

    2: { title: '얼어붙은 음모',
      prologue: [
        { who: 'narrator', text: '북방 백설 산맥. 계절이 바뀌어도 눈이 녹지 않는 땅.' },
        { who: 'narrator', text: '올해는 산 아래 마을까지 하룻밤 새 얼어붙었다.' },
        { who: 'bark', text: '대장, 여긴 숨만 쉬어도 코털이 얼어붙는데요.' },
        { who: 'sera', text: '얼어 죽은 사람들 표정이… 다들 뭔가를 보고 놀란 얼굴이야.' },
        { who: 'bram', text: '자연의 추위가 아니다. 이건 누군가 부른 냉기야.' },
        { who: 'commander', text: '(손바닥의 흉터가… 차갑게 욱신거린다.)' },
        { who: 'commander', text: '우선 산 아래 마을부터 지킨다. 원인은 그다음이야.' },
      ],
      epilogue: [
        { who: 'narrator', text: '냉기 기사가 쓰러지자, 산맥에 봄바람이 내려왔다.' },
        { who: 'bram', text: '할바르… 내 오랜 전우였다. 15년 전, 같은 밤에 있었지.' },
        { who: 'commander', text: '마지막에 하던 말, 대마도사를 어떻게 하라는 거였을까요.' },
        { who: 'bram', text: '모르겠다. 확실해지기 전엔 입 밖에 내지 마라.' },
        { who: 'kasha', text: '이번엔 네가 먼저였네, 시골 지휘관.' },
        { who: 'kasha', text: '하지만 기억해 둬. 검은 깃은 두 번 지지 않아.' },
        { who: 'narrator', text: '그때, 왕도에서 급한 전령이 도착했다.' },
        { who: 'ordin', text: '남부 습지에 역병이 돌고 있소. 서둘러 주시오.' },
        { who: 'commander', text: '……마치 다음에 어디가 터질지 알고 있는 것 같네.' },
      ] },

    3: { title: '늪지의 저주',
      prologue: [
        { who: 'narrator', text: '남부 흑수 습지. 물안개 속에서 기침 소리가 끊이지 않았다.' },
        { who: 'narrator', text: '짐승들은 뒤틀린 모습으로 변해 사람을 덮쳤다.' },
        { who: 'sera', text: '역병이면 내 몫이야. 이번엔 내가 앞에 설게.' },
        { who: 'commander', text: '세라, 혼자 다 짊어지려 하지 마.' },
        { who: 'bark', text: '진흙탕 싸움이라면 이 몸이 전문이지!' },
        { who: 'bram', text: '물이 얕은 곳은 발이 묶인다. 거기서 맞으면 더 아프다.' },
        { who: 'commander', text: '여울에는 함부로 서지 않는다. 다들 기억해.' },
      ],
      epilogue: [
        { who: 'narrator', text: '습지의 제왕이 가라앉자, 물빛이 조금씩 맑아졌다.' },
        { who: 'commander', text: '이 지도… 북방, 습지, 그리고 제국의 화산.' },
        { who: 'bram', text: '세 곳을 이으면 삼각형이다. 거대한 진(陣)이야.' },
        { who: 'sera', text: '누군가 일부러 재앙을 하나씩 일으키고 있었던 거야.' },
        { who: 'ordin', text: '보고는 받았소. 배후는 볼카르 제국이 분명하오.' },
        { who: 'commander', text: '신전에서 왕실 문장이 새겨진 제기도 나왔습니다.' },
        { who: 'ordin', text: '제국이 우리를 모함하려 한 것이겠지. 진격하시오.' },
        { who: 'bram', text: '(대답이 너무 빠르다.)' },
        { who: 'narrator', text: '의심을 품은 채, 클랜은 국경을 넘었다.' },
      ] },

    4: { title: '불타는 제국',
      prologue: [
        { who: 'narrator', text: '볼카르 제국. 화산의 불로 쇠를 벼리는 강철의 나라.' },
        { who: 'narrator', text: '지금 그 나라는 황제파와 반란군으로 갈라져 불타고 있었다.' },
        { who: 'bark', text: '제국 놈들이 진짜 배후면, 황제 머리만 치면 끝나겠네.' },
        { who: 'bram', text: '그렇게 단순했으면 좋겠군.' },
        { who: 'sera', text: '불탄 마을에서 아이들이 울고 있어. 저 사람들 먼저야.' },
        { who: 'commander', text: '반란군과 손잡는다. 우리 적은 이 나라 백성이 아니야.' },
      ],
      epilogue: [
        { who: 'narrator', text: '화염 황제가 쓰러지고, 화산의 붉은 하늘이 식어 갔다.' },
        { who: 'commander', text: '황제의 마지막 말, 그리고 제단의 서신. 다 오르딘이야.' },
        { who: 'bram', text: '"약속대로 불꽃을 키워라." 이제 확실하군.' },
        { who: 'kasha', text: '네 후원자가 이 모든 판을 짰다는 거네.' },
        { who: 'commander', text: '왕도로 가서 직접 묻겠어. 왜 이런 짓을 했는지.' },
        { who: 'narrator', text: '그러나 그날 밤, 대지가 비명을 지르듯 갈라졌다.' },
        { who: 'narrator', text: '서쪽 황무지에 끝이 보이지 않는 구멍, 심연이 열렸다.' },
        { who: 'sera', text: '저기서 마물이 쏟아지고 있어. 마을들이 위험해!' },
        { who: 'bram', text: '진실은 도망가지 않는다. 사람 목숨은 기다려 주지 않지.' },
        { who: 'commander', text: '……심연으로 간다. 오르딘은 그다음이야.' },
      ] },

    5: { title: '심연의 종말',
      prologue: [
        { who: 'narrator', text: '심연. 대지 아래 잠들어 있던 고대 문명의 폐허.' },
        { who: 'narrator', text: '빛이 닿지 않는 그곳에서, 무언가가 깨어나고 있었다.' },
        { who: 'bark', text: '바닥이 안 보여. 떨어지면 영영 끝이겠는데.' },
        { who: 'sera', text: '공기가 무거워. 기도가 잘 닿지 않는 느낌이야.' },
        { who: 'bram', text: '지휘관. 이번엔 돌아오지 못하는 자가 생길 수도 있다.' },
        { who: 'commander', text: '그런 말 하지 마세요. 전원 데리고 돌아갑니다.' },
        { who: 'bram', text: '그래. 그 고집이 네 장점이지.' },
        { who: 'commander', text: '(흉터가 뜨겁다. 저 아래에서 누가 부르고 있어.)' },
      ],
      epilogue: [
        { who: 'narrator', text: '심연의 전사가 무너지고, 깊은 곳의 울림이 잦아들었다.' },
        { who: 'narrator', text: '클랜은 지상으로 돌아왔다. 한 사람을 남겨 둔 채.' },
        { who: 'narrator', text: '솔빛 마을 언덕에 빈 관 하나가 묻혔다.' },
        { who: 'sera', text: '브람 아저씨는… 마지막까지 웃고 계셨어.' },
        { who: 'commander', text: '전원 데리고 돌아간다고 했는데. 내가 그렇게 말했는데.' },
        { who: 'bark', text: '대장 탓 아니오. 영감님이 직접 고른 자리였어.' },
        { who: 'kasha', text: '슬퍼할 시간이 없어. 왕도에서 오르딘이 사라졌대.' },
        { who: 'kasha', text: '그리고 왕도 북쪽 하늘에… 문이 생기고 있어.' },
        { who: 'commander', text: '……갑니다. 브람이 지키려던 걸 대신 지키러.' },
      ] },

    6: { title: '지옥문',
      prologue: [
        { who: 'narrator', text: '하늘 곳곳에 균열이 번졌다. 15년 전 그 밤처럼.' },
        { who: 'narrator', text: '하지만 이번에는, 새벽이 와도 닫히지 않았다.' },
        { who: 'narrator', text: '왕도 북쪽, 거대한 문이 천천히 열리고 있었다.' },
        { who: 'sera', text: '{commander}, 요즘 잠을 못 자잖아. 괜찮아?' },
        { who: 'commander', text: '괜찮지 않아. 그래도 멈추면 더 많이 잃어.' },
        { who: 'commander', text: '브람이 말했지. 지휘관은 모두를 살릴 순 없다고.' },
        { who: 'commander', text: '하지만 아무도 버리지 않을 수는 있어.' },
        { who: 'bark', text: '그 말 기다렸소, 대장. 다시 가 봅시다.' },
      ],
      epilogue: [
        { who: 'narrator', text: '옥문의 수호자가 쓰러진 순간, 지옥문이 활짝 열렸다.' },
        { who: 'ordin', text: '수고했소, 젊은 지휘관. 아니… 열쇠여.' },
        { who: 'commander', text: '오르딘! 처음부터 이걸 노린 거였나!' },
        { who: 'ordin', text: '수호자를 쓰러뜨릴 수 있는 건 그대 피뿐이었지.' },
        { who: 'ordin', text: '15년 전, 그대 부모가 문을 닫았소. 목숨을 바쳐서.' },
        { who: 'ordin', text: '나는 문을 열어야 하오. 신을 부르기 위해서.' },
        { who: 'narrator', text: '오르딘은 문 너머 붉은 어둠 속으로 사라졌다.' },
        { who: 'kasha', text: '쫓아갈 거지? 표정 보니 이미 정했네.' },
        { who: 'commander', text: '문 너머로 간다. 이번엔 우리가 끝낸다.' },
      ] },

    7: { title: '악마의 영역',
      prologue: [
        { who: 'narrator', text: '마계. 하늘은 피처럼 붉고, 땅은 숨을 쉬었다.' },
        { who: 'narrator', text: '이곳에선 길이 매일 바뀌고, 기억이 형체를 얻었다.' },
        { who: 'bark', text: '방금 저 바위가 날 쳐다봤소. 진짜로.' },
        { who: 'sera', text: '여기선 눈에 보이는 걸 다 믿으면 안 될 것 같아.' },
        { who: 'kasha', text: '검은 깃도 따라왔어. 빚은 갚아야 하니까.' },
        { who: 'commander', text: '서로 이름을 계속 불러. 자기 자신을 잃지 않게.' },
      ],
      epilogue: [
        { who: 'narrator', text: '악마의 법사가 흩어지자, 환영의 안개가 걷혔다.' },
        { who: 'commander', text: '유적에서 들은 목소리… 정말 부모님이었을까.' },
        { who: 'sera', text: '"열쇠는 혼자 돌리는 게 아니다." 그렇게 말했잖아.' },
        { who: 'commander', text: '응. 그 말은 환영이 아니었다고 믿을래.' },
        { who: 'kasha', text: '법사가 실토했어. 오르딘은 마계 꼭대기로 갔다고.' },
        { who: 'kasha', text: '천상의 빛이 새어 드는 곳. 거기서 신을 부를 생각이래.' },
        { who: 'bark', text: '신이라니… 이제 신까지 상대해야 해?' },
        { who: 'commander', text: '신이든 뭐든, 사람을 재료로 쓴다면 막는다.' },
      ] },

    8: { title: '신의 심판',
      prologue: [
        { who: 'narrator', text: '마계의 하늘 꼭대기에 하얀 틈이 벌어졌다.' },
        { who: 'narrator', text: '그 틈에서 쏟아진 빛은 악마도, 사람도 가리지 않았다.' },
        { who: 'sera', text: '이건… 내가 평생 기도해 온 빛이야.' },
        { who: 'sera', text: '그런데 왜 이렇게 차가운 거지.' },
        { who: 'ordin', text: '보시오. 신은 더럽혀진 모든 것을 태워 없앨 것이오.' },
        { who: 'ordin', text: '마계도, 마계에 닿은 땅도, 그곳의 사람들도.' },
        { who: 'commander', text: '그 사람들 중엔 우리 고향도 있어!' },
        { who: 'ordin', text: '세상을 구하려면 일부는 잃어야 하오. 그게 계산이오.' },
        { who: 'commander', text: '누굴 잃을지는 당신이 정하는 게 아니야.' },
      ],
      epilogue: [
        { who: 'narrator', text: '하얀 틈이 닫히고, 마계의 하늘이 다시 붉어졌다.' },
        { who: 'ordin', text: '신은… 이미 한 번 군주에게 졌던 것이오.' },
        { who: 'ordin', text: '나는 15년 동안 패배한 신에게 기도한 셈이군.' },
        { who: 'bark', text: '대장, 이 영감 어쩔 거요. 여기 두고 갈까?' },
        { who: 'commander', text: '데려간다. 죽어서 갚는 건 너무 쉬우니까.' },
        { who: 'sera', text: '{commander}… 많이 변했네. 좋은 쪽으로.' },
        { who: 'narrator', text: '그때, 마계 깊은 곳에서 거대한 북소리가 울렸다.' },
        { who: 'kasha', text: '군주의 대군이 움직여. 목표는… 우리 세계야!' },
        { who: 'commander', text: '돌아간다. 지금 막지 못하면 돌아갈 곳이 없어.' },
      ] },

    9: { title: '절대절명',
      prologue: [
        { who: 'narrator', text: '마계 군주의 대군이 세상 모든 균열에서 쏟아져 나왔다.' },
        { who: 'narrator', text: '왕국도, 제국도, 북방도, 습지도 이제 하나의 전쟁터였다.' },
        { who: 'narrator', text: '흩어진 생존자들이 한 깃발 아래로 모여들었다.' },
        { who: 'kasha', text: '다들 너를 총지휘관으로 원해. 웃기지, 시골 지휘관이.' },
        { who: 'commander', text: '난 아직도 마을 자경단 지휘관이야.' },
        { who: 'commander', text: '다만 지켜야 할 마을이 조금 커졌을 뿐이지.' },
        { who: 'bark', text: '크하하! 그 말 깃발에 새겨 둡시다.' },
        { who: 'sera', text: '이번엔 다 같이 살아서 끝내자. 약속해.' },
        { who: 'commander', text: '약속해. 그리고 이번엔 끝까지 지킬게.' },
      ],
      epilogue: [
        { who: 'narrator', text: '전쟁의 전사가 쓰러지자, 마계군의 진격이 멈췄다.' },
        { who: 'narrator', text: '세상은 겨우, 정말 겨우 버텨 냈다.' },
        { who: 'ordin', text: '군주의 옥좌로 가는 길을 알고 있소. 안내하겠소.' },
        { who: 'kasha', text: '믿어도 돼? 이 영감 때문에 다 이렇게 됐는데.' },
        { who: 'commander', text: '믿는 게 아니야. 기회를 주는 거지.' },
        { who: 'ordin', text: '……그대 부모도 똑같은 말을 했었소.' },
        { who: 'bark', text: '내일이면 끝나는 거요? 진짜로?' },
        { who: 'commander', text: '끝내러 가는 거야. 다 같이.' },
        { who: 'narrator', text: '출정 전야, 진영의 모닥불은 밤새 꺼지지 않았다.' },
      ] },

    10: { title: '불가능의 영역',
      prologue: [
        { who: 'narrator', text: '마계의 가장 깊은 곳. 빛도 소리도 닿지 않는 바닥.' },
        { who: 'narrator', text: '그곳에 마계 군주의 옥좌가 있었다.' },
        { who: 'ordin', text: '옥좌 앞엔 군주의 다섯 신하가 길을 막고 있소.' },
        { who: 'kasha', text: '다섯이라. 하나씩 차례로 쓰러뜨리면 되겠네.' },
        { who: 'sera', text: '{commander}, 손 줘. …흉터가 빛나고 있어.' },
        { who: 'commander', text: '부모님이 남긴 열쇠야. 이번엔 우리가 함께 돌린다.' },
        { who: 'bark', text: '대장 손 위에 내 손. 자, 다들 얹어!' },
        { who: 'commander', text: '솔빛 클랜, 마지막 출정이다!' },
      ],
      epilogue: [
        { who: 'narrator', text: '열쇠가 돌아가고, 하늘의 모든 균열이 동시에 닫혔다.' },
        { who: 'narrator', text: '마계는 다시 깊은 잠에 빠졌다. 이번에는 영원히.' },
        { who: 'narrator', text: '그리고 몇 달 뒤, 솔빛 마을의 봄.' },
        { who: 'bark', text: '대장! 밭 갈 사람 모자라요. 영웅도 일해야지!' },
        { who: 'kasha', text: '검은 깃은 해산했어. 이제 그냥 카샤야. 잘 부탁해.' },
        { who: 'sera', text: '브람 아저씨 무덤에 꽃 갖다 놨어. 같이 갈래?' },
        { who: 'commander', text: '응. 할 얘기가 많아. 다 끝났다고 말씀드려야지.' },
        { who: 'commander', text: '브람, 약속은 반만 지켰어요. 그래도 다들 여기 있어요.' },
        { who: 'narrator', text: '언덕 위로 바람이 불었다. 누군가 웃는 소리 같았다.' },
        { who: 'commander', text: '우리는 평범했어. 하지만 함께였기에 해낼 수 있었어.' },
        { who: 'narrator', text: '— DEADLINE 15, 끝 —' },
      ] },
  },

  stages: {
    // ═══ Episode 1: 영웅의 시작 ═══
    1: {
      pre: [
        { who: 'narrator', text: '솔빛 마을 동쪽 목책. 들판 너머로 횃불이 흔들렸다.' },
        { who: 'bram', text: '산적 졸개들이다. 목책만 지키면 마을은 안전해.' },
        { who: 'commander', text: '첫 명령이다. 목책 앞에 서서, 넘어오는 놈만 막는다.' },
        { who: 'sera', text: '다치면 바로 뒤로 빠져. 내가 있잖아.' },
      ],
      post: [
        { who: 'bram', text: '나쁘지 않았다. 아무도 쓰러지지 않았군.' },
        { who: 'commander', text: '손이 아직도 떨려요.' },
        { who: 'bram', text: '떨리는 손으로도 명령은 내릴 수 있다. 그거면 됐다.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '목책이 무너지면 끝이야. 자리를 지켜!' } ],
        last: [ { who: 'sera', text: '한 명 남았어! 조금만 더!' } ],
      },
    },
    2: {
      pre: [
        { who: 'narrator', text: '이튿날 새벽. 산적들이 다시 몰려왔다.' },
        { who: 'bram', text: '이번엔 도끼 든 놈들이 섞였다. 전사다.' },
        { who: 'bram', text: '전사는 맞을수록 독이 오른다. 오래 끌지 마라.' },
        { who: 'commander', text: '둘이 한 놈을 같이 친다. 하나씩 확실하게.' },
      ],
      post: [
        { who: 'sera', text: '{commander}, 방금 그 지시 진짜 지휘관 같았어.' },
        { who: 'commander', text: '그냥 브람이 하던 말을 따라 했을 뿐이야.' },
        { who: 'bram', text: '따라 하다 보면 네 것이 된다.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '도끼부터 노린다. 협공으로 끝내!' } ],
        wave: [ { who: 'bram', text: '두 번째 무리다. 서두르지 마라, 목책은 버틴다.' } ],
        danger: [ { who: 'sera', text: '{commander}! 너무 앞에 나왔어, 물러나!' } ],
      },
    },
    3: {
      pre: [
        { who: 'narrator', text: '마을로 이어지는 바위 협곡. 산적들의 지름길이었다.' },
        { who: 'bram', text: '협곡 위 언덕을 잡아라. 높은 곳에서 치면 더 아프다.' },
        { who: 'commander', text: '궁수가 있었으면 좋았을 텐데.' },
        { who: 'bram', text: '없는 걸 아쉬워하지 말고, 있는 걸로 이겨라.' },
      ],
      post: [
        { who: 'narrator', text: '협곡 바닥에서 산적들의 보급 쪽지가 발견되었다.' },
        { who: 'commander', text: '"숲속 벌목장으로 집결." 다음은 거기네.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '길목은 좁아. 한 번에 다 못 와. 여기서 막는다.' } ],
        wave: [ { who: 'sera', text: '협곡 뒤쪽에서 또 와! 이번엔 더 많아!' } ],
        last: [ { who: 'commander', text: '마지막 하나. 도망치게 두지 마.' } ],
      },
    },
    4: {
      pre: [
        { who: 'bram', text: '협곡 반대편 입구다. 오늘은 놈들도 작정했군.' },
        { who: 'sera', text: '저기 그림자 속에 누가 숨어 있어.' },
        { who: 'bram', text: '암살자다. 저놈은 방패 뒤를 파고든다. 조심해.' },
        { who: 'commander', text: '세라는 내 옆에. 혼자 떨어지지 마.' },
      ],
      post: [
        { who: 'commander', text: '저 암살자, 품에 이상한 수정 조각이 있었어.' },
        { who: 'sera', text: '보랏빛이네. 만지니까 손이 저려.' },
        { who: 'commander', text: '(흉터가… 반응한다?)' },
      ],
      battle: {
        start: [ { who: 'commander', text: '입구를 막아. 숨어든 놈부터 찾는다.' } ],
        wave: [ { who: 'bram', text: '그림자가 움직였다. 후방을 살펴라!' } ],
        danger: [ { who: 'bram', text: '꼬맹이, 쓰러지면 진형 전체가 무너진다!' } ],
      },
    },
    5: {
      pre: [
        { who: 'narrator', text: '숲속 벌목장. 마을 사람들의 겨울 장작이 쌓인 곳.' },
        { who: 'bram', text: '여기를 불태우면 마을은 겨울을 못 난다. 지켜야 해.' },
        { who: 'commander', text: '나무 사이에 숨으면 화살을 덜 맞아. 숲을 써.' },
        { who: 'sera', text: '저쪽에 덩치 큰 사람… 주먹만으로 싸우나 봐.' },
      ],
      post: [
        { who: 'bark', text: '졌다, 졌어. 죽이려면 빨리 죽여.' },
        { who: 'commander', text: '왜 일부러 빗나가게 쳤지? 다 봤어.' },
        { who: 'bark', text: '…난 바크. 굶어서 산적 된 놈이지, 사람 죽이는 건 싫어.' },
        { who: 'commander', text: '그럼 길 안내를 해. 산적 거점까지.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '장작더미를 등지고 싸워. 한 발도 물러서지 마.' } ],
        wave: [ { who: 'bram', text: '숲 깊은 곳에서 증원이다. 대열을 좁혀라.' } ],
        last: [ { who: 'sera', text: '저 덩치만 남았어. 근데… 공격을 안 하네?' } ],
      },
    },
    6: {
      pre: [
        { who: 'bark', text: '허, 이 대장 배짱 좋네. 좋아, 따라가지.' },
        { who: 'bark', text: '이 숲 너머가 산적 전초기지요. 지름길 알려 드리지.' },
        { who: 'bram', text: '처음으로 우리가 쳐들어가는 싸움이다.' },
        { who: 'bram', text: '지키는 것과 다르다. 앞으로 나가는 용기가 필요해.' },
        { who: 'commander', text: '측면으로 돌아서 친다. 정면은 바크가 맡아.' },
        { who: 'bark', text: '처음부터 제일 험한 자리네. 마음에 들어!' },
      ],
      post: [
        { who: 'bark', text: '어떻소, 이 몸 쓸 만하지?' },
        { who: 'sera', text: '다친 데 없어? …정말로 우리 편이 됐네.' },
        { who: 'commander', text: '오늘부터 바크는 우리 클랜이야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '전진! 이번엔 우리가 찾아간다.' } ],
        last: [ { who: 'bark', text: '저놈만 치면 기지는 우리 거요!' } ],
      },
    },
    7: {
      pre: [
        { who: 'narrator', text: '숲을 빠져나오자 끝없는 모래 언덕이 펼쳐졌다.' },
        { who: 'bark', text: '산적 보급로요. 물이랑 식량이 다 이리로 오지.' },
        { who: 'bram', text: '모래밭은 몸을 숨길 데가 없다. 궁수를 조심해라.' },
        { who: 'commander', text: '보급만 끊어도 산적단은 굶는다. 가자.' },
      ],
      post: [
        { who: 'sera', text: '보급 상자에 제국 글씨가 찍혀 있어.' },
        { who: 'bram', text: '산적이 제국제 무기를 쓴다고? 어디서 났지.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '궁수 사거리 안에서 오래 서 있지 마!' } ],
        wave: [ { who: 'bark', text: '모래 언덕 뒤에 매복이오! 역시 그럴 줄 알았지.' } ],
        danger: [ { who: 'sera', text: '피가 너무 많이 나! 지금 치료할게!' } ],
      },
    },
    8: {
      pre: [
        { who: 'narrator', text: '사막 한가운데 오아시스. 산적들의 창고가 있었다.' },
        { who: 'bark', text: '두목은 여기서 무기를 받아 갔소. 두건 쓴 마법사한테서.' },
        { who: 'commander', text: '마법사? 산적이랑 거래하는 마법사라니.' },
        { who: 'bram', text: '창고를 털면 알게 되겠지.' },
      ],
      post: [
        { who: 'commander', text: '이 장부… 보랏빛 수정을 모아 오면 금화를 준대.' },
        { who: 'bram', text: '수정 따위로 산적을 움직이다니. 뒤에 누가 있군.' },
        { who: 'bark', text: '두목은 붉은 바위 고개에 있소. 화산 지대요.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '창고 경비부터 쓸어버려. 물자를 지킨다.' } ],
        last: [ { who: 'bark', text: '마지막 놈이오! 창고 문 열쇠 갖고 있을 거요.' } ],
      },
    },
    9: {
      pre: [
        { who: 'narrator', text: '붉은 바위 고개. 땅 틈새로 용암이 흐르고 있었다.' },
        { who: 'bram', text: '용암 옆에서 오래 머물면 화상을 입는다.' },
        { who: 'sera', text: '차례를 끝낼 땐 용암에서 한 칸 떨어져서 끝내.' },
        { who: 'commander', text: '두목의 소굴이 코앞이야. 여기서 지칠 순 없어.' },
      ],
      post: [
        { who: 'bark', text: '저 위가 두목 요새요. 오늘 밤에 끝냅시다.' },
        { who: 'commander', text: '다들 쉬어. 내일 새벽에 친다.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '용암 쪽으로 밀리지 않게 조심해!' } ],
        wave: [ { who: 'bram', text: '요새에서 지원군이 내려온다. 고개를 사수해!' } ],
        danger: [ { who: 'bram', text: '물러서라! 무리하면 아무것도 못 지킨다!' } ],
        last: [ { who: 'sera', text: '이제 하나야! 끝까지 집중!' } ],
      },
    },
    10: {
      pre: [
        { who: 'narrator', text: '화산 기슭의 산적 요새. 깃발이 열풍에 펄럭였다.' },
        { who: 'boss', text: '마을 꼬마들이 여기까지 기어 올라왔다고?' },
        { who: 'commander', text: '마을을 괴롭히는 건 오늘로 끝이다.' },
        { who: 'boss', text: '바크, 이 배신자 놈! 너부터 용암에 처넣어 주마!' },
        { who: 'bark', text: '두목, 이젠 내 대장이 따로 있소.' },
        { who: 'bram', text: '두목 주변의 졸개부터 정리해라. 서두르지 마.' },
      ],
      post: [
        { who: 'boss', text: '크윽… 그분이 약속했는데… 불이 열린다고….' },
        { who: 'commander', text: '그분이 누구지? 불이 열린다는 게 무슨 뜻이야!' },
        { who: 'narrator', text: '우두머리는 끝내 대답하지 못하고 숨을 거두었다.' },
        { who: 'bram', text: '끝난 게 아니다. 이건 시작일지도 모르겠군.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '두목만 쓰러뜨리면 산적단은 흩어진다!' } ],
        boss: [ { who: 'boss', text: '하찮은 자경단 따위가! 내 도끼 맛을 봐라!' } ],
        wave: [ { who: 'bark', text: '요새 안쪽 정예들이오! 두목 호위대!' } ],
        danger: [ { who: 'sera', text: '{commander}, 두목 도끼가 너무 세! 거리 벌려!' } ],
        last: [ { who: 'bark', text: '이제 하나 남았소! 산적단은 오늘로 끝이오!' } ],
      },
    },
    // ═══ Episode 2: 얼어붙은 음모 ═══
    11: {
      pre: [
        { who: 'narrator', text: '산기슭 마을 하얀샘. 우물마저 얼어 버린 곳.' },
        { who: 'sera', text: '저기 마을로 걸어오는 병사들… 왕국 갑옷이야.' },
        { who: 'bram', text: '눈이 비었다. 산 사람이 아니야. 얼음에 묶인 시체다.' },
        { who: 'commander', text: '마을 성벽 안쪽으로! 문을 지킨다!' },
      ],
      post: [
        { who: 'bark', text: '쓰러뜨려도 피가 안 나오네. 오싹하구먼.' },
        { who: 'bram', text: '저 문장… 15년 전 해체된 북방 수비대다.' },
        { who: 'commander', text: '죽은 수비대가 왜 지금 걸어 다니는 거죠?' },
      ],
      battle: {
        start: [ { who: 'commander', text: '성벽에 붙는 놈부터 끊어 내!' } ],
        wave: [ { who: 'sera', text: '눈보라 속에서 또 나와! 끝이 없어!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 얼음 깨듯 부숴 버립시다!' } ],
      },
    },
    12: {
      pre: [
        { who: 'narrator', text: '하얀샘 주민들이 산 아래로 피난을 시작했다.' },
        { who: 'sera', text: '저쪽 언데드 중에 사제복 입은 사람도 있어.' },
        { who: 'sera', text: '저 사제들이 다른 시체를 다시 일으켜 세워.' },
        { who: 'commander', text: '사제부터 노려. 그래야 싸움이 끝난다.' },
        { who: 'bram', text: '피난민이 성문을 다 빠져나갈 때까지 버텨라.' },
      ],
      post: [
        { who: 'sera', text: '죽은 사제가 신의 이름을 부르면서 싸우다니… 싫다.' },
        { who: 'commander', text: '저들을 그렇게 만든 자가 있어. 반드시 찾을 거야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '피난민이 다 빠질 때까지 성벽을 지킨다!' } ],
        wave: [ { who: 'bram', text: '기사들이 선두다. 방패 뒤의 사제를 놓치지 마라.' } ],
        danger: [ { who: 'sera', text: '{commander}, 손이 얼었잖아! 잠깐만 버텨!' } ],
      },
    },
    13: {
      pre: [
        { who: 'narrator', text: '북방 관문 서리문 요새. 성문이 얼음으로 뒤덮였다.' },
        { who: 'kasha', text: '어머, 시골 자경단이 여기까지 왔네?' },
        { who: 'kasha', text: '용병단 검은 깃의 카샤야. 이 요새는 우리 몫이고.' },
        { who: 'commander', text: '누구 몫이든 상관없어. 같이 치면 빨리 끝나.' },
        { who: 'kasha', text: '같이? 누가 먼저 성주실에 닿나 내기나 해.' },
        { who: 'bark', text: '대장, 저 여자 기분 나쁘게 웃는데요.' },
      ],
      post: [
        { who: 'kasha', text: '쳇, 한 걸음 늦었네. 운이 좋았어.' },
        { who: 'commander', text: '운이 아니라 클랜원들이 잘한 거야.' },
        { who: 'kasha', text: '흥, 다음엔 내가 먼저야. 기억해 둬.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '공병을 조심해. 성문을 넘어오면 폭탄을 쓴다!' } ],
        wave: [ { who: 'kasha', text: '성벽 위 증원이야. 네 쪽으로 보내 줄게.' } ],
        last: [ { who: 'bark', text: '성주실 앞이오! 저놈만 치면 우리가 먼저요!' } ],
      },
    },
    14: {
      pre: [
        { who: 'narrator', text: '요새 아래 야영지. 깊은 밤, 모닥불이 흔들렸다.' },
        { who: 'kasha', text: '자고 있을 때가 아니야. 자객들이 너를 노리고 있어.' },
        { who: 'commander', text: '나를? 왜 시골 지휘관 하나를.' },
        { who: 'kasha', text: '의뢰서에 그렇게 적혀 있었어. "손에 흉터가 있는 자."' },
        { who: 'bram', text: '모두 일어나라. 야영지를 지킨다.' },
      ],
      post: [
        { who: 'commander', text: '왜 알려 줬어? 경쟁 상대잖아.' },
        { who: 'kasha', text: '내 경쟁 상대가 잠결에 죽으면 재미없잖아.' },
        { who: 'bram', text: '흉터를 노리는 자가 있다. 이제부터 혼자 다니지 마라.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '불가로 모여! 어둠 속에서 흩어지지 마!' } ],
        wave: [ { who: 'kasha', text: '소환술사가 짐승을 불러냈어. 저쪽부터!' } ],
        danger: [ { who: 'sera', text: '자객이 {commander}만 노려! 다들 막아!' } ],
        last: [ { who: 'bark', text: '마지막 자객이오! 살려 둬서 배후를 캐냅시다!' } ],
      },
    },
    15: {
      pre: [
        { who: 'narrator', text: '빙하 속에 묻혀 있던 고대 유적이 드러났다.' },
        { who: 'bram', text: '냉기는 이 안에서 뿜어져 나오고 있다.' },
        { who: 'sera', text: '벽에 새겨진 문양… 갈라진 별 모양이야.' },
        { who: 'commander', text: '(내 흉터랑 똑같은 모양이다.)' },
        { who: 'commander', text: '안에 마법사들이 진을 쳤어. 돌파한다.' },
      ],
      post: [
        { who: 'narrator', text: '유적의 문양이 {commander}의 손에 닿자 희미하게 빛났다.' },
        { who: 'sera', text: '{commander}, 방금 그 빛… 너한테 반응한 거야?' },
        { who: 'commander', text: '모르겠어. 하지만 우연은 아닌 것 같아.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '마법사는 맞으면 약해. 빨리 붙어서 끝내!' } ],
        wave: [ { who: 'bram', text: '유적 깊은 곳에서 무당들이다. 저주를 조심해.' } ],
        last: [ { who: 'sera', text: '하나만 더! 문양이 계속 빛나고 있어!' } ],
      },
    },
    16: {
      pre: [
        { who: 'narrator', text: '얼어붙은 능선. 냉기의 근원이 정상에 있었다.' },
        { who: 'kasha', text: '정상까지 경주야. 이번엔 내가 이긴다.' },
        { who: 'bram', text: '상대 기사들이 서로 붙어 다닌다. 엄호 대형이야.' },
        { who: 'bram', text: '기사 옆의 놈은 멀리서 노려도 맞지 않는다.' },
        { who: 'commander', text: '기사부터 쓰러뜨려 대형을 깬다. 그다음이 뒤쪽이야.' },
      ],
      post: [
        { who: 'kasha', text: '…이번에도 졌네. 너, 생각보다 한다.' },
        { who: 'commander', text: '칭찬이야? 처음 듣는 것 같은데.' },
        { who: 'kasha', text: '착각하지 마. 관찰 기록이야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '기사 대형을 깨라! 엄호가 사라지면 쉬워진다!' } ],
        wave: [ { who: 'bark', text: '창병 무리가 능선을 타고 내려오오!' } ],
        danger: [ { who: 'bram', text: '지휘관, 방어 태세로 한 차례 버텨라!' } ],
      },
    },
    17: {
      pre: [
        { who: 'narrator', text: '능선 너머 또 다른 유적. 비명이 울려 퍼졌다.' },
        { who: 'bark', text: '저거 검은 깃 놈들 아니오? 포위당했는데.' },
        { who: 'sera', text: '카샤가 다쳤어! 어떡해, {commander}?' },
        { who: 'commander', text: '구한다. 경쟁은 살아 있을 때 하는 거야.' },
      ],
      post: [
        { who: 'kasha', text: '…고마워. 이 말 두 번은 안 할 거야.' },
        { who: 'kasha', text: '함정이었어. 우리를 고용한 쪽이 위치를 흘렸지.' },
        { who: 'commander', text: '고용한 쪽이 누군데?' },
        { who: 'kasha', text: '왕도의 대리인. 얼굴은 못 봤어.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '포위를 뚫는다! 검은 깃까지 길을 내!' } ],
        wave: [ { who: 'kasha', text: '공병이 유적 기둥을 폭파하려 해! 막아!' } ],
        last: [ { who: 'kasha', text: '마지막 하나는 내가 갚아 줄게. 비켜!' } ],
      },
    },
    18: {
      pre: [
        { who: 'narrator', text: '정상 아래 야영지. 사흘째 눈보라가 그치지 않았다.' },
        { who: 'bram', text: '할 말이 있다. 냉기를 부르는 자… 누군지 알 것 같다.' },
        { who: 'bram', text: '할바르. 15년 전 나와 함께 싸운 왕실 기사였다.' },
        { who: 'bram', text: '그날 밤 이후 대마도사의 호위대로 들어갔지.' },
        { who: 'commander', text: '대마도사라면… 오르딘 님 말인가요?' },
        { who: 'bram', text: '……일단 오늘 밤을 넘기자. 놈들이 온다.' },
      ],
      post: [
        { who: 'commander', text: '브람, 아까 하던 얘기 마저 해 주세요.' },
        { who: 'bram', text: '확실하지 않은 의심은 칼보다 위험하다.' },
        { who: 'bram', text: '할바르를 만나면, 그 입으로 직접 듣자.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '눈보라가 시야를 가린다. 서로 붙어서 싸워!' } ],
        wave: [ { who: 'bram', text: '대규모다! 방어선을 한 줄로 좁혀라!' } ],
        danger: [ { who: 'sera', text: '{commander}, 몸이 너무 차가워! 물러나!' } ],
        last: [ { who: 'bark', text: '마지막이오! 이놈만 치우면 눈 좀 붙입시다!' } ],
      },
    },
    19: {
      pre: [
        { who: 'narrator', text: '빙하가 갈라진 틈. 그 아래로 보랏빛이 새어 나왔다.' },
        { who: 'sera', text: '이건… 하늘이 갈라졌던 그 밤 이야기랑 똑같아.' },
        { who: 'bram', text: '15년 전의 균열이다. 작지만, 분명히.' },
        { who: 'commander', text: '틈에서 나오는 놈들을 막아야 해. 내려간다.' },
      ],
      post: [
        { who: 'narrator', text: '틈은 줄어들었지만, 완전히 닫히지는 않았다.' },
        { who: 'commander', text: '이 틈에서 냉기가 흘러나와 산맥을 덮었던 거야.' },
        { who: 'bram', text: '누군가 일부러 이 틈을 벌렸다. 정상의 그자가.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '틈에서 나오는 족족 끊어 내! 퍼지게 두지 마!' } ],
        wave: [ { who: 'sera', text: '틈이 맥박치듯 커졌어! 또 쏟아져!' } ],
        last: [ { who: 'commander', text: '하나 남았다. 틈을 밀어붙여 닫는다!' } ],
      },
    },
    20: {
      pre: [
        { who: 'narrator', text: '백설 산맥 정상, 얼음으로 지은 성채.' },
        { who: 'bram', text: '할바르! 나다, 브람이다! 왜 이런 짓을 하나!' },
        { who: 'boss', text: '브람… 오랜만이군. 난 명령을 따를 뿐이다.' },
        { who: 'boss', text: '열쇠를 찾아라. 그것이 내게 내려진 명령.' },
        { who: 'boss', text: '그 손의 흉터… 그래, 갈라진 밤의 아이로군.' },
        { who: 'commander', text: '날 알아? 열쇠라는 게 대체 뭐야!' },
      ],
      post: [
        { who: 'boss', text: '브람… 고맙다… 이제야 얼음이 녹는군….' },
        { who: 'boss', text: '대마도사를… 그자를 믿지….' },
        { who: 'narrator', text: '말을 끝맺기 전에, 기사의 몸은 눈가루로 흩어졌다.' },
        { who: 'bram', text: '……편히 쉬게, 친구.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '저자를 멈춰야 산맥이 산다. 간다!' } ],
        boss: [ { who: 'boss', text: '얼어붙어라. 망설임도, 기억도 전부.' } ],
        wave: [ { who: 'kasha', text: '뒤쪽 증원은 검은 깃이 막을게! 앞만 봐!' } ],
        danger: [ { who: 'bram', text: '지휘관! 냉기에 휩쓸리지 마라, 물러서!' } ],
        last: [ { who: 'sera', text: '이제 하나야. 이 추위를 끝내자!' } ],
      },
    },
    // ═══ Episode 3: 늪지의 저주 ═══
    21: {
      pre: [
        { who: 'narrator', text: '습지 마을 갈대목. 말뚝 위에 지은 집들이 기울어 있었다.' },
        { who: 'sera', text: '마을 사람 절반이 앓고 있어. 움직일 수가 없대.' },
        { who: 'bark', text: '그럼 여기서 버티는 수밖에. 놈들이 몰려오는군.' },
        { who: 'commander', text: '여울에 발 묶이면 집중포화야. 마른 땅을 골라 서.' },
      ],
      post: [
        { who: 'sera', text: '저 짐승들, 원래는 습지 사슴이랑 늑대였대.' },
        { who: 'commander', text: '병든 게 아니라 바뀐 거야. 누가 바꿨지.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '마을 방벽을 지킨다! 물가로 끌려 나가지 마!' } ],
        wave: [ { who: 'bark', text: '물속에서 뭔가 기어 나오오! 두 번째 무리요!' } ],
        last: [ { who: 'sera', text: '하나 남았어. 마을 사람들이 보고 있어!' } ],
      },
    },
    22: {
      pre: [
        { who: 'narrator', text: '세라는 마을 회관을 진료소로 바꾸었다.' },
        { who: 'sera', text: '치료를 멈출 수 없어. 여기만큼은 꼭 지켜 줘.' },
        { who: 'bram', text: '소환술사와 무당이 섞였다. 저주가 날아올 거다.' },
        { who: 'commander', text: '소환수는 본체를 치면 사라져. 술사를 노려.' },
      ],
      post: [
        { who: 'sera', text: '다들 살았어. 오늘은… 아무도 안 죽었어.' },
        { who: 'commander', text: '세라, 사흘째 안 잤지. 이제 좀 쉬어.' },
        { who: 'sera', text: '쉬면 누가 죽을까 봐 무서워.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '진료소 벽을 지켜! 세라가 치료 중이야!' } ],
        wave: [ { who: 'bram', text: '사제까지 끌고 왔군. 적이 회복하기 전에 쳐라.' } ],
        danger: [ { who: 'sera', text: '{commander}! 지금 그쪽으로 갈게, 버텨!' } ],
      },
    },
    23: {
      pre: [
        { who: 'narrator', text: '습지 가장자리의 맹그로브 숲. 뿌리가 길을 막았다.' },
        { who: 'bark', text: '역병이 시작된 곳이 이 숲 안쪽이래요.' },
        { who: 'bram', text: '나무 사이는 숨기 좋다. 적도, 우리도.' },
        { who: 'commander', text: '숲을 끼고 싸워. 암살자는 그림자에서 튀어나온다.' },
      ],
      post: [
        { who: 'narrator', text: '숲 한가운데, 검은 진흙으로 빚은 토템이 서 있었다.' },
        { who: 'sera', text: '이 토템에서 병이 퍼지고 있어. 일부러 세운 거야!' },
        { who: 'commander', text: '자연 재해가 아니었어. 누군가 습지를 병들게 했어.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '나무 뒤를 확인해! 암살자가 숨어 있다!' } ],
        wave: [ { who: 'bark', text: '공병 놈들이 뿌리 사이에 폭탄을 묻었소!' } ],
        last: [ { who: 'commander', text: '마지막이다. 토템까지 길이 열린다!' } ],
      },
    },
    24: {
      pre: [
        { who: 'narrator', text: '토템은 하나가 아니었다. 습지 곳곳에 세워져 있었다.' },
        { who: 'commander', text: '가장 큰 토템부터 부순다. 이번엔 우리가 공격이야.' },
        { who: 'bark', text: '저 근육 덩어리들, 다 투사요. 나랑 같은 과네.' },
        { who: 'bark', text: '투사는 맞받아치는 게 무섭소. 혼자 덤비지 마쇼.' },
      ],
      post: [
        { who: 'narrator', text: '토템이 무너지자 고인 물에서 검은 연기가 빠져나갔다.' },
        { who: 'bark', text: '크으, 주먹이 얼얼하네. 그래도 속은 시원하오.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '토템까지 밀고 들어간다! 진흙에 발 묶이지 마!' } ],
        wave: [ { who: 'bram', text: '토템을 지키는 정예다. 둘씩 짝지어 상대하라.' } ],
        danger: [ { who: 'bark', text: '대장 다쳤소! 내가 앞을 막을 테니 빠지쇼!' } ],
      },
    },
    25: {
      pre: [
        { who: 'narrator', text: '습지 한복판, 반쯤 가라앉은 고대 신전이 나타났다.' },
        { who: 'bram', text: '여기가 저주의 심장이군. 냄새부터 다르다.' },
        { who: 'sera', text: '신전 안에서 주문 외는 소리가 들려. 의식 중이야.' },
        { who: 'commander', text: '의식을 끝내기 전에 끊는다. 돌입!' },
      ],
      post: [
        { who: 'commander', text: '이 제기… 아르덴 왕실의 문장이 새겨져 있어.' },
        { who: 'bark', text: '왕실? 우리를 보낸 그 왕실 말이오?' },
        { who: 'bram', text: '……일단 챙겨 둬라. 증거가 될 거다.' },
        { who: 'sera', text: '브람 아저씨, 뭔가 알고 계시죠?' },
      ],
      battle: {
        start: [ { who: 'commander', text: '주문을 외는 놈들부터! 의식을 멈춰라!' } ],
        wave: [ { who: 'bram', text: '신전 깊은 곳에서 기사들이 나온다. 정면으로 받지 마.' } ],
        last: [ { who: 'sera', text: '마지막 하나! 주문이 끊어지고 있어!' } ],
      },
    },
    26: {
      pre: [
        { who: 'narrator', text: '갈대목 주민들이 마침내 습지를 떠나기로 했다.' },
        { who: 'commander', text: '행렬을 지키며 이동한다. 쉬지 않고 간다.' },
        { who: 'sera', text: '안 돼! 환자들은 그 속도 못 따라와!' },
        { who: 'commander', text: '여기 오래 있으면 다 죽어. 나도 고르고 싶지 않아.' },
        { who: 'bram', text: '둘 다 맞다. 그러니 둘 다 지킬 방법을 찾아라.' },
        { who: 'commander', text: '……행렬 뒤에 방어선을 친다. 환자 속도에 맞추자.' },
      ],
      post: [
        { who: 'sera', text: '아까는 소리 질러서 미안해.' },
        { who: 'commander', text: '아니. 네가 말 안 했으면 난 잘못 골랐을 거야.' },
        { who: 'bram', text: '혼자 정하지 않는 것. 그것도 지휘다.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '피난 행렬 뒤를 막는다! 한 명도 놓치지 마!' } ],
        wave: [ { who: 'bark', text: '늪에서 또 기어 나오오! 행렬 옆구리요!' } ],
        danger: [ { who: 'sera', text: '{commander}, 무리하지 마! 너도 사람이야!' } ],
        last: [ { who: 'bram', text: '하나 남았다. 행렬은 무사하다.' } ],
      },
    },
    27: {
      pre: [
        { who: 'narrator', text: '신전 반대편 유적. 붉은 망토의 기사들이 진을 쳤다.' },
        { who: 'bram', text: '볼카르 제국 기사단이다. 왜 남의 나라 늪에 있지?' },
        { who: 'kasha', text: '오랜만이야. 제국 놈들 냄새 맡고 쫓아왔어.' },
        { who: 'commander', text: '카샤? …같이 가자. 이번엔 경주 없이.' },
        { who: 'kasha', text: '흥, 이번만이야.' },
      ],
      post: [
        { who: 'kasha', text: '제국 기사 품에 이게 있었어. 다음 지령서.' },
        { who: 'commander', text: '"습지가 끝나면 화산으로." 제국도 한패인가.' },
        { who: 'bram', text: '혹은 제국도 누군가의 지령을 받고 있거나.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '기사 옆은 엄호가 붙는다. 암살자로 파고들어!' } ],
        wave: [ { who: 'kasha', text: '유적 뒤에서 궁수들이야! 고지대를 잡았어!' } ],
        last: [ { who: 'kasha', text: '마지막은 내 거. 저 지령서 들고 있는 놈이야.' } ],
      },
    },
    28: {
      pre: [
        { who: 'narrator', text: '신전 지하. 물이 빠진 바닥에 균열이 입을 벌렸다.' },
        { who: 'sera', text: '북방에서 본 거랑 같아. 보랏빛 틈이야.' },
        { who: 'commander', text: '흉터가 쑤셔. 이 아래가 저주의 뿌리야.' },
        { who: 'bram', text: '틈을 지키는 마법사들이 있다. 의식을 끊어라.' },
      ],
      post: [
        { who: 'narrator', text: '두 번째 균열이 잦아들었다. 그러나 닫히지 않았다.' },
        { who: 'commander', text: '북방에도, 여기도. 누가 틈을 하나씩 벌리고 있어.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '균열 쪽으로 밀어붙인다! 의식을 깨라!' } ],
        wave: [ { who: 'bark', text: '틈에서 공병들이 기어 나오오! 폭탄 냄새가!' } ],
        danger: [ { who: 'bram', text: '지휘관! 균열 기운에 잠식당하지 마라!' } ],
      },
    },
    29: {
      pre: [
        { who: 'narrator', text: '독무가 짙게 깔린 습지 심부. 앞이 보이지 않았다.' },
        { who: 'sera', text: '이 안개 자체가 병이야. 오래 있으면 안 돼.' },
        { who: 'bram', text: '저 너머가 습지의 제왕이 깨어난 신전이다.' },
        { who: 'commander', text: '길을 연다. 안개 속에선 서로 떨어지지 마.' },
      ],
      post: [
        { who: 'narrator', text: '안개가 갈라지며 거대한 신전의 그림자가 드러났다.' },
        { who: 'bark', text: '저 안에 있는 놈이 진짜 왕이구먼.' },
        { who: 'commander', text: '내일 끝낸다. 오늘 밤은 모두 몸을 녹여.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '안개 속에선 붙어 다녀! 연계 공격을 노려!' } ],
        wave: [ { who: 'sera', text: '안개 속에서 소환수가 계속 늘어나!' } ],
        last: [ { who: 'commander', text: '하나 남았어. 길이 열린다!' } ],
      },
    },
    30: {
      pre: [
        { who: 'narrator', text: '신전의 가장 깊은 곳. 늪물이 거대한 형체로 일어섰다.' },
        { who: 'boss', text: '작은 것들. 나를 부른 자의 냄새가 나는구나.' },
        { who: 'commander', text: '널 부른 자? 그게 누구야!' },
        { who: 'boss', text: '보랏빛 손을 가진 아이여. 너도 곧 그분께 간다.' },
        { who: 'sera', text: '저것만 쓰러뜨리면 습지가 깨끗해져. 가자!' },
      ],
      post: [
        { who: 'boss', text: '늪은… 마르지 않는다… 불이… 다음 차례….' },
        { who: 'narrator', text: '제왕이 녹아내린 자리에서 낡은 지도가 발견되었다.' },
        { who: 'commander', text: '세 곳에 표시가 있어. 북방, 습지, 그리고 제국.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '제왕을 지키는 술사부터 걷어 낸다!' } ],
        boss: [ { who: 'boss', text: '늪이 너희를 삼키리라. 숨도, 이름도.' } ],
        wave: [ { who: 'bram', text: '소환수가 끝없이 나온다. 본체를 노려라!' } ],
        danger: [ { who: 'sera', text: '독이 퍼지고 있어! 내 쪽으로 와, {commander}!' } ],
        last: [ { who: 'bark', text: '마지막 하나요! 늪 청소 끝냅시다!' } ],
      },
    },
    // ═══ Episode 4: 불타는 제국 ═══
    31: {
      pre: [
        { who: 'narrator', text: '국경의 돌 요새. 반란군이 마지막으로 지키는 관문.' },
        { who: 'narrator', text: '지평선 너머로 제국 정규군의 창끝이 번뜩였다.' },
        { who: 'bram', text: '수가 많다. 하지만 성벽은 두껍다. 버틸 수 있어.' },
        { who: 'commander', text: '성벽에 붙는 순서대로 끊는다. 서두르지 마.' },
      ],
      post: [
        { who: 'narrator', text: '반란군 병사들이 클랜을 향해 환호를 보냈다.' },
        { who: 'bark', text: '이 나라 사람들한테 박수받을 줄은 몰랐네.' },
        { who: 'commander', text: '여기 사람들도 그냥 집을 지키려는 거야. 우리처럼.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '성벽을 등지고 싸워! 이 관문이 무너지면 끝이야!' } ],
        wave: [ { who: 'bram', text: '제국 창병대다. 대열이 길다, 측면을 쳐라.' } ],
        danger: [ { who: 'sera', text: '{commander}, 성벽 안쪽으로 물러나!' } ],
        last: [ { who: 'bark', text: '마지막 놈이오! 관문은 우리 거요!' } ],
      },
    },
    32: {
      pre: [
        { who: 'narrator', text: '제국 내륙으로 이어지는 붉은 협곡.' },
        { who: 'kasha', text: '멈춰, {commander}. 이 길로 오지 마.' },
        { who: 'kasha', text: '검은 깃 본대가 제국과 계약했어. 난 단장이고.' },
        { who: 'commander', text: '그럼 우린 적이야?' },
        { who: 'kasha', text: '…난 직접 칼 안 뽑아. 하지만 협곡엔 제국군이 가득해.' },
      ],
      post: [
        { who: 'commander', text: '카샤는 끝까지 안 나타났어.' },
        { who: 'sera', text: '저 사람도 괴로운 거야. 표정 봤잖아.' },
        { who: 'bram', text: '계약에 묶인 칼은 언젠가 스스로 끊는다.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '협곡 위 고지대를 먼저 잡는다! 올라가!' } ],
        wave: [ { who: 'bark', text: '협곡 양쪽에서 암살자들이 쏟아지오!' } ],
        last: [ { who: 'commander', text: '하나 남았다. 협곡을 빠져나간다!' } ],
      },
    },
    33: {
      pre: [
        { who: 'narrator', text: '화산 기슭의 반란군 마을, 잿빛 우물.' },
        { who: 'narrator', text: '마을을 둘러싼 용암 수로가 붉게 끓고 있었다.' },
        { who: 'bram', text: '공병들이 폭탄을 들고 온다. 성벽을 노릴 거다.' },
        { who: 'sera', text: '용암 옆에 서 있으면 화상 입어. 위치 잘 잡아.' },
        { who: 'commander', text: '공병부터 쓰러뜨린다. 폭탄이 터지기 전에!' },
      ],
      post: [
        { who: 'narrator', text: '마을 아이들이 클랜원들에게 그을린 빵을 건넸다.' },
        { who: 'bark', text: '탄 빵이 이렇게 맛있을 줄이야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '공병을 성벽에 붙이지 마! 접근 전에 끊어!' } ],
        wave: [ { who: 'bram', text: '마법사 부대가 뒤에서 불을 쏜다. 흩어져라!' } ],
        danger: [ { who: 'sera', text: '화상이 심해! 용암에서 떨어져, {commander}!' } ],
        last: [ { who: 'sera', text: '마지막이야! 마을은 무사해!' } ],
      },
    },
    34: {
      pre: [
        { who: 'narrator', text: '화산 분화구 가장자리. 제국 마법사들의 의식장.' },
        { who: 'bram', text: '화산을 깨우는 의식이다. 성공하면 이 땅이 불바다가 된다.' },
        { who: 'commander', text: '북방의 냉기, 습지의 역병… 이번엔 불이야.' },
        { who: 'commander', text: '의식을 끊는다. 용암에 길이 막혀도 돌아서 간다.' },
      ],
      post: [
        { who: 'narrator', text: '의식이 깨지자 분화구의 울림이 잦아들었다.' },
        { who: 'commander', text: '여기도 바닥에 갈라진 별 문양이 있어.' },
        { who: 'bram', text: '세 곳 모두 같은 자가 설계했다는 뜻이다.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '술사들이 의식 중이야. 시간이 없다, 돌격!' } ],
        wave: [ { who: 'bark', text: '분화구에서 소환수가 기어 올라오오!' } ],
        last: [ { who: 'commander', text: '마지막 술사다. 의식을 완전히 끊어!' } ],
      },
    },
    35: {
      pre: [
        { who: 'narrator', text: '흑요석 성채, 흑요문. 제국 서부 방위의 요충지.' },
        { who: 'narrator', text: '성채 아래 마을이 제국군의 손에 불타고 있었다.' },
        { who: 'kasha', text: '……이건 계약에 없었어. 자기 백성을 태우다니.' },
        { who: 'kasha', text: '검은 깃은 계약을 파기한다. 지금부터 네 편이야.' },
        { who: 'commander', text: '돌아와 줘서 고마워, 카샤.' },
        { who: 'kasha', text: '착각 마. 나도 내 이름이 더러워지는 건 싫거든.' },
      ],
      post: [
        { who: 'kasha', text: '제국 지휘관 방에서 이걸 찾았어. 왕국 쪽 서신이야.' },
        { who: 'commander', text: '서명이 지워져 있어. 하지만 이 필체…' },
        { who: 'bram', text: '황성으로 가자. 원본은 황제가 갖고 있을 거다.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '성채를 지키면서 문을 연다! 둘 다 해낸다!' } ],
        wave: [ { who: 'kasha', text: '성벽 위 궁수들은 검은 깃이 맡을게!' } ],
        danger: [ { who: 'kasha', text: '{commander}, 앞에 너무 나왔어! 엄호할게!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 성문 열어젖힙시다!' } ],
      },
    },
    36: {
      pre: [
        { who: 'narrator', text: '황성으로 물자를 나르는 용암 운하.' },
        { who: 'bark', text: '저 다리 위로 보급 마차가 쉴 새 없이 오가오.' },
        { who: 'bram', text: '다리 위에선 밀치기를 써라. 막힌 쪽으로 밀면 부딪힌다.' },
        { who: 'commander', text: '보급선을 끊으면 황성이 흔들려. 간다!' },
      ],
      post: [
        { who: 'narrator', text: '보급 다리가 무너지고, 운하 너머 황성이 고립되었다.' },
        { who: 'kasha', text: '이제 황제는 독 안에 든 쥐야.' },
        { who: 'commander', text: '쥐가 독 안에서 제일 사나워져. 방심하지 마.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '다리를 장악한다! 용암 쪽으로 밀리지 마!' } ],
        wave: [ { who: 'bark', text: '황성에서 기사단이 내려오오! 다리 끝이오!' } ],
        last: [ { who: 'kasha', text: '마지막이야. 다리 끊을 준비해!' } ],
      },
    },
    37: {
      pre: [
        { who: 'narrator', text: '반란군 본진. 황제가 마지막 반격을 시작했다.' },
        { who: 'narrator', text: '하늘에서 불덩이가 비처럼 쏟아졌다.' },
        { who: 'sera', text: '부상병이 넘쳐. 본진이 뚫리면 다 죽어!' },
        { who: 'bram', text: '이 싸움은 버티는 쪽이 이긴다. 진지를 지켜라.' },
        { who: 'commander', text: '방어 태세로 버틸 사람과 칠 사람을 나눈다!' },
      ],
      post: [
        { who: 'narrator', text: '불의 비가 그치고, 황제군이 물러갔다.' },
        { who: 'sera', text: '버텼어… 우리가 버텼어.' },
        { who: 'bram', text: '훌륭했다, 지휘관. 이제 꼬맹이라고 못 부르겠군.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '본진 방벽을 지킨다! 불덩이를 피하며 싸워!' } ],
        wave: [ { who: 'bram', text: '암살자들이 방벽 틈으로 들어온다! 후방을 봐라!' } ],
        danger: [ { who: 'sera', text: '{commander}! 불길 속에 있으면 안 돼!' } ],
        last: [ { who: 'bark', text: '마지막 놈! 본진은 무사하오!' } ],
      },
    },
    38: {
      pre: [
        { who: 'narrator', text: '볼카르 황성 외곽. 성벽이 세 겹으로 둘러쳐 있었다.' },
        { who: 'kasha', text: '첫 번째 성벽은 우리가 뚫고, 반란군이 뒤를 지킨대.' },
        { who: 'bram', text: '성벽 위 창병과 궁수가 고지대를 잡고 있다.' },
        { who: 'commander', text: '기사 엄호 밖에 있는 놈부터 쳐서 틈을 만든다.' },
      ],
      post: [
        { who: 'narrator', text: '황성의 외벽이 무너졌다. 안쪽에서 열기가 뿜어졌다.' },
        { who: 'commander', text: '황궁 아래에서 흉터가 아플 만큼 강한 기운이 느껴져.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '성벽 위를 노려! 고지대를 빼앗는다!' } ],
        wave: [ { who: 'kasha', text: '황궁 근위대야. 이놈들은 진짜 강해!' } ],
        danger: [ { who: 'bram', text: '지휘관, 성벽 아래서 버티지 마라! 움직여!' } ],
      },
    },
    39: {
      pre: [
        { who: 'narrator', text: '황궁 지하. 거대한 균열이 붉게 박동하고 있었다.' },
        { who: 'sera', text: '북방, 습지보다 훨씬 커. 이게 세 번째야.' },
        { who: 'bram', text: '세 균열이 모이면… 무언가 거대한 문이 열린다.' },
        { who: 'commander', text: '여길 지키는 놈들부터 치운다. 균열을 막아야 해.' },
      ],
      post: [
        { who: 'narrator', text: '균열 앞 제단에 봉인된 서신 한 통이 놓여 있었다.' },
        { who: 'commander', text: '"약속대로 불꽃을 키워라. 문이 열리면 보답하겠다."' },
        { who: 'commander', text: '인장은… 오르딘이야. 왕실 대마도사.' },
        { who: 'sera', text: '그럼 우리는 지금까지 누구를 위해 싸운 거야?' },
      ],
      battle: {
        start: [ { who: 'commander', text: '균열을 지키는 술사를 노린다! 돌입!' } ],
        wave: [ { who: 'bark', text: '균열이 커지면서 공병까지 튀어나오오!' } ],
        danger: [ { who: 'sera', text: '균열 기운이 너한테 몰려, {commander}! 떨어져!' } ],
        last: [ { who: 'commander', text: '하나 남았다. 제단까지 간다!' } ],
      },
    },
    40: {
      pre: [
        { who: 'narrator', text: '황궁 옥좌의 방. 사방이 용암 빛으로 이글거렸다.' },
        { who: 'boss', text: '왕국의 개들이 여기까지 왔군.' },
        { who: 'commander', text: '이 서신, 오르딘이 보낸 거지? 무슨 약속을 했어!' },
        { who: 'boss', text: '약속? 불을 키우면 새 세상을 준다 했지.' },
        { who: 'boss', text: '그런 건 이제 아무래도 좋다. 다 태워 주마!' },
      ],
      post: [
        { who: 'boss', text: '크윽… 우리는… 예비일 뿐이었다….' },
        { who: 'boss', text: '진짜 문은… 심연에… 너희 대마도사가 원하는 건….' },
        { who: 'narrator', text: '황제의 몸이 불꽃이 되어 사그라들었다.' },
        { who: 'commander', text: '예비… 그럼 진짜는 아직 시작도 안 한 거야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '황제 주변의 마법사부터! 불을 끊는다!' } ],
        boss: [ { who: 'boss', text: '타올라라! 제국의 불은 꺼지지 않는다!' } ],
        wave: [ { who: 'kasha', text: '옥좌 뒤에서 근위 소환술사들이 나와!' } ],
        danger: [ { who: 'bram', text: '지휘관! 불기둥이 온다, 피해라!' } ],
        last: [ { who: 'sera', text: '마지막이야! 이 불을 끝내자!' } ],
      },
    },
    // ═══ Episode 5: 심연의 종말 ═══
    41: {
      pre: [
        { who: 'narrator', text: '심연의 가장자리. 연합군이 급히 세운 전진기지.' },
        { who: 'bram', text: '아래에서 올라오는 놈들을 여기서 막는다.' },
        { who: 'bark', text: '이 목책, 바람만 세게 불어도 넘어가겠는데.' },
        { who: 'commander', text: '목책이 약하면 우리가 벽이 된다. 자리 지켜!' },
      ],
      post: [
        { who: 'sera', text: '저 마물들, 북방 언데드처럼 눈이 비어 있어.' },
        { who: 'commander', text: '같은 손에서 나온 거야. 아래로 내려가야 해.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '심연에서 올라온다! 기지를 지켜라!' } ],
        wave: [ { who: 'bram', text: '두 번째 물결이다. 기사들이 앞장섰군.' } ],
        last: [ { who: 'bark', text: '마지막 놈이오! 구멍으로 돌려보냅시다!' } ],
      },
    },
    42: {
      pre: [
        { who: 'narrator', text: '심연 벽을 따라 나선형 길이 끝없이 이어졌다.' },
        { who: 'sera', text: '내려갈수록 빛이 줄어들어. 기도도 무거워져.' },
        { who: 'bram', text: '좁은 길에선 밀치기가 무섭다. 벽 쪽에 서라.' },
        { who: 'commander', text: '길목마다 적이 있어. 하나씩 뚫고 내려간다.' },
      ],
      post: [
        { who: 'narrator', text: '어둠 속에서 누군가 {commander}의 이름을 속삭였다.' },
        { who: 'commander', text: '……방금 누가 날 불렀어?' },
        { who: 'bark', text: '아무도 안 불렀소, 대장. 소름 돋게 왜 그러오.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '내리막을 타고 밀어붙인다! 전진!' } ],
        wave: [ { who: 'bram', text: '아래에서 궁수다. 벽 그늘로 붙어라.' } ],
        danger: [ { who: 'sera', text: '{commander}, 낭떠러지 쪽이야! 조심해!' } ],
      },
    },
    43: {
      pre: [
        { who: 'narrator', text: '고대인의 승강 제단. 아래로 내려가는 유일한 길.' },
        { who: 'bram', text: '제단이 작동하려면 시간이 걸린다. 그동안 버텨라.' },
        { who: 'commander', text: '제단을 중심으로 원형 진. 어느 쪽도 비우지 마.' },
        { who: 'bark', text: '전사 놈들이 떼로 오는구먼. 오늘 주먹 좀 쓰겠네.' },
      ],
      post: [
        { who: 'narrator', text: '돌 제단이 낮게 울리며 심연 아래로 가라앉기 시작했다.' },
        { who: 'sera', text: '이 제단, 사람이 만든 거 맞아? 너무 오래됐어.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '제단이 움직일 때까지 버틴다! 진형 유지!' } ],
        wave: [ { who: 'bram', text: '투사 부대다. 반격을 조심해라, 둘이서 쳐라!' } ],
        danger: [ { who: 'bram', text: '지휘관, 한 차례 방어 태세로 숨을 골라라!' } ],
        last: [ { who: 'sera', text: '한 명 남았어! 제단이 움직이기 시작해!' } ],
      },
    },
    44: {
      pre: [
        { who: 'narrator', text: '심연 중턱, 거대한 고대 요새가 어둠 속에 잠들어 있었다.' },
        { who: 'bram', text: '이 성벽의 문양, 북방 유적과 같은 자들이 지었다.' },
        { who: 'commander', text: '안을 차지한 놈들을 몰아내고 기록을 찾는다.' },
      ],
      post: [
        { who: 'narrator', text: '요새 벽화에는 갈라진 별을 손에 지닌 사람들이 있었다.' },
        { who: 'sera', text: '이 사람들, 하늘의 틈을 손으로 닫고 있어.' },
        { who: 'commander', text: '"봉인자." 열쇠는… 핏줄로 이어진다고 적혀 있어.' },
        { who: 'bram', text: '……때가 됐군. 이 싸움이 끝나면 다 말해 주마.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '성문을 부수고 들어간다! 고대 요새를 되찾아!' } ],
        wave: [ { who: 'bark', text: '성 안쪽에서 술사들이 우르르 나오오!' } ],
        last: [ { who: 'commander', text: '마지막 하나. 벽화까지 길을 연다!' } ],
      },
    },
    45: {
      pre: [
        { who: 'narrator', text: '요새를 지나 더 깊은 곳. 검은 갑옷의 기사가 기다렸다.' },
        { who: 'boss', text: '열쇠가 제 발로 내려왔구나.' },
        { who: 'commander', text: '다들 날 열쇠라고 부르는군. 내 이름은 {commander}. 기억해 둬.' },
        { who: 'boss', text: '이름 따위 문 앞에선 무의미하다.' },
        { who: 'bram', text: '놈은 기사다. 정면은 단단하다. 뒤를 노려라.' },
      ],
      post: [
        { who: 'boss', text: '나는… 하위의 문지기일 뿐… 더 깊은 곳에서….' },
        { who: 'narrator', text: '기사가 쓰러진 자리에서 땅이 더 깊이 꺼져 내렸다.' },
        { who: 'commander', text: '아직 바닥이 아니야. 더 큰 게 있어.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '호위를 걷어 내고 기사를 포위한다!' } ],
        boss: [ { who: 'boss', text: '열쇠는 문으로. 나머지는 어둠으로.' } ],
        wave: [ { who: 'bram', text: '심연 기사단이다. 엄호 대형을 깨라!' } ],
        danger: [ { who: 'sera', text: '{commander}! 저 기사가 너만 노리고 있어!' } ],
        last: [ { who: 'bark', text: '마지막 하나요! 이 깡통 녹여 버립시다!' } ],
      },
    },
    46: {
      pre: [
        { who: 'narrator', text: '심연의 하층. 소환술사들이 마물을 끝없이 불러냈다.' },
        { who: 'bram', text: '술사를 치지 않으면 소환수는 끝없이 나온다.' },
        { who: 'kasha', text: '그럼 내가 뒤로 파고들게. 그림자 길은 내 전문이야.' },
        { who: 'commander', text: '카샤가 술사를 치는 동안, 우리가 앞을 붙잡는다.' },
      ],
      post: [
        { who: 'kasha', text: '술사 열둘. 내가 일곱. 이번엔 내 승리야.' },
        { who: 'commander', text: '그래, 이번엔 인정할게.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '술사가 우선이다! 소환수에 붙잡히지 마!' } ],
        wave: [ { who: 'kasha', text: '술사가 또 진을 쳤어! 이번엔 뒤쪽이야!' } ],
        last: [ { who: 'kasha', text: '마지막 술사, 내가 간다!' } ],
      },
    },
    47: {
      pre: [
        { who: 'narrator', text: '사방이 막힌 동굴. 클랜은 고립되었다.' },
        { who: 'sera', text: '나… 기도가 안 나와. 힘이 바닥났어.' },
        { who: 'commander', text: '세라는 뒤에서 쉬어. 앞은 우리가 지킨다.' },
        { who: 'bram', text: '마법사 무리가 위에서 내려다본다. 엄폐를 해라.' },
        { who: 'commander', text: '경계 태세로 다가오는 놈부터 먼저 친다.' },
      ],
      post: [
        { who: 'sera', text: '미안해. 나 때문에 다들 더 다쳤어.' },
        { who: 'commander', text: '네가 쉬어서 다음 싸움이 있는 거야. 미안해하지 마.' },
        { who: 'bram', text: '(…많이 컸군. 그 사람들을 꼭 닮았어.)' },
      ],
      battle: {
        start: [ { who: 'commander', text: '동굴 입구를 막는다! 세라를 지켜!' } ],
        wave: [ { who: 'bark', text: '천장에서 소환수가 떨어지오!' } ],
        danger: [ { who: 'bram', text: '지휘관이 쓰러지면 다 끝이다! 물러서라!' } ],
        last: [ { who: 'bram', text: '하나 남았다. 침착하게 끝내라.' } ],
      },
    },
    48: {
      pre: [
        { who: 'narrator', text: '심연을 가로지르는 돌다리. 곳곳이 금 가 있었다.' },
        { who: 'bram', text: '다리 너머가 심연의 바닥이다. 놈의 기척이 느껴진다.' },
        { who: 'bark', text: '이 다리 무너지면 돌아갈 길도 없겠는데.' },
        { who: 'commander', text: '빨리 건너고, 건너편을 지킨다. 둘 다 해야 해.' },
      ],
      post: [
        { who: 'narrator', text: '다리 절반이 무너져 내렸다. 브람의 다리에서 피가 흘렀다.' },
        { who: 'sera', text: '아저씨, 다리가… 지금 치료할게요!' },
        { who: 'bram', text: '괜찮다. 늙은 몸은 원래 삐걱거린다.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '다리 위로 전진! 금 간 곳에 오래 서지 마!' } ],
        wave: [ { who: 'kasha', text: '건너편에서 기사단이 다리를 막아섰어!' } ],
        danger: [ { who: 'bram', text: '지휘관, 다리 끝으로 밀리면 끝이다!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 다리 넘어갑시다!' } ],
      },
    },
    49: {
      pre: [
        { who: 'bram', text: '약속대로 말해 주마. 15년 전, 그 밤의 일을.' },
        { who: 'bram', text: '네 부모는 왕실 봉인자였다. 하늘의 틈을 닫는 사람들.' },
        { who: 'bram', text: '오르딘은 그 틈을 열려 했고, 둘은 목숨으로 닫았다.' },
        { who: 'bram', text: '난 그날 네 부모와 약속했다. 아이를 지키겠다고.' },
        { who: 'commander', text: '……그래서 마을에 계셨던 거예요? 15년 동안?' },
        { who: 'bram', text: '그래. 그리고 오늘이 그 약속을 지킬 날이다.' },
      ],
      post: [
        { who: 'bram', text: '지휘관. 저 통로는 내가 지킨다. 너희는 바닥으로 가라.' },
        { who: 'commander', text: '안 돼요! 같이 가요, 다리 다쳤잖아요!' },
        { who: 'bram', text: '이 다리로는 짐이 된다. 지휘관이면 알 거다.' },
        { who: 'bram', text: '모두를 살릴 순 없어도, 아무도 버리지 않는 거다. 가라.' },
      ],
      battle: {
        start: [ { who: 'bram', text: '이 통로만 지키면 된다. 내가 앞에 선다!' } ],
        wave: [ { who: 'commander', text: '끝이 없어… 브람, 조금만 더 버텨요!' } ],
        danger: [ { who: 'bram', text: '네가 쓰러지면 내 약속도 끝이다! 물러서라!' } ],
        last: [ { who: 'bram', text: '하나 남았다. 이제 가야 할 때다, 지휘관.' } ],
      },
    },
    50: {
      pre: [
        { who: 'narrator', text: '심연의 바닥. 뒤쪽 통로에서 들리던 칼소리가 멎었다.' },
        { who: 'sera', text: '{commander}… 브람 아저씨 소리가 안 들려.' },
        { who: 'commander', text: '……앞만 봐. 브람이 열어 준 길이야.' },
        { who: 'boss', text: '늙은 기사는 훌륭했다. 다음은 네 차례다, 열쇠.' },
        { who: 'commander', text: '그 입으로 브람을 말하지 마!' },
      ],
      post: [
        { who: 'boss', text: '심연은… 준비 단계였다… 마계의 길이… 열린다….' },
        { who: 'narrator', text: '돌아가는 통로 끝에는 부러진 검 하나만 남아 있었다.' },
        { who: 'commander', text: '브람… 약속, 지키셨네요. 끝까지.' },
        { who: 'commander', text: '이번엔 제가 지킬게요. 남은 사람 전부.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '전원 공격! 브람이 지킨 길을 헛되게 하지 마!' } ],
        boss: [ { who: 'boss', text: '분노로 휘두르는 칼은 무디다. 와 봐라!' } ],
        wave: [ { who: 'kasha', text: '바닥에서 정예가 깨어나! 정신 차려!' } ],
        danger: [ { who: 'sera', text: '{commander}, 혼자 싸우지 마! 우리가 있잖아!' } ],
        last: [ { who: 'bark', text: '하나 남았소, 대장! 영감님 몫까지!' } ],
      },
    },
    // ═══ Episode 6: 지옥문 ═══
    51: {
      pre: [
        { who: 'narrator', text: '왕도 남쪽 들녘. 하늘의 균열 아래로 피난민이 몰렸다.' },
        { who: 'sera', text: '왕도로 가는 길이 막혔대. 다들 여기서 오도 가도 못해.' },
        { who: 'commander', text: '피난 진지를 세운다. 균열에서 내려오는 건 다 막아.' },
        { who: 'bark', text: '영감님 없이 하는 첫 방어전이네. 해 봅시다.' },
      ],
      post: [
        { who: 'narrator', text: '한 노인이 {commander}의 손을 잡고 고개를 숙였다.' },
        { who: 'commander', text: '(브람도 이런 얼굴들을 보며 버텼겠지.)' },
      ],
      battle: {
        start: [ { who: 'commander', text: '진지를 지킨다! 피난민 쪽으로 한 놈도 보내지 마!' } ],
        wave: [ { who: 'kasha', text: '균열에서 두 번째 무리야! 이번엔 더 커!' } ],
        last: [ { who: 'sera', text: '하나 남았어! 다들 조금만 더!' } ],
      },
    },
    52: {
      pre: [
        { who: 'narrator', text: '둘째 날. 균열에서 내려온 적들 사이에 낯익은 얼굴이 있었다.' },
        { who: 'bark', text: '저건… 산적단 시절 동생 놈들이오. 눈이 시뻘게.' },
        { who: 'sera', text: '북방의 얼음 병사들도 섞여 있어. 다 마계에 끌려간 거야.' },
        { who: 'bark', text: '대장, 저놈들은… 내 손으로 쉬게 해 주겠소.' },
        { who: 'commander', text: '혼자 짊어지지 마, 바크. 같이 가.' },
      ],
      post: [
        { who: 'bark', text: '……미안하다, 녀석들아. 이제 배고프지 마라.' },
        { who: 'commander', text: '바크, 괜찮아?' },
        { who: 'bark', text: '괜찮을 리가. 그래도 대장이 옆에 있어서 다행이오.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '예전 적이라도 지금은 마계의 꼭두각시다. 버텨!' } ],
        wave: [ { who: 'kasha', text: '기사 무리가 진지 측면으로 돌아와!' } ],
        danger: [ { who: 'bark', text: '대장! 내 뒤로 와요, 지금!' } ],
      },
    },
    53: {
      pre: [
        { who: 'narrator', text: '균열 바로 아래, 마물들이 둥지를 튼 거점.' },
        { who: 'kasha', text: '저 둥지가 균열을 붙잡고 있어. 부수면 틈이 줄어.' },
        { who: 'commander', text: '이번엔 우리가 쳐들어간다. 둥지를 부숴!' },
      ],
      post: [
        { who: 'narrator', text: '둥지가 무너지자 하늘의 균열 하나가 희미해졌다.' },
        { who: 'sera', text: '닫을 수 있어. 하나씩이면 닫을 수 있어!' },
        { who: 'commander', text: '하지만 북쪽의 그 문은… 이런 크기가 아니야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '둥지까지 길을 낸다! 측면부터 무너뜨려!' } ],
        wave: [ { who: 'bark', text: '둥지에서 마물이 또 쏟아지오!' } ],
        last: [ { who: 'kasha', text: '하나 남았어. 둥지 심장부로!' } ],
      },
    },
    54: {
      pre: [
        { who: 'narrator', text: '볼카르 제국 화산 지대. 여기에도 균열이 열렸다.' },
        { who: 'narrator', text: '반란군은 이제 제국 임시 정부가 되어 있었다.' },
        { who: 'kasha', text: '제국 사람들이 도와 달래. 너한테 빚진 거 갚고 싶대.' },
        { who: 'commander', text: '같이 싸우자. 용암 지대는 우리도 겪어 봤어.' },
      ],
      post: [
        { who: 'narrator', text: '제국 병사들이 클랜의 깃발 아래 줄을 섰다.' },
        { who: 'bark', text: '제국군이랑 어깨를 나란히 하다니. 세상 오래 살고 볼 일이오.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '용암 옆에서 차례를 끝내지 마! 화상 조심!' } ],
        wave: [ { who: 'kasha', text: '균열에서 또 내려와! 제국군이 왼쪽을 맡았어!' } ],
        danger: [ { who: 'sera', text: '{commander}, 화상이 깊어! 물러나!' } ],
        last: [ { who: 'bark', text: '마지막이오! 제국 놈들한테 체면 좀 세웁시다!' } ],
      },
    },
    55: {
      pre: [
        { who: 'narrator', text: '왕도로 가는 길목. 경계가 무너져 내리고 있었다.' },
        { who: 'sera', text: '이번엔 내가 결계를 칠게. 다시 기도할 수 있어.' },
        { who: 'commander', text: '무리하지 마. 쓰러지면 결계도 끝이야.' },
        { who: 'sera', text: '알아. 그러니까 너희가 지켜 줘. 날 믿고.' },
      ],
      post: [
        { who: 'sera', text: '해냈어… 기도가 다시 닿았어.' },
        { who: 'commander', text: '네가 있어서 버텼어, 세라.' },
        { who: 'sera', text: '브람 아저씨가 그랬잖아. 혼자 하는 거 아니라고.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '세라 결계를 지킨다! 접근하는 놈부터 쳐!' } ],
        wave: [ { who: 'kasha', text: '술사들이 결계를 노려! 막아!' } ],
        danger: [ { who: 'sera', text: '{commander}, 결계 안으로 들어와!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 결계 아직 멀쩡하오!' } ],
      },
    },
    56: {
      pre: [
        { who: 'narrator', text: '왕도 외곽의 깊은 균열. 마계의 공기가 짙게 흘러나왔다.' },
        { who: 'kasha', text: '저 균열이 왕도까지 이어져. 왕도가 위험해.' },
        { who: 'commander', text: '정면 돌파한다. 균열을 따라 왕도로 간다.' },
      ],
      post: [
        { who: 'narrator', text: '균열 끝에서 왕도의 성벽이 보였다. 연기가 피어올랐다.' },
        { who: 'sera', text: '왕도가 불타고 있어…!' },
      ],
      battle: {
        start: [ { who: 'commander', text: '균열을 따라 전진! 멈추지 마!' } ],
        wave: [ { who: 'bark', text: '앞뒤로 다 막혔소! 한쪽부터 뚫읍시다!' } ],
        last: [ { who: 'commander', text: '하나 남았다. 왕도로 간다!' } ],
      },
    },
    57: {
      pre: [
        { who: 'narrator', text: '아르덴 왕도. 성벽 절반이 마계군에 넘어갔다.' },
        { who: 'narrator', text: '왕국 근위대는 이미 왕궁으로 퇴각한 뒤였다.' },
        { who: 'commander', text: '성벽을 되찾고, 백성이 빠질 길을 연다.' },
        { who: 'kasha', text: '왕궁 놈들은 백성을 버리고 숨었어. 한심하네.' },
        { who: 'commander', text: '그러니까 우리가 여기 있는 거야.' },
      ],
      post: [
        { who: 'narrator', text: '왕도 백성들이 남문으로 빠져나가기 시작했다.' },
        { who: 'sera', text: '대마도사 탑이 비어 있대. 오르딘은 어디 간 거지?' },
        { who: 'commander', text: '탑 아래를 뒤진다. 답은 거기 있을 거야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '성벽 위를 탈환한다! 고지대를 빼앗아!' } ],
        wave: [ { who: 'kasha', text: '성문 쪽으로 기사단이 밀려와!' } ],
        danger: [ { who: 'bark', text: '대장 다쳤소! 성벽 계단으로 빼요!' } ],
        last: [ { who: 'sera', text: '마지막이야! 남문이 열렸어!' } ],
      },
    },
    58: {
      pre: [
        { who: 'narrator', text: '대마도사 탑 지하. 계단은 균열 속으로 이어져 있었다.' },
        { who: 'kasha', text: '자기 탑 아래에 균열을 키우고 있었던 거야.' },
        { who: 'commander', text: '지키는 놈들이 있어. 뚫고 연구실까지 간다.' },
      ],
      post: [
        { who: 'commander', text: '오르딘의 일지야. "문을 열어 신을 부른다."' },
        { who: 'commander', text: '"신만이 마계를 정화한다. 문을 열 열쇠는 그 아이."' },
        { who: 'sera', text: '신을 부르려고 세상을 이렇게 만든 거야?' },
        { who: 'kasha', text: '신앙심이 아니라 광기네.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '연구실 앞 수호자들을 치운다! 진입!' } ],
        wave: [ { who: 'bark', text: '벽 속에서 소환수가 튀어나오오!' } ],
        last: [ { who: 'kasha', text: '하나 남았어. 연구실 문 앞이야.' } ],
      },
    },
    59: {
      pre: [
        { who: 'narrator', text: '왕도 북쪽 잿빛 평원. 지옥문이 하늘까지 솟아 있었다.' },
        { who: 'narrator', text: '문 앞에 연합군의 마지막 진지가 세워졌다.' },
        { who: 'commander', text: '문을 지키는 수호자를 치기 전에 진지부터 지킨다.' },
        { who: 'bark', text: '문에서 쏟아지는 놈들, 수가 장난 아니오.' },
        { who: 'commander', text: '경계 태세로 맞이한다. 먼저 쏘고, 먼저 친다.' },
      ],
      post: [
        { who: 'narrator', text: '진지는 버텼다. 문 앞에 거대한 그림자가 섰다.' },
        { who: 'sera', text: '저게 문지기야. 저것만 넘으면 문을 닫을 수 있어.' },
        { who: 'commander', text: '(정말 그럴까. 흉터가 이상하게 들떠 있어.)' },
      ],
      battle: {
        start: [ { who: 'commander', text: '진지를 지켜라! 여기가 마지막 방어선이다!' } ],
        wave: [ { who: 'kasha', text: '문에서 증원이야! 끝이 안 보여!' } ],
        danger: [ { who: 'sera', text: '{commander}! 쓰러지면 진지가 무너져!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 진지는 우리 거요!' } ],
      },
    },
    60: {
      pre: [
        { who: 'narrator', text: '지옥문 바로 앞. 거대한 기사가 문을 등지고 섰다.' },
        { who: 'boss', text: '이 문은 열쇠의 피로만 넘을 수 있다.' },
        { who: 'commander', text: '넘을 생각 없어. 닫으러 왔다.' },
        { who: 'boss', text: '닫든 열든, 나를 꺾는 순간 결정되리라.' },
        { who: 'kasha', text: '뭔가 걸려. 저 말, 함정 냄새가 나.' },
      ],
      post: [
        { who: 'boss', text: '좋다… 열쇠의 피가… 문에 닿았다….' },
        { who: 'narrator', text: '수호자가 쓰러지며, {commander}의 상처에서 피가 문에 튀었다.' },
        { who: 'commander', text: '흉터가 타는 것 같아… 문이, 움직인다?!' },
      ],
      battle: {
        start: [ { who: 'commander', text: '수호자를 둘러싼 호위부터 걷어 낸다!' } ],
        boss: [ { who: 'boss', text: '나는 문이다. 문을 넘으려면 나를 넘어라.' } ],
        wave: [ { who: 'kasha', text: '문 안쪽에서 증원이야! 앞뒤로 막혀!' } ],
        danger: [ { who: 'sera', text: '{commander}! 피가 너무 많이 나!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 이걸로 끝이오!' } ],
      },
    },
    // ═══ Episode 7: 악마의 영역 ═══
    61: {
      pre: [
        { who: 'narrator', text: '문을 넘은 첫 땅. 클랜은 검은 바위 위에 교두보를 세웠다.' },
        { who: 'kasha', text: '돌아갈 문은 등 뒤에 있어. 여길 잃으면 끝이야.' },
        { who: 'commander', text: '교두보를 지킨다. 마계 놈들한테 길을 내주지 마.' },
        { who: 'sera', text: '여기 공기… 숨 쉴 때마다 머리가 울려.' },
      ],
      post: [
        { who: 'bark', text: '버텼소. 근데 해가 안 지네. 여긴 밤이 없나.' },
        { who: 'commander', text: '시간도 길도 믿지 마. 서로만 믿자.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '교두보 사수! 문으로 가는 길을 지켜!' } ],
        wave: [ { who: 'kasha', text: '바위 틈에서 마계 기사단이야! 수가 많아!' } ],
        danger: [ { who: 'sera', text: '{commander}, 정신 차려! 내 목소리 들려?' } ],
        last: [ { who: 'bark', text: '하나 남았소! 마계 첫 승리 갑시다!' } ],
      },
    },
    62: {
      pre: [
        { who: 'narrator', text: '붉은 풀이 끝없이 일렁이는 들판이 펼쳐졌다.' },
        { who: 'sera', text: '{commander}… 저기, 솔빛 마을이야. 저 언덕, 저 방앗간.' },
        { who: 'commander', text: '아니야. 마을은 저렇게 붉지 않아. 환영이야.' },
        { who: 'kasha', text: '환영 속에 진짜 적이 섞여 있어. 정신 똑바로.' },
        { who: 'commander', text: '고향 모습이라도 망설이지 마. 전진!' },
      ],
      post: [
        { who: 'narrator', text: '환영이 걷히자 마을은 사라지고 잿더미만 남았다.' },
        { who: 'commander', text: '마계는 우리가 아끼는 걸 무기로 쓴다.' },
        { who: 'bark', text: '치사한 놈들. 그럼 더 세게 패 줘야지.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '보이는 걸 믿지 마! 적만 보고 쳐라!' } ],
        wave: [ { who: 'kasha', text: '언덕 뒤에서 더 나와! 환영이 아니야, 진짜야!' } ],
        last: [ { who: 'sera', text: '마지막이야. 이제 진짜 길로 가자.' } ],
      },
    },
    63: {
      pre: [
        { who: 'narrator', text: '하얀 뼈로 된 나무들이 숲을 이루고 있었다.' },
        { who: 'bark', text: '나뭇가지가 손가락처럼 움직이오. 소름 끼치네.' },
        { who: 'kasha', text: '그래도 숲은 숲이야. 그늘에 숨을 수 있어.' },
        { who: 'commander', text: '숲을 끼고 싸운다. 적이 몰려오면 측면을 친다.' },
      ],
      post: [
        { who: 'narrator', text: '숲 끝에서 낡은 이정표가 발견되었다. 인간의 글씨였다.' },
        { who: 'commander', text: '"봉인자의 길." …부모님도 여길 지나갔던 거야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '뼈나무를 엄폐물로 써! 노출되지 마!' } ],
        wave: [ { who: 'kasha', text: '숲 반대편에서 포위해 와! 등 뒤 조심!' } ],
        danger: [ { who: 'bark', text: '대장! 내가 가지를 막을 테니 빠지쇼!' } ],
      },
    },
    64: {
      pre: [
        { who: 'narrator', text: '붉은 물이 고인 늪. 물속에서 무언가가 숨 쉬었다.' },
        { who: 'sera', text: '흑수 습지랑 비슷해. 근데 몇 배는 더 나빠.' },
        { who: 'commander', text: '늪 한가운데 섬에 진을 친다. 여울로 나가지 마.' },
        { who: 'kasha', text: '여기서 버티면, 놈들이 늪을 건너다 지칠 거야.' },
      ],
      post: [
        { who: 'sera', text: '습지 때 생각나. 그땐 브람 아저씨가 있었는데.' },
        { who: 'commander', text: '지금도 있어. 우리가 하는 말 속에.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '섬을 지킨다! 여울에 선 놈들을 노려!' } ],
        wave: [ { who: 'bark', text: '늪 바닥에서 또 기어 올라오오!' } ],
        danger: [ { who: 'sera', text: '{commander}, 물가에서 떨어져!' } ],
        last: [ { who: 'kasha', text: '하나 남았어. 늪을 건넌다!' } ],
      },
    },
    65: {
      pre: [
        { who: 'narrator', text: '바람이 지날 때마다 비명 소리를 내는 협곡.' },
        { who: 'bark', text: '귀가 찢어질 것 같소. 이게 다 바람 소리라고?' },
        { who: 'kasha', text: '협곡 위 바위를 잡은 쪽이 이겨. 고지대 싸움이야.' },
        { who: 'commander', text: '원거리는 언덕 위로. 사거리가 더 길어진다.' },
      ],
      post: [
        { who: 'narrator', text: '협곡 끝, 검은 성채가 하늘을 찌르고 있었다.' },
        { who: 'commander', text: '저 성채 너머에 법사의 탑이 있다고 했지.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '고지대를 먼저 잡아! 위에서 내려친다!' } ],
        wave: [ { who: 'kasha', text: '반대편 고지에 술사들이 자리 잡았어!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 협곡 통과요!' } ],
      },
    },
    66: {
      pre: [
        { who: 'narrator', text: '마계의 검은 성채. 성벽이 살아 있는 것처럼 꿈틀댔다.' },
        { who: 'kasha', text: '검은 깃 본대가 문 너머에서 따라왔어. 이제 전원 합류야.' },
        { who: 'commander', text: '든든하네. 성채를 지키면서 안쪽을 뚫는다.' },
        { who: 'kasha', text: '…예전에 너랑 경주하던 게 바보 같네.' },
      ],
      post: [
        { who: 'kasha', text: '{commander}. 이제 경쟁 상대 아니야. 전우야.' },
        { who: 'commander', text: '알아. 그래도 가끔 경주는 하자.' },
        { who: 'kasha', text: '흥. 다음엔 내가 이겨.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '성채 입구를 잡고, 안쪽으로 밀어 넣는다!' } ],
        wave: [ { who: 'kasha', text: '검은 깃, 왼쪽 성벽! 지금이야!' } ],
        danger: [ { who: 'kasha', text: '{commander}, 내 뒤로! 엄호할게!' } ],
        last: [ { who: 'bark', text: '마지막 놈이오! 성채 함락!' } ],
      },
    },
    67: {
      pre: [
        { who: 'narrator', text: '마계 한복판, 인간의 손으로 쌓은 유적이 있었다.' },
        { who: 'sera', text: '여기도 갈라진 별 문양이야. 봉인자들의 유적.' },
        { who: 'commander', text: '흉터가 울려. 여기서 뭔가 기다리고 있어.' },
        { who: 'kasha', text: '마계 놈들이 유적을 부수려 해. 지켜야 해!' },
      ],
      post: [
        { who: 'narrator', text: '유적 중심의 돌이 빛나며 두 사람의 목소리가 울렸다.' },
        { who: 'narrator', text: '"우리 아이야. 열쇠는 혼자 돌리는 것이 아니란다."' },
        { who: 'narrator', text: '"네 곁의 손들과 함께 돌리렴. 그럼 닫힐 거야."' },
        { who: 'commander', text: '……엄마? 아빠? 기다려요, 아직 할 말이…!' },
      ],
      battle: {
        start: [ { who: 'commander', text: '유적을 지킨다! 저 돌에 손대게 하지 마!' } ],
        wave: [ { who: 'bark', text: '유적 사방에서 몰려오오! 원형으로 서요!' } ],
        danger: [ { who: 'sera', text: '{commander}! 유적은 우리가 지킬게, 물러나!' } ],
        last: [ { who: 'sera', text: '하나 남았어! 저 돌이 빛나기 시작해!' } ],
      },
    },
    68: {
      pre: [
        { who: 'sera', text: '{commander}, 아까 그 목소리… 괜찮아?' },
        { who: 'commander', text: '응. 오히려 처음으로 길이 보이는 것 같아.' },
        { who: 'commander', text: '혼자가 아니라 함께. 그게 열쇠래.' },
        { who: 'narrator', text: '클랜은 법사의 탑으로 이어지는 심연 회랑에 들어섰다.' },
      ],
      post: [
        { who: 'bark', text: '회랑 끝에 탑이 보이오. 저 꼭대기에 법사가 있겠지.' },
        { who: 'kasha', text: '오르딘도 거기 들렀대. 냄새가 짙어.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '회랑을 돌파한다! 함께 움직여!' } ],
        wave: [ { who: 'kasha', text: '회랑 양쪽 벽이 열렸어! 매복이야!' } ],
        last: [ { who: 'commander', text: '하나 남았다. 탑으로 간다!' } ],
      },
    },
    69: {
      pre: [
        { who: 'narrator', text: '법사의 탑 아래 요새. 탑을 지키는 마지막 성벽.' },
        { who: 'kasha', text: '성벽 위에서 마법이 비처럼 쏟아져.' },
        { who: 'commander', text: '적이 노리는 클랜원이 표시돼. 그 자리를 비워 줘.' },
        { who: 'bark', text: '노리는 놈이 보이면 피하면 되지. 간단하네!' },
      ],
      post: [
        { who: 'narrator', text: '성벽이 무너지고, 탑의 문이 저절로 열렸다.' },
        { who: 'sera', text: '초대하는 거야. 기분 나빠.' },
        { who: 'commander', text: '초대받았으면 가 줘야지. 정중하게, 칼을 들고.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '적 표적 표시를 봐! 노린 자리는 비운다!' } ],
        wave: [ { who: 'kasha', text: '탑에서 정예가 내려와! 마법사 호위대야!' } ],
        danger: [ { who: 'sera', text: '{commander}, 마법 집중포화야! 피해!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 탑 문 열립니다!' } ],
      },
    },
    70: {
      pre: [
        { who: 'narrator', text: '탑의 꼭대기. 안개 속에서 낯익은 실루엣이 걸어 나왔다.' },
        { who: 'commander', text: '……브람?' },
        { who: 'boss', text: '그래, 꼬맹이. 왜 날 두고 갔지?' },
        { who: 'sera', text: '속지 마! 아저씨는 그런 말 안 해!' },
        { who: 'commander', text: '알아. 브람은 끝까지 날 지휘관이라 불렀어.' },
        { who: 'boss', text: '흥, 재미없군. 그럼 진짜 모습으로 상대해 주지.' },
      ],
      post: [
        { who: 'boss', text: '마음을 흔들어도… 무너지지 않는 인간이라니….' },
        { who: 'boss', text: '오르딘은… 하늘 꼭대기로 갔다… 신을 부르러….' },
        { who: 'boss', text: '그리고 군주께서는… 이미 너를 보고 계신다….' },
        { who: 'commander', text: '보라고 해. 곧 직접 만나러 갈 테니까.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '환영에 흔들리지 마! 법사를 노린다!' } ],
        boss: [ { who: 'boss', text: '네 기억으로 너를 찢어 주마, 열쇠.' } ],
        wave: [ { who: 'kasha', text: '탑 아래층에서 증원이야! 계단을 막아!' } ],
        danger: [ { who: 'sera', text: '{commander}! 환영 말고 내 목소리 들어!' } ],
        last: [ { who: 'bark', text: '마지막 하나요! 이 탑 무너뜨립시다!' } ],
      },
    },
    // ═══ Episode 8: 신의 심판 ═══
    71: {
      pre: [
        { who: 'narrator', text: '하얀 빛이 내리꽂힌 들판. 붉은 풀이 하얗게 타들어 갔다.' },
        { who: 'narrator', text: '빛 속에서 갑옷 입은 형체들이 걸어 나왔다. 날개가 있었다.' },
        { who: 'sera', text: '신의 화신… 경전에서 본 모습이야.' },
        { who: 'kasha', text: '그런데 왜 우리 진영으로 걸어오지?' },
        { who: 'commander', text: '칼을 뽑고 있어. 진지를 지켜! 저것도 적이야!' },
      ],
      post: [
        { who: 'sera', text: '신의 화신이 우리를 쳤어. 왜…?' },
        { who: 'commander', text: '마계에 닿은 건 다 더럽다고 보는 거겠지. 우리도.' },
        { who: 'sera', text: '그럼 내가 평생 기도한 건 뭐였어.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '진지 사수! 빛이든 어둠이든 막는다!' } ],
        wave: [ { who: 'kasha', text: '하늘에서 또 내려와! 이번엔 기사단이야!' } ],
        danger: [ { who: 'bark', text: '대장! 저 빛, 닿기만 해도 타오!' } ],
        last: [ { who: 'sera', text: '……하나 남았어. 끝내자.' } ],
      },
    },
    72: {
      pre: [
        { who: 'narrator', text: '빛과 어둠이 부딪히는 심연의 틈.' },
        { who: 'kasha', text: '악마랑 화신이 서로 싸우고 있어. 우린 어쩌지?' },
        { who: 'commander', text: '둘 다 우리 편이 아니야. 사이를 뚫고 간다.' },
        { who: 'bark', text: '양쪽에서 얻어맞는 거 아니오, 이거?' },
      ],
      post: [
        { who: 'narrator', text: '틈 너머 하늘 꼭대기에 하얀 균열이 보였다.' },
        { who: 'commander', text: '저기가 오르딘이 신을 부르는 곳이야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '양쪽 다 적이다! 틈 사이로 돌파해!' } ],
        wave: [ { who: 'kasha', text: '악마 쪽 증원이 우리 쪽으로 방향을 틀었어!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 이 난장판 빠져나갑시다!' } ],
      },
    },
    73: {
      pre: [
        { who: 'narrator', text: '하얀 돌로 지은 성채. 마계 한가운데 서 있기엔 너무 깨끗했다.' },
        { who: 'kasha', text: '이거 오르딘이 지은 거래. 신을 맞이할 성전이라나.' },
        { who: 'commander', text: '성채를 장악하고 위로 가는 길을 찾는다.' },
        { who: 'sera', text: '이 성채, 기도하는 사람들 해골로 쌓았어…' },
      ],
      post: [
        { who: 'commander', text: '오르딘이 데려온 사람들이야. 신을 부르는 제물로.' },
        { who: 'sera', text: '신을 위해서라면 사람을 이렇게 해도 된다고?' },
        { who: 'commander', text: '아니. 어떤 이유로도 안 돼.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '성채 문을 지키며 안으로 파고든다!' } ],
        wave: [ { who: 'kasha', text: '성채 위층에서 빛의 술사들이 내려와!' } ],
        danger: [ { who: 'sera', text: '{commander}, 빛에 너무 오래 맞았어!' } ],
        last: [ { who: 'bark', text: '마지막 놈이오! 성채는 우리 거요!' } ],
      },
    },
    74: {
      pre: [
        { who: 'narrator', text: '고대 신전의 폐허. 세라가 홀로 무릎을 꿇었다.' },
        { who: 'narrator', text: '"사제여. 열쇠 곁을 떠나라. 열쇠는 더럽혀졌다."' },
        { who: 'sera', text: '……신의 목소리야. 나한테 떠나라고 해.' },
        { who: 'commander', text: '세라. 네가 고르면 돼. 난 원망 안 해.' },
        { who: 'sera', text: '바보. 내가 누굴 고를지 몰라서 그런 말 해?' },
        { who: 'sera', text: '신이 버린 사람도 내가 고칠 거야. 그게 내 기도야.' },
      ],
      post: [
        { who: 'sera', text: '신의 목소리가 멈췄어. 대신 마음이 조용해.' },
        { who: 'commander', text: '고마워, 세라. 정말로.' },
        { who: 'sera', text: '처음에 말했잖아. 다치면 내가 고쳐 준다고.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '폐허를 지킨다! 세라 곁으로 보내지 마!' } ],
        wave: [ { who: 'kasha', text: '화신들이 세라를 데려가려 해! 막아!' } ],
        danger: [ { who: 'sera', text: '{commander}! 내가 치료할게, 버텨!' } ],
        last: [ { who: 'sera', text: '마지막이야. 이건 내 손으로 끝낼게.' } ],
      },
    },
    75: {
      pre: [
        { who: 'narrator', text: '하늘로 이어진 심연의 기둥. 빛의 사다리가 걸려 있었다.' },
        { who: 'bark', text: '저 사다리 타고 올라가면 꼭대기요?' },
        { who: 'kasha', text: '지키는 놈들이 사다리 아래 진을 쳤어.' },
        { who: 'commander', text: '사다리 아래를 장악한다. 포위하면 협공이 된다.' },
      ],
      post: [
        { who: 'narrator', text: '사다리가 클랜의 무게를 받아 들이며 빛을 냈다.' },
        { who: 'bark', text: '이 몸 무게도 견디네. 신 물건은 튼튼하구먼.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '양쪽에서 끼고 친다! 협공으로 빨리 끝내!' } ],
        wave: [ { who: 'kasha', text: '위에서 내려와! 사다리 쪽을 막아!' } ],
        last: [ { who: 'commander', text: '하나 남았다. 올라간다!' } ],
      },
    },
    76: {
      pre: [
        { who: 'narrator', text: '하늘과 심연의 중간. 빛과 어둠이 뒤엉킨 전장.' },
        { who: 'kasha', text: '악마군과 화신군, 그리고 우리. 삼파전이야.' },
        { who: 'commander', text: '서로 싸우게 두고, 우리는 길만 낸다.' },
        { who: 'bark', text: '둘이 지칠 때까지 기다리는 거요? 대장 많이 영악해졌소.' },
      ],
      post: [
        { who: 'commander', text: '브람이라면 이렇게 했을 거야. 힘을 아껴야 해.' },
        { who: 'sera', text: '네 판단이야, {commander}. 브람 아저씨 아니고.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '양쪽 다 상대하지 마! 길을 열고 버텨!' } ],
        wave: [ { who: 'kasha', text: '양쪽이 동시에 우릴 노려! 진형 좁혀!' } ],
        danger: [ { who: 'bark', text: '대장! 방어 태세 잡고 한 번 버티쇼!' } ],
        last: [ { who: 'kasha', text: '하나 남았어! 빈틈이야, 가!' } ],
      },
    },
    77: {
      pre: [
        { who: 'narrator', text: '하늘 가까운 요새. 마계군이 클랜을 쫓아 올라왔다.' },
        { who: 'kasha', text: '꼭대기 가기 전에 뒤를 끊어야 해. 여기서 막자.' },
        { who: 'commander', text: '요새 문을 닫고 버틴다. 경계를 세워라.' },
        { who: 'commander', text: '사거리에 들어오는 놈은 먼저 친다.' },
      ],
      post: [
        { who: 'narrator', text: '추격군이 무너졌다. 위쪽에서 오르딘의 목소리가 울렸다.' },
        { who: 'commander', text: '오르딘이 말을 걸어오고 있어.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '요새 문을 지켜! 추격을 여기서 끊는다!' } ],
        wave: [ { who: 'bark', text: '아래에서 계속 기어 올라오오!' } ],
        danger: [ { who: 'sera', text: '{commander}, 문 안쪽으로 물러나!' } ],
        last: [ { who: 'kasha', text: '하나 남았어. 추격 끝!' } ],
      },
    },
    78: {
      pre: [
        { who: 'ordin', text: '젊은 지휘관. 거래를 하지.' },
        { who: 'ordin', text: '열쇠를 내게 다오. 신이 마계를 지우면 전쟁은 끝나오.' },
        { who: 'commander', text: '마계에 닿은 땅도 지운다며. 우리 고향도.' },
        { who: 'ordin', text: '희생 없는 구원은 없소. 그대 부모가 증명했지.' },
        { who: 'commander', text: '부모님은 스스로 골랐어. 당신은 남을 골랐고.' },
        { who: 'commander', text: '누구를 버릴지 신이 정하게 두지 않겠어.' },
      ],
      post: [
        { who: 'ordin', text: '어리석군. 그렇다면 신의 앞에서 증명해 보시오.' },
        { who: 'narrator', text: '오르딘의 환영이 흩어지고, 하늘 꼭대기의 빛이 짙어졌다.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '대답은 칼로 한다! 길을 막는 건 전부 쳐!' } ],
        wave: [ { who: 'kasha', text: '오르딘이 화신들을 더 불러냈어!' } ],
        last: [ { who: 'commander', text: '하나 남았다. 꼭대기로 간다!' } ],
      },
    },
    79: {
      pre: [
        { who: 'narrator', text: '하늘 꼭대기로 오르는 마지막 계단. 고대의 기둥이 늘어섰다.' },
        { who: 'sera', text: '봉인자들의 유적이야. 여기서도 문을 닫으려 했던 거야.' },
        { who: 'commander', text: '기둥 사이에 진을 친 놈들을 뚫는다.' },
        { who: 'bark', text: '이번만 넘으면 그 영감 낯짝 보는 거요?' },
      ],
      post: [
        { who: 'narrator', text: '계단 끝, 하얀 균열 앞에 오르딘이 서 있었다.' },
        { who: 'narrator', text: '오르딘의 몸은 이미 절반쯤 빛으로 변해 있었다.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '계단을 오른다! 기둥 뒤를 조심해!' } ],
        wave: [ { who: 'kasha', text: '위쪽 기둥에서 궁수들이 쏴! 고지대야!' } ],
        danger: [ { who: 'sera', text: '{commander}! 계단 아래로 밀리지 마!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 꼭대기요!' } ],
      },
    },
    80: {
      pre: [
        { who: 'narrator', text: '하얀 균열 앞. 오르딘은 이제 스스로를 신의 소환사라 불렀다.' },
        { who: 'boss', text: '보시오, 신이 오고 있소. 15년을 기다린 순간이오.' },
        { who: 'commander', text: '그 15년 동안 몇 명을 제물로 바쳤어!' },
        { who: 'boss', text: '세상을 구하는 데 드는 값이었소.' },
        { who: 'commander', text: '그 값은 당신이 정할 수 있는 게 아니야.' },
        { who: 'sera', text: '{commander}, 소환을 끊어야 해. 지금!' },
      ],
      post: [
        { who: 'boss', text: '신이… 오지 않는다… 아니, 올 수 없었던 건가….' },
        { who: 'narrator', text: '빛이 오르딘의 몸에서 빠져나가고, 늙은 마도사만 남았다.' },
        { who: 'bark', text: '대장, 끝장낼까요?' },
        { who: 'commander', text: '아니. 살아서 봐야 해. 자기가 무엇을 했는지.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '소환진을 지키는 화신부터 걷어 낸다!' } ],
        boss: [ { who: 'boss', text: '신의 이름으로, 더럽혀진 것들을 심판하노라!' } ],
        wave: [ { who: 'kasha', text: '균열에서 화신이 더 내려와! 서둘러!' } ],
        danger: [ { who: 'sera', text: '{commander}! 심판의 빛이야, 피해!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 이 소환 끝내 버립시다!' } ],
      },
    },
    // ═══ Episode 9: 절대절명 ═══
    81: {
      pre: [
        { who: 'narrator', text: '왕도 앞 잿빛 평원. 연합군의 깃발이 처음으로 한데 섰다.' },
        { who: 'kasha', text: '왕국 잔존군, 제국군, 검은 깃. 전부 네 명령을 기다려.' },
        { who: 'commander', text: '첫 명령이다. 아무도 혼자 싸우지 않는다.' },
        { who: 'commander', text: '균열에서 나오는 놈들을 여기서 막는다!' },
      ],
      post: [
        { who: 'narrator', text: '연합군의 첫 방어전은 승리로 끝났다.' },
        { who: 'bark', text: '나라가 다른 병사들이 서로 어깨를 두드리네.' },
        { who: 'sera', text: '브람 아저씨가 봤으면 좋아하셨을 거야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '연합군, 방어선 유지! 균열을 막아라!' } ],
        wave: [ { who: 'kasha', text: '균열에서 대군이야! 제국군이 오른쪽을 받쳐!' } ],
        danger: [ { who: 'sera', text: '{commander}! 총지휘관이 쓰러지면 안 돼!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 연합군 첫 승리요!' } ],
      },
    },
    82: {
      pre: [
        { who: 'narrator', text: '평원 북쪽, 마계군이 균열 앞에 세운 전진 진지.' },
        { who: 'kasha', text: '저 진지를 놔두면 놈들이 끝없이 쏟아질 거야.' },
        { who: 'commander', text: '쳐들어간다. 방어만 해선 이 전쟁 못 이겨.' },
      ],
      post: [
        { who: 'narrator', text: '마계 진지가 불타고, 균열 하나가 숨을 죽였다.' },
        { who: 'commander', text: '다음은 북방이야. 서리문이 포위당했대.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '진지를 친다! 측면부터 무너뜨려!' } ],
        wave: [ { who: 'kasha', text: '진지 뒤에서 마계 기사단이 몰려와!' } ],
        last: [ { who: 'commander', text: '하나 남았다. 진지에 불을 질러!' } ],
      },
    },
    83: {
      pre: [
        { who: 'narrator', text: '북방 서리문 요새. 클랜이 처음 카샤를 만난 곳.' },
        { who: 'kasha', text: '그때 여기서 너한테 졌지. 기억나?' },
        { who: 'commander', text: '기억나. 그땐 서로 적이었는데.' },
        { who: 'narrator', text: '요새 안 북방 생존자들이 클랜의 깃발을 보고 환호했다.' },
        { who: 'commander', text: '요새를 지키면서 포위망을 뚫는다!' },
      ],
      post: [
        { who: 'narrator', text: '북방 생존자들이 연합군에 합류했다.' },
        { who: 'kasha', text: '하얀샘 사람들이야. 네가 지켜 준 마을.' },
        { who: 'commander', text: '이번엔 저 사람들이 우리를 지켜 주러 왔네.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '성벽을 지키며 포위를 깬다! 둘 다 해낸다!' } ],
        wave: [ { who: 'bark', text: '눈보라 속에서 마계군이 또 오오!' } ],
        danger: [ { who: 'kasha', text: '{commander}, 성벽 안쪽으로! 엄호할게!' } ],
        last: [ { who: 'sera', text: '하나 남았어. 서리문은 무사해!' } ],
      },
    },
    84: {
      pre: [
        { who: 'narrator', text: '남부 흑수 습지, 갈대목 마을. 마계군이 늪을 건너왔다.' },
        { who: 'sera', text: '그때 치료했던 사람들이야! 다들 무기를 들었어.' },
        { who: 'commander', text: '마을을 지킨다. 이번엔 마을 사람들도 함께야.' },
        { who: 'bark', text: '늪 싸움이면 여울 조심. 이제 눈 감고도 알지.' },
      ],
      post: [
        { who: 'narrator', text: '갈대목 사람들이 세라를 둘러싸고 고개를 숙였다.' },
        { who: 'sera', text: '그때 살린 사람들이 오늘 우릴 살렸어.' },
        { who: 'commander', text: '그게 우리가 싸우는 이유야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '마을 방벽을 지켜! 늪에서 끌어내지 마!' } ],
        wave: [ { who: 'kasha', text: '늪 건너편에서 두 번째 무리야!' } ],
        danger: [ { who: 'sera', text: '{commander}, 내가 갈게! 조금만!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 갈대목 만세!' } ],
      },
    },
    85: {
      pre: [
        { who: 'narrator', text: '대륙 한가운데 열린 거대 균열. 마계군의 본류였다.' },
        { who: 'kasha', text: '저걸 꺾으면 마계군 보급이 반토막 나.' },
        { who: 'commander', text: '연합군 전원 돌격. 오늘 저 균열을 꺾는다.' },
      ],
      post: [
        { who: 'narrator', text: '거대 균열이 반쯤 닫히며 마계의 비명이 울렸다.' },
        { who: 'ordin', text: '…대단하군. 내가 15년 동안 못 한 일을.' },
        { who: 'commander', text: '혼자 하려니까 못 한 거야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '전원 돌격! 균열 앞 마계군을 쓸어 낸다!' } ],
        wave: [ { who: 'kasha', text: '균열에서 정예 기사단이야! 대열 정비!' } ],
        last: [ { who: 'commander', text: '하나 남았다. 균열을 꺾는다!' } ],
      },
    },
    86: {
      pre: [
        { who: 'narrator', text: '제국 흑요문 성채. 제국 임시 정부의 마지막 거점.' },
        { who: 'kasha', text: '검은 깃이 계약을 파기했던 곳이야. 묘한 기분이네.' },
        { who: 'commander', text: '성채를 지키면서 바깥 포위를 쳐낸다.' },
        { who: 'bark', text: '성벽 위 창병은 제국군이, 아래는 우리가 맡읍시다.' },
      ],
      post: [
        { who: 'narrator', text: '흑요문이 지켜지자 제국 전역의 저항군이 힘을 얻었다.' },
        { who: 'kasha', text: '그때 계약 깬 거, 잘한 선택이었어.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '성문 안팎을 동시에 지킨다! 흩어지지 마!' } ],
        wave: [ { who: 'bark', text: '화산 쪽에서 증원이오! 용암 조심!' } ],
        danger: [ { who: 'kasha', text: '{commander}, 무리하지 마. 내가 받칠게!' } ],
        last: [ { who: 'sera', text: '하나 남았어! 흑요문은 무사해!' } ],
      },
    },
    87: {
      pre: [
        { who: 'narrator', text: '고대 봉인자 유적. 마계군이 이곳을 부수려 몰려왔다.' },
        { who: 'ordin', text: '이 유적이 무너지면 열쇠의 힘도 약해지오.' },
        { who: 'commander', text: '그럼 지킨다. 무슨 일이 있어도.' },
        { who: 'bark', text: '대장, 이번엔 내가 제일 앞에 서겠소.' },
      ],
      post: [
        { who: 'narrator', text: '유적은 지켜졌다. 그러나 바크가 쓰러져 있었다.' },
        { who: 'sera', text: '바크! 눈 떠! 지금 치료하고 있어!' },
        { who: 'bark', text: '……대장, 나 안 죽소. 아직 밭 갈 일이 남았거든.' },
        { who: 'commander', text: '약속해. 꼭 같이 돌아가는 거야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '유적을 지켜라! 돌기둥을 등지고 싸워!' } ],
        wave: [ { who: 'kasha', text: '유적 뒤쪽이 뚫렸어! 누가 막아!' } ],
        danger: [ { who: 'bark', text: '대장! 뒤로! 여긴 내가 막소!' } ],
        last: [ { who: 'bark', text: '하나… 남았소… 대장, 끝내쇼!' } ],
      },
    },
    88: {
      pre: [
        { who: 'narrator', text: '바크는 진영에서 치료를 받고, 클랜은 다시 출전했다.' },
        { who: 'commander', text: '바크 몫까지 싸운다. 그리고 다 같이 돌아간다.' },
        { who: 'kasha', text: '저 균열 너머에 전쟁의 전사 진영이 있어.' },
        { who: 'commander', text: '길을 연다. 놈의 앞까지.' },
      ],
      post: [
        { who: 'narrator', text: '균열 너머, 마계 대장군의 붉은 깃발이 보였다.' },
        { who: 'kasha', text: '놈은 솔빛 마을 쪽으로 진군하고 있어.' },
        { who: 'commander', text: '……고향으로 간다. 거기서 끝낸다.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '균열 돌파! 바크 몫까지 친다!' } ],
        wave: [ { who: 'kasha', text: '대장군 친위대가 막아서! 강해!' } ],
        last: [ { who: 'commander', text: '하나 남았다. 고향으로 간다!' } ],
      },
    },
    89: {
      pre: [
        { who: 'narrator', text: '솔빛 마을. 목책 대신 돌로 쌓은 성벽이 서 있었다.' },
        { who: 'sera', text: '마을 사람들이 직접 쌓았대. 우리가 돌아올 곳이라고.' },
        { who: 'bark', text: '…크흑, 누가 눈에 모래 뿌렸소.' },
        { who: 'commander', text: '처음 지휘했던 그 자리야. 여기서 버틴다.' },
        { who: 'commander', text: '이번에도, 한 사람도 잃지 않겠다.' },
      ],
      post: [
        { who: 'narrator', text: '솔빛 성벽은 무너지지 않았다.' },
        { who: 'commander', text: '브람, 보셨어요? 꼬맹이가 여기까지 왔어요.' },
        { who: 'sera', text: '저기, 평원 끝에 붉은 갑옷이 보여. 대장군이야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '고향 성벽이다! 한 발도 물러서지 마!' } ],
        wave: [ { who: 'kasha', text: '대군이야! 성벽 동쪽으로 몰려와!' } ],
        danger: [ { who: 'sera', text: '{commander}! 여기서 쓰러지면 안 돼!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 우리 마을이오!' } ],
      },
    },
    90: {
      pre: [
        { who: 'narrator', text: '솔빛 마을 앞 평원. 붉은 갑옷의 거인이 걸어 나왔다.' },
        { who: 'boss', text: '이 작은 마을이 이 전쟁의 심장이라니.' },
        { who: 'commander', text: '작아도 상관없어. 여긴 우리 집이야.' },
        { who: 'boss', text: '그 집째로 짓밟아 주마. 전쟁은 그런 것이다.' },
        { who: 'kasha', text: '연합군 전원 준비됐어. 네 신호만 기다려.' },
      ],
      post: [
        { who: 'boss', text: '이 전쟁… 졌다… 하지만 군주께선… 지지 않는다….' },
        { who: 'narrator', text: '대장군이 쓰러지자 마계군이 균열 속으로 무너져 물러났다.' },
        { who: 'commander', text: '이제 남은 건 하나. 마계 군주.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '연합군, 총공격! 대장군의 호위부터!' } ],
        boss: [ { who: 'boss', text: '전쟁의 이름으로! 모두 쓸어버려라!' } ],
        wave: [ { who: 'kasha', text: '마계 정예 증원이야! 이게 마지막 물결일 거야!' } ],
        danger: [ { who: 'sera', text: '{commander}! 대장군 공격은 받으면 안 돼!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 이 전쟁 끝냅시다!' } ],
      },
    },
    // ═══ Episode 10: 불가능의 영역 ═══
    91: {
      pre: [
        { who: 'narrator', text: '마계의 가장 깊은 층. 발밑에서 거대한 심장 소리가 울렸다.' },
        { who: 'ordin', text: '옥좌까지 가려면 여기 교두보가 필요하오.' },
        { who: 'commander', text: '여길 지킨다. 돌아갈 길이자 나아갈 길이야.' },
        { who: 'bark', text: '붕대 감은 채로 왔소. 빠지면 평생 후회할 것 같아서.' },
      ],
      post: [
        { who: 'narrator', text: '교두보가 세워지자, 어둠 너머에 다섯 개의 불빛이 켜졌다.' },
        { who: 'ordin', text: '군주의 다섯 신하요. 하나씩 그대를 기다리고 있소.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '교두보 사수! 마지막 여정의 첫걸음이다!' } ],
        wave: [ { who: 'kasha', text: '어둠 속에서 끝없이 나와! 진형 유지!' } ],
        danger: [ { who: 'sera', text: '{commander}! 여기서 쓰러지면 다 끝이야!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 길 열립니다!' } ],
      },
    },
    92: {
      pre: [
        { who: 'narrator', text: '첫 번째 불빛. 낡은 망토를 두른 기사가 검을 짚고 섰다.' },
        { who: 'boss', text: '나는 군주의 첫 번째 검. 정정당당히 겨루자.' },
        { who: 'commander', text: '……브람이랑 같은 자세야. 오래된 왕국 검술.' },
        { who: 'boss', text: '나도 한때는 인간의 기사였다. 아주 오래전에.' },
        { who: 'kasha', text: '감상은 나중에. 저 기사, 엄호 대형이 완벽해.' },
      ],
      post: [
        { who: 'boss', text: '훌륭하다… 너의 스승은 좋은 기사였겠지.' },
        { who: 'commander', text: '최고의 기사였어. 당신만큼 고집도 셌고.' },
        { who: 'boss', text: '그런가… 그럼, 나도 이제 쉬어도 되겠군….' },
      ],
      battle: {
        start: [ { who: 'commander', text: '호위 기사부터 떼어 내! 엄호를 무너뜨려!' } ],
        boss: [ { who: 'boss', text: '검을 들어라, 열쇠의 아이여. 예를 갖춰 상대하마.' } ],
        wave: [ { who: 'kasha', text: '기사단 증원이야! 측면을 지켜!' } ],
        danger: [ { who: 'sera', text: '{commander}! 정면으로 받지 마, 돌아가!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 첫 번째 신하 끝!' } ],
      },
    },
    93: {
      pre: [
        { who: 'narrator', text: '두 번째 불빛. 허공에 수천 개의 마법진이 떠 있었다.' },
        { who: 'boss', text: '모든 마법은 계산이다. 네 승률은 영에 가깝다.' },
        { who: 'ordin', text: '나도 저렇게 계산하며 살았소. 그러다 틀렸지.' },
        { who: 'commander', text: '계산에 없는 걸 보여 주지. 클랜원들 손을.' },
      ],
      post: [
        { who: 'boss', text: '계산이… 맞지 않는다… 왜 서로를 감싸지…?' },
        { who: 'commander', text: '그게 우리가 이기는 이유야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '술사를 노려! 마법진이 완성되기 전에!' } ],
        boss: [ { who: 'boss', text: '변수 제거를 시작한다. 하나, 둘, 셋.' } ],
        wave: [ { who: 'kasha', text: '마법진에서 소환술사들이 쏟아져!' } ],
        danger: [ { who: 'sera', text: '{commander}! 마법진 한가운데야, 나와!' } ],
        last: [ { who: 'commander', text: '하나 남았다. 계산을 끝내 주자!' } ],
      },
    },
    94: {
      pre: [
        { who: 'narrator', text: '세 번째 불빛. 마계의 요새가 클랜을 집어삼키듯 솟았다.' },
        { who: 'boss', text: '나는 끝없는 군세. 내 소환은 마르지 않는다.' },
        { who: 'kasha', text: '요새에 갇혔어. 버티면서 저 녀석까지 닿아야 해.' },
        { who: 'commander', text: '성벽을 지키며 버틴다. 소환수가 줄어드는 때를 노려.' },
      ],
      post: [
        { who: 'boss', text: '소환이… 끊겼다… 내 군세가… 바닥났다고…?' },
        { who: 'bark', text: '우리는 바닥 안 났거든!' },
        { who: 'narrator', text: '세 번째 불빛이 꺼졌다. 남은 빛은 둘.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '성벽 사수! 소환수 물결을 받아 낸다!' } ],
        boss: [ { who: 'boss', text: '셀 수 없는 것들 앞에서 무릎 꿇어라.' } ],
        wave: [ { who: 'bark', text: '또 쏟아지오! 이놈의 소환은 끝이 없나!' } ],
        danger: [ { who: 'sera', text: '{commander}, 방어 태세로 한 번 버텨!' } ],
        last: [ { who: 'kasha', text: '하나 남았어! 군세가 끊겼다!' } ],
      },
    },
    95: {
      pre: [
        { who: 'narrator', text: '네 번째 불빛. 사슬에 묶인 검은 기사가 고개를 들었다.' },
        { who: 'boss', text: '인간이여. 하나만 묻자. 인간이란 무엇이냐.' },
        { who: 'boss', text: '나는 인간이 되고 싶었다. 그래서 금지되었다.' },
        { who: 'commander', text: '……왜 인간이 되고 싶었는데?' },
        { who: 'boss', text: '모르겠다. 그 답을 너희와 싸우며 찾겠다.' },
      ],
      post: [
        { who: 'boss', text: '쓰러진 동료에게 손을 내미는 것… 그게 인간인가.' },
        { who: 'commander', text: '응. 적어도 우리는 그렇게 생각해.' },
        { who: 'boss', text: '그렇다면… 마지막에… 조금은… 닮았을까….' },
        { who: 'sera', text: '……편히 쉬어. 이건 내 기도야.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '사슬 주변 호위부터! 기사를 고립시켜!' } ],
        boss: [ { who: 'boss', text: '보여 다오. 너희가 무엇인지.' } ],
        wave: [ { who: 'kasha', text: '사슬 너머에서 증원이야! 뒤를 봐!' } ],
        danger: [ { who: 'bark', text: '대장! 저 기사 진심이오, 물러서요!' } ],
        last: [ { who: 'sera', text: '하나 남았어. 답을 들려주자.' } ],
      },
    },
    96: {
      pre: [
        { who: 'narrator', text: '네 신하가 쓰러지자 옥좌로 향하는 회랑이 열렸다.' },
        { who: 'ordin', text: '이 회랑 끝이 군주의 근위대가 지키는 문이오.' },
        { who: 'kasha', text: '회랑이 살아 있어. 벽이 움직여.' },
        { who: 'commander', text: '멈추지 말고 간다. 벽에 붙잡히지 마.' },
      ],
      post: [
        { who: 'narrator', text: '회랑 끝, 검게 빛나는 거대한 문이 모습을 드러냈다.' },
        { who: 'ordin', text: '저 문 앞에 마지막 진지를 쳐야 하오.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '회랑을 지키며 전진! 끊기지 마!' } ],
        wave: [ { who: 'bark', text: '벽 속에서 적이 튀어나오오!' } ],
        danger: [ { who: 'sera', text: '{commander}, 회랑이 좁아져! 피해!' } ],
        last: [ { who: 'kasha', text: '하나 남았어. 문 앞이야.' } ],
      },
    },
    97: {
      pre: [
        { who: 'narrator', text: '옥좌의 문 앞. 클랜은 마지막 진지를 세웠다.' },
        { who: 'ordin', text: '문의 봉인을 풀 시간이 필요하오. 나를 지켜 주시오.' },
        { who: 'kasha', text: '이 영감을 지키는 날이 올 줄이야.' },
        { who: 'commander', text: '진지를 지킨다. 오르딘이 봉인을 풀 때까지.' },
      ],
      post: [
        { who: 'ordin', text: '봉인이 거의 풀렸소. 마지막 한 겹이 남았소.' },
        { who: 'ordin', text: '그 한 겹은… 내 몫이오.' },
        { who: 'commander', text: '무슨 뜻이야, 오르딘?' },
      ],
      battle: {
        start: [ { who: 'commander', text: '마지막 진지 사수! 오르딘을 지켜!' } ],
        wave: [ { who: 'kasha', text: '문 너머에서 근위대가 뛰쳐나와!' } ],
        danger: [ { who: 'sera', text: '{commander}! 진지 안쪽으로!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 진지 무사하오!' } ],
      },
    },
    98: {
      pre: [
        { who: 'ordin', text: '15년 전, 나는 그대 부모를 두고 도망쳤소.' },
        { who: 'ordin', text: '그 뒤로 내가 한 모든 일은 그 두려움에서 나왔지.' },
        { who: 'ordin', text: '마지막 봉인은 마도사의 목숨으로만 풀리오.' },
        { who: 'commander', text: '죽어서 갚는 건 너무 쉽다고 했잖아.' },
        { who: 'ordin', text: '그래서 살아 있는 동안 길을 열겠소. 끝까지 지켜 주시오.' },
      ],
      post: [
        { who: 'narrator', text: '마지막 봉인이 풀리며, 오르딘의 몸이 빛으로 흩어졌다.' },
        { who: 'ordin', text: '그대 부모에게… 미안하다고… 전해 주시오….' },
        { who: 'commander', text: '……직접 사과해. 언젠가, 저편에서.' },
        { who: 'narrator', text: '문이 열렸다. 그 너머에서 근위대장이 기다렸다.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '오르딘이 봉인을 푸는 동안 길을 연다!' } ],
        wave: [ { who: 'kasha', text: '근위대가 오르딘을 노려! 막아!' } ],
        danger: [ { who: 'sera', text: '{commander}! 너무 앞이야!' } ],
        last: [ { who: 'commander', text: '하나 남았다. 오르딘, 조금만 더!' } ],
      },
    },
    99: {
      pre: [
        { who: 'narrator', text: '옥좌의 전실. 칠흑의 전사가 대검을 땅에 꽂고 섰다.' },
        { who: 'boss', text: '네 신하를 넘었는가. 허나 나는 군주의 방패다.' },
        { who: 'boss', text: '군주께 닿으려면, 나를 부숴야 한다.' },
        { who: 'commander', text: '그럼 부순다. 다 같이.' },
        { who: 'bark', text: '붕대 풀었소, 대장. 마지막까지 앞에 서겠소.' },
      ],
      post: [
        { who: 'boss', text: '방패가… 깨졌다… 군주시여… 열쇠가 갑니다….' },
        { who: 'narrator', text: '마지막 문이 소리 없이 열렸다.' },
        { who: 'sera', text: '{commander}, 손. 다 같이 들어가자.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '근위대를 걷어 내고 전사를 포위한다!' } ],
        boss: [ { who: 'boss', text: '군주의 이름으로, 여기서 멈춰라!' } ],
        wave: [ { who: 'kasha', text: '마지막 근위대야! 이 뒤로는 군주뿐이야!' } ],
        danger: [ { who: 'sera', text: '{commander}! 저 대검은 받으면 안 돼!' } ],
        last: [ { who: 'bark', text: '하나 남았소! 문 앞이오!' } ],
      },
    },
    100: {
      pre: [
        { who: 'narrator', text: '마계의 옥좌. 그곳엔 투구를 쓴 거대한 전사가 앉아 있었다.' },
        { who: 'boss', text: '15년 전, 내 문을 닫은 두 인간이 있었다.' },
        { who: 'boss', text: '그 아이가 제 발로 왔구나. 열쇠를 바치러.' },
        { who: 'commander', text: '바치러 온 게 아니야. 잠그러 왔어.' },
        { who: 'commander', text: '혼자가 아니라, 여기 모두의 손으로.' },
        { who: 'boss', text: '인간 따위가 몇이 모이든, 결국 하나씩 꺾일 뿐.' },
      ],
      post: [
        { who: 'boss', text: '어째서… 하나를 꺾으면… 다른 손이 붙잡는가….' },
        { who: 'narrator', text: '지휘관이 흉터 위에 손을 펼치자 모두가 손을 포갰다.' },
        { who: 'commander', text: '이게 열쇠야. 우리 모두가.' },
        { who: 'narrator', text: '열쇠가 돌아가고, 마계 군주의 옥좌가 빛 속에 잠겼다.' },
      ],
      battle: {
        start: [ { who: 'commander', text: '솔빛 클랜, 마지막 싸움이다! 전원 함께!' } ],
        boss: [ { who: 'boss', text: '와라, 열쇠여. 너의 모든 것을 꺾어 주마.' } ],
        wave: [ { who: 'kasha', text: '옥좌의 그림자가 일어나! 마지막 군세야!' } ],
        danger: [ { who: 'sera', text: '{commander}! 쓰러지지 마! 우리가 있어!' } ],
        last: [ { who: 'bark', text: '하나 남았소, 대장! 끝냅시다, 다 같이!' } ],
      },
    },
  },
};
