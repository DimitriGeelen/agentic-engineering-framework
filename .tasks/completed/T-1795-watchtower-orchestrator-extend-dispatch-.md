---
id: T-1795
name: "Watchtower /orchestrator: extend Dispatch substrate panel with by_worker_kind
  breakdown"
description: >
  Watchtower /orchestrator: extend Dispatch substrate panel with by_worker_kind breakdown

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [web, observability]
components: []
related_tasks: [T-1792, T-1794]
arc_id: orchestrator-rethink
created: 2026-05-12T21:28:40Z
last_update: 2026-09-03T23:55:28Z
date_finished: 2026-05-12T21:31:13Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 3
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1795: Watchtower /orchestrator: extend Dispatch substrate panel with by_worker_kind breakdown

## Context

Third (and final) of the by_X sibling breakdowns on the Dispatch substrate
panel:

- T-1792: **by_model** ("which model got picked?" — routing decision)
- T-1794: **by_task_type** ("what kind of work?" — workload mix)
- T-1795: **by_worker_kind** ("which dispatch driver fired?" — execution path)

The `_to_rows(counter, key)` builder from T-1794 absorbs this for free,
so the diff is small: one new Counter + one new template sub-table.

worker_kind tells operators whether work went through `ollama-loop`,
`TermLink`, `Task`, etc. — useful when fallback paths or worker drivers
shift. Same synthetic-exclusion rule. Same missing-field exclusion.

## Acceptance Criteria

### Agent

**1. Helper extension**
- [x] `_dispatch_substrate()` returns `by_worker_kind` field — same shape
      `[{worker_kind: X, count: N}, ...]` sorted count desc.
- [x] Rows missing `worker_kind` excluded from `by_worker_kind`.
- [x] Synthetic rows excluded from `by_worker_kind`.

**2. Template panel**
- [x] `<h3>By worker-kind</h3>` sub-table after By task-type in the
      Dispatch substrate panel.
- [x] Empty-state: sub-table omitted when `by_worker_kind` is empty.

**3. Tests**
- [x] `tests/unit/test_orchestrator_dispatch_substrate.py` extends with:
      - by_worker_kind returned + sort
      - excludes synthetic
      - excludes rows missing worker_kind
      - route-level: HTML contains the by_worker_kind sub-table
- [x] `python3 -m pytest tests/unit/test_orchestrator_dispatch_substrate.py tests/unit/test_orchestrator_learned_routing.py tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_routes.py -v` exits 0.

### Human

- [x] [REVIEW] Three sub-tables stack cleanly — panel doesn't overflow
      or compress awkwardly.
      **Steps:**
      1. Open `http://localhost:3000/orchestrator` in a browser.
      2. Scroll to "Dispatch substrate" section.
      3. Verify By model, By task-type, By worker-kind stack in that order.
      **Expected:** Three sub-tables, consistent column rhythm, no layout breakage.
      **If not:** Note rendering issue + screenshot.

## Verification

python3 -m pytest tests/unit/test_orchestrator_dispatch_substrate.py tests/unit/test_orchestrator_learned_routing.py tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_routes.py -v

## Recommendation

**Recommendation:** GO — closes the by_X breakdown trio on the Dispatch substrate panel.

**Rationale:** With T-1792 (by_model) + T-1794 (by_task_type) + T-1795 (by_worker_kind), the web's Dispatch substrate panel now answers three orthogonal observability questions in one scroll: routing decision, workload mix, execution path. The `_to_rows` builder factored in T-1794 absorbed this slice with no duplication — Counter + one template block, no design change. Pattern: file each breakdown as its own small reviewable slice, even when the diff is tiny, so the Evolution log per task carries the rationale separately.

**Evidence:**
- `web/blueprints/orchestrator.py:_dispatch_substrate()` — added `worker_kind_counter` + `_to_rows(..., "worker_kind")` to the return shape.
- `web/templates/orchestrator.html` — added `<h3>By worker-kind</h3>` sub-table after By task-type, same gating + column rhythm.
- `tests/unit/test_orchestrator_dispatch_substrate.py` — 4 new T-1795 tests (return, synthetic exclude, missing-field exclude, route-level render).
- Arc-suite regression: 100/100 green (was 96/96 before this slice).
- Live render confirmed: `By worker-kind` h3 + `ollama-loop` row.

**Headline mechanic:** Open `/orchestrator` → Dispatch substrate panel → three sub-tables: which model (routing), which task type (workload), which worker (execution).

## Evolution

### 2026-05-12 — by_worker_kind closes the trio

- **What changed:** `_to_rows` builder from T-1794 absorbed this slice for free — only addition to the helper was the new Counter + one return-key. Confirms T-1794's call that the factoring was worth doing.
- **Plan impact:** The web Dispatch substrate panel now matches the CLI `by_*` breakdowns from `fw orchestrator status` 1:1. Next gap on web → CLI parity is terminal_event surface (CLI has T-1779/T-1781; web doesn't) and outcome quality view (CLI `--outcomes`). Neither is urgent — both wait for the next slice with budget headroom.
- **Triggered:** None autonomously. Outcome-quality and terminal-event panels are natural next slices for a future session.

## Decisions

## Updates

### 2026-05-12T21:28:40Z — task-created
- **Action:** Created task
- **Context:** Final by_X breakdown sibling — closes web parity matrix on the substrate panel

### 2026-05-12T21:31:13Z — status-update [task-update-agent]
- **Change:** tags: +observability

## Reviewer Verdict (v1.4)

- **Scan ID:** R-9d93ed35
- **Timestamp:** 2026-05-18T09:30:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-12T21:31:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
