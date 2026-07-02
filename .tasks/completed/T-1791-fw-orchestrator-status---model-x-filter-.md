---
id: T-1791
name: "fw orchestrator status --model X: filter by routing-decision model (T-1788
  surface pair)"
description: >
  fw orchestrator status --model X: filter by routing-decision model (T-1788 surface
  pair)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: [T-1788, T-1786, T-1790]
arc_id: orchestrator-rethink
created: 2026-05-12T21:06:39Z
last_update: '2026-06-11T22:23:59Z'
date_finished: 2026-05-12T21:10:15Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1791: fw orchestrator status --model X: filter by routing-decision model (T-1788 surface pair)

## Context

`fw orchestrator status` has filter knobs for task / since / worker-kind /
task-type. The `model` field is captured per dispatch (T-1788 surfaced it
in `By model:` breakdown + recent-line `model=X`), but not yet filterable.

Model is the headline routing decision of the orchestrator arc. Filtering
by it answers questions the breakdown can't: "show me every dispatch where
opus was picked", "did haiku ever get used for design work?", "find the
fallback to sonnet on this task_type" — all dispatch-shape questions
that operators ask after seeing the by_model summary.

Same filter-before-aggregation pattern as T-1786 / T-1790. Composes AND
with all other filters.

## Acceptance Criteria

### Agent

**1. CLI flag**
- [x] `fw orchestrator status --model X` narrows the dispatch list before
      stats are built. All downstream breakdowns (by_task_type, by_worker_kind,
      by_outcome, by_model, recent block) honour the filter.
- [x] Filter line `  Filter:            model=<X>` rendered when active.
- [x] Empty result (no dispatches match) → notice `no dispatches for model <X>` exit 0.

**2. Composability**
- [x] `--model` composes AND with `--task`, `--since`, `--worker-kind`, `--task-type`.
- [x] `--model` honored under `--json`.

**3. Tests**
- [x] `tests/unit/test_orchestrator_status_terminal_events.py` extends with:
      - `--model X` narrows to that model only
      - empty notice when no rows match
      - AND with `--worker-kind` (composition)
      - AND with `--task-type` (composition)
      - `--model --json` output respects filter
- [x] `python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py tests/unit/test_orchestrator_routes.py -v` exits 0.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py tests/unit/test_orchestrator_routes.py -v

## Recommendation

**Recommendation:** GO — fifth filter knob completing the arc's dispatch-shape symmetry.

**Rationale:** Model is the headline routing decision of the orchestrator arc (T-1788 surfaced it as a breakdown + per-row column). Filtering by it answers questions the by_model breakdown can't: "show every dispatch where opus was actually used", "did haiku ever route to design work?", "is fallback to sonnet firing on this task_type?" — dispatch-shape forensics rather than aggregate counts. Same filter-before-aggregation pattern as T-1786 / T-1790. AND-composes with all four prior filters and `--json`. Smoke-tested against the live 193-row substrate — `--model claude-3-5-sonnet-hermes3` correctly narrows the breakdown to that single model.

**Evidence:**
- `bin/fw` orchestrator status heredoc — `filter_model` parsing (sys.argv[8]) + apply-before-aggregation + `Filter:` line + empty-notice scope part.
- `tests/unit/test_orchestrator_status_terminal_events.py` — 6 new T-1791 tests covering narrowing, empty notice, two AND-compositions, JSON, and legacy-row exclusion.
- Combined regression: 77/77 arc-suite green (was 71/71 at session start).
- Live smoke: `bin/fw orchestrator status --model claude-3-5-sonnet-hermes3` → 193 dispatches filtered, breakdown reflects filter.

**Headline mechanic:** `bin/fw orchestrator status --model opus --since 24h` shows every opus routing decision in the last day across all breakdowns and recent rows.

## Evolution

### 2026-05-12 — fifth filter slice, no design changes

- **What changed:** Nothing surprising — T-1786/T-1790 set the pattern; this slice just adds the fifth dimension. The substrate had `model` (T-1788), the breakdown showed it (T-1788), the per-row line included it (T-1788). Filtering was the missing leg.
- **Plan impact:** None — symmetric extension of an established pattern.
- **Triggered:** None. The next symmetric piece would be `--workflow-resolved-via primary|fallback` (substrate has the field, useful for fallback detection) — fileable as a sibling.

## Decisions

## Updates

### 2026-05-12T21:06:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1791-fw-orchestrator-status---model-x-filter-.md
- **Context:** Fifth filter knob for orchestrator status — symmetric to T-1786/T-1790

### 2026-05-12T21:10:09Z — status-update [task-update-agent]
- **Change:** tags: +observability

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c2791ea7
- **Timestamp:** 2026-06-02T14:59:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-12T21:10:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
