// ═══════════════════════════════════════════
//  skills/_registry.js — 스킬 핸들러 레지스트리
// ═══════════════════════════════════════════

const SKILL_HANDLERS = {};
function registerSkill(id, handler) { SKILL_HANDLERS[id] = handler; }

// 스킬 완료 공통 처리
// opts: { delay, rmDead, chkEnd, rTer }
function _skillDone(u, G, opts) {
	u.ha = true; u.hm = true; G.awPM = false;
	G.skillMode = false; G._curSkill = null; G.hideAM();
	if (opts && opts.rTer) G.rTer();
	if (opts && opts.delay) {
		setTimeout(() => {
			if (opts.rmDead) G._rmDead();
			G.rUnits();
			if (opts.chkEnd) G.chkEnd();
			G.clrSel(); G.chkAutoEnd();
		}, opts.delay);
	} else {
		G.rUnits(); G.clrSel(); G.chkAutoEnd();
	}
}

// 스킬 실패 시 비용 환불 + 행동 종료
function _skillRefund(u, sk, G) {
	u.res += sk.cost;
	u.ha = true; u.hm = true; G.awPM = false;
	G.skillMode = false; G._curSkill = null; G.hideAM(); G.rUnits();
}
