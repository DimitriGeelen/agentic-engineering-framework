---
id: T-143
name: "Fix create-task.sh: quote name field to prevent YAML errors from colons"
description: >
  Fix create-task.sh: quote name field to prevent YAML errors from colons

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T09:14:54Z
last_update: 2026-02-18T09:15:01Z
date_finished: null
---

# T-143: Fix create-task.sh: quote name field to prevent YAML errors from colons

## Context

T-124 cycle 4: 16/23 sprechloop tasks had unquoted colons in `name:` field (e.g. `name: Spike: own pipeline`), causing YAML parse errors. Watchtower showed only 7 tasks instead of 23.

## Acceptance Criteria

- [x] create-task.sh quotes name field in both template paths (inception + default)
- [x] Sprechloop tasks with colons fixed (16 files)
- [x] Test added: task with colon in name produces valid YAML (test 10, 22/22 pass)

## Verification

tests/test-knowledge-capture.sh

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

### 2026-02-18T09:14:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-143-fix-create-tasksh-quote-name-field-to-pr.md
- **Context:** Initial task creation
