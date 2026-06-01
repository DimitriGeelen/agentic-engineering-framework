---
id: T-991
name: "Fix web test failures — update monkeypatch paths after subprocess_utils refactor"
description: >
  Fix web test failures — update monkeypatch paths after subprocess_utils refactor

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-07T08:51:22Z
last_update: 2026-04-07T09:43:10Z
date_finished: 2026-04-07T09:43:10Z
---

# T-991: Fix web test failures — update monkeypatch paths after subprocess_utils refactor

## Context

tasks.py was refactored to use `web.subprocess_utils.run_fw_command` instead of direct `subprocess.run`. TestSubprocessStderr monkeypatches the old path `web.blueprints.tasks.subprocess.run` which now fails with ImportError.

## Acceptance Criteria

### Agent
- [x] TestSubprocessStderr tests pass after monkeypatch path update
- [x] CSRF tests fixed — /api/ paths skip CSRF by design, tests updated
- [x] Footer version test fixed — no longer hardcodes v1.0.0
- [x] terminal.py/terminal/ package conflict resolved — PTY manager in __init__.py
- [x] All web tests pass (142/142, 0 failures)

## Verification

cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/test_app.py -x -q 2>&1 | tail -5

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

### 2026-04-07T08:51:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-991-fix-web-test-failures--update-monkeypatc.md
- **Context:** Initial task creation

### 2026-04-07T09:43:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
