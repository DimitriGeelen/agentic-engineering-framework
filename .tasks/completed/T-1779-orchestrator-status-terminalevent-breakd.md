---
id: T-1779
name: "orchestrator status: terminal_event breakdown — surface T-1777 persisted data
  in substrate observability"
description: >
  orchestrator status: terminal_event breakdown — surface T-1777 persisted data in
  substrate observability

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [bin/fw, lib/outcome.py, 
      tests/unit/test_orchestrator_status_terminal_events.py, 
      tests/unit/test_outcome.py]
related_tasks: [T-1699, T-1777, T-1778]
arc_id: orchestrator-rethink
created: 2026-05-11T08:39:53Z
last_update: '2026-06-11T22:23:58Z'
date_finished: 2026-05-13T21:10:19Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:58Z'
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

# T-1779: orchestrator status: terminal_event breakdown — surface T-1777 persisted data in substrate observability

## Context

T-1699 shipped `fw orchestrator status` with three breakdowns:
dispatch totals, by_task_type, by_worker_kind. T-1777 then started
persisting `terminal_event` (with sub-fields `retryable` / `is_error`)
into each dispatch row. That persisted data is currently invisible at
the substrate-observability surface — operators must crack open
`dispatches.jsonl` to see the distribution of agent.done / error /
result terminal events.

This adds a fourth breakdown:

```
By terminal event:
  agent.done                     145
  result                          47
  error                            1   (retryable=1 / non-retryable=0)
```

For ollama-loop result events with `is_error` field, an additional
sub-line surfaces `is_error: True=N False=M`. Section omitted entirely
when no rows carry terminal_event (legacy data, graceful fallback).

## Acceptance Criteria

### Agent

**1. stats aggregator (bin/fw orchestrator status heredoc)**
- [x] `stats["by_terminal_type"]` Counter of `terminal_event["type"]`
      across real (non-synthetic) dispatch rows where the field exists.
- [x] `stats["terminal_retryable"]` sub-dict for `error` events: counts
      of `retryable=True` / `retryable=False` (only when at least one
      error event has the field).
- [x] `stats["terminal_is_error"]` sub-dict for `result` events: counts
      of `is_error=True` / `is_error=False`.

**2. Text rendering**
- [x] New section `"By terminal event:"` printed after the existing
      `"By worker_kind:"` section, only when at least one row has
      `terminal_event`. Format mirrors the existing breakdowns.
- [x] When error events exist with retryable info, append
      `(retryable=N / non-retryable=M)` to the `error` line.
- [x] When result events have is_error info, print
      `is_error: True=N False=M` indented below the `result` line.
- [x] Legacy rows (no terminal_event) → section omitted entirely. No
      "0 events" noise.

**3. JSON output**
- [x] `fw orchestrator status --json` exposes `by_terminal_type`,
      `terminal_retryable`, `terminal_is_error` at the top level.
- [x] Existing JSON keys unchanged (`by_task_type`, `by_worker_kind`,
      `recent`, etc.) — backward compatible.

**4. Tests**
- [x] `tests/unit/test_orchestrator_status_terminal_events.py` new
      file with these pins:
      - terminal_event breakdown appears when rows carry the field
      - retryable split rendered for error events
      - is_error split rendered for result events
      - section omitted entirely when no row has terminal_event
      - synthetic T-stress-* rows excluded from terminal aggregation
      - JSON output exposes the three new keys
- [x] `python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py -v` exits 0.
- [x] No regression: existing 8 outcome-aggregation tests still pass.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py -v

## Recommendation

**Recommendation:** GO — surfaces the data T-1777 persists; section omitted gracefully when rows lack the field.

**Rationale:** T-1777 added `terminal_event` to dispatch rows but the substrate-observability surface (`fw orchestrator status`) didn't read it. Operators needing to know "what terminated the last 20 dispatches" had to crack open `.context/dispatches.jsonl`. T-1779 closes that gap: when rows carry `terminal_event`, a fourth breakdown section appears under "By worker_kind:" showing the distribution. Error events with `retryable` flag get `(retryable=N / non-retryable=M)`; result events with `is_error` flag get `is_error: True=N False=M`. Legacy rows (no field) → section omitted entirely. Synthetic T-stress-* rows excluded (matches T-1712 contract). JSON output exposes the three new keys at top level.

**Evidence:**
- `bin/fw:3416-3454` — stats aggregator builds three counters from non-synthetic dispatch rows.
- `bin/fw:3531-3550` — text rendering, sorted by count desc, sub-fields conditional on event type.
- `tests/unit/test_orchestrator_status_terminal_events.py` — 8/8 pass (6 text-output + 2 JSON).
- `tests/unit/test_orchestrator_status_outcomes.py` — 8/8 pass (no regression).
- Live smoke: `bin/fw orchestrator status` against 196 production rows (zero carry terminal_event yet) correctly omits the section — no spurious "By terminal event:" with no entries.
- Combined regression: 57/57 across orchestrator-status + resolver-run + spawn + ollama-loop.

**Headline mechanic:** `bin/fw orchestrator status` shows a "By terminal event:" breakdown automatically once dispatch rows carrying T-1777-persisted terminal_event arrive. Operators see retry/error semantics at a glance without opening any blob.

## Evolution

### 2026-05-11 — render-condition: omit-when-empty, not "0 events"

- **What changed:** First sketch had the section always render with "(none)" when no row carried `terminal_event`. Rejected: 196 existing legacy rows would each see a meaningless "By terminal event: (none)" — noise that fades only once enough new dispatches arrive. Switched to conditional rendering (skip section entirely when counter is empty). Tests pin both the present-when-data and absent-when-legacy paths explicitly.
- **Plan impact:** One `if stats["by_terminal_type"]:` guard before the section block. JSON output still always exposes the three keys (consumers ignore empty dicts cheaply).
- **Triggered:** No new task — pinned via test_section_omitted_when_no_row_has_terminal_event.

## Decisions

<!-- Record only when choosing between alternatives. -->

## Updates

### 2026-05-11T08:39:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1779-orchestrator-status-terminalevent-breakd.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-aa3cc60b
- **Timestamp:** 2026-06-02T14:59:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-13T21:10:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
