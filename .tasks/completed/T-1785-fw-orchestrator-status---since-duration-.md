---
id: T-1785
name: "fw orchestrator status --since DURATION: time-window filter (1h, 24h, 7d)"
description: >
  fw orchestrator status --since DURATION: time-window filter (1h, 24h, 7d)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [cli, observability]
components: [bin/fw, tests/unit/test_orchestrator_status_terminal_events.py]
related_tasks: [T-1779, T-1784]
arc_id: orchestrator-rethink
created: 2026-05-11T09:50:00Z
last_update: 2026-05-13T21:09:03Z
date_finished: 2026-05-13T21:09:03Z
---

# T-1785: fw orchestrator status --since DURATION: time-window filter (1h, 24h, 7d)

## Context

`fw orchestrator status` shows lifetime totals (196 dispatches and
growing). For "what's happened recently" — the natural follow-up
question to "what's happened ever" — operators want a time window.
`--since 1h` narrows to dispatches in the last hour; `--since 24h`,
`--since 7d`, etc.

Same filter-before-aggregation pattern as T-1784 (`--task`). Composes
with both `--task` and `--json`.

Duration syntax (intentionally minimal): `<int><unit>` where unit is
`m` (minutes), `h` (hours), `d` (days). Invalid formats → exit 1
with clear message.

## Acceptance Criteria

### Agent

**1. Duration parser**
- [x] Helper `_parse_duration(s) -> int seconds | None` handles
      `Nm`, `Nh`, `Nd`. Returns None for invalid.
- [x] Rejects negative, zero, missing unit, unknown unit.

**2. CLI flag**
- [x] `fw orchestrator status --since DURATION` accepts the duration string.
- [x] Filter applied BEFORE aggregation (same path as `--task`).
- [x] Header shows `Filter: since=<duration> (>= <iso timestamp>)`
      when active.
- [x] Empty result → notice `no dispatches in the last <duration>` exit 0.

**3. Composability**
- [x] `--since` composes with `--task` and `--json` and `--outcomes`.
- [x] When both `--task` and `--since` set, both filters apply (AND).

**4. Tests**
- [x] `tests/unit/test_orchestrator_status_terminal_events.py` extends with:
      - `_parse_duration` accepts `1m`, `24h`, `7d`
      - `_parse_duration` rejects bad inputs (negative, zero, no unit)
      - `--since 1h` narrows to recent rows only
      - `--since` empty notice when no rows match
      - `--since` + `--task` AND-composition
- [x] `python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py -v` exits 0.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py -v

## Recommendation

**Recommendation:** GO — second filter knob; composes with T-1784's `--task`.

**Rationale:** Lifetime totals answer "did the substrate ever work?" but operators usually want "is it working right now?". `--since 1h` gives the recent-activity slice. The intentionally minimal duration syntax (`Nm`, `Nh`, `Nd`) covers 99% of real queries; for finer windows, the operator can use `jq` on the raw JSONL. Same filter-before-aggregation pattern as T-1784 — composes cleanly with `--task` (per-task per-window) and with `--json` / `--outcomes`.

**Evidence:**
- `bin/fw` orchestrator status heredoc — `_parse_duration` + filter after synthetic exclusion.
- `tests/unit/test_orchestrator_status_terminal_events.py` — 5 new T-1785 tests.
- Combined regression: arc-suite green.

**Headline mechanic:** `bin/fw orchestrator status --since 24h` (optionally `--task T-XXX`) shows just the last day's dispatches across all breakdowns.

## Evolution

### 2026-05-11 — minimal duration grammar (m/h/d only)

- **What changed:** Considered supporting `--since 2026-05-10T00:00:00` (ISO timestamps) and freeform `30 minutes`. Rejected: timestamp arg adds quoting headaches; freeform parser is unbounded. Chose strict `<int><unit>` (m/h/d) — covers every realistic operator query without ambiguity. If `--since 30s` becomes a real need, the grammar can extend in one line.
- **Plan impact:** Reject anything that doesn't match `^[1-9]\d*[mhd]$`. Composes via subtraction from current UTC time.
- **Triggered:** None.

## Decisions

## Updates

### 2026-05-11T09:50:00Z — task-created
- **Action:** Created task; arc-tagged orchestrator-rethink
- **Context:** Time-window pair to T-1784's task filter

## Reviewer Verdict (v1.4)

- **Scan ID:** R-6bbf4357
- **Timestamp:** 2026-05-13T21:09:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-13T21:09:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
