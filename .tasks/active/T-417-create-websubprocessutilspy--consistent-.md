---
id: T-417
name: "Create web/subprocess_utils.py — consistent git/fw command execution (P7)"
description: >
  Create web/subprocess_utils.py with run_git_command() and run_fw_command() helpers. Currently 3 separate subprocess implementations with inconsistent timeouts (none vs 10s), error checking, and encoding. Directive score: P7=7. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: [refactoring, python, watchtower, reliability]
components: [web/subprocess_utils.py, web/blueprints/core.py, web/blueprints/quality.py, web/blueprints/session.py]
related_tasks: [T-411]
created: 2026-03-10T21:03:17Z
last_update: 2026-03-10T23:17:27Z
date_finished: null
---

# T-417: Create web/subprocess_utils.py — consistent git/fw command execution (P7)

## Context

Refactoring finding P7 (score 7) from `docs/reports/T-411-refactoring-directive-scoring.md`.

**P7 — Subprocess error handling inconsistency:**
Three separate subprocess implementations: core.py (no timeout), quality.py (timeout=10, detailed),
session.py (timeout=10, different error style). See research artifact § "PYTHON BACKEND" row P7.

## Acceptance Criteria

### Agent
- [x] web/subprocess_utils.py created with run_git_command(args, timeout=10) and run_fw_command(args, timeout=30)
- [x] All blueprint subprocess.run calls replaced with utility functions
- [x] Consistent timeout, encoding (utf-8, errors=replace), and error handling
- [x] At least 3 call sites converted

### Human
<!-- No human verification needed for this refactoring -->

## Verification

test -f web/subprocess_utils.py
python3 -c "from web.subprocess_utils import run_git_command; print(run_git_command(['log', '--oneline', '-1']))"

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

### 2026-03-10T21:03:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-417-create-websubprocessutilspy--consistent-.md
- **Context:** Initial task creation

### 2026-03-10T23:17:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
