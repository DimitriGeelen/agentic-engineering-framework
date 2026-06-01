---
id: T-1784
name: "fw orchestrator status --task T-XXX: filter dispatch view to one task"
description: >
  fw orchestrator status --task T-XXX: filter dispatch view to one task

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [cli, observability]
components: [bin/fw, tests/unit/test_orchestrator_status_terminal_events.py]
related_tasks: [T-1699, T-1779, T-1781]
arc_id: orchestrator-rethink
created: 2026-05-11T09:35:00Z
last_update: 2026-05-13T21:08:37Z
date_finished: 2026-05-13T21:08:37Z
---

# T-1784: fw orchestrator status --task T-XXX: filter dispatch view to one task

## Context

`fw orchestrator status` summarises ALL dispatches (currently 196).
When debugging a specific task, operators want "what dispatches has
this one task accumulated?". Adding `--task T-XXX` filters the entire
view (totals, breakdowns, recent block, JSON output) to dispatches
whose `task_id` matches.

This is a filter, not a new view — same render code path, smaller
input set. Synthetic-row exclusion still applies. Empty filter
result (no dispatches for this task) prints a clear notice.

## Acceptance Criteria

### Agent

**1. CLI flag**
- [x] `fw orchestrator status --task T-XXX` accepts a task ID.
- [x] Filter applies BEFORE all aggregation: dispatches not matching
      `task_id == args.task` are excluded.
- [x] Synthetic exclusion still runs (T-stress-* + non-matching task
      are both filtered out).

**2. Empty-result behavior**
- [x] When no dispatches match, print a clear notice
      (`no dispatches captured for task T-XXX`) and exit 0.
- [x] JSON output for empty filter returns the stats dict with zero
      counts, not an error.

**3. Combined flags**
- [x] `--task` composes with `--json` and `--outcomes` (existing flags).

**4. Tests**
- [x] `tests/unit/test_orchestrator_status_terminal_events.py` extends with:
      - filter narrows to matching dispatches only
      - empty filter prints clear notice
      - filter composes with --json
      - filter composes with --outcomes
- [x] `python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py -v` exits 0.
- [x] No regression: arc-suite green.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py -v

## Recommendation

**Recommendation:** GO — single filter; reuses all existing render paths.

**Rationale:** When debugging "what happened to T-1779's dispatches", today's only option is `grep T-1779 .context/dispatches.jsonl`. The `--task` flag makes the substrate's own observability surface answer the per-task question directly. Filter applied before aggregation means all four breakdowns (task_type, worker_kind, terminal_event, recent) are scoped — operators see exactly one task's behavior without manual filtering downstream.

**Evidence:**
- `bin/fw` orchestrator status heredoc — filter applied after `_is_synthetic` exclusion, before stats build.
- `tests/unit/test_orchestrator_status_terminal_events.py` — 4 new T-1784 tests.
- Combined regression: arc-suite green.

**Headline mechanic:** `bin/fw orchestrator status --task T-1779` shows only that task's dispatches across all breakdowns. Composes with `--json` and `--outcomes`.

## Evolution

### 2026-05-11 — filter BEFORE aggregation, not after

- **What changed:** Considered filtering only the "Recent dispatches:" block (leaving totals/breakdowns global). Rejected: filtering the recent block but not the breakdowns produces a confusing surface — "By worker_kind: ollama-loop 193" alongside "Recent (filtered): 1 result". Filter must be uniform across all stats. Applied filter immediately after synthetic exclusion so every downstream aggregation sees only matching rows.
- **Plan impact:** Add `--task` flag parsing in bash arg loop, pass through to heredoc. In heredoc, narrow `dispatches` list before any Counter call. Empty result → graceful notice.
- **Triggered:** None — pinned via test.

## Decisions

## Updates

### 2026-05-11T09:35:00Z — task-created
- **Action:** Created task; arc-tagged orchestrator-rethink
- **Context:** Per-task filter for orchestrator status

## Reviewer Verdict (v1.4)

- **Scan ID:** R-7e7846ff
- **Timestamp:** 2026-05-13T21:08:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-13T21:08:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
