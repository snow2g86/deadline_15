Object.assign(G, {
  // Render
  rTer(){const w=document.getElementById('iso-world');
    // 기존 타일 요소 맵핑 (DOM 재사용)
    const existingTiles=new Map();w.querySelectorAll('.iso-tile').forEach(el=>{const pos=el.dataset.pos;if(pos)existingTiles.set(pos,el)});
    const tilesNeeded=new Set();

    for(let r=0;r<ROWS;r++)for(let c=0;c<COLS;c++){const t=this.ter[r][c],ti=TI[t];
      const pos=`${c},${r}`;tilesNeeded.add(pos);
      let hl='';if(this.sel){if(this.mvT.some(m=>m.x===c&&m.y===r))hl='move';
        else if(this.atkT.some(a=>a.x===c&&a.y===r))hl='attack';
        else if(this.healT.some(h=>h.x===c&&h.y===r))hl='heal';
        if(this.sel.x===c&&this.sel.y===r)hl='selected'}
      const seed=r*COLS+c;
      const vi=this.tileVar&&this.tileVar[t]!==undefined?this.tileVar[t]:0;
      const svg=tSVG(TW,TH,ti.tc,ti.lc,ti.rc,ti.z,hl,t,seed,vi);

      // 기존 요소 재사용 또는 새로 생성
      let tile=existingTiles.get(pos);if(!tile){tile=document.createElement('div');tile.className='iso-tile';tile.dataset.pos=pos;w.appendChild(tile)}
      tile.style.left=this.tSX(c,r)+'px';tile.style.top=this.tSY(c,r,ti.z)+'px';
      tile.style.width=(TW*2)+'px';tile.style.height=(TH*2+ti.z*ZH+2)+'px';
      const v=this.g2v(c,r);tile.style.zIndex=v.vc+v.vr;tile.innerHTML=svg;
      tile.classList.remove('hl-move','hl-attack','hl-heal','hl-selected');
      if(hl==='move')tile.classList.add('hl-move');
      else if(hl==='attack')tile.classList.add('hl-attack');
      else if(hl==='heal')tile.classList.add('hl-heal');
      else if(hl==='selected')tile.classList.add('hl-selected')}

    // 불필요한 타일 삭제
    existingTiles.forEach((el,pos)=>{if(!tilesNeeded.has(pos))el.remove()});
    w.querySelectorAll('.tree-obj').forEach(e=>e.remove());},

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
    // 채널링 중: 해제 버튼만
    if(u.channeling){
      this.hideAllMenuButtons();
      document.getElementById('btn-cancel').style.display='none';
      const btn=document.createElement('button');btn.className='am-skill';
      btn.textContent=t('messages.unlock');
      btn.onclick=()=>G.cancelChannel();
      const btnDash=document.getElementById('btn-dash');
      m.insertBefore(btn,btnDash);
      btnDash.style.display='none';
      m.classList.add('show');return}
    // 스킬 서브 메뉴 상태
    if(this.skillMenuOpen){this.showSkillSubMenu(u);return}
    // 메인 메뉴
    this.showMainMenu(u)},
  showMainMenu(u){const m=document.getElementById('action-menu');
    // 동적 스킬 버튼 제거
    m.querySelectorAll('.am-skill').forEach(e=>e.remove());
    // 1. 이동 버튼: 아직 유닛이 이동하지 않았을 경우
    document.getElementById('btn-move').style.display=
      (!u.hm&&!u.mo)?'':'none';
    // 2. 공격 버튼: 유닛이 행동 완료 상태가 아닐 경우
    const btnAttack=document.getElementById('btn-attack');
    if(u.role==='healer'){
      btnAttack.textContent=t('messages.heal');
      btnAttack.style.display=(!u.ha&&this.healT.length>0)?'':'none'}
    else{
      btnAttack.textContent=t('messages.attack');
      btnAttack.style.display=(!u.ha&&this.atkT.length>0)?'':'none'}
    // 3. 스킬 버튼: 자원(마나, 기력, 분노)이 충분한 경우
    const skills=getSkills(u.cls);
    const hasUsableSkill=!u.ha&&skills.some(sk=>this.canUseSkill(u,sk));
    document.getElementById('btn-skill').style.display=hasUsableSkill?'':'none';
    // 4. 아이템 버튼: 추후 개발 (비활성화)
    document.getElementById('btn-item').style.display='none';
    // 5. 대기 버튼: 상시 활성화
    const btnDash=document.getElementById('btn-dash');
    btnDash.textContent=t('messages.wait');
    btnDash.style.display='';
    // 6. 취소 버튼: 유닛 이동 후
    const btnCancel=document.getElementById('btn-cancel');
    btnCancel.textContent=t('messages.cancel');
    btnCancel.style.display=this.preMv?'':'none';
    btnCancel.onclick=()=>G.actCancel();
    m.classList.add('show')},
  showSkillSubMenu(u){const m=document.getElementById('action-menu');
    // 기존 버튼 숨김
    this.hideAllMenuButtons();
    // 동적 스킬 버튼 제거 후 재생성
    m.querySelectorAll('.am-skill').forEach(e=>e.remove());
    const skills=getSkills(u.cls);
    const btnDash=document.getElementById('btn-dash');
    // 보유 스킬: 자원이 충분한 경우 활성화, 부족한 경우 디저블 처리
    skills.forEach((sk,idx)=>{
      const btn=document.createElement('button');btn.className='am-skill';
      btn.textContent=sk.icon+' '+sk.name;
      // 자원 충분 여부 확인
      let enabled=this.canUseSkill(u,sk);
      btn.disabled=!enabled;
      btn.onclick=()=>G.actSkill(idx);
      m.insertBefore(btn,btnDash)});
    // 대시 버튼 숨김
    btnDash.style.display='none';
    // 취소 버튼: 상시 활성화 - 클릭시 행동 UI로 전환
    const btnCancel=document.getElementById('btn-cancel');
    btnCancel.textContent='↩ 취소';
    btnCancel.style.display='';
    btnCancel.onclick=()=>G.hideSkillMenu();
    m.classList.add('show')},
  hideAllMenuButtons(){
    ['btn-move','btn-attack','btn-skill','btn-item','btn-dash','btn-cancel'].forEach(id=>{
      document.getElementById(id).style.display='none'})},
  canUseSkill(u,sk){
    let enabled=u.res>=sk.cost&&!u.ha;
    // 암살: 은신+겹침 추가 조건
    if(sk.id==='assassin_assassinate'){
      const overlapping=isStealthed(u)&&this.units.some(v=>
        v.x===u.x&&v.y===u.y&&v.team==='enemy'&&v.hp>0);
      enabled=enabled&&overlapping}
    // 소환 스킬: 소환 제한 체크
    if(sk.id.startsWith('summoner_summon_')){
      const maxSummons=1;
      const currentSummons=this.units.filter(s=>s.isSummon&&s.summonerId===u.id);
      if(currentSummons.length>=maxSummons){enabled=false}}
    return enabled},
  hideAM(){document.getElementById('action-menu').classList.remove('show')},
});
