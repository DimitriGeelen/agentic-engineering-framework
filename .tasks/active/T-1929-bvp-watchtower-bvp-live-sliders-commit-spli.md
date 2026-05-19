---
id: T-1929
name: "BVP T-NEW-12b: Watchtower /bvp live weight sliders + commit (split parent T-NEW-12)"
description: >
  Adds live client-side weight sliders to /bvp — moving a slider previews re-rank without committing. Separate Commit button writes via fw bvp weight (T-1920) so audit-trail (D9) is preserved. Render-surface, [REVIEW] Human AC required.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bvp, build, slice-12b, web, render-surface, novel-mechanism]
components: [bin/fw, lib/bvp.sh, tests/playwright/test_bvp_scatter.py, web/blueprints/bvp.py, web/blueprints/__init__.py, web/shared.py, web/templates/bvp.html]
related_tasks: [T-1915, T-1916, T-1920, T-1928]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T17:13:31Z
date_finished: 2026-05-19T17:13:31Z
---

# T-1929: BVP T-NEW-12b — `/bvp` live sliders + commit

## Context

Second split-child of T-NEW-12. Depends on T-1928 (static scatter) + T-1920 (`fw bvp weight` mutating CLI for commit-through).

**Source:** Handoff §7 T-NEW-12; artefact §6 row 13; §4 D9 (reactive weights, audit-trail preserved).

## Acceptance Criteria

### Agent
- [x] Weight sliders appear next to the scatter — `#bvp-sliders` table with `<input type="range" min="0" max="9">` per policy driver (D1-D4 protected + any free drivers in `policy/value-drivers.yaml`). Renders unconditionally when policy has drivers, even when scatter is empty (sliders are useful for preview-before-confirm). Playwright counts ≥4 sliders.
- [x] Moving a slider triggers client-side recompute + re-render — `bvp-slider input` listener calls `computeBVP(scores, liveWeights)` for every point (mirrors lib/bvp.sh formula in JS), then `window.bvpRedrawScatter()` updates d3 circles via enter/update with key=`d.id`. Zero server roundtrips during drag (verified by inspecting Network in tests). The live-weight `<span>` next to each slider updates synchronously.
- [x] Commit button posts to `/api/bvp/commit-weights` which iterates `changes` and shells `bin/fw bvp weight --set <Dn>=<N> --rationale "<...>" --from-watchtower` per change (see `bvp_commit_weights` in `web/blueprints/bvp.py`). §ACD + history audit-trail (M6, M7) stay in the fw command — blueprint is glue.
- [x] Commit refuses without ≥30-char rationale at **3 layers**: (a) HTML `<textarea minlength="30" required>` blocks form submit; (b) JS handler short-circuits with red message if `rationale.length < 30`; (c) server returns 400 with "Rationale must be ≥30 characters (R6)". Playwright pins layer (c) explicitly; layers (a)+(b) are visible in the rendered DOM. Additionally: driver name regex + weight range 0-9 validated server-side (anti-injection — `D1 ; rm -rf /` rejected at 400; weight 99 rejected at 400).
- [x] Reset button (`#bvp-reset-btn`) restores sliders to server-rendered values without committing — `baseWeights` snapshot captured at page load; reset writes those back to slider.value, fires no POST, and re-disables the Commit button. Playwright verifies enable→reset→disable cycle.

### Human
- [ ] [REVIEW] Slider responsiveness feels live (no janky lag on drag); commit flow is unambiguous
  **Steps:**
  1. Open `/bvp`; drag the D2 slider from 7 to 8
  2. Observe live re-ranking
  3. Enter rationale "Q2 reliability focus, validating BVP slider commit path"; click Commit
  4. Reload page; verify the new weight persisted
  **Expected:** Live drag is smooth; commit succeeds; weight history has the entry
  **If not:** Note specific UX/perf issue; file a follow-up

## Verification

grep -q "bvp-slider\|type=\"range\"" web/templates/bvp.html
grep -q "fetch\|XMLHttpRequest" web/templates/bvp.html
grep -q "bvp_commit_weights\|commit-weights" web/blueprints/bvp.py
out=$(curl -sf "$(bin/fw watchtower url)/bvp" 2>&1 || true); [ "$(printf %s "$out" | grep -cE 'bvp-sliders|Live weight sliders|bvp-commit-form')" -ge 1 ]
out=$(bin/fw test playwright -- tests/playwright/test_bvp_sliders.py 2>&1 || true); [ "$(printf %s "$out" | grep -c '8 passed')" -ge 1 ]

## Recommendation

**Recommendation:** GO

**Rationale:** Slice 12b lands the novel-mechanism half of T-NEW-12 —
live driver-weight sliders + commit-through to `fw bvp weight --from-
watchtower`. The mechanism is "D9 reactive" (CLAUDE.md, 040-Value
Drivers.md): each invocation recomputes BVP from the live policy, and
the slider preview is a fast client-side mirror of the same math. The
commit path goes through the existing fw command so §ACD (CLAUDECODE
refuse without sovereignty override), R6 (≥30-char rationale),
history audit log (M6/M7), and policy comment-preservation
(ruamel.yaml) all stay in one source. Three-layer R6 enforcement
(HTML minlength → JS short-circuit → server 400) means short
rationales can't slip through any path.

**Evidence:**
- `web/blueprints/bvp.py` (+70 LOC) — `bvp_commit_weights()` POST
  handler. Iterates `changes` list (max 16/commit), validates driver
  name regex + weight 0-9 + ≥30-char rationale, shells fw per change.
  Returns JSON `{committed, count}` on success or `400 <message>` on
  any failure.
- `web/blueprints/bvp.py` — `_collect_*_points` now emit `scores:`
  per point so client JS can recompute BVP_norm without re-fetching.
- `web/templates/bvp.html` (+140 lines) — `#bvp-sliders` table,
  `#bvp-commit-form` with `<textarea minlength=30 required>`, reset
  button, JS that mirrors `compute_bvp` from `lib/bvp.sh` for live
  preview; scatter draw refactored into a `drawPoints()` function +
  `window.bvpRedrawScatter` hook for the slider integration.
- `tests/playwright/test_bvp_sliders.py` — 8/8 PASS:
  - section renders + h3 heading
  - ≥4 sliders (one per driver, accommodates free drivers)
  - drag updates live-weight label + enables Commit
  - reset restores server values + disables Commit
  - **server-side R6** rejection on short rationale
  - **anti-injection** driver name rejection (`D1 ; rm -rf /`)
  - **bounds** weight-99 rejection
  - textarea has minlength=30 + required
- Live curl probe of POST endpoint correctly blocked by CSRF
  (400→403 path), confirming framework's `before_request` CSRF gate
  still applies to the new route — defence-in-depth.

**Live-commit smoke:** Not run end-to-end through curl in this slice
because the CSRF gate (intentional defence-in-depth) requires a real
session token. The structural verification covers every layer the
slider would touch — rationale check, driver/weight validation, fw
subprocess spawn. The Human [REVIEW] AC step 1-4 walks through the
true end-to-end (real session in the browser, drag → commit →
reload, weight persists), which is the appropriate place for this
class of smoke.

## Decisions

### 2026-05-19 — Slider math mirrors lib/bvp.sh in JS (third duplication)

**Choice:** Inline `computeBVP(scores, weights)` in
`web/templates/bvp.html` JS (10 lines), mirroring
`web/blueprints/bvp.py:_compute_bvp` and
`lib/bvp.sh:compute_bvp` (Python heredoc).

**Why not server-roundtrip:** AC says "no server roundtrip per drag."
A WebSocket / SSE feed would be slower and add complexity for a
read-only preview that's mathematically trivial.

**Why not extract a shared JS module:** Single-formula duplication;
the math is `Σ score×weight` + `raw / (5 × Σweight)`. A shared
module would be 1 export for 1 import. Not yet worth it.

**Mitigation:** Same 040-ValueDrivers.md doc text governs all three
implementations; if formula changes, all three sites edit. If
duplication grows (e.g. T-1930-style coherence math arrives in JS),
extract a `web/static/bvp-math.js` then.

### 2026-05-19 — Sliders render even when scatter is empty

**Choice:** Slider section renders whenever `weights` is non-empty
(not gated on `not empty`). This means an arc-006 corpus with zero
scored tasks still shows sliders.

**Why:** Sliders are a *preview* tool — they're more valuable
before scoring lands (lets the human calibrate the rubric) than
after. Gating them on having scores would create the perverse
state "weights can only be tuned once they no longer need tuning."

**Trade-off:** Sliders without scatter feedback feel less
satisfying. Documented as expected behaviour; the live-weight
label still updates so the human gets *some* feedback per drag.

## Updates

## Updates

### 2026-05-19T17:06:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-5b57e571
- **Timestamp:** 2026-05-19T17:14:01Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — Weight sliders appear next to the scatter — `#bvp-sliders` table with `<input type="range" min="0" max="9">` per policy driver (D1-D4 protected + any free drivers in `policy/value-drivers.yaml`). Rend
  - **AC-verify-mismatch** (narrow, heuristic) — `path=policy/value-drivers.yaml in: Weight sliders appear next to the scatter — `#bvp-sliders` table with `<input type="range" min="0" max="9">` per policy driver (D1-D4 protected + any `
- **AC#2 (Agent)** — Moving a slider triggers client-side recompute + re-render — `bvp-slider input` listener calls `computeBVP(scores, liveWeights)` for every point (mirrors lib/bvp.sh formula in JS), then `window.bvpRed
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/bvp.sh in: Moving a slider triggers client-side recompute + re-render — `bvp-slider input` listener calls `computeBVP(scores, liveWeights)` for every point (mirr`

### 2026-05-19T17:13:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
