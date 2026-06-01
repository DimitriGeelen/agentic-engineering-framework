---
id: T-597
name: "PICKUP: Pre-push hook doesn't pass PROJECT_ROOT to audit script"
description: >
  From termlink T-141: audit script runs against framework repo instead of consumer project. Fix: pass PROJECT_ROOT in agents/git/lib/hooks.sh line ~328

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [pickup, termlink]
components: []
related_tasks: []
created: 2026-03-24T08:22:01Z
last_update: 2026-03-24T08:55:55Z
date_finished: 2026-03-24T08:55:55Z
---

# T-597: PICKUP: Pre-push hook doesn't pass PROJECT_ROOT to audit script

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Pre-push hook exports PROJECT_ROOT before calling audit script
- [x] `grep -A2 'PROJECT_ROOT.*git rev-parse' agents/git/lib/hooks.sh` shows export

## Verification

grep -q 'export PROJECT_ROOT' agents/git/lib/hooks.sh

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

### 2026-03-24T08:22:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-597-pickup-pre-push-hook-doesnt-pass-project.md
- **Context:** Initial task creation

### 2026-03-24T08:54:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T08:55:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
