// ═══════════════════════════════════════════
//  lobby.js — 로비 & 화면 플로우 관리 (MPA)
// ═══════════════════════════════════════════

// ── 이름 풀 (판타지 외국인 + 한국인) ─────────────
const NAMES=(()=>{
  const FANTASY_NAMES = [
  "아서", "아리엘", "아르겐", "아델", "아스텔", "아드리아", "아론", "아가레스", "아르카", "아벨",
  "아나이스", "아라곤", "아르웬", "아크", "아틀라스", "아폴론", "알렉스", "알리사", "알베르", "알테어",
  "알렌", "알리시아", "암브로스", "앤드류", "앤설", "앨리스", "앨런", "앰버", "에단", "에릭",
  "에반", "에스텔", "에드가", "에드윈", "에리스", "에리카", "에밀리", "에이든", "에이브릴", "에이린",
  "에즈라", "에크하르트", "엑시온", "엘라", "엘로이", "엘리", "엘리야", "엘리자", "엘릭", "엘시",
  "엘윈", "엘자", "엘프리데", "엠마", "오데트", "오리온", "오스카", "오필리아", "올리버", "올리비아",
  "와이엇", "윌리엄", "윈터", "유니", "유리엘", "유스티티아", "이그니스", "이나", "이다", "이라",
  "이리나", "이반", "이사벨", "이솔데", "이안", "이오", "이카루스", "이트리", "일리아스", "자비에",
  "자크", "잔", "재스퍼", "잭", "제레미", "제로", "제롬", "제리", "제시카", "제이드",
  "제이슨", "제이크", "제인", "젤다", "조나단", "조슈아", "조이", "조지", "줄리아", "줄리안",
  "지크", "진", "질", "찰스", "채드", "첼시", "카나", "카디스", "카라", "카론",
  "카류", "카밀라", "카스", "카시우스", "카엘", "카이", "카일", "카트리나", "칼", "칼리",
  "칼릭스", "칼린", "캐서린", "캐시", "케빈", "케일", "켈리", "켈타스", "켄", "코라",
  "코델리아", "코디", "코어", "콜린", "콤", "쿠퍼", "퀸", "퀸시", "큐", "크리스",
  "크리스틴", "클라라", "클라우드", "클레어", "클로이", "클리프", "키라", "키리안", "키아라", "키안",
  "타니아", "타라", "타일러", "테라", "테오", "테오도르", "테이", "테일러", "토마스", "토비",
  "트리스", "트리스탄", "티나", "티라", "티모시", "티아", "티아나", "티오", "파비안", "파스칼",
  "페라", "페이", "페이트", "펠릭스", "펜리르", "포비", "폴", "프란", "프란시스", "프레드",
  "프레야", "플로라", "피터", "피트", "필립", "하디", "하르트", "하비", "하이디", "하인",
  "한나", "한스", "해리", "헌터", "헤라", "헤르만", "헤일리", "헥터", "헨리", "헬가",
  "헬렌", "호크", "홀리", "휴", "히스", "힐다", "가브리엘", "가이", "가트", "갈라드",
  "거스", "그레이", "그레이스", "그리핀", "글렌", "기드온", "길", "나나", "나디아", "나란",
  "나르", "나이", "나탈리", "나탄", "네로", "네스", "넬", "노라", "노아", "녹스",
  "니나", "니콜", "니키", "닉", "다나", "다니엘", "다리오", "다리우스", "다이애나", "다크",
  "단", "달리아", "대니", "데미안", "데이비드", "데이지", "덱스", "델라", "도라", "도리스",
  "도미닉", "돈", "라나", "라라", "라스", "라이", "라이언", "라일라", "라파엘", "란",
  "란슬롯", "랄프", "래리", "랙스", "랜드", "레나", "레너드", "레니", "레오", "레온",
  "레이", "레이나", "레이븐", "레이첼", "렉스", "로라", "로런", "로로", "로리", "로이드"
];
const ANIME_NAMES = [
  "카이토", "렌", "하루", "유키", "사쿠라", "켄지", "아키라", "히카리", "소라", "린",
  "리쿠", "미오", "나츠", "루피", "조로", "상디", "나미", "우솝", "쵸파", "로빈",
  "프랑키", "브룩", "징베", "나루토", "사스케", "사쿠라", "카카시", "히나타", "가아라", "이타치",
  "이치고", "루키아", "오리히메", "우류", "렌지", "뱌쿠야", "토시로", "켄파치", "긴", "아이젠",
  "탄지로", "네즈코", "젠이츠", "이노스케", "기유", "시노부", "렌고쿠", "텐겐", "미츠리", "무이치로",
  "교메이", "사네미", "오바나이", "데쿠", "바쿠고", "쇼토", "우라라카", "이이다", "츠유", "키리시마",
  "카미나리", "지로", "모모", "토코야미", "미나", "하가쿠레", "쇼타", "올마이트", "엔데버", "호크스",
  "에렌", "미카사", "아르민", "리바이", "엘빈", "한지", "사샤", "코니", "쟝", "히스토리아",
  "라이토", "엘", "미사", "니아", "멜로", "류크", "렘", "곤", "키르아", "크라피카",
  "레오리오", "히소카", "클로로", "네테로", "메르엠", "코무기", "긴토키", "신파치", "카구라", "사다하루",
  "히지카타", "오키타", "콘도", "카츠라", "엘리자베스", "신스케", "카무이", "아톰", "코난", "란",
  "하이바라", "겐타", "미츠히코", "아유미", "소노코", "헤이지", "카즈하", "키드", "아무로", "아카이",
  "신지", "레이", "아스카", "카오루", "마리", "미사토", "겐도", "료", "카오리", "코우세이",
  "츠바키", "와타리", "타키", "미츠하", "호다카", "히나", "소피", "하울", "치히로", "하쿠",
  "산", "아시타카", "토토로", "키키", "포뇨", "시타", "파즈", "나우시카", "세일러문", "턱시도가면",
  "머큐리", "마스", "쥬피터", "비너스", "치비우사", "우라누스", "넵튠", "플루토", "새턴", "사토시",
  "피카츄", "이슬", "웅", "로사", "로이", "태일", "매튜", "소라", "한솔", "미나",
  "석이", "리키", "나리", "류", "켄", "춘리", "가일", "달심", "블랑카", "장기에프",
  "혼다", "바이슨", "발로그", "사가트", "베가", "아카리", "히카루", "우미", "후우", "모코나",
  "클램프", "체리", "샤오랑", "지수", "도진", "청명", "에리얼", "크로우", "유체리", "유도진",
  "오청명", "루비", "스피넬", "케로", "유에", "셋쇼마루", "이누야샤", "가영", "미로쿠", "산고",
  "싯포", "키라라", "나라쿠", "카라", "칸나", "하쿠도시", "모료마루", "몽환의바쿠야", "링", "자켄",
  "코우가", "아야메", "긴타", "핫카쿠", "토토사이", "묘가", "금강", "카에데", "츠바사", "샤오랑",
  "사쿠라", "파이", "쿠로가네", "모코나", "유코", "와타누키", "도메키", "히마와리", "코하네", "마루",
  "모로", "아라라기", "센죠가하라", "하치쿠지", "칸바루", "센고쿠", "하네카와", "오시노", "시노부", "카렌",
  "츠키히", "요츠기", "오노데라", "치토게", "츠구미", "마리카", "루리", "슈", "라쿠", "쿄코"
];
const KOREAN_NAMES = [
  "강도현", "강서준", "강지민", "고은별", "구민재", "권소윤", "김가은", "김도윤", "김민준", "김서연",
  "김수아", "김예준", "김우진", "김지우", "김지호", "김하은", "김현우", "나영석", "남주혁", "노을",
  "류승민", "류지혜", "문지수", "민경훈", "박건우", "박서영", "박수민", "박연진", "박지영", "박현준",
  "배수지", "백승호", "서동현", "서지훈", "성민재", "손예진", "송강호", "송민호", "신예은", "신지수",
  "안재현", "양세종", "오지호", "우도환", "유아인", "유재석", "윤도현", "윤서아", "이도현", "이서진",
  "이수혁", "이승기", "이정재", "이준기", "이지은", "이현우", "임시완", "임지연", "장기용", "장동건"
];
  const all=[...FANTASY_NAMES,...ANIME_NAMES, ...KOREAN_NAMES];
  // 셔플
  for(let i=all.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[all[i],all[j]]=[all[j],all[i]]}
  return all;
})();

Object.assign(G,{
  // ══ 로비 상태 ══
  gold:0,
  _saveKey:'game_save',
  _shopKey:'game_shop',
  _navKey:'game_nav',
  _partyKey:'game_party',

  // ══ 네비게이션 임시 데이터 ══
  _saveNav(data){try{localStorage.setItem(this._navKey,JSON.stringify(data))}catch(e){}},
  _loadNav(){try{return JSON.parse(localStorage.getItem(this._navKey))}catch(e){return null}},
  _clearNav(){try{localStorage.removeItem(this._navKey)}catch(e){}},

  // ── 파티 저장/로드 ──
  _saveParty(){try{localStorage.setItem(this._partyKey,JSON.stringify(this.party))}catch(e){}},
  _loadParty(){try{const r=localStorage.getItem(this._partyKey);if(r)this.party=JSON.parse(r)}catch(e){}},

  // ── 골드 로드/세이브 ──
  _loadGold(){
    try{const d=JSON.parse(localStorage.getItem(this._saveKey));
      if(d){this.gold=d.gold||0;this.cleared=new Set(d.cleared||[])}
      else{this.gold=2000;this.cleared=new Set();this._saveGold()}
    }catch(e){}
  },
  _saveGold(){
    try{localStorage.setItem(this._saveKey,JSON.stringify({gold:this.gold,cleared:[...this.cleared]}))}catch(e){}
  },
  addGold(n){this.gold+=n;this._saveGold();this._updGoldUI()},
  _updGoldUI(){
    const v=this.gold.toLocaleString();
    ['lobby-gold','sanc-gold-val','shop-gold-val'].forEach(id=>{
      const el=document.getElementById(id);if(el)el.textContent=v});
  },

  // ══════════════════════════════════
  //  페이지 초기화
  // ══════════════════════════════════
  _initLobbyPage(){
    this._updGoldUI();
    const splash=document.getElementById('splash');
    if(splash){splash.classList.add('fade-out');setTimeout(()=>splash.remove(),500)}
  },

  _initStageSelectPage(){
    const l=document.getElementById('stage-list');l.innerHTML='';
    STAGES.forEach((st,i)=>{
      const ul=i===0||this.cleared.has(i);
      const cl=this.cleared.has(i+1);
      const b=document.createElement('div');b.className='stage-btn'+(ul?'':' locked')+(cl?' cleared':'');
      b.innerHTML=`<div class="sb-num">${st.id}</div><div class="sb-name">${st.name}</div><div class="sb-info">적 ${st.tot}체</div><div class="sb-stars">${cl?'⭐':'☆'}</div>`;
      if(ul)b.onclick=()=>{
        this._loadParty();
        // 죽은 유닛 제거
        this.party=this.party.filter(uid=>{const ch=ROSTER.getChar(uid);return ch&&!ch.dead});
        if(this.party.length>=MIN_P){
          // 파티 충분 → 바로 전투
          this._saveNav({cStage:st,party:this.party});
          location.href='battle.html';
        }else{
          // 파티 부족 → 파티 편성
          this._saveNav({cStage:st});
          location.href='party-select.html';
        }
      };
      l.appendChild(b);
    });
  },

  _initPartySelectPage(){
    const nav=this._loadNav();
    this.cStage=nav?.cStage||null;
    this._loadParty();
    const alive=ROSTER.getAll().filter(c=>!c.dead);
    // 죽은 유닛 제거
    this.party=this.party.filter(uid=>{const ch=ROSTER.getChar(uid);return ch&&!ch.dead});
    // 파티가 비어있으면 자동 편성
    if(!this.party.length){
      this.party=alive.slice(0,Math.min(MAX_P,alive.length)).map(c=>c.uid);
      this._saveParty();
    }
    this.rP();
  },

  _initBattlePage(){
    const nav=this._loadNav();
    this._clearNav();
    if(nav?.resume){
      const bs=this._loadBattle();
      if(bs){
        this._initBattleListeners();
        this.cStage=bs.stage;this.party=bs.party;
        this.ter=bs.ter;this.turn=bs.turn;this.eSpwn=bs.eSpwn;this.eQ=bs.eQ;
        this.breached=bs.breached;this.gateHP=bs.gateHP;this.wallHP=bs.wallHP;this.nid=bs.nid;
        this.battleExp=bs.battleExp||{};
        this.units=bs.units;this.phase='player';this.sel=null;this.over=false;
        this.awPM=false;this.anim=false;this.camDir=0;
        document.querySelector('#cam-dir .cd-arrow').textContent=CARR[0];
        document.querySelector('#cam-dir .cd-label').textContent=CLAB[0];
        const w=document.getElementById('iso-world');
        w.querySelectorAll('.iso-tile,.unit-sprite,.float-text').forEach(e=>e.remove());
        this.layW();this.vfxInit();this.rTer();this.rUnits();this.uUI();this.defI();this.rMM();
        this.bgmStart();
        setTimeout(()=>this.scrollToAllies(),50);
      }else{location.href='index.html'}
    }else if(nav?.cStage){
      this.cStage=nav.cStage;
      // nav에 party가 있으면 사용, 없으면 localStorage에서 로드
      if(nav.party){this.party=nav.party}else{this._loadParty()}
      if(!this.party||this.party.length<MIN_P){location.href='index.html';return}
      this._initBattleListeners();
      this.eSpwn=0;this.eQ=[...this.cStage.en];
      this.init();
    }else{location.href='index.html'}
  },

  // ══════════════════════════════════
  //  로비 네비게이션
  // ══════════════════════════════════
  openStage(){
    const bs=this._loadBattle();
    if(bs){
      this._showConfirm('이전 전투 데이터가 있습니다.\n이어서 플레이하시겠습니까?',
        ()=>{this._saveNav({resume:true});location.href='battle.html'},
        ()=>{this._clearBattle();location.href='stage-select.html'});
      return;
    }
    location.href='stage-select.html';
  },
  openParty(){
    this._saveNav({cStage:null});
    location.href='party-select.html';
  },
  returnToLobby(){location.href='index.html'},
  goNextStage(stage){
    this._loadParty();
    this.party=this.party.filter(uid=>{const ch=ROSTER.getChar(uid);return ch&&!ch.dead});
    if(this.party.length>=MIN_P){
      this._saveNav({cStage:stage,party:this.party});
      location.href='battle.html';
    }else{
      this._saveNav({cStage:stage});
      location.href='party-select.html';
    }
  },
  partyBack(){
    if(this.cStage)location.href='stage-select.html';
    else location.href='index.html';
  },

  // ══════════════════════════════════
  //  파티 편성
  // ══════════════════════════════════
  rP(){
    const ro=document.getElementById('ps-roster');ro.innerHTML='';
    const inParty=new Set(this.party);
    const alive=ROSTER.getAll().filter(c=>!c.dead);
    const groups={};alive.forEach(ch=>{if(!groups[ch.cls])groups[ch.cls]=[];groups[ch.cls].push(ch)});
    Object.keys(CD).forEach(cls=>{
      const chars=groups[cls]||[];if(!chars.length)return;
      const d=CD[cls];
      chars.forEach(ch=>{
        const sel=inParty.has(ch.uid);
        const grade=ROSTER.potGrade(ch.uid);
        const gClr=grade==='S'?'#f0c040':grade==='A'?'#60a5fa':grade==='B'?'#4ade80':'#9ca3af';
        const c=document.createElement('div');c.className='class-card'+(sel?' selected':'');
        const atMax=ch.lv>=MAX_LEVEL;
        const expNeed=atMax?1:(expForLevel(ch.lv));
        const expPct=atMax?100:Math.min(100,Math.round(((ch.exp||0)/expNeed)*100));
        c.innerHTML=`<div class="cc-grade" style="color:${gClr}">${grade}</div>`+
          `<div class="cc-icon">${d.icon}</div>`+
          `<div class="cc-name">${ch.name||d.name} <span style="font-size:10px;color:#64748b">Lv.${ch.lv}</span></div>`+
          `<div class="cc-role">${d.desc}</div>`+
          `<div class="cc-exp"><div class="cc-exp-bar"><div class="cc-exp-fill" style="width:${expPct}%"></div></div><span class="cc-exp-txt">${atMax?'MAX':`${ch.exp||0}/${expNeed}`}</span></div>`+
          `<div class="cc-stats">HP <b>${ch.hp}</b> ATK <b>${ch.atk}</b> DEF <b>${ch.def}</b><br>MOV <b>${ch.move}</b> RNG <b>${ch.range}</b></div>`+
          `<div class="cc-pot">잠재 <span style="font-size:10px;color:#94a3b8">HP+${ch.pot.hp} ATK+${ch.pot.atk} DEF+${ch.pot.def}</span></div>`;
        c.onclick=()=>{
          if(sel)this.party=this.party.filter(u=>u!==ch.uid);
          else if(this.party.length<MAX_P)this.party.push(ch.uid);
          this.rP()};
        ro.appendChild(c)})});
    const pp=document.getElementById('ps-party');pp.innerHTML='';
    for(let i=0;i<MAX_P;i++){const s=document.createElement('div');s.className='party-slot';
      if(i<this.party.length){
        const ch=ROSTER.getChar(this.party[i]);
        if(ch){const d=CD[ch.cls];s.classList.add('filled');s.innerHTML=`${d.icon}<span class="ps-lv">Lv${ch.lv}</span><span class="ps-x">✕</span>`;
          s.onclick=()=>{this.pRemAt(i)}}}
      pp.appendChild(s)}
    const n=this.party.length;
    document.getElementById('ps-counter').textContent=`${n} / ${MAX_P}`;
    document.getElementById('ps-counter').style.color=n>=MIN_P?'var(--green)':'var(--blue)';
    const startBtn=document.getElementById('ps-start');
    if(this.cStage){startBtn.textContent='▶ 출격';startBtn.disabled=n<MIN_P;startBtn.style.display=''}
    else{startBtn.style.display='none'}
    ROSTER.save();
    this._saveParty();
  },
  pRemAt(i){this.party.splice(i,1);this.rP()},
  confirmP(){
    if(this.party.length<MIN_P)return;
    this._saveNav({cStage:this.cStage,party:this.party});
    location.href='battle.html';
  },

  // ══════════════════════════════════
  //  전투 종료 + 퍼마데스
  // ══════════════════════════════════
  onBattleEnd(win){
    // 처치한 적 기반 총 경험치 → 생존 아군 균등 분배
    const deadEnemies=this.units.filter(u=>u.team==='enemy'&&u.hp<=0);
    const killPool=deadEnemies.reduce((s,u)=>s+killExp(this.cStage?this.cStage.id:1,u.cls),0);
    const survivors=this.units.filter(u=>u.team==='ally'&&u.hp>0&&u.uid);
    const killEach=survivors.length?Math.floor(killPool/survivors.length):0;
    // 행동 EXP(개인) + 처치 분배 EXP 합산
    this._expResults=[];
    survivors.forEach(u=>{
      const actE=(this.battleExp&&this.battleExp[u.uid])||0;
      const total=actE+killEach;
      if(!total)return;
      const r=ROSTER.gainExp(u.uid,total);
      this._expResults.push({uid:u.uid,exp:total,actExp:actE,killExp:killEach,leveled:r.leveled,prevLv:r.prevLv});
    });
    this._totalExp=killPool;
    this._deadEnemyCount=deadEnemies.length;
    if(win){
      const reward=50+(this.cStage?this.cStage.id*30:0);
      this.addGold(reward);
      if(this.cStage)this.cleared.add(this.cStage.id);
      this._saveGold();
    }
    this.units.filter(u=>u.team==='ally'&&u.hp<=0&&u.uid).forEach(u=>{
      ROSTER.markDead(u.uid);
    });
    this._clearBattle();
  },

  // ── 전투 저장/복원 ──
  _saveBattle(){
    try{
      const d={
        stage:this.cStage,party:this.party,
        units:this.units.map(u=>({...u})),
        ter:this.ter,turn:this.turn,eSpwn:this.eSpwn,eQ:this.eQ,
        breached:this.breached,gateHP:{...this.gateHP},wallHP:{...this.wallHP},
        nid:this.nid,battleExp:{...this.battleExp}
      };
      localStorage.setItem('game_battle',JSON.stringify(d));
    }catch(e){}
  },
  _loadBattle(){
    try{const r=localStorage.getItem('game_battle');return r?JSON.parse(r):null}catch(e){return null}
  },
  _clearBattle(){try{localStorage.removeItem('game_battle')}catch(e){}},

  // ══════════════════════════════════
  //  성소 (부활)
  // ══════════════════════════════════
  _renderSanctuary(){
    const list=document.getElementById('sanc-list');
    const dead=ROSTER.getAll().filter(c=>c.dead);
    list.innerHTML='';
    if(!dead.length){
      list.innerHTML='<div style="color:var(--dim);font-size:12px;text-align:center;padding:20px">사망한 전투원이 없습니다</div>';
      return;
    }
    dead.forEach(ch=>{
      const d=CD[ch.cls];
      const cost=this._reviveCost(ch);
      const canAfford=this.gold>=cost;
      const el=document.createElement('div');el.className='sanc-card';
      el.innerHTML=`<div class="sanc-icon">${d.icon}</div>`+
        `<div class="sanc-info"><div class="sanc-name">${ch.name||d.name} <span style="color:#64748b;font-size:10px">Lv.${ch.lv}</span></div>`+
        `<div class="sanc-stats">HP ${ch.hp} · ATK ${ch.atk} · DEF ${ch.def}</div></div>`+
        `<button class="sanc-btn${canAfford?'':' disabled'}" ${canAfford?'':'disabled'}>${cost}G 부활</button>`;
      el.querySelector('.sanc-btn').onclick=()=>{
        if(this.gold<cost)return;
        this.gold-=cost;this._saveGold();this._updGoldUI();
        ROSTER.revive(ch.uid);
        this._renderSanctuary();
      };
      list.appendChild(el);
    });
  },
  _reviveCost(ch){return 20+ch.lv*10},

  // ══════════════════════════════════
  //  상점
  // ══════════════════════════════════
  _loadShop(){
    try{
      const raw=localStorage.getItem(this._shopKey);
      if(raw){
        const d=JSON.parse(raw);
        if(Date.now()-d.ts<6*3600*1000){this._shopData=d;return}
      }
    }catch(e){}
    this._genShop();
  },
  _genShop(){
    const classes=Object.keys(CD);
    const items=[];
    // 캐릭터 3개
    for(let i=0;i<3;i++){
      const cls=classes[Math.floor(Math.random()*classes.length)];
      const d=CD[cls];
      const pot={
        hp:  +(d.growth.hp[0]+Math.random()*(d.growth.hp[1]-d.growth.hp[0])).toFixed(1),
        atk: +(d.growth.atk[0]+Math.random()*(d.growth.atk[1]-d.growth.atk[0])).toFixed(1),
        def: +(d.growth.def[0]+Math.random()*(d.growth.def[1]-d.growth.def[0])).toFixed(1)
      };
      const name=NAMES[Math.floor(Math.random()*NAMES.length)];
      const cost=60+Math.floor(Math.random()*40);
      items.push({type:'char',cls,name,pot,cost,sold:false});
    }
    // 물약 2개 (가중치 랜덤)
    for(let i=0;i<2;i++){
      const totalW=EXP_POTIONS.reduce((s,p)=>s+p.weight,0);
      let r=Math.random()*totalW,pot=EXP_POTIONS[0];
      for(const p of EXP_POTIONS){r-=p.weight;if(r<=0){pot=p;break}}
      items.push({type:'potion',potionId:pot.id,name:pot.name,icon:pot.icon,exp:pot.exp,cost:pot.cost,sold:false});
    }
    this._shopData={ts:Date.now(),items};
    this._saveShop();
  },
  _saveShop(){try{localStorage.setItem(this._shopKey,JSON.stringify(this._shopData))}catch(e){}},
  _renderShop(){
    const list=document.getElementById('shop-list');list.innerHTML='';
    const timeEl=document.getElementById('shop-timer');
    const remain=Math.max(0,6*3600*1000-(Date.now()-this._shopData.ts));
    const h=Math.floor(remain/3600000);const m=Math.floor((remain%3600000)/60000);
    timeEl.textContent=`갱신까지 ${h}시간 ${m}분`;
    this._shopData.items.forEach((item,idx)=>{
      const iType=item.type||'char';
      if(iType==='char'){
        const d=CD[item.cls];
        const canAfford=this.gold>=item.cost&&!item.sold;
        const g=d.growth;
        const scores=['hp','atk','def'].map(k=>{const[mn,mx]=g[k];const rng=mx-mn;return rng>0?(item.pot[k]-mn)/rng:0.5});
        const avg=scores.reduce((a,b)=>a+b,0)/3;
        const grade=avg>=0.85?'S':avg>=0.65?'A':avg>=0.35?'B':'C';
        const gClr=grade==='S'?'#f0c040':grade==='A'?'#60a5fa':grade==='B'?'#4ade80':'#9ca3af';
        const el=document.createElement('div');el.className='shop-card'+(item.sold?' sold':'');
        el.innerHTML=`<div class="shop-grade" style="color:${gClr}">${grade}</div>`+
          `<div class="shop-icon">${d.icon}</div>`+
          `<div class="shop-name">${item.name}</div>`+
          `<div class="shop-cls">${d.name} · ${d.desc}</div>`+
          `<div class="shop-stats">HP ${d.base.hp} ATK ${d.base.atk} DEF ${d.base.def}</div>`+
          `<div class="shop-pot">잠재 HP+${item.pot.hp} ATK+${item.pot.atk} DEF+${item.pot.def}</div>`+
          `<button class="shop-btn${item.sold?' sold-btn':''}${canAfford?'':' disabled'}" ${canAfford&&!item.sold?'':'disabled'}>${item.sold?'모집 완료':item.cost+'G 모집'}</button>`;
        if(!item.sold)el.querySelector('.shop-btn').onclick=()=>{
          if(this.gold<item.cost)return;
          this.gold-=item.cost;this._saveGold();this._updGoldUI();
          const ch=ROSTER.addChar(item.cls);
          if(ch){ch.name=item.name;ch.pot=item.pot;ROSTER.save()}
          item.sold=true;this._saveShop();this._renderShop();
        };
        list.appendChild(el);
      }else{
        // 물약
        const canAfford=this.gold>=item.cost&&!item.sold;
        const el=document.createElement('div');el.className='shop-card potion-card'+(item.sold?' sold':'');
        el.innerHTML=`<div class="shop-icon">${item.icon}</div>`+
          `<div class="shop-name">${item.name}</div>`+
          `<div class="shop-cls">EXP +${item.exp}</div>`+
          `<button class="shop-btn potion-btn${item.sold?' sold-btn':''}${canAfford?'':' disabled'}" ${canAfford&&!item.sold?'':'disabled'}>${item.sold?'사용 완료':item.cost+'G 구매'}</button>`;
        if(!item.sold)el.querySelector('.shop-btn').onclick=()=>{
          if(this.gold<item.cost)return;
          this._showPotionModal(item,idx);
        };
        list.appendChild(el);
      }
    });
  },

  // ── 물약 사용 모달 ──
  _showPotionModal(item,idx){
    const alive=ROSTER.getAll().filter(c=>!c.dead);
    if(!alive.length)return;
    const ov=document.getElementById('modal-overlay');
    document.getElementById('modal-title').textContent='캐릭터 선택';
    document.getElementById('modal-title').className='';
    let h='<div class="potion-target-list">';
    alive.forEach(ch=>{
      const d=CD[ch.cls];
      const atMax=ch.lv>=MAX_LEVEL;
      const expNeed=atMax?0:expForLevel(ch.lv);
      const expPct=atMax?100:Math.min(100,Math.round((ch.exp||0)/expNeed*100));
      h+=`<div class="pt-btn${atMax?' pt-max':''}" data-uid="${ch.uid}">`+
        `<span class="pt-icon">${d.icon}</span>`+
        `<span class="pt-info">${ch.name||d.name} Lv.${ch.lv}</span>`+
        `<span class="pt-exp">${atMax?'MAX':`${ch.exp||0}/${expNeed}`}</span>`+
        `</div>`;
    });
    h+='</div>';
    document.getElementById('modal-sub').innerHTML=`${item.icon} ${item.name} (EXP +${item.exp})<br><br>`+h;
    const bt=document.getElementById('modal-buttons');bt.innerHTML='';
    const cb=document.createElement('button');cb.className='modal-btn secondary';cb.textContent='취소';
    cb.onclick=()=>ov.classList.remove('show');bt.appendChild(cb);
    ov.classList.add('show');
    // 캐릭터 선택 이벤트
    document.querySelectorAll('.pt-btn:not(.pt-max)').forEach(b=>{
      b.onclick=()=>{
        const uid=+b.dataset.uid;
        this.gold-=item.cost;this._saveGold();this._updGoldUI();
        const r=ROSTER.gainExp(uid,item.exp);
        item.sold=true;this._saveShop();
        ov.classList.remove('show');
        this._renderShop();
        // 레벨업 알림
        if(r.leveled>0){
          const ch=ROSTER.getChar(uid);const d=CD[ch.cls];
          setTimeout(()=>{
            this._showConfirm(`${d.icon} ${ch.name||d.name}\nLv.${r.prevLv} → Lv.${ch.lv}${r.leveled>1?' ('+r.leveled+'단계 레벨업!)':''}`,null,null);
          },100);
        }
      };
    });
  },

  // ══════════════════════════════════
  //  설정
  // ══════════════════════════════════
  _renderLobbySettings(){
    const c=document.getElementById('lset-content');c.innerHTML='';
    c.innerHTML=`
      <div class="sp-toggle"><span class="sp-tlabel">🎵 배경음악</span><label class="sp-switch"><input type="checkbox" id="ls-bgm" ${this._sett.bgmOn?'checked':''}><span class="slider"></span></label></div>
      <div class="sp-row"><span class="sp-label">    볼륨</span><input type="range" id="ls-bgmv" min="0" max="100" value="${Math.round(this._sett.bgmVol*100)}"><span class="sp-val" id="ls-bgmv-v">${Math.round(this._sett.bgmVol*100)}</span></div>
      <div class="sp-toggle"><span class="sp-tlabel">🔊 효과음</span><label class="sp-switch"><input type="checkbox" id="ls-sfx" ${this._sett.sfxOn?'checked':''}><span class="slider"></span></label></div>
      <div class="sp-row"><span class="sp-label">    볼륨</span><input type="range" id="ls-sfxv" min="0" max="100" value="${Math.round(this._sett.sfxVol*100)}"><span class="sp-val" id="ls-sfxv-v">${Math.round(this._sett.sfxVol*100)}</span></div>
      <div class="sp-divider"></div>
      <div class="sp-row"><span class="sp-label">⏩ 게임 속도</span><input type="range" id="ls-spd" min="50" max="200" value="${Math.round(1/this._sett.speed*100)}" step="25"><span class="sp-val" id="ls-spd-v">${this._sett.speed.toFixed(1)}x</span></div>
      <div class="sp-divider"></div>
      <div style="text-align:center;margin-top:8px">
        <button class="sp-btn danger" id="ls-reset">⚠ 모든 데이터 초기화</button>
      </div>`;
    c.querySelector('#ls-bgm').onchange=e=>{this._sett.bgmOn=e.target.checked;this.saveSett()};
    c.querySelector('#ls-bgmv').oninput=e=>{this._sett.bgmVol=e.target.value/100;c.querySelector('#ls-bgmv-v').textContent=e.target.value;this.saveSett()};
    c.querySelector('#ls-sfx').onchange=e=>{this._sett.sfxOn=e.target.checked;this.saveSett()};
    c.querySelector('#ls-sfxv').oninput=e=>{this._sett.sfxVol=e.target.value/100;c.querySelector('#ls-sfxv-v').textContent=e.target.value;this.saveSett()};
    c.querySelector('#ls-spd').oninput=e=>{const s=100/e.target.value;this._sett.speed=s;c.querySelector('#ls-spd-v').textContent=s.toFixed(1)+'x';this.saveSett()};
    c.querySelector('#ls-reset').onclick=()=>{
      this._showConfirm('정말로 모든 데이터를 초기화하시겠습니까?\n모든 캐릭터, 골드, 진행 상황이 삭제됩니다.',
        ()=>{
          localStorage.clear();
          location.href='index.html';
        },null);
    };
  },

  // ══ 확인 다이얼로그 ══
  _showConfirm(msg,onYes,onNo){
    const ov=document.getElementById('modal-overlay');
    document.getElementById('modal-title').textContent='확인';
    document.getElementById('modal-title').className='';
    document.getElementById('modal-sub').innerHTML=msg.replace(/\n/g,'<br>');
    const bt=document.getElementById('modal-buttons');bt.innerHTML='';
    const y=document.createElement('button');y.className='modal-btn';y.textContent='확인';
    y.onclick=()=>{ov.classList.remove('show');if(onYes)onYes()};bt.appendChild(y);
    const n=document.createElement('button');n.className='modal-btn secondary';n.textContent='취소';
    n.onclick=()=>{ov.classList.remove('show');if(onNo)onNo()};bt.appendChild(n);
    ov.classList.add('show');
  },
});
