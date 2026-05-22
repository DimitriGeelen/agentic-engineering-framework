---
id: T-1978
name: "constituent task BVP columns on arc detail"
description: >
  Extend the Constituent tasks table on /arcs/<slug> with BVP_norm / BVP_raw / cost_estimate
  columns. Currently table shows ID/Arc/Name/Type/Status/Horizon — arc-level BVP rollup
  is visible at top of section but per-task contributions are invisible, so 'which
  tasks pull the average up/down' is unanswerable from the page. Tag arc:value-prioritisation.
  Related: T-1956, T-1939, T-1976 (surfaced the gap).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:value-prioritisation, bvp, watchtower, web-ui]
components: [tests/playwright/test_arc_detail_bvp.py, tests/playwright/test_task_detail_bvp.py, web/blueprints/arcs.py, web/blueprints/tasks.py, web/templates/arc_detail.html, web/templates/task_detail.html]
related_tasks: [T-1956, T-1939, T-1976]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-21T12:47:55Z
last_update: 2026-05-22T07:11:23Z
date_finished: 2026-05-22T07:11:23Z
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
  - ts: '2026-05-21T12:50:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-21T13:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1978: constituent task BVP columns on arc detail

## Context

Human round-trip on T-1976 surfaced this gap: on `/arcs/<id>` the arc-level BVP rollup (norm + raw stat boxes, per-driver breakdown) is visible, but the Constituent tasks table below shows only ID/Arc/Name/Type/Status/Horizon — no BVP score column. So "which constituent tasks pull the average up/down" is unanswerable from the page. Reuses `_compute_bvp` / `_compute_cost` from `web/blueprints/bvp.py` to keep one math source — numbers in the constituents table must match the `/bvp` scatter exactly.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/arcs.py` adds `_enrich_constituents_with_bvp(constituents)` helper that, for each constituent, resolves task frontmatter (active/ then completed/), calls `_compute_bvp` + `_compute_cost` from `web.blueprints.bvp` with policy-loaded weights, and attaches `bvp_norm` / `bvp_raw` / `cost` / `cost_source` / `bvp_mode` fields per row. Tasks without score data render `None` (template shows `—`).
- [x] `arc_detail` route calls the enricher before rendering, passing the enriched list into the template via the same `constituents=` kwarg.
- [x] `web/templates/arc_detail.html` Constituent tasks table renders three new columns after Horizon: `BVP_norm`, `BVP_raw`, `Cost`. Missing values render as muted `—`. Proposed-mode rows render `BVP_norm` in italic with `*` suffix (provenance signal).
- [x] Playwright pin (`tests/playwright/test_arc_detail_bvp.py`) on `/arcs/value-prioritisation` asserts the three new column headers exist (`BVP_norm`, `BVP_raw`, `Cost`) and that at least one row has a numeric `bvp_norm` value (proves enrichment fires; arc has scored constituents). 18/18 green incl 2 new T-1978 tests.
- [x] Math consistency: both `/arcs/value-prioritisation` constituents and `/bvp` scatter call the same `_compute_bvp` / `_compute_cost` helpers from `web.blueprints.bvp` — single math source by construction. Verified by code-level reuse (helper import) rather than per-row numeric diff to avoid coupling test to current arc data.
- [x] No new Python unit tests for `_compute_bvp` (already pinned by `test_bvp_blueprint_cost.py`).

### Human
- [ ] [REVIEW] BVP columns read cleanly in the Constituent tasks table — the three new columns are scannable (you can quickly tell which tasks are pulling the rollup up vs down), italic+`*` provenance signal for proposed-mode is unambiguous, and the legend below the H2 explains what the numbers mean without needing to click through.
  **Steps:**
  1. Open http://192.168.10.107:3000/arcs/value-prioritisation
  2. Scroll to "Constituent tasks" section
  3. Scan the BVP_norm column — confirm you can identify highest/lowest contributors at a glance
  4. Open http://192.168.10.107:3000/bvp in a second tab and confirm the numbers for the same task ID match
  **Expected:** Three new columns (BVP_norm, BVP_raw, Cost) render with values for scored tasks and `—` for unscored. Italic `*` rows indicate estimator-proposed (not yet confirmed). Numbers match `/bvp` scatter exactly.
  **If not:** Note the task ID and the mismatch, screenshot the two surfaces.

## Verification

# Python syntax of touched module
python3 -c "import ast; ast.parse(open('web/blueprints/arcs.py').read())"
# Live render: arc detail returns 200 + three new column headers + at least one numeric BVP_norm
curl -sf "$(bin/fw watchtower url)/arcs/value-prioritisation" > /tmp/.t1978.html
grep -q "<th[^>]*>BVP_norm</th>" /tmp/.t1978.html
grep -q "<th[^>]*>BVP_raw</th>" /tmp/.t1978.html
grep -q "<th[^>]*>Cost</th>" /tmp/.t1978.html
grep -qE "[0-9]\.[0-9]{3}" /tmp/.t1978.html
# Playwright pins (incl 2 new T-1978 tests)
bin/fw test playwright tests/playwright/test_arc_detail_bvp.py

## RCA

<!-- Non-bug-class — additive feature build. RCA not required. -->

## Evolution

### 2026-05-21 — T-1978 opening (round-trip surfaced gap)
- **What changed:** Human T-1976 round-trip confirmed the Add/Remove work end-to-end but flagged that the arc-level BVP rollup is opaque — you can see the average but not the per-task contributions. Without that visibility, the rollup is informationally lossy: "BVP_norm = 0.42" doesn't tell you whether 30 tasks are clustered at 0.4 or split 50/50 around 0.2 and 0.6.
- **Plan impact:** Implementation reuses `_compute_bvp` / `_compute_cost` helpers from `web.blueprints.bvp` rather than recomputing — keeps one math source, eliminates a class of "numbers diverge between /bvp and /arcs/<id>" bugs by construction. Italic+`*` on proposed-mode rows preserves the four-tier ladder provenance signal already established on /bvp.
- **Triggered:** None — clean reuse path; T-1977 (sliders) still queued.

## Recommendation

**Recommendation:** GO

**Rationale:** Closes the per-task BVP visibility gap surfaced by the T-1976 round-trip with minimal new surface — single new helper (`_enrich_constituents_with_bvp`) that delegates to existing `/bvp` math, plus three new columns on the existing constituents table. By-construction math consistency with `/bvp` (single helper source). Italic+`*` provenance signal for proposed-mode preserved.

**Evidence:**
- `web/blueprints/arcs.py:481-540` — new `_enrich_constituents_with_bvp` helper; route at `arc_detail` calls it before render.
- `web/templates/arc_detail.html:285-340` — three new columns (BVP_norm, BVP_raw, Cost) with provenance italic+`*` for proposed-mode rows; explanatory legend below H2.
- `tests/playwright/test_arc_detail_bvp.py` — 2 new T-1978 tests (header presence + numeric row count). 18/18 green.
- Live render verified: `/arcs/value-prioritisation` shows mixed confirmed + proposed-italic rows with numeric values (sample: `0.583*`, `0.150*`, `70*`).

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

### 2026-05-21T12:47:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1978-constituent-task-bvp-columns-on-arc-deta.md
- **Context:** Initial task creation

### 2026-05-21T12:50:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-88ac1ba6
- **Timestamp:** 2026-05-22T07:12:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `web/templates/arc_detail.html` Constituent tasks table renders three new columns after Horizon: `BVP_norm`, `BVP_raw`, `Cost`. Missing values render as muted `—`. Proposed-mode rows render `BVP_norm`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/arc_detail.html in: `web/templates/arc_detail.html` Constituent tasks table renders three new columns after Horizon: `BVP_norm`, `BVP_raw`, `Cost`. Missing values render `

### 2026-05-22T07:11:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
