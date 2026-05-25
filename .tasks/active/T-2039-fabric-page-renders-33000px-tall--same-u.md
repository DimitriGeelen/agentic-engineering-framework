---
id: T-2039
name: "fabric page renders 33000px tall — same unbounded-list class as T-2038"
description: >
  ux-review sweep (T-2005) flags /fabric as clipped @33109px — a second pathologically-tall
  Watchtower page, same data-growth class as T-2038 (/approvals). Likely the component
  listing/table rendering all 756 fabric cards unbounded. Bound the rendered height
  (collapse/paginate/virtualize) without hiding components, mirroring the T-2038 approach.
  Render surface — needs [REVIEW]. Verify via tests/playwright (scrollHeight < 8000)
  and the sweep Capture column going full.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc-007, perf, watchtower, fabric, ui, render-surface]
components: []
related_tasks: [T-2038, T-2005]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T13:41:27Z
last_update: 2026-05-25T13:45:02Z
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
  - ts: '2026-05-25T13:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-25T13:45:02Z'
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

# T-2039: fabric page renders 33000px tall — same unbounded-list class as T-2038

## Context

The ux-review sweep (T-2005) flagged `/fabric` as `⚠️ clipped @33109px` — a second
pathologically-tall Watchtower page, the same data-growth class as T-2038 (`/approvals`).
The driver is the component listing in `web/templates/fabric.html`: a `<table>` with
**758 component rows** (`{% raw %}{% for c in components %}{% endraw %}`) rendered with
no bound — measured 31,289px of table inside a 32,892px `#content` (probe 2026-05-25).
The page already has server-side search + subsystem/type filters, but with no filter
active every component renders. Unlike `/approvals` (a list of cards, fixed with a
collapsed `<details>`), this is a `<table>` — `<details>` can't legally wrap `<tr>`,
so the fix is a `max-height` + `overflow-y:auto` scroll container with a sticky header:
the page height is bounded, every row stays in the DOM (reachable by scrolling), and a
`full_page` screenshot then captures the bounded page.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `/fabric` renders with bounded height regardless of component count: a Playwright/`scrollHeight` measurement of the loaded page stays below the `_safe_shot` cap (8000px). Mechanism: the component table sits in a `max-height` + `overflow-y:auto` scroll container (chosen mechanism stated in `## Decisions`). Measured **2,428px** (was 33,153px); 580px internal scroll container. Guarded by `tests/playwright/test_fabric_height.py::test_fabric_height_bounded`.
- [x] No components dropped: all `<tbody> <tr>` component rows remain in the DOM and reachable (scroll the container) — row count equals `total_components` when unfiltered. All **758** rows present in the DOM inside `.fabric-table-scroll` (== 758 total components). Guarded by `tests/playwright/test_fabric_height.py::test_fabric_rows_in_scroll_container`.
- [x] After the fix, `fw ux-review --sweep` captures `/fabric` as `full` (not `clipped`) — the sweep report's Capture column shows `full` for `/fabric`. Confirmed in `docs/reports/T-2002-ux-review-arc-007-s0-s1.md` — all 5 sweep pages now `full` (`/fabric` was `⚠️ clipped @33109px`).

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
- [ ] [REVIEW] /fabric is usable after the height fix — the component table scrolls cleanly within its bounded container and nothing important is hidden
  **Steps:**
  1. Open `http://192.168.10.107:3000/fabric` in a browser
  2. Confirm the page is a sane length (no 33k-px endless scroll); the table scrolls within its own region with the header staying visible
  3. Scroll to the bottom of the table — confirm all components are reachable; spot-check the search/subsystem filters still narrow the list
  **Expected:** The page fits the screen; the table has an internal scroll; every component row is reachable; filters work
  **If not:** Note where the layout breaks or a component feels unreachable

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
curl -sf "$(bin/fw watchtower url)/fabric" >/dev/null
python3 -m pytest tests/playwright/test_fabric_height.py -q >/tmp/.t2039_pt.out 2>&1; tail -3 /tmp/.t2039_pt.out; grep -q "2 passed" /tmp/.t2039_pt.out

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

**Symptom:** `/fabric` rendered 33,153px tall — the component listing scrolled endlessly and the ux-review sweep clipped it at `@33109px`.

**Root cause:** `web/templates/fabric.html` renders the full component table — `{% raw %}{% for c in components %}{% endraw %}` over all 758 components — with no height bound. The `<table>` alone was 31,289px. Height grew linearly and unboundedly with the registered fabric (756 cards and rising).

**Why structurally allowed:** identical class to T-2038 (`/approvals`) — the page was authored when the fabric had a handful of components, nothing measured rendered height, and the page degraded silently as the fabric grew to 758. Data growth, not a code regression. It surfaced only because the tall page tripped a *tool* (the sweep's `full_page` screenshot), not because the page itself was noticed.

**Prevention:** `tests/playwright/test_fabric_height.py` asserts `/fabric` scrollHeight stays under the 8000px cap and that the table lives in a bounded scroll container shorter than its content. The ux-review sweep Capture column (T-2005) is the second line of defence — it is exactly what caught this instance after T-2038 cleared `/approvals`. Both pages are now part of a recurring sweep that flags any future page breaching the cap.

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

### 2026-05-25 — table needs a different mechanism than /approvals
- **What changed:** T-2038's collapsed-`<details>` overflow mechanism does not transfer to `/fabric`, because the height driver is a `<table>` and `<details>` cannot legally wrap `<tr>` elements. The right primitive for a table is a `max-height` + `overflow-y:auto` scroll container with a sticky header.
- **Plan impact:** "mirroring the T-2038 approach" (from the task description) held at the *outcome* level (bound height, drop nothing) but not the *mechanism* level. Same data-growth class, different DOM shape → different fix.
- **Triggered:** No new sub-tasks. Confirmed the sweep Capture column (T-2005) is the durable detector for this class — it found `/fabric` immediately after `/approvals` was cleared. All 5 sweep pages now report `full`.

## Decisions

### 2026-05-25 — bounding mechanism for the component table
- **Chose:** Wrap the 758-row component `<table>` in `<div class="fabric-table-scroll">` with `max-height: calc(100vh - 320px)` + `overflow-y:auto`, and make `thead th` `position:sticky; top:0`. Page `scrollHeight` is bounded by the container; all rows stay in the DOM and are reached by scrolling the container; the sticky header keeps columns labelled.
- **Why:** Correct primitive for a table (collapse-`<details>` is invalid around `<tr>`); responsive (`vh`-based, fills the screen minus the filter chrome); zero JS; nothing dropped; directly bounds the measured metric. Measured 33,153px → 2,428px.
- **Rejected:** (1) *Collapsed `<details>` overflow (the T-2038 fix)* — invalid HTML around `<tr>`. (2) *Server-side row limit + "show all"* — more code, and the existing search/subsystem filters already let users narrow; a scroll container needs no new route. (3) *JS virtualization* — overkill for a static server-rendered table.

## Recommendation

**Recommendation:** GO (ship the height bound)

**Rationale:** The one open AC is a `[REVIEW]` judgment call — whether the bounded `/fabric` table scrolls cleanly and hides nothing. All three Agent ACs are verified: height dropped 33,153px → 2,428px (under the 8000px cap), all 758 component rows remain in the DOM inside the scroll container, and the sweep now captures the page as `full`. Template-only change (one file), zero JS, guarded by a new Playwright regression test.

**Evidence:**
- `scrollHeight` 33,153px → **2,428px** (Playwright; 580px internal scroll container; sticky header confirmed)
- **758/758** component rows in the DOM inside `.fabric-table-scroll`
- `docs/reports/T-2002-ux-review-arc-007-s0-s1.md`: all 5 sweep pages `full` (`/fabric` was `⚠️ clipped @33109px`)
- `tests/playwright/test_fabric_height.py` — 2 passed
- Screenshot: `web/static/ux-review/T-2039-fabric-bounded.png` (served live)

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-25T13:41:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2039-fabric-page-renders-33000px-tall--same-u.md
- **Context:** Initial task creation

### 2026-05-25T13:45:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
