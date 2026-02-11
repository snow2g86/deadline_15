// ═══════════════════════════════════════════
//  battle/ai.js — AI turns, movement, tactics
// ═══════════════════════════════════════════
Object.assign(G, {
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
    if(s&&this.turn%s.si===0&&this.eSpwn<s.tot){this.showWv(t('messages.wave_info',{count:s.tot-this.eSpwn}));this.sfxWave();this.spawnW();this.rUnits();await sl(600);this.hideWv()}
    this.alive('enemy').forEach(u=>{
      if(u.stunned>0)u.stunned--;
      if(u.frozen>0)u.frozen--;
      tickBuffs(u);
      if(u.resType==='mana'){u.res=Math.min(u.maxRes,u.res+u.resRec)}
      else if(u.resType==='energy'){
        let rec=u.resRec;
        if(u.cls==='assassin'){const tl=this.ter[u.y]?this.ter[u.y][u.x]:null;if(tl==='forest')rec*=2}
        u.res=Math.min(u.maxRes,u.res+rec);
        if(u.cls==='sapper'&&u.res>=20&&!this.traps.find(tr=>tr.x===u.x&&tr.y===u.y)){
          u.res-=20;
          this.traps.push({x:u.x,y:u.y,dmg:u.atk*2,id:this.traps.length,team:'enemy'});
          this.floatT(u.x,u.y,t('messages.trap_placed'),'heal');
        }
      }
    });this.rUnits();
    this.anim=true;for(const e of[...this.alive('enemy')]){if(this.over)break;await this.eAI(e);await sl(500)}
    this.anim=false;document.getElementById('enemy-banner').classList.remove('show');this.chkEnd();
    if(!this.over){this.turn++;this.phase='player';this.turnFlash('player');this.sfxTurnPlayer();
      this.alive('ally').filter(u=>u.channeling==='shaman_curse').forEach(u=>{
        const enemies=this.alive('enemy');
        if(enemies.length){
          const tgt=enemies[Math.floor(Math.random()*enemies.length)];
          const pct=tgt.isBoss?0.002:0.005;
          const dmg=Math.max(1,Math.round(tgt.mhp*pct));
          tgt.hp=Math.max(0,tgt.hp-dmg);
          this.floatT(tgt.x,tgt.y,`-${dmg}`,'damage');
          this.floatT(tgt.x,tgt.y,t('messages.curse'),'damage');
          this.vfxSpawn(this.uSX(tgt.x,tgt.y)+UCX,this.uSY(tgt.x,tgt.y)+UCY,{count:6,colors:['#9333ea','#581c87','#a855f7'],shape:'spark',speed:2,spread:8,decay:0.03,size:3});
          if(tgt.hp<=0){this.sfxDeath();this.vfxDeath(tgt);this.deathA(tgt.id);this._rmDead();
            setTimeout(()=>{this.rUnits();this.chkEnd()},500)}
        }
      });
      if(this.poisonMists&&this.poisonMists.length){
        this.poisonMists.forEach(pm=>{
          this.alive('enemy').forEach(e=>{
            if(mh(e.x,e.y,pm.cx,pm.cy)<=1){
              const dmg=Math.max(1,Math.round(pm.atk*0.3));
              e.hp=Math.max(0,e.hp-dmg);
              this.floatT(e.x,e.y,`-${dmg}`,'damage');
              this.vfxSpawn(this.uSX(e.x,e.y)+UCX,this.uSY(e.x,e.y)+UCY,{count:4,colors:['#22c55e','#4ade80'],shape:'spark',speed:2,spread:6,decay:0.03,size:3});
              if(e.hp<=0){this.sfxDeath();this.vfxDeath(e);this.deathA(e.id)}
            }
          });
          pm.turns--;
        });
        this.poisonMists=this.poisonMists.filter(pm=>pm.turns>0);
        this._rmDead();this.rUnits();
      }
      this.alive('ally').forEach(u=>{
        if(u.isSummon&&u.summonTurns!==undefined){
          u.summonTurns--;
          if(u.summonTurns<=0){
            const summoner=this.units.find(s=>s.id===u.summonerId&&s.hp>0&&s.skillLv&&s.skillLv['summoner_soulbond']>=1);
            if(summoner){summoner.res=Math.min(summoner.maxRes,summoner.res+40);this.floatT(summoner.x,summoner.y,'+40 MP','heal')}
            this.floatT(u.x,u.y,t('messages.unsummoned'),'damage');
            this.vfxDeath(u);
            setTimeout(()=>{
              this.units=this.units.filter(v=>v.id!==u.id);
              this.rUnits();
            },500);
            return}
        }
        if(u.channeling){
          u.hm=true;u.ha=true;u.waited=true;u.mo=false;
          return}
        u.hm=false;u.ha=false;u.waited=false;u.mo=false;u._spearwallUsed=false;
        if(u._sacrificeTurns>0){u._sacrificeTurns--;if(u._sacrificeTurns<=0){this.units.forEach(v=>{if(v._sacrificeKnight===u.id)v._sacrificeKnight=null});u._sacrificeTarget=null;this.floatT(u.x,u.y,t('messages.knight_sacrifice_end'),'damage')}}
        if(u.stunned>0)u.stunned--;
        if(u.frozen>0)u.frozen--;
        tickBuffs(u);
        if(u.resType==='mana'){u.res=Math.min(u.maxRes,u.res+u.resRec)}
        else if(u.resType==='energy'){
          let rec=u.resRec;
          if(u.cls==='assassin'){const tl=this.ter[u.y]?this.ter[u.y][u.x]:null;if(tl==='forest')rec*=2}
          u.res=Math.min(u.maxRes,u.res+rec)}
        if(u.resType==='fury'&&u.cls==='warrior'&&u.skillLv&&u.skillLv['warrior_bloodthirst']>=1){u.res=Math.min(u.maxRes,u.res+1)}
      });
      this.uUI();this.clrSel();this.rMM()}},
  selectTarget(u,inRange,profile){
    if(!inRange.length)return null;
    if(Math.random()<AI_MISTAKE_CHANCE){
      return inRange[Math.floor(Math.random()*inRange.length)]
    }
    const p=profile.targetPriority;
    if(p==='low_hp'){
      const kl=inRange.filter(a=>a.hp<=Math.max(1,u.atk-a.def));
      if(kl.length)return kl.sort((a,b)=>a.hp-b.hp)[0];
      return inRange.sort((a,b)=>a.hp-b.hp)[0]
    }
    if(p==='nearest'){
      return inRange.sort((a,b)=>mh(u.x,u.y,a.x,a.y)-mh(u.x,u.y,b.x,b.y))[0]
    }
    if(p==='nearest_threat'){
      const o=u.origSpawn||{x:u.x,y:u.y};
      return inRange.sort((a,b)=>mh(o.x,o.y,a.x,a.y)-mh(o.x,o.y,b.x,b.y))[0]
    }
    if(p==='random_weak'){
      const s=[...inRange].sort((a,b)=>a.hp-b.hp);
      const w=s.slice(0,Math.ceil(s.length/2));
      return w[Math.floor(Math.random()*w.length)]
    }
    if(p==='cluster'){
      let bt=null,bn=0;
      for(const tgt of inRange){
        const n=this.alive('ally').filter(a=>a.id!==tgt.id&&mh(tgt.x,tgt.y,a.x,a.y)<=2).length;
        if(n>bn){bn=n;bt=tgt}
      }
      return bt||inRange[0]
    }
    return inRange[Math.floor(Math.random()*inRange.length)]
  },
  async tryUseSkill(u, profile) {
    if (!profile.skillUseProbability || Math.random() > profile.skillUseProbability) return false;
    const al = this.alive('ally');
    if (!al.length) return false;

    if (u.cls === 'warrior' && u.res >= 3) {
      const inR = this.atkC(u)
        .filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'ally' && !isStealthed(v); })
        .map(c => this.uAt(c.x, c.y));
      for (const tgt of inR) {
        const dmg = Math.max(1, Math.round(u.atk * 1.5 - tgt.def));
        if (tgt.hp <= dmg) {
          u.res -= 3;
          tgt.hp = 0;
          this.floatT(u.x, u.y, t('messages.warrior_strike'), 'heal');
          this.screenShake(); this.sfxKill(); this.sfxDeath(); this.vfxDeath(tgt); this.deathA(tgt.id);
          this._rmDead();
          u.ha = true;
          setTimeout(() => { this.rUnits(); }, 500);
          return true;
        }
      }
    }

    if (u.cls === 'brawler' && u.res >= 30) {
      const inR = al.filter(v => mh(u.x, u.y, v.x, v.y) <= 1);
      const highAtk = inR.filter(v => v.atk >= 25 && !v.disarmed);
      if (highAtk.length) {
        const tgt = highAtk[0];
        u.res -= 30;
        tgt.disarmed = 3;
        this.floatT(tgt.x, tgt.y, t('messages.brawler_disarm'), 'damage');
        this.floatT(u.x, u.y, t('messages.brawler_disarm'), 'heal');
        this.sfxAtk(u.cls);
        u.ha = true;
        await sl(200);
        return true;
      }
    }

    if (u.cls === 'mage' && u.res >= 40) {
      let targetCell = null, maxCluster = 0;
      for (let y = u.y - 1; y <= u.y + 1; y++) {
        for (let x = u.x - 1; x <= u.x + 1; x++) {
          if (x === u.x && y === u.y) continue;
          const cnt = al.filter(a => !isStealthed(a) && Math.abs(a.x - x) <= 1 && Math.abs(a.y - y) <= 1).length;
          if (cnt >= 2 && cnt > maxCluster) { maxCluster = cnt; targetCell = { x, y }; }
        }
      }
      if (targetCell) {
        u.res -= 40;
        for (let y = targetCell.y - 1; y <= targetCell.y + 1; y++) {
          for (let x = targetCell.x - 1; x <= targetCell.x + 1; x++) {
            const tgt = this.uAt(x, y);
            if (tgt && tgt.team === 'ally' && !isStealthed(tgt)) {
              const dmg = calcDmg(u, tgt);
              tgt.hp = Math.max(0, tgt.hp - dmg);
              this.floatT(tgt.x, tgt.y, `-${dmg}`, 'damage');
              this.vfxSpawn(this.uSX(tgt.x, tgt.y) + UCX, this.uSY(tgt.x, tgt.y) + UCY,
                { count: 8, colors: ['#ff6600', '#ffaa00', '#ffff00'], shape: 'spark',
                  speed: 3, spread: 10, decay: 0.03, size: 4 });
              if (tgt.hp <= 0) { this.screenShake(); this.sfxDeath(); this.vfxDeath(tgt); this.deathA(tgt.id); this._rmDead(); }
            }
          }
        }
        this.floatT(u.x, u.y, t('messages.mage_fireball'), 'heal');
        this.sfxAtk(u.cls);
        u.ha = true;
        await sl(300);
        this._rmDead();
        this.rUnits();
        return true;
      }
    }

    return false;
  },
  async eAI(u){const al=this.alive('ally');if(!al.length&&!this.hasAllyWall())return;
    const profile=AI_PROFILES[u.cls]||AI_PROFILES.novice;
    if(profile.avoidCombat&&u.hp>u.mhp*0.7){
      await this.eMv(u,al);return
    }
    const inR=this.atkC(u).filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&!isStealthed(v)}).map(c=>this.uAt(c.x,c.y));
    if(inR.length&&profile.targetPriority!=='never'){
      if(await this.tryUseSkill(u,profile)){return}
      const target=this.selectTarget(u,inR,profile);
      if(target){await this.eAtkAsync(u,target);return}
    }
    const gAtk=this.tryGateAtk(u);
    if(gAtk){await sl(250);return}
    const wClimb=await this.tryWallClimb(u);
    if(wClimb)return;
    await this.eMv(u,al);
    if(this.over)return;
    if(profile.avoidCombat&&u.hp>u.mhp*0.7)return;
    await sl(200);
    const postR=this.atkC(u).filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&!isStealthed(v)}).map(c=>this.uAt(c.x,c.y));
    if(postR.length&&profile.targetPriority!=='never'){
      if(await this.tryUseSkill(u,profile)){return}
      const target=this.selectTarget(u,postR,profile);
      if(target){await this.eAtkAsync(u,target);return}
    }
    this.tryGateAtk(u);
    },
  hasAllyWall(){return Object.keys(this.gateHP).some(k=>k.endsWith(',14')&&this.gateHP[k]>0)},
  tryGateAtk(u){
    for(const[dx,dy]of[[0,1],[0,-1],[-1,0],[1,0]]){
      const nx=u.x+dx,ny=u.y+dy;if(ny!==14||nx<0||nx>=COLS)continue;
      const tr=this.ter[ny][nx];if(tr!=='gate')continue;
      const k=nx+','+ny;if(!this.gateHP[k]||this.gateHP[k]<=0)continue;
      this.gateHP[k]--;
      this.floatT(nx,ny,t('messages.gate_hit'),'damage');this.sfxAtk(u.cls);
      this.vfxSpawn(this.uSX(nx,ny)+UCX,this.uSY(nx,ny)+UCY,{count:12,colors:['#aa8844','#ffcc66','#fff'],shape:'spark',speed:2,spread:12,decay:0.025,size:3});
      if(this.gateHP[k]<=0){
        this.ter[ny][nx]='plain';
        this.floatT(nx,ny,t('messages.gate_destroyed'),'damage');this.screenShake();this.sfxKill();
        this.rTer()}
      else this.rTer();
      return true}return false},
  async tryWallClimb(u){
    for(const[dx,dy]of[[0,1],[0,-1],[-1,0],[1,0]]){
      const nx=u.x+dx,ny=u.y+dy;if(ny!==14||nx<0||nx>=COLS)continue;
      const tr=this.ter[ny][nx];if(tr!=='wall')continue;
      if(Math.random()>0.3)continue;
      this._mvU(u,nx,ny);
      this.floatT(nx,ny,t('messages.ladder'),'heal');this.sfxMove();
      await sl(340);
      this.onBreach(u);
      return true}return false},
  onBreach(u){
    this.breached++;
    const s=this.cStage;if(!s)return;
    const limit=Math.ceil(s.tot/4);
    this.floatT(u.x,u.y,t('messages.breach')+` ${this.breached}/${limit}`,'damage');
    if(this.breached>=limit){this.over=true;this.showRes(false,t('messages.enemy_breached',{count:this.breached}))}},
  async eAtkAsync(a,tgt){
    if(tgt.team==='ally')this.scrollToUnit(tgt);
    await sl(250);
    this.eAtk(a,tgt);
    await sl(tgt.hp<=0?500:300)},
  eAtk(a,tgt){
    const dmg=calcDmg(a,tgt);
    const dtgt=tgt.team==='ally'?applyDmgToAlly(tgt,dmg,this):(tgt.hp=Math.max(0,tgt.hp-dmg),tgt);
    this.vfxAtk(a,tgt);this.sfxAtk(a.cls);this.shakeU(dtgt.id);this.floatT(dtgt.x,dtgt.y,`-${dmg}`,'damage');
    if(a.furyBuff>0)this.floatT(a.x,a.y,t('messages.fury_buff'),'heal');
    procFury(a,tgt,this);
    if(tgt.hp>0&&a.hp>0&&mh(tgt.x,tgt.y,a.x,a.y)<=tgt.range&&!(tgt.stunned>0)&&!(tgt.frozen>0)){
      const cdmg=calcDmg(tgt,a);a.hp=Math.max(0,a.hp-cdmg);this.vfxAtk(tgt,a);this.sfxAtk(tgt.cls);this.shakeU(a.id);this.floatT(a.x,a.y,`-${cdmg}`,'damage');procFury(tgt,a,this);
    }
    if(tgt.hp>0&&a.hp>0&&tgt.skillLv&&tgt.skillLv['brawler_counter']>=1&&mh(tgt.x,tgt.y,a.x,a.y)<=tgt.range&&Math.random()<0.3){
      const cdmg=Math.max(1,Math.round(tgt.atk*0.5)-a.def);a.hp=Math.max(0,a.hp-cdmg);
      this.vfxAtk(tgt,a);this.sfxAtk(tgt.cls);this.shakeU(a.id);this.floatT(a.x,a.y,`-${cdmg}`,'damage');this.floatT(tgt.x,tgt.y,t('messages.brawler_counter'),'heal');
    }
    if(dtgt.hp<=0){if(dtgt===tgt){this.screenShake();this.sfxKill();this.sfxDeath();this.vfxDeath(tgt);this.deathA(tgt.id);this._rmDead()}setTimeout(()=>{this.rUnits()},500)}
    else if(a.hp<=0){this.screenShake();this.sfxDeath();this.vfxDeath(a);this.deathA(a.id);this._rmDead();setTimeout(()=>{this.rUnits()},500)}
    else this.rUnits()},
  async eMv(u,al){
    if(u._rootedTurns>0){this.floatT(u.x,u.y,t('messages.rooted'),'debuff');return}
    const origPos=u.origSpawn||{x:u.x,y:u.y};
    const profile=AI_PROFILES[u.cls]||AI_PROFILES.novice;
    const hpPct=u.hp/u.mhp;
    const shouldRetreat=hpPct<profile.retreatThreshold&&Math.random()<0.3;
    if(shouldRetreat&&!u.isBoss){
      const mc=this.eMvC(u);if(!mc.length)return;
      let bestMove=null,bestDist=Infinity;
      for(const m of mc){const d=mh(m.x,m.y,origPos.x,origPos.y);if(d<bestDist){bestDist=d;bestMove=m}}
      if(bestMove&&mh(bestMove.x,bestMove.y,origPos.x,origPos.y)<mh(u.x,u.y,origPos.x,origPos.y)){
        this._mvU(u,bestMove.x,bestMove.y);
        this.floatT(u.x,u.y,t('messages.retreat'),'damage');await sl(340);
        this.chkTrap(u);this._chkSpearwall(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);this._rmDead();setTimeout(()=>{this.rUnits()},500)}
        return
      }
    }
    let advLimit = this.cStage?.style === 'defense' ? 15 : 5;
    if(profile.style==='defensive') advLimit = this.cStage?.style === 'defense' ? 12 : 3;
    if(profile.style==='support') advLimit = this.cStage?.style === 'defense' ? 10 : 2;
    const advDist=mh(u.x,u.y,origPos.x,origPos.y);

    if(this.cStage?.style === 'defense' && !u.isBoss) {
      const allies = this.alive('enemy').filter(e => e.id !== u.id && !e.isBoss);
      if(allies.length > 0) {
        const nearestAllyDist = Math.min(...allies.map(a => mh(u.x, u.y, a.x, a.y)));
        const avgAllyY = allies.reduce((sum, a) => sum + a.y, 0) / allies.length;
        if(u.y > avgAllyY + 3) {
          return;
        }
        if(nearestAllyDist > 5) {
          advLimit = Math.min(advLimit, advDist + 2);
        }
      }
    }

    if(advDist>=advLimit&&!u.isBoss){return}

    const mc=this.eMvC(u);if(!mc.length)return;
    const validMoves=mc.filter(m=>mh(m.x,m.y,origPos.x,origPos.y)<=advLimit||u.isBoss);
    if(!validMoves.length)return;

    let bt=null,bd=Infinity;
    for(const a of al){if(isStealthed(a))continue;const d=mh(u.x,u.y,a.x,a.y);if(d<bd){bd=d;bt=a}}

    if(u.cls==='assassin'){
      let bestMove=null,bestScore=-Infinity;
      for(const m of validMoves){
        const tr=this.ter[m.y]?this.ter[m.y][m.x]:null;
        let score=0;
        if(tr==='forest')score+=50;
        if(bt)score+=(mh(u.x,u.y,bt.x,bt.y)-mh(m.x,m.y,bt.x,bt.y))*10;
        score+=(m.y-u.y)*3;
        if(score>bestScore){bestScore=score;bestMove=m}
      }
      if(bestMove){this._mvU(u,bestMove.x,bestMove.y);await sl(340);
        this.chkTrap(u);this._chkSpearwall(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this._rmDead();this.rUnits()},500);return}
        if(bestMove.y===14){this.onBreach(u)};return}
    }

    if(profile.guardMode&&!u.isBoss){
      const allies=this.alive('enemy').filter(e=>e.id!==u.id);
      if(allies.length){
        let bestMove=null,bestScore=-Infinity;
        for(const m of validMoves){
          let score=0;
          const avgAllyDist=allies.reduce((sum,a)=>sum+mh(m.x,m.y,a.x,a.y),0)/allies.length;
          score-=avgAllyDist*5;
          score-=mh(m.x,m.y,origPos.x,origPos.y)*profile.advanceBonus;
          if(score>bestScore){bestScore=score;bestMove=m}
        }
        if(bestMove){this._mvU(u,bestMove.x,bestMove.y);await sl(340);
          this.chkTrap(u);this._chkSpearwall(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this._rmDead();this.rUnits()},500);return}
          return
        }
      }
    }

    let cbt=null,cbd=Infinity;
    for(const a of al){if(isStealthed(a))continue;const d=mh(u.x,u.y,a.x,a.y);if(d<cbd){cbd=d;cbt=a}}
    if(profile.keepDistance&&cbt&&mh(u.x,u.y,cbt.x,cbt.y)<=2){
      let bestMove=null,bestDist=0;
      for(const m of validMoves){
        const dist=mh(m.x,m.y,cbt.x,cbt.y);
        if(dist>bestDist&&dist<=u.range){bestDist=dist;bestMove=m}
      }
      if(bestMove&&bestDist>mh(u.x,u.y,cbt.x,cbt.y)){
        this._mvU(u,bestMove.x,bestMove.y);await sl(340);
        this.chkTrap(u);this._chkSpearwall(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this._rmDead();this.rUnits()},500);return}
        return
      }
    }

    if(!bt||bd>8){const gateTarget={x:u.x<=4?4:5,y:13};
      let bc2=null,bs2=-Infinity;
      for(const c of validMoves){
        let s=-(mh(c.x,c.y,gateTarget.x,gateTarget.y))*10+(c.y-u.y)*(5+profile.advanceBonus);
        if(s>bs2){bs2=s;bc2=c}
      }
      if(bc2){this._mvU(u,bc2.x,bc2.y);await sl(340);
        this.chkTrap(u);this._chkSpearwall(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this._rmDead();this.rUnits()},500);return}
        return}
    }

    let bc=null,bs=-Infinity;
    for(const c of validMoves){
      let s=0;if(bt)s+=(mh(u.x,u.y,bt.x,bt.y)-mh(c.x,c.y,bt.x,bt.y))*10;
      s+=(c.y-u.y)*(3+profile.advanceBonus*0.3);if(s>bs){bs=s;bc=c}
    }

    if(bc){this._mvU(u,bc.x,bc.y);await sl(340);
      this.chkTrap(u);this._chkSpearwall(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this._rmDead();this.rUnits()},500);return}
      if(bc.y===14){this.onBreach(u)}
    }
  },

  chkEnd(){if(this.over)return;const al=this.alive('ally'),en=this.alive('enemy');
    this.units.filter(u=>u.cls==='summoner'&&u.hp<=0).forEach(deadSummoner=>{
      const summons=this.units.filter(s=>s.isSummon&&s.summonerId===deadSummoner.id);
      summons.forEach(s=>{
        this.floatT(s.x,s.y,t('messages.unsummoned'),'damage');
        this.vfxDeath(s);
      });
      this.units=this.units.filter(v=>!(v.isSummon&&v.summonerId===deadSummoner.id));
    });
    if(!al.length&&!this.hasAllyWall()){this.over=true;this.showRes(false,t('messages.all_defeated'));return}
    const s=this.cStage;if(s){const limit=Math.ceil(s.tot/4);
      if(this.breached>=limit){this.over=true;this.showRes(false,t('messages.enemy_breached',{count:this.breached}));return}}
    if(s&&this.eSpwn>=s.tot&&!en.length){this.over=true;this.cleared.add(s.id);this.showRes(true,t('messages.stage_clear',{stage_id:s.id,turn:this.turn}))}},
});
