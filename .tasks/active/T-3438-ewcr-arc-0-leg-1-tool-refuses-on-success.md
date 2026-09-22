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

status: captured
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
last_update: '2026-09-22T18:15:10Z'
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

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [ ] **A1 The two conditions are separated.** `tools/ewcr-arc0-unknown-overlap.py`
      REFUSES (exit 2) only when *total Fabric cards enumerated* is 0 — the real
      "nothing was looked at" signal. A run that enumerates cards successfully and
      finds zero carrying `subsystem: Unknown` completes (exit 0) and reports the
      zero as a measured clear, printing the enumerated-card total as the evidence
      that the scan was not empty.
- [ ] **A2 The stale premise is gone from the refusal text.** The message no longer
      asserts that `fw fabric overview` reports a non-zero Unknown subsystem; that
      was true on 2026-09-19 and false on 2026-09-22 (0 of 1332 cards). Whatever
      replaces it must be a statement the script verifies at run time, not a corpus
      fact copied into a string (T-3326 mutable-corpus-anchor class).
- [ ] **A3 The false-green the guard exists to catch still bites.** A control run
      against an empty card directory still exits 2 — demonstrated by a run, not by
      reading the code. Fixing the false red must not remove the protection: both
      legs (empty scan refuses, cleared fence passes) are pinned as verification.
- [ ] **A4 T-3394's pinned line is green again.** The clause-1 attestation's own
      reproduction command runs clean:
      `python3 tools/ewcr-arc0-unknown-overlap.py && python3 tools/ewcr-arc0-coverage-check.py`
- [ ] **A5 The attestation is reconciled, not silently superseded.**
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
