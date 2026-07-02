---
id: T-1787
name: "fw orchestrator status --recent N: control size of recent block"
description: >
  fw orchestrator status --recent N: control size of recent block

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: [T-1784, T-1785, T-1786]
arc_id: orchestrator-rethink
created: 2026-05-11T11:10:00Z
last_update: '2026-06-11T22:23:59Z'
date_finished: 2026-05-11T11:09:12Z
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

# T-1787: fw orchestrator status --recent N: control size of recent block

## Context

`fw orchestrator status` shows the last 5 dispatches in the "Recent
dispatches:" block — hardcoded slice `dispatches[-5:]`. When operators
want a wider view ("show me the last 50 to see the burst pattern"),
their only option is `tail -50 .context/dispatches.jsonl`, which gives
raw JSON without the surface's flag/terminal_event annotations.

`--recent N` exposes the slice size as a CLI knob. Composes with all
existing filters (T-1784/T-1785/T-1786) — applied AFTER filtering so
the count reflects matching rows.

Defaults: 5 (preserves current behavior). N >= 1 validated.

## Acceptance Criteria

### Agent

**1. CLI flag**
- [x] `fw orchestrator status --recent N` accepts a positive integer.
- [x] Default behavior unchanged (last 5 dispatches) when flag absent.
- [x] Slice is `dispatches[-N:]` — taken AFTER all filters apply.
- [x] N <= 0 rejected with clear error, exit 1.
- [x] Non-integer rejected with clear error, exit 1.

**2. Composition**
- [x] `--recent` composes with `--task`, `--since`, `--worker-kind`.
- [x] `--recent` composes with `--json` (stats["recent"] reflects N).
- [x] When filter narrows to < N rows, the smaller count is shown
      (not padded with non-matching rows).

**3. Tests**
- [x] `tests/unit/test_orchestrator_status_terminal_events.py` extends with:
      - `--recent 10` shows up to 10 rows
      - `--recent 1` shows only the latest row
      - `--recent 0` rejected with exit 1
      - `--recent abc` rejected with exit 1
      - `--recent` composes with `--worker-kind`
- [x] `python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py -v` exits 0.
- [x] No regression: arc-suite green.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py -v

## Recommendation

**Recommendation:** GO — view-density knob; orthogonal to the filter trio.

**Rationale:** The filter trio (T-1784/T-1785/T-1786) narrows WHICH rows are in scope. `--recent N` controls how many of the in-scope rows render in the recent block — orthogonal axis. With 196 dispatches today and growing, the hardcoded 5 will get cramped fast. Bigger N also helps debugging bursts ("show me the last 50 ollama-loop dispatches since 1h ago"). Default preserved (5) so existing operator muscle memory holds.

**Evidence:**
- `bin/fw` orchestrator status heredoc — `_recent_n` arg parse + validation, applied after filters.
- `tests/unit/test_orchestrator_status_terminal_events.py` — 5 new T-1787 tests.
- Combined regression: arc-suite green.

**Headline mechanic:** `bin/fw orchestrator status --recent 20 --worker-kind ollama-loop --since 1h` shows the last 20 ollama-loop dispatches from the last hour. Composable with everything.

## Evolution

### 2026-05-11 — view-density vs filter, kept orthogonal

- **What changed:** Considered making `--recent N` an alias for `--since` (i.e. "give me N rows worth of recent time"). Rejected: rows-per-unit-time is workload-dependent; explicit N is clearer than implicit time math. The two flags compose cleanly when both set.
- **Plan impact:** Default 5 (preserve), validate N>=1 (integer), apply slice AFTER filters so per-filter recent view is honest.
- **Triggered:** None.

## Decisions

## Updates

### 2026-05-11T11:10:00Z — task-created
- **Action:** Created task; arc-tagged orchestrator-rethink
- **Context:** View-density knob orthogonal to filter trio

## Reviewer Verdict (v1.5)

- **Scan ID:** R-533644ea
- **Timestamp:** 2026-06-02T14:59:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-11T11:09:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
