---
id: T-136
name: Auto-trigger handover at critical context threshold
description: >
  checkpoint.sh fires warnings at 150K tokens but the agent ignores them. Sprechloop cycle 2 reached 152K with no handover. Change: at CRITICAL threshold, checkpoint.sh should auto-run 'fw handover --emergency --commit' instead of just printing a warning. The agent cannot be trusted to act on warnings — structural enforcement is required (L-013, L-038).
status: captured
workflow_type: build
horizon: now
owner: human
tags: []
related_tasks: []
created: 2026-02-17T23:49:33Z
last_update: 2026-02-17T23:49:33Z
date_finished: null
---

# T-136: Auto-trigger handover at critical context threshold

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T23:49:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-136-auto-trigger-handover-at-critical-contex.md
- **Context:** Initial task creation
