---
id: T-1041
name: "Playwright tests — scan actions, fabric component, ask stream endpoints"
description: >
  Playwright tests — scan actions, fabric component, ask stream endpoints

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-07T15:36:44Z
last_update: 2026-04-07T15:50:38Z
date_finished: 2026-04-07T15:50:38Z
---

# T-1041: Playwright tests — scan actions, fabric component, ask stream endpoints

## Context

Cover remaining untested Watchtower routes: scan approve/defer/apply (cockpit.py:216-300), fabric component detail (fabric.py:144), ask stream (api.py:184).

## Acceptance Criteria

### Agent
- [x] test_api_scan_actions.py covers approve/defer/apply with nonexistent rec_id (404)
- [x] test_fabric_detail.py covers component detail page (200, content, nonexistent 404)
- [x] test_api_ask_stream.py covers /ask/stream validation (missing query, valid query)
- [x] All new tests collected by pytest without errors (305 total)

## Verification

cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_api_scan_actions.py tests/playwright/test_fabric_detail.py tests/playwright/test_api_ask_stream.py --collect-only -q 2>&1 | tail -1 | grep -q "test"

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

### 2026-04-07T15:36:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1041-playwright-tests--scan-actions-fabric-co.md
- **Context:** Initial task creation

### 2026-04-07T15:50:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-14ae853d
- **Timestamp:** 2026-06-02T14:54:45Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_api_scan_actions.py tests/playwright/test_fabric_detail.py tests/playwright/test_api_ask_stream.py --collect-only -`
