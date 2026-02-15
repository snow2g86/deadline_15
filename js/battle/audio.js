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

    // 외부 오디오 파일 시도 (있으면 사용, 없으면 procedural 사용)
    if(this._bgmAudioPath){
      this._bgmStartExternal();
      return;
    }

    const ctx=this.sfxCtx();
    const vol=0.16*this._sett.bgmVol;
    const master=ctx.createGain();master.gain.setValueAtTime(vol,ctx.currentTime);
    master.connect(ctx.destination);

    const comp=ctx.createDynamicsCompressor();
    comp.threshold.setValueAtTime(-20,ctx.currentTime);
    comp.ratio.setValueAtTime(10,ctx.currentTime);
    comp.knee.setValueAtTime(4,ctx.currentTime);
    comp.connect(master);

    const BPM=130, eighth=60/BPM/2;
    // 더 긴장감 있는 베이스 진행 (Em-Bm-G-Bm-Em-Am-G-A)
    const bassN=[82.4,61.7,49,61.7,82.4,55,49,55,
                 82.4,49,61.7,55,49,61.7,82.4,55,
                 61.7,49,55,82.4,49,61.7,55,49,
                 55,82.4,61.7,49,55,49,61.7,82.4];

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
        const ci=Math.floor((beatIdx/16)%32);
        const b=beatIdx%8;
        const beat16=beatIdx%16;
        const beat32=beatIdx%32;

        // ═══ 서브 드론 (저음 긴장감) ═══
        if(b===0){
          note('sine',bassN[ci]/2,t,eighth*7.8,0.08,0);
          note('sine',bassN[ci]/2*1.005,t,eighth*7.8,0.05,3);
        }

        // ═══ 베이스 라인 (무겁고 어두운) ═══
        const bF=bassN[ci];
        if(b%2===0){
          note('sawtooth',bF,t,eighth*1.6,0.28,-3);
          note('sine',bF/2,t,eighth*1.6,0.12,0);
        } else if(b===3||b===7){
          note('sawtooth',bF*1.5,t,eighth*0.6,0.14,-3);
        }

        // ═══ 킥 드럼 (강렬한) ═══
        if(b===0||b===4){
          const ko=ctx.createOscillator(),kg=ctx.createGain();
          ko.type='sine';ko.frequency.setValueAtTime(95,t);
          ko.frequency.exponentialRampToValueAtTime(20,t+0.2);
          kg.gain.setValueAtTime(b===0?0.50:0.35,t);kg.gain.exponentialRampToValueAtTime(0.001,t+0.2);
          ko.connect(kg);kg.connect(comp);ko.start(t);ko.stop(t+0.21);
          noise(t,0.04,0.16,1200);
        }
        // 고스트 킥
        if(b===3&&beat32>=16){
          const ko=ctx.createOscillator(),kg=ctx.createGain();
          ko.type='sine';ko.frequency.setValueAtTime(85,t);
          ko.frequency.exponentialRampToValueAtTime(25,t+0.12);
          kg.gain.setValueAtTime(0.18,t);kg.gain.exponentialRampToValueAtTime(0.001,t+0.12);
          ko.connect(kg);kg.connect(comp);ko.start(t);ko.stop(t+0.13);
        }

        // ═══ 스네어 (더 강렬한) ═══
        if(b===2||b===6){
          noise(t,0.12,0.28,2200);
          note('triangle',180,t,0.06,0.10,0);
          noise(t+0.04,0.08,0.10,1600);
        }
        // 고스트 스네어
        if((b===5||b===7)&&beat16>=8){
          noise(t,0.06,0.10,2800);
        }

        // ═══ 하이햇 (강한 리듬) ═══
        if(b%2===0){
          noise(t,0.03,beat16%4===0?0.10:0.06,10000);
        }
        // 오픈 하이햇
        if(beat32%16===14&&b===6){
          noise(t,0.14,0.13,6500);
        }

        // ═══ 멜로디 라인 (현악 느낌) ═══
        if(beat32%16<8){
          const melodyFreqs=[82.4,98,110,123.47,82.4,110,98,123.47];
          const mf=melodyFreqs[(beatIdx/2)%8];
          if(b===0||b===4){
            note('triangle',mf*2,t+eighth*0.5,eighth*0.8,0.07,0);
            note('sine',mf*2.05,t+eighth*0.5,eighth*0.8,0.03,5);
          }
        }

        beatIdx++;
      }
      this._bgm.timer=setTimeout(schedule,INT);
    };
    this._bgm={master,comp,timer:null};
    schedule();
  },
  _bgmAudioPath:null,
  _bgmAudioSource:null,

  _bgmStartExternal(){
    const ctx=this.sfxCtx();
    fetch(this._bgmAudioPath)
      .then(r=>r.arrayBuffer())
      .then(buf=>ctx.decodeAudioData(buf,(decoded)=>{
        if(!this._bgm||!this._bgmAudioPath)return;
        const src=ctx.createBufferSource();
        src.buffer=decoded;
        const vol=this._sett.bgmVol*0.85;
        const gain=ctx.createGain();
        gain.gain.setValueAtTime(vol,ctx.currentTime);
        src.connect(gain);
        gain.connect(ctx.destination);
        src.loop=true;
        src.start(ctx.currentTime);
        this._bgmAudioSource=src;
      }))
      .catch(e=>console.log('BGM load failed, using procedural',e));
  },

  bgmStop(){
    if(this._bgmAudioSource){
      try{this._bgmAudioSource.stop()}catch(e){}
      this._bgmAudioSource=null;
      return;
    }
    if(!this._bgm)return;
    if(this._bgm.timer){clearTimeout(this._bgm.timer);this._bgm.timer=null}
    const m=this._bgm.master,ctx=this.sfxCtx(),t=ctx.currentTime;
    m.gain.linearRampToValueAtTime(0,t+0.6);
    setTimeout(()=>{try{m.disconnect()}catch(e){}},700);
    this._bgm=null;
  },

  setBattleMusic(audioPath){
    this._bgmAudioPath=audioPath;
  },

  sfxKill(){const c=this.sfxCtx(),t=c.currentTime;
    this.sfxNoise(c,t,0.2,0.3,{type:'lowpass',freq:500,Q:2});
    this.sfxOsc(c,'sine',100,t,0.2,0.15);this.sfxOsc(c,'sine',60,t+0.05,0.18,0.1)},
});
