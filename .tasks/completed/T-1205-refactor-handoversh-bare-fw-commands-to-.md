---
id: T-1205
name: "Refactor handover.sh bare fw commands to use _emit_user_command (T-1146 GO)"
description: >
  Refactor handover.sh bare fw commands to use _emit_user_command (T-1146 GO)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/handover/handover.sh, tests/lint/no-bare-fw-in-gate-scripts.bats]
related_tasks: []
created: 2026-04-13T08:24:08Z
last_update: 2026-04-13T08:26:01Z
date_finished: 2026-04-13T08:26:01Z
---

# T-1205: Refactor handover.sh bare fw commands to use _emit_user_command (T-1146 GO)

## Context

handover.sh has 2 terminal-output sites with bare `fw` commands (lines 277, 779). Markdown content
sites (backtick-quoted inside handover file) are documentation and don't need refactoring.
Part of T-1146 GO (command amnesia remediation).

## Acceptance Criteria

### Agent
- [x] Terminal-output bare `fw` commands replaced with `_emit_user_command()` or `_fw_cmd()`
- [x] Handover still generates successfully

## Verification

# Invariant test passes
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

### 2026-04-13T08:24:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1205-refactor-handoversh-bare-fw-commands-to-.md
- **Context:** Initial task creation

### 2026-04-13T08:26:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
