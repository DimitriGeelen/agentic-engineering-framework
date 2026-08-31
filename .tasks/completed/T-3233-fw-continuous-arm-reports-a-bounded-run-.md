---
id: T-3233
name: "fw continuous arm reports a bounded run it does not bound — ceiling, iteration
  count, task cap and atomicity"
description: >
  fw continuous arm reports a bounded run it does not bound — ceiling, iteration count,
  task cap and atomicity

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:continuous-run]
components: [tests/unit/t3233_arm_bounds.bats]
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
created: 2026-08-31T15:40:23Z
last_update: 2026-08-31T15:58:18Z
date_finished: 2026-08-31T15:58:18Z
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
  - ts: '2026-08-31T15:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=280,acs=10)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-31T15:45:16Z'
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

# T-3233: fw continuous arm reports a bounded run it does not bound — ceiling, iteration count, task cap and atomicity

## Context

arc-012 review findings **W1-F2, W1-F3, W1-F4 and W1-F8 / W5-F4** — four defects
in one verb, landed as one piece of work because fixing any single leg leaves the
same false green with a smaller surface (`SYNTHESIS.md` §What a maintainer should
do first).

`fw continuous arm` is the operator's control over an unattended run. It printed a
confident summary of a run it had not bounded:

| what it printed | what actually happened |
|---|---|
| `Ceiling: tier 5` | the enforcer used `1` — it resolves directive-first, arm wrote state-only |
| `Ceiling: tier -` | read as "no ceiling"; the effective value was `1`, the strictest |
| `Bound: 3 iteration(s)` | `current_iteration` cannot tick under Stop-hook driving |
| (no mention of `max_tasks`) | a stale `max_tasks: 2` from a prior run still halted the run |
| — | arming with no directive text made the injector a permanent no-op |

Measured on the pre-fix code, both directions of the ceiling defect are reachable:
a directive carrying `1` silently **tightens** `--tier-ceiling 5`, and one carrying
`6` silently **widens** `--tier-ceiling 1`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `--tier-ceiling N` writes the ceiling to **both** `.continuous-mode.yaml` and
      `.next-directive.yaml`; when the flag is absent, a stale `tier_ceiling` in the
      directive is removed, so a prior run's value cannot silently override this arm
- [x] The ceiling `arm` and `status` **print** is resolved through the same
      directive-first chain the enforcer uses (`inject-next-directive.py:261`), and when
      nothing is set anywhere both print the effective default (`1`) rather than `-` —
      today they show "no ceiling" and the operator gets the strictest one
- [x] `arm` gains `--max-tasks N`, written to both files; when the flag is absent a
      stale `max_tasks` is cleared from both, so a run cannot end on a ceiling that
      appears in neither the arm output nor `status`
- [x] `completed_task_ids` is cleared in the same write that zeroes `tasks_completed`,
      so the two cannot diverge across an arm boundary
- [x] `arm` refuses when the resulting `.next-directive.yaml` would carry no non-empty
      `directive:` string — the injector returns before `write_state()` without one, so
      the arm would be a permanent no-op — and the refusal names how to satisfy it
- [x] The two-file write is ordered **directive first, state last**, so the only
      reachable intermediate state is "not yet armed, fresh expiry"; the ordering
      rationale is inline so a later tidy-up cannot re-sort it back
- [x] `arm` output names which bound actually binds a **Stop-hook-driven** run
      (expiry and `max_tasks`) instead of leading with the session counter, which only
      advances across SessionStart
- [x] A bats suite drives the real verb and asserts **printed == enforced** by reading
      the enforcer's own resolution rather than either side alone, with control legs and
      zero skips; mutation matrix recorded in the RCA

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

timeout 600 bats tests/unit/t3233_arm_bounds.bats > /tmp/.t3233a.out 2>&1 && ! grep -q "^not ok" /tmp/.t3233a.out
test "$(grep -c '# skip' /tmp/.t3233a.out)" -eq 0
timeout 900 bats tests/unit/t3225_continuous_arm.bats > /tmp/.t3233b.out 2>&1 && ! grep -q "^not ok" /tmp/.t3233b.out
test "$(grep -c '# skip' /tmp/.t3233b.out)" -eq 0
timeout 900 bats tests/unit/t3212_human_gate_stop.bats > /tmp/.t3233c.out 2>&1 && ! grep -q "^not ok" /tmp/.t3233c.out
test "$(grep -c '# skip' /tmp/.t3233c.out)" -eq 0
timeout 900 bats tests/unit/continuous_task_counter.bats > /tmp/.t3233d.out 2>&1 && ! grep -q "^not ok" /tmp/.t3233d.out
timeout 900 bats tests/unit/stop_driver.bats > /tmp/.t3233e.out 2>&1 && ! grep -q "^not ok" /tmp/.t3233e.out
timeout 600 python3 -m pytest tests/unit/test_inject_next_directive.py -q > /tmp/.t3233f.out 2>&1 && grep -q "passed" /tmp/.t3233f.out
bash -n lib/continuous-mode.sh
grep -q 'CEILING_DEFAULT' lib/continuous-mode.sh
grep -q 'max-tasks' lib/continuous-mode.sh

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

**Symptom:** `fw continuous arm` reported bounds it did not enforce — a tier
ceiling the enforcer ignored, a session count that cannot advance in the mode the
loop actually runs in, a task cap it never set and never cleared, and an arm that
could be a permanent no-op.

**Root cause:** four independent misses sharing one shape — *a value written to
one place and read from another, with no surface comparing them.*
`inject-next-directive.py:261` resolves `tier_ceiling` **directive-first**; `arm`
wrote it to state only and printed straight from state. `max_tasks` was never
written or cleared by `arm` at all, so a prior run's value outranked the current
one. `completed_task_ids` was left populated while `tasks_completed` was zeroed.
The two `save()` calls ran in the order that makes the reachable intermediate
state the harmful one.

**Why structurally allowed:** `verdict()` implements directive-first precedence
**correctly** for `max_iterations`, `max_tasks` and `expires_at` — three lines
above the one field that does not. The discipline looked uniformly applied, and
the file header even names this precedence trap explicitly, for expiry. The
existing suite (`t3225_continuous_arm.bats`) asserted each side alone: `arm`
printed `Ceiling: tier 5` *truthfully*, because that is what it wrote to state.
Both numbers were individually correct about their own file. **Only the comparison
was the defect, and nothing compared them.** Same family as C1/C2/C3 of the same
review — an instrument reporting on a cached copy of its subject.

**Prevention:** the printed value is now produced by `effective_ceiling()`, which
resolves through the same chain the enforcer uses, so printed and enforced cannot
drift without both moving. `tests/unit/t3233_arm_bounds.bats` asserts
**printed == enforced** by invoking the real `inject-next-directive.py` and
reading the ceiling it states in its own emitted block — not by re-typing its
precedence rules, which would be a guard reimplementing the code it guards
(G-072). Write order is pinned on mtime, which is observable as root; a
permissions-based fixture would have proved nothing here (the W4-F2 lesson).

**Mutation matrix.** Each leg reverted independently; restore byte-identical
after every run:

| # | mutation | reddened |
|---|---|---|
| M1 | ceiling no longer written to the directive file | 2 |
| M2 | resolver reverted to state-only | 1 |
| M3 | stale `max_tasks` no longer cleared | 1 |
| M4 | `completed_task_ids` no longer cleared | 1 |
| M5 | no-directive refusal removed | 1 |
| M6 | write order swapped back to state-first | 1 |

**M2 reddened ZERO on the first matrix run**, and that was a finding about the
suite rather than a clean result. Once `arm` writes the ceiling to both files,
state-first and directive-first agree on everything `arm` can produce — so the
resolver's precedence was untested by construction. The gap is real and reachable:
anything other than `arm` can write the directive, which is F2's second direction
(a directive carrying `6` widening an arm of `1`). Added *"status resolves
DIRECTIVE-first when the two files disagree"*, planted directly because `arm` is
now correctly incapable of producing that state. M2 then reddened exactly it.

**A pre-existing red was found and fixed en route.**
`t3212_human_gate_stop.bats:149` asserted `reason=terminated(…)`, the format
T-3228 replaced with `terminated[stored@<when>](…)` when it fixed review C1. The
assertion had been red since that landed. Verified pre-existing by re-running it
against the stashed pre-T-3233 library. The replacement pins the reason text *and*
the stored-labelling, so it is stricter than what it replaces, and it was
mutation-checked: stripping the label from `stop-driver.sh` reddens it.

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

### 2026-08-31 — refusing the no-op arm broke four existing tests, and that was the point

- **What changed:** W1-F3 suggested `arm` should "refuse (or loudly warn)" when the
  resulting directive would carry no text. Refusing broke 4 of 10 tests in
  `t3225_continuous_arm.bats` — and they are precisely the tests the finding names
  as green *because* the counter they assert on is inert. They armed into a no-op
  and asserted the driver's verdict, which is reachable without a directive.
- **Plan impact:** none to the design. It confirmed the refusal is the right
  strength rather than a warning: a warning would have left those four tests
  passing over the same no-op.
- **Triggered:** updated the four bare-sandbox arms to pass `--directive`. The one
  test that legitimately arms without the flag (`arm clears a stale directive
  expiry`) has `directive: stale` in its fixture and correctly still passes —
  which is itself the control proving the refusal is conditional, not blanket.

### 2026-08-31 — the mutation that reddened nothing was the useful one

- **What changed:** M2 (resolver reverted to state-only) reddened zero tests. Not
  because the fix was unnecessary — because after the fix `arm` writes the ceiling
  to both files, so the two precedence orders agree on everything `arm` produces.
  The suite could not distinguish them by construction.
- **Plan impact:** the suite needed a case `arm` cannot generate. Planting a
  disagreeing state/directive pair directly and driving `status` covers F2's
  second direction (a directive silently widening an arm), which the original
  finding named and my first suite missed.
- **Triggered:** nothing filed; the test is in the suite and M2 now reddens it.

### 2026-08-31 — a red test from my own previous landing, found by the regression sweep

- **What changed:** `t3212_human_gate_stop.bats` was red before this task started.
  T-3228 changed the driver's stored-reason format when it fixed review C1 and did
  not update this sibling assertion; its own verification never ran t3212.
- **Plan impact:** none, but it is the clearest instance yet of the arc's own
  subject — a fix that shipped green while leaving an instrument broken, and the
  only reason it surfaced is that this task ran the neighbouring suites rather
  than only its own.
- **Triggered:** fixed in place with a stricter assertion (pins the reason text
  *and* the new stored-labelling), mutation-checked. Not filed separately: it is a
  one-line correction to incomplete work from a task I landed, and recording it
  here keeps the causality visible.

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

### 2026-08-31T15:40:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3233-fw-continuous-arm-reports-a-bounded-run-.md
- **Context:** Initial task creation

### 2026-08-31T15:57:01Z — status-update [task-update-agent]
- **Change:** tags: +arc:continuous-run

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2770c006
- **Timestamp:** 2026-08-31T15:58:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-31T15:58:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
