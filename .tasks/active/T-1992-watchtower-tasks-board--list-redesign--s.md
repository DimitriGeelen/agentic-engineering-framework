---
id: T-1992
name: "Watchtower Tasks board + list redesign — side-panel detail with dock controls,
  drag-reorder, inline edit, filter chips (arc-007 S4)"
description: >
  Redesign /tasks (board + list) — highest user-interaction surface. Click-row → slide-in
  side panel (dockable: left/bottom/fullscreen/close), no full-page navigation. Inline
  edit on status/owner/horizon cells. Drag-to-reorder kanban columns and within. Saved-view
  filter chips at top. Bulk-action floating bar for multi-select. Reference: docs/design/.../direction-calm.jsx
  (board+side-panel mockup) + direction-cockpit.jsx (dense list mockup). Depends on
  S0+S1+S2. Parent inception: T-1987.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, redesign, ui, tasks]
arc_id: watchtower-redesign
components: [tests/playwright/test_kanban_drag.py, 
      tests/playwright/test_task_panel.py, tests/unit/test_kanban_drag.py, 
      tests/unit/test_task_panel.py, web/blueprints/settings.py, 
      web/blueprints/tasks.py, web/static/command-palette.js, 
      web/static/kanban-drag.js, web/static/shortcuts-overlay.js, 
      web/static/task-panel.js, web/templates/base.html, 
      web/templates/_task_panel.html, web/templates/tasks.html]
related_tasks: [T-1987]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-22T10:06:08Z
last_update: '2026-05-28T22:54:11Z'
date_finished: 2026-05-25T22:08:04Z
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
  - ts: '2026-05-22T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-23T20:00:02Z'
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
  - ts: '2026-05-28T22:54:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1992: Watchtower Tasks board + list redesign — side-panel detail with dock controls, drag-reorder, inline edit, filter chips (arc-007 S4)

## Context

arc-007 S4 — redesign `/tasks`, the highest-interaction surface in Watchtower. Design
reference: `docs/design/watchtower-redesign-2026-05-13/project/direction-calm.jsx`
(board + side-panel mockup) and `direction-cockpit.jsx` (dense list). Parent inception:
T-1987. Existing surfaces (surveyed 2026-05-23): `web/blueprints/tasks.py` serves
`/tasks` (kanban board, `tasks.html`) and `/tasks/<id>` (full-page `task_detail.html`);
a horizon inline-edit endpoint (`/api/task/<id>/horizon`) and an AC-toggle endpoint
already exist — the redesign extends these patterns, it doesn't start from zero.

**Scoping note (2026-05-23, T-2013 follow-on):** This task as filed bundles FIVE+
independent deliverables (side panel, inline edit, drag-reorder, filter chips, bulk
multi-select) — that violates "one task = one deliverable" (CLAUDE.md §Task Sizing). It
must be decomposed at build start, highest-leverage first. Proposed sub-slices:

- **S4a — slide-in side-panel detail (dockable):** click a card/row → htmx-load the
  task detail into a slide-in side panel instead of a full-page nav to `/tasks/<id>`.
  Dock controls (left / bottom / fullscreen / close), choice persisted per-browser like
  the S1 appearance prefs (T-1988). The keystone — it changes the core read interaction.
  Reuses the existing `task_detail` content as an htmx fragment. **Build first, ship alone.**
- **S4b — inline edit on status/owner/horizon cells:** click a cell → inline control that
  POSTs to a per-field endpoint (horizon endpoint already exists; add status + owner
  mirroring it — each must route through the existing task-update path, no new ungated
  mutation). Depends on S4a's panel only loosely; can follow independently.
- **S4c — saved-view filter chips:** a chip bar atop the board/list filtering by
  owner / horizon / status / tag (query-param driven so a filtered view is shareable).
  Independent, low-risk — good second slice.
- **S4d — drag-to-reorder kanban:** drag a card between columns (→ status change via the
  existing update path) and within a column. Highest complexity (drag library +
  persistence + a11y fallback) — sequence last.
- **S4e — bulk-action floating bar (multi-select):** = the S6c deliverable in T-1993.
  Multi-select checkboxes on cards/rows + a floating action bar; each bulk action fans
  out to the existing per-task endpoint (no new bulk mutation path). **This is where S6c
  lands** — T-1993's S6c "depends on T-1992" specifically depends on this multi-select
  infrastructure. Build after S4a (needs the row model) and the per-field endpoints (S4b).

Recommend build order: **S4a → S4c → S4b → S4e/S6c → S4d**. Each sub-slice is a fresh
build task carved at start (mirroring T-2008–T-2011 from T-1989, and T-2012/T-2013 from
T-1993). Start S4a in a fresh session with budget (side panel + dock + htmx fragment +
tests ≈ a slice the size of S2d/S6a).

## Acceptance Criteria

<!-- FULL-SCOPE ACs for the S4 umbrella. Decompose into S4a–S4e sub-slice tasks at
     build start (see Scoping note); each sub-slice carries the subset it ships. -->
### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Clicking a task card/row opens a slide-in side panel with the task detail (htmx fragment, no full-page nav); dock controls switch left/bottom/fullscreen/close; the dock choice persists per-browser; works after an htmx board refresh (Playwright + unit) — **[S4a]**
- [x] Status, owner, and horizon cells are inline-editable; each edit POSTs through the existing per-task update path (no new ungated mutation endpoint) and reflects without full reload (Playwright + unit) — **[S4b]**
- [x] A filter-chip bar filters the board/list by owner/horizon/status/tag via query params (a filtered view is shareable by URL); clearing chips restores the full set (Playwright) — **[S4c]**
- [x] Cards can be dragged between kanban columns (status change persisted via the existing update path) and reordered within a column, with a keyboard-accessible fallback (Playwright) — **[S4d]**
- [x] Multi-select on cards/rows shows a floating bulk-action bar; each bulk action fans out to the existing per-task endpoint (no new bulk mutation path) — this is the T-1993 S6c deliverable (Playwright + unit) — **[S4e / S6c]**

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
- [ ] [REVIEW] The five S4 board features compose into one coherent board — side-panel, inline-edit, filter-chips, kanban-drag and bulk-actions work together without visual or interaction conflicts
  **Steps:**
  1. Open http://192.168.10.107:3000/tasks
  2. Click a card → confirm the side panel slides in; try the dock controls (left / bottom / fullscreen / close)
  3. Apply a filter chip (e.g. owner) then drag a card between kanban columns — confirm the filtered view + drag both behave
  4. Multi-select two cards → confirm the floating bulk-action bar appears; inline-edit a status/owner/horizon cell in the panel
  **Expected:** All five interactions coexist; no overlapping panels, no chip that blocks a drag, no stuck bulk bar — the board feels like one tool, not five bolted-on features
  **If not:** Note which two features conflict and how

## Verification

# L-387-safe (grep a tempfile, never echo|grep). L-291: Playwright line scoped to hosts
# that have it installed (else skipped, not failed). Behavioural proof = the S4 Playwright
# suite (33 passed, 2026-05-26); these gate checks confirm the containers render + the
# regression guards ship + a fast behavioural subset re-runs where playwright is present.
# S4a: side panel + dock controls render on /tasks
curl -sf "$(bin/fw watchtower url)/tasks" > /tmp/t1992_tasks.html 2>&1; grep -q 'task-panel' /tmp/t1992_tasks.html && grep -q 'dock' /tmp/t1992_tasks.html
# S4c: filter-chip bar renders when a filter is active (shareable-by-URL)
curl -sf "$(bin/fw watchtower url)/tasks?owner=human" > /tmp/t1992_filt.html 2>&1; grep -q 'filter-chip' /tmp/t1992_filt.html
# S4d: kanban columns render
grep -q 'kanban' /tmp/t1992_tasks.html
# S4e: bulk-action scaffolding renders
grep -q 'bulk' /tmp/t1992_tasks.html
# Behavioural regression guards ship (S4a-e)
test -f tests/playwright/test_task_panel.py && test -f tests/playwright/test_task_panel_edit.py && test -f tests/playwright/test_api_task_inline.py && test -f tests/playwright/test_filter_chips.py && test -f tests/playwright/test_kanban_drag.py && test -f tests/playwright/test_bulk_actions.py
# Behavioural verify — fast subset, scoped (L-291): runs only where playwright is installed
if python3 -c "import playwright" 2>/dev/null; then timeout 200 python3 -m pytest -q -p no:cacheprovider tests/playwright/test_filter_chips.py tests/playwright/test_kanban_drag.py tests/playwright/test_bulk_actions.py > /tmp/t1992_pw.log 2>&1; else echo "playwright not installed on gate host — behavioural subset skipped (L-291)"; fi


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

### 2026-05-26 — Umbrella decomposed into S4a–S4e; rolled up after slices shipped
- **What changed:** The five-deliverable S4 board redesign was (correctly) carved into independent slices at build start rather than built as one — honouring "one task = one deliverable" (CLAUDE.md §Task Sizing). Each slice shipped with its own Playwright guard and `[REVIEW]`.
- **Plan impact:** This umbrella's Agent ACs became roll-up checks satisfied by the shipped slices. The original filing had no Human AC; at roll-up an integrated-composition `[REVIEW]` AC was added — the per-slice reviews verify each feature, but only an integrated review confirms the five compose into one coherent board (the §ACD risk: five green slices ≠ one working board).
- **Triggered:** T-2015 (S4a side-panel + dock), T-2017 (S4b inline-edit), T-2016 (S4c filter-chips), T-2019 (S4d kanban-drag), T-2018 (S4e/S6c bulk-actions) — all shipped, in the review queue. Behavioural proof at roll-up: the S4 Playwright suite (33 passed, 159s, 2026-05-26).

## Recommendation

**Recommendation:** GO

**Rationale:** All 5 Agent ACs verified — not by grep alone (T-1575) but by running the S4 Playwright suite: **33 tests passed** covering panel-opens-no-full-nav, inline-edit-persists, filter-chips-shareable-by-URL, kanban-drag-posts-status, and bulk-actions-fan-out. The board renders all S4 containers live. One integrated-board `[REVIEW]` Human AC remains — whether the five features *compose* coherently (a judgment the per-feature tests can't make).

**Evidence:**
- S4a — `test_task_panel.py::test_click_card_opens_panel_no_full_page_nav` + `test_panel_opens_after_htmx_board_swap` pass; `/tasks` renders `task-panel` + `dock`
- S4b — `test_api_task_inline.py` + `test_task_panel_edit.py::test_change_type_confirms_and_persists` pass (routes through existing per-task update path)
- S4c — `test_filter_chips.py::test_shareable_url_shows_chips` passes; `/tasks?owner=human` renders `filter-chip`
- S4d — `test_kanban_drag.py::test_drag_to_other_column_posts_status_and_toasts` + `test_listeners_survive_content_swap` pass; `/tasks` renders `kanban`
- S4e — `test_bulk_actions.py::test_apply_horizon_fans_out_and_toasts` + `test_listeners_survive_content_swap` pass; `/tasks` renders `bulk` scaffolding
- Full run: `33 passed in 159.17s` (2026-05-26)

**Review:** http://192.168.10.107:3000/review/T-1992

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
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1992-watchtower-tasks-board--list-redesign--s.md
- **Context:** Initial task creation

### 2026-05-25T22:01:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-63076512
- **Timestamp:** 2026-05-25T22:09:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-25T22:08:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
