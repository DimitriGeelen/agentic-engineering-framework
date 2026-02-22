---
id: T-250
name: "Reliable Watchtower startup script"
description: >
  Create a reliable start/stop/restart script for the Watchtower web UI,
  inspired by DenkraumNavigator's restart_server_prod.sh. Handles PID management,
  port cleanup, graceful shutdown, health check, and LAN IP reporting.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-02-22T13:46:39Z
last_update: 2026-02-22T13:49:16Z
date_finished: 2026-02-22T13:49:16Z
---

# T-250: Reliable Watchtower startup script

## Context

Current startup is ad-hoc (`python3 -m web.app &`), fragile (wrong cwd = import error), no PID tracking, no port cleanup. Inspired by `/opt/DenkraumNavigator/restart_server_prod.sh` (Gunicorn-based, PID file, graceful shutdown, LAN IP detection, health check).

## Acceptance Criteria

### Agent
- [x] Script exists at `bin/watchtower.sh` with start/stop/restart/status subcommands
- [x] PID file management — writes/reads/cleans `.context/working/watchtower.pid`
- [x] Graceful shutdown with SIGTERM, fallback to SIGKILL after timeout
- [x] Port availability check before starting
- [x] Health check after start (curl localhost:PORT)
- [x] LAN IP detection and reporting
- [x] `fw serve` updated to use the new script
- [x] Script is executable and passes shellcheck basics

## Verification

test -x bin/watchtower.sh
grep -q "start\|stop\|restart\|status" bin/watchtower.sh
grep -q "watchtower.sh" bin/fw

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

### 2026-02-22T13:46:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-250-reliable-watchtower-startup-script.md
- **Context:** Initial task creation

### 2026-02-22T13:49:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
