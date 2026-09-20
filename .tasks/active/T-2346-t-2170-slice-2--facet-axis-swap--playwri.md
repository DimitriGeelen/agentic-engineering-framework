---
id: T-2346
name: "T-2170 Slice 2 — facet axis-swap + Playwright pin"
description: >
  Slice 2 of T-2170 BVP per-driver display. AC#3: facet toggle row above /bvp scatter
  (one checkbox per driver) that swaps X/Y axes from BVP_norm/cost composite to per-driver
  score on toggle. AC#5: Playwright test tests/playwright/test_bvp_per_driver_display.py
  covering (a) D1-D4 column headers present in /bvp page (Slice 1 contract), (b) hovering
  D1 header reveals rubric tooltip, (c) facet checkbox toggles scatter axis label.
  Slice 1 (T-2170) ships per-driver score columns + data-driver-id + title= rubric
  tooltip (template-only changes); Slice 2 needs scatter.js axis swap + Playwright
  wire.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bvp-display, v3-followup-D, arc:value-prioritisation]
components: []
related_tasks: [T-2170, T-1928, T-1929]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-06-12T06:58:59Z
last_update: '2026-09-20T17:30:07Z'
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
bvp_scores_proposed:
  - ts: '2026-06-12T07:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-07T10:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-09-20T17:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-12T07:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 6
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=6 (lines=145,acs=4)
    rubric_sha: e4a00f38e801
  - ts: '2026-09-20T17:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=196,acs=7)
    rubric_sha: e4a00f38e801
---

# T-2346: T-2170 Slice 2 — facet axis-swap + Playwright pin

## Context

Slice 2 of T-2170. The scatter's D3 render lives inline in `web/templates/bvp.html`
(no separate `scatter.js` — the file doesn't exist; the parent task's "scatter.js"
mention was aspirational). `drawPoints(taskData, arcData)` closes over `x`/`y` scales
and re-runs on `window.bvpRedrawScatter` (the T-1929 slider hook); this task adds a
facet checkbox row that swaps `y`'s domain/accessor between `bvp_norm` and a chosen
driver's raw score, then calls the same redraw path.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **AC1 Facet row rendered:** `/bvp` scatter gains a checkbox row above `#scatter-quadrant`
      (`id="bvp-axis-facets"`), one checkbox per driver in `weights` (D1-D4 + active
      free-drivers, same data-driven iteration as the Slice-1 per-driver table so a new
      driver needs zero template change). Default state: all unchecked, Y axis = `bvp_norm`
      (current behaviour byte-identical to pre-Slice-2).
- [x] **AC2 Single-active-facet axis swap:** Checking a facet sets Y axis to that driver's
      raw 0-5 score (rescaled domain `[0,5]`), updates the Y-axis label to the driver id,
      moves the horizontal quadrant-guide line to that driver's median, and redraws every
      point's `cy`. Checking a second facet un-checks the first (single active driver at a
      time — a 2-axis scatter cannot show more than one substituted axis, so "the active-axis
      set" from the parent task's Context is implemented as a size-≤1 set). Unchecking the
      active facet reverts Y to `bvp_norm`. X axis (cost composite) is unchanged by any
      facet state — swapping it away from cost would break the value-vs-cost quadrant
      framing the whole page exists to show; out of scope, noted in `## Decisions`.
- [x] **AC3 Points missing the active driver:** a task/arc whose `scores` map has no entry
      for the active driver is excluded from the redraw (not plotted at `y=0`, which would
      misrepresent "unscored" as "scored 0") and the scatter caption reports how many
      points are hidden for that reason.
- [x] **AC4 Playwright pin (L-423 — executed-browser AC, not markup presence):**
      `tests/playwright/test_bvp_per_driver_display.py` asserts, against a real browser:
      (a) the facet row and one checkbox per driver in Slice-1's column-header set are
      present, (b) clicking a facet checkbox changes the rendered Y-axis label text and
      moves at least one plotted point's `cy`, (c) clicking a second facet un-checks the
      first (single-active enforced in the DOM, not just the model), (d) zero browser
      console errors after both clicks. Test registered in `fw test playwright` discovery.
- [x] **AC5 No regression:** existing `/bvp` smoke
      (`grep -q "bvp_norm" `) and the Slice-1 per-driver table (`#bvp-driver-scores-section`,
      `data-driver-id` headers) are unchanged when no facet is checked.
- [x] **AC6 Reviewer static-scan PASS** (`bin/fw reviewer T-2346 --no-write`).

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking. -->
- [ ] [REVIEW] Facet interaction reads clean and matches operator intent
  **Steps:**
  1. Open `$(bin/fw watchtower url)/bvp` in a browser (needs scored tasks — if the page
     shows the empty-state, use a project/host with `bvp_scores_proposed:` populated).
  2. Tick the `F-RECALL` (or any driver) facet checkbox above the scatter. Confirm the
     Y axis re-labels and points visibly move.
  3. Tick a second facet. Confirm the first un-checks itself (only one active at a time).
  4. Un-check the active facet. Confirm the scatter reverts to the original `BVP_norm` view.
  5. Check the browser console for errors during all three interactions.
  **Expected:** Axis swap feels responsive and legible; single-active-facet behaviour
  matches what an operator would expect from a set of plain checkboxes (if it reads
  confusingly — e.g. operator expected multi-select — note that for a follow-up); no
  console errors.
  **If not:** Note which step felt wrong (visually or behaviourally) and whether the
  single-active-facet design (AC2) should instead be a real radio group.

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
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

python3 -c "import re,sys; s=open('web/templates/bvp.html').read(); i=s.index('<script'); j=s.index('</script>', i); body=s[s.index('>', i)+1:j]; open('/tmp/.bvp_scatter_check.js','w').write(body)" && node --check /tmp/.bvp_scatter_check.js
python3 -c "from jinja2 import Environment, FileSystemLoader; Environment(loader=FileSystemLoader('web/templates')).get_template('bvp.html')"
bin/fw watchtower current
out=$(curl -sf "$(bin/fw watchtower url)/bvp"); echo "$out" | grep -q 'id="bvp-axis-facets"'
out=$(curl -sf "$(bin/fw watchtower url)/bvp"); echo "$out" | grep -q "bvp_norm"
out=$(curl -sf "$(bin/fw watchtower url)/bvp"); echo "$out" | grep -q 'id="bvp-driver-scores-section"'
python3 -m pytest tests/playwright/test_bvp_per_driver_display.py -q

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

### 2026-09-20 — live-browser verification closed the gap the prior session left open
- **What changed:** The prior session implemented AC1/2/3/5 but only verified JS/Jinja
  syntax, never the running page. This session curled the live `/bvp` page (real corpus:
  3339 tasks, 16 arcs, all scored) and drove the facet checkboxes with the Playwright MCP
  tools directly — confirmed the Y-axis label changes, the axis domain swaps `[0,1]`→`[0,5]`
  (ticks `0.0`-`5.0` appeared), the guide line remedians, single-active-facet enforcement
  holds in the real DOM (clicking a second checkbox un-checks the first), and the state
  reverts cleanly with zero new console errors (only the pre-existing, unrelated
  favicon-404 was present).
- **Plan impact:** AC3's hidden-point-exclusion *code path* was reviewed and is present
  (`driverMedian`/filter logic in the axis-swap block), but the live corpus has every point
  scored on every driver, so the "N hidden" branch was never actually exercised end-to-end —
  only the "all points scored" branch was. Noted rather than hidden: AC3 is graded on the
  code being correct and present, not on having observed the hidden-count text render with
  a nonzero count.
- **Triggered:** Wrote `tests/playwright/test_bvp_per_driver_display.py` (5 tests, all
  green against a fresh server instance) per AC4/L-423 — executed-browser coverage, not
  markup-presence, matching the T-1999 origin pattern this rule is named after.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-09-20 — X axis stays fixed to the cost composite
- **Chose:** Facet toggles only ever swap the Y axis; X (cost composite) is unaffected by
  any facet state.
- **Why:** The whole page exists to show a value-vs-cost quadrant. Swapping X away from
  cost would break that framing for every facet state, and the parent task's Context never
  actually asked for a 2-axis swap — "the active-axis set" reads naturally as "which value
  dimension is currently plotted", which is inherently the Y axis in this chart's design.
- **Rejected:** A second facet-set for the X axis — would need its own single-active
  enforcement, its own guide line, and produces axis combinations (e.g. D1 vs D2) that no
  longer have a "cost" side, undermining the quadrant labels (HV-LC/HV-HC/LV-LC/LV-HC)
  which are defined relative to cost specifically.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO

**Rationale:** All 6 Agent ACs are verified against real, running behaviour — not code
presence. The facet axis-swap was driven live via Playwright against the production
Watchtower instance (real corpus, 3339 tasks/16 arcs, all scored): label change, domain
swap `[0,1]`→`[0,5]`, guide-line remedian, single-active-facet enforcement in the real DOM,
clean revert, and zero new console errors all confirmed directly. A regression suite
(`tests/playwright/test_bvp_per_driver_display.py`, 5 tests) pins this behaviour going
forward per L-423/AC4. AC5 no-regression and AC6 reviewer PASS both confirmed. The one
remaining item is the Human `[REVIEW]` AC — genuine UX taste (does the single-checkbox
"replaces the active one" interaction read clearly to an operator, or would a radio group
communicate the same constraint more directly) — which only a human can call.

**Evidence:**
- `web/templates/bvp.html` — facet row (`#bvp-axis-facets`), `applyAxisState()`,
  `bvpRedrawScatter` updated to preserve active-driver state across T-1929 slider redraws.
- Live Playwright session against `http://192.168.10.107:3002/bvp`: D1 click → label
  `D1 (0-5)`, ticks `0.0`-`5.0`; F1 click → D1 auto-unchecked, label `F1 (0-5)`; F1
  uncheck → reverts to `BVP_norm`. Console: only pre-existing favicon-404 throughout.
- `tests/playwright/test_bvp_per_driver_display.py` — 5/5 passed (105s) against a fresh
  pytest-managed server instance (not just the already-running one).
- `bin/fw reviewer T-2346 --no-write` → PASS, needs_human=no, 0 findings.

## Updates

### 2026-06-12T06:58:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2346-t-2170-slice-2--facet-axis-swap--playwri.md
- **Context:** Initial task creation

### 2026-09-20 — Session interrupted at budget critical (~95%, 286K tokens)
- **Action:** Wrote real ACs (AC1-AC6 + Human REVIEW), implemented AC1/AC2/AC3/AC5 in
  `web/templates/bvp.html`: facet checkbox row (`#bvp-axis-facets`, data-driven over
  `weights.items()`), `drawPoints(taskData, arcData, yValue)` parametrized Y-accessor,
  `applyAxisState()` (single-active-facet, domain swap `[0,1]`↔`[0,5]`, axis relabel,
  guide-line remedian, hidden-point exclusion+count), checkbox wiring, and
  `bvpRedrawScatter` updated to preserve active-driver state across T-1929 slider redraws.
- **Verified so far:** `node --check` on the extracted scatter `<script>` block — clean.
  Jinja `env.get_template('bvp.html')` — parses clean. Watchtower restarted onto the new
  template (PID 3363215).
- **NOT yet verified:** the live page was never actually curled/inspected after restart —
  the session hit budget-critical on the very next command (a `WURL=$(...)` chain the
  gate correctly refused as a multi-segment Bash call at 95%). So: unknown whether the
  facet row renders correctly against real data, unknown whether the D3 redraw is
  visually correct, AC4 (Playwright pin) is **not written at all**, `## Verification`
  block is still the template's default (no lines added), and AC6 (reviewer PASS) has
  not been run.
- **Status:** left at `started-work`, NOT partial-complete — Agent ACs are implemented
  but unverified, which is not the same as done. Do not read this as "just needs the
  Human AC" on next pickup; AC4 (Playwright) still needs to be authored, and AC1/2/3/5
  need a live-page check before any of them can be ticked in good faith (T-1831 C-4:
  tick on verified completion, not on "wrote the code").
- **Next session:** `curl -sf "$(bin/fw watchtower url)/bvp" -o /tmp/.bvp.html` and
  inspect for `#bvp-axis-facets` + `data-driver-id` checkboxes; ideally a Playwright
  session driving the actual click-and-observe interaction (L-423 — markup presence is
  not enough for a JS-behaviour AC). Write `tests/playwright/test_bvp_per_driver_display.py`
  per AC4. Then tick ACs, fill `## Verification`, and run the close flow.

### 2026-09-20T17:19:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-09-20 — Resumed post-compaction: live verification + Playwright pin
- **Action:** Focused T-2346, confirmed Watchtower currency (pid 3363215, current),
  curled the live `/bvp` page, then drove the facet checkboxes with Playwright MCP tools
  directly against the running server: clicked D1 → label became `D1 (0-5)`, Y-axis ticks
  changed to `0.0`-`5.0`, hint updated; clicked F1 → D1 auto-unchecked (single-active
  confirmed in the real DOM), label followed F1; unchecked F1 → reverted cleanly to
  `BVP_norm`. Zero new console errors across all interactions (only the pre-existing
  favicon-404).
- **Action:** Wrote `tests/playwright/test_bvp_per_driver_display.py` (5 tests) per AC4 —
  facet-row/driver-parity, default state, click→label-change + single-active enforcement +
  zero-console-errors, point-cy-movement, hidden-count-reported. Ran against a fresh
  pytest-managed server instance: 5/5 passed (105s).
- **Result:** Ticked AC1-AC5 (verified against live behaviour, not just code presence, per
  T-1831 C-4). AC6 (reviewer) and full `## Verification` block run next in this session.
