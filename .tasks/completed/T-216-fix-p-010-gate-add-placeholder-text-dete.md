---
id: T-216
name: "Fix P-010 gate: add placeholder text detection to reject skeleton ACs"
description: >
  Fix P-010 gate: add placeholder text detection to reject skeleton ACs

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-20T08:37:19Z
last_update: 2026-02-20T08:40:04Z
date_finished: 2026-02-20T08:40:04Z
---

# T-216: Fix P-010 gate: add placeholder text detection to reject skeleton ACs

## Context

P-010 gate (update-task.sh) counts `[x]` vs `[ ]` but doesn't check AC content. Template placeholders like `[x] [First criterion]` pass the gate. Discovered in AC quality audit across 212 tasks.

## Acceptance Criteria

### Agent
- [x] update-task.sh rejects `[x] [First criterion]` style skeleton ACs at completion
- [x] update-task.sh still passes real ACs that are checked
- [x] Both Agent/Human split mode and legacy (no split) mode are covered
- [x] --force bypass still works for skeleton ACs (with warning)
- [x] Existing unit tests (84) still pass

## Verification

grep -q "skeleton placeholders" agents/task-create/update-task.sh
# Test that the placeholder pattern detection exists
grep -q "First.*Second.*Third.*Fourth.*Fifth" agents/task-create/update-task.sh
# Shellcheck has no new errors (pre-existing SC2144/SC2012/SC2001 OK)
! shellcheck agents/task-create/update-task.sh 2>&1 | grep -v "SC2144\|SC2012\|SC2001" | grep -q "error"

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

### 2026-02-20T08:37:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-216-fix-p-010-gate-add-placeholder-text-dete.md
- **Context:** Initial task creation

### 2026-02-20T08:40:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
