// ═══════════════════════════════════════════
//  battle/event.js — EventBus (pub/sub)
// ═══════════════════════════════════════════

const EventBus = {
  _listeners: {},

  on(event, fn) {
    if (!this._listeners[event]) this._listeners[event] = [];
    this._listeners[event].push(fn);
    return () => this.off(event, fn);
  },

  off(event, fn) {
    const arr = this._listeners[event];
    if (!arr) return;
    this._listeners[event] = arr.filter(f => f !== fn);
  },

  emit(event, data) {
    const arr = this._listeners[event];
    if (!arr) return;
    for (const fn of arr) {
      try { fn(data); } catch (e) { console.error(`[EventBus] ${event}:`, e); }
    }
  },

  async emitAsync(event, data) {
    const arr = this._listeners[event];
    if (!arr) return;
    for (const fn of arr) {
      try { await fn(data); } catch (e) { console.error(`[EventBus] ${event}:`, e); }
    }
  },

  clear() { this._listeners = {}; }
};
