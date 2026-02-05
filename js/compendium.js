// ═══════════════════════════════════════════
// compendium.js — 도감 공유 렌더링 함수
// ═══════════════════════════════════════════

let CHARS = [];
let CD = {};
const RES = {
  fury: { label: '분노', color: '#ff6644', desc: '공격 시 +1, 피격 시 +2 → 10 도달 시 "몸부림" 반격 (ATK×0.5)', auto: '자동 회복 없음' },
  energy: { label: '기력', color: '#f0c040', desc: '매 턴 자동 회복, 숲에서 2배 회복 (암살자)', auto: '매 턴 +resRec' },
  mana: { label: '마나', color: '#4488ff', desc: '매 턴 자동 회복, 스킬 사용 시 소모', auto: '매 턴 +resRec, 시작 시 MAX' }
};

// ── CD 객체 로드 ────────────────────────────
function loadCD() {
  CD = window.CD || {};
  buildCHARS();
}

// ── CHARS 배열 동적 생성 ────────────────
function buildCHARS() {
  CHARS = Object.entries(CD).map(([key, d]) => ({
    key,
    name: d.name,
    icon: d.icon,
    hp: d.base.hp,
    atk: d.base.atk,
    def: d.base.def,
    move: d.base.move,
    range: d.base.range,
    role: d.role,
    res: d.res,
    maxRes: d.maxRes,
    resRec: d.resRec,
    desc: d.desc,
    growth: d.growth
  }));
}

// ── 유틸리티 함수 ──────────────────────────
function roleLabel(role) {
  const labels = { melee: '근접', ranged: '원거리', healer: '치유' };
  return labels[role] || role;
}

function roleColor(role) {
  const colors = { melee: '#f87171', ranged: '#60a5fa', healer: '#4ade80' };
  return colors[role] || '#e2e8f0';
}

function getGrowthAvg(growth) {
  return {
    hp: Math.round((growth.hp[0] + growth.hp[1]) / 2),
    atk: Math.round((growth.atk[0] + growth.atk[1]) / 2),
    def: Math.round((growth.def[0] + growth.def[1]) / 2)
  };
}

// ── 직업 카드 렌더링 ────────────────────────
function renderClassCards() {
  const container = document.getElementById('class-cards');
  if (!container) return;

  container.innerHTML = '';
  CHARS.forEach(c => {
    const ri = RES[c.res];
    const growthAvg = getGrowthAvg(c.growth);

    const card = document.createElement('div');
    card.className = 'class-card';
    card.innerHTML = `
      <div class="class-card-header">
        <div class="class-icon">${c.icon}</div>
        <div class="class-meta">
          <div class="class-name">${c.name}</div>
          <div><span class="role-tag" style="background:rgba(${hexToRgb(roleColor(c.role))},0.15);color:${roleColor(c.role)}">${roleLabel(c.role)}</span></div>
          <div class="class-desc">${c.desc}</div>
        </div>
      </div>

      <div class="stat-box">
        <div class="stat-item">
          <div class="stat-label">HP</div>
          <div class="stat-value">${c.hp}</div>
        </div>
        <div class="stat-item">
          <div class="stat-label">ATK</div>
          <div class="stat-value">${c.atk}</div>
        </div>
        <div class="stat-item">
          <div class="stat-label">DEF</div>
          <div class="stat-value">${c.def}</div>
        </div>
        <div class="stat-item">
          <div class="stat-label">이동</div>
          <div class="stat-value">${c.move}</div>
        </div>
        <div class="stat-item">
          <div class="stat-label">사거리</div>
          <div class="stat-value">${c.range}</div>
        </div>
      </div>

      <div class="res-info">
        <span style="color:${ri.color};font-weight:700">${ri.label}</span>
        <span style="color:var(--dim);font-size:11px">MAX ${c.maxRes} ${c.resRec > 0 ? '| +' + c.resRec + '/턴' : ''}</span>
      </div>

      <div class="growth-info">
        <div style="font-size:11px;color:var(--dim);margin-bottom:6px">레벨업 성장</div>
        <div class="growth-row">
          <span style="width:40px">HP</span>
          <div style="flex:1;height:12px;background:rgba(74,222,128,0.2);border-radius:2px;position:relative">
            <div style="position:absolute;left:0;top:0;width:${growthAvg.hp / 2}%;height:100%;background:#4ade80;border-radius:2px"></div>
          </div>
          <span style="width:50px;text-align:right">[${c.growth.hp[0]},${c.growth.hp[1]}]</span>
        </div>
        <div class="growth-row">
          <span style="width:40px">ATK</span>
          <div style="flex:1;height:12px;background:rgba(248,113,113,0.2);border-radius:2px;position:relative">
            <div style="position:absolute;left:0;top:0;width:${growthAvg.atk * 10}%;height:100%;background:#f87171;border-radius:2px"></div>
          </div>
          <span style="width:50px;text-align:right">[${c.growth.atk[0]},${c.growth.atk[1]}]</span>
        </div>
        <div class="growth-row">
          <span style="width:40px">DEF</span>
          <div style="flex:1;height:12px;background:rgba(96,165,250,0.2);border-radius:2px;position:relative">
            <div style="position:absolute;left:0;top:0;width:${growthAvg.def * 20}%;height:100%;background:#60a5fa;border-radius:2px"></div>
          </div>
          <span style="width:50px;text-align:right">[${c.growth.def[0]},${c.growth.def[1]}]</span>
        </div>
      </div>
    `;
    container.appendChild(card);
  });
}

// ── 자원 시스템 렌더링 ──────────────────────
function renderResourceSection() {
  const rb = document.getElementById('res-blocks');
  if (!rb) return;

  rb.innerHTML = '';
  ['fury', 'energy', 'mana'].forEach(key => {
    const ri = RES[key];
    const users = CHARS.filter(c => c.res === key);

    let inner = `<div style="font-weight:900;font-size:14px;color:${ri.color};margin-bottom:8px">⚡ ${ri.label}</div>`;
    inner += `<div style="font-size:12px;color:#cbd5e1;margin-bottom:4px">${ri.desc}</div>`;
    inner += `<div style="font-size:11px;color:var(--dim);margin-bottom:12px">${ri.auto}</div>`;

    users.forEach(u => {
      const fillPct = u.resRec > 0 ? Math.min(100, u.resRec / u.maxRes * 100 * 4) : 15;
      const fillTurns = u.resRec > 0 ? Math.ceil(u.maxRes / u.resRec) + '턴 풀충' : '공격으로 획득';

      inner += `<div class="res-meter">
        <span class="res-meter-label">${u.icon} ${u.name}</span>
        <div class="res-meter-track"><div class="res-meter-fill" style="width:${fillPct}%;background:${ri.color}44;color:${ri.color}">${u.resRec || 0}/턴</div></div>
        <span class="res-meter-info">MAX ${u.maxRes} · ${fillTurns}</span>
      </div>`;
    });

    rb.innerHTML += `<div class="res-block" style="border-color:${ri.color}">${inner}</div>`;
  });
}

// ── 스테이지 데이터 로드 ────────────────────
function loadSTAGES() {
  return window.STAGES || [];
}

// ── 스테이지 카드 렌더링 ────────────────────
function renderStageCards() {
  const container = document.getElementById('stage-cards');
  if (!container) return;

  const STAGES = loadSTAGES();
  container.innerHTML = '';

  STAGES.forEach(stage => {
    const difficultyScore = ((stage.sm.hp + stage.sm.atk) / 2 * 100).toFixed(0);
    const enemyCount = {};
    stage.en.forEach(cls => {
      enemyCount[cls] = (enemyCount[cls] || 0) + 1;
    });

    const enemyDisplay = Object.entries(enemyCount)
      .map(([cls, cnt]) => `${CD[cls]?.icon || '?'}×${cnt}`)
      .join(' ');

    const card = document.createElement('div');
    card.className = 'stage-card';
    card.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:start;margin-bottom:8px">
        <div>
          <div class="stage-name">${stage.name}</div>
          <div style="font-size:11px;color:var(--dim);margin-top:2px">${stage.theme}</div>
        </div>
        <div style="background:var(--gold);color:var(--bg);padding:2px 8px;border-radius:4px;font-size:11px;font-weight:700">Stage ${stage.id}</div>
      </div>

      <div class="stage-info">
        <div style="display:flex;gap:8px;font-size:11px;margin-bottom:8px">
          <span style="background:rgba(96,165,250,0.15);color:#60a5fa;padding:2px 6px;border-radius:3px">${stage.style === 'defense' ? '방어전' : stage.style === 'offense' ? '공격전' : '혼합'}</span>
          <span style="color:var(--dim)">난이도: ${difficultyScore}%</span>
        </div>

        <div style="font-size:12px;color:#cbd5e1;margin-bottom:8px">${stage.story}</div>

        <div style="background:rgba(0,0,0,0.2);padding:6px;border-radius:4px;font-size:11px;margin-bottom:8px">
          <div style="color:var(--dim);margin-bottom:2px">적 구성 (${stage.en.length})</div>
          <div>${enemyDisplay}</div>
        </div>

        ${stage.boss ? `
        <div style="background:rgba(167,139,250,0.1);border:1px solid rgba(167,139,250,0.3);padding:6px;border-radius:4px;font-size:11px">
          <div style="color:var(--purple);font-weight:700">👹 보스: ${stage.boss.name}</div>
          <div style="color:var(--dim);margin-top:2px">${CD[stage.boss.cls]?.icon} ${CD[stage.boss.cls]?.name}</div>
        </div>
        ` : ''}
      </div>
    `;
    container.appendChild(card);
  });
}

// ── 아이템 테이블 렌더링 ────────────────────
function renderItemTable() {
  const container = document.getElementById('item-table');
  if (!container) return;

  const potions = window.EXP_POTIONS || [];
  const totalWeight = potions.reduce((sum, p) => sum + p.weight, 0);

  let html = '<table><thead><tr><th></th><th>이름</th><th>경험치</th><th>가격</th><th>효율</th><th>확률</th></tr></thead><tbody>';

  potions.forEach(p => {
    const efficiency = (p.exp / p.cost).toFixed(2);
    const probability = ((p.weight / totalWeight) * 100).toFixed(0);
    html += `
      <tr>
        <td style="text-align:center;font-size:20px">${p.icon}</td>
        <td style="text-align:left;font-weight:700;color:var(--gold)">${p.name}</td>
        <td style="color:var(--green)">${p.exp}</td>
        <td style="color:var(--blue)">${p.cost} G</td>
        <td style="font-weight:700">${efficiency}</td>
        <td style="color:var(--dim)">${probability}%</td>
      </tr>
    `;
  });

  html += '</tbody></table>';
  container.innerHTML = html;
}

// ── 초기화 ────────────────────────────────
function initCompendium() {
  loadCD();
  if (CHARS.length > 0) {
    renderClassCards();
    renderResourceSection();
  }
}

// ── DOM 준비 완료 후 초기화 ──────────────
document.addEventListener('DOMContentLoaded', () => {
  setTimeout(() => {
    initCompendium();
  }, 300);
});

// ── 유틸리티: 16진수 색상을 RGB로 변환 ────
function hexToRgb(hex) {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result ? `${parseInt(result[1], 16)},${parseInt(result[2], 16)},${parseInt(result[3], 16)}` : '230,232,240';
}
