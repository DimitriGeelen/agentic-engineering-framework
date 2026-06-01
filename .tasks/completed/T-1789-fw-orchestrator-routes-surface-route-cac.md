---
id: T-1789
name: "fw orchestrator routes: surface route-cache learned model preferences (CLI mirror of /orchestrator)"
description: >
  fw orchestrator routes: surface route-cache learned model preferences (CLI mirror of /orchestrator)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [cli, observability]
components: []
related_tasks: [T-1647, T-1669, T-1788]
arc_id: orchestrator-rethink
created: 2026-05-11T11:30:00Z
last_update: 2026-05-11T11:17:29Z
date_finished: 2026-05-11T11:17:29Z
---

# T-1789: fw orchestrator routes — surface route-cache learned preferences

## Context

`fw orchestrator status` (T-1699 + slice burst T-1779–T-1788) surfaces
dispatch substrate: what was dispatched, by what worker, with what
model. That answers "what got picked?". It does NOT answer "what has
the orchestrator learned about which model wins?" — the learning
state lives in `/var/lib/termlink/route-cache.json` and is currently
visible only via the web `/orchestrator` page (T-1669 step 3, T-1647).

`fw orchestrator routes` mirrors the web surface on the CLI:
reads route-cache.json, aggregates model_stats by task_type, prints
the leaderboard. Per-task-type "best model" + candidates with
success/failure rates.

This is the second half of the arc-demo's headline mechanic:
> "watches per-task-type model preferences shift as route_cache learns"

Without this CLI surface, the operator can't see learning state
unless they open the web UI. Both surfaces should agree.

## Acceptance Criteria

### Agent

**1. Subcommand**
- [x] `fw orchestrator routes` reads `/var/lib/termlink/route-cache.json`
      (with `$XDG_RUNTIME_DIR/termlink/route-cache.json` override).
- [x] When file is missing, prints "no route cache yet" + path; exits 0.
- [x] When file exists but `model_stats` is empty or invalid, prints
      "route cache has no model_stats yet"; exits 0.

**2. Output format**
- [x] Per-task-type section header: `task_type=<X> (best=<model>, total <N>)`.
- [x] Per-candidate row: `model successes/failures (rate %) last_used`.
- [x] Candidates sorted: rate desc, then total desc, then model alpha.
- [x] Task-types sorted alphabetically.

**3. JSON mode**
- [x] `--json` flag emits the same data structure as web's `_route_cache_learned`
      (available, path, by_task_type list, total_stats).

**4. Tests**
- [x] `tests/unit/test_orchestrator_routes.py` covers:
      - missing file → "no route cache yet"
      - empty model_stats → "no model_stats yet"
      - valid stats → per-task-type sections + sorted candidates
      - `--json` → parseable, matches web shape
      - last_used surfaced per candidate
      - invalid file (bad JSON) → graceful (not crash)
- [x] `python3 -m pytest tests/unit/test_orchestrator_routes.py -v` exits 0.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_orchestrator_routes.py tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_status_outcomes.py -v

## Recommendation

**Recommendation:** GO — closes the CLI/web parity gap on routing-learning state.

**Rationale:** The arc-demo's headline mechanic has two halves: (a) the orchestrator picks a model based on learned success rates, and (b) the user observes the preferences shift live. (a) is captured (T-1664 + T-1669 wrote into route-cache.json). (b) was visible on web /orchestrator only, T-1647. CLI operators running `fw orchestrator status` see the substrate (what fired) but not the learner's brain. This slice mirrors the web view on the CLI — same data, same shape. Closes a substrate-vs-surface parity gap that diverges as CLI gets richer than web.

**Evidence:**
- `bin/fw` orchestrator routes subcommand — reads route-cache.json, formats per-task-type leaderboard.
- `tests/unit/test_orchestrator_routes.py` — 6+ new tests covering empty, missing, valid, JSON, sorted, last_used.
- Combined regression: arc-suite green.

**Headline mechanic:** `bin/fw orchestrator routes` shows what the orchestrator has learned: per task_type, which models have the best success rate, with last-used timestamps. Operator on the CLI sees the same learning state the web /orchestrator does.

## Evolution

### 2026-05-11 — CLI/web parity, two halves of one demo

- **What changed:** T-1788 surfaced the dispatch substrate's model field; that answers "what got picked" but not "what does the orchestrator think wins". The route-cache.json is the second half — learned preferences. T-1647 surfaced this on web; CLI was the gap. Going to mirror the web view's shape exactly (available/path/by_task_type/total_stats) so any future divergence is a real divergence, not a translation artifact.
- **Plan impact:** Inline heredoc consistent with `fw orchestrator status`. No new lib module (defer DRY-extraction until 3rd consumer emerges). Test file separate from terminal_events suite — different data source, different concerns.
- **Triggered:** None — but if CLI/web ever diverge on shape, extract `lib/orchestrator.py` for shared parser.

## Decisions

## Updates

### 2026-05-11T11:30:00Z — task-created
- **Action:** Created task; arc-tagged orchestrator-rethink
- **Context:** CLI mirror of web /orchestrator's route-cache view

## Reviewer Verdict (v1.4)

- **Scan ID:** R-9bd3419a
- **Timestamp:** 2026-05-11T11:17:36Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `fw orchestrator routes` reads `/var/lib/termlink/route-cache.json`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=var/lib/termlink/route-cache.json in: `fw orchestrator routes` reads `/var/lib/termlink/route-cache.json``

### 2026-05-11T11:17:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
