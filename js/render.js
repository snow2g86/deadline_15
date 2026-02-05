Object.assign(G, {
  // Render
  rTer(){const w=document.getElementById('iso-world');w.querySelectorAll('.iso-tile').forEach(e=>e.remove());
    for(let r=0;r<ROWS;r++)for(let c=0;c<COLS;c++){const t=this.ter[r][c],ti=TI[t];
      let hl='';if(this.sel){if(this.mvT.some(m=>m.x===c&&m.y===r))hl='move';
        else if(this.atkT.some(a=>a.x===c&&a.y===r))hl='attack';
        else if(this.healT.some(h=>h.x===c&&h.y===r))hl='heal';
        if(this.sel.x===c&&this.sel.y===r)hl='selected'}
      const seed=r*COLS+c;
      const svg=tSVG(TW,TH,ti.tc,ti.lc,ti.rc,ti.z,hl,t,seed);
      const tile=document.createElement('div');tile.className='iso-tile';
      tile.style.left=this.tSX(c,r)+'px';tile.style.top=this.tSY(c,r,ti.z)+'px';
      tile.style.width=(TW*2)+'px';tile.style.height=(TH*2+ti.z*ZH+2)+'px';
      const v=this.g2v(c,r);tile.style.zIndex=v.vc+v.vr;tile.innerHTML=svg;
      if(hl==='move')tile.classList.add('hl-move');
      else if(hl==='attack')tile.classList.add('hl-attack');
      else if(hl==='heal')tile.classList.add('hl-heal');
      w.appendChild(tile)}
    // Tree objects on forest tiles (skip if tileset loaded — forest tiles include vegetation)
    w.querySelectorAll('.tree-obj').forEach(e=>e.remove());
    if(tileImgsLoaded)return;
    for(let r=0;r<ROWS;r++)for(let c=0;c<COLS;c++){if(this.ter[r][c]!=='forest')continue;
      const seed=r*COLS+c;const sr=s=>{s=(s*9301+49297)%233280;return s/233280};
      let s0=seed+77,rn=()=>{s0=sr(s0+31);return s0};
      // Tile center pixel position (diamond top surface center)
      const tcx=this.tSX(c,r)+TW;
      const tcy=this.tSY(c,r,0)+TH;
      // 2~4 trees per tile, spread around center
      const cnt=2+Math.floor(rn()*3);
      for(let i=0;i<cnt;i++){
        const ang=rn()*Math.PI*2;
        const dist=rn()*TW*.45;
        const ox=Math.cos(ang)*dist;
        const oy=Math.sin(ang)*dist*.5;// compress Y for isometric
        const sc=.55+rn()*.5;
        const trH=Math.round(20*sc);
        const el=document.createElement('div');el.className='tree-obj';
        const tW=20,tH=trH+8;
        el.style.cssText=`position:absolute;pointer-events:none;width:${tW}px;height:${tH}px;`;
        el.style.left=(tcx+ox-tW/2)+'px';
        el.style.top=(tcy+oy-tH)+'px';
        const v=this.g2v(c,r);el.style.zIndex=50+v.vc+v.vr;
        const trunk=Math.round(6*sc);
        const crH=Math.round(14*sc);
        const crW=Math.round(16*sc);
        const g1=rn()>.5?'#1a5c28':'#1e6630';
        const g2=rn()>.5?'#0f3a18':'#134420';
        const g3=rn()>.5?'#2a7a38':'#248830';
        el.innerHTML=`<svg width="${tW}" height="${tH}" xmlns="http://www.w3.org/2000/svg">
          <rect x="${tW/2-1.5}" y="${tH-trunk}" width="3" height="${trunk}" rx="1" fill="#3a2818"/>
          <rect x="${tW/2-1}" y="${tH-trunk}" width="2" height="${trunk}" rx=".5" fill="#4a3420"/>
          <ellipse cx="${tW/2}" cy="${tH-trunk-crH*.35}" rx="${crW*.5}" ry="${crH*.5}" fill="${g2}"/>
          <ellipse cx="${tW/2-1}" cy="${tH-trunk-crH*.45}" rx="${crW*.42}" ry="${crH*.42}" fill="${g1}"/>
          <ellipse cx="${tW/2+1.5}" cy="${tH-trunk-crH*.55}" rx="${crW*.32}" ry="${crH*.35}" fill="${g3}"/>
          <ellipse cx="${tW/2-.5}" cy="${tH-trunk-crH*.65}" rx="${crW*.22}" ry="${crH*.25}" fill="${g1}" opacity=".7"/>
        </svg>`;
        w.appendChild(el)}}},

  rUnits(){const w=document.getElementById('iso-world'),al=this.units.filter(u=>u.hp>0),ids=new Set();
    const resClr=u=>u.resType==='mana'?'#4488ff':u.resType==='energy'?'#f0c040':'#ff6644';
    al.forEach(u=>{ids.add('u-'+u.id);let el=document.getElementById('u-'+u.id);
      if(!el){el=document.createElement('div');el.id='u-'+u.id;el.className=`unit-sprite ${u.team} spawning`;
        setTimeout(()=>el.classList.remove('spawning'),450);
        el.innerHTML=`<div class="u-icon">${clsIcon(u.cls,28)}</div><div class="u-shadow"></div><div class="hp-bg"><div class="hp-fill"></div></div><div class="mp-bg"><div class="mp-fill"></div></div>`;
        w.appendChild(el)}
      el.style.width=UW+'px';el.style.height=UH+'px';el.style.left=this.uSX(u.x,u.y)+'px';el.style.top=this.uSY(u.x,u.y)+'px';
      const v=this.g2v(u.x,u.y);el.style.zIndex=100+v.vc+v.vr;
      el.querySelector('.hp-fill').style.width=`${(u.hp/u.mhp)*100}%`;
      const mpFill=el.querySelector('.mp-fill');
      mpFill.style.width=`${u.maxRes?(u.res/u.maxRes)*100:0}%`;
      mpFill.style.background=resClr(u);
      const isSel=this.sel&&this.sel.id===u.id;
      el.classList.toggle('acted',u.team==='ally'&&u.ha&&!isSel);el.classList.remove('ally','enemy');el.classList.add(u.team);
      el.classList.toggle('stealthed',isStealthed(u));el.classList.toggle('stunned',u.stunned>0);
      // stunned 카운트 표시
      let stunLabel=el.querySelector('.stun-label');if(u.stunned>0){if(!stunLabel){stunLabel=document.createElement('div');stunLabel.className='stun-label';el.appendChild(stunLabel)}stunLabel.textContent=u.stunned}else if(stunLabel)stunLabel.remove();
      // 소환수 턴 카운트 표시
      if(u.isSummon&&u.summonTurns!==undefined){
        let turnLabel=el.querySelector('.summon-turns');
        if(!turnLabel){
          turnLabel=document.createElement('div');
          turnLabel.className='summon-turns';
          turnLabel.style.cssText='position:absolute;top:-8px;right:-8px;background:#8b5cf6;color:#fff;border-radius:50%;width:20px;height:20px;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:bold;border:2px solid #fff;z-index:10;';
          el.appendChild(turnLabel)
        }
        turnLabel.textContent=u.summonTurns
      }else{
        const turnLabel=el.querySelector('.summon-turns');
        if(turnLabel)turnLabel.remove()
      }});
    [...w.querySelectorAll('.unit-sprite')].forEach(el=>{if(!ids.has(el.id))el.remove()});
    this.rMM();this.rNav()},

  floatT(x,y,t,tp){const w=document.getElementById('iso-world'),el=document.createElement('div');
    el.className=`float-text ${tp}`;el.textContent=t;el.style.left=(this.uSX(x,y)+UCX/2)+'px';el.style.top=(this.uSY(x,y)-8)+'px';el.style.zIndex=500;
    w.appendChild(el);setTimeout(()=>el.remove(),950)},
  showAM(u){const m=document.getElementById('action-menu');m.style.left=(this.uSX(u.x,u.y)+UW+2)+'px';
    m.style.top=this.uSY(u.x,u.y)+'px';m.style.zIndex=600;
    document.getElementById('btn-cancel').style.display=this.preMv?'':'none';
    // 기존 단일 스킬 버튼 숨김
    document.getElementById('btn-skill').style.display='none';
    // 동적 스킬 버튼 제거 후 재생성
    m.querySelectorAll('.am-skill').forEach(e=>e.remove());
    const wait=document.getElementById('btn-wait');
    // 채널링 중: "해제" 버튼만 표시
    if(u.channeling){
      document.getElementById('btn-cancel').style.display='none';
      const btn=document.createElement('button');btn.className='am-skill';
      btn.textContent='🔓 해제';
      btn.onclick=()=>G.cancelChannel();
      m.insertBefore(btn,wait);
      wait.style.display='none';
      m.classList.add('show');return}
    wait.style.display='';
    const skills=getSkills(u.cls);
    skills.forEach((sk,idx)=>{
      const btn=document.createElement('button');btn.className='am-skill';
      btn.textContent=sk.icon+' '+sk.name;
      // 활성화 조건
      let enabled=u.res>=sk.cost&&!u.ha;
      // 암살: 은신+겹침 추가 조건
      if(sk.id==='assassin_assassinate'){
        const overlapping=isStealthed(u)&&this.units.some(v=>v.x===u.x&&v.y===u.y&&v.team==='enemy'&&v.hp>0);
        enabled=enabled&&overlapping;
      }
      // 소환 스킬: 소환 제한 체크
      if(sk.id.startsWith('summoner_summon_')){
        const maxSummons=1;
        const currentSummons=G.units.filter(s=>s.isSummon&&s.summonerId===u.id);
        if(currentSummons.length>=maxSummons){
          enabled=false;
          btn.title=`소환 한계 (${currentSummons.length}/${maxSummons})`;
        }
      }
      btn.disabled=!enabled;
      btn.onclick=()=>G.actSkill(idx);
      m.insertBefore(btn,wait);
    });
    m.classList.add('show')},
  hideAM(){document.getElementById('action-menu').classList.remove('show')},
});
