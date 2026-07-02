---
id: T-1780
name: "fw outcome read — surface terminal_event sub-fields (T-1777 pair to T-1779/T-1778)"
description: >
  fw outcome read — surface terminal_event sub-fields (T-1777 pair to T-1779/T-1778)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/outcome.py, tests/unit/test_outcome.py]
related_tasks: [T-1777, T-1778, T-1779]
arc_id: orchestrator-rethink
created: 2026-05-11T08:55:00Z
last_update: '2026-06-11T22:23:58Z'
date_finished: 2026-05-13T21:06:36Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:58Z'
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

# T-1780: fw outcome read — surface terminal_event sub-fields (T-1777 pair to T-1779/T-1778)

## Context

`fw outcome read <dispatch_id>` joins a dispatch row with the latest
outcome event and prints both. `read_dispatch()` already returns the
full dispatch dict — including `terminal_event` when T-1777 persisted
it — but `cmd_read()` doesn't surface that field in the human-readable
output. Operators must use `--json` to see it.

T-1778 added the same surface to `fw resolver run` and
`fw resolver explain`. T-1779 added an aggregate breakdown to
`fw orchestrator status`. This closes the third leg: per-dispatch
view in `fw outcome read`.

## Acceptance Criteria

### Agent

**1. cmd_read prints terminal_event**
- [x] After the existing `model:` line, when `merged.get("terminal_event")`
      is a dict with a `type`, print `terminal:       <type>`.
- [x] If `terminal_event.type == "error"` and `retryable` key exists,
      print `retryable:      <bool>`.
- [x] If `terminal_event.type == "result"` and `is_error` key exists,
      print `is_error:       <bool>`.
- [x] If no `terminal_event` field (legacy row), no terminal lines printed.

**2. JSON output unchanged**
- [x] `fw outcome read --json` already includes `terminal_event` in the
      merged dict (carried by `read_dispatch` since T-1777). No code
      change required — pinned via test.

**3. Tests**
- [x] `tests/unit/test_outcome.py` adds:
      - cmd_read prints terminal line for pi `agent.done` row
      - cmd_read prints `retryable: True` for pi `error` row
      - cmd_read prints `is_error: False` for ollama-loop `result` row
      - cmd_read prints no terminal lines when row lacks `terminal_event`
- [x] `python3 -m pytest tests/unit/test_outcome.py -v` exits 0.
- [x] No regression: T-1779, T-1778, T-1777 tests still pass.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_outcome.py tests/unit/test_resolver_run.py tests/unit/test_orchestrator_status_terminal_events.py -v

## Recommendation

**Recommendation:** GO — closes the third leg of T-1777 data surfacing.

**Rationale:** T-1777 persists terminal_event into dispatch rows; T-1778 surfaces sub-fields in `fw resolver run/explain`; T-1779 surfaces aggregate counts in `fw orchestrator status`. T-1780 adds the per-dispatch surface in `fw outcome read`, which is the canonical "what happened with dispatch X?" tool. Without this, operators must use `--json` and grep — defeats the purpose of having a human-readable output. Pattern mirrors T-1778 exactly (same three branches: error+retryable / result+is_error / quiet on other types).

**Evidence:**
- `lib/outcome.py:cmd_read` — terminal_event branch after `model:` line.
- `tests/unit/test_outcome.py` — 4 new T-1780 tests pass.
- Combined regression: T-1777 + T-1778 + T-1779 + T-1780 suite all green.

**Headline mechanic:** `bin/fw outcome read <dispatch_id>` now shows `terminal:`/`retryable:`/`is_error:` lines inline; no `--json` needed.

## Evolution

### 2026-05-11 — symmetric surfacing across three CLIs

- **What changed:** T-1779 (aggregate), T-1778 (CLI-pair forensics), and T-1780 (lookup) form the three distinct operator surfaces for T-1777-persisted data. Originally considered folding T-1780 into T-1779 by extending the "Recent dispatches:" block; rejected because aggregate breakdown and per-dispatch detail answer different operator questions. Three surfaces, three CLIs.
- **Plan impact:** No new task — T-1780 closes the third surface symmetrically.
- **Triggered:** None — pattern locked.

## Decisions

## Updates

### 2026-05-11T08:55:00Z — task-created
- **Action:** Created task; arc-tagged orchestrator-rethink
- **Context:** Pair-task to T-1779; pattern mirror of T-1778

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4f53a558
- **Timestamp:** 2026-06-02T14:59:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-13T21:06:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
