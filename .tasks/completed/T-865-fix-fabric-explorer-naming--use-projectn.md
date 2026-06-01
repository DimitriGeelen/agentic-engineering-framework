---
id: T-865
name: "Fix Fabric Explorer naming — use project_name in title"
description: >
  Fix Fabric Explorer naming — use project_name in title

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [web/app.py, web/templates/fabric_explorer.html]
related_tasks: []
created: 2026-04-04T20:39:09Z
last_update: 2026-04-04T20:43:03Z
date_finished: 2026-04-04T20:43:03Z
---

# T-865: Fix Fabric Explorer naming — use project_name in title

## Context

T-854 added `project_name` Jinja global but Fabric Explorer h1 still says "Fabric Explorer" (generic). OpenClaw's instance at :1500 shows "OpenClaw Fabric Explorer" — project-specific. Fix: use `{{ project_name }}` in the template.

## Acceptance Criteria

### Agent
- [x] Fabric Explorer h1 includes `{{ project_name }}`
- [x] curl localhost:3000/fabric/graph shows "Agentic Engineering Framework Fabric Explorer"

## Verification

curl -sf http://localhost:3000/fabric/graph -o /tmp/t865.html && grep -q 'Agentic Engineering Framework' /tmp/t865.html

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

### 2026-04-04T20:39:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-865-fix-fabric-explorer-naming--use-projectn.md
- **Context:** Initial task creation

### 2026-04-04T20:43:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
