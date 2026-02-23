---
id: T-260
name: "Fix LATEST.md handover sync — symlink instead of copy"
description: >
  Fix LATEST.md handover sync — symlink instead of copy

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: [agents/handover/handover.sh]
related_tasks: []
created: 2026-02-23T21:55:17Z
last_update: 2026-02-23T21:58:59Z
date_finished: 2026-02-23T21:58:59Z
---

# T-260: Fix LATEST.md handover sync — symlink instead of copy

## Context

LATEST.md was a copy of the session handover file. Editing the session file left LATEST.md stale with [TODO]s, causing D8 audit FAIL and blocking pre-push.

## Acceptance Criteria

### Agent
- [x] `handover.sh` uses `ln -sf` instead of `cp` for LATEST.md
- [x] LATEST.md is a symlink pointing to the current session handover
- [x] D8 audit check passes (0 TODOs in LATEST.md)

## Verification

test -L .context/handovers/LATEST.md
grep -q 'ln -sf' agents/handover/handover.sh

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

### 2026-02-23T21:55:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-260-fix-latestmd-handover-sync--symlink-inst.md
- **Context:** Initial task creation

### 2026-02-23T21:58:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
