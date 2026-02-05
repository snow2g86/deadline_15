// ═══════════════════════════════════════════
//  classes.js — 직업 기본 데이터
//  새 직업 추가 시 이 파일만 수정
// ═══════════════════════════════════════════

const CD = {
  warrior: {
    name:'전사', icon:'⚔️', iconRow:90, iconCol:0, role:'melee', desc:'균형 근접 딜러',
    res:'fury', maxRes:10, resRec:0,
    // Lv1 기본 스탯
    base: { hp:100, atk:25, def:10, move:3, range:1 },
    // 레벨업 최소/최대 상승량 (잠재력 범위)
    growth: { hp:[8,14], atk:[2,4], def:[1,2] }
  },
  knight: {
    name:'기사', icon:'🛡️', iconRow:41, iconCol:7, role:'melee', desc:'고체력 방어',
    res:'fury', maxRes:10, resRec:0,
    base: { hp:150, atk:15, def:20, move:2, range:1 },
    growth: { hp:[12,18], atk:[1,2], def:[2,4] }
  },
  assassin: {
    name:'암살자', icon:'🗡️', iconRow:94, iconCol:3, role:'melee', desc:'고공 고기동',
    res:'energy', maxRes:100, resRec:15,
    base: { hp:70, atk:35, def:5, move:4, range:1 },
    growth: { hp:[5,9], atk:[3,5], def:[0,1] }
  },
  mage: {
    name:'마법사', icon:'🔮', iconRow:98, iconCol:2, role:'ranged', desc:'원거리 마법',
    res:'mana', maxRes:120, resRec:12,
    base: { hp:65, atk:30, def:4, move:3, range:3 },
    growth: { hp:[5,8], atk:[2,5], def:[0,1] }
  },
  archer: {
    name:'궁수', icon:'🏹', iconRow:93, iconCol:10, role:'ranged', desc:'최장 사거리',
    res:'energy', maxRes:100, resRec:12,
    base: { hp:60, atk:28, def:3, move:3, range:4 },
    growth: { hp:[5,9], atk:[2,4], def:[0,2] }
  },
  priest: {
    name:'사제', icon:'✝️', iconRow:103, iconCol:15, role:'healer', desc:'아군 치유',
    res:'mana', maxRes:100, resRec:10,
    base: { hp:70, atk:20, def:5, move:3, range:3 },
    growth: { hp:[6,10], atk:[1,3], def:[1,2] }
  },
  novice: {
    name:'노비스', icon:'🗡️', iconRow:90, iconCol:1, role:'melee', desc:'초보 근접 딜러',
    res:'energy', maxRes:100, resRec:10,
    base: { hp:85, atk:22, def:8, move:3, range:1 },
    growth: { hp:[7,12], atk:[2,3], def:[1,2] }
  },
  summoner: {
    name:'소환사', icon:'📖', iconRow:18, iconCol:0, role:'ranged', desc:'소환 원거리',
    res:'mana', maxRes:110, resRec:11,
    base: { hp:60, atk:26, def:4, move:3, range:3 },
    growth: { hp:[4,8], atk:[2,4], def:[0,1] }
  },
  shaman: {
    name:'주술사', icon:'🎭', iconRow:46, iconCol:2, role:'ranged', desc:'저주 원거리',
    res:'mana', maxRes:100, resRec:10,
    base: { hp:70, atk:28, def:6, move:3, range:3 },
    growth: { hp:[5,9], atk:[2,4], def:[1,2] }
  },
  brawler: {
    name:'무투가', icon:'👊', iconRow:102, iconCol:15, role:'melee', desc:'격투 근접 딜러',
    res:'energy', maxRes:100, resRec:12,
    base: { hp:90, atk:32, def:7, move:3, range:1 },
    growth: { hp:[7,11], atk:[3,5], def:[0,2] }
  },
  lancer: {
    name:'창술사', icon:'🔱', iconRow:110, iconCol:0, role:'melee', desc:'창 근접 딜러',
    res:'fury', maxRes:5, resRec:0,
    base: { hp:95, atk:28, def:12, move:3, range:1 },
    growth: { hp:[8,13], atk:[2,4], def:[1,3] }
  },
  sapper: {
    name:'공병', icon:'💣', iconRow:47, iconCol:3, role:'melee', desc:'폭발 근접 딜러',
    res:'energy', maxRes:100, resRec:8,
    base: { hp:75, atk:30, def:6, move:3, range:1 },
    growth: { hp:[5,9], atk:[2,5], def:[0,1] }
  },
  // ═════ 소환수 클래스 (임시 유닛) ═════
  'summon_spirit': {
    name:'정령', icon:'✨', iconRow:19, iconCol:3, role:'ranged', desc:'소환된 마법 정령 (5턴)',
    res:'none', maxRes:0, resRec:0,
    base: { hp:15, atk:15, def:0, move:3, range:3 },
    growth: { hp:[0,0], atk:[0,0], def:[0,0] }
  },
  'summon_golem': {
    name:'골램', icon:'🗿', iconRow:19, iconCol:4, role:'melee', desc:'소환된 마법 골램 (5턴)',
    res:'none', maxRes:0, resRec:0,
    base: { hp:30, atk:12, def:5, move:2, range:1 },
    growth: { hp:[0,0], atk:[0,0], def:[0,0] }
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
// 테마별 스타일: defense(성벽있음) | offense(성벽없음,적장)
const STAGES = [
  // ═══ 마을 방어 (DEFENSE) ═══
  { id:1, name:'초원의 경비',  theme:'마을지킴', style:'defense', story:'산적의 약탈을 저지하라', tot:6,  spw:2, si:2, boss:null, en:['novice','novice','novice','novice','novice','novice'], sm:{hp:.65,atk:.65} },
  { id:2, name:'마을 제2경비', theme:'마을지킴', style:'defense', story:'더 강한 산적단 습격 격퇴', tot:8,  spw:2, si:2, boss:null, en:['novice','novice','novice','novice','warrior','warrior','novice','novice'], sm:{hp:.75,atk:.75} },

  // ═══ 산적 소굴 (OFFENSE) ═══
  { id:3, name:'산적 소굴',    theme:'산적소굴', style:'offense', story:'산적단의 본거지 잠입', tot:10, spw:3, si:2, boss:null, en:['novice','warrior','novice','warrior','novice','warrior','warrior','novice','warrior','assassin'], sm:{hp:.8,atk:.8} },
  { id:4, name:'산적단 거점',  theme:'산적소굴', style:'offense', story:'산적단 거점 격파', tot:12, spw:3, si:2, boss:{cls:'warrior',name:'산적 우두머리'}, en:['warrior','warrior','assassin','novice','warrior','brawler','warrior','assassin','warrior','brawler','warrior'], sm:{hp:.9,atk:.9} },

  // ═══ 성채 방어 (DEFENSE) ═══
  { id:5, name:'성채 제1경비', theme:'성채방어', style:'defense', story:'성채 침입 적군 격퇴', tot:10, spw:3, si:2, boss:null, en:['warrior','assassin','warrior','knight','warrior','archer','warrior','novice','brawler','warrior'], sm:{hp:.85,atk:.85} },
  { id:6, name:'성채 제2경비', theme:'성채방어', style:'defense', story:'적군의 대규모 침략 저지', tot:12, spw:3, si:2, boss:null, en:['warrior','knight','assassin','archer','brawler','warrior','knight','assassin','archer','warrior','brawler','warrior'], sm:{hp:.95,atk:.95} },

  // ═══ 강도단 본거지 (OFFENSE) ═══
  { id:7, name:'강도단 본거지', theme:'강도단', style:'offense', story:'강도단 최후의 거점 진격', tot:14, spw:3, si:2, boss:{cls:'lancer',name:'강도단 사령관'}, en:['knight','warrior','assassin','archer','brawler','knight','assassin','shaman','sapper','warrior','lancer','warrior','brawler'], sm:{hp:1,atk:1} },
  { id:8, name:'강도단 보스전', theme:'강도단', style:'offense', story:'강도단 두목 격파', tot:16, spw:4, si:2, boss:{cls:'knight',name:'강도단 두목'}, en:['knight','lancer','assassin','brawler','summoner','shaman','archer','sapper','sapper','warrior','warrior','lancer','brawler','archer','warrior'], sm:{hp:1.05,atk:1.05} },

  // ═══ 마계 침공 (SPECIAL/MIXED) ═══
  { id:9, name:'마계의 입구',  theme:'마계', style:'mixed', story:'마계 생물 침입 저지', tot:14, spw:3, si:2, boss:{cls:'brawler',name:'마계 선봉대장'}, en:['knight','lancer','assassin','brawler','summoner','shaman','mage','archer','sapper','sapper','warrior','warrior'], sm:{hp:1.1,atk:1.05} },
  { id:10, name:'최후의 결전', theme:'마계', style:'mixed', story:'마계의 왕 격파', tot:16, spw:4, si:2, boss:{cls:'summoner',name:'마계의 왕'}, en:['knight','lancer','lancer','assassin','brawler','brawler','shaman','mage','archer','sapper','sapper','warrior','warrior','novice','warrior'], sm:{hp:1.15,atk:1.1} }
];
