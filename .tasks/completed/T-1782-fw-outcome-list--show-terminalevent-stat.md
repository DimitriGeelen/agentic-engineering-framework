---
id: T-1782
name: "fw outcome list — show terminal_event status flag per row (T-1777 surface)"
description: >
  fw outcome list — show terminal_event status flag per row (T-1777 surface)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [cli, observability]
components: [lib/outcome.py, tests/unit/test_outcome.py]
related_tasks: [T-1777, T-1780, T-1781]
arc_id: orchestrator-rethink
created: 2026-05-11T09:10:00Z
last_update: '2026-08-16T22:24:44Z'
date_finished: 2026-05-13T21:07:34Z
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
  - ts: '2026-08-16T22:24:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1782: fw outcome list — show terminal_event status flag per row (T-1777 surface)

## Context

`fw outcome list T-XXX` is the per-task view of outcome events.
T-1780 added terminal_event to `fw outcome read <dispatch_id>` and
T-1781 added it inline to orchestrator status' recent block. The
list command remains the only outcome CLI without the surface.

Implementation: build a {dispatch_id → terminal_event} map from
dispatches.jsonl once, then append `terminal=<type>(<suffix>)` to
each row's printed line when a matching dispatch row carries the
field. Same suffix rules as T-1781:

    error retryable=T → terminal=error(retryable)
    error retryable=F → terminal=error(non-retryable)
    result is_error=T → terminal=result(is_error)
    result is_error=F → terminal=result          (no suffix)
    no terminal_event → no `terminal=` field

## Acceptance Criteria

### Agent

**1. cmd_list joins with dispatches.jsonl for terminal_event**
- [x] Add a helper `_dispatch_terminal_map()` that returns
      `{dispatch_id: terminal_event}` from dispatches.jsonl, skipping
      rows without terminal_event.
- [x] In `cmd_list`, after fetching rows, build the map once and append
      the terminal suffix per row when the dispatch_id matches.
- [x] Map lookup is cheap (single file read, O(n) where n = dispatch
      log lines; lookup O(1)).

**2. Tests**
- [x] `tests/unit/test_outcome.py` extends with:
      - list shows terminal=agent.done when dispatch row has it
      - list shows terminal=error(retryable) for retryable=True
      - list shows terminal=result(is_error) for is_error=True
      - list shows terminal=result (no suffix) for is_error=False
      - list does NOT append terminal= when dispatch row lacks the field
      - list does NOT append terminal= when dispatch_id has no match
- [x] `python3 -m pytest tests/unit/test_outcome.py -v` exits 0.
- [x] No regression across arc-suite.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_outcome.py tests/unit/test_orchestrator_status_terminal_events.py -v

## Recommendation

**Recommendation:** GO — closes the fourth and final surface of T-1777 data.

**Rationale:** After T-1778 (resolver run/explain), T-1779/T-1781 (orchestrator status aggregate + inline), T-1780 (outcome read), T-1782 closes the symmetric set: `fw outcome list T-XXX` now surfaces terminal_event per row too. Operators have one consistent visual idiom (`terminal=<type>(<suffix>)`) across every dispatch-touching CLI. The join cost is one extra file read per list call — negligible vs. the operator-clarity gain.

**Evidence:**
- `lib/outcome.py:_dispatch_terminal_map` — single-pass build.
- `lib/outcome.py:cmd_list` — suffix appended per row.
- `tests/unit/test_outcome.py` — 6 new T-1782 tests.
- Combined regression: full arc-suite green.

**Headline mechanic:** `bin/fw outcome list T-XXX` now shows the same `terminal=` suffix as `fw orchestrator status` recent block. Four CLIs, one idiom, zero `--json` required.

## Evolution

### 2026-05-11 — full symmetric surface

- **What changed:** With T-1782 the surfaces (resolver run/explain, orchestrator status aggregate, orchestrator status recent block, outcome read, outcome list) all share one suffix idiom. The arc set is internally consistent — operator learns once, applies everywhere.
- **Plan impact:** None — final slice in this surface family.
- **Triggered:** None.

## Decisions

## Updates

### 2026-05-11T09:10:00Z — task-created
- **Action:** Created task; arc-tagged orchestrator-rethink
- **Context:** Final symmetric slice of T-1777 surfacing

## Reviewer Verdict (v1.5)

- **Scan ID:** R-288039d6
- **Timestamp:** 2026-06-02T14:59:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-13T21:07:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
