---
id: T-873
name: "Fix fw approvals status exit 1 with no resolved approvals"
description: >
  Fix fw approvals status exit 1 with no resolved approvals

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-04-04T23:21:22Z
last_update: 2026-04-04T23:23:18Z
date_finished: 2026-04-04T23:23:18Z
---

# T-873: Fix fw approvals status exit 1 with no resolved approvals

## Context

`fw approvals status` exits 1 when no resolved approvals exist. Root cause: `find | xargs ls | head` pipeline fails when find returns nothing and xargs runs ls with no arguments.

## Acceptance Criteria

### Agent
- [x] `fw approvals status` exits 0 with empty approvals directory
- [x] Integration test passes

## Verification

bats tests/integration/fw_approvals.bats

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

### 2026-04-04T23:21:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-873-fix-fw-approvals-status-exit-1-with-no-r.md
- **Context:** Initial task creation

### 2026-04-04T23:23:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
