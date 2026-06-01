---
id: T-651
name: "Agent/Task tool gate — add Agent|TaskCreate to check-active-task matcher"
description: >
  T-630 GO build task 2: Add Agent|TaskCreate|TaskUpdate to check-active-task.sh PreToolUse matcher in settings.json. Zero code changes to check-active-task.sh — empty file_path falls through to task-exists check. Blocked by B-005 (settings.json protection — human must update). Related: T-630, T-650.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-28T09:44:55Z
last_update: 2026-04-13T06:23:23Z
date_finished: 2026-03-28T09:45:43Z
---

# T-651: Agent/Task tool gate — add Agent|TaskCreate to check-active-task matcher

## Context

T-630 GO: Universal task gate. Spike 2 proved check-active-task.sh already handles empty file_path correctly — zero code changes needed. Only settings.json matcher update required. B-005 blocks agent edits to settings.json.

## Acceptance Criteria

### Agent
- [x] Verified check-active-task.sh handles Agent/TaskCreate tools (empty file_path falls through to task-exists check)
- [x] Documented required settings.json change

### Human
- [x] [RUBBER-STAMP] Add Agent|TaskCreate matcher to settings.json
  **Steps:**
  1. Open `.claude/settings.json` in editor
  2. Add new PreToolUse entry: `{"matcher": "Agent|TaskCreate|TaskUpdate", "hooks": [{"type": "command", "command": "fw hook check-active-task"}]}`
  3. Restart Claude Code session (hooks snapshot at session start)
  4. Verify: try Agent tool without a task — should be blocked
  **Expected:** Agent/TaskCreate/TaskUpdate blocked without active task, allowed with task
  **If not:** Check that the matcher format is correct (nested hooks array)

## Verification

# No verification needed — settings.json change is human-only (B-005)

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

### 2026-03-28T09:44:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-651-agenttask-tool-gate--add-agenttaskcreate.md
- **Context:** Initial task creation

### 2026-03-28T09:45:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:19Z — status-update [task-update-agent]
- **Change:** horizon: now → next
