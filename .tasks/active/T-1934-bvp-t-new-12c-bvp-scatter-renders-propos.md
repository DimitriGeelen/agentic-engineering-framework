---
id: T-1934
name: "BVP T-NEW-12c: /bvp scatter renders proposed scores (advisory layer)"
description: >
  Extends the /bvp scatter (T-1928) to also render PROPOSED scores from the
  estimator (T-1922) — outlined dots, clearly labeled, sovereignty-respecting
  (proposed remain advisory; only confirmed are filled). Unblocks the visual
  half of T-1928/T-1929/T-1930 reviews without requiring per-task
  fw bvp confirm runs.
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-12c, web, render-surface]
components: [web/blueprints/bvp.py, web/templates/bvp.html, tests/playwright/test_bvp_scatter.py]
related_tasks: [T-1915, T-1916, T-1922, T-1923, T-1928]
arc_id: value-prioritisation
created: 2026-05-19T18:36:52Z
last_update: 2026-05-19T18:36:52Z
date_finished: null
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
- [ ] `web/blueprints/bvp.py:_collect_task_points` returns BOTH confirmed AND proposed points, each tagged with `proposed: bool`. Empty `bvp_scores:` with non-empty `bvp_scores_proposed:` uses the latest proposed entry's `scores`.
- [ ] Same change for `_collect_arc_points`.
- [ ] `web/templates/bvp.html` renders confirmed and proposed points distinctly — confirmed as filled circles, proposed as outlined (`stroke-only`) circles. Tooltip explicitly labels which class each point is (`(proposed)` suffix if applicable).
- [ ] Page key/legend explains the distinction in 1-2 lines near the scatter.
- [ ] `empty` flag no longer fires when there are only proposed points — the empty-state is only shown when neither confirmed nor proposed are populated.
- [ ] Playwright test verifies: (a) page renders with proposed-only corpus, (b) at least one outlined point exists in the SVG, (c) legend text references "proposed".

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
out=$(bin/fw test playwright -- tests/playwright/test_bvp_scatter.py 2>&1 || true); [ "$(printf %s "$out" | grep -cE 'passed')" -ge 1 ]

## RCA

<!-- Non-bug-class task — RCA not required. -->

## Evolution

### 2026-05-19 — Filing
- **What changed:** T-1922 + T-1923 just shipped — 53 active tasks now carry `bvp_scores_proposed:` from the heuristic estimator. The scatter (T-1928) was designed for confirmed-only and shows empty even though there's real data.
- **Plan impact:** None — this is an additive extension to T-1928 that respects the same sovereignty boundary.
- **Triggered:** Filed in-session because the user identified that the empty scatter blocks T-1928/29/30 reviews. T-1934 closes the gap WITHOUT requiring batch-confirms.

## Decisions

## Updates
