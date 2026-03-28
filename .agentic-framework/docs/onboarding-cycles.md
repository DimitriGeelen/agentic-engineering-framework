# Onboarding Experiment — Cycle Log

**Owning task:** T-124
**Subject project:** /opt/001-sprechloop

## Cycle 1 — 2026-02-17

**Starting state:** /opt/001-sprechloop initialized, T-001 inception created, no prior session history
**Observation window:** ~45 minutes (unstructured — pre-protocol)
**New observations:** O-001 through O-010 (10 total: 3x P0, 7x P1)
**Regressions:** N/A (first cycle)
**Fix applied this cycle:** O-009 partially (manual CLAUDE.md sync in sprechloop + template update)
**Cycle verdict:** FAIL (3x P0, 7x P1)
**Notes:** Agent committed 6 times without user check-in. Full Flask web app built during inception phase. Go/no-go decision for T-001 never made. Browser API constraint (O-010) discovered only after full app was built. Template drift (O-009) was the silent root cause enabling all other governance failures.

## Cycle 2 — 2026-02-17

**Starting state:** Cycle 1 fixes applied (T-125, T-126, T-127 partially)
**New observations:** Budget exhaustion (O-008 → T-128 circuit breaker, then T-136 auto-handover)
**Cycle verdict:** FAIL (budget runaway: 25 handover commits in 10min from auto-handover loop)
**Fixes:** T-128 (circuit breaker), T-136 (auto-handover with cooldown), T-137 (template enforcement)

## Cycle 3 — 2026-02-18

**Starting state:** Budget-gate.sh (T-139) built as hybrid PreToolUse+PostToolUse enforcement
**New observations:** create-task.sh bypasses default.md template, knowledge capture commands don't write
**Cycle verdict:** FAIL (task quality collapse: thin tasks, empty knowledge pages)
**Fixes:** T-140 (inception: root cause analysis), T-141 (template wiring + knowledge YAML bugs + 21 tests)

## Cycle 4 — 2026-02-18

**Starting state:** T-141 complete, budget-gate active, knowledge backfilled
**Observation window:** Full Watchtower portal audit on :3001 (sprechloop)
**New observations:** 6 bugs (4x P0, 2x P1)

| # | Priority | Bug | Fix Task |
|---|----------|-----|----------|
| 1 | P0 | add-pattern YAML format mismatch (patterns never wrote) | T-141 |
| 2 | P0 | learnings/decisions `[]` header = invalid YAML | T-141 |
| 3 | P0 | fw init missing directives.yaml + gaps.yaml | T-142 |
| 4 | P0 | Unquoted colons in name: break YAML (16/23 tasks invisible) | T-143 |
| 5 | P1 | add-pattern/learning/decision exit code 1 from trailing conditionals | T-141 |
| 6 | P1 | Watchtower PROJECT_ROOT defaults to framework, not project | Manual restart |

**Regressions:** None from prior fixes
**Fixes applied:** T-141 (already done), T-142, T-143
**Cycle verdict:** FAIL (6 bugs found, all fixed)
**Notes:** After fixes, all Watchtower pages populated: Tasks (23/23), Learnings (15), Decisions (8), Patterns (5), Directives (4), Enforcement (4 tiers + hooks), Quality (16 pass / 5 warn), Metrics (dashboard populated). Test suite now at 22 tests. Pattern of bugs: init.sh incomplete (doesn't create all files), create-task.sh doesn't sanitize YAML values, knowledge capture scripts have format mismatches between init and add commands.

## Cycle 5 — 2026-02-18

**Starting state:** All cycle 4 fixes applied (T-141, T-142, T-143). T-145 (budget gate deadlock) also fixed.
**Observation window:** Systematic HTTP + content audit of all 14 Watchtower pages on :3001
**New observations:** 0 bugs
**Regressions:** None
**Cycle verdict:** PASS (10/10 pages pass, all data populated)
**Notes:** First clean cycle. Tasks: 23 (1 captured, 1 in-progress, 21 completed). Knowledge: 15 learnings, 8 decisions, 5 patterns. Governance: 4 directives, 4 enforcement tiers (6/6 hooks), quality gate WARN (16 pass, 8 warn). Metrics dashboard fully populated (99% traceability, 28 knowledge items).

## Cycle 6 — 2026-02-18

**Starting state:** Cycle 5 passed, no changes between cycles
**Observation window:** Same 14-page audit with content keyword validation
**New observations:** 0 bugs
**Regressions:** None
**Cycle verdict:** PASS (14/14 pages pass)
**Notes:** Second consecutive clean pass. Two-PASS threshold met. T-124 inception GO decision recorded.
