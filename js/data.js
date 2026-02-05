// ═══════════════════════════════════════════
//  data.js — 맵 상수 & 유틸리티
// ═══════════════════════════════════════════

const COLS=10, ROWS=15, TW=38, TH=28;
const MIN_P=5, MAX_P=9;
const DEPLOY=[{x:4,y:12},{x:5,y:12},{x:3,y:12},{x:6,y:12},{x:4,y:11},{x:5,y:11},{x:3,y:11},{x:6,y:11},{x:7,y:12}];
const CLAB=['N','E','S','W'], CARR=['▲','▶','▼','◀'];

function mh(a,b,c,d){return Math.abs(a-c)+Math.abs(b-d)}
function shuffle(a){for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}}
function sl(ms){return new Promise(r=>setTimeout(r,ms*G._sett.speed))}

// ── 경험치 시스템 ────────────────────────
const MAX_LEVEL=15;
function expForLevel(lv){return 80+20*lv+5*lv*lv}
function killExp(stageId,enemyCls){
  const base=10+stageId*5;
  const bonus={tanker:1.3,mage:1.2,assassin:1.1,priest:1.1,warrior:1,archer:1};
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

function tSVG(tw,th,tc,lc,rc,z,hl,ttype,seed){
  const h=z*6,W=tw*2,H=th*2+h+2;
  const cx=tw,cy=th;
  const top=`${tw},1 ${W-1},${th} ${tw},${th*2-1} 1,${th}`;
  const lf=`1,${th} ${tw},${th*2-1} ${tw},${th*2-1+h} 1,${th+h}`;
  const rf=`${tw},${th*2-1} ${W-1},${th} ${W-1},${th+h} ${tw},${th*2-1+h}`;
  const sr=s=>{s=(s*9301+49297)%233280;return s/233280};
  let s0=seed||0,rn=()=>{s0=sr(s0+17);return s0};
  let defs='',details='';const gid='tg'+seed;
  if(ttype==='plain'){
    defs+=`<linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#2e4258"/><stop offset="50%" stop-color="${tc}"/><stop offset="100%" stop-color="#243848"/></linearGradient>`;
    for(let i=0;i<3;i++){const px=cx+((rn()-.5)*tw*.8),py=cy+((rn()-.5)*th*.6);const sz=1.5+rn()*1.5;
      details+=`<line x1="${px}" y1="${py}" x2="${px-sz*.3}" y2="${py-sz}" stroke="#3a5a3a" stroke-width=".6" stroke-linecap="round"/><line x1="${px}" y1="${py}" x2="${px+sz*.4}" y2="${py-sz*.8}" stroke="#3a5a3a" stroke-width=".5" stroke-linecap="round"/>`}
    for(let i=0;i<2;i++){const px=cx+((rn()-.5)*tw*.6),py=cy+((rn()-.5)*th*.4);details+=`<circle cx="${px}" cy="${py}" r="${.8+rn()*.6}" fill="#1e2e3e" opacity=".3"/>`}
  }else if(ttype==='forest'){
    defs+=`<linearGradient id="${gid}" x1="0" y1="0" x2=".5" y2="1"><stop offset="0%" stop-color="#264a32"/><stop offset="50%" stop-color="${tc}"/><stop offset="100%" stop-color="#183422"/></linearGradient>`;
    const trees=2+Math.floor(rn()*2);for(let i=0;i<trees;i++){const px=cx+((rn()-.5)*tw*.7),py=cy+((rn()-.5)*th*.5);const tr=2.5+rn()*2;
      details+=`<circle cx="${px}" cy="${py-1}" r="${tr}" fill="#1a3a22" opacity=".6"/><circle cx="${px}" cy="${py-1.5}" r="${tr*.7}" fill="#245a30" opacity=".5"/>`}
    for(let i=0;i<2;i++){const px=cx+((rn()-.5)*tw*.5),py=cy+((rn()-.5)*th*.3);details+=`<ellipse cx="${px}" cy="${py}" rx="${1.5+rn()}" ry="${.6+rn()*.4}" fill="#2a5030" opacity=".35"/>`}
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
  }
  let s='',so=0,f='';
  if(hl==='move'){s='#3b82f6';so=.7;f='rgba(59,130,246,.15)'}
  else if(hl==='attack'){s='#ef4444';so=.7;f='rgba(239,68,68,.15)'}
  else if(hl==='heal'){s='#22c55e';so=.7;f='rgba(34,197,94,.15)'}
  else if(hl==='selected'){s='#f0c040';so=.9;f='rgba(240,192,64,.12)'}
  let r=`<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg"><defs>${defs}</defs>`;
  r+=`<clipPath id="tc${seed}"><polygon points="${top}"/></clipPath>`;
  if(h>0){r+=`<polygon points="${lf}" fill="${lc}"/><polygon points="${rf}" fill="${rc}"/>`}
  r+=`<polygon points="${top}" fill="url(#${gid})"/>`;
  r+=`<g clip-path="url(#tc${seed})">${details}</g>`;
  r+=`<polygon points="${top}" fill="none" stroke="rgba(255,255,255,.08)" stroke-width=".5"/>`;
  if(hl){r+=`<polygon points="${top}" fill="${f}" stroke="${s}" stroke-width="1.5" stroke-opacity="${so}"/>`;
    if(hl==='selected')r+=`<polygon points="${top}" fill="none" stroke="${s}" stroke-width="2" stroke-opacity="1"><animate attributeName="stroke-opacity" values="1;.4;1" dur="1.2s" repeatCount="indefinite"/></polygon>`}
  r+=`</svg>`;return r;
}
