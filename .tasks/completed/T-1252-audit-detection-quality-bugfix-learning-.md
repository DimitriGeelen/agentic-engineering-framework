---
id: T-1252
name: "Audit detection quality: bugfix-learning denominator counts dev-discovered
  bugs inflating FAIL threshold"
description: >
  Inception: Audit detection quality: bugfix-learning denominator counts dev-discovered
  bugs inflating FAIL threshold

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-14T07:02:11Z
last_update: '2026-06-11T22:23:43Z'
date_finished: 2026-04-18T22:42:06Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:43Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1252: Audit detection quality: bugfix-learning denominator counts dev-discovered bugs inflating FAIL threshold

## Problem Statement

The audit (agents/audit/audit.sh:952-990) counts any completed task whose name
matches `fix|bugfix|hotfix|RCA|G-[0-9]` as a "bugfix", then expects each to have
a learning entry. Current result: 1/242 = 0% = FAIL.

Per CLAUDE.md "Bug-Fix Learning Checkpoint", the rule applies to **field-discovered
bugs** (user testing, production incidents, cross-platform failures) — NOT to
fixes found during development (pre-commit). The audit doesn't distinguish these.

Result: agents are penalized for not creating learnings for fixes that didn't
need them, and the FAIL obscures whether the rule is working for bugs that DO
need learnings.

## Assumptions

- A1: A significant fraction of the 242 are dev-discovered fixes (not field bugs)
- A2: The distinction between dev-discovered and field-discovered is mechanically detectable (e.g., task created via pickup/concerns register vs. directly)
- A3: Narrowing the denominator will produce a meaningful coverage number
- A4: The audit threshold (35% target, <10% FAIL) was set assuming a narrow denominator

## Exploration Plan

1. **Spike A (20min):** Sample 20 completed "fix" tasks. Manually classify each as
   field-discovered or dev-discovered. Report the ratio.
2. **Spike B (15min):** Identify mechanical signals that correlate with field-discovery:
   - Created via pickup inbox? `fw pickup` metadata
   - References a concerns register entry? (G-XXX gap)
   - Linked to an RCA task?
   - Task name contains "reported by" / "found in production" / similar
3. **Spike C (10min):** Run the proposed narrower filter against the 242; estimate
   the corrected coverage ratio.

## Technical Constraints

- The filter must be mechanical (grep-able from task file metadata)
- Cannot require retroactive tagging of historical tasks
- Must remain backwards-compatible with existing audit output format
- The FAIL/WARN/PASS thresholds may need recalibration after denominator change

## Scope Fence

**IN:** Define mechanical filter to distinguish field vs. dev-discovered
**IN:** Propose revised denominator and threshold values
**IN:** Estimate impact on current coverage percentage
**OUT:** Addressing the capture side (why agents skip `fw fix-learned`) — see T-1251
**OUT:** Retroactive re-classification of 242 historical tasks

## Acceptance Criteria

### Agent
- [x] Spike A complete: 242-task bulk classification run; 34% match field signals
- [x] Spike B complete: mechanical filter signals identified and documented
- [x] Spike C complete: revised denominator computed; narrowing alone insufficient
- [x] Research artifact written to docs/reports/T-1252-bugfix-detection-quality.md
- [x] Recommendation written with rationale and GO/NO-GO/DEFER

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO — implement the narrower filter

**Rationale:** Current audit denominator is ~2-3x too broad (66% inflation from
dev-discovered fixes). Narrowing gives agents a truthful signal about field-bug
learning coverage rather than penalizing trivial dev cleanups.

**Evidence:**
- Bulk classification run: 159/242 (66%) appear dev-discovered, not field-discovered
- Proposed filter uses only metadata already present in task files (no schema change)
- Coverage stays at FAIL even after narrowing — metric retains diagnostic value
- See full research artifact: docs/reports/T-1252-bugfix-detection-quality.md

**Next step if GO:** Create `T-1255-build: narrow bugfix-learning detector to field-discovered bugs in audit.sh`

**Complementary to:** T-1251 (capture-side — why agents skip `fw fix-learned`)

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

**Decision**: GO

**Rationale**: Recommendation: GO — implement the narrower filter

Rationale: Current audit denominator is ~2-3x too broad (66% inflation from
dev-discovered fixes). Narrowing gives agents a truthful signal about field-bug
learning coverage rather than penalizing trivial dev cleanups.

Evidence:
- Bulk classification run: 159/242 (66%) appear dev-discovered, not field-discovered
- Proposed filter uses only metadata already present in task files (no schema change)
- Coverage stays at FAIL even after narrowing — metric retains diagnostic value
- See full research artifact: docs/reports/T-1252-bugfix-detection-quality.md

Next step if GO: Create `T-1255-build: narrow bugfix-learning detector to field-discovered bugs in audit.sh`

Complementary to: T-1251 (capture-side — why agents skip `fw fix-learned`)

**Date**: 2026-04-18T22:42:06Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-14T07:05:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-18T22:42:06Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — implement the narrower filter

Rationale: Current audit denominator is ~2-3x too broad (66% inflation from
dev-discovered fixes). Narrowing gives agents a truthful signal about field-bug
learning coverage rather than penalizing trivial dev cleanups.

Evidence:
- Bulk classification run: 159/242 (66%) appear dev-discovered, not field-discovered
- Proposed filter uses only metadata already present in task files (no schema change)
- Coverage stays at FAIL even after narrowing — metric retains diagnostic value
- See full research artifact: docs/reports/T-1252-bugfix-detection-quality.md

Next step if GO: Create `T-1255-build: narrow bugfix-learning detector to field-discovered bugs in audit.sh`

Complementary to: T-1251 (capture-side — why agents skip `fw fix-learned`)

### 2026-04-18T22:42:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-88439648
- **Timestamp:** 2026-06-02T14:56:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
