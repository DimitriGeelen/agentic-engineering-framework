---
id: T-675
name: 'Fix T-\d{3} regex — support 3+ digit task IDs across Watchtower'
description: 'Fix T-\d{3} regex — support 3+ digit task IDs across Watchtower'

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-28T20:14:27Z
last_update: 2026-03-28T20:17:44Z
date_finished: 2026-03-28T20:17:44Z
---

# T-675: Fix T-\d{3} regex — support 3+ digit task IDs across Watchtower

## Context

All Watchtower route validators and task ID parsers use `\d{3}` (exactly 3 digits). We're at T-674 — at T-1000 every route will 404. Change to `\d{3,}` across all files.

## Acceptance Criteria

### Agent
- [x] All `T-\d{3}` patterns in web/ changed to `T-\d{3,}`
- [x] No remaining `\d{3}` task ID patterns in Watchtower code
- [x] Watchtower starts without errors after changes

## Verification

# No 3-digit-only task ID patterns remain in web/
python3 -c "import re, pathlib; files=[f for f in pathlib.Path('web').rglob('*.py') if 'T-\\\\d{3}' in f.read_text()]; assert not files, f'Found: {files}'; print('OK: no \\\\d{{3}} patterns')"
# Watchtower health endpoint works
curl -sf http://127.0.0.1:3000/health | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['app']=='ok'; print('OK')"

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

### 2026-03-28T20:14:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-675-fix-t-d3-regex--support-3-digit-task-ids.md
- **Context:** Initial task creation

### 2026-03-28T20:17:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b12e77b0
- **Timestamp:** 2026-06-02T15:04:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
