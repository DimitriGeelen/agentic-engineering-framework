---
id: T-2008
name: "arc-007 S2a nav IA regroup + Govern sub-grouping (top-bar layout)"
description: >
  arc-007 S2a nav IA regroup + Govern sub-grouping (top-bar layout)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [watchtower, redesign, ui, nav]
arc_id: watchtower-redesign
components: []
related_tasks: [T-1989, T-1987]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-23T15:58:29Z
last_update: '2026-05-23T16:00:02Z'
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
  - ts: '2026-05-23T16:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-23T16:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2008: arc-007 S2a nav IA regroup + Govern sub-grouping (top-bar layout)

## Context

First build sub-slice of **T-1989 (arc-007 S2 nav restructure)**. T-1989's scoping note
recommends decomposing S2 into S2a–S2d; this is **S2a — the top-bar layout's core IA work**,
the highest-leverage piece that resolves the named pain point (the 16-item flat Govern dropdown)
without yet touching the sidebar/rail layouts or breadcrumbs/pinned model.

**Design source:** `docs/design/watchtower-redesign-2026-05-13/project/nav-patterns.jsx:4-9`
(NAV_GROUPS) + chat1.md. The design's IA target:
- **Work:** Tasks, Inception, Assumptions, Timeline, Prompts
- **Knowledge:** Learnings, Graduation, Patterns, Decisions
- **Architecture:** Fabric, Explorer, **Arcs**, Terminal, Sessions
- **Govern:** Approvals, Directives, Enforcement, Hooks, Risks, Gaps, Quality, Metrics, Costs, Config, Cron

**Current live IA** (`web/shared.py:102` NAV_GROUPS) diverges: Arcs+BVP live in Work; Govern
carries 16 flat items (5 post-design pages: Discoveries, Reviewer Audit, Reviewer Overrides,
Escalation Drift, Pending). The nav already renders as horizontal dropdowns (`base.html:335-370`),
so S2a is **data-model + IA**, not a new layout: (1) move Arcs → Architecture per design; (2) make
the Govern dropdown render labelled subsections instead of one flat 16-item list.

**Out of scope (later sub-slices):** breadcrumbs (S2b), pinned-pages model (S2c), the sidebar/rail
layouts + `data-wt-nav` selector in /settings/appearance (S2d). The `data-wt-nav` mechanism belongs
with S2d where there are multiple layouts to switch between — adding it now would be hollow plumbing.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] NAV_GROUPS data model in `web/shared.py` supports nested subsections: a group's items
      may be a flat list (existing form, unchanged) OR a list of `(subsection_label, [items])`.
      `NAV_ITEMS` flat-derivation still yields every leaf item (recursive flatten) — asserted by
      a unit test that counts leaves before/after.
- [x] Arcs is moved from **Work** to **Architecture** (matches design NAV_GROUPS); BVP stays in Work.
- [x] The **Govern** dropdown renders as labelled subsections (each leaf still a working link),
      so it is no longer a flat 16-item `<ul>`. Verified structurally: the Govern `<details>` block
      contains ≥3 subsection headers and every endpoint still resolves (no broken `url_for`).
- [x] `base.html` renders both flat groups and subsectioned groups correctly (Jinja handles both
      item shapes); page returns HTTP 200 and the nav DOM contains the 4 top-level groups.
- [x] `web/test_app.py::test_nav_groups_present` (and any nav structural test) passes against the
      new model; `fw test unit` green for the nav + new subsection test.
- [x] DOM verification (NOT grep-only, per T-1575): a Playwright/`ux-review` capture of the
      rendered Govern dropdown shows the subsection headers and no flat 16-item list. Artefact
      path recorded in Evolution.

### Human
<!-- [REVIEW] criteria — visual/UX taste, cannot be automated (render-surface gate P-013). -->
- [ ] [REVIEW] The Govern sub-grouping is sensible — the subsection labels and item assignments
      read intuitively, and the dropdown feels organised rather than dumped.
  **Steps:** 1. Open the Watchtower URL (`bin/fw watchtower url`)  2. Hover/click the **Govern**
  top-bar group  3. Read the subsection headers and the items under each
  **Expected:** Subsections group related governance pages logically (e.g. approvals/enforcement/
  health/ops); no item feels misfiled; the 16-item wall is gone
  **If not:** Note which item belongs in a different subsection, or which subsection label is unclear
- [ ] [REVIEW] Moving Arcs into Architecture (out of Work) reads correctly and the four top-level
      groups feel balanced.
  **Steps:** 1. Scan the top-bar groups Work / Knowledge / Architecture / Govern  2. Open each
  **Expected:** Arcs sits naturally under Architecture; no group feels lopsided or surprising
  **If not:** Note the group that feels wrong and where the item should live

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

# NAV model imports and every leaf endpoint is non-empty (no broken url_for targets)
python3 -c "from web.shared import NAV_GROUPS, NAV_ITEMS; assert all(ep for _,ep,_ in NAV_ITEMS), 'empty endpoint'; print(f'{len(NAV_ITEMS)} leaf items')"
# Arcs is under Architecture (design IA), not Work
python3 -c "from web.shared import nav_group_labels; assert 'Arcs' in nav_group_labels('Architecture'), 'Arcs not in Architecture'; assert 'Arcs' not in nav_group_labels('Work'), 'Arcs still in Work'; print('IA ok')"
# nav + subsection unit tests pass
python3 -m pytest web/test_app.py -k nav -q 2>&1 | tail -3
python3 -m pytest tests/unit/test_nav_subsections.py -q 2>&1 | tail -3
# rendered page returns 200 and DOM carries the 4 top-level groups
out=$(curl -sf "$(bin/fw watchtower url)/" 2>&1); echo "$out" | grep -q "Govern" && echo "$out" | grep -q "Architecture"

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

### 2026-05-23 — S2a is data-model work, not a new layout
- **What changed:** The S2 brief framed the nav as "three selectable layouts." Reading the live
  code revealed the top-bar layout *already exists* (`base.html` renders NAV_GROUPS as horizontal
  `<details>` dropdowns) — so the highest-leverage S2a piece is the **IA + Govern sub-grouping**,
  not a new layout. The "16-item Govern" pain point lives *inside the existing dropdown*, not in
  the absence of a layout.
- **Plan impact:** Confirms T-1989's S2a/S2d split. The `data-wt-nav` selector + sidebar/rail
  layouts (S2d) are genuinely separable and correctly deferred — adding the attribute now would be
  hollow plumbing with one option. S2a touched only `web/shared.py` (model) + `base.html` (render).
- **Triggered:** No new sub-tasks. Confirmed S2b (breadcrumbs), S2c (pinned), S2d (layouts +
  selector) remain as planned under T-1989.

### 2026-05-23 — live IA had drifted past the May-13 design
- **What changed:** The design's NAV_GROUPS (11-item Govern) predates 6 pages now live
  (BVP in Work; Discoveries, Reviewer Audit/Overrides, Escalation Drift, Pending in Govern). So the
  faithful move wasn't "copy the design's Govern" but "apply the design's *grouping principle* to the
  current 16 items" → 4 function-based subsections (see Decisions).
- **Plan impact:** The [REVIEW] taste call (subsection taxonomy) is mine to propose, human's to
  confirm — recorded in Decisions so the human can react to a concrete cut, not a blank.
- **Triggered:** none.

### 2026-05-23 — verification artefacts
- **DOM-content assertion (T-1575):** `tests/unit/test_nav_subsections.py` (4 tests) — model
  flatten, Arcs-moved, Govern subsectioned, rendered DOM carries escaped subsection labels + class.
- **Executed-browser guard (T-971):** `tests/playwright/test_nav_subsections.py` (3 tests) — opens
  the Govern + Architecture dropdowns, asserts subsections visible + Arcs reachable.
- **Human [REVIEW] artefact (screenshot):** `web/static/ux-review/T-2008-govern-subsections.png`
  — the opened Govern dropdown showing all four subsections. Web path:
  `<watchtower-url>/static/ux-review/T-2008-govern-subsections.png`.

## Decisions

### 2026-05-23 — Govern subsection taxonomy (the [REVIEW] taste call)
- **Chose:** Split Govern's 16 items into 4 labelled subsections —
  - **Approvals & Decisions:** Approvals, Directives, Pending
  - **Enforcement:** Enforcement, Hooks, Reviewer Audit, Reviewer Overrides
  - **Health:** Risks, Gaps, Quality, Discoveries, Escalation Drift
  - **Operations:** Metrics, Costs, Config, Cron
- **Why:** The design's NAV_GROUPS keeps Govern flat (11 items) but the live system has 16
  (5 post-design pages). The pain point AC requires Govern to not be flat-16; subsections are the
  faithful reading of the design chat's "the 16-item Govern problem disappears … it collapses."
  Grouping by governance function (who-approves / what-enforces / what's-wrong / what-it-costs)
  is the most scannable cut.
- **Rejected:** (a) Splitting Govern into two top-level groups — would make 5 top-level groups,
  unbalancing the bar and diverging from the design's 4-group model. (b) Leaving Govern flat at 11
  by dropping the 5 newer pages elsewhere — they have no better home and 11 is still a wall.

### 2026-05-23 — Nested data model vs. flat-only
- **Chose:** Make a group's items polymorphic — a leaf `(label, endpoint, icon)` (3-tuple, unchanged)
  OR a subsection `(subsection_label, [leaf, …])` (2-tuple, list second element). Only Govern uses
  subsections in S2a; the other three groups stay flat.
- **Why:** Backward-compatible (existing flat groups untouched), `NAV_ITEMS` stays a flat leaf list
  via a recursive flatten, and the template branches on item shape. Minimal blast radius.
- **Rejected:** A separate `NAV_SUBGROUPS` constant — would duplicate the source of truth and break
  the single `NAV_ITEMS` derivation that search/jump relies on.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-23T15:58:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2008-arc-007-s2a-nav-ia-regroup--govern-sub-g.md
- **Context:** Initial task creation
