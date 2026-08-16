---
id: T-2776
name: "Watchtower /tasks takes 15s to first byte on a warm server"
description: >
  Measured 15.008s time-to-first-byte against the live Watchtower with warm caches,
  for a 662,916-byte response. Exceeds the 5s LOAD_CAP_MS guard by 3x and sits exactly
  at the OLD 15s Playwright goto timeout — which is why it read as flaky rather than
  slow (T-2774 RCA).

  Found while fixing T-2774. Not the same cause: T-2774's fixes (CSafeLoader  frontmatter
  parsing, shared-cache reuse in arcs.py) took / from 57.8s cold to  1.5s and /approvals
  to 1.4s, but did not move /tasks. Needs its own profile —  do not assume it is the
  same corpus-scan shape without measuring, which is the
  mistake the T-2774 thread already made once.

  Profile with the route profiler pattern: cProfile around a Flask test-client  GET,
  sort by cumulative. That is what located T-2774's cause (6,243  yaml.safe_load calls
  = 64 of 70.9 profiled seconds) in one pass.

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-08-03T19:19:39Z
last_update: '2026-08-16T22:25:17Z'
date_finished: 2026-08-03T21:10:46Z
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
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2776: Watchtower /tasks takes 15s to first byte on a warm server

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The 15.0s figure is re-established on a **quiet system** before anything is built on
      it. L-443 (T-2083): perf measurements must be steady-state, not contention-amplified.
      The original reading was taken moments after a 7.5-minute Playwright run and with a
      background sampler in flight, so it is a suspect number until re-measured. Record
      several runs with system load alongside. If `/tasks` turns out to be fast when idle,
      say so and re-scope this task rather than fixing a phantom — the T-2774 thread
      already spent a cycle on a diagnosis built from one bad measurement.
      → **The premise is false. `/tasks` is not slow.** Re-measured at load average 8.19
        (i.e. NOT a quiet system — the reading is if anything pessimistic): 5 consecutive
        runs gave **3.70s / 0.147s / 0.162s / 0.140s / 0.295s**, response 666,407 bytes.
        A second pass gave 1.85s cold → **0.139s warm**. The route answers in under
        two-tenths of a second. The original 15.008s was contention amplification, exactly
        the L-443 class, measured while a Playwright suite and a background sampler were
        both in flight.
- [x] ~~Cause named by profile~~ — **moot: there is no defect to profile.** Not run, and
      deliberately so; profiling a route that answers in 0.14s would have manufactured a
      cause for a problem that does not exist.
- [x] ~~First-byte time brought under the 5s `LOAD_CAP_MS` guard~~ — **already under it**,
      by a factor of ~35 warm and ~1.4 cold. Nothing to bring.
- [x] ~~`/tasks` passes the load-time suite~~ — its failure there is T-2777's measurement
      defect, not a property of this route. Re-pointed rather than fixed here.
- [x] ~~Board and list views unchanged~~ — **moot: no change was made.** No code was
      touched under this task.

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
# The premise of this task was that /tasks is slow. It is not. This asserts the
# finding that closed it: first byte well under the 5s LOAD_CAP_MS budget. One
# warming request, then the measured one — a cold cache is legitimate cost, not
# the thing this records. Single line: the extractor runs each line as its own
# command and shreds a multi-line python -c (learned on T-2774).
curl -sf -o /dev/null -m 60 "$(bin/fw watchtower url)/tasks" && python3 -c "import time,urllib.request,sys; u=sys.argv[1]+'/tasks'; t0=time.perf_counter(); urllib.request.urlopen(u,timeout=60).read(); d=time.perf_counter()-t0; print(f'/tasks {d:.3f}s'); sys.exit(0 if d < 5.0 else 1)" "$(bin/fw watchtower url)"

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

## Recommendation

**Recommendation:** GO — close as NOT-A-DEFECT. The filing was wrong; `/tasks` is fast.

**Rationale:** I filed this on a 15.008s measurement taken while a 7.5-minute Playwright
suite had just finished and a background sampler was still running. Re-measured at load
average 8.19 — deliberately not a quiet system, so the number is if anything pessimistic —
`/tasks` returns first byte in **0.14s warm**, 1.85–3.70s cold. It is under the 5s
`LOAD_CAP_MS` guard by a wide margin and needs no work.

The AC that caught this was written before the measurement, precisely because L-443
(T-2083) already names contention-amplified perf readings as a known class, and because
the T-2774 thread had just spent a cycle on a diagnosis built from one bad measurement.
Writing the falsification condition into the AC *first* is what made the phantom cheap —
one measurement instead of a profile-and-fix cycle against a route that was never slow.

**This also corrects my own report from the previous session.** I said two of the five
load-time failures were genuine (T-2775, T-2776) and three were the measurement defect.
That was wrong: **only `/timeline` (T-2775) is genuine**, and four of five are T-2777's
measurement defect. Re-measured directly, every other route is comfortably under cap —
`/metrics` 3.00s, `/approvals` 1.00s, `/approvals/content` 0.97s, `/bvp` 1.45s.
`/timeline` survives because its defect is **size** (69,836,661 bytes, confirmed on two
separate passes), and size cannot be contention-amplified the way latency can.

**Evidence:**
- 5 consecutive runs, load avg 8.19: 3.70s / 0.147s / 0.162s / 0.140s / 0.295s
- Second independent pass: 1.850s cold → 0.139s warm, 666,407 bytes
- Comparison sweep of all previously-"failing" routes, cold → warm:
  `/` 3.03→1.67s · `/tasks` 1.85→0.14s · `/metrics` 3.14→3.00s · `/approvals` 1.05→1.00s ·
  `/approvals/content` 0.99→0.97s · `/bvp` 1.58→1.45s · `/timeline` 3.37→2.98s
- No source file was modified under this task.

## RCA (measurement defect, not a product defect)

**Symptom.** `/tasks` reported at 15.008s first byte; filed as a slow-route bug.

**Root cause.** The measurement was taken during heavy contention — immediately after a
7.5-minute Playwright run, with a 16-sample background curl loop still in flight, on a box
already at load average ~8. The route itself costs 0.14s warm.

**Why structurally allowed.** Two things, and the second is the interesting one.

L-443 already names this class ("perf measurements must be steady-state, not
contention-amplified"). It surfaced in the `fw work-on` briefing for this very task — but
*after* the task was filed. The knowledge was in the system and reached me one step too
late to prevent the filing; it arrived in time only to prevent the fix.

More usefully: I took the 15.008s reading in the same batch as `/timeline`'s 69.8 MB and
treated both as equally solid, because they came out of one command. But they are not
equally solid — **a size measurement is contention-invariant and a latency measurement is
not.** Bundling both into one sweep made them look like observations of the same quality.
There was no step that asked which numbers in the batch were load-sensitive.

**Prevention.** The durable form is the AC pattern that actually worked here: when a task's
premise is a performance number, make "re-establish the number under controlled conditions,
and re-scope if it does not hold" the *first* acceptance criterion, ahead of any fix. That
converts a possible phantom from a fix-cycle into a single measurement. Recorded as a
learning against this task rather than as new tooling — a lint cannot tell which of two
numbers in a batch was load-sensitive, but an author asking "is this quantity
contention-invariant?" can.

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

### 2026-08-03T19:19:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2776-watchtower-tasks-takes-15s-to-first-byte.md
- **Context:** Initial task creation

### 2026-08-03T21:06:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-094fdbce
- **Timestamp:** 2026-08-03T21:10:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-03T21:10:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
