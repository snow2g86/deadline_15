// ── Pixel Art SVG Character Sprites ──────────────
// 10x12 pixel grid per class, rendered as SVG
const CHAR_SPRITES = {
  novice: {
    p: {h:'#5C3A1E',s:'#F5DEB3',e:'#4A3520',a:'#8B7355',b:'#6B5B3A',f:'#4A3728',w:'#B8860B'},
    r: [
      '..hhhh..w.',
      '..hsssshw.',
      '..sseessw.',
      '...ssss.w.',
      '..aaaaaaw.',
      '.aaaaaaaa.',
      '..aaaaaa..',
      '...aaaa...',
      '...b..b...',
      '...b..b...',
      '..ff..ff..',
      '..........',
    ]
  },
  warrior: {
    p: {h:'#8B0000',s:'#F5DEB3',e:'#4A3520',a:'#DC143C',b:'#8B0000',w:'#C0C0C0',f:'#4A3728'},
    r: [
      '..hhhhhh..',
      '..hssssh..',
      '..sseess..',
      '...ssss...',
      '..aaaaaa..',
      '..aaaaaaw.',
      '..aaaaaa.w',
      '...aaaa...',
      '...b..b...',
      '...b..b...',
      '..ff..ff..',
      '..........',
    ]
  },
  knight: {
    p: {c:'#A8A8A8',s:'#F5DEB3',e:'#4A3520',a:'#4169E1',b:'#2B4D99',w:'#D0D0D0',f:'#333333'},
    r: [
      '..cccccc..',
      '..cssssc..',
      '..sseess..',
      '..cccccc..',
      '.waaaaaa..',
      '.waaaaaa..',
      '..aaaaaa..',
      '...aaaa...',
      '...b..b...',
      '...b..b...',
      '..ff..ff..',
      '..........',
    ]
  },
  assassin: {
    p: {a:'#2D1B4E',s:'#F5DEB3',e:'#8B5CF6',w:'#A0A0A0',b:'#1A1028',f:'#1A1028'},
    r: [
      '...aaaa...',
      '..aaaaaa..',
      '..aessea..',
      '..aaaaaa..',
      '...aaaa...',
      '..aaaaaa..',
      '..aaaaaa..',
      '.waaaaaw..',
      '...b..b...',
      '...b..b...',
      '..ff..ff..',
      '..........',
    ]
  },
  mage: {
    p: {a:'#1E3A5F',s:'#F5DEB3',e:'#4A3520',w:'#FFD700',c:'#4488FF',f:'#1E3A5F'},
    r: [
      '....a.....',
      '...aaa....',
      '..aaaaa...',
      '..sseess..',
      '...ssss...',
      'w.aaaaaa..',
      'c.aaaaaa..',
      '..aaaaaa..',
      '..aaaaaa..',
      '..aaaaaa..',
      '..aa..aa..',
      '..........',
    ]
  },
  archer: {
    p: {a:'#2E8B57',s:'#F5DEB3',e:'#4A3520',h:'#2E8B57',b:'#1B5E20',w:'#8B4513',f:'#4A3728'},
    r: [
      '...aaaa...',
      '..ahssha..',
      '..sseess..',
      '...ssss...',
      '..aaaaaa..',
      '.waaaaaa..',
      'w.aaaaaa..',
      '.waaaaaa..',
      '...b..b...',
      '...b..b...',
      '..ff..ff..',
      '..........',
    ]
  },
  priest: {
    p: {a:'#F0F0F0',s:'#F5DEB3',e:'#4A3520',h:'#FFD700',w:'#DAA520',c:'#FFD700',f:'#DAA520'},
    r: [
      '...cccc...',
      '..hssssh..',
      '..sseess..',
      '...ssss...',
      'w.aaaaaa..',
      'c.aaaaaa..',
      '..aaaaaa..',
      '..aaaaaa..',
      '..aaaaaa..',
      '..aaaaaa..',
      '..aa..aa..',
      '..........',
    ]
  },
  summoner: {
    p: {a:'#6A0DAD',s:'#F5DEB3',e:'#4A3520',h:'#4B0082',c:'#9B59B6',f:'#4B0082'},
    r: [
      '..hhhhhh..',
      '..hssssh..',
      '..sseess..',
      '...ssss...',
      'c.aaaaaa.c',
      '..aaaaaa..',
      '..aaaaaa..',
      '..aaaaaa..',
      '..aaaaaa..',
      '..aaaaaa..',
      '..aa..aa..',
      '..........',
    ]
  },
  shaman: {
    p: {a:'#556B2F',s:'#D2B48C',e:'#FF4500',c:'#D2691E',b:'#3B4A1F',w:'#8B4513',f:'#4A3728'},
    r: [
      '..cccccc..',
      '..cccccc..',
      '..ceecec..',
      '..cccccc..',
      '...cccc...',
      'w.aaaaaa..',
      'w.aaaaaa..',
      '..aaaaaa..',
      '...aaaa...',
      '...b..b...',
      '..ff..ff..',
      '..........',
    ]
  },
  brawler: {
    p: {a:'#FF6600',s:'#D2B48C',e:'#4A3520',h:'#333333',c:'#FF0000',w:'#F0E68C',b:'#CC5500',f:'#4A3728'},
    r: [
      '..cccccc..',
      '..hssssh..',
      '..sseess..',
      '...ssss...',
      '..aassaa..',
      '.waassaaw.',
      '..aaaaaa..',
      '...aaaa...',
      '...b..b...',
      '...b..b...',
      '..ff..ff..',
      '..........',
    ]
  },
  lancer: {
    p: {a:'#4682B4',s:'#F5DEB3',e:'#4A3520',h:'#333333',w:'#C0C0C0',b:'#36648B',f:'#333333'},
    r: [
      '.........w',
      '..hhhh...w',
      '..sseess.w',
      '...ssss..w',
      '..aaaaaa.w',
      '..aaaaaa.w',
      '..aaaaaa..',
      '...aaaa...',
      '...b..b...',
      '...b..b...',
      '..ff..ff..',
      '..........',
    ]
  },
  sapper: {
    p: {a:'#8B6914',s:'#F5DEB3',e:'#4A3520',c:'#FFD700',b:'#6B4914',w:'#808080',f:'#4A3728'},
    r: [
      '.cccccc...',
      'cccssscc..',
      '..sseess..',
      '...ssss...',
      '..aaaaaa..',
      '..aaaaaa.w',
      '..aaaaaa..',
      '...aaaa...',
      '...b..b...',
      '...b..b...',
      '..ff..ff..',
      '..........',
    ]
  },
  summon_spirit: {
    p: {a:'#88CCFF',e:'#FFFFFF'},
    r: [
      '..........',
      '...aaaa...',
      '..aaaaaa..',
      '..a.ee.a..',
      '..aaaaaa..',
      '...aaaa...',
      '..aaaaaa..',
      '..aaaaaa..',
      '...aaaa...',
      '....aa....',
      '..........',
      '..........',
    ]
  },
  summon_golem: {
    p: {a:'#808080',e:'#FF4500',b:'#606060'},
    r: [
      '..........',
      '...aaaa...',
      '..aaaaaa..',
      '..aeaaea..',
      '..aaaaaa..',
      '.aaaaaaaa.',
      '.aaaaaaaa.',
      '..aaaaaa..',
      '..bb..bb..',
      '..bb..bb..',
      '..........',
      '..........',
    ]
  },
};

function charSprite(cls, size) {
  const sp = CHAR_SPRITES[cls];
  if (!sp) return clsIcon(cls, size);
  const {p, r} = sp;
  const w = r[0].length, h = r.length;
  const svgH = Math.round(size * h / w);
  let out = '';
  for (let y = 0; y < h; y++) {
    const row = r[y];
    let x = 0;
    while (x < w) {
      const ch = row[x];
      if (ch === '.') { x++; continue; }
      let x2 = x + 1;
      while (x2 < w && row[x2] === ch) x2++;
      out += `<rect x="${x}" y="${y}" width="${x2-x}" height="1" fill="${p[ch]}"/>`;
      x = x2;
    }
  }
  return `<svg viewBox="0 0 ${w} ${h}" width="${size}" height="${svgH}" xmlns="http://www.w3.org/2000/svg" style="image-rendering:pixelated">${out}</svg>`;
}
