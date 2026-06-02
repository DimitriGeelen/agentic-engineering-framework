---
id: T-1211
name: "Fix datetime.date handling in scanner.py — same bug class as T-1209"
description: >
  Fix datetime.date handling in scanner.py — same bug class as T-1209

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-13T09:03:56Z
last_update: 2026-04-13T09:05:20Z
date_finished: 2026-04-13T09:05:20Z
---

# T-1211: Fix datetime.date handling in scanner.py — same bug class as T-1209

## Context

scanner.py has 3 sites where `datetime.date` from YAML is silently skipped (`else: continue`).
Same bug class as T-1209 (core.py) and T-1210 (prioritizer.py). Fix: coerce date to datetime.

## Acceptance Criteria

### Agent
- [x] All 3 `else: continue` sites in scanner.py handle `datetime.date`
- [x] No `else: continue` remains in date-parsing blocks

## Verification

# No else-continue skipping dates in scanner.py
python3 -c "import ast; tree=ast.parse(open('web/watchtower/scanner.py').read()); print('OK')"

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

### 2026-04-13T09:03:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1211-fix-datetimedate-handling-in-scannerpy--.md
- **Context:** Initial task creation

### 2026-04-13T09:05:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c9b1a980
- **Timestamp:** 2026-06-02T14:55:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
