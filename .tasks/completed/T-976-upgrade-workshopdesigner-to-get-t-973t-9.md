---
id: T-976
name: "Upgrade WorkshopDesigner to get T-973/T-974 gates"
description: >
  Upgrade WorkshopDesigner to get T-973/T-974 gates

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-06T20:36:12Z
last_update: 2026-04-06T20:37:22Z
date_finished: 2026-04-06T20:37:22Z
---

# T-976: Upgrade WorkshopDesigner to get T-973/T-974 gates

## Context

WorkshopDesigner (`/opt/025-WokrshopDesigner`) was freshly initialized but lacks T-973 (review-before-decide gate) and T-974 (recommendation gate) in its vendored `lib/`. Run `fw upgrade` from framework root targeting that directory. Cross-repo edit via fw upgrade (not manual Write/Edit).

## Acceptance Criteria

### Agent
- [x] `fw upgrade /opt/025-WokrshopDesigner` run successfully (5 changes applied)
- [x] Consumer's `lib/review.sh` has `.reviewed-` marker code
- [x] Consumer's `lib/inception.sh` has recommendation gate
- [x] Consumer's inception template has `## Recommendation` section
- [x] Verification commands pass

## Verification

grep -q '.reviewed-' /opt/025-WokrshopDesigner/.agentic-framework/lib/review.sh
grep -q 'Recommendation' /opt/025-WokrshopDesigner/.agentic-framework/lib/inception.sh

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

### 2026-04-06T20:36:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-976-upgrade-workshopdesigner-to-get-t-973t-9.md
- **Context:** Initial task creation

### 2026-04-06T20:37:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Consumer upgraded with new gates
