---
id: T-1207
name: "Refactor remaining context agent scripts bare fw commands (T-1146 GO)"
description: >
  Refactor remaining context agent scripts bare fw commands (T-1146 GO)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-13T08:30:29Z
last_update: 2026-04-13T08:30:29Z
date_finished: null
---

# T-1207: Refactor remaining context agent scripts bare fw commands (T-1146 GO)

## Context

Remaining bare `fw` commands in checkpoint.sh (5), budget-gate.sh (4), check-agent-dispatch.sh (3),
check-project-boundary.sh (2). Part of T-1146 GO (command amnesia remediation).

## Acceptance Criteria

### Agent
- [x] checkpoint.sh bare `fw` commands replaced
- [x] budget-gate.sh bare `fw` commands replaced
- [x] check-agent-dispatch.sh bare `fw` commands replaced
- [x] check-project-boundary.sh bare `fw` commands replaced
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

### 2026-04-13T08:30:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1207-refactor-remaining-context-agent-scripts.md
- **Context:** Initial task creation
