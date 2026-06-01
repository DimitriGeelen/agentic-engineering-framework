---
id: T-1786
name: "fw orchestrator status --worker-kind X: filter by worker_kind"
description: >
  fw orchestrator status --worker-kind X: filter by worker_kind

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [cli, observability]
components: []
related_tasks: [T-1779, T-1784, T-1785]
arc_id: orchestrator-rethink
created: 2026-05-11T11:01:42Z
last_update: 2026-05-11T11:04:27Z
date_finished: 2026-05-11T11:04:27Z
---

# T-1786: fw orchestrator status --worker-kind X: filter by worker_kind

## Context

`fw orchestrator status` has filter knobs for `--task T-XXX` (T-1784) and
`--since DURATION` (T-1785). The third dimension dispatches are bucketed
by — `worker_kind` — has no filter today.

The routing arc's core question is "is one worker accumulating errors
another isn't?". With 193 ollama-loop dispatches vs 3 TermLink in the
substrate, the operator wants `--worker-kind ollama-loop` to scope the
recent block, breakdowns, and JSON output to one worker.

Same filter-before-aggregation pattern as T-1784 / T-1785. Composes with
both, with `--json`, and with `--outcomes`.

## Acceptance Criteria

### Agent

**1. CLI flag**
- [x] `fw orchestrator status --worker-kind X` accepts a worker_kind string.
- [x] Filter applies BEFORE all aggregation: dispatches not matching
      `worker_kind == args.worker_kind` are excluded.
- [x] Synthetic exclusion still runs.

**2. Empty-result behavior**
- [x] When no dispatches match, print a clear notice
      (`no dispatches captured for worker_kind X`) and exit 0.
- [x] JSON output for empty filter returns the stats dict with zero
      counts, not an error.

**3. Composability**
- [x] `--worker-kind` composes with `--task`, `--since`, `--json`, `--outcomes`.
- [x] AND-composition: all active filters must match.

**4. Tests**
- [x] `tests/unit/test_orchestrator_status_terminal_events.py` extends with:
      - filter narrows to matching worker_kind only
      - empty filter prints clear notice
      - filter composes with --task (AND)
      - filter composes with --since (AND)
- [x] `python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py -v` exits 0.
- [x] No regression: arc-suite green.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py -v

## Recommendation

**Recommendation:** GO — third filter knob; closes the trio (`--task` / `--since` / `--worker-kind`).

**Rationale:** With the substrate skewed 193 ollama-loop vs 3 TermLink, the operator question "what's failing on ollama-loop specifically?" today requires `grep worker_kind ollama-loop .context/dispatches.jsonl`. The flag makes the substrate's own observability surface answer the per-worker question directly. Filter applied before aggregation means all four breakdowns (task_type, worker_kind, terminal_event, recent) scope to one worker. Composes cleanly with `--task` and `--since` for compound queries (e.g., "show me ollama-loop errors in the last hour for T-1700").

**Evidence:**
- `bin/fw` orchestrator status heredoc — filter chained after `--task` / `--since`, before stats build.
- `tests/unit/test_orchestrator_status_terminal_events.py` — 4 new T-1786 tests.
- Combined regression: arc-suite green.

**Headline mechanic:** `bin/fw orchestrator status --worker-kind ollama-loop` shows only that worker's dispatches across all breakdowns. Composes with `--task`, `--since`, `--json`, `--outcomes`.

## Evolution

### 2026-05-11 — third filter completes the trio, no new pattern

- **What changed:** Considered whether to also add `--task-type X` (would make four filters). Deferred: task_type cardinality is currently 3 (escalation-triage / default / prompt-triage) — `grep type=X .context/dispatches.jsonl` is fine for that. worker_kind is the dimension where the routing arc's actual learning question lives (per-worker success-rate comparison).
- **Plan impact:** Mirror T-1784 implementation exactly — add bash arg parse, pipe to heredoc, narrow `dispatches` list before stats build.
- **Triggered:** None.

## Decisions

## Updates

### 2026-05-11T11:01:42Z — task-created
- **Action:** Created task; arc-tagged orchestrator-rethink
- **Context:** Third filter knob — completes --task/--since/--worker-kind trio

## Reviewer Verdict (v1.4)

- **Scan ID:** R-2b2e3ad3
- **Timestamp:** 2026-05-11T11:04:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-11T11:04:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
