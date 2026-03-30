---
id: T-778
name: "Pickup cron registration — add pickup-process to cron registry"
description: >
  Register fw pickup process in the cron registry YAML for 15-minute scheduling. Integrate with fw cron generate.

status: captured
workflow_type: build
owner: claude-code
horizon: next
tags: []
components: []
related_tasks: [T-772, T-776]
created: 2026-03-30T13:22:03Z
last_update: 2026-03-30T13:22:03Z
date_finished: null
---

# T-778: Pickup cron registration — add pickup-process to cron registry

## Context

Register the pickup inbox processor in the cron registry for automated 15-minute scanning. Design: `docs/reports/T-772-cross-project-pickup.md`

## Acceptance Criteria

### Agent
- [ ] `pickup-process` job added to cron registry YAML
- [ ] Schedule: `*/15 * * * *`
- [ ] `fw cron generate` includes the pickup-process job
- [ ] `fw cron status` shows pickup-process as active

## Verification

cd /opt/999-Agentic-Engineering-Framework && grep -q "pickup-process" cron/registry.yaml

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

### 2026-03-30T13:22:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-778-pickup-cron-registration--add-pickup-pro.md
- **Context:** Initial task creation
