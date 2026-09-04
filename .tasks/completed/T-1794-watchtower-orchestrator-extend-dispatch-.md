---
id: T-1794
name: "Watchtower /orchestrator: extend Dispatch substrate panel with by_task_type
  breakdown"
description: >
  Watchtower /orchestrator: extend Dispatch substrate panel with by_task_type breakdown

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [web, observability]
components: []
related_tasks: [T-1792, T-1788]
arc_id: orchestrator-rethink
created: 2026-05-12T21:25:20Z
last_update: 2026-09-03T23:55:24Z
date_finished: 2026-05-12T21:27:54Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 3
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F1=0 (no-signal); F2=0
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 3
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1794: Watchtower /orchestrator: extend Dispatch substrate panel with by_task_type breakdown

## Context

T-1792 added the Dispatch substrate panel to `/orchestrator` with the
`by_model` breakdown (real-dispatch total + per-model counts). Its
Evolution log named the next two siblings: `by_task_type` and
`by_worker_kind`. This slice ships the first of those — by_task_type —
because it answers a different operator question than by_model:

- **by_model** (T-1792): "what's the model mix?" — answers routing decisions.
- **by_task_type** (this): "what kind of work is the orchestrator doing?" — answers workload mix.

Same `_dispatch_substrate()` helper extended to count by `task_type` in
addition to `model`. Same synthetic exclusion. Same template panel
extended with a second sub-table.

## Acceptance Criteria

### Agent

**1. Helper extension**
- [x] `_dispatch_substrate()` returns `by_task_type` field in addition
      to `by_model` — same shape (list of `{task_type, count}` sorted
      count desc).
- [x] Rows missing `task_type` excluded from `by_task_type` (mirror of
      the by_model legacy-row behavior).
- [x] Synthetic rows still excluded from both breakdowns.

**2. Template panel**
- [x] "Dispatch substrate" panel renders by_task_type sub-table after the
      by_model sub-table, with the same Model/Dispatches/Share columns
      (header `Task-type` instead of `Model`).
- [x] Empty-state handled: omit the sub-table when `by_task_type` is empty.

**3. Tests**
- [x] `tests/unit/test_orchestrator_dispatch_substrate.py` extends with:
      - `_dispatch_substrate()` returns by_task_type
      - by_task_type excludes synthetic rows
      - by_task_type excludes rows missing task_type
      - by_task_type sorted count desc
      - route-level: HTML contains the by_task_type sub-table
- [x] `python3 -m pytest tests/unit/test_orchestrator_dispatch_substrate.py tests/unit/test_orchestrator_learned_routing.py tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_routes.py -v` exits 0.

### Human

- [x] [REVIEW] Visual rhythm: by_model and by_task_type sub-tables stack
      cleanly within the Dispatch substrate panel — no overlap or odd
      gaps.
      **Steps:**
      1. Open `http://localhost:3000/orchestrator` in a browser.
      2. Scroll to "Dispatch substrate" section.
      3. Verify both Model and Task-type tables render with consistent column widths.
      **Expected:** Two sub-tables stacked vertically, same column style.
      **If not:** Note the rendering issue + screenshot; revert is one commit.

## Verification

python3 -m pytest tests/unit/test_orchestrator_dispatch_substrate.py tests/unit/test_orchestrator_learned_routing.py tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_routes.py -v

## Recommendation

**Recommendation:** GO — by_task_type companion to T-1792's by_model panel; web parity continues to close.

**Rationale:** by_model answers "what model is the orchestrator picking?" — a routing-decision question. by_task_type answers "what kind of work is the orchestrator doing?" — a workload-mix question. Same panel, two sub-tables, two operator questions. Synthetic-exclusion follows T-1792's rule. Pattern from T-1792's Evolution log: file each web breakdown as its own small slice rather than bundle.

**Evidence:**
- `web/blueprints/orchestrator.py:_dispatch_substrate()` — extended to return `by_task_type` alongside `by_model` (factored shared `_to_rows` builder for the symmetric shape).
- `web/templates/orchestrator.html` — added `<h3>By model</h3>` + `<h3>By task-type</h3>` sub-headers inside the panel, each gated by its respective truthy check.
- `tests/unit/test_orchestrator_dispatch_substrate.py` — 5 new T-1794 tests covering by_task_type return, synthetic exclusion, missing-task_type exclusion, sort order, and route-level rendering.
- Arc-suite regression: 96/96 green (was 94/94 at T-1792 close, +5 new T-1794 tests; gained 5 not 8 because one missing-task_type case also exercises the by_model excludes-missing rule).
- Live render confirmed: `curl /orchestrator` shows `<h3>By task-type</h3>` + `escalation-triage` row.

**Headline mechanic:** Open `/orchestrator` → Dispatch substrate panel shows BOTH the routing-decision mix (by_model) AND the workload mix (by_task_type) in stacked sub-tables — answers two operator questions with one scroll.

## Evolution

### 2026-05-12 — by_task_type sibling slice

- **What changed:** The shape `{key: X, count: N}` for both breakdowns let me factor a tiny `_to_rows(counter, key)` builder instead of duplicating the sort. Worth noting because if a third breakdown (by_worker_kind, T-1795 candidate) arrives, the builder absorbs it for free.
- **Plan impact:** None. Per T-1792 Evolution log this was the next planned slice. The third (by_worker_kind) is its sibling.
- **Triggered:** by_worker_kind candidate task — still defer, file when starting next slice.

## Decisions

## Updates

### 2026-05-12T21:25:20Z — task-created
- **Action:** Created task
- **Context:** Sibling slice to T-1792 — by_task_type companion to by_model panel

### 2026-05-12T21:27:54Z — status-update [task-update-agent]
- **Change:** tags: +observability

## Reviewer Verdict (v1.4)

- **Scan ID:** R-7827aa30
- **Timestamp:** 2026-05-18T09:30:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-12T21:27:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
