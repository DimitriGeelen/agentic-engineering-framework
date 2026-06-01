---
id: T-858
name: "Update fw upgrade help text with new sync targets"
description: >
  Update fw upgrade help text with new sync targets

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/upgrade.sh]
related_tasks: []
created: 2026-04-04T19:16:54Z
last_update: 2026-04-04T21:57:53Z
date_finished: 2026-04-04T21:57:53Z
---

# T-858: Update fw upgrade help text with new sync targets

## Context

T-857 added lib/*.sh and agent script sync to `fw upgrade`. The `--help` text still only lists the original 6 sync targets.

## Acceptance Criteria

### Agent
- [x] Help text lists lib/*.sh sync
- [x] Help text lists agent scripts sync
- [x] Help text lists bin/fw sync

## Verification

bin/fw upgrade --help 2>&1 | grep -q 'lib/\*.sh'
bin/fw upgrade --help 2>&1 | grep -q 'Agent scripts'

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

### 2026-04-04T19:16:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-858-update-fw-upgrade-help-text-with-new-syn.md
- **Context:** Initial task creation

### 2026-04-04T21:57:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
