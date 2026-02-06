Object.assign(G, {
  // ═══ Unit Selection & Action State Machine ═══
  // States: idle | selected | awPM (awaiting post-move action) | waitResume (wait cancelled, can act)
  // Flags on unit: hm(has moved), ha(has acted/done), waited(in wait), mo(moved this turn)
  
  selU(u){if(this.phase!=='player'||this.over||this.anim||this.awPM)return;
    // Rule 6: 행동 완료(ha=true && !waited) → 선택 불가
    if(u.team==='ally'&&u.ha&&!u.waited)return;
    // Rule 4/5: 대기중 유닛 선택 → 대기 해제, 행동 가능(이동 불가)
    if(u.team==='ally'&&u.waited){
      u.ha=false;u.waited=false;
      this.sel=u;this.awPM=true;this.mvT=[];
      if(u.channeling){this.atkT=[];this.healT=[]}
      else{const a=this.atkC(u);
      if(u.role==='healer'){this.atkT=[];this.healT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&v.hp<v.mhp&&v.id!==u.id})}
      else{this.atkT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='enemy'});this.healT=[]}}
      this.rTer();this.rUnits();this.showAM(u);this.showUI(u);this.rNav();this.scrollToUnit(u);this.sfxSelect();return}
    // Normal selection
    this.sel=u;this.awPM=true;
    if(u.team==='ally'&&!u.ha){this.mvT=[];const a=this.atkC(u);
      if(u.role==='healer'){this.atkT=[];this.healT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&v.hp<v.mhp&&v.id!==u.id})}
      else{this.atkT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='enemy'});this.healT=[]}}
    else{this.mvT=[];this.atkT=[];this.healT=[]}this.rTer();this.rUnits();this.showAM(u);this.showUI(u);this.rNav();this.scrollToUnit(u);this.sfxSelect()},
  clrSel(){this.sel=null;this.mvT=[];this.atkT=[];this.healT=[];this.awPM=false;this.skillMode=false;this.skillMenuOpen=false;this._curSkill=null;this.preMv=null;this.hideAM();this.rTer();this.rUnits();this.defI();this.rNav()},
  cellCk(x,y){if(this.phase!=='player'||this.over||this.anim)return;const cl=this.uAt(x,y),s=this.sel;
    if(this.awPM&&s){
      // Skill targeting
      if(this.skillMode){
        if(this.atkT.some(c=>c.x===x&&c.y===y)){this.doSkill(s,x,y);return}
        this.skillMode=false;const a=this.atkC(s);
        if(s.role==='healer'){this.atkT=[];this.healT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&v.hp<v.mhp&&v.id!==s.id})}
        else{this.atkT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='enemy'});this.healT=[]}
        this.rTer();this.showAM(s);return}
      // In awPM: stealth movement (assassin into enemy-occupied forest)
      if(cl&&cl.team==='enemy'&&s.cls==='assassin'&&s.team==='ally'&&!s.ha&&this.ter[y]&&this.ter[y][x]==='forest'&&this.mvT.some(c=>c.x===x&&c.y===y)){this.doMv(s,x,y);return}
      // In awPM: attack/heal targets
      if(cl&&cl.team==='enemy'&&s.team==='ally'&&!s.ha&&this.atkT.some(c=>c.x===x&&c.y===y)){this.doAtk(s,cl);return}
      if(cl&&cl.team==='ally'&&s.role==='healer'&&!s.ha&&cl.id!==s.id&&this.healT.some(c=>c.x===x&&c.y===y)){this.doHeal(s,cl);return}
      // In awPM: movement (when no unit at target)
      if(!cl&&this.mvT.some(c=>c.x===x&&c.y===y)){this.doMv(s,x,y);return}
      // 이동/공격/치유 범위가 표시된 상태에서 범위 밖을 클릭한 경우 → 취소
      if(!cl && (this.mvT.length>0 || this.atkT.length>0 || this.healT.length>0) && !this.mvT.some(c=>c.x===x&&c.y===y) && !this.atkT.some(c=>c.x===x&&c.y===y) && !this.healT.some(c=>c.x===x&&c.y===y)){
        this.mvT=[];this.atkT=[];this.healT=[];this.rTer();this.showAM(s);return;
      }
      // Rule 1/5: 행동 안 하고 다른곳 클릭 → 대기 상태 진입
      s.ha=true;s.waited=true;this.awPM=false;this.hideAM();this.rUnits();this.clrSel();
      if(cl&&cl.team!=='enemy'){const nu=this.uAt(x,y);if(nu)this.selU(nu)}
      this.chkAutoEnd();return}
    if(!s){if(cl)this.selU(cl);return}
    // Stealth movement (assassin into enemy-occupied forest)
    if(cl&&cl.team==='enemy'&&s.cls==='assassin'&&s.team==='ally'&&!s.ha&&this.ter[y]&&this.ter[y][x]==='forest'&&this.mvT.some(c=>c.x===x&&c.y===y)){this.doMv(s,x,y);return}
    if(cl&&cl.team==='enemy'&&s.team==='ally'&&!s.ha&&this.atkT.some(c=>c.x===x&&c.y===y)){this.doAtk(s,cl);return}
    if(cl&&cl.team==='ally'&&s.role==='healer'&&!s.ha&&cl.id!==s.id&&this.healT.some(c=>c.x===x&&c.y===y)){this.doHeal(s,cl);return}
    if(!cl&&this.mvT.some(c=>c.x===x&&c.y===y)){this.doMv(s,x,y);return}
    if(cl){this.selU(cl);return}this.clrSel()},
  // 이동 버튼 클릭 핸들러
  actMove(){if(!this.sel)return;this.hideAM();const u=this.sel;this.mvT=(u.hm||u.mo)?[]:this.mvC(u);this.rTer();this.floatT(u.x,u.y,t('messages.select_move_target'),'heal')},
  // 공격/치유 버튼 클릭 핸들러
  actAttack(){if(!this.sel)return;this.hideAM();const msg=this.sel.role==='healer'?t('messages.select_heal_target'):t('messages.select_attack_target');this.floatT(this.sel.x,this.sel.y,msg,'heal')},
  // 스킬 메뉴 표시
  showSkillMenu(){if(!this.sel||!this.awPM)return;this.skillMenuOpen=true;this.showAM(this.sel)},
  // 스킬 메뉴 숨김 (메인 메뉴로 복귀)
  hideSkillMenu(){if(!this.sel)return;this.skillMenuOpen=false;this.showAM(this.sel)},
  // 아이템 버튼 (추후 개발)
  actItem(){if(!this.sel)return;this.floatT(this.sel.x,this.sel.y,t('messages.item_system_preparing'),'damage')},

  // Actions
  _grantExp(u,action){if(u.team==='ally'&&u.uid){const e=actExp(this.cStage?this.cStage.id:1,action);if(e>0)this.battleExp[u.uid]=(this.battleExp[u.uid]||0)+e;return e}return 0},
  doMv(u,tx,ty){this._grantExp(u,'move');this.preMv={x:u.x,y:u.y};u.x=tx;u.y=ty;u.hm=true;u.mo=true;this.awPM=true;this.animU(u.id,tx,ty);this.sfxMove();
    this.chkTrap(u);
    const a=this.atkC(u);if(u.role==='healer'){this.atkT=[];this.healT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&v.hp<v.mhp&&v.id!==u.id})}
    else{this.atkT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='enemy'});this.healT=[]}
    this.mvT=[];setTimeout(()=>{this.scrollToUnit(u);this.rTer();this.showAM(u);this.showUI(u)},340)},
  doAtk(a,t){
    const dmg=calcDmg(a,t);const atkE=this._grantExp(a,'attack');
    t.hp=Math.max(0,t.hp-dmg);this.vfxAtk(a,t);this.sfxAtk(a.cls);this.shakeU(t.id);
    this.floatT(t.x,t.y,`-${dmg}`,'damage');
    if(a.furyBuff>0)this.floatT(a.x,a.y,t('messages.fury_buff'),'heal');
    procFury(a,t,this);
    a.ha=true;a.hm=true;this.awPM=false;this.hideAM();
    if(t.hp<=0){if(atkE>0)this.floatT(a.x,a.y,`+${atkE} EXP`,'exp');
      this.screenShake();this.sfxKill();this.sfxDeath();this.vfxDeath(t);this.deathA(t.id);setTimeout(()=>{this.units=this.units.filter(u=>u.hp>0);this.rUnits();this.chkEnd();this.clrSel();this.chkAutoEnd()},500)}
    else if(a.hp<=0){this.screenShake();this.sfxDeath();this.vfxDeath(a);this.deathA(a.id);setTimeout(()=>{this.units=this.units.filter(u=>u.hp>0);this.rUnits();this.chkEnd();this.clrSel();this.chkAutoEnd()},500)}
    else{if(atkE>0)this.floatT(a.x,a.y,`+${atkE} EXP`,'exp');this.rUnits();this.clrSel();this.chkAutoEnd()}},
  doHeal(h,t){const amt=Math.round(h.atk*1.5);const he=this._grantExp(h,'heal');t.hp=Math.min(t.mhp,t.hp+amt);this.vfxHeal(t);this.vfxBuff(t);this.sfxHeal();this.floatT(t.x,t.y,`+${amt}`,'heal');
    if(he>0)this.floatT(h.x,h.y,`+${he} EXP`,'exp');
    h.ha=true;h.hm=true;this.awPM=false;this.hideAM();this.rUnits();this.clrSel();this.chkAutoEnd()},
  actWait(){if(!this.sel)return;this.sel.ha=true;this.sel.waited=true;if(this.sel.team==='ally')this.allyPos[this.sel.id]={x:this.sel.x,y:this.sel.y};this.awPM=false;this.hideAM();this.sfxWait();this.rUnits();this.clrSel();this.chkAutoEnd()},
  actCancel(){if(!this.sel)return;
    // 스킬 서브 메뉴에서 돌아가기
    if(this.skillMenuOpen){this.hideSkillMenu();return}
    // 이동 취소
    if(!this.preMv)return;const u=this.sel;u.x=this.preMv.x;u.y=this.preMv.y;u.hm=false;u.mo=false;
    this.animU(u.id,u.x,u.y);this.awPM=false;this.preMv=null;this.skillMode=false;this.skillMenuOpen=false;this.hideAM();this.sfxUIClick();setTimeout(()=>{this.rTer();this.clrSel()},340)},
  actSkill(idx){if(!this.sel||!this.awPM)return;const u=this.sel;
    const skills=getSkills(u.cls);const sk=skills[idx||0];
    if(!sk||u.res<sk.cost)return;
    this.skillMenuOpen=false;
    this._curSkill=sk;this.skillMode=true;
    if(sk.id==='knight_switch'){
      this.atkT=this.mvC(u).filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&v.id!==u.id});
      this.healT=[]
    }else if(sk.id==='archer_dash'){
      this.atkT=[];for(let x=0;x<COLS;x++)for(let y=0;y<ROWS;y++){
        if(mh(u.x,u.y,x,y)<=sk.dashRange&&mh(u.x,u.y,x,y)>0&&!this.uAt(x,y)){this.atkT.push({x,y})}}
      this.healT=[]
    }else if(sk.id==='assassin_ambush'){
      // 습격: 맵 전체 적 위치
      this.atkT=this.units.filter(v=>v.team==='enemy'&&v.hp>0).map(v=>({x:v.x,y:v.y}));
      this.healT=[]
    }else if(sk.id==='assassin_assassinate'){
      // 암살: 즉시 실행 (타겟팅 불필요)
      this.skillMode=false;this.doSkill(u,u.x,u.y);return
    }else if(sk.id==='priest_massheal'){
      // 집단 치유: 즉시 실행 (타겟팅 불필요)
      this.skillMode=false;this.doSkill(u,u.x,u.y);return
    }else if(sk.id==='sapper_trap'){
      // 함정 설치: trapRange 내 빈 통행가능 타일 (유닛/함정 없음)
      this.atkT=[];const tr=sk.trapRange||3;
      for(let x=0;x<COLS;x++)for(let y=0;y<ROWS;y++){
        if(mh(u.x,u.y,x,y)<=tr&&mh(u.x,u.y,x,y)>0){
          const ti=TI[this.ter[y][x]];if(!ti.pass)continue;
          if(this.uAt(x,y))continue;
          if(this.traps.find(t=>t.x===x&&t.y===y))continue;
          this.atkT.push({x,y})}}
      this.healT=[]
    }else if(sk.id==='mage_fireburst'){
      // 화염폭발: 공격 범위 내 타일 (적 존재 여부 무관 — 플레이어가 판단)
      this.atkT=[];
      for(let x=0;x<COLS;x++)for(let y=0;y<ROWS;y++){
        if(mh(u.x,u.y,x,y)<=u.range&&mh(u.x,u.y,x,y)>0)this.atkT.push({x,y})}
      this.healT=[]
    }else if(sk.id==='novice_throw'){
      // 돌던지기: throwRange 내 적 위치
      this.atkT=this.units.filter(v=>v.team==='enemy'&&v.hp>0&&mh(u.x,u.y,v.x,v.y)<=sk.throwRange).map(v=>({x:v.x,y:v.y}));
      this.healT=[]
    }else if(sk.id==='brawler_disarm'){
      // 무장해제: disarmRange 내 적 위치
      const dr=sk.disarmRange||1;
      this.atkT=this.units.filter(v=>v.team==='enemy'&&v.hp>0&&mh(u.x,u.y,v.x,v.y)<=dr).map(v=>({x:v.x,y:v.y}));
      this.healT=[]
    }else if(sk.id==='shaman_curse'||sk.id==='shaman_exalt'){
      // 채널링: 즉시 실행 (타겟팅 불필요)
      this.skillMode=false;this.doSkill(u,u.x,u.y);return
    }else if(sk.id.startsWith('summoner_summon_')){
      // 소환 스킬: 소환 제한 체크 + 범위 내 빈 타일
      const maxSummons=1;
      const currentSummons=this.units.filter(s=>s.isSummon&&s.summonerId===u.id);
      if(currentSummons.length>=maxSummons){
        u.res+=sk.cost;this.floatT(u.x,u.y,t('messages.summoner_limit'),'damage');return
      }
      // 소환 가능 타일 (주변 3칸, 빈 통행가능 타일)
      const summonRange=sk.summonRange||3;
      this.atkT=[];
      for(let x=0;x<COLS;x++)for(let y=0;y<ROWS;y++){
        if(mh(u.x,u.y,x,y)<=summonRange&&mh(u.x,u.y,x,y)>0){
          const ti=TI[this.ter[y][x]];if(!ti||!ti.pass)continue;
          if(this.uAt(x,y))continue;
          this.atkT.push({x,y})}}
      this.healT=[]
    }else{
      const dirs=[{x:0,y:-1},{x:1,y:0},{x:0,y:1},{x:-1,y:0}];
      this.atkT=dirs.map(d=>({x:u.x+d.x,y:u.y+d.y})).filter(p=>p.x>=0&&p.x<COLS&&p.y>=0&&p.y<ROWS);
      this.healT=[]
    }
    this.hideAM();this.rTer()},
  _findAdj(x,y,u){
    // 인접 빈 타일 찾기 (4방향)
    const dirs=[{x:0,y:-1},{x:1,y:0},{x:0,y:1},{x:-1,y:0}];
    const cands=[];
    for(const d of dirs){const nx=x+d.x,ny=y+d.y;
      if(nx<0||nx>=COLS||ny<0||ny>=ROWS)continue;
      const ti=TI[this.ter[ny][nx]];if(!ti.pass)continue;
      if(!this.uAt(nx,ny))cands.push({x:nx,y:ny});}
    if(!cands.length)return null;
    if(u){cands.sort((a,b)=>mh(a.x,a.y,u.x,u.y)-mh(b.x,b.y,u.x,u.y))}
    return cands[0];
  },
  doSkill(u,tx,ty){const sk=this._curSkill||SKILLS[u.cls];if(!sk)return;
    // 배열인 경우 첫 번째 스킬 사용 (fallback)
    const skObj=Array.isArray(sk)?sk[0]:sk;
    if(u.res<skObj.cost)return;u.res-=skObj.cost;
    // 습격: 맵 전체 적 대상 → 인접 이동 → ATK×2 공격
    if(skObj.id==='assassin_ambush'){
      const t=this.units.find(v=>v.x===tx&&v.y===ty&&v.team==='enemy'&&v.hp>0);
      if(!t){u.res+=skObj.cost;u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();this.rUnits();return}
      const adj=this._findAdj(t.x,t.y,u);
      if(!adj){u.res+=skObj.cost;this.floatT(u.x,u.y,t('messages.no_empty_tile'),'damage');u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();this.rUnits();return}
      u.x=adj.x;u.y=adj.y;u.mo=true;
      this.animU(u.id,adj.x,adj.y);
      setTimeout(()=>{
        const dmg=Math.max(1,u.atk*2-t.def);
        t.hp=Math.max(0,t.hp-dmg);
        this.vfxSpawn(this.uSX(t.x,t.y)+UCX,this.uSY(t.x,t.y)+UCY,{count:12,colors:['#a855f7','#fff','#c4b5fd'],shape:'spark',speed:4,spread:12,decay:0.025,size:4});
        this.sfxAtk(u.cls);this.shakeU(t.id);
        this.floatT(t.x,t.y,`-${dmg}`,'damage');
        this.floatT(u.x,u.y,t('messages.assassin_raid'),'heal');
        if(t.hp<=0){
          u.res=Math.min(u.maxRes,u.res+20);
          this.floatT(u.x,u.y,'+20 EP','exp');
          this.screenShake();this.sfxKill();this.sfxDeath();this.vfxDeath(t);this.deathA(t.id);
        }
        this._grantExp(u,'attack');
        u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
        setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits();this.chkEnd();this.clrSel();this.chkAutoEnd()},500);
      },360);return
    }
    // 암살: 겹친 적에 ATK×5 → 이탈
    if(skObj.id==='assassin_assassinate'){
      const t=this.units.find(v=>v.x===u.x&&v.y===u.y&&v.team==='enemy'&&v.hp>0);
      if(!t){u.res+=skObj.cost;u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();this.rUnits();return}
      const dmg=Math.max(1,u.atk*5-t.def);
      t.hp=Math.max(0,t.hp-dmg);
      this.vfxSpawn(this.uSX(t.x,t.y)+UCX,this.uSY(t.x,t.y)+UCY,{count:20,colors:['#7c3aed','#a855f7','#4c1d95'],shape:'spark',speed:5,spread:16,decay:0.02,size:5});
      this.screenShake();this.sfxAtk(u.cls);this.shakeU(t.id);
      this.floatT(t.x,t.y,`-${dmg}`,'damage');
      this.floatT(u.x,u.y,t('messages.assassin_assassinate'),'heal');
      if(t.hp<=0){this.sfxKill();this.sfxDeath();this.vfxDeath(t);this.deathA(t.id)}
      this._grantExp(u,'attack');
      const esc=this._findAdj(u.x,u.y,null);
      if(esc){u.x=esc.x;u.y=esc.y;u.mo=true;this.animU(u.id,esc.x,esc.y)}
      u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
      setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits();this.chkEnd();this.clrSel();this.chkAutoEnd()},500);return
    }
    // 집단 치유: 6칸 내 모든 아군 HP 회복
    if(skObj.id==='priest_massheal'){
      const hr=skObj.healRange||6;
      const targets=this.units.filter(v=>v.team==='ally'&&v.hp>0&&v.hp<v.mhp&&mh(u.x,u.y,v.x,v.y)<=hr);
      if(!targets.length){u.res+=skObj.cost;this.floatT(u.x,u.y,t('messages.select_heal_target'),'damage');u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();this.rUnits();return}
      const amt=u.atk;
      targets.forEach(t=>{
        t.hp=Math.min(t.mhp,t.hp+amt);
        this.floatT(t.x,t.y,`+${amt}`,'heal');
        this.vfxSpawn(this.uSX(t.x,t.y)+UCX,this.uSY(t.x,t.y)+UCY,{count:8,colors:['#4f4','#8f8','#fff'],shape:'ring',speed:2,spread:8,decay:0.025,size:6});
      });
      this.sfxHeal();this.floatT(u.x,u.y,t('messages.priest_mass_heal'),'heal');
      this.vfxSpawn(this.uSX(u.x,u.y)+UCX,this.uSY(u.x,u.y)+UCY,{count:15,colors:['#4f4','#ff8','#fff'],shape:'ring',speed:3,spread:14,decay:0.02,size:8});
      this._grantExp(u,'heal');
      u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
      this.rUnits();this.clrSel();this.chkAutoEnd();return
    }
    // 함정 설치: 지정 타일에 아군 함정 배치
    if(skObj.id==='sapper_trap'){
      if(this.uAt(tx,ty)||this.traps.find(t=>t.x===tx&&t.y===ty)){u.res+=skObj.cost;u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();this.rUnits();return}
      this.traps.push({x:tx,y:ty,dmg:u.atk*2,id:this.traps.length,team:'ally'});
      this.floatT(tx,ty,t('messages.trap_installed'),'heal');
      this.vfxSpawn(this.uSX(tx,ty)+UCX,this.uSY(tx,ty)+UCY,{count:10,colors:['#f80','#ff4','#fa0'],shape:'spark',speed:2,spread:10,decay:0.025,size:3});
      this.sfxUIClick();this._grantExp(u,'attack');
      u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
      this.rUnits();this.clrSel();this.chkAutoEnd();return
    }
    // 화염폭발: 3×3 범위 AoE
    if(skObj.id==='mage_fireburst'){
      let hitAny=false;
      for(let dx=-1;dx<=1;dx++)for(let dy=-1;dy<=1;dy++){
        const px=tx+dx,py=ty+dy;
        if(px<0||px>=COLS||py<0||py>=ROWS)continue;
        const t=this.units.find(v=>v.hp>0&&v.x===px&&v.y===py&&v.team==='enemy');
        if(t){
          const dmg=Math.max(1,u.atk-t.def);t.hp=Math.max(0,t.hp-dmg);
          this.floatT(t.x,t.y,`-${dmg}`,'damage');this.shakeU(t.id);
          this.vfxSpawn(this.uSX(t.x,t.y)+UCX,this.uSY(t.x,t.y)+UCY,{count:8,colors:['#f44','#f80','#ff4'],shape:'spark',speed:3,spread:8,decay:0.03,size:3});
          if(t.hp<=0){this.screenShake();this.sfxKill();this.sfxDeath();this.vfxDeath(t);this.deathA(t.id)}
          hitAny=true}}
      this.sfxAtk(u.cls);this._grantExp(u,'attack');
      this.floatT(u.x,u.y,t('messages.mage_fireball'),'heal');
      // 중앙 VFX
      this.vfxSpawn(this.uSX(tx,ty)+UCX,this.uSY(tx,ty)+UCY,{count:20,colors:['#f44','#f80','#ff4','#fff'],shape:'spark',speed:5,spread:18,decay:0.02,size:5});
      u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
      setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits();this.chkEnd();this.clrSel();this.chkAutoEnd()},500);return
    }
    // 돌던지기: throwRange 내 적에게 ATK×0.5 데미지
    if(skObj.id==='novice_throw'){
      const t=this.units.find(v=>v.x===tx&&v.y===ty&&v.team==='enemy'&&v.hp>0);
      if(!t){u.res+=skObj.cost;u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();this.rUnits();return}
      const dmg=Math.max(1,Math.round(u.atk*0.5)-t.def);
      t.hp=Math.max(0,t.hp-dmg);
      this.sfxAtk(u.cls);this.shakeU(t.id);
      this.floatT(t.x,t.y,`-${dmg}`,'damage');
      this.floatT(u.x,u.y,t('messages.stone_throw'),'heal');
      this.vfxSpawn(this.uSX(t.x,t.y)+UCX,this.uSY(t.x,t.y)+UCY,{count:8,colors:['#a88','#ccc','#fff'],shape:'spark',speed:3,spread:8,decay:0.03,size:3});
      if(t.hp<=0){this.screenShake();this.sfxKill();this.sfxDeath();this.vfxDeath(t);this.deathA(t.id)}
      this._grantExp(u,'attack');
      u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
      setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits();this.chkEnd();this.clrSel();this.chkAutoEnd()},500);return
    }
    // 쇠약의 저주: 채널링 시작
    if(skObj.id==='shaman_curse'){
      u.channeling='shaman_curse';
      this.floatT(u.x,u.y,t('messages.shaman_curse'),'heal');
      this.vfxSpawn(this.uSX(u.x,u.y)+UCX,this.uSY(u.x,u.y)+UCY,{count:15,colors:['#9333ea','#581c87','#a855f7'],shape:'ring',speed:3,spread:14,decay:0.02,size:6});
      this.sfxAtk(u.cls);
      u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
      this.rUnits();this.clrSel();this.chkAutoEnd();return
    }
    // 고양: 채널링 시작
    if(skObj.id==='shaman_exalt'){
      u.channeling='shaman_exalt';
      this.floatT(u.x,u.y,t('messages.shaman_exalt'),'heal');
      this.vfxSpawn(this.uSX(u.x,u.y)+UCX,this.uSY(u.x,u.y)+UCY,{count:15,colors:['#f59e0b','#fbbf24','#fff'],shape:'ring',speed:3,spread:14,decay:0.02,size:6});
      this.sfxHeal();
      // 모든 아군에게 버프 VFX
      this.alive('ally').forEach(a=>{
        if(a.id!==u.id)this.vfxSpawn(this.uSX(a.x,a.y)+UCX,this.uSY(a.x,a.y)+UCY,{count:6,colors:['#f59e0b','#fbbf24'],shape:'spark',speed:2,spread:6,decay:0.03,size:3});
      });
      u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
      this.rUnits();this.clrSel();this.chkAutoEnd();return
    }
    // 소환 스킬: 정령소환 & 골램소환
    if(skObj.id==='summoner_summon_spirit'||skObj.id==='summoner_summon_golem'){
      // 1. 위치 검증
      const target=this.units.find(v=>v.x===tx&&v.y===ty);
      if(target||!TI[this.ter[ty][tx]].pass){
        u.res+=skObj.cost;this.floatT(u.x,u.y,t('messages.summoner_no_spawn'),'damage');u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();this.rUnits();return
      }
      // 2. 소환수 타입별 스탯 계산
      const isSpirit=skObj.id==='summoner_summon_spirit';
      const summonCls=skObj.summonType;
      let hp,atk,def,move,range,role;
      if(isSpirit){
        hp=Math.round(u.mhp*0.5);
        atk=Math.round(u.atk*0.5);
        def=0;
        move=3;range=3;role='ranged'
      }else{
        hp=Math.round(u.mhp*1.2);
        atk=Math.round(u.atk*0.5);
        def=Math.round(u.def*1.2);
        move=2;range=1;role='melee'
      }
      // 3. 소환수 유닛 생성
      const summonName=isSpirit?'정령':'골램';
      const summon={
        id:this.nid++,uid:0,team:'ally',cls:summonCls,
        isSummon:true,summonerId:u.id,
        x:tx,y:ty,hp,mhp:hp,atk,def,
        move,range,role,
        res:0,maxRes:0,resType:'none',resRec:0,
        summonTurns:5,
        hm:false,ha:false,waited:false,mo:false,
        furyBuff:0,stunned:0
      };
      // 4. 유닛 배열 추가
      this.units.push(summon);
      // 5. VFX & 피드백
      this.floatT(tx,ty,t('messages.sapper_summon',{name:summonName}),'heal');
      const colors=isSpirit?['#8b5cf6','#c084fc','#fff']:['#78716c','#a8a29e','#fff'];
      this.vfxSpawn(this.uSX(tx,ty)+UCX,this.uSY(tx,ty)+UCY,{count:25,colors,shape:'ring',speed:5,spread:20,decay:0.02,size:8});
      this.sfxHeal();
      // 6. 경험치 & 턴 종료
      this._grantExp(u,'attack');
      u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
      this.rUnits();this.clrSel();this.chkAutoEnd();return
    }
    // 무장해제: 적 ATK 50% 감소 3턴
    if(skObj.id==='brawler_disarm'){
      const t=this.units.find(v=>v.x===tx&&v.y===ty&&v.team==='enemy'&&v.hp>0);
      if(!t){u.res+=skObj.cost;u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();this.rUnits();return}
      t.disarmed=3;
      this.sfxAtk(u.cls);this.shakeU(t.id);
      this.floatT(t.x,t.y,t('messages.atk_reduced'),'damage');
      this.floatT(u.x,u.y,t('messages.brawler_disarm'),'heal');
      this.vfxSpawn(this.uSX(t.x,t.y)+UCX,this.uSY(t.x,t.y)+UCY,{count:12,colors:['#f97316','#fbbf24','#fff'],shape:'ring',speed:3,spread:12,decay:0.025,size:5});
      this._grantExp(u,'attack');
      u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
      this.rUnits();this.clrSel();this.chkAutoEnd();return
    }
    // 스위치: 아군과 위치 교환
    if(skObj.id==='knight_switch'){
      const t=this.units.find(v=>v.x===tx&&v.y===ty&&v.team==='ally'&&v.hp>0&&v.id!==u.id);
      if(!t){u.res+=skObj.cost;u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();this.rUnits();return}
      [u.x,u.y,t.x,t.y]=[t.x,t.y,u.x,u.y];
      this.animU(u.id,u.x,u.y);this.animU(t.id,t.x,t.y);
      this.floatT(u.x,u.y,t('messages.knight_switch'),'heal');
      this.vfxSpawn(this.uSX(u.x,u.y)+UCX,this.uSY(u.x,u.y)+UCY,{count:10,colors:['#4f4','#4ff','#fff'],shape:'ring',speed:2,spread:8,decay:0.02,size:8});
      this.vfxSpawn(this.uSX(t.x,t.y)+UCX,this.uSY(t.x,t.y)+UCY,{count:10,colors:['#4f4','#4ff','#fff'],shape:'ring',speed:2,spread:8,decay:0.02,size:8});
      this.sfxMove();u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
      setTimeout(()=>{this.rUnits();this.clrSel();this.chkAutoEnd()},340);return
    }
    // 도약: 지정 위치로 빠르게 이동
    if(skObj.id==='archer_dash'){
      if(this.uAt(tx,ty)){u.res+=skObj.cost;u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();this.rUnits();return}
      u.x=tx;u.y=ty;u.mo=true;
      this.animU(u.id,tx,ty);
      this.floatT(u.x,u.y,t('messages.archer_leap'),'heal');
      this.vfxSpawn(this.uSX(u.x,u.y)+UCX,this.uSY(u.x,u.y)+UCY,{count:15,colors:['#ff8','#ff0','#fff'],shape:'spark',speed:5,spread:15,decay:0.02,size:3});
      this.sfxMove();u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
      setTimeout(()=>{this.rUnits();this.clrSel();this.chkAutoEnd()},340);return
    }
    // 강타: ATK × 1.5 데미지 공격
    if(skObj.id==='warrior_powersmash'){
      const t=this.units.find(v=>v.x===tx&&v.y===ty&&v.hp>0&&v.team!==u.team);
      if(!t){u.res+=skObj.cost;u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();this.rUnits();return}
      const dmg=Math.max(1,Math.round(u.atk*1.5-t.def));
      t.hp=Math.max(0,t.hp-dmg);
      this.vfxAtk(u,t);this.sfxAtk(u.cls);this.shakeU(t.id);
      this.floatT(t.x,t.y,`-${dmg}`,'damage');
      procFury(u,t,this);
      this.floatT(u.x,u.y,t('messages.warrior_strike'),'heal');
      if(t.hp<=0){this.screenShake();this.sfxKill();this.sfxDeath();this.vfxDeath(t);this.deathA(t.id);}
      u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
      setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits();this.chkEnd();this.clrSel();this.chkAutoEnd()},500);return
    }
    // 관통: 일직선 관통 공격
    const dx=tx-u.x,dy=ty-u.y;
    for(let i=1;i<=skObj.pierceLen;i++){const px=u.x+dx*i,py=u.y+dy*i;
      if(px<0||px>=COLS||py<0||py>=ROWS)continue;
      const t=this.units.find(v=>v.hp>0&&v.x===px&&v.y===py&&v.team!==u.team);
      if(t){const dmg=Math.max(1,u.atk-t.def);t.hp=Math.max(0,t.hp-dmg);
        this.floatT(t.x,t.y,`-${dmg}`,'damage');this.shakeU(t.id);
        this.vfxSpawn(this.uSX(t.x,t.y)+UCX,this.uSY(t.x,t.y)+UCY,{count:8,colors:['#6af','#48f','#fff'],shape:'spark',speed:3,spread:8,decay:0.03,size:3});
        if(t.hp<=0){this.screenShake();this.sfxKill();this.sfxDeath();this.vfxDeath(t);this.deathA(t.id)}}}
    this.sfxAtk(u.cls);this._grantExp(u,'attack');
    this.floatT(u.x,u.y,t('messages.lancer_pierce'),'heal');
    this.vfxSpawn(this.uSX(u.x,u.y)+UCX,this.uSY(u.x,u.y)+UCY,{count:12,colors:['#6af','#48f','#aaf'],shape:'spark',speed:4,spread:12,decay:0.025,size:4});
    u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
    setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits();this.chkEnd();this.clrSel();this.chkAutoEnd()},500)},

  // 채널링 해제
  cancelChannel(){
    if(!this.sel||!this.sel.channeling)return;
    const u=this.sel;
    this.floatT(u.x,u.y,t('messages.channel_cancel'),'damage');
    u.channeling=null;
    u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this._curSkill=null;this.hideAM();
    this.sfxUIClick();this.rUnits();this.clrSel();this.chkAutoEnd()},

});
