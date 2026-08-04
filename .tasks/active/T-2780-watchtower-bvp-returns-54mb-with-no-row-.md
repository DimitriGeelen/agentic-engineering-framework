---
id: T-2780
name: "Watchtower /bvp returns 5.4MB with no row bound"
description: >
  The /bvp route returns 5,385,019 bytes in a single response.

  Same unbounded-row class as /timeline (T-2775): every scored task renders as a row
  with no windowing. Detected by the T-2775 response-size guard, which caps routes
  at 2,000,000 bytes.

  This size has already caused one false green: it overflows the 64KB pipe buffer,
  so a verification line of the shape "cmd | grep -q PAT" exited 141 (SIGPIPE) and
  read as a failing check rather than a passing one (T-2743, L-387).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [tests/playwright/test_all_routes_size.py, web/blueprints/timeline.py, web/templates/timeline.html, web/templates/timeline_session.html]
related_tasks: []
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
created: 2026-08-03T22:21:59Z
last_update: 2026-08-04T00:03:58Z
date_finished: 2026-08-04T00:03:58Z
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
  - ts: '2026-08-03T22:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-03T22:30:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2780: Watchtower /bvp returns 5.4MB with no row bound

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `/bvp` response size measured off the wire before and after, and lands under the
      2,000,000-byte cap in `tests/playwright/test_all_routes_size.py`. — Before: 5,391,073
      bytes. After: 651,024 bytes (page 1), worst page across all 11 pages: 651,024 bytes.
- [x] The `/bvp` entry is removed from `KNOWN_OVER_CAP` in that guard. The guard fails a
      route that is under cap but still listed, so a stale exemption cannot outlive the fix.
- [x] The bound is a window the reader can see and step past, not a truncation — same
      standard as T-2775 (`/timeline`): state the window, keep the remainder reachable.
      — Server-side paging (`?page=N`, 250 tasks/page, 11 pages for 2,579 tasks), pager
      nav ("Highest value"/"Higher"/"Lower"/"Lowest value") on the scatter, raw-data table,
      and per-driver-scores table; every task remains reachable on some page.
- [x] Ranking is preserved across the window: `/bvp` exists to order tasks by value, so the
      window must be over a *sorted* set. Bounding it by "first N found" would silently
      change what the page means while making it look fixed. — `bvp_scatter()` now sorts
      `_collect_task_points()`/`_collect_arc_points()` output by `bvp_norm` descending
      *before* slicing; page 1 is always the highest-value tasks. Verified page 1's last
      value (0.40) matches page 2's first value (0.40) — continuous ranking across the
      page boundary, not a re-sort per page.
- [x] Re-check the T-2743 verification line that this page's size broke. At 5.4 MB it
      overflowed the 64KB pipe buffer, so `cmd | grep -q PAT` exited 141 (SIGPIPE) and a
      passing check read as failing. Confirm which shape that line now uses (L-387). —
      T-2771 already moved T-1928's `/bvp` verification line to the redirect-to-file shape
      (`curl -sf ".../bvp" -o /tmp/.t1928-bvp.html && grep -qi "..." /tmp/.t1928-bvp.html`,
      T-1928 task file `## Verification`). That shape is SIGPIPE-safe regardless of byte
      count (no pipe to grep at all), so it needed no further change — confirmed by reading
      the current line, not by inference.

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

- [ ] [REVIEW] New pager UI on `/bvp` (scatter, raw-data table, per-driver-scores table)
      reads clearly and doesn't look bolted-on
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` and open `<url>/bvp`
  2. Confirm the page shows "showing 1–250 of N task(s) by value, page 1 of M" under the
     scatter, and a "« Highest value / ‹ Higher ... Lower › / Lowest value »" nav row appears
     above the scatter and below each of the two `<details>` tables
  3. Click "Lower ›" once; confirm the URL becomes `/bvp?page=2` and the scatter/tables/JSON
     redraw with a different (lower-value) set of tasks
  4. Expand the "Raw data" and "Per-driver scores" `<details>` — confirm both summaries state
     the page window (e.g. "page 1 of 11") rather than implying the table is the full set
  **Expected:** pager controls are visually distinct from the rest of the page furniture,
  labels are legible at a glance, paging actually changes what's rendered (not just the URL)
  **If not:** note which element reads unclear (labels, spacing, missing state) and reopen
  for a follow-up

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
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

! grep -q '"/bvp"' tests/playwright/test_all_routes_size.py
curl -sf "$(bin/fw watchtower url)/bvp" -o /tmp/.t2780-bvp.html && wc -c < /tmp/.t2780-bvp.html | awk '{exit ($1<2000000)?0:1}'
out=$(FW_TEST_PORT=3001 bin/fw test playwright -- tests/playwright/test_all_routes_size.py -k "bvp or timeline" 2>&1); echo "$out" | grep -qE "[0-9]+ passed" && ! echo "$out" | grep -qE "[0-9]+ failed"

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

### 2026-08-04 — Windowing strategy: sort-then-page over all three rendered surfaces
- **Chose:** Sort `_collect_task_points()` output by `bvp_norm` descending once in the
  route, then slice a single 250-task page and reuse that same page for the scatter's
  JSON payload, the raw-data table, and the per-driver-scores table. One page number
  drives all three views; server-side `?page=N` paging, same UX pattern as `/timeline`
  (T-2775).
- **Why:** The task's own AC required the window to sit over a *sorted* set so page 1
  means "highest value", not "first found on disk" — `/bvp`'s entire purpose is ranking.
  Reusing one page index across all three renderings (rather than windowing them
  independently) keeps "page 2" meaning the same 250 tasks everywhere on the page,
  which matters because the per-driver-scores table and raw-data table are two
  different views of the *same* task set, not independent lists.
- **Rejected:** (a) Cap only the two `<details>` tables and leave the scatter's JSON
  payload unbounded — rejected because the JSON payload alone (1.23 MB at 2,579 tasks)
  will cross the 2 MB cap on its own as the task corpus grows, just later; this would
  have re-created T-2775's "bounded on one axis, not the other" mistake with a longer
  fuse instead of fixing the class. (b) Cap total points rendered by "first N found"
  (glob order) — rejected explicitly by the AC itself: this is exactly the truncation
  that "silently changes what the page means" the AC warns against.

## Recommendation

**Recommendation:** GO

**Rationale:** `/bvp` is fixed on the same axis T-2775 fixed `/timeline` on — server-side
paging over a value-sorted list, with a pager that keeps every task reachable. All 5 Agent
ACs are met with measured evidence, all 3 Verification commands pass, and the pre-existing
`/bvp` Playwright suite (41 tests) has zero regressions. The one remaining Human AC is a
`[REVIEW]` of the new pager UI's look/feel (labels, spacing, "bolted-on" gut-check) —
genuine visual taste, not a correctness question I can self-certify.

**Evidence:**
- Size: 5,391,073 bytes → 651,024 bytes (page 1); all 11 pages measured, max 651,024 bytes,
  well under the 2,000,000-byte cap (~3.1x headroom).
- `tests/playwright/test_all_routes_size.py -k "bvp or timeline"` → 7 passed (was 1 xfail
  for `/bvp`, now a real pass; `/bvp` removed from `KNOWN_OVER_CAP`).
- `tests/playwright/test_bvp_scatter.py`, `test_bvp_sliders.py`, `test_bvp_form_htmx.py`,
  `test_bvp_propose_queue.py`, `test_arc_detail_bvp.py` → 41 passed, 1 pre-existing failure
  (`test_add_form_submit_keeps_user_on_bvp`, unrelated to this change — reproduced on
  unmodified code via `git stash`; caused by the driver cap being at 9/9 in this repo's
  live policy state, which the test doesn't account for).
- Ranking preserved across the page boundary: page 1's last `bvp_norm` (0.40) equals page
  2's first `bvp_norm` (0.40) — continuous sort, not independently-sorted pages.
- Full sweep of `web/blueprints/bvp.py` / `web/templates/bvp.html` diff — no changes to
  driver-add/remove/commit forms, slider logic, or proposal-queue rendering; the change is
  scoped to windowing the three task-point renderings + adding the pager.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-03T22:21:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2780-watchtower-bvp-returns-54mb-with-no-row-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-01fbb081
- **Timestamp:** 2026-08-04T00:04:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-04T00:03:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
