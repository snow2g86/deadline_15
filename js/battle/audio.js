// ═══════════════════════════════════════════
//  battle/audio.js — SFX & BGM (procedural)
// ═══════════════════════════════════════════
Object.assign(G, {
  _actx:null,
  sfxCtx(){if(!this._actx)this._actx=new(window.AudioContext||window.webkitAudioContext)();
    if(this._actx.state==='suspended')this._actx.resume();
    if(!this._sfxGainNode){this._sfxGainNode=this._actx.createGain();this._sfxGainNode.gain.setValueAtTime(this._sett.sfxVol,this._actx.currentTime);this._sfxGainNode.connect(this._actx.destination)}
    return this._actx},
  sfxDest(){return this._sfxGainNode||this.sfxCtx().destination},
  sfxGain(ctx,v,t){const g=ctx.createGain();g.gain.setValueAtTime(v,t||ctx.currentTime);return g},
  sfxOsc(ctx,type,freq,start,dur,gainN,detune){
    if(!this._sett.sfxOn)return{o:null,g:null};
    const o=ctx.createOscillator(),g=this.sfxGain(ctx,gainN,start);
    o.type=type;o.frequency.setValueAtTime(freq,start);if(detune)o.detune.setValueAtTime(detune,start);
    o.connect(g);g.connect(this.sfxDest());o.start(start);o.stop(start+dur);
    g.gain.exponentialRampToValueAtTime(0.001,start+dur);return{o,g}},
  sfxNoise(ctx,start,dur,gainN,filter){
    if(!this._sett.sfxOn)return;
    const buf=ctx.createBuffer(1,ctx.sampleRate*dur,ctx.sampleRate),d=buf.getChannelData(0);
    for(let i=0;i<d.length;i++)d[i]=(Math.random()*2-1);
    const src=ctx.createBufferSource();src.buffer=buf;
    const g=this.sfxGain(ctx,gainN,start);
    if(filter){const f=ctx.createBiquadFilter();f.type=filter.type||'highpass';f.frequency.setValueAtTime(filter.freq||1000,start);
      if(filter.Q)f.Q.setValueAtTime(filter.Q,start);src.connect(f);f.connect(g)}
    else src.connect(g);
    g.connect(this.sfxDest());g.gain.exponentialRampToValueAtTime(0.001,start+dur);
    src.start(start);src.stop(start+dur)},

  sfxSelect(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',880,t,0.06,0.12);this.sfxOsc(c,'sine',1320,t+0.04,0.08,0.08)},
  sfxMove(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',440,t,0.05,0.08);this.sfxOsc(c,'sine',550,t+0.03,0.06,0.06)},
  sfxUIClick(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',660,t,0.04,0.1)},
  sfxWait(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',440,t,0.1,0.08);this.sfxOsc(c,'sine',330,t+0.06,0.12,0.06)},

  sfxAtkWarrior(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxNoise(c,t,0.12,0.25,{type:'bandpass',freq:2000,Q:2});
    this.sfxOsc(c,'sawtooth',200,t,0.08,0.12);
    this.sfxNoise(c,t+0.03,0.08,0.15,{type:'highpass',freq:3000})},
  sfxAtkKnight(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxNoise(c,t,0.18,0.3,{type:'lowpass',freq:600,Q:3});
    this.sfxOsc(c,'sine',80,t,0.15,0.2);this.sfxOsc(c,'sine',60,t+0.05,0.12,0.15);
    this.sfxNoise(c,t+0.04,0.1,0.12,{type:'bandpass',freq:400,Q:1})},
  sfxAtkAssassin(){const c=this.sfxCtx(),t=c.currentTime;
    for(let i=0;i<3;i++){const d=i*0.06;
      this.sfxNoise(c,t+d,0.04,0.18,{type:'highpass',freq:4000+i*500});
      this.sfxOsc(c,'sawtooth',600+i*200,t+d,0.04,0.06)}},
  sfxAtkMage(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',300,t,0.3,0.1);
    const o=c.createOscillator(),g=this.sfxGain(c,0.12,t);
    o.type='sine';o.frequency.setValueAtTime(300,t);o.frequency.exponentialRampToValueAtTime(1200,t+0.25);
    o.connect(g);g.connect(c.destination);o.start(t);o.stop(t+0.3);
    g.gain.exponentialRampToValueAtTime(0.001,t+0.3);
    this.sfxNoise(c,t+0.1,0.15,0.08,{type:'bandpass',freq:2000,Q:5});
    this.sfxOsc(c,'triangle',800,t+0.15,0.12,0.06)},
  sfxAtkArcher(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxNoise(c,t,0.06,0.15,{type:'highpass',freq:5000});
    const o=c.createOscillator(),g=this.sfxGain(c,0.08,t);
    o.type='sine';o.frequency.setValueAtTime(1200,t);o.frequency.exponentialRampToValueAtTime(400,t+0.15);
    o.connect(g);g.connect(c.destination);o.start(t);o.stop(t+0.18);
    g.gain.exponentialRampToValueAtTime(0.001,t+0.18);
    this.sfxNoise(c,t+0.12,0.06,0.2,{type:'bandpass',freq:1500,Q:3})},
  sfxAtkPriest(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',600,t,0.15,0.08);this.sfxOsc(c,'sine',900,t+0.05,0.12,0.06)},
  sfxAtkNovice(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxNoise(c,t,0.06,0.12,{type:'highpass',freq:3000});
    this.sfxOsc(c,'sine',400,t,0.06,0.08)},
  sfxAtkBrawler(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',120,t,0.1,0.2);this.sfxOsc(c,'sine',80,t+0.03,0.08,0.15);
    this.sfxNoise(c,t,0.08,0.2,{type:'lowpass',freq:800,Q:2});
    for(let i=0;i<3;i++)this.sfxNoise(c,t+i*0.05,0.04,0.12,{type:'bandpass',freq:1500+i*400,Q:3})},
  sfxAtkLancer(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxNoise(c,t,0.1,0.2,{type:'highpass',freq:2500});
    const o=c.createOscillator(),g=this.sfxGain(c,0.1,t);
    o.type='sawtooth';o.frequency.setValueAtTime(800,t);o.frequency.exponentialRampToValueAtTime(200,t+0.15);
    o.connect(g);g.connect(this.sfxDest());o.start(t);o.stop(t+0.15);
    g.gain.exponentialRampToValueAtTime(0.001,t+0.15);
    this.sfxOsc(c,'triangle',350,t+0.05,0.08,0.06)},
  sfxAtkSapper(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'square',180,t,0.06,0.08);this.sfxOsc(c,'square',220,t+0.02,0.06,0.06);
    this.sfxNoise(c,t+0.04,0.1,0.15,{type:'bandpass',freq:1200,Q:2});
    this.sfxOsc(c,'sine',90,t+0.06,0.12,0.1)},
  sfxAtkSummoner(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',440,t,0.2,0.07);this.sfxOsc(c,'sine',660,t+0.05,0.18,0.05);
    this.sfxOsc(c,'triangle',880,t+0.1,0.15,0.04);
    this.sfxNoise(c,t+0.08,0.12,0.06,{type:'bandpass',freq:3000,Q:5})},
  sfxAtkShaman(){const c=this.sfxCtx(),t=c.currentTime;
    const o=c.createOscillator(),g=this.sfxGain(c,0.1,t);
    o.type='sine';o.frequency.setValueAtTime(200,t);o.frequency.exponentialRampToValueAtTime(600,t+0.2);
    o.connect(g);g.connect(this.sfxDest());o.start(t);o.stop(t+0.25);
    g.gain.exponentialRampToValueAtTime(0.001,t+0.25);
    this.sfxNoise(c,t+0.05,0.15,0.08,{type:'bandpass',freq:1000,Q:3});
    this.sfxOsc(c,'sawtooth',150,t+0.1,0.12,0.06)},

  sfxAtk(cls){
    const m={warrior:'sfxAtkWarrior',knight:'sfxAtkKnight',assassin:'sfxAtkAssassin',
      mage:'sfxAtkMage',archer:'sfxAtkArcher',priest:'sfxAtkPriest',
      novice:'sfxAtkNovice',brawler:'sfxAtkBrawler',lancer:'sfxAtkLancer',
      sapper:'sfxAtkSapper',summoner:'sfxAtkSummoner',shaman:'sfxAtkShaman'};
    if(m[cls])this[m[cls]]()},

  sfxHeal(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',523,t,0.15,0.1);this.sfxOsc(c,'sine',659,t+0.08,0.15,0.08);
    this.sfxOsc(c,'sine',784,t+0.16,0.2,0.07);this.sfxOsc(c,'triangle',1047,t+0.24,0.25,0.05)},

  sfxDeath(){const c=this.sfxCtx(),t=c.currentTime;
    const o=c.createOscillator(),g=this.sfxGain(c,0.12,t);
    o.type='sine';o.frequency.setValueAtTime(500,t);o.frequency.exponentialRampToValueAtTime(80,t+0.5);
    o.connect(g);g.connect(c.destination);o.start(t);o.stop(t+0.5);
    g.gain.exponentialRampToValueAtTime(0.001,t+0.5);
    this.sfxNoise(c,t+0.1,0.35,0.06,{type:'lowpass',freq:800})},

  sfxExplosion(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',80,t,0.25,0.25);this.sfxOsc(c,'sine',50,t+0.02,0.2,0.2);
    this.sfxNoise(c,t,0.3,0.25,{type:'lowpass',freq:600,Q:1});
    this.sfxNoise(c,t+0.05,0.15,0.15,{type:'bandpass',freq:1500,Q:2});
    this.sfxOsc(c,'sawtooth',120,t+0.02,0.12,0.08)},

  sfxTurnPlayer(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sine',523,t,0.1,0.1);this.sfxOsc(c,'sine',659,t+0.08,0.1,0.09);
    this.sfxOsc(c,'sine',784,t+0.16,0.15,0.08)},
  sfxTurnEnemy(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'sawtooth',220,t,0.15,0.08);this.sfxOsc(c,'sawtooth',165,t+0.1,0.2,0.07)},

  sfxWave(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxOsc(c,'square',440,t,0.1,0.07);this.sfxOsc(c,'square',440,t+0.15,0.1,0.07);
    this.sfxOsc(c,'square',660,t+0.3,0.15,0.09)},

  sfxVictory(){const c=this.sfxCtx(),t=c.currentTime;
    const notes=[523,659,784,1047];
    notes.forEach((f,i)=>{this.sfxOsc(c,'sine',f,t+i*0.12,0.25,0.1);this.sfxOsc(c,'triangle',f,t+i*0.12,0.25,0.04)})},
  sfxDefeat(){const c=this.sfxCtx(),t=c.currentTime;
    const notes=[392,349,330,262];
    notes.forEach((f,i)=>{this.sfxOsc(c,'sine',f,t+i*0.2,0.35,0.1);this.sfxOsc(c,'sawtooth',f/2,t+i*0.2,0.35,0.03)})},

  _bgm:null,
  bgmStart(){
    this.bgmStop();
    if(!this._sett.bgmOn)return;
    const ctx=this.sfxCtx();
    const vol=0.12*this._sett.bgmVol;
    const master=ctx.createGain();master.gain.setValueAtTime(vol,ctx.currentTime);
    master.connect(ctx.destination);

    // 더 나은 음향 처리 (동적 압축 + 리버브)
    const comp=ctx.createDynamicsCompressor();
    comp.threshold.setValueAtTime(-20,ctx.currentTime);
    comp.ratio.setValueAtTime(6,ctx.currentTime);
    comp.knee.setValueAtTime(10,ctx.currentTime);
    comp.connect(master);

    const BPM=128, eighth=60/BPM/2;
    // 32마디 코드 진행 (클래식 음악 진행 기반)
    const chords=[
      [147,175,220,262],[117,147,175,220],[98,117,147,196],[110,139,165,220],
      [131,165,196,262],[110,139,165,220],[98,117,147,196],[147,175,220,262],
      [165,196,247,294],[147,175,220,262],[131,165,196,247],[117,147,175,220],
      [110,139,165,196],[98,117,147,175],[110,139,165,220],[131,165,196,262],
      [147,175,220,262],[98,117,147,196],[110,139,165,220],[131,165,196,262],
      [165,196,247,294],[147,175,220,262],[117,147,175,220],[98,117,147,196],
      [110,139,165,220],[131,165,196,262],[147,175,220,262],[165,196,247,294],
      [147,175,220,262],[110,139,165,220],[98,117,147,196],[147,175,220,262]
    ];
    const bassN=[73.5,58.5,49,55,65.5,55,49,73.5,82.5,73.5,65.5,58.5,55,49,55,65.5,
                 73.5,49,55,65.5,82.5,73.5,58.5,49,55,65.5,73.5,82.5,73.5,55,49,73.5];
    // 32마디 리프 (각 코드마다 더 복잡한 멜로디)
    const riffs=[
      [587,523,440,523,587,698,587,523],
      [466,440,349,440,466,523,466,349],
      [392,349,294,349,392,466,392,294],
      [440,349,330,349,440,523,440,330],
      [523,494,415,494,523,587,523,415],
      [440,415,330,415,440,494,440,330],
      [392,370,294,370,392,440,392,294],
      [494,440,392,440,494,587,494,392],
      [659,587,523,587,659,784,659,587],
      [587,523,440,523,587,698,587,523],
      [523,494,415,494,523,587,523,415],
      [466,440,349,440,466,523,466,349],
      [440,349,330,349,440,523,440,330],
      [392,349,294,349,392,466,392,294],
      [440,415,330,415,440,494,440,330],
      [523,494,415,494,523,587,523,415],
      [587,523,440,523,587,698,587,523],
      [392,349,294,349,392,466,392,294],
      [440,349,330,349,440,523,440,330],
      [523,494,415,494,523,587,523,415],
      [659,587,523,587,659,784,659,587],
      [587,523,440,523,587,698,587,523],
      [466,440,349,440,466,523,466,349],
      [392,349,294,349,392,466,392,294],
      [440,415,330,415,440,494,440,330],
      [523,494,415,494,523,587,523,415],
      [587,523,440,523,587,698,587,523],
      [659,587,523,587,659,784,659,587],
      [587,523,440,523,587,698,587,523],
      [440,415,330,415,440,494,440,330],
      [392,349,294,349,392,466,392,294],
      [587,523,440,523,587,698,587,523]
    ];
    // 32마디 현악기 (Strings)
    const strings=[
      [294,349,440],[220,294,349],[196,220,294],[220,262,330],
      [262,330,392],[220,262,330],[196,220,294],[294,349,440],
      [330,392,494],[294,349,440],[262,330,392],[220,294,349],
      [220,262,330],[196,220,294],[220,262,330],[262,330,392],
      [294,349,440],[196,220,294],[220,262,330],[262,330,392],
      [330,392,494],[294,349,440],[220,294,349],[196,220,294],
      [220,262,330],[262,330,392],[294,349,440],[330,392,494],
      [294,349,440],[220,262,330],[196,220,294],[294,349,440]
    ];
    // 32마디 금관악기 (Brass)
    const brass=[
      [735,880,1047],[587,698,880],[494,587,698],[523,659,784],
      [659,784,932],[523,659,784],[494,587,698],[735,880,1047],
      [880,1047,1319],[735,880,1047],[659,784,932],[587,698,880],
      [523,659,784],[494,587,698],[523,659,784],[659,784,932],
      [735,880,1047],[494,587,698],[523,659,784],[659,784,932],
      [880,1047,1319],[735,880,1047],[587,698,880],[494,587,698],
      [523,659,784],[659,784,932],[735,880,1047],[880,1047,1319],
      [735,880,1047],[523,659,784],[494,587,698],[735,880,1047]
    ];
    // 32마디 패드 (배경 분위기)
    const pads=[[147,220],[117,175],[98,147],[110,165],[131,196],[110,165],[98,147],[147,220],
                [165,220],[147,196],[131,165],[117,147],[110,139],[98,117],[110,165],[131,196],
                [147,220],[98,147],[110,165],[131,196],[165,220],[147,196],[117,175],[98,147],
                [110,165],[131,196],[147,220],[165,220],[147,196],[110,165],[98,147],[147,220]];

    let beatIdx=0;
    const startT=ctx.currentTime+0.05;

    const note=(type,freq,time,dur,vol,det)=>{
      const o=ctx.createOscillator(),g=ctx.createGain();
      o.type=type;o.frequency.setValueAtTime(freq,time);
      if(det)o.detune.setValueAtTime(det,time);
      g.gain.setValueAtTime(vol,time);
      g.gain.exponentialRampToValueAtTime(0.001,time+dur);
      o.connect(g);g.connect(comp);o.start(time);o.stop(time+dur+0.01);
    };
    const noise=(time,dur,vol,hpFreq)=>{
      const len=Math.max(0.01,dur);
      const buf=ctx.createBuffer(1,ctx.sampleRate*len,ctx.sampleRate);
      const d=buf.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=Math.random()*2-1;
      const src=ctx.createBufferSource();src.buffer=buf;
      const f=ctx.createBiquadFilter();f.type='highpass';f.frequency.setValueAtTime(hpFreq,time);
      const g=ctx.createGain();g.gain.setValueAtTime(vol,time);
      g.gain.exponentialRampToValueAtTime(0.001,time+len);
      src.connect(f);f.connect(g);g.connect(comp);
      src.start(time);src.stop(time+len+0.01);
    };

    const LOOK=0.25, INT=100;
    const schedule=()=>{
      if(!this._bgm)return;
      const now=ctx.currentTime;
      while(startT+beatIdx*eighth < now+LOOK){
        const t=startT+beatIdx*eighth;
        const ci=Math.floor((beatIdx/16)%32); // 32개 코드 순환
        const b=beatIdx%8;
        const beat16=beatIdx%16; // 16비트 패턴
        const beat32=beatIdx%32; // 32비트 패턴 (오케스트라 변화)

        // ═══ 오케스트라 현악기 섹션 (Strings) ═══
        if(b===0 || b===4){
          const str=strings[ci];
          note('sine',str[0],t,eighth*7.8,0.05,-4);
          note('sine',str[1],t,eighth*7.8,0.04,-1);
          note('sine',str[2],t,eighth*7.8,0.04,2);
        }

        // ═══ 오케스트라 금관악기 섹션 (Brass) ═══
        if(beat32>=16 && b===0){
          const br=brass[ci];
          note('sawtooth',br[0],t,eighth*3.8,0.04,-2);
          note('triangle',br[1],t,eighth*3.8,0.03,0);
          note('square',br[2],t,eighth*3.8,0.03,2);
        }

        // ═══ 패드 계층 (배경 분위기) ═══
        if(b===0){
          const pad=pads[ci];
          note('sine',pad[0],t,eighth*7.8,0.04,-6);
          note('sine',pad[1],t,eighth*7.8,0.04,6);
        }

        // ═══ 메인 코드 (풍부한 화음) ═══
        if(b===0){
          const ch=chords[ci];
          note('sawtooth',ch[0],t,eighth*7.8,0.08,-3);
          note('triangle',ch[1],t,eighth*7.8,0.06,0);
          note('triangle',ch[2],t,eighth*7.8,0.06,3);
          note('sine',ch[3]*0.5,t,eighth*7.8,0.04,0); // 7도 코드 추가
          note('sine',ch[0]/2,t,eighth*7.8,0.02,0); // 서브 베이스
        }

        // ═══ 향상된 베이스 라인 ═══
        const bF=b%2===0?bassN[ci]:bassN[ci]*2;
        note('sawtooth',bF,t,eighth*0.8,b%2===0?0.24:0.16,-2);
        note('sine',bF/2,t,eighth*0.8,b%2===0?0.1:0.05,0); // 서브
        // 콘트라베이스 (저주파)
        if(b===0 || b===4){
          note('sine',bF/4,t,eighth*7.8,0.05,0);
        }

        // ═══ 더 복잡한 멜로디 리프 ═══
        const mF=riffs[ci][b];
        note('square',mF,t,eighth*0.7,beat16%4===0?0.12:beat16%2===0?0.07:0.04,0);
        note('triangle',mF*1.004,t,eighth*0.7,beat16%4===0?0.06:beat16%2===0?0.04:0.02,0);
        // 추가 하모니 (3도)
        note('sine',mF*1.26,t,eighth*0.7,beat16%4===0?0.03:0.015,0);
        note('sine',mF*0.5,t,eighth*0.7,beat16%4===0?0.02:0.01,0);

        // ═══ 더 정교한 드럼 패턴 ═══
        if(b===0||b===4){
          const ko=ctx.createOscillator(),kg=ctx.createGain();
          ko.type='sine';ko.frequency.setValueAtTime(100,t);
          ko.frequency.exponentialRampToValueAtTime(30,t+0.12);
          kg.gain.setValueAtTime(b===0?0.35:0.22,t);kg.gain.exponentialRampToValueAtTime(0.001,t+0.12);
          ko.connect(kg);kg.connect(comp);ko.start(t);ko.stop(t+0.13);
        }

        // ═══ 향상된 스네어/클랩 ═══
        if(b===2||b===6){
          noise(t,0.08,0.2,2000);
          note('triangle',180,t,0.06,0.1,0);
          // 클랩 리버브
          noise(t+0.02,0.06,0.08,1500);
        }

        // ═══ 더 복잡한 하이햇 패턴 ═══
        if(beat16%2===0){
          noise(t,b%2===0?0.04:0.02,beat16%4===0?0.09:0.05,9000);
        }
        if(beat16%4===2){
          noise(t,0.02,0.06,12000);
        }
        // 심벌 크래시 (강조 비트)
        if(beat32===0||beat32===16){
          noise(t,0.15,0.15,6000);
        }

        beatIdx++;
      }
      this._bgm.timer=setTimeout(schedule,INT);
    };
    this._bgm={master,comp,timer:null};
    schedule();
  },
  bgmStop(){
    if(!this._bgm)return;
    if(this._bgm.timer){clearTimeout(this._bgm.timer);this._bgm.timer=null}
    const m=this._bgm.master,ctx=this.sfxCtx(),t=ctx.currentTime;
    m.gain.linearRampToValueAtTime(0,t+0.6);
    setTimeout(()=>{try{m.disconnect()}catch(e){}},700);
    this._bgm=null;
  },

  sfxKill(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxNoise(c,t,0.2,0.3,{type:'lowpass',freq:500,Q:2});
    this.sfxOsc(c,'sine',100,t,0.2,0.15);this.sfxOsc(c,'sine',60,t+0.05,0.18,0.1)},
});
