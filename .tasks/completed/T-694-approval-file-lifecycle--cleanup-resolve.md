---
id: T-694
name: "Approval file lifecycle — cleanup resolved files older than 7 days, reset notified tracker on session init"
description: >
  Approval file lifecycle — cleanup resolved files older than 7 days, reset notified tracker on session init

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-008]
related_tasks: []
created: 2026-03-28T23:54:46Z
last_update: 2026-03-28T23:56:32Z
date_finished: 2026-03-28T23:56:32Z
---

# T-694: Approval file lifecycle — cleanup resolved files older than 7 days, reset notified tracker on session init

## Context

T-691 added stale pending cleanup (>2h) and approval notifications. This task completes the lifecycle: (1) resolved files >7 days are cleaned up (bypass-log.yaml has the permanent record), (2) `.approval-notified` tracker is reset on `checkpoint.sh reset` (session init).

## Acceptance Criteria

### Agent
- [x] Resolved approval files older than 7 days auto-cleaned in checkpoint.sh post-tool
- [x] `.approval-notified` cleared in `checkpoint.sh reset` command
- [x] bypass-log.yaml remains as permanent audit trail (not cleaned)

## Verification

grep -q 'resolved.*STALE_RESOLVED_AGE\|STALE_RESOLVED' agents/context/checkpoint.sh
grep -q 'approval-notified' agents/context/checkpoint.sh

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

### 2026-03-28T23:54:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-694-approval-file-lifecycle--cleanup-resolve.md
- **Context:** Initial task creation

### 2026-03-28T23:56:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
