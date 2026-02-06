const G={
  ter:[],units:[],nid:1,turn:1,phase:'player',
  sel:null,mvT:[],atkT:[],healT:[],
  awPM:false,skillMode:false,preMv:null,over:false,anim:false,
  cStage:null,eSpwn:0,eQ:[],cleared:new Set(),
  party:[],camDir:0,battleExp:{},traps:[],eFormPos:[],

  // Camera: remap grid(c,r) to view-space(vc,vr) based on rotation
  g2v(c,r){switch(this.camDir){
    case 0:return{vc:c,vr:r};case 1:return{vc:ROWS-1-r,vr:c};
    case 2:return{vc:COLS-1-c,vr:ROWS-1-r};case 3:return{vc:r,vr:COLS-1-c}}},
  v2g(vc,vr){switch(this.camDir){
    case 0:return{c:vc,r:vr};case 1:return{c:vr,r:ROWS-1-vc};
    case 2:return{c:COLS-1-vc,r:ROWS-1-vr};case 3:return{c:COLS-1-vr,r:vc}}},
  vDim(){return this.camDir%2===0?{c:COLS,r:ROWS}:{c:ROWS,r:COLS}},
  isoX(vc,vr){return(vc-vr)*TW+this.vDim().r*TW},
  isoY(vc,vr,z){return(vc+vr)*TH-(z||0)*ZH},
  // Pixel (relative to iso-world) -> grid(c,r), diamond hit test
  isoHit(px,py){
    const d=this.vDim(),oX=d.r*TW;
    // Reverse iso: px = (vc-vr)*TW + oX + TW (center), py = (vc+vr)*TH + TH (center)
    // vc+vr = (py)/TH,  vc-vr = (px-oX)/TW
    const fvc=((px-oX)/TW+(py)/TH)/2;
    const fvr=((py)/TH-(px-oX)/TW)/2;
    // Check nearest integer candidates (the click could be between tiles)
    let best=null,bestD=Infinity;
    for(let dvc=-1;dvc<=1;dvc++)for(let dvr=-1;dvr<=1;dvr++){
      const vc=Math.floor(fvc)+dvc, vr=Math.floor(fvr)+dvr;
      if(vc<0||vr<0||vc>=d.c||vr>=d.r)continue;
      // Diamond center
      const cx=this.isoX(vc,vr)+TW, cy=this.isoY(vc,vr,0)+TH;
      // Diamond test: |dx/TW| + |dy/TH| <= 1
      const dx=Math.abs(px-cx)/TW, dy=Math.abs(py-cy)/TH;
      if(dx+dy<=1){
        const dist=dx+dy;
        if(dist<bestD){bestD=dist;const g=this.v2g(vc,vr);best={c:g.c,r:g.r}}
      }
    }
    return best;
  },
  tSX(c,r){const v=this.g2v(c,r);return this.isoX(v.vc,v.vr)},
  tSY(c,r,z){const v=this.g2v(c,r);return this.isoY(v.vc,v.vr,z)},
  uSX(c,r){return this.tSX(c,r)+TW-UCX},
  uSY(c,r){const t=this.ter[r]?this.ter[r][c]:null;return this.tSY(c,r,t?TI[t].z:0)-22},

  rotCam(d){
    this.camDir=((this.camDir+d)%4+4)%4;
    document.querySelector('#cam-dir .cd-arrow').textContent=CARR[this.camDir];
    document.querySelector('#cam-dir .cd-label').textContent=CLAB[this.camDir];
    document.querySelectorAll('.unit-sprite').forEach(el=>el.style.transition='none');
    this.layW();this.rTer();this.rUnits();this.rMM();
    requestAnimationFrame(()=>requestAnimationFrame(()=>{
      document.querySelectorAll('.unit-sprite').forEach(el=>el.style.transition='');
    }));
    if(this.awPM&&this.sel)this.showAM(this.sel);
  },
  layW(){
    const d=this.vDim(),wW=(d.c+d.r)*TW+4,wH=(d.c+d.r)*TH+80;
    const w=document.getElementById('iso-world');w.style.width=wW+'px';w.style.height=wH+'px';
    const ct=document.getElementById('map-container'),cW=ct.clientWidth,cH=ct.clientHeight;
    w.style.left=Math.max(0,(cW-wW)/2)+'px';w.style.top=Math.max(0,(cH-wH)/2)+'px';
    const cv=document.getElementById('vfx-canvas');if(cv){cv.width=wW;cv.height=wH}
  },

  // Stage/Party: managed by lobby.js (openStage, _showStageSelect, selSt, etc.)

  // Init
  init(){
    this.genT();this.units=[];this.nid=1;this.turn=1;this.phase='player';
    this.sel=null;this.over=false;this.awPM=false;this.skillMode=false;this.skillMenuOpen=false;this.anim=false;this.camDir=0;
    this.breached=0;this.battleExp={};this.traps=[];this.eFormPos=[];
    document.querySelector('#cam-dir .cd-arrow').textContent=CARR[0];
    document.querySelector('#cam-dir .cd-label').textContent=CLAB[0];
    const w=document.getElementById('iso-world');
    w.querySelectorAll('.iso-tile,.unit-sprite,.float-text').forEach(e=>e.remove());
    for(let i=0;i<this.party.length;i++){const p=DEPLOY[i];this.addU('ally',this.party[i],p.x,p.y)}
    this.spawnW();this.layW();this.vfxInit();this.rTer();this.rUnits();this.uUI();this.defI();this.rMM();
    this.bgmStart();
    // Scroll camera to ally position
    setTimeout(()=>this.scrollToAllies(),50)},
  scrollToAllies(){
    const al=this.alive('ally');if(!al.length)return;
    let sx=0,sy=0;al.forEach(u=>{sx+=this.uSX(u.x,u.y);sy+=this.uSY(u.x,u.y)});
    sx/=al.length;sy/=al.length;
    const ct=document.getElementById('map-container');
    const w=document.getElementById('iso-world');
    const oL=parseFloat(w.style.left||0),oT=parseFloat(w.style.top||0);
    ct.scrollLeft=oL+sx-ct.clientWidth/2+UCX;
    ct.scrollTop=oT+sy-ct.clientHeight/2+UCX;
  },
  scrollToUnit(u){
    const ct=document.getElementById('map-container');
    const w=document.getElementById('iso-world');
    const oL=parseFloat(w.style.left||0),oT=parseFloat(w.style.top||0);
    const ux=this.uSX(u.x,u.y)+UCX, uy=this.uSY(u.x,u.y)+UCY*2;
    const tX=oL+ux-ct.clientWidth/2, tY=oT+uy-ct.clientHeight/2;
    ct.scrollTo({left:tX,top:tY,behavior:'smooth'});
  },
  // Enemy formation: defensive positioning based on class
  eFormation(enemies,boss){
    const form=[];
    let knights=[],melee=[],ranged=[],heal=[],sappers=[];
    // Categorize enemies
    enemies.forEach(cls=>{
      const d=CD[cls];
      if(cls==='knight')knights.push(cls);
      else if(d.role==='melee')melee.push(cls);
      else if(d.role==='ranged')ranged.push(cls);
      else if(d.role==='healer')heal.push(cls);
      if(cls==='sapper')sappers.push(cls)
    });
    // Formation rows from top (row 0-1: spawn) - enemies defend from row 2-4
    // Front line: row 4 (knights first, then melee)
    const frontLine=[];
    for(let c=2;c<=7;c++){if(!this.uAt(c,4)&&frontLine.length<(knights.length+melee.length))frontLine.push({x:c,y:4})}
    let idx=0;
    knights.forEach(k=>{if(idx<frontLine.length)form.push({cls:k,pos:frontLine[idx++]})});
    melee.forEach(m=>{if(idx<frontLine.length)form.push({cls:m,pos:frontLine[idx++]})});
    // Mid line: row 3 (remaining units)
    const midLine=[];
    for(let c=2;c<=7;c++){if(!this.uAt(c,3)&&midLine.length<ranged.length+heal.length+sappers.length)midLine.push({x:c,y:3})}
    idx=0;
    ranged.forEach(r=>{if(idx<midLine.length)form.push({cls:r,pos:midLine[idx++]})});
    heal.forEach(h=>{if(idx<midLine.length)form.push({cls:h,pos:midLine[idx++]})});
    sappers.forEach(s=>{if(idx<midLine.length)form.push({cls:s,pos:midLine[idx++]})});
    // Boss at center-back: row 2-3, col 4-5
    if(boss){form.push({cls:boss.cls,pos:{x:5,y:2},isBoss:true})}
    return form
  },
  genT(){this.ter=[];this.gateHP={};this.wallHP={};this.breached=0;
    // 스테이지별 타일 종류당 1개 variant 선택
    this.tileVar={};
    Object.keys(TILE_MAP).forEach(t=>{
      const v=TILE_MAP[t].variants;
      this.tileVar[t]=Math.floor(Math.random()*v.length);
    });
    // Ally wall row (row 14): cols 2-3,6-7 = wall, cols 4-5 = gate, rest = water
    const wallRow=(row)=>{const r=[];for(let c=0;c<COLS;c++){
      if(c>=2&&c<=3||c>=6&&c<=7){r.push('wall');this.wallHP[c+','+row]=200}
      else if(c>=4&&c<=5){r.push('gate');this.gateHP[c+','+row]=2}
      else r.push('water')}return r};
    // Moat row: water except cols 4-5 = plain (path to gate)
    const moatRow=()=>{const r=[];for(let c=0;c<COLS;c++){
      if(c>=4&&c<=5)r.push('plain');else r.push('water')}return r};
    for(let r=0;r<ROWS;r++){
      if(r===14){this.ter[r]=wallRow(r)}                // Ally wall only
      else if(r===13){this.ter[r]=moatRow()}             // Ally moat
      else if(r<=1||r>=11){                              // Rows 0-1 (enemy spawn), 11-12 (ally front) = plain
        this.ter[r]=[];for(let c=0;c<COLS;c++)this.ter[r][c]='plain'}
      else{this.ter[r]=[];for(let c=0;c<COLS;c++){
        const rn=Math.random();
        this.ter[r][c]=rn<.06?'rock':rn<.16?'hill':rn<.28?'forest':'plain'}}}},
  // addU: ally는 uid(보유 캐릭터), enemy는 cls+스테이지 배율
  addU(team,src,x,y){
    let cls,hp,mhp,atk,def,mv,rng,role,resType,maxRes,resRec,initRes,uid=0,lv=1;
    if(team==='ally'&&typeof src==='number'){
      // src = roster uid
      const bs=ROSTER.toBattleStats(src);
      if(!bs)return null;
      cls=bs.cls;hp=bs.hp;mhp=bs.mhp;atk=bs.atk;def=bs.def;mv=bs.move;rng=bs.range;
      role=bs.role;resType=bs.resType;maxRes=bs.maxRes;resRec=bs.resRec;initRes=bs.res;uid=bs.uid;lv=bs.lv;
    }else{
      // src = cls string (enemy or legacy)
      cls=src;const d=CD[cls],s=this.cStage;
      hp=d.base.hp;atk=d.base.atk;def=d.base.def;mv=d.base.move;rng=d.base.range;
      role=d.role;resType=d.res;maxRes=d.maxRes;resRec=d.resRec;
      if(team==='enemy'&&s){hp=Math.round(hp*s.sm.hp);atk=Math.round(atk*s.sm.atk)}
      mhp=hp;initRes=d.res==='mana'?maxRes:0;
    }
    const u={id:this.nid++,uid,team,cls,lv,x,y,hp,mhp,atk,def,move:mv,range:rng,role,
      res:initRes,maxRes,resType,resRec,
      hm:false,ha:false,waited:false,mo:false,furyBuff:0,stunned:0};
    if(team==='enemy'){u.origSpawn={x,y}}
    this.units.push(u);return u},
  uAt(x,y){const all=this.units.filter(u=>u.x===x&&u.y===y&&u.hp>0);
    if(all.length<=1)return all[0]||null;
    // 겹침: 은신 암살자보다 적을 우선 반환
    return all.find(u=>u.team==='enemy')||all[0]},
  alive(t){return this.units.filter(u=>u.team===t&&u.hp>0)},
  // Trap system — team field: 'enemy' traps hit allies, 'ally' traps hit enemies
  chkTrap(u){
    const enemy=u.team==='ally'?'enemy':'ally';
    const trap=this.traps.find(t=>t.x===u.x&&t.y===u.y&&t.team===enemy);
    if(trap){
      u.hp=Math.max(0,u.hp-trap.dmg);u.stunned=Math.max(u.stunned,2);
      this.traps=this.traps.filter(t=>t!==trap);
      this.floatT(u.x,u.y,`함정! -${trap.dmg}`,'damage');this.floatT(u.x,u.y,'2턴 이동불가','damage');
      this.vfxSpawn(this.uSX(u.x,u.y)+UCX,this.uSY(u.x,u.y)+UCY,{count:8,colors:['#f84','#f80','#ff4'],shape:'spark',speed:3,spread:8,decay:0.03,size:2});
      return true}
    return false
  },

  spawnW(){if(!this.cStage)return;const s=this.cStage,rem=s.tot-this.eSpwn;if(rem<=0)return;
    const cnt=Math.min(s.spw,rem,this.eQ.length);
    // First wave: Boss + formation positioning (rows 2-4)
    if(this.eSpwn===0&&s.boss){
      // Spawn boss at center-back (row 2, col 4-5)
      const bu=this.addU('enemy',s.boss.cls,5,2);
      if(bu){bu.isBoss=true;bu.name=s.boss.name;bu.origSpawn={x:5,y:2};}this.eSpwn++;
      // Spawn regular enemies in formation rows (2-4)
      const posL=[[2,4],[3,4],[4,4],[5,4],[6,4],[7,4],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3]];
      let pidx=0;
      while(this.eSpwn<cnt&&pidx<posL.length&&this.eQ.length){
        const c=this.eQ.shift();if(!c)break;
        const p=posL[pidx++];
        if(!this.uAt(p[0],p[1])){this.addU('enemy',c,p[0],p[1]);this.eSpwn++}
      }
    }else{
      // Subsequent waves: random spawn at rows 0-1
      const op=[];
      for(let c=0;c<COLS;c++)if(!this.uAt(c,0))op.push({x:c,y:0});
      if(op.length<cnt)for(let c=0;c<COLS;c++)if(!this.uAt(c,1))op.push({x:c,y:1});
      shuffle(op);
      for(let i=0;i<Math.min(cnt,op.length);i++){const c=this.eQ.shift();if(!c)break;
        this.addU('enemy',c,op[i].x,op[i].y);this.eSpwn++}
    }},

  // Pathfinding
  mvC(u){if(u.stunned>0)return[];const res=[],vis=new Map(),q=[{x:u.x,y:u.y,c:0}],K=(a,b)=>a+','+b;
    const isStealth=u.cls==='assassin'&&u.team==='ally'&&this.ter[u.y]&&this.ter[u.y][u.x]==='forest';
    vis.set(K(u.x,u.y),0);
    while(q.length){const{x,y,c}=q.shift();
      const occ=this.uAt(x,y);
      if(c>0&&!occ)res.push({x,y});
      // 은신 암살자: 적이 있는 숲 타일도 이동 가능 (겹침)
      if(c>0&&occ&&occ.team!==u.team&&isStealth&&this.ter[y]&&this.ter[y][x]==='forest')res.push({x,y});
      for(const[dx,dy]of[[0,-1],[0,1],[-1,0],[1,0]]){const nx=x+dx,ny=y+dy;
        if(nx<0||nx>=COLS||ny<0||ny>=ROWS)continue;const ti=TI[this.ter[ny][nx]];if(!ti.pass)continue;
        const o=this.uAt(nx,ny);
        if(o&&o.team!==u.team){
          // 은신 암살자: 적이 있는 숲으로의 진입은 허용 (경로 확장은 차단)
          if(isStealth&&this.ter[ny][nx]==='forest'){
            const nc=c+ti.cost;if(nc<=u.move){const k=K(nx,ny);if(!vis.has(k)||vis.get(k)>nc){vis.set(k,nc)}}}
          continue}
        const nc=c+ti.cost;if(nc>u.move)continue;
        const k=K(nx,ny);if(!vis.has(k)||vis.get(k)>nc){vis.set(k,nc);q.push({x:nx,y:ny,c:nc})}}}return res},
  atkC(u){const c=[];for(let r=0;r<ROWS;r++)for(let x=0;x<COLS;x++)if(mh(u.x,u.y,x,r)<=u.range&&!(x===u.x&&r===u.y))c.push({x,y:r});return c},
  eMvC(u){const res=[],vis=new Map(),q=[{x:u.x,y:u.y,c:0}],K=(a,b)=>a+','+b;vis.set(K(u.x,u.y),0);
    while(q.length){const{x,y,c}=q.shift();
      const occ=this.uAt(x,y);if(c>0&&!occ)res.push({x,y});
      for(const[dx,dy]of[[0,-1],[0,1],[-1,0],[1,0]]){const nx=x+dx,ny=y+dy;
        if(nx<0||nx>=COLS||ny<0||ny>=ROWS)continue;const ti=TI[this.ter[ny][nx]];if(!ti.pass)continue;
        const o=this.uAt(nx,ny);if(o&&o.team!==u.team)continue;
        const nc=c+ti.cost;if(nc>u.move)continue;
        const k=K(nx,ny);if(!vis.has(k)||vis.get(k)>nc){vis.set(k,nc);q.push({x:nx,y:ny,c:nc})}}}return res},

};
