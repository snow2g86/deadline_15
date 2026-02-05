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
  clrSel(){this.sel=null;this.mvT=[];this.atkT=[];this.healT=[];this.awPM=false;this.preMv=null;this.hideAM();this.rTer();this.rUnits();this.defI();this.rNav()},
  cellCk(x,y){if(this.phase!=='player'||this.over||this.anim)return;const cl=this.uAt(x,y),s=this.sel;
    if(this.awPM&&s){
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
    this.animU(u.id,u.x,u.y);this.awPM=false;this.preMv=null;this.hideAM();this.sfxUIClick();setTimeout(()=>{this.rTer();this.clrSel()},340)},

});
