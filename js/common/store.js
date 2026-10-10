// ═══════════════════════════════════════════
//  common/store.js — 저장소 한 곳: 게임의 모든 저장 읽기·쓰기는 Store 를 거친다
//  (localStorage 를 직접 부르지 말 것 — 모든 페이지에서 가장 먼저 불러온다)
//
//  지금은 브라우저 localStorage. 앱(Capacitor)·Steam(Electron) 포장이나 Godot 이전 때는
//  Store.useBackend({ getItem, setItem, removeItem, keys, clear }) 로 저장 위치만 바꾸면 된다.
//  localStorage 를 못 쓰는 환경(사생활 보호 모드 등)에서는 메모리에 임시 보관.
// ═══════════════════════════════════════════
var Store = (function() {
  var mem = {};
  var memBackend = {
    getItem: function(k) { return Object.prototype.hasOwnProperty.call(mem, k) ? mem[k] : null; },
    setItem: function(k, v) { mem[k] = String(v); },
    removeItem: function(k) { delete mem[k]; },
    keys: function() { return Object.keys(mem); },
    clear: function() { mem = {}; },
  };
  var custom = null;

  function backend() {
    if (custom) return custom;
    var ls = null;
    try { ls = window.localStorage; } catch (_) {}
    if (!ls) return memBackend;
    return {
      getItem: function(k) { return ls.getItem(k); },
      setItem: function(k, v) { ls.setItem(k, v); },
      removeItem: function(k) { ls.removeItem(k); },
      keys: function() { return Object.keys(ls); },
      clear: function() { ls.clear(); },
    };
  }

  return {
    // 문자열 그대로 (없으면 null)
    get: function(key) { try { return backend().getItem(key); } catch (_) { return null; } },
    // 저장 성공 여부 반환 (용량 초과 등은 false)
    set: function(key, value) { try { backend().setItem(key, String(value)); return true; } catch (_) { return false; } },
    remove: function(key) { try { backend().removeItem(key); } catch (_) {} },
    // JSON 객체로 (없거나 깨졌으면 fallback)
    getJSON: function(key, fallback) {
      try { var raw = backend().getItem(key); return raw == null ? fallback : JSON.parse(raw); } catch (_) { return fallback; }
    },
    setJSON: function(key, obj) { return this.set(key, JSON.stringify(obj)); },
    keys: function() { try { return backend().keys(); } catch (_) { return []; } },
    clear: function() { try { backend().clear(); } catch (_) {} },
    // 저장 위치 교체 (앱·Steam 포장 때)
    useBackend: function(b) { custom = b || null; },
  };
})();
