// ═══════════════════════════════════════════
//  tiles.js — 타일셋 & 지형 데이터
// ═══════════════════════════════════════════

const TI = {
  plain:  { cost:1,       z:0, label:'',  pass:true,  tc:'#2a3a4e', lc:'#1e2d3d', rc:'#162232', buff:null },
  forest: { cost:1.5,     z:0, label:'', pass:true,  tc:'#1f3d2a', lc:'#162e1f', rc:'#102216', buff:{type:'buff',icon:''} },
  hill:   { cost:2,       z:1, label:'',  pass:true,  tc:'#4a3a20', lc:'#3a2c16', rc:'#2e2210', buff:{type:'buff',icon:''} },
  rock:   { cost:Infinity,z:0, label:'',  pass:false, tc:'#3a3a48', lc:'#2a2a38', rc:'#1e1e28', buff:null },
  water:  { cost:Infinity,z:0, label:'',  pass:false, tc:'#1a3050', lc:'#142640', rc:'#102035', buff:null },
  wall:   { cost:Infinity,z:2, label:'',  pass:false, tc:'#4a4458', lc:'#383248', rc:'#2e283c', buff:null },
  gate:   { cost:1,       z:0, label:'',  pass:true,  tc:'#3a3048', lc:'#2e2840', rc:'#262035', buff:null }
};

const TILE_SHEETS = {};
let tileImgsLoaded = false;
const TILE_MAP = {
  plain: { sheet: 'Overworld - Terrain 1 - Flat 128x64.png', variants: [[4, 0], [4, 1], [4, 2]] },
  dungeon: { sheet: 'Overworld - Terrain 1 - Flat 128x64.png', variants: [[4, 0], [4, 1], [4, 2]] },
  forest: { sheet: 'Overworld - Forest - Flat 128x64.png', variants: [[0, 0], [1, 0], [2, 0], [3, 0]] },
  hill: { sheet: 'Overworld - Terrain 1 - Flat 128x64.png', variants: [[0, 0], [0, 1], [1, 0]] },
  rock: { sheet: 'Overworld - Terrain 3 - Flat 128x64.png', variants: [[0, 0], [1, 0], [1, 1]] },
  water: { sheet: 'Overworld - Water - Flat 128x64.png', variants: [[0, 0], [0, 1], [1, 0]] },
  wall: { sheet: 'Overworld - Terrain 3 - Flat 128x64.png', variants: [[2, 0], [3, 0], [3, 1]] },
  gate: { sheet: 'Overworld - Terrain 2 - Flat 128x64.png', variants: [[0, 0], [0, 1], [0, 2]] }
};

function loadTilesets() {
  const names = new Set();
  Object.values(TILE_MAP).forEach(m => names.add(m.sheet));
  const proms = [];
  names.forEach(n => {
    const img = new Image();
    img.src = 'image/tileset/' + n;
    proms.push(new Promise(res => { img.onload = () => { TILE_SHEETS[n] = img; res() }; img.onerror = () => res() }));
  });
  return Promise.all(proms).then(() => { tileImgsLoaded = Object.keys(TILE_SHEETS).length > 0 });
}

function tSVG(tw, th, tc, lc, rc, z, hl, ttype, seed, vi, bgOnly, noImg) {
  const h = z * ZH, W = tw * 2, H = th * 2 + h + 2;
  const cx = tw, cy = th;
  const top = `${tw},1 ${W - 1},${th} ${tw},${th * 2 - 1} 1,${th}`;
  const lf = `1,${th} ${tw},${th * 2 - 1} ${tw},${th * 2 - 1 + h} 1,${th + h}`;
  const rf = `${tw},${th * 2 - 1} ${W - 1},${th} ${W - 1},${th + h} ${tw},${th * 2 - 1 + h}`;
  const sr = s => { s = (s * 9301 + 49297) % 233280; return s / 233280 };
  let s0 = seed || 0, rn = () => { s0 = sr(s0 + 17); return s0 };
  let defs = '', details = '', rockImg = ''; const gid = 'tg' + seed;
  const tm = TILE_MAP[ttype];
  const useImg = tileImgsLoaded && tm && TILE_SHEETS[tm.sheet];

  if (useImg) {
    if (vi === undefined) vi = 0;
    const row = tm.variants[vi][0], col = tm.variants[vi][1];
    const sc = W / 128;
    const shW = Math.round(384 * sc), shH = Math.round(384 * sc);
    const ix = -col * W, iy = -row * (th * 2);
    const imgTag = `<image href="image/tileset/${tm.sheet}" x="${ix}" y="${iy}" width="${shW}" height="${shH}" clip-path="url(#tc${seed})" preserveAspectRatio="none"/>`;
    details = imgTag;
    if (!noImg) {
      if (ttype === 'forest') {
        const forestTiles = ['tile_041', 'tile_042', 'tile_043', 'tile_044', 'tile_045', 'tile_046', 'tile_047'];
        const selectedForestTile = forestTiles[Math.floor(rn() * forestTiles.length)];
        details += `<image href="image/tileset/forest/${selectedForestTile}.png" x="0" y="-10" width="${W}" height="${H}" opacity=".7" clip-path="url(#tc${seed})"/>`;
      }
      else if (ttype === 'rock') {
        const isGreyscale = /[2-6]a[2-6]a/.test(tc);
        const rockFolder = isGreyscale ? 2 : 1;
        const rockTiles1 = ['tile_054', 'tile_055', 'tile_056', 'tile_057', 'tile_059', 'tile_060'];
        const rockTiles2 = ['tile_061'];
        const rockTiles = rockFolder === 1 ? rockTiles1 : rockTiles2;
        const selectedRockTile = rockTiles[Math.floor(rn() * rockTiles.length)];
        rockImg += `<image href="image/tileset/rocks/${rockFolder}/${selectedRockTile}.png" x="${-W * 0.1}" y="${-H * 0.1 - 20}" width="${W * 1.2}" height="${H * 1.2}" opacity=".7"/>`;
      }
    }
  } else {
    if (ttype === 'plain' || ttype === 'dungeon') {
      defs += `<linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#2e4258"/><stop offset="50%" stop-color="${tc}"/><stop offset="100%" stop-color="#243848"/></linearGradient>`;
      for (let i = 0; i < 3; i++) {
        const px = cx + ((rn() - .5) * tw * .8), py = cy + ((rn() - .5) * th * .6); const sz = 1.5 + rn() * 1.5;
        details += `<line x1="${px}" y1="${py}" x2="${px - sz * .3}" y2="${py - sz}" stroke="#3a5a3a" stroke-width=".6" stroke-linecap="round"/><line x1="${px}" y1="${py}" x2="${px + sz * .4}" y2="${py - sz * .8}" stroke="#3a5a3a" stroke-width=".5" stroke-linecap="round"/>`
      }
      for (let i = 0; i < 2; i++) { const px = cx + ((rn() - .5) * tw * .6), py = cy + ((rn() - .5) * th * .4); details += `<circle cx="${px}" cy="${py}" r="${.8 + rn() * .6}" fill="#1e2e3e" opacity=".3"/>` }
    } else if (ttype === 'forest') {
      defs += `<linearGradient id="${gid}" x1="0" y1="0" x2=".5" y2="1"><stop offset="0%" stop-color="#264a32"/><stop offset="50%" stop-color="${tc}"/><stop offset="100%" stop-color="#183422"/></linearGradient>`;
      const trees = 2 + Math.floor(rn() * 2); for (let i = 0; i < trees; i++) {
        const px = cx + ((rn() - .5) * tw * .7), py = cy + ((rn() - .5) * th * .5); const tr = 2.5 + rn() * 2;
        details += `<circle cx="${px}" cy="${py - 1}" r="${tr}" fill="#1a3a22" opacity=".6"/><circle cx="${px}" cy="${py - 1.5}" r="${tr * .7}" fill="#245a30" opacity=".5"/>`
      }
      for (let i = 0; i < 2; i++) { const px = cx + ((rn() - .5) * tw * .5), py = cy + ((rn() - .5) * th * .3); details += `<ellipse cx="${px}" cy="${py}" rx="${1.5 + rn()}" ry="${.6 + rn() * .4}" fill="#2a5030" opacity=".35"/>` }
      if (!noImg) {
        const forestTiles = ['tile_041', 'tile_042', 'tile_043', 'tile_044', 'tile_045', 'tile_046', 'tile_047'];
        const selectedForestTile = forestTiles[Math.floor(rn() * forestTiles.length)];
        details += `<image href="image/tileset/forest/${selectedForestTile}.png" x="0" y="-10" width="${W}" height="${H}" opacity=".7" clip-path="url(#tc${seed})"/>`;
      }
    } else if (ttype === 'hill') {
      defs += `<linearGradient id="${gid}" x1="0" y1="1" x2="1" y2="0"><stop offset="0%" stop-color="#5a4828"/><stop offset="40%" stop-color="${tc}"/><stop offset="100%" stop-color="#3a2e18"/></linearGradient>`;
      for (let i = 0; i < 3; i++) {
        const px = cx + ((rn() - .5) * tw * .6), py = cy + ((rn() - .5) * th * .4); const rr = 1 + rn() * 1.5;
        details += `<polygon points="${px},${py - rr} ${px + rr},${py} ${px + rr * .3},${py + rr * .5} ${px - rr * .6},${py}" fill="#5a4a30" opacity=".3"/>`
      }
      details += `<line x1="${cx - tw * .3}" y1="${cy - th * .1}" x2="${cx + tw * .3}" y2="${cy - th * .15}" stroke="#6a5a38" stroke-width=".4" opacity=".3"/>`;
      details += `<line x1="${cx - tw * .2}" y1="${cy + th * .15}" x2="${cx + tw * .25}" y2="${cy + th * .1}" stroke="#6a5a38" stroke-width=".3" opacity=".25"/>`;
    } else if (ttype === 'water') {
      defs += `<linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#1e3a5e"/><stop offset="50%" stop-color="${tc}"/><stop offset="100%" stop-color="#142842"/></linearGradient>`;
      for (let i = 0; i < 3; i++) {
        const py = cy - th * .25 + i * th * .25; const w2 = tw * (.25 + i * .1);
        details += `<ellipse cx="${cx}" cy="${py}" rx="${w2}" ry="${2 + rn()}" fill="none" stroke="#2a5a80" stroke-width=".5" opacity="${.25 + rn() * .15}"/>`
      }
      for (let i = 0; i < 2; i++) { const px = cx + ((rn() - .5) * tw * .5), py = cy + ((rn() - .5) * th * .3); details += `<ellipse cx="${px}" cy="${py}" rx="${1.5 + rn()}" ry="${.5 + rn() * .3}" fill="#3a7aaa" opacity=".15"/>` }
    } else if (ttype === 'wall') {
      defs += `<linearGradient id="${gid}" x1="0" y1="0" x2=".5" y2="1"><stop offset="0%" stop-color="#585070"/><stop offset="50%" stop-color="${tc}"/><stop offset="100%" stop-color="#3a3450"/></linearGradient>`;
      details += `<line x1="${cx - tw * .4}" y1="${cy}" x2="${cx + tw * .4}" y2="${cy}" stroke="#3a3450" stroke-width=".6" opacity=".4"/>`;
      details += `<line x1="${cx}" y1="${cy - th * .3}" x2="${cx}" y2="${cy + th * .3}" stroke="#3a3450" stroke-width=".5" opacity=".3"/>`;
      details += `<line x1="${cx - tw * .2}" y1="${cy - th * .15}" x2="${cx - tw * .2}" y2="${cy + th * .15}" stroke="#3a3450" stroke-width=".4" opacity=".25"/>`;
      details += `<line x1="${cx + tw * .2}" y1="${cy - th * .15}" x2="${cx + tw * .2}" y2="${cy + th * .15}" stroke="#3a3450" stroke-width=".4" opacity=".25"/>`;
      details += `<line x1="${cx - tw * .35}" y1="${cy - th * .1}" x2="${cx + tw * .35}" y2="${cy - th * .1}" stroke="#6a6280" stroke-width=".4" opacity=".2"/>`;
    } else if (ttype === 'gate') {
      defs += `<linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#483e5a"/><stop offset="50%" stop-color="${tc}"/><stop offset="100%" stop-color="#282040"/></linearGradient>`;
      details += `<rect x="${cx - tw * .18}" y="${cy - th * .25}" width="${tw * .36}" height="${th * .5}" rx="2" fill="#201830" opacity=".5"/>`;
      details += `<rect x="${cx - tw * .15}" y="${cy - th * .2}" width="${tw * .3}" height="${th * .4}" rx="1.5" fill="#181028" opacity=".4"/>`;
      for (let i = -1; i <= 1; i++) { details += `<line x1="${cx + i * tw * .08}" y1="${cy - th * .2}" x2="${cx + i * tw * .08}" y2="${cy + th * .15}" stroke="#5a5070" stroke-width=".5" opacity=".35"/>` }
    } else if (ttype === 'rock') {
      defs += `<linearGradient id="${gid}" x1=".2" y1="0" x2=".8" y2="1"><stop offset="0%" stop-color="#222236"/><stop offset="40%" stop-color="${tc}"/><stop offset="100%" stop-color="#0c0c18"/></linearGradient>`;
      details += `<line x1="${cx - tw * .35}" y1="${cy - th * .25}" x2="${cx}" y2="${cy + th * .1}" stroke="#08081a" stroke-width="1" opacity=".7"/>`;
      details += `<line x1="${cx}" y1="${cy + th * .1}" x2="${cx + tw * .25}" y2="${cy - th * .05}" stroke="#08081a" stroke-width=".8" opacity=".6"/>`;
      details += `<line x1="${cx + tw * .1}" y1="${cy - th * .3}" x2="${cx + tw * .3}" y2="${cy + th * .2}" stroke="#08081a" stroke-width=".6" opacity=".5"/>`;
      for (let i = 0; i < 4; i++) { const px = cx + ((rn() - .5) * tw * .7), py = cy + ((rn() - .5) * th * .5); details += `<circle cx="${px}" cy="${py}" r="${.8 + rn() * 1.2}" fill="#0a0a16" opacity=".5"/>` }
      details += `<line x1="${cx - tw * .4}" y1="${cy - th * .05}" x2="${cx}" y2="${cy - th * .35}" stroke="#2a2a40" stroke-width=".6" opacity=".35"/>`;
      details += `<line x1="${cx}" y1="${cy - th * .35}" x2="${cx + tw * .4}" y2="${cy - th * .05}" stroke="#2a2a40" stroke-width=".5" opacity=".25"/>`;
      const isGreyscale = /[2-6]a[2-6]a/.test(tc);
      const rockFolder = isGreyscale ? 2 : 1;
      const rockTiles1 = ['tile_054', 'tile_055', 'tile_056', 'tile_057', 'tile_059', 'tile_060'];
      const rockTiles2 = ['tile_061'];
      const rockTiles = rockFolder === 1 ? rockTiles1 : rockTiles2;
      const selectedRockTile = rockTiles[Math.floor(rn() * rockTiles.length)];
      rockImg += `<image href="image/tileset/rocks/${rockFolder}/${selectedRockTile}.png" x="${-W * 0.1}" y="${-H * 0.1 - 20}" width="${W * 1.2}" height="${H * 1.2}" opacity=".7"/>`;
    }
  }
  let s = '', so = 0, f = '';
  if (hl === 'move') { s = '#3b82f6'; so = .7; f = 'rgba(59,130,246,.15)' }
  else if (hl === 'attack') { s = '#ef4444'; so = .7; f = 'rgba(239,68,68,.15)' }
  else if (hl === 'heal') { s = '#22c55e'; so = .7; f = 'rgba(34,197,94,.15)' }
  else if (hl === 'selected') { s = '#f0c040'; so = .9; f = 'rgba(240,192,64,.12)' }
  let r = `<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg"><defs>${defs}</defs>`;
  r += `<clipPath id="tc${seed}"><polygon points="${top}"/></clipPath>`;
  if (h > 0) { r += `<polygon points="${lf}" fill="${lc}"/><polygon points="${rf}" fill="${rc}"/>` }
  if (!useImg) r += `<polygon points="${top}" fill="url(#${gid})"/>`;
  r += `<g clip-path="url(#tc${seed})">${details}</g>`;
  r += rockImg;
  if (hl) {
    r += `<polygon points="${top}" fill="${f}" stroke="${s}" stroke-width="1.5" stroke-opacity="${so}"/>`;
    if (hl === 'selected') r += `<polygon points="${top}" fill="none" stroke="${s}" stroke-width="2" stroke-opacity="1"><animate attributeName="stroke-opacity" values="1;.4;1" dur="1.2s" repeatCount="indefinite"/></polygon>`
  }
  r += `</svg>`; return r;
}
