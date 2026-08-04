---
id: T-2781
name: "Watchtower /project returns 2.27MB, over the response-size cap"
description: >
  The /project route returns 2,274,276 bytes, over the 2,000,000-byte cap set by the
  T-2775 response-size guard.

  Same class as /timeline and /bvp: content that scales with corpus size renders in
  full with no windowing.

  Smaller margin than its siblings (1.14x the cap rather than 35x), so this is the
  early-warning case the guard was meant to catch before it becomes another 70MB page.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/blueprints/core.py, web/templates/project.html, web/templates/_project_docs_list.html, tests/playwright/test_all_routes_size.py]
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
created: 2026-08-03T22:23:16Z
last_update: 2026-08-04T09:39:12Z
date_finished: 2026-08-04T09:39:12Z
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

# T-2781: Watchtower /project returns 2.27MB, over the response-size cap

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `/project` response size measured off the wire before and after, and lands under the
      2,000,000-byte cap in `tests/playwright/test_all_routes_size.py`. (2,274,276 →
      113,380 bytes)
- [x] The `/project` entry is removed from `KNOWN_OVER_CAP` in that guard. The guard fails a
      route that is under cap but still listed, so a stale exemption cannot outlive the fix.
- [x] The bound is a window the reader can see and step past, not a truncation — same
      standard as T-2775 (`/timeline`): state the window, keep the remainder reachable.
      Each category renders its first 25 rows server-side; "Show all N items" fetches the
      remainder via `/project/expand/<cat>` (htmx, appended in place) instead of shipping
      it hidden in the initial payload.
- [x] Worst case measured, not just the landing view. T-2775's paging looked done at 609 KB
      on page 1 while page 10 was 12.6 MB; whatever varies here gets swept across its range.
      The expand fetch is itself a new unbounded-with-corpus-growth surface (parameterized,
      so the exhaustive route discovery can't see it) — measured explicitly for the two
      categories that actually overflow: Design (1,673 docs → 626,091 bytes) and Research
      (2,457 docs → 821,608 bytes), both under cap. Regression-pinned in
      `test_project_expand_bounded`.

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

- [ ] [REVIEW] The 25-row window reads as a window, not as a page that lost its content
  **Steps:**
  1. Open http://192.168.10.107:3001/project
  2. Look at Design and Research — the two categories that overflow. Each shows 25 rows
     followed by a "Show all N items" control.
  3. Click "Show all" on Research. The remaining 2,432 rows append in place; the page does
     not navigate away or reset your scroll position.
  **Expected:** Reading the landing page, it is obvious that each list is truncated and how
  many items are behind the control — you can tell at a glance that nothing was deleted.
  After clicking, the appended rows are visually continuous with the first 25 (same styling,
  no duplicated or skipped entry at the seam).
  **If not:** Note which category reads wrong and whether the problem is the wording of the
  control, the seam between preview and remainder, or the row count (25 may be too few to be
  useful or too many to scan). The limit is one constant,
  `PROJECT_DOCS_PREVIEW_LIMIT` in `web/blueprints/core.py:459`.

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

out=$(FW_TEST_PORT=$(bin/fw watchtower port) python3 -m pytest tests/playwright/test_all_routes_size.py -k "project" -q 2>&1); echo "$out" | grep -q " passed" && ! echo "$out" | grep -q " failed"
! grep -q '"/project"' tests/playwright/test_all_routes_size.py

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

**Symptom:** `/project` returned 2,274,276 bytes — over the 2,000,000-byte cap, found by the
T-2775 size guard on its first run.

**Root cause:** the route rendered every discovered document in every category. Research alone
holds 2,457 episodic entries, Design 1,684. Response size scaled linearly with corpus size with
no windowing anywhere in the path.

**Why structurally allowed:** the same per-axis blindness as its siblings, one step earlier.
`/project` was never over the height cap (the lists are compact) and never over the latency cap
(it renders fast), so both existing guards were green while the payload grew unbounded with the
corpus. Nothing measured bytes until T-2775, and the moment something did, this route appeared —
it had been in the class for as long as the corpus had been large, just never measured.

The margin is the notable part: 1.14× the cap, against 35× for `/bvp` and 3,494× for
`/timeline`. This is the early-warning case the guard was meant to produce — caught while the
page still worked, rather than after it became another 70MB one.

**Prevention:** two guards, and the second is the one that generalises.
`test_route_response_size_bounded[/project]` pins the landing view via exhaustive route
discovery. But the fix moves the remainder behind `/project/expand/<cat>`, which is
*parameterized* — `discover_get_routes()` cannot enumerate it, so the exhaustive guard is
structurally blind to it. Bounding a page by relocating its content to a parameterized route
creates an unguarded successor by default. `test_project_expand_bounded` measures that route
explicitly for the two categories that actually overflow. Same blind spot the T-2775 paging
tests exist for; worth stating as a rule, since the natural fix for an unbounded page keeps
producing routes the discovery pass cannot see.

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

## Recommendation

**Recommendation:** GO

**Rationale:** The defect is closed on the axis it was filed against and the fix keeps the
content reachable rather than hiding or dropping it. What is left is the one judgment I cannot
make from a byte count: whether 25 rows plus a "Show all" control reads as a deliberate window
to someone opening the page, or as a list that lost its tail.

**Evidence:**
- `/project` measured off the wire: 2,274,276 → **113,380 bytes** (20×), under the 2,000,000 cap.
- Remainder routes bounded too: `/project/expand/Design` 630,811 B, `/project/expand/Research`
  821,608 B — both measured explicitly because route discovery cannot see parameterized routes.
- Window boundary is exact, no gap and no duplication: Design 1,684 total / 1,659 in expand;
  Research 2,457 / 2,432 — both exactly `total − 25`, matching `PROJECT_DOCS_PREVIEW_LIMIT`.
- Full response-size suite **60/60 passed** with `KNOWN_OVER_CAP` empty — `/project` was the
  last member of the unbounded class the T-2775 guard found.
- `test_project_expand_bounded` mutation-checked: with the cap lowered to 100,000 it goes red on
  both categories, and passes again on revert. The guard is capable of failing (L-530).

## Updates

### 2026-08-03T22:23:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2781-watchtower-project-returns-227mb-over-th.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d9be8c26
- **Timestamp:** 2026-08-04T09:39:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-04T09:39:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
