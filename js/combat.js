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
      const a=this.atkC(u);
      if(u.role==='healer'){this.atkT=[];this.healT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&v.hp<v.mhp&&v.id!==u.id})}
      else{this.atkT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='enemy'});this.healT=[]}
      this.rUnits();this.rTer();this.showAM(u);this.showUI(u);this.rNav();this.scrollToUnit(u);this.sfxSelect();return}
    // Normal selection
    this.sel=u;
    if(u.team==='ally'&&!u.ha){this.mvT=(u.hm||u.mo)?[]:this.mvC(u);const a=this.atkC(u);
      if(u.role==='healer'){this.atkT=[];this.healT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&v.hp<v.mhp&&v.id!==u.id})}
      else{this.atkT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='enemy'});this.healT=[]}}
    else{this.mvT=[];this.atkT=[];this.healT=[]}this.rTer();this.showUI(u);this.rNav();this.scrollToUnit(u);this.sfxSelect()},
  clrSel(){this.sel=null;this.mvT=[];this.atkT=[];this.healT=[];this.awPM=false;this.skillMode=false;this.preMv=null;this.hideAM();this.rTer();this.rUnits();this.defI();this.rNav()},
  cellCk(x,y){if(this.phase!=='player'||this.over||this.anim)return;const cl=this.uAt(x,y),s=this.sel;
    if(this.awPM&&s){
      // Skill targeting
      if(this.skillMode){
        if(this.atkT.some(c=>c.x===x&&c.y===y)){this.doSkill(s,x,y);return}
        this.skillMode=false;const a=this.atkC(s);
        if(s.role==='healer'){this.atkT=[];this.healT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&v.hp<v.mhp&&v.id!==s.id})}
        else{this.atkT=a.filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='enemy'});this.healT=[]}
        this.rTer();this.showAM(s);return}
      // In awPM: attack/heal targets
      if(cl&&cl.team==='enemy'&&s.team==='ally'&&!s.ha&&this.atkT.some(c=>c.x===x&&c.y===y)){this.doAtk(s,cl);return}
      if(cl&&cl.team==='ally'&&s.role==='healer'&&!s.ha&&cl.id!==s.id&&this.healT.some(c=>c.x===x&&c.y===y)){this.doHeal(s,cl);return}
      // Rule 1/5: 행동 안 하고 다른곳 클릭 → 대기 상태 진입
      s.ha=true;s.waited=true;this.awPM=false;this.hideAM();this.rUnits();this.clrSel();
      if(cl&&cl.team!=='enemy'){const nu=this.uAt(x,y);if(nu)this.selU(nu)}
      this.chkAutoEnd();return}
    if(!s){if(cl)this.selU(cl);return}
    if(cl&&cl.team==='enemy'&&s.team==='ally'&&!s.ha&&this.atkT.some(c=>c.x===x&&c.y===y)){this.doAtk(s,cl);return}
    if(cl&&cl.team==='ally'&&s.role==='healer'&&!s.ha&&cl.id!==s.id&&this.healT.some(c=>c.x===x&&c.y===y)){this.doHeal(s,cl);return}
    if(!cl&&this.mvT.some(c=>c.x===x&&c.y===y)){this.doMv(s,x,y);return}
    if(cl){this.selU(cl);return}this.clrSel()},

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
    if(a.furyBuff>0)this.floatT(a.x,a.y,'광폭!','heal');
    procFury(a,t,this);
    a.ha=true;a.hm=true;this.awPM=false;this.hideAM();
    if(t.hp<=0){if(atkE>0)this.floatT(a.x,a.y,`+${atkE} EXP`,'exp');
      this.screenShake();this.sfxKill();this.sfxDeath();this.vfxDeath(t);this.deathA(t.id);setTimeout(()=>{this.units=this.units.filter(u=>u.hp>0);this.rUnits();this.chkEnd();this.clrSel();this.chkAutoEnd()},500)}
    else if(a.hp<=0){this.screenShake();this.sfxDeath();this.vfxDeath(a);this.deathA(a.id);setTimeout(()=>{this.units=this.units.filter(u=>u.hp>0);this.rUnits();this.chkEnd();this.clrSel();this.chkAutoEnd()},500)}
    else{if(atkE>0)this.floatT(a.x,a.y,`+${atkE} EXP`,'exp');this.rUnits();this.clrSel();this.chkAutoEnd()}},
  doHeal(h,t){const amt=Math.round(h.atk*1.5);const he=this._grantExp(h,'heal');t.hp=Math.min(t.mhp,t.hp+amt);this.vfxHeal(t);this.vfxBuff(t);this.sfxHeal();this.floatT(t.x,t.y,`+${amt}`,'heal');
    if(he>0)this.floatT(h.x,h.y,`+${he} EXP`,'exp');
    h.ha=true;h.hm=true;this.awPM=false;this.hideAM();this.rUnits();this.clrSel();this.chkAutoEnd()},
  actWait(){if(!this.sel)return;this.sel.ha=true;this.sel.waited=true;this.awPM=false;this.hideAM();this.sfxWait();this.rUnits();this.clrSel();this.chkAutoEnd()},
  actCancel(){if(!this.sel||!this.preMv)return;const u=this.sel;u.x=this.preMv.x;u.y=this.preMv.y;u.hm=false;u.mo=false;
    this.animU(u.id,u.x,u.y);this.awPM=false;this.preMv=null;this.skillMode=false;this.hideAM();this.sfxUIClick();setTimeout(()=>{this.rTer();this.clrSel()},340)},
  actSkill(){if(!this.sel||!this.awPM)return;const u=this.sel;const sk=SKILLS[u.cls];if(!sk||u.res<sk.cost)return;
    this.skillMode=true;
    if(sk.id==='knight_switch'){
      // 스위치: 이동 범위 내 아군 표시
      this.atkT=this.mvC(u).filter(c=>{const v=this.uAt(c.x,c.y);return v&&v.team==='ally'&&v.id!==u.id});
      this.healT=[]
    }else if(sk.id==='archer_dash'){
      // 도약: dashRange 거리 내 빈 공간 표시
      this.atkT=[];for(let x=0;x<COLS;x++)for(let y=0;y<ROWS;y++){
        if(mh(u.x,u.y,x,y)<=sk.dashRange&&mh(u.x,u.y,x,y)>0&&!this.uAt(x,y)){this.atkT.push({x,y})}}
      this.healT=[]
    }else{
      // 기본: 공격 범위 내 표시
      const dirs=[{x:0,y:-1},{x:1,y:0},{x:0,y:1},{x:-1,y:0}];
      this.atkT=dirs.map(d=>({x:u.x+d.x,y:u.y+d.y})).filter(p=>p.x>=0&&p.x<COLS&&p.y>=0&&p.y<ROWS);
      this.healT=[]
    }
    this.hideAM();this.rTer()},
  doSkill(u,tx,ty){const sk=SKILLS[u.cls];if(!sk)return;u.res-=sk.cost;
    // 스위치: 아군과 위치 교환
    if(sk.id==='knight_switch'){
      const t=this.units.find(v=>v.x===tx&&v.y===ty&&v.team==='ally'&&v.hp>0&&v.id!==u.id);
      if(!t)return;
      [u.x,u.y,t.x,t.y]=[t.x,t.y,u.x,u.y];
      this.animU(u.id,u.x,u.y);this.animU(t.id,t.x,t.y);
      this.floatT(u.x,u.y,'스위치!','heal');
      this.vfxSpawn(this.uSX(u.x,u.y)+UCX,this.uSY(u.x,u.y)+UCY,{count:10,colors:['#4f4','#4ff','#fff'],shape:'ring',speed:2,spread:8,decay:0.02,size:8});
      this.vfxSpawn(this.uSX(t.x,t.y)+UCX,this.uSY(t.x,t.y)+UCY,{count:10,colors:['#4f4','#4ff','#fff'],shape:'ring',speed:2,spread:8,decay:0.02,size:8});
      this.sfxMove();u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this.hideAM();
      setTimeout(()=>{this.rUnits();this.clrSel();this.chkAutoEnd()},340);return
    }
    // 도약: 지정 위치로 빠르게 이동
    if(sk.id==='archer_dash'){
      if(this.uAt(tx,ty))return;
      u.x=tx;u.y=ty;u.mo=true;
      this.animU(u.id,tx,ty);
      this.floatT(u.x,u.y,'도약!','heal');
      this.vfxSpawn(this.uSX(u.x,u.y)+UCX,this.uSY(u.x,u.y)+UCY,{count:15,colors:['#ff8','#ff0','#fff'],shape:'spark',speed:5,spread:15,decay:0.02,size:3});
      this.sfxMove();u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this.hideAM();
      setTimeout(()=>{this.rUnits();this.clrSel();this.chkAutoEnd()},340);return
    }
    // 강타: ATK × 1.5 데미지 공격
    if(sk.id==='warrior_powersmash'){
      const t=this.units.find(v=>v.x===tx&&v.y===ty&&v.hp>0&&v.team!==u.team);
      if(!t)return;
      const dmg=Math.max(1,Math.round(u.atk*1.5-t.def));
      t.hp=Math.max(0,t.hp-dmg);
      this.vfxAtk(u,t);this.sfxAtk(u.cls);this.shakeU(t.id);
      this.floatT(t.x,t.y,`-${dmg}`,'damage');
      procFury(u,t,this);
      this.floatT(u.x,u.y,'강타!','heal');
      if(t.hp<=0){this.screenShake();this.sfxKill();this.sfxDeath();this.vfxDeath(t);this.deathA(t.id);}
      u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this.hideAM();
      setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits();this.chkEnd();this.clrSel();this.chkAutoEnd()},500);return
    }
    // 관통: 일직선 관통 공격
    const dx=tx-u.x,dy=ty-u.y;
    for(let i=1;i<=sk.pierceLen;i++){const px=u.x+dx*i,py=u.y+dy*i;
      if(px<0||px>=COLS||py<0||py>=ROWS)continue;
      const t=this.units.find(v=>v.hp>0&&v.x===px&&v.y===py&&v.team!==u.team);
      if(t){const dmg=Math.max(1,u.atk-t.def);t.hp=Math.max(0,t.hp-dmg);
        this.floatT(t.x,t.y,`-${dmg}`,'damage');this.shakeU(t.id);
        this.vfxSpawn(this.uSX(t.x,t.y)+UCX,this.uSY(t.x,t.y)+UCY,{count:8,colors:['#6af','#48f','#fff'],shape:'spark',speed:3,spread:8,decay:0.03,size:3});
        if(t.hp<=0){this.screenShake();this.sfxKill();this.sfxDeath();this.vfxDeath(t);this.deathA(t.id)}}}
    this.sfxAtk(u.cls);this._grantExp(u,'attack');
    this.floatT(u.x,u.y,'관통!','heal');
    this.vfxSpawn(this.uSX(u.x,u.y)+UCX,this.uSY(u.x,u.y)+UCY,{count:12,colors:['#6af','#48f','#aaf'],shape:'spark',speed:4,spread:12,decay:0.025,size:4});
    u.ha=true;u.hm=true;this.awPM=false;this.skillMode=false;this.hideAM();
    setTimeout(()=>{this.units=this.units.filter(v=>v.hp>0);this.rUnits();this.chkEnd();this.clrSel();this.chkAutoEnd()},500)},

});
