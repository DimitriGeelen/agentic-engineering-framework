---
id: T-1148
name: "Upgrade 11 consumer projects — sync audit-task-tools + block-task-tools hooks"
description: >
  Upgrade 11 consumer projects — sync audit-task-tools + block-task-tools hooks

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-12T10:30:14Z
last_update: 2026-04-12T10:30:14Z
date_finished: null
---

# T-1148: Upgrade 11 consumer projects — sync audit-task-tools + block-task-tools hooks

## Context

fw doctor shows 11 consumers behind (v1.5.339/340 vs v1.5.356), all missing audit-task-tools + block-task-tools hooks. Run fw upgrade on each.

## Acceptance Criteria

### Agent
- [x] All 11 consumer projects upgraded to current framework version
- [x] fw doctor consumer check shows 0 warnings

## Verification

bash -c 'bin/fw doctor 2>&1 | grep -c "WARN.*missing" | grep -q "^0$"'
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-12T10:30:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1148-upgrade-11-consumer-projects--sync-audit.md
- **Context:** Initial task creation
