---
id: T-1186
name: "Fix G-042: generate hook usage list from filesystem — eliminate 4 mirror sites"
description: >
  Fix G-042: generate hook usage list from filesystem — eliminate 4 mirror sites

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T21:20:01Z
last_update: 2026-04-12T21:22:07Z
date_finished: 2026-04-12T21:22:07Z
---

# T-1186: Fix G-042: generate hook usage list from filesystem — eliminate 4 mirror sites

## Context

G-042: Hook usage list in `bin/fw:3561-3563` is hardcoded (16 hook names). Filesystem (`agents/context/*.sh`) is the canonical source. Fix: generate the list dynamically from `ls`. Scope limited to the usage message — the doctor/enforcement mirror sites are deferred (separate deliverables).

## Acceptance Criteria

### Agent
- [x] `bin/fw` hook usage message generates hook list from filesystem, not hardcoded
- [x] `fw hook` (with no args) shows all hooks that exist as `.sh` files (20 hooks)
- [x] G-042 marked resolved in concerns.yaml

## Verification

bash -c 'bin/fw hook 2>&1 | grep -q "Available hooks:"'
! grep -q 'check-active-task.*check-tier0.*budget-gate' bin/fw

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

### 2026-04-12T21:20:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1186-fix-g-042-generate-hook-usage-list-from-.md
- **Context:** Initial task creation

### 2026-04-12T21:22:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
