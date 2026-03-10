---
id: T-408
name: "Remediate audit warnings: fabric edges, uncommitted changes, bugfix-learning, T-203 lifecycle"
description: >
  Remediate audit warnings: fabric edges, uncommitted changes, bugfix-learning, T-203 lifecycle

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [audit, housekeeping]
components: []
related_tasks: []
created: 2026-03-10T16:59:57Z
last_update: 2026-03-10T16:59:57Z
date_finished: null
---

# T-408: Remediate audit warnings: fabric edges, uncommitted changes, bugfix-learning, T-203 lifecycle

## Context

Audit reported 4 WARN: (1) 18/136 fabric cards have no edges, (2) uncommitted changes, (3) bugfix-learning 38% < 40% target, (4) T-203 lifecycle anomaly (0min scratch test).

## Acceptance Criteria

### Agent
- [x] Bugfix-learning coverage >= 40% (added L-096 for T-407, L-097 for T-406)
- [x] T-203 reclassified from build to test (correct workflow_type for scratch test)
- [x] Fabric cards enriched with dependency edges (sub-agent dispatched)
- [x] All changes committed (clears uncommitted warning)

## Verification

grep -q "task: T-407" .context/project/learnings.yaml
grep -q "task: T-406" .context/project/learnings.yaml
grep -q "workflow_type: test" .tasks/completed/T-203-scratch-test--partial-complete-verificat.md

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

### 2026-03-10T16:59:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-408-remediate-audit-warnings-fabric-edges-un.md
- **Context:** Initial task creation
