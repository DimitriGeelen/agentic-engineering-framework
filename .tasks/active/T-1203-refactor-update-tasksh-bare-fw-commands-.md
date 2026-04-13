---
id: T-1203
name: "Refactor update-task.sh bare fw commands to use _emit_user_command (T-1146 GO)"
description: >
  Refactor update-task.sh bare fw commands to use _emit_user_command (T-1146 GO)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-13T08:08:56Z
last_update: 2026-04-13T08:08:56Z
date_finished: null
---

# T-1203: Refactor update-task.sh bare fw commands to use _emit_user_command (T-1146 GO)

## Context

T-1146 GO identified 40 bare `fw` command output sites across 7 files. update-task.sh has 7 sites
that emit bare `fw` commands instead of using `_emit_user_command()` (from lib/paths.sh). These bare
commands are not copy-pasteable from arbitrary directories and use `fw` instead of `bin/fw`.
Related: T-1154 (watchtower URL helper), T-1201 (review.sh terminal overflow fix), T-609 (copy-paste rule).

## Acceptance Criteria

### Agent
- [x] All bare `fw` commands in update-task.sh use `_emit_user_command()` or `_fw_cmd()`
- [x] No bare `echo ".*fw ` patterns remain in update-task.sh (except comments)
- [x] update-task.sh sources paths.sh (for `_emit_user_command` availability)
- [x] Lint test: invariant test verifies no bare `fw` in guidance output

## Verification

# No bare fw commands in echo statements (excluding comments and heredocs)
grep -n 'echo.*".*\bfw\b ' agents/task-create/update-task.sh | grep -v '^\s*#' | grep -v '_fw_cmd\|_emit_user_command' | wc -l | grep -q '^0$'
# paths.sh is sourced
grep -q 'source.*paths.sh' agents/task-create/update-task.sh

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

### 2026-04-13T08:08:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1203-refactor-update-tasksh-bare-fw-commands-.md
- **Context:** Initial task creation
