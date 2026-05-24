---
id: T-2033
name: "arc-007 nav-layout polish — rail flyout clip, content overflow, sidebar gap,
  decouple preset-nav, font preload"
description: >
  arc-007 nav-layout polish — rail flyout clip, content overflow, sidebar gap, decouple
  preset-nav, font preload

status: started-work
workflow_type: build
owner: agent
horizon: now
arc_id: watchtower-redesign
tags: [arc:watchtower-redesign, ui, watchtower, nav, layout, bug]
components: []
related_tasks: [T-2011, T-1987, T-1988, T-2029, T-2032]
created: 2026-05-24T15:38:42Z
last_update: '2026-05-24T15:45:02Z'
date_finished:
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
cost_estimate_proposed:
  - ts: '2026-05-24T15:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-24T15:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2033: arc-007 nav-layout polish — rail flyout clip, content overflow, sidebar gap, decouple preset-nav, font preload

## Context

Critical review of the arc-007 nav-layout slice (T-2011) in **Sidebar** and **Icon rail**
modes (eyes-on at 785px + 1440px, DOM-measured) surfaced four defects. All measured live in
a headless browser against `:3000` — not grep.

**F1 — Rail flyout menus clipped (the "subitems not wired" report).** The rail `nav.site-nav`
has `overflow-y:auto` (to scroll icons). Per CSS spec, `overflow-x:visible` is *forced to
compute as `auto`* when `overflow-y` is non-visible — so the absolutely-positioned group
flyout (`left:56px`, measured rect x=64→256) is clipped by the 60px rail clip box and never
appears. All 31 nav routes return HTTP 200 — the destinations are fine; only the rail flyout
is unreachable.

**F2 — Horizontal scrollbar in sidebar AND rail at every desktop width.** `margin-left:232px`
(sidebar) / `60px` (rail) is applied to full-width children (`main.container`, `.ambient-strip`,
`footer`) without shrinking them. A `width:100%` block + left margin overflows by exactly the
margin. Measured at 1440px: sidebar scrollWidth 1657 > clientWidth 1425 (Δ=232); rail Δ=60.

**F3 — Sidebar dead gap.** 158px of empty space between brand and first group — empty
`nav-pins`/`spacer` `<li>`s render at ~56px each in the column even when empty.

**F4 — Preset switch = multiple visible reflows.** (a) Presets carried a `nav` axis
(Console→sidebar, Midnight→rail) so picking them jumped the page horizontally; (b) every
preset uses a different webfont with `font-display:swap` → fallback renders first, then the
woff2 arrives and re-lays-out (delayed second reflow). **Human decision (2026-05-24):
decouple — nav is an independent axis; presets no longer carry it.**

## Acceptance Criteria

### Agent
- [x] **F1** Rail group flyouts are no longer clipped: opening a group in `data-wt-nav="rail"` shows its flyout fully (rail nav is `overflow:visible`; flyout right edge ≤ viewport) — measured live + Playwright pinned
- [x] **F2** No horizontal scrollbar in sidebar or rail: root `overflow-x` computes to `clip` and the page cannot scroll horizontally beyond a ≤2px sub-pixel residue (the 232/60px margin-offset overflow is gone) — was Δ=232/60px, now ≤2px clipped
- [x] **F3** Sidebar brand→first-group vertical gap tightened: empty hamburger + pins filler rows hidden in the column (was 158px → 43px) — Playwright asserts < 60px
- [x] **F4a** `PRESETS` in `web/blueprints/settings.py` no longer carry a `nav` key; `_sanitise_appearance` no longer sets `nav` from a preset (nav is an independent axis, resolved from the posted value); the appearance picker's preset buttons no longer carry `data-nav` and the preset-click JS no longer mutates `state.nav`
- [x] **F4b** All 11 type-pairing webfonts are preloaded (`<link rel="preload" as="font" ...>`) so a preset/type switch does not cause a font-swap reflow
- [x] Playwright regression `tests/playwright/test_nav_layout_polish.py` passes (4 tests: F1 flyout-visible, F2 no-scroll sidebar+rail, F3 tight gap)
- [x] Unit regression `tests/unit/test_nav_layout_polish.py` passes (8 tests: F4a presets nav-free + resolve + no data-nav; F1 rail overflow; F2 body-padding; F3 :has filler-hide; F4b preload; compile)
- [x] `base.html` and `appearance.html` still compile (jinja `get_template`)

### Human
- [ ] [REVIEW] Sidebar and Icon rail look polished and behave correctly across palettes
  **Steps:**
  1. Open http://192.168.10.107:3000/settings/appearance and set **Layout → Icon rail**
  2. Click each group icon in the rail — confirm its flyout menu appears to the right and every subitem is clickable
  3. Set **Layout → Sidebar**; confirm no horizontal scrollbar, no large empty gap under the logo, content not cut off on the right
  4. Switch a few **presets** (Calm, Console, Midnight) and watch — the layout should settle in one step, no font-swap shimmer, no horizontal jump
  5. Repeat in 2-3 palettes (e.g. Paper light, Midnight dark)
  **Expected:** rail flyouts reachable; no horizontal scroll; tidy sidebar spacing; preset changes are a single clean transition
  **If not:** note the layout + palette + which defect (F1 flyout / F2 scroll / F3 gap / F4 shimmer) and the element involved

## Verification

out=$(cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_nav_layout_polish.py -q 2>&1); echo "$out" | tail -3; echo "$out" | grep -q "passed"
python3 -c "import sys; sys.path.insert(0,'.'); from web.app import app; app.jinja_env.get_template('base.html'); app.jinja_env.get_template('appearance.html'); print('compiles')"
python3 -c "import sys; sys.path.insert(0,'.'); from web.blueprints.settings import PRESETS; assert all('nav' not in p for p in PRESETS.values()), 'preset still carries nav'; print('F4a presets nav-free')"

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

## RCA

**Symptom:** In the Icon-rail layout, opening a nav group shows no menu (subitems unreachable
— the user's "buttons/subitems not wired"). In sidebar and rail both, a horizontal scrollbar
appears and content is cut off on the right. The sidebar has a large empty gap under the logo.
Switching presets makes the layout jump/shimmer several times.

**Root cause (per defect):**
- **F1:** the rail makes `nav.site-nav` a scroll container (`overflow-y:auto`), which per CSS
  spec forces `overflow-x` to compute to `auto` even though the rule says `visible`. The flyout
  is absolutely positioned *outside* the 60px rail (left:56px) and is therefore clipped to
  nothing. A classic "overflow-x:visible is a lie when overflow-y isn't visible" trap.
- **F2:** offsetting full-width children with `margin-left` (not a width reduction) — the block
  is still `width:100%` of the viewport, so the margin pushes it off-screen by exactly the
  margin width.
- **F3:** empty `nav-pins`/`spacer` `<li>`s keep their box height in the flex column.
- **F4:** presets bundled a `nav` axis (cross-axis coupling) + `font-display:swap` on
  per-preset webfonts that were never preloaded (async load → second reflow).

**Why structurally allowed:** the nav-layout slice (T-2011) was verified in the *topbar*
default (the tested path) and via element-presence, not eyes-on at desktop widths in the
sidebar/rail layouts. P-013 render-review existed but the slice's [REVIEW] AC checked the
topbar; the off-default layouts shipped without a desktop-width eyes-on pass. This is a
UI-layer instance of the same class as T-1575 (grep-only "looks present" ≠ "renders correctly").

**Prevention (distinct from the fix):** a Playwright regression
(`tests/playwright/test_nav_layout_polish.py`) that, for *each* of sidebar+rail, asserts (a)
no horizontal overflow at desktop width and (b) an opened group flyout is within the viewport
and not clipped. This pins the two layouts that had no eyes-on guard — the next nav change
that breaks them fails CI instead of shipping.

## Evolution

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

### 2026-05-24 — review surfaced 4 coupled nav-layout defects in one slice
- **What changed:** A critical review of the T-2011 nav-layout slice (requested by the human)
  found that the sidebar/rail layouts shipped with correctness + polish gaps that the topbar
  default never exposed. Four distinct root causes (overflow-x clip, margin overflow, empty
  filler rows, preset cross-axis coupling + unpreloaded webfonts) — all in one slice, all
  found in one eyes-on pass.
- **Plan impact:** treated as one coherent polish pass (one eyes-on review covers all four)
  rather than four micro-slices; each defect keeps its own AC + regression test so causality
  stays traceable.
- **Triggered:** human decision to **decouple nav from presets** (nav becomes an independent
  axis). No new sub-tasks; F4b font-preload folded in since it shares the "preset switch
  reflow" symptom.

## Decisions

### 2026-05-24 — decouple nav layout from presets
- **Chose:** Presets set palette/type/density/mode only; nav layout is an independent control.
- **Why:** Human decision (AskUserQuestion). Eliminates the horizontal page jump when picking
  Console/Midnight, and makes "preset" a pure look-switch. Nav is a structural preference the
  user sets once, not part of a visual theme.
- **Rejected:** Keep presets coupled to nav but fix the jump — more motion/"magic" per preset,
  and conflates a structural layout choice with a colour/type theme.

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO (built — all 8 Agent ACs pass; reviewer PASS, needs_human=no)

**Rationale:** All four reviewed defects are fixed and confirmed live in a headless browser
at 1440px, then pinned by regression tests. The only open item is the single [REVIEW] AC —
your eyes-on judgement that the two layouts feel polished across palettes, which only you can
settle.

**Evidence:**
- **F1 (rail flyout clipped → subitems unreachable):** rail nav changed to `overflow:visible`;
  opening a group now shows its flyout (measured x=64→256, within viewport). Before: flyout
  clipped to nothing by `overflow-x` computing to `auto`. Screenshot
  `web/static/ux-review/T-2033-rail-flyout-after.png` shows the Work subitems visible.
- **F2 (horizontal scrollbar):** offset moved from `margin-left` on full-width children to
  `body { padding-left }` + root `overflow-x:clip`. Gross overflow was Δ=232px (sidebar) /
  60px (rail) at every desktop width; now ≤2px sub-pixel, clipped → no visible scrollbar.
- **F3 (158px dead gap):** mobile hamburger row + empty pins row hidden in the column via
  `:has()`; gap 158px → 43px. Pins re-appear when a page is actually pinned.
- **F4a (preset↔nav coupling):** per your decision, presets no longer carry a `nav` axis
  (`PRESETS`, `_sanitise_appearance`, preset buttons, preset-click JS all stripped of nav).
  Picking Console/Midnight no longer moves the layout.
- **F4b (font-swap reflow):** all 11 type-pairing webfonts preloaded in `<head>` so switching
  preset/type no longer triggers a delayed font-swap re-layout.
- **Tests:** unit `tests/unit/test_nav_layout_polish.py` (8) + Playwright
  `tests/playwright/test_nav_layout_polish.py` (4) all green; reviewer PASS.

**Note (deploy):** the live `:3000` caches templates — these are already live (restarted during
build). The isolated-port Playwright run + the two `web/static/ux-review/T-2033-*.png`
screenshots prove the new render.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-24T15:38:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2033-arc-007-nav-layout-polish--rail-flyout-c.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8620881c
- **Timestamp:** 2026-05-24T15:50:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
