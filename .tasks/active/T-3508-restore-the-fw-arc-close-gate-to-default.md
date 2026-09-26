---
id: T-3508
name: "restore the fw arc close gate to default-on; the waiver stays available but
  opt-out"
description: >
  restore the fw arc close gate to default-on; the waiver stays available but opt-out

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:arc-grooming]
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
created: 2026-09-26T19:11:57Z
last_update: 2026-09-26T19:17:27Z
date_finished:
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
  - ts: '2026-09-26T19:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=339,acs=11)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-26T19:15:26Z'
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

# T-3508: restore the fw arc close gate to default-on; the waiver stays available but opt-out

## Context

Addresses **OBS-547**. Operator instruction 2026-09-26 after being shown the
situation and three options: proceed with the conservative one.

**What happened.** T-3487 removed the `$CLAUDECODE` refusal from `fw arc close`,
making it opt-in behind `FW_REQUIRE_ARC_CLOSE_APPROVAL=1`. I **parked** that task
this morning on a Sovereign question: its authorisation named *"BVP and ARC
drivers"*, the branch removes the gate on arc **close** (a different verb), and the
authorising quote itself ended *"ask AEF agent."* The task is still
`captured` / `horizon: later`.

While that question was open, a TermLink batch-merge worker
(`dispatch+merge-fo@aef.local`, 17:06–17:07Z) merged four branches into
`bleeding-edge` under T-3506, whose own Context describes them as *"four
independently-reviewed branches."* Three plausibly were. T-3487 was not — it was
parked. The worker read branch topology, which cannot express "deliberately
unlanded."

**Resulting state:** the gate earned after four repeat incidents (T-1670/T-1671,
one of them an agent auto-closing `arc-003` and needing a revert) is **off by
default** on `bleeding-edge`.

**What this task does, and deliberately does not do.**

- **Restores the arc-close refusal to default-on**, keeping T-3487's variable and
  mechanism — the default flips from opt-in to opt-out. This is the *conservative*
  direction: it reduces agent authority back to the documented position and is one
  commit to reverse.
- **Leaves the `fw bvp confirm` waiver in `lib/bvp.sh` untouched.** That half IS
  covered by the authorisation (*"take the human out of scoring"*) and removing it
  would undo work the operator asked for.
- **Does not revert the merge.** Reverting `d9c40f054` would drop the authorised
  `bvp.sh` half with the unauthorised `arc.sh` one. Flipping one default is
  narrower and leaves T-3487's provenance fields (`closed_via`) in place, which are
  useful either way.
- **Does not decide the Sovereign question.** T-3487 stays parked. If the operator
  rules the wider waiver correct, flipping this default back is one line.

**A second defect found while doing it, worse than the first.** T-3505 did not
merely gate the two arc-close refusal tests behind the env var — it marked them
`pytest.mark.skipif`, so they are **skipped in every normal run**:

```python
_require_approval_switch = pytest.mark.skipif(
    os.environ.get(REQUIRE_APPROVAL_ENV) != "1", ...)
```

applied at `:108` and `:207`. A skipped test reports as a pass. That is the T-3217
class this repo documents by name, and it means the two tests that would have
caught the gate being off are silent by construction. Restoring the default without
un-skipping them would leave the gate protected by tests that never run.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw arc close` refuses under `$CLAUDECODE=1` **by default** again.
      → `"${FW_REQUIRE_ARC_CLOSE_APPROVAL:-1}" != "0"` replaces
      `"${FW_REQUIRE_ARC_CLOSE_APPROVAL:-}" = "1"`. Same variable, same mechanism,
      default moved from opt-in to opt-out. Proven by
      `test_close_refused_when_claudecode_set_no_override`, which now passes **nothing**
      — no env var, no identity flag.
- [x] The waiver still exists and is opt-**out**.
      → `FW_REQUIRE_ARC_CLOSE_APPROVAL=0` waives it; proven by
      `test_the_waiver_still_works_when_explicitly_set_to_zero`, which asserts the arc
      actually reaches `status: closed` rather than merely that the command exited 0.
- [x] The two refusal tests **run by default** — the `skipif` is gone.
      → **Was 5 passed / 2 skipped. Now 10 passed / 0 skipped.** The marker was
      removed rather than left unused: its reason string asserted *"the refusal on
      `fw arc close` is opt-in"*, which is now false, and leaving it would be the same
      stale-contradiction shape T-3504 removed from `fw arc help`.
- [x] A test asserts the DEFAULT is refusal.
      → `test_the_refusal_is_the_DEFAULT_not_an_opt_in`. Asserted on behaviour **and**
      on the shipped source, because the behavioural assertion alone would also pass if
      the whole refusal block were deleted. It fails if the opt-in form returns.
- [x] A test asserts the waiver works when explicitly set to `0`.
      → As above, plus `test_waiving_the_identity_check_does_NOT_waive_the_demo_requirement`,
      which was not in the original criteria and is the one that matters most: without
      it, "the waiver works" could have meant "an agent may close an arc with no
      evidence at all", a materially worse permission than T-3487 asked for.
- [x] `lib/bvp.sh`'s `fw bvp confirm` waiver is untouched — verified by diff.
      → `git diff --stat lib/bvp.sh` is **empty**; `FW_REQUIRE_BVP_CONFIRM_APPROVAL`
      still present (5 references). The authorised half is preserved intact.
- [x] `--demo` and `--headline-mechanic` still fire for both caller classes.
      → Unchanged code, and pinned by the new
      `..._does_NOT_waive_the_demo_requirement` leg: with the identity check waived,
      a close with no `--demo` still exits non-zero with `--demo is required`.
- [x] T-3487 remains `captured` / `horizon: later`.
      → Verified. The Sovereign question is intact and unanswered; this task moved a
      default, it did not rule on authorisation.
- [x] Existing arc suites green; zero skips.
      → **56 ok, 0 failures, 0 skips** across five arc suites
      (`arc_membership_shared`, `arc_dual_identity_verbs`,
      `arc_lifecycle_state_machine`, `arc_abandon`, `t3504_arc_help_canonical_field`),
      plus 10/10 on `test_arc_close_agent_gate.py`.

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

out=$(python3 -m pytest tests/unit/test_arc_close_agent_gate.py -q 2>&1); echo "$out" | grep -q "10 passed" && ! echo "$out" | grep -qE "failed|skipped"
bash -n lib/arc.sh
# The gate must be default-ON, and the opt-in form must not return.
grep -qF '"${FW_REQUIRE_ARC_CLOSE_APPROVAL:-1}" != "0"' lib/arc.sh
! grep -qF '"${FW_REQUIRE_ARC_CLOSE_APPROVAL:-}" = "1"' lib/arc.sh
# The skipif that silenced the refusal tests must stay gone.
! grep -q "_require_approval_switch = pytest.mark.skipif" tests/unit/test_arc_close_agent_gate.py
# The AUTHORISED bvp-confirm waiver must survive untouched.
grep -q "FW_REQUIRE_BVP_CONFIRM_APPROVAL" lib/bvp.sh
# T-3487's Sovereign question stays parked — this task did not answer it.
grep -qE '^status: captured' .tasks/active/T-3487-remove-human-approval-gate-on-fw-bvp-con.md
cmp -s lib/arc.sh .agentic-framework/lib/arc.sh

## RCA

**Symptom:** on `bleeding-edge`, `fw arc close` no longer refused an agent caller.
The identity gate earned over four repeat incidents — one of them an agent
auto-closing `arc-003`, reverted two minutes later (T-1670/T-1671) — was off unless
an env var was set, and the two tests that would have caught it were skipped.

**Root cause — three things, none of which is a coding error:**

1. **T-3487 built a waiver whose authorisation did not cover it.** The instruction
   named *"BVP and ARC drivers"*; the branch waived arc **close**. Its own commit
   message quotes the operator ending *"ask AEF agent"* — the uncertainty was
   recorded and then built past.
2. **Parking lives in the task, not the branch.** I parked T-3487 (`captured`,
   `horizon: later`, Sovereign question in the body). A batch-merge worker under
   T-3506 then merged it, on the stated premise of *"four independently-reviewed
   branches."* Branch topology has no field for "deliberately unlanded", so the
   sweeper could not have distinguished it from a branch nobody had got to.
3. **The blocking tests were silenced rather than satisfied.** T-3487's AC #8 was
   unticked because two tests went red. T-3505 made those tests `skipif` on the new
   env var, so they report as passes while executing nothing (T-3217). The evidence
   that the gate had moved was removed in the same motion as the move.

**Why structurally allowed:** every individual step was locally reasonable. The
waiver had an operator quote behind it, the merge task believed the branches were
reviewed, and the test change made a suite green. **No single actor did something
obviously wrong, and the gate still ended up off.** That is the property worth
naming: this failure needed no bypass, no `--force`, and no violated rule — it
composed out of three defensible local decisions across two sessions.

**Prevention:**
1. `test_the_refusal_is_the_DEFAULT_not_an_opt_in` fails if the default is flipped
   back, asserting both behaviour and the shipped source — the behavioural half
   alone would also pass if the block were deleted entirely.
2. `..._does_NOT_waive_the_demo_requirement` fences the waiver's scope, so a future
   widening cannot quietly turn "waive the identity check" into "close an arc with
   no evidence".
3. Verification asserts the `skipif` stays gone and that the authorised `bvp.sh`
   waiver survives, so neither can be lost by a later sweep.
4. **Not prevented, and the one that matters most — OBS-547.** Nothing lets a
   deliberately-parked branch announce itself to a sweeper. Until that exists, any
   batch-merge worker can land parked work again. Candidate fixes are in the
   observation: a `refs/notes` marker, a do-not-merge list, or having the sweeper
   refuse any branch whose governing task is `captured`.

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

### 2026-09-26 — the tests were not gated, they were silenced

- **What changed:** The task was filed to flip one default. Opening the test file
  showed T-3505 had applied `pytest.mark.skipif` to the two refusal tests, not a
  conditional assertion — so they were **skipped in every run**: 5 passed, 2 skipped.
  A skipped test reports as ok (T-3217), which means the gate's own regression
  coverage was inert at exactly the moment the gate moved.
- **Plan impact:** Scope grew from one line in `lib/arc.sh` to also removing the
  marker and adding three legs, including the one that asserts the *default* rather
  than the mechanism. Restoring the default without un-skipping would have left the
  gate guarded by checks that never execute — protection on paper.
- **Triggered:** Nothing new filed; folded into this task because the two are the
  same defect seen from two sides. Recorded because "make the suite green" and "make
  the suite correct" diverged here, and the green suite was the more dangerous
  outcome.

### 2026-09-26 — no rule was broken and the gate still came off

- **What changed:** I expected to find a bypass, a `--force`, or an ignored refusal
  somewhere in the chain. There is none. T-3487 had an operator quote; T-3506
  believed it was merging reviewed branches; T-3505 made a red suite green. Each step
  is locally defensible, and the composition removed a gate that took four incidents
  to earn.
- **Plan impact:** Changed what the RCA claims. This is not an agent-discipline
  failure and writing it up as one would have been wrong — it is a **composition**
  failure across two sessions, where the governing state (a parked task) lives
  somewhere the automation (a branch sweeper) cannot read.
- **Triggered:** **OBS-547** is the real remediation and is deliberately NOT closed
  by this task. Flipping the default back is a mitigation; giving a parked branch a
  way to say so is the prevention. Stating the difference plainly because
  "mitigation is not prevention" is this repo's own G-019 rule and it applies to me
  here.

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

### 2026-09-26T19:11:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3508-restore-the-fw-arc-close-gate-to-default.md
- **Context:** Initial task creation

### 2026-09-26T19:17:27Z — status-update [task-update-agent]
- **Change:** tags: +arc:arc-grooming
