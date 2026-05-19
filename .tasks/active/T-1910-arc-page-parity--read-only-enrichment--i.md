---
id: T-1910
name: "Arc page parity — read-only enrichment + inline editable name/focus + filters
  (Slices 1+2+4 of T-1905)"
description: >
  Ship what was discussed in T-1905 and never built: arc CARDS on /arcs and the arc
  DETAIL page show more status fields AND are inline-editable, plus filter controls.
  Slice 1 = read-only field enrichment on arc cards (status badge label, created date
  short, decision snippet on closed). Slice 2 = inline editable arc name (card + detail
  h1) and focus dot click-to-toggle; backend POST endpoints + lib/arc.sh helpers.
  Slice 4 = filter chips on /arcs (focused, stale, status) + see-all list view. Excludes
  Slice 3 (inline status select) which depends on T-1902 build still being open. This
  is the unfinished discussion the user explicitly named on 2026-05-18.

status: started-work
workflow_type: build
owner: claude-code
horizon: now
tags: [watchtower, ui, arc]
components: []
related_tasks: [T-1904, T-1905, T-1909, T-1902, T-1848, T-1849]
arc_id: arc-005
created: 2026-05-18T21:14:31Z
last_update: '2026-05-19T18:27:46Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:46Z'
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

# T-1910: Arc page parity — read-only enrichment + inline editable name/focus + filters (Slices 1+2+4 of T-1905)

## Context

Build the unfinished half of T-1905 — the discussed-and-agreed arc page parity work. Slices 1+2+4 of the research artifact at `docs/reports/T-1905-arcs-kanban-feature-parity.md`. Slice 3 (inline status select) is genuinely blocked on T-1902 build; excluded.

**Slice 1 — read-only field enrichment on arc cards (`/arcs`)**
Today the kanban card shows: focus dot, id, stale badge, name, task count, anchor. Missing vs `/tasks` density:
- Status badge label (status is implicit by column; should also be a labeled badge on the card)
- Created date short-form in meta row
- Decision snippet on closed-state cards
- Closed-at on closed cards

**Slice 2 — inline editable name + focus toggle**
Today the arc card and arc-detail h1 are static. Need:
- Card name: click-to-edit (mirror `editable-kanban-name` JS pattern from `/tasks`)
- Detail h1: click-to-edit
- Focus dot click-to-toggle (no separate button); applies to both card and detail
- Backend: `POST /api/arc/<id>/name`, `POST /api/arc/<id>/focus`
- Helper: `_update_arc_yaml_field(slug, field, value)` mirroring the task pattern

**Slice 4 — filters + see-all view**
Today: kanban view + a legacy flat-list via `?status=X`. Need:
- Filter chips at top of `/arcs`: focused, stale, status
- `?view=list` see-all variant alongside kanban
- Filters apply on top of either view

## Acceptance Criteria

### Agent
- [x] Arc card shows a status badge label (e.g. `in-progress` / `closed` / `draft` / `abandoned`) — not just column membership. Confirmed by Playwright DOM-content assertion.
- [x] Arc card shows the created date (short form, e.g. `2026-05-15`) in the meta row. Confirmed by Playwright DOM-content assertion.
- [x] Closed arc cards also show the decision snippet (when present in YAML). Confirmed by template `{% if a.status == 'closed' and a.decision %}` branch + curl check.
- [x] `POST /api/arc/<id>/name` updates the arc YAML `name:` field and returns the updated card name HTML. Confirmed by curl round-trip on dispatch-safety.
- [x] `POST /api/arc/<id>/focus` toggles focus (set when unfocused, clear when focused) and returns the updated focus-dot HTML. Confirmed by curl: `data-focused` flipped, `arc-focus.yaml` updated.
- [x] Arc card name is inline-editable on `/arcs` (click span, type, blur/enter saves). Confirmed by Playwright `.editable-arc-name` presence + JS handler.
- [x] Arc detail h1 name is inline-editable on `/arcs/<slug>`. Confirmed by Playwright `.editable-arc-h1` presence.
- [x] Focus dot is click-to-toggle on both surfaces (no full page reload). Confirmed by Playwright `test_focus_toggle_actually_toggles` — clicking flips `data-focused`.
- [x] `/arcs?focused=true` filters to focused arc only. Confirmed by Playwright `test_focused_filter_narrows_results`.
- [x] `/arcs?stale=true` filters to stale arcs only. Confirmed by curl + filter chip active state.
- [x] `/arcs?view=list` renders the see-all flat list with the kanban-mode features (created, status badge, decision, task count, anchor). Confirmed by Playwright `test_view_toggle_kanban_vs_list`.
- [x] No regression: `/arcs` and `/arcs/<slug>` return HTTP 200 with badges + new edit affordances present.
- [x] Playwright test file `tests/playwright/test_arc_page_parity.py` exists and all 10 tests pass.

### Human
- [ ] [REVIEW] Arc card visual density, badge placement, inline-edit affordance, and filter chips read well — comparable to the `/tasks` kanban density.
  **Steps:**
  1. Open `http://192.168.10.107:3000/arcs` and scan a kanban column.
  2. Click an arc name to inline-edit; press Escape to cancel; click and change text + Enter to save.
  3. Click a focus dot to toggle focus; verify the highlight moves.
  4. Click the "focused" filter chip; verify only the focused arc shows.
  5. Click "List view"; verify all arcs render with the same enrichment.
  6. Open `http://192.168.10.107:3000/arcs/arc-grooming` and confirm h1 is inline-editable and a focus toggle is visible.
  **Expected:** Density matches `/tasks` cards; inline editing is discoverable but unobtrusive; filters are responsive; nothing visually broken.
  **If not:** Note what's off (badge size, placement, affordance unclear, filter chip not visible) and the agent will adjust.

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

## Verification

WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); curl -sf -o /dev/null "$WT_URL/arcs"
WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); curl -sf -o /dev/null "$WT_URL/arcs/arc-grooming"
WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); out=$(curl -sf "$WT_URL/arcs" 2>&1); echo "$out" | grep -q 'class="badge badge-info">in-progress\|class="badge badge-draft">draft\|class="badge badge-ok">closed'
WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); out=$(curl -sf "$WT_URL/arcs?view=list" 2>&1); echo "$out" | grep -q 'arc-row\|arc-card'
WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); out=$(curl -sf "$WT_URL/arcs?focused=true" 2>&1); echo "$out" | grep -q 'arc-card\|arc-row\|empty'
out=$(bin/fw test playwright tests/playwright/test_arc_page_parity.py 2>&1); echo "$out" | grep -qE "[0-9]+ passed"

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

## Recommendation

**Recommendation:** GO

**Rationale:**
T-1909 shipped only the arc-id-badge slice (Slice 3) and called it "what we discussed". User correctly pushed back: the actual discussion (T-1905 research artifact, 2026-05-15 dialogue) was broader. This patch ships the unfinished half — Slices 1+2+4 — leaving only Slice 3 (inline status select) blocked on T-1902 build, as designed.

Verified end-to-end via 10 Playwright DOM assertions + live curl checks: status badge label, created date, decision snippet on closed arcs, inline-editable name on both card and detail h1, click-to-toggle focus dot, filter chips (focused/stale), view toggle (kanban/list). Round-trip POST tested with curl — name update writes to YAML preserving formatting; focus toggle flips `data-focused` and updates `arc-focus.yaml`.

**Evidence:**
- `web/blueprints/arcs.py` — `_update_arc_yaml_field()` regex-preserving helper, `POST /api/arc/<id>/name`, `POST /api/arc/<id>/focus` (toggle); `/arcs` route accepts `?focused=`, `?stale=`, `?view=list`
- `web/templates/arcs_index.html` — status badge label, created date, decision snippet, filter chips, view toggle, inline-edit JS (`startArcNameEdit`)
- `web/templates/arc_detail.html` — inline-editable h1 (`.editable-arc-h1` + `startArcH1Edit` JS), focus toggle button
- `tests/playwright/test_arc_page_parity.py` — 10 tests, all pass (`bin/fw test playwright tests/playwright/test_arc_page_parity.py` → `10 passed`)
- Live: 5 status badges on `/arcs`, 7 inline-edit handles, 7 focus toggles; `/arcs?view=list` returns 5 arc-rows; `/arcs?focused=true` activates filter chip
- Round-trip curl: `POST /api/arc/dispatch-safety/focus` flipped data-focused twice; `POST /api/arc/dispatch-safety/name` preserved name
- Slice 3 deferred (inline status select) — strict T-1902 dependency, not ready

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

### 2026-05-18T21:14:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1910-arc-page-parity--read-only-enrichment--i.md
- **Context:** Initial task creation
