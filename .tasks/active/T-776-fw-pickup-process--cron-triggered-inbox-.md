---
id: T-776
name: "fw pickup process — cron-triggered inbox scanner"
description: >
  Deterministic, idempotent inbox scanner: read all pending envelopes from .context/pickup/inbox/, process each (validate, dedup, create inception task, notify), move to processed/. Exit 0 if no work.

status: captured
workflow_type: build
owner: claude-code
horizon: next
tags: []
components: []
related_tasks: [T-772, T-774, T-778]
created: 2026-03-30T13:21:48Z
last_update: 2026-03-30T13:21:48Z
date_finished: null
---

# T-776: fw pickup process — cron-triggered inbox scanner

## Context

Framework-side inbox processor for the pickup pipeline (T-772 GO). Depends on T-774 (lib/pickup.sh). Design: `docs/reports/T-772-cross-project-pickup.md`

## Acceptance Criteria

### Agent
- [ ] `fw pickup process` subcommand registered in `bin/fw`
- [ ] Scans `.context/pickup/inbox/` for pending YAML envelopes
- [ ] For each: validate → dedup check → create inception task → notify → move to processed/
- [ ] Idempotent: running twice with no new pickups produces no side effects
- [ ] Exit 0 when no pending pickups (silent success for cron)
- [ ] Logs each processed pickup with pickup_id and created task_id
- [ ] `fw pickup list` shows inbox contents with status

## Verification

cd /opt/999-Agentic-Engineering-Framework && bin/fw pickup process

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

### 2026-03-30T13:21:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-776-fw-pickup-process--cron-triggered-inbox-.md
- **Context:** Initial task creation
