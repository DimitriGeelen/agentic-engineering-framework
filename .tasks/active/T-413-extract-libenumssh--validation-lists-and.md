---
id: T-413
name: "Extract lib/enums.sh — validation lists and status/type/horizon checks (S3+S10)"
description: >
  Create lib/enums.sh with VALID_STATUSES, VALID_TYPES, VALID_HORIZONS and is_valid_*() functions. Currently hardcoded in 6+ files with silent divergence risk. Directive score: S3=7, S10=7. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: [refactoring, shell, reliability]
components: [lib/enums.sh, agents/task-create/create-task.sh, agents/task-create/update-task.sh]
related_tasks: [T-411]
created: 2026-03-10T21:03:13Z
last_update: 2026-03-10T22:32:33Z
date_finished: null
---

# T-413: Extract lib/enums.sh — validation lists and status/type/horizon checks (S3+S10)

## Context

Refactoring finding S3 (score 7) + S10 (score 7) from `docs/reports/T-411-refactoring-directive-scoring.md`.

**S3 — Validation enum duplication (6 files):**
VALID_STATUSES, VALID_TYPES, VALID_HORIZONS hardcoded as string lists in create-task.sh:92-103
and update-task.sh:37-56,125-131. Adding a new workflow type requires editing 3+ files.
See research artifact § "SHELL SCRIPTS" row S3, S10.

**S10 — Hardcoded status/type lists (3 files):**
Same data, different representation. No single source of truth.

## Acceptance Criteria

### Agent
- [x] lib/enums.sh created with VALID_STATUSES, VALID_TYPES, VALID_HORIZONS arrays
- [x] is_valid_status(), is_valid_type(), is_valid_horizon() validation functions
- [x] create-task.sh and update-task.sh source lib/enums.sh instead of inline lists
- [x] Adding a new type requires changing only lib/enums.sh

### Human
<!-- No human verification needed for this refactoring -->

## Verification

test -f lib/enums.sh
bash -n lib/enums.sh
source lib/enums.sh && is_valid_status captured
source lib/enums.sh && ! is_valid_status nonexistent
! grep -q 'VALID_STATUSES=' agents/task-create/create-task.sh

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

### 2026-03-10T21:03:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-413-extract-libenumssh--validation-lists-and.md
- **Context:** Initial task creation

### 2026-03-10T22:28:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-10T22:32:33Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-03-10T22:32:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
