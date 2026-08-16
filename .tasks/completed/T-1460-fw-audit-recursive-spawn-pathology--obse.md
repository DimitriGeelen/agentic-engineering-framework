---
id: T-1460
name: "fw audit recursive-spawn pathology — observed during T-1441 close. Concurrent
  audit invocations (one in foreground from agent investigation + one inside T-1441's
  verification gate) caused audit.sh to spawn nested audit.sh children at ~1/min for
  5+ minutes (saw 22 audit processes, parent-child chain 6+ levels deep). Each child
  appeared to be the audit re-running itself, possibly via the post-commit detector
  or a subshell loop in audit.sh's trend-analysis step. Killed manually with pkill
  -KILL. Need to investigate: does audit.sh fork itself? Does it lock to prevent concurrent
  runs? Should it?"
description: >
  Promoted from observation OBS-016

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-25T13:52:39Z
last_update: '2026-08-16T22:24:33Z'
date_finished: 2026-04-25T14:01:48Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1460: fw audit recursive-spawn pathology — observed during T-1441 close. Concurrent audit invocations (one in foreground from agent investigation + one inside T-1441's verification gate) caused audit.sh to spawn nested audit.sh children at ~1/min for 5+ minutes (saw 22 audit processes, parent-child chain 6+ levels deep). Each child appeared to be the audit re-running itself, possibly via the post-commit detector or a subshell loop in audit.sh's trend-analysis step. Killed manually with pkill -KILL. Need to investigate: does audit.sh fork itself? Does it lock to prevent concurrent runs? Should it?

## Problem Statement

**For whom:** the operator running `fw audit` from a session, plus any commit hook or pre-push hook chain that re-runs audit. **What problem:** observed during T-1441 close — concurrent audit invocations (one foreground from agent investigation, one inside T-1441's verification gate) caused `audit.sh` to accumulate 22 processes, parent-child chain 6+ levels deep, ~1 spawn/min for 5+ minutes. Killed manually with `pkill -KILL`. **Why now:** every session today triggered 2-3 audits via push hooks; the pathology can recur any time two audits race.

## Audit findings (this session)

**Concrete structural gap (audit.sh:306):**
```bash
if [ "$QUIET" = true ]; then
    # ... flock guard, timeout, lock-file cleanup ...
fi
```

The flock guard ONLY runs in `--quiet`/`--cron` mode. **Foreground (interactive) audits have NO concurrency guard at all.** That means:
- Two foreground audits can run simultaneously
- A pre-push-hook audit running while an agent-invoked audit is mid-flight has zero protection
- The `0 * * * *` cron audit is guarded against itself but NOT against any foreground caller

**Probable secondary cause (not yet RCA'd):** the trend-analysis section (`should_run_section "discovery-trends"` ~line 2242) reads prior audit YAMLs. If it shells out, recurses, or triggers a cron schedule install, that's a candidate for the "child-spawn" leg of the chain. A handover commit can also fire a post-commit hook that reruns audit.

## Hypotheses to test

1. **Foreground-flock hypothesis:** Lifting the `if [ "$QUIET" = true ]` guard so flock applies to ALL audits prevents the concurrent collision that started the chain. Test: synthetic — run `fw audit` twice in parallel, observe second exits cleanly.
2. **Trend-analysis recursion hypothesis:** The 1/min spawn cadence and 6-level depth suggest something keeps re-invoking audit. Test: trace audit.sh under `set -x` for the trend-analysis section; look for `audit.sh`, `fw audit`, or `cron` self-references.
3. **Hook-chain hypothesis:** post-commit / pre-push hooks re-run audit on every commit; a handover-commit storm (G-016-class) would saturate them. Test: count audit re-entries triggered by a single `git commit` under a handover scenario.

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
- [x] Problem statement validated (audit.sh:306 confirmed)
- [x] Concrete structural gap identified (foreground audits unguarded)
- [x] Hypotheses + Recommendation written

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO with **scoped Phase 1 fix** (lift the QUIET-only flock guard, ~5 LoC change), then DEFER Phase 2 (trend-analysis RCA) until repro is captured.

**Rationale:** The concrete structural gap at audit.sh:306 is small, mechanical, and addresses the *first* domino in the chain (concurrent audits). Even if Phase 2 (a self-spawn loop) is also present, removing the precondition for chains to start at all collapses the failure surface to "single audit may stall". This is bounded, testable (one synthetic concurrent test), and reversible. It costs nothing to land before the more expensive RCA.

**Evidence:**
- audit.sh:306 confirms flock guard is conditional on `$QUIET = true` only.
- Cron entry at audit.sh:91 already uses `--cron` (which sets QUIET), so production cron is protected; foreground is the gap.
- OBS-016 incident timeline: foreground agent investigation ran while T-1441 verification gate ran another audit — exactly the unprotected concurrent case.
- The 22-process chain depth suggests a multiplicative effect, but the *trigger* (two unguarded audits at once) is structurally preventable today.

**Out-of-scope:**
- Decoding the actual self-spawn mechanism (Phase 2): needs fresh repro under tracing, which OBS-016 explicitly couldn't reproduce on demand.
- Refactoring the post-commit / pre-push hook audit invocation chain (a separate concern).


## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: The concrete structural gap at audit.sh:306 is small, mechanical, and addresses the *first* domino in the chain (concurrent audits). Even if Phase 2 (a self-spawn loop) is also present, removing the precondition for chains to start at all collapses the failure surface to "single audit may stall". This is bounded, testable (one synthetic concurrent test), and reversible. It costs nothing to land before the more expensive RCA.

**Date**: 2026-04-25T14:01:48Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-25T14:01:48Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The concrete structural gap at audit.sh:306 is small, mechanical, and addresses the *first* domino in the chain (concurrent audits). Even if Phase 2 (a self-spawn loop) is also present, removing the precondition for chains to start at all collapses the failure surface to "single audit may stall". This is bounded, testable (one synthetic concurrent test), and reversible. It costs nothing to land before the more expensive RCA.

### 2026-04-25T14:01:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3aca06e8
- **Timestamp:** 2026-06-02T14:57:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T14:01:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
