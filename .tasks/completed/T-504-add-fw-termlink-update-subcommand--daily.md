---
id: T-504
name: "Add fw termlink update subcommand + daily update check cron"
description: >
  Add fw termlink update subcommand + daily update check cron

status: work-completed
workflow_type: build
owner: agent
horizon: null
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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1d9f5f9e
- **Timestamp:** 2026-06-02T15:03:14Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#3 (Agent)** — Daily cron installed at 06:00 logging to /var/log/termlink-update.log
  - **AC-verify-mismatch** (narrow, heuristic) — `path=var/log/termlink-update.log in: Daily cron installed at 06:00 logging to /var/log/termlink-update.log`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `crontab -l | grep -q "termlink.*update"`
