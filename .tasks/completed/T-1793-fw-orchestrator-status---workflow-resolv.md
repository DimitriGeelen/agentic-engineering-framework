---
id: T-1793
name: "fw orchestrator status --workflow-resolved-via primary|fallback: filter for
  fallback-firing forensics"
description: >
  fw orchestrator status --workflow-resolved-via primary|fallback: filter for fallback-firing
  forensics

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [cli, observability]
components: []
related_tasks: [T-1791, T-1786, T-1790]
arc_id: orchestrator-rethink
created: 2026-05-12T21:17:07Z
last_update: '2026-06-11T22:23:59Z'
date_finished: 2026-05-12T21:19:58Z
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

# T-1793: fw orchestrator status --workflow-resolved-via primary|fallback: filter for fallback-firing forensics

## Context

Dispatch substrate captures `workflow_resolved_via` per row (substrate
example: `"workflow_resolved_via": "primary"`). The field tells you
whether the workflow lookup hit the primary path or fell back to the
default — the failure-mode of the orchestrator's routing layer.

Operators need to answer: "how often does fallback fire?" and "show me
every fallback dispatch in the last 24h" — questions about routing
reliability that the breakdown can't surface and the substrate can.

Sixth filter knob, symmetric to T-1786 (--worker-kind), T-1790
(--task-type), T-1791 (--model). Same filter-before-aggregation pattern.
AND-composes with all five prior filters.

## Acceptance Criteria

### Agent

**1. CLI flag**
- [x] `fw orchestrator status --workflow-resolved-via primary|fallback`
      narrows the dispatch list before aggregation. All breakdowns
      honour the filter.
- [x] Filter line `  Filter:            workflow_resolved_via=<X>` rendered.
- [x] Empty result → notice `no dispatches captured for workflow_resolved_via <X>` exit 0.

**2. Composability**
- [x] AND-composes with `--task`, `--since`, `--worker-kind`, `--task-type`, `--model`.
- [x] Honored under `--json`.

**3. Tests**
- [x] `tests/unit/test_orchestrator_status_terminal_events.py` extends:
      - `--workflow-resolved-via primary` narrows correctly
      - `--workflow-resolved-via fallback` narrows correctly
      - empty notice when no rows match
      - AND with `--model` (composition)
      - `--workflow-resolved-via --json` honors filter
- [x] `python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py tests/unit/test_orchestrator_routes.py tests/unit/test_orchestrator_dispatch_substrate.py -v` exits 0.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py tests/unit/test_orchestrator_routes.py tests/unit/test_orchestrator_dispatch_substrate.py -v

## Recommendation

**Recommendation:** GO — sixth filter knob; closes fallback-detection gap.

**Rationale:** `workflow_resolved_via` is the single signal that tells operators whether the routing layer is operating in nominal mode (primary path) or degraded mode (fallback fired). The substrate captures it per dispatch; until now it was invisible to status-time forensics. Same filter-before-aggregation pattern as the five prior filters. AND-composes with all of them and with `--json`. Smoke-tested against live 246-row substrate — all dispatches recorded as primary (0 fallback firings), exactly the visibility we wanted.

**Evidence:**
- `bin/fw` orchestrator status heredoc — `filter_resolved_via` parsing (sys.argv[9]) + apply-before-aggregation + empty-notice + filter header line.
- `tests/unit/test_orchestrator_status_terminal_events.py` — 5 new T-1793 tests (primary narrowing, fallback narrowing, empty notice, AND with --model, --json composition).
- Combined arc-suite regression: 90/90 across status + outcomes + routes + dispatch-substrate test files.
- Live smoke: `--workflow-resolved-via primary` → 196 dispatches; `--workflow-resolved-via fallback` → 0 (clean empty notice); `--workflow-resolved-via nonsense` → 0 (same notice, no crash).

**Headline mechanic:** `bin/fw orchestrator status --workflow-resolved-via fallback --since 24h` answers "did fallback fire in the last day?" in one command — the canonical reliability-check query.

## Evolution

### 2026-05-12 — sixth filter slice; fallback now observable at status-time

- **What changed:** All prior filter slices answered shape questions (which task / which worker / which model). This one answers a *reliability* question: is the routing layer in degraded mode? The substrate has captured workflow_resolved_via since T-1693 but never surfaced it.
- **Plan impact:** None — symmetric extension. With six filter knobs the matrix is now: task identity / time / worker / task_type / routing-decision / routing-path. The remaining dispatch dimensions (effort, prompt_strategy) are not arc-priorities.
- **Triggered:** None autonomously. A future slice could surface `by_workflow_resolved_via` as a breakdown in the headline output — useful when no filter is set but you still want fallback-firing visibility at a glance.

## Decisions

## Updates

### 2026-05-12T21:17:07Z — task-created
- **Action:** Created task
- **Context:** Sixth filter knob — closes the fallback-detection forensic gap

### 2026-05-12T21:19:54Z — status-update [task-update-agent]
- **Change:** tags: +observability

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c3bbe4ae
- **Timestamp:** 2026-06-02T14:59:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-12T21:19:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
