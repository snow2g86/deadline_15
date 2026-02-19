// ═══════════════════════════════════════════
//  battle/ai.js — AI turns, movement, tactics
// ═══════════════════════════════════════════
Object.assign(G, {
  // 개별 유닛 행동 완료 후 호출
  endUnitTurn(u) {
    u.actionPow -= 5;
    u.ha = false;
    u.hm = false;
    u.mo = false;

    // 자원 회복
    if (u.resType === 'mana') {
      u.res = Math.min(u.maxRes, u.res + u.resRec);
    } else if (u.resType === 'energy') {
      let rec = u.resRec;
      if (u.cls === 'assassin') {
        const tl = this.ter[u.y] ? this.ter[u.y][u.x] : null;
        if (tl === 'forest') rec *= 2;
      }
      u.res = Math.min(u.maxRes, u.res + rec);
    }

    // 버프 틱
    tickBuffs(u);

    // stunned/frozen 감소
    if (u.stunned > 0) u.stunned--;
    if (u.frozen > 0) u.frozen--;

    // 소환수 턴 감소 및 소멸
    if (u.isSummon && u.summonTurns !== undefined) {
      u.summonTurns--;
      if (u._empowerTurns > 0) u._empowerTurns--;
      if (u.summonTurns <= 0) {
        u.hp = 0;
        this.floatT(u.x, u.y, t('messages.unsummoned'), 'damage');
        this.vfxDeath(u); this.deathA(u.id);
        this._rmDead();
        setTimeout(() => this.rUnits(), 500);
      }
    }

    // 게임 종료 체크
    this.chkEnd();

    // 다음 행동으로 이동
    this.actCount++;
    this.nextAction();
  },

  // 다음 유닛 행동 처리
  async nextAction() {
    if (this.over) return;

    const stage = this.cStage;
    // 웨이브 스폰 체크
    if (stage && this.eSpwn < stage.tot) {
      const interval = stage.si * 2;
      if (this.actCount > 0 && this.actCount % interval === 0) {
        this.showWv(t('messages.wave_info', { count: stage.tot - this.eSpwn }));
        this.sfxWave();
        this.spawnW();
        this.rUnits();
        await sl(600);
        this.hideWv();
      }
    }

    const nextU = this.advanceTick();
    if (!nextU) return;

    this.curUnit = nextU;
    this.clrSel();
    this.rTurnOrder(); // 순서 패널 갱신

    if (nextU.team === 'ally') {
      this.phase = 'player';
      this.turnFlash('player');
      this.uUI();

      // stunned 유닛이면 자동 스킵
      if (nextU.stunned > 0) {
        setTimeout(() => this.endUnitTurn(nextU), 300);
      } else {
        // 행동 가능한 아군 자동 선택
        setTimeout(() => this.selU(nextU), 100);
      }
    } else {
      this.phase = 'enemy';
      this.uUI();
      this.anim = true;
      setTimeout(async () => {
        if (!this.over) await this.eAI(nextU);
        this.anim = false;
        this.endUnitTurn(nextU);
      }, 300);
    }
  },

  _autoSave(){try{saveBattle({stage:this.cStage,party:this.party,practiceMode:this.practiceMode,ter:this.ter,turn:this.turn,eSpwn:this.eSpwn,eQ:this.eQ,breached:this.breached,gateHP:this.gateHP,wallHP:this.wallHP,nid:this.nid,units:this.units.map(u=>{const o={...u};delete o._el;return o}),battleExp:this.battleExp,allyPos:this.allyPos,_killCount:this._killCount,_killExpPool:this._killExpPool,_deadAllyUids:this._deadAllyUids,_siegeItems:this._siegeItems,_siegeInvIndices:this._siegeInvIndices,_battlePotions:this._battlePotions,_battlePotionIndices:this._battlePotionIndices})}catch(e){}},
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
  // 사거리 내 아군(적 입장) 탐색 헬퍼
  _visibleAllies(u) {
    return this.atkC(u).filter(c => {
      const v = this.uAt(c.x, c.y);
      return v && v.team === 'ally' && !isStealthed(v);
    }).map(c => this.uAt(c.x, c.y));
  },
  // 공격 시도 헬퍼
  async _tryAttack(u, targets, profile) {
    if (!targets.length || profile.targetPriority === 'never') return false;
    if (await this.tryUseSkill(u, profile)) return true;
    const target = this.selectTarget(u, targets, profile);
    if (target) { await this.eAtkAsync(u, target); return true; }
    return false;
  },
  async eAI(u) {
    const al = this.alive('ally');
    if (!al.length && !this.hasAllyWall()) return;
    const profile = AI_PROFILES[u.cls] || AI_PROFILES.novice;

    if (profile.avoidCombat && u.hp > u.mhp * 0.7) { await this.eMv(u, al); return; }

    // 이동 전 공격 시도
    if (await this._tryAttack(u, this._visibleAllies(u), profile)) return;

    if (this.tryGateAtk(u)) { await sl(250); return; }
    if (await this.tryWallClimb(u)) return;

    await this.eMv(u, al);
    if (this.over) return;
    if (profile.avoidCombat && u.hp > u.mhp * 0.7) return;

    // 이동 후 공격 시도
    await sl(200);
    if (await this._tryAttack(u, this._visibleAllies(u), profile)) return;

    // 이동 후에도 공격 불가 시에만 공성아이템 시도
    if (await this.trySiegeItemUse(u)) return;
    this.tryGateAtk(u);
  },
  analyzeSituation(u){
    const al=this.alive('ally');
    const hpPct=u.hp/u.mhp;
    const nearbyAllies=al.filter(a=>!isStealthed(a)&&mh(u.x,u.y,a.x,a.y)<=2).length;
    const moveOptions=this.eMvC(u).length;
    let nearbyTerrain=0;
    for(const[dx,dy]of[[0,-1],[0,1],[-1,0],[1,0]]){const nx=u.x+dx,ny=u.y+dy;if(nx>=0&&nx<COLS&&ny>=0&&ny<ROWS){const tile=this.ter[ny][nx];if(tile==='wall'||tile==='gate'||tile==='rock')nearbyTerrain++}}
    let situationType='safe';
    if(hpPct<0.3){situationType='weakened'}
    else if(nearbyAllies>=3){situationType='surrounded'}
    else if(moveOptions===0){situationType='blocked'}
    else if(nearbyAllies>0){situationType='distant'}
    const severity=(1-hpPct)*0.4+(nearbyAllies/5)*0.4+(1-moveOptions/4)*0.2;
    return{type:situationType,severity:Math.max(0,Math.min(1,severity)),blockCount:4-moveOptions,nearbyAllies,hpPercent:hpPct,nearbyTerrain}
  },
  selectSiegeItem(u,situation){
    if(!u.siegeItems||!u.siegeItems.length)return null;
    const available=u.siegeItems.filter(i=>i.cooldown===0);
    if(!available.length)return null;
    const priorityMap={
      'blocked':{'bomb':90,'ladder':70,'detour':80},
      'distant':{'detour':80,'bomb':60,'ladder':50},
      'weakened':{'shield':100,'evasion':80},
      'surrounded':{'evasion':90,'bomb':70,'detour':60},
      'safe':{}
    };
    const priors=priorityMap[situation.type]||{};
    let best=null,bestScore=-1;
    for(const item of available){
      const score=(priors[item.type]||0)+(Math.random()*10);
      if(score>bestScore){bestScore=score;best=item}
    }
    return best
  },
  _siegeBomb(u){
    let best=null,bestD=Infinity;
    for(let r=0;r<ROWS;r++)for(let c=0;c<COLS;c++){
      const d=mh(u.x,u.y,c,r);
      if(d<1||d>3)continue;
      const tile=this.ter[r][c];
      if(tile==='wall'||tile==='gate'||tile==='rock'){if(d<bestD){bestD=d;best={x:c,y:r}}}
    }
    if(!best)return false;
    this.ter[best.y][best.x]='plain';
    const wk=best.x+','+best.y;
    if(this.wallHP[wk])this.wallHP[wk]=0;
    if(this.gateHP[wk])this.gateHP[wk]=0;
    this.floatT(best.x,best.y,t('messages.wall_destroyed'),'damage');
    this.vfxSiege('siege_bomb',best.x,best.y);this.sfxAtk(u.cls);this.screenShake();this.rTer();
    return true;
  },
  async useSiegeItem(u,item){
    try{
      const actions={
        bomb:()=>this._siegeBomb(u),
        shield:()=>{u._siegeShield=3;this.floatT(u.x,u.y,'🛡️','heal');this.sfxAtk(u.cls);return true},
        evasion:()=>{u._siegeEvasion=1;this.floatT(u.x,u.y,'⚡','heal');this.sfxAtk(u.cls);return true}
      };
      const fn=actions[item.type];
      if(fn){
        const success=await fn();
        if(success){
          item.cooldown=3;
          return true
        }
      }
    }catch(e){}
    return false
  },
  async trySiegeItemUse(u){
    if(!u.siegeItems||!u.siegeItems.length)return false;
    const situation=this.analyzeSituation(u);
    // blocked: 이동 불가 시에만 공성아이템 사용
    if(situation.type==='blocked'){const item=this.selectSiegeItem(u,situation);if(!item)return false;return await this.useSiegeItem(u,item)}
    // 위험도 낮으면 사용 안함
    if(situation.severity<0.3)return false;
    const item=this.selectSiegeItem(u,situation);
    if(!item)return false;
    return await this.useSiegeItem(u,item)
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
    // 공격 애니메이션은 vfxAtk에서 처리됨 (showAttackAnim 호출)
    await this.eAtk(a,tgt);
    await sl(tgt.hp<=0?500:300)},
  async eAtk(a,tgt){
    if(a._siegeEvasion>0&&Math.random()<0.3){a._siegeEvasion--;this.floatT(a.x,a.y,t('messages.evasion'),'heal');return}
    const bCounter=tgt.skillLv&&tgt.skillLv['brawler_counter']>=1&&!(tgt.stunned>0)&&!(tgt.frozen>0)&&mh(tgt.x,tgt.y,a.x,a.y)<=tgt.range&&Math.random()<0.3;
    let dtgt=tgt;
    if(bCounter){
      await sl(420);
      const cdmg=Math.max(1,Math.round(tgt.atk*0.5)-a.def);a.hp=Math.max(0,a.hp-cdmg);
      this.vfxAtk(tgt,a);this.sfxAtk(tgt.cls);this.shakeU(a.id);this.floatT(a.x,a.y,`-${cdmg}`,'damage');this.floatT(tgt.x,tgt.y,t('messages.brawler_counter'),'heal');
    }else{
      let dmg=calcDmg(a,tgt);
      if(a._siegeShield>0){dmg=Math.max(1,Math.round(dmg*0.5));this.floatT(a.x,a.y,'🛡️','heal')}
      dtgt=tgt.team==='ally'?applyDmgToAlly(tgt,dmg,this):(tgt.hp=Math.max(0,tgt.hp-dmg),tgt);
      this.vfxAtk(a,tgt);this.sfxAtk(a.cls);this.shakeU(dtgt.id);this.floatT(dtgt.x,dtgt.y,`-${dmg}`,'damage');
      if(a.furyBuff>0)this.floatT(a.x,a.y,t('messages.fury_buff'),'heal');
      procFury(a,tgt,this);
      if(tgt.hp>0&&a.hp>0&&mh(tgt.x,tgt.y,a.x,a.y)<=tgt.range&&!(tgt.stunned>0)&&!(tgt.frozen>0)){
        await sl(420);
        const cdmg=calcDmg(tgt,a);a.hp=Math.max(0,a.hp-cdmg);this.vfxAtk(tgt,a);this.sfxAtk(tgt.cls);this.shakeU(a.id);this.floatT(a.x,a.y,`-${cdmg}`,'damage');procFury(tgt,a,this);
      }
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
    if(s&&this.eSpwn>=s.tot&&!en.length){this.over=true;this.showRes(true,t('messages.stage_clear',{stage_id:s.id,turn:this.turn}))}},
});
