---
id: T-161
name: "Hook and gate integration tests — 5 critical enforcement scripts"
description: >
  Write integration tests for: budget-gate.sh, check-active-task.sh, check-tier0.sh (extend existing), checkpoint.sh, error-watchdog.sh. Requires mock JSONL transcripts, mock git repos, mock focus.yaml. These are critical path — 0% coverage currently. Ref: T-158, /tmp/T-158-hooks-and-bugs.md

status: work-completed
workflow_type: test
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T13:30:45Z
last_update: 2026-02-18T15:24:36Z
date_finished: 2026-02-18T15:24:36Z
---

# T-161: Hook and gate integration tests — 5 critical enforcement scripts

## Context

Critical-path hooks with 0% test coverage. These enforce budget gating, task-first, tier-0, and error detection.

## Acceptance Criteria

- [x] Integration tests for `check-active-task.sh` (blocks Write/Edit without active task) — 19 tests
- [x] Integration tests for `check-tier0.sh` (blocks destructive commands) — 34 tests
- [x] Integration tests for `error-watchdog.sh` (detects bash errors in PostToolUse) — 23 tests
- [x] All integration tests pass: `bats tests/integration/` — 76/76
- [x] Minimum 25 test cases — 76 total

## Verification

bats tests/integration/

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

### 2026-02-18T13:30:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-161-hook-and-gate-integration-tests--5-criti.md
- **Context:** Initial task creation

### 2026-02-18T15:24:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
