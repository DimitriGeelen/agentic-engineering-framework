---
id: T-3138
name: "106 bats assertions cannot fail: bash exempts !-inverted commands from errexit"
description: >
  106 bats assertions cannot fail: bash exempts !-inverted commands from errexit

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/integration/continuous_loop.bats, tests/lint/bats-dead-negation.bats, tests/unit/errexit_negation_mechanism.bats, tests/unit/fabric_watch_pattern_fitness.bats, tests/unit/focus_drift_gate.bats, tests/unit/fw_init_atomic.bats, tests/unit/fw_vendor_completeness.bats, tests/unit/handover_digest.bats, tests/unit/hook_absolute_paths.bats, tests/unit/inception_decide_atomicity.bats, tests/unit/lib_compat.bats, tests/unit/note_capture_guard.bats, tests/unit/revisit_undated_signal.bats, tests/unit/t2318_retrofit_injector_append_missing.bats, tests/unit/t2391_project_root_inherited_stale.bats, tests/unit/t2473_union_resolve.bats, tests/unit/t2862_greenfield_first_inception_e2e.bats, tests/unit/t2916_stall_guard_coverage.bats, tests/unit/t2919_budget_gate_command_classify.bats, tests/unit/t2990_root_pollution.bats, tests/unit/t3049_fabric_url_location.bats, tests/unit/t3050_b005_block_message.bats, tests/unit/t3051_exec_bit_gates.bats, tests/unit/t3052_pickup_id_collision.bats, tests/unit/t3054_watchtower_root_fallback.bats, tests/unit/t3073_c001_recommendation_bearing_inceptions.bats, tests/unit/task_id_race.bats, tests/unit/task_reid.bats, tests/unit/test_consumer_recover.bats, tests/unit/test_update_task_horizon_null_reclose.bats, tests/unit/test_workflow_env_isolation.bats, tests/unit/update_task.bats, tests/unit/upgrade_fresh_machine_simulation.bats, tests/unit/watchtower_url_no_guess.bats, tools/bats-dead-negation-lint.py, tools/bats-dead-negation-mutants.py]
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
created: 2026-08-25T09:30:27Z
last_update: 2026-08-25T20:39:38Z
date_finished: 2026-08-25T20:39:38Z
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
  - ts: '2026-08-25T09:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=225,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-25T09:45:13Z'
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

# T-3138: 106 bats assertions cannot fail: bash exempts !-inverted commands from errexit

## Context

Bash's `set -e` documentation says the shell does not exit "if the command's
return value is being inverted with `!`". Bats runs each `@test` body under
`set -e` and takes the body's exit status as the verdict. Together those mean a
`!`-inverted line that is not the last statement of its body is checked by
nothing — errexit is exempted, and the verdict comes from a later line.

A dead assertion and a passing assertion produce identical output. That is why
this reached 99 sites across 62 files before anything noticed, and why the
control shipped here is a source lint rather than a runtime check: at runtime
there is nothing to see.

The filed count of 106/66 was the first draft's count. Seven of those were the
lint's own false positives, corrected during the build — see `## Decisions`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC1 — The mechanism is pinned, not asserted. A bats fixture demonstrates
      all three cases in one file: a non-final `! true` does NOT fail its test, a
      final `! true` DOES, and a non-final `[[ a != a ]]` DOES. Anyone reading the
      lint later can re-derive why it exists without trusting this task's prose.
- [x] AC2 — A lint enumerates every dead assertion in `tests/**/*.bats`: a line
      whose first token is `!` and which is NOT the last statement of its `@test`
      block. It reports file, line, and total. Final `!` assertions are counted
      separately and NOT flagged — those fire correctly.
- [x] AC3 — The lint is wired into `bin/fw test lint` and fails on a non-empty
      result, so a new dead assertion cannot be added silently. Baseline handling
      is explicit: either the sweep in AC4 lands first (preferred), or the
      remaining count is recorded in the lint itself as a shrinking allowance —
      never an unbounded skip.
- [x] AC4 — The 106 existing dead assertions across 66 files are converted to a
      form that fires. Report the count actually converted and, for any left
      behind, name the file and why. A dead assertion that is dead *and*
      would fail if revived is a second defect, not a conversion — file it.
- [x] AC5 — At least one converted assertion is shown to have been hiding a real
      defect, OR it is reported that none were. This is the point of the task: the
      question is not "are the tests tidy" but "what were these tests not telling
      us". Measure it; do not assume the answer either way.
- [x] AC6 — The lint's own control fails against pre-change code. Fixtures only
      (L-599) — no assertion pinned to a live test file, since those are exactly
      what this task edits. Report "N of M fail against pre-change" and name
      regression guards separately.

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
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
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
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# AC2 + AC4: the whole tests/ tree is clean. Asserts the PARTITION, not a count:
# "dead 0" survives the corpus growing, which a pinned total would not.
tools/bats-dead-negation-lint.py tests > /tmp/.t3138l 2>&1 && grep -q "dead 0 in 0 file" /tmp/.t3138l
# AC1: the mechanism, re-derived by running bats on fixtures rather than asserted.
bats tests/unit/errexit_negation_mechanism.bats > /tmp/.t3138b 2>&1 && grep -q "^ok 7 " /tmp/.t3138b && ! grep -q "^not ok" /tmp/.t3138b
# AC3: the gate runs under the verb that collects tests/lint/ — proving the wiring,
# not just the file's existence. `fw test invariants`, not `fw test lint`: see Decisions.
bin/fw test invariants tests/lint/bats-dead-negation.bats > /tmp/.t3138d 2>&1 && grep -q "^ok 13 " /tmp/.t3138d && ! grep -q "^not ok" /tmp/.t3138d
# AC4: the one repaired continuation site actually runs. This file's test 5 executed
# `lib/ agents/ bin/fw` as a command (status 126) after the first sweep orphaned a
# line continuation; it is the regression anchor for that class.
bats tests/unit/t3051_exec_bit_gates.bats > /tmp/.t3138e 2>&1 && grep -q "^ok 5 " /tmp/.t3138e && ! grep -q "^not ok" /tmp/.t3138e
# AC5: the defect the revived assertion exposed is filed, not just described here.
# Asserts the filed task's CONTENT, not just that a filename exists — an empty
# stub matching the glob would satisfy existence and prove nothing.
grep -lq "c001_missing counts only" .tasks/active/T-3143-*.md
# AC6: every mutant of the lint is killed by the lint's own suite. Asserts the
# ratio the harness prints, not a hand-copied number — a survivor turns this red.
tools/bats-dead-negation-mutants.py > /tmp/.t3138m 2>&1 && grep -q "^8 of 8 mutants killed" /tmp/.t3138m

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

**Symptom:** 99 assertions across 62 bats files could not fail the tests they
were written into. Each read as a normal negative assertion.

**Root cause:** bash exempts a `!`-inverted command from errexit. Bats reports a
test's verdict from its body's exit status, so a non-final `!` line is checked
by neither mechanism. Measured, not inferred:
`tests/unit/errexit_negation_mechanism.bats` runs bats on fixtures for all six
cases and reads the verdicts back.

**Why structurally allowed:** the defect is output-identical to correctness. A
dead assertion prints nothing, fails nothing and changes no exit code — it is
indistinguishable at runtime from an assertion that passed. Every existing
control here (bats itself, `fw test unit`, the audit invariant suite) observes
runtime behaviour, so none of them could see it. That is the same false-green
shape as T-3140 (`fw gaps` rendering an allowlist) and L-575: **a check that
cannot see its subject reports the same thing as one that found nothing.**

**Prevention:** `tools/bats-dead-negation-lint.py`, a source lint, wired into
`fw test invariants` via `tests/lint/bats-dead-negation.bats` with a
zero-tolerance assertion and no allowance. An allowance is a number somebody has
to remember to shrink, and nothing ever prompted anyone to look — which is how
this reached 99.

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

### 2026-08-25 — the filed count was wrong, and correcting it was the work

- **Chose:** report 99 dead across 62 files, not the filed 106 across 66.
- **Why:** the first draft implemented AC2's literal wording — "a line whose
  first token is `!` and which is NOT the last statement". Reviewing the flagged
  sites before converting them showed seven the rule mis-classified. Four are
  `! cmd || { ...; return 1; }`: the `!` exempts its own pipeline, but that
  pipeline is not the last command of the `||` list, so the guard branch IS
  checked and the assertion fires. Three are line-continued statements whose `!`
  line is not the last PHYSICAL line but is the last LOGICAL one.
- **Rejected:** converting all 106 as filed. Two of the seven would have been
  broken by the conversion rather than fixed, and the other five would have been
  rewritten for no reason — churn presented as remediation.
- **Note:** the `&&` case is deliberately still flagged. In `! cmd && cmd2`, the
  failure that matters makes `! cmd` return 1, which short-circuits, so the
  status reaching errexit IS the inverted one and IS exempt. The asymmetry with
  `||` was measured, not assumed.

### 2026-08-25 — wired into `fw test invariants`, not `fw test lint`

- **Chose:** `tests/lint/bats-dead-negation.bats`, collected by
  `fw test invariants` (and by `fw test all`).
- **Why:** `fw test lint` is shellcheck, by deliberate design — T-2697's own
  comment in `bin/fw` records that `tests/lint/` was globbed by no runner for
  months precisely because the obvious verb was taken, and named the new verb
  `invariants` "so the collision cannot recur". Wiring a second meaning into
  `lint` would re-create the condition that comment exists to prevent.
- **Rejected:** editing the `lint)` branch of `bin/fw` as AC3 words it. It would
  also have meant touching a file carrying another task's uncommitted edits.

### 2026-08-25 — `if X; then false; fi` as the universal conversion

- **Chose:** `[[ a != b ]]` where the negation fits inside one test command (23
  sites), `if X; then false; fi` everywhere else (76 sites).
- **Why:** errexit is suppressed only in an `if` CONDITION; the branch body is
  checked normally. That makes it safe for the shapes `[[ ]]` cannot hold —
  pipelines, env-var prefixes, redirects. Verified by fixture, not by reasoning.
- **Rejected:** `! X || false`, which also fires (case E in the mechanism
  fixture) but reads as a puzzle. The measurement is kept in the fixture anyway
  so the next reader does not have to redo it to find out why.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Results

**AC4 — conversion.** 99 of 99 converted, 0 left behind. 23 became
`[[ x != y ]]` (the negation moves inside one test command); 76 became
`if X; then false; fi` (errexit is suppressed only in an `if` condition, never in
its body). Two needed a second pass: the sweep replaced the first physical line
of a line-continued statement and orphaned the continuation, which bash then ran
as its own command — `tests/unit/t3051_exec_bit_gates.bats` executed
`lib/ agents/ bin/fw` and exited 126. Both repaired and re-run green. The lint
now carries a note about this for anyone else consuming its output.

**AC5 — what the dead assertions were hiding: one real defect, filed as T-3143.**
All 62 touched files were re-run and every failure attributed by line number.
Exactly one failure landed on a converted line:
`tests/unit/t3073_c001_recommendation_bearing_inceptions.bats:329`. The revived
assertion says the C-001 audit must not WARN about `T-9203`; it does. Reading
`agents/audit/audit.sh:4165-4205` explains why — `c001_missing` is incremented
only for `issue_type = missing`, so an `unreferenced` WARN leaves the counter at
zero and the run emits **`[PASS] C-001: All inceptions have research artifacts`
in the same output as its own C-001 WARN.** The PASS line's wording claims more
than the counter behind it measures. Same false-green family as T-3140 and
L-575. The assertion that would have caught it has been inert since the file was
written.

Nine other tests fail across six files (`t100195_diverged_fork`,
`t2267_self_vendor_web`, `t3095_audit_branch_hygiene`, `task_id_race`,
`fabric_watch_pattern_fitness`, `t2862_greenfield_first_inception_e2e`) — all at
lines this task did not touch, and so pre-existing.
`tests/lint/no-untracked-test-files.bats` failed only while this task's own new
files were untracked.

**AC6 — control.** "Fails against pre-change code" is degenerate for a net-new
tool: before this task the lint did not exist, so all 13 tests fail trivially and
the number says nothing. Reported honestly as 13 of 13, and replaced with the
control that does discriminate: `tools/bats-dead-negation-mutants.py` disables
one lint behaviour at a time and requires the suite to go red. **8 of 8 mutants
killed.** Two are regression guards in the ordinary sense (M7 empty-scan refusal,
M5 quote-awareness) — each is killed by exactly one test.

That harness earned its place immediately. On its first run M3 SURVIVED, which is
the only reason anyone re-read the here-string guard — and the guard was wrong,
matching `<<< hi` and swallowing the rest of a file as heredoc data. Fixing it
took two rounds: a lookahead alone still matches, because from one character in,
the second and third `<` form a valid `<<`. M3b now pins that intermediate wrong
version specifically.

## Updates

### 2026-08-25T09:30:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3138-106-bats-assertions-cannot-fail-bash-exe.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a0cde07f
- **Timestamp:** 2026-08-25T20:40:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-25T20:39:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
