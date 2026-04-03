---
id: T-807
name: "Unit tests for lib/costs.sh token tracking"
description: >
  Unit tests for lib/costs.sh token tracking

status: started-work
workflow_type: test
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-03T20:00:38Z
last_update: 2026-04-03T20:00:38Z
date_finished: null
---

# T-807: Unit tests for lib/costs.sh token tracking

## Context

Add bats unit tests for `lib/costs.sh` (T-801). Tests cover `_costs_jsonl_dir` path computation, `costs_main` routing, Python parsing with JSONL fixtures, and edge cases (empty dir, no data, malformed JSON).

## Acceptance Criteria

### Agent
- [x] Test file `tests/unit/lib_costs.bats` exists and follows project test conventions
- [x] Tests cover `_costs_jsonl_dir` path computation
- [x] Tests cover `costs_main` routing (summary, session, current, help, unknown)
- [x] Tests cover Python JSONL parsing with fixture data
- [x] Tests cover edge cases: empty directory, no JSONL files, malformed JSON lines
- [x] All tests pass: `bats tests/unit/lib_costs.bats`

## Verification

bats tests/unit/lib_costs.bats

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

### 2026-04-03T20:00:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-807-unit-tests-for-libcostssh-token-tracking.md
- **Context:** Initial task creation
