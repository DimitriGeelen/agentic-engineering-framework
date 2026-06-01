---
id: T-1380
name: "fw watchtower port subcommand — T-1376 B5 public single-source-of-truth accessor"
description: >
  fw watchtower port subcommand — T-1376 B5 public single-source-of-truth accessor

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-22T18:59:35Z
last_update: 2026-04-22T19:02:20Z
date_finished: 2026-04-22T19:02:20Z
---

# T-1380: fw watchtower port subcommand — T-1376 B5 public single-source-of-truth accessor

## Context

T-1376 GO (2026-04-22) approved B1-B5 to eliminate `:3000` hardcodes. B1-B4 shipped (lib/init.sh, templates, liveness cron, CLAUDE.md section). B5 adds `fw watchtower port` / `fw watchtower url` as a public single-source-of-truth accessor so agents and scripts can ask the framework directly instead of reading triple files manually or guessing port.

## Acceptance Criteria

### Agent
- [x] `bin/watchtower.sh port` prints the current port (integer) from `.context/working/watchtower.port` when Watchtower is running
- [x] `bin/watchtower.sh url` prints the current URL from `.context/working/watchtower.url` when Watchtower is running
- [x] When triple file is absent, `port`/`url` fall back to `fw_config PORT` → `3000` default and exit 0 (prints defaulted value)
- [x] `fw watchtower port` and `fw watchtower url` both work (routed via new `watchtower` case in bin/fw)
- [x] Help output (`bin/watchtower.sh --help`) lists the new `port` and `url` commands
- [x] CLAUDE.md "Watchtower Port" section references `fw watchtower port` as the preferred accessor

## Verification

bin/watchtower.sh port | grep -qE '^[0-9]+$'
bin/watchtower.sh url | grep -qE '^https?://'
bin/fw watchtower port | grep -qE '^[0-9]+$'
bin/watchtower.sh --help | grep -q 'port '
bin/watchtower.sh --help | grep -q 'url '
grep -q 'fw watchtower port' CLAUDE.md

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

### 2026-04-22T18:59:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1380-fw-watchtower-port-subcommand--t-1376-b5.md
- **Context:** Initial task creation

### 2026-04-22T19:02:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
