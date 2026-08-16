---
id: T-1025
name: "Playwright test expansion — untested page routes and GET APIs"
description: >
  Playwright test expansion — untested page routes and GET APIs

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-07T12:20:37Z
last_update: '2026-08-16T22:24:20Z'
date_finished: 2026-04-07T12:28:30Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:38Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=1 
      (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1e61edea
- **Timestamp:** 2026-06-02T14:54:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
