---
id: T-1068
name: "Horizon-status invariant enforcement in update-task.sh"
description: >
  Add auto-sync logic: started-work auto-sets horizon:now, horizon next/later auto-demotes started-work to captured. Update tests and CLAUDE.md. Origin: T-1067 GO.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-08T10:32:30Z
last_update: 2026-04-08T10:36:24Z
date_finished: 2026-04-08T10:36:24Z
---

# T-1068: Horizon-status invariant enforcement in update-task.sh

## Context

Origin: T-1067 GO. Research: `docs/reports/T-1067-horizon-status-invariants.md`

## Acceptance Criteria

### Agent
- [x] Invariant 1: `--status started-work` auto-sets horizon to `now` with info message
- [x] Invariant 2: `--horizon next/later` on a `started-work` task auto-demotes status to `captured` with info message
- [x] Existing test 7 updated for new invariant behavior (sets captured first to test pure horizon change)
- [x] New tests cover both invariant paths (4 tests: promote, demote-later, demote-next, no-demote-issues)
- [x] All update_task.bats tests pass (15/15)
- [x] CLAUDE.md documents the invariant rules (Horizon section)

## Verification

bats tests/unit/update_task.bats

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

### 2026-04-08T10:32:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1068-horizon-status-invariant-enforcement-in-.md
- **Context:** Initial task creation

### 2026-04-08T10:36:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3cc7e2e1
- **Timestamp:** 2026-06-02T14:54:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
