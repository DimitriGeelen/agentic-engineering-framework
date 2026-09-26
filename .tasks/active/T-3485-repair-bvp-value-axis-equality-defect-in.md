---
id: T-3485
name: "Repair BVP value-axis equality defect in quadrant classifier"
description: >
  Repair BVP value-axis equality defect in quadrant classifier

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
created: 2026-09-25T22:29:35Z
last_update: 2026-09-25T22:29:35Z
date_finished: null
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
---

# T-3485: Repair BVP value-axis equality defect in quadrant classifier

## Context

Downstream operator authorised a narrow repair: `lib/bvp.sh`'s `quadrant()` uses
`bvp_norm >= bvp_median` for the value axis, which is true at equality. In a live
project 13/25 costed tasks score `bvp_norm == 0.0`, the median is also `0.00`
(zero-value work is over half the corpus), and every one of those 13 lands in
`hv-lc` — the top-priority quadrant. Scope is the value-axis equality defect
only: no weight/driver retuning, no cost-axis fix (only a report on the
symmetric `cost <= cost_median` defect). Naive `>` swap is explicitly
disallowed without a two-sided negative control, since it just moves the
degeneracy from "everything hv" to "nothing hv" on a zero-median corpus.
Dispatch prompt (verbatim constraints): branch only, no push, no `--force`,
no worktree by default, re-derive the defect before editing.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Defect reproduced via a committed pytest fixture (not live project state) that shows a zero-value/zero-median corpus landing entirely in `hv-lc` under current `>=` semantics
- [x] Mechanism chosen and implemented in `lib/bvp.sh` quadrant()/cmd_rank(), with rationale recorded in `## Decisions` for why the naive `>=`→`>` swap was rejected
- [x] Negative control: fixture proves a task scoring exactly at a degenerate median (zero-value, zero-median) no longer classifies as `hv`
- [x] Positive control: fixture proves a genuinely high-value task (clearly above median) still classifies as `hv` under the new mechanism
- [x] Fixture proves behaviour on a healthy, well-spread (non-degenerate) corpus is unchanged (or the change there is explicitly justified)
- [x] Cost-axis equality (`cost <= cost_median`) investigated and documented as a finding (NOT fixed) in this task's Updates/Recommendation
- [x] New tests committed under `tests/unit/`, passing via `python3 -m pytest`
- [x] Change committed to a dedicated branch, NOT pushed, NOT on bleeding-edge

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

out=$(python3 -m pytest tests/unit/test_bvp_quadrant_value_axis.py -q 2>&1); echo "$out" | grep -q "5 passed" && ! echo "$out" | grep -q "failed"
out=$(python3 -m pytest tests/unit/test_bvp_status_filter.py tests/unit/test_bvp_cli_rank_proposed.py tests/unit/test_bvp_cli_arcs_rollup.py tests/unit/test_bvp_blueprint_cost.py tests/unit/test_bvp_scatter_arc_mode.py tests/unit/test_bvp_signals_rollup.py -q 2>&1); echo "$out" | grep -q "59 passed" && ! echo "$out" | grep -q "failed"

## RCA

**Symptom:** `fw bvp rank --quadrant hv-lc` (downstream project) returned 25 costed
tasks, BVP median 0.00, 13/25 scoring exactly 0.00, all 13 classified `hv-lc` —
the top-priority quadrant. Reproduced locally with a 25-task fixture (13 zero,
12 spread 1-5): before the fix, all 25 landed `hv-lc`; the defect is exact and
general, not project-specific.

**Root cause:** `lib/bvp.sh:quadrant()` used `bvp_norm >= bvp_median` (inclusive
at equality). This is correct while the median sits mid-distribution — ties AT
a genuine median legitimately belong to whichever side inclusive comparison
puts them. It becomes a defect specifically when the median itself has
collapsed onto the corpus floor: `median == min(bvp_vals)` is only possible
when >=50% of the corpus is tied at the theoretical minimum (unscored/all-zero
tasks read as raw BVP 0). In that shape, `>=` isn't resolving a real tie — it
is manufacturing a verdict for a majority-degenerate axis and calling it
"high value."

**Why structurally allowed:** `quadrant()` had no way to express "the axis
cannot support a verdict here" — only four positive quadrant labels plus `-`
for genuinely missing data. A degenerate-but-present median (0.00 is a valid
float, not None) passed every existing check. No test in the corpus pinned
median/tie behaviour at all — `tests/unit/test_bvp_*` covered filtering,
proposed-score fallback, and cost composite math, never the quadrant boundary
itself (confirmed via search prior to this fix: zero hits for `quadrant(` in
tests/).

**Prevention:** `tests/unit/test_bvp_quadrant_value_axis.py` (5 tests) pins:
degenerate-median exclusion, degenerate-median admission of a real high
scorer, a live demonstration that the naive `>=`→`>` swap would wrongly
exclude a genuine (non-degenerate) at-median tie, and inertness on a healthy
well-spread corpus. This is a repair of `lib/bvp.sh` only — see Recommendation
for two related findings (cost-axis symmetry; a second, independent copy of
this exact defect in `lib/resolver.py`) that are reported, not fixed, because
they are outside this task's authorized scope.

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

**Recommendation:** GO (for `lib/bvp.sh`, this task's authorized scope) — with
two findings for separate operator decisions.

**Rationale:** The defect reproduced exactly as described (fixture: 25 tasks,
13 zero-value, median 0.00, all 13 pre-fix in `hv-lc`). The chosen mechanism
(withhold on degenerate-median tie, `QUAD_VALUE_WITHHELD='v-thin'`) passes
both required negative controls — exclusion of the degenerate tie mass,
admission of a genuinely high-value task in the same corpus — and is proven
inert on a healthy well-spread corpus (byte-identical quadrant assignments,
hand-verified against a live run of the fixture). The naive `>=`→`>` swap was
tested and shown to fail the admission side on a non-degenerate at-median tie.
5 new tests pass; the full pre-existing BVP suite (bvp_status_filter,
bvp_cli_rank_proposed, bvp_cli_arcs_rollup, bvp_blueprint_cost,
bvp_scatter_arc_mode, bvp_signals_rollup — 59 tests — plus
bvp_auto_promote{,_enable}, t2477_bvp_yaml_timestamp_fallback,
t2332_bvp_propose_queue, t2497_resolver_bvp_rank bats suites) is unaffected.

**Evidence:**
- Fixture reproduction: `tests/unit/test_bvp_quadrant_value_axis.py` (5/5 pass)
- Full BVP pytest suite: 59/59 pass (unchanged by this fix)
- BVP-adjacent bats suites: `bvp_auto_promote.bats` (7/7), `bvp_auto_promote_enable.bats`
  (7/7), `t2477_bvp_yaml_timestamp_fallback.bats` (3/3), `t2332_bvp_propose_queue.bats`
  (6/6), `t2497_resolver_bvp_rank.bats` (5/5) — all pass
- `fw bvp --help` output unaffected (checked manually)

**Finding 1 — cost-axis equality (reported, not fixed, per explicit scope
boundary):** `lib/bvp.sh:quadrant()`'s `lc = cost <= cost_median` has the
identical equality-at-median shape as the value axis this task repairs. A
corpus where cost is constant (or where a large tied mass sits at the cost
median) reads every one of those tasks as `lc` for the same structural
reason the value axis over-read `hv`. This task's own reproduction fixture
demonstrates it incidentally: all 25 fixture tasks share `cost=2.0`, so
`cost_median=2.0` and every task reads `lc` regardless of value — visible in
the pre-fix repro output (`docs/reports/T-3485-bvp-quadrant-value-axis-repair.md`).
The requesting operator's own downstream project has a named prior instance
of this (their PL-025: constant cost → median → every task reads "low cost").
The same `degenerate-median` mechanism used here for the value axis would
generalise to the cost axis (`cost_median == min(cost_vals)`), but that is an
operator decision, not this task's authorization.

**Finding 2 — `lib/resolver.py` carries an independent, undocumented-as-such
duplicate of the exact same defect, and it is the part that actually drives
autonomous task selection.** `lib/resolver.py:_annotate_bvp_rank()` (line
~1370) reimplements the identical `("hv" if m["bvp_norm"] >= bvp_median else
"lv") + "-" + ("lc" if cost <= cost_median else "hc")` logic — its own
docstring says "mirroring bvp.sh cmd_rank." This function feeds
`fw resolver dispatch`'s task auto-selection (`_QUADRANT_RANK`, HV-LC ranked
first) — i.e. it is precisely the mechanism the dispatch prompt's symptom
paragraph describes ("An autonomous run told to 'select by BVP quadrant, Q1
first to exhaustion' is steered directly into it"). **Patching only
`lib/bvp.sh` (this task) repairs the CLI ranking/display surface but leaves
the actual autonomous-dispatch selector carrying the unrepaired defect.** Not
fixed here — `lib/resolver.py` was never named in this task's authorization,
and duplicating the fix there without being asked would be exactly the scope
creep the prompt warns against — but this is very likely the operator's next
priority if the goal is to stop autonomous runs from being steered into
zero-value work, not just to fix what `fw bvp rank` prints.

## Decisions

### 2026-09-26 — value-axis equality mechanism

- **Chose:** withhold a verdict (`QUAD_VALUE_WITHHELD = 'v-thin'`) for tasks
  whose `bvp_norm` equals a *degenerate* median, where degenerate is defined
  as `median(bvp_vals) == min(bvp_vals)`. Mathematically this can only be true
  when at least `ceil(n/2)` values are tied at the floor, so the guard fires
  exactly on the shape the reported symptom describes and is provably inert
  otherwise. Implemented as an added `degenerate=False` kwarg on `quadrant()`
  (backward compatible — every existing call site not touched by this task
  keeps prior behaviour byte-for-byte) plus a one-line `value_axis_degenerate()`
  helper and an observability NOTE mirroring the existing cost-unknown
  disclosure block (T-3068's pattern), so a shrinking hv-lc count reads as
  "withheld", not "vanished".
- **Why:** the prompt's own framing is correct — the real question is not
  which side of the boundary ties fall on, it is whether a median sitting on
  a mass of ties can support a verdict at all. Withholding answers that
  question honestly. It also composes cleanly with the two required negative
  controls: a task AT the degenerate median is excluded from hv (Direction 1);
  a task clearly ABOVE the degenerate median is untouched by the guard and
  still reads hv normally (Direction 2, since the guard only fires on
  `bvp_norm == bvp_median`, not on the whole `<=`/`>=` split).
- **Rejected — naive `bvp_norm >= bvp_median` → `bvp_norm > bvp_median`:** on
  the exact measured shape (median 0.00, 13/25 at 0.00) this only moves the
  same tied mass from `hv` to `lv` — nothing becomes newly distinguishable,
  the verdict for the tied mass is still invented, just on the other side.
  `tests/unit/test_bvp_quadrant_value_axis.py::test_naive_flip_to_strict_greater_would_fail_admission`
  demonstrates directly that `>` would ALSO wrongly exclude a genuine,
  non-degenerate at-median tie (D1 scores 1,2,2,4 — the two 2s legitimately
  belong in hv under inclusive comparison; only a *degenerate* median
  disqualifies a tie, not every tie).
- **Rejected — extending an existing `basis_ok`/`QUAD_WITHHELD` guard, as the
  dispatch prompt suggested:** verified by grep across `lib/bvp.sh`,
  `web/blueprints/bvp.py`, and `.context/concerns.yaml` — no `basis_ok`,
  `QUAD_WITHHELD`, or `G-002` symbol exists anywhere in this repository. The
  prompt's code sample ("this same function already knows how to say 'I
  cannot judge this'") does not match `quadrant()` as it actually reads
  (confirmed both by direct read and by the fact the described line number,
  "around line 303", is ~40 lines off from the real function at line 265).
  The *concept* (a withheld-verdict return distinct from '-') was worth
  keeping; the claim that it already existed was not — this is filed fresh as
  `QUAD_VALUE_WITHHELD`, not an extension.
- **Rejected — a hard "zero value is never hv" floor rule (the prompt's
  alternative suggestion):** narrower than the actual defect. The measured
  degeneracy is about the MEDIAN collapsing onto the floor, not about the
  literal value 0. A corpus where 60% of tasks tie at a nonzero floor (e.g.
  every task scored exactly 1) manufactures the identical problem and a
  zero-only floor rule would miss it entirely. The chosen mechanism (compare
  median to floor, not value to zero) generalises correctly; the floor-only
  rule does not.

### 2026-09-26 — cost-axis and `lib/resolver.py` scope boundary

- **Chose:** do not touch `cost <= cost_median` (same equality shape, `lib/bvp.sh`)
  or `lib/resolver.py`'s independent duplicate of the value-axis defect.
  Both reported below (## Recommendation), neither fixed here.
- **Why:** explicit dispatch-prompt scope boundary — "Report, do not fix: the
  cost axis" — and `lib/resolver.py` was never named in the authorization at
  all. Widening scope on a narrowly-authorized repair is the exact failure
  mode the prompt is structured to prevent (the requesting agent declined to
  make this change itself specifically because it decides how agents' own
  work is ranked).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-25T22:29:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3485-repair-bvp-value-axis-equality-defect-in.md
- **Context:** Initial task creation

### 2026-09-26 — repair implemented + verified [agent]
- **Action:** Reproduced the value-axis equality defect with a committed fixture
  (`tests/unit/test_bvp_quadrant_value_axis.py`), implemented a degenerate-median
  withhold mechanism in `lib/bvp.sh` (`QUAD_VALUE_WITHHELD`/`value_axis_degenerate()`),
  and pinned both required negative controls plus a healthy-corpus control.
- **Output:** `lib/bvp.sh` (quadrant()/cmd_rank()), `tests/unit/test_bvp_quadrant_value_axis.py`
  (5 new tests), `docs/reports/T-3485-bvp-quadrant-value-axis-repair.md` (repro evidence).
- **Context:** Full pre-existing BVP pytest suite (59 tests) + 4 related bats suites
  re-run and unaffected. Two findings reported, not fixed, per explicit scope
  boundary: cost-axis equality symmetry (`lib/bvp.sh`) and an independent
  duplicate of this same defect in `lib/resolver.py:_annotate_bvp_rank()`,
  which is the function that actually drives `fw resolver dispatch` autonomous
  task selection. See `## Recommendation` for detail. Committed to branch
  `t3485-bvp-quadrant-value-axis` via git plumbing (no `git checkout`, to avoid
  touching the shared checkout's HEAD/index while other activity was landing on
  `bleeding-edge` concurrently) — not pushed.
