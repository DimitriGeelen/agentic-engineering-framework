---
id: T-3070
name: "Full fw audit cannot complete: single process-wide lock contends with cron
  section runs"
description: >
  A full (all-section) 'fw audit' run takes long enough that it never wins the shared
  .context/locks/audit.lock against structural-30m/traceability-hourly/observations-6h/oe-*
  cron jobs, which each acquire the SAME internal audit.sh lock regardless of --section
  (cron's own /var/lock/agentic-cron-*.lock files are per-section-group and don't
  prevent this). Confirmed independently twice on T-1719 (2026-08-17): first attempt
  exit 75 'another audit already running' (cron holding lock), second attempt (lock
  free at start) ran 590s under timeout and was killed mid-run (exit 124) before reaching
  the SUMMARY section — output stopped after EPISODIC MEMORY CHECKS with no verdict.
  This makes 'fw audit clean' unusable as a task Acceptance Criterion anywhere, and
  makes the pre-push audit gate (OBS-221/T-2930 area, agents/git/lib/hooks.sh:915)
  contend against cron with no Tier-2 escape, only Tier-0 --no-verify. Candidate fixes
  noted by prior investigation: (a) full-audit mode takes a distinct lock from per-section
  cron runs, (b) full-audit retries/waits across cron gaps instead of failing immediately,
  (c) full-audit runs sections that don't overlap with in-flight cron sections first.
  Root-caused in T-1719 Evolution log (2026-08-17 entries) and .context/inbox.yaml
  (OBS-221-adjacent entry, 'PRE-PUSH AUDIT GATE CAN DEADLOCK AGAINST CRON AUDIT PILEUP').

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [audit, lock-contention, cron, verification-gate]
components: [C-004, bin/fw]
related_tasks: [T-1719, T-2930, T-860, T-862]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-17T13:20:32Z
last_update: 2026-08-24T18:14:04Z
date_finished: 2026-08-24T18:14:04Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-08-17T13:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-17T13:30:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-18T13:30:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-23T19:30:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3070: Full fw audit cannot complete: single process-wide lock contends with cron section runs

## Context

Two candidate root causes, not yet disentangled by T-1719's three prior attempts:
1. **Lock-acquisition contention** against cron section jobs sharing the same
   `.context/locks/audit.lock`, sharpened by an actual **schedule collision**:
   `full-daily` fires `0 8 * * *`, the same minute as `structural-30m`
   (`*/30 * * * *`) and `traceability-hourly` (`0 * * * *`) — three cron jobs
   racing for the same lock in the same minute is not bad luck, it's the
   registry (`.context/cron-registry.yaml`).
2. **Raw runtime**, independent of contention: `AUDIT_TIMEOUT` (`agents/audit/audit.sh:340`,
   default 600s) may be too short for a full run regardless of who holds the
   lock. T-1719's third attempt (uncontended lock, `timeout 590`) was still
   inside `EPISODIC MEMORY CHECKS` — section 10 of 27 (`grep -n 'echo "=== '
   agents/audit/audit.sh`) — when killed, with `WHOLE-TREE SCANS` alone
   already measured at ~283s per the T-3062 comment at `audit.sh:2327-2341`.

**Scope correction from filing:** the pre-push audit gate
(`agents/git/lib/hooks.sh:910`, T-862) runs a **fast section subset**, not a
full audit — production pushes are not blocked by full-run *runtime*, only by
occasional brief lock contention that self-resolves on retry. The severity is
lower than the original description implied; the primary blocked consumer is
`fw audit clean` as a task AC (T-1719 A6/A6b), not the push path.

**Root cause disentangled (2026-08-23):** BOTH candidates were real,
independently. (1) `AUDIT_TIMEOUT` was too short for a full run regardless of
contention — fixed by giving full runs (SECTIONS empty) their own larger
default (`FW_AUDIT_FULL_TIMEOUT`, 3000s vs the section-scoped 600s;
`agents/audit/audit.sh:341-355`, pinned by
`tests/unit/t3070_audit_full_run_timeout.bats`). (2) The schedule collision
was real AND wider than filed: `full-daily` (`0 8 * * *`) exactly collided
with `traceability-hourly` (`0 * * * *`) at 8:00 daily, and three MORE
undetected collisions existed on the same shared flock —
`observations-6h`/`oe-daily`/`oe-weekly` each also fired at `:00`, colliding
with `traceability-hourly`'s every-hour `:00` trigger. `structural-30m` had
already been offset to `5,35` for the same class before this task started.
Fixed by offsetting all four remaining `:00`-aligned jobs
(`.context/cron-registry.yaml`); pinned generically (not just the four known
pairs) by `tests/lint/audit-lock-cron-schedule-collision.bats`, which expands
every active `fw audit`-invoking job's 5 cron fields and fails on ANY pair
that can fire the same absolute minute.

**Structural finding beyond the filed scope (OBS-249):** deploying the
schedule fix surfaced a second, more serious bug — `agents/audit/audit.sh
schedule install` was an independent, hardcoded-template generator for the
SAME git-tracked crontab source file that `fw cron generate`/`fw cron
install` (T-1112/T-1114) already own, and it silently reverted this task's
registry-driven fixes minutes after they were correctly generated (`fw cron
generate`'s own success message even recommends the broken command). Fixed
by making `audit.sh schedule install` delegate to `fw cron install` when a
registry exists (`agents/audit/audit.sh` install case); the hardcoded
template now only serves pre-T-448 consumer projects with no registry.
Pinned by `tests/unit/t3070_audit_schedule_install_delegates_to_registry.bats`.
See OBS-249 for the full RCA.

**Diagnostic run in progress (2026-08-17T14:09:15Z, superseded — see live
ground-truth run below):** launched a fully
detached `fw audit` (`nohup ... & disown`, no external timeout, lock
confirmed free at start) to get ground-truth timing before choosing a fix
shape — PID 4115033, output at
`.context/working/t1719-full-audit-diagnostic.log`. Before repeating this
experiment, check whether that log reached `=== SUMMARY ===` and how long it
took (`grep -c '^=== ' <log>` against the 27 section headers, or just diff
mtime vs the `AUDIT REPORT` header timestamp).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Ground truth established: actual wall-clock time for an uncontended,
  un-killed full `fw audit` run to reach `=== SUMMARY ===` (or confirmation it
  never does within a generous bound, e.g. 2400s)
- [x] Root cause disentangled: confirm/refute whether `AUDIT_TIMEOUT=600s` alone
  (independent of lock contention) is insufficient for a full run on this corpus
- [x] Fix implemented for at least one of: (a) cron schedule collision at
  minute 0 in `.context/cron-registry.yaml` / `agents/audit/audit.sh` crontab
  block, (b) distinct lock or larger timeout budget for full vs section-scoped
  runs
- [x] `fw audit` (full run, no `--section`) completes and reaches
  `=== SUMMARY ===` without external or internal timeout kill, verified live
- [x] Regression coverage for the fix; `fw doctor` clean re: cron registry sync
  if `.context/cron-registry.yaml` is touched (CLAUDE.md cron-touching
  verification rule)

## Result (measured 2026-08-24)

**The full audit completes. It always could.** Uncontended, un-killed, no
`--section`: **1705s to `=== SUMMARY ===`, 1729s to `=== END AUDIT ===`, exit 0.**
No external or internal timeout kill. Run under a 2400s ceiling, well inside the
3000s full-run default — 58% of budget.

| Section | Wall-clock | Share |
|---|---:|---:|
| OE-DAILY: DAILY CONTROL CHECKS | **824s** | **48%** |
| WHOLE-TREE SCANS | 256s | 15% |
| GRADUATION PIPELINE CHECKS | 147s | 9% |
| GIT TRACEABILITY CHECKS | 132s | 8% |
| STRUCTURE CHECKS | 89s | 5% |
| ENFORCEMENT CHECKS | 82s | 5% |
| EPISODIC MEMORY CHECKS | 71s | 4% |
| all remaining | ≤29s each | |

Derived from per-line timestamps; the audit emits no native timing, which is
itself worth fixing one day.

## RCA

**Symptom:** a full `fw audit` never reached `=== SUMMARY ===`, and the standing
explanation was lock contention with cron.

**That explanation is wrong, and the measurement says so precisely.** Prior
T-3070 evidence had the run dying at 12/28 sections, mid EPISODIC MEMORY, at
590s. This run reached EPISODIC MEMORY CHECKS at **593s** — the same place, three
seconds apart — and then kept going to completion. The run was never being
starved of a lock. It was being killed by the **600s section-scoped timeout**
applied to a full run that legitimately needs ~1700s.

**Why the wrong cause was believable for so long:** cron *does* run audits, a
process-wide lock *does* exist, and `fw audit` *did* fail — three true facts that
compose into a plausible story with no step that requires checking. Lock
contention is also the more interesting hypothesis, so it got adopted without a
measurement that would separate it from the boring one. Nobody ever timed an
uncontended run, which is the single observation that distinguishes them; the
task carried "establish ground truth" as AC1 from the start and it stayed
unticked longest.

**What was actually broken, and is now fixed (commit d4787e61b):** a genuine
second defect found along the way — `fw audit schedule install` and `fw cron
install` were two independent generators writing the same git-tracked file, one
from a hardcoded heredoc and one from `.context/cron-registry.yaml`. Running the
former after editing the registry silently reverted every registry-sourced
schedule fix. Confirmed live: three collision fixes reverted in one call. That is
real and unrelated to the timeout — the contention hypothesis was not baseless,
it was aimed at the wrong symptom.

**Prevention:** the two committed regression tests pin the delegation and the
collision rule. The remaining exposure is that no check asserts a full-run
timeout budget is adequate for the corpus it must scan — the budget is a constant
and the corpus grows. At 1729s against a 3000s default, that headroom is 42% and
shrinking. Filed as a follow-up rather than fixed here.

**Correction on the measurement itself:** the dispatch prompt specified
`AUDIT_TIMEOUT=2400`. `audit.sh` reads `FW_AUDIT_TIMEOUT` / `FW_AUDIT_FULL_TIMEOUT`
— the bare name is inert. The worker caught it and used the right variable. Had
it not, the run would have silently used the default and the reported ceiling
would have been fiction: a measurement that looks controlled and is not.

## Verification

bats tests/unit/t3070_audit_schedule_install_delegates_to_registry.bats > /tmp/.t3070a.out 2>&1 && grep -q "^ok 4 " /tmp/.t3070a.out && ! grep -q "^not ok" /tmp/.t3070a.out
bats tests/lint/audit-lock-cron-schedule-collision.bats > /tmp/.t3070b.out 2>&1 && grep -q "^ok 1 " /tmp/.t3070b.out && ! grep -q "^not ok" /tmp/.t3070b.out
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync" && ! echo "$out" | grep -q "Cron registry edited but not generated"
bin/fw cron list > /tmp/.t3070c.out 2>&1 && ! grep -E 'audit|oe-|traceability|observations' /tmp/.t3070c.out | grep -q 'paused'

## Reviewer Verdict (v1.5)

- **Scan ID:** R-95364734
- **Timestamp:** 2026-08-24T18:18:05Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `bin/fw cron list > /tmp/.t3070c.out 2>&1 && ! grep -E 'audit|oe-|traceability|observations' /tmp/.t3070c.out | grep -q 'paused'`

### 2026-08-24T18:14:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
