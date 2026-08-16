---
id: T-1989
name: "Watchtower nav restructure — flatten 16-item Govern group, top-bar + contextual
  sub-nav + pinned favourites + breadcrumbs (arc-007 S2)"
description: >
  Replace current 4-group PicoCSS nav (Govern has 16 items — chat's stated pain point)
  with three selectable layouts from docs/design/watchtower-redesign-2026-05-13/project/nav-patterns.jsx:
  (A) top-bar primary + contextual sub-nav per section, (B) persistent sidebar with
  pinned + groups, (C) slim icon rail + ⌘K-primary. Layout selectable from /settings/appearance.
  Add breadcrumbs to every page header. Pinned-pages model: user can star pages, surface
  in top bar. Depends on S0+S1. Parent inception: T-1987.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, redesign, ui, nav]
arc_id: watchtower-redesign
components: [tests/playwright/test_pins.py, tests/unit/test_pins.py, 
      web/blueprints/settings.py, web/shared.py, web/templates/base.html, 
      web/templates/_breadcrumb.html, web/templates/_pins.html, 
      web/templates/_star.html]
related_tasks: [T-1987]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-22T10:06:08Z
last_update: '2026-08-16T22:24:02Z'
date_finished: 2026-05-25T22:01:13Z
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
  - ts: '2026-05-22T10:15:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-23T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-22T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-23T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-25T22:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1989: Watchtower nav restructure — flatten 16-item Govern group, top-bar + contextual sub-nav + pinned favourites + breadcrumbs (arc-007 S2)

## Context

arc-007 S2. Restructure Watchtower nav per `docs/design/watchtower-redesign-2026-05-13/project/nav-patterns.jsx`
+ the design chat (`chats/chat1.md` lines 52, 180, 232-237): nav layout is a **per-user
selectable axis** (top-bar / sidebar / icon-rail), chosen in /settings/appearance alongside
palette/type/density — the presets already bind it (Console=sidebar, Midnight=icon-rail,
others=top-bar). The design also specifies a concrete information-architecture regroup —
**NAV_GROUPS** (nav-patterns.jsx:4-9):
- **Work:** Tasks, Inception, Assumptions, Timeline, Prompts
- **Knowledge:** Learnings, Graduation, Patterns, Decisions
- **Architecture:** Fabric, Explorer, Arcs, Terminal, Sessions
- **Govern:** Approvals, Directives, Enforcement, Hooks, Risks, Gaps, Quality, Metrics, Costs, Config, Cron

The 16-item Govern flat list is the named pain point; in the sidebar/rail layouts it collapses,
in top-bar it becomes a grouped dropdown. ⌘K is the escape hatch (S6, T-1993) for everything not pinned.

**Scoping note (2026-05-23, S2 scoping pass):** Read the design + chat. The ACs below already
match the design's full intent (3 selectable layouts, not just top-bar). Scope is confirmed —
this is a **build slice, not an inception** (the design exists and is concrete). It is, however,
a **multi-session slice** (3 layouts × picker integration × breadcrumbs × pinned model × IA
regroup × apply-across-pages). Recommend decomposing into sub-slices at build start, e.g.
S2a top-bar layout + IA regroup (the default, highest-leverage), S2b breadcrumbs, S2c pinned
model, S2d sidebar + rail layouts. Start fresh-session (budget) with S2a.

**Sub-slice progress (2026-05-23):**
- **S2a — [T-2008] ✅ shipped + presented** (Recommendation GO, awaiting human [REVIEW]): Arcs moved
  Work→Architecture; the 16-item Govern dropdown now renders 4 function subsections. Covers
  T-1989 AC #5 + the IA half of AC #1.
- **S2b — [T-2009] ✅ shipped + presented** (Recommendation GO, awaiting human [REVIEW]): path-derived
  breadcrumb trail, htmx-fresh (rendered inside #content). Covers T-1989 AC #3.
- **S2c — [T-2010] ✅ shipped + presented** (Recommendation GO, awaiting human [REVIEW]): pinned-pages
  model — star a nav destination from the breadcrumb bar, surfaces as a quick-link in the top bar,
  persists per-browser across nav + reload, oob-refresh on toggle (no full reload). Covers T-1989
  AC #4. Fixed a latent S1 clobber (`_save_appearance` now read-modify-writes the full prefs dict).
- **S2d — [T-2011] ✅ shipped + presented** (Recommendation GO, awaiting human [REVIEW]): the
  `nav` appearance axis (topbar/sidebar/rail) + the /settings/appearance Layout selector +
  `data-wt-nav` render on `<html>`. Three layouts share one DOM via attribute-keyed CSS reflow
  (sidebar/rail are desktop affordances); the 16-item Govern group stays a collapsible `<details>`
  in sidebar/rail (pain point resolved); breadcrumbs (S2b) + pins (S2c) survive every layout.
  Covers T-1989 AC #1 (layout-selection half) + AC #2. 12 unit + 6 Playwright pass; all 3 layouts
  eyes-on verified. **All four S2 sub-slices (S2a–S2d) now shipped.**

This umbrella (T-1989) stays open until the human confirms the S2a/S2b/S2c/S2d reviews — all
five Agent ACs are now covered by the shipped sub-slices; only the two [REVIEW] Human ACs remain.

## Acceptance Criteria

<!-- READY (was parked pending S0/S1). 2026-05-23: S0 (T-1991) + S1 (T-1988) are built and the
     foundation verified clean — ux-review --sweep verdict PASS, theme applies across all 5
     pages (T-2005), contrast AA across all 6 palettes (T-2006/T-2007). The dependency is met
     at the build level; the only remaining gate is the human [REVIEW] of the foundation work
     (T-2003/T-2004/T-2005/T-2006, all queued in the review queue). Per the Evolution principle
     (T-1717), fold any S0/S1 review feedback in at build start. ACs below are the known full
     scope; decompose into S2a-S2d sub-slices when building (see Scoping note above). -->
### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Nav-layout selector added to /settings/appearance offering the 3 layouts from `docs/design/watchtower-redesign-2026-05-13/project/nav-patterns.jsx` (A: top-bar + contextual sub-nav, B: sidebar + pinned + groups, C: icon rail + ⌘K), persisted per-user via the existing appearance prefs (S1 mechanism)
- [x] `base.html` renders the selected layout via a `data-wt-nav` attribute (mirrors the S0 `data-wt-*` pattern); each layout returns HTTP 200 with its distinguishing element present (curl/Playwright)
- [x] Breadcrumbs render on every page header, derived from the request path
- [x] Pinned-pages model: a page can be starred/unstarred and pinned pages surface in the primary nav; persists across navigation
- [x] The 16-item Govern group is no longer a flat 16-item list in any layout (the stated pain point) — verified structurally

### Human
<!-- [REVIEW] criteria — visual/UX judgment, cannot be automated. -->
- [ ] [REVIEW] Each of the 3 nav layouts is usable and visually coherent (no overflow, sensible grouping)
  **Steps:** 1. Open the Watchtower URL  2. Switch each layout in /settings/appearance  3. Navigate 3-4 pages in each
  **Expected:** Nav is navigable and uncluttered; the Govern pain point feels resolved
  **If not:** Note which layout/section breaks and how
- [ ] [REVIEW] Breadcrumbs are accurate and aid orientation across nested pages
  **Steps:** 1. Visit a nested page (e.g. /arcs/arc-007)  2. Read the breadcrumb trail
  **Expected:** Trail reflects the real hierarchy and links work
  **If not:** Note the page and the wrong/missing crumb

## Verification

# L-387-safe: grep a tempFILE, never `echo "$out" | grep -q` — large curl HTML
# makes grep close the pipe early and echo takes SIGPIPE (exit 141) under pipefail.
# AC1: /settings/appearance exposes all 3 nav layouts (T-2011)
curl -s "$(bin/fw watchtower url)/settings/appearance" > /tmp/t1989_ac1.html 2>&1; grep -q "Icon rail" /tmp/t1989_ac1.html && grep -q "Sidebar" /tmp/t1989_ac1.html && grep -q "Top bar" /tmp/t1989_ac1.html
# AC2: base.html renders data-wt-nav; home returns 200 (curl -f)
curl -sf "$(bin/fw watchtower url)/" > /tmp/t1989_home.html 2>&1; grep -q 'data-wt-nav' /tmp/t1989_home.html
# AC3: breadcrumb renders on a nested page (/arcs)
curl -sf "$(bin/fw watchtower url)/arcs" > /tmp/t1989_arcs.html 2>&1; grep -q 'wt-breadcrumb' /tmp/t1989_arcs.html
# AC4: pinned-pages toggle renders in nav (reuse AC2 capture)
grep -q 'wt-pin-toggle' /tmp/t1989_home.html
# AC5: Govern subsectioned into 4 function-blocks, not a flat 16-item list (T-2008)
grep -q "Govern is subsectioned" web/shared.py && grep -q "Approvals & Decisions" web/shared.py && grep -q "Enforcement" web/shared.py
# Regression guard: the nav-height/all-routes guard still ships (no broken route)
test -f tests/playwright/test_all_routes_height.py


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

### 2026-05-23 — Umbrella decomposed into S2a–S2d vertical slices
- **What changed:** The S2 nav restructure was too large for one build. At build start it was split into four independently-shippable, independently-reviewable slices rather than a single big-bang nav rewrite — applying the vertical-slice discipline (T-1718) and folding S0/S1 review feedback in per slice (Evolution principle, T-1717).
- **Plan impact:** The 3-layout selector, breadcrumbs, pinned-pages, and Govern regroup each became their own slice + `[REVIEW]` instead of one umbrella commit. This umbrella's role narrowed to a roll-up gate: its Agent ACs are structural existence checks (verified live), its two Human `[REVIEW]` ACs carry the visual-coherence judgment.
- **Triggered:** T-2008 (S2a Govern regroup), T-2009 (S2b breadcrumbs), T-2010 (S2c pinned-pages), T-2011 (S2d nav-layout selector + `data-wt-nav`) — all shipped and in the review queue.

## Recommendation

**Recommendation:** GO

**Rationale:** All 5 Agent ACs verified against the live Watchtower + shipped source. The S2 nav restructure shipped as four reviewed slices (T-2008/2009/2010/2011); this umbrella's Agent ACs are structural roll-ups confirming each landed. Two Human `[REVIEW]` ACs remain — visual coherence of the 3 nav layouts and breadcrumb accuracy — which need eyes-on judgment the agent cannot supply.

**Evidence:**
- AC1 — `/settings/appearance` renders all 3 layouts live (Top bar / Sidebar / Icon rail); `NAV_LAYOUTS=("topbar","sidebar","rail")` in `web/blueprints/settings.py`
- AC2 — `base.html:7` `data-wt-nav="{{ wt_appearance.nav }}"`; live `/` returns HTTP 200 with `data-wt-nav="topbar"` + per-layout CSS
- AC3 — `_breadcrumb.html` via `_wrapper.html`; live `/arcs` renders `nav.wt-breadcrumb` + separators
- AC4 — `_pins.html` / `_star.html`; live `/` renders `wt-pin-toggle`, `nav-pin`, `wt-pins`
- AC5 — Govern subsectioned into 4 function-blocks (Approvals & Decisions / Enforcement / Health / Operations) in `web/shared.py`; labels render live in the nav dropdown — no flat 16-item list

**Review:** http://192.168.10.107:3000/review/T-1989

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

### 2026-05-22T10:06:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1989-watchtower-nav-restructure--flatten-16-i.md
- **Context:** Initial task creation

### 2026-05-22T19:53:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-05-22T20:00:05Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-05-23T15:43:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7387cc23
- **Timestamp:** 2026-05-25T22:01:18Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — Nav-layout selector added to /settings/appearance offering the 3 layouts from `docs/design/watchtower-redesign-2026-05-13/project/nav-patterns.jsx` (A: top-bar + contextual sub-nav, B: sidebar + pinne
  - **AC-verify-mismatch** (narrow, heuristic) — `path=docs/design/watchtower-redesign-2026-05-13/project/nav-patterns.jsx in: Nav-layout selector added to /settings/appearance offering the 3 layouts from `docs/design/watchtower-redesign-2026-05-13/project/nav-patterns.jsx` (A`

### 2026-05-25T22:01:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
