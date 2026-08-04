---
id: T-1792
name: "Watchtower /orchestrator: add Dispatch substrate panel — by_model breakdown
  (CLI parity with T-1788)"
description: >
  Watchtower /orchestrator: add Dispatch substrate panel — by_model breakdown (CLI
  parity with T-1788)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [web, observability]
components: []
related_tasks: [T-1788, T-1789, T-1647]
arc_id: orchestrator-rethink
created: 2026-05-12T21:11:52Z
last_update: '2026-06-11T22:23:25Z'
date_finished: 2026-05-12T21:16:07Z
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
  - ts: '2026-06-11T22:23:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1792: Watchtower /orchestrator: add Dispatch substrate panel — by_model breakdown (CLI parity with T-1788)

## Context

The CLI `fw orchestrator status` shows substrate breakdowns from
`.context/dispatches.jsonl` — totals, by_task_type, by_worker_kind, and
(T-1788) by_model. The web `/orchestrator` page surfaces learned route-cache
preferences and recent `/tmp/tl-dispatch` workers but does NOT show the
underlying dispatch substrate.

This is a CLI→web parity gap. Web is where humans actually look; CLI is
the operator surface. The arc's headline mechanic ("operator observes the
routing decision live") presently has to choose between two half-surfaces.

Slice scope: add a "Dispatch substrate" panel mirroring the by_model
breakdown that CLI's `fw orchestrator status` already prints. Keep it
minimal — totals + by_model. by_task_type / by_worker_kind / outcomes are
follow-on slices (separate tasks).

Synthetic-row exclusion (`T-stress-*`) follows the CLI rule from T-1712
so the panel reflects only real arc-substrate signal.

## Acceptance Criteria

### Agent

**1. Helper function**
- [x] `_dispatch_substrate()` added to `web/blueprints/orchestrator.py`.
- [x] Reads `.context/dispatches.jsonl` (graceful: returns
      `{available: False, total: 0, by_model: {}}` if file missing or
      JSONL malformed).
- [x] Excludes synthetic rows (task_id startswith `T-stress-`) consistent
      with CLI's `_is_synthetic` (T-1712).
- [x] Returns `{available, path, total, synthetic_total, by_model}` shape.
- [x] `by_model` Counter excludes rows missing `model` (mirror of CLI
      T-1788 behavior).

**2. Template panel**
- [x] New `<h2>Dispatch substrate</h2>` panel added to
      `web/templates/orchestrator.html`, near the learned-routing section
      so the substrate→learned narrative reads top-down.
- [x] Shows totals (real + synthetic) and `by_model` breakdown sorted
      by count desc.
- [x] Empty-state message when `available=False` or `total=0`.

**3. Tests**
- [x] New file `tests/unit/test_orchestrator_dispatch_substrate.py`:
      - `_dispatch_substrate()` returns unavailable when no jsonl
      - returns available with totals + by_model when jsonl present
      - excludes synthetic T-stress-* rows from total + by_model
      - excludes rows missing model from by_model breakdown
      - graceful on malformed JSONL line (skips, continues)
      - sort by count desc
- [x] Route-level test: GET `/orchestrator` renders the by_model rows
      when substrate present.
- [x] `python3 -m pytest tests/unit/test_orchestrator_dispatch_substrate.py tests/unit/test_orchestrator_learned_routing.py tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_routes.py -v` exits 0.

### Human

- [x] [REVIEW] Render quality: the new Dispatch substrate panel visually
      belongs in /orchestrator — fits the page rhythm, by_model rows are
      legible.
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve` (if not running).
      2. Open `http://localhost:3000/orchestrator` in a browser.
      3. Locate the new "Dispatch substrate" section.
      **Expected:** Section renders cleanly, totals visible, by_model
      table sorted by count desc, no layout breakage on the rest of the page.
      **If not:** Note the rendering issue + screenshot the affected
      region; revert is one commit.

## Verification

python3 -m pytest tests/unit/test_orchestrator_dispatch_substrate.py tests/unit/test_orchestrator_learned_routing.py tests/unit/test_orchestrator_status_terminal_events.py tests/unit/test_orchestrator_routes.py -v

## Recommendation

**Recommendation:** GO — first CLI→web parity slice on the orchestrator arc. Closes the most visible observability gap (the routing-decision breakdown only existed on CLI).

**Rationale:** `fw orchestrator status` (CLI) and `/orchestrator` (web) are two halves of the same observability surface. Until this slice, the web view showed *learned* model preferences (route-cache, T-1669) and recent /tmp/tl-dispatch workers, but not the dispatch substrate breakdown the CLI exposes — so an operator who looked at the web page saw the recommendation engine's brain but not what it had actually picked. This panel mirrors `by_model` from T-1788's CLI surface: real-dispatch total, synthetic count, model breakdown sorted by count desc. Synthetic-row exclusion follows T-1712 / CLI rule. Minimum-slice scope: by_task_type / by_worker_kind / outcomes are deliberately deferred to follow-on tasks — keeping each panel a small, reviewable diff.

**Evidence:**
- `web/blueprints/orchestrator.py:_dispatch_substrate()` — 70 LOC pure helper, mirrors CLI shape, graceful on missing/malformed input.
- `web/blueprints/orchestrator.py:orchestrator_page` — passes `substrate=_dispatch_substrate()` to template.
- `web/templates/orchestrator.html` — new "Dispatch substrate" panel between Recent dispatches table region and Learned routing panel (substrate→learned narrative reads top-down on the page).
- `tests/unit/test_orchestrator_dispatch_substrate.py` — 8 tests covering missing-file, totals, synthetic exclusion, missing-model exclusion, malformed-line graceful, sort order, route-level rendered, route-level absent.
- Arc-suite regression: 94/94 green (was 77/77 before this slice; +8 new T-1792 + 9 carried from T-1669/T-1647 web tests now pinned together).
- Live smoke: `curl /orchestrator` against running Watchtower shows "196 real dispatch(es), plus 50 synthetic" + claude-3-5-sonnet-hermes3 row at 100%.

**Headline mechanic:** Open `/orchestrator` in a browser → see "Dispatch substrate" panel below "Recent dispatches" → read total dispatches and per-model counts at a glance — same information the CLI `fw orchestrator status` shows, now on the surface humans actually look at.

## Evolution

### 2026-05-12 — first CLI→web parity slice

- **What changed:** Through the prior session (T-1786..T-1790) I built five CLI filter knobs and one new CLI subcommand (`routes`), but did not surface any of that on the web view. The arc's headline mechanic ("operator observes the routing decision live") is *more* satisfied by the web page than by CLI parity — operators don't routinely `fw orchestrator status` but they do open Watchtower tabs. This slice acknowledges that the CLI is a forensic surface; the web is the discovery surface.
- **Plan impact:** Subsequent slices for `by_task_type` (T-1793 candidate) and `by_worker_kind` (T-1794 candidate) breakdowns on web should be filed as separate small tasks rather than bundled — same per-slice rhythm as T-1786..T-1791.
- **Triggered:** Sibling-task candidates noted in next-session-action list (by_task_type panel, by_worker_kind panel, outcome-quality panel). Web-side filter knobs are *not* needed yet — operators use the page for orientation, not forensics; filtering belongs on CLI.

## Decisions

## Updates

### 2026-05-12T21:11:52Z — task-created
- **Action:** Created task
- **Context:** CLI→web parity slice; closes the most visible
  observability gap (by_model on web)

### 2026-05-12T21:15:54Z — status-update [task-update-agent]
- **Change:** tags: +observability

## Reviewer Verdict (v1.4)

- **Scan ID:** R-924c2c05
- **Timestamp:** 2026-05-18T09:30:54Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `_dispatch_substrate()` added to `web/blueprints/orchestrator.py`.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/orchestrator.py in: `_dispatch_substrate()` added to `web/blueprints/orchestrator.py`.`
- **AC#2 (Agent)** — Reads `.context/dispatches.jsonl` (graceful: returns
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/dispatches.jsonl in: Reads `.context/dispatches.jsonl` (graceful: returns`
### 2026-05-12T21:16:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
