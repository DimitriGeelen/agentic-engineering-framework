---
id: T-2046
name: "/graduation renders 70000px tall — unbounded pipeline lists (T-2038 class)"
description: >
  /graduation renders 70,201px (tallest; pipeline-stage layout with multiple loops
  over learnings/patterns/practices/decisions). 9th instance of the unbounded-page
  class (T-2042 probe). Shape needs investigation — likely per-stage collapse or scroll
  containers.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc-007, perf, watchtower, graduation, ui, render-surface]
components: [tests/playwright/test_graduation_height.py, 
      web/templates/graduation.html]
related_tasks: [T-2042, T-2044, T-2045]
arc_id: watchtower-redesign
created: 2026-05-25T14:53:07Z
last_update: '2026-06-11T22:23:30Z'
date_finished: 2026-05-26T06:56:30Z
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
  - ts: '2026-05-25T15:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-25T15:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F1: 1
      F2: 0
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 (body:component-discoverability);
      D4=2 (body:env-class-handled); F1=1 (body/tag hits for 'F1': 1); F2=0 (no-signal)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2046: /graduation renders 70000px tall — unbounded pipeline lists (T-2038 class)

## Context

Final instance of the unbounded-page class ([[project_unbounded_watchtower_pages]], T-2042 exhaustive probe). `/graduation` renders ~70,201px — the tallest of the 9. Despite the task title ("unbounded pipeline lists"), inspection shows the page has ONE height driver: the pipeline `<table>` (`{% for l in pipeline %}`) over the full learnings list. The other elements (pipeline-flow viz, summary stats, filter row) are fixed-size, and the "How to promote" `<details>` is already collapsed. Same shape as /learnings (T-2044) & /decisions (T-2045): wrap the pipeline table in a `max-height` scroll container with sticky `thead`.

## Acceptance Criteria

### Agent
- [x] `/graduation` rendered `scrollHeight` < 8000px (TALL_PAGE_CAP_PX) measured via Playwright after restart — **70,201px → 1,272px**
- [x] All pipeline rows remain in the DOM (count unchanged) inside a bounded `.graduation-table-scroll` container that scrolls (clientHeight < scrollHeight when rows > 30) — **462 rows retained, container scrolls**
- [x] Sticky `thead` so column headers stay visible while scrolling the container — `position: sticky; top: 0; z-index: 2`
- [x] The `?status=` filter still works (filtered subset renders inside the same bounded container) — **?status=ready → 62 rows, 1,272px bounded**
- [x] `tests/playwright/test_graduation_height.py` added and passing (height bound + rows-in-scroll-container guards) — **3 passed (incl. filtered-view guard)**

### Human
- [ ] [REVIEW] /graduation reads clean and the pipeline is comfortable to scan
  **Steps:**
  1. Open http://192.168.10.107:3000/graduation in a browser
  2. Confirm the pipeline-flow visualization and summary stats sit above a bounded, scrollable pipeline table with a pinned header
  3. Click a filter (e.g. "Ready") — confirm the filtered list renders inside the same bounded container, page stays short
  **Expected:** Pipeline viz + stats visible at top; table scrolls within its container with sticky headers; page is screen-sized, not 70k px
  **If not:** Screenshot the issue and note whether the container is mis-sized or the filter broke the layout

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
python3 -c "s=open('web/templates/graduation.html').read(); assert 'graduation-table-scroll' in s, 'scroll container class missing'; assert 'position: sticky' in s or 'position:sticky' in s, 'sticky thead missing'; print('graduation.html scroll-container + sticky present')"
cd tests/playwright && python3 -m pytest test_graduation_height.py -q 2>&1 | tail -3; cd "$OLDPWD"

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

**Symptom:** `/graduation` rendered 70,201px tall (462 rows) — the tallest page of the class; endless page-level scroll and a wedged ux-review `full_page` screenshot.

**Root cause:** The pipeline `<table>` looped `{% for l in pipeline %}` over the full learnings list with no height bound. Final (9th) confirmed instance of the unbounded-page class ([[project_unbounded_watchtower_pages]]).

**Why structurally allowed:** The ux-review height detector swept only 5 hard-coded pages, so /graduation grew undetected. **This root is already closed** by T-2042 (exhaustive `discover_get_routes()` over `app.url_map`), which is what surfaced this instance.

**Prevention:** `tests/playwright/test_graduation_height.py` (height-bound + filtered-view + rows-in-scroll-container guards) catches a regression of this page; the T-2042 exhaustive sweep catches the next new page automatically.

## Evolution

### 2026-05-25 — title over-stated the shape
- **What changed:** Task title said "unbounded pipeline lists" (plural), implying multiple loops. Inspection found a single height driver: the pipeline table. The pipeline-flow viz, summary stats, and filter row are fixed-size; the "How to promote" section is already a collapsed `<details>`.
- **Plan impact:** No multi-section work needed — single table-scroll-container (identical to T-2044/T-2045). This was the 3rd of 3 remaining pages where the filed shape was more complex than reality; all three reduced to the proven scroll-container or collapse pattern.
- **Triggered:** Added a filtered-view (`?status=ready`) test case since this page (unlike its siblings) has a query-param filter that must also stay bounded.

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

### 2026-05-25 — table scroll-container (max-height accounts for the tall header block)
- **Chose:** Wrap the pipeline table in `.graduation-table-scroll` (`max-height: calc(100vh - 380px)`, sticky `thead`). The 380px subtrahend (vs 220-280px on sibling pages) accounts for /graduation's taller header block (pipeline-flow viz + 6-stat summary + filter row).
- **Why:** Same proven pattern as /learnings (T-2044) & /decisions (T-2045); `<details>` can't wrap `<tr>`. The larger max-height offset keeps the container from spilling below the fold given this page's bigger header.
- **Rejected:** A fixed pixel max-height — wouldn't adapt to viewport. Collapsing the table behind a `<details>` — the pipeline IS the page's primary content, should be visible by default, not hidden.

## Recommendation

**Recommendation:** GO

**Rationale:** Tallest page of the class (70k px) brought to screen-size by the same proven scroll-container pattern, with the filter path verified to stay bounded too. Regression test (incl. filtered view) guards it. Only the `[REVIEW]` human-taste check remains; agent-side everything passes. **This is the final instance — the unbounded-page class is fully closed (9/9 fixed; detector exhaustive via T-2042).**

**Evidence:**
- Height: 70,201px → **1,272px** (Playwright, post-restart) — well under the 8000px cap
- Filtered: `?status=ready` → 62 rows, **1,272px** (bounded)
- Rows: **462 retained** inside `.graduation-table-scroll`; container scrolls (clientHeight < scrollHeight)
- Sticky `thead` (`position: sticky; top: 0; z-index: 2`)
- `tests/playwright/test_graduation_height.py` — **3 passed**
- Eyes-on screenshot: http://192.168.10.107:3000/static/ux-review/T-2046-graduation-bounded.png

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-25T14:53:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2046-graduation-renders-70000px-tall--unbound.md
- **Context:** Initial task creation

### 2026-05-25T15:36:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-30312df1
- **Timestamp:** 2026-05-26T06:56:57Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#5 (Agent)** — `tests/playwright/test_graduation_height.py` added and passing (height bound + rows-in-scroll-container guards) — **3 passed (incl. filtered-view guard)**
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/playwright/test_graduation_height.py in: `tests/playwright/test_graduation_height.py` added and passing (height bound + rows-in-scroll-container guards) — **3 passed (incl. filtered-view guar`

### 2026-05-26T06:56:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
