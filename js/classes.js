// ═══════════════════════════════════════════
//  classes.js — 직업 기본 데이터
//  새 직업 추가 시 이 파일만 수정
// ═══════════════════════════════════════════

const CD = {
  warrior: {
    name:'전사', icon:'⚔️', role:'melee', desc:'균형 근접 딜러',
    res:'fury', maxRes:10, resRec:0,
    // Lv1 기본 스탯
    base: { hp:100, atk:25, def:10, move:3, range:1 },
    // 레벨업 최소/최대 상승량 (잠재력 범위)
    growth: { hp:[8,14], atk:[2,4], def:[1,2] }
  },
  tanker: {
    name:'탱커', icon:'🛡️', role:'melee', desc:'고체력 방어',
    res:'fury', maxRes:10, resRec:0,
    base: { hp:150, atk:15, def:20, move:2, range:1 },
    growth: { hp:[12,18], atk:[1,2], def:[2,4] }
  },
  assassin: {
    name:'암살자', icon:'🗡️', role:'melee', desc:'고공 고기동',
    res:'energy', maxRes:80, resRec:15,
    base: { hp:70, atk:35, def:5, move:4, range:1 },
    growth: { hp:[5,9], atk:[3,5], def:[0,1] }
  },
  mage: {
    name:'마법사', icon:'🔮', role:'ranged', desc:'원거리 마법',
    res:'mana', maxRes:120, resRec:12,
    base: { hp:65, atk:30, def:4, move:3, range:3 },
    growth: { hp:[5,8], atk:[2,5], def:[0,1] }
  },
  archer: {
    name:'궁수', icon:'🏹', role:'ranged', desc:'최장 사거리',
    res:'energy', maxRes:60, resRec:12,
    base: { hp:60, atk:28, def:3, move:3, range:4 },
    growth: { hp:[5,9], atk:[2,4], def:[0,2] }
  },
  priest: {
    name:'사제', icon:'✝️', role:'healer', desc:'아군 치유',
    res:'mana', maxRes:100, resRec:10,
    base: { hp:70, atk:20, def:5, move:3, range:3 },
    growth: { hp:[6,10], atk:[1,3], def:[1,2] }
  }
};

// ── 지형 데이터 ──────────────────────────
const TI = {
  plain:  { cost:1,       z:0, label:'',  pass:true,  tc:'#2a3a4e', lc:'#1e2d3d', rc:'#162232', buff:null },
  forest: { cost:1.5,     z:0, label:'🌲', pass:true,  tc:'#1f3d2a', lc:'#162e1f', rc:'#102216', buff:{name:'은신',icon:'🌿',type:'buff',desc:'DEF+3'} },
  hill:   { cost:2,       z:1, label:'⛰',  pass:true,  tc:'#4a3a20', lc:'#3a2c16', rc:'#2e2210', buff:{name:'고지',icon:'⬆',type:'buff',desc:'ATK+5'} },
  rock:   { cost:Infinity,z:3, label:'',  pass:false, tc:'#1a1a28', lc:'#121220', rc:'#0e0e18', buff:null },
  water:  { cost:Infinity,z:0, label:'',  pass:false, tc:'#1a3050', lc:'#142640', rc:'#102035', buff:null },
  wall:   { cost:Infinity,z:2, label:'',  pass:false, tc:'#4a4458', lc:'#383248', rc:'#2e283c', buff:null },
  gate:   { cost:1,       z:0, label:'',  pass:true,  tc:'#3a3048', lc:'#2e2840', rc:'#262035', buff:null }
};

// ── 스테이지 데이터 ──────────────────────
const STAGES = [
  { id:1, name:'초원의 전투',  tot:6,  spw:2, si:2, en:['warrior','warrior','warrior','warrior','warrior','warrior'], sm:{hp:.7,atk:.7} },
  { id:2, name:'숲의 습격',    tot:8,  spw:2, si:2, en:['warrior','warrior','warrior','assassin','assassin','warrior','warrior','archer'], sm:{hp:.8,atk:.8} },
  { id:3, name:'언덕 방어전',  tot:10, spw:3, si:2, en:['warrior','warrior','tanker','assassin','assassin','archer','archer','mage','warrior','warrior'], sm:{hp:.85,atk:.85} },
  { id:4, name:'암흑의 계곡',  tot:12, spw:3, si:2, en:['tanker','warrior','assassin','mage','archer','warrior','tanker','assassin','mage','archer','warrior','warrior'], sm:{hp:.9,atk:.9} },
  { id:5, name:'마왕의 관문',  tot:14, spw:3, si:2, en:['tanker','tanker','assassin','assassin','mage','mage','archer','archer','warrior','warrior','tanker','assassin','mage','warrior'], sm:{hp:1,atk:1} },
  { id:6, name:'최후의 결전',  tot:16, spw:4, si:2, en:['tanker','tanker','tanker','assassin','assassin','assassin','mage','mage','mage','archer','archer','archer','warrior','warrior','warrior','warrior'], sm:{hp:1.1,atk:1.05} }
];
