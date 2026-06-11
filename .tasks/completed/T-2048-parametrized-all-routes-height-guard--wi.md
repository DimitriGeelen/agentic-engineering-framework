---
id: T-2048
name: "Parametrized all-routes height guard — wire the exhaustive sweep into the test
  suite (T-2042 capability → automation)"
description: >
  T-2042 made the ux-review detector exhaustive (discover_get_routes over app.url_map)
  but only as an opt-in --all-routes flag; the default sweep and (absent) cron still
  cover only 5 pages, so the next unbounded Watchtower page would NOT be caught automatically.
  Add a parametrized Playwright test iterating discover_get_routes() asserting every
  parameterless GET route renders < 8000px (TALL_PAGE_CAP_PX). Runs with the existing
  suite, no cron/screenshots, catches the next instance the moment a new page is added.
  Closes the G-019 automation leg of the unbounded-page class.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc-007, perf, watchtower, testing, prevention]
components: []
related_tasks: [T-2042, T-2046]
arc_id: watchtower-redesign
created: 2026-05-25T15:43:02Z
last_update: '2026-06-11T22:24:05Z'
date_finished: 2026-05-25T17:53:31+02:00
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
bvp_scores_proposed:
  - ts: '2026-05-25T15:43:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-25T15:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2048: Parametrized all-routes height guard — wire the exhaustive sweep into the test suite (T-2042 capability → automation)

## Context

T-2042 closed the *capability* gap (the ux-review height detector can sweep every parameterless GET route via `discover_get_routes()` over `app.url_map`), but only behind the opt-in `--all-routes` flag — the default `--sweep` and the (non-existent) cron still cover only 5 hard-coded pages. That means the next unbounded Watchtower page would still grow undetected (the exact G-019 root that hid /inception, /timeline, /gaps, /learnings, /decisions, /graduation, /docs/generated). This task wires the exhaustive sweep into the **existing test suite** as a parametrized Playwright test, so any new over-cap page fails CI/`fw test playwright` the moment it's added — no cron, no screenshots, no manual flag. This is the automation leg that complements the per-page regression guards (T-2041/43/44/45/46/47) and the capability (T-2042).

This task only adds a test file — no render surface is touched, so all ACs are agent-verifiable (no `[REVIEW]` needed).

## Acceptance Criteria

### Agent
- [x] `tests/playwright/test_all_routes_height.py` added — parametrizes over `discover_get_routes()` (loaded from `agents/ux-review/ux-review.py`) and asserts each route's rendered `scrollHeight` < 8000px (TALL_PAGE_CAP_PX)
- [x] The test discovers > 5 routes (proves it uses the exhaustive list, not the 5-page hard-code) and skips gracefully if the route map can't be imported — **`test_routes_discovered_exhaustively` passed (47 routes)**
- [x] All discovered routes pass (regression baseline green now that the class is closed) — **49 passed (47 route checks + 2 contract tests) in 178s**
- [x] `HEIGHT_CAP_PX` mirrors `agents/ux-review/ux-review.py:TALL_PAGE_CAP_PX` so the guard and the detector stay in lockstep — **`test_height_cap_matches_detector` passed**

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
cd tests/playwright && python3 -m pytest test_all_routes_height.py -q 2>&1 | tail -3; cd "$OLDPWD"

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

Not a bug fix — this is the *prevention* deliverable for the unbounded-page class. The class RCA lives in the per-page tasks (T-2041..T-2047); the structural omission was "the detector swept only 5 hard-coded pages" (closed as a capability by T-2042, as automation here).

## Evolution

### 2026-05-25 — capability without invocation is not prevention
- **What changed:** While verifying the class was closed, I found T-2042's exhaustive sweep is opt-in (`--all-routes`) and has no cron — so the framework still wouldn't catch the *next* unbounded page automatically. Fixing 9 pages + building a detector ≠ wiring the detector to run.
- **Plan impact:** Chose the test-suite route over a cron job: a parametrized Playwright test is cheaper (no screenshots), runs with the existing suite (`fw test playwright`), needs no cron-registry/generate/install cycle, and fails fast in CI/pre-merge rather than a day later on a daily cron.
- **Triggered:** This task (T-2048), filed as the automation leg distinct from T-2042's capability.

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-05-25 — test suite over cron for the automation leg
- **Chose:** A parametrized Playwright test (`test_all_routes_height.py`) that iterates `discover_get_routes()` and asserts each route < cap, run by the existing suite.
- **Why:** Fails fast at CI/pre-merge (the moment a new unbounded page is added), needs no cron-registry→generate→install cycle (and its drift gates), no screenshots (cheap), and keeps the guard co-located with the per-page guards. A `test_height_cap_matches_detector` contract test prevents the guard and the detector silently diverging.
- **Rejected:** A daily `fw ux-review --all-routes` cron — catches regressions a day late, costs screenshot time, and adds cron-drift surface (L-364). Making `--all-routes` the *default* sweep — would change existing ux-review behaviour and still needs something to invoke it. Both remain viable as a *belt-and-suspenders* daily check if the human wants defence-in-depth (noted as a possible follow-up).

## Recommendation

**Recommendation:** GO

**Rationale:** Closes the automation leg of the unbounded-page class: the next over-cap page now fails the test suite automatically, with a contract test keeping the guard in lockstep with the detector. Test-only change, no render surface, fully agent-verifiable — no human review needed.

**Evidence:**
- `tests/playwright/test_all_routes_height.py` — **49 passed** (47 route checks + 2 contract tests) in 178s
- Discovers 47 routes (> 5 hard-code) via `discover_get_routes()`; skips gracefully if the map can't import
- `HEIGHT_CAP_PX == TALL_PAGE_CAP_PX` pinned by `test_height_cap_matches_detector`
- Class fully closed: all 47 routes under 8000px (exhaustive sweep, this session)

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-25T15:43:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2048-parametrized-all-routes-height-guard--wi.md
- **Context:** Initial task creation

### 2026-05-25T15:43:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-35f26b6e
- **Timestamp:** 2026-06-02T15:00:53Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `tests/playwright/test_all_routes_height.py` added — parametrizes over `discover_get_routes()` (loaded from `agents/ux-review/ux-review.py`) and asserts each route's rendered `scrollHeight` < 8000px (
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/playwright/test_all_routes_height.py in: `tests/playwright/test_all_routes_height.py` added — parametrizes over `discover_get_routes()` (loaded from `agents/ux-review/ux-review.py`) and asser`
- **AC#4 (Agent)** — `HEIGHT_CAP_PX` mirrors `agents/ux-review/ux-review.py:TALL_PAGE_CAP_PX` so the guard and the detector stay in lockstep — **`test_height_cap_matches_detector` passed**
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/ux-review/ux-review.py in: `HEIGHT_CAP_PX` mirrors `agents/ux-review/ux-review.py:TALL_PAGE_CAP_PX` so the guard and the detector stay in lockstep — **`test_height_cap_matches_d`
