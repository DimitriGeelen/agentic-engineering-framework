---
id: T-3438
name: "EWCR Arc-0 leg-1 tool refuses on success: split 'nothing enumerated' from 'zero
  Unknown'"
description: >
  tools/ewcr-arc0-unknown-overlap.py exits 2 REFUSED when it finds 0 Unknown-subsystem
  cards, on the premise that fw fabric overview reports a non-zero Unknown subsystem.
  That premise is false as of 2026-09-22: 0 of 1332 .fabric cards carry subsystem:
  Unknown. The guard cannot distinguish a broken predicate from a genuinely cleared
  fence, so it refuses on success and T-3394's pinned verification line 4 is red.
  OBS-476.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [ewcr, arc0, bug]
arc_id: ewcr-arc0-contract-evidence
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
created: 2026-09-22T18:10:24Z
last_update: 2026-09-22T19:30:56Z
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
bvp_scores_proposed:
  - ts: '2026-09-22T18:11:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-09-22T18:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 7
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=7 (lines=145,acs=5)
    rubric_sha: e4a00f38e801
---

# T-3438: EWCR Arc-0 leg-1 tool refuses on success: split 'nothing enumerated' from 'zero Unknown'

## Context

`tools/ewcr-arc0-unknown-overlap.py` is the executable fence behind Arc-0 clause 1: it
measures how many `subsystem: Unknown` Fabric cards fall inside the runtime write set.
It carried a guard that refused (exit 2) whenever it found **zero** Unknown cards, on the
premise that the corpus always holds some — so a zero could only mean its own subsystem
predicate was broken. On 2026-09-22 that premise went false (0 Unknown of 1332 cards,
measured by T-3437 drive 6 and recorded as D-615), and the tool began refusing on
success. `T-3394`'s pinned verification line 4 — the clause-1 attestation's own
*"Reproducing this"* command — therefore went **red three days after T-3394 closed
green**, with nobody having touched the tool. Registered as **OBS-476**.

## Acceptance Criteria

### Agent
- [x] **A1 The two conditions are separated.** `tools/ewcr-arc0-unknown-overlap.py`
      REFUSES (exit 2) only when *total Fabric cards enumerated* is 0 — the real
      "nothing was looked at" signal. A run that enumerates cards successfully and
      finds zero carrying `subsystem: Unknown` completes (exit 0) and reports the
      zero as a measured clear, printing the enumerated-card total as the evidence
      that the scan was not empty.
- [x] **A2 The stale premise is gone from the refusal text.** The message no longer
      asserts that `fw fabric overview` reports a non-zero Unknown subsystem; that
      was true on 2026-09-19 and false on 2026-09-22 (0 of 1332 cards). Whatever
      replaces it must be a statement the script verifies at run time, not a corpus
      fact copied into a string (T-3326 mutable-corpus-anchor class).
- [x] **A3 The false-green the guard exists to catch still bites.** A control run
      against an empty card directory still exits 2 — demonstrated by a run, not by
      reading the code. Fixing the false red must not remove the protection: both
      legs (empty scan refuses, cleared fence passes) are pinned as verification.
- [x] **A4 T-3394's pinned line is green again.** The clause-1 attestation's own
      reproduction command runs clean:
      `python3 tools/ewcr-arc0-unknown-overlap.py && python3 tools/ewcr-arc0-coverage-check.py`
- [x] **A5 The attestation is reconciled, not silently superseded.**
      `arc-0-clause-1-attestation.md` records that the Unknown total moved 544 -> 0
      corpus-wide, with the date and the commit, so the document and the live
      measurement cannot disagree without one of them going red — the same discipline
      T-3394 applied to the `intersection_count: 3` block it corrected.

## Verification

# A1/A4: the tool completes and reports the intersection.
timeout 300 python3 tools/ewcr-arc0-unknown-overlap.py > /tmp/.t3438-overlap.out 2>&1 && grep -q 'Intersection with CORE write set' /tmp/.t3438-overlap.out
# A1: the enumerated-card total is printed as the not-empty evidence.
grep -qiE 'cards enumerated' /tmp/.t3438-overlap.out
# A2: the stale premise string is gone.
! grep -q 'reports a non-zero Unknown subsystem' tools/ewcr-arc0-unknown-overlap.py
# A3: the empty-scan control still refuses (exit 2).
d=$(mktemp -d); mkdir -p "$d/.fabric/components"; FRAMEWORK_ROOT="$d" python3 tools/ewcr-arc0-unknown-overlap.py > /tmp/.t3438-ctl.out 2>&1; rc=$?; rm -rf "$d"; test "$rc" -eq 2
# A4: the coverage control still runs.
timeout 300 python3 tools/ewcr-arc0-coverage-check.py > /tmp/.t3438-cov.out 2>&1 && grep -q 'files on disk' /tmp/.t3438-cov.out
# A5: the attestation records the 544 -> 0 move.
grep -q '544' docs/research/executable-workflow/arc-0-clause-1-attestation.md

## RCA

**Symptom.** `python3 tools/ewcr-arc0-unknown-overlap.py` exits **2 REFUSED** on a
healthy corpus: *"REFUSED: enumerated 0 Unknown-subsystem cards."* T-3394's pinned
verification line 4 returns `rc=2`. Re-measured at the start of this task, before any
edit, and again after — red then, green now.

**Root cause.** The guard used the **wrong discriminator**. The question it exists to
answer is *"did this scan look at anything?"*, and the number that answers it is the
**Fabric card total**. The guard instead read the **Unknown total**, which is a *result*
of the scan, not evidence that the scan happened. The two are only equivalent while the
corpus holds some Unknown cards — which the refusal text asserted as a standing fact
(*"`fw fabric overview` reports a non-zero Unknown subsystem"*). Once the corpus cleared,
a cleared fence and a broken predicate produced the identical observation and the guard
resolved the ambiguity in the one direction that is wrong on a success.

**Why structurally allowed.** The script hard-coded a **corpus fact as an invariant** —
exactly the mutable-corpus-anchor class **T-3326** names, which the framework applies to
`## Verification` lines but not to the tools those lines invoke. The script's own header
argues the opposite case correctly (*"The Unknown count moves… A fence keyed to a number
that drifts needs a command, not a citation"*) and then embeds a drifting number in its
refusal string eighty lines later — so the rule was understood and still not applied to
the file that stated it. Nothing detected the regression: the only consumer is a
verification line on an already-**completed** task, and P-011 runs a task's Verification
block at the close transition, never again. A pinned line on a closed task is a claim
nobody re-checks.

**Prevention.** Distinct from the fix, and both are pinned as verification lines here:

1. **The right discriminator, read at run time.** REFUSED now means *zero Fabric cards
   enumerated* — a property the script measures on every invocation, which cannot go
   stale because there is no number stored anywhere to go stale.
2. **The control leg proves the protection still bites.** A run against an empty
   `.fabric/components` directory still exits 2 (verification line 4 of this task) — so
   removing the false red demonstrably did not remove the false-green guard. Fixing a
   guard by deleting it is the obvious wrong repair, and the control is what makes that
   distinguishable from the right one.
3. **The document and the measurement are reconciled** (AC A5) so they cannot silently
   disagree — the same discipline T-3394 itself applied to the stale `intersection_count:
   3` block it corrected.

**The generalisable finding, recorded for whoever owns it.** *A verification line pinned
on a `completed/` task is never re-run by the framework.* T-3394 was green at close and
red three days later, and the only reason anyone knows is that drive 6 chose to re-run a
cited command instead of citing it. This is a detection gap wider than this bug —
surfaced in the drive-7 handback as a Sovereign question rather than fixed here, because
"re-run completed tasks' verification blocks on a schedule" is a governance change with a
cost model, not a one-file repair.

## Evolution

### 2026-09-22 — the fix is one condition, the finding is two

- **What changed:** At filing this read as a one-line guard repair. Implementing it
  surfaced that the guard's premise and its *discriminator* are separate defects. Swapping
  the discriminator (card total, not Unknown total) fixes it permanently; deleting the
  stale premise string alone would have left a guard that is correct today and wrong again
  the next time someone reasons from a corpus snapshot. The zero-denominator path
  (`0/0` in the percent-of-Unknown columns) was not anticipated at filing and needed an
  explicit `n/a — 0 Unknown cards to apportion` rather than a crash or a misleading `0.0%`.
- **Plan impact:** None to scope; A1–A5 were already written against the right shape. The
  measured-clear banner and the `share()` helper are additions the ACs implied but did not
  name.
- **Triggered:** No new task. One Sovereign question for the drive-7 handback — *nothing
  re-runs a completed task's `## Verification` block*, which is why this sat red for three
  days and is a wider gap than this tool. Surfaced, not decided.

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

### 2026-09-22T18:10:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3438-ewcr-arc-0-leg-1-tool-refuses-on-success.md
- **Context:** Initial task creation

### 2026-09-22T19:30:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
