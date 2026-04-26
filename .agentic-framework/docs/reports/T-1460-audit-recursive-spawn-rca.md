# T-1460 — fw audit Recursive-Spawn Pathology (RCA)

**Type:** Inception (RCA)
**Date:** 2026-04-25
**Decision:** GO (Phase 1 — lift QUIET-only flock guard)
**Source task:** `.tasks/completed/T-1460-fw-audit-recursive-spawn-pathology--obse.md`

## Problem Statement

**For whom:** the operator running `fw audit` from a session, plus any commit hook or pre-push hook chain that re-runs audit.

**What problem:** observed during T-1441 close — concurrent audit invocations (one foreground from agent investigation, one inside T-1441's verification gate) caused `audit.sh` to accumulate **22 processes**, parent-child chain 6+ levels deep, ~1 spawn/min for 5+ minutes. Killed manually with `pkill -KILL`.

**Why now:** every session today triggers 2-3 audits via push hooks; the pathology can recur any time two audits race.

## Audit Findings

- `audit.sh:306` confirms flock guard is wrapped in `if [ "$QUIET" = true ]; then` — i.e. only the cron path is protected
- Cron entry at `audit.sh:91` already uses `--cron` (which sets QUIET), so production cron is fine
- Foreground audits run unguarded — exactly the OBS-016 incident pattern
- 22-process chain depth suggests a multiplicative effect (likely audit's trend-analysis step re-invoking itself), but the *trigger* is the unguarded concurrent case

## Recommendation

**GO with scoped Phase 1 fix** (lift the QUIET-only flock guard, ~5 LoC change), then DEFER Phase 2 (trend-analysis self-spawn RCA) until repro is captured.

**Rationale:** The concrete structural gap at audit.sh:306 is small, mechanical, and addresses the *first* domino in the chain. Even if Phase 2 (a self-spawn loop) is also present, removing the precondition for chains to start at all collapses the failure surface to "single audit may stall". Bounded, testable (one synthetic concurrent test), and reversible. Costs nothing to land before the more expensive RCA.

**Evidence:**
- audit.sh:306 confirms flock guard is conditional on `$QUIET = true` only
- OBS-016 timeline: foreground agent investigation ran while T-1441 verification gate ran another audit — exactly the unprotected case
- 22-process chain is multiplicative, but structurally preventable today

**Out-of-scope:**
- Phase 2 self-spawn mechanism (needs fresh repro under tracing)
- Refactoring post-commit / pre-push hook audit invocation chain

## Outcome

Build task T-1464 lifted the QUIET-only flock guard and added a watchdog FD detach (closed 2026-04-25). 14 audits in 14 days post-fix, no recursive-spawn observed; `bin/fw audit --quiet` returns rc=0.
