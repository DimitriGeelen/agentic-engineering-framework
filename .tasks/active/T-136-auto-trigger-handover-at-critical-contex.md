---
id: T-136
name: Auto-trigger handover at critical context threshold
description: >
  checkpoint.sh fires warnings at 150K tokens but the agent ignores them. Sprechloop cycle 2 reached 152K with no handover. Change: at CRITICAL threshold, checkpoint.sh should auto-run 'fw handover --emergency --commit' instead of just printing a warning. The agent cannot be trusted to act on warnings — structural enforcement is required (L-013, L-038).
status: started-work
workflow_type: build
horizon: now
owner: human
tags: []
related_tasks: []
created: 2026-02-17T23:49:33Z
last_update: 2026-02-18T00:04:08Z
date_finished: null
---

# T-136: Auto-trigger handover at critical context threshold

## Context

Sprechloop cycle 2: agent reached 152K tokens without triggering handover despite CRITICAL warnings from checkpoint.sh. The agent ignored the printed warning and kept dispatching new work. Evidence: L-013, L-038 — agents cannot be trusted to act on warnings. checkpoint.sh already detects the threshold — it just needs to act instead of advising.

**Design:** At CRITICAL threshold (150K+), checkpoint.sh auto-runs `fw handover --emergency` instead of just printing a warning. Re-entry guard (`.handover-in-progress` lock file) prevents the handover commit from re-triggering the checkpoint.

## Acceptance Criteria

- [ ] checkpoint.sh auto-runs `fw handover --emergency` at CRITICAL threshold
- [ ] Re-entry guard prevents recursive handover triggering
- [ ] Lock file is cleaned up after handover (success or failure)
- [ ] Failure falls back to manual instructions

## Verification

# checkpoint.sh contains auto-handover logic
grep -q 'AUTO-HANDOVER' agents/context/checkpoint.sh
# Re-entry guard uses lock file
grep -q 'handover-in-progress' agents/context/checkpoint.sh
# Lock file cleanup on both success and failure paths
grep -q 'rm -f.*handover_lock' agents/context/checkpoint.sh

## Updates

### 2026-02-17T23:49:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-136-auto-trigger-handover-at-critical-contex.md
- **Context:** Initial task creation

### 2026-02-18T00:04:08Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
