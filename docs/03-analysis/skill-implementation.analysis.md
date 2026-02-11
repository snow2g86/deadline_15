# skill-implementation Gap Analysis Report

> **Date**: 2026-02-11 | **Match Rate**: 93% | **Status**: PASS

## Overall Scores

| Category | Score | Status |
|----------|:-----:|:------:|
| Data Schema (LEARNABLE_SKILLS) | 100% | PASS |
| Skill Handlers (target/exec) | 100% | PASS |
| Passive System (_common.js) | 100% | PASS |
| Battle Logic Integration | 73% | WARN |
| Save/Load | 25% | WARN (low priority) |
| i18n (3 languages) | 100% | PASS |
| UI Buff Icons | 100% | PASS |
| **Overall** | **93%** | **PASS** |

## Issues Found (6)

### Issue #1 [BUG] chkTrap stun hardcoded to 2
- **File**: `js/battle/core.js:225`
- `u.stunned = Math.max(u.stunned, 2)` ignores `trap.stun` value
- `sapper_enhancedtrap` sets `stun:3` but chkTrap never reads it
- **Fix**: `u.stunned = Math.max(u.stunned, trap.stun || 2)`

### Issue #2 [CHANGED] brawler_counter triggers on attacker side
- **Design**: defender-side (when brawler is attacked, counter-attack)
- **Impl**: attacker-side (after brawler attacks, extra hit at 30%)
- **Impact**: Medium - different behavior than design

### Issue #3 [MISSING] brawler_counter absent from eAtk
- **File**: `js/battle/ai.js` eAtk()
- When enemies attack brawlers, no counter triggered
- **Impact**: High - passive only works on offense

### Issue #4 [CHANGED] lancer_spearwall damage
- **Design**: `ATK * 0.5 - enemy.def`
- **Impl**: `ATK - enemy.def` (full ATK)
- **Impact**: Medium - double designed damage

### Issue #5 [CHANGED] poisonMists subtracts DEF
- **Design**: true damage (`ATK*0.3`, no DEF subtraction)
- **Impl**: `ATK*0.3 - e.def`
- **Impact**: Medium - weaker vs high-DEF enemies

### Issue #6 [MISSING/LOW] summoner_soulbond in chkEnd
- Summoner dies -> summons removed -> soulbond not triggered
- **Impact**: Zero (dead summoner can't use MP anyway)

## Verification Checklist

- [x] 16 LEARNABLE_SKILLS entries correct
- [x] 10 active skill handlers registered
- [x] FURY_PASSIVES.lancer added
- [x] calcDmg: empower/phalanx/manasurge
- [x] tickBuffs: phalanx/empower/rooted
- [x] getSkillBuffs: 9 new buff icons
- [x] _rootedTurns blocks enemy movement
- [x] _chkSpearwall on all 6 eMv paths
- [x] soulbond on summon expiry + combat death
- [x] poisonMists tick at ally turn start
- [x] i18n: ko/en/es all 3 languages complete
- [ ] chkTrap uses trap.stun (BUG)
- [ ] brawler_counter defensive trigger (MISSING)
