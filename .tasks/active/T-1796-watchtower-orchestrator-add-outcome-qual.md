---
id: T-1796
name: "Watchtower /orchestrator: add Outcome quality panel — verification pass/fail
  per task-type (CLI parity for --outcomes)"
description: >
  Watchtower /orchestrator: add Outcome quality panel — verification pass/fail per
  task-type (CLI parity for --outcomes)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [web, observability]
components: []
related_tasks: [T-1792, T-1794, T-1795, T-1749]
arc_id: orchestrator-rethink
created: 2026-05-12T21:32:28Z
last_update: '2026-05-28T22:54:09Z'
date_finished: 2026-05-12T21:36:35Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 3
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F1=0 (no-signal); F2=0
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1796: Watchtower /orchestrator: add Outcome quality panel — verification pass/fail per task-type (CLI parity for --outcomes)

## Context

The orchestrator arc's headline mechanic has three legs:
1. **Dispatch** — routing decision (which model picked for which task_type)
2. **Routing** — learned preferences (route-cache best/all candidates)
3. **Outcome** — quality signal (verification passed, AC satisfied)

After T-1792..T-1795, web /orchestrator shows legs 1 (Dispatch substrate
panel: by_model/by_task_type/by_worker_kind) and 2 (Learned routing
panel). Leg 3 (outcomes) is captured in `.context/dispatch-outcomes.jsonl`
(227 events as of session start) and aggregated by CLI's `--outcomes` flag
(T-1749), but never surfaced on web.

Slice scope: add a "Outcome quality" panel showing
verification_passed pass/fail counts per task_type. Mirror CLI's
verification-style aggregation. Don't touch verdict-style (T-1749's
shape-detection routes verdict-only events from escalation-scan-v0.5
through a different table — out of scope here; the verification-style
view is the canonical outcome surface for default-evaluator dispatches).

## Acceptance Criteria

### Agent

**1. Helper function**
- [x] `_outcome_quality()` added to `web/blueprints/orchestrator.py`.
- [x] Reads `.context/dispatch-outcomes.jsonl` and joins to dispatch rows
      by `dispatch_id` to pick up `task_type`.
- [x] Dedupes by dispatch_id, latest ts wins (mirror of CLI T-1757 rule).
- [x] Synthetic dispatches (`T-stress-*`) excluded.
- [x] Returns shape `{available, total_outcomes, by_task_type: [{task_type,
      passed, failed, total, pass_rate}, ...]}` sorted total desc.
- [x] Graceful on missing files / malformed lines.

**2. Template panel**
- [x] New `<h2>Outcome quality</h2>` panel between Dispatch substrate
      and Learned routing.
- [x] Per-task-type table with columns Task-type, Passed, Failed, Total,
      Pass rate (%).
- [x] Empty-state when no outcomes recorded.

**3. Tests**
- [x] `tests/unit/test_orchestrator_outcome_quality.py` (new file):
      - returns empty when no outcomes file
      - returns rows when seeded with dispatches + outcomes
      - dedupes by dispatch_id (latest ts wins)
      - excludes outcomes for synthetic dispatches
      - excludes outcomes with no matching dispatch
      - sorted total desc
      - route-level: HTML contains Outcome quality + rows
- [x] `python3 -m pytest tests/unit/test_orchestrator_outcome_quality.py tests/unit/test_orchestrator_dispatch_substrate.py tests/unit/test_orchestrator_learned_routing.py tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_routes.py -v` exits 0.

### Human

- [ ] [REVIEW] Panel fits the page flow: Outcome quality sits between
      substrate and learned-routing without breaking rhythm.
      **Steps:**
      1. Open `http://localhost:3000/orchestrator` in a browser.
      2. Verify panel order: Dispatch substrate → Outcome quality → Learned routing.
      **Expected:** Three panels stack cleanly.
      **If not:** Note rendering issue + screenshot.

## Verification

python3 -m pytest tests/unit/test_orchestrator_outcome_quality.py tests/unit/test_orchestrator_dispatch_substrate.py tests/unit/test_orchestrator_learned_routing.py tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_routes.py -v

## Recommendation

**Recommendation:** GO — closes the third leg of the arc's headline mechanic on web.

**Rationale:** Before this slice, web `/orchestrator` showed routing decisions (T-1792's by_model) and learned preferences (T-1669's Learned routing) but never closed the loop on outcomes — the leg that tells you if any of this is actually *working*. With 227 outcome events already recorded, surfacing per-task-type verification pass/fail is a one-screen answer to "is the orchestrator producing good outputs?" Joining dispatches + outcomes by dispatch_id and deduping by latest ts (T-1757 rule) keeps the math correct under append-only / replay semantics. Verdict-style outcomes are surfaced in the total but excluded from pass/fail (no verification_passed field) — clean separation of evaluator shapes per T-1749.

**Evidence:**
- `web/blueprints/orchestrator.py:_outcome_quality()` — ~100 LOC pure helper, joins+dedups+aggregates+sorts, graceful on missing files / malformed lines.
- `web/blueprints/orchestrator.py:orchestrator_page` — passes `outcome_quality` payload to template.
- `web/templates/orchestrator.html` — new "Outcome quality" panel between Dispatch substrate and Learned routing, with passed/failed badge styling and pass-rate column gated on decided rows.
- `tests/unit/test_orchestrator_outcome_quality.py` — 10 tests covering missing-file, aggregation, dedupe, synthetic exclusion, orphan-outcome exclusion, sort order, verdict-style edge, graceful-on-missing-dispatches, and two route-level renders.
- Combined arc-suite regression: 110/110 green (was 100/100 before this slice).
- Live render confirmed: panel renders against 246-dispatch / 227-outcome substrate.

**Headline mechanic:** Open `/orchestrator` → Dispatch substrate (what got picked) → Outcome quality (did it work?) → Learned routing (what does the cache now prefer?) — three panels read top-down, complete arc story in one scroll.

## Evolution

### 2026-05-12 — third leg of headline mechanic landed on web

- **What changed:** The arc's headline mechanic on the web view was structurally one-legged: routing decisions visible (T-1792), learned state visible (T-1669), but outcome quality was substrate-only (CLI `--outcomes` from T-1749). Until now an operator could see the decisions the orchestrator made but had no surface to assess whether those decisions were *good*. Adding this panel makes outcome quality first-class on web.
- **Plan impact:** With this slice, the web `/orchestrator` page covers the arc's full headline-mechanic story. Remaining gaps are narrow: terminal_event surface (CLI has T-1779/T-1781 but substrate-side terminal_event is still empty — not actionable today), and verdict-style outcome breakdown (escalation-scan-v0.5 verdicts could get their own sub-table). Both wait for substrate signal.
- **Triggered:** None. The arc's web observability is now headline-mechanic complete. Next-session work belongs on either: substrate population (TermLink worker primitive, dispatch driver enrichment) or new arc surfaces.

## Decisions

## Updates

### 2026-05-12T21:32:28Z — task-created
- **Action:** Created task
- **Context:** Third leg of headline mechanic — outcome quality on web

### 2026-05-12T21:35:39Z — status-update [task-update-agent]
- **Change:** tags: +observability

## Reviewer Verdict (v1.4)

- **Scan ID:** R-62138cb0
- **Timestamp:** 2026-05-18T09:30:54Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `_outcome_quality()` added to `web/blueprints/orchestrator.py`.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/orchestrator.py in: `_outcome_quality()` added to `web/blueprints/orchestrator.py`.`
- **AC#2 (Agent)** — Reads `.context/dispatch-outcomes.jsonl` and joins to dispatch rows
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/dispatch-outcomes.jsonl in: Reads `.context/dispatch-outcomes.jsonl` and joins to dispatch rows`
### 2026-05-12T21:36:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
