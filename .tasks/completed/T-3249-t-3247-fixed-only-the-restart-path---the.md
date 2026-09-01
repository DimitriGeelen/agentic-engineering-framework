---
id: T-3249
name: "T-3247 fixed only the restart path - the re-arm relaunch is still promptless
  under headless"
description: >
  bin/claude-fw:659-663 relaunches with CLAUDE_ARGS=() when a clean-exit re-arm fires,
  with no HEADLESS branch. T-3247 added that branch to the budget-critical restart
  path (line 577) and left its sibling untouched. Under headless every re-arm therefore
  relaunches a --print session with no prompt, which dies on 'Input must be provided'
  and burns a restart from the budget without taking a turn. Measured 1:1 in arc-012
  E9: run 3 had 4 re-arms and 4 such errors, run 4 had 1 and 1.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
arc_id: continuous-run
components: [bin/claude-fw]
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
created: 2026-09-01T21:08:15Z
last_update: 2026-09-01T22:03:22Z
date_finished: 2026-09-01T22:03:22Z
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
  - ts: '2026-09-01T21:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=318,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-01T21:15:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      Discard fidelity: 0
      Loop closure (conditional): 0
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: Discard fidelity=0 (no-signal); Loop closure (conditional)=0 
      (no-signal); D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3249: T-3247 fixed only the restart path - the re-arm relaunch is still promptless under headless

## Context

T-3247 diagnosed a real defect — a headless auto-restart relaunched `claude -p`
with `CLAUDE_ARGS=()`, so the new session died on *"Input must be provided"*
before doing anything — and fixed it. It fixed **one of the two places the same
line appears.**

`bin/claude-fw` has two relaunch paths:

| path | trigger | line | headless branch? |
|---|---|---|---|
| **restart** | budget-critical signal | 577-597 | **yes** — `CLAUDE_ARGS=("-p" "$local_directive")`, plus an honest refusal when there is no directive |
| **re-arm** | clean exit, no signal, run still armed | 659-663 | **no** — falls straight to `CLAUDE_ARGS=()` |

The re-arm branch is verbatim what T-3247 replaced:

```sh
if [ "${FW_RESTART_MODE:-fresh}" = "continue" ]; then
    CLAUDE_ARGS=("-c")
else
    CLAUDE_ARGS=()
fi
```

### Measured, 1:1, in both arc-012 E9 runs

Counted from the committed wrapper transcripts, not inferred:

| run | `Re-arm #` lines | `Input must be provided` errors |
|---|---:|---:|
| run 3 (`E9-run3-calibration.txt`) | 4 | 4 |
| run 4 (`E9-loop-does-work.txt`) | 1 | 1 |

Every re-arm under headless relaunches a promptless `--print` session, which
cannot take a turn, dies immediately, and **still consumes one of `MAX_RESTARTS`**.

### Why this is not cosmetic

A supervised continuous run ends each session one of two ways: it trips the
budget, or it finishes its turn cleanly. The budget path works. **The clean-exit
path is dead**, so half the loop's exit modes cannot continue the run. In E9 run 3
that meant the loop spent its entire restart budget — four relaunches — without a
single session capable of doing anything.

This also corrects the record in T-3246's run-3 write-up, which described those
four events as *"the wrapper relaunching a session that had nothing left to do"*.
That reading was charitable and mechanically wrong: the backlog did happen to be
empty, but those sessions **could not have worked it even if it had not been** —
they never received a prompt. The two states are indistinguishable from the
outside, which is why it went unnoticed through the run and the write-up both.

### Note on the general shape

T-3247's own commit message is *"headless restart passes the directive as the
prompt — the loop can act again"*. The fix was correct and its reasoning (a
directive carries an instruction, not a transcript, so the freed context stays
freed) applies **identically** to re-arm. What was missing was the sweep: when a
defect is a duplicated line, fixing the instance you reproduced leaves the
instances you did not. Sibling in kind to L-399 (producer/consumer parity) —
ship the contract everywhere the pattern appears, not only where it was hit.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The re-arm path honours `HEADLESS` exactly as the restart path does — relaunching with the armed directive as the prompt rather than no prompt.
- [x] When headless and there is no directive to run, re-arm **refuses** rather than relaunching, and records its own distinct loop-event reason — matching the restart path's `no-directive-headless` treatment instead of silently burning the budget.
- [x] A regression test drives a headless re-arm end to end and asserts the relaunched session receives a prompt: no `Input must be provided` in the transcript, and the re-arm count matches the count of sessions that actually took a turn.
- [x] A negative control is included: with the fix reverted, the test fails. Without it the test cannot distinguish 'fixed' from 'never exercised' (L-653).
- [x] Both paths are checked for any further duplicated relaunch sites, so this is closed as a class rather than a second instance.

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

## Implementation

`bin/claude-fw`:

- **`_armed_directive()`** (new helper) reads `.context/working/.next-directive.yaml`
  key `directive:` — the same file and key that `budget-gate.sh:64` and
  `checkpoint.sh:190` fold into the restart signal (T-2363). The re-arm path has no
  signal to read from, so it reads the source directly. Same precedence, different
  delivery.
- **the re-arm branch** now mirrors the restart branch: `continue` → `-c`;
  headless with a directive → `-p "$directive"` plus `FW_NEXT_DIRECTIVE`; headless
  with none → refuse, log `exit / no-directive-headless-rearm`, exit 1;
  interactive → unchanged.

**Class closure (AC 5).** All eight `CLAUDE_ARGS=` sites audited. Two are relaunch
points (restart, re-arm) and both now carry a `HEADLESS` arm; two are the
interactive `else` legs, correctly promptless; one is the initial declaration
consumed by argument parsing; the rest are comments. No third relaunch site exists.

## Verification results

`tests/unit/t3249_rearm_headless_prompt.bats` — **6/6 pass**:

| id | asserts |
|---|---|
| D1 | every headless relaunch carries `-p` **and** the armed directive |
| D2 | no relaunch has the promptless argv signature |
| D3 | headless re-arm with no directive exits 1 and does not relaunch |
| D4 | the refusal logs `no-directive-headless-rearm`, distinct from `max-restarts` |
| D5 | **scope control** — non-headless re-arm still relaunches with no prompt |
| C1 | **negative control** — reconstructs the pre-fix wrapper and asserts D1's claim is false there |

The stub `claude` records its own argv, because argv *is* the defect: what the
wrapper passes on relaunch. AC 3's "no `Input must be provided`" is asserted at
the mechanism rather than the symptom — the stub never emits that string, so
grepping for it would pass vacuously; D2 asserts the argv shape that causes it.

C1 twice refused to pass on a broken control before it was right: first the
reconstructed wrapper did not parse (asserted, so it went red rather than
silently proving nothing), then the excision check counted the helper *name*
instead of the *call*. Both are the same failure the control exists to prevent.

### Deferred at the budget gate, then done

The previous session ran out of budget before re-running the broader `claude-fw`
suites and said so rather than closing on the one suite it had. Those suites have
now been run: **44/44 green, zero failures** across all six
(`t3249_rearm_headless_prompt`, `t3243_supervisor_restart_policy`,
`claude_fw_restart_mode`, `restart_sentinel_ttl`, `claude_fw_router`,
`claude_fw_copy_not_symlink`) — run twice, second run captured. D5's reasoning
about the interactive path is now backed by a green suite rather than standing
alone, and the cluster is pinned in `## Verification` so the next change to
either relaunch site has to keep all six honest.

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

# --- T-3249 gate (the whole claude-fw relaunch cluster, not just this task's suite) ---
# Scoped to the six suites that touch the relaunch decision. Written as a full-cluster
# run because the defect class is "one relaunch site fixed, its sibling left behind" —
# a per-file green would reproduce exactly the blindness this task exists to close.
bats tests/unit/t3249_rearm_headless_prompt.bats tests/unit/t3243_supervisor_restart_policy.bats tests/unit/claude_fw_restart_mode.bats tests/unit/restart_sentinel_ttl.bats tests/unit/claude_fw_router.bats tests/unit/claude_fw_copy_not_symlink.bats > /tmp/.t3249gate.out 2>&1 && grep -q '^1\.\.44$' /tmp/.t3249gate.out && ! grep -q '^not ok' /tmp/.t3249gate.out
# The 1..44 clause is deliberate: it pins the COUNT, so a suite silently ceasing to
# run (renamed, skipped, emptied) reddens the gate instead of passing on 0 failures.

## RCA

**Symptom.** Under headless (`-p`/`--print`), every clean-exit re-arm relaunched
`claude` with an empty argv. The relaunched process printed *"Input must be provided
either through stdin or as a prompt argument when using --print"* and exited 1
immediately — spending one unit of the restart budget without taking a turn. Measured
1:1 in arc-012 E9: run 3 had 4 re-arms and 4 such errors, run 4 had 1 and 1.

**Root cause.** `bin/claude-fw` has two relaunch sites — the budget-critical restart
(~577) and the clean-exit re-arm (~659) — and each constructs `CLAUDE_ARGS` for
itself. T-3247 added the `HEADLESS` branch to the first and left the second exactly
as it was. Nothing shared between them, so nothing carried the fix across.

**Why the framework allowed it.** Three reasons, and the third is why it survived
four experiments:

1. **The relaunch decision is enforced at each site rather than asserted as an
   invariant.** Same class as T-3235 and peer 832's G-008: when the behaviour lives
   at N sites, a fix at one of them is structurally incapable of reaching the others.
2. **T-3247's suite tested the path it fixed.** It went fully green with the sibling
   broken, because a per-path test cannot see a per-class defect. The green was real;
   it just did not depend on the thing that was wrong.
3. **The failure direction is benign-looking.** A relaunch that dies in under a second
   still appends a restart event, so the loop ledger reads *"the loop ran, it restarted
   4 times"* — which is what E5, E7, E8 and E9 all reported. Nothing anywhere reads
   *"and took zero turns"*. A false green of the recurring family: the signal that
   was emitted was not the signal that mattered.

**Prevention.** The regression suite asserts over **every** relaunch site, not the one
under test: D1 requires each headless relaunch to carry `-p` plus the armed directive,
and D2 asserts the promptless argv signature appears at **no** relaunch. C1 reconstructs
the pre-fix wrapper and requires D1 to go red there, so the suite is falsifiable rather
than tautological. AC 5 audited all eight `CLAUDE_ARGS=` sites to close this as a class
and confirmed there is no third relaunch point. `## Verification` pins the whole
six-suite cluster with a `1..44` count clause, so a suite that silently stops running
reddens the gate instead of passing on zero failures.

**Not prevented, deliberately.** The duplication itself still stands — two sites still
build argv independently, and the invariant is asserted by tests rather than by
construction. A *third* relaunch site added later is caught only if it produces the
argv shape D2 scans for. Factoring both sites into one `_relaunch()` would remove the
class outright; that is a refactor with its own blast radius on the wrapper every
session starts through, and it is not being smuggled into a bug fix. Named here so the
next reader knows the guard is a net, not a wall.

## Evolution

### 2026-09-01 — the AC asked for the symptom; the symptom is unassertable

- **What changed:** AC 3 was written as "no `Input must be provided` in the
  transcript". Building the harness showed that string can never appear: the test
  stub *is* the `claude` under test and it never emits it, so the grep would have
  passed on a fully broken wrapper. The evidence had to move from the symptom to
  the mechanism — D2 asserts the promptless argv signature appears at no relaunch
  site, which is the thing that *causes* the message.
- **Plan impact:** the "assert the error text is absent" shape is unusable wherever
  the failing component is stubbed out. Nothing else in the plan changed.
- **Triggered:** no new task. Recorded because the shape recurs: an absence-assertion
  over output the harness cannot produce is a vacuous green, and it reads identical
  to a real one.

### 2026-09-01 — the negative control needed its own control

- **What changed:** C1 reconstructs the pre-fix wrapper and requires D1 to go red
  against it. It passed twice while proving nothing — first because the reconstructed
  wrapper did not parse at all (so D1 "failed" for the wrong reason), then because the
  excision check counted the helper's *name* rather than its *call*. Both were caught
  only because C1 asserts that its own reconstruction is well-formed before asserting
  the red.
- **Plan impact:** a negative control is not automatically trustworthy for being
  negative — "the test failed" and "the test failed for the reason claimed" are
  different propositions, and only the second is evidence.
- **Triggered:** no new task; folded into the suite as an explicit parse assertion
  inside C1.

### 2026-09-02 — filed as a missed site, closed as a class

- **What changed:** at filing this read as "T-3247 fixed one of two places". The
  audit of all eight `CLAUDE_ARGS=` sites (AC 5) reframed it: the relaunch decision
  is *constructed per-site*, so a per-site fix is structurally incapable of reaching
  its siblings. Same shape as T-3235 / peer 832's G-008.
- **Plan impact:** the tests changed target — from "the re-arm path is fixed" to
  "no relaunch site anywhere is promptless". D2 is that assertion.
- **Triggered:** no new task. The residual — two sites still build argv independently
  — is named in `## RCA` under "Not prevented, deliberately" rather than silently
  left as done.

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

### 2026-09-01T21:08:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3249-t-3247-fixed-only-the-restart-path---the.md
- **Context:** Initial task creation

### 2026-09-01T21:31:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c2595cd7
- **Timestamp:** 2026-09-01T22:05:34Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/unit/t3249_rearm_headless_prompt.bats tests/unit/t3243_supervisor_restart_policy.bats tests/unit/claude_fw_restart_mode.bats tests/unit/restart_sentinel_ttl.bats tests/unit/claude_fw_router`

### 2026-09-01T22:03:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
