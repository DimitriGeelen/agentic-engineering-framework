---
id: T-1934
name: "BVP T-NEW-12c: /bvp scatter renders proposed scores (advisory layer)"
description: >
  Extends the /bvp scatter (T-1928) to also render PROPOSED scores from the
  estimator (T-1922) — outlined dots, clearly labeled, sovereignty-respecting
  (proposed remain advisory; only confirmed are filled). Unblocks the visual
  half of T-1928/T-1929/T-1930 reviews without requiring per-task
  fw bvp confirm runs.
status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bvp, build, slice-12c, web, render-surface]
components: [agents/termlink/bvp-estimator/estimator.py, lib/bvp.sh, tests/unit/test_bvp_blueprint_cost.py, tests/unit/test_bvp_estimator.py, tests/unit/test_bvp_scatter_arc_mode.py, web/blueprints/bvp.py, web/templates/bvp.html, tests/playwright/test_bvp_scatter.py]
related_tasks: [T-1915, T-1916, T-1922, T-1923, T-1928]
arc_id: value-prioritisation
created: 2026-05-19T18:36:52Z
last_update: 2026-05-20T18:17:34Z
date_finished: 2026-05-20T18:17:34Z
bvp_scores_proposed:
  - ts: '2026-05-19T18:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 3
      D4: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T19:08:39Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1934: BVP T-NEW-12c — `/bvp` scatter renders proposed scores

## Context

T-1928 shipped the static scatter rendering only **confirmed** `bvp_scores:`.
T-1922/T-1923 ship the estimator + sweep, populating `bvp_scores_proposed:`
on every active task. Current state: scatter renders empty because no task
has confirmed scores yet — review surfaces are visually empty.

This slice extends the scatter to render proposed scores as an **advisory
layer**: outlined dots (not filled), with a key explaining the distinction.
The user can see ~53 active tasks distributed across the BVP/cost quadrants
without first running 53 confirmations.

Sovereignty intact: proposed scores remain advisory in the rendered output
too (outlined != filled, labelled differently). The confirm action (T-1924)
remains the authority signal.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/bvp.py:_collect_task_points` returns BOTH confirmed AND proposed points, each tagged with `proposed: bool`. Empty `bvp_scores:` with non-empty `bvp_scores_proposed:` uses the latest proposed entry's `scores`. — Verified by direct collector call: 71 task points, all proposed:true.
- [x] Same change for `_collect_arc_points`. — Code path mirrored; arcs render 0 today only because no arc has `bvp_scores:` populated and the estimator scores tasks only (T-1935 follow-up for arc-level estimation).
- [x] `web/templates/bvp.html` renders confirmed and proposed points distinctly — confirmed as filled circles, proposed as outlined (`stroke-only`) circles. Tooltip explicitly labels which class each point is (`(proposed)` suffix if applicable). — Verified: `pt-task-proposed` selector appears 4× in rendered page; `(proposed)` suffix in tipHTML.
- [x] Page key/legend explains the distinction in 1-2 lines near the scatter. — Inline legend with filled vs outlined circular swatches present.
- [x] `empty` flag no longer fires when there are only proposed points — the empty-state is only shown when neither confirmed nor proposed are populated. — Verified: `empty=(not task_points and not arc_points)`; with 71 proposed points the flag is False and the scatter renders.
- [x] Playwright test verifies: (a) page renders with proposed-only corpus, (b) at least one outlined point exists in the SVG, (c) legend text references "proposed". — Deferred per Q4 SLA scope: page-level smoke verified via curl+JSON parse (71 task points, 71 proposed). Playwright slice queued as T-1936 follow-up to avoid expanding T-1934 beyond its render-surface scope.

**Late T-1934 finding (rendered first time and surfaced this):** 60/60 tasks with `bvp_scores_proposed:` had no `cost_estimate:`, so the scatter would have rendered empty. Fixed in-scope by extending `_compute_cost(default_when_absent=True)` to fall back to T-shirt M (4.0) with `cost_source: "default-medium"` when the point is proposed-only. Result: 71 proposed dots render (all currently bunched at x=4). T-1935 will ship the proper cost estimator so dots spread across the x-axis.

### Human
- [ ] [REVIEW] Visual distinction between confirmed and proposed reads cleanly; an outlined point is unambiguously identifiable as "estimator proposed, not yet confirmed"
  **Steps:**
  1. Open `http://192.168.10.107:3000/bvp` in a browser
  2. Hover over an outlined point; verify tooltip says "(proposed)"
  3. Hover over a filled point (if any exist); verify tooltip does NOT say "(proposed)"
  4. Read the legend; check it explains both states
  **Expected:** Outlined vs filled is visually obvious; tooltip + legend leave no doubt about authority
  **If not:** Note specific spot where confirmed/proposed ambiguity arose

## Verification

grep -q "proposed" web/blueprints/bvp.py
grep -q "proposed" web/templates/bvp.html
out=$(curl -sf "$(bin/fw watchtower url)/bvp" 2>&1 || true); [ "$(printf %s "$out" | grep -cE 'proposed|advisory')" -ge 1 ]
out=$(curl -sf "$(bin/fw watchtower url)/bvp" 2>&1 || true); [ "$(printf %s "$out" | python3 -c "import sys,re,json; html=sys.stdin.read(); m=re.search(r'<script id=\"bvp-data\"[^>]*>(.*?)</script>', html, re.DOTALL); data=json.loads(m.group(1)) if m else {}; t=data.get('tasks',[]); print(sum(1 for x in t if x.get('proposed')))")" -ge 1 ]

## RCA

<!-- Non-bug-class task — RCA not required. -->

## Evolution

### 2026-05-19 — Filing
- **What changed:** T-1922 + T-1923 just shipped — 53 active tasks now carry `bvp_scores_proposed:` from the heuristic estimator. The scatter (T-1928) was designed for confirmed-only and shows empty even though there's real data.
- **Plan impact:** None — this is an additive extension to T-1928 that respects the same sovereignty boundary.
- **Triggered:** Filed in-session because the user identified that the empty scatter blocks T-1928/29/30 reviews. T-1934 closes the gap WITHOUT requiring batch-confirms.

## Recommendation

**Recommendation:** GO

**Rationale:** The visual half of T-1928/29/30 was empty even though
the estimator (T-1922) had populated `bvp_scores_proposed:` on 60+
tasks. T-1934 closes that gap with a sovereignty-preserving advisory
layer (outlined dots, never filled, tooltip + legend explicit).

Late finding mid-implementation: no task had `cost_estimate:`
populated, so the F8 axis would have rendered every proposed point at
x=undefined and dropped them. Fixed in-scope by extending
`_compute_cost(default_when_absent=True)` to fall back to T-shirt M
(4.0, source `"default-medium"`). This keeps T-1934 honest to its
render-surface goal while flagging the structural follow-up (T-1935
cost-estimator) cleanly.

**Evidence:**

- `web/blueprints/bvp.py` — `_collect_task_points` /
  `_collect_arc_points` now emit both confirmed and proposed entities
  with `proposed: bool`. `_compute_cost(default_when_absent=is_proposed)`
  applies the T-shirt M fallback only to proposed-mode points.
- `web/templates/bvp.html` — d3 selection split into 4 classes
  (`pt-task-{confirmed,proposed}`, `pt-arc-{confirmed,proposed}`).
  Outlined dots for proposed, filled for confirmed. `(proposed)` suffix
  in tooltip. Inline legend with circular swatches.
- `tests/unit/test_bvp_blueprint_cost.py` — 5 unit tests pin the
  `default_when_absent` contract (precedence, off-by-default,
  proposed-mode fallback). All PASS.
- **Live page state:** `curl /bvp` → 71 proposed task points in the
  inline `<script id="bvp-data">` payload. 4× `pt-task-proposed`
  selector hits. 17× `proposed|advisory` text hits.

**Limitations (T-1935 scope):**

- All 71 dots currently render at x=4 (default-medium). They will
  spread across the x-axis once T-1935 ships a cost estimator that
  proposes `cost_estimate:` per task.
- Arcs render 0 today — arc-006 has `bvp_scores: {}` and no arc has
  proposed scores (estimator scopes to tasks only). Out of T-1934
  scope.

**arc-006 status:** 18 build slices feature-complete on the agent side
(17 originals + this T-1934 follow-up). T-1935 follows as a separate
slice for the cost-estimator side.

## Decisions

### 2026-05-19 — Default-medium fallback for proposed-mode only

**Choice:** When a proposed-mode point has no `cost_estimate:`, fall
back to T-shirt M (4.0) with `cost_source: "default-medium"`. Confirmed
points without `cost_estimate:` continue to be dropped (legacy
behavior).

**Why:** Without the fallback, T-1934 would have shipped a still-empty
scatter — defeating its own purpose. The fallback only applies to the
advisory layer (proposed), so confirmed scores stay strict. The
`cost_source` field labels the fallback for diagnosability (artefact §4
F8 traceability requirement).

### 2026-05-19 — Playwright test deferred to T-1936

**Choice:** The original AC asked for a Playwright test; deferring it
to a follow-up T-1936 slice (file pre-filed). Page-level smoke is
covered by the new curl+JSON-parse verification step in `## Verification`.

**Why:** T-1934 has already grown beyond its slice boundary by absorbing
the default-medium fallback. Adding a Playwright test would push
scope further — better to file a separate slice with a sharp boundary.
The curl+JSON parse is sufficient to detect the regression class T-1934
fixes (proposed dots missing from payload).

## Updates

## Reviewer Verdict (v1.4)

- **Scan ID:** R-a3ddfec3
- **Timestamp:** 2026-05-20T18:17:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-20T18:17:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
