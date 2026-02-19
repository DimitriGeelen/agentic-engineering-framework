---
id: T-186
name: "Auto-restart: signal file + checkpoint.sh integration"
description: >
  From T-179 GO. When checkpoint.sh auto-handover fires at critical budget, write .context/working/.restart-requested with timestamp after successful handover commit. This is the signal that tells the wrapper script to auto-restart.

status: work-completed
workflow_type: build
owner: claude-code
horizon: now
tags: []
related_tasks: []
created: 2026-02-19T07:37:53Z
last_update: 2026-02-19T07:39:32Z
date_finished: 2026-02-19T07:39:32Z
---

# T-186: Auto-restart: signal file + checkpoint.sh integration

## Context

From T-179 GO decision. Three-component auto-restart: (1) signal file, (2) wrapper script, (3) SessionStart:resume hook. This task covers component 1.

## Acceptance Criteria

- [x] `checkpoint.sh` writes `.context/working/.restart-requested` after successful auto-handover at critical
- [x] Signal file contains JSON with timestamp, session_id, and reason
- [x] Signal file is NOT written if handover fails
- [x] Signal file is cleaned up by `checkpoint.sh reset` and `fw context init`

## Verification

# Signal file write exists in checkpoint.sh
grep -q "restart-requested" /opt/999-Agentic-Engineering-Framework/agents/context/checkpoint.sh
# Reset cleans up signal file
grep -A10 "reset)" /opt/999-Agentic-Engineering-Framework/agents/context/checkpoint.sh | grep -q "restart-requested"

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

### 2026-02-19T07:37:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-186-auto-restart-signal-file--checkpointsh-i.md
- **Context:** Initial task creation

### 2026-02-19T07:39:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
