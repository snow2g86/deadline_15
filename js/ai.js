// ═══════════════════════════════════════════
//  AI Behavior Profiles — 클래스별 행동 특성
// ═══════════════════════════════════════════
const AI_PROFILES = {
  // Aggressive (공격적) - 5개
  warrior: {
    style: 'aggressive',
    targetPriority: 'low_hp',
    advanceBonus: 10,
    retreatThreshold: 0.2,
    skillUseProbability: 0.7
  },
  assassin: {
    style: 'aggressive',
    targetPriority: 'low_hp',
    advanceBonus: 15,
    retreatThreshold: 0.25,
    skillUseProbability: 0.8
  },
  brawler: {
    style: 'aggressive',
    targetPriority: 'random_weak',
    advanceBonus: 12,
    retreatThreshold: 0.15,
    skillUseProbability: 0.6
  },
  mage: {
    style: 'aggressive',
    targetPriority: 'cluster',
    advanceBonus: 5,
    retreatThreshold: 0.4,
    skillUseProbability: 0.75,
    keepDistance: true
  },
  sapper: {
    style: 'aggressive',
    targetPriority: 'nearest',
    advanceBonus: 8,
    retreatThreshold: 0.3,
    skillUseProbability: 0.9,
    trapPlacement: true
  },
  // Defensive (방어적) - 2개
  knight: {
    style: 'defensive',
    targetPriority: 'nearest_threat',
    advanceBonus: -5,
    retreatThreshold: 0.1,
    skillUseProbability: 0.5,
    guardMode: true
  },
  lancer: {
    style: 'defensive',
    targetPriority: 'nearest_threat',
    advanceBonus: -3,
    retreatThreshold: 0.15,
    skillUseProbability: 0.65,
    guardMode: true
  },
  // Support (지원) - 2개
  priest: {
    style: 'support',
    targetPriority: 'never',
    advanceBonus: -10,
    retreatThreshold: 0.5,
    skillUseProbability: 0.0,
    keepDistance: true,
    avoidCombat: true
  },
  shaman: {
    style: 'support',
    targetPriority: 'random',
    advanceBonus: -8,
    retreatThreshold: 0.45,
    skillUseProbability: 0.0,
    keepDistance: true,
    avoidCombat: true
  },
  // Balanced (균형) - 3개
  novice: {
    style: 'balanced',
    targetPriority: 'nearest',
    advanceBonus: 0,
    retreatThreshold: 0.3,
    skillUseProbability: 0.4
  },
  archer: {
    style: 'balanced',
    targetPriority: 'low_hp',
    advanceBonus: 2,
    retreatThreshold: 0.35,
    skillUseProbability: 0.5,
    keepDistance: true
  },
  summoner: {
    style: 'balanced',
    targetPriority: 'random',
    advanceBonus: 0,
    retreatThreshold: 0.4,
    skillUseProbability: 0.0,
    keepDistance: true
  }
};

const AI_MISTAKE_CHANCE = 0.3; // 30% 실수 확률

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
    if(s&&this.turn%s.si===0&&this.eSpwn<s.tot){this.showWv(t('messages.wave_info',{count:s.tot-this.eSpwn}));this.sfxWave();this.spawnW();this.rUnits();await sl(600);this.hideWv()}
    // Enemy resource recovery
    this.alive('enemy').forEach(u=>{
      if(u.stunned>0)u.stunned--;
      tickBuffs(u);
      if(u.resType==='mana'){u.res=Math.min(u.maxRes,u.res+u.resRec)}
      else if(u.resType==='energy'){
        let rec=u.resRec;
        if(u.cls==='assassin'){const t=this.ter[u.y]?this.ter[u.y][u.x]:null;if(t==='forest')rec*=2}
        u.res=Math.min(u.maxRes,u.res+rec);
        // Sapper: place trap if energy >= 20 (spend 20)
        if(u.cls==='sapper'&&u.res>=20&&!this.traps.find(t=>t.x===u.x&&t.y===u.y)){
          u.res-=20;
          this.traps.push({x:u.x,y:u.y,dmg:u.atk*2,id:this.traps.length,team:'enemy'});
          this.floatT(u.x,u.y,t('messages.trap_placed'),'heal');
        }
      }
    });this.rUnits();
    this.anim=true;for(const e of[...this.alive('enemy')]){if(this.over)break;await this.eAI(e);await sl(500)}
    this.anim=false;document.getElementById('enemy-banner').classList.remove('show');this.chkEnd();
    if(!this.over){this.turn++;this.phase='player';this.turnFlash('player');this.sfxTurnPlayer();
      // 채널링 효과 처리 (쇠약의 저주: 적 1명에게 최대HP% 피해)
      this.alive('ally').filter(u=>u.channeling==='shaman_curse').forEach(u=>{
        const enemies=this.alive('enemy');
        if(enemies.length){
          const t=enemies[Math.floor(Math.random()*enemies.length)];
          const pct=t.isBoss?0.002:0.005;
          const dmg=Math.max(1,Math.round(t.mhp*pct));
          t.hp=Math.max(0,t.hp-dmg);
          this.floatT(t.x,t.y,`-${dmg}`,'damage');
          this.floatT(t.x,t.y,t('messages.curse'),'damage');
          this.vfxSpawn(this.uSX(t.x,t.y)+UCX,this.uSY(t.x,t.y)+UCY,{count:6,colors:['#9333ea','#581c87','#a855f7'],shape:'spark',speed:2,spread:8,decay:0.03,size:3});
          if(t.hp<=0){this.sfxDeath();this.vfxDeath(t);this.deathA(t.id);this.units=this.units.filter(v=>v.hp>0);
            setTimeout(()=>{this.rUnits();this.chkEnd()},500)}
        }
      });
      this.alive('ally').forEach(u=>{
        // 소환수 턴 관리
        if(u.isSummon&&u.summonTurns!==undefined){
          u.summonTurns--;
          if(u.summonTurns<=0){
            this.floatT(u.x,u.y,t('messages.unsummoned'),'damage');
            this.vfxDeath(u);
            setTimeout(()=>{
              this.units=this.units.filter(v=>v.id!==u.id);
              this.rUnits();
            },500);
            return}
        }
        // 채널링 유닛: 이동/행동 불가, 자원 회복 없음
        if(u.channeling){
          u.hm=true;u.ha=true;u.waited=true;u.mo=false;
          return}
        u.hm=false;u.ha=false;u.waited=false;u.mo=false;
        // Stunned recovery
        if(u.stunned>0)u.stunned--;
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
      this.uUI();this.clrSel();this.rMM()}},
  // ─── 타겟 선택 (클래스별 우선순위) ────
  selectTarget(u,inRange,profile){
    if(!inRange.length)return null;
    // 30% 확률로 실수 (랜덤 선택)
    if(Math.random()<AI_MISTAKE_CHANCE){
      return inRange[Math.floor(Math.random()*inRange.length)]
    }
    const p=profile.targetPriority;
    // low_hp: 킬 가능 대상 우선
    if(p==='low_hp'){
      const kl=inRange.filter(a=>a.hp<=Math.max(1,u.atk-a.def));
      if(kl.length)return kl.sort((a,b)=>a.hp-b.hp)[0];
      return inRange.sort((a,b)=>a.hp-b.hp)[0]
    }
    // nearest: 가장 가까운 적
    if(p==='nearest'){
      return inRange.sort((a,b)=>mh(u.x,u.y,a.x,a.y)-mh(u.x,u.y,b.x,b.y))[0]
    }
    // nearest_threat: 진형에 가까운 적
    if(p==='nearest_threat'){
      const o=u.origSpawn||{x:u.x,y:u.y};
      return inRange.sort((a,b)=>mh(o.x,o.y,a.x,a.y)-mh(o.x,o.y,b.x,b.y))[0]
    }
    // random_weak: 약한 50% 중 랜덤
    if(p==='random_weak'){
      const s=[...inRange].sort((a,b)=>a.hp-b.hp);
      const w=s.slice(0,Math.ceil(s.length/2));
      return w[Math.floor(Math.random()*w.length)]
    }
    // cluster: 뭉친 적들 선호 (3×3 범위)
    if(p==='cluster'){
      let bt=null,bn=0;
      for(const t of inRange){
        const n=this.alive('ally').filter(a=>a.id!==t.id&&mh(t.x,t.y,a.x,a.y)<=2).length;
        if(n>bn){bn=n;bt=t}
      }
      return bt||inRange[0]
    }
    // random, never: 랜덤 또는 회피
    return inRange[Math.floor(Math.random()*inRange.length)]
  },
  // ─── 스킬 자동 사용 (조건 만족 시) ────
  async tryUseSkill(u, profile) {
    if (!profile.skillUseProbability || Math.random() > profile.skillUseProbability) return false;
    const al = this.alive('ally');
    if (!al.length) return false;

    // Warrior 강타: 분노 3+ && 킬각 있음
    if (u.cls === 'warrior' && u.res >= 3) {
      const inR = this.atkC(u)
        .filter(c => { const v = this.uAt(c.x, c.y); return v && v.team === 'ally' && !isStealthed(v); })
        .map(c => this.uAt(c.x, c.y));
      for (const t of inR) {
        const dmg = Math.max(1, Math.round(u.atk * 1.5 - t.def));
        if (t.hp <= dmg) {
          u.res -= 3;
          t.hp = 0;
          this.floatT(u.x, u.y, t('messages.warrior_strike'), 'heal');
          this.screenShake(); this.sfxKill(); this.sfxDeath(); this.vfxDeath(t); this.deathA(t.id);
          this.units = this.units.filter(v => v.hp > 0);
          u.ha = true; // 행동 완료
          setTimeout(() => { this.rUnits(); }, 500);
          return true;
        }
      }
    }

    // Brawler 무장해제: 에너지 30+ && 고공격력 적(25+) 인접
    if (u.cls === 'brawler' && u.res >= 30) {
      const inR = al.filter(t => mh(u.x, u.y, t.x, t.y) <= 1);
      const highAtk = inR.filter(t => t.atk >= 25 && !t.disarmed);
      if (highAtk.length) {
        const t = highAtk[0];
        u.res -= 30;
        t.disarmed = 3;
        this.floatT(t.x, t.y, t('messages.brawler_disarm'), 'damage');
        this.floatT(u.x, u.y, t('messages.brawler_disarm'), 'heal');
        this.sfxAtk(u.cls);
        u.ha = true; // 행동 완료
        await sl(200);
        return true;
      }
    }

    // Mage 화염폭발: 마나 40+ && 3x3 범위 적 2개+
    if (u.cls === 'mage' && u.res >= 40) {
      let targetCell = null, maxCluster = 0;
      for (let y = u.y - 1; y <= u.y + 1; y++) {
        for (let x = u.x - 1; x <= u.x + 1; x++) {
          if (x === u.x && y === u.y) continue;
          // 3x3 범위(정사각형) 내의 적 개수 계산 (은신한 아군 제외)
          const cnt = al.filter(a => !isStealthed(a) && Math.abs(a.x - x) <= 1 && Math.abs(a.y - y) <= 1).length;
          if (cnt >= 2 && cnt > maxCluster) { maxCluster = cnt; targetCell = { x, y }; }
        }
      }
      if (targetCell) {
        u.res -= 40;
        for (let y = targetCell.y - 1; y <= targetCell.y + 1; y++) {
          for (let x = targetCell.x - 1; x <= targetCell.x + 1; x++) {
            const t = this.uAt(x, y);
            if (t && t.team === 'ally' && !isStealthed(t)) {
              const dmg = calcDmg(u, t);
              t.hp = Math.max(0, t.hp - dmg);
              this.floatT(t.x, t.y, `-${dmg}`, 'damage');
              this.vfxSpawn(this.uSX(t.x, t.y) + UCX, this.uSY(t.x, t.y) + UCY,
                { count: 8, colors: ['#ff6600', '#ffaa00', '#ffff00'], shape: 'spark',
                  speed: 3, spread: 10, decay: 0.03, size: 4 });
              if (t.hp <= 0) { this.screenShake(); this.sfxDeath(); this.vfxDeath(t); this.deathA(t.id); this.units = this.units.filter(v => v.hp > 0); }
            }
          }
        }
        this.floatT(u.x, u.y, t('messages.mage_fireball'), 'heal');
        this.sfxAtk(u.cls);
        u.ha = true; // 행동 완료
        await sl(300);
        this.units = this.units.filter(v => v.hp > 0);
        this.rUnits();
        return true;
      }
    }

    return false;
  },
  async eAI(u){const al=this.alive('ally');if(!al.length&&!this.hasAllyWall())return;
    const profile=AI_PROFILES[u.cls]||AI_PROFILES.novice;
    // 지원 클래스: HP 높으면 전투 회피
    if(profile.avoidCombat&&u.hp>u.mhp*0.7){
      await this.eMv(u,al);return
    }
    // Check attack from current position first
    const inR=this.atkC(u).filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&!isStealthed(v)}).map(c=>this.uAt(c.x,c.y));
    if(inR.length&&profile.targetPriority!=='never'){
      // 스킬 사용 시도
      if(await this.tryUseSkill(u,profile)){return}
      // 일반 공격
      const target=this.selectTarget(u,inR,profile);
      if(target){await this.eAtkAsync(u,target);return}
    }
    // Try gate attack if adjacent to ally gate
    const gAtk=this.tryGateAtk(u);
    if(gAtk){await sl(250);return}
    // Try wall climb if adjacent to ally wall
    const wClimb=await this.tryWallClimb(u);
    if(wClimb)return;
    // Move towards closest ally or ally wall
    await this.eMv(u,al);
    if(this.over)return;
    // Attack after move (지원 클래스는 스킵)
    if(profile.avoidCombat&&u.hp>u.mhp*0.7)return;
    await sl(200);
    const postR=this.atkC(u).filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&!isStealthed(v)}).map(c=>this.uAt(c.x,c.y));
    if(postR.length&&profile.targetPriority!=='never'){
      // 스킬 사용 시도
      if(await this.tryUseSkill(u,profile)){return}
      // 일반 공격
      const target=this.selectTarget(u,postR,profile);
      if(target){await this.eAtkAsync(u,target);return}
    }
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
      this.floatT(nx,ny,t('messages.gate_hit'),'damage');this.sfxAtk(u.cls);
      this.vfxSpawn(this.uSX(nx,ny)+UCX,this.uSY(nx,ny)+UCY,{count:12,colors:['#aa8844','#ffcc66','#fff'],shape:'spark',speed:2,spread:12,decay:0.025,size:3});
      if(this.gateHP[k]<=0){
        // Gate destroyed - becomes passable plain
        this.ter[ny][nx]='plain';this.ter[ny][nx]='plain';
        this.floatT(nx,ny,t('messages.gate_destroyed'),'damage');this.screenShake();this.sfxKill();
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
      this.floatT(nx,ny,t('messages.ladder'),'heal');this.sfxMove();
      await sl(340);
      this.onBreach(u);
      return true}return false},
  // Track breach count and check defeat
  onBreach(u){
    this.breached++;
    const s=this.cStage;if(!s)return;
    const limit=Math.ceil(s.tot/4);
    this.floatT(u.x,u.y,t('messages.breach')+` ${this.breached}/${limit}`,'damage');
    if(this.breached>=limit){this.over=true;this.showRes(false,t('messages.enemy_breached',{count:this.breached}))}},
  async eAtkAsync(a,t){
    if(t.team==='ally')this.scrollToUnit(t);
    await sl(250);
    this.eAtk(a,t);
    await sl(t.hp<=0?500:300)},
  eAtk(a,t){
    const dmg=calcDmg(a,t);
    t.hp=Math.max(0,t.hp-dmg);this.vfxAtk(a,t);this.sfxAtk(a.cls);this.shakeU(t.id);this.floatT(t.x,t.y,`-${dmg}`,'damage');
    if(a.furyBuff>0)this.floatT(a.x,a.y,t('messages.fury_buff'),'heal');
    procFury(a,t,this);
    if(t.hp<=0){this.screenShake();this.sfxKill();this.sfxDeath();this.vfxDeath(t);this.deathA(t.id);this.units=this.units.filter(u=>u.hp>0);setTimeout(()=>{this.rUnits()},500)}
    else if(a.hp<=0){this.screenShake();this.sfxDeath();this.vfxDeath(a);this.deathA(a.id);this.units=this.units.filter(u=>u.hp>0);setTimeout(()=>{this.rUnits()},500)}
    else this.rUnits()},
  async eMv(u,al){
    // Defensive AI: 5-cell advance limit from formation position
    const origPos=u.origSpawn||{x:u.x,y:u.y};
    const profile=AI_PROFILES[u.cls]||AI_PROFILES.novice;
    const hpPct=u.hp/u.mhp;
    // 후퇴 조건: HP 낮으면 30% 확률로 후퇴
    const shouldRetreat=hpPct<profile.retreatThreshold&&Math.random()<0.3;
    if(shouldRetreat&&!u.isBoss){
      const mc=this.eMvC(u);if(!mc.length)return;
      let bestMove=null,bestDist=Infinity;
      for(const m of mc){const d=mh(m.x,m.y,origPos.x,origPos.y);if(d<bestDist){bestDist=d;bestMove=m}}
      if(bestMove&&mh(bestMove.x,bestMove.y,origPos.x,origPos.y)<mh(u.x,u.y,origPos.x,origPos.y)){
        u.x=bestMove.x;u.y=bestMove.y;this.animU(u.id,bestMove.x,bestMove.y);
        this.floatT(u.x,u.y,t('messages.retreat'),'damage');await sl(340);
        this.chkTrap(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);this.units=this.units.filter(v=>v.hp>0);setTimeout(()=>{this.rUnits()},500)}
        return
      }
    }
    // 클래스별 전진 제한 (Defense 맵: 무리 진격 범위 확대)
    let advLimit = this.cStage?.style === 'defense' ? 15 : 5;
    if(profile.style==='defensive') advLimit = this.cStage?.style === 'defense' ? 12 : 3;
    if(profile.style==='support') advLimit = this.cStage?.style === 'defense' ? 10 : 2;
    const advDist=mh(u.x,u.y,origPos.x,origPos.y);

    // Defense 맵: 무리 진격 체크 (고립 방지)
    if(this.cStage?.style === 'defense' && !u.isBoss) {
      const allies = this.alive('enemy').filter(e => e.id !== u.id && !e.isBoss);

      // 아군이 있으면 무리 진격 체크
      if(allies.length > 0) {
        // 가장 가까운 아군과의 거리
        const nearestAllyDist = Math.min(...allies.map(a => mh(u.x, u.y, a.x, a.y)));

        // 너무 앞서가면 대기 (아군보다 3칸 이상 앞서지 않기)
        const avgAllyY = allies.reduce((sum, a) => sum + a.y, 0) / allies.length;
        if(u.y > avgAllyY + 3) {
          return; // 너무 앞서감, 아군 대기
        }

        // 너무 고립되면 진격 제한 (가장 가까운 아군이 5칸 이상 멀면)
        if(nearestAllyDist > 5) {
          advLimit = Math.min(advLimit, advDist + 2); // 2칸만 더 진격 허용
        }
      }
    }

    // 전진 제한 체크
    if(advDist>=advLimit&&!u.isBoss){return}

    const mc=this.eMvC(u);if(!mc.length)return;
    // Filter moves to respect class-based advance limit
    const validMoves=mc.filter(m=>mh(m.x,m.y,origPos.x,origPos.y)<=advLimit||u.isBoss);
    if(!validMoves.length)return;

    let bt=null,bd=Infinity;
    for(const a of al){if(isStealthed(a))continue;const d=mh(u.x,u.y,a.x,a.y);if(d<bd){bd=d;bt=a}}

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
        this.chkTrap(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits()},500);return}
        if(bestMove.y===14){this.onBreach(u)};return}
    }

    // Guard mode: 방어형 유닛들이 아군 근처 유지
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
        if(bestMove){u.x=bestMove.x;u.y=bestMove.y;this.animU(u.id,bestMove.x,bestMove.y);await sl(340);
          this.chkTrap(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits()},500);return}
          return
        }
      }
    }

    // Keep distance: 원거리 유닛이 거리 유지
    let cbt=null,cbd=Infinity;
    for(const a of al){if(isStealthed(a))continue;const d=mh(u.x,u.y,a.x,a.y);if(d<cbd){cbd=d;cbt=a}}
    if(profile.keepDistance&&cbt&&mh(u.x,u.y,cbt.x,cbt.y)<=2){
      let bestMove=null,bestDist=0;
      for(const m of validMoves){
        const dist=mh(m.x,m.y,cbt.x,cbt.y);
        if(dist>bestDist&&dist<=u.range){bestDist=dist;bestMove=m}
      }
      if(bestMove&&bestDist>mh(u.x,u.y,cbt.x,cbt.y)){
        u.x=bestMove.x;u.y=bestMove.y;this.animU(u.id,bestMove.x,bestMove.y);await sl(340);
        this.chkTrap(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits()},500);return}
        return
      }
    }

    // Normal movement: target closest ally or gate
    if(!bt||bd>8){const gateTarget={x:u.x<=4?4:5,y:13};
      let bc2=null,bs2=-Infinity;
      for(const c of validMoves){
        let s=-(mh(c.x,c.y,gateTarget.x,gateTarget.y))*10+(c.y-u.y)*(5+profile.advanceBonus);
        if(s>bs2){bs2=s;bc2=c}
      }
      if(bc2){u.x=bc2.x;u.y=bc2.y;this.animU(u.id,bc2.x,bc2.y);await sl(340);
        this.chkTrap(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits()},500);return}
        return}
    }

    let bc=null,bs=-Infinity;
    for(const c of validMoves){
      let s=0;if(bt)s+=(mh(u.x,u.y,bt.x,bt.y)-mh(c.x,c.y,bt.x,bt.y))*10;
      s+=(c.y-u.y)*(3+profile.advanceBonus*0.3);if(s>bs){bs=s;bc=c}
    }

    if(bc){u.x=bc.x;u.y=bc.y;this.animU(u.id,bc.x,bc.y);await sl(340);
      this.chkTrap(u);if(u.hp<=0){this.vfxDeath(u);this.deathA(u.id);setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits()},500);return}
      if(bc.y===14){this.onBreach(u)}
    }
  },

  chkEnd(){if(this.over)return;const al=this.alive('ally'),en=this.alive('enemy');
    // 소환사 사망 시 소환수 제거 (모든 소환사 확인, 죽은 것들만 처리)
    this.units.filter(u=>u.cls==='summoner'&&u.hp<=0).forEach(deadSummoner=>{
      const summons=this.units.filter(s=>s.isSummon&&s.summonerId===deadSummoner.id);
      summons.forEach(s=>{
        this.floatT(s.x,s.y,t('messages.unsummoned'),'damage');
        this.vfxDeath(s);
      });
      this.units=this.units.filter(v=>!(v.isSummon&&v.summonerId===deadSummoner.id));
    });
    if(!al.length&&!this.hasAllyWall()){this.over=true;this.showRes(false,t('messages.all_defeated'));return}
    // Breach check
    const s=this.cStage;if(s){const limit=Math.ceil(s.tot/4);
      if(this.breached>=limit){this.over=true;this.showRes(false,t('messages.enemy_breached',{count:this.breached}));return}}
    if(s&&this.eSpwn>=s.tot&&!en.length){this.over=true;this.cleared.add(s.id);this.showRes(true,t('messages.stage_clear',{stage_id:s.id,turn:this.turn}))}},
});
