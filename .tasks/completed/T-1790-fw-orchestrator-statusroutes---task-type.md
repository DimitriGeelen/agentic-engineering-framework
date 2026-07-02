---
id: T-1790
name: "fw orchestrator status/routes --task-type X: fourth filter knob (parity across
  surfaces)"
description: >
  fw orchestrator status/routes --task-type X: fourth filter knob (parity across surfaces)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: [T-1784, T-1786, T-1789]
arc_id: orchestrator-rethink
created: 2026-05-11T11:42:00Z
last_update: '2026-06-11T22:23:59Z'
date_finished: 2026-05-11T11:21:32Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1790: --task-type X filter on both status and routes surfaces

## Context

The orchestrator filter trio (T-1784 task, T-1785 since, T-1786 worker-kind)
covers task identity, time, and worker — but not `task_type`, which is
literally the routing dimension (orchestrator picks model BY task_type).

`fw orchestrator status` has a `By task_type` breakdown but no
`--task-type` filter — operator can see distribution but can't zoom in.

`fw orchestrator routes` (T-1789) shows learned preferences per task_type;
no filter to narrow to one task_type — small now (4 types) but will
grow as workflows multiply.

This slice adds `--task-type X` symmetrically to both surfaces. Same
filter-before-aggregation pattern as the trio.

## Acceptance Criteria

### Agent

**1. status --task-type X**
- [x] `fw orchestrator status --task-type X` accepts a task_type string.
- [x] Filter applied BEFORE aggregation (mirror of --worker-kind).
- [x] Composes with --task, --since, --worker-kind (AND).
- [x] Empty-result notice includes task_type in scope phrase.
- [x] Filter line `Filter: task_type=X` shown when active.

**2. routes --task-type X**
- [x] `fw orchestrator routes --task-type X` narrows the by_task_type
      list to entries matching X.
- [x] When no match → "no route cache entries for task_type X" notice.
- [x] --json: by_task_type list filtered to matching entries only.

**3. Tests**
- [x] `tests/unit/test_orchestrator_status_terminal_events.py` extends with:
      - --task-type narrows status to matching dispatches
      - --task-type empty result prints notice
      - --task-type composes with --worker-kind (AND)
- [x] `tests/unit/test_orchestrator_routes.py` extends with:
      - --task-type narrows routes to matching task_type only
      - --task-type with no match prints notice
      - --task-type --json filters list
- [x] All tests pass; arc-suite green.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_orchestrator_routes.py tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py -v

## Recommendation

**Recommendation:** GO — closes the filter symmetry across both surfaces.

**Rationale:** task_type is the routing dimension itself. Operator asking "what dispatches happened for escalation-triage" or "what's the orchestrator learned for build tasks" should not need to grep raw JSON. The pattern is identical to existing filters — no new infrastructure. Symmetric application across status and routes preserves the CLI/web/CLI-surfaces parity established by T-1789.

**Evidence:**
- `bin/fw` orchestrator status heredoc — --task-type bash + Python plumbing, mirror of --worker-kind.
- `bin/fw` orchestrator routes heredoc — --task-type filter on by_task_type list, plus notice for empty.
- `tests/unit/test_orchestrator_status_terminal_events.py` — 3 new tests.
- `tests/unit/test_orchestrator_routes.py` — 3 new tests.
- Combined regression: arc-suite green.

**Headline mechanic:** `bin/fw orchestrator status --task-type escalation-triage --since 1h` narrows to one routing dimension within a time window. `bin/fw orchestrator routes --task-type build` shows just build's leaderboard.

## Evolution

### 2026-05-11 — close filter symmetry, no new infrastructure

- **What changed:** Realized the filter trio (T-1784/T-1785/T-1786) included task identity, time, and worker — but not the routing dimension itself. task_type is the field by which the orchestrator chooses a model, and the operator wants to slice by it on both surfaces.
- **Plan impact:** Mirror --worker-kind on status (5 LOC + filter line). For routes, filter by_task_type list in the heredoc (3 LOC). Tests follow established patterns.
- **Triggered:** None.

## Decisions

## Updates

### 2026-05-11T11:42:00Z — task-created
- **Action:** Created task; arc-tagged orchestrator-rethink
- **Context:** task_type filter symmetric on status + routes

## Reviewer Verdict (v1.5)

- **Scan ID:** R-abf4fa7f
- **Timestamp:** 2026-06-02T14:59:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-11T11:21:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
