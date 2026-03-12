---
id: T-471
name: "Scope-aware task gate — block build tasks with placeholder ACs (G-020 Option A)"
description: >
  Scope-aware task gate — block build tasks with placeholder ACs (G-020 Option A)

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [governance, enforcement, G-020]
components: []
related_tasks: []
created: 2026-03-12T20:50:50Z
last_update: 2026-03-12T20:53:06Z
date_finished: 2026-03-12T20:53:06Z
---

# T-471: Scope-aware task gate — block build tasks with placeholder ACs (G-020 Option A)

## Context

Implements Option A + E from T-469 inception. See `docs/reports/T-469-governance-bypass-remediation.md`.

## Acceptance Criteria

### Agent
- [x] Build readiness gate added to check-active-task.sh (blocks build tasks with placeholder ACs)
- [x] CLAUDE.md pickup message handling rule added
- [x] Gate blocks a build task with placeholder ACs (self-test — blocked T-471 itself before ACs were written)
- [x] Gate allows a build task with real ACs (CLAUDE.md edit succeeded after ACs written)
- [x] G-020 status updated in concerns.yaml (watching → mitigated)

## Verification

grep -q "Build readiness gate" agents/context/check-active-task.sh
grep -q "Pickup Message Handling" CLAUDE.md
grep -q "G-020" agents/context/check-active-task.sh

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

### 2026-03-12T20:50:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-471-scope-aware-task-gate--block-build-tasks.md
- **Context:** Initial task creation

### 2026-03-12T20:53:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
