---
id: T-3209
name: "doctor blames the operator when the loop ledger is missing but claude-fw is
  running"
description: >
  doctor blames the operator when the loop ledger is missing but claude-fw is running

status: work-completed
workflow_type: build
arc_id: continuous-run
owner: agent
horizon: null
tags: []
components: [bin/fw]
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
created: 2026-08-28T15:39:18Z
last_update: 2026-08-28T15:48:53Z
date_finished: 2026-08-28T15:48:53Z
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
  - ts: '2026-08-28T15:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=252,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-28T15:45:18Z'
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

# T-3209: doctor blames the operator when the loop ledger is missing but claude-fw is running

## Context

`fw doctor` inferred a CAUSE from the absence of a file. Its missing-ledger branch
said, unconditionally, *"Expected when the session was not launched via claude-fw.
Launch with: claude-fw"* — a claim that is false whenever a wrapper is actually
running, and advice to do the thing the operator is already doing.

Found while re-measuring T-3181's IW-6 against the ledger T-3206 shipped. The live
supervisor (pid 1851680) armed 29h before the start event existed, so it never wrote
a line, and doctor read that silence as operator error.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw doctor`'s missing-ledger branch discriminates on whether a `claude-fw` wrapper for THIS project is actually running, instead of asserting a cause from the absence of a file alone
- [x] When a wrapper IS running with no ledger, the output is a WARN naming the pid and BOTH causes (armed before the start event shipped; recorder could not write), and does not tell the operator to launch what is already running
- [x] When no wrapper is running, the existing SKIP guidance is preserved and now states that absence explicitly rather than leaving it inferred
- [x] The pid match is scoped to `$PROJECT_ROOT` — a `claude-fw` supervising a different project on the same host does not satisfy the check
- [x] Tests cover all three states, and each test is mutation-tested: a specific mutation is named per test and is recorded as having reddened it
- [x] A CONTROL test proves the suite can fail — it is not green because it asserts nothing

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
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.


# T-3209: all three states + scoping + robustness. Assertion is the ONLY command on
# each line — P-011 judges `cmd1; cmd2` only on cmd2 (T-3203).
bats tests/unit/t3209_loop_ledger_cause_attribution.bats
# T-3206 regression: this task touched only the else-branch of its block.
bats tests/unit/t3206_continuous_run_ledger.bats
# The shipped block must still parse.
bash -n bin/fw
# The no-wrapper branch must state the absence rather than leave it inferred.
grep -q 'No claude-fw wrapper is running for this project' bin/fw
# The pid match must stay scoped to this project.
grep -q 'grep -F "$PROJECT_ROOT"' bin/fw

## RCA

**Symptom.** With a `claude-fw` wrapper supervising this very session, `fw doctor`
reported the continuous-run loop as never recorded and told the operator to launch
`claude-fw`.

**Root cause.** The branch had one arm where the state space has two. Absence of a
ledger line was treated as evidence of absence of a loop. It is not: it is evidence
of absence of a *written line*, which has two causes with opposite remedies —

1. **transient** — the wrapper armed before T-3206 shipped the start event. Clears on
   the next restart. This is the state that surfaced it.
2. **permanent** — `_record_loop_event` is deliberately non-fatal (T-3206 pinned that
   in its own test 4), so a recorder that cannot write fails *silently* and lands in
   exactly this branch. Here the old message actively misdirects: it blames the
   operator for a tooling failure and sends them into a restart loop that cannot help.

**Why the framework allowed it (G-019).** T-3206 was written to kill a false green —
an absent log must not look like a healthy loop — and it succeeded at that. But it
closed the gap by *asserting* the benign explanation in prose rather than checking it.
The check that named the third state did not verify the state it named. Same family as
the arc's other findings, one level up: not a check that passes for the wrong reason,
but a check whose *explanation* is unverified.

**A defect in the first fix, found by mutation and worth recording.** The first
implementation matched `pgrep -af claude-fw | grep -F "$PROJECT_ROOT"`. That matched
any process whose command line merely *mentions* the wrapper — including this agent's
own `bash -c` shell, whose command text contained both strings. It reported 4 pids
where 2 exist, and it broke T-3206's test 5 by finding a "wrapper" for a bats
sandbox.

The tests did not catch it, and the reason is the lesson: **the suite faked `pgrep`,
so it never saw a line shaped like a real one.** Mocking the data source removed the
exact failure mode. This is adjacent to the peer rule at chat-arc offset 689 — a guard
that reimplements the code it guards cannot detect that code being fixed; here, a test
that mocks the data source cannot detect the source behaving differently. The fix
matches on argv position via `ps -eo pid=,args=`, and the false positive is now a
regression test (11) with its positive control (12).

**Honest limit.** Test 11 does NOT redden under M4 (reversion to the `pgrep`
substring form), because that reversion bypasses the fake `ps` entirely and the test
passes vacuously. Tests 12 and 13 do redden, so the suite catches the reversion — but
not via the test that names it. Recorded rather than papered over.

**Prevention, not mitigation.** 13 tests, 5 mutations, each reddening a distinct
predicted set: M1 old message (2,4,5,6,7), M2 unscoped (8), M3 one cause only (6),
M4 substring matcher (2,5,6,12,13), M5 match-anywhere (11).

## Evolution

### 2026-08-28 — the third state was named but not verified
T-3182 killed the two-state false green (an absent log must not look like a healthy
loop). T-3206 added the third state and the arm-time `start` event. This task found
that the third state carried an *unverified explanation*: it told the operator why the
file was missing without checking. The arc's ratchet, one turn further — first the
state, then the state's cause.

### 2026-08-28 — a mocked data source hides the failure it was mocked for
The first fix used a substring match and the suite could not see it, because the suite
faked `pgrep`. Determinism was bought by removing the very behaviour under test. The
replacement fakes `ps` in its *real output shape*, and the false positive is pinned as
a regression test with a positive control beside it, so "never matches anything"
cannot masquerade as "never false-positives".

### 2026-08-28 — a tail is not a count
This task's regression check was first reported green off `tail -3`, which showed the
last three tests passing while test 5 failed above the fold. Counting (`grep -c '^ok'`
plus an explicit failure grep) is now how both suites are reported here.

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
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

### 2026-08-28T15:39:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3209-doctor-blames-the-operator-when-the-loop.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3119e787
- **Timestamp:** 2026-08-28T15:48:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-28T15:48:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
