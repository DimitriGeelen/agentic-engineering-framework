---
id: T-1025
name: "Playwright test expansion — untested page routes and GET APIs"
description: >
  Playwright test expansion — untested page routes and GET APIs

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-07T12:20:37Z
last_update: 2026-04-07T12:28:30Z
date_finished: 2026-04-07T12:28:30Z
---

# T-1025: Playwright test expansion — untested page routes and GET APIs

## Context

Expand Playwright regression test coverage to untested Watchtower routes. Previous sessions built 35 test files covering ~193 tests. This task adds coverage for remaining page routes (/ask, /fabric/component, /file viewer, /search sub-pages) and GET API endpoints (/api/sessions, /api/termlink/sessions, /api/timeline/task, /api/fabric/source, /settings/models). Uses TermLink dispatch for parallel test writing.

## Acceptance Criteria

### Agent
- [x] test_ask.py — /api/v1/ask endpoint returns JSON with query/error fields (2 tests)
- [x] test_file_viewer.py — /file/<path> renders markdown, blocks traversal (4 tests)
- [x] test_search_extended.py — /search/conversations and /search/feedback/analytics (3 tests)
- [x] test_api_fabric_source.py — /api/fabric/source and /api/fabric/report (4 tests)
- [x] test_api_timeline_detail.py — /api/timeline/task/<id> returns HTML (3 tests)
- [x] test_api_termlink.py — /api/termlink/sessions returns JSON array (1 test)
- [x] test_settings_models.py — /settings/models returns response (1 test)
- [x] All 18 new tests pass

## Verification

# All new test files exist
ls tests/playwright/test_ask.py tests/playwright/test_file_viewer.py tests/playwright/test_search_extended.py tests/playwright/test_api_fabric_source.py tests/playwright/test_api_timeline_detail.py tests/playwright/test_api_termlink.py tests/playwright/test_settings_models.py
# Tests pass
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_ask.py tests/playwright/test_file_viewer.py tests/playwright/test_search_extended.py tests/playwright/test_api_fabric_source.py tests/playwright/test_api_timeline_detail.py tests/playwright/test_api_termlink.py tests/playwright/test_settings_models.py -x -q 2>&1 | tail -5

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

### 2026-04-07T12:20:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1025-playwright-test-expansion--untested-page.md
- **Context:** Initial task creation

### 2026-04-07T12:28:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
