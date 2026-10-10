// ═══════════════════════════════════════════
//  skills/_registry.js — 스킬 핸들러 레지스트리
// ═══════════════════════════════════════════

const SKILL_HANDLERS = {};
function registerSkill(id, handler) { SKILL_HANDLERS[id] = handler; }

// 스킬 완료 공통 처리
// opts: { delay, rmDead, chkEnd, rTer }
function _skillDone(u, G, opts) {
	u.ha = true; u.hm = true; G.awPM = false;
	G.skillMode = false; G._curSkill = null; Fx.hideActionMenu();
	if (opts && opts.rTer) Fx.redrawTerrain();
	// 기본 delay: 300ms (VFX 애니메이션 완료 대기)
	const delay = (opts && opts.delay !== undefined) ? opts.delay : 300;
	Fx.later(() => {
		if (opts && opts.rmDead) G._rmDead();
		Fx.redrawUnits();
		if (opts && opts.chkEnd) G.chkEnd();
		G.clrSel(); G.endUnitTurn(u);
	}, delay);
}

// 스킬 실패 시 비용 환불 + 행동메뉴 복귀
function _skillRefund(u, sk, G) {
	u.res += sk.cost;
	G.skillMode = false; G._curSkill = null;
	G.atkT = []; G.healT = [];
	const a = G.atkC(u);
	G.atkT = a.filter(c => { const v = G.uAt(c.x, c.y); return v && v.team === 'enemy' });
	if (u.role === 'healer') { G.healT = a.filter(c => { const v = G.uAt(c.x, c.y); return v && v.team === 'ally' && v.hp < v.mhp && v.id !== u.id }); }
	Fx.redrawTerrain(); Fx.redrawUnits(); Fx.showActionMenu(u);
}
