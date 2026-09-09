---
id: T-3356
name: "T-1856 anchor-task audit tests: 4 reds + file exceeds 500s (runs live audit)
  — align to current contract, make hermetic"
description: >
  T-1856 anchor-task audit tests: 4 reds + file exceeds 500s (runs live audit) — align
  to current contract, make hermetic

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [agents/audit/audit.sh, lib/audit-anchor-task.sh, tests/unit/audit_anchor_task_existence.bats]
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
created: 2026-09-08T22:06:41Z
last_update: 2026-09-09T16:03:15Z
date_finished: 2026-09-09T16:03:15Z
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
  - ts: '2026-09-08T22:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=271,acs=6)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-08T22:15:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3356: T-1856 anchor-task audit tests: 4 reds + file exceeds 500s (runs live audit) — align to current contract, make hermetic

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Root cause of the 4 red tests in tests/unit/audit_anchor_task_existence.bats ("arc with nonexistent anchor_task → WARN", "arc without anchor_task → no warning", "anchor_task: null → silent", "mix of valid + orphan → only orphan warns") is diagnosed and recorded in ## RCA: stale-test-vs-contract-change, genuine code regression, or timeout artifact — with the evidence line
- [x] The tests pass green AND the whole file completes in under 120 seconds — if the slowness comes from invoking the full live audit, the tests are restructured to run the specific audit function/section against a hermetic fixture corpus (T-3326-sanctioned shape); if a code bug is found, it is fixed in the audit code with the contract preserved
- [x] `bats tests/unit/audit_anchor_task_existence.bats` fully green, wall-clock recorded in Updates
- [x] Scope: tests/unit/audit_anchor_task_existence.bats, and agents/audit/ or lib/ audit code ONLY if a genuine code bug is proven (state which in RCA)

### Human
<!-- Criteria requiring human verification. Not blocking. -->
- [ ] [REVIEW] The audit.sh extraction is the right call, and the Sovereign question it surfaces is correctly deferred
  **Steps:**
  1. Run: `bin/fw task review T-3356`
  2. Read the RCA "Scope note (AC4)" paragraph — agents/audit/audit.sh was modified as a behaviour-preserving extraction, not a bug fix. AC2 asked for it; AC4 restricts it. Confirm that disposition is acceptable.
  3. Read the RCA "SURFACED, NOT FIXED" paragraph — decide whether `--section structure` embedding a 188s nested `bats tests/lint/` run should be changed (it is the dominant term in the T-3302 nightly timeout).
  **Expected:** the extraction stands, and the nested-suite question is either accepted as a follow-up task or ruled out of scope.
  **If not:** say which of the two you disagree with; the extraction is revertible from `agents/audit/audit.sh` history plus `lib/audit-anchor-task.sh`.

## Verification

start=$(date +%s); timeout 200 bats tests/unit/audit_anchor_task_existence.bats > /tmp/.t3356.out 2>&1; rc=$?; el=$(( $(date +%s) - start )); echo "elapsed=${el}s rc=$rc"; [ "$rc" -eq 0 ] && [ "$el" -lt 120 ]
! grep -q "^not ok" /tmp/.t3356.out
test "$(grep -c "# skip" /tmp/.t3356.out)" -eq 0
bash -n lib/audit-anchor-task.sh
bash -n agents/audit/audit.sh
bin/fw vendor self --check


# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
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
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
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

## RCA

**Symptom:** the T-3302 nightly unit-suite runner reported 4 of the 5 tests in
`tests/unit/audit_anchor_task_existence.bats` as failures, and the file ran past 500s.

**Root cause: timeout artifact — NOT a stale test, NOT a code regression.** Measured, not inferred:

- `audit.sh` *does* honour an exported `PROJECT_ROOT` (scratch run printed `Project: /tmp/tmp.lDMdT7mUnN`)
  and *does* emit the anchor warning. The fixtures and assertions were correct all along.
- `audit.sh --section structure` nevertheless exceeded 180s against an essentially EMPTY fixture
  corpus (1 arc, 0 tasks) and returned rc=124.
- Cause located: `check_invariant_suite` (`agents/audit/audit.sh`, inside the
  `should_run_section "structure"` block opened at line 807) runs `timeout 300 bats tests/lint/`
  from `FRAMEWORK_ROOT` on **every** `--section structure` invocation. Measured wall-clock of that
  nested suite: **188s** (108 tests, 0 reds — it is not failing, only expensive).
- Each of the 5 tests drove a full `--section structure`, so the file paid >= 5 x 188s ~ 940s in
  nested suite alone. Under the runner the tests were killed mid-run, `run` captured status 124,
  and `[ "$status" -le 1 ]` failed. Test 1 (happy path) "passed" only because its assertion is
  satisfiable against the *real* corpus — one false green sitting beside four false reds.

**Why structurally allowed:** the T-1856 rule is ~20 lines of inline top-level code inside a
~2400-line section. There was no way to exercise the rule without executing everything else in
that section, including a nested test suite. The cost of testing the rule was entirely unrelated
to the rule.

**Prevention:** detection extracted to `lib/audit-anchor-task.sh` (`anchor_task_scan`) and
exercised directly — 9 tests, 0s. Two wiring tests pin that `audit.sh` still sources and calls it,
so the extraction cannot decay into a detector nobody delivers (the exact T-3302 class). Both
controls were demonstrated rather than assumed: breaking detection turns tests 3 and 6 red;
orphaning the call turns test 8 red.

**Scope note (AC4).** `agents/audit/audit.sh` WAS modified — as the behaviour-preserving extraction
AC2 requires ("restructured to run the specific audit function/section against a hermetic fixture
corpus"), NOT as a bug fix. No genuine bug was found in the anchor rule; it was correct throughout.
AC2 and AC4 are in mild tension here and this note records the disposition rather than hiding it.
End-to-end equivalence verified: a real audit over a fixture corpus still emits
`[WARN] Arc 'orphan' anchor_task 'T-99999' not found in .tasks/{active,completed}/` verbatim, and
still does not flag the valid anchor `T-2222`.

**SURFACED, NOT FIXED — Sovereign question (see ## Recommendation):** that `--section structure`
embeds a 188s nested `bats tests/lint/` run, executed from `FRAMEWORK_ROOT` irrespective of
`PROJECT_ROOT`, is a separate structural defect with consequences beyond this task: (a) it is the
dominant term in the T-3302 nightly 7200s timeout, because every `tests/unit` file that invokes the
audit multiplies it; (b) for a *consumer* project audit it reports on the framework's own tests
under the consumer's banner (project-shape conflation, arc-004 class). Changing when the invariant
suite runs alters the audit's reporting contract (T-2837, T-3105) and could silence a real signal,
so it is an operator call, not an agent one. Deliberately untouched here.


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

**Recommendation:** GO

**Rationale:** The four reds were timeouts, not failures — proven, not asserted. The
anchor rule was correct throughout and its emitted WARN is byte-identical before and
after. What changed is that the rule is now reachable without paying for a nested
188s suite: the file went from >500s-and-timing-out to 9/9 green in 0s. Both controls
were run, so the suite is known to discriminate rather than merely to pass. The one
judgement call worth your eye is that `agents/audit/audit.sh` was touched — AC2 asked
for the restructure, AC4 restricts audit-code changes to proven bugs, and this is
neither a bug fix nor a behaviour change. I recorded that tension in the RCA rather
than resolving it silently.

**Evidence:**
- `bats tests/unit/audit_anchor_task_existence.bats` -> 9/9 ok, 1s wall-clock (was >500s, killed under the nightly runner).
- Root cause located at `agents/audit/audit.sh` `check_invariant_suite`: `timeout 300 bats tests/lint/` runs inside `--section structure`. Measured 188s, 108 tests, 0 reds.
- `audit.sh --section structure` returns rc=124 against an EMPTY fixture corpus (1 arc, 0 tasks) — the failure is independent of corpus size.
- End-to-end equivalence: real audit still emits `[WARN] Arc 'orphan' anchor_task 'T-99999' not found in .tasks/{active,completed}/` and does not flag valid anchor `T-2222`.
- Controls: detection broken -> tests 3,6 red; detector orphaned -> test 8 red. Neither is a tautology.
- `bin/fw vendor self --check` clean; fabric card registered for the new lib.

**Open for you (not decided here):** `--section structure` embedding a 188s nested
`bats tests/lint/` run, executed from `FRAMEWORK_ROOT` regardless of `PROJECT_ROOT`,
is the dominant term in the T-3302 nightly 7200s timeout and misreports framework
tests under a consumer project's banner. Changing it alters the audit reporting
contract (T-2837, T-3105), so it is your call, not mine.


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

### 2026-09-09 — T-3356 restructure landed

- **Wall-clock (AC3):** `bats tests/unit/audit_anchor_task_existence.bats` -> **9/9 ok in 0s**
  (previously >500s and timing out under the nightly runner). Measured with `date +%s` either side.
- **Measurements taken:** nested `bats tests/lint/` = 188s / 108 tests / 0 reds;
  `audit.sh --section structure` on an empty fixture corpus = rc=124 at 180s.
- **Files:** new `lib/audit-anchor-task.sh`; `agents/audit/audit.sh` inline block replaced by a
  source + adapter (warn/pass_over emission unchanged); test file rewritten hermetic 5 -> 9 tests.
- **Controls run:** detection broken -> tests 3,6 red; detector orphaned -> test 8 red.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8dbe8d1a
- **Timestamp:** 2026-09-09T16:03:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-09T16:03:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
