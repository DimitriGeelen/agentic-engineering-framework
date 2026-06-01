---
id: T-736
name: "Fix component detail source path — use ACTUAL_PROJECT_ROOT"
description: >
  Fix component detail source path — use ACTUAL_PROJECT_ROOT

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-29T20:56:04Z
last_update: 2026-03-29T21:00:24Z
date_finished: 2026-03-29T21:00:24Z
---

# T-736: Fix component detail source path — use ACTUAL_PROJECT_ROOT

## Context

`component_detail()` in fabric.py uses `PROJECT_ROOT` for source file resolution. In consumer projects, `PROJECT_ROOT` is `.agentic-framework/` but source files live at the actual project root. Should use `ACTUAL_PROJECT_ROOT` (introduced in T-730).

## Acceptance Criteria

### Agent
- [x] `component_detail()` uses `ACTUAL_PROJECT_ROOT` for source path resolution
- [x] Path traversal check uses `ACTUAL_PROJECT_ROOT`
- [x] Vendor copy synced
- [x] Component detail page still shows source code

## Verification

python3 -c "import ast; ast.parse(open('web/blueprints/fabric.py').read())"
grep -q "ACTUAL_PROJECT_ROOT" web/blueprints/fabric.py
grep -qm1 "Component:" <(curl -s http://localhost:3000/fabric/component/fw)

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

### 2026-03-29T20:56:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-736-fix-component-detail-source-path--use-ac.md
- **Context:** Initial task creation

### 2026-03-29T21:00:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
