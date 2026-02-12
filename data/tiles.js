// ═══════════════════════════════════════════
//  tiles.js — 타일 지형 데이터
// ═══════════════════════════════════════════

const TI = {
  plain:  { cost:1,       z:0, label:'',  pass:true,  tc:'#2a3a4e', lc:'#1e2d3d', rc:'#162232', buff:null },
  forest: { cost:1.5,     z:0, label:'', pass:true,  tc:'#1a4430', lc:'#143620', rc:'#0e2a16', buff:{type:'buff',icon:'🌲'} },
  hill:   { cost:2,       z:1, label:'',  pass:true,  tc:'#5a4828', lc:'#2a2010', rc:'#1e1808', buff:{type:'buff',icon:'⛰️'} },
  rock:   { cost:Infinity,z:2, label:'',  pass:false, tc:'#2e2e3e', lc:'#161622', rc:'#0e0e18', buff:null },
  water:  { cost:Infinity,z:0, label:'',  pass:false, tc:'#162e55', lc:'#102240', rc:'#0c1a35', buff:null },
  wall:   { cost:Infinity,z:2, label:'',  pass:false, tc:'#504868', lc:'#261e38', rc:'#1a1428', buff:null },
  gate:   { cost:1,       z:0, label:'',  pass:true,  tc:'#3a3048', lc:'#2e2840', rc:'#262035', buff:null }
};

const MAP_THEMES = {
  plains: {
    colors: {
      plain:  { tc:'#2e4a30', lc:'#223a24', rc:'#1a2e1c' },
      forest: { tc:'#1a4430', lc:'#0e3020', rc:'#082414' },
      hill:   { tc:'#4a5a28', lc:'#2a3210', rc:'#1e2608' },
      rock:   { tc:'#3a3a40', lc:'#1e1e28', rc:'#141420' },
      water:  { tc:'#1a3558', lc:'#122840', rc:'#0e2035' },
    },
    dist: { rock:.05, hill:.10, forest:.15, water:0 }
  },
  canyon: {
    colors: {
      plain:  { tc:'#5a4838', lc:'#3e3028', rc:'#2e2018' },
      forest: { tc:'#3a4828', lc:'#283818', rc:'#1e2a10' },
      hill:   { tc:'#6e5830', lc:'#4e3a18', rc:'#3a2a10' },
      rock:   { tc:'#4a4048', lc:'#2e2830', rc:'#201c24' },
      water:  { tc:'#1a3558', lc:'#122840', rc:'#0e2035' },
    },
    dist: { rock:.20, hill:.20, forest:.08, water:0 }
  },
  jungle: {
    colors: {
      plain:  { tc:'#1e3e28', lc:'#142e1c', rc:'#0e2414' },
      forest: { tc:'#0e4420', lc:'#083416', rc:'#04280e' },
      hill:   { tc:'#2e4a20', lc:'#1e3610', rc:'#142a08' },
      rock:   { tc:'#2a3230', lc:'#1a2220', rc:'#101816' },
      water:  { tc:'#1a4048', lc:'#103038', rc:'#0a242e' },
    },
    dist: { rock:.05, hill:.05, forest:.40, water:.08 }
  },
  desert: {
    colors: {
      plain:  { tc:'#6e5c38', lc:'#584828', rc:'#48381c' },
      forest: { tc:'#5a5030', lc:'#443c20', rc:'#362e14' },
      hill:   { tc:'#7a6430', lc:'#5e4c1c', rc:'#4a3c14' },
      rock:   { tc:'#5a5048', lc:'#3e3830', rc:'#2e2824' },
      water:  { tc:'#1a3558', lc:'#122840', rc:'#0e2035' },
    },
    dist: { rock:.08, hill:.30, forest:0, water:0 }
  },
  volcano: {
    colors: {
      plain:  { tc:'#3a2828', lc:'#2a1c1c', rc:'#1e1414' },
      forest: { tc:'#2e3020', lc:'#1e2214', rc:'#14180c' },
      hill:   { tc:'#4a3020', lc:'#362214', rc:'#28180c' },
      rock:   { tc:'#2e2030', lc:'#1e1420', rc:'#140e18' },
      water:  { tc:'#5a2010', lc:'#42180c', rc:'#301008' },
    },
    dist: { rock:.22, hill:.18, forest:.03, water:.10 }
  },
  frozen: {
    colors: {
      plain:  { tc:'#d0e0f0', lc:'#b0c8dc', rc:'#90afc8' },
      forest: { tc:'#4a6070', lc:'#3a4e5c', rc:'#2a3e48' },
      hill:   { tc:'#e0f0ff', lc:'#c8dcf0', rc:'#b0c8e0' },
      rock:   { tc:'#8090a0', lc:'#607080', rc:'#405060' },
      water:  { tc:'#a0c8f0', lc:'#80b0dc', rc:'#6098c8' },
    },
    dist: { rock:.15, hill:.20, forest:.10, water:.15 }
  },
  ruins: {
    colors: {
      plain:  { tc:'#4a4a50', lc:'#3a3a40', rc:'#2a2a30' },
      forest: { tc:'#2a3a30', lc:'#1a2a20', rc:'#0a1a10' },
      hill:   { tc:'#5a5a60', lc:'#4a4a50', rc:'#3a3a40' },
      rock:   { tc:'#3a3a40', lc:'#2a2a30', rc:'#1a1a20' },
      water:  { tc:'#1a2a38', lc:'#0a1a28', rc:'#000a18' },
    },
    dist: { rock:.35, hill:.15, forest:.08, water:.05 }
  },
  swamp: {
    colors: {
      plain:  { tc:'#3a4a38', lc:'#2a3a28', rc:'#1a2a18' },
      forest: { tc:'#2a4030', lc:'#1a3020', rc:'#0a2010' },
      hill:   { tc:'#4a5a40', lc:'#3a4a30', rc:'#2a3a20' },
      rock:   { tc:'#3a4a48', lc:'#2a3a38', rc:'#1a2a28' },
      water:  { tc:'#1a3a28', lc:'#0a2a18', rc:'#001a08' },
    },
    dist: { rock:.08, hill:.10, forest:.25, water:.30 }
  },
  fortress: {
    colors: {
      plain:  { tc:'#5a5860', lc:'#4a4850', rc:'#3a3840' },
      forest: { tc:'#3a4838', lc:'#2a3828', rc:'#1a2818' },
      hill:   { tc:'#6a6870', lc:'#5a5860', rc:'#4a4850' },
      rock:   { tc:'#4a4850', lc:'#3a3840', rc:'#2a2830' },
      water:  { tc:'#2a3848', lc:'#1a2838', rc:'#0a1828' },
    },
    dist: { rock:.25, hill:.15, forest:.05, water:.05 }
  },
  abyss: {
    colors: {
      plain:  { tc:'#2a1a28', lc:'#1a0a18', rc:'#0a0008' },
      forest: { tc:'#1a2020', lc:'#0a1010', rc:'#000000' },
      hill:   { tc:'#3a2a30', lc:'#2a1a20', rc:'#1a0a10' },
      rock:   { tc:'#2a2030', lc:'#1a1020', rc:'#0a0010' },
      water:  { tc:'#3a0a20', lc:'#2a0010', rc:'#1a0000' },
    },
    dist: { rock:.30, hill:.20, forest:.05, water:.15 }
  }
};

function loadTilesets() { return Promise.resolve(); }
