---
id: T-915
name: "Add unit tests for lib/upstream.sh"
description: >
  Add unit tests for lib/upstream.sh

status: started-work
workflow_type: test
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-05T15:39:36Z
last_update: 2026-04-05T15:39:36Z
date_finished: null
---

# T-915: Add unit tests for lib/upstream.sh

## Context

lib/upstream.sh is one of only 2 lib/ files without unit tests (82% coverage). It has testable pure functions for repo resolution, dedup tracking, and config management.

## Acceptance Criteria

### Agent
- [ ] Test file exists at tests/unit/lib_upstream.bats
- [ ] Tests cover _upstream_resolve_repo (from .framework.yaml)
- [ ] Tests cover _upstream_is_sent / _upstream_mark_sent dedup
- [ ] Tests cover do_upstream_config (show + set)
- [ ] Tests cover do_upstream routing (help, unknown subcommand)
- [ ] All tests pass

## Verification

bats tests/unit/lib_upstream.bats

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

### 2026-04-05T15:39:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-915-add-unit-tests-for-libupstreamsh.md
- **Context:** Initial task creation
