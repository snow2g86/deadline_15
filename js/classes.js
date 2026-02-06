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
  knight: {
    name:'기사', icon:'🛡️', role:'melee', desc:'방어 탱커',
    res:'fury', maxRes:10, resRec:0,
    base: { hp:150, atk:15, def:20, move:2, range:1 },
    growth: { hp:[12,18], atk:[1,2], def:[2,4] }
  },
  assassin: {
    name:'암살자', icon:'🗡️', role:'melee', desc:'고속 암살자',
    res:'energy', maxRes:100, resRec:15,
    base: { hp:70, atk:35, def:5, move:4, range:1 },
    growth: { hp:[5,9], atk:[3,5], def:[0,1] }
  },
  mage: {
    name:'마법사', icon:'🔮', role:'ranged', desc:'원거리 마법사',
    res:'mana', maxRes:120, resRec:12,
    base: { hp:65, atk:30, def:4, move:3, range:3 },
    growth: { hp:[5,8], atk:[2,5], def:[0,1] }
  },
  archer: {
    name:'궁수', icon:'🏹', role:'ranged', desc:'원거리 궁수',
    res:'energy', maxRes:100, resRec:12,
    base: { hp:60, atk:28, def:3, move:3, range:4 },
    growth: { hp:[5,9], atk:[2,4], def:[0,2] }
  },
  priest: {
    name:'사제', icon:'✝️', role:'healer', desc:'회복 힐러',
    res:'mana', maxRes:100, resRec:10,
    base: { hp:70, atk:20, def:5, move:3, range:3 },
    growth: { hp:[6,10], atk:[1,3], def:[1,2] }
  },
  novice: {
    name:'노비스', icon:'🔰', role:'melee', desc:'초보 전사',
    res:'energy', maxRes:100, resRec:10,
    base: { hp:85, atk:22, def:8, move:3, range:1 },
    growth: { hp:[7,12], atk:[2,3], def:[1,2] }
  },
  summoner: {
    name:'소환사', icon:'📖', role:'ranged', desc:'소환 지원가',
    res:'mana', maxRes:110, resRec:11,
    base: { hp:60, atk:26, def:4, move:3, range:3 },
    growth: { hp:[4,8], atk:[2,4], def:[0,1] }
  },
  shaman: {
    name:'주술사', icon:'🎭', role:'ranged', desc:'강화 주술사',
    res:'mana', maxRes:100, resRec:10,
    base: { hp:70, atk:28, def:6, move:3, range:3 },
    growth: { hp:[5,9], atk:[2,4], def:[1,2] }
  },
  brawler: {
    name:'무투가', icon:'👊', role:'melee', desc:'맨손 격투가',
    res:'energy', maxRes:100, resRec:12,
    base: { hp:90, atk:32, def:7, move:3, range:1 },
    growth: { hp:[7,11], atk:[3,5], def:[0,2] }
  },
  lancer: {
    name:'창술사', icon:'🔱', role:'melee', desc:'관통 창술사',
    res:'fury', maxRes:5, resRec:0,
    base: { hp:95, atk:28, def:12, move:3, range:1 },
    growth: { hp:[8,13], atk:[2,4], def:[1,3] }
  },
  sapper: {
    name:'공병', icon:'💣', role:'melee', desc:'함정 공병',
    res:'energy', maxRes:100, resRec:8,
    base: { hp:75, atk:30, def:6, move:3, range:1 },
    growth: { hp:[5,9], atk:[2,5], def:[0,1] }
  },
  // ═════ 소환수 클래스 (임시 유닛) ═════
  'summon_spirit': {
    name:'정령', icon:'✨', role:'ranged', desc:'소환된 마법 정령 (5턴)',
    res:'none', maxRes:0, resRec:0,
    base: { hp:15, atk:15, def:0, move:3, range:3 },
    growth: { hp:[0,0], atk:[0,0], def:[0,0] }
  },
  'summon_golem': {
    name:'골램', icon:'🗿', role:'melee', desc:'소환된 마법 골램 (5턴)',
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
  rock:   { cost:Infinity,z:0, label:'',  pass:false, tc:'#3a3a48', lc:'#2a2a38', rc:'#1e1e28', buff:null },
  water:  { cost:Infinity,z:0, label:'',  pass:false, tc:'#1a3050', lc:'#142640', rc:'#102035', buff:null },
  wall:   { cost:Infinity,z:2, label:'',  pass:false, tc:'#4a4458', lc:'#383248', rc:'#2e283c', buff:null },
  gate:   { cost:1,       z:0, label:'',  pass:true,  tc:'#3a3048', lc:'#2e2840', rc:'#262035', buff:null }
};

// ── 스테이지 데이터 ──────────────────────
// 테마별 스타일: defense(성벽있음) | offense(성벽없음,적장)
const STAGES = [
  // ═══════════════════════════════════════════
  // Phase 1: 영웅의 시작
  // ═══════════════════════════════════════════

  // ─── Stage 1-5: 마을 지킴 ───
  { id:1, phase:1, phaseTitle:'영웅의 시작', name:'초원의 경비',  theme:'마을지킴', style:'defense', story:'산적의 약탈을 저지하라', tot:6,  spw:2, si:2, boss:null, en:['novice','novice','novice','novice','novice','novice'], sm:{hp:.65,atk:.65} },
  { id:2, phase:1, phaseTitle:'영웅의 시작', name:'마을 제2경비', theme:'마을지킴', style:'defense', story:'더 강한 산적단 습격 격퇴', tot:8,  spw:2, si:2, boss:null, en:['novice','novice','novice','novice','warrior','warrior','novice','novice'], sm:{hp:.75,atk:.75} },
  { id:3, phase:1, phaseTitle:'영웅의 시작', name:'목초지 방어',   theme:'마을지킴', style:'defense', story:'산적 부대 격퇴', tot:10, spw:2, si:2, boss:null, en:['novice','warrior','novice','warrior','novice','warrior','novice','warrior','novice','warrior'], sm:{hp:.8,atk:.8} },
  { id:4, phase:1, phaseTitle:'영웅의 시작', name:'마을 주변 정찰', theme:'마을지킴', style:'defense', story:'주변 산적소굴 정찰', tot:10, spw:3, si:2, boss:null, en:['warrior','novice','warrior','warrior','novice','warrior','warrior','novice','warrior','assassin'], sm:{hp:.85,atk:.85} },
  { id:5, phase:1, phaseTitle:'영웅의 시작', name:'최후의 방어',   theme:'마을지킴', style:'defense', story:'대규모 산적단 습격 저지', tot:12, spw:3, si:2, boss:null, en:['warrior','warrior','warrior','warrior','warrior','assassin','novice','warrior','brawler','warrior','novice','warrior'], sm:{hp:.9,atk:.9} },

  // ─── Stage 6-9: 산적소굴 소탕 ───
  { id:6, phase:1, phaseTitle:'영웅의 시작', name:'산적 소굴 입구', theme:'산적소굴', style:'offense', story:'산적단의 본거지 입구 진입', tot:10, spw:3, si:2, boss:null, en:['warrior','assassin','warrior','lancer','warrior','archer','warrior','novice','brawler','warrior'], sm:{hp:.9,atk:.9} },
  { id:7, phase:1, phaseTitle:'영웅의 시작', name:'소굴 심부',     theme:'산적소굴', style:'offense', story:'산적단 거점 탐색', tot:12, spw:3, si:2, boss:null, en:['warrior','lancer','assassin','archer','brawler','warrior','brawler','assassin','archer','warrior','brawler','warrior'], sm:{hp:.95,atk:.95} },
  { id:8, phase:1, phaseTitle:'영웅의 시작', name:'산적 거점 전투1', theme:'산적소굴', style:'offense', story:'산적 거점 병력 격파', tot:12, spw:3, si:2, boss:null, en:['warrior','assassin','warrior','lancer','warrior','archer','warrior','novice','brawler','warrior','warrior','assassin'], sm:{hp:1,atk:1} },
  { id:9, phase:1, phaseTitle:'영웅의 시작', name:'산적 거점 전투2', theme:'산적소굴', style:'offense', story:'산적 대장 격파 임박', tot:14, spw:3, si:2, boss:null, en:['warrior','lancer','assassin','brawler','summoner','warrior','archer','warrior','warrior','lancer','brawler','archer','warrior','warrior'], sm:{hp:1.05,atk:1.05} },

  // ─── Stage 10: 산적 보스 ───
  { id:10, phase:1, phaseTitle:'영웅의 시작', name:'산적 우두머리 격파', theme:'산적소굴', style:'offense', story:'산적 세력 거점 최종 격파', tot:16, spw:4, si:2, boss:{cls:'warrior',name:'산적 우두머리'}, en:['lancer','lancer','assassin','brawler','summoner','shaman','archer','sapper','sapper','warrior','warrior','lancer','brawler','archer','warrior','warrior'], sm:{hp:1.1,atk:1.1} }
];
