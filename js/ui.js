Object.assign(G, {
  // ═══ Ally Nav ═══
  getBuffs(u){
    const buffs=[];
    // Terrain buff
    const t=this.ter[u.y]?this.ter[u.y][u.x]:null;
    if(t&&TI[t].buff){const b=TI[t].buff;buffs.push({icon:b.icon,type:b.type,turns:0})}
    // Fury max
    // 광폭 active
    // → skills.js에서 관리
    getSkillBuffs(u).forEach(b=>buffs.push(b));
    // Stealth bonus (assassin in forest)
    if(u.cls==='assassin'&&t==='forest')buffs.push({icon:'🌙',type:'buff',turns:0});
    // Status
    if(u.ha)buffs.push({icon:'✓',type:'debuff',turns:0});
    else if(u.waited)buffs.push({icon:'⏸',type:'neutral',turns:0});
    if(u.mo&&!u.ha)buffs.push({icon:'👣',type:'neutral',turns:0});
    return buffs;
  },
  rNav(){
    const nav=document.getElementById('ally-nav');
    const allAllies=this.units.filter(u=>u.team==='ally');
    nav.innerHTML='';
    allAllies.forEach(u=>{
      const dead=u.hp<=0;
      const isSel=this.sel&&this.sel.id===u.id;
      const d=CD[u.cls];
      const pct=dead?0:Math.round(u.hp/u.mhp*100);
      const hpColor=pct>60?'#22c55e':pct>30?'#eab308':'#ef4444';
      const buffs=dead?[]:this.getBuffs(u);

      const el=document.createElement('div');
      el.className='an-unit'+(dead?' dead':'')+(isSel?' selected':'')+(u.ha&&!dead?' acted-nav':'');
      
      let bh='';
      buffs.forEach(b=>{
        const tl=b.turns>0?`<span class="bf-turn">${b.turns}</span>`:'';
        bh+=`<span class="an-buff ${b.type}">${b.icon}${tl}</span>`;
      });

      const resColor=u.resType==='mana'?'#4488ff':u.resType==='energy'?'#f0c040':'#ff6644';
      const resPct=dead?0:(u.maxRes?Math.round(u.res/u.maxRes*100):0);

      const buffsDiv=bh?`<div class="an-buffs">${bh}</div>`:'';
      el.innerHTML=`${buffsDiv}<div class="an-vres"><div class="an-vres-fill" style="height:${resPct}%;background:${resColor}"></div></div><div class="an-vhp"><div class="an-vhp-fill" style="height:${pct}%;background:${hpColor}"></div></div><div class="an-icon">${clsIcon(u.cls,18)}</div>`;
      
      if(!dead)el.onclick=()=>{if(this.awPM)return;this.selU(u)};
      nav.appendChild(el);
    });
  },

  // ═══ Minimap ═══
  rMM(){
    const d=this.vDim();
    // Match iso-world coordinate system scaled down
    // Main world: isoX = (vc-vr)*TW + d.r*TW, isoY = (vc+vr)*TH
    // World bounds: x from 0..d.c-1, y from 0..d.r-1
    // min isoX when vc=0,vr=d.r-1 => -(d.r-1)*TW + d.r*TW = TW
    // max isoX when vc=d.c-1,vr=0 => (d.c-1)*TW + d.r*TW = (d.c+d.r-1)*TW
    // min isoY when vc=0,vr=0 => 0
    // max isoY when vc=d.c-1,vr=d.r-1 => (d.c+d.r-2)*TH
    const wW=(d.c+d.r)*TW+4;
    const wH=(d.c+d.r)*TH+80;
    // minimap scale: fit to ~80px wide
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

    // draw tiles - use same isoX/isoY scaled
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
    // draw units
    this.units.filter(u=>u.hp>0).forEach(u=>{
      const v=this.g2v(u.x,u.y);
      const ix=this.isoX(v.vc,v.vr)+TW; // center of tile
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
    // visible area in world coords
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
    document.getElementById('stage-info').innerHTML=`STAGE ${s?s.id:1} <span style="color:var(--dim);font-size:9px">${s?s.name:''}</span>
      <div class="si-turn">TURN ${this.turn} · 소환 ${this.eSpwn}/${s?s.tot:'?'} · 잔여 ${en}체 · <span style="color:${br>0?'#ef4444':'var(--dim)'}">돌파 ${br}/${blim}</span></div>`;
    document.getElementById('btn-end-turn').disabled=this.phase!=='player'},
  showUI(u){const p=document.getElementById('info-panel'),tc=u.team==='ally'?'ally-card':'enemy-card';
    let h=this.iCard(u,tc,true);if(u.team==='ally'){(u.role==='healer'?this.healT:this.atkT).forEach(t=>{
      const tu=this.uAt(t.x,t.y);if(tu)h+=this.iCard(tu,tu.team==='ally'?'ally-card':'enemy-card',false)})}p.innerHTML=h},
  iCard(u,cc,m){const d=CD[u.cls],p=Math.round(u.hp/u.mhp*100);
    const rl={'mana':'MP','energy':'EP','fury':'FP'};
    const rc={'mana':'#4488ff','energy':'#f0c040','fury':'#ff6644'};
    const rn=rl[u.resType]||'',rpct=u.maxRes?Math.round(u.res/u.maxRes*100):0;
    return`<div class="info-card ${cc}" ${m?'style="border-width:2px"':''}>
      <div class="ic-top"><span class="ic-icon">${clsIcon(u.cls,18)}</span><span class="ic-name">${d.name}</span><span class="ic-class">${u.team==='ally'?'아군':'적군'}</span></div>
      <div class="ic-stats"><span>HP <b>${u.hp}/${u.mhp}</b></span><span style="color:${rc[u.resType]}">${rn} <b>${u.res}/${u.maxRes}</b></span><span>ATK <b>${u.atk}</b></span><span>DEF <b>${u.def}</b></span><span>RNG <b>${u.range}</b></span></div></div>`},
  defI(){const a=this.alive('ally').length,e=this.alive('enemy').length;
    document.getElementById('info-panel').innerHTML=`<div style="display:flex;gap:12px;align-items:center;font-size:11px"><span style="color:var(--blue)">🛡 아군 ${a}명</span><span style="color:var(--red)">⚔ 적군 ${e}명</span><span style="color:var(--dim)">유닛을 터치하여 선택</span></div>`},
  showWv(t){const b=document.getElementById('wave-banner');b.textContent=t;b.classList.add('show')},
  hideWv(){document.getElementById('wave-banner').classList.remove('show')},
  showRes(win,msg){const ov=document.getElementById('modal-overlay');
    this.onBattleEnd(win);
    const reward=win?(50+(this.cStage?this.cStage.id*30:0)):0;
    document.getElementById('modal-title').textContent=win?t('messages.victory'):t('messages.defeat');
    document.getElementById('modal-title').className=win?'win':'lose';
    const deadAllies=this.units.filter(u=>u.team==='ally'&&u.hp<=0);
    let sub=msg;
    if(win&&reward)sub+=`\n🏅 보상: ${reward} Gold`;
    if(deadAllies.length)sub+=`\n💀 전사자: ${deadAllies.length}명 (성소에서 부활 가능)`;
    // 경험치 결과
    if(this._expResults&&this._expResults.length){
      sub+=`\n\n📈 처치 ${this._deadEnemyCount||0}체 · 총 ${this._totalExp||0} EXP (÷${this._expResults.length}명)`;
      this._expResults.forEach(r=>{
        const ch=ROSTER.getChar(r.uid);if(!ch)return;
        const d=CD[ch.cls];
        let line=`\n${d.icon} ${ch.name||d.name}: +${r.exp} EXP`;
        if(r.leveled>0)line+=` ⬆ Lv.${r.prevLv}→${ch.lv}`;
        sub+=line;
      });
    }
    document.getElementById('modal-sub').innerHTML=sub.replace(/\n/g,'<br>');
    if(win)this.sfxVictory();else this.sfxDefeat();
    this.bgmStop();
    const bt=document.getElementById('modal-buttons');bt.innerHTML='';
    const lb=document.createElement('button');lb.className='modal-btn';lb.textContent='로비로 돌아가기';
    lb.onclick=()=>{ov.classList.remove('show');this.returnToLobby()};bt.appendChild(lb);
    if(win){const s=this.cStage,ns=STAGES.find(v=>v.id===s.id+1);
      if(ns){const b=document.createElement('button');b.className='modal-btn secondary';b.textContent='다음 스테이지 ▶';
        b.onclick=()=>{ov.classList.remove('show');this.goNextStage(ns)};bt.appendChild(b)}}
    ov.classList.add('show')},

  // === Settings ===
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
  setSpeed(v){const spd=100/v;this._sett.speed=spd;
    document.getElementById('sp-speed-val').textContent=spd.toFixed(1)+'x';this.saveSett()},
  surrender(){if(this.over)return;
    this.closeSettings();
    this.over=true;this.showRes(false,'항복했습니다.')}
});
