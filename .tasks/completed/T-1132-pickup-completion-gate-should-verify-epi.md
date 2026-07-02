---
id: T-1132
name: "Pickup: Completion gate should verify episodic output exists after generation
  — silent failures cause audit decay (from 010-termlink)"
description: >
  Auto-created from pickup envelope. Source: 010-termlink, task T-961. Type: feature-proposal.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-12T09:00:01Z
last_update: '2026-06-11T22:23:40Z'
date_finished: 2026-04-22T05:25:48Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
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

# T-1132: Pickup: Completion gate should verify episodic output exists after generation — silent failures cause audit decay (from 010-termlink)

## Problem Statement

External pickup from 010-termlink proposing: completion gate should verify episodic output exists after generation. Verification this session: the proposed fix has already shipped in T-1169. Triage decision is whether to DEFER as duplicate.

## Assumptions

1. T-1169 already implements the proposed fix — TESTED TRUE (see Evidence)
2. No additional scope remains beyond what's shipped — TESTED TRUE

## Exploration Plan

5-min time-box (done):
- Locate the proposed fix in framework code — DONE
- Verify T-1169 status — DONE (work-completed)
- Diff pickup proposal vs shipped behavior — DONE (matches)

## Technical Constraints

None. Triage only.

## Scope Fence

**IN:** decide whether T-1132 adds anything beyond the T-1169 fix.
**OUT:** re-implementing what's already shipped.

## Acceptance Criteria

### Agent
- [x] Problem statement validated (proposal matches what T-1169 already shipped)
- [x] Assumptions tested (2/2 true)
- [x] Recommendation written with rationale (DEFER — shipped in T-1169)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- New scope exists beyond T-1169's fix

**NO-GO if:**
- The fix is already in tree (this is the case here — DEFER)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** DEFER (close as duplicate of T-1169)

**Rationale:** External pickup from 010-termlink proposing "completion gate should verify episodic output exists after generation". Verification this session shows the fix is already in tree, shipped by T-1169. Closing the pickup is the correct response — no new work to do.

**Evidence:**
- agents/task-create/update-task.sh:397-402 already verifies episodic file existence post-generation
- T-1169 shipped 'Add episodic verification after auto-generation in update-task.sh' — work-completed
- Inline comment cites T-1169: 'silent failure detection'

If 010-termlink is observing the symptom anew, root cause is likely a stale framework copy on the consumer side — operator should run `fw upgrade` on 010-termlink to pick up T-1169.

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

**Decision**: DEFER

**Rationale**: Recommendation: DEFER (close as duplicate of T-1169)

Rationale: External pickup from 010-termlink proposing "completion gate should verify episodic output exists after generation". Verification this session shows the fix is already in tree, shipped by T-1169. Closing the pickup is the correct response — no new work to do.

Evidence:
- agents/task-create/update-task.sh:397-402 already verifies episodic file existence post-generation
- T-1169 shipped 'Add episodic verification after auto-generation in update-task.sh' — work-completed
- Inline comment cites T-1169: 'silent failure detection'

If 010-termlink is observing the symptom anew, root cause is likely a stale framework copy on the consumer side — operator should run `fw upgrade` on 010-termlink to pick up T-1169.

**Date**: 2026-04-19T11:54:02Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T09:41:34Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-04-19T11:54:02Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER (close as duplicate of T-1169)

Rationale: External pickup from 010-termlink proposing "completion gate should verify episodic output exists after generation". Verification this session shows the fix is already in tree, shipped by T-1169. Closing the pickup is the correct response — no new work to do.

Evidence:
- agents/task-create/update-task.sh:397-402 already verifies episodic file existence post-generation
- T-1169 shipped 'Add episodic verification after auto-generation in update-task.sh' — work-completed
- Inline comment cites T-1169: 'silent failure detection'

If 010-termlink is observing the symptom anew, root cause is likely a stale framework copy on the consumer side — operator should run `fw upgrade` on 010-termlink to pick up T-1169.

### 2026-04-22T05:25:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-04-22T05:25:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7ac9d4c7
- **Timestamp:** 2026-06-02T14:55:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
