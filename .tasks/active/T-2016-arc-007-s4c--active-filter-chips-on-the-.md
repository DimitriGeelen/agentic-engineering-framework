---
id: T-2016
name: "arc-007 S4c — active-filter chips on the tasks board (per-chip clear, shareable
  URL)"
description: >
  arc-007 S4c — active-filter chips on the tasks board (per-chip clear, shareable
  URL)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, redesign, ui, tasks, arc:watchtower-redesign]
arc_id: watchtower-redesign
components: [tests/playwright/test_filter_chips.py, tests/unit/test_filter_chips.py, web/blueprints/tasks.py, web/templates/tasks.html]
related_tasks: [T-1992, T-1987, T-2015]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-24T08:11:51Z
last_update: 2026-05-26T06:48:45Z
date_finished: 2026-05-26T06:48:45Z
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
  - ts: '2026-05-24T08:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-24T08:15:03Z'
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

# T-2016: arc-007 S4c — active-filter chips on the tasks board (per-chip clear, shareable URL)

## Context

arc-007 S4c — second slice of the Tasks-board redesign (parent T-1992, after the S4a
keystone T-2015). The board already filters by owner/horizon/tag/status/type/search via
query params (`web/blueprints/tasks.py::tasks`) and already renders **one** removable chip
— for the `arc:` filter only (`tasks.html` ~L456). S4c generalises that: **every** active
filter becomes a removable chip, each with an × that clears just that one while preserving
the rest, so the active filter state is visible at a glance and a filtered view stays
shareable by URL (the query params already make it shareable).

**Approach (decided at build start):** compute the chip list in the route — a list of
`{key, label, clear_url}` where `clear_url` is the current querystring minus that one
filter — so it's unit-testable and the per-chip clear-URL logic lives in Python, not in
awkward Jinja string-building. The template renders the list, replacing the bespoke arc
chip + reusing its pill styling. No change to the filtering logic itself (reversible,
internal). Mirrors the existing `arc:` chip's hx-get/#content/push-url pattern.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The route exposes an `active_filter_chips` list — one entry per non-empty filter (owner/horizon/tag/status/type/q), each with a `label` and a `clear_url` that drops only that filter while preserving the others and the current `view` (unit: test_filter_chips.py::test_one_chip_per_active_filter + test_clear_url_keeps_current_view)
- [x] When two filters are active, each chip's `clear_url` keeps the other filter's query param (unit: test_each_clear_url_preserves_the_other_filters — per-chip isolation, not clear-all)
- [x] `/tasks` with filters renders a chip per active filter, each with a × clear control; with no filters active, no chip bar renders (unit: test_board_renders_chip_per_active_filter)
- [x] Clicking a chip's × removes that filter and reloads the board via htmx (no full-page nav), leaving the other active filters in place (Playwright: test_clear_one_chip_keeps_the_other)
- [x] A filtered board URL is shareable — visiting `/tasks?owner=agent&horizon=now` directly shows both chips active (Playwright: test_shareable_url_shows_chips)

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
- [ ] [REVIEW] The filter-chip bar reads cleanly — chips are visually distinct from the filter dropdowns, the × controls are obvious and easy to hit, and a board with 2-3 active filters reads as "here's exactly what you're looking at" rather than cluttered.
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve` (or open the live Watchtower), go to `/tasks`
  2. Pick an owner and a horizon from the dropdowns — confirm a chip appears for each
  3. Click one chip's × — confirm only that filter clears and the other chip stays
  4. Review the captured screenshot `web/static/ux-review/T-2016-filter-chips.png`
  **Expected:** The chip bar reads as a clear, uncluttered summary of the active filter state; chips are easy to distinguish and dismiss.
  **If not:** Note which chip styling or spacing feels off (screenshot it) so it can be tuned.

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
# Live :3000 is NOT restarted by agents — verify against the Flask test_client.
python3 -c "import ast; ast.parse(open('web/blueprints/tasks.py').read())"
python3 -m pytest tests/unit/test_filter_chips.py -q 2>&1 | tail -3

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

### 2026-05-24 — chip set built on what already existed
- **What changed:** S4c turned out smaller than scoped — the board already had working query-param filtering AND a bespoke removable chip for the `arc:` filter. S4c was really "generalise the one chip to all filters", not "build a filter system". The clear-all link also already existed.
- **Plan impact:** No backend filter change at all; the only new Python is the pure `_build_active_filter_chips` helper. The arc-specific chip markup was replaced by the generic loop (so arc still gets a chip, now via the same path).
- **Triggered:** Nothing new — confirms the S4b/S4d slices likewise extend existing endpoints (horizon inline-edit endpoint already exists) rather than starting fresh.

## Decisions

### 2026-05-24 — compute chips in the route, not in Jinja
- **Chose:** Build the chip list (label + per-chip clear-URL) in `_build_active_filter_chips` (Python), passed to the template as `active_filter_chips`.
- **Why:** Each chip's clear-URL must be the current querystring *minus one* filter — string surgery that's painful and error-prone in Jinja, and untestable without a browser. In Python it's a dict-comprehension + `urlencode`, and the per-chip isolation is pinned by a unit test.
- **Rejected:** Building clear-URLs inline in the template — would have duplicated the "preserve every other param" logic per filter and left the core correctness (isolation) unverifiable by unit test.

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

## Recommendation

**Recommendation:** GO

**Rationale:** S4c is complete — every active board filter now renders as a removable
chip with a per-chip × that clears just that filter (preserving the rest), and the
filtered view stays shareable by URL. It's a small, internal, reversible slice built on
the board's existing query-param filtering (no filter-logic change). All 5 Agent ACs pass;
the only open item is the `[REVIEW]` Human AC (chip-bar legibility/feel), sovereignty-reserved.

**Evidence:**
- `web/blueprints/tasks.py`: pure `_build_active_filter_chips(active, view)` helper + wired into the `/tasks` route as `active_filter_chips`.
- `web/templates/tasks.html`: bespoke arc-only chip replaced by a generic chip loop (arc still chipped via the same path) + "Clear all".
- Tests: `tests/unit/test_filter_chips.py` (6 pass — incl. per-chip clear-URL isolation) + `tests/playwright/test_filter_chips.py` (4 pass — incl. clear-one-keep-other, shareable URL).
- Eyes-on screenshot: `web/static/ux-review/T-2016-filter-chips.png` (two chips + Clear all, visually distinct from the dropdowns).

## Updates

### 2026-05-24T08:11:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2016-arc-007-s4c--active-filter-chips-on-the-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cd467e57
- **Timestamp:** 2026-05-26T06:48:55Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-26T06:48:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
