---
id: T-641
name: "Tier 0 rejection feedback — write rejection reason to resolved YAML, agent reads on retry"
description: >
  Tier 0 rejection feedback — write rejection reason to resolved YAML, agent reads on retry

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-27T11:45:50Z
last_update: 2026-03-27T11:50:32Z
date_finished: 2026-03-27T11:50:32Z
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
