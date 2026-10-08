// js/common/story.js — 스토리 대사 연출 엔진
// 대본 형식: docs/story-schema.md (window.STORY_KO 등)
// 사용 예:
//   await Story.play(lines, { stage })          → 무조건 재생
//   await Story.scene('s1_pre', lines, { stage }) → 본 적 있으면 즉시 끝남, 끝까지 보거나 건너뛰면 기록
//   await Story.beforeStage(stage) / Story.afterStage(stage)
//   Story.openReplay()                           → 본 장면 다시 보기 목록
// 대본 파일이 아직 없거나 일부만 있어도 동작한다 (없는 장면은 건너뜀).
(function() {
  'use strict';

  var SEEN_KEY = 'game_story_seen';
  // 대본 파일(data/story/story.<lang>.js)이 실제로 있는 언어. en/es 파일이 생기면 여기에 추가 (없는 파일 요청으로 404가 나지 않게)
  var STORY_LANGS = ['ko'];
  var TYPE_MS = 28; // 한 글자 출력 간격(ms)
  var BATTLE_KINDS = ['start', 'wave', 'boss', 'danger', 'last'];

  // ── 유틸 ────────────────────────────────
  function tr(key, fallback, params) {
    if (typeof window.t !== 'function') return fallback;
    var v = window.t(key, params);
    return (v === key || v == null) ? fallback : v;
  }

  function curLang() {
    var lang = null;
    try { lang = localStorage.getItem('game_i18n_lang'); } catch (_) {}
    if (!lang) {
      try { var s = JSON.parse(localStorage.getItem('game_settings')); if (s && s.language) lang = s.language; } catch (_) {}
    }
    return lang || 'ko';
  }

  function loadScript(src) {
    return new Promise(function(resolve) {
      var s = document.createElement('script');
      s.src = src;
      s.onload = function() { resolve(true); };
      s.onerror = function() { resolve(false); };
      document.head.appendChild(s);
    });
  }

  function readJSON(key) {
    try { return JSON.parse(localStorage.getItem(key)); } catch (_) { return null; }
  }

  // 스테이지 → 에피소드 번호 / 에피소드 안 순번
  function epOf(stageId) {
    if (typeof EPISODES !== 'undefined') {
      var ep = EPISODES.find(function(e) { return e.stages.indexOf(stageId) !== -1; });
      if (ep) return ep.id;
    }
    return Math.floor((stageId - 1) / 10) + 1;
  }
  function epStages(epId) {
    if (typeof EPISODES !== 'undefined') {
      var ep = EPISODES.find(function(e) { return e.id === epId; });
      if (ep) return ep.stages;
    }
    var a = []; for (var i = 1; i <= 10; i++) a.push((epId - 1) * 10 + i);
    return a;
  }
  function findStage(stageId) {
    return (typeof STAGES !== 'undefined') ? STAGES.find(function(s) { return s.id === stageId; }) : null;
  }
  function stageLabel(stageId) {
    var ep = epOf(stageId), idx = epStages(ep).indexOf(stageId) + 1;
    var name = tr('stages.stage_' + stageId + '_name', '');
    return 'EP.' + ep + '-' + (idx || stageId) + (name ? ' ' + name : '');
  }

  // ── 지휘관 (로스터에서 cls==='commander') ──
  function commanderChar() {
    var r = readJSON('game_roster');
    if (!r || !Array.isArray(r.chars)) return null;
    return r.chars.find(function(c) { return c && c.cls === 'commander'; }) || null;
  }

  var Story = {
    _loadP: null,
    _active: null, // 재생 중인 장면 상태

    // ── 데이터 로드 ──────────────────────
    load: function() {
      if (this._loadP) return this._loadP;
      var self = this;
      this._loadP = (async function() {
        var dev = null;
        try { dev = localStorage.getItem('game_story_dev'); } catch (_) {}
        if (dev === 'sample') {
          // 개발용: localStorage.game_story_dev = 'sample' 이면 샘플 대본 사용
          if (!window.STORY_KO) await loadScript('data/story/story.sample.js');
        } else {
          var lang = curLang();
          if (!window.STORY_KO) await loadScript('data/story/story.ko.js');
          var LK = 'STORY_' + lang.toUpperCase();
          if (lang !== 'ko' && STORY_LANGS.indexOf(lang) !== -1 && !window[LK]) await loadScript('data/story/story.' + lang + '.js');
        }
        return self.data();
      })();
      return this._loadP;
    },

    // 현재 언어 대본 → 없으면 한국어
    data: function() {
      var d = window['STORY_' + curLang().toUpperCase()] || window.STORY_KO;
      return (d && typeof d === 'object') ? d : null;
    },

    // ── 본 장면 기록 ─────────────────────
    _seenAll: function() { return readJSON(SEEN_KEY) || {}; },
    seen: function(key) { return !!this._seenAll()[key]; },
    markSeen: function(key) {
      var s = this._seenAll(); s[key] = true;
      try { localStorage.setItem(SEEN_KEY, JSON.stringify(s)); } catch (_) {}
    },

    // ── 장면 조회 (키 → 대사 배열) ───────
    // 키: ep{n}_pro / ep{n}_epi / s{id}_pre / s{id}_post / s{id}_{start|wave|boss|danger|last}
    linesOf: function(key) {
      var d = this.data(); if (!d) return null;
      var m;
      if ((m = /^ep(\d+)_(pro|epi)$/.exec(key))) {
        var ep = d.episodes && d.episodes[m[1]];
        return ep ? ep[m[2] === 'pro' ? 'prologue' : 'epilogue'] : null;
      }
      if ((m = /^s(\d+)_(\w+)$/.exec(key))) {
        var st = d.stages && d.stages[m[1]];
        if (!st) return null;
        if (m[2] === 'pre' || m[2] === 'post') return st[m[2]];
        if (!st.battle) return null;
        // s{id}_battle: 다시 보기용 — 전투 중 대사 전부를 순서대로 이어 붙임
        if (m[2] === 'battle') {
          return BATTLE_KINDS.reduce(function(a, k) { return a.concat(Array.isArray(st.battle[k]) ? st.battle[k] : []); }, []);
        }
        return st.battle[m[2]];
      }
      return null;
    },

    // 장면 제목 (다시 보기 목록·상단 표시용)
    titleOf: function(key) {
      var d = this.data(), m;
      if ((m = /^ep(\d+)_(pro|epi)$/.exec(key))) {
        var ep = d && d.episodes && d.episodes[m[1]];
        var epName = (ep && ep.title) || tr('episode.' + m[1] + '.name', '');
        return 'EP.' + m[1] + ' ' + (m[2] === 'pro' ? tr('story.prologue', '프롤로그') : tr('story.epilogue', '에필로그')) + (epName ? ' · ' + epName : '');
      }
      if ((m = /^s(\d+)_(\w+)$/.exec(key))) {
        var part = m[2] === 'pre' ? tr('story.part_pre', '전투 전') : m[2] === 'post' ? tr('story.part_post', '승리 후') : tr('story.part_battle', '전투 중');
        return stageLabel(+m[1]) + ' · ' + part;
      }
      return '';
    },

    // ── 화자 해석 ────────────────────────
    _speaker: function(line, ctx) {
      var d = this.data() || {};
      var cast = d.cast || {};
      var who = line.who || 'narrator';
      if (who === 'boss') {
        var b = ctx.stage && ctx.stage.boss;
        return { key: 'boss', name: b ? b.name : '???', img: b ? 'image/character/' + b.cls + '_01.png' : null, side: 'right', boss: true };
      }
      var c = cast[who];
      if (who === 'narrator' || (c && !c.name && !c.portrait && who !== 'commander')) return { narr: true };
      c = c || { name: who, portrait: null };
      var sp = { key: who, name: c.name || '', img: null, side: (who === 'commander' || c.side === 'left') ? 'left' : 'right' };
      if (who === 'commander') sp.name = this.commanderName();
      if (c.portrait === 'commander' || (who === 'commander' && c.portrait !== null)) {
        var cm = this._commanderImg(); sp.img = cm.src; sp.fallback = cm.fallback;
      } else if (c.portrait === 'boss') {
        var bb = ctx.stage && ctx.stage.boss;
        if (bb) { sp.img = 'image/character/' + bb.cls + '_01.png'; sp.boss = true; }
      } else if (c.portrait) {
        sp.img = 'image/character/' + c.portrait + '.png';
      }
      return sp;
    },

    // 지휘관 이름: 로스터 지휘관(customName → name → 이름표) → 대본 기본값
    commanderName: function() {
      var ch = commanderChar();
      if (ch) {
        if (ch.customName) return ch.customName;
        if (ch.name) return ch.name;
        var names = tr('character.names', null);
        if (Array.isArray(names) && names[ch.nameId]) return names[ch.nameId];
      }
      var d = this.data();
      return (d && d.cast && d.cast.commander && d.cast.commander.name) || tr('story.commander', '지휘관');
    },

    // 지휘관 그림: commander_01(남)/02(여). 지휘관이 없거나 그림이 없으면 노비스 그림
    _commanderImg: function() {
      var ch = commanderChar();
      var suf = ch && ch.gender === 'f' ? '02' : '01';
      var nov = 'image/character/novice_' + suf + '.png';
      if (!ch) return { src: nov, fallback: null };
      return { src: 'image/character/commander_' + suf + '.png', fallback: nov };
    },

    // {commander}: 지휘관 이름, {ally}: 전투 중 위기에 빠진 클랜원 이름 (없으면 '클랜원' — 다시 보기 등)
    _fmt: function(text, vars) {
      var ally = (vars && vars.ally) || tr('story.ally', '클랜원');
      return String(text == null ? '' : text).replace(/\{commander\}/g, this.commanderName()).replace(/\{ally\}/g, ally);
    },

    // ── DOM ──────────────────────────────
    _build: function() {
      var el = document.getElementById('story-layer');
      if (el) return el;
      el = document.createElement('div');
      el.id = 'story-layer';
      el.className = 'story-layer';
      el.setAttribute('role', 'dialog');
      el.setAttribute('aria-modal', 'true');
      el.innerHTML =
        '<div class="st-dim"></div>' +
        '<div class="st-top"><div class="st-title"></div>' +
          '<button type="button" class="st-skip"></button></div>' +
        '<div class="st-scene">' +
          '<div class="st-pt left"><img alt=""></div>' +
          '<div class="st-pt right"><img alt=""></div>' +
          '<div class="st-box">' +
            '<div class="st-name"></div>' +
            '<div class="st-text"></div>' +
            '<div class="st-next" aria-hidden="true">▼</div>' +
          '</div>' +
        '</div>';
      document.body.appendChild(el);
      var self = this;
      el.addEventListener('click', function(e) {
        if (e.target.closest('.st-skip')) { e.stopPropagation(); self._skip(); return; }
        e.stopPropagation();
        self._advance();
      });
      // 캡처 단계에서 키를 먼저 받아 전투 단축키(Space=대기 등)와 겹치지 않게 막는다
      window.addEventListener('keydown', function(e) {
        if (!self._active) return;
        e.stopImmediatePropagation();
        if (e.repeat) { e.preventDefault(); return; }
        if (e.key === 'Escape') { e.preventDefault(); self._skip(); }
        else if (e.key === ' ' || e.key === 'Enter' || e.key === 'ArrowRight') { e.preventDefault(); self._advance(); }
      }, true);
      return el;
    },

    _setPortrait: function(side, sp) {
      var el = this._el.querySelector('.st-pt.' + side);
      var img = el.querySelector('img');
      if (!sp || !sp.img) { el.classList.remove('show', 'boss'); el.dataset.key = ''; return; }
      if (el.dataset.key !== sp.key || img.dataset.src !== sp.img) {
        img.onerror = sp.fallback ? function() { img.onerror = null; img.src = sp.fallback; } : null;
        img.dataset.src = sp.img;
        img.src = sp.img;
        el.dataset.key = sp.key;
        el.classList.remove('enter'); void el.offsetWidth; el.classList.add('enter');
      }
      el.classList.toggle('boss', !!sp.boss);
      el.classList.add('show');
    },

    // ── 재생 ─────────────────────────────
    // lines: 대사 배열, opts: { stage, title, battle(짧은 전투 대사 모드), vars({ally}), onEnd }
    play: function(lines, opts) {
      opts = opts || {};
      var self = this;
      var list = (Array.isArray(lines) ? lines : []).filter(function(l) { return l && l.text; });
      if (!list.length) { if (opts.onEnd) opts.onEnd(); return Promise.resolve(); }
      // 이미 재생 중이면 끝난 뒤 이어서
      if (this._active) return this._active.promise.then(function() { return self.play(lines, opts); });

      var el = this._el = this._build();
      var st = { lines: list, idx: -1, typing: false, timer: null, opts: opts };
      st.promise = new Promise(function(resolve) { st.resolve = resolve; });
      this._active = st;

      el.querySelector('.st-skip').textContent = tr('story.skip', '건너뛰기') + ' ⏭';
      el.querySelector('.st-skip').title = 'Esc';
      var title = el.querySelector('.st-title');
      title.textContent = opts.title || '';
      title.style.display = opts.title ? '' : 'none';
      el.classList.toggle('battle', !!opts.battle);
      el.querySelectorAll('.st-pt').forEach(function(p) { p.classList.remove('show', 'speaking', 'boss'); p.dataset.key = ''; });
      el.classList.remove('closing');
      el.classList.add('open');
      this._next();
      return st.promise;
    },

    _next: function() {
      var st = this._active; if (!st) return;
      st.idx++;
      if (st.idx >= st.lines.length) { this._close(); return; }
      var line = st.lines[st.idx];
      var sp = this._speaker(line, st.opts);
      var el = this._el;
      var box = el.querySelector('.st-box');
      var nameEl = el.querySelector('.st-name');
      var textEl = el.querySelector('.st-text');

      el.classList.toggle('narration', !!sp.narr);
      if (!sp.narr) {
        if (sp.img) this._setPortrait(sp.side, sp);
        el.querySelectorAll('.st-pt').forEach(function(p) { p.classList.toggle('speaking', p.classList.contains(sp.side) && !!sp.img); });
        nameEl.textContent = sp.name;
        nameEl.className = 'st-name ' + sp.side + (sp.boss ? ' boss' : '');
        nameEl.style.display = sp.name ? '' : 'none';
      } else {
        el.querySelectorAll('.st-pt').forEach(function(p) { p.classList.remove('speaking'); });
        nameEl.style.display = 'none';
      }

      // 감정 표현: 흔들림(angry/shout), 기울임(worried/sad)
      var mood = line.mood || 'normal';
      box.className = 'st-box mood-' + mood + (sp.boss ? ' boss' : '');
      void box.offsetWidth;
      if (mood === 'angry' || mood === 'shout') box.classList.add('shake');

      // 한 글자씩 출력
      var full = this._fmt(line.text, st.opts.vars);
      var chars = Array.from(full);
      var i = 0;
      textEl.textContent = '';
      st.full = full;
      st.typing = true;
      el.classList.add('typing');
      clearInterval(st.timer);
      var self = this;
      st.timer = setInterval(function() {
        i++;
        textEl.textContent = chars.slice(0, i).join('');
        if (i >= chars.length) self._finishTyping();
      }, TYPE_MS);
    },

    _finishTyping: function() {
      var st = this._active; if (!st) return;
      clearInterval(st.timer);
      st.typing = false;
      this._el.querySelector('.st-text').textContent = st.full;
      this._el.classList.remove('typing');
    },

    // 클릭/Space/Enter: 출력 중이면 즉시 완성, 아니면 다음 대사
    _advance: function() {
      var st = this._active; if (!st) return;
      if (st.typing) this._finishTyping();
      else this._next();
    },

    _skip: function() { if (this._active) this._close(); },

    _close: function() {
      var st = this._active; if (!st) return;
      clearInterval(st.timer);
      this._active = null;
      var el = this._el;
      el.classList.add('closing');
      setTimeout(function() {
        if (!Story._active) el.classList.remove('open', 'closing', 'typing', 'narration');
        if (st.opts.onEnd) { try { st.opts.onEnd(); } catch (e) { console.error('[Story] onEnd', e); } }
        st.resolve();
      }, 180);
    },

    isPlaying: function() { return !!this._active; },

    // 본 적 없는 장면만 재생하고 기록 (끝까지 보거나 건너뛰면 본 것으로 처리)
    scene: function(key, lines, opts) {
      var self = this;
      if (lines === undefined || lines === null) lines = this.linesOf(key);
      if (!Array.isArray(lines) || !lines.length || this.seen(key)) return Promise.resolve(false);
      return this.play(lines, opts).then(function() { self.markSeen(key); return true; });
    },

    // ── 스테이지 흐름 ────────────────────
    // 출전 직전: 에피소드 첫 진입이면 프롤로그 → 스테이지 pre
    beforeStage: async function(stage) {
      if (!stage) return;
      try {
        await this.load();
        if (!this.data()) return;
        var ep = epOf(stage.id);
        await this.scene('ep' + ep + '_pro', null, { stage: stage, title: this.titleOf('ep' + ep + '_pro') });
        await this.scene('s' + stage.id + '_pre', null, { stage: stage, title: stageLabel(stage.id) });
      } catch (e) { console.error('[Story] beforeStage', e); }
    },

    // 승리 후: 스테이지 post → 에피소드 마지막 스테이지면 에필로그
    hasAfter: function(stage) {
      if (!stage || !this.data()) return false;
      var ep = epOf(stage.id), last = epStages(ep).slice(-1)[0] === stage.id;
      var k1 = 's' + stage.id + '_post', k2 = 'ep' + ep + '_epi';
      var has = function(k) { var l = Story.linesOf(k); return Array.isArray(l) && l.length && !Story.seen(k); };
      return has(k1) || (last && has(k2));
    },
    afterStage: async function(stage) {
      if (!stage) return;
      try {
        await this.load();
        if (!this.data()) return;
        await this.scene('s' + stage.id + '_post', null, { stage: stage, title: stageLabel(stage.id) });
        var ep = epOf(stage.id);
        if (epStages(ep).slice(-1)[0] === stage.id) {
          await this.scene('ep' + ep + '_epi', null, { stage: stage, title: this.titleOf('ep' + ep + '_epi') });
        }
      } catch (e) { console.error('[Story] afterStage', e); }
    },

    // 전투 중 짧은 대사 (kind: start|wave|boss|danger|last), vars: { ally } 치환값
    battle: function(stage, kind, vars) {
      if (!stage || BATTLE_KINDS.indexOf(kind) === -1) return Promise.resolve(false);
      return this.scene('s' + stage.id + '_' + kind, null, { stage: stage, battle: true, vars: vars || null });
    },

    // ── 다시 보기 ────────────────────────
    // 본 장면 키를 이야기 순서대로 정렬
    seenKeys: function() {
      var seen = this._seenAll(), self = this;
      var order = { pro: 0, pre: 1, battle: 2, post: 7, epi: 8 };
      var rank = function(k) {
        var m = /^ep(\d+)_(pro|epi)$/.exec(k);
        if (m) {
          var es = epStages(+m[1]);
          return m[2] === 'pro' ? [(es[0] || 0) - 0.5, 0] : [(es[es.length - 1] || 0) + 0.5, 0];
        }
        m = /^s(\d+)_(\w+)$/.exec(k);
        return m ? [+m[1], order[m[2]] == null ? 9 : order[m[2]]] : [1e9, 0];
      };
      // 전투 중 대사(start/wave/...)는 스테이지별 '전투 중' 한 항목으로 묶는다
      var keys = {};
      Object.keys(seen).forEach(function(k) {
        if (!seen[k]) return;
        var bm = /^s(\d+)_(\w+)$/.exec(k);
        if (bm && BATTLE_KINDS.indexOf(bm[2]) !== -1) k = 's' + bm[1] + '_battle';
        var l = self.linesOf(k);
        if (Array.isArray(l) && l.length) keys[k] = true;
      });
      return Object.keys(keys).sort(function(a, b) { var ra = rank(a), rb = rank(b); return ra[0] - rb[0] || ra[1] - rb[1]; });
    },

    openReplay: async function() {
      await this.load();
      var self = this;
      var keys = this.seenKeys();
      var pn = document.getElementById('story-replay');
      if (!pn) {
        pn = document.createElement('div');
        pn.id = 'story-replay';
        pn.className = 'story-replay';
        pn.addEventListener('click', function(e) { if (e.target === pn) pn.classList.remove('show'); });
        document.addEventListener('keydown', function(e) {
          if (e.key === 'Escape' && !self._active && pn.classList.contains('show')) pn.classList.remove('show');
        });
        document.body.appendChild(pn);
      }
      var html = '<div class="sr-box"><div class="sr-head"><span>📜 ' + tr('story.replay', '스토리 다시 보기') + '</span>' +
        '<button type="button" class="sr-close" aria-label="close">✕</button></div><div class="sr-list">';
      if (!keys.length) html += '<div class="sr-empty">' + tr('story.replay_empty', '아직 본 이야기가 없습니다') + '</div>';
      html += '</div></div>';
      pn.innerHTML = html;
      var list = pn.querySelector('.sr-list');
      var lastEp = 0;
      keys.forEach(function(k) {
        var m = /^ep(\d+)_/.exec(k) || /^s(\d+)_/.exec(k);
        var ep = /^ep/.test(k) ? +m[1] : epOf(+m[1]);
        if (ep !== lastEp) {
          lastEp = ep;
          var h = document.createElement('div'); h.className = 'sr-ep';
          var d = self.data(), epd = d && d.episodes && d.episodes[ep];
          h.textContent = 'EP.' + ep + ' ' + ((epd && epd.title) || tr('episode.' + ep + '.name', ''));
          list.appendChild(h);
        }
        var b = document.createElement('button');
        b.type = 'button';
        b.className = 'sr-item' + (/^ep/.test(k) ? ' ep' : '');
        b.textContent = self.titleOf(k);
        b.onclick = function() {
          var sm = /^s(\d+)_/.exec(k), em = /^ep(\d+)_(pro|epi)$/.exec(k);
          var stage = sm ? findStage(+sm[1]) : (em ? findStage(epStages(+em[1]).slice(-1)[0]) : null);
          pn.classList.remove('show');
          self.play(self.linesOf(k), { stage: stage, title: self.titleOf(k) }).then(function() { pn.classList.add('show'); });
        };
        list.appendChild(b);
      });
      pn.querySelector('.sr-close').onclick = function() { pn.classList.remove('show'); };
      pn.classList.add('show');
    },
  };

  window.Story = Story;
})();
