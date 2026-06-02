---
id: T-647
name: "Fix broken /file/ route in Watchtower docs.py"
description: >
  Fix broken /file/ route in Watchtower docs.py

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-27T13:50:33Z
last_update: 2026-03-27T14:03:33Z
date_finished: 2026-03-27T14:03:33Z
---

# T-647: Fix broken /file/ route in Watchtower docs.py

## Context

Investigation: The `/file/` route already uses `PROJECT_ROOT` (not `FRAMEWORK_ROOT`). The bug report was incorrect — the test files (T-026-agent*.md) simply don't exist. No code change needed.

## Acceptance Criteria

### Agent
- [x] `docs.py` file_viewer route uses PROJECT_ROOT instead of FRAMEWORK_ROOT
- [x] `docs.py` _auto_link_files uses PROJECT_ROOT for existence checks
- [x] /file/ route returns 200 for existing project files

## Verification

# Code already uses PROJECT_ROOT — verified by inspection
grep -q 'PROJECT_ROOT / filepath' web/blueprints/docs.py
grep -q 'PROJECT_ROOT / path' web/blueprints/docs.py

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

### 2026-03-27T13:50:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-647-fix-broken-file-route-in-watchtower-docs.md
- **Context:** Initial task creation

### 2026-03-27T14:03:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-15b0f85a
- **Timestamp:** 2026-06-02T15:04:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
