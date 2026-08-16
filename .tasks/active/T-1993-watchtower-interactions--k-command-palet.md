---
id: T-1993
name: "Watchtower interactions — ⌘K command palette + ?-shortcuts overlay + bulk actions
  + live activity ticker (arc-007 S6)"
description: >
  Cross-cutting interaction layer: (1) ⌘K command palette spanning all entities (tasks,
  arcs, learnings, files, pages, fw commands) — fuzzy match, recent-first, keyboard-only
  flow. (2) ?-press shortcuts overlay listing every keybinding. (3) Bulk-action contract
  — pages opt in via data-bulk-target on tables. (4) Live activity ticker — subtle
  animations on filesystem changes (e.g., task transitions, commits) via SSE or polling.
  Depends on S0+S2+S4 (board/list patterns inform palette UX). Parent inception: T-1987.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, redesign, ui, interactions]
arc_id: watchtower-redesign
components: [tests/playwright/test_cockpit_activity.py, 
      tests/unit/test_cockpit_activity.py, web/blueprints/cockpit.py, 
      web/templates/_cockpit_activity.html, web/templates/cockpit.html]
related_tasks: [T-1987]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-22T10:06:08Z
last_update: '2026-08-16T22:24:02Z'
date_finished: 2026-05-25T22:13:34Z
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
  - ts: '2026-05-23T18:00:01Z'
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
  - ts: '2026-05-25T22:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=0 (no-signal)
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
  - ts: '2026-06-11T22:23:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1993: Watchtower interactions — ⌘K command palette + ?-shortcuts overlay + bulk actions + live activity ticker (arc-007 S6)

## Context

arc-007 S6 — the interaction layer. The redesigned nav (S2, T-1989) deliberately
defers "everything not pinned" to ⌘K: the **icon-rail layout (S2d, T-2011) is only
fully usable once ⌘K exists** — the rail shows 4 group flyouts + pins, and ⌘K is the
escape hatch for the other ~30 destinations. Design reference: the ⌘K bar appears in
all three patterns in `docs/design/watchtower-redesign-2026-05-13/project/nav-patterns.jsx`
("Search or jump to…  ⌘K"). The existing search surface (`web/blueprints/discovery.py`
`search_view`/`search_ask`) is the semantic-search backend ⌘K should reuse, not replace.

**Scoping note (2026-05-23, T-2011 follow-on):** This task as filed bundles FOUR independent
deliverables — that violates "one task = one deliverable" (CLAUDE.md §Task Sizing). It must be
decomposed at build start into sub-slices, highest-leverage first:

- **S6a — ⌘K command palette (core):** a modal overlay opened by ⌘K / Ctrl-K (and a click on
  the existing nav search affordance), with a single input that does two things — (1) fuzzy
  **jump** to any nav destination (`web.shared.NAV_ITEMS` — the same whitelist S2c pins use)
  and (2) **search** content via the existing `discovery.search` backend. Arrow-key + Enter
  navigation, Esc to close, htmx-friendly (works after `#content` swaps). This is the keystone
  that unblocks the rail layout — build this first, ship alone.
- **S6b — `?` keyboard-shortcuts overlay:** a read-only modal listing the keyboard shortcuts
  (⌘K, `?`, `g`-then-key jumps if added), opened by `?`. Small, self-contained, depends on S6a
  existing (so the shortcut list is non-empty).
- **S6c — bulk actions:** multi-select on the Tasks board/list (S5/T-1992 territory) + a bulk
  action bar. Depends on the Tasks redesign (T-1992) landing first — **sequence after T-1992.**
- **S6d — live activity ticker:** an SSE-fed strip of recent framework events. Independent of
  the others; lowest priority (nice-to-have, not on the nav critical path).

Recommend build order: **S6a → S6b**, then S6c after T-1992, S6d last. Start a fresh session
with budget for S6a (modal + keyboard handling + search wiring ≈ a slice the size of S2d).

## Acceptance Criteria

<!-- These are the FULL-SCOPE ACs for the S6 umbrella. Decompose into S6a–S6d sub-slice
     tasks at build start (see Scoping note); each sub-slice carries the subset it ships,
     mirroring how T-1989 (S2) decomposed into T-2008/T-2009/T-2010/T-2011. -->
### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] ⌘K / Ctrl-K (and a click on the nav search affordance) opens a command-palette modal; Esc closes it; it works on a fresh load AND after an htmx `#content` swap (Playwright) — **[S6a]**
- [x] The palette input fuzzy-jumps to any nav destination in `web.shared.NAV_ITEMS` (arrow keys move selection, Enter navigates) AND falls through to the existing `discovery.search` backend for content queries — no second search implementation (Playwright + unit) — **[S6a]**
- [x] `?` opens a keyboard-shortcuts overlay listing the live shortcuts; Esc closes it (Playwright) — **[S6b]**
- [x] Tasks board/list supports multi-select with a bulk-action bar (depends on T-1992); each bulk action routes through the existing per-task endpoint (no new ungated mutation path) — **[S6c]**
- [x] A live activity ticker renders recent framework events via htmx poll (every 15s) and updates without reload (Playwright) — **[S6d]** *(design allowed "SSE or polling"; shipped as poll — see Evolution)*

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
- [ ] [REVIEW] The S6 interactions feel cohesive and keyboard-first — ⌘K palette, ?-overlay, bulk-actions and the live activity ticker work together without shortcut collisions or focus traps
  **Steps:**
  1. Open http://192.168.10.107:3000/
  2. Press ⌘K (or Ctrl-K) → type a few letters → arrow to a destination → Enter; reopen and type a content query → confirm it falls through to search
  3. Press `?` → confirm the shortcuts overlay lists the live shortcuts; Esc closes it
  4. Watch the cockpit activity ticker update on its own (~15s) without a reload; on /tasks multi-select two cards and apply a bulk action
  **Expected:** Shortcuts don't collide, Esc always escapes (no focus trap), the ticker refreshes silently, and the whole thing feels keyboard-first — one coherent interaction layer, not four separate widgets
  **If not:** Note which two interactions collide or where focus gets stuck

## Verification

# L-387-safe (grep a tempfile). L-291: Playwright line scoped to hosts with it installed.
# Behavioural proof = S6 Playwright suite (16 passed + bulk in T-1992's 33-pass run, 2026-05-26).
# S6a: command palette renders + JS loads on every page (base.html)
curl -sf "$(bin/fw watchtower url)/" > /tmp/t1993_home.html 2>&1; grep -q 'command-palette' /tmp/t1993_home.html && grep -q 'data-palette' /tmp/t1993_home.html
# S6b: shortcuts overlay scaffolding renders
grep -q 'shortcuts-overlay' /tmp/t1993_home.html && grep -q 'data-shortcuts' /tmp/t1993_home.html
# S6d: activity feed renders + is wired to the 15s htmx poll (not SSE — see Evolution)
grep -q 'recent-activity' /tmp/t1993_home.html && grep -q 'every 15s' /tmp/t1993_home.html
# Behavioural regression guards ship (S6a/S6b/S6c/S6d)
test -f tests/playwright/test_command_palette.py && test -f tests/playwright/test_shortcuts_overlay.py && test -f tests/playwright/test_cockpit_activity.py && test -f tests/playwright/test_bulk_actions.py
# Behavioural verify — scoped (L-291): runs only where playwright is installed
if python3 -c "import playwright" 2>/dev/null; then timeout 200 python3 -m pytest -q -p no:cacheprovider tests/playwright/test_command_palette.py tests/playwright/test_shortcuts_overlay.py tests/playwright/test_cockpit_activity.py > /tmp/t1993_pw.log 2>&1; else echo "playwright not installed on gate host — behavioural subset skipped (L-291)"; fi


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

### 2026-05-26 — S6d shipped as htmx poll, not SSE; umbrella rolled up after slices
- **What changed:** The S6d AC was narrowed to "via SSE", but the task *description* (line 10) had specified "via SSE **or polling**". T-2020 shipped the activity feed as an htmx poll (`hx-trigger="load, every 15s"`), which is within the original intent and simpler (no long-lived connection, no SSE infra). The AC text was corrected to match the shipped mechanism; `test_cockpit_activity.py::test_card_is_wired_to_poll` pins it.
- **Plan impact:** No SSE endpoint is needed for S6d. The umbrella's Agent ACs became roll-up checks for the shipped slices; an integrated keyboard-cohesion `[REVIEW]` AC was added at roll-up (the original filing had none).
- **Triggered:** T-2012 (S6a ⌘K palette), T-2013 (S6b ?-overlay), T-2018 (S6c bulk-actions, shared with T-1992 S4e), T-2020 (S6d activity poll) — all shipped, in the review queue. Behavioural proof: S6 Playwright suite (16 passed) + bulk in T-1992's 33-pass run.

## Recommendation

**Recommendation:** GO

**Rationale:** All 5 Agent ACs verified by running the S6 Playwright suite (**16 passed**) plus the bulk-action tests (in T-1992's 33-pass run) — not grep alone (T-1575). One AC was *corrected* during roll-up: S6d shipped as htmx poll, not SSE — within the description's "SSE or polling" intent, logged in Evolution. One integrated keyboard-cohesion `[REVIEW]` Human AC remains.

**Evidence:**
- S6a — `test_command_palette.py`: `test_open_close_fresh`, `test_open_close_after_htmx_swap`, `test_search_fallthrough_routes_to_discovery`, `test_jump_targets_are_whitelisted_nav_destinations` pass; `/` renders `command-palette` + `data-palette` + loads `command-palette.js`
- S6b — `test_shortcuts_overlay.py` passes; `/` renders `shortcuts-overlay` + `data-shortcuts`
- S6c — `test_bulk_actions.py` passes (T-1992 run); routes through existing per-task endpoint
- S6d — `test_cockpit_activity.py`: `test_card_loads_activity_entries`, `test_card_is_wired_to_poll` pass; `/` renders `recent-activity` + the `every 15s` poll
- Runs: `16 passed in 100.57s` (S6) + `33 passed in 159.17s` (S4/bulk), 2026-05-26

**Review:** http://192.168.10.107:3000/review/T-1993

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
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1993-watchtower-interactions--k-command-palet.md
- **Context:** Initial task creation

### 2026-05-25T22:09:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e9b3d3bc
- **Timestamp:** 2026-05-25T22:15:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-25T22:13:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
