---
id: T-2777
name: "Playwright load-time warm-up expires mid-suite, so fast routes fail as slow"
description: >
  tests/playwright/conftest.py:_warm_slow_routes (T-2104) pre-hits /approvals /inception
  /tasks /timeline /bvp once at session start, to keep cold-aggregation latency from
  being measured as the route's real cost. But the caches it warms have 30s (shared
  task metadata), 60s (dashboard/QR, arc membership) and 120s (session transcripts)
  TTLs, while test_all_routes_load_time.py takes 7.5 minutes to run. Every warmed
  cache has expired long before the parametrized test for that route executes, so
  the warm-up buys nothing beyond the first few tests.

  Evidence: /approvals, /approvals/content and /metrics FAIL the 5s cap inside the
  suite, while the same three routes measure 1.38s, 0.90s and 2.75s against the  live
  server. The suite is reporting cold-cache cost under the name  'warm-load', which
  is a measurement defect, not a page defect. It also masks  the real ones — /timeline
  (T-2775) and /tasks (T-2776) are genuinely over cap  and are currently indistinguishable
  from these three in the output.

  Fix options to weigh, not a decided design: (a) re-warm per-test rather than  per-session;
  (b) measure the second of two consecutive gotos so the first pays
  the cold cost; (c) drop the pretence and assert a separate, higher cold-start  budget
  under an honest name. Whichever is chosen, the assertion message must  say which
  cost it is measuring — the current message says 'warm-load' for a  number that is
  usually cold, and a check that misnames what it measured is how
  a false green or a false red survives review.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/task-create/create-task.sh, 
      tests/unit/test_task_create_description_yaml.py]
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
created: 2026-08-03T19:20:31Z
last_update: '2026-08-16T22:25:17Z'
date_finished: 2026-08-03T23:32:08Z
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
  - ts: '2026-08-03T19:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-03T19:30:09Z'
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
  - ts: '2026-08-16T22:25:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 5
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4-5 (body:new-class); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2777: Playwright load-time warm-up expires mid-suite, so fast routes fail as slow

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The suite measures, and names, one well-defined quantity. Today it reports
      cold-cache-plus-contention cost under the label "warm-load". Whichever design is
      chosen, the assertion message must state which cost it measured — a check that
      misnames its own quantity is how both a false green and a false red survive review.
      **Verified:** the assertion message now reports every sample
      (`f"...best-of-{len(samples)}...(all samples: [{sample_report}])..."`) and states
      explicitly that it measures warm-cache render time, best-of-N, distinct from host
      contention. See `test_all_routes_load_time.py:187-197`.
- [x] Contention is controlled or acknowledged. This is the sharper half of the defect:
      the suite times routes while a browser, a Flask server and 50+ sibling tests share
      one box, so a route's measured latency depends on what else is running. **Scope
      correction from T-2776: FOUR of the five failing routes are fast when measured
      directly** — `/tasks` 0.14s, `/approvals/content` 0.97s, `/approvals` 1.00s,
      `/metrics` 3.00s — against suite readings of 11.7s, 21.8s, 11.8s and 27.3s. Only
      `/timeline` (T-2775) is genuinely over budget, and it is over on **size**, which is
      the one quantity that does not inflate under load (L-443, and the T-2776 RCA).
      **Verified, and corrected (see Updates):** the bounded best-of-3 retry controls
      millisecond-scale contention (a route caught mid-flight of one sibling write). A
      prior pass on this task attributed the remaining 3 red routes to *sustained*
      host-wide contention and left it as an acknowledged, uncontrolled boundary. That
      diagnosis was itself wrong: the actual cause was one specific stale server process
      on the Playwright test port (3099), unmanaged since 2026-08-03, that had degraded
      independent of host load (OBS-098). Killing it and re-running fresh took the same
      3 routes from 13-16s to under 3s and the full suite to 54/54. Contention (the
      general kind) IS still acknowledged, not fully controlled, as a class — but it was
      not the operative cause of this particular failure. See Updates + OBS-098 + T-2782.
- [x] Whatever replaces the current warm-up is verified to actually hold for the routes it
      claims to cover — the present `_warm_slow_routes` runs once per session with 30s/60s/
      120s TTLs behind it and a 7.5-minute suite, so every cache it warms has expired long
      before the route it warmed is tested. Show the new mechanism still warm at point of
      measurement rather than assuming it.
      **Verified:** each parametrized test primes its own route immediately before
      measuring (`test_all_routes_load_time.py:166-169`), independent of session-elapsed
      time. Full-suite run (54 params, 8m57s) confirms `/tasks` — the route T-2776 showed
      cold-reading 11.7s in-suite vs 0.14s live — now passes.
- [x] After the fix, `tests/playwright/test_all_routes_load_time.py` is green except for
      genuinely-over-budget routes, and each remaining red is traceable to a filed task.
      Do NOT reach green by raising `LOAD_CAP_MS` — the guard's own docstring forbids it,
      and the cap is the thing carrying the T-2102 provenance.
      **Met:** full-suite run (fresh test server) is 54 passed / 0 failed in 238.09s
      (0:03:58). No `LOAD_CAP_MS`/`KNOWN_SLOW` values were touched to reach this. See
      Updates.
- [x] The four routes above are re-measured after the change and confirmed passing on
      their merits, not by loosening the assertion.
      **Met:** all four confirmed passing on a fresh test server —
      `/tasks`, `/approvals`, `/approvals/content`, `/metrics` all inside the 54/54 green
      run, no cap changes. The previous "not met" readings were traced to a stale test
      server process, not to these routes — see Updates + OBS-098.

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

# T-2777: full-suite run must show only KNOWN_SLOW-tracked failures (currently /timeline
# only, elevated cap). 54/54 passed once the stale Playwright test-server process (OBS-098)
# was cleared — see RCA. If this line goes red again on a clean checkout, first check
# `ps aux | grep "python3 -m web.app --port ${FW_TEST_PORT:-3099}"` for a long-lived
# leftover process before assuming a real regression or contention (T-2782 tracks the
# structural fix; this comment is the interim mitigation until it lands).
out=$(python3 -m pytest tests/playwright/test_all_routes_load_time.py -q 2>&1); echo "$out" | grep -q " passed" && ! echo "$out" | grep -q " failed"

## RCA

**Symptom:** `test_all_routes_load_time.py` reported `/approvals`, `/approvals/content`
and `/metrics` failing the 5s cap under the label "warm-load", while the same routes
measured 0.9-3.0s against a live, directly-curled server. The suite was reporting a
number under a name that implied it wasn't what it actually measured.

**Root cause:** `conftest.py:_warm_slow_routes` (T-2104) warms a fixed route set once
per session, but the caches behind those routes carry 30s/60s/120s TTLs while the
parametrized suite takes ~7.5 minutes to reach most of its 54 routes — every warmed
cache had already expired by the time its route was tested. The prior "prime, then
measure" pair inside each test (added post-T-2104) mostly compensated for that, but
took exactly one measured sample — so a route caught mid-flight by a concurrent
session's write to `.tasks/active/` (this repo self-hosts, and dozens of concurrent
agent sessions write to the corpus continuously) paid a full cache-rebuild cost on
that one sample and reported it, indistinguishably, as "warm-load".

**Why structurally allowed:** nothing separated "structurally slow route" from "route
caught mid-rebuild by another session's write" — a single sample and a label that
didn't say what was actually measured meant a contention-inflated reading and a
genuine regression produced the identical failure message.

**Prevention (implemented, see diff to `test_all_routes_load_time.py`):**
1. Each parametrized test primes its own route immediately before measuring, so the
   guard never depends on the session-level warm-up's TTL surviving to that point.
2. Measurement takes the best of up to 3 samples (`RETRY_SAMPLES`), bounded — a route
   caught mid-flight by a sibling session's write gets a clean sample within a retry; a
   structurally slow route stays slow across all of them.
3. The assertion message reports every sample and states explicitly what was measured
   ("warm-cache page-render time, best case across repeated samples"), so a genuine
   regression and a contention-inflated failure read differently in the output.

**Correction (second pass, 2026-08-04):** a prior pass on this task investigated the
remaining 3 red routes and attributed them to sustained host-wide contention (load
average 3-5, 16-18 concurrent `web.app` processes), citing that as a live confirmation
of a boundary the fix's docstring already acknowledges, and left the task at
`started-work` with those 2 ACs unmet.

That diagnosis was itself wrong. `tests/playwright/conftest.py:watchtower_server`
reuses whatever server is already listening on the Playwright test port (3099) across
sessions, with no staleness check and no teardown if it didn't start the process. The
server actually serving those 3 routes during every failing run had been running
unmanaged since 2026-08-03 — 656MB RSS, ~66 minutes of accumulated CPU by the time it
was found (`ps`/`/proc/<pid>/status`), roughly a day old. `curl` directly against
THAT process (not a fresh one) reproduced the identical 13-16s readings the Playwright
suite saw — ruling out Playwright/browser overhead as the cause. Killing that one
process and letting the fixture spawn a fresh instance took the same 3 routes from
13-16s to under 3s, and the full 54-route suite from ~9min/51-passed to 4min/54-passed,
with host load unchanged throughout (`uptime` before/after: load average ~4-5 both
times). The host genuinely was busy — that part of the prior diagnosis was accurately
observed — but busy-host was not what was making these 3 routes slow; one specific
degraded process was.

Registered as **OBS-098** (`.context/concerns.yaml`) — the fixture's unbounded server
reuse is a structural gap: it can silently degrade the exact timings this suite exists
to guard, and will reproduce the identical "host contention" misdiagnosis for the next
session that hits it, same as it did here. Follow-up **T-2782** filed (build, horizon
later) to add a staleness/age bound to `watchtower_server` — out of scope for this task
because it touches a shared fixture used by every Playwright test file, not just this
one's measurement-methodology fix.

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

### 2026-08-03T19:20:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2777-playwright-load-time-warm-up-expires-mid.md
- **Context:** Initial task creation

### 2026-08-03T21:11:30Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-04T01:xx:xxZ — dispatched-worker verification pass
- **Found:** the fix (per-test priming + best-of-3-samples retry, honest assertion
  naming) was already implemented in a prior session, uncommitted. Read the diff
  against `tests/playwright/test_all_routes_load_time.py` in full — matches design
  option (a)+(b) from the task body, correctly.
- **Ran:** targeted 4-route subset twice (~13 min apart) and the full 54-route suite
  once (8m57s). Result both times: 51 passed / 3 failed — `/approvals`,
  `/approvals/content`, `/metrics` fail reproducibly on all 3 retry samples;
  `/timeline` passes under its `KNOWN_SLOW`/T-2775 elevated cap; `/tasks` (the T-2776
  false-red) now passes.
- **Cross-checked against live server directly** (bypassing Playwright): `curl` to the
  same 3 routes on the already-running test server reproduced the same 5.5-16s
  readings, twice, ruling out Playwright-specific overhead as the cause.
- **Investigated (hypothesis-driven, bounded):** `/health` and `/api/version` on the
  same server responded in 12-22ms — rules out global request-handling stall.
  `web/blueprints/approvals.py` GET routes don't call subprocess directly, but
  `_build_approvals_context` runs ~7 independent full-corpus scans per request over
  313 active task files. `web/blueprints/metrics.py` calls `run_git_command` (git log,
  uncached) twice per request — genuinely sensitive to host scheduling contention.
  `vmstat` showed 13k-21k context-switches/sec; `ps` showed 17 concurrent `web.app`
  instances plus multiple live `claude` sessions and termlink hubs on this host.
  Conclusion: real, current, sustained host contention — not a flaw in the delivered
  fix, but a live demonstration of the boundary the fix's own docstring already
  documents (bounded retry survives millisecond blips, not sustained load).
- **Did NOT:** modify `RETRY_SAMPLES`, add host-load-aware skip logic, or touch
  `web/blueprints/metrics.py` / `approvals.py` — any of those would be scope
  expansion beyond the measurement-methodology fix this task targets, and touching
  them now would be fitting the test to one moment's host state rather than a
  structural condition. Left AC #4/#5 unticked and Verification red pending either a
  quieter re-run or a follow-up KNOWN_SLOW-pattern task if the 3 routes prove
  structurally slow independent of load.
- **Left task at `started-work`** — not moving to `work-completed`; two Agent ACs are
  genuinely unmet right now and the Verification line above correctly blocks the gate.

### 2026-08-04T01:xx:xxZ — dispatched-worker, second pass: corrected diagnosis
- **Re-checked host state:** `uptime` showed load average ~4-5, `ps` showed 16-18
  concurrent `web.app` instances — essentially the same sustained-load condition the
  prior pass measured. Direct `curl` to the *production* Watchtower (port 3001) for the
  3 failing routes measured 0.9-2.8s — fast, consistent with earlier live-server checks.
- **Found the actual server under test:** the Playwright suite talks to a *different*
  server, on `FW_TEST_PORT` (3099), managed by `conftest.py:watchtower_server`. `ps`
  showed that process running since 2026-08-03 (yesterday), 656MB RSS, ~66 minutes
  accumulated CPU — `watchtower_server`'s "already running, don't manage it" branch had
  been reusing it across every session since, with no staleness check and no teardown.
- **Confirmed by direct curl to that specific process** (bypassing Playwright entirely):
  `/approvals` 15.8s, `/approvals/content` 5.6s, `/metrics` 13.8s — reproducing the
  in-suite readings exactly, and ruling out Playwright/browser overhead as the cause.
- **Killed the stale process** (`kill <pid>`; it was root-owned, this session runs as
  root). Confirmed port 3099 freed.
- **Re-ran the full suite** — `watchtower_server` auto-spawned a fresh instance.
  Result: **54 passed, 0 failed, in 238.09s (0:03:58)** — down from ~9 minutes and
  51/54 on every prior run this session, host load unchanged throughout.
- **Registered OBS-098** in `.context/concerns.yaml` — the unbounded-reuse gap in
  `watchtower_server` is structural and will reproduce the same misdiagnosis for future
  sessions until bounded.
- **Filed T-2782** (build, horizon later) — add a staleness/age bound to
  `watchtower_server`. Left out of this task's scope: it's a shared fixture used by
  every Playwright test file, not specific to this task's measurement-methodology fix,
  and warrants its own review rather than an incidental edit here.
- **Updated RCA + the 2 previously-unmet Agent ACs** to reflect the corrected finding;
  both are now met. Verification line re-run and green.
- **Did NOT** modify `RETRY_SAMPLES`, `LOAD_CAP_MS`, or any blueprint cache code — the
  fix that got the suite green was killing a stale process, not a code change to the
  routes or the guard.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-972c23ac
- **Timestamp:** 2026-08-03T23:36:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-03T23:32:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
