var EPISODES = [
  { id:1, stages:[1,2,3,4,5,6,7,8,9,10] }
];

var STAGES = [
  { id:1, phase:1, style:'defense', tot:6,  spw:2, si:2, boss:null, en:['novice','novice','novice','novice','novice','novice'], sm:{hp:.65,atk:.65} },
  { id:2, phase:1, style:'defense', tot:8,  spw:2, si:2, boss:null, en:['novice','novice','novice','novice','warrior','warrior','novice','novice'], sm:{hp:.75,atk:.75} },
  { id:3, phase:1, style:'defense', tot:10, spw:2, si:2, boss:null, en:['novice','warrior','novice','warrior','novice','warrior','novice','warrior','novice','warrior'], sm:{hp:.8,atk:.8} },
  { id:4, phase:1, style:'defense', tot:10, spw:3, si:2, boss:null, en:['warrior','novice','warrior','warrior','novice','warrior','warrior','novice','warrior','assassin'], sm:{hp:.85,atk:.85} },
  { id:5, phase:1, style:'defense', tot:12, spw:3, si:2, boss:null, en:['warrior','warrior','warrior','warrior','warrior','assassin','novice','warrior','brawler','warrior','novice','warrior'], sm:{hp:.9,atk:.9} },
  { id:6, phase:1, style:'offense', tot:10, spw:3, si:2, boss:null, en:['warrior','assassin','warrior','lancer','warrior','archer','warrior','novice','brawler','warrior'], sm:{hp:.9,atk:.9} },
  { id:7, phase:1, style:'offense', tot:12, spw:3, si:2, boss:null, en:['warrior','lancer','assassin','archer','brawler','warrior','brawler','assassin','archer','warrior','brawler','warrior'], sm:{hp:.95,atk:.95} },
  { id:8, phase:1, style:'offense', tot:12, spw:3, si:2, boss:null, en:['warrior','assassin','warrior','lancer','warrior','archer','warrior','novice','brawler','warrior','warrior','assassin'], sm:{hp:1,atk:1} },
  { id:9, phase:1, style:'offense', tot:14, spw:3, si:2, boss:null, en:['warrior','lancer','assassin','brawler','summoner','warrior','archer','warrior','warrior','lancer','brawler','archer','warrior','warrior'], sm:{hp:1.05,atk:1.05} },
  { id:10, phase:1, style:'offense', tot:16, spw:4, si:2, boss:{cls:'warrior',name:'boss'}, en:['lancer','lancer','assassin','brawler','summoner','shaman','archer','sapper','sapper','warrior','warrior','lancer','brawler','archer','warrior','warrior'], sm:{hp:1.1,atk:1.1} }
];
