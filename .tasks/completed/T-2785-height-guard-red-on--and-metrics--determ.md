---
id: T-2785
name: "Height guard red on / and /metrics — determine whether the signal is honest"
description: >
  test_all_routes_height.py has 4 failures in the 2026-08-04 baseline: test_route_height_bounded[/]
  and [/metrics], plus test_parametrized_route_height_bounded[/inception/T-2715] and
  [/review/T-2715]. They predate T-2784 and nothing is acting on them (OBS-142).

  Worth investigating rather than muting: T-2775 established that the height axis
  can be satisfied by hiding overflow inside a collapsed <details> (display:none is
  excluded from scrollHeight) while still shipping every byte. A guard that is RED
  on that axis is therefore more likely to be reporting an honest unbounded page than
  to be broken — the failure direction is the informative one.

  Determine, per failing route, whether the page genuinely exceeds the height bound
  (fix the page) or the guard's expectation has drifted (fix the guard). Do not raise
  the cap to make it green.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [web/blueprints/cockpit.py, web/blueprints/inception.py, web/blueprints/metrics.py, web/templates/cockpit.html, web/templates/metrics.html, web/templates/task_detail.html]
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
created: 2026-08-04T11:12:28Z
last_update: 2026-08-04T21:23:30Z
date_finished: 2026-08-04T21:23:30Z
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
  - ts: '2026-08-04T11:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-04T11:15:11Z'
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

# T-2785: Height guard red on / and /metrics — determine whether the signal is honest

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Each of the 4 failing routes is measured and classified as either **page genuinely over
      the bound** or **guard expectation drifted**, with the measured height and the bound
      quoted for each. A verdict without a number is not a classification.
      - `/` — 16627px vs 8000px cap. **Genuinely over.** Correction to an earlier draft of
        this classification, which had cited `_get_attention_items()`/`index.html`:
        `core.index()` only falls back to `index.html`/`_get_attention_items()`
        when `load_scan()` returns falsy; live, `load_scan()` is truthy (verified:
        `python3 -c "from web.blueprints.core import load_scan; print(bool(load_scan()))"`
        → `True`), so `/` actually renders `cockpit.html` via `get_cockpit_context()`.
        The real dominant contributor is the "Work Direction" queue —
        `get_cockpit_context()` passed `scan_data["work_queue"]` through unsliced
        (1:1 with active-task count, 317 today, no cap) and `cockpit.html:262-292`
        rendered one `.wt-queue-item` per entry unconditionally.
      - `/metrics` — 10477px vs 8000px cap. **Genuinely over.** `metrics._stale_tasks()`
        appends one entry per active task with `status=issues` or `last_update` >7d old
        (260 of 317 today, no cap) — `web/templates/metrics.html:151` renders the full list.
      - `/inception/T-2715` — 11104px vs 8000px cap. **Genuinely over.** T-2715's `## Open
        Questions` section is 51,547 chars / 147 lines; it isn't in `inception.py`'s
        `KNOWN_SECTIONS` set so it falls into `extra_sections` and renders in full via
        `web/templates/inception_detail.html`'s generic section card — no truncation.
      - `/review/T-2715` — same 11104px measurement. **Same root cause as above, not a
        distinct page.** `web/blueprints/review.py:160` 302-redirects `/review/<id>` to
        `/inception/<id>` when the task is `workflow_type: inception` (T-2125 class-correct
        routing) — Playwright follows the redirect, so both parametrized-test IDs measure
        the identical rendered HTML.
- [x] For any route classified "page over the bound", the page is bounded the way T-2775
      bounded `/timeline`: render less, keep the remainder reachable. Raising the cap, hiding
      overflow behind `display:none`, or adding the route to a skip list are all explicitly
      out of scope — each makes the guard green while the page stays unbounded, which is the
      failure mode the guard exists to catch.
      - `/` — `web/blueprints/cockpit.py`: `get_cockpit_context()` now slices
        `work_queue` to `WORK_QUEUE_INITIAL = 20` (of 317) and exposes
        `work_queue_total`/`work_queue_initial`; `cockpit.html` renders the capped
        list plus a "Show N more" htmx link to the new
        `GET /api/scan/work-queue-more` route, which renders the true remainder
        via `_work_queue_items.html` on demand — the rows past 20 are absent from
        the initial DOM, not `display:none`-hidden.
      - `/metrics` — `web/blueprints/metrics.py`: `project_metrics()` slices `stale`
        to `STALE_TASKS_INITIAL = 20` (of 260) and exposes `stale_tasks_total`/
        `stale_tasks_initial`; `metrics.html` mirrors the same capped-list +
        "Show N more" + `GET /api/metrics/stale-tasks-more` shape via
        `_stale_tasks_items.html`.
      - `/inception/T-2715` + `/review/T-2715` (same page, see AC1) —
        `web/blueprints/inception.py`: `_build_extra_sections()` truncates any
        extra section past `EXTRA_SECTION_TRUNCATE_CHARS = 2000`, cut on a
        newline boundary; `inception_detail.html` renders the truncated card plus
        a "Show full section (N chars)" htmx link to the new
        `GET /inception/<task_id>/section-expand/<idx>` route, which returns the
        untruncated card in place. `## Open Questions` (51,547 chars) now ships
        ~2000 chars initially, not all 51,547.
- [x] For any route classified "guard drifted", the reason the expectation no longer holds is
      named (route renamed, fixture task removed, selector changed), and the guard is corrected
      so it still fails on a genuinely over-height page — demonstrated by mutation, not asserted.
      **N/A — vacuously satisfied.** All 4 failing routes were classified "page genuinely over
      the bound" in AC1 (none guard-drifted), so there is nothing for this AC to act on. The
      guard's own correctness (still fails on genuinely-over pages) is demonstrated by the
      baseline re-run below reproducing the original 4 failures against the pre-fix code —
      the guard was never broken, only honest.
- [x] `test_all_routes_height.py` ends green, and the count of tests it runs is reported before
      and after so a route cannot go green by ceasing to be measured.
      **Before (pre-fix code, reproduced via `git stash` of the 3 blueprint + 3 template +
      2 new-partial files, then rerun):** `4 failed, 70 passed in 304.86s` — 74 tests total,
      failures on exactly the 4 routes named in this task's description (`/`, `/metrics`,
      `/inception/T-2715`, `/review/T-2715`).
      **After (fix restored via `git stash pop`):** `74 passed in 299.14s` — same 74 tests
      total, zero failures. Route count is identical before/after (74 == 74) — no route
      dropped out of measurement; all 4 previously-failing routes are now passing for real.

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

out=$(python3 -m pytest tests/playwright/test_all_routes_height.py -q 2>&1); echo "$out" | grep -q " passed" && ! echo "$out" | grep -q " failed"

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

### 2026-08-04T11:12:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2785-height-guard-red-on--and-metrics--determ.md
- **Context:** Initial task creation

### 2026-08-04T11:15:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ff262b34
- **Timestamp:** 2026-08-04T21:28:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-04T21:23:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
