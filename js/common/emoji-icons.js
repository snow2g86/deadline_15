// ═══════════════════════════════════════════
//  common/emoji-icons.js — 화면의 이모지를 일러스트 아이콘으로 자동 교체
//  EMOJI_ICON(이모지 → 아이콘 키)은 tools/icon-catalog.py 가 갱신. 그림이 시트(ITEM_SPRITE)에 있는 이모지만 바꾸고,
//  없는 것은 이모지 그대로 둔다 → image/icon/src 에 그림을 넣고 tools/import-icons.py 만 돌리면 화면 전체에 적용됨.
//  글자 크기에 맞춰(1.2em) 그려지므로 버튼·떠오르는 글자·카드 어디서나 같은 방식으로 동작
// ═══════════════════════════════════════════
var EMOJI_ICON = {'🔪':'wpn_assassin','🪄':'wpn_mage','🏹':'wpn_archer','🪬':'wpn_shaman','👊':'wpn_brawler','🔱':'wpn_lancer','🔨':'wpn_sapper','🛡️':'shield','🛡':'shield','📖':'tome','⛑️':'plate_helm','🪖':'chain_helm','👒':'leather_cap','🧢':'cloth_hood','⛓️':'chain_armor','🥋':'chain_armor','🧥':'leather_armor','🧵':'leather_armor','👘':'cloth_robe','👗':'cloth_robe','👢':'plate_boots','🥾':'leather_boots','👟':'cloth_shoes','💎':'necklace_power','📿':'necklace_power','🔗':'necklace_guard','⭐':'earring_guard','💍':'ring_power','🔷':'ring_guard','🔹':'ring_swift','💊':'potion_heal','⚗️':'exp_m','🏺':'exp_l','🪜':'siege_ladder','💣':'siege_bomb','🌉':'siege_bridge','🔩':'mat_stone','💠':'soul_stone','📜':'class_scroll','📕':'skillbook','🎁':'chest','🪙':'gold','💰':'gold','🧊':'rune_frost','🐍':'rune_venom','🩸':'rune_vamp','⚡':'e_lightning','⚔️':'e_swords','⚔':'e_swords','✨':'e_sparkle','🔥':'e_fire','🎯':'e_target','🗡️':'e_dagger','☠️':'e_poison','💀':'e_skull','❄️':'e_frost','💢':'e_rage','✝️':'e_holy','💥':'e_explosion','🔮':'e_crystal_ball','🏰':'e_fortress','🌟':'e_star_burst','⚙️':'e_gear','⚠':'e_trap','🧪':'e_flask','🤛':'e_disarm','🔁':'e_repeat','🌿':'e_root','🔺':'e_exalt','💪':'e_tenacity','🧱':'e_wall','⬆️':'e_empower','🎖️':'e_commander','💧':'e_water','💫':'e_soul_burst','🌊':'e_wave','🕊️':'e_dove','👁':'e_eye','👁️':'e_eye','🌪️':'e_tornado','🔄':'e_switch','🪨':'e_rock','🗿':'e_golem','🐎':'e_charge','🌫️':'e_smoke','🔧':'e_repair','💚':'e_regen','🤝':'e_support','💔':'e_painshare','🩹':'e_bandage','✊':'e_grit','⛏️':'e_pickaxe','☁️':'e_poison_cloud','🧨':'e_dynamite','🪝':'e_capture','🌀':'e_cleave','🦅':'e_assault','🏃':'e_tackle','🌧️':'e_steelrain','👻':'e_spirit','🌙':'e_stealth','⏳':'e_hourglass','💨':'e_dash','👣':'e_footsteps','🎒':'e_backpack','🔓':'e_unlock','🫸':'e_shove','🌲':'e_forest','⛰️':'e_hill','☀️':'e_sun_heat','☄️':'e_meteor','🦟':'e_mosquito','🕯️':'e_candle','🌌':'e_galaxy','🌑':'e_new_moon','🥊':'e_boxing','🌱':'e_sprout','⚖️':'e_balance','🌈':'e_rainbow','🎭':'e_mask','🔰':'e_beginner','🎓':'e_graduate','👹':'e_boss','🛣️':'e_detour','🛤️':'e_detour','🛒':'e_shop','📦':'e_box','👤':'e_person','👥':'e_party','📈':'e_level_up','🎉':'e_celebrate','🏆':'e_trophy','🏅':'e_medal','🥇':'e_medal','🥈':'e_medal_silver','🥉':'e_medal_bronze','❤️':'e_heart','💜':'e_mana','📚':'e_books','📊':'e_chart','📋':'e_clipboard','📍':'e_pin','💡':'e_idea','🤖':'e_ai','🧠':'e_ai','🗺️':'e_map','🗺':'e_map','🎴':'e_cards','💼':'e_briefcase','🎮':'e_game','🚧':'e_barrier','🏫':'e_academy','⚒️':'e_forge','⛪':'e_sanctuary','⏰':'e_alarm','🔀':'e_shuffle','✏️':'e_pencil','🗣️':'e_shout'};

var EmojiIcons = {
  _re: null,
  // 아이콘 HTML (em 단위 — 주변 글자 크기를 따라감)
  html: function(key) {
    var p = ITEM_SPRITE[key];
    var bx = ITEM_SPRITE_COLS > 1 ? p[0] / (ITEM_SPRITE_COLS - 1) * 100 : 0, by = ITEM_SPRITE_ROWS > 1 ? p[1] / (ITEM_SPRITE_ROWS - 1) * 100 : 0;
    return '<span class="emo-icon" style="background-position:' + bx + '% ' + by + '%;background-size:' + (ITEM_SPRITE_COLS * 100) + '% ' + (ITEM_SPRITE_ROWS * 100) + '%"></span>';
  },
  _regex: function() {
    if (this._re !== null) return this._re;
    var keys = Object.keys(EMOJI_ICON).filter(function(e) { return typeof ITEM_SPRITE !== 'undefined' && ITEM_SPRITE[EMOJI_ICON[e]]; });
    keys.sort(function(a, b) { return b.length - a.length; });   // 변형 선택자(FE0F) 붙은 것부터
    this._re = keys.length ? new RegExp(keys.map(function(k) { return k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }).join('|'), 'g') : false;
    return this._re;
  },
  _skip: { SCRIPT: 1, STYLE: 1, TEXTAREA: 1, INPUT: 1, OPTION: 1, TITLE: 1, CANVAS: 1 },
  // 텍스트 노드 안의 이모지를 아이콘으로
  _text: function(node) {
    var re = this._regex(); if (!re) return;
    var s = node.nodeValue; if (!s) return;
    re.lastIndex = 0; if (!re.test(s)) return;
    var par = node.parentNode; if (!par || this._skip[par.nodeName] || par.isContentEditable) return;
    re.lastIndex = 0;
    var frag = document.createDocumentFragment(), last = 0, m, self = this;
    while ((m = re.exec(s))) {
      if (m.index > last) frag.appendChild(document.createTextNode(s.slice(last, m.index)));
      var key = EMOJI_ICON[m[0]] || EMOJI_ICON[m[0].replace('️', '')] || EMOJI_ICON[m[0] + '️'];
      var span = document.createElement('span');
      span.className = 'emo-icon'; span.setAttribute('aria-label', m[0]); span.title = '';
      var tmp = document.createElement('span'); tmp.innerHTML = self.html(key);
      span.setAttribute('style', tmp.firstChild.getAttribute('style'));
      frag.appendChild(span);
      last = m.index + m[0].length;
    }
    if (last < s.length) frag.appendChild(document.createTextNode(s.slice(last)));
    par.replaceChild(frag, node);
  },
  scan: function(root) {
    if (!root) return;
    if (root.nodeType === 3) { this._text(root); return; }
    if (root.nodeType !== 1 || this._skip[root.nodeName]) return;
    var w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null), list = [], n;
    while ((n = w.nextNode())) list.push(n);
    for (var i = 0; i < list.length; i++) this._text(list[i]);
  },
  start: function() {
    if (typeof ITEM_SPRITE === 'undefined' || !this._regex() || !document.body) return;
    var self = this, pending = [], queued = false;
    var flush = function() { queued = false; var p = pending; pending = []; for (var i = 0; i < p.length; i++) if (p[i].isConnected) self.scan(p[i]); };
    new MutationObserver(function(muts) {
      for (var i = 0; i < muts.length; i++) {
        var m = muts[i];
        if (m.type === 'characterData') pending.push(m.target);
        else for (var j = 0; j < m.addedNodes.length; j++) pending.push(m.addedNodes[j]);
      }
      if (!queued && pending.length) { queued = true; (window.requestAnimationFrame || setTimeout)(flush); }
    }).observe(document.body, { childList: true, subtree: true, characterData: true });
    this.scan(document.body);
  }
};
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', function() { EmojiIcons.start(); });
else EmojiIcons.start();

// ── 종류별 개별 아이콘 (같은 이모지를 여러 종류가 쓰는 장비·룬·물약) ──
// 그림이 없으면 기존 이모지 (그 이모지도 EMOJI_ICON에 있으면 위 자동 교체가 처리)
function iconOr(key, size, fallback) { return typeof itemIcon === 'function' && ITEM_SPRITE[key] ? itemIcon(key, size, fallback) : (fallback || ''); }
function equipIcon(it, size) {
  if (!it) return '';
  var emo = typeof getEquipEmoji === 'function' ? getEquipEmoji(it.templateId) : '📦';
  if (it.legend && ITEM_SPRITE['legend_' + it.legend]) return itemIcon('legend_' + it.legend, size);
  return iconOr(it.templateId, size, emo);
}
function runeIcon(k, size) { return iconOr('rune_' + k, size, typeof ENCHANTS !== 'undefined' && ENCHANTS[k] ? ENCHANTS[k].icon : ''); }
