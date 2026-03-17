---
id: T-520
name: "Fix commit-msg hook FRAMEWORK_ROOT resolution for vendored installs"
description: >
  commit-msg hook resolves FRAMEWORK_ROOT from .framework.yaml framework_path, but T-498 removed that field. Falls back to PROJECT_ROOT, but lib/tasks.sh lives in .agentic-framework/lib/ not project root. find_task_file: command not found. Found during TermLink install test.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [bug, hooks, install, D2]
components: []
related_tasks: []
created: 2026-03-17T22:39:12Z
last_update: 2026-03-17T22:45:36Z
date_finished: 2026-03-17T22:45:36Z
---

# T-520: Fix commit-msg hook FRAMEWORK_ROOT resolution for vendored installs

## Context

Hook template in `agents/git/lib/hooks.sh` checks `.framework.yaml` for `framework_path`, but T-498 removed it. Now checks `.agentic-framework/lib/tasks.sh` as fallback.

## Acceptance Criteria

### Agent
- [x] Hook template checks `.agentic-framework/` vendored path as fallback
- [x] `bash -n agents/git/lib/hooks.sh` passes

## Verification

bash -n agents/git/lib/hooks.sh
grep -q "agentic-framework" agents/git/lib/hooks.sh

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

### 2026-03-17T22:39:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-520-fix-commit-msg-hook-frameworkroot-resolu.md
- **Context:** Initial task creation

### 2026-03-17T22:45:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
