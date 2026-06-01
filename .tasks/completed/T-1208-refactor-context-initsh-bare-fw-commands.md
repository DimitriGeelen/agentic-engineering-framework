---
id: T-1208
name: "Refactor context init.sh bare fw commands to use _fw_cmd (T-1146 GO)"
description: >
  Refactor context init.sh bare fw commands to use _fw_cmd (T-1146 GO)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/lib/init.sh, tests/lint/no-bare-fw-in-gate-scripts.bats]
related_tasks: []
created: 2026-04-13T08:41:07Z
last_update: 2026-04-13T08:43:09Z
date_finished: 2026-04-13T08:43:09Z
---

# T-1208: Refactor context init.sh bare fw commands to use _fw_cmd (T-1146 GO)

## Context

agents/context/lib/init.sh is the context init welcome message — first thing agents see. Has 7 bare
`fw` command sites. Part of T-1146 GO (command amnesia remediation).

## Acceptance Criteria

### Agent
- [x] All bare `fw` commands in init.sh replaced with `_fw_cmd()`
- [x] Invariant test extended

## Verification

bats tests/lint/no-bare-fw-in-gate-scripts.bats

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

### 2026-04-13T08:41:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1208-refactor-context-initsh-bare-fw-commands.md
- **Context:** Initial task creation

### 2026-04-13T08:43:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
