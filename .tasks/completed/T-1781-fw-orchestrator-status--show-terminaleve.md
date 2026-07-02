---
id: T-1781
name: "fw orchestrator status — show terminal_event in 'Recent dispatches:' lines"
description: >
  fw orchestrator status — show terminal_event in 'Recent dispatches:' lines

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [bin/fw, lib/outcome.py, 
      tests/unit/test_orchestrator_status_terminal_events.py, 
      tests/unit/test_outcome.py]
related_tasks: [T-1777, T-1779]
arc_id: orchestrator-rethink
created: 2026-05-11T09:00:00Z
last_update: '2026-06-11T22:23:59Z'
date_finished: 2026-05-13T21:05:11Z
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

# T-1781: fw orchestrator status — show terminal_event in 'Recent dispatches:' lines

## Context

`fw orchestrator status` ends with a "Recent dispatches:" block showing
the last 5 dispatch rows in this format:

    · 2026-05-05T18:30:55 [23ecae45] task=T-1086 type=escalation-triage worker=ollama-loop

The terminal_event T-1777 persists into each row is the most operator-
relevant piece of "what happened" — but invisible here. Adding it makes
the default surface ("first thing I see when I run status") answer the
default operator question ("did these complete cleanly?").

T-1779 added an aggregate breakdown ("By terminal event:"); T-1781
brings the same data inline at the per-row level.

## Acceptance Criteria

### Agent

**1. Recent dispatches line format**
- [x] When a dispatch row carries `terminal_event` with a `type`, append
      ` terminal=<type>` to the existing line.
- [x] For `error` events with `retryable` flag, append `(retryable)` or
      `(non-retryable)` after the type.
- [x] For `result` events with `is_error: True`, append `(is_error)`
      after the type. `is_error: False` does not add a suffix (success
      case, no noise).
- [x] Rows without terminal_event print the existing line unchanged
      (backward compatible).

**2. Stats dict propagation**
- [x] Each entry in `stats["recent"]` gains `terminal_event` key
      (mirroring the dispatch row), or `None` if absent.

**3. Tests**
- [x] `tests/unit/test_orchestrator_status_terminal_events.py` extended:
      - recent line shows `terminal=agent.done` when present
      - recent line shows `terminal=error(retryable)` for retryable error
      - recent line shows `terminal=error(non-retryable)` for non-retryable
      - recent line shows `terminal=result(is_error)` for failed result
      - recent line shows `terminal=result` for successful result (no suffix)
      - recent line unchanged when row lacks terminal_event
- [x] `python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py -v` exits 0.
- [x] No regression: full arc-suite (T-1777, T-1778, T-1779, T-1780) green.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py tests/unit/test_outcome.py -v

## Recommendation

**Recommendation:** GO — single-line append on the default surface; closes the per-row leg.

**Rationale:** The "Recent dispatches:" block is the first thing an operator reads when running `fw orchestrator status`. Showing terminal_event inline (`terminal=agent.done` / `terminal=error(retryable)` / `terminal=result(is_error)`) answers the default question — "did these dispatches complete cleanly?" — without making the user run `fw outcome read <dispatch_id>` for each. is_error: False is the success path; no suffix avoids cluttering the common case. Pattern: render only what's informative for THIS terminal type (same principle as T-1778's quiet-on-agent.done decision).

**Evidence:**
- `bin/fw` — Recent dispatches block extended; stats dict carries `terminal_event` per row.
- `tests/unit/test_orchestrator_status_terminal_events.py` — 6 new T-1781 tests.
- Combined regression: T-1777 + T-1778 + T-1779 + T-1780 + T-1781 all green.

**Headline mechanic:** `bin/fw orchestrator status` "Recent dispatches:" now shows `terminal=<type>(<suffix>)` per row when data is present. Default surface, default question, one-look answer.

## Evolution

### 2026-05-11 — suffix-only-when-informative

- **What changed:** Considered always appending `(is_error=False)` to result events for symmetry with `(retryable)` on errors. Rejected: every successful ollama-loop dispatch would carry a meaningless suffix, doubling line length on the common case. Adopted the asymmetric rule: error always shows retryable state (both branches important); result shows nothing on success, `(is_error)` only on failure (the noisy case is the failure case, not the success case).
- **Plan impact:** Branch on `(type, is_error_value)` for result; branch on `retryable` boolean for error. Tests pin both halves of result branch (with and without suffix).
- **Triggered:** None — pinned via test.

## Decisions

## Updates

### 2026-05-11T09:00:00Z — task-created
- **Action:** Created task; arc-tagged orchestrator-rethink
- **Context:** Inline-row pair to T-1779's aggregate breakdown

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0b388b0f
- **Timestamp:** 2026-06-02T14:59:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-13T21:05:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
