---
id: T-1690
name: "v1 Outcome enrichment hook + task-completion back-propagation into dispatches.jsonl"
description: >
  v1 implementation of the post-dispatch outcome evaluator and the task-lifecycle back-propagation. Per CONTEXT.md+ADR-0003: workflows declare optional outcome_evaluator script; default evaluator checks Verification+Agent ACs; when a task transitions to work-completed/issues AFTER a dispatch ran for it, resolver back-fills task_completion_outcome into the matching dispatches.jsonl rows. Couples task lifecycle (Agent slice 1) to dispatch telemetry (Agent slice 3). Inception because the coupling needs careful scoping.

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: [arc:orchestrator-rethink, telemetry]
components: []
related_tasks: [T-1687]
created: 2026-05-02T22:55:57Z
last_update: 2026-05-02T22:55:57Z
date_finished: null
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
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
-->

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
