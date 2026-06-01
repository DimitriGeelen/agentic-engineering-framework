---
id: T-985
name: "Fix task template — verification section comments parsed as commands"
description: >
  The default task template has HTML comments in the Verification section that get parsed as shell commands by the verification gate, causing false failures. Remove or restructure the comments.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-06T23:26:05Z
last_update: 2026-04-06T23:27:58Z
date_finished: 2026-04-06T23:27:58Z
---

# T-985: Fix task template — verification section comments parsed as commands

## Context

Root cause: template Verification section uses HTML comments (`<!-- -->`). When agent edits to add commands, partial removal leaves orphaned comment body that the parser can't strip. Fix: use `#` comments instead.

## Acceptance Criteria

### Agent
- [x] `default.md` template Verification section uses `#` comments instead of `<!-- -->`
- [x] `inception.md` template Verification section uses `#` comments instead of `<!-- -->`
- [x] Parser already correctly skips `#` comments (line 182 in update-task.sh)

## Verification

grep -q '^# Shell commands' .tasks/templates/default.md
grep -q '^# Shell commands' .tasks/templates/inception.md

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

### 2026-04-06T23:26:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-985-fix-task-template--verification-section-.md
- **Context:** Initial task creation

### 2026-04-06T23:27:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
