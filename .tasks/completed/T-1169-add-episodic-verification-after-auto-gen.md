---
id: T-1169
name: "Add episodic verification after auto-generation in update-task.sh"
description: >
  Add episodic verification after auto-generation in update-task.sh

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T14:05:10Z
last_update: 2026-04-12T14:07:12Z
date_finished: 2026-04-12T14:07:12Z
---

# T-1169: Add episodic verification after auto-generation in update-task.sh

## Context

`update-task.sh` auto-generates episodics on completion (`|| true`) but never verifies the output file exists. Silent failures cause audit decay (T-1132 pickup from 010-termlink).

## Acceptance Criteria

### Agent
- [x] After episodic auto-generation, `update-task.sh` checks if the output file exists
- [x] Warning printed if episodic generation failed (non-blocking — task still completes)
- [x] Both episodic generation paths (line ~393 and ~838) have verification

## Verification

# Verification patterns exist in update-task.sh
grep -q "episodic.*exist\|Episodic.*not.*created\|EPISODIC_FILE" agents/task-create/update-task.sh

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

### 2026-04-12T14:05:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1169-add-episodic-verification-after-auto-gen.md
- **Context:** Initial task creation

### 2026-04-12T14:07:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
