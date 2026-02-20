// ═══════════════════════════════════════════
//  battle/ui.js — UI (settings, info panel, result modal, nav)
// ═══════════════════════════════════════════

Object.assign(G, {
  getBuffs(u){
    const buffs=[];
    const t=this.ter[u.y]?this.ter[u.y][u.x]:null;
    if(t&&TI[t].buff){const b=TI[t].buff;buffs.push({icon:b.icon,type:b.type,turns:0})}
    getSkillBuffs(u).forEach(b=>buffs.push(b));
    if(u.cls==='assassin'&&t==='forest')buffs.push({icon:'🌙',type:'buff',turns:0});
    if(u._rootedTurns>0)buffs.push({icon:'🔗',type:'debuff',turns:u._rootedTurns});
    return buffs;
  },
  rTurnOrder(){
    const nav=document.getElementById('ally-nav');
    const alive=this.units.filter(u=>u.hp>0);
    // 다음 행동까지 남은 tick 계산
    const withTicks=alive.map(u=>{
      const rec=u.actionRec||1.0;
      return {u, ticksLeft: u.actionPow>=4.999 ? 0 : (5-u.actionPow)/rec};
    });
    withTicks.sort((a,b)=>a.ticksLeft-b.ticksLeft);

    nav.innerHTML='';
    withTicks.forEach(({u,ticksLeft})=>{
      const isCur=this.curUnit&&this.curUnit.id===u.id;
      const el=document.createElement('div');
      const isEnemy=u.team==='enemy';
      el.className=`an-unit${isEnemy?' enemy-nav':''}${isCur?' cur-nav':''}`;

      // 행동력 바: actionPow/5 비율
      const ap=u.actionPow||0, rec=u.actionRec||1.0;
      const apPct=Math.min(100,(ap/5)*100);
      const apDisplay=ap.toFixed(1);
      const recDisplay=rec.toFixed(1);
      const tickDisplay=ap>=4.999?'✓':ticksLeft.toFixed(1);

      el.innerHTML=`<div class="an-icon">${clsIcon(u.cls,18)}</div>
        <div class="an-apbar"><div style="height:${apPct}%"></div></div>
        <div class="an-info">
          <div class="an-ap-text">${apDisplay}/5</div>
          <div class="an-rec-text">${recDisplay}x</div>
          <div class="an-tick-text">${tickDisplay}</div>
        </div>`;

      if(u.team==='ally')el.onclick=()=>{if(this.awPM)return;if(!this.curUnit||u.id===this.curUnit.id)this.selU(u)};
      nav.appendChild(el);
    });
    this.rInfoPanel();
  },

  rMM(){
    const d=this.vDim();
    const wW=(d.c+d.r)*TW+4;
    const wH=(d.c+d.r)*TH+80;
    const mmMaxW=80;
    const sc=mmMaxW/wW;
    const mW=Math.ceil(wW*sc);
    const mH=Math.ceil(wH*sc);

    const cv=document.getElementById('mm-cv');
    cv.width=mW;cv.height=mH;
    const mm=document.getElementById('minimap');
    mm.style.width=mW+'px';mm.style.height=mH+'px';
    const ctx=cv.getContext('2d');
    ctx.clearRect(0,0,mW,mH);

    for(let r=0;r<ROWS;r++)for(let c=0;c<COLS;c++){
      const v=this.g2v(c,r);
      const ix=this.isoX(v.vc,v.vr);
      const iy=this.isoY(v.vc,v.vr,0);
      const sx=ix*sc, sy=iy*sc;
      const tw=TW*sc, th=TH*sc;
      ctx.fillStyle=TI[this.ter[r][c]].tc;
      ctx.beginPath();
      ctx.moveTo(sx+tw,sy);
      ctx.lineTo(sx+tw*2,sy+th);
      ctx.lineTo(sx+tw,sy+th*2);
      ctx.lineTo(sx,sy+th);
      ctx.closePath();ctx.fill();
      ctx.strokeStyle='rgba(255,255,255,.08)';ctx.lineWidth=0.3;ctx.stroke();
    }
    this.units.filter(u=>u.hp>0).forEach(u=>{
      const v=this.g2v(u.x,u.y);
      const ix=this.isoX(v.vc,v.vr)+TW;
      const iy=this.isoY(v.vc,v.vr,0)+TH;
      const sx=ix*sc, sy=iy*sc;
      ctx.fillStyle=u.team==='ally'?'#3b82f6':'#ef4444';
      ctx.beginPath();ctx.arc(sx,sy,Math.max(2,TW*sc*0.35),0,Math.PI*2);ctx.fill();
    });
    this._mmSc=sc;
    this.rMMvp();
  },
  rMMvp(){
    const ct=document.getElementById('map-container');
    const w=document.getElementById('iso-world');
    const wW=parseFloat(w.style.width),wH=parseFloat(w.style.height);
    if(!wW||!wH||!this._mmSc)return;
    const sc=this._mmSc;
    const vp=document.getElementById('mm-vp');
    const oL=parseFloat(w.style.left||0),oT=parseFloat(w.style.top||0);
    const vx=ct.scrollLeft-oL, vy=ct.scrollTop-oT;
    vp.style.left=Math.max(0,vx*sc)+'px';
    vp.style.top=Math.max(0,vy*sc)+'px';
    vp.style.width=Math.min(ct.clientWidth*sc, wW*sc)+'px';
    vp.style.height=Math.min(ct.clientHeight*sc, wH*sc)+'px';
  },
  mmClick(e){
    const cv=document.getElementById('mm-cv');
    const rect=cv.getBoundingClientRect();
    if(!this._mmSc)return;
    const sc=this._mmSc;
    const wx=(e.clientX-rect.left)/sc;
    const wy=(e.clientY-rect.top)/sc;
    const ct=document.getElementById('map-container');
    const w=document.getElementById('iso-world');
    const oL=parseFloat(w.style.left||0),oT=parseFloat(w.style.top||0);
    ct.scrollLeft=oL+wx-ct.clientWidth/2;
    ct.scrollTop=oT+wy-ct.clientHeight/2;
  },

  uUI(){const ti=document.getElementById('turn-indicator');ti.textContent=this.phase==='player'?'PLAYER':'ENEMY';ti.className=this.phase;
    const s=this.cStage,en=this.alive('enemy').length;
    const br=s?this.breached:0,blim=s?Math.ceil(s.tot/4):0;
    document.getElementById('stage-info').innerHTML=`STAGE ${s?s.id:1} <span style="color:var(--dim);font-size:9px">${s?t('stages.stage_'+s.id+'_name'):''}</span>
      <div class="si-turn">TURN ${this.turn} · ${t('battle.summon')} ${this.eSpwn}/${s?s.tot:'?'} · ${t('battle.remaining')} ${en}체 · <span style="color:${br>0?'#ef4444':'var(--dim)'}">
${t('battle.breach')} ${br}/${blim}</span></div>`},
  showUI(){this.rInfoPanel()},
  defI(){this.rInfoPanel()},
  rInfoPanel(){
    const p=document.getElementById('info-panel');
    const allies=this.units.filter(u=>u.hp>0&&u.team==='ally');
    const selId=this.sel?this.sel.id:(this.curUnit?this.curUnit.id:null);
    let html='';
    allies.forEach(u=>{
      const isSel=u.id===selId;
      const hpPct=Math.round(u.hp/u.mhp*100);
      const rn=RES_LABEL[u.resType]||'';
      const resPct=u.maxRes?Math.round(u.res/u.maxRes*100):0;
      const buffs=this.getBuffs(u);
      const buffHtml=buffs.map(b=>`<span class="buff-icon">${b.icon}</span>`).join('');
      html+=`<div class="info-card ally-card${isSel?' ip-sel':''}" data-uid="${u.id}">
        <div class="ic-top"><span class="ic-icon">${clsIcon(u.cls,14)}</span><span class="ic-name">${u.name}</span><span class="ic-class">${t('classes.'+u.cls)}</span></div>
        <div class="ic-bar-row"><span class="ic-blabel">HP</span><div class="ic-bar"><div class="ic-bfill ${hpPct<=25?'low':''}" style="width:${hpPct}%"></div></div><span class="ic-bval">${u.hp}/${u.mhp}</span></div>
        ${rn?`<div class="ic-bar-row"><span class="ic-blabel" style="color:${RES_COLOR[u.resType]}">${rn}</span><div class="ic-bar"><div class="ic-bfill" style="width:${resPct}%;background:${RES_COLOR[u.resType]}"></div></div><span class="ic-bval">${u.res}/${u.maxRes}</span></div>`:''}
        <div class="ic-stats"><span>ATK <b>${u.atk}</b></span><span>DEF <b>${u.def}</b></span><span>RNG <b>${u.range}</b></span></div>
        ${buffHtml?`<div class="ic-buffs">${buffHtml}</div>`:''}
      </div>`;
    });
    p.innerHTML=html;
    // 선택 유닛으로 자동 스크롤
    if(selId){const el=p.querySelector(`[data-uid="${selId}"]`);if(el)el.scrollIntoView({inline:'center',block:'nearest',behavior:'smooth'})}
  },
  // ── 적 유닛 정보 팝업 ──
  showEnemyPopup(u){
    this.hideEnemyPopup();
    const hpPct=Math.round(u.hp/u.mhp*100);
    const rn=RES_LABEL[u.resType]||'';
    const resPct=u.maxRes?Math.round(u.res/u.maxRes*100):0;
    const buffs=this.getBuffs(u);
    const buffHtml=buffs.map(b=>`<span class="buff-icon">${b.icon}</span>`).join('');
    const pop=document.createElement('div');
    pop.id='enemy-popup';
    pop.innerHTML=`
      <div class="ep-head"><span class="ep-icon">${clsIcon(u.cls,16)}</span><span class="ep-name">${u.name}</span><span class="ep-cls">${t('classes.'+u.cls)}</span></div>
      <div class="ep-bar"><span class="ep-blbl">HP</span><div class="ep-btrack"><div class="ep-bfill ${hpPct<=25?'low':''}" style="width:${hpPct}%"></div></div><span class="ep-bval">${u.hp}/${u.mhp}</span></div>
      ${rn?`<div class="ep-bar"><span class="ep-blbl" style="color:${RES_COLOR[u.resType]}">${rn}</span><div class="ep-btrack"><div class="ep-bfill" style="width:${resPct}%;background:${RES_COLOR[u.resType]}"></div></div><span class="ep-bval">${u.res}/${u.maxRes}</span></div>`:''}
      <div class="ep-stats"><span>ATK <b>${u.atk}</b></span><span>DEF <b>${u.def}</b></span><span>RNG <b>${u.range}</b></span></div>
      ${buffHtml?`<div class="ep-buffs">${buffHtml}</div>`:''}`;
    document.getElementById('iso-world').appendChild(pop);
    // 위치: 유닛 스프라이트 기준, 화면 넘어가면 아래쪽으로 표시
    const sx=this.uSX(u.x,u.y)+UCX;
    const sy=this.uSY(u.x,u.y)-10;
    pop.style.left=sx+'px';pop.style.top=sy+'px';
    requestAnimationFrame(()=>{
      const rect=pop.getBoundingClientRect();
      if(rect.top<0)pop.classList.add('below');
      pop.classList.add('show');
    });
    // 다른 곳 클릭/터치 시 즉시 닫기
    this._epClose=e=>{e.stopPropagation();this.hideEnemyPopup()};
    document.addEventListener('pointerdown',this._epClose,{capture:true,once:true});
  },
  hideEnemyPopup(){
    const old=document.getElementById('enemy-popup');
    if(old)old.remove();
    if(this._epClose){document.removeEventListener('pointerdown',this._epClose,{capture:true});this._epClose=null}
  },
  showWv(t){const b=document.getElementById('wave-banner');b.textContent=t;b.classList.add('show')},
  hideWv(){document.getElementById('wave-banner').classList.remove('show')},
  showRes(win,msg){const ov=document.getElementById('modal-overlay');
    this.onBattleEnd(win);
    const baseReward=this._baseReward||0;
    const bonusReward=this._bonusReward||0;
    const actualReward=baseReward+bonusReward;
    document.getElementById('modal-title').textContent=win?t('messages.victory'):t('messages.defeat');
    document.getElementById('modal-title').className=win?'win':'lose';
    const deadAllyCount=this._deadAllyUids.length;
    const autoRevived=this._autoRevivedCount||0;

    // 연습 모드 공지
    let sub='';
    if(this.practiceMode){
      sub+=`🎓 ${t('stage.practice_mode_active')}\n`;
      sub+=`<img src="image/icon/64x64/fc67.png" alt="Gold" style="width:14px;height:14px;vertical-align:middle;"> ${t('stage.reduced_gold')} (70%)\n`;
      sub+=`📊 ${t('stage.full_exp')} (100%)\n`;
      if(autoRevived>0)sub+=`❤ ${t('stage.auto_revived',{count: autoRevived})}\n`;
      sub+=`⚠️ ${t('stage.no_clear_recorded')}\n\n`;
    }

    sub+=msg;
    if(win&&actualReward)sub+=`\n<img src="image/icon/64x64/fc67.png" alt="Gold" style="width:16px;height:16px;vertical-align:middle;"> ${t('messages.reward')}: ${actualReward} Gold`;
    if(win&&this._firstClearBonus){sub+=`\n🎉 ${t('messages.first_clear_bonus')}: +${this._firstClearBonus} Gold`;this._firstClearBonus=0}
    if(win&&this._firstClearUnit){const fc=this._firstClearUnit,fd=JAB[fc.cls];sub+=`\n🎁 ${t('messages.first_clear_unit',{cls: t('classes.'+fc.cls)})}`;this._firstClearUnit=null}
    if(win&&this._droppedBook){sub+=`\n📕 ${t('academy.skillbook_drop', {skill: t('skills.'+this._droppedBook)})}`;this._droppedBook=null}
    if(deadAllyCount)sub+=`\n💀 전사자: ${deadAllyCount}명 (성소에서 부활 가능)`;
    if(this._expResults&&this._expResults.length){
      sub+=`\n\n${t('results.battle_detail', {kills: this._deadEnemyCount||0, exp: this._totalExp||0, survivors: this._expResults.length})}`;
      this._expResults.forEach(r=>{
        const ch=getChar(r.uid);if(!ch)return;
        const d=JAB[ch.cls];
        const charName = ch.customName || t('character.names')[ch.nameId] || d.icon;
        let line=`\n${clsIcon(ch.cls,16)} ${charName}: +${r.exp} EXP`;
        if(r.leveled>0)line+=` <img src="image/icon/64x64/fc675.png" alt="LvUp" style="width:14px;height:14px;vertical-align:middle;margin:0 2px;"> Lv.${r.prevLv}→${ch.lv}`;
        sub+=line;
      });
    }
    document.getElementById('modal-sub').innerHTML=sub.replace(/\n/g,'<br>');
    if(win)this.sfxVictory();else this.sfxDefeat();
    this.bgmStop();
    const bt=document.getElementById('modal-buttons');bt.innerHTML='';
    const lb=document.createElement('button');lb.className='modal-btn';lb.textContent=t('results.return_to_lobby');
    lb.onclick=()=>{ov.classList.remove('show');this.returnToLobby()};bt.appendChild(lb);
    if(win){const s=this.cStage,ns=s&&STAGES.find(v=>v.id===s.id+1);
      if(ns){const b=document.createElement('button');b.className='modal-btn secondary';b.textContent=t('results.next_stage');
        b.onclick=()=>{ov.classList.remove('show');this.goNextStage(ns)};bt.appendChild(b)}}
    ov.classList.add('show')},

  _sett:{bgmVol:0.6,sfxVol:0.8,bgmOn:true,sfxOn:true,speed:1,language:null},
  _sfxGainNode:null,
  loadSett(){try{const d=JSON.parse(localStorage.getItem('game_setting'));
    if(d){if(typeof d.bgmVol==='number')this._sett.bgmVol=d.bgmVol;
      if(typeof d.sfxVol==='number')this._sett.sfxVol=d.sfxVol;
      if(typeof d.bgmOn==='boolean')this._sett.bgmOn=d.bgmOn;
      if(typeof d.sfxOn==='boolean')this._sett.sfxOn=d.sfxOn;
      if(typeof d.speed==='number')this._sett.speed=d.speed;
      if(typeof d.language==='string')this._sett.language=d.language;
    }}catch(e){}},
  saveSett(){try{localStorage.setItem('game_setting',JSON.stringify(this._sett))}catch(e){}},
  toggleSettings(){const p=document.getElementById('settings-panel');if(!p)return;
    const b=document.getElementById('settings-backdrop');
    const opening=!p.classList.contains('show');
    p.classList.toggle('show');b.classList.toggle('show');
    if(opening)this.syncSettingsUI()},
  closeSettings(){const p=document.getElementById('settings-panel');if(p)p.classList.remove('show');
    const b=document.getElementById('settings-backdrop');if(b)b.classList.remove('show')},
  syncSettingsUI(){
    document.getElementById('sp-bgm-on').checked=this._sett.bgmOn;
    document.getElementById('sp-bgm').value=Math.round(this._sett.bgmVol*100);
    document.getElementById('sp-bgm-val').textContent=Math.round(this._sett.bgmVol*100);
    document.getElementById('sp-sfx-on').checked=this._sett.sfxOn;
    document.getElementById('sp-sfx').value=Math.round(this._sett.sfxVol*100);
    document.getElementById('sp-sfx-val').textContent=Math.round(this._sett.sfxVol*100);
    document.getElementById('sp-speed').value=Math.round(1/this._sett.speed*100);
    document.getElementById('sp-speed-val').textContent=this._sett.speed.toFixed(1)+'x';
  },
  setBGMOn(v){this._sett.bgmOn=v;
    if(v){if(!this._bgm&&!this.over)this.bgmStart()}
    else{this.bgmStop()}this.saveSett()},
  setSFXOn(v){this._sett.sfxOn=v;
    if(this._sfxGainNode)this._sfxGainNode.gain.setValueAtTime(v?this._sett.sfxVol:0,this.sfxCtx().currentTime);this.saveSett()},
  setBGMVol(v){this._sett.bgmVol=v/100;document.getElementById('sp-bgm-val').textContent=v;
    if(this._bgm&&this._bgm.master){this._bgm.master.gain.setValueAtTime(0.12*(v/100),this.sfxCtx().currentTime)}this.saveSett()},
  setSFXVol(v){this._sett.sfxVol=v/100;document.getElementById('sp-sfx-val').textContent=v;
    if(this._sfxGainNode&&this._sett.sfxOn)this._sfxGainNode.gain.setValueAtTime(v/100,this.sfxCtx().currentTime);this.saveSett()},
  setSpeed(v){const spd=v>0?100/v:1;this._sett.speed=spd;
    document.getElementById('sp-speed-val').textContent=spd.toFixed(1)+'x';this.saveSett()},
  surrender(){if(this.over)return;
    this.closeSettings();
    this.over=true;this.showRes(false,t('messages.surrender'))}
});
