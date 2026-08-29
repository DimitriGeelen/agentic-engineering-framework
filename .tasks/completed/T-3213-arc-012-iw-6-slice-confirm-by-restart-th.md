---
id: T-3213
name: "arc-012 IW-6 slice: confirm by restart that the continuous-run ledger is empty
  only because the live supervisor predates T-3206"
description: >
  Build slice propagating T-3181's GO (2026-08-27). IW-6 was narrowed but never confirmed:
  the discrimination against T-3206 showed the ledger has no start event because the
  running claude-fw supervisor (pid 1851680) was launched before the recorder existed,
  and T-3209 made fw doctor say so instead of blaming the operator. What was NOT done
  is the confirming experiment - restart claude-fw and verify a start event actually
  appears. Until that runs, the explanation is the best-supported hypothesis and not
  a measured fact, which is the exact distinction T-3209 exists to enforce. AC shape:
  restart the wrapper, assert the ledger gains a start event, and assert fw doctor
  flips from the SKIP branch to a recorded state. If it does NOT appear, the second
  cause named in T-3209 (recorder could not write) is live and this becomes a real
  bug.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
arc_id: continuous-run
components: []
related_tasks: []
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
created: 2026-08-29T10:18:58Z
last_update: 2026-08-29T15:06:34Z
date_finished: 2026-08-29T15:06:34Z
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
  - ts: '2026-08-29T10:30:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=235,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-29T10:30:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-29T15:01:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3213: arc-012 IW-6 slice: confirm by restart that the continuous-run ledger is empty only because the live supervisor predates T-3206

## Context

IW-6 of T-3181's GO. T-3206 added a `start` event to `bin/claude-fw` so the loop
could say it is ARMED, not only why it stopped. T-3209 then made `fw doctor`
attribute an absent ledger to a *supervisor that predates the recorder* rather
than to the operator having never armed it.

Both shipped on the strength of an explanation that was never confirmed. The
numbers behind it, re-measured at the head of this task:

| fact | measured |
|---|---|
| `.context/working/continuous-run.jsonl` | ABSENT |
| `_record_loop_event start armed` (bin/claude-fw:273) | landed `b072d815f`, 2026-08-28 16:14 |
| live supervisor pid 1851680 | started 2026-08-27 10:52, still alive |

The supervisor predates its own recorder by ~29 hours, so the explanation is
consistent with every observation. That is exactly what makes it dangerous:
T-3209's own reason for existing is the distinction between a supported
hypothesis and a measured fact, and it was itself shipped on the former.

**Why this is not "restart claude-fw".** The wrapper named in the hypothesis is
the supervisor of the session doing the work; restarting it ends the observer.
The confirming experiment is instead a real `bin/claude-fw` invocation in a
scratch git repo with a stubbed `claude` on PATH. `_record_loop_event` resolves
its log via `git rev-parse --show-toplevel`, so the scratch repo gets its own
ledger and the live one stays untouched. Same shipped code path, no destruction.

If the start event does NOT appear, the second cause T-3209 names (the recorder
cannot write) is live and this becomes a bug report rather than a confirmation.

## Acceptance Criteria

### Agent
- [x] A real `bin/claude-fw` run in a scratch git repo writes a `start` event with `reason=armed` to that repo's `.context/working/continuous-run.jsonl` — the confirming experiment T-3206 shipped without.
- [x] The same run also writes a terminal `exit` event, so "armed then exited" is distinguishable on disk from "never armed".
- [x] The start event carries the wrapper pid and restart configuration, so a future absent-ledger claim can be checked against a live process rather than re-argued.
- [x] `fw doctor` reports the ARMED branch against a ledger holding that start event, and the never-recorded branch against an absent one — the flip the hypothesis predicts.
- [x] MUTATION CONTROL: with the `_record_loop_event start` call site removed from a copy of the shipped wrapper, the ledger gains no start event and doctor falls back to the never-recorded branch. Proves the assertions above track that call site.
- [x] T-3209's second cause is discriminated, not assumed absent: a run whose ledger directory cannot be written produces no ledger AND leaves the wrapper's exit code unchanged.
- [x] The task record states plainly whether the predates-the-recorder explanation is now a measured fact or still a hypothesis.


## Verification

timeout 300 bats tests/unit/t3213_start_event_confirmation.bats > /tmp/.t3213.out 2>&1 && grep -q "^ok 10" /tmp/.t3213.out && ! grep -q "^not ok" /tmp/.t3213.out
timeout 300 bats tests/unit/t3206_continuous_run_ledger.bats > /tmp/.t3206.out 2>&1 && ! grep -q "^not ok" /tmp/.t3206.out
timeout 300 bats tests/unit/t3209_loop_ledger_cause_attribution.bats > /tmp/.t3209.out 2>&1 && ! grep -q "^not ok" /tmp/.t3209.out
timeout 300 bats tests/unit/t3212_human_gate_stop.bats > /tmp/.t3212.out 2>&1 && ! grep -q "^not ok" /tmp/.t3212.out
grep -q '_record_loop_event start armed' bin/claude-fw
python3 tools/bats-dead-negation-lint.py tests/unit/t3213_start_event_confirmation.bats
test ! -f .context/working/continuous-run.jsonl || grep -q '"event"' .context/working/continuous-run.jsonl


## Decisions

### 2026-08-29 — the confirming experiment does not restart the live supervisor

- **Chose:** run the shipped `bin/claude-fw` in a scratch git repo with a stubbed
  `claude` on PATH. `_record_loop_event` resolves its log through `git rev-parse
  --show-toplevel`, so the scratch repo gets its own ledger.
- **Why:** the wrapper named in the hypothesis (pid 1851680) supervises the session
  doing the work. Restarting it ends the observer, and the operator's session with it.
  The scratch run exercises the identical code path — line 273 fires once, before the
  loop, so nothing about the real session is needed to reach it.
- **Rejected:** pointing the experiment at PROJECT_ROOT. It would have created the very
  ledger whose absence is the evidence, and left `fw doctor` reporting ARMED for a
  wrapper supervising nothing — manufacturing the exact false green arc-012 exists to
  kill. Every run in the suite is confined to `BATS_TEST_TMPDIR`.
- **Rejected:** asserting against a hand-written ledger fixture. That proves doctor
  parses what the TEST believes the wrapper emits. Test 9 sources its fixture from an
  actual wrapper run instead, because the producer/consumer join is where this class
  of defect lives (L-399).

### 2026-08-29 — `chmod 500` was replaced because it SKIPPED rather than failed

- **Chose:** make the ledger PATH a directory, so `open(..., "a")` raises
  `IsADirectoryError`.
- **Why:** the first version denied writes with `chmod 500` and guarded it with
  `skip` when running as root. This suite runs as root on the origin host, so that
  test asserted nothing on every run that mattered — a skipped test and an inert
  one are the same thing from the report's point of view. A directory at the path
  denies root and non-root alike.
- **Rejected:** dropping the AC. T-3209 names two causes for an absent ledger and
  this is the second; leaving it unmeasured would repeat the shape this task exists
  to close.

## Findings

**The predates-the-recorder explanation is now a MEASURED FACT, not a hypothesis.**

Measured this session:

| step | result |
|---|---|
| shipped `bin/claude-fw` invoked in a scratch repo | writes `{"event":"start","reason":"armed",...}` |
| same run | writes terminal `{"event":"exit","reason":"auto-restart-disabled"}` |
| `_record_loop_event start armed` introduced | `b072d815f`, 2026-08-28 16:14 |
| live supervisor pid 1851680 launched | 2026-08-27 10:52 — **29h earlier** |
| `.context/working/continuous-run.jsonl` | still ABSENT |

The recorder demonstrably writes when invoked, so the absence of a live ledger is
explained by the supervisor predating the call site rather than by a recorder that
cannot write. T-3209's SECOND cause is separately excluded for the normal case by
test 6: when the path genuinely cannot be appended to, no record appears **and the
wrapper's exit code is unchanged** — the non-fatal contract holds.

**Scope limit, stated rather than glossed.** This confirms the recorder works in a
scratch repo, not that it would write *into this repo*. Proving the latter requires
writing the real ledger, which destroys the evidence. `.context/working/` here is
present and writable, which is consistent with the explanation but is not the same
measurement — and the honest distinction between those two is the whole point of
T-3209.

**Residual, not closed by this task.** The live ledger stays absent until pid 1851680
is replaced. That happens on the operator's next `claude-fw` restart, at which point
`fw doctor` should flip from the two-cause WARN to `OK … last recorded ARMED`. Nothing
here forces that restart, and nothing should.


## Updates

### 2026-08-29T10:18:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3213-arc-012-iw-6-slice-confirm-by-restart-th.md
- **Context:** Initial task creation

### 2026-08-29T15:01:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-401d332e
- **Timestamp:** 2026-08-29T15:06:51Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 7
     - evidence: `test ! -f .context/working/continuous-run.jsonl || grep -q '"event"' .context/working/continuous-run.jsonl`

### 2026-08-29T15:06:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
