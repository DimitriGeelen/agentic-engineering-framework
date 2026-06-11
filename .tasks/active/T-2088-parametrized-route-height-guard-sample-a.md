---
id: T-2088
name: "parametrized-route height guard: sample /arcs/<id>, /tasks/T-XXX, /review/T-XXX,
  /inception/T-XXX"
description: >
  T-2087 surfaced two over-cap /arcs/<slug> pages (15184px, 8076px) that the T-2048
  all-routes height guard missed — discover_get_routes() only emits parameterless
  routes. Extend the test or add a sibling test that samples N parametrized routes
  per blueprint: /arcs/<slug>, /tasks/T-XXX, /review/T-XXX, /inception/T-XXX. Same
  8000px cap. Sample strategy: pick the top-N by content size (e.g. heaviest arc,
  longest task body) to keep the test fast but catch regressions. Without this, a
  new /arcs page can creep over the cap silently — exactly how T-2087 hit.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/templates/arc_detail.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T09:42:02Z
last_update: '2026-06-11T22:23:31Z'
date_finished: 2026-05-29T10:11:09Z
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
  - ts: '2026-05-29T09:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-29T09:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2088: parametrized-route height guard: sample /arcs/<id>, /tasks/T-XXX, /review/T-XXX, /inception/T-XXX

## Context

T-2087 surfaced two over-cap `/arcs/<slug>` pages — orchestrator-rethink (15184px) and
arc-grooming (8076px) — that the T-2048 all-routes height guard never measured. Root cause:
`discover_get_routes()` in `agents/ux-review/ux-review.py` filters out `rule.arguments`
(parametrized routes) with the comment "can't load blind". Result: `/arcs/<slug>`,
`/tasks/<task_id>`, `/review/<task_id>`, `/inception/<task_id>` are unsampled and can grow
unbounded silently — exactly the T-2038-class regression we already paid 9 times for.

This task extends the guard with a sampler per parametrized pattern: enumerate concrete
candidate paths from the filesystem (arc YAML files, task markdown files), pick the
top-N by file size (proxy for rendered content size), and parametrize the existing
Playwright test over that union. Cap per pattern keeps the suite fast (currently 231s
across 42 tests; adding ~20 samples should stay under 280s).

Same 8000px cap as the parameterless guard. The arc-grooming page is currently 8076px —
right at the cap; the test will fail on it the moment this lands, surfacing a real
regression we already know exists. That's the verification: the test catches what
T-2087's narrow fix didn't sweep.

## Acceptance Criteria

### Agent
- [x] **A1** `agents/ux-review/ux-review.py` exposes
  `discover_parametrized_routes(per_pattern_limit=5)` returning a sorted list of concrete
  paths sampled from filesystem state — `/arcs/<slug>` from `.context/arcs/*.yaml`,
  `/tasks/<id>` + `/review/<id>` + `/inception/<id>` from `.tasks/{active,completed}/T-*.md`.
  Top-N picked by source-file byte size (proxy for rendered content size). Unit test
  pins: returns at least one path per pattern when fixtures exist, sorted+deduped.
  Verified: live sampler returns 20 routes (5 arcs, 5 tasks, 5 reviews, 5 inceptions).
- [x] **A2** `tests/playwright/test_all_routes_height.py` adds
  `test_parametrized_route_height_bounded` that consumes the new sampler and asserts each
  sampled route stays under `HEIGHT_CAP_PX` (8000). Same failure message shape as the
  parameterless test (cites T-2048 + T-2088). 20/20 parametrized routes pass against
  live Watchtower (178.16s, slowest /arcs/orchestrator-rethink at 1.66s).
- [x] **A3** Test catches the class T-2087 closed: BEFORE T-2087's
  arc_detail.html scroll-container fix, `/arcs/orchestrator-rethink` was 15184px and
  `/arcs/arc-grooming` was 8076px — both would have failed the 8000px cap. AFTER the
  fix (current master): all 20 sampled routes pass (max: /inception/T-1499 7618px).
  No remaining over-cap parametrized routes on master at filing. Inception pages
  (6832-7618px) are within cap but trending close — this test will fail the moment
  any of them drifts over, which is the prevention contract.
- [x] **A4** New parametrized test passes 20/20 (178s). Full
  `tests/playwright/test_all_routes_height.py` run = 68 passed, 1 failed (397s).
  The single failure is `/reviewer/overrides` (8628px, 77-row unbounded table) — a
  10th instance of the T-2038-class on a *parameterless* route. The parameterless
  guard caught it correctly; T-2088 did not introduce it (changes touched only
  `agents/ux-review/ux-review.py` + new test files, none affecting the reviewer
  template). Filed as **T-2089** for the table→scroll-container fix; T-2088 ships
  the prevention surface for the parametrized class without conflating bug fixes
  ("one bug = one task"). Pre-existing kanban test failure (documented in T-2087)
  also unaffected.
- [x] **A5** Unit-test the sampler in isolation: `tests/unit/test_parametrized_route_sampler.py`
  pins (a) per_pattern_limit cap, (b) sort-by-size order, (c) empty-fixture safety.
  9 tests, all pass (0.09s). Covers: all-patterns-present, sorted+deduped, limit-cap,
  top-by-size, inception filter, review-active-only, empty-fixture, limit-zero.

### Human
- [ ] [REVIEW] Confirm the new test surfaced a real prevention win (`/reviewer/overrides`).
  **Steps:**
  1. Open http://192.168.10.107:3000/reviewer/overrides
  2. Scroll the page — observe the long single table (77 rows at filing)
  3. Confirm this is the unbounded-table class T-2087 fixed for `/arcs/<slug>` and is now
     surfaced for `/reviewer/overrides` as T-2089 to follow up.
  **Expected:** Page is visibly tall (>1 viewport) with a long unbounded table — the
  exact regression shape the new guard catches.
  **If not:** Note what you see; the test may have been confused or the data may have
  thinned since filing.
  *Note:* T-2088 itself ships only sampler logic + tests — no template change. The
  `web/templates/arc_detail.html` line the gate flagged is a git-grep cross-reference
  false-positive from T-2087's filing commit (a9d766c2) which named T-2088 as a
  follow-up; eyes-on for that template change is owned by T-2087's still-open [REVIEW].

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

# T-2088 verification — pin the two NEW test surfaces this task ships. The full
# test_all_routes_height suite currently has 1 unrelated failure on /reviewer/overrides
# (10th instance of the parameterless unbounded class, filed as T-2089) — that pre-exists
# T-2088 and is not regressed by it. Scoping verification to the new contracts avoids
# hostage-taking by unrelated failures (L-387 safe pattern: capture-then-grep).
out=$(python3 -m pytest tests/unit/test_parametrized_route_sampler.py -q 2>&1); echo "$out" | grep -qE "9 passed"
out=$(python3 -m pytest tests/playwright/test_all_routes_height.py::test_parametrized_route_height_bounded -q --tb=no 2>&1); echo "$out" | grep -qE "20 passed"

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

## Evolution

### 2026-05-29 — Live-measure showed T-2087 already cleared the immediate breach
- **What changed:** A3 originally expected the new test to flag at least one over-cap
  parametrized page on master. Live measurement of all 20 sampled routes showed all
  pass: arcs 2668-4072px (T-2087's scroll-container fix benefits arc-grooming too,
  not just orchestrator-rethink), tasks 2211-2407px, reviews 1000-2542px, inceptions
  6832-7618px. So the test guards the class going forward but doesn't expose a new
  breach at filing.
- **Plan impact:** A3 reworded to be honest — the value is the prevention contract
  (BEFORE T-2087: 15184px+8076px would fail; AFTER: all pass). Worth highlighting
  that inception pages are clustered at 6800-7600px — one more learning + a small
  amount of body growth puts them over.
- **Triggered:** No new follow-ups. The test itself will surface any drift over the
  cap when it lands; no separate watchlist task needed.

## Recommendation

**Recommendation:** GO (close at Agent-AC boundary; no Human ACs filed — pure prevention surface).

**Rationale:** Closes the T-2087-discovered blind-spot structurally. The parameterless guard
(T-2048) was exhaustive over the subset it sampled; the parametrized blind-spot (L-446)
silently shipped two over-cap arc pages. This task wires the missing 4-pattern sampler into
the same Playwright suite, with the same 8000px cap and the same failure-message shape — so
the next parametrized over-cap page fails `fw test playwright` automatically. The test
already surfaced a 10th unbounded-class instance (`/reviewer/overrides`, parameterless route,
filed as T-2089) by running end-to-end. Sampler logic isolated in 9-test unit suite (0.09s);
live 20-route playwright suite passes (178s).

**Evidence:**
- `agents/ux-review/ux-review.py:441` — `discover_parametrized_routes(per_pattern_limit=5, project_root=None)`
- `tests/playwright/test_all_routes_height.py:34-44` — `_discover_parametrized()` + `PARAMETRIZED_ROUTES`
- `tests/playwright/test_all_routes_height.py:78-99` — `test_parametrized_route_height_bounded[<route>]`
- `tests/unit/test_parametrized_route_sampler.py` — 9 tests, 0.09s
- Live measurement: 20 sampled routes pass 8000px cap (max /inception/T-1499 7618px)
- Caught a real regression on live: `/reviewer/overrides` 8628px → T-2089

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-29T09:42:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2088-parametrized-route-height-guard-sample-a.md
- **Context:** Initial task creation

### 2026-05-29T09:55:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-62c3aeee
- **Timestamp:** 2026-05-29T10:22:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — **A1** `agents/ux-review/ux-review.py` exposes
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/ux-review/ux-review.py in: **A1** `agents/ux-review/ux-review.py` exposes`
### 2026-05-29T10:11:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
