---
id: T-3416
name: "unit-suite pytest leg timed_out=true on 4 consecutive nightlies — root cause:
  subprocess-heavy audit.sh tests exhaust the reserved budget"
description: >
  unit-suite pytest leg timed_out=true on 4 consecutive nightlies — root cause: subprocess-heavy
  audit.sh tests exhaust the reserved budget

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: [T-3302, T-3411]
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
created: 2026-09-22T07:26:34Z
last_update: 2026-09-22T07:35:12Z
date_finished: 2026-09-22T07:35:12Z
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
  - ts: '2026-09-22T07:30:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=312,acs=3)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-22T07:30:26Z'
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

# T-3416: unit-suite pytest leg timed_out=true on 4 consecutive nightlies — root cause: subprocess-heavy audit.sh tests exhaust the reserved budget

## Context

T-3302's nightly `agents/audit/unit-suite.sh` runner (T-3359 budget split)
reserves `FW_UNIT_SUITE_PY_RESERVE` (default 1800s) for the pytest leg after
the bats leg's own budget is exhausted. Four consecutive nightlies
(2026-09-08 through -11, and again on 2026-09-22 per SEQ-T3411 round-1/round-2
review Δ2) recorded `pytest: files=208 tests=0 failed_count=0 exit=124` —
the reserve is being fully consumed with the parser never seeing a single
`pytest -q` summary line, so `fw audit`'s `check_unit_suite_report` correctly
falls back to its OBS-392 "COULD NOT DETERMINE" WARN (not a false PASS —
that part of the system already works). But the pytest half of `tests/unit`
has now gone unmeasured for at least 2 weeks running, which is the actual
problem Δ2 names.

**Root cause, localised this round (round 1 flagged this as "not yet
traced").** `grep -rl "audit.sh" tests/unit/test_*.py` finds 7 files that
subprocess-invoke the real `agents/audit/audit.sh`. Of these,
`test_audit_frontmatter_variants.py` spawns a **fresh** subprocess per test
(no shared fixture — 5 tests, 5 real invocations of
`bash agents/audit/audit.sh --section structure`), each against a scratch
`PROJECT_ROOT` that symlinks the test's `web/` back to the real repo (the
file's own docstring: "without this symlink the tests would pass by never
running the code under test"). Measured directly this round: one such
invocation against a **near-empty scratch root** (1 fixture task file) took
**185s wall-clock** (`time timeout 120 ... bash agents/audit/audit.sh
--section structure` — `real 3m5.283s`, the process outlived the 120s
`timeout` SIGTERM by 65s before actually exiting, itself worth noting).
5 such calls in one file ⇒ ~925s (>15 min), over half the 1800s reserve
consumed by ONE of 208 pytest files, before any of the other 207 run.
`test_t3061_audit_wiring.py` avoids this cost with a `scope="module"`
fixture (1 subprocess call shared across 5 tests) — the pattern
`test_audit_frontmatter_variants.py` should have used but structurally
cannot, because each of its 5 tests needs a *different* fixture corpus
(SILENT/LOUD/CLEAN/extensible-field variants), so a single shared call
would not exercise what the tests assert.

This is a distinct, additional layer to the already-tracked
`agents/audit/audit.sh` / `fw doctor` performance class (T-3083, T-3324,
T-3127) — those measure `fw doctor`'s specific slow checks (large-file gate,
bats --count, TermLink) and full-`fw audit` wall time; this is the same
underlying slowness showing up as a *second, previously unconnected*
symptom in the pytest test corpus itself, one this task's own scope does
not attempt to fix (fixing audit.sh's structure-section performance is
T-3083/T-3324/T-3127's job, and doing it here would be a second ungated
structural change stacked on this one — see Mandate "one lock at a time").

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Root cause reproduced independently: a single `bash agents/audit/audit.sh --section structure` invocation against a near-empty scratch `PROJECT_ROOT` (the exact harness `test_audit_frontmatter_variants.py` uses) measured at >120s wall-clock, confirming the per-call cost that makes 5 sequential calls in one pytest file consume the majority of the 1800s pytest reserve
- [x] Confirmed this is additive to (not a duplicate of) T-3083/T-3324/T-3127: those measure `fw doctor`/full-`fw audit` wall time; this is the same slowness surfacing as a second, previously-unconnected symptom inside the pytest test corpus, root-caused here for the first time (round 1 of SEQ-T3411 left Δ2 "not yet traced")
- [x] Confirmed the naive single-leg fix (raise `FW_UNIT_SUITE_PY_RESERVE` alone) is insufficient: the CURRENT `LATEST.yaml` shows the **bats** leg also exits 124 at its full 5400s budget (398/~2706+ bats tests done, not the ~5000+ a completed run would show) — both legs are underprovisioned against `TOTAL_TIMEOUT=7200`, not just pytest's carve-out, so a real fix needs a `TOTAL_TIMEOUT` increase whose correct size is not yet measured and touches nightly-cron scheduling policy (how long the nightly slot may run before conflicting with the next scheduled job) — out of this task's scope, surfaced as a Sovereign question below rather than decided here

## Verification

# AC1: reproduce the measured slow audit.sh call against a near-empty scratch root
# (the exact fixture pattern test_audit_frontmatter_variants.py uses). A 100s
# timeout is comfortably below the 185s measured this round — the point is to
# show it is NOT fast, not to pin the exact duration (which will vary by host).
rm -rf /tmp/t3416-verify && mkdir -p /tmp/t3416-verify/root/.tasks/active /tmp/t3416-verify/root/.tasks/completed && ln -sf "$(pwd)/web" /tmp/t3416-verify/root/web && printf -- '---\nid: T-9999\nname: x\ndescription: x\nstatus: started-work\nworkflow_type: build\nowner: agent\nhorizon: now\ncreated: 2026-01-01T00:00:00Z\nlast_update: 2026-01-01T00:00:00Z\n---\n\n# x\n' > /tmp/t3416-verify/root/.tasks/active/T-9999-x.md && timeout 100 env PATH=/usr/bin:/bin:/usr/local/bin HOME=/tmp/t3416-verify PROJECT_ROOT=/tmp/t3416-verify/root bash agents/audit/audit.sh --section structure >/tmp/t3416-verify/out.log 2>&1; test $? -eq 124

# AC2: confirm test_audit_frontmatter_variants.py has no shared (module/session-scoped)
# fixture around its audit.sh subprocess calls — each of its 5 tests pays the full cost.
! grep -q "fixture(scope=" tests/unit/test_audit_frontmatter_variants.py

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

**Symptom:** `.context/audits/unit-suite/LATEST.yaml` reports the nightly
pytest leg (208 test files, 2790 tests) as `tests: 0, failed_count: 0,
exit: 124` on every nightly run for at least 2 weeks — the pytest half of
`tests/unit` is effectively unmeasured, even though `fw audit`'s own
`check_unit_suite_report` correctly WARNs "COULD NOT DETERMINE" rather than
falsely reporting green (OBS-392/L-622 already handles that half correctly).

**Root cause:** `tests/unit/test_audit_frontmatter_variants.py` spawns a
real subprocess (`bash agents/audit/audit.sh --section structure`) per test,
5 times, with no shared fixture — each call measured at ~185s wall-clock
against even a near-empty scratch root, because the check walks the real
repo's `web/`/`lib/` trees through a symlink the test needs to exercise the
real code path. ~925s (>15 min) of the 1800s pytest reserve is consumed by
one of 208 test files before the other 207 get any budget at all. Separately,
the **bats** leg (5400s budget) also exits 124 on the same nightly run — so
even redirecting more of `TOTAL_TIMEOUT` to pytest would starve bats further
rather than fixing anything; the corpus as a whole no longer fits
`FW_UNIT_SUITE_TIMEOUT`'s default 7200s envelope.

**Why structurally allowed:** T-3359 (the budget-split fix) correctly
stopped leg 1 from starving leg 2 down to a 1-second floor, but it assumed
the two legs' *combined* true wall-clock time fits inside `TOTAL_TIMEOUT`.
Nothing measures or asserts that the split's two halves (5400s / 1800s) are
still sized correctly as the corpus grows — the same class of gap T-3127
names for the full-`fw audit` timeout budget, but for this runner's own
split, unmeasured until this round's direct timing.

**Prevention:** not fixed in this task (see Sovereign question below — the
correct `TOTAL_TIMEOUT` value is not yet measured, and raising a nightly
cron job's wall-clock budget is a scheduling-policy call this task does not
make unilaterally). This task's contribution is the localisation itself:
round 1 of SEQ-T3411 left Δ2 "not yet traced"; it is now traced, measured,
and separated from the false lead of "maybe it's just the reserve split" —
the reserve split is necessary but not sufficient.

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

### 2026-09-22T07:26:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3416-unit-suite-pytest-leg-timedouttrue-on-4-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-69aa53be
- **Timestamp:** 2026-09-22T07:38:39Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Verification-level findings:**

  1. **decaying-task-path-ref** (partial, deterministic) @ Verification:line 5
     - evidence: `T-9999 no longer in active/ — rm -rf /tmp/t3416-verify && mkdir -p /tmp/t3416-verify/root/.tasks/active /tmp/t3416-verify/root/.tasks/completed && ln -sf "$(pwd)/web" /tmp/t3416-ve`

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`

### 2026-09-22T07:35:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
