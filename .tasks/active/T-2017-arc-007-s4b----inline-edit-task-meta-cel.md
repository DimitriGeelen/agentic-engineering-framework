---
id: T-2017
name: "arc-007 S4b -- inline-edit task meta cells in the side panel"
description: >
  arc-007 S4b -- inline-edit task meta cells in the side panel

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:watchtower-redesign, ui, watchtower]
components: [tests/playwright/test_task_panel_edit.py, tests/unit/test_task_panel_edit.py, web/blueprints/tasks.py, web/templates/base.html, web/templates/_task_panel.html]
related_tasks: [T-1992, T-1987, T-2015]
arc_id: watchtower-redesign
created: 2026-05-24T09:05:47Z
last_update: 2026-05-26T06:49:02Z
date_finished: 2026-05-26T06:49:02Z
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
  - ts: '2026-05-24T09:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-24T09:15:03Z'
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

# T-2017: arc-007 S4b -- inline-edit task meta cells in the side panel

## Context

arc-007 S4b, next in the T-1992 build order after S4a (T-2015, the panel keystone) and
S4c (T-2016, filter chips). S4a deliberately shipped the side panel as a **read-only** lean
fragment (`_task_panel.html`), deferring all editing here. Its Evolution note set this slice's
scope precisely: inline-edit must be wired **into the panel** with **no document-level listener
accumulation** (the reason `task_detail.html` could not be reused as-is — its inline `<script>`
leaks one `htmx:afterRequest` listener per open).

S4b makes the panel's meta cells (status, owner, horizon, workflow_type) inline-editable by
reusing the existing `inline_select` macro (`web/templates/_partials/inline_select.html`) and the
existing `/api/task/<id>/{status,owner,horizon,type}` endpoints — **zero new JS**. The macro is
self-contained (hx-post + `_csrf_token` hidden field + `onchange="this.form.requestSubmit()"`);
htmx processes the swapped fragment and the inline onchange handler needs no binding, so there is
no listener to accumulate. CSRF is doubly covered (hidden field + the body-level
`htmx:configRequest` header listener in `csrf-htmx.js`).

**Deferred (out of scope, documented in Evolution):** live board-cell sync — after an in-panel
edit the board card behind the panel stays stale until the next board load. The inline confirmation
("Owner set to …") signals the save; cross-surface live-sync is a separate concern.

## Acceptance Criteria

### Agent
- [x] `task_panel` route passes the enum option lists (`status_options`, `enum_owners`, `enum_horizons`, `enum_types` from `_load_enums()`) to `_task_panel.html`
- [x] `_task_panel.html` imports `inline_select` and renders an editable select for status, owner, horizon, and workflow_type — each hx-post to its existing `/api/task/<id>/<field>` endpoint with its own panel-scoped result span
- [x] No new document-level JS listener is added for panel editing (idempotent: htmx + the macro's inline onchange only — `task-panel.js` is unchanged for edit wiring)
- [x] Unit test (`tests/unit/test_task_panel_edit.py`): panel fragment contains the four inline-edit forms posting to the correct endpoints and each carries a `_csrf_token` field
- [x] Unit test: posting an invalid value to a panel-driven endpoint is rejected (enum validation still enforced) and a valid value persists via `fw task update`
- [x] Playwright test (`tests/playwright/test_task_panel_edit.py`): open panel → change a meta select → confirmation text appears → reopen panel shows the new value persisted (round-trips `type`, a governance-neutral field; see Evolution for why not horizon/owner)
- [x] Regression: `tests/unit/test_task_panel.py` (S4a read view), `test_filter_chips.py` (S4c), and the S6a/S6b suites (unit + playwright) stay green

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
- [ ] [REVIEW] Editing a meta cell in the panel feels responsive and unambiguous
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` to get the base URL, open `<url>/tasks`
  2. Click any task id to open the side panel
  3. Change the **Type** select (e.g. build → refactor); watch the confirmation. (Type is reversible with no cascade — set it back after. Owner on a human-owned task is intentionally refused with a toast — that's R-033 working, not a bug.)
  4. Close and reopen the panel for that task
  **Expected:** The change saves with a clear inline confirmation next to the select; on reopen the new value is shown; the edit controls read cleanly within the panel layout (no cramped/overflowing rhythm)
  **If not:** Note which cell and what felt off (confirmation unclear, layout cramped, value not persisted)

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
python3 -m pytest tests/unit/test_task_panel_edit.py tests/unit/test_task_panel.py tests/unit/test_filter_chips.py -q
out=$(bin/fw reviewer T-2017 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

### 2026-05-24 — edit wiring needs zero new JS; the macro already solves the listener-leak
- **What changed:** S4a's Evolution note framed S4b as "wire inline-edit into the panel with panel-scoped, idempotent listeners" — implying custom JS would be needed. Recon found the opposite: the existing `inline_select` macro is fully self-contained (hx-post form + `_csrf_token` hidden field + inline `onchange="this.form.requestSubmit()"`), and the `/api/task/<id>/{status,owner,horizon,type}` endpoints already exist and validate against `_load_enums()`. htmx processes swapped fragments automatically, so dropping the macro into `_task_panel.html` wires the edits with **no document-level listener at all** — which is strictly better than "a panel-scoped listener" because there is nothing to accumulate or leak.
- **Plan impact:** S4b reduces to: (1) pass the four enum lists from the panel route, (2) swap the static read `<dd>` cells for `inline_select` calls + result spans. No `task-panel.js` change for editing. The "idempotent panel-scoped listener" design the note anticipated is unnecessary.
- **Triggered:** Live board-cell sync explicitly carved OUT of S4b (board card stays stale until next board load; inline confirmation covers the save signal). Captured as a candidate follow-up micro-slice rather than scope-creeping S4b. No task filed yet.

### 2026-05-24 — edits inherit the detail page's governance rails + error feedback (parity, not new code)
- **What changed:** Building the Playwright test surfaced two behaviours of the *shared* endpoints that the panel now inherits for free: (1) **R-033** — `/api/task/<id>/owner` refuses to reassign a human-owned task (500 "human ownership is protected"); (2) htmx 2.x does not swap non-2xx responses, but a global `htmx:responseError` handler (base.html:862) already surfaces the error text as a **toast**. So in-panel edits give feedback on *both* paths: success → the panel-scoped result span; rejection → a toast. There is no silent-failure gap, and nothing panel-specific was needed — the panel is at full parity with `task_detail.html`.
- **Plan impact:** Confirms S4b is genuinely "make the panel cells editable" with zero behavioural divergence from the detail page. No error-feedback work to do here.
- **Triggered:** Test target moved off `owner` (R-033 protected) and `horizon` (T-1068 demote cascade on started-work tasks) onto `workflow_type` — the one meta field with no ownership protection and no status cascade — so the round-trip is net-zero on repo state. The [REVIEW] steps were likewise re-pointed to Type to avoid recommending a cascading change.

## Decisions

### 2026-05-24 — reuse inline_select macro + existing endpoints, no bespoke panel-edit JS
- **Chose:** Render the panel meta cells with the shared `inline_select` macro, POSTing to the already-existing `/api/task/<id>/{status,owner,horizon,type}` endpoints; add no new JS.
- **Why:** The macro + endpoints are the same surface the full detail page uses, so behaviour and validation cannot drift. htmx auto-processes the swapped fragment and the macro's inline onchange submits — zero listener accumulation, directly satisfying S4a's "idempotent, panel-scoped" requirement by having nothing to bind.
- **Rejected:** (a) Reusing `task_detail.html`'s editable widgets wholesale — rejected in S4a for the document-level `htmx:afterRequest` leak. (b) A custom `task-panel.js` edit-binding pass — unnecessary given htmx's swap processing; would add a listener to maintain for no benefit.

### 2026-05-24 — defer live board-cell sync
- **Chose:** After an in-panel edit, show inline confirmation only; the board card behind the panel refreshes on next board load, not live.
- **Why:** Live cross-surface sync is a distinct concern (which board cell, preserving open-panel state, filter-aware refresh URL) that would bloat this slice past "one deliverable". The confirmation makes the save unambiguous.
- **Rejected:** Triggering a `#content` board refresh on edit success — adds JS state + a test burden and risks disrupting the open panel; better as its own micro-slice if the human wants it.

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO

**Rationale:** The side panel's meta cells (status / owner / horizon / type) are now inline-editable
for active tasks, completing the keystone editing slice of the Tasks-board redesign. The
implementation reuses the shared `inline_select` macro + the existing `/api/task/<id>/<field>`
endpoints, so it adds **zero new JS** and cannot drift from the full detail page — it inherits the
same validation, CSRF protection, governance rails (R-033 owner protection), and error feedback
(toast on rejection, confirmation span on success). This is strictly better than the "panel-scoped
listener" S4a anticipated: there is no listener to accumulate. All 7 Agent ACs pass; the reviewer
returns PASS with no findings. One [REVIEW] Human AC remains — a taste/feel check on the editing
interaction — which is sovereignty-reserved.

**Evidence:**
- `web/blueprints/tasks.py` — `task_panel` route passes `editable` + the four enum lists; gates editing to active tasks (completed render read-only, since their status falls outside the active enum).
- `web/templates/_task_panel.html` — imports `inline_select`; renders editable selects + panel-scoped result spans for active tasks, read-only `<dd>`s otherwise.
- `web/templates/base.html` — compact CSS for the panel edit cells (no JS added).
- Unit: `tests/unit/test_task_panel_edit.py` — 5/5 (editable selects + CSRF on active; read-only on completed; invalid enum → 400; valid → `fw task update` via mock; CSRF enforced).
- Playwright: `tests/playwright/test_task_panel_edit.py` — 3/3 (selects visible; type round-trip confirms + persists across reopen; review screenshot captured).
- Regression: S4a `test_task_panel.py`, S4c `test_filter_chips.py`, S6a/S6b palette+overlay — 22 playwright + (16+17) unit green.
- Eyes-on: `web/static/ux-review/T-2017-panel-inline-edit.png` — edit cells render cleanly in the 2-col meta grid, no crowding.
- Reviewer: `bin/fw reviewer T-2017` → Overall PASS, needs_human=no, findings none.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-24T09:05:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2017-arc-007-s4b----inline-edit-task-meta-cel.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5f2cad29
- **Timestamp:** 2026-05-26T06:49:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-26T06:49:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
