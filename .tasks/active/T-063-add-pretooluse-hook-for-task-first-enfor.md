---
id: T-063
name: Add PreToolUse hook for task-first enforcement
description: >
  T-061 finding: No enforcement exists before Write/Edit/Bash tools. Create check-active-task.sh that reads .context/working/focus.yaml, verifies current_task is set, and blocks tool execution if no active task. Wire it as a PreToolUse hook in .claude/settings.json with matcher for Write|Edit. This makes the structural enforcement claim in P-002 actually true.
status: captured
workflow_type: build
owner: human
created: 2026-02-15T08:35:10Z
last_update: 2026-02-15T08:35:10Z
date_finished: null
---

# T-063: Add PreToolUse hook for task-first enforcement

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-15T08:35:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-063-add-pretooluse-hook-for-task-first-enfor.md
- **Context:** Initial task creation
