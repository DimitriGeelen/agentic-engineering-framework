---
id: T-1690
name: "v1 Outcome enrichment hook + task-completion back-propagation into dispatches.jsonl"
description: >
  v1 implementation of the post-dispatch outcome evaluator and the task-lifecycle
  back-propagation. Per CONTEXT.md+ADR-0003: workflows declare optional outcome_evaluator
  script; default evaluator checks Verification+Agent ACs; when a task transitions
  to work-completed/issues AFTER a dispatch ran for it, resolver back-fills task_completion_outcome
  into the matching dispatches.jsonl rows. Couples task lifecycle (Agent slice 1)
  to dispatch telemetry (Agent slice 3). Inception because the coupling needs careful
  scoping.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: [telemetry]
components: []
related_tasks: [T-1687]
arc_id: orchestrator-rethink
created: 2026-05-02T22:55:57Z
last_update: '2026-06-11T22:23:56Z'
date_finished: 2026-05-03T08:29:11Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
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
---

# T-1690: v1 Outcome enrichment hook + task-completion back-propagation into dispatches.jsonl

## Problem Statement

`dispatches.jsonl` records `exit_code` per dispatch but that is a thin signal. v2 self-improvement (ADR-0003) needs to know whether the WORK actually succeeded — did Verification pass, were all Agent ACs ticked, did the human accept the result, did a follow-up bug get filed within N days? Without back-prop, the v2 learner sees only short-horizon outcomes. This inception scopes (a) the default `outcome_evaluator`, (b) the back-prop hook from task-status transitions to `dispatches.jsonl` rows, (c) atomicity guarantees for JSONL modify-in-place under concurrency.

## Assumptions

- A-1: Default evaluator (Verification passed + all `### Agent` ACs ticked) is sufficient signal for ~80% of workflows.
- A-2: Custom evaluators emit JSON to stdout: `{verification_passed, ac_satisfied, quality_score, notes}`.
- A-3: JSONL modify-in-place via rewrite-then-rename is safe under typical dispatch concurrency (≤5 parallel).
- A-4: `update-task.sh` can call the back-prop function without circular dependency on the Resolver (T-1689).

## Exploration Plan

- Spike S-1 (½ sess): default evaluator integration with T-1689 resolver — dispatch a fake worker, run evaluator, verify outcome fields land in JSONL row.
- Spike S-2 (½ sess): back-prop hook — make a dispatch, complete the task via `fw task update`, verify `task_completion_outcome` back-fills the row matching `dispatch_id`.
- Spike S-3 (½ sess): concurrency stress — fire 5 parallel dispatches, complete them in random order, verify zero JSONL corruption.

## Technical Constraints

- Custom evaluator scripts run under operator authority (no sandboxing in v1) — operator-curated, not arbitrary input.
- Back-prop hook fires inside `update-task.sh`, which is called frequently — must be cheap (<10ms when no matching dispatch).
- JSONL files can grow large (~MB by month-end); modify-in-place must scan efficiently or use an index.

## Scope Fence

- IN: `outcome_evaluator` workflow field; default evaluator (Verification + Agent ACs); back-prop hook in `update-task.sh`; atomic JSONL modify-in-place; `dispatch_id ↔ task_id` index for fast row lookup; `task_completion_outcome` field write.
- OUT: ML-based quality scoring (v2 learner); evaluator sandboxing/security (operator-curated); cross-task outcome aggregation analysis (v2); SQLite migration (v2 if v1 stress reveals JSONL is the bottleneck).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Default evaluator + back-prop both work end-to-end with T-1689 resolver
- Concurrency stress (5 parallel dispatches, randomized completion order) produces zero JSONL corruption
- No measurable latency regression on dispatch path (<5ms overhead per dispatch)
- Back-prop hook adds <10ms to `update-task.sh` when no matching dispatch exists

**NO-GO if:**
- JSONL modify-in-place is unsafe under typical concurrency (forces SQLite migration into v1, expanding scope)
- Back-prop hook creates a circular dependency between resolver and update-task.sh
- Default evaluator misses critical signals for >50% of workflows (signal that the evaluator interface needs richer design before v1 ships)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO — with a design adjustment to the storage model

**Rationale:** Default evaluator works (282ms to parse + run all Verification commands for T-1693, 6/6 Agent ACs detected as satisfied). Back-prop hook is fast on the unmatched path (0.3ms — far below the 10ms NO-GO threshold). Spike passes all functional tests. **Critical finding:** the modify-in-place pattern that T-1689 validated for *single-row* updates does NOT compose under cross-row concurrency — when two back-props run in parallel on different task_ids, the second rename overwrites the first writer's enrichments (last-writer-wins at the FILE level, not the row level). Spike measured 15/50 enrichments preserved when 10 threads enriched distinct task_ids concurrently. This is a CHANGE from T-1689's sub-spike A-5, which only proved no-corruption — not no-overwrite.

**Design adjustment (proposed):** split storage. Keep `dispatches.jsonl` append-only for the dispatch row itself; write outcomes to a separate append-only file `.context/dispatch-outcomes.jsonl` keyed by dispatch_id. v2 read-path joins. This eliminates the last-writer-wins exposure entirely AND keeps both files monotone (simpler rotation + simpler rsync semantics + no rewrite-then-rename code path needed).

**Evidence:**
- `docs/reports/T-1690-spikes/eval_backprop_spike.py`: ALL CHECKS PASS
- Default evaluator: 282ms for T-1693 (8 verification commands run live), correctly identifies `verification_passed=True`, `ac_checked=6/6`
- Back-prop matches by task_id: 3/3 rows enriched, 0.5ms
- Unmatched-task-id back-prop: 0.3ms (NO-GO threshold >10ms — ~33× headroom)
- Concurrent back-prop (10 threads, distinct task_ids, 5 rows each): 50/50 rows preserved (no corruption — T-1689 A-5 inheritance held), but only 15/50 enriched (last-writer-wins on FILE rename)
- Evaluator runs ONCE per task completion (not per dispatch); per-dispatch overhead is back-prop only (~0.5ms)

**v1 build task scope (to file after GO):**
1. Implement the default evaluator as a Python module loaded by `lib/resolver.py`
2. **Design adjustment:** outcomes write to `.context/dispatch-outcomes.jsonl` (append-only) rather than modifying `dispatches.jsonl` in place
3. Resolver-side: when emitting a dispatch row, leave `task_completion_outcome` field absent (not "pending"); v2 read path joins
4. Hook in `update-task.sh`: on transition to `work-completed` or `issues`, run evaluator → append outcome row keyed by task_id (resolver provides dispatch_id index lookup)
5. `outcome_evaluator` workflow field: invokes external script when set, falls back to default
6. Custom evaluator contract: stdout JSON `{verification_passed, ac_satisfied, quality_score?, notes?}`
7. Index for fast lookup: small in-memory dict `task_id → [dispatch_ids]` rebuilt on first access; rebuild cost amortizes to ~0 for typical task volumes
8. Stress test: 50 concurrent back-props, all distinct task_ids — must produce 50/50 enrichments (proves the design adjustment works)

**Caveats:**
- Evaluator latency depends on the task's Verification commands. T-1693 took 282ms. Tasks with `dotnet build` or `playwright` Verification could be 30s+ — that's acceptable because the evaluator runs ONCE on task completion, not per dispatch.
- Custom evaluators run unsandboxed (operator authority) — same trust model as Verification blocks. v1 ships as-is; sandboxing is a separate concern (T-558 territory).
- The proposed split (`dispatch-outcomes.jsonl`) is a design CHANGE from the original ADR-0003 schema which had `task_completion_outcome` inline in `dispatches.jsonl`. ADR-0003 should be amended at v1 build time to reflect the split.

## Decisions

### 2026-05-03 — Storage model for outcomes (modify-in-place vs separate append-only file)

- **Chose:** Separate `dispatch-outcomes.jsonl` (append-only).
- **Why:** Spike caught last-writer-wins corruption when concurrent back-props for *different* task_ids race at the FILE level. The fix isn't another atomicity primitive (T-1689 already proved per-call unique tmp prevents JSON corruption — that's row-level). The fix is to stop modifying in place. Append-only files compose under any concurrency. v2 self-improvement does read-side joins, which is cheap for monthly-rotated logs.
- **Rejected:** Application-level mutex/lockfile — adds operational complexity, doesn't help v2's offline read path, doesn't survive cross-process concurrency cleanly. Rejected SQLite migration — premature for v1; would force a schema migration if outcomes evolve.

### 2026-05-03 — Default evaluator scope (Verification + Agent ACs vs richer signal)

- **Chose:** Verification + Agent ACs only for v1 default.
- **Why:** Both signals are already required by framework gates (P-010 + P-011). Free-rider on existing structure. Custom evaluators slot in for workflows that need richer signals (e.g., diff size, regression test pass rate) without forcing every workflow to provide one.
- **Rejected:** Including Reviewer Verdict / handover-mention / commit-message-quality in the default — coupling to subsystems that aren't yet stable; better to let custom evaluators opt in.

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

**Rationale**: Default evaluator works (282ms to parse + run all Verification commands for T-1693, 6/6 Agent ACs detected as satisfied). Back-prop hook is fast on the unmatched path (0.3ms — far below the 10ms NO-GO threshold). Spike passes all functional tests. **Critical finding:** the modify-in-place pattern that T-1689 validated for *single-row* updates does NOT compose under cross-row concurrency — when two back-props run in parallel on different task_ids, the second rename overwrites the first writer's enrichments (last-writer-wins at the FILE level, not the row level). Spike measured 15/50 enrichments preserved when 10 threads enriched distinct task_ids concurrently. This is a CHANGE from T-1689's sub-spike A-5, which only proved no-corruption — not no-overwrite.

**Date**: 2026-05-03T08:29:11Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-03T08:15:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-03T08:29:11Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Default evaluator works (282ms to parse + run all Verification commands for T-1693, 6/6 Agent ACs detected as satisfied). Back-prop hook is fast on the unmatched path (0.3ms — far below the 10ms NO-GO threshold). Spike passes all functional tests. **Critical finding:** the modify-in-place pattern that T-1689 validated for *single-row* updates does NOT compose under cross-row concurrency — when two back-props run in parallel on different task_ids, the second rename overwrites the first writer's enrichments (last-writer-wins at the FILE level, not the row level). Spike measured 15/50 enrichments preserved when 10 threads enriched distinct task_ids concurrently. This is a CHANGE from T-1689's sub-spike A-5, which only proved no-corruption — not no-overwrite.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-85bd41cb
- **Timestamp:** 2026-06-02T14:59:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-03T08:29:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
