---
id: T-861
name: "Register unregistered fabric components — session-metrics.sh and config.html"
description: >
  Register unregistered fabric components — session-metrics.sh and config.html

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-04T19:35:58Z
last_update: 2026-04-04T21:58:04Z
date_finished: 2026-04-04T21:58:04Z
---

# T-861: Register unregistered fabric components — session-metrics.sh and config.html

## Context

Fabric drift detected 2 unregistered components: `agents/context/session-metrics.sh` (T-831) and `web/templates/config.html` (T-817).

## Acceptance Criteria

### Agent
- [x] session-metrics.sh registered in .fabric/components/
- [x] config.html registered in .fabric/components/
- [x] Fabric drift shows 0 unregistered components

## Verification

test -f .fabric/components/agents-context-session-metrics.yaml
test -f .fabric/components/web-templates-config.yaml

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

### 2026-04-04T19:35:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-861-register-unregistered-fabric-components-.md
- **Context:** Initial task creation

### 2026-04-04T21:58:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
