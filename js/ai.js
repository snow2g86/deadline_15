Object.assign(G, {
  // Turns
  endTurn(){if(this.phase!=='player'||this.over||this.awPM||this.anim)return;
    document.getElementById('turn-confirm').classList.remove('show');
    this.clrSel();this.phase='enemy';this.uUI();this.turnFlash('enemy');this.sfxTurnEnemy();
    document.getElementById('enemy-banner').classList.add('show');setTimeout(()=>this.doET(),800)},
  chkAutoEnd(){if(this.phase!=='player'||this.over||this.anim||this.awPM)return;
    const al=this.alive('ally');if(!al.length||!al.every(u=>u.ha))return;
    if(this.autoEndSkip){setTimeout(()=>this.endTurn(),350);return}
    document.getElementById('turn-confirm').classList.add('show')},
  confirmEndTurn(yes){
    document.getElementById('turn-confirm').classList.remove('show');
    if(yes)setTimeout(()=>this.endTurn(),100)},
  autoEndSkip:false,
  setAutoEnd(v){this.autoEndSkip=v},
  async doET(){const s=this.cStage;
    if(s&&this.turn%s.si===0&&this.eSpwn<s.tot){this.showWv(`웨이브 — 남은 적 ${s.tot-this.eSpwn}체`);this.sfxWave();this.spawnW();this.rUnits();await sl(600);this.hideWv()}
    // Enemy resource recovery
    this.alive('enemy').forEach(u=>{
      tickBuffs(u);
      if(u.resType==='mana'){u.res=Math.min(u.maxRes,u.res+u.resRec)}
      else if(u.resType==='energy'){
        let rec=u.resRec;
        if(u.cls==='assassin'){const t=this.ter[u.y]?this.ter[u.y][u.x]:null;if(t==='forest')rec*=2}
        u.res=Math.min(u.maxRes,u.res+rec)}
    });this.rUnits();
    this.anim=true;for(const e of[...this.alive('enemy')]){if(this.over)break;await this.eAI(e);await sl(500)}
    this.anim=false;document.getElementById('enemy-banner').classList.remove('show');this.chkEnd();
    if(!this.over){this.turn++;this.phase='player';this.turnFlash('player');this.sfxTurnPlayer();
      this.alive('ally').forEach(u=>{
        u.hm=false;u.ha=false;u.waited=false;u.mo=false;
        tickBuffs(u);
        // Resource recovery
        if(u.resType==='mana'){u.res=Math.min(u.maxRes,u.res+u.resRec)}
        else if(u.resType==='energy'){
          let rec=u.resRec;
          // Assassin stealth: 2x recovery in forest
          if(u.cls==='assassin'){const t=this.ter[u.y]?this.ter[u.y][u.x]:null;if(t==='forest')rec*=2}
          u.res=Math.min(u.maxRes,u.res+rec)}
        // fury: no auto recovery
      });
      this.uUI();this.rUnits();this.rTer();this.rMM()}},
  async eAI(u){const al=this.alive('ally');if(!al.length&&!this.hasAllyWall())return;
    // Check attack from current position first
    const inR=this.atkC(u).filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'}).map(c=>this.uAt(c.x,c.y));
    if(inR.length){const kl=inR.filter(a=>a.hp<=Math.max(1,u.atk-a.def));
      if(kl.length){await this.eAtkAsync(u,kl.sort((a,b)=>a.hp-b.hp)[0]);return}
      await this.eAtkAsync(u,inR.sort((a,b)=>a.hp-b.hp)[0]);return}
    // Try gate attack if adjacent to ally gate
    const gAtk=this.tryGateAtk(u);
    if(gAtk){await sl(250);return}
    // Try wall climb if adjacent to ally wall
    const wClimb=await this.tryWallClimb(u);
    if(wClimb)return;
    // Move towards closest ally or ally wall
    await this.eMv(u,al);
    if(this.over)return;
    // Attack after move
    await sl(200);
    const postR=this.atkC(u).filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'}).map(c=>this.uAt(c.x,c.y));
    if(postR.length){const kl2=postR.filter(a=>a.hp<=Math.max(1,u.atk-a.def));
      if(kl2.length){await this.eAtkAsync(u,kl2.sort((a,b)=>a.hp-b.hp)[0]);return}
      await this.eAtkAsync(u,postR.sort((a,b)=>a.hp-b.hp)[0]);return}
    // Try gate attack after move
    this.tryGateAtk(u);
    },
  hasAllyWall(){return Object.keys(this.gateHP).some(k=>k.endsWith(',14')&&this.gateHP[k]>0)},
  // Gate attack: enemy hits ally gate (row 14) if adjacent
  tryGateAtk(u){
    for(const[dx,dy]of[[0,1],[0,-1],[-1,0],[1,0]]){
      const nx=u.x+dx,ny=u.y+dy;if(ny!==14||nx<0||nx>=COLS)continue;
      const t=this.ter[ny][nx];if(t!=='gate')continue;
      const k=nx+','+ny;if(!this.gateHP[k]||this.gateHP[k]<=0)continue;
      // Attack gate
      this.gateHP[k]--;
      this.floatT(nx,ny,`성문 피격!`,'damage');this.sfxAtk(u.cls);
      this.vfxSpawn(this.uSX(nx,ny)+UCX,this.uSY(nx,ny)+UCY,{count:12,colors:['#aa8844','#ffcc66','#fff'],shape:'spark',speed:2,spread:12,decay:0.025,size:3});
      if(this.gateHP[k]<=0){
        // Gate destroyed - becomes passable plain
        this.ter[ny][nx]='plain';this.ter[ny][nx]='plain';
        this.floatT(nx,ny,'성문 파괴!','damage');this.screenShake();this.sfxKill();
        this.rTer()}
      else this.rTer();
      return true}return false},
  // Wall climb: enemy uses "ladder" to cross ally wall (row 14)
  async tryWallClimb(u){
    for(const[dx,dy]of[[0,1],[0,-1],[-1,0],[1,0]]){
      const nx=u.x+dx,ny=u.y+dy;if(ny!==14||nx<0||nx>=COLS)continue;
      const t=this.ter[ny][nx];if(t!=='wall')continue;
      // 30% chance to have ladder and climb
      if(Math.random()>0.3)continue;
      // Climb over wall — move to wall tile
      u.x=nx;u.y=ny;this.animU(u.id,nx,ny);
      this.floatT(nx,ny,'🪜 사다리!','heal');this.sfxMove();
      await sl(340);
      this.onBreach(u);
      return true}return false},
  // Track breach count and check defeat
  onBreach(u){
    this.breached++;
    const s=this.cStage;if(!s)return;
    const limit=Math.ceil(s.tot/4);
    this.floatT(u.x,u.y,`돌파 ${this.breached}/${limit}`,'damage');
    if(this.breached>=limit){this.over=true;this.showRes(false,`적 ${this.breached}체가 성벽을 돌파했습니다!`)}},
  async eAtkAsync(a,t){
    if(t.team==='ally')this.scrollToUnit(t);
    await sl(250);
    this.eAtk(a,t);
    await sl(t.hp<=0?500:300)},
  eAtk(a,t){
    const dmg=calcDmg(a,t);
    t.hp=Math.max(0,t.hp-dmg);this.vfxAtk(a,t);this.sfxAtk(a.cls);this.shakeU(t.id);this.floatT(t.x,t.y,`-${dmg}`,'damage');
    if(a.furyBuff>0)this.floatT(a.x,a.y,'광폭!','heal');
    procFury(a,t,this);
    if(t.hp<=0){this.screenShake();this.sfxKill();this.sfxDeath();this.vfxDeath(t);this.deathA(t.id);setTimeout(()=>{this.units=this.units.filter(u=>u.hp>0);this.rUnits()},500)}
    else if(a.hp<=0){this.screenShake();this.sfxDeath();this.vfxDeath(a);this.deathA(a.id);setTimeout(()=>{this.units=this.units.filter(u=>u.hp>0);this.rUnits()},500)}
    else this.rUnits()},
  async eMv(u,al){
    // Defensive AI: 5-cell advance limit from formation position
    const origPos=u.origSpawn||{x:u.x,y:u.y};
    const advLimit=5;
    const advDist=mh(u.x,u.y,origPos.x,origPos.y);
    // If already at advance limit, don't move further
    if(advDist>=advLimit&&!u.isBoss){return}

    const mc=this.eMvC(u);if(!mc.length)return;
    // Filter moves to respect 5-cell limit
    const validMoves=mc.filter(m=>mh(m.x,m.y,origPos.x,origPos.y)<=advLimit||u.isBoss);
    if(!validMoves.length)return;

    let bt=null,bd=Infinity;
    for(const a of al){const d=mh(u.x,u.y,a.x,a.y);if(d<bd){bd=d;bt=a}}

    // Special unit logic: assassins prefer forests
    if(u.cls==='assassin'){
      let bestMove=null,bestScore=-Infinity;
      for(const m of validMoves){
        const t=this.ter[m.y]?this.ter[m.y][m.x]:null;
        let score=0;
        if(t==='forest')score+=50;
        if(bt)score+=(mh(u.x,u.y,bt.x,bt.y)-mh(m.x,m.y,bt.x,bt.y))*10;
        score+=(m.y-u.y)*3;
        if(score>bestScore){bestScore=score;bestMove=m}
      }
      if(bestMove){u.x=bestMove.x;u.y=bestMove.y;this.animU(u.id,bestMove.x,bestMove.y);await sl(340);
        if(bestMove.y===14){this.onBreach(u)};return}
    }

    // Sapper: place traps at current position before moving
    if(u.cls==='sapper'&&!this.traps.find(t=>t.x===u.x&&t.y===u.y)){
      this.traps.push({x:u.x,y:u.y,dmg:15,id:this.traps.length});
      this.floatT(u.x,u.y,'함정 설치','heal')
    }

    // Normal movement: target closest ally or gate
    if(!bt||bd>8){const gateTarget={x:u.x<=4?4:5,y:13};
      let bc2=null,bs2=-Infinity;
      for(const c of validMoves){
        const s=-(mh(c.x,c.y,gateTarget.x,gateTarget.y))*10+(c.y-u.y)*5;
        if(s>bs2){bs2=s;bc2=c}
      }
      if(bc2){u.x=bc2.x;u.y=bc2.y;this.animU(u.id,bc2.x,bc2.y);await sl(340);return}
    }

    let bc=null,bs=-Infinity;
    for(const c of validMoves){
      let s=0;if(bt)s+=(mh(u.x,u.y,bt.x,bt.y)-mh(c.x,c.y,bt.x,bt.y))*10;
      s+=(c.y-u.y)*3;if(s>bs){bs=s;bc=c}
    }

    if(bc){u.x=bc.x;u.y=bc.y;this.animU(u.id,bc.x,bc.y);await sl(340);
      if(bc.y===14){this.onBreach(u)}
    }
  },

  chkEnd(){if(this.over)return;const al=this.alive('ally'),en=this.alive('enemy');
    if(!al.length&&!this.hasAllyWall()){this.over=true;this.showRes(false,'아군이 전멸했습니다.');return}
    // Breach check
    const s=this.cStage;if(s){const limit=Math.ceil(s.tot/4);
      if(this.breached>=limit){this.over=true;this.showRes(false,`적 ${this.breached}체가 성벽을 돌파했습니다!`);return}}
    if(s&&this.eSpwn>=s.tot&&!en.length){this.over=true;this.cleared.add(s.id);this.showRes(true,`STAGE ${s.id} 클리어! (${this.turn}턴)`)}},
});
