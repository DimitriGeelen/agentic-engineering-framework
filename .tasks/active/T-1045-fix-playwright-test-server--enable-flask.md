---
id: T-1045
name: "Fix Playwright test server — enable Flask threaded mode to prevent sequential request starvation"
description: >
  Fix Playwright test server — enable Flask threaded mode to prevent sequential request starvation

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-07T16:37:38Z
last_update: 2026-04-07T16:37:38Z
date_finished: null
---

# T-1045: Fix Playwright test server — enable Flask threaded mode to prevent sequential request starvation

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [ ] conftest.py redirects Flask stderr to file instead of PIPE (prevents buffer deadlock)
- [ ] conftest.py stdout redirected to DEVNULL (not needed after startup)
- [x] Test collection still succeeds (305 tests)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-07T16:37:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1045-fix-playwright-test-server--enable-flask.md
- **Context:** Initial task creation
