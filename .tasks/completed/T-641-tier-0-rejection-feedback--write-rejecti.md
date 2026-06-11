---
id: T-641
name: "Tier 0 rejection feedback — write rejection reason to resolved YAML, agent
  reads on retry"
description: >
  Tier 0 rejection feedback — write rejection reason to resolved YAML, agent reads
  on retry

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-27T11:45:50Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-27T11:50:32Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-641: Tier 0 rejection feedback — write rejection reason to resolved YAML, agent reads on retry

## Context

T-636 Phase 2. When human rejects a Tier 0 command in Watchtower, the feedback text is stored in the resolved YAML but the agent never reads it. On retry, check-tier0.sh should check for a rejection and include the feedback in the block message so the agent knows WHY it was rejected.

## Acceptance Criteria

### Agent
- [x] check-tier0.sh reads rejection feedback from resolved YAML on block
- [x] Rejection feedback included in stderr block message when present
- [x] Watchtower rejection feedback textarea text persists in resolved YAML (already works — verify)
- [x] GO decision rationale prepopulated from Go/No-Go Criteria or Recommendation section

## Verification

grep -q 'rejected\|rejection\|feedback' agents/context/check-tier0.sh

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-03-27T11:45:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-641-tier-0-rejection-feedback--write-rejecti.md
- **Context:** Initial task creation

### 2026-03-27T11:50:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e77b09d0
- **Timestamp:** 2026-06-02T15:04:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
