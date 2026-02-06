// ═══════════════════════════════════════════
//  data.js — 맵 상수 & 유틸리티
// ═══════════════════════════════════════════

const COLS=10, ROWS=15, TW=48, TH=24;
const ZH=6, UW=48, UH=60, UCX=24, UCY=12;
const MIN_P=5, MAX_P=5;
const DEPLOY=[{x:4,y:12},{x:5,y:12},{x:3,y:12},{x:6,y:12},{x:4,y:11},{x:5,y:11},{x:3,y:11},{x:6,y:11},{x:7,y:12},{x:7,y:11}];
const CLAB=['N','E','S','W'], CARR=['▲','▶','▼','◀'];

function mh(a,b,c,d){return Math.abs(a-c)+Math.abs(b-d)}
function shuffle(a){for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}}
function sl(ms){return new Promise(r=>setTimeout(r,ms*G._sett.speed))}

// ── 경험치 시스템 ────────────────────────
const MAX_LEVEL=15;
function expForLevel(lv){return 80+20*lv+5*lv*lv}
function killExp(stageId,enemyCls){
  const base=10+stageId*5;
  const bonus={knight:1.3,mage:1.2,summoner:1.2,shaman:1.2,assassin:1.1,priest:1.1,brawler:1.1,lancer:1.1,sapper:1.1,novice:1,warrior:1,archer:1};
  return Math.floor(base*(bonus[enemyCls]||1));
}
function actExp(stageId,action){
  const base={move:2,attack:5,heal:6};
  return Math.floor((base[action]||0)*(1+stageId*0.2));
}
const EXP_POTIONS=[
  {id:'exp_s',name:'소형 경험치 물약',icon:'🧪',exp:50,cost:40,weight:50},
  {id:'exp_m',name:'중형 경험치 물약',icon:'⚗️',exp:150,cost:100,weight:35},
  {id:'exp_l',name:'대형 경험치 물약',icon:'🏺',exp:400,cost:240,weight:15},
];

const CLASS_CHANGE_SCROLLS=[
  {id:'cc_melee',name:'근접 전직서',icon:'📜',desc:'노비스를 근접 직업으로 전직',classes:['warrior','knight','assassin','brawler','lancer','sapper'],cost:150,weight:30},
  {id:'cc_ranged',name:'원거리 전직서',icon:'📋',desc:'노비스를 원거리 직업으로 전직',classes:['archer','mage','summoner','shaman'],cost:150,weight:30},
  {id:'cc_healer',name:'힐러 전직서',icon:'📃',desc:'노비스를 사제로 전직',classes:['priest'],cost:120,weight:20},
  {id:'cc_universal',name:'범용 전직서',icon:'🎖️',desc:'노비스를 원하는 직업으로 전직',classes:['warrior','knight','assassin','archer','mage','priest','summoner','shaman','brawler','lancer','sapper'],cost:200,weight:10},
];

// ── 클래스 아이콘 (이모지) ──────────────
function clsIcon(cls,size){
  const d=CD[cls];if(!d)return '';
  return `<span class="cls-icon" style="font-size:${size}px">${d.icon}</span>`;
}

// ── 타일셋 이미지 시스템 ──────────────────
const TILE_SHEETS={};
let tileImgsLoaded=false;
const TILE_MAP={
  plain:{sheet:'Overworld - Terrain 1 - Flat 128x64.png',variants:[[4,0],[4,1],[4,2]]},
  dungeon:{sheet:'Overworld - Terrain 1 - Flat 128x64.png',variants:[[4,0],[4,1],[4,2]]},
  forest:{sheet:'Overworld - Forest - Flat 128x64.png',variants:[[0,0],[1,0],[2,0],[3,0]]},
  hill:{sheet:'Overworld - Terrain 1 - Flat 128x64.png',variants:[[0,0],[0,1],[1,0]]},
  rock:{sheet:'Overworld - Terrain 3 - Flat 128x64.png',variants:[[0,0],[1,0],[1,1]]},
  water:{sheet:'Overworld - Water - Flat 128x64.png',variants:[[0,0],[0,1],[1,0]]},
  wall:{sheet:'Overworld - Terrain 3 - Flat 128x64.png',variants:[[2,0],[3,0],[3,1]]},
  gate:{sheet:'Overworld - Terrain 2 - Flat 128x64.png',variants:[[0,0],[0,1],[0,2]]}
};
function loadTilesets(){
  const names=new Set();
  Object.values(TILE_MAP).forEach(m=>names.add(m.sheet));
  const proms=[];
  names.forEach(n=>{
    const img=new Image();
    img.src='image/tileset/'+n;
    proms.push(new Promise(res=>{img.onload=()=>{TILE_SHEETS[n]=img;res()};img.onerror=()=>res()}));
  });
  return Promise.all(proms).then(()=>{tileImgsLoaded=Object.keys(TILE_SHEETS).length>0});
}

function tSVG(tw,th,tc,lc,rc,z,hl,ttype,seed,vi,bgOnly){
  const h=z*ZH,W=tw*2,H=th*2+h+2;
  const cx=tw,cy=th;
  const top=`${tw},1 ${W-1},${th} ${tw},${th*2-1} 1,${th}`;
  const lf=`1,${th} ${tw},${th*2-1} ${tw},${th*2-1+h} 1,${th+h}`;
  const rf=`${tw},${th*2-1} ${W-1},${th} ${W-1},${th+h} ${tw},${th*2-1+h}`;
  const sr=s=>{s=(s*9301+49297)%233280;return s/233280};
  let s0=seed||0,rn=()=>{s0=sr(s0+17);return s0};
  let defs='',details='',rockImg='';const gid='tg'+seed;
  const tm=TILE_MAP[ttype];
  const useImg=tileImgsLoaded&&tm&&TILE_SHEETS[tm.sheet];

  if(useImg){
    // 이미지 기반 타일 — 스테이지별 고정 variant
    if(vi===undefined)vi=0;
    const row=tm.variants[vi][0],col=tm.variants[vi][1];
    // 시트: 384x384, 3열x6행, 각 타일 128x64
    // 스케일: TW*2=96px 폭에 맞춰 128→96, 비율 0.75
    const sc=W/128; // 96/128=0.75
    const shW=Math.round(384*sc),shH=Math.round(384*sc);
    const ix=-col*W,iy=-row*(th*2);
    const imgTag=`<image href="image/tileset/${tm.sheet}" x="${ix}" y="${iy}" width="${shW}" height="${shH}" clip-path="url(#tc${seed})" preserveAspectRatio="none"/>`;
    details=imgTag;
    // forest 폴더의 랜덤 이미지 오버레이 (useImg가 true인 경우도 추가)
    if(ttype==='forest'){
      const forestTiles=['tile_041','tile_042','tile_043','tile_044','tile_045','tile_046','tile_047','tile_049','tile_051'];
      const selectedForestTile=forestTiles[Math.floor(rn()*forestTiles.length)];
      details+=`<image href="image/tileset/forest/${selectedForestTile}.png" x="0" y="-10" width="${W}" height="${H}" opacity=".7" clip-path="url(#tc${seed})"/>`;
    }
    // rock 폴더의 랜덤 이미지 오버레이 (회색계열은 2, 갈색/녹색계열은 1)
    else if(ttype==='rock'){
      const isGreyscale=/[2-6]a[2-6]a/.test(tc);
      const rockFolder=isGreyscale?2:1;
      const rockTiles1=['tile_054','tile_055','tile_056','tile_057','tile_059','tile_060'];
      const rockTiles2=['tile_064','tile_065','tile_068'];
      const rockTiles=rockFolder===1?rockTiles1:rockTiles2;
      const selectedRockTile=rockTiles[Math.floor(rn()*rockTiles.length)];
      rockImg+=`<image href="image/tileset/rocks/${rockFolder}/${selectedRockTile}.png" x="${-W*0.1}" y="${-H*0.1-20}" width="${W*1.2}" height="${H*1.2}" opacity=".7"/>`;
    }
  }else{
    // 프로시저럴 폴백
    if(ttype==='plain'||ttype==='dungeon'){
      defs+=`<linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#2e4258"/><stop offset="50%" stop-color="${tc}"/><stop offset="100%" stop-color="#243848"/></linearGradient>`;
      for(let i=0;i<3;i++){const px=cx+((rn()-.5)*tw*.8),py=cy+((rn()-.5)*th*.6);const sz=1.5+rn()*1.5;
        details+=`<line x1="${px}" y1="${py}" x2="${px-sz*.3}" y2="${py-sz}" stroke="#3a5a3a" stroke-width=".6" stroke-linecap="round"/><line x1="${px}" y1="${py}" x2="${px+sz*.4}" y2="${py-sz*.8}" stroke="#3a5a3a" stroke-width=".5" stroke-linecap="round"/>`}
      for(let i=0;i<2;i++){const px=cx+((rn()-.5)*tw*.6),py=cy+((rn()-.5)*th*.4);details+=`<circle cx="${px}" cy="${py}" r="${.8+rn()*.6}" fill="#1e2e3e" opacity=".3"/>`}
    }else if(ttype==='forest'){
      defs+=`<linearGradient id="${gid}" x1="0" y1="0" x2=".5" y2="1"><stop offset="0%" stop-color="#264a32"/><stop offset="50%" stop-color="${tc}"/><stop offset="100%" stop-color="#183422"/></linearGradient>`;
      const trees=2+Math.floor(rn()*2);for(let i=0;i<trees;i++){const px=cx+((rn()-.5)*tw*.7),py=cy+((rn()-.5)*th*.5);const tr=2.5+rn()*2;
        details+=`<circle cx="${px}" cy="${py-1}" r="${tr}" fill="#1a3a22" opacity=".6"/><circle cx="${px}" cy="${py-1.5}" r="${tr*.7}" fill="#245a30" opacity=".5"/>`}
      for(let i=0;i<2;i++){const px=cx+((rn()-.5)*tw*.5),py=cy+((rn()-.5)*th*.3);details+=`<ellipse cx="${px}" cy="${py}" rx="${1.5+rn()}" ry="${.6+rn()*.4}" fill="#2a5030" opacity=".35"/>`}
      // forest 폴더의 랜덤 이미지 오버레이
      const forestTiles=['tile_041','tile_042','tile_043','tile_044','tile_045','tile_046','tile_047','tile_049','tile_051'];
      const selectedForestTile=forestTiles[Math.floor(rn()*forestTiles.length)];
      details+=`<image href="image/tileset/forest/${selectedForestTile}.png" x="0" y="-10" width="${W}" height="${H}" opacity=".7" clip-path="url(#tc${seed})"/>`;
    }else if(ttype==='hill'){
      defs+=`<linearGradient id="${gid}" x1="0" y1="1" x2="1" y2="0"><stop offset="0%" stop-color="#5a4828"/><stop offset="40%" stop-color="${tc}"/><stop offset="100%" stop-color="#3a2e18"/></linearGradient>`;
      for(let i=0;i<3;i++){const px=cx+((rn()-.5)*tw*.6),py=cy+((rn()-.5)*th*.4);const rr=1+rn()*1.5;
        details+=`<polygon points="${px},${py-rr} ${px+rr},${py} ${px+rr*.3},${py+rr*.5} ${px-rr*.6},${py}" fill="#5a4a30" opacity=".3"/>`}
      details+=`<line x1="${cx-tw*.3}" y1="${cy-th*.1}" x2="${cx+tw*.3}" y2="${cy-th*.15}" stroke="#6a5a38" stroke-width=".4" opacity=".3"/>`;
      details+=`<line x1="${cx-tw*.2}" y1="${cy+th*.15}" x2="${cx+tw*.25}" y2="${cy+th*.1}" stroke="#6a5a38" stroke-width=".3" opacity=".25"/>`;
    }else if(ttype==='water'){
      defs+=`<linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#1e3a5e"/><stop offset="50%" stop-color="${tc}"/><stop offset="100%" stop-color="#142842"/></linearGradient>`;
      for(let i=0;i<3;i++){const py=cy-th*.25+i*th*.25;const w2=tw*(.25+i*.1);
        details+=`<ellipse cx="${cx}" cy="${py}" rx="${w2}" ry="${2+rn()}" fill="none" stroke="#2a5a80" stroke-width=".5" opacity="${.25+rn()*.15}"/>`}
      for(let i=0;i<2;i++){const px=cx+((rn()-.5)*tw*.5),py=cy+((rn()-.5)*th*.3);details+=`<ellipse cx="${px}" cy="${py}" rx="${1.5+rn()}" ry="${.5+rn()*.3}" fill="#3a7aaa" opacity=".15"/>`}
    }else if(ttype==='wall'){
      defs+=`<linearGradient id="${gid}" x1="0" y1="0" x2=".5" y2="1"><stop offset="0%" stop-color="#585070"/><stop offset="50%" stop-color="${tc}"/><stop offset="100%" stop-color="#3a3450"/></linearGradient>`;
      details+=`<line x1="${cx-tw*.4}" y1="${cy}" x2="${cx+tw*.4}" y2="${cy}" stroke="#3a3450" stroke-width=".6" opacity=".4"/>`;
      details+=`<line x1="${cx}" y1="${cy-th*.3}" x2="${cx}" y2="${cy+th*.3}" stroke="#3a3450" stroke-width=".5" opacity=".3"/>`;
      details+=`<line x1="${cx-tw*.2}" y1="${cy-th*.15}" x2="${cx-tw*.2}" y2="${cy+th*.15}" stroke="#3a3450" stroke-width=".4" opacity=".25"/>`;
      details+=`<line x1="${cx+tw*.2}" y1="${cy-th*.15}" x2="${cx+tw*.2}" y2="${cy+th*.15}" stroke="#3a3450" stroke-width=".4" opacity=".25"/>`;
      details+=`<line x1="${cx-tw*.35}" y1="${cy-th*.1}" x2="${cx+tw*.35}" y2="${cy-th*.1}" stroke="#6a6280" stroke-width=".4" opacity=".2"/>`;
    }else if(ttype==='gate'){
      defs+=`<linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#483e5a"/><stop offset="50%" stop-color="${tc}"/><stop offset="100%" stop-color="#282040"/></linearGradient>`;
      details+=`<rect x="${cx-tw*.18}" y="${cy-th*.25}" width="${tw*.36}" height="${th*.5}" rx="2" fill="#201830" opacity=".5"/>`;
      details+=`<rect x="${cx-tw*.15}" y="${cy-th*.2}" width="${tw*.3}" height="${th*.4}" rx="1.5" fill="#181028" opacity=".4"/>`;
      for(let i=-1;i<=1;i++){details+=`<line x1="${cx+i*tw*.08}" y1="${cy-th*.2}" x2="${cx+i*tw*.08}" y2="${cy+th*.15}" stroke="#5a5070" stroke-width=".5" opacity=".35"/>`}
    }else if(ttype==='rock'){
      defs+=`<linearGradient id="${gid}" x1=".2" y1="0" x2=".8" y2="1"><stop offset="0%" stop-color="#222236"/><stop offset="40%" stop-color="${tc}"/><stop offset="100%" stop-color="#0c0c18"/></linearGradient>`;
      details+=`<line x1="${cx-tw*.35}" y1="${cy-th*.25}" x2="${cx}" y2="${cy+th*.1}" stroke="#08081a" stroke-width="1" opacity=".7"/>`;
      details+=`<line x1="${cx}" y1="${cy+th*.1}" x2="${cx+tw*.25}" y2="${cy-th*.05}" stroke="#08081a" stroke-width=".8" opacity=".6"/>`;
      details+=`<line x1="${cx+tw*.1}" y1="${cy-th*.3}" x2="${cx+tw*.3}" y2="${cy+th*.2}" stroke="#08081a" stroke-width=".6" opacity=".5"/>`;
      for(let i=0;i<4;i++){const px=cx+((rn()-.5)*tw*.7),py=cy+((rn()-.5)*th*.5);details+=`<circle cx="${px}" cy="${py}" r="${.8+rn()*1.2}" fill="#0a0a16" opacity=".5"/>`}
      details+=`<line x1="${cx-tw*.4}" y1="${cy-th*.05}" x2="${cx}" y2="${cy-th*.35}" stroke="#2a2a40" stroke-width=".6" opacity=".35"/>`;
      details+=`<line x1="${cx}" y1="${cy-th*.35}" x2="${cx+tw*.4}" y2="${cy-th*.05}" stroke="#2a2a40" stroke-width=".5" opacity=".25"/>`;
      // rock 폴더의 랜덤 이미지 오버레이 (회색계열은 2, 갈색/녹색계열은 1)
      const isGreyscale=/[2-6]a[2-6]a/.test(tc);
      const rockFolder=isGreyscale?2:1;
      const rockTiles1=['tile_054','tile_055','tile_056','tile_057','tile_059','tile_060'];
      const rockTiles2=['tile_064','tile_065','tile_068'];
      const rockTiles=rockFolder===1?rockTiles1:rockTiles2;
      const selectedRockTile=rockTiles[Math.floor(rn()*rockTiles.length)];
      rockImg+=`<image href="image/tileset/rocks/${rockFolder}/${selectedRockTile}.png" x="${-W*0.1}" y="${-H*0.1-20}" width="${W*1.2}" height="${H*1.2}" opacity=".7"/>`;
    }
  }
  let r=`<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg"><defs>${defs}</defs>`;
  r+=`<clipPath id="tc${seed}"><polygon points="${top}"/></clipPath>`;
  if(h>0){r+=`<polygon points="${lf}" fill="${lc}"/><polygon points="${rf}" fill="${rc}"/>`}
  if(!useImg)r+=`<polygon points="${top}" fill="url(#${gid})"/>`;
  r+=`<g clip-path="url(#tc${seed})">${details}</g>`;
  r+=rockImg;
  // 배경만 생성하는 경우 하이라이트 스킵
  if(!bgOnly){
    let s='',so=0,f='';
    if(hl==='move'){s='#3b82f6';so=.7;f='rgba(59,130,246,.15)'}
    else if(hl==='attack'){s='#ef4444';so=.7;f='rgba(239,68,68,.15)'}
    else if(hl==='heal'){s='#22c55e';so=.7;f='rgba(34,197,94,.15)'}
    else if(hl==='selected'){s='#f0c040';so=.9;f='rgba(240,192,64,.12)'}
    if(hl){r+=`<polygon points="${top}" fill="${f}" stroke="${s}" stroke-width="1.5" stroke-opacity="${so}"/>`;
      if(hl==='selected')r+=`<polygon points="${top}" fill="none" stroke="${s}" stroke-width="2" stroke-opacity="1"><animate attributeName="stroke-opacity" values="1;.4;1" dur="1.2s" repeatCount="indefinite"/></polygon>`}
  }
  r+=`</svg>`;return r;
}
