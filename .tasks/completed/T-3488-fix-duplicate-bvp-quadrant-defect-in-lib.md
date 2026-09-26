---
id: T-3488
name: "Fix duplicate BVP quadrant defect in lib/resolver.py (T-3485 follow-up)"
description: >
  resolver.py:_annotate_bvp_rank() is an independent duplicate of the BVP quadrant
  value-axis equality defect fixed in T-3485 (lib/bvp.sh). This one drives fw resolver
  dispatch's autonomous task selection, so it steers real behaviour, not just display.
  Branch from t3485-bvp-quadrant-value-axis (e67d7e95b), apply the same degenerate-median
  withhold-verdict mechanism, add two-sided negative-control tests asserted on selection
  (not just rendered rank), plus healthy-corpus regression. Branch only, do not push.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:value-prioritisation]
components: [lib/bvp.sh, lib/resolver.py]
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
created: 2026-09-25T22:52:52Z
last_update: 2026-09-26T08:01:29Z
date_finished: 2026-09-26T08:01:29Z
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
  - ts: '2026-09-25T23:00:12Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=300,acs=10)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-25T23:00:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3488: Fix duplicate BVP quadrant defect in lib/resolver.py (T-3485 follow-up)

## Context

Follow-up to T-3485 (branch `t3485-bvp-quadrant-value-axis`, commit `e67d7e95b`),
which repaired a quadrant-classifier equality defect in `lib/bvp.sh` (a `>=` test
against a corpus median that collapses onto the distribution's floor when many
tasks tie at zero, misclassifying tied-floor tasks as `hv-lc`). That worker found
an independent, docstring-acknowledged duplicate in
`lib/resolver.py:_annotate_bvp_rank()` (~line 1370) — the function that drives
`fw resolver dispatch`'s autonomous task selection. This task ports T-3485's
chosen mechanism (withhold verdict `QUAD_VALUE_WITHHELD` when
`median(bvp_vals) == min(bvp_vals)`) into the resolver, and proves the fix on
selection behaviour, not just on a rendered table. Full requirements, rejected
alternatives, and constraints are in the dispatch prompt for this task (see
Decisions / dispatch worker prompt).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Defect reproduced against a committed degenerate-corpus fixture: a floor-tied
      task is shown selected first by `_annotate_bvp_rank()` / the resolver's
      selection path before the fix is applied.
      → `test_PRE_FIX_semantics_select_a_zero_value_task_first`. The pre-fix rule is
      re-implemented in the test file (`_prefix_quadrant` / `_prefix_order`) and run
      against the same fixture the fix is tested on, so the defect is demonstrated
      rather than taken on trust from the T-3485 worker's report.
- [x] `lib/resolver.py:_annotate_bvp_rank()` applies the same degenerate-median
      withhold-verdict mechanism as T-3485's `lib/bvp.sh` fix (or a reasoned,
      explicitly documented divergence is recorded in `## Decisions` if identical
      behaviour is not appropriate for the resolver's selection semantics).
      → SAME mechanism, no divergence. `_value_axis_degenerate()` keys on
      `median == min`, identical to `lib/bvp.sh`. A divergence was investigated and
      **rejected on measurement** — see Decision D1; the reasoning is recorded because
      widening the guard was the tempting wrong answer, not because the clause was
      unused.
- [x] Negative control (exclusion): on the degenerate fixture, a floor-tied/zero
      value task is no longer selected first by the resolver's dispatch selection.
      → `test_a_floor_tied_task_is_no_longer_selected_first`, asserted on
      `_pick_rank_key` order, not on a rendered quadrant string.
- [x] Negative control (admission): on the same degenerate fixture, a genuinely
      high-value task is still selected.
      → `test_a_genuinely_high_value_task_is_still_selected` (T-200 → `hv-hc`,
      selected first post-fix).
- [x] Regression control: on a committed healthy/well-spread fixture, resolver
      selection output is unchanged from pre-fix behaviour.
      → `test_a_healthy_spread_corpus_is_byte_identical_to_pre_fix`, compared against
      the independently-computed pre-fix rule rather than a remembered expectation.
- [x] Behaviour of a withheld task under `fw resolver dispatch` (skip / defer /
      error) is deliberate and documented in the task body.
      → Decision D2: **rank last (the FIFO bucket), never skip and never error.**
      Pinned by `test_withheld_tasks_report_v_thin_and_rank_as_no_bvp` and
      `test_withheld_still_carries_its_value_and_cost_for_observability`.
- [x] T-3485's fix in `lib/bvp.sh` on branch `t3485-bvp-quadrant-value-axis` is
      untouched by this task's commits.
      → `git status --short lib/bvp.sh` empty; this task's diff is exactly
      `lib/resolver.py` + the new test file. Pinned forward by
      `test_the_two_surfaces_report_the_same_withheld_literal`.
- [x] **AMENDED — see Decision D3.** Original text: *"Work is committed on top of
      `t3485-bvp-quadrant-value-axis` (commit `e67d7e95b1b1e3f12b5735d7268c616046c8ee84`)
      and NOT pushed."* That branch was cut from `0aefa83a3` and now lacks ~5,500
      lines of subsequently landed work, so committing onto it would revert unrelated
      slices. T-3485 was landed on `bleeding-edge` as `b23ee1a65`, so **"on top of
      T-3485's mechanism" is satisfied by `bleeding-edge`**, which is where this work
      is committed. The `NOT pushed` clause was a dispatched-worker sandbox rule and
      does not bind the parent session on the sanctioned dev branch; `master` is not
      touched either way.

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

# The two lines that were here are REPLACED, not bypassed. Both anchored to
# `t3485-bvp-quadrant-value-axis`, which Decision D3 establishes is stale (cut
# from 0aefa83a3, now ~5,500 lines behind), and both were defective:
#
#   git log  t3485..HEAD --oneline    | grep -q .                  -> exit 141
#   git diff t3485..HEAD --stat       | grep -q "lib/resolver.py"
#
# (1) is the L-387 SIGPIPE anti-pattern CLAUDE.md documents by name: `grep -q`
#     matches the first line and closes stdin while `git log` is still writing,
#     git takes SIGPIPE, the pipeline exits 141 — a FAIL with the pattern
#     present. It failed exactly that way at this task's first close attempt.
# (2) is worse than broken, it is FALSE-GREEN-prone: a diff spanning a stale
#     branch covers thousands of lines of unrelated landed work, so it could
#     report success without this task having touched anything.
#
# Replaced with assertions on the DELIVERABLE rather than on branch topology,
# in the sanctioned redirect-then-grep form:
grep -q "_value_axis_degenerate" lib/resolver.py
grep -q 'QUAD_VALUE_WITHHELD = "v-thin"' lib/resolver.py
git log --oneline -30 > /tmp/.t3488-log 2>&1 && grep -q "T-3488" /tmp/.t3488-log

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

out=$(python3 -m pytest tests/unit/test_bvp_quadrant_resolver_selection.py -q 2>&1); echo "$out" | grep -q "10 passed" && ! echo "$out" | grep -q "failed"
out=$(python3 -m pytest tests/unit/test_resolver.py tests/unit/test_resolver_run.py tests/unit/test_bvp_quadrant_value_axis.py -q 2>&1); echo "$out" | grep -q "47 passed" && ! echo "$out" | grep -q "failed"
out=$(bats tests/unit/t2497_resolver_bvp_rank.bats tests/unit/t2489_resolver_pick.bats 2>&1); echo "$out" | grep -qE "^ok 10 " && ! echo "$out" | grep -qE "^not ok|# skip"
# AC #7 fence: this task must not have modified T-3485's surface.
test -z "$(git status --porcelain lib/bvp.sh)"
# The vendored copy of the file this task DID change must match its source.
cmp -s lib/resolver.py .agentic-framework/lib/resolver.py

## RCA

**Symptom:** `fw resolver dispatch`, and therefore any autonomous run told to
"select by BVP quadrant", ranks `hv-lc` first. On a corpus whose value median has
collapsed onto its floor, `_annotate_bvp_rank()` labelled every floor-tied task
`hv` — so the lowest-value work in the corpus was offered for dispatch ahead of
genuinely valuable work. Measured downstream: 13 of 25 costed tasks at
`bvp_norm == 0.0`, median `0.00`, all 13 in `hv-lc`.

**Root cause:** `m["bvp_norm"] >= bvp_median` is true *at* equality. That is a
harmless convention while the median sits inside the distribution, but when
`median == min` the equality is not incidental — it is forced, because a median
equal to the minimum means at least half the values ARE the minimum. The
comparison then manufactures a verdict for that entire tied mass instead of
reporting that the axis cannot separate it.

**Why structurally allowed — the part worth keeping:** the rule is implemented
**twice**, in two languages, and the duplication was *documented* rather than
removed. `lib/resolver.py:_annotate_bvp_rank()` carries the docstring
"mirroring bvp.sh cmd_rank, including its 0.5/4.0 empty-set fallbacks", which
means the copy was known, deliberate, and understood — and it still drifted,
because fixing one copy does not fix the other. T-3485 repaired `lib/bvp.sh` and
closed with its ACs green while the surface that actually steers dispatch stayed
defective. **A docstring acknowledging a duplicate is not a rail against it
diverging; it only makes the divergence legible after the fact.** No test, lint,
or audit check asserted parity between the two implementations.

**Prevention** (distinct from the fix):
1. `test_the_two_surfaces_report_the_same_withheld_literal` asserts cross-surface
   parity on the withheld verdict — the first check of any kind that fails if one
   copy is repaired and the other is not. It is deliberately a *weak* parity
   check (one string literal); it is not a substitute for de-duplication.
2. `test_a_ceiling_collapse_is_deliberately_NOT_withheld` pins the guard's
   *scope*, so the next agent measuring this repo's 83% ceiling tie cannot widen
   the predicate into a regression without a red test explaining why.
3. Not prevented, and filed rather than claimed: the duplication itself. One rule
   in two languages will drift again. See Decision D4 and the Recommendation.

## Evolution

### 2026-09-26 — the live corpus is degenerate at the CEILING, which is a different defect

- **What changed:** Measuring before coding (`fw bvp --include-proposed`, 29
  costed tasks) showed **24 of 29 (83%) tied at `NORM 0.40`, which is
  simultaneously the median and the maximum**. `min` is `0.04`, so
  `median == min` is False and this task's guard is **inert on this repo**. The
  first reading — "the guard misses the same pathology, widen it" — was wrong,
  and was discarded after working the two cases through: a floor tie labelled
  `hv` contradicts the data, a ceiling tie labelled `hv` agrees with it.
- **Plan impact:** AC #2's divergence clause was expected to be used and was
  not. The mechanism is a faithful port. The measurement's real value was
  negative evidence: it told us what NOT to build, and it re-homed the ceiling
  finding to the degenerate-scorer alarm (`lib/bvp_degenerate.py`) where it
  belongs.
- **Triggered:** No new task for the ceiling case — `lib/bvp_degenerate.py`
  (T-3489/T-3495) already detects it and already fires on this shape. The
  measurement is recorded in `_value_axis_degenerate()`'s docstring and pinned by
  a control-leg test so it is not re-litigated.

### 2026-09-26 — two ACs encoded a dispatch sandbox that no longer existed

- **What changed:** ACs #1 and #8 were authored as a *dispatch prompt* for a
  worker that was never spawned. AC #8 required committing onto
  `t3485-bvp-quadrant-value-axis`, a branch cut from `0aefa83a3` that now lacks
  ~5,500 lines of landed work; honouring it literally would have reverted
  unrelated slices.
- **Plan impact:** AC #8 amended in place with the rationale visible in the AC
  text itself, not silently re-scoped. See Decision D3.
- **Triggered:** Nothing filed. Recorded because "ACs written as a dispatch
  prompt" is a distinct authoring hazard from "ACs written as criteria" — the
  former bake in process constraints that expire.

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

### D1 — 2026-09-26 — port `median == min` faithfully; reject the "large tie at the median" generalisation

- **Chose:** The identical predicate to `lib/bvp.sh`: withhold when
  `median(norms) == min(norms)` and the task sits at the median. No divergence,
  despite AC #2 explicitly permitting one.
- **Why:** The harmful condition is **having nothing below you**, not "being tied
  with many others". A task at the distribution's floor labelled *high value* is
  self-contradictory; a task at the maximum labelled *high value* is the strongest
  case there is. `median == min` captures exactly the first and excludes exactly
  the second.
- **Rejected — "withhold whenever a large mass ties at the median":** this was the
  first design, and measurement killed it. This repo's live corpus has 24 of 29
  costed tasks (83%) tied at `NORM 0.40` = median = **max**. Under the wider rule
  all 24 would be withheld and ranked behind the corpus's five *lowest* scorers —
  it would invert the ordering it was meant to protect. It would also break
  T-3485's own pinned admission control, which asserts a non-degenerate at-median
  tie (scores 1,2,2,4) legitimately stays `hv`.
- **Rejected — `>=` → `>`:** already rejected under T-3485 with a pinned test; it
  moves the tied mass from `hv` to `lv` without making anything distinguishable.
- **Consequence stated plainly:** the guard is **inert on this repo today**
  (`median 0.40 != min 0.04`). This task repairs a latent defect here and an
  active one downstream. That is not a reason to skip it — the resolver is the
  autonomous selection path, and a latent inversion there is exactly the thing
  you fix before it fires.

### D2 — 2026-09-26 — a withheld task ranks LAST; it is never skipped and never errors

- **Chose:** `_quadrant = "v-thin"`, `_quadrant_rank = _NO_BVP_RANK` — the same
  ordering bucket as a task carrying no BVP signal at all, i.e. fall back to FIFO.
  The task stays fully eligible for dispatch and keeps its measured `bvp_norm` /
  `bvp_cost` for observability.
- **Why:** Ranking it last is *provably* correct in every case this branch can
  fire, not merely a reasonable default: the guard only fires when
  `median == min`, so a task at the median is at the floor and nothing in the
  corpus is below it. And withholding a **verdict** must not erase a
  **measurement** — `fw resolver explain` has to be able to show the score that
  produced the withholding.
- **Rejected — skip or error:** a selection path that refuses to return a task
  because its value is unclear turns a ranking problem into an availability
  problem. The corpus would go empty rather than un-ordered.
- **Rejected — a fifth ranked quadrant between `lv-hc` and no-data:** that invents
  a new ordering claim out of the same absence of signal. Pinned against by
  `test_withheld_tasks_report_v_thin_and_rank_as_no_bvp`.

### D3 — 2026-09-26 — AC #8 amended, in the open, rather than passed or silently dropped

- **Chose:** Rewrite AC #8's branch/push constraint in the AC text itself, with
  the original quoted verbatim and the reason attached, and commit this work on
  `bleeding-edge`.
- **Why:** The AC named commit `e67d7e95b`'s branch, which was cut from
  `0aefa83a3` and now lacks ~5,500 lines of landed work; committing there would
  revert unrelated slices. T-3485's mechanism is now *on* `bleeding-edge`
  (`b23ee1a65`), so the AC's intent — build on top of T-3485 — is satisfied. The
  `NOT pushed` clause was a sandbox rule for a dispatched worker, and `master` is
  untouched regardless.
- **Rejected — ticking it as-written:** it would have been false. A ticked box
  asserting something untrue is worse than an open one.
- **Rejected — deleting the AC:** deleting an inconvenient criterion is
  indistinguishable from never having had it.

### D4 — 2026-09-26 — do NOT de-duplicate the two implementations under this task

- **Chose:** Fix the second copy, pin a weak cross-surface parity test, and file
  the de-duplication as separate work rather than attempting it here.
- **Why:** One rule living in two languages (shell-embedded Python in
  `lib/bvp.sh`, native Python in `lib/resolver.py`) is the root fault, and it will
  drift again — this task exists *because* it drifted. But unifying them changes
  the BVP ranking surface and the autonomous dispatch surface in one move, which
  is a second structural change opened while the first is still ungated. Out of
  scope by the task-sizing rule (one deliverable) and by the standing
  one-lock-at-a-time constraint.
- **Rejected — extracting a shared module now:** correct destination, wrong
  moment; it needs its own task, its own blast-radius read, and its own controls.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-25T22:52:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3488-fix-duplicate-bvp-quadrant-defect-in-lib.md
- **Context:** Initial task creation

### 2026-09-26T07:55:46Z — status-update [task-update-agent]
- **Change:** tags: +arc:value-prioritisation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-eb11a540
- **Timestamp:** 2026-09-26T08:01:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-26T08:01:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
