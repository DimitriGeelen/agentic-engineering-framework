---
id: T-2029
name: "arc-007 S3b — cockpit density spacing (scale-multiply)"
description: >
  arc-007 S3b — make the cockpit the first consumer of the density spacing axis:
  wrap every rem/px spacing in calc(<value> * var(--wt-density-scale)) so the
  Compact/Cozy/Comfortable control visibly tightens/loosens layout (not just font).
  Human-approved approach (scale-multiply); ready to build with a full budget window.

status: work-completed
workflow_type: build
owner: human
horizon: now
arc_id: watchtower-redesign
tags: [arc:watchtower-redesign, ui, watchtower, cockpit, density]
components: [tests/playwright/test_cockpit_density_spacing.py, 
      tests/unit/test_cockpit_density_spacing.py, web/templates/cockpit.html]
related_tasks: [T-1990, T-1987, T-2024, T-1991]
created: 2026-05-24T12:58:23Z
last_update: '2026-06-11T22:23:30Z'
date_finished: 2026-05-25T22:43:25Z
cost_estimate_proposed:
  - ts: '2026-05-24T13:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-25T13:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-24T13:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2029: arc-007 S3b — cockpit density spacing (scale-multiply)

## Context

**Finding (this enables the slice):** the Density control on `/appearance`
(Compact/Cozy/Comfortable) sets `data-wt-density` on `<html>` and persists it. Its
FONT-SIZE axis works (`--wt-font-size` / `--pico-font-size` are consumed), but the
SPACING axis is **inert** — *zero* templates consume `--wt-space` / `--wt-row-pad`, so
changing density does nothing to layout spacing. S3b makes the cockpit the first
consumer, so density visibly tightens/loosens spacing.

**Human-approved approach (2026-05-24, AskUserQuestion — "Scale-multiply"):** wrap each
cockpit rem/px spacing in `calc(<value> * var(--wt-density-scale))`. Density-scale is
`0.875 / 1 / 1.125` for compact/cozy/comfortable (foundations.css:224-226). At Cozy
(scale=1) the layout is pixel-identical to today; Compact/Comfortable scale the rhythm
proportionally. No new tokens; preserves the current visual rhythm.

**Scope = cockpit.html only** (the pilot consumer). 54 rem/px spacing sites across the
`<style>` block (~13) and inline `style="…"` article attributes (~41).

### Exclusion rules (critical — get these right or rhythm breaks)
WRAP (multiply by `var(--wt-density-scale)`):
- `padding`, `margin`, `gap` (and `-top/-bottom/-left/-right` variants) expressed in **rem or px**.

DO NOT WRAP:
- **`em`-based spacing** (6 sites) — already scales with font-size (density changes
  `--wt-font-size`); wrapping would double-scale. Leave as-is.
- **`border-radius`** (9 sites, rem/px) — corner radius, not spacing.
- **`border` / `border-left` / `border-width`** — line weight, not spacing.
- **`font-size`, `letter-spacing`** — typography axis, handled separately.
- **`min-width` / `min-height` / grid track sizes (`1fr`, `1.5em`)** — sizing, not spacing.

## Acceptance Criteria

### Agent
- [x] Every rem/px `padding`/`margin`/`gap` in cockpit.html (`<style>` block + inline) wrapped in `calc(<value> * var(--wt-density-scale))`
- [x] No `em`-based spacing, `border-radius`, `border-*`, `font-size`, or `letter-spacing` was wrapped (exclusion rules honoured)
- [x] cockpit.html still compiles (jinja `get_template`)
- [x] Unit test `tests/unit/test_cockpit_density_spacing.py` passes (sample of spacing rules use `calc(… * var(--wt-density-scale))`; border-radius/font-size untouched)
- [x] Playwright test `tests/playwright/test_cockpit_density_spacing.py` passes: at `data-wt-density="cozy"` a sampled element's computed padding equals the pre-change baseline; at `compact` it is ~×0.875 (spacing axis now responds)

### Human
- [ ] [REVIEW] Cockpit looks identical at Cozy and visibly tightens at Compact / loosens at Comfortable, with the rhythm staying coherent
  **Steps:**
  1. Open the Watchtower cockpit (`bin/fw watchtower url` → `/` cockpit) at `/appearance` density = Cozy
  2. Compare to the current cockpit (should be pixel-identical at Cozy)
  3. Switch density to Compact, then Comfortable; watch the cockpit re-layout
  **Expected:** Cozy unchanged; Compact tighter; Comfortable looser; no element collides, overflows, or loses its rhythm at any level
  **If not:** note the element + density level; a specific spacing may be wrapped wrong (em double-scaled) or missed

## Verification

out=$(cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_cockpit_density_spacing.py -q 2>&1); echo "$out" | tail -3; echo "$out" | grep -q "passed"
python3 -c "import sys; sys.path.insert(0,'.'); from web.app import app; app.jinja_env.get_template('cockpit.html'); print('compiles')"

## Evolution

### 2026-05-24 — filed ready-to-build (scope revealed by investigation)
- **What changed:** Investigating S3b revealed (a) the density SPACING axis is currently inert (font-size works, spacing doesn't — arguably a latent bug in the appearance control), and (b) the cockpit has 54 rem/px spacing sites mixed with em-spacing/border-radius/font-size that must NOT be wrapped. The exclusion rules are the real content of this slice.
- **Plan impact:** S3b is an *atomic* render slice (the whole cockpit must scale together or density looks janky) with rhythm-preservation as the correctness bar — deserves a full budget window, not a tail-end start. Filed human-approved + fully-scoped rather than started at 53% budget.
- **Triggered:** Consider a follow-up to roll the same scale-multiply to other high-density pages (tasks board, approvals) once the cockpit pilot is validated — would make the density control global, not cockpit-only.

### 2026-05-24 — build: actual count 37 spacing values; font-size compounding measured
- **What changed:** The "54 sites" filing estimate over-counted — it folded in font-size (37
  sites, excluded) and em-spacing (6, excluded). The authoritative count is **37 rem/px
  padding/margin/gap values** wrapped; every remaining unwrapped rem/px value is a legitimate
  exclusion (37 font-size, 9 border-radius, 7 border, 1 media-query max-width — verified by a
  classify-all-rem/px grep). Diff is a clean 37-insert/37-delete 1:1 line swap.
- **Measured (T-2031 lesson — don't reason, measure):** the density control ALSO shifts the
  root font-size (`--pico-font-size` 100/112.5/125%), so a `calc(1rem * scale)` value moves for
  *two* reasons at once — the rem-anchor (font axis) AND the density-scale (spacing axis). Net
  effect: compact/comfortable change *more* in raw px than the bare 0.875/1.125, while **cozy
  stays pixel-identical** (scale=1, and cozy is today's default). The Playwright test isolates
  the pure density-scale by normalising margin ÷ root-font-size, proving 0.875 / 1 / 1.125
  cleanly regardless of the rem shift. Eyes-on (3 screenshots) confirms coherent rhythm — nothing
  collides or overflows at any density.
- **Plan impact:** none — the human-approved scale-multiply is implemented as specified; the
  compounding is a property of the existing token system (font + spacing both keyed to
  `data-wt-density`), not introduced here. Noted so a reviewer isn't surprised that Compact is
  visibly *quite* a bit tighter than a pure ×0.875 would suggest.
- **Triggered:** none new. The "roll to other pages" follow-up still stands (now with the
  font-compounding caveat documented for whoever picks it up).
- **Verification artefacts:** unit `tests/unit/test_cockpit_density_spacing.py` (5 tests);
  Playwright `tests/playwright/test_cockpit_density_spacing.py` (3 tests, normalised ratio);
  screenshots `web/static/ux-review/T-2029-cockpit-density-{compact,cozy,comfortable}.png`.

## Decisions

### 2026-05-24 — scale-multiply, em-spacing excluded
- **Chose:** `calc(<rem/px value> * var(--wt-density-scale))` on padding/margin/gap; leave em-spacing, border-radius, border, font-size, letter-spacing untouched.
- **Why:** Human-approved (AskUserQuestion). Preserves current rhythm at Cozy; em-spacing already follows font-size so wrapping it would double-scale; border-radius/border/font are not the spacing axis.
- **Rejected:** snap-to-token-scale (changes appearance, needs new tokens) and row-pad-only (incoherent partial density). See project memory + the AskUserQuestion options.

## Recommendation

**Recommendation:** GO (built — all 5 Agent ACs pass)
**Rationale:** The human-approved scale-multiply is implemented: all 37 cockpit rem/px
padding/margin/gap values are now `calc(<value> * var(--wt-density-scale))`; every excluded
property (em-spacing, border-radius, border, font-size, letter-spacing, sizing) is verified
untouched. Cozy is pixel-identical to before (scale=1); Compact tightens and Comfortable
loosens. One [REVIEW] AC remains — the human's eyes-on judgement that the rhythm stays
coherent across all three densities — which only the human can settle.
**Evidence:**
- 37 spacing values wrapped (clean 37-insert/37-delete 1:1 diff); classify-all-rem/px grep
  confirms every unwrapped rem/px is a legitimate exclusion (font-size/border-radius/border/max-width).
- Unit `tests/unit/test_cockpit_density_spacing.py` — 5 tests pass (wrapped, exclusions-not-wrapped,
  no-bare-spacing-left, compiles).
- Playwright `tests/playwright/test_cockpit_density_spacing.py` — 3 tests pass; density-scale
  isolated via margin÷root-font normalisation → 0.875 / 1 / 1.125 confirmed.
- Eyes-on (3 screenshots, web `/static/ux-review/T-2029-cockpit-density-{compact,cozy,comfortable}.png`):
  coherent rhythm, no collisions/overflow at any density.
- Reviewer PASS (needs_human=no).
**Note (deploy):** the live `:3000` caches templates — the density behaviour shows after a restart.
The isolated-port Playwright run + screenshots prove the new render.

## Updates

### 2026-05-24T12:58:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent; filed fully-scoped + human-approved for next-session build
- **Context:** arc-007 S3b — investigation revealed atomic 54-site scope; deferred build to fresh budget window

### 2026-05-24T13:00:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-050b0d49
- **Timestamp:** 2026-05-25T22:43:28Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-25T22:43:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
