// ═══════════════════════════════════════════
//  battle/render.js — Terrain, Units, UI, Minimap, Menus
//  (merged render.js + ui.js)
// ═══════════════════════════════════════════

const Renderer = {
  _activeTexts: new Map(),
  _bgReady: false,
  _hlTiles: new Map(),
  _hlDelegated: false,
  _mmSc: 0,

  init() { this._subscribe(); },

  _subscribe() {
    EventBus.on('battle_end', ({ win, message }) => { this.showRes(win, message); });
  },

  // ══════════════════════════════════════════
  //  Terrain Rendering
  // ══════════════════════════════════════════
  rTerBg() {
    const S = GameStore;
    const w = document.getElementById('iso-world');
    const existingBgTiles = new Map(), existingHlTiles = new Map();
    w.querySelectorAll('.iso-tile-bg').forEach(el => existingBgTiles.set(el.dataset.pos, el));
    w.querySelectorAll('.iso-tile-hl').forEach(el => existingHlTiles.set(el.dataset.pos, el));
    const tilesNeeded = new Set();
    const W = TW * 2;
    const _tc = Grid._tColors || {};

    if (!this._hlDelegated) {
      w.addEventListener('click', e => {
        const hl = e.target.closest('.iso-tile-hl');
        if (!hl) return;
        e.stopPropagation();
        const rect = w.getBoundingClientRect();
        const px = e.clientX - rect.left, py = e.clientY - rect.top;
        const hit = Grid.isoHit(px, py); if (!hit) return;
        const { c, r } = hit;
        if (c < 0 || c >= COLS || r < 0 || r >= ROWS) return;
        if (S.sel && FSM.is(BattleState.UNIT_SELECTED)) {
          const cl = UnitManager.uAt(c, r);
          if (cl && cl.id === S.sel.id) { ActionManager.clrSel(); return; }
        }
        ActionManager.cellCk(c, r);
      });
      this._hlDelegated = true;
    }

    this._hlTiles.clear();
    for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
      const tp = S.ter[r][c], ti = TI[tp], clr = _tc[tp] || ti;
      const pos = `${c},${r}`; tilesNeeded.add(pos);
      const h = ti.z * ZH, H = TH * 2 + h + 2;
      const clip = h > 0
        ? `polygon(${TW}px 1px,${W - 1}px ${TH}px,${W - 1}px ${TH + h}px,${TW}px ${TH * 2 - 1 + h}px,1px ${TH + h}px,1px ${TH}px)`
        : `polygon(${TW}px 1px,${W - 1}px ${TH}px,${TW}px ${TH * 2 - 1}px,1px ${TH}px)`;

      let bgTile = existingBgTiles.get(pos);
      if (!bgTile) { bgTile = document.createElement('div'); bgTile.className = 'iso-tile iso-tile-bg'; bgTile.dataset.pos = pos; w.appendChild(bgTile); }
      while (bgTile.firstChild) bgTile.removeChild(bgTile.firstChild);
      if (h > 0) {
        const cy = ((TH * 2 - 1) / H * 100).toFixed(1);
        const ang = Math.round(Math.atan2(TW - 1, TH - 1) * 180 / Math.PI);
        bgTile.style.background = `conic-gradient(from 0deg at 50% ${cy}%,${clr.tc} 0deg ${ang}deg,${clr.rc} ${ang}deg 180deg,${clr.lc} 180deg ${360 - ang}deg,${clr.tc} ${360 - ang}deg 360deg)`;
      } else if (tp === 'forest') {
        const fb = clr.tc, fl = clr.lc, fd = clr.rc;
        bgTile.style.background = [
          `radial-gradient(circle 18px at 26% 24%,${fb},${fl} 42%,transparent 72%)`,
          `radial-gradient(circle 20px at 68% 20%,${fb},${fl} 42%,transparent 72%)`,
          `radial-gradient(circle 22px at 48% 46%,${fb},${fl} 42%,transparent 72%)`,
          `radial-gradient(ellipse 2.5px 11px at 26% 54%,${fd},transparent 90%)`,
          `radial-gradient(ellipse 2.5px 11px at 68% 48%,${fd},transparent 90%)`,
          fd
        ].join(',');
      } else if (tp === 'rock') {
        bgTile.style.background = `linear-gradient(135deg,${clr.tc} 25%,${clr.rc} 45%,${clr.tc} 55%,${clr.rc} 75%,${clr.tc})`;
      } else if (tp === 'water') {
        const wA = (S.cStage && S.cStage.mapType === 'volcano') ? 'rgba(140,40,20,.12)' : 'rgba(40,90,140,.12)';
        bgTile.style.background = `repeating-linear-gradient(0deg,transparent,transparent 5px,${wA} 5px,${wA} 6px),${clr.tc}`;
      } else { bgTile.style.background = clr.tc; }
      bgTile.style.clipPath = clip;

      let hlTile = existingHlTiles.get(pos);
      if (!hlTile) {
        hlTile = document.createElement('div'); hlTile.className = 'iso-tile iso-tile-hl'; hlTile.dataset.pos = pos; hlTile.style.cursor = 'pointer';
        w.appendChild(hlTile);
      }
      while (hlTile.firstChild) hlTile.removeChild(hlTile.firstChild);
      hlTile.style.clipPath = clip;

      const sx = Grid.tSX(c, r), sy = Grid.tSY(c, r, ti.z), zix = Grid.g2v(c, r);
      bgTile.style.left = sx + 'px'; bgTile.style.top = sy + 'px'; bgTile.style.width = W + 'px'; bgTile.style.height = H + 'px'; bgTile.style.zIndex = zix.vc + zix.vr;
      hlTile.style.left = sx + 'px'; hlTile.style.top = sy + 'px'; hlTile.style.width = W + 'px'; hlTile.style.height = H + 'px'; hlTile.style.zIndex = zix.vc + zix.vr + 1;
      this._hlTiles.set(pos, hlTile);
    }

    existingBgTiles.forEach((el, pos) => { if (!tilesNeeded.has(pos)) el.remove(); });
    existingHlTiles.forEach((el, pos) => { if (!tilesNeeded.has(pos)) el.remove(); });
    this._bgReady = true;
  },

  rTer() {
    const S = GameStore;
    if (!this._bgReady) { this.rTerBg(); }
    Grid.calcFOW();
    this._hlTiles.forEach((hlTile, pos) => {
      const [c, r] = pos.split(',').map(Number);
      let hl = '';
      if (S.sel) {
        if (S.mvT.some(m => m.x === c && m.y === r)) hl = 'move';
        else if (S.atkT.some(a => a.x === c && a.y === r)) hl = 'attack';
        else if (S.healT.some(h => h.x === c && h.y === r)) hl = 'heal';
        if (S.sel.x === c && S.sel.y === r) hl = 'selected';
      }
      hlTile.classList.toggle('hl-move', hl === 'move');
      hlTile.classList.toggle('hl-attack', hl === 'attack');
      hlTile.classList.toggle('hl-heal', hl === 'heal');
      hlTile.classList.toggle('hl-selected', hl === 'selected');
      hlTile.classList.toggle('fow-dark', !S.fogVisible.has(pos));
    });
  },

  // ══════════════════════════════════════════
  //  Unit Rendering
  // ══════════════════════════════════════════
  rUnits() {
    const S = GameStore;
    const w = document.getElementById('iso-world'), al = S.units.filter(u => u.hp > 0), ids = new Set();
    const resClr = u => u.resType === 'mana' ? '#4488ff' : u.resType === 'energy' ? '#f0c040' : '#ff6644';
    al.forEach(u => {
      ids.add('u-' + u.id); let el = document.getElementById('u-' + u.id);
      if (!el) {
        el = document.createElement('div'); el.id = 'u-' + u.id; el.className = 'unit-sprite ' + u.team + ' spawning';
        if (u.team === 'ally') S.allyPos[u.id] = { x: u.x, y: u.y };
        setTimeout(() => el.classList.remove('spawning'), 450);
        // Build unit DOM safely
        const iconDiv = document.createElement('div'); iconDiv.className = 'u-icon';
        const spriteEl = document.createElement('span');
        spriteEl.textContent = ''; // placeholder
        iconDiv.append(spriteEl);
        // Use charSprite which returns safe markup
        iconDiv.insertAdjacentHTML('beforeend', charSprite(u.cls, 36, u.gender));
        if (iconDiv.querySelector('span')) iconDiv.querySelector('span').remove();
        const shadow = document.createElement('div'); shadow.className = 'u-shadow';
        const hpBg = document.createElement('div'); hpBg.className = 'hp-bg';
        const hpFill = document.createElement('div'); hpFill.className = 'hp-fill'; hpBg.appendChild(hpFill);
        const mpBg = document.createElement('div'); mpBg.className = 'mp-bg';
        const mpFill = document.createElement('div'); mpFill.className = 'mp-fill'; mpBg.appendChild(mpFill);
        el.appendChild(iconDiv); el.appendChild(shadow); el.appendChild(hpBg); el.appendChild(mpBg);
        w.appendChild(el);
        if (u.team === 'enemy') { u._gdx = 0; u._gdy = 1; VFX._applyFace(u.id); }
      }
      const inFog = u.team === 'enemy' && !S.fogVisible.has(u.x + ',' + u.y);
      el.style.display = inFog ? 'none' : '';
      el.style.width = UW + 'px'; el.style.height = UH + 'px';
      el.style.transform = 'translate(' + Grid.uSX(u.x, u.y) + 'px,' + Grid.uSY(u.x, u.y) + 'px)';
      const v = Grid.g2v(u.x, u.y); el.style.zIndex = 100 + v.vc + v.vr;
      const hpFill = el._hpFill || (el._hpFill = el.querySelector('.hp-fill'));
      if (hpFill) hpFill.style.width = (u.hp / u.mhp * 100) + '%';
      const mpFill = el._mpFill || (el._mpFill = el.querySelector('.mp-fill'));
      if (mpFill) {
        mpFill.style.width = (u.maxRes ? u.res / u.maxRes * 100 : 0) + '%';
        mpFill.style.background = resClr(u);
      }
      const isSel = S.sel && S.sel.id === u.id;
      const isCur = S.curUnit && S.curUnit.id === u.id;
      el.classList.toggle('acted', u.team === 'ally' && u.ha && !isSel); el.classList.remove('ally', 'enemy'); el.classList.add(u.team);
      el.classList.toggle('cur-turn', !!isCur);
      el.classList.toggle('stealthed', isStealthed(u));
      el.classList.toggle('stunned', UnitManager.isCC(u));
      el.classList.toggle('potion-target', FSM.is(BattleState.ITEM_TARGET) && S.potionTargets && S.potionTargets.some(pt => pt.id === u.id));
      let stunLabel = el._stunLabel || (el._stunLabel = el.querySelector('.stun-label'));
      if (u.stunned > 0 || u.frozen > 0) {
        if (!stunLabel) { stunLabel = document.createElement('div'); stunLabel.className = 'stun-label'; el.appendChild(stunLabel); el._stunLabel = stunLabel; }
        stunLabel.textContent = u.frozen > 0 ? '\u2744\uFE0F' + u.frozen : u.stunned;
      } else if (stunLabel) { stunLabel.remove(); el._stunLabel = null; }
      // Buff/debuff badges
      const fx = [];
      const tile = S.ter[u.y] ? S.ter[u.y][u.x] : null;
      if (tile && TI[tile] && TI[tile].buff) fx.push({ icon: TI[tile].buff.icon, cls: TI[tile].buff.type });
      if (u.furyBuff > 0) fx.push({ icon: '\uD83D\uDCA2', cls: 'buff' });
      if (u.defBuff > 0) fx.push({ icon: '\uD83D\uDEE1\uFE0F', cls: 'buff' });
      if (u.disarmed > 0) fx.push({ icon: '\uD83E\uDD1B', cls: 'debuff' });
      if (u.channeling) fx.push({ icon: u.channeling === 'shaman_curse' ? '\u2620\uFE0F' : '\uD83D\uDD3A', cls: u.channeling === 'shaman_curse' ? 'debuff' : 'buff' });
      let badges = el.querySelector('.u-badges');
      if (fx.length) {
        if (!badges) { badges = document.createElement('div'); badges.className = 'u-badges'; el.appendChild(badges); }
        badges.textContent = '';
        fx.forEach(e => {
          const span = document.createElement('span');
          span.className = 'u-badge ' + e.cls;
          span.textContent = e.icon;
          badges.appendChild(span);
        });
      } else if (badges) badges.remove();
      if (u.isSummon && u.summonTurns !== undefined) {
        let turnLabel = el.querySelector('.summon-turns');
        if (!turnLabel) {
          turnLabel = document.createElement('div'); turnLabel.className = 'summon-turns';
          turnLabel.style.cssText = 'position:absolute;top:-8px;right:-8px;background:#8b5cf6;color:#fff;border-radius:50%;width:20px;height:20px;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:bold;border:2px solid #fff;z-index:10;';
          el.appendChild(turnLabel);
        }
        turnLabel.textContent = u.summonTurns;
      } else {
        const turnLabel = el.querySelector('.summon-turns');
        if (turnLabel) turnLabel.remove();
      }
    });
    [...w.querySelectorAll('.unit-sprite')].forEach(el => { if (!ids.has(el.id)) el.remove(); });
    S.units.filter(u => u.team === 'ally' && u.hp <= 0).forEach(u => {
      S.allyPos[u.id] = { x: 99, y: 99 };
    });
    this.rMM(); this.rTurnOrder();
  },

  // ══════════════════════════════════════════
  //  Float Text
  // ══════════════════════════════════════════
  floatT(x, y, txt, tp) {
    const w = document.getElementById('iso-world'), el = document.createElement('div');
    const posKey = x + ',' + y;
    const count = (this._activeTexts.get(posKey) || 0) + 1;
    this._activeTexts.set(posKey, count);
    const yOffset = -8 - (count - 1) * 18;
    el.className = 'float-text ' + tp;
    el.textContent = txt;
    el.style.left = (Grid.uSX(x, y) + UCX / 2) + 'px';
    el.style.top = (Grid.uSY(x, y) + yOffset) + 'px';
    el.style.zIndex = 500;
    w.appendChild(el);
    setTimeout(() => {
      el.remove();
      const newCount = (this._activeTexts.get(posKey) || 1) - 1;
      if (newCount <= 0) this._activeTexts.delete(posKey);
      else this._activeTexts.set(posKey, newCount);
    }, 950);
  },

  // ══════════════════════════════════════════
  //  Action Menu
  // ══════════════════════════════════════════
  showAM(u) {
    const S = GameStore;
    const m = document.getElementById('action-menu');
    m.style.left = (Grid.uSX(u.x, u.y) + UW + 2) + 'px';
    m.style.top = Grid.uSY(u.x, u.y) + 'px'; m.style.zIndex = 500;
    if (u.channeling) {
      this.hideAllMenuButtons();
      document.getElementById('btn-cancel').style.display = 'none';
      const btn = document.createElement('button'); btn.className = 'am-skill';
      btn.textContent = t('messages.unlock');
      btn.onclick = () => ActionManager.cancelChannel();
      const btnDash = document.getElementById('btn-dash');
      m.insertBefore(btn, btnDash);
      btnDash.style.display = '';
      btnDash.textContent = t('battle.wait');
      m.classList.add('show'); return;
    }
    if (S._skillMenuOpen) { this.showSkillSubMenu(u); return; }
    if (S._itemMenuOpen) { this.showItemSubMenu(u); return; }
    this.showMainMenu(u);
  },

  showMainMenu(u) {
    const S = GameStore;
    const m = document.getElementById('action-menu');
    m.querySelectorAll('.am-skill, .am-item, .am-healer-atk').forEach(e => e.remove());

    if (S._skillFailedMsg) {
      document.getElementById('btn-move').style.display = 'none';
      document.getElementById('btn-attack').style.display = 'none';
      document.getElementById('btn-skill').style.display = 'none';
      document.getElementById('btn-item').style.display = 'none';
      const btnDash = document.getElementById('btn-dash');
      btnDash.textContent = t('battle.wait'); btnDash.style.display = '';
      const btnCancel = document.getElementById('btn-cancel');
      btnCancel.textContent = t('battle.cancel'); btnCancel.style.display = '';
      btnCancel.onclick = () => ActionManager.hideSkillMenu();
      m.classList.add('show'); return;
    }

    // 이동 버튼: 이동 전이면 표시
    document.getElementById('btn-move').style.display = (!u.hm && !u.mo) ? '' : 'none';

    // 공격 버튼: 힐러 → "공격&회복" 단일 버튼, 비힐러 → "공격"
    const btnAttack = document.getElementById('btn-attack');
    if (u.role === 'healer') {
      btnAttack.textContent = t('battle.attack_heal');
      btnAttack.style.display = (!u.ha && (S.atkT.length > 0 || S.healT.length > 0)) ? '' : 'none';
      btnAttack.onclick = () => ActionManager.actAttack();
    } else {
      btnAttack.textContent = t('battle.attack');
      btnAttack.style.display = (!u.ha && S.atkT.length > 0) ? '' : 'none';
      btnAttack.onclick = () => ActionManager.actAttack();
    }

    // 스킬 버튼: active 스킬이 1개라도 있으면 표시 (개별 disable은 서브메뉴에서)
    const skills = getUnitSkills(u);
    const hasActiveSkill = !u.ha && skills.some(sk => !sk.passive);
    document.getElementById('btn-skill').style.display = hasActiveSkill ? '' : 'none';

    // 아이템 버튼
    const hasPotion = S._battlePotions && S._battlePotions.length > 0;
    const hasSiege = S._siegeItems && S._siegeItems.length > 0;
    document.getElementById('btn-item').style.display = (!u.ha && (hasPotion || hasSiege)) ? '' : 'none';

    // 대기 버튼
    const btnDash = document.getElementById('btn-dash');
    btnDash.textContent = t('battle.wait'); btnDash.style.display = '';

    // 취소/되돌리기 버튼
    const btnCancel = document.getElementById('btn-cancel');
    if (S.preMv) {
      btnCancel.textContent = t('battle.undo_move');
      btnCancel.style.display = '';
    } else {
      btnCancel.style.display = 'none';
    }
    btnCancel.onclick = () => ActionManager.actCancel();
    m.classList.add('show');
  },

  showSkillSubMenu(u) {
    const m = document.getElementById('action-menu');
    this.hideAllMenuButtons();
    m.querySelectorAll('.am-skill').forEach(e => e.remove());
    const skills = getUnitSkills(u);
    const btnDash = document.getElementById('btn-dash');
    skills.forEach((sk, idx) => {
      if (sk.passive) return;
      const btn = document.createElement('button'); btn.className = 'am-skill';
      btn.textContent = t('skills.' + sk.id);
      btn.disabled = !this.canUseSkill(u, sk);
      btn.onclick = () => ActionManager.actSkill(idx);
      m.insertBefore(btn, btnDash);
    });
    btnDash.style.display = 'none';
    const btnCancel = document.getElementById('btn-cancel');
    btnCancel.textContent = t('battle.cancel'); btnCancel.style.display = '';
    btnCancel.onclick = () => ActionManager.hideSkillMenu();
    m.classList.add('show');
  },

  showItemSubMenu(u) {
    const S = GameStore;
    const m = document.getElementById('action-menu');
    this.hideAllMenuButtons();
    m.querySelectorAll('.am-skill,.am-item').forEach(e => e.remove());
    const btnDash = document.getElementById('btn-dash');
    const potionSeen = {};
    if (S._battlePotions) {
      S._battlePotions.forEach((pot, idx) => {
        const def = BATTLE_POTIONS[pot.potionId]; if (!def) return;
        const key = pot.potionId;
        if (!potionSeen[key]) potionSeen[key] = { def, count: 0, firstIdx: idx };
        potionSeen[key].count += pot.quantity || 1;
      });
      Object.keys(potionSeen).forEach(key => {
        const { def, count, firstIdx } = potionSeen[key];
        const btn = document.createElement('button'); btn.className = 'am-item';
        btn.textContent = t('battle_potions.' + def.id) + ' x' + count;
        btn.onclick = () => ActionManager.actPotion(firstIdx);
        m.insertBefore(btn, btnDash);
      });
    }
    const siegeSeen = {};
    if (S._siegeItems) {
      S._siegeItems.forEach((si, idx) => {
        const def = SIEGE_ITEMS.find(d => d.id === si.siegeId); if (!def) return;
        const key = si.siegeId;
        if (!siegeSeen[key]) siegeSeen[key] = { def, count: 0, firstIdx: idx };
        siegeSeen[key].count += si.quantity || 1;
      });
      Object.keys(siegeSeen).forEach(key => {
        const { def, count, firstIdx } = siegeSeen[key];
        const btn = document.createElement('button'); btn.className = 'am-item';
        btn.textContent = t('shop.' + def.id) + (count > 1 ? ' x' + count : '');
        btn.onclick = () => ActionManager.actSiege(firstIdx);
        m.insertBefore(btn, btnDash);
      });
    }
    btnDash.style.display = 'none';
    const btnCancel = document.getElementById('btn-cancel');
    btnCancel.textContent = t('battle.cancel'); btnCancel.style.display = '';
    btnCancel.onclick = () => ActionManager.hideItemMenu();
    m.classList.add('show');
  },

  hideAllMenuButtons() {
    ['btn-move', 'btn-attack', 'btn-skill', 'btn-item', 'btn-dash', 'btn-cancel'].forEach(id => {
      document.getElementById(id).style.display = 'none';
    });
    document.getElementById('action-menu').querySelectorAll('.am-healer-atk').forEach(e => e.remove());
  },

  canUseSkill(u, sk) {
    const S = GameStore;
    if (sk.passive) return false;
    let enabled = u.res >= sk.cost && !u.ha;
    if (sk.id === 'assassin_assassinate') {
      const overlapping = isStealthed(u) && S.units.some(v =>
        v.x === u.x && v.y === u.y && v.team === 'enemy' && v.hp > 0);
      enabled = enabled && overlapping;
    }
    if (sk.id === 'assassin_ambush') { if (!isStealthed(u)) enabled = false; }
    if (sk.id.startsWith('summoner_summon_')) {
      const currentSummons = S.units.filter(s => s.isSummon && s.summonerId === u.id);
      if (currentSummons.length >= 1) enabled = false;
    }
    if (sk.id === 'archer_snipe') {
      const sMin = sk.snipeMin || 5, sMax = sk.snipeMax || 10;
      const hasTarget = S.units.some(v => v.team === 'enemy' && v.hp > 0 && mh(u.x, u.y, v.x, v.y) >= sMin && mh(u.x, u.y, v.x, v.y) <= sMax);
      if (!hasTarget) enabled = false;
    }
    if (sk.id === 'sapper_excavate') {
      const er = sk.excavateRange || 1;
      const hasRock = S.ter.some((row, y) => row.some((ti, x) => ti === 'rock' && mh(u.x, u.y, x, y) <= er && mh(u.x, u.y, x, y) > 0));
      if (!hasRock) enabled = false;
    }
    return enabled;
  },

  hideAM() { document.getElementById('action-menu').classList.remove('show'); },

  // ══════════════════════════════════════════
  //  Turn Order Panel (from ui.js)
  // ══════════════════════════════════════════
  getBuffs(u) {
    const S = GameStore;
    const buffs = [];
    const tile = S.ter[u.y] ? S.ter[u.y][u.x] : null;
    if (tile && TI[tile].buff) { const b = TI[tile].buff; buffs.push({ icon: b.icon, type: b.type, turns: 0 }); }
    getSkillBuffs(u).forEach(b => buffs.push(b));
    if (u.cls === 'assassin' && tile === 'forest') buffs.push({ icon: '\uD83C\uDF19', type: 'buff', turns: 0 });
    if (u._rootedTurns > 0) buffs.push({ icon: '\uD83D\uDD17', type: 'debuff', turns: u._rootedTurns });
    return buffs;
  },

  rTurnOrder() {
    const S = GameStore;
    const nav = document.getElementById('ally-nav');
    const alive = S.units.filter(u => u.hp > 0
      && !(u.team === 'enemy' && isStealthed(u))
      && !(u.team === 'enemy' && !S.fogVisible.has(u.x + ',' + u.y)));
    const withTicks = alive.map(u => {
      const rec = u.actionRec || 1.0;
      return { u, ticksLeft: u.actionPow >= 4.999 ? 0 : (5 - u.actionPow) / rec };
    });
    withTicks.sort((a, b) => a.ticksLeft - b.ticksLeft);
    while (nav.firstChild) nav.removeChild(nav.firstChild);
    withTicks.forEach(({ u, ticksLeft }) => {
      const isCur = S.curUnit && S.curUnit.id === u.id;
      const el = document.createElement('div');
      const isEnemy = u.team === 'enemy';
      el.className = 'an-unit' + (isEnemy ? ' enemy-nav' : '') + (isCur ? ' cur-nav' : '');
      const ap = u.actionPow || 0, rec = u.actionRec || 1.0;
      const apPct = Math.min(100, (ap / 5) * 100);
      const apDisplay = ap.toFixed(1);
      const recDisplay = rec.toFixed(1);
      const tickDisplay = ap >= 4.999 ? '\u2713' : ticksLeft.toFixed(1);
      // Build DOM safely
      const iconWrap = document.createElement('div'); iconWrap.className = 'an-icon';
      iconWrap.insertAdjacentHTML('afterbegin', clsIcon(u.cls, 18));
      const apbar = document.createElement('div'); apbar.className = 'an-apbar';
      const apbarFill = document.createElement('div'); apbarFill.style.height = apPct + '%'; apbar.appendChild(apbarFill);
      const info = document.createElement('div'); info.className = 'an-info';
      const apText = document.createElement('div'); apText.className = 'an-ap-text'; apText.textContent = apDisplay + '/5';
      const recText = document.createElement('div'); recText.className = 'an-rec-text'; recText.textContent = recDisplay + 'x';
      const tickText = document.createElement('div'); tickText.className = 'an-tick-text'; tickText.textContent = tickDisplay;
      info.appendChild(apText); info.appendChild(recText); info.appendChild(tickText);
      el.appendChild(iconWrap); el.appendChild(apbar); el.appendChild(info);
      if (u.team === 'ally') el.onclick = () => {
        if (!FSM.isPlayerTurn()) return;
        if (!S.curUnit || u.id === S.curUnit.id) ActionManager.selU(u);
      };
      nav.appendChild(el);
    });
    this.rInfoPanel();
  },

  // ══════════════════════════════════════════
  //  Minimap (from ui.js)
  // ══════════════════════════════════════════
  rMM() {
    const S = GameStore;
    const d = Grid.vDim();
    const wW = (d.c + d.r) * TW + 4;
    const wH = (d.c + d.r) * TH + 80;
    const mmMaxW = 80;
    const sc = mmMaxW / wW;
    const mW = Math.ceil(wW * sc);
    const mH = Math.ceil(wH * sc);
    const cv = document.getElementById('mm-cv');
    cv.width = mW; cv.height = mH;
    const mm = document.getElementById('minimap');
    mm.style.width = mW + 'px'; mm.style.height = mH + 'px';
    const ctx = cv.getContext('2d');
    ctx.clearRect(0, 0, mW, mH);
    for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
      const v = Grid.g2v(c, r);
      const ix = Grid.isoX(v.vc, v.vr);
      const iy = Grid.isoY(v.vc, v.vr, 0);
      const sx = ix * sc, sy = iy * sc;
      const tw = TW * sc, th = TH * sc;
      ctx.fillStyle = TI[S.ter[r][c]].tc;
      ctx.beginPath();
      ctx.moveTo(sx + tw, sy); ctx.lineTo(sx + tw * 2, sy + th);
      ctx.lineTo(sx + tw, sy + th * 2); ctx.lineTo(sx, sy + th);
      ctx.closePath(); ctx.fill();
      ctx.strokeStyle = 'rgba(255,255,255,.08)'; ctx.lineWidth = 0.3; ctx.stroke();
    }
    S.units.filter(u => u.hp > 0
      && !(u.team === 'enemy' && isStealthed(u))
      && !(u.team === 'enemy' && !S.fogVisible.has(u.x + ',' + u.y))).forEach(u => {
      const v = Grid.g2v(u.x, u.y);
      const ix = Grid.isoX(v.vc, v.vr) + TW;
      const iy = Grid.isoY(v.vc, v.vr, 0) + TH;
      const sx = ix * sc, sy = iy * sc;
      ctx.fillStyle = u.team === 'ally' ? '#3b82f6' : '#ef4444';
      ctx.beginPath(); ctx.arc(sx, sy, Math.max(2, TW * sc * 0.35), 0, Math.PI * 2); ctx.fill();
    });
    this._mmSc = sc;
    this.rMMvp();
  },

  rMMvp() {
    const ct = document.getElementById('map-container');
    const w = document.getElementById('iso-world');
    const wW = parseFloat(w.style.width), wH = parseFloat(w.style.height);
    if (!wW || !wH || !this._mmSc) return;
    const sc = this._mmSc;
    const vp = document.getElementById('mm-vp');
    const oL = parseFloat(w.style.left || 0), oT = parseFloat(w.style.top || 0);
    const vx = ct.scrollLeft - oL, vy = ct.scrollTop - oT;
    vp.style.left = Math.max(0, vx * sc) + 'px';
    vp.style.top = Math.max(0, vy * sc) + 'px';
    vp.style.width = Math.min(ct.clientWidth * sc, wW * sc) + 'px';
    vp.style.height = Math.min(ct.clientHeight * sc, wH * sc) + 'px';
  },

  mmClick(e) {
    const cv = document.getElementById('mm-cv');
    const rect = cv.getBoundingClientRect();
    if (!this._mmSc) return;
    const sc = this._mmSc;
    const wx = (e.clientX - rect.left) / sc;
    const wy = (e.clientY - rect.top) / sc;
    const ct = document.getElementById('map-container');
    const w = document.getElementById('iso-world');
    const oL = parseFloat(w.style.left || 0), oT = parseFloat(w.style.top || 0);
    ct.scrollLeft = oL + wx - ct.clientWidth / 2;
    ct.scrollTop = oT + wy - ct.clientHeight / 2;
  },

  // ══════════════════════════════════════════
  //  Info Panel & Status (from ui.js)
  // ══════════════════════════════════════════
  uUI() {
    const S = GameStore;
    const ti = document.getElementById('turn-indicator');
    const phase = S.curUnit ? (S.curUnit.team === 'ally' ? 'player' : 'enemy') : 'player';
    ti.textContent = phase === 'player' ? 'PLAYER' : 'ENEMY'; ti.className = phase;
    const s = S.cStage, en = UnitManager.alive('enemy').length;
    const br = s ? S.breached : 0, blim = s ? Math.ceil(s.tot / 4) : 0;
    const infoEl = document.getElementById('stage-info');
    infoEl.textContent = '';
    const stageText = document.createTextNode('STAGE ' + (s ? s.id : 1) + ' ');
    infoEl.appendChild(stageText);
    const nameSpan = document.createElement('span');
    nameSpan.style.cssText = 'color:var(--dim);font-size:9px';
    nameSpan.textContent = s ? t('stages.stage_' + s.id + '_name') : '';
    infoEl.appendChild(nameSpan);
    const turnDiv = document.createElement('div');
    turnDiv.className = 'si-turn';
    const brSpan = document.createElement('span');
    brSpan.style.color = br > 0 ? '#ef4444' : 'var(--dim)';
    brSpan.textContent = t('battle.breach') + ' ' + br + '/' + blim;
    turnDiv.appendChild(document.createTextNode(t('battle.summon') + ' ' + S.eSpwn + '/' + (s ? s.tot : '?') + ' \u00B7 ' + t('battle.remaining') + ' ' + en + '\uCCB4 \u00B7 '));
    turnDiv.appendChild(brSpan);
    infoEl.appendChild(turnDiv);
  },

  showUI() { this.rInfoPanel(); },
  defI() { this.rInfoPanel(); },

  rInfoPanel() {
    const S = GameStore;
    const p = document.getElementById('info-panel');
    const allies = S.units.filter(u => u.hp > 0 && u.team === 'ally');
    const selId = S.sel ? S.sel.id : (S.curUnit ? S.curUnit.id : null);
    while (p.firstChild) p.removeChild(p.firstChild);
    allies.forEach(u => {
      const isSel = u.id === selId;
      const hpPct = Math.round(u.hp / u.mhp * 100);
      const rn = RES_LABEL[u.resType] || '';
      const resPct = u.maxRes ? Math.round(u.res / u.maxRes * 100) : 0;
      const buffs = this.getBuffs(u);

      const card = document.createElement('div');
      card.className = 'info-card ally-card' + (isSel ? ' ip-sel' : '');
      card.dataset.uid = u.id;

      // Top row
      const top = document.createElement('div'); top.className = 'ic-top';
      const iconSpan = document.createElement('span'); iconSpan.className = 'ic-icon';
      iconSpan.insertAdjacentHTML('afterbegin', clsIcon(u.cls, 14));
      const nameSpan = document.createElement('span'); nameSpan.className = 'ic-name'; nameSpan.textContent = u.name;
      const clsSpan = document.createElement('span'); clsSpan.className = 'ic-class'; clsSpan.textContent = t('classes.' + u.cls);
      top.appendChild(iconSpan); top.appendChild(nameSpan); top.appendChild(clsSpan);
      card.appendChild(top);

      // HP bar
      const hpRow = document.createElement('div'); hpRow.className = 'ic-bar-row';
      const hpLabel = document.createElement('span'); hpLabel.className = 'ic-blabel'; hpLabel.textContent = 'HP';
      const hpBar = document.createElement('div'); hpBar.className = 'ic-bar';
      const hpFill = document.createElement('div'); hpFill.className = 'ic-bfill' + (hpPct <= 25 ? ' low' : ''); hpFill.style.width = hpPct + '%';
      hpBar.appendChild(hpFill);
      const hpVal = document.createElement('span'); hpVal.className = 'ic-bval'; hpVal.textContent = u.hp + '/' + u.mhp;
      hpRow.appendChild(hpLabel); hpRow.appendChild(hpBar); hpRow.appendChild(hpVal);
      card.appendChild(hpRow);

      // Resource bar
      if (rn) {
        const resRow = document.createElement('div'); resRow.className = 'ic-bar-row';
        const resLabel = document.createElement('span'); resLabel.className = 'ic-blabel'; resLabel.style.color = RES_COLOR[u.resType]; resLabel.textContent = rn;
        const resBar = document.createElement('div'); resBar.className = 'ic-bar';
        const resFill = document.createElement('div'); resFill.className = 'ic-bfill'; resFill.style.width = resPct + '%'; resFill.style.background = RES_COLOR[u.resType];
        resBar.appendChild(resFill);
        const resVal = document.createElement('span'); resVal.className = 'ic-bval'; resVal.textContent = u.res + '/' + u.maxRes;
        resRow.appendChild(resLabel); resRow.appendChild(resBar); resRow.appendChild(resVal);
        card.appendChild(resRow);
      }

      // Stats
      const stats = document.createElement('div'); stats.className = 'ic-stats';
      ['ATK', 'DEF', 'RNG'].forEach((label, i) => {
        const span = document.createElement('span');
        const val = i === 0 ? u.atk : i === 1 ? u.def : u.range;
        span.textContent = label + ' ';
        const b = document.createElement('b'); b.textContent = val; span.appendChild(b);
        stats.appendChild(span);
      });
      card.appendChild(stats);

      // Buffs
      if (buffs.length) {
        const buffDiv = document.createElement('div'); buffDiv.className = 'ic-buffs';
        buffs.forEach(b => {
          const span = document.createElement('span'); span.className = 'buff-icon'; span.textContent = b.icon;
          buffDiv.appendChild(span);
        });
        card.appendChild(buffDiv);
      }

      p.appendChild(card);
    });
    if (selId) { const el = p.querySelector('[data-uid="' + selId + '"]'); if (el) el.scrollIntoView({ inline: 'center', block: 'nearest', behavior: 'smooth' }); }
  },

  // ── Enemy popup ──
  showEnemyPopup(u) {
    this.hideEnemyPopup();
    const hpPct = Math.round(u.hp / u.mhp * 100);
    const rn = RES_LABEL[u.resType] || '';
    const resPct = u.maxRes ? Math.round(u.res / u.maxRes * 100) : 0;
    const buffs = this.getBuffs(u);

    const pop = document.createElement('div');
    pop.id = 'enemy-popup';

    // Head
    const head = document.createElement('div'); head.className = 'ep-head';
    const epIcon = document.createElement('span'); epIcon.className = 'ep-icon';
    epIcon.insertAdjacentHTML('afterbegin', clsIcon(u.cls, 16));
    const epName = document.createElement('span'); epName.className = 'ep-name'; epName.textContent = u.name;
    const epCls = document.createElement('span'); epCls.className = 'ep-cls'; epCls.textContent = t('classes.' + u.cls);
    head.appendChild(epIcon); head.appendChild(epName); head.appendChild(epCls);
    pop.appendChild(head);

    // HP bar
    const hpBar = document.createElement('div'); hpBar.className = 'ep-bar';
    const hpLbl = document.createElement('span'); hpLbl.className = 'ep-blbl'; hpLbl.textContent = 'HP';
    const hpTrack = document.createElement('div'); hpTrack.className = 'ep-btrack';
    const hpFill = document.createElement('div'); hpFill.className = 'ep-bfill' + (hpPct <= 25 ? ' low' : ''); hpFill.style.width = hpPct + '%';
    hpTrack.appendChild(hpFill);
    const hpVal = document.createElement('span'); hpVal.className = 'ep-bval'; hpVal.textContent = u.hp + '/' + u.mhp;
    hpBar.appendChild(hpLbl); hpBar.appendChild(hpTrack); hpBar.appendChild(hpVal);
    pop.appendChild(hpBar);

    // Resource bar
    if (rn) {
      const resBar = document.createElement('div'); resBar.className = 'ep-bar';
      const resLbl = document.createElement('span'); resLbl.className = 'ep-blbl'; resLbl.style.color = RES_COLOR[u.resType]; resLbl.textContent = rn;
      const resTrack = document.createElement('div'); resTrack.className = 'ep-btrack';
      const resFill = document.createElement('div'); resFill.className = 'ep-bfill'; resFill.style.width = resPct + '%'; resFill.style.background = RES_COLOR[u.resType];
      resTrack.appendChild(resFill);
      const resVal = document.createElement('span'); resVal.className = 'ep-bval'; resVal.textContent = u.res + '/' + u.maxRes;
      resBar.appendChild(resLbl); resBar.appendChild(resTrack); resBar.appendChild(resVal);
      pop.appendChild(resBar);
    }

    // Stats
    const epStats = document.createElement('div'); epStats.className = 'ep-stats';
    [['ATK', u.atk], ['DEF', u.def], ['RNG', u.range]].forEach(([label, val]) => {
      const span = document.createElement('span');
      span.textContent = label + ' ';
      const b = document.createElement('b'); b.textContent = val; span.appendChild(b);
      epStats.appendChild(span);
    });
    pop.appendChild(epStats);

    // Buffs
    if (buffs.length) {
      const buffDiv = document.createElement('div'); buffDiv.className = 'ep-buffs';
      buffs.forEach(b => {
        const span = document.createElement('span'); span.className = 'buff-icon'; span.textContent = b.icon;
        buffDiv.appendChild(span);
      });
      pop.appendChild(buffDiv);
    }

    document.getElementById('iso-world').appendChild(pop);
    const sx = Grid.uSX(u.x, u.y) + UCX;
    const sy = Grid.uSY(u.x, u.y) - 10;
    pop.style.left = sx + 'px'; pop.style.top = sy + 'px';
    requestAnimationFrame(() => {
      const rect = pop.getBoundingClientRect();
      if (rect.top < 0) pop.classList.add('below');
      pop.classList.add('show');
    });
    this._epClose = e => { e.stopPropagation(); this.hideEnemyPopup(); };
    document.addEventListener('pointerdown', this._epClose, { capture: true, once: true });
  },

  hideEnemyPopup() {
    const old = document.getElementById('enemy-popup');
    if (old) old.remove();
    if (this._epClose) { document.removeEventListener('pointerdown', this._epClose, { capture: true }); this._epClose = null; }
  },

  // ══════════════════════════════════════════
  //  Wave Banner (from ui.js)
  // ══════════════════════════════════════════
  showWv(txt) { const b = document.getElementById('wave-banner'); b.textContent = txt; b.classList.add('show'); },
  hideWv() { document.getElementById('wave-banner').classList.remove('show'); },

  // ══════════════════════════════════════════
  //  Result Modal (from ui.js)
  // ══════════════════════════════════════════
  showRes(win, msg) {
    const S = GameStore;
    const ov = document.getElementById('modal-overlay');
    BattleEnd.onBattleEnd(win);
    const baseReward = S._baseReward || 0;
    const bonusReward = S._bonusReward || 0;
    const actualReward = baseReward + bonusReward;
    const titleEl = document.getElementById('modal-title');
    titleEl.textContent = win ? t('messages.victory') : t('messages.defeat');
    titleEl.className = win ? 'win' : 'lose';
    const deadAllyCount = S._deadAllyUids.length;
    const autoRevived = S._autoRevivedCount || 0;

    const lines = [];
    if (S.practiceMode) {
      lines.push('\uD83C\uDF93 ' + t('stage.practice_mode_active'));
      lines.push(t('stage.reduced_gold') + ' (70%)');
      lines.push('\uD83D\uDCCA ' + t('stage.full_exp') + ' (100%)');
      if (autoRevived > 0) lines.push('\u2764 ' + t('stage.auto_revived', { count: autoRevived }));
      lines.push('\u26A0\uFE0F ' + t('stage.no_clear_recorded'));
      lines.push('');
    }
    lines.push(msg);
    if (win && actualReward) lines.push(t('messages.reward') + ': ' + actualReward + ' Gold');
    if (win && S._firstClearBonus) { lines.push('\uD83C\uDF89 ' + t('messages.first_clear_bonus') + ': +' + S._firstClearBonus + ' Gold'); S._firstClearBonus = 0; }
    if (win && S._firstClearUnit) { lines.push('\uD83C\uDF81 ' + t('messages.first_clear_unit', { cls: t('classes.' + S._firstClearUnit.cls) })); S._firstClearUnit = null; }
    if (win && S._droppedBook) { lines.push('\uD83D\uDCD5 ' + t('academy.skillbook_drop', { skill: t('skills.' + S._droppedBook) })); S._droppedBook = null; }
    if (deadAllyCount) lines.push('\uD83D\uDC80 \uC804\uC0AC\uC790: ' + deadAllyCount + '\uBA85 (\uC131\uC18C\uC5D0\uC11C \uBD80\uD65C \uAC00\uB2A5)');
    if (S._expResults && S._expResults.length) {
      lines.push('');
      lines.push(t('results.battle_detail', { kills: S._deadEnemyCount || 0, exp: S._totalExp || 0, survivors: S._expResults.length }));
      S._expResults.forEach(r => {
        const ch = getChar(r.uid); if (!ch) return;
        const charName = ch.customName || t('character.names')[ch.nameId] || JAB[ch.cls].icon;
        let line = charName + ': +' + r.exp + ' EXP';
        if (r.leveled > 0) line += ' Lv.' + r.prevLv + '\u2192' + ch.lv;
        lines.push(line);
      });
    }

    const subEl = document.getElementById('modal-sub');
    subEl.textContent = '';
    lines.forEach((line, i) => {
      if (i > 0) subEl.appendChild(document.createElement('br'));
      subEl.appendChild(document.createTextNode(line));
    });

    const bt = document.getElementById('modal-buttons');
    while (bt.firstChild) bt.removeChild(bt.firstChild);
    const lb = document.createElement('button'); lb.className = 'modal-btn'; lb.textContent = t('results.return_to_lobby');
    lb.onclick = () => { ov.classList.remove('show'); BattleEnd.returnToLobby(); }; bt.appendChild(lb);
    if (win) {
      const s = S.cStage, ns = s && STAGES.find(v => v.id === s.id + 1);
      if (ns) {
        const b = document.createElement('button'); b.className = 'modal-btn secondary'; b.textContent = t('results.next_stage');
        b.onclick = () => { ov.classList.remove('show'); BattleEnd.goNextStage(ns); }; bt.appendChild(b);
      }
    }
    ov.classList.add('show');
  },

  // ══════════════════════════════════════════
  //  Settings (from ui.js)
  // ══════════════════════════════════════════
  loadSett() {
    try {
      const d = JSON.parse(localStorage.getItem('game_setting'));
      if (d) {
        if (typeof d.bgmVol === 'number') GameStore._sett.bgmVol = d.bgmVol;
        if (typeof d.sfxVol === 'number') GameStore._sett.sfxVol = d.sfxVol;
        if (typeof d.bgmOn === 'boolean') GameStore._sett.bgmOn = d.bgmOn;
        if (typeof d.sfxOn === 'boolean') GameStore._sett.sfxOn = d.sfxOn;
        if (typeof d.speed === 'number') GameStore._sett.speed = d.speed;
        if (typeof d.language === 'string') GameStore._sett.language = d.language;
      }
    } catch (e) {}
  },
  saveSett() { try { localStorage.setItem('game_setting', JSON.stringify(GameStore._sett)); } catch (e) {} },

  toggleSettings() {
    const p = document.getElementById('settings-panel'); if (!p) return;
    const b = document.getElementById('settings-backdrop');
    const opening = !p.classList.contains('show');
    p.classList.toggle('show'); b.classList.toggle('show');
    if (opening) this.syncSettingsUI();
  },
  closeSettings() {
    const p = document.getElementById('settings-panel'); if (p) p.classList.remove('show');
    const b = document.getElementById('settings-backdrop'); if (b) b.classList.remove('show');
  },
  syncSettingsUI() {
    const s = GameStore._sett;
    document.getElementById('sp-bgm-on').checked = s.bgmOn;
    document.getElementById('sp-bgm').value = Math.round(s.bgmVol * 100);
    document.getElementById('sp-bgm-val').textContent = Math.round(s.bgmVol * 100);
    document.getElementById('sp-sfx-on').checked = s.sfxOn;
    document.getElementById('sp-sfx').value = Math.round(s.sfxVol * 100);
    document.getElementById('sp-sfx-val').textContent = Math.round(s.sfxVol * 100);
    document.getElementById('sp-speed').value = Math.round(1 / s.speed * 100);
    document.getElementById('sp-speed-val').textContent = s.speed.toFixed(1) + 'x';
  },
  setSpeed(v) {
    const spd = v > 0 ? 100 / v : 1;
    GameStore._sett.speed = spd;
    document.getElementById('sp-speed-val').textContent = spd.toFixed(1) + 'x';
    this.saveSett();
  },

  surrender() {
    if (FSM.is(BattleState.BATTLE_END)) return;
    this.closeSettings();
    FSM.transition(BattleState.BATTLE_END);
    EventBus.emit('battle_end', { win: false, message: t('messages.surrender') });
  },

  // ══════════════════════════════════════════
  //  Scroll Helper
  // ══════════════════════════════════════════
  scrollToUnit(u) {
    const ct = document.getElementById('map-container');
    const w = document.getElementById('iso-world');
    const oL = parseFloat(w.style.left || 0), oT = parseFloat(w.style.top || 0);
    const ux = Grid.uSX(u.x, u.y) + UCX, uy = Grid.uSY(u.x, u.y);
    ct.scrollLeft = oL + ux - ct.clientWidth / 2;
    ct.scrollTop = oT + uy - ct.clientHeight / 2;
  },

  scrollToAllies() {
    const al = UnitManager.alive('ally'); if (!al.length) return;
    let sx = 0, sy = 0;
    al.forEach(u => { sx += Grid.uSX(u.x, u.y); sy += Grid.uSY(u.x, u.y); });
    sx /= al.length; sy /= al.length;
    const ct = document.getElementById('map-container');
    const w = document.getElementById('iso-world');
    const oL = parseFloat(w.style.left || 0), oT = parseFloat(w.style.top || 0);
    ct.scrollLeft = oL + sx - ct.clientWidth / 2 + UCX;
    ct.scrollTop = oT + sy - ct.clientHeight / 2 + UCX;
  },

  rotCam(d) {
    const S = GameStore;
    S.camDir = ((S.camDir + d) % 4 + 4) % 4;
    document.querySelector('#cam-dir .cd-arrow').textContent = CARR[S.camDir];
    document.querySelector('#cam-dir .cd-label').textContent = CLAB[S.camDir];
    document.querySelectorAll('.unit-sprite').forEach(el => el.style.transition = 'none');
    this._bgReady = false; Grid.layWorld(); this.rTerBg(); this.rTer(); this.rUnits();
    S.units.forEach(u => { if (u._gdx || u._gdy) VFX._applyFace(u.id); });
    this.rMM();
    requestAnimationFrame(() => requestAnimationFrame(() => {
      document.querySelectorAll('.unit-sprite').forEach(el => el.style.transition = '');
    }));
    if (FSM.isPlayerTurn() && S.sel) this.showAM(S.sel);
  },
};
