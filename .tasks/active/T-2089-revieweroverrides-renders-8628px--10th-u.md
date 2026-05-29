---
id: T-2089
name: "reviewer/overrides renders 8628px — 10th unbounded-table class instance"
description: >
  10th instance of the unbounded-page class, caught by T-2048+T-2088 height guard
  at 8628px (77-row single table on /reviewer/overrides). Same shape as T-2038 (approvals)
  / T-2044 (learnings) / T-2045 (decisions) / T-2087 (arc detail): wrap table in max-height
  scroll container with sticky thead. Template: web/templates/reviewer_overrides.html.
  Fix is 1 template edit + Playwright re-verify.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [agents/ux-review/ux-review.py, tests/playwright/test_all_routes_height.py]
related_tasks: [T-2048, T-2087, T-2088, T-2038, T-2044, T-2045]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T10:06:24Z
last_update: 2026-05-29T10:17:27Z
date_finished: 2026-05-29T10:17:27Z
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
  - ts: '2026-05-29T10:13:51Z'
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
  - ts: '2026-05-29T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2089: reviewer/overrides renders 8628px — 10th unbounded-table class instance

## Context

`/reviewer/overrides` page rendered 8628px tall (77-row events table + N-row active-overrides
table, both unbounded). The T-2048+T-2088 height guard caught it on the first end-to-end run
of T-2088. Same shape as T-2038 (approvals) / T-2044 (learnings) / T-2045 (decisions) /
T-2087 (arc detail): two `<table>` blocks loop over a growing collection with no height
bound. Fix shape: wrap each in a `<div class="…-scroll" style="max-height:60vh; overflow-y:auto; …">`
with sticky `<thead>` — exactly the T-2087 pattern.

Both tables grow with use:
- **Active overrides** — N rows, one per active TTL'd false-positive suppression
- **Recent feedback-stream events** — 77 rows at filing, grows continuously (auto-tick events,
  manual override events). Primary driver of the 8628px height.

Template: `web/templates/reviewer_overrides.html` (lines 21-52 active, 66-87 events).

## Acceptance Criteria

### Agent
- [x] **A1** Both tables on `/reviewer/overrides` wrapped in a `max-height:60vh; overflow-y:auto`
  scroll container with `position:sticky; top:0` `<thead>` and `border-radius:0.3rem`
  border. Verified: `document.querySelectorAll('.overrides-scroll, .events-scroll').length === 2`.
- [x] **A2** Live page height: BEFORE 8628px, AFTER **1811px** (78% reduction, well under
  8000px cap). Measured via Playwright after Watchtower restart picked up the template change.
- [x] **A3** Parametrized-route test (T-2088) + parameterless guard (T-2048)
  `test_route_height_bounded[/reviewer/overrides]` will pass — height 1811px < 8000px cap.
  Closes the 10th instance of the unbounded-table class.
- [x] **A4** Header row count hint added to both sections (`Active Overrides (N)` +
  `Recent feedback-stream events (N)`). Verified via DOM regex match on rendered HTML.

### Human
- [ ] [REVIEW] `/reviewer/overrides` layout reads cleanly with the new scroll containers.
  **Steps:**
  1. Open http://192.168.10.107:3000/reviewer/overrides
  2. Confirm two scroll containers (Active Overrides + Recent feedback-stream events) —
     each has a sticky header that stays visible while you scroll inside the box.
  3. Page no longer scrolls the body endlessly — the two boxes contain the rows.
  4. Section headers show the row count `(N)` so you know how much is inside without scrolling.
  **Expected:** Two compact, scrollable boxes; sticky headers; row counts visible; total page
  height roughly one viewport (was 8628px before, now ~1800px).
  **If not:** Note whether sticky headers hide behind anything or the scroll box looks broken;
  agent reworks border/background tokens.

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
# T-2089 verification: the targeted height-guard test must pass on the live page.
# L-387-safe pattern: capture pytest output, then grep the capture (not pipe-grep).
out=$(timeout 90 python3 -m pytest "tests/playwright/test_all_routes_height.py::test_route_height_bounded[/reviewer/overrides]" -q 2>&1); echo "$out" | tail -3 | grep -qE "1 passed"

# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

**Symptom:** `/reviewer/overrides` rendered 8628px tall (77-row events table + N-row
overrides table). Caught by the parameterless guard `test_route_height_bounded[/reviewer/overrides]`
on T-2088's first end-to-end suite run.

**Root cause:** Two `<table>` blocks in `web/templates/reviewer_overrides.html` looped over
growing collections (`overrides`, `events`) with no height bound — the canonical
unbounded-page anti-pattern (T-2038/T-2044/T-2045/T-2087 class, 9 prior instances).

**Why structurally allowed:** The parameterless height guard (T-2048) covered this route
all along, but the suite wasn't being run on the master branch as part of routine
verification — only when explicitly invoked. T-2088's full-suite end-to-end run surfaced it.
The class-prevention surface (heights bounded by shape) exists but compliance was
opportunistic, not gated.

**Prevention:** Already structurally guarded — the same Playwright parametrize that caught
this instance prevents the next one. No new gate needed. The remaining systemic gap is
making the all-routes suite a routine CI/pre-push gate; that's tracked under existing
prevention infrastructure (T-2048's `fw test playwright` is the gate; running it before
push is the discipline). This task is a tactical fix, not a structural one — class
prevention was already in place.
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

**Recommendation:** GO — close at Agent-AC boundary; partial-complete pending [REVIEW].

**Rationale:** Template-level fix to the 10th instance of the unbounded-table class.
Same shape as T-2087 (max-height scroll container + sticky thead + row-count hint).
8628px → 1811px (78% reduction). Caught by the very Playwright guard the previous task
(T-2088) extended, which is the antifragility loop working as designed.

**Evidence:**
- `web/templates/reviewer_overrides.html`: two `<div class="…-scroll" style="max-height:60vh; overflow-y:auto">` wrappers + sticky `<thead>` + row-count `<small>(N)</small>` hints
- Live measurement: BEFORE 8628px, AFTER 1811px (Playwright eval `document.documentElement.scrollHeight`)
- `test_route_height_bounded[/reviewer/overrides]`: PASS (1.77s) — was FAIL before this commit
- 2 scroll containers confirmed via `document.querySelectorAll('.overrides-scroll, .events-scroll').length === 2`

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

### 2026-05-29T10:06:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2089-revieweroverrides-renders-8628px--10th-u.md
- **Context:** Initial task creation

### 2026-05-29T10:13:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-70b2650b
- **Timestamp:** 2026-05-29T10:17:47Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 21
     - evidence: `out=$(timeout 90 python3 -m pytest "tests/playwright/test_all_routes_height.py::test_route_height_bounded[/reviewer/overrides]" -q 2>&1); echo "$out" | tail -3 | grep -qE "1 passed"`

### 2026-05-29T10:17:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
