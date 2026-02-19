---
id: T-187
name: "Auto-restart: claude-fw wrapper script"
description: >
  From T-179 GO. Create bin/claude-fw wrapper script that runs claude, then checks for .context/working/.restart-requested signal file on exit. If found (and <5 min old), auto-restarts with claude -c. If stale, removes and exits. Includes --no-restart flag to opt out.

status: work-completed
workflow_type: build
owner: claude-code
horizon: now
tags: []
related_tasks: []
created: 2026-02-19T07:39:56Z
last_update: 2026-02-19T07:41:19Z
date_finished: 2026-02-19T07:41:19Z
---

# T-187: Auto-restart: claude-fw wrapper script

## Context

Component 2 of T-179 auto-restart. Wrapper script that monitors the `.restart-requested` signal file from T-186.

## Acceptance Criteria

- [x] `bin/claude-fw` wrapper script exists and is executable
- [x] Runs `claude` with all passed arguments
- [x] On exit, checks for `.context/working/.restart-requested` signal file
- [x] Restarts with `claude -c` if signal is fresh (<5 min)
- [x] Ignores stale signals (>5 min old)
- [x] Supports `--no-restart` flag to disable auto-restart

## Verification

test -x /opt/999-Agentic-Engineering-Framework/bin/claude-fw
grep -q "restart-requested" /opt/999-Agentic-Engineering-Framework/bin/claude-fw
grep -q "\-\-no-restart" /opt/999-Agentic-Engineering-Framework/bin/claude-fw

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

### 2026-02-19T07:39:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-187-auto-restart-claude-fw-wrapper-script.md
- **Context:** Initial task creation

### 2026-02-19T07:41:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
