// ═══════════════════════════════════════════
//  battle/story-battle.js — 전투 중 스토리 대사 연결 (js/common/story.js 사용)
//  기존 모듈은 고치지 않고, 차례가 바뀌는 지점에서만 대사를 끼워 넣는다:
//    - TurnManager.nextAction 앞 (다음 유닛 결정 전) → 쌓인 대사 재생이 끝날 때까지 대기
//    - AI.eAI 앞 (적 행동 직전) → 같은 차례에 생긴 웨이브/보스 대사가 끝날 때까지 대기
//    - 아군 차례 시작(turn_start) → 대사 창이 화면을 막으므로 플레이어 입력도 자연히 멈춤
//  본 대사는 game_story_seen에 기록되므로 재시작·이어하기 때 반복되지 않는다.
// ═══════════════════════════════════════════

const StoryBattle = {
  _queue: [],        // 재생 대기 중인 대사 종류
  _queued: {},       // 이번 전투에서 이미 큐에 넣은 종류
  _playing: null,    // 재생 중 Promise
  _introDone: false, // 출전 전 대사(프롤로그·pre) 확인 여부
  _startDone: false,
  _healthy: {},      // HP 30% 이상인 것을 확인한 클랜원 id (위기 대사 조건)
  _vars: {},         // 대사 치환값 ({ally}: 위기에 빠진 클랜원 이름)
  PRIORITY: { start: 0, boss: 1, wave: 2, danger: 3, last: 4 },

  get stage() { return GameStore.cStage; },

  init() {
    if (typeof Story === 'undefined') return;
    Story.load();

    // 다음 유닛 결정 전: (첫 호출이면 출전 전 대사) + 쌓인 전투 대사
    const origNext = TurnManager.nextAction;
    TurnManager.nextAction = async function() {
      try {
        if (!StoryBattle._introDone) {
          StoryBattle._introDone = true;
          // 스테이지 선택을 거치지 않고 들어온 경우(다음 스테이지 버튼 등)에도 프롤로그·pre를 보여준다 (본 것은 건너뜀)
          if (StoryBattle.stage) await Story.beforeStage(StoryBattle.stage);
          // 전투 시작 대사: 어느 유닛이든 첫 행동 전에 (= 첫 아군 차례 직전)
          StoryBattle._startDone = true;
          StoryBattle.enqueue('start');
        }
        await StoryBattle.flush();
      } catch (e) { console.error('[StoryBattle]', e); }
      return origNext.apply(this, arguments);
    };

    // 적 행동 직전
    const origAI = AI.eAI;
    AI.eAI = async function() {
      try { await StoryBattle.flush(); } catch (e) { console.error('[StoryBattle]', e); }
      return origAI.apply(this, arguments);
    };

    // 결과 화면 전에 승리 후 대사: 보상 저장(showRes 안의 onBattleEnd)은 먼저 끝내고 결과 창만 잠시 숨긴다
    const origRes = Renderer.showRes;
    Renderer.showRes = function(win, msg) {
      const r = origRes.apply(this, arguments);
      const st = StoryBattle.stage;
      StoryBattle._queue = [];
      if (win && st && Story.hasAfter(st)) {
        const ov = document.getElementById('modal-overlay');
        if (ov) ov.classList.remove('show');
        const wait = Story.isPlaying() ? StoryBattle._playing || Promise.resolve() : Promise.resolve();
        wait.then(() => Story.afterStage(st)).then(() => { if (ov) ov.classList.add('show'); });
      }
      return r;
    };

    // 이벤트 구독
    EventBus.on('turn_start', ({ phase }) => {
      this.scan();
      // 아군 차례는 진행이 플레이어 입력을 기다리므로 바로 재생 (적 차례는 AI.eAI 앞에서 재생)
      if (phase === 'player') this.flush();
    });
    EventBus.on('wave_spawn', () => {
      // 첫 배치(전투 시작 시 actCount=0)는 제외, 그다음 증원부터
      if (GameStore.actCount > 0) this.enqueue('wave');
      this.scan();
    });
    EventBus.on('unit_killed', () => this.scan());
    EventBus.on('unit_attacked', () => this.scan());
  },

  // 현재 전장 상태를 보고 조건이 맞는 대사를 큐에 넣는다
  scan() {
    const S = GameStore, st = S.cStage;
    if (!st || FSM.is(BattleState.BATTLE_END)) return;
    // 보스 등장
    if (S.units.some(u => u.isBoss && u.team === 'enemy' && u.hp > 0)) this.enqueue('boss');
    // 클랜원 위기: 클랜원(소환수 제외) 누군가가 이 전투에서 처음으로 HP 30% 아래로 떨어질 때 1회
    //   한 번이라도 30% 이상이던 클랜원만 센다 (이어하기로 들어왔을 때 이미 낮은 HP는 '떨어진 것'이 아님)
    if (!this._queued.danger) {
      for (const u of S.units) {
        if (u.team !== 'ally' || u.isSummon || String(u.cls).startsWith('summon_') || u.hp <= 0) continue;
        if (u.hp >= u.mhp * 0.3) { this._healthy[u.id] = true; continue; }
        if (this._healthy[u.id]) { this._vars.ally = this.allyName(u); this.enqueue('danger'); break; }
      }
    }
    // 남은 적 1명 (더 나올 증원 없음)
    if (S.eSpwn >= st.tot && S.units.filter(u => u.team === 'enemy' && u.hp > 0 && !u.isSummon).length === 1) this.enqueue('last');
  },

  // 대사에 넣을 클랜원 이름 (이름이 없거나 아이콘뿐이면 비워 두어 Story 쪽 기본값 '클랜원'을 쓴다)
  allyName(u) {
    const n = String(u.name || '');
    return /[A-Za-z0-9\u3131-\uD79D\u00C0-\u024F]/.test(n) ? n : '';
  },

  enqueue(kind) {
    const st = this.stage;
    if (!st || this._queued[kind]) return;
    if (Story.seen('s' + st.id + '_' + kind)) { this._queued[kind] = true; return; }
    const lines = Story.linesOf('s' + st.id + '_' + kind);
    if (!Array.isArray(lines) || !lines.length) return; // 대본 로드 전일 수 있으니 기록하지 않음
    this._queued[kind] = true;
    this._queue.push(kind);
    this._queue.sort((a, b) => this.PRIORITY[a] - this.PRIORITY[b]);
  },

  // 쌓인 대사를 순서대로 재생. 재생 중에 다시 불리면 같은 Promise를 기다린다
  flush() {
    if (this._playing) return this._playing;
    if (typeof Story === 'undefined') return Promise.resolve();
    this._playing = (async () => {
      await Story.load();
      this.scan();
      while (this._queue.length && !FSM.is(BattleState.BATTLE_END)) {
        const kind = this._queue.shift();
        await Story.battle(this.stage, kind, this._vars);
      }
      this._queue = FSM.is(BattleState.BATTLE_END) ? [] : this._queue;
    })().catch(e => console.error('[StoryBattle]', e)).finally(() => { this._playing = null; });
    return this._playing;
  },
};

StoryBattle.init();
