Object.assign(G, {
  // ═══ VFX System ═══
  vfxParts:[],vfxRaf:null,
  vfxInit(){
    const cv=document.getElementById('vfx-canvas');
    const w=document.getElementById('iso-world');
    cv.width=parseInt(w.style.width)||2000;cv.height=parseInt(w.style.height)||2000;
  },
  vfxSpawn(x,y,opts){
    const cnt=opts.count||8;
    for(let i=0;i<cnt;i++){
      this.vfxParts.push({
        x:x+(Math.random()-.5)*(opts.spread||10),
        y:y+(Math.random()-.5)*(opts.spread||10),
        vx:(Math.random()-.5)*(opts.speed||2),
        vy:opts.vy!==undefined?(opts.vy+(Math.random()-.5)):(-Math.random()*(opts.speed||2)),
        life:1,decay:opts.decay||(0.015+Math.random()*0.02),
        size:opts.size||(2+Math.random()*3),
        color:opts.colors[Math.floor(Math.random()*opts.colors.length)],
        shape:opts.shape||'circle',
        gravity:opts.gravity||0,
        trail:opts.trail||false,
        rotation:Math.random()*Math.PI*2,
        rotSpd:(Math.random()-.5)*0.2
      });
    }
    if(!this.vfxRaf)this.vfxLoop();
  },
  vfxLoop(){
    const cv=document.getElementById('vfx-canvas');if(!cv)return;
    const ctx=cv.getContext('2d');ctx.clearRect(0,0,cv.width,cv.height);
    for(let i=this.vfxParts.length-1;i>=0;i--){
      const p=this.vfxParts[i];
      p.x+=p.vx;p.y+=p.vy;p.vy+=p.gravity;p.life-=p.decay;p.rotation+=p.rotSpd;
      if(p.life<=0){this.vfxParts.splice(i,1);continue}
      ctx.save();ctx.globalAlpha=p.life;ctx.fillStyle=p.color;
      ctx.translate(p.x,p.y);ctx.rotate(p.rotation);
      if(p.shape==='circle'){ctx.beginPath();ctx.arc(0,0,p.size*p.life,0,Math.PI*2);ctx.fill()}
      else if(p.shape==='star'){this.drawStar(ctx,0,0,p.size*p.life)}
      else if(p.shape==='slash'){ctx.strokeStyle=p.color;ctx.lineWidth=p.size*p.life*0.6;ctx.lineCap='round';
        ctx.beginPath();ctx.moveTo(-p.size*2,p.size*2);ctx.lineTo(p.size*2,-p.size*2);ctx.stroke()}
      else if(p.shape==='spark'){ctx.strokeStyle=p.color;ctx.lineWidth=1;ctx.beginPath();
        ctx.moveTo(0,0);ctx.lineTo(-p.vx*3,-p.vy*3);ctx.stroke();
        ctx.beginPath();ctx.arc(0,0,p.size*p.life*0.5,0,Math.PI*2);ctx.fill()}
      else if(p.shape==='ring'){ctx.strokeStyle=p.color;ctx.lineWidth=1.5*p.life;
        ctx.beginPath();ctx.arc(0,0,p.size*(1-p.life)*3+2,0,Math.PI*2);ctx.stroke()}
      else if(p.shape==='arrow'){ctx.strokeStyle=p.color;ctx.lineWidth=1.5*p.life;ctx.lineCap='round';
        ctx.beginPath();ctx.moveTo(0,p.size*3);ctx.lineTo(0,-p.size*3);
        ctx.moveTo(-p.size,-p.size);ctx.lineTo(0,-p.size*3);ctx.lineTo(p.size,-p.size);ctx.stroke()}
      else if(p.shape==='diamond'){ctx.beginPath();const s=p.size*p.life;
        ctx.moveTo(0,-s);ctx.lineTo(s,0);ctx.lineTo(0,s);ctx.lineTo(-s,0);ctx.closePath();ctx.fill()}
      ctx.restore();
    }
    if(this.vfxParts.length)this.vfxRaf=requestAnimationFrame(()=>this.vfxLoop());
    else{this.vfxRaf=null;ctx.clearRect(0,0,cv.width,cv.height)}
  },
  drawStar(ctx,x,y,r){ctx.beginPath();for(let i=0;i<5;i++){
    ctx.lineTo(x+r*Math.cos(i*1.256-.785),y+r*Math.sin(i*1.256-.785));
    ctx.lineTo(x+r*.4*Math.cos(i*1.256+.628-.785),y+r*.4*Math.sin(i*1.256+.628-.785))}ctx.closePath();ctx.fill()},

  // Class-specific attack VFX
  vfxAtk(attacker,target){
    const ax=this.uSX(attacker.x,attacker.y)+UCX,ay=this.uSY(attacker.x,attacker.y)+UCY;
    const tx=this.uSX(target.x,target.y)+UCX,ty=this.uSY(target.x,target.y)+UCY;
    const cls=attacker.cls;
    if(cls==='warrior'){// Slash
      this.vfxSpawn(tx,ty,{count:12,colors:['#fff','#aaddff','#88bbff'],shape:'slash',speed:3,spread:12,decay:0.04,size:4});
      this.vfxSpawn(tx,ty,{count:6,colors:['#ffffffcc','#aaddffcc'],shape:'spark',speed:4,spread:8,decay:0.03,size:2});
    }else if(cls==='knight'){// Heavy impact
      this.vfxSpawn(tx,ty,{count:15,colors:['#ffcc44','#ff8800','#ffffff'],shape:'circle',speed:2,spread:6,decay:0.02,size:4,gravity:0.1});
      this.vfxSpawn(tx,ty,{count:3,colors:['#ffffff88'],shape:'ring',speed:0,spread:2,decay:0.02,size:12});
    }else if(cls==='assassin'){// Quick multi-slash + afterimage
      for(let i=0;i<3;i++)setTimeout(()=>{
        this.vfxSpawn(tx+(Math.random()-0.5)*10,ty+(Math.random()-0.5)*10,{count:6,colors:['#cc44ff','#ff44cc','#ffffff'],shape:'slash',speed:4,spread:8,decay:0.05,size:3})},i*60);
      this.vfxSpawn(ax,ay,{count:8,colors:['#cc44ff44','#8844ff44'],shape:'diamond',speed:1.5,spread:15,decay:0.03,size:5});
    }else if(cls==='mage'){// Magic circle + burst
      this.vfxSpawn(tx,ty,{count:4,colors:['#4488ff55'],shape:'ring',speed:0,spread:4,decay:0.012,size:16});
      this.vfxSpawn(tx,ty,{count:20,colors:['#4488ff','#88aaff','#aaccff','#ffffff'],shape:'star',speed:3,spread:8,decay:0.025,size:3});
      this.vfxSpawn(tx,ty,{count:8,colors:['#4488ff','#ffffff'],shape:'spark',speed:5,spread:4,decay:0.02,size:2});
    }else if(cls==='archer'){// Arrow trail
      const dx=tx-ax,dy=ty-ay,dist=Math.sqrt(dx*dx+dy*dy);
      const steps=Math.max(5,Math.floor(dist/12));
      for(let i=0;i<steps;i++){const t=i/steps;
        setTimeout(()=>this.vfxSpawn(ax+dx*t,ay+dy*t,{count:2,colors:['#ffdd88','#ffffff88'],shape:'spark',speed:1,spread:3,decay:0.06,size:1.5}),i*20)}
      setTimeout(()=>this.vfxSpawn(tx,ty,{count:8,colors:['#ffdd44','#ff8844','#ffffff'],shape:'spark',speed:3,spread:6,decay:0.03,size:2}),steps*20);
    }else if(cls==='priest'){// Attack (rare but possible)
      this.vfxSpawn(tx,ty,{count:10,colors:['#ffffff','#ffffaa'],shape:'star',speed:2,spread:10,decay:0.025,size:3});
    }
  },

  // Heal VFX
  vfxHeal(target){
    const tx=this.uSX(target.x,target.y)+UCX,ty=this.uSY(target.x,target.y)+UCY;
    this.vfxSpawn(tx,ty,{count:18,colors:['#44ff88','#88ffaa','#aaffcc','#ffffff'],shape:'circle',
      speed:1.5,spread:14,decay:0.018,size:3,vy:-1.5,gravity:-0.02});
    this.vfxSpawn(tx,ty,{count:5,colors:['#44ff8844'],shape:'ring',speed:0,spread:3,decay:0.015,size:14});
    this.vfxSpawn(tx,ty,{count:8,colors:['#aaffcc','#ffffff'],shape:'star',speed:1,spread:10,decay:0.02,size:2.5,vy:-2,gravity:-0.01});
  },

  // Death dissolve particles
  vfxDeath(unit){
    const tx=this.uSX(unit.x,unit.y)+UCX,ty=this.uSY(unit.x,unit.y)+UCY;
    const baseColor=unit.team==='ally'?['#3b82f6','#60a5fa','#93c5fd','#bfdbfe']:['#ef4444','#f87171','#fca5a5','#fecaca'];
    this.vfxSpawn(tx,ty,{count:25,colors:[...baseColor,'#ffffff88'],shape:'diamond',speed:1.5,spread:16,decay:0.012,size:3,gravity:0.03,vy:-.5});
    this.vfxSpawn(tx,ty,{count:10,colors:['#ffffff44'],shape:'circle',speed:.8,spread:12,decay:0.01,size:2,vy:-1,gravity:-0.01});
  },

  // Buff apply glow
  vfxBuff(unit){
    const el=document.getElementById('u-'+unit.id);
    if(el){el.classList.add('buff-glow');setTimeout(()=>el.classList.remove('buff-glow'),500)}
    const tx=this.uSX(unit.x,unit.y)+UCX,ty=this.uSY(unit.x,unit.y)+UCY;
    this.vfxSpawn(tx,ty,{count:8,colors:['#22c55e','#4ade80','#ffffff'],shape:'star',speed:1.5,spread:12,decay:0.025,size:2.5,vy:-1});
  },

  // Screen shake
  screenShake(){
    const w=document.getElementById('iso-world');
    w.classList.remove('screen-shake');void w.offsetWidth;w.classList.add('screen-shake');
    setTimeout(()=>w.classList.remove('screen-shake'),300);
  },

  // Turn transition flash
  turnFlash(type){
    const el=document.getElementById('turn-flash');
    el.classList.remove('player-flash','enemy-flash');void el.offsetWidth;
    el.classList.add(type+'-flash');setTimeout(()=>el.classList.remove(type+'-flash'),600);
  },

  // Anim helpers
  animU(id,x,y){const el=document.getElementById('u-'+id);if(el){el.style.left=this.uSX(x,y)+'px';el.style.top=this.uSY(x,y)+'px';
    const v=this.g2v(x,y);el.style.zIndex=100+v.vc+v.vr}},
  shakeU(id){const el=document.getElementById('u-'+id);if(el){el.classList.add('shaking');setTimeout(()=>el.classList.remove('shaking'),300)}},
  deathA(id){const el=document.getElementById('u-'+id);if(el)el.classList.add('dying')},

});
