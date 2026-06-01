---
id: T-791
name: "Fix checkpoint.sh cross-project transcript leak — scope find_transcript to current project"
description: >
  Fix checkpoint.sh cross-project transcript leak — scope find_transcript to current project

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-30T14:42:20Z
last_update: 2026-03-30T14:46:05Z
date_finished: 2026-03-30T14:46:05Z
---

# T-791: Fix checkpoint.sh cross-project transcript leak — scope find_transcript to current project

## Context

`checkpoint.sh`'s `find_transcript()` searches ALL projects (`~/.claude/projects`) and picks the most recently modified JSONL. When another project has a more recent or larger transcript, `checkpoint.sh status` reports that project's token count — causing false warnings/handovers. `budget-gate.sh` was already fixed (T-149) to scope to the current project but `checkpoint.sh` was never updated.

## Acceptance Criteria

### Agent
- [x] `find_transcript()` in checkpoint.sh scoped to current project directory (matching budget-gate.sh pattern)
- [x] `checkpoint.sh status` reports tokens from the correct project transcript
- [x] Unit test verifying project-scoped transcript discovery (tests/unit/checkpoint.bats — 8 tests)

## Verification

# checkpoint.sh is valid bash
bash -n agents/context/checkpoint.sh
# find_transcript uses PROJECT_ROOT-derived path, not global search
grep -q 'project_dir_name\|project_jsonl_dir' agents/context/checkpoint.sh
# No unscoped find across all projects
! grep 'find.*\.claude/projects ' agents/context/checkpoint.sh

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

### 2026-03-30T14:42:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-791-fix-checkpointsh-cross-project-transcrip.md
- **Context:** Initial task creation

### 2026-03-30T14:46:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
