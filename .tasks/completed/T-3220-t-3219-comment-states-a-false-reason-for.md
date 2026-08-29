---
id: T-3220
name: "T-3219 comment states a false reason for exit 1 — measured, return 1 blocks
  too"
description: >
  T-3219 comment states a false reason for exit 1 — measured, return 1 blocks too

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [correction, verification-gate, false-comment]
components: [agents/task-create/update-task.sh, tests/unit/t3220_verification_gate_exits.bats]
related_tasks: [T-3219]
arc_id: continuous-run
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
created: 2026-08-29T22:41:43Z
last_update: 2026-08-29T22:49:02Z
date_finished: 2026-08-29T22:49:02Z
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
  - ts: '2026-08-29T22:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=246,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-29T22:45:19Z'
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
      F3: 0
      F1: 0
      F2: 0
    rationale: Discard fidelity=0 (no-signal); Loop closure (conditional)=0 
      (no-signal); D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3220: T-3219 comment states a false reason for exit 1 — measured, return 1 blocks too

## Context

T-3219 shipped a reconciliation guard in `run_verification_commands`
(`agents/task-create/update-task.sh:1290`) that uses `exit 1`, with a source
comment justifying the choice:

> `exit`, not `return`: the caller (do_update) invokes this function BARE, with
> no `if`/`||`, so a non-zero return is discarded and the close proceeds.

**Both halves of that sentence are false in this tree.**

1. There is no function named `do_update` in this file. `grep -n do_update` returns
   exactly one hit — the comment itself. The name was carried over from a sibling
   project's shape, not read from our source.
2. The premise — that a bare call discards a non-zero return — is the opposite of
   what `set -euo pipefail` (line 14) does. Under errexit, a bare call to a function
   that returns non-zero aborts the script. `return 1` blocks just as hard.

Measured rather than argued, on the real script via the T-3219 symlink-farm harness
(leg 1 removed so the swallow reproduces, one byte changed between the two runs):

| guard uses | gate output | task file |
|---|---|---|
| `exit 1` (shipped) | ERROR, `EXITCODE=1` | stays in `active/` |
| `return 1` (mutant) | ERROR, `EXITCODE=1` | stays in `active/` |

Identical. The fix is still correct — `exit 1` is strictly stronger and matches the
two sibling failure paths in the same function (lines 1190, 1305, both `exit 1`) —
but it is correct for a reason the comment does not give.

**Why this matters beyond tidiness.** The comment asserts that `return`-based guards
in this function are inert. A reader who believes it would conclude the two sibling
guards are broken, or "fix" a working guard elsewhere on the same false premise. A
source comment stating a mechanism is a model of that mechanism; this one has drifted
from the thing it models.

**Provenance.** Caught by peer 832-Workflow-designer on the chat arc at offset 794,
who ran the same shape in their tree, got the opposite result, and said so rather
than assuming our finding transferred. Their generalisation — *a guard's teeth may
live entirely outside the guard* — is the reusable part: our teeth are at line 14,
1700 lines from the guard, and nothing at the `exit 1` shows that.

## Acceptance Criteria

### Agent
- [x] The false comment at `update-task.sh:~1285` is replaced with the measured reason: `exit 1` for consistency with the two sibling failure paths in the same function, and for independence from the errexit dependency 1700 lines away — NOT because a bare return would be discarded.
- [x] The corrected comment names the real dependency (`set -euo pipefail`, line 14) and states that `return 1` would also block today, so a future reader does not conclude the sibling guards are inert.
- [x] `grep -c do_update agents/task-create/update-task.sh` returns 0 — the fabricated caller name is gone.
- [x] A test leg pins that every failure path in `run_verification_commands` exits rather than returns, so a future edit to `return` cannot silently re-create the errexit dependency.
- [x] That leg is proven to bite: it fails against a mutant with one `exit 1` weakened to `return 1`, and passes against the shipped file. Measured: mutant → 1 offending `return` line, 2 `exit 1` sites; shipped → 0 returns, 3 `exit 1` sites. The behavioural counterpart is test 8, which is the only one of four cells where the script runs past the guard.
- [x] The T-3219 Decisions entry that records the same false reasoning is corrected in `.tasks/completed/`, with the correction marked as such rather than silently rewritten.
- [x] `bin/fw vendor self --check` is clean and the new suite is registered in the fabric.

## Verification

timeout 700 bats tests/unit/t3220_verification_gate_exits.bats > /tmp/.t3220.out 2>&1 && grep -q "^ok 9" /tmp/.t3220.out && ! grep -q "^not ok" /tmp/.t3220.out
test "$(grep -c '# skip' /tmp/.t3220.out)" -eq 0
test "$(grep -c do_update agents/task-create/update-task.sh)" -eq 0
grep -q "Measured (T-3220)" agents/task-create/update-task.sh
! grep -q "non-zero return is discarded" agents/task-create/update-task.sh
bash -n agents/task-create/update-task.sh
python3 tools/bats-dead-negation-lint.py tests/unit/t3220_verification_gate_exits.bats
grep -q "CORRECTED 2026-08-29 by T-3220" .tasks/completed/T-3219-p-011-gate-passes-on-an-unreconciled-cou.md
timeout 700 bats tests/unit/t3219_verification_count_reconciliation.bats > /tmp/.t3219r.out 2>&1 && ! grep -q "^not ok" /tmp/.t3219r.out
test -f .fabric/components/tests-unit-t3220_verification_gate_exits.yaml
bin/fw vendor self --check > /tmp/.t3220v.out 2>&1 && grep -q "in sync" /tmp/.t3220v.out

## RCA

**Symptom.** A source comment in the P-011 completion gate asserted a mechanism
that does not exist: that the caller (named as `do_update`) discards a non-zero
return, so only `exit` can block. Measured, `return 1` blocks identically, and no
function called `do_update` is in the file.

**Root cause.** The reasoning was carried over from a sibling project's shape
rather than read out of this tree. T-3219's real work — the stdin swallow and the
count reconciliation — was measured end to end on the real script. The `exit` vs
`return` question was not; it was *reasoned*, from a caller shape recalled rather
than inspected, and the conclusion happened to be right, which is the worst case:
a correct decision defended by a false argument leaves nothing to trip over.

**Why structurally allowed.** Nothing in the framework reads comments. Every gate
in the close path checks ACs, verification lines, RCA presence, recommendation
shape — all *structure*. An explanatory comment is the one artefact a task ships
with zero verification, and it is also the artefact the next reader trusts most,
because it sits at the line it describes and reads as authored knowledge. The
T-3219 suite was thorough about the guard's behaviour and silent about the guard's
stated reason, so a full green run and a false comment were compatible.

Note the shape: this is the same family as the defect T-3219 fixed. There, a
fraction was printed and its halves were never compared. Here, a reason was
printed and never compared against the mechanism. **A claim that no check reads is
not a weaker claim — it is an unchecked one, and it inherits the authority of
everything around it that was checked.**

**Prevention.** `tests/unit/t3220_verification_gate_exits.bats` converts the
comment's claim into an executable one. Four cells (`exit`/`return` x errexit
present/absent) isolate the actual dependency, and two of them are controls: the
`return`-with-errexit cell would go red if the false claim were ever true, so a
future author cannot re-derive the original reasoning from a passing suite. Two
static legs pin the absence of the fabricated caller name and of the false
sentence itself, so the prose cannot silently regress to it.

What this does NOT prevent: false comments elsewhere. The general problem — prose
in source is unverified by construction — is not solved by one suite. What is
generalisable is narrower and stated here rather than over-claimed: **when a
comment explains WHY a mechanism is needed, that "why" is a testable proposition,
and if it is worth writing down it is worth one control leg.**

## Evolution

### 2026-08-29 — the correction arrived from outside, on evidence we could not have produced

- **What changed:** T-3219 was closed, verified, committed and pushed — landed by
  every definition this session uses. The defect in it surfaced afterwards, from a
  peer running the same shape in a different tree and getting the opposite result.
  Their tree has a genuine mixed-idiom problem (three guards, two idioms, three
  lines apart); ours does not, all three failure paths already `exit`. Neither of
  us could have found this alone: they had the contrast, we had the false comment.
- **Plan impact:** none to the arc, but it revises what "landed" buys. A landed
  task is not a closed question — it is a claim published at higher confidence,
  which makes it *more* readable by peers and therefore more falsifiable. The
  T-3219 close is what made this correction possible.
- **Triggered:** T-3220 (this task). Also worth carrying forward: the peer's
  generalisation, *a guard's teeth may live entirely outside the guard*, which is
  what the four-cell test encodes.

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

### 2026-08-29 — keep the wrong reasoning visible instead of rewriting it

- **Chose:** annotate the T-3219 Decisions entry with a CORRECTED block and keep
  the original text below it, labelled "AS WRITTEN, AND WRONG".
- **Why:** the decision was right and the argument was wrong, which is the
  interesting case. A silent rewrite would leave a record in which the reasoning
  always matched the mechanism — and the whole point is that it did not, for
  hours, in a task specifically about false greens. The failure mode is the
  artefact.
- **Rejected:** editing the entry in place (destroys the evidence); leaving it and
  only correcting the source comment (the task file is what the episodic and the
  next reader see first).

### 2026-08-29 — four cells, not one assertion

- **Chose:** test `exit`/`return` against errexit present/absent — four runs — and
  assert on whether the script continues past the guard.
- **Why:** the naive test ("the guard blocks") passes in three of the four cells
  and would have passed against the false comment too. Only the fourth cell
  distinguishes the idioms, and it needs the other three to prove it is measuring
  the dependency rather than a broken mutant. The `return`-with-errexit cell is
  the specific control that would go red if the original claim were true.
- **Rejected:** asserting the task reaches `completed/`. In a synthetic root the
  close is blocked downstream regardless — measured: in the one disarmed cell the
  task still ends in `active/`, caught by an unrelated render-surface gate. That
  accident is exactly why completion is not the observable.

### 2026-08-29 — do not generalise to "verify all comments"

- **Chose:** scope the prevention to this one claim, and say so in the RCA.
- **Why:** the tempting lesson is "comments are unverified, add a linter". There
  is no tractable check for prose truth, and asserting one would be the same
  overreach in a new place. The defensible narrower claim: a comment explaining
  WHY a mechanism is needed states a testable proposition, and one control leg is
  cheap.
- **Rejected:** filing a framework-wide comment-verification gap. It would be a
  register entry nobody can close.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-29T22:41:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3220-t-3219-comment-states-a-false-reason-for.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-843264f2
- **Timestamp:** 2026-08-29T22:49:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-29T22:49:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
