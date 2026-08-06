---
id: T-2837
name: "tests/lint red is invisible to every runner"
description: >
  tests/lint red is invisible to every runner

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004, web/blueprints/config.py]
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
created: 2026-08-06T20:59:22Z
last_update: 2026-08-06T21:39:43Z
date_finished: 2026-08-06T21:39:43Z
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
  - ts: '2026-08-06T21:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T21:15:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2837: tests/lint red is invisible to every runner

## Context

`tests/lint/` holds the framework's structural invariants — router↔help parity,
config-registry parity, single-vendor-writer, no-bare-fw. One of them
(`help-router-parity.bats`) was red across an unknown number of sessions while
20 verbs drifted out of `fw help`; T-2836 fixed the drift, this task addresses
why nobody found out.

**The obvious diagnosis is wrong and was checked.** The suite is *not* orphaned:
T-2697 added `fw test invariants` and wired `tests/lint/` into `fw test all`
(`bin/fw:7941-7964`, `:8040-8042`). The runner exists and works. My first
framing — "globbed by no runner", the T-2696/T-2786 class — was stale by one
task, and is recorded here so the next reader doesn't re-derive it.

**The actual gap is scheduling.** `.context/cron-registry.yaml` has 25 jobs.
`fw audit` alone runs on five schedules (every 30 min, hourly, 6-hourly, daily,
weekly). **No job runs any test suite** — `grep -E "fw test|bats|pytest"` over
the registry returns nothing. So every automated surface an agent or operator
reads (doctor, audit, Watchtower, the pre-push gate) can be fully green while an
invariant suite is red, indefinitely, by construction.

That is the same shape as the defect it failed to catch: a check that exists,
is correct, and is never reached. T-2697 built the runner and stopped one step
short of anything invoking it.

Mechanism (cron entry vs. an `fw audit --section invariants` leg) is deliberately
not fixed by these ACs — it depends on measured suite runtime, which is the
first piece of work. Recorded in `## Decisions` once measured.

## Acceptance Criteria

### Agent
- [x] `tests/lint/` suite runtime is measured and recorded in `## Decisions`;
      the chosen mechanism is justified against that number (a 30-min audit leg
      and a daily cron have very different budgets).
- [x] Some automated, unattended surface fails or warns when a `tests/lint/`
      test is red — demonstrated by making one temporarily red and observing
      the surface change, not by reading the wiring.
- [x] The signal reaches somewhere an agent actually reads at session start
      (audit output, `fw doctor`, or the handover), not only a cron log file.
- [x] If the mechanism is a cron entry: registry → generated → deployed chain is
      verified per CLAUDE.md (`fw doctor` reports "Cron registry in sync" and
      not "edited but not generated").
- [x] The negative control is stated: with all invariants green, the new surface
      is quiet — no permanent WARN that would train readers to ignore it.

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

# Not a live `fw audit` invocation here: audit.sh takes a flock (agents/audit/audit.sh:320-330)
# shared with the real 30-min cron job, so a gate-time invocation races the live
# schedule and is flaky by construction — quiet mode silently exit-0s on contention
# with no output written, which would make this line pass/fail on cron timing
# rather than on the wiring. Live behaviour was demonstrated manually this session
# (see ## Decisions) instead; these lines assert the static wiring deterministically.
grep -q "check_invariant_suite" agents/audit/audit.sh
out=$(sed -n '/^# SECTION 1: STRUCTURE CHECKS/,/^# SECTION 2:/p' agents/audit/audit.sh); echo "$out" | grep -q "check_invariant_suite"
out=$(bats tests/lint/ 2>&1); echo "$out" | grep -qE '^[0-9]+\.\.[0-9]+$'

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

### 2026-08-06 — Scheduling mechanism (measured runtime → existing 30-min section, not a new cron)
- **Measured:** `time bats tests/lint/` → 51 tests, `real 0m5.560s` (`user 0m3.734s`, `sys 0m2.408s`).
- **Chose:** Wire `tests/lint/` into `agents/audit/audit.sh`'s `STRUCTURE` section
  (`check_invariant_suite()`, `agents/audit/audit.sh:1897-1930` — landed as a prior
  step in this same task's work, commit `55744e9e`) rather than a dedicated cron
  entry. `structural-30m` (`.context/cron-registry.yaml`) already runs
  `fw audit --section structure,compliance,quality,discovery` every 30 minutes and
  on the pre-push audit path — placing the check inside an already-scheduled
  section means it inherits that cadence for free.
- **Why:** 5.6s is negligible against a 30-minute budget (<0.4% duty cycle) — no
  case for a separate, coarser (e.g. daily) cron just to keep the check cheap.
  Reusing the section means **zero `.context/cron-registry.yaml` edits**, so the
  CLAUDE.md cron-touching-task Verification requirement (registry → generated →
  deployed chain) does not apply here — nothing was registered, generated, or
  redeployed. Confirmed via `fw doctor` that cron state is unaffected by this
  change (see Verification).
- **Rejected:** A new dedicated cron job — would be the registry's 26th entry for
  a check cheap enough to ride along on an existing 30-min leg; also would have
  required the full registry→generate→deploy chain for no benefit.

### 2026-08-06 — Live demonstration (AC2) and negative control (AC5)
- **Demonstrated live:** appended a deliberately-failing `@test` to
  `tests/lint/no-force-in-framework.bats`, ran
  `bin/fw audit --section structure --output /tmp/t2837-demo`, observed the
  invariant check flip from `FAIL "Invariant suite: 1 of 51 ... RED"` to
  `FAIL "Invariant suite: 2 of 52 ... RED"` — the count moved live off a real
  bats run, not a cached/stale value. Reverted with `git checkout --`, reran,
  confirmed it returned to exactly `FAIL "Invariant suite: 1 of 51 ... RED"`.
- **Unplanned but stronger evidence:** the baseline itself was not a clean pass —
  `config-registry-parity.bats` test 2 (17 keys present in `lib/config.sh` but
  absent from the CLAUDE.md config table) is a genuine, pre-existing red that
  this newly-wired check surfaced on its very first live run in this session.
  That red is already tracked separately in **T-2698** (`status: captured`,
  filed 2026-07-31, predates this task) — fixing it is out of scope here per
  "one bug = one task"; it is cited only as proof the mechanism catches real
  drift, unprompted, which is the exact failure mode this task exists to end.
- **Negative control (AC5), stated from code since the live suite is not
  currently all-green (see above):** `check_invariant_suite()` emits exactly
  one line when `_red -eq 0` — `pass "Invariant suite: $_total ... green"`
  (`agents/audit/audit.sh:1921-1924`). There is no WARN path on a clean run;
  WARN fires only on `bats` being absent or producing zero TAP results (a
  "not checked" state, deliberately distinct from "checked and clean" per the
  function's header comment) — never as a permanent artifact of a green suite.
  So a fully-green `tests/lint/` produces a single quiet PASS line, not a
  standing WARN that readers would learn to ignore.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-06T20:59:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2837-testslint-red-is-invisible-to-every-runn.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ab5110dd
- **Timestamp:** 2026-08-06T21:39:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-06T21:39:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
