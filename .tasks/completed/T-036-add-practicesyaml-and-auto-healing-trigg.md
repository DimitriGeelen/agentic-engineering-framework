---
id: T-036
name: Add practices.yaml and auto-healing trigger
description: >
  Create practices.yaml as structured queryable data and auto-trigger healing diagnosis when task status changes to issues or blocked
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: [practices, structured-data]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T23:45:30Z
last_update: 2026-02-14T09:03:31Z
date_finished: 2026-02-14T09:03:31Z
---

# T-036: Add practices.yaml and auto-healing trigger

## Design Record

**practices.yaml:** Machine-queryable YAML with all 7 practices from 015-Practices.md. Each entry has id, name, derived_from, description, anti_pattern, origin_task, origin_date, status, applications.

**Auto-healing trigger:** Deferred — requires task status change detection mechanism that doesn't exist yet. Will be implemented when task status transitions are formalized (e.g., via fw task update command).

## Updates

### 2026-02-14T09:03:31Z — build-completed [claude-code]
- **Action:** Created .context/project/practices.yaml with all 7 practices
- **Scope note:** Auto-healing trigger deferred (no task status transition mechanism exists yet)
