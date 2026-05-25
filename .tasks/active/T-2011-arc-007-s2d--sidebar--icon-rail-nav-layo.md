---
id: T-2011
name: "arc-007 S2d — sidebar + icon-rail nav layouts + data-wt-nav selector"
description: >
  arc-007 S2d — sidebar + icon-rail nav layouts + data-wt-nav selector

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, redesign, ui, nav, arc:watchtower-redesign]
arc_id: watchtower-redesign
components: [tests/playwright/test_command_palette.py, tests/playwright/test_nav_layouts.py, tests/unit/test_command_palette.py, tests/unit/test_nav_layouts.py, web/blueprints/settings.py, web/shared.py, web/static/command-palette.js, web/templates/appearance.html, web/templates/base.html]
related_tasks: [T-1989, T-1987, T-1988, T-2010]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-23T17:39:57Z
last_update: 2026-05-25T22:54:31Z
date_finished: 2026-05-25T22:54:31Z
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
  - ts: '2026-05-23T17:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-23T17:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2011: arc-007 S2d — sidebar + icon-rail nav layouts + data-wt-nav selector

## Context

arc-007 S2 (T-1989) final sub-slice. S2a/b/c shipped the IA regroup, breadcrumbs, and
pinned model — all under the **top-bar** layout. S2d adds the other two layouts from
`docs/design/watchtower-redesign-2026-05-13/project/nav-patterns.jsx` (B sidebar, C icon-rail)
and the per-user **layout selector** in /settings/appearance, completing T-1989 AC #1 (the
layout-selection half) + AC #2 (`data-wt-nav` render).

The mechanism mirrors S1 (T-1988): a new `nav` axis on the appearance prefs, persisted
per-browser, applied via a `data-wt-nav` attribute on `<html>` (same shape as the existing
`data-wt-palette`/`-type`/`-density`). The three layouts are pure-CSS reflows of the *same*
DOM (`nav.site-nav` + `main` + ambient strip + footer) keyed off the attribute — no template
branching, so breadcrumbs (S2b) and pins (S2c) keep working in every layout. The 16-item
Govern group stays collapsed in sidebar/rail (its `<details>` dropdowns stack vertically /
become flyouts) — the named pain point disappears without an extra mechanism. ⌘K (S6, T-1993)
is the rail's eventual escape hatch but is out of scope here; the rail's group flyouts keep
it usable until then.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A `nav` axis (`topbar`/`sidebar`/`rail`) is added to the appearance prefs: `NAV_LAYOUTS` constant, every preset carries a `nav` value (Console=sidebar, Midnight=rail, rest=topbar), `DEFAULT_APPEARANCE` defaults to `topbar`, and `_sanitise_appearance` whitelists it (unit test: invalid nav falls back to default) — `test_nav_layouts.py::test_nav_layouts_are_the_three_patterns`, `test_every_preset_carries_a_valid_nav`, `test_sanitise_rejects_unknown_nav` (12 pass)
- [x] The nav axis coexists with `pins:`/`appearance:` in the prefs file — saving the nav layout does not clobber pins, and vice-versa (unit regression test, both directions) — `test_nav_layouts.py::test_saving_nav_does_not_wipe_pins`, `test_toggling_pin_does_not_wipe_nav`; `test_pins.py` 10/10 still green
- [x] `base.html` renders `data-wt-nav="{{ wt_appearance.nav }}"` on `<html>`; each of the 3 layouts returns HTTP 200 with its distinguishing element present (Playwright: topbar = horizontal `nav.site-nav`; sidebar = nav width ≥ 180px fixed left column; rail = nav width ≤ 72px) — `test_nav_layouts.py::test_topbar_is_default`, `test_switch_to_sidebar_persists`, `test_switch_to_rail_persists` (6 Playwright pass)
- [x] A Layout selector (3 options) is added to /settings/appearance, wired to the same save/apply path as the other axes (selecting a layout sets `data-wt-nav` live and persists; Playwright: switch layout → attribute changes → reload → attribute survives) — `_set_layout` helper exercises the selector + `expect(html).to_have_attribute` after `page.goto` reload in the switch tests
- [x] In sidebar AND rail layouts the Govern group is not a flat 16-item list — it stays a collapsible `<details>` (structural check in the rendered DOM) — AND breadcrumbs (S2b) + pins (S2c) still render in all three layouts (Playwright) — `test_govern_collapsible_in_sidebar` (closed `<details>`, Approvals leaf hidden) + `test_breadcrumb_and_pin_in_all_layouts` (crumb + star visible in all 3)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->
- [ ] [REVIEW] Each of the 3 nav layouts is usable and visually coherent — no overflow, content not hidden behind the sidebar/rail, the Govern pain point feels resolved
  **Steps:**
  1. Open the Watchtower review URL (`bin/fw task review T-2011` prints it)
  2. Go to /settings/appearance and switch the Layout selector through Top bar → Sidebar → Icon rail
  3. In each layout navigate 3–4 pages (Tasks, Arcs, a Govern page, a detail page) and open the Govern group
  4. Review the captured screenshots in `web/static/ux-review/T-2011-nav-*.png`
  **Expected:** In sidebar the left column holds groups + pins and `main` is not occluded; in rail the slim icon column opens group flyouts; breadcrumbs + the pin star appear in all three; nothing overflows or clips
  **If not:** Note which layout/page breaks and how (screenshot)

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
python3 -m pytest tests/unit/test_nav_layouts.py -q
# nav is an independent axis: presets do NOT carry nav (T-2033 decouple, human decision; reconciled in T-2056)
python3 -c "import yaml,sys; from web.blueprints import settings as s; assert set(s.NAV_LAYOUTS)=={'topbar','sidebar','rail'}; assert all('nav' not in p for p in s.PRESETS.values()); assert s.DEFAULT_APPEARANCE['nav']=='topbar'; print('nav axis OK')"
out=$(python3 -c "from web.blueprints.settings import _sanitise_appearance as f; print(f({'nav':'bogus'})['nav'], f({'nav':'sidebar'})['nav'])"); echo "$out" | grep -q "topbar sidebar"

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

### 2026-05-23 — nav axis did not exist yet
- **What changed:** The T-1989 scoping note and the design chat said "the presets already
  bind nav layout (Console=sidebar, Midnight=icon-rail, others=top-bar)". They do not — the
  S1 (T-1988) `PRESETS` dict only carries palette/type/density/mode. The binding was design
  intent, never built. S2d adds the `nav` axis from scratch, not just the layouts.
- **Plan impact:** None to scope — the axis was always implied by AC #1; this just confirms
  S2d owns the full axis (constant + presets + default + sanitise + save + selector), not only
  the CSS. Reused the S1 read-modify-write prefs path (T-2010) so coexistence is free.
- **Triggered:** No new sub-task — folded into this slice.

## Recommendation

- **Recommendation:** GO
- **Rationale:** All 5 Agent ACs pass with test evidence (12 unit + 6 Playwright, plus
  10 pins + 9 appearance regression tests green). The nav-layout axis closes T-1989 AC #1
  (layout-selection half) + AC #2 (`data-wt-nav` render), completing the S2 nav restructure
  (S2a–S2d all shipped). All three layouts were verified by eye via the captured screenshots,
  not just by element-presence — topbar is unregressed (S2a grouped dropdown + S2c pin star
  intact), sidebar reflows to a clean accordion with content clear of the column, rail is a
  slim icon column with recognizable group glyphs and the most content room. The remaining
  gate is the human [REVIEW] of layout taste/coherence across pages.
- **Evidence:**
  - Backend: `web/blueprints/settings.py` — `NAV_LAYOUTS`, `nav` on all presets + `DEFAULT_APPEARANCE`, sanitise whitelist, save form-field, render context
  - Render: `web/templates/base.html` — `data-wt-nav` attribute + group icons + sidebar/rail CSS (one DOM, attribute-keyed reflow, desktop-only via `min-width:769px`)
  - Selector: `web/templates/appearance.html` — Layout segment wired into state/apply/reflect/save
  - Tests: `tests/unit/test_nav_layouts.py` (12), `tests/playwright/test_nav_layouts.py` (6)
  - Screenshots: `web/static/ux-review/T-2011-nav-{topbar,sidebar,rail}.png`

## Decisions

### 2026-05-23 — pure-CSS reflow over per-layout templates
- **Chose:** Render all 3 layouts from the *same* DOM, switching only via `html[data-wt-nav=...]`
  CSS selectors (nav becomes a fixed left column for sidebar/rail; `main`/ambient/footer get a
  left margin). Group icons added once, hidden by CSS except in rail.
- **Why:** Breadcrumbs (S2b) and pins (S2c) live in the shared chrome; branching templates
  per layout would fork them three ways and invite drift. One DOM + attribute-keyed CSS keeps
  every layout on the same render path — the same reason S0/S1 used `data-wt-*` over template forks.
- **Rejected:** Separate `base_sidebar.html`/`base_rail.html` (3× the chrome to keep in sync);
  JS-driven DOM restructuring on layout change (flash-of-wrong-layout, breaks no-JS + htmx swaps).

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

### 2026-05-23T17:39:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2011-arc-007-s2d--sidebar--icon-rail-nav-layo.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0314a792
- **Timestamp:** 2026-05-25T22:54:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-25T22:54:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
