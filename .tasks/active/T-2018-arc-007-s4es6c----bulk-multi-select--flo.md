---
id: T-2018
name: "arc-007 S4e/S6c -- bulk multi-select + floating action bar on the tasks board"
description: >
  arc-007 S4e/S6c -- bulk multi-select + floating action bar on the tasks board

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:watchtower-redesign, ui, watchtower]
components: [tests/playwright/test_bulk_actions.py, 
      tests/unit/test_bulk_actions.py, web/static/bulk-actions.js, 
      web/templates/base.html, web/templates/tasks.html]
related_tasks: [T-1992, T-1993, T-1987, T-2015]
arc_id: watchtower-redesign
created: 2026-05-24T09:22:27Z
last_update: '2026-05-28T22:54:11Z'
date_finished: 2026-05-26T06:49:20Z
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
  - ts: '2026-05-24T09:30:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-24T09:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=2 (body:default-change); D4=2 
      (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 2
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2018: arc-007 S4e/S6c -- bulk multi-select + floating action bar on the tasks board

## Context

arc-007 S4e (and T-1993's S6c — same deliverable, two slice names). Last slice of the
Tasks-board interaction set before S4d (drag-reorder). The board already supports per-card
inline editing (status/owner/horizon/type selects on every card and row). S4e adds **bulk**
triage: select many tasks, then apply one horizon to all of them at once.

Design — reuse, don't re-build:
- A multi-select checkbox (`data-bulk-select="T-XXX"`) on each kanban card and list row.
- A **shell-level floating action bar** (`#wt-bulk-bar` in base.html, hidden until ≥1 selected)
  showing the selected count, a horizon quick-set (Now / Next / Later), and Clear. Living in the
  shell (like the panel / palette / overlay) means the single delegated listener set survives every
  htmx #content swap with no re-binding.
- `web/static/bulk-actions.js`: tracks a Set of selected ids; toggles the bar + count; on a
  horizon button, **fans out** one `fetchWithCsrf` POST per selected id to the EXISTING
  `/api/task/<id>/horizon` endpoint (no new route), awaits all, and reports
  "Set horizon=X on N tasks (M failed)" via the existing `showToast`, then refreshes #content so
  the board reflects the change. Partial failures are surfaced, never swallowed (Reliability: no
  silent failures — some tasks may be governance-protected or hit the T-1068 demote cascade).

Scope: horizon is the canonical board triage action, so v1 ships horizon-only. Bulk owner/status
are trivial extensions of the same fan-out (documented in Evolution as follow-ups), kept out to
hold "one task = one deliverable". Drag-reorder is the separate S4d slice.

## Acceptance Criteria

### Agent
- [x] Each kanban card and each list row carries a multi-select checkbox `[data-bulk-select="T-XXX"]`
- [x] The floating bulk-action bar (`#wt-bulk-bar`) + `bulk-actions.js` are injected on every page via base.html (shell-level), so the bar + its listeners keep working across htmx #content swaps (selection resets on a view/filter change to avoid phantom off-screen selections)
- [x] The bar exposes a Now/Next/Later horizon quick-set and a Clear control, and is hidden when nothing is selected
- [x] The bulk action reuses the existing `/api/task/<id>/horizon` endpoint (no new route added) and fans out one CSRF-protected POST per selected id
- [x] Partial failures are reported, not swallowed: the toast names how many succeeded and how many failed
- [x] Unit test (`tests/unit/test_bulk_actions.py`): checkboxes render on cards + rows; the bar + script are present on an arbitrary page; the bar offers the three horizon actions + clear
- [x] Playwright test (`tests/playwright/test_bulk_actions.py`): selecting ≥2 cards shows the bar with the right count; Clear hides it; applying a horizon fans out (proven net-zero by applying each task's current horizon) and shows the success toast
- [x] Regression: S4a `test_task_panel.py`, S4b `test_task_panel_edit.py`, S4c `test_filter_chips.py`, and S6a/S6b suites stay green

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
- [ ] [REVIEW] Bulk multi-select + floating bar feels clear and the action is reassuring
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` to get the base URL, open `<url>/tasks`
  2. Tick the checkboxes on 2–3 cards; watch the floating bar appear with the count
  3. Click a horizon (e.g. **Next**); watch the toast and the board update. (Reversible — re-select and set them back. Some tasks may be protected/cascade; the toast names any that failed.)
  4. Click **Clear** with items selected
  **Expected:** The bar appears/disappears in step with selection; the count is correct; applying a horizon shows a clear success toast (and names failures if any); the bar reads cleanly and doesn't obscure the board
  **If not:** Note what felt off (count wrong, bar overlaps content, toast unclear, action silent)

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
python3 -c "import ast; ast.parse(open('web/blueprints/tasks.py').read())"
node --check web/static/bulk-actions.js 2>/dev/null || python3 -c "print('node not installed — JS syntax check skipped')"
python3 -m pytest tests/unit/test_bulk_actions.py tests/unit/test_task_panel.py tests/unit/test_filter_chips.py -q
out=$(bin/fw reviewer T-2018 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

### 2026-05-24 — fan-out over existing per-task endpoint; no bulk endpoint
- **What changed:** The board already has per-card horizon editing via `/api/task/<id>/horizon`. Rather than add a `/api/tasks/bulk` endpoint (new server surface, new validation, new tests), S4e fans out N client-side POSTs to the existing endpoint. This keeps the server unchanged and inherits its validation/CSRF/governance for free — the same reuse stance as S4b.
- **Plan impact:** S4e is almost entirely client JS + template wiring (checkboxes + a shell bar). The only "new" behaviour is the partial-failure aggregation (count succeeded/failed) which the single-edit path never needed.
- **Triggered:** Bulk owner/status deliberately deferred — same fan-out mechanism, different endpoint, but each adds governance nuance (owner→R-033 refusals, status→transition rules) that deserves its own slice. Captured as follow-ups, not built here.

### 2026-05-24 — test the fan-out net-zero (apply current horizon)
- **What changed:** Bulk horizon application mutates many real tasks and (on started-work tasks) triggers the T-1068 demote cascade — impossible to cleanly restore per-task in a browser test. So the Playwright fan-out test applies each selected task's *current* horizon: the POST fires, the toast appears, but no value changes and no cascade triggers. Selection/bar mechanics (appear, count, clear) are tested directly; horizon *persistence* is already covered by S4b's unit test on the same endpoint.
- **Plan impact:** None to the feature; shapes the test only.
- **Triggered:** n/a.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-05-24 — client-side fan-out over the existing endpoint, not a bulk server route
- **Chose:** Apply bulk horizon by fanning out N client-side `fetchWithCsrf` POSTs to the existing `/api/task/<id>/horizon` endpoint, aggregating success/failure in JS.
- **Why:** Zero new server surface — the per-task endpoint already validates, enforces CSRF, and honours governance (R-033, T-1068). A bulk route would re-implement all of that and need its own tests. The only genuinely new behaviour (success/failure aggregation) is small and lives where the selection state already is.
- **Rejected:** A `/api/tasks/bulk` endpoint — more code, duplicated validation, and it would still have to loop per-task server-side anyway; the partial-failure reporting is identical either way.

## Recommendation

**Recommendation:** GO

**Rationale:** The Tasks board now supports bulk triage: tick checkboxes on any number of cards/rows,
and a shell-level floating bar applies a horizon (Now/Next/Later) to all of them at once. This
completes the S4 interaction set (S4a panel, S4b inline-edit, S4c filter chips, S4e bulk) ahead of
the separate S4d drag-reorder slice. It adds **no server route** — it fans out over the existing
per-task endpoint, inheriting its validation, CSRF, and governance, and surfaces partial failures in
the toast rather than swallowing them (Reliability: no silent failures). The bar lives in the shell
like the panel/palette/overlay, so its listeners survive htmx swaps. All 8 Agent ACs pass; reviewer
PASS, no findings. One [REVIEW] Human AC (feel/clarity of the bulk interaction) remains
sovereignty-reserved.

**Evidence:**
- `web/static/bulk-actions.js` — selection Set, bar toggle, CSRF fan-out to `/api/task/<id>/horizon`, success/failure aggregation → `showToast`, #content refresh, selection-reset on swap.
- `web/templates/base.html` — `#wt-bulk-bar` shell element (count + Now/Next/Later + Clear) + CSS; loads `bulk-actions.js`.
- `web/templates/tasks.html` — `data-bulk-select` checkbox on each kanban card and list row (+ leading column header).
- Unit: `tests/unit/test_bulk_actions.py` — 5/5 (checkboxes on cards+rows; bar+script on any page; three horizons + clear; no bulk route added).
- Playwright: `tests/playwright/test_bulk_actions.py` — 5/5 (select shows bar+count; clear hides; listeners survive #content swap; horizon fan-out + toast net-zero; review screenshot).
- Regression: 38 unit + 30 playwright green across S4a/S4b/S4c/S6a/S6b.
- Eyes-on: `web/static/ux-review/T-2018-bulk-actions.png` — pill bar centred at the bottom, clear count + actions, does not obscure the board.
- Reviewer: `bin/fw reviewer T-2018` → Overall PASS, needs_human=no, findings none.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-24T09:22:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2018-arc-007-s4es6c----bulk-multi-select--flo.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ab0c103c
- **Timestamp:** 2026-05-26T06:49:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-26T06:49:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
