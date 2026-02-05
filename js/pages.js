const Pages={
  _loaded:new Set(),
  _pending:{},
  async load(name){
    if(this._loaded.has(name))return;
    if(this._pending[name])return this._pending[name];
    this._pending[name]=(async()=>{
      const resp=await fetch(`pages/${name}.html`);
      const html=await resp.text();
      const frag=document.createRange().createContextualFragment(html);
      document.body.appendChild(frag);
      this._loaded.add(name);
      delete this._pending[name];
    })();
    return this._pending[name];
  }
};
