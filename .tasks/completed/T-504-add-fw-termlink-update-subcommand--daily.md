---
id: T-504
name: "Add fw termlink update subcommand + daily update check cron"
description: >
  Add fw termlink update subcommand + daily update check cron

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-16T05:16:56Z
last_update: 2026-03-16T05:18:45Z
date_finished: 2026-03-16T05:18:45Z
---

# T-504: Add fw termlink update subcommand + daily update check cron

## Context

Extends T-503 TermLink Phase 0. User requested `fw termlink update` + daily cron.

## Acceptance Criteria

### Agent
- [x] `fw termlink update` pulls latest and rebuilds from TERMLINK_REPO
- [x] `fw termlink update --quiet` only prints when update available
- [x] Daily cron installed at 06:00 logging to /var/log/termlink-update.log

## Verification

grep -q "cmd_update" agents/termlink/termlink.sh
grep -q "update)" agents/termlink/termlink.sh
crontab -l | grep -q "termlink.*update"

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

### 2026-03-16T05:16:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-504-add-fw-termlink-update-subcommand--daily.md
- **Context:** Initial task creation

### 2026-03-16T05:18:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
