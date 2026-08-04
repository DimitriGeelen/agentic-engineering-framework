---
id: T-2784
name: "Playwright tests hard-code port 3099, bypassing FW_TEST_PORT and the T-2782
  identity check"
description: >
  81 of 150 tests/playwright/test_*.py files define their own module-level TEST_URL
  = "http://localhost:3099" instead of taking it from conftest. None of them read
  FW_TEST_PORT.

  All 81 do depend on the page fixture, so a server IS established — that half is
  sound. But conftest starts/adopts/verifies a server on FW_TEST_PORT while these
  files send their requests to a literal 3099. When the two differ, the T-2782 identity
  check and staleness bound apply to a server the tests are not talking to, and if
  anything else holds 3099 (another project's Watchtower — every consumer runs the
  same Flask app) the suite asserts confidently against it.

  3 files already use the correct shape (import TEST_URL from conftest). Found by
  the T-2783 sweep.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
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
created: 2026-08-04T10:06:24Z
last_update: 2026-08-04T12:38:56Z
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
  - ts: '2026-08-04T10:09:15Z'
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
cost_estimate_proposed:
  - ts: '2026-08-04T10:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2784: Playwright tests hard-code port 3099, bypassing FW_TEST_PORT and the T-2782 identity check

## Context

Second half of the T-2782 wrong-object class, found by the T-2783 sweep. See that task for
the first half (`base_url` returning a URL with no server behind it).

### Baseline — full suite BEFORE the conversion

`FW_TEST_PORT=3099 python3 -m pytest tests/playwright/ -q`, 2026-08-04:

```
13 failed, 885 passed, 5 skipped in 3169.20s (0:52:49)
```

All 13 predate this task and are **not** absorbed into its diff — filed as **OBS-142**:

| Failure | |
|---|---|
| `test_all_routes_height.py::test_route_height_bounded[/]` | height guard |
| `test_all_routes_height.py::test_route_height_bounded[/metrics]` | height guard |
| `test_all_routes_height.py::test_parametrized_route_height_bounded[/inception/T-2715]` | height guard |
| `test_all_routes_height.py::test_parametrized_route_height_bounded[/review/T-2715]` | height guard |
| `test_arc_review_route.py::test_arc_review_no_form_fields` | |
| `test_arc_review_route.py::test_arc_review_renders_for_closed_arc_without_redirect` | |
| `test_arcs_kanban.py::test_arcs_link_lives_under_work_nav_group` | |
| `test_badge_contrast.py::...::test_arc_detail_badge_contrast[.badge-ok]` | |
| `test_bulk_actions.py::...::test_listeners_survive_content_swap` | |
| `test_bvp_form_htmx.py::test_add_form_submit_keeps_user_on_bvp` | |
| `test_file_viewer.py::...::test_file_viewer_loads_markdown` | |
| `test_mobile_viewport.py::...::test_approvals_no_horizontal_overflow_on_mobile` | |
| `test_task_panel.py::...::test_panel_opens_after_htmx_board_swap` | |

The four height failures are worth first look: T-2775 showed that axis can be satisfied by
hiding overflow rather than bounding it, so a *red* height guard is more likely the honest
signal than noise.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] No `tests/playwright/test_*.py` defines its own port or host literal. All of them take
      the target from one place, and that place is the same one `conftest.py` uses to decide
      which server to start, adopt or verify — so the address under test and the address under
      guard cannot diverge.
- [x] Setting `FW_TEST_PORT` moves the whole suite, demonstrated rather than asserted: run a
      sample of the converted files against a non-default port and show they hit it. Before
      this change they would have gone to 3099 regardless.
- [x] The literal cannot come back: a check fails if a new test file introduces a bare
      `localhost:<port>` / `127.0.0.1:<port>`, and it is red before the fix and green after
      (mutation-checked, L-530). 81 files drifted into this shape one at a time; nothing
      noticed, which is the actual defect.
- [ ] Full playwright suite result recorded before and after with the same invocation, so the
      conversion is shown not to have changed which tests pass. Any test that was already
      failing stays named rather than absorbed into the diff.
      **PENDING — before-run done, after-run in flight (3rd attempt).** Baseline recorded above
      (13 failed / 885 passed / 5 skipped, 52:49), preserved at `/tmp/.before-failures.txt` and
      inlined in the table above. The after-run is `FW_TEST_PORT=3099 python3 -m pytest
      tests/playwright/ -q`, started 2026-08-04 ~15:16, logging to
      `.context/working/.T-2784-after-run.log` (project-root path this time — the prior two
      attempts lost their log to a `/tmp` session dir that got unlinked with the wrapper shell).
      **To finish:** wait for `EXIT=` / the summary line at the end of that file, then
      `grep "^FAILED" .context/working/.T-2784-after-run.log | sed 's/^FAILED //' | sort > /tmp/.after-failures.txt`
      and `diff /tmp/.before-failures.txt /tmp/.after-failures.txt`. Expected: empty diff — the
      conversion changes only where the address comes from. A non-empty diff on the *added*
      side is a regression from this task and must be fixed, not accepted.
      Deliberately left unticked: two earlier attempts were lost (one to `--timeout=120`, which
      this environment has no plugin for and which exits 4; one to the harness unlinking the
      log when it killed the wrapper shell). Neither is evidence the suite passed.

      **ATTEMPT 3 COMPLETED AND IS INVALID. STILL UNTICKED.**
      Result: `310 failed, 590 passed, 3 skipped in 2519.27s (0:41:59)` against a baseline of
      `13 failed, 885 passed, 5 skipped`. That looks like a catastrophic regression and is not
      one — the failures are **connection-level, not assertion-level**:

      ```
      100  net::ERR_CONNECTION_REFUSED     (in the first 250KB of the log alone)
        2  TimeoutError
      ```

      and nothing answers on `:3099` now. The suite was addressing a server that was not there
      for much of the run, so it measured server absence, not the port conversion.

      **The contamination is mine and is stated rather than reasoned around.** While this run was
      in flight I ran, on the same host: the full `tests/unit` pytest suite (~6 min, 2085 tests),
      two complete `bats --count tests/unit/` passes over 387 files, and a `bats` execution. I had
      already flagged the risk for *latency* assertions (L-542: size is contention-invariant,
      latency is not) and then under-estimated it — 310 connection refusals is a heavier failure
      than contention alone comfortably explains, which is exactly why it cannot be attributed
      either way from this log.

      So this run supports **neither** verdict. It does not show a regression from the conversion
      (no import error, no addressing failure, no assertion diff appears in it), and it does not
      clear the conversion either, because a suite that could not reach its server cannot testify
      about which address it used. Reporting it as a pass would be false; reporting it as a
      T-2784 regression would be false in the other direction.

      **What attempt 4 must do differently:** run it with nothing else touching the host, and
      capture the fixture's own adoption line (`[watchtower_server] <action>: <reason>`, added by
      T-2782) by running with `-q -s` or `--capture=no` so the decision is in the log. This run
      printed no such line anywhere, so the server's fate is unreconstructible after the fact —
      the one piece of evidence that would have settled it in seconds.
      Log preserved at `.context/working/T-2784-after-run.log` (753KB).

      **ATTEMPT 4 COMPLETED AND IS ALSO INVALID — DIFFERENT CAUSE, SAME CLASS.** Run with
      `-s` this time, isolated (no concurrent suites on my part). Result: `137 failed, 761
      passed, 5 skipped in 2948.50s (0:49:08)` against the 13-failure baseline. The
      `[watchtower_server] start: nothing listening on the test port` line appears exactly
      once at the top — the fixture correctly started its own fresh server, no adoption/
      identity ambiguity this time.

      The 137 failures are not scattered: `diff`-ing against the baseline shows the 13
      known-pre-existing failures unchanged, plus a **contiguous alphabetical block** of 89
      new failures (`test_review_*` through `test_verdict_ui.py`, the back third of the
      file list) — exactly the shape of "server died partway through," not "these files
      broke." Spot-checked `test_review_page.py::test_review_has_content`:
      `playwright._impl._errors.Error: Page.goto: net::ERR_CONNECTION_REFUSED at
      http://localhost:3099/review/T-1794`. Server was up, then wasn't.

      `/tmp/watchtower-test-stderr.log` (the fixture's captured stderr, T-1954-era pipe-
      buffer-deadlock fix) could not be used to diagnose the death: the fixture opens it
      `"w"` (truncate) on every `start`, and a later diagnostic sub-run overwrote it before
      I read it. No OOM entries in `dmesg`/`journalctl -k` for the window either way.

      **This is a host-contention finding, not a self-contamination one — and it is
      structural, not incidental.** `ps aux` mid-investigation showed **15 concurrent
      `python3 -m web.app` processes** already running on this host (ports 3000-3200,
      3098-3101, 4050 — other consumer projects' Watchtowers, per-project isolation working
      as designed but sharing one machine's CPU/RAM), plus `free -h` showing 28GB/32GB swap
      in use with only 842MB physically free (31GB "available" via reclaimable cache, so not
      OOM-critical, but evidence of sustained pressure). A single-threaded Flask dev server
      under a 49-minute continuous run is not resilient to a neighbour on the same host
      spiking load or memory at the wrong moment — and on this host, multiple neighbours are
      *always* running. Two independent 49-minute runs (attempt 3, contaminated by me;
      attempt 4, isolated) both lost the server mid-run. The baseline run (13 failed) is the
      only one of three that completed clean — which may itself have been luck rather than a
      property of the earlier code.

      Log preserved at `.context/working/.T-2784-after-run.log` (334KB, `-s` captured).

      **Attempt 5 in flight** (2026-08-04 ~19:14): same invocation
      (`FW_TEST_PORT=3099 python3 -m pytest tests/playwright/ -q -s`), backgrounded, logging
      to `.context/working/.T-2784-after-run5.log`, nothing else run concurrently on my part.
      If this one also loses the server mid-run, the AC's "same invocation" premise (a single
      49-minute monolithic run, matching the baseline's shape exactly) may not be achievable
      reliably on this host regardless of the code under test, and the fallback is chunked
      re-verification of only the diff set (the 89 newly-failing tests) run in isolation
      against a fresh short-lived server, cross-referenced with the already-completed AC #2
      sample demonstration — not a fourth/fifth full-suite attempt for its own sake.

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

### 2026-08-04T10:06:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2784-playwright-tests-hard-code-port-3099-byp.md
- **Context:** Initial task creation

### 2026-08-04T10:09:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
