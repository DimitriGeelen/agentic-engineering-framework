---
id: T-251
name: "Fix C-XXX display in fabric detail page"
description: >
  Fix C-XXX display in fabric detail page

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: [web/blueprints/fabric.py, web/templates/fabric_detail.html]
related_tasks: []
created: 2026-02-22T15:41:44Z
last_update: 2026-02-22T15:42:50Z
date_finished: 2026-02-22T15:42:50Z
---

# T-251: Fix C-XXX display in fabric detail page

## Context

Legacy C-XXX component IDs in dependency targets showed as raw codes in the fabric detail page, not resolved to component names or linked.

## Acceptance Criteria

### Agent
- [x] Fabric detail page resolves C-XXX IDs to component names in "Depends On" table
- [x] Dependency targets are clickable links to component detail pages
- [x] Path-based targets (agents/context/lib/init.sh) also resolve to names

## Verification

# Detail page loads for context-dispatcher (has C-XXX deps)
curl -sf http://localhost:3000/fabric/component/context-dispatcher | grep -q "add-learning"
# C-002 target resolved to link
curl -sf http://localhost:3000/fabric/component/context-dispatcher | grep -q "C-002"

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

### 2026-02-22T15:41:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-251-fix-c-xxx-display-in-fabric-detail-page.md
- **Context:** Initial task creation

### 2026-02-22T15:42:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
