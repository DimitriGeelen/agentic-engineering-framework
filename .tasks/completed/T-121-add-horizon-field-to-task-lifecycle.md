---
id: T-121
name: Add horizon field to task lifecycle
description: >
  Add horizon: now|next|later field to task frontmatter. Distinguishes "ready to work on" from "backlog/deferred" tasks. Handover agent filters by horizon so deferred tasks don't appear as suggested actions.
status: work-completed
horizon: now
workflow_type: build
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T16:07:24Z
last_update: 2026-02-17T16:16:07Z
date_finished: 2026-02-17T16:16:07Z
---

# T-121: Add horizon field to task lifecycle

## Context

User observed T-120 (deferred whitepaper review) being suggested as primary handover action despite being intentionally parked. The `captured` status conflates "ready to work" with "backlog." Horizon field adds structured prioritization.

## Acceptance Criteria

- [x] `horizon` field in both templates (default.md, inception.md) with default `now`
- [x] `create-task.sh` accepts `--horizon` flag
- [x] `update-task.sh` accepts `--horizon` flag
- [x] `handover.sh` sorts/filters Work in Progress by horizon (now first, later excluded from suggestions)
- [x] `fw work-on` passes `--horizon` through to create-task
- [x] Existing tasks tagged: T-111→now, T-107→next, T-120→later
- [x] CLAUDE.md documents the horizon field

## Updates

### 2026-02-17T16:07:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-121-add-horizon-field-to-task-lifecycle.md
- **Context:** Initial task creation

### 2026-02-17T16:12:44Z — status-update [task-update-agent]
- **Change:** horizon: unset → now

### 2026-02-17T16:16:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
