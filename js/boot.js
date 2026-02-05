window.G=G;

document.addEventListener('keydown',e=>{
  if(document.body.dataset.page!=='battle')return;
  if(e.key==='q'||e.key==='Q')G.rotCam(-1);
  if(e.key==='e'||e.key==='E')G.rotCam(1);
  if(e.key==='Escape'){G.closeSettings()}
});

window.addEventListener('DOMContentLoaded',()=>{
  ROSTER.load();
  G.loadSett();
  G._loadGold();

  const page=document.body.dataset.page;
  if(page==='lobby')G._initLobbyPage();
  else if(page==='stage-select')G._initStageSelectPage();
  else if(page==='party-select')G._initPartySelectPage();
  else if(page==='battle')G._initBattlePage();
  else if(page==='sanctuary'){G._updGoldUI();G._renderSanctuary()}
  else if(page==='shop'){G._updGoldUI();G._loadShop();G._renderShop()}
  else if(page==='settings')G._renderLobbySettings();
});

window.addEventListener('resize',()=>{if(G.ter&&G.ter.length){G.layW()}});

Object.assign(G,{
  _battleListenersInit:false,
  _initBattleListeners(){
    if(this._battleListenersInit)return;
    this._battleListenersInit=true;
    document.getElementById('minimap').addEventListener('click',e=>G.mmClick(e));
    document.getElementById('map-container').addEventListener('scroll',()=>G.rMMvp());
    document.getElementById('iso-world').addEventListener('click',e=>{
      const w=document.getElementById('iso-world');
      const rect=w.getBoundingClientRect();
      const px=e.clientX-rect.left, py=e.clientY-rect.top;
      const hit=G.isoHit(px,py);
      if(!hit)return;
      const{c,r}=hit;
      if(c<0||c>=COLS||r<0||r>=ROWS)return;
      if(G.awPM){G.cellCk(c,r);return}
      const u=G.uAt(c,r);
      if(u&&!G.sel){G.selU(u);return}
      if(u&&G.sel&&u.id===G.sel.id){G.clrSel();return}
      G.cellCk(c,r);
    });
  }
});
