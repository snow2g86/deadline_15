// ═══════════════════════════════════════════
//  battle/state.js — FSM + GameStore
// ═══════════════════════════════════════════

const BattleState = {
  LOADING:          'LOADING',
  ADVANCING_TICK:   'ADVANCING_TICK',
  PLAYER_IDLE:      'PLAYER_IDLE',
  UNIT_SELECTED:    'UNIT_SELECTED',
  MOVE_MODE:        'MOVE_MODE',
  ATTACK_MODE:      'ATTACK_MODE',
  HEAL_MODE:        'HEAL_MODE',
  ATTACK_HEAL_MODE: 'ATTACK_HEAL_MODE',
  SKILL_TARGET:     'SKILL_TARGET',
  ITEM_TARGET:      'ITEM_TARGET',
  AI_TURN:          'AI_TURN',
  ANIMATING:        'ANIMATING',
  WAVE_TRANSITION:  'WAVE_TRANSITION',
  BATTLE_END:       'BATTLE_END',
};

const FSM = {
  _state: BattleState.LOADING,
  _prev: null,

  get state() { return this._state; },

  transition(newState) {
    if (this._state === newState) return;
    this._prev = this._state;
    this._state = newState;
    EventBus.emit('state_changed', { from: this._prev, to: newState });
  },

  is(...states) { return states.includes(this._state); },

  acceptsCellClick() {
    return this.is(
      BattleState.PLAYER_IDLE,
      BattleState.UNIT_SELECTED,
      BattleState.MOVE_MODE,
      BattleState.ATTACK_MODE,
      BattleState.HEAL_MODE,
      BattleState.ATTACK_HEAL_MODE,
      BattleState.SKILL_TARGET,
      BattleState.ITEM_TARGET
    );
  },

  isPlayerTurn() {
    return this.is(
      BattleState.PLAYER_IDLE,
      BattleState.UNIT_SELECTED,
      BattleState.MOVE_MODE,
      BattleState.ATTACK_MODE,
      BattleState.HEAL_MODE,
      BattleState.ATTACK_HEAL_MODE,
      BattleState.SKILL_TARGET,
      BattleState.ITEM_TARGET
    );
  },

  reset() {
    this._state = BattleState.LOADING;
    this._prev = null;
  }
};

// GameStore: 전역 전투 상태 저장소
const GameStore = {
  ter: [],
  units: [],
  nid: 1,
  turn: 1,
  sel: null,
  curUnit: null,
  actCount: 0,

  mvT: [],
  atkT: [],
  healT: [],

  cStage: null,
  eSpwn: 0,
  eQ: [],
  cleared: new Set(),
  gold: 0,
  party: [],
  camDir: 0,

  battleExp: {},
  allyPos: {},
  traps: [],
  poisonMists: [],
  eFormPos: [],
  fogVisible: new Set(),

  _killCount: 0,
  _killExpPool: 0,
  _deadAllyUids: [],

  preMv: null,
  _curSkill: null,

  breached: 0,
  gateHP: {},
  wallHP: {},

  practiceMode: false,

  _battlePotions: [],
  _battlePotionIndices: [],
  _siegeItems: [],
  _siegeInvIndices: [],

  _sett: { bgmVol: 0.6, sfxVol: 0.8, bgmOn: true, sfxOn: true, speed: 1, language: null },

  reset() {
    this.ter = []; this.units = []; this.nid = 1; this.turn = 1;
    this.sel = null; this.curUnit = null; this.actCount = 0;
    this.mvT = []; this.atkT = []; this.healT = [];
    this.eSpwn = 0; this.eQ = [];
    this.battleExp = {}; this.allyPos = {}; this.traps = [];
    this.poisonMists = []; this.eFormPos = []; this.fogVisible = new Set();
    this._killCount = 0; this._killExpPool = 0; this._deadAllyUids = [];
    this.preMv = null; this._curSkill = null;
    this.breached = 0; this.gateHP = {}; this.wallHP = {};
    this._battlePotions = []; this._battlePotionIndices = [];
    this._siegeItems = []; this._siegeInvIndices = [];
    FSM.reset();
  }
};
