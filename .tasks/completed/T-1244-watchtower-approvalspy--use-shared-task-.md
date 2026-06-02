---
id: T-1244
name: "Watchtower approvals.py — use shared task cache instead of inline file scanning"
description: >
  Watchtower approvals.py — use shared task cache instead of inline file scanning

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [web/blueprints/approvals.py, web/shared.py]
related_tasks: []
created: 2026-04-13T20:28:38Z
last_update: 2026-04-23T18:57:40Z
date_finished: 2026-04-23T18:57:40Z
---

# T-1244: Watchtower approvals.py — use shared task cache instead of inline file scanning

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `_load_pending_go_decisions()` filters via `get_all_task_metadata()` cache before reading bodies (only inception tasks in active/ are read)
- [x] `_load_pending_human_acs()` filters via cache before reading bodies (only active tasks are scanned, frontmatter from cache)
- [x] No regression in /approvals output: pending_go and pending_acs lists equivalent before/after refactor
- [x] Pytest `tests/web/test_approvals_cache.py` covers parity check (same task list before/after)

## Verification

bash -c 'out=$(python3 -m pytest tests/web/test_approvals_cache.py -q 2>&1); echo "$out" | tail -5; echo "$out" | grep -qE "passed"'
curl -sf http://localhost:3000/approvals -o /dev/null

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

### 2026-04-13T20:28:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1244-watchtower-approvalspy--use-shared-task-.md
- **Context:** Initial task creation

### 2026-04-13T20:29:53Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
- **Reason:** Approvals page already at 170ms — no performance issue

### 2026-04-23T16:46:48Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-04-23T18:54:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-23T18:57:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c32876af
- **Timestamp:** 2026-06-02T14:56:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
